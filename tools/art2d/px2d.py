"""px2d: pequeña librería de dibujo 2D para pixel art pintado «a mano» con código.

Nada de volúmenes 3D ni de trazado de rayos. Todo se define en el plano:

- **Pieza** (`Part`): una capa del tamaño del fotograma con dos mapas por píxel, el *material*
  (qué rampa de color usa) y el *tono* (qué escalón de la rampa). Se rellena con polígonos
  trazados punto a punto, líneas y píxeles sueltos.
- **Rampas**: pocas tonalidades por material (3-5), de la más oscura a la más clara.
- **Luz y sombra** como formas planas: polígonos de tono, bandas de borde que siguen la silueta
  (`rim`, la sombra del lado contrario a la luz) y tramado a mano (`pattern`) en las transiciones.
- **Contorno selectivo**: cada pieza se rodea de 1 px del tono más oscuro de su material
  mezclado con tinta (`INK`); en el lado iluminado el contorno se aclara o desaparece.
- **Rig 2D** (`limb`, `Pose`): las extremidades se trazan como perfiles angulosos entre dos
  articulaciones, con anchura distinta a cada lado (pantorrilla, rodilla, codo). Las piezas
  recortadas (*cutout*) se pueden girar con `rotsprite`.

Convención de coordenadas: x hacia la derecha, y hacia abajo, en píxeles del fotograma.
La luz viene de arriba y algo de la izquierda (`LIGHT = (-1, -1)`).
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Iterable, Sequence

import numpy as np
from PIL import Image, ImageDraw

RGB = tuple[int, int, int]
Pt = tuple[float, float]

INK: RGB = (14, 10, 18)
LIGHT: tuple[int, int] = (-1, -1)

# --- rampas ----------------------------------------------------------------------------------

_RAMPS: dict[str, list[RGB]] = {}


def hexrgb(h: str) -> RGB:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def ramp(name: str, colors: Sequence[str | RGB]) -> None:
    """Registra una rampa (de oscuro a claro). Acepta '#rrggbb' o tuplas."""
    _RAMPS[name] = [hexrgb(c) if isinstance(c, str) else tuple(c) for c in colors]


def ramp_colors(name: str) -> list[RGB]:
    return _RAMPS[name]


def mix(a: RGB, b: RGB, t: float) -> RGB:
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


# --- patrones de tramado -----------------------------------------------------------------------

def pattern_mask(name: str | None, h: int, w: int, phase: int = 0) -> np.ndarray:
    """Máscara de tramado alineada a la rejilla del fotograma.

    - None: todo.
    - 'checker': damero (50 %).
    - 'sparse': un píxel de cada cuatro (25 %).
    - 'dense': tres de cada cuatro (75 %).
    - 'hlines'/'vlines': rayado de líneas alternas.
    - 'diag': diagonal de 1 de cada 3.
    """
    yy, xx = np.mgrid[0:h, 0:w]
    xx = xx + phase
    if name is None:
        return np.ones((h, w), bool)
    if name == "checker":
        return (xx + yy) % 2 == 0
    if name == "sparse":
        return (xx % 2 == 0) & (yy % 2 == 0) & (((xx // 2) + (yy // 2)) % 2 == 0) | ((xx % 2 == 1) & (yy % 2 == 1) & (((xx // 2) + (yy // 2)) % 2 == 1))
    if name == "dense":
        return ~((xx % 2 == 0) & (yy % 2 == 0))
    if name == "hlines":
        return yy % 2 == 0
    if name == "vlines":
        return xx % 2 == 0
    if name == "diag":
        return (xx + yy) % 3 == 0
    raise ValueError(name)


# --- geometría 2D ------------------------------------------------------------------------------

def lerp(a: Pt, b: Pt, t: float) -> Pt:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def limb(a: Pt, b: Pt, profile: Sequence[tuple[float, float, float]]) -> list[Pt]:
    """Polígono anguloso de una extremidad entre las articulaciones `a` y `b`.

    `profile` es una lista de (t, ancho_izq, ancho_der): a lo largo del hueso (t de 0 a 1),
    cuánto sale la silueta a la izquierda y a la derecha de la dirección a→b. Con anchos
    distintos a cada lado se dibuja la pantorrilla, la rodilla huesuda o el codo.
    """
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy) or 1.0
    ux, uy = dx / ln, dy / ln
    # Normal a la izquierda de la dirección (en pantalla, con y hacia abajo).
    nx, ny = uy, -ux
    left: list[Pt] = []
    right: list[Pt] = []
    for t, wl, wr in profile:
        cx, cy = a[0] + dx * t, a[1] + dy * t
        left.append((cx + nx * wl, cy + ny * wl))
        right.append((cx - nx * wr, cy - ny * wr))
    return left + right[::-1]


def offset(pts: Iterable[Pt], ox: float, oy: float) -> list[Pt]:
    return [(x + ox, y + oy) for x, y in pts]


def mirror_x(pts: Iterable[Pt], axis: float) -> list[Pt]:
    """Refleja puntos respecto a la vertical x = axis (el centro del píxel cuenta)."""
    return [(2 * axis - x, y) for x, y in pts]


def scale_pts(pts: Iterable[Pt], s: float, ox: float = 0.0, oy: float = 0.0) -> list[Pt]:
    return [(ox + x * s, oy + y * s) for x, y in pts]


def rotate_pts(pts: Iterable[Pt], deg: float, pivot: Pt) -> list[Pt]:
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    out = []
    for x, y in pts:
        dx, dy = x - pivot[0], y - pivot[1]
        out.append((pivot[0] + dx * c - dy * s, pivot[1] + dx * s + dy * c))
    return out


# --- pieza -------------------------------------------------------------------------------------

class Part:
    """Una pieza dibujable: material y tono por píxel. Se compone con otras con `compose`."""

    def __init__(self, w: int, h: int, name: str = "") -> None:
        self.w, self.h, self.name = w, h, name
        self.mat = np.full((h, w), -1, np.int16)
        self.tone = np.zeros((h, w), np.int8)
        self.names: list[str] = []
        # Píxeles que no reciben contorno a su alrededor (p. ej. un tubo que entra en la carne).
        self.no_outline = np.zeros((h, w), bool)
        # Píxeles marcados como «brillo propio» (capa emisiva opcional).
        self.glow = np.zeros((h, w), bool)

    # ---- utilidades internas ----
    def _mid(self, name: str) -> int:
        if name not in _RAMPS:
            raise KeyError(f"rampa desconocida: {name}")
        if name not in self.names:
            self.names.append(name)
        return self.names.index(name)

    def _poly_mask(self, pts: Sequence[Pt]) -> np.ndarray:
        img = Image.new("L", (self.w, self.h), 0)
        d = ImageDraw.Draw(img)
        p = [(int(math.floor(x + 1e-6)), int(math.floor(y + 1e-6))) for x, y in pts]
        if len(p) >= 3:
            d.polygon(p, fill=1, outline=1)
        elif len(p) == 2:
            d.line(p, fill=1)
        else:
            d.point(p, fill=1)
        return np.array(img, bool)

    def _line_mask(self, pts: Sequence[Pt], width: int = 1) -> np.ndarray:
        img = Image.new("L", (self.w, self.h), 0)
        d = ImageDraw.Draw(img)
        p = [(int(math.floor(x + 1e-6)), int(math.floor(y + 1e-6))) for x, y in pts]
        d.line(p, fill=1, width=width)
        return np.array(img, bool)

    def _clip(self, m: np.ndarray, clip: str | Sequence[str] | None, inside: bool) -> np.ndarray:
        if inside:
            m = m & (self.mat >= 0)
        if clip is not None:
            names = [clip] if isinstance(clip, str) else list(clip)
            ids = [self.names.index(n) for n in names if n in self.names]
            m = m & np.isin(self.mat, ids)
        return m

    def _apply(self, m: np.ndarray, mat: str | None, tone: int | None, delta: int | None,
               pattern: str | None, phase: int = 0) -> None:
        if pattern is not None:
            m = m & pattern_mask(pattern, self.h, self.w, phase)
        if mat is not None:
            self.mat[m] = self._mid(mat)
        if tone is not None:
            self.tone[m] = tone
        if delta is not None:
            self.tone[m] = self.tone[m] + delta
        self._clamp()

    def _clamp(self) -> None:
        for i, n in enumerate(self.names):
            sel = self.mat == i
            self.tone[sel] = np.clip(self.tone[sel], 0, len(_RAMPS[n]) - 1)

    @property
    def mask(self) -> np.ndarray:
        return self.mat >= 0

    # ---- dibujo ----
    def poly(self, pts: Sequence[Pt], mat: str, tone: int = 2, clip=None, pattern: str | None = None,
             inside: bool = False) -> "Part":
        """Rellena un polígono con un material y tono."""
        m = self._clip(self._poly_mask(pts), clip, inside)
        self._apply(m, mat, tone, None, pattern)
        return self

    def shade(self, pts: Sequence[Pt], tone: int | None = None, delta: int | None = None, clip=None,
              pattern: str | None = None, mat: str | None = None) -> "Part":
        """Pinta una zona de luz o sombra (forma plana) solo sobre lo ya dibujado."""
        m = self._clip(self._poly_mask(pts), clip, True)
        self._apply(m, mat, tone, delta, pattern)
        return self

    def line(self, pts: Sequence[Pt], mat: str | None, tone: int | None = None, width: int = 1,
             clip=None, inside: bool = False, delta: int | None = None, pattern: str | None = None) -> "Part":
        """Línea (pliegue, costura, cable). Con `inside=True` no se sale de lo dibujado."""
        m = self._clip(self._line_mask(pts, width), clip, inside)
        self._apply(m, mat, tone, delta, pattern)
        return self

    def dot(self, x: float, y: float, mat: str | None, tone: int | None = None, delta: int | None = None,
            inside: bool = False) -> "Part":
        """Un píxel a mano."""
        xi, yi = int(math.floor(x)), int(math.floor(y))
        if 0 <= xi < self.w and 0 <= yi < self.h:
            if inside and self.mat[yi, xi] < 0:
                return self
            if mat is not None:
                self.mat[yi, xi] = self._mid(mat)
            if tone is not None:
                self.tone[yi, xi] = tone
            if delta is not None:
                self.tone[yi, xi] += delta
            self._clamp()
        return self

    def dots(self, pts: Iterable[Pt], mat: str | None, tone: int | None = None, delta: int | None = None,
             inside: bool = False) -> "Part":
        for x, y in pts:
            self.dot(x, y, mat, tone, delta, inside)
        return self

    def rim(self, dx: int, dy: int, depth: int = 1, tone: int | None = None, delta: int | None = None,
            clip=None, pattern: str | None = None, region: Sequence[Pt] | None = None) -> "Part":
        """Banda que sigue la silueta por el lado (dx, dy): si a `depth` píxeles en esa dirección
        ya no hay pieza, el píxel cambia de tono. Con (1, 1) es la sombra del lado contrario a la
        luz; con (-1, -1), el brillo del lado de la luz. Sigue los ángulos del polígono: por eso
        las sombras salen angulosas y no redondeadas."""
        mk = self.mask
        if clip is not None:
            names = [clip] if isinstance(clip, str) else list(clip)
            ids = [self.names.index(n) for n in names if n in self.names]
            mk = np.isin(self.mat, ids)
        edge = np.zeros_like(mk)
        for k in range(1, depth + 1):
            sh = np.zeros_like(mk)
            ys0, ys1 = max(0, -dy * k), self.h - max(0, dy * k)
            xs0, xs1 = max(0, -dx * k), self.w - max(0, dx * k)
            sh[ys0:ys1, xs0:xs1] = mk[ys0 + dy * k:ys1 + dy * k, xs0 + dx * k:xs1 + dx * k]
            edge |= mk & ~sh
        if region is not None:
            edge &= self._poly_mask(region)
        self._apply(edge, None, tone, delta, pattern)
        return self

    def dither_edges(self, mat: str, lo: int, hi: int, pattern: str = "checker") -> "Part":
        """Trama la frontera entre dos tonos de un material: los píxeles del tono `lo` que tocan
        el tono `hi` se vuelven `hi` en damero (transición a mano, 1 px)."""
        if mat not in self.names:
            return self
        i = self.names.index(mat)
        lo_m = (self.mat == i) & (self.tone == lo)
        hi_m = (self.mat == i) & (self.tone == hi)
        nb = np.zeros_like(hi_m)
        nb[1:, :] |= hi_m[:-1, :]
        nb[:-1, :] |= hi_m[1:, :]
        nb[:, 1:] |= hi_m[:, :-1]
        nb[:, :-1] |= hi_m[:, 1:]
        m = lo_m & nb & pattern_mask(pattern, self.h, self.w)
        self.tone[m] = hi
        return self

    def erase(self, pts: Sequence[Pt]) -> "Part":
        """Borra (para mordiscos, desgarros y huecos en la silueta)."""
        m = self._poly_mask(pts)
        self.mat[m] = -1
        return self

    def erase_line(self, pts: Sequence[Pt], width: int = 1) -> "Part":
        m = self._line_mask(pts, width)
        self.mat[m] = -1
        return self

    # ---- salida ----
    def colors(self) -> np.ndarray:
        """RGBA sin contorno."""
        out = np.zeros((self.h, self.w, 4), np.uint8)
        for i, n in enumerate(self.names):
            r = np.array(_RAMPS[n], np.uint8)
            sel = self.mat == i
            out[sel, :3] = r[np.clip(self.tone[sel], 0, len(r) - 1)]
            out[sel, 3] = 255
        return out

    def render(self, outline: bool = True, selout: bool = True, ink: RGB = INK,
               ink_mix: float = 0.6, light_gap: bool = False) -> Image.Image:
        """Imagen RGBA con contorno selectivo de 1 px por fuera de la pieza.

        El contorno toma el tono más oscuro del material vecino, mezclado con tinta. Con
        `selout`, por el lado de la luz (arriba e izquierda) usa el segundo tono de la rampa,
        y con `light_gap` deja algún hueco en ese lado, como un trazo a mano que se levanta."""
        rgba = self.colors()
        if not outline:
            return Image.fromarray(rgba, "RGBA")
        mk = self.mask
        h, w = mk.shape
        # Para cada píxel vacío vecino, elige el material del vecino (prioridad: abajo/dcha.).
        out_mat = np.full((h, w), -1, np.int16)
        lit_side = np.zeros((h, w), bool)
        src_ok = mk & ~self.no_outline
        for dy, dx, lit in ((-1, 0, False), (0, -1, False), (1, 0, True), (0, 1, True)):
            # vecino en (y+dy, x+dx)
            nb = np.zeros((h, w), bool)
            nm = np.full((h, w), -1, np.int16)
            ys0, ys1 = max(0, -dy), h - max(0, dy)
            xs0, xs1 = max(0, -dx), w - max(0, dx)
            nb[ys0:ys1, xs0:xs1] = src_ok[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx]
            nm[ys0:ys1, xs0:xs1] = self.mat[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx]
            sel = nb & ~mk & (out_mat < 0)
            out_mat[sel] = nm[sel]
            # Si el vecino está abajo o a la derecha, este píxel queda arriba/izquierda: lado de luz.
            lit_side[sel] = lit
        for i, n in enumerate(self.names):
            r = _RAMPS[n]
            sel = out_mat == i
            base = mix(r[0], ink, ink_mix)
            rgba[sel, :3] = base
            rgba[sel, 3] = 255
            if selout and len(r) >= 3:
                soft = mix(r[1], ink, ink_mix * 0.35)
                s2 = sel & lit_side
                rgba[s2, :3] = soft
                if light_gap:
                    gap = s2 & pattern_mask("sparse", h, w)
                    rgba[gap, 3] = 0
        return Image.fromarray(rgba, "RGBA")

    def glow_image(self) -> Image.Image:
        rgba = self.colors()
        rgba[~self.glow, 3] = 0
        return Image.fromarray(rgba, "RGBA")


def compose(parts: Sequence[Part | Image.Image], size: tuple[int, int], outline: bool = True,
            selout: bool = True, light_gap: bool = False, bg: RGB | None = None) -> Image.Image:
    """Superpone piezas de atrás adelante; cada una con su contorno."""
    w, h = size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0) if bg is None else (*bg, 255))
    for p in parts:
        if p is None:
            continue
        im = p if isinstance(p, Image.Image) else p.render(outline=outline, selout=selout, light_gap=light_gap)
        out.alpha_composite(im)
    return out


# --- cutout: girar piezas sin emborronar ------------------------------------------------------

def rotsprite(img: Image.Image, deg: float, pivot: Pt, k: int = 4) -> Image.Image:
    """Gira un sprite de pixel art alrededor de `pivot` sin interpolar colores (estilo
    RotSprite simplificado): se amplía ×k sin filtrar, se gira con vecino más cercano y se
    reduce tomando el píxel central de cada bloque. Para piezas recortadas (brazo, cabeza)."""
    if abs(deg) < 1e-3:
        return img
    big = img.resize((img.width * k, img.height * k), Image.NEAREST)
    big = big.rotate(-deg, resample=Image.NEAREST, center=(pivot[0] * k, pivot[1] * k))
    arr = np.array(big)
    small = arr[k // 2::k, k // 2::k]
    return Image.fromarray(small, "RGBA")


def shift(img: Image.Image, dx: int, dy: int) -> Image.Image:
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(img, (0, 0)) if (dx, dy) == (0, 0) else out.paste(img, (dx, dy), img)
    return out


# --- hojas y vistas ---------------------------------------------------------------------------

def upscale(img: Image.Image, k: int) -> Image.Image:
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def sheet(frames: Sequence[Sequence[Image.Image]], bg: RGB | None = None, gap: int = 0) -> Image.Image:
    """Hoja con filas de fotogramas del mismo tamaño."""
    fw, fh = frames[0][0].size
    cols = max(len(r) for r in frames)
    out = Image.new("RGBA", (cols * (fw + gap), len(frames) * (fh + gap)), (0, 0, 0, 0) if bg is None else (*bg, 255))
    for j, row in enumerate(frames):
        for i, f in enumerate(row):
            out.alpha_composite(f, (i * (fw + gap), j * (fh + gap)))
    return out


@dataclass
class Pose:
    """Esqueleto 2D: articulaciones con nombre en coordenadas del fotograma."""

    joints: dict[str, Pt] = field(default_factory=dict)

    def __getitem__(self, k: str) -> Pt:
        return self.joints[k]

    def __setitem__(self, k: str, v: Pt) -> None:
        self.joints[k] = v

    def moved(self, **offsets: Pt) -> "Pose":
        j = dict(self.joints)
        for k, (ox, oy) in offsets.items():
            x, y = j[k]
            j[k] = (x + ox, y + oy)
        return Pose(j)
