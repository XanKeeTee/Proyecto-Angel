"""Mobiliario con más detalle (objetos interactuables) y decorado no interactivo del hospital.

Vista oblicua de mapa (props.MAP_VIEW, b = 1): la altura sube en pantalla 1:1 y la
profundidad baja 1:1. Coordenadas: x derecha, y arriba, z hacia el espectador; 1 = 1 px.

Interactuables (se mantienen los índices de fotograma que usa el juego; lo nuevo va al final):
  nightstand      0 cerrada · 1 cajón abierto con cosas · 2 cajón abierto vacío
  locker          0 cerrada · 1 abierta con ropa · 2 abierta vacía
  desk, workbench 0 cerrado · 1 cajón abierto con cosas · 2 cajón abierto vacío
  filing_cabinet  0 cerrado · 1 cajón abierto con carpetas · 2 cajón abierto vacío
  shelf           0 cajas · 1 frascos · 2 cajas (registrada) · 3 frascos (registrada)
  med_cabinet     0 cerrado · 1 abierto con frascos y una llave colgada · 2 abierto sin la llave
  counter         0 cerrado · 1 puertas abiertas con cosas · 2 puertas abiertas vacío
  elec_panel      0 cerrado · 1 abierto averiado · 2 bornas apretadas · 3 con el fusible
  generator       0 parado · 1 en marcha
  trash_bin       0 llena · 1 revuelta
  laundry_cart    0 lleno · 1 revuelto
  tape_recorder, crates, boiler, morgue (0 cerrada, 1 cajón con pie, 2 cajón vacío)

Decorado (DRESSING): ver la tabla al final del archivo; la escena lo coloca con
tools/levels/hospital_dressing.gd.
"""

from __future__ import annotations

import math
import random

import human
import props2  # noqa: F401  (rampas cardboard, bottle, amber, bakelite…)
from materials import cardboard, fabric, flat, glass, noisy, painted, steel, wood
from props import make_sheet, mat, metal_worn
from pxrender import Vec, add, basis_rot, box, capsule, cylinder, ellipsoid, limb, sphere, transform

ENAMEL = painted("enamel", 11)
ENAMEL_B = painted("enamel", 12, bright=1.08)
GREEN = painted("enamel_green", 13)
CHROME = steel(14)
STEEL = steel(15, name="metal", spec=0.7)
GALV = painted("galv", 16, rust=0.7, chips=0.9, dent=0.5)
MACHINE = painted("machine", 17, rust=0.7, dent=0.4)
OXBLOOD = painted("oxblood", 18, rust=0.72)
RUBBER = flat("rubber")
DARK = flat("dark")
VOID = flat("void")
GLASS = glass(19)
PAPER = noisy("paper", 20, 0.25, 1.1)
LABEL = noisy("label_w", 21, 0.2)
WOOD = wood(22)


def caster(x: float, z: float, r: float = 1.3) -> list:
    """Rueda giratoria: horquilla y rueda de goma."""
    return [capsule((x, r * 2 + 0.6, z), (x, r * 2 + 2.2, z), 0.45, CHROME),
            cylinder((x - 0.7, r, z), (x + 0.7, r, z), r, RUBBER)]


def pad(x: float, z: float, r: float = 1.0) -> list:
    return [cylinder((x, 0.0, z), (x, 0.9, z), r, RUBBER)]


def handle_h(x: float, y: float, z: float, w: float = 3.0, r: float = 0.45) -> list:
    return [capsule((x - w, y, z + 0.6), (x + w, y, z + 0.6), r, CHROME),
            capsule((x - w, y, z), (x - w, y, z + 0.6), r * 0.8, CHROME),
            capsule((x + w, y, z), (x + w, y, z + 0.6), r * 0.8, CHROME)]


def papers(rng: random.Random, n: int, x0: float, x1: float, z0: float, z1: float, y: float, size: tuple = (3.5, 4.5)) -> list:
    prims = []
    for i in range(n):
        prims.append(box((rng.uniform(x0, x1), y + 0.12 * i, rng.uniform(z0, z1)), (size[0], 0.12, size[1]),
                         PAPER if rng.random() < 0.8 else flat("stain", 1.0), basis=basis_rot(ry=rng.uniform(-0.7, 0.7))))
    return prims


def bottle(x: float, y: float, z: float, h: float, r: float, kind: str = "amber") -> list:
    m = {"amber": noisy("amber", 23, 0.2), "green": noisy("bottle", 24, 0.2), "white": ENAMEL_B, "clear": GLASS}[kind]
    prims = [cylinder((x, y, z), (x, y + h, z), r, m)]
    prims.append(cylinder((x, y + h, z), (x, y + h + max(1.0, h * 0.18), z), r * 0.5, m))
    prims.append(cylinder((x, y + h + max(1.0, h * 0.18), z), (x, y + h + max(1.0, h * 0.18) + 0.8, z), r * 0.6,
                          flat("plastic", 1.0)))
    if h > 4:
        prims.append(box((x, y + h * 0.5, z + r * 0.9), (r * 0.8, h * 0.22, 0.1), LABEL))
    return prims


# --- mesita ---------------------------------------------------------------------------------------

def nightstand(state: int) -> list:
    prims = [box((0.0, 13.0, 0.0), (8.5, 11.0, 6.5), ENAMEL)]
    for x in (-6.8, 6.8):
        for z in (-4.8, 4.8):
            prims += caster(x, z, 1.0)
    prims.append(box((0.0, 24.6, 0.0), (9.0, 0.6, 7.0), ENAMEL_B))
    for a, b in (((-8.6, 26.0, -6.6), (8.6, 26.0, -6.6)), ((-8.6, 26.0, -6.6), (-8.6, 26.0, 5.0)), ((8.6, 26.0, -6.6), (8.6, 26.0, 5.0))):
        prims.append(capsule(a, b, 0.4, CHROME))
    # Hueco entre cajón y puerta, puerta baja con su tirador.
    prims.append(box((0.0, 16.9, 6.55), (8.3, 0.3, 0.1), DARK))
    prims.append(box((0.0, 9.6, 6.7), (7.6, 6.6, 0.25), ENAMEL_B))
    prims.append(capsule((5.6, 12.2, 7.3), (5.6, 8.4, 7.3), 0.45, CHROME))
    # Encima: vaso de agua con polvo, vasito de pastillas y la hoja de la cena.
    prims.append(cylinder((-4.5, 25.2, -2.5), (-4.5, 29.6, -2.5), 1.6, GLASS,
                          cut=lambda p: p[1] > 29.2 and (p[0] + 4.5) ** 2 + (p[2] + 2.5) ** 2 < 1.3))
    prims.append(cylinder((-4.5, 25.3, -2.5), (-4.5, 27.4, -2.5), 1.25, flat("water_dark", 1.1, 0.8)))
    prims.append(cylinder((2.8, 25.2, 1.5), (2.8, 26.8, 1.5), 1.1, LABEL))
    prims.append(box((3.2, 25.3, -3.5), (2.6, 0.1, 2.0), PAPER, basis=basis_rot(ry=0.3)))
    if state == 0:
        prims.append(box((0.0, 20.2, 6.7), (7.6, 2.6, 0.25), ENAMEL_B))
        prims += handle_h(0.0, 20.2, 6.95)
    else:
        prims.append(box((0.0, 20.2, 7.0), (7.6, 2.6, 0.25), ENAMEL_B))
        prims.append(box((0.0, 19.4, 11.0), (7.2, 0.25, 4.2), ENAMEL))  # fondo del cajón
        for x in (-7.3, 7.3):
            prims.append(box((x, 20.6, 11.0), (0.25, 1.6, 4.2), ENAMEL))
        prims.append(box((0.0, 20.6, 15.1), (7.6, 2.1, 0.3), ENAMEL_B))
        prims += handle_h(0.0, 20.8, 15.4)
        prims.append(box((0.0, 19.7, 11.0), (6.9, 0.05, 3.9), flat("dark", 0.9)))
        if state == 1:
            rng = random.Random(31)
            prims += papers(rng, 2, -4, 4, 9, 13, 19.8, (2.6, 3.0))
            prims.append(box((-3.0, 20.4, 10.5), (2.2, 0.4, 1.4), flat("metal", 1.2, 0.8)))  # blíster
            prims.append(capsule((1.0, 20.3, 13.2), (5.5, 20.3, 12.0), 0.4, flat("plastic", 1.2)))  # bolígrafo
            prims.append(cylinder((3.5, 19.9, 9.5), (3.5, 21.5, 9.5), 1.2, flat("gauze", 1.1)))
        else:
            prims.append(box((0.0, 19.8, 11.0), (6.6, 0.06, 3.6), flat("stain", 0.7)))
            prims.append(sphere((4.0, 19.9, 13.0), 0.5, flat("label_w", 1.1)))
    return prims


# --- taquilla -------------------------------------------------------------------------------------

def _locker_panel(c: Vec, half: Vec, seed: int) -> list:
    return [box(c, half, painted("enamel_green", seed, rust=0.7, dent=0.6))]


def locker(state: int) -> list:
    """Taquilla de dos puertas. Al abrir, la izquierda gira hacia fuera y se ve el interior."""
    prims = []
    prims += _locker_panel((0.0, 31.5, -5.6), (13.0, 30.5, 0.4), 41)  # fondo
    prims += _locker_panel((-12.6, 31.5, 0.0), (0.4, 30.5, 6.0), 42)
    prims += _locker_panel((12.6, 31.5, 0.0), (0.4, 30.5, 6.0), 43)
    prims += _locker_panel((0.0, 62.2, 0.0), (13.0, 0.4, 6.0), 44)  # techo
    prims += _locker_panel((0.0, 1.6, 0.0), (13.0, 0.6, 6.0), 45)  # base
    prims += _locker_panel((0.0, 31.5, 0.0), (0.35, 30.5, 5.6), 46)  # tabique
    for x in (-11.0, 11.0):
        for z in (-4.5, 4.5):
            prims.append(box((x, 0.5, z), (0.8, 0.5, 0.8), RUBBER))

    def door(x0: float, open_: bool) -> list:
        d = []
        seed = 47 if x0 < 0 else 48
        panel = painted("enamel_green", seed, rust=0.68, dent=0.8)
        d.append(box((6.4, 31.6, 0.0), (6.3, 29.8, 0.3), panel))
        for vy in (55.5, 53.5, 51.5):  # rejillas
            d.append(box((6.4, vy, 0.32), (3.8, 0.35, 0.05), DARK))
        d.append(box((6.4, 46.0, 0.35), (2.4, 1.2, 0.06), LABEL))  # tarjetero
        d.append(box((6.4, 46.0, 0.42), (2.6, 1.4, 0.03), flat("chrome", 0.8, 0.5)))
        d.append(box((11.0, 33.0, 0.6), (0.6, 2.4, 0.4), CHROME))  # tirador
        d.append(box((11.0, 30.0, 0.5), (0.9, 0.8, 0.3), flat("dark", 1.0)))  # cerradura
        if open_:
            return transform(d, basis_rot(ry=-1.95), (x0, 0.0, 6.0))
        return transform(d, basis_rot(), (x0, 0.0, 6.0))

    prims += door(0.6, False)
    if state == 0:
        prims += door(-12.6, False)
        return prims
    prims += door(-12.6, True)
    prims.append(box((-6.3, 49.0, 0.0), (5.9, 0.3, 5.4), painted("enamel_green", 49)))  # balda
    prims.append(capsule((-11.0, 46.5, 0.0), (-1.5, 46.5, 0.0), 0.3, CHROME))  # barra
    prims.append(box((-6.3, 31.0, -5.1), (5.8, 17.5, 0.05), flat("dark", 1.0)))  # sombra del fondo
    if state == 1:
        coat = fabric("gown", 50, folds=0.5)
        prims.append(capsule((-6.3, 46.6, 0.0), (-6.3, 44.0, 0.0), 0.25, CHROME))
        prims.append(ellipsoid((-6.3, 36.0, -0.5), (4.6, 9.0, 3.0), coat))  # ropa colgada
        prims.append(ellipsoid((-6.0, 26.5, -0.8), (3.6, 4.0, 2.4), coat))
        prims.append(box((-6.3, 50.5, -1.0), (3.5, 1.2, 3.0), noisy("wool", 51)))  # gorro doblado
        prims.append(ellipsoid((-8.5, 3.5, 2.0), (2.0, 1.4, 3.0), flat("slipper", 0.9)))  # zapato
        prims.append(box((-3.5, 51.2, 1.0), (1.5, 2.0, 1.0), flat("plastic", 1.1)))
    else:
        prims += limb([(-6.3, 46.6, 0.0), (-6.3, 45.0, 0.0), (-9.0, 43.5, 0.0), (-4.0, 42.0, 0.6)], [0.25] * 4, CHROME, 1)
        prims.append(box((-6.3, 2.5, -1.0), (4.0, 0.1, 3.0), flat("stain", 0.6)))
    return prims


# --- escritorio y banco ------------------------------------------------------------------------------

def desk(state: int) -> list:
    """Escritorio de oficina: tablero de formica sobre bastidor de acero y cajonera a la derecha.
    El tablero queda a 25.2 de alto (el ordenador del juego se apoya ahí)."""
    rng = random.Random(61)
    top = noisy("formica", 62, 0.25)
    prims = [box((0.0, 24.0, 0.0), (30.0, 1.2, 12.0), top)]
    prims.append(box((0.0, 24.0, 12.05), (30.0, 1.2, 0.08), flat("formica", 0.75)))
    for x in (-28.0, -10.0):
        for z in (-10.5, 10.5):
            prims.append(box((x, 11.5, z), (0.8, 11.5, 0.8), painted("galv", 63)))
        prims.append(box((x, 2.0, 0.0), (0.8, 0.6, 10.5), painted("galv", 64)))
    prims.append(box((-19.0, 15.0, -10.8), (9.0, 8.0, 0.4), painted("galv", 65)))  # faldón
    prims.append(box((18.0, 12.0, 0.0), (11.0, 11.0, 11.0), painted("enamel", 66, grime_h=4.0)))
    for i, y in enumerate((5.5, 12.5)):
        prims.append(box((18.0, y, 11.1), (10.2, 3.0, 0.15), painted("enamel", 67 + i, bright=1.06)))
        prims += handle_h(18.0, y + 1.2, 11.25, 2.4, 0.4)
    prims.append(box((18.0, 16.0, 11.05), (10.4, 0.3, 0.1), DARK))
    prims.append(box((18.0, 9.0, 11.05), (10.4, 0.3, 0.1), DARK))
    # Encima: papeles, taza con un cerco, portalápices, carpeta.
    prims += papers(rng, 4, -4, 22, -8, 6, 25.3)
    prims.append(cylinder((24.0, 25.2, -6.0), (24.0, 28.6, -6.0), 1.8, flat("porcelain", 1.0, 0.6)))
    prims.append(cylinder((24.0, 28.0, -6.0), (24.0, 28.62, -6.0), 1.4, flat("dark", 1.0)))
    prims.append(capsule((25.9, 27.6, -6.0), (25.9, 26.0, -6.0), 0.5, flat("porcelain", 0.9)))
    prims.append(cylinder((-2.0, 25.2, -8.0), (-2.0, 29.0, -8.0), 1.6, flat("bakelite", 1.1)))
    for k in range(3):
        prims.append(capsule((-2.0 + k * 0.6 - 0.6, 28.0, -8.0), (-2.5 + k * 1.2, 31.5, -8.6), 0.25,
                             flat(["plastic", "metal", "stain"][k], 1.2)))
    prims.append(box((12.0, 25.9, 4.0), (5.0, 0.7, 6.0), flat("oxblood", 0.9), basis=basis_rot(ry=-0.2)))
    if state == 0:
        prims.append(box((18.0, 19.5, 11.1), (10.2, 3.0, 0.15), painted("enamel", 69, bright=1.06)))
        prims += handle_h(18.0, 20.5, 11.25, 2.4, 0.4)
    else:
        prims.append(box((18.0, 18.2, 16.0), (10.0, 0.3, 5.0), ENAMEL))
        for x in (8.2, 27.8):
            prims.append(box((x, 19.6, 16.0), (0.3, 1.6, 5.0), ENAMEL))
        prims.append(box((18.0, 19.6, 21.0), (10.2, 2.2, 0.3), painted("enamel", 69, bright=1.06)))
        prims += handle_h(18.0, 20.0, 21.3, 2.4, 0.4)
        prims.append(box((18.0, 18.6, 16.0), (9.6, 0.05, 4.6), flat("dark", 0.9)))
        if state == 1:
            prims += papers(random.Random(70), 3, 13, 23, 14, 18, 18.7, (3.0, 3.6))
            prims.append(capsule((12.0, 19.2, 19.0), (16.0, 19.2, 18.0), 0.35, flat("plastic", 1.2)))
            prims.append(box((22.5, 19.4, 13.5), (1.6, 0.5, 1.0), flat("brass_d", 1.1, 0.8)))
        else:
            prims.append(sphere((14.0, 18.8, 17.0), 0.4, flat("metal", 1.2)))
            prims.append(sphere((21.0, 18.8, 19.5), 0.35, flat("metal", 1.0)))
    return prims


def workbench(state: int) -> list:
    """Banco de taller: tablero grueso de madera gastada, tornillo de banco, cajones y balda baja."""
    rng = random.Random(81)
    prims = [box((0.0, 23.5, 0.0), (30.0, 1.8, 12.0), wood(82, 0.95))]
    for x in (-28.0, 28.0):
        for z in (-10.0, 10.0):
            prims.append(box((x, 11.0, z), (1.2, 11.0, 1.2), painted("machine", 83)))
    prims.append(box((0.0, 6.0, 0.0), (28.5, 0.6, 10.5), wood(84, 0.8)))  # balda
    for i, x in enumerate((-22.0, -14.0)):  # cajas y latas en la balda
        prims.append(box((x, 9.5, -2.0), (3.5, 3.0, 4.0), cardboard(85 + i)))
    prims.append(cylinder((-6.0, 6.6, 2.0), (-6.0, 11.5, 2.0), 2.4, painted("oxblood", 87)))
    prims.append(cylinder((-1.0, 6.6, 0.0), (-1.0, 10.0, 0.0), 2.0, painted("galv", 88)))
    # Cajonera bajo el tablero, a la derecha.
    prims.append(box((18.0, 18.0, 0.0), (9.0, 3.6, 11.0), painted("machine", 89)))
    # Tornillo de banco.
    prims.append(box((-22.0, 26.8, 9.0), (3.5, 1.6, 2.6), painted("galv", 90, rust=0.55)))
    prims.append(box((-22.0, 26.8, 12.6), (3.5, 1.6, 0.8), painted("galv", 91, rust=0.55)))
    prims.append(capsule((-22.0, 26.8, 13.4), (-22.0, 26.8, 17.0), 0.5, CHROME))
    prims.append(capsule((-25.0, 26.8, 17.0), (-19.0, 26.8, 17.0), 0.4, CHROME))
    # Herramientas y trapos encima.
    prims.append(capsule((-6.0, 25.6, 4.0), (2.0, 25.6, 6.0), 0.6, flat("oxblood", 1.0)))
    prims.append(capsule((2.0, 25.6, 6.0), (5.0, 25.6, 6.8), 0.35, CHROME))
    prims.append(box((8.0, 25.7, -6.0), (1.0, 0.5, 4.5), CHROME, basis=basis_rot(ry=0.8)))
    prims.append(ellipsoid((14.0, 26.0, 2.0), (4.0, 0.9, 3.0), fabric("stain", 92, folds=0.6)))
    for _ in range(7):
        prims.append(sphere((rng.uniform(-14, 22), 25.5, rng.uniform(-9, 9)), 0.45, flat("metal", 1.1, 0.6)))
    prims.append(box((-12.0, 26.6, -6.0), (3.0, 1.2, 2.5), painted("oxblood", 93)))  # caja de herramientas
    if state == 0:
        prims.append(box((18.0, 18.0, 11.1), (8.4, 3.0, 0.2), painted("machine", 94, bright=1.1)))
        prims += handle_h(18.0, 18.2, 11.3, 2.4, 0.4)
    else:
        prims.append(box((18.0, 16.6, 16.0), (8.2, 0.3, 5.0), painted("machine", 95)))
        for x in (10.0, 26.0):
            prims.append(box((x, 18.0, 16.0), (0.3, 1.6, 5.0), painted("machine", 96)))
        prims.append(box((18.0, 18.0, 21.0), (8.4, 2.4, 0.3), painted("machine", 94, bright=1.1)))
        prims += handle_h(18.0, 18.4, 21.3, 2.4, 0.4)
        prims.append(box((18.0, 17.0, 16.0), (7.8, 0.05, 4.6), flat("dark", 0.9)))
        if state == 1:
            prims += papers(random.Random(97), 1, 14, 16, 15, 17, 17.1, (3.4, 4.2))  # libreta
            prims.append(box((22.0, 17.6, 15.0), (2.0, 0.6, 3.0), flat("plastic", 0.9)))
    return prims


# --- archivador ------------------------------------------------------------------------------------

def filing_cabinet(state: int) -> list:
    body = painted("enamel_green", 101, rust=0.7, dent=0.5)
    prims = [box((0.0, 22.5, 0.0), (9.0, 21.5, 9.0), body)]
    prims.append(box((0.0, 44.2, 0.0), (9.2, 0.4, 9.2), painted("enamel_green", 102, bright=1.1)))
    prims.append(cylinder((6.5, 41.8, 9.0), (6.5, 41.8, 9.6), 0.7, CHROME))  # cerradura
    for i, y in enumerate((8.0, 18.5, 29.0, 39.0)):
        if state > 0 and i == 3:
            continue
        prims.append(box((0.0, y - 4.0, 9.08), (8.3, 0.25, 0.1), DARK))
        prims.append(box((0.0, y, 9.15), (8.2, 4.6, 0.12), painted("enamel_green", 103 + i, bright=1.07)))
        prims.append(box((0.0, y + 2.2, 9.35), (2.0, 0.9, 0.1), LABEL))
        prims.append(box((0.0, y + 2.2, 9.42), (2.3, 1.1, 0.05), flat("chrome", 0.7, 0.6)))
        prims += handle_h(0.0, y - 0.6, 9.3, 2.2, 0.4)
    if state > 0:
        y = 39.0
        prims.append(box((0.0, 35.6, 15.5), (8.0, 0.3, 6.5), body))
        for x in (-8.0, 8.0):
            prims.append(box((x, 38.0, 15.5), (0.3, 2.6, 6.5), body))
        prims.append(box((0.0, y - 0.8, 22.1), (8.2, 4.4, 0.3), painted("enamel_green", 106, bright=1.07)))
        prims.append(box((0.0, y + 1.4, 22.5), (2.0, 0.9, 0.1), LABEL))
        prims += handle_h(0.0, y - 2.0, 22.4, 2.2, 0.4)
        prims.append(box((0.0, 36.0, 15.5), (7.6, 0.05, 6.2), flat("dark", 0.9)))
        for x in (-7.4, 7.4):  # carriles de las carpetas colgantes
            prims.append(capsule((x, 40.4, 9.5), (x, 40.4, 21.5), 0.3, CHROME))
        if state == 1:
            rng = random.Random(107)
            for i in range(6):
                z = 10.5 + i * 2.0
                col = rng.choice(["label_w", "stain", "cardboard"])
                prims.append(box((0.0, 38.6, z), (7.6, 2.6, 0.35), flat(col, rng.uniform(0.85, 1.1)), basis=basis_rot(rx=rng.uniform(-0.2, 0.2))))
                prims.append(box((rng.uniform(-5, 5), 41.4, z), (1.0, 0.4, 0.3), flat("plastic", 1.2)))
        else:
            prims.append(box((0.0, 36.6, 18.0), (6.6, 0.4, 0.3), flat("label_w", 0.8), basis=basis_rot(rx=1.2)))
    return prims


# --- estantería -------------------------------------------------------------------------------------

def shelf(frame: int) -> list:
    bottles = frame in (1, 3)
    sparse = frame >= 2
    post = painted("galv", 111, rust=0.66)
    prims = []
    for x in (-29.0, 29.0):
        for z in (-5.0, 5.0):
            prims.append(box((x, 29.5, z), (0.7, 29.5, 0.7), post))
            prims.append(box((x, 0.4, z), (1.2, 0.4, 1.2), RUBBER))
    rng = random.Random(112 if bottles else 113)
    levels = (3.0, 20.5, 38.0, 55.5)
    for li, y in enumerate(levels):
        sag = 0.6 if li == 2 else 0.0
        prims.append(box((0.0, y - sag * 0.5, 0.0), (29.5, 0.6, 5.6), painted("galv", 114 + li, rust=0.7)))
        prims.append(box((0.0, y - 0.4, 5.7), (29.5, 1.0, 0.2), painted("galv", 118 + li, rust=0.6)))
        x = -26.0
        while x < 25.0:
            skip = rng.random()
            if skip < (0.62 if sparse else 0.18):
                x += rng.uniform(4.0, 9.0)
                continue
            if bottles:
                kind = rng.choice(["amber", "amber", "green", "white", "clear"])
                h = rng.uniform(4, 9)
                r = rng.uniform(1.3, 2.3)
                prims += bottle(x, y + 0.6, rng.uniform(-2.5, 2.5), h, r, kind)
                if rng.random() < 0.15:  # frasco tumbado
                    prims.append(capsule((x + 2, y + 1.9, 2.0), (x + 7, y + 1.9, 3.0), 1.3, noisy("amber", 119, 0.2)))
                    x += 5
                x += 2 * r + rng.uniform(0.6, 2.0)
            else:
                w, h = rng.uniform(5, 9), rng.uniform(6, 13)
                kind = rng.random()
                if kind < 0.6:
                    prims.append(box((x + w / 2, y + 0.6 + h / 2, rng.uniform(-0.8, 0.8)), (w / 2, h / 2, 4.6), cardboard(120 + int(x))))
                    prims.append(box((x + w / 2, y + 0.6 + h * 0.6, 4.75), (w * 0.3, 1.2, 0.05), LABEL))
                    if rng.random() < 0.4:  # cinta de embalar
                        prims.append(box((x + w / 2, y + 0.6 + h, 0.0), (0.7, 0.06, 4.6), flat("plastic_yellow", 0.8)))
                elif kind < 0.85:  # archivadores de lomo
                    for k in range(int(w // 2)):
                        prims.append(box((x + 1 + k * 2.0, y + 0.6 + 5.5, 0.0), (0.9, 5.5, 4.0),
                                         flat(rng.choice(["oxblood", "felt", "label_w", "enamel_green"]), rng.uniform(0.85, 1.1))))
                else:  # papeles apilados
                    prims += papers(rng, 4, x + 2, x + w - 2, -2, 2, y + 0.7, (3.0, 4.0))
                x += w + rng.uniform(0.4, 1.8)
    if sparse:  # lo que se ha sacado queda en el suelo
        prims += papers(random.Random(121), 2, -10, 10, 6, 10, 0.2)
    return prims


# --- botiquín de pared ---------------------------------------------------------------------------------

def med_cabinet(state: int) -> list:
    body = painted("enamel", 131, rust=0.78, grime_h=0.0)
    prims = [box((0.0, 42.0, -6.5), (12.0, 12.5, 0.5), body)]  # fondo
    for x in (-11.6, 11.6):
        prims.append(box((x, 42.0, -3.0), (0.4, 12.5, 3.5), body))
    for y in (29.9, 54.1):
        prims.append(box((0.0, y, -3.0), (12.0, 0.4, 3.5), body))
    rng = random.Random(132)
    for y in (32.0, 41.0, 49.0):
        prims.append(box((0.0, y - 0.6, -3.5), (11.0, 0.25, 3.0), GLASS))
        n = 4 if state < 2 else 2
        for i in range(n):
            x = -8.0 + i * (16.0 / max(1, n - 1)) + rng.uniform(-0.8, 0.8)
            prims += bottle(x, y - 0.35, -4.0 + rng.uniform(-0.6, 0.6), rng.uniform(3, 5), rng.uniform(1.0, 1.5),
                            rng.choice(["amber", "white", "green"]))
    prims.append(box((0.0, 56.5, -6.2), (2.2, 0.6, 0.2), flat("red_cross", 0.9)))  # cruz pintada (medio despegada)
    prims.append(box((0.0, 56.5, -6.1), (0.6, 2.0, 0.2), flat("red_cross", 0.8)))
    door_mats = [box((0.0, 42.0, 0.0), (11.8, 12.4, 0.25), GLASS)]
    for y in (29.8, 54.2):
        door_mats.append(box((0.0, y, 0.3), (12.0, 0.6, 0.4), body))
    for x in (-11.6, 11.6):
        door_mats.append(box((x, 42.0, 0.3), (0.6, 12.6, 0.4), body))
    door_mats.append(box((10.0, 42.0, 0.9), (0.5, 2.2, 0.4), CHROME))
    door_mats.append(box((10.0, 39.0, 0.8), (0.8, 0.8, 0.3), flat("brass_d", 1.0, 0.6)))
    if state == 0:
        prims += door_mats
    else:
        prims += transform(transform(door_mats, basis_rot(), (12.0, 0.0, 0.0)), basis_rot(ry=-1.9), (-12.0, 0.0, 0.0))
        prims.append(box((0.0, 42.0, -5.9), (11.0, 12.0, 0.05), flat("dark", 0.8)))
        prims.append(capsule((6.5, 50.0, -5.9), (6.5, 50.0, -4.6), 0.35, CHROME))  # gancho
        if state == 1:
            prims.append(capsule((6.5, 49.6, -4.8), (6.5, 45.0, -4.6), 0.35, flat("brass_d", 1.2, 0.8)))
            prims.append(sphere((6.5, 44.4, -4.6), 0.9, flat("brass_d", 1.1, 0.8)))
    return prims


# --- mostrador / encimera ------------------------------------------------------------------------------

def counter(state: int) -> list:
    """Mueble bajo con tres puertas y encimera. La encimera queda a 27.4 (el teléfono se apoya ahí)."""
    rng = random.Random(141)
    body = painted("enamel", 142, grime_h=5.0, dent=0.4)
    prims = [box((0.0, 13.6, -2.0), (30.0, 12.4, 10.0), body)]
    prims.append(box((0.0, 0.7, 7.0), (29.6, 0.7, 0.8), flat("dark", 1.0)))  # zócalo
    prims.append(box((0.0, 26.6, -2.0), (31.0, 0.8, 11.0), noisy("formica", 143, 0.3)))
    prims.append(box((0.0, 26.6, 9.05), (31.0, 0.8, 0.1), CHROME))
    for i, x in enumerate((-20.0, 0.0, 20.0)):
        opened = state > 0 and i == 1
        if opened:
            prims.append(box((x, 13.4, 8.0), (9.0, 11.0, 0.05), flat("dark", 0.9)))
            prims.append(box((x, 13.0, 1.0), (9.0, 0.3, 7.0), body))  # balda
            prims += transform([box((4.6, 13.4, 0.0), (4.6, 11.0, 0.3), painted("enamel", 145, bright=1.07))],
                               basis_rot(ry=-1.6), (x - 9.0, 0.0, 8.4))
            if state == 1:
                prims += papers(random.Random(146), 3, x - 5, x + 5, 2, 6, 13.4, (3.4, 2.4))
                prims += bottle(x - 5.0, 13.3, 3.0, 4.0, 1.3, "amber")
                prims.append(box((x + 4.0, 15.5, 3.0), (3.0, 2.2, 2.4), cardboard(147)))
                prims.append(box((x, 23.0, 4.0), (6.0, 0.6, 2.0), flat("linen", 1.0)))  # algo colgado de la puerta
        else:
            prims.append(box((x, 13.4, 8.15), (9.4, 11.4, 0.2), painted("enamel", 148 + i, bright=1.06)))
            prims.append(box((x + 6.6, 19.0, 8.55), (0.45, 2.4, 0.35), CHROME))
    # Encima: carpetas, una taza con café helado, papeles, un cuaderno de registro.
    prims += papers(rng, 4, -26, 8, -10, 4, 27.5)
    prims.append(cylinder((-20.0, 27.4, -6.0), (-20.0, 30.8, -6.0), 1.8, flat("porcelain", 1.0, 0.6)))
    prims.append(cylinder((-20.0, 30.2, -6.0), (-20.0, 30.82, -6.0), 1.4, flat("dark", 1.0)))
    prims.append(box((14.0, 28.4, -8.0), (6.0, 1.0, 3.5), flat("oxblood", 0.9), basis=basis_rot(ry=0.15)))
    prims.append(box((14.0, 29.5, -8.0), (5.6, 0.2, 3.1), flat("felt", 1.0), basis=basis_rot(ry=0.15)))
    return prims


# --- cuadro eléctrico ------------------------------------------------------------------------------------

def elec_panel(state: int) -> list:
    """0 cerrado, 1 abierto averiado (cables sueltos, sin fusible), 2 bornas apretadas, 3 con el fusible."""
    body = painted("machine", 151, rust=0.7, grime_h=0.0, dent=0.4)
    prims = [box((0.0, 36.0, -8.6), (13.5, 17.0, 0.6), body)]
    for x in (-13.1, 13.1):
        prims.append(box((x, 36.0, -5.4), (0.4, 17.0, 3.2), body))
    for y in (19.4, 52.6):
        prims.append(box((0.0, y, -5.4), (13.5, 0.4, 3.2), body))
    # Conductos que bajan del techo hasta el cuadro.
    for i, x in enumerate((-8.0, -3.0, 7.0)):
        prims.append(cylinder((x, 53.0, -6.0), (x, 92.0, -6.0), 1.2 if i < 2 else 1.6, GALV))
        prims.append(cylinder((x, 52.6, -6.0), (x, 54.4, -6.0), 1.7 if i < 2 else 2.1, CHROME))
    door = [box((0.0, 36.0, 0.0), (13.2, 16.6, 0.3), painted("machine", 152, rust=0.66, dent=0.5))]
    door.append(box((0.0, 46.0, 0.35), (4.0, 3.2, 0.05), flat("hazard", 1.0)))  # aviso
    door.append(box((0.0, 46.6, 0.42), (0.5, 1.6, 0.05), flat("dark", 1.0)))
    door.append(box((0.0, 44.0, 0.42), (0.5, 0.4, 0.05), flat("dark", 1.0)))
    door.append(box((0.0, 39.0, 0.38), (6.0, 1.0, 0.05), LABEL))  # «F1 — ALTA TENSIÓN»
    door.append(box((10.5, 34.0, 0.7), (0.8, 3.0, 0.5), CHROME))
    door.append(cylinder((10.5, 30.0, 0.3), (10.5, 30.0, 0.9), 1.0, flat("dark", 1.0)))
    if state == 0:
        prims += transform(door, basis_rot(), (0.0, 0.0, -2.2))
        return prims
    prims += transform(transform(door, basis_rot(), (13.2, 0.0, 0.0)), basis_rot(ry=-1.75), (-13.2, 0.0, -2.2))
    prims.append(box((0.0, 36.0, -7.9), (12.6, 16.2, 0.05), flat("dark", 1.0)))
    prims.append(box((0.0, 36.0, -7.6), (10.0, 13.0, 0.25), flat("bakelite", 0.9)))  # placa de montaje
    for row, y in enumerate((45.0, 39.0)):  # interruptores
        for i in range(6):
            x = -7.5 + i * 3.0
            prims.append(box((x, y, -6.9), (1.2, 2.4, 0.9), flat("plastic", 1.15)))
            prims.append(box((x, y + (0.8 if (i + row) % 3 else -0.8), -5.8), (0.5, 0.8, 0.4), flat("dark", 1.0)))
    for y in (33.5, 31.5, 29.5):  # barras de cobre
        prims.append(box((-3.0, y, -6.8), (7.5, 0.45, 0.4), flat("brass_d", 1.1, 0.9)))
    prims.append(box((7.0, 30.5, -6.6), (2.4, 5.0, 1.0), flat("porcelain", 0.8)))  # portafusible F1
    prims.append(box((7.0, 30.5, -5.5), (1.4, 3.6, 0.2), flat("dark", 1.0)))
    if state == 3:
        prims.append(cylinder((7.0, 26.8, -4.6), (7.0, 34.2, -4.6), 1.3, flat("porcelain", 1.15, 0.6)))
        for y in (26.8, 34.2):
            prims.append(cylinder((7.0, y - 0.6, -4.6), (7.0, y + 0.6, -4.6), 1.4, flat("brass_d", 1.1, 0.9)))
    if state == 1:
        for i, (end, col) in enumerate((((-9.0, 18.0, 2.0), "oxblood"), ((-4.0, 21.0, 4.0), "metal"), ((1.0, 17.0, 3.0), "felt"))):
            start = (-6.0 + i * 3.0, 28.5, -6.0)
            mid = ((start[0] + end[0]) / 2, 22.0, (start[2] + end[2]) / 2)
            prims += limb([start, mid, end], [0.5, 0.5, 0.5], flat(col, 0.9), 2)
            prims.append(sphere(end, 0.7, flat("brass_d", 1.2, 0.9)))
        prims.append(box((-2.0, 26.0, -6.4), (4.0, 1.2, 0.5), metal_worn))  # bornero suelto
    else:
        for i in range(3):
            prims.append(capsule((-6.0 + i * 3.0, 28.5, -6.0), (-6.0 + i * 3.0, 25.0, -6.0), 0.5,
                                 flat(["oxblood", "metal", "felt"][i], 0.9)))
        prims.append(box((-3.0, 24.6, -6.2), (5.0, 1.0, 0.6), metal_worn))
    return prims


# --- generador -------------------------------------------------------------------------------------------

def generator(on: bool) -> list:
    """Grupo electrógeno sobre bancada: motor, alternador, radiador, depósito, cuadro y escape."""
    yellow = painted("hazard", 161, rust=0.72, chips=0.86, dent=0.5, grime_h=8.0)
    prims = [box((0.0, 2.0, 0.0), (28.0, 2.0, 15.0), painted("galv", 162, rust=0.6))]
    for x in (-25.0, 25.0):
        prims.append(box((x, 2.0, 15.4), (2.0, 2.0, 0.4), flat("dark", 1.0)))
    prims.append(box((-6.0, 15.0, 0.0), (16.0, 11.0, 11.0), yellow))  # motor
    for i in range(6):  # aletas
        prims.append(box((-18.0 + i * 4.8, 26.6, 0.0), (1.4, 0.8, 10.0), painted("galv", 163)))
    prims.append(box((18.0, 15.0, 0.0), (7.0, 11.0, 10.0), painted("machine", 164)))  # alternador
    for y in (8.0, 11.0, 14.0, 17.0, 20.0):  # rejilla
        prims.append(box((18.0, y, 10.1), (5.5, 0.5, 0.1), flat("dark", 1.0)))
    prims.append(box((-24.0, 15.0, 0.0), (3.0, 12.0, 12.0), painted("galv", 165)))  # radiador
    for z in range(-10, 11, 3):
        prims.append(box((-27.1, 15.0, z), (0.1, 10.0, 0.6), flat("dark", 1.0)))
    prims.append(cylinder((-14.0, 26.0, -8.0), (-14.0, 38.0, -8.0), 2.2, GALV))  # escape
    prims.append(capsule((-14.0, 38.0, -8.0), (-14.0, 40.0, -12.0), 2.2, GALV))
    prims.append(cylinder((-14.0, 30.0, -8.0), (-14.0, 34.0, -8.0), 3.0, flat("rust", 0.9)))  # silenciador
    # Depósito de gasóleo con su tapón.
    prims.append(box((4.0, 30.0, -4.0), (8.0, 3.5, 6.0), painted("oxblood", 166)))
    prims.append(cylinder((8.0, 33.5, -6.0), (8.0, 35.0, -6.0), 1.4, CHROME))
    # Cuadro de mando con manómetro y piloto.
    prims.append(box((18.0, 32.0, 6.0), (6.0, 6.0, 2.0), painted("machine", 167)))
    prims.append(cylinder((15.5, 33.0, 8.0), (15.5, 33.0, 8.6), 2.0, flat("porcelain", 1.1)))
    prims.append(capsule((15.5, 33.0, 8.7), (16.6, 34.2, 8.7), 0.25, flat("dark", 1.0)))
    prims.append(sphere((21.0, 35.0, 8.2), 0.9, flat("!led_green", 0.9) if on else flat("red_off", 0.6)))
    prims.append(capsule((21.0, 30.5, 8.2), (21.0, 28.5, 10.5), 0.6, flat("oxblood", 1.0)))  # palanca de arranque
    prims.append(sphere((21.0, 28.4, 10.6), 1.0, flat("dark", 1.2)))
    # Asiento de la válvula (hueco con la rosca a la vista).
    prims.append(cylinder((6.0, 20.0, 11.0), (6.0, 20.0, 13.0), 3.2, painted("galv", 168)))
    prims.append(cylinder((6.0, 20.0, 12.9), (6.0, 20.0, 13.1), 2.2, flat("dark", 1.0)))
    # Cables y manguera de combustible.
    prims += limb([(24.0, 22.0, 0.0), (28.0, 14.0, 6.0), (30.0, 4.0, 12.0)], [0.6, 0.6, 0.6], flat("cable", 0.9), 2)
    return prims


# --- grabadora, papelera, carro de lavandería, cajas, caldera, morgue ---------------------------------------

def tape_recorder() -> list:
    """Magnetófono de bobinas sobre un carrito con ruedas, con el micro colgando."""
    prims = []
    for x in (-8.0, 8.0):
        for z in (-6.0, 6.0):
            prims.append(box((x, 9.0, z), (0.6, 8.0, 0.6), CHROME))
            prims += caster(x, z, 0.9)
    prims.append(box((0.0, 6.0, 0.0), (8.6, 0.5, 6.6), painted("galv", 171)))
    prims.append(box((0.0, 17.4, 0.0), (9.0, 0.6, 7.0), painted("galv", 172)))
    prims.append(box((0.0, 21.0, -0.5), (9.0, 3.0, 6.0), painted("felt", 173, rust=0.95, chips=0.95)))
    prims.append(box((0.0, 24.1, -0.5), (8.6, 0.1, 5.6), flat("bakelite", 1.0)))
    for x in (-4.4, 4.4):
        prims.append(cylinder((x, 24.1, -2.0), (x, 24.9, -2.0), 3.4, flat("metal", 1.1, 0.8)))
        prims.append(cylinder((x, 24.9, -2.0), (x, 25.2, -2.0), 2.6, flat("tape", 1.0)))
        prims.append(cylinder((x, 25.2, -2.0), (x, 25.5, -2.0), 0.7, CHROME))
    prims.append(box((0.0, 24.3, 2.5), (2.0, 0.3, 1.0), CHROME))  # cabezal
    for i in range(4):
        prims.append(box((-5.0 + i * 2.4, 22.0, 5.6), (0.9, 0.7, 0.3), flat("porcelain", 1.0)))
    prims.append(box((5.5, 22.2, 5.55), (1.8, 1.0, 0.1), flat("hazard", 0.6)))  # vúmetro
    prims.append(sphere((7.6, 22.4, 5.6), 0.6, flat("!led_red", 0.9)))
    prims += limb([(-9.0, 20.0, 3.0), (-11.5, 14.0, 6.0), (-10.0, 6.0, 9.0), (-6.0, 1.2, 11.0)], [0.35] * 4, flat("cable", 1.0), 2)
    prims.append(capsule((-6.0, 1.2, 11.0), (-3.0, 1.2, 12.5), 1.1, CHROME))  # micro en el suelo
    prims.append(box((0.0, 7.0, 0.0), (6.0, 0.6, 4.0), noisy("tape", 174, 0.3)))  # cajas de cinta abajo
    return prims


def trash_bin(frame: int) -> list:
    """Cubo de pedal. 0 lleno de gasas, 1 revuelto (gasas por el suelo)."""
    body = painted("enamel", 181, rust=0.7, grime_h=4.0)
    prims = [cylinder((0.0, 0.6, 0.0), (0.0, 15.0, 0.0), 6.5, body)]
    prims.append(cylinder((0.0, 0.0, 0.0), (0.0, 0.8, 0.0), 6.9, flat("dark", 1.0)))
    prims.append(cylinder((0.0, 14.6, 0.0), (0.0, 15.2, 0.0), 6.9, CHROME))
    prims.append(box((0.0, 1.0, 7.2), (2.0, 0.4, 1.2), CHROME))  # pedal
    prims += transform([cylinder((0.0, 0.0, 0.0), (0.0, 0.6, 0.0), 6.8, body)], basis_rot(rx=-0.35), (0.0, 16.6, -7.2))  # tapa entreabierta
    from props import gauze_mat
    rng = random.Random(182)
    n = 6 if frame == 0 else 2
    for _ in range(n):
        c = (rng.uniform(-4, 4), rng.uniform(15.0, 17.5), rng.uniform(-3, 4))
        prims.append(ellipsoid(c, (rng.uniform(1.8, 3.0), rng.uniform(1.2, 2.0), rng.uniform(1.8, 3.0)), gauze_mat))
    if frame == 1:
        for c in ((-8.5, 1.0, 6.0), (8.0, 0.9, 7.5), (2.0, 1.0, 10.5)):
            prims.append(ellipsoid(c, (2.4, 1.0, 2.0), gauze_mat, basis=basis_rot(ry=rng.uniform(0, 3))))
    else:
        prims.append(ellipsoid((6.5, 12.0, 2.0), (1.2, 3.5, 1.8), gauze_mat))
    return prims


def laundry_cart(frame: int) -> list:
    """Carro de lona sobre bastidor. 0 lleno, 1 revuelto (sábanas colgando y en el suelo)."""
    prims = []
    for x in (-10.0, 10.0):
        for z in (-8.0, 8.0):
            prims.append(capsule((x, 3.0, z), (x, 25.0, z), 0.6, GALV))
            prims += caster(x, z, 1.1)
        prims.append(capsule((x, 25.0, -8.0), (x, 25.0, 8.0), 0.6, GALV))
    for z in (-8.0, 8.0):
        prims.append(capsule((-10.0, 25.0, z), (10.0, 25.0, z), 0.6, GALV))
    prims.append(box((0.0, 15.0, 0.0), (9.6, 9.8, 7.6), fabric("canvas", 191, folds=0.3, stain=0.66, dirty_h=10.0)))
    rng = random.Random(192)
    n = 6 if frame == 0 else 3
    for _ in range(n):
        prims.append(ellipsoid((rng.uniform(-6, 6), 25.5 if frame == 0 else 23.0, rng.uniform(-5, 5)), (4.2, 2.2, 4.0),
                               make_sheet((0.0, 25.0, 0.0), 3.0 if rng.random() < 0.4 else 0.0, 0.45)))
    prims.append(box((-3.0, 22.0, 8.2), (2.0, 1.6, 0.1), LABEL))  # etiqueta prendida
    if frame == 1:
        prims.append(box((10.6, 17.0, 2.0), (0.5, 8.0, 5.0), make_sheet(folds=0.5), basis=basis_rot(rz=0.15)))
        prims.append(ellipsoid((14.0, 1.2, 9.0), (5.0, 1.2, 4.0), make_sheet((14.0, 1.0, 9.0), 2.0, 0.5)))
    return prims


def crates() -> list:
    prims = [box((0.0, 7.5, 0.0), (11.0, 7.5, 9.5), cardboard(201))]
    prims.append(box((0.0, 15.05, 0.0), (11.0, 0.08, 1.1), flat("plastic_yellow", 0.8)))
    prims.append(box((0.0, 9.0, 9.55), (5.0, 2.6, 0.05), LABEL))
    prims.append(box((0.0, 5.0, 9.6), (3.0, 0.3, 0.05), flat("ink_d", 1.0)))
    prims.append(box((2.0, 21.0, -1.0), (8.0, 6.0, 7.0), cardboard(202, 1.05), basis=basis_rot(ry=0.18)))
    prims.append(box((2.0, 27.05, -1.0), (8.0, 0.08, 1.0), flat("plastic_yellow", 0.8), basis=basis_rot(ry=0.18)))
    # Solapa abierta de la caja de arriba.
    prims.append(box((2.0, 27.6, 7.0), (7.6, 0.2, 2.0), cardboard(203, 1.1), basis=basis_rot(rx=-0.9, ry=0.18)))
    return prims


def boiler() -> list:
    shell = painted("galv", 211, rust=0.64, dent=0.3)
    prims = [cylinder((0.0, 2.0, 0.0), (0.0, 56.0, 0.0), 11.0, shell)]
    prims.append(sphere((0.0, 56.0, 0.0), 11.0, shell))
    prims.append(cylinder((0.0, 0.0, 0.0), (0.0, 2.0, 0.0), 12.0, flat("dark", 1.0)))
    for y in (14.0, 30.0, 46.0):
        prims.append(cylinder((0.0, y, 0.0), (0.0, y + 1.2, 0.0), 11.5, flat("rust", 1.0)))
    for y in range(6, 54, 6):  # remaches
        prims.append(sphere((-10.6, y, 3.0), 0.5, CHROME))
    prims.append(capsule((11.0, 40.0, 0.0), (16.0, 40.0, 0.0), 1.8, GALV))
    prims.append(capsule((16.0, 40.0, 0.0), (16.0, 70.0, -4.0), 1.8, GALV))
    prims.append(cylinder((0.0, 30.0, 11.0), (0.0, 30.0, 12.0), 3.2, CHROME))  # manómetro
    prims.append(cylinder((0.0, 30.0, 12.0), (0.0, 30.0, 12.2), 2.6, flat("porcelain", 1.1)))
    prims.append(capsule((0.0, 30.0, 12.3), (-1.5, 31.4, 12.3), 0.25, flat("oxblood", 1.0)))
    for i in range(8):  # volante de la válvula
        a = i / 8 * math.tau
        prims.append(capsule((-7.0, 20.0 + math.cos(a) * 3.2, 9.5 + math.sin(a) * 0.4), (-7.0, 20.0, 9.5), 0.3, flat("oxblood", 1.0)))
    prims.append(cylinder((-7.0, 20.0, 8.0), (-7.0, 20.0, 9.6), 3.4, flat("oxblood", 0.8)))
    prims.append(box((5.0, 10.0, 9.8), (3.0, 2.0, 0.3), LABEL))
    return prims


def morgue(state: int) -> list:
    """0 cerrada, 1 cajón abierto con un pie y su etiqueta, 2 cajón abierto vacío."""
    shell = steel(221, 0.9)
    prims = [box((0.0, 24.0, -6.0), (30.0, 24.0, 8.0), shell)]
    prims.append(box((0.0, 48.6, -6.0), (30.4, 0.6, 8.4), steel(222, 1.05)))
    prims.append(box((-18.0, 50.6, -10.0), (4.0, 2.4, 2.0), painted("galv", 223)))  # compresor
    for row, y in enumerate((12.0, 34.0)):
        for col, x in enumerate((-19.0, 0.0, 19.0)):
            if state > 0 and row == 0 and col == 1:
                continue
            prims.append(box((x, y, 2.1), (8.6, 8.6, 0.25), steel(224 + row * 3 + col, 1.05)))
            prims.append(box((x, y, 2.0), (9.2, 9.2, 0.1), flat("dark", 1.0)))
            prims.append(box((x + 6.0, y, 2.6), (0.8, 3.0, 0.6), CHROME))
            prims.append(box((x - 3.5, y + 5.6, 2.42), (3.2, 1.2, 0.1), LABEL))
            prims.append(box((x - 3.5, y + 5.6, 2.5), (3.4, 1.4, 0.05), flat("chrome", 0.7, 0.5)))
    prims.append(box((0.0, 17.6, 2.5), (2.4, 0.7, 0.1), flat("ink_d", 1.0)))  # «09» con rotulador
    prims.append(cylinder((24.0, 44.0, 2.1), (24.0, 44.0, 2.8), 2.0, flat("porcelain", 1.0)))  # termómetro
    if state > 0:
        prims.append(box((0.0, 12.0, 2.3), (8.6, 8.6, 0.1), VOID))
        prims.append(box((0.0, 7.6, 14.0), (8.4, 0.8, 12.0), shell))  # bandeja
        for x in (-8.2, 8.2):
            prims.append(capsule((x, 4.0, 2.5), (x, 7.0, 25.5), 0.5, CHROME))
        prims.append(box((0.0, 9.6, 26.2), (8.6, 2.4, 0.6), steel(229, 1.0)))
        prims.append(box((6.0, 9.6, 26.9), (0.8, 1.6, 0.5), CHROME))
        if state == 1:
            prims.append(box((0.0, 9.6, 12.0), (7.6, 1.0, 10.5), make_sheet(folds=0.25)))
            prims.append(ellipsoid((0.0, 12.0, 6.0), (5.0, 2.6, 6.0), make_sheet(folds=0.3)))
            prims.append(ellipsoid((-2.0, 11.0, 24.0), (2.0, 3.0, 2.6), human.skin_mat))
            prims.append(box((-2.0, 13.5, 26.0), (1.5, 0.15, 1.0), flat("label_w", 1.3)))
        else:
            prims.append(box((0.0, 9.0, 14.0), (7.6, 0.6, 10.5), make_sheet((0.0, 9.0, 16.0), 2.0, folds=0.15)))  # sábana doblada
    return prims


# =========================================================================================================
# DECORADO NO INTERACTIVO
# =========================================================================================================

def wheelchair_up(folded: bool = False) -> list:
    """Silla de ruedas de pie, vista de frente (abierta) o plegada contra la pared."""
    prims = []
    half = 4.5 if folded else 9.5
    for side in (-1.0, 1.0):
        c = (side * half, 10.5, -2.0)
        rim = []
        for i in range(17):
            a = i / 16 * math.tau
            rim.append(add(c, (0.0, math.cos(a) * 10.0, math.sin(a) * 10.0)))
        prims += limb(rim, [0.9] * len(rim), RUBBER, steps=1)
        rim2 = [add(c, (side * 0.9, math.cos(i / 16 * math.tau) * 8.6, math.sin(i / 16 * math.tau) * 8.6)) for i in range(17)]
        prims += limb(rim2, [0.35] * len(rim2), CHROME, steps=1)
        for i in range(4):
            a = i / 4 * math.pi
            off = (0.0, math.cos(a) * 9.0, math.sin(a) * 9.0)
            prims.append(capsule(add(c, mul_(off, -1.0)), add(c, off), 0.18, CHROME))
        prims.append(cylinder(add(c, (-0.8, 0.0, 0.0)), add(c, (0.8, 0.0, 0.0)), 1.2, CHROME))
        prims.append(capsule((side * (half - 1.5), 18.0, -8.0), (side * (half - 1.5), 18.0, 8.0), 0.6, CHROME))
        prims.append(capsule((side * (half - 1.5), 18.0, 8.0), (side * (half - 2.5), 3.0, 9.0), 0.55, CHROME))
        prims += caster(side * (half - 2.5), 9.5, 1.6)
        prims.append(capsule((side * (half - 1.5), 18.0, -8.0), (side * (half - 1.5), 35.0, -10.0), 0.6, CHROME))
        prims.append(capsule((side * (half - 1.5), 35.0, -10.0), (side * (half - 1.5), 35.0, -14.0), 0.9, RUBBER))
        prims.append(box((side * (half - 1.5), 24.0, -1.0), (0.8, 0.8, 6.0), flat("vinyl", 1.0)))  # reposabrazos
        prims.append(box((side * (half - 3.5), 2.8, 11.0), (2.4, 0.3, 2.0), CHROME))  # reposapiés
    if not folded:
        prims.append(box((0.0, 18.4, 0.0), (8.0, 0.8, 8.0), fabric("vinyl", 231, folds=0.15, stain=0.66, dirty_h=0)))
        prims.append(box((0.0, 27.0, -9.0), (8.0, 7.6, 0.5), fabric("vinyl", 232, folds=0.15, stain=0.7, dirty_h=0)))
        prims.append(box((0.0, 20.5, 2.0), (6.0, 0.15, 0.8), flat("oxblood", 0.8)))  # correa
    return prims


def mul_(v: Vec, s: float) -> Vec:
    return (v[0] * s, v[1] * s, v[2] * s)


def screen(fallen: bool = False) -> list:
    """Biombo de tres hojas de tela con bastidor de tubo; 1 = tirado en el suelo."""
    prims = []
    cloth = fabric("enamel_green", 241, folds=0.55, stain=0.6, dirty_h=14.0)
    for i, (x, ang) in enumerate(((-17.0, 0.5), (0.0, 0.0), (17.0, -0.5))):
        panel = []
        for px in (-8.0, 8.0):
            panel.append(capsule((px, 2.0, 0.0), (px, 50.0, 0.0), 0.6, CHROME))
        panel.append(capsule((-8.0, 50.0, 0.0), (8.0, 50.0, 0.0), 0.6, CHROME))
        panel.append(capsule((-8.0, 8.0, 0.0), (8.0, 8.0, 0.0), 0.5, CHROME))
        panel.append(box((0.0, 29.0, 0.0), (7.6, 20.0, 0.3), cloth))
        panel += caster(-8.0, 0.0, 1.0) + caster(8.0, 0.0, 1.0)
        z = -3.0 if i != 1 else 0.0
        prims += transform(panel, basis_rot(ry=ang), (x, 0.0, z))
    if fallen:
        return transform(prims, basis_rot(rx=-1.5, ry=0.15), (0.0, 1.5, -20.0))
    return prims


def o2_tank() -> list:
    """Bombona de oxígeno en su carrito, con el manorreductor y la mascarilla colgando."""
    prims = [cylinder((0.0, 3.0, 0.0), (0.0, 34.0, 0.0), 4.0, painted("enamel", 251, rust=0.8, bright=1.05))]
    prims.append(sphere((0.0, 34.0, 0.0), 4.0, painted("machine", 252)))
    prims.append(cylinder((0.0, 37.5, 0.0), (0.0, 41.0, 0.0), 1.2, flat("brass_d", 1.0, 0.8)))
    prims.append(cylinder((0.0, 41.0, 1.0), (0.0, 41.0, 2.5), 2.0, CHROME))  # manómetro
    prims.append(cylinder((0.0, 41.0, 2.5), (0.0, 41.0, 2.7), 1.5, flat("porcelain", 1.1)))
    prims += limb([(1.0, 39.0, 0.0), (5.0, 32.0, 3.0), (6.0, 22.0, 5.0)], [0.35] * 3, flat("tube", 1.0), 2)
    prims.append(ellipsoid((6.0, 20.0, 5.5), (2.0, 2.4, 1.4), GLASS))  # mascarilla
    prims.append(box((0.0, 14.0, 4.0), (3.0, 4.0, 0.1), LABEL))
    # Carrito.
    prims.append(capsule((0.0, 4.0, -5.0), (0.0, 40.0, -6.0), 0.6, GALV))
    prims.append(box((0.0, 2.0, 0.0), (5.0, 0.6, 5.0), GALV))
    for x in (-4.0, 4.0):
        prims += caster(x, -3.0, 1.4)
    return prims


def cart_med() -> list:
    """Carro de medicación con cajones de colores apagados y cosas encima."""
    prims = [box((0.0, 17.0, 0.0), (11.0, 14.0, 9.0), GREEN)]
    for x in (-9.0, 9.0):
        for z in (-7.0, 7.0):
            prims += caster(x, z, 1.4)
    prims.append(box((0.0, 31.4, 0.0), (11.6, 0.6, 9.6), noisy("formica", 261, 0.3)))
    for i in range(5):
        y = 6.5 + i * 5.2
        prims.append(box((0.0, y, 9.1), (10.2, 2.3, 0.15), painted("enamel_green", 262 + i, bright=1.1)))
        prims.append(box((0.0, y + 0.8, 9.3), (2.0, 0.4, 0.2), CHROME))
        prims.append(box((-7.0, y + 0.6, 9.3), (2.0, 0.9, 0.1), LABEL))
    prims.append(capsule((-11.6, 30.0, -6.0), (-11.6, 30.0, 6.0), 0.5, CHROME))  # asa
    prims.append(box((12.6, 22.0, 0.0), (1.4, 8.0, 4.0), flat("oxblood", 0.8)))  # contenedor de agujas
    rng = random.Random(267)
    prims += papers(rng, 2, -6, 6, -5, 5, 32.1)
    for i in range(4):
        prims += bottle(-7.0 + i * 3.2, 32.0, -5.0 + (i % 2) * 2.0, rng.uniform(2.5, 4.0), 1.0, rng.choice(["amber", "white"]))
    prims.append(box((6.0, 32.6, 3.0), (3.0, 0.6, 2.0), flat("metal", 1.1, 0.8)))
    return prims


def cart_instr() -> list:
    """Mesa auxiliar de instrumental: dos bandejas de acero, paños y frascos."""
    prims = []
    for x in (-10.0, 10.0):
        for z in (-6.0, 6.0):
            prims.append(capsule((x, 3.0, z), (x, 24.0, z), 0.6, CHROME))
            prims += caster(x, z, 1.1)
    for y in (10.0, 24.0):
        prims.append(box((0.0, y, 0.0), (11.0, 0.5, 7.0), steel(271 + int(y))))
        prims.append(box((0.0, y + 0.8, 7.0), (11.0, 0.8, 0.2), steel(273)))
    prims.append(box((-3.0, 24.6, 0.0), (6.0, 0.12, 5.0), fabric("cloth_green", 274, folds=0.2, stain=0.6, dirty_h=0)))
    for x in (-7.0, -5.0, -3.0, -1.0):
        prims.append(capsule((x, 24.9, -3.0), (x + 0.5, 24.9, 3.0), 0.3, flat("chrome", 1.2, 1.0)))
    prims.append(cylinder((6.0, 24.5, -2.0), (6.0, 26.5, -2.0), 2.6, steel(275)))  # riñonera / cuenco
    prims.append(cylinder((6.0, 26.0, -2.0), (6.0, 26.55, -2.0), 2.1, flat("blood_dry", 0.9)))
    prims += bottle(7.0, 24.5, 4.0, 4.0, 1.2, "amber")
    prims.append(box((0.0, 11.5, 0.0), (8.0, 1.0, 5.0), cardboard(276)))
    prims.append(ellipsoid((-6.0, 11.4, 2.0), (3.0, 1.0, 2.0), fabric("gauze", 277, folds=0.5, stain=0.5)))
    return prims


def gurney_tipped() -> list:
    """Camilla volcada de lado, con el colchón medio caído."""
    from props import _stretcher_base
    base = _stretcher_base(make_sheet((0.0, 27.0, 4.0), 5.0), "open")
    prims = transform(base, basis_rot(rz=math.pi / 2, ry=math.pi / 2), (0.0, 13.0, 0.0))
    prims.append(box((2.0, 2.0, 18.0), (26.0, 2.0, 9.0), flat("mattress", 0.9), basis=basis_rot(ry=0.12)))
    prims.append(box((0.0, 4.2, 18.0), (24.0, 0.4, 8.0), make_sheet((0.0, 4.0, 18.0), 4.0, 0.4), basis=basis_rot(ry=0.12)))
    return prims


def iv_fallen() -> list:
    from props import iv_stand
    return transform(iv_stand(), basis_rot(rz=-1.5, ry=0.05), (-30.0, 1.5, 2.0))


def boxes(kind: int) -> list:
    """Pilas de cajas: 0 dos cajas, 1 pila alta con una caída, 2 caja abierta con fichas."""
    rng = random.Random(281 + kind)
    prims = []
    if kind == 0:
        prims.append(box((-2.0, 6.0, 0.0), (9.0, 6.0, 7.0), cardboard(282)))
        prims.append(box((3.0, 6.0, 9.0), (6.0, 6.0, 5.0), cardboard(283, 1.05), basis=basis_rot(ry=0.3)))
    elif kind == 1:
        prims.append(box((0.0, 7.0, 0.0), (10.0, 7.0, 8.0), cardboard(284)))
        prims.append(box((1.0, 20.0, -1.0), (9.0, 6.0, 7.0), cardboard(285, 1.05), basis=basis_rot(ry=-0.15)))
        prims.append(box((-1.0, 30.5, -1.5), (7.0, 4.5, 6.0), cardboard(286, 1.1), basis=basis_rot(ry=0.2)))
        prims.append(box((12.0, 5.0, 12.0), (6.0, 5.0, 5.0), cardboard(287, 0.95), basis=basis_rot(rx=0.25, ry=0.8)))
        prims += papers(rng, 4, 4, 20, 14, 22, 0.2)
    else:
        prims.append(box((0.0, 0.5, 0.0), (9.0, 0.5, 7.0), cardboard(288)))
        for x in (-8.7, 8.7):
            prims.append(box((x, 6.0, 0.0), (0.3, 6.0, 7.0), cardboard(289)))
        for z in (-6.7, 6.7):
            prims.append(box((0.0, 6.0, z), (9.0, 6.0, 0.3), cardboard(290)))
        prims.append(box((-12.0, 11.8, 0.0), (3.6, 0.2, 7.0), cardboard(291), basis=basis_rot(rz=0.4)))
        for i in range(8):
            prims.append(box((rng.uniform(-6, 6), 9.0 + rng.uniform(-1, 1), -5.0 + i * 1.4), (5.0, 3.0, 0.2),
                             flat(rng.choice(["label_w", "paper", "stain"]), 1.0), basis=basis_rot(rx=rng.uniform(-0.3, 0.3))))
    return prims


def drum(tipped: bool = False) -> list:
    """Bidón metálico de 200 l, granate y oxidado."""
    body = painted("oxblood", 301, rust=0.6, dent=0.6)
    prims = [cylinder((0.0, 0.0, 0.0), (0.0, 26.0, 0.0), 8.0, body)]
    for y in (8.5, 17.5):
        prims.append(cylinder((0.0, y, 0.0), (0.0, y + 1.0, 0.0), 8.4, painted("oxblood", 302, rust=0.5)))
    prims.append(cylinder((0.0, 25.6, 0.0), (0.0, 26.4, 0.0), 8.3, painted("galv", 303)))
    prims.append(cylinder((4.0, 26.4, -2.0), (4.0, 27.2, -2.0), 1.2, CHROME))
    prims.append(box((0.0, 13.0, 7.9), (3.0, 3.0, 0.2), flat("hazard", 0.8)))
    if tipped:
        prims = transform(prims, basis_rot(rx=math.pi / 2, ry=0.6), (-4.0, 8.4, -20.0))
        prims.append(ellipsoid((8.0, 0.2, 6.0), (9.0, 0.2, 6.0), flat("oil", 0.6)))
    return prims


def pallet() -> list:
    """Palé con sacos (o bolsas) encima."""
    prims = []
    for z in (-11.0, 0.0, 11.0):
        prims.append(box((0.0, 2.0, z), (14.0, 2.0, 1.4), wood(311)))
    for x in range(-12, 13, 4):
        prims.append(box((float(x), 4.4, 0.0), (1.6, 0.4, 13.0), wood(312 + x)))
    rng = random.Random(313)
    for i in range(4):
        prims.append(ellipsoid((rng.uniform(-7, 7), 8.0 + (i // 2) * 5.0, rng.uniform(-5, 5)), (7.0, 3.6, 5.0),
                               fabric("canvas", 314 + i, folds=0.4, stain=0.6, dirty_h=0), basis=basis_rot(ry=rng.uniform(-0.4, 0.4))))
    return prims


def washer() -> list:
    """Lavadora industrial de carga frontal, con el ojo de buey de cristal y agua oscura dentro."""
    body = painted("enamel", 321, rust=0.66, dent=0.4, grime_h=8.0)
    prims = [box((0.0, 20.0, 0.0), (14.0, 20.0, 13.0), body)]
    prims.append(box((0.0, 1.0, 0.0), (13.0, 1.0, 12.0), flat("dark", 1.0)))
    prims.append(box((0.0, 37.0, 13.1), (14.0, 3.0, 0.2), painted("machine", 322)))  # panel
    for i in range(3):
        prims.append(cylinder((-8.0 + i * 5.0, 37.0, 13.3), (-8.0 + i * 5.0, 37.0, 14.2), 1.3, flat("bakelite", 1.1)))
    prims.append(sphere((9.0, 37.0, 13.6), 0.7, flat("red_off", 0.8)))
    prims.append(cylinder((0.0, 20.0, 13.0), (0.0, 20.0, 14.0), 9.0, CHROME))  # marco de la puerta
    prims.append(cylinder((0.0, 20.0, 13.5), (0.0, 20.0, 14.3), 7.4, glass(323, 0.9)))
    prims.append(cylinder((0.0, 20.0, 12.0), (0.0, 20.0, 13.9), 7.0, flat("water_dark", 1.0)))
    prims.append(ellipsoid((-1.0, 16.0, 13.0), (5.0, 2.6, 1.0), make_sheet((0.0, 16.0, 13.0), 2.0, 0.5)))
    prims.append(box((9.5, 20.0, 14.2), (1.0, 3.0, 0.6), CHROME))
    prims += limb([(-12.0, 34.0, -13.0), (-16.0, 20.0, -14.0), (-15.0, 2.0, -10.0), (-10.0, 0.8, -4.0)], [0.9] * 4,
                  flat("rubber", 1.0), 2)  # manguera
    return prims


def dryer() -> list:
    body = painted("enamel", 331, rust=0.7, dent=0.4, grime_h=8.0)
    prims = [box((0.0, 22.0, 0.0), (13.0, 22.0, 12.0), body)]
    prims.append(box((0.0, 1.0, 0.0), (12.0, 1.0, 11.0), flat("dark", 1.0)))
    prims.append(cylinder((0.0, 26.0, 12.0), (0.0, 26.0, 13.0), 8.0, CHROME))
    prims.append(cylinder((0.0, 26.0, 12.6), (0.0, 26.0, 13.3), 6.6, flat("dark", 1.0)))
    for y in (6.0, 8.0, 10.0):  # rejilla del filtro
        prims.append(box((0.0, y, 12.1), (8.0, 0.4, 0.1), flat("dark", 1.0)))
    prims.append(box((0.0, 41.0, 12.1), (11.0, 2.0, 0.2), painted("machine", 332)))
    prims.append(cylinder((6.0, 41.0, 12.3), (6.0, 41.0, 13.0), 1.2, flat("bakelite", 1.1)))
    prims.append(cylinder((0.0, 44.0, -6.0), (0.0, 60.0, -9.0), 3.0, GALV))  # salida de aire
    return prims


def linen_pile() -> list:
    """Montón de sábanas y sacos de ropa sucia en el suelo."""
    rng = random.Random(341)
    prims = []
    for i in range(6):
        c = (rng.uniform(-10, 10), rng.uniform(2.0, 5.0) + (i // 3) * 3.0, rng.uniform(-6, 6))
        prims.append(ellipsoid(c, (rng.uniform(5, 8), rng.uniform(2, 3.5), rng.uniform(4, 6)),
                               make_sheet(c, 2.5 if rng.random() < 0.35 else 0.0, 0.5), basis=basis_rot(ry=rng.uniform(0, 3))))
    prims.append(ellipsoid((9.0, 6.0, -4.0), (5.0, 6.0, 4.5), fabric("canvas", 342, folds=0.4, stain=0.6, dirty_h=3)))
    prims.append(capsule((9.0, 12.0, -4.0), (9.0, 14.0, -4.0), 1.0, fabric("canvas", 343)))
    return prims


def basket() -> list:
    prims = [cylinder((0.0, 0.5, 0.0), (0.0, 12.0, 0.0), 7.5, painted("felt", 351, rust=0.95, chips=0.95),
                      cut=lambda p: p[1] > 1.2 and p[0] ** 2 + p[2] ** 2 < 6.6 ** 2)]
    prims.append(cylinder((0.0, 0.5, 0.0), (0.0, 1.0, 0.0), 6.6, flat("dark", 1.0)))
    for y in (4.0, 8.0):
        prims.append(cylinder((0.0, y, 0.0), (0.0, y + 0.5, 0.0), 7.7, flat("dark", 0.9)))
    prims.append(ellipsoid((0.0, 11.0, 0.0), (6.0, 2.6, 6.0), make_sheet(folds=0.5)))
    prims.append(box((7.0, 8.0, 4.0), (0.4, 4.0, 3.0), make_sheet(folds=0.5), basis=basis_rot(rz=0.3)))
    return prims


def cold_door() -> list:
    """Puerta de cámara frigorífica (de pared), aislada, con la manilla de palanca y escarcha."""
    frame_ = steel(361, 0.9)
    prims = [box((0.0, 34.0, -3.0), (24.0, 34.0, 1.0), frame_)]
    prims.append(box((0.0, 32.0, -1.5), (20.0, 31.0, 1.5), steel(362, 1.05)))
    for y in (8.0, 56.0):  # bisagras
        prims.append(box((-20.5, y, 0.4), (1.2, 3.0, 1.0), CHROME))
    prims.append(box((15.0, 34.0, 0.6), (2.0, 5.0, 1.0), CHROME))
    prims.append(capsule((15.0, 34.0, 1.8), (15.0, 26.0, 3.0), 0.9, flat("dark", 1.2)))
    prims.append(box((0.0, 50.0, 0.1), (6.0, 2.4, 0.1), LABEL))
    prims.append(box((0.0, 46.0, 0.1), (3.0, 0.8, 0.1), flat("hazard", 0.9)))
    rng = random.Random(363)
    for _ in range(10):  # escarcha en el borde
        prims.append(sphere((rng.choice((-20.0, 20.0)) + rng.uniform(-1, 1), rng.uniform(2, 62), 0.2), 0.8, flat("porcelain", 1.25)))
    prims.append(box((0.0, 0.6, 2.0), (20.0, 0.6, 2.0), flat("water_dark", 1.0, 0.8)))
    return prims


def autopsy_table() -> list:
    """Mesa de autopsias de acero con desagüe, sobre pie central; vertical (2 casillas)."""
    s = steel(371, 1.0)
    prims = [cylinder((0.0, 0.0, 0.0), (0.0, 20.0, 0.0), 3.5, steel(372, 0.85))]
    prims.append(box((0.0, 1.0, 0.0), (8.0, 1.0, 10.0), steel(373, 0.8)))
    prims.append(box((0.0, 22.0, 0.0), (10.0, 1.4, 28.0), s,
                     cut=lambda p: p[1] > 22.6 and abs(p[0]) < 8.6 and abs(p[2]) < 26.6))
    prims.append(box((0.0, 22.0, 0.0), (8.6, 0.4, 26.6), steel(374, 0.8)))
    for z in range(-22, 23, 4):  # acanaladuras
        prims.append(box((0.0, 22.45, float(z)), (8.0, 0.05, 0.3), flat("dark", 1.0)))
    prims.append(cylinder((0.0, 22.3, 24.0), (0.0, 22.5, 24.0), 1.4, flat("void", 1.0)))  # desagüe
    prims.append(box((0.0, 22.5, 6.0), (5.0, 0.05, 8.0), flat("blood_dry", 0.8)))
    prims.append(capsule((0.0, 18.0, 26.0), (0.0, 6.0, 30.0), 0.9, flat("rubber", 1.0)))
    prims.append(cylinder((0.0, 0.0, 32.0), (0.0, 5.0, 32.0), 3.0, painted("galv", 375)))  # cubo de desagüe
    prims.append(cylinder((-11.0, 21.0, -26.0), (-11.0, 40.0, -26.0), 0.6, CHROME))  # grifo/ducha
    prims.append(capsule((-11.0, 40.0, -26.0), (-6.0, 40.0, -24.0), 0.6, CHROME))
    return prims


def body_bags() -> list:
    """Bolsas para cadáveres dobladas y apiladas, sin usar, sobre una caja."""
    prims = [box((0.0, 4.0, 0.0), (10.0, 4.0, 7.0), cardboard(381))]
    for i in range(5):
        prims.append(box((0.4 * (i % 2), 8.6 + i * 1.3, 0.0), (8.6, 0.6, 5.6), noisy("felt", 382 + i, 0.25),
                         basis=basis_rot(ry=0.04 * (i - 2))))
        prims.append(box((0.4 * (i % 2), 8.6 + i * 1.3, 5.7), (6.0, 0.25, 0.1), flat("chrome", 0.8, 0.6)))
    prims.append(box((0.0, 15.3, 0.0), (3.0, 0.1, 2.0), LABEL))
    return prims


def tank_h() -> list:
    """Depósito de presión horizontal sobre dos cunas, con manómetro y válvula."""
    shell = painted("galv", 391, rust=0.6, dent=0.3)
    prims = [cylinder((-24.0, 16.0, 0.0), (24.0, 16.0, 0.0), 11.0, shell)]
    for x in (-24.0, 24.0):
        prims.append(ellipsoid((x, 16.0, 0.0), (4.0, 11.0, 11.0), shell))
    for x in (-15.0, 15.0):
        prims.append(box((x, 4.0, 0.0), (2.0, 4.0, 9.0), painted("machine", 392)))
    for x in (-8.0, 8.0):
        prims.append(cylinder((x, 15.6, 0.0), (x, 16.4, 0.0), 11.4, flat("rust", 1.0)))
    prims.append(cylinder((0.0, 27.0, 0.0), (0.0, 31.0, 0.0), 1.4, CHROME))
    prims.append(cylinder((0.0, 31.5, 1.0), (0.0, 31.5, 2.2), 2.2, CHROME))
    prims.append(cylinder((0.0, 31.5, 2.2), (0.0, 31.5, 2.4), 1.7, flat("porcelain", 1.1)))
    prims.append(capsule((20.0, 26.0, 0.0), (20.0, 40.0, -6.0), 1.6, GALV))
    prims.append(box((-6.0, 16.0, 11.1), (4.0, 2.0, 0.2), flat("hazard", 0.8)))
    return prims


def pegboard() -> list:
    """Panel de herramientas de pared con siluetas pintadas (faltan varias)."""
    prims = [box((0.0, 46.0, -6.0), (22.0, 12.0, 0.6), wood(401, 0.8))]
    for y in range(36, 58, 3):
        for x in range(-20, 21, 3):
            prims.append(box((float(x), float(y), -5.38), (0.3, 0.3, 0.02), flat("dark", 1.0)))
    tools_ = [((-16.0, 50.0), "chrome", (0.8, 6.0)), ((-11.0, 49.0), "oxblood", (1.0, 5.0)), ((-4.0, 48.0), "chrome", (0.6, 7.0)),
              ((3.0, 50.0), None, (1.2, 5.0)), ((9.0, 47.0), "machine", (2.0, 3.0)), ((15.0, 50.0), None, (0.8, 6.0))]
    for (x, y), m, (w, h) in tools_:
        prims.append(box((x, y, -5.3), (w + 0.4, h + 0.4, 0.05), flat("felt", 0.8)))  # silueta pintada
        if m is not None:
            prims.append(box((x, y, -4.9), (w, h, 0.4), flat(m, 1.1, 0.6)))
    prims.append(capsule((-20.0, 38.0, -4.8), (-6.0, 38.0, -4.8), 0.4, flat("cable", 1.0)))
    return prims


def office_chair(tipped: bool = False) -> list:
    prims = []
    for i in range(5):
        a = i / 5 * math.tau + 0.3
        end = (math.cos(a) * 8.0, 2.0, math.sin(a) * 8.0)
        prims.append(capsule((0.0, 3.0, 0.0), end, 0.7, flat("dark", 1.1)))
        prims += caster(end[0], end[2], 1.0)
    prims.append(cylinder((0.0, 3.0, 0.0), (0.0, 13.0, 0.0), 1.0, CHROME))
    prims.append(box((0.0, 14.5, 0.0), (7.0, 1.4, 7.0), fabric("felt", 411, folds=0.2, stain=0.66, dirty_h=0)))
    prims.append(capsule((0.0, 15.0, -6.0), (0.0, 20.0, -8.0), 0.8, flat("dark", 1.0)))
    prims.append(box((0.0, 25.0, -8.4), (6.4, 6.0, 1.2), fabric("felt", 412, folds=0.2, stain=0.66, dirty_h=0),
                     basis=basis_rot(rx=-0.1)))
    if tipped:
        return transform(prims, basis_rot(rx=-1.4, ry=-0.6), (0.0, 7.0, 4.0))
    return prims


def bench() -> list:
    """Bancada de espera de tres asientos unidos sobre una viga (2 casillas de ancho)."""
    prims = [box((0.0, 8.0, 0.0), (28.0, 1.0, 1.2), painted("galv", 421))]
    for x in (-22.0, 22.0):
        prims.append(box((x, 4.0, 0.0), (1.2, 4.0, 6.0), painted("galv", 422)))
        prims.append(box((x, 0.5, 0.0), (2.0, 0.5, 7.0), RUBBER))
    for i, x in enumerate((-19.0, 0.0, 19.0)):
        seat = fabric("vinyl", 423 + i, folds=0.15, stain=0.66, dirty_h=0)
        prims.append(box((x, 15.0, 1.0), (8.6, 1.2, 7.0), seat))
        prims.append(box((x, 24.0, -6.5), (8.6, 8.0, 1.0), seat, basis=basis_rot(rx=-0.12)))
        prims.append(box((x, 11.0, 0.0), (1.0, 3.0, 1.0), painted("galv", 426)))
        if i == 1:  # asiento rajado
            prims.append(box((x, 16.3, 1.0), (4.0, 0.2, 0.6), flat("stain", 1.0)))
    prims.append(box((19.0, 16.5, 2.0), (3.0, 0.4, 4.0), PAPER, basis=basis_rot(ry=0.4)))  # revista
    return prims


def plant() -> list:
    """Planta muerta en una maceta de barro con tierra seca y hojas caídas."""
    prims = [cylinder((0.0, 0.0, 0.0), (0.0, 12.0, 0.0), 6.0, painted("oxblood", 431, rust=0.9, chips=0.9),
                      cut=lambda p: p[1] > 11.0 and p[0] ** 2 + p[2] ** 2 < 5.0 ** 2)]
    prims.append(cylinder((0.0, 0.0, 0.0), (0.0, 10.6, 0.0), 5.2, noisy("wood_old", 432, 0.3, 0.6)))
    prims.append(cylinder((0.0, 11.6, 0.0), (0.0, 12.4, 0.0), 6.6, painted("oxblood", 433, rust=0.9)))
    rng = random.Random(434)
    for _ in range(6):
        a = rng.uniform(0, math.tau)
        tip = (math.cos(a) * rng.uniform(4, 9), rng.uniform(22, 34), math.sin(a) * rng.uniform(2, 6))
        mid = (tip[0] * 0.4, tip[1] * 0.6, tip[2] * 0.4)
        prims += limb([(0.0, 10.6, 0.0), mid, tip], [0.6, 0.4, 0.25], flat("wood_old", 0.9), 2)
        prims.append(ellipsoid(tip, (1.6, 0.6, 1.0), flat("stain", 0.8), basis=basis_rot(rz=rng.uniform(-1, 1))))
    for _ in range(4):
        prims.append(ellipsoid((rng.uniform(-10, 10), 0.3, rng.uniform(4, 10)), (1.6, 0.3, 1.0), flat("stain", 0.7)))
    return prims


def lightbox() -> list:
    """Negatoscopio de pared con dos radiografías puestas (apagado)."""
    prims = [box((0.0, 46.0, -6.0), (14.0, 9.0, 1.4), painted("enamel", 441, grime_h=0.0))]
    prims.append(box((0.0, 46.0, -4.5), (12.6, 7.6, 0.1), flat("porcelain", 0.6)))
    for x in (-6.2, 6.2):
        prims.append(box((x, 46.4, -4.35), (5.4, 6.8, 0.05), flat("dark", 1.0)))
        prims.append(ellipsoid((x, 47.0, -4.25), (2.6, 4.6, 0.02), flat("felt", 1.4)))  # costillas (borrosas)
        for k in range(4):
            prims.append(box((x, 44.0 + k * 1.6, -4.2), (2.2, 0.2, 0.02), flat("porcelain", 0.5)))
        prims.append(box((x, 53.0, -4.2), (0.8, 0.5, 0.2), CHROME))
    prims.append(capsule((12.0, 37.0, -5.0), (12.0, 20.0, -5.4), 0.35, flat("cable", 1.0)))
    return prims


def clock() -> list:
    prims = [cylinder((0.0, 56.0, -6.6), (0.0, 56.0, -5.0), 5.0, painted("enamel", 451, grime_h=0.0))]
    prims.append(cylinder((0.0, 56.0, -5.0), (0.0, 56.0, -4.8), 4.2, flat("porcelain", 1.05)))
    for i in range(12):
        a = i / 12 * math.tau
        prims.append(box((math.sin(a) * 3.6, 56.0 + math.cos(a) * 3.6, -4.7), (0.3, 0.3, 0.05), flat("dark", 1.0)))
    prims.append(capsule((0.0, 56.0, -4.6), (2.6, 55.0, -4.6), 0.25, flat("dark", 1.0)))  # parado a las 3:40
    prims.append(capsule((0.0, 56.0, -4.6), (-1.8, 53.0, -4.6), 0.3, flat("dark", 1.0)))
    prims.append(box((0.0, 56.0, -4.55), (4.0, 4.0, 0.02), glass(452, 0.6)))
    return prims


def extinguisher() -> list:
    prims = [box((0.0, 36.0, -6.6), (2.0, 4.0, 0.4), GALV)]  # soporte
    prims.append(cylinder((0.0, 22.0, -3.6), (0.0, 38.0, -3.6), 3.0, painted("ext_red", 461, rust=0.7)))
    prims.append(sphere((0.0, 38.0, -3.6), 3.0, painted("ext_red", 462, rust=0.7)))
    prims.append(cylinder((0.0, 40.0, -3.6), (0.0, 42.0, -3.6), 1.0, CHROME))
    prims.append(box((1.6, 42.0, -3.6), (2.4, 0.5, 0.6), flat("dark", 1.0)))
    prims += limb([(-1.0, 41.0, -3.0), (-4.0, 36.0, -2.4), (-3.6, 28.0, -1.0)], [0.45] * 3, flat("rubber", 1.0), 2)
    prims.append(box((0.0, 30.0, -0.7), (2.0, 2.6, 0.1), LABEL))
    return prims


def toolbox() -> list:
    prims = [box((0.0, 4.5, 0.0), (8.0, 4.5, 4.0), painted("oxblood", 471, rust=0.6))]
    prims.append(box((0.0, 9.4, 0.0), (8.2, 0.6, 4.2), painted("oxblood", 472, rust=0.6)))
    prims.append(capsule((-4.0, 11.0, 0.0), (4.0, 11.0, 0.0), 0.5, flat("dark", 1.1)))
    for x in (-5.0, 5.0):
        prims.append(box((x, 7.0, 4.1), (1.0, 0.6, 0.3), CHROME))
    prims.append(capsule((10.0, 0.6, 3.0), (16.0, 0.6, 6.0), 0.6, flat("oxblood", 1.0)))
    prims.append(capsule((16.0, 0.6, 6.0), (19.0, 0.6, 7.0), 0.35, CHROME))
    return prims


def ladder() -> list:
    """Escalera de tijera abierta, de aluminio sucio."""
    prims = []
    for side in (-1.0, 1.0):
        prims.append(capsule((side * 7.0, 0.5, -6.0), (side * 5.0, 46.0, -1.0), 0.8, GALV))
        prims.append(capsule((side * 7.0, 0.5, 6.0), (side * 5.0, 46.0, 0.0), 0.8, GALV))
    for k in range(5):
        t = (k + 1) / 6
        y = 46.0 * t
        prims.append(box((0.0, y, 6.0 - t * 6.0 + 0.4), (6.6 - t * 1.6, 0.4, 1.2), GALV))
    prims.append(box((0.0, 46.6, -0.5), (6.0, 0.6, 2.4), painted("hazard", 481)))
    prims.append(capsule((-6.0, 22.0, -4.0), (6.0, 22.0, 4.0), 0.25, flat("cable", 1.0)))
    return prims


def bags() -> list:
    """Bolsas de basura negras, atadas."""
    rng = random.Random(491)
    prims = []
    for i in range(4):
        c = (rng.uniform(-8, 8), 5.0 + (i // 3) * 6.0, rng.uniform(-5, 5))
        prims.append(ellipsoid(c, (rng.uniform(5, 7), rng.uniform(5, 6.5), rng.uniform(4, 6)),
                               lambda p, n: ("trash_bag", 0.9, None, 1.2)))
        prims.append(capsule(add(c, (0.0, 5.0, 0.0)), add(c, (0.5, 7.5, 0.0)), 0.9, flat("trash_bag", 1.0, 0.8)))
    return prims


def water_cooler() -> list:
    prims = [box((0.0, 17.0, 0.0), (6.0, 17.0, 6.0), painted("enamel", 501, rust=0.8))]
    prims.append(cylinder((0.0, 34.0, 0.0), (0.0, 46.0, 0.0), 5.4, glass(502, 0.9)))
    prims.append(cylinder((0.0, 34.0, 0.0), (0.0, 37.0, 0.0), 5.0, flat("water_dark", 1.2, 0.8)))  # casi vacía
    prims.append(box((0.0, 24.0, 6.2), (4.0, 3.0, 0.4), flat("dark", 1.0)))
    for x in (-1.8, 1.8):
        prims.append(box((x, 26.0, 6.6), (0.6, 0.9, 0.6), flat("ext_red" if x > 0 else "pane", 1.0)))
    prims.append(cylinder((8.5, 16.0, 2.0), (8.5, 28.0, 2.0), 1.4, flat("porcelain", 0.9)))  # vasos
    return prims


def anesthesia() -> list:
    """Máquina de anestesia: carro con fuelle, caudalímetros, monitor apagado y tubos colgando."""
    body = painted("enamel", 511, rust=0.76, grime_h=6.0)
    prims = [box((0.0, 16.0, 0.0), (10.0, 13.0, 8.0), body)]
    for x in (-8.0, 8.0):
        for z in (-6.0, 6.0):
            prims += caster(x, z, 1.4)
    prims.append(box((0.0, 29.6, 0.0), (10.6, 0.6, 8.6), steel(512)))
    prims.append(box((-3.0, 38.0, -5.0), (7.0, 8.0, 2.0), body))
    for i in range(4):
        prims.append(cylinder((-8.0 + i * 2.6, 34.0, -2.6), (-8.0 + i * 2.6, 42.0, -2.6), 0.7, GLASS))
        prims.append(sphere((-8.0 + i * 2.6, 35.0 + i * 1.5, -2.6), 0.5, flat("chrome", 1.2)))
    prims.append(box((5.0, 42.0, -4.0), (5.0, 4.0, 2.4), flat("plastic", 1.0)))
    prims.append(box((5.0, 42.0, -1.5), (4.0, 3.0, 0.1), flat("crt", 1.0)))
    prims.append(cylinder((6.0, 30.2, 3.0), (6.0, 37.0, 3.0), 2.4, fabric("rubber", 513, folds=0.6, stain=0.95, dirty_h=0)))  # fuelle
    prims += limb([(-9.0, 32.0, 4.0), (-14.0, 24.0, 8.0), (-12.0, 12.0, 12.0), (-6.0, 1.0, 14.0)], [0.9] * 4,
                  flat("rubber", 1.1), 2)
    prims += limb([(-6.0, 32.0, 6.0), (-8.0, 20.0, 10.0), (-2.0, 10.0, 12.0)], [0.6] * 3, flat("tube", 1.0), 2)
    prims.append(cylinder((11.0, 4.0, -4.0), (11.0, 30.0, -4.0), 2.6, painted("machine", 514)))  # bombona
    return prims


def cable_reel() -> list:
    prims = []
    for x in (-5.0, 5.0):
        prims.append(cylinder((x, 10.0, 0.0), (x + 1.0, 10.0, 0.0), 10.0, wood(521, 0.9)))
    prims.append(cylinder((-4.0, 10.0, 0.0), (4.0, 10.0, 0.0), 7.0, flat("cable", 1.0)))
    for i in range(8):
        prims.append(cylinder((-4.0 + i, 10.0, 0.0), (-3.6 + i, 10.0, 0.0), 7.3, flat("cable", 1.3)))
    prims += limb([(0.0, 17.0, 3.0), (6.0, 8.0, 10.0), (10.0, 1.0, 14.0), (18.0, 0.8, 18.0), (24.0, 0.8, 16.0)],
                  [0.8] * 5, flat("cable", 1.0), 2)
    return prims


def transformer() -> list:
    """Armario de transformador / batería de condensadores, con rejillas y aviso."""
    body = painted("machine", 531, rust=0.66, dent=0.4)
    prims = [box((0.0, 26.0, 0.0), (14.0, 26.0, 10.0), body)]
    prims.append(box((0.0, 0.8, 0.0), (14.4, 0.8, 10.4), flat("dark", 1.0)))
    for y in range(8, 20, 3):
        prims.append(box((0.0, float(y), 10.05), (10.0, 0.5, 0.1), flat("dark", 1.0)))
    prims.append(box((0.0, 40.0, 10.1), (4.0, 3.4, 0.1), flat("hazard", 1.0)))
    prims.append(box((0.0, 40.4, 10.2), (0.5, 1.6, 0.05), flat("dark", 1.0)))
    prims.append(box((-9.0, 30.0, 10.1), (3.0, 4.0, 0.1), LABEL))
    prims.append(box((10.0, 30.0, 10.6), (0.7, 3.0, 0.5), CHROME))
    for i, x in enumerate((-8.0, 0.0, 8.0)):
        prims.append(cylinder((x, 52.0, -4.0), (x, 66.0, -4.0), 1.5, GALV))
    return prims


def toilet() -> list:
    """Inodoro con cisterna alta y cadena; la tapa levantada y el agua oscura."""
    prims = [box((0.0, 46.0, -9.0), (7.0, 4.0, 3.0), painted("porcelain", 541, rust=0.82, grime_h=0.0))]
    prims.append(capsule((5.0, 42.0, -6.5), (5.0, 26.0, -6.0), 0.2, CHROME))
    prims.append(sphere((5.0, 25.6, -6.0), 0.8, flat("bakelite", 1.0)))
    prims.append(capsule((-4.0, 42.0, -8.0), (-4.0, 16.0, -8.5), 0.9, GALV))
    pc = painted("porcelain", 542, rust=0.85, grime_h=4.0)
    prims.append(cylinder((0.0, 0.0, -2.0), (0.0, 9.0, -1.0), 4.2, pc))
    prims.append(ellipsoid((0.0, 13.0, 1.0), (7.0, 3.4, 8.5), pc,
                           cut=lambda p: p[1] > 14.6 and (p[0] / 5.4) ** 2 + ((p[2] - 1.5) / 6.6) ** 2 < 1))
    prims.append(ellipsoid((0.0, 12.0, 1.5), (5.4, 1.4, 6.6), flat("water_dark", 1.0, 1.0)))
    prims.append(box((0.0, 22.0, -7.0), (6.6, 6.6, 0.4), noisy("felt", 543, 0.3), basis=basis_rot(rx=0.15)))  # tapa
    return prims


def bathtub() -> list:
    """Bañera de hierro esmaltado con agua oscura y quieta (2 casillas de ancho)."""
    shell = painted("porcelain", 551, rust=0.75, grime_h=5.0)
    prims = [box((0.0, 9.0, 0.0), (28.0, 9.0, 11.0), shell,
                 cut=lambda p: p[1] > 15.0 and abs(p[0]) < 26.0 and abs(p[2]) < 9.0)]
    prims.append(box((0.0, 13.0, 0.0), (26.0, 0.3, 9.0), flat("water_dark", 1.0, 1.4)))
    prims.append(box((0.0, 15.3, 0.0), (26.0, 2.0, 9.0), shell,
                     cut=lambda p: abs(p[0]) < 25.6 and abs(p[2]) < 8.6))
    prims.append(capsule((-25.0, 22.0, -9.5), (-25.0, 18.0, -6.0), 0.8, CHROME))  # grifo
    prims.append(ellipsoid((10.0, 13.4, 2.0), (6.0, 0.4, 4.0), flat("stain", 0.7)))  # algo flota
    prims.append(capsule((-6.0, 13.5, 4.0), (6.0, 13.5, 5.0), 0.3, flat("hair", 1.0)))
    return prims


def scale() -> list:
    """Báscula de columna con el tallímetro."""
    prims = [box((0.0, 2.0, 2.0), (7.0, 2.0, 8.0), painted("enamel", 561, rust=0.8))]
    prims.append(box((0.0, 4.1, 3.0), (6.0, 0.1, 6.0), flat("rubber", 0.9)))
    prims.append(box((0.0, 26.0, -6.0), (1.6, 22.0, 1.4), painted("enamel", 562, rust=0.8)))
    prims.append(box((0.0, 40.0, -4.0), (5.0, 1.0, 1.6), steel(563)))
    prims.append(capsule((-4.0, 40.6, -3.0), (4.0, 40.6, -3.0), 0.4, CHROME))
    prims.append(sphere((1.0, 41.0, -3.0), 0.7, flat("brass_d", 1.1, 0.8)))
    prims.append(capsule((0.0, 50.0, -5.0), (0.0, 62.0, -5.0), 0.5, CHROME))
    prims.append(box((0.0, 60.0, 0.0), (4.0, 0.3, 4.0), CHROME))
    return prims


def gas_bottles() -> list:
    """Botellas de gas de soldadura encadenadas a la pared."""
    prims = []
    for i, (x, m) in enumerate(((-5.0, "machine"), (5.0, "oxblood"))):
        prims.append(cylinder((x, 0.0, 0.0), (x, 40.0, 0.0), 4.2, painted(m, 571 + i, rust=0.62)))
        prims.append(sphere((x, 40.0, 0.0), 4.2, painted(m, 573 + i, rust=0.62)))
        prims.append(cylinder((x, 43.0, 0.0), (x, 47.0, 0.0), 1.1, flat("brass_d", 1.0, 0.8)))
    prims += limb([(-10.0, 30.0, -4.0), (0.0, 29.0, 4.6), (10.0, 30.0, -4.0)], [0.4] * 3, flat("chain", 1.0), 3)
    prims += limb([(5.0, 45.0, 1.0), (9.0, 30.0, 6.0), (8.0, 4.0, 9.0), (2.0, 0.8, 12.0)], [0.6] * 4, flat("oxblood", 1.0), 2)
    return prims


def bed_frame() -> list:
    """Somier de cama sin colchón, con la malla oxidada (2 casillas en vertical)."""
    from props import _stretcher_base
    prims = [p for p in _stretcher_base(make_sheet(), "none") if p.center[1] < 23.5 or abs(p.center[1] - 28.5) < 0.1]
    for z in range(-27, 28, 3):
        prims.append(capsule((-10.5, 23.2, float(z)), (10.5, 23.2, float(z)), 0.2, painted("galv", 581, rust=0.5)))
    for x in range(-9, 10, 3):
        prims.append(capsule((float(x), 23.3, -28.0), (float(x), 23.3, 28.0), 0.2, painted("galv", 582, rust=0.5)))
    return prims


def files_pile() -> list:
    """Montón de expedientes en el suelo, unos sobre otros."""
    rng = random.Random(591)
    prims = []
    for i in range(7):
        prims.append(box((rng.uniform(-3, 3), 0.6 + i * 1.1, rng.uniform(-2, 2)), (6.5, 0.5, 5.0),
                         flat(rng.choice(["label_w", "cardboard", "stain", "oxblood"]), rng.uniform(0.85, 1.1)),
                         basis=basis_rot(ry=rng.uniform(-0.5, 0.5))))
    prims += papers(rng, 3, -12, 12, 4, 12, 0.2)
    return prims


def iv_bags_box() -> list:
    """Caja abierta de bolsas de suero, alguna reventada."""
    prims = boxes(2)[:5]
    for i in range(3):
        prims.append(ellipsoid((-4.0 + i * 4.0, 11.0, -2.0 + i), (2.4, 1.0, 3.6), flat("bag", 1.0, 1.0)))
    prims.append(ellipsoid((13.0, 0.4, 6.0), (4.0, 0.3, 3.0), flat("water_dark", 1.0, 1.0)))
    return prims


# Tabla del decorado: clave -> (función o lista de funciones = fotogramas, ancho, alto, origen, vista, sombra)
#   vista: "map" (oblicua de suelo) | sombra: "ground" (apoya en el suelo), "wall" (cuelga de la pared), "none".
DRESSING = {
    "wheelchair_up": ([lambda: wheelchair_up(False), lambda: wheelchair_up(True)], 40, 64, (20, 44), "ground"),
    "screen": ([lambda: screen(False), lambda: screen(True)], 64, 84, (32, 64), "ground"),
    "o2_tank": ([o2_tank], 24, 64, (12, 54), "ground"),
    "cart_med": ([cart_med], 36, 64, (16, 50), "ground"),
    "cart_instr": ([cart_instr], 32, 48, (16, 38), "ground"),
    "gurney_tipped": ([gurney_tipped], 76, 64, (38, 40), "ground"),
    "iv_fallen": ([iv_fallen], 64, 40, (32, 24), "ground"),
    "boxes": ([lambda: boxes(0), lambda: boxes(1), lambda: boxes(2)], 48, 56, (22, 42), "ground"),
    "drum": ([lambda: drum(False), lambda: drum(True)], 40, 56, (20, 42), "ground"),
    "pallet": ([pallet], 40, 44, (20, 30), "ground"),
    "washer": ([washer], 40, 72, (20, 56), "ground"),
    "dryer": ([dryer], 36, 80, (18, 64), "ground"),
    "linen_pile": ([linen_pile], 40, 32, (20, 20), "ground"),
    "basket": ([basket], 24, 28, (12, 18), "ground"),
    "cold_door": ([cold_door], 56, 80, (28, 76), "wall"),
    "autopsy_table": ([autopsy_table], 32, 104, (16, 64), "ground"),
    "body_bags": ([body_bags], 28, 32, (14, 22), "ground"),
    "tank_h": ([tank_h], 72, 60, (36, 44), "ground"),
    "pegboard": ([pegboard], 52, 72, (26, 68), "wall"),
    "office_chair": ([lambda: office_chair(False), lambda: office_chair(True)], 36, 48, (18, 36), "ground"),
    "bench": ([bench], 64, 48, (32, 38), "ground"),
    "plant": ([plant], 28, 48, (14, 40), "ground"),
    "lightbox": ([lightbox], 36, 64, (18, 60), "wall"),
    "clock": ([clock], 16, 72, (8, 68), "wall"),
    "extinguisher": ([extinguisher], 16, 52, (8, 48), "wall"),
    "toolbox": ([toolbox], 44, 24, (16, 14), "ground"),
    "ladder": ([ladder], 24, 64, (12, 54), "ground"),
    "bags": ([bags], 32, 36, (16, 24), "ground"),
    "water_cooler": ([water_cooler], 28, 64, (12, 54), "ground"),
    "anesthesia": ([anesthesia], 40, 64, (20, 52), "ground"),
    "cable_reel": ([cable_reel], 52, 44, (20, 30), "ground"),
    "transformer": ([transformer], 40, 84, (20, 72), "ground"),
    "toilet": ([toilet], 24, 64, (12, 52), "ground"),
    "bathtub": ([bathtub], 68, 48, (34, 34), "ground"),
    "scale": ([scale], 24, 80, (12, 70), "ground"),
    "gas_bottles": ([gas_bottles], 32, 64, (16, 54), "ground"),
    "bed_frame": ([bed_frame], 40, 112, (20, 74), "ground"),
    "files_pile": ([files_pile], 36, 28, (18, 16), "ground"),
    "iv_bags_box": ([iv_bags_box], 40, 32, (18, 20), "ground"),
}
