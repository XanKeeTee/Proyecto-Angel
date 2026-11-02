# Terror ambiental aleatorio y efectos de estado

Complementa a los eventos guionizados del prólogo ([prologo.md](../escenas/prologo.md#terror-ambiental-eventos)), que pasan una sola vez y se guardan. Aquí va lo **aleatorio**: lo que puede pasar o no, en cualquier partida, para que el hospital nunca se sienta del todo vacío.

Código: `scripts/systems/horror/` (director, planificador, entidad) y `scenes/ui/status_fx/` (efectos de pantalla). Datos: `data/horror/prologo.tres`.

## Reglas comunes

- **Nunca** con el control bloqueado: textos, eventos guionizados, menús, custodia, inspector, puertas y escaleras.
- Tras un evento guionizado (bandera `event:*`) hay **20 s de silencio**; tras cualquier otra bandera, 8 s.
- El reloj de los enfriamientos solo corre mientras el jugador tiene el control.
- Nada hace daño ni mata. Como mucho resta un poco de **Mente**.
- Lo único que se guarda: cuántas veces ha salido un susto limitado y qué objetos del decorado ya se han movido (`GameState.objects["horror"]`).

## La entidad

Una sombra humanoide **más negra que el negro**, muy alta (casi el doble que el protagonista) y deforme: cuello largo y torcido, la cabeza alargada caída hacia un lado, un hombro más alto que otro, el brazo izquierdo tan largo que casi roza el suelo, el derecho doblado hacia fuera, piernas finas que se deshacen en humo. Sin máscara ni nada que brille.

**Casi no se ve**, y así tiene que ser:

- En la oscuridad solo se **intuye**: el fondo de detrás tiembla un poco (como aire caliente) y se oscurece; los bordes sueltan un humo apenas más claro que el negro. Donde hay algo de luz detrás (una luz de emergencia, el suelo que alumbra la linterna), recorta una silueta negra.
- **Se nota más con el rabillo del ojo que de frente**: mirándola de reojo o a la espalda pinta su negro entero; si el jugador la mira de frente (dentro del cono de la linterna y hasta 55° más allá) se borra casi del todo y solo queda el temblor del fondo (`Stalker.set_gaze`, `HorrorDirector.gaze_at`).
- **Ojos**: a ratos (cada 2,5–7 s, durante 0,4–1,1 s) dos puntos pálidos y tenues, uno más bajo que el otro. Nunca de frente.
- **Aparición**: primero solo tiembla el aire (0,5 s); luego la sombra se condensa a saltos, por manchas, como una imagen que no acaba de sintonizar, y se asienta estirada hacia abajo (1,6 s en total). A veces da un tirón de lado y se salta un fotograma; el fotograma 5 de la hoja es un tirón de la cabeza.
- **Disolución con el haz**: se queda negra entera un instante, se estira hacia arriba como humo que se lleva una corriente, suelta humo negro y unas motas de estática apagadas, y la cinta salta (0,5 s).
- **Si se va sola** (te alcanza, se cansa): se hunde un poco y se apaga a saltos; el temblor del aire es lo último en irse.

Arte: `tools/art/entity.py` genera `assets/sprites/horror/entity.png`, que no es una imagen sino un mapa de datos (densidad, humo y ojos) que interpreta `shaders/entity_shade.gdshader` (lee la pantalla para deformar el fondo). La sombra que cruza (`PassingShadow`) usa lo mismo, sin ojos.

| Regla | Valor (en `prologo.tres`) |
|---|---|
| Aparece mientras el jugador **camina** (al menos 2 s seguidos) | — |
| Probabilidad por segundo caminando | 1,2 % con la Mente alta → 5 % con la Mente muy baja |
| Primera aparición posible | a los 75 s de juego |
| Enfriamiento tras irse | 90–170 s |
| Dónde aparece | **detrás**, a 120–170 px sobre el camino que acaba de recorrer el jugador, fuera del cono de la linterna (con 40° de margen) |
| Nunca | en una sala iluminada (cerca de un fluorescente encendido), en paredes, a la vista del haz |
| Cómo se mueve | sigue el **mismo camino** que el jugador (no atraviesa paredes); mantiene unos 70 px mientras andas, acelera si se queda atrás y se acerca despacio si te paras |
| Si el haz la toca | se estira y se deshace en humo (0,5 s), motas de estática, fallo de cinta, sonido; −1 Mente |
| Si te alcanza sin mirarla | susurro, fallo de cinta, −3 Mente; se desvanece |
| Si cruzas una puerta, se abre un texto o salta un evento | se desvanece |
| Si nada de eso pasa | se cansa a los 14–22 s |

La linterna la «toca» si está encendida, la figura está a menos de 250 px y dentro de ±22° del haz, y no hay pared entre medias (se comprueba por casillas del mapa).

## Sustos pequeños

`ScarePlanner` elige uno cada **55–110 s** de juego con la Mente alta y cada **28–60 s** con la Mente muy baja, por peso, sin repetir los tres últimos y respetando el enfriamiento propio de cada uno.

| Id | Qué pasa | Dónde | Enfriamiento | Notas |
|---|---|---|---|---|
| `portazo_lejano` | Portazo | Lejos | 150 s | |
| `algo_cae` | Algo metálico o de cristal cae | Sala cercana | 120 s | |
| `golpe_pared` | Golpes en una pared | Sala cercana | 140 s | Más con la Mente baja |
| `pasos_arriba` | Pasos en el piso de arriba | Arriba | 200 s | |
| `objeto_rueda` | Algo rueda por el suelo | Sala cercana | 160 s | |
| `puerta_entornada` | Una bisagra que chirría | Sala cercana | 150 s | Solo sonido: no cambia puertas |
| `goteo` | Goteo | Sala cercana | 90 s | |
| `respiracion` | Respiran a tu espalda | Detrás, muy cerca | 240 s | Solo con la Mente algo baja; −1 Mente |
| `parpadeo` | Las luces y la linterna fallan | Alrededor | 120 s | |
| `sombra_que_cruza` | Una sombra cruza al fondo, delante | 150–230 px delante | 240 s | Solo con la linterna encendida; 4 veces por partida; −1 Mente |
| `cara_en_la_cinta` | La máscara aparece dos fotogramas en un fallo de cinta | Pantalla | 300 s | Solo con la Mente baja; 3 veces por partida; −2 Mente |
| `silla_de_ruedas` | Una silla de ruedas se desplaza sola | La silla (fuera del haz) | 200 s | Cada silla una vez por partida; se guarda |

Para añadir uno: un `ScareDef` más en `data/horror/prologo.tres` (tipo, peso, enfriamiento, condiciones y sonido).

## Efectos de pantalla según el estado

Overlay entre el mundo y la interfaz (no tapa el HUD ni los textos). Se reduce con la opción de filtro VHS, sin desaparecer (es información de juego).

| Estado | Efecto |
|---|---|
| **Herido** (Cuerpo < 60) | Viñeta granate tramada que late con el corazón (lub-dub); más rápido y más cerrada cuanto peor (66 → 128 ppm). Algo de desaturación. Con el Cuerpo muy bajo, latido audible. |
| **Sangrando** | Regueros de sangre que bajan del borde superior y manchas en los laterales; a cada punto de Cuerpo perdido, el color se escapa un instante. |
| **Mente baja** | (además de la aberración y los ruidos que ya había) un eco muy leve de la imagen que se desliza en los bordes. |
| **Venda** | Onda cálida que sale del centro, la viñeta y los regueros se retiran (3 s) y un respiro. |
| **Analgésicos / sedante** | Suavizado breve de la imagen y una onda cálida más débil. |
| **Pilas y demás** | Nada en pantalla. |

## Depuración

| Argumento (tras `--`) | Qué hace |
|---|---|
| `--stalker` | La entidad aparece enseguida a la espalda y sigue al jugador aunque esté quieto (para capturas); con `--aim=` hacia ella se deshace. `--stalker=0` la fija «de reojo» y `--stalker=1` «de frente» (para comparar) |
| `--stalker-eyes` | Con `--stalker`: los ojos siempre encendidos (para capturas) |
| `--scare=id` | Lanza ese susto al segundo de empezar |
| `--body=N` / `--mind=N` / `--bleed` | Fija las constantes al empezar |
| `--use=id@S` | Usa ese objeto de la custodia a los S segundos (con `--give=venda`) |

Ejemplo: `-- --skip-intro --at=30,15 --face=left --give=linterna,pilas,venda --body=30 --bleed --use=venda@2`.
