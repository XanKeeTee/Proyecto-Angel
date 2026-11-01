# Técnica — Proyecto-Angel

Las convenciones de código, comandos y estructura de carpetas están en [CLAUDE.md](../../CLAUDE.md). Aquí va lo que necesita más detalle.

## Documentos

- [tests.md](tests.md) — propuesta de framework de tests (pendiente de decisión).

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

> Decisión abierta: RPG Maker MV/MZ usa 816×624 (casi 4:3) con tiles de 48 px. Si queremos ese encuadre más "cuadrado", hay que decidirlo antes de producir arte. Tamaño de tile: **pendiente** (16, 24, 32 o 48 px).

## Prototipo de combate

Escena principal del proyecto: `res://scenes/battle/battle_scene.tscn`. Pulsa F5 en el editor o ejecuta:

```bash
"$GODOT_BIN" --path .
```

- **Controles**: ratón, o flechas + Intro. **F2** activa o desactiva el filtro VHS.
- **Contenido**: 3 aliados (PROTAGONISTA, ALIADO 1, ALIADO 2) contra 2 enemigos (ENEMIGO A, ENEMIGO B). Nombres y gráficos provisionales: rectángulos que cambian de color según el estado de cada parte (hueso = Sana, ámbar = Herida, rojo oscuro = Rota, contorno = Amputada).
- **Datos**: los `.tres` de `data/` se editan desde el inspector de Godot.
- **Depuración** (argumentos tras `--`):

  ```bash
  "$GODOT_BIN" --path . -- --autoplay=3 --screenshot=captura.png
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
