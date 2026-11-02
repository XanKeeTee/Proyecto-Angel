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
- **Paisaje sonoro** (`Soundscape`, `scripts/systems/audio/`): emisores posicionales por sala o zona según `data/audio/hospital_soundscape.tres` (`SoundscapeDef` con una lista de `AmbientSoundDef`). Se crea en `hospital.gd::_ready` con una línea. Cada sonido indica: bucle o suelto, zonas (en casillas) donde tiene que estar el jugador, si necesita corriente, dónde suena (casillas, junto a cada fluorescente que funciona, o alrededor del jugador), volumen y distancia, y enfriamiento de los sueltos. Todo va por el bus `Ambiente`, bajo.
- **Convivencia con el terror**: tras un susto del `HorrorDirector` los sueltos callan 16 s; mientras está la entidad, no hay sueltos y los bucles bajan 9 dB; nunca hay sueltos con el control bloqueado (textos, eventos, menús). Entre dos sueltos hay al menos 9 s.
- El zumbido del **generador** lo lleva ahora el paisaje sonoro (antes lo arrancaba `_power_on` y se perdía al cargar partida).

| Id | Tipo | Sonido | Cuándo | Qué es |
|---|---|---|---|---|
| `fluorescentes` | bucle | `hum_loop` | con corriente | Zumbido junto a cada fluorescente encendido; se corta cuando el tubo parpadea |
| `ventilacion` | bucle | `amb_vent_loop` | con corriente | Rejillas de ventilación de los dos pasillos |
| `goteo_banos` | bucle | `amb_drip_loop` | siempre | Grifo que gotea en los baños |
| `tuberias_sotano` | bucle | `amb_pipes_loop` | siempre | Agua que se mueve por las tuberías de la caldera (apagada) y de la lavandería |
| `nevera_morgue` | bucle | `amb_fridge_loop` | con corriente | Compresor de las cámaras frigoríficas |
| `generador` | bucle | `generator_loop` | con corriente | El generador de emergencia en marcha |
| `cuadro_electrico` | bucle | `amb_electric_buzz` | con corriente | Zumbido del cuadro eléctrico general |
| `crujidos_planta` | suelto | `amb_creak_building`, `amb_creak_wood` | siempre | El edificio cruje (madera y estructura) |
| `crujidos_sotano` | suelto | `amb_creak_metal` | siempre | Metal y hormigón que se asientan en el sótano |
| `golpes_tuberia` | suelto | `amb_pipe_knock` | siempre | Una tubería que golpea dentro de la pared |
| `agua_tuberias` | suelto | `amb_water_pipes` | siempre | Agua que corre por las tuberías de la pared |
| `viento_ventana` | suelto | `amb_wind_gust` | siempre | Ráfaga por una ventana rota (Habitación 07 y ventana del pasillo) |
| `monitor_lejano` | suelto | `amb_monitor_far` | siempre | Un monitor de constantes pita en alguna habitación lejana |
| `cables_ascensor` | suelto | `amb_elevator_cables` | siempre | Los cables del ascensor crujen en el hueco |
| `papeles_corriente` | suelto | `amb_paper_draft` | siempre | Papeles que se mueven con una corriente de aire |
| `gotas_sotano` | suelto | `drip` | siempre | Gotas sueltas que caen en charcos del sótano |
| `chispas_cuadro` | suelto | `amb_spark_crackle` | con corriente | Chisporroteo del cuadro eléctrico |

Para añadir uno: una entrada nueva en el `.tres` (o en el inspector) y su búsqueda en `build_manifest.py`; `check` avisa si falta.

## Grupos del manifiesto

`build_manifest.py` ordena las entradas por grupos: mundo (luz, máquinas, puertas, muebles), jugador (pisadas, levantarse, escaleras), paisaje sonoro (`amb_*`), terror (`entity_*`, `scare_*`), estado e interfaz (`status_*`, `ui_*`, título), música (`music_menu_*`), usar/fabricar objetos (`use_*`, `craft_*`, `cloth_tear`) y custodia (`inv_<material>_<acción>` para los 12 materiales y 6 acciones, más `inv_<acción>` genéricos). Lo que hay que buscar para cada uno está en su `note`, `query` y `alt`.

Reservados (en el manifiesto, aún sin uso en el código): `breaker` (palanca del cuadro), `unlock` (llave), `monitor_beep` (monitor de la 09) y `stairs_concrete` (escaleras).

## Créditos en el juego

`fetch` y `credits` escriben también `assets/audio/credits.txt` (una línea por grabación: título, autor y
licencia), que la pantalla de créditos del título muestra en lugar de «atribuciones pendientes». Las
licencias CC BY obligan a citarlas. Al exportar el juego, añade `*.txt` a los filtros de archivos que no
son recursos del preset de exportación para que el archivo viaje con el juego.
