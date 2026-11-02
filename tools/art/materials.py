"""Rampas y materiales con desgaste para los objetos del mapa (pxrender).

Un material es una función (p, n) -> (rampa, brillo[, normal[, especular]]).
Aquí están los que se repiten: pintura esmaltada con desconchones y óxido, acero cepillado,
cromo, cristal, formica, vinilo de tapicería y galvanizado de sótano. La mugre se acumula
abajo (cerca del suelo) y en las aristas, como en la guía estética.
"""

from __future__ import annotations

import math

from pxrender import Vec, add, fbm, mul, norm, ramp

# Hueso sucio: mobiliario de hospital esmaltado.
ramp("enamel", [(30, 30, 32), (52, 52, 52), (80, 78, 72), (110, 106, 96), (140, 134, 120), (168, 162, 144), (194, 188, 168)])
# Verde clínico apagado: carros, armarios, biombos.
ramp("enamel_green", [(18, 28, 26), (30, 44, 40), (46, 62, 56), (64, 82, 74), (86, 104, 92), (110, 126, 110)])
ramp("chrome", [(14, 16, 20), (30, 34, 38), (54, 58, 62), (88, 92, 94), (130, 134, 132), (178, 180, 174), (220, 220, 210)])
ramp("formica", [(36, 32, 28), (58, 52, 44), (84, 76, 62), (110, 100, 82), (136, 124, 102)])
ramp("vinyl", [(12, 18, 20), (20, 30, 32), (30, 44, 46), (44, 60, 60), (62, 78, 76)])
ramp("galv", [(22, 24, 24), (38, 40, 40), (58, 60, 58), (82, 84, 80), (108, 110, 104), (136, 136, 128)])
ramp("machine", [(12, 20, 18), (20, 32, 28), (30, 46, 40), (44, 62, 52), (60, 80, 66), (80, 100, 82)])
ramp("oxblood", [(26, 8, 10), (44, 14, 16), (66, 24, 24), (90, 36, 34), (114, 52, 46)])
ramp("pane", [(8, 12, 16), (16, 22, 28), (30, 40, 46), (60, 74, 78), (110, 124, 124), (180, 190, 186)])
ramp("porcelain", [(46, 48, 48), (72, 74, 72), (100, 102, 98), (130, 132, 126), (160, 160, 152), (188, 186, 176)])
ramp("linen", [(48, 50, 50), (72, 74, 72), (98, 100, 96), (124, 126, 120), (150, 150, 142), (174, 172, 162)])
ramp("felt", [(14, 16, 22), (22, 26, 34), (34, 38, 48), (48, 54, 64)])
ramp("dark", [(6, 6, 8), (12, 12, 14), (20, 20, 24), (30, 30, 34)])
ramp("wood_old", [(22, 14, 10), (36, 24, 16), (54, 36, 24), (72, 50, 34), (92, 66, 46), (110, 82, 58)])
ramp("water_dark", [(4, 6, 8), (8, 12, 14), (14, 20, 22), (30, 40, 42)])
ramp("label_w", [(70, 66, 58), (104, 98, 86), (138, 132, 116), (168, 162, 144)])
ramp("brass_d", [(46, 34, 14), (80, 62, 26), (120, 96, 44), (160, 132, 70)])
ramp("tape", [(14, 10, 8), (28, 20, 14), (46, 34, 22), (66, 50, 32)])
ramp("cable", [(6, 6, 8), (14, 14, 16), (24, 24, 28), (38, 38, 42)])
ramp("hair", [(10, 8, 8), (20, 16, 14), (32, 26, 22)])
ramp("pill", [(90, 86, 76), (130, 126, 112), (170, 166, 150), (204, 200, 184)])
ramp("ext_red", [(34, 8, 8), (64, 16, 14), (98, 28, 24), (132, 46, 38), (160, 70, 56)])
ramp("trash_bag", [(6, 6, 8), (12, 12, 14), (20, 20, 24), (32, 32, 36), (52, 52, 58)])
ramp("ink_d", [(18, 18, 22), (32, 32, 40), (50, 50, 60)])
ramp("hazard", [(60, 50, 10), (110, 92, 20), (156, 134, 40), (190, 170, 70)])


def _bump(p: Vec, n: Vec, seed: int, amount: float, scale: float = 0.35) -> Vec:
    if amount <= 0:
        return n
    d = fbm(mul(p, scale), seed) - 0.5
    e = fbm(mul(p, scale), seed + 7) - 0.5
    return norm(add(n, (d * amount, e * amount * 0.6, 0.0)))


def painted(name: str, seed: int = 1, rust: float = 0.74, chips: float = 0.82, grime_h: float = 6.0,
            dent: float = 0.35, spec: float = 0.0, bright: float = 1.0):
    """Metal pintado: desconchones con metal a la vista, óxido en manchas y mugre abajo."""

    def f(p: Vec, n: Vec) -> tuple:
        n2 = _bump(p, n, seed, dent)
        b = bright * (0.9 + 0.18 * fbm(mul(p, 0.6), seed + 3))
        if p[1] < grime_h:
            b *= 0.7 + 0.3 * (p[1] / grime_h)
        r = fbm(mul((p[0], p[1] * 0.5, p[2]), 0.42), seed + 5)
        if r > rust + (0.06 if p[1] > grime_h * 2 else -0.04):
            return ("rust", 0.85 + 0.2 * fbm(mul(p, 1.3), seed + 6), n2)
        if fbm(mul(p, 1.6), seed + 9) > chips:
            return ("metal", 0.95, n2, 0.6)
        return (name, b, n2, spec)

    return f


def steel(seed: int = 2, bright: float = 1.0, spec: float = 0.9, name: str = "chrome", grime_h: float = 4.0):
    """Acero o cromo con brillo, vetas de cepillado y manchas de agua."""

    def f(p: Vec, n: Vec) -> tuple:
        streak = 0.08 * math.sin(p[0] * 2.3 + 6 * fbm(mul(p, 0.15), seed))
        b = bright * (0.92 + streak + 0.1 * fbm(mul(p, 0.5), seed + 1))
        if p[1] < grime_h:
            b *= 0.75
        if fbm(mul(p, 0.3), seed + 2) > 0.72:
            return ("metal", b * 0.85, None, spec * 0.4)
        return (name, b, None, spec)

    return f


def glass(seed: int = 3, bright: float = 1.0):
    def f(p: Vec, n: Vec) -> tuple:
        dirt = fbm(mul(p, 0.4), seed)
        if dirt > 0.66:
            return ("stain", 0.5 * bright, None, 0.4)
        return ("pane", (0.55 + 0.2 * dirt) * bright, None, 1.4)

    return f


def flat(name: str, bright: float = 1.0, spec: float = 0.0):
    return lambda p, n: (name, bright, None, spec)


def noisy(name: str, seed: int = 4, amount: float = 0.2, bright: float = 1.0):
    return lambda p, n: (name, bright * (1 - amount / 2 + amount * fbm(mul(p, 0.7), seed)))


def fabric(name: str, seed: int = 5, folds: float = 0.35, stain: float = 0.72, bright: float = 1.0, dirty_h: float = 8.0):
    """Tela con pliegues (normales onduladas), manchas y el bajo sucio."""

    def f(p: Vec, n: Vec) -> tuple:
        wave = math.sin(p[0] * 0.8 + 4 * fbm(mul(p, 0.09), seed))
        n2 = norm(add(n, (wave * folds, 0.0, math.cos(p[1] * 0.6) * folds * 0.4)))
        b = bright * (0.9 + 0.12 * wave)
        if p[1] < dirty_h:
            b *= 0.78
            if fbm(mul(p, 0.4), seed + 2) > 0.55:
                return ("stain", b, n2)
        if fbm(mul(p, 0.16), seed + 1) > stain:
            return ("stain", b, n2)
        return (name, b, n2)

    return f


def wood(seed: int = 6, bright: float = 1.0, name: str = "wood_old"):
    def f(p: Vec, n: Vec) -> tuple:
        grain = math.sin(p[0] * 0.9 + p[2] * 0.2 + 3 * fbm(mul(p, 0.2), seed)) * 0.5 + 0.5
        if fbm(mul(p, 0.5), seed + 1) > 0.76:
            return ("stain", 0.7 * bright)
        return (name, bright * (0.72 + 0.36 * grain))

    return f


def cardboard(seed: int = 7, bright: float = 1.0):
    def f(p: Vec, n: Vec) -> tuple:
        if p[1] < 3 and fbm(mul(p, 0.5), seed) > 0.45:
            return ("stain", 0.7 * bright)  # base mojada
        if fbm(mul(p, 0.3), seed + 1) > 0.74:
            return ("stain", 0.85 * bright)
        return ("cardboard", bright * (0.85 + 0.2 * fbm(mul(p, 0.8), seed + 2)))

    return f
