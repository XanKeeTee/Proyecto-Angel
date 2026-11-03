"""El enfermero transfigurado, quinta muestra: tinta y pinceladas, buscando el realismo de Fear & Hunger.

300×440 en combate (dibujado en una rejilla de diseño de 520×640 a ×4). Anatomía con perfiles medidos
(deltoides, bíceps y tríceps, codo, braquiorradial, muñeca; rodilla, tibia, gemelos), contornos orgánicos
con trazo nervioso, sombreado a pinceladas que siguen el músculo o el pliegue, luz lateral fría con el
lado oscuro casi negro, filo granate a contraluz y micro-detalle: venas, cardenales, vello, costuras, puntos
que tiran de la piel, craquelado de la porcelana, arañazos y óxido, menisco del líquido.
"""

from __future__ import annotations

import math
import os
import random
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import palette_fh as pal  # noqa: E402
from brush import Canvas, lerp, limb_pts, polyline_interp, rcol  # noqa: E402

W, H = 300, 440
K = 4
VIEW = (0.72, 40, 60)
INK = (26, 17, 16)


def axis(pts):
    """Campo de dirección: el ángulo del tramo más cercano de una polilínea (para pinceladas que
    siguen el miembro)."""
    segs = list(zip(pts, pts[1:]))

    def f(x, y):
        best, ang = 1e9, 0.0
        for a, b in segs:
            dx, dy = b[0] - a[0], b[1] - a[1]
            l2 = dx * dx + dy * dy or 1
            t = max(0, min(1, ((x - a[0]) * dx + (y - a[1]) * dy) / l2))
            d = (x - a[0] - dx * t) ** 2 + (y - a[1] - dy * t) ** 2
            if d < best:
                best, ang = d, math.atan2(dy, dx)
        return ang
    return f


def spot(c: Canvas, top: float = 80, bot: float = 640, a: float = 0.1, b: float = -0.28) -> np.ndarray:
    """El foco del combate: más luz arriba, más sombra hacia los pies (en el campo de valor)."""
    yy = np.arange(c.H, dtype=np.float32)[:, None] / c.s + c.view[2]
    t = np.clip((yy - top) / (bot - top), 0, 1)
    return np.broadcast_to(a + (b - a) * t, (c.H, c.W)).astype(np.float32)


ARM_OUT = [21, 23, 20, 15, 12.5, 11.0, 12.5, 15.5, 16.0, 14.0, 12.0, 10.0, 8.8, 8.6]
ARM_IN = [18, 16, 15, 14.0, 12.5, 11.0, 12.0, 13.5, 13.5, 11.5, 10.0, 9.0, 8.2, 8.0]


def arm(c: Canvas, sh, el, wr, seed: int, fused: bool = False):
    path = [sh, el, wr]
    st = polyline_interp(path, 14)
    out_ = ARM_OUT if not fused else ARM_OUT[:9] + [17, 18, 19, 18.5, 18]
    in_ = ARM_IN if not fused else ARM_IN[:9] + [16, 17, 18, 18, 18]
    pts = limb_pts(st, out_, in_)
    q, m = c.paint(pts, "nskin", axis(path), seed, soft=8, base=0.5, contrast=1.7, length=6, width=1.6, density=0.75,
                   extra=spot(c))
    # grupos musculares: separación del deltoides, surco bíceps/tríceps, codo huesudo, braquiorradial
    d0 = lerp(sh, el, 0.28)
    d1 = lerp(sh, el, 0.42)
    with c.clip(pts):
        c.ink([(d0[0] - 18, d0[1] - 6), (d0[0] - 4, d0[1] + 2), d1], 1.1, 0.4, rcol("nskin", 0.1), seed=seed + 1)
        c.ink([lerp(sh, el, 0.45), lerp(sh, el, 0.9)], 1.0, 0.5, rcol("nskin", 0.15), seed=seed + 2)
        c.scumble([lerp(sh, el, 0.35), (lerp(sh, el, 0.5)[0] - 8, lerp(sh, el, 0.5)[1]), lerp(sh, el, 0.75),
                   (lerp(sh, el, 0.55)[0] - 3, lerp(sh, el, 0.55)[1] + 2)], "nskin", 0.82, axis(path), seed + 3,
                  length=5, width=1.2, density=0.5)
        ex, ey = el
        c.fill([(ex - 9, ey - 6), (ex - 2, ey - 12), (ex + 8, ey - 8), (ex + 9, ey + 2), (ex + 1, ey + 6), (ex - 7, ey + 3)],
               rcol("nskin", 0.78), wob=0.6, seed=seed + 4)
        c.glint([(ex - 4, ey - 9), (ex + 4, ey - 8)], rcol("nskin", 1.0), 0.9)
        for kk in (5, 10):
            c.ink([(ex - 9, ey + kk), (ex - 1, ey + kk + 2), (ex + 8, ey + kk - 1)], 0.8, 0.3, rcol("nskin", 0.05), seed=seed + kk)
        br = lerp(el, wr, 0.25)
        c.scumble([(br[0] - 10, br[1] - 14), (br[0] + 4, br[1] - 16), (br[0] + 6, br[1] + 18), (br[0] - 8, br[1] + 16)], "nskin",
                  0.74, axis(path), seed + 5, length=5, width=1.2, density=0.45)
        c.ink([lerp(el, wr, 0.3), lerp(el, wr, 0.92)], 0.8, 0.3, rcol("nskin", 0.15), seed=seed + 6)              # tendón
        # venas que se ramifican, cardenales con halo, vello ralo
        rnd = random.Random(seed)
        for v0, v1 in ((0.35, 0.8), (0.1, 0.55)):
            seg = [lerp(sh, el, v0)] + [lerp(lerp(sh, el, v1), lerp(el, wr, 0.4), rnd.random())] + [lerp(el, wr, 0.7)]
            seg = [(x + rnd.uniform(-5, 5), y) for x, y in seg]
            c.ink(seg, 1.1, 0.5, rcol("vein", 0.5), seed=seed + 9, wob=1.2)
        bp = lerp(sh, el, 0.62)
        c.fill([(bp[0] - 9, bp[1] - 7), (bp[0] + 7, bp[1] - 8), (bp[0] + 9, bp[1] + 7), (bp[0] - 6, bp[1] + 9)],
               rcol("nskin", 0.35), wob=1.5, seed=seed + 10, a=0.8)
        c.fill([(bp[0] - 5, bp[1] - 3), (bp[0] + 4, bp[1] - 4), (bp[0] + 4, bp[1] + 4), (bp[0] - 3, bp[1] + 4)],
               (62, 44, 70), wob=1.0, seed=seed + 11, a=0.85)
        for _ in range(26):
            p = lerp(el, wr, rnd.uniform(0.1, 0.8))
            p = (p[0] + rnd.uniform(-9, 9), p[1] + rnd.uniform(-4, 4))
            a = math.atan2(wr[1] - el[1], wr[0] - el[0]) + rnd.uniform(-0.4, 0.4)
            c.ink([p, (p[0] + math.cos(a) * 3, p[1] + math.sin(a) * 3)], 0.35, 0.2, rcol("nskin", 0.1), smooth=False, wob=0)
    # filo granate a contraluz y contorno
    with c.clip(pts):
        c.ink([(x + 2.4, y) for x, y in st[2:-1]], 2.2, 1.0, rcol("rim", 0.5), wob=0.6, seed=seed + 12)
    c.outline(q, 1.42, INK, seed)
    return q, st


def draw() -> Canvas:
    c = Canvas(W, H, K, VIEW)
    rnd = random.Random(2)
    sp = spot(c)
    # ===================================== piernas =====================================
    for side, hip, knee, ank, seed in ((-1, (226, 408), (202, 524), (214, 612), 10), (1, (300, 406), (328, 526), (312, 612), 20)):
        # espinilla gris: tibia afilada delante, gemelo detrás
        st = polyline_interp([knee, ank], 8)
        shin = limb_pts(st, [13, 14, 13, 11, 9.5, 8, 7.4, 7.6], [13, 15, 15.5, 13, 10, 8.4, 7.6, 7.8])
        q, _ = c.paint(shin, "nskin", axis([knee, ank]), seed, soft=6, base=0.42, contrast=1.7, length=5, width=1.4,
                       density=0.75, extra=sp)
        with c.clip(shin):
            c.ink([lerp(knee, ank, 0.45), (ank[0] - 2, ank[1] - 10)], 0.9, 0.4, rcol("nskin", 0.85), seed=seed)
            c.ink([lerp(knee, ank, 0.55), lerp(knee, ank, 0.95)], 1.2, 0.4, rcol("vein", 0.5), seed=seed + 1, wob=1.4)
        c.outline(q, 1.35, INK, seed)
        # pie largo y huesudo: tendones del empeine, dedos separados, uñas negras, mugre
        fx, fy = ank
        foot = [(fx - 10, fy - 4), (fx - 3, fy - 6), (fx + 8, fy - 4), (fx + 14 + side * 6, fy + 12), (fx + 18 + side * 7, fy + 22),
                (fx + 16 + side * 7, fy + 28), (fx + side * 6, fy + 29), (fx - 16 + side * 6, fy + 28), (fx - 18 + side * 5, fy + 20),
                (fx - 15 + side * 4, fy + 10)]
        q, _ = c.paint(foot, "nskin", -1.4, seed + 2, soft=5, base=0.4, contrast=1.6, length=4, width=1.2, density=0.8, extra=sp)
        with c.clip(foot):
            for k in range(5):
                x = fx - 13 + k * 6.6 + side * 6
                c.ink([(x, fy + 12), (x + side * 0.6, fy + 28)], 1.0, 0.6, INK, seed=seed + k)
                c.fill([(x + 1, fy + 23), (x + 5, fy + 23), (x + 4.6, fy + 28), (x + 1.2, fy + 28)], rcol("nail", 0.2), smooth=False)
            for dx in (-5, 4):
                c.ink([(fx + dx, fy), (fx + dx * 1.8 + side * 3, fy + 15)], 1.0, 0.4, rcol("nskin", 0.9), seed=seed + 7)
            c.fill([(fx - 18, fy + 22), (fx + 20, fy + 22), (fx + 20, fy + 30), (fx - 18, fy + 30)], rcol("dry", 0.2), wob=2, seed=seed, a=0.7)
        c.outline(q, 1.27, INK, seed + 3)
        # pantalón ancho, roto en jirones a media espinilla
        hem = lerp(knee, ank, 0.45)
        st = polyline_interp([hip, knee, hem], 10)
        trou = limb_pts(st, [28, 28, 26, 24, 22, 21, 20, 19.5, 19, 19], [27, 27, 25, 23, 21, 20, 19.5, 19, 19, 19])
        L = trou[:10]
        R = trou[10:]
        rag = []
        for k in range(1, 12):
            p = lerp(L[-1], R[0], k / 12)
            rag.append((p[0], p[1] + (rnd.uniform(7, 20) if k % 2 else rnd.uniform(-2, 5))))
        trou = L + rag + R
        q, m = c.paint(trou, "uniform", -1.57, seed + 4, soft=10, base=0.5, contrast=1.6, length=7, width=1.6, density=0.7,
                       extra=sp)
        with c.clip(trou):
            kx, ky = knee
            for pts_, v in (([(hip[0] - side * 8, hip[1] + 18), (kx - side * 10, ky - 38), (kx - side * 3, ky - 16)], 0.18),
                            ([(hip[0] + side * 14, hip[1] + 26), (kx + side * 12, ky - 22), (kx + side * 6, ky - 10)], 0.2),
                            ([(kx - 10, ky + 14), (hem[0] - 6, hem[1] - 6)], 0.22), ([(kx + 9, ky + 14), (hem[0] + 9, hem[1] - 2)], 0.22)):
                side_off = [(x + 4, y) for x, y in pts_]
                c.scumble(pts_ + side_off[::-1], "uniform", v, -1.57, seed + 5, length=5, width=1.3, density=0.9, smooth=False)
                c.ink(pts_, 1.4, 0.4, INK, seed=seed + 6)
                c.ink([(x - 2, y) for x, y in pts_], 0.9, 0.3, rcol("uniform", 0.95), seed=seed + 7)
            # rodilla rota: la rótula gris asoma
            tear = [(kx - 12, ky - 6), (kx - 4, ky - 14), (kx + 6, ky - 10), (kx + 13, ky - 1), (kx + 8, ky + 10), (kx - 4, ky + 12),
                    (kx - 13, ky + 4)]
            qt, _ = c.paint(tear, "nskin", -1.0, seed + 8, soft=5, base=0.55, contrast=1.8, length=4, width=1.2, density=0.9, wob=1.5)
            c.fill([(kx - 6, ky - 7), (kx + 2, ky - 10), (kx + 6, ky - 3), (kx + 1, ky + 3), (kx - 5, ky + 1)], rcol("nskin", 0.85),
                   wob=0.8, seed=seed)
            c.outline(qt, 0.9, INK, seed + 9)
            for k in range(0, len(qt), 4):
                p = qt[k]
                c.ink([p, (p[0] + rnd.uniform(-3, 3), p[1] + rnd.uniform(2, 7))], 0.7, 0.3, rcol("uniform", 0.7), smooth=False, wob=0)
            c.blood((hip[0] - side * 2, hip[1] + 62), 12, seed + 10, "dry", drips=3, down=1.6, wet=False)
            c.fill([(hem[0] - 22, hem[1] - 10), (hem[0] + 22, hem[1] - 14), (hem[0] + 24, hem[1] + 22), (hem[0] - 24, hem[1] + 22)],
                   rcol("dirt", 0.5) if False else rcol("uniform", 0.2), wob=3, seed=seed, a=0.55)
            c.ink([(hip[0] + side * 25, hip[1] + 12), (kx + side * 18, ky - 4)], 0.7, 0.7, rcol("uniform", 0.15), seed=seed + 11)
        c.outline(q, 1.5, INK, seed + 12)
    # ===================================== tronco y túnica =====================================
    tunic = [(196, 138), (210, 120), (224, 104), (240, 88), (258, 76), (274, 72), (290, 76), (304, 88), (318, 104), (334, 118),
             (352, 128), (368, 140), (374, 158), (368, 186), (356, 226), (346, 270), (340, 312), (343, 352), (350, 392),
             (356, 428), (344, 422), (334, 438), (322, 424), (308, 442), (294, 426), (280, 444), (266, 428), (252, 442),
             (238, 426), (224, 440), (210, 424), (196, 436), (184, 420), (190, 388), (196, 352), (194, 316), (186, 278),
             (172, 238), (160, 196), (151, 166), (158, 148), (176, 142)]
    drape = axis([(270, 80), (262, 200), (264, 440)])
    q_tunic, mt = c.paint(tunic, "uniform", lambda x, y: drape(x, y) + (0.35 if x > 290 else -0.25 if x < 220 else 0), 30,
                          soft=26, base=0.52, contrast=1.8, length=8, width=1.8, density=0.75, extra=sp, wob=1.0)
    with c.clip(tunic, wob=1.0, seed=30):
        # sombra grande del costado derecho, casi negra en el borde, y bajo el pecho
        c.scumble([(330, 110), (380, 120), (380, 440), (330, 440), (318, 300), (322, 200)], "uniform", 0.12, -1.57, 31,
                  length=8, width=1.6, density=0.9)
        c.scumble([(352, 150), (380, 150), (380, 440), (346, 440), (342, 300)], "uniform", 0.03, -1.57, 32, length=8, width=1.6,
                  density=1.0)
        c.scumble([(184, 392), (352, 392), (358, 440), (182, 440)], "uniform", 0.25, -1.57, 33, length=7, width=1.5, density=0.8)
        # joroba: vértebras que se marcan bajo la tela tirante
        for i, (x, y) in enumerate(((262, 84), (270, 96), (277, 108), (282, 120))):
            c.fill([(x - 8, y + 1), (x - 1, y - 4), (x + 7, y - 1), (x + 7, y + 5), (x - 1, y + 7)], rcol("uniform", 0.85), wob=0.6, seed=i)
            c.ink([(x - 8, y + 4), (x, y + 8), (x + 8, y + 5)], 1.1, 0.4, INK, seed=40 + i)
        # pliegues de peso: líneas con su sombra pintada a un lado y su filo claro al otro
        folds = [[(178, 160), (190, 210), (196, 262), (204, 304)], [(350, 162), (334, 214), (326, 264)],
                 [(226, 150), (232, 196), (226, 238)], [(200, 322), (214, 364), (212, 412)], [(318, 328), (312, 372), (318, 420)],
                 [(246, 338), (252, 382), (248, 426)], [(282, 342), (288, 386), (284, 428)], [(214, 302), (236, 314), (262, 308)],
                 [(290, 306), (310, 318), (326, 310)], [(172, 252), (182, 300), (190, 342)], [(232, 98), (250, 92), (266, 110)],
                 [(300, 88), (312, 106), (318, 132)]]
        for k, f in enumerate(folds):
            sh_ = [(x + 6, y + 1) for x, y in f]
            c.scumble(f + sh_[::-1], "uniform", 0.22, drape, 50 + k, length=5, width=1.3, density=1.0, smooth=False)
            c.ink(f, 1.5, 0.4, INK, seed=60 + k)
            c.ink([(x - 2.2, y) for x, y in f], 1.0, 0.3, rcol("uniform", 1.0), seed=70 + k)
        # costuras con puntadas
        for k, seam in enumerate(([(190, 154), (178, 196), (188, 252)], [(354, 150), (346, 200), (336, 260)], [(196, 340), (346, 340)])):
            c.ink(seam, 0.9, 0.9, rcol("uniform", 0.2), seed=80 + k)
            for a, b in zip(seam, seam[1:]):
                for t in range(1, 9):
                    p = lerp(a, b, t / 9)
                    c.ink([(p[0] - 1.6, p[1] - 1), (p[0] + 1.6, p[1] + 1)], 0.9, 0.9, INK, smooth=False, wob=0)
        # trama de la tela y mugre
        for _ in range(500):
            x, y = rnd.uniform(150, 375), rnd.uniform(75, 445)
            c.ink([(x, y), (x + rnd.uniform(-0.6, 0.6), y + rnd.uniform(2, 5))], 0.4, 0.3, rcol("uniform", rnd.uniform(0.25, 0.5)),
                  smooth=False, wob=0, a=0.6)
        # desgarro del pecho: esternón, costillas, piel tirante y venas
        rip = [(262, 152), (270, 146), (277, 150), (286, 146), (292, 158), (300, 158), (304, 170), (310, 178), (316, 190),
               (312, 202), (310, 214), (318, 226), (314, 240), (306, 254), (302, 266), (298, 278), (288, 270), (278, 276),
               (270, 280), (266, 268), (258, 258), (250, 246), (254, 234), (256, 222), (248, 212), (246, 200), (254, 190),
               (256, 178), (250, 168)]
        qr, mr = c.paint(rip, "nskin", -0.2, 90, soft=12, base=0.5, contrast=1.7, length=5, width=1.3, density=0.8, wob=0.8)
        with c.clip(rip, wob=0.8, seed=90):
            c.scumble([(286, 140), (330, 140), (330, 290), (290, 290)], "nskin", 0.18, -0.2, 91, length=5, width=1.3, density=0.9)
            c.ink([(282, 158), (280, 200), (281, 240), (279, 272)], 1.8, 1.0, INK, seed=92)                           # esternón
            c.ink([(277, 160), (275, 200), (276, 240)], 1.2, 0.5, rcol("nskin", 0.95), seed=93)
            for i, y in enumerate(range(168, 270, 12)):
                for sd in (-1, 1):
                    x0 = 280 + sd * 4
                    rib = [(x0, y), (x0 + sd * 12, y + 3), (x0 + sd * 28, y + 1)]
                    c.scumble([(x0, y - 4), (x0 + sd * 12, y - 1), (x0 + sd * 28, y - 3), (x0 + sd * 28, y + 1), (x0 + sd * 12, y + 3),
                               (x0, y)], "nskin", 0.85 if sd < 0 else 0.6, 0.0, 95 + i, length=3, width=1.0, density=1.2, smooth=False)
                    c.ink(rib, 1.5, 0.5, INK, seed=100 + i * 2 + sd)
                    c.scumble([(x0, y + 1), (x0 + sd * 12, y + 4), (x0 + sd * 26, y + 3), (x0 + sd * 12, y + 8)], "nskin", 0.05, 0.0,
                              110 + i, length=3, width=1.0, density=1.2, smooth=False)
            for v in ([(262, 190), (258, 210), (264, 228), (260, 246)], [(296, 220), (300, 240), (296, 258)]):
                c.ink(v, 1.2, 0.5, rcol("vein", 0.6), seed=120, wob=1.0)
        c.outline(qr, 1.05, INK, 91)
        for k in range(0, len(qr), 5):
            p = qr[k]
            c.ink([p, (p[0] + rnd.uniform(-4, 4), p[1] + rnd.uniform(3, 9))], 0.8, 0.3, rcol("uniform", 0.8), smooth=False, wob=0)
        # bolsillo y tarjeta (foto oscura, texto ilegible, la pinza)
        pocket = [(310, 288), (334, 284), (336, 314), (312, 318)]
        c.fill(pocket, rcol("uniform", 0.32), smooth=False)
        c.ink([(310, 288), (334, 284)], 1.2, 1.2, INK, smooth=False, wob=0)
        card = [(314, 274), (330, 272), (332, 298), (316, 300)]
        c.fill(card, rcol("porcelain", 0.7), smooth=False)
        c.fill([(316, 277), (322, 277), (322, 286), (316, 286)], rcol("liquid", 0.5), smooth=False)
        for y in (280, 283, 289, 292, 295):
            c.ink([(324 if y < 287 else 317, y), (330, y)], 0.6, 0.6, rcol("porcelain", 0.2), smooth=False, wob=0)
        c.ink([(322, 266), (322, 274)], 1.4, 1.4, rcol("metal", 0.7), smooth=False, wob=0)
        # sangre que empapa el vientre: seca y oscura, con la fresca encima y regueros por los pliegues
        c.blood((276, 318), 24, 130, "dry", drips=4, down=2.2, wet=False)
        c.blood((272, 312), 12, 131, "blood", drips=3, down=2.5)
        c.blood((210, 212), 8, 132, "dry", drips=2, down=2.0, wet=False)
        c.blood((330, 398), 10, 133, "dry", drips=1, wet=False)
        # filo granate a contraluz por la derecha
        c.ink([(371, 150), (360, 210), (348, 270), (343, 340), (352, 400)], 3.0, 1.6, rcol("rim", 0.6), seed=135)
    c.outline(q_tunic, 1.65, INK, 30)
    # ===================================== brazo de la jeringa =====================================
    sh, el, wr = (356, 146), (410, 284), (396, 398)
    sx, top = wr[0] - 4, wr[1] - 30
    bot = top + 158
    # émbolo y alas (metal con arañazos)
    for pts_, v in (([(sx - 4, top - 66), (sx + 4, top - 66), (sx + 4, top - 8), (sx - 4, top - 8)], 0.5),
                    ([(sx - 15, top - 78), (sx + 15, top - 78), (sx + 15, top - 66), (sx - 15, top - 66)], 0.55),
                    ([(sx - 18, top - 9), (sx + 18, top - 9), (sx + 18, top), (sx - 18, top)], 0.55)):
        qm, _ = c.paint(pts_, "metal", 0.0, 140, soft=3, base=v, contrast=1.8, length=4, width=1.0, density=0.9, wob=0)
        c.glint([(pts_[0][0] + 1, pts_[0][1] + 1.2), (pts_[1][0] - 1, pts_[1][1] + 1.2)], rcol("metal", 1.0), 0.9)
        c.outline(qm, 0.98, INK, 141)
    c.glint([(sx - 2.4, top - 64), (sx - 2.4, top - 12)], rcol("metal", 0.95), 0.9)
    # cilindro de cristal: líquido oscuro con menisco, escala, reflejo, burbujas
    barrel = [(sx - 13, top), (sx + 13, top), (sx + 13, bot - 6), (sx + 8, bot), (sx - 8, bot), (sx - 13, bot - 6)]
    qb = c.fill(barrel, rcol("glass", 0.3), smooth=False)
    with c.clip(barrel):
        c.fill([(sx - 13, top + 2), (sx + 13, top + 2), (sx + 13, top + 14), (sx - 13, top + 14)], rcol("nail", 0.1), smooth=False)
        liq = [(sx - 13, top + 44), (sx - 6, top + 41), (sx, top + 40), (sx + 6, top + 41), (sx + 13, top + 44), (sx + 13, bot), (sx - 13, bot)]
        c.fill(liq, rcol("liquid", 0.75), smooth=False)
        c.fill([(sx - 13, top + 60), (sx + 13, top + 52), (sx + 13, bot), (sx - 13, bot)], rcol("liquid", 0.35), smooth=False)
        c.ink([(sx - 12, top + 43.5), (sx, top + 40.5), (sx + 12, top + 43.5)], 1.0, 1.0, rcol("glass", 0.9), wob=0)   # menisco
        c.fill([(sx - 9, top + 3), (sx - 6, top + 3), (sx - 6, bot - 6), (sx - 9, bot - 9)], rcol("glass", 0.8), smooth=False, a=0.85)
        c.ink([(sx + 10, top + 4), (sx + 10, bot - 8)], 1.0, 1.0, rcol("glass", 0.05), smooth=False, wob=0)
        for i, y in enumerate(range(int(top) + 22, int(bot) - 8, 7)):
            c.ink([(sx + 1, y), (sx + (12 if i % 2 == 0 else 7), y)], 0.9, 0.9, rcol("porcelain", 0.9), smooth=False, wob=0)
        for bx, by, r in ((sx - 2, top + 70, 1.4), (sx + 4, top + 94, 1.0), (sx - 3, top + 120, 1.2), (sx + 3, top + 56, 0.8)):
            c.dots([(bx, by)], rcol("glass", 0.7), r)
    c.outline(qb, 1.2, INK, 142)
    tip_ = [(sx - 5, bot), (sx + 5, bot), (sx + 3, bot + 12), (sx - 3, bot + 12)]
    c.fill(tip_, rcol("metal", 0.6), smooth=False)
    c.outline(c.path(tip_, smooth=False), 1.1, INK, 143)
    c.ink([(sx, bot + 12), (sx + 3, bot + 92)], 1.6, 0.6, rcol("metal", 0.85), smooth=False, wob=0)
    c.ink([(sx + 1.3, bot + 12), (sx + 4, bot + 92)], 0.6, 0.3, INK, smooth=False, wob=0)
    c.fill([(sx + 2, bot + 94), (sx + 5, bot + 94), (sx + 4, bot + 103)], rcol("liquid", 0.8))
    # el brazo largo, consumido
    arm(c, sh, el, wr, 150)
    # mano: dorso con los tendones, cuatro dedos largos y nudosos alrededor del cilindro, uñas negras
    hx, hy = wr
    back = [(sx + 8, hy - 18), (sx + 20, hy - 20), (sx + 31, hy - 12), (sx + 32, hy + 6), (sx + 30, hy + 22), (sx + 19, hy + 38),
            (sx + 7, hy + 30)]
    qh, _ = c.paint(back, "nskin", 1.3, 160, soft=6, base=0.45, contrast=1.7, length=4, width=1.1, density=0.9, extra=sp)
    with c.clip(back):
        for k in range(4):
            c.ink([(sx + 26 - k * 2, hy - 12 + k * 3), (sx + 14 - k * 2, hy - 4 + k * 10)], 0.9, 0.4, rcol("nskin", 0.85), seed=161 + k)
    c.outline(qh, 1.2, INK, 162)
    for i in range(4):
        y = hy - 8 + i * 13
        f_ = [(sx + 24, y), (sx + 8, y + 2), (sx - 1, y + 5), (sx - 9, y + 8), (sx - 15, y + 11)]
        st = polyline_interp(f_, 7)
        fp = limb_pts(st, [5.4, 5.2, 4.2, 4.6, 3.6, 3.8, 3.0], [5.4, 5.0, 4.2, 4.4, 3.6, 3.6, 3.0])
        qf, _ = c.paint(fp, "nskin", axis(f_), 163 + i, soft=3, base=0.5, contrast=1.8, length=3, width=0.9, density=1.0, extra=sp, wob=0.3)
        with c.clip(fp):
            for kn in (st[2], st[4]):
                c.ink([(kn[0] - 1, kn[1] - 4), (kn[0] + 1, kn[1] + 4)], 0.9, 0.4, INK, smooth=False, wob=0)
            c.glint([(st[1][0] - 2, st[1][1] - 3.6), (st[1][0] + 3, st[1][1] - 3.4)], rcol("nskin", 1.0), 0.7)
        c.fill([(st[-1][0] - 4, st[-1][1] - 3), (st[-1][0] + 1, st[-1][1] - 3.4), (st[-1][0] + 1.4, st[-1][1] + 3),
                (st[-1][0] - 4, st[-1][1] + 3.2)], rcol("nail", 0.2), smooth=False)
        c.outline(qf, 0.98, INK, 170 + i)
    thumb = [(sx + 18, hy - 22), (sx + 6, hy - 27), (sx - 4, hy - 24), (sx - 12, hy - 20)]
    st = polyline_interp(thumb, 6)
    tp = limb_pts(st, [6, 5.6, 4.6, 4.8, 3.8, 3.2], [6, 5.4, 4.6, 4.4, 3.6, 3.2])
    qt, _ = c.paint(tp, "nskin", axis(thumb), 175, soft=3, base=0.6, contrast=1.8, length=3, width=0.9, density=1.0, wob=0.3)
    c.outline(qt, 0.98, INK, 176)
    # manga rota sobre el hombro
    slv = [(sh[0] - 22, sh[1] - 12), (sh[0] - 4, sh[1] - 22), (sh[0] + 14, sh[1] - 22), (sh[0] + 30, sh[1] + 2), (sh[0] + 26, sh[1] + 34),
           (sh[0] + 18, sh[1] + 27), (sh[0] + 12, sh[1] + 42), (sh[0] + 4, sh[1] + 30), (sh[0] - 6, sh[1] + 38), (sh[0] - 14, sh[1] + 24),
           (sh[0] - 24, sh[1] + 6)]
    qs, _ = c.paint(slv, "uniform", 1.2, 180, soft=10, base=0.5, contrast=1.8, length=6, width=1.5, density=0.8, extra=sp)
    with c.clip(slv):
        c.scumble([(sh[0] + 6, sh[1] - 30), (sh[0] + 40, sh[1] - 30), (sh[0] + 40, sh[1] + 50), (sh[0] + 4, sh[1] + 50)], "uniform",
                  0.15, 1.3, 181, length=5, width=1.3, density=0.9)
        c.ink([(sh[0] - 8, sh[1] - 6), (sh[0] - 2, sh[1] + 22)], 1.3, 0.4, INK, seed=182)
        c.blood((sh[0] + 10, sh[1] + 10), 6, 183, "dry", drips=1, wet=False)
    c.outline(qs, 1.35, INK, 184)
    # ===================================== cuello y cabeza colgante =====================================
    neck = [(258, 118), (270, 114), (284, 118), (276, 140), (262, 168), (246, 178), (236, 172), (246, 146)]
    qn, _ = c.paint(neck, "nskin", 2.0, 190, soft=6, base=0.36, contrast=1.7, length=5, width=1.2, density=0.8)
    with c.clip(neck):
        c.ink([(276, 122), (256, 168)], 1.4, 0.6, INK, seed=191)
        c.ink([(266, 124), (248, 168)], 1.0, 0.5, rcol("nskin", 0.75), seed=192)
    c.outline(qn, 1.2, INK, 193)
    cx, cy, tilt = 222, 214, -0.42
    ct, st_ = math.cos(tilt), math.sin(tilt)
    HS = 1.18

    def Rt(pts):
        return [(cx + (x * ct - y * st_) * HS, cy + (x * st_ + y * ct) * HS) for x, y in pts]

    skull = Rt([(-6, -54), (6, -55), (16, -51), (25, -43), (31, -32), (34, -18), (34, -4), (32, 10), (28, 22), (22, 32), (14, 41),
                (4, 46), (-6, 46), (-15, 41), (-23, 33), (-29, 21), (-33, 6), (-34, -10), (-32, -26), (-27, -40), (-18, -50)])
    qk, mk = c.paint(skull, "nskin", lambda x, y: -0.4, 200, soft=12, base=0.46, contrast=1.8, length=5, width=1.3, density=0.8)
    for sd in (-1, 1):
        ear = Rt([(sd * 32, -14), (sd * 38, -15), (sd * 42, -6), (sd * 41, 6), (sd * 36, 12), (sd * 31, 4)])
        qe, _ = c.paint(ear, "nskin", 1.57, 201 + sd, soft=3, base=0.42 if sd > 0 else 0.5, contrast=1.6, length=3, width=0.9, density=1.0)
        c.ink(Rt([(sd * 36, -10), (sd * 38, 0), (sd * 35, 6)]), 1.0, 0.4, INK, seed=203)
        c.outline(qe, 0.98, INK, 204)
    with c.clip(skull):
        for p0, p1 in (((-14, -50), (-24, -30)), ((2, -54), (-2, -36)), ((16, -50), (24, -32)), ((-4, -52), (-12, -40))):
            c.ink(Rt([p0, lerp(p0, p1, 0.5), p1]), 1.0, 0.3, rcol("nail", 0.3), seed=205)                     # pelo ralo y pegado
        for v in (Rt([(-24, -40), (-28, -26), (-24, -16)]), Rt([(20, -44), (26, -32), (22, -24)])):
            c.ink(v, 1.1, 0.4, rcol("vein", 0.6), seed=206, wob=1.0)
    # máscara de porcelana: plano a la luz y plano en sombra, ceja tallada, craquelado, trozo saltado
    mask = Rt([(-30, -28), (-22, -32), (-12, -35), (0, -36), (12, -35), (22, -32), (30, -28), (33, -18), (32, -6), (28, 4),
               (20, 11), (10, 15), (0, 18), (-10, 15), (-20, 11), (-28, 4), (-32, -6), (-33, -18)])
    qm, mm = c.paint(mask, "porcelain", -0.6, 210, soft=9, base=0.62, contrast=1.9, length=4, width=1.1, density=0.9, jitter=0.03)
    with c.clip(mask):
        c.scumble(Rt([(2, -38), (38, -38), (38, 22), (0, 22), (4, -2), (1, -20)]), "porcelain", 0.3, -1.0, 211, length=4, width=1.1, density=1.0)
        c.ink(Rt([(0, -28), (1, -8), (0, 16)]), 1.3, 0.5, rcol("porcelain", 0.15), seed=212)
        c.ink(Rt([(-2, -28), (-1, -8), (-2, 14)]), 1.0, 0.4, rcol("porcelain", 1.0), seed=213)
        c.ink(Rt([(-26, -20), (-14, -25), (-4, -21)]), 1.4, 0.5, INK, seed=214)
        c.ink(Rt([(4, -21), (14, -25), (26, -20)]), 1.4, 0.5, INK, seed=215)
        c.ink(Rt([(-26, -23), (-14, -28), (-4, -24)]), 1.0, 0.4, rcol("porcelain", 1.0), seed=216)
        c.glint(Rt([(-22, -30), (-10, -33)]), rcol("porcelain", 1.0), 1.2)
        rr = random.Random(7)
        for st0, n in (((-8, -10), 7), ((-2, -34), 5), ((22, -30), 5), ((20, 6), 4), ((-26, -2), 4), ((10, -30), 3), ((-18, 8), 3)):
            x, y = st0
            ang = rr.uniform(0, 2 * math.pi)
            pts = [(x, y)]
            for _ in range(n):
                ang += rr.uniform(-0.9, 0.9)
                x, y = x + math.cos(ang) * rr.uniform(2.5, 5), y + math.sin(ang) * rr.uniform(2.5, 5)
                pts.append((x, y))
                if rr.random() < 0.35:                                                                             # ramita
                    b = ang + rr.choice((-1.2, 1.2))
                    c.ink(Rt([(x, y), (x + math.cos(b) * 3, y + math.sin(b) * 3)]), 0.6, 0.3, INK, smooth=False, wob=0)
            P = Rt(pts)
            c.ink([(p[0] + 0.7, p[1] + 0.7) for p in P], 0.8, 0.4, rcol("porcelain", 1.0), smooth=False, wob=0)
            c.ink(P, 1.0, 0.4, INK, smooth=False, wob=0)
        for _ in range(60):                                                                                       # craquelado fino
            x, y = rr.uniform(-28, 28), rr.uniform(-30, 12)
            a = rr.uniform(0, math.pi)
            c.ink(Rt([(x, y), (x + math.cos(a) * 2.4, y + math.sin(a) * 2.4)]), 0.35, 0.3, rcol("porcelain", 0.3), smooth=False,
                  wob=0, a=0.8)
    # cuencas: la izquierda vacía y negra; en la derecha, un ojo vivo, húmedo, inyectado
    eye_l = Rt([(-23, -16), (-14, -20), (-5, -17), (-4, -8), (-12, -4), (-21, -7)])
    c.fill(eye_l, rcol("liquid", 0.0), wob=0.4, seed=220)
    c.outline(c.path(eye_l, wob=0.4, seed=220), 1.4, INK, 221)
    eye_r = Rt([(5, -17), (14, -21), (23, -16), (24, -7), (14, -3), (6, -8)])
    c.fill(eye_r, rcol("liquid", 0.3), wob=0.4, seed=222)
    with c.clip(eye_r, wob=0.4, seed=222):
        c.fill(Rt([(7, -13), (14, -17), (22, -13), (21, -7), (14, -5), (8, -8)]), rcol("eye", 0.7))
        c.fill(Rt([(14, -16), (20, -13), (19, -8), (14, -7)]), rcol("eye", 0.95))
        for vv in (((21, -12), (17, -11), (16, -12)), ((8, -10), (11, -11)), ((20, -8), (17, -8.4)), ((9, -12), (11, -12.6))):
            c.ink(Rt(list(vv)), 0.5, 0.3, rcol("blood", 0.7), smooth=False, wob=0)
        c.fill(Rt([(10.6, -14.4), (15.4, -15), (16.2, -10), (11.6, -9.4)]), rcol("eye", 0.3))                   # iris
        c.fill(Rt([(12.4, -13.4), (14.6, -13.6), (14.8, -11), (12.8, -10.8)]), INK)                              # pupila
        c.dots(Rt([(13.0, -14.0)]), rcol("eye", 1.0), 0.7)                                                       # brillo húmedo
        c.ink(Rt([(6, -6), (14, -4), (22, -6.5)]), 1.0, 0.4, rcol("blood", 0.55), smooth=False, wob=0)
    c.outline(c.path(eye_r, wob=0.4, seed=222), 1.4, INK, 223)
    chip = Rt([(-33, -4), (-25, -6), (-21, 2), (-28, 8)])
    c.fill(chip, rcol("flesh", 0.35), wob=0.5, seed=224)
    c.fill(Rt([(-30, -3), (-25, -4), (-24, 0)]), rcol("flesh", 0.8))
    c.outline(c.path(chip, wob=0.5, seed=224), 1.0, INK, 225)
    c.outline(qm, 1.27, INK, 226)
    c.ink(Rt([(-33, -16), (-40, -14)]), 2.0, 2.0, INK, smooth=False, wob=0)
    c.ink(Rt([(33, -16), (40, -14)]), 2.0, 2.0, INK, smooth=False, wob=0)
    # mascarilla quirúrgica cosida: pliegues, sangre de la boca que empapa, cada punto tirando de la piel
    cloth = Rt([(-28, 4), (-20, 9), (-10, 14), (0, 17), (10, 14), (20, 9), (28, 4), (28, 14), (24, 24), (18, 32), (10, 38), (0, 41),
                (-10, 38), (-18, 32), (-24, 24), (-28, 14)])
    qc, _ = c.paint(cloth, "mask_cloth", lambda x, y: -0.42, 230, soft=7, base=0.55, contrast=1.8, length=5, width=1.1, density=0.9)
    with c.clip(cloth):
        c.scumble(Rt([(4, 0), (34, 0), (34, 46), (2, 46), (6, 28)]), "mask_cloth", 0.2, -0.4, 231, length=4, width=1.1, density=1.0)
        for y in (17, 24, 31):
            f_ = Rt([(-24, y - 4), (-8, y + 1), (8, y + 1), (24, y - 4)])
            c.ink(f_, 1.2, 0.4, INK, seed=232 + y)
            c.ink([(x, y_ - 1.4) for x, y_ in f_], 0.8, 0.3, rcol("mask_cloth", 1.0), seed=233 + y)
        c.blood(Rt([(2, 28)])[0], 9, 235, "blood", drips=1)
        c.blood(Rt([(1, 27)])[0], 4, 236, "blood", drips=0)
    c.outline(qc, 1.12, INK, 237)
    edge = Rt([(-30, 2), (-29, 16), (-22, 32), (-11, 43), (0, 46), (11, 43), (22, 32), (29, 16), (30, 2)])
    for a, b in zip(edge, edge[1:]):
        for t in (0.2, 0.55, 0.85):
            qq = lerp(a, b, t)
            dx, dy = b[0] - a[0], b[1] - a[1]
            ln = math.hypot(dx, dy)
            nx, ny = -dy / ln, dx / ln
            c.ink([(qq[0] - nx * 5, qq[1] - ny * 5), (qq[0] + nx * 5, qq[1] + ny * 5)], 1.4, 1.0, INK, smooth=False, wob=0)
            c.dots([(qq[0] + nx * 5, qq[1] + ny * 5)], rcol("flesh", 0.4), 0.9)
            for o in (-1, 1):
                c.ink([(qq[0] + nx * 5 + dx / ln * o * 2, qq[1] + ny * 5 + dy / ln * o * 2),
                       (qq[0] + nx * 9 + dx / ln * o * 4, qq[1] + ny * 9 + dy / ln * o * 4)], 0.7, 0.3, rcol("nskin", 0.1),
                      smooth=False, wob=0)
    c.blood(Rt([(2, 47)])[0], 4, 238, "blood", drips=2, down=2.4)
    c.outline(qk, 1.58, INK, 239)
    # ===================================== tubos que entran en el pecho =====================================
    for k, path in enumerate(([(318, 96), (322, 124), (314, 150), (302, 166), (294, 176)],
                              [(344, 120), (346, 150), (334, 180), (318, 204), (306, 214)],
                              [(286, 82), (300, 104), (304, 132), (300, 152)])):
        st = polyline_interp(path, 10)
        tp = limb_pts(st, [3.4] * 10, [3.4] * 10)
        c.fill(tp, rcol("liquid", 0.55))
        with c.clip(tp):
            c.ink([(x - 1.8, y) for x, y in st], 0.9, 0.9, rcol("glass", 0.7), wob=0)
            c.ink([(x + 1.6, y) for x, y in st], 1.0, 1.0, rcol("liquid", 0.0), wob=0)
        c.outline(c.path(tp), 1.3, INK, 240 + k)
        ex, ey = path[-1]
        pucker = [(ex - 8, ey - 2), (ex - 2, ey - 8), (ex + 7, ey - 3), (ex + 6, ey + 5), (ex - 4, ey + 7)]
        c.fill(pucker, rcol("flesh", 0.35), wob=0.8, seed=k)
        c.fill([(ex - 3, ey - 2), (ex + 2, ey - 3), (ex + 2, ey + 2), (ex - 2, ey + 3)], rcol("flesh", 0.05))
        for ang in (0.3, 1.5, 2.7, 3.9, 5.1):
            c.ink([(ex + math.cos(ang) * 7, ey + math.sin(ang) * 6), (ex + math.cos(ang) * 13, ey + math.sin(ang) * 11)], 0.8, 0.3, INK,
                  smooth=False, wob=0)
        c.ink([(ex, ey + 6), (ex + 0.6, ey + 14), (ex - 0.4, ey + 22)], 1.5, 1.0, rcol("blood", 0.5), seed=245 + k)
    # ===================================== brazo de instrumental =====================================
    sh, el, wr = (168, 152), (118, 296), (136, 414)
    ux, uy = (wr[0] - el[0]), (wr[1] - el[1])
    ln = math.hypot(ux, uy)
    ux, uy = ux / ln, uy / ln
    nx, ny = -uy, ux
    out = (nx, ny) if nx < 0 else (-nx, -ny)
    # sierra de hueso: hoja con dientes, arañazos, óxido, sangre seca en los dientes
    s0 = lerp(el, wr, 0.15)
    s0 = (s0[0] + out[0] * 14, s0[1] + out[1] * 14)
    s1 = (s0[0] + ux * 196, s0[1] + uy * 196)
    blade = [s0, s1, (s1[0] + out[0] * 25, s1[1] + out[1] * 25)]
    nt = 40
    for t in range(nt, -1, -1):
        p = lerp((s0[0] + out[0] * 19, s0[1] + out[1] * 19), (s1[0] + out[0] * 25, s1[1] + out[1] * 25), t / nt)
        blade.append(p)
        if t:
            qq = lerp((s0[0] + out[0] * 19, s0[1] + out[1] * 19), (s1[0] + out[0] * 25, s1[1] + out[1] * 25), (t - 0.5) / nt)
            blade.append((qq[0] + out[0] * 5 - ux * 1.5, qq[1] + out[1] * 5 - uy * 1.5))
    qsaw = c.fill(blade, rcol("metal", 0.55), smooth=False)
    with c.clip(blade, ):
        c.path(blade, smooth=False)
        c.ctx.clip()
        mb = c.mask(blade, smooth=False)
        c.strokes(mb, np.full_like(mb, 0.55), "metal", math.atan2(uy, ux), 9, 1.0, 0.6, 0.12, 250)
        c.fill([s0, s1, (s1[0] + out[0] * 6, s1[1] + out[1] * 6), (s0[0] + out[0] * 5, s0[1] + out[1] * 5)], rcol("metal", 0.9), smooth=False)
        c.fill([(s0[0] + out[0] * 14, s0[1] + out[1] * 14), (s1[0] + out[0] * 18, s1[1] + out[1] * 18),
                (s1[0] + out[0] * 40, s1[1] + out[1] * 40), (s0[0] + out[0] * 40, s0[1] + out[1] * 40)], rcol("metal", 0.25), smooth=False)
        rr = random.Random(251)
        for _ in range(40):                                                                                         # arañazos
            t = rr.uniform(0.05, 0.95)
            p = lerp(s0, s1, t)
            p = (p[0] + out[0] * rr.uniform(3, 16), p[1] + out[1] * rr.uniform(3, 16))
            a = math.atan2(uy, ux) + rr.uniform(-0.3, 0.3)
            c.ink([p, (p[0] + math.cos(a) * rr.uniform(3, 9), p[1] + math.sin(a) * rr.uniform(3, 9))], 0.45, 0.3,
                  rcol("metal", rr.choice((0.1, 0.95))), smooth=False, wob=0)
        for t, r_ in ((0.3, 6), (0.55, 8), (0.8, 5)):
            cc = lerp(s0, s1, t)
            cc = (cc[0] + out[0] * 12, cc[1] + out[1] * 12)
            c.fill([(cc[0] + rr.uniform(-r_, r_), cc[1] + rr.uniform(-r_, r_)) for _ in range(9)], rcol("rust", 0.5), wob=1.0, seed=int(t * 99))
            c.dots([(cc[0] + rr.uniform(-r_, r_), cc[1] + rr.uniform(-r_, r_)) for _ in range(12)], rcol("rust", 0.2), 0.6)
        for t in (0.2, 0.5, 0.8):
            qq = lerp(s0, s1, t)
            qq = (qq[0] + out[0] * 6, qq[1] + out[1] * 6)
            c.fill([(qq[0] - 2.4, qq[1] - 2.4), (qq[0] + 2.4, qq[1] - 2.4), (qq[0] + 2.4, qq[1] + 2.4), (qq[0] - 2.4, qq[1] + 2.4)],
                   rcol("metal", 0.2), smooth=True)
            c.dots([(qq[0] - 0.8, qq[1] - 0.8)], rcol("metal", 1.0), 0.6)
        c.blood((s1[0] + out[0] * 18 - ux * 16, s1[1] + out[1] * 18 - uy * 16), 8, 252, "dry", drips=2, wet=False)
        c.blood((s1[0] + out[0] * 20 - ux * 60, s1[1] + out[1] * 20 - uy * 60), 5, 253, "blood", drips=1)
    c.outline(qsaw, 1.2, INK, 254)
    # bisturíes en abanico: hoja con bisel, lomo, reflejo nítido, sangre en la punta que gotea
    for k, (ang, bl) in enumerate(((-0.66, 100), (-0.34, 124), (-0.04, 132), (0.26, 118), (0.54, 92))):
        d = (ux * math.cos(ang) - uy * math.sin(ang), ux * math.sin(ang) + uy * math.cos(ang))
        bn = (-d[1], d[0])
        base = (wr[0] + ux * 14 + bn[0] * (k - 2) * 4, wr[1] + uy * 14 + bn[1] * (k - 2) * 4)
        tip = (base[0] + d[0] * bl, base[1] + d[1] * bl)
        cv = 1 if ang < 0 else -1
        belly = (base[0] + d[0] * bl * 0.62 + bn[0] * 8 * cv, base[1] + d[1] * bl * 0.62 + bn[1] * 8 * cv)
        spine = (base[0] + d[0] * bl * 0.8 - bn[0] * 2 * cv, base[1] + d[1] * bl * 0.8 - bn[1] * 2 * cv)
        pts = [(base[0] - bn[0] * 3.4 * cv, base[1] - bn[1] * 3.4 * cv), spine, tip, belly, (base[0] + bn[0] * 5 * cv, base[1] + bn[1] * 5 * cv)]
        qbl = c.fill(pts, rcol("metal", 0.5), smooth=False)
        with c.clip(pts):
            c.path(pts, smooth=False)
            c.ctx.clip()
            c.fill([belly, tip, lerp(tip, spine, 0.15), lerp(belly, spine, 0.4), lerp(pts[-1], pts[0], 0.4), pts[-1]], rcol("metal", 0.8), smooth=False)
            c.fill([pts[0], spine, lerp(spine, belly, 0.25), lerp(pts[0], pts[-1], 0.3)], rcol("metal", 0.25), smooth=False)
            c.glint([lerp(pts[-1], belly, 0.2), lerp(belly, tip, 0.6)], rcol("metal", 1.0), 0.9)
            c.fill([tip, lerp(tip, belly, 0.35), lerp(tip, spine, 0.4)], rcol("blood", 0.4), smooth=False)
            c.blood(lerp(base, tip, 0.72), 3.2, 255 + k, "blood", drips=0)
        c.outline(qbl, 0.98, INK, 260 + k)
        c.ink([tip, (tip[0] + 0.8, tip[1] + 6), (tip[0] + 0.3, tip[1] + 11)], 1.4, 1.0, rcol("blood", 0.5), seed=265 + k)
    # el brazo, con el antebrazo hinchado donde la carne se funde con el metal
    q_ar, st_ar = arm(c, sh, el, wr, 270, fused=True)
    stump = [(wr[0] + nx * 21 - ux * 8, wr[1] + ny * 21 - uy * 8), (wr[0] - nx * 21 - ux * 8, wr[1] - ny * 21 - uy * 8),
             (wr[0] - nx * 16 + ux * 18, wr[1] - ny * 16 + uy * 18), (wr[0] - nx * 4 + ux * 23, wr[1] - ny * 4 + uy * 23),
             (wr[0] + nx * 10 + ux * 21, wr[1] + ny * 10 + uy * 21), (wr[0] + nx * 17 + ux * 17, wr[1] + ny * 17 + uy * 17)]
    qst, _ = c.paint(stump, "flesh", math.atan2(nx, ny), 280, soft=6, base=0.5, contrast=1.8, length=4, width=1.2, density=0.95, wob=1.4)
    with c.clip(stump, wob=1.4, seed=280):
        rr = random.Random(281)
        for _ in range(14):                                                                                         # brillo húmedo
            p = (wr[0] + rr.uniform(-14, 14), wr[1] + rr.uniform(-4, 18))
            c.glint([p, (p[0] + rr.uniform(1, 3), p[1] + rr.uniform(-1, 1))], rcol("flesh", 1.0), 0.6)
        c.dots([(wr[0] + rr.uniform(-14, 14), wr[1] + rr.uniform(-4, 18)) for _ in range(20)], rcol("flesh", 0.0), 0.8)
    c.outline(qst, 1.2, INK, 282)
    for t in (0.38, 0.72):                                                                                       # abrazaderas
        qq = lerp(el, wr, t)
        hw = 22
        band = [(qq[0] + nx * hw - ux * 4, qq[1] + ny * hw - uy * 4), (qq[0] - nx * hw - ux * 4, qq[1] - ny * hw - uy * 4),
                (qq[0] - nx * hw + ux * 5, qq[1] - ny * hw + uy * 5), (qq[0] + nx * hw + ux * 5, qq[1] + ny * hw + uy * 5)]
        c.fill(band, rcol("metal", 0.35), smooth=False)
        c.fill([band[0], band[1], lerp(band[1], band[2], 0.35), lerp(band[0], band[3], 0.35)], rcol("metal", 0.8), smooth=False)
        c.outline(c.path(band, smooth=False), 1.3, INK, 290)
        for o in (-15, 15):
            b_ = (qq[0] + nx * o, qq[1] + ny * o)
            c.fill([(b_[0] - 2.4, b_[1] - 2.4), (b_[0] + 2.4, b_[1] - 2.4), (b_[0] + 2.4, b_[1] + 2.4), (b_[0] - 2.4, b_[1] + 2.4)], rcol("metal", 0.85))
            c.ink([(b_[0] - 2, b_[1]), (b_[0] + 2, b_[1])], 0.8, 0.8, INK, smooth=False, wob=0)
        for o in (-1, 1):
            c.ink([(qq[0] + nx * 20 + ux * o * 8, qq[1] + ny * 20 + uy * o * 8), (qq[0] - nx * 20 + ux * o * 8, qq[1] - ny * 20 + uy * o * 8)],
                  1.0, 0.3, INK, smooth=False, wob=0.5)
        c.fill([(qq[0] - nx * 21 + ux * 6, qq[1] - ny * 21 + uy * 6), (qq[0] + nx * 21 + ux * 6, qq[1] + ny * 21 + uy * 6),
                (qq[0] + nx * 18 + ux * 9, qq[1] + ny * 18 + uy * 9), (qq[0] - nx * 18 + ux * 9, qq[1] - ny * 18 + uy * 9)],
               rcol("flesh", 0.4), smooth=False, a=0.85)                                                          # carne que rebosa
    seam0 = (lerp(el, wr, 0.08)[0] + out[0] * 13, lerp(el, wr, 0.08)[1] + out[1] * 13)
    seam1 = (lerp(el, wr, 0.98)[0] + out[0] * 13, lerp(el, wr, 0.98)[1] + out[1] * 13)
    c.ink([seam0, seam1], 2.6, 1.6, rcol("flesh", 0.3), smooth=False, wob=0.6)
    c.ink([seam0, seam1], 0.8, 0.8, INK, smooth=False, wob=0.4)
    for i in range(14):                                                                                         # grapas
        qq = lerp(seam0, seam1, (i + 0.5) / 14)
        c.ink([(qq[0] - out[0] * 4.4, qq[1] - out[1] * 4.4), (qq[0] + out[0] * 4.4, qq[1] + out[1] * 4.4)], 1.6, 1.6,
              rcol("metal", 0.85), smooth=False, wob=0)
        c.ink([(qq[0] + out[0] * 4.6, qq[1] + out[1] * 4.6), (qq[0] + out[0] * 4.6 + ux * 2, qq[1] + out[1] * 4.6 + uy * 2)], 0.9, 0.9, INK,
              smooth=False, wob=0)
        c.dots([(qq[0] - out[0] * 4.6, qq[1] - out[1] * 4.6)], rcol("flesh", 0.2), 0.8)
    for t in (0.2, 0.45, 0.8):
        c.blood(lerp(seam0, seam1, t), 3.6, int(t * 300), "blood", drips=1, down=2.0)
    slv = [(sh[0] + 22, sh[1] - 12), (sh[0] + 4, sh[1] - 22), (sh[0] - 14, sh[1] - 22), (sh[0] - 30, sh[1] + 2), (sh[0] - 26, sh[1] + 34),
           (sh[0] - 18, sh[1] + 27), (sh[0] - 12, sh[1] + 42), (sh[0] - 4, sh[1] + 30), (sh[0] + 6, sh[1] + 38), (sh[0] + 14, sh[1] + 24),
           (sh[0] + 24, sh[1] + 6)]
    qs, _ = c.paint(slv, "uniform", 1.9, 300, soft=10, base=0.58, contrast=1.8, length=6, width=1.5, density=0.8, extra=sp)
    with c.clip(slv):
        c.scumble([(sh[0] + 4, sh[1] - 30), (sh[0] + 40, sh[1] - 30), (sh[0] + 40, sh[1] + 50), (sh[0] + 2, sh[1] + 50)], "uniform", 0.2, 1.9,
                  301, length=5, width=1.3, density=0.9)
        c.ink([(sh[0] + 8, sh[1] - 6), (sh[0] + 2, sh[1] + 22)], 1.3, 0.4, INK, seed=302)
        c.blood((sh[0] - 8, sh[1] + 16), 7, 303, "dry", drips=1, wet=False)
    c.outline(qs, 1.35, INK, 304)
    return c


def frame():
    return draw().render(pal.NURSE)


if __name__ == "__main__":
    from paint import upscale
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n/fh_nurse.png"
    im = frame()
    im.save(out)
    upscale(im, 2).save(out.replace(".png", "_x2.png"))
