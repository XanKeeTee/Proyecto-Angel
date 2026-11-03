# Cuerpo, mutilación y heridas

> Estado: `[PROPUESTA]` salvo lo indicado como **aprobado**.
> Relacionado: [combate.md](combate.md)

**Aprobado:** las heridas son **mixtas**. La mayoría se curan con recursos escasos o descanso; las amputaciones son permanentes salvo prótesis o rituales con coste.

## Partes del cuerpo (humanoide)

| Parte | Integridad (fracción de Cuerpo máx.) | Con Cuerpo 100 | `mod_acierto` | `mult_cuerpo` | Vital | Amputable |
|---|---|---|---|---|---|---|
| Cabeza | 0.25 | 25 | −25 | 2.0 | Sí | Solo enemigos (decapitación = muerte) |
| Torso | 0.50 | 50 | +10 | 1.0 | Sí | No |
| Brazo izq. / der. | 0.30 | 30 | −10 | 0.6 | No | Sí |
| Pierna izq. / der. | 0.35 | 35 | 0 | 0.6 | No | Sí |

Cada personaje tiene un **brazo dominante** (por defecto, el derecho). El arma de una mano va en él.

Los enemigos no humanoides definen sus propias partes con los mismos campos (por ejemplo, un halo, un ala o un tubo), y sus efectos propios.

## Estados de una parte

```
SANA ──(integridad ≤ 50 %)──► HERIDA ──(integridad ≤ 0)──► ROTA ──(corte)──► AMPUTADA
```

| Estado | Condición |
|---|---|
| **Sana** | integridad > 50 % |
| **Herida** | 0 < integridad ≤ 50 % |
| **Rota** | integridad = 0 (no baja de 0) |
| **Amputada** | ver Amputación |

Una parte **Rota** sigue pudiendo recibir golpes: no pierde más integridad, pero el daño al Cuerpo se aplica igual.

### Amputación

Solo con daño **cortante** y en partes **amputables** (y, a golpes, en las partes `severable_by_blunt` ya Rotas). Se amputa si se cumple una de estas condiciones:

1. El golpe deja la parte a 0 y el **exceso** de daño es ≥ 25 % de su integridad máxima.
2. La parte ya estaba **Rota** y el golpe hace ≥ 25 % de su integridad máxima.
3. Un **crítico** rompe la parte (el crítico sube un escalón extra).

**Tirada de Resistencia:** antes de amputar, el objetivo tiene `min(RES × 2, 40) %` de evitarlo (se queda en Rota).

Tras una amputación, los ataques dirigidos a esa parte se **redirigen al torso**.

## Efectos por parte y estado

| Parte | Herida | Rota | Amputada |
|---|---|---|---|
| **Brazo dominante** | −10 acierto y −15 % de daño con su arma | El arma de una mano pasa a la otra (**mano torpe**: −15 acierto, −25 % daño), o usa la de la otra mano | El arma **se cae**: Forcejear o la de la otra mano; permanente |
| **Brazo no dominante** | −5 acierto con armas a dos manos | No puede usar armas a dos manos | Igual que Rota, permanente |
| **Ambos brazos** Rotos/Amputados | — | Solo Forcejear; **no puede usar Objetos** (un aliado sí puede usarlos en él) | Igual, permanente |
| **Pierna** (una) | AGI −20 %; −5 a huir | AGI −50 %; −15 a huir | AGI −50 %, −15 a huir, permanente |
| **Ambas piernas** Rotas/Amputadas | — | AGI cuenta como 0; no puede huir; está en el suelo (se le puede rematar) | Igual, permanente |
| **Cabeza** | −10 acierto; −2 Mente por ronda | −25 acierto; −5 Mente por ronda; ve las intenciones enemigas como `???`; **Aturdido** al romperse | Solo enemigos: muerte |
| **Torso** | Sangrado: +20 % de probabilidad al recibir golpes | Cada acción propia cuesta 3 de Cuerpo | No amputable |

Los penalizadores se suman. AGI nunca baja de 0. Los **analgésicos** los anulan mientras duran. Detalle de empuñar con heridas, sangrado por partes y cómo se tratan en combate: [combate.md](combate.md#empuñar-con-heridas-combatantgrip). `[PROPUESTA]`

## Después del combate (heridas mixtas)

| Estado | ¿Persiste? | Cómo se cura | Rareza del remedio |
|---|---|---|---|
| **Sana** | La integridad vuelve al máximo | — | — |
| **Herida** | Sí; integridad limitada al 50 % | Vendas, o descanso en un refugio | Común |
| **Rota** | Sí; integridad a 0 | Férula o cirugía, o descanso largo en un refugio | Raro |
| **Amputada** | **Permanente** | **Prótesis** o **ritual** | Muy raro / con coste |

**Aprobado:** el **Cuerpo global no se regenera solo**. Solo se recupera curándose, dentro del combate (objetos, habilidades) o fuera (objetos, tratamientos, descanso en refugios).

### Prótesis

- Es un **equipo** que ocupa la ranura de la parte amputada.
- Devuelve la función, pero con contrapartidas. Ejemplos: brazo mecánico (permite armas, −5 acierto, +2 armadura en esa parte); pierna de soporte (AGI −20 % en lugar de −50 %).
- Puede romperse en combate como una parte más; se repara, no se cura.

### Rituales

- Devuelven la parte original, con un **coste permanente**: por ejemplo, −15 de Mente máxima o un trauma.
- Su forma concreta depende del lore (pendiente en `docs/lore/`). Encaja con la idea central: el milagro como herramienta y su precio.

### Infección (opcional)

Una parte Herida o Rota que no se trata en **3 combates** se **infecta**: −10 % de Cuerpo máximo hasta que se trate. Pendiente de decidir si entra.

## Traumas (heridas de la Mente)

- Se reciben al llegar a **Quiebre** (Mente 0) en un combate.
- Son persistentes y se curan con **eventos narrativos** o en refugios, nunca con objetos comunes.
- **Aprobado:** los tipos de trauma y sus consecuencias **dependen del lore** y se irán definiendo y revisando durante el desarrollo.
- Ejemplos provisionales de efecto, solo para prototipar: −5 acierto permanente (temblor); doble daño de Mente al ver sangre; el descanso recupera la mitad.
- Qué pasa al acumular traumas: pendiente del lore.

## Reglas contra bloqueos

1. **Forcejear** está siempre disponible: nadie se queda sin acción.
2. En el **primer refugio** hay siempre una prótesis básica de brazo y otra de pierna, a cambio de recursos, no de progreso de historia.
3. El juego debe poder terminarse con **cualquier combinación** de amputaciones. Los combates obligatorios se prueban con un grupo muy mutilado.
4. Ningún objeto clave de historia exige una parte concreta del cuerpo.

## Balance de referencia

Simulación Monte Carlo (20 000 combates) con las fórmulas de [combate.md](combate.md). Script: `tools/balance/sim_combate.py`.

Atacante FUE 8, DES 8, arma cortante de poder 12 y precisión 75. Objetivo AGI 8, RES 8, armadura 2, Cuerpo 100. Se cuentan **ataques** necesarios (no rondas). Se ataca siempre a la misma parte; si se amputa, se redirige al torso.

| Apuntando a | Romper | Amputar | Derribar (Cuerpo 0) |
|---|---|---|---|
| Cabeza | 4.0 (2–7) | — | 7.8 (5–12) |
| Torso | 4.6 (4–6) | — | 8.2 (7–10) |
| Brazo | 3.8 (2–6) | 4.8 (3–7) | 10.9 (9–14) |
| Pierna | 3.9 (3–5) | 4.6 (3–7) | 10.5 (8–13) |

Media (percentil 10 – percentil 90).

Otros casos:
- Arma **contundente** apuntando a un brazo hasta derribar: 17.7 ataques. Insistir en una parte ya Rota es ineficiente; hay que cambiar de objetivo.
- Enemigo duro (Cuerpo 180, armadura 4) por el torso: 16.7 ataques.

Lectura, con un grupo de 3:
- Un enemigo común cae en **3–4 rondas** si se va a por el cuerpo, o se le **desarma en 1–2** si se va a por un brazo.
- La cabeza es la apuesta: de media mata antes, pero con mucha varianza.
- El torso es lo seguro.
- Las extremidades no matan, pero quitan ataques al enemigo.

Ajuste del multiplicador de la cabeza: con 1.5, apuntar a la cabeza era peor que al torso en todo (9.8 ataques), así que se subió a **2.0**.

## Preguntas abiertas

1. ¿Entra la infección?
2. ¿Puede el jugador elegir el brazo dominante al crear al protagonista?
3. ¿Se muestran las heridas en el sprite de mapa (vendas, prótesis) o solo en el menú?

### Resueltas

- Recuperación de Cuerpo → **no se recupera solo**; solo curándose, dentro o fuera del combate.
- Traumas → **según el lore**; se revisan durante el desarrollo.
