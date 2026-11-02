class_name EnemySpriteDef
extends Resource
## Hojas de sprites por capas de un enemigo de combate (contrato con el arte).
##
## Una hoja PNG por capa (`body`, `head`, `arm_l`, `arm_r`, `leg_l`, `leg_r`, y `stump_<parte>` con el
## muñón que se ve cuando esa parte está amputada), todas con la misma rejilla de fotogramas.
## La descripción vive en tools/art/sprite_meta.json → clave del enemigo:
##   {"frame": [w, h], "origin": [x, y] (los pies), "layers": {capa: ruta}, "order": [capas de atrás
##   adelante], "anims": {"idle": [inicio, nº, fps, bucle], "windup", "attack", "hit", "stagger",
##   "death"}, "anchors": {parte: [x, y] centro de la parte en el fotograma de reposo}}
## Las normales, si existen, son `<capa>_n.png` junto a cada hoja.
## `tools/data/build_enemies.gd` lo hornea en un .tres; en desarrollo se puede leer del JSON.

## Capa que dibuja cada parte del cuerpo (el torso es el cuerpo base).
const PART_LAYERS: Dictionary[StringName, StringName] = {
	&"head": &"head", &"torso": &"body", &"arm_l": &"arm_l", &"arm_r": &"arm_r", &"leg_l": &"leg_l", &"leg_r": &"leg_r",
}
const STUMP_PREFIX: String = "stump_"

@export var frame: Vector2i = Vector2i(200, 260)
## Pies del enemigo dentro del fotograma.
@export var origin: Vector2i = Vector2i(100, 250)
@export var layers: Dictionary[StringName, Texture2D] = {}
@export var normals: Dictionary[StringName, Texture2D] = {}
## Capas de atrás adelante.
@export var order: Array[StringName] = []
## nombre → [inicio, nº de fotogramas, fps, bucle (0/1)].
@export var anims: Dictionary[StringName, Array] = {}
## parte → centro en el fotograma de reposo (píxeles desde la esquina del fotograma).
@export var anchors: Dictionary[StringName, Vector2] = {}


## Lee la descripción de `sprite_meta.json` (ya decodificada). Devuelve null si falta lo básico
## o no existe ninguna hoja.
static func from_meta(meta: Dictionary) -> EnemySpriteDef:
	if not meta.has("frame") or not meta.has("layers"):
		return null
	var def: EnemySpriteDef = EnemySpriteDef.new()
	var f: Array = meta["frame"]
	def.frame = Vector2i(int(f[0]), int(f[1]))
	var o: Array = meta.get("origin", [def.frame.x / 2, def.frame.y - 8])
	def.origin = Vector2i(int(o[0]), int(o[1]))
	var layer_paths: Dictionary = meta["layers"]
	for key: Variant in layer_paths:
		var path: String = _res_path(String(layer_paths[key]))
		if not ResourceLoader.exists(path):
			continue
		def.layers[StringName(key)] = load(path)
		var normal_path: String = path.get_basename() + "_n.png"
		if ResourceLoader.exists(normal_path):
			def.normals[StringName(key)] = load(normal_path)
	if def.layers.is_empty():
		return null
	for key: Variant in meta.get("order", layer_paths.keys()):
		def.order.append(StringName(key))
	var anim_data: Dictionary = meta.get("anims", {})
	for key: Variant in anim_data:
		var a: Array = anim_data[key]
		def.anims[StringName(key)] = [int(a[0]), int(a[1]), float(a[2]) if a.size() > 2 else 8.0,
				int(a[3]) if a.size() > 3 else 0]
	var anchor_data: Dictionary = meta.get("anchors", {})
	for key: Variant in anchor_data:
		var p: Array = anchor_data[key]
		def.anchors[StringName(key)] = Vector2(float(p[0]), float(p[1]))
	return def


## Lee `key` de un JSON de metadatos (p. ej. tools/art/sprite_meta.json). null si no está.
static func from_meta_file(path: String, key: String) -> EnemySpriteDef:
	if key == "" or not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has(key):
		return null
	return from_meta((data as Dictionary)[key])


static func _res_path(path: String) -> String:
	return path if path.begins_with("res://") else "res://" + path.trim_prefix("/")


## Columnas de la rejilla (todas las capas comparten rejilla).
func columns() -> int:
	for texture: Texture2D in layers.values():
		return maxi(1, texture.get_width() / frame.x)
	return 1


func rows() -> int:
	for texture: Texture2D in layers.values():
		return maxi(1, texture.get_height() / frame.y)
	return 1


func has_anim(anim_name: StringName) -> bool:
	return anims.has(anim_name)


## Centro de una parte relativo a los pies (origen), en píxeles. Si no hay ancla, una estimación.
func anchor_from_feet(part_id: StringName) -> Vector2:
	if anchors.has(part_id):
		return anchors[part_id] - Vector2(origin)
	var h: float = frame.y * 0.9
	var guess: Dictionary[StringName, Vector2] = {
		&"head": Vector2(0, -0.88 * h), &"torso": Vector2(0, -0.6 * h), &"arm_l": Vector2(0.22 * frame.x, -0.55 * h),
		&"arm_r": Vector2(-0.22 * frame.x, -0.55 * h), &"leg_l": Vector2(0.08 * frame.x, -0.2 * h),
		&"leg_r": Vector2(-0.08 * frame.x, -0.2 * h),
	}
	return guess.get(part_id, Vector2(0, -0.5 * h))
