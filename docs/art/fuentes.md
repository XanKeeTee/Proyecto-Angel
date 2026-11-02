# Fuentes

Todas tienen licencia **SIL Open Font License 1.1** (se pueden usar, incrustar y redistribuir con el juego; no se pueden vender sueltas). Cada carpeta de `assets/fonts/` lleva su `OFL.txt`. Vienen de [google/fonts](https://github.com/google/fonts) sin modificar.

| Fuente | Archivo | Uso | Autoría |
|---|---|---|---|
| **PT Serif** (Regular y Bold) | `assets/fonts/pt_serif/` | Menús, caja de mensajes, descripciones, botones, nombres | ParaType Ltd. (2010) |
| **Courier Prime** | `assets/fonts/courier_prime/` | Datos, pistas de teclas, fichas y documentos mecanografiados | The Courier Prime Project Authors (2015) |
| **Patrick Hand** | `assets/fonts/patrick_hand/` | Notas escritas a mano | Patrick Wagesreiter (2010-2012) |
| **Pixelify Sans** | `assets/fonts/pixelify_sans/` | Títulos de pantalla («REGISTRO DE CUSTODIA», «PAUSA», «OPCIONES») | The Pixelify Sans Project Authors (2021) |

«PT Serif» es nombre reservado de la licencia: si algún día se modifica la fuente, la versión modificada tiene que llevar otro nombre.

## Cómo se ven nítidas en 640×360

- La vista se dibuja a 640×360 y se escala entera, así que el texto tiene que caer en píxeles enteros.
- Los `.import` de las fuentes llevan **antialiasing = desactivado**, **posición subpíxel = desactivada** y **hinting completo** (Pixelify Sans, sin hinting): cada letra se dibuja píxel a píxel, con un toque pixelado y sin el borroso de antes.
- Tamaños que se ven bien (constantes de `UiStyle`):

  | Fuente | Tamaños |
  |---|---|
  | PT Serif | 12 (pequeño), 13 (texto), 16 (nombres y caja de mensajes) |
  | Courier Prime | 11 (pistas), 12 (datos y documentos) |
  | Patrick Hand | 16 |
  | Pixelify Sans | 20 (su rejilla nativa: cada píxel de la letra son 2 de pantalla) |

  `UiStyle.fit_size` redondea cualquier tamaño pedido al más cercano de estos.
- Se descartaron otras fuentes pixel de google/fonts (VT323, Pixelify Sans a 10-13 px, DotGothic16, Jersey, Silkscreen…): o no tienen tamaños nativos entre 10 y 14 px y las letras se deforman (la «C» se cierra), o son solo mayúsculas.
- Ninguna trae ▶ ▼ ← →: las flechas se dibujan (`UiStyle.draw_arrow`) o se escriben con texto.
