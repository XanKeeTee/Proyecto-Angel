extends TestCase
## Rasgar, fabricar, descartar, arma en la mano y sonidos de los objetos (lógica sin escena).


func _item(id: String) -> ItemDef:
	return Registry.item(StringName(id))


func _recipe(id: String) -> RecipeDef:
	for r: RecipeDef in Registry.recipes():
		if r.id == StringName(id):
			return r
	return null


func test_rasgar_ropa_da_tela() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("bata_medico"))
	var gown: ItemStack = c.find_first(&"bata_medico")
	check(Crafting.can_tear(c, gown), "una bata se puede rasgar")
	var text: String = Crafting.tear(c, gown)
	check(text.begins_with("Rasgas"), "texto de rasgar")
	check(not c.has(&"bata_medico"), "la bata desaparece")
	check_eq(c.count(&"tela"), _item("bata_medico").tear_yield(), "da tantas tiras como dice la prenda")
	check_eq(_item("bata_medico").tear_yield(), 3, "la ropa del cuerpo da 3 tiras")
	check_eq(_item("gorro_lana").tear_yield(), 1, "un gorro da 1")


func test_no_se_rasga_lo_que_no_es_tela() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("botas_goma"))
	c.add_item(_item("linterna"))
	check(not Crafting.can_tear(c, c.find_first(&"botas_goma")), "las botas de goma no")
	check(not Crafting.can_tear(c, c.find_first(&"linterna")), "la linterna no")
	check_eq(Crafting.tear(c, c.find_first(&"linterna")), "", "rasgar algo que no se puede no hace nada")
	check(c.has(&"linterna"), "y no se pierde")


func test_fabricar_consume_y_produce() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("tela"), 3)
	var recipe: RecipeDef = _recipe("venda_improvisada")
	check(recipe != null and recipe.mode == RecipeDef.Mode.CRAFT, "existe la receta de fabricar")
	check(Crafting.can_craft(c, recipe), "con 3 tiras se puede")
	var text: String = Crafting.craft(c, recipe)
	check(text != "", "fabrica")
	check_eq(c.count(&"tela"), 1, "gasta dos tiras")
	check_eq(c.count(&"venda_improvisada"), 1, "da una venda improvisada")
	check(c.find_first(&"venda_improvisada").contaminated, "la venda improvisada sale sucia")
	check(not Crafting.can_craft(c, recipe), "con una tira ya no")
	check_eq(Crafting.craft(c, recipe), "", "y no fabrica")
	check_eq(c.count(&"tela"), 1, "sin gastar nada")
	check(Crafting.blocker(c, recipe).begins_with("Falta"), "dice lo que falta")


func test_fabricar_varios_ingredientes() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("tubo_metal"))
	c.add_item(_item("tela"), 2)
	var recipe: RecipeDef = _recipe("mango_envuelto")
	check(Crafting.craft(c, recipe) != "", "envuelve el tubo")
	check(not c.has(&"tubo_metal") and not c.has(&"tela"), "gasta el tubo y la tela")
	check(c.has(&"tubo_envuelto"), "da el tubo envuelto")
	check(c.find_first(&"tubo_envuelto").def.weapon.accuracy > _item("tubo_metal").weapon.accuracy, "agarra mejor")


func test_fabricar_sin_sitio_no_gasta() -> void:
	var c: Custody = Custody.new()
	for i: int in 4:
		c.add_item(_item("valvula_averiada"))
	# Bandeja llena salvo una columna de 4: tela (1 casilla) + 3 vendas improvisadas llenas.
	c.add_item(_item("tela"), 2)
	for i: int in 3:
		var s: ItemStack = ItemStack.create(_item("venda_improvisada"), 4)
		s.cell = Vector2i(4, 1 + i)
		c.tray.append(s)
	check(not Crafting.can_craft(c, _recipe("torniquete")), "no hay tela suficiente")
	c.add_item(_item("tela"), 1)
	var recipe: RecipeDef = _recipe("venda_improvisada")
	var before: int = c.count(&"tela")
	# Gastar 2 de 3 tiras deja la casilla ocupada y no cabe otra venda (montones llenos).
	check(not Crafting.can_craft(c, recipe), "no cabe el resultado")
	check_eq(Crafting.craft(c, recipe), "", "no fabrica")
	check_eq(c.count(&"tela"), before, "no gasta nada")


func test_descubrir_recetas() -> void:
	var c: Custody = Custody.new()
	check(not Crafting.known_recipes(c).has(_recipe("torniquete")), "sin tela no se conoce el torniquete")
	c.add_item(_item("tela"))
	check(Crafting.known_recipes(c).has(_recipe("torniquete")), "con tela se descubre")
	c.take(&"tela")
	check(Crafting.known_recipes(c).has(_recipe("torniquete")), "y no se olvida")
	var data: Dictionary = c.to_dict()
	check(Custody.from_dict(data).known_recipes.has(&"torniquete"), "se guarda")


func test_combinacion_se_aprende_y_desinfecta() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("venda_improvisada"))
	c.add_item(_item("desinfectante"))
	var text: String = c.combine(c.find_first(&"venda_improvisada"), c.find_first(&"desinfectante"))
	check(text != "", "venda improvisada + desinfectante")
	check(c.has(&"venda") and not c.has(&"venda_improvisada"), "da una venda limpia")
	check_eq(c.find_first(&"desinfectante").durability, 2, "el desinfectante gasta un uso")
	check(c.known_recipes.has(&"desinfectar_venda_improvisada"), "la combinación queda aprendida")
	check(Crafting.known_recipes(c).has(_recipe("desinfectar_venda_improvisada")), "y aparece en FABRICAR")


func test_descartar_respeta_objetos_clave() -> void:
	var c: Custody = Custody.new()
	c.add_item(_item("llave_sotano"))
	c.add_item(_item("pilas"), 3)
	check(not c.discard(c.find_first(&"llave_sotano")), "una llave no se descarta")
	check(c.has(&"llave_sotano"), "sigue en la custodia")
	check(c.discard(c.find_first(&"pilas")), "unas pilas sí")
	check(not c.has(&"pilas"), "ya no están")


func test_arma_en_la_mano_se_guarda() -> void:
	var ch: CharacterState = CharacterState.new()
	ch.custody.add_item(_item("linterna"))
	ch.custody.add_item(_item("bisturi"))
	ch.custody.add_item(_item("tubo_metal"))
	var tube: ItemStack = ch.custody.find_first(&"tubo_metal")
	check_eq(ch.wield(ch.custody.find_first(&"linterna")), "Eso no sirve como arma.", "la linterna no es un arma")
	check_eq(ch.wield(tube), "", "empuña el tubo")
	check(ch.wielded() == tube, "lo tiene en la mano")
	check(ch.custody.contains(tube), "sigue en la custodia")
	var loaded: CharacterState = CharacterState.from_dict(ch.to_dict())
	check(loaded.wielded() != null and loaded.wielded().def.id == &"tubo_metal", "se carga con el arma en la mano")
	check_eq(loaded.wielded().cell, tube.cell, "el mismo montón")
	ch.custody.remove(tube)
	check(ch.wielded() == null, "si sale de la custodia, la mano queda vacía")


func test_descartar_el_arma_vacia_la_mano() -> void:
	var ch: CharacterState = CharacterState.new()
	ch.custody.add_item(_item("bisturi"))
	var knife: ItemStack = ch.custody.find_first(&"bisturi")
	ch.wield(knife)
	var got: Array[ItemStack] = []
	var on_drop: Callable = func(s: ItemStack) -> void: got.append(s)
	EventBus.item_discarded.connect(on_drop)
	var text: String = ch.discard(knife)
	EventBus.item_discarded.disconnect(on_drop)
	check(text.begins_with("Dejas"), "lo deja en el suelo")
	check(ch.wielded() == null, "la mano queda vacía")
	check_eq(got.size(), 1, "avisa al mundo")
	ch.custody.add_item(_item("fusible"))
	check_eq(ch.discard(ch.custody.find_first(&"fusible")), "No. Podrías necesitarlo.", "el fusible es clave")


func test_sonidos_por_material() -> void:
	var names: PackedStringArray = ItemSounds.candidates(_item("palanca"), ItemSounds.Action.PICK)
	check_eq(names[0], "inv_metal_heavy_pick", "metal pesado al cogerlo")
	check_eq(ItemSounds.candidates(_item("llave_sotano"), ItemSounds.Action.DISCARD)[0], "inv_keys_drop", "llaves al tirarlas")
	check_eq(ItemSounds.candidates(_item("bata_paciente"), ItemSounds.Action.EQUIP)[0], "inv_cloth_equip", "ropa: tela")
	var use: PackedStringArray = ItemSounds.candidates(_item("pilas"), ItemSounds.Action.USE)
	check_eq(use[0], "use_battery_insert", "pilas: sonido por acción")
	check(ItemSounds.resolve(use) != "", "y hay uno provisional que existe")
	check(ItemSounds.resolve(ItemSounds.candidates(_item("venda"), ItemSounds.Action.USE)) != "", "venda también")
	for def: ItemDef in Registry.all_items():
		check(ItemSounds.resolve(ItemSounds.candidates(def, ItemSounds.Action.PLACE)) != "", "%s suena al soltarlo" % def.id)
