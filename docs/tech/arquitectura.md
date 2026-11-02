# Arquitectura — La Novena Vigilia

Cómo está organizado el código del prólogo y cómo se amplía. Las convenciones generales están en [CLAUDE.md](../../CLAUDE.md).

## Principios

- **Datos fuera del código.** Objetos, documentos y recetas son `Resource` (`.tres`) en `data/`. Para añadir uno nuevo se crea el `.tres`; no hay que tocar código.
- **Objetos del mapa configurables.** Cada cosa interactuable es un nodo `Interactable` (o `Door`) configurado en el inspector: textos, estado inicial, contenido, llave necesaria, objeto que se puede usar sobre él…
- **La lógica no depende de la pantalla.** El inventario (`Custody`), las constantes vitales (`Vitals`) y el estado del mundo (`GameState`) se pueden probar sin escena.
- **Persistencia en un solo sitio.** Todo lo que debe sobrevivir (cajones abiertos, objetos recogidos, puertas, eventos, inventario) vive en `GameState` y se guarda con `SaveSystem`.
- **Preparado para cinco protagonistas.** Lo que depende del personaje (inventario, constantes, linterna) cuelga de `GameState.character`, no del nodo `Player`.

## Autoloads

| Nombre | Archivo | Qué guarda o hace |
|---|---|---|
| `EventBus` | `autoload/event_bus.gd` | Señales globales (objeto recibido, usado o descartado, documento nuevo, bandera activada, corriente…) |
| `GameState` | `autoload/game_state.gd` | Banderas, estado de cada objeto del mundo (y objetos sueltos en el suelo), personaje activo (custodia, constantes, ropa puesta, arma), posición |
| `SaveSystem` | `autoload/save_system.gd` | Guardar y cargar `GameState` en JSON (`user://saves/`) |
| `Settings` | `autoload/settings.gd` | Opciones del jugador y canales de audio (`user://settings.cfg`) |

## Módulos

| Carpeta | Qué contiene |
|---|---|
| `scripts/core/items/` | `ItemDef` (definición), `ItemStack` (ejemplar con cantidad, durabilidad, carga…), efectos al usar (`effects/`) |
| `scripts/core/documents/` | `DocumentDef` |
| `scripts/core/recipes/` | `RecipeDef` (combinaciones de dos objetos y recetas de fabricar) y `RecipeIngredient` |
| `scripts/core/weapon_def.gd` | `WeaponDef` (datos de combate de un arma; en `data/weapons/`) |
| `scripts/core/registry.gd` | Carga por id todo lo que hay en `data/items`, `data/documents` y `data/recipes` |
| `scripts/ui/ui_style.gd` | Colores, fuentes (`ui`, `ui_bold`, `pixel`, `mono`, `hand`) y tamaños de la interfaz |
| `scripts/core/input_actions.gd` | Acciones de teclado y mando |
| `scripts/systems/inventory/` | `Custody` (bandeja 5×4, bolsillos, expediente, descartar, recetas descubiertas), `Crafting` (fabricar y rasgar) e `ItemSounds` (sonidos de los objetos por material) |
| `scripts/systems/world/` | `WorldController`, `CustodyWorldLink` (objetos descartados al suelo, arma en la mano y sonidos de uso) y `DroppedItem` (objeto suelto recogible) |
| `scripts/systems/survival/` | `Vitals`: Cuerpo, Mente y sangrado |
| `scripts/systems/interaction/` | `Interactable`, `Door` (puertas que se cruzan andando), `LootEntry`, `ItemUse`, `InteractionPicker` (qué objeto se enfoca), `FocusOutline` y `Glint` (contorno y destello) |
| `scripts/systems/loot/` | Botín aleatorio: `LootPlan` (muebles y repartos), `LootTable`, `LootScatter`, `LootRoller` (tirada determinista con semilla) |
| `scripts/systems/thoughts/` | `Thought` y `ThoughtSet`: lo que el protagonista sabe que tiene que hacer (tecla T) |
| `scripts/systems/events/` | `EventDirector` y eventos de datos (`HorrorEvent` + acciones) |
| `scripts/systems/horror/` | Terror ambiental aleatorio: `HorrorDirector` (se crea con una línea desde el mapa), `ScarePlanner` + `ScareDef` (sustos pequeños como datos, en `data/horror/`), `Stalker` (la entidad que sigue al jugador) y `PassingShadow`. Ver [terror-ambiental.md](../design/sistemas/terror-ambiental.md) |
| `scripts/systems/lighting/` | Luces con corriente y parpadeo (`PoweredLight`); capas de luz y sombra (`LightLayers`), luz gemela (`LightMirror`) y rebote que no cruza muros (`BounceClamp`) |
| `scripts/systems/audio/` | `Sfx` (sonidos posicionales y de interfaz), `MusicPlayer` (música en bucle con fundidos, bus `Música`), `Soundscape` (paisaje sonoro por datos: `SoundscapeDef`/`AmbientSoundDef` en `data/audio/`), `AudioBuses` (buses y efectos: eco de sala y paso bajo por distancia) y `RoomAcoustics` (eco y ecualización según la sala del jugador: `AcousticsDef`/`AcousticSpaceDef`). Ver [sonidos.md](sonidos.md) |
| `scripts/systems/character/` | `CharacterState`: custodia, constantes, linterna, ropa puesta (`equip`, `unequip`, `worn`), arma (`wield`, `unwield`, `wielded`) y `discard` |
| `scenes/ui/custody/` | Pantalla del Sistema de Custodia (bandeja, fabricar, expediente y personaje) |
| `scenes/ui/hud/` | Indicador de interacción, bolsillos y batería |
| `scenes/ui/` | Caja de texto, inspector de objetos, lector de documentos, menús |
| `scenes/ui/status_fx/` | `StatusFx`: efectos de pantalla de herida, sangrado, Mente baja y cura (shader `shaders/status_fx.gdshader`) |
| `scenes/ui/title/` | Pantalla de título: fondo animado (`TitleBackground`: la escena del hospital sin su script de `WorldController`, sin jugador, eventos ni ambiente, en un `SubViewport` con cámara fija en la Habitación 09), rótulos de vídeo (`TapeOsd`), paneles de Cargar y Créditos (`TitlePanel`) |
| `scenes/world/hospital/` | El hospital (una sola escena) y su guion |

## Flujo de una interacción

1. Cada fotograma, `WorldController` elige el objeto enfocado con `InteractionPicker` (cercanía a los pies y ángulo con la mirada) y le pone un contorno tenue.
2. Le pide sus **acciones disponibles** (Abrir, Registrar, Leer, Usar llave…), que dependen de su estado y del inventario. El HUD muestra el nombre (con un estado breve: «con llave», «ya registrado»), las acciones (E) y Examinar (R).
3. Al pulsar E con varias acciones se elige una; con una sola, se hace.
4. El protagonista hace el gesto de la acción (`Player.play_action`: alcanzar abajo/medio/arriba, recoger, llave, válvula, palanca, forzar). Cuando la mano llega, el `Interactable` ejecuta la acción, cambia de estado, da objetos a `GameState` y lo deja anotado para el guardado; entonces suena.
5. Se muestran los textos; se actualizan los destellos y, si ha cambiado, se avisa de que hay algo nuevo en lo que pensar (T).

## Guardado

`SaveSystem.save_game()` escribe un JSON con:
- la posición del jugador;
- el inventario (bandeja, bolsillos, documentos y recetas descubiertas);
- las constantes vitales y la carga de la linterna;
- la ropa puesta (ranura → id de objeto) y el arma empuñada (id y bolsillo o casilla);
- los objetos descartados en el suelo (`objects["dropped_items"]`: escena, posición y estado del montón);
- el estado de cada objeto del mundo (por `object_id`);
- las banderas de eventos;
- la semilla del botín aleatorio (en el estado de objetos, clave `loot`): al cargar se vuelve a tirar con ella y sale lo mismo. Las partidas anteriores al botín aleatorio guardan `-1` y conservan el contenido original.

Al cargar, cada `Interactable` lee su estado en `_ready`. Se guarda en las grabadoras de cinta del hospital.
