# El protagonista: hojas, animaciones y ropa

Cómo se genera y cómo se anima el protagonista del prólogo. La dirección de arte está en
[la guía estética](../art/guia-estetica.md); aquí va la parte técnica.

## Generadores

| Archivo | Qué hace |
|---|---|
| `tools/art/pxrender.py` | Raytracer de píxeles con proyección oblicua. Con numpy (si está instalado) traza cada primitiva de golpe; sin él, Python puro con el mismo resultado. |
| `tools/art/human.py` | Modelo del cuerpo y de la ropa, posturas (`Pose`) y ciclos: reposo, gestos, paso, paso de espaldas, paso lateral, giro en el sitio. Cinemática inversa de brazos (`arm_ik`) y piernas (`leg_ik`). |
| `tools/art/motion.py` | Coreografía que no es un ciclo: las 8 acciones de interacción y levantarse de la camilla. |
| `tools/art/character.py` | Renderiza las hojas por capas y escribe la entrada `protagonist` de `sprite_meta.json`. |
| `tools/levels/build_wear.gd` | Crea los objetos de ropa y las `CanvasTexture` de cada hoja de cada prenda. |
| `tools/levels/build_player.gd` | Crea `scenes/world/player/player.tscn` con los datos de las hojas. |

`human.build_pose(pose)` y `human.build(phase, pose)` siguen existiendo tal cual para las
camillas de `tools/art/props*.py`.

### Regenerar

```bash
python -I tools/art/character.py                       # todo: cuerpo + 9 prendas, 5 hojas (~40 min con 3 núcleos)
python -I tools/art/character.py --sheets getup body bata_paciente   # solo una parte
"$GODOT_BIN" --headless --path . --import
"$GODOT_BIN" --headless --path . res://tools/levels/build_wear.tscn
"$GODOT_BIN" --headless --path . res://tools/levels/build_player.tscn
```

`--procs N` limita los procesos. Lo que no se renderiza conserva sus datos en `sprite_meta.json`.
Un fotograma tarda ~0,15 s (la bata de médico ~0,25 s).

## Hojas

Fotograma de 48×68 px con los pies en (24, 62), salvo la de levantarse. Todas las capas
(cuerpo y prendas) tienen las mismas hojas con la misma distribución, así que comparten el
número de fotograma. Ninguna pasa de 16384 px de ancho.

| Hoja | Sufijo | Filas | Columnas | Qué |
|---|---|---|---|---|
| `move` | — | 16 | 76 | Andar sin linterna |
| `move_flash` | `_flash` | 16 | 76 | Andar con la linterna |
| `action` | `_action` | 8 | 80 | Acciones sin linterna |
| `action_flash` | `_action_flash` | 8 | 80 | Acciones con linterna |
| `getup` | `_getup` | 1 | 56 | Levantarse (fotograma de 56×84) |

Filas: orientaciones en el orden del ángulo en pantalla, empezando por abajo y girando hacia
la izquierda: `fila = round((ángulo − 90°) / (360° / filas)) mod filas` (`Player.row_for_angle`).
Con 16, cada 22,5°: 0 abajo, 4 izquierda, 8 arriba, 12 derecha.

Columnas de `move` y `move_flash` (iguales en las dos):

| Columnas | Animación | Fotogramas | Avanza con |
|---|---|---|---|
| 0–7 | Reposo (respira) | 8 | el tiempo (3,3 fps) |
| 8–19 | Gesto: mano a la herida / con linterna, mira alrededor | 12 | el tiempo (7 fps) |
| 20–31 | Paso hacia delante | 12 | la distancia (64 px por ciclo) |
| 32–43 | Paso de espaldas | 12 | la distancia (44 px) |
| 44–55 | Paso lateral hacia su izquierda | 12 | la distancia (58 px) |
| 56–67 | Paso lateral hacia su derecha | 12 | la distancia (58 px) |
| 68–75 | Giro en el sitio (arrastra los pies) | 8 | el tiempo (14 fps) |

Acciones (10 fotogramas cada una, 11–13 fps, 0,75–0,9 s): `reach_low` 0–9, `reach_mid` 10–19,
`reach_high` 20–29, `pickup` 30–39, `key` 40–49, `valve` 50–59, `lever` 60–69, `pry` 70–79.

### Datos por fotograma (`sprite_meta.json` → `protagonist.sheets.<hoja>`)

- `lens[fila][columna]`: lente de la linterna respecto a los pies (`[x, y]`), para que la luz
  salga de ella. Solo en las hojas con linterna.
- `hand[fila][columna]`: mano libre (la izquierda): `[x, y, ángulo del arma en grados, 1 si va
  por delante del cuerpo]`. Lo usa `Player.set_held_weapon`.
- `fps` (acciones y levantarse), `stand` y `sounds` (levantarse).

## En el juego (`Player`)

- **Paso según la dirección**: con el ángulo entre hacia dónde anda y hacia dónde mira elige
  de frente (< 50°), de espaldas (> 130°) o de lado, con 8° de margen para no parpadear. El
  paso lateral gira la cadera 90° hacia donde va: así las piernas andan de verdad (sin
  patinar) y el tronco y la cabeza siguen mirando al frente. Para que los pies no patinen en
  los ángulos intermedios, el cuerpo se gira hasta una orientación (22,5°) hacia donde van las
  piernas; la luz sigue apuntando al puntero.
- **Giro en el sitio**: parado, si tiene que girar 3 orientaciones o más (> 45°), arrastra los
  pies y gira algo más despacio.
- **Acciones**: `play_action(acción, destino)` (corrutina). Se gira hacia el destino pasando por
  las intermedias, se acerca hasta 14 px si está a más de 30 px, cambia a la hoja de acciones
  (8 orientaciones; se usa la más cercana), reproduce y vuelve. Una acción desconocida no hace
  nada. La mano izquierda hace la acción; la derecha sujeta la linterna (en la válvula y al
  forzar con la palanca, bajo el brazo) o, sin ella, se apoya en la rodilla, se agarra la
  herida o ayuda.
- **Levantarse**: `prepare_get_up(camilla)` deja al jugador invisible junto a la camilla (para
  que la cámara esté ahí durante el fundido); `play_get_up(camilla)` dibuja la secuencia encima
  de la camilla deshecha. Se renderiza con la misma proyección que los objetos del mapa
  (b = 1) y el cuerpo colocado como en la camilla "tumbado", así que el primer fotograma
  coincide con ella. Los últimos fotogramas pasan a la proyección del personaje (b = 0,45)
  sin mover los pies, y acaba de pie a su izquierda (19 px a la derecha del centro de la
  camilla, fuera de su colisión), mirando a la derecha.
- **Arma**: `set_held_weapon(textura)` dibuja un `Sprite2D` pequeño (15 px) en la mano libre,
  girado según el fotograma y detrás del cuerpo cuando la mano queda detrás. Se oculta durante
  acciones y al levantarse.
- **Memoria de vídeo**: solo está cargada la hoja que se usa (cuerpo y prendas puestas). Al
  coger la linterna se cambia `move` por `move_flash`; las acciones y levantarse se cargan al
  empezar y se sueltan al terminar. `ItemDef.wear_path` guarda la ruta de la hoja de andar de
  cada prenda (no la textura), así que las prendas que no se llevan no ocupan memoria;
  `ItemDef.wear_sheet` la carga al pedirla.

## Física de la ropa

`Player._update_cloth` es un muelle amortiguado (se queda atrás al andar, sigue de largo al
frenar, ondea con cada paso y sale despedido al girar). El shader `cloth_sway.gdshader`
desplaza los píxeles según su altura sobre los pies: nada en la cintura (`waist`) y todo en el
bajo (`hem`). Cada prenda trae sus alturas en `ItemDef.cloth_waist` y `ItemDef.cloth_hem`.

Antes el shader usaba el mismo bajo para todas (12 px, el de la bata de médico): la bata de
paciente acaba a ~16 px, así que su bajo solo recibía la mitad del balanceo y apenas se notaba.
Lo comprueba `test_la_bata_inicial_se_balancea`.

## Sonidos de levantarse

Se piden con `Sfx.at` en fotogramas concretos (`motion.GETUP_SOUNDS`). Mientras no estén en
`assets/audio/sfx/` no suenan (Sfx avisa por consola). Qué buscar en Freesound:

| Sonido | Qué |
|---|---|
| `breath_wake_male` | Hombre adulto que despierta: inspiración brusca y temblorosa por la nariz, 1–1,5 s, cerca del micro, sin voz. |
| `pain_sigh_male` | Suspiro de dolor contenido de hombre adulto, exhalación entrecortada con un leve quejido, 1–2 s. |
| `pain_groan_male` | Gemido de dolor contenido de hombre adulto con la boca cerrada (esfuerzo al incorporarse), 1–2 s, seco. |
| `breath_strain_male` | Respiración de esfuerzo de hombre: dos o tres exhalaciones cortas apretando los dientes, 1,5–2 s. |
| `cloth_rustle` | Roce de sábana o bata fina de algodón al moverse en una cama, 1 s, suave. |
| `bare_feet_floor` | Pies descalzos que se apoyan en suelo de baldosa, peso que cae con cuidado, 0,5–1 s. |

`bed_creak` ya existe (crujido de la camilla).
