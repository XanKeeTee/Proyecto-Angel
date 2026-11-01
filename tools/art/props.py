"""Objetos del hospital modelados para pxrender (vista oblicua de mapa: b = 1)."""

from __future__ import annotations

import math
import random

import human
from pxrender import (
    View, Vec, add, basis_rot, box, capsule, cylinder, ellipsoid, fbm, limb, mul, norm, ramp,
    render, rot_y, sphere, transform, RenderResult,
)

ramp("rust", [(28, 16, 12), (48, 28, 18), (72, 42, 26), (98, 60, 36), (122, 82, 50)])
ramp("locker", [(22, 28, 26), (36, 44, 40), (52, 62, 56), (70, 82, 74), (90, 102, 92), (112, 122, 110)])
ramp("mattress", [(18, 24, 22), (28, 38, 34), (40, 54, 48), (54, 70, 62), (70, 86, 76)])
ramp("sheet", [(38, 42, 42), (58, 64, 62), (82, 88, 84), (106, 112, 106), (130, 136, 128), (154, 160, 150)])
ramp("leather", [(16, 10, 8), (28, 19, 15), (44, 30, 23), (62, 44, 34), (84, 62, 48)])
ramp("bag", [(54, 60, 64), (82, 90, 92), (114, 122, 122), (148, 154, 152)])
ramp("tube", [(60, 64, 62), (96, 100, 94), (134, 136, 128)])
ramp("screen", [(6, 12, 8), (12, 22, 14), (18, 32, 20)])
ramp("screen_line", [(110, 160, 56), (160, 206, 90), (204, 236, 146)])
ramp("plastic", [(20, 24, 30), (32, 38, 46), (48, 56, 64), (66, 76, 84), (88, 98, 104)])
ramp("gauze", [(64, 60, 54), (100, 94, 84), (136, 130, 118), (170, 164, 150)])
ramp("ceramic", [(40, 42, 42), (64, 68, 66), (92, 96, 92), (122, 126, 120), (152, 156, 148), (178, 180, 170)])
ramp("curtain", [(26, 34, 32), (40, 52, 48), (58, 72, 66), (78, 92, 84), (98, 112, 102), (120, 132, 120)])
ramp("cloth_green", [(16, 34, 28), (26, 50, 42), (38, 70, 58), (52, 90, 74)])
ramp("rubber", [(12, 12, 14), (22, 22, 26), (34, 34, 38), (48, 48, 52)])
ramp("red_lens", [(120, 24, 20), (180, 48, 36), (228, 110, 90), (250, 190, 170)])
ramp("red_off", [(30, 8, 8), (52, 14, 14), (74, 22, 20)])
ramp("void", [(6, 5, 8), (12, 10, 14), (18, 16, 20)])

MAP_VIEW = View(b=1.0, ambient=0.4)
WALL_VIEW = View(b=0.45, ambient=0.4)


# --- materiales ---------------------------------------------------------------

def mat(name: str, bright: float = 1.0):
    return lambda p, n: (name, bright)


def metal_worn(p: Vec, n: Vec) -> tuple:
    if fbm(mul(p, 0.45), 31) > 0.72:
        return ("rust", 0.95 + 0.1 * fbm(mul(p, 1.0), 32))
    return ("metal", 0.9 + 0.2 * fbm(mul(p, 0.8), 33))


def make_sheet(stain_at: Vec | None = None, stain_r: float = 0.0, folds: float = 0.3):
    def sheet(p: Vec, n: Vec) -> tuple:
        wave = math.sin(p[0] * 0.7 + 4 * fbm(mul(p, 0.08), 41))
        n2 = norm(add(n, (wave * folds, 0.0, math.cos(p[2] * 0.5) * folds * 0.5)))
        bright = 0.92 + 0.1 * wave
        if stain_at is not None:
            dx, dz = p[0] - stain_at[0], p[2] - stain_at[2]
            d = math.sqrt(dx * dx + dz * dz) + 3 * (fbm(mul(p, 0.3), 43) - 0.5)
            if d < stain_r:
                return ("blood_dry", 1.1 - d / stain_r * 0.3, n2)
            if d < stain_r + 2.5:
                return ("stain", bright, n2)
        if fbm(mul(p, 0.15), 44) > 0.75:
            return ("stain", bright, n2)
        return ("sheet", bright, n2)
    return sheet


def locker_mat(p: Vec, n: Vec) -> tuple:
    x, y, z = p
    dent = fbm(mul(p, 0.35), 51) - 0.5
    n2 = norm(add(n, (dent * 0.5, dent * 0.3, 0.0)))
    if n[2] > 0.8:  # frente
        if abs(x) < 0.45 and y > 14:
            return ("void", 1.0, n2)  # junta entre puertas
        for vy in (52.0, 49.5, 47.0):  # rejillas
            if abs(y - vy) < 0.5 and 2.5 < abs(x) < 10.5:
                return ("void", 1.0, n2)
        if abs(y - 13.5) < 0.5:
            return ("void", 1.0, n2)
    if fbm(mul((x, y * 0.4, z), 0.45), 52) > 0.71 or (y < 5 and fbm(mul(p, 0.6), 53) > 0.5):
        return ("rust", 0.9 + 0.2 * fbm(mul(p, 1.1), 54), n2)
    return ("locker", 0.95 + 0.1 * dent, n2)


# --- camilla ---------------------------------------------------------------------

STRETCHER_FRAMES = ["gurney", "lying", "sitting", "messy", "torn"]


def _stretcher_base(sheet_mat, straps: str) -> list:
    prims = []
    for x in (-11.0, 11.0):
        for z in (-26.0, 26.0):
            prims.append(cylinder((x, 3.0, z), (x, 22.0, z), 0.9, metal_worn))
            prims.append(cylinder((x - 0.9, 1.9, z), (x + 0.9, 1.9, z), 1.9, mat("rubber")))
        prims.append(capsule((x * 1.07, 22.6, -29.0), (x * 1.07, 22.6, 29.0), 1.0, metal_worn))
        prims.append(capsule((x * 1.12, 30.0, -21.0), (x * 1.12, 30.0, 9.0), 0.6, metal_worn))
        for z in (-21.0, -6.0, 9.0):
            prims.append(capsule((x * 1.12, 23.0, z), (x * 1.12, 30.0, z), 0.5, metal_worn))
    for z in (-29.0, 29.0):
        prims.append(capsule((-11.8, 22.6, z), (11.8, 22.6, z), 1.0, metal_worn))
    prims.append(box((0.0, 8.0, 0.0), (10.0, 0.5, 24.0), metal_worn))
    prims.append(box((0.0, 28.5, -30.4), (12.0, 6.0, 0.6), metal_worn))
    prims.append(box((0.0, 24.6, 0.0), (11.2, 2.2, 29.0), mat("mattress")))
    prims.append(box((0.0, 27.0, 1.5), (11.5, 0.35, 27.0), sheet_mat))
    for z in (-10.0, 3.0, 20.0):
        if straps == "buckled":
            prims.append(box((0.0, 27.7, z), (12.6, 0.4, 1.4), mat("leather")))
            prims.append(box((7.5, 28.1, z), (1.4, 0.35, 1.8), metal_worn))
        elif straps == "open":
            for side in (-1.0, 1.0):
                prims.append(box((side * 12.9, 22.0, z), (0.35, 5.6, 1.4), mat("leather")))
                prims.append(box((side * 13.0, 16.6, z), (0.45, 1.0, 1.7), metal_worn))
        elif straps == "torn":
            for side in (-1.0, 1.0):
                prims.append(box((side * 12.9, 24.5, z), (0.35, 2.6, 1.4), mat("leather")))
    return prims


def _pillow(dent: bool) -> list:
    shape = (8.5, 1.8 if dent else 2.4, 4.5)
    return [ellipsoid((0.0, 28.4, -23.0), shape, make_sheet(folds=0.15))]


def _blanket_lumps(seed: int, count: int, z0: float, z1: float) -> list:
    rng = random.Random(seed)
    prims = []
    for _ in range(count):
        c = (rng.uniform(-7, 7), rng.uniform(27.8, 29.5), rng.uniform(z0, z1))
        prims.append(ellipsoid(c, (rng.uniform(3, 6), rng.uniform(1.0, 2.2), rng.uniform(3, 6)),
                               make_sheet(folds=0.45), basis=basis_rot(ry=rng.uniform(0, 3))))
    return prims


def stretcher_frames() -> list[list]:
    frames = []
    frames.append(_stretcher_base(make_sheet(), "buckled") + _pillow(False))

    lying = _stretcher_base(make_sheet(), "open") + _pillow(True)
    body = human.build(0.0)
    lying += transform(body, ((1.0, 0.0, 0.0), (0.0, 0.0, -1.0), (0.0, 1.0, 0.0)), (0.0, 30.4, 31.0))
    lying.append(ellipsoid((0.0, 29.4, 14.0), (10.5, 2.6, 14.5), make_sheet(folds=0.4)))
    frames.append(lying)

    sitting = _stretcher_base(make_sheet(), "open") + _pillow(True)
    sitting += transform(human.build(0.0, pose="sit"), ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)),
                         (0.0, 0.6, -10.0))
    sitting.append(ellipsoid((0.0, 29.6, 9.0), (10.0, 3.0, 13.0), make_sheet(folds=0.4)))
    frames.append(sitting)

    messy = _stretcher_base(make_sheet((0.0, 27.0, -6.0), 3.2), "open") + _pillow(True)
    messy += _blanket_lumps(7, 5, 12.0, 24.0)
    frames.append(messy)

    torn = _stretcher_base(make_sheet((1.0, 27.0, -2.0), 7.5), "torn") + _pillow(True)
    torn.append(box((13.2, 20.0, 4.0), (0.4, 8.0, 12.0), make_sheet(folds=0.5), basis=basis_rot(rz=0.25)))
    frames.append(torn)
    return frames


# --- gotero ---------------------------------------------------------------------

def iv_stand() -> list:
    prims = []
    for i in range(5):
        ang = i / 5 * math.tau + 0.3
        end = (math.cos(ang) * 8.0, 2.0, math.sin(ang) * 8.0)
        prims.append(capsule((0.0, 4.0, 0.0), end, 0.55, metal_worn))
        prims.append(sphere((end[0], 1.1, end[2]), 1.1, mat("rubber")))
    prims.append(cylinder((0.0, 3.0, 0.0), (0.0, 66.0, 0.0), 0.55, metal_worn))
    prims.append(capsule((-5.0, 66.0, 0.0), (5.0, 66.0, 0.0), 0.45, metal_worn))
    for x in (-5.0, 5.0):
        prims.append(capsule((x, 66.0, 0.0), (x, 63.5, 0.0), 0.3, metal_worn))
    prims.append(ellipsoid((-5.0, 58.0, 0.0), (2.5, 5.0, 0.9), mat("bag", 1.05), basis=basis_rot(rz=0.08)))
    prims.append(cylinder((-5.0, 52.6, 0.0), (-5.0, 50.4, 0.0), 0.55, mat("bag", 0.9)))
    path = [(-5.0, 50.4, 0.0), (-5.0, 40.0, 0.5), (-3.5, 28.0, 2.0), (0.5, 17.0, 4.0), (4.0, 12.0, 5.5), (5.5, 10.0, 6.0)]
    prims += limb(path[:-1], [0.32] * (len(path) - 1), mat("tube"), steps=2)
    prims.append(capsule(path[-2], path[-1], 0.35, mat("blood_dry", 1.1)))
    prims.append(capsule(path[-1], (6.3, 9.0, 6.4), 0.18, mat("metal", 1.2)))
    return prims


# --- monitor -----------------------------------------------------------------------

def _ecg(x: float) -> float:
    k = (x + 6.0) % 6.5
    if 2.0 < k < 2.5:
        return 2.6
    if 2.5 <= k < 2.9:
        return -1.6
    if 3.6 < k < 4.4:
        return 0.6
    return 0.0


def screen_mat(p: Vec, n: Vec) -> tuple:
    if abs(p[1] - (44.5 + _ecg(p[0]))) < 0.55 or (p[0] > 4.0 and abs(p[1] - 40.6) < 0.6 and p[0] < 5.5):
        return ("!screen_line", 0.85)
    return ("!screen", 0.6 + 0.3 * (1.0 if int(p[1] * 2) % 2 else 0.0))


def monitor() -> list:
    prims = []
    for i in range(4):
        ang = i / 4 * math.tau + 0.78
        end = (math.cos(ang) * 7.0, 2.0, math.sin(ang) * 7.0)
        prims.append(capsule((0.0, 4.0, 0.0), end, 0.55, metal_worn))
        prims.append(sphere((end[0], 1.1, end[2]), 1.0, mat("rubber")))
    prims.append(cylinder((0.0, 3.0, 0.0), (0.0, 37.0, 0.0), 0.7, metal_worn))
    prims.append(box((0.0, 44.0, 0.0), (8.0, 6.2, 3.5), mat("plastic")))
    prims.append(box((0.0, 44.4, 3.55), (6.6, 4.8, 0.15), screen_mat))
    for x in (-5.0, -3.0):
        prims.append(box((x, 38.6, 3.6), (0.6, 0.5, 0.3), mat("metal", 1.1)))
    for i, (end, sag) in enumerate((((8.0, 6.0, 6.0), 4.0), ((10.0, 10.0, 1.0), 2.0), ((5.0, 3.0, 9.0), 5.0))):
        start = (-2.0 + i * 1.6, 38.0, 2.0)
        mid = ((start[0] + end[0]) / 2, (start[1] + end[1]) / 2 - sag, (start[2] + end[2]) / 2)
        prims += limb([start, mid, end], [0.32, 0.32, 0.32], mat("rubber", 1.2), steps=3)
        prims.append(cylinder(end, add(end, (0.0, 0.3, 0.0)), 1.0, mat("gauze", 1.1)))
    return prims


# --- taquilla --------------------------------------------------------------------

def locker(open_drawer: bool) -> list:
    prims = [box((0.0, 31.0, 0.0), (13.0, 31.0, 6.0), locker_mat)]
    for x in (-2.2, 2.2):
        prims.append(box((x, 34.0, 6.3), (0.4, 2.2, 0.4), metal_worn))
    prims.append(box((0.0, 58.0, 6.15), (3.5, 1.4, 0.2), mat("gauze", 1.0)))  # etiqueta
    if open_drawer:
        prims.append(box((0.0, 7.0, 9.5), (12.0, 6.0, 4.0), locker_mat))
        prims.append(box((0.0, 13.05, 9.5), (11.0, 0.05, 3.2), mat("void")))
        prims.append(box((0.0, 7.0, 13.6), (0.0 + 3.0, 0.5, 0.4), metal_worn))
    else:
        prims.append(box((0.0, 7.0, 6.3), (3.0, 0.5, 0.4), metal_worn))
    return prims


# --- bandeja de instrumental ------------------------------------------------------

def tray_cloth(p: Vec, n: Vec) -> tuple:
    # Hueco vacío con cerco de sangre: falta una pieza.
    if -0.3 < p[0] < 2.3 and abs(p[2]) < 3.6:
        edge = abs(p[0] - 1.0) > 0.85 or abs(p[2]) > 2.8
        return ("blood_dry", 1.0) if edge else ("cloth_green", 0.75)
    return ("cloth_green", 0.95 + 0.1 * fbm(mul(p, 0.6), 61))


def tray() -> list:
    prims = []
    for x in (-11.0, 11.0):
        for z in (-6.0, 6.0):
            prims.append(capsule((x, 2.0, z), (x, 23.5, z), 0.6, metal_worn))
            prims.append(sphere((x, 1.0, z), 1.0, mat("rubber")))
    prims.append(box((0.0, 24.0, 0.0), (12.0, 0.6, 7.0), metal_worn))
    prims.append(box((0.0, 10.0, 0.0), (11.0, 0.5, 6.0), metal_worn))
    for x0, z0, x1, z1 in ((-12.0, -7.0, 12.0, -7.0), (-12.0, 7.0, 12.0, 7.0), (-12.0, -7.0, -12.0, 7.0), (12.0, -7.0, 12.0, 7.0)):
        prims.append(capsule((x0, 25.0, z0), (x1, 25.0, z1), 0.5, metal_worn))
    prims.append(box((0.0, 24.75, 0.0), (10.0, 0.15, 5.5), tray_cloth))
    for x in (-8.0, -5.5, -3.0, 4.5, 7.0, 9.0):
        prims.append(capsule((x, 25.2, -3.5), (x, 25.2, 3.5), 0.35, mat("metal", 1.25)))
        prims.append(box((x, 25.2, -3.9), (0.5, 0.3, 0.8), mat("metal", 1.1)))
    return prims


# --- silla de ruedas volcada ------------------------------------------------------

def wheelchair() -> list:
    upright = []
    for side in (-1.0, 1.0):
        center = (side * 10.0, 11.0, -2.0)
        rim = []
        for i in range(17):
            ang = i / 16 * math.tau
            rim.append(add(center, (0.0, math.cos(ang) * 10.0, math.sin(ang) * 10.0)))
        upright += limb(rim, [0.9] * len(rim), mat("rubber", 1.1), steps=1)
        for i in range(6):
            ang = i / 6 * math.pi
            off = (0.0, math.cos(ang) * 9.0, math.sin(ang) * 9.0)
            upright.append(capsule(add(center, mul(off, -1.0)), add(center, off), 0.22, metal_worn))
        upright.append(cylinder(add(center, (-0.8, 0.0, 0.0)), add(center, (0.8, 0.0, 0.0)), 1.1, metal_worn))
        upright.append(capsule((side * 8.0, 18.0, -8.0), (side * 8.0, 18.0, 8.0), 0.6, metal_worn))
        upright.append(capsule((side * 8.0, 18.0, 8.0), (side * 7.0, 3.0, 8.0), 0.55, metal_worn))
        upright.append(cylinder((side * 7.0 - 0.6, 2.0, 9.0), (side * 7.0 + 0.6, 2.0, 9.0), 2.0, mat("rubber")))
        upright.append(capsule((side * 8.0, 18.0, -8.0), (side * 8.0, 34.0, -9.5), 0.6, metal_worn))
    upright.append(box((0.0, 18.4, 0.0), (8.0, 0.8, 8.0), mat("leather", 1.1)))
    upright.append(box((0.0, 26.0, -8.6), (8.0, 7.0, 0.6), mat("leather", 1.1)))
    return transform(upright, basis_rot(rz=math.pi / 2, ry=0.35), (11.0, 0.0, 0.0))


# --- papelera -------------------------------------------------------------------

def gauze_mat(p: Vec, n: Vec) -> tuple:
    if fbm(mul(p, 0.5), 71) > 0.55:
        return ("blood_dry", 1.1)
    return ("gauze", 0.95 + 0.15 * fbm(mul(p, 1.2), 72))


def trash_bin() -> list:
    prims = [cylinder((0.0, 0.0, 0.0), (0.0, 15.0, 0.0), 6.5, metal_worn)]
    prims.append(cylinder((0.0, 14.6, 0.0), (0.0, 15.4, 0.0), 6.9, metal_worn))
    rng = random.Random(3)
    for _ in range(6):
        c = (rng.uniform(-4, 4), rng.uniform(15.5, 18.0), rng.uniform(-4, 4))
        prims.append(ellipsoid(c, (rng.uniform(1.8, 3.0), rng.uniform(1.2, 2.0), rng.uniform(1.8, 3.0)), gauze_mat))
    prims.append(ellipsoid((6.5, 12.0, 2.0), (1.2, 3.5, 1.8), gauze_mat))
    return prims


# --- lavabo ----------------------------------------------------------------------

def sink_inner(p: Vec, n: Vec) -> tuple:
    if abs(p[0]) < 1.0 and abs(p[2] + 2.0) < 1.0:
        return ("void", 1.0)
    if fbm(mul(p, 0.4), 81) > 0.58:
        return ("rust", 0.9)
    return ("ceramic", 0.7)


def sink() -> list:
    prims = [ellipsoid((0.0, 26.0, -3.0), (10.0, 3.6, 6.0), mat("ceramic"),
                       cut=lambda p: p[1] > 27.6 and ((p[0] / 8.8) ** 2 + ((p[2] + 3.0) / 4.8) ** 2) < 1.0)]
    prims.append(ellipsoid((0.0, 25.6, -3.0), (8.6, 2.6, 4.6), sink_inner))
    prims += limb([(0.0, 23.0, -4.0), (0.0, 12.0, -5.5), (0.0, 9.0, -8.0)], [1.0, 1.0, 1.0], metal_worn, steps=2)
    for x in (-3.5, 3.5):
        prims.append(capsule((x, 29.0, -8.5), (x, 31.0, -8.0), 0.6, metal_worn))
    prims.append(capsule((0.0, 31.5, -8.5), (0.0, 31.5, -5.5), 0.6, metal_worn))
    return prims


# --- cortina ---------------------------------------------------------------------

def curtain_mat(p: Vec, n: Vec) -> tuple:
    if p[1] < 14 and fbm(mul(p, 0.3), 91) > 0.5:
        return ("blood_dry", 0.95)
    if fbm(mul(p, 0.12), 92) > 0.62:
        return ("stain", 0.9)
    bright = 0.9 + 0.15 * fbm(mul(p, 0.5), 93)
    if p[1] < 12:
        bright *= 0.85
    return ("curtain", bright)


def curtain() -> list:
    prims = [capsule((-30.0, 62.0, 0.0), (30.0, 62.0, 0.0), 0.5, metal_worn)]
    for x in (-30.0, 30.0):
        prims.append(capsule((x, 62.0, 0.0), (x, 66.0, 0.0), 0.4, metal_worn))
    x = -28.0
    i = 0
    while x < 14.0:
        z = 1.3 if i % 2 else -1.3
        prims.append(capsule((x, 59.0, z * 0.4), (x + 0.4 * math.sin(i), 8.0, z), 1.8, curtain_mat))
        x += 2.6
        i += 1
    return prims


# --- sillas ------------------------------------------------------------------------

def chair(fallen: bool) -> list:
    prims = []
    for x in (-6.0, 6.0):
        for z in (-6.0, 6.0):
            prims.append(capsule((x, 0.5, z), (x, 14.5, z), 0.5, metal_worn))
        prims.append(capsule((x, 15.0, -6.5), (x, 30.0, -7.5), 0.5, metal_worn))
    prims.append(box((0.0, 15.2, 0.0), (7.0, 0.8, 7.0), mat("plastic", 1.1)))
    prims.append(box((0.0, 24.5, -7.2), (7.0, 5.5, 0.7), mat("plastic", 1.1), basis=basis_rot(rx=-0.08)))
    if fallen:
        return transform(prims, basis_rot(rx=-1.45, ry=0.4), (0.0, 7.5, 4.0))
    return prims


# --- luz de emergencia -------------------------------------------------------------

def emergency_light(on: bool) -> list:
    prims = [box((0.0, 0.0, 0.0), (5.5, 3.0, 2.0), mat("metal", 0.9))]
    lens = mat("!red_lens", 0.9) if on else mat("red_off")
    prims.append(ellipsoid((0.0, -0.5, 2.0), (4.2, 2.0, 1.4), lens))
    return prims


# --- utilidades -----------------------------------------------------------------

def render_sheet(frames: list[list], w: int, h: int, origin: tuple[float, float], view: View) -> list[RenderResult]:
    return [render(prims, w, h, origin, view) for prims in frames]
