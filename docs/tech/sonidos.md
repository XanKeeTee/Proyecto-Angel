# Sonidos pendientes (Freesound)

Todos los sonidos del juego saldrán de [Freesound](https://freesound.org). Los WAV van en `assets/audio/sfx/<nombre>.wav` y se piden por nombre con `Sfx.at(...)` o `Sfx.ui(...)`. Si un archivo no existe, el código usa un **sonido provisional** parecido de los que ya hay (columna «Provisional») o no suena nada. Cuando llegue el definitivo basta con copiarlo con su nombre: no hay que tocar código.

Cada sonido que se añada lleva su atribución (autor, título, enlace y licencia) en los créditos (`CREDITS` en `scenes/ui/title/title_screen.gd`).

## Terror ambiental (`scripts/systems/horror/`)

| Nombre | Qué buscar | Provisional |
|---|---|---|
| `entity_breath` | Respiración humana lenta y ronca, muy cerca y húmeda; una inspiración y una espiración, sin voz. 2–3 s, mono, sin reverberación | `whisper` |
| `entity_dissolve` | Ráfaga corta de estática de televisión con chisporroteo eléctrico que se corta en seco (o cinta que se rasga). 0,5–0,8 s | `phone_static` |
| `entity_whisper` | Susurro ininteligible pegado al oído, varias voces superpuestas sin palabras claras; entra y se corta. 1–1,5 s | `whisper` |
| `scare_door_slam` | Portazo de una puerta pesada, lejano, con la cola de un pasillo largo. 1,5–2,5 s | `door_close` |
| `scare_fall` | Bandeja o instrumental metálico que cae sobre baldosa en otra sala y rebota. 1–2 s | `metal_bang` |
| `scare_glass` | Frasco de cristal pequeño que cae y se rompe, a media distancia. ~1 s | `glass` |
| `scare_wall_knock` | Tres golpes sordos de puño contra una pared de yeso, oídos desde el otro lado (apagados). ~1,5 s | `knock` |
| `scare_steps_above` | Pasos lentos en el piso de arriba, sin agudos, con algún crujido del forjado. 4–6 s | `steps_far` |
| `scare_roll` | Objeto cilíndrico pequeño (bote, linterna) que rueda por linóleo y se para. 2–3 s | `heavy_drag` |
| `scare_wheelchair` | Silla de ruedas empujada un palmo sobre baldosa: ruedas, un chirrido. 1–2 s | `heavy_drag` |
| `scare_door_creak` | Bisagra de puerta que se abre sola, chirrido largo y lento. 2–3 s | `door_open` |
| `scare_breath` | Exhalación lenta justo detrás. ~1,5 s (mismo carácter que `entity_breath`, más corta) | `whisper` |
| `scare_static_burst` | Ráfaga de estática de vídeo VHS. ~0,5 s | `pa_static` |
| `scare_drip` | Dos a cuatro gotas cayendo en un charco, con eco de tubería. ~2 s | `drip` |

## Efectos de estado (`scenes/ui/status_fx/`)

| Nombre | Qué buscar | Provisional |
|---|---|---|
| `status_heartbeat` | Un latido (lub-dub) grave y amortiguado, como oído desde dentro. Un ciclo, ~0,6 s, sin clic al empezar | ninguno (no suena) |
| `status_relief_breath` | Respiración de alivio: exhalación larga y algo temblorosa. ~1,5 s | ninguno (no suena) |

## Título (`scenes/ui/title/`)

| Nombre | Qué buscar | Provisional |
|---|---|---|
| `ui_move` | Clic mecánico corto de botón de vídeo VHS o de mando a distancia. 50–100 ms | `flashlight_click` |
| `ui_accept` | Botón de vídeo más firme, con el «clonc» del mecanismo de la cinta. ~0,3 s | `flashlight_click` |
| `ui_back` | Clic de botón suave, más grave que `ui_move`. ~0,1 s | `flashlight_click` |
| `tape_rewind` | Vídeo VHS rebobinando (zumbido agudo del motor) con el chasquido de parada al final. 1,5–2 s | `pa_static` |
| `title_ambience` | Bucle de 30–60 s: zumbido de fluorescente y edificio vacío de noche (aire, tuberías lejanas), sin sucesos marcados, que haga bucle limpio | `ambience_loop` |
| `title_tube_flicker` | Chasquido y zumbido entrecortado de un tubo fluorescente que falla. 0,5–1 s | ninguno (no suena) |
