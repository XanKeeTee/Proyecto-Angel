"""El enfermero transfigurado a tinta y color plano (cuarta muestra, prueba de estilo estática).

300×440 (diseñado en una rejilla de 520×640), dibujado a ×3 sin antialias y reducido por bloques. Silueta nudosa y quebrada, encorvado, la
joroba por encima de la cabeza colgante, brazos hasta las rodillas. Todo con línea de grosor variable,
manchas de sombra de borde duro, tramas en las sombras profundas y manchas planas de sangre y mugre.
Luz fría desde la izquierda; filo granate a contraluz por la derecha.
"""

from __future__ import annotations

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ink import INK, Ink, edges, jag, lerp  # noqa: E402
from palette_ink import PAL  # noqa: E402

W, H = 300, 440          # tamaño en combate: un hombre alto, no un jefe
K = 4
VIEW = (0.72, 40, 60)    # se dibuja en una rejilla de diseño de 520×640 y se reduce a 300×440


def _mx(pts):
    return sum(p[0] for p in pts) / len(pts)


def limb(I: Ink, joints, widths, mat: str, seed: int, contour: float = 1.8, deep: bool = True,
         rim: bool = True) -> list:
    """Miembro anguloso: color plano, mancha de sombra de borde nervioso, trama en lo más hondo,
    filo de luz, filo granate a contraluz y contorno de tinta."""
    rnd = random.Random(seed)
    L, R = edges(joints, widths)
    outline = L + R[::-1]
    I.fill(outline, I.c(mat, 2))
    sh, li = (L, R) if _mx(L) > _mx(R) else (R, L)
    inner = [lerp(s, l, 0.5 + rnd.uniform(-0.12, 0.12)) for s, l in zip(sh, li)]
    band = sh + inner[::-1]
    I.clip_fill(outline, band, I.c(mat, 1))
    if deep:
        dp = [lerp(s, l, 0.28 + rnd.uniform(-0.06, 0.06)) for s, l in zip(sh, li)]
        I.clip_fill(outline, sh + dp[::-1], I.c(mat, 0))
        I.ctx.save()
        I._path(outline)
        I.ctx.clip()
        I.hatch(sh + dp[::-1], math.atan2(joints[-1][1] - joints[0][1], joints[-1][0] - joints[0][0]) + 0.8, 3.4, 1.0,
                rgb=I.c(mat, 1), seed=seed)
        I.ctx.restore()
    lt = [lerp(l, s, 0.14 + rnd.uniform(-0.04, 0.04)) for s, l in zip(sh, li)]
    I.clip_fill(outline, li + lt[::-1], I.c(mat, 3) if len(PAL[mat]) > 3 else I.c(mat, 2))
    if rim:
        rr = [lerp(s, l, 0.06) for s, l in zip(sh, li)]
        I.clip_fill(outline, sh + rr[::-1], PAL["rim"][0])
    I.poly_line(outline, contour)
    return outline


def body_shadow(I: Ink, clip, pts, mat: str, tone: int = 1, hatch: float | None = None, seed: int = 0):
    I.clip_fill(clip, pts, I.c(mat, tone))
    if hatch is not None:
        I.ctx.save()
        I._path(clip)
        I.ctx.clip()
        I.hatch(pts, hatch, 3.4, 1.0, rgb=I.c(mat, 1), seed=seed)
        I.ctx.restore()


def fold(I: Ink, clip, pts, mat: str, side: float = 1.0, wsh: float = 4.0, w: float = 1.4, seed: int = 0):
    """Pliegue a tinta: la línea quebrada y, a un lado, su cuña de sombra de borde duro."""
    rnd = random.Random(seed)
    wedge = list(pts)
    back = []
    n = len(pts)
    for i, p in enumerate(pts[::-1]):
        t = 1 - i / max(1, n - 1)
        a = pts[max(0, n - 1 - i - 1)]
        b = pts[min(n - 1, n - 1 - i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1
        o = wsh * math.sin(math.pi * t) * rnd.uniform(0.7, 1.2) * side
        back.append((p[0] - dy / ln * o, p[1] + dx / ln * o))
    I.clip_fill(clip, wedge + back, I.c(mat, 1))
    I.line(pts, w, w * 0.4)


def draw() -> Ink:
    I = Ink(W, H, K, PAL, VIEW)
    rnd = random.Random(1)
    # ===================================== piernas =====================================
    for side, hip, knee, ank, seed in ((-1, (226, 408), (202, 522), (214, 612), 10), (1, (300, 406), (326, 524), (312, 612), 20)):
        hem = lerp(knee, ank, 0.45)
        # espinilla desnuda, gris, con la tibia marcada
        limb(I, [knee, lerp(knee, ank, 0.35), lerp(knee, ank, 0.75), ank], [(15, 15), (13, 12), (9, 8.5), (8.5, 8.5)], "nskin", seed)
        I.line([lerp(knee, ank, 0.5), (ank[0] - 2, ank[1] - 8)], 1.0, 0.4)
        # pie largo, huesudo, de dedos separados
        sg = side
        fx, fy = ank
        foot = [(fx - 10, fy - 4), (fx + 10, fy - 4), (fx + 17 + sg * 6, fy + 16), (fx + 17 + sg * 7, fy + 26),
                (fx - 17 + sg * 6, fy + 26), (fx - 17 + sg * 5, fy + 16)]
        I.fill(foot, I.c("nskin", 2))
        I.clip_fill(foot, [(fx + 2, fy - 4), (fx + 30, fy - 4), (fx + 30, fy + 30), (fx + 4, fy + 30)], I.c("nskin", 1))
        I.poly_line(foot, 1.8)
        for k in range(5):
            x = fx - 13 + k * 6.4 + sg * 6
            I.line([(x, fy + 13), (x + sg * 0.5, fy + 26)], 1.1, 0.6)
            I.fill([(x + 0.8, fy + 21), (x + 4.4, fy + 21), (x + 4.2, fy + 26), (x + 1.0, fy + 26)], I.c("nail", 0))
        for dx in (-5, 4):
            I.line([(fx + dx, fy), (fx + dx * 1.8 + sg * 3, fy + 14)], 0.9, 0.3)
        I.splat((fx + sg * 2, fy + 24), 9, I.c("dirt", 0), seed + 3, spikes=13, clip=foot)
        # pantalón de enfermería, ancho, roto a media espinilla en jirones
        L, R = edges([hip, lerp(hip, knee, 0.5), knee, hem], [(27, 27), (24, 23), (19, 19), (18.5, 18.5)])
        rag = [R[-1]]
        for k in range(1, 9):
            p = lerp(R[-1], L[-1], k / 9)
            rag.append((p[0], p[1] + (rnd.uniform(6, 18) if k % 2 else rnd.uniform(-2, 4))))
        rag.append(L[-1])
        trou = L + rag[::-1][1:-1][::-1][::-1] + R[::-1]
        trou = L[:-1] + [L[-1]] + rag[::-1] + R[::-1]
        I.fill(trou, I.c("uniform", 2))
        body_shadow(I, trou, [(knee[0] + sg * 4, hip[1]), (hip[0] + 40, hip[1]), (hem[0] + 40, hem[1] + 30),
                              (hem[0] + 2, hem[1] + 30), (knee[0] + 2, knee[1])] if sg > 0 else
                    [(hip[0] + 8, hip[1]), (hip[0] + 40, hip[1]), (hem[0] + 30, hem[1] + 30), (hem[0] + 6, hem[1] + 30),
                     (knee[0] + 6, knee[1])], "uniform", 1, hatch=None)
        # rodilla rasgada: la rótula gris por el roto
        kx, ky = knee
        tear = [(kx - 11, ky - 6), (kx - 3, ky - 13), (kx + 6, ky - 9), (kx + 12, ky - 1), (kx + 7, ky + 9), (kx - 4, ky + 11),
                (kx - 12, ky + 4)]
        I.fill(tear, I.c("nskin", 2))
        I.clip_fill(tear, [(kx + 1, ky - 14), (kx + 14, ky - 14), (kx + 14, ky + 12), (kx + 3, ky + 12)], I.c("nskin", 1))
        I.fill([(kx - 6, ky - 6), (kx + 1, ky - 9), (kx + 5, ky - 3), (kx + 1, ky + 3), (kx - 5, ky + 1)], I.c("nskin", 3))
        I.poly_line(tear, 1.4)
        for k in range(6):
            p = tear[k]
            I.line([p, (p[0] + rnd.uniform(-3, 3), p[1] + rnd.uniform(2, 6))], 0.8, 0.3)
        # pliegues de la tela: tirones de la rodilla doblada
        for f_pts, sd in (([(hip[0] - sg * 8, hip[1] + 18), (kx - sg * 10, ky - 38), (kx - sg * 3, ky - 16)], sg),
                          ([(hip[0] + sg * 14, hip[1] + 26), (kx + sg * 12, ky - 22), (kx + sg * 6, ky - 10)], -sg),
                          ([(kx - 10, ky + 14), (hem[0] - 6, hem[1] - 6)], 1), ([(kx + 9, ky + 14), (hem[0] + 9, hem[1] - 2)], 1)):
            fold(I, trou, f_pts, "uniform", sd, 5.0, 1.4, seed + 7)
        I.line(jag((hip[0] + sg * 24, hip[1] + 10), (kx + sg * 17, ky - 4), 6, 0.8, seed), 0.9, 0.9)    # costura lateral
        I.splat((hip[0] - sg * 2, hip[1] + 60), 13, I.c("dry", 1), seed + 4, spikes=14, drips=3, clip=trou)
        I.splat((hem[0], hem[1] - 4), 15, I.c("dirt", 1), seed + 5, spikes=15, clip=trou)
        I.poly_line(trou, 1.8)
    # ===================================== tronco =====================================
    tunic = [(196, 136), (222, 108), (244, 82), (270, 72), (298, 80), (322, 108), (346, 128), (366, 140), (372, 160),
             (366, 190), (352, 230), (342, 278), (336, 318), (340, 362), (348, 398), (354, 428), (340, 422), (330, 436),
             (318, 424), (304, 440), (290, 426), (276, 442), (262, 427), (248, 440), (234, 425), (220, 438), (206, 424),
             (194, 434), (184, 420), (190, 386), (196, 352), (194, 316), (184, 278), (172, 238), (160, 196), (152, 166),
             (160, 146), (176, 140)]
    I.fill(tunic, I.c("uniform", 2))
    # sombra del costado derecho (borde nervioso) y bajo el pecho
    body_shadow(I, tunic, jag((326, 110), (316, 180), 5, 4, 2) + jag((316, 180), (300, 300), 6, 6, 3) +
                jag((300, 300), (306, 440), 6, 5, 4) + [(380, 440), (380, 100)], "uniform", 1)
    body_shadow(I, tunic, [(334, 150), (372, 150), (372, 440), (330, 440), (328, 300), (338, 220)], "uniform", 0, hatch=2.2, seed=5)
    body_shadow(I, tunic, [(152, 150), (176, 146), (186, 200), (198, 270), (190, 300), (172, 240), (156, 190)], "uniform", 3)
    body_shadow(I, tunic, [(182, 392), (350, 392), (356, 440), (180, 440)], "uniform", 1)
    # joroba: la tela tirante sobre las vértebras
    for i, (x, y) in enumerate(((262, 86), (272, 98), (280, 112))):
        v = [(x - 9, y + 2), (x - 2, y - 4), (x + 8, y - 1), (x + 9, y + 6), (x, y + 8)]
        I.fill(v, I.c("uniform", 3))
        I.line([(x - 9, y + 4), (x, y + 9), (x + 9, y + 6)], 1.2, 0.5)
    fold(I, tunic, [(232, 98), (250, 92), (266, 108)], "uniform", 1, 4, 1.2, 31)
    fold(I, tunic, [(300, 86), (312, 104), (318, 132)], "uniform", -1, 4, 1.2, 32)
    # pliegues de peso desde los hombros y en la cintura
    for k, (pts, sd) in enumerate((([(176, 160), (190, 210), (196, 260), (204, 300)], 1), ([(350, 162), (334, 214), (326, 262)], -1),
                                   ([(200, 320), (214, 360), (212, 410)], 1), ([(318, 326), (312, 370), (318, 420)], 1),
                                   ([(246, 336), (252, 380), (248, 424)], 1), ([(282, 340), (288, 384), (284, 426)], -1),
                                   ([(214, 300), (236, 312), (262, 306)], 1), ([(290, 304), (310, 316), (326, 308)], -1))):
        fold(I, tunic, pts, "uniform", sd, 5.5, 1.5, 40 + k)
    for k, (pts, sd) in enumerate((([(226, 150), (232, 196), (226, 236)], 1), ([(170, 250), (180, 300), (188, 340)], 1),
                                   ([(336, 240), (326, 290)], -1), ([(228, 380), (236, 424)], 1), ([(262, 384), (266, 430)], -1),
                                   ([(300, 380), (296, 428)], 1), ([(208, 260), (222, 276), (244, 272)], 1))):
        fold(I, tunic, pts, "uniform", sd, 4.5, 1.3, 60 + k)
    # costuras con puntadas
    for seam in ([(188, 152), (176, 190), (186, 250)], [(354, 150), (346, 200), (336, 260)], [(194, 340), (346, 340)]):
        I.line(seam, 0.8, 0.8)
        for a, b in zip(seam, seam[1:]):
            for t in range(1, 8):
                p = lerp(a, b, t / 8)
                I.fill([(p[0] - 0.6, p[1] - 1.6), (p[0] + 0.6, p[1] - 1.6), (p[0] + 0.6, p[1] + 1.6), (p[0] - 0.6, p[1] + 1.6)], INK)
    # desgarro del pecho: esternón, costillas y la piel tirante
    rip = [(262, 152), (276, 146), (288, 160), (300, 158), (304, 178), (316, 190), (310, 214), (318, 236), (306, 254),
           (300, 276), (286, 268), (270, 280), (264, 258), (250, 246), (256, 222), (246, 204), (256, 186), (250, 168)]
    I.fill(rip, I.c("nskin", 2))
    I.clip_fill(rip, [(286, 140), (330, 140), (330, 290), (290, 290)], I.c("nskin", 1))
    I.line([(282, 160), (279, 200), (281, 240), (279, 270)], 2.0, 1.0)                           # esternón
    I.line([(276, 162), (273, 200), (275, 240)], 1.0, 0.6, rgb=I.c("nskin", 3))
    for i, y in enumerate(range(170, 268, 13)):
        for sd in (-1, 1):
            x0 = 280 + sd * 4
            rib = [(x0, y), (x0 + sd * 12, y + 3), (x0 + sd * 26, y + 1)]
            band = [(x0, y - 3), (x0 + sd * 12, y), (x0 + sd * 26, y - 2), (x0 + sd * 26, y + 1), (x0 + sd * 12, y + 3), (x0, y)]
            I.clip_fill(rip, band, I.c("nskin", 3))
            I.ctx.save()
            I._path(rip)
            I.ctx.clip()
            I.line(rib, 1.6, 0.6)
            I.fill([(x0, y + 1), (x0 + sd * 12, y + 4), (x0 + sd * 24, y + 3), (x0 + sd * 12, y + 7)], I.c("nskin", 0))
            I.ctx.restore()
    for v in ([(262, 190), (258, 210), (264, 228)], [(296, 220), (300, 240), (296, 258)]):
        I.line(v, 0.9, 0.5, rgb=PAL["vein"][1])
    I.poly_line(rip, 1.6)
    for k in range(0, len(rip), 2):                                                                # hilachas
        p = rip[k]
        I.line([p, (p[0] + rnd.uniform(-4, 4), p[1] + rnd.uniform(3, 8))], 0.8, 0.3)
    # bolsillo y tarjeta de identificación
    pocket = [(310, 288), (334, 284), (336, 312), (312, 316)]
    I.fill(pocket, I.c("uniform", 1))
    I.poly_line(pocket, 1.2)
    card = [(314, 276), (330, 274), (332, 298), (316, 300)]
    I.fill(card, I.c("porcelain", 2))
    I.fill([(316, 278), (322, 278), (322, 286), (316, 286)], I.c("liquid", 1))
    for y in (281, 284, 290, 293):
        I.line([(324 if y < 288 else 317, y), (330, y)], 0.6, 0.6)
    I.poly_line(card, 1.0)
    # sangre: la que empapa el vientre (seca, de borde duro) y la fresca
    I.splat((276, 318), 24, I.c("dry", 1), 60, spikes=17, drips=4, clip=tunic)
    I.splat((272, 312), 13, I.c("blood", 1), 61, spikes=13, drips=2, clip=tunic)
    I.splat((210, 210), 9, I.c("dry", 1), 62, spikes=11, drips=2, clip=tunic)
    I.splat((330, 400), 12, I.c("dry", 0), 63, spikes=12, clip=tunic)
    I.splat((200, 410), 14, I.c("dirt", 1), 64, spikes=14, clip=tunic)
    I.stipple(tunic, 0.006, 1.0, I.c("uniform", 1), 65)
    rim_pts = jag((368, 150), (352, 230), 4, 2, 70) + jag((352, 230), (340, 330), 4, 2, 71) + [(334, 330), (346, 230), (362, 150)]
    I.clip_fill(tunic, rim_pts, PAL["rim"][0])
    I.poly_line(tunic, 2.2)
    # ===================================== brazo de la jeringa (derecha de la pantalla) =====
    sh, el, wr = (356, 146), (410, 282), (394, 398)
    sx, top = wr[0] - 4, wr[1] - 30
    bot = top + 158
    # jeringa por detrás de la mano: émbolo, alas, cilindro de cristal con el líquido y la escala
    I.fill([(sx - 4, top - 66), (sx + 4, top - 66), (sx + 4, top - 8), (sx - 4, top - 8)], I.c("metal", 2))
    I.fill([(sx - 1.6, top - 66), (sx + 0.2, top - 66), (sx + 0.2, top - 8), (sx - 1.6, top - 8)], I.c("metal", 3))
    I.poly_line([(sx - 4, top - 66), (sx + 4, top - 66), (sx + 4, top - 8), (sx - 4, top - 8)], 1.2)
    for pts in ([(sx - 15, top - 78), (sx + 15, top - 78), (sx + 15, top - 66), (sx - 15, top - 66)],
                [(sx - 18, top - 9), (sx + 18, top - 9), (sx + 18, top), (sx - 18, top)]):
        I.fill(pts, I.c("metal", 2))
        I.fill([pts[0], pts[1], (pts[1][0], pts[1][1] + 3), (pts[0][0], pts[0][1] + 3)], I.c("metal", 3))
        I.poly_line(pts, 1.3)
    barrel = [(sx - 13, top), (sx + 13, top), (sx + 13, bot - 6), (sx + 8, bot), (sx - 8, bot), (sx - 13, bot - 6)]
    I.fill(barrel, I.c("glass", 1))
    I.fill([(sx - 12, top + 2), (sx + 12, top + 2), (sx + 12, top + 14), (sx - 12, top + 14)], I.c("nail", 0))    # goma
    I.fill([(sx - 12, top + 40), (sx + 12, top + 40), (sx + 12, bot - 6), (sx + 7, bot - 1), (sx - 7, bot - 1),
            (sx - 12, bot - 6)], I.c("liquid", 2))
    I.fill([(sx - 12, top + 52), (sx + 12, top + 46), (sx + 12, bot - 6), (sx + 7, bot - 1), (sx - 7, bot - 1),
            (sx - 12, bot - 6)], I.c("liquid", 1))
    I.fill([(sx - 9, top + 3), (sx - 6, top + 3), (sx - 6, bot - 6), (sx - 9, bot - 9)], I.c("glass", 2))     # reflejo plano
    I.line([(sx + 10, top + 4), (sx + 10, bot - 8)], 1.0, 1.0, rgb=I.c("glass", 0), taper=False)
    for i, y in enumerate(range(int(top) + 22, int(bot) - 8, 8)):
        I.line([(sx + 1, y), (sx + (12 if i % 2 == 0 else 7), y)], 1.0, 1.0, rgb=I.c("porcelain", 3), taper=False)
    for bx, by in ((sx - 2, top + 70), (sx + 4, top + 94), (sx - 3, top + 120)):
        I.fill([(bx, by), (bx + 2, by), (bx + 2, by + 2), (bx, by + 2)], I.c("glass", 2))
    I.poly_line(barrel, 1.6)
    I.fill([(sx - 5, bot), (sx + 5, bot), (sx + 3, bot + 12), (sx - 3, bot + 12)], I.c("metal", 2))
    I.poly_line([(sx - 5, bot), (sx + 5, bot), (sx + 3, bot + 12), (sx - 3, bot + 12)], 1.2)
    I.line([(sx, bot + 12), (sx + 3, bot + 92)], 1.8, 0.8, rgb=I.c("metal", 3))
    I.line([(sx + 1.2, bot + 12), (sx + 4, bot + 92)], 0.7, 0.3)
    I.fill([(sx + 2, bot + 94), (sx + 5, bot + 94), (sx + 4, bot + 102)], I.c("liquid", 2))
    # brazo largo, consumido
    arm = limb(I, [sh, lerp(sh, el, 0.18), lerp(sh, el, 0.5), lerp(sh, el, 0.85), el, lerp(el, wr, 0.2), lerp(el, wr, 0.6), wr],
               [(21, 19), (22, 17), (14, 13), (11.5, 11.5), (15, 14), (16, 14), (12, 11), (10, 10)], "nskin", 80)
    ex, ey = el
    elbow = [(ex - 8, ey - 9), (ex + 3, ey - 13), (ex + 14, ey - 4), (ex + 10, ey + 8), (ex - 3, ey + 7)]
    I.fill(elbow, I.c("nskin", 3))
    I.poly_line(elbow, 1.0)
    for kk in (4, 9):
        I.line([(ex - 9, ey + kk), (ex + 2, ey + kk + 2), (ex + 12, ey + kk - 1)], 1.0, 0.4)
    I.line([lerp(sh, el, 0.3), (lerp(sh, el, 0.3)[0] - 14, lerp(sh, el, 0.3)[1] + 8)], 1.4, 0.4)       # deltoides
    I.line([lerp(el, wr, 0.15), lerp(el, wr, 0.9)], 1.2, 0.4)                                         # tendón
    I.line([lerp(el, wr, 0.25), (lerp(el, wr, 0.55)[0] + 7, lerp(el, wr, 0.55)[1]), lerp(el, wr, 0.85)], 0.9, 0.3,
           rgb=PAL["vein"][1])
    I.line([lerp(sh, el, 0.45), (lerp(sh, el, 0.7)[0] + 4, lerp(sh, el, 0.7)[1]), lerp(sh, el, 0.9)], 0.9, 0.3,
           rgb=PAL["vein"][1])
    # mano: dorso detrás del cilindro, cuatro dedos largos en diagonal, uñas negras
    hx, hy = wr
    back = [(sx + 8, hy - 18), (sx + 30, hy - 12), (sx + 31, hy + 22), (sx + 18, hy + 38), (sx + 7, hy + 30)]
    I.fill(back, I.c("nskin", 2))
    I.clip_fill(back, [(sx + 20, hy - 20), (sx + 40, hy - 20), (sx + 40, hy + 40), (sx + 16, hy + 40)], I.c("nskin", 1))
    I.poly_line(back, 1.6)
    for i in range(4):
        y = hy - 8 + i * 13
        k0, k1, k2 = (sx + 22, y), (sx - 1, y + 5), (sx - 15, y + 10)
        fl = limb(I, [k0, k1, k2], [(5.0, 5.0), (4.2, 4.2), (3.2, 3.2)], "nskin", 90 + i, contour=1.4, deep=False, rim=False)
        I.fill([(k0[0] - 3, k0[1] - 5), (k0[0] + 3, k0[1] - 5), (k0[0] + 4, k0[1] + 1), (k0[0] - 3, k0[1] + 1)], I.c("nskin", 3))
        I.line([(k1[0] - 1, k1[1] - 4), (k1[0] + 1, k1[1] + 4)], 1.0, 0.5)                            # nudillo
        I.fill([(k2[0] - 4, k2[1] - 3), (k2[0] + 1, k2[1] - 3.4), (k2[0] + 1.4, k2[1] + 3), (k2[0] - 4, k2[1] + 3.2)], I.c("nail", 0))
        _ = fl
    thumb = limb(I, [(sx + 18, hy - 22), (sx + 4, hy - 26), (sx - 10, hy - 20)], [(5.4, 5.4), (4.6, 4.6), (3.4, 3.4)], "nskin",
                 99, contour=1.4, deep=False, rim=False)
    _ = (arm, thumb)
    # manga rota sobre el hombro
    sl = [(sh[0] - 22, sh[1] - 12), (sh[0] + 14, sh[1] - 22), (sh[0] + 30, sh[1] + 2), (sh[0] + 26, sh[1] + 34),
          (sh[0] + 18, sh[1] + 28), (sh[0] + 12, sh[1] + 42), (sh[0] + 4, sh[1] + 30), (sh[0] - 6, sh[1] + 38),
          (sh[0] - 14, sh[1] + 24), (sh[0] - 24, sh[1] + 6)]
    I.fill(sl, I.c("uniform", 2))
    body_shadow(I, sl, [(sh[0] + 6, sh[1] - 30), (sh[0] + 40, sh[1] - 30), (sh[0] + 40, sh[1] + 50), (sh[0] + 4, sh[1] + 50)],
                "uniform", 1)
    fold(I, sl, [(sh[0] - 8, sh[1] - 6), (sh[0] - 2, sh[1] + 20)], "uniform", 1, 4, 1.2, 101)
    I.splat((sh[0] + 10, sh[1] + 10), 7, I.c("dry", 1), 102, clip=sl)
    I.poly_line(sl, 1.8)
    # ===================================== cuello y cabeza =====================================
    neck = [(262, 120), (282, 118), (262, 170), (238, 176)]
    I.fill(neck, I.c("nskin", 1))
    I.line([(276, 122), (256, 168)], 1.4, 0.6)
    I.line([(266, 124), (246, 170)], 1.0, 0.4)
    I.poly_line(neck, 1.6)
    cx, cy, tilt = 222, 214, -0.42
    ct, st = math.cos(tilt), math.sin(tilt)
    HS = 1.18

    def Rt(pts):
        return [(cx + (x * ct - y * st) * HS, cy + (x * st + y * ct) * HS) for x, y in pts]

    skull = Rt([(-6, -54), (12, -52), (26, -42), (33, -24), (34, -4), (31, 14), (24, 30), (14, 42), (2, 47), (-10, 44),
                (-20, 34), (-28, 18), (-33, 0), (-34, -20), (-28, -38), (-18, -50)])
    I.fill(skull, I.c("nskin", 2))
    body_shadow(I, skull, Rt([(8, -60), (40, -60), (40, 50), (10, 50), (18, 20), (20, -20)]), "nskin", 1)
    body_shadow(I, skull, Rt([(-20, -56), (8, -58), (-4, -44), (-24, -36)]), "nskin", 3)
    for sd in (-1, 1):
        ear = Rt([(sd * 32, -14), (sd * 40, -12), (sd * 42, 4), (sd * 36, 12), (sd * 31, 4)])
        I.fill(ear, I.c("nskin", 1 if sd > 0 else 2))
        I.poly_line(ear, 1.4)
        I.line(Rt([(sd * 36, -8), (sd * 38, 4)]), 1.0, 0.4)
    for p0, p1 in (((-14, -50), (-24, -30)), ((2, -54), (-2, -36)), ((16, -50), (24, -32))):                    # pelo ralo
        I.line(Rt([p0, lerp(p0, p1, 0.5), p1]), 1.4, 0.3)
    for v in (Rt([(-24, -40), (-28, -26), (-24, -16)]), Rt([(20, -44), (26, -32)])):
        I.line(v, 1.0, 0.4, rgb=PAL["vein"][1])
    # máscara de porcelana: plano a la luz, plano en sombra, ceja tallada, cuencas, grietas, trozo saltado
    mask = Rt([(-30, -28), (-16, -34), (0, -35), (16, -34), (30, -28), (33, -12), (28, 4), (16, 13), (0, 18), (-16, 13),
               (-28, 4), (-33, -12)])
    I.fill(mask, I.c("porcelain", 2))
    body_shadow(I, mask, Rt([(2, -36), (36, -36), (36, 20), (0, 20), (4, -4), (1, -20)]), "porcelain", 1)
    body_shadow(I, mask, Rt([(-30, -30), (-6, -34), (-20, -27), (-31, -16)]), "porcelain", 3)
    I.line(Rt([(0, -26), (1, -6), (0, 16)]), 1.4, 0.6)                                                         # caballete
    I.line(Rt([(-26, -20), (-14, -24), (-4, -20)]), 1.6, 0.5)
    I.line(Rt([(4, -20), (14, -24), (26, -20)]), 1.6, 0.5)
    eye_l = Rt([(-23, -16), (-14, -20), (-5, -17), (-4, -8), (-12, -4), (-21, -7)])
    eye_r = Rt([(5, -17), (14, -21), (23, -16), (24, -7), (14, -3), (6, -8)])
    I.fill(eye_l, I.c("liquid", 0))
    I.poly_line(eye_l, 1.6)
    I.fill(eye_r, I.c("liquid", 1))
    ball = Rt([(8, -13), (14, -17), (21, -14), (21, -8), (14, -6), (8, -9)])
    I.fill(ball, I.c("eye", 1))
    I.fill(Rt([(14, -16), (19, -14), (19, -9), (14, -8)]), I.c("eye", 2))
    I.fill(Rt([(11, -14), (15, -15), (16, -10), (12, -9)]), I.c("liquid", 1))                                  # iris
    I.fill(Rt([(12.6, -13), (14.6, -13.4), (14.8, -11), (12.8, -10.6)]), INK)                                   # pupila
    I.fill(Rt([(13, -14.6), (14.2, -14.6), (14.2, -13.6), (13, -13.6)]), I.c("eye", 2))                       # brillo húmedo
    for vv in (((20, -12), (17, -11)), ((9, -10), (11, -11)), ((20, -9), (18, -8.4))):
        I.line(Rt(list(vv)), 0.7, 0.4, rgb=I.c("blood", 2))
    I.poly_line(eye_r, 1.6)
    I.line(Rt([(6, -4), (14, -2), (22, -5)]), 1.0, 0.4, rgb=I.c("blood", 1))                                   # lagrimal húmedo
    for st0, n, sd in (((-8, -10), 7, 5), ((-2, -34), 5, 6), ((22, -30), 5, 7), ((20, 6), 4, 8), ((-26, -2), 4, 9)):
        rr = random.Random(sd)
        x, y = st0
        ang = rr.uniform(0, 2 * math.pi)
        pts = [(x, y)]
        for _ in range(n):
            ang += rr.uniform(-0.8, 0.8)
            x, y = x + math.cos(ang) * rr.uniform(3, 6), y + math.sin(ang) * rr.uniform(3, 6)
            pts.append((x, y))
        P = Rt(pts)
        I.ctx.save()
        I._path(mask)
        I.ctx.clip()
        I.line([(p[0] + 0.8, p[1] + 0.8) for p in P], 1.2, 0.6, rgb=I.c("porcelain", 3))
        I.line(P, 1.3, 0.4)
        I.ctx.restore()
    chip = Rt([(-33, -4), (-25, -6), (-21, 2), (-28, 8)])
    I.fill(chip, I.c("flesh", 1))
    I.fill(Rt([(-30, -3), (-25, -4), (-24, 0)]), I.c("flesh", 3))
    I.poly_line(chip, 1.2)
    I.poly_line(mask, 1.8)
    I.line(Rt([(-33, -16), (-40, -14)]), 2.0, 2.0, taper=False)
    I.line(Rt([(33, -16), (40, -14)]), 2.0, 2.0, taper=False)
    # mascarilla quirúrgica cosida a la piel: pliegues, sangre de la boca, cada punto tirando de la piel
    cloth = Rt([(-28, 4), (-16, 12), (0, 17), (16, 12), (28, 4), (27, 16), (20, 30), (10, 39), (0, 42), (-10, 39),
                (-20, 30), (-27, 16)])
    I.fill(cloth, I.c("mask_cloth", 2))
    body_shadow(I, cloth, Rt([(4, 0), (34, 0), (34, 46), (2, 46), (6, 28)]), "mask_cloth", 1)
    for y in (18, 25, 32):
        fold(I, cloth, Rt([(-24, y - 4), (-8, y + 1), (8, y + 1), (24, y - 4)]), "mask_cloth", 1, 2.6, 1.3, int(y))
    I.splat(Rt([(2, 28)])[0], 9, I.c("blood", 1), 110, spikes=12, clip=cloth)
    I.splat(Rt([(1, 27)])[0], 5, I.c("blood", 2), 111, spikes=9, clip=cloth)
    I.poly_line(cloth, 1.6)
    edge = Rt([(-30, 2), (-29, 16), (-22, 32), (-11, 43), (0, 46), (11, 43), (22, 32), (29, 16), (30, 2)])
    for a, b in zip(edge, edge[1:]):
        for t in (0.25, 0.75):
            q = lerp(a, b, t)
            dx, dy = b[0] - a[0], b[1] - a[1]
            ln = math.hypot(dx, dy)
            nx, ny = -dy / ln, dx / ln
            I.line([(q[0] - nx * 5, q[1] - ny * 5), (q[0] + nx * 5, q[1] + ny * 5)], 1.6, 1.0, taper=False)       # punto
            for o in (-1, 1):                                                                                    # piel fruncida
                I.line([(q[0] + nx * 5 + dx / ln * o * 2, q[1] + ny * 5 + dy / ln * o * 2),
                        (q[0] + nx * 9 + dx / ln * o * 4, q[1] + ny * 9 + dy / ln * o * 4)], 0.8, 0.3)
    I.splat(Rt([(2, 46)])[0], 4, I.c("blood", 1), 112, spikes=8, drips=2, drip_len=2.0)
    I.poly_line(skull, 2.2)
    # ===================================== tubos al pecho =====================================
    for path in ([(318, 96), (322, 124), (314, 150), (302, 166), (294, 176)],
                 [(344, 120), (346, 150), (334, 180), (318, 204), (306, 214)],
                 [(286, 82), (300, 104), (304, 132), (300, 152)]):
        L, R = edges(path, [(3.4, 3.4)] * len(path))
        tube = L + R[::-1]
        I.fill(tube, I.c("liquid", 2))
        I.clip_fill(tube, [(p[0] - 1.6, p[1]) for p in L] + [(p[0] - 0.4, p[1]) for p in L[::-1]], I.c("glass", 1))
        I.poly_line(tube, 1.4)
        ex, ey = path[-1]
        pucker = [(ex - 7, ey - 2), (ex, ey - 8), (ex + 7, ey - 1), (ex + 2, ey + 6), (ex - 5, ey + 5)]
        I.fill(pucker, I.c("flesh", 1))
        I.poly_line(pucker, 1.0)
        for ang in (0.3, 1.5, 2.7, 3.9, 5.1):
            I.line([(ex + math.cos(ang) * 7, ey + math.sin(ang) * 6), (ex + math.cos(ang) * 13, ey + math.sin(ang) * 11)], 0.9, 0.3)
        I.fill([(ex - 1, ey + 5), (ex + 1.6, ey + 5), (ex + 1, ey + 20), (ex - 0.4, ey + 22)], I.c("blood", 1))
    # ===================================== brazo de instrumental (izquierda de la pantalla) =====
    sh, el, wr = (168, 152), (118, 296), (136, 414)
    ux, uy = (wr[0] - el[0]), (wr[1] - el[1])
    ln = math.hypot(ux, uy)
    ux, uy = ux / ln, uy / ln
    nx, ny = -uy, ux
    out = (nx, ny) if nx < 0 else (-nx, -ny)
    # sierra de hueso por el canto exterior: hoja con dientes en zigzag, óxido y sangre
    s0 = lerp(el, wr, 0.15)
    s0 = (s0[0] + out[0] * 12, s0[1] + out[1] * 12)
    s1 = (s0[0] + ux * 196, s0[1] + uy * 196)
    blade = [s0, s1, (s1[0] + out[0] * 24, s1[1] + out[1] * 24)]
    nteeth = 38
    for t in range(nteeth, -1, -1):
        p = lerp((s0[0] + out[0] * 18, s0[1] + out[1] * 18), (s1[0] + out[0] * 24, s1[1] + out[1] * 24), t / nteeth)
        blade.append(p)
        if t:
            q = lerp((s0[0] + out[0] * 18, s0[1] + out[1] * 18), (s1[0] + out[0] * 24, s1[1] + out[1] * 24), (t - 0.5) / nteeth)
            blade.append((q[0] + out[0] * 5 - ux * 1.5, q[1] + out[1] * 5 - uy * 1.5))
    I.fill(blade, I.c("metal", 2))
    I.clip_fill(blade, [s0, s1, (s1[0] + out[0] * 8, s1[1] + out[1] * 8), (s0[0] + out[0] * 6, s0[1] + out[1] * 6)], I.c("metal", 3))
    I.clip_fill(blade, [(s0[0] + out[0] * 14, s0[1] + out[1] * 14), (s1[0] + out[0] * 18, s1[1] + out[1] * 18),
                        (s1[0] + out[0] * 40, s1[1] + out[1] * 40), (s0[0] + out[0] * 40, s0[1] + out[1] * 40)], I.c("metal", 1))
    for t, r_ in ((0.3, 6), (0.55, 8), (0.8, 5)):
        c_ = lerp(lerp(s0, s1, t), (s1[0] + out[0] * 20, s1[1] + out[1] * 20), 0.0)
        c_ = (c_[0] + out[0] * 12, c_[1] + out[1] * 12)
        I.splat(c_, r_, I.c("rust", 1), int(t * 99), spikes=9, clip=blade)
    I.splat((s1[0] + out[0] * 14 - ux * 14, s1[1] + out[1] * 14 - uy * 14), 9, I.c("blood", 1), 120, spikes=11, drips=2, clip=blade)
    for t in (0.2, 0.5, 0.8):                                                                       # remaches
        q = lerp(s0, s1, t)
        q = (q[0] + out[0] * 6, q[1] + out[1] * 6)
        I.fill([(q[0] - 2, q[1] - 2), (q[0] + 2, q[1] - 2), (q[0] + 2, q[1] + 2), (q[0] - 2, q[1] + 2)], I.c("metal", 0))
    I.poly_line(blade, 1.6)
    # bisturíes en abanico, como dedos abiertos: hoja con bisel claro, lomo de tinta, sangre en la punta
    for k, (ang, bl) in enumerate(((-0.66, 100), (-0.34, 124), (-0.04, 132), (0.26, 118), (0.54, 92))):
        d = (ux * math.cos(ang) - uy * math.sin(ang), ux * math.sin(ang) + uy * math.cos(ang))
        bn = (-d[1], d[0])
        base = (wr[0] + ux * 14 + bn[0] * (k - 2) * 4, wr[1] + uy * 14 + bn[1] * (k - 2) * 4)
        tip = (base[0] + d[0] * bl, base[1] + d[1] * bl)
        cv = 1 if ang < 0 else -1
        belly = (base[0] + d[0] * bl * 0.62 + bn[0] * 8 * cv, base[1] + d[1] * bl * 0.62 + bn[1] * 8 * cv)
        spine = (base[0] + d[0] * bl * 0.8 - bn[0] * 2 * cv, base[1] + d[1] * bl * 0.8 - bn[1] * 2 * cv)
        pts = [(base[0] - bn[0] * 3.4 * cv, base[1] - bn[1] * 3.4 * cv), spine, tip, belly,
               (base[0] + bn[0] * 5 * cv, base[1] + bn[1] * 5 * cv)]
        I.fill(pts, I.c("metal", 2))
        bevel = [belly, tip, lerp(tip, spine, 0.15), lerp(belly, spine, 0.4), lerp(pts[-1], pts[0], 0.4), pts[-1]]
        I.fill(bevel, I.c("metal", 3))
        I.fill([pts[0], spine, lerp(spine, belly, 0.25), lerp(pts[0], pts[-1], 0.3)], I.c("metal", 1))
        tipb = [tip, lerp(tip, belly, 0.3), lerp(tip, spine, 0.35)]
        I.fill(tipb, I.c("blood", 1))
        I.splat(lerp(base, tip, 0.7), 3.4, I.c("blood", 1), 130 + k, spikes=7, clip=pts)
        I.poly_line(pts, 1.4)
        I.line([lerp(base, tip, 0.1), lerp(base, tip, 0.85)], 0.7, 0.3)
        I.fill([tip, (tip[0] + 1.4, tip[1] + 1), (tip[0] + 0.6, tip[1] + 8), (tip[0] - 0.4, tip[1] + 9)], I.c("blood", 1))
    # el brazo
    limb(I, [sh, lerp(sh, el, 0.18), lerp(sh, el, 0.5), lerp(sh, el, 0.85), el, lerp(el, wr, 0.2), lerp(el, wr, 0.6), wr],
         [(22, 20), (23, 18), (15, 13), (12, 12), (16, 14), (19, 18), (19, 18), (18, 18)], "nskin", 140)
    ex, ey = el
    elbow = [(ex - 12, ey - 6), (ex - 2, ey - 14), (ex + 9, ey - 8), (ex + 6, ey + 6), (ex - 6, ey + 8)]
    I.fill(elbow, I.c("nskin", 3))
    I.poly_line(elbow, 1.0)
    for kk in (5, 10):
        I.line([(ex - 12, ey + kk), (ex - 1, ey + kk + 2), (ex + 9, ey + kk - 1)], 1.0, 0.4)
    I.line([lerp(sh, el, 0.3), (lerp(sh, el, 0.3)[0] + 14, lerp(sh, el, 0.3)[1] + 8)], 1.4, 0.4)
    I.line([lerp(sh, el, 0.5), lerp(sh, el, 0.75), (lerp(sh, el, 0.85)[0] - 3, lerp(sh, el, 0.85)[1])], 0.9, 0.3,
           rgb=PAL["vein"][1])
    # carne que rebosa en la muñeca y se funde con el metal
    stump = [(wr[0] + nx * 21 - ux * 8, wr[1] + ny * 21 - uy * 8), (wr[0] - nx * 21 - ux * 8, wr[1] - ny * 21 - uy * 8),
             (wr[0] - nx * 16 + ux * 18, wr[1] - ny * 16 + uy * 18), (wr[0] - nx * 4 + ux * 22, wr[1] - ny * 4 + uy * 22),
             (wr[0] + nx * 10 + ux * 21, wr[1] + ny * 10 + uy * 21), (wr[0] + nx * 17 + ux * 17, wr[1] + ny * 17 + uy * 17)]
    I.fill(stump, I.c("flesh", 2))
    I.clip_fill(stump, [(wr[0] - nx * 30, wr[1] - ny * 30), (wr[0] + nx * 2, wr[1] + ny * 2),
                        (wr[0] + nx * 2 + ux * 40, wr[1] + ny * 2 + uy * 40), (wr[0] - nx * 30 + ux * 40, wr[1] - ny * 30 + uy * 40)],
                I.c("flesh", 1))
    I.hatch(stump, 0.4, 2.6, 0.6, seed=150)
    I.fill([(wr[0] + nx * 8, wr[1] + ny * 8), (wr[0] + nx * 3, wr[1] + ny * 3 + 3), (wr[0] + nx * 10 + 2, wr[1] + 6)], I.c("flesh", 3))
    I.poly_line(stump, 1.6)
    # abrazaderas atornilladas y la línea de grapas donde la carne se une al metal
    for t in (0.38, 0.72):
        q = lerp(el, wr, t)
        hw = 21
        band = [(q[0] + nx * hw - ux * 4, q[1] + ny * hw - uy * 4), (q[0] - nx * hw - ux * 4, q[1] - ny * hw - uy * 4),
                (q[0] - nx * hw + ux * 5, q[1] - ny * hw + uy * 5), (q[0] + nx * hw + ux * 5, q[1] + ny * hw + uy * 5)]
        I.fill(band, I.c("metal", 1))
        I.fill([band[0], band[1], lerp(band[1], band[2], 0.35), lerp(band[0], band[3], 0.35)], I.c("metal", 3))
        I.poly_line(band, 1.4)
        for o in (-15, 15):
            b_ = (q[0] + nx * o, q[1] + ny * o)
            I.fill([(b_[0] - 2.4, b_[1] - 2.4), (b_[0] + 2.4, b_[1] - 2.4), (b_[0] + 2.4, b_[1] + 2.4), (b_[0] - 2.4, b_[1] + 2.4)],
                   I.c("metal", 3))
            I.line([(b_[0] - 2, b_[1]), (b_[0] + 2, b_[1])], 0.8, 0.8, taper=False)
        for o in (-1, 1):                                                                            # carne fruncida
            I.line([(q[0] + nx * 19 + ux * o * 8, q[1] + ny * 19 + uy * o * 8),
                    (q[0] - nx * 19 + ux * o * 8, q[1] - ny * 19 + uy * o * 8)], 1.0, 0.3)
    seam0 = (lerp(el, wr, 0.08)[0] + out[0] * 13, lerp(el, wr, 0.08)[1] + out[1] * 13)
    seam1 = (lerp(el, wr, 0.98)[0] + out[0] * 13, lerp(el, wr, 0.98)[1] + out[1] * 13)
    I.line([seam0, seam1], 2.0, 1.2, rgb=I.c("flesh", 1))
    I.line([seam0, seam1], 0.8, 0.8)
    for i in range(14):
        q = lerp(seam0, seam1, (i + 0.5) / 14)
        I.line([(q[0] - out[0] * 4, q[1] - out[1] * 4), (q[0] + out[0] * 4, q[1] + out[1] * 4)], 1.8, 1.8,
               rgb=I.c("metal", 3), taper=False)
        I.line([(q[0] + out[0] * 4.4, q[1] + out[1] * 4.4), (q[0] + out[0] * 4.4 + ux * 2, q[1] + out[1] * 4.4 + uy * 2)], 1.0,
               1.0, taper=False)
    for t in (0.2, 0.45, 0.8):
        I.splat(lerp(seam0, seam1, t), 4, I.c("blood", 1), int(t * 300), spikes=8, drips=1)
    # manga rota
    sl = [(sh[0] + 22, sh[1] - 12), (sh[0] - 14, sh[1] - 22), (sh[0] - 30, sh[1] + 2), (sh[0] - 26, sh[1] + 34),
          (sh[0] - 18, sh[1] + 28), (sh[0] - 12, sh[1] + 42), (sh[0] - 4, sh[1] + 30), (sh[0] + 6, sh[1] + 38),
          (sh[0] + 14, sh[1] + 24), (sh[0] + 24, sh[1] + 6)]
    I.fill(sl, I.c("uniform", 2))
    body_shadow(I, sl, [(sh[0] + 4, sh[1] - 30), (sh[0] + 40, sh[1] - 30), (sh[0] + 40, sh[1] + 50), (sh[0] + 2, sh[1] + 50)],
                "uniform", 1)
    body_shadow(I, sl, [(sh[0] - 34, sh[1] - 20), (sh[0] - 6, sh[1] - 24), (sh[0] - 22, sh[1] + 4)], "uniform", 3)
    fold(I, sl, [(sh[0] + 8, sh[1] - 6), (sh[0] + 2, sh[1] + 22)], "uniform", -1, 4, 1.2, 160)
    I.splat((sh[0] - 8, sh[1] + 16), 8, I.c("dry", 1), 161, clip=sl)
    I.poly_line(sl, 1.8)
    return I


def frame():
    return draw().render()


if __name__ == "__main__":
    from paint import upscale
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n/ink_nurse.png"
    im = frame()
    im.save(out)
    upscale(im, 2).save(out.replace(".png", "_x2.png"))
