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
| `scripts/systems/interaction/` | `Interactable`, `Door`, `LootEntry`, `ItemUse` |
| `scripts/systems/events/` | `EventDirector` y eventos de datos (`HorrorEvent` + acciones) |
| `scripts/systems/lighting/` | Luces con corriente y parpadeo (`PoweredLight`) |
| `scripts/systems/audio/` | `Sfx`: sonidos posicionales y ambiente |
| `scripts/systems/character/` | `CharacterState`: custodia, constantes, linterna, ropa puesta (`equip`, `unequip`, `worn`), arma (`wield`, `unwield`, `wielded`) y `discard` |
| `scenes/ui/custody/` | Pantalla del Sistema de Custodia (bandeja, fabricar, expediente y personaje) |
| `scenes/ui/hud/` | Indicador de interacción, bolsillos y batería |
| `scenes/ui/` | Caja de texto, inspector de objetos, lector de documentos, menús |
| `scenes/world/hospital/` | El hospital (una sola escena) y su guion |

## Flujo de una interacción

1. El `Player` emite `interact_requested` con las casillas que tiene delante.
2. La escena busca el `Interactable` y le pide sus **acciones disponibles** (Abrir, Registrar, Leer, Usar llave…), que dependen de su estado y del inventario.
3. El HUD muestra la acción principal (E) y Examinar (R).
4. El `Interactable` ejecuta la acción, cambia de estado, da objetos a `GameState` y lo deja anotado para el guardado.

## Guardado

`SaveSystem.save_game()` escribe un JSON con:
- la posición del jugador;
- el inventario (bandeja, bolsillos, documentos y recetas descubiertas);
- las constantes vitales y la carga de la linterna;
- la ropa puesta (ranura → id de objeto) y el arma empuñada (id y bolsillo o casilla);
- los objetos descartados en el suelo (`objects["dropped_items"]`: escena, posición y estado del montón);
- el estado de cada objeto del mundo (por `object_id`);
- las banderas de eventos.

Al cargar, cada `Interactable` lee su estado en `_ready`. Se guarda en las grabadoras de cinta del hospital.
