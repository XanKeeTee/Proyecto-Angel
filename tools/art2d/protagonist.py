"""Protagonista (paciente de la Habitación 09) dibujado en 2D: mapa en 8 direcciones.

Rasgos (docs/art/guia-estetica.md): hombre, cráneo rapado con cicatriz cosida, ojos hundidos,
bata de hospital abierta por detrás con la incisión cosida de la columna a la vista, pieza
metálica entre los omóplatos [PROPUESTA], pulsera en la muñeca derecha, vía arrancada en la
mano izquierda, descalzo y con los pies sucios.

Cómo se dibuja: cada vista es un conjunto de polígonos trazados a mano sobre una rejilla de
diseño de 48×68 que la pluma (`Pen`) lleva al fotograma real (56×80, figura de ~68 px). Brazos y
piernas son perfiles angulosos (`px2d.limb`) entre articulaciones de un esqueleto 2D que el paso
desplaza; las cabezas se dibujan píxel a píxel a resolución final (`HEAD_*`).

Vistas propias: S (frente), SW (tres cuartos de frente), W (perfil), NW (tres cuartos de
espaldas), N (espalda). E, SE y NE son el espejo de W, SW y NW, pero los detalles asimétricos
(pulsera y vía) se dibujan antes de reflejar en la mano que corresponde. La luz viene de arriba y
de frente: las sombras laterales caen en el lado de la espalda, así el espejo no la contradice.
"""

from __future__ import annotations

import os
import sys
from dataclasses import dataclass

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import palette  # noqa: E402,F401  (registra las rampas)
from pen import Pen  # noqa: E402
from px2d import Part, compose, ramp  # noqa: E402

ramp("brief", ["#16171c", "#262830", "#3a3d45"])  # ropa interior oscura

GROUND = 62  # y de la planta del pie en la rejilla de diseño
CX = 24      # eje vertical del cuerpo en la rejilla de diseño

FRAME_W, FRAME_H = 56, 80   # propuesta: algo mayor que 48×68
FRAME_ORIGIN = (28, 74)     # punto de apoyo (entre los pies), en píxeles del fotograma
SCALE = 68 / 58             # figura de ~68 px

# Perfiles de extremidad: (t, ancho a la izquierda, ancho a la derecha) respecto a la dirección
# del hueso (de la articulación de arriba a la de abajo).
THIGH = [(0.0, 1.6, 1.6), (0.45, 1.5, 1.4), (0.85, 1.1, 1.1), (1.0, 1.25, 1.25)]
SHIN = [(0.0, 1.25, 1.25), (0.08, 1.45, 1.25), (0.3, 1.15, 1.5), (0.55, 1.0, 1.15), (0.9, 0.7, 0.7), (1.0, 0.8, 0.8)]
# De perfil mirando a la izquierda: la izquierda del hueso (que baja) es la espalda de la pierna.
THIGH_SIDE = [(0.0, 2.2, 1.8), (0.4, 2.0, 1.6), (0.85, 1.3, 1.3), (1.0, 1.4, 1.4)]
SHIN_SIDE = [(0.0, 1.4, 1.4), (0.12, 1.5, 1.1), (0.32, 1.9, 0.9), (0.6, 1.2, 0.8), (0.92, 0.75, 0.75), (1.0, 0.9, 0.9)]
UPPER_ARM = [(0.0, 1.4, 1.4), (0.5, 1.1, 1.1), (0.9, 0.9, 0.9), (1.0, 1.1, 1.1)]
FOREARM = [(0.0, 1.0, 1.0), (0.25, 1.2, 1.1), (0.8, 0.75, 0.75), (1.0, 0.75, 0.75)]


@dataclass
class Gait:
    """Un fotograma del paso o del reposo. Desplazamientos en píxeles de diseño."""

    bob: float = 0.0          # cuerpo arriba (-) / abajo (+)
    # Pierna «a» (izquierda de la pantalla o, de perfil, la cercana) y «b»: avance del pie
    # (+ = hacia donde camina) y alzado (rodilla doblada).
    a_step: float = 0.0
    a_lift: float = 0.0
    b_step: float = 0.0
    b_lift: float = 0.0
    a_swing: float = 0.0      # balanceo de la mano (+ = adelante)
    b_swing: float = 0.0
    breath: float = 0.0       # hombros (reposo)
    lean: float = 0.0         # tronco adelantado (perfil)


IDLE = [Gait(), Gait(breath=1.0)]
# Contacto, paso, contacto opuesto, paso. La pierna derecha («b» de frente) da el paso más corto.
WALK = [
    Gait(bob=1, a_step=3.0, b_step=-2.6, a_swing=-2, b_swing=2, lean=0.5),
    Gait(bob=0, a_step=0.4, b_step=0.6, b_lift=2.6, a_swing=-0.5, b_swing=0.5),
    Gait(bob=1, a_step=-2.6, b_step=2.4, a_swing=2, b_swing=-2, lean=0.5),
    Gait(bob=0, a_step=0.6, a_lift=2.6, b_step=0.4, a_swing=0.5, b_swing=-0.5),
]

LEG = {
    "s": ("scalp", 2), "S": ("scalp", 3), "H": ("scalp", 4), "q": ("scalp", 1), "Q": ("scalp", 0),
    "r": ("blood", 2), "R": ("blood", 1), "t": ("thread", 0), "T": ("thread", 1),
    "D": ("skin", 0), "d": ("skin", 1), "k": ("skin", 2), "K": ("skin", 3), "L": ("skin", 4),
    "o": ("socket", 0), "O": ("socket", 1), "m": ("lips", 0), "n": ("lips", 1),
    "E": ("skin", 1),
}

# --- cabezas (a resolución final; '.' = vacío) ---------------------------------------------
# Frente: la cicatriz sube de la sien izquierda a la coronilla con puntadas a los lados.
HEAD_S = [
    "....qssq....",
    "..qsSHSSsq..",
    ".qsSHtrtSssq",
    ".sSHtrtSSssq",
    ".sStrtSSSssq",
    "kLLrLKKLLKdE",
    "kOooKKKooOdE",
    "kdoOdLkOodkE",
    ".dKkdKkdKkd.",
    ".dkdkddkdkD.",
    "..dkmmmmkd..",
    "..DdkKKkdD..",
    "....dddd....",
]
# Tres cuartos de frente (mira abajo a la izquierda): la nariz se sale del óvalo, oreja derecha.
HEAD_SW = [
    "....qsssq...",
    "..qsSHHSsq..",
    ".qsSHtrtSsq.",
    ".sSHtrtSSssq",
    "qsStrtSSsssq",
    "LLrLKKLKdsqq",
    "ooOKKoOkdEkq",
    "oOdLkOodkEEq",
    "LkdKkKkdkEd.",
    "dkdkddkdkd..",
    ".kmmmkkdD...",
    ".dkKKkdD....",
    "..dddd......",
]
# Perfil mirando a la izquierda: ceja saliente, cuenca honda, nariz, mandíbula y nuca.
HEAD_W = [
    "....qsssq...",
    "..qsSHHSSq..",
    ".qsSHHSSssq.",
    ".sSHSSStrsq.",
    ".sSSSSrtssq.",
    ".KLSSsstrsqq",
    "LKdKSssssqtq",
    ".oOkkkEEdqsq",
    "LkKkkEkEdqq.",
    "dkkkkkkdDq..",
    ".mkKkkkdD...",
    ".dKkkkdD....",
    "..dddD......",
]
# Tres cuartos de espaldas (mira arriba a la izquierda): nuca, oreja y un filo de mejilla.
HEAD_NW = [
    "...qsssq....",
    ".qsSHHSsq...",
    "qsSHHSSssq..",
    "sSHSSSSsssq.",
    "sSSSSSSStrq.",
    "kSSSSSsstrsq",
    "LkSSSSsssrtq",
    "dEkSSsssssrq",
    "dEESssssssqq",
    ".dkqsssssqq.",
    "..dkkkkkdq..",
    "..DdkKkkd...",
    "...dddd.....",
]
# Espalda: la cicatriz baja por detrás de la coronilla hasta la nuca.
HEAD_N = [
    "....qssq....",
    "..qsSHSSsq..",
    ".qsSHHSSssq.",
    ".sSHSSSStrq.",
    ".sSSSSSrtsq.",
    "ksSSSSSstrsE",
    "kSSSSSsssrtE",
    "kSSSSSsssrsE",
    ".sSSSssssqq.",
    ".qsSssssqqq.",
    "..dkKKkkd...",
    "..DdkKkkdD..",
    "....dddd....",
]


def _mirror(pts):
    return [(48 - x, y) for x, y in pts]


# =============================================================================================
# Piezas comunes
# =============================================================================================

def _foot_front(pen: Pen, a, step: float, lift: float, toe_dir: float, back: bool):
    """Pie de frente (empeine y dedos) o de espaldas (talón sucio)."""
    fx, fy = a
    if back:
        hy = fy + 3.0 - lift * 0.2
        pen.poly([(fx - 1.3, fy), (fx + 1.2, fy), (fx + 1.4, hy), (fx - 1.4, hy)], "skin", 2)
        pen.line([(fx - 1.2, hy), (fx + 1.2, hy)], "dirt", 1 if lift < 1 else 0)
        if lift > 1:   # se ve la planta sucia del pie que se levanta
            pen.poly([(fx - 1.4, hy - 1.6), (fx + 1.4, hy - 1.6), (fx + 1.4, hy), (fx - 1.4, hy)], "dirt", 2)
        pen.px(fx - 0.6, fy + 0.6, "skin", 3)
        return
    toe = fy + 3.6 + step * 0.3 - lift * 0.4
    pts = [(fx - 1.4, fy + 0.2), (fx + 1.2, fy + 0.2), (fx + 2.0 + toe_dir, toe), (fx - 2.2 + toe_dir, toe)]
    pen.poly(pts, "skin", 2)
    pen.line([(fx - 2.0 + toe_dir, toe), (fx + 1.8 + toe_dir, toe)], "dirt", 1)
    pen.pxs([(fx - 1.4 + toe_dir, toe - 1), (fx + 0.6 + toe_dir, toe - 1)], "dirt", 2, inside=True)
    pen.px(fx - 0.5, fy + 0.6, "skin", 3)
    pen.shade([(fx - 3, toe - 1.6), (fx + 3, toe - 1.6), (fx + 3, toe + 1), (fx - 3, toe + 1)],
              mat="dirt", tone=1, pattern="checker")


def _leg_front(pen: Pen, hip, knee, ankle, step: float, lift: float, toe_dir: float = 0.0,
               back: bool = False, side_dx: float = 0.0):
    """Pierna de frente/espaldas. `step` > 0 = el pie va hacia donde camina: de frente baja
    (se acerca), de espaldas sube (se aleja). `side_dx`: en tres cuartos, el paso también se
    desplaza en horizontal."""
    sgn = -1.0 if back else 1.0
    ay = ankle[1] - lift + sgn * step * 0.4
    ky = knee[1] - lift * 0.55 + sgn * step * 0.2
    k = (knee[0] + side_dx * step * 0.5, ky)
    a = (ankle[0] + side_dx * step, ay)
    pen.limb(hip, k, THIGH, "skin", 2)
    pen.limb(k, a, SHIN, "skin", 2)
    if back:
        pen.px(k[0] - 0.5, k[1] + 0.5, "skin", 1)          # corva
        pen.line([(k[0] - 1.0, k[1] + 2.0), (k[0] - 1.2, k[1] + 4.6)], "skin", 3, inside=True)  # gemelo
        pen.line([(a[0] - 0.2, a[1] - 3.0), (a[0] - 0.2, a[1] - 0.6)], "skin", 1, inside=True)  # tendón
    else:
        pen.px(k[0] - 0.5, k[1] - 0.5, "skin", 3)          # rótula
        pen.px(k[0] - 0.5, k[1] + 1.5, "skin", 1)
        pen.line([(k[0] - 0.6, k[1] + 3), (a[0] - 0.4, a[1] - 2)], "skin", 3, inside=True)  # espinilla
    _foot_front(pen, a, step, lift, toe_dir, back)


def _hand(pen: Pen, w, dirx: float = 0.0):
    hx, hy = w
    pen.poly([(hx - 1.2, hy), (hx + 1.1, hy), (hx + 1.3 + dirx * 0.3, hy + 2.4), (hx + 0.5 + dirx * 0.5, hy + 4.2),
              (hx - 0.7 + dirx * 0.5, hy + 4.0), (hx - 1.4, hy + 2.2)], "skin", 2)
    pen.px(hx - 0.4, hy + 3.4, "skin", 1)     # separación de los dedos
    pen.px(hx + 0.6, hy + 2.6, "skin", 1)
    pen.px(hx - 0.6, hy + 0.8, "skin", 3)     # nudillo


def _arm_hanging(pen: Pen, sh, el, wr, swing: float):
    """Brazo colgando visto de frente/espaldas. `swing` acorta (atrás) o alarga (adelante)."""
    e = (el[0], el[1] + swing * 0.2)
    w = (wr[0], wr[1] + swing * 0.6)
    pen.limb(sh, e, UPPER_ARM, "skin", 2)
    pen.limb(e, w, FOREARM, "skin", 2)
    pen.px(e[0] - 0.5, e[1], "skin", 1)  # codo
    pen.line([(e[0] - 0.4, e[1] + 1.5), (w[0] - 0.4, w[1] - 1.5)], "skin", 3, inside=True)
    _hand(pen, w)
    return w


def _bracelet(pen: Pen, wrist, wide: float = 1.3):
    x, y = wrist
    pen.poly([(x - wide, y - 1.4), (x + wide, y - 1.4), (x + wide, y - 0.2), (x - wide, y - 0.2)], "band", 2)
    pen.px(x + wide - 0.6, y - 1.0, "band", 0)
    pen.px(x - wide + 0.2, y - 1.0, "band", 1)


def _iv_torn(pen: Pen, wrist, dirx: float = 1.0):
    """Vía arrancada: esparadrapo en el dorso, un trozo de tubo colgando y sangre."""
    x, y = wrist
    pen.poly([(x - 1.2, y + 0.2), (x + 1.0, y + 0.2), (x + 1.0, y + 1.6), (x - 1.2, y + 1.6)], "gown", 3)
    pen.line([(x + 0.4 * dirx, y + 1.2), (x + 1.5 * dirx, y + 4.0), (x + 1.0 * dirx, y + 6.5)], "tube", 1)
    pen.px(x - 0.5, y + 2.2, "blood", 2)
    pen.px(x + 0.5, y + 2.6, "blood", 1)
    pen.px(x - 0.5, y + 3.6, "blood", 1, inside=True)


def _wrist_detail(pen: Pen, wrist, who: str, dirx: float):
    if who == "R":
        _bracelet(pen, wrist)
    else:
        _iv_torn(pen, wrist, dirx)


# =============================================================================================
# Frente, espalda y tres cuartos
# =============================================================================================

def view_frontal(pen: Pen, g: Gait, back: bool, turn: float, ids: tuple[str, str]) -> list[Part]:
    """Vistas S, N, SW y NW. `turn` = 0 de frente o de espaldas; 1 = tres cuartos (el cuerpo se
    estrecha y los ejes de la bata, cuello y columna se desplazan hacia donde mira). `ids` dice
    qué brazo físico (R/L) está a la izquierda y a la derecha de la pantalla."""
    W, H = pen.part.w, pen.part.h
    s, bo, o = pen.s, pen.bo, pen.o
    k = 1.0 - 0.14 * turn                       # estrechamiento horizontal
    face = -1.0 if turn else 0.0                 # hacia dónde mira en tres cuartos (izquierda)

    def X(x: float, shift: float = 0.0) -> float:
        return CX + (x - CX) * k + shift

    def P(pts, shift: float = 0.0):
        return [(X(x, shift), y) for x, y in pts]

    def new_pen(dy=0.0):
        return Pen(Part(W, H), s, bo, o, dy=g.bob + dy)

    up = -g.breath * 0.6
    axis = 2.2 * turn * (1 if back else -1)      # eje del pecho/columna en tres cuartos
    # cerca y lejos en tres cuartos: de frente el brazo cercano es el de la derecha de la pantalla
    near_b = not back

    # --- piernas ---
    legs = Pen(Part(W, H), s, bo, o)
    hip_a, hip_b = (X(21.4, -0.4 * turn), 38 + g.bob), (X(26.6, -0.4 * turn), 38 + g.bob)
    side = 0.5 * turn * (-1)                     # en tres cuartos el paso se va en diagonal
    order = [("a", hip_a, 21.2, g.a_step, g.a_lift), ("b", hip_b, 26.8, g.b_step, g.b_lift)]
    if turn:
        order = order[::-1] if not back else order   # la pierna lejana primero
    for _, hip, kx, step, lift in order:
        _leg_front(legs, hip, (X(kx, -0.6 * turn), 47.5), (X(kx, -0.8 * turn), 57.5), step, lift,
                   toe_dir=face * 1.0, back=back, side_dx=side)
    legs.part.rim(1, 0, 1, delta=-1, clip="skin")
    legs.part.rim(0, -1, 1, tone=1, clip="skin")

    # --- brazos: el lejano va detrás del cuerpo en tres cuartos ---
    sh_a, el_a, wr_a = (X(17.0), 19.5 + up), (X(16.2), 28.5), (X(16.4), 37.2)
    sh_b, el_b, wr_b = (X(31.0), 19.5 + up), (X(31.8), 28.5), (X(31.6), 37.2)
    if turn:
        if near_b:
            sh_a, el_a, wr_a = (sh_a[0] + 1.2, sh_a[1]), (el_a[0] + 1.6, el_a[1]), (wr_a[0] + 1.8, wr_a[1])
        else:
            sh_b, el_b, wr_b = (sh_b[0] - 1.2, sh_b[1]), (el_b[0] - 1.6, el_b[1]), (wr_b[0] - 1.8, wr_b[1])
    swing_sign = -1.0 if back else 1.0
    arm_a, arm_b = new_pen(), new_pen()
    wa = _arm_hanging(arm_a, sh_a, el_a, wr_a, g.a_swing * swing_sign)
    wb = _arm_hanging(arm_b, sh_b, el_b, wr_b, g.b_swing * swing_sign)
    for pp, wrist, who in ((arm_a, wa, ids[0]), (arm_b, wb, ids[1])):
        pp.part.rim(1, 0, 1, delta=-1, clip="skin")
        if not back or who == "R":
            _wrist_detail(pp, wrist, who, 1 if wrist[0] > CX else -1)
        else:
            # de espaldas la vía cuelga por la palma: se ve el tubo y la sangre
            pp.line([(wrist[0], wrist[1] + 1.4), (wrist[0] + 0.8, wrist[1] + 5.6)], "tube", 1)
            pp.px(wrist[0] - 0.4, wrist[1] + 2.4, "blood", 1)

    # --- bata (cuerpo) ---
    body = new_pen()
    hem = [(31.0, 43.6), (29.4, 44.6), (27.6, 43.4), (25.6, 44.8), (23.4, 43.6), (21.2, 44.8), (19.0, 43.4),
           (17.2, 44.4), (16.6, 42.6)]
    side_r = [(29.8, 16.4 + up), (30.4, 18.4), (29.8, 23.2), (29.6, 30), (30.4, 36.4), (31.6, 41.4)]
    side_l = [(17.6, 36.4), (18.4, 30), (18.2, 23.2), (17.6, 18.4), (18.2, 16.4 + up)]
    if back:
        neck = [(20.4, 15.2 + up), (22.6, 14.6 + up), (25.4, 14.6 + up), (27.6, 15.2 + up)]
    else:
        neck = [(20.6, 15.6 + up), (22.4, 16.6 + up), (23.4, 19.6 + up), (24.6, 19.6 + up), (25.6, 16.6 + up),
                (27.4, 15.6 + up)]
    gown = P(neck, axis) + P(side_r) + P(hem) + P(side_l)
    body.poly(gown, "gown", 3)
    body.shade(P([(17, 14), (31, 14), (31, 19.4), (17, 19.4)]), tone=4)
    # pliegues angulosos que caen y se abren en el bajo
    body.line(P([(21.0, 21), (20.2, 29), (19.6, 36), (18.8, 43)]), "gown", 2, inside=True)
    body.line(P([(27.0, 21.5), (27.8, 29), (28.6, 36), (29.6, 43)]), "gown", 2, inside=True)
    body.shade(P([(27.6, 22), (29.8, 22), (30.4, 36.4), (31.6, 41.4), (31.0, 43.6), (29.0, 43)]), tone=2)
    body.shade(P([(28.6, 31), (29.8, 31), (31.4, 41.4), (30.8, 43.6), (29.4, 43)]), tone=1, pattern="checker")
    body.part.rim(0, 1, 1, tone=1, clip="gown")
    if not back:
        body.line(P([(24.2, 27), (23.6, 35), (23.8, 43)], axis), "gown", 2, inside=True)
        body.shade(P([(21.6, 20.6), (26.6, 20.6), (26, 22.4), (22, 22.4)], axis), tone=2)
        body.shade(P([(27.6, 23.2), (29.4, 23.2), (29.4, 25.6), (28.0, 26)]), mat="stain", tone=1, pattern="checker")
        body.pxs(P([(25, 33), (26, 33), (25, 34), (26, 35)], axis), "blood", 1, inside=True)
        body.px(X(24, axis), 34, "blood", 2, inside=True)
    else:
        # La bata se abre por detrás: una franja de espalda desnuda que se ensancha hacia la
        # cintura, con la incisión cosida sobre la columna y la pieza metálica en los omóplatos.
        c = X(24, axis)
        gap = [(c - 1.2, 16.0 + up), (c + 1.2, 16.0 + up), (c + 2.6, 27), (c + 3.0, 36), (c + 1.6, 44.6),
               (c - 1.4, 44.6), (c - 2.6, 36), (c - 2.2, 27)]
        body.poly(gap, "skin", 2, inside=True)
        body.shade([(c - 3.2, 37.6), (c + 3.4, 37.6), (c + 3.4, 45), (c - 3.2, 45)], mat="brief", tone=1, clip="skin")
        body.shade([(c - 3.2, 37.6), (c + 3.4, 37.6), (c + 3.4, 38.6), (c - 3.2, 38.6)], tone=2, clip="brief")
        # bordes de la abertura: la tela se dobla hacia dentro (canto claro y sombra en la piel)
        body.line([(c - 1.4, 16.4 + up), (c - 2.4, 27), (c - 2.8, 36), (c - 1.6, 44)], "gown", 4)
        body.line([(c + 1.4, 16.4 + up), (c + 2.8, 27), (c + 3.2, 36), (c + 1.8, 44)], "gown", 2)
        body.line([(c + 1.0, 18), (c + 2.0, 27), (c + 2.2, 35)], "skin", 1, inside=True, clip="skin")
        # lazos de la bata: cuello y media espalda
        body.pxs([(c - 0.5, 16.6 + up), (c + 0.5, 16.6 + up)], "gown", 3)
        body.pxs([(c - 2.0, 29), (c - 1.0, 30), (c + 1.0, 30), (c + 2.0, 29)], "gown", 3)
        body.pxs([(c - 0.5, 31), (c + 1.5, 31.6)], "gown", 2)
        # pieza metálica entre los omóplatos: placa con dos tornillos y la piel amoratada alrededor
        body.poly([(c - 1.8, 19.4), (c + 1.8, 19.4), (c + 1.8, 23.8), (c - 1.8, 23.8)], "skin", 1, clip="skin")
        body.poly([(c - 1.2, 20.0), (c + 1.2, 20.0), (c + 1.2, 23.2), (c - 1.2, 23.2)], "metal", 3)
        body.px(c - 1.2, 20.0, "metal", 4)
        body.px(c - 0.2, 20.0, "metal", 4)
        body.px(c - 1.2, 22.4, "metal", 1)
        body.px(c + 0.6, 22.4, "metal", 2)
        body.px(c + 0.6, 23.4, "flesh", 1)
        # incisión cosida a lo largo de la columna, con puntadas que la cruzan
        body.line([(c - 0.2, 24.6), (c - 0.4, 30), (c - 0.2, 36.8)], "flesh", 2, clip="skin", inside=True)
        for yy in (25.8, 28.4, 31.0, 33.6):
            body.px(c - 1.4, yy, "thread", 1, inside=True)
            body.px(c + 0.6, yy, "thread", 1, inside=True)
        body.px(c - 0.4, 35.6, "blood", 1, inside=True)
        # omóplatos: aristas de luz y sombra junto a la abertura
        body.pxs([(c - 3.4, 21), (c - 3.0, 22)], "gown", 2, inside=True)
        body.pxs([(c + 3.0, 21), (c + 3.4, 22)], "gown", 2, inside=True)

    # --- mangas: casquillo corto que se abre hacia el codo ---
    sl = [(17.6, 16.0 + up), (20.2, 16.8 + up), (19.8, 21.0), (18.6, 22.8), (15.4, 23.2), (14.8, 21.6), (15.4, 18.0)]
    sl_a, sl_b = P(sl), P(_mirror(sl))
    if turn:
        if near_b:
            sl_a = [(x + 1.2, y) for x, y in sl_a]
        else:
            sl_b = [(x - 1.2, y) for x, y in sl_b]
    # De frente y de espaldas las mangas van en la misma pieza que la bata (sin contorno entre
    # ellas); en tres cuartos, la manga cercana va en su propia pieza por encima del brazo.
    sleeves_a = body if not turn else new_pen()
    sleeves_b = body if not turn else new_pen()
    for sp, pts, lit in ((sleeves_a, sl_a, True), (sleeves_b, sl_b, False)):
        sp.poly(pts, "gown", 3)
        top = min(y for _, y in pts)
        xs = [x for x, _ in pts]
        x0, x1 = min(xs) - 1, max(xs) + 1
        sp.shade([(x0, top - 1), (x1, top - 1), (x1, top + 2.6), (x0, top + 3.4)], tone=4, clip="gown")
        sp.line([(x0 + 1.6, 22.6), (x1 - 1.0, 21.6)], "gown", 2 if lit else 1, inside=True)
        sp.line([((x0 + x1) / 2, top + 3.2), ((x0 + x1) / 2 - 0.6, 22.0)], "gown", 2, inside=True)

    # --- cabeza y cuello ---
    head = new_pen()
    nx = X(24, axis * 0.6) + face * 0.6
    head.poly([(nx - 2.0, 12.6), (nx + 2.0, 12.6), (nx + 2.8, 16.6), (nx - 2.8, 16.6)], "skin", 1)
    if back:
        head.pxs([(nx - 1.5, 14), (nx + 0.5, 14)], "skin", 2)    # tendones de la nuca
    else:
        head.pxs([(nx - 2, 15), (nx + 1, 15)], "skin", 2)
        head.poly([(nx - 3.0, 16.0), (nx + 3.0, 16.0), (nx + 0.8, 19.2), (nx - 0.8, 19.2)], "skin", 2)
        head.px(nx - 0.5, 17.2, "skin", 0)
    if back:
        art = HEAD_NW if turn else HEAD_N
    else:
        art = HEAD_SW if turn else HEAD_S
    head.pixmap(art, (nx + face * 0.8, 4.6), LEG, hot=(6, 0))

    if turn and not back:
        # de tres cuartos de frente: el brazo de la izquierda queda detrás del cuerpo
        return [arm_a.part, sleeves_a.part, legs.part, body.part, arm_b.part, sleeves_b.part, head.part]
    if turn and back:
        return [arm_b.part, sleeves_b.part, legs.part, body.part, arm_a.part, sleeves_a.part, head.part]
    return [legs.part, arm_a.part, arm_b.part, body.part, head.part]


# =============================================================================================
# Perfil (mira a la izquierda)
# =============================================================================================

def _leg_side(pen: Pen, hip, step: float, lift: float, shade: int = 0):
    """Pierna de perfil mirando a la izquierda. `step` > 0 adelanta el pie (a la izquierda)."""
    ax = hip[0] - step * 1.6
    ay = 57.5 - lift
    kx = hip[0] - step * 0.7 - lift * 0.9
    ky = 47.5 - lift * 0.45
    k, a = (kx, ky), (ax, ay)
    t2 = 2 + shade
    pen.limb(hip, k, THIGH_SIDE, "skin", t2)
    pen.limb(k, a, SHIN_SIDE, "skin", t2)
    pen.px(k[0] - 1.4, k[1] - 0.5, "skin", 3 + shade)                   # rótula
    pen.line([(k[0] - 1.0, k[1] + 2.0), (a[0] - 0.6, a[1] - 1.6)], "skin", 3 + shade, inside=True)
    # pie: talón, empeine y dedos; si se levanta, los dedos cuelgan
    foot = [(ax + 1.2, ay - 0.6), (ax + 1.8, ay + 2.4), (ax + 1.4, ay + 3.6),
            (ax - 4.4, ay + 3.6), (ax - 4.6, ay + 2.6), (ax - 1.6, ay + 1.2), (ax - 0.8, ay - 0.6)]
    if lift > 1:
        foot = [(ax + 1.2, ay - 0.6), (ax + 2.2, ay + 1.6), (ax + 1.0, ay + 2.6), (ax - 3.4, ay + 4.6),
                (ax - 4.0, ay + 3.6), (ax - 1.6, ay + 1.0), (ax - 0.8, ay - 0.6)]
    pen.poly(foot, "skin", 2 + shade)
    if lift <= 1:
        pen.line([(ax - 4.2, ay + 3.6), (ax + 1.2, ay + 3.6)], "dirt", 1)
        pen.px(ax - 4.0, ay + 2.8, "dirt", 2, inside=True)
    else:
        pen.line([(ax + 1.4, ay + 2.4), (ax - 3.2, ay + 4.4)], "dirt", 1)
    pen.px(ax - 0.2, ay + 0.6, "skin", 3 + shade)                        # tobillo


def _arm_side(pen: Pen, sh, swing: float, shade: int = 0):
    """Brazo de perfil: colgando, algo adelantado (encorvado), balanceándose."""
    el = (sh[0] - swing * 0.6 + 0.6, sh[1] + 8.8)
    wr = (el[0] - swing * 1.0 - 0.8, el[1] + 8.4 - abs(swing) * 0.3)
    pen.limb(sh, el, UPPER_ARM, "skin", 2 + shade)
    pen.limb(el, wr, FOREARM, "skin", 2 + shade)
    pen.px(el[0] + 0.6, el[1], "skin", 1 + shade)
    hx, hy = wr
    pen.poly([(hx - 1.0, hy - 0.2), (hx + 1.2, hy - 0.2), (hx + 1.0, hy + 2.6), (hx - 0.2, hy + 4.2),
              (hx - 1.4, hy + 3.2)], "skin", 2 + shade)
    pen.px(hx - 0.8, hy + 2.6, "skin", 1 + shade)
    pen.px(hx + 0.4, hy + 0.6, "skin", 3 + shade)
    return wr


def view_side(pen: Pen, g: Gait, ids: tuple[str, str]) -> list[Part]:
    """Perfil mirando a la izquierda. `ids` = (brazo cercano, brazo lejano): mirando a la
    izquierda se ve el costado izquierdo (cercano = L)."""
    W, H = pen.part.w, pen.part.h
    s, bo, o = pen.s, pen.bo, pen.o
    up = -g.breath * 0.6
    L = -0.8 - g.lean                       # encorvado: hombros y cabeza adelantados

    def new_pen(dy: float = 0.0):
        return Pen(Part(W, H), s, bo, o, dy=dy)

    hip = (24.6, 38 + g.bob)
    far_leg, near_leg = new_pen(), new_pen()
    idle = g.a_step == 0 and g.b_step == 0
    _leg_side(far_leg, (hip[0] + 0.6, hip[1]), g.b_step - (0.8 if idle else 0), g.b_lift, shade=-1)
    _leg_side(near_leg, hip, g.a_step + (0.6 if idle else 0), g.a_lift)
    for lp in (far_leg, near_leg):
        lp.part.rim(1, 0, 1, delta=-1, clip="skin")

    far_arm, near_arm = new_pen(g.bob), new_pen(g.bob)
    wf = _arm_side(far_arm, (25.4 + L, 19.6 + up), g.b_swing, shade=-1)
    wn = _arm_side(near_arm, (24.6 + L, 19.8 + up), g.a_swing)
    near_arm.part.rim(1, 0, 1, delta=-1, clip="skin")
    _wrist_detail(near_arm, wn, ids[0], 1)
    if ids[1] == "R":
        far_arm.px(wf[0] - 0.4, wf[1] - 0.6, "band", 1)
        far_arm.px(wf[0] + 0.6, wf[1] - 0.6, "band", 1)

    body = new_pen(g.bob)
    gown = [
        (22.4 + L, 15.4 + up), (25.6 + L, 15.0 + up), (28.0, 16.6 + up), (29.4, 19.6), (29.6, 23.0),
        (28.8, 28), (29.0, 36), (29.8, 42.6), (28.6, 44.4), (26.8, 43.4), (24.8, 44.6), (22.6, 43.6),
        (20.4, 44.2), (19.6, 42.6), (20.4, 36), (20.6, 29), (20.2 + L, 23), (20.4 + L, 18.4),
    ]
    body.poly(gown, "gown", 3)
    body.shade([(18, 14), (30, 14), (30, 19.6), (18, 19.6)], tone=4)
    # la abertura de la espalda: un filo de piel con la incisión que asoma
    body.poly([(27.2 + L * 0.6, 17.0 + up), (28.0 + L * 0.3, 20), (28.4, 28), (28.8, 36), (29.4, 42.4), (28.4, 42.4),
               (27.6, 36), (27.2, 28), (26.8 + L * 0.3, 20)], "skin", 2, inside=True)
    body.line([(26.8 + L * 0.3, 20), (27.2, 28), (27.6, 36), (28.2, 42.4)], "gown", 2, inside=True)
    body.pxs([(27.8, 24), (28.0, 27), (28.2, 30)], "thread", 0, inside=True)
    body.pxs([(26.6 + L * 0.3, 21), (26.6 + L * 0.3, 22)], "metal", 3, inside=True)
    body.shade([(28.0, 37.0), (30, 37.0), (30, 43), (28.0, 43)], mat="brief", tone=1, clip="skin")
    # pliegues: del pecho al bajo, la tela cae por delante del vientre hundido
    body.line([(22.0 + L, 22), (21.6, 30), (21.4, 37), (21.0, 43)], "gown", 2, inside=True)
    body.line([(24.8, 24), (25.2, 32), (25.4, 38), (25.0, 44)], "gown", 2, inside=True)
    body.shade([(25.6, 22), (27.0, 22), (27.4, 36), (28.4, 43), (25.6, 43)], tone=2)
    body.part.rim(0, 1, 1, tone=1, clip="gown")
    body.pxs([(22, 33), (22, 34), (23, 34)], "blood", 1, inside=True)

    sleeve = new_pen(g.bob)
    sv = [(22.0 + L, 16.4 + up), (25.6 + L, 16.0 + up), (27.2 + L, 18.6), (26.8 + L, 23.6), (22.6 + L, 24.0),
          (21.8 + L, 19.0)]
    sleeve.poly(sv, "gown", 3)
    sleeve.shade([(20, 15), (30, 15), (30, 19.0), (20, 19.0)], tone=4, clip="gown")
    sleeve.shade([(20, 22.4), (30, 22.4), (30, 25), (20, 25)], tone=2)
    sleeve.line([(24.2 + L, 18.6), (24.0 + L, 23.4)], "gown", 2, inside=True)

    head = new_pen(g.bob)
    nx = 23.2 + L * 1.8
    head.poly([(nx - 0.2, 12.4), (nx + 2.4, 12.0), (nx + 3.4, 16.6), (nx + 0.4, 17.0)], "skin", 2)
    head.px(nx + 0.0, 15.0, "skin", 3)                    # nuez
    head.line([(nx + 2.2, 12.6), (nx + 3.0, 16.0)], "skin", 1, inside=True)
    head.pixmap(HEAD_W, (nx - 0.4, 4.8), LEG, hot=(5, 0))

    return [far_leg.part, far_arm.part, near_leg.part, body.part, near_arm.part, sleeve.part, head.part]


# =============================================================================================
# Montaje
# =============================================================================================

DIRECTIONS = ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]


def _parts(view: str, g: Gait, pen: Pen) -> tuple[list[Part], bool]:
    """Piezas de una dirección y si hay que reflejarlas."""
    mirrored = view in ("E", "SE", "NE")
    base = {"E": "W", "SE": "SW", "NE": "NW"}.get(view, view)
    if base == "S":
        return view_frontal(pen, g, back=False, turn=0, ids=("R", "L")), False
    if base == "N":
        return view_frontal(pen, g, back=True, turn=0, ids=("L", "R")), False
    if base == "SW":
        ids = ("R", "L") if not mirrored else ("L", "R")
        return view_frontal(pen, g, back=False, turn=1, ids=ids), mirrored
    if base == "NW":
        ids = ("L", "R") if not mirrored else ("R", "L")
        return view_frontal(pen, g, back=True, turn=1, ids=ids), mirrored
    ids = ("L", "R") if not mirrored else ("R", "L")
    return view_side(pen, g, ids=ids), mirrored


def frame(view: str, g: Gait, s: float = SCALE) -> Image.Image:
    """Un fotograma de 56×80 de la dirección `view` (S, SW, W, NW, N, NE, E, SE)."""
    W, H = FRAME_W, FRAME_H
    pen = Pen(Part(W, H), s, (CX, GROUND), FRAME_ORIGIN)
    parts, mirrored = _parts(view, g, pen)
    im = compose(parts, (W, H))
    if mirrored:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    return im


def walk_cycle(view: str) -> list[Image.Image]:
    return [frame(view, g) for g in WALK]


def idle_cycle(view: str) -> list[Image.Image]:
    return [frame(view, g) for g in IDLE]


if __name__ == "__main__":
    from px2d import sheet, upscale
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n/proto_8dir.png"
    rows = [[frame(d, g) for g in IDLE[:1] + WALK] for d in DIRECTIONS]
    im = sheet(rows, bg=(40, 38, 42), gap=2)
    upscale(im, 3).save(out)
