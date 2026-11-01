# GDD — Proyecto-Angel

> Esqueleto. Las secciones se rellenarán a medida que el equipo apruebe cada sistema.

## 1. Visión

- **Género**: JRPG 2D por turnos, terror analógico.
- **Motor**: Godot 4.7.2, GDScript.
- **Estilo**: pixel art tipo RPG Maker con tratamiento VHS (ver `docs/art/guia-estetica.md`).
- **Premisa temática (aprobada)**: la humanidad recibió un milagro y lo convirtió en herramienta de explotación, en un futuro postapocalíptico donde se juega a ser Dios con experimentos, tecnología y rituales.

## 2. Pilares

1. Combate táctico donde importa **dónde** golpeas.
2. Mutilación y heridas con consecuencias permanentes.
3. Enemigos con patrones legibles.
4. Decisiones con coste que llevan a rutas y finales distintos.
5. Terror por desgaste y pérdida.

## 3. Bucle de juego

_Pendiente._

## 4. Protagonista personalizable

_Pendiente: qué se personaliza (nombre, aspecto, trasfondo, atributos) y qué efecto tiene._

## 5. Combate por turnos

Detalle en [sistemas/combate.md](sistemas/combate.md) y [sistemas/cuerpo-y-heridas.md](sistemas/cuerpo-y-heridas.md).

**Aprobado:** recursos **Cuerpo + Mente**; heridas **mixtas**; turnos **por rondas** resueltas por velocidad; grupo de **hasta 3**.

### 5.1 Selección de partes del cuerpo
`[PROPUESTA]` Al atacar se elige enemigo y parte. Cabeza: difícil de acertar, mucho daño. Torso: fácil, daño normal. Extremidades: poco daño, pero inutilizan ataques.

### 5.2 Mutilación y heridas permanentes
`[PROPUESTA]` Cada parte pasa por Sana → Herida → Rota → Amputada (solo con daño cortante). Las amputaciones son permanentes salvo prótesis o rituales con coste.

### 5.3 Estados alterados
_Pendiente (`sistemas/estados.md`)._ Ya usados: Sangrado, Aturdido, Inquieto, Pánico, Quiebre.

### 5.4 Patrones de ataque enemigos
`[PROPUESTA]` Telegrafiado al inicio de cada ronda (qué, a quién y a qué parte). Mutilar a un enemigo le quita los ataques que dependen de esa parte. Detalle pendiente (`sistemas/enemigos.md`).

### 5.5 Armas y equipamiento
_Pendiente (`sistemas/equipamiento.md`)._ Tipos de daño: cortante, contundente, perforante, horror.

### 5.6 Decisiones tácticas
`[PROPUESTA]` Guardia sobre una parte o un aliado como respuesta al telegrafiado; Respirar para recuperar Mente; huir puede dejar atrás a quien no puede andar.

## 6. Narrativa y decisiones

_Pendiente: estructura de rutas, finales, secundarios con historia propia, secretos opcionales._

## 7. Progresión

_Pendiente._

## 8. Exploración y mapa

_Pendiente._

## 9. Interfaz

_Pendiente._

## 10. Alcance y prioridades

_Pendiente: qué entra en el primer prototipo jugable (vertical slice)._

## Preguntas abiertas

-
