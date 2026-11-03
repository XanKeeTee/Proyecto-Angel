# Diseño — Proyecto-Angel

Documentación de sistemas de juego. El documento principal es el [GDD](gdd.md).

## Convenciones

- Cada sistema grande tiene su propio archivo en `sistemas/` y una sección resumen en el GDD.
- Todo valor numérico indica **dónde vive** (qué `Resource` y qué campo en `data/`), su valor inicial y su rango razonable.
- Las fórmulas se escriben exactas, sin ambigüedad, para que se puedan implementar y testear.
- Las dudas se dejan en una sección **Preguntas abiertas** al final de cada documento.
- Lo que aún no está aprobado se marca `[PROPUESTA]`.

## Estructura prevista

| Archivo | Contenido |
|---|---|
| `gdd.md` | Visión general y resumen de todos los sistemas |
| `sistemas/combate.md` | Turnos, acciones, orden de iniciativa |
| `sistemas/cuerpo-y-heridas.md` | Partes del cuerpo, mutilación, heridas permanentes |
| `sistemas/estados.md` | Estados alterados |
| `sistemas/enemigos.md` | Patrones de ataque y telegrafiado |
| `sistemas/custodia.md` | Sistema de Custodia: inventario, objetos, combinaciones |
| `sistemas/equipamiento.md` | Armas, armaduras |
| `sistemas/decisiones.md` | Banderas de historia, rutas y finales (lado técnico del lore) |
| `enemigos/` | Un archivo por enemigo (plantilla en `plantillas/enemigo.md`). Ver [el enfermero](enemigos/enfermero.md) |
| `escenas/` | Diseño de escenas concretas: secuencia, textos y mecánicas. Ver [prologo.md](escenas/prologo.md) |
| `plantillas/` | Plantillas de enemigo y de sistema |
