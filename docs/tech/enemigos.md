# Sprites de enemigos — el enfermero transfigurado `[PROPUESTA]`

Generador: `tools/art/enemy_enfermero.py` (modelo, esqueleto, animaciones, hojas y `sprite_meta.json`), sobre
`tools/art/enemy_render.py` (renderizador vectorizado reutilizable para otros enemigos). Concepto en el brief de la
tercera ronda y en `docs/lore/prologo.md`; nada de esto es canon.

```bash
python -I tools/art/enemy_enfermero.py                      # todo (≈1,5 min con 3 procesos)
python -I tools/art/enemy_enfermero.py --only combat        # solo el combate
python -I tools/art/enemy_enfermero.py --only map           # solo el sprite del mapa y el cadáver
python -I tools/art/enemy_enfermero.py --only combat --anims idle,death --procs 3   # repasar unas animaciones
```

Escribe `assets/sprites/enemies/enfermero/` y las claves `enemy_enfermero` y `enemy_enfermero_map` de
`tools/art/sprite_meta.json` (el resto del archivo no se toca). Después hay que importar en Godot.

Depuración: `ENEMY_DEBUG=mat` (un color plano por material), `ENEMY_DEBUG=albedo` (sin luz) y
`ENEMY_DEBUG=noshadow`.

## Cómo se renderiza

- **Modelo**: volúmenes de `pxrender.py` (elipsoides, cápsulas, cilindros, cajas) colgados de un esqueleto de huesos
  rígidos (`BONES`: pelvis, lumbar, tórax, cuello, cabeza, mandíbula, clavículas, brazos, antebrazos, manos, muslos,
  espinillas, pies, cuatro bisturíes y el émbolo de la jeringa). Cada postura (`Pose`) da una rotación local por hueso;
  la cinemática directa coloca cada pieza y un paso final apoya el punto más bajo en el suelo.
- **Anatomía**: deltoides de tres cabezas, bíceps y tríceps consumidos, codos de nudos (olécranon y epicóndilos),
  antebrazos con braquiorradial, flexores, extensores, cúbito y tendones; manos con metacarpianos y nudillos;
  rodillas huesudas (cóndilos, rótula, tuberosidad), tibia de filo, gemelos, Aquiles y maléolos; pies con tendones;
  cuello con esternocleidomastoideo y cuerdas tensas; costillas, esternón, clavículas y vientre hundido por los
  desgarros. Postura encorvada y asimétrica: hombro derecho caído, pierna derecha torcida hacia dentro, cabeza
  adelantada y ladeada.
- **Cabeza**: cráneo con orejas (concha), arcos cigomáticos y ángulos de la mandíbula; cuero cabelludo a
  trasquilones con costras y grapas; carne hinchada que rebosa alrededor de la porcelana; puntos de sutura de hilo
  que cruzan el borde de la mascarilla.
- **Uniforme**: costuras laterales con pespunte, bolsillo del pecho, botones, pespunte del bajo, pliegues de caída
  y rebordes de tela amontonada en rodillas y tobillos, jirones colgando (bajo, mangas, perneras, colgajo del
  pecho), sangre que empapa y brilla húmeda, bilis, manchas casi negras y mugre acumulada abajo.
- **Texturas en reposo**: los materiales se evalúan en las coordenadas del modelo en reposo, así que la sangre, las
  venas, la trama de la tela y las grietas de la porcelana se mueven con la carne en vez de «nadar».
- **Materiales vectorizados** (numpy): piel gris azulada con moteado lívido, venas (ruido de crestas) en relieve,
  suciedad en los pies; uniforme blanco con pliegues, trama, mugre, manchas de fluido con cerco y sangre seca que
  empapa los bordes de los desgarros y baja en regueros; porcelana brillante con grietas y mugre metida; acero
  cepillado con brillo especular; hojas de espejo con la punta ensangrentada; tubos de goma con líquido oscuro;
  cristal graduado de la jeringa; carne viva húmeda, hueso y médula en los muñones.
- **Desgarros**: campos escalares (`TEARS`) que a la vez recortan la tela (`vcut`) y oscurecen y ensangrientan su
  borde. La casaca es un solo volumen en rodajas (`_TUNIC_KEYS`) que cuelga suelta sobre el cuerpo consumido.
- **Luz**: luz lateral fría desde la izquierda de la pantalla (con sombras arrojadas por mapa de sombras), contraluz
  granate por la derecha, rebote violeta muy tenue, oclusión ambiental en pantalla, luz envolvente en la piel.
  Se trabaja en lineal y se vuelve a sRGB; al final, tramado Bayer a 32 niveles por canal. Sin contorno negro.
- **Capas**: una sola pasada con un búfer de profundidad por capa. Cada capa se dibuja completa (lo que hay detrás
  de un brazo está pintado), las extremidades y muñones se recortan solo donde el tronco (`body`) les queda delante,
  y los brazos y la cabeza dejan una sombra de contacto semitransparente que va en su propia capa (desaparece con ella).

## Combate (`enemy_enfermero`)

Una hoja por capa en rejilla de **8 columnas × 9 filas** (2176×2808; Godot no carga texturas de más de 16384 px
por lado), con los 68 fotogramas en orden de lectura por filas: el índice de `anims` es el `frame` de un `Sprite2D`
con `hframes`/`vframes`. Fotograma de **272×312**, pies en **(122, 284)**; en reposo mide ~210 px (cabe sobre los pies
del combate, `ENEMY_FEET.y = 238`). El modelo se dibuja a `MODEL_SCALE` = 1,05. Cada capa tiene su mapa de normales
`_n.png` (salvo `shadow`). Tras regenerar: importar y `"$GODOT_BIN" --headless --path . -s tools/data/build_enemies.gd`
(hornea `data/enemies/enfermero_sprites.tres`). `tests/unit/test_enemy_sprites.gd` comprueba tamaños y rejilla.

| Clave | Contenido |
|---|---|
| `frame`, `origin`, `hframes`, `vframes` | tamaño del fotograma, píxel de los pies, columnas y filas de la rejilla |
| `layers` / `normals` | ruta de cada capa / de sus normales |
| `order` | de atrás adelante: `shadow`, `leg_l`, `leg_r`, `body`, `stump_*`, `head`, `arm_l`, `arm_r` |
| `anims` | `[inicio, nº, fps, bucle]` |
| `anchors` | centro de cada parte en el reposo (para marcar la parte apuntada) |
| `stumps`, `parts` | capa del muñón de cada parte; parte del combate → capa (`torso` → `body`) |

`shadow` es la sombra blanda en el suelo (opcional). Los muñones (`stump_<parte>`) se muestran solo cuando esa parte
está amputada; ocultar la parte y mostrar su muñón no deja huecos. `l`/`r` son la izquierda y la derecha **del
enfermero** (el brazo derecho, el de los bisturíes y la sierra, queda a la izquierda de la pantalla).

| Animación | Fotogramas | fps | Qué hace |
|---|---|---|---|
| `idle` | 12 | 8 | bucle: respiración irregular con enganche, temblor, la cabeza se ladea con un tic, los bisturíes se abren y cierran a destiempo |
| `windup` | 8 | 12 | se encorva y alza el brazo instrumental por encima del hombro (queda en la última pose) |
| `attack` | 8 | 16 | tajo diagonal rápido con giro de todo el cuerpo y vuelta a la guardia |
| `attack_syringe` | 10 | 14 | alza la jeringa como un punzón, la clava hacia delante y aprieta el émbolo |
| `hit` | 6 | 12 | la cabeza y el tronco salen despedidos hacia atrás y vuelve temblando |
| `stagger` | 10 | 10 | la pierna derecha cede, se va de lado, abre los brazos y se recompone a medias |
| `death` | 14 | 10 | se le doblan las rodillas, cae de rodillas y se desploma de lado |

Las animaciones que no son bucle empiezan y acaban cerca del reposo (salvo `windup`, que enlaza con `attack`, y `death`).

## Mapa (`enemy_enfermero_map`)

- `map.png` (+ `_n`): fotograma **56×80**, pies en **(28, 74)**, 8 orientaciones en filas (mismo orden que el
  protagonista: fila 0 mirando abajo y girando hacia la izquierda), `idle` (4) y `walk` (8, arrastrando la pierna
  derecha). Misma proyección oblicua y luz que el protagonista, con contorno de color.
- `corpse.png` (+ `_n`): fotograma **88×56**, origen **(44, 34)**, variantes `whole` y `no_arm_r`.

## Sonidos que harían falta (Freesound)

Ninguno se sintetiza; los nombres los usaría el combate (`Sfx`).

- `enfermero_respira`: respiración húmeda y entrecortada a través de una tela, con un enganche en la garganta; 2-3 s, bucle; sin voz, sin gruñido de monstruo.
- `enfermero_bisturi`: tintineo metálico fino de instrumental quirúrgico (bisturíes que se rozan); 0,5-1 s; acero pequeño, nada de espadas.
- `enfermero_tajo`: silbido corto de hoja + desgarro de tela/carne; 0,3-0,6 s; seco, sin «whoosh» de película.
- `enfermero_jeringa`: émbolo de cristal que se hunde con un chasquido de goma y un chorro breve; < 1 s.
- `enfermero_golpe`: impacto sordo en un cuerpo flaco con crujido de porcelana; 0,4 s.
- `enfermero_cae`: cuerpo que cae de rodillas y luego de lado sobre baldosa, con metal que repica; 1,5-2 s.
- `enfermero_arrastre`: pie descalzo que se arrastra por baldosa sucia, un paso; 0,6 s (para el mapa).
