"""Genera todo el arte PROVISIONAL del hospital: personaje, objetos, tiles y calcomanías.

Uso (desde la raíz del repo):
    python -I tools/art/build_all.py

Cada imagen va con su mapa de normales (`*_n.png`) para las luces 2D de Godot y,
si emite luz, con una capa `*_glow.png` que se dibuja sin sombra.
`tools/art/sprite_meta.json` guarda tamaño de fotograma, nº de fotogramas y el píxel
de apoyo de cada sprite (dónde toca el suelo), que usa la escena para colocarlos.
"""

from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

import human  # noqa: E402
import props  # noqa: E402
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


# Columnas de la hoja del protagonista (por fila de dirección).
ANIMS = {"idle": (0, 4), "walk": (4, 8), "idle_flash": (12, 4), "walk_flash": (16, 8)}
# 8 orientaciones, en el orden del ángulo en pantalla: abajo, abajo-izq., izq., arriba-izq.,
# arriba, arriba-der., der., abajo-der. (fila = round((ángulo - 90°) / 45°) mod 8).
YAWS = (0.0, -math.pi / 4, -math.pi / 2, -3 * math.pi / 4, math.pi, 3 * math.pi / 4, math.pi / 2, math.pi / 4)


def _pose_for(anim: str, i: int):
    count = ANIMS[anim][1]
    flash = anim.endswith("flash")
    if anim.startswith("idle"):
        return human.idle_pose(i / count, flash)
    return human.walk_pose(i / count, flash)


def build_protagonist() -> None:
    frames = []
    lens = []
    view = View()
    for yaw in YAWS:
        for anim in ANIMS:
            for i in range(ANIMS[anim][1]):
                frames.append(render(human.build_pose(_pose_for(anim, i)), human.FRAME_W, human.FRAME_H, human.ORIGIN,
                                     View(yaw=yaw)))
        # Lente en reposo con linterna: posición en pantalla y su proyección en el suelo.
        from pxrender import rot_y
        p = rot_y(human.lens_position(human.idle_pose(0.0, True)), yaw)
        lens.append({"screen": [round(p[0], 1), round(-(view.a * p[1] - view.b * p[2]), 1)],
                     "floor": [round(p[0], 1), round(view.b * p[2], 1)]})
    sheet("protagonist", "assets/sprites/characters/protagonist.png", frames, human.FRAME_W, human.FRAME_H,
          human.ORIGIN, rows=len(YAWS), glow=True)
    META["protagonist"]["anims"] = {k: list(v) for k, v in ANIMS.items()}
    META["protagonist"]["lens"] = lens


def build_lights() -> None:
    import lights
    for name, img in (("light_round", lights.round_light()), ("flashlight_cone", lights.flashlight_cone())):
        path = ROOT / f"assets/sprites/lights/{name}.png"
        img.save(path)
        print("  ", path.relative_to(ROOT).as_posix(), f"{img.width}x{img.height}")


def build_props() -> None:
    v = props.MAP_VIEW
    sheet("stretcher", "assets/sprites/props/stretcher.png",
          props.render_sheet(props.stretcher_frames(), 40, 112, (20, 74), v), 40, 112, (20, 74), anchor=(0, -16))
    sheet("iv_stand", "assets/sprites/props/iv_stand.png", [render(props.iv_stand(), 24, 84, (12, 78), v)], 24, 84, (12, 78))
    sheet("monitor", "assets/sprites/props/monitor.png", [render(props.monitor(), 32, 72, (16, 64), v)], 32, 72, (16, 64),
          glow=True)
    sheet("locker", "assets/sprites/props/locker.png",
          [render(props.locker(o), 32, 90, (16, 76), v) for o in (False, True)], 32, 90, (16, 76), anchor=(0, -8))
    sheet("tray", "assets/sprites/props/tray.png", [render(props.tray(), 32, 56, (16, 44), v)], 32, 56, (16, 44))
    sheet("wheelchair", "assets/sprites/props/wheelchair.png", [render(props.wheelchair(), 48, 56, (24, 40), v)], 48, 56, (24, 40))
    sheet("trash_bin", "assets/sprites/props/trash_bin.png", [render(props.trash_bin(), 20, 36, (10, 28), v)], 20, 36, (10, 28))
    sheet("sink", "assets/sprites/props/sink.png", [render(props.sink(), 28, 48, (14, 38), v)], 28, 48, (14, 38), anchor=(0, -10))
    sheet("curtain", "assets/sprites/props/curtain.png", [render(props.curtain(), 68, 80, (34, 70), v)], 68, 80, (34, 70),
          anchor=(16, 0))
    sheet("chair", "assets/sprites/props/chair.png", [render(props.chair(f), 28, 48, (14, 38), v) for f in (False, True)],
          28, 48, (14, 38))
    sheet("emergency_light", "assets/sprites/props/emergency_light.png",
          [render(props.emergency_light(on), 16, 12, (8, 6), props.WALL_VIEW) for on in (True, False)], 16, 12, (8, 6),
          glow=True)


def build_tiles() -> None:
    color, normal = tiles.build()
    save_pair("assets/tilesets/hospital.png", color, normal)


def build_decals() -> None:
    """Calcomanías de suelo de 32x32: huellas, papeles, cristales, gotas, arrastre."""
    names = ["footprints", "papers", "glass", "drops", "drag"]
    color = Image.new("RGBA", (32 * len(names), 32), (0, 0, 0, 0))
    normal = Image.new("RGBA", (32 * len(names), 32), (128, 128, 255, 0))
    rng = random.Random(77)
    for i, name in enumerate(names):
        c = tiles.Canvas(32, 32, fill="none")
        if name == "footprints":
            for fx, fy, flip in ((10, 9, -1), (22, 22, 1)):
                c.blob(fx, fy + 1, 1.8, 3.6, "water", 0.12, 1000 + fx, -0.2, rough=0.15)
                c.blob(fx + flip * 0.3, fy - 3.2, 1.6, 1.2, "water", 0.12, 1100 + fx, -0.2, rough=0.1)
                for t in range(5):
                    c.set(int(fx - 2 + t), int(fy - 5.5 + abs(t - 1.5) * 0.4), "water", 0.15, -0.2)
                c.set(fx, fy, "water", 0.85)
        elif name == "papers":
            for _ in range(3):
                cx, cy = rng.uniform(8, 24), rng.uniform(8, 24)
                ang = rng.uniform(0, math.pi)
                for y in range(32):
                    for x in range(32):
                        dx, dy = x - cx, y - cy
                        u = dx * math.cos(ang) + dy * math.sin(ang)
                        w = -dx * math.sin(ang) + dy * math.cos(ang)
                        if abs(u) < 4 and abs(w) < 5.5:
                            line = int(w + 10) % 2 == 0 and abs(u) < 3
                            c.set(x, y, "paper", 0.3 if line else 0.6 + 0.2 * tiles._hash2(x, y, 3), 0.4)
            c.blob(17, 18, 2.5, 1.8, "blood_dry", 0.4, 1201, 0.5)
        elif name == "glass":
            for _ in range(9):
                x, y = rng.randint(5, 27), rng.randint(5, 27)
                c.line([(x, y), (x + rng.choice((-2, 2)), y + rng.choice((-1, 1)))], "glass", 0.7, 0.5)
                c.set(x, y, "glass", 1.0, 0.8)
        elif name == "drops":
            for _ in range(7):
                c.blob(rng.uniform(4, 28), rng.uniform(4, 28), rng.uniform(0.7, 1.5), rng.uniform(0.7, 1.4),
                       "blood_dry", 0.4, rng.randint(0, 9999), 0.3, rough=0.2)
        elif name == "drag":
            for x in range(32):
                y0 = 16 + math.sin(x * 0.25) * 1.5
                width = 3.0 + 1.2 * tiles.pnoise(x, 0, 4, 1301, 32, 0)
                for y in range(32):
                    if abs(y - y0) < width and tiles.pnoise(x, y, 2, 1302, 32, 0) > 0.3:
                        c.set(x, y, "blood_dry", 0.25 + 0.25 * tiles._hash2(x, y, 1303), 0.2)
        img, nrm = c.to_images()
        color.alpha_composite(img, (i * 32, 0))
        normal.paste(nrm, (i * 32, 0), nrm)
    save_pair("assets/sprites/decals/decals.png", color, normal)
    META["decals"] = {"path": "res://assets/sprites/decals/decals.png", "frame": [32, 32], "hframes": len(names),
                      "vframes": 1, "origin": [16, 16], "anchor": [0, 0], "glow": False, "names": names}


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
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    if out:
        canvas.resize((canvas.width * 2, canvas.height * 2), Image.NEAREST).save(out)


def main() -> None:
    print("Generando arte provisional del hospital:")
    build_tiles()
    build_decals()
    build_lights()
    build_protagonist()
    build_props()
    (ROOT / "tools/art/sprite_meta.json").write_text(json.dumps(META, indent=1), encoding="utf-8")
    preview()


if __name__ == "__main__":
    main()
