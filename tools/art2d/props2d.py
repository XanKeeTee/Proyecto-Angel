"""Muestra de escenario en 2D: taquilla (cerrada y abierta), baldosa de suelo y tramo de pared.

Mismas reglas que los personajes, salvo el contorno: los objetos del mapa no lo llevan (guía
estética, *Escenarios*); el borde sale de las propias zonas de luz y sombra del material.
Vista oblicua de RPG Maker: la tapa se ve desde arriba (una franja) y el frente de cara.
El desgaste (abolladuras, óxido, pintura saltada, grietas) son polígonos y líneas trazados a mano;
solo su reparto en las baldosas usa una semilla fija para que cada una sea distinta.
"""

from __future__ import annotations

import os
import random
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import palette  # noqa: E402,F401
from pen import Pen  # noqa: E402
from px2d import Part  # noqa: E402

LOCKER_W, LOCKER_H = 44, 92


def _shadow(im: Image.Image, box: tuple[int, int, int, int], alpha: int = 120) -> Image.Image:
    """Sombra de contacto plana bajo el objeto (detrás de él)."""
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    a = np.zeros((im.height, im.width, 4), np.uint8)
    x0, y0, x1, y1 = box
    a[y0:y1, x0:x1] = (8, 6, 10, alpha)
    a[y0:y1 - 1, x0 + 1:x1 - 1, 3] = min(255, alpha + 40)
    sh = Image.fromarray(a, "RGBA")
    sh.alpha_composite(im)
    return sh


def _door(pen: Pen, x0: float, x1: float, seed: int):
    """Una puerta de la taquilla: rejilla, tarjetero, tirador, abolladuras, óxido."""
    rnd = random.Random(seed)
    # marco de la puerta: canto claro arriba/izquierda, oscuro abajo/derecha
    pen.line([(x0, 9), (x1, 9)], "paint", 3)
    pen.line([(x0, 9), (x0, 72)], "paint", 3)
    pen.line([(x1, 10), (x1, 72)], "paint", 1)
    # rejilla de ventilación: ranuras oscuras con labio de luz debajo
    for y in (14, 17, 20, 23):
        pen.line([(x0 + 3, y), (x1 - 3, y)], "paint", 0)
        pen.line([(x0 + 3, y + 1), (x1 - 3, y + 1)], "paint", 3)
    # tarjetero con un papel amarillento
    pen.poly([(x0 + 4, 28), (x1 - 4, 28), (x1 - 4, 32), (x0 + 4, 32)], "metal", 2)
    pen.poly([(x0 + 5, 29), (x1 - 5, 29), (x1 - 5, 31), (x0 + 5, 31)], "stain", 2)
    pen.pxs([(x0 + 6, 30), (x0 + 8, 30), (x0 + 9, 30)], "stain", 0)
    # tirador vertical con el cerrojo
    hx = x1 - 4 if seed % 2 else x0 + 3
    pen.poly([(hx, 38), (hx + 1.6, 38), (hx + 1.6, 46), (hx, 46)], "metal", 3)
    pen.px(hx, 38, "metal", 4)
    pen.px(hx + 1, 45, "metal", 1)
    pen.pxs([(hx + 0.5, 47.5), (hx + 0.5, 48.5)], "rust", 1)
    # abolladura: hundimiento con el borde de arriba en sombra y el de abajo iluminado
    dy = rnd.uniform(50, 60)
    dx = rnd.uniform(x0 + 3, x1 - 9)
    dent = [(dx, dy), (dx + 5, dy - 1.6), (dx + 7, dy + 2.4), (dx + 3, dy + 5), (dx - 0.6, dy + 3.2)]
    pen.shade(dent, tone=1)
    pen.line([(dx + 0.6, dy + 3.8), (dx + 3, dy + 5), (dx + 6.6, dy + 2.6)], "paint", 3, inside=True)
    # pintura saltada y óxido que crece desde el bajo
    for _ in range(3):
        cx, cy = rnd.uniform(x0 + 2, x1 - 3), rnd.uniform(34, 66)
        chip = [(cx, cy), (cx + rnd.uniform(1.5, 3), cy + 0.4), (cx + 2.4, cy + rnd.uniform(1.4, 2.6)),
                (cx + 0.4, cy + 2)]
        pen.shade(chip, mat="metal", tone=2)
        pen.px(cx + 1, cy + 2, "rust", 1, inside=True)
    rust = [(x0 + 1, 72), (x0 + 1, 66), (x0 + 3, 63), (x0 + 5, 66), (x0 + 8, 64), (x0 + 10, 68), (x1 - 2, 67),
            (x1 - 1, 72)]
    pen.shade(rust, mat="rust", tone=1)
    pen.shade([(x0 + 2, 70), (x1 - 2, 70), (x1 - 2, 72), (x0 + 2, 72)], mat="rust", tone=0)
    pen.pxs([(x0 + 4, 62), (x0 + 4, 63), (x1 - 3, 64)], "rust", 2, inside=True)
    # regueros de mugre bajo las ranuras
    for x in (x0 + 5, x0 + 9, x1 - 6):
        pen.line([(x, 25), (x, 25 + rnd.randint(3, 8))], "paint", 1, inside=True)


def locker(open_door: bool = False) -> Image.Image:
    pen = Pen(Part(LOCKER_W, LOCKER_H))
    # tapa vista desde arriba
    pen.poly([(4, 2), (39, 2), (39, 7), (4, 7)], "paint", 3)
    pen.line([(4, 7), (39, 7)], "paint", 4)
    pen.line([(4, 2), (39, 2)], "paint", 2)
    pen.pxs([(9, 4), (10, 4), (27, 5), (33, 3)], "paint", 2)               # polvo y marcas
    pen.poly([(16, 3), (22, 3), (23, 6), (15, 6)], "stain", 1)             # una caja olvidada arriba
    # frente
    pen.poly([(4, 8), (39, 8), (39, 74), (4, 74)], "paint", 2)
    pen.shade([(4, 8), (39, 8), (39, 11), (4, 12)], tone=3)                # el plafón da arriba
    _door(pen, 5, 21, 3)
    _door(pen, 23, 38, 4)
    pen.line([(22, 9), (22, 73)], "paint", 0)                               # junta entre puertas
    pen.line([(4, 8), (4, 74)], "paint", 3)
    pen.line([(39, 8), (39, 74)], "paint", 0)
    # zócalo
    pen.poly([(4, 73), (39, 73), (39, 76), (4, 76)], "paint", 0)
    pen.pxs([(6, 74), (14, 75), (30, 74)], "rust", 1)
    if open_door:
        # la puerta derecha abierta hacia el espectador: se ve de canto, y dentro, oscuridad,
        # una balda y una bata colgada
        pen.poly([(23, 9), (38, 9), (38, 72), (23, 72)], "glass_dark", 1)
        pen.line([(23, 22), (38, 22)], "metal", 1)                          # balda
        pen.line([(23, 21), (38, 21)], "metal", 2)
        pen.poly([(26, 24), (34, 24), (36, 40), (33, 48), (27, 47), (25, 38)], "gown", 1)
        pen.line([(30, 24), (30, 46)], "gown", 0)
        pen.px(30, 23, "metal", 3)
        pen.poly([(24, 60), (31, 58), (34, 66), (26, 68)], "stain", 0)     # zapato tirado al fondo
        door = [(39, 8), (43, 11), (43, 77), (39, 74)]
        pen.poly(door, "paint", 1)
        pen.line([(39, 8), (43, 11)], "paint", 3)
        pen.line([(41, 20), (41, 30)], "paint", 0)
        pen.shade([(39, 60), (43, 62), (43, 77), (39, 74)], mat="rust", tone=1)
    im = pen.part.render(outline=False)
    return _shadow(im, (3, 75, 41, 79) if not open_door else (3, 75, 44, 80))


# --- suelo y pared ---------------------------------------------------------------------------

def floor_tile(seed: int = 1) -> Image.Image:
    """32×32: cuatro losetas de linóleo con juntas sucias, rozaduras y alguna grieta. Las juntas
    van solo a la derecha y abajo de cada loseta, así el tile se repite sin juntas dobles."""
    rnd = random.Random(seed)
    pen = Pen(Part(32, 32))
    for i, (x0, y0) in enumerate(((0, 0), (16, 0), (0, 16), (16, 16))):
        t = 2 if (i + seed) % 3 else 1
        pen.poly([(x0, y0), (x0 + 15, y0), (x0 + 15, y0 + 15), (x0, y0 + 15)], "tile", t)
        pen.line([(x0, y0), (x0 + 14, y0)], "tile", t + 1)                  # canto de luz
        pen.line([(x0 + 1, y0 + 14), (x0 + 14, y0 + 14)], "tile", max(0, t - 1))
        # rozaduras: trazos cortos y oblicuos de pies y ruedas
        for _ in range(rnd.randint(1, 3)):
            x, y = x0 + rnd.uniform(2, 11), y0 + rnd.uniform(3, 12)
            ln = rnd.uniform(2, 4)
            pen.line([(x, y), (x + ln, y + rnd.choice((-1, 0, 1)))], "tile", max(0, t - 1))
        if rnd.random() < 0.5:   # mancha seca: forma plana, un tono abajo
            cx, cy = x0 + rnd.uniform(4, 9), y0 + rnd.uniform(4, 9)
            pen.shade([(cx, cy), (cx + 3, cy - 1), (cx + 4, cy + 2), (cx + 1, cy + 3)], delta=-1)
    for k in (15, 31):
        pen.line([(k, 0), (k, 31)], "floor", 0)
        pen.line([(0, k), (31, k)], "floor", 0)
    pen.pxs([(14, 15), (15, 14), (30, 31), (31, 30)], "dirt", 0)
    if seed % 2:   # grieta quebrada con el canto claro
        x, y = 19, 18
        pts = [(x, y)]
        for _ in range(4):
            x += rnd.choice((1, 2, 2)); y += rnd.choice((1, 2))
            pts.append((x, y))
        pen.line(pts, "tile", 0)
        pen.line([(px + 1, py) for px, py in pts[1:]], "tile", 3)
    return pen.part.render(outline=False)


def wall_strip(seed: int = 2) -> Image.Image:
    """32×96: yeso con humedades arriba, barandilla metálica, azulejo agrietado y zócalo."""
    rnd = random.Random(seed)
    pen = Pen(Part(32, 96))
    pen.poly([(0, 0), (31, 0), (31, 51), (0, 51)], "plaster", 2)
    # humedad: mancha que baja en lenguas, con cerco oscuro
    damp = [(4, 0), (22, 0), (24, 8), (20, 14), (21, 24), (17, 30), (15, 22), (10, 27), (8, 16), (5, 12)]
    pen.shade(damp, tone=1, pattern="checker")
    pen.shade([(6, 0), (20, 0), (21, 7), (17, 12), (12, 13), (8, 9)], tone=1)
    pen.line([(5, 12), (8, 16), (10, 27), (15, 22), (17, 30), (21, 24)], "plaster", 1)
    pen.shade([(10, 2), (16, 2), (15, 7), (12, 8)], mat="mold", tone=2)
    # pintura levantada: escama clara con su sombra debajo
    pen.poly([(24, 33), (29, 32), (30, 36), (26, 37)], "plaster", 4)
    pen.line([(25, 37), (30, 36)], "plaster", 0)
    pen.pxs([(3, 40), (4, 41), (12, 44), (28, 20)], "plaster", 3)
    # barandilla: tubo metálico sobre soportes
    pen.poly([(0, 52), (31, 52), (31, 57), (0, 57)], "plaster", 1)
    pen.poly([(0, 53), (31, 53), (31, 55), (0, 55)], "metal", 3)
    pen.line([(0, 53), (31, 53)], "metal", 4)
    pen.line([(0, 55), (31, 55)], "metal", 1)
    pen.poly([(14, 55), (17, 55), (17, 57), (14, 57)], "metal", 2)
    pen.pxs([(8, 54), (23, 54)], "rust", 1)
    # azulejo: piezas de 8×8, alguna rota o que falta
    pen.poly([(0, 58), (31, 58), (31, 89), (0, 89)], "tile", 3)
    for ty in range(58, 90, 8):
        for tx in range(0, 32, 8):
            t = 3 if rnd.random() < 0.7 else 2
            pen.poly([(tx, ty), (tx + 7, ty), (tx + 7, ty + 7), (tx, ty + 7)], "tile", t)
            pen.line([(tx, ty), (tx + 6, ty)], "tile", 4)
            pen.line([(tx + 7, ty), (tx + 7, ty + 7)], "tile", 1)
            pen.line([(tx, ty + 7), (tx + 7, ty + 7)], "tile", 1)
    pen.poly([(16, 74), (23, 74), (23, 81), (16, 81)], "plaster", 0)       # azulejo que falta
    pen.line([(17, 75), (22, 75)], "plaster", 1)
    pen.line([(2, 66), (4, 69), (3, 72)], "tile", 0)                        # grietas
    pen.line([(25, 82), (27, 84), (30, 84)], "tile", 0)
    pen.shade([(0, 80), (31, 80), (31, 89), (0, 89)], delta=-1, pattern="checker")  # mugre a ras de suelo
    # zócalo
    pen.poly([(0, 90), (31, 90), (31, 95), (0, 95)], "floor", 1)
    pen.line([(0, 90), (31, 90)], "floor", 3)
    pen.pxs([(6, 93), (19, 92), (27, 94)], "dirt", 0)
    return pen.part.render(outline=False)


if __name__ == "__main__":
    from px2d import upscale
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n/props.png"
    can = Image.new("RGBA", (44 * 2 + 32 * 3 + 40, 96), (30, 29, 32, 255))
    can.alpha_composite(locker(False), (0, 2))
    can.alpha_composite(locker(True), (48, 2))
    can.alpha_composite(wall_strip(), (100, 0))
    for i in range(2):
        can.alpha_composite(floor_tile(i + 1), (140 + i * 32, 0))
        can.alpha_composite(floor_tile(i + 3), (140 + i * 32, 32))
    upscale(can, 4).save(out)
