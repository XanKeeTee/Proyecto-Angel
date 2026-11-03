"""Protagonista en el mapa, tercera muestra: mirando abajo (112×160), reposo y paso ×4, método `vec`.

Hombre delgado y demacrado de ~7,5 cabezas, hombros caídos, contrapposto (el peso en la pierna
izquierda: esa cadera sube y ese hombro baja), la cabeza algo ladeada. Bata con peso: pliegues de
tracción desde los hombros, escote en pico, bajo irregular. Cicatriz cosida en el cráneo, pulsera en la
muñeca derecha, vía arrancada en el dorso de la mano izquierda, pies sucios.
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

W, H = 112, 160
K = 6
LIGHT = (-0.8, -0.55)
LZ = 0.38


def pose(step_l=0.0, step_r=0.0, lift_l=0.0, lift_r=0.0, swing_l=0.0, swing_r=0.0, bob=0.0) -> dict:
    """De frente. Pierna/brazo «r» = derecho del personaje (izquierda de la pantalla)."""
    def leg(x_hip, y_hip, x_ank, step, lift):
        return [(x_hip, y_hip + bob), (x_hip - 0.5, y_hip + 13 + bob * 0.6),
                (x_ank - 0.4, 113 - lift * 0.6 + step * 0.25), (x_ank, 127 - lift * 0.8 + step * 0.3),
                (x_ank, 141 - lift + step * 0.4)]
    return {
        "bob": bob,
        "head": (54.6, 22.4 + bob), "tilt": 0.06,
        "leg_r": leg(49.6, 86, 48.4, step_r, lift_r), "lift_r": lift_r, "step_r": step_r,
        "leg_l": leg(62.0, 85, 62.4, step_l, lift_l), "lift_l": lift_l, "step_l": step_l,
        "arm_r": [(40.5, 44.5 + bob), (38.0, 57 + bob), (37.0 - swing_r * 0.2, 70 + bob + swing_r * 0.2),
                  (37.6 - swing_r * 0.5, 82 + bob + swing_r * 0.4), (38.6 - swing_r * 0.7, 93 + bob + swing_r * 0.6)],
        "arm_l": [(71.5, 45.6 + bob), (74.2, 58 + bob), (75.6 + swing_l * 0.2, 71 + bob + swing_l * 0.2),
                  (75.2 + swing_l * 0.5, 83 + bob + swing_l * 0.4), (74.2 + swing_l * 0.7, 94 + bob + swing_l * 0.6)],
    }


IDLE = pose()
WALK = [pose(step_l=8, step_r=-7, swing_l=-3, swing_r=3, bob=1),
        pose(step_l=1, lift_r=6.5, bob=-0.8),
        pose(step_l=-7, step_r=7, swing_l=3, swing_r=-3, bob=1),
        pose(step_r=1, lift_l=6.5, bob=-0.8)]


def draw(p: dict) -> Fig:
    f = Fig(W, H, K, LIGHT, LZ)
    b = p["bob"]
    # --- piel: piernas, pies, brazos, manos, cuello, cabeza: una sola capa continua ---
    parts = {}
    for leg in ("leg_r", "leg_l"):
        parts[leg] = f.shape(limb_outline(p[leg], [(6.2, 6.0), (5.6, 5.2), (3.9, 3.9), (4.5, 3.9), (2.4, 2.4)]))
        f.fill(parts[leg], "skin", 0.28)
        ax, ay = p[leg][-1]
        sg = -1 if leg == "leg_r" else 1
        lift = p["lift_" + leg[-1]]
        toe = ay + 9.0 - lift * 0.5 + p["step_" + leg[-1]] * 0.25
        foot = [(ax - 2.8, ay - 1), (ax + 2.8, ay - 1), (ax + 4.0 + sg * 0.8, toe - 2.6), (ax + 3.4 + sg * 0.8, toe),
                (ax - 3.4 + sg * 0.8, toe), (ax - 4.0 + sg * 0.8, toe - 2.6)]
        parts["foot" + leg] = f.shape(foot)
        f.fill(parts["foot" + leg], "skin", 0.32)
    for arm in ("arm_r", "arm_l"):
        parts[arm] = f.shape(limb_outline(p[arm], [(4.6, 4.4), (3.6, 3.4), (2.9, 3.0), (3.2, 2.9), (2.2, 2.2)]))
        f.fill(parts[arm], "skin", 0.28)
        wx, wy = p[arm][-1]
        sg = -1 if arm == "arm_r" else 1
        hand = [(wx - 2.2, wy - 0.5), (wx + 2.2, wy - 0.5), (wx + 2.8 + sg * 0.3, wy + 4.5), (wx + 1.8, wy + 10.5),
                (wx - 0.4 * sg, wy + 12.4), (wx - 2.2, wy + 10), (wx - 3.0 - sg * 0.3, wy + 4.5)]
        parts["hand" + arm] = f.shape(hand)
        f.fill(parts["hand" + arm], "skin", 0.32)
    hx, hy = p["head"]
    neck = [(hx - 4.4, hy + 6), (hx + 4.0, hy + 6), (hx + 5.6, hy + 17.6 - b), (hx - 6.2, hy + 17.6 - b)]
    f.fill(f.shape(neck), "skin", 0.34)
    ct, st = math.cos(p["tilt"]), math.sin(p["tilt"])

    def R(pts):
        return [(hx + x * ct - y * st, hy + x * st + y * ct) for x, y in pts]

    skull = R([(0, -11.2), (5.6, -10.4), (8.2, -6.6), (8.6, -1.6), (8.0, 2.8), (6.6, 6.6), (4.2, 9.4), (0, 10.6),
               (-4.2, 9.4), (-6.6, 6.6), (-8.0, 2.8), (-8.6, -1.6), (-8.2, -6.6), (-5.6, -10.4)])
    for sd in (-1, 1):
        f.fill(f.shape(R([(sd * 8.0, -2.4), (sd * 10.0, -1.6), (sd * 10.2, 2.6), (sd * 8.6, 4.6), (sd * 7.6, 1.6)])), "skin", 0.34)
    head_m = f.shape(skull)
    f.fill(head_m, "skin", 0.44)
    scalp = f.shape(R([(-9, -12), (9, -12), (9, -4.6), (5, -6.0), (0, -6.4), (-5, -6.0), (-9, -4.6)]))
    f.recolor((scalp > 0.5) & (head_m > 0.5), "scalp")
    # --- bata: escote en pico, mangas cortas, cae con peso hasta encima de la rodilla ---
    sr, sl = p["arm_r"][0], p["arm_l"][0]
    gown = [(hx - 6.4, 37.4 + b), (hx - 2.6, 42 + b), C(hx - 0.4, 46.6 + b), (hx + 2.2, 42 + b), (hx + 6.0, 37.6 + b),
            (sl[0] - 2, sl[1] - 5.6), (sl[0] + 3.6, sl[1] - 2.4), (sl[0] + 6.6, sl[1] + 5), C(sl[0] + 7.0, sl[1] + 11.4),
            (sl[0] + 1.6, sl[1] + 12.4), (sl[0] - 1.0, sl[1] + 14), (68.4, 70 + b), (71.4, 86), (75.0, 101), (72.4, 104.6), (68.6, 102.8),
            (64.6, 105.4), (60.0, 103.0), (55.4, 105.8), (51.0, 103.2), (46.4, 105.4), (42.2, 103.0), (38.6, 104.8),
            (36.6, 100), (40.4, 86), (43.6, 70 + b), (sr[0] + 1.0, sr[1] + 14), (sr[0] - 1.6, sr[1] + 12.4),
            C(sr[0] - 7.0, sr[1] + 11.4), (sr[0] - 6.6, sr[1] + 5), (sr[0] - 3.6, sr[1] - 2.4), (sr[0] + 2, sr[1] - 5.6)]
    gm = f.shape(gown, 0.9)
    f.fill(gm, "gown", 0.42)
    # piel del escote
    vee = f.shape([(hx - 6.0, 37.8 + b), (hx + 5.6, 38.0 + b), (hx + 1.8, 42.4 + b), C(hx - 0.4, 46.2 + b), (hx - 2.4, 42.4 + b)])
    f.fill(vee, "skin", 0.36)

    # ============================== pintura ==============================
    skin = f.of("skin", "scalp")
    f.mass(skin, soft=4.0, hard=0.08, fill=0.02, edge=0.1, clip=["skin", "scalp"])
    for k_ in ("leg_r", "leg_l", "arm_r", "arm_l"):
        f.mass(parts[k_] > 0.5, soft=2.2, hard=0.24, fill=0.04, edge=0.08, clip="skin")
    for leg in ("leg_r", "leg_l"):
        hip, mid, knee, calf, ank = p[leg]
        f.paint(f.ellipse((knee[0] - 0.4, knee[1] - 1.2), 2.0, 1.8), 0.22, 0.3, clip="skin")          # rótula
        f.crease([(knee[0] - 2.6, knee[1] + 1.6), (knee[0] + 2.6, knee[1] + 1.4)], 0.22, 0.6, 0.3, clip="skin")
        f.crease([lerp(knee, ank, 0.2), lerp(knee, ank, 0.85)], -0.16, 0.8, 0.4, clip="skin")         # espinilla
        f.mass(parts["foot" + leg] > 0.5, soft=1.4, hard=0.22, fill=0.06, edge=0.08, clip="skin")
        f.stain((ank[0], ank[1] + 8), 4.6, "dirt", int(ank[0]), val=0.4, stretch=(1.2, 0.7), ring=0.04)
        for dx in (-1.6, 0.0, 1.6):
            f.crease([(ank[0] + dx, ank[1] + 6.4), (ank[0] + dx * 1.2, ank[1] + 9)], 0.2, 0.4, 0.2, clip=["skin", "dirt"])
    f.stain(lerp(p["leg_r"][2], p["leg_r"][4], 0.4), 1.6, "bruise", 3, val=0.32, stretch=(0.8, 1.4), ring=0.0, clip="skin")
    for arm in ("arm_r", "arm_l"):
        sh, a1, el, a3, wr = p[arm]
        f.crease([(el[0] - 2, el[1] + 0.6), (el[0] + 2, el[1] + 0.4)], 0.2, 0.5, 0.3, clip="skin")
        f.crease([lerp(el, wr, 0.2), lerp(el, wr, 0.9)], -0.14, 0.7, 0.4, clip="skin")
        f.mass(parts["hand" + arm] > 0.5, soft=1.2, hard=0.22, fill=0.06, edge=0.1, clip="skin")
        f.crease([(wr[0] - 1.6, wr[1] + 6), (wr[0] - 1.0, wr[1] + 11)], 0.24, 0.4, 0.2, clip="skin")
        f.crease([(wr[0] + 0.6, wr[1] + 6), (wr[0] + 1.0, wr[1] + 11)], 0.24, 0.4, 0.2, clip="skin")
    # cuello, clavículas, cara
    f.crease([(hx - 3, hy + 9), (hx - 4.6, hy + 16)], -0.14, 0.7, 0.4, clip="skin")
    f.crease([(hx + 3, hy + 9), (hx + 4.4, hy + 16)], 0.14, 0.7, 0.4, clip="skin")
    f.crease([(hx - 5.4, 38.6 + b), (hx - 1.6, 40.4 + b)], -0.2, 0.6, 0.3, clip="skin")
    f.crease([(hx + 1.4, 40.4 + b), (hx + 5.0, 38.8 + b)], -0.16, 0.6, 0.3, clip="skin")
    f.paint(f.poly([(hx - 7, hy + 9), (hx + 7, hy + 9), (hx + 6, hy + 13), (hx - 6, hy + 13)]), -0.25, 0.8, clip="skin")
    f.mass(head_m > 0.5, soft=3.2, hard=0.3, fill=0.06, edge=0.1, clip=["skin", "scalp"])
    eyes = R([(-3.4, -1.2), (3.2, -1.2)])
    for ex, ey in eyes:
        f.paint(f.ellipse((ex, ey), 2.6, 1.9), -0.42, 0.35, clip="skin")                           # cuenca hundida
        f.crease([(ex - 2.4, ey - 2.4), (ex + 2.4, ey - 2.6)], -0.2, 0.6, 0.3, clip="skin")         # arco de la ceja
    nose = R([(-0.2, -1.6), (0.0, 3.4)])
    f.crease(nose, -0.2, 0.7, 0.3, clip="skin")
    f.paint(f.ellipse(R([(0.4, 4.4)])[0], 1.8, 0.8), -0.3, 0.3, clip="skin")
    for sd in (-1, 1):
        f.paint(f.ellipse(R([(sd * 5.2, 2.8)])[0], 1.6, 1.2), 0.18, 0.3, clip="skin")              # pómulo
        f.paint(f.ellipse(R([(sd * 4.6, 5.6)])[0], 1.4, 1.8), -0.2, 0.4, clip="skin")              # mejilla chupada
    f.crease(R([(-2.4, 6.8), (0, 7.2), (2.4, 6.8)]), 0.36, 0.6, 0.2, clip="skin")                   # boca seca
    f.pores(0.07, 0.5, 0.3, 4, clip="scalp")
    f.noise(0.06, 3.0, 5, clip=["skin", "scalp"])
    f.pores(0.04, 0.5, 0.08, 6, clip="skin")
    scar = R([(-7.6, -3.6), (-5.4, -7.8), (-1.4, -10.2), (3.4, -10.6)])
    f.stain(lerp(scar[0], scar[-1], 0.5), 2.4, "bruise", 7, val=0.36, stretch=(1.6, 0.7), ring=0.0, clip="scalp")
    f.crease(scar, 0.24, 0.7, 0.2, ridge=0.16, ridge_off=(0, 0.8))
    # bata
    f.mass(f.of("gown"), soft=5.0, hard=0.28, fill=0.08, edge=0.14, clip="gown")
    for fl in ([(sr[0] + 1, sr[1] - 2), (45, 62), (43, 82), (41, 102)], [(sl[0] - 1, sl[1] - 2), (67, 62), (69, 82), (71, 102)],
               [(hx - 3, 47 + b), (50, 66), (49, 84), (48, 104)], [(hx + 2.6, 47 + b), (59, 68), (60, 86), (62, 104)],
               [(sr[0] + 3, sr[1] + 6), (48, 52)], [(sl[0] - 3, sl[1] + 6), (64, 53)], [(55, 80), (55, 104)],
               [(sr[0] - 4, sr[1] + 4), (sr[0] - 5, sr[1] + 11)], [(sl[0] + 4, sl[1] + 4), (sl[0] + 5, sl[1] + 11)]):
        f.crease(fl, 0.3, 0.9, 0.6, ridge=0.2, ridge_off=(-1.0, -0.2), clip="gown")
    f.crease([(hx - 6.0, 37.8 + b), (hx - 2.4, 42.4 + b), (hx - 0.4, 46.2 + b), (hx + 1.8, 42.4 + b), (hx + 5.6, 38.0 + b)],
             0.24, 0.8, 0.3, clip="gown")
    f.paint(f.poly([(30, 96), (82, 96), (82, 110), (30, 110)]), -0.14, 2.0, clip="gown")
    f.weave(0.03, 0.5, clip="gown")
    f.noise(0.08, 6.0, 8, clip="gown")
    f.stain((44, 101), 4.0, "dirt", 9, val=0.38, stretch=(1.6, 0.6), ring=0.04, clip="gown")
    f.stain((66, 74), 2.6, "dry", 10, val=0.42, stretch=(0.7, 1.6), ring=0.08, clip="gown")
    f.stain((69, 52), 2.4, "dirt", 11, val=0.45, stretch=(1.0, 1.0), ring=0.04, clip="gown")
    # sombra de la bata sobre los muslos y de la cabeza sobre el pecho
    f.paint(f.poly([(30, 102), (82, 102), (82, 110), (30, 110)]), -0.24, 1.6, clip="skin")
    # pulsera (muñeca derecha) y vía arrancada (mano izquierda)
    wr = p["arm_r"][4]
    a3 = p["arm_r"][3]
    band = f.shape(limb_outline([lerp(wr, a3, 0.05), lerp(wr, a3, 0.3)], [(3.2, 3.2), (3.4, 3.4)]))
    f.fill(band, "band", 0.62)
    f.mass(band > 0.5, soft=0.8, hard=0.25, fill=0.1, edge=0.1, clip="band")
    wl = p["arm_l"][4]
    tp = (wl[0] + 0.2, wl[1] + 3.6)
    f.fill(f.shape([(tp[0] - 2.2, tp[1] - 1.6), (tp[0] + 2.0, tp[1] - 1.8), (tp[0] + 2.2, tp[1] + 1.6), (tp[0] - 2.0, tp[1] + 1.8)]),
           "tape", 0.62, inside=True)
    f.fill(f.stroke([(tp[0] + 0.6, tp[1]), (tp[0] + 2.6, tp[1] + 5), (tp[0] + 1.6, tp[1] + 10), (tp[0] + 3.0, tp[1] + 15)], 1.0),
           "tube", 0.6)
    f.stain((tp[0] - 0.4, tp[1] + 3.4), 1.6, "blood", 12, val=0.42, stretch=(0.6, 2.4), ring=0.06, drip=1.0, clip="skin", wet=0.2)
    f.rim((26, 34, 48), (0.8, -0.5), 1.4, 1.0)

    def touch(o: np.ndarray) -> None:
        # ojos: un punto oscuro en el fondo de la cuenca y el brillo húmedo; puntos de la cicatriz
        for (ex, ey) in eyes:
            x, y = int(round(ex)), int(round(ey))
            o[y, x, :3] = (24, 14, 18)
            o[y, x - 1, :3] = (44, 30, 32)
        x, y = int(round(eyes[0][0])), int(round(eyes[0][1]))
        o[y - 1, x - 1, :3] = (150, 132, 116)
        for i in range(4):
            q = lerp(scar[0], scar[-1], (i + 0.5) / 4)
            o[int(q[1]) - 1, int(q[0]), :3] = (24, 16, 20)
            o[int(q[1]) + 1, int(q[0]) + 1, :3] = (24, 16, 20)
    f.touch(touch)
    return f


def frames() -> list[Image.Image]:
    return [draw(p).render(pal.HERO, dither=8.0) for p in [IDLE] + WALK]


if __name__ == "__main__":
    from paint import row, upscale
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n/v3_map.png"
    fr = frames()
    sil = [draw(IDLE).silhouette()]
    upscale(row(fr + sil, gap=6), 3).save(out)
