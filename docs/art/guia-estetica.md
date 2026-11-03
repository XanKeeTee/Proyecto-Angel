# Guía estética — Proyecto-Angel

> Basada en las referencias de [`referencias/`](referencias/README.md) (`ref_01`…`ref_07`). Las imágenes solo están en local; la tabla del README describe cada una.

## Sensación general

Terror analógico. Algo sagrado tratado como material de laboratorio. La pantalla parece una cinta VHS o una película vieja grabada en un sitio donde no debería haber cámaras. Frío, silencioso, clínico, con destellos de carne y una luz enferma que sale de las máquinas.

Palabras clave: **noche, hueso, carne, óxido, cable, halo, tanque, cinta.**

## Paleta

Tres ambientes, un neutro y un acento. Pocos colores por escena; el contraste y la oscuridad hacen el trabajo.

| Rol | Descripción | Uso | Valores orientativos | Ref. |
|---|---|---|---|---|
| **Azul noche / violeta** | Azul profundo casi negro que tira a violeta | Exteriores, cielo, lo distante y sagrado, salas de tanques | `#0B1026` `#1E1B3A` `#3A2E5C` | 02, 04 |
| **Granate / carne** | Rojo oscuro saturado, víscera y sangre seca | Zonas de carne, heridas, interfaz de daño, lo humano profanado | `#2A0A0E` `#5A1620` `#8E3A35` | 05, 06 |
| **Verde laboratorio** | Verde amarillento enfermizo de lámpara | Laboratorios, máquinas encendidas, halos, luz artificial | `#1A2418` `#3F5A2E` `#B8D45A` | 01, 07 |
| **Blanco hueso** | Blanco sucio, cálido | Máscaras, batas, halos, texto, puntos focales | `#E8E1D3` `#BFB6A3` | 02, 04 |
| **Óxido / máquina** | Grises y marrones apagados | Metal, consolas, cables, rejillas | `#2E2D2A` `#5E574C` `#7A6A4F` | 03, 05 |
| **Acento** | Rojo vivo o cian de monitor, muy escaso | Un elemento por escena: capa, cable, luz de peligro | `#C0392B` / `#5FB8B0` | 03, 04 |

> Los valores hex son punto de partida. Se fijarán en una paleta `.gpl`/`.hex` en `assets/` con el primer arte.

Reglas:
- Cada escena tiene **un ambiente dominante** (azul, granate o verde). Mezclarlos a partes iguales se reserva para momentos clave.
- El blanco hueso es lo más claro de la pantalla y dirige la mirada.
- La **oscuridad ocupa mucha pantalla**: en mapas, solo se ve bien lo que está cerca del personaje o de una fuente de luz (ref_06).
- Un único acento de color vivo por escena (la capa roja de ref_04, los cables de ref_03).

## Motivos visuales

- **Lo sagrado intervenido**: halos que siguen brillando sobre cuerpos rotos, alas sucias y desplumadas, piezas mecánicas injertadas en carne (ref_01). Lo divino aparece **dañado y manipulado**, nunca glorioso.
- **Máscaras pálidas y ojos huecos**: rostros sin expresión, grietas, a veces un solo ojo vivo (ref_04, ref_07).
- **Laboratorio**: batas blancas, tanques y piscinas de líquido con cuerpos sumergidos, mesas metálicas, lámparas colgantes de luz cónica, básculas, frascos (ref_01, ref_02).
- **Cables**: cuelgan del techo, conectan cuerpos y máquinas, caen en cascada hacia abajo (ref_01, ref_03).
- **Escala opresiva**: figuras enormes frente a personajes pequeños (ref_04); el cielo mismo puede tener cara (ref_07).
- **Arquitectura gótica en silueta** en exteriores: agujas, torres, ventanas estrechas (ref_07).
- **Materia orgánica como escenario**: paredes y suelos de carne, montones de huesos y cráneos (ref_06).

> Recordatorio de lore: ref_01 muestra un ángel fusionado con un motor. Sirve como referencia **visual** (luz, textura, injertos), pero la premisa de "ángel como fuente de energía de una máquina" está prohibida (ver `docs/lore/README.md`).

## Pixel art (estilo RPG Maker)

- Resolución base del juego: **640×360** con escalado entero (provisional, ver `docs/tech/README.md`).
- Tamaño de tile: **32 px** (aprobado).

### Personajes: realismo sucio

Referencia de **tono**: *Fear & Hunger*. Tomamos la idea, no sus sprites ni su interfaz: proporciones humanas reales, cuerpos frágiles, paleta apagada, suciedad y heridas visibles. Nada de cabezones chibi.

- Fotograma de **48×68 px**. La figura mide unos **58 px**, con la cabeza a ~1/7 de la altura. Los pies apoyan en la parte baja de la casilla.
- **16 orientaciones** (cada 22,5°) para andar y 8 para las acciones; detalle técnico en [docs/tech/personaje.md](../tech/personaje.md):

  | Animación | Fotogramas |
  |---|---|
  | Reposo (respira) | 8 |
  | Gesto: se lleva la mano a la herida y mira al suelo (con linterna: mira a un lado y a otro) | 12 |
  | Paso | 12 (un ciclo = 2 casillas) |
  | Paso de espaldas: más corto, apoya primero la punta, tronco algo atrás, brazos separados | 12 |
  | Paso lateral (izquierda y derecha): la cadera gira hacia donde va, la cabeza mira al frente | 12 + 12 |
  | Giro en el sitio: arrastra los pies | 8 |
  | Acciones: alcanzar abajo, a media altura y arriba, recoger del suelo (hinca la rodilla derecha), llave, válvula, palanca, forzar | 10 cada una |
  | Levantarse de la camilla (solo al empezar) | 56 |

  Todas existen con y sin linterna.

- **Movimiento secundario del paso**:
  - la cadera gira con la pierna que avanza y los hombros giran al contrario;
  - el pie apoya el talón y despega con los dedos;
  - los brazos van con un poco de retraso;
  - la cabeza se estabiliza con un leve cabeceo;
  - el tronco va inclinado hacia delante;
  - el bajo de la bata se balancea.
- **Ropa por capas**: cuerpo con ropa interior y una hoja por prenda, del mismo tamaño. Las prendas largas se balancean en el juego (el bajo, no la cintura).
- **En el juego**:
  - mira hacia el puntero y puede andar de espaldas o de lado, cada uno con su paso;
  - los giros pasan por las orientaciones intermedias;
  - tras unos segundos quieto, el personaje hace uno de sus gestos;
  - la luz de la linterna sale de la lente en cada fotograma.

- **Movimiento realista**: rodilla que se dobla al adelantar la pierna, peso que pasa de un pie a otro, brazos en contrapeso y una **ligera cojera** (la pierna derecha da el paso más corto). En reposo, el pecho y los hombros suben y bajan.
- **La linterna se sujeta con la mano derecha**, codo pegado al cuerpo y antebrazo al frente, a la altura del pecho. La lente es emisiva (capa `*_glow.png`). De espaldas queda tapada por el cuerpo.
- Postura encorvada, zancada corta. Ojos hundidos (cuencas oscuras, sin pupila visible a esta escala).
- Contorno de color: el tono más oscuro del material, mezclado con `#0E0A12`. Nunca negro puro. (Solo personajes: los objetos del mapa no llevan contorno, ver *Escenarios*.)
- Cada sprite lleva **mapa de normales** (`*_n.png`), para que la linterna revele el volumen.
- **Rasgos propios del protagonista** (lo que lo hace nuestro):
  - cabeza rapada con una cicatriz cosida en el cráneo;
  - bata abierta por detrás con una incisión cosida a lo largo de la columna;
  - vía arrancada con sangre en la mano izquierda;
  - pulsera de paciente;
  - pies sucios.

### Iconos de objetos

- Miden `size × 36 − 4` px según la forma del objeto (`ItemDef.ICON_CELL`) y el objeto llena el recuadro. Las listas de la custodia los reducen a miniaturas (`ItemThumbs`); el panel de detalles usa la primera vista del inspector.
- Detalle a escala real: moleteado, estrías, roscas, etiquetas con líneas de texto, graduaciones, tornillería, dientes de llave, pintura desconchada.
- Metal, cristal y plástico llevan brillo especular. Tramado suave (menos que en el mapa).
- La ropa se dibuja con el mismo modelo que lleva puesto el personaje, sin cuerpo.
- El inspector y el panel de detalles usan vistas de 112 px.

### Escenarios

- Paredes de **3 casillas** (96 px): arriba yeso con humedades, moho y pintura levantada; en medio una barandilla metálica; abajo azulejo agrietado y zócalo. Las puertas miden casi toda la pared.
- Los objetos se ven en vista oblicua: la tapa se ve desde arriba y el frente de cara, como en RPG Maker, pero con volumen real y desgaste (óxido, abolladuras, manchas).
- Suciedad que se acumula donde se acumularía de verdad: juntas, rincones, la parte baja de las paredes y el bajo de las telas.
- Lo que emite luz (pantallas, pilotos) lleva una capa `*_glow.png` que se dibuja sin sombra.
- **Los objetos del mapa se funden con el escenario**: sin contorno (el borde lo da el sombreado del propio
  material, como en los tiles), luces comprimidas para que el blanco hueso de un mueble no pase mucho del tramo
  más claro de las paredes, y saturación algo más baja que la del modelo (`tools/art/shadow.py::blend_in`).
  Lo emisivo no se toca. Qué se puede usar lo dice el juego (contorno de foco y destello), nunca el dibujo:
  un mueble interactuable y uno de decorado se pintan igual. Los iconos de objeto tirados por el suelo se apagan
  en la escena (`ITEM_ON_FLOOR_TINT` en `build_hospital.gd`).
- **Puertas vistas desde atrás del muro** (las salas al sur del pasillo): desde ese lado solo se ve el remate,
  así que el remate de la puerta es el hueco visto desde arriba (cabezas de las jambas, suelo del paso en penumbra,
  canto de la hoja y umbral) y la linterna lo alumbra; delante, en el suelo, desgaste de paso (`doorway`) en lugar
  de la sombra al pie de la pared. Nada de carteles: se adivina, no se señala.
- **Nada flota**: todo objeto apoyado lleva sombra de contacto (horneada en el sprite) y lo que cuelga de la pared,
  una sombra arrojada de 1-2 px sobre el muro. Los objetos sueltos del suelo llevan una sombra suave debajo.
- **Cada sala cuenta algo** con su decorado (abandono precipitado, algo que pasó), sin explicarlo: papeles hasta la
  puerta, un biombo caído, tuberías que gotean. El decorado no se puede usar, pero tiene volumen, colisión y sombra.
- Pies de pared y rincones más oscuros; el sótano con tuberías y cables vistos.

### Arte provisional generado

Todo el arte actual se genera con `python -I tools/art/build_all.py`, con un renderizador propio (`tools/art/pxrender.py`) que modela con volúmenes simples, reduce a rampas de color con tramado y saca los mapas de normales. Sirve para fijar el estilo y la escala. El arte definitivo puede pintarse a mano encima, **manteniendo tamaños de fotograma, puntos de apoyo (`tools/art/sprite_meta.json`) y la disposición del atlas** (ver `tools/art/tiles.py`).

> **En revisión**: el usuario ha pedido rehacer todo el arte en 2D, sin volúmenes 3D, con 8 direcciones.
> Muestra, flujo propuesto, plan y decisiones pendientes en [arte-2d.md](arte-2d.md).
- **Mapas** (ref_06): vista cenital RPG Maker, personajes **de proporciones realistas** (ver abajo) de 4 direcciones y 3 frames. Texturas densas y "sucias", no limpias. Iluminación con máscara de oscuridad alrededor del jugador.
- **Combate** (ref_05): enemigo grande de frente en el centro, grupo del jugador de espaldas en primer plano, escenario con perspectiva. Los enemigos deben tener **partes del cuerpo distinguibles a simple vista**, porque son objetivos de combate.
- **Retratos y escenas ilustradas** (ref_02, ref_04): pueden tener más detalle, estilo pintado o anime oscuro, siempre con la paleta del juego. Útiles para momentos clave y finales.
- Contorno oscuro de color (azul o granate muy oscuro), no negro puro, en personajes y combate; los objetos del mapa van sin contorno.

## Interfaz

- Sobria y funcional (ref_05): ventanas rectangulares de fondo oscuro semitransparente, borde fino claro, comandos en lista vertical a la izquierda y estado del grupo a la derecha.
- Barras finas y discretas. La idea de **dos recursos por personaje** (cuerpo y mente) es interesante para el diseño; se decide en `docs/design/`, no aquí.
- Fuentes del sistema: serifa legible para menús y títulos, máquina de escribir para datos y documentos y letra a mano para notas, con suavizado y tamaños pensados para la vista de 640×360. Ver [fuentes.md](fuentes.md).
- La legibilidad manda sobre los efectos.

## Tratamiento analógico (post-procesado)

Se aplica en pantalla completa; lo implementa el subagente `shader-fx`.

| Efecto | Intensidad base | Notas | Ref. |
|---|---|---|---|
| Grano | Baja, siempre presente | Ruido animado de película/VHS | 07 |
| Virado de color | Por zona | Sepia-verde para exteriores, frío para laboratorios | 07, 01 |
| Aberración cromática | Baja; sube en tensión | Desplazamiento horizontal R/B | — |
| Scanlines / CRT | Sutil | Sin moiré al escalar | — |
| Viñeta | Media-alta | Bordes muy oscuros | 06, 07 |
| Halo de luz (bloom suave) | Solo en fuentes de luz | Lámparas, halos | 01 |
| Distorsión / tracking | Solo en eventos | Bandas horizontales, saltos de imagen | — |

Accesibilidad: todos los efectos se pueden reducir o desactivar; nada de destellos rápidos sin aviso.

## Texto en pantalla

- **Subtítulos cortos en mayúsculas** con punto final, como sellos: `NOT CRY.` `HOST.`
- Tamaño pequeño, **centrados**, con serifa, blanco hueso sobre la imagen, sin caja (ref_02: "AS YOU").
- Una a tres palabras para los momentos de impacto; el texto largo va en cajas de diálogo normales.
- Ligera aberración cromática y grano en los textos de impacto.

## Lo que evitamos

- Gore detallado que rompa el pixel art: la mutilación se comunica con silueta, color y animación breve.
- Colores saturados alegres, degradados limpios, brillo "épico".
- Ángeles bellos e intactos.
- **Copiar** composiciones, personajes, interfaz o escenarios concretos de las referencias. En particular, ref_05 y ref_06 son capturas de otro juego: tomamos el tipo de encuadre y el tono, no su interfaz exacta, sus nombres ni sus sprites.
