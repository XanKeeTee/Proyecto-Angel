# Técnica — Proyecto-Angel

Las convenciones de código, comandos y estructura de carpetas están en [CLAUDE.md](../../CLAUDE.md). Aquí va lo que necesita más detalle.

## Documentos

- [arquitectura.md](arquitectura.md) — módulos del prólogo y cómo se amplían.
- [sonidos.md](sonidos.md) — sonidos pendientes de Freesound y sus provisionales.
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
| `--wear=id,id` | Se pone esas prendas |
| `--aim=grados` | Apunta en ese ángulo (0 = derecha, 90 = abajo) |
| `--outfit` | Abre la Custodia en la pestaña PERSONAJE |
| `--skip-intro` / `--at=X,Y` | Empieza con control (en la casilla indicada), sin el despertar |
| `--face=up\|down\|left\|right\|up_left\|…` | Dirección inicial |
| `--give=id,id` | Da objetos (montón completo) |
| `--flag=f,f` | Activa banderas (p. ej. `power_on`, `pasillo_imposible`) |
| `--custody` / `--doc=id` | Abre la custodia (o el expediente en ese documento) |
| `--custody-tab=craft\|combine\|dossier\|character\|hand` | Con `--custody`: abre esa pestaña (o modo) |
| `--custody-drag=id` / `--custody-menu=id` / `--custody-wield=id` | Con `--custody`: deja ese objeto agarrado con el ratón / abre su menú contextual / lo empuña |
| `--drop=id,id` | Deja esos objetos en el suelo junto al jugador |
| `--auto-advance=S` | Los textos avanzan solos |
| `--screenshot=RUTA` y `--screenshot-delay=S` | Captura y cierra. **Abre una ventana** |
| `--no-vhs` | Sin filtro |
3. `build_items` crea los objetos, las armas (`data/weapons/`) y las recetas, `build_documents` los documentos, `build_prologue_data` el plan de botín (`data/loot/prologo.tres`) y los pensamientos (`data/thoughts/prologo.tres`), `build_player` la escena del protagonista y `build_hospital` la del hospital.

### Regenerar contenido

Cada generador recrea sus archivos desde cero. Si se ha retocado algo a mano en el editor, se pierde.

```bash
python -I tools/art/build_all.py
python -I tools/art/tiles_doors.py
"$GODOT_BIN" --headless --path . --import
"$GODOT_BIN" --headless --path . res://tools/levels/build_wear.tscn
"$GODOT_BIN" --headless --path . -s tools/data/build_items.gd
"$GODOT_BIN" --headless --path . -s tools/data/build_documents.gd
"$GODOT_BIN" --headless --path . res://tools/data/build_prologue_data.tscn
"$GODOT_BIN" --headless --path . res://tools/levels/build_player.tscn
"$GODOT_BIN" --headless --path . res://tools/levels/build_hospital.tscn
```

1. `build_all.py` genera el arte (tiles, personaje, objetos, iconos), los sonidos y las imágenes de documentos.
   - Por pasos: `python -I tools/art/build_all.py props tiles decals` rehace solo esos pasos y conserva el resto de
     `sprite_meta.json` (pasos: `tiles`, `decals`, `lights`, `protagonist`, `props`, `items`, `sounds`, `docs`).
     Los objetos del mapa tardan unos 2 min en un núcleo. `--preview=RUTA` guarda además una hoja de revisión.
   - Por partes: `python -I tools/art/character.py [capa ...]` rehace el cuerpo y las prendas (unos 4 min, usa todos los núcleos); `python -I tools/art/items.py [id ...]` rehace iconos y vistas del inspector.
   - `build_wear` crea los objetos de ropa (`data/items/`) y la textura con normales de cada prenda puesta.
   - `tiles_doors.py` genera el marco y la hoja de las puertas (`assets/tilesets/door_frame.png`) y el suelo de los pasos (`hospital_doors.png`).
2. `--import` hace que Godot importe todo eso.
3. `build_items` crea los objetos, las armas (`data/weapons/`) y las recetas, `build_documents` los documentos, `build_prologue_data` el plan de botín (`data/loot/prologo.tres`) y los pensamientos (`data/thoughts/prologo.tres`), `build_player` la escena del protagonista y `build_hospital` la del hospital.

El generador del hospital y el de datos del prólogo se ejecutan como escena (no con `-s`) porque necesitan los autoloads.

Aparte (no los llama `build_all.py`):
- `python -I tools/art/entity.py`: la entidad del terror ambiental y el fotograma de cara (`assets/sprites/horror/`).

Sonidos que faltan y qué buscar en Freesound: [sonidos.md](sonidos.md).

**Vista de revisión del mapa** (sin oscuridad ni luces, o con `--lit` como en el juego con corriente):

```bash
xvfb-run -a "$GODOT_BIN" --path . --rendering-driver opengl3 res://tools/levels/preview_map.tscn -- \
  --region=0,0,74,30 --out=/tmp/planta3.png        # sótano: --region=0,30,37,30
```

### Arte del mapa y decorado

| Archivo | Qué genera |
|---|---|
| `tools/art/tiles.py`, `tiles_extra.py` | Atlas del hospital (suelos, paredes, puertas). Las variantes del atlas son sobrias: el desgaste fuerte va en calcomanías |
| `tools/art/decals.py` | Calcomanías: `decals` (suelo 32×32), `decals_big` (64×64) y `decals_wall` (columna de pared 32×96, con brillo para las señales de salida) |
| `tools/art/props.py`, `props2.py`, `props3.py` | Objetos del mapa. `props3.py` tiene los muebles con cajones rehechos (fotogramas cerrado / abierto con cosas / abierto vacío) y el decorado (`DRESSING`) |
| `tools/art/materials.py` | Rampas y materiales con desgaste (esmalte con desconchones y óxido, acero, cristal, tela…) |
| `tools/art/shadow.py` | Sombra de contacto horneada en cada sprite: oclusión del suelo bajo patas y bases, o sombra arrojada sobre el muro para lo que cuelga de la pared |
| `tools/levels/hospital_dressing.gd` | Coloca el decorado: sombras al pie de paredes y rincones, desgaste según el suelo, calcomanías de pared solo sobre tramos lisos, muebles y máquinas con colisión y oclusor, sombra bajo los objetos sueltos (`item:`) y el fotograma de vacío de los contenedores |

- El decorado son nodos `Node2D` del grupo `dressing` dentro de `World` (se ordenan con el jugador). Los que ocupan sitio
  guardan sus casillas en el meta `cells` y llevan un `StaticBody2D`. Si una pieza cae sobre un objeto interactuable,
  una puerta o su paso, se omite con un aviso; `tests/integration/test_dressing.gd` comprueba que todo sigue siendo alcanzable.
- `Interactable.frame_empty` (fotograma de vacío) solo se ve con el contenedor abierto; cerrado vuelve a `frame_closed`.
- Para añadir decorado: modelo en `props3.py` + entrada en `DRESSING` → `build_all.py props` → entrada en
  `hospital_dressing.gd::_props()` → `build_hospital`.

### Notas

- **Movimiento libre**: el protagonista es un `CharacterBody2D` (modo flotante) con un círculo de 6 px en los pies; el nodo está en los pies. Colisiona con la capa 1:
  - los tiles con `solid = true` tienen polígono de colisión en la capa de física del tileset;
  - los muebles con `Interactable.blocks` tienen un `StaticBody2D` llamado `Body` con la huella de su `footprint`.
- **Casillas de interacción**: `Interactable.interact_cells`, si está, sustituye a `footprint` para interactuar (p. ej. un escritorio con el ordenador en una casilla y los cajones en la otra).
- **Puertas entre salas**: se cruzan andando. Entre una sala y el pasillo hay 4 casillas de muro (remate + 3 tramos de pared); en la columna de la puerta esas 4 casillas son suelo de paso (`hospital_doors.png`, sin colisión). La `Door` lleva:
  - `Sprite2D`: marco, dintel, remate y hoja (`door_frame.png`, fotograma cerrado/abierto según el estilo de pared). Su nodo está en el **pie del muro** y la puerta tiene `y_sort_enabled`, así que si los pies del jugador están dentro del hueco el marco se dibuja por encima: parece que pasa por debajo del dintel;
  - `Body`: colisión de las 4 casillas, activa solo con la puerta cerrada;
  - `Occluder`: tapa la luz en la casilla del remate, solo con la puerta cerrada.
  Si una puerta se cierra (o la cierra un evento) con el jugador dentro del hueco, sale al lado más cercano; desde dentro no se ofrece «Cerrar». Las **escaleras** siguen cambiando de planta con `Door.warp_front_to`: el jugador sigue andando hacia el hueco mientras funde a negro, se oyen pasos y vuelve la imagen.
- **Sombras**: los tiles de remate tienen oclusor completo (capa de oclusión con máscara `LightLayers.WALL_OCCLUDERS`); las caras de la pared no, para que la luz las ilumine desde delante. Los muebles llevan un `LightOccluder2D` llamado `Shadow` con máscara `LightLayers.PROP_OCCLUDERS`. Ver `scripts/systems/lighting/light_layers.gd`.
- **Mapas de normales**: cada sprite y el tileset usan un `CanvasTexture` (`*_canvas.tres`). Las luces llevan `height` alto (70–110).
- **Capas de luz** (`light_mask`, constantes en `LightLayers`). En Godot 2D, `shadow_item_cull_mask` elige a la vez qué oclusores usa una luz y qué objetos reciben su sombra; por eso los muros y los muebles ocluyen en capas distintas:

  | Capa | Qué | La linterna lo ilumina | Recibe sombra de muros | Recibe sombra de muebles |
  |---|---|---|---|---|
  | 1 | Suelo, paredes, marcos de puerta, calcomanías | Sí (luz principal) | Sí | Sí (linterna) |
  | 2 | Protagonista | No (la lleva él) | No | No |
  | 4 | Muebles | Sí (luz gemela `FlashlightProps`) | Sí | No (un mueble no se oscurece a sí mismo) |
  | 8 | Solo oclusores de muebles | — | — | — |

  La linterna son dos luces: la principal (capa 1, sombras de muros y muebles) y una gemela hija (`LightMirror`, capa 4, sombras solo de muros). La luz rebotada no puede quedar al otro lado de un muro: `BounceClamp` la acerca hasta el obstáculo con un rayo por el suelo. Las luces fijas (techo, emergencia, monitor) y el halo usan sombras de muros sobre suelo y muebles. `LightLayers.setup_player()` lo prepara al cargar el mapa (no hace falta regenerar el jugador).
- **Orden de dibujo** (`build_hospital._setup_draw_order`): el mapa va en z −2; calcomanías, papeles en el suelo y apliques de pared en z −1; el resto, ordenado por Y en `World`. Cada mueble con colisión se ordena por el **borde norte de su colisión** (el sprite se mueve a ese punto y su `offset` lo compensa): el jugador queda detrás solo si sus pies están por detrás del mueble; delante y a los lados, por delante. Lo que está encima de otro mueble (teléfono, ordenador) va justo después de él. Vale para cualquier nodo de `World` con `Sprite2D` y `Body` (también el decorado).
- **Interacción**: `InteractionPicker` elige el objeto por cercanía (pies → borde de la casilla, máx. 26 px) y por ángulo con la mirada (máx. 80°). El enfocado lleva un contorno tenue (`FocusOutline`, `shaders/focus_outline.gdshader`). Con varias acciones, E abre una elección. Los objetos clave destellan (`Glint`) mientras tienen algo dentro o cuando llevas lo que les falta (`Interactable.wants_attention`). Cada acción tiene un gesto (`Interactable.anim_for`, `interact_anim`, `ItemUse.anim`): el cambio de estado y el sonido llegan cuando la mano toca el objeto (`WorldController.ACTION_CONTACT`, o la señal `action_contact` del jugador si existe).

- **Animación del protagonista**: 64 columnas × 8 orientaciones (ver la guía estética). El paso avanza con la distancia recorrida de verdad; los giros pasan por las orientaciones intermedias; tras un rato quieto, un gesto. La luz de la linterna sale de la lente: `Player.lens_frames` guarda su posición en cada fotograma. El origen de la linterna por orientación sale de `sprite_meta.json` (`lens`).
- **Apuntar**: el jugador mira hacia el ratón (o el stick derecho) desde la altura del pecho; si no hay ninguno, hacia donde camina. De lado va al 85 % y de espaldas al 62 %, con el paso al revés. `Player.forced_aim` fija la dirección para pruebas y escenas guionizadas. `AimReticle` dibuja el punto de mira y oculta el cursor del sistema solo mientras se explora.
- **Ropa por capas**: el cuerpo (`protagonist.png`, con ropa interior) y una hoja por prenda (`characters/wear/<id>.png`), todas con el mismo formato de 64×8 fotogramas. Cada prenda se renderiza con el cuerpo como "tapa" invisible, así que solo pinta lo que queda por delante. En el jugador son 4 `Sprite2D` hijos (`Feet`, `Legs`, `Body`, `Head`) que copian el fotograma del cuerpo.
- **Física de la tela**: un muelle amortiguado en `Player._update_cloth` (se queda atrás al andar, sigue de largo al frenar, ondea con el paso y sale despedido al girar). El shader `shaders/cloth_sway.gdshader` desplaza los píxeles de la prenda según su altura (nada en la cintura, todo en el bajo) y lee las normales en el mismo sitio. `ItemDef.cloth_sway` dice cuánto se mueve cada prenda.
- **Iconos**: miden `casillas × 40 − 4` px (`ItemDef.ICON_CELL`) y el modelo se encuadra solo. `pxrender` admite un cuarto valor en los materiales: brillo especular. Si cambia el tamaño de casilla, hay que rehacer los iconos (`items.py`) y luego `build_wear` y `build_items` para que los `.tres` apunten a ellos.
- **Fuentes**: sin antialias ni posición subpíxel, con hinting completo (ver [fuentes](../art/fuentes.md)). Usa siempre `UiStyle` y sus tamaños.
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
