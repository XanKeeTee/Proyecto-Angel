"""Texturas de luz para Godot (PointLight2D), con escalones y tramado de pixel art.

- light_round.png: halo suave con caída tipo inversa del cuadrado.
- flashlight_cone.png: linterna real, con punto caliente estrecho, halo exterior
  más ancho y débil, pequeñas imperfecciones del reflector y resplandor junto a la lente.
  El vértice está en el centro de la imagen y apunta a +X.
"""

from __future__ import annotations

import math

from PIL import Image

from pxrender import BAYER4, vnoise

STEPS = 12


def _shade(v: float, x: int, y: int) -> int:
    level = v * STEPS + ((BAYER4[y % 4][x % 4] + 0.5) / 16 - 0.5) * 0.9
    level = max(0.0, min(STEPS, math.floor(level + 0.5)))
    return int(255 * level / STEPS)


def round_light(size: int = 256) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = size / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c) / c
            if d >= 1:
                continue
            v = (1 / (1 + (d * 4.0) ** 2) - 1 / 17) / (1 - 1 / 17)
            v *= 1 - d ** 4
            g = _shade(max(0.0, v), x, y)
            if g:
                img.putpixel((x, y), (g, g, g, 255))
    return img


def flashlight_cone(size: int = 512) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = size / 2
    length = 250.0
    hot = math.radians(8.5)
    spill = math.radians(27.0)
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            d = math.hypot(dx, dy)
            v = 0.45 * max(0.0, 1 - d / 18.0) ** 2  # resplandor pegado a la lente
            if dx > 0 and d < length:
                ang = abs(math.atan2(dy, dx))
                dist = 1 / (1 + (d / 125.0) ** 2) * (1 - (d / length) ** 3)
                core = math.exp(-(ang / hot) ** 2 * 1.6)
                halo = 0.42 * max(0.0, 1 - (ang / spill) ** 2.2)
                ring = 0.08 * math.exp(-((ang - hot * 1.25) / (hot * 0.25)) ** 2)  # borde del reflector
                flaw = 0.92 + 0.16 * vnoise((ang * 40, d * 0.03, 0.0), 7)
                v = max(v, (core + halo + ring) * dist * flaw)
            g = _shade(min(v, 1.0), x, y)
            if g:
                img.putpixel((x, y), (g, g, g, 255))
    return img
