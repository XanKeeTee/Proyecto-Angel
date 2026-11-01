"""Objetos de la custodia: icono para la bandeja (casillas x 24 px) y 8 vistas para el inspector."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image

import human  # noqa: F401  (rampas)
import props2  # noqa: F401  (rampas)
from props import gauze_mat, mat, metal_worn
from pxrender import View, basis_rot, box, capsule, cylinder, ellipsoid, fbm, mul, ramp, render, scale_prims, sphere

ramp("brass", [(54, 40, 14), (96, 74, 28), (140, 112, 48), (186, 156, 80), (220, 196, 120)])
ramp("battery", [(14, 14, 16), (30, 30, 34), (52, 50, 54), (80, 76, 78)])
ramp("copper", [(60, 30, 14), (110, 60, 30), (160, 100, 54), (200, 150, 96)])
ramp("iodine", [(70, 40, 14), (112, 70, 26), (150, 104, 48), (184, 140, 80)])
ramp("red_paint", [(40, 8, 8), (80, 18, 16), (120, 32, 28), (160, 54, 46)])

ICON = 24
ICON_VIEW = View(b=0.85, ambient=0.45, light=(-0.4, 0.8, 0.5))
INSPECT_VIEW = View(b=0.55, ambient=0.42, light=(-0.4, 0.8, 0.5))
INSPECT_SIZE = 72


def dirty(p, n) -> tuple:
    if fbm(mul(p, 0.5), 301) > 0.55:
        return ("blood_dry", 1.0)
    return ("gauze", 0.85)


def key_model(tag: str, length: float = 16.0, metal: str = "brass") -> list:
    prims = []
    for i in range(10):
        a = i / 10 * math.tau
        prims.append(sphere((math.cos(a) * 3.5, 1.0, -length / 2 + math.sin(a) * 3.5), 1.0, mat(metal, 1.0)))
    prims.append(box((0.0, 1.0, 1.5), (0.9, 0.7, length / 2 - 1.0), mat(metal, 1.05)))
    for i, h in enumerate((1.5, 2.5, 1.0, 2.0)):
        prims.append(box((1.0 + h / 2, 1.0, length / 2 - 2.0 - i * 2.2), (h / 2, 0.6, 0.8), mat(metal, 0.95)))
    if tag == "plastic":
        prims.append(box((-6.0, 1.0, -length / 2 - 3.0), (4.0, 0.8, 3.0), mat("plastic_yellow", 1.0), basis=basis_rot(ry=0.4)))
    elif tag == "label":
        prims.append(box((-6.0, 1.0, -length / 2 - 2.0), (3.0, 0.3, 4.5), mat("gauze", 1.1), basis=basis_rot(ry=0.6)))
    elif tag == "cord":
        for i in range(8):
            prims.append(sphere((-4.0 - i * 1.2, 1.0, -length / 2 - 2.0 + math.sin(i) * 1.5), 0.6, mat("canvas", 0.9)))
    return prims


def bandage(material) -> list:
    return [cylinder((-6.0, 5.0, 0.0), (6.0, 5.0, 0.0), 5.0, material),
            cylinder((-6.1, 5.0, 0.0), (6.1, 5.0, 0.0), 1.5, mat("void")),
            box((4.0, 0.6, 6.0), (2.0, 0.4, 3.0), material)]


def syringe(filled: bool) -> list:
    prims = [cylinder((0.0, 2.0, -8.0), (0.0, 2.0, 6.0), 1.8, mat("bag", 1.0))]
    if filled:
        prims.append(cylinder((0.0, 2.0, -2.0), (0.0, 2.0, 5.5), 1.4, mat("amber", 1.1)))
    prims.append(cylinder((0.0, 2.0, -12.0), (0.0, 2.0, -8.0), 0.6, mat("plastic", 1.2)))
    prims.append(cylinder((0.0, 2.0, -12.5), (0.0, 2.0, -12.0), 2.4, mat("plastic", 1.2)))
    prims.append(capsule((0.0, 2.0, 6.0), (0.0, 2.0, 12.0), 0.25, mat("metal", 1.3)))
    return prims


def valve(repaired: bool) -> list:
    prims = [cylinder((0.0, 0.0, 0.0), (0.0, 12.0, 0.0), 8.0, metal_worn)]
    for side in (-1.0, 1.0):
        prims.append(cylinder((side * 8.0, 6.0, 0.0), (side * 13.0, 6.0, 0.0), 3.5, metal_worn))
    prims.append(cylinder((0.0, 12.0, 0.0), (0.0, 18.0, 0.0), 1.2, metal_worn))
    for i in range(14):
        a = i / 14 * math.tau
        prims.append(sphere((math.cos(a) * 7.0, 18.5, math.sin(a) * 7.0), 1.1, mat("red_paint", 1.0)))
    for i in range(4):
        a = i / 4 * math.tau
        prims.append(capsule((0.0, 18.5, 0.0), (math.cos(a) * 7.0, 18.5, math.sin(a) * 7.0), 0.6, mat("red_paint", 1.0)))
    for i in range(6):
        a = i / 6 * math.tau + 0.3
        screw = mat("metal", 1.35) if repaired else mat("void")
        prims.append(cylinder((math.cos(a) * 6.0, 12.0, math.sin(a) * 6.0), (math.cos(a) * 6.0, 12.6, math.sin(a) * 6.0),
                              0.9, screw))
    return prims


# id: (modelo, casillas (ancho, alto), escala del icono)
ITEMS: dict = {
    "linterna": (lambda: [cylinder((0.0, 3.0, -16.0), (0.0, 3.0, 8.0), 3.2, mat("grip", 1.1)),
                          cylinder((0.0, 3.0, 8.0), (0.0, 3.0, 16.0), 4.6, metal_worn),
                          cylinder((0.0, 3.0, 16.0), (0.0, 3.0, 16.4), 3.8, mat("!lens", 0.9)),
                          box((0.0, 6.0, -2.0), (1.2, 0.8, 2.0), mat("metal", 1.2))], (1, 2), 1.0),
    "pilas": (lambda: [cylinder((x, 3.4, -7.0), (x, 3.4, 7.0), 3.3, mat("battery", 1.0)) for x in (-3.6, 3.6)]
              + [cylinder((x, 3.4, 7.0), (x, 3.4, 8.0), 1.2, mat("copper", 1.2)) for x in (-3.6, 3.6)], (1, 1), 1.0),
    "venda": (lambda: bandage(mat("gauze", 1.1)), (1, 1), 1.0),
    "venda_sucia": (lambda: bandage(dirty), (1, 1), 1.0),
    "venda_esterilizada": (lambda: bandage(mat("iodine", 1.1)), (1, 1), 1.0),
    "desinfectante": (lambda: [cylinder((0.0, 0.0, 0.0), (0.0, 14.0, 0.0), 5.0, mat("bottle", 1.0)),
                               cylinder((0.0, 14.0, 0.0), (0.0, 18.0, 0.0), 2.4, mat("plastic", 1.2)),
                               box((0.0, 7.0, 5.0), (3.5, 3.5, 0.2), mat("gauze", 1.1))], (1, 1), 1.0),
    "analgesicos": (lambda: [cylinder((0.0, 0.0, 0.0), (0.0, 11.0, 0.0), 4.2, mat("amber", 1.0)),
                             cylinder((0.0, 11.0, 0.0), (0.0, 13.5, 0.0), 4.4, mat("gauze", 1.2))], (1, 1), 1.1),
    "jeringa": (lambda: syringe(False), (1, 1), 0.9),
    "ampolla": (lambda: [cylinder((0.0, 0.0, 0.0), (0.0, 8.0, 0.0), 2.4, mat("bottle", 1.2)),
                         cylinder((0.0, 8.0, 0.0), (0.0, 10.0, 0.0), 1.0, mat("bottle", 1.2)),
                         sphere((0.0, 11.0, 0.0), 1.6, mat("bottle", 1.2)),
                         box((0.0, 4.0, 2.4), (1.8, 1.8, 0.1), mat("gauze", 1.1))], (1, 1), 1.3),
    "sedante": (lambda: syringe(True), (1, 1), 0.9),
    "destornillador": (lambda: [cylinder((0.0, 3.5, -20.0), (0.0, 3.5, -4.0), 3.5, mat("plastic_yellow", 1.0)),
                                cylinder((0.0, 3.5, -4.0), (0.0, 3.5, 18.0), 1.0, mat("metal", 1.2)),
                                box((0.0, 3.5, 19.0), (1.6, 0.4, 1.2), mat("metal", 1.2))], (1, 2), 1.0),
    "palanca": (lambda: [capsule((0.0, 2.0, -30.0), (0.0, 2.0, 26.0), 2.0, metal_worn),
                         capsule((0.0, 2.0, 26.0), (0.0, 4.0, 32.0), 2.0, metal_worn),
                         capsule((0.0, 4.0, 32.0), (0.0, 1.0, 34.0), 1.6, mat("rust", 1.0)),
                         capsule((0.0, 2.0, -30.0), (-3.0, 2.0, -33.0), 1.6, mat("blood_dry", 1.1))], (1, 3), 1.0),
    "fusible": (lambda: [cylinder((0.0, 5.0, -12.0), (0.0, 5.0, 12.0), 5.0, mat("ceramic", 1.0)),
                         cylinder((0.0, 5.0, -16.0), (0.0, 5.0, -12.0), 5.5, mat("brass", 1.0)),
                         cylinder((0.0, 5.0, 12.0), (0.0, 5.0, 16.0), 5.5, mat("brass", 1.0)),
                         box((0.0, 10.0, 0.0), (2.5, 0.2, 6.0), mat("gauze", 1.1))], (1, 2), 1.0),
    "valvula_averiada": (lambda: valve(False), (2, 2), 1.15),
    "valvula_reparada": (lambda: valve(True), (2, 2), 1.15),
    "llave_botiquin": (lambda: key_model("", 12.0, "metal"), (1, 1), 1.1),
    "llave_habitacion_10": (lambda: key_model("plastic", 14.0), (1, 1), 1.0),
    "llave_archivo": (lambda: key_model("label", 18.0), (1, 1), 0.95),
    "llave_sotano": (lambda: key_model("cord", 16.0, "metal"), (1, 1), 1.0),
}


def build(out_dir: Path) -> list[str]:
    out_dir.mkdir(parents=True, exist_ok=True)
    built = []
    for item_id, (model, cells, scale) in ITEMS.items():
        w, h = cells[0] * ICON, cells[1] * ICON
        prims = scale_prims(model(), scale)
        icon = render(prims, w, h, (w / 2, h / 2 + 2), ICON_VIEW).color
        icon.save(out_dir / f"{item_id}.png")
        # Vistas del inspector: el objeto escalado para llenar el recuadro, girando sobre sí mismo.
        longest = max(cells) * ICON * 1.15
        k = INSPECT_SIZE / longest * scale
        big = scale_prims(model(), k)
        sheet = Image.new("RGBA", (INSPECT_SIZE * 8, INSPECT_SIZE), (0, 0, 0, 0))
        for i in range(8):
            view = View(b=INSPECT_VIEW.b, ambient=INSPECT_VIEW.ambient, light=INSPECT_VIEW.light, yaw=i / 8 * math.tau)
            frame = render(big, INSPECT_SIZE, INSPECT_SIZE, (INSPECT_SIZE / 2, INSPECT_SIZE / 2 + 6), view).color
            sheet.alpha_composite(frame, (i * INSPECT_SIZE, 0))
        sheet.save(out_dir / f"{item_id}_inspect.png")
        built.append(item_id)
    return built
