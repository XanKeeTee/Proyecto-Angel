"""ink: ilustración 2D a tinta y color plano (cuarta muestra).

Nada de volumen pintado: ni degradados, ni aerógrafo, ni desenfoques, ni brillos redondos. El dibujo
lo lleva la línea y el color va por zonas planas:

- `fill`: zona de color plano (polígono de lados rectos: formas angulosas, quebradas).
- `shadow`/`light`: manchas de sombra o de luz con su propia silueta y borde duro, del tono siguiente
  del material (2-4 tonos por material).
- `line`: trazo de tinta de grosor variable (se afila en los extremos, sin puntas redondas) y quebrado.
- `hatch`: trama de líneas paralelas (y cruzadas) recortada a una zona; `stipple`: punteado.
- `splat`: mancha plana de borde irregular (sangre, mugre), con regueros.

Se dibuja a ×k con cairo **sin antialias** y se reduce al tamaño final por bloques: si en el bloque hay
bastante tinta, el píxel es tinta (las líneas finas sobreviven); si no, el color más frecuente. Así la
reducción no inventa colores intermedios: todo sale de la paleta y con bordes duros.
"""

from __future__ import annotations

import math
import random
from typing import Sequence

import cairo
import numpy as np
from PIL import Image

Pt = tuple[float, float]
INK = (14, 10, 12)


def hexrgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


class Ink:
    def __init__(self, w: int, h: int, k: int = 3, pal: dict | None = None,
                 view: tuple[float, float, float] = (1.0, 0.0, 0.0)) -> None:
        """`view` = (escala, x, y): se dibuja en coordenadas de diseño y se lleva al fotograma
        (x' = (x - vx)·escala), para cambiar el tamaño de una figura sin redibujarla."""
        self.w, self.h, self.k = w, h, k
        self.surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, w * k, h * k)
        self.ctx = cairo.Context(self.surf)
        self.ctx.scale(k * view[0], k * view[0])
        self.ctx.translate(-view[1], -view[2])
        self.ctx.set_antialias(cairo.ANTIALIAS_NONE)
        self.pal = pal or {}

    # --- color ---
    def c(self, mat: str, tone: int = 1) -> tuple[int, int, int]:
        r = self.pal[mat]
        return r[max(0, min(len(r) - 1, tone))]

    def _set(self, rgb) -> None:
        self.ctx.set_source_rgb(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255)

    def _path(self, pts: Sequence[Pt]) -> None:
        self.ctx.move_to(*pts[0])
        for p in pts[1:]:
            self.ctx.line_to(*p)
        self.ctx.close_path()

    # --- rellenos planos ---
    def fill(self, pts: Sequence[Pt], rgb) -> None:
        self._path(pts)
        self._set(rgb)
        self.ctx.fill()

    def clip_fill(self, clip_pts: Sequence[Pt], pts: Sequence[Pt], rgb) -> None:
        """Rellena `pts` solo dentro de `clip_pts` (sombra que no se sale de su forma)."""
        self.ctx.save()
        self._path(clip_pts)
        self.ctx.clip()
        self.fill(pts, rgb)
        self.ctx.restore()

    # --- líneas de tinta ---
    def line(self, pts: Sequence[Pt], w0: float = 1.4, w1: float | None = None, rgb=INK, taper: bool = True) -> None:
        """Trazo de grosor variable: de `w0` a `w1`, afilado en los extremos (punta, no bola)."""
        if len(pts) < 2:
            return
        w1 = w0 if w1 is None else w1
        n = len(pts)
        left, right = [], []
        for i, p in enumerate(pts):
            a = pts[max(0, i - 1)]
            b = pts[min(n - 1, i + 1)]
            dx, dy = b[0] - a[0], b[1] - a[1]
            ln = math.hypot(dx, dy) or 1
            nx, ny = -dy / ln, dx / ln
            t = i / (n - 1)
            wd = (w0 + (w1 - w0) * t) / 2
            if taper and (i == 0 or i == n - 1):
                wd *= 0.25
            left.append((p[0] + nx * wd, p[1] + ny * wd))
            right.append((p[0] - nx * wd, p[1] - ny * wd))
        self.fill(left + right[::-1], rgb)

    def poly_line(self, pts: Sequence[Pt], w: float = 1.4, rgb=INK, closed: bool = True) -> None:
        """Contorno de tinta de un polígono (esquinas en inglete, sin redondear)."""
        self.ctx.set_line_join(cairo.LINE_JOIN_MITER)
        self.ctx.set_line_cap(cairo.LINE_CAP_BUTT)
        self.ctx.set_line_width(w)
        if closed:
            self._path(pts)
        else:
            self.ctx.move_to(*pts[0])
            for p in pts[1:]:
                self.ctx.line_to(*p)
        self._set(rgb)
        self.ctx.stroke()

    def hatch(self, region: Sequence[Pt], angle: float, spacing: float, w: float = 0.8, rgb=INK,
              cross: bool = False, jitter: float = 0.0, seed: int = 0) -> None:
        """Trama de líneas paralelas (y cruzadas) dentro de `region`."""
        rnd = random.Random(seed)
        xs = [p[0] for p in region]
        ys = [p[1] for p in region]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        r = math.hypot(max(xs) - min(xs), max(ys) - min(ys)) / 2 + 2
        self.ctx.save()
        self._path(region)
        self.ctx.clip()
        for ang in ([angle, angle + math.pi / 2.6] if cross else [angle]):
            ux, uy = math.cos(ang), math.sin(ang)
            nx, ny = -uy, ux
            o = -r
            while o <= r:
                oo = o + rnd.uniform(-jitter, jitter)
                a = (cx + nx * oo - ux * r, cy + ny * oo - uy * r)
                b = (cx + nx * oo + ux * r, cy + ny * oo + uy * r)
                self.line([a, b], w, w, rgb, taper=False)
                o += spacing
        self.ctx.restore()

    def stipple(self, region: Sequence[Pt], density: float, size: float, rgb, seed: int = 0) -> None:
        rnd = random.Random(seed)
        xs = [p[0] for p in region]
        ys = [p[1] for p in region]
        area = (max(xs) - min(xs)) * (max(ys) - min(ys))
        self.ctx.save()
        self._path(region)
        self.ctx.clip()
        self._set(rgb)
        for _ in range(int(area * density)):
            x, y = rnd.uniform(min(xs), max(xs)), rnd.uniform(min(ys), max(ys))
            self.ctx.rectangle(x, y, size, size)
        self.ctx.fill()
        self.ctx.restore()

    def splat(self, c: Pt, r: float, rgb, seed: int, spikes: int = 11, drips: int = 0, drip_len: float = 1.0,
              clip: Sequence[Pt] | None = None, ink: bool = False) -> list[Pt]:
        """Mancha plana de borde irregular, con regueros hacia abajo."""
        rnd = random.Random(seed)
        pts = []
        for i in range(spikes):
            a = i / spikes * 2 * math.pi + rnd.uniform(-0.2, 0.2)
            rr = r * rnd.uniform(0.55, 1.15)
            pts.append((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr * 0.8))
        if clip is not None:
            self.ctx.save()
            self._path(clip)
            self.ctx.clip()
        self.fill(pts, rgb)
        for _ in range(drips):
            x = c[0] + rnd.uniform(-r * 0.6, r * 0.6)
            y0 = c[1] + r * 0.3
            ln = r * rnd.uniform(1.0, 3.0) * drip_len
            wd = rnd.uniform(1.2, 2.4)
            self.fill([(x - wd / 2, y0), (x + wd / 2, y0), (x + wd * 0.4, y0 + ln), (x + 0.2, y0 + ln + wd),
                       (x - wd * 0.4, y0 + ln)], rgb)
        if ink:
            self.poly_line(pts, 0.7)
        if clip is not None:
            self.ctx.restore()
        return pts

    # --- salida ---
    def hires(self) -> np.ndarray:
        self.surf.flush()
        a = np.frombuffer(self.surf.get_data(), np.uint8).reshape(self.h * self.k, self.surf.get_stride() // 4, 4)
        a = a[:, : self.w * self.k]
        return np.dstack([a[..., 2], a[..., 1], a[..., 0], a[..., 3]])

    def render(self, ink_share: float = 0.3, outline: bool = True) -> Image.Image:
        """Reducción por bloques sin mezclar colores: tinta si hay bastante; si no, el más frecuente."""
        hi = self.hires()
        k = self.k
        H, W = self.h, self.w
        flat = hi.reshape(H * k, W * k, 4)
        code = (flat[..., 0].astype(np.int64) << 24) | (flat[..., 1].astype(np.int64) << 16) | \
               (flat[..., 2].astype(np.int64) << 8) | (flat[..., 3] > 127).astype(np.int64)
        blocks = code.reshape(H, k, W, k).transpose(0, 2, 1, 3).reshape(H, W, k * k)
        ink_code = (INK[0] << 24) | (INK[1] << 16) | (INK[2] << 8) | 1
        is_ink = (blocks == ink_code).mean(-1) >= ink_share
        srt = np.sort(blocks, -1)
        # moda por bloque
        change = np.concatenate([np.ones(srt.shape[:-1] + (1,), bool), srt[..., 1:] != srt[..., :-1]], -1)
        idx = np.cumsum(change, -1)
        best = np.zeros((H, W), np.int64)
        bestn = np.zeros((H, W), np.int64)
        for j in range(1, k * k + 1):
            cnt = (idx == j).sum(-1)
            val = np.where(cnt > 0, np.max(np.where(idx == j, srt, -1), -1), 0)
            better = cnt > bestn
            best[better] = val[better]
            bestn[better] = cnt[better]
        best[is_ink] = ink_code
        out = np.zeros((H, W, 4), np.uint8)
        out[..., 0] = (best >> 24) & 255
        out[..., 1] = (best >> 16) & 255
        out[..., 2] = (best >> 8) & 255
        out[..., 3] = (best & 1) * 255
        if outline:
            from scipy import ndimage
            op = out[..., 3] > 0
            ring = ndimage.binary_dilation(op, [[0, 1, 0], [1, 1, 1], [0, 1, 0]]) & ~op
            # el contorno exterior ya va dibujado; esto solo cierra huecos de un píxel
            near_ink = ndimage.binary_dilation(np.all(out[..., :3] == INK, -1) & op, np.ones((3, 3)))
            fix = ring & ~near_ink
            out[fix, :3] = INK
            out[fix, 3] = 255
        return Image.fromarray(out, "RGBA")


# --- geometría ---------------------------------------------------------------------------

def lerp(a: Pt, b: Pt, t: float) -> Pt:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def edges(joints: Sequence[Pt], widths: Sequence[tuple[float, float]]) -> tuple[list[Pt], list[Pt]]:
    """Bordes izquierdo y derecho (respecto al sentido del miembro) de un miembro anguloso."""
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
    return left, right


def jag(a: Pt, b: Pt, n: int, amp: float, seed: int) -> list[Pt]:
    """Línea quebrada de a a b (n tramos), para bordes rasgados y sombras de borde nervioso."""
    rnd = random.Random(seed)
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy) or 1
    nx, ny = -dy / ln, dx / ln
    out = [a]
    for i in range(1, n):
        t = i / n
        o = rnd.uniform(-amp, amp)
        out.append((a[0] + dx * t + nx * o, a[1] + dy * t + ny * o))
    out.append(b)
    return out


def offset_line(pts: Sequence[Pt], d: float) -> list[Pt]:
    out = []
    n = len(pts)
    for i, p in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(n - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1
        out.append((p[0] - dy / ln * d, p[1] + dx / ln * d))
    return out
