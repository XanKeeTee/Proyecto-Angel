# GDD — La Novena Vigilia

> Esqueleto. Las secciones se rellenarán a medida que el equipo apruebe cada sistema.

## 1. Visión

- **Título**: La Novena Vigilia.
- **Género**: RPG 2D de terror y supervivencia, combate por turnos, terror analógico.
- **Protagonistas**: cinco (aportado por el equipo). El prólogo usa al paciente de la Habitación 09.
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

Exploración a oscuras con linterna de batería limitada → registrar el entorno (todo lo que tiene sentido se puede examinar, abrir o registrar) → gestionar la custodia (espacio, combinaciones, curas) → resolver obstáculos con llaves, herramientas y piezas → leer documentos que explican a medias → sucesos que inquietan sin explicar. El combate llegará después; el prólogo no lo tiene.

Primera experiencia completa: [escenas/prologo.md](escenas/prologo.md).

## 4. Protagonista personalizable

_Pendiente: qué se personaliza (nombre, aspecto, trasfondo, atributos) y qué efecto tiene._

## 5. Combate por turnos

Detalle en [sistemas/combate.md](sistemas/combate.md) y [sistemas/cuerpo-y-heridas.md](sistemas/cuerpo-y-heridas.md).

**Aprobado:** recursos **Cuerpo + Mente**; heridas **mixtas**; turnos **por rondas** resueltas por velocidad; grupo de **hasta 3**; **muerte permanente** para todos y **fin de partida si muere el protagonista**; huida **en grupo o individual**; el Cuerpo **solo se recupera curándose**; los traumas se definen **según el lore**.

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
`[PROPUESTA]` Guardia sobre una parte o un aliado como respuesta al telegrafiado; Respirar para recuperar Mente. Huir en grupo o solo (aprobado); quien no puede andar no puede huir.

## 6. Narrativa y decisiones

_Pendiente: estructura de rutas, finales, secundarios con historia propia, secretos opcionales._

## 7. Progresión

_Pendiente._

## 8. Exploración y mapa

**Aprobado:** tiles de **32 px**. Movimiento libre en cualquier ángulo (8 orientaciones de sprite), linterna con batería, oscuridad casi total.

Vista cenital estilo RPG Maker con paredes de 3 casillas y proporciones realistas. Primera zona: [escenas/prologo.md](escenas/prologo.md).

## 9. Interfaz

- **Sistema de Custodia** (inventario, al estilo de *Fear & Hunger*): lista por categorías sin límite de espacio, pantalla de equipo con ranuras y estadísticas, atajos 1-5 y expediente personal. Ver [sistemas/custodia.md](sistemas/custodia.md).
- HUD mínimo: indicador de interacción, atajos, batería y avisos breves; se esconde solo.

## 10. Alcance y prioridades

_Pendiente: qué entra en el primer prototipo jugable (vertical slice)._

## Preguntas abiertas

-
