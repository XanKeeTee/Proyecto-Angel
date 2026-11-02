"""Genera todo el arte PROVISIONAL del hospital: personaje, objetos, tiles y calcomanías.

Uso (desde la raíz del repo):
    python -I tools/art/build_all.py                       # todo
    python -I tools/art/build_all.py props tiles decals    # solo esos pasos (ver STEPS)
    python -I tools/art/build_all.py props --preview=/tmp/hoja.png   # y una hoja de revisión

Cada imagen va con su mapa de normales (`*_n.png`) para las luces 2D de Godot y,
si emite luz, con una capa `*_glow.png` que se dibuja sin sombra.
`tools/art/sprite_meta.json` guarda tamaño de fotograma, nº de fotogramas y el píxel
de apoyo de cada sprite (dónde toca el suelo), que usa la escena para colocarlos.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

import doc_images  # noqa: E402
import human  # noqa: E402
import items  # noqa: E402
import props  # noqa: E402
import props2  # noqa: E402
import sounds  # noqa: E402
import tiles  # noqa: E402
from pxrender import View, composite, render  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
META: dict[str, dict] = {}


def save_pair(rel: str, color: Image.Image, normal: Image.Image, glow: Image.Image | None = None) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    color.save(path)
    normal.save(path.with_name(path.stem + "_n.png"))
    if glow is not None:
        glow.save(path.with_name(path.stem + "_glow.png"))
    print("  ", rel, f"{color.width}x{color.height}")


def sheet(name: str, rel: str, frames: list, w: int, h: int, origin: tuple[int, int], anchor: tuple[int, int] = (0, 0),
          rows: int = 1, glow: bool = False) -> None:
    cols = len(frames) // rows
    placed = [(r, (i % cols) * w, (i // cols) * h) for i, r in enumerate(frames)]
    color, normal = composite(placed, w * cols, h * rows)
    glow_img = None
    if glow:
        glow_img = Image.new("RGBA", color.size, (0, 0, 0, 0))
        for r, x, y in placed:
            glow_img.alpha_composite(r.glow(), (x, y))
    save_pair(rel, color, normal, glow_img)
    META[name] = {"path": "res://" + rel, "frame": [w, h], "hframes": cols, "vframes": rows,
                  "origin": list(origin), "anchor": list(anchor), "glow": glow}


# Columnas de la hoja del protagonista (por fila de orientación): inicio y nº de fotogramas.
ANIMS = {"idle": (0, 8), "fidget": (8, 12), "walk": (20, 12), "idle_flash": (32, 8), "look": (40, 12), "walk_flash": (52, 12)}
COLUMNS = 64
# 8 orientaciones, en el orden del ángulo en pantalla: abajo, abajo-izq., izq., arriba-izq.,
# arriba, arriba-der., der., abajo-der. (fila = round((ángulo - 90°) / 45°) mod 8).
YAWS = (0.0, -math.pi / 4, -math.pi / 2, -3 * math.pi / 4, math.pi, 3 * math.pi / 4, math.pi / 2, math.pi / 4)


def _pose_for(anim: str, i: int):
    t = i / ANIMS[anim][1]
    return {
        "idle": lambda: human.idle_pose(t),
        "fidget": lambda: human.fidget_pose(t),
        "walk": lambda: human.walk_pose(t),
        "idle_flash": lambda: human.idle_pose(t, True),
        "look": lambda: human.look_pose(t),
        "walk_flash": lambda: human.walk_pose(t, True),
    }[anim]()


def build_protagonist() -> None:
    from pxrender import rot_y
    frames = []
    lens = []
    lens_frames = []
    view = View()
    for yaw in YAWS:
        row_lens = [None] * COLUMNS
        for anim in ANIMS:
            start, count = ANIMS[anim]
            for i in range(count):
                pose = _pose_for(anim, i)
                frames.append(render(human.build_pose(pose), human.FRAME_W, human.FRAME_H, human.ORIGIN, View(yaw=yaw)))
                if pose.flashlight:
                    p = rot_y(human.lens_position(pose), yaw)
                    # Píxel de la lente respecto a los pies (el nodo del jugador).
                    row_lens[start + i] = [round(p[0], 1), round(-(view.a * p[1] - view.b * p[2]), 1)]
        lens_frames.append(row_lens)
        p0 = rot_y(human.lens_position(human.idle_pose(0.0, True)), yaw)
        lens.append({"screen": [round(p0[0], 1), round(-(view.a * p0[1] - view.b * p0[2]), 1)],
                     "floor": [round(p0[0], 1), round(view.b * p0[2], 1)]})
    sheet("protagonist", "assets/sprites/characters/protagonist.png", frames, human.FRAME_W, human.FRAME_H,
          human.ORIGIN, rows=len(YAWS), glow=True)
    META["protagonist"]["anims"] = {k: list(v) for k, v in ANIMS.items()}
    META["protagonist"]["columns"] = COLUMNS
    META["protagonist"]["lens"] = lens
    META["protagonist"]["lens_frames"] = lens_frames


def build_lights() -> None:
    import lights
    for name, img in (("light_round", lights.round_light()), ("flashlight_cone", lights.flashlight_cone())):
        path = ROOT / f"assets/sprites/lights/{name}.png"
        img.save(path)
        print("  ", path.relative_to(ROOT).as_posix(), f"{img.width}x{img.height}")


def _r(prims: list, w: int, h: int, origin: tuple[int, int], view: View | None = None, kind: str = "ground"):
    """Render con sombra de contacto horneada (ver shadow.py)."""
    import shadow
    return shadow.render_shadowed(prims, w, h, origin, view or props.MAP_VIEW, kind)


def build_props() -> None:
    import props3
    # Camilla: 0 correas abrochadas, 1 tumbado, 2 sentado, 3 revuelta, 4 destrozada, 5 cadáver tapado, 6 sábana sin nadie.
    sheet("stretcher", "assets/sprites/props/stretcher.png",
          [_r(f, 40, 112, (20, 74)) for f in props.stretcher_frames() + props2.stretcher_extra()], 40, 112, (20, 74),
          anchor=(0, -16))
    sheet("iv_stand", "assets/sprites/props/iv_stand.png", [_r(props.iv_stand(), 28, 88, (14, 80))], 28, 88, (14, 80))
    sheet("monitor", "assets/sprites/props/monitor.png", [_r(props.monitor(), 32, 72, (16, 64))], 32, 72, (16, 64),
          glow=True)
    sheet("locker", "assets/sprites/props/locker.png", [_r(props3.locker(i), 44, 92, (22, 72)) for i in range(3)],
          44, 92, (22, 72), anchor=(0, -8))
    sheet("tray", "assets/sprites/props/tray.png", [_r(props.tray(), 32, 56, (16, 44))], 32, 56, (16, 44))
    sheet("wheelchair", "assets/sprites/props/wheelchair.png", [_r(props.wheelchair(), 52, 60, (26, 42))], 52, 60, (26, 42))
    sheet("trash_bin", "assets/sprites/props/trash_bin.png", [_r(props3.trash_bin(i), 28, 44, (14, 32)) for i in range(2)],
          28, 44, (14, 32))
    sheet("sink", "assets/sprites/props/sink.png", [_r(props.sink(), 28, 48, (14, 38), kind="wall")], 28, 48, (14, 38),
          anchor=(0, -10))
    sheet("curtain", "assets/sprites/props/curtain.png", [_r(props.curtain(), 68, 80, (34, 70))], 68, 80, (34, 70),
          anchor=(16, 0))
    sheet("chair", "assets/sprites/props/chair.png", [_r(props.chair(f), 32, 52, (16, 40)) for f in (False, True)],
          32, 52, (16, 40))
    sheet("emergency_light", "assets/sprites/props/emergency_light.png",
          [_r(props.emergency_light(on), 16, 12, (8, 6), props.WALL_VIEW, "wall") for on in (True, False)], 16, 12, (8, 6),
          glow=True)


def build_props2() -> None:
    import props3
    w = props.WALL_VIEW

    def n(fn, count: int) -> list:
        return [lambda i=i: fn(i) for i in range(count)]

    def frames(fns: list, fw: int, fh: int, origin: tuple[int, int], view: View | None = None, kind: str = "ground") -> list:
        return [_r(fn(), fw, fh, origin, view, kind) for fn in fns]

    two = lambda f: [lambda: f(False), lambda: f(True)]  # noqa: E731
    sheet("nightstand", "assets/sprites/props/nightstand.png", frames(n(props3.nightstand, 3), 28, 48, (14, 36)), 28, 48,
          (14, 36), anchor=(0, -4))
    sheet("desk", "assets/sprites/props/desk.png", frames(n(props3.desk, 3), 72, 64, (36, 44)), 72, 64, (36, 44), anchor=(16, 0))
    sheet("workbench", "assets/sprites/props/workbench.png", frames(n(props3.workbench, 3), 72, 64, (36, 44)), 72, 64, (36, 44),
          anchor=(16, 0))
    sheet("computer", "assets/sprites/props/computer.png", frames(two(props2.computer), 24, 56, (12, 52), kind="none"), 24, 56,
          (12, 52), anchor=(1, 0), glow=True)
    sheet("phone", "assets/sprites/props/phone.png", frames(two(props2.phone), 24, 20, (12, 14), kind="none"), 24, 20, (12, 14),
          anchor=(0, -25))
    sheet("filing_cabinet", "assets/sprites/props/filing_cabinet.png", frames(n(props3.filing_cabinet, 3), 28, 72, (14, 56)),
          28, 72, (14, 56), anchor=(0, -6))
    sheet("shelf", "assets/sprites/props/shelf.png", frames(n(props3.shelf, 4), 72, 84, (36, 70)), 72, 84, (36, 70),
          anchor=(16, -10))
    sheet("med_cabinet", "assets/sprites/props/med_cabinet.png", frames(n(props3.med_cabinet, 3), 36, 72, (18, 66), kind="wall"),
          36, 72, (18, 66), anchor=(0, -10))
    sheet("counter", "assets/sprites/props/counter.png", frames(n(props3.counter, 3), 72, 60, (36, 43)), 72, 60, (36, 43),
          anchor=(16, -6))
    sheet("op_table", "assets/sprites/props/op_table.png", frames([props2.op_table], 32, 96, (16, 62)), 32, 96, (16, 62),
          anchor=(0, -16))
    sheet("op_lamp", "assets/sprites/props/op_lamp.png", frames(two(props2.op_lamp), 48, 88, (16, 76)), 48, 88, (16, 76), glow=True)
    sheet("morgue", "assets/sprites/props/morgue.png", frames(n(props3.morgue, 3), 68, 92, (34, 66)), 68, 92, (34, 66),
          anchor=(16, -8))
    sheet("elec_panel", "assets/sprites/props/elec_panel.png", frames(n(props3.elec_panel, 4), 44, 108, (24, 100), kind="wall"),
          44, 108, (24, 100), anchor=(0, -10))
    sheet("generator", "assets/sprites/props/generator.png", frames(two(props3.generator), 76, 76, (38, 56)), 76, 76, (38, 56),
          anchor=(16, -16), glow=True)
    sheet("boiler", "assets/sprites/props/boiler.png", frames([props3.boiler], 40, 92, (18, 80)), 40, 92, (18, 80), anchor=(0, -6))
    sheet("crates", "assets/sprites/props/crates.png", frames([props3.crates], 32, 48, (16, 38)), 32, 48, (16, 38))
    sheet("tape_recorder", "assets/sprites/props/tape_recorder.png", frames([props3.tape_recorder], 32, 52, (16, 36)), 32, 52,
          (16, 36), glow=True)
    sheet("wall_lamp", "assets/sprites/props/wall_lamp.png", frames(two(props2.wall_lamp)[::-1], 20, 10, (10, 4), w, "wall"),
          20, 10, (10, 4), glow=True)
    sheet("laundry_cart", "assets/sprites/props/laundry_cart.png", frames(n(props3.laundry_cart, 2), 40, 54, (16, 38)), 40, 54,
          (16, 38))
    sheet("mop_bucket", "assets/sprites/props/mop_bucket.png", frames([props2.mop_bucket], 24, 48, (12, 40)), 24, 48, (12, 40))


def build_props3() -> None:
    """Decorado no interactivo (props3.DRESSING), con sombra de contacto."""
    import props3
    for key, (fns, fw, fh, origin, kind) in props3.DRESSING.items():
        sheet(key, f"assets/sprites/props/{key}.png", [_r(fn(), fw, fh, origin, None, kind) for fn in fns], fw, fh, origin)


def build_items() -> None:
    built = items.build(ROOT / "assets/sprites/items")
    print("  ", "assets/sprites/items/", f"{len(built)} objetos (icono + 8 vistas)")


def build_tiles() -> None:
    color, normal = tiles.build()
    save_pair("assets/tilesets/hospital.png", color, normal)


def build_decals() -> None:
    """Calcomanías de suelo (32 y 64 px) y de pared (32x96): ver decals.py."""
    import decals
    for key, (color, normal, glow, names, w, h) in decals.build().items():
        rel = f"assets/sprites/decals/{key}.png"
        save_pair(rel, color, normal, glow)
        META[key] = {"path": "res://" + rel, "frame": [w, h], "hframes": len(names), "vframes": 1,
                     "origin": [w // 2, h // 2], "anchor": [0, 0], "glow": glow is not None, "names": names}


def preview() -> None:
    """Hoja de revisión ampliada (no se usa en el juego)."""
    items = []
    for name, meta in META.items():
        img = Image.open(ROOT / meta["path"].removeprefix("res://"))
        items.append(img)
    width = sum(i.width + 6 for i in items)
    height = max(i.height for i in items)
    canvas = Image.new("RGBA", (width, height), (48, 48, 56, 255))
    x = 0
    for img in items:
        canvas.alpha_composite(img.convert("RGBA"), (x, height - img.height))
        x += img.width + 6
    out = next((Path(a[10:]) for a in sys.argv[1:] if a.startswith("--preview=")), None)
    if out:
        canvas.resize((canvas.width * 2, canvas.height * 2), Image.NEAREST).save(out)


STEPS = {
    "tiles": lambda: build_tiles(),
    "decals": lambda: build_decals(),
    "lights": lambda: build_lights(),
    "protagonist": lambda: build_protagonist(),
    "props": lambda: (build_props(), build_props2(), build_props3()),
    "items": lambda: build_items(),
    "sounds": lambda: sounds.build(),
    "docs": lambda: doc_images.build(),
}


def main() -> None:
    """Sin argumentos genera todo. Con nombres de pasos (p. ej. `props tiles decals`) genera solo
    esos y conserva el resto de `sprite_meta.json`: así no se regeneran sonidos ni personaje sin querer."""
    wanted = [a for a in sys.argv[1:] if not a.startswith("--")]
    unknown = [a for a in wanted if a not in STEPS]
    if unknown:
        sys.exit(f"Pasos desconocidos: {unknown}. Disponibles: {', '.join(STEPS)}")
    meta_path = ROOT / "tools/art/sprite_meta.json"
    if wanted and meta_path.exists():
        META.update(json.loads(meta_path.read_text(encoding="utf-8")))
    print("Generando arte provisional del hospital:", ", ".join(wanted) if wanted else "todo")
    for name, step in STEPS.items():
        if not wanted or name in wanted:
            step()
    meta_path.write_text(json.dumps(META, indent=1), encoding="utf-8")
    preview()


if __name__ == "__main__":
    main()
