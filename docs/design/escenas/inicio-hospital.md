# Escena: inicio en el hospital

> Estado: `[PROPUESTA]`. Hay un prototipo jugable (`res://scenes/world/hospital/hospital_intro.tscn`, escena principal). Los textos son **provisionales**: el equipo los reescribe.

## Idea (aprobada por el equipo)

El juego empieza con el protagonista levantándose de una camilla de hospital, desorientado y a oscuras. No hay nadie en el hospital. Va solo, con la bata de recién operado.

## Decisiones tomadas

| Tema | Decisión |
|---|---|
| Tamaño de tile | **32 px** (unos 20×11 tiles en pantalla a 640×360) |
| Alcance de esta parte | **Habitación + pasillo**, sin combate. Termina con algo inquietante |
| Visión en la oscuridad | **Linterna que se encuentra**: se empieza casi a ciegas y se encuentra en la habitación |

## Objetivo de la escena

- Fijar el tono: soledad, frío clínico, cuerpo vulnerable.
- Enseñar los controles sin tutorial: moverse, examinar y seguir la luz.
- Plantear preguntas sin responderlas: quién operó al protagonista, dónde está todo el mundo, de quién son las huellas.

## Secuencia

### 1. Despertar (sin control)

1. Pantalla negra. Rótulo: **DESPIERTA.**
2. Los ojos se abren a medias y se cierran dos veces (fundidos a negro).
3. Se ve la habitación casi a oscuras. La única luz es el verde del monitor sobre la camilla.
4. Texto interior (en segunda persona, ver *Voz*).
5. El protagonista se incorpora, hay una distorsión breve de cinta y se baja de la camilla. Desde aquí, el jugador tiene el control.
6. Pista de controles abajo durante unos segundos.

### 2. La habitación (casi a ciegas)

- Solo se ve un radio de unas 2 casillas alrededor del personaje y lo que ilumina el monitor.
- Hay objetos que se pueden examinar: la camilla (con las correas desabrochadas), el monitor, el gotero, el lavabo bajo un espejo roto, una cortina separadora, otra camilla con las correas rotas, la bandeja de instrumental y una papelera llena de gasas.
- **La puerta no se abre sin luz**: "No puedes salir a ciegas." Así el jugador tiene que explorar la habitación.
- **La taquilla**: en el cajón de abajo está la **linterna**. Al cogerla se enciende con un parpadeo.
- Con la linterna, la puerta se abre. Al cruzarla hay un fundido corto y apareces en el pasillo (y al revés).

### 3. El pasillo (con linterna)

- La linterna ilumina un cono hacia donde mira el personaje; las paredes proyectan sombra.
- Al fondo, una **luz de emergencia roja** parpadea. Es el acento de color de la escena.
- Hay tres puertas cerradas con texto distinto, un cartel arañado, una ventana a una sala a oscuras, una mano de sangre arrastrada pared abajo, una rejilla de ventilación, sillas de espera (una tirada), una silla de ruedas volcada, una camilla vacía **con las correas abrochadas** y un rastro de arrastre en el suelo.
- A mitad de pasillo aparecen **huellas de pies descalzos, húmedas**, que llevan hasta la puerta doble del fondo.

### 4. Final del prototipo

- Al examinar la puerta doble: las huellas terminan ahí y **son del tamaño de sus pies**.
- La linterna falla, la luz de emergencia se apaga, la imagen se distorsiona y se funde a negro.
- Rótulo: **CONTINUARÁ.** Intro vuelve a empezar.

## Guion provisional

Todo se edita en el inspector de Godot: cada objeto es un nodo `Interactable` con `lines` (primera vez) y `lines_repeat` (las siguientes). Los textos de la intro y de las huellas están en el nodo raíz (`intro_lines`, `footprints_lines`).

| Momento / objeto | Primera vez | Después |
|---|---|---|
| Intro | "Frío." / "Huele a desinfectante. Debajo, a algo dulce." / "Al moverte, algo tira en la espalda. Puntos. Recientes." | — |
| Camilla | "La sábana conserva la forma de tu cuerpo." / "Las correas están desabrochadas. Alguien las soltó." | "Hay una mancha donde tenías la espalda." |
| Monitor | "El monitor sigue encendido." / "Los cables cuelgan sueltos, pero la línea verde sigue latiendo." | "La línea verde sigue latiendo." |
| Gotero | "La bolsa del gotero está vacía." / "El tubo está arrancado. La aguja todavía tiene sangre." | "La aguja todavía tiene sangre." |
| Taquilla | "Una taquilla oxidada. Las puertas están cerradas con llave." / "El cajón de abajo cede." / "Dentro hay una linterna." → "Has cogido la LINTERNA." | "El cajón está vacío." |
| Lavabo | "El espejo está roto desde dentro hacia fuera." / "El grifo no da agua." | igual |
| Cortina | "Una cortina separadora. El bajo está empapado de algo oscuro." | igual |
| Otra camilla | "Otra camilla. Las correas están rotas, no desabrochadas." | igual |
| Bandeja | "Instrumental quirúrgico, limpio y en orden." / "Falta una pieza en el centro. Queda su silueta en sangre." | igual |
| Papelera | "Gasas usadas. Muchas." (la del pasillo: "Más gasas.") | igual |
| Puerta (sin luz) | "Al otro lado de la puerta no se ve nada. Ni siquiera el suelo." / "No puedes salir a ciegas." | igual |
| Cartel | "Un cartel con el horario de visitas." / "Alguien lo ha arañado hasta romper el papel." | igual |
| Ventana | "Una ventana a una sala a oscuras. Las persianas están arrancadas." | igual |
| Mano de sangre | "Una mano. Arrastrada hacia abajo." | igual |
| Puertas cerradas | "Cerrada." · "Cerrada. No se oye nada al otro lado." · "Cerrada. El pomo está helado." | igual |
| Sillas | "Sillas de espera. Nadie espera." · "Una silla tirada." | igual |
| Silla de ruedas | "Una silla de ruedas volcada." | igual |
| Camilla del pasillo | "Una camilla vacía con las correas abrochadas." / "Abrochadas sobre nadie." | igual |
| Huellas | "Huellas de pies descalzos en el suelo." / "Todavía están húmedas." | — |
| Puerta doble | "Las huellas terminan delante de esta puerta." / "Son del tamaño de tus pies." | — |

### Voz

`[PROPUESTA]` Narración en **segunda persona** ("Al moverte…", "tus pies"). Así el protagonista no tiene voz propia mientras no se decida cómo se personaliza (GDD §4).

### Pistas de lore que deja la escena

Ninguna es canon. Son ganchos que el equipo puede aprovechar o quitar:

- **Cicatriz en la espalda con puntos recientes**: se ve en el sprite cuando camina hacia arriba, porque la bata está abierta por detrás. ¿Qué le han hecho?
- **"Falta una pieza en el centro"** de la bandeja de instrumental.
- **El monitor sigue latiendo** con los cables sueltos.
- **Huellas húmedas del tamaño de sus pies** que van por delante de él.
- **Cicatriz cosida en el cráneo** rapado.
- **Pieza metálica entre los omóplatos**, al final de la incisión.
- **Correas**: las suyas, desabrochadas ("alguien las soltó"); las de la otra camilla, rotas; las del pasillo, abrochadas sobre nadie.
- **Espejo roto desde dentro.**

> Antes de aprobar, pasar estos ganchos por `lore-keeper`: no deben chocar con la idea central ni acercarse a la premisa prohibida.

## Mecánicas que introduce

| Mecánica | Detalle | Dónde vive |
|---|---|---|
| Movimiento por casillas | 4 direcciones, un paso = 1 tile de 32 px en 0,27 s (lento a propósito). Sin correr | `player.gd` (`STEP_TIME`) |
| Examinar | Intro sobre la casilla de enfrente | `interactable.gd` |
| Oscuridad | Ambiente casi negro (`CanvasModulate`); solo se ve lo iluminado | Nodo `Darkness` |
| Luz propia | Radio de unas 2 casillas, tenue | `Player/Aura` |
| Linterna | Cono de unos 7 tiles hacia donde se mira, con sombras de las paredes | `Player/Flashlight` |
| Texto | Caja inferior con efecto de máquina de escribir; rótulos centrados en mayúsculas | `scenes/ui/message_box.gd` |
| VHS | Grano, aberración, scanlines, viñeta, virado frío y distorsión en eventos | `scenes/ui/vhs_overlay.gd` |

## Arte

Arte **provisional** generado con `python -I tools/art/build_all.py` (ver "Personajes: realismo sucio" en la guía estética). Ambiente verde de hospital muy oscuro, la bata como foco y el rojo de emergencia como único acento.

- Tileset: `assets/tilesets/hospital.png` + normales. Contiene ocho suelos y ocho linóleos, paredes de 3 casillas en cuatro variantes, puertas (cerrada, abierta, doble) y extras de pared: mano de sangre, cartel, espejo roto, arañazos, rejilla, ventana y chorreón.
- Protagonista: `assets/sprites/characters/protagonist.png` (48×68 px por fotograma).
- Camilla: 5 estados (correas abrochadas, tumbado, sentado, revuelta, destrozada).
- Objetos: gotero, monitor (pantalla emisiva), taquilla (cajón cerrado/abierto), bandeja, silla de ruedas, papelera, lavabo, cortina, sillas, luz de emergencia.
- Calcomanías de suelo: huellas, papeles, cristales, gotas y arrastre.

### Distribución

Pasillo arriba (filas 4–6) y habitación abajo (filas 11–16). Las paredes miden 3 casillas. Puntos clave:
- empiezas en `(3,13)`;
- la linterna está en `(9,11)`;
- la puerta de la habitación está en `(5,10)` y lleva al pasillo en `(5,6)`;
- el final está en la puerta doble, `(31,3)`.

## Falta

- **Sonido**: es lo que más pesa en esta escena. Zumbido del monitor, pitido, pasos descalzos, clic de la linterna y un golpe sordo al final.
- Fuente pixel con serifa (ahora usa una del sistema).
- Arte definitivo y retrato del protagonista.
- Guardado: la escena no guarda nada todavía.
- Enlace con lo que hay detrás de la puerta doble.

## Preguntas abiertas

1. ¿Narración en segunda persona, o el protagonista habla?
2. ¿Qué hay detrás de la puerta doble? ¿Primer combate, primer personaje o más exploración?
3. ¿Se puede **apagar** la linterna (para esconderse) o siempre está encendida? ¿Tiene batería?
4. ¿Las huellas son una pista de lore (un doble, un bucle, otro paciente) o solo ambiente?
5. ¿Rótulo **DESPIERTA.** al principio, o empezamos sin texto?
