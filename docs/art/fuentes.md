# Fuentes

La interfaz usa **fuentes del sistema**, las de los primeros prototipos: al equipo le gusta más su
aspecto que el de las fuentes pixel que se probaron (y que se retiraron). Se definen en
`scripts/ui/ui_style.gd`, que prueba cada lista en orden:

| Uso | Función | Fuentes (en orden) |
|---|---|---|
| Menús, caja de mensajes, descripciones, botones | `ui()`, `ui_bold()` | Georgia, Times New Roman, Liberation Serif, DejaVu Serif |
| Títulos de pantalla | `pixel()` (nombre antiguo) | La misma serifa, más gruesa |
| Datos, fichas, documentos mecanografiados | `mono()` | Courier New, Liberation Mono, DejaVu Sans Mono |
| Notas a mano | `hand()` | Segoe Print, Comic Sans MS, Bradley Hand |

Para que se lean mejor que al principio:
- tamaños mínimos algo mayores (`SIZE_*`, `MONO_*`, `HAND_TEXT`); `fit_size` sube cualquier tamaño
  pequeño del código antiguo al mínimo legible;
- suavizado en escala de grises sin posición subpíxel (en la imagen ampliada no deja bordes de color)
  y hinting ligero.

Al no ir dentro del juego, el aspecto exacto depende del sistema (en Windows, Georgia y Courier New).
