"""Hojas del protagonista por capas: el cuerpo (con ropa interior) y una hoja por prenda.

Cada prenda se renderiza junto al cuerpo, pero el cuerpo solo sirve de "tapa": los píxeles
donde el cuerpo queda por delante se borran. Así cada prenda se dibuja encima del cuerpo
en Godot y queda bien tapada por brazos, piernas o cabeza cuando corresponde. En el borde
donde la prenda pisa al cuerpo se añade una sombra de contacto de un píxel.

Cada capa tiene varias hojas (para no cargar en memoria lo que no se usa):
  - "move":         andar, de espaldas, de lado, girar, reposo y gestos. 16 orientaciones.
  - "move_flash":   lo mismo con la linterna en la mano.
  - "action":       acciones de interacción (abrir, coger, llave…). 8 orientaciones.
  - "action_flash": lo mismo con la linterna.
  - "getup":        levantarse de la camilla al empezar (una sola orientación, la de la camilla).
Todas las capas comparten la distribución de cada hoja, así que en el juego todas usan el
mismo número de fotograma.

Uso: python -I tools/art/character.py [--sheets move,getup] [--procs N] [capa ...]
Sin capas, todas (cuerpo + human.GARMENTS). Sin --sheets, todas las hojas. Lo que no se
renderiza conserva sus datos en sprite_meta.json.
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
import motion  # noqa: E402
from pxrender import OUTLINE, RAMPS, View, render, rot_y  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
BODY_PATH = "assets/sprites/characters/protagonist.png"
WEAR_DIR = "assets/sprites/characters/wear"

# Columnas de las hojas de movimiento (por fila de orientación): inicio y nº de fotogramas.
# En la hoja con linterna, "fidget" es mirar a los lados.
MOVE_ANIMS = {"idle": (0, 8), "fidget": (8, 12), "walk": (20, 12), "back": (32, 12), "strafe_l": (44, 12),
              "strafe_r": (56, 12), "turn": (68, 8)}
MOVE_COLUMNS = 76
ACTION_COLUMNS = sum(n for n, _ in motion.ACTIONS.values())
DIRECTIONS = 16
ACTION_DIRECTIONS = 8


def yaws(count: int) -> list[float]:
    """Orientaciones en el orden del ángulo en pantalla, empezando por abajo y girando hacia
    la izquierda: fila = round((ángulo - 90°) / (360° / count)) mod count."""
    return [-i * math.tau / count for i in range(count)]


def _action_anims() -> dict:
    anims, col = {}, 0
    for name, (count, fps) in motion.ACTIONS.items():
        anims[name] = (col, count)
        col += count
    return anims


SHEETS: dict[str, dict] = {
    "move": {"suffix": "", "rows": DIRECTIONS, "columns": MOVE_COLUMNS, "flash": False, "anims": MOVE_ANIMS},
    "move_flash": {"suffix": "_flash", "rows": DIRECTIONS, "columns": MOVE_COLUMNS, "flash": True, "anims": MOVE_ANIMS},
    "action": {"suffix": "_action", "rows": ACTION_DIRECTIONS, "columns": ACTION_COLUMNS, "flash": False,
               "anims": _action_anims()},
    "action_flash": {"suffix": "_action_flash", "rows": ACTION_DIRECTIONS, "columns": ACTION_COLUMNS, "flash": True,
                     "anims": _action_anims()},
    "getup": {"suffix": "_getup", "rows": 1, "columns": motion.GETUP_FRAMES, "flash": False,
              "anims": {"getup": (0, motion.GETUP_FRAMES)}},
}


def frame_size(sheet: str) -> tuple[int, int]:
    return motion.GETUP_FRAME if sheet == "getup" else (human.FRAME_W, human.FRAME_H)


def frame_origin(sheet: str) -> tuple[int, int]:
    return motion.GETUP_ORIGIN if sheet == "getup" else human.ORIGIN


def anim_of(sheet: str, column: int) -> tuple[str, int]:
    for name, (start, count) in SHEETS[sheet]["anims"].items():
        if start <= column < start + count:
            return name, column - start
    raise ValueError(column)


def pose_for(sheet: str, column: int) -> human.Pose:
    anim, i = anim_of(sheet, column)
    flash = SHEETS[sheet]["flash"]
    if sheet.startswith("action"):
        return motion.action_pose(anim, i, flash)
    t = i / SHEETS[sheet]["anims"][anim][1]
    return {
        "idle": lambda: human.idle_pose(t, flash),
        "fidget": lambda: human.look_pose(t) if flash else human.fidget_pose(t),
        "walk": lambda: human.walk_pose(t, flash),
        "back": lambda: human.walk_back_pose(t, flash),
        "strafe_l": lambda: human.strafe_pose(t, 1.0, flash),
        "strafe_r": lambda: human.strafe_pose(t, -1.0, flash),
        "turn": lambda: human.turn_pose(t, flash),
    }[anim]()


def _occ(p: human.Prim) -> human.Prim:
    q = copy.copy(p)
    q.material = lambda _p, _n: ("occ", 1.0)
    return q


def render_layer(layer: str, pose: human.Pose, view: View, w: int = human.FRAME_W, h: int = human.FRAME_H,
                 origin: tuple = human.ORIGIN, extra: list | None = None,
                 hidden: list | None = None) -> tuple[Image.Image, Image.Image, Image.Image | None]:
    """Un fotograma de una capa: (color, normales, brillo o None). `extra` va con el cuerpo
    (la manta); `hidden` tapa pero no se dibuja (el colchón)."""
    extra = extra or []
    hidden = hidden or []
    if layer == "body":
        prims = human.build_parts(pose, ())["body"] + extra
        r = render(prims + hidden, w, h, origin, view)
        if not hidden:
            return r.color, r.normal, r.glow()
        color, normal = _strip_occluders(r, w, h, garment=False)
        return color, normal, r.glow()
    parts = human.build_parts(pose, (layer,))
    r = render([_occ(p) for p in parts["body"] + extra] + parts[layer] + hidden, w, h, origin, view)
    return _strip_occluders(r, w, h) + (None,)


def render_garment_alone(layer: str, pose: human.Pose, view: View, w: int, h: int, origin: tuple) -> Image.Image:
    """La prenda sin cuerpo (para iconos)."""
    return render(human.build_parts(pose, (layer,))[layer], w, h, origin, view).color


def _strip_occluders(r, w: int, h: int, garment: bool = True) -> tuple[Image.Image, Image.Image]:
    """Deja solo lo que se dibuja en esta capa. "occ" (el cuerpo, al pintar una prenda) se borra
    dejando una sombra de contacto junto a la prenda; "hide" (el colchón) se borra sin más."""
    cells = r.depth
    color = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    normal = Image.new("RGBA", (w, h), (128, 128, 255, 0))
    src_color = r.color.load()
    src_normal = r.normal.load()
    dst_color = color.load()
    dst_normal = normal.load()

    def visible(x: int, y: int) -> bool:
        if 0 <= x < w and 0 <= y < h:
            c = cells[y * w + x]
            return c is not None and c[0] not in ("occ", "hide")
        return False

    for y in range(h):
        for x in range(w):
            c = cells[y * w + x]
            src = src_color[x, y]
            if c is not None and c[0] == "hide":
                continue  # lo tapa la camilla (que ya tiene su dibujo): ni cuerpo ni contorno
            if c is None:
                # Contorno: solo si lo provoca lo que se dibuja.
                for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                    if src[3] and visible(x + dx, y + dy):
                        dark = RAMPS[cells[(y + dy) * w + x + dx][0].lstrip("!")][0]
                        dst_color[x, y] = (*(int(dark[i] * 0.45 + OUTLINE[i] * 0.55) for i in range(3)), 255)
                        dst_normal[x, y] = src_normal[x + dx, y + dy]
                        break
                continue
            if c[0] != "occ":
                dst_color[x, y] = src
                dst_normal[x, y] = src_normal[x, y]
                continue
            if not garment:
                continue
            # Cuerpo junto al borde de la prenda que está por delante: sombra de contacto.
            for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                if visible(x + dx, y + dy) and c[3] - cells[(y + dy) * w + x + dx][3] > 1.2:
                    dst_color[x, y] = (*OUTLINE, 120)
                    dst_normal[x, y] = src_normal[x + dx, y + dy]
                    break
    return color, normal


def view_for(sheet: str, row: int, column: int) -> View:
    if sheet == "getup":
        _, b, ambient, _ = motion.getup_pose(column)
        return View(b=b, ambient=ambient)
    return View(yaw=yaws(SHEETS[sheet]["rows"])[row])


def render_frame(layer: str, sheet: str, row: int, column: int):
    if sheet == "getup":
        pose, b, ambient, blanket = motion.getup_pose(column)
        w, h = frame_size(sheet)
        return render_layer(layer, pose, View(b=b, ambient=ambient), w, h, frame_origin(sheet), blanket,
                            motion.bed_occluders())
    return render_layer(layer, pose_for(sheet, column), view_for(sheet, row, column))


def _job(args: tuple) -> tuple:
    layer, sheet, row, column = args
    color, normal, glow = render_frame(layer, sheet, row, column)
    pack = lambda img: (img.tobytes() if img is not None else None)  # noqa: E731
    return layer, sheet, row, column, pack(color), pack(normal), pack(glow)


def _screen(p: tuple, yaw: float, view: View) -> tuple[float, float]:
    """Punto del modelo (girado con `yaw`) a píxeles respecto a los pies."""
    q = rot_y(p, yaw)
    return q[0], -(view.a * q[1] - view.b * q[2])


def frame_data(sheet: str) -> tuple[list, list]:
    """Por fila y columna: posición de la lente ([x, y] o None) y de la mano libre
    ([x, y, ángulo en grados del arma, 1 si va por delante del cuerpo])."""
    view = View()
    spec = SHEETS[sheet]
    lens, hands = [], []
    for row, yaw in enumerate(yaws(spec["rows"])):
        row_lens, row_hand = [None] * spec["columns"], [None] * spec["columns"]
        for col in range(spec["columns"]):
            pose = pose_for(sheet, col)
            if pose.flashlight:
                x, y = _screen(human.lens_position(pose), yaw, view)
                row_lens[col] = [round(x, 1), round(y, 1)]
            palm, fore, axis = human.hand_info(pose, 1.0)
            x, y = _screen(palm, yaw, view)
            tip = tuple(palm[i] + axis[i] * 6.0 for i in range(3))
            tx, ty = _screen(tip, yaw, view)
            # Delante o detrás del cuerpo: profundidad hacia la cámara respecto al pecho.
            chest = human.to_final(pose, (0.0, 40.0 + human._bob(pose), 0.3))
            depth = lambda p: rot_y(p, yaw)[2] * view.a + p[1] * view.b  # noqa: E731
            front = 1 if depth(palm) > depth(chest) + 0.5 else 0
            row_hand[col] = [round(x, 1), round(y, 1), round(math.degrees(math.atan2(ty - y, tx - x)), 1), front]
        lens.append(row_lens)
        hands.append(row_hand)
    return lens, hands


def layer_path(layer: str, sheet: str = "move") -> str:
    suffix = SHEETS[sheet]["suffix"]
    return f"{BODY_PATH[:-4]}{suffix}.png" if layer == "body" else f"{WEAR_DIR}/{layer}{suffix}.png"


def build(layers: list[str] | None = None, sheets: list[str] | None = None, processes: int | None = None,
          meta: dict | None = None) -> dict:
    """Renderiza las capas y hojas pedidas y devuelve la entrada de sprite_meta (conservando de
    `meta` las hojas que no se tocan)."""
    layers = layers or ["body"] + list(human.GARMENTS)
    sheets = sheets or list(SHEETS)
    images: dict[tuple[str, str], list] = {}
    jobs = []
    for sheet in sheets:
        spec = SHEETS[sheet]
        w, h = frame_size(sheet)
        size = (w * spec["columns"], h * spec["rows"])
        assert size[0] <= 16384 and size[1] <= 16384, (sheet, size)
        for layer in layers:
            images[(layer, sheet)] = [Image.new("RGBA", size, (0, 0, 0, 0)), Image.new("RGBA", size, (128, 128, 255, 0)),
                                      Image.new("RGBA", size, (0, 0, 0, 0))]
            jobs += [(layer, sheet, row, col) for row in range(spec["rows"]) for col in range(spec["columns"])]
    # Primero lo caro (prendas largas) para repartir mejor.
    jobs.sort(key=lambda j: j[0] not in ("bata_medico", "bata_paciente", "chaqueta_celador"))
    start = time.time()
    with Pool(processes or max(1, (os.cpu_count() or 2) - 1)) as pool:
        for n, (layer, sheet, row, col, c, nm, g) in enumerate(pool.imap_unordered(_job, jobs, chunksize=8)):
            w, h = frame_size(sheet)
            at = (col * w, row * h)
            imgs = images[(layer, sheet)]
            imgs[0].paste(Image.frombytes("RGBA", (w, h), c), at)
            imgs[1].paste(Image.frombytes("RGBA", (w, h), nm), at)
            if g is not None:
                imgs[2].paste(Image.frombytes("RGBA", (w, h), g), at)
            if n % 500 == 0:
                print(f"   {n}/{len(jobs)} fotogramas ({time.time() - start:.0f} s)", flush=True)
    for (layer, sheet), (color, normal, glow) in images.items():
        path = ROOT / layer_path(layer, sheet)
        path.parent.mkdir(parents=True, exist_ok=True)
        color.save(path, optimize=True)
        normal.save(path.with_name(path.stem + "_n.png"), optimize=True)
        glow_path = path.with_name(path.stem + "_glow.png")
        if layer == "body" and glow.getbbox() is not None:
            glow.save(glow_path, optimize=True)
        elif layer == "body" and glow_path.exists():
            glow_path.unlink()  # hoja sin linterna: sin capa de brillo
        print("  ", layer_path(layer, sheet), f"{color.width}x{color.height}")
    return describe(sheets, meta)


def describe(sheets: list[str], meta: dict | None = None) -> dict:
    """Entrada "protagonist" de sprite_meta.json."""
    old = (meta or {}).get("sheets", {})
    out_sheets = {}
    for name, spec in SHEETS.items():
        if name not in sheets and name in old:
            out_sheets[name] = old[name]
            continue
        w, h = frame_size(name)
        entry = {"suffix": spec["suffix"], "frame": [w, h], "origin": list(frame_origin(name)),
                 "hframes": spec["columns"], "vframes": spec["rows"], "flash": spec["flash"],
                 "anims": {k: list(v) for k, v in spec["anims"].items()},
                 "glow": (ROOT / layer_path("body", name)).with_name(Path(layer_path("body", name)).stem + "_glow.png").exists()}
        if name.startswith("action"):
            entry["fps"] = {k: v[1] for k, v in motion.ACTIONS.items()}
        if name == "getup":
            entry["fps"] = motion.GETUP_FPS
            entry["stand"] = [motion.STAND_AT[0], motion.STAND_AT[2] * motion.MAP_B]
            entry["sounds"] = {str(k): list(v) for k, v in motion.GETUP_SOUNDS.items()}
        else:
            lens, hands = frame_data(name)
            entry["hand"] = hands
            if spec["flash"]:
                entry["lens"] = lens
        out_sheets[name] = entry
    w, h = human.FRAME_W, human.FRAME_H
    return {"path": "res://" + BODY_PATH, "frame": [w, h], "hframes": MOVE_COLUMNS, "vframes": DIRECTIONS,
            "origin": list(human.ORIGIN), "anchor": [0, 0], "glow": True, "columns": MOVE_COLUMNS,
            "anims": {k: list(v) for k, v in MOVE_ANIMS.items()}, "sheets": out_sheets,
            "wear": {g: {"path": "res://" + layer_path(g), "slot": slot} for g, slot in human.GARMENTS.items()}}


def main() -> None:
    args = sys.argv[1:]
    sheets, procs, layers = None, None, []
    while args:
        a = args.pop(0)
        if a == "--sheets":
            sheets = args.pop(0).split(",")
        elif a == "--procs":
            procs = int(args.pop(0))
        else:
            layers.append(a)
    meta_path = ROOT / "tools/art/sprite_meta.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    meta["protagonist"] = build(layers or None, sheets, procs, meta.get("protagonist"))
    meta_path.write_text(json.dumps(meta, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
