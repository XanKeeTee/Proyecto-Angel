# Sistema de combate

> Estado: `[PROPUESTA]` salvo las decisiones marcadas como **aprobadas**.
> Relacionado: [cuerpo-y-heridas.md](cuerpo-y-heridas.md) · [el enfermero](../enemigos/enfermero.md) (primer enemigo) · equipamiento (pendiente)
>
> Código: reglas en `scripts/systems/combat/` (`Battle`, `Combatant`, `EnemyAI`, `CombatRules`, `CombatBridge`, `EncounterDirector`; opciones del menú en `BattleMenu` y `BattlePreview`), datos en `scripts/core/*def.gd`, `scripts/core/combat/` (`SkillDef`, `TreatmentDef`, `DamageTypeDef`, `AttackBonus`) y `data/{enemies,party,body_parts,weapons,statuses,skills,treatments,damage_types}/`, pantalla en `scenes/battle/`.
>
> Generadores: `tools/data/build_combat_rules.gd` (estados, tipos de daño, habilidades y tratamientos) y después `tools/data/build_enemies.gd` (enfermero, paciente 09, encuentro). Balance: `tools/balance/sim_enfermero.gd`.

## Decisiones aprobadas

| Tema | Decisión |
|---|---|
| Recursos | Cada combatiente tiene **Cuerpo** y **Mente** |
| Heridas | **Mixtas**: la mayoría se curan con recursos escasos; las amputaciones son permanentes salvo prótesis o rituales con coste |
| Turnos | **Por rondas**: se eligen las acciones de todo el grupo y se resuelven por velocidad |
| Grupo | **Hasta 3** personajes en combate |
| Muerte | **Permanente para todos**, protagonista incluido. **Si muere el protagonista, fin de partida** |
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

- `mod_accion`: Objeto +5, ataque con arma de dos manos −5, y el de cada habilidad (Empujón +12, Golpe a la rodilla −10). El resto, 0. La Guardia no tira: va siempre antes que todo.
- Empate: primero el jugador, luego por orden de la lista del grupo.
- Las intenciones enemigas se fijan en el paso 1; la iniciativa se tira en el paso 3.

## Acciones del jugador

| Acción | Efecto |
|---|---|
| **Atacar** | Elegir enemigo → elegir **parte del cuerpo** → ataque con el arma equipada |
| **Habilidad** | Técnica de arma o recurso del cuerpo (ver Habilidades); cuesta Cuerpo o Mente (no hay barra aparte) |
| **Guardia** | Elegir una **parte propia** o a un **aliado** que cubrir (ver Guardia) |
| **Objeto** | Tratar una herida o tomar algo (ver Tratar heridas en combate) |
| **Respirar** | (Habilidad) Recupera `10 + VOL` de Mente. Ocupa la acción |
| **Levantarse / Recobrarse** | Lo único que queda si está **derribado** o **aturdido**: pierde la acción (derribado aún puede **encogerse**: Guardia) |
| **Zafarse** | Solo si le **sujetan** (estado Agarrado). Ver Estados `[PROPUESTA]` |
| **Huir** | Intento de huida de todo el grupo (ver Huida) |

En el juego, **Objeto** usa lo que lleva el personaje en la Custodia. Si el objeto tiene tratamiento de combate (`TreatmentDef`) se aplica **por partes**; si no, con sus efectos de siempre (`CombatBridge.use_item`). El prototipo sin mapa y el simulador usan un inventario de prueba (`Battle.supplies`).

Si un personaje no puede usar su arma (ver Empuñar con heridas), siempre le queda **Forcejear**: ataque débil sin arma (poder 4, contundente) con la parte que le quede.

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

### Tipos de daño `[PROPUESTA]`

Cada tipo hace algo distinto según **dónde** golpea (`DamageTypeDef`, `data/damage_types/`). El multiplicador de integridad solo cambia cuánto se rompe la parte, no el daño al Cuerpo.

| Tipo | Integridad (extremidad / cabeza / torso) | Armadura | Sangrado por golpe | Efecto por parte |
|---|---|---|---|---|
| **Contundente** | ×1,25 / ×1,2 / ×1 | entera | — | **Rompe huesos**. Cabeza: 25 % de **aturdir** (y siempre al romperla). Pierna que se rompe: 60 % de **derribar**. **Nunca amputa** (salvo partes `severable_by_blunt`) |
| **Cortante** | ×1 / ×1 / ×0,9 | entera | 30 % | **Sangra** y **amputa** lo que ya está roto. Pierna que se rompe o se amputa: 30 % de derribar |
| **Punzante** | ×0,75 / ×0,85 / ×0,8 | **mitad** | 30 % (si hace ≥ 7) | Rompe poco. **Torso**: 25 % de **alcanzar un órgano** (si hace ≥ 7): daño al Cuerpo ×1,6 y una acumulación más de sangrado |
| **Horror** | — | — | — | Daña la **Mente**, no el Cuerpo |

Con el torso Herido o Roto, los golpes cortantes y punzantes tienen +20 % de hacer sangrar.

Un ataque físico enemigo puede restar también Mente si acierta (`EnemyAttackDef.mind_damage`, reducido en VOL/2). `[PROPUESTA]`

**Amputación que sangra** `[PROPUESTA]`: perder un miembro (no vital) deja el **muñón** con 2 acumulaciones de **Sangrado**.

### Sangrado por partes `[PROPUESTA]`

El sangrado va **por parte** (`BodyPartState.bleeding`, máx. 3 acumulaciones cada una). Al final de cada ronda:

- cada acumulación resta **3 de Cuerpo**;
- cada parte que sangra puede **coagular** (pierde una acumulación) con `35 % + 2,5 % × RES` (RES 8: 55 %); **Rota**, la mitad; un **muñón** (Amputada) **nunca**: hace falta torniquete o venda.

Los enemigos huelen la sangre (ver IA). Al volver al mapa, si alguna parte sangra, el personaje sale sangrando (`Vitals.bleeding`); el sangrado del mapa entra en el combate en el torso (los puntos de la espalda).

**Partes que se arrancan a golpes** `[PROPUESTA]`: una parte marcada `severable_by_blunt` (carne fundida con metal, tejido muerto) se amputa con daño contundente si ya estaba **Rota** y el golpe hace ≥ 25 % de su integridad (con la misma tirada de Resistencia). Solo la tiene el brazo de instrumental del enfermero.

## Armas `[PROPUESTA]`

Un arma (`WeaponDef`) tiene poder, precisión, crítico, **tipo de daño**, **manos** (una o dos) y **alcance** (corto, medio, largo). El tipo decide qué hace en cada parte; el alcance y las manos, qué **habilidades** permite.

| Arma | Poder · precisión · crítico | Tipo | Manos | Alcance |
|---|---|---|---|---|
| Tubo de hierro | 12 · 70 · +0 | Contundente | Una | Medio |
| Tubo con mango envuelto | 12 · 78 · +2 | Contundente | Una | Medio |
| Barra | 14 · 70 · +0 | Contundente | Dos | Largo |
| Palanca | 13 · 65 · +0 | Contundente | Dos | Largo |
| Cuchilla | 12 · 75 · +0 | Cortante | Una | Corto |
| Bisturí | 8 · 85 · +10 | Cortante | Una | Corto |
| Punzón | 10 · 80 · +5 | Punzante | Una | Corto |
| (sin arma) Forcejear | 4 · 70 · +0 | Contundente | — | Corto |

**Mano izquierda** (`CharacterState.wield_offhand`, `CombatantDef.offhand_weapon`): un arma de una mano en la mano no dominante. Da una segunda forma de atacar (−10 acierto) y sus habilidades (con el tubo en la derecha y el bisturí en la izquierda se puede **clavar**).

### Empuñar con heridas (`Combatant.grip()`)

| Situación | Qué pasa |
|---|---|
| Brazo que sostiene el arma **Herido** | −10 acierto y −15 % de daño |
| Brazo de apoyo Herido (arma de dos manos) | −5 acierto |
| Brazo dominante **Roto** | Un arma de una mano pasa a la otra mano: **mano torpe**, −15 acierto y −25 % de daño. Si lleva otra arma en la izquierda, pelea con esa |
| Brazo dominante **Amputado** | El arma **se cae**: queda la de la izquierda o Forcejear |
| Arma de **dos manos** con un brazo inútil | No puede: Forcejear |
| Los dos brazos inútiles | Forcejear (con lo que quede) y Morder; no puede usar objetos |

Las demás mutilaciones del protagonista: **pierna** Herida −20 % AGI y −5 a huir; Rota o Amputada −50 % AGI y **−15 a huir** (las dos: no huye ni se mantiene en pie); **cabeza** Herida −10 acierto y **−2 Mente por ronda**, Rota −25 acierto, −5 Mente por ronda y no lee intenciones; **torso** Roto, cada acción cuesta 3 de Cuerpo. Los **analgésicos** anulan los penalizadores de heridas mientras duran.

## Habilidades `[PROPUESTA]`

Datos en `data/skills/` (`SkillDef`): coste en **Cuerpo** (esfuerzo) o **Mente** (nervio), recarga, requisitos (arma de cierto alcance y tipo, brazos útiles, cabeza útil, estar de pie, estado del objetivo) y efectos (golpe con el arma o propio, partes permitidas, estado que aplica, sangrado extra, órgano, iniciativa). El menú solo enseña las que permite el arma que se lleva; las que no se pueden usar por una herida, el coste o la recarga salen apagadas **con su motivo**.

| Habilidad | Requisitos | Coste · recarga | Efecto |
|---|---|---|---|
| **Golpe a la rodilla** | Arma contundente de alcance medio o largo, de pie | 2 Mente · 1 | Solo piernas. Poder ×1,3. **Lento** (−10 iniciativa). 50 % de **derribar** si acierta (+30 % si la pierna ya estaba herida). Como suele llegar después de su golpe, el derribado pierde la acción **de la ronda siguiente** y queda a merced de un remate |
| **Barrido** | Arma contundente media o larga, de pie | 3 Cuerpo · 2 | Golpea **las dos piernas** (poder ×0,55, −10 acierto); 50 % de derribar si entran los dos golpes (la mitad si entra uno) |
| **Empujón** | Arma media o larga, **los dos brazos**, de pie; el objetivo de pie | 2 Cuerpo · 2 | No hace daño. **Rápido** (+12 iniciativa). Acierto 80 + 3 × (FUE propia − FUE ajena). Aplica **Apartado**: si aún no había actuado, **pierde su golpe**; y suelta a quien sujetaba |
| **Rematar** | El objetivo **en el suelo** (derribado o arrastrándose), de pie | 6 Mente · — | Cabeza o torso. Poder ×1,5, +10 acierto, +20 crítico. «Es atroz, y lo sabes» |
| **Forcejear** | Mano libre o arma corta, un brazo útil | 2 Cuerpo · 1 | Poder 2. Acierto 70 + 3 × diferencia de FUE. Le **agarras** (Agarrado: esquiva la mitad y se le acierta +20). Si te tenía agarrado, **le das la vuelta** |
| **Morder** | Cabeza útil (sin manos) | 4 Mente · — | Punzante, poder 6, acierto 60 (+25 si uno sujeta al otro). Una acumulación de sangrado extra |
| **Clavar** | Arma corta cortante o punzante | 3 Mente · 1 | Punzante con el filo: poder ×1,3, −10 acierto, sangrado extra y +20 % de alcanzar un órgano |
| **Respirar** | Tener Mente | — | +`10 + VOL` Mente |

## Tratar heridas en combate `[PROPUESTA]`

La acción **Objeto** aplica el tratamiento del objeto (`TreatmentDef`, `data/treatments/`) **sobre una parte**, propia o de un aliado, y gasta una unidad de la custodia (`EventBus.item_used`). Los objetos son los de siempre; esto solo dice qué hacen en la pelea.

| Tratamiento | Objetos | Parte | Efecto |
|---|---|---|---|
| **Vendar** | Venda | Herida o que sangra | −2 sangrado en esa parte, +25 % de integridad (una Herida puede **cerrarse**), +4 Cuerpo |
| **Vendar con gasa limpia** | Venda esterilizada | Herida o que sangra | −3 sangrado, +40 % integridad, +12 Cuerpo |
| **Vendar con tela sucia** | Venda usada, venda improvisada | Herida o que sangra | −2 sangrado, +15 % integridad, +2 Cuerpo; si está sucia, −3 Cuerpo y −3 Mente |
| **Torniquete** | Torniquete | Brazo o pierna que sangra | Corta **todo** el sangrado de esa extremidad, también un **muñón**, y ya no vuelve a sangrar en el combate |
| **Analgésicos** | Analgésicos | — | +6 Cuerpo y **Analgesia** 3 rondas |
| **Sedante** | Sedante preparado | — | +25 Mente, quita **Aterrado** y aplica **Sedación** 2 rondas (embota: es el precio) |

Una parte **Rota** no se arregla en combate (férula o cirugía, fuera). Los objetos de cura sin tratamiento propio siguen funcionando con sus efectos de siempre.

## Guardia

- **Cubrir parte propia**: esa parte recibe −50 % de daño esta ronda y **no puede ser amputada**.
- **Cubrir a un aliado**: el primer ataque dirigido a ese aliado esta ronda lo recibe quien cubre, **en la misma parte** a la que apuntaba.
- La Guardia se aplica **siempre al principio** de la resolución, antes de cualquier ataque. `[PROPUESTA]` (antes: iniciativa +10; se simplificó en el prototipo porque una guardia que llega tarde se siente injusta).

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
- **Muerte del protagonista** → **fin de partida** (aprobado). La partida depende solo de que el protagonista siga vivo.
- **Derrota en combate**: todos los que siguen en el combate están Caídos, en Quiebre o muertos. Lo que pasa después depende de dónde esté el protagonista:
  - **El protagonista está en el combate** → fin de partida (salvo combates narrativos marcados como `derrota_continua`).
  - **El protagonista huyó solo** → la partida **sigue** con él. Los que murieron se pierden (aprobado). Los que quedaron Caídos o en Quiebre al perder el combate también mueren. `[PROPUESTA]`

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

Aprobado:

- Si sale bien, ese personaje **queda fuera del combate** y el jugador **sigue peleando** con los que quedan. Esto vale también si el que huye es el **protagonista**: el combate continúa con el resto del grupo, bajo control del jugador.
- Si los que quedan **ganan** (o huyen después), los que sigan vivos sobreviven y el que huyó vuelve al grupo.
- Si los que quedan **mueren**, se pierden para siempre.
- Si quien huyó **no es el protagonista**, el protagonista sigue en el combate: si muere, **fin de partida**.
- Si quien huyó **es el protagonista**, la partida sigue con él aunque muera el resto.
- Los aliados que se quedan pierden **10 de Mente** al verle marcharse (5 si VOL ≥ 12). `[PROPUESTA]`
- Imposible con las dos piernas Rotas o Amputadas.

### Común

- Huir falla en combates marcados `sin_huida`.
- Si la tirada falla, se pierde la acción.

## Estados `[PROPUESTA]`

Temporales, como datos (`CombatStatusDef`, en `data/statuses/`). Duran unas rondas contando la ronda en que se aplican y se descuentan al final de cada ronda. Los aplican ataques enemigos (`inflicts_status`), habilidades, tratamientos y las propias reglas.

| Campo | Qué hace |
|---|---|
| `agility_mult` | Multiplica la AGI efectiva (iniciativa, evasión, huida) |
| `accuracy_mod` | Suma al acierto de quien lo sufre |
| `incoming_hit_mod` | Suma al acierto de quien le ataca |
| `skip_chance` | Probabilidad de perder la acción, cada vez |
| `loses_next_action` | Pierde **su siguiente acción**, una vez; después dura solo hasta el final de esa ronda. Perder una acción cumple a la vez todos los estados así (no se encadenan) |
| `allows_guard` | Aun así puede cubrirse (derribado: se encoge) |
| `blocks_flee` | No puede huir |
| `breakable` | Se rompe con **Zafarse**: `45 + 5 × (FUE propia − FUE de quien sujeta)` %, entre 15 y 90. También se suelta si a quien sujeta se le rompe la parte con la que sujeta, cae, muere o le tiran al suelo |
| `breaks_holds` | Al aplicarse, quien lo sufre suelta a quien sujetaba |
| `ignores_wound_penalties` | Sin penalizadores por heridas (analgesia) |
| `suppresses` / `removes` | Anula los efectos de otros estados mientras dura / los quita al aplicarse |

| Estado | Rondas | Efecto | Lo aplica |
|---|---|---|---|
| **Agarrado** | 2 | No huye; AGI ×0,5; se le acierta +20. Se rompe con Zafarse | Agarrar del enfermero; Forcejear |
| **Sedación** | 2 | AGI ×0,6; −10 acierto; 15 % de perder la acción; **embota el terror** | Pinchazo; el sedante |
| **Aturdido** | 2 | Pierde su siguiente acción; se le acierta +10 | Romper la cabeza; contundente en la cabeza (25 %) |
| **Derribado** | 2 | Pierde su siguiente acción **levantándose**; AGI ×0,5; se le acierta +20; no huye; suelta lo que sujetaba; **se le puede rematar**. Aún puede encogerse (Guardia) | Golpe a la rodilla, Barrido, Embestida (30 %), romper una pierna |
| **Apartado** | 1 | Si aún no había actuado esta ronda, **pierde su golpe**; suelta lo que sujetaba | Empujón |
| **Aterrado** | mientras dure | 25 % de perder la acción. Se pasa al subir la Mente del 25 % | La Mente por debajo del 25 % |
| **Analgesia** | 3 | Sin penalizadores por heridas: el torso roto no cuesta y la cabeza no resta Mente | Analgésicos |
| **Sangrado** (por parte) | — | Ver Sangrado por partes | Cortante, punzante, amputaciones |

Arrastrándose (las dos piernas inútiles) ya está en el suelo: no se le derriba, pero **se le puede rematar**.

Para la interfaz: `Combatant.status_entries()` (estados con sus rondas y el sangrado de cada parte) y las señales `status_added`, `status_removed`, `bleeding_changed` y `status_changed` de `Battle`.

## Intenciones ocultas

Para variar la lectura, un enemigo puede ocultar parte del telegrafiado:

- `???  → [personaje]`: se sabe a quién, no qué ni dónde.
- `TAJO → ???`: se sabe qué, no a quién.
- Personajes con la cabeza Rota ven todas las intenciones como `???`.
- Un enemigo que va a perder la acción (derribado, aturdido) lo enseña: `DERRIBADO: PIERDE EL TURNO`.
- Cada intención puede llevar **su razón** (`Battle.intent_reason`): «Huele tu sangre», «Sin bisturíes, embiste», «Reacciona al dolor».

## Redirección

Si al resolverse una acción su objetivo ya no es válido:

1. Parte amputada → se redirige al **torso** del mismo objetivo.
2. Objetivo muerto o huido → se elige otro objetivo al azar del mismo bando, misma parte si existe; si no, torso.
3. Si no queda ningún objetivo, la acción se pierde.

## Enemigos (resumen; detalle en `enemigos.md`, pendiente)

- Cada ataque enemigo puede requerir una **parte** (`parte_requerida`). Si esa parte está Rota o Amputada, el ataque **deja de estar disponible**. Mutilar al enemigo cambia lo que puede hacer.
- Cada ataque tiene además (`EnemyAttackDef`, `[PROPUESTA]`): un **aviso legible** (`telegraph`, «Levanta el brazo de bisturíes…») que se ve con la intención; un **peso** para la elección al azar; una **recarga** en rondas; si necesita que el objetivo sufra un **estado** (serrar a quien está agarrado: lo elige casi siempre y va a por él); si necesita estar **de pie** o solo se usa **arrastrándose** (las dos piernas inútiles); y si es una **reacción** (se elige con prioridad la ronda siguiente a perder una parte).
- Patrones: secuencia fija, condicional (por Cuerpo, por partes perdidas, por número de aliados) o mezcla. Un patrón debe poder aprenderse en 2–3 rondas.
- Hasta **4 enemigos** a la vez en pantalla.
- Los enemigos **mueren** al llegar a Cuerpo 0 (no pasan por Caído). `[PROPUESTA]`
- Comportamiento base `[PROPUESTA]` (`EnemyAI`):
  - si alguien **sangra o está en el suelo**, va a por él el 75 % de las veces; si no, 50 % al aliado con menos Cuerpo;
  - 70 % de las veces apunta a la **parte que sangra**; si no, 65 % a una parte ya Herida o Rota ("huelen la sangre"), lo que hace útil la Guardia;
  - **tácticas** (`EnemyAttackDef.bonuses`, `AttackBonus`): un ataque pesa más si el objetivo sangra, está en el suelo o ha perdido el arma, o si al enemigo le falta una parte o está malherido. La táctica que decide se enseña como razón de la intención.

## Presentación `[PROPUESTA]`

A la manera de *Fear & Hunger* (`scenes/battle/battle_scene.gd`, vista 640×360), siguiendo la captura de referencia que mandó el equipo:

- **Escena**: fondo **negro** con un **foco** cenital: un haz muy tenue desde arriba y una elipse de luz en el suelo que se difumina hacia fuera. El enemigo, grande, en el centro y de pie sobre la luz (pies a 250 px; ~210 px de alto). Ya no se usa la captura del mapa como fondo.
- **El grupo, de espaldas y en primer plano** (`PartyBattler`): delante del enemigo y más abajo, al borde de la luz, con la mitad inferior tapada por las cajas. En el prólogo solo está el protagonista, abajo y un poco a la izquierda. Su imagen es un dato: `CombatantDef.battle_back` (+ `battle_back_origin`, los pies); mientras se rehace el arte en 2D, se usa el fotograma de espaldas (fila 8, reposo) del sprite del mapa con la ropa puesta, ampliado ×2 sin suavizar.
- **Abajo, dos cajas** (`BattleFrame`: fondo oscuro translúcido y marco fino de dos tonos):
  - **izquierda, estrecha: órdenes** — Atacar, Habilidades (por ahora, Respirar), Guardia, Objeto, Zafarse (si te agarran), Huir solo (con más de un personaje) y Huir. La seleccionada, en una franja clara. Los porcentajes y cantidades van en azul grisáceo a la derecha. En los submenús la caja se ensancha lo justo para los nombres largos; Esc o «Atrás» vuelve.
  - **derecha, ancha: el grupo** (`PartyRow`) — una fila por miembro: nombre, iconos de sus estados, icono del arma empuñada, **Cuerpo** con barra fina roja y su número, **Mente** con barra fina azul y su número. El miembro que elige, resaltado.
- **Apuntar**: al elegir Atacar, la caja de órdenes lista las **partes del enemigo con su probabilidad de acierto** (las amputadas, con «—» y sin poder elegirse). La parte señalada se marca **discretamente** sobre el propio enemigo (cuatro esquinas finas, `PartReticle`) y la ventana de arriba dice su estado, el acierto, el daño estimado al Cuerpo (`Battle.preview_damage`) y qué se consigue («Si se rompe: sin tajo», «Se puede arrancar», «Puede aturdir»). Con el ratón se apunta y se hace clic sobre el sprite.
- **Estados sobre el enemigo** (`EnemyMarks`): iconos pequeños con marquito junto a cada parte afectada — gota (Herida), hueso partido (Rota), muñón (Amputada) — y, sobre la cabeza, los de todo el cuerpo (sangrado, aturdimiento, agarre…). No se ve su Cuerpo exacto.
- **Mensajes** (`MessageWindow`): ventana **arriba, a todo lo ancho**, con el mismo marco, que enseña 1-2 líneas cada vez como en un RPG clásico. Cada mensaje se queda un momento y pasa solo (Intro o clic lo adelanta); la resolución de la ronda espera a que se haya contado todo. Cuando no queda nada que contar enseña lo que **prepara el enemigo** («ENFERMERO prepara AGARRAR → BRAZO DER.» y, debajo, el gesto) o los datos de la parte apuntada. Todo queda en `MessageWindow.history` (también «— RONDA N —», que no se enseña).
- **Heridas propias** (`WoundsPanel`): ventanita al pasar el ratón por la fila del personaje (al pulsar, se queda abierta; Esc la cierra) con cada parte y su estado, sus estados y el arma. Se abre sola al elegir qué cubrir con la Guardia, con la parte señalada.
- **Al resolver**: el enemigo hace su animación de preparación al anunciar y la de ataque al golpear; el personaje da un paso al atacar y se sacude en rojo al recibir; los golpes producen destello, sacudida de pantalla, salpicaduras de sangre que quedan en el suelo, números flotantes («−16», «FALLO», «CRÍTICO»), el rótulo de impacto («FRACTURA.», «AMPUTACIÓN.») y aberración del filtro de imagen (`VhsOverlay`; el del mapa si se entra desde el mapa). Mientras dura el combate la viñeta del filtro se suaviza para que se lean las cajas, y al salir vuelve a su valor.
- Se quitaron (no están en la referencia): la lista de partes con su estado a la izquierda, la caja de previsión, la silueta de heridas, la ficha grande con retrato y el registro lateral.
- **Vista del enemigo** (`EnemyView`): lee las hojas **por capas** del arte (contrato J ↔ K: `tools/art/sprite_meta.json` → `enemy_<nombre>`, horneado en `EnemySpriteDef` por `tools/data/build_enemies.gd`; en desarrollo lo lee del JSON). Oculta la capa de cada parte amputada y enseña su muñón (`stump_<parte>`), oscurece las Rotas y reproduce `idle`, `windup`, `attack`, `hit`, `stagger` y `death`. Sin hojas dibuja un **marcador provisional** por partes con las mismas animaciones y mutilaciones. La misma vista, escalada, es la figura del enemigo en el mapa y su cadáver.

## Del mapa al combate `[PROPUESTA]`

`CombatBridge` traslada el estado del protagonista (sencillo a propósito):

| En el mapa (`Vitals`) | En el combate (`Combatant`) | Al volver |
|---|---|---|
| Cuerpo (0–100) | Cuerpo (máx. 100) | El que quede (mínimo 1) |
| Mente (0–100) | Mente (máx. 100) | La que quede |
| Sangrado sí/no | 1 acumulación si sangra | Sangra si le queda alguna |
| `wounds`: parte → Herida / Rota / Amputada | Herida = 50 % de integridad; Rota = 0; Amputada | Se guarda el estado de cada parte que no esté Sana |
| Arma empuñada (`CharacterState.wielded()`) | Arma del combate (sin ninguna: Forcejear) | — |

Fuera del combate, por ahora las heridas por parte solo se guardan (no ralentizan ni impiden nada en el mapa). El enemigo también se guarda (`GameState.objects["enemy:<id>"]`: Cuerpo, sangrado y cada parte) para que, si se huye, vuelva igual de herido.

Los encuentros del mapa son datos (`EncounterDef`) y los lleva `EncounterDirector` (una línea en el guion del mapa). Ver [el enfermero § En el mapa](../enemigos/enfermero.md#en-el-mapa).

## API de opciones (contrato con la interfaz)

La interfaz no conoce las reglas: pregunta a `Battle` qué se puede hacer (código en `BattleMenu` y `BattlePreview`).

```gdscript
func action_menu(actor: Combatant) -> Array[ActionOption]
func targets_for(actor: Combatant, option: ActionOption) -> Array[TargetOption]
func preview(actor: Combatant, option: ActionOption, target: Combatant, part_id: StringName) -> ActionPreview
func make_order(actor: Combatant, option: ActionOption, target: Combatant, part_id: StringName) -> CombatAction
```

- `ActionOption`: `id` (`attack`, `attack_offhand`, id de la habilidad, `guard`, `item:<id del objeto>`, `bandage`, `break_free`, `flee_solo`, `flee`, `recover`), `category` (`attack`, `skill`, `guard`, `item`, `other`), `label`, `description`, `icon_key`, `enabled`, `disabled_reason`, `cost_body`, `cost_mind`, `needs_target`, `needs_part`, `item`, `skill`. Añadidos: `action_type`, `treatment`, `use_offhand`, `value_text` (lo de la derecha del menú: «−2 M», «×2», «45%», «+19 Mente») y `target_side` (`enemy`, `ally` o vacío).
- `TargetOption`: `combatant`, `parts`; añadidos `enabled`, `disabled_reason` (rematar a quien no está en el suelo). `PartOption`: `id`, `label`, `state`, `hit_chance`, `enabled`, `disabled_reason`; añadido `bleeding`.
- `ActionPreview`: `hit_chance`, `damage_min`/`damage_max` (Cuerpo, sin crítico), `damage_type`, `lines`, `risk_lines`, `amputation_chance`, `status_chances` (`derribado`, `aturdido`, `sangrado`, `organo`, `apartado`…; 0–100, ya con el acierto). Añadidos: `break_chance`, `act_first_chance` (probabilidad de actuar antes que lo que prepara el enemigo) y `part_damage_min`/`max`.
- La vista previa es **honesta**: recorre las tiradas posibles (azar de daño × crítico) con las mismas reglas que la resolución (la prueba `test_la_vista_previa_es_honesta` lo compara con 400 golpes reales).
- Señales de `Battle`: `logged`, `impact`, `struck` (con `organ`, `knocked_down`, `bled`, `skill`), `status_changed`, `status_added`, `status_removed`, `bleeding_changed`, `action_started`, `finished`, `intent_changed(enemy)` (al fijar la intención y cuando la pierde por un estado) y `turn_order_changed()` (`turn_order()` da la cola que queda).

## Recursos de datos (para implementación)

| Recurso | Campos principales |
|---|---|
| `CombatantStats` | cuerpo_max, mente_max, fue, des, agi, vol, res, tiene_mente |
| `BodyPartDef` | id, nombre, fraccion_integridad, mod_acierto, mult_cuerpo, vital, amputable, efectos por estado |
| `WeaponDef` | poder, precision, tipo_daño, manos (1/2), mod_critico, alcance |
| `DamageTypeDef` | por tipo de daño: armadura, integridad por parte, sangrado, aturdir, derribar, órgano, amputar, textos |
| `SkillDef` | coste, recarga, requisitos (arma, brazos, cabeza, de pie, objetivo en el suelo), golpe, estado, textos |
| `TreatmentDef` | objetos que lo dan, partes que admite, sangrado, integridad, Cuerpo, Mente, estados |
| `AttackBonus` | táctica de la IA: condición, peso extra y razón legible |
| `ArmorDef` | armadura por parte |
| `EnemyDef` | stats, partes (`Array[BodyPartDef]`), ataques, patrón, rasgos (`remata`, …) |
| `EnemyAttackDef` | tipo, poder, parte_objetivo, parte_requerida, visibilidad del telegrafiado, aviso, peso, recarga, estado que aplica, condiciones (de pie, arrastrándose, estado del objetivo, reacción), tácticas, animación y sonidos |
| `CombatStatusDef` | rondas, multiplicador de AGI, acierto propio y ajeno, perder la acción (al azar o la siguiente), impide huir, se rompe con Zafarse, suelta agarres, ignora heridas, anula y quita otros, textos |
| `EnemySpriteDef` | rejilla, origen, capa por parte, muñones, orden, animaciones y anclas de cada parte |
| `EncounterDef` | enemigo, protagonista base, objeto y bandera que lo disparan, zonas, textos, música |

En `scripts/core/` y `scripts/core/combat/`; instancias `.tres` en `data/`.

## Balance de referencia

- Fórmulas de base: [cuerpo-y-heridas.md § Balance](cuerpo-y-heridas.md#balance-de-referencia) (simulación antigua, sin las reglas por tipo de daño).
- El primer combate real, con el código del juego: [el enfermero § Balance](../enemigos/enfermero.md#balance) (`tools/balance/sim_enfermero.gd`).

## Preguntas abiertas

1. ¿Las habilidades cuestan Cuerpo/Mente/objetos, o añadimos un tercer recurso? Propuesta: sin tercer recurso (implementado así: las de esfuerzo cuestan Cuerpo; las de nervio o las atroces, Mente).
2. ¿Se ve la integridad exacta de las partes enemigas o solo su estado (Sana / Herida / Rota)? Propuesta: solo el estado.
3. ¿El orden de iniciativa de la ronda se muestra antes de confirmar órdenes? Propuesta: no exacto; la vista previa da la probabilidad de actuar antes (`act_first_chance`) y, durante la resolución, `turn_order()`.
4. ¿Se aprenden habilidades nuevas (con armas, documentos, rituales) o cada personaje tiene las suyas fijas?
5. ¿Cuántas acumulaciones de sangrado aguanta una parte, y debería el sangrado del mapa recordar en qué parte estaba?

### Resueltas

- Muerte permanente → **sí, para todos**.
- Muerte del protagonista → **fin de partida**.
- Huida individual → quien huye sale del combate y **se sigue peleando** con el resto, también si huye el protagonista. Los que ganan sobreviven; los que mueren se pierden. Solo es fin de partida si muere el protagonista.
- Huida → **en grupo o individual**, a elección.
- Recuperación de Cuerpo → **solo curándose**, dentro o fuera del combate.
