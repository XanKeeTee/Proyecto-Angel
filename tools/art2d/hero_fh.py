"""Protagonista a tinta y pinceladas (quinta muestra): en guardia de espaldas (260×420) y en el mapa (112×160).

Guardia: piernas abiertas y flexionadas de verdad (rodillas hacia fuera, el peso delante, el talón
derecho levantado), tronco girado y encorvado, el tubo cruzado por delante en diagonal y cogido con las
dos manos juntas a la derecha, a la altura del pecho; asoma por encima del hombro izquierdo. La bata
cuelga con peso de los hombros, se abre por detrás (incisión cosida sobre la columna) y el brazo en
guardia tira de ella.
"""

from __future__ import annotations

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import palette_fh as pal  # noqa: E402
from brush import Canvas, lerp, limb_pts, polyline_interp, rcol  # noqa: E402
from nurse_fh import axis, spot  # noqa: E402

INK = (26, 17, 16)


def _stitch(c: Canvas, pts, every: float, size: float, w: float = 1.0):
    for a, b in zip(pts, pts[1:]):
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1
        nx, ny = -dy / ln, dx / ln
        for i in range(max(1, int(ln / every))):
            q = lerp(a, b, (i + 0.5) / max(1, int(ln / every)))
            c.ink([(q[0] - nx * size, q[1] - ny * size), (q[0] + nx * size, q[1] + ny * size)], w, w, INK, smooth=False, wob=0)


def combat() -> Canvas:
    c = Canvas(260, 420, 4, (1.0, 0, 0))
    sp = spot(c, 40, 420, 0.06, -0.3)
    rnd = random.Random(4)
    # ------------------------------- piernas, desde atrás -------------------------------
    for hip, knee, ank, lift, seed in (((106, 250), (80, 318), (90, 384), 0, 1), ((158, 252), (186, 320), (176, 386), 1, 2)):
        st = polyline_interp([hip, knee, ank], 16)
        # muslo con isquios, corva estrecha, gemelos abultados arriba y por dentro, tendón fino
        outer = [16, 16.5, 16, 15, 13.5, 12, 10.5, 10, 11.5, 13, 12.5, 10.5, 8.5, 7, 6.2, 6.4]
        inner = [15, 15, 14.5, 13.5, 12, 10.5, 9.5, 9.5, 12, 13.5, 12.5, 10, 8, 6.6, 6, 6.2]
        pts = limb_pts(st, outer, inner)
        q, _ = c.paint(pts, "skin", axis([hip, knee, ank]), seed, soft=8, base=0.48, contrast=1.8, length=5, width=1.3,
                       density=0.85, extra=sp, wob=0.6)
        kx, ky = knee
        with c.clip(pts, wob=0.6, seed=seed):
            c.ink([(kx - 10, ky + 1), (kx - 2, ky + 5), (kx + 9, ky + 1)], 1.5, 0.5, INK, seed=seed)                 # corva
            c.ink([(kx - 7, ky - 18), (kx - 6, ky + 2)], 1.0, 0.4, INK, seed=seed + 1)
            c.ink([(kx + 7, ky - 18), (kx + 6, ky + 2)], 1.0, 0.4, INK, seed=seed + 2)
            g0, g1 = lerp(knee, ank, 0.12), lerp(knee, ank, 0.58)
            c.ink([g0, lerp(g0, g1, 0.5), g1], 1.1, 0.4, INK, seed=seed + 3)                                       # entre gemelos
            for sd in (-1, 1):
                gc = lerp(knee, ank, 0.3)
                c.scumble([(gc[0] + sd * 2, gc[1] - 12), (gc[0] + sd * 11, gc[1] - 6), (gc[0] + sd * 9, gc[1] + 14),
                           (gc[0] + sd * 2, gc[1] + 18)], "skin", 0.78 if sd < 0 else 0.4, axis([knee, ank]), seed + 4 + sd,
                          length=4, width=1.1, density=0.6)
            c.ink([lerp(knee, ank, 0.62), (ank[0], ank[1] - 1)], 0.9, 0.4, rcol("skin", 0.9), seed=seed + 5)        # Aquiles
            for _ in range(40):                                                                                     # vello
                p = lerp(knee, ank, rnd.uniform(0.05, 0.8))
                p = (p[0] + rnd.uniform(-9, 9), p[1])
                c.ink([p, (p[0] + rnd.uniform(-1, 1), p[1] + 2.4)], 0.35, 0.2, rcol("skin", 0.1), smooth=False, wob=0)
            c.fill([(hip[0] - 20, hip[1] - 4), (hip[0] + 20, hip[1] - 4), (hip[0] + 20, hip[1] + 26), (hip[0] - 20, hip[1] + 34)],
                   rcol("skin", 0.12), wob=3, seed=seed, a=0.75)                                                    # sombra de la bata
        c.outline(q, 1.4, INK, seed)
        # talón y planta sucia (el derecho, levantado: se ve la planta)
        ax, ay = ank
        heel = [(ax - 8, ay - 3), (ax, ay - 4), (ax + 8, ay - 3), (ax + 10, ay + 9 - lift * 4), (ax + 7, ay + 21 - lift * 4),
                (ax, ay + 23 - lift * 4), (ax - 7, ay + 21 - lift * 4), (ax - 10, ay + 9 - lift * 4)]
        qh, _ = c.paint(heel, "skin", 1.57, seed + 9, soft=4, base=0.45, contrast=1.8, length=3, width=1.0, density=0.9, extra=sp)
        with c.clip(heel):
            c.fill([(ax - 12, ay + 10 - lift * 4), (ax + 12, ay + 10 - lift * 4), (ax + 12, ay + 26), (ax - 12, ay + 26)],
                   rcol("dirt", 0.5), wob=1.6, seed=seed)
            c.ink([(ax - 6, ay + 15 - lift * 4), (ax + 5, ay + 16 - lift * 4)], 0.8, 0.4, INK, seed=seed)
            c.dots([(ax + rnd.uniform(-7, 7), ay + rnd.uniform(11, 21) - lift * 4) for _ in range(10)], rcol("dirt", 0.0), 0.5)
        c.outline(qh, 1.4, INK, seed + 10)
    c.blood((174, 306), 3.0, 5, "blood", drips=1, down=1.5)                                                       # rasguño
    c.fill([(84, 336), (92, 332), (94, 342), (86, 346)], (70, 50, 74), wob=1.2, seed=6, a=0.75)                       # cardenal
    # ------------------------------- espalda desnuda -------------------------------
    back = [(104, 102), (126, 98), (150, 100), (172, 106), (186, 116), (192, 134), (188, 158), (184, 186), (182, 216), (180, 244),
            (174, 264), (132, 268), (90, 264), (84, 240), (82, 210), (78, 182), (72, 156), (70, 134), (78, 114), (90, 106)]
    qb, _ = c.paint(back, "skin", 1.57, 10, soft=18, base=0.5, contrast=1.8, length=6, width=1.5, density=0.8, extra=sp)
    with c.clip(back):
        for pts_, v in (([(98, 126), (86, 142), (88, 176), (104, 172)], 0.78), ([(134, 124), (160, 130), (166, 168), (146, 178)], 0.3)):
            c.scumble(pts_, "skin", v, 1.2, 11, length=4, width=1.2, density=0.8)
            c.ink(pts_[1:] if v > 0.5 else pts_[:3], 1.3, 0.4, INK, seed=12)
        spine = [(119, 112), (117, 150), (118, 190), (121, 232), (122, 262)]
        c.ink(spine, 1.6, 0.8, INK, seed=13)
        c.ink([(x - 2, y) for x, y in spine[:3]], 0.9, 0.4, rcol("skin", 0.9), seed=14)
        for y in (116, 126, 136, 146):
            c.fill([(116, y), (121, y - 2.4), (124, y + 2), (119, y + 4)], rcol("skin", 0.85), smooth=False)
        for i in range(4):                                                                                       # costillas
            y = 184 + i * 11
            c.ink([(96 - i, y), (106, y + 4)], 0.9, 0.3, INK, seed=15 + i)
            c.ink([(134, y + 4), (150 + i, y)], 0.9, 0.3, INK, seed=19 + i)
        # incisión cosida: cardenal con halo, carne, costra, hilo negro
        c.fill([(108, 150), (130, 148), (132, 230), (110, 232)], (78, 58, 78), wob=3, seed=20, a=0.55)
        c.fill([(112, 160), (126, 158), (128, 222), (114, 224)], (60, 42, 64), wob=2, seed=21, a=0.6)
        inc = [(118, 146), (117, 178), (119, 210), (121, 236)]
        st = polyline_interp(inc, 8)
        c.fill(limb_pts(st, [2.2] * 8, [2.2] * 8), rcol("flesh", 0.55), smooth=False)
        c.ink(inc, 1.0, 1.0, rcol("flesh", 0.05), wob=0.3)
        _stitch(c, inc, 6.0, 5.2, 1.2)
        c.blood((120, 228), 3, 22, "dry", drips=2, down=2.5, wet=False)
        brief = [(100, 246), (160, 246), (164, 268), (96, 268)]
        c.fill(brief, rcol("brief", 0.5), smooth=False)
        c.fill([(100, 246), (160, 246), (160, 250), (100, 250)], rcol("brief", 0.1), smooth=False)
        c.ink([(130, 250), (132, 268)], 1.0, 0.4, INK)
    c.outline(qb, 1.4, INK, 23)
    # ------------------------------- bata con peso -------------------------------
    gl = [(104, 102), (90, 106), (76, 114), (66, 126), (62, 142), (66, 164), (70, 190), (68, 220), (64, 252), (58, 282), (60, 296),
          (66, 292), (72, 302), (78, 294), (84, 304), (90, 294), (96, 300), (100, 289), (99, 256), (97, 218), (102, 180), (108, 148),
          (112, 118)]
    gr = [(128, 106), (148, 100), (168, 104), (184, 112), (194, 126), (196, 146), (192, 170), (192, 204), (196, 242), (202, 284),
          (200, 292), (194, 287), (190, 299), (184, 289), (176, 301), (170, 291), (164, 299), (158, 287), (156, 254), (150, 220),
          (140, 186), (132, 150), (128, 122)]
    drape = lambda x, y: -1.57 + (0.25 if y < 150 else 0.0) * (1 if x > 130 else -1)  # noqa: E731
    qgl, _ = c.paint(gl, "gown", drape, 30, soft=14, base=0.5, contrast=1.8, length=7, width=1.5, density=0.8, extra=sp)
    with c.clip(gl):
        for k, (f, sd) in enumerate((([(62, 128), (72, 170), (70, 214), (64, 262), (60, 296)], 1), ([(86, 118), (88, 170), (82, 230), (78, 298)], 1),
                                     ([(92, 250), (90, 298)], 1), ([(68, 236), (62, 296)], -1), ([(80, 140), (76, 160)], 1))):
            sh_ = [(x + 5 * sd, y + 1) for x, y in f]
            c.scumble(f + sh_[::-1], "gown", 0.18, -1.57, 31 + k, length=5, width=1.3, density=1.0, smooth=False)
            c.ink(f, 1.4, 0.4, INK, seed=40 + k)
            c.ink([(x - 2 * sd, y) for x, y in f], 0.9, 0.3, rcol("gown", 1.0), seed=45 + k)
        c.ink([(112, 118), (108, 148), (102, 180), (95, 218), (97, 256)], 1.8, 1.0, rcol("gown", 1.0), seed=49)       # canto doblado
    c.outline(qgl, 1.6, INK, 50)
    qgr, _ = c.paint(gr, "gown", drape, 51, soft=14, base=0.42, contrast=1.8, length=7, width=1.5, density=0.8, extra=sp)
    with c.clip(gr):
        c.scumble([(194, 120), (222, 120), (222, 310), (200, 310), (206, 220)], "gown", 0.05, -1.57, 52, length=6, width=1.4, density=1.0)
        for k, (f, sd) in enumerate((([(198, 128), (178, 160), (160, 200)], 1), ([(200, 150), (184, 196), (180, 240)], 1),
                                     ([(170, 214), (176, 254), (174, 294)], -1), ([(190, 232), (196, 262), (198, 294)], 1),
                                     ([(150, 110), (148, 140)], 1), ([(180, 116), (164, 140)], 1))):
            sh_ = [(x + 5 * sd, y + 1) for x, y in f]
            c.scumble(f + sh_[::-1], "gown", 0.12, -1.0, 53 + k, length=5, width=1.3, density=1.0, smooth=False)
            c.ink(f, 1.4, 0.4, INK, seed=60 + k)
            c.ink([(x - 2 * sd, y) for x, y in f], 0.9, 0.3, rcol("gown", 0.85), seed=66 + k)
    c.outline(qgr, 1.6, INK, 70)
    with c.clip(back):
        c.ink([(130, 120), (132, 150), (140, 186), (150, 220), (156, 254)], 3.4, 2.4, rcol("skin", 0.08), seed=71)   # sombra de la tela
    # trama, mugre y sangre seca en la tela; los lazos
    for pan, sd in ((gl, 72), (gr, 73)):
        with c.clip(pan):
            for _ in range(260):
                x, y = rnd.uniform(40, 220), rnd.uniform(98, 304)
                c.ink([(x, y), (x + rnd.uniform(-0.4, 0.4), y + rnd.uniform(2, 5))], 0.35, 0.3, rcol("gown", rnd.uniform(0.2, 0.45)),
                      smooth=False, wob=0, a=0.7)
            c.fill([(40, 280), (220, 276), (220, 306), (40, 306)], rcol("dirt", 0.6), wob=3, seed=sd, a=0.5)
    with c.clip(gr):
        c.blood((198, 200), 6, 74, "dry", drips=2, down=2.0, wet=False)
    knot = [(112, 104), (126, 102), (128, 110), (114, 112)]
    c.fill(knot, rcol("gown", 0.85), smooth=False)
    c.ink([(116, 112), (110, 128), (112, 140)], 2.2, 1.0, rcol("gown", 0.7), seed=75)
    c.ink([(122, 112), (126, 126)], 2.0, 1.0, rcol("gown", 0.4), seed=76)
    c.ink([(98, 176), (106, 182), (104, 196)], 2.2, 1.0, rcol("gown", 0.9), seed=77)
    c.outline(c.path(knot, smooth=False), 1.0, INK, 78)
    # ------------------------------- nuca y cráneo -------------------------------
    neck = [(104, 82), (122, 80), (140, 82), (146, 108), (122, 110), (100, 108)]
    qn, _ = c.paint(neck, "skin", 1.57, 80, soft=6, base=0.45, contrast=1.8, length=4, width=1.1, density=0.9)
    with c.clip(neck):
        c.ink([(110, 86), (108, 104)], 1.2, 0.5, INK, seed=81)
        c.ink([(134, 86), (138, 104)], 1.2, 0.5, INK, seed=82)
    c.outline(qn, 1.3, INK, 83)
    cx, cy = 122, 62
    skull = [(cx - 8, cy - 30), (cx + 2, cy - 31), (cx + 12, cy - 29), (cx + 20, cy - 23), (cx + 25, cy - 13), (cx + 26, cy - 1),
             (cx + 24, cy + 10), (cx + 19, cy + 20), (cx + 10, cy + 26), (cx, cy + 28), (cx - 10, cy + 26), (cx - 19, cy + 20),
             (cx - 24, cy + 10), (cx - 26, cy - 1), (cx - 25, cy - 13), (cx - 20, cy - 23)]
    for sd in (-1, 1):
        ear = [(cx + sd * 24, cy - 6), (cx + sd * 30, cy - 7), (cx + sd * 32, cy + 3), (cx + sd * 30, cy + 12), (cx + sd * 25, cy + 14),
               (cx + sd * 23, cy + 6)]
        qe, _ = c.paint(ear, "skin", 1.57, 84 + sd, soft=3, base=0.5 if sd < 0 else 0.35, contrast=1.7, length=3, width=0.9, density=1.0)
        c.ink([(cx + sd * 28, cy - 3), (cx + sd * 29, cy + 6), (cx + sd * 27, cy + 10)], 0.9, 0.4, INK, seed=86)
        c.outline(qe, 1.2, INK, 87)
    qk, _ = c.paint(skull, "scalp", -1.2, 88, soft=10, base=0.5, contrast=1.8, length=4, width=1.1, density=0.9)
    with c.clip(skull):
        c.dots([(cx + rnd.uniform(-24, 24), cy + rnd.uniform(-28, 18)) for _ in range(260)], rcol("scalp", 0.15), 0.35)   # pelo rapado
        c.ink([(cx - 18, cy + 22), (cx, cy + 26), (cx + 18, cy + 22)], 1.3, 0.5, INK, seed=89)
        scar = [(cx + 2, cy - 30), (cx - 6, cy - 20), (cx - 13, cy - 8), (cx - 19, cy + 4), (cx - 22, cy + 12)]
        c.fill([(cx - 22, cy - 20), (cx - 2, cy - 30), (cx - 8, cy + 0), (cx - 24, cy + 14)], (74, 54, 70), wob=2, seed=90, a=0.5)
        st = polyline_interp(scar, 8)
        c.fill(limb_pts(st, [1.8] * 8, [1.8] * 8), rcol("flesh", 0.5), smooth=False)
        c.ink(scar, 0.8, 0.8, rcol("flesh", 0.05), wob=0.3)
        _stitch(c, scar, 4.6, 3.8, 1.0)
    c.outline(qk, 1.6, INK, 91)
    # ------------------------------- tubo: asoma por encima del hombro izquierdo y entre las manos -------------------------------
    pa, pb = (228, 186), (34, 68)
    L = math.hypot(pb[0] - pa[0], pb[1] - pa[1])
    ux, uy = (pb[0] - pa[0]) / L, (pb[1] - pa[1]) / L
    for t0, t1 in ((0.74, 1.0), (0.0, 0.2)):
        a, b = lerp(pa, pb, t0), lerp(pa, pb, t1)
        st = polyline_interp([a, b], 6)
        pp = limb_pts(st, [4.4] * 6, [4.4] * 6)
        qp, _ = c.paint(pp, "iron", math.atan2(uy, ux), 92, soft=2.5, base=0.48, contrast=1.9, length=6, width=1.0, density=1.0, wob=0)
        with c.clip(pp, wob=0):
            c.glint([(a[0] - uy * 2.4 * -1, a[1] + ux * 2.4 * -1), (b[0] - uy * 2.4 * -1, b[1] + ux * 2.4 * -1)], rcol("iron", 1.0), 0.8)
            for t in (0.3, 0.7):
                cc = lerp(a, b, t)
                c.fill([(cc[0] + rnd.uniform(-4, 4), cc[1] + rnd.uniform(-3, 3)) for _ in range(7)], rcol("rust", 0.5) if False else rcol("iron", 0.25),
                       wob=0.6, seed=int(t * 50))
        c.outline(qp, 1.3, INK, 93)
    cap = [(pb[0] - uy * 7 + ux * 2, pb[1] + ux * 7 + uy * 2), (pb[0] + uy * 7 + ux * 2, pb[1] - ux * 7 + uy * 2),
           (pb[0] + uy * 7 - ux * 11, pb[1] - ux * 7 - uy * 11), (pb[0] - uy * 7 - ux * 11, pb[1] + ux * 7 - uy * 11)]
    qc, _ = c.paint(cap, "iron", math.atan2(uy, ux), 94, soft=3, base=0.42, contrast=1.9, length=4, width=1.0, density=1.0, wob=0)
    with c.clip(cap, wob=0):
        for t in (0.3, 0.55, 0.8):
            qq = lerp(cap[0], cap[3], t)
            c.ink([qq, (qq[0] + (cap[1][0] - cap[0][0]), qq[1] + (cap[1][1] - cap[0][1]))], 0.8, 0.8, INK, smooth=False, wob=0)
        c.blood(lerp(cap[0], cap[2], 0.45), 3.4, 95, "dry", drips=0, wet=False)
    c.outline(qc, 1.3, INK, 96)
    # ------------------------------- brazo en guardia y las dos manos -------------------------------
    sh, el, wr = (194, 120), (244, 146), (216, 166)
    st = polyline_interp([sh, el, wr], 12)
    ap = limb_pts(st, [15, 15.5, 13, 11, 9.5, 9.5, 10.5, 11, 10, 8.5, 7.6, 7.2], [13, 12.5, 11, 10, 9, 9, 10, 10.5, 9.5, 8, 7, 7])
    qa, _ = c.paint(ap, "skin", axis([sh, el, wr]), 100, soft=6, base=0.5, contrast=1.8, length=5, width=1.2, density=0.9, extra=sp)
    with c.clip(ap):
        ex, ey = el
        c.fill([(ex - 3, ey - 9), (ex + 7, ey - 7), (ex + 9, ey + 3), (ex + 1, ey + 2)], rcol("skin", 0.85), wob=0.6, seed=101)
        c.ink([(ex - 6, ey + 3), (ex + 4, ey + 8)], 1.0, 0.4, INK, seed=102)
        c.ink([lerp(sh, el, 0.25), lerp(sh, el, 0.8)], 1.0, 0.4, INK, seed=103)                                  # tríceps
        c.ink([lerp(el, wr, 0.15), (lerp(el, wr, 0.6)[0] - 3, lerp(el, wr, 0.6)[1])], 1.0, 0.4, rcol("vein", 0.6), seed=104, wob=1)
    c.outline(qa, 1.4, INK, 105)
    sleeve = [(170, 104), (186, 103), (200, 108), (214, 128), (210, 146), (204, 140), (198, 152), (190, 142), (182, 150), (176, 136)]
    qs, _ = c.paint(sleeve, "gown", -1.0, 106, soft=8, base=0.48, contrast=1.8, length=5, width=1.3, density=0.9)
    with c.clip(sleeve):
        c.ink([(184, 112), (190, 140)], 1.3, 0.4, INK, seed=107)
        c.ink([(196, 112), (204, 132)], 1.1, 0.4, INK, seed=108)
    c.outline(qs, 1.4, INK, 109)
    for (hx, hy), sd in (((196, 166), 1), ((213, 177), 0)):
        fist = [(hx - 10, hy - 8), (hx - 2, hy - 12), (hx + 7, hy - 11), (hx + 13, hy - 3), (hx + 12, hy + 6), (hx + 8, hy + 12),
                (hx - 2, hy + 13), (hx - 10, hy + 6), (hx - 12, hy - 1)]
        qf, _ = c.paint(fist, "skin", 0.6, 110 + sd, soft=4, base=0.52, contrast=1.8, length=3, width=0.9, density=1.0, extra=sp)
        with c.clip(fist):
            for o in (-5, 0, 5):                                                                                     # dedos
                c.ink([(hx - 6 + o * 0.3, hy - 4 + o), (hx + 3, hy - 1 + o), (hx + 12, hy + o * 0.4 - 1)], 1.1, 0.5, INK, seed=112 + o)
            for o in (-6, -1, 4, 9):                                                                                 # nudillos
                c.fill([(hx + 9, hy + o - 1.8), (hx + 12, hy + o - 1.2), (hx + 12, hy + o + 1.2), (hx + 9, hy + o + 1.8)],
                       rcol("skin", 0.9))
                c.fill([(hx + 11.4, hy + o - 1), (hx + 13, hy + o - 0.6), (hx + 13, hy + o + 0.8), (hx + 11.4, hy + o + 1)],
                       rcol("nail", 0.5) if False else rcol("skin", 0.25))
            c.fill([(hx - 12, hy - 6), (hx - 2, hy - 13), (hx + 3, hy - 9), (hx - 6, hy - 2)], rcol("skin", 0.8))         # pulgar
            c.ink([(hx - 12, hy - 6), (hx - 2, hy - 13), (hx + 3, hy - 9)], 1.0, 0.4, INK, seed=118)
        c.outline(qf, 1.3, INK, 119 + sd)
    band = [(212, 156), (224, 162), (220, 169), (208, 163)]
    c.fill(band, rcol("band", 0.6), smooth=False)
    c.fill([(212, 156), (224, 162), (223, 164), (211, 158)], rcol("band", 1.0), smooth=False)
    c.ink([(214, 161), (219, 164)], 0.7, 0.7, INK, smooth=False, wob=0)
    c.outline(c.path(band, smooth=False), 1.0, INK, 121)
    tape = [(188, 158), (196, 156), (197, 163), (189, 164)]
    c.fill(tape, rcol("tape", 0.6), smooth=False)
    c.outline(c.path(tape, smooth=False), 0.9, INK, 122)
    c.ink([(192, 164), (188, 178), (192, 192), (188, 206)], 1.6, 1.1, rcol("tube", 0.6), seed=123)
    c.ink([(193, 164), (189, 178)], 0.6, 0.4, rcol("tube", 1.0), seed=124)
    c.blood((191, 168), 2.6, 125, "blood", drips=2, down=3.0)
    c.blood((188, 207), 1.4, 126, "blood", drips=1, down=2.0)
    return c


def map_down() -> Canvas:
    """Mapa, mirando abajo (112×160)."""
    c = Canvas(112, 160, 6, (1.0, 0, 0))
    rnd = random.Random(8)
    sp = spot(c, 10, 160, 0.04, -0.18)
    for hip, knee, ank, seed in (((50, 88), (47.6, 114), (49, 141), 1), ((62, 88), (63.4, 114), (62, 141), 2)):
        st = polyline_interp([hip, knee, ank], 12)
        pts = limb_pts(st, [5.8, 5.6, 5.0, 4.4, 3.8, 3.5, 3.9, 4.3, 3.8, 2.9, 2.3, 2.4], [5.6, 5.4, 4.8, 4.2, 3.7, 3.4, 3.6, 3.8, 3.3, 2.6, 2.2, 2.3])
        q, _ = c.paint(pts, "skin", axis([hip, knee, ank]), seed, soft=2.6, base=0.48, contrast=1.8, length=2.2, width=0.6,
                       density=0.9, extra=sp, wob=0.15)
        with c.clip(pts):
            c.fill([(knee[0] - 2, knee[1] - 2.6), (knee[0] + 1.8, knee[1] - 2.8), (knee[0] + 2.2, knee[1] + 0.6), (knee[0] - 1.6, knee[1] + 1)],
                   rcol("skin", 0.85))
            c.ink([(knee[0] - 2.4, knee[1] + 1.8), (knee[0] + 2.4, knee[1] + 1.6)], 0.5, 0.3, INK, smooth=False, wob=0)
        c.outline(q, 0.7, INK, seed)
        ax, ay = ank
        sg = -1 if seed == 1 else 1
        foot = [(ax - 2.6, ay - 1), (ax + 2.6, ay - 1), (ax + 3.8 + sg, ay + 5.4), (ax + 3.4 + sg, ay + 8.6), (ax - 3.4 + sg, ay + 8.6),
                (ax - 3.8 + sg, ay + 5.4)]
        qf, _ = c.paint(foot, "skin", 1.57, seed + 5, soft=1.6, base=0.45, contrast=1.8, length=1.6, width=0.5, density=1.0, wob=0.1)
        with c.clip(foot):
            c.fill([(ax - 5, ay + 6.6), (ax + 5, ay + 6.6), (ax + 5, ay + 9), (ax - 5, ay + 9)], rcol("dirt", 0.5))
            for o in (-1.6, 0, 1.6):
                c.ink([(ax + o + sg, ay + 5.8), (ax + o + sg, ay + 8.6)], 0.4, 0.3, INK, smooth=False, wob=0)
        c.outline(qf, 0.7, INK, seed + 6)
    for sh, el, wr, sd, seed in (((41, 46), (37.6, 70), (38.6, 93), -1, 3), ((71, 47), (75, 71), (74, 94), 1, 4)):
        st = polyline_interp([sh, el, wr], 10)
        pts = limb_pts(st, [4.6, 4.4, 3.6, 3.1, 2.9, 3.4, 3.2, 2.7, 2.3, 2.2], [4.2, 3.8, 3.4, 3.0, 2.9, 3.1, 2.9, 2.5, 2.2, 2.1])
        q, _ = c.paint(pts, "skin", axis([sh, el, wr]), seed, soft=2.2, base=0.48, contrast=1.8, length=2.0, width=0.55, density=0.9,
                       extra=sp, wob=0.12)
        c.outline(q, 0.7, INK, seed)
        hx, hy = wr
        hand = [(hx - 2.4, hy - 0.4), (hx + 2.4, hy - 0.4), (hx + 3.0, hy + 4.4), (hx + 2.0, hy + 10.4), (hx - 0.6 * sd, hy + 12.2),
                (hx - 2.4, hy + 10), (hx - 3.2, hy + 4.4)]
        qh, _ = c.paint(hand, "skin", 1.57, seed + 10, soft=1.6, base=0.5, contrast=1.8, length=1.6, width=0.5, density=1.0, wob=0.1)
        with c.clip(hand):
            for o in (-1.0, 0.4, 1.8):
                c.ink([(hx + o, hy + 6), (hx + o * 0.9, hy + 11)], 0.4, 0.25, INK, smooth=False, wob=0)
        c.outline(qh, 0.7, INK, seed + 11)
    c.fill([(36.2, 89), (41.2, 89.4), (41, 92), (36, 91.6)], rcol("band", 0.9), smooth=False)
    c.fill([(72.4, 96.4), (76, 96), (76.2, 98.6), (72.6, 99)], rcol("tape", 0.6), smooth=False)
    c.ink([(74.6, 98.6), (77, 104), (75.6, 109), (77.4, 114)], 0.8, 0.6, rcol("tube", 0.6), seed=12)
    c.blood((73.8, 101), 1.2, 13, "blood", drips=1, down=3)
    gown = [(48.4, 37), (52.6, 41.6), (55, 46.6), (57.4, 41.6), (61.4, 37), (66, 38), (70, 40.5), (75, 43.5), (78.6, 48), (80, 53.4),
            (79, 58), (74.6, 58.6), (72, 54), (70.4, 72), (72.6, 88), (75.4, 102), (71.6, 105), (68, 102.6), (63.6, 106), (59, 103),
            (54.4, 106.4), (50, 103), (45.4, 106), (41.4, 102.6), (37.4, 105.4), (36.4, 101.6), (39.6, 88), (41.8, 72), (40, 54),
            (37.4, 58.6), (33, 58), (32, 53.4), (33.4, 48), (37, 43.5), (42, 40.5), (45.4, 38)]
    q, _ = c.paint(gown, "gown", lambda x, y: -1.57, 20, soft=6, base=0.5, contrast=1.8, length=2.6, width=0.6, density=0.9, extra=sp,
                   wob=0.12)
    with c.clip(gown):
        for k, (f, sd) in enumerate((([(43, 46), (46, 66), (44, 86), (42, 102)], 1), ([(68, 46), (66, 66), (68, 86), (70, 102)], -1),
                                     ([(52.6, 48), (51, 70), (50, 90), (49, 104)], 1), ([(57.6, 48), (59, 70), (60, 90), (62, 104)], -1),
                                     ([(55, 80), (55.4, 104)], 1), ([(36, 48), (38, 56)], 1), ([(76, 48), (75, 56)], -1))):
            sh_ = [(x + 1.6 * sd, y) for x, y in f]
            c.scumble(f + sh_[::-1], "gown", 0.2, -1.57, 21 + k, length=1.8, width=0.5, density=1.2, smooth=False)
            c.ink(f, 0.6, 0.25, INK, seed=30 + k)
        c.fill([(36, 100), (48, 98), (48, 108), (36, 108)], rcol("dirt", 0.6), wob=0.6, seed=40, a=0.6)
        c.blood((66, 74), 1.6, 41, "dry", drips=1, down=2, wet=False)
    c.outline(q, 0.8, INK, 42)
    vee = [(48.6, 37.4), (61.2, 37.4), (57, 41.6), (55, 45.8), (53, 41.6)]
    c.fill(vee, rcol("skin", 0.35), smooth=False)
    c.ink([(49.6, 38.4), (53.6, 40)], 0.5, 0.3, rcol("skin", 0.85), smooth=False, wob=0)
    neck = [(50.8, 28), (58.6, 28), (60, 38), (49.6, 38)]
    qn, _ = c.paint(neck, "skin", 1.57, 43, soft=2, base=0.4, contrast=1.8, length=1.6, width=0.5, density=1.0, wob=0.1)
    c.outline(qn, 0.6, INK, 44)
    cx, cy = 54.6, 22
    for sd in (-1, 1):
        ear = [(cx + sd * 8, cy - 2.4), (cx + sd * 10.2, cy - 1.6), (cx + sd * 10.2, cy + 3), (cx + sd * 8.4, cy + 4.6)]
        c.fill(ear, rcol("skin", 0.55 if sd < 0 else 0.3))
        c.outline(c.path(ear), 0.6, INK, 45)
    head = [(cx - 4, cy - 11.4), (cx + 4, cy - 11.4), (cx + 7.6, cy - 8), (cx + 8.6, cy - 2.6), (cx + 8, cy + 3), (cx + 6.4, cy + 7),
            (cx + 3.6, cy + 10.2), (cx - 3.6, cy + 10.2), (cx - 6.4, cy + 7), (cx - 8, cy + 3), (cx - 8.6, cy - 2.6), (cx - 7.6, cy - 8)]
    qk, _ = c.paint(head, "skin", 1.57, 46, soft=3.4, base=0.5, contrast=1.8, length=1.6, width=0.5, density=1.0, wob=0.1)
    with c.clip(head):
        c.scumble([(cx - 10, cy - 13), (cx + 10, cy - 13), (cx + 10, cy - 5.4), (cx - 10, cy - 5.4)], "scalp", 0.55, 0.0, 47,
                  length=1.4, width=0.5, density=1.1)
        c.scumble([(cx + 3, cy - 13), (cx + 10, cy - 13), (cx + 10, cy - 5.4), (cx + 4, cy - 5.4)], "scalp", 0.25, 0.0, 48,
                  length=1.4, width=0.5, density=1.1)
        for ex in (cx - 3.4, cx + 3.2):
            c.fill([(ex - 2.8, cy - 2.2), (ex + 2.6, cy - 2.4), (ex + 2.6, cy + 0.6), (ex, cy + 1.6), (ex - 2.6, cy + 0.8)], rcol("skin", 0.08))
            c.fill([(ex - 1.3, cy - 0.7), (ex + 1.1, cy - 0.8), (ex + 1, cy + 0.3), (ex - 1.1, cy + 0.4)], rcol("ink", 0))
            c.dots([(ex - 0.4, cy - 0.5)], rcol("skin", 0.9), 0.35)
            c.ink([(ex - 2.6, cy - 3.0), (ex + 2.4, cy - 3.2)], 0.6, 0.3, INK, smooth=False, wob=0)
        c.ink([(cx, cy - 1.6), (cx - 0.4, cy + 3.6)], 0.5, 0.3, rcol("skin", 0.9), smooth=False, wob=0)
        c.fill([(cx - 1.4, cy + 3.6), (cx + 1.4, cy + 3.6), (cx + 0.6, cy + 4.6), (cx - 0.8, cy + 4.6)], rcol("skin", 0.1))
        for sd in (-1, 1):
            c.fill([(cx + sd * 4.4, cy + 2.4), (cx + sd * 6.6, cy + 2), (cx + sd * 6, cy + 6.4), (cx + sd * 4.6, cy + 5.8)], rcol("skin", 0.25))
        c.ink([(cx - 2.6, cy + 6.6), (cx, cy + 7), (cx + 2.6, cy + 6.4)], 0.7, 0.4, INK, smooth=False, wob=0)
        scar = [(cx - 7.6, cy - 3.6), (cx - 5.6, cy - 7.6), (cx - 1.6, cy - 10.2), (cx + 3.4, cy - 10.8)]
        c.ink(scar, 1.1, 1.1, rcol("flesh", 0.4), wob=0)
        _stitch(c, scar, 2.0, 1.2, 0.45)
    c.outline(qk, 0.8, INK, 49)
    _ = rnd
    return c


if __name__ == "__main__":
    from paint import upscale
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n/fh_hero.png"
    im = combat().render(pal.HERO)
    im.save(out)
    upscale(im, 2).save(out.replace(".png", "_x2.png"))
    m = map_down().render(pal.HERO)
    m.save(out.replace(".png", "_map.png"))
    upscale(m, 4).save(out.replace(".png", "_map_x4.png"))
