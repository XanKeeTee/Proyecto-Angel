"""Modelo del protagonista (paciente recién operado) para pxrender.

Proporciones realistas: ~58 px de alto, cabeza ~1/7 de la altura, postura encorvada.
Detalles propios del proyecto (ver docs/art/guia-estetica.md):
  - cabeza rapada con cicatriz cosida en el cráneo,
  - ojos hundidos,
  - bata abierta por detrás: incisión cosida a lo largo de la columna,
  - pieza metálica entre los omóplatos [PROPUESTA],
  - vía arrancada con sangre en la mano izquierda, pulsera de paciente en la derecha,
  - pies descalzos y sucios.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

from pxrender import (
    basis_rot, cross, dot, length, lerp, rot_y, rot_z, transform,
    Mat3, Prim, Vec, add, basis_from_y, box, capsule, cylinder, ellipsoid, fbm, limb, mul, norm,
    ramp, rot_x, sphere, sub, to_local, to_world,
)

# --- rampas ---------------------------------------------------------------------

ramp("skin", [(36, 24, 28), (58, 40, 44), (86, 62, 62), (116, 90, 84), (146, 118, 106), (174, 146, 130), (198, 172, 154)])
ramp("skin_bruise", [(32, 22, 34), (52, 36, 54), (74, 54, 72), (98, 76, 90), (122, 98, 106)])
ramp("skin_dirty", [(28, 22, 22), (46, 36, 34), (68, 54, 48), (92, 76, 66), (116, 98, 84), (138, 118, 100)])
ramp("scalp", [(24, 20, 24), (40, 34, 38), (58, 50, 52), (78, 68, 68), (98, 88, 84), (118, 106, 98)])
ramp("socket", [(14, 8, 12), (26, 16, 20), (40, 28, 32), (56, 40, 44)])
ramp("lips", [(44, 26, 30), (66, 42, 44), (90, 60, 60), (112, 80, 76)])
ramp("wound", [(28, 6, 10), (54, 12, 18), (86, 22, 28), (118, 38, 40), (144, 60, 56)])
ramp("thread", [(12, 10, 14), (26, 22, 26), (42, 38, 42)])
ramp("gown", [(38, 38, 42), (60, 60, 62), (86, 86, 84), (114, 112, 106), (142, 140, 130), (170, 166, 154), (196, 192, 178)])
ramp("gown_print", [(36, 42, 50), (54, 62, 70), (76, 86, 92), (98, 110, 114), (122, 132, 134)])
ramp("stain", [(42, 36, 24), (66, 58, 38), (92, 82, 54), (118, 106, 72), (142, 130, 92)])
ramp("blood_dry", [(24, 8, 10), (42, 12, 16), (64, 18, 22), (88, 28, 30), (110, 44, 42)])
ramp("metal", [(20, 22, 26), (40, 44, 48), (66, 70, 74), (98, 102, 104), (138, 142, 142), (182, 184, 180)])
ramp("grip", [(12, 12, 14), (22, 22, 26), (34, 34, 38), (48, 48, 52)])
ramp("lens", [(200, 180, 120), (236, 222, 170), (255, 248, 220)])
ramp("band", [(36, 48, 56), (62, 78, 86), (94, 112, 118), (130, 146, 148), (166, 178, 178)])

FRAME_W, FRAME_H = 48, 68
ORIGIN = (24, 62)


def _frac(x: float) -> float:
    return x - math.floor(x)


# --- materiales -----------------------------------------------------------------

def skin_mat(p: Vec, n: Vec) -> tuple:
    bright = 0.9 + 0.16 * fbm(mul(p, 0.4), 3)
    if p[1] < 6.5:
        return ("skin_dirty", bright * (0.85 + 0.1 * fbm(mul(p, 0.9), 4)))
    if p[1] < 14 and fbm(mul(p, 0.3), 8) > 0.7:
        return ("skin_bruise", bright)
    return ("skin", bright)


def torso_skin_mat(p: Vec, n: Vec) -> tuple:
    """Espalda: incisión cosida sobre la columna."""
    x, y, z = p
    if z < -1.2 and 32.0 < y < 45.0:
        ax = abs(x + 0.15 * math.sin(y * 0.9))
        if ax < 0.45:
            return ("wound", 0.95)
        if ax < 1.2 and _frac(y / 1.45) < 0.38:
            return ("thread", 1.0)
        if ax < 2.4:
            return ("skin_bruise", 0.95 + 0.1 * fbm(mul(p, 0.7), 2))
    return skin_mat(p, n)


def make_head_mat(center: Vec):
    def head_mat(p: Vec, n: Vec) -> tuple:
        r = sub(p, center)
        # Cicatriz del cráneo: línea coronal ligeramente oblicua con puntos.
        line = r[2] + 0.18 * r[0] - 0.2
        if r[1] > 1.0:
            if abs(line) < 0.36:
                return ("wound", 0.9)
            if abs(line) < 0.95 and _frac(r[0] / 1.05) < 0.3:
                return ("thread", 1.0)
        if r[1] > -0.4 and r[2] < 2.4:
            return ("scalp", 0.85 + 0.25 * fbm(mul(p, 1.3), 11))
        # Ojos hundidos.
        if n[2] > 0.3:
            for ex in (-1.22, 1.22):
                dd = (r[0] - ex) ** 2 + ((r[1] + 0.95) * 1.35) ** 2
                if dd < 0.62:
                    return ("socket", 0.7)
                if dd < 1.7:
                    return ("skin", 0.62)
        return skin_mat(p, n)
    return head_mat


def make_face_mat(center: Vec):
    def face_mat(p: Vec, n: Vec) -> tuple:
        r = sub(p, center)
        if n[2] > 0.45 and abs(r[0]) < 1.0 and abs(r[1] + 0.55) < 0.3:
            return ("lips", 0.85)
        if abs(r[0]) > 1.4 and n[2] > 0.2:
            return ("skin", 0.8)  # mejillas hundidas
        return skin_mat(p, n)
    return face_mat


def gown_mat(p: Vec, n: Vec) -> tuple:
    x, y, z = p
    # Pliegues verticales: perturban la normal.
    fold = math.sin(x * 1.25 + z * 0.8 + 3.0 * fbm(mul(p, 0.12), 21))
    strength = 0.38 if y < 31 else 0.16
    n2 = norm(add(n, (fold * strength, 0.0, 0.0)))
    bright = 1.0 + 0.08 * fold
    if y < 20:
        bright *= 0.8 + 0.15 * fbm(mul(p, 0.6), 23)
    if z < -0.3 and abs(x) < 3.2 and y < 42:
        if fbm(mul(p, 0.38), 9) > 0.62 - (3.2 - abs(x)) * 0.09:
            return ("blood_dry", bright, n2)
    if fbm(mul(p, 0.16), 5) > 0.64:
        return ("stain", bright, n2)
    u = x + z * 0.6
    if _frac(u / 3.2) < 0.2 and _frac(y / 3.2) < 0.2:
        return ("gown_print", bright, n2)
    return ("gown", bright, n2)


def gown_slice_mat(p: Vec, n: Vec) -> tuple:
    """La bata se modela en rodajas: se aplana la componente vertical de la normal
    para que no se vean escalones horizontales."""
    flat = norm((n[0], n[1] * 0.15, n[2]))
    return gown_mat(p, flat)


def gown_cut(p: Vec) -> bool:
    x, y, z = p
    if z < -0.8 and abs(x) < 1.35 + max(0.0, 30.0 - y) * 0.05 and y > 22.0:
        return True  # abertura de la espalda
    if y > 46.4 and abs(x) < 2.5:
        return True  # cuello
    return False


def metal_mat(p: Vec, n: Vec) -> tuple:
    return ("metal", 1.05)


def band_mat(p: Vec, n: Vec) -> tuple:
    return ("band", 1.0)


def tape_mat(p: Vec, n: Vec) -> tuple:
    return ("gown", 1.12)


# --- ropa ----------------------------------------------------------------------------
# Cada prenda se renderiza en su propia capa encima del cuerpo (ver tools/art/character.py).
# id -> capa. Los ids coinciden con los objetos de data/items.
GARMENTS: dict[str, str] = {
    "bata_paciente": "body",
    "chaqueta_celador": "body",
    "bata_medico": "body",
    "pantalon_pijama": "legs",
    "pantalon_celador": "legs",
    "zapatillas": "feet",
    "botas_goma": "feet",
    "gorro_quirurgico": "head",
    "gorro_lana": "head",
}

ramp("underwear", [(44, 42, 44), (70, 68, 68), (100, 96, 92), (130, 126, 118), (158, 152, 142)])
ramp("uniform", [(14, 30, 32), (22, 46, 48), (32, 64, 64), (46, 86, 84), (64, 108, 102), (88, 132, 122)])
ramp("labcoat", [(52, 52, 56), (84, 84, 86), (118, 116, 112), (152, 148, 140), (184, 180, 168), (210, 206, 192),
                 (228, 224, 210)])
ramp("pajama", [(28, 34, 46), (42, 52, 66), (60, 72, 88), (82, 96, 110), (106, 120, 132), (132, 144, 152)])
ramp("pajama_stripe", [(22, 24, 36), (34, 38, 54), (50, 56, 74), (68, 76, 94)])
ramp("slipper", [(34, 38, 42), (54, 60, 64), (78, 84, 86), (104, 110, 110), (130, 134, 132)])
ramp("rubber", [(8, 12, 10), (16, 24, 20), (26, 38, 32), (40, 56, 46), (60, 78, 64), (88, 104, 88)])
ramp("scrub", [(16, 38, 46), (24, 56, 66), (36, 80, 90), (52, 106, 114), (72, 132, 136)])
ramp("wool", [(16, 18, 24), (26, 30, 38), (40, 44, 54), (56, 62, 72), (76, 82, 90)])
ramp("zip", [(30, 32, 34), (70, 72, 72), (128, 128, 124), (182, 180, 172)])
ramp("occ", [(255, 0, 255)])


def _fold(p: Vec, n: Vec, freq: float, strength: float, seed: int) -> tuple[Vec, float]:
    """Pliegues de tela: perturba la normal con ondas irregulares."""
    fold = math.sin(p[0] * freq + p[2] * 0.8 * freq + 3.0 * fbm(mul(p, 0.12), seed))
    return norm(add(n, (fold * strength, 0.0, 0.0))), 1.0 + 0.07 * fold


def _flat(n: Vec) -> Vec:
    return norm((n[0], n[1] * 0.15, n[2]))


def underwear_mat(p: Vec, n: Vec) -> tuple:
    n2, b = _fold(p, n, 1.6, 0.2, 31)
    return ("underwear", b * (0.9 + 0.1 * fbm(mul(p, 0.5), 32)), n2)


def jacket_mat(p: Vec, n: Vec) -> tuple:
    x, y, z = p
    n2, b = _fold(_flat(n) if y < 46 else n, n, 1.1, 0.3, 41)
    if z > 1.0 and abs(x - 0.3) < 0.4 and 27.5 < y < 46.5:
        return ("zip", 1.05 + 0.25 * (_frac(y / 0.9) < 0.5))  # cremallera
    if z > 1.5 and -5.0 < x < -1.6 and 38.0 < y < 41.5:  # bolsillo del pecho
        edge = y > 41.0 or x > -1.9 or x < -4.7
        return ("uniform", b * (0.72 if edge else 0.95), n2)
    if fbm(mul(p, 0.2), 43) > 0.68:
        return ("stain", b, n2)
    return ("uniform", b * (0.92 + 0.12 * fbm(mul(p, 0.7), 44)), n2)


def sleeve_jacket_mat(p: Vec, n: Vec) -> tuple:
    n2, b = _fold(p, n, 2.2, 0.35, 45)
    return ("uniform", b * (0.92 + 0.1 * fbm(mul(p, 0.7), 46)), n2)


def labcoat_mat(p: Vec, n: Vec) -> tuple:
    x, y, z = p
    n2, b = _fold(_flat(n) if y < 45 else n, n, 1.0, 0.36 if y < 31 else 0.2, 51)
    if z > 1.6 and 3.0 < abs(x) < 6.2 and 23.0 < y < 26.8:  # bolsillos
        return ("labcoat", b * (0.78 if y > 26.4 else 0.95), n2)
    if z > 0.0 and fbm(mul(p, 0.33), 52) > 0.7:
        return ("blood_dry", b, n2)
    if fbm(mul(p, 0.15), 53) > 0.66:
        return ("stain", b, n2)
    return ("labcoat", b * (0.94 + 0.08 * fbm(mul(p, 0.6), 54)), n2)


def sleeve_labcoat_mat(p: Vec, n: Vec) -> tuple:
    n2, b = _fold(p, n, 2.0, 0.35, 55)
    return ("labcoat", b * (0.93 + 0.08 * fbm(mul(p, 0.6), 56)), n2)


def pajama_mat(p: Vec, n: Vec) -> tuple:
    n2, b = _fold(p, n, 1.4, 0.3, 61)
    if _frac((p[0] + p[2] * 0.7) / 2.6) < 0.22:
        return ("pajama_stripe", b, n2)
    return ("pajama", b * (0.92 + 0.1 * fbm(mul(p, 0.6), 62)), n2)


def trousers_mat(p: Vec, n: Vec) -> tuple:
    n2, b = _fold(p, n, 1.2, 0.32, 63)
    if 14.0 < p[1] < 17.5 and p[2] > 0.5:  # rodillera gastada
        return ("uniform", b * 1.12, n2)
    if fbm(mul(p, 0.25), 64) > 0.7:
        return ("stain", b * 0.9, n2)
    return ("uniform", b * (0.88 + 0.12 * fbm(mul(p, 0.7), 65)), n2)


def slipper_mat(p: Vec, n: Vec) -> tuple:
    bright = 0.9 + 0.2 * fbm(mul(p, 1.2), 71)
    if n[1] < -0.4:
        return ("rubber", 0.8)
    return ("slipper", bright)


def boot_mat(p: Vec, n: Vec) -> tuple:
    if p[1] < 1.0:
        return ("rubber", 0.6)  # suela
    if fbm(mul(p, 0.4), 72) > 0.66:
        return ("stain", 0.7)  # barro seco
    return ("rubber", 0.95 + 0.25 * max(0.0, n[0] * -0.5 + n[2] * 0.4))


def scrub_mat(p: Vec, n: Vec) -> tuple:
    n2, b = _fold(p, n, 1.8, 0.25, 81)
    return ("scrub", b * (0.92 + 0.1 * fbm(mul(p, 0.8), 82)), n2)


def wool_mat(p: Vec, n: Vec) -> tuple:
    rib = math.sin(math.atan2(p[0], p[2] + 0.001) * 18.0)
    n2 = norm(add(n, (rib * 0.3, 0.0, 0.0)))
    return ("wool", 0.92 + 0.1 * rib + 0.1 * fbm(mul(p, 1.4), 83), n2)


def _hat(name: str, head_c: Vec) -> list[Prim]:
    prims: list[Prim] = []
    if name == "gorro_quirurgico":
        top = head_c[1] - 0.1

        def cut_cap(p: Vec, _top=top, _c=head_c) -> bool:
            return p[1] < _top + max(0.0, (p[2] - _c[2]) * 0.55)  # más alto por delante (despeja la frente)
        prims.append(ellipsoid(add(head_c, (0.0, 0.55, -0.25)), (3.7, 3.6, 4.15), scrub_mat, cut=cut_cap))
        prims.append(sphere(add(head_c, (0.0, -0.2, -4.0)), 0.75, scrub_mat))  # nudo
        prims.append(capsule(add(head_c, (0.0, -0.4, -4.1)), add(head_c, (0.5, -2.4, -4.0)), 0.4, scrub_mat))
        prims.append(capsule(add(head_c, (0.0, -0.4, -4.1)), add(head_c, (-0.6, -2.1, -3.9)), 0.4, scrub_mat))
    elif name == "gorro_lana":
        rim_y = head_c[1] + 0.55

        def cut_beanie(p: Vec, _y=rim_y) -> bool:
            return p[1] < _y
        prims.append(ellipsoid(add(head_c, (0.0, 0.7, -0.2)), (3.8, 3.85, 4.2), wool_mat, cut=cut_beanie))
        for i in range(16):
            a = i / 16 * math.tau
            prims.append(sphere(add(head_c, (math.sin(a) * 3.7, 0.75, -0.2 + math.cos(a) * 4.05)), 0.85, wool_mat))
    return prims


# --- modelo ---------------------------------------------------------------------
# Coordenadas del modelo: pies en el origen, x = izquierda del personaje, y arriba, z hacia
# donde mira. 1 unidad = 1 px. Longitudes de los huesos:
THIGH, SHIN = 13.4, 12.9
UPPER_ARM, FOREARM, PALM = 11.2, 9.8, 1.9
HIP_Y = 29.4


def _clamp01(x: float) -> float:
    return 0.0 if x < 0.0 else 1.0 if x > 1.0 else x


def smooth(x: float) -> float:
    """Curva suave 0..1 (entra y sale despacio)."""
    x = _clamp01(x)
    return x * x * (3 - 2 * x)


def _mix(a, b, u: float):
    if isinstance(a, tuple):
        return tuple(x + (y - x) * u for x, y in zip(a, b))
    return a + (b - a) * u


def keys(t: float, pts: list):
    """Interpolación suave entre fotogramas clave [(tiempo, valor), ...]; el valor puede ser
    un número o una tupla."""
    if t <= pts[0][0]:
        return pts[0][1]
    for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
        if t <= t1:
            return _mix(v0, v1, smooth((t - t0) / (t1 - t0)) if t1 > t0 else 1.0)
    return pts[-1][1]


def _leg(hip: Vec, swing: float, bend: float, abduct: float = 0.0, side: float = 1.0) -> tuple[Vec, Vec, Vec]:
    thigh = (0.0, -math.cos(swing), math.sin(swing))
    shin_a = swing - bend
    shin = (0.0, -math.cos(shin_a), math.sin(shin_a))
    if abduct:
        thigh = rot_z(thigh, side * abduct)
        shin = rot_z(shin, side * abduct)
    knee = add(hip, mul(thigh, THIGH))
    ankle = add(knee, mul(shin, SHIN))
    return hip, knee, ankle


def leg_ik(dz: float, dy: float) -> tuple[float, float]:
    """(swing, bend) para que el tobillo quede `dz` por delante y `dy` por debajo de la cadera
    (rodilla hacia delante)."""
    length_ = max(abs(THIGH - SHIN) + 0.05, min(THIGH + SHIN - 0.02, math.hypot(dz, dy)))
    phi = math.atan2(dz, dy)
    alpha = math.acos(max(-1.0, min(1.0, (THIGH ** 2 + length_ ** 2 - SHIN ** 2) / (2 * THIGH * length_))))
    beta = math.acos(max(-1.0, min(1.0, (SHIN ** 2 + length_ ** 2 - THIGH ** 2) / (2 * SHIN * length_))))
    return phi + alpha, alpha + beta


def _arm(shoulder: Vec, side: float, swing: float, flex: float, abduct: float = 0.1) -> tuple[Vec, Vec, Vec, Vec]:
    upper = norm((side * abduct, -math.cos(swing), math.sin(swing)))
    elbow = add(shoulder, mul(upper, UPPER_ARM))
    fore_ang = swing + flex
    fore = norm((side * (0.04 + abduct * 0.4), -math.cos(fore_ang), math.sin(fore_ang)))
    wrist = add(elbow, mul(fore, FOREARM))
    return shoulder, elbow, wrist, fore


def arm_ik(shoulder: Vec, side: float, palm: Vec, pole: Vec | None = None) -> tuple[Vec, Vec, Vec, Vec]:
    """Brazo de dos huesos que lleva la palma a `palm`. El codo se abre hacia `pole`
    (por defecto: hacia fuera, atrás y abajo). Si no llega, el brazo se estira hacia el punto."""
    pole = pole or (side * 0.6, -0.4, -0.7)
    fore = norm(sub(palm, shoulder))
    elbow = wrist = shoulder
    for _ in range(3):
        wrist_t = sub(palm, mul(fore, PALM))
        d_vec = sub(wrist_t, shoulder)
        d = max(abs(UPPER_ARM - FOREARM) + 0.05, min(UPPER_ARM + FOREARM - 0.05, length(d_vec)))
        direction = norm(d_vec)
        cos_a = (UPPER_ARM ** 2 + d * d - FOREARM ** 2) / (2 * UPPER_ARM * d)
        sin_a = math.sqrt(max(0.0, 1 - cos_a * cos_a))
        p = sub(pole, mul(direction, dot(pole, direction)))
        p = norm(p) if length(p) > 1e-6 else norm(cross(direction, (1.0, 0.0, 0.0)))
        elbow = add(shoulder, add(mul(direction, UPPER_ARM * cos_a), mul(p, UPPER_ARM * sin_a)))
        wrist = add(shoulder, mul(direction, d))
        fore = norm(sub(wrist, elbow))
    return shoulder, elbow, wrist, fore


@dataclass
class Pose:
    """Postura completa. Lado 1.0 = izquierda del personaje (x+), -1.0 = derecha."""
    leg_swing: dict = field(default_factory=lambda: {1.0: 0.0, -1.0: 0.0})
    leg_bend: dict = field(default_factory=lambda: {1.0: 0.06, -1.0: 0.06})
    ## Separación lateral de cada pierna (radianes, hacia fuera).
    leg_abduct: dict = field(default_factory=lambda: {1.0: 0.0, -1.0: 0.0})
    foot_pitch: dict = field(default_factory=lambda: {1.0: 0.0, -1.0: 0.0})
    arm_swing: dict = field(default_factory=lambda: {1.0: 0.0, -1.0: 0.0})
    arm_flex: dict = field(default_factory=lambda: {1.0: 0.2, -1.0: 0.2})
    arm_abduct: dict = field(default_factory=lambda: {1.0: 0.1, -1.0: 0.1})
    ## Si hay objetivo, la palma de esa mano va ahí (cinemática inversa); coordenadas del modelo
    ## con los pies en el origen, ya con el tronco inclinado. `hand_pole`: hacia dónde se abre el codo.
    hand_target: dict = field(default_factory=dict)
    hand_pole: dict = field(default_factory=dict)
    sway_x: float = 0.0
    breath: float = 0.0
    spread: float = 0.0
    ## Giro de la pelvis y de los hombros (radianes, alrededor del eje vertical).
    hip_twist: float = 0.0
    shoulder_twist: float = 0.0
    ## Cabeza: giro (mirar a los lados) e inclinación (positivo = mirar abajo).
    head_yaw: float = 0.0
    head_pitch: float = 0.0
    ## Inclinación del tronco hacia delante (unidades en z a la altura de los hombros).
    lean: float = 0.6
    ## Flexión real del tronco desde la cintura (radianes, + = hacia delante) e inclinación
    ## lateral (+ = hacia su izquierda).
    pitch: float = 0.0
    roll: float = 0.0
    ## Giro de piernas y pelvis respecto al tronco (paso lateral: la cadera mira hacia donde anda).
    lower_yaw: float = 0.0
    flashlight: bool = False
    ## Dónde va la linterna: "hand" (mano derecha) o "tucked" (sujeta bajo el brazo derecho).
    flash_mode: str = "hand"
    ## Objeto en las manos durante una acción: "", "key", "crowbar".
    prop: str = ""
    sitting: bool = False
    ## Altura de la articulación de la cadera sobre el suelo; None = la calculan las piernas
    ## (el pie más bajo toca el suelo).
    hip_height: float | None = None
    ## Giro y desplazamiento de todo el cuerpo (levantarse de la camilla, acercarse al objeto).
    body_rx: float = 0.0
    body_ry: float = 0.0
    body_rz: float = 0.0
    root: Vec = (0.0, 0.0, 0.0)


# Brazo derecho al frente sujetando la linterna.
FLASH_SWING = 0.3
FLASH_FLEX = 1.2


def walk_pose(t: float, flashlight: bool = False) -> Pose:
    """Ciclo de paso (t en 0..1), con giro de cadera, contragiro de hombros, apoyo de talón
    y despegue de dedos, brazos con retraso y cabeza estabilizada. Cojea: la pierna derecha
    da el paso más corto."""
    s, c = math.sin(math.tau * t), math.cos(math.tau * t)
    lag = math.sin(math.tau * (t - 0.06))
    pose = Pose(flashlight=flashlight)
    pose.leg_swing = {1.0: 0.36 * s, -1.0: -0.29 * s}
    pose.leg_bend = {1.0: 0.06 + 0.58 * max(0.0, c) ** 1.2, -1.0: 0.06 + 0.5 * max(0.0, -c) ** 1.2}
    pose.foot_pitch = {1.0: -0.42 * s, -1.0: 0.36 * s}
    pose.arm_swing = {1.0: -0.26 * lag, -1.0: 0.22 * lag}
    pose.arm_flex = {1.0: 0.18 + 0.16 * max(0.0, -lag), -1.0: 0.18 + 0.14 * max(0.0, lag)}
    pose.hip_twist = -0.13 * s
    pose.shoulder_twist = 0.1 * s
    pose.head_yaw = -0.05 * s
    pose.head_pitch = 0.05 + 0.03 * math.sin(2 * math.tau * t)
    pose.sway_x = 0.5 * c
    pose.spread = abs(s)
    pose.lean = 0.9
    if flashlight:
        pose.arm_swing[-1.0] = FLASH_SWING + 0.03 * math.sin(2 * math.tau * t)
        pose.arm_flex[-1.0] = FLASH_FLEX
        pose.shoulder_twist *= 0.5
    return pose


def idle_pose(t: float, flashlight: bool = False) -> Pose:
    """Respiración en reposo (t en 0..1): pecho y hombros suben, peso que oscila un poco."""
    pose = Pose(flashlight=flashlight)
    b = (1 - math.cos(math.tau * t)) / 2
    pose.breath = b
    pose.arm_flex = {1.0: 0.2 + 0.05 * b, -1.0: 0.2 + 0.05 * b}
    pose.sway_x = 0.2 * math.sin(math.tau * t)
    pose.head_pitch = 0.06 - 0.03 * b
    pose.leg_bend = {1.0: 0.12, -1.0: 0.04}  # carga el peso en la pierna buena
    if flashlight:
        pose.arm_swing[-1.0] = FLASH_SWING + 0.03 * b
        pose.arm_flex[-1.0] = FLASH_FLEX
    return pose


def fidget_pose(t: float) -> Pose:
    """Gesto en reposo sin linterna: se lleva la mano izquierda a la herida de la espalda y mira al suelo."""
    e = math.sin(math.pi * t) ** 1.5
    pose = idle_pose(t)
    pose.arm_swing[1.0] = -1.15 * e
    pose.arm_flex[1.0] = 0.2 + 1.7 * e
    pose.arm_abduct[1.0] = 0.1 + 0.12 * e
    pose.head_pitch = 0.06 + 0.3 * e
    pose.head_yaw = 0.3 * e
    pose.shoulder_twist = 0.15 * e
    pose.lean = 0.6 + 0.5 * e
    return pose


def look_pose(t: float) -> Pose:
    """Gesto en reposo con linterna: mira a un lado y a otro."""
    pose = idle_pose(t, True)
    turn = math.sin(math.tau * t)
    pose.head_yaw = 0.75 * turn
    pose.shoulder_twist = 0.18 * turn
    pose.arm_swing[-1.0] = FLASH_SWING + 0.1 * abs(turn)
    return pose


def walk_back_pose(t: float, flashlight: bool = False) -> Pose:
    """Andar de espaldas (t en 0..1): el ciclo de paso invertido, pero con el paso más corto,
    la punta del pie apoyando primero, rodillas algo más flexionadas, el tronco echado atrás
    y los brazos separados para equilibrarse. Sigue cojeando de la derecha."""
    s, c = math.sin(math.tau * t), math.cos(math.tau * t)
    lag = math.sin(math.tau * (t - 0.08))
    pose = Pose(flashlight=flashlight)
    # Fase invertida: la pierna que pasa por debajo va hacia atrás.
    pose.leg_swing = {1.0: -0.27 * s, -1.0: 0.21 * s}
    pose.leg_bend = {1.0: 0.14 + 0.5 * max(0.0, c) ** 1.2, -1.0: 0.12 + 0.44 * max(0.0, -c) ** 1.2}
    # Punta abajo cuando el pie busca el suelo por detrás; talón que se despega el último delante.
    pose.foot_pitch = {1.0: 0.5 * max(0.0, s) - 0.22 * max(0.0, -s), -1.0: 0.44 * max(0.0, -s) - 0.2 * max(0.0, s)}
    pose.arm_swing = {1.0: 0.12 + 0.1 * lag, -1.0: 0.12 - 0.08 * lag}
    pose.arm_flex = {1.0: 0.42 + 0.06 * lag, -1.0: 0.42 - 0.06 * lag}
    pose.arm_abduct = {1.0: 0.3 + 0.04 * c, -1.0: 0.3 - 0.04 * c}
    pose.hip_twist = 0.09 * s
    pose.shoulder_twist = -0.06 * s
    pose.head_yaw = 0.04 * s
    pose.head_pitch = 0.1
    pose.sway_x = 0.7 * c  # se balancea más: no ve dónde pisa
    pose.spread = 0.7 * abs(s)
    pose.lean = 0.1
    pose.pitch = -0.07
    if flashlight:
        pose.arm_swing[-1.0] = FLASH_SWING + 0.04 * math.sin(2 * math.tau * t)
        pose.arm_flex[-1.0] = FLASH_FLEX
        pose.arm_abduct[-1.0] = 0.12
    return pose


def strafe_pose(t: float, direction: float, flashlight: bool = False) -> Pose:
    """Paso lateral hacia su izquierda (`direction` = 1) o su derecha (-1): la cadera y las
    piernas se giran hacia donde anda y caminan de verdad (sin patinar), el tronco se queda
    a medio camino y la cabeza (y la linterna) siguen mirando al frente."""
    pose = walk_pose(t, flashlight)
    pose.leg_swing = {side: v * 0.88 for side, v in pose.leg_swing.items()}
    pose.lower_yaw = direction * math.pi / 2
    pose.shoulder_twist = direction * 0.5 + pose.shoulder_twist * 0.5
    pose.head_yaw = -direction * 0.5
    pose.hip_twist *= 0.6
    pose.sway_x *= 0.6
    pose.lean = 0.5
    pose.spread *= 0.7
    if flashlight:
        # La mano de la linterna apunta al frente aunque el tronco esté girado.
        bob = 0.6 * math.sin(2 * math.tau * t)
        pose.hand_target[-1.0] = (-2.0 - direction * 1.5, 37.5 + bob, 11.5)
        pose.hand_pole[-1.0] = (-0.8, -0.6, -0.2)
    else:
        # Brazos más pegados: el de delante se adelanta un poco para equilibrar.
        pose.arm_abduct = {1.0: 0.16, -1.0: 0.16}
    return pose


def turn_pose(t: float, flashlight: bool = False) -> Pose:
    """Giro en el sitio (t en 0..1): arrastra los pies, primero uno y luego el otro, cargando el
    peso en la pierna que se queda; la cadera acompaña el giro."""
    pose = idle_pose(0.25, flashlight)
    lift_l = math.sin(math.pi * _clamp01(t * 2.0)) if t < 0.5 else 0.0
    lift_r = math.sin(math.pi * _clamp01(t * 2.0 - 1.0)) if t >= 0.5 else 0.0
    pose.leg_bend = {1.0: 0.1 + 0.42 * lift_l, -1.0: 0.08 + 0.36 * lift_r}
    pose.leg_swing = {1.0: 0.1 * lift_l, -1.0: 0.08 * lift_r}
    pose.leg_abduct = {1.0: 0.08 * lift_l, -1.0: 0.07 * lift_r}
    pose.foot_pitch = {1.0: 0.15 * lift_l, -1.0: 0.12 * lift_r}
    pose.sway_x = -0.9 * lift_l + 0.9 * lift_r  # el peso pasa a la otra pierna
    pose.hip_twist = 0.16 * (lift_l - lift_r)
    pose.shoulder_twist = 0.08 * (lift_l - lift_r)
    pose.head_pitch = 0.1
    pose.arm_abduct = {1.0: 0.14 + 0.06 * (lift_l + lift_r), -1.0: 0.14 + 0.06 * (lift_l + lift_r)}
    if flashlight:
        pose.arm_abduct[-1.0] = 0.1
    return pose


def sit_pose() -> Pose:
    pose = Pose(sitting=True)
    pose.leg_swing = {1.0: 1.5, -1.0: 1.5}
    pose.leg_bend = {1.0: 0.0, -1.0: 0.0}
    pose.arm_swing = {1.0: 0.35, -1.0: 0.35}
    pose.arm_flex = {1.0: 0.75, -1.0: 0.75}
    pose.lean = 0.0
    return pose


def build(phase: float = 0.0, pose: str = "stand") -> list[Prim]:
    """Compatibilidad: de pie (phase = 0) o sentado (pose = "sit")."""
    return build_pose(sit_pose() if pose == "sit" else walk_pose(0.0 if phase == 0 else 0.25 * phase))


def _hip(side: float, pose: Pose) -> Vec:
    return rot_y((side * 2.7, HIP_Y, 0.0), pose.hip_twist)


def _legs(pose: Pose) -> dict:
    return {side: _leg(_hip(side, pose), pose.leg_swing[side], pose.leg_bend[side], pose.leg_abduct[side], side)
            for side in (1.0, -1.0)}


def _bob(pose: Pose) -> float:
    if pose.hip_height is not None:
        return pose.hip_height - HIP_Y
    if pose.sitting:
        return 0.0
    return 2.4 - min(leg[2][1] for leg in _legs(pose).values())


def _torso_offset(pose: Pose) -> Vec:
    return (pose.sway_x, _bob(pose) + 0.6 * pose.breath, 0.0)


def _shoulder(side: float, pose: Pose) -> Vec:
    base = rot_y((side * 6.0, 44.2, 0.2 + pose.lean), pose.shoulder_twist)
    return add(base, _torso_offset(pose))


# --- articulación: tronco que se dobla, cadera girada, cuerpo entero ---------------------

def _mat_mul(a: Mat3, b: Mat3) -> Mat3:
    return (to_world(a, b[0]), to_world(a, b[1]), to_world(a, b[2]))


def _pivot(pose: Pose) -> Vec:
    """Punto de la cintura sobre el que se dobla el tronco."""
    return (pose.sway_x * 0.6, 31.0 + _bob(pose), 0.0)


def _affine(pose: Pose, w: float) -> tuple[Mat3, Vec]:
    """Transformación (base, desplazamiento) de un punto del modelo erguido con peso de tronco `w`
    (1 = tronco y brazos, 0 = piernas y pelvis) a su sitio final."""
    lower = basis_rot(ry=pose.lower_yaw * (1.0 - w))
    upper = basis_rot(rx=pose.pitch * w, rz=-pose.roll * w)
    body = basis_rot(rx=pose.body_rx, ry=pose.body_ry, rz=pose.body_rz)
    piv = _pivot(pose)
    m = _mat_mul(body, _mat_mul(upper, lower))
    # p' = B (piv + U (L p - piv)) + root
    off = add(to_world(body, sub(piv, to_world(upper, piv))), pose.root)
    return m, off


def to_final(pose: Pose, p: Vec, w: float = 1.0) -> Vec:
    m, off = _affine(pose, w)
    return add(to_world(m, p), off)


def _dir_final(pose: Pose, v: Vec, w: float = 1.0) -> Vec:
    return to_world(_affine(pose, w)[0], v)


def _to_upright(pose: Pose, p: Vec) -> Vec:
    """Inverso del doblez del tronco (sin el giro del cuerpo entero): para la cinemática inversa."""
    upper = basis_rot(rx=pose.pitch, rz=-pose.roll)
    piv = _pivot(pose)
    return add(piv, to_local(upper, sub(p, piv)))


def _is_identity(m: Mat3, off: Vec) -> bool:
    return (abs(m[0][0] - 1) + abs(m[1][1] - 1) + abs(m[2][2] - 1) + abs(off[0]) + abs(off[1]) + abs(off[2])) < 1e-9


def _weight(prim: Prim, hips_y: float) -> float:
    if prim.tag == "upper":
        return 1.0
    if prim.tag == "lower":
        return 0.0
    return smooth((prim.center[1] - hips_y - 30.0) / 7.0)


def _articulate(prims: list[Prim], pose: Pose, hips_y: float) -> list[Prim]:
    groups: dict[float, list[Prim]] = {}
    for prim in prims:
        groups.setdefault(round(_weight(prim, hips_y), 2), []).append(prim)
    result: list[Prim] = []
    for w, group in groups.items():
        m, off = _affine(pose, w)
        result += group if _is_identity(m, off) else transform(group, m, off)
    return result


def _tag(prims, tag: str):
    """Marca primitivas como tronco ("upper") o piernas ("lower")."""
    if isinstance(prims, Prim):
        prims.tag = tag
        return prims
    for p in prims:
        p.tag = tag
    return prims


# --- brazos, manos y linterna ---------------------------------------------------------

def _arm_joints(pose: Pose, side: float) -> tuple[Vec, Vec, Vec, Vec]:
    """Hombro, codo, muñeca y dirección del antebrazo, en el modelo erguido."""
    shoulder = add(_shoulder(side, pose), (side * 0.4, -0.2, 0.0))
    tucked = side < 0 and pose.flashlight and pose.flash_mode == "tucked"
    if tucked and side not in pose.hand_target:
        # Brazo pegado al costado apretando la linterna.
        return _arm(shoulder, side, 0.08, 0.35, 0.02)
    if side in pose.hand_target:
        # El objetivo está en coordenadas finales: se deshace el giro del cuerpo y el doblez del tronco.
        body = basis_rot(rx=pose.body_rx, ry=pose.body_ry, rz=pose.body_rz)
        target = _to_upright(pose, to_local(body, sub(pose.hand_target[side], pose.root)))
        # Con la linterna bajo el brazo, el codo no se separa del costado.
        pole = (-0.15, -1.0, -0.25) if tucked else pose.hand_pole.get(side)
        return arm_ik(shoulder, side, target, pole)
    return _arm(shoulder, side, pose.arm_swing[side], pose.arm_flex[side], pose.arm_abduct[side])


def _palm(joints: tuple) -> Vec:
    return add(joints[2], mul(joints[3], PALM))


TUCK_BACK: Vec = (-6.9, 37.2, -2.6)
TUCK_FRONT: Vec = (-6.7, 38.4, 5.2)


def _flash_axis(pose: Pose) -> tuple[Vec, Vec]:
    """Extremos (culata, lente) de la linterna en el modelo erguido."""
    if pose.flash_mode == "tucked":
        up = _torso_offset(pose)
        lean: Vec = (0.0, 0.0, pose.lean * 0.8)
        back = add(add(rot_y(TUCK_BACK, pose.shoulder_twist), up), lean)
        front = add(add(rot_y(TUCK_FRONT, pose.shoulder_twist), up), lean)
        return back, front
    s, e, w, fore = _arm_joints(pose, -1.0)
    hand_c = add(w, mul(fore, PALM))
    return add(hand_c, mul(fore, -1.2)), add(hand_c, mul(fore, 5.2))


def lens_position(pose: Pose) -> Vec:
    """Posición (modelo, final) de la lente de la linterna para esa postura."""
    start, head = _flash_axis(pose)
    return to_final(pose, add(head, mul(norm(sub(head, start)), 0.2)))


def hand_info(pose: Pose, side: float = 1.0) -> tuple[Vec, Vec, Vec]:
    """Mano de `side` en su sitio final: (palma, dirección del antebrazo, dirección en la que
    apuntaría un arma empuñada: hacia delante y algo hacia abajo)."""
    joints = _arm_joints(pose, side)
    palm = to_final(pose, _palm(joints))
    fore = _dir_final(pose, joints[3])
    forward = _dir_final(pose, (0.0, 0.0, 1.0))
    axis = sub(forward, mul(fore, dot(forward, fore)))
    axis = norm(add(mul(norm(axis), 0.8), mul(fore, 0.45))) if length(axis) > 1e-3 else fore
    return palm, fore, axis


def flash_mat(p: Vec, n: Vec) -> tuple:
    return ("grip", 1.1)


def lens_mat(p: Vec, n: Vec) -> tuple:
    return ("!lens", 0.95)


def _head(pose: Pose, torso_up: Vec, hats: dict[str, list[Prim]] | None = None) -> list[Prim]:
    """Cabeza en su sitio y girada alrededor del cuello (las texturas giran con ella).
    `hats` recibe las prendas de cabeza ya colocadas con el mismo giro."""
    prims: list[Prim] = []
    lean: Vec = (0.0, 0.0, pose.lean * 1.3)
    head_c = add(add((0.0, 53.9, 0.7), torso_up), lean)
    face_c = add(add((0.0, 51.5, 1.6), torso_up), lean)
    prims.append(ellipsoid(head_c, (3.35, 4.05, 3.85), make_head_mat(head_c)))
    prims.append(ellipsoid(face_c, (2.7, 2.6, 2.85), make_face_mat(face_c)))
    prims.append(ellipsoid(add(face_c, (0.0, 0.85, 2.15)), (0.42, 0.9, 0.7), skin_mat))
    prims.append(ellipsoid(add(head_c, (0.0, -0.25, 2.75)), (2.5, 0.55, 1.0), make_head_mat(head_c)))
    for side in (1.0, -1.0):
        prims.append(ellipsoid(add(head_c, (side * 3.3, -1.1, -0.6)), (0.55, 1.1, 0.8), skin_mat))
    hat_parts = {name: _tag(_hat(name, head_c), "upper") for name in (hats or {})}
    if abs(pose.head_yaw) < 1e-4 and abs(pose.head_pitch) < 1e-4:
        for name, parts in hat_parts.items():
            hats[name] += parts
        return prims
    pivot: Vec = add(add((0.0, 49.6, 0.6), torso_up), mul(lean, 0.7))
    basis = basis_rot(rx=pose.head_pitch, ry=pose.head_yaw)
    offset: Vec = sub(pivot, to_world(basis, pivot))
    for name, parts in hat_parts.items():
        hats[name] += transform(parts, basis, offset)
    return transform(prims, basis, offset)


def _prop(pose: Pose, rig: "Rig") -> list[Prim]:
    """Objeto en las manos durante una acción."""
    prims: list[Prim] = []
    if pose.prop == "key":
        s, e, w, fore = rig.arms[1.0]
        tip = add(add(w, mul(fore, PALM + 1.2)), (0.0, 0.0, 0.0))
        prims.append(box(add(tip, mul(fore, 0.9)), (0.25, 1.2, 0.5), metal_mat, basis=basis_from_y(fore)))
        prims.append(sphere(tip, 0.75, metal_mat))
    elif pose.prop == "crowbar":
        a = _palm(rig.arms[-1.0])
        b = _palm(rig.arms[1.0])
        d = norm(sub(b, a))
        back = sub(a, mul(d, 3.0))
        front = add(b, mul(d, 9.0))
        prims.append(cylinder(back, front, 0.55, crowbar_mat))
        claw_dir = norm(add(d, (0.0, -0.9, 0.0)))
        prims.append(capsule(front, add(front, mul(claw_dir, 2.2)), 0.5, crowbar_mat))
        hook = norm(add(mul(d, -1.0), (0.0, -0.6, 0.0)))
        prims.append(capsule(back, add(back, mul(hook, 1.6)), 0.5, crowbar_mat))
    return _tag(prims, "upper")


def crowbar_mat(p: Vec, n: Vec) -> tuple:
    if fbm(mul(p, 0.8), 91) > 0.62:
        return ("blood_dry", 0.9)
    return ("metal", 0.82, None, 0.6)


@dataclass
class Rig:
    """Articulaciones de una postura ya colocadas en el modelo erguido (para vestir el cuerpo)."""
    legs: dict = field(default_factory=dict)   # side -> (hip, knee, ankle)
    feet: dict = field(default_factory=dict)   # side -> (heel, dir, basis)
    arms: dict = field(default_factory=dict)   # side -> (shoulder, elbow, wrist, fore)
    shoulders: dict = field(default_factory=dict)
    pelvis: Vec = (0.0, 0.0, 0.0)
    hips_up: Vec = (0.0, 0.0, 0.0)
    torso_up: Vec = (0.0, 0.0, 0.0)
    knee_z: float = 0.0
    ## Cuánto se adelantan los muslos (0 = de pie, 1 = sentado o en cuclillas): la falda de la
    ## bata pasa a apoyarse sobre ellos.
    lap: float = 0.0


def build_pose(pose: Pose) -> list[Prim]:
    """Cuerpo con la bata de paciente puesta (compatibilidad: camillas, pruebas)."""
    parts = build_parts(pose, ("bata_paciente",))
    return parts["body"] + parts["bata_paciente"]


def build_parts(pose: Pose, garments: tuple = tuple(GARMENTS)) -> dict[str, list[Prim]]:
    """Cuerpo ("body", con ropa interior) y cada prenda pedida, por separado, ya articulados."""
    out: dict[str, list[Prim]] = {"body": []}
    for g in garments:
        out[g] = []
    prims = out["body"]
    rig = Rig()
    legs = _legs(pose)
    bob = _bob(pose)
    up = (0.0, bob, 0.0)
    hips_up = (pose.sway_x * 0.6, bob, 0.0)
    torso_up = _torso_offset(pose)
    rig.hips_up, rig.torso_up = hips_up, torso_up
    lean_mid: Vec = (0.0, 0.0, pose.lean * 0.5)
    lean_top: Vec = (0.0, 0.0, pose.lean)

    for side in (1.0, -1.0):
        hip, knee, ankle = (add(v, up) for v in legs[side])
        hip = add(hip, (pose.sway_x * 0.6, 0.0, 0.0))
        rig.legs[side] = (hip, knee, ankle)
        mid_thigh = add(hip, mul(sub(knee, hip), 0.45))
        calf = add(knee, mul(sub(ankle, knee), 0.3))
        lower = limb([hip, mid_thigh, knee], [2.45, 2.05, 1.65], skin_mat)
        lower += limb([knee, calf, ankle], [1.6, 1.7, 1.0], skin_mat)
        # Pie: talón en el tobillo, puntera girada según el apoyo.
        pitch = pose.foot_pitch[side]
        heel = add(ankle, (0.0, -1.25, 0.2))
        dir_foot: Vec = (0.0, -math.sin(pitch), math.cos(pitch))
        foot_basis = basis_rot(rx=pitch)
        rig.feet[side] = (heel, dir_foot, foot_basis)
        lower.append(ellipsoid(add(heel, mul(dir_foot, 1.3)), (1.25, 0.9, 2.5), skin_mat, basis=foot_basis))
        lower.append(ellipsoid(add(heel, mul(dir_foot, 3.3)), (1.2, 0.7, 0.9), skin_mat, basis=foot_basis))
        # Ropa interior: arranque de los muslos.
        lower.append(capsule(hip, add(hip, mul(sub(knee, hip), 0.18)), 2.62, underwear_mat))
        prims += _tag(lower, "lower")

    pelvis_basis = basis_rot(ry=pose.hip_twist)
    chest_basis = basis_rot(ry=pose.shoulder_twist)
    rig.pelvis = add((0.0, 30.2, 0.0), hips_up)
    prims.append(_tag(ellipsoid(rig.pelvis, (5.1, 3.6, 3.2), skin_mat, basis=pelvis_basis), "lower"))
    prims.append(_tag(ellipsoid(add(rig.pelvis, (0.0, -0.2, 0.0)), (5.3, 3.45, 3.4), underwear_mat, basis=pelvis_basis,
                                cut=lambda p, _y=rig.pelvis[1] + 1.9: p[1] > _y), "lower"))
    prims.append(ellipsoid(add(add((0.0, 35.2, 0.3), torso_up), lean_mid), (4.5, 4.3, 2.9), torso_skin_mat))
    prims.append(ellipsoid(add(add((0.0, 41.3, 0.3), torso_up), lean_top), (5.7, 5.1, 3.3 + 0.25 * pose.breath), torso_skin_mat,
                           basis=chest_basis))
    shoulder_l = _shoulder(1.0, pose)
    shoulder_r = _shoulder(-1.0, pose)
    rig.shoulders = {1.0: shoulder_l, -1.0: shoulder_r}
    upper: list[Prim] = []
    upper.append(capsule(shoulder_r, shoulder_l, 1.9, torso_skin_mat))
    upper.append(capsule(add(add((0.0, 45.5, -0.2), torso_up), lean_top), add(add((0.0, 49.6, 0.6), torso_up), mul(lean_top, 1.2)),
                         1.45, skin_mat))

    # Pieza metálica entre los omóplatos [PROPUESTA].
    port: Vec = add(add(rot_y((0.0, 43.4, -2.4), pose.shoulder_twist), torso_up), lean_top)
    port_out: Vec = add(add(rot_y((0.0, 43.4, -3.7), pose.shoulder_twist), torso_up), lean_top)
    upper.append(cylinder(port, port_out, 0.75, metal_mat))
    upper.append(sphere(add(port_out, rot_y((0.0, 0.0, -0.05), pose.shoulder_twist)), 0.35, metal_mat))

    hats = {g: out[g] for g in garments if GARMENTS[g] == "head"}
    upper += _head(pose, torso_up, hats)

    for side in (1.0, -1.0):
        s, e, w, fore = _arm_joints(pose, side)
        rig.arms[side] = (s, e, w, fore)
        upper += limb([s, e], [1.55, 1.3], skin_mat)
        upper += limb([e, w], [1.25, 0.95], skin_mat)
        hand_basis: Mat3 = basis_from_y(fore, (side, 0.0, 0.0))
        hand_c = add(w, mul(fore, PALM))
        if side > 0:
            upper.append(ellipsoid(hand_c, (0.95, 2.0, 1.3), _left_hand_mat(hand_c, fore), basis=hand_basis))
            tape_c = add(hand_c, (side * 0.85, 0.5, 0.0))
            upper.append(box(tape_c, (0.25, 0.75, 0.7), tape_mat, basis=hand_basis))
            upper.append(sphere(add(tape_c, (side * 0.3, 0.7, 0.0)), 0.35, metal_mat))
        else:
            upper.append(ellipsoid(hand_c, (1.05, 2.0, 1.35), skin_mat, basis=hand_basis))
            for i in range(8):  # pulsera
                ang = i / 8 * math.tau
                ring = to_world(hand_basis, (math.cos(ang) * 1.12, 0.0, math.sin(ang) * 1.12))
                upper.append(sphere(add(add(w, mul(fore, -0.5)), ring), 0.42, band_mat))
        upper.append(ellipsoid(add(hand_c, to_world(hand_basis, (0.0, -0.2, 1.0))), (0.5, 1.1, 0.5), skin_mat,
                               basis=hand_basis))
    if pose.flashlight:
        start, lens = _flash_axis(pose)
        axis = norm(sub(lens, start))
        body_end = sub(lens, mul(axis, 1.4))
        upper.append(cylinder(start, body_end, 1.0, flash_mat))
        upper.append(cylinder(body_end, lens, 1.5, metal_mat))
        upper.append(cylinder(lens, add(lens, mul(axis, 0.25)), 1.25, lens_mat))
    upper += _prop(pose, rig)
    prims += _tag(upper, "upper")

    rig.knee_z = (rig.legs[1.0][1][2] + rig.legs[-1.0][1][2]) / 2
    swing = (pose.leg_swing[1.0] + pose.leg_swing[-1.0]) / 2
    rig.lap = 1.0 if pose.sitting else smooth((swing - 0.4) / 0.7)
    builders = {
        "bata_paciente": _gown, "chaqueta_celador": _jacket, "bata_medico": _labcoat,
        "pantalon_pijama": lambda r, p: _trousers(r, p, pajama_mat, 0.0),
        "pantalon_celador": lambda r, p: _trousers(r, p, trousers_mat, 0.25),
        "zapatillas": _slippers, "botas_goma": _boots,
    }
    for g in garments:
        if g in builders:
            out[g] += builders[g](rig, pose)
    return {key: _articulate(value, pose, hips_up[1]) for key, value in out.items()}


GOWN_PROFILE = [  # (altura, radio x, radio z, centro z)
    (45.6, 6.0, 3.2, 0.25),
    (43.0, 6.15, 3.8, 0.35),
    (39.0, 5.75, 3.85, 0.4),
    (35.5, 5.2, 3.55, 0.35),
    (31.0, 5.55, 3.5, 0.25),
    (17.5, 6.7, 4.1, 0.25),
]
JACKET_PROFILE = [
    (45.8, 6.3, 3.45, 0.25),
    (43.0, 6.45, 4.05, 0.35),
    (39.0, 6.05, 4.1, 0.4),
    (35.5, 5.5, 3.8, 0.35),
    (31.0, 5.8, 3.75, 0.25),
    (27.0, 6.05, 3.95, 0.25),
]
COAT_PROFILE = GOWN_PROFILE[:-1] + [(17.5, 7.0, 4.3, 0.25), (12.5, 7.5, 4.7, 0.25)]


def _profile(y: float, profile: list = GOWN_PROFILE) -> tuple[float, float, float]:
    for (y0, rx0, rz0, cz0), (y1, rx1, rz1, cz1) in zip(profile, profile[1:]):
        if y1 <= y <= y0:
            t = (y0 - y) / (y0 - y1)
            return rx0 + (rx1 - rx0) * t, rz0 + (rz1 - rz0) * t, cz0 + (cz1 - cz0) * t
    return profile[-1][1:]


def _shell(rig: Rig, pose: Pose, profile: list, bottom: float, material, cut, scale: float = 1.0) -> list[Prim]:
    """Prenda del tronco en rodajas: sigue al pecho arriba y a la pelvis abajo; el bajo
    se abre con el paso y va con retraso. Con los muslos adelantados (sentado, en cuclillas)
    la falda se recoge y se apoya sobre ellos."""
    prims: list[Prim] = []
    y = profile[0][0]
    hem = bottom
    if rig.lap > 0.0:
        bottom = bottom + (max(bottom, 28.0) - bottom) * rig.lap
    while y > bottom:
        rx, rz, cz = _profile(y, profile)
        rx *= scale
        rz *= scale
        k = max(0.0, min(1.0, (y - 31.0) / 14.0))
        offset = add(lerp(rig.hips_up, rig.torso_up, k), (0.0, 0.0, pose.lean * k))
        if y < 31.0:
            t = (31.0 - y) / 13.5
            rz += pose.spread * 1.1 * t
            cz += rig.knee_z * 0.5 * t * (1.0 - rig.lap)
            offset = add(offset, (-pose.sway_x * 0.5 * t, 0.0, 0.0))
        prims.append(ellipsoid(add((0.0, y, cz), offset), (rx, 1.0, rz), material, cut=cut,
                               basis=basis_rot(ry=pose.hip_twist * (1 - k) + pose.shoulder_twist * k)))
        y -= 0.75
    if rig.lap > 0.05 and HIP_Y - hem > 4.0:
        prims += _drape(rig, HIP_Y - hem, material, scale)
    return prims


def _drape(rig: Rig, hem_len: float, material, scale: float) -> list[Prim]:
    """La falda sobre los muslos adelantados, hasta donde llega el bajo."""
    prims: list[Prim] = []
    f_max = min(0.98, hem_len / THIGH) * rig.lap
    (hip_l, knee_l, _), (hip_r, knee_r, _) = rig.legs[1.0], rig.legs[-1.0]
    steps = max(2, int(f_max * THIGH / 1.4))
    for i in range(steps + 1):
        f = 0.08 + (f_max - 0.08) * i / steps
        a = lerp(hip_l, knee_l, f)
        b = lerp(hip_r, knee_r, f)
        along = norm(sub(lerp(knee_l, knee_r, 0.5), lerp(hip_l, hip_r, 0.5)))
        across = sub(a, b)
        across = norm(sub(across, mul(along, dot(across, along))))
        normal = norm(cross(across, along))
        if normal[1] < 0:
            normal = mul(normal, -1.0)
        c = add(lerp(a, b, 0.5), mul(normal, 0.5))
        half = length(sub(a, b)) / 2 + 2.7 * scale
        prims.append(_tag(ellipsoid(c, (half, 1.2, 2.9 * scale), material, basis=(across, along, normal)), "lower"))
    return prims


def _sleeves(rig: Rig, material, length_: float, extra: float = 0.45) -> list[Prim]:
    """Mangas: `length_` 0..1 del brazo (0,42 = manga corta; 1 = hasta la muñeca)."""
    prims: list[Prim] = []
    for side in (1.0, -1.0):
        s, e, w, fore = rig.arms[side]
        if length_ <= 0.5:
            prims.append(capsule(s, add(s, mul(sub(e, s), length_ / 0.5 * 0.42)), 2.0, material))
            continue
        prims += limb([s, e], [1.55 + extra + 0.1, 1.3 + extra], material, steps=2)
        end = add(e, mul(sub(w, e), min(1.0, (length_ - 0.5) / 0.5) * 0.92))
        prims += limb([e, end], [1.3 + extra, 1.0 + extra], material, steps=2)
        prims.append(cylinder(add(end, mul(fore, -0.9)), end, 1.0 + extra + 0.12, material))  # puño
    return _tag(prims, "upper")


def _collar(rig: Rig, pose: Pose, material, cut=None) -> list[Prim]:
    sr, sl = rig.shoulders[-1.0], rig.shoulders[1.0]
    return [_tag(capsule(add(sr, (0.4, -0.3, 0.0)), add(sl, (-0.4, -0.3, 0.0)), 2.25, material, cut=cut), "upper")]


def _gown(rig: Rig, pose: Pose) -> list[Prim]:
    prims = _sleeves(rig, gown_mat, 0.42)
    prims += _collar(rig, pose, gown_mat, gown_cut)
    prims += _shell(rig, pose, GOWN_PROFILE, 17.4, gown_slice_mat, gown_cut)
    return prims


def _neck_cut(p: Vec) -> bool:
    return p[1] > 46.4 and abs(p[0]) < 2.4


def _jacket(rig: Rig, pose: Pose) -> list[Prim]:
    prims = _sleeves(rig, sleeve_jacket_mat, 1.0, 0.5)
    prims += _collar(rig, pose, jacket_mat, _neck_cut)
    prims += _shell(rig, pose, JACKET_PROFILE, 26.6, jacket_mat, _neck_cut)
    # Cuello alzado.
    neck: Vec = add(add((0.0, 46.6, 0.1), rig.torso_up), (0.0, 0.0, pose.lean))
    for i in range(10):
        a = (i / 9 - 0.5) * 4.2
        prims.append(_tag(sphere(add(neck, (math.sin(a) * 2.5, 0.2, -math.cos(a) * 2.0 + 0.3)), 0.85, jacket_mat), "upper"))
    return prims


def _coat_cut(p: Vec) -> bool:
    x, y, z = p
    if _neck_cut(p):
        return True
    # Bata abierta por delante, cada vez más abierta hacia abajo.
    return z > 0.6 and y < 41.0 and abs(x) < 0.5 + max(0.0, 40.0 - y) * 0.11


def _labcoat(rig: Rig, pose: Pose) -> list[Prim]:
    prims = _sleeves(rig, sleeve_labcoat_mat, 1.0, 0.55)
    prims += _collar(rig, pose, labcoat_mat, _neck_cut)
    prims += _shell(rig, pose, COAT_PROFILE, 12.3, labcoat_mat, _coat_cut, 1.04)
    # Solapas.
    top: Vec = add(add((0.0, 45.0, 2.6), rig.torso_up), (0.0, 0.0, pose.lean))
    for side in (1.0, -1.0):
        prims.append(_tag(box(add(top, (side * 1.7, -2.6, 0.7)), (0.9, 2.8, 0.25), labcoat_mat,
                              basis=basis_rot(rz=side * 0.35, ry=side * 0.25)), "upper"))
    return prims


def _trousers(rig: Rig, pose: Pose, material, loose: float) -> list[Prim]:
    prims: list[Prim] = []
    for side in (1.0, -1.0):
        hip, knee, ankle = rig.legs[side]
        mid_thigh = add(hip, mul(sub(knee, hip), 0.45))
        calf = add(knee, mul(sub(ankle, knee), 0.3))
        hem = add(knee, mul(sub(ankle, knee), 0.94))
        prims += limb([hip, mid_thigh, knee], [3.0 + loose, 2.6 + loose, 2.15 + loose], material)
        prims += limb([knee, calf, hem], [2.1 + loose, 2.15 + loose, 1.75 + loose], material)
    waist = rig.pelvis[1] + 2.4
    prims.append(ellipsoid(add(rig.pelvis, (0.0, 0.2, 0.0)), (5.55 + loose, 3.75, 3.6 + loose), material,
                           basis=basis_rot(ry=pose.hip_twist), cut=lambda p, _y=waist: p[1] > _y))
    return _tag(prims, "lower")


def _slippers(rig: Rig, pose: Pose) -> list[Prim]:
    prims: list[Prim] = []
    for side in (1.0, -1.0):
        heel, d, basis = rig.feet[side]
        top = heel[1] + 0.55

        def cut(p: Vec, _top=top, _heel=heel) -> bool:
            return p[1] > _top + 0.6 and p[2] < _heel[2] + 0.6  # abierta por el talón
        prims.append(ellipsoid(add(heel, mul(d, 1.4)), (1.5, 1.08, 2.8), slipper_mat, basis=basis, cut=cut))
        prims.append(ellipsoid(add(heel, mul(d, 3.2)), (1.45, 0.95, 1.2), slipper_mat, basis=basis))
    return _tag(prims, "lower")


def _boots(rig: Rig, pose: Pose) -> list[Prim]:
    prims: list[Prim] = []
    for side in (1.0, -1.0):
        heel, d, basis = rig.feet[side]
        hip, knee, ankle = rig.legs[side]
        prims.append(ellipsoid(add(heel, mul(d, 1.35)), (1.62, 1.25, 2.9), boot_mat, basis=basis))
        prims.append(ellipsoid(add(heel, mul(d, 3.3)), (1.55, 1.1, 1.35), boot_mat, basis=basis))
        shaft_top = add(ankle, mul(sub(knee, ankle), 0.58))
        prims += limb([add(ankle, (0.0, -0.8, 0.0)), shaft_top], [1.75, 2.3], boot_mat, steps=4)
        prims.append(cylinder(add(shaft_top, mul(norm(sub(knee, ankle)), -0.4)), shaft_top, 2.45, boot_mat))
    return _tag(prims, "lower")


def _left_hand_mat(center: Vec, fore: Vec):
    def mat(p: Vec, n: Vec) -> tuple:
        r = sub(p, center)
        # Hilo de sangre que baja desde la vía.
        if r[0] > 0.2 and abs(r[2] - 0.3 * r[1]) < 0.45 and r[1] < 0.8:
            return ("blood_dry", 1.0)
        return skin_mat(p, n)
    return mat
