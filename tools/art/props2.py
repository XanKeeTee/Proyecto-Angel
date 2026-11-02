"""Mobiliario y máquinas del prólogo (vista oblicua de mapa). Los muebles con cajones y las máquinas
se rehicieron con más detalle en props3.py; aquí quedan ordenador, teléfono, quirófano, aplique y cubo."""

from __future__ import annotations

import math

import human  # noqa: F401  (rampas de piel y ropa)
import tiles_extra  # noqa: F401  (rampa "wood")
from props import make_sheet, mat, metal_worn
from pxrender import Vec, basis_rot, box, capsule, cylinder, ellipsoid, fbm, mul, ramp, sphere

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


# --- habitación ----------------------------------------------------------------------------


# --- escritorio, ordenador, teléfono ----------------------------------------------------------


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


# --- botiquín y encimera ------------------------------------------------------------------------------


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


# --- sótano ------------------------------------------------------------------------------------------------


def wall_lamp(on: bool) -> list:
    prims = [box((0.0, 0.0, 0.0), (8.0, 2.0, 2.0), metal_worn)]
    prims.append(box((0.0, -2.2, 1.0), (7.0, 1.0, 1.5), mat("!lamp_warm", 0.85) if on else mat("gauze", 0.5)))
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
