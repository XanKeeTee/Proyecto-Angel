"""Calcomanías del hospital: suelo (32x32), suelo grande (64x64) y pared (32x96).

Se dibujan con el `Canvas` de tiles.py (material + luminancia + altura → rampas con tramado
y mapa de normales). El fondo es transparente: se ponen encima del tileset en el nodo
`Decals` de la escena (por debajo de los objetos), así el suelo y las paredes ganan
variedad y desgaste sin tocar el atlas.

- `floor`  (32x32): huellas, papeles, cristales, gotas, arrastre (las 5 primeras, que ya
  usaba la escena) y desgaste y basura: grietas, baldosa rota, mugre, moho, charcos,
  rodadas, óxido, aceite, polvo, pastillas, cables, gasas, jeringa, cinta, tornillos,
  pelo, colillas, rejilla de desagüe y sombras de rincón (`wallbase`, `corner`).
  `doorway`: el desgaste del suelo delante de una puerta (la puerta queda arriba): rozado
  claro donde se pisa, rodadas de camilla que entran y rozaduras. Indica una puerta sin cartel.
- `floor_big` (64x64): charco, cerco de humedad, sangre seca, aceite, mugre, moho,
  quemadura, cerco de óxido y sábana tirada.
- `wall` (32x96, la columna entera de pared): humedad, moho, pintura levantada, grieta,
  enchufe, interruptor, tuberías, conducto eléctrico, caja de registro, cartel roto,
  telaraña, mugre baja, rozaduras de camilla, mancha de mano baja, tomas de oxígeno,
  timbre de llamada y señal de salida (con capa de brillo).
"""

from __future__ import annotations

import math
import random

from PIL import Image

import tiles
import materials  # noqa: F401  (rampas compartidas: cable, tape, pill, hair…)
from pxrender import ramp
from tiles import RAIL_Y, TILES_Y, Canvas, _hash2, pnoise

ramp("dust", [(40, 38, 34), (56, 52, 46), (72, 68, 60), (88, 84, 74)])
ramp("grime", [(8, 8, 8), (14, 13, 12), (22, 20, 18), (30, 28, 25)])
ramp("moss", [(10, 16, 10), (18, 28, 16), (28, 42, 22), (40, 56, 30), (54, 70, 38)])
ramp("pill_red", [(70, 20, 20), (110, 34, 30), (150, 56, 48)])
ramp("scorch", [(4, 4, 4), (10, 9, 8), (18, 16, 14), (28, 24, 20)])
ramp("exit_green", [(30, 90, 50), (60, 150, 80), (130, 220, 150), (210, 250, 220)])
ramp("plate", [(30, 34, 34), (52, 58, 56), (80, 88, 84), (110, 118, 112), (140, 146, 138)])
ramp("web", [(70, 72, 70), (100, 102, 98), (130, 132, 126)])

FLOOR = ["footprints", "papers", "glass", "drops", "drag",
         "crack", "crack_b", "tile_broken", "grime", "mold", "puddle", "tracks", "rust", "oil", "dust",
         "pills", "cables", "gauze", "syringe", "tape", "screws", "hair", "butts", "drain", "wallbase", "corner",
         "smear", "bandage", "leaflets", "contact", "doorway"]
FLOOR_BIG = ["puddle_big", "damp_big", "blood_big", "oil_big", "grime_big", "mold_big", "scorch", "rust_big", "sheet"]
WALL = ["damp", "mold_top", "peel", "crack_w", "socket", "switch", "pipe_v", "pipes_v2", "conduit", "junction",
        "poster", "cobweb", "grime_low", "scrapes", "hand_low", "oxygen", "call", "exit", "drip_rust", "pipe_h"]


# --- utilidades -------------------------------------------------------------------------

def _speck(c: Canvas, rng: random.Random, n: int, mat: str, lum: tuple[float, float], area: tuple[int, int, int, int],
           height: float = 0.3) -> None:
    x0, y0, x1, y1 = area
    for _ in range(n):
        c.set(rng.randint(x0, x1), rng.randint(y0, y1), mat, rng.uniform(*lum), height)


def _soft(c: Canvas, cx: float, cy: float, rx: float, ry: float, mat: str, lum: float, seed: int, cut: float = 0.5,
          height: float | None = None) -> None:
    """Mancha difusa: solo pinta donde el ruido supera el borde (bordes deshilachados)."""
    for y in range(int(cy - ry - 2), int(cy + ry + 3)):
        for x in range(int(cx - rx - 2), int(cx + rx + 3)):
            d = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
            n = pnoise(x, y, 3, seed, 0, 0) * 0.6 + pnoise(x, y, 1.5, seed + 1, 0, 0) * 0.4
            if d < 1.0 and n > cut * (0.4 + 0.8 * d):
                c.set(x, y, mat, lum * (0.8 + 0.4 * _hash2(x, y, seed + 2)) * (1.15 - 0.35 * d), height)


def _crack(c: Canvas, rng: random.Random, x: float, y: float, ang: float, length: float, branch: int = 2) -> None:
    pts = [(x, y)]
    for _ in range(int(length / 3)):
        ang += rng.uniform(-0.6, 0.6)
        pts.append((pts[-1][0] + math.cos(ang) * 3, pts[-1][1] + math.sin(ang) * 3))
    c.line(pts, "grout", 0.05, -1.5)
    for p in pts[1:]:
        if rng.random() < 0.25:
            c.set(int(p[0]) + 1, int(p[1]), "grout", 0.35, -0.6)
    if branch > 0:
        k = rng.randint(1, max(1, len(pts) - 2))
        _crack(c, rng, pts[k][0], pts[k][1], ang + rng.choice((-1.0, 1.0)), length * 0.45, branch - 1)


# --- suelo 32x32 --------------------------------------------------------------------------

def floor_decal(name: str) -> Canvas:
    c = Canvas(32, 32, fill="none")
    rng = random.Random(sum(map(ord, name)) * 31)
    if name == "footprints":
        for fx, fy, flip in ((10, 9, -1), (22, 22, 1)):
            c.blob(fx, fy + 1, 1.8, 3.6, "water", 0.12, 1000 + fx, -0.2, rough=0.15)
            c.blob(fx + flip * 0.3, fy - 3.2, 1.6, 1.2, "water", 0.12, 1100 + fx, -0.2, rough=0.1)
            for t in range(5):
                c.set(int(fx - 2 + t), int(fy - 5.5 + abs(t - 1.5) * 0.4), "water", 0.15, -0.2)
            c.set(fx, fy, "water", 0.85)
    elif name in ("papers", "leaflets"):
        count = 3 if name == "papers" else 5
        for k in range(count):
            cx, cy = rng.uniform(8, 24), rng.uniform(8, 24)
            ang = rng.uniform(0, math.pi)
            hw, hh = (4, 5.5) if name == "papers" else (2.6, 3.6)
            for y in range(32):
                for x in range(32):
                    dx, dy = x - cx, y - cy
                    u = dx * math.cos(ang) + dy * math.sin(ang)
                    w = -dx * math.sin(ang) + dy * math.cos(ang)
                    if abs(u) < hw and abs(w) < hh:
                        edge = abs(u) > hw - 1 or abs(w) > hh - 1
                        line = int(w + 10) % 2 == 0 and abs(u) < hw - 1.2 and abs(w) < hh - 1.5
                        lum = 0.28 if line else 0.62 + 0.18 * tiles._hash2(x, y, 3) - (0.1 if edge else 0)
                        if tiles.pnoise(x, y, 4, 77 + k, 0, 0) > 0.72:
                            c.set(x, y, "stain", 0.5, 0.4)
                        else:
                            c.set(x, y, "paper", lum, 0.4 + 0.2 * k)
        if name == "papers":
            c.blob(17, 18, 2.5, 1.8, "blood_dry", 0.4, 1201, 0.5)
    elif name == "glass":
        for _ in range(11):
            x, y = rng.randint(5, 27), rng.randint(5, 27)
            c.line([(x, y), (x + rng.choice((-2, 2, 3)), y + rng.choice((-1, 1)))], "glass", 0.6, 0.5)
            c.set(x, y, "glass", 1.0, 0.8)
        for _ in range(14):
            c.set(rng.randint(3, 29), rng.randint(3, 29), "glass", rng.uniform(0.5, 1.0), 0.4)
    elif name == "drops":
        for _ in range(7):
            c.blob(rng.uniform(4, 28), rng.uniform(4, 28), rng.uniform(0.7, 1.5), rng.uniform(0.7, 1.4),
                   "blood_dry", 0.4, rng.randint(0, 9999), 0.3, rough=0.2)
    elif name == "drag":
        for x in range(32):
            y0 = 16 + math.sin(x * 0.25) * 1.5
            width = 3.0 + 1.2 * tiles.pnoise(x, 0, 4, 1301, 32, 0)
            for y in range(32):
                if abs(y - y0) < width and tiles.pnoise(x, y, 2, 1302, 32, 0) > 0.3:
                    c.set(x, y, "blood_dry", 0.25 + 0.25 * tiles._hash2(x, y, 1303), 0.2)
    elif name in ("crack", "crack_b"):
        _crack(c, rng, rng.uniform(2, 8), rng.uniform(6, 26), rng.uniform(-0.4, 0.4), 30 if name == "crack" else 22, 2)
        if name == "crack_b":
            _crack(c, rng, 16, 16, rng.uniform(1.0, 2.0), 16, 1)
    elif name == "tile_broken":
        # Una baldosa (16x16) hundida y partida: se ve el mortero.
        x0, y0 = 8, 8
        for y in range(y0, y0 + 16):
            for x in range(x0, x0 + 16):
                if pnoise(x, y, 3, 1401, 0, 0) > 0.42:
                    c.set(x, y, "concrete", 0.25 + 0.35 * _hash2(x, y, 1402), -1.8 - _hash2(x, y, 1403))
                else:
                    c.set(x, y, "floor", 0.22 + 0.15 * _hash2(x, y, 1404), -0.6)
        for _ in range(5):
            c.blob(rng.uniform(4, 28), rng.uniform(4, 28), 1.2, 0.9, "floor", 0.4, rng.randint(0, 999), 0.6)
        _crack(c, rng, x0, y0 + 4, 0.2, 16, 1)
    elif name == "grime":
        _soft(c, 16, 16, 14, 13, "grime", 0.5, 1501, 0.45)
    elif name == "mold":
        _soft(c, 16, 16, 13, 12, "moss", 0.45, 1601, 0.5, 0.3)
        _speck(c, rng, 18, "moss", (0.5, 0.9), (4, 4, 28, 28), 0.5)
    elif name == "puddle":
        c.blob(16, 17, 10, 6.5, "water", 0.18, 1701, -0.2, rough=0.5)
        for x, y in ((11, 15), (12, 15), (19, 18), (20, 14)):
            c.set(x, y, "water", 0.85, -0.1)
    elif name == "tracks":
        for lane in (11, 21):
            for y in range(32):
                for x in range(lane - 1, lane + 2):
                    if pnoise(x, y, 3, 1801 + lane, 0, 0) > 0.35:
                        c.set(x + int(math.sin(y * 0.15) * 1.5), y, "grime", 0.35 + 0.3 * _hash2(x, y, 1802), -0.1)
    elif name == "rust":
        _soft(c, 16, 16, 12, 10, "rust", 0.35, 1901, 0.45)
        c.blob(16, 16, 5, 3.5, "rust", 0.25, 1902, None, rough=0.6)
    elif name == "oil":
        c.blob(15, 17, 9, 6, "oil", 0.45, 2001, -0.1, rough=0.6)
        c.set(13, 14, "oil", 1.0)
        c.set(18, 19, "oil", 0.9)
    elif name == "dust":
        for y in range(32):
            for x in range(32):
                if pnoise(x, y, 4, 2101, 0, 0) * (1 - math.hypot(x - 16, y - 16) / 18) > 0.25 and _hash2(x, y, 2102) > 0.35:
                    c.set(x, y, "dust", 0.3 + 0.4 * _hash2(x, y, 2103), 0.0)
    elif name == "pills":
        for _ in range(9):
            x, y = rng.randint(5, 26), rng.randint(5, 26)
            mat = "pill_red" if rng.random() < 0.3 else "pill"
            c.set(x, y, mat, 0.9, 0.8)
            c.set(x + 1, y, mat, 0.6, 0.8)
            c.set(x, y + 1, "grime", 0.2, 0.0)
        # Bote volcado.
        for y in range(18, 23):
            for x in range(20, 28):
                c.set(x, y, "amber" if y > 18 else "pill", 0.4 + 0.3 * (y == 19), 1.5)
        for y in range(18, 23):
            c.set(28, y, "pill", 0.8, 1.6)
    elif name == "cables":
        for k in range(3):
            y = rng.uniform(6, 26)
            pts = []
            for i in range(9):
                x = -2 + i * 4.5
                pts.append((x, y + math.sin(i * 0.9 + k * 2) * 3))
            c.line(pts, "cable", 0.5 + 0.15 * k, 1.0, width=1 if k else 2)
    elif name in ("gauze", "bandage"):
        for k in range(2 if name == "gauze" else 1):
            cx, cy = rng.uniform(10, 22), rng.uniform(10, 22)
            c.blob(cx, cy, 4.5, 3.5, "gauze", 0.75, 2201 + k, 0.8, rough=0.6)
            c.blob(cx + 1, cy, 2.0, 1.5, "blood_dry", 0.45, 2211 + k, 0.9, rough=0.5)
        if name == "bandage":
            pts = [(6, 22), (10, 19), (16, 21), (22, 18), (27, 20)]
            c.line(pts, "gauze", 0.85, 0.6, width=2)
    elif name == "syringe":
        c.line([(9, 21), (22, 12)], "clear_plastic" if "clear_plastic" in tiles.RAMPS else "glass", 0.8, 1.2, width=2)
        c.line([(22, 12), (27, 9)], "metal", 0.9, 0.8)
        c.line([(7, 22), (9, 21)], "plastic", 0.6, 1.4, width=2)
        c.set(15, 17, "blood_dry", 0.6, 1.3)
        c.set(16, 16, "blood_dry", 0.5, 1.3)
    elif name == "tape":
        # Cinta magnética desenrollada por el suelo.
        pts = []
        for i in range(40):
            t = i / 39
            pts.append((4 + t * 24 + math.sin(t * 9) * 3, 16 + math.sin(t * 13) * 7 * (1 - t * 0.5)))
        c.line(pts, "tape", 0.6, 0.3)
        c.blob(8, 24, 3.2, 2.2, "plastic", 0.4, 2301, 1.2, rough=0.1)
    elif name == "screws":
        for _ in range(8):
            x, y = rng.randint(4, 27), rng.randint(4, 27)
            c.set(x, y, "metal", 0.85, 0.8)
            c.set(x + 1, y, "metal", 0.5, 0.6)
        c.line([(6, 25), (14, 23)], "metal", 0.6, 0.8)
    elif name == "hair":
        for k in range(14):
            x, y = rng.uniform(8, 24), rng.uniform(8, 24)
            pts = [(x, y)]
            ang = rng.uniform(0, math.tau)
            for _ in range(4):
                ang += rng.uniform(-0.8, 0.8)
                pts.append((pts[-1][0] + math.cos(ang) * 2.5, pts[-1][1] + math.sin(ang) * 2.5))
            c.line(pts, "hair", 0.6, 0.1)
    elif name == "butts":
        for _ in range(5):
            x, y = rng.randint(5, 25), rng.randint(5, 25)
            c.set(x, y, "stain", 0.8, 0.6)
            c.set(x + 1, y, "paper", 0.7, 0.6)
            c.set(x + 2, y, "paper", 0.6, 0.6)
        _soft(c, 16, 16, 8, 6, "dust", 0.35, 2401, 0.55)
    elif name == "drain":
        for y in range(8, 24):
            for x in range(8, 24):
                d = math.hypot(x + 0.5 - 16, y + 0.5 - 16)
                if d < 7.5:
                    slot = (x % 3 == 0) and d < 6.0
                    c.set(x, y, "void" if slot else "metal", 0.1 if slot else 0.35 + 0.2 * _hash2(x, y, 2501),
                          -1.5 if slot else 0.2)
                elif d < 9:
                    c.set(x, y, "rust", 0.3 + 0.2 * _hash2(x, y, 2502), -0.4)
    elif name == "wallbase":
        # Sombra de contacto y mugre al pie de una pared (borde superior de la casilla).
        for y in range(9):
            for x in range(32):
                k = 1 - y / 9
                if _hash2(x, y, 2601) < k * 0.95 + 0.1 * pnoise(x, y, 4, 2602, 32, 0):
                    c.set(x, y, "grime", 0.15 + 0.25 * (1 - k) + 0.1 * _hash2(x, y, 2603), -0.2)
    elif name == "corner":
        for y in range(14):
            for x in range(14):
                k = 1 - math.hypot(x, y) / 14
                if k > 0 and _hash2(x, y, 2701) < k * 1.2:
                    c.set(x, y, "grime", 0.1 + 0.3 * (1 - k), -0.2)
                    if pnoise(x, y, 3, 2702, 0, 0) > 0.7:
                        c.set(x, y, "dust", 0.35, 0.0)
    elif name == "contact":
        # Sombra de contacto suave para objetos sueltos en el suelo.
        for y in range(32):
            for x in range(32):
                d = math.hypot((x + 0.5 - 16) / 10.5, (y + 0.5 - 16) / 4.5)
                if d < 1.0 and _hash2(x, y, 2901) < (1.15 - d) * 1.1:
                    c.set(x, y, "grime", 0.05 + 0.2 * d, -0.1)
    elif name == "doorway":
        # Desgaste delante de la puerta (arriba): más fuerte junto al umbral, se pierde hacia abajo.
        for y in range(30):
            fade = 1.0 - y / 30
            half = 11 - 4 * (y / 30)
            for x in range(32):
                if abs(x + 0.5 - 16) > half:
                    continue
                n = pnoise(x, y, 3, 3001, 0, 0) * 0.6 + pnoise(x, y, 1.5, 3002, 0, 0) * 0.4
                if n < 0.1 + 0.6 * fade and _hash2(x, y, 3007) < 0.75:
                    c.set(x, y, "dust", 0.04 + 0.12 * fade * _hash2(x, y, 3003), -0.05)
        for lane in (10, 22):  # rodadas de camilla que cruzan la puerta
            for y in range(26):
                if pnoise(lane, y, 2, 3004 + lane, 0, 0) < 0.8 - y / 40:
                    c.set(lane + int(math.sin(y * 0.2 + lane) * 0.8), y, "grime", 0.3 + 0.2 * _hash2(lane, y, 3005), -0.1)
        for _ in range(5):  # rozaduras de suela junto al umbral
            x, y = rng.uniform(7, 22), rng.uniform(2, 9)
            c.line([(x, y), (x + rng.uniform(2, 5), y + rng.uniform(-0.6, 0.6))], "grime", 0.25, -0.1)
        for x in range(6, 27):  # sombra corta del umbral
            if _hash2(x, 0, 3006) < 0.85:
                c.set(x, 0, "grime", 0.08, -0.3)
    elif name == "smear":
        for i in range(24):
            t = i / 23
            c.blob(4 + t * 24, 16 + math.sin(t * 4) * 3, 2.6 - t, 2.2 - t * 0.8, "blood_dry", 0.35 + 0.15 * (1 - t),
                   2801 + i, 0.2, rough=0.6)
        for k in range(4):
            c.line([(5, 13 + k * 2), (13, 13 + k * 2 + 1)], "blood_dry", 0.25, 0.2)
    return c


# --- suelo grande 64x64 --------------------------------------------------------------------

def big_decal(name: str) -> Canvas:
    c = Canvas(64, 64, fill="none")
    rng = random.Random(sum(map(ord, name)) * 17)
    if name == "puddle_big":
        c.blob(32, 34, 24, 15, "water", 0.16, 3001, -0.3, rough=0.7)
        c.blob(18, 22, 8, 5, "water", 0.2, 3002, -0.3, rough=0.6)
        for _ in range(6):
            c.set(rng.randint(14, 50), rng.randint(24, 44), "water", 0.9, -0.2)
        for y in range(64):
            for x in range(64):
                if c.mat[y][x] == "water" and pnoise(x, y, 6, 3003, 0, 0) > 0.72:
                    c.lum[y][x] = 0.45
    elif name == "damp_big":
        for ring, lum in ((26, 0.12), (21, 0.2), (15, 0.14)):
            for y in range(64):
                for x in range(64):
                    d = math.hypot(x + 0.5 - 32, (y + 0.5 - 32) * 1.2) + (pnoise(x, y, 6, 3101, 0, 0) - 0.5) * 9
                    if abs(d - ring) < 1.2:
                        c.set(x, y, "stain", lum, 0.0)
        _soft(c, 32, 32, 20, 16, "grime", 0.35, 3102, 0.6)
    elif name == "blood_big":
        c.blob(30, 32, 16, 11, "blood_dry", 0.3, 3201, 0.1, rough=0.8)
        c.blob(44, 40, 6, 4, "blood_dry", 0.25, 3202, 0.1, rough=0.6)
        for y in range(64):
            for x in range(64):
                if c.mat[y][x] == "blood_dry" and pnoise(x, y, 4, 3203, 0, 0) > 0.6:
                    c.lum[y][x] = 0.12
        for _ in range(9):
            c.blob(rng.uniform(6, 58), rng.uniform(6, 58), 1.2, 1.0, "blood_dry", 0.35, rng.randint(0, 999), 0.1)
    elif name == "oil_big":
        c.blob(32, 32, 22, 14, "oil", 0.35, 3301, -0.1, rough=0.8)
        for y in range(64):
            for x in range(64):
                if c.mat[y][x] == "oil" and pnoise(x, y, 5, 3302, 0, 0) > 0.66:
                    c.lum[y][x] = 0.95
    elif name == "grime_big":
        _soft(c, 32, 32, 30, 26, "grime", 0.45, 3401, 0.42)
    elif name == "mold_big":
        _soft(c, 32, 32, 28, 22, "moss", 0.45, 3501, 0.42, 0.3)
        _soft(c, 30, 30, 14, 10, "grime", 0.3, 3502, 0.5)
        _speck(c, rng, 40, "moss", (0.5, 1.0), (6, 6, 58, 58), 0.6)
    elif name == "scorch":
        _soft(c, 32, 32, 22, 20, "scorch", 0.5, 3601, 0.3)
        _soft(c, 32, 32, 10, 9, "scorch", 0.15, 3602, 0.2)
        _speck(c, rng, 20, "grime", (0.5, 0.9), (10, 10, 54, 54))
    elif name == "rust_big":
        _soft(c, 32, 32, 26, 18, "rust", 0.35, 3701, 0.4)
        _soft(c, 32, 34, 16, 10, "oil", 0.3, 3702, 0.5)
    elif name == "sheet":
        # Sábana tirada en el suelo, arrugada, con el bajo sucio.
        for y in range(64):
            for x in range(64):
                d = math.hypot((x - 32) / 26, (y - 32) / 18) + (pnoise(x, y, 7, 3801, 0, 0) - 0.5) * 0.7
                if d < 1.0:
                    fold = math.sin(x * 0.45 + pnoise(x, y, 9, 3802, 0, 0) * 6)
                    mat = "stain" if pnoise(x, y, 5, 3803, 0, 0) > 0.7 or d > 0.85 else "sheet"
                    c.set(x, y, mat, 0.3 + 0.18 * fold, 1.0 + fold)
    return c


# --- pared 32x96 ---------------------------------------------------------------------------

def _box(c: Canvas, x0: int, y0: int, x1: int, y1: int, mat: str, lum: float, height: float, rim: str | None = None,
         rim_lum: float = 0.25) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            edge = x in (x0, x1) or y in (y0, y1)
            if edge and rim is not None:
                c.set(x, y, rim, rim_lum if (x == x1 or y == y1) else rim_lum + 0.3, height)
            else:
                c.set(x, y, mat, lum - (0.12 if x == x1 or y == y1 else 0) + (0.1 if x == x0 or y == y0 else 0), height)


def _shadow_box(c: Canvas, x0: int, y0: int, x1: int, y1: int) -> None:
    """Sombra arrojada de 1 px abajo-derecha de un elemento pegado a la pared."""
    for y in range(y0 + 1, y1 + 2):
        c.set(x1 + 1, y, "grime", 0.1, -0.2)
    for x in range(x0 + 1, x1 + 2):
        c.set(x, y1 + 1, "grime", 0.1, -0.2)


def _pipe_v(c: Canvas, x: int, r: int, mat_fn, top: int = 0, bottom: int = 96, seed: int = 0) -> None:
    for y in range(top, bottom):
        for dx in range(-r, r + 1):
            d = dx / (r + 0.5)
            m = "rust" if pnoise(x + dx, y, 4, 4001 + seed, 0, 0) > 0.64 else mat_fn
            c.set(x + dx, y, m, 0.42 - 0.3 * d - 0.2 * abs(d), 2.5 * (1 - abs(d)))
        c.set(x + r + 1, y, "grime", 0.1, -0.2)
    for by in range(top + 10, bottom, 26):  # abrazaderas
        for y in range(by, by + 3):
            for dx in range(-r - 1, r + 2):
                c.set(x + dx, y, "metal", 0.55 if y == by else 0.3, 3.0)


def wall_decal(name: str) -> tuple[Canvas, Canvas | None]:
    """Devuelve (lienzo, brillo) de una columna de pared transparente de 32x96."""
    c = Canvas(32, 96, fill="none")
    glow = None
    rng = random.Random(sum(map(ord, name)) * 13)
    if name == "damp":
        cx = rng.uniform(10, 22)
        for y in range(70):
            w = 6 + 5 * math.sin(y * 0.05) + 3 * pnoise(0, y, 6, 4101, 0, 0)
            for x in range(32):
                n = pnoise(x, y, 3, 4102, 0, 0)
                d = abs(x - cx) / w
                if d < 1 and n > 0.3 + 0.6 * d * d + y / 160:
                    edge = d > 0.75
                    c.set(x, y, "stain", (0.35 if edge else 0.18) - y / 500, None)
    elif name == "mold_top":
        for y in range(30):
            for x in range(32):
                n = pnoise(x, y, 4, 4201, 32, 0) * (1 - y / 30) + 0.15 * _hash2(x, y, 4202)
                if n > 0.42:
                    c.set(x, y, "moss" if n > 0.5 else "mold", 0.25 + 0.5 * _hash2(x, y, 4203), 0.6)
    elif name == "peel":
        cx, cy = rng.uniform(10, 22), rng.uniform(14, 30)
        for y in range(0, RAIL_Y[0]):
            for x in range(32):
                d = math.hypot((x - cx) / 8, (y - cy) / 6) + (pnoise(x, y, 3, 4301, 0, 0) - 0.5) * 0.9
                if d < 1.0:
                    c.set(x, y, "plaster", 0.35 + 0.35 * pnoise(x, y, 2, 4302, 0, 0), -0.6)
                elif d < 1.18:
                    c.set(x, y, "paint", 0.78, 1.4)
                elif d < 1.3 and y > cy:
                    c.set(x, y, "grime", 0.2, -0.1)
        # Lascas caídas sobre la barandilla.
        for _ in range(4):
            c.set(rng.randint(6, 26), RAIL_Y[0] - 1, "paint", 0.7, 1.0)
    elif name == "crack_w":
        _crack(c, rng, rng.uniform(8, 24), 0, math.pi / 2 + rng.uniform(-0.3, 0.3), 80, 2)
    elif name == "socket":
        # Enchufe doble en el azulejo, a media altura de la parte baja.
        x0, y0 = 10, 66
        _box(c, x0, y0, x0 + 11, y0 + 7, "white_plastic" if "white_plastic" in tiles.RAMPS else "gauze", 0.55, 1.6, "plate", 0.3)
        for hx in (x0 + 3, x0 + 8):
            c.set(hx, y0 + 3, "void", 0.1, -1.0)
            c.set(hx, y0 + 4, "void", 0.1, -1.0)
        _shadow_box(c, x0, y0, x0 + 11, y0 + 7)
        c.blob(x0 + 6, y0 + 9, 3, 1.5, "grime", 0.3, 4401, None)
    elif name == "switch":
        x0, y0 = 12, 50
        c.blob(x0 + 4, y0 + 5, 4.5, 6.5, "grime", 0.4, 4501, None, rough=0.7)  # dedos
        _box(c, x0, y0, x0 + 7, y0 + 10, "gauze", 0.6, 1.6, "plate", 0.3)
        for y in range(y0 + 3, y0 + 8):
            c.set(x0 + 3, y, "plate", 0.75, 2.2)
            c.set(x0 + 4, y, "plate", 0.45, 2.2)
        _shadow_box(c, x0, y0, x0 + 7, y0 + 10)
        for y in range(y0 + 10, 96):  # tubo de la instalación vista
            c.set(x0 + 4, y, "plate", 0.4, 1.2)
            c.set(x0 + 5, y, "grime", 0.1, -0.2)
    elif name == "pipe_v":
        _pipe_v(c, 18, 3, "metal", seed=1)
        # Fuga: chorreo y cerco de óxido.
        for y in range(40, 96):
            if pnoise(18, y, 4, 4601, 0, 0) > 0.4:
                c.set(15, y, "rust", 0.3, None)
    elif name == "pipes_v2":
        _pipe_v(c, 8, 2, "metal", seed=2)
        _pipe_v(c, 20, 1, "metal", seed=3)
        for y in range(20, 26):  # válvula
            for x in range(4, 13):
                c.set(x, y, "rust" if x % 3 == 0 else "metal", 0.6 if y == 20 else 0.4, 3.2)
    elif name == "conduit":
        for y in range(96):
            c.set(23, y, "plate", 0.55, 2.0)
            c.set(24, y, "plate", 0.35, 2.0)
            c.set(25, y, "grime", 0.1, -0.2)
        for by in range(6, 96, 20):
            c.set(22, by, "metal", 0.8, 2.5)
            c.set(25, by, "metal", 0.5, 2.5)
        _box(c, 18, 30, 29, 40, "plate", 0.45, 2.2, "metal", 0.3)
        c.set(20, 32, "metal", 0.8, 2.6)
        c.set(27, 38, "metal", 0.8, 2.6)
        _shadow_box(c, 18, 30, 29, 40)
    elif name == "junction":
        _box(c, 6, 20, 25, 36, "plate", 0.4, 2.2, "metal", 0.3)
        _shadow_box(c, 6, 20, 25, 36)
        for i, x in enumerate((9, 13, 17, 21)):
            pts = [(x, 37), (x + math.sin(i) * 2, 52), (x - 2 + i, 70 + i * 4), (x - 4 + i * 2, 96)]
            c.line(pts, "cable", 0.45, 1.2)
        c.line([(9, 26), (22, 26)], "plastic_yellow" if "plastic_yellow" in tiles.RAMPS else "stain", 0.8, 2.4)
        c.line([(15, 29), (16, 33)], "void", 0.2, 2.4)
    elif name == "poster":
        x0, y0 = 6, 8
        for y in range(y0, y0 + 26):
            for x in range(x0, x0 + 19):
                torn = y > y0 + 16 and pnoise(x, y, 3, 4701, 0, 0) > 0.45 + (y - y0 - 16) * 0.04
                if torn:
                    continue
                line = (y - y0) % 3 == 0 and x0 + 2 < x < x0 + 16 and y > y0 + 6
                block = y0 + 1 < y < y0 + 6 and x0 + 2 < x < x0 + 16
                lum = 0.5 + 0.15 * _hash2(x, y, 4702) - (0.3 if line else 0) - (0.25 if block else 0)
                c.set(x, y, "paper", lum, 0.5)
        for x in (x0 + 1, x0 + 17):
            c.set(x, y0 + 1, "metal", 0.8, 1.5)
        _shadow_box(c, x0, y0, x0 + 18, y0 + 16)
    elif name == "cobweb":
        for k in range(7):
            ang = k / 6 * (math.pi / 2)
            c.line([(0, 0), (math.cos(ang) * 22, math.sin(ang) * 22)], "web", 0.5, None)
        for r in (6, 11, 16, 20):
            pts = [(math.cos(a / 8 * math.pi / 2) * r, math.sin(a / 8 * math.pi / 2) * r * 0.95) for a in range(9)]
            c.line(pts, "web", 0.35, None)
    elif name == "grime_low":
        for y in range(TILES_Y + 20, 96):
            for x in range(32):
                k = (y - TILES_Y - 20) / (96 - TILES_Y - 20)
                if pnoise(x, y, 4, 4801, 32, 0) * 0.6 + 0.5 * k > 0.55:
                    c.set(x, y, "grime", 0.25 + 0.3 * _hash2(x, y, 4802), None)
        for _ in range(6):  # salpicaduras
            c.set(rng.randint(0, 31), rng.randint(70, 86), "grime", 0.2, None)
    elif name == "scrapes":
        # Rozaduras de camillas y sillas a la altura de la barandilla y en el azulejo.
        for k in range(5):
            y = rng.randint(RAIL_Y[1] + 2, RAIL_Y[1] + 14)
            x0 = rng.uniform(-4, 14)
            c.line([(x0, y), (x0 + rng.uniform(10, 22), y + rng.uniform(-1, 1))], "grime", 0.25 + 0.1 * k, -0.4)
        for k in range(3):
            y = rng.randint(30, RAIL_Y[0] - 1)
            x0 = rng.uniform(0, 16)
            c.line([(x0, y), (x0 + rng.uniform(8, 16), y)], "plaster", 0.5, -0.4)
    elif name == "hand_low":
        x0, y0 = 6, 58
        for i in range(30):
            t = i / 29
            c.blob(x0 + 10 + math.sin(t * 3) * 2, y0 + t * 30, 3.4 - t * 2, 2.0, "blood_dry", 0.4, 4901 + i, 0.2, rough=0.5)
        for k, dx in enumerate((-4, -1, 2, 5)):
            c.line([(x0 + 10 + dx, y0 - 3), (x0 + 10 + dx * 1.2, y0 + 2)], "blood_dry", 0.45, 0.2)
    elif name == "oxygen":
        # Panel de tomas de gases medicinales en la cabecera de la cama.
        x0, y0 = 4, 50
        _box(c, x0, y0, x0 + 23, y0 + 9, "plate", 0.5, 2.0, "metal", 0.3)
        for i, mat in enumerate(("paint_green" if "paint_green" in tiles.RAMPS else "moss", "gauze", "plastic")):
            cx = x0 + 4 + i * 7
            c.set(cx, y0 + 4, mat, 0.8, 2.6)
            c.set(cx + 1, y0 + 4, mat, 0.6, 2.6)
            c.set(cx, y0 + 5, mat, 0.5, 2.6)
            c.set(cx + 1, y0 + 5, "void", 0.2, 2.6)
        _shadow_box(c, x0, y0, x0 + 23, y0 + 9)
        # Tubo de oxígeno arrancado colgando.
        c.line([(x0 + 5, y0 + 6), (x0 + 6, y0 + 16), (x0 + 3, y0 + 26), (x0 + 7, y0 + 34)], "tube", 0.7, 2.0)
    elif name == "call":
        _box(c, 22, 48, 28, 56, "gauze", 0.55, 1.8, "plate", 0.3)
        c.set(25, 51, "red_off", 0.9, 2.4)
        c.set(25, 52, "red_off", 0.7, 2.4)
        _shadow_box(c, 22, 48, 28, 56)
        c.line([(25, 57), (24, 70), (26, 82), (25, 95)], "cable", 0.5, 1.4)
    elif name == "exit":
        glow = Canvas(32, 96, fill="none")
        x0, y0 = 4, 4
        _box(c, x0, y0, x0 + 23, y0 + 9, "metal", 0.35, 2.0)
        glyphs = {"S": ["111", "100", "111", "001", "111"], "A": ["010", "101", "111", "101", "101"],
                  "L": ["100", "100", "100", "100", "111"], "I": ["1", "1", "1", "1", "1"],
                  "D": ["110", "101", "101", "101", "110"]}
        x = x0 + 2
        for ch in "SALIDA":
            g = glyphs[ch]
            for gy, row in enumerate(g):
                for gx, bit in enumerate(row):
                    if bit == "1":
                        c.set(x + gx, y0 + 2 + gy, "gauze", 0.9, 2.2)
                        glow.set(x + gx, y0 + 2 + gy, "exit_green", 0.95)
            x += len(g[0]) + 1
        for y in range(y0 + 1, y0 + 9):
            for xx in range(x0 + 1, x0 + 23):
                if c.mat[y][xx] != "gauze":
                    c.set(xx, y, "exit_green", 0.35, 2.0)
                    glow.set(xx, y, "exit_green", 0.3)
        _shadow_box(c, x0, y0, x0 + 23, y0 + 9)
    elif name == "drip_rust":
        for x in range(32):
            if pnoise(x, 0, 2, 5001, 32, 0) > 0.6:
                length = int(20 + 60 * pnoise(x, 1, 3, 5002, 32, 0))
                for y in range(0, length):
                    c.set(x, y, "rust", 0.3 - y / 400, None)
    elif name == "pipe_h":
        for py_, r in ((22, 3), (31, 2)):
            for y in range(py_ - r, py_ + r + 1):
                for x in range(32):
                    d = abs(y - py_) / (r + 0.5)
                    m = "rust" if pnoise(x, y, 4, 5101 + py_, 32, 0) > 0.62 else "metal"
                    c.set(x, y, m, 0.44 - d * 0.32, 2.5 * (1 - d))
            for x in range(32):
                c.set(x, py_ + r + 1, "grime", 0.1, -0.2)
        for x in (6, 22):
            for y in range(18, 35):
                c.set(x, y, "metal", 0.75 if y in (18, 34) else 0.45, 3.0)
    return c, glow


# --- montaje --------------------------------------------------------------------------------

# Opacidad de las manchas (la mugre, el agua o el moho dejan ver el suelo debajo).
ALPHA = {"grime": 0.42, "dust": 0.55, "moss": 0.7, "mold": 0.75, "water": 0.5, "oil": 0.72, "stain": 0.55,
         "rust": 0.62, "scorch": 0.62, "blood_dry": 0.86}


def _sheet(canvases: list[Canvas], w: int, h: int) -> tuple[Image.Image, Image.Image]:
    color = Image.new("RGBA", (w * len(canvases), h), (0, 0, 0, 0))
    normal = Image.new("RGBA", (w * len(canvases), h), (128, 128, 255, 0))
    for i, c in enumerate(canvases):
        img, nrm = c.to_images()
        for y in range(c.h):
            for x in range(c.w):
                a = ALPHA.get(c.mat[y][x])
                if a is not None and c.height[y][x] < 1.0:
                    px = img.getpixel((x, y))
                    img.putpixel((x, y), (px[0], px[1], px[2], int(px[3] * a)))
                    n = nrm.getpixel((x, y))
                    nrm.putpixel((x, y), (n[0], n[1], n[2], int(n[3] * a)))
        color.alpha_composite(img, (i * w, 0))
        normal.paste(nrm, (i * w, 0), nrm)
    return color, normal


def build() -> dict[str, tuple]:
    """Devuelve {clave: (color, normales, brillo|None, nombres, ancho, alto)}."""
    result = {}
    color, normal = _sheet([floor_decal(n) for n in FLOOR], 32, 32)
    result["decals"] = (color, normal, None, FLOOR, 32, 32)
    color, normal = _sheet([big_decal(n) for n in FLOOR_BIG], 64, 64)
    result["decals_big"] = (color, normal, None, FLOOR_BIG, 64, 64)
    walls = [wall_decal(n) for n in WALL]
    color, normal = _sheet([w for w, _ in walls], 32, 96)
    glow = Image.new("RGBA", color.size, (0, 0, 0, 0))
    for i, (_, g) in enumerate(walls):
        if g is not None:
            gi, _ = g.to_images()
            glow.alpha_composite(gi, (i * 32, 0))
    result["decals_wall"] = (color, normal, glow, WALL, 32, 96)
    return result
