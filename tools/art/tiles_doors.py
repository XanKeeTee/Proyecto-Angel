"""Puertas que se cruzan andando (sin fundido): marco y hoja como sprite, y suelo del paso.

Genera dos imágenes (con su mapa de normales):

  assets/tilesets/door_frame.png   hoja de 6 fotogramas de 32x128 (casilla de remate + 3 tramos de pared):
                                   0 cerrada / 1 abierta (planta), 2 / 3 (sótano, hormigón), 4 / 5 (quirófano, azulejo).
                                   Es lo que queda POR ENCIMA del jugador cuando cruza: remate, dintel, jambas y hoja.
                                   El hueco de la puerta abierta es transparente: deja ver el suelo del paso.
  assets/tilesets/hospital_doors.png  atlas de 2 columnas x 4 filas de 32 px: suelo del paso por dentro del muro
                                   (fila 0 = casilla del remate, filas 1-3 = tramos de la pared), columna 0 linóleo,
                                   columna 1 hormigón. No tiene colisión: la pone la puerta cuando está cerrada.

Uso (desde la raíz del repo):
    python3 -I tools/art/tiles_doors.py
Después: "$GODOT_BIN" --headless --path . --import  y  tools/levels/build_hospital.tscn
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

import tiles  # noqa: E402
import tiles_extra  # noqa: E402
from tiles import Canvas, T, _hash2, cap_tile, pnoise, wall_column  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
STYLES = ("ward", "basement", "or")
# Hueco de la puerta dentro de la columna de pared (x, y respecto a la pared de 96 px).
X0, X1, TOP = 4, 27, 10


def _wall(style: str) -> Canvas:
    if style == "basement":
        return tiles_extra.concrete_column(0)
    if style == "or":
        return tiles_extra.or_wall_column()
    return wall_column(0)


def frame_column(style: str, open_: bool) -> Canvas:
    """Remate (32 px) + pared (96 px) con el marco y la hoja."""
    c = Canvas(T, T * 4, fill="none")
    cap = cap_tile()
    wall = _wall(style)
    for y in range(T):
        for x in range(T):
            c.set(x, y, cap.mat[y][x], cap.lum[y][x], cap.height[y][x])
    for y in range(96):
        for x in range(T):
            c.set(x, T + y, wall.mat[y][x], wall.lum[y][x], wall.height[y][x])
    # Marco metálico.
    for y in range(TOP - 2, 96):
        for x in range(X0 - 2, X1 + 3):
            c.set(x, T + y, "metal", 0.25 if style != "basement" else 0.2, 1.5)
    for y in range(TOP, 96):
        for x in range(X0, X1 + 1):
            if open_:
                c.set(x, T + y, "none")
                continue
            n = pnoise(x, y, 4, 61, 0, 0)
            rust = 0.82 if style != "basement" else 0.6
            lum = 0.45 + 0.15 * (n - 0.5) - 0.1 * (y / 96) - (0.08 if style == "basement" else 0.0)
            mat = "rust" if pnoise(x, y, 3, 62, 0, 0) > rust else "door"
            c.set(x, T + y, mat, lum, 0.8 + 0.6 * (n - 0.5))
    if open_:
        # Hoja abierta hacia dentro, vista de canto contra la jamba izquierda, y sombra bajo el dintel.
        for y in range(TOP, 96):
            for x in range(X0, X0 + 3):
                c.set(x, T + y, "door", 0.5 if x == X0 + 2 else 0.35, 1.5)
        for x in range(X0 + 3, X1 + 1):
            c.set(x, T + TOP, "void", 0.1, -1.0)
        return c
    if style == "ward":  # ventanilla con malla
        for y in range(22, 38):
            for x in range(10, 22):
                edge = y in (22, 37) or x in (10, 21)
                mesh = (x + y) % 4 == 0 or (x - y) % 4 == 0
                c.set(x, T + y, "metal" if edge else "glass", 0.4 if edge else (0.35 if mesh else 0.12), 1.0 if edge else -1.0)
        c.set(12, T + 24, "glass", 0.9)
    elif style == "or":  # ojo de buey
        for y in range(18, 40):
            for x in range(T):
                d = ((x + 0.5 - 16) ** 2 + (y + 0.5 - 28) ** 2) ** 0.5
                if d < 6:
                    c.set(x, T + y, "glass", 0.12 if d < 5 else 0.0, -1.0)
                elif d < 7.2:
                    c.set(x, T + y, "metal", 0.5, 1.5)
    else:  # rejilla de ventilación en la hoja del sótano
        for y in range(70, 80):
            for x in range(9, 23):
                c.set(x, T + y, "void" if y % 2 else "metal", 0.1 if y % 2 else 0.45, -1.0 if y % 2 else 1.2)
    for y in range(54, 58):  # manilla
        c.set(23, T + y, "metal", 0.8, 2.5)
        c.set(24, T + y, "metal", 0.5, 2.5)
    for y in range(80, 94):  # chapa de protección
        for x in range(X0 + 1, X1):
            c.set(x, T + y, "metal", 0.22 + 0.15 * _hash2(x, y // 3, 63), 1.2)
    return c


def passage_tile(floor: str, row: int) -> Canvas:
    """Suelo del paso por dentro del muro: oscurece hacia arriba (hacia el otro lado) y en las jambas."""
    base = tiles.lino_tile(0) if floor == "lino" else tiles_extra.concrete_floor(0)
    c = Canvas(T, T)
    for y in range(T):
        for x in range(T):
            depth = (row * T + y) / (4 * T)  # 0 arriba (remate) .. 1 abajo (umbral del pasillo)
            side = min(x - X0, X1 - x)
            shade = 0.35 + 0.55 * depth
            if side < 3:
                shade *= 0.55 + 0.15 * max(0, side)
            c.set(x, y, base.mat[y][x], base.lum[y][x] * shade, base.height[y][x])
    if row == 3:  # umbral metálico donde empieza el pasillo
        for x in range(X0, X1 + 1):
            c.set(x, T - 2, "metal", 0.45, 1.5)
            c.set(x, T - 1, "metal", 0.25, 0.5)
    return c


def _save(rel: str, canvases: list[tuple[Canvas, int, int]], w: int, h: int) -> None:
    color = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    normal = Image.new("RGBA", (w, h), (128, 128, 255, 0))
    for canvas, x, y in canvases:
        img, nrm = canvas.to_images()
        color.paste(img, (x, y))
        normal.paste(nrm, (x, y))
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    color.save(path)
    normal.save(path.with_name(path.stem + "_n.png"))
    print("  ", rel, f"{w}x{h}")


def build() -> None:
    frames = []
    for i, style in enumerate(STYLES):
        frames.append((frame_column(style, False), (2 * i) * T, 0))
        frames.append((frame_column(style, True), (2 * i + 1) * T, 0))
    _save("assets/tilesets/door_frame.png", frames, T * 6, T * 4)
    passage = []
    for col, floor in enumerate(("lino", "concrete")):
        for row in range(4):
            passage.append((passage_tile(floor, row), col * T, row * T))
    _save("assets/tilesets/hospital_doors.png", passage, T * 2, T * 4)


if __name__ == "__main__":
    build()
