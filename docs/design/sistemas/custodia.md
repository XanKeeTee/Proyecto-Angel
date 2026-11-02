# Sistema de Custodia (inventario)

> Estado: implementado y con pruebas. Lógica: `scripts/systems/inventory/` (`custody.gd`, `crafting.gd`, `item_sounds.gd`). Interfaz: `scenes/ui/custody/`.

El inventario de La Novena Vigilia se presenta como el **registro de pertenencias de un paciente**: una bandeja de instrumental metálica, unos bolsillos y un expediente. Interfaz oscura, de acero, con letra de máquina de escribir para los datos.

## Pantalla

Ocupa toda la vista (640×360) y tiene cuatro pestañas (Q / Mayús+Q para cambiar, Tab o Esc para cerrar):

| Pestaña | Qué hay |
|---|---|
| **BANDEJA** | Bandeja, bolsillos, zona de SUELO, detalles del objeto con sus acciones y constantes |
| **FABRICAR** | Dos modos: **Fabricar** (recetas de varios ingredientes) y **Combinar** (dos objetos) |
| **EXPEDIENTE** | Documentos y lector en papel |
| **PERSONAJE** | El protagonista con la ropa puesta, sus 4 ranuras de ropa y la **MANO** (arma) |

Textos: serifa del sistema para menús, descripciones y títulos; máquina de escribir para datos y documentos mecanografiados; letra a mano para notas (ver [fuentes](../../art/fuentes.md)).

## A. Bandeja de custodia

- **Cuadrícula de 5×4** (20 casillas) de **36 px** (`ItemDef.ICON_CELL`). Indicador de ocupación sobre los bolsillos (`bandeja 07/20`), en rojo al llenarse.
- **Tamaño**: cada objeto ocupa casillas según su tamaño (`ItemDef.size`). Se puede **girar** si no es cuadrado.

  | Objeto | Tamaño |
  |---|---|
  | Llave, frasco, venda, pilas, tela | 1×1 |
  | Linterna, destornillador, fusible, bisturí, cuchilla, punzón | 1×2 |
  | Palanca, tubo de hierro, barra | 1×3 |
  | Válvula, bata | 2×2 |

- **Apilado**: hasta `max_stack` unidades por montón. Los ejemplares contaminados no se mezclan con los limpios.
- **Arrastrar con el ratón** (al estilo de Tarkov):
  - al arrastrar, el objeto **se levanta** (un par de píxeles, con su sombra) y **sigue al cursor**, agarrado por donde se cogió;
  - donde estaba queda su **hueco a trazos**;
  - se ve la **huella** de dónde caería: verde = cabe, ámbar = juntar con otro montón o combinar, rojo = no cabe;
  - **clic derecho mientras se arrastra lo gira** (o R);
  - soltar **encima de otro objeto** intenta combinarlos; soltar en un **bolsillo** lo guarda ahí;
  - soltar en la zona **SUELO** lo descarta; soltar **fuera de la bandeja** lo devuelve a su sitio.
- **Teclado**: flechas mueven el cursor, Intro coge y suelta, R gira.
- **Menú contextual**: clic derecho sobre un objeto. Doble clic: usar.

### Acciones de un objeto

Aparecen en el panel de detalles y en el menú contextual (solo las que tienen sentido):

| Acción | Tecla | Notas |
|---|---|---|
| Usar / Ponerse | E | El verbo es el del objeto ("Vendar", "Tomar", "Cargar la linterna"…) |
| Empuñar / Guardar arma | F | Solo armas |
| Examinar | X | Inspector con 8 vistas giratorias |
| Combinar | C | Elige el segundo objeto e Intro |
| Rasgar | T | Prendas no puestas: da tiras de tela |
| Al bolsillo / A la bandeja | 1-5 | |
| Girar | R | |
| Descartar | Supr | Nunca los objetos clave |

## B. Bolsillos de acceso rápido

- 5 huecos **independientes de la bandeja**: lo que va en un bolsillo deja de ocupar casillas.
- Se usan durante la exploración con las teclas **1–5**, sin abrir la custodia. La linterna en un bolsillo se enciende y apaga.
- El HUD los muestra un momento cuando se usan o cambian.

## C. Suelo: descartar

- Se descarta arrastrando a **SUELO**, con **Supr** o desde el menú contextual.
- Los **objetos clave** (`key_item`) **no se pueden descartar** ("No. Podrías necesitarlo.").
- Lo descartado **cae a los pies del jugador** como objeto recogible (`DroppedItem`) y **conserva su estado** (cantidad, desgaste, carga, contaminación). Se recoge con E mirándolo, si cabe.
- Se **guarda con la partida** (lista de objetos sueltos por escena).
- Si se descarta el arma empuñada, la mano queda vacía.

## D. Expediente personal

- Documentos, fotografías, planos, etiquetas: **no ocupan sitio** en la bandeja.
- Lista a la izquierda (• = sin leer) y lector en papel a la derecha. Cada tipo tiene su aspecto: mecanografiado (máquina de escribir), a mano (letra manuscrita) o ficha. También admite imagen y sello en rojo.
- Leer algo en el mundo lo añade y abre el lector directamente.

## E. Personaje: ropa y arma

- Cuatro ranuras de ropa (cabeza, cuerpo, piernas, pies). La ropa puesta no ocupa sitio en la bandeja; lo que se quita vuelve a ella.
- **MANO** `[PROPUESTA]`: el arma empuñada. A diferencia de la ropa, **sigue en la custodia** y ocupa su sitio (en la bandeja lleva una esquina ámbar). Así la palanca se puede empuñar y seguir usando en la puerta del quirófano; si el arma sale de la custodia (se descarta, se queda encajada…), la mano queda vacía sola.
- Se ven los datos del arma: tipo de daño, poder, precisión, crítico, una o dos manos y qué hace a las partes del cuerpo (ver [combate](combate.md)).
- Se guarda con la partida. Si el personaje tiene `Player.set_held_weapon`, se dibuja en la mano.

### Armas

| Objeto | Tipo | Poder | Precisión | Crítico | Manos | Origen |
|---|---|---|---|---|---|---|
| Cuchilla | Cortante | 12 | 75 % | — | Una | Prototipo de combate |
| Barra de hierro | Contundente | 14 | 70 % | — | Dos | Prototipo de combate |
| Punzón | Perforante | 10 | 80 % | +5 | Una | Prototipo de combate |
| Palanca | Contundente | 13 | 65 % | — | Dos | Herramienta del prólogo |
| Bisturí | Cortante | 8 | 85 % | +10 | Una | `[PROPUESTA]` quirófano |
| Tubo de hierro | Contundente | 12 | 70 % | — | Una | `[PROPUESTA]` taller o calderas |
| Tubo con mango envuelto | Contundente | 12 | 78 % | +2 | Una | `[PROPUESTA]` se fabrica |

Las `WeaponDef` están en `data/weapons/`; el objeto de la custodia (`ItemDef.weapon`) apunta a ellas. El prólogo no tiene combate: las armas nuevas no están colocadas en el mapa (se pueden dar con `--give=bisturi,tubo_metal`).

## Constantes

Al pie del panel de detalles: barras de Cuerpo y Mente, carga de la linterna y aviso de SANGRADO.

## Rasgar y fabricar `[PROPUESTA]`

### Rasgar

Una prenda **que no se lleva puesta** se rasga en **tiras de tela** (T o menú). Cantidad (`ItemDef.tear_yield`, automática según la ranura si `tear_amount` es -1):

| Prenda | Tiras |
|---|---|
| Ropa del cuerpo (batas, chaqueta) | 3 |
| Pantalones | 2 |
| Gorros | 1 |
| Calzado | 0 (no se rasga) |

### Fabricar

Recetas de varios ingredientes. La pestaña muestra las **conocidas**, lo que **falta** (verde/rojo, con lo que tienes) y el botón **Fabricar** (Intro). Una receta se descubre al llevar encima alguno de sus ingredientes; las combinaciones de dos objetos aparecen también, en su grupo, después de hacerlas una vez. Si el resultado no cabe en la bandeja, no se gasta nada.

| Receta | Ingredientes | Resultado |
|---|---|---|
| Venda improvisada | Tiras de tela ×2 | Venda improvisada (sucia: cura 3 y corta el sangrado, pero penaliza si no se desinfecta) |
| Torniquete | Tiras de tela ×3 | Torniquete (solo con sangrado: lo corta sin tocar la herida, sin cura) |
| Envolver el mango del tubo | Tubo de hierro + tiras de tela ×2 | Tubo con mango envuelto (+8 % de precisión) |

### Combinar

Dos objetos: soltando uno encima de otro en la bandeja, con C, o en FABRICAR › Combinar (se eligen dos objetos de la lista y se ve el resultado si ya se conoce).

| Combinación | Resultado |
|---|---|
| Venda + desinfectante | Venda esterilizada (el desinfectante gasta un uso) |
| Venda usada + desinfectante | Venda limpia |
| `[PROPUESTA]` Venda improvisada + desinfectante | Venda limpia |
| Pilas + linterna | +45 % de carga (se gasta una pila) |
| Jeringa + ampolla | Sedante |
| Destornillador + válvula averiada | Válvula reparada (el destornillador gasta un uso) |

Además, hay objetos que se **usan sobre el mundo** (`ItemUse` en un `Interactable`): la palanca en la puerta atascada, el destornillador en el cuadro, el fusible en su hueco, la válvula en el generador.

## Sonidos de los objetos

Cada objeto suena según su **material** (`ItemDef.sound_material`; AUTO lo deduce de la categoría) al **cogerlo** (`pick`), **colocarlo** (`place`), **girarlo** (`rotate`), **equiparlo** (`equip`/`unequip`) y **descartarlo** (`drop`). Al **usarlo** suena `ItemDef.use_sound`. Lo gestiona `ItemSounds`, que busca en este orden:

1. `inv_<material>_<acción>` (p. ej. `inv_metal_heavy_pick`);
2. `inv_<acción>` (genérico);
3. un sonido que ya existe y se parece (provisional: `pickup` con el tono cambiado, `paper`, `glass`, `pills`, `battery`, `bandage`).

Materiales: `metal_heavy`, `metal_small`, `keys`, `cloth`, `paper`, `plastic`, `glass`, `pills`, `battery`, `tool`, `rubber`, `ceramic`.

Sonidos de uso (provisional entre paréntesis): `use_battery_insert` (battery), `use_bandage_apply` (bandage), `use_pills_swallow` (pills), `use_syringe_inject` (pills), `use_tourniquet_tighten` (bandage). Otros: `cloth_tear` al rasgar (bandage), `craft_cloth` al fabricar con tela (bandage), `craft_combine` y `craft_generic` (pickup).

**Pendiente**: todos los `inv_*`, `use_*`, `cloth_tear` y `craft_*` saldrán de Freesound; basta con dejar el `.wav` con ese nombre en `assets/audio/sfx/`.

## Propiedades de un objeto (`ItemDef`)

| Propiedad | Para qué |
|---|---|
| `display_name`, `description` | Nombre y texto al seleccionarlo |
| `icon`, `inspect_sheet` | Icono de la bandeja (`casillas × 36 − 4` px) y vistas del inspector |
| `size` | Casillas que ocupa |
| `max_stack` | Cantidad máxima por montón |
| `max_durability` | Usos antes de romperse (herramientas) |
| `max_charge` | Carga (linterna) |
| `contaminated` | Viene contaminado; al usarlo penaliza |
| `usable`, `use_effects`, `use_verb`, `consumed_on_use` | Qué pasa al usarlo |
| `key_item` | Objeto clave: no se puede descartar |
| `equip_slot`, `wear_sheet`, `cloth_sway`, `step_sound` | Ropa |
| `weapon` | `WeaponDef`: se puede empuñar |
| `tear_amount`, `tear_result` | Rasgar (-1 = automático según la ranura) |
| `sound_material`, `use_sound` | Sonidos |

El **estado** de cada ejemplar (`ItemStack`) es cantidad, durabilidad, carga y contaminación. Se muestra como texto («Carga 40 %», «Desgastado», «Contaminado»).

**Efectos disponibles** (`scripts/core/items/effects/`):
- `HealEffect`: Cuerpo, Mente, cortar sangrado; con penalización si está contaminado.
- `RechargeEffect`: carga la linterna.
- `ToggleFlashlightEffect`: enciende o apaga la linterna.

## Cómo añadir cosas

- **Objeto nuevo**: un `.tres` de `ItemDef` en `data/items/` (o en `tools/data/build_items.gd`). Para su icono y sus vistas, añadirlo a `tools/art/items.py`.
- **Arma nueva**: una `WeaponDef` en `data/weapons/` y un objeto con `weapon` apuntando a ella.
- **Combinación nueva**: un `.tres` de `RecipeDef` (modo PRODUCE o RECHARGE) en `data/recipes/`.
- **Receta de fabricar**: `RecipeDef` en modo CRAFT, con `ingredients` (`RecipeIngredient`: objeto, cantidad, si es herramienta y si gasta un uso).
- **Documento nuevo**: un `.tres` de `DocumentDef` en `data/documents/`.

`Registry` los encuentra solos; no hay que tocar código.

## Decisiones

- **Se puede descartar, salvo lo clave** (antes no se podía tirar nada). Así el espacio obliga a decidir, pero el camino principal nunca se rompe. Lo descartado se queda en el suelo, guardado, por si se quiere volver a por ello.
- **El arma empuñada no sale de la bandeja**: evita que una herramienta clave (la palanca) desaparezca de la custodia al empuñarla.
- **Si algo no cabe**, se queda donde estaba («No te cabe en la bandeja») y se puede volver a por ello. Fabricar o rasgar sin sitio para el resultado no gasta nada.
