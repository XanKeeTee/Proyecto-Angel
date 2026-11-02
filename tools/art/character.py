"""Hojas del protagonista por capas: el cuerpo (con ropa interior) y una hoja por prenda.

Cada prenda se renderiza junto al cuerpo, pero el cuerpo solo sirve de "tapa": los píxeles
donde el cuerpo queda por delante se borran. Así cada prenda se dibuja encima del cuerpo
en Godot y queda bien tapada por brazos, piernas o cabeza cuando corresponde. En el borde
donde la prenda pisa al cuerpo se añade una sombra de contacto de un píxel.

Las hojas tienen el mismo formato que la del cuerpo (64 columnas x 8 orientaciones), así
que en el juego todas las capas usan el mismo número de fotograma.

El render es lento (Python puro), así que se reparte entre todos los núcleos.
Uso independiente: python -I tools/art/character.py [capa ...]
"""

from __future__ import annotations

import copy
import json
import math
import os
import sys
import time
from multiprocessing import Pool
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

import human  # noqa: E402
from pxrender import OUTLINE, RAMPS, View, render, rot_y  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
BODY_PATH = "assets/sprites/characters/protagonist.png"
WEAR_DIR = "assets/sprites/characters/wear"

# Columnas de la hoja (por fila de orientación): inicio y nº de fotogramas.
ANIMS = {"idle": (0, 8), "fidget": (8, 12), "walk": (20, 12), "idle_flash": (32, 8), "look": (40, 12), "walk_flash": (52, 12)}
COLUMNS = 64
# 8 orientaciones, en el orden del ángulo en pantalla: abajo, abajo-izq., izq., arriba-izq.,
# arriba, arriba-der., der., abajo-der. (fila = round((ángulo - 90°) / 45°) mod 8).
YAWS = (0.0, -math.pi / 4, -math.pi / 2, -3 * math.pi / 4, math.pi, 3 * math.pi / 4, math.pi / 2, math.pi / 4)


def anim_of(column: int) -> tuple[str, int]:
    for name, (start, count) in ANIMS.items():
        if start <= column < start + count:
            return name, column - start
    raise ValueError(column)


def pose_for(anim: str, i: int) -> human.Pose:
    t = i / ANIMS[anim][1]
    return {
        "idle": lambda: human.idle_pose(t),
        "fidget": lambda: human.fidget_pose(t),
        "walk": lambda: human.walk_pose(t),
        "idle_flash": lambda: human.idle_pose(t, True),
        "look": lambda: human.look_pose(t),
        "walk_flash": lambda: human.walk_pose(t, True),
    }[anim]()


def _occ(p: human.Prim) -> human.Prim:
    q = copy.copy(p)
    q.material = lambda _p, _n: ("occ", 1.0)
    return q


def render_layer(layer: str, pose: human.Pose, view: View, w: int = human.FRAME_W, h: int = human.FRAME_H,
                 origin: tuple = human.ORIGIN) -> tuple[Image.Image, Image.Image, Image.Image | None]:
    """Un fotograma de una capa: (color, normales, brillo o None)."""
    if layer == "body":
        r = render(human.build_parts(pose, ())["body"], w, h, origin, view)
        return r.color, r.normal, r.glow()
    parts = human.build_parts(pose, (layer,))
    r = render([_occ(p) for p in parts["body"]] + parts[layer], w, h, origin, view)
    return _strip_occluders(r, w, h) + (None,)


def render_garment_alone(layer: str, pose: human.Pose, view: View, w: int, h: int, origin: tuple) -> Image.Image:
    """La prenda sin cuerpo (para iconos)."""
    return render(human.build_parts(pose, (layer,))[layer], w, h, origin, view).color


def _strip_occluders(r, w: int, h: int) -> tuple[Image.Image, Image.Image]:
    cells = r.depth
    color = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    normal = Image.new("RGBA", (w, h), (128, 128, 255, 0))

    def is_garment(x: int, y: int) -> bool:
        if 0 <= x < w and 0 <= y < h:
            c = cells[y * w + x]
            return c is not None and c[0] != "occ"
        return False

    for y in range(h):
        for x in range(w):
            c = cells[y * w + x]
            src = r.color.getpixel((x, y))
            if c is None:
                # Contorno: solo si lo provoca la prenda.
                for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                    if src[3] and is_garment(x + dx, y + dy):
                        dark = RAMPS[cells[(y + dy) * w + x + dx][0].lstrip("!")][0]
                        color.putpixel((x, y), (*(int(dark[i] * 0.45 + OUTLINE[i] * 0.55) for i in range(3)), 255))
                        normal.putpixel((x, y), r.normal.getpixel((x + dx, y + dy)))
                        break
                continue
            if c[0] != "occ":
                color.putpixel((x, y), src)
                normal.putpixel((x, y), r.normal.getpixel((x, y)))
                continue
            # Cuerpo junto al borde de la prenda que está por delante: sombra de contacto.
            for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                if is_garment(x + dx, y + dy) and c[3] - cells[(y + dy) * w + x + dx][3] > 1.2:
                    color.putpixel((x, y), (*OUTLINE, 120))
                    normal.putpixel((x, y), r.normal.getpixel((x + dx, y + dy)))
                    break
    return color, normal


def _job(args: tuple) -> tuple:
    layer, row, column = args
    anim, i = anim_of(column)
    color, normal, glow = render_layer(layer, pose_for(anim, i), View(yaw=YAWS[row]))
    pack = lambda img: (img.tobytes() if img is not None else None)  # noqa: E731
    return layer, row, column, pack(color), pack(normal), pack(glow)


def lens_frames() -> tuple[list, list]:
    """Posición de la lente de la linterna por fotograma (respecto a los pies) y una por fila."""
    view = View()
    frames, rows = [], []
    for yaw in YAWS:
        row = [None] * COLUMNS
        for anim, (start, count) in ANIMS.items():
            for i in range(count):
                pose = pose_for(anim, i)
                if pose.flashlight:
                    p = rot_y(human.lens_position(pose), yaw)
                    row[start + i] = [round(p[0], 1), round(-(view.a * p[1] - view.b * p[2]), 1)]
        frames.append(row)
        p0 = rot_y(human.lens_position(human.idle_pose(0.0, True)), yaw)
        rows.append({"screen": [round(p0[0], 1), round(-(view.a * p0[1] - view.b * p0[2]), 1)],
                     "floor": [round(p0[0], 1), round(view.b * p0[2], 1)]})
    return frames, rows


def layer_path(layer: str) -> str:
    return BODY_PATH if layer == "body" else f"{WEAR_DIR}/{layer}.png"


def build(layers: list[str] | None = None, processes: int | None = None) -> dict:
    """Renderiza las capas pedidas (todas por defecto) y devuelve la entrada de sprite_meta."""
    layers = layers or ["body"] + list(human.GARMENTS)
    w, h = human.FRAME_W, human.FRAME_H
    size = (w * COLUMNS, h * len(YAWS))
    sheets = {layer: [Image.new("RGBA", size, (0, 0, 0, 0)), Image.new("RGBA", size, (128, 128, 255, 0)),
                      Image.new("RGBA", size, (0, 0, 0, 0))] for layer in layers}
    jobs = [(layer, row, col) for layer in layers for row in range(len(YAWS)) for col in range(COLUMNS)]
    start = time.time()
    with Pool(processes or max(1, (os.cpu_count() or 2) - 1)) as pool:
        for n, (layer, row, col, c, nm, g) in enumerate(pool.imap_unordered(_job, jobs, chunksize=4)):
            at = (col * w, row * h)
            sheets[layer][0].paste(Image.frombytes("RGBA", (w, h), c), at)
            sheets[layer][1].paste(Image.frombytes("RGBA", (w, h), nm), at)
            if g is not None:
                sheets[layer][2].paste(Image.frombytes("RGBA", (w, h), g), at)
            if n % 256 == 0:
                print(f"   {n}/{len(jobs)} fotogramas ({time.time() - start:.0f} s)", flush=True)
    for layer, (color, normal, glow) in sheets.items():
        path = ROOT / layer_path(layer)
        path.parent.mkdir(parents=True, exist_ok=True)
        color.save(path)
        normal.save(path.with_name(path.stem + "_n.png"))
        if layer == "body":
            glow.save(path.with_name(path.stem + "_glow.png"))
        print("  ", layer_path(layer), f"{color.width}x{color.height}")
    frames, rows = lens_frames()
    return {"path": "res://" + BODY_PATH, "frame": [w, h], "hframes": COLUMNS, "vframes": len(YAWS),
            "origin": list(human.ORIGIN), "anchor": [0, 0], "glow": True,
            "anims": {k: list(v) for k, v in ANIMS.items()}, "columns": COLUMNS, "lens": rows, "lens_frames": frames,
            "wear": {g: {"path": "res://" + layer_path(g), "slot": slot} for g, slot in human.GARMENTS.items()}}


def main() -> None:
    meta_path = ROOT / "tools/art/sprite_meta.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    meta["protagonist"] = build(sys.argv[1:] or None)
    meta_path.write_text(json.dumps(meta, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
