"""Hojas de comparación de la muestra 2D (para debatir, no para el juego).

    python3 -I tools/art2d/sheets.py [carpeta_de_salida] [captura_del_juego.png]

Genera:
- `antes_despues.png`: arte actual (volúmenes 3D rasterizados) frente al dibujo 2D nuevo.
- `protagonista_8dir.png`: las 8 direcciones con reposo y paso (×3).
- `protagonista_combate.png`, `enfermero.png`, `enfermero_piezas.png`, `escenario.png`.
- `maqueta_combate.png`: 640×360, fondo negro con foco, enfermero arriba, protagonista de
  espaldas abajo y las dos cajas de menú; con el filtro de película del juego (`film_grade`).
- `en_sala.png`: si se pasa una captura del juego, el protagonista nuevo pegado en ella.
"""

from __future__ import annotations

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

import enemy_nurse  # noqa: E402
import props2d  # noqa: E402
import protagonist  # noqa: E402
import protagonist_battle  # noqa: E402
from px2d import sheet, upscale  # noqa: E402

BG = (22, 21, 24)
INK = (190, 182, 165)


def _font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    for name in (("LiberationSerif-Bold.ttf" if bold else "LiberationSerif-Regular.ttf"),
                 ("DejaVuSerif-Bold.ttf" if bold else "DejaVuSerif.ttf")):
        for d in ("/usr/share/fonts/truetype/liberation", "/usr/share/fonts/truetype/dejavu"):
            p = os.path.join(d, name)
            if os.path.exists(p):
                return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def film_grade(im: Image.Image, seed: int = 7) -> Image.Image:
    """Aproximación en numpy de shaders/film_grade.gdshader con sus valores por defecto:
    desatura, sombras frías y aplastadas, viñeta y grano monocromo."""
    a = np.asarray(im.convert("RGB")).astype(np.float32) / 255.0
    h, w, _ = a.shape
    luma = a @ np.array([0.299, 0.587, 0.114], np.float32)
    a = a + (luma[..., None] - a) * 0.38
    a = luma[..., None] + (a - luma[..., None]) * 0.78
    t = np.clip((luma - 0.08) / 0.52, 0, 1)
    t = t * t * (3 - 2 * t)
    tone = np.array([0.86, 0.9, 1.0]) * (1 - t[..., None]) + np.array([1.0, 0.97, 0.9]) * t[..., None]
    a = a * tone
    a = (a - 0.5) * 1.04 + 0.5
    luma = a @ np.array([0.299, 0.587, 0.114], np.float32)
    piv = 0.16
    low = np.clip(luma / piv, 0, 1)
    crushed = np.power(low, 1.0 + 0.22 * 1.6) * piv
    m = (luma < piv) & (luma > 1e-4)
    a[m] *= (crushed[m] / luma[m])[..., None]
    yy, xx = np.mgrid[0:h, 0:w]
    cx = (xx / w - 0.5) * (w / h)
    cy = yy / h - 0.5
    dist = np.sqrt(cx * cx + cy * cy) * 1.35
    s = np.clip((dist - 0.32) / 0.55, 0, 1)
    s = s * s * (3 - 2 * s)
    a *= np.clip(1 - s * 0.85, 0, 1)[..., None]
    rng = np.random.default_rng(seed)
    g = rng.random((h, w)) + rng.random((h, w)) - 1.0
    luma = a @ np.array([0.299, 0.587, 0.114], np.float32)
    k = np.clip((luma - 0.02) / 0.33, 0, 1)
    k = k * k * (3 - 2 * k)
    a += (g * 0.05 * (0.35 + 0.65 * k))[..., None]
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGB").convert("RGBA")


def _label(im: Image.Image, text: str, xy, size: int = 16, fill=INK) -> None:
    ImageDraw.Draw(im).text(xy, text, font=_font(size), fill=fill)


def _on_bg(im: Image.Image, bg=BG) -> Image.Image:
    out = Image.new("RGBA", im.size, (*bg, 255))
    out.alpha_composite(im)
    return out


# --- arte actual (para el antes/después) -------------------------------------------------------

def old_protagonist() -> list[Image.Image]:
    """8 de las 16 orientaciones del sprite actual (cuerpo + bata), fotograma de reposo."""
    d = os.path.join(ROOT, "assets/sprites/characters")
    base = Image.open(os.path.join(d, "protagonist.png")).convert("RGBA")
    gown = Image.open(os.path.join(d, "wear/bata_paciente.png")).convert("RGBA")
    c = Image.alpha_composite(base, gown)
    return [c.crop((0, r * 68, 48, r * 68 + 68)) for r in range(0, 16, 2)]


def old_nurse() -> Image.Image:
    d = os.path.join(ROOT, "assets/sprites/enemies/enfermero")
    out = Image.new("RGBA", (272, 312), (0, 0, 0, 0))
    for o in ("leg_l", "leg_r", "body", "head", "arm_l", "arm_r"):
        out.alpha_composite(Image.open(os.path.join(d, o + ".png")).convert("RGBA").crop((0, 0, 272, 312)))
    return out


def old_locker() -> Image.Image:
    im = Image.open(os.path.join(ROOT, "assets/sprites/props/locker.png")).convert("RGBA")
    return im.crop((0, 0, 44, 92))


# --- hojas ----------------------------------------------------------------------------------

def before_after() -> Image.Image:
    k = 3
    W = 1720
    out = Image.new("RGBA", (W, 1180), (*BG, 255))
    _label(out, "ANTES: volúmenes 3D rasterizados (arte actual)", (16, 10), 22)
    _label(out, "DESPUÉS: dibujo 2D a mano en el plano (muestra)", (16, 590), 22)
    # personaje
    old = sheet([old_protagonist()], gap=4)
    out.alpha_composite(upscale(old, k), (16, 44))
    new = sheet([[protagonist.frame(d, protagonist.IDLE[0]) for d in protagonist.DIRECTIONS]], gap=4)
    out.alpha_composite(upscale(new, k), (16, 624))
    _label(out, "Mapa · 48×68 · 16 orientaciones", (16, 44 + 68 * k + 4), 15)
    _label(out, "Mapa · 56×80 · 8 direcciones (S, SO, O, NO, N, NE, E, SE)", (16, 624 + 80 * k + 4), 15)
    # enfermero (escala 1:1 para que se vea el tamaño real en pantalla, y ×1,5)
    on = old_nurse()
    out.alpha_composite(upscale(on.crop((40, 20, 232, 312)), 1), (1480, 40))
    nn = enemy_nurse.frames()["idle_0"]
    out.alpha_composite(nn, (1490, 600))
    _label(out, "Combate ×1", (1480, 340), 15)
    _label(out, "Combate 200×260 ×1", (1490, 864), 15)
    # taquilla
    out.alpha_composite(upscale(old_locker(), k), (16, 330))
    out.alpha_composite(upscale(props2d.locker(False), k), (16, 910))
    out.alpha_composite(upscale(props2d.locker(True), k), (16 + 44 * k + 12, 910))
    _label(out, "Taquilla ×3", (16 + 44 * k + 12, 330 + 8), 15)
    # protagonista en combate (no existía)
    pb = protagonist_battle.frames()[0]
    out.alpha_composite(upscale(pb, 2), (400, 910))
    _label(out, "Combate de espaldas 64×110 ×2 (nuevo)", (400 + 140, 1140), 15)
    return out


def battle_mockup(attack: bool = False) -> Image.Image:
    """Maqueta de combate a 640×360 como en Fear & Hunger."""
    W, H = 640, 360
    a = np.zeros((H, W, 3), np.float32)
    a[:] = (6, 5, 7)
    # foco cenital: un círculo de luz en el suelo, en bandas planas con tramado entre ellas
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.sqrt(((xx - 320) / 230.0) ** 2 + ((yy - 250) / 70.0) ** 2)
    cone = np.clip(1.0 - np.abs(xx - 320) / (60 + (yy / H) * 220), 0, 1) * np.clip(yy / 260, 0, 1)
    lvl = np.clip(1.2 - d, 0, 1) * 0.8 + cone * 0.25
    bands = np.floor(lvl * 5 + ((xx + yy) % 2) * 0.5) / 5
    floor = np.array([64, 58, 54], np.float32)
    a += bands[..., None] * floor
    bg = Image.fromarray(a.astype(np.uint8), "RGB").convert("RGBA")
    f = enemy_nurse.frames()["attack" if attack else "idle_0"]
    bg.alpha_composite(f, (220, -4))
    pb = protagonist_battle.frames()[1]
    bg.alpha_composite(pb, (158, 168))
    # cajas de menú: fondo oscuro translúcido, borde fino claro
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(ov)
    bone = (191, 182, 163, 255)
    for box in ((6, 262, 132, 354), (138, 262, 634, 354)):
        dr.rectangle(box, fill=(8, 7, 10, 215))
        dr.rectangle(box, outline=(120, 114, 104, 255))
        dr.rectangle((box[0] + 2, box[1] + 2, box[2] - 2, box[3] - 2), outline=(60, 56, 52, 255))
    dr.rectangle((12, 268, 126, 286), fill=(70, 64, 60, 200), outline=(140, 132, 120, 255))
    font = _font(17)
    for i, t in enumerate(("Atacar", "Habilidades", "Guardia", "Objeto")):
        tw = dr.textlength(t, font=font)
        dr.text((69 - tw / 2, 268 + i * 21), t, font=font, fill=bone)
    dr.rectangle((144, 268, 628, 286), fill=(70, 64, 60, 200), outline=(140, 132, 120, 255))
    dr.text((152, 268), "Paciente 09", font=font, fill=bone)
    small = _font(15)
    blue = (110, 122, 150, 255)
    for label, val, x, frac in (("Cuerpo", "82", 340, 1.0), ("Mente", "70", 500, 1.0)):
        dr.text((x, 269), label, font=small, fill=blue)
        tw = dr.textlength(val, font=font)
        dr.text((x + 110 - tw, 268), val, font=font, fill=bone)
        dr.line((x, 286, x + 112, 286), fill=(120, 30, 30, 255), width=2)
    if attack:
        dr.rectangle((60, 8, 580, 34), fill=(8, 7, 10, 200), outline=(120, 114, 104, 255))
        msg = "Levanta el brazo de bisturíes por encima de la máscara."
        tw = dr.textlength(msg, font=small)
        dr.text((320 - tw / 2, 13), msg, font=small, fill=bone)
    bg.alpha_composite(ov)
    return film_grade(bg)


def in_room(capture_path: str, at: tuple[int, int], light: float = 0.4) -> Image.Image:
    """Pega el protagonista nuevo en una captura del juego (640×360), con el pie en `at`, oscurecido
    como la sala (`light`), y añade a la derecha una ampliación ×3 de la zona para compararlo con
    el sprite actual que lleva la captura."""
    cap = Image.open(capture_path).convert("RGBA").resize((640, 360), Image.NEAREST)
    spr = protagonist.frame("SW", protagonist.IDLE[0])
    arr = np.asarray(spr).astype(np.float32)
    arr[..., :3] *= light
    spr = Image.fromarray(arr.astype(np.uint8), "RGBA")
    ox, oy = protagonist.FRAME_ORIGIN
    cap.alpha_composite(spr, (at[0] - ox, at[1] - oy))
    crop = cap.crop((at[0] - 90, at[1] - 100, at[0] + 50, at[1] + 20))
    lift = np.asarray(crop).astype(np.float32)
    lift[..., :3] = np.clip(lift[..., :3] * 2.2, 0, 255)                # aclarado solo para verlo
    zoom = upscale(Image.fromarray(lift.astype(np.uint8), "RGBA"), 3)
    out = Image.new("RGBA", (640 + zoom.width + 12, max(360, zoom.height + 30)), (*BG, 255))
    out.alpha_composite(cap, (0, 0))
    out.alpha_composite(zoom, (652, 24))
    _label(out, "×3 y aclarado ×2,2: actual (izq.) · nuevo (dcha.)", (652, 4), 14)
    return out


def main() -> None:
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n"
    os.makedirs(out_dir, exist_ok=True)
    save = lambda im, name: im.save(os.path.join(out_dir, name))  # noqa: E731
    save(before_after(), "antes_despues.png")
    rows = [[protagonist.frame(d, g) for g in protagonist.IDLE + protagonist.WALK] for d in protagonist.DIRECTIONS]
    s8 = upscale(_on_bg(sheet(rows, gap=4)), 3)
    labels = ["S (abajo)", "SO", "O (izquierda)", "NO", "N (arriba)", "NE (espejo de NO)", "E (espejo de O)",
              "SE (espejo de SO)"]
    big = Image.new("RGBA", (s8.width + 200, s8.height + 40), (*BG, 255))
    big.alpha_composite(s8, (200, 40))
    _label(big, "reposo ×2  ·  paso ×4", (210, 8), 18)
    for i, t in enumerate(labels):
        _label(big, t, (10, 40 + i * 84 * 3 + 110), 18)
    save(big, "protagonista_8dir.png")
    save(upscale(_on_bg(sheet([protagonist_battle.frames()], gap=6)), 4), "protagonista_combate.png")
    f = enemy_nurse.frames()
    save(upscale(_on_bg(sheet([[f["idle_0"], f["idle_1"], f["attack"], f["stump"]]], gap=6), (10, 9, 12)), 2),
         "enfermero.png")
    save(enemy_nurse.parts_sheet(), "enfermero_piezas.png")
    esc = Image.new("RGBA", (44 * 2 + 32 * 3 + 40, 96), (*BG, 255))
    esc.alpha_composite(props2d.locker(False), (0, 2))
    esc.alpha_composite(props2d.locker(True), (48, 2))
    esc.alpha_composite(props2d.wall_strip(), (100, 0))
    for i in range(2):
        esc.alpha_composite(props2d.floor_tile(i + 1), (140 + i * 32, 0))
        esc.alpha_composite(props2d.floor_tile(i + 3), (140 + i * 32, 32))
    save(upscale(esc, 4), "escenario.png")
    save(battle_mockup(False), "maqueta_combate.png")
    save(battle_mockup(True), "maqueta_combate_ataque.png")
    # animación: las 8 direcciones andando a la vez (×3), y el enfermero respirando
    frames = []
    for i in range(4):
        row = [protagonist.frame(d, protagonist.WALK[i]) for d in protagonist.DIRECTIONS]
        frames.append(upscale(_on_bg(sheet([row], gap=4)), 3).convert("P", palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(out_dir, "paso_8dir.gif"), save_all=True, append_images=frames[1:],
                   duration=170, loop=0, disposal=2)
    nf = [upscale(_on_bg(f[k], (10, 9, 12)), 2).convert("P", palette=Image.ADAPTIVE) for k in ("idle_0", "idle_1")]
    nf[0].save(os.path.join(out_dir, "enfermero_reposo.gif"), save_all=True, append_images=nf[1:], duration=600, loop=0)
    if len(sys.argv) > 2:
        x, y = (int(v) for v in sys.argv[3].split(",")) if len(sys.argv) > 3 else (352, 204)
        save(in_room(sys.argv[2], (x, y)), "en_sala.png")


if __name__ == "__main__":
    main()
