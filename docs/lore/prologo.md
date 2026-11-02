# Lore del prólogo

## Aportado por el equipo (canon)

Lo pidió Miguel en el encargo del prólogo:

- El juego se llama **La Novena Vigilia**.
- Existe un acontecimiento llamado **el Desvelo**, que hace de referencia temporal («antes del Desvelo»).
- El protagonista despierta en la **Habitación 09** de un hospital, sin recordar cómo llegó.
- El hospital tiene que ver con su presencia allí. Por megafonía se dice: «El paciente de la habitación nueve ha recuperado la consciencia. Inicien el protocolo de recuperación».
- Existe un **expediente de la Habitación 09** fechado antes del Desvelo.
- El juego tendrá **cinco protagonistas**.

> Pendiente de confirmar por la otra persona del equipo, según las reglas de `README.md`.

## `[PROPUESTA]` Lo que sugieren los documentos del prólogo

Nada de esto es canon hasta que lo aprueben las dos personas del equipo. Está escrito para **no cerrar el misterio**.

- **Hospital Clínico San Lázaro**, planta 3: la **Unidad de Vigilia**. Lázaro alude a volver de la muerte.
- **Vigilia**: estado en el que se mantiene a ciertos pacientes, sin sedación y sin sueño profundo. Se cuenta en ciclos. El protagonista está en el **ciclo IX**, la novena vigilia.
- **Desde el Desvelo** nadie de la planta duerme de verdad, y no ha muerto nadie en planta (el inventario dice que las bolsas para cadáveres no se han usado). No se explica qué fue el Desvelo.
- **Protocolo de recuperación**: el término es ambiguo a propósito. Puede ser recuperar al paciente o recuperar algo del paciente:
  - el informe quirúrgico habla de «material recuperado: 3 ml», de aspecto luminoso, extraído por un **puerto dorsal**;
  - el protagonista tiene una pieza metálica entre los omóplatos;
  - según la circular nº 9, cuando un paciente despierta solo, el personal se va y «el edificio se encarga».

  Encaja con la idea central (un milagro convertido en herramienta de explotación) sin aclarar qué es lo que se extrae. **Evita la premisa prohibida**: no hay ningún ángel usado como batería; es un paciente humano y no se dice qué trae de vuelta.
- **Reingresos**: el libro de admisiones muestra nueve ingresos de la Habitación 09 con el mismo nombre tachado. En la morgue hay una etiqueta «09 — Causa: fin de la vigilia», con el cuerpo desaparecido.
- **El pasillo imposible**: la libreta del celador dice que el ala mide once metros más por dentro que por fuera. Al final del prólogo, el pasillo lleva a otra Habitación 09 con alguien que tiene la cara del protagonista.

- **Ropa del prólogo**: descripciones en `tools/levels/build_wear.gd`. Detalles que sugieren cosas sin cerrarlas: «09» bordado en la bata, la placa arrancada del celador, la etiqueta «CAMA 12» del pijama, un nombre escrito y tachado dentro del gorro de lana.

- **Decorado del mapa** (solo visual, sin texto): no añade hechos nuevos, pero algunos detalles apuntan a cosas.
  - Morgue: una pila de bolsas para cadáveres dobladas y sin usar, junto a la puerta de una cámara frigorífica
    (encaja con el inventario: no ha muerto nadie en planta).
  - Hab. 09: el tubo de oxígeno arrancado de la toma de la pared; gasas y una jeringa en el suelo.
  - Hab. 10: hojas del cuaderno desperdigadas hasta la puerta y una silla volcada (alguien quería salir).
  - Hab. 11: polvo de meses y un biombo plegado; Hab. 12: rodadas donde estaba la otra cama.
  - Relojes de pared parados, todos a la misma hora (3:40). Si el equipo quiere que la hora signifique algo, se decide aquí.

## `[PROPUESTA]` Pistas y pensamientos del prólogo

Textos nuevos para que los puzles se entiendan sin salir del mundo. No añaden canon: son carteles, etiquetas y lo que el protagonista piensa. Están en `tools/levels/build_hospital.gd` (`OBJECT_TWEAKS`, `DOOR_TWEAKS`) y en `tools/data/build_prologue_data.gd` (pensamientos).

- **Carteles y etiquetas**:
  - puerta del archivo: pegatina «ARCHIVO MÉDICO · Llave: enfermería»;
  - puerta de la escalera: placa «ESCALERA DE SERVICIO · SÓTANO · Solo mantenimiento»;
  - estantería del taller: etiqueta «GRUPO ELECTRÓGENO · RECAMBIOS»;
  - puerta de la 10: «Alguien ha rayado el número de la placa con algo de metal».
- **Examinar**:
  - puerta del quirófano (atascada): «Con algo largo y fuerte metido en la ranura, quizá cediera»;
  - armario del almacén: «Por la rendija se ve algo largo de hierro apoyado en el fondo»;
  - generador: «En el lateral, un hueco con rosca: le falta una pieza».
- **Pensamientos** (tecla T), en segunda persona como el resto de textos del protagonista. Resumen lo que ya sabe; no revelan nada que no haya visto u oído, salvo dos suposiciones de sentido común: «El generador de un hospital suele estar en el sótano» y «En un quirófano siempre queda instrumental tirado». El último pensamiento, tras la megafonía, señala las huellas mojadas hacia el muro oeste.
- **Registrar**: los textos de los muebles con botín aleatorio ya no nombran objetos («Rebuscas entre ropa de otra persona», «Revuelves la ropa del carro»…), porque lo que hay cambia de una partida a otra.

## Revisar con `lore-keeper`

- Que «el edificio se encarga» no choque con lo que el equipo quiera hacer con el hospital después.
- Que la extracción del puerto dorsal no se acerque demasiado a la premisa prohibida.
- Cómo encajan los otros cuatro protagonistas con la Unidad de Vigilia.
