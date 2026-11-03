"""El enfermero transfigurado en combate, segunda muestra: 400×540 (vista de 1280×720).

Concepto: docs/design/enemigos/enfermero.md. Siluetas trazadas a mano y volumen pintado con `paint`:
piel gris azulada con poros, moteado, venas y cardenales; músculo y hueso marcados (deltoides,
tendones, codos y rodillas huesudos, costillas); uniforme con trama, costuras, desgarros y sangre que
empapa con el cerco oscuro; máscara de porcelana con grietas y brillo; mascarilla cosida a la piel;
bisturíes y sierra con reflejos; jeringa de cristal con el líquido oscuro; vías en el pecho.

Piezas separables (mutilaciones): `leg_r`, `leg_l`, `body`, `arm_r` (instrumental, izquierda de
la pantalla), `arm_l` (jeringa), `head`; muñón de ejemplo `stump_arm_r`. Poses: reposo (2),
ataque (Tajo) y el muñón.
"""

from __future__ import annotations

import math
import os
import random
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import palette_hd  # noqa: E402,F401
from paint import Piece, compose, lerp, limb, rotsprite  # noqa: E402

W, H = 400, 540
LIGHT = (-0.35, -0.94)


def S(x: float, y: float) -> tuple[float, float]:
    """De la rejilla de diseño de la primera muestra (200×260) a la resolución nueva."""
    return (x * 2.0, y * 2.0 + 14)


def SP(pts):
    return [S(x, y) for x, y in pts]


THIGH = [(0.0, 19, 19), (0.15, 18.4, 17.6), (0.45, 15.6, 15.0), (0.8, 12.4, 12.0), (1.0, 13.4, 13.4)]
SHIN = [(0.0, 13.0, 13.0), (0.06, 14.0, 12.6), (0.25, 11.6, 13.4), (0.5, 9.4, 10.0), (0.8, 6.8, 7.0), (1.0, 7.6, 7.6)]
UPPER = [(0.0, 16.0, 15.0), (0.1, 17.4, 14.6), (0.22, 15.0, 12.2), (0.32, 11.4, 11.6), (0.45, 10.6, 9.4),
         (0.6, 8.6, 9.2), (0.75, 7.6, 8.0), (0.86, 8.4, 7.4), (0.95, 10.6, 9.6), (1.0, 10.8, 10.2)]
FORE = [(0.0, 10.0, 10.0), (0.1, 12.6, 11.0), (0.22, 12.0, 11.6), (0.35, 10.2, 10.0), (0.5, 9.0, 8.2), (0.7, 7.0, 7.4),
        (0.85, 6.0, 6.2), (1.0, 6.8, 6.6)]
FORE_FUSED = [(0.0, 10.4, 10.4), (0.15, 13.4, 12.4), (0.45, 14.6, 13.6), (0.75, 13.0, 13.4), (1.0, 12.0, 12.0)]


def _u(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dy) or 1.0
    return dx / n, dy / n


def _skin(pc: Piece, seed: int, bevel: float = 7.0, mat: str = "nskin") -> None:
    pc.form(LIGHT, bevel=bevel * 1.6, strength=0.44, rim_dark=0.22, region=pc.of(mat))
    pc.form((0.95, -0.3), bevel=2.0, strength=0.12, rim_dark=0.0, region=pc.of(mat))   # contraluz frío
    pc.noise(0.22, 12.0, seed, clip=[mat])                 # moteado lívido
    pc.noise(0.1, 3.0, seed + 1, clip=[mat])
    pc.pores(0.08, 0.15, seed + 2, clip=[mat])


def _cloth(pc: Piece, seed: int, bevel: float = 8.0) -> None:
    pc.form(LIGHT, bevel=bevel * 1.8, strength=0.42, rim_dark=0.2, region=pc.of("uniform"))
    pc.form(LIGHT, bevel=3.0, strength=0.12, rim_dark=0.12, region=pc.of("uniform"))
    pc.weave(0.05, 1, clip=["uniform"])
    pc.noise(0.2, 20.0, seed, clip=["uniform"])            # mugre que tiñe la tela a parches
    pc.noise(0.08, 5.0, seed + 1, clip=["uniform"])
    pc.pores(0.1, 0.03, seed + 2, clip=["uniform"])        # motas de suciedad


def _seam(pc: Piece, pts, every: float = 4.0) -> None:
    """Costura de la tela: surco con puntadas."""
    pc.crease(pts, 0.14, 1.0, ridge=0.08, ridge_off=(1, 1), clip=["uniform"])
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        ln = math.hypot(x1 - x0, y1 - y0)
        for i in range(int(ln / every)):
            t = (i + 0.5) * every / ln
            pc.dot(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, "uniform", 0.3)


def _crack(pc: Piece, start, steps: int, seed: int, ang: float) -> list:
    rnd = random.Random(seed)
    x, y = start
    pts = [(x, y)]
    for _ in range(steps):
        ang += rnd.uniform(-0.6, 0.6)
        st = rnd.uniform(3.0, 6.0)
        x, y = x + math.cos(ang) * st, y + math.sin(ang) * st
        pts.append((x, y))
    pc.line(pts, "porcelain", 0.05, inside=True)
    pc.line([(px + 1, py + 1) for px, py in pts[1:]], "porcelain", 0.98, inside=True)
    if len(pts) > 3:
        bx, by = pts[len(pts) // 2]
        b = ang + rnd.choice((-1.2, 1.2))
        pc.line([(bx, by), (bx + math.cos(b) * 9, by + math.sin(b) * 9)], "porcelain", 0.1, inside=True)
    return pts


def _stitch_line(pc: Piece, pts, every: float = 6.0, size: float = 3.4, val: float = 0.25) -> None:
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        ln = math.hypot(x1 - x0, y1 - y0) or 1
        ux, uy = (x1 - x0) / ln, (y1 - y0) / ln
        nx, ny = -uy, ux
        for i in range(int(ln / every)):
            t = (i + 0.5) * every
            cx, cy = x0 + ux * t, y0 + uy * t
            pc.line([(cx - nx * size - ux, cy - ny * size - uy), (cx + nx * size + ux, cy + ny * size + uy)], "thread", val)
            pc.dot(cx - nx * size, cy - ny * size, "flesh", 0.35)       # agujero inflamado
            pc.dot(cx + nx * size, cy + ny * size, "flesh", 0.35)


# =============================================================================================
# Piezas
# =============================================================================================

def leg(side: int, pose: dict) -> Piece:
    pc = Piece(W, H, "leg_r" if side < 0 else "leg_l")
    hip, knee, ankle = S(*pose[f"hip{side}"]), S(*pose[f"knee{side}"]), S(*pose[f"ankle{side}"])
    hem = lerp(knee, ankle, 0.5)
    pc.fill(limb(hip, knee, THIGH), "uniform", 0.6)
    shin = SHIN if side > 0 else [(t, r, l) for t, l, r in SHIN]
    pc.fill(limb(knee, ankle, shin), "nskin", 0.5)
    pc.fill(limb(knee, hem, [(0, 13.6, 13.6), (0.5, 12.8, 13.2), (1, 12.4, 12.6)]), "uniform", 0.58)
    hx, hy = hem
    rnd = random.Random(side + 5)
    jag = [(hx - 13, hy - 2)]
    for k in range(9):
        jag.append((hx - 13 + k * 3.2, hy + (rnd.uniform(4, 11) if k % 2 else rnd.uniform(-2, 2))))
    jag += [(hx + 13, hy - 3), (hx + 13, hy - 10), (hx - 13, hy - 10)]
    pc.fill(jag, "uniform", 0.5)
    # rodilla rota: la tela rasgada deja ver la rótula gris
    kx, ky = knee
    tear = [(kx - 8, ky - 6), (kx + 2, ky - 9), (kx + 9, ky - 3), (kx + 7, ky + 6), (kx - 2, ky + 8), (kx - 9, ky + 3)]
    pc.fill(tear, "nskin", 0.58, inside=True)
    # pie largo y huesudo
    ax, ay = ankle
    foot = [(ax - 8, ay - 2), (ax + 8, ay - 2), (ax + 13 + side * 4, ay + 18), (ax + 12 + side * 4, ay + 25),
            (ax - 12 + side * 4, ay + 25), (ax - 13 + side * 4, ay + 18)]
    pc.fill(foot, "nskin", 0.5)
    _cloth(pc, 100 + side)
    _skin(pc, 110 + side, 5.0)
    # pantalón: pliegues en zigzag del muslo a la rodilla, costura lateral
    hx0, hy0 = hip
    pc.crease([(hx0 + side * 4, hy0 + 18), (kx + side * 7, ky - 42), (kx - side * 2, ky - 22)], 0.2, 1.6, ridge=0.12,
              ridge_off=(-2, 0), clip=["uniform"])
    pc.crease([(hx0 - side * 7, hy0 + 26), (kx - side * 8, ky - 18)], 0.16, 1.6, ridge=0.1, ridge_off=(-2, 0),
              clip=["uniform"])
    pc.crease([(kx + side * 4, ky + 12), (hx + side * 2, hy - 6)], 0.16, 1.4, clip=["uniform"])
    _seam(pc, [(hx0 + side * 16, hy0 + 6), (kx + side * 12, ky - 6)])
    # rótula y bordes del roto
    pc.plane([(kx - 4, ky - 5), (kx + 4, ky - 6), (kx + 5, ky + 1), (kx - 3, ky + 2)], 0.18, 1.2, clip=["nskin"])
    pc.crease(tear[:4], -0.16, 1.0, clip=["uniform"])
    pc.crease([(kx - 6, ky + 5), (kx + 6, ky + 4)], 0.22, 1.2, clip=["nskin"])
    # espinilla, tendones del pie, dedos con uñas negras
    pc.crease([(hx - 1.5, hy + 8), (ax - 1, ay - 6)], -0.14, 1.2, clip=["nskin"])
    for i, dx in enumerate((-9, -4.5, 0, 4.5, 9)):
        x = ax + dx + side * 4
        pc.crease([(x, ay + 12), (x + side * 0.6, ay + 24)], 0.24 if i % 2 else 0.18, 0.8, clip=["nskin"])
        pc.fill([(x - 1.6, ay + 21), (x + 1.6, ay + 21), (x + 1.4, ay + 25), (x - 1.4, ay + 25)], "nail", 0.4, inside=True)
    for dx in (-3.5, 2.5):
        pc.crease([(ax + dx, ay + 1), (ax + dx * 1.8 + side * 2, ay + 13)], -0.14, 0.9, clip=["nskin"])
    pc.veins((hx + 3, hy + 10), 12, 120 + side, ang=math.pi / 2 + 0.2, depth=0.14, mat="vein")
    # manchas: sangre seca que empapa el muslo, mugre en el bajo
    pc.stain((hx0 - side * 3, hy0 + 50), 11.0, "blood", 130 + side, val=0.24, stretch=(0.8, 1.8), ring=0.14, drip=1.4,
             clip=["uniform"])
    pc.stain((hx, hy - 6), 14.0, "stain", 132 + side, stretch=(1.2, 0.8), ring=0.06, clip=["uniform"])
    # el foco no llega a los pies
    pc.plane([(0, 492), (W, 492), (W, H), (0, H)], -0.12, 8.0)
    return pc


def body(pose: dict, br: float = 0.0) -> Piece:
    pc = Piece(W, H, "body")
    o = (0, br)
    tunic = [(84, 49), (90, 53), (93, 62), (100, 80), (107, 62), (110, 53), (116, 49), (124, 51), (131, 55), (137, 60),
             (141, 66), (141, 73), (136, 80), (131, 88), (128, 100), (124, 112), (121, 120), (123, 132), (127, 146),
             (128.5, 152), (125, 157), (121, 153), (117, 159), (113, 152), (108, 158), (104, 151), (98, 160), (93, 152),
             (88, 157), (83, 151), (78, 156), (73, 152), (72, 146), (75, 134), (78, 120), (75, 110), (71, 100), (68, 88),
             (63, 80), (58, 72), (59, 64), (63, 58), (70, 54), (77, 51)]
    pts = [(x, y + br / 2) for x, y in SP(tunic)]
    pc.fill(pts, "uniform", 0.62)
    # desgarro en el pecho: piel gris tirante sobre las costillas
    tear = SP([(76, 89), (81, 85), (85, 88), (88, 92), (93, 95), (96, 103), (95, 109), (91, 113), (86, 110), (81, 106),
               (78, 100)])
    pc.fill(tear, "nskin", 0.5, inside=True)
    # escote en pico con las clavículas
    neck = SP([(86, 51), (114, 51), (109, 56), (100, 77), (91, 56)])
    pc.fill(neck, "nskin", 0.48, inside=True)
    _cloth(pc, 200)
    _skin(pc, 210, 4.0)
    # luz: hombros alzados, sombra bajo el pecho, costado derecho de la pantalla en sombra
    pc.plane(SP([(58, 46), (142, 46), (142, 64), (124, 62), (110, 57), (90, 57), (76, 62), (58, 64)]), 0.12, 4.0)
    pc.plane(SP([(118, 66), (141, 66), (131, 88), (127, 102), (121, 120), (113, 112), (118, 90)]), -0.2, 4.0)
    pc.plane(SP([(76, 112), (124, 112), (121, 120), (124, 134), (76, 134), (79, 120)]), -0.12, 5.0)
    pc.plane(SP([(72, 140), (128, 140), (128, 162), (72, 162)]), -0.16, 4.0)
    pc.plane(SP([(60, 70), (72, 76), (74, 100), (66, 92)]), -0.22, 5.0, clip=["uniform"])     # axilas sudadas
    pc.plane(SP([(140, 70), (128, 76), (126, 100), (134, 92)]), -0.22, 5.0, clip=["uniform"])
    pc.stain(S(92, 150), 16.0, "stain", 225, stretch=(2.2, 0.7), ring=0.06, val=0.4, clip=["uniform"])
    # pliegues: tiran de los hombros hacia el centro y se arrugan en la cintura
    for f in ([(66, 70), (80, 86), (86, 104), (84, 118)], [(134, 70), (120, 88), (114, 104), (116, 118)],
              [(80, 122), (88, 132), (86, 146), (90, 152)], [(118, 122), (110, 134), (112, 148)],
              [(96, 136), (98, 150), (97, 158)], [(104, 116), (110, 120), (116, 117)], [(82, 118), (90, 121), (97, 119)],
              [(70, 60), (78, 66)], [(130, 60), (122, 66)]):
        pc.crease(SP(f), 0.2, 2.0, ridge=0.12, ridge_off=(-2.4, -1), clip=["uniform"])
    _seam(pc, SP([(70, 55), (63, 60), (59, 68)]))
    _seam(pc, SP([(130, 55), (137, 60), (141, 68)]))
    _seam(pc, SP([(73, 104), (76, 134), (73, 150)]))
    _seam(pc, SP([(127, 104), (124, 134), (127, 150)]))
    # costillas y venas en el desgarro, canto deshilachado
    for i, y in enumerate((92, 98, 104, 109)):
        pc.crease(SP([(78 + i, y), (86, y + 2), (94 - i * 0.6, y + 1)]), 0.34, 1.2, ridge=0.24, ridge_off=(0, -2.6),
                  clip=["nskin"])
    pc.veins(S(84, 88), 10, 211, ang=1.7, depth=0.18, mat="vein")
    pc.crease(tear[:6], -0.2, 1.2, clip=["uniform"])
    pc.crease([(x + 1.5, y + 1.5) for x, y in tear[:6]], 0.22, 1.4, clip=["nskin"])
    rnd = random.Random(212)
    for _ in range(14):                                     # hilachas sueltas en el borde del roto
        x, y = tear[rnd.randrange(len(tear))]
        pc.line([(x, y), (x + rnd.uniform(-4, 4), y + rnd.uniform(2, 6))], "uniform", 0.75)
    pc.crease(SP([(88, 56), (96, 60)]), -0.18, 1.2, clip=["nskin"])
    pc.crease(SP([(112, 56), (104, 60)]), -0.14, 1.2, clip=["nskin"])
    pc.crease(SP([(98, 62), (100, 74)]), 0.2, 1.4, clip=["nskin"])
    # bolsillo y tarjeta de identificación (la foto, oscura; el texto, ilegible)
    pc.fill(SP([(110, 96), (122, 96), (121, 107), (111, 107)]), "uniform", 0.55)
    pc.crease(SP([(110, 96), (122, 96)]), -0.18, 1.0)
    pc.crease(SP([(110.5, 107), (121, 107)]), 0.18, 1.0)
    pc.fill(SP([(113, 91), (119.5, 90.5), (120.5, 99.5), (114, 100)]), "porcelain", 0.62)
    pc.fill(SP([(114, 92.5), (116.5, 92.5), (116.5, 96), (114, 96)]), "liquid", 0.3)
    for yy in (93, 94.5, 97.5, 98.8):
        pc.line(SP([(117, yy), (119.5, yy)]) if yy < 96 else SP([(114.5, yy), (119.5, yy)]), "porcelain", 0.25, inside=True)
    pc.line(SP([(116.5, 86), (116.5, 91)]), "metal", 0.7, width=2)
    # sangre: chorreones del cuello cosido, salpicaduras y la mancha que empapa el vientre
    pc.stain(S(97, 80), 7.0, "blood", 220, val=0.3, stretch=(0.5, 2.6), ring=0.12, drip=2.0)
    pc.stain(S(106, 124), 12.0, "blood", 221, val=0.24, stretch=(0.9, 1.4), ring=0.16, drip=1.2, clip=["uniform"])
    pc.stain(S(124, 146), 8.0, "stain", 222, stretch=(0.8, 1.4), ring=0.08, clip=["uniform"])
    pc.stain(S(80, 140), 7.0, "stain", 223, stretch=(1.2, 0.8), ring=0.06, clip=["uniform"])
    pc.gloss(mask=pc.of("blood") & (np.random.default_rng(224).random((H, W)) < 0.04), amount=0.3, soft=0)
    # vías: tres tubos que vienen de la espalda por encima de los hombros y entran en el pecho
    for path in ([(128, 50), (127, 58), (124, 66), (118, 74), (110, 80), (104, 88), (102, 96)],
                 [(136, 56), (135, 66), (131, 78), (124, 90), (116, 98), (110, 102)],
                 [(70, 52), (70, 62), (73, 72), (79, 80), (86, 86), (90, 96)]):
        sp = SP(path)
        m = pc.line(sp, "liquid", 0.3, width=5)
        pc.line([(x - 1, y - 1.5) for x, y in sp[:-1]], "liquid", 0.85, width=1)
        pc.line([(x + 1.6, y + 1.6) for x, y in sp[:-1]], "liquid", 0.05, width=1)
        ex, ey = sp[-1]
        pc.fill([(ex - 5, ey - 2), (ex, ey - 6), (ex + 5, ey - 1), (ex + 1, ey + 4)], "flesh", 0.3)
        pc.fill([(ex - 6, ey - 3), (ex + 6, ey - 1.6), (ex + 6, ey + 1), (ex - 6, ey - 0.4)], "tape", 0.55)
        pc.line([(ex, ey + 4), (ex - 1, ey + 14)], "blood", 0.35, width=2)
        _ = m
    pc.cast(pc.of("liquid"), (3, 4), 2.0, 0.2)
    return pc


def arm_r(pose: dict, br: float = 0.0) -> Piece:
    """Brazo de instrumental: la carne del antebrazo se funde con bisturíes y una sierra."""
    pc = Piece(W, H, "arm_r")
    sh, el, wr = S(*pose["sh_r"]), S(*pose["el_r"]), S(*pose["wr_r"])
    sh, el, wr = (sh[0], sh[1] + br), (el[0], el[1] + br), (wr[0], wr[1] + br)
    ux, uy = _u(el, wr)
    nx, ny = -uy, ux
    out = (nx, ny) if nx < 0 else (-nx, -ny)
    # sierra de hueso: sale del canto exterior del antebrazo
    a0 = lerp(el, wr, 0.28)
    sa = (a0[0] + out[0] * 9, a0[1] + out[1] * 9)
    sb = (sa[0] + ux * 150, sa[1] + uy * 150)
    saw = [sa, sb, (sb[0] + out[0] * 22, sb[1] + out[1] * 22), (sa[0] + out[0] * 16, sa[1] + out[1] * 16)]
    pc.fill(saw, "metal", 0.55)
    # bisturíes que brotan de la muñeca como dedos abiertos
    blades = []
    for ang, ln, off in ((-0.34, 82, -7), (-0.13, 100, -2.4), (0.08, 92, 2.4), (0.3, 72, 7)):
        d = (ux * math.cos(ang) - uy * math.sin(ang), ux * math.sin(ang) + uy * math.cos(ang))
        bx, by = wr[0] + nx * off + ux * 6, wr[1] + ny * off + uy * 6
        bn = (-d[1], d[0])
        cv = 1 if ang < 0 else -1
        tip = (bx + d[0] * ln, by + d[1] * ln)
        belly = (bx + d[0] * ln * 0.62 + bn[0] * 6 * cv, by + d[1] * ln * 0.62 + bn[1] * 6 * cv)
        back1 = (bx + d[0] * ln * 0.82 - bn[0] * 1.6 * cv, by + d[1] * ln * 0.82 - bn[1] * 1.6 * cv)
        poly = [(bx - bn[0] * 2.4 * cv, by - bn[1] * 2.4 * cv), back1, tip, belly, (bx + bn[0] * 4 * cv, by + bn[1] * 4 * cv)]
        pc.fill(poly, "metal", 0.6)
        blades.append((poly, tip, belly, (bx, by), d, bn, cv))
    # brazo
    pc.fill(limb(sh, el, UPPER), "nskin", 0.52)
    pc.fill(limb(el, wr, FORE_FUSED), "nskin", 0.5)
    stump = [(wr[0] + nx * 14 - ux * 4, wr[1] + ny * 14 - uy * 4), (wr[0] - nx * 14 - ux * 4, wr[1] - ny * 14 - uy * 4),
             (wr[0] - nx * 11 + ux * 12, wr[1] - ny * 11 + uy * 12), (wr[0] + nx * 11 + ux * 12, wr[1] + ny * 11 + uy * 12)]
    pc.fill(stump, "flesh", 0.42)
    _skin(pc, 300, 7.0)
    pc.form(LIGHT, bevel=5.0, strength=0.3, rim_dark=0.14, region=pc.of("flesh"))
    pc.noise(0.14, 3.0, 301, clip=["flesh"])
    pc.gloss(mask=pc.of("flesh") & (np.random.default_rng(302).random((H, W)) < 0.06), amount=0.4, soft=0)
    # metal: reflejos largos, filo claro, lomo oscuro, sangre en las puntas
    pc.form(LIGHT, bevel=3.0, strength=0.4, rim_dark=0.1, region=pc.of("metal"))
    for poly, tip, belly, base, d, bn, cv in blades:
        pc.line([poly[-1], belly, tip], "metal", 0.98)
        pc.line([poly[0], poly[1]], "metal", 0.12)
        mid0 = lerp(base, tip, 0.2)
        mid1 = lerp(base, tip, 0.7)
        pc.line([(mid0[0] + bn[0] * 1.4 * cv, mid0[1] + bn[1] * 1.4 * cv),
                 (mid1[0] + bn[0] * 2 * cv, mid1[1] + bn[1] * 2 * cv)], "metal", 0.82, inside=True)
        pc.stain(lerp(base, tip, 0.9), 4.5, "blood", int(tip[0]), val=0.4, stretch=(0.6, 1.6), ring=0.1, clip=["metal"])
    ox, oy = out
    for i in range(1, 30):                                           # dientes de la sierra
        p = lerp(saw[3], saw[2], i / 30)
        pc.fill([(p[0] - ux * 2.4, p[1] - uy * 2.4), (p[0] + ux * 2.4, p[1] + uy * 2.4),
                 (p[0] + ox * 4 + ux * 0.6, p[1] + oy * 4 + uy * 0.6)], "metal", 0.75)
        pc.dot(p[0] + ox * 2, p[1] + oy * 2, "metal", 0.25)
    pc.line([sa, sb], "metal", 0.95)
    pc.line([lerp(sa, sb, 0.05), lerp(sa, sb, 0.9)], "metal", 0.35, inside=True)
    for t, r in ((0.3, 5), (0.55, 7), (0.8, 4)):
        c = lerp(lerp(sa, sb, t), lerp(saw[3], saw[2], t), 0.5)
        pc.stain(c, r, "rust", int(t * 50), val=0.45, ring=0.1, clip=["metal"])
    pc.stain(lerp(lerp(sa, sb, 0.85), lerp(saw[3], saw[2], 0.85), 0.4), 6, "blood", 310, val=0.35, ring=0.1,
             clip=["metal"])
    # costura de grapas donde la carne se une al metal, carne inflamada alrededor
    seam = [lerp(el, wr, 0.24), lerp(el, wr, 0.95)]
    seam = [(p[0] + ox * 7, p[1] + oy * 7) for p in seam]
    pc.stain(lerp(*seam, 0.5), 8, "flesh", 311, stretch=(0.7, 3.6), ring=0.1, val=0.45, clip=["nskin"])
    pc.line(seam, "flesh", 0.15, width=2, inside=True)
    sl = math.hypot(seam[1][0] - seam[0][0], seam[1][1] - seam[0][1])
    for i in range(int(sl / 9)):
        p = lerp(*seam, (i + 0.5) * 9 / sl)
        pc.fill([(p[0] - ox * 5 - ux, p[1] - oy * 5 - uy), (p[0] + ox * 5 - ux, p[1] + oy * 5 - uy),
                 (p[0] + ox * 5 + ux * 2, p[1] + oy * 5 + uy * 2), (p[0] - ox * 5 + ux * 2, p[1] - oy * 5 + uy * 2)],
                "metal", 0.75)
        pc.dot(p[0] - ox * 4, p[1] - oy * 4, "metal", 0.98)
    pc.line([(wr[0] + nx * 12 + ux * 11, wr[1] + ny * 12 + uy * 11), (wr[0] - nx * 12 + ux * 11, wr[1] - ny * 12 + uy * 11)],
            "flesh", 0.12, width=2)
    _anatomy(pc, sh, el, wr, 320)
    _sleeve(pc, sh, el, -1, 330)
    return pc


def _anatomy(pc: Piece, sh, el, wr, seed: int) -> None:
    """Músculo y hueso: hendidura del deltoides, bíceps/tríceps, codo huesudo, tendones, venas."""
    ux, uy = _u(sh, el)
    nx, ny = uy, -ux
    d = lerp(sh, el, 0.32)
    pc.crease([(d[0] - nx * 12, d[1] - ny * 12), (d[0] + nx * 2, d[1] + ny * 2 + 5)], 0.22, 1.6, ridge=0.12,
              ridge_off=(0, -2.2), clip=["nskin"])
    pc.crease([lerp(sh, el, 0.4), lerp(sh, el, 0.86)], 0.16, 1.8, ridge=0.12, ridge_off=(-2.4, 0), clip=["nskin"])
    ex, ey = el
    pc.fill([(ex - 7, ey - 7), (ex + 6, ey - 8), (ex + 9, ey + 1), (ex + 2, ey + 8), (ex - 8, ey + 3)], "nskin", 0.62,
            inside=True)
    pc.plane([(ex - 4, ey - 6), (ex + 3, ey - 7), (ex + 2, ey - 2), (ex - 4, ey - 1)], 0.18, 1.0, clip=["nskin"])
    for k in (2, 6):
        pc.crease([(ex - 6, ey + k), (ex + 6, ey + k - 1)], 0.2, 0.9, clip=["nskin"])
    fu, fv = _u(el, wr)
    fn = (fv, -fu)
    a = lerp(el, wr, 0.45)
    pc.crease([(a[0] - fn[0] * 3, a[1] - fn[1] * 3), (wr[0] - fn[0] * 2, wr[1] - fn[1] * 2)], -0.16, 1.2, clip=["nskin"])
    pc.crease([(a[0] + fn[0] * 4, a[1] + fn[1] * 4), (wr[0] + fn[0] * 3, wr[1] + fn[1] * 3)], 0.12, 1.2, clip=["nskin"])
    pc.veins(lerp(sh, el, 0.5), 14, seed, ang=math.atan2(el[1] - sh[1], el[0] - sh[0]), depth=0.18, mat="vein")
    pc.veins(lerp(el, wr, 0.2), 14, seed + 1, ang=math.atan2(wr[1] - el[1], wr[0] - el[0]), depth=0.18, mat="vein")
    pc.stain(lerp(sh, el, 0.7), 4, "nskin_bruise", seed + 2, stretch=(1.0, 1.4), ring=0.0, clip=["nskin"])


def _sleeve(pc: Piece, sh, el, side: int, seed: int) -> None:
    """Manga corta rota del uniforme sobre el hombro."""
    sx, sy = sh
    e = lerp(sh, el, 0.3)
    rnd = random.Random(seed)
    sleeve = [(sx - 20, sy - 14), (sx + 16, sy - 20), (sx + 24, sy + 8)]
    n = 7
    for k in range(n + 1):
        t = k / n
        p = (e[0] + 18 - t * 40, e[1] + 6 + (rnd.uniform(4, 12) if k % 2 else rnd.uniform(-3, 2)))
        sleeve.append(p)
    sleeve.append((sx - 24, sy + 6))
    if side > 0:
        sleeve = [(2 * sx - x, y) for x, y in sleeve]
    pc.fill(sleeve, "uniform", 0.66)
    pc.form(LIGHT, bevel=6.0, strength=0.3, rim_dark=0.12, region=pc.of("uniform"))
    pc.weave(0.045, 1, clip=["uniform"])
    pc.noise(0.08, 8.0, seed, clip=["uniform"])
    pc.crease([(sx - side * 6, sy - 4), (e[0] - side * 8, e[1] + 4)], 0.2, 1.6, ridge=0.12, ridge_off=(-2.2, 0),
              clip=["uniform"])
    pc.crease([(sx + side * 8, sy - 2), (e[0] + side * 10, e[1] + 6)], 0.16, 1.6, clip=["uniform"])
    pc.plane([(e[0] - 26, e[1] + 2), (e[0] + 26, e[1] + 2), (e[0] + 26, e[1] + 20), (e[0] - 26, e[1] + 20)], -0.22, 2.0,
             clip=["uniform"])
    pc.stain((sx + side * 6, sy + 10), 6.0, "blood", seed + 1, val=0.35, ring=0.12, drip=1.0, clip=["uniform"])


def arm_l(pose: dict, br: float = 0.0) -> Piece:
    """Brazo de la jeringa: dedos largos y nudosos alrededor del cilindro de cristal."""
    pc = Piece(W, H, "arm_l")
    sh, el, wr = S(*pose["sh_l"]), S(*pose["el_l"]), S(*pose["wr_l"])
    sh, el, wr = (sh[0], sh[1] + br), (el[0], el[1] + br), (wr[0], wr[1] + br)
    pc.fill(limb(sh, el, UPPER), "nskin", 0.52)
    pc.fill(limb(el, wr, FORE), "nskin", 0.5)
    sx, top = wr[0] + 2, wr[1] - 22
    bot = top + 112
    # jeringa
    pc.fill([(sx - 11, top - 6), (sx + 11, top - 6), (sx + 11, top), (sx - 11, top)], "metal", 0.55)        # alas
    pc.fill([(sx - 3, top - 44), (sx + 3, top - 44), (sx + 3, top - 6), (sx - 3, top - 6)], "metal", 0.5)     # vástago
    pc.fill([(sx - 11, top - 52), (sx + 11, top - 52), (sx + 11, top - 44), (sx - 11, top - 44)], "metal", 0.55)
    pc.fill([(sx - 9, top), (sx + 9, top), (sx + 9, bot), (sx - 9, bot)], "glass", 0.5)
    pc.fill([(sx - 8, top + 4), (sx + 8, top + 4), (sx + 8, top + 10), (sx - 8, top + 10)], "nail", 0.3)    # goma
    pc.fill([(sx - 8, top + 26), (sx + 8, top + 26), (sx + 8, bot - 2), (sx - 8, bot - 2)], "liquid", 0.35)
    pc.fill([(sx - 4, bot), (sx + 4, bot), (sx + 2.4, bot + 9), (sx - 2.4, bot + 9)], "metal", 0.6)
    pc.line([(sx, bot + 9), (sx + 2, bot + 68)], "metal", 0.85, width=1)
    pc.form(LIGHT, bevel=3.0, strength=0.36, rim_dark=0.1, region=pc.of("metal"))
    pc.form(LIGHT, bevel=4.0, strength=0.3, rim_dark=0.1, region=pc.of("liquid", "glass"))
    pc.line([(sx - 5, top + 3), (sx - 5, bot - 4)], "glass", 0.95)                      # reflejo del cristal
    pc.line([(sx - 3.5, top + 3), (sx - 3.5, bot - 30)], "glass", 0.75, inside=True)
    pc.line([(sx + 7, top + 6), (sx + 7, bot - 4)], "glass", 0.2, inside=True)
    pc.line([(sx - 8, top + 26), (sx + 8, top + 26)], "liquid", 0.8)                     # menisco
    for i, y in enumerate(range(int(top) + 14, int(bot) - 6, 9)):                      # graduación
        pc.line([(sx + 1, y), (sx + (8 if i % 2 else 5), y)], "porcelain", 0.7)
    for k, (bx, by) in enumerate(((sx - 2, top + 50), (sx + 2, top + 64), (sx - 1, top + 84), (sx + 3, top + 40))):
        pc.dot(bx, by, "liquid", 0.9)
        pc.dot(bx + 1, by + 1, "liquid", 0.6)
    pc.line([(sx + 2, bot + 66), (sx + 2, bot + 72)], "liquid", 0.5)                  # gota oscura
    # mano: dorso detrás del cilindro, dedos en diagonal delante, pulgar sobre las alas
    hx, hy = wr
    pc.fill([(sx + 6, hy - 14), (sx + 22, hy - 10), (sx + 23, hy + 16), (sx + 14, hy + 28), (sx + 6, hy + 24)], "nskin", 0.48)
    for i in range(4):
        y = hy - 6 + i * 10
        k0, k1, k2 = (sx + 15, y), (sx - 2, y + 3.4), (sx - 12, y + 7)
        pc.fill(limb(k0, k1, [(0, 3.8, 3.8), (1, 3.2, 3.2)]), "nskin", 0.6)
        pc.fill(limb(k1, k2, [(0, 3.2, 3.2), (1, 2.4, 2.4)]), "nskin", 0.52)
        pc.fill([(k2[0] - 3, k2[1] - 2), (k2[0] + 1, k2[1] - 2.4), (k2[0] + 1, k2[1] + 2), (k2[0] - 3, k2[1] + 2)], "nail", 0.35)
    pc.fill(limb((sx + 12, hy - 18), (sx - 6, hy - 14), [(0, 4, 4), (1, 3, 3)]), "nskin", 0.6)
    _skin(pc, 400, 6.0)
    for i in range(4):
        y = hy - 6 + i * 10
        pc.crease([(sx + 15, y + 3.8), (sx - 12, y + 10.5)], 0.26, 0.9, clip=["nskin"])
        pc.dot(sx + 15, y - 2, "nskin", 0.85)
        pc.dot(sx - 2, y + 1, "nskin", 0.8)
    _anatomy(pc, sh, el, wr, 410)
    _sleeve(pc, sh, el, 1, 420)
    return pc


def head(br: float = 0.0, drop: float = 10.0) -> Piece:
    """Cabeza: cráneo largo con mechones, máscara de porcelana agrietada, mascarilla cosida."""
    pc = Piece(W, H, "head")
    dy = br + drop * 2

    def T(pts):
        return [(x, y + dy) for x, y in SP(pts)]

    pc.fill(T([(91, 46), (109, 46), (111, 60), (89, 60)]), "nskin", 0.4)
    skull = [(87, 21), (92, 17), (98, 15), (104, 15.4), (110, 17), (115, 21), (118.5, 27), (119.5, 34), (119, 41),
             (117.5, 48), (115, 55), (111.5, 62), (107, 68), (100, 72), (93, 68), (88.5, 62), (85, 55), (82.5, 48),
             (81, 41), (80.5, 34), (81.5, 27)]
    pc.fill(T(skull), "nskin", 0.52)
    pc.fill(T([(80.6, 35), (82.6, 34), (83.8, 48), (80.4, 47), (78.4, 41)]), "nskin", 0.44)
    pc.fill(T([(119.4, 35), (117.4, 34), (116.2, 48), (119.6, 47), (121.6, 41)]), "nskin", 0.4)
    _skin(pc, 500, 8.0)
    pc.plane(T([(84, 14), (108, 13), (117, 24), (104, 29), (85, 31)]), 0.12, 3.0)
    for x0, y0, x1, y1, sd in ((96, 16, 89, 28, 501), (108, 18, 114, 31, 502), (101, 15, 100, 24, 503)):
        a, b = T([(x0, y0), (x1, y1)])
        pc.line([a, lerp(a, b, 0.5), (b[0] + 2, b[1])], "nail", 0.4, width=1)            # mechones ralos
        pc.line([(a[0] + 2, a[1]), (b[0] + 3, b[1] - 3)], "nail", 0.25, width=1)
    pc.veins(T([(86, 25)])[0], 12, 504, ang=1.6, depth=0.2, mat="vein")
    pc.veins(T([(113, 22)])[0], 9, 505, ang=1.4, depth=0.2, mat="vein")
    pc.crease(T([(81, 37), (82.6, 46)]), 0.22, 1.0)
    pc.crease(T([(119, 37), (117.4, 46)]), 0.22, 1.0)
    # máscara de porcelana
    mask = [(85, 27), (90, 25), (95, 24), (100, 23.6), (105, 24), (110, 25), (115, 27), (117, 31), (117, 36), (115.5, 42),
            (113.5, 46), (106, 51), (100, 54.5), (94, 51), (86.5, 46), (84.5, 42), (83, 36), (83, 31)]
    pc.fill(T(mask), "porcelain", 0.66)
    por = pc.of("porcelain")
    pc.form(LIGHT, bevel=7.0, strength=0.42, rim_dark=0.1, region=por)
    pc.plane(T([(102, 38), (118, 32), (116, 47), (106, 52), (100, 55)]), -0.16, 3.0, clip=["porcelain"])
    pc.crease(T([(99.4, 33), (99.6, 46), (100, 53)]), -0.18, 1.2, clip=["porcelain"])     # caballete tallado
    pc.crease(T([(101.6, 36), (102, 50)]), 0.12, 1.2, clip=["porcelain"])
    pc.crease(T([(86, 31.5), (94, 29.5)]), -0.14, 1.2, ridge=-0.1, ridge_off=(0, 2.4), clip=["porcelain"])
    pc.crease(T([(105, 29.5), (114, 31.5)]), -0.12, 1.2, ridge=-0.1, ridge_off=(0, 2.4), clip=["porcelain"])
    pc.gloss(T([(88, 27), (95, 25.5), (93, 27.5), (88, 29)]), 0.4, 1.0)
    pc.gloss(T([(97, 26), (99, 26), (98.6, 36), (97.6, 36)]), 0.3, 1.0)
    # cuencas: la izquierda, vacía y negra; en la derecha, un ojo lechoso con vasos rotos
    pc.fill(T([(87, 35), (91, 33.4), (95, 33.6), (97, 37), (95, 40.5), (91, 41.4), (88, 40)]), "liquid", 0.05)
    pc.fill(T([(103, 34.4), (106, 33), (110, 33.4), (112.6, 35.6), (112, 39.8), (108, 41.6), (104.4, 40.4), (102.6, 37.4)]),
            "liquid", 0.1)
    pc.fill(T([(104.2, 36.6), (106.4, 35), (110, 35.4), (111.2, 37.6), (109.6, 39.8), (105.6, 39.8)]), "bone", 0.55)
    pc.form(LIGHT, bevel=2.0, strength=0.3, rim_dark=0.25, region=pc.of("bone"))
    ex, ey = T([(107.6, 37.2)])[0]
    pc.fill([(ex - 1.4, ey - 2.4), (ex + 1.4, ey - 2.4), (ex + 2.4, ey - 1), (ex + 2.4, ey + 1), (ex + 1.4, ey + 2.4),
             (ex - 1.4, ey + 2.4), (ex - 2.4, ey + 1), (ex - 2.4, ey - 1)], "liquid", 0.3)
    pc.dot(ex - 1, ey - 1, "bone", 1.0)
    for vx, vy in ((ex + 4, ey - 1), (ex + 5, ey), (ex - 4, ey + 1), (ex + 3, ey + 2)):
        pc.dot(vx, vy, "blood", 0.6)
    pc.crease(T([(87, 35), (91, 33.4), (95, 33.6)]), -0.12, 0.8, clip=["porcelain"])
    pc.crease(T([(88, 41), (93, 42)]), -0.16, 0.9, clip=["porcelain"])
    # grietas y un trozo saltado con la carne hinchada debajo
    for st, n, sd, ang in (((93, 41.4), 9, 3, 1.9), ((96, 24.4), 6, 8, 2.0), ((113, 30), 6, 11, 2.6), ((110, 47), 4, 12, 0.6)):
        _crack(pc, T([st])[0], n, sd, ang)
    chip = T([(84, 41.4), (88.4, 41.4), (90.6, 46.8), (86, 47.6), (84.4, 45)])
    pc.fill(chip, "flesh", 0.45)
    pc.form(LIGHT, bevel=2.0, strength=0.3, rim_dark=0.2, region=pc.of("flesh"))
    pc.gloss(mask=pc.poly_mask(chip) & (np.random.default_rng(510).random((H, W)) < 0.15), amount=0.35, soft=0)
    # tira de la máscara clavada en las sienes
    pc.line(T([(83, 33), (79.6, 34.4)]), "thread", 0.4, width=2)
    pc.line(T([(117, 33), (120.4, 34.4)]), "thread", 0.4, width=2)
    # mascarilla cosida a la piel
    cloth = [(86, 47.6), (90, 50), (94, 52), (100, 55.4), (106, 52), (110, 50), (114, 47.6), (113.6, 53), (112, 58.6),
             (108.6, 64.6), (104, 69), (100, 70.6), (96, 69), (91.4, 64.6), (88, 58.6), (86.4, 53)]
    pc.fill(T(cloth), "mask_cloth", 0.55)
    pc.form(LIGHT, bevel=5.0, strength=0.32, rim_dark=0.14, region=pc.of("mask_cloth"))
    for a in ((88.5, 56, 100, 59.4, 111.5, 56), (89.5, 61, 100, 64.4, 110.5, 61)):
        pts = T([(a[0], a[1]), (a[2], a[3]), (a[4], a[5])])
        pc.crease(pts, 0.24, 1.4, ridge=0.16, ridge_off=(0, -2.4), clip=["mask_cloth"])
    pc.weave(0.06, 1, clip=["mask_cloth"])
    pc.stain(T([(100, 63)])[0], 7.0, "blood", 520, val=0.3, stretch=(1.3, 1.0), ring=0.14, clip=["mask_cloth"])
    pc.stain(T([(100, 70)])[0], 3.0, "blood", 521, val=0.25, stretch=(0.6, 2.4), ring=0.1, drip=2.0)
    _stitch_line(pc, T([(86.6, 49.4), (87.6, 57.6), (91.6, 65.6), (100, 71.4), (108.4, 65.6), (112.4, 57.6),
                        (113.4, 49.4)]), every=7.0, size=2.6)
    pc.plane(T([(84, 62), (116, 62), (114, 76), (86, 76)]), -0.12, 3.0, clip=["nskin"])
    return pc


def stump_arm_r(pose: dict) -> Piece:
    """Muñón del brazo de instrumental: manga rasgada, el corte con el hueso astillado, sangre."""
    pc = Piece(W, H, "stump_arm_r")
    sh, el = S(*pose["sh_r"]), S(*pose["el_r"])
    sx, sy = sh
    cut = [(sx - 16, sy + 12), (sx - 4, sy + 6), (sx + 8, sy + 8), (sx + 17, sy + 16), (sx + 13, sy + 32), (sx + 2, sy + 38),
           (sx - 10, sy + 36), (sx - 18, sy + 26)]
    pc.fill(cut, "flesh", 0.5)
    pc.form(LIGHT, bevel=5.0, strength=0.36, rim_dark=0.16)
    pc.noise(0.16, 2.5, 600)
    pc.plane([(sx - 20, sy + 26), (sx + 20, sy + 22), (sx + 20, sy + 40), (sx - 20, sy + 40)], -0.2, 2.0)
    bone = [(sx - 5, sy + 15), (sx + 5, sy + 13), (sx + 9, sy + 20), (sx + 5, sy + 28), (sx - 3, sy + 29), (sx - 8, sy + 22)]
    pc.fill(bone, "bone", 0.62)
    pc.form(LIGHT, bevel=3.0, strength=0.35, rim_dark=0.18, region=pc.of("bone"))
    pc.fill([(sx - 2, sy + 19), (sx + 3, sy + 18), (sx + 4, sy + 23), (sx - 1, sy + 24)], "flesh", 0.15)      # médula
    pc.fill([(sx + 5, sy + 13), (sx + 10, sy + 6), (sx + 8, sy + 15)], "bone", 0.7)                           # astilla
    pc.gloss(mask=pc.of("flesh") & (np.random.default_rng(601).random((H, W)) < 0.08), amount=0.45, soft=0)
    _sleeve(pc, sh, el, -1, 602)
    for x, ln in ((sx - 9, 30), (sx + 1, 50), (sx + 10, 18)):
        pc.line([(x, sy + 34), (x + 1, sy + 34 + ln)], "blood", 0.35, width=2)
        pc.line([(x - 0.6, sy + 34), (x - 0.4, sy + 30 + ln)], "blood", 0.8, width=1)
        pc.fill([(x - 2, sy + 34 + ln), (x + 3, sy + 34 + ln), (x + 2, sy + 39 + ln), (x - 1, sy + 39 + ln)], "blood", 0.4)
    return pc


# =============================================================================================
# Poses y montaje
# =============================================================================================

HEAD_DROP = 10.0


def pose_idle(phase: int = 0) -> dict:
    b = 1.5 * phase
    return {
        "hip-1": (90, 142), "knee-1": (82, 196), "ankle-1": (86, 236),
        "hip1": (110, 142), "knee1": (120, 195), "ankle1": (116, 236),
        "sh_r": (65, 70 + b), "el_r": (42, 120 + b), "wr_r": (50, 166 + b * 1.4),
        "sh_l": (135, 63 + b), "el_l": (160, 108 + b), "wr_l": (152, 150 + b * 1.4),
    }


def pose_attack() -> dict:
    p = pose_idle(0)
    p.update({"sh_r": (68, 64), "el_r": (34, 58), "wr_r": (56, 38),
              "sh_l": (134, 70), "el_l": (156, 112), "wr_l": (160, 146)})
    return p


def assemble(pose: dict, br: float = 0.0, tilt: float = -7.0, head_dy: float = 0.0,
             missing: tuple[str, ...] = ()) -> Image.Image:
    layers: list = []
    if "leg_r" not in missing:
        layers.append(leg(-1, pose))
    if "leg_l" not in missing:
        layers.append(leg(1, pose))
    layers.append(body(pose, br))
    if "arm_l" not in missing:
        layers.append(arm_l(pose, br))
    if "head" not in missing:
        h = head(br + head_dy, HEAD_DROP).render()
        if tilt:
            h = rotsprite(h, tilt, (200, 130 + HEAD_DROP * 2 + br))
        layers.append(h)
    layers.append(arm_r(pose, br) if "arm_r" not in missing else stump_arm_r(pose))
    return compose(layers, (W, H), contact=0.3, blur=4.0, contact_off=(4, 6))


def frames() -> dict[str, Image.Image]:
    return {
        "idle_0": assemble(pose_idle(0)),
        "idle_1": assemble(pose_idle(1), br=3.0, tilt=-10, head_dy=1),
        "attack": assemble(pose_attack(), br=-4, tilt=6),
        "stump": assemble(pose_idle(0), missing=("arm_r",)),
    }


def parts() -> list[Image.Image]:
    p = pose_idle(0)
    items = [leg(-1, p), leg(1, p), body(p), arm_r(p), arm_l(p), head(0, HEAD_DROP), stump_arm_r(p)]
    return [it.render() for it in items]


if __name__ == "__main__":
    from paint import row
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n/hd_nurse.png"
    f = frames()
    row([f["idle_0"], f["attack"], f["stump"]], bg=(12, 11, 14)).save(out)
