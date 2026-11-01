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


GOWN_PROFILE = [  # (altura, radio x, radio z, centro z)
    (45.6, 6.0, 3.2, 0.25),
    (43.0, 6.15, 3.8, 0.35),
    (39.0, 5.75, 3.85, 0.4),
    (35.5, 5.2, 3.55, 0.35),
    (31.0, 5.55, 3.5, 0.25),
    (17.5, 6.7, 4.1, 0.25),
]


def _profile(y: float) -> tuple[float, float, float]:
    for (y0, rx0, rz0, cz0), (y1, rx1, rz1, cz1) in zip(GOWN_PROFILE, GOWN_PROFILE[1:]):
        if y1 <= y <= y0:
            t = (y0 - y) / (y0 - y1)
            return rx0 + (rx1 - rx0) * t, rz0 + (rz1 - rz0) * t, cz0 + (cz1 - cz0) * t
    return GOWN_PROFILE[-1][1:]


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


def _arm(shoulder: Vec, side: float, swing: float, flex: float) -> tuple[Vec, Vec, Vec, Vec]:
    upper = norm((side * 0.1, -math.cos(swing), math.sin(swing)))
    elbow = add(shoulder, mul(upper, 11.2))
    fore_ang = swing + flex
    fore = norm((side * 0.04, -math.cos(fore_ang), math.sin(fore_ang)))
    wrist = add(elbow, mul(fore, 9.8))
    return shoulder, elbow, wrist, fore


@dataclass
class Pose:
    """Postura completa. Lado 1.0 = izquierda del personaje (x+), -1.0 = derecha."""
    leg_swing: dict = field(default_factory=lambda: {1.0: 0.0, -1.0: 0.0})
    leg_bend: dict = field(default_factory=lambda: {1.0: 0.06, -1.0: 0.06})
    arm_swing: dict = field(default_factory=lambda: {1.0: 0.0, -1.0: 0.0})
    arm_flex: dict = field(default_factory=lambda: {1.0: 0.2, -1.0: 0.2})
    sway_x: float = 0.0
    breath: float = 0.0
    spread: float = 0.0
    flashlight: bool = False
    sitting: bool = False


# Brazo derecho al frente sujetando la linterna.
FLASH_SWING = 0.3
FLASH_FLEX = 1.2


def walk_pose(t: float, flashlight: bool = False) -> Pose:
    """Ciclo de paso (t en 0..1). Cojea un poco: la pierna derecha da un paso más corto."""
    s, c = math.sin(math.tau * t), math.cos(math.tau * t)
    pose = Pose(flashlight=flashlight)
    pose.leg_swing = {1.0: 0.36 * s, -1.0: -0.29 * s}
    pose.leg_bend = {1.0: 0.06 + 0.55 * max(0.0, c), -1.0: 0.06 + 0.5 * max(0.0, -c)}
    pose.arm_swing = {1.0: -0.24 * s, -1.0: 0.2 * s}
    pose.arm_flex = {1.0: 0.2 + 0.1 * abs(s), -1.0: 0.2 + 0.1 * abs(s)}
    pose.sway_x = 0.45 * c
    pose.spread = abs(s)
    if flashlight:
        pose.arm_swing[-1.0] = FLASH_SWING + 0.035 * math.sin(2 * math.tau * t)
        pose.arm_flex[-1.0] = FLASH_FLEX
    return pose


def idle_pose(t: float, flashlight: bool = False) -> Pose:
    """Respiración en reposo (t en 0..1)."""
    pose = Pose(flashlight=flashlight)
    pose.breath = (1 - math.cos(math.tau * t)) / 2
    pose.arm_flex = {1.0: 0.2 + 0.05 * pose.breath, -1.0: 0.2 + 0.05 * pose.breath}
    pose.sway_x = 0.15 * math.sin(math.tau * t)
    if flashlight:
        pose.arm_swing[-1.0] = FLASH_SWING + 0.03 * pose.breath
        pose.arm_flex[-1.0] = FLASH_FLEX
    return pose


def sit_pose() -> Pose:
    pose = Pose(sitting=True)
    pose.leg_swing = {1.0: 1.5, -1.0: 1.5}
    pose.leg_bend = {1.0: 0.0, -1.0: 0.0}
    pose.arm_swing = {1.0: 0.35, -1.0: 0.35}
    pose.arm_flex = {1.0: 0.75, -1.0: 0.75}
    return pose


def build(phase: float = 0.0, pose: str = "stand") -> list[Prim]:
    """Compatibilidad: de pie (phase = 0) o sentado (pose = "sit")."""
    return build_pose(sit_pose() if pose == "sit" else walk_pose(0.0 if phase == 0 else 0.25 * phase))


def _bob(pose: Pose) -> float:
    if pose.sitting:
        return 0.0
    ankles = [_leg((side * 2.7, 29.4, 0.0), pose.leg_swing[side], pose.leg_bend[side])[2][1] for side in (1.0, -1.0)]
    return 2.4 - min(ankles)


def _torso_offset(pose: Pose) -> Vec:
    return (pose.sway_x, _bob(pose) + 0.6 * pose.breath, 0.0)


def lens_position(pose: Pose) -> Vec:
    """Posición (modelo) de la lente de la linterna para esa postura."""
    shoulder = add(add((-6.0, 44.2, 0.2), _torso_offset(pose)), (-0.4, -0.2, 0.0))
    s, e, w, fore = _arm(shoulder, -1.0, pose.arm_swing[-1.0], pose.arm_flex[-1.0])
    return add(add(w, mul(fore, 1.9)), mul(fore, 5.4))


def flash_mat(p: Vec, n: Vec) -> tuple:
    return ("grip", 1.1)


def lens_mat(p: Vec, n: Vec) -> tuple:
    return ("!lens", 0.95)


def build_pose(pose: Pose) -> list[Prim]:
    prims: list[Prim] = []
    legs = {side: _leg((side * 2.7, 29.4, 0.0), pose.leg_swing[side], pose.leg_bend[side]) for side in (1.0, -1.0)}
    bob = _bob(pose)
    up = (0.0, bob, 0.0)
    hips_up = (pose.sway_x * 0.6, bob, 0.0)
    # Desplazamiento lateral del peso y respiración (tronco, brazos y cabeza).
    torso_up = _torso_offset(pose)

    for side in (1.0, -1.0):
        hip, knee, ankle = (add(v, up) for v in legs[side])
        hip = add(hip, (pose.sway_x * 0.6, 0.0, 0.0))
        mid_thigh = add(hip, mul(sub(knee, hip), 0.45))
        calf = add(knee, mul(sub(ankle, knee), 0.3))
        prims += limb([hip, mid_thigh, knee], [2.45, 2.05, 1.65], skin_mat)
        prims += limb([knee, calf, ankle], [1.6, 1.7, 1.0], skin_mat)
        foot_c = add(ankle, (0.0, -1.25, 1.35))
        prims.append(ellipsoid(foot_c, (1.25, 0.9, 2.5), skin_mat))
        prims.append(ellipsoid(add(foot_c, (0.0, -0.1, 2.0)), (1.2, 0.7, 0.9), skin_mat))

    prims.append(ellipsoid(add((0.0, 30.2, 0.0), hips_up), (5.1, 3.6, 3.2), skin_mat))
    prims.append(ellipsoid(add((0.0, 35.2, 0.3), torso_up), (4.5, 4.3, 2.9), torso_skin_mat))
    prims.append(ellipsoid(add((0.0, 41.3, 0.3), torso_up), (5.7, 5.1, 3.3 + 0.25 * pose.breath), torso_skin_mat))
    shoulder_l = add((6.0, 44.2, 0.2), torso_up)
    shoulder_r = add((-6.0, 44.2, 0.2), torso_up)
    prims.append(capsule(shoulder_r, shoulder_l, 1.9, torso_skin_mat))
    prims.append(capsule(add((0.0, 45.5, -0.2), torso_up), add((0.0, 49.6, 0.6), torso_up), 1.45, skin_mat))

    # Pieza metálica entre los omóplatos [PROPUESTA].
    prims.append(cylinder(add((0.0, 43.4, -2.4), torso_up), add((0.0, 43.4, -3.7), torso_up), 0.75, metal_mat))
    prims.append(sphere(add((0.0, 43.4, -3.75), torso_up), 0.35, metal_mat))

    head_c = add((0.0, 53.9, 0.7), torso_up)
    face_c = add((0.0, 51.5, 1.6), torso_up)
    prims.append(ellipsoid(head_c, (3.35, 4.05, 3.85), make_head_mat(head_c)))
    prims.append(ellipsoid(face_c, (2.7, 2.6, 2.85), make_face_mat(face_c)))
    prims.append(ellipsoid(add(face_c, (0.0, 0.85, 2.15)), (0.42, 0.9, 0.7), skin_mat))
    prims.append(ellipsoid(add(head_c, (0.0, -0.25, 2.75)), (2.5, 0.55, 1.0), make_head_mat(head_c)))
    for side in (1.0, -1.0):
        prims.append(ellipsoid(add(head_c, (side * 3.3, -1.1, -0.6)), (0.55, 1.1, 0.8), skin_mat))

    for side, shoulder in ((1.0, shoulder_l), (-1.0, shoulder_r)):
        s, e, w, fore = _arm(add(shoulder, (side * 0.4, -0.2, 0.0)), side, pose.arm_swing[side], pose.arm_flex[side])
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
        sleeve_end = add(s, mul(sub(e, s), 0.42))
        prims.append(capsule(s, sleeve_end, 2.0, gown_mat))

    prims.append(capsule(add(shoulder_r, (0.4, -0.3, 0.0)), add(shoulder_l, (-0.4, -0.3, 0.0)), 2.25, gown_mat,
                         cut=gown_cut))
    knee_z = (legs[1.0][1][2] + legs[-1.0][1][2]) / 2
    y = 45.6
    bottom = 28.0 if pose.sitting else 17.4
    while y > bottom:
        rx, rz, cz = _profile(y)
        offset = torso_up if y > 33 else hips_up
        if y < 31.0:
            t = (31.0 - y) / 13.5
            rz += pose.spread * 1.1 * t
            cz += knee_z * 0.55 * t
        prims.append(ellipsoid(add((0.0, y, cz), offset), (rx, 1.0, rz), gown_slice_mat, cut=gown_cut))
        y -= 0.75
    if pose.sitting:
        prims.append(ellipsoid(add((0.0, 29.0, 7.0), up), (6.0, 2.4, 8.5), gown_mat))
    return prims


def _left_hand_mat(center: Vec, fore: Vec):
    def mat(p: Vec, n: Vec) -> tuple:
        r = sub(p, center)
        # Hilo de sangre que baja desde la vía.
        if r[0] > 0.2 and abs(r[2] - 0.3 * r[1]) < 0.45 and r[1] < 0.8:
            return ("blood_dry", 1.0)
        return skin_mat(p, n)
    return mat
