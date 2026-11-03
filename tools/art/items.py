"""Objetos de la custodia: icono para la bandeja y 8 vistas para el inspector.

- El icono mide `size x 36 - 4` píxeles (ItemDef.ICON_CELL; la forma del objeto: la custodia ya no
  tiene casillas) y el modelo se encuadra solo para llenarlo. Las listas lo reducen (ItemThumbs).
- Los modelos tienen detalle a escala real: moleteado, roscas, etiquetas con líneas
  de texto, graduaciones, tornillería, dientes de llave… y brillo especular en metal,
  cristal y plástico.
- La ropa se dibuja con el mismo modelo que lleva puesto el personaje (tools/art/human.py).
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

import human  # noqa: E402
import props  # noqa: F401  (rampas)
import props2  # noqa: F401  (rampas)
from pxrender import (View, Vec, add, basis_rot, box, capsule, cylinder, ellipsoid, fbm, mul, norm, ramp, render,
                      scale_prims, sphere)

ramp("brass", [(54, 40, 14), (96, 74, 28), (140, 112, 48), (186, 156, 80), (220, 196, 120), (244, 230, 170)])
ramp("copper", [(60, 30, 14), (110, 60, 30), (160, 100, 54), (200, 150, 96), (232, 196, 150)])
ramp("iodine", [(70, 40, 14), (112, 70, 26), (150, 104, 48), (184, 140, 80), (210, 172, 112)])
ramp("red_paint", [(40, 8, 8), (80, 18, 16), (120, 32, 28), (160, 54, 46), (196, 88, 72)])
ramp("steel", [(18, 20, 24), (34, 38, 42), (54, 58, 62), (78, 82, 86), (108, 112, 114), (146, 150, 150), (196, 198, 194),
               (238, 238, 232)])
ramp("castiron", [(14, 14, 16), (26, 26, 28), (40, 40, 42), (58, 58, 58), (82, 82, 80), (114, 112, 108), (156, 154, 148)])
ramp("paint_green", [(12, 22, 16), (20, 36, 26), (32, 54, 38), (46, 74, 54), (66, 96, 72), (92, 122, 96)])
ramp("rubber_k", [(8, 8, 10), (16, 16, 18), (26, 26, 30), (38, 38, 42), (56, 56, 60), (86, 86, 90)])
ramp("glass_lens", [(54, 60, 64), (96, 106, 108), (150, 160, 156), (208, 212, 200), (250, 250, 238)])
ramp("label", [(84, 80, 70), (122, 116, 100), (160, 154, 134), (194, 188, 166), (222, 218, 198)])
ramp("ink", [(18, 18, 22), (32, 32, 40), (50, 50, 60)])
ramp("red_cross", [(70, 14, 14), (120, 26, 24), (170, 44, 38), (204, 74, 62)])
ramp("battery_k", [(10, 12, 18), (18, 22, 30), (28, 34, 46), (42, 50, 64), (62, 72, 88), (100, 110, 124)])
ramp("amber_glass", [(36, 16, 6), (66, 30, 10), (104, 52, 16), (146, 80, 28), (190, 122, 52), (232, 184, 110)])
ramp("white_plastic", [(64, 64, 64), (104, 102, 98), (144, 142, 136), (180, 178, 170), (210, 208, 200), (236, 234, 226)])
ramp("clear_plastic", [(58, 68, 72), (92, 104, 108), (130, 140, 142), (170, 178, 178), (210, 216, 214), (240, 244, 240)])
ramp("yellow_plastic", [(58, 42, 6), (100, 76, 12), (146, 114, 22), (190, 154, 42), (224, 190, 80), (246, 224, 140)])
ramp("gauze_hi", [(60, 56, 50), (92, 86, 76), (126, 120, 106), (158, 152, 136), (188, 182, 164), (214, 208, 190)])
ramp("gauze_dirty", [(46, 38, 28), (72, 60, 44), (100, 86, 64), (128, 112, 86), (152, 136, 106)])
ramp("tag_yellow", [(70, 54, 8), (120, 94, 16), (170, 136, 30), (210, 176, 60), (236, 210, 110)])
ramp("cord", [(26, 22, 18), (44, 38, 30), (68, 58, 44), (94, 82, 62)])
# Propias de los objetos de tela y de las armas improvisadas (no dependen de otros generadores).
ramp("strip_cloth", [(44, 46, 50), (70, 72, 74), (98, 100, 98), (128, 128, 122), (158, 156, 146), (188, 184, 170),
                     (212, 208, 192)])
ramp("strip_stain", [(40, 32, 22), (64, 54, 36), (90, 78, 52), (116, 102, 70)])
ramp("strip_blood", [(30, 8, 10), (52, 14, 16), (78, 22, 24), (104, 36, 34)])
ramp("handle_wood", [(26, 14, 8), (44, 26, 14), (66, 42, 24), (90, 60, 36), (116, 82, 50), (140, 104, 66)])
ramp("pipe_rust", [(26, 14, 10), (46, 26, 16), (70, 40, 24), (96, 58, 34), (124, 80, 46)])

CELL = 36  # medida de referencia de los iconos (ItemDef.ICON_CELL); ya no hay casillas en la custodia
ICON_VIEW = View(b=0.85, ambient=0.42, light=(-0.45, 0.8, 0.5), dither=0.4, ss=4)
INSPECT_VIEW = View(b=0.6, ambient=0.4, light=(-0.45, 0.8, 0.5), dither=0.35, ss=3)
INSPECT_SIZE = 112


def _frac(x: float) -> float:
    return x - math.floor(x)


def m(name: str, bright: float = 1.0, spec: float = 0.0, var: float = 0.12, seed: int = 0, scale: float = 0.8):
    """Material liso con algo de variación de tono y brillo especular opcional."""
    def f(p: Vec, n: Vec) -> tuple:
        return (name, bright * (1.0 - var / 2 + var * fbm(mul(p, scale), seed)), None, spec)
    return f


def worn_paint(paint: str, bare: str = "steel", seed: int = 5, wear: float = 0.64):
    """Pintura desconchada: por debajo asoma el metal (que brilla)."""
    def f(p: Vec, n: Vec) -> tuple:
        if fbm(mul(p, 0.55), seed) > wear:
            return (bare, 0.95 + 0.15 * fbm(mul(p, 2.0), seed + 1), None, 0.7)
        return (paint, 0.92 + 0.12 * fbm(mul(p, 1.1), seed + 2), None, 0.18)
    return f


def _axis_angle(p: Vec, axis: str) -> float:
    if axis == "z":
        return math.atan2(p[1] - 3.0, p[0])
    if axis == "y":
        return math.atan2(p[2], p[0])
    return math.atan2(p[1], p[2])


# --- linterna ------------------------------------------------------------------------------

def _knurl(p: Vec, n: Vec) -> tuple:
    a = _axis_angle(p, "z")
    d1 = math.sin(a * 14 + p[2] * 2.2)
    d2 = math.sin(a * 14 - p[2] * 2.2)
    n2 = norm(add(n, (0.0, 0.0, 0.32 * (d1 + d2))))
    # Número grabado a mano en el mango: «09».
    if n[1] > 0.55 and -9.5 < p[2] < -4.0 and abs(p[0]) < 1.1:
        z = p[2]
        if (-9.5 < z < -8.6 or -7.0 < z < -6.2) or (abs(p[0]) > 0.75 and -9.5 < z < -6.2) or \
                (-5.4 < z < -4.0 and abs(p[0]) > 0.75) or (abs(z + 4.6) < 0.3) or (abs(z + 5.4) < 0.3 and p[0] > 0):
            return ("ink", 1.0, n2)
    return worn_paint("paint_green", seed=11, wear=0.6)(p, n2)


def _lens(p: Vec, n: Vec) -> tuple:
    r = math.hypot(p[0], p[1] - 3.0)
    ring = _frac(r / 0.9)
    return ("glass_lens", 0.75 + 0.3 * ring + (0.35 if r < 1.0 else 0.0), None, 1.4)


def flashlight() -> list:
    P = []
    P.append(cylinder((0.0, 3.0, -17.2), (0.0, 3.0, -15.0), 3.15, m("steel", 0.85, 0.6, seed=3)))
    for i in range(12):  # anilla del cordón
        a = i / 12 * math.tau
        P.append(sphere((0.0, 3.0 + 1.5 * math.cos(a), -18.9 + 1.5 * math.sin(a)), 0.38, m("steel", 0.9, 0.8)))
    P.append(cylinder((0.0, 3.0, -15.0), (0.0, 3.0, 3.5), 3.0, _knurl))
    for z in (-15.0, 3.5):
        P.append(cylinder((0.0, 3.0, z - 0.35), (0.0, 3.0, z + 0.35), 3.12, m("steel", 0.8, 0.5)))
    P.append(box((0.0, 6.0, 0.4), (1.25, 0.5, 1.9), m("rubber_k", 1.0, 0.15)))  # interruptor
    P.append(ellipsoid((0.0, 6.55, 0.4), (0.8, 0.45, 1.2), m("rubber_k", 1.2, 0.3)))
    for k in range(6):  # cuello cónico
        t = k / 5
        z = 3.5 + t * 4.5
        P.append(cylinder((0.0, 3.0, z), (0.0, 3.0, z + 0.95), 3.0 + 1.5 * t, worn_paint("paint_green", seed=12)))
    P.append(cylinder((0.0, 3.0, 8.4), (0.0, 3.0, 14.0), 4.5, worn_paint("paint_green", seed=13)))
    for i in range(18):  # estrías de la cabeza
        a = i / 18 * math.tau
        P.append(box((math.cos(a) * 4.5, 3.0 + math.sin(a) * 4.5, 11.2), (0.35, 0.35, 2.6), m("paint_green", 0.75),
                     basis=basis_rot(rz=a)))
    P.append(cylinder((0.0, 3.0, 14.0), (0.0, 3.0, 15.3), 4.75, m("steel", 1.0, 1.0, seed=4)))
    P.append(cylinder((0.0, 3.0, 15.3), (0.0, 3.0, 15.45), 3.95, _lens))
    return P


# --- pilas ----------------------------------------------------------------------------------

def _battery_mat(p: Vec, n: Vec) -> tuple:
    z = p[2]
    if z > 4.6:
        return ("brass", 1.0, None, 0.8)  # franja del positivo
    if z < -6.6:
        return ("steel", 0.95, None, 0.9)
    a = math.degrees(_axis_angle((p[0] - (3.0 if p[0] > 0 else -3.0), p[1], z), "z")) % 360
    if 40 < a < 140 and -3.5 < z < 3.5 and _frac(z / 1.1) < 0.35 and abs(a - 90) < 35:
        return ("label", 0.85)  # texto impreso
    if 60 < a < 120 and abs(z + 4.8) < 0.7:
        return ("red_paint", 1.0)
    return ("battery_k", 0.95 + 0.1 * fbm(mul(p, 1.5), 21), None, 0.6)


def batteries() -> list:
    P = []
    for x in (-3.0, 3.0):
        P.append(cylinder((x, 2.6, -7.0), (x, 2.6, 7.0), 2.6, _battery_mat))
        P.append(cylinder((x, 2.6, 7.0), (x, 2.6, 7.9), 1.0, m("steel", 1.0, 1.0)))
        P.append(cylinder((x, 2.6, -7.3), (x, 2.6, -7.0), 2.0, m("steel", 0.8, 0.8)))
    return P


# --- vendas ------------------------------------------------------------------------------

def gauze(ramp_name: str, stains: str = ""):
    def f(p: Vec, n: Vec) -> tuple:
        x, y, z = p
        if abs(n[0]) > 0.7:  # cara del rollo: capas en espiral
            r = math.hypot(y - 5.0, z)
            if _frac(r / 0.62 + math.atan2(y - 5.0, z) / math.tau) < 0.28:
                return (ramp_name, 0.72)
        weave = 0.88 + 0.12 * ((int(x * 2.4) + int(_axis_angle((x, y - 5.0, z), "x") * 9)) % 2)
        if stains == "blood" and fbm(mul(p, 0.45), 301) > 0.56:
            return ("blood_dry", 0.95 + 0.15 * fbm(mul(p, 1.4), 302))
        if stains == "blood" and fbm(mul(p, 0.3), 303) > 0.62:
            return ("stain", 0.9)
        return (ramp_name, weave * (0.92 + 0.12 * fbm(mul(p, 0.9), 304)))
    return f


def bandage(material) -> list:
    P = [cylinder((-5.5, 5.0, 0.0), (5.5, 5.0, 0.0), 5.0, material),
         cylinder((-5.6, 5.0, 0.0), (5.6, 5.0, 0.0), 1.5, m("void"))]
    # Cola suelta que cae hacia delante, algo arrugada.
    for i in range(5):
        P.append(box((0.4 * math.sin(i * 1.3), 0.35, 4.5 + i * 2.0), (4.6, 0.25, 1.05), material,
                     basis=basis_rot(ry=0.05 * math.sin(i * 2.0), rx=0.08 * math.cos(i * 1.7))))
    P.append(box((0.0, 9.85, -1.5), (1.4, 0.3, 1.0), m("steel", 1.0, 0.9)))  # grapa
    return P


# --- frascos y medicación -------------------------------------------------------------------

def _label_lines(p: Vec, top: float, bottom: float, width: float, ink_seed: int) -> bool:
    """Líneas de texto de una etiqueta, en la cara que mira al espectador."""
    y = p[1]
    if not (bottom < y < top):
        return False
    row = (top - y) / 1.15
    if _frac(row) > 0.45:
        return False
    length = width * (0.5 + 0.5 * fbm((math.floor(row) * 3.1, 0.0, ink_seed), ink_seed))
    return -width < p[0] < -width + 2 * length and fbm((p[0] * 1.6, math.floor(row), 0.0), ink_seed + 1) > 0.3


def disinfectant_mat(p: Vec, n: Vec) -> tuple:
    x, y, z = p
    if 2.5 < y < 10.5 and n[2] > -0.2:
        if n[2] > 0.35:
            if (abs(x) < 0.55 and 7.2 < y < 9.8) or (abs(y - 8.5) < 0.55 and abs(x) < 1.35):
                return ("red_cross", 1.0)
            if _label_lines(p, 6.6, 3.0, 3.4, 61):
                return ("ink", 1.0)
        return ("label", 0.95 + 0.1 * fbm(mul(p, 1.2), 62))
    return ("white_plastic", 0.92 + 0.1 * fbm(mul(p, 0.6), 63), None, 0.5)


def ribbed(name: str, count: int, spec: float = 0.4):
    def f(p: Vec, n: Vec) -> tuple:
        a = math.atan2(p[2], p[0])
        rib = math.sin(a * count)
        n2 = norm((n[0] - math.sin(a) * rib * 0.35, n[1], n[2] + math.cos(a) * rib * 0.35))
        return (name, 0.95 + 0.08 * rib, n2, spec)
    return f


def disinfectant() -> list:
    P = [cylinder((0.0, 0.0, 0.0), (0.0, 11.5, 0.0), 5.0, disinfectant_mat)]
    P.append(ellipsoid((0.0, 11.5, 0.0), (5.0, 2.6, 5.0), m("white_plastic", 1.0, 0.5)))
    P.append(cylinder((0.0, 13.0, 0.0), (0.0, 15.2, 0.0), 2.1, m("white_plastic", 0.95, 0.4)))
    P.append(cylinder((0.0, 15.2, 0.0), (0.0, 17.6, 0.0), 2.7, ribbed("red_paint", 16, 0.3)))
    P.append(cylinder((0.0, 17.6, 0.0), (0.0, 19.6, 0.0), 0.9, m("red_paint", 1.1, 0.3)))
    P.append(box((0.0, 18.0, 1.8), (0.9, 0.5, 1.4), m("red_paint", 0.9)))  # tapón abatible
    return P


def pill_bottle_mat(p: Vec, n: Vec) -> tuple:
    x, y, z = p
    if 2.0 < y < 8.5 and n[2] > -0.1:
        if n[2] > 0.3 and _label_lines(p, 7.6, 3.0, 2.8, 71):
            return ("ink", 1.0)
        if n[2] > 0.3 and abs(y - 8.0) < 0.35:
            return ("red_paint", 1.0)
        return ("label", 0.95 + 0.1 * fbm(mul(p, 1.3), 72))
    return ("amber_glass", 0.85 + 0.15 * fbm(mul(p, 0.8), 73), None, 1.1)


def pills() -> list:
    P = [cylinder((0.0, 0.0, 0.0), (0.0, 9.6, 0.0), 4.0, pill_bottle_mat)]
    P.append(ellipsoid((0.0, 9.6, 0.0), (4.0, 1.4, 4.0), m("amber_glass", 0.9, 1.1)))
    P.append(cylinder((0.0, 10.2, 0.0), (0.0, 13.2, 0.0), 4.25, ribbed("white_plastic", 22, 0.35)))
    P.append(cylinder((0.0, 13.2, 0.0), (0.0, 13.5, 0.0), 3.9, m("white_plastic", 1.1, 0.3)))
    for x, z, a in ((6.6, 3.0, 0.4), (5.2, 6.4, -0.9)):  # comprimidos sueltos
        d = (math.sin(a) * 1.1, 0.0, math.cos(a) * 1.1)
        P.append(capsule(add((x, 0.85, z), mul(d, -1)), add((x, 0.85, z), d), 0.85, m("white_plastic", 1.15, 0.4)))
    return P


def syringe_mat(p: Vec, n: Vec) -> tuple:
    z = p[2]
    if n[1] > 0.4 and -6.0 < z < 5.0:
        k = _frac((z + 6.0) / 1.1)
        if k < 0.14 and abs(p[0]) < (1.0 if int((z + 6.0) / 1.1) % 5 == 0 else 0.55):
            return ("ink", 1.0)
    return ("clear_plastic", 0.9 + 0.1 * fbm(mul(p, 0.7), 81), None, 1.2)


def syringe(filled: bool) -> list:
    P = [cylinder((0.0, 2.0, -8.0), (0.0, 2.0, 6.0), 1.8, syringe_mat)]
    if filled:
        P.append(cylinder((0.0, 2.0, -0.6), (0.0, 2.0, 5.6), 1.83, m("amber_glass", 1.05, 0.9)))
    P.append(cylinder((0.0, 2.0, -1.4), (0.0, 2.0, -0.6), 1.86, m("rubber_k", 1.0, 0.4)))  # émbolo
    P.append(box((0.0, 2.0, -11.0), (0.25, 1.2, 3.0), m("white_plastic", 0.95)))  # vástago en cruz
    P.append(box((0.0, 2.0, -11.0), (1.2, 0.25, 3.0), m("white_plastic", 0.95)))
    P.append(cylinder((0.0, 2.0, -14.4), (0.0, 2.0, -13.9), 2.3, m("white_plastic", 1.05, 0.3)))
    P.append(box((0.0, 2.0, -8.2), (3.6, 0.45, 0.45), m("clear_plastic", 1.0, 0.8)))  # aletas
    for k in range(4):  # cono hacia la aguja
        P.append(cylinder((0.0, 2.0, 6.0 + k * 0.45), (0.0, 2.0, 6.45 + k * 0.45), 1.6 - k * 0.32, m("clear_plastic", 1.0, 1.0)))
    P.append(cylinder((0.0, 2.0, 7.8), (0.0, 2.0, 8.6), 0.7, m("tag_yellow", 1.0, 0.3)))  # cono de color
    P.append(capsule((0.0, 2.0, 8.6), (0.0, 2.0, 15.5), 0.2, m("steel", 1.2, 1.6)))
    return P


def ampoule_mat(p: Vec, n: Vec) -> tuple:
    y = p[1]
    if y < 6.2:
        if 1.8 < y < 5.0 and n[2] > 0.2:
            if _label_lines(p, 4.6, 2.0, 1.9, 91):
                return ("ink", 1.0)
            return ("label", 1.0)
        return ("amber_glass", 0.9 + 0.12 * fbm(mul(p, 1.0), 92), None, 1.4)
    return ("clear_plastic", 0.95, None, 1.5)


def ampoule() -> list:
    P = [sphere((0.0, 1.6, 0.0), 2.3, ampoule_mat),
         cylinder((0.0, 1.6, 0.0), (0.0, 7.6, 0.0), 2.3, ampoule_mat),
         ellipsoid((0.0, 7.6, 0.0), (2.3, 1.6, 2.3), ampoule_mat),
         cylinder((0.0, 8.6, 0.0), (0.0, 10.2, 0.0), 0.85, ampoule_mat),
         cylinder((0.0, 9.1, 0.0), (0.0, 9.6, 0.0), 0.95, m("red_paint", 1.1, 0.5)),  # anilla de rotura
         sphere((0.0, 11.4, 0.0), 1.45, ampoule_mat)]
    return P


# --- herramientas ------------------------------------------------------------------------------

def screwdriver_handle(p: Vec, n: Vec) -> tuple:
    a = math.atan2(p[1] - 3.5, p[0])
    flute = math.cos(a * 6)
    n2 = norm((n[0] + math.sin(a) * math.sin(a * 6) * 0.5, n[1] - math.cos(a) * math.sin(a * 6) * 0.5, n[2]))
    if flute < -0.55 and -17.5 < p[2] < -7.5:
        return ("rubber_k", 1.0, n2, 0.2)
    if fbm(mul(p, 0.5), 101) > 0.7:
        return ("stain", 0.8, n2)
    return ("yellow_plastic", 0.95 + 0.06 * flute, n2, 0.7)


def screwdriver() -> list:
    P = [cylinder((0.0, 3.5, -19.0), (0.0, 3.5, -5.5), 3.4, screwdriver_handle),
         ellipsoid((0.0, 3.5, -19.0), (3.4, 3.4, 1.6), m("yellow_plastic", 0.95, 0.6)),
         cylinder((0.0, 3.5, -5.5), (0.0, 3.5, -4.2), 2.6, m("yellow_plastic", 0.9, 0.6)),
         cylinder((0.0, 3.5, -4.2), (0.0, 3.5, -2.6), 1.6, m("steel", 1.0, 1.0)),
         cylinder((0.0, 3.5, -2.6), (0.0, 3.5, 16.5), 0.9, m("steel", 1.05, 1.4, var=0.05)),
         box((0.0, 3.5, 17.6), (1.3, 0.3, 1.2), m("steel", 1.1, 1.4))]
    return P


def _hex_facets(p: Vec, n: Vec, axis: tuple) -> Vec:
    """Normal facetada en hexágono alrededor del eje z (barra de hierro)."""
    a = math.atan2(n[1], n[0])
    a = round(a / (math.tau / 6)) * (math.tau / 6)
    return norm((math.cos(a), math.sin(a), n[2] * 0.3))


def crowbar_mat(p: Vec, n: Vec) -> tuple:
    n2 = _hex_facets(p, n, (0, 0, 1)) if -29 < p[2] < 23 else n
    if p[2] < -27 and fbm(mul(p, 0.5), 111) > 0.45:
        return ("blood_dry", 1.0, n2)
    if fbm(mul(p, 0.4), 112) > 0.62:
        return ("rust", 0.9 + 0.2 * fbm(mul(p, 1.8), 113), n2, 0.1)
    if fbm(mul(p, 0.3), 114) > 0.45:
        return ("red_paint", 0.9 + 0.1 * fbm(mul(p, 1.0), 115), n2, 0.25)
    return ("castiron", 0.95 + 0.15 * fbm(mul(p, 1.2), 116), n2, 0.8)


def crowbar() -> list:
    P = [capsule((0.0, 2.0, -28.0), (0.0, 2.0, 23.0), 1.9, crowbar_mat)]
    # Uña curva (se dobla hacia un lado para que se vea desde arriba) con la punta partida.
    arc = [(0.0, 2.0, 23.0), (1.6, 2.0, 27.0), (4.8, 2.0, 29.6), (8.4, 2.0, 29.4), (10.6, 2.0, 27.2)]
    for i in range(len(arc) - 1):
        r = 1.9 - i * 0.18
        P.append(capsule(arc[i], arc[i + 1], r, crowbar_mat))
    for y in (1.3, 2.7):
        P.append(capsule((10.6, y, 27.2), (11.2, y, 24.4), 0.7, crowbar_mat))
    P.append(ellipsoid((0.0, 1.6, -30.2), (1.9, 0.9, 2.6), crowbar_mat, basis=basis_rot(rx=0.25)))  # bisel
    return P


def fuse_mat(p: Vec, n: Vec) -> tuple:
    if n[1] > 0.3 and -6.0 < p[2] < 6.0:
        if abs(p[0]) < 3.0:
            if _frac((p[2] + 6) / 1.3) < 0.4 and abs(p[0]) < 2.4 * (0.4 + 0.6 * fbm((math.floor((p[2] + 6) / 1.3), 0, 0), 121)):
                return ("ink", 1.0)
            return ("label", 1.0)
    if n[1] > 0.5 and abs(p[2] - 8.0) < 1.0 and abs(p[0]) < 0.9:
        return ("red_paint", 1.2, None, 0.8)  # testigo
    return ("ceramic", 0.95 + 0.1 * fbm(mul(p, 1.4), 122), None, 0.3)


def fuse() -> list:
    P = [cylinder((0.0, 5.0, -11.0), (0.0, 5.0, 11.0), 4.6, fuse_mat)]
    for z0, z1 in ((-14.0, -11.0), (11.0, 14.0)):
        P.append(cylinder((0.0, 5.0, z0), (0.0, 5.0, z1), 5.1, m("brass", 1.0, 1.1)))
        for zz in (z0 + 0.6, z1 - 0.6):
            P.append(cylinder((0.0, 5.0, zz - 0.2), (0.0, 5.0, zz + 0.2), 5.25, m("brass", 0.85, 0.8)))
    for z in (-16.5, 16.5):  # cuchillas
        P.append(box((0.0, 5.0, z), (2.6, 0.5, 2.4), m("brass", 1.05, 1.2)))
    return P


def valve(repaired: bool) -> list:
    body = (lambda p, n: ("rust", 0.95, None, 0.1) if fbm(mul(p, 0.35), 131) > (0.7 if repaired else 0.55)
            else ("castiron", 0.9 + 0.2 * fbm(mul(p, 1.1), 132), None, 0.5))
    P = [ellipsoid((0.0, 5.5, 0.0), (7.2, 5.6, 6.2), body)]
    for side in (-1.0, 1.0):
        P.append(cylinder((side * 6.0, 5.0, 0.0), (side * 11.5, 5.0, 0.0), 3.4, body))
        P.append(cylinder((side * 11.5, 5.0, 0.0), (side * 12.8, 5.0, 0.0), 5.6, body))  # brida
        for k in range(4):
            a = k / 4 * math.tau + math.pi / 4
            pos = (side * 13.0, 5.0 + math.sin(a) * 4.2, math.cos(a) * 4.2)
            if repaired or k % 2 == 0:
                P.append(cylinder(pos, (side * 13.8, pos[1], pos[2]), 0.85, m("steel", 0.95, 1.0)))
            else:
                P.append(cylinder(pos, (side * 13.0 + side * 0.05, pos[1], pos[2]), 0.6, m("void")))
    P.append(cylinder((0.0, 9.5, 0.0), (0.0, 13.0, 0.0), 3.6, body))  # bonete
    P.append(cylinder((0.0, 13.0, 0.0), (0.0, 14.8, 0.0), 2.7, m("brass" if repaired else "castiron", 1.0, 0.9)))
    for k in range(6 if repaired else 3):
        a = k / 6 * math.tau
        P.append(cylinder((math.cos(a) * 4.6, 10.0, math.sin(a) * 4.6), (math.cos(a) * 4.6, 10.8, math.sin(a) * 4.6), 0.75,
                          m("steel", 1.0, 1.1)))
    P.append(cylinder((0.0, 14.8, 0.0), (0.0, 19.5, 0.0), 0.8, m("steel", 1.05, 1.3)))
    wheel = worn_paint("red_paint", seed=133, wear=0.7)
    for i in range(20):
        a = i / 20 * math.tau
        P.append(sphere((math.cos(a) * 6.4, 19.6, math.sin(a) * 6.4), 0.95, wheel))
    for i in range(5):
        a = i / 5 * math.tau
        P.append(capsule((0.0, 19.6, 0.0), (math.cos(a) * 6.2, 19.6, math.sin(a) * 6.2), 0.55, wheel))
    P.append(cylinder((0.0, 19.2, 0.0), (0.0, 20.2, 0.0), 1.5, m("steel", 0.9, 1.0)))
    if not repaired:  # grieta en el asiento
        P.append(box((2.0, 5.6, 6.0), (0.18, 3.2, 0.3), m("void"), basis=basis_rot(rz=0.4)))
    return P


# --- llaves ----------------------------------------------------------------------------------------

def key_model(tag: str, length: float = 16.0, metal: str = "brass") -> list:
    P = []
    shine = m(metal, 1.0, 1.1, seed=141)
    for i in range(16):  # cabeza (anilla con agujero)
        a = i / 16 * math.tau
        P.append(sphere((math.cos(a) * 3.6, 1.0, -length / 2 + math.sin(a) * 3.6), 1.15, shine))
    P.append(box((0.0, 1.0, -length / 2 + 4.6), (1.6, 0.75, 1.0), shine))  # tope
    blade_cut = lambda p, _l=length: p[0] > 0.6 and _frac((p[2] + _l) / 2.1) < 0.45 and p[2] > -_l / 2 + 6  # noqa: E731
    P.append(box((0.4, 1.0, 2.0), (1.6, 0.65, length / 2 - 1.0), shine, cut=blade_cut))
    P.append(box((-0.3, 1.66, 2.0), (0.25, 0.05, length / 2 - 1.6), m(metal, 0.6)))  # ranura
    P.append(ellipsoid((0.4, 1.0, length / 2 + 1.0), (1.6, 0.65, 1.0), shine))
    ring_c = (0.0, 1.0, -length / 2 - 5.2)
    for i in range(18):  # llavero
        a = i / 18 * math.tau
        P.append(sphere(add(ring_c, (math.cos(a) * 3.0, 0.0, math.sin(a) * 3.0)), 0.42, m("steel", 1.0, 1.2)))
    if tag == "plastic":
        def tag_mat(p: Vec, n: Vec) -> tuple:
            if n[1] > 0.5 and abs(p[0] + 8.2) < 1.6 and abs(p[2] + length / 2 + 8.5) < 1.4:
                return ("ink", 1.0)  # «10» escrito a rotulador
            if fbm(mul(p, 1.4), 142) > 0.72:
                return ("tag_yellow", 0.7)  # mordiscos
            return ("tag_yellow", 1.0, None, 0.5)
        P.append(box((-7.6, 1.0, -length / 2 - 8.5), (3.6, 0.6, 2.6), tag_mat, basis=basis_rot(ry=0.35)))
    elif tag == "label":
        def label_mat(p: Vec, n: Vec) -> tuple:
            if n[1] > 0.5 and _frac((p[2] + 40) / 1.2) < 0.4 and abs(p[0] + 7.0) < 2.0:
                return ("ink", 1.0)
            return ("label", 1.0)
        P.append(box((-7.0, 0.9, -length / 2 - 9.0), (2.6, 0.2, 4.2), label_mat, basis=basis_rot(ry=0.5)))
        P.append(capsule(add(ring_c, (-2.4, 0.0, -1.0)), (-6.0, 0.9, -length / 2 - 6.6), 0.25, m("cord")))
    elif tag == "cord":
        for i in range(14):
            P.append(sphere((-3.0 - i * 1.0, 1.0, -length / 2 - 5.0 + math.sin(i * 0.8) * 2.0), 0.6, m("cord", 1.0)))
    return P


# --- tela, vendas improvisadas y torniquete ([PROPUESTA]) ---------------------------------------

def cloth_mat(seed: int, stains: float = 0.66, blood: bool = False):
    """Tela de bata: trama a cuadros finos, algo de suciedad y, si se pide, sangre seca."""
    def f(p: Vec, n: Vec) -> tuple:
        weave = 0.9 + 0.1 * ((int(math.floor(p[0] * 2.4)) + int(math.floor(p[2] * 2.4))) % 2)
        if blood and fbm(mul(p, 0.5), seed + 7) > 0.68:
            return ("strip_blood", 0.95 + 0.1 * fbm(mul(p, 1.6), seed + 8))
        if fbm(mul(p, 0.38), seed) > stains:
            return ("strip_stain", 0.95 + 0.1 * fbm(mul(p, 1.4), seed + 1))
        return ("strip_cloth", weave * (0.9 + 0.14 * fbm(mul(p, 0.9), seed + 2)))
    return f


def cloth_strips() -> list:
    """Tres tiras arrancadas, onduladas, con los bordes deshilachados."""
    P = []
    for k, (x, ang) in enumerate(((-4.6, 0.18), (0.0, -0.08), (4.4, 0.24))):
        mat = cloth_mat(401 + k * 11)
        for i in range(7):
            z = -10.5 + i * 3.3
            P.append(box((x + 0.7 * math.sin(i * 1.3 + k), 0.6 + 0.35 * math.sin(i * 2.1 + k * 1.7), z),
                         (1.8, 0.32, 1.85), mat,
                         basis=basis_rot(ry=ang + 0.12 * math.sin(i + k), rx=0.18 * math.cos(i * 1.7 + k))))
        for t in range(4):  # hilos sueltos en la punta
            x0 = x - 1.4 + t * 0.95
            P.append(capsule((x0, 0.6, 11.0), (x0 + 0.4 * math.sin(t * 2.3 + k), 0.5, 12.6 + 0.6 * ((t + k) % 3)), 0.16,
                             m("strip_cloth", 0.85)))
    return P


def improvised_bandage() -> list:
    """Rollo de tiras de tela con un nudo, sin envoltorio."""
    cloth = cloth_mat(431, 0.6)

    def mat(p: Vec, n: Vec) -> tuple:
        if abs(n[0]) > 0.7:  # cara del rollo: vueltas de tela en espiral
            r = math.hypot(p[1] - 5.0, p[2])
            if _frac(r / 0.8 + math.atan2(p[1] - 5.0, p[2]) / math.tau) < 0.3:
                return ("strip_cloth", 0.6)
        if _frac(p[0] / 3.4) < 0.08:  # costuras entre tiras
            return ("strip_stain", 0.8)
        return cloth(p, n)
    P = [cylinder((-5.0, 5.0, 0.0), (5.0, 5.0, 0.0), 5.0, mat),
         cylinder((-5.1, 5.0, 0.0), (5.1, 5.0, 0.0), 1.2, m("void"))]
    for i in range(5):  # cola suelta
        P.append(box((0.5 * math.sin(i * 1.1), 0.35, 4.5 + i * 2.0), (3.6, 0.28, 1.05), cloth,
                     basis=basis_rot(ry=0.09 * math.sin(i * 2.0), rx=0.1 * math.cos(i * 1.7))))
    return P


def tourniquet() -> list:
    """Cinta gruesa de tela retorcida, cerrada en lazo, con nudo y dos colas."""
    mat = cloth_mat(451, 0.72)
    P = []
    for i in range(22):
        a = i / 22 * math.tau
        c = (math.cos(a) * 7.0, 1.4, math.sin(a) * 5.4)
        P.append(ellipsoid(c, (1.5, 1.2, 1.5), mat, basis=basis_rot(ry=-a, rx=0.5 * math.sin(a * 6))))
    P.append(ellipsoid((0.0, 2.0, 5.6), (2.4, 1.8, 2.0), mat))  # nudo, delante
    for k, dx in enumerate((-1.6, 1.8)):  # dos colas que caen hacia delante
        for j in range(3):
            P.append(box((dx * (1.0 + 0.5 * j), 0.6, 7.6 + j * 1.8), (1.1, 0.3, 1.0), mat,
                         basis=basis_rot(ry=0.35 * dx / abs(dx) + 0.1 * j)))
    return P


# --- armas ([PROPUESTA] las del hospital; cuchilla, barra y punzón son del prototipo de combate) ---

def blade_mat(edge_x: float):
    """Acero de hoja: mate y algo rayado, con el bisel del filo más claro (a partir de `edge_x`)."""
    def f(p: Vec, n: Vec) -> tuple:
        scratch = 0.06 * math.sin(p[2] * 7.0 + p[0] * 1.3)
        if p[0] > edge_x:
            return ("steel", 1.0 + scratch, None, 1.3)
        return ("steel", 0.72 + scratch + 0.08 * fbm(mul(p, 1.5), 511), None, 0.7)
    return f


def scalpel() -> list:
    """Bisturí de mango plano con estrías y hoja curva del n.º 22."""
    grip = lambda p, n: ("steel", 0.85 + (0.25 if _frac(p[2] / 1.1) < 0.4 and n[1] > 0.5 else 0.0), None, 1.0)  # noqa: E731
    P = [box((0.0, 1.0, -6.0), (1.2, 0.45, 9.0), grip),
         box((0.0, 1.0, 3.6), (0.8, 0.4, 0.8), m("steel", 1.0, 1.2))]
    for i in range(6):  # hoja: se ensancha y vuelve a la punta
        t = i / 5
        w = 0.6 + 1.3 * math.sin(t * math.pi * 0.85)
        P.append(box((0.35 * t, 1.0, 5.2 + i * 1.6), (w, 0.12, 0.85), blade_mat(0.35 * t + w * 0.45)))
    P.append(box((0.0, 1.0, 14.6), (0.25, 0.1, 0.6), m("steel", 1.2, 1.8)))
    P.append(box((0.9, 1.13, 8.0), (0.5, 0.02, 1.6), m("strip_blood", 1.0)))  # mancha seca en el filo
    return P


def pipe(wrapped: bool) -> list:
    """Tubo de hierro galvanizado con rosca en un extremo y óxido; envuelto con tela si se pide."""
    def mat(p: Vec, n: Vec) -> tuple:
        if fbm(mul(p, 0.32), 461) > 0.6:
            return ("pipe_rust", 0.9 + 0.2 * fbm(mul(p, 1.7), 462), None, 0.1)
        return ("castiron", 0.95 + 0.12 * fbm(mul(p, 1.2), 463), None, 0.7)
    P = [cylinder((0.0, 2.4, -26.0), (0.0, 2.4, 24.0), 2.3, mat),
         cylinder((0.0, 2.4, 24.0), (0.0, 2.4, 24.3), 1.6, m("void"))]
    for i in range(6):  # rosca
        z = 19.0 + i * 0.8
        P.append(cylinder((0.0, 2.4, z), (0.0, 2.4, z + 0.35), 2.45, m("steel", 0.95, 0.9)))
    P.append(cylinder((0.0, 2.4, -26.0), (0.0, 2.4, -22.4), 2.9, m("castiron", 0.85, 0.5)))  # manguito
    if wrapped:
        cloth = cloth_mat(471, 0.62, blood=True)
        for i in range(10):
            z = -21.6 + i * 1.55
            P.append(cylinder((0.0, 2.4, z), (0.0, 2.4, z + 1.25), 2.75, cloth))
        P.append(capsule((0.0, 4.6, -6.2), (2.4, 3.6, -3.4), 0.45, cloth))  # cabo del nudo
    return P


def knife() -> list:
    """Cuchilla de cocina con mango de madera y tres remaches."""
    wood = lambda p, n: ("handle_wood", 0.9 + 0.2 * _frac(p[2] * 0.55 + fbm(mul(p, 0.6), 481) * 2.0), None, 0.3)  # noqa: E731
    P = [box((0.0, 1.4, -8.5), (1.6, 0.9, 6.0), wood)]
    for z in (-12.0, -8.5, -5.0):
        P.append(cylinder((0.0, 1.0, z), (0.0, 2.45, z), 0.55, m("brass", 1.05, 1.2)))
    P.append(box((0.0, 1.4, -2.2), (1.8, 1.0, 0.4), m("steel", 0.9, 1.0)))  # virola
    for i in range(8):  # hoja que se estrecha hacia la punta
        t = i / 7
        w = 2.1 * (1.0 - t ** 1.8) + 0.25
        P.append(box((-0.3 * t, 1.4, -0.6 + i * 2.2), (w, 0.16, 1.15), blade_mat(-0.3 * t + w * 0.55)))
    return P


def iron_bar() -> list:
    """Barra de hierro corrugado (de obra), oxidada."""
    def mat(p: Vec, n: Vec) -> tuple:
        rib = math.sin(p[2] * 2.6 + math.atan2(p[1] - 2.0, p[0]) * 1.0)
        n2 = norm((n[0], n[1], n[2] + 0.4 * rib))
        if fbm(mul(p, 0.3), 491) > 0.5:
            return ("pipe_rust", 0.9 + 0.18 * fbm(mul(p, 1.8), 492), n2, 0.1)
        return ("castiron", 0.95, n2, 0.6)
    P = [cylinder((0.0, 2.0, -27.0), (0.0, 2.0, 27.0), 1.7, mat)]
    for side in (-1.0, 1.0):  # nervios longitudinales
        P.append(box((side * 1.7, 2.0, 0.0), (0.25, 0.3, 27.0), mat))
    return P


def awl() -> list:
    """Punzón: mango de madera en forma de pera y vástago de acero afilado."""
    wood = lambda p, n: ("handle_wood", 0.95 + 0.15 * fbm(mul(p, 0.9), 501), None, 0.5)  # noqa: E731
    P = [ellipsoid((0.0, 3.0, -9.0), (3.0, 3.0, 6.0), wood),
         cylinder((0.0, 3.0, -3.5), (0.0, 3.0, -2.2), 1.6, m("brass", 1.0, 1.1)),
         cylinder((0.0, 3.0, -2.2), (0.0, 3.0, 11.0), 0.6, m("steel", 1.1, 1.5))]
    for k in range(4):
        P.append(cylinder((0.0, 3.0, 11.0 + k * 0.9), (0.0, 3.0, 11.9 + k * 0.9), 0.55 - k * 0.13, m("steel", 1.2, 1.6)))
    return P


# --- ropa ------------------------------------------------------------------------------------------

def garment(gid: str):
    def model() -> list:
        pose = human.idle_pose(0.0)
        pose.arm_abduct = {1.0: 0.42, -1.0: 0.42}  # mangas algo abiertas, como una prenda extendida
        pose.lean = 0.0
        return human.build_parts(pose, (gid,))[gid]
    return model


# id: (modelo, casillas (ancho, alto), giro del icono)
ITEMS: dict = {
    "linterna": (flashlight, (1, 2), 0.0),
    "pilas": (batteries, (1, 1), 0.0),
    "venda": (lambda: bandage(gauze("gauze_hi")), (1, 1), 0.3),
    "venda_sucia": (lambda: bandage(gauze("gauze_dirty", "blood")), (1, 1), 0.3),
    "venda_esterilizada": (lambda: bandage(gauze("iodine")), (1, 1), 0.3),
    "desinfectante": (disinfectant, (1, 1), 0.0),
    "analgesicos": (pills, (1, 1), 0.0),
    "jeringa": (lambda: syringe(False), (1, 1), 0.7),
    "ampolla": (ampoule, (1, 1), 0.0),
    "sedante": (lambda: syringe(True), (1, 1), 0.7),
    "destornillador": (screwdriver, (1, 2), 0.0),
    "palanca": (crowbar, (1, 3), 0.0),
    "fusible": (fuse, (1, 2), 0.0),
    "valvula_averiada": (lambda: valve(False), (2, 2), 0.35),
    "valvula_reparada": (lambda: valve(True), (2, 2), 0.35),
    "llave_botiquin": (lambda: key_model("", 12.0, "steel"), (1, 1), 0.5),
    "llave_habitacion_10": (lambda: key_model("plastic", 14.0), (1, 1), 0.5),
    "llave_archivo": (lambda: key_model("label", 18.0), (1, 1), 0.5),
    "llave_sotano": (lambda: key_model("cord", 16.0, "steel"), (1, 1), 0.5),
    "tela": (cloth_strips, (1, 1), 0.4),
    "venda_improvisada": (improvised_bandage, (1, 1), 0.3),
    "torniquete": (tourniquet, (1, 1), 0.2),
    "bisturi": (scalpel, (1, 2), 0.0),
    "tubo_metal": (lambda: pipe(False), (1, 3), 0.0),
    "tubo_envuelto": (lambda: pipe(True), (1, 3), 0.0),
    "cuchilla": (knife, (1, 2), 0.0),
    "barra_hierro": (iron_bar, (1, 3), 0.0),
    "punzon": (awl, (1, 2), 0.0),
}
WEAR_CELLS = {"head": (1, 1), "body": (2, 2), "legs": (1, 2), "feet": (2, 1)}
WEAR_YAW = {"head": 0.5, "body": 0.0, "legs": 0.25, "feet": -1.0}
for _gid, _slot in human.GARMENTS.items():
    ITEMS[_gid] = (garment(_gid), (2, 2) if _gid == "botas_goma" else WEAR_CELLS[_slot], WEAR_YAW[_slot])


def _fit(model, w: int, h: int, view: View, fill: float = 0.92) -> tuple[float, tuple[float, float]]:
    """Escala y origen para que el modelo llene `fill` del recuadro."""
    k, (cx, cy) = _fit_center(model, w, h, view, fill)
    return k, (w / 2 - cx * k, h / 2 - cy * k)


def _fit_center(model, w: int, h: int, view: View, fill: float = 0.92) -> tuple[float, tuple[float, float]]:
    """Escala para llenar `fill` del recuadro y centro del modelo en pantalla (a escala 1)."""
    probe = 240
    r = render(model(), probe, probe, (probe / 2, probe / 2), View(a=view.a, b=view.b, yaw=view.yaw, ss=1))
    bbox = r.color.getbbox()
    if bbox is None:
        return 1.0, (0.0, 0.0)
    bw, bh = bbox[2] - bbox[0], bbox[3] - bbox[1]
    k = min(w * fill / bw, h * fill / bh)
    return k, ((bbox[0] + bbox[2]) / 2 - probe / 2, (bbox[1] + bbox[3]) / 2 - probe / 2)


def _icon_view(yaw: float) -> View:
    return View(a=ICON_VIEW.a, b=ICON_VIEW.b, yaw=yaw, light=ICON_VIEW.light, ambient=ICON_VIEW.ambient,
                dither=ICON_VIEW.dither, ss=ICON_VIEW.ss)


def _inspect_view(i: int) -> View:
    return View(a=INSPECT_VIEW.a, b=INSPECT_VIEW.b, ambient=INSPECT_VIEW.ambient, light=INSPECT_VIEW.light,
                yaw=i / 8 * math.tau, dither=INSPECT_VIEW.dither, ss=INSPECT_VIEW.ss)


def _job(args: tuple) -> tuple:
    """Un icono (frame = -1) o una vista del inspector (frame 0..7)."""
    item_id, frame = args
    model, cells, yaw = ITEMS[item_id]
    if frame < 0:
        w, h = cells[0] * CELL - 4, cells[1] * CELL - 4
        view = _icon_view(yaw)
        k, origin = _fit(model, w, h, view)
        img = render(scale_prims(model(), k), w, h, origin, view).color
    else:
        # Mismo encuadre en las 8 vistas: el más pequeño de mirarlo de frente y de lado.
        # Centrado en vertical según la vista de frente (la ropa no está en el origen del modelo:
        # cuelga del cuerpo, y sin esto quedaba fuera del recuadro). En horizontal gira sobre su eje.
        fits = [_fit_center(model, INSPECT_SIZE, INSPECT_SIZE, _inspect_view(i), 0.84) for i in (0, 2)]
        k = min(f[0] for f in fits)
        cy = fits[0][1][1]
        origin = (INSPECT_SIZE / 2, INSPECT_SIZE / 2 + 2 - cy * k)
        img = render(scale_prims(model(), k), INSPECT_SIZE, INSPECT_SIZE, origin, _inspect_view(frame)).color
    return item_id, frame, img.size, img.tobytes()


def build(out_dir: Path, only: list[str] | None = None) -> list[str]:
    """Genera iconos e inspector de todos los objetos (o de `only`), repartido entre núcleos."""
    from multiprocessing import Pool
    import os
    out_dir.mkdir(parents=True, exist_ok=True)
    ids = [i for i in ITEMS if not only or i in only]
    jobs = [(i, f) for i in ids for f in range(-1, 8)]
    sheets = {i: Image.new("RGBA", (INSPECT_SIZE * 8, INSPECT_SIZE), (0, 0, 0, 0)) for i in ids}
    with Pool(max(1, (os.cpu_count() or 2) - 1)) as pool:
        for item_id, frame, size, data in pool.imap_unordered(_job, jobs):
            img = Image.frombytes("RGBA", size, data)
            if frame < 0:
                img.save(out_dir / f"{item_id}.png")
            else:
                sheets[item_id].alpha_composite(img, (frame * INSPECT_SIZE, 0))
    for item_id, sheet in sheets.items():
        sheet.save(out_dir / f"{item_id}_inspect.png")
    return ids


if __name__ == "__main__":
    print(build(Path(__file__).resolve().parents[2] / "assets/sprites/items", sys.argv[1:] or None))
