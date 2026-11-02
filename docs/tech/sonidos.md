# Sonido y música (Freesound)

Todos los sonidos y la música del juego saldrán de [Freesound](https://freesound.org), solo con licencias **CC0** o **CC BY** (uso comercial permitido; CC BY exige atribución). Los WAV actuales de `assets/audio/sfx/` son **provisionales sintetizados** y se sustituyen solos al traer los de Freesound: el juego los pide por nombre y no hay que tocar código.

| Qué | Dónde |
|---|---|
| Efectos y ambientes | `assets/audio/sfx/<nombre>.wav` — `Sfx.at(...)`, `Sfx.ui(...)`, `ItemSounds`, `Soundscape` |
| Música | `assets/audio/music/<nombre>.ogg` — `MusicPlayer` (bus `Música`) |
| Qué buscar para cada nombre | `tools/audio/sound_manifest.json` (lo genera `tools/audio/build_manifest.py`; cada entrada lleva una `note` en español) |
| Herramienta | `tools/audio/freesound.py` (`check`, `search`, `fetch`, `credits`) |
| Atribuciones | `tools/audio/credits.json` y `docs/art/creditos-sonido.md` (los escribe `fetch`) |

Si falta un archivo, `Sfx` avisa una vez por consola y no suena nada (o suena el provisional parecido que indique el código: `FALLBACK_SOUNDS` del título y del terror, `NAMED_PROVISIONAL`/`MATERIAL_PROVISIONAL` de `ItemSounds`). `tools/art/sounds.py` (los sintetizados) **no sobrescribe** ningún WAV que ya exista, así que `build_all.py` no pisa los de Freesound.

## Flujo para traerlos (próxima sesión)

1. **Crear la clave**: con una cuenta de Freesound, en <https://freesound.org/apiv2/apply> («Create new API credentials»). Sirve la *Client secret / API key* (no hace falta OAuth2: se descarga la vista previa OGG de alta calidad).
2. **Ponerla como variable de entorno** (no se guarda en el repositorio):
   ```bash
   export FREESOUND_API_KEY="la_clave"          # bash / Git Bash
   # PowerShell: $env:FREESOUND_API_KEY = "la_clave"
   ```
   Requisitos: Python 3 con `numpy` (`pip install numpy`) y `ffmpeg` con `libvorbis` en el PATH.
3. **Comprobar el manifiesto** (no necesita clave ni red):
   ```bash
   python3 -I tools/audio/freesound.py check
   ```
   Lista los nombres que usa el código sin entrada en el manifiesto y las entradas que no usa nadie (las marcadas `reserved` están a propósito). Debe decir «Todo cubierto».
4. **Traerlos todos**:
   ```bash
   python3 -I tools/audio/freesound.py fetch
   ```
   Para cada entrada busca (consulta principal y alternativas), puntúa los candidatos (relevancia, valoraciones, descargas, etiquetas `want`/`avoid`, duración), elige el mejor, lo descarga a `tools/audio/.cache/` (ignorada por git), lo prepara (filtro, recorte, fundidos, nivel, bucle sin costura, cortes de pisadas) y lo escribe con su nombre. Guarda el id elegido en `pick` del manifiesto en cuanto lo elige. Respeta el límite de la API (60 peticiones/minuto): la primera vez tarda unos 15 minutos. Si algo falla, al final dice qué entradas quedan; `fetch --missing` repite solo las que no tienen `pick`.
5. **Importar y probar**: `"$GODOT_BIN" --headless --path . --import`, las pruebas, y **escuchar en el juego** (título, despertar, pasillo, sótano con y sin corriente, custodia).
6. **Revisar los que no convenzan**:
   ```bash
   python3 -I tools/audio/freesound.py search amb_vent_loop     # 12 candidatos con su enlace
   ```
   Escucha los enlaces (`https://freesound.org/s/<id>/`), pon el id bueno en `pick` de esa entrada en `sound_manifest.json` y vuelve a traer solo esa: `python3 -I tools/audio/freesound.py fetch amb_vent_loop`. Si ningún candidato vale, afina `query`/`alt`/`want`/`avoid` en `tools/audio/build_manifest.py`, regenera (`python3 -I tools/audio/build_manifest.py`, conserva los `pick`), borra el `pick` de esa entrada y repite. Ajustes de nivel (`level`), recorte (`max_len`) o filtro (`af`) se aplican al volver a hacer `fetch` de esa entrada (usa la caché, no vuelve a descargar).
7. **Créditos**: `fetch` actualiza `docs/art/creditos-sonido.md`. Las CC BY deben aparecer también en los créditos del juego (`CREDITS` de `scenes/ui/title/title_screen.gd`; pendiente de pasar esa lista allí).
8. **Commit**: los WAV/OGG, `sound_manifest.json` (con los `pick`, para que sea reproducible), `credits.json` y el documento de créditos.

**Elecciones revisadas**: los ids escogidos a mano están en `REVIEWED_PICKS` de `tools/audio/build_manifest.py` (con el motivo) y mandan sobre lo que elija `fetch` solo. Para cambiar uno, cambia el id ahí, regenera el manifiesto y haz `fetch <nombre>`.

### Desde GitHub Actions

Freesound rechaza las conexiones desde algunas nubes (por ejemplo, las sesiones de Claude en la web). En ese caso, el flujo `.github/workflows/freesound.yml` lo hace en GitHub, en la rama `feat/sonidos-freesound`:

- Necesita el secreto del repositorio `FREESOUND_API_KEY` (Settings → Secrets and variables → Actions).
- Ejecuta las órdenes de `tools/audio/ci_jobs.txt` (una orden de `freesound.py` por línea: `fetch`, `fetch --missing`, `fetch door_open`…) y las búsquedas libres de `tools/audio/ci_queries.txt` (`nombre|consulta|dur_mín|dur_máx`, con etiquetas y descripción en el registro).
- Escribe en el registro la ficha de cada sonido elegido (título, etiquetas, descripción, duración, licencia) y sube los WAV/OGG, el manifiesto y los créditos a la misma rama.
- Se lanza al subir un cambio de esos dos archivos, del manifiesto, de las herramientas o del flujo.

`python3 -I tools/audio/test_freesound.py` prueba la herramienta sin red (manifiesto sin huecos, buscador de nombres, puntuación y proceso de audio).

## Música del menú

Solo en el título. `MENU_TRACKS` de `title_screen.gd` tiene tres candidatas; suena **una al azar entre las que existan** y, si no hay ninguna, no suena nada. Entra con un fundido de 6 s y se funde al empezar o cargar partida (mientras se rebobina la cinta). Con música, el ambiente del título baja. Volumen en Opciones → «Música» (bus `Música`, `Settings.music`).

| Nombre | Qué buscar |
|---|---|
| `music_menu_drone` | Dark ambient: dron oscuro y lento con capas que respiran; sin ritmo ni melodía clara |
| `music_menu_piano` | Piano lejano con mucha reverberación, notas sueltas, tensión sin resolver |
| `music_menu_tension` | Atmósfera de suspense (cuerdas graves, texturas), sin golpes ni sustos |

Se guardan en OGG (bucle sin costura con un fundido cruzado de 8 s, máx. 2,5 min). Tras escucharlas, se borran las que no gusten (o se quitan de `MENU_TRACKS`).

## Ambiente de fondo y paisaje sonoro del hospital

- **Fondo** (`ambience_loop`, nodo `%Ambience` del hospital): un tono de sala **limpio y muy bajo**. El provisional sintetizado tenía casi toda la energía por debajo de 60 Hz (un retumbo sucio); ahora está filtrado (paso alto a 110 Hz y bajo a 1,6 kHz, ~10 dB más bajo). Ya no suena desde el primer fotograma: entra en 9 s cuando el jugador tiene el control por primera vez (tras despertar, o al cargar).
- **Paisaje sonoro** (`Soundscape`, `scripts/systems/audio/`): según `data/audio/hospital_soundscape.tres` (`SoundscapeDef` con una lista de `AmbientSoundDef`). Se crea en `hospital.gd::_ready` con una línea. Cada sonido indica: bucle o suelto, zonas (en casillas) donde tiene que estar el jugador, si necesita corriente (`ANY`/`ON`/`OFF`), dónde suena (casillas, junto a cada fluorescente que funciona, alrededor del jugador o **con el jugador** —`LISTENER`, para los tonos de sala—), volumen y distancia, fundido propio (`fade`) y enfriamiento de los sueltos.
- **Tres capas**:
  1. **Tono de sala** que va con el jugador, uno por tipo de estancia (habitaciones, pasillo, baños alicatados, quirófano, vestíbulo, archivo, escalera, sótano, morgue) y el **aire del edificio**: con corriente, un zumbido grave y lejano y el siseo de los altavoces; sin corriente, el viento contra el edificio se oye más (nada lo tapa). Al pasar de sala, **fundido cruzado de 2,5 s** (4 s el aire del edificio).
  2. **Bucles posicionales**: fluorescentes, ventilación, relojes de pared, ventanas rotas, transformador de la lámpara del quirófano, hueco del ascensor, bomba y goteos del sótano, tuberías, nevera de la morgue, generador, cuadro eléctrico.
  3. **Sueltos** (32 tipos): crujidos y asentamiento, puertas y pasos lejanos, rejillas y conductos, cebadores, ratas, palomas, cristales que vibran, relés, cadenas, la morgue… Más frecuentes que antes (**4,5 s** mínimo entre dos) pero cada uno con su enfriamiento; dependen de la planta, de la sala y de la corriente.
- **Eco y distancia**: los sueltos suenan por el eco de la sala del jugador y, si están lejos, más apagados (ver «Acústica» abajo). Los bucles van secos por el bus `Ambiente` (ya traen su sala grabada).
- **Convivencia con el terror**: tras un susto del `HorrorDirector` los sueltos callan 14 s; mientras está la entidad, no hay sueltos y los bucles bajan 9 dB; nunca hay sueltos con el control bloqueado (textos, eventos, menús).
- El zumbido del **generador** lo lleva el paisaje sonoro (antes lo arrancaba `_power_on` y se perdía al cargar partida).

| Id | Tipo | Sonido | Cuándo | Qué es |
|---|---|---|---|---|
| `tono_habitaciones` | tono | `amb_tone_ward` | siempre | Habitaciones, enfermería, control, almacén |
| `tono_pasillo` | tono | `amb_tone_corridor` | siempre | Pasillo largo (y el pasillo imposible) |
| `tono_banos` | tono | `amb_tone_tiled` | siempre | Baños alicatados |
| `tono_quirofano` | tono | `amb_tone_or` | siempre | Quirófano |
| `tono_vestibulo` | tono | `amb_tone_hall` | siempre | Vestíbulo y recepción |
| `tono_archivo` | tono | `amb_tone_archive` | siempre | Archivo (sala seca de papel) |
| `tono_escalera` | tono | `amb_tone_stairwell` | siempre | Escalera de servicio (planta y sótano) |
| `tono_sotano` | tono | `amb_tone_basement` | siempre | Pasillo de mantenimiento, sala eléctrica, lavandería, calderas, taller |
| `tono_morgue` | tono | `amb_tone_morgue` | siempre | Morgue |
| `zumbido_edificio` | tono | `amb_building_hum` | con corriente | El edificio vivo (planta y sótano) |
| `viento_edificio` | tono | `amb_wind_building` | sin corriente | Viento contra el edificio (planta) |
| `viento_edificio_corriente` | tono | `amb_wind_building` | con corriente | El mismo, 6 dB más bajo |
| `megafonia_siseo` | tono | `amb_pa_hum` | con corriente | Los altavoces del techo encendidos |
| `fluorescentes` | bucle | `hum_loop` | con corriente | Zumbido junto a cada fluorescente encendido; se corta cuando el tubo parpadea |
| `ventilacion` | bucle | `amb_vent_loop` | con corriente | Rejillas de ventilación de los dos pasillos |
| `goteo_banos` | bucle | `amb_drip_loop` | siempre | Grifo que gotea en los baños |
| `tuberias_sotano` | bucle | `amb_pipes_loop` | siempre | Agua en las tuberías de la caldera (apagada) y de la lavandería |
| `nevera_morgue` | bucle | `amb_fridge_loop` | con corriente | Compresor de las cámaras frigoríficas |
| `generador` | bucle | `generator_loop` | con corriente | El generador de emergencia en marcha |
| `cuadro_electrico` | bucle | `amb_electric_buzz` | con corriente | Zumbido del cuadro eléctrico general |
| `relojes` | bucle | `amb_clock_tick` | siempre | Los cinco relojes de pared de la planta |
| `silbido_ventanas` | bucle | `amb_wind_window_loop` | siempre | Viento por la ventana rota de la 07 y la del pasillo |
| `lampara_quirofano` | bucle | `amb_lamp_transformer` | con corriente | Transformador de la lámpara del quirófano |
| `hueco_ascensor` | bucle | `amb_elevator_shaft` | siempre | Aire en el hueco del ascensor |
| `bomba_lavanderia` | bucle | `amb_pump_loop` | con corriente | Bomba de agua del sótano |
| `goteo_sotano` | bucle | `amb_drip_puddle_loop` | siempre | Goteo en charcos (lavandería y taller) |
| `crujidos_planta` | suelto | `amb_creak_building`, `amb_creak_wood` | siempre | El edificio cruje (madera y estructura) |
| `crujidos_sotano` | suelto | `amb_creak_metal`, `amb_concrete_groan` | siempre | Metal y hormigón que se asientan en el sótano |
| `golpes_tuberia` | suelto | `amb_pipe_knock` | siempre | Una tubería que golpea dentro de la pared |
| `agua_tuberias` | suelto | `amb_water_pipes` | siempre | Agua que corre por las tuberías de la pared |
| `viento_ventana` | suelto | `amb_wind_gust` | siempre | Ráfaga por una ventana rota (Habitación 07 y ventana del pasillo) |
| `monitor_lejano` | suelto | `amb_monitor_far` | siempre | Un monitor de constantes pita en alguna habitación lejana |
| `cables_ascensor` | suelto | `amb_elevator_cables` | siempre | Los cables del ascensor crujen en el hueco |
| `papeles_corriente` | suelto | `amb_paper_draft` | siempre | Papeles que se mueven con una corriente de aire |
| `gotas_sotano` | suelto | `drip`, `amb_drip_metal` | siempre | Gotas sueltas en charcos y en chapa |
| `chispas_cuadro` | suelto | `amb_spark_crackle` | con corriente | Chisporroteo del cuadro eléctrico |
| `puertas_lejanas` | suelto | `amb_door_far`, `amb_door_swing_far` | siempre | Una puerta que se cierra o se mueve sola, lejos |
| `pasos_lejanos` | suelto | `amb_steps_distant` | siempre | Pasos lentos muy lejos (raro: 140-260 s) |
| `asentamiento` | suelto | `amb_settle_thump`, `amb_settle_crack` | siempre | Golpes sordos y chasquidos de la estructura (planta) |
| `asentamiento_sotano` | suelto | `amb_settle_thump` | siempre | Lo mismo en el sótano |
| `rejillas` | suelto | `amb_vent_rattle` | siempre | Una rejilla que traquetea con la corriente |
| `conductos` | suelto | `amb_duct_pop` | siempre | Un conducto de chapa que chasquea |
| `cebadores` | suelto | `amb_ballast_tick` | con corriente | Tic de un fluorescente |
| `ventanas_tiemblan` | suelto | `amb_window_rattle` | siempre | Un cristal flojo que tiembla |
| `camilla_lejana` | suelto | `amb_trolley_far` | siempre | Una camilla rueda lejos y se para (raro) |
| `cristal_vibra` | suelto | `amb_glass_tinkle` | siempre | Frascos que tintinean (enfermería, quirófano, control) |
| `reles` | suelto | `amb_relay_click` | con corriente | Relés del cuadro eléctrico |
| `tuberias_tictac` | suelto | `amb_pipe_tick` | siempre | Tubería que se contrae (sótano) |
| `cadena` | suelto | `amb_chain_rattle` | siempre | La cadena del polipasto del taller |
| `camaras_morgue` | suelto | `amb_morgue_door_creak` | siempre | Una puerta de las cámaras que cede y cruje |
| `megafonia_chasquido` | suelto | `amb_pa_crackle` | con corriente | Chasquido de los altavoces |
| `ratas` | suelto | `amb_rats_wall` | siempre | Ratas en la pared o el falso techo |
| `palomas` | suelto | `amb_pigeon_flutter` | siempre | Una paloma que aletea (07 y escalera) |
| `generador_tose` | suelto | `amb_generator_cough` | con corriente | El generador falla un instante |
| `escombros` | suelto | `amb_debris_fall` | siempre | Yeso que cae del techo |
| `camas_lejanas` | suelto | `bed_creak` | siempre | Una cama que cruje en otra habitación |

Para añadir uno: una entrada nueva en el `.tres` (o en el inspector) y su búsqueda en `build_manifest.py` (`AMBIENT`, `AMBIENT_ROOMS` o `AMBIENT_MORE`); `check` avisa si falta.

## Buses, eco por sala y distancia

Los crea `AudioBuses.ensure()` (desde `Settings`) en este orden; cada uno manda a uno anterior:

| Bus | Manda a | Efectos | Qué pasa por él |
|---|---|---|---|
| `Master` | — | limitador (−1,5 dB) | todo |
| `Sala` | Master | EQ de 6 bandas + reverberación | lo que suena «en la sala»: efectos del mundo y sueltos del ambiente |
| `Ambiente` | Master | — | bucles y tonos de sala (secos) · volumen «Ambiente» |
| `Ambiente eco` | Sala | — | sueltos del paisaje sonoro · volumen «Ambiente» |
| `Ambiente lejos` / `muy lejos` | Ambiente eco | paso bajo 3,6 kHz / 1,5 kHz | sueltos a ≥ 230 / ≥ 400 px |
| `Música` | Master | — | música del menú (sin eco) |
| `Efectos` | Sala | — | `Sfx.at`: pasos, puertas, golpes, voces del jugador, sustos · volumen «Efectos» |
| `Efectos lejos` / `muy lejos` | Efectos | paso bajo 3,6 kHz / 1,5 kHz | `Sfx.at` a ≥ 230 / ≥ 400 px de la cámara |
| `Interfaz` | Master | — | `Sfx.ui`, menús, custodia, megafonía (sin eco) |

- **Acústica por sala** (`RoomAcoustics`, la actualiza `Soundscape`): `data/audio/hospital_acoustics.tres` (`AcousticsDef`) tiene un `AcousticSpaceDef` por tipo de sala con sus zonas, los parámetros de la reverberación (tamaño, amortiguación, anchura, paso alto, mezcla seca/húmeda, primera reflexión y su realimentación) y 6 ganancias de EQ. Al cambiar de sala, los parámetros se mezclan en ~1,2 s. Al salir del mapa vuelve a «sin sala» (título y lo demás, secos).
- Mezcla **moderada**: húmedo 0,08 (archivo) – 0,28 (pasillo imposible), seco 1.

| Espacio | Salas | Carácter |
|---|---|---|
| `alicatado` | baños | pequeña y brillante (cola corta que no se apaga en agudos) |
| `morgue` | morgue | acero y azulejo: brillante, fría |
| `quirofano` | quirófano | superficies duras, cola media |
| `escalera` | escalera (planta y sótano) | hormigón: cola larga y un rebote |
| `archivo` | archivo | papel y madera: casi seca, apagada |
| `habitacion` | habitaciones, enfermería, control, almacén | pequeña, algo amortiguada |
| `vestibulo` | vestíbulo y recepción | grande, primera reflexión tardía |
| `pasillo_imposible` | el pasillo imposible | demasiado largo: cola y eco exagerados, sin agudos |
| `pasillo` | pasillo largo | eco de pasillo (primera reflexión a 35 ms y rebote) |
| `sotano` | resto del sótano | grande y grave, cola larga, agudos apagados |
| `edificio` (por defecto) | cualquier otro sitio | intermedio |

- **Opción «Eco de las salas»** (Opciones; `Settings.echo`, se guarda): apaga la reverberación y la EQ de `Sala`. El paso bajo por distancia se queda (no es eco).

## Grupos del manifiesto

`build_manifest.py` ordena las entradas por grupos: mundo (luz, máquinas, puertas, muebles), jugador (pisadas, levantarse, escaleras), paisaje sonoro (`amb_*`: `AMBIENT`, tonos de sala y aire del edificio en `AMBIENT_ROOMS`, sueltos y bucles nuevos en `AMBIENT_MORE`; grabaciones de campo reales, nada diseñado ni sintético), terror (`entity_*`, `scare_*`), estado e interfaz (`status_*`, `ui_*`, título), música (`music_menu_*`), usar/fabricar objetos (`use_*`, `craft_*`, `cloth_tear`) y custodia (`inv_<material>_<acción>` para los 12 materiales y 6 acciones, más `inv_<acción>` genéricos). Lo que hay que buscar para cada uno está en su `note`, `query` y `alt`.

Reservados (en el manifiesto, aún sin uso en el código): `breaker` (palanca del cuadro), `unlock` (llave), `monitor_beep` (monitor de la 09) y `stairs_concrete` (escaleras).

## Créditos en el juego

`fetch` y `credits` escriben también `assets/audio/credits.txt` (una línea por grabación: título, autor y
licencia), que la pantalla de créditos del título muestra en lugar de «atribuciones pendientes». Las
licencias CC BY obligan a citarlas. Al exportar el juego, añade `*.txt` a los filtros de archivos que no
son recursos del preset de exportación para que el archivo viaje con el juego.
