extends SceneTree
## Genera los objetos, armas y recetas del prólogo en data/items, data/weapons y data/recipes.
## Uso: "$GODOT_BIN" --headless --path . -s tools/data/build_items.gd
## Después se editan en el inspector; este script solo sirve para recrearlos desde cero.
## La ropa la crea tools/levels/build_wear.gd (rasgarla da tela según su ranura: ver ItemDef.tear_yield).
## Lo marcado [PROPUESTA] (tela, vendas improvisadas, torniquete, armas del hospital) está pendiente
## de aprobar por el equipo (docs/design/sistemas/custodia.md).

const ITEMS: String = "res://data/items/"
const RECIPES: String = "res://data/recipes/"
const WEAPONS: String = "res://data/weapons/"
const ICONS: String = "res://assets/sprites/items/"

var items: Dictionary = {}
var weapons: Dictionary = {}


func _init() -> void:
	_build_weapons()
	_build_items()
	_build_recipes()
	print("Objetos: %d" % items.size())
	quit()


## Armas (`WeaponDef`). Cuchilla, barra y punzón son del prototipo de combate (data/party las usa).
func _build_weapons() -> void:
	_weapon("knife", "Cuchilla", 12, 75, CombatTypes.DamageType.CUT, false, 0)
	_weapon("iron_bar", "Barra", 14, 70, CombatTypes.DamageType.BLUNT, true, 0)
	_weapon("awl", "Punzón", 10, 80, CombatTypes.DamageType.PIERCE, false, 5)
	# [PROPUESTA] Improvisadas del hospital.
	_weapon("scalpel", "Bisturí", 8, 85, CombatTypes.DamageType.CUT, false, 10)
	_weapon("pipe", "Tubo de hierro", 12, 70, CombatTypes.DamageType.BLUNT, false, 0)
	_weapon("pipe_wrapped", "Tubo con mango envuelto", 12, 78, CombatTypes.DamageType.BLUNT, false, 2)
	_weapon("crowbar", "Palanca", 13, 65, CombatTypes.DamageType.BLUNT, true, 0)


func _build_items() -> void:
	var toggle: ToggleFlashlightEffect = ToggleFlashlightEffect.new()
	_item("linterna", "Linterna", ItemDef.Category.TOOL, Vector2i(1, 2), 1,
		"Una linterna de bolsillo de metal, con la pintura desconchada. Alguien grabó un número en el mango: 09.\nFunciona con pilas.",
		{"max_charge": 100.0, "usable": true, "consumed_on_use": false, "use_effects": [toggle], "use_verb": "Encender / apagar",
		"key_item": true, "sound_material": ItemDef.SoundMaterial.METAL_SMALL})
	var recharge: RechargeEffect = RechargeEffect.new()
	recharge.amount = 45.0
	recharge.message = "Cambias las pilas. La luz vuelve a ser blanca."
	_item("pilas", "Pilas", ItemDef.Category.POWER, Vector2i.ONE, 4,
		"Pilas alcalinas. Una de ellas tiene la fecha de caducidad rascada.",
		{"usable": true, "use_effects": [recharge], "use_verb": "Cargar la linterna",
		"sound_material": ItemDef.SoundMaterial.BATTERY, "use_sound": "use_battery_insert"})
	_item("venda", "Venda", ItemDef.Category.MEDICAL, Vector2i.ONE, 4,
		"Venda de gasa en su envoltorio. El papel está húmedo, pero el sello aguanta.",
		{"usable": true, "use_effects": [_heal(4, 0, true, "Aprietas la venda contra los puntos. La sangre se detiene.")],
		"use_verb": "Vendar", "sound_material": ItemDef.SoundMaterial.CLOTH, "use_sound": "use_bandage_apply"})
	var dirty: HealEffect = _heal(4, 0, true, "Aprietas la venda contra los puntos. La sangre se detiene.")
	dirty.contaminated_message = "La sangre se detiene, pero la venda huele mal. Un calor febril te sube por la espalda."
	_item("venda_sucia", "Venda usada", ItemDef.Category.MEDICAL, Vector2i.ONE, 3,
		"Una venda sacada de la papelera. Tiene manchas que no son tuyas.\nSe podría limpiar con algo.",
		{"usable": true, "contaminated": true, "use_effects": [dirty], "use_verb": "Vendar",
		"sound_material": ItemDef.SoundMaterial.CLOTH, "use_sound": "use_bandage_apply"})
	_item("desinfectante", "Desinfectante", ItemDef.Category.MEDICAL, Vector2i.ONE, 1,
		"Frasco de clorhexidina medio vacío. Da para unas pocas curas.\nSolo sirve combinado con otra cosa.",
		{"max_durability": 3, "sound_material": ItemDef.SoundMaterial.PLASTIC})
	_item("venda_esterilizada", "Venda esterilizada", ItemDef.Category.MEDICAL, Vector2i.ONE, 4,
		"Venda empapada en desinfectante. Escuece solo de mirarla.",
		{"usable": true, "use_effects": [_heal(18, 0, true, "Escuece como fuego. Después, por fin, algo de alivio.")],
		"use_verb": "Vendar", "sound_material": ItemDef.SoundMaterial.CLOTH, "use_sound": "use_bandage_apply"})
	_item("analgesicos", "Analgésicos", ItemDef.Category.MEDICAL, Vector2i.ONE, 6,
		"Comprimidos sueltos en un bote sin etiqueta. Alguien escribió a mano: «para el dolor de los vigilantes».",
		{"usable": true, "use_effects": [_heal(12, 0, false, "Los tragas en seco. El dolor se aleja un poco.")],
		"use_verb": "Tomar", "sound_material": ItemDef.SoundMaterial.PILLS, "use_sound": "use_pills_swallow"})
	_item("jeringa", "Jeringa", ItemDef.Category.MEDICAL, Vector2i.ONE, 3,
		"Jeringa estéril, sin usar. Sola no sirve de nada.", {"sound_material": ItemDef.SoundMaterial.PLASTIC})
	_item("ampolla", "Ampolla", ItemDef.Category.MEDICAL, Vector2i.ONE, 3,
		"Ampolla de cristal. La etiqueta dice «Sedante — uso restringido. No administrar en planta 3».",
		{"sound_material": ItemDef.SoundMaterial.GLASS})
	_item("sedante", "Sedante preparado", ItemDef.Category.MEDICAL, Vector2i.ONE, 3,
		"Una dosis lista para inyectar. Calma la mente; no hace que duermas.",
		{"usable": true, "use_effects": [_heal(0, 35, false, "El frío te sube por el brazo. Los ruidos se apagan un poco.")],
		"use_verb": "Inyectar", "sound_material": ItemDef.SoundMaterial.PLASTIC, "use_sound": "use_syringe_inject"})
	_item("destornillador", "Destornillador", ItemDef.Category.TOOL, Vector2i(1, 2), 1,
		"Destornillador de electricista con el mango agrietado. Aguantará unos pocos usos.",
		{"max_durability": 4, "sound_material": ItemDef.SoundMaterial.TOOL})
	_item("palanca", "Palanca", ItemDef.Category.TOOL, Vector2i(1, 3), 1,
		"Una palanca de hierro, pesada. Tiene pelo pegado en un extremo.",
		{"max_durability": 6, "sound_material": ItemDef.SoundMaterial.METAL_HEAVY, "weapon": weapons["crowbar"]})
	_item("fusible", "Fusible de alta tensión", ItemDef.Category.PART, Vector2i(1, 2), 1,
		"Cartucho cerámico con contactos de latón. Lleva escrito: «CUADRO GENERAL — SÓTANO».",
		{"key_item": true, "sound_material": ItemDef.SoundMaterial.CERAMIC})
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

	# [PROPUESTA] Tela y curas improvisadas (rasgar ropa y fabricar).
	_item("tela", "Tiras de tela", ItemDef.Category.MISC, Vector2i.ONE, 8,
		"Tiras arrancadas de una prenda. Sirven para atar, vendar o envolver algo.",
		{"sound_material": ItemDef.SoundMaterial.CLOTH})
	var rag: HealEffect = _heal(3, 0, true, "Enrollas las tiras sobre los puntos. Aguanta.")
	rag.contaminated_penalty = 3
	rag.contaminated_message = "La sangre se detiene, pero la tela no estaba limpia. Te pica la herida."
	_item("venda_improvisada", "Venda improvisada", ItemDef.Category.MEDICAL, Vector2i.ONE, 4,
		"Tiras de tela enrolladas. No están limpias: mejor pasarlas por desinfectante antes.",
		{"usable": true, "contaminated": true, "use_effects": [rag], "use_verb": "Vendar",
		"sound_material": ItemDef.SoundMaterial.CLOTH, "use_sound": "use_bandage_apply"})
	var cinch: HealEffect = _heal(0, 0, true, "Aprietas el nudo por encima de la herida hasta que duele. Deja de sangrar.")
	cinch.requires_bleeding = true
	_item("torniquete", "Torniquete", ItemDef.Category.MEDICAL, Vector2i.ONE, 2,
		"Una cinta gruesa de tela retorcida. No cura nada, pero corta la sangre sin tocar la herida.",
		{"usable": true, "use_effects": [cinch], "use_verb": "Apretar", "sound_material": ItemDef.SoundMaterial.CLOTH,
		"use_sound": "use_tourniquet_tighten"})

	# Armas. Cuchilla, barra y punzón vienen del prototipo de combate; el resto, [PROPUESTA].
	_item("cuchilla", "Cuchilla", ItemDef.Category.WEAPON, Vector2i(1, 2), 1,
		"Una cuchilla de cocina con el mango de madera hinchado por la humedad.",
		{"weapon": weapons["knife"], "sound_material": ItemDef.SoundMaterial.METAL_SMALL})
	_item("barra_hierro", "Barra de hierro", ItemDef.Category.WEAPON, Vector2i(1, 3), 1,
		"Hierro corrugado de obra, oxidado. Pesa lo suficiente para hacer daño.",
		{"weapon": weapons["iron_bar"], "sound_material": ItemDef.SoundMaterial.METAL_HEAVY})
	_item("punzon", "Punzón", ItemDef.Category.WEAPON, Vector2i(1, 2), 1,
		"Un punzón de zapatero con el mango de madera pulido por el uso.",
		{"weapon": weapons["awl"], "sound_material": ItemDef.SoundMaterial.TOOL})
	_item("bisturi", "Bisturí", ItemDef.Category.WEAPON, Vector2i(1, 2), 1,
		"Bisturí de acero con una hoja curva del número 22. Todavía tiene sangre seca en el filo.",
		{"weapon": weapons["scalpel"], "sound_material": ItemDef.SoundMaterial.METAL_SMALL})
	_item("tubo_metal", "Tubo de hierro", ItemDef.Category.WEAPON, Vector2i(1, 3), 1,
		"Un trozo de tubería arrancado de algún sitio, con la rosca a la vista. Resbala en la mano.",
		{"weapon": weapons["pipe"], "sound_material": ItemDef.SoundMaterial.METAL_HEAVY})
	_item("tubo_envuelto", "Tubo con mango envuelto", ItemDef.Category.WEAPON, Vector2i(1, 3), 1,
		"El tubo de hierro con tiras de tela apretadas en un extremo. Ya no resbala.",
		{"weapon": weapons["pipe_wrapped"], "sound_material": ItemDef.SoundMaterial.METAL_HEAVY})


func _build_recipes() -> void:
	_recipe("venda_esterilizada", "venda", "desinfectante", RecipeDef.Mode.PRODUCE, "venda_esterilizada",
		"Empapas la venda en desinfectante.")
	_recipe("limpiar_venda", "venda_sucia", "desinfectante", RecipeDef.Mode.PRODUCE, "venda",
		"Lavas la venda con desinfectante hasta que deja de oler. Servirá.")
	var recharge: RecipeDef = _recipe("recargar_linterna", "pilas", "linterna", RecipeDef.Mode.RECHARGE, "",
		"Cambias las pilas de la linterna. La luz vuelve a ser blanca.")
	recharge.consume_second = false
	recharge.charge_amount = 45.0
	recharge.sound = "use_battery_insert"
	ResourceSaver.save(recharge, RECIPES + "recargar_linterna.tres")
	_recipe("sedante", "jeringa", "ampolla", RecipeDef.Mode.PRODUCE, "sedante",
		"Cargas la jeringa con el contenido de la ampolla.")
	_recipe("reparar_valvula", "destornillador", "valvula_averiada", RecipeDef.Mode.PRODUCE, "valvula_reparada",
		"Aprietas los tornillos del asiento hasta que dejan de girar. La válvula queda firme.")
	# [PROPUESTA] Combinación y recetas de fabricar con tela.
	_recipe("desinfectar_venda_improvisada", "venda_improvisada", "desinfectante", RecipeDef.Mode.PRODUCE, "venda",
		"Empapas las tiras en desinfectante y las escurres. Ahora sí sirven.")
	_craft("venda_improvisada", "Venda improvisada", [["tela", 2]], "venda_improvisada", 1,
		"Enrollas dos tiras bien apretadas. No es una venda de verdad, pero tapa.", "craft_cloth")
	_craft("torniquete", "Torniquete", [["tela", 3]], "torniquete", 1,
		"Retuerces tres tiras hasta hacer una cinta gruesa y le das un nudo de lazo.", "craft_cloth")
	_craft("mango_envuelto", "Envolver el mango del tubo", [["tubo_metal", 1], ["tela", 2]], "tubo_envuelto", 1,
		"Enrollas las tiras alrededor de un extremo del tubo y las aprietas con un nudo. Ahora se agarra bien.",
		"craft_cloth")


func _heal(body: int, mind: int, stops: bool, message: String) -> HealEffect:
	var effect: HealEffect = HealEffect.new()
	effect.body = body
	effect.mind = mind
	effect.stops_bleeding = stops
	effect.requires_bleeding = stops and body < 10
	effect.message = message
	return effect


func _weapon(id: String, display: String, power: int, accuracy: int, type: CombatTypes.DamageType, two_handed: bool,
		crit: int) -> void:
	var w: WeaponDef = WeaponDef.new()
	w.display_name = display
	w.power = power
	w.accuracy = accuracy
	w.damage_type = type
	w.two_handed = two_handed
	w.crit_mod = crit
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WEAPONS))
	ResourceSaver.save(w, WEAPONS + id + ".tres")
	weapons[id] = load(WEAPONS + id + ".tres")


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
	if item.weapon != null:
		item.use_verb = "Empuñar"
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
	recipe.id = StringName(id)
	recipe.first = items[a]
	recipe.second = items[b]
	recipe.mode = mode
	if result != "":
		recipe.result = items[result]
	recipe.message = message
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RECIPES))
	ResourceSaver.save(recipe, RECIPES + id + ".tres")
	return recipe


## Receta de fabricar: `parts` es [[id, cantidad], …] (cantidad negativa = herramienta que no se gasta).
func _craft(id: String, display: String, parts: Array, result: String, amount: int, message: String,
		sound: String) -> void:
	var recipe: RecipeDef = RecipeDef.new()
	recipe.id = StringName(id)
	recipe.display_name = display
	recipe.mode = RecipeDef.Mode.CRAFT
	var list: Array[RecipeIngredient] = []
	for part: Array in parts:
		var n: int = int(part[1])
		list.append(RecipeIngredient.create(items[part[0]], absi(n), n < 0))
	recipe.ingredients = list
	recipe.result = items[result]
	recipe.result_quantity = amount
	recipe.message = message
	recipe.sound = sound
	ResourceSaver.save(recipe, RECIPES + id + ".tres")
