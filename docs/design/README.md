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
| `sistemas/equipamiento.md` | Armas, armaduras, objetos |
| `sistemas/decisiones.md` | Banderas de historia, rutas y finales (lado técnico del lore) |
| `escenas/` | Diseño de escenas concretas: secuencia, textos y mecánicas. Ver [inicio-hospital.md](escenas/inicio-hospital.md) |
| `plantillas/` | Plantillas de enemigo y de sistema |
