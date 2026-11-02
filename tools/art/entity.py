"""Arte de la entidad que sigue al jugador (terror ambiental del prólogo) y del fotograma de cara.

Uso (desde la raíz del repo):
    python -I tools/art/entity.py

Genera en assets/sprites/horror/:
- entity.png: hoja de 8 fotogramas de 72×136. NO es una imagen para mirar: es un **mapa de datos**
  que lee `shaders/entity_shade.gdshader`:
    A = densidad de la sombra (1 en el núcleo; un halo tenue alrededor, que solo deforma el fondo),
    G = hilos de humo que suben de los bordes (se pintan apenas más claros que el negro),
    R = los dos puntos pálidos de los ojos (el shader los enciende a ratos).
  Silueta: muy alta (≈ 2,2 veces el protagonista) y deforme: cuello largo y torcido, cabeza
  alargada y caída hacia un lado, un hombro más alto, el brazo izquierdo tan largo que roza el
  suelo, el derecho doblado hacia fuera, piernas finas que se deshacen en humo. Pies en (36, 130).
  El fotograma 5 es un tirón brusco de la cabeza.
- face_flash.png: 160×160, la máscara de cerca, agrietada y con las cuencas vacías.
  Se ve uno o dos fotogramas dentro de un fallo de cinta (susto FACE_FLASH, no la entidad).

Colores de la guía estética (face_flash): contorno #0E0A12, blanco hueso #BFB6A3 #E8E1D3.
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

FRAME_W = 72
FRAME_H = 136
FRAMES = 8
# Píxel de los pies dentro del fotograma (el nodo se coloca ahí).
ORIGIN = (36, 130)
# Fotograma con el tirón de cabeza.
TWITCH_FRAME = 5

INK = (14, 10, 18)
BONE = (191, 182, 163)
BONE_LIGHT = (232, 225, 211)
BONE_DARK = (120, 112, 100)


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


def _ellipse(px: float, py: float, cx: float, cy: float, rx: float, ry: float, tilt: float = 0.0) -> float:
    dx, dy = px - cx, py - cy
    u = dx * math.cos(tilt) + dy * math.sin(tilt)
    v = -dx * math.sin(tilt) + dy * math.cos(tilt)
    return (math.hypot(u / rx, v / ry) - 1.0) * min(rx, ry)


def _loop_noise(x: float, y: float, t: float, seed: int, octaves: int = 3) -> float:
    """Ruido que hace bucle en t ∈ [0, 1): mezcla de dos muestras desfasadas."""
    a = fbm((x, y, t * 3.0), seed, octaves)
    b = fbm((x, y, (t - 1.0) * 3.0), seed, octaves)
    return a * (1 - t) + b * t


def _head(t: float, twitch: bool) -> tuple[float, float, float]:
    """Centro y giro de la cabeza: caída hacia la derecha, con un vaivén lento (o un tirón)."""
    sway = math.sin(t * math.tau)
    if twitch:
        return 10.5, -106.0, 0.95
    return 6.5 + sway * 0.8, -109.0 + abs(sway) * 0.6, 0.55 + sway * 0.06


def body_sdf(x: float, y: float, t: float, twitch: bool) -> float:
    """Distancia (px) a la silueta. x a la derecha, y hacia abajo, origen en los pies."""
    heave = math.sin(t * math.tau) * 0.8  # respira: el tronco sube y baja un poco
    y_body = y + heave * max(0.0, (-y - 40.0) / 80.0)
    hx, hy, tilt = _head(t, twitch)
    head = _ellipse(x, y, hx, hy, 4.6, 8.4, tilt)
    jaw = _capsule(x, y, hx - 1.0, hy + 4.0, hx + 1.5, hy + 9.5, 1.6)  # mandíbula caída
    neck = _capsule(x, y_body, 0.5, -91.0, hx - 2.5, hy + 4.0, 2.0)
    # Hombros torcidos: el izquierdo caído, el derecho alto y adelantado.
    shoulders = _capsule(x, y_body, -12.0, -86.0, 10.0, -92.0, 3.2)
    chest = _capsule(x, y_body, -0.5, -87.0, -1.5, -64.0, 5.0)
    ribs = _capsule(x, y_body, -1.5, -66.0, 0.0, -46.0, 3.0)  # cintura consumida
    hips = _capsule(x, y_body, -3.0, -44.0, 3.0, -43.5, 2.6)
    # Brazo izquierdo: largo hasta casi el suelo, dedos como ramas.
    arm_l = min(_capsule(x, y_body, -12.0, -86.0, -16.0, -60.0, 2.1),
                _capsule(x, y_body, -16.0, -60.0, -19.0, -28.0, 1.7))
    fingers_l = min(_capsule(x, y, -19.0, -28.0, -21.5, -13.0, 0.75), _capsule(x, y, -19.0, -28.0, -18.0, -12.0, 0.7),
                    _capsule(x, y, -19.0, -28.0, -15.5, -15.0, 0.65))
    # Brazo derecho: codo hacia fuera, antebrazo que vuelve hacia el cuerpo.
    arm_r = min(_capsule(x, y_body, 10.0, -92.0, 18.5, -73.0, 2.1),
                _capsule(x, y_body, 18.5, -73.0, 13.0, -48.0, 1.7))
    fingers_r = min(_capsule(x, y, 13.0, -48.0, 15.5, -37.0, 0.7), _capsule(x, y, 13.0, -48.0, 11.0, -36.5, 0.65),
                    _capsule(x, y, 13.0, -48.0, 13.5, -35.0, 0.6))
    # Piernas finas y demasiado largas; la derecha un poco por delante.
    leg_l = _capsule(x, y, -3.5, -44.0, -5.0, -4.0, 2.3)
    leg_r = _capsule(x, y, 3.5, -44.0, 5.5, -6.0, 2.1)
    d = _smin(head, jaw, 1.5)
    d = _smin(d, neck, 2.0)
    d = _smin(d, shoulders, 2.5)
    d = _smin(d, chest, 3.0)
    d = _smin(d, ribs, 3.0)
    d = _smin(d, hips, 2.5)
    d = _smin(d, min(arm_l, arm_r), 2.0)
    d = _smin(d, min(leg_l, leg_r), 2.0)
    d = min(d, fingers_l, fingers_r)
    return d


def eye_value(x: float, y: float, t: float, twitch: bool) -> float:
    """Los dos puntos de los ojos (uno algo más bajo que el otro), en la cara caída."""
    hx, hy, tilt = _head(t, twitch)
    c, s = math.cos(tilt), math.sin(tilt)
    best = 0.0
    for ex, ey in ((-1.6, -2.0), (1.8, -1.2)):
        px, py = hx + ex * c - ey * s, hy + ex * s + ey * c
        dist = math.hypot(x - px, y - py)
        best = max(best, 1.0 if dist < 0.75 else (0.35 if dist < 1.3 else 0.0))
    return best


def render_frame(index: int) -> Image.Image:
    img = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    t = index / FRAMES
    twitch = index == TWITCH_FRAME
    ox, oy = ORIGIN
    for py in range(FRAME_H):
        for px in range(FRAME_W):
            x, y = px + 0.5 - ox, py + 0.5 - oy
            # Humo: el borde se deshace con ruido, más cuanto más abajo.
            low = max(0.0, min(1.0, (y + 40.0) / 40.0))  # 0 en la cadera, 1 en el suelo
            n = _loop_noise(x * 0.14, y * 0.09 + t * 1.5, t, 41)
            n2 = _loop_noise(x * 0.38, y * 0.28 + t * 3.0, t, 97, 2)
            d = body_sdf(x + (n - 0.5) * (2.0 + low * 10.0), y, t, twitch) + (n2 - 0.5) * 2.6
            d += low * low * 9.0 * (0.35 + n)  # las piernas se adelgazan y se rompen en humo
            # Densidad: 1 dentro; cae en el borde; un halo muy tenue alrededor (solo deforma el fondo).
            if d < -1.5:
                density = 1.0
            elif d < 2.0:
                density = 0.15 + 0.85 * (2.0 - d) / 3.5
            elif d < 9.0:
                density = 0.15 * (9.0 - d) / 7.0
            else:
                density = 0.0
            density *= 1.0 - low * 0.35
            # Hilos de humo que suben de cabeza, hombros y brazos.
            wisp = 0.0
            if 0.0 < d < 8.0 and y < -50.0:
                wn = _loop_noise(x * 0.22, y * 0.05 + t * 2.0, t, 151)
                stream = abs(math.sin(x * 0.45 + wn * 7.0 + math.sin(y * 0.21 + t * math.tau) * 1.4))
                wisp = max(0.0, 1.0 - stream * 3.2) * max(0.0, 1.0 - d / 8.0) * (0.3 + wn)
                wisp = min(1.0, wisp)
                density = max(density, wisp * 0.12)
            eye = eye_value(x, y, t, twitch) if d < 0.0 else 0.0
            if density <= 0.004 and wisp <= 0.0:
                continue
            img.putpixel((px, py), (int(255 * eye), int(255 * wisp), 0, int(round(255 * min(1.0, density)))))
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
    for i in range(FRAMES):
        sheet.paste(render_frame(i), (i * FRAME_W, 0))
    sheet.save(OUT / "entity.png")
    face_flash().save(OUT / "face_flash.png")
    for name in ("entity.png", "face_flash.png"):
        print("  ", (OUT / name).relative_to(ROOT).as_posix())


if __name__ == "__main__":
    build()
