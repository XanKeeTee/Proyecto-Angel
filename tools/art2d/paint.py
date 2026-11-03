"""paint: pintura 2D de alta resolución (segunda muestra) sobre formas trazadas a mano.

Sigue sin haber geometría 3D: cada pieza es una silueta 2D (polígonos punto a punto) y el volumen se
*pinta* encima, como haría un ilustrador:

- **Valor por píxel** (`val`, de 0 = sombra a 1 = luz) y **material** por píxel. Al final cada material
  traduce su valor a una **rampa larga** (10-14 tonos interpolados de 4-6 colores clave) con **tramado
  ordenado** (Bayer 4×4) entre tonos vecinos: transiciones suaves, pero con aspecto de píxel.
- `plane`: una zona de luz o de sombra trazada a mano, con el borde suavizado lo que se pida.
- `form`: el canto que gira. Mide en 2D la distancia al borde de la silueta y oscurece o aclara una
  franja de `bevel` píxeles según hacia dónde mira ese borde respecto a la luz; el interior queda plano.
  Es el «canto redondeado» de un dibujo, no un volumen: con un `bevel` corto las formas siguen planas.
- `crease`: pliegues y oclusión (línea oscura difuminada) con su arista de luz al lado.
- `noise`, `pores`, `weave`, `veins`, `stain`: texturas pintadas (piel con poros, cardenales, trama de
  la tela, sangre que empapa con el cerco más oscuro, venas).
- `gloss`: brillo especular en lo húmedo o pulido.
- `compose`: piezas de atrás adelante, cada una con su contorno, y sombra de contacto de la pieza de
  delante sobre las de detrás.

Requisitos: numpy, scipy (ndimage) y Pillow.
"""

from __future__ import annotations

import math
import random
from typing import Iterable, Sequence

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

Pt = tuple[float, float]
INK = np.array([10, 7, 12], np.float32)

BAYER4 = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) + 0.5) / 16.0

_RAMPS: dict[str, np.ndarray] = {}


def _hex(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def ramp(name: str, keys: Sequence[str], n: int = 12) -> None:
    """Rampa de `n` tonos interpolada entre colores clave (de sombra a luz)."""
    k = np.stack([_hex(c) for c in keys])
    xs = np.linspace(0, len(k) - 1, n)
    out = np.empty((n, 3), np.float32)
    for i, x in enumerate(xs):
        a = int(math.floor(x))
        b = min(a + 1, len(k) - 1)
        t = x - a
        out[i] = k[a] * (1 - t) + k[b] * t
    _RAMPS[name] = out


def bayer(h: int, w: int) -> np.ndarray:
    return np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]


def value_noise(h: int, w: int, scale: float, seed: int, octaves: int = 1) -> np.ndarray:
    """Ruido de valor 0..1 (rejilla aleatoria ampliada con interpolación), para texturas."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        s = max(1.0, scale / (2 ** o))
        gh, gw = int(h / s) + 3, int(w / s) + 3
        g = rng.random((gh, gw)).astype(np.float32)
        z = ndimage.zoom(g, (s, s), order=3)[:h, :w]
        z = np.pad(z, ((0, max(0, h - z.shape[0])), (0, max(0, w - z.shape[1]))), mode="edge")
        out += amp * z
        tot += amp
        amp *= 0.5
    out /= tot
    return np.clip((out - out.mean()) * 1.8 + 0.5, 0, 1)


class Piece:
    """Una pieza pintable: material y valor por píxel."""

    def __init__(self, w: int, h: int, name: str = "") -> None:
        self.w, self.h, self.name = w, h, name
        self.mat = np.full((h, w), -1, np.int16)
        self.val = np.zeros((h, w), np.float32)
        self.names: list[str] = []
        self.outline = True

    # --- máscaras ---
    def poly_mask(self, pts: Sequence[Pt]) -> np.ndarray:
        img = Image.new("L", (self.w, self.h), 0)
        p = [(float(x), float(y)) for x, y in pts]
        if len(p) >= 3:
            ImageDraw.Draw(img).polygon(p, fill=255)
        return np.array(img) > 127

    def line_mask(self, pts: Sequence[Pt], width: float = 1.0) -> np.ndarray:
        img = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(img).line([(float(x), float(y)) for x, y in pts], fill=255, width=max(1, int(round(width))),
                                 joint="curve")
        return np.array(img) > 127

    def _mid(self, name: str) -> int:
        if name not in _RAMPS:
            raise KeyError(name)
        if name not in self.names:
            self.names.append(name)
        return self.names.index(name)

    @property
    def mask(self) -> np.ndarray:
        return self.mat >= 0

    def of(self, *mats: str) -> np.ndarray:
        ids = [self.names.index(m) for m in mats if m in self.names]
        return np.isin(self.mat, ids)

    # --- relleno ---
    def fill(self, pts: Sequence[Pt], mat: str, val: float = 0.5, inside: bool = False) -> np.ndarray:
        m = self.poly_mask(pts)
        if inside:
            m &= self.mask
        self.mat[m] = self._mid(mat)
        self.val[m] = val
        return m

    def fill_mask(self, m: np.ndarray, mat: str, val: float | None = None) -> None:
        self.mat[m] = self._mid(mat)
        if val is not None:
            self.val[m] = val

    def line(self, pts: Sequence[Pt], mat: str | None, val: float | None, width: float = 1.0,
             inside: bool = False) -> np.ndarray:
        m = self.line_mask(pts, width)
        if inside:
            m &= self.mask
        if mat is not None:
            self.mat[m] = self._mid(mat)
        if val is not None:
            self.val[m] = val
        return m

    def dot(self, x: float, y: float, mat: str | None, val: float, inside: bool = True) -> None:
        xi, yi = int(x), int(y)
        if 0 <= xi < self.w and 0 <= yi < self.h and (not inside or self.mat[yi, xi] >= 0):
            if mat is not None:
                self.mat[yi, xi] = self._mid(mat)
            self.val[yi, xi] = val

    def erase(self, pts: Sequence[Pt]) -> None:
        self.mat[self.poly_mask(pts)] = -1

    # --- pintura de valor ---
    def add(self, field: np.ndarray, where: np.ndarray | None = None) -> None:
        m = self.mask if where is None else (where & self.mask)
        self.val[m] += field[m] if isinstance(field, np.ndarray) else field

    def plane(self, pts: Sequence[Pt], delta: float, soft: float = 1.2, clip: Sequence[str] | None = None) -> None:
        """Zona de luz (delta > 0) o sombra trazada a mano, con borde suavizado."""
        m = self.poly_mask(pts).astype(np.float32)
        if soft > 0:
            m = ndimage.gaussian_filter(m, soft)
        where = self.mask if clip is None else self.of(*clip)
        self.val[where] += delta * m[where]

    def form(self, light: Pt = (-0.35, -0.94), bevel: float = 5.0, strength: float = 0.28, rim_dark: float = 0.12,
             region: np.ndarray | None = None, center_lift: float = 0.0) -> None:
        """Canto que gira: franja de `bevel` px junto al borde, más clara si el borde mira a la luz
        y más oscura si no; `rim_dark` oscurece el filo (oclusión); `center_lift` aclara el centro."""
        m = self.mask if region is None else (region & self.mask)
        if not m.any():
            return
        d = ndimage.distance_transform_edt(m).astype(np.float32)
        g = ndimage.gaussian_filter(d, 1.6)
        gy, gx = np.gradient(g)
        n = np.hypot(gx, gy) + 1e-6
        nx, ny = -gx / n, -gy / n          # hacia fuera
        lx, ly = light
        ln = math.hypot(lx, ly)
        lam = (nx * lx + ny * ly) / ln
        t = np.clip(1.0 - d / bevel, 0, 1)
        self.val[m] += (strength * lam * t - rim_dark * t * t)[m]
        if center_lift:
            self.val[m] += (center_lift * np.clip(d / (bevel * 2.5), 0, 1))[m]

    def crease(self, pts: Sequence[Pt], depth: float = 0.25, width: float = 1.6, ridge: float = 0.0,
               ridge_off: Pt = (1.0, 1.0), clip: Sequence[str] | None = None) -> None:
        """Pliegue u oclusión: línea oscura difuminada; `ridge` aclara una paralela desplazada."""
        m = self.line_mask(pts, 1).astype(np.float32)
        f = ndimage.gaussian_filter(m, width * 0.6)
        f /= max(f.max(), 1e-6)
        where = self.mask if clip is None else self.of(*clip)
        self.val[where] -= depth * f[where]
        if ridge:
            q = [(x + ridge_off[0], y + ridge_off[1]) for x, y in pts]
            r = ndimage.gaussian_filter(self.line_mask(q, 1).astype(np.float32), width * 0.5)
            r /= max(r.max(), 1e-6)
            self.val[where] += ridge * r[where]

    def noise(self, amp: float, scale: float, seed: int, clip: Sequence[str] | None = None, octaves: int = 2) -> None:
        n = value_noise(self.h, self.w, scale, seed, octaves) - 0.5
        where = self.mask if clip is None else self.of(*clip)
        self.val[where] += amp * n[where]

    def pores(self, amp: float, density: float, seed: int, clip: Sequence[str] | None = None) -> None:
        """Poros y granulado de la piel: puntos sueltos un poco más oscuros (y alguno claro)."""
        rng = np.random.default_rng(seed)
        r = rng.random((self.h, self.w))
        where = self.mask if clip is None else self.of(*clip)
        self.val[where & (r < density)] -= amp
        self.val[where & (r > 1 - density * 0.4)] += amp * 0.6

    def weave(self, amp: float, period: int = 2, clip: Sequence[str] | None = None, angle: int = 0) -> None:
        """Trama de la tela: rayado fino alterno."""
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        if angle:
            pat = ((xx + yy) // period) % 2
        else:
            pat = ((yy // period) % 2) ^ ((xx // (period * 2)) % 2)
        where = self.mask if clip is None else self.of(*clip)
        self.val[where] += (amp * (pat - 0.5))[where]

    def stain(self, center: Pt, radius: float, mat: str, seed: int, val: float | None = None, ring: float = 0.18,
              stretch: Pt = (1.0, 1.0), clip: Sequence[str] | None = None, drip: float = 0.0) -> None:
        """Mancha que empapa: forma irregular (ruido) con el cerco más oscuro; `drip` la alarga
        hacia abajo en chorretones."""
        yy, xx = np.mgrid[0:self.h, 0:self.w].astype(np.float32)
        dx = (xx - center[0]) / (radius * stretch[0])
        dy = (yy - center[1]) / (radius * stretch[1])
        if drip:
            dy = np.where(dy > 0, dy / (1 + drip * value_noise(self.h, self.w, 3, seed + 9)), dy)
        d = np.sqrt(dx * dx + dy * dy)
        n = value_noise(self.h, self.w, max(2.0, radius / 2), seed, 2)
        f = 1.0 - d + (n - 0.5) * 0.9
        where = self.mask if clip is None else self.of(*clip)
        inside = (f > 0.0) & where
        edge = (f > 0.0) & (f < 0.22) & where
        self.mat[inside] = self._mid(mat)
        if val is not None:
            self.val[inside] = np.minimum(self.val[inside], val + 0.12 * (n[inside] - 0.5))
        self.val[edge] -= ring

    def veins(self, start: Pt, length: int, seed: int, ang: float = math.pi / 2, depth: float = 0.16,
              mat: str | None = None, branch: float = 0.35) -> None:
        """Venas: trazos quebrados que se ramifican, un poco más oscuros (y del material `mat`)."""
        rnd = random.Random(seed)
        stack = [(start, ang, length)]
        while stack:
            (x, y), a, ln = stack.pop()
            pts = [(x, y)]
            for _ in range(ln):
                a += rnd.uniform(-0.45, 0.45)
                x, y = x + math.cos(a) * 1.6, y + math.sin(a) * 1.6
                pts.append((x, y))
                if rnd.random() < branch / 6 and ln > 4:
                    stack.append(((x, y), a + rnd.choice((-0.9, 0.9)), ln // 2))
            m = self.line_mask(pts, 1) & self.mask
            self.val[m] -= depth
            if mat is not None:
                self.mat[m & (np.random.default_rng(seed).random(m.shape) < 0.7)] = self._mid(mat)

    def gloss(self, pts: Sequence[Pt] | None = None, amount: float = 0.35, soft: float = 0.8,
              mask: np.ndarray | None = None) -> None:
        """Brillo especular (húmedo, porcelana, metal)."""
        m = self.poly_mask(pts) if pts is not None else mask
        f = ndimage.gaussian_filter(m.astype(np.float32), soft) if soft else m.astype(np.float32)
        self.val[self.mask] += amount * f[self.mask]

    def cast(self, other_mask: np.ndarray, offset: Pt = (2, 3), blur: float = 2.5, depth: float = 0.25) -> None:
        """Sombra que otra pieza arroja sobre esta (pintada en el valor)."""
        sh = ndimage.shift(other_mask.astype(np.float32), (offset[1], offset[0]), order=0)
        f = ndimage.gaussian_filter(sh, blur)
        m = self.mask & ~other_mask
        self.val[m] -= depth * f[m]

    # --- salida ---
    def render(self, outline: bool | None = None, ink_mix: float = 0.55, dither: float = 1.0) -> Image.Image:
        out = np.zeros((self.h, self.w, 4), np.uint8)
        thr = bayer(self.h, self.w) - 0.5
        for i, n in enumerate(self.names):
            r = _RAMPS[n]
            sel = self.mat == i
            if not sel.any():
                continue
            v = np.clip(self.val[sel], 0, 1) * (len(r) - 1) + thr[sel] * dither
            idx = np.clip(np.round(v), 0, len(r) - 1).astype(int)
            out[sel, :3] = r[idx].astype(np.uint8)
            out[sel, 3] = 255
        if outline if outline is not None else self.outline:
            mk = self.mask
            ring = ndimage.binary_dilation(mk, structure=[[0, 1, 0], [1, 1, 1], [0, 1, 0]]) & ~mk
            # material del vecino para teñir el contorno
            mat = self.mat.copy()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                sh = np.roll(np.roll(self.mat, dy, 0), dx, 1)
                sel = ring & (mat < 0) & (sh >= 0)
                mat[sel] = sh[sel]
            for i, n in enumerate(self.names):
                sel = ring & (mat == i)
                c = _RAMPS[n][0] * (1 - ink_mix) + INK * ink_mix
                out[sel, :3] = c.astype(np.uint8)
                out[sel, 3] = 255
        return Image.fromarray(out, "RGBA")


def compose(pieces: Sequence[Piece | Image.Image], size: tuple[int, int], contact: float = 0.28,
            contact_off: Pt = (2, 3), blur: float = 2.5) -> Image.Image:
    """De atrás adelante. Cada pieza oscurece lo que ya hay detrás con su sombra de contacto."""
    w, h = size
    acc = np.zeros((h, w, 4), np.float32)
    thr = bayer(h, w)
    for p in pieces:
        if p is None:
            continue
        im = p if isinstance(p, Image.Image) else p.render()
        a = np.asarray(im).astype(np.float32)
        m = a[..., 3] > 0
        if contact > 0 and acc[..., 3].any():
            sh = ndimage.shift(m.astype(np.float32), (contact_off[1], contact_off[0]), order=0)
            f = ndimage.gaussian_filter(sh, blur) * contact
            f = np.floor(f * 6 + thr) / 6          # sombra en escalones tramados
            under = (acc[..., 3] > 0) & ~m
            acc[under, :3] *= (1 - f[under])[:, None]
        acc[m] = a[m]
    return Image.fromarray(np.clip(acc, 0, 255).astype(np.uint8), "RGBA")


def limb(a: Pt, b: Pt, profile: Sequence[tuple[float, float, float]]) -> list[Pt]:
    """Silueta de una extremidad entre dos articulaciones: (t, ancho izq., ancho der.)."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy) or 1.0
    ux, uy = dx / ln, dy / ln
    nx, ny = uy, -ux
    left, right = [], []
    for t, wl, wr in profile:
        cx, cy = a[0] + dx * t, a[1] + dy * t
        left.append((cx + nx * wl, cy + ny * wl))
        right.append((cx - nx * wr, cy - ny * wr))
    return left + right[::-1]


def lerp(a: Pt, b: Pt, t: float) -> Pt:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def mirror(pts: Iterable[Pt], axis: float) -> list[Pt]:
    return [(2 * axis - x, y) for x, y in pts]


def offset(pts: Iterable[Pt], ox: float, oy: float) -> list[Pt]:
    return [(x + ox, y + oy) for x, y in pts]


def upscale(im: Image.Image, k: int) -> Image.Image:
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def on_bg(im: Image.Image, bg=(22, 21, 24)) -> Image.Image:
    out = Image.new("RGBA", im.size, (*bg, 255))
    out.alpha_composite(im)
    return out


def row(images: Sequence[Image.Image], gap: int = 4, bg=(22, 21, 24)) -> Image.Image:
    w = sum(i.width for i in images) + gap * (len(images) - 1)
    h = max(i.height for i in images)
    out = Image.new("RGBA", (w, h), (*bg, 255))
    x = 0
    for i in images:
        out.alpha_composite(i, (x, h - i.height))
        x += i.width + gap
    return out


def rotsprite(img: Image.Image, deg: float, pivot: Pt, k: int = 4) -> Image.Image:
    if abs(deg) < 1e-3:
        return img
    big = img.resize((img.width * k, img.height * k), Image.NEAREST)
    big = big.rotate(-deg, resample=Image.NEAREST, center=(pivot[0] * k, pivot[1] * k))
    return Image.fromarray(np.array(big)[k // 2::k, k // 2::k], "RGBA")
