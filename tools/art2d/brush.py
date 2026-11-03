"""brush: pintura a pinceladas sobre dibujo a tinta (quinta muestra, cerca de *Fear & Hunger*).

Cómo se pinta una figura (todo 2D):
1. **Formas orgánicas**: cada forma es una curva suave que pasa por muchos puntos dados a mano, con un
   ruido de baja frecuencia en el borde (`wobble`) para el trazo nervioso. Se rasteriza a ×k con cairo.
2. **Mapa de valor** por forma: de dónde viene la luz (lateral, fría) y dónde cae la sombra, sacado de la
   propia silueta (`light_field`) y de manchas de sombra dibujadas a mano (`dark`, `lift`). El terminador se
   aprieta (`contrast`) para que el lado oscuro sea casi negro.
3. **Pinceladas**: la forma se cubre con miles de trazos cortos en forma de hoja (`strokes`), orientados
   según un campo de dirección (el eje del músculo, la caída del pliegue), con el color de la rampa del
   material en ese valor (5-8 tonos) y algo de variación. Primero una mano de fondo plana, luego las
   pinceladas. Así el volumen se lee por el valor, pero con textura de pintura, no de aerógrafo.
4. **Tinta**: contorno y líneas interiores con trazo nervioso (`ink`), acentos oscuros en pliegues y
   uniones, brillos pequeños y nítidos en aristas (`glint`), y micro-detalle (venas, vello, costuras,
   puntos, grietas, sangre con coágulos y regueros).
5. **Reducción**: filtro de área a la resolución final y **cuantización a la paleta** del juego sin
   tramado (ningún color fuera de paleta), contorno exterior oscuro de 1 px y limpieza de píxeles sueltos.
"""

from __future__ import annotations

import math
import random
from typing import Callable, Sequence

import cairo
import numpy as np
from PIL import Image
from scipy import ndimage

Pt = tuple[float, float]


def hexrgb(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


RAMPS: dict[str, np.ndarray] = {}


def ramp(name: str, keys: Sequence[str]) -> None:
    RAMPS[name] = np.stack([hexrgb(k) for k in keys])


def rcol(name: str, v: float) -> np.ndarray:
    """Color de la rampa en el valor v (0..1), escalonado a sus tonos (sin interpolar)."""
    r = RAMPS[name]
    i = int(round(max(0.0, min(1.0, v)) * (len(r) - 1)))
    return r[i]


def _smooth_closed(pts: Sequence[Pt], samples: int = 6) -> list[Pt]:
    """Catmull-Rom cerrada muestreada."""
    n = len(pts)
    out = []
    for i in range(n):
        p0, p1, p2, p3 = pts[(i - 1) % n], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        for s in range(samples):
            t = s / samples
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 +
                       (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 +
                       (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    return out


def _smooth_open(pts: Sequence[Pt], samples: int = 6) -> list[Pt]:
    n = len(pts)
    if n < 3:
        return list(pts)
    out = []
    for i in range(n - 1):
        p0 = pts[max(0, i - 1)]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[min(n - 1, i + 2)]
        for s in range(samples):
            t = s / samples
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 +
                       (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 +
                       (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    out.append(pts[-1])
    return out


def wobble(pts: Sequence[Pt], amp: float, seed: int, closed: bool = True, freq: float = 0.18) -> list[Pt]:
    """Desplaza la curva a lo largo de su normal con ruido de baja frecuencia (trazo nervioso)."""
    if amp <= 0:
        return list(pts)
    rnd = random.Random(seed)
    n = len(pts)
    ph = [rnd.uniform(0, 6.28) for _ in range(3)]
    acc = 0.0
    out = []
    for i, p in enumerate(pts):
        a = pts[(i - 1) % n] if closed else pts[max(0, i - 1)]
        b = pts[(i + 1) % n] if closed else pts[min(n - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1
        acc += ln / 2
        o = amp * (0.6 * math.sin(acc * freq + ph[0]) + 0.3 * math.sin(acc * freq * 2.3 + ph[1]) +
                   0.15 * math.sin(acc * freq * 5.1 + ph[2]))
        out.append((p[0] - dy / ln * o, p[1] + dx / ln * o))
    return out


class Canvas:
    def __init__(self, w: int, h: int, k: int = 4, view: tuple[float, float, float] = (1.0, 0.0, 0.0),
                 light: Pt = (-0.9, -0.42)) -> None:
        self.w, self.h, self.k = w, h, k
        self.W, self.H = w * k, h * k
        self.surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, self.W, self.H)
        self.ctx = cairo.Context(self.surf)
        self.s = k * view[0]
        self.ctx.scale(self.s, self.s)
        self.ctx.translate(-view[1], -view[2])
        self.view = view
        self.light = light
        self.ctx.set_line_join(cairo.LINE_JOIN_ROUND)

    # --- coordenadas ---
    def to_px(self, p: Pt) -> tuple[float, float]:
        return ((p[0] - self.view[1]) * self.s, (p[1] - self.view[2]) * self.s)

    # --- formas ---
    def path(self, pts: Sequence[Pt], smooth: bool = True, wob: float = 0.0, seed: int = 0) -> list[Pt]:
        q = _smooth_closed(pts) if smooth else list(pts)
        q = wobble(q, wob, seed) if wob else q
        self.ctx.new_path()
        self.ctx.move_to(*q[0])
        for p in q[1:]:
            self.ctx.line_to(*p)
        self.ctx.close_path()
        return q

    def mask(self, pts: Sequence[Pt], smooth: bool = True, wob: float = 0.0, seed: int = 0) -> np.ndarray:
        surf = cairo.ImageSurface(cairo.FORMAT_A8, self.W, self.H)
        c = cairo.Context(surf)
        c.scale(self.s, self.s)
        c.translate(-self.view[1], -self.view[2])
        q = _smooth_closed(pts) if smooth else list(pts)
        q = wobble(q, wob, seed) if wob else q
        c.move_to(*q[0])
        for p in q[1:]:
            c.line_to(*p)
        c.close_path()
        c.fill()
        surf.flush()
        a = np.frombuffer(surf.get_data(), np.uint8).reshape(self.H, surf.get_stride())[:, :self.W]
        return a.astype(np.float32) / 255

    def _rgb(self, c, a: float = 1.0) -> None:
        self.ctx.set_source_rgba(c[0] / 255, c[1] / 255, c[2] / 255, a)

    def fill(self, pts: Sequence[Pt], color, smooth: bool = True, wob: float = 0.0, seed: int = 0, a: float = 1.0) -> list[Pt]:
        q = self.path(pts, smooth, wob, seed)
        self._rgb(color, a)
        self.ctx.fill()
        return q

    # --- luz ---
    def light_field(self, m: np.ndarray, soft: float, light: Pt | None = None, lz: float = 0.18) -> np.ndarray:
        """Valor 0..1 de una forma según su silueta: el borde que mira a la luz, claro; el contrario,
        oscuro; el centro, medio. `soft` en px de diseño."""
        lx, ly = light or self.light
        sg = soft * self.s
        g = ndimage.gaussian_filter((m > 0.5).astype(np.float32), sg)
        gy, gx = np.gradient(g)
        mag = np.hypot(gx, gy)
        sl = np.clip(mag * sg * 2.5, 0, 1)
        nx = -gx / (mag + 1e-6) * sl
        ny = -gy / (mag + 1e-6) * sl
        nz = np.sqrt(np.clip(1 - sl * sl, 0, 1))
        ln = math.sqrt(lx * lx + ly * ly + lz * lz)
        lam = (nx * lx + ny * ly + nz * lz) / ln
        return np.clip(0.5 + 0.5 * lam, 0, 1)

    # --- pinceladas ---
    def strokes(self, m: np.ndarray, value: np.ndarray, rampname: str, angle: Callable[[float, float], float] | float,
                length: float = 5.0, width: float = 1.6, density: float = 0.55, jitter: float = 0.06,
                seed: int = 0, contrast: float = 1.0, base: float | None = None, clip_pts=None, alpha: float = 1.0) -> None:
        """Cubre la máscara `m` con pinceladas en forma de hoja. `value` (0..1) da el tono; `angle` es un
        ángulo fijo o una función (x, y) → ángulo en coordenadas de diseño."""
        rnd = random.Random(seed)
        rng = np.random.default_rng(seed)
        ys, xs = np.nonzero(m > 0.5)
        if len(xs) == 0:
            return
        area = len(xs) / (self.s * self.s)
        n = int(area * density / (length * width) * 4)
        idx = rng.integers(0, len(xs), n)
        if clip_pts is not None:
            self.ctx.save()
            self.path(clip_pts)
            self.ctx.clip()
        if base is not None:
            self.ctx.save()
        for j in idx:
            X, Y = xs[j], ys[j]
            x = X / self.s + self.view[1]
            y = Y / self.s + self.view[2]
            v = float(value[Y, X])
            v = 0.5 + (v - 0.5) * contrast + rnd.uniform(-jitter, jitter)
            col = rcol(rampname, v)
            a = angle(x, y) if callable(angle) else angle
            a += rnd.uniform(-0.25, 0.25)
            L = length * rnd.uniform(0.6, 1.3)
            Wd = width * rnd.uniform(0.7, 1.2)
            ux, uy = math.cos(a), math.sin(a)
            nx, ny = -uy, ux
            p0 = (x - ux * L / 2, y - uy * L / 2)
            p1 = (x + ux * L / 2, y + uy * L / 2)
            self.ctx.new_path()
            self.ctx.move_to(*p0)
            self.ctx.curve_to(x - ux * L / 4 + nx * Wd, y - uy * L / 4 + ny * Wd, x + ux * L / 4 + nx * Wd,
                              y + uy * L / 4 + ny * Wd, *p1)
            self.ctx.curve_to(x + ux * L / 4 - nx * Wd, y + uy * L / 4 - ny * Wd, x - ux * L / 4 - nx * Wd,
                              y - uy * L / 4 - ny * Wd, *p0)
            self._rgb(col, alpha)
            self.ctx.fill()
        if base is not None:
            self.ctx.restore()
        if clip_pts is not None:
            self.ctx.restore()

    def paint(self, pts: Sequence[Pt], rampname: str, angle, seed: int, soft: float = 10.0, base: float = 0.5,
              contrast: float = 1.6, length: float = 5.0, width: float = 1.5, density: float = 0.6, wob: float = 0.8,
              extra: np.ndarray | None = None, light: Pt | None = None, jitter: float = 0.07,
              side: float = 0.3) -> tuple[list[Pt], np.ndarray]:
        """Forma completa: mano de fondo, campo de valor de su silueta y pinceladas recortadas a ella."""
        m = self.mask(pts, wob=wob, seed=seed)
        val = self.light_field(m, soft, light) * 0.9 + base - 0.45
        if side:
            # la luz lateral: la mitad de la forma que mira a la luz, clara; la otra, hacia la sombra
            ys, xs = np.nonzero(m > 0.5)
            if len(xs):
                cxh, hw = (xs.min() + xs.max()) / 2, max(1.0, (xs.max() - xs.min()) / 2)
                lx = (light or self.light)[0]
                xx = np.arange(self.W, dtype=np.float32)[None, :]
                val = val + side * np.clip((xx - cxh) / hw * (1 if lx < 0 else -1), -1, 1) * -1
        if extra is not None:
            val = val + extra
        val = np.clip(val, 0, 1)
        q = self.fill(pts, rcol(rampname, base - 0.08), wob=wob, seed=seed)
        self.ctx.save()
        self.path(pts, wob=wob, seed=seed)
        self.ctx.clip()
        self.strokes(m, val, rampname, angle, length, width, density, jitter, seed + 1, contrast)
        self.ctx.restore()
        return q, m

    def clip(self, pts, wob: float = 0.0, seed: int = 0):
        """Contexto: recorta a una forma (para pintar sombras y detalles que no se salgan)."""
        canvas = self

        class _C:
            def __enter__(self_inner):
                canvas.ctx.save()
                canvas.path(pts, wob=wob, seed=seed)
                canvas.ctx.clip()

            def __exit__(self_inner, *a):
                canvas.ctx.restore()
        return _C()

    def scumble(self, pts, rampname: str, v: float, angle, seed: int, length: float = 4.0, width: float = 1.2,
                density: float = 0.5, jitter: float = 0.05, wob: float = 0.6, smooth: bool = True) -> None:
        """Mancha de sombra o de luz pintada a pinceladas (borde semiduro), dentro de lo ya recortado."""
        m = self.mask(pts, smooth, wob, seed)
        val = np.full_like(m, v)
        self.strokes(m, val, rampname, angle, length, width, density, jitter, seed)

    # --- tinta y detalle ---
    def ink(self, pts: Sequence[Pt], w0: float = 1.2, w1: float | None = None, color=(18, 12, 12), smooth: bool = True,
            wob: float = 0.4, seed: int = 0, a: float = 1.0, taper: float = 0.35) -> None:
        """Trazo de tinta de grosor variable con temblor; afilado en las puntas."""
        q = _smooth_open(pts, 4) if smooth and len(pts) > 2 else list(pts)
        q = wobble(q, wob, seed, closed=False, freq=0.5) if wob else q
        w1 = w0 if w1 is None else w1
        n = len(q)
        if n < 2:
            return
        left, right = [], []
        rnd = random.Random(seed)
        for i, p in enumerate(q):
            a_ = q[max(0, i - 1)]
            b_ = q[min(n - 1, i + 1)]
            dx, dy = b_[0] - a_[0], b_[1] - a_[1]
            ln = math.hypot(dx, dy) or 1
            nx, ny = -dy / ln, dx / ln
            t = i / (n - 1)
            wd = (w0 + (w1 - w0) * t) / 2 * rnd.uniform(0.8, 1.15)
            edge = min(t, 1 - t)
            if edge < 0.15:
                wd *= taper + (1 - taper) * edge / 0.15
            left.append((p[0] + nx * wd, p[1] + ny * wd))
            right.append((p[0] - nx * wd, p[1] - ny * wd))
        self.ctx.new_path()
        self.ctx.move_to(*left[0])
        for p in left[1:] + right[::-1]:
            self.ctx.line_to(*p)
        self.ctx.close_path()
        self._rgb(color, a)
        self.ctx.fill()

    def outline(self, q: Sequence[Pt], w: float = 1.6, color=(18, 12, 12), seed: int = 0) -> None:
        """Contorno de tinta de una forma ya trazada (puntos de `fill`/`paint`), con grosor que varía."""
        n = len(q)
        step = max(8, n // 10)
        rnd = random.Random(seed)
        for i in range(0, n, step):
            seg = [q[(i + j) % n] for j in range(step + 2)]
            self.ink(seg, w * rnd.uniform(0.8, 1.25), w * rnd.uniform(0.7, 1.2), color, smooth=False, wob=0.0,
                     seed=seed + i, taper=0.8)

    def glint(self, pts: Sequence[Pt], color, w: float = 0.8) -> None:
        """Brillo pequeño y nítido en una arista."""
        self.ink(pts, w, w * 0.4, color, wob=0.0, taper=0.2)

    def dots(self, pts: Sequence[Pt], color, r: float = 0.5) -> None:
        self._rgb(color)
        for x, y in pts:
            self.ctx.new_path()
            self.ctx.rectangle(x - r, y - r, 2 * r, 2 * r)
            self.ctx.fill()

    def blood(self, c: Pt, r: float, seed: int, ramp_name: str = "blood", drips: int = 2, down: float = 1.0,
              wet: bool = True) -> None:
        """Mancha de sangre: borde irregular, coágulo oscuro dentro, regueros que bajan, brillo húmedo."""
        rnd = random.Random(seed)
        pts = []
        for i in range(14):
            a = i / 14 * 2 * math.pi
            rr = r * rnd.uniform(0.5, 1.15)
            pts.append((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr * 0.85))
        self.fill(pts, rcol(ramp_name, 0.45), wob=0.0)
        self.fill([(c[0] + (x - c[0]) * 0.5 + rnd.uniform(-1, 1), c[1] + (y - c[1]) * 0.5) for x, y in pts], rcol(ramp_name, 0.15))
        for _ in range(drips):
            x = c[0] + rnd.uniform(-r * 0.6, r * 0.6)
            y0 = c[1] + r * 0.2
            ln = r * rnd.uniform(1.2, 3.5) * down
            path = [(x, y0), (x + rnd.uniform(-1, 1), y0 + ln * 0.5), (x + rnd.uniform(-1.5, 1.5), y0 + ln)]
            self.ink(path, rnd.uniform(1.0, 1.8), 1.4, rcol(ramp_name, 0.35), wob=0.3, seed=seed + 7, taper=0.6)
            self.fill([(path[-1][0] - 1.1, path[-1][1]), (path[-1][0] + 1.1, path[-1][1]), (path[-1][0], path[-1][1] + 2.0)],
                      rcol(ramp_name, 0.3), smooth=True)
        if wet:
            self.glint([(c[0] - r * 0.3, c[1] - r * 0.3), (c[0] - r * 0.05, c[1] - r * 0.4)], rcol(ramp_name, 1.0), 0.7)

    # --- salida ---
    def render(self, pal: np.ndarray, outline_col=(18, 12, 12)) -> Image.Image:
        self.surf.flush()
        a = np.frombuffer(self.surf.get_data(), np.uint8).reshape(self.H, self.surf.get_stride() // 4, 4)[:, :self.W]
        rgba = np.dstack([a[..., 2], a[..., 1], a[..., 0], a[..., 3]]).astype(np.float32)
        k = self.k
        al = rgba[..., 3] / 255
        prem = rgba[..., :3]          # cairo guarda premultiplicado
        small = prem.reshape(self.h, k, self.w, k, 3).mean((1, 3))
        alpha = al.reshape(self.h, k, self.w, k).mean((1, 3))
        col = small / np.maximum(alpha[..., None], 1e-6)
        op = alpha > 0.5
        nb = ndimage.convolve(op.astype(np.int32), np.ones((3, 3), np.int32), mode="constant") - op
        op = (op & (nb >= 2)) | (~op & (nb >= 7))
        flat = col.reshape(-1, 3)
        d = ((flat[:, None, :] - pal[None, :, :]) ** 2 * np.array([0.3, 0.59, 0.11])).sum(-1)
        q = pal[d.argmin(1)].reshape(self.h, self.w, 3)
        out = np.zeros((self.h, self.w, 4), np.uint8)
        out[op, :3] = q[op].astype(np.uint8)
        out[op, 3] = 255
        ring = ndimage.binary_dilation(op, [[0, 1, 0], [1, 1, 1], [0, 1, 0]]) & ~op
        out[ring, :3] = outline_col
        out[ring, 3] = 255
        return Image.fromarray(out, "RGBA")


def build_palette(names: Sequence[str]) -> np.ndarray:
    return np.concatenate([RAMPS[n] for n in names], 0)


def lerp(a: Pt, b: Pt, t: float) -> Pt:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def along(a: Pt, b: Pt) -> float:
    return math.atan2(b[1] - a[1], a[0] - a[0] + (b[0] - a[0]))


def limb_pts(joints: Sequence[Pt], left: Sequence[float], right: Sequence[float]) -> list[Pt]:
    """Contorno de un miembro con muchas inflexiones: para cada articulación/estación, cuánto sale la
    silueta a cada lado (perfil anatómico medido a mano)."""
    L, R = [], []
    n = len(joints)
    for i, p in enumerate(joints):
        a = joints[max(0, i - 1)]
        b = joints[min(n - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1
        nx, ny = dy / ln, -dx / ln
        L.append((p[0] + nx * left[i], p[1] + ny * left[i]))
        R.append((p[0] - nx * right[i], p[1] - ny * right[i]))
    return L + R[::-1]


def polyline_interp(pts: Sequence[Pt], n: int) -> list[Pt]:
    """Reparte n estaciones a lo largo de una polilínea (para los perfiles de los miembros)."""
    seg = [math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts, pts[1:])]
    tot = sum(seg)
    out = []
    for i in range(n):
        d = tot * i / (n - 1)
        acc = 0
        for j, s in enumerate(seg):
            if acc + s >= d or j == len(seg) - 1:
                t = (d - acc) / s if s else 0
                out.append(lerp(pts[j], pts[j + 1], min(1, t)))
                break
            acc += s
    return out
