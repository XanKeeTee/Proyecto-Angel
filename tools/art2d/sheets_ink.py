"""Hojas de la cuarta muestra: prueba de estilo a tinta y color plano (estática).

    python3 -I tools/art2d/sheets_ink.py [carpeta_de_salida]

- `estilo_tinta_enfermero.png`, `estilo_tinta_protagonista_combate.png`, `estilo_tinta_protagonista_mapa.png`:
  cada figura a escala 1 y ampliada.
- `maqueta_combate_tinta.png`: 1280×720 con el filtro de película.
"""

from __future__ import annotations

import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import hero_ink  # noqa: E402
import nurse_ink  # noqa: E402
import sheets as v1  # noqa: E402
import sheets_hd as s2  # noqa: E402
import sheets_v3 as s3  # noqa: E402
from paint import row, upscale  # noqa: E402

BG = (20, 19, 22)


def _pair(im: Image.Image, k: int, label: str) -> Image.Image:
    r = row([im, upscale(im, k)], gap=24, bg=BG)
    out = Image.new("RGBA", (r.width + 24, r.height + 44), (*BG, 255))
    out.alpha_composite(r, (12, 34))
    s3._label(out, label, (12, 8))
    return out


def main() -> None:
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots/n"
    os.makedirs(out, exist_ok=True)
    nurse = nurse_ink.frame()
    hero = hero_ink.combat().render()
    hmap = hero_ink.map_down().render()
    _pair(nurse, 2, "Enfermero a tinta · 300×440 · escala 1 y ×2").save(os.path.join(out, "estilo_tinta_enfermero.png"), optimize=True)
    _pair(hero, 2, "Protagonista en combate a tinta · 260×420 · escala 1 y ×2").save(
        os.path.join(out, "estilo_tinta_protagonista_combate.png"), optimize=True)
    _pair(hmap, 4, "Protagonista en el mapa a tinta · 112×160 · escala 1 y ×4").save(
        os.path.join(out, "estilo_tinta_protagonista_mapa.png"), optimize=True)
    can = s2.spotlight()
    can.alpha_composite(nurse, (500, 86))
    can.alpha_composite(hero, (250, 270))
    can = v1.film_grade(can)
    can = s3._ui(can, False)
    can.convert("RGB").quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(
        os.path.join(out, "maqueta_combate_tinta.png"), optimize=True)


if __name__ == "__main__":
    main()
