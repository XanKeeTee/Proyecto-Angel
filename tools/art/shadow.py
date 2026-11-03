"""Sombras de contacto para los objetos del mapa (se hornean en el sprite).

- `ground`: oclusión del suelo bajo el objeto. Para cada píxel se busca el punto del suelo
  (y = 0) que se ve en él, se lanza un rayo vertical y, cuanto más baja está la pieza que
  lo tapa, más oscuro. Después se difumina un poco y se pinta solo donde no hay objeto,
  con tramado de pocos niveles para que siga pareciendo pixel art. Así las patas, ruedas
  y bases «apoyan» en el suelo en vez de flotar.
- `wall`: para lo que cuelga de la pared (lavabos, armarios de pared, cuadros…): una sombra
  arrojada de 1-2 px sobre el muro, que lo despega del fondo y lo pega a la cara del muro.
- `blend_in`: ajusta valores y saturación del objeto a los de suelos y paredes (tiles.py), para
  que el mobiliario y el decorado formen parte del escenario y no destaquen como pegatinas.
  Lo interactuable lo señala el juego (contorno de foco y destello), no el dibujo.

No toca pxrender: usa sus primitivas (`intersect`) y el resultado ya renderizado.
"""

from __future__ import annotations

from pxrender import BAYER4, RenderResult, View, norm

SHADOW_RGB = (8, 6, 12)
LEVELS = (0.0, 0.22, 0.36, 0.5)

# Curva de valor de blend_in: por debajo de KNEE casi igual; por encima, las luces se comprimen
# para que el blanco hueso de un objeto no pase mucho del tramo más claro de las paredes (~110).
KNEE = 0.24
LOW_GAIN = 0.92
HIGH_GAIN = 0.36
SATURATION = 0.7


def _ground_normal(view: View) -> tuple[int, int, int]:
    up_s = norm((0.0, view.a, -view.b))
    view_dir = norm((0.0, view.b, view.a))
    n = (0.0, 1.0, 0.0)
    ns = (0.0, n[1] * up_s[1] + n[2] * up_s[2], n[1] * view_dir[1] + n[2] * view_dir[2])
    return (128, int((ns[1] * 0.5 + 0.5) * 255), int((max(ns[2], 0.0) * 0.5 + 0.5) * 255))


def _blur(grid: list[list[float]], w: int, h: int, r: int) -> list[list[float]]:
    tmp = [[0.0] * w for _ in range(h)]
    for y in range(h):
        row = grid[y]
        for x in range(w):
            s, k = 0.0, 0
            for dx in range(-r, r + 1):
                if 0 <= x + dx < w:
                    s += row[x + dx]
                    k += 1
            tmp[y][x] = s / k
    out = [[0.0] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            s, k = 0.0, 0
            for dy in range(-r, r + 1):
                if 0 <= y + dy < h:
                    s += tmp[y + dy][x]
                    k += 1
            out[y][x] = s / k
    return out


def ground(prims: list, result: RenderResult, origin: tuple[float, float], view: View, strength: float = 1.0,
           reach: float = 34.0, blur: int = 2) -> RenderResult:
    """Añade la sombra de contacto sobre el suelo a `result` (modifica y devuelve el mismo)."""
    w, h = result.color.size
    ox, oy = origin
    # Huella horizontal de cada pieza para descartar rápido.
    boxes = []
    for p in prims:
        c = p.center
        boxes.append((c[0] - p.bound, c[0] + p.bound, c[2] - p.bound, c[2] + p.bound, c[1] - p.bound, p))
    occ = [[0.0] * w for _ in range(h)]
    up = (0.0, 1.0, 0.0)
    for py in range(h):
        v = oy - (py + 0.5)
        z = -v / view.b
        for px in range(w):
            x = px + 0.5 - ox
            best = None
            for x0, x1, z0, z1, ymin, prim in boxes:
                if x < x0 or x > x1 or z < z0 or z > z1 or ymin > reach:
                    continue
                hit = prim.intersect((x, -0.5, z), up)
                if hit is not None and (best is None or hit.t < best):
                    best = hit.t
            if best is not None:
                height = max(0.0, best - 0.5)
                occ[py][px] = max(0.0, 1.0 - height / reach) ** 1.6
    occ = _blur(occ, w, h, blur)
    nrm = _ground_normal(view)
    for py in range(h):
        for px in range(w):
            if result.depth[py * w + px] is not None or result.color.getpixel((px, py))[3] > 0:
                continue
            o = occ[py][px] * strength
            if o <= 0.02:
                continue
            threshold = (BAYER4[py % 4][px % 4] + 0.5) / 16 - 0.5
            level = int(round(o * (len(LEVELS) - 1) + threshold * 0.8))
            level = max(0, min(len(LEVELS) - 1, level))
            a = LEVELS[level]
            if a <= 0:
                continue
            result.color.putpixel((px, py), (*SHADOW_RGB, int(a * 255)))
            result.normal.putpixel((px, py), (*nrm, int(a * 255)))
    return result


def wall(result: RenderResult, offset: tuple[int, int] = (1, 2), alpha: float = 0.5) -> RenderResult:
    """Sombra arrojada sobre la pared, desplazada `offset` píxeles."""
    w, h = result.color.size
    src = result.color.copy()
    dx, dy = offset
    for py in range(h):
        for px in range(w):
            if src.getpixel((px, py))[3] > 0:
                continue
            for k in range(max(abs(dx), abs(dy)), 0, -1):
                sx = px - round(dx * k / max(abs(dx), abs(dy)))
                sy = py - round(dy * k / max(abs(dx), abs(dy)))
                if 0 <= sx < w and 0 <= sy < h and src.getpixel((sx, sy))[3] == 255:
                    a = alpha * (0.6 if k > 1 else 1.0)
                    result.color.putpixel((px, py), (*SHADOW_RGB, int(a * 255)))
                    result.normal.putpixel((px, py), (128, 128, 255, int(a * 255)))
                    break
    return result


def _fit_value(v: float) -> float:
    if v <= KNEE:
        return v * LOW_GAIN
    return KNEE * LOW_GAIN + (v - KNEE) * HIGH_GAIN


def blend_in(result: RenderResult) -> RenderResult:
    """Integra el objeto en el escenario: comprime las luces y baja la saturación.
    Los píxeles emisivos (rampas con "!") no se tocan: siguen brillando en la oscuridad."""
    w, h = result.color.size
    px = result.color.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            cell = result.depth[y * w + x] if result.depth else None
            if cell is not None and cell[0].startswith("!"):
                continue
            v = max(r, g, b) / 255.0
            if v <= 0:
                continue
            k = _fit_value(v) / v
            lum = 0.3 * r + 0.59 * g + 0.11 * b
            out = []
            for c in (r, g, b):
                c2 = lum + (c - lum) * SATURATION
                out.append(max(0, min(255, int(round(c2 * k)))))
            px[x, y] = (*out, a)
    return result


def render_shadowed(prims: list, w: int, h: int, origin: tuple[float, float], view: View, kind: str = "ground",
                    **kw) -> RenderResult:
    """Renderiza con pxrender y añade la sombra que toque ("ground", "wall" o "none")."""
    from dataclasses import replace

    from pxrender import render
    result = render(prims, w, h, origin, replace(view, outline=False))
    blend_in(result)
    if kind == "ground":
        ground(prims, result, origin, view, **kw)
    elif kind == "wall":
        wall(result, **kw)
    return result

