"""Protagonista en combate, de espaldas (64×110), como el grupo de Fear & Hunger.

Dibujado directamente a resolución final, pieza a pieza: piernas, brazos, espalda desnuda con la
incisión cosida y la pieza metálica, paneles de la bata abiertos, mangas, cuello y cráneo. La luz
viene de arriba (el foco del combate): hombros y coronilla claros, piernas hacia la sombra.

Reposo en 3 fotogramas: respira (hombros y cabeza suben 1 px) y se balancea sobre la pierna
de apoyo.
"""

from __future__ import annotations

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import palette  # noqa: E402,F401
from pen import Pen  # noqa: E402
from px2d import Part, compose, ramp  # noqa: E402

ramp("brief", ["#16171c", "#262830", "#3a3d45"])

W, H = 64, 110
ORIGIN = (32, 107)

THIGH = [(0.0, 3.8, 3.6), (0.3, 3.5, 3.3), (0.75, 2.7, 2.6), (1.0, 2.6, 2.6)]
# Pantorrilla vista desde atrás: los dos gemelos abultan arriba, el tendón de Aquiles adelgaza.
SHIN = [(0.0, 2.6, 2.6), (0.12, 3.1, 2.9), (0.3, 3.3, 3.0), (0.5, 2.5, 2.3), (0.75, 1.6, 1.5),
        (0.92, 1.3, 1.3), (1.0, 1.6, 1.6)]
UPPER_ARM = [(0.0, 2.6, 2.4), (0.4, 2.1, 2.0), (0.85, 1.6, 1.6), (1.0, 1.9, 1.9)]
FOREARM = [(0.0, 1.9, 1.9), (0.2, 2.3, 2.0), (0.6, 1.6, 1.5), (0.92, 1.1, 1.1), (1.0, 1.2, 1.2)]


def _leg(pen: Pen, hip, knee, ankle, outer: int):
    """Pierna desde atrás. `outer` = -1 si el lado exterior está a la izquierda."""
    pen.limb(hip, knee, THIGH, "skin", 2)
    pen.limb(knee, ankle, SHIN, "skin", 2)
    kx, ky = knee
    ax, ay = ankle
    # corva: pliegue en H con sombra
    pen.line([(kx - 1.4, ky - 0.4), (kx + 1.6, ky - 0.6)], "skin", 1, inside=True)
    pen.pxs([(kx - 2.2, ky - 2), (kx + 2.0, ky - 2)], "skin", 1, inside=True)
    # gemelos: luz arriba, sombra en la división
    pen.line([(kx - 2.4, ky + 2.4), (kx - 2.6, ky + 6), (kx - 1.4, ky + 9)], "skin", 3, inside=True)
    pen.line([(kx, ky + 2), (kx + 0.2, ky + 9)], "skin", 1, inside=True)
    # tendón de Aquiles y talón sucio
    pen.line([(ax, ay - 9), (ax, ay - 1)], "skin", 3, inside=True)
    pen.line([(ax + outer * 1.4, ay - 7), (ax + outer * 1.2, ay - 1)], "skin", 1, inside=True)
    heel = [(ax - 2.2, ay - 0.6), (ax + 2.2, ay - 0.6), (ax + 2.8, ay + 4.0), (ax + 1.6, ay + 8.0),
            (ax - 1.6, ay + 8.0), (ax - 2.8, ay + 4.0)]
    pen.poly(heel, "skin", 2)
    pen.shade([(ax - 3, ay + 4.6), (ax + 3, ay + 4.6), (ax + 3, ay + 9), (ax - 3, ay + 9)], mat="dirt", tone=1)
    pen.shade([(ax - 3, ay + 3.6), (ax + 3, ay + 3.6), (ax + 3, ay + 4.6), (ax - 3, ay + 4.6)], mat="dirt", tone=2,
              pattern="checker")
    pen.px(ax - 1, ay + 1, "skin", 3)
    # tobillo (maléolo) que asoma por el lado exterior
    pen.px(ax + outer * 2.2, ay - 1, "skin", 3)


def _arm(pen: Pen, sh, el, wr, outer: int):
    pen.limb(sh, el, UPPER_ARM, "skin", 2)
    pen.limb(el, wr, FOREARM, "skin", 2)
    ex, ey = el
    # codo desde atrás: olécranon huesudo con arrugas
    pen.pxs([(ex - 0.5, ey - 0.5), (ex + 0.5, ey - 0.5)], "skin", 3)
    pen.pxs([(ex - 1.5, ey + 0.5), (ex + 1.5, ey + 0.5), (ex - 0.5, ey + 1.5)], "skin", 1)
    # tríceps: arista de luz
    pen.line([(sh[0] + outer * 1.4, sh[1] + 3), (ex + outer * 1.2, ey - 4)], "skin", 3, inside=True)
    # cúbito: arista del antebrazo
    pen.line([(ex - outer * 0.4, ey + 3), (wr[0] - outer * 0.6, wr[1] - 2)], "skin", 3, inside=True)
    pen.line([(ex + outer * 1.6, ey + 3), (wr[0] + outer * 1.0, wr[1] - 3)], "skin", 1, inside=True)
    # mano colgando, vista de canto por detrás: dorso, nudillos y dedos separados
    hx, hy = wr
    hand = [(hx - 2.0, hy), (hx + 2.0, hy), (hx + 2.6, hy + 3.4), (hx + 2.4, hy + 7.0), (hx + 1.0, hy + 9.6),
            (hx - 0.6, hy + 9.4), (hx - 2.0, hy + 7.4), (hx - 2.8, hy + 3.6)]
    pen.poly(hand, "skin", 2)
    pen.line([(hx - 0.4, hy + 5.6), (hx - 0.6, hy + 9.0)], "skin", 1, inside=True)
    pen.line([(hx + 1.0, hy + 5.4), (hx + 1.0, hy + 8.6)], "skin", 1, inside=True)
    pen.pxs([(hx - 1.5, hy + 4.5), (hx + 0.5, hy + 4.5)], "skin", 3)       # nudillos
    pen.px(hx + outer * 2.0, hy + 2, "skin", 3)
    return wr


def parts(breath: int = 0, sway: int = 0) -> list[Part]:
    up = -breath
    def P():
        return Pen(Part(W, H))

    def U(dy: float):
        return Pen(Part(W, H), dy=dy)

    # --- piernas: apoya en la derecha, la izquierda algo doblada ---
    legs = P()
    _leg(legs, (27.0 + sway * 0.5, 58), (26.6, 77), (27.2, 98.4), outer=-1)
    _leg(legs, (37.0 + sway * 0.5, 58), (37.4, 76), (36.8, 99), outer=1)
    legs.part.rim(1, 0, 1, delta=-1, clip="skin")
    legs.shade([(0, 90), (64, 90), (64, 110), (0, 110)], delta=-1, clip="skin")
    legs.part.dither_edges("skin", 1, 2)
    legs.shade([(20, 58), (44, 58), (44, 66), (20, 66)], tone=1, clip="skin")   # sombra de la bata

    # --- espalda desnuda (lo que deja ver la bata abierta) ---
    back = U(up * 0.5)
    torso = [(27, 20.4), (37, 20.4), (43.4, 24), (44.4, 30), (42.4, 40), (40.8, 50), (41.4, 60), (22.6, 60),
             (23.2, 50), (21.6, 40), (19.6, 30), (20.6, 24)]
    back.poly(torso, "skin", 2)
    back.shade([(20, 20), (44, 20), (44, 26), (20, 27)], tone=3)
    back.line([(32, 22), (32.2, 34), (31.8, 52)], "skin", 1, inside=True)       # surco de la columna
    back.pxs([(32, 23), (32, 25)], "skin", 4)                                    # vértebras
    # omóplatos: aristas angulosas y sombra debajo
    back.line([(28.6, 25), (27.2, 32), (24.6, 36)], "skin", 1)
    back.line([(35.4, 25), (36.8, 32), (39.4, 36)], "skin", 1)
    back.line([(28.0, 25), (26.6, 31)], "skin", 3, inside=True)
    back.line([(36.2, 26), (37.6, 31)], "skin", 3, inside=True)
    back.shade([(24, 36.4), (40, 36.4), (39, 40), (25, 40)], tone=1, pattern="checker")
    # costillas apenas marcadas a los lados de la cintura
    for y in (41, 44, 47):
        back.line([(25.6, y), (28.4, y + 1)], "skin", 1, inside=True)
        back.line([(38.4, y), (35.6, y + 1)], "skin", 1, inside=True)
    # pieza metálica: placa octogonal atornillada, con un orificio y la piel inflamada alrededor
    cx, cy = 32, 31.0
    back.poly([(cx - 4.4, cy - 3.0), (cx + 4.4, cy - 3.0), (cx + 5.0, cy), (cx + 4.4, cy + 3.6), (cx - 4.4, cy + 3.6),
               (cx - 5.0, cy)], "flesh", 3)
    back.shade([(cx - 5, cy + 1.6), (cx + 5, cy + 1.6), (cx + 5, cy + 4), (cx - 5, cy + 4)], tone=2, clip="flesh")
    plate = [(cx - 3.4, cy - 2.4), (cx + 3.4, cy - 2.4), (cx + 3.4, cy + 3.0), (cx - 3.4, cy + 3.0)]
    back.poly(plate, "metal", 3)
    back.line([(cx - 3.4, cy - 2.4), (cx + 3.4, cy - 2.4)], "metal", 4)
    back.line([(cx - 3.4, cy - 2.4), (cx - 3.4, cy + 3.0)], "metal", 4)
    back.line([(cx - 3.4, cy + 3.0), (cx + 3.4, cy + 3.0)], "metal", 1)
    back.line([(cx + 3.4, cy - 1.4), (cx + 3.4, cy + 3.0)], "metal", 2)
    back.line([(cx, cy - 1.0), (cx, cy + 1.8)], "glass_dark", 0)         # ranura del puerto
    back.px(cx + 1, cy - 1.0, "metal", 2)
    back.pxs([(cx - 2.6, cy - 1.6), (cx + 2.6, cy - 1.6), (cx - 2.6, cy + 2.2), (cx + 2.6, cy + 2.2)], "metal", 0)
    back.pxs([(cx + 2.6, cy + 1), (cx - 1.6, cy + 3.0)], "rust", 2)
    # incisión cosida a lo largo de la columna, con puntadas cruzadas
    back.line([(32, 35.6), (31.6, 40), (32.2, 46), (31.8, 52)], "flesh", 1)
    back.line([(33, 36.6), (32.6, 41), (33.2, 47)], "flesh", 2, inside=True)
    for y in range(38, 52, 4):
        back.line([(31, y), (33, y + 1)], "thread", 1, inside=True)
    back.pxs([(31, 43), (31, 44), (33, 49)], "blood", 1, inside=True)
    # ropa interior oscura asomando por la abertura
    back.shade([(20, 52.6), (44, 52.6), (44, 60), (20, 60)], mat="brief", tone=1)
    back.shade([(20, 52.6), (44, 52.6), (44, 53.6), (20, 53.6)], tone=2, clip="brief")
    back.line([(32, 54), (32, 60)], "brief", 0)

    # --- paneles de la bata: caen de los hombros, abiertos por detrás ---
    gown = U(up * 0.5)
    left = [(29.0, 20.6), (31.4, 21.8), (28.6, 25), (26.2, 34), (25.2, 48), (26.4, 62.4), (25.8, 65.6), (23.4, 64.2),
            (21.0, 66.4), (18.8, 64.4), (18.2, 56), (19.0, 44), (19.8, 36), (19.4, 28), (20.4, 23.4), (24.4, 21.2)]
    right = [(64 - x, y) for x, y in left]
    right = [(x + (0.6 if y > 50 else 0), y) for x, y in right]
    gown.poly(left, "gown", 3)
    gown.poly(right, "gown", 3)
    # hombros a la luz; la tela cae en planos con pliegues angulosos
    gown.shade([(18, 20), (46, 20), (46, 25.4), (18, 26)], tone=4)
    gown.line([(23.4, 26), (22.6, 38), (21.4, 50), (21.6, 64)], "gown", 2, inside=True)
    gown.line([(24.6, 32), (23.6, 44), (23.4, 63)], "gown", 2, inside=True)
    gown.line([(40.4, 26), (41.2, 38), (42.4, 50), (42.2, 64)], "gown", 2, inside=True)
    gown.line([(39.4, 32), (40.4, 44), (40.6, 63)], "gown", 2, inside=True)
    gown.shade([(18, 50), (21.4, 50), (24.4, 60), (26.4, 67), (18, 67)], delta=-1)
    gown.shade([(39.6, 46), (46, 46), (46, 67), (37, 67), (40.6, 60)], delta=-1)
    gown.shade([(23.6, 56), (25.6, 56), (26.6, 67), (24.0, 67)], delta=-1)
    # canto interior de la abertura: la tela se dobla (filo claro a la izquierda, sombra a la derecha)
    gown.line([(31.0, 22), (28.2, 25), (25.8, 34), (24.8, 48), (26.0, 62)], "gown", 4, inside=True)
    gown.line([(33.0, 22), (35.8, 25), (38.2, 34), (39.2, 48), (38.2, 62)], "gown", 1, inside=True)
    # lazos: uno anudado en la nuca y otro suelto a media espalda
    gown.poly([(30.6, 20.6), (33.4, 20.6), (33.4, 22.6), (30.6, 22.6)], "gown", 3)
    gown.line([(31.4, 22.6), (31.0, 24.6)], "gown", 3)
    gown.line([(25.6, 38.6), (27.4, 40.6)], "gown", 3)
    # mugre y sangre seca en el bajo, desgarro en el panel derecho
    gown.shade([(19, 60), (27, 60), (27, 66), (19, 66)], mat="stain", tone=1, pattern="sparse")
    gown.pxs([(40, 52), (41, 53), (41, 54), (40, 55)], "blood", 1, inside=True)
    gown.erase([(43.2, 62.6), (44.6, 61.0), (45.6, 64.8)])
    gown.part.rim(0, 1, 1, tone=1, clip="gown")

    # --- brazos ---
    arms = U(up * 0.5)
    wl = _arm(arms, (18.6, 27), (16.0, 46), (16.8, 62), outer=-1)
    wr = _arm(arms, (45.4, 27), (48.0, 46), (47.2, 62), outer=1)
    arms.part.rim(1, 0, 1, delta=-1, clip="skin")
    arms.shade([(0, 60), (64, 60), (64, 80), (0, 80)], delta=-1, clip="skin")
    arms.part.dither_edges("skin", 1, 2)
    # muñeca izquierda: esparadrapo, la vía arrancada colgando y sangre que baja por la mano
    x, y = wl
    arms.poly([(x - 2.2, y - 3.4), (x + 2.0, y - 3.8), (x + 2.2, y - 1.4), (x - 2.2, y - 1.0)], "gown", 4)
    arms.px(x - 1.5, y - 2.5, "gown", 2)
    arms.line([(x - 0.4, y - 1.4), (x - 1.6, y + 4), (x - 0.6, y + 10), (x - 2.0, y + 15)], "tube", 1)
    arms.line([(x - 0.4, y - 1.4), (x - 1.6, y + 4)], "tube", 2)
    arms.pxs([(x - 2.0, y + 15), (x - 2.0, y + 16)], "blood", 2)
    arms.line([(x + 0.6, y - 1), (x + 1.0, y + 4), (x + 0.6, y + 7)], "blood", 1, inside=True)
    arms.px(x + 1.0, y + 12, "blood", 1)
    # muñeca derecha: pulsera de paciente con la tarjeta del nombre
    x, y = wr
    arms.poly([(x - 2.4, y - 3.4), (x + 2.4, y - 3.4), (x + 2.4, y - 1.4), (x - 2.4, y - 1.4)], "band", 2)
    arms.poly([(x + 0.2, y - 4.0), (x + 3.0, y - 4.0), (x + 3.0, y - 0.6), (x + 0.2, y - 0.6)], "band", 2)
    arms.line([(x + 1, y - 3), (x + 2, y - 3)], "band", 0)
    arms.px(x - 2, y - 3, "band", 1)

    # --- mangas ---
    sleeves = gown
    sl = [(19.6, 22.0), (24.4, 21.4), (23.4, 27.6), (21.4, 32.0), (15.6, 32.6), (14.8, 28.4), (16.4, 24.4)]
    sr = [(64 - x, y) for x, y in sl]
    for pts, d in ((sl, 1), (sr, -1)):
        sleeves.poly(pts, "gown", 3)
        x0 = min(p[0] for p in pts)
        x1 = max(p[0] for p in pts)
        sleeves.shade([(x0, 20), (x1, 20), (x1, 23.6), (x0, 25.0)], tone=4, clip="gown")
        sleeves.line([(x0 + 1.0, 31.4), (x1 - 2.6, 30.6)], "gown", 2, inside=True)
        mid = (x0 + x1) / 2
        sleeves.line([(mid + d * 0.6, 25), (mid - d * 0.8, 31)], "gown", 2, inside=True)

    # --- cuello y cráneo, algo caído hacia delante ---
    head = U(up)
    head.poly([(28.0, 14), (36.0, 14), (37.2, 22.4), (26.8, 22.4)], "skin", 2)
    head.line([(29.8, 16), (29.2, 22)], "skin", 3, inside=True)      # tendones
    head.line([(34.4, 16), (35.0, 22)], "skin", 1, inside=True)
    head.line([(32, 15), (32, 21)], "skin", 1, inside=True)
    head.px(32, 20.5, "skin", 4)                                     # vértebra prominente
    head.shade([(26, 21), (38, 21), (38, 23), (26, 23)], tone=1)
    skull = [(28.6, 2.6), (35.4, 2.6), (37.8, 4.6), (39.0, 8.0), (38.8, 12.4), (37.4, 15.4), (35.2, 17.0),
             (28.8, 17.0), (26.6, 15.4), (25.2, 12.4), (25.0, 8.0), (26.2, 4.6)]
    head.poly(skull, "scalp", 3)
    ear = [(24.2, 8.6), (25.6, 8.2), (26.0, 14.2), (24.8, 14.0), (23.8, 11.0)]
    head.poly(ear, "skin", 2)
    head.poly([(64 - x, y) for x, y in ear], "skin", 1)
    head.px(24.5, 10, "skin", 3)
    head.shade([(25, 2), (33, 2), (31.4, 6.4), (26.0, 8.0)], tone=4, clip="scalp")
    head.shade([(25, 11.4), (40, 11.4), (40, 18), (25, 18)], tone=2, clip="scalp")
    head.shade([(25, 14.6), (40, 14.6), (40, 18), (25, 18)], tone=1, clip="scalp")
    head.part.rim(1, 0, 2, delta=-1, clip="scalp")
    head.shade([(24, 4), (40, 4), (40, 15), (24, 15)], delta=-1, pattern="sparse", clip="scalp")  # pelo rapado
    # cicatriz: de la coronilla baja hacia la oreja derecha, cosida con hilo negro
    scar = [(30.6, 3.4), (33.0, 5.4), (35.6, 8.2), (36.4, 11.6), (35.8, 14.4)]
    head.line(scar, "blood", 1)
    head.line([(31.6, 3.6), (33.8, 5.4), (36.4, 8.2)], "flesh", 2, inside=True)
    for (a, b) in ((31.0, 5.6), (34.0, 8.0), (35.4, 12.0)):
        head.line([(a, b), (a + 1.6, b - 1.4)], "thread", 1, inside=True)
    head.px(36, 15, "blood", 1, inside=True)

    return [legs.part, back.part, arms.part, gown.part, head.part]


IDLE = [(0, 0), (1, 0), (1, 1)]


def frames() -> list[Image.Image]:
    return [compose(parts(b, s), (W, H)) for b, s in IDLE]


if __name__ == "__main__":
    from px2d import sheet, upscale
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n/proto_battle.png"
    upscale(sheet([frames()], bg=(40, 38, 42), gap=4), 4).save(out)
