"""El enfermero transfigurado en combate, de frente (200×260), dibujado en 2D por piezas.

Concepto: docs/design/enemigos/enfermero.md. Alto y demacrado, uniforme blanco de enfermería roto
y manchado, piel gris azulada con venas oscuras, mascarilla quirúrgica cosida a la cara y máscara
de porcelana agrietada sobre los ojos, columna arqueada (la cabeza cuelga por delante, entre los
hombros alzados), antebrazo derecho fundido con bisturíes y una sierra de hueso con una costura de
grapas, jeringa grande en la mano izquierda y vías con líquido oscuro que le entran en el pecho.

Piezas separables (para las mutilaciones del combate), cada una en su capa del mismo tamaño:
`leg_r`, `leg_l`, `body`, `arm_r` (instrumental, a la izquierda de la pantalla), `arm_l`
(jeringa), `head`; y muñones (`stump_*`) que se dibujan cuando falta la pieza.

Poses: `idle` (dos fotogramas: respira y se balancea) y `attack` (Tajo: levanta el brazo de
bisturíes por encima de la máscara). Los brazos se redibujan desde las articulaciones de cada
pose (no se giran como un recorte), y la cabeza se inclina como pieza recortada (`rotsprite`).
"""

from __future__ import annotations

import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import palette  # noqa: E402,F401
from pen import Pen  # noqa: E402
from px2d import Part, compose, lerp, rotsprite  # noqa: E402

W, H = 200, 260
ORIGIN = (100, 252)

# Perfiles (t, izquierda, derecha) respecto a la dirección del hueso.
THIGH = [(0.0, 9.5, 9.5), (0.3, 8.6, 8.4), (0.8, 6.4, 6.2), (1.0, 6.8, 6.8)]
SHIN_TROUSER = [(0.0, 6.8, 6.8), (0.2, 6.2, 6.6), (0.6, 5.4, 5.6), (1.0, 5.2, 5.4)]
SHIN_BARE = [(0.0, 3.6, 3.6), (0.5, 2.8, 2.8), (0.9, 2.4, 2.4), (1.0, 3.0, 3.0)]
UPPER_ARM = [(0.0, 8.0, 7.4), (0.12, 8.6, 7.0), (0.35, 5.4, 5.0), (0.75, 3.8, 3.8), (0.92, 4.8, 4.4), (1.0, 5.6, 5.0)]
FOREARM = [(0.0, 5.0, 5.0), (0.1, 6.0, 5.4), (0.3, 5.2, 4.8), (0.7, 3.4, 3.2), (1.0, 3.0, 3.0)]
FOREARM_FUSED = [(0.0, 5.4, 5.4), (0.2, 7.0, 6.4), (0.55, 7.4, 7.0), (0.85, 6.4, 6.6), (1.0, 6.0, 6.0)]


def _unit(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dy) or 1.0
    return dx / n, dy / n


def _crack(pen: Pen, start, length: int, seed: int, ang: float, mat="porcelain", tone=0):
    """Grieta: línea quebrada a mano (ángulos al azar con semilla fija) con una rama."""
    rnd = random.Random(seed)
    x, y = start
    pts = [(x, y)]
    for _ in range(length):
        ang += rnd.uniform(-0.7, 0.7)
        step = rnd.uniform(2.0, 3.6)
        x, y = x + math.cos(ang) * step, y + math.sin(ang) * step
        pts.append((x, y))
    pen.line(pts, mat, tone, inside=True)
    # brillo del canto de la grieta, un píxel por debajo
    pen.line([(px + 1, py + 1) for px, py in pts[1:-1]], mat, 4, inside=True, clip=mat)
    if len(pts) > 3:
        bx, by = pts[len(pts) // 2]
        b2 = ang + rnd.choice((-1.1, 1.1))
        pen.line([(bx, by), (bx + math.cos(b2) * 5, by + math.sin(b2) * 5)], mat, tone, inside=True)


def _half(profile, side: str, k: float = 0.15):
    """Media extremidad: la mitad izquierda ('l') o derecha ('r') del perfil, para la zona de sombra."""
    if side == "l":
        return [(t, wl, -wl * k) for t, wl, wr in profile]
    return [(t, -wr * k, wr) for t, wl, wr in profile]


def _arm_flesh(pen: Pen, sh, el, wr, upper, fore, shadow_side: str = "l"):
    """Brazo descarnado: perfiles angulosos, zona de sombra plana en un costado, codo huesudo,
    hendidura del deltoides, tendones y venas oscuras."""
    pen.limb(sh, el, upper, "skin_grey", 2)
    pen.limb(el, wr, fore, "skin_grey", 2)
    other = "r" if shadow_side == "l" else "l"
    lit_u = [(t, a * 0.45, b * 0.45) for t, a, b in _half(upper, other, -0.35)]
    lit_f = [(t, a * 0.45, b * 0.45) for t, a, b in _half(fore, other, -0.35)]
    pen.limb(sh, el, _half(upper, shadow_side, -0.25), "skin_grey", 1, inside=True)
    pen.limb(el, wr, _half(fore, shadow_side, -0.25), "skin_grey", 1, inside=True)
    pen.limb(sh, el, _half(upper, other, -0.55), "skin_grey", 3, inside=True)
    pen.limb(el, wr, _half(fore, other, -0.55), "skin_grey", 3, inside=True)
    _ = (lit_u, lit_f)
    ux, uy = _unit(sh, el)
    nx, ny = uy, -ux                                  # normal izquierda (como en px2d.limb)
    sgn = 1 if shadow_side == "l" else -1
    # hendidura bajo el deltoides
    d = lerp(sh, el, 0.3)
    pen.line([(d[0] - nx * 5 * sgn, d[1] - ny * 5 * sgn), (d[0] + nx * 1 * sgn, d[1] + ny * 1 * sgn + 3)],
             "skin_grey", 1, inside=True)
    # codo: nudo de hueso con arrugas y sombra debajo
    ex, ey = el
    pen.poly([(ex - 3, ey - 3), (ex + 3, ey - 3), (ex + 4, ey + 1), (ex, ey + 4), (ex - 4, ey + 1)], "skin_grey", 3)
    pen.pxs([(ex - 1, ey - 2), (ex, ey - 2)], "skin_grey", 4)
    pen.line([(ex - 3, ey + 2), (ex + 3, ey + 2)], "skin_grey", 1, inside=True)
    pen.line([(ex - 2, ey + 4), (ex + 2, ey + 4)], "skin_grey", 1, inside=True)
    # tendones del antebrazo y venas
    fu, fv = _unit(el, wr)
    fn = (fv, -fu)
    a = lerp(el, wr, 0.55)
    pen.line([(a[0] - fn[0] * 1.5 * sgn, a[1] - fn[1] * 1.5 * sgn), (wr[0] - fn[0] * 1 * sgn, wr[1] - fn[1] * sgn)],
             "skin_grey", 4, inside=True)
    pen.line([lerp(sh, el, 0.45), (lerp(sh, el, 0.7)[0] + 1, lerp(sh, el, 0.7)[1]), lerp(el, wr, 0.15),
              (lerp(el, wr, 0.4)[0] - 1, lerp(el, wr, 0.4)[1])], "vein", 1, inside=True)


def _stitches(pen: Pen, pts, every: float = 4.0, size: float = 2.4, mat="thread"):
    """Puntadas gruesas cruzando una línea de costura."""
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        ux, uy = _unit(a, b)
        nx, ny = -uy, ux
        seg = math.hypot(b[0] - a[0], b[1] - a[1])
        t = 0.0
        while t < seg:
            cx, cy = a[0] + ux * t, a[1] + uy * t
            pen.line([(cx - nx * size, cy - ny * size), (cx + nx * size, cy + ny * size)], mat, 0)
            t += every


def _scalpel(pen: Pen, base, direction, length: float, width: float = 2.6, curve: int = 1):
    """Hoja de bisturí que sale de la carne: lomo recto, filo con panza, punta ensangrentada."""
    ux, uy = direction
    nx, ny = -uy * curve, ux * curve
    bx, by = base
    tip = (bx + ux * length, by + uy * length)
    belly = (bx + ux * length * 0.62 + nx * width, by + uy * length * 0.62 + ny * width)
    back0 = (bx - nx * width * 0.5, by - ny * width * 0.5)
    back1 = (bx + ux * length * 0.8 - nx * width * 0.4, by + uy * length * 0.8 - ny * width * 0.4)
    root = (bx + nx * width * 0.8, by + ny * width * 0.8)
    pen.poly([back0, back1, tip, belly, root], "metal", 3)
    pen.line([root, belly, tip], "metal", 4)                     # filo
    pen.line([back0, back1], "metal", 1)                         # lomo
    pen.line([lerp(tip, belly, 0.0), lerp(tip, belly, 0.35)], "blood", 2)
    pen.px(*lerp(tip, back1, 0.2), "blood", 1)


def _saw(pen: Pen, base, direction, length: float, depth: float, normal):
    """Sierra de hueso: hoja rectangular con dientes en el canto que da a `normal`, roñosa."""
    ux, uy = direction
    nx, ny = normal
    a = base
    b = (a[0] + ux * length, a[1] + uy * length)
    c = (b[0] + nx * depth, b[1] + ny * depth)
    d = (a[0] + nx * depth * 0.7, a[1] + ny * depth * 0.7)
    pen.poly([a, b, c, d], "metal", 2)
    pen.line([a, b], "metal", 4)
    pen.line([lerp(a, b, 0.1), lerp(a, b, 0.9)], "metal", 3, inside=True)
    # dientes: muescas en el canto exterior
    n = int(length / 3)
    for i in range(1, n):
        p = lerp(d, c, i / n)
        pen.part.dot(*pen.m(p), "metal", 4)
        q = (p[0] + nx * 1.2 + ux * 1.2, p[1] + ny * 1.2 + uy * 1.2)
        pen.part.dot(*pen.m(q), "metal", 1)
    # óxido y sangre seca
    for t in (0.3, 0.55, 0.7):
        p = lerp(lerp(a, b, t), lerp(d, c, t), 0.5)
        pen.px(*p, "rust", 1)
    pen.px(*lerp(lerp(a, b, 0.85), lerp(d, c, 0.85), 0.4), "blood", 1)


# =============================================================================================
# Piezas
# =============================================================================================

def leg(side: int, pose: dict) -> Part:
    """Pierna. side = -1 (derecha del enfermero, a la izquierda de la pantalla) o 1."""
    pen = Pen(Part(W, H, f"leg_{'r' if side < 0 else 'l'}"))
    hip, knee, ankle = pose[f"hip{side}"], pose[f"knee{side}"], pose[f"ankle{side}"]
    hem = lerp(knee, ankle, 0.55)
    pen.limb(hip, knee, THIGH, "uniform", 2)
    # piel gris bajo el pantalón desgarrado
    pen.limb(knee, ankle, SHIN_BARE, "skin_grey", 2)
    pen.limb(knee, hem, SHIN_TROUSER[:3] + [(1.0, 5.8, 5.8)], "uniform", 2)
    # bajo desgarrado en jirones
    hx, hy = hem
    jag = [(hx - 6, hy - 1), (hx - 4.6, hy + 4), (hx - 3, hy + 0.6), (hx - 1, hy + 6), (hx + 1.2, hy + 1),
           (hx + 3.4, hy + 3.6), (hx + 5.6, hy - 0.4), (hx + 6, hy - 2), (hx - 6, hy - 2)]
    pen.poly(jag, "uniform", 1)
    # rodilla: rodillera sucia con un roto por donde asoma la rótula gris
    kx, ky = knee
    pen.poly([(kx - 3.4, ky - 3), (kx + 2.6, ky - 4), (kx + 3.6, ky + 1.4), (kx - 1, ky + 3.4), (kx - 4, ky + 1)],
             "skin_grey", 3)
    pen.line([(kx - 3.4, ky - 3), (kx + 2.6, ky - 4)], "uniform", 0)
    pen.px(kx - 1, ky - 1, "skin_grey", 4)
    # pliegues del pantalón: aristas en zigzag que caen del muslo a la rodilla
    hx0, hy0 = hip
    pen.line([(hx0 + side * 2, hy0 + 8), (kx + side * 3, ky - 22), (kx - side * 1, ky - 12)], "uniform", 1, inside=True)
    pen.line([(hx0 - side * 3, hy0 + 14), (kx - side * 4, ky - 10)], "uniform", 3, inside=True)
    pen.line([(kx + side * 2, ky + 6), (hx + side * 1, hy - 4)], "uniform", 1, inside=True)
    # manchas: sangre seca en el muslo, suciedad hacia el bajo
    pen.shade([(hx0 - 5, hy0 + 20), (hx0 + 1, hy0 + 19), (hx0 + 2, hy0 + 26), (hx0 - 1, hy0 + 33), (hx0 - 4, hy0 + 29)],
              mat="blood", tone=1)
    pen.shade([(hx0 - 2, hy0 + 33), (hx0, hy0 + 33), (hx0, hy0 + 40), (hx0 - 1, hy0 + 41)], mat="blood", tone=1)
    pen.shade([(kx - 8, hy - 2), (kx - 3, hy - 6), (kx + 2, hy - 3), (kx + 8, hy - 7), (kx + 8, hy + 8), (kx - 8, hy + 8)],
              mat="stain", tone=1)
    # espinilla: arista clara y venas
    ax, ay = ankle
    pen.line([(hx - 0.8, hy + 4), (ax - 0.6, ay - 3)], "skin_grey", 3, inside=True)
    pen.line([(hx + 1.8, hy + 6), (hx + 1.0, hy + 10), (hx + 2.0, hy + 13)], "vein", 1, inside=True)
    # pie desnudo, largo y huesudo: tendones en el empeine, dedos largos con uñas negras
    foot = [(ax - 4, ay - 1), (ax + 4, ay - 1), (ax + 7 + side * 2, ay + 9), (ax + 6 + side * 2, ay + 12),
            (ax - 6 + side * 2, ay + 12), (ax - 7 + side * 2, ay + 9)]
    pen.poly(foot, "skin_grey", 3)
    for i, dx in enumerate((-5, -2.6, -0.2, 2.2, 4.6)):
        x = ax + dx + side * 2
        pen.line([(x, ay + 6), (x + side * 0.4, ay + 11)], "skin_grey", 1 if i % 2 else 3, inside=True)
        pen.px(x + side * 0.4, ay + 11, "glass_dark", 1)
    pen.line([(ax - 2, ay + 1), (ax - 3 + side, ay + 7)], "skin_grey", 3, inside=True)
    pen.line([(ax + 1, ay + 1), (ax + 2 + side, ay + 7)], "skin_grey", 3, inside=True)
    pen.part.rim(1, 0, 2, delta=-1)
    pen.part.rim(0, -1, 1, delta=1, clip="uniform")
    # el foco no llega a los pies: se apagan hacia abajo
    pen.shade([(0, 246), (W, 246), (W, H), (0, H)], delta=-1)
    return pen.part


def body(pose: dict, breath: float = 0.0) -> Part:
    """Tronco con la túnica blanca, el cuello, las vías del pecho."""
    pen = Pen(Part(W, H, "body"), dy=breath)
    # túnica: hombros alzados (columna arqueada), cintura estrecha, bajo roto
    tunic = [
        (84, 50), (91, 54), (100, 80), (109, 54), (116, 50),        # cuello en pico
        (131, 56), (140, 63), (141, 72), (132, 86),                # hombro y sisa derecha (pantalla)
        (127, 102), (121, 118), (124, 134), (128, 150),            # costado
        (122, 156), (117, 151), (111, 158), (104, 152), (97, 160), (90, 152), (84, 157), (78, 151), (72, 154),
        (76, 134), (79, 118), (73, 102), (68, 86),                 # bajo en jirones y costado izquierdo
        (59, 72), (60, 63), (69, 56),
    ]
    pen.poly(tunic, "uniform", 3)
    # planos: hombros a la luz, pecho, sombra bajo las costillas
    pen.shade([(58, 46), (142, 46), (142, 66), (124, 64), (110, 58), (90, 58), (76, 64), (58, 66)], tone=4)
    pen.shade([(118, 66), (141, 66), (132, 86), (127, 102), (121, 118), (112, 112), (118, 90)], tone=2)
    pen.shade([(76, 112), (124, 112), (121, 118), (124, 134), (76, 134), (79, 118)], tone=2)
    pen.shade([(72, 134), (128, 134), (128, 160), (72, 160)], tone=2)
    pen.shade([(80, 146), (92, 142), (100, 148), (112, 141), (126, 146), (128, 160), (72, 160)], tone=1)
    # pliegues angulosos: tiran de los hombros hacia el centro
    pen.line([(66, 70), (80, 86), (86, 104), (84, 118)], "uniform", 2, inside=True)
    pen.line([(134, 70), (120, 88), (114, 104), (116, 118)], "uniform", 2, inside=True)
    pen.line([(80, 122), (88, 132), (86, 146), (90, 152)], "uniform", 1, inside=True)
    pen.line([(118, 122), (110, 134), (112, 148)], "uniform", 1, inside=True)
    pen.line([(96, 136), (98, 150), (97, 158)], "uniform", 2, inside=True)
    # bolsillo de pecho con la tarjeta de identificación (foto oscura, texto ilegible)
    pen.poly([(110, 96), (122, 96), (121, 107), (111, 107)], "uniform", 2)
    pen.line([(110, 96), (122, 96)], "uniform", 4)
    pen.poly([(113, 92), (119, 91), (120, 99), (114, 100)], "porcelain", 3)
    pen.poly([(114, 93), (116, 93), (116, 96), (114, 96)], "glass_dark", 2)
    pen.pxs([(117, 94), (118, 94), (115, 98), (117, 98)], "porcelain", 1)
    pen.line([(116, 88), (116, 91)], "metal", 3)
    # desgarro en el pecho: se ve la piel gris tirante sobre las costillas
    tear = [(77, 90), (84, 86), (88, 92), (94, 96), (96, 106), (91, 112), (86, 108), (80, 104), (78, 97)]
    pen.poly(tear, "skin_grey", 2, inside=True)
    for i, y in enumerate((93, 99, 105)):
        pen.line([(78 + i, y), (86, y + 2), (95, y + 1)], "skin_grey", 1, inside=True, clip="skin_grey")
        pen.line([(79 + i, y - 1.4), (86, y + 0.6)], "skin_grey", 3, inside=True, clip="skin_grey")
    pen.line([(84, 88), (83, 96), (86, 104)], "vein", 1, inside=True, clip="skin_grey")
    # canto del desgarro: hilachas
    pen.line([(77, 90), (84, 86), (88, 92), (94, 96), (96, 106)], "uniform", 4)
    pen.pxs([(86, 86), (90, 93), (97, 101), (76, 96)], "uniform", 2)
    # cuello en pico: piel gris, clavículas que se marcan
    pen.poly([(86, 51), (114, 51), (108, 56), (100, 76), (92, 56)], "skin_grey", 2, inside=True)
    pen.line([(88, 56), (96, 60)], "skin_grey", 4, inside=True, clip="skin_grey")
    pen.line([(112, 56), (104, 60)], "skin_grey", 3, inside=True, clip="skin_grey")
    pen.line([(98, 62), (100, 74)], "skin_grey", 1, inside=True, clip="skin_grey")
    # sangre: chorreones del cuello cosido y salpicaduras en el vientre
    pen.line([(96, 70), (95, 84), (96, 92)], "blood", 1, inside=True)
    pen.line([(104, 68), (106, 80)], "blood", 2, inside=True)
    pen.shade([(99, 117), (104, 119), (110, 115), (113, 121), (111, 129), (114, 136), (108, 133), (103, 137),
               (101, 128)], mat="blood", tone=1)
    pen.shade([(103, 121), (108, 120), (107, 126)], mat="blood", tone=2)
    pen.pxs([(108, 124), (109, 125), (110, 127), (103, 128)], "blood", 2, inside=True)
    pen.shade([(122, 140), (127, 140), (126, 152), (121, 151)], mat="stain", tone=1, pattern="sparse")
    # vías: tres tubos con líquido oscuro que le entran en el pecho; vienen de la espalda por
    # encima de los hombros (de la pieza metálica)
    for path in (
        [(128, 50), (127, 58), (124, 66), (118, 74), (110, 80), (104, 88), (102, 96)],
        [(136, 56), (135, 66), (131, 78), (124, 90), (116, 98), (110, 102)],
        [(70, 52), (70, 62), (73, 72), (79, 80), (86, 86), (90, 96)],
    ):
        pen.line(path, "tube_dark", 1, width=4)
        pen.line([(x - 1, y - 1) for x, y in path[:-1]], "tube_dark", 3)
        ex, ey = path[-1]
        # entra en la carne: esparadrapo en cruz y un cerco amoratado
        pen.poly([(ex - 2, ey - 1), (ex, ey - 3), (ex + 2, ey - 1), (ex, ey + 2)], "flesh", 1)
        pen.line([(ex - 4, ey - 2), (ex + 4, ey)], "uniform", 4)
        pen.line([(ex, ey + 2), (ex, ey + 6)], "blood", 1)
    pen.part.rim(1, 0, 2, delta=-1, clip="uniform")
    pen.part.rim(0, 1, 2, delta=-1, clip="uniform")
    pen.part.dither_edges("uniform", 2, 3)
    return pen.part


def arm_r(pose: dict, breath: float = 0.0) -> Part:
    """Brazo de instrumental: a la izquierda de la pantalla."""
    pen = Pen(Part(W, H, "arm_r"), dy=breath)
    sh, el, wr = pose["sh_r"], pose["el_r"], pose["wr_r"]
    # antebrazo hinchado, con la carne cosida al metal
    _arm_flesh(pen, sh, el, wr, UPPER_ARM, FOREARM_FUSED, "l")
    ux, uy = _unit(el, wr)
    nx, ny = -uy, ux
    # sierra de hueso que sale del canto exterior del antebrazo
    sb = lerp(el, wr, 0.3)
    out = (nx, ny) if nx < 0 else (-nx, -ny)          # hacia fuera del cuerpo
    _saw(pen, (sb[0] + out[0] * 4, sb[1] + out[1] * 4), (ux, uy), 72, 11, out)
    # haz de bisturíes que brotan de la muñeca como dedos abiertos
    for ang, ln, off in ((-0.32, 40, -3.0), (-0.12, 50, -1.0), (0.08, 46, 1.2), (0.28, 36, 3.2)):
        d = (ux * math.cos(ang) - uy * math.sin(ang), ux * math.sin(ang) + uy * math.cos(ang))
        _scalpel(pen, (wr[0] + nx * off, wr[1] + ny * off), d, ln, width=2.6, curve=1 if ang < 0 else -1)
    # muñón de la mano: carne abultada alrededor del metal
    pen.poly([(wr[0] + nx * 6 - ux * 2, wr[1] + ny * 6 - uy * 2), (wr[0] - nx * 6 - ux * 2, wr[1] - ny * 6 - uy * 2),
              (wr[0] - nx * 5 + ux * 5, wr[1] - ny * 5 + uy * 5), (wr[0] + nx * 5 + ux * 5, wr[1] + ny * 5 + uy * 5)],
             "flesh", 2)
    pen.line([(wr[0] + nx * 5 + ux * 5, wr[1] + ny * 5 + uy * 5), (wr[0] - nx * 5 + ux * 5, wr[1] - ny * 5 + uy * 5)],
             "flesh", 0)
    # costura de grapas donde la carne se une al metal
    c0 = lerp(el, wr, 0.28)
    c1 = lerp(el, wr, 0.92)
    seam = [(c0[0] - nx * 4, c0[1] - ny * 4), (c1[0] - nx * 3, c1[1] - ny * 3)]
    pen.line(seam, "flesh", 1, inside=True)
    _stitches(pen, seam, every=5, size=2.2, mat="metal")
    # manga corta rota que cubre el hombro
    sx, sy = sh
    sleeve = [(sx - 9, sy - 6), (sx + 8, sy - 10), (sx + 12, sy + 6), (sx + 6, sy + 20), (sx + 2, sy + 16),
              (sx - 2, sy + 22), (sx - 6, sy + 17), (sx - 11, sy + 18), (sx - 12, sy + 4)]
    pen.poly(sleeve, "uniform", 3)
    pen.shade([(sx - 14, sy - 12), (sx + 14, sy - 12), (sx + 14, sy - 1), (sx - 14, sy + 2)], tone=4, clip="uniform")
    pen.line([(sx - 4, sy - 2), (sx - 6, sy + 14)], "uniform", 2, inside=True)
    pen.pxs([(sx - 1, sy + 6), (sx, sy + 7), (sx - 2, sy + 9)], "blood", 1, inside=True)
    pen.part.rim(0, 1, 1, delta=-1, clip="uniform")
    return pen.part


def arm_l(pose: dict, breath: float = 0.0) -> Part:
    """Brazo de la jeringa: a la derecha de la pantalla."""
    pen = Pen(Part(W, H, "arm_l"), dy=breath)
    sh, el, wr = pose["sh_l"], pose["el_l"], pose["wr_l"]
    _arm_flesh(pen, sh, el, wr, UPPER_ARM, FOREARM, "l")
    # jeringa grande, sujeta en vertical: émbolo arriba, aguja abajo
    sx, sy = wr[0] + 1, wr[1] - 10
    top, bot = sy, sy + 54
    barrel = [(sx - 5, top), (sx + 5, top), (sx + 5, bot), (sx - 5, bot)]
    pen.poly(barrel, "glass_dark", 1)
    pen.poly([(sx - 4, top + 14), (sx + 4, top + 14), (sx + 4, bot - 1), (sx - 4, bot - 1)], "tube_dark", 1)
    pen.line([(sx - 4, top + 14), (sx + 4, top + 14)], "tube_dark", 2)                   # menisco
    pen.line([(sx - 3, top + 2), (sx - 3, bot - 3)], "glass_dark", 3)                   # reflejo del cristal
    for y in range(int(top) + 6, int(bot) - 4, 5):                                                # graduación
        pen.line([(sx + 1, y), (sx + 4, y)], "porcelain", 2 if (y // 5) % 2 else 1)
    pen.pxs([(sx - 1, top + 30), (sx + 1, top + 36), (sx, top + 44)], "tube_dark", 2)  # burbujas
    pen.poly([(sx - 8, top - 3), (sx + 8, top - 3), (sx + 8, top), (sx - 8, top)], "metal", 3)  # alas
    pen.poly([(sx - 1.4, top - 22), (sx + 1.4, top - 22), (sx + 1.4, top - 3), (sx - 1.4, top - 3)], "metal", 2)  # vástago
    pen.poly([(sx - 6, top - 26), (sx + 6, top - 26), (sx + 6, top - 22), (sx - 6, top - 22)], "metal", 3)  # émbolo
    pen.line([(sx - 6, top - 26), (sx + 6, top - 26)], "metal", 4)
    pen.poly([(sx - 2.4, bot), (sx + 2.4, bot), (sx + 1.4, bot + 5), (sx - 1.4, bot + 5)], "metal", 3)  # cono
    pen.line([(sx, bot + 5), (sx + 1, bot + 34)], "metal", 4)                           # aguja
    pen.pxs([(sx + 1, bot + 33), (sx + 1, bot + 35), (sx + 1, bot + 38)], "tube_dark", 1)  # gota oscura
    # mano: dedos largos y nudosos que rodean el cilindro
    hx, hy = wr
    # dorso de la mano (por detrás del cilindro, a la derecha) y nudillos huesudos
    pen.poly([(sx + 3, hy - 7), (sx + 10, hy - 5), (sx + 11, hy + 8), (sx + 7, hy + 14), (sx + 3, hy + 12)], "skin_grey", 2)
    pen.line([(sx + 10, hy - 4), (sx + 11, hy + 8)], "skin_grey", 1)
    # cuatro dedos largos que rodean el cilindro en diagonal, con huecos oscuros entre ellos
    for i in range(4):
        y = hy - 3 + i * 4.6
        k0 = (sx + 7, y)                      # nudillo
        k1 = (sx - 1, y + 1.6)                # falange media, delante del cristal
        k2 = (sx - 5.6, y + 3.4)              # punta, asoma por la izquierda
        pen.limb(k0, k1, [(0, 1.8, 1.8), (1, 1.5, 1.5)], "skin_grey", 3)
        pen.limb(k1, k2, [(0, 1.5, 1.5), (1, 1.1, 1.1)], "skin_grey", 2)
        pen.px(k0[0], k0[1] - 1, "skin_grey", 4)
        pen.px(k1[0], k1[1] - 1, "skin_grey", 4)
        pen.px(k2[0], k2[1], "glass_dark", 2)            # uña negra
    pen.poly([(sx + 6, hy - 9), (sx + 2, hy - 6), (sx - 3, hy - 4), (sx - 4, hy - 2), (sx + 4, hy - 3)],
             "skin_grey", 3)                                                            # pulgar sobre las alas
    # manga corta rota
    sx2, sy2 = sh
    sleeve = [(sx2 + 9, sy2 - 6), (sx2 - 8, sy2 - 10), (sx2 - 12, sy2 + 6), (sx2 - 6, sy2 + 21), (sx2 - 1, sy2 + 15),
              (sx2 + 3, sy2 + 21), (sx2 + 7, sy2 + 15), (sx2 + 11, sy2 + 18), (sx2 + 12, sy2 + 4)]
    pen.poly(sleeve, "uniform", 3)
    pen.shade([(sx2 - 14, sy2 - 12), (sx2 + 14, sy2 - 12), (sx2 + 14, sy2 + 2), (sx2 - 14, sy2 - 1)], tone=4,
              clip="uniform")
    pen.shade([(sx2 + 2, sy2), (sx2 + 14, sy2), (sx2 + 14, sy2 + 22), (sx2 + 2, sy2 + 22)], tone=2, clip="uniform")
    pen.line([(sx2 + 4, sy2 - 2), (sx2 + 6, sy2 + 14)], "uniform", 2, inside=True)
    return pen.part


def head(breath: float = 0.0, tilt: float = 0.0) -> Part:
    """Cabeza: máscara de porcelana agrietada sobre los ojos y mascarilla cosida a la cara."""
    pen = Pen(Part(W, H, "head"), dy=breath)
    cx = 100
    # cuello largo y fibroso que se dobla hacia delante
    pen.poly([(92, 46), (108, 46), (110, 60), (90, 60)], "skin_grey", 1)
    pen.line([(94, 48), (93, 58)], "skin_grey", 2)
    pen.line([(106, 48), (107, 58)], "skin_grey", 2)
    # cráneo alargado y anguloso, con mechones ralos
    skull = [(88, 20), (98, 15), (108, 16), (116, 22), (119, 32), (118, 46), (114, 58), (108, 68), (100, 72),
             (92, 68), (86, 58), (82, 46), (81, 32)]
    pen.poly(skull, "skin_grey", 2)
    pen.shade([(84, 14), (110, 12), (118, 24), (104, 28), (86, 30)], tone=3)
    pen.shade([(92, 15), (102, 14), (98, 20), (90, 22)], tone=4)
    pen.part.rim(1, 0, 3, delta=-1)
    for x0, y0, x1, y1 in ((96, 16, 90, 27), (108, 18, 113, 30)):
        pen.line([(x0, y0), ((x0 + x1) / 2 + 1, (y0 + y1) / 2), (x1, y1)], "glass_dark", 3, inside=True)  # pelo ralo
    pen.line([(86, 24), (88, 30), (85, 36)], "vein", 1, inside=True)
    pen.line([(113, 22), (112, 28)], "vein", 1, inside=True)
    # orejas
    pen.poly([(80, 36), (83, 35), (84, 48), (80, 46), (78, 41)], "skin_grey", 1)
    pen.poly([(120, 35), (117, 36), (116, 48), (120, 46), (122, 41)], "skin_grey", 1)
    # máscara de porcelana: cubre de la frente a la nariz, cejas talladas, cuencas huecas
    mask = [(85, 27), (95, 24), (105, 24), (115, 27), (117, 36), (114, 46), (106, 51), (100, 54), (94, 51), (86, 46),
            (83, 36)]
    pen.poly(mask, "porcelain", 3)
    pen.shade([(84, 26), (116, 26), (116, 31), (84, 31)], tone=4, clip="porcelain")
    pen.shade([(104, 40), (118, 34), (116, 47), (106, 52), (100, 54)], tone=2, clip="porcelain")
    pen.line([(98, 36), (99, 46), (100, 52)], "porcelain", 4, inside=True)               # caballete
    pen.line([(102, 38), (102, 48)], "porcelain", 2, inside=True)
    # cuencas: la izquierda vacía y negra; en la derecha asoma un ojo lechoso con vasos rotos
    pen.poly([(87, 35), (95, 33), (97, 38), (93, 41), (88, 40)], "glass_dark", 0)
    pen.poly([(103, 33), (112, 35), (112, 40), (107, 41), (103, 38)], "glass_dark", 1)
    pen.poly([(105, 35), (110, 36), (110, 39), (106, 39)], "bone", 3)
    pen.px(107, 37, "glass_dark", 0)
    pen.px(108, 37, "glass_dark", 2)
    pen.pxs([(109, 38), (105, 36)], "blood", 2)
    pen.line([(87, 35), (95, 33)], "porcelain", 1)
    pen.line([(103, 33), (112, 35)], "porcelain", 1)
    pen.line([(88, 41), (93, 42)], "porcelain", 4, inside=True)
    # grietas: una larga que parte la cuenca izquierda y otras finas
    _crack(pen, (93, 41), 6, 3, 1.9)
    _crack(pen, (96, 25), 4, 8, 2.0)
    _crack(pen, (113, 30), 4, 11, 2.6)
    # trozo saltado: se ve la carne hinchada debajo
    pen.poly([(84, 42), (88, 42), (90, 47), (86, 47)], "flesh", 2)
    pen.px(86, 44, "flesh", 4)
    # tira de la máscara clavada en las sienes
    pen.line([(83, 33), (80, 34)], "thread", 1)
    pen.line([(117, 33), (120, 34)], "thread", 1)
    # mascarilla quirúrgica cosida a la cara (de la nariz a la barbilla)
    cloth = [(86, 48), (94, 52), (100, 55), (106, 52), (114, 48), (113, 58), (108, 66), (100, 71), (92, 66), (87, 58)]
    pen.poly(cloth, "mask_cloth", 2)
    pen.line([(88, 56), (100, 59), (112, 56)], "mask_cloth", 1, inside=True)              # pliegues
    pen.line([(89, 61), (100, 64), (111, 61)], "mask_cloth", 1, inside=True)
    pen.line([(90, 53), (100, 56), (110, 53)], "mask_cloth", 3, inside=True)
    pen.shade([(95, 60), (99, 59), (103, 61), (106, 60), (104, 65), (100, 68), (96, 65)], mat="blood", tone=1)
    pen.pxs([(99, 62), (100, 62), (101, 63)], "blood", 0)
    _stitches(pen, [(87, 50), (88, 58), (92, 66), (100, 71), (108, 66), (112, 58), (113, 50)], every=4.2, size=1.6)
    pen.px(100, 72, "blood", 1)
    pen.px(100, 74, "blood", 2)
    pen.part.rim(0, 1, 1, delta=-1)
    part = pen.part
    if tilt:
        im = compose([part], (W, H), outline=False)
        _ = im  # la inclinación se aplica en el montaje sobre la imagen ya contorneada
    return part


def stump_arm_r(pose: dict) -> Part:
    """Muñón del brazo de instrumental: manga rasgada, hueso y carne en el corte, sangre."""
    pen = Pen(Part(W, H, "stump_arm_r"))
    sx, sy = pose["sh_r"]
    sleeve = [(sx - 8, sy - 7), (sx + 9, sy - 10), (sx + 12, sy + 6), (sx + 7, sy + 13), (sx + 2, sy + 9), (sx - 3, sy + 14),
              (sx - 8, sy + 9), (sx - 11, sy + 2)]
    pen.poly(sleeve, "uniform", 3)
    pen.shade([(sx - 14, sy - 12), (sx + 14, sy - 12), (sx + 14, sy - 2), (sx - 14, sy)], tone=4, clip="uniform")
    pen.shade([(sx - 12, sy + 4), (sx + 12, sy + 4), (sx + 12, sy + 16), (sx - 12, sy + 16)], mat="blood", tone=1,
              clip="uniform", pattern="checker")
    # corte: carne, grasa y el hueso astillado
    cut = [(sx - 7, sy + 8), (sx + 1, sy + 6), (sx + 8, sy + 10), (sx + 6, sy + 18), (sx - 1, sy + 20), (sx - 8, sy + 16)]
    pen.poly(cut, "flesh", 2)
    pen.shade([(sx - 8, sy + 14), (sx + 8, sy + 14), (sx + 8, sy + 21), (sx - 8, sy + 21)], tone=1, clip="flesh")
    pen.line([(sx - 6, sy + 9), (sx + 1, sy + 7), (sx + 7, sy + 11)], "flesh", 4, inside=True)
    pen.poly([(sx - 2, sy + 10), (sx + 3, sy + 10), (sx + 4, sy + 14), (sx + 1, sy + 17), (sx - 3, sy + 14)], "bone", 3)
    pen.pxs([(sx, sy + 12), (sx + 1, sy + 13)], "flesh", 0)                                     # médula
    pen.pxs([(sx + 3, sy + 9), (sx + 4, sy + 8)], "bone", 2)                                    # astilla
    # chorreones
    for x, ln in ((sx - 5, 14), (sx + 1, 22), (sx + 5, 9)):
        pen.line([(x, sy + 18), (x, sy + 18 + ln)], "blood", 2)
        pen.px(x, sy + 19 + ln, "blood", 1)
    return pen.part


# =============================================================================================
# Poses y montaje
# =============================================================================================

HEAD_DROP = 10  # la columna arqueada deja la cabeza colgando entre los hombros


def pose_idle(phase: int = 0) -> dict:
    b = 1.5 * phase
    return {
        "hip-1": (90, 142), "knee-1": (82, 196), "ankle-1": (86, 238),
        "hip1": (110, 142), "knee1": (120, 195), "ankle1": (116, 238),
        "sh_r": (65, 70 + b), "el_r": (42, 120 + b), "wr_r": (50, 168 + b * 1.4),
        "sh_l": (135, 63 + b), "el_l": (160, 108 + b), "wr_l": (152, 152 + b * 1.4),
    }


def pose_attack() -> dict:
    p = pose_idle(0)
    p.update({"sh_r": (68, 64), "el_r": (34, 56), "wr_r": (56, 36),
              "sh_l": (134, 70), "el_l": (156, 112), "wr_l": (160, 146)})
    return p


def assemble(pose: dict, breath: float = 0.0, head_tilt: float = 0.0, head_dy: float = 0.0,
             missing: tuple[str, ...] = ()) -> Image.Image:
    """Compone el enfermero; `missing` quita piezas y pone su muñón (de momento, el del brazo
    derecho como ejemplo)."""
    layers: list = []
    if "leg_r" not in missing:
        layers.append(leg(-1, pose))
    if "leg_l" not in missing:
        layers.append(leg(1, pose))
    layers.append(body(pose, breath))
    if "arm_l" not in missing:
        layers.append(arm_l(pose, breath))
    if "head" not in missing:
        h = head(breath + head_dy + HEAD_DROP).render()
        if head_tilt:
            h = rotsprite(h, head_tilt, (100, 58 + HEAD_DROP + breath))
        layers.append(h)
    if "arm_r" not in missing:
        layers.append(arm_r(pose, breath))
    else:
        layers.append(stump_arm_r(pose))
    return compose(layers, (W, H))


def frames() -> dict[str, Image.Image]:
    return {
        "idle_0": assemble(pose_idle(0), head_tilt=-7),
        "idle_1": assemble(pose_idle(1), breath=1.5, head_tilt=-10, head_dy=1),
        "attack": assemble(pose_attack(), breath=-2, head_tilt=6),
        "stump": assemble(pose_idle(0), head_tilt=-7, missing=("arm_r",)),
    }


def parts_sheet() -> Image.Image:
    """Las piezas por separado (como las usaría el sistema de mutilaciones)."""
    p = pose_idle(0)
    items = [leg(-1, p), leg(1, p), body(p), arm_r(p), arm_l(p), head(), stump_arm_r(p)]
    return Image.merge("RGBA", compose([items[0]], (W, H)).split()) if False else \
        __import__("px2d").sheet([[compose([it], (W, H)) for it in items]], bg=(24, 22, 26), gap=4)


if __name__ == "__main__":
    from px2d import sheet, upscale
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n/nurse.png"
    f = frames()
    upscale(sheet([[f["idle_0"], f["idle_1"], f["attack"], f["stump"]]], bg=(20, 19, 22), gap=4), 2).save(out)
    parts_sheet().save(out.replace(".png", "_parts.png"))
