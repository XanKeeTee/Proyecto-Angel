"""Protagonista en combate, de espaldas y en guardia (160×240, vista de 1280×720).

Postura de lucha: piernas abiertas y flexionadas, peso adelante, hombros tensos y alzados, el tubo
de hierro agarrado con las dos manos por encima del hombro derecho, la cabeza adelantada. La bata se
abre por detrás y deja ver la incisión cosida sobre la columna y los omóplatos tirantes.

Fotogramas: guardia respirando (4) y golpe (el tubo cae en diagonal hacia el enemigo).
Todo son siluetas trazadas a mano y pintadas con `paint` (sin volúmenes 3D).
"""

from __future__ import annotations

import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import palette_hd  # noqa: E402,F401
from paint import Piece, compose, lerp, limb  # noqa: E402

W, H = 160, 240
LIGHT = (-0.3, -0.95)

THIGH = [(0.0, 9.6, 9.2), (0.3, 9.0, 8.4), (0.75, 6.8, 6.4), (1.0, 6.0, 6.0)]
# pantorrilla desde atrás: gemelos abultados arriba, tendón fino abajo
SHIN = [(0.0, 6.0, 6.0), (0.12, 7.2, 6.8), (0.32, 7.4, 6.6), (0.55, 5.4, 4.8), (0.8, 3.4, 3.2), (1.0, 3.6, 3.6)]
UPPER = [(0.0, 7.6, 7.0), (0.2, 7.4, 6.6), (0.6, 5.4, 5.0), (0.92, 4.4, 4.4), (1.0, 5.0, 4.8)]
FORE = [(0.0, 5.0, 5.0), (0.2, 5.8, 5.2), (0.55, 4.6, 4.2), (0.9, 3.4, 3.2), (1.0, 3.4, 3.4)]
SLEEVE = [(0.0, 6.4, 6.2), (0.5, 7.6, 7.2), (1.0, 8.2, 7.8)]


def _skin_paint(pc: Piece, seed: int, bevel: float = 4.0) -> None:
    pc.form(LIGHT, bevel=bevel, strength=0.34, rim_dark=0.14)
    pc.noise(0.1, 4.0, seed, clip=["skin"])
    pc.pores(0.05, 0.1, seed + 1, clip=["skin"])


def legs(pose: dict) -> Piece:
    pc = Piece(W, H, "legs")
    for hip, knee, ankle, outer, seed in ((pose["hip_l"], pose["knee_l"], pose["ankle_l"], -1, 1),
                                          (pose["hip_r"], pose["knee_r"], pose["ankle_r"], 1, 2)):
        pc.fill(limb(hip, knee, THIGH), "skin", 0.5)
        shin = SHIN if outer > 0 else [(t, r, l) for t, l, r in SHIN]
        pc.fill(limb(knee, ankle, shin), "skin", 0.5)
        ax, ay = ankle
        heel = [(ax - 4.4, ay - 1), (ax + 4.4, ay - 1), (ax + 5.2, ay + 6), (ax + 3.6, ay + 12.5), (ax - 3.6, ay + 12.5),
                (ax - 5.2, ay + 6)]
        pc.fill(heel, "skin", 0.5)
    _skin_paint(pc, 10)
    for hip, knee, ankle, outer in ((pose["hip_l"], pose["knee_l"], pose["ankle_l"], -1),
                                    (pose["hip_r"], pose["knee_r"], pose["ankle_r"], 1)):
        kx, ky = knee
        # corva: pliegue en H con los tendones de los isquios
        pc.crease([(kx - 4.4, ky + 0.6), (kx + 4.2, ky - 0.4)], 0.26, 1.2)
        pc.crease([(kx - 3.6, ky - 7), (kx - 3.0, ky + 1)], 0.16, 1.0, ridge=0.1, ridge_off=(-1.4, 0))
        pc.crease([(kx + 3.6, ky - 7), (kx + 3.0, ky + 1)], 0.16, 1.0, ridge=0.1, ridge_off=(1.4, 0))
        # gemelos: luz arriba, surco en medio, tendón de Aquiles
        g0 = lerp(knee, ankle, 0.12)
        g1 = lerp(knee, ankle, 0.5)
        pc.crease([g0, g1], 0.18, 1.1)
        for k in (-3.2, 3.0):
            pc.plane([(g0[0] + k - 2.6, g0[1] + 1), (g0[0] + k + 2.6, g0[1] + 1), (g1[0] + k * 0.5 + 1, g1[1] - 3),
                      (g1[0] + k * 0.5 - 1, g1[1] - 3)], 0.12, 1.4)
        a0 = lerp(knee, ankle, 0.62)
        pc.crease([a0, (ankle[0], ankle[1] - 1)], -0.14, 0.8)
        # talón: planta sucia y agrietada
        ax, ay = ankle
        pc.stain((ax, ay + 10), 6.0, "dirt", 20 + outer, stretch=(1.1, 0.8), ring=0.06, val=0.4)
        pc.crease([(ax - 3, ay + 9), (ax + 3.2, ay + 10)], 0.18, 0.7)
        pc.dot(ax + outer * 4.4, ay - 1.5, "skin", 0.78)                 # maléolo
        # sombra de la bata sobre los muslos
        hx, hy = hip
        pc.plane([(hx - 12, hy - 10), (hx + 12, hy - 10), (hx + 12, hy + 20), (hx - 12, hy + 26)], -0.25, 3.0)
    pc.stain(lerp(pose["knee_l"], pose["ankle_l"], 0.35), 3.0, "skin_bruise", 25, stretch=(0.8, 1.6), ring=0.0)
    pc.line([lerp(pose["knee_r"], pose["ankle_r"], 0.25), lerp(pose["knee_r"], pose["ankle_r"], 0.38)], "blood", 0.42,
            inside=True)
    pc.plane([(0, 205), (W, 205), (W, H), (0, H)], -0.18, 4.0)            # el foco no llega a los pies
    return pc


def torso(pose: dict, br: float) -> Piece:
    """Espalda desnuda y los dos paneles de la bata (con las mangas)."""
    pc = Piece(W, H, "torso")
    rot = pose.get("rot", 0.0)                                        # giro de los hombros (golpe)
    lsh, rsh = pose["sh_l"], pose["sh_r"]
    back = [(74 + rot, 43 + br), (92 + rot, 43 + br), (rsh[0] - 6, rsh[1] - 8), (rsh[0] + 6, rsh[1] - 1),
            (rsh[0] + 7, rsh[1] + 14), (110, 92), (106, 112), (104, 128), (100, 142), (96, 152), (66, 152), (60, 142),
            (58, 128), (56, 110), (52, 90), (lsh[0] - 6, lsh[1] + 14), (lsh[0] - 6, lsh[1] - 1), (lsh[0] + 6, lsh[1] - 8)]
    pc.fill(back, "skin", 0.52)
    _skin_paint(pc, 30, 5.0)
    sp = [(83 + rot, 48 + br), (83.5 + rot * 0.6, 70), (82.6, 96), (83, 120), (82.4, 140)]
    # omóplatos tirantes (los brazos en alto los separan), dorsales, costillas
    for sx, k in ((-1, lsh), (1, rsh)):
        cx = 83 + sx * 13
        pc.crease([(cx - sx * 6, 62 + br), (cx + sx * 1, 74 + br), (cx + sx * 7, 84)], 0.22, 1.4, ridge=0.16,
                  ridge_off=(-sx * 1.5, -1.5))
        pc.plane([(cx - 6, 58 + br), (cx + 6, 58 + br), (cx + sx * 6, 74), (cx - sx * 2, 70)], 0.12, 1.6)
        for i, y in enumerate((96, 104, 112)):
            pc.crease([(83 + sx * 10, y), (83 + sx * 18, y + 3 + i)], 0.12, 0.9, ridge=0.06, ridge_off=(0, -1.4))
    pc.plane([(70, 43), (96, 43), (rsh[0], rsh[1] - 2), (lsh[0], lsh[1] - 2)], 0.16, 2.0)   # trapecios a la luz
    pc.crease(sp, 0.2, 1.6, ridge=0.1, ridge_off=(1.6, 0))
    for y in (54, 62, 70, 78, 86):                                    # apófisis de la columna
        pc.dot(83, y + br * 0.5, "skin", 0.8)
    # incisión cosida a lo largo de la columna: carne, costra, hilo negro y cardenal alrededor
    pc.stain((83, 100), 5.0, "skin_bruise", 31, stretch=(0.9, 5.4), ring=0.0)
    inc = [(83.2, 72), (82.6, 92), (83.4, 112), (82.8, 134)]
    pc.line(inc, "flesh", 0.36, width=2)
    pc.line([(84.2, 74), (83.6, 92), (84.2, 112)], "flesh", 0.6, inside=True)
    for y in range(75, 134, 5):
        pc.line([(80.6, y), (85.6, y + 1.2)], "thread", 0.32, inside=True)
        pc.dot(80.2, y, "blood", 0.35)
    pc.stain((83, 118), 1.6, "blood", 32, stretch=(0.7, 2.4), ring=0.06, drip=1.5)
    # ropa interior
    pc.fill_mask(pc.poly_mask([(60, 138), (104, 138), (100, 156), (64, 156)]) & pc.mask, "brief", 0.42)
    pc.crease([(62, 139), (102, 139)], -0.18, 0.8, clip=["brief"])
    pc.crease([(83, 140), (83, 156)], 0.2, 1.0, clip=["brief"])
    # paneles de la bata, abiertos por detrás
    left = [(70 + rot, 41 + br), (80 + rot, 44 + br), (79, 56), (74, 76), (70, 100), (70, 126), (73, 152), (74, 166),
            (68, 168), (63, 165), (57, 169), (52, 165), (45, 167), (46, 150), (51, 124), (53, 104), (52, 86),
            (lsh[0] - 7, lsh[1] + 12), (lsh[0] - 7, lsh[1] - 2), (lsh[0] + 4, lsh[1] - 9)]
    right = [(96 + rot, 41 + br), (86 + rot, 44 + br), (88, 56), (93, 76), (97, 100), (97, 126), (94, 152), (93, 166),
             (99, 169), (104, 165), (110, 169), (116, 165), (121, 167), (118, 148), (112, 124), (110, 104), (113, 86),
             (rsh[0] + 7, rsh[1] + 12), (rsh[0] + 6, rsh[1] - 2), (rsh[0] - 4, rsh[1] - 9)]
    pc.fill(left, "gown", 0.55)
    pc.fill(right, "gown", 0.55)
    gown = pc.of("gown")
    pc.form(LIGHT, bevel=5.0, strength=0.3, rim_dark=0.12, region=gown)
    # mangas: caen abiertas de los hombros alzados
    for k, el, sd in ((lsh, pose["el_l"], -1), (rsh, pose["el_r"], 1)):
        sl = limb((k[0] - sd * 1, k[1] - 2), lerp(k, el, 0.42), SLEEVE)
        pc.fill(sl, "gown", 0.56)
        e = lerp(k, el, 0.45)
        pc.crease([lerp(k, e, 0.2), lerp(k, e, 0.95)], 0.16, 1.2, ridge=0.1, ridge_off=(-1.5, 0))
        pc.plane([(e[0] - 10, e[1] - 2), (e[0] + 10, e[1] - 2), (e[0] + 10, e[1] + 4), (e[0] - 10, e[1] + 4)], -0.22,
                 1.0, clip=["gown"])
    pc.form(LIGHT, bevel=3.0, strength=0.2, rim_dark=0.08, region=pc.of("gown"))
    # pliegues tensos: tiran de los hombros hacia la cintura, y caen en el bajo
    for pts in ([(lsh[0] + 2, lsh[1]), (60, 84), (56, 120), (52, 164)],
                [(66, 52), (63, 90), (64, 128), (62, 164)],
                [(rsh[0] - 2, rsh[1]), (106, 86), (110, 122), (114, 164)],
                [(100, 52), (103, 92), (104, 130), (106, 164)],
                [(54, 70), (66, 78)], [(112, 70), (100, 80)]):
        pc.crease(pts, 0.17, 1.4, ridge=0.1, ridge_off=(-1.5, 0), clip=["gown"])
    # canto de la abertura: la tela se dobla (filo claro) y deja sombra sobre la piel
    pc.crease([(79, 56), (74, 76), (70, 100), (70, 126), (73, 152)], -0.15, 0.9, clip=["gown"])
    pc.crease([(89, 56), (94, 76), (98, 100), (98, 126), (95, 152)], 0.24, 1.2, clip=["skin", "skin_bruise", "brief"])
    pc.crease([(78, 56), (73, 76), (69, 100), (69, 126)], 0.18, 1.0, clip=["skin", "skin_bruise", "brief"])
    # lazos: uno anudado en la nuca, otro suelto
    pc.fill([(79, 44 + br), (88, 44 + br), (88, 49 + br), (79, 49 + br)], "gown", 0.62)
    pc.line([(81, 49 + br), (79, 60 + br)], "gown", 0.6, width=2)
    pc.line([(86, 49 + br), (88, 58 + br)], "gown", 0.5, width=2)
    pc.line([(71, 100), (77, 103), (76, 112)], "gown", 0.62, width=2)
    pc.weave(0.05, 1, clip=["gown"])
    pc.noise(0.08, 8.0, 34, clip=["gown"])
    yy, xx = np.mgrid[0:H, 0:W]
    pr = ((xx + yy) % 9 == 0) & ((xx - yy) % 9 == 0) & pc.of("gown")
    pc.val[pr] -= 0.08
    pc.stain((50, 162), 9, "dirt", 35, stretch=(1.4, 0.6), ring=0.05, val=0.42, clip=["gown"])
    pc.stain((112, 120), 4.0, "blood", 36, stretch=(0.8, 1.8), ring=0.12, drip=1.0, clip=["gown"])
    pc.plane([(0, 150), (W, 150), (W, 175), (0, 175)], -0.14, 3.0, clip=["gown"])
    return pc


def arm(pose: dict, side: str) -> Piece:
    pc = Piece(W, H, "arm_" + side)
    sh, el, wr, hand = pose["sh_" + side], pose["el_" + side], pose["wr_" + side], pose["hand_" + side]
    pc.fill(limb(sh, el, UPPER), "skin", 0.5)
    pc.fill(limb(el, wr, FORE), "skin", 0.5)
    # puño cerrado alrededor del tubo: dorso y nudillos marcados
    hx, hy = hand
    ux, uy = (hx - wr[0]), (hy - wr[1])
    n = math.hypot(ux, uy) or 1
    ux, uy = ux / n, uy / n
    nx, ny = -uy, ux
    fist = [(wr[0] + nx * 3.6, wr[1] + ny * 3.6), (hx + nx * 5 + ux * 2, hy + ny * 5 + uy * 2),
            (hx + ux * 6, hy + uy * 6), (hx - nx * 5 + ux * 2, hy - ny * 5 + uy * 2), (wr[0] - nx * 3.6, wr[1] - ny * 3.6)]
    pc.fill(fist, "skin", 0.54)
    _skin_paint(pc, 40 if side == "r" else 41, 3.5)
    for k in (-2.6, 0, 2.6):
        pc.crease([(hx + nx * k + ux * 1, hy + ny * k + uy * 1), (hx + nx * k + ux * 5.5, hy + ny * k + uy * 5.5)], 0.2, 0.7)
        pc.dot(hx + nx * k + ux * 2, hy + ny * k + uy * 2, "skin", 0.8)
    # músculos tensos: tríceps, codo, tendones del antebrazo, venas hinchadas
    pc.crease([lerp(sh, el, 0.2), lerp(sh, el, 0.85)], 0.14, 1.2, ridge=0.12, ridge_off=(0, -1.6))
    pc.plane([(el[0] - 3, el[1] - 3), (el[0] + 3, el[1] - 3), (el[0] + 3, el[1] + 2), (el[0] - 3, el[1] + 2)], 0.14, 0.9)
    pc.crease([lerp(el, wr, 0.15), lerp(el, wr, 0.85)], -0.12, 1.0)
    pc.veins(lerp(el, wr, 0.3), 9, 43 if side == "r" else 44, ang=math.atan2(wr[1] - el[1], wr[0] - el[0]),
             depth=0.14, mat="skin_bruise")
    if side == "r":
        b0, b1 = lerp(el, wr, 0.82), lerp(el, wr, 0.97)
        pc.fill(limb(b0, b1, [(0, 5.6, 5.6), (1, 5.2, 5.2)]), "band", 0.62)
        pc.form(LIGHT, bevel=2.0, strength=0.3, rim_dark=0.08, region=pc.of("band"))
        m = lerp(b0, b1, 0.5)
        pc.line([(m[0] - 2.4, m[1] - 1), (m[0] + 2.0, m[1] + 1)], "band", 0.2, inside=True)
        pc.line([(m[0] - 1.4, m[1] + 1), (m[0] + 2.4, m[1] + 2.6)], "band", 0.3, inside=True)
    else:
        t = lerp(wr, hand, 0.4)
        pc.fill([(t[0] - 4, t[1] - 3), (t[0] + 3.6, t[1] - 3.6), (t[0] + 4.2, t[1] + 2.6), (t[0] - 3.4, t[1] + 3.2)], "tape", 0.6)
        pc.stain((t[0], t[1] + 4), 2.4, "blood", 45, stretch=(0.6, 2.2), ring=0.1, drip=1.0)
        tube = [(t[0] + 1, t[1] + 2), (t[0] + 4, t[1] + 10), (t[0] + 2, t[1] + 18), (t[0] + 5, t[1] + 26)]
        pc.line(tube, "tube", 0.55, width=2)
        pc.line(tube[:2], "tube", 0.85)
    pc.plane([(0, 0), (W, 0), (W, 50), (0, 50)], 0.06, 4.0)
    return pc


def pipe(pose: dict) -> Piece:
    """Tubo de hierro oxidado con un codo roscado en la punta."""
    pc = Piece(W, H, "pipe")
    a, b = pose["pipe_a"], pose["pipe_b"]
    pc.fill(limb(a, b, [(0, 3.2, 3.2), (1, 3.2, 3.2)]), "iron", 0.5)
    ux, uy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(ux, uy)
    ux, uy = ux / n, uy / n
    nx, ny = -uy, ux
    c = (b[0] + ux * 2, b[1] + uy * 2)
    pc.fill([(c[0] + nx * 5 - ux * 6, c[1] + ny * 5 - uy * 6), (c[0] - nx * 5 - ux * 6, c[1] - ny * 5 - uy * 6),
             (c[0] - nx * 5 + ux * 4, c[1] - ny * 5 + uy * 4), (c[0] + nx * 5 + ux * 4, c[1] + ny * 5 + uy * 4)],
            "iron", 0.5)
    for i in range(3):                                                    # rosca
        p = (a[0] + ux * (2 + i * 2), a[1] + uy * (2 + i * 2))
        pc.line([(p[0] + nx * 3.2, p[1] + ny * 3.2), (p[0] - nx * 3.2, p[1] - ny * 3.2)], "iron", 0.25, inside=True)
    pc.form(LIGHT, bevel=2.4, strength=0.4, rim_dark=0.1)
    pc.line([(a[0] - nx * 1.4, a[1] - ny * 1.4), (b[0] - nx * 1.4, b[1] - ny * 1.4)], "iron", 0.92, inside=True)
    for t, r in ((0.3, 2.0), (0.55, 3.0), (0.8, 1.6)):
        pc.stain(lerp(a, b, t), r, "rust", int(t * 100), stretch=(1.2, 1.2), ring=0.1, val=0.4)
    pc.stain(c, 3.0, "blood", 51, ring=0.1, val=0.4)
    return pc


def head(pose: dict, br: float) -> Piece:
    """Cráneo rapado visto desde atrás y algo de arriba (la cabeza va adelantada), con la cicatriz."""
    pc = Piece(W, H, "head")
    hx, hy = pose["head"]
    hy += br
    pc.fill([(hx - 6, hy + 8), (hx + 6, hy + 8), (hx + 7.5, hy + 18), (hx - 7.5, hy + 18)], "skin", 0.46)    # nuca
    skull = [(hx - 4, hy - 13), (hx + 5, hy - 13), (hx + 11, hy - 9), (hx + 13.5, hy - 2), (hx + 13, hy + 6),
             (hx + 10, hy + 12), (hx + 5, hy + 15), (hx - 5, hy + 15), (hx - 10, hy + 12), (hx - 13, hy + 6),
             (hx - 13.5, hy - 2), (hx - 11, hy - 9)]
    pc.fill(skull, "scalp", 0.55)
    for sd in (-1, 1):
        ear = [(hx + sd * 12.6, hy - 2), (hx + sd * 16, hy - 1), (hx + sd * 16.4, hy + 6), (hx + sd * 13.2, hy + 9)]
        pc.fill(ear, "skin", 0.46)
        pc.crease([(hx + sd * 14, hy), (hx + sd * 14.6, hy + 6)], 0.2, 0.9)
    pc.form(LIGHT, bevel=5.0, strength=0.36, rim_dark=0.14)
    pc.plane([(hx - 12, hy - 14), (hx + 2, hy - 14), (hx - 4, hy - 4), (hx - 13, hy)], 0.12, 2.5)
    pc.pores(0.07, 0.25, 60, clip=["scalp"])
    pc.noise(0.07, 3.0, 61)
    pc.crease([(hx - 3.4, hy + 14), (hx - 3, hy + 18)], 0.14, 1.2, ridge=0.1, ridge_off=(-1.5, 0))   # tendones
    pc.crease([(hx + 3.4, hy + 14), (hx + 3, hy + 18)], 0.14, 1.2, ridge=0.1, ridge_off=(1.5, 0))
    pc.crease([(hx - 11, hy + 13), (hx + 11, hy + 13)], 0.2, 1.5)                                   # pliegue de la nuca
    # cicatriz: baja de la coronilla a detrás de la oreja izquierda, con puntos
    scar = [(hx - 2, hy - 13), (hx - 6, hy - 8), (hx - 9.5, hy - 2), (hx - 11.5, hy + 5)]
    pc.stain((hx - 7, hy - 4), 3.4, "skin_bruise", 62, stretch=(0.8, 2.2), ring=0.0, clip=["scalp"])
    pc.line(scar, "flesh", 0.4, width=1)
    pc.crease(scar, 0.1, 1.4, ridge=0.12, ridge_off=(1.4, 0))
    for i in range(6):
        t = (i + 0.5) / 6
        p = lerp(scar[0], scar[-1], t)
        pc.line([(p[0] - 1.8, p[1] - 0.8), (p[0] + 1.8, p[1] + 0.5)], "thread", 0.3, inside=True)
    return pc


def pose_guard(phase: int = 0) -> dict:
    b = [0, 1, 2, 1][phase % 4]
    return {
        "hip_l": (69, 142), "knee_l": (54, 180), "ankle_l": (50, 219),
        "hip_r": (96, 142), "knee_r": (111, 177), "ankle_r": (115, 218),
        "sh_l": (54, 60 - b), "el_l": (88, 72 - b), "wr_l": (112, 54 - b), "hand_l": (116, 50 - b),
        "sh_r": (111, 57 - b), "el_r": (139, 72 - b * 0.5), "wr_r": (128, 42 - b), "hand_r": (124, 36 - b),
        "pipe_a": (110, 66 - b), "pipe_b": (146, 6 - b), "head": (83, 36), "rot": 0.0, "br": -b,
    }


def pose_strike() -> dict:
    p = pose_guard(0)
    p.update({
        "sh_l": (52, 64), "el_l": (40, 88), "wr_l": (36, 112), "hand_l": (32, 118),
        "sh_r": (106, 64), "el_r": (82, 96), "wr_r": (48, 112), "hand_r": (40, 116),
        "pipe_a": (50, 108), "pipe_b": (6, 170), "head": (78, 40), "rot": -4.0, "br": 2,
        "knee_l": (52, 182), "knee_r": (112, 180),
    })
    return p


def frame(pose: dict) -> Image.Image:
    br = pose["br"]
    pieces: list = [legs(pose)]
    strike = pose["pipe_b"][1] > pose["pipe_a"][1]
    if strike:
        pieces += [pipe(pose), arm(pose, "r"), arm(pose, "l"), torso(pose, br), head(pose, br)]
    else:
        pieces += [arm(pose, "l"), torso(pose, br), head(pose, br), pipe(pose), arm(pose, "r")]
    return compose(pieces, (W, H), contact=0.3, blur=3.0)


def frames() -> list[Image.Image]:
    return [frame(pose_guard(i)) for i in range(4)] + [frame(pose_strike())]


if __name__ == "__main__":
    from paint import row, upscale
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n/hd_battle.png"
    upscale(row(frames()), 2).save(out)
