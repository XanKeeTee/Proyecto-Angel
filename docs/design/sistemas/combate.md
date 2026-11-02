# Sistema de combate

> Estado: `[PROPUESTA]` salvo las decisiones marcadas como **aprobadas**.
> Relacionado: [cuerpo-y-heridas.md](cuerpo-y-heridas.md) · [el enfermero](../enemigos/enfermero.md) (primer enemigo) · equipamiento (pendiente)
>
> Código: reglas en `scripts/systems/combat/` (`Battle`, `Combatant`, `EnemyAI`, `CombatRules`, `CombatBridge`, `EncounterDirector`), datos en `scripts/core/*def.gd` y `data/{enemies,party,body_parts,weapons,statuses}/`, pantalla en `scenes/battle/`.

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
| **Zafarse** | Solo si le **sujetan** (estado Agarrado). Ver Estados `[PROPUESTA]` |
| **Huir** | Intento de huida de todo el grupo (ver Huida) |

En el juego, **Objeto** usa lo que lleva el personaje en la Custodia que cura (vendas, analgésicos, sedante…) con sus efectos de siempre (`CombatBridge.use_item`). El prototipo sin mapa usa vendas genéricas.

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

Un ataque físico enemigo puede restar también Mente si acierta (`EnemyAttackDef.mind_damage`, reducido en VOL/2). `[PROPUESTA]`

**Amputación que sangra** `[PROPUESTA]`: perder un miembro (no vital) añade 2 acumulaciones de **Sangrado** (máx. 3).

**Partes que se arrancan a golpes** `[PROPUESTA]`: una parte marcada `severable_by_blunt` (carne fundida con metal, tejido muerto) se amputa con daño contundente si ya estaba **Rota** y el golpe hace ≥ 25 % de su integridad (con la misma tirada de Resistencia). Solo la tiene el brazo de instrumental del enfermero.

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

Temporales, como datos (`CombatStatusDef`, en `data/statuses/`). Duran unas rondas contando la ronda en que se aplican y se descuentan al final de cada ronda. Los aplica un ataque que acierta (`inflicts_status`, con su probabilidad).

| Campo | Qué hace |
|---|---|
| `agility_mult` | Multiplica la AGI efectiva (iniciativa, evasión, huida) |
| `accuracy_mod` | Suma al acierto de quien lo sufre |
| `incoming_hit_mod` | Suma al acierto de quien le ataca |
| `skip_chance` | Probabilidad de perder la acción |
| `blocks_flee` | No puede huir |
| `breakable` | Se rompe con **Zafarse**: `45 + 5 × (FUE propia − FUE de quien sujeta)` %, entre 15 y 90. También se suelta si a quien sujeta se le rompe la parte con la que sujeta, cae o muere |

Estados actuales: **Agarrado** y **Sedación** (ver [el enfermero](../enemigos/enfermero.md#estados)). Se ven como iconos en la fila del personaje (y sobre el enemigo), en su ventanita de heridas y en la ventana de mensajes.

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
- Cada ataque tiene además (`EnemyAttackDef`, `[PROPUESTA]`): un **aviso legible** (`telegraph`, «Levanta el brazo de bisturíes…») que se ve con la intención; un **peso** para la elección al azar; una **recarga** en rondas; si necesita que el objetivo sufra un **estado** (serrar a quien está agarrado: lo elige casi siempre y va a por él); si necesita estar **de pie** o solo se usa **arrastrándose** (las dos piernas inútiles); y si es una **reacción** (se elige con prioridad la ronda siguiente a perder una parte).
- Patrones: secuencia fija, condicional (por Cuerpo, por partes perdidas, por número de aliados) o mezcla. Un patrón debe poder aprenderse en 2–3 rondas.
- Hasta **4 enemigos** a la vez en pantalla.
- Los enemigos **mueren** al llegar a Cuerpo 0 (no pasan por Caído). `[PROPUESTA]`
- Comportamiento base (prototipo) `[PROPUESTA]`:
  - 50 % de las veces van a por el aliado con menos Cuerpo;
  - 65 % de las veces vuelven a golpear una parte ya Herida o Rota ("huelen la sangre"), lo que hace útil la Guardia.

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

## Recursos de datos (para implementación)

| Recurso | Campos principales |
|---|---|
| `CombatantStats` | cuerpo_max, mente_max, fue, des, agi, vol, res, tiene_mente |
| `BodyPartDef` | id, nombre, fraccion_integridad, mod_acierto, mult_cuerpo, vital, amputable, efectos por estado |
| `WeaponDef` | poder, precision, tipo_daño, manos (1/2), mod_critico, habilidades |
| `ArmorDef` | armadura por parte |
| `EnemyDef` | stats, partes (`Array[BodyPartDef]`), ataques, patrón, rasgos (`remata`, …) |
| `EnemyAttackDef` | tipo, poder, parte_objetivo, parte_requerida, visibilidad del telegrafiado, aviso, peso, recarga, estado que aplica, condiciones (de pie, arrastrándose, estado del objetivo, reacción), animación y sonidos |
| `CombatStatusDef` | rondas, multiplicador de AGI, acierto propio y ajeno, perder la acción, impide huir, se rompe con Zafarse |
| `EnemySpriteDef` | rejilla, origen, capa por parte, muñones, orden, animaciones y anclas de cada parte |
| `EncounterDef` | enemigo, protagonista base, objeto y bandera que lo disparan, zonas, textos, música |

Todos en `scripts/core/`; instancias `.tres` en `data/`.

## Balance de referencia

Ver la simulación en [cuerpo-y-heridas.md § Balance](cuerpo-y-heridas.md#balance-de-referencia).

## Preguntas abiertas

1. ¿Las habilidades cuestan Cuerpo/Mente/objetos, o añadimos un tercer recurso? Propuesta: sin tercer recurso.
2. ¿Se ve la integridad exacta de las partes enemigas o solo su estado (Sana / Herida / Rota)? Propuesta: solo el estado.
3. ¿El orden de iniciativa de la ronda se muestra antes de confirmar órdenes?

### Resueltas

- Muerte permanente → **sí, para todos**.
- Muerte del protagonista → **fin de partida**.
- Huida individual → quien huye sale del combate y **se sigue peleando** con el resto, también si huye el protagonista. Los que ganan sobreviven; los que mueren se pierden. Solo es fin de partida si muere el protagonista.
- Huida → **en grupo o individual**, a elección.
- Recuperación de Cuerpo → **solo curándose**, dentro o fuera del combate.
