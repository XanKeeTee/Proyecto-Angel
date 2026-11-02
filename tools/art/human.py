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
    basis_rot, lerp, rot_y, transform,
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


# --- modelo ---------------------------------------------------------------------

def _leg(hip: Vec, swing: float, bend: float) -> tuple[Vec, Vec, Vec]:
    knee = add(hip, mul((0.0, -math.cos(swing), math.sin(swing)), 13.4))
    shin = swing - bend
    ankle = add(knee, mul((0.0, -math.cos(shin), math.sin(shin)), 12.9))
    return hip, knee, ankle


def _arm(shoulder: Vec, side: float, swing: float, flex: float, abduct: float = 0.1) -> tuple[Vec, Vec, Vec, Vec]:
    upper = norm((side * abduct, -math.cos(swing), math.sin(swing)))
    elbow = add(shoulder, mul(upper, 11.2))
    fore_ang = swing + flex
    fore = norm((side * (0.04 + abduct * 0.4), -math.cos(fore_ang), math.sin(fore_ang)))
    wrist = add(elbow, mul(fore, 9.8))
    return shoulder, elbow, wrist, fore


@dataclass
class Pose:
    """Postura completa. Lado 1.0 = izquierda del personaje (x+), -1.0 = derecha."""
    leg_swing: dict = field(default_factory=lambda: {1.0: 0.0, -1.0: 0.0})
    leg_bend: dict = field(default_factory=lambda: {1.0: 0.06, -1.0: 0.06})
    foot_pitch: dict = field(default_factory=lambda: {1.0: 0.0, -1.0: 0.0})
    arm_swing: dict = field(default_factory=lambda: {1.0: 0.0, -1.0: 0.0})
    arm_flex: dict = field(default_factory=lambda: {1.0: 0.2, -1.0: 0.2})
    arm_abduct: dict = field(default_factory=lambda: {1.0: 0.1, -1.0: 0.1})
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
    flashlight: bool = False
    sitting: bool = False


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
    return rot_y((side * 2.7, 29.4, 0.0), pose.hip_twist)


def _bob(pose: Pose) -> float:
    if pose.sitting:
        return 0.0
    ankles = [_leg(_hip(side, pose), pose.leg_swing[side], pose.leg_bend[side])[2][1] for side in (1.0, -1.0)]
    return 2.4 - min(ankles)


def _torso_offset(pose: Pose) -> Vec:
    return (pose.sway_x, _bob(pose) + 0.6 * pose.breath, 0.0)


def _shoulder(side: float, pose: Pose) -> Vec:
    base = rot_y((side * 6.0, 44.2, 0.2 + pose.lean), pose.shoulder_twist)
    return add(base, _torso_offset(pose))


def lens_position(pose: Pose) -> Vec:
    """Posición (modelo) de la lente de la linterna para esa postura."""
    shoulder = add(_shoulder(-1.0, pose), (-0.4, -0.2, 0.0))
    s, e, w, fore = _arm(shoulder, -1.0, pose.arm_swing[-1.0], pose.arm_flex[-1.0], pose.arm_abduct[-1.0])
    return add(add(w, mul(fore, 1.9)), mul(fore, 5.4))


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
    hat_parts = {name: _hat(name, head_c) for name in (hats or {})}
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


@dataclass
class Rig:
    """Articulaciones de una postura ya colocadas (para vestir el cuerpo)."""
    legs: dict = field(default_factory=dict)   # side -> (hip, knee, ankle)
    feet: dict = field(default_factory=dict)   # side -> (heel, dir, basis)
    arms: dict = field(default_factory=dict)   # side -> (shoulder, elbow, wrist, fore)
    shoulders: dict = field(default_factory=dict)
    pelvis: Vec = (0.0, 0.0, 0.0)
    hips_up: Vec = (0.0, 0.0, 0.0)
    torso_up: Vec = (0.0, 0.0, 0.0)
    knee_z: float = 0.0


def build_pose(pose: Pose) -> list[Prim]:
    """Cuerpo con la bata de paciente puesta (compatibilidad: camillas, pruebas)."""
    parts = build_parts(pose, ("bata_paciente",))
    return parts["body"] + parts["bata_paciente"]


def build_parts(pose: Pose, garments: tuple = tuple(GARMENTS)) -> dict[str, list[Prim]]:
    """Cuerpo ("body", con ropa interior) y cada prenda pedida, por separado."""
    out: dict[str, list[Prim]] = {"body": []}
    for g in garments:
        out[g] = []
    prims = out["body"]
    rig = Rig()
    legs = {side: _leg(_hip(side, pose), pose.leg_swing[side], pose.leg_bend[side]) for side in (1.0, -1.0)}
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
        prims += limb([hip, mid_thigh, knee], [2.45, 2.05, 1.65], skin_mat)
        prims += limb([knee, calf, ankle], [1.6, 1.7, 1.0], skin_mat)
        # Pie: talón en el tobillo, puntera girada según el apoyo.
        pitch = pose.foot_pitch[side]
        heel = add(ankle, (0.0, -1.25, 0.2))
        dir_foot: Vec = (0.0, -math.sin(pitch), math.cos(pitch))
        foot_basis = basis_rot(rx=pitch)
        rig.feet[side] = (heel, dir_foot, foot_basis)
        prims.append(ellipsoid(add(heel, mul(dir_foot, 1.3)), (1.25, 0.9, 2.5), skin_mat, basis=foot_basis))
        prims.append(ellipsoid(add(heel, mul(dir_foot, 3.3)), (1.2, 0.7, 0.9), skin_mat, basis=foot_basis))
        # Ropa interior: arranque de los muslos.
        prims.append(capsule(hip, add(hip, mul(sub(knee, hip), 0.18)), 2.62, underwear_mat))

    pelvis_basis = basis_rot(ry=pose.hip_twist)
    chest_basis = basis_rot(ry=pose.shoulder_twist)
    rig.pelvis = add((0.0, 30.2, 0.0), hips_up)
    prims.append(ellipsoid(rig.pelvis, (5.1, 3.6, 3.2), skin_mat, basis=pelvis_basis))
    prims.append(ellipsoid(add(rig.pelvis, (0.0, -0.2, 0.0)), (5.3, 3.45, 3.4), underwear_mat, basis=pelvis_basis,
                           cut=lambda p, _y=rig.pelvis[1] + 1.9: p[1] > _y))
    prims.append(ellipsoid(add(add((0.0, 35.2, 0.3), torso_up), lean_mid), (4.5, 4.3, 2.9), torso_skin_mat))
    prims.append(ellipsoid(add(add((0.0, 41.3, 0.3), torso_up), lean_top), (5.7, 5.1, 3.3 + 0.25 * pose.breath), torso_skin_mat,
                           basis=chest_basis))
    shoulder_l = _shoulder(1.0, pose)
    shoulder_r = _shoulder(-1.0, pose)
    rig.shoulders = {1.0: shoulder_l, -1.0: shoulder_r}
    prims.append(capsule(shoulder_r, shoulder_l, 1.9, torso_skin_mat))
    prims.append(capsule(add(add((0.0, 45.5, -0.2), torso_up), lean_top), add(add((0.0, 49.6, 0.6), torso_up), mul(lean_top, 1.2)),
                         1.45, skin_mat))

    # Pieza metálica entre los omóplatos [PROPUESTA].
    port: Vec = add(add(rot_y((0.0, 43.4, -2.4), pose.shoulder_twist), torso_up), lean_top)
    port_out: Vec = add(add(rot_y((0.0, 43.4, -3.7), pose.shoulder_twist), torso_up), lean_top)
    prims.append(cylinder(port, port_out, 0.75, metal_mat))
    prims.append(sphere(add(port_out, rot_y((0.0, 0.0, -0.05), pose.shoulder_twist)), 0.35, metal_mat))

    hats = {g: out[g] for g in garments if GARMENTS[g] == "head"}
    prims += _head(pose, torso_up, hats)

    for side, shoulder in ((1.0, shoulder_l), (-1.0, shoulder_r)):
        s, e, w, fore = _arm(add(shoulder, (side * 0.4, -0.2, 0.0)), side, pose.arm_swing[side], pose.arm_flex[side],
                             pose.arm_abduct[side])
        rig.arms[side] = (s, e, w, fore)
        prims += limb([s, e], [1.55, 1.3], skin_mat)
        prims += limb([e, w], [1.25, 0.95], skin_mat)
        hand_basis: Mat3 = basis_from_y(fore, (side, 0.0, 0.0))
        hand_c = add(w, mul(fore, 1.9))
        if side > 0:
            prims.append(ellipsoid(hand_c, (0.95, 2.0, 1.3), _left_hand_mat(hand_c, fore), basis=hand_basis))
            tape_c = add(hand_c, (side * 0.85, 0.5, 0.0))
            prims.append(box(tape_c, (0.25, 0.75, 0.7), tape_mat, basis=hand_basis))
            prims.append(sphere(add(tape_c, (side * 0.3, 0.7, 0.0)), 0.35, metal_mat))
        else:
            prims.append(ellipsoid(hand_c, (1.05, 2.0, 1.35), skin_mat, basis=hand_basis))
            for i in range(8):  # pulsera
                ang = i / 8 * math.tau
                ring = to_world(hand_basis, (math.cos(ang) * 1.12, 0.0, math.sin(ang) * 1.12))
                prims.append(sphere(add(add(w, mul(fore, -0.5)), ring), 0.42, band_mat))
            if pose.flashlight:
                start = add(hand_c, mul(fore, -1.2))
                body_end = add(hand_c, mul(fore, 3.8))
                head_end = add(hand_c, mul(fore, 5.2))
                prims.append(cylinder(start, body_end, 1.0, flash_mat))
                prims.append(cylinder(body_end, head_end, 1.5, metal_mat))
                prims.append(cylinder(head_end, add(head_end, mul(fore, 0.25)), 1.25, lens_mat))
        prims.append(ellipsoid(add(hand_c, to_world(hand_basis, (0.0, -0.2, 1.0))), (0.5, 1.1, 0.5), skin_mat,
                               basis=hand_basis))

    rig.knee_z = (legs[1.0][1][2] + legs[-1.0][1][2]) / 2
    builders = {
        "bata_paciente": _gown, "chaqueta_celador": _jacket, "bata_medico": _labcoat,
        "pantalon_pijama": lambda r, p: _trousers(r, p, pajama_mat, 0.0),
        "pantalon_celador": lambda r, p: _trousers(r, p, trousers_mat, 0.25),
        "zapatillas": _slippers, "botas_goma": _boots,
    }
    for g in garments:
        if g in builders:
            out[g] += builders[g](rig, pose)
    return out


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
    se abre con el paso y va con retraso."""
    prims: list[Prim] = []
    y = profile[0][0]
    if pose.sitting:
        bottom = max(bottom, 28.0)
    while y > bottom:
        rx, rz, cz = _profile(y, profile)
        rx *= scale
        rz *= scale
        k = max(0.0, min(1.0, (y - 31.0) / 14.0))
        offset = add(lerp(rig.hips_up, rig.torso_up, k), (0.0, 0.0, pose.lean * k))
        if y < 31.0:
            t = (31.0 - y) / 13.5
            rz += pose.spread * 1.1 * t
            cz += rig.knee_z * 0.5 * t
            offset = add(offset, (-pose.sway_x * 0.5 * t, 0.0, 0.0))
        prims.append(ellipsoid(add((0.0, y, cz), offset), (rx, 1.0, rz), material, cut=cut,
                               basis=basis_rot(ry=pose.hip_twist * (1 - k) + pose.shoulder_twist * k)))
        y -= 0.75
    return prims


def _sleeves(rig: Rig, material, length: float, extra: float = 0.45) -> list[Prim]:
    """Mangas: `length` 0..1 del brazo (0,42 = manga corta; 1 = hasta la muñeca)."""
    prims: list[Prim] = []
    for side in (1.0, -1.0):
        s, e, w, fore = rig.arms[side]
        if length <= 0.5:
            prims.append(capsule(s, add(s, mul(sub(e, s), length / 0.5 * 0.42)), 2.0, material))
            continue
        prims += limb([s, e], [1.55 + extra + 0.1, 1.3 + extra], material, steps=2)
        end = add(e, mul(sub(w, e), min(1.0, (length - 0.5) / 0.5) * 0.92))
        prims += limb([e, end], [1.3 + extra, 1.0 + extra], material, steps=2)
        prims.append(cylinder(add(end, mul(fore, -0.9)), end, 1.0 + extra + 0.12, material))  # puño
    return prims


def _collar(rig: Rig, pose: Pose, material, cut=None) -> list[Prim]:
    sr, sl = rig.shoulders[-1.0], rig.shoulders[1.0]
    return [capsule(add(sr, (0.4, -0.3, 0.0)), add(sl, (-0.4, -0.3, 0.0)), 2.25, material, cut=cut)]


def _gown(rig: Rig, pose: Pose) -> list[Prim]:
    prims = _sleeves(rig, gown_mat, 0.42)
    prims += _collar(rig, pose, gown_mat, gown_cut)
    prims += _shell(rig, pose, GOWN_PROFILE, 17.4, gown_slice_mat, gown_cut)
    if pose.sitting:
        prims.append(ellipsoid(add((0.0, 29.0, 7.0), (0.0, rig.hips_up[1], 0.0)), (6.0, 2.4, 8.5), gown_mat))
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
        prims.append(sphere(add(neck, (math.sin(a) * 2.5, 0.2, -math.cos(a) * 2.0 + 0.3)), 0.85, jacket_mat))
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
        prims.append(box(add(top, (side * 1.7, -2.6, 0.7)), (0.9, 2.8, 0.25), labcoat_mat,
                         basis=basis_rot(rz=side * 0.35, ry=side * 0.25)))
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
    return prims


def _slippers(rig: Rig, pose: Pose) -> list[Prim]:
    prims: list[Prim] = []
    for side in (1.0, -1.0):
        heel, d, basis = rig.feet[side]
        top = heel[1] + 0.55

        def cut(p: Vec, _top=top, _heel=heel) -> bool:
            return p[1] > _top + 0.6 and p[2] < _heel[2] + 0.6  # abierta por el talón
        prims.append(ellipsoid(add(heel, mul(d, 1.4)), (1.5, 1.08, 2.8), slipper_mat, basis=basis, cut=cut))
        prims.append(ellipsoid(add(heel, mul(d, 3.2)), (1.45, 0.95, 1.2), slipper_mat, basis=basis))
    return prims


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
    return prims


def _left_hand_mat(center: Vec, fore: Vec):
    def mat(p: Vec, n: Vec) -> tuple:
        r = sub(p, center)
        # Hilo de sangre que baja desde la vía.
        if r[0] > 0.2 and abs(r[2] - 0.3 * r[1]) < 0.45 and r[1] < 0.8:
            return ("blood_dry", 1.0)
        return skin_mat(p, n)
    return mat
