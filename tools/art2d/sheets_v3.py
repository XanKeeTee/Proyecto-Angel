"""Hojas de la tercera muestra (método `vec`: dibujo suave a ×4-×6, reducción, paleta y contorno).

    python3 -I tools/art2d/sheets_v3.py [carpeta_de_salida]      (tarda unos 10 minutos)

- `protagonista_combate.png` · `combate_guardia.gif` · `combate_golpe.gif`: guardia ×4 y golpe ×3
  (carga, impacto, retroceso), con las siluetas en negro debajo.
- `enfermero.png` · `enfermero_piezas.png` · `enfermero_reposo.gif`: reposo ×2, Tajo, muñón; piezas.
- `protagonista_mapa_abajo.png` · `paso_abajo.gif`: mapa mirando abajo, reposo y paso ×4.
- `maqueta_combate.png` · `maqueta_combate_ataque.png`: 1280×720 con el filtro de película.
- `antes_despues.png`: segunda muestra frente a la tercera.
"""

from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import enemy_nurse_hd as nurse2  # noqa: E402
import hero_battle_v3 as hb  # noqa: E402
import hero_map_v3 as hm  # noqa: E402
import nurse_v3 as nv  # noqa: E402
import palette_v3 as pal  # noqa: E402
import protagonist_battle_hd as battle2  # noqa: E402
import protagonist_hd as hero2  # noqa: E402
import sheets as v1  # noqa: E402
import sheets_hd as s2  # noqa: E402
import title_hd  # noqa: E402
from paint import on_bg, row, upscale  # noqa: E402

BG = (22, 21, 24)


def _label(im, text, xy, size=18):
    ImageDraw.Draw(im).text(xy, text, font=title_hd._font(title_hd.SERIF, size), fill=(190, 182, 165))


def _gif(frames, path, ms, bg=BG, k=2):
    pf = [upscale(on_bg(f, bg), k).convert("P", palette=Image.ADAPTIVE) for f in frames]
    pf[0].save(path, save_all=True, append_images=pf[1:], duration=ms, loop=0)


def main() -> None:
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n"
    os.makedirs(out, exist_ok=True)

    def save(im, name):
        if name.startswith("maqueta"):
            im = im.convert("RGB").quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        im.save(os.path.join(out, name), optimize=True)

    # --- protagonista en combate ---
    names = ["guard_0", "guard_1", "guard_2", "guard_3", "windup", "impact", "recoil"]
    figs = [hb.draw(hb.POSES[n]()) for n in names]
    hero_frames = [f.render(pal.HERO, dither=9.0) for f in figs]
    sils = [f.silhouette() for f in figs]
    top = row(hero_frames, gap=10, bg=BG)
    bot = row(sils, gap=10, bg=BG)
    sheet = Image.new("RGBA", (top.width, top.height + bot.height + 40), (*BG, 255))
    sheet.alpha_composite(top, (0, 30))
    sheet.alpha_composite(bot, (0, top.height + 40))
    _label(sheet, "guardia: respiración ×4   ·   golpe: carga, impacto, retroceso   (escala 1; debajo, la silueta)", (8, 4))
    save(upscale(sheet, 2), "protagonista_combate.png")
    _gif(hero_frames[:4] + hero_frames[2:3], os.path.join(out, "combate_guardia.gif"), 260)
    _gif([hero_frames[0], hero_frames[4], hero_frames[5], hero_frames[6], hero_frames[0]],
         os.path.join(out, "combate_golpe.gif"), 220)
    # --- enfermero ---
    nf = nv.frames()
    save(row([nf["idle_0"], nf["idle_1"], nf["attack"], nf["stump"]], gap=10, bg=(12, 11, 14)), "enfermero.png")
    save(row(nv.parts(), gap=6, bg=(12, 11, 14)), "enfermero_piezas.png")
    _gif([nf["idle_0"], nf["idle_1"]], os.path.join(out, "enfermero_reposo.gif"), 700, bg=(12, 11, 14), k=1)
    # --- mapa, mirando abajo ---
    mf = hm.frames()
    msil = hm.draw(hm.IDLE).silhouette()
    save(upscale(row(mf + [msil], gap=8, bg=BG), 3), "protagonista_mapa_abajo.png")
    _gif(mf[1:], os.path.join(out, "paso_abajo.gif"), 160, k=3)
    # --- maquetas de combate ---
    for attack, name in ((False, "maqueta_combate.png"), (True, "maqueta_combate_ataque.png")):
        can = s2.spotlight()
        can.alpha_composite(nf["attack" if attack else "idle_0"], (440, -6))
        can.alpha_composite(hero_frames[4 if attack else 1], (300, 300))
        can = v1.film_grade(can)
        save(_ui(can, attack), name)
    # --- antes / después ---
    ba = Image.new("RGBA", (1700, 640), (*BG, 255))
    _label(ba, "Segunda muestra (izquierda) · tercera muestra (derecha), a escala 1", (12, 6), 20)
    ba.alpha_composite(battle2.frames()[0], (12, 60))
    ba.alpha_composite(hero_frames[0], (190, 40))
    ba.alpha_composite(nurse2.frames()["idle_0"], (420, 60))
    ba.alpha_composite(nf["idle_0"], (830, 60))
    ba.alpha_composite(hero2.frame("S", hero2.IDLE[0]), (1260, 120))
    ba.alpha_composite(mf[0], (1400, 120))
    save(ba, "antes_despues.png")


def _ui(can: Image.Image, attack: bool) -> Image.Image:
    left = title_hd.frame_box(250, 168, seed=5)
    right = title_hd.frame_box(1000, 168, seed=6)
    can.alpha_composite(left, (12, 540))
    can.alpha_composite(right, (268, 540))
    d = ImageDraw.Draw(can)
    f26 = title_hd._font(title_hd.SERIF, 26)
    f22 = title_hd._font(title_hd.SERIF, 22)
    bone, dim = (214, 204, 182, 255), (150, 142, 126, 255)
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


if __name__ == "__main__":
    main()
