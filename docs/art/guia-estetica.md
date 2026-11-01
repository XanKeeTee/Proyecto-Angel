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
- Tamaño de tile: **32 px** (aprobado). Personajes de **32×48 px** por fotograma (sobresalen media casilla por arriba), 3 fotogramas por dirección en el orden abajo, izquierda, derecha y arriba.
- Arte provisional del hospital: `tools/art/gen_hospital_placeholders.py`. Al sustituirlo por arte definitivo, mantener tamaños y disposición de los PNG.
- **Mapas** (ref_06): vista cenital RPG Maker, personajes chibi de 4 direcciones y 3 frames. Texturas densas y "sucias", no limpias. Iluminación con máscara de oscuridad alrededor del jugador.
- **Combate** (ref_05): enemigo grande de frente en el centro, grupo del jugador de espaldas en primer plano, escenario con perspectiva. Los enemigos deben tener **partes del cuerpo distinguibles a simple vista**, porque son objetivos de combate.
- **Retratos y escenas ilustradas** (ref_02, ref_04): pueden tener más detalle, estilo pintado o anime oscuro, siempre con la paleta del juego. Útiles para momentos clave y finales.
- Contorno oscuro de color (azul o granate muy oscuro), no negro puro.

## Interfaz

- Sobria y funcional (ref_05): ventanas rectangulares de fondo oscuro semitransparente, borde fino claro, comandos en lista vertical a la izquierda y estado del grupo a la derecha.
- Barras finas y discretas. La idea de **dos recursos por personaje** (cuerpo y mente) es interesante para el diseño; se decide en `docs/design/`, no aquí.
- Fuente con serifa legible para menús.
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
