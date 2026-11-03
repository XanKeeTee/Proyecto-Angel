# Interfaz del combate

> Diseño: [combate.md § Presentación](../design/sistemas/combate.md#presentación-propuesta). Código en `scenes/battle/`;
> arte en `assets/ui/battle/` (generador `tools/art2d/ui_battle.py`).

De *Fear & Hunger* solo se conserva la **disposición** (enemigo arriba en el centro sobre el foco, el grupo de espaldas
abajo en primer plano) y el núcleo de reglas (apuntar a partes, mutilar). La interfaz es del hospital de 1987, como el
menú principal aprobado (`docs/art/muestras/maqueta_menu.png`): chapa oxidada con remaches, fichas de papel clínico a
máquina, pestañas con cinta, sellos de caucho y una lámina anatómica.

## Piezas

| Clase | Archivo | Qué es |
|---|---|---|
| `BattleScene` | `battle_scene.gd` | Orquesta: fases (`MAIN`, `SUBMENU`, `AIM`, `RESOLVE`, `END`), menús, efectos y señales de `Battle` |
| `ActionMenuModel` | `action_menu_model.gd` | **Adaptador provisional** de la API de opciones (ver abajo). Lo único que habla de reglas |
| `ActionOption`, `TargetOption`, `PartOption`, `ActionPreview` | `model/*.gd` | Estructuras del contrato (provisionales: ver «Al fusionar») |
| `BattleSkin` | `battle_skin.gd` | Carga el arte, estilos de 9 cortes (`StyleBoxTexture`), paleta, iconos, sellos y ayudas de dibujo |
| `BattleFrame` | `battle_frame.gd` | Caja de chapa con pestaña; iconos de estado (`draw_icon`, `part_icon`, `status_icons`) |
| `BattleOption` | `battle_option.gd` | Opción del menú: marca roja y franja granate al elegirla, icono, dato a la derecha; las desactivadas, tachadas (se pueden señalar: su ficha dice por qué) |
| `PaperCard` | `paper_card.gd` | Ficha de papel a partir de filas (`title`, `text`, `bullet`, `risk`, `rule`, `stats`, `state`), con pestaña, cinta y sello. Es la **ficha de detalle** y la **ficha de la parte** |
| `BodyDiagram` | `body_diagram.gd` | Lámina anatómica: partes coloreadas por estado, la señalada con contorno que late (`part_outline.gdshader`), acierto en cada rótulo, la parte amenazada parpadeando (Guardia). Ratón: `part_hovered`, `part_pressed` |
| `PatientCard` | `patient_card.gd` | Ficha de paciente: foto de la figura de espaldas, Cuerpo y Mente como líquido en tubos (bajan con rastro), mapa de heridas, arma, estados; tiembla y se mancha. Hasta 4 (estrechas = compactas) |
| `IntentNote` | `intent_note.gd` | Nota de observación que se escribe sola con lo que prepara el enemigo |
| `TurnStrip` | `turn_strip.gd` | Ronda y orden (previsto por velocidad al elegir; quién actúa al resolver) |
| `BattleLog` | `battle_log.gd` | Carpeta «REGISTRO»: guarda todas las líneas por rondas; Tab / Select / clic la abre; rueda o flechas |
| `StampFx` | `stamp_fx.gd` | Sello que cae: «AUTORIZADO» al confirmar, rótulos de impacto («AMPUTACIÓN»…) |
| `MessageWindow` | `message_window.gd` | Placa de chapa con 1-2 líneas al resolver (y la presentación) |
| `WoundsPanel` | `wounds_panel.gd` | Hoja de lesiones al pasar por la ficha de paciente |
| `EnemyView` | `enemy_view.gd` | Además de lo de siempre: `focus_part` (oscurece el resto y recorta la parte con contorno por encima de las demás capas) y `part_at(punto)` (qué parte hay bajo el ratón, por los píxeles de cada capa; si no, el ancla más cercana) |

El enemigo sigue siendo **cualquier sprite por capas** (`EnemySpriteDef`): el foco, el contorno y el ratón funcionan con
cualquier hoja nueva sin tocar código. La figura del grupo y su foto salen de `PartyBattler` (`CombatantDef.battle_back`
si existe; si no, el fotograma de espaldas del mapa), así que el retrato es un recurso sustituible.

## Contrato con las reglas (API de opciones)

La interfaz consume cuatro llamadas y no conoce las reglas:

```gdscript
func action_menu(actor: Combatant) -> Array[ActionOption]
func targets_for(actor: Combatant, option: ActionOption) -> Array[TargetOption]
func preview(actor: Combatant, option: ActionOption, target: Combatant, part_id: StringName) -> ActionPreview
func make_order(actor: Combatant, option: ActionOption, target: Combatant, part_id: StringName) -> CombatAction
```

`ActionMenuModel` las ofrece. **Si `Battle` ya tiene un método con ese nombre, lo usa** (`has_method`); si no, construye
las mismas estructuras con la API antigua (`preview_hit_chance`, `preview_damage`, `flee_chance_*`,
`break_free_chance`, `intents`). Además lleva lo que la interfaz necesita y las reglas no: reservar los objetos ya
elegidos por otro miembro en la misma ronda (`reserve`, `release`, `clear_reservations`).

Campo añadido a `ActionOption`: **`quantity`** (unidades que quedan; 0 = no se enseña).

### Al fusionar con las reglas definitivas

1. Si las reglas definen `ActionOption`, `TargetOption`, `PartOption` y `ActionPreview` (mismos campos), borrar
   `scenes/battle/model/` (si no, Godot avisa de `class_name` repetido).
2. `ActionMenuModel` ya delega en `Battle` si tiene los cuatro métodos; lo demás puede quedarse como está.
3. Si `Battle` emite `intent_changed(enemy)` o `turn_order_changed()`, conectarlas a `_telegraph()` y `_refresh()`.

## Arte (`tools/art2d/ui_battle.py`)

```bash
python3 -I tools/art2d/ui_battle.py                    # 640×360 → assets/ui/battle/
python3 -I tools/art2d/ui_battle.py --sheet hoja.png   # y una hoja de revisión ×3
"$GODOT_BIN" --headless --path . --import
```

Chapa (`frame_metal`, la misma función que la maqueta del menú), papel (`frame_paper`), cartulina (`frame_folder`),
pestaña (`tab_paper`), cinta, franja y marca de selección, línea a mano, tubo de vidrio, sellos (`stamp_*`), iconos de
órdenes 16×16 (`icons/order_*`: tubo, puño, bisturí, brazos cruzados, venda, pastillas, jeringa, pulmones, puerta,
puerta con flecha, eslabón roto, atrás, ojo, botiquín) e iconos de estado 12×12 (`icons/status_*`: sangrado, herida,
hueso roto, amputado, agarrado, sedado, aturdido, guardia, pánico), lámina anatómica con una máscara por parte
(`diagram/`) y la silueta pequeña del mapa de heridas (`diagram/mini_*`), y el puntero (plumilla, a 2×).

**Escala**: todo se mide en píxeles de la vista (640×360) y las piezas de 9 cortes se estiran. Para 1280×720:
`ui_battle.py --scale 2`, `BattleSkin.SCALE = 2` y los márgenes y posiciones de `BattleScene` por 2 (son constantes
juntas al principio del archivo).

## Controles

| Acción | Teclado | Ratón | Mando |
|---|---|---|---|
| Mover por el menú / por las partes | Flechas | Pasar por encima | Cruceta / stick |
| Confirmar | Intro | Clic (en el menú, sobre el enemigo o en la lámina) | A |
| Atrás | Esc | Clic derecho | B |
| Registro | Tab | Clic en la pestaña; rueda | Select |
| Hoja de lesiones | — | Pasar / clic en la ficha de paciente | — |

## Sonidos de interfaz (nuevos, solo nombres)

Mientras no estén en `assets/audio/sfx/`, `BattleScene.SOUND_FALLBACK` usa el provisional (o nada).

| Nombre | Qué buscar en Freesound | Provisional |
|---|---|---|
| `ui_battle_move` | Tic seco y corto de papel o de clip metálico al pasar de una opción a otra; 40–80 ms, sin cola | `ui_move` |
| `ui_battle_confirm` | Clac de una grapadora o de un interruptor de baquelita; 0,1–0,2 s | `ui_accept` |
| `ui_battle_back` | Hoja de papel que se retira deprisa (roce corto); 0,15–0,3 s | `ui_back` |
| `ui_battle_denied` | Golpe sordo de un cajón metálico que no abre, o zumbido corto de error de un aparato viejo; 0,2–0,3 s | `ui_back` |
| `ui_stamp` | Sello de caucho golpeando papel sobre una mesa de madera: golpe seco y grave con algo de cuerpo; 0,15–0,35 s | `ui_accept` |
| `ui_paper_slide` | Ficha de cartulina que se desliza sobre un escritorio; 0,2–0,4 s | `paper` |
| `ui_folder` | Carpeta de cartón que se abre o se cierra, con roce de hojas; 0,3–0,6 s | `paper` |
| `ui_aim_part` | Clic muy suave de lápiz o de bolígrafo al señalar (casi inaudible, se repite mucho); 30–60 ms | `ui_move` |
| `ui_typewriter` | Una pulsación de máquina de escribir mecánica (tecla sola, sin campana); 50–100 ms, que se pueda repetir | — (nada) |

## Depuración

Los argumentos están en la cabecera de `battle_scene.gd`. Capturas (pantalla virtual):

```bash
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT_BIN" --path . --rendering-driver opengl3 \
  res://scenes/battle/battle_scene.tscn -- --battle-seed=3 --battle-pick=arm_r --screenshot=/tmp/apuntar.png \
  --battle-shot-delay=2.5
```

| Para ver | Argumentos |
|---|---|
| Órdenes con la ficha de detalle | `--battle-focus=1` (la opción 1 del menú) |
| Apuntar (lámina y ficha de la parte) | `--battle-pick=arm_r` |
| Sello «AUTORIZADO» | `--battle-pick=head --battle-confirm --battle-shot-delay=0.2` |
| Guardia sobre el propio cuerpo | `--battle-menu=guard --battle-wound=arm_l:1` |
| Submenú de objetos | `--battle-items --battle-menu=item --battle-focus=1` |
| Golpe con amputación | `--battle-strike=arm_r --battle-shot-delay=0.3` |
| Registro abierto | `--autoplay=3 --battle-log --battle-shot-delay=0.5` |

## Pruebas

`tests/integration/test_battle_ui.gd` (menús desde `action_menu`, motivo de lo desactivado, apuntar con el ratón y la
lámina, partes amputadas, registro, aviso del enemigo y parte amenazada, hasta 4 fichas, la ficha reacciona al golpe),
`tests/unit/test_action_menu_model.gd` (el adaptador sale de las reglas) y `tests/integration/test_encounter.gd`
(`test_pantalla_de_combate`, la pantalla desde el mapa).
