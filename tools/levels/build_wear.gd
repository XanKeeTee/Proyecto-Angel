extends Node
## Crea los objetos de ropa (data/items/<id>.tres) y la textura con normales de cada prenda
## puesta (assets/sprites/characters/wear/<id>_canvas.tres). Las hojas de la prenda las genera
## tools/art/character.py y los iconos tools/art/items.py.
## Uso: "$GODOT_BIN" --headless --path . res://tools/levels/build_wear.tscn
## Los textos son [PROPUESTA] (ver docs/lore/prologo.md).

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
	"chaqueta_celador": ["Chaqueta de celador", "body", Vector2i(2, 2), 0.3, "", 0.0,
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


func _ready() -> void:
	for id: String in garments:
		var g: Array = garments[id]
		var canvas: CanvasTexture = CanvasTexture.new()
		canvas.diffuse_texture = load(WEAR_DIR + id + ".png")
		canvas.normal_texture = load(WEAR_DIR + id + "_n.png")
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var canvas_path: String = WEAR_DIR + id + "_canvas.tres"
		ResourceSaver.save(canvas, canvas_path)
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
		item.wear_sheet = load(canvas_path)
		if ResourceLoader.exists(ITEMS_DIR + id + ".png"):
			item.icon = load(ITEMS_DIR + id + ".png")
		if ResourceLoader.exists(ITEMS_DIR + id + "_inspect.png"):
			item.inspect_sheet = load(ITEMS_DIR + id + "_inspect.png")
			item.inspect_views = 8
		ResourceSaver.save(item, "res://data/items/%s.tres" % id)
	print("Ropa creada: %d prendas." % garments.size())
	get_tree().quit()
