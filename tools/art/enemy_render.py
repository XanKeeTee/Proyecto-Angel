"""Renderizador vectorizado (numpy) para los enemigos de combate, por capas.

Usa las primitivas e intersecciones de `pxrender.py` (elipsoides, cápsulas, cilindros y
cajas, versión `intersect_np`), pero todo lo demás va en arrays:
  - materiales vectorizados que devuelven albedo, normal perturbada (relieve), brillo
    especular y dureza; las texturas se calculan en las coordenadas del modelo EN REPOSO,
    así que la tela, las venas y las grietas se mueven con el hueso que las lleva;
  - recortes vectorizados (`vcut`) para desgarros, agujeros y bordes dentados;
  - varias capas en una sola pasada: cada primitiva pertenece a una capa y cada capa tiene
    su propio búfer de profundidad, de modo que una capa oculta deja ver lo de detrás
    completo (el torso bajo el brazo está dibujado);
  - sombras arrojadas con un mapa de sombras desde la luz principal, oclusión ambiental en
    pantalla y luz de contorno (contraluz) de otro color;
  - supermuestreo 2×2 con cobertura de mayoría (bordes nítidos de pixel art) y tramado
    ordenado al reducir a pocos niveles de color.

Coordenadas: x = izquierda del personaje (derecha en pantalla cuando mira a cámara), y arriba,
z hacia la cámara. 1 unidad = 1 px.
"""

from __future__ import annotations

import copy
import math
import os
from dataclasses import dataclass, field

import numpy as np

from pxrender import Prim

_DEBUG = os.environ.get("ENEMY_DEBUG", "")

# --- ruido vectorizado -------------------------------------------------------------------

_M1, _M2, _M3, _M4 = np.uint32(374761393), np.uint32(668265263), np.uint32(2246822519), np.uint32(1274126177)


def _hash(ix: np.ndarray, iy: np.ndarray, iz: np.ndarray, seed: int) -> np.ndarray:
    with np.errstate(over="ignore"):
        h = (ix.astype(np.uint32) * _M1 + iy.astype(np.uint32) * _M2 + iz.astype(np.uint32) * _M3
             + np.uint32((seed * 144269504) & 0xFFFFFFFF))
        h = (h ^ (h >> np.uint32(13))) * _M4
        h = h ^ (h >> np.uint32(16))
    return (h & np.uint32(0xFFFF)).astype(np.float64) / 65535.0


def vnoise(p: np.ndarray, seed: int = 0) -> np.ndarray:
    """Ruido de valor 3D suave en [0, 1] para un array (N, 3)."""
    f = np.floor(p)
    i = f.astype(np.int64)
    u = p - f
    u = u * u * (3 - 2 * u)
    ix, iy, iz = i[:, 0], i[:, 1], i[:, 2]
    ux, uy, uz = u[:, 0], u[:, 1], u[:, 2]
    out = np.zeros(len(p))
    for dz in (0, 1):
        wz = uz if dz else 1 - uz
        for dy in (0, 1):
            wy = uy if dy else 1 - uy
            for dx in (0, 1):
                wx = ux if dx else 1 - ux
                out += wx * wy * wz * _hash(ix + dx, iy + dy, iz + dz, seed)
    return out


def fbm(p: np.ndarray, seed: int = 0, octaves: int = 3) -> np.ndarray:
    total = np.zeros(len(p))
    amp, freq, norm_sum = 1.0, 1.0, 0.0
    for i in range(octaves):
        total += amp * vnoise(p * freq, seed + i * 17)
        norm_sum += amp
        amp *= 0.5
        freq *= 2.03
    return total / norm_sum


def ridge(p: np.ndarray, seed: int = 0, octaves: int = 2) -> np.ndarray:
    """Ruido de crestas: 1 en líneas finas y sinuosas (venas, grietas)."""
    return 1.0 - np.abs(2.0 * fbm(p, seed, octaves) - 1.0)


def smoothstep(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def normalize(v: np.ndarray) -> np.ndarray:
    n = np.sqrt(np.einsum("ij,ij->i", v, v))
    return v / np.where(n > 0, n, 1.0)[:, None]


def bump(n: np.ndarray, grad: np.ndarray, k: float | np.ndarray) -> np.ndarray:
    """Perturba la normal con el gradiente de una altura (solo su parte tangente)."""
    k = np.asarray(k)
    if k.ndim == 1:
        k = k[:, None]
    tangent = grad - np.einsum("ij,ij->i", grad, n)[:, None] * n
    return normalize(n - k * tangent)


def grad_of(fn, p: np.ndarray, eps: float = 0.35) -> np.ndarray:
    """Gradiente numérico de una función escalar vectorizada."""
    g = np.zeros_like(p)
    for axis in range(3):
        d = np.zeros(3)
        d[axis] = eps
        g[:, axis] = (fn(p + d) - fn(p - d)) / (2 * eps)
    return g


def rgb(*c: float) -> np.ndarray:
    return np.array(c, dtype=np.float64) / 255.0


def mix(a: np.ndarray, b: np.ndarray, t: np.ndarray) -> np.ndarray:
    """Mezcla colores (N,3) o (3,) con pesos (N,)."""
    t = np.asarray(t)[:, None]
    return a * (1 - t) + b * t


# --- primitivas con datos de textura -----------------------------------------------------

def tag(prims: list[Prim], layer: str, mat: str, seed: int = 0, vcut=None, data: dict | None = None) -> list[Prim]:
    """Marca primitivas (en coordenadas de reposo) con capa, material y recorte vectorizado."""
    for p in prims:
        p.layer = layer
        p.mat = mat
        p.seed = seed
        p.vcut = vcut
        p.data = data or {}
        p.tex_R = np.eye(3)
        p.tex_t = np.zeros(3)
    return prims


def place(prims: list[Prim], R: np.ndarray, t: np.ndarray) -> list[Prim]:
    """Coloca primitivas en reposo con la transformación rígida p' = R p + t. Las texturas y
    los recortes siguen calculándose en las coordenadas de reposo."""
    out = []

    def fwd(v):
        return tuple(R @ np.array(v) + t)

    for prim in prims:
        q = copy.copy(prim)
        q.center = fwd(prim.center)
        if hasattr(prim, "a"):
            q.a = fwd(prim.a)
            q.b = fwd(prim.b)
        if hasattr(prim, "basis"):
            q.basis = tuple(tuple(R @ np.array(ax)) for ax in prim.basis)
        q.tex_R = R @ prim.tex_R
        q.tex_t = R @ prim.tex_t + t
        out.append(q)
    return out


# --- cámara ------------------------------------------------------------------------------

@dataclass
class Camera:
    """Proyección paralela: el píxel (u, v) relativo al origen sale de O0 + u*U + v*V con
    dirección D. Sirve tanto para la vista de combate (ortográfica, algo picada) como para la
    oblicua del mapa (la de pxrender: v = a*y - b*z)."""
    U: np.ndarray
    V: np.ndarray
    D: np.ndarray
    O0: np.ndarray

    @staticmethod
    def ortho(pitch: float) -> "Camera":
        """Mirando hacia -z, inclinada `pitch` radianes hacia abajo."""
        D = np.array([0.0, -math.sin(pitch), -math.cos(pitch)])
        U = np.array([1.0, 0.0, 0.0])
        V = np.cross(D, U) * -1.0
        V = V / np.linalg.norm(V)
        return Camera(U, V, D, -D * 400.0)

    @staticmethod
    def oblique(a: float = 1.0, b: float = 0.45) -> "Camera":
        D = np.array([0.0, -b, -a])
        D = D / np.linalg.norm(D)
        return Camera(np.array([1.0, 0.0, 0.0]), np.array([0.0, 1.0 / a, 0.0]), D, -D * 400.0)

    def project(self, p) -> tuple[float, float]:
        """Punto del mundo -> (u, v) en unidades de pantalla (v hacia arriba)."""
        m = np.stack([self.U, self.V, self.D], axis=1)
        s = np.linalg.solve(m, np.asarray(p, dtype=np.float64) - self.O0)
        return float(s[0]), float(s[1])

    @property
    def view_dir(self) -> np.ndarray:
        return -self.D

    @property
    def up(self) -> np.ndarray:
        v = self.V - np.dot(self.V, self.D) * self.D
        return v / np.linalg.norm(v)


def _trace(prims: list[Prim], cam: Camera, W: int, H: int, ox: float, oy: float, scale: float,
           layers: list[str]) -> dict:
    """Traza todas las primitivas; un búfer de profundidad por capa.
    Devuelve {capa: (t, idx, n, p)} con arrays de W*H."""
    out = {}
    for layer in layers:
        out[layer] = [np.full(W * H, np.inf), np.full(W * H, -1, dtype=np.int64), np.zeros((W * H, 3)),
                      np.zeros((W * H, 3))]
    m = np.stack([cam.U, cam.V, cam.D], axis=1)
    minv = np.linalg.inv(m)
    D = cam.D
    ku = np.linalg.norm(minv[0])
    kv = np.linalg.norm(minv[1])
    for index, prim in enumerate(prims):
        if prim.layer not in out:
            continue
        s = minv @ (np.array(prim.center) - cam.O0)
        rad = prim.bound * ku + 1.0
        rad_v = prim.bound * kv + 1.0
        x0 = max(0, int((ox + s[0] - rad) * scale))
        x1 = min(W - 1, int((ox + s[0] + rad) * scale) + 1)
        y0 = max(0, int((oy - s[1] - rad_v) * scale))
        y1 = min(H - 1, int((oy - s[1] + rad_v) * scale) + 1)
        if x1 < x0 or y1 < y0:
            continue
        sx, sy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        sx, sy = sx.ravel(), sy.ravel()
        u = (sx + 0.5) / scale - ox
        v = oy - (sy + 0.5) / scale
        o = cam.O0 + np.outer(u, cam.U) + np.outer(v, cam.V)
        t, n = prim.intersect_np(o, tuple(D))
        buf = out[prim.layer]
        k = sy * W + sx
        mask = t < buf[0][k]
        if not mask.any():
            continue
        k, t, n, o = k[mask], t[mask], n[mask], o[mask]
        p = o + np.outer(t, D)
        if prim.vcut is not None:
            rest = (p - prim.tex_t) @ np.linalg.inv(prim.tex_R).T
            keep = ~prim.vcut(rest, prim)
            k, t, n, p = k[keep], t[keep], n[keep], p[keep]
        buf[0][k] = t
        buf[1][k] = index
        buf[2][k] = n
        buf[3][k] = p
    return out


# --- materiales ------------------------------------------------------------------------------

@dataclass
class Surface:
    """Resultado de un material para N muestras."""
    albedo: np.ndarray            # (N, 3) lineal 0..1
    normal: np.ndarray            # (N, 3) en coordenadas de reposo
    spec: np.ndarray              # (N,) intensidad especular
    gloss: np.ndarray             # (N,) exponente
    wrap: np.ndarray              # (N,) luz envolvente (piel: dispersión bajo la superficie)
    emit: np.ndarray | None = None  # (N, 3) emisivo


MATERIALS: dict[str, callable] = {}


def material(name: str):
    def deco(fn):
        MATERIALS[name] = fn
        return fn
    return deco


def surface(n_count: int, albedo, normal, spec=0.0, gloss=20.0, wrap=0.0, emit=None) -> Surface:
    def arr(v):
        v = np.asarray(v, dtype=np.float64)
        return np.broadcast_to(v, (n_count,)).copy() if v.ndim == 0 else v
    alb = np.asarray(albedo, dtype=np.float64)
    if alb.ndim == 1:
        alb = np.broadcast_to(alb, (n_count, 3)).copy()
    return Surface(alb, normal, arr(spec), arr(gloss), arr(wrap), emit)


# --- iluminación ---------------------------------------------------------------------------

@dataclass
class Lighting:
    key_dir: tuple = (-0.74, 0.58, 0.34)      # luz lateral fría (de la izquierda de la pantalla, algo alta)
    key_col: tuple = (1.55, 1.72, 2.05)
    rim_dir: tuple = (0.85, 0.3, -0.45)       # contraluz granate (detrás, a la derecha)
    rim_col: tuple = (1.1, 0.16, 0.14)
    rim_power: float = 1.8
    fill_dir: tuple = (0.5, -0.3, 0.6)        # rebote del suelo, muy tenue y violeta
    fill_col: tuple = (0.035, 0.025, 0.06)
    ambient: tuple = (0.012, 0.011, 0.022)
    shadow_strength: float = 0.94
    ao_strength: float = 0.8
    exposure: float = 1.0


MAP_LIGHTING = Lighting(key_dir=(-0.45, 0.7, 0.55), key_col=(0.95, 0.95, 1.0), rim_dir=(0.6, 0.3, -0.7),
                        rim_col=(0.25, 0.08, 0.1), fill_col=(0.12, 0.12, 0.16), ambient=(0.30, 0.30, 0.34),
                        shadow_strength=0.5, ao_strength=0.35)


def _n(v) -> np.ndarray:
    v = np.asarray(v, dtype=np.float64)
    return v / np.linalg.norm(v)


def _shadow_maps(prims: list[Prim], light: np.ndarray, groups: dict[str, list[str]], res: float = 1.5):
    """Mapas de profundidad desde la luz para cada capa. Devuelve una función
    lit(points, receptor) -> factor 0..1."""
    D = -light
    U = np.cross(D, np.array([0.0, 1.0, 0.0]))
    if np.linalg.norm(U) < 1e-3:
        U = np.cross(D, np.array([1.0, 0.0, 0.0]))
    U = U / np.linalg.norm(U)
    V = np.cross(U, D)
    centers = np.array([p.center for p in prims])
    O0 = -D * 400.0
    us = centers @ U
    vs = centers @ V
    bounds = np.array([p.bound for p in prims])
    umin, umax = (us - bounds).min() - 2, (us + bounds).max() + 2
    vmin, vmax = (vs - bounds).min() - 2, (vs + bounds).max() + 2
    W = int((umax - umin) * res) + 2
    H = int((vmax - vmin) * res) + 2
    cam = Camera(U, V, D, O0)
    layers = sorted({p.layer for p in prims})
    buf = _trace(prims, cam, W, H, -umin, vmax, res, layers)
    depth = {layer: buf[layer][0] for layer in layers}

    def lit(points: np.ndarray, casters: list[str]) -> np.ndarray:
        rel = points - O0
        u = rel @ U
        v = rel @ V
        t = rel @ D
        result = np.ones(len(points))
        # Filtro de 3×3 (sombras algo suaves)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                xi = np.clip(((u - umin) * res + dx * 0.7).astype(int), 0, W - 1)
                yi = np.clip(((vmax - v) * res + dy * 0.7).astype(int), 0, H - 1)
                k = yi * W + xi
                occluded = np.zeros(len(points), dtype=bool)
                for layer in casters:
                    if layer in depth:
                        occluded |= depth[layer][k] < t - 2.2
                result -= occluded / 9.0
        return result

    return lit


def _ssao(depth: np.ndarray, valid: np.ndarray, radius: int = 4) -> np.ndarray:
    """Oclusión ambiental en pantalla: cuánto más cerca de la cámara están los vecinos."""
    H, W = depth.shape
    d = np.where(valid, depth, np.inf)
    occ = np.zeros((H, W))
    count = 0
    for r in (1, 2, radius):
        for ang in range(8):
            a = ang / 8 * math.tau + r * 0.4
            dx, dy = int(round(math.cos(a) * r)), int(round(math.sin(a) * r))
            sh = np.full((H, W), np.inf)
            ys = slice(max(0, dy), H + min(0, dy))
            yd = slice(max(0, -dy), H + min(0, -dy))
            xs = slice(max(0, dx), W + min(0, dx))
            xd = slice(max(0, -dx), W + min(0, -dx))
            sh[yd, xd] = d[ys, xs]
            with np.errstate(invalid="ignore"):
                diff = np.nan_to_num(depth - sh, nan=0.0, posinf=0.0, neginf=0.0)  # >0: el vecino está más cerca
            occ += np.clip((diff - 0.6) / (2.5 * r), 0.0, 1.0) * (diff < 14.0 * r)
            count += 1
    return np.clip(occ / count * 2.2, 0.0, 1.0)


BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float64)


@dataclass
class LayerImage:
    color: np.ndarray    # (H, W, 4) uint8
    normal: np.ndarray   # (H, W, 4) uint8
    depth: np.ndarray    # (H, W) float (inf = vacío)


@dataclass
class RenderSettings:
    width: int
    height: int
    origin: tuple
    cam: Camera
    lighting: Lighting = field(default_factory=Lighting)
    ss: int = 2
    levels: int = 20             # niveles por canal tras el tramado
    dither: float = 0.9
    occluders: dict = field(default_factory=dict)   # capa -> capas que la tapan (sin dibujarse)
    casters: dict = field(default_factory=dict)     # capa -> capas que le arrojan sombra
    contact: dict = field(default_factory=dict)     # capa -> capa sobre la que deja sombra de contacto
    outline: bool = False
    outline_col: tuple = (14, 10, 18)
    saturation: float = 1.0
    gamma: float = 1.0 / 2.2


def render_layers(prims: list[Prim], rs: RenderSettings, layers: list[str]) -> dict[str, LayerImage]:
    """Renderiza cada capa por separado (todas en una pasada)."""
    ss = rs.ss
    W, H = rs.width * ss, rs.height * ss
    ox, oy = rs.origin
    cam = rs.cam
    lt = rs.lighting
    key = _n(lt.key_dir)
    rim = _n(lt.rim_dir)
    fill = _n(lt.fill_dir)
    vdir = cam.view_dir
    half = _n(key + vdir)
    needed = set(layers)
    for layer in layers:
        needed |= set(rs.occluders.get(layer, []))
    all_layers = sorted({p.layer for p in prims} & needed)
    buf = _trace(prims, cam, W, H, ox, oy, ss, all_layers)
    lit_fn = _shadow_maps([p for p in prims if p.layer in needed or any(p.layer in c for c in rs.casters.values())],
                          key, rs.casters)

    tex_R = np.array([p.tex_R for p in prims])
    tex_Ri = np.linalg.inv(tex_R)
    tex_t = np.array([p.tex_t for p in prims])
    mats = [p.mat for p in prims]
    seeds = np.array([p.seed for p in prims], dtype=np.float64)

    result: dict[str, LayerImage] = {}
    for layer in layers:
        t, idx, n, p = buf[layer]
        hit = idx >= 0
        for occ in rs.occluders.get(layer, []):
            ot = buf[occ][0]
            hit &= ~(ot < t - 0.4)
        sel = np.nonzero(hit)[0]
        lin = np.zeros((W * H, 3))
        nrm_out = np.zeros((W * H, 3))
        if len(sel):
            ii = idx[sel]
            P = p[sel]
            Nw = n[sel]
            R = tex_R[ii]
            Prest = np.einsum("nij,nj->ni", tex_Ri[ii], P - tex_t[ii])
            Nrest = normalize(np.einsum("nji,nj->ni", R, Nw))
            albedo = np.zeros((len(sel), 3))
            nrest2 = Nrest.copy()
            spec = np.zeros(len(sel))
            gloss = np.ones(len(sel)) * 20
            wrap = np.zeros(len(sel))
            emit = np.zeros((len(sel), 3))
            names = np.array(mats, dtype=object)[ii]
            for name in set(names.tolist()):
                m = names == name
                sub_idx = ii[m]
                s = MATERIALS[name](Prest[m], Nrest[m], seeds[sub_idx], sub_idx, prims)
                albedo[m] = s.albedo
                nrest2[m] = s.normal
                spec[m] = s.spec
                gloss[m] = s.gloss
                wrap[m] = s.wrap
                if s.emit is not None:
                    emit[m] = s.emit
            if _DEBUG == "mat":
                for name in set(names.tolist()):
                    h = abs(hash(name)) % 997
                    albedo[names == name] = ((h * 37) % 255 / 255, (h * 91) % 255 / 255, (h * 53) % 255 / 255)
            albedo = np.clip(albedo, 0.0, 1.0) ** 2.2   # sRGB -> lineal
            Nw2 = normalize(np.einsum("nij,nj->ni", R, nrest2))
            casters = rs.casters.get(layer, [layer])
            shadow = lit_fn(P, casters)
            if _DEBUG == "noshadow":
                shadow = np.ones(len(P))
            shadow = 1.0 - lt.shadow_strength * (1.0 - shadow)
            ndl = Nw2 @ key
            diff = np.clip((ndl + wrap) / (1.0 + wrap), 0.0, 1.0)
            diff = np.minimum(diff, np.clip(ndl * 0.5 + 0.5, 0, 1) * 2.0)  # el envolvente no ilumina la espalda
            ndv = np.clip(Nw2 @ vdir, 0.0, 1.0)
            rim_t = np.clip(Nw2 @ rim, 0.0, 1.0) * (1.0 - ndv) ** lt.rim_power
            fill_t = np.clip(Nw2 @ fill * 0.5 + 0.5, 0.0, 1.0)
            spec_t = spec * np.clip(Nw2 @ half, 0.0, 1.0) ** gloss * (ndl > 0)
            col = albedo * (np.array(lt.ambient) + np.outer(diff * shadow, lt.key_col) + np.outer(fill_t, lt.fill_col))
            col += albedo * 0.6 * np.outer(rim_t, lt.rim_col) + np.outer(rim_t * 0.35, lt.rim_col) * 0.4
            col += np.outer(spec_t * shadow, lt.key_col)
            col += emit
            if _DEBUG == "albedo":
                col = albedo
            lin[sel] = col
            nrm_out[sel] = Nw2
        # Reducción del supermuestreo: cobertura de mayoría.
        hits = hit.reshape(rs.height, ss, rs.width, ss).sum(axis=(1, 3))
        cover = hits * 2 >= ss * ss
        col = lin.reshape(rs.height, ss, rs.width, ss, 3).sum(axis=(1, 3)) / np.maximum(hits, 1)[..., None]
        nn = nrm_out.reshape(rs.height, ss, rs.width, ss, 3).sum(axis=(1, 3))
        nl = np.linalg.norm(nn, axis=2, keepdims=True)
        nn = nn / np.where(nl > 0, nl, 1.0)
        tt = np.where(hit, t, 0.0).reshape(rs.height, ss, rs.width, ss).sum(axis=(1, 3)) / np.maximum(hits, 1)
        depth = np.where(cover, tt, np.inf)
        # Oclusión ambiental contra la propia capa y lo que la tapa.
        dep_ao = depth.copy()
        for occ in rs.occluders.get(layer, []) + rs.casters.get(layer, []):
            if occ in buf and occ != layer:
                ot = buf[occ][0].reshape(rs.height, ss, rs.width, ss).min(axis=(1, 3))
                dep_ao = np.minimum(dep_ao, ot)
        ao = _ssao(np.where(np.isfinite(depth), depth, dep_ao), np.isfinite(dep_ao))
        col *= (1.0 - lt.ao_strength * ao)[..., None]
        col *= lt.exposure
        if rs.saturation != 1.0:
            lum = col @ np.array([0.3, 0.55, 0.15])
            col = lum[..., None] + (col - lum[..., None]) * rs.saturation
        col = np.clip(np.nan_to_num(col), 0.0, 1.0) ** rs.gamma
        # Tramado ordenado a pocos niveles (aspecto de pixel art, sin bandas).
        yy, xx = np.mgrid[0:rs.height, 0:rs.width]
        thr = (BAYER4[yy % 4, xx % 4] + 0.5) / 16 - 0.5
        q = np.floor(col * (rs.levels - 1) + 0.5 + thr[..., None] * rs.dither)
        col8 = np.clip(q / (rs.levels - 1) * 255, 0, 255).astype(np.uint8)
        rgba = np.zeros((rs.height, rs.width, 4), dtype=np.uint8)
        rgba[..., :3] = col8
        rgba[..., 3] = np.where(cover, 255, 0)
        # Mapa de normales en pantalla (mismo convenio que pxrender).
        up = cam.up
        right = cam.U / np.linalg.norm(cam.U)
        nx = nn @ right
        ny = nn @ up
        nz = np.maximum(nn @ vdir, 0.0)
        nrgba = np.zeros((rs.height, rs.width, 4), dtype=np.uint8)
        nrgba[..., 0] = ((nx * 0.5 + 0.5) * 255).astype(np.uint8)
        nrgba[..., 1] = ((ny * 0.5 + 0.5) * 255).astype(np.uint8)
        nrgba[..., 2] = ((nz * 0.5 + 0.5) * 255).astype(np.uint8)
        nrgba[..., 3] = np.where(cover, 255, 0)
        nrgba[~cover] = (128, 128, 255, 0)
        result[layer] = LayerImage(rgba, nrgba, depth)
        result[layer]._occ_depth = {occ: buf[occ][0].reshape(rs.height, ss, rs.width, ss).min(axis=(1, 3))
                                    for occ in rs.occluders.get(layer, []) if occ in buf}
    for layer, targets in rs.contact.items():
        for target in targets:
            if layer in result and target in result:
                _contact_shadow(result[layer], result[target], key, cam)
    if rs.outline:
        for layer in layers:
            _outline(result[layer], rs.outline_col)
    return result


def _contact_shadow(img: LayerImage, under: LayerImage, key: np.ndarray, cam: Camera) -> None:
    """Sombra semitransparente que la capa deja sobre la de debajo (va en la propia capa,
    así desaparece con ella)."""
    a = img.color[..., 3] > 0
    H, W = a.shape
    # Desplazamiento en pantalla opuesto a la luz.
    dx = int(round(-np.dot(key, cam.U) * 2.0))
    dy = int(round(np.dot(key, cam.up) * 2.0))
    shade = np.zeros((H, W))
    for k, (ox, oy) in enumerate(((dx, dy), (dx * 2, dy * 2), (1 if dx >= 0 else -1, 1))):
        sh = np.zeros((H, W), dtype=bool)
        ys = slice(max(0, -oy), H + min(0, -oy))
        yd = slice(max(0, oy), H + min(0, oy))
        xs = slice(max(0, -ox), W + min(0, -ox))
        xd = slice(max(0, ox), W + min(0, ox))
        sh[yd, xd] = a[ys, xs]
        shade = np.maximum(shade, sh * (0.55 if k == 0 else 0.3))
    target = (under.color[..., 3] > 0) & ~a & (shade > 0)
    # Solo donde la capa está por delante de la de debajo (profundidad similar).
    col = img.color
    col[target, :3] = (8, 6, 12)
    col[target, 3] = (shade[target] * 255).astype(np.uint8)
    img.normal[target] = under.normal[target]


def _outline(img: LayerImage, ink: tuple) -> None:
    """Contorno de color (solo el sprite del mapa): el tono del vecino oscurecido hacia `ink`."""
    a = img.color[..., 3] == 255
    H, W = a.shape
    out = img.color.copy()
    for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        src = np.zeros_like(img.color)
        ys = slice(max(0, dy), H + min(0, dy))
        yd = slice(max(0, -dy), H + min(0, -dy))
        xs = slice(max(0, dx), W + min(0, dx))
        xd = slice(max(0, -dx), W + min(0, -dx))
        src[yd, xd] = img.color[ys, xs]
        m = (out[..., 3] < 255) & (src[..., 3] == 255)
        c = src[..., :3].astype(np.float64) * 0.35 + np.array(ink) * 0.65
        out[m, :3] = c[m].astype(np.uint8)
        out[m, 3] = 255
    img.color[...] = out


def pdata(ii: np.ndarray, prims: list[Prim], key: str, default: float = 0.0) -> np.ndarray:
    """Valor numérico `prim.data[key]` de cada muestra (por índice de primitiva)."""
    uniq, inv = np.unique(ii, return_inverse=True)
    vals = np.array([float(prims[j].data.get(key, default)) for j in uniq])
    return vals[inv]
