# Prólogo — El hospital

> Estado: jugable de principio a fin. La estructura y los sistemas siguen el encargo del equipo. Los textos, los documentos y los detalles de lore son `[PROPUESTA]` (ver [docs/lore/prologo.md](../../lore/prologo.md)).
>
> Escena: `res://scenes/world/hospital/hospital.tscn`. Se entra desde el título (Nueva partida).

## Qué es

Una experiencia continua, sin actos ni capítulos visibles. El protagonista despierta en la **Habitación 09** de un hospital vacío y a oscuras. Explora, encuentra recursos, lee documentos y resuelve pequeños obstáculos hasta **restaurar la corriente desde el sótano**. Entonces la megafonía anuncia:

> «El paciente de la habitación nueve ha recuperado la consciencia. Inicien el protocolo de recuperación».

Al intentar salir, el hospital le ofrece un **pasillo que no aparece en los planos**. Al recorrerlo termina el prólogo.

## Mapa

Una sola escena. El sótano está en la misma escena y se llega por la escalera de servicio, con un fundido breve y sin pantalla de carga (el protagonista sigue andando hacia la escalera mientras funde y se oyen sus pasos).

Las **puertas se cruzan andando**, sin fundido: abiertas dejan un hueco en el muro por el que se pasa por debajo del dintel; cerradas bloquean el paso y la luz. La linterna no atraviesa paredes ni puertas cerradas, pero sí ilumina la cara del muro que tiene delante y lo que hay al otro lado de una puerta abierta.

**Planta 3**
- **Pasillo del ala de pacientes**, de oeste a este.
- **Al norte del pasillo**:
  - Habitación 07;
  - Habitación 08;
  - Habitación 10 (cerrada con llave);
  - Habitación 11;
  - Enfermería;
  - Archivo médico (cerrado con llave);
  - Escalera de servicio (cerrada con llave);
  - Vestíbulo, con la salida principal y el ascensor.
- **Al sur del pasillo**:
  - **Habitación 09** (inicio);
  - Habitación 12;
  - Almacén de limpieza;
  - Baños;
  - Control de enfermería (grabadora);
  - Quirófano (puerta atascada);
  - Recepción y admisiones.

**Sótano**
- Pasillo de mantenimiento.
- Escalera (llegada).
- Sala eléctrica (grabadora).
- Lavandería.
- Morgue.
- Sala de calderas (generador).
- Taller.

La distribución está en `tools/levels/hospital_layout.json`. La escena se genera con `tools/levels/build_hospital.gd` (ver docs/tech).

## Progresión (camino principal)

| # | Dónde | Qué se consigue | Qué abre |
|---|---|---|---|
| 1 | Hab. 09 · mesita | **Linterna** (35 % de batería) y **2 pilas** | Ver |
| 2 | Almacén · armario | **Palanca** (ocupa 1×3) | La puerta atascada del quirófano (la palanca se queda encajada) |
| 3 | Quirófano · bandeja | **Destornillador** (4 usos) | — |
| 4 | Hab. 11 · cama (tras oír el chirrido) | **Llave pequeña** | Armario de medicación de la enfermería |
| 5 | Enfermería · armario | **Llave del archivo** | Archivo |
| 6 | Archivo | **Fusible** (estantería), **llave del sótano** (escritorio), **expediente 09** | Escalera de servicio |
| 7 | Sótano · taller | **Válvula averiada** (2×2) | — |
| 8 | Custodia | Destornillador + válvula averiada = **válvula reparada** | — |
| 9 | Sala eléctrica · cuadro | Abrir, apretar las bornas (destornillador), colocar el fusible | — |
| 10 | Calderas · generador | Instalar la válvula y arrancar | **Vuelve la luz** y suena la megafonía |
| 11 | Pasillo, extremo oeste | El muro se ha abierto | **Pasillo imposible**, que lleva al final |

Las puertas con llave guardan la llave puesta, que deja de ocupar sitio. Las combinaciones no se explican en un tutorial: se descubren probando, leyendo (nota del cuadro, manual del generador) o pensando (T).

## Pistas `[PROPUESTA]`

Cada paso del camino principal tiene pistas dentro del mundo, para que nadie se quede atascado sin saber por qué:

| # | Qué falta | Pista |
|---|---|---|
| 1 | Linterna | La mesita de la 09 destella. Pensamiento: «En la mesita, junto a la cama, quizá haya algo». |
| 2 | Palanca | Al intentar abrir el quirófano: «Con algo largo y fuerte metido en la ranura, quizá cediera». Desde entonces el armario del almacén destella y, al examinarlo, «se ve algo largo de hierro apoyado en el fondo». Con la palanca encima, la puerta del quirófano destella. |
| 3 | Destornillador | La bandeja del quirófano destella. Si llegas al cuadro sin él: «En un quirófano siempre queda instrumental tirado». |
| 4 | Llave pequeña | El crujido de la 11; desde entonces su cama destella. |
| 5 | Llave del archivo | El armario de la enfermería deja ver la llave colgada; con la llave pequeña, destella. La puerta del archivo tiene una pegatina: «Llave: enfermería». |
| 6 | Fusible y llave del sótano | Estantería, escritorio y archivador de la VIGILIA destellan. La placa de la escalera dice «SÓTANO · Solo mantenimiento»; la caja del archivo pone «MANTENIMIENTO». |
| 7 | Válvula | El generador, al examinarlo: «le falta una pieza». La estantería del taller tiene la etiqueta «GRUPO ELECTRÓGENO · RECAMBIOS» y destella. |
| 8 | Reparar la válvula | Al probarla en el generador: «el asiento está suelto». Pensamiento: «En la Custodia se pueden probar cosas juntas». |
| 9-10 | Cuadro y generador | El cuadro destella hasta abrirlo y después cada vez que llevas lo que le falta (destornillador, fusible); el generador destella hasta arrancar. |

**Destellos**: una chispa pequeña, de medio segundo cada pocos segundos y solo de cerca, sobre los objetos clave mientras les queda algo, y sobre cualquier cosa (puerta, cuadro, generador) cuando llevas lo que le falta. **Contorno**: el objeto enfocado tiene un contorno tenue.

**Pensamientos (T)**: un resumen de lo que el protagonista sabe que tiene que hacer, según las banderas y lo que lleva. Cuando cambia, aparece «Algo nuevo en lo que pensar · T». Si sangra, primero recuerda que tiene que vendarse. Datos: `data/thoughts/prologo.tres` (de `tools/data/build_prologue_data.gd`).

## Botín

El contenido «suelto» de los muebles se reparte **al azar al empezar partida nueva**, con una semilla que se guarda con la partida (al cargar sale lo mismo). Lo del camino principal no cambia: linterna y 2 pilas de la mesita de la 09, palanca, destornillador, llaves, fusible, válvula, documentos, la venda usada de la papelera de la 09, la venda esterilizada del armario de la enfermería y el tubo de hierro de la habitación 12.

Datos: `data/loot/prologo.tres` (de `tools/data/build_prologue_data.gd`).

- **Repartos garantizados**: el total del mapa está fijo y solo cambia dónde aparece cada cosa (cada ejemplar en un mueble distinto, elegido entre unos candidatos plausibles):
  - pilas: 3 en la planta 3 y 2 en el sótano;
  - vendas: 1 arriba y 1 abajo (los puntos se abren al bajar), y 1 esterilizada (quirófano o enfermería);
  - analgésicos ×2, una jeringa y una ampolla (un sedante), un desinfectante.
- **Tablas por tipo de mueble** (cajón, taquilla, papelera, material de cura, medicación, trastero del sótano, debajo de una cama): casi siempre vacías (del 50 % al 88 %), con una tirada de algo menor. Pueden añadir alguna pila, venda o analgésico más.
- **Ropa** (rara y repartida): cada prenda sale como mucho una vez y no siempre (del 45 % al 70 %); ninguna en la habitación 09 y la mitad, en el sótano. Unas 4 de 8 por partida (antes salían las 9 y la primera, bajo tu propia cama).

**Balance de luz**: la batería gasta un 100 % en 9 minutos y cada pila da un 45 % (unos 4 minutos). Empiezas con un 35 % y 2 pilas (unos 11 minutos). Con los repartos garantizados hay luz para unos 31 minutos, y con lo que pueda salir de las tablas, unos 35-40. El camino principal, sabiendo qué hacer, dura unos 15; explorándolo todo con la linterna encendida casi siempre, la luz llega justa. Antes había 17 pilas (unos 72 minutos de luz).

| Antes | Ahora (por partida) |
|---|---|
| 15 pilas sueltas, siempre en el mismo sitio | 5 garantizadas + ~1 de las tablas, en sitios distintos |
| 5 vendas limpias + 2 esterilizadas | 2 + ~1 de las tablas, y 1 esterilizada (más la fija del armario) |
| 9 prendas, la primera bajo tu cama | ~4 prendas, ninguna en la 09 |

La medicación sigue igual de escasa: analgésicos (2 garantizados + tablas); jeringas y ampollas, que combinadas dan **sedante**. El **desinfectante** limpia vendas usadas y esteriliza vendas.

- `[PROPUESTA]` **Tela**: rasgando ropa que no se lleva puesta (las batas dan 3 tiras). Con ella se fabrican vendas improvisadas (sucias hasta desinfectarlas), torniquetes y el mango envuelto del tubo. Ver [custodia](../sistemas/custodia.md).
- `[PROPUESTA]` **Armas improvisadas** (se empuñan desde PERSONAJE › MANO): la palanca ya sirve; un **bisturí** en el quirófano (al azar) y el **tubo de hierro**, que ya no se reparte: está siempre en el suelo de la **habitación 12**, junto a la 09, arrancado de la toma de la pared (`tubo_hab12`). Al cogerlo se empuña solo si la mano está vacía, y desencadena el combate (ver «Combate»).

## Ropa

Desde la pestaña **PERSONAJE** de la Custodia se ve al protagonista con lo que lleva y se cambia la ropa como en un RPG: cuatro ranuras (cabeza, cuerpo, piernas, pies). La ropa puesta no ocupa sitio en la bandeja; lo que se quita vuelve a ella (si no cabe, no se cambia). Desde la bandeja también se puede usar «Ponerse» (E).

Empieza con la bata de paciente, descalzo. Prendas del prólogo `[PROPUESTA]`:

| Prenda | Ranura | Dónde puede salir (probabilidad) | Efecto |
|---|---|---|---|
| Bata de paciente | Cuerpo | Puesta al empezar | Se balancea mucho |
| Zapatillas | Pies | Debajo de una cama de la 07, 10 o 12, una taquilla o la camilla del pasillo (70 %) | Pasos casi mudos |
| Gorro de lana | Cabeza | Taquillas de las habitaciones, mesita de la 11 (45 %) | — |
| Pantalón de pijama | Piernas | Hab. 12, carros de la lavandería (45 %) | — |
| Gorro quirúrgico | Cabeza | Encimeras del quirófano y la enfermería, control (55 %) | Tapa la cicatriz |
| Bata de médico | Cuerpo | Control, recepción, enfermería (50 %) | Se balancea mucho |
| Chaqueta de celador | Cuerpo | Lavandería, taller (55 %) | — |
| Pantalón de celador | Piernas | Lavandería (45 %) | — |
| Botas de goma | Pies | Taller, sala eléctrica, lavandería (55 %) | Pasos fuertes |

Por ahora el efecto es visual y de sonido; no cambian estadísticas.

## Supervivencia en el prólogo

- **Linterna**: batería limitada. Con poca carga amarillea, se debilita y parpadea. Indicador en el HUD. Se enciende con F o con su bolsillo.
- **Sangrado**: al bajar al sótano «se abren los puntos». El Cuerpo baja poco a poco hasta que se venda. Una venda contaminada corta la hemorragia, pero resta Cuerpo y Mente.
- **Cuerpo bajo**: caminas más despacio y la imagen se enrojece.
- **Mente**: baja con los sucesos. Con la Mente baja se oyen susurros, pasos y golpes que no existen, y hay más distorsión de cinta. Se recupera con sedante.
- **Muerte**: el sangrado sigue sin bajar el Cuerpo de 20 (así el prólogo no castiga explorar). `[PROPUESTA]` **Cambio**: hasta ahora el prólogo no mataba; con el combate del enfermero se puede morir. Si el protagonista muere en combate, **pantalla de muerte** («FIN DE LA CINTA»: la imagen se corta entre nieve) y se elige **volver a la última cinta grabada** (si hay alguna) o **volver al título**. Pendiente de aprobar por el equipo; la alternativa sería un combate con `derrota_continua` (despertar de nuevo en la 09).
- **Efectos en pantalla**: herida (viñeta granate que late), sangrado (regueros en los bordes), cura con venda (onda cálida) y analgésicos o sedante (suavizado). Detalle en [terror-ambiental.md](../sistemas/terror-ambiental.md#efectos-de-pantalla-según-el-estado).

## Combate: el enfermero `[PROPUESTA]`

El único combate del prólogo, temprano y opcional en la práctica (casi todo el mundo coge el tubo, que destella):

1. En la **habitación 12** hay un tubo de hierro en el suelo. Al cogerlo se empuña (si no llevabas nada en la mano).
2. Al salir al **pasillo**, un fluorescente se enciende solo al fondo, falla, y bajo él hay alguien muy alto con uniforme de enfermero y una máscara pálida. Se le oye arrastrar un pie mientras se acerca. La cinta salta y empieza el combate.
3. **Combate por turnos con mutilaciones** (ver [combate.md](../sistemas/combate.md) y [el enfermero](../enemigos/enfermero.md)): el enemigo arriba, el protagonista abajo. El Cuerpo, la Mente, el sangrado y las heridas pasan del mapa al combate y vuelven.
4. **Victoria**: su cuerpo se queda en el pasillo, sin lo que perdió, y se recuerda al guardar. Al examinarlo se ve la pieza de metal entre sus omóplatos, como la del protagonista.
5. **Huida** (≈ 50 %, más si le has roto las piernas; imposible si te tiene agarrado): vuelve a buscarte más tarde (pasado algo más de un minuto, al volver al pasillo o en el del sótano), con las heridas que le hiciste.
6. **Derrota**: pantalla de muerte (ver «Supervivencia»).

El resto del prólogo no depende del combate: se puede terminar ganándolo, huyendo o sin coger el tubo.

## Terror ambiental (eventos)

Todos son datos (`HorrorEvent`) en la escena. Se guardan como ocurridos y no se repiten.

| Evento | Cuándo | Qué pasa |
|---|---|---|
| Teléfono | Al pasar junto al control con la linterna | Suena. Si descuelgas: estática y alguien que respira a tu ritmo |
| Chirrido de cama | Al pasar frente a la 11 | Cruje una cama en una habitación vacía. Al entrar, no hay nadie; la cama aún se balancea |
| Pasos en el pasillo | Al entrar en la 07 | Pasos lejanos fuera |
| Golpes | Al entrar en la 12 | Llaman desde la 10, cerrada. Al abrirla, no hay nadie |
| Cama de la 08 | Al volver a la 08 tras coger la llave pequeña | La cama aparece desplazada, con las correas abrochadas |
| Cadáver del quirófano | Al volver tras haberlo visto | Ya no está: solo la sábana |
| Puerta que se cierra | Al salir del archivo con el fusible | La puerta de la 07 se cierra sola y el pasillo parpadea |
| Susurro | En el archivo | Junto al archivador de la VIGILIA |
| Puntos abiertos | Al llegar al sótano | Empieza el sangrado |
| Pasos arriba | En el pasillo del sótano | Pasos en la escalera por la que acabas de bajar |
| Morgue | Al volver | El cajón 09 aparece vacío |
| Tu habitación | Al volver a la 09 tras leer tu expediente | Alguien ha hecho tu cama y ha abrochado las correas |
| Ascensor | En el vestíbulo | Un golpe metálico dentro del hueco |
| Parpadeos | Tramo central del pasillo (a veces) | Las luces y la linterna fallan un momento |

Además de estos, hay **terror aleatorio** que puede pasar o no en cada partida: una entidad de humo que a veces te sigue por la espalda y se deshace si la alumbras, y sustos pequeños (portazos lejanos, algo que cae, pasos arriba, una sombra que cruza, una silla de ruedas que se mueve…). Reglas y valores en [terror-ambiental.md](../sistemas/terror-ambiental.md). `[PROPUESTA]` La entidad no tiene nombre ni explicación en el canon: solo se ve.

Además hay detalles fijos:
- una ventana con alguien mirando desde el ala de enfrente;
- un monitor que refleja a alguien en una cama vacía;
- manos de sangre en las paredes;
- un espejo roto desde dentro;
- huellas húmedas que van hacia el muro oeste.

## Final

Tras la megafonía, el extremo oeste del pasillo (junto a la 07, donde según el plano está la fachada) se ha abierto. Las huellas húmedas llevan hasta él y la luz de emergencia de ese lado se enciende.

El pasillo nuevo repite puertas con el número 09. Al fondo hay una puerta abierta y una luz verde que late. Dentro hay alguien en la cama con tu cara. Fundido y rótulo: **LA NOVENA VIGILIA**.

## Duración

El camino principal, sabiendo qué hacer, dura unos 15 minutos. Explorando, leyendo los 21 documentos, registrando los ~110 objetos y gestionando la batería, el objetivo es de **30–45 minutos** (la luz garantizada da para unos 31; ver «Botín»).

**Sin medir**: nadie lo ha jugado entero todavía.

## Pantalla de título

El título es una cinta de vídeo que se está reproduciendo: la Habitación 09 vista desde arriba, con el mismo arte del mapa (es la escena real del hospital, sin guion ni jugador, en un SubViewport con la cámara fija): la camilla deshecha, el monitor que late, un fluorescente que falla, polvo en la luz y lluvia de estática. En algunos apagones la máscara de la entidad asoma en un rincón. El menú queda a la izquierda, sobre el negro de fuera del mapa. Arriba, los rótulos del vídeo (PLAY ▶, contador de cinta); abajo, la fecha y la hora del sistema.

Menú: **Continuar** (la grabación más reciente), **Nueva partida**, **Cargar** (si hay alguna grabación), **Opciones**, **Créditos** y **Salir**. Teclado, ratón o mando. Al entrar en la partida la cinta se rebobina entre nieve y empieza a reproducirse. Los créditos tendrán la atribución de los sonidos de Freesound.

## Opciones

Desde el título y la pausa:
- volumen general, de ambiente, de efectos y de interfaz;
- **brillo**, con una muestra de calibración;
- intensidad del filtro VHS;
- pantalla completa;
- velocidad del texto.

Se guardan en `user://settings.cfg`, aparte de la partida.

## Controles

| Acción | Teclado | Mando |
|---|---|---|
| Moverse | WASD / flechas | Stick izquierdo / cruceta |
| Correr (un poco, solo hacia delante, con aliento limitado) | Shift | Stick izquierdo pulsado (L3) / L2 |
| Apuntar (mirar y alumbrar) | Ratón | Stick derecho |
| Acción (abrir, coger, leer…; si hay varias, se elige) | E / Intro / Espacio | A |
| Examinar | R | X |
| Pensar (qué tengo que hacer) | T | LB |
| Linterna | F | Y |
| Sistema de Custodia | Tab / I | Select |
| Bolsillos | 1–5 | — |
| Pausa | Esc | Start |

**Correr.** El protagonista está recién operado: correr es poco más que apretar el paso
(×1,5 la velocidad de andar; ×1,2 con el Cuerpo al mínimo). Solo corre hacia donde mira o en
diagonal hacia delante; de espaldas o de lado, Shift no hace nada. Aguanta unos 4 s; el
aliento se recupera tras ~0,7 s sin correr, más deprisa parado que andando, y si se agota
del todo no puede volver a correr hasta recuperar un tercio (respira agitado). Con el Cuerpo
bajo se gasta hasta el doble de rápido y se recupera a la mitad; sangrando, ×1,5 y ×0,7. El
HUD muestra una raya fina abajo en el centro solo mientras el aliento no está lleno.

## Pendiente

- Voz de la megafonía: ahora es texto con sonido de megafonía y estática. Grabar la voz.
- Música y diseño de sonido definitivos (los sonidos actuales son sintetizados).
- Arte definitivo de interfaz y fuentes propias.
- Medir la duración real con jugadores.
