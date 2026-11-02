"""El enfermero transfigurado [PROPUESTA]: sprites de combate por capas y sprite del mapa.

Concepto (docs/lore/prologo.md, brief de la tercera ronda): hombre alto y demacrado con el
uniforme blanco de enfermería roto y manchado; piel gris azulada con venas oscuras; la
mascarilla quirúrgica cosida a la cara y una máscara pálida de porcelana agrietada encajada
sobre los ojos; columna arqueada y demasiado larga, con apófisis que rompen la piel; el
antebrazo derecho fundido con instrumental (bisturíes en lugar de dedos y una sierra de hueso
que sale de la carne); una jeringa grande en la mano izquierda; tubos con líquido oscuro que
le entran en el pecho y, entre los omóplatos, la misma pieza metálica que el protagonista.

Se modela con volúmenes (enemy_render.py, sobre las primitivas de pxrender.py), con un
esqueleto de huesos rígidos y cinemática directa. Las texturas se calculan en las coordenadas
del modelo en reposo, así que se mueven con la carne.

Uso (desde la raíz del repo):
    python -I tools/art/enemy_enfermero.py [--only combat|map] [--procs N] [--anims idle,attack]
                                            [--preview DIR]

Genera en assets/sprites/enemies/enfermero/:
  - combate: <capa>.png y <capa>_n.png (normales) para cada capa de LAYERS, todas con la
    misma rejilla (una fila, los fotogramas de todas las animaciones seguidos);
  - mapa: map.png/map_n.png (andar arrastrando los pies y reposo, 8 orientaciones) y
    corpse.png/corpse_n.png (cadáver: entero y sin el brazo derecho).
Y escribe las claves `enemy_enfermero` y `enemy_enfermero_map` de tools/art/sprite_meta.json.
"""

from __future__ import annotations

import json
import math
import os
import sys
import time
from dataclasses import dataclass, field
from multiprocessing import Pool
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

import enemy_render as er  # noqa: E402
from enemy_render import (  # noqa: E402
    bump, fbm, grad_of, material, mix, normalize, pdata, rgb, ridge, smoothstep, surface, tag, vnoise,
)
from pxrender import basis_from_y, box, capsule, cylinder, ellipsoid, limb, sphere  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = "assets/sprites/enemies/enfermero"

# --- combate: fotograma, capas y animaciones ----------------------------------------------

FRAME_W, FRAME_H = 256, 300
ORIGIN = (124, 282)                     # píxel de los pies
PITCH = 0.16                            # cámara algo picada (rad)
YAW = 0.3                               # girado: el brazo instrumental se adelanta

PARTS = ["head", "arm_l", "arm_r", "leg_l", "leg_r"]
STUMPS = ["stump_" + p for p in PARTS]
# De atrás adelante. "shadow" es la sombra en el suelo (opcional para el juego).
ORDER = ["shadow", "leg_l", "leg_r", "body"] + STUMPS + ["head", "arm_l", "arm_r"]
LAYERS = [layer for layer in ORDER if layer != "shadow"]

# nombre -> (fotogramas, fps, bucle)
ANIMS: dict[str, tuple[int, float, bool]] = {
    "idle": (12, 8.0, True),
    "windup": (8, 12.0, False),
    "attack": (8, 16.0, False),
    "attack_syringe": (10, 14.0, False),
    "hit": (6, 12.0, False),
    "stagger": (10, 10.0, False),
    "death": (14, 10.0, False),
}


def anim_starts() -> dict[str, int]:
    out, col = {}, 0
    for name, (count, _, _) in ANIMS.items():
        out[name] = col
        col += count
    return out


TOTAL_FRAMES = sum(v[0] for v in ANIMS.values())

# --- mapa ----------------------------------------------------------------------------------

MAP_FRAME = (56, 80)
MAP_ORIGIN = (28, 74)
MAP_SCALE = 0.29
MAP_DIRS = 8
MAP_ANIMS = {"idle": 4, "walk": 8}
CORPSE_FRAME = (88, 56)
CORPSE_ORIGIN = (44, 34)
CORPSE_VARIANTS = ["whole", "no_arm_r"]

# =========================================================================================
# Materiales
# =========================================================================================

SKIN = rgb(92, 100, 108)
SKIN_LIVID = rgb(80, 72, 90)
SKIN_PALE = rgb(122, 126, 126)
SKIN_DARK = rgb(56, 58, 66)
SKIN_SALLOW = rgb(100, 102, 86)
VEIN = rgb(34, 36, 66)
GRIME = rgb(52, 44, 38)
BLOOD_DRY = rgb(70, 18, 20)
BLOOD_OLD = rgb(52, 22, 22)
BLOOD_WET = rgb(96, 8, 12)
FLUID = rgb(148, 126, 74)
CLOTH = rgb(198, 194, 180)


def _seeded(P: np.ndarray, seeds: np.ndarray) -> np.ndarray:
    return P + seeds[:, None] * np.array([37.1, 11.7, 23.3])


@material("skin")
def skin_mat(P, N, seeds, ii, prims):
    Q = _seeded(P, seeds)
    n = len(P)
    mott = fbm(Q * 0.07, 1, 3)
    alb = mix(SKIN, SKIN_LIVID, smoothstep(0.5, 0.72, mott))
    alb = mix(alb, SKIN_PALE, smoothstep(0.52, 0.75, fbm(Q * 0.11, 2, 2)) * 0.6)
    alb = mix(alb, SKIN_DARK, smoothstep(0.55, 0.8, fbm(Q * 0.21, 3, 2)) * 0.5)
    alb = mix(alb, SKIN_SALLOW, smoothstep(0.5, 0.75, fbm(Q * 0.05, 4, 2)) * 0.5)
    warp = np.stack([fbm(Q * 0.05, 7, 2), fbm(Q * 0.05, 8, 2), fbm(Q * 0.05, 9, 2)], axis=1) * 9.0

    def veins(X):
        r = ridge((X + warp) * np.array([0.09, 0.05, 0.09]), 5, 2)
        return smoothstep(0.9, 0.975, r) * smoothstep(0.35, 0.55, fbm(X * 0.04, 6, 2))

    def height(X):
        return 0.9 * veins(X) + 0.35 * fbm(X * 0.8, 12, 2)

    v = veins(Q)
    alb = mix(alb, VEIN, v * 0.85)
    # Suciedad y sangre seca en la parte baja (pies, espinillas) y en las manos.
    low = smoothstep(26.0, 4.0, P[:, 1]) * (0.5 + 0.5 * fbm(Q * 0.2, 13, 2))
    alb = mix(alb, GRIME, low * 0.85)
    dirt = smoothstep(0.62, 0.7, fbm(Q * 0.13, 14, 3)) * 0.6
    alb = mix(alb, BLOOD_OLD, dirt * pdata(ii, prims, "dirty", 0.35))
    nn = bump(N, grad_of(height, Q), 0.9)
    return surface(n, alb, nn, spec=0.14, gloss=12.0, wrap=0.3)


@material("skin_head")
def skin_head_mat(P, N, seeds, ii, prims):
    """Piel de la cabeza: cuencas oscuras bajo la máscara, regueros de sangre que bajan por
    las mejillas desde la porcelana, puntos de sutura alrededor de la mascarilla y la
    cicatriz del cráneo."""
    s = skin_mat(P, N, seeds, ii, prims)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    alb = s.albedo
    # Cuencas: debajo de los agujeros de la máscara.
    for ex in (EYE_X, -EYE_X):
        d = (x - ex) ** 2 + ((y - EYE_Y) * 1.2) ** 2
        alb = mix(alb, rgb(12, 6, 10), smoothstep(7.5, 2.0, d) * (z > HEAD_C[2]))
        # Lágrimas de sangre bajo la porcelana.
        streak = np.exp(-((x - ex - 0.6 * np.sin(y * 0.5)) / 0.9) ** 2) * (y < EYE_Y - 2) * (y > EYE_Y - 9.5 - 3 * fbm(P * 0.3, 41, 1))
        alb = mix(alb, BLOOD_DRY, np.clip(streak, 0, 1) * (z > HEAD_C[2] + 4) * 0.95)
    # Cicatriz coronal con grapas.
    rel = P - np.array(HEAD_C)
    line = rel[:, 2] + 0.25 * rel[:, 0] + 2.0
    top = rel[:, 1] > 5.0
    alb = mix(alb, rgb(84, 26, 32), (np.abs(line) < 0.9) * top)
    staple = (np.abs(line) < 2.2) & (np.mod(rel[:, 0], 3.2) < 0.9) & top
    alb = np.where(staple[:, None], rgb(150, 152, 150), alb)
    # Puntos de sutura en el borde de la mascarilla (la piel tira hacia los puntos).
    edge = np.abs(np.abs(x) - (MASK_HALF_W - 0.4)) < 1.1
    rows = (y > MASK_Y0) & (y < MASK_Y1) & (z > HEAD_C[2] + 2)
    stitch = edge & rows & (np.mod(y, 2.6) < 0.9)
    alb = mix(alb, rgb(70, 30, 36), (edge & rows) * 0.55)
    alb = np.where(stitch[:, None], rgb(16, 12, 14), alb)
    s.albedo = alb
    return s


@material("socket")
def socket_mat(P, N, seeds, ii, prims):
    return surface(len(P), rgb(10, 6, 9), N, spec=0.0)


@material("eye")
def eye_mat(P, N, seeds, ii, prims):
    """El único ojo vivo: lechoso, húmedo, con vasos rotos."""
    n = len(P)
    alb = mix(rgb(150, 148, 136), rgb(120, 40, 40), smoothstep(0.6, 0.8, ridge(P * 0.8, 3, 1)) * 0.7)
    rel = P - np.array((EYE_X, EYE_Y, 0.0))
    pupil = (rel[:, 0] + 0.3) ** 2 + (rel[:, 1] + 0.2) ** 2 < 0.8
    alb = np.where(pupil[:, None], rgb(30, 34, 36), alb)
    return surface(n, alb, N, spec=2.2, gloss=90.0)


@material("cloth")
def cloth_mat(P, N, seeds, ii, prims):
    """Uniforme blanco de enfermería: pliegues, trama, mugre, sangre seca, manchas de fluido
    y borde deshilachado en los desgarros."""
    Q = _seeded(P, seeds)
    n = len(P)
    blood_amt = pdata(ii, prims, "blood", 0.5)
    fold_f = pdata(ii, prims, "fold", 1.0)
    sliced = pdata(ii, prims, "slice", 0.0) > 0
    if sliced.any():
        N = N.copy()
        N[sliced, 1] *= 0.2
        N = normalize(N)

    def height(X):
        w = fbm(X * 0.05, 21, 2) * 6.0
        folds = np.sin(X[:, 0] * 0.45 + X[:, 2] * 0.3 + w) * 0.6 + np.sin(X[:, 1] * 0.12 + X[:, 0] * 0.2 + w * 0.7) * 0.4
        creases = smoothstep(0.86, 0.96, ridge(X * np.array([0.08, 0.04, 0.08]), 22, 2))
        return folds * 0.9 - creases * 1.2 + 0.05 * vnoise(X * 1.5, 23)

    alb = np.broadcast_to(CLOTH, (n, 3)).copy()
    # Trama: muy fina, como variación de brillo.
    weave = (np.sin(P[:, 0] * 2.6) * np.sin(P[:, 1] * 2.6)) * 0.025
    alb = alb * (1 + weave[:, None])
    grime = fbm(Q * 0.06, 24, 3)
    alb = mix(alb, rgb(150, 140, 118), smoothstep(0.42, 0.75, grime) * 0.8)
    # Manchas de fluido amarillento con cerco más oscuro.
    f = fbm(Q * 0.09, 25, 3)
    alb = mix(alb, FLUID, smoothstep(0.6, 0.66, f) * 0.55)
    alb = mix(alb, rgb(112, 92, 56), (np.abs(f - 0.6) < 0.012) * 0.6)
    # Sangre seca: empapa los bordes de los desgarros y baja en regueros; salpicaduras sueltas.
    tear = pdata(ii, prims, "tear_id", -1.0)
    field_ = np.full(n, -9.0)
    for tid in np.unique(tear[tear >= 0]):
        m = tear == tid
        field_[m] = TEARS[int(tid)](P[m])
    soak = smoothstep(-0.9 - 0.5 * fbm(Q * 0.15, 26, 2), -0.1, field_) * (tear >= 0)
    drip_x = fbm(Q * np.array([0.5, 0.0, 0.5]), 27, 1)
    drip = smoothstep(0.7, 0.76, drip_x) * smoothstep(0.35, 0.6, fbm(Q * np.array([0.06, 0.02, 0.06]), 29, 2))
    spatter = smoothstep(0.84, 0.88, vnoise(Q * 0.8, 30))
    blob = smoothstep(0.7, 0.74, fbm(Q * 0.1, 31, 3))
    blood = np.clip(soak * 0.95 + (drip * 0.9 + spatter * 0.8 + blob * 0.85) * blood_amt, 0.0, 1.0)
    alb = mix(alb, mix(BLOOD_DRY, BLOOD_OLD, fbm(Q * 0.3, 28, 2)), blood * 0.9)
    # Bajo sucio (y gris donde roza).
    hem = pdata(ii, prims, "hem", -999.0)
    alb = mix(alb, rgb(96, 84, 70), smoothstep(hem + 9, hem, P[:, 1]) * 0.65)
    # Borde de los desgarros: hilos sueltos, más oscuro.
    alb = mix(alb, rgb(60, 30, 28), smoothstep(-0.12, 0.0, field_) * (tear >= 0) * 0.8)
    nn = bump(N, grad_of(height, Q, 0.5), 0.55 * fold_f[:, None])
    return surface(n, alb, nn, spec=0.05, gloss=8.0, wrap=0.2)


@material("mask_cloth")
def mask_cloth_mat(P, N, seeds, ii, prims):
    """Mascarilla quirúrgica: pliegues horizontales, verde agua sucio, manchada en la boca."""
    n = len(P)
    rel = P - np.array(HEAD_C)

    def height(X):
        return np.sin(X[:, 1] * 1.25) * 0.8 + 0.15 * vnoise(X * 1.5, 31)

    alb = np.broadcast_to(rgb(120, 150, 146), (n, 3)).copy()
    alb = mix(alb, rgb(94, 110, 96), smoothstep(0.4, 0.8, fbm(P * 0.15, 32, 3)) * 0.7)
    mouth = np.exp(-((rel[:, 0] / 4.0) ** 2 + ((P[:, 1] - (MASK_Y0 + 4.2)) / 2.0) ** 2))
    alb = mix(alb, rgb(78, 22, 24), np.clip(mouth * 1.3 * (0.6 + 0.5 * fbm(P * 0.6, 33, 2)), 0, 0.95))
    drip = (np.abs(rel[:, 0] - 1.5 - np.sin(P[:, 1]) * 0.4) < 0.8) & (P[:, 1] < MASK_Y0 + 3)
    alb = mix(alb, BLOOD_DRY, drip * 0.9)
    # Costura del borde: la tela está cosida a la piel.
    edge = (np.abs(np.abs(rel[:, 0]) - (MASK_HALF_W - 1.0)) < 0.8) & (np.mod(P[:, 1], 2.6) < 1.0)
    alb = np.where(edge[:, None], rgb(18, 14, 16), alb)
    nn = bump(N, grad_of(height, P, 0.3), 0.5)
    return surface(n, alb, nn, spec=0.06, gloss=8.0, wrap=0.2)


@material("porcelain")
def porcelain_mat(P, N, seeds, ii, prims):
    """Porcelana pálida agrietada: muy lisa y brillante; grietas oscuras con mugre metida."""
    n = len(P)
    Q = P + np.array([3.1, 0.0, 1.7])
    crack_f = ridge(Q * np.array([0.13, 0.09, 0.13]), 51, 2)
    crack2 = ridge(Q * np.array([0.3, 0.22, 0.3]) + 4.0, 52, 1)
    big = smoothstep(0.93, 0.965, crack_f)
    small = smoothstep(0.95, 0.98, crack2) * smoothstep(0.8, 0.92, crack_f)
    cracks = np.maximum(big, small * 0.8)

    def height(X):
        c = ridge(X * np.array([0.13, 0.09, 0.13]), 51, 2)
        return -smoothstep(0.92, 0.97, c) * 1.2

    alb = np.broadcast_to(rgb(226, 220, 204), (n, 3)).copy()
    alb = mix(alb, rgb(196, 186, 166), smoothstep(0.45, 0.85, fbm(Q * 0.12, 53, 3)) * 0.7)
    alb = mix(alb, rgb(150, 136, 116), smoothstep(0.8, 0.95, crack_f) * 0.5)   # mugre junto a las grietas
    alb = mix(alb, rgb(30, 22, 24), cracks)
    # Sangre que asoma por debajo del borde.
    alb = mix(alb, BLOOD_DRY, smoothstep(0.72, 0.8, fbm(Q * 0.2, 54, 2)) * smoothstep(EYE_Y - 1, EYE_Y - 5, P[:, 1]) * 0.8)
    nn = bump(N, grad_of(height, Q, 0.3), 0.8)
    return surface(n, alb, nn, spec=1.1 * (1 - cracks), gloss=55.0, wrap=0.0)


@material("metal")
def metal_mat(P, N, seeds, ii, prims):
    """Acero quirúrgico usado: cepillado, con sangre seca en las juntas y algo de óxido."""
    Q = _seeded(P, seeds)
    n = len(P)
    brushed = vnoise(Q * np.array([3.0, 0.15, 3.0]), 61)
    alb = mix(rgb(118, 124, 130), rgb(170, 174, 178), brushed)
    alb = mix(alb, rgb(96, 58, 40), smoothstep(0.66, 0.74, fbm(Q * 0.3, 62, 3)) * 0.6 * pdata(ii, prims, "rust", 0.5))
    blood = smoothstep(0.6, 0.66, fbm(Q * 0.22, 63, 3)) * pdata(ii, prims, "blood", 0.6)
    alb = mix(alb, BLOOD_DRY, blood * 0.9)

    def height(X):
        return 0.3 * vnoise(X * np.array([3.0, 0.15, 3.0]), 61)

    nn = bump(N, grad_of(height, Q, 0.2), 0.3)
    return surface(n, alb, nn, spec=1.5 * (1 - blood * 0.7), gloss=38.0 + 30 * brushed, wrap=0.0)


@material("blade")
def blade_mat(P, N, seeds, ii, prims):
    """Hoja de bisturí o de sierra: espejo con el filo más claro y la punta ensangrentada."""
    Q = _seeded(P, seeds)
    n = len(P)
    alb = mix(rgb(150, 156, 162), rgb(196, 200, 204), vnoise(Q * np.array([0.3, 2.5, 0.3]), 64))
    tip = pdata(ii, prims, "tip_y", -999.0)
    wet = smoothstep(tip + 9, tip + 1, P[:, 1]) * (0.5 + 0.5 * fbm(Q * 0.5, 65, 2))
    alb = mix(alb, BLOOD_WET, np.clip(wet * 1.2, 0, 1) * 0.9)
    alb = mix(alb, BLOOD_DRY, smoothstep(0.62, 0.68, fbm(Q * 0.35, 66, 2)) * 0.8)
    return surface(n, alb, N, spec=2.0, gloss=70.0, wrap=0.0)


@material("rubber_tube")
def tube_mat(P, N, seeds, ii, prims):
    """Tubo de goma traslúcido lleno de líquido oscuro: muy brillante, con burbujas claras."""
    Q = _seeded(P, seeds)
    n = len(P)
    alb = mix(rgb(36, 16, 20), rgb(70, 46, 40), smoothstep(0.55, 0.75, fbm(Q * 0.3, 71, 2)))
    bubble = smoothstep(0.82, 0.86, vnoise(Q * 0.45, 72))
    alb = mix(alb, rgb(120, 100, 90), bubble * 0.6)
    return surface(n, alb, N, spec=1.6, gloss=60.0, wrap=0.1)


@material("glass")
def glass_mat(P, N, seeds, ii, prims):
    """Cilindro de la jeringa: líquido casi negro, graduación blanca, reflejo de cristal."""
    n = len(P)
    y = P[:, 1]
    top = pdata(ii, prims, "fill_top", 999.0)
    alb = np.where((y < top)[:, None], rgb(30, 12, 18), rgb(62, 68, 76))
    alb = mix(alb, rgb(60, 20, 26), smoothstep(0.5, 0.8, fbm(P * 0.4, 73, 2)) * (y < top))
    marks = (np.mod(y, 2.8) < 0.55) & (N[:, 2] > 0.2) & (np.abs(N[:, 0]) < 0.75)
    long = marks & (np.mod(y, 11.2) < 0.55)
    alb = np.where(marks[:, None], rgb(150, 150, 140), alb)
    alb = np.where(long[:, None], rgb(190, 190, 176), alb)
    return surface(n, alb, N, spec=2.4, gloss=95.0, wrap=0.0)


@material("rubber")
def rubber_mat(P, N, seeds, ii, prims):
    n = len(P)
    alb = mix(rgb(22, 22, 26), rgb(44, 40, 44), fbm(P * 0.5, 74, 2))
    return surface(n, alb, N, spec=0.4, gloss=20.0)


@material("wound")
def wound_mat(P, N, seeds, ii, prims):
    """Carne viva: rojo oscuro húmedo con grasa amarillenta y coágulos casi negros."""
    Q = _seeded(P, seeds)
    n = len(P)
    f = fbm(Q * 0.45, 81, 3)
    alb = mix(rgb(120, 24, 28), rgb(58, 8, 12), smoothstep(0.4, 0.7, f))
    alb = mix(alb, rgb(164, 132, 86), smoothstep(0.7, 0.76, fbm(Q * 0.6, 82, 2)) * 0.8)
    alb = mix(alb, rgb(26, 4, 8), smoothstep(0.66, 0.72, fbm(Q * 0.3, 83, 2)))

    def height(X):
        return fbm(X * 0.6, 84, 2) * 1.2

    nn = bump(N, grad_of(height, Q, 0.3), 0.8)
    return surface(n, alb, nn, spec=1.1, gloss=40.0, wrap=0.35)


@material("stump_face")
def stump_face_mat(P, N, seeds, ii, prims):
    """Corte de un miembro: hueso en el centro (con médula), anillo de músculo y grasa, piel
    gris en el borde."""
    n = len(P)
    cx = pdata(ii, prims, "cx")
    cy = pdata(ii, prims, "cy")
    cz = pdata(ii, prims, "cz")
    rad = pdata(ii, prims, "rad", 5.0)
    bone_r = pdata(ii, prims, "bone_r", 1.8)
    d = np.sqrt((P[:, 0] - cx) ** 2 + (P[:, 1] - cy) ** 2 + (P[:, 2] - cz) ** 2)
    w = wound_mat(P, N, seeds, ii, prims)
    alb = w.albedo
    alb = mix(alb, rgb(176, 150, 100), (np.abs(d - rad * 0.82) < rad * 0.08) * 0.8)
    alb = mix(alb, SKIN_DARK, smoothstep(rad * 0.9, rad, d))
    bone = d < bone_r
    alb = np.where(bone[:, None], rgb(210, 198, 172), alb)
    alb = np.where((d < bone_r * 0.45)[:, None], rgb(90, 30, 30), alb)
    w.albedo = alb
    w.spec = np.where(bone, 0.3, w.spec)
    return w


@material("bone")
def bone_mat(P, N, seeds, ii, prims):
    """Hueso: marfil sucio, más oscuro y ensangrentado en la base."""
    Q = _seeded(P, seeds)
    n = len(P)
    alb = mix(rgb(214, 202, 174), rgb(170, 152, 120), fbm(Q * 0.4, 91, 3))
    base = pdata(ii, prims, "base_blood", 0.0)
    alb = mix(alb, rgb(96, 22, 26), np.clip(base * smoothstep(0.35, 0.65, fbm(Q * 0.5, 92, 2)), 0, 1) * 0.85)

    def height(X):
        return fbm(X * 0.9, 93, 2) * 0.6

    nn = bump(N, grad_of(height, Q, 0.3), 0.6)
    return surface(n, alb, nn, spec=0.35, gloss=18.0, wrap=0.15)


@material("blood")
def blood_mat(P, N, seeds, ii, prims):
    n = len(P)
    alb = mix(BLOOD_WET, rgb(50, 4, 8), fbm(P * 0.5, 94, 2))
    return surface(n, alb, N, spec=1.8, gloss=70.0, wrap=0.2)


@material("thread")
def thread_mat(P, N, seeds, ii, prims):
    return surface(len(P), rgb(24, 18, 20), N, spec=0.2)


@material("nail")
def nail_mat(P, N, seeds, ii, prims):
    n = len(P)
    alb = mix(rgb(132, 116, 84), rgb(70, 52, 40), fbm(P * 0.8, 95, 2))
    return surface(n, alb, N, spec=0.6, gloss=30.0)


@material("badge")
def badge_mat(P, N, seeds, ii, prims):
    """Tarjeta de identificación con foto (un cuadro oscuro) y líneas de texto ilegibles."""
    n = len(P)
    rel = P - np.array(BADGE_C)
    alb = np.broadcast_to(rgb(176, 172, 156), (n, 3)).copy()
    photo = (rel[:, 0] > 0.4) & (rel[:, 0] < 3.6) & (rel[:, 1] > -2.2) & (rel[:, 1] < 1.8)
    alb = np.where(photo[:, None], rgb(52, 48, 50), alb)
    lines = (rel[:, 0] < -0.2) & (rel[:, 0] > -3.6) & (np.mod(rel[:, 1] + 3.0, 1.6) < 0.55) & (np.abs(rel[:, 1]) < 2.4)
    alb = np.where(lines[:, None], rgb(70, 66, 64), alb)
    alb = mix(alb, BLOOD_DRY, smoothstep(0.6, 0.66, fbm(P * 0.5, 96, 2)) * 0.9)
    return surface(n, alb, N, spec=0.9, gloss=40.0)


@material("shadow_occ")
def shadow_occ_mat(P, N, seeds, ii, prims):
    return surface(len(P), rgb(0, 0, 0), N)


# =========================================================================================
# Modelo en reposo
# =========================================================================================

# Medidas clave (coordenadas de reposo).
HIP_Y = 116.0
SHOULDER = (25.0, 179.0, 5.0)
ELBOW = (28.5, 128.0, 4.0)
WRIST = (30.0, 84.0, 7.0)
KNEE = (14.0, 62.0, 2.0)
ANKLE = (14.0, 9.0, -1.0)
NECK_BASE = (0.0, 184.0, 10.0)
HEAD_PIVOT = (0.0, 196.0, 26.0)
HEAD_C = (0.0, 210.0, 29.0)
EYE_X, EYE_Y = 4.4, 209.0
HEAD_SCALE = 1.18
MASK_Y0, MASK_Y1, MASK_HALF_W = 194.0, 202.5, 9.6
BADGE_C = (12.5, 158.0, 0.0)  # z se calcula
CHEST_C = (0.0, 165.0, 1.0)
CHEST_AXIS = (0.0, 36.0, 13.0)

# Huesos: nombre -> (padre, pivote en reposo)
BONES: dict[str, tuple[str | None, tuple]] = {
    "root": (None, (0.0, 118.0, 0.0)),
    "lumbar": ("root", (0.0, 128.0, -1.0)),
    "chest": ("lumbar", (0.0, 148.0, -3.0)),
    "neck": ("chest", NECK_BASE),
    "head": ("neck", HEAD_PIVOT),
    "jaw": ("head", (0.0, 201.0, 26.0)),
}
for _s, _n in ((1.0, "l"), (-1.0, "r")):
    BONES[f"clav_{_n}"] = ("chest", (_s * 6.0, 182.0, 8.0))
    BONES[f"arm_{_n}"] = (f"clav_{_n}", (_s * SHOULDER[0], SHOULDER[1], SHOULDER[2]))
    BONES[f"fore_{_n}"] = (f"arm_{_n}", (_s * ELBOW[0], ELBOW[1], ELBOW[2]))
    BONES[f"hand_{_n}"] = (f"fore_{_n}", (_s * WRIST[0], WRIST[1], WRIST[2]))
    BONES[f"thigh_{_n}"] = ("root", (_s * 13.0, HIP_Y, 0.0))
    BONES[f"shin_{_n}"] = (f"thigh_{_n}", (_s * KNEE[0], KNEE[1], KNEE[2]))
    BONES[f"foot_{_n}"] = (f"shin_{_n}", (_s * ANKLE[0], ANKLE[1], ANKLE[2]))
BLADE_COUNT = 4
BLADE_MOUNT_Y = 77.0
for _i in range(BLADE_COUNT):
    BONES[f"blade_{_i}"] = ("hand_r", (-27.0 - _i * 2.4, BLADE_MOUNT_Y, 8.0 + (1.5 - abs(_i - 1.5)) * 0.8))
BONES["plunger"] = ("hand_l", (31.0, 82.0, 13.0))


def V(*a) -> tuple:
    return tuple(float(x) for x in a)


def vadd(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def vsub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def vmul(a, k):
    return (a[0] * k, a[1] * k, a[2] * k)


def vlerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def mirror(p, side):
    return (p[0] * side, p[1], p[2])


def bezier(pts: list, n: int) -> list:
    out = []
    for i in range(n + 1):
        t = i / n
        q = list(pts)
        while len(q) > 1:
            q = [vlerp(q[j], q[j + 1], t) for j in range(len(q) - 1)]
        out.append(q[0])
    return out


def chest_basis():
    return basis_from_y(CHEST_AXIS, (0.0, 0.0, 1.0))


# Perfil de la casaca: (y, semiancho, semifondo, centro z) — z sigue la joroba hacia delante.
_TUNIC_KEYS = [(103.0, 20.0, 14.6, -0.5), (112.0, 19.4, 14.0, -0.5), (122.0, 18.4, 13.2, -0.8), (132.0, 17.6, 12.8, -1.0),
               (142.0, 17.8, 13.0, -0.8), (150.0, 19.6, 14.0, 0.0), (158.0, 21.2, 15.2, 1.2), (166.0, 21.8, 15.6, 2.4),
               (174.0, 21.4, 15.2, 3.4), (180.0, 19.6, 14.0, 4.4), (185.0, 15.0, 11.5, 5.4)]


def TUNIC_PROFILE_SLICES(breath: float = 0.0) -> list:
    out = []
    y = 104.0
    while y <= 185.0:
        for (y0, a0, b0, c0), (y1, a1, b1, c1) in zip(_TUNIC_KEYS, _TUNIC_KEYS[1:]):
            if y0 <= y <= y1:
                u = (y - y0) / (y1 - y0)
                k = 1.0 + (0.035 * breath if y > 150 else 0.0)
                out.append((y, a0 + (a1 - a0) * u, (b0 + (b1 - b0) * u) * k, c0 + (c1 - c0) * u))
                break
        y += 2.0
    return out


def _ellipsoid_surface_z(c, r, basis, x, y) -> float:
    """z de la superficie frontal de un elipsoide en (x, y) (búsqueda simple)."""
    best = c[2]
    for k in range(200):
        z = c[2] + r[2] * 1.5 - k * 0.1
        p = np.array([x, y, z]) - np.array(c)
        m = np.array(basis).T
        lp = (p @ m) / np.array(r)
        if lp @ lp <= 1.0:
            return z
        best = z
    return best


# --- desgarros (campos escalares: > 0 = agujero) -------------------------------------------

def _tear_chest(P):
    """Gran desgarro en el pecho (deja ver costillas y esternón) y apertura del cuello."""
    q = P + np.array([0.0, 0.0, 0.0])
    n = fbm(q * 0.18, 101, 3) - 0.5
    d = np.sqrt(((q[:, 0] + 5.0) / 14.0) ** 2 + ((q[:, 1] - 163.0) / 15.0) ** 2)
    front = smoothstep(0.0, 6.0, q[:, 2])
    hole = (1.0 - d + n * 0.9) - (1.0 - front) * 3.0
    # Escote en pico.
    vneck = (q[:, 1] - (180.0 - 9.0 + np.abs(q[:, 0]) * 0.9)) / 3.0 - (1.0 - smoothstep(2.0, 8.0, q[:, 2])) * 9.0
    vneck = np.where(np.abs(q[:, 0]) < 11.0, vneck, -1.0)
    back = (q[:, 1] - 176.0 + n * 6.0) / 3.0 - (1.0 - smoothstep(-6.0, -12.0, q[:, 2])) * 9.0
    return np.maximum(np.maximum(hole, vneck), back)


def _tear_belly(P):
    n = fbm(P * 0.2, 102, 3) - 0.5
    d = np.sqrt(((P[:, 0] + 4.0) / 7.0) ** 2 + ((P[:, 1] - 136.0) / 6.0) ** 2)
    return (1.0 - d + n * 1.1) - (1.0 - smoothstep(0.0, 5.0, P[:, 2])) * 3.0


def _tear_hem(P):
    n = fbm(P * np.array([0.25, 0.1, 0.25]), 103, 3)
    return (106.0 + n * 9.0 - P[:, 1]) / 2.0


def _tear_sleeve_l(P):
    n = fbm(P * 0.3, 104, 3)
    ragged = (156.0 + n * 8.0 - P[:, 1]) / 2.0
    hole = 0.7 - np.sqrt(((P[:, 1] - 166.0) / 4.0) ** 2 + ((P[:, 2] - 11.0) / 4.0) ** 2) + (n - 0.5)
    return np.maximum(ragged, hole)


def _tear_sleeve_r(P):
    n = fbm(P * 0.3, 105, 3)
    return (171.0 + n * 7.0 - P[:, 1]) / 2.0


def _tear_trouser(side):
    def fn(P):
        n = fbm(P * np.array([0.3, 0.12, 0.3]) + side * 7.0, 106, 3)
        hem = (28.0 + 10.0 * n + (6.0 if side < 0 else 0.0) - P[:, 1]) / 2.0
        knee = 0.9 - np.sqrt(((P[:, 0] - side * 14.0) / 5.0) ** 2 + ((P[:, 1] - 64.0) / 6.0) ** 2) + (n - 0.5) * 1.2
        knee = np.where(P[:, 2] > 0.0, knee, -1.0) if side < 0 else np.full(len(P), -1.0)
        return np.maximum(hem, knee)
    return fn


def _tear_mask_cloth(P):
    """La mascarilla solo cubre de la nariz a la barbilla, por delante."""
    rel = P - np.array(HEAD_C)
    out = np.maximum((P[:, 1] - MASK_Y1) / 1.0, (MASK_Y0 - P[:, 1]) / 1.0)
    out = np.maximum(out, np.abs(rel[:, 0]) - MASK_HALF_W)
    return np.maximum(out, (HEAD_C[2] + 1.0 - P[:, 2]))


def _tear_porcelain(P):
    """Máscara de media cara: frente, ojos y puente de la nariz; un trozo saltado."""
    rel = P - np.array(HEAD_C)
    x, y = rel[:, 0], P[:, 1]
    top = y - (217.5 - 0.06 * x * x)
    bottom = (EYE_Y - 4.5 + np.clip(4.5 - np.abs(x), 0, 4.5) * -1.0) - y
    side = np.abs(x) - 10.6
    out = np.maximum(np.maximum(top, bottom), side)
    out = np.maximum(out, HEAD_C[2] + 2.0 - P[:, 2])
    for ex in (EYE_X, -EYE_X):
        eye = 2.7 - np.sqrt((x - ex) ** 2 + ((y - EYE_Y) * 1.3) ** 2)
        out = np.maximum(out, eye)
    chip = 1.0 - np.sqrt(((x + 7.6) / 2.6) ** 2 + ((y - 214.5) / 2.2) ** 2) + (fbm(P * 0.8, 107, 2) - 0.5)
    return np.maximum(out, chip)


def _tear_tunic(P):
    return np.maximum(np.maximum(_tear_chest(P), _tear_belly(P)), _tear_hem(P))


TEARS = [_tear_chest, _tear_belly, _tear_hem, _tear_sleeve_l, _tear_sleeve_r, _tear_trouser(1.0), _tear_trouser(-1.0),
         _tear_mask_cloth, _tear_porcelain, _tear_tunic]


def tear_cut(tid: int):
    fn = TEARS[tid]

    def cut(P, prim):
        return fn(P) > 0.0
    return cut


def plane_cut(point, normal, jag: float = 0.0, seed: int = 0):
    """Corta lo que queda al lado positivo de un plano (borde irregular con `jag`)."""
    pt = np.array(point)
    nr = np.array(normal) / np.linalg.norm(normal)

    def cut(P, prim):
        d = (P - pt) @ nr
        if jag:
            d = d + (fbm(P * 0.5, seed, 2) - 0.5) * jag
        return d > 0.0
    return cut


def saw_cut(edge_x: float, tooth: float, depth: float):
    """Dientes de sierra en el borde x < edge_x (en reposo)."""
    def cut(P, prim):
        phase = np.mod(P[:, 1], tooth) / tooth
        return P[:, 0] < edge_x + depth * phase
    return cut


# --- piezas -------------------------------------------------------------------------------

def _T(prims, layer, mat, seed=0, vcut=None, **data):
    return tag(prims if isinstance(prims, list) else [prims], layer, mat, seed, vcut, data)


def build_rest(params: dict) -> dict[str, list]:
    """Primitivas en reposo, agrupadas por hueso. `params`: breath (0..1), plunger (0..1)."""
    breath = params.get("breath", 0.0)
    B: dict[str, list] = {name: [] for name in BONES}
    cb = chest_basis()

    # --- pelvis y piernas -----------------------------------------------------------------
    B["root"] += _T(ellipsoid(V(0, 120, 0), V(16, 12, 11), None), "body", "skin", 1)
    B["root"] += _T(ellipsoid(V(0, 119.5, -0.5), V(17.6, 13.6, 12.6), None), "body", "cloth", 2, None, blood=0.3, fold=0.8)
    # Faldón de la casaca (cae sobre la cadera, con el bajo deshilachado).
    for side, n in ((1.0, "l"), (-1.0, "r")):
        leg = f"leg_{n}"
        hip = V(side * 13, 116, 0)
        thigh_mid = V(side * 14, 90, 2)
        knee = V(side * 14, 62, 2)
        B[f"thigh_{n}"] += _T(limb([hip, thigh_mid, knee], [8.2, 6.6, 5.2], None, 3), leg, "skin", 10 + side)
        # Pantalón (con la rodilla derecha rota).
        B[f"thigh_{n}"] += _T(limb([vadd(hip, V(0, 2, 0)), thigh_mid, knee], [9.8, 8.4, 7.3], None, 3), leg, "cloth",
                              12 + side, tear_cut(5 if side > 0 else 6), blood=0.45, hem=24.0, tear_id=5 if side > 0 else 6)
        B[f"thigh_{n}"] += _T(sphere(V(side * 14, 62.5, 2.6), 7.3, None), leg, "cloth", 14 + side,
                              tear_cut(5 if side > 0 else 6), blood=0.45, tear_id=5 if side > 0 else 6)
        B[f"shin_{n}"] += _T(sphere(V(side * 14, 62, 2.5), 5.4, None), leg, "skin", 15 + side)
        B[f"shin_{n}"] += _T(ellipsoid(V(side * 14, 62.5, 6.8), V(3.4, 4.0, 2.0), None), leg, "skin", 16 + side)
        shin_mid = V(side * 14, 38, 1)
        ankle = V(side * 14, 9, -1)
        B[f"shin_{n}"] += _T(limb([knee, shin_mid, ankle], [4.8, 4.0, 2.6], None, 3), leg, "skin", 17 + side, dirty=0.6)
        B[f"shin_{n}"] += _T(ellipsoid(V(side * 14, 46, -2.2), V(4.3, 11, 4.3), None), leg, "skin", 18 + side)
        B[f"shin_{n}"] += _T(capsule(V(side * 14, 57, 5.0), V(side * 14, 15, 2.6), 1.5, None), leg, "skin", 19 + side)
        # Pernera desde la rodilla.
        B[f"shin_{n}"] += _T(limb([knee, shin_mid, V(side * 14, 20, 0)], [7.2, 6.4, 5.6], None, 3), leg, "cloth", 20 + side,
                             tear_cut(5 if side > 0 else 6), blood=0.6, hem=24.0, tear_id=5 if side > 0 else 6, fold=1.3)
        for mx in (2.6, -2.6):
            B[f"shin_{n}"] += _T(sphere(V(side * 14 + mx, 9.5, -0.5), 2.0, None), leg, "skin", 21 + side, dirty=0.8)
        # Pie descalzo, largo, con los dedos y las uñas.
        foot = f"foot_{n}"
        B[foot] += _T(ellipsoid(V(side * 14, 4.2, -2.6), V(3.4, 4.2, 4.0), None), leg, "skin", 22 + side, dirty=0.9)
        B[foot] += _T(ellipsoid(V(side * 14.6, 3.2, 5.5), V(4.8, 3.0, 8.5), None), leg, "skin", 23 + side, dirty=0.9)
        toes = [(-3.3, 1.45, 18.6), (-1.2, 1.1, 17.8), (0.8, 1.0, 17.0), (2.6, 0.95, 16.0), (4.2, 0.85, 14.8)]
        for tx, tr, tz in toes:
            x = side * 14.6 + side * tx
            a = V(x, 2.2, 12.0)
            b = V(x + side * tx * 0.1, 1.2, tz)
            B[foot] += _T(capsule(a, b, tr, None), leg, "skin", 24 + side, dirty=0.9)
            B[foot] += _T(ellipsoid(vadd(b, V(0, 0.55, 0.3)), V(tr * 0.8, 0.4, tr * 0.7), None), leg, "nail", 25)

    # --- tronco ---------------------------------------------------------------------------
    B["lumbar"] += _T(ellipsoid(V(0, 138, -1.5), V(13.2, 13, 8.6 + 0.5 * breath), None), "body", "skin", 30)
    # Oblicuos marcados.
    for side in (1.0, -1.0):
        B["lumbar"] += _T(ellipsoid(V(side * 9.5, 134, 1), V(4.5, 9, 6), None), "body", "skin", 31)
    # Incisión cosida en el vientre (visible por el desgarro).
    for i in range(7):
        y = 131 + i * 2.0
        B["lumbar"] += _T(capsule(V(-6.2, y, 8.0), V(-1.8, y + 0.4, 8.8), 0.42, None), "body", "thread", 33)
    B["lumbar"] += _T(capsule(V(-4.0, 130.0, 8.2), V(-4.0, 144.0, 8.4), 0.9, None), "body", "wound", 34)

    rib_c = CHEST_C
    rib_r = (19.0, 22.0, 12.5 + 0.9 * breath)
    B["chest"] += _T(ellipsoid(rib_c, (rib_r[0] * 0.95, rib_r[1], rib_r[2] * 0.9), None, basis=cb), "body", "skin", 40)
    # Costillas: arcos que bajan hacia los lados, medio hundidos en la caja.
    for i in range(7):
        ly0 = -13.0 + i * 4.3
        pts = []
        for k in range(13):
            phi = (k / 12 - 0.5) * math.radians(200)
            ly = ly0 - 6.0 * (abs(phi) / (math.pi / 2)) ** 1.4
            ring = math.sqrt(max(0.0, 1 - (ly / rib_r[1]) ** 2))
            lx = math.sin(phi) * rib_r[0] * ring * 1.0
            lz = math.cos(phi) * rib_r[2] * ring * 1.0
            if abs(phi) < 0.18:
                continue  # el esternón
            local = np.array(cb[0]) * lx + np.array(cb[1]) * ly + np.array(cb[2]) * lz
            pts.append(tuple(np.array(rib_c) + local))
        half = len(pts) // 2
        for seg in (pts[:half], pts[half:]):
            for a, b in zip(seg, seg[1:]):
                B["chest"] += _T(capsule(a, b, 2.1, None), "body", "skin", 41 + i)
    # Esternón y clavículas.
    for a, b in zip(bezier([V(0, 158, 12.6), V(0, 170, 14.5), V(0, 180, 13.0)], 4)[:-1],
                    bezier([V(0, 158, 12.6), V(0, 170, 14.5), V(0, 180, 13.0)], 4)[1:]):
        B["chest"] += _T(capsule(a, b, 1.9, None), "body", "skin", 50)
    for side in (1.0, -1.0):
        B["chest"] += _T(capsule(V(side * 3, 181.5, 12), V(side * 22, 184, 4), 2.1, None), "body", "skin", 51)
        # Trapecio.
        B["chest"] += _T(capsule(V(side * 5, 189, 3), V(side * 20, 184.5, 1.5), 5.6, None), "body", "skin", 52)
        # Pectoral enjuto.
        B["chest"] += _T(ellipsoid(V(side * 10, 172, 9), V(9, 6, 4), None), "body", "skin", 53)
        # Acromion.
        B["chest"] += _T(sphere(V(side * 23, 183, 3.5), 4.6, None), "body", "skin", 54)
        # Omóplatos.
        B["chest"] += _T(ellipsoid(V(side * 12, 172, -13), V(8, 11, 3.5), None, basis=cb), "body", "skin", 55)
    # Joroba y columna demasiado larga: apófisis que rompen la piel.
    B["chest"] += _T(ellipsoid(V(0, 170, -11), V(17, 19, 9.5), None, basis=cb), "body", "skin", 56)
    spine = bezier([V(0, 128, -10), V(0, 150, -18), V(0, 176, -22), V(0, 192, -6)], 14)
    for i, p in enumerate(spine):
        B["chest" if p[1] > 148 else "lumbar"] += _T(ellipsoid(p, V(2.6, 2.0, 2.4), None), "body", "skin", 57)
        if i % 2 == 1 and p[1] > 150:
            out = norm3(vsub(p, vadd(V(0, 165, 0), V(0, 0, 0))))
            length = 4.0 + (p[1] - 150) * 0.32
            tip = vadd(p, vmul(norm3(vadd(out, V(0, 0.8, 0))), length))
            B["chest"] += _T(capsule(p, tip, 1.3, None), "body", "bone", 58 + i, base_blood=1.0)
            B["chest"] += _T(sphere(p, 2.4, None), "body", "wound", 59 + i)
    # Pieza metálica entre los omóplatos (la misma del protagonista, a escala) y tubos.
    port_a, port_b = V(0, 175, -19.5), V(0, 176, -27)
    B["chest"] += _T(cylinder(port_a, port_b, 5.2, None), "body", "metal", 60, rust=0.8)
    B["chest"] += _T(cylinder(V(0, 175.9, -26), V(0, 176.1, -28.2), 6.4, None), "body", "metal", 61, rust=0.4)
    B["chest"] += _T(sphere(V(0, 176.2, -28.4), 2.4, None), "body", "metal", 62)
    for k in range(6):
        a = k / 6 * math.tau
        B["chest"] += _T(cylinder(V(math.cos(a) * 5.3, 176 + math.sin(a) * 5.3, -26.6), V(math.cos(a) * 5.3, 176 + math.sin(a) * 5.3, -28.9),
                                  0.8, None), "body", "metal", 63)
    B["chest"] += _T(sphere(V(0, 175, -19.5), 7.0, None), "body", "wound", 64)
    z1 = _ellipsoid_surface_z(rib_c, rib_r, cb, 7, 172) + 0.4
    z2 = _ellipsoid_surface_z(rib_c, rib_r, cb, -6, 166) + 0.4
    z3 = _ellipsoid_surface_z(V(0, 138, -1.5), V(13.2, 13, 8.6), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), 9, 142) + 0.4
    tubes = [
        [V(3, 178, -27), V(14, 198, -18), V(18, 196, 8), V(7, 172 + 3, z1 + 3), V(7, 172, z1)],
        [V(-3, 178, -27), V(-16, 199, -14), V(-17, 194, 10), V(-6, 166 + 3, z2 + 3), V(-6, 166, z2)],
        [V(4, 172, -27), V(26, 160, -16), V(23, 140, 8), V(9 + 2, 142, z3 + 3), V(9, 142, z3)],
    ]
    for ti, ctrl in enumerate(tubes):
        pts = bezier(ctrl, 16)
        for a, b in zip(pts, pts[1:]):
            B["chest" if a[1] > 150 else "lumbar"] += _T(capsule(a, b, 1.55, None), "body", "rubber_tube", 70 + ti)
        end = ctrl[-1]
        d = norm3(vsub(ctrl[-1], ctrl[-2]))
        B["chest" if end[1] > 150 else "lumbar"] += _T(cylinder(vsub(end, vmul(d, 1.6)), vadd(end, vmul(d, 0.8)), 2.4, None),
                                                       "body", "metal", 73)
        B["chest" if end[1] > 150 else "lumbar"] += _T(ellipsoid(vadd(end, vmul(d, 0.5)), V(4.2, 4.2, 1.8), None), "body",
                                                       "wound", 74 + ti)
    # Casaca: pecho, hombros y espalda, con el desgarro grande.
    for side in (1.0, -1.0):
        B["chest"] += _T(capsule(V(side * 6, 187.5, 2.5), V(side * 21, 183.5, 1.5), 6.6, None), "body", "cloth", 81 + side,
                         tear_cut(0), blood=0.5, tear_id=0)
    # Casaca: un solo volumen en rodajas (de la cadera a los hombros) que cuelga suelta sobre
    # el cuerpo consumido; las rodajas aplanan la normal vertical para no verse escalonadas.
    for y0, rx, rz, cz in TUNIC_PROFILE_SLICES(breath):
        bone = "root" if y0 < 128 else "lumbar" if y0 < 148 else "chest"
        ry = max(2.0, min(8.0, 190.0 - y0, y0 - 96.0))
        B[bone] += _T(ellipsoid(V(0, y0, cz), V(rx, ry, rz), None), "body", "cloth", 80, tear_cut(9), blood=0.8,
                      hem=106.0, tear_id=9, slice=1.0)
    # Tarjeta de identificación prendida del bolsillo.
    bz = _ellipsoid_surface_z(V(0, 158, 1.2), V(21.2, 8.0, 15.2), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), BADGE_C[0], BADGE_C[1])
    B["chest"] += _T(box(V(BADGE_C[0] + 1.0, BADGE_C[1], bz + 0.2), V(4.3, 3.1, 0.35), None,
                         basis=((0.96, 0, -0.28), (0, 1, 0), (0.28, 0, 0.96))), "body", "badge", 85)
    B["chest"] += _T(cylinder(V(BADGE_C[0] + 1.0, BADGE_C[1] + 3.0, bz + 0.3), V(BADGE_C[0] + 1.0, BADGE_C[1] + 5.0, bz + 0.3),
                              0.8, None), "body", "metal", 86)

    # --- cuello y cabeza --------------------------------------------------------------------
    neck_pts = [V(0, 180, 4), V(0, 189, 13), V(0, 197, 25)]
    B["neck"] += _T(limb(neck_pts, [6.8, 6.0, 5.6], None, 2), "body", "skin", 90)
    for side in (1.0, -1.0):
        B["neck"] += _T(capsule(V(side * 7.5, 202, 22), V(side * 2.2, 182.5, 12.5), 2.0, None), "body", "skin", 91)
    B["neck"] += _T(ellipsoid(V(0, 191, 18.6), V(2.0, 2.6, 2.0), None), "body", "skin", 92)

    hc = HEAD_C
    B["head"] += _T(ellipsoid(vadd(hc, V(0, 1.5, -3.5)), V(11.2, 13.2, 13.5), None), "head", "skin_head", 100)
    B["head"] += _T(ellipsoid(vadd(hc, V(0, -4, 3.0)), V(9.6, 10.5, 9.8), None), "head", "skin_head", 101)
    for side in (1.0, -1.0):
        B["head"] += _T(ellipsoid(vadd(hc, V(side * 11.0, -3.0, -1.0)), V(1.7, 4.2, 3.0), None), "head", "skin_head", 103)
        B["head"] += _T(ellipsoid(vadd(hc, V(side * 4.2, 1.6, 9.6)), V(4.2, 1.8, 2.2), None), "head", "skin_head", 104)  # arco ciliar
    # Nariz (bajo la porcelana) y mentón.
    B["head"] += _T(ellipsoid(vadd(hc, V(0, -4.0, 9.8)), V(1.8, 3.6, 2.2), None), "head", "skin_head", 105)
    B["jaw"] += _T(ellipsoid(vadd(hc, V(0, -14.0, 7.0)), V(6.0, 4.6, 5.4), None), "head", "skin_head", 106)
    B["jaw"] += _T(ellipsoid(vadd(hc, V(0, -10.5, 4.0)), V(8.6, 5.6, 7.6), None), "head", "skin_head", 107)
    # Ojo vivo (izquierdo) y cuenca vacía.
    B["head"] += _T(sphere(V(EYE_X, EYE_Y, hc[2] + 9.6), 2.0, None), "head", "eye", 108)
    # Mascarilla cosida (cubre de la nariz a la barbilla).
    B["jaw"] += _T(ellipsoid(vadd(hc, V(0, -9.0, 4.4)), V(10.3, 10.0, 9.4), None), "head", "mask_cloth", 110, tear_cut(7), tear_id=7)
    for side in (1.0, -1.0):
        B["head"] += _T(capsule(vadd(hc, V(side * 9.8, -6, 3)), vadd(hc, V(side * 10.6, -2, -8)), 0.55, None), "head", "mask_cloth", 111)
        B["head"] += _T(capsule(vadd(hc, V(side * 9.4, -11, 3)), vadd(hc, V(side * 10.0, -8, -9)), 0.55, None), "head", "mask_cloth", 112)
    # Máscara de porcelana encajada sobre los ojos.
    B["head"] += _T(ellipsoid(vadd(hc, V(0, -0.5, 0.4)), V(11.9, 12.4, 13.4), None), "head", "porcelain", 113, tear_cut(8),
                    tear_id=8)
    # Remaches/argollas que la sujetan a las sienes.
    for side in (1.0, -1.0):
        B["head"] += _T(cylinder(vadd(hc, V(side * 10.2, 1.0, 5.8)), vadd(hc, V(side * 11.8, 1.0, 5.3)), 1.3, None), "head", "metal", 114)
        B["head"] += _T(sphere(vadd(hc, V(side * 10.2, 1.0, 5.8)), 2.2, None), "head", "wound", 115)

    # Cabeza algo más grande que la de un hombre: se lee mejor la máscara.
    B["head"] = scale_about(B["head"], HEAD_SCALE, HEAD_PIVOT)
    B["jaw"] = scale_about(B["jaw"], HEAD_SCALE, HEAD_PIVOT)

    # --- brazos -----------------------------------------------------------------------------
    for side, n in ((1.0, "l"), (-1.0, "r")):
        arm = f"arm_{n}"
        sh = mirror(SHOULDER, side)
        el = mirror(ELBOW, side)
        wr = mirror(WRIST, side)
        B[f"clav_{n}"] += []
        B[arm] += _T(ellipsoid(vadd(sh, V(side * 1.5, -3, 0)), V(6.8, 9.5, 7.2), None), arm, "skin", 120 + side)
        B[arm] += _T(limb([sh, vlerp(sh, el, 0.5), el], [5.2, 4.6, 3.9], None, 3), arm, "skin", 121 + side)
        B[arm] += _T(ellipsoid(vadd(vlerp(sh, el, 0.55), V(0, 0, 3.6)), V(3.3, 10, 3.0), None), arm, "skin", 122 + side)
        B[arm] += _T(ellipsoid(vadd(vlerp(sh, el, 0.5), V(side * 0.6, 0, -3.3)), V(3.6, 11.5, 3.4), None), arm, "skin", 123 + side)
        B[f"fore_{n}"] += _T(sphere(el, 4.3, None), arm, "skin", 124 + side)
        B[f"fore_{n}"] += _T(sphere(vadd(el, V(0, 0.5, -3.5)), 2.6, None), arm, "skin", 125 + side)
        if side > 0:
            # Manga corta rota.
            B[arm] += _T(limb([vadd(sh, V(0, 1.5, 0)), vlerp(sh, el, 0.48)], [8.6, 7.2], None, 3), arm, "cloth", 126,
                         tear_cut(3), blood=0.55, tear_id=3)
            B[f"fore_{n}"] += _T(limb([el, vlerp(el, wr, 0.5), wr], [4.1, 3.6, 2.7], None, 3), arm, "skin", 127)
            B[f"fore_{n}"] += _T(ellipsoid(vadd(vlerp(el, wr, 0.25), V(-1.0, 0, 2.0)), V(3.4, 10, 3.0), None), arm, "skin", 128)
            _left_hand(B)
        else:
            # Jirón de manga en el hombro derecho.
            B[arm] += _T(limb([vadd(sh, V(0, 1.5, 0)), vlerp(sh, el, 0.3)], [8.6, 7.6], None, 2), arm, "cloth", 129,
                         tear_cut(4), blood=1.0, tear_id=4)
            # Grapas a lo largo del brazo.
            for k in range(6):
                y = 166 - k * 4.0
                p = vadd(vlerp(sh, el, (179 - y) / 51.0), V(-1.5, 0, 4.4))
                B[arm] += _T(box(p, V(1.6, 0.35, 0.4), None), arm, "metal", 130, blood=0.9)
            _right_forearm(B)
    return B


def scale_about(prims: list, k: float, c) -> list:
    """Escala primitivas (aún sin colocar) alrededor de `c`; la textura y los recortes
    siguen en las coordenadas originales."""
    C = np.array(c)
    out = er.place(prims, np.eye(3) * k, C * (1 - k))
    for q, p in zip(out, prims):
        if hasattr(q, "radii"):
            q.radii = tuple(r * k for r in p.radii)
        if hasattr(q, "r"):
            q.r = p.r * k
        if hasattr(q, "half"):
            q.half = tuple(h * k for h in p.half)
        if hasattr(q, "basis"):
            q.basis = p.basis
        q.bound = p.bound * k
    return out


def norm3(v):
    l = math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2)
    return (0.0, 0.0, 1.0) if l == 0 else (v[0] / l, v[1] / l, v[2] / l)


def _left_hand(B):
    """Mano izquierda cerrada sobre una jeringa grande, aguja hacia abajo."""
    wr = WRIST
    L = "arm_l"
    H = "hand_l"
    B[H] += _T(ellipsoid(V(30.8, 76.5, 8.5), V(3.4, 6.2, 2.6), None), L, "skin", 140, dirty=0.6)
    B[H] += _T(sphere(V(30.2, 83.5, 7.2), 2.9, None), L, "skin", 141)
    # Jeringa: eje vertical en x = 31, z = 13.
    cx, cz = 31.0, 13.0
    B[H] += _T(cylinder(V(cx, 50, cz), V(cx, 79, cz), 4.4, None), L, "glass", 142, fill_top=78.0)
    B[H] += _T(cylinder(V(cx, 79, cz), V(cx, 80.4, cz), 4.9, None), L, "glass", 143, fill_top=0)
    B[H] += _T(box(V(cx, 80.6, cz), V(7.6, 0.7, 2.4), None), L, "metal", 144, blood=0.3)   # aletas
    B[H] += _T(cylinder(V(cx, 47.5, cz), V(cx, 50.2, cz), 2.0, None), L, "metal", 145)
    B[H] += _T(cylinder(V(cx, 44.5, cz), V(cx, 47.6, cz), 1.1, None), L, "metal", 146)
    B[H] += _T(cylinder(V(cx, 26.0, cz), V(cx, 44.6, cz), 0.45, None), L, "blade", 147, tip_y=26.0)
    # Dedos largos que rodean el cilindro por delante, con uñas negras.
    for k, y in enumerate((75.5, 71.8, 68.2, 64.8)):
        r = 1.55 - k * 0.08
        pts = [V(33.6, y + 1.0, 8.6), V(35.6, y, 12.0), V(34.0, y - 0.4, 16.6), V(30.4, y - 0.8, 18.0), V(27.6, y - 1.2, 15.6)]
        for a, b in zip(pts, pts[1:]):
            B[H] += _T(capsule(a, b, r, None), L, "skin", 150 + k, dirty=0.6)
        B[H] += _T(ellipsoid(V(27.4, y - 1.1, 15.2), V(0.9, 1.1, 0.9), None), L, "nail", 154)
    # Pulgar sobre el émbolo.
    B[H] += _T(capsule(V(27.6, 79.0, 9.5), V(28.6, 83.6, 12.2), 1.8, None), L, "skin", 155)
    B[H] += _T(capsule(V(28.6, 83.6, 12.2), V(30.6, 87.0, 13.0), 1.6, None), L, "skin", 156)
    # Émbolo (hueso propio: baja al inyectar).
    P = "plunger"
    B[P] += _T(cylinder(V(cx, 72.5, cz), V(cx, 79.0, cz), 4.1, None), L, "rubber", 157)
    B[P] += _T(cylinder(V(cx, 79.0, cz), V(cx, 87.5, cz), 1.1, None), L, "metal", 158)
    B[P] += _T(cylinder(V(cx, 87.5, cz), V(cx, 88.7, cz), 3.4, None), L, "metal", 159)


def _right_forearm(B):
    """Antebrazo derecho fundido con instrumental: abrazaderas atornilladas a la carne, una
    sierra de hueso que sale del cúbito y cuatro bisturíes en lugar de dedos."""
    el = mirror(ELBOW, -1)
    wr = mirror(WRIST, -1)
    A = "arm_r"
    F = "fore_r"
    B[F] += _T(limb([el, vlerp(el, wr, 0.5), wr], [4.3, 3.9, 3.3], None, 3), A, "skin", 160, dirty=0.6)
    B[F] += _T(ellipsoid(vadd(vlerp(el, wr, 0.25), V(1.0, 0, 2.0)), V(3.5, 10, 3.1), None), A, "skin", 161)
    # Carne abierta donde entra el metal.
    B[F] += _T(ellipsoid(vadd(vlerp(el, wr, 0.62), V(-1.0, 0, 0.5)), V(4.0, 9.0, 3.8), None), A, "wound", 162)
    for t, r in ((0.42, 5.2), (0.7, 4.8)):
        c = vlerp(el, wr, t)
        B[F] += _T(cylinder(vadd(c, V(0, 1.1, 0)), vadd(c, V(0, -1.1, 0)), r, None), A, "metal", 163, blood=0.8, rust=0.9)
        for k in range(4):
            a = k / 4 * math.tau + 0.4
            d = V(math.cos(a), 0, math.sin(a))
            B[F] += _T(cylinder(vadd(c, vmul(d, r - 0.5)), vadd(c, vmul(d, r + 1.8)), 0.75, None), A, "metal", 164)
    # Varillas desde las abrazaderas hasta la muñeca.
    for dx in (2.2, -2.2):
        B[F] += _T(cylinder(vadd(vlerp(el, wr, 0.42), V(dx, 0, 4.4)), vadd(wr, V(dx * 0.8, -2, 3.6)), 0.85, None), A, "metal", 165)
    # Sierra de hueso: hoja plana de cara a la cámara, dientes por fuera.
    saw_c = V(-36.8, 96.0, 6.5)
    B[F] += _T(box(saw_c, V(3.8, 24.0, 0.55), None), A, "blade", 166, saw_cut(-36.8 - 3.8 + 1.6, 2.2, -1.6), tip_y=72.0)
    B[F] += _T(box(vadd(saw_c, V(1.6, 3, 0)), V(1.0, 22.0, 1.0), None), A, "metal", 167, blood=0.9)  # lomo
    B[F] += _T(ellipsoid(V(-34.0, 118.0, 5.5), V(3.0, 6.0, 3.6), None), A, "wound", 168)
    B[F] += _T(capsule(V(-33.5, 121.0, 5.6), V(-34.8, 113.0, 6.0), 1.6, None), A, "bone", 169, base_blood=1.0)
    # Montura de la muñeca.
    H = "hand_r"
    B[H] += _T(cylinder(vadd(wr, V(0, 1.5, 0)), vadd(wr, V(0.4, -5.5, 1.0)), 4.4, None), A, "metal", 170, blood=0.7)
    B[H] += _T(cylinder(vadd(wr, V(0.4, -5.0, 1.0)), vadd(wr, V(0.4, -6.6, 1.0)), 5.4, None), A, "metal", 171)
    B[H] += _T(ellipsoid(vadd(wr, V(0, 2.4, 0)), V(4.6, 2.5, 4.4), None), A, "wound", 172)
    for i in range(BLADE_COUNT):
        bone = f"blade_{i}"
        mx, my, mz = BONES[bone][1]
        # Mango estriado y hoja (elipsoide aplanado cortado por el lomo).
        B[bone] += _T(box(V(mx, my - 5.5, mz), V(0.95, 5.8, 0.55), None), A, "metal", 180 + i, blood=0.4)
        for k in range(4):
            B[bone] += _T(box(V(mx, my - 2.0 - k * 2.2, mz + 0.4), V(1.05, 0.35, 0.3), None), A, "metal", 184)
        length = 9.0 + (1.5 - abs(i - 1.5)) * 1.6
        bc = V(mx + 0.6, my - 11.0 - length * 0.55, mz)
        tip = my - 11.0 - length * 1.1
        B[bone] += _T(ellipsoid(bc, V(2.2, length * 0.62, 0.32), None), A, "blade", 185 + i, plane_cut(V(mx - 0.2, 0, 0), V(-1, 0, 0)),
                      tip_y=tip)
        B[bone] += _T(box(V(mx, my - 11.4, mz), V(0.7, 0.6, 0.4), None), A, "metal", 189)


# --- muñones ------------------------------------------------------------------------------

def build_stumps() -> dict[str, list]:
    """Muñón de cada parte: en el hueso del que cuelga la parte, con la carne cortada, el
    hueso asomando, jirones y sangre."""
    B: dict[str, list] = {name: [] for name in BONES}

    def face(c, axis, rad, bone_r, layer, bone, seed):
        a = vsub(c, vmul(axis, 0.4))
        b = vadd(c, vmul(axis, 0.4))
        B[bone].extend(_T(cylinder(a, b, rad, None), layer, "stump_face", seed, None, cx=c[0], cy=c[1], cz=c[2], rad=rad,
                          bone_r=bone_r))
        bone_tip = vadd(c, vmul(axis, 4.0))
        B[bone].extend(_T(capsule(c, bone_tip, bone_r, None), layer, "bone", seed + 1, base_blood=0.6))
        for k in range(4):
            ang = k * 1.7 + seed
            off = V(math.cos(ang) * rad * 0.8, 0, math.sin(ang) * rad * 0.8)
            p = vadd(c, off)
            q = vadd(p, vadd(vmul(axis, 2.5 + k % 2 * 1.5), V(0, -2.5, 0)))
            B[bone].extend(_T(capsule(p, q, 0.9 + 0.3 * (k % 2), None), layer, "wound", seed + 2 + k))

    for side, n in ((1.0, "l"), (-1.0, "r")):
        layer = f"stump_arm_{n}"
        sh = mirror(SHOULDER, side)
        cut_y = 166.0
        axis = norm3(vsub(mirror(ELBOW, side), sh))
        c = vlerp(sh, mirror(ELBOW, side), (sh[1] - cut_y) / (sh[1] - ELBOW[1]))
        B[f"arm_{n}"] += _T(ellipsoid(vadd(sh, V(side * 1.5, -3, 0)), V(6.8, 9.5, 7.2), None), layer, "skin", 200,
                            plane_cut(c, axis, 2.0, 201))
        B[f"arm_{n}"] += _T(limb([sh, c], [5.2, 4.9], None, 2), layer, "skin", 202)
        if side > 0:
            B[f"arm_{n}"] += _T(limb([vadd(sh, V(0, 1.5, 0)), vadd(c, vmul(axis, -1.0))], [8.6, 7.6], None, 2), layer, "cloth", 203,
                                tear_cut(3), blood=1.0, tear_id=3)
        face(c, axis, 5.0, 1.9, layer, f"arm_{n}", 210 + int(side))
        layer = f"stump_leg_{n}"
        hip = V(side * 13, 116, 0)
        knee = V(side * 14, 62, 2)
        axis = norm3(vsub(knee, hip))
        c = vlerp(hip, knee, 0.3)
        B[f"thigh_{n}"] += _T(limb([hip, c], [8.2, 7.6], None, 2), layer, "skin", 220)
        B[f"thigh_{n}"] += _T(limb([vadd(hip, V(0, 2, 0)), vadd(c, vmul(axis, -1.5))], [10.4, 9.6], None, 2), layer, "cloth", 221,
                              None, blood=1.0)
        face(c, axis, 7.8, 2.6, layer, f"thigh_{n}", 230 + int(side))
    # Cuello sin cabeza: la carne cortada sobre la nuez y una vértebra.
    neck_axis = norm3(vsub(V(0, 197, 25), V(0, 189, 13)))
    c = vlerp(V(0, 189, 13), V(0, 197, 25), 0.82)
    face(c, neck_axis, 5.9, 2.2, "stump_head", "neck", 240)
    for k in range(5):
        x = -3.5 + k * 1.8
        B["neck"] += _T(capsule(V(x, 192 - k % 2, 21), V(x + 0.3, 170 - k * 3.5, 15.2), 0.75 + 0.2 * (k % 2), None), "stump_head",
                        "blood", 245 + k)
    return B


# =========================================================================================
# Esqueleto y posturas
# =========================================================================================

def euler(rx: float = 0.0, ry: float = 0.0, rz: float = 0.0) -> np.ndarray:
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Ry @ Rx @ Rz


@dataclass
class Pose:
    """Rotaciones locales por hueso (rx, ry, rz) sobre el reposo, y el cuerpo entero."""
    rot: dict = field(default_factory=dict)
    root_t: tuple = (0.0, 0.0, 0.0)
    breath: float = 0.0
    plunger: float = 0.0
    ground: str = "feet"     # "feet": el pie más bajo en el suelo; "all": cualquier punto; "none"
    yaw: float = YAW

    def r(self, bone: str) -> tuple:
        return self.rot.get(bone, (0.0, 0.0, 0.0))


# Puntos de contacto con el suelo por hueso (reposo).
CONTACTS = {
    "foot_l": [V(14, 0.5, -5.5), V(14.6, 0.4, 17.5), V(20, 0.5, 12)],
    "foot_r": [V(-14, 0.5, -5.5), V(-14.6, 0.4, 17.5), V(-20, 0.5, 12)],
}
CONTACTS_ALL = dict(CONTACTS)
CONTACTS_ALL.update({
    "shin_l": [V(14, 62, 8.5), V(14, 40, 5), V(14, 20, -4), V(14, 45, -6)],
    "shin_r": [V(-14, 62, 8.5), V(-14, 40, 5), V(-14, 20, -4), V(-14, 45, -6)],
    "thigh_l": [V(14, 90, 10), V(14, 90, -7)],
    "thigh_r": [V(-14, 90, 10), V(-14, 90, -7)],
    "root": [V(0, 112, 12), V(0, 112, -12), V(18, 118, 0), V(-18, 118, 0)],
    "lumbar": [V(0, 138, 10), V(0, 138, -11), V(14, 138, 0), V(-14, 138, 0)],
    "chest": [V(0, 165, 16), V(0, 170, -22), V(19, 165, 2), V(-19, 165, 2), V(0, 176, -28), V(15, 150, -10),
              V(-15, 150, -10)],
    "head": [V(0, 222, 26), V(0, 210, 41), V(11, 210, 29), V(-11, 210, 29), V(0, 212, 15)],
    "jaw": [V(0, 196, 36)],
    "fore_l": [V(29, 128, -1), V(30, 84, 4)],
    "fore_r": [V(-29, 128, -1), V(-30, 84, 4), V(-40, 72, 6)],
    "hand_l": [V(31, 26, 13), V(31, 89, 13), V(36, 70, 13), V(26, 70, 17)],
    "hand_r": [V(-30, 72, 8)],
    "arm_l": [V(25, 179, 12), V(31, 150, 0)],
    "arm_r": [V(-25, 179, 12), V(-31, 150, 0)],
    "blade_0": [V(-27, 50, 8)], "blade_1": [V(-29.4, 48, 8)], "blade_2": [V(-31.8, 48, 8)], "blade_3": [V(-34.2, 50, 8)],
})


def skeleton(pose: Pose) -> dict[str, tuple[np.ndarray, np.ndarray]]:
    """Transformación de cada hueso (R, t): p_mundo = R p_reposo + t."""
    out: dict[str, tuple[np.ndarray, np.ndarray]] = {}
    for name, (parent, pivot) in BONES.items():
        J = np.array(pivot)
        Rl = euler(*pose.r(name))
        if parent is None:
            Rp, tp = np.eye(3), np.zeros(3)
        else:
            Rp, tp = out[parent]
        R = Rp @ Rl
        t = Rp @ J + tp - R @ J
        out[name] = (R, t)
    # Cuerpo entero: giro hacia la cámara y apoyo en el suelo.
    Ry = euler(ry=pose.yaw)
    root_t = np.array(pose.root_t)
    for name in out:
        R, t = out[name]
        out[name] = (Ry @ R, Ry @ (t + root_t))
    if pose.ground != "none":
        contacts = CONTACTS if pose.ground == "feet" else CONTACTS_ALL
        low = min((out[b][0] @ np.array(p) + out[b][1])[1] for b, pts in contacts.items() for p in pts)
        for name in out:
            R, t = out[name]
            out[name] = (R, t + np.array([0.0, -low, 0.0]))
    return out


def world_point(sk, bone: str, p) -> np.ndarray:
    R, t = sk[bone]
    return R @ np.array(p) + t


def posed_prims(pose: Pose, layers: set[str] | None = None) -> list:
    sk = skeleton(pose)
    rest = build_rest({"breath": pose.breath})
    stumps = build_stumps()
    prims = []
    for group in (rest, stumps):
        for bone, ps in group.items():
            if not ps:
                continue
            ps = [p for p in ps if layers is None or p.layer in layers]
            if not ps:
                continue
            R, t = sk[bone]
            if bone == "plunger":
                t = t + R @ np.array([0.0, -9.0 * pose.plunger, 0.0])
            prims += er.place(ps, R, t)
    return prims


# --- animaciones ----------------------------------------------------------------------------

def keys(t: float, pts: list):
    """Interpolación suave entre fotogramas clave [(t, valor)]; valor número o tupla."""
    def sm(x):
        x = min(1.0, max(0.0, x))
        return x * x * (3 - 2 * x)
    if t <= pts[0][0]:
        return pts[0][1]
    for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
        if t <= t1:
            u = sm((t - t0) / (t1 - t0)) if t1 > t0 else 1.0
            if isinstance(v0, tuple):
                return tuple(a + (b - a) * u for a, b in zip(v0, v1))
            return v0 + (v1 - v0) * u
    return pts[-1][1]


def _add(a: tuple, b: tuple, k: float = 1.0) -> tuple:
    return tuple(x + y * k for x, y in zip(a, b))


def base_pose() -> dict:
    """Postura de guardia: rodillas algo dobladas, brazos colgando un poco adelantados, la
    cabeza adelantada y ladeada, los bisturíes medio abiertos."""
    return {
        "thigh_l": (-0.16, 0.0, 0.05), "thigh_r": (-0.1, 0.0, -0.08),
        "shin_l": (0.3, 0.0, 0.0), "shin_r": (0.2, 0.0, 0.0),
        "foot_l": (-0.12, 0.12, 0.0), "foot_r": (-0.08, -0.15, 0.0),
        "root": (0.02, 0.0, 0.03),
        "lumbar": (0.06, 0.0, -0.02), "chest": (0.05, 0.0, 0.0),
        "neck": (0.0, 0.0, 0.0), "head": (-0.3, -0.12, 0.1),
        "arm_l": (-0.12, 0.0, 0.05), "fore_l": (-0.32, 0.0, 0.0), "hand_l": (0.0, 0.0, 0.0),
        "arm_r": (-0.05, 0.0, -0.12), "fore_r": (-0.25, 0.0, 0.0), "hand_r": (0.0, 0.0, 0.0),
        "blade_0": (0.0, 0.0, 0.16), "blade_1": (0.0, 0.0, 0.05), "blade_2": (0.0, 0.0, -0.06), "blade_3": (0.0, 0.0, -0.2),
        "jaw": (0.0, 0.0, 0.0),
    }


def _pose_from(rot: dict, **kw) -> Pose:
    return Pose(rot=rot, **kw)


def idle(t: float) -> Pose:
    """Respiración irregular (jadeo con un enganche), temblor, cabeza que se ladea con un tic,
    bisturíes que se abren y cierran a destiempo."""
    tau = math.tau
    breath = 0.5 + 0.32 * math.sin(tau * t) + 0.18 * math.sin(2 * tau * t + 1.1)
    breath = max(0.0, min(1.0, breath))
    trem = lambda k, ph: 0.012 * math.sin(tau * k * t + ph)  # noqa: E731
    tic = math.exp(-((t - 0.62) / 0.05) ** 2)
    rot = base_pose()
    rot["chest"] = _add(rot["chest"], (-0.05 * breath + trem(5, 0.3), 0.0, trem(7, 1.0)))
    rot["lumbar"] = _add(rot["lumbar"], (0.02 * breath, 0.0, 0.0))
    rot["clav_l"] = (0.0, 0.0, 0.05 * breath)
    rot["clav_r"] = (0.0, 0.0, -0.05 * breath)
    rot["head"] = _add(rot["head"], (0.05 * math.sin(tau * t) + trem(6, 2.0), 0.08 * math.sin(tau * t + 0.5),
                                     0.12 * math.sin(tau * t) + 0.05 * math.sin(2 * tau * t) + 0.22 * tic))
    rot["neck"] = (0.03 * math.sin(tau * t + 2), 0.0, 0.05 * tic)
    rot["jaw"] = (0.05 * breath, 0.0, 0.0)
    rot["arm_l"] = _add(rot["arm_l"], (0.03 * math.sin(tau * t + 1) + trem(9, 0.5), 0.0, trem(11, 0.0)))
    rot["fore_l"] = _add(rot["fore_l"], (0.04 * math.sin(tau * t), 0.0, 0.0))
    rot["arm_r"] = _add(rot["arm_r"], (0.04 * math.sin(tau * t + 0.4) + trem(8, 0.0), 0.0, trem(10, 1.5)))
    rot["fore_r"] = _add(rot["fore_r"], (-0.05 * math.sin(tau * t + 0.8), 0.0, 0.0))
    rot["hand_r"] = (0.0, 0.08 * math.sin(tau * t), 0.0)
    for i in range(BLADE_COUNT):
        rot[f"blade_{i}"] = _add(rot[f"blade_{i}"], (0.12 * math.sin(2 * tau * t + i * 1.3), 0.0,
                                                    0.1 * math.sin(tau * t + i * 0.9) * (1 if i % 2 else -1)))
    return _pose_from(rot, breath=breath, root_t=(0.3 * math.sin(tau * t), 0.0, 0.0))


def _blend(a: dict, b: dict, u: float) -> dict:
    out = {}
    for k in set(a) | set(b):
        va = a.get(k, (0.0, 0.0, 0.0))
        vb = b.get(k, (0.0, 0.0, 0.0))
        out[k] = tuple(x + (y - x) * u for x, y in zip(va, vb))
    return out


def windup_rot(u: float) -> dict:
    """Se encorva y levanta el brazo-instrumental por encima del hombro, bisturíes hacia arriba."""
    rot = base_pose()
    target = dict(rot)
    target.update({
        "thigh_l": (-0.42, 0.0, 0.1), "thigh_r": (-0.3, 0.0, -0.14),
        "shin_l": (0.7, 0.0, 0.0), "shin_r": (0.55, 0.0, 0.0),
        "foot_l": (-0.28, 0.12, 0.0), "foot_r": (-0.25, -0.15, 0.0),
        "root": (0.12, 0.28, 0.0),
        "lumbar": (0.16, 0.06, 0.04), "chest": (0.14, 0.1, 0.06),
        "head": (-0.12, -0.25, 0.3), "neck": (-0.05, -0.1, 0.0),
        "clav_r": (0.0, 0.0, -0.25),
        "arm_r": (0.25, -0.3, -2.25), "fore_r": (-1.35, 0.0, 0.0), "hand_r": (0.0, 0.0, 0.25),
        "arm_l": (-0.5, 0.0, 0.32), "fore_l": (-0.7, 0.0, 0.0),
        "blade_0": (0.0, 0.0, 0.35), "blade_1": (0.0, 0.0, 0.12), "blade_2": (0.0, 0.0, -0.12), "blade_3": (0.0, 0.0, -0.38),
        "jaw": (0.18, 0.0, 0.0),
    })
    return _blend(rot, target, u)


def windup(t: float) -> Pose:
    u = keys(t, [(0.0, 0.0), (0.25, 0.15), (0.85, 1.0), (1.0, 1.02)])
    tremor = 0.03 * math.sin(t * 40) * smooth_in(t, 0.6)
    rot = windup_rot(u)
    rot["arm_r"] = _add(rot["arm_r"], (tremor, 0.0, tremor))
    return _pose_from(rot, breath=0.9 * u, root_t=(0.0, 0.0, -3.0 * u))


def smooth_in(t, a):
    return min(1.0, max(0.0, (t - a) / (1 - a)))


def attack(t: float) -> Pose:
    """Tajo diagonal rápido de arriba a la derecha (su derecha) a abajo a la izquierda, con
    el cuerpo entero girando, y vuelta a la guardia."""
    start = windup_rot(1.0)
    strike = dict(start)
    strike.update({
        "thigh_l": (-0.42, 0.0, 0.16), "thigh_r": (-0.14, 0.0, -0.2),
        "shin_l": (0.68, 0.0, 0.0), "shin_r": (0.35, 0.0, 0.0),
        "foot_l": (-0.25, 0.25, 0.0), "foot_r": (-0.2, -0.3, 0.0),
        "root": (0.08, -0.22, 0.05),
        "lumbar": (0.1, -0.16, 0.0), "chest": (0.12, -0.22, -0.1),
        "head": (-0.15, 0.2, -0.05), "neck": (0.05, 0.0, 0.0),
        "clav_r": (0.0, 0.0, 0.12),
        "arm_r": (-1.3, 0.2, 0.75), "fore_r": (-0.12, 0.0, 0.0), "hand_r": (0.0, 0.3, 0.1),
        "arm_l": (0.25, 0.0, 0.5), "fore_l": (-0.4, 0.0, 0.0),
        "blade_0": (0.0, 0.0, 0.2), "blade_1": (0.0, 0.0, 0.07), "blade_2": (0.0, 0.0, -0.07), "blade_3": (0.0, 0.0, -0.22),
        "jaw": (0.25, 0.0, 0.0),
    })
    follow = dict(strike)
    follow.update({"arm_r": (-0.55, 0.3, 1.0), "fore_r": (-0.3, 0.0, 0.0), "chest": (0.16, -0.3, -0.12),
                   "root": (0.1, -0.3, 0.05), "lumbar": (0.12, -0.2, 0.0)})
    rest = base_pose()
    # 0: tensión; 1-2: golpe (muy rápido); 3-4: inercia; 5-7: vuelve.
    frames = [(0.0, start), (0.12, _blend(start, strike, 0.45)), (0.25, strike), (0.42, follow), (0.6, follow),
              (1.0, _blend(follow, rest, 0.92))]
    rot = _keyframes(t, frames)
    lunge = keys(t, [(0.0, -3.0), (0.25, 6.0), (0.6, 5.0), (1.0, 0.5)])
    return _pose_from(rot, breath=keys(t, [(0.0, 0.9), (0.3, 0.2), (1.0, 0.5)]), root_t=(0.0, 0.0, lunge))


def _keyframes(t: float, frames: list) -> dict:
    if t <= frames[0][0]:
        return dict(frames[0][1])
    for (t0, a), (t1, b) in zip(frames, frames[1:]):
        if t <= t1:
            x = (t - t0) / (t1 - t0)
            return _blend(a, b, x * x * (3 - 2 * x))
    return dict(frames[-1][1])


def attack_syringe(t: float) -> Pose:
    """Alza la jeringa como un punzón y la clava hacia delante y abajo; aprieta el émbolo."""
    rest = base_pose()
    raise_ = dict(rest)
    raise_.update({
        "root": (0.06, -0.3, 0.0), "lumbar": (0.0, -0.1, 0.05), "chest": (-0.08, -0.15, 0.08),
        "arm_l": (-2.25, 0.0, 0.3), "fore_l": (-0.75, 0.0, 0.0), "hand_l": (1.6, 0.0, 0.0),
        "clav_l": (0.0, 0.0, 0.22),
        "head": (-0.05, 0.25, -0.1), "thigh_l": (-0.2, 0.0, 0.08), "shin_l": (0.38, 0.0, 0.0),
        "arm_r": (0.15, 0.0, -0.35), "fore_r": (-0.5, 0.0, 0.0),
    })
    stab = dict(raise_)
    stab.update({
        "root": (0.1, 0.12, 0.0), "lumbar": (0.1, 0.08, 0.0), "chest": (0.16, 0.12, -0.04),
        "arm_l": (-1.25, -0.2, 0.05), "fore_l": (-0.35, 0.0, 0.0), "hand_l": (1.2, 0.0, 0.0),
        "clav_l": (0.0, 0.0, 0.0),
        "head": (0.3, -0.1, 0.1), "thigh_l": (-0.55, 0.0, 0.08), "shin_l": (0.8, 0.0, 0.0), "foot_l": (-0.25, 0.1, 0.0),
        "thigh_r": (-0.05, 0.0, -0.1), "shin_r": (0.3, 0.0, 0.0),
        "jaw": (0.2, 0.0, 0.0),
    })
    frames = [(0.0, rest), (0.3, raise_), (0.42, raise_), (0.55, stab), (0.75, stab), (1.0, _blend(stab, rest, 0.9))]
    rot = _keyframes(t, frames)
    plunger = keys(t, [(0.0, 0.0), (0.55, 0.0), (0.75, 0.85), (1.0, 0.85)])
    lunge = keys(t, [(0.0, 0.0), (0.3, -3.0), (0.55, 9.0), (0.75, 8.0), (1.0, 1.0)])
    return _pose_from(rot, breath=0.6, plunger=plunger, root_t=(0.0, 0.0, lunge))


def hit(t: float) -> Pose:
    """Recibe un golpe: el tronco y la cabeza salen despedidos hacia atrás, los brazos se
    abren, y vuelve temblando a la guardia."""
    rest = base_pose()
    snap = dict(rest)
    snap.update({
        "root": (-0.14, 0.05, -0.05), "lumbar": (-0.14, 0.0, 0.0), "chest": (-0.22, 0.12, 0.08),
        "neck": (-0.25, 0.0, 0.0), "head": (-0.45, 0.2, -0.35), "jaw": (0.35, 0.0, 0.0),
        "arm_l": (0.35, 0.0, 0.5), "fore_l": (-0.65, 0.0, 0.0),
        "arm_r": (0.3, 0.0, -0.55), "fore_r": (-0.7, 0.0, 0.0),
        "thigh_l": (-0.05, 0.0, 0.08), "shin_l": (0.22, 0.0, 0.0), "thigh_r": (-0.25, 0.0, -0.1), "shin_r": (0.45, 0.0, 0.0),
        "blade_0": (0.0, 0.0, 0.5), "blade_1": (0.0, 0.0, 0.2), "blade_2": (0.0, 0.0, -0.2), "blade_3": (0.0, 0.0, -0.5),
    })
    frames = [(0.0, _blend(rest, snap, 0.7)), (0.16, snap), (0.45, _blend(snap, rest, 0.6)), (1.0, rest)]
    rot = _keyframes(t, frames)
    shake = 0.05 * math.sin(t * 37) * (1 - t)
    rot["head"] = _add(rot["head"], (shake, 0.0, shake))
    push = keys(t, [(0.0, -4.0), (0.16, -7.0), (1.0, 0.0)])
    return _pose_from(rot, breath=1.0 - t * 0.5, root_t=(0.0, 0.0, push))


def stagger(t: float) -> Pose:
    """Pierde el equilibrio: la pierna derecha cede, el cuerpo se va hacia su derecha, los
    brazos se abren para no caer, se recompone a medias."""
    rest = base_pose()
    buckle = dict(rest)
    buckle.update({
        "thigh_r": (-0.75, 0.0, -0.05), "shin_r": (1.25, 0.0, 0.0), "foot_r": (-0.4, -0.15, 0.0),
        "thigh_l": (-0.1, 0.0, 0.32), "shin_l": (0.2, 0.0, 0.0), "foot_l": (0.0, 0.1, -0.25),
        "root": (0.12, -0.15, -0.3), "lumbar": (0.12, 0.0, 0.18), "chest": (0.1, 0.1, 0.22),
        "head": (0.2, 0.3, 0.55), "neck": (0.1, 0.0, 0.2), "jaw": (0.3, 0.0, 0.0),
        "arm_l": (-0.75, 0.0, 0.5), "fore_l": (-0.8, 0.0, 0.0),
        "arm_r": (-0.2, 0.0, -0.7), "fore_r": (-0.4, 0.0, 0.0),
        "blade_0": (0.0, 0.0, 0.45), "blade_3": (0.0, 0.0, -0.45),
    })
    catch = dict(buckle)
    catch.update({"root": (0.08, -0.08, -0.12), "chest": (0.08, 0.05, 0.05), "head": (0.15, 0.2, 0.3),
                  "thigh_r": (-0.4, 0.0, -0.08), "shin_r": (0.7, 0.0, 0.0), "arm_l": (-0.5, 0.0, 0.45)})
    frames = [(0.0, rest), (0.3, buckle), (0.45, buckle), (0.7, catch), (1.0, _blend(catch, rest, 0.85))]
    rot = _keyframes(t, frames)
    slide = keys(t, [(0.0, 0.0), (0.3, -6.0), (0.7, -4.0), (1.0, -1.0)])
    return _pose_from(rot, breath=0.8, root_t=(slide, 0.0, 0.0))


def death(t: float) -> Pose:
    """Se le doblan las rodillas, cae de rodillas, el tronco se vence hacia delante y se
    desploma de bruces hacia su izquierda; un último espasmo de los bisturíes."""
    rest = base_pose()
    knees = dict(rest)
    knees.update({
        "thigh_l": (-0.75, 0.0, 0.15), "thigh_r": (-0.6, 0.0, -0.18),
        "shin_l": (1.9, 0.0, 0.0), "shin_r": (1.85, 0.0, 0.0), "foot_l": (0.4, 0.2, 0.0), "foot_r": (0.4, -0.2, 0.0),
        "root": (0.3, 0.05, 0.05), "lumbar": (0.2, 0.0, 0.05), "chest": (0.25, 0.0, -0.1),
        "neck": (0.25, 0.0, 0.0), "head": (0.45, 0.2, 0.4), "jaw": (0.4, 0.0, 0.0),
        "arm_l": (0.05, 0.0, 0.25), "fore_l": (-0.2, 0.0, 0.0),
        "arm_r": (0.05, 0.0, -0.3), "fore_r": (-0.2, 0.0, 0.0),
    })
    fall = dict(knees)
    fall.update({
        "root": (0.45, 0.25, -1.45), "lumbar": (0.25, 0.0, 0.1), "chest": (0.2, 0.0, 0.12),
        "thigh_l": (-1.0, 0.0, 0.1), "thigh_r": (-0.7, 0.0, -0.1), "shin_l": (1.5, 0.0, 0.0), "shin_r": (1.2, 0.0, 0.0),
        "foot_l": (0.3, 0.0, 0.0), "foot_r": (0.2, 0.0, 0.0),
        "neck": (0.15, 0.0, 0.1), "head": (0.2, 0.5, 0.35),
        "arm_l": (-0.35, 0.0, -0.25), "fore_l": (-0.5, 0.0, 0.0), "hand_l": (0.0, 0.0, 0.0),
        "arm_r": (-1.35, 0.0, 0.35), "fore_r": (-0.3, 0.0, 0.0),
        "blade_0": (0.0, 0.0, 0.5), "blade_3": (0.0, 0.0, -0.5),
    })
    still = dict(fall)
    still.update({"blade_0": (0.0, 0.0, 0.1), "blade_1": (0.0, 0.0, 0.0), "blade_2": (0.0, 0.0, 0.0), "blade_3": (0.0, 0.0, -0.1),
                  "jaw": (0.5, 0.0, 0.0)})
    frames = [(0.0, rest), (0.14, _blend(rest, knees, 0.5)), (0.36, knees), (0.46, knees), (0.75, fall), (0.86, fall),
              (1.0, still)]
    rot = _keyframes(t, frames)
    slide = keys(t, [(0.0, 0.0), (0.46, 2.0), (0.75, 6.0), (1.0, 6.0)])
    side = keys(t, [(0.0, 0.0), (0.46, 0.0), (0.75, -6.0), (1.0, -6.0)])
    return _pose_from(rot, breath=keys(t, [(0.0, 0.6), (0.4, 1.0), (1.0, 0.0)]), root_t=(side, 0.0, slide),
                      ground="all" if t > 0.1 else "feet")


ANIM_FN = {"idle": idle, "windup": windup, "attack": attack, "attack_syringe": attack_syringe, "hit": hit,
           "stagger": stagger, "death": death}


def pose_at(anim: str, i: int) -> Pose:
    count, _, loop = ANIMS[anim]
    t = i / count if loop else (i / (count - 1) if count > 1 else 0.0)
    return ANIM_FN[anim](t)


# =========================================================================================
# Render
# =========================================================================================

def combat_settings() -> er.RenderSettings:
    occ = {layer: ["body"] for layer in LAYERS if layer != "body"}
    casters = {"body": ["body", "head"], "head": ["head", "body"]}
    for side in ("l", "r"):
        casters[f"arm_{side}"] = [f"arm_{side}", "body", "head"]
        casters[f"leg_{side}"] = [f"leg_{side}", "body"]
    for s in STUMPS:
        casters[s] = [s, "body"]
    contact = {"arm_l": ["body", "leg_l", "leg_r"], "arm_r": ["body", "leg_l", "leg_r"], "head": ["body"]}
    return er.RenderSettings(FRAME_W, FRAME_H, ORIGIN, er.Camera.ortho(PITCH), occluders=occ, casters=casters,
                             contact=contact, levels=32, dither=0.5)


def ground_shadow(prims: list, rs: er.RenderSettings, scale: float = 1.0) -> np.ndarray:
    """Sombra suave en el suelo: la planta del cuerpo vista desde arriba, más clara cuanto más
    alto está lo que la proyecta. Devuelve RGBA (alto, ancho, 4)."""
    res = 1.0
    W, H = rs.width, rs.height
    cam = rs.cam
    # Huella vista desde arriba en una rejilla x-z.
    span = 140 * scale
    n = int(span * 2 * res)
    top = er.Camera(np.array([1.0, 0.0, 0.0]), np.array([0.0, 0.0, -1.0]), np.array([0.0, -1.0, 0.0]),
                    np.array([0.0, 600.0, 0.0]))
    body = [p for p in prims if not p.layer.startswith("stump")]
    groups = {p.layer for p in body}
    buf = er._trace(body, top, n, n, span, span, res, sorted(groups))
    t = np.min(np.stack([buf[g][0] for g in groups]), axis=0)
    height = np.where(np.isfinite(t), 600.0 - t, np.inf).reshape(n, n)
    dens = np.where(np.isfinite(height), np.clip(1.0 - height / (90.0 * scale), 0.15, 1.0), 0.0)
    # Desenfoque.
    from PIL import ImageFilter
    img = Image.fromarray((dens * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3 * scale))
    dens = np.asarray(img).astype(np.float64) / 255.0
    out = np.zeros((H, W, 4), dtype=np.uint8)
    ys, xs = np.nonzero(dens > 0.03)
    for yy, xx in zip(ys, xs):
        x = xx / res - span
        z = yy / res - span
        u, v = cam.project((x, 0.0, z))
        px, py = int(round(rs.origin[0] + u)), int(round(rs.origin[1] - v))
        if 0 <= px < W and 0 <= py < H:
            a = int(min(1.0, dens[yy, xx]) * 150)
            if a > out[py, px, 3]:
                out[py, px] = (6, 4, 10, a)
    # Rellenar huecos de la proyección.
    a = Image.fromarray(out[..., 3]).filter(ImageFilter.MaxFilter(3))
    out[..., 3] = np.asarray(a)
    out[..., :3] = (6, 4, 10)
    return out


def render_combat_frame(anim: str, i: int) -> dict[str, tuple[bytes, bytes]]:
    pose = pose_at(anim, i)
    prims = posed_prims(pose)
    rs = combat_settings()
    imgs = er.render_layers(prims, rs, LAYERS)
    out = {layer: (img.color.tobytes(), img.normal.tobytes()) for layer, img in imgs.items()}
    sh = ground_shadow(prims, rs)
    out["shadow"] = (sh.tobytes(), None)
    return out


def _combat_job(args):
    anim, i, col = args
    t0 = time.time()
    data = render_combat_frame(anim, i)
    return col, data, time.time() - t0


def anchors() -> dict:
    """Centro en pantalla de cada parte en el fotograma de reposo (idle 0)."""
    pose = pose_at("idle", 0)
    sk = skeleton(pose)
    cam = er.Camera.ortho(PITCH)
    pts = {
        "head": ("head", HEAD_C),
        "body": ("chest", V(0, 160, 8)),
        "arm_l": ("fore_l", V(29, 118, 5)),
        "arm_r": ("fore_r", V(-31, 108, 6)),
        "leg_l": ("shin_l", V(14, 66, 3)),
        "leg_r": ("shin_r", V(-14, 66, 3)),
    }
    out = {}
    for part, (bone, p) in pts.items():
        u, v = cam.project(world_point(sk, bone, p))
        out[part] = [int(round(ORIGIN[0] + u)), int(round(ORIGIN[1] - v))]
    return out


def build_combat(procs: int, only_anims: list[str] | None = None, meta_old: dict | None = None) -> dict:
    starts = anim_starts()
    jobs = []
    for anim, (count, _, _) in ANIMS.items():
        if only_anims and anim not in only_anims:
            continue
        for i in range(count):
            jobs.append((anim, i, starts[anim] + i))
    out_dir = ROOT / OUT_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    sheets = {}
    for layer in ORDER:
        path = out_dir / f"{layer}.png"
        npath = out_dir / f"{layer}_n.png"
        size = (FRAME_W * TOTAL_FRAMES, FRAME_H)
        if only_anims and path.exists():
            c = Image.open(path).convert("RGBA")
            nimg = Image.open(npath).convert("RGBA") if npath.exists() else Image.new("RGBA", size, (128, 128, 255, 0))
        else:
            c = Image.new("RGBA", size, (0, 0, 0, 0))
            nimg = Image.new("RGBA", size, (128, 128, 255, 0))
        sheets[layer] = [c, nimg]
    start = time.time()
    with Pool(procs) as pool:
        for n, (col, data, dt) in enumerate(pool.imap_unordered(_combat_job, jobs)):
            at = (col * FRAME_W, 0)
            for layer, (cb, nb) in data.items():
                sheets[layer][0].paste(Image.frombytes("RGBA", (FRAME_W, FRAME_H), cb), at)
                if nb is not None:
                    sheets[layer][1].paste(Image.frombytes("RGBA", (FRAME_W, FRAME_H), nb), at)
            print(f"   combate {n + 1}/{len(jobs)} (col {col}, {dt:.1f} s; total {time.time() - start:.0f} s)", flush=True)
    for layer, (c, nimg) in sheets.items():
        c.save(out_dir / f"{layer}.png", optimize=True)
        if layer != "shadow":
            nimg.save(out_dir / f"{layer}_n.png", optimize=True)
    _check_edges(sheets)
    return describe_combat()


def _check_edges(sheets) -> None:
    for layer, (c, _) in sheets.items():
        a = np.asarray(c)[..., 3]
        for f in range(TOTAL_FRAMES):
            fr = a[:, f * FRAME_W:(f + 1) * FRAME_W]
            if fr[0].any() or fr[:, 0].any() or fr[:, -1].any() or fr[-1].any():
                print(f"   AVISO: la capa {layer} toca el borde en el fotograma {f}")


def describe_combat() -> dict:
    starts = anim_starts()
    return {
        "frame": [FRAME_W, FRAME_H],
        "origin": list(ORIGIN),
        "hframes": TOTAL_FRAMES,
        "vframes": 1,
        "layers": {layer: f"res://{OUT_DIR}/{layer}.png" for layer in ORDER},
        "normals": {layer: f"res://{OUT_DIR}/{layer}_n.png" for layer in LAYERS},
        "order": ORDER,
        "anims": {name: [starts[name], count, fps, loop] for name, (count, fps, loop) in ANIMS.items()},
        "anchors": anchors(),
        "stumps": {part: "stump_" + part for part in PARTS},
        "parts": {"head": "head", "torso": "body", "arm_l": "arm_l", "arm_r": "arm_r", "leg_l": "leg_l", "leg_r": "leg_r"},
    }


# --- mapa ------------------------------------------------------------------------------------

def map_pose(anim: str, i: int) -> Pose:
    """Andar arrastrando los pies (paso corto, la pierna derecha se arrastra, el tronco se
    balancea) y reposo con temblor."""
    tau = math.tau
    if anim == "idle":
        p = idle(i / MAP_ANIMS["idle"])
        p.yaw = 0.0
        return p
    t = i / MAP_ANIMS["walk"]
    s, c = math.sin(tau * t), math.cos(tau * t)
    rot = base_pose()
    rot.update({
        "thigh_l": (-0.16 - 0.32 * s, 0.0, 0.05), "thigh_r": (-0.1 + 0.18 * s, 0.0, -0.08),
        "shin_l": (0.3 + 0.45 * max(0.0, c), 0.0, 0.0), "shin_r": (0.2 + 0.12 * max(0.0, -c), 0.0, 0.0),
        "foot_l": (-0.12 + 0.2 * s, 0.12, 0.0), "foot_r": (-0.08 - 0.15 * s, -0.25, 0.0),
        "root": (0.08, 0.12 * s, 0.06 * c), "chest": (0.08, -0.1 * s, -0.05 * c),
        "head": (0.15, 0.06 * s, 0.16 + 0.1 * c),
        "arm_l": (0.2 * s - 0.1, 0.0, 0.06), "arm_r": (-0.12 * s - 0.05, 0.0, -0.14),
    })
    return Pose(rot=rot, breath=0.5 + 0.3 * s, root_t=(1.2 * c, 0.0, 0.0), yaw=0.0)


def _map_yaws() -> list[float]:
    # Mismo orden que el protagonista: la fila 0 mira abajo (a cámara) y gira hacia la izquierda.
    return [-i * math.tau / MAP_DIRS for i in range(MAP_DIRS)]


def _map_prims(pose: Pose, yaw: float, drop: set[str] = frozenset()) -> list:
    pose.yaw = yaw
    prims = [p for p in posed_prims(pose) if not p.layer.startswith("stump") or p.layer[6:] in drop]
    prims = [p for p in prims if p.layer not in drop]
    k = MAP_SCALE
    out = []
    for p in prims:
        # place() con R = k·I escala posiciones y la transformación de textura; los radios
        # y la base (que debe seguir siendo ortonormal) se arreglan a mano.
        q = er.place([p], np.eye(3) * k, np.zeros(3))[0]
        if hasattr(q, "radii"):
            q.radii = tuple(r * k for r in p.radii)
        if hasattr(q, "r"):
            q.r = p.r * k
        if hasattr(q, "half"):
            q.half = tuple(h * k for h in p.half)
        if hasattr(q, "basis"):
            q.basis = p.basis
        q.bound = p.bound * k
        q.layer = "map"
        out.append(q)
    return out


def map_settings(w, h, origin) -> er.RenderSettings:
    return er.RenderSettings(w, h, origin, er.Camera.oblique(1.0, 0.45), lighting=er.MAP_LIGHTING, ss=3, levels=12,
                             dither=0.6, outline=True, casters={"map": ["map"]}, saturation=0.85)


def render_map_frame(anim: str, i: int, row: int) -> tuple[bytes, bytes]:
    pose = map_pose(anim, i)
    prims = _map_prims(pose, _map_yaws()[row])
    imgs = er.render_layers(prims, map_settings(*MAP_FRAME, MAP_ORIGIN), ["map"])
    return imgs["map"].color.tobytes(), imgs["map"].normal.tobytes()


def corpse_pose(variant: str) -> Pose:
    p = death(1.0)
    return p


def render_corpse(variant: str) -> tuple[bytes, bytes]:
    pose = corpse_pose(variant)
    drop = {"arm_r"} if variant == "no_arm_r" else set()
    pose.ground = "all"
    prims = _map_prims(pose, -0.6, drop)
    imgs = er.render_layers(prims, map_settings(*CORPSE_FRAME, CORPSE_ORIGIN), ["map"])
    return imgs["map"].color.tobytes(), imgs["map"].normal.tobytes()


def _map_job(args):
    kind, anim, i, row, col = args
    if kind == "corpse":
        return kind, row, col, render_corpse(anim)
    return kind, row, col, render_map_frame(anim, i, row)


def build_map(procs: int) -> dict:
    out_dir = ROOT / OUT_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    cols = sum(MAP_ANIMS.values())
    jobs = []
    for row in range(MAP_DIRS):
        col = 0
        for anim, count in MAP_ANIMS.items():
            for i in range(count):
                jobs.append(("map", anim, i, row, col))
                col += 1
    for k, variant in enumerate(CORPSE_VARIANTS):
        jobs.append(("corpse", variant, 0, 0, k))
    mw, mh = MAP_FRAME
    cw, ch = CORPSE_FRAME
    sheet = [Image.new("RGBA", (mw * cols, mh * MAP_DIRS), (0, 0, 0, 0)), Image.new("RGBA", (mw * cols, mh * MAP_DIRS), (128, 128, 255, 0))]
    corpse = [Image.new("RGBA", (cw * len(CORPSE_VARIANTS), ch), (0, 0, 0, 0)),
              Image.new("RGBA", (cw * len(CORPSE_VARIANTS), ch), (128, 128, 255, 0))]
    with Pool(procs) as pool:
        for kind, row, col, (cb, nb) in pool.imap_unordered(_map_job, jobs):
            if kind == "corpse":
                corpse[0].paste(Image.frombytes("RGBA", CORPSE_FRAME, cb), (col * cw, 0))
                corpse[1].paste(Image.frombytes("RGBA", CORPSE_FRAME, nb), (col * cw, 0))
            else:
                sheet[0].paste(Image.frombytes("RGBA", MAP_FRAME, cb), (col * mw, row * mh))
                sheet[1].paste(Image.frombytes("RGBA", MAP_FRAME, nb), (col * mw, row * mh))
    sheet[0].save(out_dir / "map.png", optimize=True)
    sheet[1].save(out_dir / "map_n.png", optimize=True)
    corpse[0].save(out_dir / "corpse.png", optimize=True)
    corpse[1].save(out_dir / "corpse_n.png", optimize=True)
    return describe_map()


def describe_map() -> dict:
    anims, col = {}, 0
    fps = {"idle": 5.0, "walk": 7.0}
    for name, count in MAP_ANIMS.items():
        anims[name] = [col, count, fps[name], True]
        col += count
    return {
        "path": f"res://{OUT_DIR}/map.png",
        "normal": f"res://{OUT_DIR}/map_n.png",
        "frame": list(MAP_FRAME),
        "origin": list(MAP_ORIGIN),
        "hframes": col,
        "vframes": MAP_DIRS,
        "directions": MAP_DIRS,
        "anims": anims,
        "corpse": {
            "path": f"res://{OUT_DIR}/corpse.png",
            "normal": f"res://{OUT_DIR}/corpse_n.png",
            "frame": list(CORPSE_FRAME),
            "origin": list(CORPSE_ORIGIN),
            "hframes": len(CORPSE_VARIANTS),
            "variants": CORPSE_VARIANTS,
        },
    }


# =========================================================================================

def main() -> None:
    args = sys.argv[1:]
    only, procs, anims = None, max(1, (os.cpu_count() or 2) - 1), None
    while args:
        a = args.pop(0)
        if a == "--only":
            only = args.pop(0)
        elif a == "--procs":
            procs = int(args.pop(0))
        elif a == "--anims":
            anims = args.pop(0).split(",")
    meta_path = ROOT / "tools/art/sprite_meta.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    if only in (None, "combat"):
        meta["enemy_enfermero"] = build_combat(procs, anims, meta.get("enemy_enfermero"))
    if only in (None, "map"):
        meta["enemy_enfermero_map"] = build_map(procs)
    meta_path.write_text(json.dumps(meta, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
