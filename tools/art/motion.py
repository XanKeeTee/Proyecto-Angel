"""Coreografía del protagonista que no es un ciclo: acciones de interacción y levantarse
de la camilla. Cada función devuelve una `human.Pose` para un instante t (0..1).

Coordenadas de las acciones: pies en el origen, +z hacia el objeto, +x = izquierda del
personaje. El objeto está a una casilla delante: su cara frontal a ~15-17 px de los pies.
La mano IZQUIERDA (la libre) hace la acción; la derecha sujeta la linterna si la lleva o
se apoya, se agarra la herida o ayuda. Con la válvula y la palanca de forzar, la linterna
va sujeta bajo el brazo derecho (las dos manos hacen fuerza).

Levantarse: coordenadas de la camilla de tools/art/props.py (colchón a y = 27,35; cabecero
en -z; los pies hacia +z) y la misma proyección que los objetos del mapa (b = 1), para que
el primer fotograma coincida con la camilla "lying" y el personaje quede en su sitio exacto.
"""

from __future__ import annotations

import math

import human
from human import Pose, keys, smooth
from pxrender import (
    Prim, Vec, add, basis_rot, box, ellipsoid, fbm, mul, norm, ramp, sub, to_local, to_world,
)

# --- acciones ---------------------------------------------------------------------------

# nombre -> (fotogramas, fotogramas por segundo). Duran entre 0,7 y 0,9 s.
ACTIONS: dict[str, tuple[int, float]] = {
    "reach_low": (10, 12.0),
    "reach_mid": (10, 13.0),
    "reach_high": (10, 12.0),
    "pickup": (10, 11.0),
    "key": (10, 12.0),
    "valve": (10, 11.0),
    "lever": (10, 12.0),
    "pry": (10, 11.0),
}

_REST: dict[bool, Pose] = {}


def _rest(flash: bool) -> Pose:
    if flash not in _REST:
        _REST[flash] = human.idle_pose(0.25, flash)
    return _REST[flash]


def _rest_palm(side: float, flash: bool) -> Vec:
    p = _rest(flash)
    return human.to_final(p, human._palm(human._arm_joints(p, side)))


def _rest_hip() -> float:
    return human.HIP_Y + human._bob(_rest(False))


def _stance(pose: Pose, hip_h: float, hip_z: float, foot_l: float = 0.0, foot_r: float = 0.0) -> None:
    """Pies plantados en z = foot_l / foot_r, cadera a `hip_h` de altura y `hip_z` adelantada."""
    pose.hip_height = hip_h
    for side, fz in ((1.0, foot_l), (-1.0, foot_r)):
        swing, bend = human.leg_ik(fz - hip_z, hip_h - 2.4)
        pose.leg_swing[side] = swing
        pose.leg_bend[side] = bend
        pose.foot_pitch[side] = 0.0
    pose.root = (0.0, 0.0, hip_z)


def _knee(pose: Pose, side: float) -> Vec:
    hip, knee, _ = human._legs(pose)[side]
    bob = human._bob(pose)
    return human.to_final(pose, add(knee, (pose.sway_x * 0.6, bob, 0.0)), 0.0)


def _wound_arm(pose: Pose, side: float, e: float) -> None:
    """Mano a la herida de la espalda (como el gesto de reposo), con intensidad e."""
    pose.arm_swing[side] = -1.15 * e
    pose.arm_flex[side] = 0.2 + 1.7 * e
    pose.arm_abduct[side] = 0.1 + 0.12 * e


def _hand(pose: Pose, side: float, target: Vec, weight: float, flash: bool, pole: Vec | None = None) -> None:
    """Lleva la palma de `side` hacia `target` (mezclando desde el reposo con `weight`)."""
    rest = _rest_palm(side, flash)
    pose.hand_target[side] = tuple(r + (t - r) * weight for r, t in zip(rest, target))
    if pole is not None:
        pose.hand_pole[side] = pole


def reach_low(t: float, flash: bool) -> Pose:
    """Cajón bajo, mesita, papelera: flexiona las rodillas y el tronco, abre/tira con la izquierda.
    Sin linterna, la derecha se apoya en la rodilla (le duele la espalda)."""
    pose = human.idle_pose(0.25, flash)
    h0 = _rest_hip()
    down = keys(t, [(0.0, 0.0), (0.32, 1.0), (0.66, 1.0), (1.0, 0.0)])
    _stance(pose, h0 - 9.5 * down, -1.6 * down, 0.4 * down, -0.6 * down)
    pose.pitch = 0.55 * keys(t, [(0.0, 0.0), (0.32, 1.0), (0.6, 0.92), (1.0, 0.0)])
    pose.lean = 0.6
    reach = keys(t, [(0.0, 0.0), (0.3, 1.0), (0.72, 1.0), (1.0, 0.0)])
    pull = keys(t, [(0.36, 0.0), (0.6, 1.0), (0.8, 1.0)])
    _hand(pose, 1.0, (2.2, 12.5, 15.5 - 4.0 * pull), reach, flash, (0.7, -0.2, -0.7))
    support = keys(t, [(0.0, 0.0), (0.28, 1.0), (0.74, 1.0), (1.0, 0.0)])
    if flash:
        _hand(pose, -1.0, (-4.5, 25.0, 13.5), support, flash, (-0.8, -0.5, -0.3))
    else:
        _hand(pose, -1.0, add(_knee(pose, -1.0), (-0.4, 2.4, 0.8)), support, flash, (-0.7, 0.0, -0.7))
    pose.head_pitch = 0.06 + 0.22 * down
    pose.sway_x = -0.3 * down
    return pose


def pickup(t: float, flash: bool) -> Pose:
    """Recoger del suelo: hinca la rodilla derecha (la de la cojera), coge con la izquierda y se
    levanta empujándose con la mano en la rodilla buena (o con la linterna alumbrando el suelo)."""
    pose = human.idle_pose(0.25, flash)
    h0 = _rest_hip()
    down = keys(t, [(0.0, 0.0), (0.38, 1.0), (0.58, 1.0), (1.0, 0.0)])
    hip_h = h0 + (15.4 - h0) * down
    hip_z = 0.8 * down
    pose.hip_height = hip_h
    # Pierna izquierda: pie delante, plantado.
    swing, bend = human.leg_ik(6.5 * down - hip_z, hip_h - 2.4)
    pose.leg_swing[1.0], pose.leg_bend[1.0] = swing, bend
    # Pierna derecha: rodilla al suelo, pie detrás apoyado en los dedos.
    knee_s = keys(t, [(0.0, 0.0), (0.38, 0.16), (0.58, 0.16), (1.0, 0.0)])
    pose.leg_swing[-1.0] = knee_s
    pose.leg_bend[-1.0] = 0.04 + 1.86 * down
    pose.foot_pitch[-1.0] = 0.9 * down
    pose.foot_pitch[1.0] = 0.0
    pose.root = (0.0, 0.0, hip_z)
    pose.pitch = 0.72 * keys(t, [(0.0, 0.0), (0.4, 1.0), (0.56, 1.0), (0.8, 0.4), (1.0, 0.0)])
    pose.lean = 0.7
    reach = keys(t, [(0.0, 0.0), (0.36, 1.0), (0.5, 1.0), (0.72, 0.0)])
    _hand(pose, 1.0, (3.2, 2.0, 10.5), reach, flash, (0.8, 0.1, -0.6))
    support = keys(t, [(0.1, 0.0), (0.4, 1.0), (0.85, 1.0), (1.0, 0.0)])
    if flash:
        _hand(pose, -1.0, (-4.0, 19.0, 12.0), support, flash, (-0.8, -0.4, -0.4))
    else:
        _hand(pose, -1.0, add(_knee(pose, 1.0), (-1.2, 2.2, 0.6)), support, flash, (-0.8, 0.0, -0.6))
    pose.head_pitch = 0.08 + 0.3 * down
    pose.sway_x = 0.4 * down
    return pose


def reach_mid(t: float, flash: bool) -> Pose:
    """Taquilla, pomo, interruptor: medio paso adelante cargando el peso, la izquierda a la altura
    de la cintura-pecho, empuja/gira y retira la mano. Sin linterna, la derecha a la herida."""
    pose = human.idle_pose(0.25, flash)
    h0 = _rest_hip()
    go = keys(t, [(0.0, 0.0), (0.3, 1.0), (0.7, 1.0), (1.0, 0.0)])
    _stance(pose, h0 - 1.0 * go, 2.2 * go, 3.6 * go, -0.4 * go)
    pose.lean = 0.6 + 0.5 * go
    pose.pitch = 0.08 * go
    press = keys(t, [(0.3, 0.0), (0.45, 1.0), (0.55, 1.0), (0.68, 0.0)])
    _hand(pose, 1.0, (1.8, 33.0, 15.0 + 1.2 * press), keys(t, [(0.0, 0.0), (0.3, 1.0), (0.66, 1.0), (1.0, 0.0)]),
          flash, (0.9, -0.3, -0.4))
    if flash:
        _hand(pose, -1.0, (-5.0, 34.5, 15.0), go, flash, (-0.8, -0.5, -0.3))
    else:
        _wound_arm(pose, -1.0, 0.7 * go)
    pose.head_pitch = 0.06 + 0.12 * go
    return pose


def reach_high(t: float, flash: bool) -> Pose:
    """Estante alto: se pone de puntillas arqueando la espalda, alarga la izquierda y baja algo.
    Sin linterna, la derecha se aprieta la herida por el tirón."""
    pose = human.idle_pose(0.25, flash)
    h0 = _rest_hip()
    up = keys(t, [(0.0, 0.0), (0.35, 1.0), (0.62, 1.0), (1.0, 0.0)])
    _stance(pose, h0 + 1.4 * up, 1.0 * up, 1.6 * up, 0.4 * up)
    pose.foot_pitch = {1.0: 0.35 * up, -1.0: 0.3 * up}
    pose.pitch = -0.1 * up
    pose.lean = 0.6 - 0.4 * up
    grab = keys(t, [(0.36, 0.0), (0.5, 1.0), (0.66, 1.0)])
    reach = keys(t, [(0.0, 0.0), (0.34, 1.0), (0.68, 1.0), (1.0, 0.0)])
    _hand(pose, 1.0, (1.5, 61.0 - 3.5 * grab, 11.0 - 3.0 * grab), reach, flash, (0.9, -0.2, -0.3))
    if flash:
        _hand(pose, -1.0, (-5.0, 46.0, 13.0), up, flash, (-0.9, -0.4, -0.2))
    else:
        _wound_arm(pose, -1.0, up)
    pose.head_pitch = 0.06 - 0.45 * up
    pose.shoulder_twist = -0.12 * up
    return pose


def key(t: float, flash: bool) -> Pose:
    """Llave: la acerca a la cerradura, la mete, la gira (el codo se levanta al girar la muñeca)
    y la saca. Sin linterna, la derecha se apoya en la puerta."""
    pose = human.idle_pose(0.25, flash)
    h0 = _rest_hip()
    go = keys(t, [(0.0, 0.0), (0.25, 1.0), (0.78, 1.0), (1.0, 0.0)])
    _stance(pose, h0 - 1.6 * go, 1.8 * go, 2.6 * go, -0.2 * go)
    pose.lean = 0.6 + 0.6 * go
    pose.pitch = 0.12 * go
    insert = keys(t, [(0.22, 0.0), (0.38, 1.0), (0.7, 1.0), (0.84, 0.0)])
    twist = keys(t, [(0.4, 0.0), (0.56, 1.0), (0.64, 1.0)])
    reach = keys(t, [(0.0, 0.0), (0.24, 1.0), (0.8, 1.0), (1.0, 0.0)])
    pole = norm((0.9 * (1 - twist) + 0.6 * twist, -0.5 * (1 - twist) + 0.6 * twist, -0.4))
    _hand(pose, 1.0, (1.2 + 0.4 * twist, 30.0 + 0.4 * twist, 12.5 + 3.0 * insert), reach, flash, pole)
    pose.prop = "key" if 0.08 < t < 0.92 else ""
    if flash:
        _hand(pose, -1.0, (-5.0, 32.5, 14.0), go, flash, (-0.8, -0.5, -0.3))
    else:
        _hand(pose, -1.0, (-4.5, 37.0, 16.0), go, flash, (-0.9, -0.3, -0.3))
    pose.head_pitch = 0.06 + 0.2 * go
    return pose


VALVE: Vec = (0.0, 33.0, 15.5)
VALVE_R = 5.5


def _rim(angle: float) -> Vec:
    return add(VALVE, (math.cos(angle) * VALVE_R, math.sin(angle) * VALVE_R, -0.6))


def valve(t: float, flash: bool) -> Pose:
    """Válvula: agarra el volante con las dos manos (la linterna bajo el brazo) y lo gira un
    cuarto de vuelta con todo el cuerpo, tensando la espalda."""
    pose = human.idle_pose(0.25, flash)
    if flash and 0.06 < t < 0.94:
        pose.flash_mode = "tucked"
    h0 = _rest_hip()
    go = keys(t, [(0.0, 0.0), (0.22, 1.0), (0.8, 1.0), (1.0, 0.0)])
    turn = keys(t, [(0.25, 0.0), (0.72, 1.0)])
    _stance(pose, h0 - 2.4 * go, 1.2 * go, 2.0 * go, -1.0 * go)
    pose.lean = 0.6 + 0.4 * go
    pose.pitch = 0.1 * go + 0.06 * math.sin(math.pi * turn)
    a = math.radians(35.0) - math.radians(95.0) * turn
    _hand(pose, 1.0, _rim(a), go, flash, (0.9, -0.4, -0.2))
    _hand(pose, -1.0, _rim(a + math.pi), go, flash, (-0.9, -0.4, -0.2))
    pose.shoulder_twist = -0.18 * math.sin(math.pi * turn) * go
    pose.hip_twist = 0.06 * math.sin(math.pi * turn) * go
    pose.sway_x = -0.5 * math.sin(math.pi * turn)
    pose.head_pitch = 0.1 + 0.15 * go
    return pose


def lever(t: float, flash: bool) -> Pose:
    """Palanca: la agarra arriba y tira hacia abajo dejando caer el peso del cuerpo. Sin
    linterna, con las dos manos."""
    pose = human.idle_pose(0.25, flash)
    h0 = _rest_hip()
    go = keys(t, [(0.0, 0.0), (0.25, 1.0), (0.78, 1.0), (1.0, 0.0)])
    pull = keys(t, [(0.3, 0.0), (0.62, 1.0)])
    _stance(pose, h0 - 0.8 * go - 3.4 * pull * go, 1.0 * go, 2.6 * go, -1.0 * go)
    pose.lean = 0.6 + 0.3 * go
    pose.pitch = 0.05 * go + 0.22 * pull * go
    handle_y = 41.0 - 15.0 * pull
    handle_z = 15.0 - 2.5 * pull
    _hand(pose, 1.0, (1.8, handle_y, handle_z), go, flash, (0.9, -0.4, -0.2))
    if flash:
        _hand(pose, -1.0, (-5.0, 36.0, 14.5), go, flash, (-0.8, -0.5, -0.3))
    else:
        _hand(pose, -1.0, (-1.3, handle_y + 0.4, handle_z), go, flash, (-0.9, -0.4, -0.2))
    pose.head_pitch = 0.06 + 0.18 * pull
    return pose


def pry(t: float, flash: bool) -> Pose:
    """Forzar con una palanca: encaja la punta en la rendija, empuja y hace palanca echando el
    peso atrás y girando el tronco. La linterna, bajo el brazo."""
    pose = human.idle_pose(0.25, flash)
    if flash:
        pose.flash_mode = "tucked"
    pose.prop = "crowbar"
    h0 = _rest_hip()
    go = keys(t, [(0.0, 0.0), (0.2, 1.0), (0.84, 1.0), (1.0, 0.0)])
    jab = keys(t, [(0.2, 0.0), (0.32, 1.0), (0.4, 0.8)])
    lev = keys(t, [(0.4, 0.0), (0.7, 1.0), (0.82, 0.8)])
    _stance(pose, h0 - 2.0 * go - 1.5 * lev, (1.4 + 1.2 * jab - 2.4 * lev) * go, 3.0 * go, -1.4 * go)
    pose.lean = 0.6 + 0.5 * go - 0.6 * lev
    pose.pitch = 0.12 * go - 0.16 * lev
    pose.shoulder_twist = -0.3 * lev
    front = (1.6, 31.0, 8.0 + 3.0 * jab)
    back = (-2.6 - 5.0 * lev, 33.5 + 1.0 * lev, 2.5 + 2.0 * jab - 1.5 * lev)
    _hand(pose, 1.0, front, go, flash, (0.8, -0.5, -0.3))
    _hand(pose, -1.0, back, go, flash, (-0.8, -0.5, -0.3))
    pose.head_pitch = 0.08 + 0.15 * go
    return pose


ACTION_POSES = {
    "reach_low": reach_low, "reach_mid": reach_mid, "reach_high": reach_high, "pickup": pickup,
    "key": key, "valve": valve, "lever": lever, "pry": pry,
}


def action_pose(name: str, i: int, flash: bool) -> Pose:
    """Fotograma i de la acción (empieza y acaba cerca del reposo)."""
    count = ACTIONS[name][0]
    return ACTION_POSES[name]((i + 0.5) / count, flash)


# --- levantarse de la camilla ------------------------------------------------------------

GETUP_FRAMES = 56
GETUP_FPS = 8.0
## Fotograma, píxel del origen de la camilla y tamaño: más ancho que el personaje de pie
## porque empieza tumbado a lo largo de la camilla.
GETUP_FRAME = (56, 84)
GETUP_ORIGIN = (16, 70)
## Colocación del cuerpo tumbado en la camilla (la misma que props.stretcher_frames "lying").
LYING_BASIS = ((1.0, 0.0, 0.0), (0.0, 0.0, -1.0), (0.0, 1.0, 0.0))
LYING_OFFSET: Vec = (0.0, 30.4, 31.0)
MATTRESS_TOP = 27.35
## Dónde acaba de pie (coordenadas de la camilla): a su izquierda, a un paso del borde.
STAND_AT: Vec = (19.0, 0.0, 3.0)
## Proyección: la de los objetos del mapa al principio y la del personaje al final.
MAP_B, MAP_AMBIENT = 1.0, 0.4
CHAR_B, CHAR_AMBIENT = 0.45, 0.38

# Sonidos de la secuencia: fotograma -> (sonido, volumen dB). Ver docs/tech/personaje.md.
GETUP_SOUNDS: dict[int, tuple[str, float]] = {
    3: ("breath_wake_male", -8.0),
    8: ("pain_sigh_male", -8.0),
    15: ("bed_creak", -6.0),
    17: ("pain_groan_male", -5.0),
    24: ("breath_strain_male", -6.0),
    27: ("bed_creak", -8.0),
    31: ("cloth_rustle", -10.0),
    36: ("pain_sigh_male", -7.0),
    43: ("bed_creak", -9.0),
    46: ("bare_feet_floor", -6.0),
    49: ("pain_groan_male", -9.0),
}

ramp("sheet", [(38, 42, 42), (58, 64, 62), (82, 88, 84), (106, 112, 106), (130, 136, 128), (154, 160, 150)])


def _sheet_mat(p: Vec, n: Vec) -> tuple:
    """Copia de props.make_sheet(folds=0.4): la manta tiene que verse igual que la de la camilla."""
    wave = math.sin(p[0] * 0.7 + 4 * fbm(mul(p, 0.08), 41))
    n2 = norm(add(n, (wave * 0.4, 0.0, math.cos(p[2] * 0.5) * 0.2)))
    bright = 0.92 + 0.1 * wave
    if fbm(mul(p, 0.15), 44) > 0.75:
        return ("stain", bright, n2)
    return ("sheet", bright, n2)


def _hide_mat(p: Vec, n: Vec) -> tuple:
    return ("hide", 1.0)


ramp("hide", [(0, 255, 0)])


def bed_occluders() -> list[Prim]:
    """El colchón tapa lo que queda por debajo (se borra de la hoja: lo dibuja la camilla)."""
    return [box((0.0, 24.6, 0.0), (11.2, 2.2, 29.0), _hide_mat), box((0.0, 27.0, 1.5), (11.5, 0.35, 27.0), _hide_mat),
            ellipsoid((0.0, 28.4, -23.0), (8.5, 1.8, 4.5), _hide_mat),  # almohada
            box((0.0, 28.5, -30.4), (12.0, 6.0, 0.6), _hide_mat)]  # cabecero


def _body_basis(pose: Pose):
    return basis_rot(rx=pose.body_rx, ry=pose.body_ry, rz=pose.body_rz)


def _place_hip(pose: Pose, hip_bed: Vec) -> None:
    """Pone `root` para que el centro de las caderas caiga en `hip_bed` (coordenadas de la camilla)."""
    pose.root = (0.0, 0.0, 0.0)
    hip_body = (pose.sway_x * 0.6, human.HIP_Y + human._bob(pose), 0.0)
    now = human.to_final(pose, hip_body, 0.0)
    pose.root = sub(hip_bed, now)


def _hand_bed(pose: Pose, side: float, p_bed: Vec, weight: float, pole: Vec | None = None) -> None:
    """Palma de `side` hacia un punto de la camilla, mezclando desde donde estaría sin objetivo."""
    if weight <= 0.0:
        return
    # Donde está ahora la palma (con lo que ya se haya pedido antes), en coordenadas de la camilla.
    rest = human.to_final(pose, human._palm(human._arm_joints(pose, side)))
    pose.hand_target[side] = tuple(r + (t - r) * weight for r, t in zip(rest, p_bed))
    if pole is not None:
        pose.hand_pole[side] = pole


def _lying_pose() -> Pose:
    pose = human.walk_pose(0.0)
    pose.body_rx = -math.pi / 2
    pose.root = LYING_OFFSET
    return pose


def getup_pose(f: int) -> tuple[Pose, float, float, list[Prim]]:
    """Fotograma f de la secuencia: (postura, b de la proyección, luz ambiente, manta)."""
    u = f / (GETUP_FRAMES - 1)
    if f == 0:
        return _lying_pose(), MAP_B, MAP_AMBIENT, [_blanket(0.0)]
    pose = human.idle_pose(0.0)
    pose.sitting = True
    lying = _lying_pose()
    lying_hip = human.to_final(lying, (lying.sway_x * 0.6, human.HIP_Y + human._bob(lying), 0.0), 0.0)

    # Tiempos (fotogramas) de cada fase.
    def k(pts: list) -> float:
        return keys(f, pts)

    sit = k([(18, 0.0), (22, 0.35), (30, 1.0)])            # tronco: tumbado -> sentado
    turn = k([(31, 0.0), (38, 1.0)])                         # gira hacia el borde
    slide = k([(45, 0.0), (51, 1.0)])                        # se desliza hasta el suelo
    stand = k([(48, 0.0), (55, 1.0)])                        # se endereza

    # Piernas: estiradas sobre la camilla, se doblan al girar y cuelgan; luego al suelo.
    knee_up = k([(0, 0.64), (4, 0.3), (14, 0.15), (24, 0.5), (30, 0.35)])
    pose.leg_swing = {1.0: sit * (math.pi / 2 - 0.12), -1.0: sit * (math.pi / 2 - 0.12)}
    pose.leg_bend = {1.0: 0.06 + knee_up * (1 - turn), -1.0: 0.06 + 0.2 * (1 - turn)}
    hang = turn * (1 - slide)
    for side, delay in ((1.0, 0.0), (-1.0, 0.12)):
        h = keys(turn, [(delay, 0.0), (0.5 + delay, 1.0)]) * (1 - slide)
        pose.leg_bend[side] = pose.leg_bend[side] * (1 - h) + 1.35 * h
        pose.foot_pitch[side] = 0.45 * h  # los pies cuelgan con las puntas hacia abajo
    if slide > 0:
        # Las piernas se estiran hacia el suelo: las puntas tocan primero.
        for side, lag in ((1.0, 0.0), (-1.0, 0.15)):
            s = keys(slide, [(lag, 0.0), (1.0, 1.0)])
            pose.leg_swing[side] = (math.pi / 2 - 0.12) * (1 - s) + 0.05 * s
            pose.leg_bend[side] = 1.35 * (1 - s) + 0.1 * s
            pose.foot_pitch[side] = 0.45 * (1 - s) + 0.5 * s * (1 - stand)
    pose.leg_abduct = {1.0: 0.06 * hang, -1.0: 0.04 * hang}

    # Cuerpo entero: de tumbado a sentado (gira sobre la cadera) y de cara al borde.
    pose.body_rx = -math.pi / 2 + sit * (math.pi / 2)
    pose.body_ry = turn * (math.pi / 2)
    # Rodar hacia la izquierda (hacia el borde) apoyando el codo: giro de hombros.
    roll = k([(10, 0.0), (15, 1.0), (22, 0.8), (28, 0.0)])
    pose.shoulder_twist = 0.55 * roll
    pose.roll = -0.15 * roll
    # Esfuerzo: el tronco se encorva al incorporarse; sentado, hundido de dolor.
    pose.pitch = k([(14, 0.0), (19, 0.35), (26, 0.3), (31, 0.15), (36, 0.3), (42, 0.28), (46, 0.1),
                    (49, 0.42), (55, 0.0)])
    pose.lean = k([(0, 0.6), (30, 0.4), (40, 0.9), (55, 0.6)])

    # Cadera: en la camilla, hacia el borde izquierdo y, al final, de pie a un paso.
    edge = (8.6, MATTRESS_TOP + 3.2, lying_hip[2] + 1.0)
    floor = (STAND_AT[0], 0.0, STAND_AT[2])
    standing_hip = human.HIP_Y + human._bob(human.idle_pose(0.0))
    hip_bed = lying_hip
    hip_bed = add(hip_bed, mul(sub((lying_hip[0], MATTRESS_TOP + 3.0, lying_hip[2]), lying_hip), sit))
    hip_bed = add(hip_bed, mul(sub(edge, hip_bed), keys(f, [(29, 0.0), (38, 1.0)])))
    if slide > 0:
        drop = (floor[0] - 2.0 + 2.0 * stand, standing_hip - 0.8 * (1 - stand), floor[2])
        hip_bed = add(hip_bed, mul(sub(drop, hip_bed), smooth(slide)))

    # Respiración: lenta tumbado, agitada tras el esfuerzo.
    pose.breath = 0.5 - 0.5 * math.cos(f * (0.9 if 30 < f < 46 else 0.6))

    # Cabeza.
    pose.head_yaw = k([(0, 0.0), (5, 0.25), (9, -0.1), (14, 0.35), (24, 0.1), (36, 0.0), (44, 0.2), (55, 0.0)])
    pose.head_pitch = k([(0, 0.0), (6, -0.15), (14, 0.1), (24, 0.25), (34, 0.45), (40, 0.5), (45, 0.2),
                         (50, 0.35), (55, 0.06)])

    # Bamboleo al ponerse de pie.
    wobble = keys(f, [(49, 0.0), (51, 1.0), (55, 0.15)])
    pose.sway_x = 1.4 * wobble * math.sin(f * 1.7)

    _place_hip(pose, hip_bed)

    # Brazos.
    # Mano izquierda (la de la vía) a la cara, al principio.
    face = k([(5, 0.0), (8, 1.0), (11, 1.0), (14, 0.0)])
    head_bed = human.to_final(pose, (0.0, 52.0, 3.6))
    _hand_bed(pose, 1.0, head_bed, face, (0.9, -0.2, -0.4))
    # Codo izquierdo en el colchón y luego la mano empuja para sentarse.
    elbow = k([(12, 0.0), (16, 1.0), (23, 1.0), (28, 0.0)])
    _hand_bed(pose, 1.0, (9.0, MATTRESS_TOP + 1.2, lying_hip[2] - 13.0 + 7.0 * sit), elbow, (0.3, -0.9, -0.3))
    # La derecha cruza y empuja también.
    push = k([(17, 0.0), (21, 1.0), (27, 1.0), (31, 0.0)])
    _hand_bed(pose, -1.0, (4.0, MATTRESS_TOP + 1.0, lying_hip[2] - 4.0), push, (-0.6, -0.4, -0.6))
    # Sentado en el borde: las dos manos en el colchón y luego la izquierda a la herida.
    # (sentado de cara a +x, su izquierda queda hacia -z y su derecha hacia +z).
    perch = k([(32, 0.0), (36, 1.0), (45, 1.0), (49, 0.0)])
    wound = k([(37, 0.0), (40, 1.0), (43, 1.0), (46, 0.0)])
    if wound > 0:
        _wound_arm(pose, 1.0, wound)
    _hand_bed(pose, -1.0, (8.8, MATTRESS_TOP + 0.9, hip_bed[2] + 6.0), perch, (-0.5, -0.5, -0.6))
    _hand_bed(pose, 1.0, (8.8, MATTRESS_TOP + 0.9, hip_bed[2] - 6.0), perch * (1 - wound), (0.5, -0.5, -0.6))
    # Al levantarse, la mano derecha busca la camilla para no caerse y luego la suelta.
    grab = k([(47, 0.0), (49, 1.0), (52, 1.0), (55, 0.0)])
    _hand_bed(pose, -1.0, (11.4, MATTRESS_TOP + 0.6, STAND_AT[2] + 6.0), grab, (-0.7, -0.4, -0.4))

    # Proyección: pasa a la del personaje en los últimos fotogramas sin mover los pies.
    blend = k([(50, 0.0), (55, 1.0)])
    b = MAP_B + (CHAR_B - MAP_B) * blend
    ambient = MAP_AMBIENT + (CHAR_AMBIENT - MAP_AMBIENT) * blend
    if f == GETUP_FRAMES - 1:
        pose = human.idle_pose(0.0)
        pose.body_ry = math.pi / 2
        pose.root = (STAND_AT[0], 0.0, STAND_AT[2])
    # Con b < 1, desplazar en z lo que haga falta para que los pies sigan en el mismo píxel.
    pose.root = (pose.root[0], pose.root[1], pose.root[2] + STAND_AT[2] * (MAP_B / b - 1.0))
    blanket = [] if f > 32 else [_blanket(k([(23, 0.0), (32, 1.0)]))]
    return pose, b, ambient, blanket


def _blanket(off: float) -> Prim:
    """La manta sobre las piernas (como en la camilla "lying"); al girarse la aparta hacia los pies."""
    c = (0.0 + 1.5 * off, 29.4 - 0.4 * off, 14.0 + 5.0 * off)
    r = (10.5 - 2.0 * off, 2.6 - 0.3 * off, 14.5 - 6.5 * off)
    return ellipsoid(c, r, _sheet_mat)


def getup_stand_point() -> Vec:
    """Dónde quedan los pies al terminar (coordenadas de la camilla)."""
    return STAND_AT


def to_bed(p: Vec, basis, offset: Vec) -> Vec:
    return add(to_world(basis, p), offset)
