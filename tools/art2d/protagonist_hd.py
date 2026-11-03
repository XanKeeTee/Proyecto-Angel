"""Protagonista en el mapa, segunda muestra: 112×160 (vista interna de 1280×720), 8 direcciones.

Un hombre corriente, demacrado y herido: cráneo rapado con una cicatriz cosida, ojos hundidos, bata
de hospital abierta por detrás con la incisión cosida sobre la columna, pulsera de paciente en la
muñeca derecha, vía arrancada en el dorso de la mano izquierda, descalzo y con los pies sucios. Sin
piezas metálicas ni nada tecnológico (canon: docs/lore/prologo.md).

Cómo se dibuja (todo en 2D):
- **Esqueleto 2D girable**: cada articulación tiene una posición lateral, una altura y una
  profundidad; para cada una de las 8 direcciones se calcula dónde cae en pantalla (`Rig.p`). Es
  solo la maqueta de dónde van las cosas, como el giro de un muñeco de recortes: no hay volúmenes.
- **Siluetas trazadas a mano** sobre esos puntos: perfiles de extremidad angulosos (`paint.limb`),
  el saco de la bata por filas (ancho delante/detrás a cada altura), el cráneo como un polígono de
  frente y otro de perfil que se mezclan en los tres cuartos, pies y manos en polígonos.
- **Pintura** (`paint.Piece`): valor por píxel con canto que gira, pliegues, poros, trama de la
  tela, manchas que empapan, venas, brillo húmedo; rampas largas con tramado ordenado.

Las 8 direcciones se dibujan todas (no hay espejo), así la pulsera y la vía siempre están en su mano
y la luz siempre viene del mismo lado (arriba a la izquierda).
"""

from __future__ import annotations

import math
import os
import sys
from dataclasses import dataclass

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import palette_hd  # noqa: E402,F401
from paint import Piece, compose, lerp, limb  # noqa: E402

W, H = 112, 160
CX, GROUND = 56, 150
ORIGIN = (56, 150)
LIGHT = (-0.35, -0.94)
PERSP = 0.28            # lo que se acerca al espectador baja en pantalla (vista oblicua)

DIRECTIONS = {"S": 0, "SW": 45, "W": 90, "NW": 135, "N": 180, "NE": -135, "E": -90, "SE": -45}

# Perfiles (t, ancho a la izquierda, ancho a la derecha del hueso que baja).
THIGH = [(0.0, 6.0, 6.0), (0.3, 5.6, 5.3), (0.7, 4.3, 4.1), (1.0, 3.7, 3.7)]
SHIN_F = [(0.0, 3.7, 3.7), (0.07, 4.1, 3.6), (0.25, 3.4, 4.3), (0.55, 2.8, 3.1), (0.85, 1.9, 1.9), (1.0, 2.3, 2.3)]
SHIN_S = [(0.0, 3.8, 3.8), (0.08, 3.4, 4.2), (0.28, 4.6, 3.1), (0.55, 3.4, 2.6), (0.85, 1.9, 1.8), (1.0, 2.3, 2.3)]
UPPER = [(0.0, 4.4, 4.2), (0.15, 4.6, 4.0), (0.5, 3.2, 3.0), (0.9, 2.6, 2.6), (1.0, 3.0, 2.9)]
FORE = [(0.0, 2.9, 2.9), (0.18, 3.5, 3.1), (0.5, 2.9, 2.6), (0.9, 1.9, 1.9), (1.0, 2.0, 2.0)]
SLEEVE = [(0.0, 4.6, 4.2), (0.35, 5.8, 5.4), (1.0, 6.6, 6.2)]

# Saco de la bata: (altura, medio ancho, profundidad delante, profundidad detrás)
GOWN_ROWS = [(35.5, 11.0, 3.8, -4.6), (40, 16.6, 5.8, -6.6), (46, 17.0, 7.4, -7.8), (54, 15.8, 8.4, -6.8),
             (64, 15.0, 7.6, -5.8), (74, 14.6, 6.8, -5.8), (86, 16.0, 7.2, -7.2), (96, 17.4, 7.6, -7.6),
             (102, 18.4, 8.0, -8.0)]
WOBBLE = [0.0, 0.3, -0.2, 0.5, -0.4, 0.2, -0.5, 0.4, 0.0]


@dataclass
class Gait:
    bob: float = 0.0
    step_l: float = 0.0
    step_r: float = 0.0
    lift_l: float = 0.0
    lift_r: float = 0.0
    swing_l: float = 0.0
    swing_r: float = 0.0
    breath: float = 0.0
    sway: int = 0


IDLE = [Gait(), Gait(breath=1.0, sway=1)]
# Contacto, paso, contacto opuesto, paso. La pierna derecha da el paso más corto (cojea).
WALK = [
    Gait(bob=1.2, step_l=12.0, step_r=-10.0, swing_l=-7.0, swing_r=7.5, sway=0),
    Gait(bob=-0.6, step_l=1.5, step_r=1.0, lift_r=6.0, swing_l=-1.5, swing_r=1.5, sway=1),
    Gait(bob=1.2, step_l=-11.0, step_r=9.0, swing_l=7.5, swing_r=-7.0, sway=2),
    Gait(bob=-0.6, step_l=1.0, step_r=1.5, lift_l=6.5, swing_l=1.5, swing_r=-1.5, sway=3),
]


class Rig:
    """Proyección de puntos del cuerpo (lateral `a`, altura `y`, profundidad `z`) a la pantalla.
    a > 0 = lado izquierdo del personaje; z > 0 = hacia donde mira."""

    def __init__(self, theta: float) -> None:
        self.t = math.radians(theta)
        self.c, self.s = math.cos(self.t), math.sin(self.t)

    def p(self, a: float, y: float, z: float) -> tuple[float, float]:
        x = CX + a * self.c - z * self.s
        v = z * self.c + a * self.s
        return (x, y + v * PERSP)

    def v(self, a: float, z: float) -> float:
        return z * self.c + a * self.s


def _rows(y: float) -> tuple[float, float, float]:
    ys = [r[0] for r in GOWN_ROWS]
    y = min(max(y, ys[0]), ys[-1])
    for i in range(len(ys) - 1):
        if ys[i] <= y <= ys[i + 1]:
            t = (y - ys[i]) / (ys[i + 1] - ys[i])
            a, b = GOWN_ROWS[i], GOWN_ROWS[i + 1]
            return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
    return GOWN_ROWS[-1][1:]


# =============================================================================================
# Cabeza
# =============================================================================================

# Cráneo de frente y de perfil (mirando a la izquierda), mismos puntos y en el mismo orden:
# coronilla → lado derecho de la pantalla → barbilla → lado izquierdo. Relativos al centro.
SKULL_F = [(0, -11.4), (4.2, -10.8), (7.0, -8.6), (8.4, -5.0), (8.6, -1.0), (8.2, 2.6), (7.2, 5.4), (5.4, 8.4),
           (3.0, 10.6), (0, 11.3), (-3.0, 10.6), (-5.4, 8.4), (-7.2, 5.4), (-8.2, 2.6), (-8.6, -1.0), (-8.4, -5.0),
           (-7.0, -8.6), (-4.2, -10.8)]
SKULL_S = [(1.0, -11.4), (5.6, -10.6), (8.8, -7.8), (10.2, -3.6), (9.8, 0.4), (8.2, 3.4), (6.4, 5.6), (4.4, 8.4),
           (1.0, 10.4), (-3.2, 11.1), (-6.4, 10.2), (-7.2, 8.4), (-7.6, 6.6), (-9.8, 4.2), (-8.4, 1.6), (-9.0, -1.2),
           (-8.6, -5.0), (-5.4, -9.8)]
SKULL_SB = [(1.0, -11.4), (5.6, -10.6), (8.8, -7.8), (10.2, -3.6), (9.8, 0.4), (8.2, 3.4), (6.4, 5.6), (4.4, 8.4),
            (1.0, 10.4), (-3.2, 11.0), (-5.8, 10.0), (-6.8, 8.0), (-7.4, 6.0), (-7.8, 3.6), (-8.2, 1.0), (-8.8, -1.6),
            (-8.6, -5.0), (-5.4, -9.8)]
R_HEAD = 8.3
# Cicatriz: de la sien derecha, por encima de la coronilla, hasta detrás de la oreja izquierda.
SCAR = [(-80, -2.5), (-62, -6.5), (-40, -9.4), (-12, -10.8), (20, -10.6), (52, -9.4), (85, -7.0), (118, -4.2),
        (150, -1.8)]


def _az(rig: Rig, phi: float, y: float, cx: float, cy: float, r: float = R_HEAD) -> tuple[tuple[float, float], float]:
    """Punto de la superficie de la cabeza a un azimut `phi` (0 = cara, +90 = lado izquierdo)."""
    d = math.radians(phi) - rig.t
    return (cx + r * math.sin(d), cy + y), math.cos(d)


def head_piece(rig: Rig, g: Gait) -> Piece:
    pc = Piece(W, H, "head")
    th = math.degrees(rig.t)
    s, c = rig.s, rig.c
    hcx, hcy = rig.p(0, 22.5 + g.bob * 0.6 - g.breath * 0.3, 4.6)
    # cuello: de la base (dentro de la bata) a la mandíbula, adelantado
    nb = rig.p(0, 39 + g.bob, 1.5)
    nt = rig.p(0, 30 + g.bob, 3.4)
    neck = limb(nb, nt, [(0.0, 5.2, 5.2), (0.5, 4.0, 4.0), (1.0, 4.0, 4.0)])
    pc.fill(neck, "skin", 0.5)
    # cráneo
    t = abs(s)
    side = SKULL_S if c >= -0.05 else SKULL_SB
    pts = [((fx * (1 - t) + sx * t) * (1 if s >= 0 else -1), fy * (1 - t) + sy * t)
           for (fx, fy), (sx, sy) in zip(SKULL_F, side)]
    skull = [(hcx + x, hcy + y) for x, y in pts]
    pc.fill(skull, "skin", 0.56)
    # orejas
    for phi in (90, -90):
        (ex, ey), vis = _az(rig, phi, 1.0, hcx, hcy, R_HEAD - 0.4)
        if vis < -0.35:
            continue
        wv = 1.1 + 2.4 * max(0.0, abs(vis))
        ear = [(ex - wv, ey - 3.6), (ex + wv * 0.6, ey - 4.2), (ex + wv, ey - 1.0), (ex + wv * 0.4, ey + 4.6),
               (ex - wv * 0.8, ey + 3.4)]
        if abs(vis) < 0.5:   # de frente/espaldas la oreja sobresale del contorno
            dirx = 1 if ex > hcx else -1
            ear = [(ex + dirx * 0.2, ey - 3.6), (ex + dirx * 2.0, ey - 2.4), (ex + dirx * 1.8, ey + 2.6),
                   (ex + dirx * 0.4, ey + 4.2)]
        pc.fill(ear, "skin", 0.5)
        pc.crease([(ex - wv * 0.2, ey - 2.4), (ex + wv * 0.3, ey + 2.0)], 0.22, 1.0)
    # cuero cabelludo rapado: por encima de la línea del pelo, según el azimut de cada píxel
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    dx = np.clip((xx - hcx) / R_HEAD, -1, 1)
    phi = np.degrees(rig.t + np.arcsin(dx))
    phi = (phi + 180) % 360 - 180
    hair = -5.5 + np.clip((np.abs(phi) - 40) / 50, 0, 1) * 4.5 + np.clip((np.abs(phi) - 100) / 60, 0, 1) * 9.5
    scalp = pc.mask & (yy - hcy < hair) & ~pc.poly_mask(neck)
    if c < -0.3:   # de espaldas, todo el cráneo es cuero cabelludo hasta la nuca
        scalp |= pc.mask & (yy - hcy < 6.0) & ~pc.poly_mask(neck)
    pc.fill_mask(scalp, "scalp")
    # luz y forma
    pc.form(LIGHT, bevel=4.0, strength=0.34, rim_dark=0.14)
    pc.plane([(hcx - 9, hcy - 12), (hcx + 2, hcy - 12), (hcx - 3, hcy - 6), (hcx - 9, hcy - 4)], 0.14, 2.0)
    pc.pores(0.06, 0.18, 11, clip=["scalp"])        # pelo rapado
    pc.noise(0.10, 3.0, 12, clip=["skin"])          # piel moteada
    pc.pores(0.05, 0.08, 13, clip=["skin"])
    # cara (solo si mira hacia el espectador)
    if c > -0.35:
        for side_phi in (-30, 30):
            (ex, ey), vis = _az(rig, side_phi, -0.6, hcx, hcy, R_HEAD - 0.6)
            if vis <= 0.08:
                continue
            k = max(0.35, vis)
            sock = [(ex - 2.6 * k, ey - 1.6), (ex + 2.4 * k, ey - 1.8), (ex + 2.8 * k, ey + 0.8),
                    (ex + 1.0 * k, ey + 2.4), (ex - 2.0 * k, ey + 2.0), (ex - 2.9 * k, ey + 0.4)]
            pc.plane(sock, -0.42, 0.9)                                 # cuenca hundida
            pc.crease([(ex - 2.4 * k, ey - 2.4), (ex + 2.4 * k, ey - 2.6)], -0.16, 0.8)  # arco de la ceja (luz)
            pc.line([(ex - 1.4 * k, ey + 0.4), (ex + 1.4 * k, ey + 0.2)], "eye", 0.12)  # ojo entornado
            pc.dot(ex - 0.4 * k, ey + 0.4, "eye", 0.55)               # brillo húmedo
            pc.plane([(ex - 2.2 * k, ey + 2.2), (ex + 1.6 * k, ey + 2.2), (ex + 1.0 * k, ey + 3.4), (ex - 1.6 * k, ey + 3.4)],
                     -0.14, 0.7, clip=["skin"])                       # ojera
            (cx2, cy2), v2 = _az(rig, side_phi * 1.55, 3.2, hcx, hcy, R_HEAD - 0.3)
            if v2 > 0.1:
                pc.plane([(cx2 - 1.6, cy2 - 1.0), (cx2 + 1.6, cy2 - 1.2), (cx2 + 1.0, cy2 + 0.4)], 0.16, 0.8)  # pómulo
                pc.plane([(cx2 - 1.4, cy2 + 1.4), (cx2 + 1.6, cy2 + 1.2), (cx2 + 0.8, cy2 + 4.6), (cx2 - 1.0, cy2 + 4.2)],
                         -0.2, 0.9, clip=["skin"])                     # mejilla chupada
        (nx, ny), nv = _az(rig, 0, 0.0, hcx, hcy, R_HEAD + 1.0)
        if nv > 0.0:
            tip = (nx, ny + 4.0)
            pc.crease([(nx - 0.6, ny - 0.6), (tip[0] - 0.4, tip[1] - 0.6)], -0.18, 0.7)   # caballete
            pc.plane([(tip[0] - 1.8, tip[1] + 0.4), (tip[0] + 1.6, tip[1] + 0.4), (tip[0] + 1.2, tip[1] + 1.4),
                      (tip[0] - 1.4, tip[1] + 1.4)], -0.3, 0.6)             # sombra bajo la nariz
            pc.dot(tip[0] - 1.0, tip[1] + 0.6, "skin", 0.12)
            pc.dot(tip[0] + 0.6, tip[1] + 0.6, "skin", 0.14)
            (mx, my), mv = _az(rig, 0, 7.6, hcx, hcy, R_HEAD - 0.4)
            hw = 2.8 * max(0.4, mv)
            pc.line([(mx - hw, my), (mx + hw * 0.9, my - 0.2)], "lips", 0.18)       # boca seca
            pc.line([(mx - hw * 0.7, my + 1), (mx + hw * 0.6, my + 1)], "lips", 0.62)
            pc.crease([(mx - 1.4, my + 3.2), (mx + 1.4, my + 3.0)], -0.12, 0.8)     # luz en la barbilla
            # barba de días en la mandíbula
            jaw = pc.poly_mask([(hcx - 8, hcy + 4), (hcx + 8, hcy + 4), (hcx + 6, hcy + 12), (hcx - 6, hcy + 12)])
            rng = np.random.default_rng(15)
            stub = jaw & pc.of("skin") & (rng.random((H, W)) < 0.35)
            pc.val[stub] -= 0.1
    # nuca y tendones del cuello
    pc.crease([lerp(nb, nt, 0.1), lerp(nb, nt, 0.85)], 0.14, 1.0, ridge=0.1, ridge_off=(-1.2, 0))
    pc.plane([(hcx - 9, hcy + 8), (hcx + 9, hcy + 8), (hcx + 8, hcy + 14), (hcx - 8, hcy + 14)], -0.2, 1.4,
             clip=["skin"])                                       # sombra bajo la mandíbula
    # cicatriz cosida
    path = []
    for ph, yy_ in SCAR:
        (px_, py_), vis = _az(rig, ph, yy_, hcx, hcy, R_HEAD - 0.2)
        if vis > -0.05:
            path.append((px_, py_, vis))
    if len(path) >= 2:
        pts2 = [(x, y) for x, y, _ in path]
        pc.stain(pts2[len(pts2) // 2], 2.4, "skin_bruise", 21, stretch=(2.0, 0.5), ring=0.0)
        pc.line(pts2, "flesh", 0.38)
        pc.crease(pts2, 0.12, 1.2, ridge=0.08, ridge_off=(0, 1))
        acc = 0.0
        for (x0, y0, _), (x1, y1, _) in zip(path, path[1:]):
            seg = math.hypot(x1 - x0, y1 - y0)
            n = max(1, int(seg / 3.0))
            for i in range(n):
                tt = (i + 0.5) / n
                px_, py_ = x0 + (x1 - x0) * tt, y0 + (y1 - y0) * tt
                ux, uy = (x1 - x0) / (seg or 1), (y1 - y0) / (seg or 1)
                pc.line([(px_ - uy * 1.2, py_ + ux * 1.2), (px_ + uy * 1.2, py_ - ux * 1.2)], "thread", 0.3, inside=True)
            acc += seg
        pc.dot(*pts2[0], "blood", 0.4)
    return pc


# =============================================================================================
# Extremidades
# =============================================================================================

def _foot(pc: Piece, rig: Rig, a: float, ankle_z: float, lift: float, bob: float) -> None:
    y0 = 141 - lift + bob * 0.3
    heel_up = lift * 1.3
    toe_up = lift * 0.4
    pts3 = [(a + 2.4, y0, ankle_z + 1.4), (a - 2.4, y0, ankle_z + 1.4), (a - 2.4, y0, ankle_z - 1.8),
            (a + 2.4, y0, ankle_z - 1.8),
            (a + 2.4, 149 - heel_up, ankle_z - 2.8), (a - 2.4, 149 - heel_up, ankle_z - 2.8),
            (a + 3.5, 149 - toe_up * 0.6, ankle_z + 7.0), (a - 3.4, 149 - toe_up * 0.6, ankle_z + 6.6),
            (a + 2.8, 150 - toe_up, ankle_z + 10.6), (a - 2.4, 150 - toe_up, ankle_z + 10.2)]
    scr = [rig.p(*p) for p in pts3]
    from scipy.spatial import ConvexHull
    hull = ConvexHull(np.array(scr))
    poly = [tuple(scr[i]) for i in hull.vertices]
    pc.fill(poly, "skin", 0.5)
    # dedos: pliegues entre ellos en el extremo, uñas, empeine con tendones
    toes = [rig.p(a + k, 150 - toe_up, ankle_z + 9.6) for k in (-1.6, -0.2, 1.2, 2.4)]
    base = [rig.p(a + k, 148 - toe_up, ankle_z + 7.4) for k in (-1.6, -0.2, 1.2, 2.4)]
    for (tx, ty), (bx, by) in zip(toes[:3], base[:3]):
        pc.crease([(bx + 0.7, by), (tx + 0.7, ty)], 0.14, 0.7)
    for tx, ty in toes:
        pc.dot(tx, ty - 0.6, "skin", 0.7)
    tend = [rig.p(a + k, 143 - lift, ankle_z + 1) for k in (-0.6, 1.0)]
    tend2 = [rig.p(a + k, 147 - toe_up, ankle_z + 6.5) for k in (-1.0, 1.4)]
    for t1, t2 in zip(tend, tend2):
        pc.crease([t1, t2], -0.1, 0.7)
    pc.stain(rig.p(a, 150, ankle_z + 4), 4.5, "dirt", 31 + int(a), stretch=(1.4, 0.6), ring=0.04, val=0.45)
    pc.dot(*rig.p(a - 2.2, 141 - lift, ankle_z), "skin", 0.72)     # tobillo


def leg_piece(rig: Rig, g: Gait, side: int) -> tuple[Piece, float]:
    """side = +1 pierna izquierda del personaje, -1 derecha."""
    pc = Piece(W, H, "leg")
    step = g.step_l if side > 0 else g.step_r
    lift = g.lift_l if side > 0 else g.lift_r
    a = 6.6 * side
    hip = rig.p(a, 84 + g.bob, -0.5)
    knee = rig.p(a + side * 0.4, 112 - lift * 0.5 + g.bob * 0.5, 1.0 + step * 0.5 + lift * 1.0)
    ankle = rig.p(a + side * 0.2, 140 - lift + g.bob * 0.3, step)
    sideways = abs(rig.s) > 0.6
    shin = SHIN_S if sideways else SHIN_F
    if sideways and rig.s < 0:                 # mirando a la derecha: la pantorrilla va al otro lado
        shin = [(t, r, l) for t, l, r in shin]
    pc.fill(limb(hip, knee, THIGH), "skin", 0.5)
    pc.fill(limb(knee, ankle, shin), "skin", 0.52)
    _foot(pc, rig, a + side * 0.2, step, lift, g.bob)
    pc.form(LIGHT, bevel=3.0, strength=0.32, rim_dark=0.12)
    # rodilla huesuda: rótula clara, sombra debajo; espinilla como arista de luz
    kx, ky = knee
    pc.plane([(kx - 2.6, ky - 2.4), (kx + 1.8, ky - 2.8), (kx + 2.2, ky + 0.6), (kx - 1.8, ky + 1.0)], 0.14, 0.8)
    pc.crease([(kx - 2.4, ky + 2.2), (kx + 2.2, ky + 1.8)], 0.18, 0.9)
    pc.crease([lerp(knee, ankle, 0.12), lerp(knee, ankle, 0.85)], -0.12, 0.9)
    pc.noise(0.09, 3.0, 40 + side, clip=["skin"])
    pc.pores(0.05, 0.08, 42 + side, clip=["skin"])
    # cardenal en la espinilla y arañazos
    if side > 0:
        pc.stain(lerp(knee, ankle, 0.4), 1.8, "skin_bruise", 44 + side, stretch=(0.8, 1.3), ring=0.0)
    if side < 0:
        pc.line([lerp(knee, ankle, 0.3), (lerp(knee, ankle, 0.42)[0] + 1.2, lerp(knee, ankle, 0.42)[1])], "blood", 0.45,
                inside=True)
    # suciedad que sube de los pies
    pc.stain((ankle[0], ankle[1] + 8), 5.5, "dirt", 47 + side, stretch=(1.0, 1.0), ring=0.04, val=0.5)
    return pc, rig.v(a, step)


def _arm_joints(rig: Rig, g: Gait, side: int):
    swing = g.swing_l if side > 0 else g.swing_r
    up = -g.breath * 0.8
    a = 16.0 * side
    sh = rig.p(a, 43 + g.bob + up, 1.0)
    el = rig.p(a + side * 1.6, 68 + g.bob + up * 0.5, 0.5 + swing * 0.45)
    return sh, el, swing, up, a


def sleeve_poly(rig: Rig, g: Gait, side: int) -> list[tuple[float, float]]:
    """Manga corta: va en la pieza de la bata; el brazo sale por el dobladillo."""
    sh, el, _, up, a = _arm_joints(rig, g, side)
    return limb(rig.p(a - side * 0.6, 40.5 + g.bob + up, 0.8), lerp(sh, el, 0.52), SLEEVE)


def arm_piece(rig: Rig, g: Gait, side: int) -> tuple[Piece, float]:
    pc = Piece(W, H, "arm")
    swing = g.swing_l if side > 0 else g.swing_r
    up = -g.breath * 0.8
    a = 16.0 * side
    sh = rig.p(a, 43 + g.bob + up, 1.0)
    el = rig.p(a + side * 1.6, 68 + g.bob + up * 0.5, 0.5 + swing * 0.45)
    wr = rig.p(a + side * 1.2, 92 + g.bob - abs(swing) * 0.2, 2.0 + swing)
    tip = rig.p(a + side * 1.0, 106 + g.bob - abs(swing) * 0.3, 3.4 + swing * 1.15)
    pc.fill(limb(sh, el, UPPER), "skin", 0.5)
    pc.fill(limb(el, wr, FORE), "skin", 0.5)
    wv = 2.6 + 1.0 * abs(rig.s)
    hand = limb(wr, tip, [(0.0, 2.1, 2.1), (0.3, wv, wv * 0.95), (0.62, wv * 0.92, wv * 0.85), (0.85, wv * 0.7, wv * 0.6),
                          (1.0, 1.2, 1.0)])
    pc.fill(hand, "skin", 0.52)
    pc.form(LIGHT, bevel=2.6, strength=0.32, rim_dark=0.12)
    # codo, tendones, nudillos, dedos
    pc.crease([(el[0] - 1.8, el[1] + 0.6), (el[0] + 1.8, el[1] + 0.4)], 0.16, 0.8)
    pc.dot(el[0], el[1] - 0.6, "skin", 0.74)
    pc.crease([lerp(el, wr, 0.3), lerp(el, wr, 0.9)], -0.1, 0.8)
    kn = lerp(wr, tip, 0.55)
    pc.crease([(kn[0] - wv * 0.8, kn[1]), (kn[0] + wv * 0.8, kn[1] - 0.4)], -0.14, 0.7)
    for k in (-0.35, 0.35):
        f0 = lerp(wr, tip, 0.62)
        f1 = lerp(wr, tip, 0.98)
        pc.crease([(f0[0] + k * wv, f0[1]), (f1[0] + k * wv * 0.6, f1[1])], 0.18, 0.6)
    pc.noise(0.08, 2.5, 50 + side, clip=["skin"])
    pc.veins(lerp(el, wr, 0.55), 6, 52 + side, ang=math.atan2(wr[1] - el[1], wr[0] - el[0]), depth=0.12, mat="skin_bruise")
    # lo que queda dentro de la manga no se ve (la manga va en la pieza de la bata)
    pc.erase(sleeve_poly(rig, g, side))
    # muñeca: pulsera (derecha) o vía arrancada (izquierda)
    if side < 0:
        b0, b1 = lerp(el, wr, 0.8), lerp(el, wr, 0.96)
        band = limb(b0, b1, [(0, 3.4, 3.4), (1, 3.2, 3.2)])
        pc.fill(band, "band", 0.62)
        pc.form(LIGHT, bevel=1.6, strength=0.3, rim_dark=0.08, region=pc.of("band"))
        mid = lerp(b0, b1, 0.5)
        pc.line([(mid[0] - 1.6, mid[1]), (mid[0] + 1.2, mid[1])], "band", 0.25, inside=True)   # texto de la etiqueta
        pc.dot(mid[0] - 1.6, b0[1] + 0.5, "band", 0.98)
    else:
        bk = lerp(wr, tip, 0.3)
        tape = [(bk[0] - 2.4, bk[1] - 1.6), (bk[0] + 2.2, bk[1] - 2.0), (bk[0] + 2.6, bk[1] + 1.6), (bk[0] - 2.0, bk[1] + 2.0)]
        pc.fill(tape, "tape", 0.6)
        pc.line([(bk[0] - 1.6, bk[1] - 0.4), (bk[0] + 1.8, bk[1] - 0.8)], "tape", 0.35, inside=True)
        pc.stain((bk[0] + 0.6, bk[1] + 3.0), 2.2, "blood", 57, stretch=(0.6, 2.2), ring=0.1, drip=1.0)
        # el tubo arrancado cuelga del esparadrapo
        tube = [(bk[0] + 0.4, bk[1] + 0.6), (bk[0] + 2.4, bk[1] + 5), (bk[0] + 1.6, bk[1] + 10),
                (bk[0] + 3.2, bk[1] + 15)]
        pc.line(tube, "tube", 0.55, width=1)
        pc.line(tube[:2], "tube", 0.8)
        pc.dot(tube[-1][0], tube[-1][1] + 1, "blood", 0.5, inside=False)
        pc.dot(tip[0] - 0.4, tip[1] + 2.0, "blood", 0.35, inside=False)
    v = rig.v(a, 1.0 + swing * 0.5)
    return pc, v


# =============================================================================================
# Bata
# =============================================================================================

def gown_piece(rig: Rig, g: Gait) -> Piece:
    pc = Piece(W, H, "gown")
    up = -g.breath * 0.8
    left, right = [], []
    for i, (y, wf, zf, zb) in enumerate(GOWN_ROWS):
        yy = y + g.bob + (up if y < 50 else 0)
        wob = WOBBLE[(i + g.sway) % len(WOBBLE)] if y > 70 else WOBBLE[i]
        corners = [rig.p(sa * (wf + wob), yy, z) for sa in (-1, 1) for z in (zf, zb)]
        xs = [p[0] for p in corners]
        ys = [p[1] for p in corners]
        left.append((min(xs), sum(ys) / 4))
        right.append((max(xs), sum(ys) / 4))
    # bajo en jirones (se balancea con el paso)
    lx, ly = left[-1]
    rx, ry = right[-1]
    hem = []
    n = 9
    for k in range(n + 1):
        t = k / n
        jag = (1.6 if (k + g.sway) % 2 else -0.6) + (0.8 if k % 3 == 0 else 0)
        hem.append((rx + (lx - rx) * t, ry + (ly - ry) * t + jag))
    poly = [*left[:-1]] + hem[::-1] + right[:-1][::-1]
    pc.fill(poly, "gown", 0.55)
    sleeves = []
    for side in (1, -1):
        sp = sleeve_poly(rig, g, side)
        sh, el, _, _, a = _arm_joints(rig, g, side)
        sleeves.append((sp, sh, lerp(sh, el, 0.52), rig.v(a, 1.0)))
        pc.fill(sp, "gown", 0.55)
    gm = pc.mask.copy()
    pc.form(LIGHT, bevel=5.0, strength=0.3, rim_dark=0.12)
    top = left[0][1]
    pc.plane([(0, top - 4), (W, top - 4), (W, top + 7), (0, top + 9)], 0.14, 2.0)      # hombros a la luz

    def surf(a: float, y: float, face: str) -> tuple[tuple[float, float], float]:
        wf, zf, zb = _rows(y)
        z = zf if face == "f" else zb
        return rig.p(a, y + g.bob, z), rig.v(a, z)

    def fold(points: list[tuple[float, float]], face: str, depth: float = 0.16, ridge: float = 0.1) -> None:
        sp = [surf(a, y, face) for a, y in points]
        if sum(v for _, v in sp) / len(sp) < 0.5:
            return
        pc.crease([p for p, _ in sp], depth, 1.3, ridge=ridge, ridge_off=(-1.3, 0), clip=["gown"])

    facing_front = rig.c > -0.25
    facing_back = rig.c < 0.25
    # pliegues de la cara delantera y la trasera (caen de los hombros y se abren en el bajo)
    for face in ("f", "b"):
        for a0, a1 in ((-9, -12), (-3.5, -5), (4, 6), (10, 13.5)):
            fold([(a0, 44), ((a0 + a1) / 2, 72), (a1, 100)], face)
    # pliegues de los costados (se ven de perfil)
    for sa in (-1, 1):
        sp = [rig.p(sa * _rows(y)[0] * 0.92, y + g.bob, (_rows(y)[1] + _rows(y)[2]) * 0.5) for y in (52, 74, 98)]
        if rig.v(sa * 14, 0) > 2:
            pc.crease(sp, 0.14, 1.2, ridge=0.08, ridge_off=(-1.2, 0), clip=["gown"])
    # arrugas de la axila y bajo el pecho
    if facing_front:
        p1, _ = surf(-12, 50, "f")
        p2, _ = surf(-6, 56, "f")
        pc.crease([p1, p2], 0.12, 1.0)
        p1, _ = surf(12, 50, "f")
        p2, _ = surf(6, 57, "f")
        pc.crease([p1, p2], 0.12, 1.0)
        # escote en pico con la piel del pecho
        neck = [surf(-6.5, 36, "f")[0], surf(-2.4, 41, "f")[0], surf(0, 45, "f")[0], surf(2.4, 41, "f")[0],
                surf(6.5, 36, "f")[0], surf(0, 34, "f")[0]]
        m = pc.poly_mask(neck) & gm
        pc.fill_mask(m, "skin", 0.48)
        pc.form(LIGHT, bevel=2.0, strength=0.2, rim_dark=0.15, region=pc.of("skin"))
        a0, _ = surf(-3.2, 38, "f")
        a1, _ = surf(3.2, 38, "f")
        pc.crease([a0, lerp(a0, a1, 0.5), a1], -0.12, 0.8, clip=["skin"])   # clavículas
        pc.crease(neck[:5], 0.18, 1.0, clip=["gown"])                         # ribete del escote
    if facing_back:
        # abertura trasera: la espalda desnuda, más ancha hacia la cintura
        opening = [(40, 1.2), (48, 4.0), (60, 6.2), (72, 6.8), (84, 6.2), (96, 4.8), (102, 4.2)]
        lpts = [surf(-w, y, "b")[0] for y, w in opening]
        rpts = [surf(w, y, "b")[0] for y, w in opening]
        strip = lpts + rpts[::-1]
        m = pc.poly_mask(strip) & gm
        pc.fill_mask(m, "skin", 0.5)
        sk = pc.of("skin")
        pc.form(LIGHT, bevel=2.2, strength=0.22, rim_dark=0.22, region=sk)
        # ropa interior
        br = [surf(-8, 88, "b")[0], surf(8, 88, "b")[0], surf(8, 104, "b")[0], surf(-8, 104, "b")[0]]
        pc.fill_mask(pc.poly_mask(br) & sk, "brief", 0.45)
        pc.crease([surf(-8, 89, "b")[0], surf(8, 89, "b")[0]], -0.15, 0.7, clip=["brief"])
        # omóplatos y columna
        for sa in (-1, 1):
            pc.crease([surf(sa * 3.4, 47, "b")[0], surf(sa * 5.6, 56, "b")[0]], 0.14, 1.0, ridge=0.1,
                      ridge_off=(-1, 0), clip=["skin"])
        spine = [surf(0, 44, "b")[0], surf(-0.3, 60, "b")[0], surf(0.2, 74, "b")[0], surf(0, 86, "b")[0]]
        pc.stain(surf(0, 64, "b")[0], 2.6, "skin_bruise", 61, stretch=(0.8, 4.5), ring=0.0, clip=["skin"])
        pc.line(spine, "flesh", 0.42, inside=True)
        pc.crease(spine, 0.1, 1.2, ridge=0.1, ridge_off=(1, 0), clip=["skin", "flesh", "skin_bruise"])
        for y in range(47, 85, 4):
            p0 = surf(-1.2, y, "b")[0]
            p1 = surf(1.2, y + 0.6, "b")[0]
            pc.line([p0, p1], "thread", 0.25, inside=True)
        pc.dot(*surf(0, 70, "b")[0], "blood", 0.4)
        pc.dot(*surf(0.3, 71, "b")[0], "blood", 0.3)
        # bordes de la abertura: la tela se dobla (canto claro, sombra sobre la piel)
        pc.crease(lpts, -0.14, 0.8, clip=["gown"])
        pc.crease([(x + 1, y) for x, y in rpts], 0.2, 1.0, clip=["skin", "skin_bruise"])
        # lazos: en la nuca y a media espalda
        for y in (41, 68):
            k0 = surf(-2.0, y, "b")[0]
            k1 = surf(2.0, y + 0.5, "b")[0]
            pc.line([k0, k1], "gown", 0.7, width=1)
            pc.line([lerp(k0, k1, 0.5), (lerp(k0, k1, 0.5)[0] - 1, lerp(k0, k1, 0.5)[1] + 5)], "gown", 0.62)
    # mangas: pliegue que baja del hombro, dobladillo y la boca oscura de la manga
    for sp, sh, send, v in sleeves:
        if v < -8:
            continue
        pc.crease([lerp(sh, send, 0.25), lerp(sh, send, 0.95)], 0.12, 1.0, ridge=0.08, ridge_off=(-1.2, 0))
        hx, hy = send
        pc.crease([(hx - 6, hy - 0.8), (hx + 6, hy - 1.2)], 0.18, 0.9)
        pc.plane([(hx - 7, hy - 0.4), (hx + 7, hy - 0.8), (hx + 7, hy + 3), (hx - 7, hy + 3)], -0.2, 0.6,
                 clip=["gown"])
    # textura: trama, estampado de rombos desvaído, sudor, mugre en el bajo, sangre
    pc.weave(0.05, 1, clip=["gown"])
    yy, xx = np.mgrid[0:H, 0:W]
    print_ = ((xx + yy) % 7 == 0) & ((xx - yy) % 7 == 0) & pc.of("gown")
    pc.val[print_] -= 0.09
    pc.noise(0.08, 6.0, 70, clip=["gown"])
    lo = left[-1]
    pc.stain((lo[0] + 8, lo[1] - 2), 7.0, "dirt", 71, stretch=(1.6, 0.6), ring=0.05, val=0.45, clip=["gown"])
    if facing_front:
        pc.stain(surf(9, 60, "f")[0], 3.0, "blood", 72, stretch=(0.8, 1.6), ring=0.12, drip=1.2, clip=["gown"])
    if facing_back:
        pc.stain(surf(5, 96, "b")[0], 2.4, "blood", 73, stretch=(0.8, 1.4), ring=0.1, clip=["gown"])
    pc.plane([(0, ly - 6), (W, ry - 6), (W, H), (0, H)], -0.16, 2.0)                # bajo en sombra
    return pc


# =============================================================================================
# Montaje
# =============================================================================================

def frame(direction: str, g: Gait) -> Image.Image:
    rig = Rig(DIRECTIONS[direction])
    legs = [leg_piece(rig, g, s) for s in (1, -1)]
    arms = [arm_piece(rig, g, s) for s in (1, -1)]
    legs.sort(key=lambda t: t[1])
    arms.sort(key=lambda t: t[1])
    gown = gown_piece(rig, g)
    head = head_piece(rig, g)
    behind = [p for p, v in arms if v < -0.5]
    front = [p for p, v in arms if v >= -0.5]
    pieces = behind + [p for p, _ in legs] + [gown] + front + [head]
    if rig.c < -0.3:                      # de espaldas, la cabeza va detrás de los hombros
        pieces = behind + [p for p, _ in legs] + [gown, head] + front
    return compose(pieces, (W, H), contact=0.22)


def walk(direction: str) -> list[Image.Image]:
    return [frame(direction, g) for g in WALK]


if __name__ == "__main__":
    from paint import row, upscale
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n/hd_proto.png"
    dirs = sys.argv[2].split(",") if len(sys.argv) > 2 else ["S", "SW", "W", "NW", "N"]
    ims = [frame(d, IDLE[0]) for d in dirs]
    upscale(row(ims), 3).save(out)
