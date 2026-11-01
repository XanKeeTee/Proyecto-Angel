extends TestCase
## Sistema de Custodia: bandeja, tamaños, montones, bolsillos, combinaciones y guardado.


func _item(id: String) -> ItemDef:
	return Registry.item(StringName(id))


func test_objetos_ocupan_su_tamano() -> void:
	var c: Custody = Custody.new()
	check_eq(c.add_item(_item("palanca")), 0, "la palanca cabe")
	var stack: ItemStack = c.find_first(&"palanca")
	check_eq(stack.cells().size(), 3, "la palanca ocupa 3 casillas")
	check_eq(c.occupied_cells(), 3, "casillas ocupadas")


func test_bandeja_llena_rechaza() -> void:
	var c: Custody = Custody.new()
	# 2x2 ocupa 4 casillas: caben 4 válvulas en 5x4 (en columnas 0-1 y 2-3), no 5.
	for i: int in 4:
		check_eq(c.add_item(_item("valvula_averiada")), 0, "válvula %d cabe" % i)
	check_eq(c.add_item(_item("valvula_averiada")), 1, "la quinta no cabe")


func test_apilar() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("pilas"), 3)
	c.add_item(_item("pilas"), 3)
	check_eq(c.count(&"pilas"), 6, "seis pilas")
	check_eq(c.tray.size(), 2, "dos montones (máximo 4 por montón)")


func test_contaminado_no_se_mezcla() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("venda"), 1)
	var dirty: ItemStack = ItemStack.create(_item("venda"))
	dirty.contaminated = true
	c.add_item(_item("venda"), 1, dirty)
	check_eq(c.tray.size(), 2, "una limpia y una contaminada por separado")


func test_mover_y_girar() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("destornillador"))
	var s: ItemStack = c.find_first(&"destornillador")
	check(c.move(s, Vector2i(2, 3), true), "girado cabe en la última fila")
	check_eq(s.footprint(), Vector2i(2, 1), "girado ocupa 2x1")
	check(not c.move(s, Vector2i(4, 3), true), "no cabe saliéndose de la bandeja")


func test_juntar_al_soltar_encima() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("pilas"), 4)
	var a: ItemStack = c.tray[0]
	a.quantity = 2
	var b: ItemStack = ItemStack.create(_item("pilas"), 1)
	b.cell = Vector2i(3, 3)
	c.tray.append(b)
	check(c.move(b, a.cell, false), "soltar encima junta")
	check_eq(a.quantity, 3, "montón resultante")
	check(not c.tray.has(b), "el origen desaparece")


func test_bolsillos() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("linterna"))
	var s: ItemStack = c.find_first(&"linterna")
	check(c.to_pocket(s, 0), "a bolsillo")
	check_eq(c.occupied_cells(), 0, "ya no ocupa la bandeja")
	check(c.has(&"linterna"), "sigue en la custodia")
	check(c.from_pocket(0), "vuelve a la bandeja")
	check_eq(c.occupied_cells(), 2, "vuelve a ocupar")


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
	c.add_document(&"nota_prueba")
	var copy: Custody = Custody.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check_eq(copy.count(&"pilas"), 3, "pilas")
	check_eq(copy.find_first(&"palanca").cell, c.find_first(&"palanca").cell, "posición de la palanca")
	check(copy.pockets[2] != null and copy.pockets[2].def.id == &"linterna", "linterna en el bolsillo 3")
	check_eq(copy.pockets[2].charge, 33.0, "carga")
	check(copy.documents.has(&"nota_prueba"), "documento")


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
