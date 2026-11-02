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
| `EventBus` | `autoload/event_bus.gd` | Señales globales (objeto recibido, documento nuevo, bandera activada, corriente…) |
| `GameState` | `autoload/game_state.gd` | Banderas, estado de cada objeto del mundo, personaje activo (custodia, constantes, ropa puesta), posición |
| `SaveSystem` | `autoload/save_system.gd` | Guardar y cargar `GameState` en JSON (`user://saves/`) |
| `Settings` | `autoload/settings.gd` | Opciones del jugador y canales de audio (`user://settings.cfg`) |

## Módulos

| Carpeta | Qué contiene |
|---|---|
| `scripts/core/items/` | `ItemDef` (definición), `ItemStack` (ejemplar con cantidad, durabilidad, carga…), efectos al usar (`effects/`) |
| `scripts/core/documents/` | `DocumentDef` |
| `scripts/core/recipes/` | `RecipeDef` (combinaciones) |
| `scripts/core/registry.gd` | Carga por id todo lo que hay en `data/items`, `data/documents` y `data/recipes` |
| `scripts/core/input_actions.gd` | Acciones de teclado y mando |
| `scripts/systems/inventory/` | `Custody`: bandeja 5×4 con objetos de varios tamaños, bolsillos y expediente |
| `scripts/systems/survival/` | `Vitals`: Cuerpo, Mente y sangrado |
| `scripts/systems/interaction/` | `Interactable`, `Door` (puertas que se cruzan andando), `LootEntry`, `ItemUse`, `InteractionPicker` (qué objeto se enfoca), `FocusOutline` y `Glint` (contorno y destello) |
| `scripts/systems/loot/` | Botín aleatorio: `LootPlan` (muebles y repartos), `LootTable`, `LootScatter`, `LootRoller` (tirada determinista con semilla) |
| `scripts/systems/thoughts/` | `Thought` y `ThoughtSet`: lo que el protagonista sabe que tiene que hacer (tecla T) |
| `scripts/systems/events/` | `EventDirector` y eventos de datos (`HorrorEvent` + acciones) |
| `scripts/systems/lighting/` | Luces con corriente y parpadeo (`PoweredLight`); capas de luz y sombra (`LightLayers`), luz gemela (`LightMirror`) y rebote que no cruza muros (`BounceClamp`) |
| `scripts/systems/audio/` | `Sfx`: sonidos posicionales y ambiente |
| `scripts/systems/character/` | `CharacterState`: custodia, constantes, linterna y ropa puesta (`equip`, `unequip`, `worn`) |
| `scenes/ui/custody/` | Pantalla del Sistema de Custodia (bandeja, expediente y personaje) |
| `scenes/ui/hud/` | Indicador de interacción, bolsillos y batería |
| `scenes/ui/` | Caja de texto, inspector de objetos, lector de documentos, menús |
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
- el inventario (bandeja, bolsillos y documentos);
- las constantes vitales y la carga de la linterna;
- la ropa puesta (ranura → id de objeto);
- el estado de cada objeto del mundo (por `object_id`);
- las banderas de eventos;
- la semilla del botín aleatorio (en el estado de objetos, clave `loot`): al cargar se vuelve a tirar con ella y sale lo mismo. Las partidas anteriores al botín aleatorio guardan `-1` y conservan el contenido original.

Al cargar, cada `Interactable` lee su estado en `_ready`. Se guarda en las grabadoras de cinta del hospital.
