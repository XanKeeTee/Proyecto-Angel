# Sistema de Custodia (inventario)

> Estado: implementado y con pruebas. Lógica: `scripts/systems/inventory/custody.gd`. Interfaz: `scenes/ui/custody/`.

El inventario de La Novena Vigilia se presenta como el **registro de pertenencias de un paciente**: una bandeja de instrumental metálica, unos bolsillos y un expediente. Interfaz oscura, de acero, con tipografía de máquina de escribir para los datos.

## Secciones

### A. Bandeja de custodia

- **Cuadrícula de 5×4** (20 casillas). Indicador de ocupación arriba a la derecha (`07/20`), que se pone en rojo al llenarse.
- **Tamaño**: cada objeto ocupa casillas según su tamaño (`ItemDef.size`). Se puede **girar** si no es cuadrado.

  | Objeto | Tamaño |
  |---|---|
  | Llave, frasco, venda, pilas | 1×1 |
  | Linterna, destornillador, fusible | 1×2 |
  | Palanca | 1×3 |
  | Válvula | 2×2 |

- **Apilado**: hasta `max_stack` unidades por montón. Los ejemplares contaminados no se mezclan con los limpios.
- **Reorganizar**:
  - con ratón: arrastrar y soltar; clic derecho mientras arrastras gira el objeto;
  - con teclado: Intro coge y suelta, R gira.
- **Combinar**:
  - soltando un objeto **encima de otro**;
  - o con C, eligiendo el segundo objeto y pulsando Intro.
- **Usar**: E, doble clic o clic derecho. **Examinar**: X, que abre el inspector con 8 vistas giratorias.

### B. Bolsillos de acceso rápido

- 5 huecos **independientes de la bandeja**: lo que va en un bolsillo deja de ocupar casillas.
- Se usan durante la exploración con las teclas **1–5**, sin abrir la custodia. La linterna en un bolsillo se enciende y apaga.
- El HUD los muestra un momento cuando se usan o cambian.

### C. Expediente personal

- Documentos, fotografías, planos, etiquetas: **no ocupan sitio** en la bandeja.
- Lista a la izquierda (• = sin leer) y lector en papel a la derecha. Cada tipo tiene su aspecto: mecanografiado, a mano o ficha. También admite imagen y sello en rojo.
- Leer algo en el mundo lo añade y abre el lector directamente.

### Constantes

Bajo la bandeja: barras de Cuerpo y Mente, aviso de sangrado y carga de la linterna.

## Propiedades de un objeto (`ItemDef`)

| Propiedad | Para qué |
|---|---|
| `display_name`, `description` | Nombre y texto al seleccionarlo |
| `icon`, `inspect_sheet` | Icono de la bandeja y vistas del inspector |
| `size` | Casillas que ocupa |
| `max_stack` | Cantidad máxima por montón |
| `max_durability` | Usos antes de romperse (herramientas) |
| `max_charge` | Carga (linterna) |
| `contaminated` | Viene contaminado; al usarlo penaliza |
| `usable`, `use_effects`, `use_verb`, `consumed_on_use` | Qué pasa al usarlo |
| `key_item` | Objeto clave (no se puede perder) |

El **estado** de cada ejemplar (`ItemStack`) es cantidad, durabilidad, carga y contaminación. Se muestra como texto («Carga 40 %», «Desgastado», «Contaminado»).

**Efectos disponibles** (`scripts/core/items/effects/`):
- `HealEffect`: Cuerpo, Mente, cortar sangrado; con penalización si está contaminado.
- `RechargeEffect`: carga la linterna.
- `ToggleFlashlightEffect`: enciende o apaga la linterna.

Se añaden efectos nuevos creando una subclase de `ItemEffect`.

## Combinaciones (`RecipeDef`)

| Combinación | Resultado |
|---|---|
| Venda + desinfectante | Venda esterilizada (el desinfectante gasta un uso) |
| Venda usada + desinfectante | Venda limpia |
| Pilas + linterna | +45 % de carga (se gasta una pila) |
| Jeringa + ampolla | Sedante |
| Destornillador + válvula averiada | Válvula reparada (el destornillador gasta un uso) |

Además, hay objetos que se **usan sobre el mundo** (`ItemUse` en un `Interactable`):
- la palanca en la puerta atascada;
- el destornillador en el cuadro;
- el fusible en su hueco;
- la válvula en el generador.

## Cómo añadir cosas

- **Objeto nuevo**: crear un `.tres` de `ItemDef` en `data/items/` (o añadirlo a `tools/data/build_items.gd`). Para generar su icono y sus vistas, añadirlo a `tools/art/items.py`.
- **Receta nueva**: un `.tres` de `RecipeDef` en `data/recipes/`.
- **Documento nuevo**: un `.tres` de `DocumentDef` en `data/documents/` (o en `tools/data/build_documents.gd`).

`Registry` los encuentra solos; no hay que tocar código.

## Decisiones

- **No se pueden tirar objetos.** Así ningún objeto clave se pierde y no hace falta guardar objetos sueltos por el suelo. El espacio está calculado para que haya que organizar, pero el camino principal siempre cabe. Las llaves y la palanca se quedan puestas al usarlas.
- **Si algo no cabe**, se queda donde estaba («No te cabe en la bandeja») y se puede volver a por ello.
