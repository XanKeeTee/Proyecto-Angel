# Técnica — Proyecto-Angel

Las convenciones de código, comandos y estructura de carpetas están en [CLAUDE.md](../../CLAUDE.md). Aquí va lo que necesita más detalle.

## Documentos

- [tests.md](tests.md) — propuesta de framework de tests (pendiente de decisión).

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

## Inicio en el hospital

Escena principal del proyecto: `res://scenes/world/hospital/hospital_intro.tscn` (F5). Diseño en [inicio-hospital.md](../design/escenas/inicio-hospital.md).

- **Controles**: flechas para moverse, Intro para examinar y pasar texto, F2 para el filtro VHS.
- **Depuración** (argumentos tras `--`):

  ```bash
  "$GODOT_BIN" --path . -- --at=20,5 --face=right --screenshot=captura.png
  "$GODOT_BIN" --path . -- --ending --auto-advance=0.8
  ```

  | Argumento | Qué hace |
  |---|---|
  | `--skip-intro` | Empieza con control, sin la secuencia de despertar |
  | `--flashlight` | Empieza con la linterna |
  | `--at=X,Y` / `--face=up\|down\|left\|right` | Casilla y dirección iniciales. En el pasillo da la linterna y abre la puerta |
  | `--ending` | Lanza el final en la puerta doble |
  | `--auto-advance=S` | Los textos avanzan solos (pruebas sin manos) |
  | `--screenshot=RUTA` y `--screenshot-delay=S` | Guarda una captura y cierra (sin control del jugador) |
  | `--no-vhs` | Sin filtro |

| Archivo | Qué hace |
|---|---|
| `scenes/world/hospital/hospital_intro.gd` | Secuencia, eventos (linterna, puerta, huellas, final) y luces |
| `scenes/world/player/player.gd` | Movimiento por casillas, linterna, cámara |
| `scenes/world/interactable.gd` | Objeto o tile examinable; textos en el inspector |
| `scenes/ui/message_box.gd` | Caja de texto, rótulos y pistas |
| `scenes/ui/vhs_overlay.gd` | Filtro VHS reutilizable, `glitch()` para eventos |
| `assets/tilesets/hospital_tileset.tres` | Tiles con dato `solid` (paso) y oclusores (sombras); textura con normales |
| `tools/art/` | Generador del arte provisional (`build_all.py`) y puntos de apoyo (`sprite_meta.json`) |

Notas:
- **Paso**: un tile bloquea si su dato personalizado `solid` es verdadero. Los objetos bloquean con `Interactable.blocks` y su `footprint`.
- **Sombras**: solo las tapas de muro (y una franja de la puerta cerrada) tienen oclusor, así la cara de la pared se ilumina y la luz no atraviesa muros.
- **Mapas de normales**: cada sprite y el tileset usan un `CanvasTexture` (`*_canvas.tres`) con el PNG y su `*_n.png`. Las luces llevan `height` alto (70–110) para que iluminen superficies que miran a cámara; con altura baja todo queda negro.
- **Capas de luz**: el sprite del protagonista usa `light_mask = 2`. La linterna solo ilumina la capa 1 (no ilumina a quien la lleva); el halo, el monitor y la emergencia iluminan las dos.
- **Brillos**: lo que emite luz tiene un hijo `Glow` con `CanvasItemMaterial` sin sombreado.
- **Puertas entre zonas**: `WARPS` en `hospital_intro.gd` (casilla pisada → destino y dirección), con fundido.
- `--screenshot` abre una ventana; para comprobar sin ventana usa `--headless` con `--quit-after`.
- **Mandos**: algunos mandos (visto con un DualSense) mandan valores falsos los primeros fotogramas; por eso el control llega 0,5 s después al saltarse la intro.

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
