"""Tileset del hospital (32 px) pintado por código, con mapa de normales.

Distribución del atlas (8 columnas x 6 filas de 32 px):
  fila 0  suelo de la habitación: base, mugre, grieta, sangre arrastrada, sumidero, charco, baldosa rota, mancha
  fila 1  linóleo del pasillo:   base, rozaduras, mancha, grieta, gotas de sangre, agua, base 2, mugre
  fila 2  pared, tramo ALTO:     4 variantes, puerta, puerta abierta, puerta doble izq., puerta doble der.
  fila 3  pared, tramo MEDIO:    ídem
  fila 4  pared, tramo BAJO:     ídem
  fila 5  remate de muro, y extras: mano de sangre (medio), cartel (medio), espejo roto (medio),
          arañazos (bajo), rejilla (alto), ventana oscura (medio), sangre que chorrea (medio)
  filas 6-10  ver tiles_extra.py (sótano, quirófano, archivo, recepción, pasos de puerta)

La pared mide 3 casillas (96 px) para que la escala case con personajes realistas.
Las bases son periódicas: cualquier variante encaja con cualquier otra.
"""

from __future__ import annotations

import math
import random

from PIL import Image

import props  # noqa: F401  (registra las rampas de objetos y personaje)
from pxrender import BAYER4, RAMPS, ramp

T = 32

ramp("floor", [(16, 20, 20), (26, 32, 30), (38, 46, 42), (52, 60, 54), (66, 76, 68), (82, 92, 82)])
ramp("grout", [(10, 12, 12), (18, 22, 20), (28, 32, 30)])
ramp("lino", [(14, 16, 20), (22, 24, 30), (32, 34, 42), (44, 46, 54), (58, 60, 68), (74, 76, 84)])
ramp("paint", [(18, 24, 20), (28, 36, 30), (40, 50, 42), (54, 66, 56), (70, 82, 70), (86, 98, 84)])
ramp("plaster", [(40, 34, 28), (62, 54, 44), (86, 76, 62), (110, 98, 80), (132, 120, 98)])
ramp("mold", [(6, 10, 8), (12, 18, 14), (20, 28, 22), (30, 38, 30)])
ramp("wtile", [(22, 28, 28), (34, 42, 40), (48, 58, 54), (64, 76, 70), (82, 94, 86), (100, 112, 102)])
ramp("baseboard", [(10, 10, 14), (18, 18, 24), (28, 28, 34), (40, 40, 46)])
ramp("cap", [(6, 6, 10), (10, 10, 16), (16, 16, 24), (24, 22, 34)])
ramp("door", [(20, 26, 26), (30, 38, 38), (42, 52, 50), (56, 68, 64), (72, 84, 78)])
ramp("glass", [(4, 6, 8), (10, 14, 18), (20, 26, 30), (60, 70, 74), (140, 150, 150)])
ramp("concrete", [(20, 18, 18), (32, 30, 28), (46, 42, 38), (60, 56, 50)])
ramp("water", [(6, 8, 12), (12, 16, 22), (22, 28, 36), (70, 84, 96), (150, 166, 176)])
ramp("paper", [(60, 56, 48), (92, 86, 74), (124, 118, 102), (150, 144, 126)])


def _hash2(x: int, y: int, seed: int) -> float:
    h = (x * 374761393 + y * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def pnoise(x: float, y: float, cell: float, seed: int, px: int = T, py: int = 0) -> float:
    """Ruido de valor periódico (periodo `px` en x y `py` en y si > 0)."""
    gx, gy = x / cell, y / cell
    nx = max(1, round(px / cell)) if px else 0
    ny = max(1, round(py / cell)) if py else 0
    xi, yi = math.floor(gx), math.floor(gy)
    fx, fy = gx - xi, gy - yi
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)

    def v(ix: int, iy: int) -> float:
        if nx:
            ix %= nx
        if ny:
            iy %= ny
        return _hash2(ix, iy, seed)

    a = v(xi, yi) + (v(xi + 1, yi) - v(xi, yi)) * fx
    b = v(xi, yi + 1) + (v(xi + 1, yi + 1) - v(xi, yi + 1)) * fx
    return a + (b - a) * fy


def pfbm(x: float, y: float, seed: int, py: int = T, base: float = 8.0) -> float:
    return (pnoise(x, y, base, seed, T, py) * 0.55 + pnoise(x, y, base / 2, seed + 1, T, py) * 0.3
            + pnoise(x, y, base / 4, seed + 2, T, py) * 0.15)


class Canvas:
    """Lienzo de material + luminancia + altura; luego se reduce a rampas."""

    def __init__(self, w: int, h: int, fill: str = "floor") -> None:
        self.w, self.h = w, h
        self.mat = [[fill] * w for _ in range(h)]
        self.lum = [[0.5] * w for _ in range(h)]
        self.height = [[0.0] * w for _ in range(h)]

    def set(self, x: int, y: int, mat: str | None = None, lum: float | None = None, height: float | None = None) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            if mat is not None:
                self.mat[y][x] = mat
            if lum is not None:
                self.lum[y][x] = lum
            if height is not None:
                self.height[y][x] = height

    def blob(self, cx: float, cy: float, rx: float, ry: float, mat: str, lum: float, seed: int,
             height: float | None = None, rough: float = 0.35) -> None:
        for y in range(int(cy - ry - 3), int(cy + ry + 4)):
            for x in range(int(cx - rx - 3), int(cx + rx + 4)):
                d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
                d += (_hash2(x, y, seed) - 0.5) * rough + (pnoise(x, y, 3, seed, 0, 0) - 0.5) * rough * 2
                if d < 1.0:
                    self.set(x, y, mat, lum * (0.85 + 0.25 * _hash2(x, y, seed + 9)), height)

    def line(self, pts: list[tuple[float, float]], mat: str, lum: float, height: float | None = None, width: int = 1) -> None:
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
            for i in range(steps + 1):
                t = i / steps
                x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
                for w in range(width):
                    self.set(int(x) + w, int(y), mat, lum, height)

    def to_images(self, normal_strength: float = 1.6) -> tuple[Image.Image, Image.Image]:
        color = Image.new("RGBA", (self.w, self.h))
        normal = Image.new("RGBA", (self.w, self.h))
        for y in range(self.h):
            for x in range(self.w):
                if self.mat[y][x] == "none":
                    color.putpixel((x, y), (0, 0, 0, 0))
                    normal.putpixel((x, y), (128, 128, 255, 0))
                    continue
                colors = RAMPS[self.mat[y][x]]
                threshold = (BAYER4[y % 4][x % 4] + 0.5) / 16 - 0.5
                idx = int(round(self.lum[y][x] * (len(colors) - 1) + threshold * 0.6))
                color.putpixel((x, y), (*colors[max(0, min(len(colors) - 1, idx))], 255))
                h = self.height
                dx = h[y][(x + 1) % self.w] - h[y][(x - 1) % self.w]
                dy = h[(y + 1) % self.h][x] - h[(y - 1) % self.h][x]
                nx, ny, nz = -dx * normal_strength * 0.5, dy * normal_strength * 0.5, 1.0
                l = math.sqrt(nx * nx + ny * ny + nz * nz)
                normal.putpixel((x, y), (int((nx / l * 0.5 + 0.5) * 255), int((ny / l * 0.5 + 0.5) * 255),
                                         int((nz / l * 0.5 + 0.5) * 255), 255))
        return color, normal


def _edge_fade(x: int, margin: int = 4) -> float:
    return min(1.0, min(x, T - 1 - x) / margin)


# --- suelos ---------------------------------------------------------------------

def floor_tile(variant: int) -> Canvas:
    c = Canvas(T, T)
    rng = random.Random(100 + variant)
    for y in range(T):
        for x in range(T):
            sub = _hash2(x // 16, y // 16, 7)
            grime = pfbm(x, y, 3)
            lum = 0.42 + 0.12 * sub + 0.22 * (grime - 0.5)
            near = min(x % 16, 15 - x % 16, y % 16, 15 - y % 16)
            if near == 0:
                c.set(x, y, "grout", 0.5 + 0.3 * (grime - 0.5), -1.2)
                continue
            if near == 1:
                lum -= 0.1
            c.set(x, y, "floor", lum, 0.4 if near > 1 else 0.1)
    if variant == 1:
        for y in range(T):
            for x in range(T):
                if pfbm(x, y, 21, base=6) > 0.55 and c.mat[y][x] == "floor":
                    c.lum[y][x] *= 0.55
        for _ in range(14):
            c.set(rng.randint(3, 28), rng.randint(3, 28), "grout", 0.3, 0.8)
    elif variant == 2:
        pts = [(rng.uniform(4, 8), rng.uniform(4, 10))]
        for _ in range(4):
            pts.append((pts[-1][0] + rng.uniform(3, 7), pts[-1][1] + rng.uniform(2, 6)))
        c.line(pts, "grout", 0.1, -1.5)
        c.line([(pts[2][0], pts[2][1]), (pts[2][0] - 4, pts[2][1] + 6)], "grout", 0.2, -1.2)
    elif variant == 3:
        for i in range(20):
            t = i / 19
            c.blob(6 + t * 20, 10 + t * 12 + math.sin(t * 5) * 1.5, 3.2 - t * 1.6, 2.2, "blood_dry", 0.55 - t * 0.2, 300 + i, 0.6)
        c.blob(8, 11, 4.0, 3.0, "blood_dry", 0.35, 301, 0.7)
    elif variant == 4:
        for y in range(T):
            for x in range(T):
                d = math.hypot(x + 0.5 - 16, y + 0.5 - 16)
                if d < 7:
                    slot = (x // 2) % 2 == 0 and abs(x + 0.5 - 16) < 5.5 and abs(y + 0.5 - 16) < 5.5
                    c.set(x, y, "void" if slot else "rust", 0.3 if slot else 0.5 + 0.3 * pfbm(x, y, 5), -2.0 if slot else 0.0)
                elif d < 9.5:
                    c.set(x, y, "rust" if pfbm(x, y, 6) > 0.5 else "floor", 0.25, -0.5)
    elif variant == 5:
        c.blob(16, 17, 10, 6.5, "water", 0.18, 501, 0.0, rough=0.5)
        for x, y in ((11, 15), (12, 15), (19, 18), (20, 14)):
            c.set(x, y, "water", 0.8)
    elif variant == 6:
        for y in range(1, 16):
            for x in range(17, 32):
                c.set(x, y, "concrete", 0.35 + 0.3 * _hash2(x, y, 61), -2.0 - _hash2(x, y, 62))
        for _ in range(5):
            c.blob(rng.uniform(19, 29), rng.uniform(4, 13), 1.4, 1.0, "floor", 0.45, rng.randint(0, 999), 0.2)
    elif variant == 7:
        c.blob(15, 16, 9, 7, "stain", 0.2, 701, None, rough=0.6)
        c.blob(17, 15, 5, 4, "blood_dry", 0.25, 702, None, rough=0.6)
    return c


def lino_tile(variant: int) -> Canvas:
    c = Canvas(T, T)
    rng = random.Random(200 + variant)
    for y in range(T):
        for x in range(T):
            n = pfbm(x, y, 31, base=12)
            lum = 0.4 + 0.25 * (n - 0.5) + 0.05 * _hash2(x, y, 33)
            h = 0.0
            if y == 31:
                lum, h = 0.15, -0.8
            c.set(x, y, "lino", lum, h)
    if variant == 1:
        for _ in range(7):
            x, y = rng.uniform(2, 24), rng.uniform(3, 28)
            c.line([(x, y), (x + rng.uniform(4, 9), y + rng.uniform(-1.5, 1.5))], "lino", 0.12, -0.3)
    elif variant == 2:
        c.blob(16, 15, 8, 5.5, "stain", 0.15, 221, None)
    elif variant == 3:
        c.line([(3, 20), (9, 17), (14, 18), (20, 13), (27, 12)], "grout", 0.1, -1.4)
    elif variant == 4:
        for _ in range(6):
            c.blob(rng.uniform(5, 27), rng.uniform(5, 27), rng.uniform(0.8, 1.6), rng.uniform(0.8, 1.6), "blood_dry", 0.4,
                   rng.randint(0, 999), 0.3, rough=0.2)
    elif variant == 5:
        c.blob(15, 16, 9, 5, "water", 0.2, 251, 0.0, rough=0.5)
        c.set(12, 14, "water", 0.85)
        c.set(18, 17, "water", 0.85)
    elif variant == 7:
        for y in range(T):
            for x in range(T):
                if pfbm(x, y, 271, base=5) > 0.56:
                    c.lum[y][x] *= 0.5
    return c


# --- paredes (columna de 32x96 que se corta en 3 tiles) ----------------------------

RAIL_Y = (41, 45)
TILES_Y = 46
BASE_Y = 87


def wall_column(variant: int) -> Canvas:
    c = Canvas(T, 96)
    rng = random.Random(400 + variant)
    for y in range(96):
        for x in range(T):
            n = pfbm(x, y, 41, py=0, base=10)
            if y < RAIL_Y[0]:
                shade = 0.32 + 0.3 * (y / RAIL_Y[0])  # sombra del techo
                c.set(x, y, "paint", shade + 0.22 * (n - 0.5), 0.0)
            elif y < RAIL_Y[1]:
                lum = 0.55 if y == RAIL_Y[0] else (0.4 if y < RAIL_Y[1] - 1 else 0.2)
                mat = "rust" if pnoise(x, y, 3, 42, T, 0) > 0.7 else "metal"
                c.set(x, y, mat, lum, 2.0 if y < RAIL_Y[1] - 1 else 1.0)
            elif y < BASE_Y:
                ty = y - TILES_Y
                grout = x % 8 == 0 or ty % 8 == 7 or y == TILES_Y
                dirt = (y - TILES_Y) / (BASE_Y - TILES_Y)
                lum = 0.5 + 0.12 * (_hash2(x // 8, ty // 8, 43) - 0.5) + 0.2 * (n - 0.5) - 0.18 * dirt
                c.set(x, y, "grout" if grout else "wtile", 0.5 if grout else lum, -0.8 if grout else 0.3)
            else:
                c.set(x, y, "baseboard", 0.45 - 0.2 * ((y - BASE_Y) / 9) + 0.15 * (n - 0.5), 1.0)
    # Humedad que baja del techo, mugre en la parte baja.
    for x in range(T):
        drip = pnoise(x, 0, 3, 44 + variant, T, 0)
        if drip > 0.66 and _hash2(x, variant, 45) > 0.35:
            length = int((drip - 0.6) * 90 * (0.5 + _hash2(x, 1, 46)))
            for y in range(0, min(RAIL_Y[0], length)):
                c.set(x, y, "stain", 0.18 - y / 260)
    if variant == 1:  # pintura levantada
        cx, cy = rng.uniform(9, 23), rng.uniform(12, 30)
        for y in range(T + 9):
            for x in range(T):
                d = math.hypot((x - cx) / 7, (y - cy) / 5) + (pnoise(x, y, 3, 45, 0, 0) - 0.5) * 0.9
                if d < 1.0 and _edge_fade(x) > 0.5 and y < RAIL_Y[0]:
                    c.set(x, y, "plaster", 0.4 + 0.3 * pnoise(x, y, 2, 46, 0, 0), -0.6)
                elif d < 1.15 and _edge_fade(x) > 0.5 and y < RAIL_Y[0]:
                    c.set(x, y, "paint", 0.75, 1.2)
    elif variant == 2:  # moho junto al techo
        for y in range(16):
            for x in range(T):
                if pnoise(x, y, 4, 47, T, 0) * (1 - y / 16) > 0.32:
                    c.set(x, y, "mold", 0.3 + 0.4 * _hash2(x, y, 48), 0.6)
    elif variant == 3:  # azulejos rotos y grieta
        for y in range(TILES_Y + 16, TILES_Y + 24):
            for x in range(9, 16):
                c.set(x, y, "concrete", 0.3 + 0.3 * _hash2(x, y, 49), -1.8)
        c.line([(18, 8), (17, 15), (20, 22), (19, 30), (21, 38)], "grout", 0.1, -1.2)
    return c


def door_column(kind: str) -> Canvas:
    """kind: closed, open, double_l, double_r."""
    c = wall_column(0)
    x0, x1 = (4, 27) if kind in ("closed", "open") else ((3, 31) if kind == "double_l" else (0, 28))
    top = 10
    for y in range(top - 2, 96):
        for x in range(x0 - 2, x1 + 3):
            if 0 <= x < T:
                c.set(x, y, "metal", 0.25, 1.5)
    for y in range(top, 96):
        for x in range(x0, x1 + 1):
            if not 0 <= x < T:
                continue
            if kind == "open":
                inner = x > x0 + 3
                c.set(x, y, "void" if inner else "door", 0.15 if inner else 0.45, -3.0 if inner else 2.0)
                continue
            n = pnoise(x, y, 4, 61, 0, 0)
            lum = 0.45 + 0.15 * (n - 0.5) - 0.1 * (y / 96)
            mat = "rust" if pnoise(x, y, 3, 62, 0, 0) > 0.82 else "door"
            c.set(x, y, mat, lum, 0.8 + 0.6 * (n - 0.5))
    if kind == "closed":
        for y in range(22, 38):
            for x in range(10, 22):
                edge = y in (22, 37) or x in (10, 21)
                mesh = (x + y) % 4 == 0 or (x - y) % 4 == 0
                c.set(x, y, "metal" if edge else "glass", 0.4 if edge else (0.35 if mesh else 0.12), 1.0 if edge else -1.0)
        c.set(12, 24, "glass", 0.9)
        for y in range(54, 58):
            c.set(23, y, "metal", 0.8, 2.5)
            c.set(24, y, "metal", 0.5, 2.5)
    if kind in ("closed", "double_l", "double_r"):
        for y in range(80, 94):
            for x in range(x0 + 1, x1):
                if 0 <= x < T:
                    c.set(x, y, "metal", 0.22 + 0.15 * _hash2(x, y // 3, 63), 1.2)
    if kind in ("double_l", "double_r"):
        cx = 18 if kind == "double_l" else 13
        for y in range(18, 40):
            for x in range(T):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - 28)
                if d < 6:
                    c.set(x, y, "glass", 0.12 if d < 5 else 0.0, -1.0)
                elif d < 7.2:
                    c.set(x, y, "metal", 0.5, 1.5)
        c.set(cx - 2, 26, "glass", 0.9)
        seam = 31 if kind == "double_l" else 0
        for y in range(top, 96):
            c.set(seam, y, "void", 0.1, -2.0)
        px = 22 if kind == "double_l" else 4
        for y in range(52, 64):
            for x in range(px, px + 6):
                c.set(x, y, "metal", 0.6, 1.8)
    return c


def cap_tile() -> Canvas:
    c = Canvas(T, T)
    for y in range(T):
        for x in range(T):
            c.set(x, y, "cap", 0.35 + 0.3 * (pfbm(x, y, 81) - 0.5), 0.0)
    return c


# --- extras sobre la pared -------------------------------------------------------

def handprint(c: Canvas, ox: int, oy: int) -> None:
    c.blob(ox + 16, oy + 18, 4.2, 4.8, "blood_dry", 0.45, 901, 0.3, rough=0.4)
    for i, (dx, length, ang) in enumerate(((-4, 6, -0.45), (-1.5, 8, -0.12), (1, 8.5, 0.05), (3.5, 7, 0.25), (5.5, 4.5, 0.85))):
        x0, y0 = ox + 16 + dx, oy + 15
        c.line([(x0, y0), (x0 + math.sin(ang) * length, y0 - math.cos(ang) * length)], "blood_dry", 0.5, 0.3)
    for i, x in enumerate((13, 16, 19)):
        c.line([(ox + x, oy + 22), (ox + x + 0.3, oy + 26 + i * 2)], "blood_dry", 0.35, 0.2)


def wall_extra(kind: str) -> Canvas:
    col = wall_column(0)
    c = Canvas(T, T)
    row = {"handprint": 1, "notice": 1, "mirror": 1, "scratch": 2, "vent": 0, "window": 1, "smear": 1}[kind]
    for y in range(T):
        for x in range(T):
            c.set(x, y, col.mat[row * T + y][x], col.lum[row * T + y][x], col.height[row * T + y][x])
    if kind == "handprint":
        handprint(c, 0, 0)
    elif kind == "notice":
        for y in range(1, 22):
            for x in range(7, 25):
                c.set(x, y, "paper", 0.55 + 0.2 * _hash2(x, y, 911) - (0.25 if (y - 4) % 3 == 0 and 9 < x < 23 else 0), 0.5)
        for dx in (0, 2, 4, 6):
            c.line([(11 + dx, 3), (14 + dx, 20)], "void", 0.2, -0.5)
    elif kind == "mirror":
        for y in range(0, 26):
            for x in range(6, 26):
                edge = y in (0, 25) or x in (6, 25)
                c.set(x, y, "metal" if edge else "glass", 0.5 if edge else 0.18 + 0.08 * (y / 26), 1.0 if edge else 0.0)
        for ang in (0.3, 1.4, 2.2, 3.5, 4.4, 5.6):
            c.line([(17, 11), (17 + math.cos(ang) * 9, 11 + math.sin(ang) * 9)], "glass", 0.75, 0.2)
    elif kind == "scratch":
        for i in range(4):
            c.line([(8 + i * 3, 2), (11 + i * 3, 24)], "void", 0.1, -1.0)
    elif kind == "vent":
        for y in range(8, 24):
            for x in range(6, 26):
                edge = y in (8, 23) or x in (6, 25)
                slot = y % 3 == 0
                c.set(x, y, "metal" if edge or not slot else "void", 0.4 if edge else (0.3 if not slot else 0.1),
                      1.0 if not slot else -1.0)
        for y in range(24, 32):
            c.set(15, y, "rust", 0.4)
            c.set(16, y, "rust", 0.3)
    elif kind == "window":
        for y in range(2, 30):
            for x in range(3, 29):
                edge = y in (2, 29) or x in (3, 28)
                blind = (y % 4 == 0) and not (12 < x < 20 and y > 14)
                c.set(x, y, "metal" if edge else ("door" if blind else "glass"), 0.45 if edge else (0.3 if blind else 0.06),
                      1.0 if edge else (0.3 if blind else -1.0))
    elif kind == "smear":
        for y in range(T):
            w = 4.5 - y * 0.06 + math.sin(y * 0.4) * 0.8
            for x in range(T):
                if abs(x - 15 - math.sin(y * 0.2) * 1.5) < w and pnoise(x, y, 2, 931, 0, 0) > 0.25:
                    c.set(x, y, "blood_dry", 0.35 + 0.2 * _hash2(x, y, 932), 0.2)
    return c


# --- montaje ----------------------------------------------------------------------

def build() -> tuple[Image.Image, Image.Image]:
    color = Image.new("RGBA", (T * 8, T * 11))
    normal = Image.new("RGBA", (T * 8, T * 11))

    def put(canvas: Canvas, col: int, row: int) -> None:
        img, nrm = canvas.to_images()
        color.paste(img, (col * T, row * T))
        normal.paste(nrm, (col * T, row * T))

    for v in range(8):
        put(floor_tile(v), v, 0)
        put(lino_tile(v), v, 1)
    columns = [wall_column(v) for v in range(4)] + [door_column(k) for k in ("closed", "open", "double_l", "double_r")]
    for i, column in enumerate(columns):
        for part in range(3):
            sub = Canvas(T, T)
            for y in range(T):
                for x in range(T):
                    sub.set(x, y, column.mat[part * T + y][x], column.lum[part * T + y][x], column.height[part * T + y][x])
            put(sub, i, 2 + part)
    put(cap_tile(), 0, 5)
    for i, kind in enumerate(("handprint", "notice", "mirror", "scratch", "vent", "window", "smear")):
        put(wall_extra(kind), i + 1, 5)
    import tiles_extra
    tiles_extra.build_into(color, normal)
    return color, normal
