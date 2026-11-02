# Arte 2D dibujado a mano con código (muestra para debatir)

> Estado: **muestra**. Nada de esto está integrado en el juego. Sirve para decidir cómo se rehace
> todo el arte antes de empezar. Imágenes en [`muestras/`](muestras/); código en `tools/art2d/`.

## Por qué

El arte actual (`tools/art/pxrender.py`) modela volúmenes 3D (esferas, elipsoides y cápsulas), los
ilumina y los reduce a píxeles. Por eso las siluetas salen de tubo, con bultos redondos y aspecto de
maniquí. El usuario pidió **todo en 2D**, con la referencia del combate de *Fear & Hunger*: siluetas
angulosas e irregulares, huesos y articulaciones marcados, pliegues dibujados, sombreado por zonas
planas con pocos tonos, contorno oscuro y paleta desaturada y sucia.

El flujo nuevo no usa geometría 3D ni trazado de rayos: **todo se dibuja en el plano**, con formas
definidas a mano punto a punto.

## Muestras

| Archivo | Qué enseña |
|---|---|
| [antes_despues.png](muestras/antes_despues.png) | Arte actual frente al nuevo: personaje, enfermero y taquilla |
| [protagonista_8dir.png](muestras/protagonista_8dir.png) | Protagonista en el mapa: 8 direcciones, 2 fotogramas de reposo y 4 de paso (×3) |
| [paso_8dir.gif](muestras/paso_8dir.gif) | El paso animado en las 8 direcciones |
| [protagonista_combate.png](muestras/protagonista_combate.png) | De espaldas en combate, 64×110, 3 fotogramas de reposo (×4) |
| [enfermero.png](muestras/enfermero.png) | Enfermero 200×260: reposo (2), ataque (Tajo) y muñón del brazo de instrumental (×2) |
| [enfermero_piezas.png](muestras/enfermero_piezas.png) | Las piezas separables: piernas, tronco, brazos, cabeza y muñón |
| [enfermero_reposo.gif](muestras/enfermero_reposo.gif) | Reposo animado del enfermero |
| [escenario.png](muestras/escenario.png) | Taquilla cerrada y abierta, tramo de pared (32×96) y suelo (32×32), ×4 |
| [maqueta_combate.png](muestras/maqueta_combate.png) | Maqueta 640×360 con foco, menús y el filtro de película del juego |
| [maqueta_combate_ataque.png](muestras/maqueta_combate_ataque.png) | La misma, con el aviso del ataque |
| [en_sala.png](muestras/en_sala.png) | El protagonista nuevo pegado en una captura real (sala de la 09), con ampliación |

Regenerarlas (unos 4 s):

```bash
python3 -I tools/art2d/sheets.py docs/art/muestras [captura.png] [x,y]
```

## Cómo se dibuja

`tools/art2d/` es una librería pequeña y reutilizable:

| Módulo | Para qué |
|---|---|
| `px2d.py` | El núcleo. `Part`: una capa con **material y tono por píxel**. Polígonos (`poly`), zonas de luz y sombra (`shade`), líneas (`line`), píxeles sueltos (`dot`), borrado (`erase`), bandas que siguen la silueta (`rim`), tramado (`pattern`, `dither_edges`), contorno selectivo (`render`), composición de piezas (`compose`), extremidades angulosas (`limb`), giro de recortes sin emborronar (`rotsprite`) y hojas (`sheet`). |
| `pen.py` | `Pen`: dibuja en una `Part` con coordenadas de diseño, escala y desplazamientos (balanceo del paso, respiración); `pixmap` pinta un dibujo píxel a píxel escrito como texto. |
| `palette.py` | Rampas de 3-5 tonos por material, desaturadas y sucias. |
| `protagonist.py` | Protagonista en el mapa (8 direcciones). |
| `protagonist_battle.py` | Protagonista de espaldas en combate. |
| `enemy_nurse.py` | Enfermero por piezas, poses de reposo y ataque, muñón. |
| `props2d.py` | Taquilla, baldosa de suelo y tramo de pared. |
| `sheets.py` | Hojas de comparación, maquetas y el filtro de película aproximado (`film_grade`). |

### Reglas del dibujo

1. **Silueta trazada a mano.** Cada pieza es un polígono con sus vértices escritos uno a uno
   (bajo de la bata en jirones, hombros alzados, máscara con el pómulo marcado). Brazos y piernas
   son perfiles `limb(a, b, perfil)`: entre dos articulaciones, una lista de anchos a cada lado
   (rodilla huesuda, pantorrilla, codo, deltoides). Sale anguloso porque solo hay vértices rectos.
2. **Luz y sombra como formas planas.** Encima del color base se pintan polígonos de tono
   (el hombro a la luz, la sombra bajo las costillas, el pliegue que cae). `rim(dx, dy)` añade la
   sombra que sigue el borde del lado contrario a la luz con los mismos ángulos de la silueta.
   Nada de degradados: 3-5 tonos por material.
3. **Tramado solo en las transiciones** (`dither_edges`, `pattern="checker"`), y con moderación:
   a esta escala el damero se lee como malla si se abusa.
4. **Detalle píxel a píxel** donde importa: las cabezas del mapa (`HEAD_S`, `HEAD_W`…) se escriben
   como texto, un carácter por píxel; puntadas, ojos, uñas, tornillos y gotas van con `dot`.
5. **Contorno selectivo**: 1 px por fuera de cada pieza, del tono más oscuro del material mezclado
   con tinta `#0E0A12`; en el lado de la luz, el segundo tono (más suave). Como cada pieza lleva el
   suyo, un brazo por delante del tronco queda separado por una línea, como en *Fear & Hunger*.
   Los objetos del mapa siguen sin contorno (guía estética).
6. **Animación 2D**:
   - **Fotogramas redibujados desde un esqueleto 2D** (lo que usa la muestra): cada pose mueve
     las articulaciones y la pieza se vuelve a trazar con su perfil. No se deforma ni se gira el
     dibujo, así que no se emborrona.
   - **Recortes (*cutout*)** para movimientos pequeños: la cabeza del enfermero se inclina con
     `rotsprite` (ampliar sin filtrar, girar, reducir tomando el píxel central).
7. **Piezas separables** en los enemigos: cada parte del cuerpo es una capa del mismo tamaño
   (como ahora en `sprite_meta.json`), y cada una tiene su muñón (`stump_*`).
8. **Espejo**: las vistas E, SE y NE son el espejo de O, SO y NO. Los detalles asimétricos (pulsera
   en la derecha, vía en la izquierda) se dibujan **antes** de reflejar, en la mano que toca. La luz
   del mapa viene de arriba y de frente, así el espejo no la contradice.

## Decisiones

Tomadas por el usuario:

- **8 direcciones** (S, SO, O, NO, N, NE, E, SE), con buena resolución de dibujo. Sustituyen las
  16 orientaciones actuales.
- **Rehacer todo** en 2D: personajes, enemigos, muebles, decorado, suelos y paredes.
- El filtro de película nuevo (`shaders/film_grade.gdshader`) se queda; las maquetas lo llevan.

Pendientes (las dos personas del equipo):

1. **Tamaño del fotograma del mapa.** La muestra propone **56×80** (figura de ~68 px y cabeza de
   12 px) en lugar de 48×68 (figura de 58 px, cabeza de 9-10 px). Con 9 px de cabeza no caben unas
   cuencas, una nariz y una cicatriz legibles en las 8 vistas.
   - Cámara y vista: sin cambios (640×360). El personaje ocupa un 19 % del alto de la pantalla en
     vez de un 16 %.
   - Tiles de 32 px: sin cambios. La figura mide 2,1 casillas (antes 1,8): una persona de 1,75 m
     sobre casillas de ~0,8 m. Las paredes de 3 casillas (96 px) siguen siendo más altas que él.
   - Colisión: no cambia (va a los pies). Cambian `frame` y `origin` en `sprite_meta.json`,
     `player.tscn` y las capas de ropa.
   - Muebles: se dibujan a la escala de la figura nueva (la taquilla de la muestra mide 72 px de
     frente: ~1,85 m).
2. **Contorno**: ¿el de la muestra (selectivo, más suave en el lado de la luz) o uno uniforme y más
   oscuro como en *Fear & Hunger*? ¿Granate/azul muy oscuro o casi negro?
3. **Paleta**: la muestra usa rampas cortas y desaturadas (`palette.py`). Falta fijar la paleta
   cerrada del juego (`.gpl`) con el primer arte aprobado.
4. **Mapas de normales**: hoy cada sprite lleva `*_n.png` para que la linterna revele el volumen.
   Opciones: (a) quitarlos (luz plana más la máscara de oscuridad, como *Fear & Hunger*);
   (b) asignar una normal por zona plana al dibujar (cada polígono de luz/sombra «mira» a un lado),
   barato y coherente con el dibujo; (c) pintarlos aparte. Propuesta: (b).
5. **Fotogramas por animación**: la muestra tiene 4 de paso y 2 de reposo. La guía pide 12 de paso
   y 8 de reposo en 16 orientaciones. Con 8 direcciones y dibujo 2D, propuesta: paso 6-8, reposo 4,
   acciones 6, levantarse de la camilla 24.

## Plan para rehacer todo el arte

### Orden de trabajo

1. **Cerrar el estilo** (con esta muestra): tamaño, contorno, paleta, normales. Ajustar `px2d`.
2. **Protagonista en el mapa**: 8 direcciones × reposo, paso, giro, acciones (alcanzar abajo,
   media altura y arriba, recoger, llave, válvula, palanca, forzar), levantarse de la camilla;
   con y sin linterna. Es lo que más se ve.
3. **Ropa por capas**: cada prenda como polígonos propios sobre el mismo esqueleto (bata,
   pantalón, chaqueta, gorros, calzado), con las mismas poses.
4. **Tiles**: suelos, paredes de 3 casillas, puertas y pasos (con sus oclusores y colisión).
5. **Muebles y decorado** (~75 sprites de `assets/sprites/props/`), primero los que se usan.
6. **Combate**: protagonista de espaldas (con la ropa), el enfermero con todas sus poses (reposo,
   cada ataque con su aviso, dolor, arrastrándose, muerte), muñones de las 6 partes, cadáver.
7. **Enfermero en el mapa** (8 direcciones, paso, ataque, caído) y la entidad de terror.
8. **Integración**: `sprite_meta.json`, `player.tscn`, capas de ropa, normales, colisiones;
   capturas de cada sala y pruebas.

### Flujo por tipo de arte

| Tipo | Cómo | Animación |
|---|---|---|
| Personajes del mapa | Esqueleto 2D por vista + perfiles de extremidad + cabezas píxel a píxel; 5 vistas propias y 3 en espejo | Fotogramas redibujados desde el esqueleto |
| Ropa | Polígonos de cada prenda anclados a las mismas articulaciones; misma hoja que el cuerpo | La de su portador |
| Enemigos de combate | Piezas separables a resolución final, perfiles grandes, anatomía con líneas y zonas planas | Poses redibujadas; recortes con `rotsprite` para la cabeza y gestos pequeños |
| Muebles y decorado | Vista oblicua: tapa en franja y frente; desgaste dibujado (abolladuras, óxido, pintura saltada); sin contorno; sombra de contacto plana | Estados (abierto, cerrado, roto) como fotogramas |
| Suelos y paredes | Tiles de 32 px con juntas a un lado (se repiten sin juntas dobles), variantes con semilla fija | — |

### Estimación

En sesiones de trabajo de un agente (cada una, unas 2 h de trabajo con revisión de capturas), sin
contar las rondas de revisión del equipo:

| Bloque | Sesiones |
|---|---|
| Cerrar estilo y librería | 1-2 |
| Protagonista en el mapa (todas las animaciones) | 5-7 |
| Ropa (6-7 prendas) | 4-6 |
| Tiles (suelos, paredes, puertas) | 3-4 |
| Muebles y decorado (~75) | 8-10 |
| Combate (protagonista y enfermero completos) | 5-7 |
| Enfermero en el mapa y entidad | 3-4 |
| Integración y pruebas | 2-3 |
| **Total** | **31-43** |

Con revisiones del equipo entre bloques, de 4 a 6 semanas de calendario. Se puede trabajar en
paralelo por bloques (personajes / escenario / combate) si cada uno toca sus propios archivos.

## Límites de la muestra

- Los brazos del enfermero aún se leen algo tubulares; falta más anatomía (tendones, nudillos,
  la costura del metal más trabajada).
- El protagonista del mapa no lleva normales ni linterna, y no está integrado: en la captura
  editada está pegado encima y oscurecido a mano.
- Las vistas de tres cuartos estrechan el cuerpo de forma paramétrica; en el arte final conviene
  repasar a mano cada una.
- No hay ropa por capas ni acciones.
