"""Pen: dibuja en una `Part` con coordenadas de diseño escaladas.

Todo personaje se diseña en una rejilla base (p. ej. el fotograma de 48×68 del mapa) y la
pluma la lleva a otro tamaño (×1,25, ×1,5) multiplicando las coordenadas. Así se puede probar
un fotograma mayor sin redibujar, y los detalles píxel a píxel (`px`) siguen cayendo en su sitio.
"""

from __future__ import annotations

import math
from typing import Sequence

from px2d import Part, Pt, limb


class Pen:
    def __init__(self, part: Part, s: float = 1.0, base_origin: Pt = (0.0, 0.0), origin: Pt = (0.0, 0.0),
                 flip_axis: float | None = None, dx: float = 0.0, dy: float = 0.0) -> None:
        """`base_origin` es un punto de la rejilla base que cae en `origin` del fotograma real.
        `flip_axis`: si se da, refleja la x de diseño respecto a esa vertical antes de escalar.
        `dx`, `dy`: desplazamiento en coordenadas de diseño (balanceo del paso, respiración)."""
        self.part, self.s = part, s
        self.bo, self.o = base_origin, origin
        self.flip = flip_axis
        self.dx, self.dy = dx, dy

    def m(self, p: Pt) -> Pt:
        x, y = p[0] + self.dx, p[1] + self.dy
        if self.flip is not None:
            x = 2 * self.flip - x
        return (self.o[0] + (x - self.bo[0]) * self.s, self.o[1] + (y - self.bo[1]) * self.s)

    def ms(self, pts: Sequence[Pt]) -> list[Pt]:
        return [self.m(p) for p in pts]

    def w(self, width: float) -> int:
        return max(1, int(round(width * self.s)))

    # --- envolturas ---
    def poly(self, pts, mat, tone=2, **kw):
        self.part.poly(self.ms(pts), mat, tone, **kw)
        return self

    def shade(self, pts, tone=None, delta=None, **kw):
        self.part.shade(self.ms(pts), tone, delta, **kw)
        return self

    def line(self, pts, mat, tone=None, width=1, **kw):
        self.part.line(self.ms(pts), mat, tone, self.w(width), **kw)
        return self

    def px(self, x, y, mat, tone=None, delta=None, inside=False):
        """Un píxel de detalle (en coordenadas de diseño; con escala >1 cae en el píxel más cercano)."""
        X, Y = self.m((x + 0.5, y + 0.5))
        self.part.dot(X, Y, mat, tone, delta, inside)
        return self

    def pxs(self, pts, mat, tone=None, delta=None, inside=False):
        for x, y in pts:
            self.px(x, y, mat, tone, delta, inside)
        return self

    def pixmap(self, rows: Sequence[str], anchor: Pt, legend: dict, hot: tuple[int, int] = (0, 0),
               flip: bool = False):
        """Pinta un dibujo píxel a píxel (lista de cadenas; '.' o ' ' = nada) a resolución final,
        sin escalar. `anchor` es un punto de diseño; `hot` es la celda del dibujo que cae en él.
        `legend` traduce cada carácter a (material, tono) o a None para borrar."""
        ax, ay = self.m(anchor)
        x0, y0 = int(math.floor(ax)) - hot[0], int(math.floor(ay)) - hot[1]
        for j, row in enumerate(rows):
            if flip:
                row = row[::-1]
            for i, ch in enumerate(row):
                if ch in ". ":
                    continue
                v = legend[ch]
                X, Y = x0 + i, y0 + j
                if not (0 <= X < self.part.w and 0 <= Y < self.part.h):
                    continue
                if v is None:
                    self.part.mat[Y, X] = -1
                else:
                    self.part.dot(X, Y, v[0], v[1])
        return self

    def limb(self, a: Pt, b: Pt, profile, mat, tone=2, **kw):
        pts = limb(a, b, profile)
        self.part.poly(self.ms(pts), mat, tone, **kw)
        return pts

    def erase(self, pts):
        self.part.erase(self.ms(pts))
        return self
