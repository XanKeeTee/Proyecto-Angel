# Sistema de Custodia (inventario)

> Estado: implementado y con pruebas. Lógica: `scripts/systems/inventory/` (`custody.gd`, `crafting.gd`, `item_sounds.gd`) y `scripts/systems/character/character_state.gd` (ropa, manos, defensa). Interfaz: `scenes/ui/custody/`.

El inventario de La Novena Vigilia se presenta como el **registro de pertenencias de un paciente**. Funciona **como el de *Fear & Hunger***: una **lista por categorías**, sin casillas, sin tamaños y sin límite de espacio; lo que importa es qué llevas y en qué estado, no cómo lo encajas. Las armas y la ropa se gestionan en una **pantalla de equipo** con el personaje, sus ranuras y sus estadísticas. Interfaz oscura, de acero, con letra de máquina de escribir para los datos.

## Pantalla

Ocupa toda la vista (640×360) y tiene cuatro pestañas. **Q / Mayús+Q** (o **LB / RB** en el mando) cambian de pestaña; **Tab** o **Esc** cierran.

| Pestaña | Qué hay |
|---|---|
| **OBJETOS** | Categorías, lista de objetos, imagen, descripción, datos y acciones; atajos 1-5 y constantes |
| **EQUIPO** | El protagonista con lo que lleva, sus 6 ranuras, sus estadísticas y lo que se puede poner en cada ranura |
| **FABRICAR** | Dos modos: **Fabricar** (recetas de varios ingredientes) y **Combinar** (dos objetos) |
| **EXPEDIENTE** | Documentos y lector en papel |

Textos: serifa del sistema para menús, descripciones y títulos; máquina de escribir para datos y documentos mecanografiados; letra a mano para notas (ver [fuentes](../../art/fuentes.md)).

## A. Objetos: lista por categorías

Tres columnas:

1. **Categorías** (izquierda), con cuántos objetos hay en cada una. Debajo, los **atajos 1-5** y las **constantes** (Cuerpo, Mente, carga de la linterna, SANGRADO).
2. **Lista** de la categoría (centro): miniatura, nombre, cantidad (`×3`), estado breve (`contam.`, `40 %`, `2/4` usos) y una etiqueta: **DCHA** / **IZDA** (en la mano), **PUESTO** (ropa puesta) o el número de su atajo.
3. **Detalles** (derecha): nombre, categoría y estado, imagen del objeto (la primera vista del inspector), descripción, datos de combate o de protección y los botones de sus acciones.

### Categorías

Cada objeto tiene la suya en `ItemDef.section` (si se deja en AUTO, se deduce de `category`):

| Categoría | Qué va | Objetos del prólogo |
|---|---|---|
| **Armas** | Lo que se empuña | Bisturí, cuchilla, punzón, barra, tubo de hierro, tubo envuelto |
| **Armaduras** | Ropa y prendas (las puestas aparecen arriba con PUESTO) | Batas, chaqueta y pantalón de celador, pijama, gorros, calzado |
| **Útiles** | Herramientas y lo que las alimenta | Linterna, pilas, destornillador |
| **Medicina** | Curas y lo que sirve para prepararlas | Vendas (todas), analgésicos, jeringa, ampolla, sedante, desinfectante, torniquete |
| **Objetos principales** | Piezas del camino principal: **no se descartan** | Llaves, fusible, válvulas, palanca |
| **Otros** | Objetos secundarios | Tiras de tela |

La palanca está en Objetos principales (abre el quirófano) pero **también se puede empuñar**: cualquier objeto con `weapon` aparece en las listas de armas de EQUIPO, sea cual sea su categoría.

### Montones y estado

- Los objetos **apilables** (`max_stack > 1`) van en **un solo montón por tipo**, sin tope. Los ejemplares **contaminados** van aparte.
- Los que no se apilan (herramientas, armas, ropa, válvulas) van **de uno en uno**, cada uno con su desgaste o su carga.
- El orden es el de llegada.

### Manejo

| Entrada | Qué hace |
|---|---|
| ← / → (cruceta) | Categoría anterior / siguiente |
| ↑ / ↓ · RePág / AvPág | Objeto anterior / siguiente · saltar una página |
| Intro (A) | **Menú de acciones** del objeto (se recorre con las flechas) |
| Clic | Elegir · **doble clic**: usar · **clic derecho**: menú · rueda: desplazar |
| Esc (B) | Cierra el menú o cancela Combinar; si no hay nada a medias, cierra la custodia |

### Acciones de un objeto

Aparecen en el panel de detalles y en el menú (solo las que tienen sentido):

| Acción | Tecla | Notas |
|---|---|---|
| Usar / Ponerse | E | El verbo es el del objeto ("Vendar", "Tomar", "Cargar la linterna"…). En la ropa puesta: **Quitarse** |
| Empuñar / Guardar arma | F | Mano derecha |
| Mano izquierda / Soltar | G | Solo armas de una mano |
| Examinar | X | Inspector con 8 vistas giratorias |
| Combinar | C | Elige el segundo objeto (en cualquier categoría) e Intro |
| Rasgar | T | Prendas no puestas: da tiras de tela |
| Al atajo / Quitar del atajo | 1-5 | La tecla elige el atajo |
| Descartar | Supr | Nunca los objetos clave ni los principales |

## B. Atajos 1-5

En *Fear & Hunger* no hay accesos rápidos, pero aquí se exploran pasillos a oscuras y encender la linterna o vendarse sin abrir el menú tiene sentido. Se mantienen como **atajos**, no como bolsillos:

- Un atajo **apunta a un objeto de la lista**; no es un contenedor aparte ni ocupa nada. Lo que está en un atajo sigue en su categoría (con su número como etiqueta).
- Se asignan **desde la lista**: tecla 1-5 sobre el objeto (otra vez la misma tecla lo quita) o «Al atajo» en el menú. Si el atajo estaba ocupado, el objeto anterior solo pierde el atajo.
- Se usan en exploración con las teclas **1–5**. La linterna en un atajo se enciende y apaga. Si el objeto se gasta o se descarta, el atajo queda vacío.
- El HUD los muestra un momento cuando se usan o cambian; la pestaña OBJETOS, siempre (bajo las categorías).

## C. Suelo: descartar

- Se descarta con **Supr** o desde el menú.
- Los **objetos clave** (`key_item`, p. ej. la linterna) y los de **Objetos principales** **no se pueden descartar** ("No. Podrías necesitarlo.").
- Lo descartado **cae a los pies del jugador** como objeto recogible (`DroppedItem`) y **conserva su estado** (cantidad, desgaste, carga, contaminación). Se recoge con E mirándolo.
- Se **guarda con la partida** (lista de objetos sueltos por escena).
- Si se descarta un arma que se lleva en la mano, esa mano queda vacía.

## D. Expediente personal

- Documentos, fotografías, planos, etiquetas: no son objetos de la lista.
- Lista a la izquierda (• = sin leer; ↑/↓ para cambiar) y lector en papel a la derecha. Cada tipo tiene su aspecto: mecanografiado (máquina de escribir), a mano (letra manuscrita) o ficha. También admite imagen y sello en rojo.
- Leer algo en el mundo lo añade y abre el lector directamente.

## E. Equipo: personaje, ranuras y estadísticas

Al estilo de la pantalla de equipo de *Fear & Hunger*:

- **Retrato** del protagonista con la ropa puesta, respirando y girando por sus 16 orientaciones (Z / V o los botones `<` `>`, o arrastrando con el ratón).
- **Seis ranuras**: **mano derecha**, **mano izquierda** `[PROPUESTA]`, cabeza, cuerpo, piernas y pies. Cada una muestra lo que lleva, con el daño (armas) o la defensa (ropa) a la derecha.
- **Estadísticas**: Cuerpo y Mente; Fuerza, Destreza, Agilidad, Voluntad y Aguante (de la ficha de combate `data/party/protagonist.tres`); **Defensa** (suma de la ropa) y el **ataque** del arma de la mano derecha (daño, tipo, precisión, crítico).
- **Lista de la ranura** (derecha): lo que se puede poner en ella (armas para las manos, prendas de esa ranura) y, si ya hay algo, «Manos vacías» / «Quitar…». Al mirar un candidato se ve su descripción, sus datos y la **comparación** con lo que hay («daño 13 → 8 · precisión 65 → 85 %»).
- Teclado/mando: ↑/↓ ranura · Intro o → para elegir de la lista · ↑/↓ e Intro equipan · ← o Esc vuelven a las ranuras · Supr quita lo de la ranura. Ratón: clic en ranura y en la lista; doble clic equipa.

Reglas:

- **Ropa**: la puesta sale de la lista (y aparece arriba en Armaduras con PUESTO); lo que se quita vuelve a ella. Siempre cabe.
- **Armas**: a diferencia de la ropa, **siguen en la custodia** (con la etiqueta DCHA / IZDA). Así la palanca se puede empuñar y seguir usando en la puerta del quirófano; si el arma sale de la custodia (se descarta, se queda encajada…), la mano queda vacía sola.
- **Mano izquierda** `[PROPUESTA]`: un arma de **una mano**. Un arma de **dos manos** en la derecha la deja libre (y no admite nada). Pasar el arma de una mano a la otra la mueve. El combate todavía no usa la mano izquierda (lo decide el sistema de combate).
- **Defensa de la ropa** `[PROPUESTA]` (`ItemDef.defense`): chaqueta de celador 2; bata de médico, pantalón de celador, gorro de lana y botas de goma 1; el resto 0. De momento solo se muestra: el combate usa la armadura de su ficha.
- Se guarda con la partida (ropa por ranura; cada mano, por la posición del arma en la lista). Si el personaje tiene `Player.set_held_weapon`, el arma de la mano derecha se dibuja en el mundo.

### Rendimiento de la vista previa

Las hojas del protagonista y de la ropa son grandes (3648×1088 px, 76 columnas × 16 orientaciones, más normales). La vista previa **no las dibuja**: de cada hoja lee **una vez** el bloque de reposo (8 fotogramas × 16 orientaciones, 384×1088) a una caché, compone cuerpo + ropa en **una textura pequeña** al cambiar de ropa y dibuja **un fotograma**, solo cuando cambia. Girar no carga nada. (Antes pedía la hoja de la ropa en cada `_draw`: ~70 ms por fotograma, 5 FPS y un rectángulo blanco en lugar del personaje.) Lo vigila `tests/integration/test_equipment_preview.gd`.

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

En la pestaña OBJETOS, bajo las categorías y los atajos: barras de Cuerpo y Mente, carga de la linterna y aviso de SANGRADO. En EQUIPO, con las estadísticas.

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

Recetas de varios ingredientes. La pestaña muestra las **conocidas**, lo que **falta** (verde/rojo, con lo que tienes) y el botón **Fabricar** (Intro). Una receta se descubre al llevar encima alguno de sus ingredientes; las combinaciones de dos objetos aparecen también, en su grupo, después de hacerlas una vez. Como no hay límite de espacio, el resultado siempre se guarda.

| Receta | Ingredientes | Resultado |
|---|---|---|
| Venda improvisada | Tiras de tela ×2 | Venda improvisada (sucia: cura 3 y corta el sangrado, pero penaliza si no se desinfecta) |
| Torniquete | Tiras de tela ×3 | Torniquete (solo con sangrado: lo corta sin tocar la herida, sin cura) |
| Envolver el mango del tubo | Tubo de hierro + tiras de tela ×2 | Tubo con mango envuelto (+8 % de precisión) |

### Combinar

Dos objetos: con C en OBJETOS (se elige el segundo en cualquier categoría e Intro), o en FABRICAR › Combinar (se eligen dos objetos de la lista y se ve el resultado si ya se conoce).

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

Cada objeto suena según su **material** (`ItemDef.sound_material`; AUTO lo deduce de la categoría) al **elegirlo en la lista** (`pick`, flojo), **ponerlo en un atajo** (`place`), **equiparlo** (`equip`/`unequip`), **rasgarlo** (`tear`) y **descartarlo** (`drop`). (`rotate` ya no se usa: era de la bandeja.) Al cambiar de categoría suena `inv_category`. Al **usarlo** suena `ItemDef.use_sound`. Lo gestiona `ItemSounds`, que busca en este orden:

1. `inv_<material>_<acción>` (p. ej. `inv_metal_heavy_pick`);
2. `inv_<acción>` (genérico);
3. un sonido que ya existe y se parece (provisional: `pickup` con el tono cambiado, `paper`, `glass`, `pills`, `battery`, `bandage`).

Materiales: `metal_heavy`, `metal_small`, `keys`, `cloth`, `paper`, `plastic`, `glass`, `pills`, `battery`, `tool`, `rubber`, `ceramic`.

Sonidos de uso (provisional entre paréntesis): `use_battery_insert` (battery), `use_bandage_apply` (bandage), `use_pills_swallow` (pills), `use_syringe_inject` (pills), `use_tourniquet_tighten` (bandage). Otros: `cloth_tear` al rasgar (bandage), `craft_cloth` al fabricar con tela (bandage), `craft_combine` y `craft_generic` (pickup).

**Pendiente**: los `inv_*` que falten, `inv_category`, `use_*`, `cloth_tear` y `craft_*` saldrán de Freesound; basta con dejar el `.wav` con ese nombre en `assets/audio/sfx/`.

## Propiedades de un objeto (`ItemDef`)

| Propiedad | Para qué |
|---|---|
| `display_name`, `description` | Nombre y texto al seleccionarlo |
| `section` | Categoría de la lista: Armas, Armaduras, Útiles, Medicina, Objetos principales u Otros (AUTO = según `category`) |
| `category` | Tipo (herramienta, llave, médico…): para el material de los sonidos y deducir `section` |
| `icon`, `inspect_sheet` | Icono (`size × 36 − 4` px; las listas lo reducen) y vistas del inspector (la primera, en el panel de detalles) |
| `size` | Forma del icono (ya no ocupa casillas) |
| `max_stack` | Mayor que 1 = se apila (un montón por tipo, sin tope) |
| `max_durability` | Usos antes de romperse (herramientas) |
| `max_charge` | Carga (linterna) |
| `contaminated` | Viene contaminado; al usarlo penaliza |
| `usable`, `use_effects`, `use_verb`, `consumed_on_use` | Qué pasa al usarlo |
| `key_item` | Objeto clave: no se puede descartar (los de Objetos principales tampoco) |
| `equip_slot`, `wear_path`, `cloth_sway`, `step_sound` | Ropa |
| `defense` | Defensa puesta `[PROPUESTA]` |
| `weapon` | `WeaponDef`: se puede empuñar |
| `tear_amount`, `tear_result` | Rasgar (-1 = automático según la ranura) |
| `sound_material`, `use_sound` | Sonidos |

El **estado** de cada ejemplar (`ItemStack`) es cantidad, durabilidad, carga y contaminación. Se muestra como texto («Carga 40 %», «Desgastado», «Contaminado»).

**Efectos disponibles** (`scripts/core/items/effects/`):
- `HealEffect`: Cuerpo, Mente, cortar sangrado; con penalización si está contaminado.
- `RechargeEffect`: carga la linterna.
- `ToggleFlashlightEffect`: enciende o apaga la linterna.

## Cómo añadir cosas

- **Objeto nuevo**: un `.tres` de `ItemDef` en `data/items/` (o en `tools/data/build_items.gd`, con su categoría en `SECTIONS`). Para su icono y sus vistas, añadirlo a `tools/art/items.py`.
- **Arma nueva**: una `WeaponDef` en `data/weapons/` y un objeto con `weapon` apuntando a ella.
- **Combinación nueva**: un `.tres` de `RecipeDef` (modo PRODUCE o RECHARGE) en `data/recipes/`.
- **Receta de fabricar**: `RecipeDef` en modo CRAFT, con `ingredients` (`RecipeIngredient`: objeto, cantidad, si es herramienta y si gasta un uso).
- **Documento nuevo**: un `.tres` de `DocumentDef` en `data/documents/`.

`Registry` los encuentra solos; no hay que tocar código.

## Guardado

`Custody.to_dict()` guarda `{"version": 2, "items": [...], "shortcuts": [índice o -1 ×5], "documents", "read", "recipes"}`; cada mano, `{"id", "index"}` (posición en la lista). Las **partidas antiguas** (bandeja por casillas, `"tray"` + `"pockets"`) se leen: los objetos de la bandeja pasan a la lista fila a fila, los de los bolsillos detrás y en su atajo, los montones iguales se juntan y el arma empuñada se busca por bolsillo o, si no, por id. Lo prueba `test_custody.gd › test_partida_antigua_con_bandeja`.

## Decisiones

- **Lista sin límite, al estilo de Fear & Hunger** (antes, bandeja de 5×4 con tamaños y giro). La tensión no está en encajar objetos sino en qué gastar y cuándo: vendas, pilas, usos del destornillador, armas que se rompen o se quedan encajadas.
- **Categorías como dato** (`ItemDef.section`), no deducidas del nombre: el equipo decide en qué pestaña va cada cosa (la palanca es «principal» aunque se pueda empuñar).
- **Atajos 1-5 en vez de bolsillos**: se conservan por la linterna y las curas rápidas, pero ya no son un contenedor: apuntan a la lista y se asignan desde ella.
- **Se puede descartar, salvo lo clave y lo principal**. El camino principal nunca se rompe. Lo descartado se queda en el suelo, guardado, por si se quiere volver a por ello.
- **El arma empuñada no sale de la custodia**: evita que una herramienta clave (la palanca) desaparezca al empuñarla.
