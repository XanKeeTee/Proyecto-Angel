"""Protagonista a tinta y color plano (cuarta muestra, prueba de estilo estática).

- `combat()`: de espaldas en guardia, 260×420. El tubo, cogido con las dos manos juntas a la altura del
  pecho por el lado derecho, cruza por delante del cuerpo en diagonal y asoma por encima del hombro
  izquierdo: listo para descargar. Hombros tensos, tronco girado, piernas flexionadas y abiertas, el talón
  derecho levantado. Bata abierta por detrás con la incisión cosida; las manos con sus dedos.
- `map_down()`: mapa mirando abajo, 112×160, el mismo método.
"""

from __future__ import annotations

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ink import INK, Ink, edges, jag, lerp  # noqa: E402
from nurse_ink import body_shadow, fold, limb  # noqa: E402
from palette_ink import PAL  # noqa: E402


def _stitches(I: Ink, pts, every: float, size: float, w: float = 1.2):
    for a, b in zip(pts, pts[1:]):
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1
        nx, ny = -dy / ln, dx / ln
        n = max(1, int(ln / every))
        for i in range(n):
            q = lerp(a, b, (i + 0.5) / n)
            I.line([(q[0] - nx * size - dx / ln, q[1] - ny * size - dy / ln), (q[0] + nx * size + dx / ln, q[1] + ny * size + dy / ln)],
                   w, w, taper=False)


def combat() -> Ink:
    I = Ink(260, 420, 4, PAL)
    rnd = random.Random(3)
    # ------------------------------- piernas -------------------------------
    for hip, knee, ank, lift, seed in (((108, 252), (84, 318), (88, 386), 0, 1), ((156, 254), (178, 322), (174, 388), 1, 2)):
        limb(I, [hip, lerp(hip, knee, 0.5), knee, lerp(knee, ank, 0.3), lerp(knee, ank, 0.7), ank],
             [(15, 15), (13.5, 12.5), (10, 10), (11.5, 10), (7, 6.5), (6, 6)], "skin", seed, contour=1.8, rim=False)
        kx, ky = knee
        I.line([(kx - 9, ky + 1), (kx, ky + 4), (kx + 9, ky)], 1.6, 0.6)                                   # corva
        I.line([(kx - 6, ky - 14), (kx - 5, ky + 2)], 1.2, 0.4)
        I.line([(kx + 6, ky - 14), (kx + 5, ky + 2)], 1.2, 0.4)
        g0 = lerp(knee, ank, 0.12)
        g1 = lerp(knee, ank, 0.55)
        I.line([g0, g1], 1.2, 0.4)                                                                          # entre gemelos
        I.line([lerp(knee, ank, 0.6), (ank[0], ank[1] - 2)], 1.0, 0.4)                                       # Aquiles
        ax, ay = ank
        heel = [(ax - 8, ay - 2), (ax + 8, ay - 2), (ax + 10, ay + 10 - lift * 4), (ax + 6, ay + 22 - lift * 4),
                (ax - 6, ay + 22 - lift * 4), (ax - 10, ay + 10 - lift * 4)]
        I.fill(heel, I.c("skin", 2))
        sole = [(ax - 9, ay + 10 - lift * 4), (ax + 9, ay + 10 - lift * 4), (ax + 6, ay + 22 - lift * 4), (ax - 6, ay + 22 - lift * 4)]
        I.fill(sole, I.c("dirt", 1))
        I.splat((ax + 2, ay + 16 - lift * 4), 5, I.c("dirt", 0), seed + 9, spikes=9, clip=sole)
        I.line([(ax - 6, ay + 14 - lift * 4), (ax + 6, ay + 15 - lift * 4)], 0.9, 0.4)
        I.poly_line(heel, 1.8)
        I.fill([(ax - 11, ay + 1), (ax - 7, ay - 1), (ax - 7, ay + 3)], I.c("skin", 3))                        # maléolo
    I.splat((90, 340), 6, I.c("skin", 0), 7, spikes=9)                                                       # cardenal
    I.line([(170, 300), (176, 312)], 1.2, 0.6, rgb=I.c("blood", 1))
    # ------------------------------- espalda desnuda y bata -------------------------------
    back = [(104, 104), (148, 100), (182, 112), (196, 132), (192, 170), (188, 206), (186, 240), (182, 262), (84, 262),
            (80, 236), (78, 200), (72, 164), (66, 134), (78, 116)]
    I.fill(back, I.c("skin", 2))
    body_shadow(I, back, [(140, 96), (200, 100), (200, 270), (150, 270), (146, 210), (150, 150)], "skin", 1)
    body_shadow(I, back, [(170, 100), (200, 100), (200, 270), (176, 270)], "skin", 0, hatch=2.2, seed=9)
    # omóplatos: el derecho despegado por el brazo en guardia
    for pts, sd in (([(100, 128), (86, 146), (90, 178), (104, 170)], -1), ([(136, 126), (160, 132), (164, 168), (146, 176)], 1)):
        I.fill(pts, I.c("skin", 3 if sd < 0 else 1))
        I.line(pts[1:] if sd < 0 else pts[:3], 1.4, 0.4)
    spine = [(119, 112), (117, 150), (118, 190), (121, 232), (122, 256)]
    I.line(spine, 1.6, 0.8)
    for y in (118, 128, 138):
        I.fill([(116, y), (121, y - 2), (124, y + 2), (119, y + 4)], I.c("skin", 3))
    for i in range(4):                                                                                   # costillas
        y = 182 + i * 12
        I.line([(98 - i, y), (108, y + 4)], 1.0, 0.3)
        I.line([(134, y + 4), (148 + i, y)], 1.0, 0.3)
    # incisión cosida sobre la columna: carne, costra y puntos
    inc = [(118, 146), (117, 178), (119, 210), (121, 236)]
    I.splat((119, 190), 9, I.c("skin", 1), 11, spikes=12)
    L, R = edges(inc, [(2.0, 2.0)] * 4)
    I.fill(L + R[::-1], I.c("flesh", 2))
    I.line(inc, 1.0, 1.0, rgb=I.c("flesh", 0), taper=False)
    _stitches(I, inc, 7.0, 5.0, 1.4)
    I.splat((120, 228), 3, I.c("dry", 1), 12, spikes=7, drips=2, drip_len=2)
    brief = [(94, 236), (176, 236), (182, 262), (88, 262)]
    I.fill(brief, I.c("brief", 1))
    I.fill([(94, 236), (176, 236), (176, 241), (94, 241)], I.c("brief", 0))
    I.line([(130, 242), (132, 262)], 1.0, 0.4)
    # paneles de la bata, abiertos por detrás, con peso: caen de los hombros y se abren en el bajo
    gl = [(102, 104), (80, 112), (60, 124), (52, 148), (58, 176), (54, 214), (50, 254), (46, 296), (54, 292), (60, 302),
          (68, 294), (76, 304), (84, 294), (92, 300), (98, 288), (96, 254), (94, 214), (102, 178), (108, 146), (112, 116)]
    gr = [(128, 106), (150, 102), (176, 108), (196, 120), (204, 140), (198, 168), (202, 206), (208, 246), (214, 290),
          (206, 286), (200, 298), (192, 288), (184, 300), (176, 290), (168, 298), (160, 286), (156, 254), (150, 220),
          (140, 186), (132, 150), (128, 120)]
    for pan, sd, seed in ((gl, -1, 20), (gr, 1, 21)):
        I.fill(pan, I.c("gown", 2))
    # sombras planas: costado derecho de cada panel, bajo, sombra que el brazo arroja
    body_shadow(I, gl, [(84, 100), (120, 100), (120, 310), (82, 310), (86, 230), (80, 150)], "gown", 1)
    body_shadow(I, gl, [(40, 120), (64, 118), (60, 200), (56, 300), (40, 300)], "gown", 3)
    body_shadow(I, gr, [(176, 100), (220, 100), (220, 310), (186, 310), (192, 240), (186, 170)], "gown", 1)
    body_shadow(I, gr, [(196, 120), (220, 120), (220, 310), (200, 310), (204, 220)], "gown", 0, hatch=-0.9, seed=22)
    body_shadow(I, gr, [(126, 104), (150, 102), (140, 160), (130, 140)], "gown", 3)
    for pan in (gl, gr):
        body_shadow(I, pan, [(40, 270), (220, 270), (220, 310), (40, 310)], "gown", 1)
    # pliegues de tracción (del brazo derecho en guardia) y de peso
    for k, (pan, pts, sd) in enumerate(((gr, [(196, 128), (176, 160), (160, 200)], 1), (gr, [(198, 150), (182, 196), (178, 240)], 1),
                                        (gr, [(170, 214), (176, 254), (174, 292)], -1), (gr, [(190, 230), (196, 262), (198, 292)], 1),
                                        (gl, [(62, 128), (72, 170), (70, 214), (64, 262)], 1), (gl, [(86, 120), (88, 170), (82, 230), (78, 296)], 1),
                                        (gl, [(66, 236), (60, 296)], -1), (gl, [(92, 250), (90, 296)], 1), (gr, [(150, 110), (148, 140)], 1))):
        fold(I, pan, pts, "gown", sd, 5.0, 1.6, 30 + k)
    # el canto doblado de la abertura (filo claro) y su sombra sobre la piel
    I.line([(112, 116), (108, 146), (102, 178), (94, 214), (96, 254)], 1.6, 1.0, rgb=I.c("gown", 3))
    I.line([(130, 120), (132, 150), (140, 186), (150, 220), (156, 254)], 3.0, 2.0, rgb=I.c("skin", 0))
    # lazos: uno en la nuca, otro colgando a media espalda
    knot = [(112, 104), (126, 102), (128, 110), (114, 112)]
    I.fill(knot, I.c("gown", 3))
    I.poly_line(knot, 1.2)
    I.line([(116, 112), (110, 128), (112, 140)], 2.2, 1.0, rgb=I.c("gown", 2))
    I.line([(122, 112), (126, 126)], 2.0, 1.0, rgb=I.c("gown", 1))
    I.line([(98, 176), (106, 182), (104, 196)], 2.2, 1.0, rgb=I.c("gown", 3))
    # trama de la tela, mugre del bajo y sangre seca
    for pan in (gl, gr):
        I.ctx.save()
        I._path(pan)
        I.ctx.clip()
        I.hatch(pan, 1.57, 4.0, 0.5, rgb=I.c("gown", 1), seed=40)
        I.ctx.restore()
        I.splat((70 if pan is gl else 190, 292), 12, I.c("dirt", 1), 41 if pan is gl else 42, spikes=14, clip=pan)
    I.splat((198, 200), 7, I.c("dry", 1), 43, spikes=11, drips=2, clip=gr)
    I.splat((64, 150), 5, I.c("dirt", 0), 44, spikes=9, clip=gl)
    I.poly_line(gl, 2.0)
    I.poly_line(gr, 2.0)
    # ------------------------------- cabeza y nuca, adelantadas -------------------------------
    neck = [(104, 82), (140, 82), (146, 108), (100, 108)]
    I.fill(neck, I.c("skin", 2))
    I.clip_fill(neck, [(126, 80), (150, 80), (150, 110), (130, 110)], I.c("skin", 1))
    I.line([(110, 86), (108, 104)], 1.4, 0.5)
    I.line([(134, 86), (138, 104)], 1.4, 0.5)
    I.poly_line(neck, 1.6)
    cx, cy = 122, 62
    skull = [(cx - 8, cy - 30), (cx + 10, cy - 30), (cx + 22, cy - 22), (cx + 26, cy - 8), (cx + 25, cy + 8), (cx + 19, cy + 20),
             (cx + 8, cy + 27), (cx - 8, cy + 27), (cx - 19, cy + 20), (cx - 25, cy + 8), (cx - 26, cy - 8), (cx - 22, cy - 22)]
    I.fill(skull, I.c("scalp", 2))
    body_shadow(I, skull, [(cx + 4, cy - 34), (cx + 30, cy - 34), (cx + 30, cy + 30), (cx + 2, cy + 30), (cx + 10, cy)], "scalp", 1)
    body_shadow(I, skull, [(cx - 22, cy - 26), (cx - 2, cy - 32), (cx - 8, cy - 18), (cx - 24, cy - 10)], "scalp", 3)
    body_shadow(I, skull, [(cx - 30, cy + 14), (cx + 30, cy + 14), (cx + 30, cy + 30), (cx - 30, cy + 30)], "scalp", 1)
    I.stipple(skull, 0.08, 0.8, I.c("scalp", 0), 50)                                                     # pelo rapado
    for sd in (-1, 1):
        ear = [(cx + sd * 24, cy - 6), (cx + sd * 31, cy - 4), (cx + sd * 32, cy + 8), (cx + sd * 27, cy + 15), (cx + sd * 23, cy + 8)]
        I.fill(ear, I.c("skin", 2 if sd < 0 else 1))
        I.line([(cx + sd * 28, cy - 2), (cx + sd * 29, cy + 8)], 1.0, 0.4)
        I.poly_line(ear, 1.4)
    I.line([(cx - 18, cy + 22), (cx, cy + 26), (cx + 18, cy + 22)], 1.6, 0.6)                             # pliegue de la nuca
    scar = [(cx + 2, cy - 30), (cx - 6, cy - 20), (cx - 13, cy - 8), (cx - 19, cy + 4), (cx - 22, cy + 12)]
    I.splat((cx - 12, cy - 8), 7, PAL["skin"][1], 51, spikes=11, clip=skull)
    Ls, Rs = edges(scar, [(1.6, 1.6)] * len(scar))
    I.fill(Ls + Rs[::-1], I.c("flesh", 2))
    I.line(scar, 0.8, 0.8, rgb=I.c("flesh", 0), taper=False)
    _stitches(I, scar, 5.5, 4.0, 1.2)
    I.poly_line(skull, 2.2)
    # ------------------------------- el tubo, por delante del cuerpo -------------------------------
    pa, pb = (226, 186), (36, 70)
    # solo se ven sus dos extremos: arriba, por encima del hombro izquierdo; abajo, entre las manos
    for seg in ((lerp(pa, pb, 0.74), pb), (pa, lerp(pa, pb, 0.2))):
        L, R = edges(list(seg), [(4.2, 4.2), (4.2, 4.2)])
        pipe = L + R[::-1]
        I.fill(pipe, I.c("iron", 2))
        I.clip_fill(pipe, [(p[0] - 0.5, p[1] - 3) for p in L] + [(p[0], p[1] - 1) for p in L[::-1]], I.c("iron", 3))
        I.clip_fill(pipe, [(p[0], p[1]) for p in R] + [(p[0] + 0.5, p[1] - 2.4) for p in R[::-1]], I.c("iron", 0))
        I.poly_line(pipe, 1.6)
    _l = math.hypot(pb[0] - pa[0], pb[1] - pa[1])
    ux, uy = (pb[0] - pa[0]) / _l, (pb[1] - pa[1]) / _l
    tip = pb
    cap = [(tip[0] - uy * 7 + ux * 2, tip[1] + ux * 7 + uy * 2), (tip[0] + uy * 7 + ux * 2, tip[1] - ux * 7 + uy * 2),
           (tip[0] + uy * 7 - ux * 10, tip[1] - ux * 7 - uy * 10), (tip[0] - uy * 7 - ux * 10, tip[1] + ux * 7 - uy * 10)]
    I.fill(cap, I.c("iron", 1))
    I.fill([cap[0], cap[1], lerp(cap[1], cap[2], 0.3), lerp(cap[0], cap[3], 0.3)], I.c("iron", 3))
    I.splat(lerp(cap[0], cap[2], 0.5), 5, I.c("rust", 1), 60, spikes=9, clip=cap)
    I.splat(lerp(cap[0], cap[2], 0.4), 3, I.c("dry", 1), 61, spikes=7, clip=cap)
    I.poly_line(cap, 1.6)
    for t in (0.84, 0.92):
        q = lerp(pa, pb, t)
        I.line([(q[0] - uy * 4, q[1] + ux * 4), (q[0] + uy * 4, q[1] - ux * 4)], 1.0, 1.0, taper=False)    # rosca
    # ------------------------------- brazo derecho en guardia y las dos manos -------------------------------
    sh, el, wr = (194, 120), (244, 146), (214, 168)
    limb(I, [sh, lerp(sh, el, 0.5), el, lerp(el, wr, 0.5), wr], [(14, 13), (11, 10), (10, 10), (10, 9), (8, 8)], "skin", 70,
         contour=1.8, rim=False)
    ex, ey = el
    I.fill([(ex - 3, ey - 9), (ex + 8, ey - 6), (ex + 9, ey + 4), (ex + 1, ey + 2)], I.c("skin", 3))
    I.line([(ex - 6, ey + 3), (ex + 4, ey + 8)], 1.2, 0.4)
    I.line([lerp(sh, el, 0.25), lerp(sh, el, 0.8)], 1.2, 0.4)                                             # tríceps
    I.line([lerp(el, wr, 0.2), (lerp(el, wr, 0.6)[0] - 3, lerp(el, wr, 0.6)[1])], 0.9, 0.3, rgb=PAL["vein"][1])
    sleeve = [(170, 104), (198, 108), (214, 128), (210, 146), (204, 140), (198, 152), (190, 142), (182, 150), (176, 136)]
    I.fill(sleeve, I.c("gown", 2))
    body_shadow(I, sleeve, [(198, 100), (220, 100), (220, 160), (196, 160)], "gown", 1)
    fold(I, sleeve, [(184, 112), (190, 140)], "gown", 1, 4, 1.4, 71)
    I.poly_line(sleeve, 1.8)
    # puños alrededor del tubo: dedos apilados, nudillos, uñas, el pulgar por encima; la pulsera
    for (hx, hy), sd in (((196, 166), 1), ((212, 176), 0)):
        fist = [(hx - 10, hy - 8), (hx + 6, hy - 11), (hx + 13, hy - 2), (hx + 11, hy + 10), (hx - 2, hy + 13), (hx - 11, hy + 4)]
        I.fill(fist, I.c("skin", 2))
        I.clip_fill(fist, [(hx + 2, hy - 14), (hx + 16, hy - 14), (hx + 16, hy + 16), (hx + 4, hy + 16)], I.c("skin", 1))
        for o in (-5, 0, 5):                                                                            # dedos
            I.line([(hx - 6 + o * 0.3, hy - 4 + o), (hx + 11, hy + o * 0.4 - 1)], 1.3, 0.6)
        for o in (-6, -1, 4, 9):                                                                         # nudillos
            I.fill([(hx + 9, hy + o - 1.6), (hx + 12, hy + o - 1.2), (hx + 12, hy + o + 1.2), (hx + 9, hy + o + 1.6)], I.c("skin", 3))
        I.fill([(hx - 11, hy - 6), (hx - 2, hy - 13), (hx + 3, hy - 9), (hx - 6, hy - 2)], I.c("skin", 3))     # pulgar
        I.line([(hx - 11, hy - 6), (hx - 2, hy - 13), (hx + 3, hy - 9)], 1.2, 0.5)
        I.poly_line(fist, 1.6)
    band = [(212, 156), (224, 162), (220, 169), (208, 163)]
    I.fill(band, I.c("band", 1))
    I.fill([(212, 156), (224, 162), (223, 164), (211, 158)], I.c("band", 2))
    I.line([(214, 161), (219, 164)], 0.8, 0.8, taper=False)
    I.poly_line(band, 1.2)
    # la vía arrancada cuelga del dorso de la mano izquierda (la de arriba del tubo)
    I.fill([(188, 158), (196, 156), (197, 163), (189, 164)], I.c("tape", 1))
    I.poly_line([(188, 158), (196, 156), (197, 163), (189, 164)], 1.0)
    I.line([(192, 164), (188, 178), (192, 192), (188, 206)], 1.6, 1.0, rgb=I.c("tube", 1))
    I.line([(193, 164), (189, 178)], 0.7, 0.4)
    I.fill([(187, 206), (189.6, 206), (189, 212)], I.c("blood", 1))
    I.splat((191, 168), 3, I.c("blood", 1), 72, spikes=7, drips=2, drip_len=2.5)
    return I


def map_down() -> Ink:
    """Mapa, mirando abajo: 112×160 dibujado a ×6."""
    I = Ink(112, 160, 6, PAL)
    # piernas
    for hip, knee, ank, seed in (((50, 88), (48, 114), (49, 141), 1), ((62, 88), (63, 114), (62, 141), 2)):
        limb(I, [hip, lerp(hip, knee, 0.5), knee, lerp(knee, ank, 0.35), ank], [(5.6, 5.4), (4.8, 4.6), (3.6, 3.6), (4.0, 3.6), (2.3, 2.3)],
             "skin", seed, contour=0.9, rim=False)
        kx, ky = knee
        I.fill([(kx - 2, ky - 2.4), (kx + 1.6, ky - 2.6), (kx + 2, ky + 0.6), (kx - 1.6, ky + 1)], I.c("skin", 3))
        I.line([(kx - 2.4, ky + 1.6), (kx + 2.4, ky + 1.4)], 0.6, 0.3)
        I.line([lerp(knee, ank, 0.25), lerp(knee, ank, 0.85)], 0.5, 0.2, rgb=I.c("skin", 3))
        ax, ay = ank
        sg = -1 if seed == 1 else 1
        foot = [(ax - 2.6, ay - 1), (ax + 2.6, ay - 1), (ax + 3.8 + sg, ay + 5.4), (ax + 3.4 + sg, ay + 8.6),
                (ax - 3.4 + sg, ay + 8.6), (ax - 3.8 + sg, ay + 5.4)]
        I.fill(foot, I.c("skin", 2))
        I.clip_fill(foot, [(ax + 0.6, ay - 2), (ax + 6, ay - 2), (ax + 6, ay + 10), (ax + 1, ay + 10)], I.c("skin", 1))
        I.fill([(ax - 3.6 + sg, ay + 6.6), (ax + 3.6 + sg, ay + 6.6), (ax + 3.4 + sg, ay + 8.6), (ax - 3.4 + sg, ay + 8.6)], I.c("dirt", 1))
        for o in (-1.6, 0, 1.6):
            I.line([(ax + o + sg, ay + 5.6), (ax + o + sg, ay + 8.4)], 0.5, 0.3)
        I.poly_line(foot, 0.9)
    I.fill([(47, 124), (49, 123), (49.6, 126), (47.4, 127)], I.c("skin", 0))                                 # cardenal
    # brazos colgando, con las manos
    for sh, el, wr, sd, seed in (((41, 46), (37.6, 70), (38.6, 93), -1, 3), ((71, 47), (75, 71), (74, 94), 1, 4)):
        limb(I, [sh, lerp(sh, el, 0.5), el, lerp(el, wr, 0.4), wr], [(4.4, 4.2), (3.3, 3.1), (3.0, 3.0), (3.0, 2.8), (2.2, 2.2)],
             "skin", seed, contour=0.9, rim=False)
        I.line([(el[0] - 1.8, el[1] + 0.4), (el[0] + 1.8, el[1] + 0.8)], 0.6, 0.3)
        hx, hy = wr
        hand = [(hx - 2.4, hy - 0.4), (hx + 2.4, hy - 0.4), (hx + 3.0, hy + 4.4), (hx + 2.0, hy + 10.4), (hx - 0.6 * sd, hy + 12.2),
                (hx - 2.4, hy + 10), (hx - 3.2, hy + 4.4)]
        I.fill(hand, I.c("skin", 2))
        I.clip_fill(hand, [(hx + 0.4, hy - 1), (hx + 5, hy - 1), (hx + 5, hy + 14), (hx + 0.6, hy + 14)], I.c("skin", 1))
        for o in (-1.0, 0.4, 1.8):
            I.line([(hx + o, hy + 6), (hx + o * 0.9, hy + 11)], 0.5, 0.3)
        I.poly_line(hand, 0.9)
    # pulsera (derecha, a la izquierda de la pantalla) y vía arrancada (izquierda)
    I.fill([(36.2, 89), (41.2, 89.4), (41, 92), (36, 91.6)], I.c("band", 2))
    I.poly_line([(36.2, 89), (41.2, 89.4), (41, 92), (36, 91.6)], 0.6)
    I.fill([(72.4, 96.4), (76, 96), (76.2, 98.6), (72.6, 99)], I.c("tape", 1))
    I.line([(74.6, 98.6), (77, 104), (75.6, 109), (77.4, 114)], 0.9, 0.6, rgb=I.c("tube", 1))
    I.splat((73.8, 101), 1.4, I.c("blood", 1), 5, spikes=6, drips=1, drip_len=3)
    # bata: escote en pico, mangas, cae con peso, bajo en jirones
    gown = [(48.4, 37), (52.6, 41.6), (55, 46.6), (57.4, 41.6), (61.4, 37), (69, 40), (76, 44), (80, 52), (79, 58),
            (74.6, 58.6), (72, 54), (70.4, 72), (72.6, 88), (75.4, 102), (71.6, 105), (68, 102.6), (63.6, 106),
            (59, 103), (54.4, 106.4), (50, 103), (45.4, 106), (41.4, 102.6), (37.4, 105.4), (36.4, 101.6), (39.6, 88),
            (41.8, 72), (40, 54), (37.4, 58.6), (33, 58), (32, 52), (36, 44), (42.6, 40)]
    I.fill(gown, I.c("gown", 2))
    body_shadow(I, gown, [(58, 36), (84, 36), (84, 110), (60, 110), (62, 80), (58, 56)], "gown", 1)
    body_shadow(I, gown, [(70, 52), (84, 52), (84, 110), (70, 110), (72, 86)], "gown", 0)
    body_shadow(I, gown, [(30, 40), (46, 38), (42, 60), (38, 100), (30, 104)], "gown", 3)
    body_shadow(I, gown, [(30, 98), (84, 98), (84, 110), (30, 110)], "gown", 1)
    for k, (pts, sd) in enumerate((([(43, 46), (46, 66), (44, 86), (42, 102)], 1), ([(68, 46), (66, 66), (68, 86), (70, 102)], -1),
                                   ([(52.6, 48), (51, 70), (50, 90), (49, 104)], 1), ([(57.6, 48), (59, 70), (60, 90), (62, 104)], -1),
                                   ([(55, 80), (55.4, 104)], 1), ([(36, 48), (38, 56)], 1), ([(76, 48), (75, 56)], -1))):
        fold(I, gown, pts, "gown", sd, 1.6, 0.7, 20 + k)
    I.splat((44, 100), 4, I.c("dirt", 1), 30, spikes=10, clip=gown)
    I.splat((66, 74), 2.4, I.c("dry", 1), 31, spikes=8, drips=1, clip=gown)
    I.poly_line(gown, 1.0)
    vee = [(48.6, 37.4), (61.2, 37.4), (57, 41.6), (55, 45.8), (53, 41.6)]
    I.fill(vee, I.c("skin", 1))
    I.line([(49.6, 38.4), (53.6, 40)], 0.6, 0.3, rgb=I.c("skin", 3))                                      # clavículas
    I.line([(56.6, 40), (60.4, 38.4)], 0.6, 0.3, rgb=I.c("skin", 2))
    I.poly_line(vee, 0.8)
    # cuello y cabeza: cráneo rapado con la cicatriz cosida, cuencas hundidas, pómulos, boca seca
    neck = [(50.8, 28), (58.6, 28), (60, 38), (49.6, 38)]
    I.fill(neck, I.c("skin", 1))
    I.line([(51.6, 30), (50.6, 37)], 0.5, 0.2)
    I.line([(57.8, 30), (58.8, 37)], 0.5, 0.2)
    I.poly_line(neck, 0.8)
    cx, cy = 54.6, 22
    head = [(cx - 4, cy - 11.4), (cx + 4, cy - 11.4), (cx + 7.6, cy - 8), (cx + 8.6, cy - 2.6), (cx + 8, cy + 3), (cx + 6.4, cy + 7),
            (cx + 3.6, cy + 10.2), (cx - 3.6, cy + 10.2), (cx - 6.4, cy + 7), (cx - 8, cy + 3), (cx - 8.6, cy - 2.6), (cx - 7.6, cy - 8)]
    for sd in (-1, 1):
        ear = [(cx + sd * 8, cy - 2.4), (cx + sd * 10.2, cy - 1.6), (cx + sd * 10.2, cy + 3), (cx + sd * 8.4, cy + 4.6)]
        I.fill(ear, I.c("skin", 2 if sd < 0 else 1))
        I.poly_line(ear, 0.8)
    I.fill(head, I.c("skin", 2))
    I.clip_fill(head, [(cx - 10, cy - 13), (cx + 10, cy - 13), (cx + 10, cy - 5.4), (cx - 10, cy - 5.4)], I.c("scalp", 2))
    I.clip_fill(head, [(cx + 2, cy - 13), (cx + 10, cy - 13), (cx + 10, cy + 12), (cx + 3.6, cy + 12), (cx + 4.6, cy + 2)], I.c("skin", 1))
    I.clip_fill(head, [(cx + 3, cy - 13), (cx + 10, cy - 13), (cx + 10, cy - 5.4), (cx + 4, cy - 5.4)], I.c("scalp", 1))
    I.stipple([(cx - 8, cy - 12), (cx + 8, cy - 12), (cx + 8, cy - 5.6), (cx - 8, cy - 5.6)], 0.25, 0.4, I.c("scalp", 0), 40)
    for ex in (cx - 3.4, cx + 3.2):                                                                        # cuencas
        sock = [(ex - 2.8, cy - 2.2), (ex + 2.6, cy - 2.4), (ex + 2.6, cy + 0.6), (ex, cy + 1.6), (ex - 2.6, cy + 0.8)]
        I.fill(sock, I.c("skin", 0))
        I.fill([(ex - 1.4, cy - 0.6), (ex + 1.2, cy - 0.7), (ex + 1, cy + 0.4), (ex - 1.2, cy + 0.4)], I.c("liquid", 0))
        I.fill([(ex - 0.6, cy - 0.8), (ex + 0.2, cy - 0.8), (ex + 0.2, cy - 0.1), (ex - 0.6, cy - 0.1)], I.c("eye", 1))
        I.line([(ex - 2.6, cy - 3.0), (ex + 2.4, cy - 3.2)], 0.7, 0.3)                                     # ceja
    I.line([(cx, cy - 1.6), (cx - 0.4, cy + 3.6)], 0.6, 0.3)                                               # nariz
    I.fill([(cx - 1.4, cy + 3.6), (cx + 1.4, cy + 3.6), (cx + 0.6, cy + 4.6), (cx - 0.8, cy + 4.6)], I.c("skin", 0))
    for sd in (-1, 1):
        I.fill([(cx + sd * 4.4, cy + 2.4), (cx + sd * 6.6, cy + 2), (cx + sd * 6, cy + 6.4), (cx + sd * 4.6, cy + 5.8)], I.c("skin", 1))
    I.line([(cx - 2.6, cy + 6.6), (cx, cy + 7), (cx + 2.6, cy + 6.4)], 0.8, 0.5)                          # boca
    scar = [(cx - 7.6, cy - 3.6), (cx - 5.6, cy - 7.6), (cx - 1.6, cy - 10.2), (cx + 3.4, cy - 10.8)]
    I.line(scar, 1.2, 1.2, rgb=I.c("flesh", 1), taper=False)
    _stitches(I, scar, 2.0, 1.4, 0.5)
    I.poly_line(head, 1.0)
    return I


if __name__ == "__main__":
    from paint import row, upscale
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n/ink_hero.png"
    c = combat().render()
    m = map_down().render()
    c.save(out)
    upscale(c, 2).save(out.replace(".png", "_x2.png"))
    m.save(out.replace(".png", "_map.png"))
    upscale(m, 4).save(out.replace(".png", "_map_x4.png"))
    _ = row
