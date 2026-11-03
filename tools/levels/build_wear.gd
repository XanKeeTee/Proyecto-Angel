extends Node
## Crea los objetos de ropa (data/items/<id>.tres) y las texturas con normales de cada prenda
## puesta (assets/sprites/characters/wear/<id><sufijo>_canvas.tres, una por hoja: andar, con
## linterna, acciones, levantarse; ver tools/art/character.py). Los objetos guardan solo la RUTA
## de la hoja: se carga al ponérsela (Player.set_outfit). Los iconos los hace tools/art/items.py.
## Uso: "$GODOT_BIN" --headless --path . res://tools/levels/build_wear.tscn
## Los textos son [PROPUESTA] (ver docs/lore/prologo.md).

const META: String = "res://tools/art/sprite_meta.json"
const WEAR_DIR: String = "res://assets/sprites/characters/wear/"
const ITEMS_DIR: String = "res://assets/sprites/items/"
const S: Dictionary = {
	"head": ItemDef.EquipSlot.HEAD, "body": ItemDef.EquipSlot.BODY,
	"legs": ItemDef.EquipSlot.LEGS, "feet": ItemDef.EquipSlot.FEET,
}

## id: [nombre, ranura, casillas, balanceo, pisada, volumen, descripción]
var garments: Dictionary = {
	"bata_paciente": ["Bata de paciente", "body", Vector2i(2, 2), 1.0, "", 0.0,
		"La bata con la que despertaste. Tela fina, abierta por la espalda, con «09» bordado en el cuello. Huele a desinfectante y a algo más."],
	"chaqueta_celador": ["Chaqueta de celador", "body", Vector2i(2, 2), 0.35, "", 0.0,
		"Chaqueta de trabajo verde, con cremallera. Alguien arrancó la placa con el nombre del pecho. Abriga más que la bata."],
	"bata_medico": ["Bata de médico", "body", Vector2i(2, 2), 1.1, "", 0.0,
		"Bata blanca de manga larga. Los puños tienen manchas que no salieron en la lavadora."],
	"pantalon_pijama": ["Pantalón de pijama", "legs", Vector2i(1, 2), 0.0, "", 0.0,
		"Pantalón de pijama del hospital, a rayas. Lleva cosida una etiqueta: «CAMA 12»."],
	"pantalon_celador": ["Pantalón de celador", "legs", Vector2i(1, 2), 0.0, "", 0.0,
		"Pantalón de trabajo a juego con la chaqueta. Las rodillas están gastadas, como de arrodillarse mucho tiempo."],
	"zapatillas": ["Zapatillas", "feet", Vector2i(2, 1), 0.0, "step_soft", -13.0,
		"Zapatillas de tela con suela de goma. Con ellas los pasos apenas se oyen."],
	"botas_goma": ["Botas de goma", "feet", Vector2i(2, 2), 0.0, "step_boot", -8.0,
		"Botas altas de goma, de las que se usan para baldear suelos. Pesan y se oyen al pisar."],
	"gorro_quirurgico": ["Gorro quirúrgico", "head", Vector2i(1, 1), 0.0, "", 0.0,
		"Gorro de tela de quirófano. Tapa la cicatriz de la cabeza."],
	"gorro_lana": ["Gorro de lana", "head", Vector2i(1, 1), 0.0, "", 0.0,
		"Un gorro de lana oscuro, dado de sí. Por dentro hay un nombre escrito y tachado."],
}
## Prendas que se balancean: [cintura, bajo] en píxeles sobre los pies (en pantalla). El bajo
## es donde acaba la tela (ver los perfiles de tools/art/human.py): ahí se mueve del todo.
var cloth_heights: Dictionary = {
	"bata_paciente": Vector2(31.0, 16.0),
	"chaqueta_celador": Vector2(35.0, 25.0),
	"bata_medico": Vector2(31.0, 11.0),
}


func _ready() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(META)))
	var sheets: Dictionary = meta["protagonist"].get("sheets", {"move": {"suffix": ""}})
	for id: String in garments:
		var g: Array = garments[id]
		for sheet: String in sheets:
			var suffix: String = sheets[sheet]["suffix"]
			var png: String = WEAR_DIR + id + suffix + ".png"
			if not ResourceLoader.exists(png):
				continue
			var canvas: CanvasTexture = CanvasTexture.new()
			canvas.diffuse_texture = load(png)
			canvas.normal_texture = load(WEAR_DIR + id + suffix + "_n.png")
			canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ResourceSaver.save(canvas, WEAR_DIR + id + suffix + "_canvas.tres")
		var item: ItemDef = ItemDef.new()
		item.id = StringName(id)
		item.display_name = g[0]
		item.description = g[6]
		item.category = ItemDef.Category.CLOTHING
		item.equip_slot = S[g[1]]
		item.size = g[2]
		item.cloth_sway = g[3]
		item.step_sound = g[4]
		item.step_volume_db = g[5]
		item.wear_path = WEAR_DIR + id + "_canvas.tres"
		var heights: Vector2 = cloth_heights.get(id, Vector2(32.0, 14.0))
		item.cloth_waist = heights.x
		item.cloth_hem = heights.y
		if ResourceLoader.exists(ITEMS_DIR + id + ".png"):
			item.icon = load(ITEMS_DIR + id + ".png")
		if ResourceLoader.exists(ITEMS_DIR + id + "_inspect.png"):
			item.inspect_sheet = load(ITEMS_DIR + id + "_inspect.png")
			item.inspect_views = 8
		ResourceSaver.save(item, "res://data/items/%s.tres" % id)
	print("Ropa creada: %d prendas." % garments.size())
	get_tree().quit()
