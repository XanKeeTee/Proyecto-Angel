"""Protagonista en combate, tercera muestra: de espaldas, en guardia con el tubo de hierro (200×280).

Un herido que agarra un tubo para defenderse: piernas separadas, la izquierda algo adelantada y las
rodillas flexionadas (el talón derecho levantado); tronco girado hacia su derecha y encorvado; el
tubo agarrado con las dos manos juntas por un extremo, como un bate, alzado sobre el hombro derecho;
la cabeza adelantada hacia el enemigo.

Método `vec`: formas suaves a ×6 (piel, bata, tubo… cada material en una sola capa continua),
volumen pintado a esa escala, reducción, paleta y contorno de un píxel alrededor de toda la figura.

Fotogramas: guardia (respiración ×4) y golpe ×3 (carga, impacto, retroceso).
"""

from __future__ import annotations

import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import palette_v3 as pal  # noqa: E402
from vec import C, Fig, lerp, limb_outline  # noqa: E402

W, H = 200, 280
K = 6
LIGHT = (-0.78, -0.52)
LZ = 0.32


def guard() -> dict:
    return {
        "head": (95, 74), "tilt": -0.10,
        "nape": [(86, 82), (104, 82), (109, 95), (81, 95)],
        "torso": [(88, 87), (79, 92), (66, 102), (62, 112), (63, 126), (66, 142), (71, 157), (68, 177), (82, 184),
                  (116, 184), (129, 178), (124, 156), (127, 136), (127, 118), (134, 100), (116, 89), (102, 87)],
        "spine": [(95, 92), (93, 112), (92, 132), (94, 152), (97, 172)],
        "gown_l": [(92, 89), (80, 92), (66, 100), (58, 106), C(55, 123), (62, 127), (60, 142), (60, 162), (58, 180),
                   C(60, 190), (66, 186), (71, 192), (77, 187), (82, 191), C(87, 186), (86, 170), (84, 150),
                   (85, 130), (88, 110), C(92, 95)],
        "gown_r": [C(99, 89), (103, 110), (108, 130), (110, 150), (110, 170), C(112, 189), (118, 193), (124, 188),
                   (131, 193), C(137, 187), (136, 168), (134, 148), (132, 130), C(131, 118), (136, 111), C(147, 104),
                   (148, 97), C(144, 89), (130, 92), (116, 89)],
        "arm_r": [(128, 101), (146, 95), (161, 92), (152, 78), (139, 68)],
        "arm_r_w": [(9.5, 9.5), (6.6, 6.4), (6.2, 6.6), (6.2, 5.6), (4.4, 4.4)],
        "l_fore": [(122, 81), (113, 94), (103, 104)],
        "pipe": ((117, 92), (163, 2)), "grip": (0.12, 0.26),
        "leg_l": [(80, 176), (76, 195), (70, 214), (71, 232), (75, 249)],
        "leg_l_w": [(9, 9), (8, 7.4), (5.6, 5.6), (7.2, 6.4), (3.8, 3.8)],
        "leg_r": [(117, 176), (121, 198), (127, 219), (129, 237), (129, 253)],
        "leg_r_w": [(9.4, 9.4), (8.4, 7.8), (5.8, 5.8), (7.4, 6.6), (3.8, 3.8)],
        "heel_l": (75, 249, 0.0), "heel_r": (129, 253, 1.0),
        "brief": [(86, 168), (110, 168), (111, 184), (86, 184)],
    }


def _shift(p: dict, dy_of, dx_of=None) -> dict:
    """Desplaza los puntos de la parte alta del cuerpo (respiración)."""
    def mv(pt):
        if isinstance(pt, tuple) and len(pt) == 2 and all(isinstance(v, (int, float)) for v in pt):
            x, y = pt
            nx = x + (dx_of(y) if dx_of else 0)
            q = (nx, y + dy_of(y))
            return C(*q) if isinstance(pt, C) else q
        return pt
    out = {}
    for k, v in p.items():
        if k.startswith("leg") or k.startswith("heel") or k in ("tilt", "grip", "arm_r_w"):
            out[k] = v
        elif isinstance(v, list):
            out[k] = [mv(x) for x in v]
        elif isinstance(v, tuple) and len(v) == 2 and isinstance(v[0], tuple):
            out[k] = (mv(v[0]), mv(v[1]))
        else:
            out[k] = mv(v)
    return out


def breathe(b: float) -> dict:
    return _shift(guard(), lambda y: -b * max(0.0, min(1.0, (176 - y) / 90)))


def windup() -> dict:
    """Carga: más enroscado, el tubo más atrás por encima del hombro, la cabeza hundida."""
    p = guard()
    p = _shift(p, lambda y: 2 * max(0.0, min(1.0, (176 - y) / 90)), lambda y: 2 * max(0.0, min(1.0, (176 - y) / 90)))
    p["arm_r"] = [(130, 102), (148, 94), (164, 86), (160, 70), (148, 60)]
    p["pipe"] = ((134, 76), (196, 22))
    p["grip"] = (0.1, 0.24)
    p["l_fore"] = [(138, 72), (124, 88), (110, 100)]
    p["head"] = (96, 78)
    return p


def impact() -> dict:
    """Impacto: el tubo descarga en diagonal hacia delante y a la izquierda; el tronco gira."""
    p = guard()
    p["head"] = (92, 76)
    p["torso"] = [(86, 88), (76, 92), (62, 100), (58, 112), (61, 128), (66, 142), (71, 157), (68, 177), (82, 184),
                  (116, 184), (128, 178), (122, 156), (122, 136), (120, 118), (122, 104), (110, 90), (100, 88)]
    p["gown_l"] = [(90, 90), (78, 92), (62, 98), (54, 104), C(50, 118), (60, 124), (60, 142), (60, 162), (58, 180),
                   C(60, 190), (66, 186), (71, 192), (77, 187), (82, 191), C(87, 186), (86, 170), (84, 150),
                   (85, 130), (87, 110), C(90, 95)]
    p["gown_r"] = [C(97, 90), (101, 110), (106, 130), (108, 150), (110, 170), C(112, 189), (118, 193), (124, 188),
                   (131, 193), C(136, 187), (133, 168), (128, 148), (124, 130), C(121, 116), (123, 106), C(118, 92),
                   (110, 89)]
    p["arm_r"] = [(118, 100), (106, 92), (92, 86), (78, 70), (66, 56)]
    p["arm_r_w"] = [(8, 8), (6.4, 6.4), (6, 6.4), (5.8, 5.4), (4.2, 4.2)]
    p["l_fore"] = [(60, 60), (56, 82), (58, 104)]
    p["pipe"] = ((70, 62), (12, 14))
    p["grip"] = (0.06, 0.2)
    p["leg_r"] = [(117, 176), (122, 198), (130, 220), (133, 238), (134, 252)]
    p["heel_r"] = (134, 252, 1.6)
    return p


def recoil() -> dict:
    """Retroceso: el golpe rebota, el tubo baja a la izquierda, el cuerpo se encoge."""
    p = impact()
    p = _shift(p, lambda y: 3 * max(0.0, min(1.0, (176 - y) / 90)))
    p["arm_r"] = [(118, 103), (104, 98), (90, 96), (76, 92), (64, 90)]
    p["l_fore"] = [(58, 92), (58, 104), (62, 116)]
    p["pipe"] = ((66, 98), (10, 66))
    p["head"] = (91, 81)
    return p


# =============================================================================================

def draw(p: dict) -> Fig:
    f = Fig(W, H, K, LIGHT, LZ)
    pa, pb = p["pipe"]
    u = (pb[0] - pa[0], pb[1] - pa[1])
    ln = math.hypot(*u)
    u = (u[0] / ln, u[1] / ln)
    n = (-u[1], u[0])
    if n[0] < 0:
        n = (-n[0], -n[1])
    g_l = lerp(pa, pb, p["grip"][0])
    g_r = lerp(pa, pb, p["grip"][1])

    # --- piel: piernas, antebrazo izquierdo (detrás), tronco, cuello, brazo derecho ---
    skin_parts = []
    for leg, wk in (("leg_l", "leg_l_w"), ("leg_r", "leg_r_w")):
        skin_parts.append(f.shape(limb_outline(p[leg], p[wk])))
    for hk in ("heel_l", "heel_r"):
        x, y, lift = p[hk]
        heel = [(x - 5, y - 2), (x + 5, y - 2), (x + 6.5, y + 6 - lift * 3), (x + 4.5, y + 13 - lift * 2),
                (x, y + 15 - lift * 1.5), (x - 4.5, y + 13 - lift * 2), (x - 6.5, y + 6 - lift * 3)]
        skin_parts.append(f.shape(heel))
    skin_parts.append(f.stroke(p["l_fore"], 9.0))
    skin_parts.append(f.shape(p["torso"]))
    skin_parts.append(f.shape(p["nape"]))
    skin_parts.append(f.shape(limb_outline(p["arm_r"], p["arm_r_w"])))
    for part in skin_parts:
        f.fill(part, "skin", 0.3)
    legs = np.maximum(skin_parts[0], skin_parts[1])
    # ropa interior bajo la abertura
    f.fill(f.shape(p["brief"]), "brief", 0.45)
    # --- bata: dos paneles y la manga del brazo alzado ---
    gl = f.shape(p["gown_l"])
    gr = f.shape(p["gown_r"])
    f.fill(gl, "gown", 0.42)
    f.fill(gr, "gown", 0.42)
    # --- cabeza (cráneo rapado y orejas), algo inclinada ---
    hx, hy = p["head"]
    ct, st = math.cos(p["tilt"]), math.sin(p["tilt"])

    def R(pts):
        return [(hx + x * ct - y * st, hy + x * st + y * ct) for x, y in pts]

    skull = R([(0, -16), (9, -14.5), (13.6, -7.5), (14.2, 1.5), (12.4, 8.6), (7.6, 13.6), (0, 15), (-7.6, 13.6),
               (-12.4, 8.6), (-14.2, 1.5), (-13.6, -7.5), (-9, -14.5)])
    ear_r = R([(13.2, -1.5), (16.6, -0.6), (17.4, 4.6), (15.2, 9.0), (12.8, 6.4)])
    ear_l = R([(-13.2, -1.5), (-16.6, -0.6), (-17.4, 4.6), (-15.2, 9.0), (-12.8, 6.4)])
    f.fill(f.shape(ear_r), "skin", 0.36)
    f.fill(f.shape(ear_l), "skin", 0.36)
    head_m = f.shape(skull)
    f.fill(head_m, "scalp", 0.46)
    # --- tubo de hierro (por detrás de los puños) ---
    pipe = f.stroke([pa, pb], 5.2)
    tipc = (pb[0] - u[0] * 3, pb[1] - u[1] * 3)
    coupling = f.poly([(tipc[0] + n[0] * 4.6 - u[0] * 5, tipc[1] + n[1] * 4.6 - u[1] * 5),
                       (tipc[0] - n[0] * 4.6 - u[0] * 5, tipc[1] - n[1] * 4.6 - u[1] * 5),
                       (tipc[0] - n[0] * 4.6 + u[0] * 4, tipc[1] - n[1] * 4.6 + u[1] * 4),
                       (tipc[0] + n[0] * 4.6 + u[0] * 4, tipc[1] + n[1] * 4.6 + u[1] * 4)])
    f.fill(np.maximum(pipe, coupling), "iron", 0.5)
    # --- puños: los dedos rodean el tubo, apilados a lo largo de él; el pulgar por encima ---
    fists = []
    for c, sd in ((g_l, 0), (g_r, 1)):
        a = 5.6
        pts = [(c[0] - u[0] * a - n[0] * 5.4, c[1] - u[1] * a - n[1] * 5.4),
               (c[0] + u[0] * a - n[0] * 5.0, c[1] + u[1] * a - n[1] * 5.0),
               (c[0] + u[0] * (a + 1) + n[0] * 2, c[1] + u[1] * (a + 1) + n[1] * 2),
               (c[0] + u[0] * a + n[0] * 7.0, c[1] + u[1] * a + n[1] * 7.0),
               (c[0] - u[0] * a + n[0] * 7.4, c[1] - u[1] * a + n[1] * 7.4),
               (c[0] - u[0] * (a + 1.4) + n[0] * 2, c[1] - u[1] * (a + 1.4) + n[1] * 2)]
        fm = f.shape(pts)
        f.fill(fm, "skin", 0.42)
        fists.append((c, fm))

    # =========================== pintura ===========================
    skin = f.of("skin")
    f.mass(skin, soft=7.0, hard=0.12, fill=0.04, edge=0.12, clip="skin")
    for part in skin_parts[:2]:
        f.mass(part > 0.5, soft=3.2, hard=0.3, fill=0.06, edge=0.08, clip="skin")
    f.mass(skin_parts[-1] > 0.5, soft=3.0, hard=0.24, fill=0.1, edge=0.06, clip="skin")
    # anatomía de las piernas: corvas, gemelos, tendón de Aquiles, talón sucio
    for leg in ("leg_l", "leg_r"):
        hip, mid, knee, calf, ank = p[leg]
        f.crease([(knee[0] - 4.6, knee[1] + 0.6), (knee[0], knee[1] + 1.6), (knee[0] + 4.6, knee[1] + 0.2)], 0.3, 1.0, 0.5)
        f.crease([(knee[0] - 3.4, knee[1] - 9), (knee[0] - 3.0, knee[1] + 1)], 0.16, 1.0, 0.6, ridge=0.12,
                 ridge_off=(-1.2, 0))
        f.crease([(knee[0] + 3.4, knee[1] - 9), (knee[0] + 3.0, knee[1] + 1)], 0.16, 1.0, 0.6, ridge=0.12,
                 ridge_off=(1.2, 0))
        for side in (-1, 1):
            g = f.ellipse((calf[0] + side * 2.8, calf[1] - 4), 3.4, 7.5, 0.1 * side)
            f.mass(g > 0.5, soft=2.2, hard=0.1, fill=0.06, edge=0.0, clip="skin")
        f.crease([lerp(knee, calf, 0.4), lerp(calf, ank, 0.5)], 0.14, 0.9, 0.7)
        f.crease([lerp(calf, ank, 0.45), (ank[0], ank[1] + 2)], -0.16, 1.4, 0.6)
    for hk in ("heel_l", "heel_r"):
        x, y, lift = p[hk]
        f.stain((x, y + 12 - lift * 2), 5.5, "dirt", int(x), val=0.42, stretch=(1.2, 0.7), ring=0.06)
        f.crease([(x - 3.6, y + 10 - lift), (x + 3.6, y + 11 - lift)], 0.18, 0.7, 0.4)
    # espalda en la abertura: columna, omóplatos, costillas
    sp = p["spine"]
    f.crease(sp, 0.26, 1.6, 0.9, ridge=0.14, ridge_off=(1.4, 0), clip="skin")
    sc_l = f.shape([(sp[0][0] - 4, sp[0][1] + 8), (sp[0][0] - 14, sp[0][1] + 10), (sp[0][0] - 15, sp[0][1] + 30),
                    (sp[0][0] - 5, sp[0][1] + 26)])
    sc_r = f.shape([(sp[0][0] + 6, sp[0][1] + 6), (sp[0][0] + 22, sp[0][1] + 6), (sp[0][0] + 22, sp[0][1] + 28),
                    (sp[0][0] + 9, sp[0][1] + 30)])
    for sc in (sc_l, sc_r):
        f.mass(sc > 0.5, soft=2.6, hard=0.2, fill=0.1, edge=0.0, clip="skin")
    for i in range(3):
        y = sp[2][1] + i * 6
        f.crease([(sp[2][0] - 9, y), (sp[2][0] - 3, y + 2)], 0.12, 0.8, 0.6, clip="skin")
        f.crease([(sp[2][0] + 3, y + 2), (sp[2][0] + 11, y)], 0.12, 0.8, 0.6, clip="skin")
    f.stain(lerp(sp[1], sp[3], 0.5), 3.6, "bruise", 31, val=0.32, stretch=(0.7, 3.4), ring=0.0, clip="skin")
    # brazo: deltoides, codo, tendones del antebrazo, venas
    ar = p["arm_r"]
    dl = f.ellipse(lerp(ar[0], ar[1], 0.3), 7.5, 6.5, 0.0)
    f.mass(dl > 0.5, soft=2.6, hard=0.2, fill=0.1, edge=0.0, clip="skin")
    f.crease([(ar[2][0] - 2, ar[2][1] - 2), (ar[2][0] + 3, ar[2][1] + 1)], 0.2, 0.9, 0.5)
    f.crease([lerp(ar[2], ar[4], 0.15), lerp(ar[2], ar[4], 0.85)], -0.14, 1.2, 0.6, clip="skin")
    f.veins(lerp(ar[2], ar[4], 0.2), 10, 41, math.atan2(ar[4][1] - ar[2][1], ar[4][0] - ar[2][0]), depth=0.12,
            mat="bruise", width=0.6)
    # nuca: tendones y pliegue
    nk = p["nape"]
    f.crease([(nk[0][0] + 3, nk[0][1] + 2), (nk[3][0] + 6, nk[3][1] - 1)], 0.16, 1.2, 0.6, ridge=0.12,
             ridge_off=(-1.2, 0), clip="skin")
    f.crease([(nk[1][0] - 3, nk[1][1] + 2), (nk[2][0] - 6, nk[2][1] - 1)], 0.16, 1.2, 0.6, ridge=0.12,
             ridge_off=(1.2, 0), clip="skin")
    # puños: dedos apilados (pliegues perpendiculares al tubo), nudillos claros, pulgar
    for c, fm in fists:
        f.mass(fm > 0.5, soft=2.0, hard=0.22, fill=0.1, edge=0.08, clip="skin")
        for o in (-2.8, 0.0, 2.8):
            a = (c[0] + u[0] * o + n[0] * 0.5, c[1] + u[1] * o + n[1] * 0.5)
            b = (c[0] + u[0] * o + n[0] * 7.2, c[1] + u[1] * o + n[1] * 7.2)
            f.crease([a, b], 0.3, 0.7, 0.3, clip="skin")
        for o in (-4.2, -1.4, 1.4, 4.2):
            kp = (c[0] + u[0] * o + n[0] * 6.0, c[1] + u[1] * o + n[1] * 6.0)
            f.paint(f.ellipse(kp, 1.2, 1.2), 0.22, 0.2, clip="skin")
        th = f.shape([(c[0] - n[0] * 5 - u[0] * 4, c[1] - n[1] * 5 - u[1] * 4), (c[0] - n[0] * 6.4 + u[0] * 1, c[1] - n[1] * 6.4 + u[1] * 1),
                      (c[0] - n[0] * 2 + u[0] * 4.6, c[1] - n[1] * 2 + u[1] * 4.6), (c[0] - n[0] * 1 + u[0] * 1, c[1] - n[1] * 1 + u[1] * 1)])
        f.crease([(c[0] - n[0] * 5.6 - u[0] * 3, c[1] - n[1] * 5.6 - u[1] * 3), (c[0] - n[0] * 1.5 + u[0] * 3.6, c[1] - n[1] * 1.5 + u[1] * 3.6)],
                 0.2, 0.7, 0.4, clip="skin")
        _ = th
    f.noise(0.1, 6.0, 1, clip="skin")
    f.noise(0.05, 1.5, 2, clip="skin")
    f.pores(0.06, 0.7, 0.12, 3, clip="skin")
    f.stain(lerp(p["leg_l"][2], p["leg_l"][3], 0.6), 2.2, "bruise", 4, val=0.3, stretch=(0.8, 1.6), ring=0.0, clip="skin")
    f.stain(lerp(p["leg_r"][0], p["leg_r"][1], 0.9), 1.8, "bruise", 5, val=0.3, stretch=(1.2, 0.8), ring=0.0, clip="skin")
    # cabeza: volumen, pelo rapado, nuca, cicatriz
    f.mass(head_m > 0.5, soft=5.0, hard=0.26, fill=0.12, edge=0.1, clip=["scalp", "skin"])
    f.pores(0.07, 0.5, 0.35, 6, clip="scalp")
    f.noise(0.06, 3.0, 7, clip="scalp")
    f.crease(R([(-11, 11), (0, 13.6), (11, 11)]), 0.18, 1.4, 0.8)
    for e in (ear_r, ear_l):
        f.crease(e[1:4], 0.2, 0.7, 0.4)
    scar = R([(5, -15), (-1, -12), (-7, -6.5), (-11, 0.5), (-12.2, 6)])
    f.stain(lerp(scar[1], scar[3], 0.5), 2.4, "bruise", 8, val=0.35, stretch=(0.8, 2.2), ring=0.0, clip="scalp")
    f.crease(scar, 0.22, 1.0, 0.3, ridge=0.16, ridge_off=(1.0, 0.4))
    # ropa interior
    f.mass(f.of("brief"), soft=3.0, hard=0.1, fill=0.1, edge=0.1, clip="brief")
    f.crease([(p["brief"][0][0], p["brief"][0][1] + 1), (p["brief"][1][0], p["brief"][1][1] + 1)], -0.2, 0.8, 0.4,
             clip="brief")
    # bata: volumen, pliegues de tracción (del brazo alzado), caída, bajo, textura, manchas
    gown = f.of("gown")
    for gm in (gl, gr):
        f.mass(gm > 0.5, soft=6.0, hard=0.3, fill=0.08, edge=0.16, clip="gown")
    gr_pts = p["gown_r"]
    gl_pts = p["gown_l"]
    folds = [
        [(gr_pts[14][0] - 2, gr_pts[14][1] + 2), (118, 128), (108, 150)],
        [(gr_pts[13][0], gr_pts[13][1] + 4), (124, 140), (118, 164), (116, 186)],
        [(gr_pts[15][0] - 4, gr_pts[15][1] + 4), (128, 116), (120, 124)],
        [(gl_pts[3][0] + 6, gl_pts[3][1] + 2), (70, 128), (68, 156), (66, 184)],
        [(gl_pts[2][0] + 10, gl_pts[2][1] + 2), (78, 120), (78, 150), (78, 186)],
        [(gl_pts[1][0], gl_pts[1][1] + 4), (84, 108)],
        [(104, 170), (106, 186)], [(62, 166), (64, 186)], [(96, 176), (100, 190)],
        [(126, 160), (130, 186)], [(72, 160), (74, 189)], [(66, 106), (64, 124)],
    ]
    for fl in folds:
        f.crease(fl, 0.34, 1.3, 0.8, ridge=0.22, ridge_off=(-1.5, -0.4), clip="gown")
    f.crease(gl_pts[-6:], -0.18, 1.0, 0.4, clip="gown")                               # canto doblado de la abertura
    f.crease(gr_pts[:6], 0.0, 1.0, 0.4, ridge=-0.0, clip="gown")
    f.crease([(x + 1.6, y) for x, y in gr_pts[:5]], 0.3, 1.6, 0.8, clip=["skin", "bruise", "brief"])
    f.crease([(x - 1.2, y) for x, y in gl_pts[-5:]], 0.22, 1.4, 0.8, clip=["skin", "bruise", "brief"])
    f.paint(f.poly([(40, 176), (160, 176), (160, 200), (40, 200)]), -0.16, 4.0, clip="gown")
    f.weave(0.035, 0.5, clip="gown")
    f.noise(0.12, 9.0, 11, clip="gown")
    f.noise(0.05, 2.0, 16, clip="gown")
    f.pores(0.08, 0.6, 0.04, 12, clip="gown")
    f.stain((66, 182), 7.0, "dirt", 13, val=0.4, stretch=(1.6, 0.6), ring=0.06, clip="gown")
    f.stain((131, 150), 3.4, "dry", 14, val=0.45, stretch=(0.7, 2.0), ring=0.1, drip=1.0, clip="gown")
    f.stain((72, 112), 3.0, "dirt", 15, val=0.38, stretch=(1.0, 1.0), ring=0.03, clip="gown")
    # nudos de la bata: uno en la nuca y otro suelto a media espalda
    knot = f.shape([(91, 90), (99, 89), (100, 94), (92, 95)])
    f.fill(knot, "gown", 0.62)
    f.fill(f.stroke([(93, 95), (90, 104), (91, 110)], 1.6), "gown", 0.6)
    f.fill(f.stroke([(98, 95), (100, 102)], 1.4), "gown", 0.5)
    f.fill(f.stroke([(85, 128), (90, 131), (89, 138)], 1.6), "gown", 0.6)
    # tubo: hierro con reflejo, rosca, óxido y sangre en el codo de la punta
    iron = f.of("iron")
    f.mass(iron, soft=1.4, hard=0.3, fill=0.1, edge=0.05, clip="iron")
    f.crease([(pa[0] - n[0] * 1.2, pa[1] - n[1] * 1.2), (pb[0] - n[0] * 1.2, pb[1] - n[1] * 1.2)], -0.34, 0.6, 0.3,
             clip="iron")
    for t in (0.5, 0.78):
        f.stain(lerp(pa, pb, t), 1.6, "rust", int(t * 100), val=0.3, ring=0.06, clip="iron")
    f.stain(tipc, 3.4, "dry", 21, val=0.4, ring=0.1, clip="iron", wet=0.2)
    for i in range(3):
        q = (pa[0] + u[0] * (1.5 + i * 1.6), pa[1] + u[1] * (1.5 + i * 1.6))
        f.crease([(q[0] - n[0] * 2.6, q[1] - n[1] * 2.6), (q[0] + n[0] * 2.6, q[1] + n[1] * 2.6)], 0.3, 0.5, 0.2,
                 clip="iron")
    # muñeca derecha: pulsera; mano izquierda: esparadrapo y la vía arrancada colgando
    wr = p["arm_r"][4]
    w3 = p["arm_r"][3]
    b0 = lerp(wr, w3, 0.15)
    b1 = lerp(wr, w3, 0.42)
    band = f.shape(limb_outline([b0, b1], [(5.2, 5.2), (5.4, 5.4)]))
    f.fill(band, "band", 0.62, inside=True)
    f.mass(band > 0.5, soft=1.2, hard=0.25, fill=0.1, edge=0.08, clip="band")
    f.crease([lerp(b0, b1, 0.5), (lerp(b0, b1, 0.5)[0] + 2, lerp(b0, b1, 0.5)[1] + 2.6)], 0.4, 0.5, 0.2, clip="band")
    lf = p["l_fore"]
    tp = lerp(lf[0], lf[1], 0.3)
    f.fill(f.shape([(tp[0] - 3.5, tp[1] - 2.6), (tp[0] + 3.2, tp[1] - 3.2), (tp[0] + 3.8, tp[1] + 2.4),
                    (tp[0] - 3.0, tp[1] + 3.0)]), "tape", 0.6, inside=True)
    tube = f.stroke([tp, (tp[0] + 2, tp[1] + 7), (tp[0] + 1, tp[1] + 13)], 1.2)
    f.fill(tube, "tube", 0.45)
    f.stain((tp[0] + 1, tp[1] + 4), 2.4, "blood", 22, val=0.4, stretch=(0.6, 2.0), ring=0.1, drip=1.5, clip="skin", wet=0.25)
    # incisión cosida sobre la columna (los puntos se retocan a escala 1)
    inc = [lerp(sp[1], sp[2], 0.0), sp[2], sp[3], lerp(sp[3], sp[4], 0.4)]
    f.fill(f.stroke(inc, 1.6), "flesh", 0.32, inside=True)
    f.fill(f.stroke([(x + 0.6, y) for x, y in inc], 0.6), "flesh", 0.62, inside=True)
    f.stain(lerp(sp[2], sp[3], 0.6), 1.4, "dry", 23, val=0.35, stretch=(0.6, 1.4), ring=0.06, clip="flesh")
    # luz: contraluz frío desde arriba a la derecha y la sombra de la bata sobre las piernas
    f.rim((26, 34, 48), (0.7, -0.7), 2.2, 1.0)
    f.paint(f.poly([(40, 184), (160, 184), (160, 200), (40, 200)]), -0.22, 3.0, clip="skin")
    f.paint(f.poly([(40, 236), (160, 236), (160, 280), (40, 280)]), -0.12, 6.0, clip=["skin", "dirt"])

    # retoques a escala 1: puntos de sutura de la columna y de la cicatriz del cráneo
    def stitches(out: np.ndarray) -> None:
        dark = np.array([22, 14, 18], np.uint8)
        for i in range(7):
            q = lerp(inc[0], inc[-1], (i + 0.5) / 7)
            x, y = int(q[0]), int(q[1])
            for dx in (-2, -1, 1, 2):
                if out[y, x + dx, 3]:
                    out[y + (1 if dx > 0 else 0), x + dx, :3] = dark
        for i in range(5):
            q = lerp(scar[0], scar[-1], (i + 0.5) / 5)
            x, y = int(q[0]), int(q[1])
            for dx, dy in ((-1, -1), (1, 1)):
                if out[y + dy, x + dx, 3]:
                    out[y + dy, x + dx, :3] = dark
    f.touch(stitches)
    return f


POSES = {
    "guard_0": lambda: breathe(0), "guard_1": lambda: breathe(1), "guard_2": lambda: breathe(2),
    "guard_3": lambda: breathe(1),
    "windup": windup, "impact": impact, "recoil": recoil,
}


def frame(name: str) -> Image.Image:
    return draw(POSES[name]()).render(pal.HERO, dither=9.0)


def silhouette(name: str) -> Image.Image:
    return draw(POSES[name]()).silhouette()


if __name__ == "__main__":
    from paint import row, upscale
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n/v3_hero.png"
    names = sys.argv[2].split(",") if len(sys.argv) > 2 else ["guard_0"]
    ims = [frame(nm) for nm in names]
    sil = [silhouette(nm) for nm in names]
    upscale(row(ims + sil, gap=6), 2).save(out)
