"""Arte de la entidad que sigue al jugador (terror ambiental del prólogo) y del fotograma de cara.

Uso (desde la raíz del repo):
    python -I tools/art/entity.py

Genera en assets/sprites/horror/:
- entity.png: hoja de 8 fotogramas de 64×112 (humo que se mueve en bucle). Silueta humanoide
  alta y encorvada, brazos demasiado largos, de cintura para abajo se deshace en humo.
  Casi negra con un borde violeta tramado; la máscara pálida va apagada. Pies en (32, 104).
- entity_glow.png: misma hoja, solo la máscara y dos puntos en las cuencas (se dibuja
  aditiva y sin luz, para que se intuya en la oscuridad).
- face_flash.png: 160×160, la máscara de cerca, agrietada y con las cuencas vacías.
  Se ve uno o dos fotogramas dentro de un fallo de cinta.

Colores de la guía estética: contorno #0E0A12, azul noche/violeta #1E1B3A #3A2E5C,
blanco hueso #BFB6A3 #E8E1D3. El humo es tramado (Bayer 4×4), nunca degradado limpio.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

from pxrender import BAYER4, fbm, vnoise  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/sprites/horror"

FRAME_W = 64
FRAME_H = 112
FRAMES = 8
# Píxel de los pies dentro del fotograma (el nodo se coloca ahí).
ORIGIN = (32, 104)

INK = (14, 10, 18)
NIGHT = (24, 20, 40)
VIOLET = (42, 34, 70)
HAZE = (58, 46, 92)
BONE = (191, 182, 163)
BONE_LIGHT = (232, 225, 211)
BONE_DARK = (120, 112, 100)
# Brillo de la máscara en la hoja base (la entidad se dibuja sin luz: tiene que quedar apagada).
MASK_DIM = 0.32


def _dither(x: int, y: int) -> float:
    return (BAYER4[y % 4][x % 4] + 0.5) / 16.0


def _smin(a: float, b: float, k: float) -> float:
    h = max(0.0, min(1.0, 0.5 + 0.5 * (b - a) / k))
    return b + (a - b) * h - k * h * (1 - h)


def _capsule(px: float, py: float, ax: float, ay: float, bx: float, by: float, r: float) -> float:
    pax, pay = px - ax, py - ay
    bax, bay = bx - ax, by - ay
    h = max(0.0, min(1.0, (pax * bax + pay * bay) / (bax * bax + bay * bay)))
    return math.hypot(pax - bax * h, pay - bay * h) - r


def _ellipse(px: float, py: float, cx: float, cy: float, rx: float, ry: float) -> float:
    return (math.hypot((px - cx) / rx, (py - cy) / ry) - 1.0) * min(rx, ry)


def _loop_noise(x: float, y: float, t: float, seed: int, octaves: int = 3) -> float:
    """Ruido que hace bucle en t ∈ [0, 1): mezcla de dos muestras desfasadas."""
    a = fbm((x, y, t * 3.0), seed, octaves)
    b = fbm((x, y, (t - 1.0) * 3.0), seed, octaves)
    return a * (1 - t) + b * t


def body_sdf(x: float, y: float, sway: float) -> float:
    """Distancia (px) a la silueta. x hacia la derecha, y hacia abajo, origen en los pies."""
    lean = sway * (-y / 80.0)  # la parte alta se mece más
    x -= lean
    head = _ellipse(x, y, 1.5, -71.0, 6.0, 7.8)
    neck = _capsule(x, y, 0.5, -64.0, 0.0, -58.0, 2.6)
    shoulders = _capsule(x, y, -11.0, -56.0, 11.5, -57.5, 3.6)
    chest = _capsule(x, y, 0.0, -56.0, 0.0, -36.0, 7.2)
    waist = _capsule(x, y, 0.0, -38.0, 0.0, -6.0, 6.2 + max(0.0, (-y - 6.0) * -0.0) + (1.0 - (-y) / 40.0) * 3.0)
    # Brazos demasiado largos, colgando y un poco abiertos; dedos largos.
    arm_l = min(_capsule(x, y, -11.5, -56.0, -15.0, -36.0, 2.4), _capsule(x, y, -15.0, -36.0, -16.5, -20.0, 2.0))
    arm_r = min(_capsule(x, y, 12.0, -57.0, 15.0, -37.0, 2.4), _capsule(x, y, 15.0, -37.0, 17.5, -21.0, 2.0))
    fingers = min(
        _capsule(x, y, -16.5, -20.0, -17.5, -12.0, 0.9), _capsule(x, y, -16.0, -20.0, -15.0, -12.5, 0.8),
        _capsule(x, y, 17.5, -21.0, 18.5, -13.0, 0.9), _capsule(x, y, 17.0, -21.0, 16.0, -13.5, 0.8),
    )
    d = _smin(head, neck, 2.0)
    d = _smin(d, shoulders, 3.0)
    d = _smin(d, chest, 4.0)
    d = _smin(d, waist, 4.0)
    d = _smin(d, min(arm_l, arm_r), 2.5)
    d = min(d, fingers)
    return d


def mask_value(x: float, y: float, sway: float, glow: bool) -> tuple[tuple[int, int, int], float] | None:
    """Máscara pálida sobre la cabeza: color y opacidad, o None si el píxel no es de la máscara."""
    lean = sway * (71.0 / 80.0)
    mx, my = 1.5 + lean + 0.4, -71.5
    d = _ellipse(x, y, mx, my, 4.6, 6.0)
    if d > 0:
        return None
    # Cuencas vacías: dos óvalos oscuros; la izquierda algo más grande.
    for ex, ey, rx, ry in ((-1.9, -1.2, 1.25, 1.6), (2.0, -1.0, 1.1, 1.4)):
        if _ellipse(x, y, mx + ex, my + ey, rx, ry) < 0:
            if glow and abs(x - (mx + ex)) < 0.6 and abs(y - (my + ey + 0.3)) < 0.6:
                return (BONE_LIGHT, 0.55)  # un punto mínimo en el fondo de la cuenca
            return (INK, 1.0) if not glow else None
    # Grieta vertical que baja desde la frente.
    crack_x = mx + 0.6 + math.sin((y - my) * 1.3) * 0.6
    if abs(x - crack_x) < 0.5 and y < my + 3.5:
        return (BONE_DARK, 1.0) if not glow else None
    shade = 0.55 + 0.45 * max(0.0, -d / 2.5)
    if glow:
        return (BONE, 0.16 + 0.16 * shade)
    # En la hoja base la máscara va muy apagada: la claridad la pone la capa de brillo.
    color = tuple(int((BONE_DARK[i] + (BONE[i] - BONE_DARK[i]) * shade) * MASK_DIM) for i in range(3))
    return (color, 1.0)


def render_frame(t: float, glow: bool) -> Image.Image:
    img = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    sway = math.sin(t * math.tau) * 1.6
    ox, oy = ORIGIN
    for py in range(FRAME_H):
        for px in range(FRAME_W):
            x, y = px + 0.5 - ox, py + 0.5 - oy
            m = mask_value(x, y, sway, glow)
            if m is not None:
                (r, g, b), a = m
                if a > _dither(px, py) * 0.3:
                    img.putpixel((px, py), (r, g, b, int(255 * a)))
                continue
            if glow:
                continue
            # Humo: el borde se deshace con ruido; más cuanto más abajo.
            low = max(0.0, min(1.0, (y + 34.0) / 34.0))  # 0 en la cintura, 1 en el suelo
            n = _loop_noise(x * 0.16, y * 0.11 + t * 1.5, t, 41)
            n2 = _loop_noise(x * 0.4, y * 0.3 + t * 3.0, t, 97, 2)
            d = body_sdf(x + (n - 0.5) * (2.0 + low * 9.0), y, sway) + (n2 - 0.5) * 3.0
            d += low * low * 7.0 * (0.4 + n)  # se adelgaza y se rompe al bajar
            # Hilos de humo que suben desde hombros y cabeza.
            wisp = 0.0
            if y < -50:
                wn = _loop_noise(x * 0.25, y * 0.06 + t * 2.0, t, 151)
                stream = abs(math.sin(x * 0.42 + wn * 5.0))
                wisp = max(0.0, 1.0 - stream * 3.0) * max(0.0, 1.0 - (-50 - y) / 34.0) * (1.0 if abs(x) < 22 else 0.0)
            if d < -2.5:
                level = 1.0
            elif d < 1.5:
                level = (1.5 - d) / 4.0
            else:
                level = 0.0
            level = max(level, wisp * 0.45)
            if level <= 0.0:
                continue
            if level < 1.0 and level < _dither(px, py) * 0.9 + 0.05:
                continue
            # Núcleo casi negro; borde violeta tramado; la neblina de los hilos, más clara.
            edge = max(0.0, min(1.0, (d + 2.5) / 4.0))
            if wisp > 0.0 and d > 1.0:
                color, alpha = HAZE, 0.55
            elif edge > 0.6 + 0.3 * _dither(px, py):
                color, alpha = VIOLET, 0.9
            elif edge > 0.25 + 0.3 * _dither(px, py):
                color, alpha = NIGHT, 1.0
            else:
                color, alpha = INK, 1.0
            # Abajo, el humo se vuelve transparente.
            alpha *= 1.0 - low * 0.55
            img.putpixel((px, py), (*color, int(255 * alpha)))
    return img


def face_flash(size: int = 160) -> Image.Image:
    """La máscara de cerca: hueso agrietado, ladeada, cuencas vacías que gotean y sin boca."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = size / 2
    tilt = -0.12
    steps = [(34, 28, 32), (70, 64, 58), BONE_DARK, (160, 151, 135), BONE, BONE_LIGHT]
    for py in range(size):
        for px in range(size):
            x0, y0 = (px + 0.5 - c) / c, (py + 0.5 - c) / c
            x = x0 * math.cos(tilt) - y0 * math.sin(tilt)
            y = x0 * math.sin(tilt) + y0 * math.cos(tilt)
            n = fbm((x * 3.0, y * 3.0, 0.5), 211, 4)
            # Óvalo alargado, más estrecho en la barbilla.
            rx = 0.56 - max(0.0, y) * 0.16
            d = math.hypot(x / rx, (y + 0.04) / 0.86) - 1.0 + (n - 0.5) * 0.14
            if d > 0.06:
                continue
            shade = 0.25 + 0.75 * min(1.0, -d * 2.2)
            shade *= 0.8 + 0.4 * (fbm((x * 9.0, y * 9.0, 2.0), 223, 3) - 0.5)
            shade *= 1.0 - max(0.0, y) * 0.45 - max(0.0, x) * 0.25  # luz desde arriba a la izquierda
            shade -= 0.25 * max(0.0, 1.0 - abs(x) / 0.12) * max(0.0, 1.0 - abs(y - 0.12) / 0.12)  # bajo la nariz
            col = None
            for ex, ey, rx_e, ry_e, tilt_e in ((-0.22, -0.1, 0.15, 0.085, 0.25), (0.22, -0.08, 0.13, 0.075, -0.3)):
                dx, dy = x - ex, y - ey
                u = dx * math.cos(tilt_e) + dy * math.sin(tilt_e)
                v = -dx * math.sin(tilt_e) + dy * math.cos(tilt_e)
                de = math.hypot(u / rx_e, v / ry_e)
                if de < 1.0:
                    col = INK
                    break
                if de < 1.8:
                    shade *= 0.35 + 0.65 * (de - 1.0) / 0.8  # cuencas hundidas
                # Regueros oscuros que bajan de las cuencas.
                drip_x = ex + 0.02 * math.sin(y * 14.0 + ex * 9.0)
                if abs(x - drip_x) < 0.018 + 0.012 * n and ey < y < ey + 0.25 + 0.3 * vnoise((ex * 10.0, 0.0, 0.0), 5):
                    col = (52, 22, 26)
                    break
            crack = abs(x - 0.04 - math.sin(y * 9.0) * 0.03 - (y + 0.8) * 0.07) < 0.011 + 0.008 * n and y < 0.35
            crack2 = abs(y + 0.48 + (x - 0.05) * 0.6) < 0.011 and 0.05 < x < 0.42
            seam = abs(y - 0.45 - x * x * 0.3) < 0.012 and abs(x) < 0.2 and int((x + 1.0) * 60) % 3 != 0
            if col is None and (crack or crack2 or seam):
                col = (40, 34, 36)
            if col is None:
                level = shade + (_dither(px, py) - 0.5) * 0.2
                col = steps[max(0, min(len(steps) - 1, int(level * len(steps))))]
            alpha = 255 if d < -0.04 or _dither(px, py) > 0.5 else 0
            if alpha:
                img.putpixel((px, py), (*col, alpha))
    return img


def build() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (FRAME_W * FRAMES, FRAME_H), (0, 0, 0, 0))
    glow = Image.new("RGBA", (FRAME_W * FRAMES, FRAME_H), (0, 0, 0, 0))
    for i in range(FRAMES):
        t = i / FRAMES
        sheet.alpha_composite(render_frame(t, False), (i * FRAME_W, 0))
        glow.alpha_composite(render_frame(t, True), (i * FRAME_W, 0))
    sheet.save(OUT / "entity.png")
    glow.save(OUT / "entity_glow.png")
    face_flash().save(OUT / "face_flash.png")
    for name in ("entity.png", "entity_glow.png", "face_flash.png"):
        print("  ", (OUT / name).relative_to(ROOT).as_posix())


if __name__ == "__main__":
    build()
