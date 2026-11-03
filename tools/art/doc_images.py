"""Imágenes de documentos: fotografía del personal y plano de evacuación (desde hospital_layout.json)."""

from __future__ import annotations

import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/documents"


def _font(size: int) -> ImageFont.ImageFont:
    for name in ("cour.ttf", "consola.ttf", "DejaVuSansMono.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def photo() -> Image.Image:
    rng = random.Random(14)
    w, h = 180, 110
    img = Image.new("RGB", (w, h), (70, 58, 44))
    d = ImageDraw.Draw(img)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=(78 - y // 6, 64 - y // 7, 48 - y // 8))
    d.rectangle([0, 0, w, 38], fill=(52, 44, 36))  # fachada
    for x in range(10, w, 22):
        d.rectangle([x, 8, x + 10, 26], fill=(30, 26, 22))
    people = []
    for row, (y0, scale) in enumerate(((62, 1.0), (74, 1.08))):
        for i in range(7):
            x = 16 + i * 23 + (11 if row else 0)
            people.append((x, y0, scale))
    for idx, (x, y0, s) in enumerate(people):
        d.ellipse([x - 5 * s, y0 - 12 * s, x + 5 * s, y0 - 2 * s], fill=(150, 132, 108))
        d.rectangle([x - 8 * s, y0 - 2 * s, x + 8 * s, y0 + 26 * s], fill=(196, 184, 160))
        if idx == 9:  # la cara rayada
            for k in range(14):
                d.line([(x - 6 + rng.uniform(-2, 2), y0 - 13 + k), (x + 6 + rng.uniform(-2, 2), y0 - 13 + k + rng.uniform(-3, 3))],
                       fill=(240, 232, 214), width=1)
    for _ in range(1500):
        x, y = rng.randrange(w), rng.randrange(h)
        v = rng.randint(-25, 25)
        r, g, b = img.getpixel((x, y))
        img.putpixel((x, y), (max(0, min(255, r + v)), max(0, min(255, g + v)), max(0, min(255, b + v))))
    border = Image.new("RGB", (w + 12, h + 12), (214, 206, 186))
    border.paste(img, (6, 6))
    return border


def plan() -> Image.Image:
    layout = json.loads((ROOT / "tools/levels/hospital_layout.json").read_text(encoding="utf-8"))
    s = 5
    rooms = [r for r in layout["rooms"] if r.get("map")]
    w, h = 74 * s + 20, 30 * s + 30
    img = Image.new("RGB", (w, h), (206, 198, 178))
    d = ImageDraw.Draw(img)
    font = _font(8)
    for r in rooms:
        x, y, rw, rh = r["rect"]
        box = [10 + x * s, 14 + y * s, 10 + (x + rw) * s, 14 + (y + rh) * s]
        d.rectangle(box, outline=(60, 54, 46), width=1, fill=(226, 220, 202) if r["id"] != "pasillo" else (214, 208, 190))
        label = r["name"].replace("Habitación ", "").replace("Pasillo del ala de pacientes", "Pasillo")
        if r["id"] not in ("escalera", "almacen", "banos"):
            d.text((box[0] + 2, box[1] + 2), label[:14], fill=(60, 54, 46), font=font)
    # Fachada oeste: el pasillo termina en el muro.
    d.line([(10 + 1 * s - 2, 14 + 13 * s), (10 + 1 * s - 2, 14 + 18 * s)], fill=(20, 18, 16), width=3)
    d.text((12, h - 14), "PLANTA 3 · PLANO DE EVACUACIÓN · USTED ESTÁ AQUÍ ↓", fill=(120, 20, 20), font=font)
    d.polygon([(10 + 62 * s, 14 + 24 * s), (10 + 64 * s, 14 + 24 * s), (10 + 63 * s, 14 + 26 * s)], fill=(160, 20, 20))
    return img


def build() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    photo().save(OUT / "foto_personal.png")
    plan().save(OUT / "plano_hospital.png")
    print("  ", "assets/documents/ foto_personal.png, plano_hospital.png")


if __name__ == "__main__":
    build()
