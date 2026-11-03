"""Escenario a la escala nueva (baldosa de 64 px): taquilla doble, baldosa de suelo y tramo de pared.

Sin contorno (los objetos del mapa se funden con el escenario, guía estética) y con la misma pintura
que los personajes: canto que gira, desgaste dibujado (abolladuras, pintura saltada, óxido que sube
del suelo, regueros), textura y sombra de contacto.
"""

from __future__ import annotations

import os
import random
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import palette_hd  # noqa: E402,F401
from paint import Piece  # noqa: E402

LIGHT = (-0.35, -0.94)


def _contact(im: Image.Image, box, alpha: int = 140) -> Image.Image:
    a = np.zeros((im.height, im.width, 4), np.uint8)
    x0, y0, x1, y1 = box
    a[y0:y1, x0:x1] = (6, 5, 8, alpha)
    a[y0 + 1:y1 - 1, x0 + 2:x1 - 2, 3] = min(255, alpha + 50)
    out = Image.fromarray(a, "RGBA")
    out.alpha_composite(im)
    return out


def locker(open_door: bool = False) -> Image.Image:
    """Taquilla doble de 88×184 (unos 1,85 m de frente frente a la figura de 140 px)."""
    w, h = 88, 184
    pc = Piece(w, h, "locker")
    pc.outline = False
    rnd = random.Random(4)
    pc.fill([(8, 4), (79, 4), (79, 14), (8, 14)], "paint", 0.66)                 # tapa vista desde arriba
    pc.fill([(8, 14), (79, 14), (79, 150), (8, 150)], "paint", 0.5)               # frente
    pc.fill([(8, 150), (79, 150), (79, 156), (8, 156)], "paint", 0.15)            # zócalo
    pc.form(LIGHT, bevel=3.0, strength=0.3, rim_dark=0.12)
    pc.plane([(8, 14), (79, 14), (79, 24), (8, 28)], 0.12, 3.0)                    # el plafón da arriba
    pc.fill([(30, 6), (44, 6), (46, 12), (28, 12)], "stain", 0.4)                  # caja olvidada arriba
    for x0, x1, seed in ((10, 42, 1), (45, 77, 2)):
        r = random.Random(seed)
        pc.crease([(x0, 16), (x1, 16)], -0.2, 0.7)
        pc.crease([(x0, 16), (x0, 148)], -0.16, 0.7)
        pc.crease([(x1, 17), (x1, 148)], 0.24, 0.8)
        for y in (26, 31, 36, 41, 46):                                            # rejilla
            pc.line([(x0 + 6, y), (x1 - 6, y)], "paint", 0.04)
            pc.line([(x0 + 6, y + 1), (x1 - 6, y + 1)], "paint", 0.72)
        pc.fill([(x0 + 8, 56), (x1 - 8, 56), (x1 - 8, 64), (x0 + 8, 64)], "metal", 0.5)      # tarjetero
        pc.fill([(x0 + 10, 58), (x1 - 10, 58), (x1 - 10, 62), (x0 + 10, 62)], "paper", 0.55)
        pc.line([(x0 + 12, 60), (x0 + 20, 60)], "ink", 0.4)
        hx = x1 - 7 if seed == 1 else x0 + 4
        pc.fill([(hx, 76), (hx + 3, 76), (hx + 3, 94), (hx, 94)], "metal", 0.6)            # tirador
        pc.form(LIGHT, bevel=1.5, strength=0.4, rim_dark=0.05, region=pc.of("metal"))
        # abolladura: hundida (sombra arriba, luz abajo)
        dx, dy = r.uniform(x0 + 6, x1 - 14), r.uniform(100, 120)
        pc.plane([(dx, dy), (dx + 10, dy - 3), (dx + 13, dy + 4), (dx + 6, dy + 10), (dx - 1, dy + 6)], -0.18, 1.0)
        pc.crease([(dx + 1, dy + 7), (dx + 6, dy + 10), (dx + 12, dy + 5)], -0.16, 0.8)
        # pintura saltada y óxido que sube del suelo
        for _ in range(5):
            cx, cy = r.uniform(x0 + 3, x1 - 4), r.uniform(66, 140)
            pc.stain((cx, cy), r.uniform(1.6, 3.4), "metal", r.randrange(999), val=0.45, ring=0.08)
        pc.stain(((x0 + x1) / 2, 150), 16, "rust", seed + 10, stretch=(1.1, 0.9), ring=0.1, val=0.45)
        for x in (x0 + 8, x0 + 16, x1 - 10):                                       # regueros bajo la rejilla
            pc.crease([(x, 48), (x, 48 + r.randint(6, 22))], 0.12, 0.6, clip=["paint"])
    pc.crease([(44, 16), (44, 150)], 0.35, 0.8)
    pc.noise(0.12, 8.0, 7, clip=["paint"])
    pc.pores(0.08, 0.04, 8, clip=["paint"])
    if open_door:
        pc.fill([(45, 16), (77, 16), (77, 149), (45, 149)], "dark", 0.4)
        pc.line([(45, 44), (77, 44)], "metal", 0.35, width=2)
        pc.fill([(50, 48), (70, 48), (74, 82), (68, 98), (54, 96), (49, 78)], "gown", 0.2)
        pc.crease([(60, 48), (61, 95)], 0.2, 1.0, clip=["gown"])
        pc.stain((58, 80), 5, "blood", 21, val=0.3, ring=0.08, clip=["gown"])
        pc.fill([(50, 128), (64, 124), (68, 136), (54, 140)], "stain", 0.25)      # zapato tirado al fondo
        door = Piece(w, h, "door")
        door.outline = False
        door.fill([(79, 14), (87, 20), (87, 160), (79, 152)], "paint", 0.32)
        door.crease([(83, 40), (83, 62)], 0.25, 0.6)
        door.stain((83, 150), 6, "rust", 30, ring=0.08, val=0.45)
        im = pc.render(outline=False)
        im.alpha_composite(door.render(outline=False))
        return _contact(im, (6, 154, 88, 162))
    return _contact(pc.render(outline=False), (6, 154, 82, 162))


def floor_tile(seed: int = 1) -> Image.Image:
    """64×64: cuatro losetas de linóleo con juntas sucias (solo a la derecha y abajo, para repetir)."""
    rnd = random.Random(seed)
    pc = Piece(64, 64, "floor")
    pc.outline = False
    for i, (x0, y0) in enumerate(((0, 0), (32, 0), (0, 32), (32, 32))):
        v = 0.5 if (i + seed) % 3 else 0.42
        pc.fill([(x0, y0), (x0 + 31, y0), (x0 + 31, y0 + 31), (x0, y0 + 31)], "lino", v)
        pc.crease([(x0, y0 + 0.5), (x0 + 30, y0 + 0.5)], -0.14, 0.5)
        pc.crease([(x0 + 0.5, y0), (x0 + 0.5, y0 + 30)], -0.08, 0.5)
        for _ in range(rnd.randint(2, 4)):                                     # rozaduras
            x, y = x0 + rnd.uniform(3, 24), y0 + rnd.uniform(3, 26)
            ln = rnd.uniform(4, 9)
            pc.crease([(x, y), (x + ln, y + rnd.uniform(-1.5, 1.5))], 0.12, 0.5)
        if rnd.random() < 0.6:
            pc.stain((x0 + rnd.uniform(8, 22), y0 + rnd.uniform(8, 22)), rnd.uniform(3, 5), "dirt", rnd.randrange(999),
                     ring=0.04, val=0.45)
    pc.noise(0.14, 6.0, seed, clip=["lino"])
    pc.pores(0.08, 0.06, seed + 1, clip=["lino"])
    for k in (31, 63):
        pc.line([(k, 0), (k, 63)], "grout", 0.4)
        pc.line([(0, k), (63, k)], "grout", 0.4)
    if seed % 2:
        x, y = 38, 36
        pts = [(x, y)]
        for _ in range(6):
            x += rnd.choice((1, 2, 3))
            y += rnd.choice((1, 2))
            pts.append((x, y))
        pc.line(pts, "lino", 0.05)
        pc.line([(px + 1, py) for px, py in pts[1:]], "lino", 0.9)
    return pc.render(outline=False)


def wall_strip(seed: int = 2) -> Image.Image:
    """64×192: yeso con humedad y moho, barandilla, azulejo agrietado y zócalo."""
    rnd = random.Random(seed)
    pc = Piece(64, 192, "wall")
    pc.outline = False
    pc.fill([(0, 0), (63, 0), (63, 104), (0, 104)], "plaster", 0.55)
    pc.stain((30, 4), 20, "plaster", 3, stretch=(1.0, 1.8), ring=0.1, val=0.44, drip=2.0)
    pc.stain((26, 14), 8, "mold", 4, stretch=(1.2, 1.0), ring=0.06, val=0.55)
    pc.fill([(46, 64), (57, 62), (59, 71), (50, 73)], "plaster", 0.85)          # escama de pintura
    pc.crease([(48, 74), (59, 72)], 0.3, 0.7)
    pc.noise(0.07, 18.0, seed, clip=["plaster"])
    pc.pores(0.08, 0.05, seed + 1, clip=["plaster"])
    pc.fill([(0, 104), (63, 104), (63, 114), (0, 114)], "plaster", 0.3)
    pc.fill([(0, 106), (63, 106), (63, 111), (0, 111)], "metal", 0.55)          # barandilla
    pc.form(LIGHT, bevel=2.0, strength=0.4, rim_dark=0.1, region=pc.of("metal"))
    pc.fill([(28, 111), (35, 111), (35, 115), (28, 115)], "metal", 0.4)
    pc.stain((14, 108), 3, "rust", 5, ring=0.05, val=0.5)
    for ty in range(116, 180, 16):
        for tx in range(0, 64, 16):
            v = 0.6 if rnd.random() < 0.7 else 0.48
            pc.fill([(tx, ty), (tx + 15, ty), (tx + 15, ty + 15), (tx, ty + 15)], "tile", v)
            pc.crease([(tx + 1, ty + 1), (tx + 14, ty + 1)], -0.18, 0.5)
            pc.crease([(tx + 15, ty), (tx + 15, ty + 15)], 0.25, 0.5)
            pc.crease([(tx, ty + 15), (tx + 15, ty + 15)], 0.25, 0.5)
    pc.fill([(32, 148), (47, 148), (47, 163), (32, 163)], "plaster", 0.12)      # azulejo que falta
    pc.line([(4, 132), (8, 138), (6, 143)], "tile", 0.05)
    pc.line([(50, 166), (54, 170), (60, 170)], "tile", 0.05)
    pc.noise(0.1, 5.0, seed + 3, clip=["tile"])
    pc.plane([(0, 160), (64, 160), (64, 180), (0, 180)], -0.14, 4.0)            # mugre a ras de suelo
    pc.fill([(0, 180), (63, 180), (63, 191), (0, 191)], "lino", 0.3)            # zócalo
    pc.crease([(0, 180.5), (63, 180.5)], -0.25, 0.5)
    return pc.render(outline=False)


if __name__ == "__main__":
    from paint import upscale
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n/hd_props.png"
    can = Image.new("RGBA", (88 * 2 + 64 * 3 + 40, 192), (22, 21, 24, 255))
    can.alpha_composite(locker(False), (0, 4))
    can.alpha_composite(locker(True), (92, 4))
    can.alpha_composite(wall_strip(), (196, 0))
    for i in range(2):
        can.alpha_composite(floor_tile(i + 1), (268 + i * 64, 0))
        can.alpha_composite(floor_tile(i + 3), (268 + i * 64, 64))
    upscale(can, 2).save(out)
