# Técnica — Proyecto-Angel

Las convenciones de código, comandos y estructura de carpetas están en [CLAUDE.md](../../CLAUDE.md). Aquí va lo que necesita más detalle.

## Documentos

- [arquitectura.md](arquitectura.md) — módulos del prólogo y cómo se amplían.
- [tests.md](tests.md) — propuesta de framework de tests (GUT, pendiente). Mientras tanto hay un ejecutor mínimo (ver CLAUDE.md).

## Configuración del proyecto (provisional)

Valores puestos en `project.godot`. Se pueden cambiar; si se cambian, actualizar esta tabla.

| Ajuste | Valor | Motivo |
|---|---|---|
| Renderer | GL Compatibility | 2D pixel art, máxima compatibilidad de hardware; suficiente para shaders `canvas_item` |
| Resolución base | 640×360 | 16:9, escala entera a 720p (×2), 1080p (×3) y 1440p (×4) |
| Ventana por defecto | 1280×720 | ×2 de la base |
| Stretch | `viewport` + escala `integer` | Píxeles nítidos, sin deformar |
| Filtro de texturas | Nearest | Pixel art sin difuminar |
| Avisos GDScript | `untyped_declaration`, `inferred_declaration` = warning | Empujar al tipado estático |

| Color de fondo | Negro | Lo que queda fuera del mapa no se ve gris |

Tamaño de tile: **32 px** (aprobado).

## Prólogo (hospital)

Arquitectura del código: [arquitectura.md](arquitectura.md). Diseño: [prologo.md](../design/escenas/prologo.md). Inventario: [custodia.md](../design/sistemas/custodia.md).

- **Escena principal**: `res://scenes/ui/title/title_screen.tscn` (título → Nueva partida / Continuar).
- **El hospital**: `res://scenes/world/hospital/hospital.tscn` + `hospital.gd` (guion), que hereda de `WorldController`.
- **Opciones** (`autoload/settings.gd`, menú en `scenes/ui/options_menu.gd`): volúmenes por canal de audio (`Ambiente`, `Efectos` e `Interfaz`, que van al `Master`, con un limitador), brillo (gamma en el shader VHS), intensidad del filtro, pantalla completa y velocidad del texto. Se guardan en `user://settings.cfg`.
- **Guardado**: en las grabadoras de cinta (control de enfermería y sala eléctrica), en `user://saves/slot_0.json`.

### Depuración

Con argumentos tras `--`, el título salta directamente al hospital:

```bash
"$GODOT_BIN" --path . -- --at=30,15 --face=up --give=linterna,pilas --flag=power_on
"$GODOT_BIN" --path . -- --skip-intro --screenshot=captura.png --screenshot-delay=2
```

| Argumento | Qué hace |
|---|---|
| `--skip-intro` / `--at=X,Y` | Empieza con control (en la casilla indicada), sin el despertar |
| `--face=up\|down\|left\|right\|up_left\|…` | Dirección inicial |
| `--give=id,id` | Da objetos (montón completo) |
| `--flag=f,f` | Activa banderas (p. ej. `power_on`, `pasillo_imposible`) |
| `--custody` / `--doc=id` | Abre la custodia (o el expediente en ese documento) |
| `--auto-advance=S` | Los textos avanzan solos |
| `--screenshot=RUTA` y `--screenshot-delay=S` | Captura y cierra. **Abre una ventana** |
| `--no-vhs` | Sin filtro |

### Regenerar contenido

Cada generador recrea sus archivos desde cero. Si se ha retocado algo a mano en el editor, se pierde.

```bash
python -I tools/art/build_all.py
"$GODOT_BIN" --headless --path . --import
"$GODOT_BIN" --headless --path . -s tools/data/build_items.gd
"$GODOT_BIN" --headless --path . -s tools/data/build_documents.gd
"$GODOT_BIN" --headless --path . res://tools/levels/build_player.tscn
"$GODOT_BIN" --headless --path . res://tools/levels/build_hospital.tscn
```

1. `build_all.py` genera el arte (tiles, personaje, objetos, iconos), los sonidos y las imágenes de documentos.
2. `--import` hace que Godot importe todo eso.
3. `build_items` crea los objetos y recetas, `build_documents` los documentos, `build_player` la escena del protagonista y `build_hospital` la del hospital.

El generador del hospital se ejecuta como escena (no con `-s`) porque necesita los autoloads.

### Notas

- **Movimiento libre**: el protagonista es un `CharacterBody2D` (modo flotante) con un círculo de 6 px en los pies; el nodo está en los pies. Colisiona con la capa 1:
  - los tiles con `solid = true` tienen polígono de colisión en la capa de física del tileset;
  - los muebles con `Interactable.blocks` tienen un `StaticBody2D` llamado `Body` con la huella de su `footprint`.
- **Casillas de interacción**: `Interactable.interact_cells`, si está, sustituye a `footprint` para interactuar (p. ej. un escritorio con el ordenador en una casilla y los cajones en la otra).
- **Puertas entre salas**: las de la pared norte cambian sus 4 tiles (3 de puerta y el umbral del otro lado) y llevan al otro lado con un fundido (`Door.warp_*`).
- **Sombras**: solo las tapas de muro, el umbral cerrado y una franja de la puerta cerrada tienen oclusor; los muebles llevan un `LightOccluder2D` llamado `Shadow`.
- **Mapas de normales**: cada sprite y el tileset usan un `CanvasTexture` (`*_canvas.tres`). Las luces llevan `height` alto (70–110).
- **Capas de luz** (`light_mask`):

  | Capa | Qué | La linterna lo ilumina | Recibe sombras |
  |---|---|---|---|
  | 1 | Suelo, paredes, calcomanías, polvo | Sí | Sí |
  | 2 | Protagonista | No (la lleva él) | No |
  | 4 | Muebles | Sí | No |

- **Animación del protagonista**: 64 columnas × 8 orientaciones (ver la guía estética). El paso avanza con la distancia recorrida de verdad; los giros pasan por las orientaciones intermedias; tras un rato quieto, un gesto. La luz de la linterna sale de la lente: `Player.lens_frames` guarda su posición en cada fotograma. El origen de la linterna por orientación sale de `sprite_meta.json` (`lens`).
- **Mandos**: algunos (visto con un DualSense) mandan valores falsos en los primeros fotogramas; por eso el control llega 0,5 s después en el arranque de depuración.

## Prototipo de combate

Ya no es la escena principal: abre `res://scenes/battle/battle_scene.tscn` y pulsa **F6** (ejecutar escena actual), o ejecuta:

```bash
"$GODOT_BIN" --path . res://scenes/battle/battle_scene.tscn
```

- **Controles**: ratón, o flechas + Intro. **F2** activa o desactiva el filtro VHS.
- **Contenido**: 3 aliados (PROTAGONISTA, ALIADO 1, ALIADO 2) contra 2 enemigos (ENEMIGO A, ENEMIGO B). Nombres y gráficos provisionales: rectángulos que cambian de color según el estado de cada parte (hueso = Sana, ámbar = Herida, rojo oscuro = Rota, contorno = Amputada).
- **Datos**: los `.tres` de `data/` se editan desde el inspector de Godot.
- **Depuración** (argumentos tras `--`):

  ```bash
  "$GODOT_BIN" --path . res://scenes/battle/battle_scene.tscn -- --autoplay=3 --screenshot=captura.png
  ```

  `--autoplay=N` juega N rondas solo; `--screenshot=RUTA` guarda una captura y cierra.

Qué incluye: rondas con telegrafiado, ataque por partes, Guardia, Respirar, Vendas, huida individual y en grupo, amputación, fracturas, sangrado, aturdimiento, Mente (Inquietud, Pánico, Quiebre), Caídos y rematar, fin de partida por muerte del protagonista.

Qué falta: habilidades, cargar con un aliado al huir, armaduras por parte, prótesis, curación fuera de combate, sonido y arte.

### Código

| Archivo | Qué hace |
|---|---|
| `scripts/core/*_def.gd`, `combat_types.gd` | Definiciones de datos (`Resource`) y enums |
| `scripts/systems/combat/battle.gd` | Lógica de la ronda; sin nodos, testeable en headless |
| `scripts/systems/combat/combat_rules.gd` | Fórmulas puras |
| `scripts/systems/combat/enemy_ai.gd` | Intenciones enemigas |
| `scenes/battle/` | Escena, silueta de partes (`body_diagram.gd`) |
| `shaders/vhs_post.gdshader` | Grano, aberración, scanlines, viñeta |

## Arquitectura prevista (sin implementar)

- **Datos**: `Resource` con `class_name` en `scripts/core/`, instancias `.tres` en `data/`.
- **Lógica de reglas** (combate, heridas, estados) en clases puras, sin nodos, para testear en headless.
- **Presentación**: escenas en `scenes/` que escuchan señales de la lógica y la representan.
- **Autoloads**: `EventBus`, `GameState`, `SaveSystem`. Nada más sin motivo.
- **Guardado**: pendiente de decidir formato (`ConfigFile`, JSON o `Resource` serializado). Las heridas permanentes y banderas de decisiones deben sobrevivir al guardado y tener test.
