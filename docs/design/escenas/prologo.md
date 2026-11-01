# Prólogo — El hospital

> Estado: jugable de principio a fin. La estructura y los sistemas siguen el encargo del equipo. Los textos, los documentos y los detalles de lore son `[PROPUESTA]` (ver [docs/lore/prologo.md](../../lore/prologo.md)).
>
> Escena: `res://scenes/world/hospital/hospital.tscn`. Se entra desde el título (Nueva partida).

## Qué es

Una experiencia continua, sin actos ni capítulos visibles. El protagonista despierta en la **Habitación 09** de un hospital vacío y a oscuras. Explora, encuentra recursos, lee documentos y resuelve pequeños obstáculos hasta **restaurar la corriente desde el sótano**. Entonces la megafonía anuncia:

> «El paciente de la habitación nueve ha recuperado la consciencia. Inicien el protocolo de recuperación».

Al intentar salir, el hospital le ofrece un **pasillo que no aparece en los planos**. Al recorrerlo termina el prólogo.

## Mapa

Una sola escena. El sótano está en la misma escena y se llega por la escalera de servicio, con un fundido breve y sin pantalla de carga.

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

Las puertas con llave guardan la llave puesta, que deja de ocupar sitio. Las combinaciones no se explican: se descubren probando o leyendo (nota del cuadro, manual del generador).

## Recursos opcionales

- **Pilas**:
  - Hab. 07 (2);
  - Hab. 10 (1);
  - baños (1);
  - recepción (2);
  - sala eléctrica (1);
  - lavandería (2);
  - morgue (1);
  - taller (1).
- **Vendas**: una venda usada en la papelera de la 09 (contaminada); vendas limpias en la Hab. 12, la enfermería y la lavandería; venda esterilizada en la enfermería y el quirófano.
- **Medicación**: analgésicos (Hab. 08, baños, control); jeringas y ampollas (Hab. 10, enfermería), que combinadas dan **sedante**.
- **Desinfectante** (almacén, enfermería). Limpia vendas usadas y esteriliza vendas.

La batería gasta un 100 % en unos 9 minutos encendida, y hay pilas para unos 40 minutos más si se buscan.

## Supervivencia en el prólogo

- **Linterna**: batería limitada. Con poca carga amarillea, se debilita y parpadea. Indicador en el HUD. Se enciende con F o con su bolsillo.
- **Sangrado**: al bajar al sótano «se abren los puntos». El Cuerpo baja poco a poco hasta que se venda. Una venda contaminada corta la hemorragia, pero resta Cuerpo y Mente.
- **Cuerpo bajo**: caminas más despacio y la imagen se enrojece.
- **Mente**: baja con los sucesos. Con la Mente baja se oyen susurros, pasos y golpes que no existen, y hay más distorsión de cinta. Se recupera con sedante.
- **Sin muerte en el prólogo**: el sangrado no baja el Cuerpo de 20. Es una decisión de diseño para que el prólogo sea de exploración.

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

El camino principal, sabiendo qué hacer, dura unos 15 minutos. Explorando, leyendo los 21 documentos, registrando los ~110 objetos y gestionando la batería, el objetivo es de **30–45 minutos**.

**Sin medir**: nadie lo ha jugado entero todavía.

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
| Acción principal (abrir, coger, leer…) | E / Intro / Espacio | A |
| Examinar | R | X |
| Linterna | F | Y |
| Sistema de Custodia | Tab / I | Select |
| Bolsillos | 1–5 | — |
| Pausa | Esc | Start |

## Pendiente

- Voz de la megafonía: ahora es texto con sonido de megafonía y estática. Grabar la voz.
- Música y diseño de sonido definitivos (los sonidos actuales son sintetizados).
- Arte definitivo de interfaz y fuentes propias.
- Medir la duración real con jugadores.
