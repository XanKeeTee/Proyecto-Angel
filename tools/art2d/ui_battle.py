"""Arte de la interfaz del combate (La Novena Vigilia) → assets/ui/battle/.

Mismo mundo que la maqueta aprobada del menú principal (docs/art/muestras/maqueta_menu.png): chapa
oxidada con remaches, papel de expediente, cinta adhesiva, sellos de caucho y tinta de máquina.
Todo se dibuja a 2× (o más) y se reduce al tamaño de la vista (640×360) con un único factor de escala:
`--scale 2` genera las mismas piezas para 1280×720 sin tocar nada más.

Piezas (las de «9 cortes» se estiran con StyleBoxTexture / NinePatchRect; los márgenes están en
`scenes/battle/battle_skin.gd`):

- `frame_metal.png`   marco de chapa oxidada con escuadras y remaches (cajas de órdenes y mensajes).
- `frame_paper.png`   papel de expediente (fichas de detalle, de la parte, de paciente, nota de aviso).
- `frame_folder.png`  cartulina de carpeta (registro).
- `tab_paper.png`     pestaña de papel con cinta (rótulos «ÓRDENES», «REGISTRO»…).
- `tape.png`          trozo de cinta adhesiva.
- `band.png`, `check.png`  franja granate de la opción elegida y la marca roja (como en el menú).
- `rule.png`          línea de tinta trazada a mano (separadores).
- `tube.png`          tubo de vidrio con tapones (Cuerpo y Mente como líquido).
- `stamp_*.png`       sellos de caucho: AUTORIZADO y los rótulos de impacto (FRACTURA, AMPUTACIÓN…).
- `icons/order_*.png` iconos de órdenes 16×16; `icons/status_*.png` iconos de estado 12×12.
- `diagram/plate.png` lámina anatómica (vista anterior) y `diagram/<parte>.png` la máscara de cada parte;
  `diagram/mini_*.png` la silueta pequeña para el mapa de heridas de la ficha.
- `cursor.png`        puntero (a 2×: el cursor del sistema no se escala con la vista).

Uso:  python3 -I tools/art2d/ui_battle.py [--scale N] [--out DIR] [--sheet hoja.png]
Requisitos: numpy, scipy y Pillow (y `paint.py`/`palette_hd.py`/`title_hd.py` de esta carpeta).
"""

from __future__ import annotations

import argparse
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import palette_hd  # noqa: E402,F401  (registra las rampas)
from paint import Piece, value_noise  # noqa: E402
from title_hd import frame_box  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui", "battle")
S = 1  # factor de escala de salida (1 = 640×360)

INK = (24, 18, 18, 255)
INK_SOFT = (52, 42, 36, 255)
BONE = (216, 204, 175, 255)
BONE_DARK = (150, 138, 112, 255)
BLOOD = (122, 22, 20, 255)
BLOOD_LIGHT = (170, 40, 30, 255)
STAMP_RED = (150, 28, 26)
STEEL = (120, 124, 122, 255)
STEEL_DARK = (66, 70, 72, 255)
RUST = (122, 74, 48, 255)
SKIN = (176, 150, 124, 255)
GLASS = (170, 186, 180, 255)

FONT_DIRS = ["/mnt/skills/examples/canvas-design/canvas-fonts", "/usr/share/fonts/truetype/liberation",
             "/usr/share/fonts/truetype/dejavu", "/usr/share/fonts/truetype/freefont"]


def font(names: list[str], size: int) -> ImageFont.FreeTypeFont:
    for n in names:
        for d in FONT_DIRS:
            p = os.path.join(d, n)
            if os.path.exists(p):
                return ImageFont.truetype(p, size)
    return ImageFont.load_default()


STAMP_FONT = ["BigShoulders-Bold.ttf", "LiberationSans-Bold.ttf", "DejaVuSans-Bold.ttf", "FreeSansBold.ttf"]


def save(im: Image.Image, name: str) -> None:
    path = os.path.join(OUT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)


def reduce_to(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Reduce con filtro de área y deja el alfa duro (píxel), sin halos."""
    small = im.resize(size, Image.Resampling.BOX)
    a = np.asarray(small).copy()
    a[..., 3] = np.where(a[..., 3] >= 110, 255, 0)
    return Image.fromarray(a, "RGBA")


def ink_outline(im: Image.Image, color=INK, diagonal: bool = False) -> Image.Image:
    """Contorno de tinta de 1 px alrededor de lo opaco."""
    a = np.asarray(im).copy()
    mk = a[..., 3] > 0
    st = np.ones((3, 3), bool) if diagonal else np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], bool)
    ring = ndimage.binary_dilation(mk, structure=st) & ~mk
    a[ring] = color
    return Image.fromarray(a, "RGBA")


def hi(size: tuple[int, int], k: int = 8) -> tuple[Image.Image, ImageDraw.ImageDraw, float]:
    """Lienzo a k× para dibujar formas vectoriales que luego se reducen."""
    im = Image.new("RGBA", (size[0] * k, size[1] * k), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im), float(k)


def P(pts, k: float) -> list[tuple[float, float]]:
    return [(x * k, y * k) for x, y in pts]


# --- marcos y papeles ------------------------------------------------------------------------

def metal_frame() -> Image.Image:
    """Chapa oxidada con remaches: la del menú principal, en 9 cortes (64×64 a escala 1)."""
    big = frame_box(128, 128, seed=7)
    return big if S == 2 else big.resize((64 * S, 64 * S), Image.Resampling.BOX)


def _paper_piece(w: int, h: int, seed: int, mat: str = "paper", base: float = 0.78, stains: int = 1) -> Piece:
    pc = Piece(w, h, "paper")
    pc.outline = False
    pc.fill([(0, 0), (w, 0), (w, h), (0, h)], mat, base)
    pc.noise(0.06, 6.0, seed, octaves=3)
    pc.noise(0.025, 1.5, seed + 1)
    pc.pores(0.03, 0.02, seed + 2)
    # bordes gastados y algo más oscuros
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    pc.val -= 0.10 * np.clip(1.0 - edge / 4.0, 0, 1)
    rnd = random.Random(seed)
    for i in range(stains):
        c = (rnd.choice([rnd.uniform(4, 14), w - rnd.uniform(4, 14)]), rnd.choice([rnd.uniform(4, 14), h - rnd.uniform(4, 14)]))
        pc.stain(c, rnd.uniform(1.5, 3.5), "stain", seed + 10 + i, val=0.55, ring=0.04)
    return pc


def paper_frame(seed: int = 3, mat: str = "paper", base: float = 0.80, stains: int = 0) -> Image.Image:
    """Papel de expediente en 9 cortes (48×48): grano, borde gastado, alguna mancha y esquinas
    mordidas."""
    w = h = 48 * S
    pc = _paper_piece(w, h, seed, mat, base, stains)
    im = pc.render(outline=False)
    a = np.asarray(im).copy()
    # borde de 1 px un poco más oscuro (el papel se lee contra el negro) y esquinas romas
    a[0, :, :3] = (a[0, :, :3] * 0.82).astype(np.uint8)
    a[-1, :, :3] = (a[-1, :, :3] * 0.7).astype(np.uint8)
    a[:, 0, :3] = (a[:, 0, :3] * 0.82).astype(np.uint8)
    a[:, -1, :3] = (a[:, -1, :3] * 0.7).astype(np.uint8)
    for cx, cy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        a[cy, cx, 3] = 0
    return Image.fromarray(a, "RGBA")


def tab_paper() -> Image.Image:
    """Pestaña de papel con un poco de cinta en la izquierda (32×14, se estira a lo ancho)."""
    w, h = 32 * S, 14 * S
    pc = _paper_piece(w, h, 21, "paper", 0.86, stains=0)
    pc.form((-0.4, -0.9), bevel=2.0 * S, strength=0.2, rim_dark=0.15)
    im = pc.render(outline=False)
    a = np.asarray(im).copy()
    a[0, :, :3] = (a[0, :, :3] * 0.8).astype(np.uint8)
    a[h - 1, :, :3] = (a[h - 1, :, :3] * 0.6).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def tape() -> Image.Image:
    """Cinta adhesiva amarillenta y translúcida, con los cortes en zigzag (22×8)."""
    w, h = 22 * S, 8 * S
    pc = Piece(w, h, "tape")
    pc.outline = False
    pc.fill([(0, 0), (w, 0), (w, h), (0, h)], "tape", 0.72)
    pc.noise(0.12, 3.0, 5)
    pc.weave(0.04, 1)
    im = pc.render(outline=False)
    a = np.asarray(im).copy()
    a[..., 3] = 168
    for y in range(h):
        if y % 2 == 0:
            a[y, 0, 3] = 0
            a[y, w - 1, 3] = 0
    return Image.fromarray(a, "RGBA")


def band() -> Image.Image:
    """Franja granate de la opción elegida (24×14; 9 cortes con 3 px)."""
    w, h = 24 * S, 14 * S
    pc = Piece(w, h, "band")
    pc.outline = False
    pc.fill([(0, 0), (w, 0), (w, h), (0, h)], "blood", 0.42)
    pc.noise(0.10, 3.0, 9)
    pc.val[0, :] += 0.25
    pc.val[-1, :] -= 0.25
    im = pc.render(outline=False)
    a = np.asarray(im).copy()
    a[..., 3] = 230
    return Image.fromarray(a, "RGBA")


def check() -> Image.Image:
    """Marca roja a mano (la del menú principal), 12×12."""
    im, d, k = hi((12 * S, 12 * S), 8)
    d.line(P([(1.5 * S, 6.5 * S), (4.5 * S, 10 * S), (10.5 * S, 1.5 * S)], k), fill=(196, 52, 40, 255),
           width=int(2.2 * S * k), joint="curve")
    return reduce_to(im, (12 * S, 12 * S))


def rule() -> Image.Image:
    """Línea de tinta trazada a mano, repetible a lo ancho (32×2)."""
    w = 32 * S
    a = np.zeros((2 * S, w, 4), np.uint8)
    rng = np.random.default_rng(4)
    for x in range(w):
        y = 0 if rng.random() < 0.8 else 1
        a[y * S:(y + 1) * S, x] = (60, 50, 42, 200 if rng.random() < 0.85 else 120)
    return Image.fromarray(a, "RGBA")


def tube() -> Image.Image:
    """Tubo de vidrio con tapones de metal (32×8; 9 cortes con 5 px a los lados). El líquido lo
    pinta el juego dentro."""
    w, h = 32 * S, 8 * S
    im, d, k = hi((w, h), 6)
    W, H = w * k, h * k
    cap = 4.5 * S * k
    d.rectangle([cap - k, 0.8 * S * k, W - cap + k, H - 0.8 * S * k], fill=(26, 30, 30, 200))
    d.rectangle([cap - k, 0.8 * S * k, W - cap + k, H - 0.8 * S * k], outline=(140, 156, 150, 255), width=int(0.8 * S * k))
    d.line([(cap + 2 * k, 1.9 * S * k), (W - cap - 2 * k, 1.9 * S * k)], fill=(220, 230, 222, 200), width=int(0.6 * S * k))
    for x0 in (0, W - cap):
        d.rectangle([x0, 0, x0 + cap, H - 1], fill=STEEL_DARK)
        d.rectangle([x0, 0, x0 + cap, H - 1], outline=INK, width=int(0.7 * S * k))
        d.line([(x0 + cap * 0.35, k), (x0 + cap * 0.35, H - 2 * k)], fill=STEEL, width=int(0.8 * S * k))
    small = im.resize((w, h), Image.Resampling.BOX)
    return small


# --- sellos ------------------------------------------------------------------------------------

STAMPS: dict[str, str] = {
    "autorizado": "AUTORIZADO", "fractura": "FRACTURA", "amputacion": "AMPUTACIÓN", "mutilacion": "MUTILACIÓN",
    "decapitacion": "DECAPITACIÓN", "caida": "CAÍDA", "muerte": "MUERTE", "quiebre": "QUIEBRE", "huida": "HUIDA",
    "victoria": "VICTORIA", "fin": "FIN DE LA PARTIDA", "solo": "SOLO QUEDAS TÚ", "denegado": "DENEGADO",
}


def stamp(text: str, seed: int, size: int = 15) -> Image.Image:
    """Sello de caucho: letras condensadas dentro de un marco doble, tinta roja que carga mal
    (huecos y bordes comidos) y un poco girado."""
    k = 4
    f = font(STAMP_FONT, size * S * k)
    x0, y0, x1, y1 = f.getbbox(text)
    pad = 6 * S * k
    w, h = (x1 - x0) + pad * 2, (y1 - y0) + pad * 2
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    d.rectangle([k, k, w - k - 1, h - k - 1], outline=255, width=int(1.6 * S * k))
    d.rectangle([3.4 * S * k, 3.4 * S * k, w - 3.4 * S * k - 1, h - 3.4 * S * k - 1], outline=255, width=int(0.6 * S * k))
    d.text((pad - x0, pad - y0), text, font=f, fill=255)
    a = np.asarray(im).astype(np.float32) / 255.0
    n = value_noise(h, w, 7.0 * k, seed, 3)
    speck = np.random.default_rng(seed).random((h, w))
    a *= np.clip((n + 0.05) * 2.4, 0.25, 1)
    a[speck < 0.025] = 0
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[..., 0], rgba[..., 1], rgba[..., 2] = STAMP_RED
    rgba[..., 3] = (np.clip(a, 0, 1) * 235).astype(np.uint8)
    out = Image.fromarray(rgba, "RGBA").rotate(random.Random(seed).uniform(-5, -2), resample=Image.Resampling.BICUBIC,
                                                expand=True)
    small = out.resize((max(1, out.width // k), max(1, out.height // k)), Image.Resampling.BOX)
    a2 = np.asarray(small).copy()
    a2[..., 3] = np.where(a2[..., 3] > 70, np.minimum(255, a2[..., 3].astype(np.int32) + 40), 0).astype(np.uint8)
    return Image.fromarray(a2, "RGBA")


# --- iconos de órdenes (16×16) ------------------------------------------------------------------

def _icon(draw_fn, size: int = 16, k: int = 8, outline: bool = True) -> Image.Image:
    im, d, kk = hi((size * S, size * S), k)
    draw_fn(d, kk * S)
    small = reduce_to(im, (size * S, size * S))
    return ink_outline(small) if outline else small


def ic_pipe(d, k):
    d.line(P([(3, 13), (13, 3)], k), fill=STEEL, width=int(3.2 * k))
    d.line(P([(3.6, 12.2), (12.4, 3.4)], k), fill=(176, 178, 170, 255), width=int(0.9 * k))
    for t in (0.3, 0.62):
        x, y = 3 + 10 * t, 13 - 10 * t
        d.ellipse(P([(x - 1.4, y - 1.4), (x + 1.4, y + 1.4)], k), fill=RUST)
    d.ellipse(P([(1.6, 11.6), (4.6, 14.6)], k), fill=STEEL_DARK)


def ic_fist(d, k):
    d.rounded_rectangle(P([(3, 5), (13, 12)], k), radius=2.2 * k, fill=SKIN)
    d.rounded_rectangle(P([(5, 11), (11, 15)], k), radius=1 * k, fill=(150, 124, 100, 255))
    for x in (5.5, 8, 10.5):
        d.line(P([(x, 5.4), (x, 8.2)], k), fill=(110, 84, 70, 255), width=int(0.8 * k))
    d.line(P([(3.4, 8.6), (8, 9.4)], k), fill=(110, 84, 70, 255), width=int(0.9 * k))


def ic_blade(d, k):
    d.polygon(P([(3, 14), (5, 12), (12.5, 2.5), (13.5, 3.5), (6, 13.5)], k), fill=(200, 204, 198, 255))
    d.line(P([(1.5, 15), (5, 11.5)], k), fill=STEEL_DARK, width=int(2.4 * k))


def ic_guard(d, k):
    # dos antebrazos cruzados en aspa, vendados
    for a, b in (((2.5, 13.5), (13.5, 3)), ((2.5, 3), (13.5, 13.5))):
        d.line(P([a, b], k), fill=SKIN, width=int(3.4 * k))
    for t in (0.25, 0.75):
        for a, b in (((2.5, 13.5), (13.5, 3)), ((2.5, 3), (13.5, 13.5))):
            x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            d.ellipse(P([(x - 1.9, y - 1.9), (x + 1.9, y + 1.9)], k), fill=BONE)
    d.ellipse(P([(1, 1.5), (4.2, 4.6)], k), fill=SKIN)
    d.ellipse(P([(11.8, 1.5), (15, 4.6)], k), fill=SKIN)


def ic_bandage(d, k):
    d.ellipse(P([(2, 3), (11, 13)], k), fill=BONE)
    d.ellipse(P([(4.6, 5.8), (8.4, 10.2)], k), fill=BONE_DARK)
    d.polygon(P([(8, 11.5), (14.5, 9.5), (15, 12.5), (9, 13.6)], k), fill=BONE)
    d.line(P([(10, 12), (14.2, 10.8)], k), fill=BLOOD_LIGHT, width=int(1 * k))


def ic_pills(d, k):
    d.rounded_rectangle(P([(1.5, 7), (9, 11)], k), radius=2 * k, fill=BONE)
    d.rounded_rectangle(P([(5.25, 7), (9, 11)], k), radius=2 * k, fill=BLOOD_LIGHT)
    d.rectangle(P([(5.25, 7), (6.5, 11)], k), fill=BLOOD_LIGHT)
    d.ellipse(P([(9.5, 3), (14.5, 8)], k), fill=(196, 196, 186, 255))
    d.line(P([(10.2, 5.5), (13.8, 5.5)], k), fill=BONE_DARK, width=int(0.7 * k))
    d.ellipse(P([(9, 10), (13.4, 14.4)], k), fill=(200, 190, 150, 255))


def ic_syringe(d, k):
    d.line(P([(3, 13), (11, 5)], k), fill=GLASS, width=int(3.4 * k))
    d.line(P([(5.5, 10.5), (9.8, 6.2)], k), fill=(60, 20, 30, 255), width=int(1.8 * k))
    d.line(P([(11, 5), (14.5, 1.5)], k), fill=STEEL, width=int(0.9 * k))
    d.line(P([(1, 15), (3.2, 12.8)], k), fill=STEEL_DARK, width=int(1.4 * k))
    d.line(P([(1, 11.6), (4.4, 15)], k), fill=STEEL_DARK, width=int(1.2 * k))


def ic_lungs(d, k):
    d.line(P([(8, 1.5), (8, 7)], k), fill=BONE_DARK, width=int(1.6 * k))
    d.line(P([(8, 6.5), (5.5, 8.5)], k), fill=BONE_DARK, width=int(1.2 * k))
    d.line(P([(8, 6.5), (10.5, 8.5)], k), fill=BONE_DARK, width=int(1.2 * k))
    d.polygon(P([(6.8, 4.5), (3.2, 6), (1.6, 11), (2.2, 14.2), (6.8, 13.2), (7.2, 8)], k), fill=(176, 104, 98, 255))
    d.polygon(P([(9.2, 4.5), (12.8, 6), (14.4, 11), (13.8, 14.2), (9.2, 13.2), (8.8, 8)], k), fill=(176, 104, 98, 255))
    d.line(P([(3, 10), (6, 11)], k), fill=(124, 62, 60, 255), width=int(0.6 * k))
    d.line(P([(13, 10), (10, 11)], k), fill=(124, 62, 60, 255), width=int(0.6 * k))


def ic_door(d, k):
    d.rectangle(P([(3, 1.5), (13, 15)], k), fill=(60, 66, 64, 255))
    d.polygon(P([(4.2, 2.6), (10.4, 3.8), (10.4, 15), (4.2, 15)], k), fill=(110, 118, 112, 255))
    d.rectangle(P([(10.6, 2.6), (12, 15)], k), fill=(214, 220, 200, 255))  # rendija de luz
    d.ellipse(P([(8.2, 8.4), (9.6, 9.8)], k), fill=BONE)
    d.rectangle(P([(5.4, 4.6), (9.2, 7.2)], k), fill=(150, 160, 150, 255))


def ic_flee_solo(d, k):
    ic_door(d, k)
    d.polygon(P([(0.5, 9), (5, 6), (5, 8), (8, 8), (8, 10), (5, 10), (5, 12)], k), fill=BLOOD_LIGHT)


def ic_break_free(d, k):
    # eslabón partido
    d.ellipse(P([(1, 5), (8, 11)], k), outline=STEEL, width=int(1.8 * k))
    d.arc(P([(8, 5), (15, 11)], k), start=-60, end=200, fill=STEEL, width=int(1.8 * k))
    d.line(P([(9, 2), (7.5, 4)], k), fill=BONE, width=int(0.8 * k))
    d.line(P([(12, 13), (13.4, 15)], k), fill=BONE, width=int(0.8 * k))


def ic_back(d, k):
    d.arc(P([(3, 3), (14, 14)], k), start=180, end=90, fill=BONE, width=int(1.8 * k))
    d.polygon(P([(0.6, 7.5), (5.4, 7.5), (3, 11.4)], k), fill=BONE)


def ic_skill(d, k):
    # ojo abierto de la vigilia
    d.ellipse(P([(1.5, 4.5), (14.5, 11.5)], k), fill=BONE)
    d.ellipse(P([(5.4, 4.6), (10.6, 11.4)], k), fill=(110, 40, 36, 255))
    d.ellipse(P([(7, 6.4), (9, 9.6)], k), fill=INK)
    for x in (3, 6, 10, 13):
        d.line(P([(x, 4.8), (x - 0.4 + (x - 8) * 0.15, 2.2)], k), fill=BONE_DARK, width=int(0.7 * k))


def ic_item(d, k):
    # caja de hojalata de botiquín
    d.rectangle(P([(2, 5), (14, 14)], k), fill=(190, 186, 170, 255))
    d.rectangle(P([(2, 4), (14, 6.4)], k), fill=(150, 146, 132, 255))
    d.rectangle(P([(7, 7), (9, 12.4)], k), fill=BLOOD_LIGHT)
    d.rectangle(P([(5.2, 8.8), (10.8, 10.6)], k), fill=BLOOD_LIGHT)
    d.rectangle(P([(6.4, 2), (9.6, 4)], k), outline=STEEL_DARK, width=int(0.8 * k))


def ic_attack(d, k):
    # sin arma conocida: la mano que golpea
    ic_fist(d, k)


ORDER_ICONS = {
    "pipe": ic_pipe, "fist": ic_fist, "blade": ic_blade, "guard": ic_guard, "bandage": ic_bandage,
    "pills": ic_pills, "syringe": ic_syringe, "lungs": ic_lungs, "door": ic_door, "flee_solo": ic_flee_solo,
    "break_free": ic_break_free, "back": ic_back, "skill": ic_skill, "item": ic_item, "attack": ic_attack,
}


# --- iconos de estado (12×12) -------------------------------------------------------------------

def st_bleed(d, k):
    d.polygon(P([(6, 1), (9.6, 7), (2.4, 7)], k), fill=BLOOD_LIGHT)
    d.ellipse(P([(2.4, 4.4), (9.6, 11.2)], k), fill=BLOOD_LIGHT)
    d.ellipse(P([(4, 6.2), (5.6, 7.8)], k), fill=(230, 160, 150, 255))


def st_wound(d, k):
    d.ellipse(P([(1, 1), (11, 11)], k), fill=SKIN)
    d.line(P([(2.6, 8.6), (9.4, 3.4)], k), fill=BLOOD, width=int(1.8 * k))
    for t in (0.25, 0.5, 0.75):
        x, y = 2.6 + 6.8 * t, 8.6 - 5.2 * t
        d.line(P([(x - 1.2, y - 1.6), (x + 1.2, y + 1.6)], k), fill=INK_SOFT, width=int(0.6 * k))


def st_broken(d, k):
    for a, b in (((1.5, 10.5), (5.2, 6.8)), ((6.8, 5.2), (10.5, 1.5))):
        d.line(P([a, b], k), fill=BONE, width=int(2.2 * k))
    for c in ((1.4, 9.4), (2.6, 10.6), (9.4, 1.4), (10.6, 2.6)):
        d.ellipse(P([(c[0] - 1.3, c[1] - 1.3), (c[0] + 1.3, c[1] + 1.3)], k), fill=BONE)
    d.polygon(P([(5.2, 6.8), (4.6, 5.6), (6, 6), (6.6, 4.8), (6.8, 5.2), (6, 7.2)], k), fill=BONE)
    d.line(P([(4.8, 4.2), (7.4, 7.6)], k), fill=BLOOD_LIGHT, width=int(0.8 * k))


def st_amputated(d, k):
    d.ellipse(P([(1, 1), (11, 11)], k), fill=(100, 20, 18, 255))
    d.ellipse(P([(2.6, 2.6), (9.4, 9.4)], k), fill=BLOOD_LIGHT)
    d.ellipse(P([(4.4, 4.4), (7.6, 7.6)], k), fill=BONE)


def st_grabbed(d, k):
    # mano que aprieta un antebrazo
    d.line(P([(0.5, 6), (11.5, 6)], k), fill=SKIN, width=int(3 * k))
    d.rounded_rectangle(P([(4, 2), (8.6, 10.4)], k), radius=1.2 * k, fill=(106, 118, 130, 255))
    for y in (3.6, 5.6, 7.6):
        d.line(P([(4.2, y), (8.4, y)], k), fill=INK_SOFT, width=int(0.6 * k))


def st_sedated(d, k):
    d.polygon(P([(6, 1), (9.4, 6.4), (2.6, 6.4)], k), fill=(110, 70, 120, 255))
    d.ellipse(P([(2.6, 4), (9.4, 10.8)], k), fill=(110, 70, 120, 255))
    d.line(P([(4.6, 6.2), (7.4, 6.2), (4.6, 9), (7.4, 9)], k), fill=BONE, width=int(0.8 * k))


def st_stunned(d, k):
    for i in range(3):
        a = math.tau * i / 3 - math.pi / 2
        x, y = 6 + math.cos(a) * 3.6, 6 + math.sin(a) * 3.6
        d.polygon(P([(x, y - 2), (x + 0.7, y - 0.7), (x + 2, y), (x + 0.7, y + 0.7), (x, y + 2), (x - 0.7, y + 0.7),
                     (x - 2, y), (x - 0.7, y - 0.7)], k), fill=(208, 162, 74, 255))


def st_guard(d, k):
    ic_guard(d, k * 12 / 16)


def st_panic(d, k):
    d.ellipse(P([(1, 3), (11, 9)], k), fill=BONE)
    d.ellipse(P([(4.6, 4.6), (7.4, 7.4)], k), fill=INK)
    for x in (2, 6, 10):
        d.line(P([(x, 2.8), (x, 0.6)], k), fill=BLOOD_LIGHT, width=int(0.8 * k))


STATUS_ICONS = {
    "bleed": st_bleed, "wound": st_wound, "broken": st_broken, "amputated": st_amputated, "grabbed": st_grabbed,
    "sedated": st_sedated, "stunned": st_stunned, "guard": st_guard, "panic": st_panic,
}


# --- lámina anatómica ----------------------------------------------------------------------------

PLATE = (112, 160)
# Figura de frente (convención anatómica: su derecha a nuestra izquierda), en coordenadas de la lámina.
FIG: dict[str, list[tuple[float, float]]] = {
    "head": [(56, 9), (63, 11), (66, 19), (65, 27), (61, 33), (59, 37), (53, 37), (51, 33), (47, 27), (46, 19),
             (49, 11)],
    "torso": [(51, 37), (61, 37), (62, 40), (74, 43), (76, 48), (72, 64), (71, 78), (74, 90), (60, 94), (56, 92),
              (52, 94), (38, 90), (41, 78), (40, 64), (36, 48), (38, 43), (50, 40)],
    "arm_r": [(38, 42), (33, 46), (30, 58), (27, 72), (24, 86), (21, 98), (19, 106), (24, 110), (28, 104), (31, 96),
              (34, 84), (37, 72), (39.5, 60), (40.5, 50)],
    "arm_l": [(74, 42), (79, 46), (82, 58), (85, 72), (88, 86), (91, 98), (93, 106), (88, 110), (84, 104), (81, 96),
              (78, 84), (75, 72), (72.5, 60), (71.5, 50)],
    "leg_r": [(38, 90), (52, 94), (55.4, 93), (53, 108), (52, 124), (51, 140), (51, 150), (44, 152), (45, 140),
              (43, 124), (40, 108)],
    "leg_l": [(74, 90), (60, 94), (56.6, 93), (59, 108), (60, 124), (61, 140), (61, 150), (68, 152), (67, 140),
              (69, 124), (72, 108)],
}
PART_ORDER = ["leg_r", "leg_l", "arm_r", "arm_l", "torso", "head"]
INNER_LINES = [  # pliegues, músculos y costuras, para que se lea como una lámina
    [(56, 44), (56, 88)], [(44, 52), (52, 56), (56, 54)], [(68, 52), (60, 56), (56, 54)],
    [(46, 64), (52, 66)], [(66, 64), (60, 66)], [(47, 72), (52, 73)], [(65, 72), (60, 73)],
    [(46, 82), (52, 88), (56, 89)], [(66, 82), (60, 88), (56, 89)],
    [(34, 70), (36, 74)], [(78, 70), (76, 74)], [(47, 120), (49, 126)], [(65, 120), (63, 126)],
    [(56, 30), (56, 36)],
]


def _part_mask(part: str, k: int) -> Image.Image:
    im = Image.new("L", (PLATE[0] * k, PLATE[1] * k), 0)
    ImageDraw.Draw(im).polygon(P(FIG[part], k), fill=255)
    return im


def diagram() -> dict[str, Image.Image]:
    """Lámina: papel, marco de dos líneas, retícula de medidas, la figura con sombreado de trazos y
    sus líneas interiores. Y una máscara blanca por parte, del mismo tamaño."""
    k = 4
    w, h = PLATE[0] * S, PLATE[1] * S
    kk = k * S
    pc = _paper_piece(w, h, 31, "paper", 0.84, stains=1)
    paper = np.asarray(pc.render(outline=False)).astype(np.float32)
    big = Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    # retícula y marco
    for gx in range(8, PLATE[0], 8):
        d.line([(gx * kk, 6 * kk), (gx * kk, (PLATE[1] - 6) * kk)], fill=(120, 132, 140, 50), width=1)
    for gy in range(8, PLATE[1], 8):
        d.line([(6 * kk, gy * kk), ((PLATE[0] - 6) * kk, gy * kk)], fill=(120, 132, 140, 50), width=1)
    d.rectangle([3 * kk, 3 * kk, (PLATE[0] - 3) * kk, (PLATE[1] - 3) * kk], outline=(60, 50, 42, 230), width=int(0.9 * kk))
    d.rectangle([5 * kk, 5 * kk, (PLATE[0] - 5) * kk, (PLATE[1] - 5) * kk], outline=(60, 50, 42, 140), width=int(0.5 * kk))
    for y in range(12, PLATE[1] - 8, 6):  # escala lateral
        d.line([(5 * kk, y * kk), ((7.5 if y % 30 else 9) * kk, y * kk)], fill=(60, 50, 42, 170), width=int(0.4 * kk))
    # figura: relleno claro, sombra a trazos en el lado derecho de cada parte
    fig_fill = (206, 192, 164, 255)
    for part in PART_ORDER:
        pts = [(x * kk, y * kk) for x, y in FIG[part]]
        d.polygon(pts, fill=fig_fill)
    shade = Image.new("L", big.size, 0)
    sd = ImageDraw.Draw(shade)
    for part in PART_ORDER:
        xs = [x for x, _ in FIG[part]]
        cx = (min(xs) + max(xs)) / 2
        m = _part_mask(part, kk)
        stripes = Image.new("L", big.size, 0)
        st = ImageDraw.Draw(stripes)
        for i in range(-PLATE[1], PLATE[0] + PLATE[1], 3):
            st.line([((i) * kk, 0), ((i + PLATE[1]) * kk, PLATE[1] * kk)], fill=255, width=int(0.45 * kk))
        half = Image.new("L", big.size, 0)
        ImageDraw.Draw(half).rectangle([cx * kk + 1.5 * kk, 0, PLATE[0] * kk, PLATE[1] * kk], fill=255)
        sd.bitmap((0, 0), Image.fromarray((np.asarray(stripes) & np.asarray(half) & np.asarray(m)).astype(np.uint8)),
                  fill=255)
    big.paste((120, 100, 82, 200), mask=shade)
    for part in PART_ORDER:
        pts = [(x * kk, y * kk) for x, y in FIG[part]]
        d.line(pts + [pts[0]], fill=(34, 26, 24, 255), width=int(0.9 * kk), joint="curve")
    for line in INNER_LINES:
        d.line([(x * kk, y * kk) for x, y in line], fill=(70, 54, 46, 220), width=int(0.55 * kk), joint="curve")
    # líneas de rótulo (los nombres los escribe el juego)
    for part, (a, b) in {"head": ((47, 18), (14, 18)), "arm_r": ((30, 80), (12, 80)), "leg_r": ((44, 130), (12, 130)),
                         "torso": ((70, 60), (100, 60)), "arm_l": ((84, 92), (100, 92)), "leg_l": ((66, 136), (100, 136))}.items():
        d.line([(a[0] * kk, a[1] * kk), (b[0] * kk, b[1] * kk)], fill=(60, 50, 42, 160), width=int(0.4 * kk))
        d.ellipse([(b[0] - 1.2) * kk, (b[1] - 1.2) * kk, (b[0] + 1.2) * kk, (b[1] + 1.2) * kk], outline=(60, 50, 42, 200),
                  width=int(0.4 * kk))
    ink = big.resize((w, h), Image.Resampling.BOX)
    ia = np.asarray(ink).astype(np.float32)
    al = ia[..., 3:4] / 255.0
    out = paper.copy()
    out[..., :3] = paper[..., :3] * (1 - al) + ia[..., :3] * al
    result = {"plate": Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")}
    for part in FIG:
        m = _part_mask(part, kk).resize((w, h), Image.Resampling.BOX)
        a = (np.asarray(m) >= 100).astype(np.uint8) * 255
        rgba = np.zeros((h, w, 4), np.uint8)
        rgba[..., :3] = 255
        rgba[..., 3] = a
        result[part] = Image.fromarray(rgba, "RGBA")
    return result


MINI = (22, 40)


def mini_figure() -> dict[str, Image.Image]:
    """Silueta pequeña para el mapa de heridas: una máscara por parte y el contorno."""
    k = 8
    w, h = MINI[0] * S, MINI[1] * S
    # La figura ocupa de x 22 a 90 y de y 8 a 153 en la lámina: se encaja en la silueta pequeña.
    sx = (MINI[0] - 1) / 70.0
    sy = (MINI[1] - 1) / 146.0

    def tr(pts):
        return [((x - 21) * sx * S * k, (y - 7.5) * sy * S * k) for x, y in pts]

    result: dict[str, Image.Image] = {}
    union = np.zeros((h, w), bool)
    for part in FIG:
        im = Image.new("L", (w * k, h * k), 0)
        ImageDraw.Draw(im).polygon(tr(FIG[part]), fill=255)
        a = np.asarray(im.resize((w, h), Image.Resampling.BOX)) >= 96
        union |= a
        rgba = np.zeros((h, w, 4), np.uint8)
        rgba[..., :3] = 255
        rgba[..., 3] = a * 255
        result["mini_" + part] = Image.fromarray(rgba, "RGBA")
    ring = ndimage.binary_dilation(union) & ~union
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[ring] = (30, 24, 22, 255)
    result["mini_outline"] = Image.fromarray(rgba, "RGBA")
    return result


# --- puntero ------------------------------------------------------------------------------------

def cursor() -> Image.Image:
    """Puntero: una plumilla de tinta con el filo hacia arriba a la izquierda (a 2× la vista)."""
    size = 12
    im, d, k = hi((size * S, size * S), 8)
    kk = k * S
    d.polygon(P([(0.6, 0.6), (9.6, 4.2), (6, 6), (4.2, 9.6)], kk), fill=BONE)
    d.polygon(P([(6, 6), (9.6, 4.2), (11.4, 9.6), (9.6, 11.4), (4.2, 9.6)], kk), fill=(60, 50, 44, 255))
    d.line(P([(0.8, 0.8), (6, 6)], kk), fill=(80, 64, 56, 255), width=int(0.6 * kk))
    small = ink_outline(reduce_to(im, (size * S, size * S)), diagonal=True)
    return small.resize((size * S * 2, size * S * 2), Image.Resampling.NEAREST)


# --- hoja de revisión ----------------------------------------------------------------------------

def sheet(images: dict[str, Image.Image], path: str) -> None:
    """Hoja con todas las piezas ampliadas ×3 sobre fondo oscuro, para revisar."""
    pad = 6
    tiles = [(n, im.resize((im.width * 3, im.height * 3), Image.Resampling.NEAREST)) for n, im in images.items()]
    width = 900
    x = y = pad
    row_h = 0
    pos = []
    for n, im in tiles:
        if x + im.width > width:
            x = pad
            y += row_h + pad + 10
            row_h = 0
        pos.append((x, y, im, n))
        x += im.width + pad
        row_h = max(row_h, im.height)
    out = Image.new("RGBA", (width, y + row_h + pad + 10), (18, 17, 20, 255))
    d = ImageDraw.Draw(out)
    f = font(["LiberationMono-Regular.ttf", "DejaVuSansMono.ttf"], 9)
    for x, y, im, n in pos:
        out.alpha_composite(im, (x, y + 10))
        d.text((x, y), n, font=f, fill=(150, 140, 120, 255))
    out.save(path)


def main() -> None:
    global S, OUT
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--scale", type=int, default=1)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--sheet", default="")
    args = ap.parse_args()
    S = args.scale
    OUT = args.out
    pieces: dict[str, Image.Image] = {
        "frame_metal.png": metal_frame(),
        "frame_paper.png": paper_frame(3),
        "frame_folder.png": paper_frame(5, "paper", 0.64),
        "tab_paper.png": tab_paper(),
        "tape.png": tape(),
        "band.png": band(),
        "check.png": check(),
        "rule.png": rule(),
        "tube.png": tube(),
        "cursor.png": cursor(),
    }
    for i, (key, text) in enumerate(STAMPS.items()):
        pieces["stamp_%s.png" % key] = stamp(text, 40 + i, 15 if key != "autorizado" else 13)
    for key, fn in ORDER_ICONS.items():
        pieces["icons/order_%s.png" % key] = _icon(fn, 16)
    for key, fn in STATUS_ICONS.items():
        pieces["icons/status_%s.png" % key] = _icon(fn, 12)
    for key, im in diagram().items():
        pieces["diagram/%s.png" % key] = im
    for key, im in mini_figure().items():
        pieces["diagram/%s.png" % key] = im
    for name, im in pieces.items():
        save(im, name)
    if args.sheet:
        sheet({n: im for n, im in pieces.items()}, args.sheet)
    print("%d piezas en %s" % (len(pieces), OUT))


if __name__ == "__main__":
    main()
