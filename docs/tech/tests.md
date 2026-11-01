# Propuesta: framework de tests

> Estado: **pendiente de decisión**. Nada instalado todavía.

## Candidatos

| | **GUT** (Godot Unit Test) | **gdUnit4** |
|---|---|---|
| Lenguaje | GDScript puro | GDScript (y C#) |
| Instalación | Copiar `addons/gut/` o Asset Library | Copiar `addons/gdUnit4/` o Asset Library |
| Ejecución headless | `-s addons/gut/gut_cmdln.gd` | Script `runtest` propio |
| Asserts | Clásicos (`assert_eq`, `assert_true`…) | Fluidos (`assert_int(x).is_equal(5)`) |
| Dobles / mocks | Doubles, stubs, spies | Mocks y spies |
| Tests de escena / input | Básico (simular frames, señales) | **Scene runner** con simulación de input |
| Informes | Consola, JUnit XML | Consola, HTML, JUnit XML |
| CI | Comando directo en cualquier CI | GitHub Action oficial |
| Riesgo de versión | Bajo: históricamente aguanta bien entre versiones menores de Godot | Medio: suele requerir la versión del plugin ligada a la versión de Godot |
| Curva de aprendizaje | Baja | Media |

## Recomendación: **GUT**

1. La parte crítica que testear es **lógica pura** (daño por parte del cuerpo, heridas permanentes, acumulación de estados, patrones enemigos, banderas de decisión). GUT cubre esto de sobra y con menos ceremonia.
2. Es GDScript puro y sencillo de leer, lo que ayuda a que las dos personas revisen tests sin aprender una API fluida nueva.
3. El comando headless es un único script, fácil de documentar en `CLAUDE.md` y de usar desde los subagentes.

Elegiríamos **gdUnit4** si preferimos priorizar tests de interfaz e input (menús de combate, selección de parte del cuerpo con teclado/mando) con su scene runner, o una GitHub Action ya hecha.

## Compatibilidad con Godot 4.7.2 — verificar al instalar

No hemos encontrado (noviembre de 2026) una nota oficial que confirme compatibilidad explícita con 4.7 para ninguno de los dos:

- GUT: la Asset Library lista 9.6.1 para Godot 4.6 y existe una 9.7.x sin requisitos publicados. Fuentes: [Godot Asset Store — GUT](https://store.godotengine.org/asset/bitwes/gut/), [Asset Library](https://godotengine.org/asset-library/asset/edit/21096).
- gdUnit4: revisar su página de releases en GitHub y elegir la versión que declare 4.7.

**Paso de verificación al instalar**: descargar la última versión, ejecutar un test trivial en headless con 4.7.2 y comprobar que no hay errores de parseo ni avisos del plugin. Fijar la versión exacta en este documento.

## Plan de instalación (cuando se apruebe)

1. Rama `chore/tests-gut`.
2. Copiar el addon a `addons/gut/` (sin modificarlo) y activarlo en Project Settings → Plugins.
3. Crear `.gutconfig.json` con `dirs: ["res://tests/"]`, `include_subdirs: true`, `prefix: "test_"`, `should_exit: true`.
4. Añadir un test de humo en `tests/unit/test_smoke.gd`.
5. Comando:

   ```bash
   "$GODOT_BIN" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
   ```

6. Actualizar la sección Tests de `CLAUDE.md` y los subagentes `qa-tester` y `godot-dev` si el comando cambia.
7. Más adelante: CI en GitHub Actions con Godot headless.
