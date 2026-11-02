"""Ilustración de fondo de la pantalla de título: el pasillo de la planta del hospital.

Uso (desde la raíz del repo):
    python -I tools/art/title_bg.py

Un pequeño trazador de rayos en Python puro (sin dependencias aparte de Pillow) pinta el pasillo
en perspectiva a 640×360 (la resolución del juego) y lo reduce a pocos niveles con tramado
Bayer, como el resto del arte. Genera en assets/sprites/title/:

- title_bg_lit.png: el fluorescente del centro encendido (luz verdosa de lámpara, suelo mojado
  que la refleja, polvo alrededor del tubo).
- title_bg_dark.png: el mismo encuadre con el tubo apagado; solo queda la luz roja de emergencia
  del fondo. La pantalla de título alterna las dos imágenes cuando el tubo parpadea.
- title_figure.png: capa transparente con la silueta de la entidad al fondo del pasillo
  (aparece un instante en algunos parpadeos).

Composición: camilla con una sábana (y algo debajo) cruzada en mitad del pasillo, puertas a los
lados, una entornada, barandilla, azulejo agrietado abajo y yeso con humedades arriba. Paleta de
la guía: verde laboratorio para la lámpara, azul noche en la sombra, granate/rojo de acento al fondo.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

import entity  # noqa: E402
from pxrender import BAYER4, fbm, vnoise  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/sprites/title"

W, H = 640, 360
FOCAL = 300.0
CAM = (-0.25, 1.5, 0.0)
# Pasillo: medio ancho, alto y largo (metros).
HALF_W = 1.45
CEIL = 2.85
LENGTH = 30.0
TUBE_Z = 5.2
FIXTURES = (0.2, 5.2, 10.6, 16.0, 21.4)
DOORS = (4.2, 9.0, 14.5, 20.5)
# Camilla: centro en el suelo, medio ancho y medio largo, altura del colchón y giro (radianes).
GURNEY_C = (0.2, 0.0, 5.9)
GURNEY_HALF = (0.33, 0.98)
GURNEY_TOP = 0.92
GURNEY_ANGLE = 0.62
EMERGENCY = (0.0, 2.35, LENGTH - 0.3)
FIGURE_AT = (0.35, 0.0, 19.0)

TUBE_COLOR = (0.84, 0.92, 0.72)
AMBIENT = (0.022, 0.022, 0.034)
RED = (0.75, 0.22, 0.17)


def _dither(x: int, y: int) -> float:
    return (BAYER4[y % 4][x % 4] + 0.5) / 16.0


def _mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def _ray_box(o, d, lo, hi):
    tmin, tmax, axis = -1e9, 1e9, -1
    for i in range(3):
        if abs(d[i]) < 1e-9:
            if o[i] < lo[i] or o[i] > hi[i]:
                return None
            continue
        t1, t2 = (lo[i] - o[i]) / d[i], (hi[i] - o[i]) / d[i]
        near_axis = i
        if t1 > t2:
            t1, t2 = t2, t1
        if t1 > tmin:
            tmin, axis = t1, near_axis
        tmax = min(tmax, t2)
        if tmin > tmax:
            return None
    if tmin <= 0:
        return None
    n = [0.0, 0.0, 0.0]
    n[axis] = -1.0 if d[axis] > 0 else 1.0
    return tmin, tuple(n)


def _rot(v, ang):
    c, s_ = math.cos(ang), math.sin(ang)
    return (v[0] * c + v[2] * s_, v[1], -v[0] * s_ + v[2] * c)


def _gurney_hit(o, d):
    """Camilla girada: se pasa el rayo a coordenadas de la camilla y se vuelve con la normal."""
    lo = _rot(tuple(o[i] - GURNEY_C[i] for i in range(3)), -GURNEY_ANGLE)
    ld = _rot(d, -GURNEY_ANGLE)
    hx, hz = GURNEY_HALF
    y1 = GURNEY_TOP
    best = None
    hit = _ray_box(lo, ld, (-hx, y1 - 0.3, -hz), (hx, y1, hz))  # colchón y sábana que cuelga
    if hit:
        best = (hit[0], hit[1], "sheet")
    # Bulto bajo la sábana (algo tumbado): un elipsoide aplastado.
    cx, cy, cz = 0.0, y1, 0.1
    rx, ry, rz = 0.2, 0.15, 0.78
    oc = ((lo[0] - cx) / rx, (lo[1] - cy) / ry, (lo[2] - cz) / rz)
    dd = (ld[0] / rx, ld[1] / ry, ld[2] / rz)
    a = sum(v * v for v in dd)
    b = 2 * sum(oc[i] * dd[i] for i in range(3))
    c = sum(v * v for v in oc) - 1
    disc = b * b - 4 * a * c
    if disc > 0:
        t = (-b - math.sqrt(disc)) / (2 * a)
        if t > 0 and (best is None or t < best[0]):
            p = tuple(lo[i] + ld[i] * t for i in range(3))
            if p[1] >= y1 - 0.01:
                n = ((p[0] - cx) / rx ** 2, (p[1] - cy) / ry ** 2, (p[2] - cz) / rz ** 2)
                ln = math.sqrt(sum(v * v for v in n))
                best = (t, tuple(v / ln for v in n), "sheet")
    # Patas.
    for lx in (-hx + 0.05, hx - 0.05):
        for lz in (-hz + 0.1, hz - 0.1):
            hit = _ray_box(lo, ld, (lx - 0.025, 0.0, lz - 0.025), (lx + 0.025, y1 - 0.3, lz + 0.025))
            if hit and (best is None or hit[0] < best[0]):
                best = (hit[0], hit[1], "metal")
    if best is None:
        return None
    return best[0], _rot(best[1], GURNEY_ANGLE), best[2]


def _shadowed(p) -> bool:
    """Sombra de la camilla respecto al tubo."""
    light = (0.0, CEIL - 0.05, TUBE_Z)
    d = tuple(light[i] - p[i] for i in range(3))
    hit = _gurney_hit(p, d)
    return hit is not None and hit[0] < 1.0


def _wall_material(z: float, y: float, side: float):
    """Color base, rugosidad y tipo de una pared (z: profundidad, y: altura)."""
    for i, dz in enumerate(DOORS):
        door_side = -1 if i % 2 == 0 else 1
        if door_side != side and not (i == 1):
            continue
        if abs(z - dz) < 0.55 and y < 2.15:
            if abs(z - dz) > 0.48 or y > 2.08:
                return (0.30, 0.29, 0.26), "frame"
            # La puerta 10.5 de la izquierda está entornada: una rendija negra.
            if i == 1 and side == -1 and z - dz > 0.3:
                return (0.0, 0.0, 0.0), "gap"
            if 1.35 < y < 1.75 and abs(z - dz) < 0.17:
                return (0.06, 0.08, 0.09), "glass"
            base = (0.36, 0.40, 0.36)
            stain = fbm((z * 3.0, y * 3.0, side), 31, 3)
            return _mix(base, (0.22, 0.22, 0.18), stain * 0.6), "door"
    if 0.93 < y < 0.99:
        return (0.42, 0.42, 0.40), "rail"
    if 0.86 < y <= 0.93:
        return (0.10, 0.10, 0.10), "rail_shadow"
    if y < 1.25:
        tile = (0.46, 0.50, 0.46)
        gu, gv = (z / 0.15) % 1.0, (y / 0.15) % 1.0
        if gu < 0.08 or gv < 0.08:
            return (0.34, 0.36, 0.33), "grout"
        crack = vnoise((z * 4.0, y * 4.0, side * 7.0), 51)
        grime = max(0.0, 1.0 - y / 0.5) * 0.5 + fbm((z * 2.0, y * 5.0, side), 53, 3) * 0.3
        c = _mix(tile, (0.25, 0.25, 0.20), grime)
        if 0.495 < crack < 0.505:
            c = (0.16, 0.16, 0.15)
        return c, "tile"
    plaster = (0.62, 0.62, 0.55)
    damp = fbm((z * 0.7, y * 1.3, side * 3.0), 61, 4)
    c = _mix(plaster, (0.30, 0.31, 0.24), max(0.0, damp - 0.45) * 2.2)
    if y > 2.6:
        c = _mix(c, (0.2, 0.2, 0.17), (y - 2.6) / 0.3 * 0.5)
    return c, "plaster"


def shade(px: int, py: int, lit: bool):
    d = ((px + 0.5 - W / 2) / FOCAL, -(py + 0.5 - H / 2 + 18) / FOCAL, 1.0)
    o = CAM
    t_best, n, kind, albedo = 1e9, None, "", (0, 0, 0)
    cands = []
    if d[1] < 0:
        cands.append(((0 - o[1]) / d[1], (0, 1, 0), "floor"))
    if d[1] > 0:
        cands.append(((CEIL - o[1]) / d[1], (0, -1, 0), "ceil"))
    if d[0] < 0:
        cands.append(((-HALF_W - o[0]) / d[0], (1, 0, 0), "wall_l"))
    if d[0] > 0:
        cands.append(((HALF_W - o[0]) / d[0], (-1, 0, 0), "wall_r"))
    cands.append(((LENGTH - o[2]) / d[2], (0, 0, -1), "end"))
    for t, nn, k in cands:
        if 0 < t < t_best:
            t_best, n, kind = t, nn, k
    g = _gurney_hit(o, d)
    if g and g[0] < t_best:
        t_best, n, kind = g[0], g[1], g[2]
    p = tuple(o[i] + d[i] * t_best for i in range(3))
    emissive = (0.0, 0.0, 0.0)
    spec_floor = False
    if kind == "floor":
        u, v = p[0] / 0.5, p[2] / 0.5
        checker = (math.floor(u) + math.floor(v)) % 2
        base = (0.36, 0.37, 0.34) if checker else (0.25, 0.26, 0.24)
        dirt = fbm((p[0] * 1.5, p[2] * 0.8, 0.0), 71, 4)
        albedo = _mix(base, (0.18, 0.17, 0.14), dirt * 0.7)
        spec_floor = True
    elif kind == "ceil":
        albedo = (0.30, 0.31, 0.28)
        if (p[0] / 0.6) % 1.0 < 0.04 or (p[2] / 0.6) % 1.0 < 0.03:
            albedo = (0.16, 0.16, 0.15)
        for fz in FIXTURES:
            if abs(p[0]) < 0.16 and abs(p[2] - fz) < 0.62:
                if fz == TUBE_Z and lit and abs(p[0]) < 0.1:
                    emissive = (1.6, 1.7, 1.35)
                else:
                    albedo = (0.20, 0.21, 0.19) if abs(p[0]) < 0.1 else (0.34, 0.34, 0.31)
        stain = fbm((p[0] * 2.0, p[2] * 0.6, 9.0), 81, 3)
        albedo = _mix(albedo, (0.12, 0.11, 0.09), max(0.0, stain - 0.5) * 1.5)
    elif kind in ("wall_l", "wall_r"):
        side = -1 if kind == "wall_l" else 1
        albedo, sub = _wall_material(p[2], p[1], side)
        if sub == "gap":
            albedo = (0.0, 0.0, 0.0)
    elif kind == "end":
        # Fondo: una puerta doble abierta a la oscuridad, con el piloto rojo encima.
        if abs(p[0]) < 0.7 and p[1] < 2.1:
            albedo = (0.0, 0.0, 0.0)
        else:
            albedo = (0.4, 0.38, 0.33)
        if abs(p[0]) < 0.12 and abs(p[1] - 2.35) < 0.06:
            emissive = (1.4, 0.35, 0.25)
    elif kind == "sheet":
        wrinkle = fbm((p[0] * 6.0, p[1] * 4.0, p[2] * 5.0), 91, 3)
        albedo = _mix((0.80, 0.78, 0.70), (0.45, 0.44, 0.40), wrinkle * 0.8)
        # Una mancha seca en la sábana, a la altura del pecho del bulto.
        q = _rot(tuple(p[i] - GURNEY_C[i] for i in range(3)), -GURNEY_ANGLE)
        if math.hypot((q[0] + 0.05) / 0.12, (q[2] + 0.35) / 0.2) < 1.0 + (wrinkle - 0.5) * 0.6 and p[1] > 0.85:
            albedo = (0.32, 0.10, 0.10)
    elif kind == "metal":
        albedo = (0.25, 0.25, 0.25)
    # Luz.
    light = list(AMBIENT)
    # Tubo encendido: tres puntos a lo largo del tubo.
    if lit:
        for dz in (-0.45, 0.0, 0.45):
            lp = (0.0, CEIL - 0.08, TUBE_Z + dz)
            lv = tuple(lp[i] - p[i] for i in range(3))
            dist = math.sqrt(sum(v * v for v in lv))
            ndl = max(0.0, sum(n[i] * lv[i] for i in range(3)) / dist) if kind != "ceil" else 0.25
            att = 1.0 / (1.0 + (dist / 1.25) ** 2)
            k = ndl * att * 1.15
            for i in range(3):
                light[i] += TUBE_COLOR[i] * k
        if kind in ("floor", "wall_l", "wall_r") and _shadowed(p):
            light = [light[i] * 0.35 + AMBIENT[i] for i in range(3)]
    # Piloto rojo del fondo.
    lv = tuple(EMERGENCY[i] - p[i] for i in range(3))
    dist = math.sqrt(sum(v * v for v in lv))
    ndl = max(0.0, sum(n[i] * lv[i] for i in range(3)) / max(dist, 1e-6))
    k = ndl / (1.0 + (dist / 2.2) ** 2) * 0.9
    for i in range(3):
        light[i] += RED[i] * k
    color = [albedo[i] * light[i] + emissive[i] for i in range(3)]
    # Suelo mojado: refleja el tubo en charcos.
    if spec_floor and lit:
        puddle = fbm((p[0] * 0.9, p[2] * 0.35, 4.0), 101, 3)
        if puddle > 0.5:
            r = (d[0], -d[1], d[2])
            tc = (CEIL - 0.08 - p[1]) / r[1] if r[1] > 0 else -1
            if tc > 0:
                hx, hz = p[0] + r[0] * tc, p[2] + r[2] * tc
                if abs(hx) < 0.12 and abs(hz - TUBE_Z) < 0.65:
                    wet = min(1.0, (puddle - 0.5) * 6.0)
                    for i in range(3):
                        color[i] += TUBE_COLOR[i] * 0.55 * wet
    # Halo de polvo alrededor del tubo.
    if lit:
        tube = (0.0, CEIL - 0.1, TUBE_Z)
        oc = tuple(tube[i] - o[i] for i in range(3))
        dl = math.sqrt(sum(v * v for v in d))
        along = sum(oc[i] * d[i] for i in range(3)) / dl
        if 0 < along < t_best * dl:
            closest = math.sqrt(max(0.0, sum(v * v for v in oc) - along * along))
            halo = math.exp(-(closest / 0.55) ** 2) * 0.35
            for i in range(3):
                color[i] += TUBE_COLOR[i] * halo
    # Niebla: lo lejano se hunde en azul noche.
    fog = 1.0 - math.exp(-t_best * 0.05)
    color = [color[i] * (1 - fog) + 0.02 * fog for i in range(3)]
    return color


def _quantize(color, x: int, y: int):
    """Tramado sobre la luminosidad (no por canal: así el tono no se ensucia) y pocos niveles."""
    levels = 12
    c = [max(0.0, v) ** (1 / 1.3) for v in color]  # gamma suave: las sombras siguen oscuras
    lum = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
    if lum <= 1e-5:
        return (0, 0, 0)
    q = math.floor(lum * levels + _dither(x, y) * 0.95) / levels
    k = q / lum
    return tuple(int(max(0, min(31, round(v * k * 31)))) * 255 // 31 for v in c)


def render(lit: bool) -> Image.Image:
    img = Image.new("RGB", (W, H))
    for y in range(H):
        for x in range(W):
            img.putpixel((x, y), _quantize(shade(x, y, lit), x, y))
    return img


def figure_layer() -> Image.Image:
    """Silueta de la entidad al fondo, proyectada en su sitio (capa transparente)."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fx, fy, fz = FIGURE_AT
    rel = (fx - CAM[0], fy - CAM[1], fz - CAM[2])
    sx = W / 2 + rel[0] / rel[2] * FOCAL
    sy = H / 2 - 18 - rel[1] / rel[2] * FOCAL
    scale = (1.85 / rel[2] * FOCAL) / 78.0  # 78 px: alto de la figura en entity.py
    for py in range(int(sy - 40), int(sy + 4)):
        for px in range(int(sx - 16), int(sx + 16)):
            x = (px + 0.5 - sx) / scale
            y = (py + 0.5 - sy) / scale
            n = fbm((x * 0.12, y * 0.1, 3.0), 7, 2)
            d = entity.body_sdf(x + (n - 0.5) * 6.0, y, 0.0) + max(0.0, (y + 30.0) / 30.0) * 9.0 * n
            if d < 0:
                img.putpixel((px, py), (6, 4, 9, 255))
            elif d < 2.5 and _dither(px, py) > 0.55:
                img.putpixel((px, py), (20, 14, 30, 200))
            mask = entity._ellipse(x, y, 1.5, -71.5, 4.6, 6.0)
            if mask < 0:
                img.putpixel((px, py), (150, 142, 128, 255))
    return img


def build() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for lit, name in ((True, "title_bg_lit.png"), (False, "title_bg_dark.png")):
        render(lit).save(OUT / name)
        print("  ", (OUT / name).relative_to(ROOT).as_posix())
    figure_layer().save(OUT / "title_figure.png")
    print("  ", (OUT / "title_figure.png").relative_to(ROOT).as_posix())


if __name__ == "__main__":
    build()
