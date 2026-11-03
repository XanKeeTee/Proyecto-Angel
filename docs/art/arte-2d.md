# Arte 2D pintado y reducido (tercera muestra, para debatir)

> Estado: **muestra**. No está integrada en el juego. Imágenes en [`muestras/`](muestras/); código en
> `tools/art2d/`. La tercera muestra usa `vec.py` (`hero_battle_v3.py`, `nurse_v3.py`, `hero_map_v3.py`,
> `sheets_v3.py`); la segunda, `paint.py` y los `*_hd.py` (de ahí salen todavía el menú principal y el
> escenario); la primera, `px2d.py`.

## Qué cambia en la tercera muestra

El usuario vio la segunda y dijo que el personaje era feo, con **las partes del cuerpo separadas**, que la
**pose de pelea no tenía sentido** y que el enemigo era **muy básico**. El diagnóstico: cada miembro era
una pieza con su contorno y su sombreado, así que se veían cortes en hombros, codos y rodillas, y las
formas eran polígonos rectos. Cambio de método:

| Antes (muestra 2) | Ahora (muestra 3) |
|---|---|
| Polígonos a resolución final, una pieza por miembro con su contorno | **Curvas suaves a ×4-×6** del tamaño final; **una sola capa por material** (toda la piel junta, toda la tela junta) y **un solo contorno** alrededor de la figura |
| Sombreado por pieza (canto que gira) | **Masas** que dan volumen dentro de la silueta continua (omóplato, gemelos, deltoides, costillas), **luz lateral dura** con el terminador nítido, relleno suave, oclusión en pliegues, **contraluz** de color |
| Rampas con tramado a escala 1 | **Reducción con filtro de área**, **cuantización a la paleta** con tramado ordenado suave, **limpieza** de píxeles sueltos y **retoques a escala 1** (ojos, puntos de sutura) |
| Pose de guardia rígida | Pose de un herido que se defiende, comprobada **en silueta negra** |

## Muestras

| Archivo | Qué enseña |
|---|---|
| [protagonista_combate.png](muestras/protagonista_combate.png) · [combate_guardia.gif](muestras/combate_guardia.gif) · [combate_golpe.gif](muestras/combate_golpe.gif) | De espaldas: guardia (respiración ×4) y golpe ×3 (carga, impacto, retroceso), con sus siluetas |
| [enfermero.png](muestras/enfermero.png) · [enfermero_reposo.gif](muestras/enfermero_reposo.gif) | Reposo ×2, Tajo (el brazo de bisturíes en alto) y el muñón del brazo de instrumental |
| [enfermero_piezas.png](muestras/enfermero_piezas.png) | Las piezas separadas del mismo dibujo (`Fig.split`): tronco, cabeza, brazos, piernas |
| [protagonista_mapa_abajo.png](muestras/protagonista_mapa_abajo.png) · [paso_abajo.gif](muestras/paso_abajo.gif) | Mapa mirando abajo (112×160): reposo y paso ×4, y la silueta (×3) |
| [maqueta_combate.png](muestras/maqueta_combate.png) · [maqueta_combate_ataque.png](muestras/maqueta_combate_ataque.png) | Combate a 1280×720 con el filtro de película |
| [antes_despues.png](muestras/antes_despues.png) | Segunda muestra frente a la tercera, a escala 1 |
| [maqueta_menu.png](muestras/maqueta_menu.png) · [escenario.png](muestras/escenario.png) | De la segunda muestra (sin cambios en esta ronda) |

Regenerarlas (≈10 min; requiere numpy, scipy, Pillow y pycairo):

```bash
python3 -I tools/art2d/sheets_v3.py docs/art/muestras
```

## Método (`tools/art2d/vec.py`)

1. **Trazo en alta resolución.** Cada forma es una curva cerrada que pasa por los puntos que se dan
   (Catmull-Rom convertida a Bézier cúbicas; `C(x, y)` marca una esquina), rasterizada con cairo a ×k del
   tamaño final (×6 para el protagonista, ×4 para el enfermero). Los miembros salen de `limb_outline`: un
   contorno suave que pasa por hombro, codo y muñeca (o cadera, rodilla, tobillo) con su ancho en cada punto,
   así el brazo es una sola forma que fluye, sin cortes en las articulaciones.
2. **Una silueta por material.** Todo lo que es piel se rellena en la misma capa (piernas, tronco, cuello,
   brazos, manos); la bata en otra; el hierro en otra. Lo que va delante se pinta después.
3. **Volumen pintado a esa escala.**
   - `mass(región, soft)`: la normal sale de la propia silueta difuminada (no hay geometría 3D);
     da una luz **dura** (terminador nítido), un relleno suave y la oclusión del borde. Se aplica a la figura
     entera y luego a masas internas trazadas a mano (omóplatos, gemelos, deltoides, joroba, puños);
   - `crease`: pliegues de tracción y de peso en la tela, corvas, esternón, costillas, tendones, con su arista
     de luz al lado;
   - `rim`: contraluz de color (granate en el enfermero, frío en el protagonista);
   - texturas: `noise` (moteado, mugre), `pores`, `weave` (trama), `stain` (manchas que empapan con cerco,
     sangre seca y fresca con brillo húmedo), `veins`, `gloss`.
4. **Reducción y paleta.** Filtro de área al tamaño final, cuantización a la paleta del juego (rampas de
   `palette_v3.py` muestreadas a 12 tonos) con tramado Bayer suave, limpieza de píxeles sueltos en la
   silueta y en el color, y **contorno de un píxel** alrededor de toda la figura (del tono oscuro vecino
   mezclado con tinta).
5. **Retoques a escala 1** (`touch`): ojos, brillo húmedo, puntos de sutura.
6. **Piezas para las mutilaciones**: cada relleno se etiqueta con su pieza (`Fig.cur`) y `Fig.split` separa
   la imagen final en capas, así el sistema de mutilaciones usa exactamente el mismo dibujo.
7. **Comprobación en silueta** (`Fig.silhouette`): la pose tiene que leerse en negro, sin detalle.

### Las poses

- **Protagonista en combate**: piernas separadas, la izquierda algo adelantada, rodillas flexionadas y el
  talón derecho levantado; tronco girado hacia la derecha y encorvado; el tubo cogido con las dos manos
  juntas por un extremo, como un bate, alzado sobre el hombro derecho (dedos apilados alrededor del tubo y
  pulgar por encima); la cabeza adelantada. Golpe: **carga** (más enroscado, el tubo detrás de la cabeza),
  **impacto** (el tubo descarga hacia delante y a la izquierda, el tronco gira), **retroceso** (rebota y baja).
- **Enfermero**: muy encorvado, la joroba de la columna (con las vértebras marcándose bajo la tela) asoma por
  encima de la cabeza, que cuelga ladeada sobre el pecho; brazos que llegan a las rodillas; bisturíes en
  abanico como dedos, sierra por el canto, abrazaderas y grapas donde la carne se funde con el metal; jeringa
  de cristal con el líquido oscuro; tubos que entran en el pecho con la piel fruncida; desgarro con el
  esternón y las costillas; mascarilla cosida con puntos que tiran de la piel; máscara de porcelana agrietada
  con un ojo vivo y húmedo. Luz lateral fría y contraluz granate.

## Resolución propuesta

**Vista interna de 1280×720, baldosas de 64 px, personaje de 112×160 (≈2,2 casillas de alto).**

Es el doble de lo actual en cada eje: el mapa, que se mide en casillas, no cambia; todo lo que va en
píxeles se multiplica por 2. A esta escala caben de verdad cara, manos, pliegues y heridas.

| Pantalla | Escala desde 1280×720 | Nota |
|---|---|---|
| 1280×720 | ×1 | |
| 2560×1440 | ×2 entero | |
| 3840×2160 (4K) | ×3 entero | |
| **1920×1080** | **×1,5** | No es entero: con «vecino más cercano» unos píxeles salen dobles y otros sencillos (el tramado se nota irregular). Solución habitual: escalar ×2 sin filtrar y luego reducir con filtro lineal (*sharp bilinear*), un shader pequeño al final. |

Alternativa: **960×540** con baldosas de 48 px y personaje de 84×120. Escala entera en 1080p (×2) y 4K (×4),
pero con un 44 % menos de píxeles: la cara del protagonista se queda en ~17 px. **Propuesta: 1280×720**
con el reescalado *sharp bilinear* para 1080p.

### Qué implica en el motor

- **Proyecto**: `display/window/size/viewport_width/height` a 1280×720; modo de estiramiento `viewport`
  con escala entera donde se pueda y el shader de reescalado en 1080p.
- **Mapa y tiles**: tamaño de casilla 32 → 64 (`TileSet`, `tile_size`); las posiciones en casillas de
  `hospital_layout.json` no cambian. Todo lo que el código expresa en píxeles se dobla: formas de colisión,
  oclusores, desplazamientos de props, `sprite_meta.json` (fotogramas, orígenes, anclas), radios y texturas
  de las luces, distancia de interacción, velocidad del jugador en px/s, límites de la cámara.
- **Cámara**: misma vista en casillas (20×11,25); zoom 1.
- **Interfaz**: todo el diseño a ×2 (tamaños de fuente, márgenes, iconos de objeto, custodia, inspector,
  caja de mensajes). Las fuentes del sistema ganan nitidez. Conviene un factor de escala único en
  `ui_style.gd` en vez de números sueltos.
- **Shaders**: los parámetros en píxeles (grano, aberración, escalones de tramado) se ajustan al doble.
- **Memoria**: cada textura tiene 4 veces más píxeles. El protagonista con todas sus animaciones
  (8 direcciones × ~60 fotogramas de 112×160) cabe en un atlas de 4096×2160; sin problema.
- **Pruebas**: revisar las que comprueban posiciones en píxeles.

## Decisiones pendientes

1. **Resolución**: 1280×720 (propuesta) o 960×540.
2. **Nivel de acabado**: la muestra sale íntegra del generador. Para un acabado de juego comercial en
   protagonista y enemigos, propongo un flujo **mixto**: el generador hace la base (siluetas, poses,
   sombreado, texturas, las 8 direcciones y la animación coherentes) y una persona retoca a mano los
   fotogramas clave (cara, manos, heridas) en Aseprite o Krita. Los muebles, suelos y paredes pueden quedarse
   solo con el generador.
3. **Contorno**: oscuro de 1 px en personajes y enemigos, como ahora; o más fino y coloreado.
4. **Normales para la linterna**: sacarlas del valor pintado (`form` ya calcula hacia dónde mira cada canto)
   o prescindir de ellas.
5. **Fotogramas**: paso 6-8, reposo 4, acciones 6; combate: guardia 4, golpe 3-4.
6. **Título**: tipografía del logotipo (la maqueta usa Libre Baskerville, OFL; habría que incluirla en el
   proyecto) y si se añade algún subtítulo (sería `[PROPUESTA]` de lore).

## Plan para rehacer todo el arte

### Orden

1. Cerrar estilo y resolución; cambiar el proyecto a 1280×720 y baldosas de 64 (con el mapa actual
   ampliado como provisional, para no romper nada).
2. Protagonista en el mapa: 8 direcciones × reposo, paso, giro, 8 acciones, levantarse; con y sin linterna.
3. Ropa por capas sobre el mismo esqueleto.
4. Tiles: suelos, paredes de 3 casillas, puertas.
5. Muebles y decorado (~75).
6. Combate: protagonista en guardia con cada arma y golpe; enfermero completo (todas las poses, 6 muñones,
   arrastrándose, muerte, cadáver).
7. Enfermero en el mapa y entidad.
8. Interfaz: marco nuevo, menú principal, custodia, inspector, caja de mensajes.
9. Integración y pruebas.

### Flujo por tipo

| Tipo | Cómo | Animación |
|---|---|---|
| Personajes del mapa | `vec`: curvas a ×6, una capa por material, masas, reducción y paleta | Poses redibujadas desde las articulaciones |
| Ropa | Formas por prenda sobre las mismas articulaciones, en su propia capa | La del portador |
| Enemigos de combate | `vec` a ×4, piezas etiquetadas y separadas con `split`, muñones | Poses redibujadas; la cabeza puede inclinarse como recorte |
| Muebles y decorado | `vec` o `paint` (formas más simples), sin contorno, sombra de contacto | Estados como fotogramas |
| Suelos y paredes | Baldosas de 64 con juntas a un lado y variantes | — |
| Interfaz e ilustraciones | Marco pintado reutilizable; ilustraciones a 640×360 dobladas o a 1280×720 | — |

### Estimación revisada

En sesiones de agente (≈2 h cada una, sin contar las rondas de revisión del equipo). Con el método de la
tercera muestra cada figura cuesta más (diseño de la silueta y de las masas a mano, y varias iteraciones
mirando la silueta), pero el resultado ya no necesita reconstruirse: la estimación de la segunda ronda se
mantiene, con el margen alto como más probable.

| Bloque | Sesiones |
|---|---|
| Cerrar estilo, resolución y cambio del proyecto a 1280×720 | 3-4 |
| Protagonista en el mapa (todas las animaciones) | 8-10 |
| Ropa (6-7 prendas) | 6-8 |
| Tiles (suelos, paredes, puertas) | 4-5 |
| Muebles y decorado (~75) | 12-15 |
| Combate (protagonista y enfermero completos) | 8-10 |
| Enfermero en el mapa y entidad | 4-5 |
| Interfaz a ×2 con el marco nuevo y menú principal | 4-5 |
| Integración y pruebas | 3-4 |
| **Total** | **52-66** |

Con revisiones entre bloques, de 7 a 10 semanas de calendario; se puede repartir en paralelo
(personajes / escenario / combate e interfaz). El retoque a mano del flujo mixto va aparte y depende
de quién lo haga.

## Límites de esta muestra

- Solo la dirección «abajo» del mapa está hecha con el método nuevo; las otras siete se harían igual.
- El protagonista del mapa todavía se ve algo rígido (la bata cae como un saco y la cara a 112×160 tiene
  pocos píxeles); necesita otra pasada de diseño o el retoque a mano del flujo mixto.
- El enfermero ya es una figura continua con volumen, anatomía y texturas, pero aún se nota generado:
  conviene un repaso a mano de la cara bajo la máscara, la mano de la jeringa y la unión de la carne con el metal.
- Las grietas de la porcelana y las venas se pierden un poco al reducir; se retocarían a escala 1.
- El menú principal y el escenario son de la segunda muestra.
