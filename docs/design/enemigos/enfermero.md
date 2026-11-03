# El enfermero transfigurado

> Estado: `[PROPUESTA]` (concepto, números y textos). Lore en [docs/lore/prologo.md](../../lore/prologo.md).
> Recursos: `data/enemies/enfermero.tres` (enemigo), `data/body_parts/enfermero_*.tres` (partes),
> `data/statuses/{agarre,sedacion}.tres` (estados), `data/enemies/encuentro_enfermero.tres` (encuentro en el mapa).
> Todo se genera con `tools/data/build_combat_rules.gd` (estados, habilidades…) y `tools/data/build_enemies.gd`; el balance se mide con `tools/balance/sim_enfermero.gd`.

## Concepto

Un **Transfigurado** (dossier, § 5): un enfermero del propio hospital, alterado. Alto y demacrado, uniforme blanco manchado y roto, piel gris azulada con venas oscuras, la mascarilla quirúrgica **cosida a la cara** y una **máscara de porcelana** agrietada sobre los ojos; la columna arqueada y demasiado larga; el antebrazo derecho **fundido con instrumental** (bisturíes y una sierra de hueso que le salen de la carne) y una **jeringa** grande en la mano izquierda; vías que le entran en el pecho con un líquido oscuro y, sobre la columna, **una incisión cosida como la del protagonista** (no se explica).

Es el primer combate del juego: tiene que enseñar que **dónde golpeas importa** y que el **aviso** del enemigo sirve para algo.

## Estadísticas base

| Campo | Valor | Notas |
|---|---|---|
| Cuerpo | 105 | Muere al llegar a 0 (no pasa por Caído) |
| Mente | — | `has_mind = false`: no entra en pánico ni se quiebra |
| FUE / DES / AGI / VOL / RES | 10 / 9 / 7 / 6 / 6 | AGI baja: se le acierta algo más que a un humano |
| Armadura | 1 | |

## Partes del cuerpo

| Parte | Integridad | `mod_acierto` | `mult_cuerpo` | Si queda inútil (Rota o Amputada)… | Amputable |
|---|---|---|---|---|---|
| Cabeza | 0.25 (26) | −25 | 2.0 | Rota: aturdido, −25 acierto y sin Chillido. **Decapitarlo lo mata** | Sí (corte) |
| Torso | 0.50 (53) | +10 | 1.0 | Rota: cada acción le cuesta 3 de Cuerpo | No |
| Brazo de la jeringa (izq.) | 0.30 (32) | −10 | 0.6 | Sin **Pinchazo** ni **Agarrar**; suelta a quien sujetaba | Sí (corte) |
| Brazo de instrumental (der.) | **0.24** (25) | **0** | 0.6 | Sin **Tajo**, **Serrar**, **Zarpazo** ni **Ensartar**: ya no corta | Sí, **también a golpes** si ya está Roto `[PROPUESTA]` |
| Pierna izq. / der. | 0.35 (37) | 0 | 0.6 | Una: cojea (AGI −50 %). Las dos: **se arrastra** (AGI 0, otros ataques; está en el suelo: **se le puede rematar**) | Sí (corte) |

Con el tubo (contundente) las piernas y los brazos se rompen antes (integridad ×1,25) y un golpe en la cabeza puede aturdirlo; romperle una pierna puede **derribarlo** (60 %).

El brazo de instrumental es grande y sale del cuerpo: se acierta como el resto (0 en vez de −10) y aguanta dos golpes de tubo. Donde la carne se funde con el metal hay una costura de grapas: cuando está Roto, un golpe contundente que haga ≥ 25 % de su integridad **lo arranca** (`BodyPartDef.severable_by_blunt`). Así el tubo, que nunca corta, también puede mutilar a este enemigo.

## Patrón de ataque

Cada ronda elige al azar entre lo que **puede** hacer, según el peso **más sus tácticas** (ver Tácticas). Lo que puede hacer depende de su cuerpo; lo que prefiere, del tuyo.

| Ataque | Requiere | Tipo · poder · precisión | Peso | Telegrafiado (lo que ve el jugador) |
|---|---|---|---|---|
| **Tajo** | Brazo de instrumental, de pie | Cortante · 13 · 72 · parte al azar (torso ×3) · hace sangrar | 3 (+1,5 si sangras) | «Levanta el brazo de bisturíes por encima de la máscara.» |
| **Agarrar** | Brazo de la jeringa, de pie | Contundente · 3 · 70 · un brazo · aplica **Agarrado** | 1.6 (+2 si has perdido el arma) · recarga 3 | «Abre la mano izquierda y se inclina hacia ti.» |
| **Serrar** | Brazo de instrumental · el objetivo **Agarrado** | Cortante · 15 · 82 · un brazo | 9 | «Te sujeta y apoya la sierra de hueso en el brazo.» |
| **Pinchazo** | Brazo de la jeringa | Punzante · 4 · 76 · torso · −10 Mente · 70 % **Sedación** (es leve: no llega a hacer sangrar ni a un órgano) | 1.8 (+0,6 sin bisturíes) · recarga 1 | «Sacude la jeringa. El líquido oscuro burbujea dentro.» |
| **Chillido** | Cabeza útil · **reacción** | Horror · −14 Mente | — | «Se encoge. Algo se hincha detrás de la mascarilla cosida.» |
| **Embestida** | De pie | Contundente · 5 · 65 · torso · 30 % **Derribado** | 0.6 (+1 sin bisturíes, +0,4 malherido) | «Baja la cabeza y carga con el hombro.» |
| **Ensartar** | Brazo de instrumental, de pie · el objetivo **Derribado** | Punzante · 12 · 80 · torso | 8 | «Se inclina sobre ti con los bisturíes hacia abajo.» |
| **Pisotón** | De pie · el objetivo **Derribado** | Contundente · 10 · 80 · torso | 4 (+4 sin bisturíes) | «Levanta el pie descalzo sobre tu pecho.» |
| **Zarpazo** | Brazo de instrumental · **arrastrándose** | Cortante · 9 · 68 · una pierna | 3 | «Se arrastra hacia tus tobillos con los bisturíes por delante.» |
| **Agarrar el tobillo** | Brazo de la jeringa · arrastrándose | Contundente · 3 · 66 · una pierna · Agarrado | 1.5 · recarga 3 | «Estira la mano desde el suelo hacia tu pierna.» |
| Forcejeo | (si no le queda nada) | Contundente · 5 · 70 | — | — |

La Mente que resta se reduce en VOL/2 del objetivo (el protagonista tiene VOL 9: −4).

**Combinación que se aprende en 2–3 rondas**: *Agarrar* → la ronda siguiente *Serrar* el brazo agarrado. El aviso dice qué brazo. Respuestas: **Guardia** en ese brazo (mitad de daño y no se puede amputar), **Zafarse**, o romperle el **brazo de la jeringa** (suelta) o el **de instrumental** (ya no sierra).

**Segunda combinación** `[PROPUESTA]`: *Embestida* te tira al suelo (30 %) → la ronda siguiente pierdes la acción levantándote y él *ensarta* (o *pisa*, sin bisturíes). El aviso lo dice («ENSARTAR → tu TORSO»). Respuesta: en el suelo aún puedes **encogerte** (Guardia en el torso: mitad de daño).

**Reacciones**: la ronda siguiente a perder una parte (romperla o amputarla) **chilla** (−Mente) si tiene la cabeza útil.

### Tácticas `[PROPUESTA]`

Lee al protagonista y cambia según lo que ha perdido (`EnemyAttackDef.bonuses`). La razón se enseña con la intención (`Battle.intent_reason`).

| Situación | Qué hace | Razón que se ve |
|---|---|---|
| Sangras | Va a por ti (75 %), apunta a la parte que sangra (70 %) y tajea más | «Huele tu sangre» / «Va a la herida que sangra» |
| Estás derribado | Ensarta (o pisa) | «Va a rematarte» |
| Has perdido el arma | Agarra más | «Ya no te teme» |
| Le has roto el brazo de instrumental | Embiste y pincha más | «Sin bisturíes, embiste» / «Sin bisturíes, quiere dormirte» |
| Está malherido (< 50 % de Cuerpo) | Embiste un poco más | «Herido, quiere tirarte» |
| Acaba de perder una parte | Chilla | «Reacciona al dolor» |
| Está derribado o aturdido | Pierde la ronda (se ve: «DERRIBADO: PIERDE EL TURNO») | — |

### Estados

| Estado | Rondas | Efecto | Se quita |
|---|---|---|---|
| **Agarrado** | 2 | No puede huir; AGI ×0.5; quien le ataca, +20 acierto | Zafarse (`45 + 5 × (FUE propia − FUE de quien sujeta)` %, entre 15 y 90); un **Empujón** que entra; **Forcejear** (le da la vuelta); o si a quien sujeta se le rompe la mano, cae, muere o le derriban |
| **Sedación** | 2 | AGI ×0.6; −10 acierto; 15 % de perder la acción; embota el terror | Solo con el tiempo |
| **Derribado** | 2 | Pierde su siguiente acción levantándose; AGI ×0.5; +20 acierto contra él; puede encogerse | Al levantarse (dura hasta el final de esa ronda) |

El enfermero también puede acabar **derribado** (golpe a la rodilla, barrido, romperle una pierna), **aturdido** (cabeza), **apartado** (empujón) o **agarrado** (forcejear). Ver [combate.md § Estados](../sistemas/combate.md#estados-propuesta).

### Cómo se le gana con el tubo `[PROPUESTA]`

Desarmarle (brazo de instrumental), luego a las piernas con el **golpe a la rodilla** (lento: suele llegar después de su golpe; si cae, la ronda siguiente se levanta en vez de atacar) y **rematar** a la cabeza mientras está en el suelo. Ante el serrado, **empujón** (rápido: si llegas antes, no sierra y te suelta) o Guardia en ese brazo. Si sangra algo que no coagula (un muñón, un hueso roto), torniquete o venda.

## Balance

`tools/balance/sim_enfermero.gd` (3000 combates por estrategia, código real de `Battle` y su API de opciones; `SIM_LOG=1` imprime el registro). Protagonista como al coger el tubo: Cuerpo 82, Mente 70, FUE 8 DES 8 AGI 8 VOL 9 RES 8, sin armadura, tubo (contundente, poder 12, precisión 70, alcance medio). Sin huida.

| Estrategia | Victoria | Rondas (al ganar) | Cuerpo al ganar | Sale con algo amputado | Sale con algo roto |
|---|---|---|---|---|---|
| **Al azar**: partes al azar, sin mirar el aviso, a veces muerde | 25.7 % | 9.9 | 32 | 38.1 % | 49.4 % |
| **Siempre al torso** | 51.6 % | 8.0 | 33 | 34.2 % | 38.4 % |
| **Desarmar**: el brazo de instrumental y luego el torso | 74.6 % | 10.3 | 38 | 5.4 % | 35.3 % |
| **Con cabeza** (sin objetos): desarmar, rodilla y remate, Guardia y empujón ante el serrado, encogerse en el suelo, respirar | 77.3 % | 9.7 | 45 | 2.9 % | 31.1 % |
| Lo mismo **sin el golpe a la rodilla** | 75.6 % | 10.5 | 39 | 2.9 % | 34.7 % |
| **Con cabeza y lo que se suele llevar** (1 venda, 1 analgésico) | 78.5 % | 10.0 | 45 | 3.5 % | 31.0 % |

Usos por combate con cabeza: golpe a la rodilla 3,6, rematar 1,2, Guardia 0,3, respirar 0,3, empujón 0,15; con el kit, además venda 0,24 y analgésicos 0,28 (se gastan en uno de cada cuatro combates).

De dónde viene el daño (Cuerpo perdido por combate): a lo bruto, el **Tajo** (39) y el sangrado (10); desarmándole, el Tajo baja a 14 y el sangrado a 3–4, y pesan la Embestida y el Pinchazo (12–15 cada uno).

Lectura: a lo loco se pierde tres de cada cuatro veces y casi siempre con algo amputado; al torso es una moneda al aire y deja mutilado a uno de cada tres; leyendo el aviso, desarmando y derribando se gana cuatro de cada cinco veces, se termina antes y con más Cuerpo, y casi nunca se pierde un miembro. El golpe a la rodilla no es obligatorio (sin él, −2 puntos y 6 de Cuerpo menos al ganar) pero es lo que acorta el combate.

Valores que se tocaron para llegar aquí (desde la versión con 80 % «con cabeza»): con las reglas nuevas (el Tajo hace sangrar, la Embestida derriba, el remate en el suelo) el combate era mucho más duro: **Cuerpo 115 → 105**; tácticas sin bisturíes más suaves (Pinchazo +2 → +0,6, Embestida +2,5 → +1); la Embestida derriba 40 → 30 %; Ensartar 15/85 → 12/80; el punzante necesita ≥ 7 de daño para hacer sangrar o llegar a un órgano (el Pinchazo no llega); coagulación 25 → 35 % de base; el golpe a la rodilla pasó a ser **lento** (−10 iniciativa: así el derribo cae después de su golpe y deja la ronda siguiente para rematar), poder ×0,9 → ×1,3, derribo 25 → 50 % y su coste de 2 Cuerpo a 2 Mente.

## En el mapa

- **Disparo**: al coger el tubo de la habitación 12 (`tubo_hab12`) se activa `tubo_cogido` y, si la mano está vacía, se empuña solo. Al pisar el **pasillo del ala de pacientes** con esa bandera, aparece.
- **Presentación**: a 8 casillas por el pasillo; un fluorescente parpadea sobre él, se le oye arrastrar un pie, el protagonista se gira, dos líneas de texto, se acerca hasta 3 casillas, dos líneas más, gruñe y la cinta salta (nieve, `combat_transition`) al combate. El fondo del combate es una captura oscurecida del pasillo.
- **Victoria**: el cuerpo queda tendido donde cayó, sin las partes que perdió, y se puede examinar. Se guarda en `GameState.objects["enemy:enfermero"]` (`state: dead`, posición y partes) y sigue ahí al cargar.
- **Huida**: desaparece. Vuelve con las **mismas heridas** pasados 75 s de juego, la próxima vez que se entre en el pasillo de la planta 3 o en el de mantenimiento del sótano viniendo de otra sala.
- **Derrota**: pantalla de muerte (ver [prologo.md](../escenas/prologo.md#supervivencia-en-el-prólogo)).

## Sonidos

Ninguno está sintetizado: se buscarán en Freesound. Mientras falte el archivo, `BattleScene` y `EncounterDirector` usan el provisional de la derecha (`SOUND_FALLBACK`).

| Nombre | Qué buscar | Provisional |
|---|---|---|
| `combat_pipe_flesh` | Tubo de hierro contra carne: golpe sordo y húmedo, contundente, 0,3–0,6 s. Sin eco metálico ni «puñetazo de cine» | `metal_bang` |
| `combat_pipe_bone` | Tubo contra hueso (cráneo, antebrazo): golpe seco con crujido corto, 0,3–0,5 s | `metal_bang` |
| `combat_bone_break` | Hueso que se parte: chasquido grave y crujido (apio/madera húmeda), 0,4–0,8 s, sin voz | `metal_bang` |
| `combat_amputation` | Miembro arrancado: desgarro de carne y tendón con chapoteo, 0,8–1,5 s; nada de espada ni silbido | `cloth_tear` |
| `combat_scalpel_slash` | Tajo de bisturíes: corte rápido y fino sobre carne/tela con un tintineo metálico pequeño, 0,3–0,6 s | `cloth_tear` |
| `combat_saw` | Sierra de hueso manual: dos o tres pasadas ásperas contra hueso, 1–2 s | `cloth_tear` |
| `combat_syringe` | Pinchazo de jeringa: aguja que entra (clic de émbolo, líquido), muy corto, 0,2–0,5 s | `glass` |
| `combat_swing_miss` | Golpe al aire: zumbido grave de una barra pesada, 0,2–0,4 s | `cloth_rustle` |
| `enfermero_breath` | Respiración húmeda y lenta a través de tela (mascarilla), masculina, sin palabras; 2–4 s, que se pueda repetir | `entity_breath` |
| `enfermero_growl` | Gruñido gutural ahogado, como a través de una boca cosida, 0,6–1,2 s | `entity_breath` |
| `enfermero_scream` | Chillido de dolor ahogado tras la mascarilla, agudo y quebrado, 1–1,5 s; humano pero mal | `entity_whisper` |
| `enfermero_death` | Último estertor y caída de un cuerpo pesado al suelo, 1,5–2,5 s | `heavy_drag` |
| `enfermero_drag_steps` | Un paso y un pie que se arrastra sobre linóleo, lento, 1–1,5 s (un ciclo) | `heavy_drag` |
| `combat_transition` | Cinta VHS que salta: chirrido de cabezal + ráfaga de estática, 0,6–1 s | `pa_static` |
| `music_combat_drone` (música, `.ogg`) | Drone industrial grave y tenso, pulso lento como de máquina, bucle de 30–90 s, sin melodía | — (sin música) |

## Preguntas abiertas

1. ¿Puede el tubo arrancar partes de otros enemigos (tejido muerto, prótesis) o solo de este?
2. ¿Debería soltar algo al morir (la jeringa, una llave)? Ahora no suelta nada.
3. ¿Vuelve a aparecer si se huye dos veces, o se queda en un sitio concreto?
4. ¿Debería huir al quedarse sin piernas? Ahora se arrastra hasta el final.
