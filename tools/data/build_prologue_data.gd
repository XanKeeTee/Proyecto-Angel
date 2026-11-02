extends Node
## Genera los datos de puzles y botín del prólogo:
## - data/loot/prologo.tres: plan de botín aleatorio (tablas por tipo de mueble y repartos).
## - data/thoughts/prologo.tres: pensamientos del protagonista (objetivo actual, tecla T).
## Uso: "$GODOT_BIN" --headless --path . res://tools/data/build_prologue_data.tscn
## (como escena, para que existan los autoloads de los que dependen los objetos).
## Después se pueden retocar en el inspector; volver a ejecutar esto los sobrescribe.
## Balance y criterios: docs/design/escenas/prologo.md («Botín» y «Pistas»).
## Los textos son `[PROPUESTA]` (docs/lore/prologo.md).

const LOOT_OUT: String = "res://data/loot/prologo.tres"
const THOUGHTS_OUT: String = "res://data/thoughts/prologo.tres"

var _tables: Dictionary = {}


func _ready() -> void:
	var plan: LootPlan = _build_loot()
	var err: Error = ResourceSaver.save(plan, LOOT_OUT)
	if err != OK:
		push_error("No se pudo guardar " + LOOT_OUT)
	var thought_set: ThoughtSet = _build_thoughts()
	err = ResourceSaver.save(thought_set, THOUGHTS_OUT)
	if err != OK:
		push_error("No se pudo guardar " + THOUGHTS_OUT)
	print("Botín: %d muebles, %d repartos. Pensamientos: %d." % [plan.slots.size(), plan.scatter.size(), thought_set.thoughts.size()])
	get_tree().quit()


func _item(id: String) -> ItemDef:
	return load("res://data/items/%s.tres" % id)


# --- botín -------------------------------------------------------------------------------------

## [id, empty_chance, [[item, peso, min, max], ...]]
func _table(id: String, empty: float, entries: Array) -> LootTable:
	var t: LootTable = LootTable.new()
	t.id = StringName(id)
	t.empty_chance = empty
	var list: Array[LootTableEntry] = []
	for e: Array in entries:
		var entry: LootTableEntry = LootTableEntry.new()
		entry.item = _item(e[0])
		entry.weight = float(e[1])
		entry.min_quantity = int(e[2]) if e.size() > 2 else 1
		entry.max_quantity = int(e[3]) if e.size() > 3 else entry.min_quantity
		list.append(entry)
	t.entries = list
	_tables[id] = t
	return t


func _ids(list: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: String in list:
		result.append(StringName(id))
	return result


func _scatter(item: String, copies: int, chance: float, candidates: Array) -> LootScatter:
	var rule: LootScatter = LootScatter.new()
	rule.item = _item(item)
	rule.copies = copies
	rule.chance = chance
	rule.candidates = _ids(candidates)
	return rule


func _build_loot() -> LootPlan:
	# Tablas por tipo de mueble: casi siempre vacías y con poco dentro. Lo importante (pilas,
	# vendas, ropa) va por repartos garantizados, para que el total no dependa de la suerte.
	_table("cajon", 0.7, [["analgesicos", 3], ["jeringa", 1], ["venda", 1], ["pilas", 1]])
	_table("taquilla", 0.75, [["analgesicos", 1], ["venda", 1], ["pilas", 1]])
	_table("papelera", 0.8, [["venda_sucia", 2], ["analgesicos", 1], ["pilas", 1]])
	_table("cura", 0.5, [["venda", 2], ["desinfectante", 2], ["analgesicos", 1], ["jeringa", 1], ["ampolla", 1]])
	_table("medicacion", 0.55, [["analgesicos", 3], ["ampolla", 1], ["jeringa", 1]])
	_table("trastero", 0.7, [["pilas", 1], ["venda", 1], ["desinfectante", 1]])
	_table("cama", 0.88, [["analgesicos", 1], ["venda_sucia", 1]])

	var slots: Array[LootSlot] = []
	# [object_id, tabla ("" = ninguna), texto de registrar (null = el de la sala)]
	var spec: Array = [
		["cama_09", "", "A los pies de la cama cuelga una hoja de constantes con tu número."],
		["cama_07", "cama", null],
		["mesita_07", "cajon", null],
		["taquilla_07", "taquilla", "Rebuscas entre ropa de otra persona."],
		["cama_08", "cama", null],
		["mesita_08", "cajon", ""],
		["cama_10", "cama", null],
		["mesita_10", "cajon", ""],
		["taquilla_10", "taquilla", "Rebuscas entre la ropa colgada."],
		["mesita_11", "cajon", null],
		["cama_12", "cama", null],
		["mesita_12", "cajon", ""],
		["taquilla_12", "taquilla", null],
		["estanteria_almacen", "cura", "Apartas cajas de productos de limpieza."],
		["papelera_banos", "papelera", "Rebuscas entre papel mojado."],
		["botiquin_banos", "medicacion", ""],
		["mostrador_control", "medicacion", "Abres el armario de abajo."],
		["estanteria_enfermeria", "cura", "Buscas entre los frascos algo que todavía sirva."],
		["encimera_enfermeria", "cura", ""],
		["camilla_enfermeria", "cama", null],
		["encimera_quirofano", "", "Entre el instrumental hay un formulario."],
		["camilla_pasillo", "cama", null],
		["papelera_vestibulo", "papelera", null],
		["mostrador_recepcion_2", "cajon", null],
		["papelera_recepcion", "papelera", ""],
		["estanteria_electrica", "trastero", "Revuelves una caja de bombillas fundidas."],
		["carro_lavanderia_1", "trastero", null],
		["carro_lavanderia_2", "trastero", "Revuelves la ropa del carro."],
		["estanteria_lavanderia", "trastero", "Detergente y cajas de jabón."],
		["morgue_2", "", "Abres los cajones uno a uno."],
		["camilla_morgue", "cama", null],
		["banco_taller", "trastero", "Encima, una libreta con las tapas manchadas de grasa."],
	]
	for row: Array in spec:
		var slot: LootSlot = LootSlot.new()
		slot.object_id = StringName(row[0])
		if row[1] != "":
			slot.table = _tables[row[1]]
		if row[2] != null:
			slot.override_search = true
			slot.search_text = row[2]
		slots.append(slot)

	var upstairs_drawers: Array = ["taquilla_07", "mesita_08", "mesita_10", "mesita_11", "mesita_12", "taquilla_12",
		"papelera_banos", "mostrador_control", "papelera_recepcion", "mostrador_recepcion_2", "papelera_vestibulo",
		"estanteria_almacen"]
	var basement: Array = ["estanteria_electrica", "carro_lavanderia_1", "carro_lavanderia_2", "estanteria_lavanderia",
		"morgue_2", "banco_taller"]
	var scatter: Array[LootScatter] = [
		# Luz: 3 pilas arriba y 2 abajo, siempre (cada una da un 45 % de batería, unos 4 minutos).
		_scatter("pilas", 3, 1.0, upstairs_drawers),
		_scatter("pilas", 2, 1.0, basement),
		# Curas: una venda arriba, otra abajo (donde se abren los puntos) y una esterilizada.
		_scatter("venda", 1, 1.0, ["mesita_12", "estanteria_enfermeria", "encimera_enfermeria", "taquilla_10", "botiquin_banos",
			"mostrador_control"]),
		_scatter("venda", 1, 1.0, ["carro_lavanderia_2", "estanteria_lavanderia", "banco_taller", "estanteria_electrica"]),
		_scatter("venda_esterilizada", 1, 1.0, ["encimera_quirofano", "estanteria_enfermeria"]),
		_scatter("analgesicos", 2, 1.0, ["mesita_08", "botiquin_banos", "mostrador_control", "taquilla_10", "mesita_07"]),
		_scatter("jeringa", 1, 1.0, ["taquilla_10", "encimera_enfermeria", "estanteria_enfermeria", "mostrador_control"]),
		_scatter("ampolla", 1, 1.0, ["taquilla_10", "encimera_enfermeria", "estanteria_enfermeria", "botiquin_banos"]),
		_scatter("desinfectante", 1, 1.0, ["estanteria_almacen", "estanteria_enfermeria", "encimera_enfermeria"]),
		# Ropa: cada prenda como mucho una vez, y no siempre. Lejos de la habitación 09; la mitad, abajo.
		_scatter("zapatillas", 1, 0.7, ["cama_07", "cama_10", "cama_12", "taquilla_12", "taquilla_10", "camilla_pasillo"]),
		_scatter("gorro_lana", 1, 0.45, ["taquilla_07", "taquilla_10", "taquilla_12", "mesita_11"]),
		_scatter("pantalon_pijama", 1, 0.45, ["mesita_12", "taquilla_12", "carro_lavanderia_1", "carro_lavanderia_2"]),
		_scatter("gorro_quirurgico", 1, 0.55, ["encimera_quirofano", "encimera_enfermeria", "mostrador_control"]),
		_scatter("bata_medico", 1, 0.5, ["mostrador_control", "mostrador_recepcion_2", "encimera_enfermeria"]),
		_scatter("chaqueta_celador", 1, 0.55, ["carro_lavanderia_2", "carro_lavanderia_1", "banco_taller", "estanteria_lavanderia"]),
		_scatter("pantalon_celador", 1, 0.45, ["carro_lavanderia_1", "carro_lavanderia_2", "estanteria_lavanderia"]),
		_scatter("botas_goma", 1, 0.55, ["banco_taller", "estanteria_electrica", "carro_lavanderia_2"]),
	]
	var plan: LootPlan = LootPlan.new()
	plan.slots = slots
	plan.scatter = scatter
	plan.fixed_items = _ids(["linterna", "palanca", "destornillador", "fusible", "valvula_averiada", "llave_botiquin",
		"llave_archivo", "llave_sotano", "llave_habitacion_10"])
	return plan


# --- pensamientos --------------------------------------------------------------------------------

## [texto, banderas necesarias, banderas prohibidas, objetos necesarios, objetos prohibidos]
func _thought(text: String, req: Array = [], forb: Array = [], items: Array = [], no_items: Array = []) -> Thought:
	var t: Thought = Thought.new()
	t.text = text
	t.requires_flags = _ids(req)
	t.forbids_flags = _ids(forb)
	t.requires_items = _ids(items)
	t.forbids_items = _ids(no_items)
	return t


func _build_thoughts() -> ThoughtSet:
	var result: ThoughtSet = ThoughtSet.new()
	# Del final al principio: vale el primero que se cumpla.
	result.thoughts = [
		_thought("Saben que estás despierto. Tienes que salir.\nLas huellas mojadas del pasillo van hacia el muro oeste, junto a la 07. Según el plano, ahí termina el edificio.",
			["pasillo_imposible"]),
		_thought("La válvula está puesta. Solo falta tirar de la palanca de arranque del generador.",
			["valvula_puesta", "fusible_puesto"], ["power_on"]),
		_thought("La válvula ya encaja. Hay que enroscarla en el generador, en la sala de calderas.",
			[], ["valvula_puesta"], ["valvula_reparada"]),
		_thought("La válvula tiene el asiento suelto: así no va a encajar. Con el destornillador podrías apretarlo.\nEn la Custodia se pueden probar cosas juntas.",
			[], ["valvula_puesta"], ["valvula_averiada", "destornillador"]),
		_thought("La válvula tiene el asiento suelto. Haría falta un destornillador para apretarlo.\nEn un quirófano siempre queda instrumental tirado.",
			[], ["valvula_puesta"], ["valvula_averiada"]),
		_thought("El cuadro ya está listo, pero el generador no arranca sin su válvula de presión.\nSi hay recambios en algún sitio, será en el taller de mantenimiento.",
			["fusible_puesto"], ["valvula_puesta"]),
		_thought("Las bornas aguantan. Falta colocar el fusible F1 en su hueco del cuadro.",
			["panel_reparado"], ["fusible_puesto"], ["fusible"]),
		_thought("Al cuadro le falta el fusible F1. La nota decía que hay repuestos en el archivo de la planta 3, en la caja de mantenimiento.",
			["panel_reparado"], ["fusible_puesto"]),
		_thought("Las bornas del cuadro están sueltas. Con el destornillador puedes apretarlas.",
			["panel_abierto"], ["panel_reparado"], ["destornillador"]),
		_thought("Las bornas del cuadro están sueltas y no tienes con qué apretarlas.\nUn destornillador… En un quirófano siempre queda instrumental tirado.",
			["panel_abierto"], ["panel_reparado"]),
		_thought("El generador ya tiene su válvula, pero al cuadro general no le llega nada. El cuadro está en la sala eléctrica.",
			["valvula_puesta"], ["fusible_puesto"]),
		_thought("El generador no arranca: le falta la válvula de presión. Y antes habrá que mirar el cuadro eléctrico general.",
			["generador_sin_valvula"], ["panel_abierto"]),
		_thought("El sótano. Si el hospital tiene un generador de emergencia, estará aquí abajo, con un cuadro eléctrico que lo alimente.",
			["event:puntos_abiertos"], ["panel_abierto"]),
		_thought("La escalera de servicio está abierta. Baja al sótano: sin corriente no hay salida.",
			["escalera_abierta"], ["event:puntos_abiertos"]),
		_thought("Una llave de hierro con un cordel. Es de la escalera de servicio, la que baja al sótano.",
			[], ["escalera_abierta"], ["llave_sotano"]),
		_thought("Ya tienes el fusible. Para bajar al sótano hace falta la llave de la escalera de servicio.\nEl escritorio del archivo tenía cajones.",
			["fusible_cogido"], ["escalera_abierta"], [], ["llave_sotano"]),
		_thought("El archivo médico. Tu expediente tiene que estar aquí.\nY si mantenimiento guardaba algo en esta planta, también.",
			["archivo_abierto"], ["fusible_cogido"], [], ["llave_sotano"]),
		_thought("Una llave larga de latón. La del archivo médico, en el lado norte del pasillo, pasada la enfermería.",
			[], ["archivo_abierto"], ["llave_archivo"]),
		_thought("La llave pequeña de la cama de la 11. Es de un armario de cristal… El de medicación de la enfermería.",
			[], ["llave_archivo_cogida"], ["llave_botiquin"]),
		_thought("En la enfermería hay una llave colgada dentro de un armario de cristal. Su cerradura es pequeña.\nAlgo ha crujido en la habitación 11.",
			["botiquin_cerrado", "oyo_crujido"], ["llave_botiquin_cogida"]),
		_thought("Algo ha crujido en la habitación 11. Una cama. Esa habitación debería estar vacía.",
			["oyo_crujido"], ["llave_botiquin_cogida"]),
		_thought("El archivo está cerrado con llave. La pegatina de la puerta decía que la llave está en la enfermería.",
			["archivo_cerrado"], ["llave_archivo_cogida"]),
		_thought("La escalera de servicio baja al sótano, pero está cerrada con llave. Solo mantenimiento.",
			["escalera_cerrada"], ["escalera_abierta"], [], ["llave_sotano"]),
		_thought("Una palanca de hierro. La puerta atascada del quirófano tendría que ceder con esto.",
			[], ["quirofano_abierto"], ["palanca"]),
		_thought("La puerta del quirófano está atascada por dentro. Con algo largo y fuerte, como una palanca, podrías forzarla.\nEn el almacén de limpieza guardan de todo.",
			["quirofano_atascado"], ["quirofano_abierto"]),
		_thought("La salida está encadenada y el ascensor no tiene corriente. Si volviera la luz…\nEl generador de un hospital suele estar en el sótano.",
			["salida_cerrada"], ["escalera_abierta"]),
		_thought("El ascensor no tiene corriente. Si volviera la luz…\nEl generador de un hospital suele estar en el sótano.",
			["ascensor_sin_corriente"], ["escalera_abierta"]),
		_thought("Tienes que averiguar dónde estás y cómo salir.\nEl pasillo, las otras habitaciones… El plano de evacuación estará junto a recepción.",
			["linterna_cogida"]),
		_thought("Está demasiado oscuro. En la mesita, junto a la cama, quizá haya algo.",
			[], ["linterna_cogida"]),
	]
	result.fallback = "No sabes muy bien qué hacer. Quizá mirar con más calma lo que ya has visto."
	result.bleeding_text = "Los puntos de la espalda se han abierto. Tienes que vendarte antes de que sea peor."
	return result
