"""El enfermero transfigurado, tercera muestra (400×540), con el método `vec`.

Silueta orgánica y amenazante: muy encorvado, la joroba de la columna asomando por encima de la cabeza,
que cuelga ladeada entre los hombros; brazos demasiado largos; el derecho fundido con instrumental
(bisturíes abiertos en abanico como dedos, una sierra de hueso por el canto, abrazaderas y grapas
donde la carne se une al metal); jeringa de cristal en la izquierda. Anatomía consumida bajo el
uniforme rasgado (esternón, costillas, clavículas, tendones), uniforme con peso y pliegues, sangre seca
y fresca con brillo, mascarilla cosida con los puntos tirando de la piel, máscara de porcelana agrietada
con un ojo vivo y húmedo, tubos que entran en el pecho con la piel fruncida. Luz lateral fría y
contraluz granate.

Piezas (para las mutilaciones): 0 tronco, 1 cabeza, 2 brazo derecho (instrumental), 3 brazo
izquierdo (jeringa), 4 pierna derecha, 5 pierna izquierda, 6 muñón. `Fig.split` las separa del
dibujo final.
"""

from __future__ import annotations

import math
import os
import random
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import palette_v3 as pal  # noqa: E402
from vec import C, Fig, lerp, limb_outline  # noqa: E402

W, H = 400, 540
K = 4
LIGHT = (-0.86, -0.42)
LZ = 0.34
PARTS = ["tronco", "cabeza", "brazo_der", "brazo_izq", "pierna_der", "pierna_izq", "muñon"]


def _u(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dy) or 1
    return dx / n, dy / n


def pose_idle(b: float = 0.0) -> dict:
    return {
        "b": b, "tilt": -0.5 - b * 0.01, "head": (166, 162 + b),
        "sh_r": (126, 116 + b), "el_r": (92, 228 + b), "wr_r": (104, 322 + b),
        "sh_l": (274, 108 + b), "el_l": (314, 214 + b), "wr_l": (300, 304 + b),
        "hip_r": (172, 300), "knee_r": (158, 402), "ank_r": (166, 498),
        "hip_l": (228, 300), "knee_l": (248, 404), "ank_l": (236, 500),
        "fan": 0.0,
    }


def pose_attack() -> dict:
    p = pose_idle(-2)
    p.update({"sh_r": (128, 108), "el_r": (70, 62), "wr_r": (118, 30), "tilt": -0.3, "head": (172, 156),
              "sh_l": (272, 112), "el_l": (318, 206), "wr_l": (312, 290)})
    return p


def draw(p: dict, missing: tuple[str, ...] = ()) -> Fig:
    f = Fig(W, H, K, LIGHT, LZ)
    b = p["b"]
    # ---------------- piernas (pantalón roto a media espinilla, pie desnudo) ----------------
    for i, side in ((4, "r"), (5, "l")):
        f.cur = i
        hip, knee, ank = p["hip_" + side], p["knee_" + side], p["ank_" + side]
        sg = -1 if side == "r" else 1
        mid_t = lerp(hip, knee, 0.5)
        calf = lerp(knee, ank, 0.3)
        f.fill(f.shape(limb_outline([hip, mid_t, knee, calf, lerp(knee, ank, 0.7), ank],
                                    [(20, 20), (17, 17), (13, 13), (13.5, 12.5), (9, 9), (7.5, 7.5)])), "nskin", 0.4)
        foot = [(ank[0] - 9, ank[1] - 4), (ank[0] + 9, ank[1] - 4), (ank[0] + 15 + sg * 5, ank[1] + 18),
                (ank[0] + 14 + sg * 6, ank[1] + 28), (ank[0] - 14 + sg * 5, ank[1] + 28), (ank[0] - 15 + sg * 4, ank[1] + 18)]
        f.fill(f.shape(foot), "nskin", 0.42)
        hem = lerp(knee, ank, 0.42)
        rnd = random.Random(i)
        trouser = limb_outline([hip, mid_t, knee, hem], [(22, 22), (19, 19), (16, 16), (15.5, 15.5)])
        rag = [(hem[0] - 15.5, hem[1])]
        for k in range(8):
            rag.append((hem[0] - 15.5 + (k + 0.5) * 31 / 8, hem[1] + (rnd.uniform(5, 16) if k % 2 else rnd.uniform(-2, 3))))
        f.fill(f.shape(trouser[: len(trouser) // 2] + rag[::-1] + trouser[len(trouser) // 2:]), "uniform", 0.48)
        # rodillera rota con la rótula huesuda
        f.fill(f.shape([(knee[0] - 9, knee[1] - 6), (knee[0] + 2, knee[1] - 11), (knee[0] + 10, knee[1] - 3),
                        (knee[0] + 7, knee[1] + 8), (knee[0] - 4, knee[1] + 10), (knee[0] - 10, knee[1] + 3)]),
               "nskin", 0.46, inside=True)
    # ---------------- tronco: túnica sobre el cuerpo consumido, joroba ----------------
    f.cur = 0
    body = [(176, 92), (196, 74), (214, 70), (232, 80), (250, 98), (266, 106), (280, 120), (282, 140), (276, 160),
            (266, 196), (252, 232), (248, 262), (252, 300), (148, 300), (152, 262), (148, 232), (132, 196),
            (122, 162), (112, 136), (112, 116), (130, 104), (152, 98)]
    body = [(x, y + b * (1 - y / 300)) for x, y in body]
    f.fill(f.shape(body), "nskin", 0.4)
    tunic = [(150, 100), (174, 94), (192, 76), (210, 68), (230, 78), (250, 102),
             (266, 108), (280, 122), (284, 142), (278, 162), (270, 196), (260, 232), (256, 262), (262, 296),
             (266, 322), (256, 318), (248, 330), (238, 320), (226, 334), (214, 322), (200, 336), (188, 322),
             (176, 334), (164, 320), (152, 330), (138, 318), (142, 296), (146, 262), (142, 232), (130, 196),
             (120, 162), (114, 140), (116, 120), (132, 106)]
    tunic = [((x, y + b * (1 - y / 330)) if not isinstance((x, y), C) else C(x, y + b * (1 - y / 330))) for x, y in tunic]
    f.fill(f.shape(tunic), "uniform", 0.5)
    # desgarro del pecho: esternón y costillas a la vista
    rip = [C(204, 122), (214, 128), C(226, 126), (232, 146), C(242, 156), (238, 178), C(244, 196), (234, 212),
           C(232, 230), (220, 222), C(208, 232), (206, 210), C(196, 196), (202, 176), C(194, 158), (202, 142)]
    rip = [(x, y + b) for x, y in rip]
    f.fill(f.shape(rip), "nskin", 0.5, inside=True)
    rip2 = [(232, 262), (246, 256), (252, 270), (240, 282), (228, 276)]
    f.fill(f.shape(rip2), "nskin", 0.4, inside=True)
    # ---------------- brazos ----------------
    if "arm_r" not in missing:
        f.cur = 2
        sh, el, wr = p["sh_r"], p["el_r"], p["wr_r"]
        ux, uy = _u(el, wr)
        nx, ny = -uy, ux
        out = (nx, ny) if (nx < 0 or (nx == 0 and ny < 0)) else (-nx, -ny)
        # sierra de hueso por el canto exterior
        s0 = lerp(el, wr, 0.18)
        s0 = (s0[0] + out[0] * 10, s0[1] + out[1] * 10)
        s1 = (s0[0] + ux * 150, s0[1] + uy * 150)
        saw = [s0, s1, (s1[0] + out[0] * 22, s1[1] + out[1] * 22), (s0[0] + out[0] * 15, s0[1] + out[1] * 15)]
        f.fill(f.poly(saw), "metal", 0.34)
        teeth = []
        for t in range(1, 32):
            q = lerp(saw[3], saw[2], t / 32)
            teeth += [f.poly([(q[0] - ux * 2.4, q[1] - uy * 2.4), (q[0] + ux * 2.4, q[1] + uy * 2.4),
                              (q[0] + out[0] * 4.5 + ux * 1, q[1] + out[1] * 4.5 + uy * 1)])]
        f.fill(np.maximum.reduce(teeth), "metal", 0.45)
        # bisturíes en abanico, como dedos abiertos
        blades = []
        for k, (ang, ln) in enumerate(((-0.62, 78), (-0.32, 96), (-0.04, 104), (0.25, 92), (0.52, 70))):
            d = (ux * math.cos(ang) - uy * math.sin(ang), ux * math.sin(ang) + uy * math.cos(ang))
            bn = (-d[1], d[0])
            base = (wr[0] + ux * 10 + bn[0] * (k - 2) * 3, wr[1] + uy * 10 + bn[1] * (k - 2) * 3)
            tip = (base[0] + d[0] * ln, base[1] + d[1] * ln)
            cv = 1 if ang < 0 else -1
            belly = (base[0] + d[0] * ln * 0.62 + bn[0] * 6.5 * cv, base[1] + d[1] * ln * 0.62 + bn[1] * 6.5 * cv)
            spine = (base[0] + d[0] * ln * 0.8 - bn[0] * 1.6 * cv, base[1] + d[1] * ln * 0.8 - bn[1] * 1.6 * cv)
            pts = [C(base[0] - bn[0] * 2.6 * cv, base[1] - bn[1] * 2.6 * cv), spine, C(*tip), belly,
                   C(base[0] + bn[0] * 4 * cv, base[1] + bn[1] * 4 * cv)]
            f.fill(f.shape(pts, 0.6), "metal", 0.38)
            blades.append((base, tip, belly, spine, d, bn, cv))
        # brazo largo y descarnado
        f.fill(f.shape(limb_outline([sh, lerp(sh, el, 0.3), lerp(sh, el, 0.7), el, lerp(el, wr, 0.3), lerp(el, wr, 0.7), wr],
                                    [(18, 16), (15, 13), (10, 9.5), (11.5, 11), (15, 14), (16, 15.5), (15, 15)])),
               "nskin", 0.4)
        stump = [(wr[0] + nx * 16 - ux * 6, wr[1] + ny * 16 - uy * 6), (wr[0] - nx * 16 - ux * 6, wr[1] - ny * 16 - uy * 6),
                 (wr[0] - nx * 13 + ux * 14, wr[1] - ny * 13 + uy * 14), (wr[0] + nx * 13 + ux * 14, wr[1] + ny * 13 + uy * 14)]
        f.fill(f.shape(stump), "flesh", 0.36)
        clamps = []
        for t in (0.42, 0.78):
            q = lerp(el, wr, t)
            clamps.append(f.poly([(q[0] + nx * 17 - ux * 3, q[1] + ny * 17 - uy * 3), (q[0] - nx * 17 - ux * 3, q[1] - ny * 17 - uy * 3),
                                  (q[0] - nx * 17 + ux * 4, q[1] - ny * 17 + uy * 4), (q[0] + nx * 17 + ux * 4, q[1] + ny * 17 + uy * 4)]))
        for cm in clamps:
            f.fill(cm, "metal", 0.4, inside=True)
        f.fill(f.shape([(sh[0] - 14, sh[1] - 6), (sh[0] + 12, sh[1] - 14), (sh[0] + 18, sh[1] + 6), (sh[0] + 10, sh[1] + 28),
                        (sh[0] + 2, sh[1] + 22), (sh[0] - 6, sh[1] + 30), (sh[0] - 15, sh[1] + 22), (sh[0] - 19, sh[1] + 6)]),
               "uniform", 0.5)
        arm_r = (sh, el, wr, blades, saw, clamps, (ux, uy, nx, ny, out))
    else:
        f.cur = 6
        sh = p["sh_r"]
        f.fill(f.shape([(sh[0] - 24, sh[1] - 12), (sh[0] + 14, sh[1] - 18), (sh[0] + 22, sh[1] + 6), (sh[0] + 16, sh[1] + 22),
                        (sh[0] + 4, sh[1] + 16), (sh[0] - 8, sh[1] + 24), (sh[0] - 20, sh[1] + 18), (sh[0] - 28, sh[1] + 4)]),
               "uniform", 0.5)
        cut = [(sh[0] - 18, sh[1] + 14), (sh[0] - 4, sh[1] + 8), (sh[0] + 12, sh[1] + 12), (sh[0] + 18, sh[1] + 24),
               (sh[0] + 12, sh[1] + 38), (sh[0] - 4, sh[1] + 42), (sh[0] - 16, sh[1] + 34)]
        f.fill(f.shape(cut), "flesh", 0.42)
        f.fill(f.shape([(sh[0] - 6, sh[1] + 18), (sh[0] + 6, sh[1] + 16), (sh[0] + 10, sh[1] + 26), (sh[0] + 4, sh[1] + 33),
                        (sh[0] - 6, sh[1] + 31), (sh[0] - 9, sh[1] + 24)]), "bone", 0.6)
        f.fill(f.shape([(sh[0] + 6, sh[1] + 17), C(sh[0] + 12, sh[1] + 6), (sh[0] + 10, sh[1] + 20)]), "bone", 0.7)
        for x, ln in ((sh[0] - 10, 34), (sh[0] + 1, 56), (sh[0] + 12, 22)):
            f.fill(f.stroke([(x, sh[1] + 36), (x + 1, sh[1] + 36 + ln * 0.6), (x, sh[1] + 36 + ln)], 3.0, taper=True), "blood", 0.45)
        arm_r = None
    f.cur = 3
    sh, el, wr = p["sh_l"], p["el_l"], p["wr_l"]
    sx, top = wr[0] - 2, wr[1] - 24
    bot = top + 124
    f.fill(f.poly([(sx - 13, top - 7), (sx + 13, top - 7), (sx + 13, top), (sx - 13, top)]), "metal", 0.5)   # alas
    f.fill(f.poly([(sx - 3.4, top - 48), (sx + 3.4, top - 48), (sx + 3.4, top - 7), (sx - 3.4, top - 7)]), "metal", 0.45)
    f.fill(f.shape([(sx - 12, top - 58), (sx + 12, top - 58), (sx + 12, top - 48), (sx - 12, top - 48)], 0.3), "metal", 0.5)
    f.fill(f.shape([C(sx - 10, top), C(sx + 10, top), (sx + 10.5, bot - 4), (sx + 6, bot), (sx - 6, bot), (sx - 10.5, bot - 4)]),
           "glass", 0.45)
    f.fill(f.poly([(sx - 9, top + 30), (sx + 9, top + 30), (sx + 9, bot - 3), (sx - 9, bot - 3)]), "liquid", 0.3, inside=True)
    f.fill(f.poly([(sx - 9, top + 4), (sx + 9, top + 4), (sx + 9, top + 11), (sx - 9, top + 11)]), "nail", 0.3, inside=True)
    f.fill(f.poly([(sx - 4, bot), (sx + 4, bot), (sx + 2.4, bot + 10), (sx - 2.4, bot + 10)]), "metal", 0.6)
    f.fill(f.stroke([(sx, bot + 10), (sx + 2, bot + 74)], 2.0), "metal", 0.7)
    f.fill(f.shape(limb_outline([sh, lerp(sh, el, 0.3), lerp(sh, el, 0.7), el, lerp(el, wr, 0.3), lerp(el, wr, 0.75), wr],
                                [(17, 16), (14, 12.5), (9.5, 9.5), (11, 11), (13, 12), (9.5, 9), (8, 8)])), "nskin", 0.4)
    hx, hy = wr
    f.fill(f.shape([(sx + 4, hy - 14), (sx + 22, hy - 10), (sx + 24, hy + 18), (sx + 14, hy + 30), (sx + 5, hy + 24)]), "nskin", 0.38)
    fingers = []
    for i in range(4):
        y = hy - 6 + i * 11
        k0, k1, k2 = (sx + 17, y), (sx - 1, y + 4), (sx - 12, y + 8)
        fm = f.shape(limb_outline([k0, k1, k2], [(4.2, 4.2), (3.6, 3.6), (2.6, 2.6)]))
        f.fill(fm, "nskin", 0.44)
        fingers.append((k0, k1, k2))
        f.fill(f.shape([(k2[0] - 3.4, k2[1] - 2.2), (k2[0] + 1, k2[1] - 2.6), (k2[0] + 1.4, k2[1] + 2.2), (k2[0] - 3.4, k2[1] + 2.4)]),
               "nail", 0.35)
    f.fill(f.shape(limb_outline([(sx + 14, hy - 16), (sx + 2, hy - 18), (sx - 8, hy - 14)], [(4.4, 4.4), (3.8, 3.8), (3, 3)])),
           "nskin", 0.46)
    f.fill(f.shape([(sh[0] + 14, sh[1] - 6), (sh[0] - 12, sh[1] - 14), (sh[0] - 18, sh[1] + 6), (sh[0] - 12, sh[1] + 28),
                    (sh[0] - 3, sh[1] + 22), (sh[0] + 5, sh[1] + 30), (sh[0] + 14, sh[1] + 22), (sh[0] + 19, sh[1] + 6)]),
           "uniform", 0.5)
    # ---------------- vías del pecho (por encima de todo el tronco) ----------------
    f.cur = 0
    tubes = []
    for path in ([(250, 94), (252, 116), (246, 140), (234, 160), (222, 172)],
                 [(268, 104), (270, 130), (262, 156), (248, 180), (230, 198)],
                 [(196, 84), (208, 106), (214, 130), (216, 150)]):
        path = [(x, y + b) for x, y in path]
        f.fill(f.stroke(path, 3.6), "liquid", 0.3)
        tubes.append(path)

    # ---------------- cabeza colgando y ladeada ----------------
    f.cur = 1
    hx0, hy0 = p["head"]
    ct, st = math.cos(p["tilt"]), math.sin(p["tilt"])

    HS = 1.32                                     # escala de la cabeza

    def R(pts):
        return [(hx0 + (x * ct - y * st) * HS, hy0 + (x * st + y * ct) * HS) for x, y in pts]

    def Rc(pts):
        return [C(*q) if isinstance(o, C) else q for o, q in zip(pts, R(pts))]

    neck_top = R([(4, -30)])[0]
    neck = [(208, 84 + b), (204, 104 + b), (lerp((204, 104 + b), neck_top, 0.5)[0] - 2, lerp((204, 104 + b), neck_top, 0.5)[1]),
            neck_top]
    f.fill(f.stroke(neck, 11.0), "nskin", 0.34)
    skull = R([(0, -40), (13, -38), (22, -30), (25, -16), (25, 0), (22, 14), (16, 26), (8, 34), (0, 36), (-8, 34),
               (-16, 26), (-22, 14), (-25, 0), (-25, -16), (-22, -30), (-13, -38)])
    f.fill(f.shape(skull), "nskin", 0.4)
    for sd in (-1, 1):
        f.fill(f.shape(R([(sd * 24, -8), (sd * 30, -6), (sd * 31, 6), (sd * 26, 12), (sd * 23, 4)])), "nskin", 0.36)
    mask = Rc([(-23, -18), (-12, -24), (0, -25), (12, -24), (23, -18), (25, -6), (21, 6), (12, 12), (0, 16), (-12, 12),
               (-21, 6), (-25, -6)])
    f.fill(f.shape(mask), "porcelain", 0.6)
    cloth = R([(-21, 6), (-12, 11), (0, 15), (12, 11), (21, 6), (20, 16), (15, 26), (8, 32), (0, 34), (-8, 32), (-15, 26),
               (-20, 16)])
    f.fill(f.shape(cloth), "mask_cloth", 0.45)
    eye_l = R([(-15, -12), (-9, -15), (-3, -13), (-2, -7), (-7, -4), (-14, -6)])
    eye_r = R([(3, -13), (9, -15.5), (15, -12.5), (15.5, -6.5), (9, -4), (3.5, -7)])
    f.fill(f.shape(eye_l), "liquid", 0.06)
    f.fill(f.shape(eye_r), "liquid", 0.12)
    ball = f.ellipse(R([(9.4, -9.6)])[0], 5.2 * HS, 4.0 * HS, p["tilt"])
    f.fill(ball, "eye", 0.6, inside=True)
    chip = R([(-25, 0), (-19, -2), (-16, 6), (-22, 8)])
    f.fill(f.shape(chip), "flesh", 0.4, inside=True)
    # ============================== pintura ==============================
    nsk = f.of("nskin")
    f.mass(nsk, soft=12.0, hard=0.18, fill=0.04, edge=0.14, clip="nskin")
    unif = f.of("uniform")
    f.mass(unif, soft=12.0, hard=0.26, fill=0.06, edge=0.16, clip="uniform")
    # anatomía del pecho rasgado: esternón, costillas, clavículas, la joroba
    rc = lerp(rip[2], rip[6], 0.5)
    f.crease([(rc[0] - 2, rip[0][1] + 4), (rc[0], rc[1] + 20)], -0.2, 2.0, 1.0, clip="nskin")          # esternón
    for i in range(6):
        y = rip[0][1] + 18 + i * 13
        for sd in (-1, 1):
            f.crease([(rc[0] + sd * 3, y), (rc[0] + sd * 14, y + 4), (rc[0] + sd * 24, y + 3)], 0.32, 1.6, 0.8, ridge=0.26,
                     ridge_off=(0, -3.2), clip="nskin")
    f.crease([(170, 104 + b), (188, 112 + b)], -0.22, 2.0, 0.8, clip="nskin")
    f.crease([(212, 112 + b), (232, 104 + b)], -0.18, 2.0, 0.8, clip="nskin")
    hump = f.shape([(184, 90), (198, 66), (214, 62), (230, 76), (222, 96)])
    f.mass(hump > 0.5, soft=6.0, hard=0.2, fill=0.06, edge=0.0, clip=["nskin", "uniform"])
    for i, y in enumerate((70, 80, 90)):                                                   # vértebras bajo la tela
        f.crease([(204 + i * 2, y + b), (216 + i * 2, y + 1 + b)], 0.24, 1.6, 0.8, ridge=0.2, ridge_off=(0, -2.4))
    # túnica: pliegues de peso (de los hombros encorvados), costuras, bajo, roturas, sangre
    folds = [[(138, 110), (150, 150), (148, 196), (152, 240)], [(266, 108), (252, 150), (254, 196), (250, 240)],
             [(160, 120), (176, 170), (170, 220), (176, 262)], [(244, 120), (232, 160), (238, 210), (232, 258)],
             [(156, 262), (166, 290), (164, 322)], [(248, 266), (238, 292), (242, 322)], [(196, 250), (200, 290), (196, 326)],
             [(214, 248), (220, 288), (222, 322)], [(176, 240), (190, 252), (206, 244)], [(130, 150), (140, 176)],
             [(282, 140), (272, 170)]]
    for fl in folds:
        f.crease([(x, y + b * 0.5) for x, y in fl], 0.34, 2.2, 1.4, ridge=0.24, ridge_off=(-2.6, -0.6), clip="uniform")
    f.crease(rip[:6], -0.24, 1.6, 0.6, clip="uniform")
    f.crease([(x + 2, y + 2) for x, y in rip[:7]], 0.32, 2.4, 1.2, clip="nskin")
    f.crease([(x + 2, y + 2) for x, y in rip2], 0.28, 2.0, 1.0, clip="nskin")
    f.weave(0.04, 0.5, clip="uniform")
    f.noise(0.14, 22.0, 101, clip="uniform")
    f.noise(0.06, 5.0, 102, clip="uniform")
    f.pores(0.1, 0.8, 0.03, 103, clip="uniform")
    f.stain((150, 210 + b), 8, "dry", 104, val=0.36, stretch=(0.6, 2.2), ring=0.12)
    f.stain((228, 266 + b), 18, "dry", 105, val=0.36, stretch=(1.0, 1.3), ring=0.08, clip="uniform")
    f.stain((222, 262 + b), 6, "blood", 106, val=0.36, stretch=(0.9, 1.4), ring=0.08, clip=["uniform", "dry"], wet=0.2)
    f.stain((150, 300), 16, "dry", 107, val=0.34, stretch=(1.4, 0.8), ring=0.08, clip="uniform")
    f.stain((262, 150 + b), 9, "dry", 108, val=0.36, stretch=(0.8, 1.8), ring=0.1, clip="uniform")
    f.stain((176, 380), 14, "dry", 109, val=0.34, stretch=(0.8, 2.0), ring=0.08, clip="uniform")
    f.stain((236, 432), 12, "dirt", 110, val=0.4, stretch=(1.2, 0.8), ring=0.06, clip="uniform")
    f.stain((166, 432), 12, "dirt", 111, val=0.4, stretch=(1.2, 0.8), ring=0.06, clip="uniform")
    # piernas: rodillas, espinillas, tendones del pie, dedos, uñas negras
    for side in ("r", "l"):
        hip, knee, ank = p["hip_" + side], p["knee_" + side], p["ank_" + side]
        sg = -1 if side == "r" else 1
        f.crease([(hip[0] + sg * 6, hip[1] + 20), (knee[0] + sg * 10, knee[1] - 40), (knee[0] - sg * 2, knee[1] - 16)],
                 0.3, 2.0, 1.2, ridge=0.2, ridge_off=(-2.4, 0), clip="uniform")
        f.crease([(hip[0] - sg * 9, hip[1] + 30), (knee[0] - sg * 9, knee[1] - 12)], 0.26, 2.0, 1.2, ridge=0.2,
                 ridge_off=(-2.4, 0), clip="uniform")
        f.crease([(knee[0] - 6, knee[1] + 6), (knee[0] + 6, knee[1] + 5)], 0.3, 1.4, 0.6, clip="nskin")
        f.paint(f.ellipse((knee[0] - 1, knee[1] - 3), 4.5, 4.0), 0.22, 0.6, clip="nskin")
        f.crease([lerp(knee, ank, 0.5), (ank[0] - 1, ank[1] - 6)], -0.2, 1.4, 0.8, clip="nskin")
        for k, dx in enumerate((-10, -5, 0, 5, 10)):
            x = ank[0] + dx + sg * 5
            f.crease([(x, ank[1] + 14), (x + sg * 0.6, ank[1] + 27)], 0.32 if k % 2 else 0.24, 1.0, 0.4, clip="nskin")
            f.fill(f.shape([(x - 1.9, ank[1] + 23), (x + 1.9, ank[1] + 23), (x + 1.6, ank[1] + 28), (x - 1.6, ank[1] + 28)]),
                   "nail", 0.35, inside=True)
        for dx in (-4, 3):
            f.crease([(ank[0] + dx, ank[1] + 2), (ank[0] + dx * 1.9 + sg * 3, ank[1] + 16)], -0.2, 1.2, 0.6, clip="nskin")
        f.veins((lerp(knee, ank, 0.55)[0] + 2, lerp(knee, ank, 0.55)[1]), 14, 120 + sg, math.pi / 2 + 0.2, depth=0.2,
                mat="vein", width=0.9)
        f.stain((ank[0], ank[1] + 22), 10, "nbruise", 122 + sg, val=0.3, stretch=(1.4, 0.6), ring=0.0, clip="nskin")
    # brazos: músculo, codo huesudo, tendones, venas; carne fundida con el metal
    for side in ("r", "l"):
        if side == "r" and arm_r is None:
            continue
        sh, el, wr = p["sh_" + side], p["el_" + side], p["wr_" + side]
        ar = f.shape(limb_outline([sh, el, wr], [(14, 13), (11, 11), (13, 13)]))
        f.mass(ar > 0.5, soft=5.0, hard=0.3, fill=0.06, edge=0.08, clip="nskin")
        d = lerp(sh, el, 0.3)
        f.crease([(d[0] - 12, d[1] - 2), (d[0] + 2, d[1] + 8)], 0.28, 1.6, 0.8, ridge=0.2, ridge_off=(0, -2.6), clip="nskin")
        f.crease([lerp(sh, el, 0.4), lerp(sh, el, 0.88)], 0.22, 1.8, 1.0, ridge=0.18, ridge_off=(-2.4, 0), clip="nskin")
        f.paint(f.ellipse(el, 6.0, 7.0), 0.24, 0.8, clip="nskin")
        for kk in (3, 8):
            f.crease([(el[0] - 6, el[1] + kk), (el[0] + 6, el[1] + kk - 1)], 0.28, 1.0, 0.5, clip="nskin")
        fu = _u(el, wr)
        fn = (fu[1], -fu[0])
        a = lerp(el, wr, 0.3)
        for o in (-4, 3):
            f.crease([(a[0] + fn[0] * o, a[1] + fn[1] * o), (wr[0] + fn[0] * o * 0.6, wr[1] + fn[1] * o * 0.6)], -0.2 if o < 0 else 0.18,
                     1.4, 0.8, clip="nskin")
        f.veins(lerp(sh, el, 0.45), 16, 130 + len(side), math.atan2(el[1] - sh[1], el[0] - sh[0]), depth=0.22, mat="vein")
        f.veins(lerp(el, wr, 0.2), 16, 133 + len(side), math.atan2(wr[1] - el[1], wr[0] - el[0]), depth=0.22, mat="vein")
        f.stain(lerp(sh, el, 0.7), 6, "nbruise", 136 + len(side), val=0.3, stretch=(1.0, 1.4), ring=0.0, clip="nskin")
    if arm_r is not None:
        sh, el, wr, blades, saw, clamps, (ux, uy, nx, ny, out) = arm_r
        f.mass(f.of("flesh"), soft=4.0, hard=0.3, fill=0.06, edge=0.1, clip="flesh")
        f.noise(0.16, 2.5, 140, clip="flesh")
        f.gloss(((f.of("flesh")) & (np.random.default_rng(141).random(f.mask.shape) < 0.03)).astype(np.float32), 0.5, 0.4)
        f.mass(f.of("metal"), soft=2.0, hard=0.24, fill=0.04, edge=0.08, clip="metal")
        for base, tip, belly, spine, d, bn, cv in blades:
            f.crease([lerp(base, tip, 0.15), lerp(base, tip, 0.85)], -0.42, 0.8, 0.3, clip="metal")      # reflejo
            f.crease([base, belly, tip], -0.36, 0.8, 0.2, clip="metal")                                   # filo
            f.stain(lerp(base, tip, 0.86), 4.6, "blood", int(tip[0]), val=0.42, stretch=(0.6, 1.8), ring=0.1, clip="metal",
                    wet=0.4)
        f.crease([saw[0], saw[1]], -0.45, 1.0, 0.3, clip="metal")
        for t, r in ((0.3, 6), (0.6, 8), (0.82, 5)):
            c = lerp(lerp(saw[0], saw[1], t), lerp(saw[3], saw[2], t), 0.5)
            f.stain(c, r, "rust", int(t * 100), val=0.4, ring=0.1, clip="metal")
        f.stain(lerp(lerp(saw[0], saw[1], 0.9), lerp(saw[3], saw[2], 0.9), 0.4), 7, "blood", 142, val=0.42, ring=0.1,
                clip="metal", wet=0.3)
        for cm in clamps:                                                                         # abrazaderas
            f.mass(cm > 0.5, soft=1.6, hard=0.3, fill=0.1, edge=0.1, clip="metal")
        for t in (0.42, 0.78):
            q = lerp(el, wr, t)
            for o in (-12, 12):
                f.paint(f.ellipse((q[0] + nx * o, q[1] + ny * o), 1.8, 1.8), 0.5, 0.2, clip="metal")
            for o in (-1, 1):                                                                     # carne que rebosa
                f.crease([(q[0] + nx * 15 + ux * o * 6, q[1] + ny * 15 + uy * o * 6),
                          (q[0] - nx * 15 + ux * o * 6, q[1] - ny * 15 + uy * o * 6)], 0.3, 1.6, 0.8, clip="nskin")
        seam = [lerp(el, wr, 0.25), lerp(el, wr, 0.96)]
        seam = [(q[0] + out[0] * 9, q[1] + out[1] * 9) for q in seam]
        f.stain(lerp(*seam, 0.5), 9, "flesh", 143, val=0.38, stretch=(0.7, 4.2), ring=0.12)
        sl = math.hypot(seam[1][0] - seam[0][0], seam[1][1] - seam[0][1])
        for i in range(int(sl / 9)):
            q = lerp(*seam, (i + 0.5) * 9 / sl)
            st_ = f.stroke([(q[0] - out[0] * 5, q[1] - out[1] * 5), (q[0] + out[0] * 5, q[1] + out[1] * 5)], 1.6)
            f.fill(st_, "metal", 0.75, inside=True)
    # mano de la jeringa: nudillos, pliegues, cristal, líquido, graduación
    for k0, k1, k2 in fingers:
        f.paint(f.ellipse(k0, 2.2, 2.2), 0.24, 0.3, clip="nskin")
        f.paint(f.ellipse(k1, 2.0, 2.0), 0.2, 0.3, clip="nskin")
        f.crease([(k0[0], k0[1] + 4), (k1[0], k1[1] + 4), (k2[0], k2[1] + 3)], 0.34, 1.0, 0.4, clip="nskin")
    f.mass(f.of("glass", "liquid"), soft=3.0, hard=0.2, fill=0.08, edge=0.1)
    f.crease([(sx - 6, top + 3), (sx - 6, bot - 6)], -0.6, 1.0, 0.3, clip=["glass", "liquid"])
    f.crease([(sx - 3.6, top + 3), (sx - 3.6, bot - 36)], -0.3, 0.6, 0.3, clip=["glass", "liquid"])
    f.crease([(sx + 7.6, top + 4), (sx + 7.6, bot - 4)], 0.25, 0.6, 0.3, clip=["glass", "liquid"])
    f.crease([(sx - 9, top + 30), (sx + 9, top + 30)], -0.5, 0.8, 0.2, clip=["glass", "liquid"])
    for i, y in enumerate(range(int(top) + 16, int(bot) - 8, 9)):
        f.fill(f.stroke([(sx + 1.5, y), (sx + (8.5 if i % 2 else 5.5), y)], 0.9), "porcelain", 0.75, inside=True)
    for bx, by in ((sx - 2, top + 54), (sx + 3, top + 70), (sx - 1, top + 92)):
        f.paint(f.ellipse((bx, by), 1.4, 1.4), 0.5, 0.2, clip="liquid")
    
    # cuello estirado: tendones tensos bajo la joroba
    f.crease([(x + 3, y) for x, y in neck], 0.22, 1.4, 1.0, clip="nskin")
    # sombra de la cabeza colgante sobre el pecho
    f.crease(skull + skull[:1], 0.0, 1.0, 0.1)
    hm = f.shape(skull)
    from scipy import ndimage as _nd
    ring_ = _nd.gaussian_filter(hm, 3 * K) - hm
    m_ = f.of("uniform", "nskin", "dry", "blood") & (f.part != 1)
    f.val[m_] -= 0.9 * np.clip(ring_[m_], 0, 1)
    # cabeza: volumen, porcelana con brillo y grietas, ojo vivo, mascarilla cosida tirando de la piel
    f.mass(f.shape(skull) > 0.5, soft=8.0, hard=0.28, fill=0.06, edge=0.12, clip=["nskin"])
    f.mass(f.of("porcelain"), soft=5.0, hard=0.3, fill=0.1, edge=0.1, clip="porcelain")
    f.crease(R([(-1, -18), (0, -4), (1, 8)]), -0.3, 1.6, 0.8, clip="porcelain")
    f.crease(R([(-20, -16), (-10, -19.5)]), -0.24, 1.6, 0.6, ridge=0.2, ridge_off=(0, 3), clip="porcelain")
    f.crease(R([(10, -19.5), (20, -16)]), -0.24, 1.6, 0.6, ridge=0.2, ridge_off=(0, 3), clip="porcelain")
    f.gloss(f.shape(R([(-18, -20), (-8, -22.5), (-10, -19.5), (-17, -18)])), 0.6, 0.4)
    f.gloss(f.shape(R([(-3, -22), (-1, -22), (-1.2, -10), (-2.6, -10)])), 0.4, 0.4)
    rnd = random.Random(7)
    for st0, n, ang in ((R([(-6, -5)])[0], 9, 1.9), (R([(-2, -24)])[0], 6, 1.8), (R([(16, -20)])[0], 6, 2.5),
                        (R([(14, 6)])[0], 5, 0.5)):
        x, y = st0
        pts = [(x, y)]
        for _ in range(n):
            ang += rnd.uniform(-0.6, 0.6)
            s_ = rnd.uniform(2.6, 4.6)
            x, y = x + math.cos(ang) * s_, y + math.sin(ang) * s_
            pts.append((x, y))
        f.crease(pts, 0.7, 0.6, 0.15, ridge=0.3, ridge_off=(0.8, 0.8), clip="porcelain", tension=0.3)
    f.mass(f.of("eye"), soft=2.0, hard=0.2, fill=0.1, edge=0.3, clip="eye")
    ec = R([(9.4, -9.6)])[0]
    f.paint(f.ellipse(ec, 2.2, 2.2), -0.8, 0.2, clip="eye")
    f.paint(f.ellipse((ec[0] + 3.4, ec[1] + 0.6), 1.2, 0.8), -0.2, 0.3, clip="eye")
    f.mass(f.of("mask_cloth"), soft=5.0, hard=0.26, fill=0.08, edge=0.12, clip="mask_cloth")
    for y in (14, 20, 26):
        f.crease(R([(-18, y - 2), (0, y + 2), (18, y - 2)]), 0.32, 1.4, 0.8, ridge=0.24, ridge_off=(0, -2.4), clip="mask_cloth")
    f.weave(0.05, 0.5, clip="mask_cloth")
    f.stain(R([(0, 22)])[0], 9, "blood", 150, val=0.4, stretch=(1.2, 1.0), ring=0.08, clip="mask_cloth", wet=0.35)
    f.stain(R([(1, 34)])[0], 3.4, "blood", 151, val=0.42, stretch=(0.6, 3.0), ring=0.1, drip=2.5, wet=0.3)
    stitches = R([(-22, 6), (-21, 16), (-16, 26), (-8, 32.5), (0, 35), (8, 32.5), (16, 26), (21, 16), (22, 6)])
    for q0, q1 in zip(stitches, stitches[1:]):
        q = lerp(q0, q1, 0.5)
        dn = _u(q0, q1)
        nn = (-dn[1], dn[0])
        f.fill(f.stroke([(q[0] - nn[0] * 3.4, q[1] - nn[1] * 3.4), (q[0] + nn[0] * 3.4, q[1] + nn[1] * 3.4)], 1.4), "thread", 0.3)
        for o in (-1, 1):                                                        # la piel fruncida por el hilo
            f.crease([(q[0] + nn[0] * 3.4 * o, q[1] + nn[1] * 3.4 * o),
                      (q[0] + nn[0] * 7 * o + dn[0] * 2, q[1] + nn[1] * 7 * o + dn[1] * 2)], 0.3, 0.8, 0.4, clip="nskin")
    for sd in (-1, 1):
        f.fill(f.stroke(R([(sd * 25, -12), (sd * 31, -11)]), 2.0), "thread", 0.35)
    f.veins(R([(-16, -34)])[0], 12, 152, 2.0, depth=0.24, mat="vein")
    f.veins(R([(12, -36)])[0], 10, 153, 1.2, depth=0.24, mat="vein")
    for k in range(3):                                                           # pelo ralo y pegado
        a0 = R([(-12 + k * 9, -38)])[0]
        a1 = R([(-17 + k * 10, -24)])[0]
        f.fill(f.stroke([a0, (lerp(a0, a1, 0.5)[0] - 2, lerp(a0, a1, 0.5)[1]), a1], 1.0, taper=True), "nail", 0.35)
    # tubos: brillo, líquido oscuro y la piel fruncida donde entran
    for path in tubes:
        f.crease([(x - 1.2, y - 1.2) for x, y in path[:-1]], -0.6, 0.8, 0.2, clip="liquid")
        f.crease([(x + 1.6, y + 1.6) for x, y in path[:-1]], 0.3, 0.8, 0.2, clip="liquid")
        ex, ey = path[-1]
        f.paint(f.ellipse((ex, ey), 4.0, 3.2), -0.25, 0.8)                            # piel fruncida
        f.crease([(ex - 5, ey - 2), (ex - 2, ey)], 0.2, 0.6, 0.3)
        f.crease([(ex + 5, ey - 1), (ex + 2, ey + 1)], 0.2, 0.6, 0.3)
        f.fill(f.stroke([(ex, ey + 5), (ex - 1, ey + 18)], 2.0, taper=True), "blood", 0.42)
    # textura de la piel gris: moteado, poros, venas, cardenales
    f.noise(0.14, 10.0, 160, clip="nskin")
    f.noise(0.06, 2.5, 161, clip="nskin")
    f.pores(0.1, 0.6, 0.1, 162, clip="nskin")
    # luz: contraluz granate por la derecha y la espalda; sombra hacia los pies
    f.rim((96, 14, 22), (0.9, -0.25), 3.2, 1.0)
    f.rim((40, 52, 70), (-0.9, -0.3), 1.6, 0.6)
    f.paint(f.poly([(0, 470), (W, 470), (W, H), (0, H)]), -0.14, 8.0)

    def touch(outimg: np.ndarray) -> None:
        # brillo húmedo del ojo y pupila a escala 1
        x, y = int(ec[0]), int(ec[1])
        outimg[y, x, :3] = (6, 4, 6)
        outimg[y - 1, x - 1, :3] = (250, 246, 232)
    f.touch(touch)
    return f


def frames() -> dict[str, Image.Image]:
    out = {}
    for name, p, miss in (("idle_0", pose_idle(0), ()), ("idle_1", pose_idle(3), ()), ("attack", pose_attack(), ()),
                          ("stump", pose_idle(0), ("arm_r",))):
        out[name] = draw(p, miss).render(pal.NURSE, dither=9.0)
    return out


def parts() -> list[Image.Image]:
    f = draw(pose_idle(0))
    img = f.render(pal.NURSE, dither=9.0)
    return f.split(img, 6)


if __name__ == "__main__":
    from paint import row
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n/v3_nurse.png"
    which = sys.argv[2] if len(sys.argv) > 2 else "idle"
    if which == "idle":
        f = draw(pose_idle(0))
        row([f.render(pal.NURSE, dither=9.0), f.silhouette()], bg=(12, 11, 14)).save(out)
    else:
        fr = frames()
        row([fr["idle_0"], fr["idle_1"], fr["attack"], fr["stump"]], bg=(12, 11, 14)).save(out)
