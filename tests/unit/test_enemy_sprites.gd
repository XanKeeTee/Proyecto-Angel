extends TestCase
## Hojas del enfermero (arte por capas): caben en una textura de Godot y la rejilla de fotogramas
## coincide con lo que describe sprite_meta.json.
## Bug corregido: con 68 fotogramas en una sola fila la hoja medía 17408 px de ancho, Godot no la
## cargaba (máximo 16384) y el enemigo salía invisible en combate.

const SPRITES_PATH: String = "res://data/enemies/enfermero_sprites.tres"
const META_PATH: String = "res://tools/art/sprite_meta.json"
const MAX_SIDE: int = 8192


func _meta() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	return (data as Dictionary).get("enemy_enfermero", {})


func test_las_hojas_caben_en_una_textura() -> void:
	var sprites: EnemySpriteDef = load(SPRITES_PATH)
	check(sprites != null, "existen las hojas horneadas")
	if sprites == null:
		return
	check(not sprites.layers.is_empty(), "hay capas")
	for key: StringName in sprites.layers:
		var texture: Texture2D = sprites.layers[key]
		check(texture != null, "la capa %s carga" % key)
		if texture != null:
			check(texture.get_width() <= MAX_SIDE and texture.get_height() <= MAX_SIDE,
					"la capa %s mide %dx%d" % [key, texture.get_width(), texture.get_height()])


func test_rejilla_igual_que_en_los_metadatos() -> void:
	var sprites: EnemySpriteDef = load(SPRITES_PATH)
	var meta: Dictionary = _meta()
	if sprites == null or meta.is_empty():
		check(false, "faltan las hojas o los metadatos")
		return
	check_eq(sprites.columns(), int(meta["hframes"]), "columnas")
	check_eq(sprites.rows(), int(meta["vframes"]), "filas")
	# Todas las animaciones caben en la rejilla.
	var cells: int = sprites.columns() * sprites.rows()
	for anim_name: StringName in sprites.anims:
		var a: Array = sprites.anims[anim_name]
		check(int(a[0]) + int(a[1]) <= cells, "la animación %s cabe en la rejilla" % anim_name)
	# Cada parte tiene su capa y su muñón.
	for part: StringName in [&"head", &"arm_l", &"arm_r", &"leg_l", &"leg_r"]:
		check(sprites.layers.has(part), "capa %s" % part)
		check(sprites.layers.has(StringName("stump_" + String(part))), "muñón de %s" % part)
