"""Maqueta del menú principal a 1280×720 y marco de interfaz con el arte del juego.

- Fondo: ilustración pintada en 2D a 640×360 (se dobla a 1280×720 para que el píxel se lea): el
  pasillo de la planta con la puerta de la Habitación 09 al fondo, una camilla con correas bajo el
  único fluorescente que funciona, el pie de suero tirado y el protagonista de espaldas en la
  penumbra. La perspectiva solo sirve para colocar las formas planas (suelo, paredes, puertas): es
  un dibujo con punto de fuga, no una escena 3D.
- Título: versalitas espaciadas, desgastadas, con «IX» en rojo.
- Opciones en un marco de chapa oxidada con remaches y una pestaña de expediente («EXPEDIENTE 09»,
  canon: el expediente de la Habitación 09).
- `frame_box` sirve también para las cajas del combate.
"""

from __future__ import annotations

import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import palette_hd  # noqa: E402,F401
import protagonist_hd  # noqa: E402
from paint import Piece, compose, lerp  # noqa: E402

BW, BH = 640, 360
VP_BACK = (340, 112, 462, 192)      # pared del fondo: x0, y0, x1, y1
NEAR = (-60, -80, 700, 440)         # bordes cercanos (fuera de cuadro)


def _font(names: list[str], size: int) -> ImageFont.FreeTypeFont:
    dirs = ["/mnt/skills/examples/canvas-design/canvas-fonts", "/usr/share/fonts/truetype/liberation",
            "/usr/share/fonts/truetype/dejavu"]
    for n in names:
        for d in dirs:
            p = os.path.join(d, n)
            if os.path.exists(p):
                return ImageFont.truetype(p, size)
    return ImageFont.load_default()


SERIF = ["LiberationSerif-Regular.ttf", "DejaVuSerif.ttf"]
SERIF_B = ["LiberationSerif-Bold.ttf", "DejaVuSerif-Bold.ttf"]
TITLE = ["LibreBaskerville-Regular.ttf", "Gloock-Regular.ttf", "LiberationSerif-Regular.ttf"]
MONO = ["LiberationMono-Regular.ttf", "DejaVuSansMono.ttf"]


# --- colocación con punto de fuga -------------------------------------------------------------

def _u(d: float) -> float:
    """Profundidad en metros → fracción entre el borde cercano (0) y la pared del fondo (1)."""
    return d / (d + 2.6)


def P(d: float, s: float, h: float) -> tuple[float, float]:
    """Punto del pasillo: profundidad d (m), s de 0 (pared izquierda) a 1 (derecha), h de 0 (suelo)
    a 1 (techo)."""
    u = _u(d) / _u(12.0)
    u = min(u, 1.0)
    x0, y0, x1, y1 = VP_BACK
    nx0, ny0, nx1, ny1 = NEAR
    lx = nx0 + (x0 - nx0) * u
    rx = nx1 + (x1 - nx1) * u
    fy = ny1 + (y1 - ny1) * u
    cy = ny0 + (y0 - ny0) * u
    return (lx + (rx - lx) * s, fy + (cy - fy) * h)


def quad(d0, d1, s0, s1, h0, h1, wall: str):
    if wall == "floor":
        return [P(d0, s0, h0), P(d0, s1, h0), P(d1, s1, h0), P(d1, s0, h0)]
    if wall == "left":
        return [P(d0, 0, h0), P(d1, 0, h0), P(d1, 0, h1), P(d0, 0, h1)]
    if wall == "right":
        return [P(d0, 1, h0), P(d1, 1, h0), P(d1, 1, h1), P(d0, 1, h1)]
    raise ValueError(wall)


def background() -> Image.Image:
    rnd = random.Random(9)
    x0, y0, x1, y1 = VP_BACK
    # --- paredes, suelo y techo ---
    room = Piece(BW, BH, "room")
    room.outline = False
    room.fill([P(0, 0, 0), P(0, 1, 0), P(12, 1, 0), P(12, 0, 0)], "lino", 0.5)
    room.fill([P(0, 0, 1), P(0, 1, 1), P(12, 1, 1), P(12, 0, 1)], "plaster", 0.35)
    for side in (0, 1):
        room.fill([P(0, side, 0.0), P(12, side, 0.0), P(12, side, 0.36), P(0, side, 0.36)], "tile", 0.5)
        room.fill([P(0, side, 0.36), P(12, side, 0.36), P(12, side, 1.0), P(0, side, 1.0)], "plaster", 0.5)
    room.fill([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], "plaster", 0.3)
    room.fill([(x0, y1 - 29), (x1, y1 - 29), (x1, y1), (x0, y1)], "tile", 0.4)
    # baldosas del suelo y azulejos en perspectiva
    d = 0.0
    while d < 12:
        room.crease([P(d, 0, 0), P(d, 1, 0)], 0.2, 0.6, clip=["lino"])
        for side in (0, 1):
            room.crease([P(d, side, 0), P(d, side, 0.36)], 0.22, 0.5, clip=["tile"])
        d += 0.5
    for k in range(1, 8):
        s = k / 8
        room.crease([P(0, s, 0), P(12, s, 0)], 0.16, 0.6, clip=["lino"])
    for h in (0.09, 0.18, 0.27):
        for side in (0, 1):
            room.crease([P(0, side, h), P(12, side, h)], 0.18, 0.5, clip=["tile"])
    # barandilla metálica a lo largo de las paredes
    for side in (0, 1):
        room.fill([P(0, side, 0.37), P(12, side, 0.37), P(12, side, 0.41), P(0, side, 0.41)], "metal", 0.45)
        room.crease([P(0, side, 0.405), P(12, side, 0.405)], -0.25, 0.6, clip=["metal"])
    # humedades, moho y desconchones
    for c, r, sd in (((60, 70), 40, 1), ((560, 60), 34, 2), ((250, 120), 14, 3), ((520, 150), 12, 4)):
        room.stain(c, r, "mold", sd, stretch=(1.0, 1.6), ring=0.08, val=0.5, clip=["plaster"], drip=1.5)
    room.noise(0.18, 10.0, 5, clip=["plaster"])
    room.noise(0.12, 6.0, 6, clip=["lino", "tile"])
    room.pores(0.1, 0.05, 7)
    # puertas: dos a la derecha, una a la izquierda, la 09 al fondo entreabierta
    doors = [("right", 2.0, 3.2), ("right", 6.0, 7.0), ("left", 0.6, 2.0), ("left", 4.4, 5.3)]
    for wall, a, b in doors:
        q = quad(a, b, 0, 0, 0.0, 0.72, wall)
        room.fill(q, "paint", 0.32)
        frame_ = quad(a - 0.08, b + 0.08, 0, 0, 0.0, 0.75, wall)
        room.crease(frame_[1:3] + frame_[3:] + frame_[:1], -0.2, 0.8)
        win = quad(a + (b - a) * 0.25, a + (b - a) * 0.75, 0, 0, 0.45, 0.62, wall)
        room.fill(win, "dark", 0.3)
        room.crease([lerp(q[0], q[1], 0.5), lerp(q[3], q[2], 0.5)], 0.14, 0.6, clip=["paint"])
    dw = [(x0 + 42, y1 - 2), (x0 + 82, y1 - 2), (x0 + 82, y0 + 26), (x0 + 42, y0 + 26)]
    room.fill(dw, "paint", 0.28)
    room.fill([(x0 + 76, y1 - 2), (x0 + 82, y1 - 2), (x0 + 82, y0 + 26), (x0 + 76, y0 + 26)], "fluo", 0.25)   # rendija
    room.fill([(x0 + 54, y0 + 34), (x0 + 68, y0 + 34), (x0 + 68, y0 + 41), (x0 + 54, y0 + 41)], "paper", 0.55)
    # fluorescentes: el cercano funciona, los demás están muertos
    tubes = []
    for dd, on in ((1.4, True), (4.0, False), (7.5, False)):
        q = [P(dd, 0.42, 1), P(dd, 0.58, 1), P(dd + 0.25, 0.58, 1), P(dd + 0.25, 0.42, 1)]
        room.fill(q, "fluo" if on else "metal", 0.95 if on else 0.3)
        tubes.append((q, on))
    room.form((-0.3, -0.95), bevel=2.0, strength=0.1, rim_dark=0.0)
    # --- camilla con correas bajo la luz ---
    gur = Piece(BW, BH, "gurney")
    top = [P(2.2, 0.40, 0.3), P(2.2, 0.72, 0.3), P(4.0, 0.72, 0.3), P(4.0, 0.40, 0.3)]
    side = [P(2.2, 0.40, 0.3), P(2.2, 0.72, 0.3), P(2.2, 0.72, 0.25), P(2.2, 0.40, 0.25)]
    left = [P(2.2, 0.40, 0.3), P(4.0, 0.40, 0.3), P(4.0, 0.40, 0.25), P(2.2, 0.40, 0.25)]
    for a, b in ((P(2.25, 0.42, 0.25), P(2.25, 0.42, 0.03)), (P(2.25, 0.70, 0.25), P(2.25, 0.70, 0.03)),
                 (P(3.9, 0.42, 0.25), P(3.9, 0.42, 0.05)), (P(3.9, 0.70, 0.25), P(3.9, 0.70, 0.05))):
        gur.line([a, b], "metal", 0.6, width=2)
        gur.fill([(b[0] - 3, b[1] - 1), (b[0] + 3, b[1] - 1), (b[0] + 3, b[1] + 3), (b[0] - 3, b[1] + 3)], "dark", 0.6)
    gur.line([P(2.25, 0.42, 0.12), P(2.25, 0.70, 0.12)], "metal", 0.5, width=1)
    gur.fill(side, "metal", 0.5)
    gur.fill(left, "metal", 0.4)
    gur.fill(top, "mattress", 0.66)
    sheet = [P(2.15, 0.38, 0.31), P(2.15, 0.74, 0.31), P(3.6, 0.75, 0.31), P(3.4, 0.78, 0.12), P(2.6, 0.77, 0.14),
             P(2.1, 0.75, 0.2)]
    gur.fill(sheet, "gown", 0.66)
    gur.form((-0.3, -0.95), bevel=3.0, strength=0.3, rim_dark=0.12)
    for k in range(3):
        a = lerp(sheet[1], sheet[3], 0.2 + k * 0.25)
        gur.crease([a, (a[0] + 2, a[1] + 14)], 0.2, 1.0, ridge=0.1, ridge_off=(-1, 0), clip=["gown"])
    gur.stain(lerp(P(2.8, 0.52, 0.3), P(3.2, 0.62, 0.3), 0.5), 9, "blood", 11, val=0.35, stretch=(1.6, 0.7), ring=0.14)
    gur.stain(P(3.0, 0.76, 0.2), 4, "blood", 12, val=0.35, stretch=(0.6, 2.0), ring=0.1, drip=2.0)
    for s_ in (0.48, 0.64):                                            # correas sueltas que cuelgan
        a = P(3.0, s_, 0.3)
        gur.line([a, (a[0] - 3, a[1] + 14), (a[0] - 1, a[1] + 26)], "brief", 0.35, width=2)
        gur.dot(a[0] - 1, a[1] + 26, "metal", 0.9, inside=False)
    gur.line([P(1.6, 0.86, 0.0), P(3.1, 0.62, 0.02)], "metal", 0.7, width=2)          # pie de suero tirado
    gur.line([P(3.1, 0.62, 0.02), P(3.25, 0.6, 0.06)], "metal", 0.6, width=1)
    gur.fill([(p[0] - 4, p[1] - 3) for p in [P(3.15, 0.63, 0.03)]] + [(P(3.15, 0.63, 0.03)[0] + 4, P(3.15, 0.63, 0.03)[1] - 3),
                                                                    (P(3.15, 0.63, 0.03)[0] + 3, P(3.15, 0.63, 0.03)[1] + 4)],
             "tube", 0.5)
    for _ in range(9):                                                  # papeles por el suelo
        dd, s_ = rnd.uniform(1.0, 5.0), rnd.uniform(0.15, 0.9)
        c = P(dd, s_, 0)
        w = 9 / (1 + dd * 0.6)
        gur.fill([(c[0] - w, c[1] - w * 0.3), (c[0] + w * 0.8, c[1] - w * 0.5), (c[0] + w, c[1] + w * 0.25),
                  (c[0] - w * 0.7, c[1] + w * 0.4)], "paper", rnd.uniform(0.5, 0.7))
    # --- protagonista de espaldas, en primer plano a la izquierda ---
    hero = protagonist_hd.frame("N", protagonist_hd.IDLE[0])
    # --- montaje y luz ---
    im = compose([room, gur], (BW, BH), contact=0.35, blur=3.0)
    im.alpha_composite(hero, (215 - 56, 352 - 150))
    a = np.asarray(im).astype(np.float32)
    yy, xx = np.mgrid[0:BH, 0:BW].astype(np.float32)
    tq, _ = tubes[0]
    tx = sum(p[0] for p in tq) / 4
    ty = sum(p[1] for p in tq) / 4
    fx, fy = P(1.55, 0.5, 0)
    pool = np.exp(-(((xx - fx) / 170) ** 2 + ((yy - fy) / 90) ** 2))
    cone = np.exp(-(((xx - tx) / (40 + np.clip(yy - ty, 0, None) * 0.9)) ** 2)) * (yy > ty)
    wash = np.exp(-(((xx - tx) / 260) ** 2 + ((yy - ty) / 160) ** 2))
    end = np.exp(-(((xx - (x0 + 79)) / 10) ** 2 + ((yy - (y0 + 60)) / 40) ** 2))
    light = 0.1 + 0.85 * pool + 0.25 * cone + 0.5 * wash + 0.4 * end
    light = np.clip(light, 0, 1.25)
    tint = np.array([0.9, 1.02, 0.96])
    a[..., :3] *= (light[..., None] * tint)
    glow = ndimage.gaussian_filter(((xx > tq[0][0] - 2) & (xx < tq[1][0] + 2) & (yy > tq[0][1] - 3) &
                                    (yy < tq[2][1] + 3)).astype(np.float32), 10)
    a[..., :3] += glow[..., None] * np.array([150, 190, 165]) * 1.4
    thr = np.tile((np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16, (BH // 4 + 1, BW // 4 + 1))[:BH, :BW]
    a[..., :3] = np.floor(a[..., :3] / 6 + thr[..., None]) * 6           # escalones tramados
    out = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    return out


# --- marco de interfaz ----------------------------------------------------------------------

def frame_box(w: int, h: int, tab: str | None = None, seed: int = 1) -> Image.Image:
    """Caja de interfaz: fondo casi negro translúcido, marco de chapa oxidada con remaches y
    escuadras en las esquinas; opcionalmente una pestaña de expediente con texto a máquina."""
    pc = Piece(w, h, "frame")
    pc.outline = False
    b = 9
    pc.fill([(0, 0), (w, 0), (w, h), (0, h)], "iron", 0.5)
    inner = [(b, b), (w - b, b), (w - b, h - b), (b, h - b)]
    pc.fill(inner, "dark", 0.5)
    fr = pc.of("iron")
    pc.form((-0.4, -0.9), bevel=4.0, strength=0.5, rim_dark=0.25, region=fr)
    pc.noise(0.2, 6.0, seed, clip=["iron"])
    pc.pores(0.12, 0.06, seed + 1, clip=["iron"])
    rnd = random.Random(seed)
    for _ in range(int((w + h) / 40)):
        side = rnd.randrange(4)
        t = rnd.random()
        c = [(t * w, b / 2), (t * w, h - b / 2), (b / 2, t * h), (w - b / 2, t * h)][side]
        pc.stain(c, rnd.uniform(4, 10), "rust", rnd.randrange(999), val=0.5, stretch=(1.6, 0.6) if side < 2 else (0.6, 1.6),
                 ring=0.08, clip=["iron", "rust"])
    pc.crease([(b, b), (w - b, b)], 0.3, 0.8, clip=["iron", "rust"])
    pc.crease([(b, h - b), (w - b, h - b)], -0.2, 0.8, clip=["iron", "rust"])
    # escuadras y remaches
    for cx, cy in ((0, 0), (w, 0), (0, h), (w, h)):
        sx = 1 if cx == 0 else -1
        sy = 1 if cy == 0 else -1
        pc.fill([(cx, cy), (cx + sx * 26, cy), (cx + sx * 26, cy + sy * 12), (cx + sx * 12, cy + sy * 12),
                 (cx + sx * 12, cy + sy * 26), (cx, cy + sy * 26)], "metal", 0.45)
        for rx, ry in ((6, 6), (19, 6), (6, 19)):
            x, y = cx + sx * rx, cy + sy * ry
            pc.fill([(x - 2, y - 1), (x - 1, y - 2), (x + 1, y - 2), (x + 2, y - 1), (x + 2, y + 1), (x + 1, y + 2),
                     (x - 1, y + 2), (x - 2, y + 1)], "metal", 0.75)
            pc.dot(x - 1, y - 1, "metal", 1.0)
            pc.dot(x + 1, y + 1, "metal", 0.2)
    pc.form((-0.4, -0.9), bevel=3.0, strength=0.4, rim_dark=0.15, region=pc.of("metal"))
    x = 40
    while x < w - 40:
        for y in (b / 2, h - b / 2):
            pc.fill([(x - 1.5, y - 1.5), (x + 1.5, y - 1.5), (x + 1.5, y + 1.5), (x - 1.5, y + 1.5)], "metal", 0.7)
            pc.dot(x - 1, y - 1, "metal", 0.95)
        x += 44
    pc.noise(0.12, 30.0, seed + 5, clip=["dark"])
    pc.plane([(b, b), (w - b, b), (w - b, b + 18), (b, b + 30)], 0.12, 8.0, clip=["dark"])
    im = pc.render(outline=False)
    a = np.asarray(im).copy()
    dk = pc.of("dark")
    a[dk, 3] = 225
    im = Image.fromarray(a, "RGBA")
    if tab:
        f = _font(MONO, 15)
        tw = int(ImageDraw.Draw(im).textlength(tab, font=f)) + 26
        tp = Piece(tw, 30, "tab")
        tp.fill([(0, 4), (tw - 6, 0), (tw, 26), (4, 30)], "paper", 0.6)
        tp.form((-0.4, -0.9), bevel=3.0, strength=0.25, rim_dark=0.15)
        tp.noise(0.15, 5.0, seed + 9)
        tp.stain((tw - 10, 24), 4, "stain", seed + 10, ring=0.1, val=0.4)
        ti = tp.render(outline=False)
        ImageDraw.Draw(ti).text((12, 6), tab, font=f, fill=(40, 34, 28, 255))
        ti = ti.rotate(-1.5, resample=Image.NEAREST, expand=True)
        out = Image.new("RGBA", (w, h + 18), (0, 0, 0, 0))
        out.alpha_composite(im, (0, 18))
        out.alpha_composite(ti, (34, 0))
        return out
    return im


def _title(canvas: Image.Image, xy: tuple[int, int]) -> None:
    """«LA NOVENA VIGILIA» en versalitas espaciadas, desgastadas, con sombra y un «IX» rojo."""
    x, y = xy
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    small = _font(TITLE, 30)
    big = _font(TITLE, 78)
    d.text((x + 4, y), "L A", font=small, fill=(214, 204, 182, 255))
    words = "NOVENA VIGILIA"
    cx = x
    for ch in words:
        d.text((cx, y + 30), ch, font=big, fill=(222, 212, 190, 255))
        cx += int(d.textlength(ch, font=big)) + (10 if ch != " " else 14)
    a = np.asarray(layer).astype(np.float32)
    rng = np.random.default_rng(3)
    # desgaste: arañazos horizontales y picado que se comen la tinta
    scratch = np.zeros(a.shape[:2], bool)
    for _ in range(60):
        yy = rng.integers(y + 30, y + 120)
        x0 = rng.integers(x, cx)
        scratch[yy, x0:x0 + rng.integers(6, 60)] = True
    pits = rng.random(a.shape[:2]) < 0.035
    a[scratch | pits, 3] *= 0.15
    layer = Image.fromarray(a.astype(np.uint8), "RGBA")
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sa = np.asarray(layer).copy()
    sa[..., :3] = 0
    shadow = Image.fromarray(sa, "RGBA").filter(ImageFilter.GaussianBlur(6))
    canvas.alpha_composite(shadow, (3, 5))
    canvas.alpha_composite(layer)
    d2 = ImageDraw.Draw(canvas)
    d2.line([(x + 2, y + 124), (cx - 10, y + 124)], fill=(150, 140, 120, 200), width=1)
    numeral = _font(TITLE, 26)
    d2.text((x + 2, y + 132), "IX", font=numeral, fill=(150, 40, 34, 255))


def title_mockup(grade=None) -> Image.Image:
    """`grade`: filtro que se aplica solo al fondo (la interfaz va encima, nítida)."""
    bg = background().resize((1280, 720), Image.NEAREST)
    if grade is not None:
        bg = grade(bg)
    can = bg.copy()
    _title(can, (86, 70))
    box = frame_box(330, 290, tab="EXPEDIENTE 09 · HAB. 09", seed=3)
    bx, by = 916, 396
    can.alpha_composite(box, (bx, by))
    f = _font(SERIF, 25)
    d = ImageDraw.Draw(can)
    opts = ["Continuar", "Nueva partida", "Cargar", "Opciones", "Créditos", "Salir"]
    for i, t in enumerate(opts):
        yy = by + 46 + i * 40
        if i == 1:
            d.rectangle((bx + 18, yy - 4, bx + 312, yy + 30), fill=(52, 14, 16, 190))
            d.line([(bx + 24, yy + 13), (bx + 30, yy + 20), (bx + 42, yy + 2)], fill=(176, 52, 40, 255), width=3)   # marca de bolígrafo
        col = (226, 216, 194, 255) if i == 1 else ((110, 104, 94, 255) if i == 0 else (190, 182, 164, 255))
        d.text((bx + 56, yy), t, font=f, fill=col)
    d.text((24, 690), "v0.1 · prólogo", font=_font(MONO, 14), fill=(96, 92, 84, 255))
    return can


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n/hd_title.png"
    title_mockup().save(out)
    background().save(out.replace(".png", "_bg.png"))
