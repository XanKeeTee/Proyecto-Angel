"""Tiles añadidos para el prólogo completo (filas 6-10 del atlas del hospital).

  fila 6   suelos: hormigón x4, quirófano x2, parqué del archivo, terrazo de recepción
  filas 7-9  paredes de 3 tramos (alto/medio/bajo):
           0-1 hormigón del sótano, 2 hormigón con tuberías, 3 ascensor cerrado,
           4 bajada a las escaleras, 5 azulejo de quirófano, 6-7 salida principal encadenada (izq./der.)
  fila 10  pasos: umbral cerrado, umbral abierto, puerta lateral cerrada, puerta lateral abierta,
           peldaños, rejilla de desagüe, altavoz de megafonía (tramo medio), aplique (tramo alto)
"""

from __future__ import annotations

import math
import random

from tiles import Canvas, T, _hash2, pfbm, pnoise, wall_column
from pxrender import ramp

ramp("concrete_floor", [(14, 14, 14), (24, 24, 23), (36, 35, 33), (50, 48, 45), (64, 62, 58)])
ramp("or_tile", [(26, 34, 32), (44, 56, 52), (66, 80, 74), (92, 106, 98), (120, 132, 122), (148, 158, 146)])
ramp("wood", [(20, 12, 10), (34, 22, 16), (50, 34, 24), (66, 46, 32), (84, 60, 42)])
ramp("terrazzo", [(28, 26, 24), (44, 42, 38), (62, 58, 52), (82, 78, 70), (104, 98, 88)])
ramp("concrete_wall", [(16, 16, 18), (26, 26, 28), (38, 38, 40), (52, 52, 54), (68, 68, 68)])
ramp("oil", [(8, 8, 10), (14, 14, 18), (22, 22, 28)])
ramp("chain", [(30, 28, 26), (62, 58, 52), (104, 98, 88), (150, 144, 130)])


def concrete_floor(variant: int) -> Canvas:
    c = Canvas(T, T, fill="concrete_floor")
    rng = random.Random(600 + variant)
    for y in range(T):
        for x in range(T):
            n = pfbm(x, y, 61, base=10)
            c.set(x, y, "concrete_floor", 0.45 + 0.3 * (n - 0.5) + 0.06 * (_hash2(x, y, 62) - 0.5), 0.0)
    if variant == 1:  # cerco de humedad tenue (los charcos grandes son calcomanías)
        for y in range(T):
            for x in range(T):
                if pfbm(x, y, 611, base=8) > 0.58:
                    c.lum[y][x] *= 0.72
    elif variant == 2:
        c.line([(2, 8), (9, 12), (14, 11), (22, 19), (30, 22)], "oil", 0.2, -1.2)
    elif variant == 3:
        for _ in range(4):
            c.blob(rng.uniform(6, 26), rng.uniform(6, 26), rng.uniform(1.0, 2.2), rng.uniform(1.0, 2.0), "rust", 0.4,
                   rng.randint(0, 999), 0.1)
    return c


def or_floor(variant: int) -> Canvas:
    c = Canvas(T, T, fill="or_tile")
    for y in range(T):
        for x in range(T):
            grout = x % 8 == 0 or y % 8 == 0
            n = pfbm(x, y, 71, base=6)
            c.set(x, y, "grout" if grout else "or_tile", 0.5 if grout else 0.55 + 0.25 * (n - 0.5), -0.6 if grout else 0.2)
    if variant == 1:  # juntas negras y una gota seca
        rng = random.Random(72)
        for y in range(T):
            for x in range(T):
                if c.mat[y][x] == "grout":
                    c.lum[y][x] = 0.15
                elif pfbm(x, y, 722, base=8) > 0.6:
                    c.lum[y][x] *= 0.8
        c.set(int(rng.uniform(6, 26)), int(rng.uniform(6, 26)), "blood_dry", 0.35)
    return c


def wood_floor() -> Canvas:
    c = Canvas(T, T, fill="wood")
    for y in range(T):
        for x in range(T):
            plank = (y // 8) % 2
            seam = y % 8 == 0 or (x + plank * 16) % 32 == 0
            grain = math.sin(x * 0.7 + pnoise(x, y, 5, 81, T, T) * 6.0) * 0.5 + 0.5
            c.set(x, y, "grout" if seam else "wood", 0.3 if seam else 0.35 + 0.25 * grain, -0.6 if seam else 0.1)
    return c


def terrazzo_floor() -> Canvas:
    c = Canvas(T, T, fill="terrazzo")
    for y in range(T):
        for x in range(T):
            chip = _hash2(x, y, 91)
            lum = 0.45 + 0.15 * (pfbm(x, y, 92, base=12) - 0.5)
            if chip > 0.93:
                lum = 0.85
            elif chip < 0.06:
                lum = 0.15
            c.set(x, y, "terrazzo", lum, 0.0)
    return c


def concrete_column(variant: int) -> Canvas:
    c = Canvas(T, 96, fill="concrete_wall")
    for y in range(96):
        for x in range(T):
            n = pfbm(x, y, 101 + variant, py=0, base=9)
            joint = y % 24 == 23 or (x + (y // 24) % 2 * 16) % 32 == 0
            shade = 0.3 + 0.25 * (y / 96)
            c.set(x, y, "grout" if joint else "concrete_wall", 0.3 if joint else shade + 0.25 * (n - 0.5), -0.6 if joint else 0.2)
    for x in range(T):
        if pnoise(x, 0, 3, 103 + variant, T, 0) > 0.7 and _hash2(x, variant, 105) > 0.4:
            for y in range(int(8 + 26 * pnoise(x, 1, 3, 104, T, 0))):
                c.lum[y][x] *= 0.55
    for y in range(88, 96):
        for x in range(T):
            c.lum[y][x] *= 0.6
    if variant == 2:  # tuberías horizontales
        for pipe_y, r in ((30, 3), (40, 2)):
            for y in range(pipe_y - r, pipe_y + r + 1):
                for x in range(T):
                    d = abs(y - pipe_y) / (r + 0.5)
                    mat = "rust" if pnoise(x, y, 4, 105, T, 0) > 0.62 else "metal"
                    c.set(x, y, mat, 0.6 - d * 0.4, 2.5 * (1 - d))
    return c


def elevator_column() -> Canvas:
    c = wall_column(0)
    for y in range(14, 96):
        for x in range(3, 29):
            edge = x in (3, 28) or y == 14
            seam = x == 16
            c.set(x, y, "metal" if not seam else "void", 0.35 if edge else (0.1 if seam else 0.45 + 0.08 * _hash2(x // 2, y, 106)),
                  1.5 if edge else (-2.0 if seam else 0.6))
    for y in range(4, 11):
        for x in range(10, 22):
            c.set(x, y, "void", 0.1, -0.5)
    c.set(14, 7, "void", 0.4)  # piloto apagado
    return c


def stairs_column() -> Canvas:
    c = wall_column(0)
    for y in range(12, 96):
        for x in range(4, 28):
            if x in (4, 27):
                c.set(x, y, "metal", 0.3, 1.5)
                continue
            depth = (y - 12) / 84
            step = (y // 7) % 2
            c.set(x, y, "concrete_floor", 0.25 - 0.22 * depth + 0.05 * step, -1.0 - depth * 2)
    for y in range(18, 96, 3):
        c.set(6, y, "metal", 0.5, 2.0)
        c.set(25, y, "metal", 0.5, 2.0)
    return c


def or_wall_column() -> Canvas:
    c = Canvas(T, 96, fill="or_tile")
    for y in range(96):
        for x in range(T):
            grout = x % 8 == 0 or y % 8 == 0
            n = pfbm(x, y, 111, py=0, base=8)
            c.set(x, y, "grout" if grout else "or_tile", 0.4 if grout else 0.5 + 0.2 * (n - 0.5) + 0.15 * (y / 96),
                  -0.6 if grout else 0.2)
    rng = random.Random(112)
    for _ in range(14):
        x, y = rng.uniform(4, 28), rng.uniform(30, 80)
        c.line([(x, y), (x + rng.uniform(-1, 1), y + rng.uniform(2, 7))], "blood_dry", 0.4, 0.1)
    return c


def chained_exit(right: bool) -> Canvas:
    from tiles import door_column
    c = door_column("double_r" if right else "double_l")
    # Cadena y candado por fuera del cristal y por delante.
    for i in range(16):
        t = i / 15
        x = (2 + t * 28) if not right else (t * 28 - 2)
        y = 52 + math.sin(t * math.pi) * 6
        c.set(int(x), int(y), "chain", 0.75 if i % 2 else 0.45, 2.0)
        c.set(int(x), int(y) + 1, "chain", 0.4, 1.5)
    if right:
        for y in range(56, 64):
            for x in range(0, 6):
                c.set(x, y, "metal", 0.55 if y > 58 else 0.3, 2.0)
    return c


def threshold(open_: bool) -> Canvas:
    c = Canvas(T, T, fill="cap")
    for y in range(T):
        for x in range(T):
            c.set(x, y, "cap", 0.35, 0.0)
    for y in range(T):
        for x in range(3, 29):
            c.set(x, y, "lino", 0.25, -0.5)
    if not open_:
        for y in range(10, 22):
            for x in range(4, 28):
                c.set(x, y, "door", 0.4 + (0.15 if y == 10 else 0.0), 1.0)
    else:
        for y in range(4, 28):
            for x in range(3, 6):
                c.set(x, y, "door", 0.45, 1.0)
    return c


def side_door(open_: bool) -> Canvas:
    c = Canvas(T, T, fill="cap")
    for y in range(T):
        for x in range(T):
            c.set(x, y, "lino", 0.3 + 0.05 * _hash2(x, y, 121), 0.0)
    for y in range(T):
        for x in (0, 1, 30, 31):
            c.set(x, y, "cap", 0.4, 0.0)
    if not open_:
        for y in range(2, 30):
            for x in range(13, 19):
                c.set(x, y, "door", 0.45 + (0.1 if x == 13 else 0.0), 1.2)
        c.set(18, 16, "metal", 0.8, 2.0)
    else:
        for y in range(1, 6):
            for x in range(2, 30):
                c.set(x, y, "door", 0.45, 1.2)
    return c


def steps_tile() -> Canvas:
    c = Canvas(T, T, fill="concrete_floor")
    for y in range(T):
        for x in range(T):
            step = y // 6
            edge = y % 6 == 0
            c.set(x, y, "concrete_floor", 0.55 - step * 0.09 + (0.12 if edge else 0.0), 2.0 - step * 0.6)
    return c


def drain_tile() -> Canvas:
    c = concrete_floor(0)
    for y in range(10, 22):
        for x in range(10, 22):
            slot = (x % 3 == 0) and 11 < y < 21
            c.set(x, y, "void" if slot else "metal", 0.1 if slot else 0.4, -1.5 if slot else 0.0)
    return c


def speaker_extra() -> Canvas:
    col = wall_column(0)
    c = Canvas(T, T)
    for y in range(T):
        for x in range(T):
            c.set(x, y, col.mat[T + y][x], col.lum[T + y][x], col.height[T + y][x])
    for y in range(2, 18):
        for x in range(8, 24):
            d = math.hypot(x + 0.5 - 16, y + 0.5 - 10)
            if d < 7.5:
                c.set(x, y, "metal" if d > 6.5 or (int(d * 2) % 2 == 0) else "void", 0.45, 1.5)
    return c


def lamp_extra() -> Canvas:
    col = wall_column(0)
    c = Canvas(T, T)
    for y in range(T):
        for x in range(T):
            c.set(x, y, col.mat[y][x], col.lum[y][x], col.height[y][x])
    for y in range(14, 22):
        for x in range(6, 26):
            c.set(x, y, "metal" if y in (14, 21) else "gauze", 0.45 if y in (14, 21) else 0.55, 2.0)
    return c


def build_into(color, normal) -> None:
    """Pinta las filas 6-10 en el atlas ya creado (256 x 352)."""

    def put(canvas: Canvas, col: int, row: int) -> None:
        img, nrm = canvas.to_images()
        color.paste(img, (col * T, row * T))
        normal.paste(nrm, (col * T, row * T))

    for v in range(4):
        put(concrete_floor(v), v, 6)
    put(or_floor(0), 4, 6)
    put(or_floor(1), 5, 6)
    put(wood_floor(), 6, 6)
    put(terrazzo_floor(), 7, 6)
    columns = [concrete_column(0), concrete_column(1), concrete_column(2), elevator_column(), stairs_column(),
               or_wall_column(), chained_exit(False), chained_exit(True)]
    for i, column in enumerate(columns):
        for part in range(3):
            sub = Canvas(T, T)
            for y in range(T):
                for x in range(T):
                    sub.set(x, y, column.mat[part * T + y][x], column.lum[part * T + y][x], column.height[part * T + y][x])
            put(sub, i, 7 + part)
    for i, canvas in enumerate([threshold(False), threshold(True), side_door(False), side_door(True), steps_tile(),
                                drain_tile(), speaker_extra(), lamp_extra()]):
        put(canvas, i, 10)
