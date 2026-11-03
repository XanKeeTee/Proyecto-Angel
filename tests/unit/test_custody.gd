extends TestCase
## Sistema de Custodia: lista por categorías sin límite, montones, atajos, combinaciones, guardado
## (también de partidas antiguas con la bandeja por casillas).


func _item(id: String) -> ItemDef:
	return Registry.item(StringName(id))


func test_sin_limite_de_espacio() -> void:
	var c: Custody = Custody.new()
	for i: int in 12:
		check_eq(c.add_item(_item("valvula_averiada")), 0, "válvula %d entra" % i)
	check_eq(c.count(&"valvula_averiada"), 12, "doce válvulas")
	check_eq(c.items.size(), 12, "cada una con su estado (no se apilan)")
	check_eq(c.room_for(_item("palanca"), 3), 3, "siempre hay sitio")


func test_apilar() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("pilas"), 3)
	c.add_item(_item("pilas"), 3)
	check_eq(c.count(&"pilas"), 6, "seis pilas")
	check_eq(c.items.size(), 1, "un solo montón, sin tope")
	check_eq(c.find_first(&"pilas").quantity, 6, "de seis")


func test_contaminado_no_se_mezcla() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("venda"), 1)
	var dirty: ItemStack = ItemStack.create(_item("venda"))
	dirty.contaminated = true
	c.add_item(_item("venda"), 1, dirty)
	check_eq(c.items.size(), 2, "una limpia y una contaminada por separado")
	c.add_item(_item("venda"), 2)
	check_eq(c.items.size(), 2, "las limpias nuevas van con las limpias")
	check_eq(c.items[0].quantity, 3, "tres limpias")


func test_categorias() -> void:
	var expected: Dictionary[StringName, ItemDef.Section] = {
		&"bisturi": ItemDef.Section.WEAPONS, &"tubo_metal": ItemDef.Section.WEAPONS,
		&"bata_paciente": ItemDef.Section.ARMOR, &"botas_goma": ItemDef.Section.ARMOR,
		&"linterna": ItemDef.Section.UTILITY, &"pilas": ItemDef.Section.UTILITY,
		&"destornillador": ItemDef.Section.UTILITY,
		&"venda": ItemDef.Section.MEDICINE, &"analgesicos": ItemDef.Section.MEDICINE,
		&"jeringa": ItemDef.Section.MEDICINE, &"sedante": ItemDef.Section.MEDICINE,
		&"desinfectante": ItemDef.Section.MEDICINE, &"torniquete": ItemDef.Section.MEDICINE,
		&"llave_sotano": ItemDef.Section.MAIN, &"fusible": ItemDef.Section.MAIN,
		&"valvula_averiada": ItemDef.Section.MAIN, &"palanca": ItemDef.Section.MAIN,
		&"tela": ItemDef.Section.OTHER,
	}
	for id: StringName in expected:
		check_eq(Registry.item(id).resolved_section(), expected[id], "categoría de " + id)
	for def: ItemDef in Registry.all_items():
		check(def.resolved_section() != ItemDef.Section.AUTO, "%s tiene categoría" % def.id)
	var c: Custody = Custody.new()
	c.add_item(_item("venda"))
	c.add_item(_item("bisturi"))
	c.add_item(_item("analgesicos"))
	var med: Array[ItemStack] = c.items_in(ItemDef.Section.MEDICINE)
	check_eq(med.size(), 2, "dos de medicina")
	check_eq(med[0].def.id, &"venda", "en orden de llegada")


func test_objetos_principales_no_se_descartan() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("palanca"))
	c.add_item(_item("valvula_averiada"))
	c.add_item(_item("tela"), 2)
	check(not c.discard(c.find_first(&"palanca")), "la palanca es del camino principal")
	check(not c.discard(c.find_first(&"valvula_averiada")), "la válvula tampoco")
	check(c.discard(c.find_first(&"tela")), "la tela sí")


func test_atajos() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("linterna"))
	c.add_item(_item("venda"), 2)
	var lamp: ItemStack = c.find_first(&"linterna")
	check(c.to_pocket(lamp, 0), "al atajo 1")
	check(c.contains(lamp) and c.pockets[0] == lamp, "sigue en la lista y en el atajo")
	check(c.to_pocket(lamp, 2), "se mueve al atajo 3")
	check(c.pockets[0] == null and c.pocket_of(lamp) == 2, "deja libre el 1")
	var bandage: ItemStack = c.find_first(&"venda")
	c.to_pocket(bandage, 2)
	check(c.pockets[2] == bandage and c.pocket_of(lamp) == -1, "otro objeto ocupa el atajo; el anterior sigue en la lista")
	check(c.contains(lamp), "la linterna no se pierde")
	c.take(&"venda", 2)
	check(c.pockets[2] == null, "al gastarse, el atajo queda vacío")
	check(c.from_pocket(2) == false, "vaciar uno vacío no hace nada")


func test_combinar_produce() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("venda"), 2)
	c.add_item(_item("desinfectante"))
	var text: String = c.combine(c.find_first(&"venda"), c.find_first(&"desinfectante"))
	check(text != "", "la receta existe")
	check_eq(c.count(&"venda"), 1, "gasta una venda")
	check_eq(c.count(&"venda_esterilizada"), 1, "crea una esterilizada")
	check_eq(c.find_first(&"desinfectante").durability, 2, "el desinfectante pierde un uso")


func test_combinar_no_encaja() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("venda"))
	c.add_item(_item("palanca"))
	check_eq(c.combine(c.find_first(&"venda"), c.find_first(&"palanca")), "", "venda + palanca no hace nada")
	check_eq(c.count(&"venda"), 1, "no gasta nada")


func test_recargar_linterna() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("linterna"))
	c.add_item(_item("pilas"), 2)
	var lamp: ItemStack = c.find_first(&"linterna")
	lamp.charge = 10.0
	c.combine(c.find_first(&"pilas"), lamp)
	check_eq(lamp.charge, 55.0, "suma 45")
	check_eq(c.count(&"pilas"), 1, "gasta una pila")
	check(c.has(&"linterna"), "la linterna se queda")


func test_guardado_ida_y_vuelta() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("palanca"))
	c.add_item(_item("pilas"), 3)
	c.add_item(_item("linterna"))
	c.to_pocket(c.find_first(&"linterna"), 2)
	c.find_first(&"linterna").charge = 33.0
	c.find_first(&"palanca").durability = 2
	c.add_document(&"nota_prueba")
	var copy: Custody = Custody.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check_eq(copy.count(&"pilas"), 3, "pilas")
	check_eq(copy.items.size(), 3, "tres montones")
	check_eq(copy.items[0].def.id, &"palanca", "mismo orden")
	check_eq(copy.find_first(&"palanca").durability, 2, "desgaste de la palanca")
	check(copy.pockets[2] != null and copy.pockets[2].def.id == &"linterna", "linterna en el atajo 3")
	check(copy.contains(copy.pockets[2]), "el atajo apunta a un montón de la lista")
	check_eq(copy.pockets[2].charge, 33.0, "carga")
	check(copy.documents.has(&"nota_prueba"), "documento")


func test_partida_antigua_con_bandeja() -> void:
	# Formato 1: bandeja con casillas y bolsillos separados (montones de 4 como máximo).
	var old: Dictionary = {
		"tray": [
			{"id": "pilas", "quantity": 2, "durability": 0, "charge": 0.0, "contaminated": false, "cell": [3, 2], "rotated": false},
			{"id": "palanca", "quantity": 1, "durability": 5, "charge": 0.0, "contaminated": false, "cell": [0, 0], "rotated": true},
			{"id": "pilas", "quantity": 4, "durability": 0, "charge": 0.0, "contaminated": false, "cell": [1, 0], "rotated": false},
			{"id": "objeto_que_ya_no_existe", "quantity": 1, "cell": [4, 3]},
		],
		"pockets": [null, {"id": "linterna", "quantity": 1, "durability": 0, "charge": 20.0, "contaminated": false,
			"cell": [0, 0], "rotated": false}, null, null, null],
		"documents": ["nota_prueba"], "read": [], "recipes": ["sedante"],
	}
	var c: Custody = Custody.from_dict(JSON.parse_string(JSON.stringify(old)))
	check_eq(c.count(&"pilas"), 6, "las pilas de los dos montones")
	check_eq(c.items_in(ItemDef.Section.UTILITY).filter(func(s: ItemStack) -> bool: return s.def.id == &"pilas").size(), 1,
		"juntas en un montón")
	check_eq(c.items[0].def.id, &"palanca", "orden de lectura de la bandeja (fila a fila)")
	check_eq(c.find_first(&"palanca").durability, 5, "conserva el desgaste")
	check(c.pockets[1] != null and c.pockets[1].def.id == &"linterna", "el bolsillo 2 pasa a ser el atajo 2")
	check(c.contains(c.pockets[1]) and c.pockets[1].charge == 20.0, "la linterna está en la lista con su carga")
	check(c.documents.has(&"nota_prueba") and c.known_recipes.has(&"sedante"), "documentos y recetas")
	# Y el personaje con el arma empuñada en la bandeja antigua.
	var ch: CharacterState = CharacterState.from_dict({"custody": old, "weapon": {"id": "palanca", "pocket": -1, "cell": [0, 0]}})
	check(ch.wielded() != null and ch.wielded().def.id == &"palanca", "el arma empuñada se recupera")
	var again: CharacterState = CharacterState.from_dict(JSON.parse_string(JSON.stringify(ch.to_dict())))
	check(again.wielded() == again.custody.find_first(&"palanca"), "y se vuelve a guardar en el formato nuevo")
	check_eq(int(ch.to_dict()["custody"]["version"]), Custody.SAVE_VERSION, "formato nuevo")


func test_usar_objeto() -> void:
	var ch: CharacterState = CharacterState.new()
	ch.custody.add_item(_item("venda"), 2)
	ch.vitals.set_bleeding(true)
	var text: String = ch.use_item(ch.custody.find_first(&"venda"))
	check(text != "", "se puede usar")
	check(not ch.vitals.bleeding, "deja de sangrar")
	check_eq(ch.custody.count(&"venda"), 1, "gasta una")
	check_eq(ch.use_item(ch.custody.find_first(&"venda")), "", "sin sangrado la venda no se gasta")


func test_venda_contaminada_penaliza() -> void:
	var ch: CharacterState = CharacterState.new()
	ch.custody.add_item(_item("venda_sucia"))
	ch.vitals.set_bleeding(true)
	var body: int = ch.vitals.body
	ch.use_item(ch.custody.find_first(&"venda_sucia"))
	check(not ch.vitals.bleeding, "corta la hemorragia")
	check(ch.vitals.body < body, "pero resta Cuerpo")


func test_sangrado_tiene_suelo() -> void:
	var v: Vitals = Vitals.new()
	v.set_bleeding(true)
	v.tick(1000.0)
	check_eq(v.body, v.body_floor, "el sangrado no baja del suelo del prólogo")
