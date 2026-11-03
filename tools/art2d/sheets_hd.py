"""Hojas de la segunda muestra (vista interna de 1280×720).

    python3 -I tools/art2d/sheets_hd.py [carpeta_de_salida]

- `antes_despues.png`: arte 3D actual, primera muestra 2D y segunda, a la misma escala de pantalla
  (lo de 640×360 ampliado ×2, lo nuevo a ×1).
- `protagonista_8dir.png` y `paso_8dir.gif`: mapa, 8 direcciones, reposo y paso.
- `protagonista_combate.png`: de espaldas en guardia (4 fotogramas de respiración) y el golpe.
- `enfermero.png`, `enfermero_piezas.png`, `enfermero_reposo.gif`.
- `escenario.png`: taquilla cerrada y abierta, pared y suelo a la escala nueva.
- `maqueta_combate.png`, `maqueta_combate_ataque.png`, `maqueta_menu.png`: 1280×720 con el
  filtro de película del juego (`sheets.film_grade`).
"""

from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import enemy_nurse_hd as nurse  # noqa: E402
import props_hd  # noqa: E402
import protagonist_battle_hd as battle  # noqa: E402
import protagonist_hd as hero  # noqa: E402
import sheets as v1  # noqa: E402
import title_hd  # noqa: E402
from paint import on_bg, row, upscale  # noqa: E402

BG = (22, 21, 24)
INK = (190, 182, 165)
ORDER = ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
NAMES = {"S": "S (abajo)", "SW": "SO", "W": "O", "NW": "NO", "N": "N (arriba)", "NE": "NE", "E": "E", "SE": "SE"}


def _label(im, text, xy, size=18, fill=INK):
    ImageDraw.Draw(im).text(xy, text, font=title_hd._font(title_hd.SERIF, size), fill=fill)


def before_after() -> Image.Image:
    out = Image.new("RGBA", (1900, 1140), (*BG, 255))
    _label(out, "Misma escala de pantalla: lo de 640×360 ampliado ×2, lo de 1280×720 a ×1", (20, 8), 20)
    old = row([upscale(i, 2) for i in v1.old_protagonist()], gap=8, bg=BG)
    out.alpha_composite(old, (20, 50))
    _label(out, "Arte actual: volúmenes 3D rasterizados, 48×68, 16 orientaciones", (20, 50 + old.height + 4))
    s1 = row([upscale(v1.protagonist.frame(d, v1.protagonist.IDLE[0]), 2) for d in v1.protagonist.DIRECTIONS], gap=8, bg=BG)
    out.alpha_composite(s1, (20, 250))
    _label(out, "Muestra 1: 2D plano, 56×80", (20, 250 + s1.height + 4))
    s2 = row([hero.frame(d, hero.IDLE[0]) for d in ORDER], gap=8, bg=BG)
    out.alpha_composite(s2, (20, 480))
    _label(out, "Muestra 2: 2D pintado, 112×160 (vista de 1280×720), 8 direcciones", (20, 480 + s2.height + 4))
    # enfermero: actual (×2), muestra 1 (×2), muestra 2 (×1)
    on = upscale(v1.old_nurse().crop((60, 40, 220, 300)), 2)
    out.alpha_composite(on, (980, 40))
    _label(out, "Actual", (980, 40 + on.height - 6))
    n1 = upscale(v1.enemy_nurse.frames()["idle_0"].crop((20, 0, 180, 260)), 2)
    out.alpha_composite(n1, (1300, 40))
    _label(out, "Muestra 1", (1300, 40 + n1.height - 6))
    n2 = nurse.frames()["idle_0"].crop((40, 0, 360, 540))
    out.alpha_composite(n2, (1560, 560))
    _label(out, "Muestra 2", (1570, 1100))
    # combate de espaldas y escenario
    b1 = upscale(v1.protagonist_battle.frames()[0], 2)
    out.alpha_composite(b1, (20, 720))
    b2 = battle.frames()[0]
    out.alpha_composite(b2, (180, 720))
    _label(out, "Combate: muestra 1 (×2) · muestra 2 en guardia", (20, 966))
    out.alpha_composite(upscale(v1.old_locker(), 2), (520, 760))
    out.alpha_composite(upscale(v1.props2d.locker(False), 2), (620, 760))
    out.alpha_composite(props_hd.locker(False), (720, 760))
    _label(out, "Taquilla: actual · muestra 1 · muestra 2", (520, 966))
    return out


def map_sheet() -> Image.Image:
    frames = [[hero.frame(d, g) for g in hero.IDLE + hero.WALK] for d in ORDER]
    fw, fh = hero.W, hero.H
    out = Image.new("RGBA", (150 + 6 * (fw + 8), 40 + 8 * (fh + 6)), (*BG, 255))
    _label(out, "reposo ×2 · paso ×4 (112×160, a escala 1)", (150, 10))
    for j, d in enumerate(ORDER):
        _label(out, NAMES[d], (12, 40 + j * (fh + 6) + fh // 2 - 10))
        for i, f in enumerate(frames[j]):
            out.alpha_composite(f, (150 + i * (fw + 8), 40 + j * (fh + 6)))
    return out


def spotlight(w: int = 1280, h: int = 720) -> Image.Image:
    a = np.zeros((h, w, 3), np.float32)
    a[:] = (5, 4, 6)
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx - 640) / 460.0) ** 2 + ((yy - 500) / 130.0) ** 2)
    cone = np.clip(1.0 - np.abs(xx - 640) / (120 + (yy / h) * 440), 0, 1) * np.clip(yy / 520, 0, 1)
    lvl = np.clip(1.2 - d, 0, 1) * 0.8 + cone * 0.25
    bands = np.floor(lvl * 6 + ((xx + yy) % 2) * 0.5) / 6
    a += bands[..., None] * np.array([66, 60, 56], np.float32)
    return Image.fromarray(a.astype(np.uint8), "RGB").convert("RGBA")


def combat_mockup(attack: bool = False) -> Image.Image:
    can = spotlight()
    f = nurse.frames()["attack" if attack else "idle_0"]
    can.alpha_composite(f, (440, -6))
    can.alpha_composite(battle.frames()[2 if attack else 1], (350, 306))
    can = v1.film_grade(can)              # el filtro va a la escena; la interfaz encima, nítida
    left = title_hd.frame_box(250, 168, seed=5)
    right = title_hd.frame_box(1000, 168, seed=6)
    can.alpha_composite(left, (12, 540))
    can.alpha_composite(right, (268, 540))
    d = ImageDraw.Draw(can)
    f26 = title_hd._font(title_hd.SERIF, 26)
    f22 = title_hd._font(title_hd.SERIF, 22)
    bone = (214, 204, 182, 255)
    dim = (150, 142, 126, 255)
    for i, t in enumerate(("Atacar", "Habilidades", "Guardia", "Objeto")):
        y = 556 + i * 36
        if i == 0:
            d.rectangle((26, y - 2, 248, y + 32), fill=(52, 14, 16, 190))
            d.line([(32, y + 15), (38, y + 22), (50, y + 4)], fill=(176, 52, 40, 255), width=3)
        tw = d.textlength(t, font=f26)
        d.text((137 - tw / 2, y), t, font=f26, fill=bone if i == 0 else dim)
    d.rectangle((282, 554, 1254, 588), fill=(40, 34, 30, 170))
    d.text((300, 556), "Paciente 09", font=f26, fill=bone)
    for label, val, x, frac in (("Cuerpo", "82", 640, 1.0), ("Mente", "70", 960, 0.86)):
        d.text((x, 560), label, font=f22, fill=(120, 132, 158, 255))
        tw = d.textlength(val, font=f26)
        d.text((x + 230 - tw, 556), val, font=f26, fill=bone)
        d.rectangle((x, 590, x + 232, 594), fill=(30, 14, 14, 255))
        d.rectangle((x, 590, x + int(232 * frac), 594), fill=(132, 34, 30, 255))
    d.text((300, 612), "Tubo de hierro · manos: las dos", font=title_hd._font(title_hd.MONO, 16), fill=dim)
    if attack:
        top = title_hd.frame_box(800, 56, seed=7)
        can.alpha_composite(top, (240, 12))
        msg = "Levanta el brazo de bisturíes por encima de la máscara."
        tw = d.textlength(msg, font=f22)
        d.text((640 - tw / 2, 26), msg, font=f22, fill=bone)
    return can


def main() -> None:
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n"
    os.makedirs(out_dir, exist_ok=True)

    def save(im, name):
        if name.startswith("maqueta"):    # 256 colores: las maquetas con grano pesan menos
            im = im.convert("RGB").quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        im.save(os.path.join(out_dir, name), optimize=True)

    save(before_after(), "antes_despues.png")
    save(map_sheet(), "protagonista_8dir.png")
    frames = []
    for i in range(4):
        r = row([hero.frame(d, hero.WALK[i]) for d in ORDER], gap=8, bg=BG)
        frames.append(r.convert("P", palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(out_dir, "paso_8dir.gif"), save_all=True, append_images=frames[1:], duration=150,
                   loop=0)
    bf = battle.frames()
    sheet = row([upscale(f, 2) for f in bf], gap=12, bg=BG)
    _label(sheet, "guardia: respiración ×4 · golpe (×2)", (10, 6))
    save(sheet, "protagonista_combate.png")
    g = [upscale(on_bg(f, BG), 2).convert("P", palette=Image.ADAPTIVE) for f in bf[:4]]
    g[0].save(os.path.join(out_dir, "combate_guardia.gif"), save_all=True, append_images=g[1:] + g[2:3], duration=260,
              loop=0)
    nf = nurse.frames()
    save(row([nf["idle_0"], nf["idle_1"], nf["attack"], nf["stump"]], gap=10, bg=(12, 11, 14)), "enfermero.png")
    save(row(nurse.parts(), gap=6, bg=(12, 11, 14)), "enfermero_piezas.png")
    ng = [on_bg(nf[k], (12, 11, 14)).convert("P", palette=Image.ADAPTIVE) for k in ("idle_0", "idle_1")]
    ng[0].save(os.path.join(out_dir, "enfermero_reposo.gif"), save_all=True, append_images=ng[1:], duration=700, loop=0)
    esc = Image.new("RGBA", (88 * 2 + 64 * 3 + 40, 192), (*BG, 255))
    esc.alpha_composite(props_hd.locker(False), (0, 4))
    esc.alpha_composite(props_hd.locker(True), (96, 4))
    esc.alpha_composite(props_hd.wall_strip(), (200, 0))
    for i in range(2):
        esc.alpha_composite(props_hd.floor_tile(i + 1), (276 + i * 64, 0))
        esc.alpha_composite(props_hd.floor_tile(i + 3), (276 + i * 64, 64))
    save(upscale(esc, 2), "escenario.png")
    save(combat_mockup(False), "maqueta_combate.png")
    save(combat_mockup(True), "maqueta_combate_ataque.png")
    save(title_hd.title_mockup(grade=v1.film_grade), "maqueta_menu.png")


if __name__ == "__main__":
    main()
