# Proyecto-Angel — guía para Claude

JRPG 2D de terror analógico hecho en **Godot 4.7.2** con **GDScript**. Equipo de 2 personas: ambas guionizan y revisan código y arte. Los documentos y comentarios se escriben en **español**; los identificadores de código, en **inglés**.

## Motor

- Versión: **Godot 4.7.2-stable** (`4.7.2.stable.official.ed1daf0bf`).
- Ejecutable (máquina de Miguel):
  `C:\Users\usuario\Documents\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- Usa siempre la variante `_console.exe` desde la terminal: la versión sin `_console` no devuelve la salida ni el código de error.
- Cada persona define la variable de entorno `GODOT_BIN` con la ruta de su ejecutable. Los comandos de este documento la usan. Si no existe, usa la ruta de arriba.

```bash
export GODOT_BIN="/c/Users/usuario/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
```

## Ejecutar Godot en headless

```bash
# Comprobar versión
"$GODOT_BIN" --version

# Importar recursos y comprobar que el proyecto carga sin errores
"$GODOT_BIN" --headless --path . --import

# Comprobar errores de parseo de un script concreto
"$GODOT_BIN" --headless --path . --check-only --script res://ruta/al/script.gd

# Arrancar el juego sin ventana y salir tras N frames (smoke test)
"$GODOT_BIN" --headless --path . --quit-after 120
```

## Tests

El framework **aún no está instalado**. Propuesta y comparativa en [docs/tech/tests.md](docs/tech/tests.md) (recomendación: GUT). Cuando se instale, este apartado tendrá el comando exacto. Previsto:

```bash
"$GODOT_BIN" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- Los tests viven en `tests/unit/` (lógica pura: daño, heridas, estados) y `tests/integration/` (escenas, flujo de combate).
- Archivo de test: `test_<sistema>.gd`. Cada bug corregido añade un test que lo reproduce.
- No se hace merge a `main` con tests en rojo.

## Convenciones de GDScript

- **Tipado estático obligatorio**: variables, parámetros y retornos (`var hp: int = 10`, `func apply_wound(part: BodyPart) -> void:`). Usa `:=` solo si el tipo es obvio a la vista.
- Activar en Project Settings → Debug → GDScript los avisos `untyped_declaration` e `inferred_declaration` como **Warning** (el CI los tratará como error más adelante).
- **Nombres**:
  - Archivos y carpetas: `snake_case` (`body_part.gd`, `battle_scene.tscn`).
  - Clases (`class_name`) y nodos: `PascalCase`.
  - Funciones y variables: `snake_case`. Privadas con prefijo `_`.
  - Constantes y valores de enum: `UPPER_SNAKE_CASE`.
  - Señales: `snake_case` en pasado (`wound_inflicted`, `turn_ended`).
- **Orden dentro de un script** (guía oficial de Godot): `class_name`, `extends`, docstring `##`, señales, enums, constantes, `@export`, variables públicas, privadas, `@onready`, `_init`, `_ready`, otros callbacks, métodos públicos, métodos privados.
- **Señales**: "llama hacia abajo, señaliza hacia arriba". Un nodo hijo nunca busca a su padre con `get_parent()`; emite una señal. Conectar por código con `signal.connect(callable)`, no con strings.
- **Autoloads**: solo para estado global y servicios transversales. Mantenerlos pocos y finos. Previstos (todavía no existen):
  - `EventBus`: señales globales desacopladas.
  - `GameState`: banderas de historia, decisiones, rutas.
  - `SaveSystem`: guardado/carga.
  La lógica de combate **no** va en un autoload: vive en la escena de combate y en `Resource`s.
- **Datos como `Resource`**: enemigos, objetos, armas, partes del cuerpo, heridas y estados se definen como `Resource` con `class_name` y se guardan como `.tres` en `data/`. Nada de números mágicos en el código.
- Separar lógica de presentación: las reglas de combate deben poder ejecutarse y testearse sin escena ni nodos visuales.
- Rutas con `res://` y `preload` para recursos fijos; `@export` antes que `get_node("...")` con rutas largas. Usa `%NombreUnico` para nodos únicos de escena.
- Docstrings con `##` en clases y métodos públicos.

## Estructura de carpetas

```
addons/            Plugins de terceros (GUT cuando se instale). No se editan a mano.
assets/            Arte y audio fuente importado por Godot
  sprites/  tilesets/  portraits/  ui/  fonts/  audio/{music,sfx}/
autoload/          Singletons registrados en project.godot
data/              Recursos .tres: enemies/, items/, skills/, body_parts/, statuses/
scenes/            Escenas .tscn con su script al lado (mismo nombre)
  world/  battle/  ui/  dialogue/
scripts/           Código que no pertenece a una escena concreta
  core/            Clases Resource y utilidades
  systems/         combat/, dialogue/, inventory/, save/
shaders/           .gdshader (VHS, CRT, aberración, grano)
tests/             unit/, integration/
docs/              lore/, design/, tech/, art/
.claude/agents/    Subagentes del proyecto
```

Un script ligado a una escena va junto a ella (`scenes/battle/battle_scene.tscn` + `battle_scene.gd`).

## Reglas de lore (obligatorias)

- **Universo propio.** Inspiración estética y tonal: *Angel Engine*. Está **prohibido** usar los nombres "Uriel" o "Angel Engine" y copiar su premisa literal (un ángel capturado usado como batería de una máquina).
- **Idea central que sí mantenemos**: la humanidad recibió un milagro y lo convirtió en herramienta de explotación. Futuro postapocalíptico donde se juega a ser Dios mediante experimentos, tecnología y rituales.
- **El canon vive en `docs/lore/`.** Antes de escribir diálogos, descripciones de objetos, nombres o eventos, léelo. Si algo contradice el canon, se señala; no se "arregla" en silencio.
- Claude **no inventa canon por iniciativa propia**. Puede proponer, pero lo propuesto se marca como `[PROPUESTA]` hasta que las dos personas del equipo lo aprueben.
- Para dudas de coherencia, usa el subagente `lore-keeper`.

## Subagentes (`.claude/agents/`)

| Agente | Para qué |
|---|---|
| `lore-keeper` | Canon, coherencia, nombres, revisión de textos |
| `game-designer` | Sistemas, balance, GDD |
| `godot-dev` | Código GDScript y escenas |
| `shader-fx` | Shaders y post-procesado VHS/CRT |
| `qa-tester` | Ejecución headless, tests, informes de bugs |

## Flujo de trabajo con git

- Nunca se trabaja directamente en `main`. Ramas: `feat/…`, `fix/…`, `docs/…`, `lore/…`, `chore/…`.
- Commits pequeños y en español, en imperativo ("Añade sistema de heridas").
- **No hacer push sin preguntar** al equipo.
- Los cambios de lore y de diseño los revisan las dos personas antes del merge.
- Fin de línea LF (ver `.gitattributes`).

## Documentación

- [docs/lore/](docs/lore/README.md) — canon del mundo (vacío por ahora).
- [docs/design/](docs/design/README.md) — GDD y sistemas.
- [docs/tech/](docs/tech/README.md) — arquitectura, tests, convenciones técnicas.
- [docs/art/guia-estetica.md](docs/art/guia-estetica.md) — dirección de arte.
