"""Mobiliario y máquinas añadidos para el prólogo completo (vista oblicua de mapa)."""

from __future__ import annotations

import math
import random

import human
import tiles_extra  # noqa: F401  (rampa "wood")
from props import gauze_mat, locker_mat, make_sheet, mat, metal_worn
from pxrender import Vec, basis_rot, box, capsule, cylinder, ellipsoid, fbm, mul, ramp, sphere, transform

ramp("crt", [(4, 8, 6), (10, 18, 12), (16, 28, 18)])
ramp("crt_on", [(60, 110, 70), (110, 170, 110), (170, 220, 160)])
ramp("bakelite", [(12, 10, 10), (24, 20, 18), (40, 34, 30), (58, 50, 44)])
ramp("cardboard", [(40, 30, 20), (62, 48, 32), (86, 68, 46), (110, 90, 62)])
ramp("bottle", [(30, 40, 30), (50, 70, 50), (80, 104, 74), (120, 140, 104)])
ramp("amber", [(50, 24, 8), (86, 44, 14), (124, 70, 24), (160, 100, 40)])
ramp("led_red", [(140, 20, 20), (220, 50, 40), (255, 140, 120)])
ramp("led_green", [(40, 120, 40), (90, 200, 80), (180, 250, 160)])
ramp("lamp_warm", [(170, 150, 110), (220, 200, 150), (250, 240, 210)])
ramp("canvas", [(40, 40, 36), (64, 62, 56), (90, 88, 78), (118, 114, 102)])
ramp("plastic_yellow", [(60, 50, 10), (100, 84, 20), (140, 120, 40), (176, 156, 70)])


def wood_mat(p: Vec, n: Vec) -> tuple:
    grain = math.sin(p[0] * 0.9 + 3 * fbm(mul(p, 0.2), 201)) * 0.5 + 0.5
    return ("wood", 0.75 + 0.35 * grain)


def paper_mat(p: Vec, n: Vec) -> tuple:
    if fbm(mul(p, 0.5), 202) > 0.7:
        return ("stain", 1.0)
    return ("gauze", 1.05)


# --- habitación ----------------------------------------------------------------------------

def nightstand(open_: bool) -> list:
    prims = [box((0.0, 9.0, 0.0), (9.0, 9.0, 7.0), locker_mat)]
    prims.append(box((0.0, 18.3, 0.0), (9.4, 0.6, 7.4), metal_worn))
    if open_:
        prims.append(box((0.0, 13.5, 9.0), (8.0, 3.0, 4.0), locker_mat))
        prims.append(box((0.0, 16.55, 9.0), (7.0, 0.05, 3.2), mat("void")))
    else:
        prims.append(box((0.0, 13.5, 7.15), (7.5, 0.4, 0.2), mat("void")))
        prims.append(box((0.0, 14.5, 7.3), (1.5, 0.4, 0.3), metal_worn))
    prims.append(cylinder((-4.0, 18.9, -2.0), (-4.0, 22.0, -2.0), 1.5, mat("bag", 0.8)))  # vaso
    return prims


# --- escritorio, ordenador, teléfono ----------------------------------------------------------

def desk(open_: bool) -> list:
    prims = [box((0.0, 24.0, 0.0), (30.0, 1.2, 12.0), wood_mat)]
    for x in (-27.0, -9.0):
        for z in (-10.0, 10.0):
            prims.append(capsule((x, 0.5, z), (x, 23.0, z), 0.8, metal_worn))
    prims.append(box((18.0, 11.5, 0.0), (11.0, 11.5, 11.0), wood_mat))
    for y in (7.0, 14.0, 20.0):
        prims.append(box((18.0, y, 11.1), (10.0, 0.25, 0.15), mat("void")))
        prims.append(box((18.0, y - 2.5, 11.3), (2.0, 0.4, 0.3), metal_worn))
    if open_:
        prims.append(box((18.0, 18.5, 16.0), (10.0, 2.6, 5.0), wood_mat))
        prims.append(box((18.0, 21.15, 16.0), (9.0, 0.05, 4.2), mat("void")))
    rng = random.Random(5)
    for _ in range(4):
        prims.append(box((rng.uniform(-24, 4), 25.3, rng.uniform(-8, 8)), (4.0, 0.15, 5.5), paper_mat,
                         basis=basis_rot(ry=rng.uniform(-0.6, 0.6))))
    return prims


def computer(on: bool) -> list:
    prims = [box((0.0, 31.0, -1.0), (8.0, 6.5, 7.0), mat("plastic", 1.2))]
    prims.append(box((0.0, 31.5, 6.1), (6.0, 4.6, 0.2), mat("!crt_on", 0.8) if on else mat("crt")))
    prims.append(box((0.0, 25.8, 7.0), (7.0, 0.6, 3.5), mat("plastic", 1.1)))  # teclado
    return prims


def phone(off_hook: bool) -> list:
    prims = [box((0.0, 2.0, 0.0), (4.0, 2.0, 3.5), mat("bakelite"))]
    prims.append(cylinder((0.0, 4.0, 0.5), (0.0, 4.3, 0.5), 2.0, mat("metal", 1.0)))
    if off_hook:
        prims.append(capsule((5.0, 0.8, 4.0), (9.0, 0.8, 7.0), 1.0, mat("bakelite", 1.2)))
        for i in range(6):
            prims.append(sphere((3.5 + i * 0.8, 1.0, 1.5 + i * 0.9), 0.35, mat("bakelite")))
    else:
        prims.append(capsule((-3.5, 4.8, -1.0), (3.5, 4.8, -1.0), 1.0, mat("bakelite", 1.2)))
    return prims


# --- archivo ------------------------------------------------------------------------------------

def filing_cabinet(open_: bool) -> list:
    prims = [box((0.0, 22.0, 0.0), (9.0, 22.0, 9.0), locker_mat)]
    for y in (10.0, 21.0, 32.0, 43.0):
        prims.append(box((0.0, y - 5.5, 9.05), (8.0, 0.25, 0.15), mat("void")))
        prims.append(box((0.0, y - 2.0, 9.3), (2.5, 0.5, 0.4), metal_worn))
        prims.append(box((0.0, y - 8.0, 9.2), (2.0, 1.0, 0.1), mat("gauze", 1.1)))
    if open_:
        prims.append(box((0.0, 37.5, 15.0), (8.0, 5.0, 6.0), locker_mat))
        prims.append(box((0.0, 42.55, 15.0), (7.0, 0.05, 5.2), mat("void")))
        for i in range(5):
            prims.append(box((0.0, 43.2, 11.0 + i * 2.0), (6.0, 1.5, 0.2), paper_mat))
    return prims


def shelf(bottles: bool) -> list:
    prims = []
    for x in (-29.0, 29.0):
        for z in (-5.0, 5.0):
            prims.append(capsule((x, 0.5, z), (x, 58.0, z), 0.7, metal_worn))
    rng = random.Random(9 if bottles else 8)
    for y in (2.0, 20.0, 38.0, 56.0):
        prims.append(box((0.0, y, 0.0), (29.5, 0.6, 5.5), metal_worn))
        x = -26.0
        while x < 26.0:
            if rng.random() < 0.25:
                x += 5.0
                continue
            if bottles:
                h = rng.uniform(4, 8)
                prims.append(cylinder((x, y + 0.6, rng.uniform(-2, 2)), (x, y + 0.6 + h, 0.0), rng.uniform(1.4, 2.2),
                                      mat(rng.choice(["bottle", "amber", "gauze"]), 1.0)))
                x += rng.uniform(4.5, 6.5)
            else:
                w, h = rng.uniform(4, 8), rng.uniform(6, 13)
                prims.append(box((x + w / 2, y + 0.6 + h / 2, 0.0), (w / 2, h / 2, 4.5), mat("cardboard", rng.uniform(0.8, 1.1))))
                x += w + rng.uniform(0.5, 2.0)
    return prims


# --- botiquín y encimera ------------------------------------------------------------------------------

def med_cabinet(open_: bool) -> list:
    prims = [box((0.0, 42.0, -6.0), (12.0, 12.0, 4.0), mat("ceramic", 0.9))]
    prims.append(box((0.0, 42.0, -1.9), (10.5, 10.5, 0.1), mat("void")))
    rng = random.Random(4)
    for y in (35.0, 43.0, 50.0):
        prims.append(box((0.0, y - 1.0, -4.5), (10.0, 0.3, 2.5), mat("metal", 1.0)))
        for i in range(4):
            prims.append(cylinder((-8 + i * 5.0 + rng.uniform(-1, 1), y - 0.7, -4.5), (-8 + i * 5.0, y + 3.5, -4.5), 1.3,
                                  mat(rng.choice(["amber", "bottle", "gauze"]))))
    if open_:
        prims.append(box((-14.0, 42.0, 4.5), (0.4, 10.5, 9.0), mat("bag", 0.9), basis=basis_rot(ry=0.0)))
    else:
        prims.append(box((0.0, 42.0, -1.6), (10.5, 10.5, 0.3), mat("bag", 0.85)))
        prims.append(box((8.0, 42.0, -1.2), (0.6, 2.0, 0.4), metal_worn))
    prims.append(box((0.0, 56.0, -6.0), (1.5, 1.5, 0.2), mat("!red_lens", 0.4)))  # cruz
    return prims


def counter(open_: bool) -> list:
    prims = [box((0.0, 13.0, -2.0), (30.0, 13.0, 10.0), locker_mat)]
    prims.append(box((0.0, 26.6, -2.0), (31.0, 0.8, 11.0), mat("ceramic", 1.0)))
    for x in (-15.0, 0.0, 15.0):
        prims.append(box((x, 13.0, 8.1), (7.0, 11.0, 0.15), mat("void") if open_ and x == 0.0 else locker_mat))
        prims.append(box((x + 5.0, 18.0, 8.4), (0.5, 2.0, 0.4), metal_worn))
    rng = random.Random(12)
    for _ in range(5):
        prims.append(cylinder((rng.uniform(-26, 26), 27.4, rng.uniform(-8, 4)), (rng.uniform(-26, 26), 27.4, -2.0),
                              0.25, mat("metal", 1.2)))
    prims.append(cylinder((-20.0, 27.4, -4.0), (-20.0, 33.0, -4.0), 2.0, mat("amber")))
    return prims


# --- quirófano -----------------------------------------------------------------------------------------

def op_table() -> list:
    prims = [cylinder((0.0, 0.0, 0.0), (0.0, 20.0, 0.0), 3.0, metal_worn)]
    prims.append(box((0.0, 1.0, 0.0), (9.0, 1.0, 14.0), metal_worn))
    prims.append(box((0.0, 22.5, 0.0), (10.0, 2.0, 30.0), mat("mattress", 0.9)))
    for z in (-12.0, 4.0, 20.0):
        prims.append(box((0.0, 24.8, z), (10.6, 0.4, 1.4), mat("leather")))
        prims.append(box((10.6, 22.0, z), (0.3, 3.0, 1.4), mat("leather")))
    prims.append(box((0.0, 24.6, 2.0), (6.0, 0.1, 9.0), make_sheet((0.0, 24.6, 3.0), 6.0)))
    prims.append(capsule((-12.0, 23.0, -16.0), (-20.0, 24.0, -16.0), 1.0, metal_worn))  # apoyabrazos
    return prims


def op_lamp(on: bool) -> list:
    prims = [cylinder((0.0, 0.0, 0.0), (0.0, 1.5, 0.0), 7.0, metal_worn)]
    prims.append(cylinder((0.0, 1.5, 0.0), (0.0, 62.0, 0.0), 1.2, metal_worn))
    prims.append(capsule((0.0, 62.0, 0.0), (8.0, 60.0, 10.0), 1.0, metal_worn))
    prims.append(ellipsoid((10.0, 56.0, 13.0), (11.0, 4.0, 11.0), mat("ceramic", 1.0)))
    for i in range(7):
        ang = i / 7 * math.tau
        c = (10.0 + math.cos(ang) * 5.5, 52.5, 13.0 + math.sin(ang) * 5.5)
        prims.append(sphere(c, 1.8, mat("!lamp_warm", 0.9) if on else mat("glass", 0.6)))
    prims.append(sphere((10.0, 52.3, 13.0), 2.0, mat("!lamp_warm", 1.0) if on else mat("glass", 0.5)))
    return prims


def covered_body(on_gurney: bool, gone: bool) -> list:
    """Bulto bajo una sábana (frame del cadáver) o la sábana caída sin nadie debajo."""
    prims = []
    if not gone:
        sheet = make_sheet((0.0, 30.0, 4.0), 4.5, folds=0.35)
        prims.append(ellipsoid((0.0, 31.5, -22.0), (5.2, 4.2, 5.0), sheet))  # cabeza
        prims.append(ellipsoid((0.0, 31.0, -6.0), (9.5, 3.8, 11.0), sheet))  # torso
        prims.append(ellipsoid((0.0, 30.0, 14.0), (8.0, 2.8, 13.0), sheet))  # piernas
        prims.append(ellipsoid((-3.0, 31.0, 26.0), (2.0, 3.0, 2.0), sheet))  # pies
        prims.append(ellipsoid((3.0, 31.0, 26.0), (2.0, 3.0, 2.0), sheet))
        prims.append(box((0.0, 28.0, 0.0), (12.5, 0.6, 29.0), sheet))
        prims.append(box((12.8, 22.0, 2.0), (0.4, 6.5, 20.0), sheet))  # cae por el lado
        prims.append(box((-6.0, 31.0, 28.0), (1.2, 0.2, 0.8), mat("gauze", 1.2)))  # etiqueta del pie
    else:
        sheet = make_sheet((0.0, 28.0, -4.0), 6.0, folds=0.5)
        prims.append(box((0.0, 27.8, 4.0), (11.5, 0.5, 20.0), sheet))
        prims.append(box((13.0, 18.0, 6.0), (0.4, 10.0, 16.0), sheet))
        prims.append(box((0.0, 1.0, 38.0), (8.0, 0.8, 6.0), sheet, basis=basis_rot(ry=0.4)))  # en el suelo
    return prims


# --- morgue ------------------------------------------------------------------------------------------------

def morgue(state: int) -> list:
    """0 cerrada, 1 cajón abierto con un pie y su etiqueta, 2 cajón abierto vacío."""
    prims = [box((0.0, 24.0, -6.0), (30.0, 24.0, 8.0), mat("metal", 0.9))]
    for row, y in enumerate((12.0, 34.0)):
        for col, x in enumerate((-19.0, 0.0, 19.0)):
            prims.append(box((x, y, 2.1), (8.5, 8.5, 0.2), metal_worn))
            prims.append(box((x + 6.0, y, 2.6), (0.8, 2.5, 0.5), mat("metal", 1.2)))
            prims.append(box((x - 4.0, y + 5.5, 2.4), (3.0, 1.0, 0.1), mat("gauze", 1.0)))
    if state > 0:
        prims.append(box((0.0, 12.0, 2.3), (8.0, 8.0, 0.1), mat("void")))
        prims.append(box((0.0, 8.0, 14.0), (8.0, 1.0, 12.0), metal_worn))
        prims.append(box((0.0, 9.2, 14.0), (7.0, 0.4, 11.0), make_sheet(folds=0.2)))
        if state == 1:
            prims.append(ellipsoid((-2.0, 11.0, 24.0), (2.0, 3.0, 2.6), human.skin_mat))
            prims.append(box((-2.0, 13.5, 26.0), (1.5, 0.15, 1.0), mat("gauze", 1.3)))
    return prims


# --- sótano ------------------------------------------------------------------------------------------------

def elec_panel(state: int) -> list:
    """0 cerrado, 1 abierto averiado (cables sueltos, sin fusible), 2 reparado sin fusible, 3 completo."""
    prims = [box((0.0, 36.0, -8.0), (13.0, 16.0, 3.0), mat("locker", 0.8))]
    if state == 0:
        prims.append(box((0.0, 36.0, -4.8), (12.5, 15.5, 0.2), locker_mat))
        prims.append(box((0.0, 44.0, -4.4), (3.0, 1.5, 0.2), mat("plastic_yellow", 1.0)))  # aviso
        return prims
    prims.append(box((0.0, 36.0, -4.9), (11.5, 14.5, 0.1), mat("void")))
    prims.append(box((-15.0, 36.0, 4.0), (0.4, 15.5, 9.0), locker_mat))  # puerta abierta
    for i in range(6):
        prims.append(box((-8.0 + i * 3.2, 45.0, -4.5), (1.0, 2.5, 0.6), mat("plastic", 1.2)))
    prims.append(box((6.0, 33.0, -4.3), (2.0, 4.5, 0.6), mat("bakelite", 1.0)))  # zócalo del fusible
    if state == 3:
        prims.append(cylinder((6.0, 30.0, -3.6), (6.0, 36.0, -3.6), 1.2, mat("ceramic", 1.1)))
    if state == 1:
        for i, (x, z) in enumerate(((-6.0, 2.0), (-2.0, 4.0), (1.0, 3.0))):
            prims.append(capsule((-6.0 + i * 3, 30.0, -4.0), (x, 22.0, z), 0.45, mat(["led_red", "metal", "bakelite"][i], 0.6)))
    else:
        for i in range(3):
            prims.append(capsule((-6.0 + i * 3, 30.0, -4.0), (-6.0 + i * 3, 24.0, -4.0), 0.45, mat("bakelite", 0.9)))
    prims.append(box((-6.0, 26.0, -4.3), (4.0, 1.0, 0.4), metal_worn))
    return prims


def generator(on: bool) -> list:
    prims = [box((0.0, 2.0, 0.0), (28.0, 2.0, 16.0), metal_worn)]
    prims.append(box((-4.0, 16.0, 0.0), (18.0, 12.0, 12.0), mat("plastic_yellow", 0.7)))
    prims.append(cylinder((18.0, 16.0, -6.0), (18.0, 16.0, 6.0), 9.0, metal_worn))
    prims.append(cylinder((-24.0, 6.0, 0.0), (-24.0, 36.0, 0.0), 2.5, metal_worn))  # escape
    prims.append(capsule((-24.0, 36.0, 0.0), (-24.0, 40.0, -10.0), 2.5, metal_worn))
    prims.append(box((-4.0, 29.0, 4.0), (6.0, 1.2, 4.0), mat("plastic", 1.0)))
    prims.append(sphere((-8.0, 30.5, 8.0), 1.2, mat("!led_green", 0.9) if on else mat("led_red", 0.4)))
    prims.append(cylinder((8.0, 22.0, 12.0), (8.0, 22.0, 14.0), 3.0, mat("void")))  # asiento de la válvula
    return prims


def boiler() -> list:
    prims = [cylinder((0.0, 0.0, 0.0), (0.0, 56.0, 0.0), 11.0, metal_worn)]
    prims.append(sphere((0.0, 56.0, 0.0), 11.0, metal_worn))
    for y in (14.0, 30.0, 46.0):
        prims.append(cylinder((0.0, y, 0.0), (0.0, y + 1.0, 0.0), 11.6, mat("rust", 1.0)))
    prims.append(capsule((11.0, 40.0, 0.0), (16.0, 40.0, 0.0), 1.6, metal_worn))
    prims.append(cylinder((0.0, 30.0, 11.0), (0.0, 30.0, 12.0), 3.0, mat("ceramic", 1.0)))  # manómetro
    return prims


def crates() -> list:
    prims = [box((0.0, 8.0, 0.0), (11.0, 8.0, 10.0), mat("cardboard", 0.9))]
    prims.append(box((2.0, 22.0, -1.0), (9.0, 6.0, 8.0), mat("cardboard", 1.0), basis=basis_rot(ry=0.2)))
    prims.append(box((0.0, 16.05, 0.0), (11.0, 0.05, 1.0), mat("plastic_yellow", 1.0)))
    return prims


def tape_recorder() -> list:
    prims = [box((0.0, 10.0, 0.0), (10.0, 10.0, 8.0), wood_mat)]
    prims.append(box((0.0, 22.0, 0.0), (9.0, 2.0, 6.0), mat("plastic", 1.1)))
    for x in (-4.0, 4.0):
        prims.append(cylinder((x, 24.0, -1.0), (x, 24.6, -1.0), 2.6, mat("bakelite", 1.2)))
        prims.append(cylinder((x, 24.6, -1.0), (x, 24.8, -1.0), 0.8, metal_worn))
    prims.append(sphere((7.0, 23.5, 5.0), 0.8, mat("!led_red", 0.9)))
    prims.append(capsule((-9.0, 22.0, 4.0), (-12.0, 30.0, 8.0), 0.4, mat("bakelite")))  # cable del micro
    prims.append(sphere((-12.0, 30.5, 8.0), 1.6, metal_worn))
    return prims


def wall_lamp(on: bool) -> list:
    prims = [box((0.0, 0.0, 0.0), (8.0, 2.0, 2.0), metal_worn)]
    prims.append(box((0.0, -2.2, 1.0), (7.0, 1.0, 1.5), mat("!lamp_warm", 0.85) if on else mat("gauze", 0.5)))
    return prims


def laundry_cart() -> list:
    prims = []
    for x in (-10.0, 10.0):
        for z in (-8.0, 8.0):
            prims.append(capsule((x, 2.0, z), (x, 24.0, z), 0.6, metal_worn))
            prims.append(sphere((x, 1.0, z), 1.0, mat("rubber")))
    prims.append(box((0.0, 14.0, 0.0), (10.0, 10.0, 8.0), mat("canvas", 0.9)))
    rng = random.Random(14)
    for _ in range(5):
        prims.append(ellipsoid((rng.uniform(-6, 6), 25.0, rng.uniform(-5, 5)), (4.0, 2.0, 4.0),
                               make_sheet((0.0, 25.0, 0.0), 3.0 if rng.random() < 0.4 else 0.0, 0.4)))
    return prims


def mop_bucket() -> list:
    prims = [cylinder((0.0, 0.0, 0.0), (0.0, 10.0, 0.0), 6.0, mat("plastic_yellow", 0.9))]
    prims.append(cylinder((0.0, 9.6, 0.0), (0.0, 10.0, 0.0), 5.2, mat("blood_dry", 0.8)))
    prims.append(capsule((2.0, 8.0, 0.0), (6.0, 38.0, -4.0), 0.7, wood_mat))
    return prims


def stretcher_extra() -> list:
    """Fotogramas 5 y 6 de la camilla: cadáver tapado y sábana sin nadie."""
    from props import _stretcher_base
    return [_stretcher_base(make_sheet(), "open") + covered_body(True, False),
            _stretcher_base(make_sheet((0.0, 27.0, 2.0), 6.0), "open") + covered_body(True, True)]
