"""Hojas de la quinta muestra (tinta y pinceladas, buscando Fear & Hunger).

    python3 -I tools/art2d/sheets_fh.py [carpeta_de_salida] [imagen_de_referencia]
"""

from __future__ import annotations

import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import hero_fh  # noqa: E402
import nurse_fh  # noqa: E402
import palette_fh as pal  # noqa: E402
import sheets as v1  # noqa: E402
import sheets_hd as s2  # noqa: E402
import sheets_v3 as s3  # noqa: E402
from sheets_ink import _pair  # noqa: E402

REF = "/tmp/claude-0/-home-user-Proyecto-Angel/78bbf7aa-014d-5166-9823-72d17a78b072/images/1.png"


def main() -> None:
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n"
    ref = sys.argv[2] if len(sys.argv) > 2 else REF
    os.makedirs(out, exist_ok=True)
    nurse = nurse_fh.frame()
    hero = hero_fh.combat().render(pal.HERO)
    hmap = hero_fh.map_down().render(pal.HERO)
    _pair(nurse, 2, "Enfermero · tinta y pinceladas · 300×440 · escala 1 y ×2").save(os.path.join(out, "estilo_fh_enfermero.png"), optimize=True)
    _pair(hero, 2, "Protagonista en guardia · 260×420 · escala 1 y ×2").save(os.path.join(out, "estilo_fh_protagonista_combate.png"),
                                                                              optimize=True)
    _pair(hmap, 4, "Protagonista en el mapa · 112×160 · escala 1 y ×4").save(os.path.join(out, "estilo_fh_protagonista_mapa.png"),
                                                                              optimize=True)
    can = s2.spotlight()
    can.alpha_composite(nurse, (500, 86))
    can.alpha_composite(hero, (250, 270))
    can = s3._ui(v1.film_grade(can), False)
    can.convert("RGB").quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(
        os.path.join(out, "maqueta_combate_fh.png"), optimize=True)
    if os.path.exists(ref):
        r = Image.open(ref).convert("RGBA")
        enemy = r.crop((230, 0, 520, 300))                          # el enemigo de la referencia, a escala 1
        party = r.crop((90, 240, 200, 400))
        sheet = Image.new("RGBA", (enemy.width * 2 + nurse.width * 2 + 60, max(enemy.height, nurse.height) * 2 + 60), (20, 19, 22, 255))
        from paint import upscale
        sheet.alpha_composite(upscale(enemy, 2), (12, 40))
        sheet.alpha_composite(upscale(nurse, 2), (enemy.width * 2 + 40, 40))
        sheet.alpha_composite(upscale(party, 2), (12, 40 + enemy.height * 2 + 10)) if 40 + enemy.height * 2 + 10 + party.height * 2 <= sheet.height else None
        s3._label(sheet, "Referencia (Fear & Hunger, escala ×2)", (12, 8))
        s3._label(sheet, "Enfermero de la muestra (×2)", (enemy.width * 2 + 40, 8))
        sheet.save(os.path.join(out, "comparacion_referencia.png"), optimize=True)


if __name__ == "__main__":
    main()
