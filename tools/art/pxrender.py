"""Mini renderizador de pixel art con volumen (Python puro, sin dependencias salvo Pillow).

Modelas un objeto con primitivas 3D (esferas, elipsoides, cápsulas, cilindros, cajas),
cada una con una función de material. El render:
  1. lanza rayos paralelos con proyección oblicua (la de los mapas tipo RPG Maker:
     las alturas suben en pantalla y la profundidad del suelo baja),
  2. sombrea con una luz fija suave,
  3. reduce cada material a una rampa de pocos colores con tramado ordenado,
  4. añade contorno de color y devuelve también el MAPA DE NORMALES para que
     las luces 2D de Godot iluminen el relieve.

Coordenadas del modelo: x derecha, y arriba, z hacia el espectador. 1 unidad = 1 px.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Callable, Optional

from PIL import Image

try:  # numpy acelera mucho el trazado de rayos (opcional: sin él se usa Python puro)
    import numpy as np
except ImportError:  # pragma: no cover
    np = None

Vec = tuple[float, float, float]


# --- vectores ----------------------------------------------------------------

def add(a: Vec, b: Vec) -> Vec:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a: Vec, b: Vec) -> Vec:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def mul(a: Vec, s: float) -> Vec:
    return (a[0] * s, a[1] * s, a[2] * s)


def dot(a: Vec, b: Vec) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a: Vec, b: Vec) -> Vec:
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def length(a: Vec) -> float:
    return math.sqrt(dot(a, a))


def norm(a: Vec) -> Vec:
    l = length(a)
    return (0.0, 0.0, 1.0) if l == 0 else (a[0] / l, a[1] / l, a[2] / l)


def lerp(a: Vec, b: Vec, t: float) -> Vec:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def rot_x(v: Vec, ang: float) -> Vec:
    c, s = math.cos(ang), math.sin(ang)
    return (v[0], v[1] * c - v[2] * s, v[1] * s + v[2] * c)


def rot_y(v: Vec, ang: float) -> Vec:
    c, s = math.cos(ang), math.sin(ang)
    return (v[0] * c + v[2] * s, v[1], -v[0] * s + v[2] * c)


def rot_z(v: Vec, ang: float) -> Vec:
    c, s = math.cos(ang), math.sin(ang)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c, v[2])


Mat3 = tuple[Vec, Vec, Vec]  # columnas: ejes locales x, y, z expresados en mundo
IDENTITY: Mat3 = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))


def basis_from_y(y_axis: Vec, hint: Vec = (0.0, 0.0, 1.0)) -> Mat3:
    """Base ortonormal cuyo eje Y local apunta a `y_axis`."""
    y = norm(y_axis)
    if abs(dot(y, hint)) > 0.95:
        hint = (1.0, 0.0, 0.0)
    x = norm(cross(y, hint))
    z = cross(x, y)
    return (x, y, z)


def basis_rot(rx: float = 0.0, ry: float = 0.0, rz: float = 0.0) -> Mat3:
    axes = []
    for v in ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)):
        axes.append(rot_y(rot_x(rot_z(v, rz), rx), ry))
    return (axes[0], axes[1], axes[2])


def to_local(m: Mat3, v: Vec) -> Vec:
    return (dot(v, m[0]), dot(v, m[1]), dot(v, m[2]))


def to_world(m: Mat3, v: Vec) -> Vec:
    return add(add(mul(m[0], v[0]), mul(m[1], v[1])), mul(m[2], v[2]))


# --- ruido ---------------------------------------------------------------------

def _hash3(x: int, y: int, z: int, seed: int) -> float:
    h = (x * 374761393 + y * 668265263 + z * 2147483647 + seed * 144269504) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def vnoise(p: Vec, seed: int = 0) -> float:
    """Ruido de valor 3D suave en [0, 1]."""
    return _vnoise(p[0], p[1], p[2], seed)


def _vnoise(x: float, y: float, z: float, seed: int) -> float:
    # Igual que _hash3 en las 8 esquinas, desenrollado (es lo que más tiempo se lleva al renderizar).
    xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
    fx, fy, fz = x - xi, y - yi, z - zi
    fx, fy, fz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
    hx0 = xi * 374761393
    hx1 = hx0 + 374761393
    hy0 = yi * 668265263
    hy1 = hy0 + 668265263
    hz0 = zi * 2147483647 + seed * 144269504
    hz1 = hz0 + 2147483647

    def h(v: int) -> float:
        v &= 0xFFFFFFFF
        v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
        return ((v ^ (v >> 16)) & 0xFFFF) / 65535.0

    gx, gy, gz = 1 - fx, 1 - fy, 1 - fz
    return (gz * (gy * (gx * h(hx0 + hy0 + hz0) + fx * h(hx1 + hy0 + hz0))
                  + fy * (gx * h(hx0 + hy1 + hz0) + fx * h(hx1 + hy1 + hz0)))
            + fz * (gy * (gx * h(hx0 + hy0 + hz1) + fx * h(hx1 + hy0 + hz1))
                    + fy * (gx * h(hx0 + hy1 + hz1) + fx * h(hx1 + hy1 + hz1))))


def fbm(p: Vec, seed: int = 0, octaves: int = 3) -> float:
    total, amp, freq, norm_sum = 0.0, 1.0, 1.0, 0.0
    x, y, z = p
    for i in range(octaves):
        total += amp * _vnoise(x * freq, y * freq, z * freq, seed + i * 17)
        norm_sum += amp
        amp *= 0.5
        freq *= 2.03
    return total / norm_sum


# --- rampas de color (oscuro → claro) ---------------------------------------

RAMPS: dict[str, list[tuple[int, int, int]]] = {}


def ramp(name: str, colors: list[tuple[int, int, int]]) -> None:
    RAMPS[name] = colors


OUTLINE = (14, 10, 18)


# --- primitivas -------------------------------------------------------------------

@dataclass
class Hit:
    t: float
    normal: Vec


MaterialFn = Callable[[Vec, Vec], tuple]  # (p, n) -> (rampa, brillo[, normal[, especular]])


@dataclass
class Prim:
    material: MaterialFn
    cut: Optional[Callable[[Vec], bool]] = None  # True = agujero en ese punto
    center: Vec = (0.0, 0.0, 0.0)
    bound: float = 1.0
    tag: str = ""

    def intersect(self, o: Vec, d: Vec) -> Optional[Hit]:
        raise NotImplementedError


@dataclass
class Ellipsoid(Prim):
    radii: Vec = (1.0, 1.0, 1.0)
    basis: Mat3 = IDENTITY

    def __post_init__(self) -> None:
        self.bound = max(self.radii) + 0.5

    def intersect(self, o: Vec, d: Vec) -> Optional[Hit]:
        rel = sub(o, self.center)
        ol = to_local(self.basis, rel)
        dl = to_local(self.basis, d)
        ol = (ol[0] / self.radii[0], ol[1] / self.radii[1], ol[2] / self.radii[2])
        dl = (dl[0] / self.radii[0], dl[1] / self.radii[1], dl[2] / self.radii[2])
        a = dot(dl, dl)
        b = dot(ol, dl)
        c = dot(ol, ol) - 1.0
        h = b * b - a * c
        if h < 0:
            return None
        t = (-b - math.sqrt(h)) / a
        if t < 0:
            return None
        pl = add(ol, mul(dl, t))
        nl = (pl[0] / self.radii[0], pl[1] / self.radii[1], pl[2] / self.radii[2])
        return Hit(t, norm(to_world(self.basis, nl)))

    def intersect_np(self, o, d: Vec):
        """Versión vectorizada: `o` es un array (N, 3) de orígenes; devuelve (t, normales)."""
        m = np.array(self.basis).T  # columnas = ejes locales
        r = np.array(self.radii)
        ol = ((o - np.array(self.center)) @ m) / r
        dl = (np.array(d) @ m) / r
        a = float(dl @ dl)
        b = ol @ dl
        c = np.einsum("ij,ij->i", ol, ol) - 1.0
        h = b * b - a * c
        ok = h >= 0
        t = (-b - np.sqrt(np.where(ok, h, 0.0))) / a
        ok &= t >= 0
        nl = (ol + dl * t[:, None]) / r
        return np.where(ok, t, np.inf), _normalize(nl @ m.T)


def sphere(c: Vec, r: float, material: MaterialFn, **kw) -> Ellipsoid:
    return Ellipsoid(material=material, center=c, radii=(r, r, r), **kw)


def ellipsoid(c: Vec, radii: Vec, material: MaterialFn, basis: Mat3 = IDENTITY, **kw) -> Ellipsoid:
    return Ellipsoid(material=material, center=c, radii=radii, basis=basis, **kw)


@dataclass
class Capsule(Prim):
    a: Vec = (0.0, 0.0, 0.0)
    b: Vec = (0.0, 1.0, 0.0)
    r: float = 1.0

    def __post_init__(self) -> None:
        self.center = lerp(self.a, self.b, 0.5)
        self.bound = length(sub(self.b, self.a)) / 2 + self.r + 0.5

    def intersect(self, o: Vec, d: Vec) -> Optional[Hit]:
        ba = sub(self.b, self.a)
        oa = sub(o, self.a)
        baba = dot(ba, ba)
        bard = dot(ba, d)
        baoa = dot(ba, oa)
        rdoa = dot(d, oa)
        oaoa = dot(oa, oa)
        a = baba - bard * bard
        b = baba * rdoa - baoa * bard
        c = baba * oaoa - baoa * baoa - self.r * self.r * baba
        t = None
        if abs(a) > 1e-9:
            h = b * b - a * c
            if h >= 0:
                tt = (-b - math.sqrt(h)) / a
                y = baoa + tt * bard
                if 0 < y < baba:
                    t = tt
        if t is None:
            best = None
            for cap in (self.a, self.b):
                oc = sub(o, cap)
                bb = dot(d, oc)
                cc = dot(oc, oc) - self.r * self.r
                h = bb * bb - cc
                if h > 0:
                    tt = -bb - math.sqrt(h)
                    if tt > 0 and (best is None or tt < best):
                        best = tt
            t = best
        if t is None or t < 0:
            return None
        p = add(o, mul(d, t))
        pa = sub(p, self.a)
        hh = max(0.0, min(1.0, dot(pa, ba) / baba))
        return Hit(t, norm(sub(pa, mul(ba, hh))))

    def intersect_np(self, o, d: Vec):
        A, B, D = np.array(self.a), np.array(self.b), np.array(d)
        ba = B - A
        oa = o - A
        baba = float(ba @ ba)
        bard = float(ba @ D)
        baoa = oa @ ba
        rdoa = oa @ D
        oaoa = np.einsum("ij,ij->i", oa, oa)
        a = baba - bard * bard
        t_body = np.full(len(o), np.inf)
        if abs(a) > 1e-9:
            b = baba * rdoa - baoa * bard
            c = baba * oaoa - baoa * baoa - self.r * self.r * baba
            h = b * b - a * c
            ok = h >= 0
            tt = (-b - np.sqrt(np.where(ok, h, 0.0))) / a
            y = baoa + tt * bard
            ok &= (y > 0) & (y < baba)
            t_body = np.where(ok, tt, np.inf)
        t_cap = np.full(len(o), np.inf)
        for cap in (A, B):
            oc = o - cap
            bb = oc @ D
            cc = np.einsum("ij,ij->i", oc, oc) - self.r * self.r
            h = bb * bb - cc
            ok = h > 0
            tt = -bb - np.sqrt(np.where(ok, h, 0.0))
            ok &= tt > 0
            t_cap = np.where(ok, np.minimum(t_cap, tt), t_cap)
        # Las tapas solo cuentan donde el cuerpo no ha dado (como en la versión escalar).
        t = np.where(np.isfinite(t_body), t_body, t_cap)
        t = np.where(t >= 0, t, np.inf)
        p = o + np.outer(np.where(np.isfinite(t), t, 0.0), D)
        pa = p - A
        hh = np.clip((pa @ ba) / baba, 0.0, 1.0)
        return t, _normalize(pa - np.outer(hh, ba))


def capsule(a: Vec, b: Vec, r: float, material: MaterialFn, **kw) -> Capsule:
    return Capsule(material=material, a=a, b=b, r=r, **kw)


def limb(points: list[Vec], radii: list[float], material: MaterialFn, steps: int = 3, **kw) -> list[Capsule]:
    """Cadena de cápsulas con radio que va cambiando (miembros que se afinan)."""
    result: list[Capsule] = []
    for i in range(len(points) - 1):
        for s in range(steps):
            t0, t1 = s / steps, (s + 1) / steps
            r = radii[i] + (radii[i + 1] - radii[i]) * (t0 + t1) / 2
            result.append(capsule(lerp(points[i], points[i + 1], t0), lerp(points[i], points[i + 1], t1), r, material, **kw))
    return result


@dataclass
class Cylinder(Prim):
    a: Vec = (0.0, 0.0, 0.0)
    b: Vec = (0.0, 1.0, 0.0)
    r: float = 1.0

    def __post_init__(self) -> None:
        self.center = lerp(self.a, self.b, 0.5)
        self.bound = length(sub(self.b, self.a)) / 2 + self.r + 0.5

    def intersect(self, o: Vec, d: Vec) -> Optional[Hit]:
        ba = sub(self.b, self.a)
        oc = sub(o, self.a)
        baba = dot(ba, ba)
        bard = dot(ba, d)
        baoc = dot(ba, oc)
        k2 = baba - bard * bard
        k1 = baba * dot(oc, d) - baoc * bard
        k0 = baba * dot(oc, oc) - baoc * baoc - self.r * self.r * baba
        axis = mul(ba, 1 / math.sqrt(baba))
        if abs(k2) < 1e-9:
            # Rayo paralelo al eje: solo puede dar en una tapa.
            if k0 > 0:
                return None
            t = (0.0 - baoc) / bard if bard > 0 else (baba - baoc) / bard
            return Hit(t, mul(axis, -1.0 if bard > 0 else 1.0)) if t > 0 else None
        h = k1 * k1 - k2 * k0
        if h < 0:
            return None
        h = math.sqrt(h)
        t = (-k1 - h) / k2
        y = baoc + t * bard
        if 0 < y < baba and t > 0:
            n = sub(add(oc, mul(d, t)), mul(ba, y / baba))
            return Hit(t, norm(n))
        if abs(bard) < 1e-9:
            return None
        t = ((0.0 if y < 0 else baba) - baoc) / bard
        if t > 0 and abs(k1 + k2 * t) < h:
            return Hit(t, mul(axis, -1.0 if y < 0 else 1.0))
        return None

    def intersect_np(self, o, d: Vec):
        A, B, D = np.array(self.a), np.array(self.b), np.array(d)
        n = len(o)
        ba = B - A
        oc = o - A
        baba = float(ba @ ba)
        bard = float(ba @ D)
        baoc = oc @ ba
        k2 = baba - bard * bard
        k1 = baba * (oc @ D) - baoc * bard
        k0 = baba * np.einsum("ij,ij->i", oc, oc) - baoc * baoc - self.r * self.r * baba
        axis = ba / math.sqrt(baba)
        if abs(k2) < 1e-9:
            # Rayo paralelo al eje: solo puede dar en una tapa.
            t = ((0.0 - baoc) / bard) if bard > 0 else ((baba - baoc) / bard)
            ok = (k0 <= 0) & (t > 0)
            nrm = np.tile(axis * (-1.0 if bard > 0 else 1.0), (n, 1))
            return np.where(ok, t, np.inf), nrm
        h = k1 * k1 - k2 * k0
        ok = h >= 0
        h = np.sqrt(np.where(ok, h, 0.0))
        t = (-k1 - h) / k2
        y = baoc + t * bard
        side = ok & (y > 0) & (y < baba) & (t > 0)
        nrm = _normalize(oc + np.outer(t, D) - np.outer(y / baba, ba))
        result = np.where(side, t, np.inf)
        if abs(bard) >= 1e-9:
            tc = (np.where(y < 0, 0.0, baba) - baoc) / bard
            cap = ok & ~side & (tc > 0) & (np.abs(k1 + k2 * tc) < h)
            result = np.where(cap, tc, result)
            cap_n = np.outer(np.where(y < 0, -1.0, 1.0), axis)
            nrm = np.where(cap[:, None], cap_n, nrm)
        return result, nrm


def cylinder(a: Vec, b: Vec, r: float, material: MaterialFn, **kw) -> Cylinder:
    return Cylinder(material=material, a=a, b=b, r=r, **kw)


@dataclass
class Box(Prim):
    half: Vec = (1.0, 1.0, 1.0)
    basis: Mat3 = IDENTITY

    def __post_init__(self) -> None:
        self.bound = length(self.half) + 0.5

    def intersect(self, o: Vec, d: Vec) -> Optional[Hit]:
        ol = to_local(self.basis, sub(o, self.center))
        dl = to_local(self.basis, d)
        tmin, tmax = -1e9, 1e9
        axis_hit, sign_hit = 0, 1.0
        for i in range(3):
            if abs(dl[i]) < 1e-9:
                if abs(ol[i]) > self.half[i]:
                    return None
                continue
            t1 = (-self.half[i] - ol[i]) / dl[i]
            t2 = (self.half[i] - ol[i]) / dl[i]
            s = -1.0
            if t1 > t2:
                t1, t2 = t2, t1
                s = 1.0
            if t1 > tmin:
                tmin, axis_hit, sign_hit = t1, i, s
            tmax = min(tmax, t2)
            if tmin > tmax:
                return None
        if tmin < 0:
            return None
        nl = [0.0, 0.0, 0.0]
        nl[axis_hit] = sign_hit
        return Hit(tmin, to_world(self.basis, (nl[0], nl[1], nl[2])))

    def intersect_np(self, o, d: Vec):
        m = np.array(self.basis).T
        ol = (o - np.array(self.center)) @ m
        dl = np.array(d) @ m
        n = len(o)
        tmin = np.full(n, -1e9)
        tmax = np.full(n, 1e9)
        axis_hit = np.zeros(n, dtype=int)
        sign_hit = np.ones(n)
        ok = np.ones(n, dtype=bool)
        for i in range(3):
            if abs(dl[i]) < 1e-9:
                ok &= np.abs(ol[:, i]) <= self.half[i]
                continue
            t1 = (-self.half[i] - ol[:, i]) / dl[i]
            t2 = (self.half[i] - ol[:, i]) / dl[i]
            s = 1.0 if dl[i] < 0 else -1.0  # dl es igual en todos los rayos: el orden de t1 y t2 también
            lo, hi = (t1, t2) if s < 0 else (t2, t1)
            better = lo > tmin
            tmin = np.where(better, lo, tmin)
            axis_hit = np.where(better, i, axis_hit)
            sign_hit = np.where(better, s, sign_hit)
            tmax = np.minimum(tmax, hi)
        ok &= (tmin <= tmax) & (tmin >= 0)
        nl = np.zeros((n, 3))
        nl[np.arange(n), axis_hit] = sign_hit
        return np.where(ok, tmin, np.inf), nl @ m.T


def box(c: Vec, half: Vec, material: MaterialFn, basis: Mat3 = IDENTITY, **kw) -> Box:
    return Box(material=material, center=c, half=half, basis=basis, **kw)


# --- render ----------------------------------------------------------------------

BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


@dataclass
class View:
    """Proyección oblicua: v_pantalla = a*y - b*z. `yaw` gira el modelo."""
    a: float = 1.0
    b: float = 0.45
    yaw: float = 0.0
    light: Vec = (-0.45, 0.7, 0.55)
    ambient: float = 0.38
    dither: float = 0.55
    ss: int = 3
    # Contorno de color alrededor de la silueta (personajes). Los objetos del mapa lo
    # desactivan: un borde oscuro los recorta del suelo y parecen pegatinas.
    outline: bool = True


@dataclass
class RenderResult:
    color: Image.Image
    normal: Image.Image
    depth: list = field(default_factory=list)

    def glow(self) -> Image.Image:
        """Solo los píxeles de materiales emisivos (rampa con "!"), para una capa sin sombra."""
        img = Image.new("RGBA", self.color.size, (0, 0, 0, 0))
        w = self.color.width
        for i, cell in enumerate(self.depth):
            if cell is not None and cell[0].startswith("!"):
                img.putpixel((i % w, i // w), self.color.getpixel((i % w, i // w)))
        return img


def transform(prims: list["Prim"], basis: Mat3, offset: Vec) -> list["Prim"]:
    """Gira (`basis`) y desplaza un grupo de primitivas. Las texturas siguen
    calculándose en las coordenadas originales del modelo."""
    import copy

    def fwd(v: Vec) -> Vec:
        return add(to_world(basis, v), offset)

    def back(v: Vec) -> Vec:
        return to_local(basis, sub(v, offset))

    result = []
    for prim in prims:
        q = copy.copy(prim)
        q.center = fwd(prim.center)
        if hasattr(prim, "a"):
            q.a = fwd(prim.a)
            q.b = fwd(prim.b)
        if hasattr(prim, "basis"):
            q.basis = tuple(to_world(basis, axis) for axis in prim.basis)
        mat = prim.material

        def wrapped(p: Vec, n: Vec, _mat=mat) -> tuple:
            r = _mat(back(p), to_local(basis, n))
            if len(r) > 2 and r[2] is not None:
                return (r[0], r[1], to_world(basis, r[2])) + tuple(r[3:])
            return (r[0], r[1], None) + tuple(r[3:])

        q.material = wrapped
        if prim.cut is not None:
            q.cut = lambda p, _cut=prim.cut: _cut(back(p))
        result.append(q)
    return result


def render(prims: list[Prim], width: int, height: int, origin: tuple[float, float], view: View) -> RenderResult:
    """Renderiza `prims` en una imagen de `width`x`height`. `origin` es el píxel donde cae (0,0,0)."""
    ss = view.ss
    d_world = norm((0.0, -view.b, -view.a))
    up_s = norm((0.0, view.a, -view.b))
    view_dir = norm((0.0, view.b, view.a))
    light = norm(view.light)
    half = norm(add(light, view_dir))  # brillo especular (Blinn-Phong)
    yaw = view.yaw
    # Al girar el modelo con yaw, giramos la cámara al revés.
    d_local = rot_y(d_world, -yaw)
    W, H = width * ss, height * ss
    ox, oy = origin
    if np is not None:
        best_t, best_i, best_n, best_p = _trace_np(prims, W, H, ss, ox, oy, view, d_world, d_local)
    else:
        best_t, best_i, best_n, best_p = _trace_py(prims, W, H, ss, ox, oy, view, d_world, d_local)
    return _shade(prims, best_t, best_i, best_n, best_p, width, height, view, light, half, up_s, view_dir)


def _normalize(v):
    length_ = np.sqrt(np.einsum("ij,ij->i", v, v))
    return v / np.where(length_ > 0, length_, 1.0)[:, None]


def _prim_rect(prim: Prim, W: int, H: int, ss: int, ox: float, oy: float, view: View) -> tuple[int, int, int, int]:
    cw = rot_y(prim.center, view.yaw)
    su = cw[0]
    sv = view.a * cw[1] - view.b * cw[2]
    rad = prim.bound * max(1.0, math.hypot(view.a, view.b))
    x0 = max(0, int((ox + su - rad) * ss))
    x1 = min(W - 1, int((ox + su + rad) * ss) + 1)
    y0 = max(0, int((oy - sv - rad) * ss))
    y1 = min(H - 1, int((oy - sv + rad) * ss) + 1)
    return x0, x1, y0, y1


def _trace_np(prims: list[Prim], W: int, H: int, ss: int, ox: float, oy: float, view: View, d_world: Vec,
              d_local: Vec) -> tuple[list, list, list, list]:
    """Trazado vectorizado: todos los rayos del rectángulo de cada primitiva a la vez."""
    best_t = np.full(W * H, 1e9)
    best_i = np.full(W * H, -1, dtype=np.int64)
    best_n = np.zeros((W * H, 3))
    best_p = np.zeros((W * H, 3))
    c, s = math.cos(-view.yaw), math.sin(-view.yaw)
    dw = np.array(d_world)
    for index, prim in enumerate(prims):
        x0, x1, y0, y1 = _prim_rect(prim, W, H, ss, ox, oy, view)
        if x1 < x0 or y1 < y0:
            continue
        sx, sy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        sx, sy = sx.ravel(), sy.ravel()
        u = (sx + 0.5) / ss - ox
        v = oy - (sy + 0.5) / ss
        ow = np.stack([u, v / view.a, np.zeros_like(u)], axis=1) - dw * 300.0
        o_local = np.stack([ow[:, 0] * c + ow[:, 2] * s, ow[:, 1], -ow[:, 0] * s + ow[:, 2] * c], axis=1)
        t, n = prim.intersect_np(o_local, d_local)
        k = sy * W + sx
        mask = t < best_t[k]
        if not mask.any():
            continue
        k, t, n, o_local = k[mask], t[mask], n[mask], o_local[mask]
        p = o_local + np.outer(t, d_local)
        if prim.cut is not None:
            keep = np.fromiter((not prim.cut(tuple(q)) for q in p.tolist()), dtype=bool, count=len(p))
            k, t, n, p = k[keep], t[keep], n[keep], p[keep]
        best_t[k] = t
        best_i[k] = index
        best_n[k] = n
        best_p[k] = p
    return (best_t.tolist(), best_i.tolist(), [tuple(v) for v in best_n.tolist()],
            [tuple(v) for v in best_p.tolist()])


def _trace_py(prims: list[Prim], W: int, H: int, ss: int, ox: float, oy: float, view: View, d_world: Vec,
              d_local: Vec) -> tuple[list, list, list, list]:
    yaw = view.yaw
    best_t = [1e9] * (W * H)
    best_i = [-1] * (W * H)
    best_n: list[Optional[Vec]] = [None] * (W * H)
    best_p: list[Optional[Vec]] = [None] * (W * H)
    for index, prim in enumerate(prims):
        cw = rot_y(prim.center, yaw)
        su = cw[0]
        sv = view.a * cw[1] - view.b * cw[2]
        rad = prim.bound * max(1.0, math.hypot(view.a, view.b))
        x0 = max(0, int((ox + su - rad) * ss))
        x1 = min(W - 1, int((ox + su + rad) * ss) + 1)
        y0 = max(0, int((oy - sv - rad) * ss))
        y1 = min(H - 1, int((oy - sv + rad) * ss) + 1)
        for sy in range(y0, y1 + 1):
            v = oy - (sy + 0.5) / ss
            for sx in range(x0, x1 + 1):
                u = (sx + 0.5) / ss - ox
                o_world = sub((u, v / view.a, 0.0), mul(d_world, 300.0))
                o_local = rot_y(o_world, -yaw)
                hit = prim.intersect(o_local, d_local)
                if hit is None:
                    continue
                k = sy * W + sx
                if hit.t >= best_t[k]:
                    continue
                p = add(o_local, mul(d_local, hit.t))
                if prim.cut is not None and prim.cut(p):
                    continue
                best_t[k] = hit.t
                best_i[k] = index
                best_n[k] = hit.normal
                best_p[k] = p
    return best_t, best_i, best_n, best_p


def _shade(prims: list[Prim], best_t: list, best_i: list, best_n: list, best_p: list, width: int, height: int,
           view: View, light: Vec, half: Vec, up_s: Vec, view_dir: Vec) -> RenderResult:
    """Materiales, reducción a rampas con tramado, línea de contacto y contorno."""
    ss = view.ss
    W = width * ss
    yaw = view.yaw
    color = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    normal_img = Image.new("RGBA", (width, height), (128, 128, 255, 0))
    # Información por píxel final: (rampa, luminancia, normal en pantalla, profundidad)
    cells: list[Optional[tuple]] = [None] * (width * height)
    for py in range(height):
        for px_ in range(width):
            votes: dict[str, list] = {}
            n_acc = [0.0, 0.0, 0.0]
            t_acc = 0.0
            hits = 0
            for sy in range(py * ss, py * ss + ss):
                for sx in range(px_ * ss, px_ * ss + ss):
                    k = sy * W + sx
                    i = best_i[k]
                    if i < 0:
                        continue
                    prim = prims[i]
                    n_local = best_n[k]
                    result = prim.material(best_p[k], n_local)
                    ramp_name, bright = result[0], result[1]
                    if len(result) > 2 and result[2] is not None:
                        n_local = norm(result[2])
                    n_world = rot_y(n_local, yaw)
                    lam = max(0.0, dot(n_world, light))
                    lum = (view.ambient + (1 - view.ambient) * lam) * bright
                    if len(result) > 3 and result[3]:  # 4º valor opcional: brillo especular
                        lum += result[3] * max(0.0, dot(n_world, half)) ** 18
                    if ramp_name.startswith("!"):  # emisivo: sin sombreado
                        lum = bright
                    votes.setdefault(ramp_name, []).append(lum)
                    n_acc = [n_acc[0] + n_world[0], n_acc[1] + n_world[1], n_acc[2] + n_world[2]]
                    t_acc += best_t[k]
                    hits += 1
            if hits * 2 < ss * ss:
                continue
            ramp_name = max(votes, key=lambda r: len(votes[r]))
            lum = sum(votes[ramp_name]) / len(votes[ramp_name])
            n = norm((n_acc[0], n_acc[1], n_acc[2]))
            ns = (dot(n, (1.0, 0.0, 0.0)), dot(n, up_s), dot(n, view_dir))
            cells[py * width + px_] = (ramp_name, lum, ns, t_acc / hits)

    # Línea de contacto: lo que queda detrás de otra pieza se oscurece un escalón.
    darken = [0] * (width * height)
    for py in range(height):
        for px_ in range(width):
            c = cells[py * width + px_]
            if c is None:
                continue
            for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                qx, qy = px_ + dx, py + dy
                if 0 <= qx < width and 0 <= qy < height:
                    q = cells[qy * width + qx]
                    if q is not None and c[3] - q[3] > 2.2:
                        darken[py * width + px_] = 1

    for py in range(height):
        for px_ in range(width):
            c = cells[py * width + px_]
            if c is None:
                continue
            ramp_name, lum, ns, _ = c
            colors = RAMPS[ramp_name.lstrip("!")]
            threshold = (BAYER4[py % 4][px_ % 4] + 0.5) / 16 - 0.5
            level = lum * (len(colors) - 1) + threshold * view.dither
            idx = int(round(level)) - darken[py * width + px_]
            idx = max(0, min(len(colors) - 1, idx))
            color.putpixel((px_, py), (*colors[idx], 255))
            normal_img.putpixel((px_, py), (int((ns[0] * 0.5 + 0.5) * 255), int((ns[1] * 0.5 + 0.5) * 255),
                                            int((max(ns[2], 0.0) * 0.5 + 0.5) * 255), 255))

    if view.outline:
        _outline(color, normal_img, cells, width, height)
    return RenderResult(color, normal_img, cells)


def _outline(color: Image.Image, normal_img: Image.Image, cells: list, width: int, height: int) -> None:
    """Contorno de color: el escalón más oscuro del vecino, mezclado con OUTLINE."""
    targets = []
    for py in range(height):
        for px_ in range(width):
            if cells[py * width + px_] is not None:
                continue
            for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                qx, qy = px_ + dx, py + dy
                if 0 <= qx < width and 0 <= qy < height and cells[qy * width + qx] is not None:
                    targets.append((px_, py, qx, qy))
                    break
    for px_, py, qx, qy in targets:
        dark = RAMPS[cells[qy * width + qx][0].lstrip("!")][0]
        c = tuple(int(dark[i] * 0.45 + OUTLINE[i] * 0.55) for i in range(3))
        color.putpixel((px_, py), (*c, 255))
        normal_img.putpixel((px_, py), normal_img.getpixel((qx, qy)))


def composite(results: list[tuple[RenderResult, int, int]], width: int, height: int) -> tuple[Image.Image, Image.Image]:
    """Monta varios fotogramas en una hoja (color y normales)."""
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    nsheet = Image.new("RGBA", (width, height), (128, 128, 255, 0))
    for result, x, y in results:
        sheet.alpha_composite(result.color, (x, y))
        nsheet.paste(result.normal, (x, y), result.normal)
    return sheet, nsheet


def scale_prims(prims: list["Prim"], k: float) -> list["Prim"]:
    """Escala un grupo de primitivas (las texturas se siguen calculando a escala original)."""
    import copy

    result = []
    for prim in prims:
        q = copy.copy(prim)
        q.center = mul(prim.center, k)
        q.bound = prim.bound * k
        if hasattr(prim, "a"):
            q.a = mul(prim.a, k)
            q.b = mul(prim.b, k)
            q.r = prim.r * k
        if hasattr(prim, "radii"):
            q.radii = mul(prim.radii, k)
        if hasattr(prim, "half"):
            q.half = mul(prim.half, k)
        mat = prim.material

        def wrapped(p: Vec, n: Vec, _mat=mat) -> tuple:
            return _mat(mul(p, 1.0 / k), n)

        q.material = wrapped
        if prim.cut is not None:
            q.cut = lambda p, _cut=prim.cut: _cut(mul(p, 1.0 / k))
        result.append(q)
    return result
