extends SceneTree
## Genera los objetos y recetas del prólogo en data/items y data/recipes.
## Uso: "$GODOT_BIN" --headless --path . -s tools/data/build_items.gd
## Después se editan en el inspector; este script solo sirve para recrearlos desde cero.

const ITEMS: String = "res://data/items/"
const RECIPES: String = "res://data/recipes/"
const ICONS: String = "res://assets/sprites/items/"

var items: Dictionary = {}


func _init() -> void:
	_build_items()
	_build_recipes()
	print("Objetos: %d" % items.size())
	quit()


func _build_items() -> void:
	var toggle: ToggleFlashlightEffect = ToggleFlashlightEffect.new()
	_item("linterna", "Linterna", ItemDef.Category.TOOL, Vector2i(1, 2), 1,
		"Una linterna de bolsillo de metal, con la pintura desconchada. Alguien grabó un número en el mango: 09.\nFunciona con pilas.",
		{"max_charge": 100.0, "usable": true, "consumed_on_use": false, "use_effects": [toggle], "use_verb": "Encender / apagar", "key_item": true})
	var recharge: RechargeEffect = RechargeEffect.new()
	recharge.amount = 45.0
	recharge.message = "Cambias las pilas. La luz vuelve a ser blanca."
	_item("pilas", "Pilas", ItemDef.Category.POWER, Vector2i.ONE, 4,
		"Pilas alcalinas. Una de ellas tiene la fecha de caducidad rascada.",
		{"usable": true, "use_effects": [recharge], "use_verb": "Cargar la linterna"})
	_item("venda", "Venda", ItemDef.Category.MEDICAL, Vector2i.ONE, 4,
		"Venda de gasa en su envoltorio. El papel está húmedo, pero el sello aguanta.",
		{"usable": true, "use_effects": [_heal(4, 0, true, "Aprietas la venda contra los puntos. La sangre se detiene.")], "use_verb": "Vendar"})
	var dirty: HealEffect = _heal(4, 0, true, "Aprietas la venda contra los puntos. La sangre se detiene.")
	dirty.contaminated_message = "La sangre se detiene, pero la venda huele mal. Un calor febril te sube por la espalda."
	_item("venda_sucia", "Venda usada", ItemDef.Category.MEDICAL, Vector2i.ONE, 3,
		"Una venda sacada de la papelera. Tiene manchas que no son tuyas.\nSe podría limpiar con algo.",
		{"usable": true, "contaminated": true, "use_effects": [dirty], "use_verb": "Vendar"})
	_item("desinfectante", "Desinfectante", ItemDef.Category.MEDICAL, Vector2i.ONE, 1,
		"Frasco de clorhexidina medio vacío. Da para unas pocas curas.\nSolo sirve combinado con otra cosa.",
		{"max_durability": 3})
	_item("venda_esterilizada", "Venda esterilizada", ItemDef.Category.MEDICAL, Vector2i.ONE, 4,
		"Venda empapada en desinfectante. Escuece solo de mirarla.",
		{"usable": true, "use_effects": [_heal(18, 0, true, "Escuece como fuego. Después, por fin, algo de alivio.")], "use_verb": "Vendar"})
	_item("analgesicos", "Analgésicos", ItemDef.Category.MEDICAL, Vector2i.ONE, 6,
		"Comprimidos sueltos en un bote sin etiqueta. Alguien escribió a mano: «para el dolor de los vigilantes».",
		{"usable": true, "use_effects": [_heal(12, 0, false, "Los tragas en seco. El dolor se aleja un poco.")], "use_verb": "Tomar"})
	_item("jeringa", "Jeringa", ItemDef.Category.MEDICAL, Vector2i.ONE, 3,
		"Jeringa estéril, sin usar. Sola no sirve de nada.", {})
	_item("ampolla", "Ampolla", ItemDef.Category.MEDICAL, Vector2i.ONE, 3,
		"Ampolla de cristal. La etiqueta dice «Sedante — uso restringido. No administrar en planta 3».", {})
	_item("sedante", "Sedante preparado", ItemDef.Category.MEDICAL, Vector2i.ONE, 3,
		"Una dosis lista para inyectar. Calma la mente; no hace que duermas.",
		{"usable": true, "use_effects": [_heal(0, 35, false, "El frío te sube por el brazo. Los ruidos se apagan un poco.")], "use_verb": "Inyectar"})
	_item("destornillador", "Destornillador", ItemDef.Category.TOOL, Vector2i(1, 2), 1,
		"Destornillador de electricista con el mango agrietado. Aguantará unos pocos usos.",
		{"max_durability": 4})
	_item("palanca", "Palanca", ItemDef.Category.TOOL, Vector2i(1, 3), 1,
		"Una palanca de hierro, pesada. Tiene pelo pegado en un extremo.",
		{"max_durability": 6})
	_item("fusible", "Fusible de alta tensión", ItemDef.Category.PART, Vector2i(1, 2), 1,
		"Cartucho cerámico con contactos de latón. Lleva escrito: «CUADRO GENERAL — SÓTANO».",
		{"key_item": true})
	_item("valvula_averiada", "Válvula averiada", ItemDef.Category.PART, Vector2i(2, 2), 1,
		"La válvula de presión del generador. El cuerpo está bien, pero el asiento se ha soltado: le faltan los tornillos apretados.",
		{"key_item": true})
	_item("valvula_reparada", "Válvula reparada", ItemDef.Category.PART, Vector2i(2, 2), 1,
		"La válvula de presión, con el asiento atornillado. Debería aguantar.",
		{"key_item": true})
	_item("llave_botiquin", "Llave pequeña", ItemDef.Category.KEY, Vector2i.ONE, 1,
		"Una llave diminuta y fría. La encontraste en una cama que todavía crujía.", {"key_item": true})
	_item("llave_habitacion_10", "Llave de la habitación 10", ItemDef.Category.KEY, Vector2i.ONE, 1,
		"Llave con una chapa de plástico: «10». La chapa está mordida.", {"key_item": true})
	_item("llave_archivo", "Llave del archivo", ItemDef.Category.KEY, Vector2i.ONE, 1,
		"Llave larga de latón. Etiqueta: «ARCHIVO — solo personal autorizado».", {"key_item": true})
	_item("llave_sotano", "Llave del sótano", ItemDef.Category.KEY, Vector2i.ONE, 1,
		"Llave de hierro con un cordel. Huele a gasóleo.", {"key_item": true})


func _build_recipes() -> void:
	_recipe("venda_esterilizada", "venda", "desinfectante", RecipeDef.Mode.PRODUCE, "venda_esterilizada",
		"Empapas la venda en desinfectante.")
	_recipe("limpiar_venda", "venda_sucia", "desinfectante", RecipeDef.Mode.PRODUCE, "venda",
		"Lavas la venda con desinfectante hasta que deja de oler. Servirá.")
	var recharge: RecipeDef = _recipe("recargar_linterna", "pilas", "linterna", RecipeDef.Mode.RECHARGE, "",
		"Cambias las pilas de la linterna. La luz vuelve a ser blanca.")
	recharge.consume_second = false
	recharge.charge_amount = 45.0
	ResourceSaver.save(recharge, RECIPES + "recargar_linterna.tres")
	_recipe("sedante", "jeringa", "ampolla", RecipeDef.Mode.PRODUCE, "sedante",
		"Cargas la jeringa con el contenido de la ampolla.")
	_recipe("reparar_valvula", "destornillador", "valvula_averiada", RecipeDef.Mode.PRODUCE, "valvula_reparada",
		"Aprietas los tornillos del asiento hasta que dejan de girar. La válvula queda firme.")


func _heal(body: int, mind: int, stops: bool, message: String) -> HealEffect:
	var effect: HealEffect = HealEffect.new()
	effect.body = body
	effect.mind = mind
	effect.stops_bleeding = stops
	effect.requires_bleeding = stops and body < 10
	effect.message = message
	return effect


func _item(id: String, name: String, category: ItemDef.Category, size: Vector2i, stack: int, description: String,
		extra: Dictionary) -> void:
	var item: ItemDef = ItemDef.new()
	item.id = StringName(id)
	item.display_name = name
	item.category = category
	item.size = size
	item.max_stack = stack
	item.description = description
	for key: String in extra:
		if key == "use_effects":
			var effects: Array[ItemEffect] = []
			for effect: ItemEffect in extra[key]:
				effects.append(effect)
			item.use_effects = effects
		else:
			item.set(key, extra[key])
	if ResourceLoader.exists(ICONS + id + ".png"):
		item.icon = load(ICONS + id + ".png")
	if ResourceLoader.exists(ICONS + id + "_inspect.png"):
		item.inspect_sheet = load(ICONS + id + "_inspect.png")
		item.inspect_views = 8
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ITEMS))
	ResourceSaver.save(item, ITEMS + id + ".tres")
	items[id] = load(ITEMS + id + ".tres")


func _recipe(id: String, a: String, b: String, mode: RecipeDef.Mode, result: String, message: String) -> RecipeDef:
	var recipe: RecipeDef = RecipeDef.new()
	recipe.first = items[a]
	recipe.second = items[b]
	recipe.mode = mode
	if result != "":
		recipe.result = items[result]
	recipe.message = message
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RECIPES))
	ResourceSaver.save(recipe, RECIPES + id + ".tres")
	return recipe
