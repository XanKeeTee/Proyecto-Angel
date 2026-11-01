# Sistema de combate

> Estado: `[PROPUESTA]` salvo las decisiones marcadas como **aprobadas**.
> Relacionado: [cuerpo-y-heridas.md](cuerpo-y-heridas.md) · estados (pendiente) · enemigos (pendiente) · equipamiento (pendiente)

## Decisiones aprobadas

| Tema | Decisión |
|---|---|
| Recursos | Cada combatiente tiene **Cuerpo** y **Mente** |
| Heridas | **Mixtas**: la mayoría se curan con recursos escasos; las amputaciones son permanentes salvo prótesis o rituales con coste |
| Turnos | **Por rondas**: se eligen las acciones de todo el grupo y se resuelven por velocidad |
| Grupo | **Hasta 3** personajes en combate |
| Muerte | **Permanente para todos**, protagonista incluido |
| Huida | Se puede huir **en grupo** o **solo ese personaje** |
| Cuerpo | **No se recupera solo**: solo curándose, dentro o fuera del combate |

## Objetivo del sistema

Que cada ronda sea una decisión sobre **dónde** golpear y **qué** proteger, con información suficiente para anticipar el siguiente golpe enemigo. Ganar debe costar: el jugador sale de casi todos los combates con algo dañado.

## Recursos del combatiente

| Recurso | Qué representa | Llega a 0 → |
|---|---|---|
| **Cuerpo** | Daño físico acumulado | **Caído** (ver Derrota y muerte) |
| **Mente** | Horror, miedo, desgaste psicológico | **Quiebre** (ver Mente) |

Además, cada **parte del cuerpo** tiene su propia **integridad**. Se explica en [cuerpo-y-heridas.md](cuerpo-y-heridas.md).

## Atributos

Rango 1–20. Personaje inicial típico: 5–10.

| Atributo | Abrev. | Afecta a |
|---|---|---|
| Fuerza | FUE | Daño de armas físicas |
| Destreza | DES | Acierto y crítico |
| Agilidad | AGI | Iniciativa, evasión, huida |
| Voluntad | VOL | Resistencia a daño de Mente, recuperación de Mente |
| Resistencia | RES | Resistencia a sangrado y a empeorar heridas |

Valores base: **Cuerpo 100**, **Mente 100** para el grupo del jugador. Los enemigos tienen los suyos en su recurso.

## Estructura de una ronda

1. **Intención enemiga (telegrafiado).** Cada enemigo muestra qué va a hacer: tipo de ataque, objetivo y **parte del cuerpo a la que apunta**. Ejemplo: `PREPARA UN TAJO → BRAZO IZQ. de [personaje]`. Algunos enemigos ocultan parte de la información (ver Intenciones ocultas).
2. **Órdenes.** El jugador elige una acción para cada personaje en pie.
3. **Resolución.** Todas las acciones (aliadas y enemigas) se ordenan por iniciativa y se ejecutan una a una. Si el objetivo ya no es válido (muerto, parte ya amputada), la acción se redirige según las reglas de Redirección.
4. **Fin de ronda.** Se aplican estados (sangrado, etc.), se comprueban Caídos, Quiebres y condiciones de victoria/derrota.

### Iniciativa

```
iniciativa = AGI × 2 + aleatorio_entero(0, AGI) + mod_accion + mods_estados
```

- `mod_accion`: Guardia +10, Objeto +5, ataque con arma pesada −5. El resto, 0.
- Empate: primero el jugador, luego por orden de la lista del grupo.
- Las intenciones enemigas se fijan en el paso 1; la iniciativa se tira en el paso 3.

## Acciones del jugador

| Acción | Efecto |
|---|---|
| **Atacar** | Elegir enemigo → elegir **parte del cuerpo** → ataque con el arma equipada |
| **Habilidad** | Técnica de arma, ritual u otra; puede costar Cuerpo, Mente u objetos (no hay barra de magia aparte) |
| **Guardia** | Elegir una **parte propia** o a un **aliado** que cubrir (ver Guardia) |
| **Objeto** | Usar un objeto consumible (vendas, calmantes…) |
| **Respirar** | Recupera `10 + VOL` de Mente. Ocupa la acción |
| **Huir** | Intento de huida de todo el grupo (ver Huida) |

Si un personaje no puede usar su arma (ver brazos en cuerpo-y-heridas), siempre le queda **Forcejear**: ataque débil sin arma (poder 4, contundente) con la parte que le quede.

## Fórmulas

### Acierto

```
acierto% = precision_arma + 2·DES_atacante − 2·AGI_objetivo + mod_parte + mods_estados
acierto% = clamp(acierto%, 5, 95)
```

`mod_parte` (por parte objetivo): torso **+10**, piernas **0**, brazos **−10**, cabeza **−25**. Las partes de enemigos no humanoides definen su propio `mod_parte`.

### Daño físico

```
base = poder_arma × (1 + FUE / 20) × aleatorio(0.9, 1.1)
daño_parte = max(1, round(base) − armadura_parte)
daño_cuerpo = round(daño_parte × mult_cuerpo_parte)
```

- `daño_parte` se resta de la **integridad** de la parte golpeada.
- `daño_cuerpo` se resta del **Cuerpo** global.
- `mult_cuerpo_parte`: cabeza **2.0**, torso **1.0**, brazos y piernas **0.6**.

Esto crea la decisión central: **golpear extremidades** inutiliza ataques pero mata despacio; **golpear el torso** mata más rápido; **golpear la cabeza** es arriesgado y muy rentable.

### Crítico

```
prob_critico% = DES / 2 + mod_arma_critico
```

Se tira solo si el ataque acierta. Crítico: daño × 1.5 y la herida resultante **empeora un escalón** extra (ver cuerpo-y-heridas).

### Tipos de daño

| Tipo | Efecto especial |
|---|---|
| **Cortante** | Puede **amputar** |
| **Contundente** | Rompe (fractura) pero **nunca amputa**; 25 % de **Aturdir** si golpea la cabeza |
| **Perforante** | Ignora la mitad de la armadura; 40 % de **Sangrado** |
| **Horror** | Daña la **Mente**, no el Cuerpo |

## Guardia

- **Cubrir parte propia**: esa parte recibe −50 % de daño esta ronda y **no puede ser amputada**.
- **Cubrir a un aliado**: el primer ataque dirigido a ese aliado esta ronda lo recibe quien cubre, **en la misma parte** a la que apuntaba.
- Guardia actúa con iniciativa +10, así que casi siempre se resuelve antes del golpe.

La Guardia es la respuesta directa al telegrafiado: si un enemigo anuncia `TAJO → BRAZO DER.`, cubrir ese brazo salva el arma.

## Mente

Umbrales sobre el máximo:

| Mente | Estado | Efecto |
|---|---|---|
| < 50 % | **Inquieto** | −10 acierto |
| < 25 % | **Pánico** | Al llegar su turno, 25 % de quedarse paralizado y perder la acción |
| 0 | **Quiebre** | Incapacitado hasta el final del combate. Al terminar, recibe un **trauma** (herida mental persistente; ver cuerpo-y-heridas) |

Daño a la Mente:

| Origen | Daño |
|---|---|
| Habilidad de horror enemiga | Según la habilidad; se reduce `VOL / 2` |
| Ver una **amputación** de un aliado | −10 a cada aliado consciente (−5 si VOL ≥ 12) |
| Ver **caer** a un aliado | −15 a cada aliado consciente |
| Sufrir una amputación propia | −20 |

Algunos enemigos tienen Mente (humanos) y pueden entrar en pánico; otros no (`tiene_mente = false`).

## Derrota y muerte

**Aprobado:** la muerte es **permanente para todos**, protagonista incluido.

- **Caído** (Cuerpo 0): no actúa. Sigue en el campo.
- Un personaje **Caído** que recibe otro ataque físico **muere** para siempre. Los enemigos con el rasgo `remata` eligen a propósito a los caídos; el telegrafiado lo muestra (`REMATA → [personaje]`).
- Al terminar el combate, los Caídos vuelven con **Cuerpo 1** y una herida grave en el torso. No recuperan más Cuerpo solos (ver Curación).
- **Muerte del protagonista** → fin de partida. `[PROPUESTA]`
- **Derrota**: todo el grupo Caído, en Quiebre o muerto → fin de partida (salvo combates narrativos marcados como `derrota_continua`).

## Curación

**Aprobado:** el Cuerpo **no se regenera solo**, ni al terminar el combate ni con el tiempo. Solo se recupera **curándose**:

- **En combate**: con la acción Objeto o con habilidades de curación.
- **Fuera de combate**: con objetos, tratamientos o descanso en refugios.

La integridad de las partes sigue sus propias reglas (ver [cuerpo-y-heridas.md](cuerpo-y-heridas.md)).

## Huida

**Aprobado:** al elegir Huir, el personaje decide entre **huir todos** o **huir solo él**.

### Huir todos

```
prob_huida% = clamp(50 + 3 × (AGI_media_grupo − AGI_media_enemigos), 10, 90)
```

- Si sale bien, termina el combate para todo el grupo.
- Un personaje con **las dos piernas Rotas o Amputadas** no puede huir: **se queda atrás** salvo que un aliado use su acción para cargar con él (el que carga tampoco ataca esa ronda). `[PROPUESTA]`

### Huir solo

```
prob_huida_solo% = clamp(50 + 3 × (AGI_personaje − AGI_media_enemigos), 10, 90)
```

- Si sale bien, ese personaje sale del combate; el resto sigue luchando.
- Si el resto gana o huye después, el que huyó vuelve al grupo al terminar. `[PROPUESTA]`
- Los aliados que se quedan pierden **10 de Mente** al verle marcharse (5 si VOL ≥ 12). `[PROPUESTA]`
- Imposible con las dos piernas Rotas o Amputadas.

### Común

- Huir falla en combates marcados `sin_huida`.
- Si la tirada falla, se pierde la acción.

## Intenciones ocultas

Para variar la lectura, un enemigo puede ocultar parte del telegrafiado:

- `???  → [personaje]`: se sabe a quién, no qué ni dónde.
- `TAJO → ???`: se sabe qué, no a quién.
- Personajes con la cabeza Rota ven todas las intenciones como `???`.

## Redirección

Si al resolverse una acción su objetivo ya no es válido:

1. Parte amputada → se redirige al **torso** del mismo objetivo.
2. Objetivo muerto o huido → se elige otro objetivo al azar del mismo bando, misma parte si existe; si no, torso.
3. Si no queda ningún objetivo, la acción se pierde.

## Enemigos (resumen; detalle en `enemigos.md`, pendiente)

- Cada ataque enemigo puede requerir una **parte** (`parte_requerida`). Si esa parte está Rota o Amputada, el ataque **deja de estar disponible**. Mutilar al enemigo cambia lo que puede hacer.
- Patrones: secuencia fija, condicional (por Cuerpo, por partes perdidas, por número de aliados) o mezcla. Un patrón debe poder aprenderse en 2–3 rondas.
- Hasta **4 enemigos** a la vez en pantalla.

## Recursos de datos (para implementación)

| Recurso | Campos principales |
|---|---|
| `CombatantStats` | cuerpo_max, mente_max, fue, des, agi, vol, res, tiene_mente |
| `BodyPartDef` | id, nombre, fraccion_integridad, mod_acierto, mult_cuerpo, vital, amputable, efectos por estado |
| `WeaponDef` | poder, precision, tipo_daño, manos (1/2), mod_critico, habilidades |
| `ArmorDef` | armadura por parte |
| `EnemyDef` | stats, partes (`Array[BodyPartDef]`), ataques, patrón, rasgos (`remata`, …) |
| `EnemyAttackDef` | tipo, poder, parte_objetivo, parte_requerida, visibilidad del telegrafiado |

Todos en `scripts/core/`; instancias `.tres` en `data/`.

## Balance de referencia

Ver la simulación en [cuerpo-y-heridas.md § Balance](cuerpo-y-heridas.md#balance-de-referencia).

## Preguntas abiertas

1. Si muere el protagonista, ¿fin de partida, o la historia puede seguir con otro personaje? Propuesta: fin de partida.
2. Si alguien huye solo y el resto del grupo muere, ¿qué pasa con él? ¿Sigue la partida con un superviviente?
3. ¿Las habilidades cuestan Cuerpo/Mente/objetos, o añadimos un tercer recurso? Propuesta: sin tercer recurso.
4. ¿Se ve la integridad exacta de las partes enemigas o solo su estado (Sana / Herida / Rota)? Propuesta: solo el estado.
5. ¿El orden de iniciativa de la ronda se muestra antes de confirmar órdenes?

### Resueltas

- Muerte permanente → **sí, para todos**.
- Huida → **en grupo o individual**, a elección.
- Recuperación de Cuerpo → **solo curándose**, dentro o fuera del combate.
