# Arte 2D pintado con código (segunda muestra, para debatir)

> Estado: **muestra**. No está integrada en el juego. Imágenes en [`muestras/`](muestras/);
> código en `tools/art2d/` (los módulos `*_hd.py` son de esta segunda muestra; `px2d.py`,
> `protagonist.py`, `enemy_nurse.py`, `props2d.py` y `sheets.py` son de la primera).

## Qué pidió el usuario y qué cambia

| Petición | Respuesta en esta muestra |
|---|---|
| Nada de 3D: todo en 2D | Siluetas trazadas a mano punto a punto; el volumen se **pinta** encima (ver *Cómo se dibuja*). No hay esferas, cápsulas ni trazado de rayos. |
| 8 direcciones | Las 8 se dibujan todas, sin espejo: la pulsera y la vía siempre en su mano, la luz siempre del mismo lado. |
| Protagonista con mucha más resolución y detalle; humano normal | Fotograma de **112×160** (figura de ~140 px, cabeza de ~23 px). **Sin pieza metálica** (canon actualizado en `docs/lore/prologo.md`): cicatriz cosida en el cráneo, incisión cosida en la columna, pulsera, vía arrancada, pies sucios, cardenales. |
| Enemigos mucho más detallados y realistas | Enfermero de **400×540** con piel con poros, moteado, venas y cardenales; músculo y hueso marcados; tela con trama, costuras, desgarros y sangre que empapa; porcelana agrietada con brillo; metal con reflejos; cristal de la jeringa con el líquido dentro. |
| Pose de combate, no un maniquí | De espaldas en guardia: piernas abiertas y flexionadas, peso adelante, hombros alzados, el tubo en alto con las dos manos; respiración de 4 fotogramas y un golpe. |
| Menú principal con el arte del juego | Maqueta de 1280×720: ilustración del pasillo con la puerta de la 09 al fondo, la camilla con correas bajo el único fluorescente y el protagonista de espaldas; título trabajado; opciones en un marco de chapa oxidada con remaches y una pestaña de expediente. El mismo marco en las cajas del combate. |

## Muestras

| Archivo | Qué enseña |
|---|---|
| [antes_despues.png](muestras/antes_despues.png) | Arte 3D actual, muestra 1 y muestra 2 **a la misma escala de pantalla** |
| [protagonista_8dir.png](muestras/protagonista_8dir.png) · [paso_8dir.gif](muestras/paso_8dir.gif) | Mapa: 8 direcciones, 2 de reposo y 4 de paso, a escala 1 |
| [protagonista_combate.png](muestras/protagonista_combate.png) · [combate_guardia.gif](muestras/combate_guardia.gif) | Guardia con el tubo (respiración) y golpe |
| [enfermero.png](muestras/enfermero.png) · [enfermero_reposo.gif](muestras/enfermero_reposo.gif) | Reposo (2), Tajo y muñón del brazo de instrumental |
| [enfermero_piezas.png](muestras/enfermero_piezas.png) | Piezas separables para las mutilaciones |
| [escenario.png](muestras/escenario.png) | Taquilla (88×184) cerrada y abierta, tramo de pared (64×192) y suelo (64×64), ×2 |
| [maqueta_combate.png](muestras/maqueta_combate.png) · [maqueta_combate_ataque.png](muestras/maqueta_combate_ataque.png) | Combate a 1280×720 con el filtro de película y el marco nuevo |
| [maqueta_menu.png](muestras/maqueta_menu.png) | Menú principal a 1280×720 |

Regenerarlas (≈1 min; requiere numpy, scipy y Pillow):

```bash
python3 -I tools/art2d/sheets_hd.py docs/art/muestras
```

## Cómo se dibuja (`tools/art2d/paint.py`)

1. **Silueta a mano.** Polígonos punto a punto; brazos y piernas con `limb(a, b, perfil)` (anchos a cada
   lado a lo largo del hueso: deltoides, codo, gemelos, tobillo). Las formas siguen siendo planas y angulosas.
2. **Valor pintado, no geometría.** Cada pieza guarda material y valor (luz) por píxel:
   - `form`: el canto que gira. Se mide en 2D la distancia al borde y se aclara u oscurece una franja
     según hacia dónde mira ese borde; el interior queda plano. Es el canto redondeado de un dibujo;
   - `plane`: zonas de luz o sombra trazadas a mano (hombros al foco, sombra bajo las costillas);
   - `crease`: pliegues, oclusión y aristas (tendones, costillas, pliegues de la tela);
   - texturas: `noise` (moteado, mugre a parches), `pores`, `weave` (trama), `veins`, `stain` (manchas
     que empapan con el cerco oscuro y chorretones), `gloss` (brillo húmedo o pulido), `cast` (sombra arrojada).
3. **Rampas largas con tramado** (`palette_hd.py`): 6-8 colores clave interpolados a 12-16 tonos; el valor
   se convierte en tono con tramado ordenado Bayer 4×4. Transiciones suaves con aspecto de píxel.
4. **Contorno** oscuro de 1 px por pieza (personajes y enemigos); los objetos del mapa sin contorno.
5. **Montaje** (`compose`): piezas de atrás adelante con sombra de contacto de cada una sobre las de detrás.
6. **Ocho direcciones** (`protagonist_hd.Rig`): cada articulación tiene posición lateral, altura y profundidad,
   y para cada dirección se calcula dónde cae en pantalla. Es la maqueta de un muñeco de recortes que gira;
   las formas que se trazan encima son 2D. Las cabezas mezclan un contorno de frente y otro de perfil; ojos,
   nariz, boca, orejas y cicatriz se colocan por su ángulo alrededor del cráneo.
7. **Animación**: poses redibujadas desde el esqueleto (paso, guardia, golpe, ataque del enfermero);
   la cabeza del enfermero se inclina como recorte (`rotsprite`).

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
| Personajes del mapa | Esqueleto girable + siluetas a mano + pintura; cabezas por azimut | Poses redibujadas |
| Ropa | Polígonos por prenda anclados al esqueleto, en su propia hoja | La del portador |
| Enemigos de combate | Piezas separables a tamaño final, pintura rica, muñones | Poses redibujadas + recortes |
| Muebles y decorado | Vista oblicua, desgaste dibujado, sin contorno, sombra de contacto | Estados como fotogramas |
| Suelos y paredes | Baldosas de 64 con juntas a un lado y variantes | — |
| Interfaz e ilustraciones | Marco pintado reutilizable; ilustraciones a 640×360 dobladas o a 1280×720 | — |

### Estimación revisada

En sesiones de agente (≈2 h cada una, sin contar las rondas de revisión del equipo). Al doble de
resolución y con pintura más rica, cada pieza cuesta del orden de 1,5 a 2 veces más que en la primera
estimación.

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

- El enfermero ya tiene volumen y texturas, pero aún se nota generado: le falta un repaso a mano (manos,
  cara bajo la máscara, transición entre carne y metal).
- La pose de guardia se lee bien; el golpe es un primer fotograma, sin anticipación ni estela.
- Los tres cuartos del mapa salen del esqueleto girable; en el arte final conviene revisar a mano cada
  dirección.
- La ilustración del menú está pintada a 640×360 y doblada; la interfaz va a 1280×720 nativa.
