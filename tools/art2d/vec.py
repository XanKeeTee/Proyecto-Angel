"""vec: dibujo 2D «pintado y reducido» (tercera muestra).

Método, todo en el plano:
1. **Trazo en alta resolución** (×k del tamaño final) con curvas suaves: cada forma es una curva
   cerrada que pasa por los puntos dados (Catmull-Rom convertida a Bézier cúbicas), con esquinas
   donde se marquen (`C(x, y)`). Se rasteriza con cairo y antialias.
2. **Una silueta continua por material**: todo lo que es piel va a la misma capa de piel, toda la
   tela a la capa de tela, etc. El sombreado se hace sobre la capa entera, así no quedan cortes en
   hombros, codos ni rodillas.
3. **Volumen pintado a esa escala**: masas (`mass`) que dan volumen suave dentro de la silueta
   (omóplato, gemelo, deltoides) a partir de su propia forma difuminada; luz lateral **dura** (el
   terminador es un corte nítido), luz de relleno suave, contraluz de color en el borde opuesto,
   oclusión en pliegues (`crease`), texturas (`noise`, `pores`, `weave`, `stain`, `veins`) y brillo
   húmedo (`gloss`).
4. **Reducción** al tamaño final con filtro de área, **cuantización a la paleta** del juego con
   tramado ordenado suave, **contorno** de un píxel alrededor de la silueta completa y **limpieza**
   (píxeles sueltos). Al final se pueden retocar a mano detalles a escala 1 (`touch`).

Requisitos: numpy, scipy, Pillow y pycairo.
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass
from typing import Callable, Iterable, Sequence

import cairo
import numpy as np
from PIL import Image
from scipy import ndimage

Pt = tuple[float, float]

# --- rampas (de sombra a luz), en color continuo ----------------------------------------------

RAMPS: dict[str, np.ndarray] = {}


def _hex(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def ramp(name: str, keys: Sequence[str]) -> None:
    RAMPS[name] = np.stack([_hex(k) for k in keys])


def ramp_eval(name: str, v: np.ndarray) -> np.ndarray:
    k = RAMPS[name]
    x = np.clip(v, 0, 1) * (len(k) - 1)
    i = np.clip(np.floor(x).astype(int), 0, len(k) - 2)
    t = (x - i)[..., None]
    return k[i] * (1 - t) + k[i + 1] * t


def palette(names: Iterable[str], steps: int = 14) -> np.ndarray:
    """Paleta cerrada: cada rampa muestreada en `steps` tonos."""
    cols = [ramp_eval(n, np.linspace(0, 1, steps)) for n in names]
    return np.concatenate(cols, 0)


# --- curvas -----------------------------------------------------------------------------------

class C(tuple):
    """Punto de esquina (la curva no se suaviza ahí)."""

    def __new__(cls, x: float, y: float):
        return super().__new__(cls, (x, y))


def bez_closed(pts: Sequence[Pt], tension: float = 1.0) -> list[tuple]:
    """Segmentos Bézier (p0, c1, c2, p1) de una curva cerrada que pasa por `pts`."""
    n = len(pts)
    segs = []
    for i in range(n):
        p0, p1 = pts[i], pts[(i + 1) % n]
        pm, p2 = pts[(i - 1) % n], pts[(i + 2) % n]
        t0 = (0.0, 0.0) if isinstance(p0, C) else ((p1[0] - pm[0]) * tension / 6, (p1[1] - pm[1]) * tension / 6)
        t1 = (0.0, 0.0) if isinstance(p1, C) else ((p2[0] - p0[0]) * tension / 6, (p2[1] - p0[1]) * tension / 6)
        segs.append((p0, (p0[0] + t0[0], p0[1] + t0[1]), (p1[0] - t1[0], p1[1] - t1[1]), p1))
    return segs


def bez_open(pts: Sequence[Pt], tension: float = 1.0) -> list[tuple]:
    n = len(pts)
    segs = []
    for i in range(n - 1):
        p0, p1 = pts[i], pts[i + 1]
        pm = pts[i - 1] if i > 0 else p0
        p2 = pts[i + 2] if i + 2 < n else p1
        t0 = (0.0, 0.0) if isinstance(p0, C) else ((p1[0] - pm[0]) * tension / 6, (p1[1] - pm[1]) * tension / 6)
        t1 = (0.0, 0.0) if isinstance(p1, C) else ((p2[0] - p0[0]) * tension / 6, (p2[1] - p0[1]) * tension / 6)
        segs.append((p0, (p0[0] + t0[0], p0[1] + t0[1]), (p1[0] - t1[0], p1[1] - t1[1]), p1))
    return segs


# --- lienzo -----------------------------------------------------------------------------------

class Fig:
    """Figura en alta resolución: material y valor por píxel, más luz de color añadida."""

    def __init__(self, w: int, h: int, k: int = 6, light: Pt = (-0.55, -0.83), lz: float = 0.6) -> None:
        self.w, self.h, self.k = w, h, k
        self.W, self.H = w * k, h * k
        self.mat = np.full((self.H, self.W), -1, np.int16)
        self.val = np.zeros((self.H, self.W), np.float32)
        self.add = np.zeros((self.H, self.W, 3), np.float32)      # luz de color (contraluz, brillos)
        self.names: list[str] = []
        self.light = light
        self.lz = lz
        self.touches: list[Callable[[np.ndarray], None]] = []
        self.part = np.zeros((self.H, self.W), np.int8)   # pieza (para separar mutilaciones)
        self.cur = 0

    # --- máscaras ---
    def _surface(self):
        surf = cairo.ImageSurface(cairo.FORMAT_A8, self.W, self.H)
        ctx = cairo.Context(surf)
        ctx.scale(self.k, self.k)
        return surf, ctx

    @staticmethod
    def _read(surf) -> np.ndarray:
        surf.flush()
        stride = surf.get_stride()
        buf = np.frombuffer(surf.get_data(), np.uint8).reshape(surf.get_height(), stride)
        return buf[:, :surf.get_width()].astype(np.float32) / 255.0

    def shape(self, pts: Sequence[Pt], tension: float = 1.0) -> np.ndarray:
        """Cobertura (0..1) de una forma cerrada suave."""
        surf, ctx = self._surface()
        segs = bez_closed(pts, tension)
        ctx.move_to(*segs[0][0])
        for _, c1, c2, p1 in segs:
            ctx.curve_to(*c1, *c2, *p1)
        ctx.close_path()
        ctx.fill()
        return self._read(surf)

    def poly(self, pts: Sequence[Pt]) -> np.ndarray:
        surf, ctx = self._surface()
        ctx.move_to(*pts[0])
        for p in pts[1:]:
            ctx.line_to(*p)
        ctx.close_path()
        ctx.fill()
        return self._read(surf)

    def stroke(self, pts: Sequence[Pt], width: float, tension: float = 1.0, taper: bool = False) -> np.ndarray:
        """Cobertura de un trazo abierto (en px finales de ancho). Con `taper`, adelgaza al final."""
        surf, ctx = self._surface()
        ctx.set_line_cap(cairo.LINE_CAP_ROUND)
        ctx.set_line_join(cairo.LINE_JOIN_ROUND)
        segs = bez_open(pts, tension)
        if not taper:
            ctx.set_line_width(width)
            ctx.move_to(*segs[0][0])
            for _, c1, c2, p1 in segs:
                ctx.curve_to(*c1, *c2, *p1)
            ctx.stroke()
        else:
            n = len(segs)
            for i, (p0, c1, c2, p1) in enumerate(segs):
                ctx.set_line_width(max(0.2, width * (1 - i / n)))
                ctx.move_to(*p0)
                ctx.curve_to(*c1, *c2, *p1)
                ctx.stroke()
        return self._read(surf)

    def ellipse(self, c: Pt, rx: float, ry: float, rot: float = 0.0) -> np.ndarray:
        surf, ctx = self._surface()
        ctx.translate(*c)
        ctx.rotate(rot)
        ctx.scale(rx, ry)
        ctx.arc(0, 0, 1, 0, 2 * math.pi)
        ctx.fill()
        return self._read(surf)

    # --- materiales ---
    def _mid(self, name: str) -> int:
        if name not in self.names:
            self.names.append(name)
        return self.names.index(name)

    @property
    def mask(self) -> np.ndarray:
        return self.mat >= 0

    def of(self, *names: str) -> np.ndarray:
        ids = [self.names.index(n) for n in names if n in self.names]
        return np.isin(self.mat, ids)

    def fill(self, cov: np.ndarray, mat: str, val: float = 0.5, inside: bool = False) -> np.ndarray:
        m = cov > 0.5
        if inside:
            m &= self.mask
        self.mat[m] = self._mid(mat)
        self.val[m] = val
        if not inside:
            self.part[m] = self.cur
        return m

    def recolor(self, m: np.ndarray, mat: str) -> None:
        self.mat[m & self.mask] = self._mid(mat)

    def erase(self, cov: np.ndarray) -> None:
        self.mat[cov > 0.5] = -1

    # --- pintura ---
    def _where(self, clip):
        return self.mask if clip is None else self.of(*([clip] if isinstance(clip, str) else clip))

    def paint(self, cov: np.ndarray, delta: float, blur: float = 0.0, clip=None) -> None:
        """Zona plana de luz o sombra (con borde duro o suavizado `blur` px finales)."""
        f = ndimage.gaussian_filter(cov, blur * self.k) if blur else cov
        m = self._where(clip)
        self.val[m] += delta * f[m]

    def lambert(self, region: np.ndarray, soft: float, light: Pt | None = None) -> np.ndarray:
        """Luz de una masa: normal sacada de su silueta difuminada `soft` px finales."""
        lx, ly = light or self.light
        g = ndimage.gaussian_filter(region.astype(np.float32), soft * self.k)
        gy, gx = np.gradient(g)
        mag = np.hypot(gx, gy)
        sl = np.clip(mag * soft * self.k * 2.5, 0, 1)
        nx = -gx / (mag + 1e-6) * sl
        ny = -gy / (mag + 1e-6) * sl
        nz = np.sqrt(1 - sl * sl)
        lz = self.lz
        ln = math.sqrt(lx * lx + ly * ly + lz * lz)
        return (nx * lx + ny * ly + nz * lz) / ln

    def mass(self, region: np.ndarray, soft: float, hard: float = 0.32, fill: float = 0.12, edge: float = 0.08,
             clip=None, light: Pt | None = None, terminator: float = 0.0) -> None:
        """Volumen de una masa: luz dura (corte en `terminator`) + relleno suave + oclusión del borde."""
        reg = region > 0.5 if region.dtype != bool else region
        lam = self.lambert(reg, soft, light)
        h = np.clip((lam - terminator) * 6.0, -1, 1)
        m = reg & self._where(clip)
        d = ndimage.distance_transform_edt(reg) / self.k
        occ = np.clip(1 - d / (soft * 0.6), 0, 1) ** 2
        self.val[m] += (hard * h + fill * lam - edge * occ)[m]

    def rim(self, color: Sequence[float], light: Pt, width: float, strength: float = 1.0, clip=None) -> None:
        """Contraluz de color en los bordes que miran a `light`."""
        reg = self._where(clip)
        g = ndimage.gaussian_filter(reg.astype(np.float32), width * self.k * 0.7)
        gy, gx = np.gradient(g)
        n = np.hypot(gx, gy) + 1e-6
        lam = np.clip((-gx / n) * light[0] + (-gy / n) * light[1], 0, 1)
        d = ndimage.distance_transform_edt(reg) / self.k
        band = np.clip(1 - d / width, 0, 1)
        f = (lam * band * strength)[..., None] * np.array(color, np.float32)[None, None, :]
        self.add[reg] += f[reg]

    def crease(self, pts: Sequence[Pt], depth: float = 0.25, width: float = 1.0, blur: float = 0.6,
               ridge: float = 0.0, ridge_off: Pt = (0.8, 0.8), clip=None, tension: float = 1.0) -> None:
        """Pliegue u oclusión: trazo oscuro difuminado y, si se pide, su arista de luz al lado."""
        c = ndimage.gaussian_filter(self.stroke(pts, width, tension), blur * self.k)
        m = self._where(clip)
        self.val[m] -= depth * (c / max(c.max(), 1e-6))[m]
        if ridge:
            q = [(x + ridge_off[0], y + ridge_off[1]) for x, y in pts]
            r = ndimage.gaussian_filter(self.stroke(q, width * 0.8, tension), blur * self.k)
            self.val[m] += ridge * (r / max(r.max(), 1e-6))[m]

    def noise(self, amp: float, scale: float, seed: int, clip=None) -> None:
        rng = np.random.default_rng(seed)
        s = scale * self.k
        g = rng.random((int(self.H / s) + 3, int(self.W / s) + 3)).astype(np.float32)
        z = ndimage.zoom(g, s, order=3)[:self.H, :self.W]
        z = np.pad(z, ((0, max(0, self.H - z.shape[0])), (0, max(0, self.W - z.shape[1]))), mode="edge")
        m = self._where(clip)
        self.val[m] += amp * (z[m] - 0.5) * 2

    def pores(self, amp: float, size: float, density: float, seed: int, clip=None) -> None:
        """Poros, motas o grano: puntos de `size` px finales."""
        rng = np.random.default_rng(seed)
        s = max(1, int(size * self.k))
        g = (rng.random((self.H // s + 1, self.W // s + 1)) < density).astype(np.float32)
        z = np.kron(g, np.ones((s, s), np.float32))[:self.H, :self.W]
        z = ndimage.gaussian_filter(z, s * 0.3)
        m = self._where(clip)
        self.val[m] -= amp * z[m] / max(z.max(), 1e-6)

    def weave(self, amp: float, period: float = 1.0, clip=None) -> None:
        yy, xx = np.mgrid[0:self.H, 0:self.W]
        p = period * self.k
        pat = np.sin(yy / p * math.pi) * np.sin(xx / (p * 1.7) * math.pi)
        m = self._where(clip)
        self.val[m] += amp * pat[m]

    def stain(self, c: Pt, r: float, mat: str, seed: int, val: float | None = None, ring: float = 0.15,
              stretch: Pt = (1.0, 1.0), drip: float = 0.0, clip=None, wet: float = 0.0) -> np.ndarray:
        """Mancha que empapa con el cerco más oscuro; `drip` la alarga en chorretones; `wet` brilla."""
        rng = np.random.default_rng(seed)
        yy, xx = np.mgrid[0:self.H, 0:self.W].astype(np.float32)
        dx = (xx / self.k - c[0]) / (r * stretch[0])
        dy = (yy / self.k - c[1]) / (r * stretch[1])
        g = rng.random((int(self.H / (r * self.k * 0.35)) + 3, int(self.W / (r * self.k * 0.35)) + 3))
        z = ndimage.zoom(g.astype(np.float32), r * self.k * 0.35, order=3)[:self.H, :self.W]
        z = np.pad(z, ((0, max(0, self.H - z.shape[0])), (0, max(0, self.W - z.shape[1]))), mode="edge")
        if drip:
            cols = rng.random(self.W // max(1, int(self.k * 1.5)) + 2)
            col = np.repeat(cols, max(1, int(self.k * 1.5)))[:self.W][None, :]
            dy = np.where(dy > 0, dy / (1 + drip * (col > 0.6) * 3.0), dy)
        f = 1 - np.sqrt(dx * dx + dy * dy) + (z - 0.5) * 0.8
        m = (f > 0) & self._where(clip)
        self.mat[m] = self._mid(mat)
        if val is not None:
            self.val[m] = val + 0.1 * (z[m] - 0.5)
        e = m & (f < 0.16)
        self.val[e] -= ring
        if wet:
            spec = m & (z > 0.72) & (f > 0.2)
            self.val[spec] += wet
        return m

    def veins(self, start: Pt, length: int, seed: int, ang: float, depth: float = 0.18, width: float = 0.7,
              mat: str | None = None, clip=None) -> None:
        rnd = random.Random(seed)
        stack = [(start, ang, length, width)]
        while stack:
            (x, y), a, ln, w = stack.pop()
            pts = [(x, y)]
            for _ in range(ln):
                a += rnd.uniform(-0.35, 0.35)
                x, y = x + math.cos(a) * 2.0, y + math.sin(a) * 2.0
                pts.append((x, y))
                if rnd.random() < 0.08 and ln > 4:
                    stack.append(((x, y), a + rnd.choice((-0.8, 0.8)), ln // 2, w * 0.7))
            c = self.stroke(pts, w, taper=True)
            m = (c > 0.3) & self._where(clip)
            self.val[m] -= depth
            if mat:
                self.mat[m] = self._mid(mat)

    def gloss(self, cov: np.ndarray, amount: float = 0.4, blur: float = 0.3, color: Sequence[float] | None = None) -> None:
        f = ndimage.gaussian_filter(cov, blur * self.k) if blur else cov
        m = self.mask
        if color is None:
            self.val[m] += amount * f[m]
        else:
            self.add[m] += (f[..., None] * np.array(color, np.float32) * amount)[m]

    def touch(self, fn: Callable[[np.ndarray], None]) -> None:
        """Retoque a escala 1 (recibe el RGBA final, uint8, y lo modifica)."""
        self.touches.append(fn)

    # --- salida ---
    def hires(self) -> np.ndarray:
        rgb = np.zeros((self.H, self.W, 3), np.float32)
        for i, n in enumerate(self.names):
            sel = self.mat == i
            rgb[sel] = ramp_eval(n, self.val[sel])
        rgb += self.add
        a = (self.mat >= 0).astype(np.float32)
        return np.dstack([rgb, a])

    def render(self, pal: np.ndarray, dither: float = 10.0, outline: Sequence[int] = (12, 8, 14),
               outline_mix: float = 0.7) -> Image.Image:
        """Reduce con filtro de área, cuantiza a la paleta con tramado, contorno y limpieza."""
        hi = self.hires()
        k = self.k
        a = hi[..., 3]
        rgb = hi[..., :3] * a[..., None]
        small = rgb.reshape(self.h, k, self.w, k, 3).sum((1, 3))
        alpha = a.reshape(self.h, k, self.w, k).sum((1, 3)) / (k * k)
        col = small / np.maximum(alpha[..., None] * k * k, 1e-6)
        op = alpha > 0.45
        # limpieza de la silueta: sin píxeles sueltos ni agujeros de un píxel
        nb = ndimage.convolve(op.astype(np.int32), np.ones((3, 3), np.int32), mode="constant") - op
        op = (op & (nb >= 2)) | (~op & (nb >= 7))
        # cuantización con tramado ordenado
        bay = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) + 0.5) / 16 - 0.5
        thr = np.tile(bay, (self.h // 4 + 1, self.w // 4 + 1))[:self.h, :self.w]
        c = col + thr[..., None] * dither
        flat = c.reshape(-1, 3)
        d = ((flat[:, None, :] - pal[None, :, :]) ** 2 * np.array([0.3, 0.59, 0.11])).sum(-1)
        q = pal[d.argmin(1)].reshape(self.h, self.w, 3)
        out = np.zeros((self.h, self.w, 4), np.uint8)
        out[op, :3] = np.clip(q[op], 0, 255).astype(np.uint8)
        out[op, 3] = 255
        # píxeles aislados de color: se igualan al vecino más parecido
        for _ in range(1):
            lum = out[..., :3].astype(np.float32) @ np.array([0.3, 0.59, 0.11])
            med = ndimage.median_filter(lum, size=3)
            iso = op & (np.abs(lum - med) > 34)
            if iso.any():
                for y, x in zip(*np.nonzero(iso)):
                    ys, xs = slice(max(0, y - 1), y + 2), slice(max(0, x - 1), x + 2)
                    patch = out[ys, xs, :3].reshape(-1, 3).astype(np.float32)
                    pl = patch @ np.array([0.3, 0.59, 0.11])
                    out[y, x, :3] = patch[np.argmin(np.abs(pl - med[y, x]))].astype(np.uint8)
        # contorno de un píxel, del color oscuro del vecino mezclado con tinta
        ring = ndimage.binary_dilation(op, structure=[[0, 1, 0], [1, 1, 1], [0, 1, 0]]) & ~op
        src = out[..., :3].astype(np.float32)
        acc = np.zeros_like(src)
        cnt = np.zeros(src.shape[:2], np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(np.roll(src, dy, 0), dx, 1)
            so = np.roll(np.roll(op, dy, 0), dx, 1)
            acc[so] += sh[so]
            cnt[so] += 1
        nbcol = acc / np.maximum(cnt[..., None], 1)
        ink = np.array(outline, np.float32)
        oc = nbcol * (1 - outline_mix) * 0.6 + ink * (1 - (1 - outline_mix) * 0.6)
        out[ring, :3] = np.clip(oc[ring], 0, 255).astype(np.uint8)
        out[ring, 3] = 255
        for fn in self.touches:
            fn(out)
        return Image.fromarray(out, "RGBA")

    def split(self, img: Image.Image, n_parts: int) -> list[Image.Image]:
        """Separa la imagen final por piezas (la pieza mayoritaria de cada píxel; el contorno va
        con la pieza vecina). Así las capas de mutilación salen del mismo dibujo."""
        a = np.asarray(img)
        votes = np.zeros((n_parts, self.h, self.w), np.float32)
        for i in range(n_parts):
            votes[i] = ((self.part == i) & self.mask).astype(np.float32).reshape(self.h, self.k, self.w, self.k).sum((1, 3))
        lab = votes.argmax(0)
        has = votes.max(0) > 0
        # el contorno y los píxeles sin voto toman la pieza del vecino más cercano
        idx = ndimage.distance_transform_edt(~has, return_distances=False, return_indices=True)
        lab = lab[idx[0], idx[1]]
        out = []
        for i in range(n_parts):
            b = a.copy()
            b[lab != i, 3] = 0
            out.append(Image.fromarray(b, "RGBA"))
        return out

    def silhouette(self) -> Image.Image:
        a = self.mask.astype(np.float32).reshape(self.h, self.k, self.w, self.k).mean((1, 3)) > 0.45
        out = np.zeros((self.h, self.w, 4), np.uint8)
        out[a] = (0, 0, 0, 255)
        out[~a] = (230, 226, 216, 255)
        return Image.fromarray(out, "RGBA")


def lerp(a: Pt, b: Pt, t: float) -> Pt:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def limb_outline(joints: Sequence[Pt], widths: Sequence[tuple[float, float]]) -> list[Pt]:
    """Contorno suave de un miembro que pasa por varias articulaciones: a cada articulación, un
    ancho a la izquierda y a la derecha. Devuelve los puntos para `Fig.shape` (una sola pieza)."""
    left, right = [], []
    n = len(joints)
    for i, (p, (wl, wr)) in enumerate(zip(joints, widths)):
        a = joints[max(0, i - 1)]
        b = joints[min(n - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1
        nx, ny = dy / ln, -dx / ln
        left.append((p[0] + nx * wl, p[1] + ny * wl))
        right.append((p[0] - nx * wr, p[1] - ny * wr))
    return left + right[::-1]
