"""Genera el arte PROVISIONAL del inicio en el hospital (pixel art 32 px).

Uso (desde la raíz del repo):
    python -I tools/art/gen_hospital_placeholders.py

Sobrescribe los PNG de assets/. Es arte de relleno para probar el tono:
cuando haya arte definitivo, se sustituyen los PNG con el mismo tamaño y
disposición y se deja de usar este script.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
TILE = 32

# Paleta (ver docs/art/guia-estetica.md). Contorno de color, nunca negro puro.
OUT = (30, 27, 58)
SKIN = (201, 184, 166)
SKIN_SH = (158, 138, 122)
SKIN_DK = (110, 92, 86)
HAIR = (42, 34, 48)
HAIR_HI = (66, 56, 74)
BONE = (232, 225, 211)
BONE_SH = (191, 182, 163)
BONE_DK = (143, 136, 120)
WOUND = (142, 58, 53)
BLOOD = (90, 22, 32)
METAL_DK = (46, 45, 42)
METAL = (94, 87, 76)
METAL_LT = (140, 132, 118)
METAL_HI = (180, 172, 158)
GREEN_DK = (26, 36, 24)
GREEN = (63, 90, 46)
GREEN_LT = (184, 212, 90)
SHEET = (150, 164, 140)
SHEET_SH = (118, 132, 112)
SHEET_HI = (176, 188, 166)
ACCENT_RED = (192, 57, 43)

rng = random.Random(1987)


# --- utilidades -----------------------------------------------------------

def new(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def px(img: Image.Image, x: int, y: int, c: tuple, a: int = 255) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), (*c[:3], a))


def rect(img: Image.Image, x0: int, y0: int, x1: int, y1: int, c: tuple, a: int = 255) -> None:
    """Rectángulo relleno, extremos incluidos."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c, a)


def ellipse(img: Image.Image, cx: float, cy: float, rx: float, ry: float, c: tuple) -> None:
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                px(img, x, y, c)


def line(img: Image.Image, x0: int, y0: int, x1: int, y1: int, c: tuple, a: int = 255) -> None:
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(steps + 1):
        t = i / steps
        px(img, round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), c, a)


def opaque(img: Image.Image, x: int, y: int) -> bool:
    if not (0 <= x < img.width and 0 <= y < img.height):
        return False
    return img.getpixel((x, y))[3] > 0


def outline(img: Image.Image, color: tuple = OUT) -> Image.Image:
    """Contorno exterior de 1 px alrededor de todo lo opaco."""
    result = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if opaque(img, x, y):
                continue
            if any(opaque(img, x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px(result, x, y, color)
    return result


def paste(sheet: Image.Image, frame: Image.Image, x: int, y: int) -> None:
    sheet.alpha_composite(frame, (x, y))


def noise(img: Image.Image, x0: int, y0: int, w: int, h: int, colors: list, density: float) -> None:
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            if rng.random() < density:
                px(img, x, y, rng.choice(colors))


def save(img: Image.Image, rel: str) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print("  ", rel, f"{img.width}x{img.height}")


# --- protagonista (32x48 por fotograma, 3 fotogramas x 4 direcciones) ------

FW, FH = 32, 48
DOWN, LEFT, RIGHT, UP = range(4)


def _legs_front(img: Image.Image, frame: int) -> None:
    left_bottom = 46 if frame != 0 else 45
    right_bottom = 46 if frame != 2 else 45
    for x0, bottom in ((12, left_bottom), (17, right_bottom)):
        rect(img, x0, 39, x0 + 2, bottom - 2, SKIN)
        px(img, x0 + 2, 40, SKIN_SH)
        rect(img, x0 - (1 if x0 == 12 else 0), bottom - 1, x0 + 2 + (1 if x0 == 17 else 0), bottom, SKIN_SH)


def _gown_front(img: Image.Image, back: bool) -> None:
    for y in range(25, 40):
        widen = (y - 25) // 6
        rect(img, 11 - widen, y, 20 + widen, y, BONE)
        rect(img, 19 + widen, y, 20 + widen, y, BONE_SH)
    rect(img, 9, 39, 22, 39, BONE_SH)
    # Estampado de bata de hospital.
    for y in range(28, 38, 4):
        for x in range(12 + (y // 4) % 2 * 2, 20, 4):
            px(img, x, y, BONE_DK)
    if back:
        # Bata abierta por detrás: cicatriz reciente con puntos.
        rect(img, 15, 25, 16, 38, SKIN)
        rect(img, 15, 28, 16, 36, WOUND)
        for y in range(28, 37, 2):
            px(img, 14, y, BONE_DK)
            px(img, 17, y, BONE_DK)
        for y in (27, 33):
            rect(img, 14, y, 17, y, BONE_DK)
    else:
        rect(img, 15, 25, 16, 26, SKIN)
        px(img, 15, 27, SKIN_SH)


def _arms_front(img: Image.Image, frame: int, back: bool) -> None:
    swing = (0, 0, 0) if back else (1, 0, -1)
    for x0, s in ((8, swing[frame]), (22, -swing[frame])):
        rect(img, x0, 26, x0 + 1, 28, BONE_SH)
        rect(img, x0, 29 + s, x0 + 1, 34 + s, SKIN)
        rect(img, x0, 35 + s, x0 + 1, 35 + s, SKIN_SH)
    if not back:
        # Esparadrapo de la vía en el brazo.
        px(img, 23, 31 - swing[frame], BONE)
        px(img, 22, 31 - swing[frame], BLOOD)


def _head_front(img: Image.Image, back: bool) -> None:
    ellipse(img, 16, 17, 7.6, 7.6, SKIN)
    if back:
        ellipse(img, 16, 17, 7.6, 7.6, HAIR)
        for x in range(11, 21, 3):
            px(img, x, 15, HAIR_HI)
    else:
        for y in range(9, 15):
            for x in range(8, 24):
                if opaque(img, x, y):
                    px(img, x, y, HAIR)
        for x, y in ((9, 15), (10, 15), (10, 16), (14, 15), (19, 15), (20, 15), (21, 15), (21, 16),
                     (8, 16), (8, 17), (8, 18), (9, 17), (23, 16), (23, 17), (23, 18), (22, 17)):
            px(img, x, y, HAIR)
        px(img, 12, 11, HAIR_HI)
        px(img, 17, 10, HAIR_HI)
        # Ojos cansados.
        for ex in (12, 19):
            rect(img, ex, 18, ex, 19, OUT)
            px(img, ex, 20, SKIN_SH)
            px(img, ex + (1 if ex == 12 else -1), 20, SKIN_SH)
        rect(img, 15, 22, 16, 22, SKIN_DK)
        rect(img, 22, 19, 22, 22, SKIN_SH)
    # Venda alrededor de la cabeza.
    for x in range(8, 24):
        for y in (12, 13):
            if opaque(img, x, y) or x in (8, 23):
                px(img, x, y, BONE if y == 12 else BONE_SH)
    if back:
        rect(img, 15, 14, 16, 16, BONE_SH)
        px(img, 17, 15, BONE_SH)
    else:
        rect(img, 19, 12, 20, 12, WOUND)


def _draw_front(frame: int, back: bool) -> Image.Image:
    img = new(FW, FH)
    _legs_front(img, frame)
    _gown_front(img, back)
    _arms_front(img, frame, back)
    _head_front(img, back)
    return outline(img)


def _draw_side(frame: int) -> Image.Image:
    """Perfil mirando a la izquierda."""
    img = new(FW, FH)
    # Piernas: la de atrás más oscura.
    if frame == 1:
        legs = ((15, SKIN_SH, 46), (14, SKIN, 46))
    elif frame == 0:
        legs = ((17, SKIN_SH, 46), (12, SKIN, 45))
    else:
        legs = ((12, SKIN_SH, 45), (17, SKIN, 46))
    for x0, color, bottom in legs:
        rect(img, x0, 39, x0 + 2, bottom - 1, color)
        rect(img, x0 - 2, bottom, x0 + 2, bottom, SKIN_SH)
    # Bata (abierta por la espalda, a la derecha).
    for y in range(25, 40):
        widen = (y - 25) // 7
        rect(img, 12 - widen, y, 20 + widen, y, BONE)
        px(img, 20 + widen, y, SKIN)
    rect(img, 11, 39, 21, 39, BONE_SH)
    for y in range(28, 38, 4):
        px(img, 14 + (y // 4) % 2 * 2, y, BONE_DK)
    # Brazo delantero.
    swing = (-1, 0, 1)[frame]
    rect(img, 15 + swing, 26, 17 + swing, 28, BONE_SH)
    rect(img, 15 + swing, 29, 16 + swing, 34, SKIN)
    rect(img, 15 + swing, 35, 16 + swing, 35, SKIN_SH)
    # Cabeza.
    ellipse(img, 16, 17, 7.2, 7.6, SKIN)
    for y in range(9, 25):
        for x in range(8, 25):
            if opaque(img, x, y) and (x > 17 or y < 14):
                px(img, x, y, HAIR)
    for x, y in ((10, 14), (11, 14), (12, 14), (10, 15), (13, 15), (18, 15), (17, 16)):
        px(img, x, y, HAIR)
    px(img, 20, 11, HAIR_HI)
    px(img, 8, 19, SKIN)
    rect(img, 11, 18, 11, 19, OUT)
    px(img, 11, 20, SKIN_SH)
    px(img, 10, 22, SKIN_DK)
    for x in range(8, 25):
        for y in (12, 13):
            if opaque(img, x, y):
                px(img, x, y, BONE if y == 12 else BONE_SH)
    rect(img, 23, 13, 24, 14, BONE_SH)
    px(img, 10, 12, WOUND)
    return outline(img)


def build_protagonist() -> None:
    sheet = new(FW * 3, FH * 4)
    for frame in range(3):
        paste(sheet, _draw_front(frame, back=False), frame * FW, DOWN * FH)
        side = _draw_side(frame)
        paste(sheet, side, frame * FW, LEFT * FH)
        paste(sheet, side.transpose(Image.Transpose.FLIP_LEFT_RIGHT), frame * FW, RIGHT * FH)
        paste(sheet, _draw_front(frame, back=True), frame * FW, UP * FH)
    save(sheet, "assets/sprites/characters/protagonist.png")


# --- camilla (32x64, 4 fotogramas: vacía, tumbado, sentado, revuelta) -------

def _stretcher_base() -> Image.Image:
    img = new(32, 64)
    # Ruedas y patas.
    for x in (4, 25):
        rect(img, x, 56, x + 2, 59, METAL)
        rect(img, x, 60, x + 2, 62, METAL_DK)
    # Barandilla del cabecero y marco.
    rect(img, 3, 5, 28, 8, METAL)
    rect(img, 4, 5, 27, 5, METAL_HI)
    rect(img, 3, 9, 28, 55, METAL_DK)
    rect(img, 3, 9, 3, 55, METAL)
    rect(img, 28, 9, 28, 55, METAL)
    # Colchón y sábana.
    rect(img, 5, 10, 26, 49, SHEET)
    rect(img, 5, 50, 26, 54, SHEET_SH)
    rect(img, 25, 10, 26, 49, SHEET_SH)
    return img


def _pillow(img: Image.Image, dent: bool) -> None:
    rect(img, 8, 11, 23, 18, BONE_SH)
    rect(img, 9, 11, 22, 17, BONE)
    if dent:
        rect(img, 12, 13, 19, 16, BONE_SH)


def build_stretcher() -> None:
    sheet = new(32 * 4, 64)

    empty = _stretcher_base()
    _pillow(empty, dent=False)
    for y in (24, 36):
        line(empty, 7, y, 24, y, SHEET_HI)
    paste(sheet, outline(empty), 0, 0)

    lying = _stretcher_base()
    _pillow(lying, dent=False)
    ellipse(lying, 16, 16, 5.6, 5.6, SKIN)
    for x in range(10, 23):
        for y in range(10, 15):
            if opaque(lying, x, y) and lying.getpixel((x, y))[:3] == SKIN:
                px(lying, x, y, HAIR)
    rect(lying, 11, 14, 21, 14, BONE)
    rect(lying, 13, 17, 14, 17, OUT)
    rect(lying, 18, 17, 19, 17, OUT)
    rect(lying, 7, 21, 24, 23, BONE)  # bata asomando
    rect(lying, 6, 24, 25, 47, SHEET_HI)
    rect(lying, 6, 44, 25, 47, SHEET)
    for y in (30, 38):
        line(lying, 8, y, 23, y + 1, SHEET_SH)
    for x0 in (6, 24):
        rect(lying, x0, 24, x0 + 1, 34, SKIN)
        px(lying, x0, 35, SKIN_SH)
    px(lying, 7, 28, BONE)
    px(lying, 7, 29, BLOOD)
    rect(lying, 11, 45, 13, 47, SHEET)
    rect(lying, 18, 45, 20, 47, SHEET)
    paste(sheet, outline(lying), 32, 0)

    sitting = _stretcher_base()
    _pillow(sitting, dent=True)
    ellipse(sitting, 16, 9, 6.2, 6.2, SKIN)
    for x in range(9, 24):
        for y in range(2, 9):
            if opaque(sitting, x, y) and sitting.getpixel((x, y))[:3] == SKIN:
                px(sitting, x, y, HAIR)
    rect(sitting, 10, 6, 22, 6, BONE)
    rect(sitting, 13, 10, 13, 11, OUT)
    rect(sitting, 18, 10, 18, 11, OUT)
    rect(sitting, 9, 15, 22, 27, BONE)
    rect(sitting, 20, 15, 22, 27, BONE_SH)
    rect(sitting, 7, 17, 8, 26, SKIN)
    rect(sitting, 23, 17, 24, 26, SKIN)
    rect(sitting, 6, 28, 25, 47, SHEET_HI)
    line(sitting, 7, 30, 24, 32, SHEET_SH)
    paste(sheet, outline(sitting), 64, 0)

    messy = _stretcher_base()
    _pillow(messy, dent=True)
    rect(messy, 6, 34, 26, 47, SHEET_HI)
    for y in (36, 40, 44):
        line(messy, 6, y, 26, y - 2, SHEET_SH)
    rect(messy, 27, 30, 29, 46, SHEET_HI)  # sábana colgando
    rect(messy, 29, 33, 29, 46, SHEET_SH)
    rect(messy, 14, 27, 16, 28, WOUND)  # mancha de la herida
    px(messy, 15, 29, BLOOD)
    paste(sheet, outline(messy), 96, 0)

    save(sheet, "assets/sprites/props/stretcher.png")


# --- objetos -----------------------------------------------------------------

def build_monitor() -> None:
    img = new(32, 48)
    rect(img, 15, 20, 16, 43, METAL)
    px(img, 15, 20, METAL_LT)
    rect(img, 8, 43, 24, 44, METAL)
    for x in (8, 23):
        rect(img, x, 45, x + 1, 46, METAL_DK)
    rect(img, 5, 3, 26, 19, METAL_DK)
    rect(img, 5, 3, 26, 3, METAL)
    rect(img, 7, 5, 24, 16, GREEN_DK)
    trace = [11, 11, 11, 11, 11, 7, 14, 11, 11, 11, 11, 11, 9, 11, 11, 11, 11, 11]
    for i, y in enumerate(trace):
        px(img, 7 + i, y, GREEN_LT)
        if i > 0 and abs(trace[i - 1] - y) > 1:
            line(img, 7 + i, trace[i - 1], 7 + i, y, GREEN_LT)
    px(img, 23, 18, GREEN_LT)
    # Cables sueltos.
    for x0, x1 in ((10, 27), (13, 29), (20, 26)):
        line(img, x0, 20, x1, 34, METAL_DK)
        line(img, x1, 34, x1, 40 + (x1 % 3), METAL_DK)
    save(outline(img), "assets/sprites/props/monitor.png")


def build_iv_stand() -> None:
    img = new(32, 64)
    rect(img, 15, 6, 16, 57, METAL_LT)
    rect(img, 16, 6, 16, 57, METAL)
    rect(img, 10, 6, 21, 6, METAL_LT)
    for x in (10, 21):
        px(img, x, 7, METAL_LT)
    # Bolsa vacía y arrugada.
    rect(img, 9, 8, 13, 19, BONE_SH, 150)
    rect(img, 10, 9, 12, 12, BONE, 170)
    px(img, 11, 16, BONE_DK, 200)
    # Tubo arrancado, con sangre al final.
    pts = [(11, 20), (11, 28), (13, 36), (18, 42), (21, 48), (22, 52)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        line(img, x0, y0, x1, y1, BONE_DK, 220)
    line(img, 21, 48, 22, 52, BLOOD)
    px(img, 22, 53, METAL_HI)
    for dx in (-9, -5, 5, 9):
        line(img, 16, 57, 16 + dx, 59, METAL)
    for x in (6, 11, 20, 25):
        rect(img, x, 60, x + 1, 61, METAL_DK)
    save(outline(img), "assets/sprites/props/iv_stand.png")


def build_cabinet() -> None:
    sheet = new(64, 48)
    for frame in range(2):
        img = new(32, 48)
        body = (98, 106, 98)
        body_sh = (76, 84, 78)
        rect(img, 3, 2, 28, 45, body)
        rect(img, 3, 2, 28, 3, METAL_LT)
        rect(img, 26, 4, 28, 45, body_sh)
        rect(img, 15, 4, 16, 32, body_sh)
        for x in (13, 18):
            rect(img, x, 16, x, 19, METAL_HI)
        rect(img, 5, 34, 26, 34, body_sh)
        noise(img, 4, 5, 22, 28, [body_sh, METAL], 0.04)
        if frame == 0:
            rect(img, 13, 39, 18, 39, METAL_HI)
        else:
            rect(img, 4, 35, 27, 38, (14, 12, 22))  # hueco del cajón
            rect(img, 3, 39, 28, 47, body)
            rect(img, 3, 46, 28, 47, body_sh)
            rect(img, 13, 43, 18, 43, METAL_HI)
        paste(sheet, outline(img), frame * 32, 0)
    save(sheet, "assets/sprites/props/cabinet.png")


def build_tray() -> None:
    img = new(32, 32)
    for x in (5, 25):
        rect(img, x, 20, x + 1, 28, METAL)
        rect(img, x, 29, x + 1, 30, METAL_DK)
    rect(img, 3, 9, 28, 19, METAL_LT)
    rect(img, 3, 18, 28, 19, METAL)
    rect(img, 4, 10, 27, 10, METAL_HI)
    # Instrumental en fila; falta una pieza en medio.
    for x in (7, 10, 13, 19, 22, 25):
        rect(img, x, 12, x, 16, BONE)
        px(img, x, 12, METAL_HI)
    rect(img, 15, 12, 17, 16, METAL)
    save(outline(img), "assets/sprites/props/tray.png")


def build_wheelchair() -> None:
    img = new(32, 32)
    # Volcada de lado: rueda grande vista de frente.
    for a in range(0, 360, 4):
        r = math.radians(a)
        px(img, round(13 + 10 * math.cos(r)), round(18 + 10 * math.sin(r)), METAL_LT)
        px(img, round(13 + 9 * math.cos(r)), round(18 + 9 * math.sin(r)), METAL)
    for a in range(0, 180, 45):
        r = math.radians(a)
        line(img, round(13 - 8 * math.cos(r)), round(18 - 8 * math.sin(r)),
             round(13 + 8 * math.cos(r)), round(18 + 8 * math.sin(r)), METAL_DK)
    rect(img, 12, 17, 14, 19, METAL_HI)
    rect(img, 18, 10, 29, 14, (60, 30, 36))  # asiento de skay
    rect(img, 18, 14, 29, 15, METAL)
    line(img, 27, 15, 28, 26, METAL)
    ellipse(img, 28, 27, 2.2, 2.2, METAL_DK)
    save(outline(img), "assets/sprites/props/wheelchair.png")


def build_footprint() -> None:
    img = new(32, 32)
    wet = (24, 22, 34)
    shine = (120, 132, 142)
    ellipse(img, 16, 19, 3.2, 6.5, wet)
    rect(img, 14, 17, 16, 18, (0, 0, 0))  # arco del pie (se limpia abajo)
    for x in range(14, 17):
        for y in range(17, 19):
            img.putpixel((x, y), (0, 0, 0, 0))
    for i, (x, y) in enumerate(((13, 11), (15, 10), (17, 10), (19, 11), (20, 13))):
        px(img, x, y, wet, 230)
    px(img, 17, 21, shine, 200)
    px(img, 16, 15, shine, 160)
    # Semitransparente: es una mancha húmeda.
    for y in range(32):
        for x in range(32):
            r, g, b, a = img.getpixel((x, y))
            if a:
                img.putpixel((x, y), (r, g, b, min(a, 210)))
    save(img, "assets/sprites/props/footprint.png")


def build_emergency_light() -> None:
    sheet = new(32, 16)
    for frame, lit in enumerate((True, False)):
        img = new(16, 16)
        rect(img, 3, 5, 12, 6, METAL)
        rect(img, 4, 7, 11, 12, ACCENT_RED if lit else (70, 24, 26))
        if lit:
            rect(img, 5, 8, 7, 9, (240, 150, 130))
        paste(sheet, outline(img), frame * 16, 0)
    save(sheet, "assets/sprites/props/emergency_light.png")


# --- tileset -------------------------------------------------------------------

FLOOR = (74, 84, 70)
FLOOR_GROUT = (52, 60, 51)
FLOOR_SH = (62, 70, 58)
FLOOR_LT = (88, 98, 82)
LINO = (60, 64, 72)
LINO_SH = (50, 53, 60)
LINO_LT = (74, 78, 86)
WALL_TOP = (20, 18, 35)
WALL_RIM = (44, 40, 66)
PAINT = (84, 96, 80)
PAINT_SH = (70, 80, 66)
WTILE = (104, 114, 98)
WTILE_GROUT = (78, 86, 72)
RAIL = (122, 130, 112)
BASEBOARD = (40, 38, 44)
DOOR = (90, 96, 92)
DOOR_SH = (66, 72, 70)
DOORWAY = (10, 9, 16)


def _floor(img: Image.Image, ox: int, oy: int, variant: int) -> None:
    rect(img, ox, oy, ox + 31, oy + 31, FLOOR)
    noise(img, ox, oy, 32, 32, [FLOOR_SH, FLOOR_LT], 0.08)
    for i in (0, 16):
        rect(img, ox + i, oy, ox + i, oy + 31, FLOOR_GROUT)
        rect(img, ox, oy + i, ox + 31, oy + i, FLOOR_GROUT)
    if variant == 1:
        for _ in range(3):
            ellipse(img, ox + rng.randint(6, 26), oy + rng.randint(6, 26), rng.uniform(2, 4), rng.uniform(1.5, 3), FLOOR_SH)
    elif variant == 2:
        pts = [(ox + 4, oy + 6), (ox + 11, oy + 12), (ox + 14, oy + 21), (ox + 22, oy + 26)]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            line(img, x0, y0, x1, y1, FLOOR_GROUT)
    elif variant == 3:
        ellipse(img, ox + 18, oy + 17, 4.5, 3, BLOOD)
        for x, y in ((ox + 11, oy + 14), (ox + 24, oy + 21), (ox + 9, oy + 22)):
            px(img, x, y, BLOOD)


def _lino(img: Image.Image, ox: int, oy: int, variant: int) -> None:
    rect(img, ox, oy, ox + 31, oy + 31, LINO)
    noise(img, ox, oy, 32, 32, [LINO_SH, LINO_LT], 0.06)
    rect(img, ox, oy, ox + 31, oy, LINO_SH)
    if variant == 1:
        for _ in range(4):
            y = oy + rng.randint(3, 28)
            x = ox + rng.randint(0, 20)
            line(img, x, y, x + rng.randint(4, 10), y + rng.choice((-1, 0, 1)), LINO_SH)
    elif variant == 2:
        ellipse(img, ox + 14, oy + 18, 6, 3.5, LINO_SH)


def _wall_top(img: Image.Image, ox: int, oy: int) -> None:
    rect(img, ox, oy, ox + 31, oy + 31, WALL_TOP)
    noise(img, ox, oy, 32, 30, [(26, 23, 44)], 0.05)
    rect(img, ox, oy + 30, ox + 31, oy + 31, WALL_RIM)


def _face(img: Image.Image, ox: int, oy: int, variant: int) -> None:
    rect(img, ox, oy, ox + 31, oy + 13, PAINT)
    noise(img, ox, oy, 32, 13, [PAINT_SH], 0.06)
    rect(img, ox, oy + 14, ox + 31, oy + 14, RAIL)
    rect(img, ox, oy + 15, ox + 31, oy + 28, WTILE)
    for y in (oy + 15, oy + 22):
        rect(img, ox, y, ox + 31, y, WTILE_GROUT)
    for x in range(ox, ox + 32, 8):
        rect(img, x, oy + 15, x, oy + 28, WTILE_GROUT)
    rect(img, ox, oy + 29, ox + 31, oy + 31, BASEBOARD)
    if variant == 1:
        # Grieta y chorreón de humedad.
        for x, y0, length in ((ox + 7, oy, 11), (ox + 9, oy + 2, 6), (ox + 21, oy, 9)):
            rect(img, x, y0, x, y0 + length, PAINT_SH)
        pts = [(ox + 24, oy + 15), (ox + 22, oy + 19), (ox + 25, oy + 23), (ox + 23, oy + 28)]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            line(img, x0, y0, x1, y1, WTILE_GROUT)


def _notice(img: Image.Image, ox: int, oy: int) -> None:
    _face(img, ox, oy, 0)
    rect(img, ox + 7, oy + 3, ox + 24, oy + 19, BONE_SH)
    rect(img, ox + 8, oy + 4, ox + 23, oy + 18, BONE)
    for y in range(oy + 7, oy + 17, 3):
        rect(img, ox + 10, y, ox + 10 + rng.randint(7, 12), y, BONE_DK)
    px(img, ox + 15, oy + 3, WOUND)
    # Arañazos sobre el cartel.
    for dx in (0, 2, 4):
        line(img, ox + 12 + dx, oy + 6, ox + 15 + dx, oy + 15, SKIN_DK)


def _door(img: Image.Image, ox: int, oy: int) -> None:
    _face(img, ox, oy, 0)
    rect(img, ox + 5, oy + 1, ox + 26, oy + 31, DOOR_SH)
    rect(img, ox + 6, oy + 2, ox + 25, oy + 31, DOOR)
    rect(img, ox + 24, oy + 2, ox + 25, oy + 31, DOOR_SH)
    rect(img, ox + 11, oy + 6, ox + 19, oy + 12, METAL_DK)
    rect(img, ox + 12, oy + 7, ox + 18, oy + 11, (16, 18, 26))
    px(img, ox + 13, oy + 8, METAL_LT)
    rect(img, ox + 21, oy + 17, ox + 22, oy + 18, METAL_HI)
    rect(img, ox + 7, oy + 26, ox + 24, oy + 30, DOOR_SH)


def _door_open(img: Image.Image, ox: int, oy: int) -> None:
    _face(img, ox, oy, 0)
    rect(img, ox + 5, oy + 1, ox + 26, oy + 31, DOOR_SH)
    rect(img, ox + 6, oy + 2, ox + 25, oy + 31, DOORWAY)
    rect(img, ox + 6, oy + 2, ox + 8, oy + 31, DOOR)  # hoja abierta, de canto


def _double_door(img: Image.Image, ox: int, oy: int, right: bool) -> None:
    _face(img, ox, oy, 0)
    x0, x1 = (ox, ox + 28) if right else (ox + 3, ox + 31)
    rect(img, x0, oy + 1, x1, oy + 31, DOOR_SH)
    rect(img, x0 + 1, oy + 2, x1 - (0 if right else 1) + (0 if not right else -1), oy + 31, DOOR)
    seam = ox if right else ox + 31
    rect(img, seam, oy + 2, seam, oy + 31, METAL_DK)
    cx = ox + (13 if right else 18)
    ellipse(img, cx, oy + 10, 4, 4, METAL_DK)
    ellipse(img, cx, oy + 10, 3, 3, (16, 18, 26))
    px(img, cx - 1, oy + 9, METAL_LT)
    rect(img, ox + (3 if right else 22), oy + 18, ox + (6 if right else 25), oy + 18, METAL_HI)
    rect(img, x0 + 1, oy + 26, x1 - 1, oy + 30, DOOR_SH)


def build_tileset() -> None:
    img = new(TILE * 8, TILE * 3)
    for v in range(4):
        _floor(img, v * TILE, 0, v)
    for v in range(3):
        _lino(img, v * TILE, TILE, v)
    row = TILE * 2
    _wall_top(img, 0, row)
    _face(img, TILE, row, 0)
    _face(img, TILE * 2, row, 1)
    _notice(img, TILE * 3, row)
    _door(img, TILE * 4, row)
    _door_open(img, TILE * 5, row)
    _double_door(img, TILE * 6, row, right=False)
    _double_door(img, TILE * 7, row, right=True)
    save(img, "assets/tilesets/hospital.png")


# --- texturas de luz (escalones marcados, sin degradado limpio) --------------

def _quantize(v: float, steps: int) -> float:
    return math.floor(v * steps + 0.5) / steps


def build_lights() -> None:
    size = 256
    round_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = size / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c) / c
            v = _quantize(max(0.0, 1.0 - d) ** 1.4, 6)
            g = int(255 * v)
            round_img.putpixel((x, y), (g, g, g, 255 if g else 0))
    save(round_img, "assets/sprites/lights/light_round.png")

    # Cono de linterna: el vértice está en el centro y apunta a +X.
    size = 512
    cone = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = size / 2
    half_angle = math.radians(26)
    length = 240.0
    for y in range(size):
        for x in range(size):
            dx = x + 0.5 - c
            dy = y + 0.5 - c
            d = math.hypot(dx, dy)
            near = max(0.0, 1.0 - d / 22.0) * 0.55  # halo pegado al cuerpo
            v = near
            if dx > 0 and d < length:
                ang = abs(math.atan2(dy, dx))
                if ang < half_angle:
                    edge = 1.0 - (ang / half_angle) ** 3
                    fall = (1.0 - d / length) ** 0.8
                    v = max(v, edge * fall)
            v = _quantize(min(v, 1.0), 5)
            g = int(255 * v)
            cone.putpixel((x, y), (g, g, g, 255 if g else 0))
    save(cone, "assets/sprites/lights/flashlight_cone.png")


def main() -> None:
    print("Generando arte provisional del hospital:")
    build_tileset()
    build_protagonist()
    build_stretcher()
    build_monitor()
    build_iv_stand()
    build_cabinet()
    build_tray()
    build_wheelchair()
    build_footprint()
    build_emergency_light()
    build_lights()


if __name__ == "__main__":
    main()
