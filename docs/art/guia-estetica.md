# Guía estética — Proyecto-Angel

> Versión inicial, escrita a partir de la descripción de las referencias. Las imágenes de referencia deben guardarse en [`referencias/`](referencias/) y citarse aquí por nombre de archivo. Revisar esta guía cuando estén subidas.

## Sensación general

Terror analógico. Algo sagrado tratado como material industrial. La pantalla parece una cinta VHS vieja grabada en un lugar donde no debería haber cámaras. Frío, silencioso, clínico, con destellos de carne.

Palabras clave: **noche, hueso, carne, óxido, cable, halo, cinta.**

## Paleta

Dos polos y un neutro. Pocos colores por escena; el contraste hace el trabajo.

| Rol | Descripción | Uso | Valores orientativos |
|---|---|---|---|
| **Azul noche** | Azul profundo casi negro, cielo estrellado | Fondos, exteriores, lo distante y sagrado | `#0B1026` `#16204A` `#2C3E7A` |
| **Granate / carne** | Rojo oscuro saturado, tonos de víscera y sangre seca | Interiores de carne, heridas, interfaz de daño, lo humano y lo profanado | `#3A0A12` `#6E1423` `#A33A3A` |
| **Blanco hueso** | Blanco sucio, ligeramente cálido | Máscaras, halos, texto, puntos focales | `#E8E1D3` `#BFB6A3` |
| **Óxido / máquina** | Grises verdosos y marrones apagados | Maquinaria, metal quirúrgico, cables | `#3B3A36` `#5E574C` `#7A6A4F` |
| **Acento** | Muy limitado: un ámbar enfermizo o un cian de monitor | Luces de máquinas, peligro, interacción | `#C9A04A` / `#5FB8B0` |

> Los valores hex son punto de partida, no canon visual. Se fijarán con una paleta `.gpl`/`.hex` en `assets/` cuando se produzca el primer arte.

Reglas:
- Una escena es **predominantemente azul** o **predominantemente granate**. Mezclar ambos a partes iguales se reserva para momentos clave.
- El blanco hueso es lo más claro de la pantalla: dirige la mirada. No abusar.
- Negro puro solo para siluetas y vacío (ojos huecos).

## Motivos visuales

- **Máscaras pálidas con ojos huecos**: rostros sin expresión, blanco hueso, cuencas negras. Nunca se ve lo que hay detrás.
- **Ángeles rotos**: halos agrietados o incompletos, alas sucias, desplumadas, atadas o cosidas. Lo divino aparece **dañado y manipulado**, nunca glorioso.
- **Maquinaria industrial y quirúrgica**: camillas, pinzas, tubos, bombas, tanques, engranajes. Metal frío junto a carne.
- **Cables**: conectan cuerpos con máquinas, cuelgan del techo, salen de heridas. Elemento recurrente de composición.
- **Iconografía religiosa reutilizada** como herramienta: altares convertidos en mesas de trabajo, vidrieras como paneles.

> Recordatorio de lore: nada de ángeles usados literalmente como batería de una máquina (ver `docs/lore/README.md`). La imagen puede sugerir explotación de lo sagrado, pero la premisa concreta es nuestra.

## Pixel art (estilo RPG Maker)

- Resolución base del juego: **640×360** con escalado entero (provisional, ver `docs/tech/README.md`).
- Tamaño de tile: **pendiente** de decisión.
- Personajes de mapa: chibi de proporción RPG Maker (cabeza grande), 4 direcciones, 3 frames de caminar.
- Enemigos de combate: más grandes y detallados que los sprites de mapa, vista frontal, con **partes del cuerpo distinguibles a simple vista** (son objetivos de combate).
- Retratos de diálogo: más detalle y textura, mismo tratamiento de paleta.
- Contorno: oscuro y de color (azul o granate muy oscuro), no negro puro.
- Sin antialiasing contra el fondo; sombreado con pocas rampas de color.

## Tratamiento analógico (post-procesado)

Se aplica en pantalla completa; lo implementa el subagente `shader-fx`.

| Efecto | Intensidad base | Notas |
|---|---|---|
| Grano VHS | Baja, siempre presente | Ruido animado, no estático |
| Aberración cromática | Baja; sube en momentos de tensión | Desplazamiento horizontal R/B |
| Scanlines / CRT | Sutil | Sin moiré al escalar |
| Viñeta | Media | Oscurece bordes |
| Distorsión / tracking | Solo en eventos | Bandas horizontales, saltos de imagen |
| Desaturación | Variable por escena | |

Accesibilidad: todos los efectos tienen opción para reducirlos o desactivarlos; nada de destellos rápidos sin aviso.

## Tipografía y texto en pantalla

- **Subtítulos cortos en mayúsculas**, con punto final, como sellos: `NOT CRY.` `HOST.`
- Frases de una a tres palabras para los momentos de impacto. El texto largo va en cajas de diálogo normales.
- Fuente bitmap pixel, sin serifa o con serifa mínima; blanco hueso sobre negro/azul noche, con ligera aberración cromática en los textos de impacto.
- Interfaz de combate: sobria, marcos finos, iconos de partes del cuerpo claros. La legibilidad manda sobre el efecto.

## Lo que evitamos

- Gore detallado de alta resolución que rompa el pixel art: la mutilación se comunica con silueta, color y animación breve.
- Colores saturados alegres, degradados limpios, brillo "épico".
- Ángeles bellos e intactos.
- Copiar composiciones, personajes o interfaz concretos de *Angel Engine*.
