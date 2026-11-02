extends Node
## Construye el hospital del prólogo (una sola escena) a partir de hospital_layout.json:
## tileset, paredes automáticas, puertas, escaleras, objetos interactuables, luces, eventos
## y el pasillo imposible.
## Uso: "$GODOT_BIN" --headless --path . res://tools/levels/build_hospital.tscn
## Después la escena se puede retocar en el editor; volver a ejecutar esto la sobrescribe.

const T: int = 32
const SRC: int = 0
const LAYOUT: String = "res://tools/levels/hospital_layout.json"
const META: String = "res://tools/art/sprite_meta.json"
const OUT_SCENE: String = "res://scenes/world/hospital/hospital.tscn"
const TILESET: String = "res://assets/tilesets/hospital_tileset.tres"

const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_PROPS: int = 4
const LAYER_ALL: int = 7

const CAP: Vector2i = Vector2i(0, 5)
const DOOR_CLOSED: Array[Vector2i] = [Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4), Vector2i(0, 10)]
const DOOR_OPEN: Array[Vector2i] = [Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4), Vector2i(1, 10)]
const STAIRS: Array[Vector2i] = [Vector2i(4, 7), Vector2i(4, 8), Vector2i(4, 9)]
const ELEVATOR: Array[Vector2i] = [Vector2i(3, 7), Vector2i(3, 8), Vector2i(3, 9)]
const EXIT_L: Array[Vector2i] = [Vector2i(6, 7), Vector2i(6, 8), Vector2i(6, 9)]
const EXIT_R: Array[Vector2i] = [Vector2i(7, 7), Vector2i(7, 8), Vector2i(7, 9)]
const X_HANDPRINT: Vector2i = Vector2i(1, 5)
const X_NOTICE: Vector2i = Vector2i(2, 5)
const X_MIRROR: Vector2i = Vector2i(3, 5)
const X_SCRATCH: Vector2i = Vector2i(4, 5)
const X_VENT: Vector2i = Vector2i(5, 5)
const X_WINDOW: Vector2i = Vector2i(6, 5)
const X_SMEAR: Vector2i = Vector2i(7, 5)
const X_SPEAKER: Vector2i = Vector2i(6, 10)
const DRESSING: GDScript = preload("res://tools/levels/hospital_dressing.gd")

var layout: Dictionary
var meta: Dictionary
var rooms: Dictionary = {}
var floor_room: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var scene_root: Node2D
var world: Node2D
var lights: Node2D
var decals: Node2D
var map: TileMapLayer
var tileset: TileSet
var events: Array[HorrorEvent] = []
var _canvas_cache: Dictionary = {}


func _ready() -> void:
	rng.seed = 909
	layout = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(LAYOUT)))
	meta = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(META)))
	for r: Dictionary in layout["rooms"]:
		rooms[r["id"]] = r
	tileset = _build_tileset()
	_build_scene()
	print("Hospital construido: %d objetos, %d eventos." % [scene_root.find_children("*", "Interactable", true, false).size(), events.size()])
	var packed: PackedScene = PackedScene.new()
	var err: Error = packed.pack(scene_root)
	if err != OK:
		push_error("pack: " + error_string(err))
	ResourceSaver.save(packed, OUT_SCENE)
	scene_root.free()
	get_tree().quit()


# --- tileset ---------------------------------------------------------------------------------------

func _build_tileset() -> TileSet:
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "solid")
	ts.set_custom_data_layer_type(0, TYPE_BOOL)
	ts.add_occlusion_layer()
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src: TileSetAtlasSource = TileSetAtlasSource.new()
	src.texture = _canvas("res://assets/tilesets/hospital.png")
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, SRC)
	var full: PackedVector2Array = [Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]
	var top_strip: PackedVector2Array = [Vector2(-16, -16), Vector2(16, -16), Vector2(16, -12), Vector2(-16, -12)]
	var mid_strip: PackedVector2Array = [Vector2(-3, -16), Vector2(3, -16), Vector2(3, 16), Vector2(-3, 16)]
	var walkable: Array[Vector2i] = [Vector2i(5, 4), Vector2i(4, 9), Vector2i(1, 10), Vector2i(3, 10), Vector2i(4, 10), Vector2i(5, 10)]
	for row: int in 11:
		for col: int in 8:
			var c: Vector2i = Vector2i(col, row)
			src.create_tile(c)
			var data: TileData = src.get_tile_data(c, 0)
			var solid: bool = not (row in [0, 1, 6]) and not walkable.has(c)
			data.set_custom_data("solid", solid)
			if solid:
				data.set_collision_polygons_count(0, 1)
				data.set_collision_polygon_points(0, 0, full)
			var occ: PackedVector2Array = []
			if c == CAP or c == Vector2i(0, 10):
				occ = full
			elif c == Vector2i(4, 2):
				occ = top_strip
			elif c == Vector2i(2, 10):
				occ = mid_strip
			if not occ.is_empty():
				var poly: OccluderPolygon2D = OccluderPolygon2D.new()
				poly.polygon = occ
				data.set_occluder_polygons_count(0, 1)
				data.set_occluder_polygon(0, 0, poly)
	ResourceSaver.save(ts, TILESET)
	return load(TILESET)


func _canvas(png: String) -> CanvasTexture:
	if _canvas_cache.has(png):
		return _canvas_cache[png]
	var tres: String = png.get_basename() + "_canvas.tres"
	var tex: CanvasTexture = CanvasTexture.new()
	tex.diffuse_texture = load(png)
	var normal_path: String = png.get_basename() + "_n.png"
	if ResourceLoader.exists(normal_path):
		tex.normal_texture = load(normal_path)
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ResourceSaver.save(tex, tres)
	_canvas_cache[png] = load(tres)
	return _canvas_cache[png]


# --- escena ------------------------------------------------------------------------------------------

func _build_scene() -> void:
	scene_root = Node2D.new()
	scene_root.name = "Hospital"
	scene_root.set_script(load("res://scenes/world/hospital/hospital.gd"))
	scene_root.set("start_cell", Vector2i(3, 23))
	scene_root.set("zone_tint", Color(0.9, 1.0, 0.96))

	var dark: CanvasModulate = CanvasModulate.new()
	dark.name = "Darkness"
	dark.color = Color(0.045, 0.045, 0.06)
	_add(scene_root, dark, true)

	map = TileMapLayer.new()
	map.name = "Map"
	map.tile_set = tileset
	_add(scene_root, map, true)
	_paint_rooms()
	_paint_walls()

	var impossible: TileMapLayer = TileMapLayer.new()
	impossible.name = "Impossible"
	impossible.tile_set = tileset
	impossible.visible = false
	impossible.collision_enabled = false
	_add(scene_root, impossible, true)
	_paint_impossible(impossible)

	decals = Node2D.new()
	decals.name = "Decals"
	_add(scene_root, decals)

	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	_add(scene_root, world, true)

	lights = Node2D.new()
	lights.name = "Lights"
	_add(scene_root, lights, true)

	_build_doors()
	_build_fixtures_on_walls()
	_build_content()
	_build_impossible_content()
	_build_lights()
	_build_decals()

	var player: Node2D = load("res://scenes/world/player/player.tscn").instantiate()
	player.name = "Player"
	world.add_child(player)
	player.owner = scene_root
	player.unique_name_in_owner = true

	var director: EventDirector = EventDirector.new()
	director.name = "Events"
	_build_events()
	director.events = events
	_add(scene_root, director, true)

	var ambience: AudioStreamPlayer = AudioStreamPlayer.new()
	ambience.name = "Ambience"
	ambience.stream = load("res://assets/audio/sfx/ambience_loop.wav")
	ambience.volume_db = -10.0
	ambience.bus = &"Ambiente"
	_add(scene_root, ambience, true)

	var fade_layer: CanvasLayer = CanvasLayer.new()
	fade_layer.name = "FadeLayer"
	fade_layer.layer = 15
	_add(scene_root, fade_layer)
	var fade: ColorRect = ColorRect.new()
	fade.name = "Fade"
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_add(fade_layer, fade, true)


func _add(parent: Node, child: Node, unique: bool = false) -> void:
	parent.add_child(child)
	child.owner = scene_root
	if unique:
		child.unique_name_in_owner = true


# --- suelos y paredes ---------------------------------------------------------------------------------

func _rect(room_id: String) -> Rect2i:
	var r: Array = rooms[room_id]["rect"]
	return Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))


func _floor_tile(kind: String) -> Vector2i:
	match kind:
		"room": return Vector2i([0, 0, 0, 0, 0, 1, 1, 2, 7].pick_random(), 0)
		"lino": return Vector2i([0, 0, 0, 0, 6, 6, 1, 7, 2].pick_random(), 1)
		"wood": return Vector2i(6, 6)
		"terrazzo": return Vector2i(7, 6)
		"or": return Vector2i(4, 6) if rng.randf() < 0.8 else Vector2i(5, 6)
		"concrete": return Vector2i([0, 0, 0, 1, 2, 3].pick_random(), 6)
	return Vector2i(0, 0)


func _paint_rooms() -> void:
	seed(909)
	for id: String in rooms:
		var r: Rect2i = _rect(id)
		for y: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				var c: Vector2i = Vector2i(x, y)
				floor_room[c] = id
				map.set_cell(c, SRC, _floor_tile(rooms[id]["floor"]))


func _wall_column(style: String, x: int) -> int:
	match style:
		"or": return 5
		"basement": return [0, 0, 1, 1, 2][posmod(x * 7 + 3, 5)]
	return [0, 0, 1, 2, 3][posmod(x * 13 + 5, 5)]


func _paint_walls() -> void:
	var faces: Dictionary = {}
	var bounds: Rect2i = Rect2i(-2, -2, 80, 64)
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var c: Vector2i = Vector2i(x, y)
			if floor_room.has(c):
				continue
			for k: int in [1, 2, 3]:
				var below: Vector2i = c + Vector2i(0, k)
				var clear: bool = true
				for j: int in range(1, k):
					if floor_room.has(c + Vector2i(0, j)):
						clear = false
				if clear and floor_room.has(below):
					var style: String = rooms[floor_room[below]]["walls"]
					var row_base: int = 7 if style in ["or", "basement"] else 2
					faces[c] = Vector2i(_wall_column(style, x), row_base + (3 - k))
					break
	for c: Vector2i in faces:
		map.set_cell(c, SRC, faces[c])
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var c: Vector2i = Vector2i(x, y)
			if floor_room.has(c) or faces.has(c):
				continue
			var near: bool = false
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					var n: Vector2i = c + Vector2i(dx, dy)
					if floor_room.has(n) or faces.has(n):
						near = true
			if near:
				map.set_cell(c, SRC, CAP)


## Coloca un tile extra en la pared norte de una sala (fila 0 alto, 1 medio, 2 bajo).
func _wall_extra(room_id: String, x: int, row: int, tile: Vector2i) -> void:
	var r: Rect2i = _rect(room_id)
	map.set_cell(Vector2i(x, r.position.y - 3 + row), SRC, tile)


# --- puertas ---------------------------------------------------------------------------------------------

const DOOR_NAMES: Dictionary = {
	"hab07": "Puerta de la habitación 07", "hab08": "Puerta de la habitación 08", "hab10": "Puerta de la habitación 10",
	"hab11": "Puerta de la habitación 11", "enfermeria": "Puerta de la enfermería", "archivo": "Puerta del archivo",
	"escalera": "Puerta de la escalera de servicio", "vestibulo": "Puerta del vestíbulo", "hab09": "Puerta de la habitación 09",
	"hab12": "Puerta de la habitación 12", "almacen": "Puerta del almacén", "banos": "Puerta de los baños",
	"control": "Puerta del control de enfermería", "quirofano": "Puerta del quirófano", "recepcion": "Puerta de recepción",
	"b_escalera": "Puerta de la escalera", "b_electrica": "Puerta de la sala eléctrica", "b_lavanderia": "Puerta de la lavandería",
	"b_morgue": "Puerta de la morgue", "b_calderas": "Puerta de la sala de calderas", "b_taller": "Puerta del taller",
}


func _build_doors() -> void:
	for d: Dictionary in layout["doors"]:
		var room: Rect2i = _rect(d["room"])
		var corridor: Rect2i = _rect(d["from"])
		var lower: Rect2i = corridor if room.position.y < corridor.position.y else room
		var x: int = int(d["x"])
		var base: Vector2i = Vector2i(x, lower.position.y - 1)
		var door: Door = Door.new()
		door.name = "Door_" + d["id"]
		door.object_id = StringName(d["id"])
		door.display_name = DOOR_NAMES.get(d["room"], "Puerta")
		door.position = _center(base)
		door.footprint = [Vector2i.ZERO]
		door.blocks = false
		door.tile_cells = [Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, -3)]
		door.closed_tiles = DOOR_CLOSED
		door.open_tiles = DOOR_OPEN
		door.back_cell = Vector2i(0, -3)
		door.warp_front_to = base + Vector2i(0, -4)
		door.warp_front_facing = Vector2i.UP
		door.warp_back_to = base + Vector2i(0, 1)
		door.warp_back_facing = Vector2i.DOWN
		door.examine_text = "Una puerta de hospital, de metal pintado. La pintura está levantada a la altura de las manos."
		door.sound_open = load("res://assets/audio/sfx/door_open.wav")
		door.sound_close = load("res://assets/audio/sfx/door_close.wav")
		door.sound_locked = load("res://assets/audio/sfx/door_locked.wav")
		if d.has("key"):
			door.start_locked = true
			door.key_item = load("res://data/items/%s.tres" % d["key"])
			door.locked_text = "Cerrada con llave."
			door.unlock_text = "La llave gira con esfuerzo. Se queda puesta en la cerradura."
		if d.has("jammed"):
			door.start_locked = true
			door.locked_text = "No está cerrada con llave: algo la atasca por dentro. Cede un dedo y vuelve."
			door.examine_text = "La puerta del quirófano. El marco está deformado, como si la hubieran empujado desde dentro."
			var use: ItemUse = ItemUse.new()
			use.item = load("res://data/items/%s.tres" % d["jammed"])
			use.label = "Forzar con la palanca"
			use.opens = true
			use.consumes_item = true
			use.sets_flag = &"quirofano_abierto"
			use.text = "Metes la palanca en la ranura y empujas con todo el cuerpo. La puerta cede con un chasquido.\nLa palanca se queda encajada en el marco."
			door.item_uses = [use]
		_add(world, door)
		for i: int in door.tile_cells.size():
			map.set_cell(base + door.tile_cells[i], SRC, DOOR_CLOSED[i])
	for s: Dictionary in layout["stairs"]:
		var r: Rect2i = _rect(s["room"])
		var base: Vector2i = Vector2i(int(s["x"]), r.position.y - 1)
		var stairs: Door = Door.new()
		stairs.name = "Stairs_" + s["id"]
		stairs.object_id = StringName(s["id"])
		stairs.display_name = "Escalera"
		stairs.position = _center(base)
		stairs.blocks = false
		stairs.always_open = true
		stairs.start_open = true
		stairs.tile_cells = [Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 0)]
		stairs.closed_tiles = STAIRS
		stairs.open_tiles = STAIRS
		var to: Array = s["to"]
		stairs.warp_front_to = Vector2i(int(to[0]), int(to[1]))
		stairs.warp_front_facing = Vector2i.DOWN
		stairs.examine_text = "Escaleras de hormigón. Bajan hacia el sótano." if s["id"] == "escalera_bajar" else "La escalera sube hacia la planta 3."
		_add(world, stairs)
		for i: int in 3:
			map.set_cell(base + stairs.tile_cells[i], SRC, STAIRS[i])


func _center(c: Vector2i) -> Vector2:
	return Vector2(c * T) + Vector2(T / 2.0, T / 2.0)


# --- objetos -----------------------------------------------------------------------------------------------

func _item(id: String) -> ItemDef:
	return load("res://data/items/%s.tres" % id)


func _doc(id: String) -> DocumentDef:
	return load("res://data/documents/%s.tres" % id)


func _snd(name: String) -> AudioStream:
	return load("res://assets/audio/sfx/%s.wav" % name)


## Crea un Interactable a partir de un diccionario (ver claves abajo).
func obj(s: Dictionary) -> Interactable:
	var it: Interactable = Interactable.new()
	var cell: Vector2i = Vector2i(s["cell"][0], s["cell"][1])
	it.name = s.get("node", s["id"])
	it.object_id = StringName(s["id"])
	it.display_name = s["name"]
	it.position = _center(cell)
	var fp: Array[Vector2i] = []
	for f: Array in s.get("fp", [[0, 0]]):
		fp.append(Vector2i(f[0], f[1]))
	it.footprint = fp
	var icells: Array[Vector2i] = []
	for f: Array in s.get("icells", []):
		icells.append(Vector2i(f[0], f[1]))
	it.interact_cells = icells
	var kinds: Dictionary = {"fixture": Interactable.Kind.FIXTURE, "container": Interactable.Kind.CONTAINER,
		"pickup": Interactable.Kind.PICKUP, "readable": Interactable.Kind.READABLE, "device": Interactable.Kind.DEVICE}
	it.kind = kinds[s.get("kind", "fixture")]
	it.blocks = s.get("blocks", s.has("sprite") and not String(s.get("sprite", "")).begins_with("decal") and it.kind != Interactable.Kind.PICKUP and it.kind != Interactable.Kind.READABLE)
	it.examine_text = s.get("examine", "")
	it.examine_open_text = s.get("examine_open", "")
	it.examine_done_text = s.get("examine_done", "")
	it.search_text = s.get("search", "")
	it.empty_text = s.get("empty", "No hay nada.")
	it.locked_text = s.get("locked_text", "Está cerrado con llave.")
	it.unlock_text = s.get("unlock_text", "")
	it.blocked_text = s.get("blocked", "")
	it.search_verb = s.get("verb", "Registrar")
	it.openable = s.get("openable", false)
	it.start_open = s.get("open", false)
	it.start_locked = s.get("locked", false)
	if s.has("key"):
		it.key_item = _item(s["key"])
	it.requires_flag = StringName(s.get("requires", ""))
	var loot: Array[LootEntry] = []
	for entry: Variant in s.get("loot", []):
		var le: LootEntry = LootEntry.new()
		if entry is String and String(entry).begins_with("doc:"):
			le.document = _doc(String(entry).trim_prefix("doc:"))
		else:
			le.item = _item(entry[0])
			le.quantity = int(entry[1])
		loot.append(le)
	it.contents = loot
	if s.has("doc"):
		it.document = _doc(s["doc"])
	var uses: Array[ItemUse] = []
	for u: Dictionary in s.get("uses", []):
		var use: ItemUse = ItemUse.new()
		use.item = _item(u["item"])
		use.label = u.get("label", "")
		use.consumes_item = u.get("consumes", false)
		use.uses_durability = u.get("durability", false)
		use.opens = u.get("opens", false)
		use.unlocks = u.get("unlocks", false)
		use.sets_flag = StringName(u.get("flag", ""))
		use.text = u.get("text", "")
		use.frame_after = u.get("frame", -1)
		var req: Array[StringName] = []
		for f: String in u.get("requires", []):
			req.append(StringName(f))
		use.requires_flags = req
		uses.append(use)
	it.item_uses = uses
	it.device_label = s.get("device_label", "Usar")
	it.device_text = s.get("device_text", "")
	it.device_once = s.get("device_once", false)
	it.device_special = StringName(s.get("special", ""))
	it.flag_on_open = StringName(s.get("flag_open", ""))
	it.flag_on_search = StringName(s.get("flag_search", ""))
	it.flag_on_examine = StringName(s.get("flag_examine", ""))
	it.frame_closed = s.get("frame", 0)
	it.frame_open = s.get("frame_open", 1 if it.openable else s.get("frame", 0))
	it.frame_empty = s.get("frame_empty", -1)
	var sounds: Dictionary = s.get("sounds", {})
	if it.openable and sounds.is_empty():
		sounds = {"open": "drawer_open", "close": "drawer_close", "locked": "door_locked"}
	if sounds.has("open"):
		it.sound_open = _snd(sounds["open"])
	if sounds.has("close"):
		it.sound_close = _snd(sounds["close"])
	if sounds.has("locked"):
		it.sound_locked = _snd(sounds["locked"])
	it.sound_take = _snd(sounds.get("take", "pickup"))
	var item_for_inspect: String = s.get("inspect", "")
	if item_for_inspect != "":
		var def: ItemDef = _item(item_for_inspect)
		it.inspect_sheet = def.inspect_sheet
		it.inspect_views = def.inspect_views
	_add(world, it)
	it.start_hidden = s.get("hidden", false)
	var sprite_key: String = s.get("sprite", "")
	if sprite_key != "":
		var sprite: Sprite2D = _sprite(sprite_key)
		sprite.frame = it.frame_closed
		_add(it, sprite)
		for child: Node in sprite.get_children():
			child.owner = scene_root
	if it.blocks and s.has("sprite"):
		_add_body(it, fp)
	if s.has("shadow"):
		var r: Array = s["shadow"]
		var occ: OccluderPolygon2D = OccluderPolygon2D.new()
		occ.polygon = PackedVector2Array([Vector2(r[0], r[1]), Vector2(r[0] + r[2], r[1]), Vector2(r[0] + r[2], r[1] + r[3]), Vector2(r[0], r[1] + r[3])])
		var o: LightOccluder2D = LightOccluder2D.new()
		o.name = "Shadow"
		o.occluder = occ
		_add(it, o)
	for g: String in s.get("groups", []):
		it.add_to_group(StringName(g), true)
	return it


func _add_body(it: Interactable, fp: Array[Vector2i]) -> void:
	var area: Rect2 = Rect2(Vector2(fp[0] * T), Vector2.ZERO)
	for c: Vector2i in fp:
		area = area.merge(Rect2(Vector2(c * T), Vector2.ZERO))
	area = Rect2(area.position - Vector2(12, 12), area.size + Vector2(24, 24))
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	_add(it, body)
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = area.size
	shape.shape = rect
	shape.position = area.get_center()
	_add(body, shape)


func _sprite(key: String) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.light_mask = LAYER_PROPS
	if key.begins_with("decal:"):
		var d: Dictionary = meta["decals"]
		sprite.texture = _canvas(d["path"])
		sprite.hframes = int(d["hframes"])
		sprite.frame = (d["names"] as Array).find(key.trim_prefix("decal:"))
		sprite.light_mask = LAYER_WORLD
		return sprite
	if key.begins_with("item:"):
		var def: ItemDef = _item(key.trim_prefix("item:"))
		sprite.texture = def.icon
		sprite.offset = Vector2(0, 4)
		return sprite
	var m: Dictionary = meta[key]
	sprite.texture = _canvas(m["path"])
	sprite.hframes = int(m["hframes"])
	sprite.vframes = int(m["vframes"])
	var frame: Array = m["frame"]
	var origin: Array = m["origin"]
	var anchor: Array = m["anchor"]
	sprite.offset = Vector2(anchor[0] - origin[0] + frame[0] / 2.0, anchor[1] - origin[1] + frame[1] / 2.0)
	if m["glow"]:
		var glow: Sprite2D = Sprite2D.new()
		glow.name = "Glow"
		glow.texture = load(String(m["path"]).get_basename() + "_glow.png")
		glow.hframes = sprite.hframes
		glow.vframes = sprite.vframes
		glow.offset = sprite.offset
		var unshaded: CanvasItemMaterial = CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		glow.material = unshaded
		sprite.add_child(glow)
	return sprite


# --- contenido de cada sala ----------------------------------------------------------------------------------

const BED2: Array = [[0, 0], [0, -1]]
const WIDE: Array = [[0, 0], [1, 0]]
const BED_SHADOW: Array = [-12, -44, 24, 56]


func _bed(id: String, name: String, cell: Array, frame: int, extra: Dictionary) -> Interactable:
	var s: Dictionary = {"id": id, "name": name, "sprite": "stretcher", "cell": cell, "fp": BED2, "frame": frame,
		"kind": "container", "shadow": BED_SHADOW, "sounds": {"take": "pickup"}}
	s.merge(extra, true)
	return obj(s)


func _build_content() -> void:
	_room_hab09()
	_room_hab07()
	_room_hab08()
	_room_hab10()
	_room_hab11()
	_room_hab12()
	_room_almacen()
	_room_banos()
	_room_control()
	_room_enfermeria()
	_room_quirofano()
	_room_archivo()
	_room_escalera()
	_room_vestibulo()
	_room_recepcion()
	_room_pasillo()
	_basement()


func _room_hab09() -> void:
	_bed("cama_09", "Tu cama", [2, 23], 1, {"node": "Stretcher09", "verb": "Mirar a los pies",
		"examine": "Tu cama. Las correas están desabrochadas. Alguien las soltó.",
		"examine_done": "Hay una mancha donde tenías la espalda. Tiene la forma de una columna.",
		"search": "A los pies de la cama cuelga una hoja de constantes con tu número.
Debajo de la cama, unas zapatillas de tela.",
		"loot": ["doc:hoja_constantes", ["zapatillas", 1]],
		"empty": ""})
	obj({"id": "mesita_09", "name": "Mesita", "sprite": "nightstand", "cell": [3, 22], "kind": "container", "openable": true,
		"examine": "Una mesita de hospital con un vaso de agua. El agua tiene una película de polvo.",
		"search": "En el cajón hay una linterna. Tiene un número grabado en el mango: 09.
Debajo, un par de pilas de repuesto.",
		"loot": [["linterna", 1], ["pilas", 2]],
		"flag_search": "linterna_cogida", "empty": "El cajón está vacío."})
	obj({"id": "monitor_09", "name": "Monitor", "sprite": "monitor", "cell": [1, 22],
		"examine": "El monitor sigue encendido. Los cables cuelgan sueltos, pero la línea verde sigue latiendo.\nAl ritmo de tu pulso.",
		"shadow": [-6, -4, 12, 8]})
	obj({"id": "gotero_09", "name": "Gotero", "sprite": "iv_stand", "cell": [1, 24],
		"examine": "La bolsa del gotero está vacía. La aguja todavía tiene sangre. Tu sangre."})
	obj({"id": "taquilla_09", "name": "Taquilla", "sprite": "locker", "cell": [6, 21], "kind": "container", "openable": true,
		"examine": "Una taquilla con tu número.", "empty": "Tu ropa no está. Solo queda una percha doblada hacia dentro.",
		"sounds": {"open": "locker_open", "close": "door_close"}, "shadow": [-13, -14, 26, 12]})
	obj({"id": "lavabo_09", "name": "Lavabo", "sprite": "sink", "cell": [5, 21],
		"examine": "El espejo está roto desde dentro hacia fuera. En los trozos que quedan no consigues encontrarte."})
	obj({"id": "papelera_09", "name": "Papelera", "sprite": "trash_bin", "cell": [7, 27], "kind": "container",
		"examine": "Una papelera llena de gasas.", "search": "Entre las gasas usadas hay una venda casi entera.",
		"loot": [["venda_sucia", 1]], "empty": "Solo gasas empapadas. Prefieres no tocarlas más.", "shadow": [-6, -6, 12, 12]})
	obj({"id": "cortina_09", "name": "Cortina", "sprite": "curtain", "cell": [4, 25], "fp": WIDE,
		"examine": "Una cortina separadora. El bajo está empapado de algo oscuro que no se ha secado.", "shadow": [-12, -2, 42, 4]})
	obj({"id": "bandeja_09", "name": "Bandeja de instrumental", "sprite": "tray", "cell": [6, 24],
		"examine": "Instrumental quirúrgico, limpio y en orden. Falta una pieza en el centro: queda su silueta en sangre.",
		"shadow": [-12, -7, 24, 14]})
	_wall_extra("hab09", 5, 1, X_MIRROR)
	_wall_extra("hab09", 2, 1, X_HANDPRINT)


func _room_hab07() -> void:
	_bed("cama_07", "Cama", [2, 6], 3, {"examine": "Una cama deshecha. El colchón conserva la forma de alguien que no estaba quieto.",
		"search": "Debajo de la almohada hay una carta doblada muchas veces.", "loot": ["doc:carta_sin_enviar"],
		"empty": "Las sábanas están frías."})
	obj({"id": "mesita_07", "name": "Mesita", "sprite": "nightstand", "cell": [3, 5], "kind": "container", "openable": true,
		"examine": "Una mesita con marcas de uñas en el borde.", "empty": "El cajón está vacío, salvo por unas uñas cortadas."})
	obj({"id": "taquilla_07", "name": "Taquilla", "sprite": "locker", "cell": [6, 4], "kind": "container", "openable": true,
		"examine": "Una taquilla abollada a puñetazos.", "search": "Entre ropa de otra persona hay un blíster con pilas y un gorro de lana.",
		"loot": [["pilas", 2], ["gorro_lana", 1]], "sounds": {"open": "locker_open", "close": "door_close"}, "shadow": [-13, -14, 26, 12]})
	obj({"id": "silla_07", "name": "Silla", "sprite": "chair", "cell": [6, 8],
		"examine": "Una silla junto a la cama. El asiento está hundido: alguien se sentó aquí mucho tiempo.", "shadow": [-7, -7, 14, 14]})
	_wall_extra("hab07", 5, 1, X_WINDOW)
	obj({"id": "ventana_07", "name": "Ventana", "cell": [5, 3], "blocks": false,
		"examine": "La ventana da a un patio interior. Enfrente, todas las ventanas del otro ala están encendidas.\nTodas menos una. En esa hay alguien mirando hacia aquí.",
		"flag_examine": "vio_ventana"})


func _room_hab08() -> void:
	_bed("cama_08", "Cama", [10, 6], 0, {"node": "Bed08", "examine": "Las correas están abrochadas. Sobre nadie.",
		"verb": "Registrar", "empty": "Nada. Las sábanas están tirantes, recién hechas."})
	obj({"id": "mesita_08", "name": "Mesita", "sprite": "nightstand", "cell": [11, 5], "kind": "container", "openable": true,
		"examine": "Una mesita.", "search": "Un bote de comprimidos sin etiqueta.", "loot": [["analgesicos", 2]],
		"empty": "Vacío."})
	obj({"id": "foto_08", "name": "Fotografía", "sprite": "decal:papers", "cell": [14, 7], "kind": "readable",
		"doc": "foto_personal", "search": "", "examine": "Una fotografía en el suelo, boca abajo."})
	obj({"id": "gotero_08", "name": "Gotero", "sprite": "iv_stand", "cell": [14, 4], "examine": "Un gotero sin bolsa."})
	obj({"id": "silla_ruedas_08", "name": "Silla de ruedas", "sprite": "wheelchair", "cell": [13, 9],
		"examine": "Volcada. Una rueda gira todavía, muy despacio.", "shadow": [-12, -8, 24, 16]})


func _room_hab10() -> void:
	_bed("cama_10", "Cama", [18, 6], 4, {"examine": "Las correas están rotas. No desabrochadas: rotas, desde dentro.",
		"empty": "La sábana está rígida de algo seco."})
	obj({"id": "diario_10", "name": "Cuaderno", "sprite": "decal:papers", "cell": [20, 8], "kind": "readable",
		"doc": "diario_paciente", "examine": "Un cuaderno abierto en el suelo."})
	obj({"id": "taquilla_10", "name": "Taquilla", "sprite": "locker", "cell": [22, 4], "kind": "container", "openable": true,
		"examine": "Una taquilla. Alguien escribió dentro, en la puerta: «412».",
		"search": "Material de enfermería escondido entre la ropa.", "loot": [["jeringa", 2], ["ampolla", 1]],
		"sounds": {"open": "locker_open", "close": "door_close"}, "shadow": [-13, -14, 26, 12]})
	obj({"id": "mesita_10", "name": "Mesita", "sprite": "nightstand", "cell": [19, 5], "kind": "container", "openable": true,
		"examine": "Una mesita.", "search": "Una pila suelta, rodando en el cajón.", "loot": [["pilas", 1]], "empty": "Vacío."})


func _room_hab11() -> void:
	_bed("cama_11", "Cama", [26, 6], 3, {"node": "Bed11", "examine": "La cama de una habitación vacía desde marzo. Las sábanas están revueltas.",
		"search": "Sobre el colchón hay una llave pequeña. El colchón todavía está caliente.", "loot": [["llave_botiquin", 1]],
		"flag_search": "llave_botiquin_cogida", "empty": "El hueco de un cuerpo en el colchón. Caliente."})
	obj({"id": "mesita_11", "name": "Mesita", "sprite": "nightstand", "cell": [27, 5], "kind": "container", "openable": true,
		"examine": "Una mesita.", "empty": "Vacío. Huele a alguien."})
	obj({"id": "monitor_11", "name": "Monitor", "sprite": "monitor", "cell": [30, 4],
		"examine": "Un monitor apagado. En la pantalla, el reflejo de la habitación tiene una persona en la cama.\nLa cama, a tu espalda, está vacía."})


func _room_hab12() -> void:
	_bed("cama_12", "Cama", [10, 23], 3, {"examine": "Una cama deshecha.",
		"search": "Debajo de la almohada, una llave con una chapa de plástico mordida: «10».", "loot": [["llave_habitacion_10", 1]],
		"empty": "Nada más."})
	obj({"id": "mesita_12", "name": "Mesita", "sprite": "nightstand", "cell": [11, 22], "kind": "container", "openable": true,
		"examine": "Una mesita.", "search": "Una venda en su envoltorio y un pantalón de pijama doblado.",
		"loot": [["venda", 1], ["pantalon_pijama", 1]], "empty": "Vacío."})
	obj({"id": "taquilla_12", "name": "Taquilla", "sprite": "locker", "cell": [15, 21], "kind": "container", "openable": true,
		"examine": "Una taquilla.", "empty": "Una bata doblada con una mancha en la espalda. No es la tuya.",
		"sounds": {"open": "locker_open", "close": "door_close"}, "shadow": [-13, -14, 26, 12]})
	obj({"id": "cortina_12", "name": "Cortina", "sprite": "curtain", "cell": [12, 25], "fp": WIDE,
		"examine": "Detrás de la cortina no hay nada. Solo el sitio donde habría otra cama.", "shadow": [-12, -2, 42, 4]})


func _room_almacen() -> void:
	obj({"id": "taquilla_almacen", "name": "Armario de limpieza", "sprite": "locker", "cell": [17, 21], "kind": "container",
		"openable": true, "examine": "Un armario metálico de limpieza.",
		"search": "Detrás de las fregonas, apoyada en el fondo, hay una palanca de hierro.", "loot": [["palanca", 1]],
		"sounds": {"open": "locker_open", "close": "door_close"}, "shadow": [-13, -14, 26, 12]})
	obj({"id": "estanteria_almacen", "name": "Estantería", "sprite": "shelf", "cell": [20, 21], "fp": WIDE, "kind": "container",
		"frame": 0, "examine": "Cajas de productos de limpieza.", "search": "Un frasco de desinfectante, medio vacío.",
		"loot": [["desinfectante", 1]], "empty": "Cajas vacías y bolsas de basura dobladas."})
	obj({"id": "cubo_almacen", "name": "Cubo de fregar", "sprite": "mop_bucket", "cell": [21, 25],
		"examine": "Agua negra. Huele a hierro."})
	obj({"id": "cajas_almacen", "name": "Cajas", "sprite": "crates", "cell": [18, 26], "examine": "Cajas de guantes. Todas abiertas, todas vacías."})


func _room_banos() -> void:
	obj({"id": "lavabo_banos_1", "name": "Lavabo", "sprite": "sink", "cell": [23, 21],
		"examine": "El grifo gotea. Cada gota suena demasiado fuerte."})
	obj({"id": "lavabo_banos_2", "name": "Lavabo", "sprite": "sink", "cell": [27, 21],
		"examine": "El espejo está roto. En el lavabo hay pelo, mucho. Del mismo largo que el que tenías."})
	_wall_extra("banos", 23, 1, X_MIRROR)
	_wall_extra("banos", 27, 1, X_MIRROR)
	obj({"id": "papelera_banos", "name": "Papelera", "sprite": "trash_bin", "cell": [28, 27], "kind": "container",
		"examine": "Una papelera.", "search": "Entre papel mojado hay una pila.", "loot": [["pilas", 1]], "empty": "Papel mojado."})
	obj({"id": "botiquin_banos", "name": "Botiquín", "sprite": "med_cabinet", "cell": [26, 21], "kind": "container", "openable": true,
		"examine": "Un botiquín de pared con la cruz roja medio despegada.", "search": "Un bote de analgésicos.",
		"loot": [["analgesicos", 1]], "empty": "Vacío."})


func _room_control() -> void:
	obj({"id": "mostrador_control", "name": "Mostrador", "sprite": "counter", "cell": [31, 23], "fp": WIDE, "icells": [[0, 0]],
		"kind": "container", "openable": true, "examine": "El mostrador del control. Hay una taza con el café helado.",
		"search": "En el armario de abajo, medicación suelta. Colgada en la puerta, una bata blanca.",
		"loot": [["analgesicos", 2], ["bata_medico", 1]], "empty": "Carpetas vacías."})
	obj({"id": "telefono_control", "name": "Teléfono", "sprite": "phone", "cell": [32, 23], "kind": "device", "blocks": false,
		"examine": "Un teléfono de baquelita. El cable está enrollado como si alguien hubiera tirado de él.",
		"device_label": "Descolgar", "special": "phone"})
	obj({"id": "escritorio_control", "name": "Escritorio", "sprite": "desk", "cell": [34, 25], "fp": WIDE, "icells": [[1, 0]],
		"kind": "container", "openable": true, "examine": "El escritorio de la supervisora.",
		"search": "En el cajón de arriba, una nota doblada.", "loot": ["doc:nota_enfermera"], "empty": "Bolígrafos secos.",
		"shadow": [-14, -12, 60, 24]})
	obj({"id": "ordenador_control", "name": "Ordenador", "sprite": "computer", "cell": [34, 25], "kind": "device", "blocks": false,
		"examine": "Un ordenador viejo.", "requires": "power_on", "blocked": "Está apagado. No hay corriente.",
		"device_label": "Mirar la pantalla", "groups": ["computers"],
		"device_text": "En la pantalla, una sola línea parpadea:\n«PLANTA 3 · 1 PACIENTE · ESTADO: CONSCIENTE · PROTOCOLO: EN CURSO»"})
	obj({"id": "parte_control", "name": "Hoja", "sprite": "decal:papers", "cell": [36, 27], "kind": "readable",
		"doc": "parte_turno", "examine": "Una hoja arrugada en el suelo."})
	obj({"id": "grabadora_control", "name": "Grabadora de cinta", "sprite": "tape_recorder", "cell": [30, 27], "kind": "device",
		"examine": "Una grabadora de cinta. La luz roja está encendida. La cinta está casi llena.",
		"device_label": "Grabar en la cinta", "special": "save"})
	obj({"id": "silla_control", "name": "Silla", "sprite": "chair", "cell": [31, 26], "frame": 1,
		"examine": "Una silla tirada. Quien estaba sentado se levantó con prisa."})


func _room_enfermeria() -> void:
	obj({"id": "botiquin_enfermeria", "name": "Armario de medicación", "sprite": "med_cabinet", "cell": [35, 4], "kind": "container",
		"openable": true, "locked": true, "key": "llave_botiquin", "locked_text": "Un armario de cristal cerrado con una llave pequeña.",
		"unlock_text": "La llave pequeña encaja. Está fría.", "examine": "Un armario de medicación de cristal. Dentro hay una llave colgada de un gancho.",
		"search": "Entre frascos vacíos cuelga una llave larga de latón.", "loot": [["llave_archivo", 1], ["venda_esterilizada", 1]],
		"flag_search": "llave_archivo_cogida"})
	obj({"id": "estanteria_enfermeria", "name": "Estantería", "sprite": "shelf", "cell": [40, 4], "fp": WIDE, "kind": "container",
		"frame": 1, "examine": "Frascos y botes. Casi todos vacíos.", "search": "Material de cura que todavía sirve.",
		"loot": [["venda", 2], ["desinfectante", 1]], "empty": "Frascos vacíos con etiquetas que no reconoces."})
	obj({"id": "encimera_enfermeria", "name": "Encimera", "sprite": "counter", "cell": [36, 8], "fp": WIDE, "kind": "container",
		"openable": true, "examine": "Una encimera con manchas de yodo.", "search": "Una jeringa y una ampolla, preparadas y olvidadas.",
		"loot": [["jeringa", 1], ["ampolla", 1]], "empty": "Envoltorios."})
	obj({"id": "receta_enfermeria", "name": "Hoja de pauta", "sprite": "decal:papers", "cell": [43, 8], "kind": "readable",
		"doc": "receta_09", "examine": "Una hoja con tu número."})
	obj({"id": "archivador_enfermeria", "name": "Archivador", "sprite": "filing_cabinet", "cell": [44, 4], "kind": "container",
		"openable": true, "examine": "Un archivador de enfermería.", "search": "Un inventario a máquina.",
		"loot": ["doc:inventario_enfermeria"], "empty": "Carpetas vacías."})
	_bed("camilla_enfermeria", "Camilla", [34, 9], 0, {"examine": "Una camilla con las correas preparadas.", "empty": "Nada."})
	obj({"id": "lavabo_enfermeria", "name": "Lavabo", "sprite": "sink", "cell": [42, 4], "examine": "Un lavabo con un cepillo de uñas. Las cerdas están rojas."})


func _room_quirofano() -> void:
	obj({"id": "mesa_quirofano", "name": "Mesa de operaciones", "sprite": "op_table", "cell": [45, 25], "fp": BED2,
		"examine": "Correas en las muñecas, en los tobillos y en la frente. Todas desgastadas por dentro.\nA la altura de la espalda, la mesa tiene un agujero.",
		"shadow": [-10, -44, 20, 56]})
	obj({"id": "lampara_quirofano", "name": "Lámpara de quirófano", "sprite": "op_lamp", "cell": [47, 24], "groups": ["powered_props"],
		"examine": "Una lámpara de quirófano. Las bombillas están calientes. No hay corriente."})
	_bed("cadaver_quirofano", "Camilla", [40, 25], 5, {"node": "CorpseGurney", "verb": "Levantar la sábana",
		"examine": "Un cuerpo cubierto con una sábana. Asoma un pie con una etiqueta: «IX».", "flag_examine": "cadaver_visto",
		"search": "No te atreves a levantarla del todo. Ves el principio de una espalda con puntos. Como la tuya.",
		"flag_search": "cadaver_visto", "empty": ""})
	_bed("camilla_vacia_quirofano", "Camilla", [40, 25], 6, {"node": "EmptyGurney", "hidden": true,
		"examine": "La sábana está en el suelo. Lo que había debajo, no.", "empty": "Nada. La sábana está caliente.", "verb": "Mirar"})
	obj({"id": "bandeja_quirofano", "name": "Bandeja de instrumental", "sprite": "tray", "cell": [49, 22], "kind": "container",
		"examine": "Una bandeja de instrumental desordenada.",
		"search": "Entre bisturíes, alguien dejó un destornillador de electricista.", "loot": [["destornillador", 1]],
		"empty": "Bisturíes. No necesitas bisturíes.", "shadow": [-12, -7, 24, 14]})
	obj({"id": "vitrina_quirofano", "name": "Vitrina", "sprite": "med_cabinet", "cell": [51, 21], "kind": "container", "openable": true,
		"examine": "Una vitrina con instrumental.", "search": "Un informe grapado.", "loot": ["doc:informe_quirurgico"], "empty": "Vacía."})
	obj({"id": "encimera_quirofano", "name": "Encimera", "sprite": "counter", "cell": [39, 21], "fp": WIDE, "kind": "container",
		"openable": true, "examine": "Una encimera de acero.", "search": "Un formulario, una venda empapada en yodo y un gorro de quirófano.",
		"loot": ["doc:consentimiento", ["venda_esterilizada", 1], ["gorro_quirurgico", 1]], "empty": "Nada."})
	obj({"id": "gotero_quirofano", "name": "Gotero", "sprite": "iv_stand", "cell": [52, 25], "examine": "La bolsa está llena de algo que no es suero. Brilla un poco."})


func _room_archivo() -> void:
	obj({"id": "archivador_archivo_1", "name": "Archivador", "sprite": "filing_cabinet", "cell": [47, 4], "kind": "container",
		"openable": true, "examine": "Expedientes de la planta 3.", "search": "Un expediente fino.", "loot": ["doc:expediente_11"],
		"empty": "Carpetas de gente que ya no está."})
	obj({"id": "archivador_archivo_2", "name": "Archivador", "sprite": "filing_cabinet", "cell": [48, 4], "kind": "container",
		"openable": true, "examine": "Expedientes de la planta 2.", "empty": "Expedientes de la planta 2. Todos con la misma fecha de alta."})
	obj({"id": "archivador_archivo_3", "name": "Archivador", "sprite": "filing_cabinet", "cell": [49, 4], "kind": "container",
		"openable": true, "examine": "Un archivador con una etiqueta: «VIGILIA».",
		"search": "Una carpeta gruesa con tu número y un sello: «NO ARCHIVAR».", "loot": ["doc:expediente_09"],
		"flag_search": "leyo_expediente_09", "empty": "Vacío."})
	obj({"id": "estanteria_archivo", "name": "Estantería", "sprite": "shelf", "cell": [54, 4], "fp": WIDE, "kind": "container",
		"frame": 0, "examine": "Cajas de archivo y una caja de cartón: «MANTENIMIENTO».",
		"search": "En la caja de mantenimiento, entre recambios, hay un fusible grande.", "loot": [["fusible", 1]],
		"flag_search": "fusible_cogido", "empty": "Recambios que no sirven para nada."})
	obj({"id": "escritorio_archivo", "name": "Escritorio", "sprite": "desk", "cell": [47, 8], "fp": WIDE, "icells": [[1, 0]],
		"kind": "container", "openable": true, "examine": "El escritorio del archivo.",
		"search": "En el cajón: una llave de hierro con un cordel y una circular de dirección.",
		"loot": [["llave_sotano", 1], "doc:circular_9"], "empty": "Grapas.", "shadow": [-14, -12, 60, 24]})
	obj({"id": "ordenador_archivo", "name": "Ordenador", "sprite": "computer", "cell": [47, 8], "kind": "device", "blocks": false,
		"examine": "Un ordenador viejo.", "requires": "power_on", "blocked": "Apagado. No hay corriente.", "groups": ["computers"],
		"device_label": "Mirar la pantalla",
		"device_text": "«EXPEDIENTE 09 — CICLO IX — PROTOCOLO DE RECUPERACIÓN: EN CURSO»\nDebajo, el cursor parpadea en un campo vacío: «HORA DE LA ÚLTIMA VIGILIA».\nNo escribes nada."})
	obj({"id": "cajas_archivo", "name": "Cajas", "sprite": "crates", "cell": [56, 8], "examine": "Cajas con fichas. Todas con fecha de antes del Desvelo."})


func _room_escalera() -> void:
	obj({"id": "cajas_escalera", "name": "Cajas", "sprite": "crates", "cell": [63, 8], "examine": "Cajas apiladas contra la pared, para que no se viera la puerta."})


func _room_vestibulo() -> void:
	var r: Rect2i = _rect("vestibulo")
	for i: int in 3:
		map.set_cell(Vector2i(68, r.position.y - 3 + i), SRC, EXIT_L[i])
		map.set_cell(Vector2i(69, r.position.y - 3 + i), SRC, EXIT_R[i])
		map.set_cell(Vector2i(71, r.position.y - 3 + i), SRC, ELEVATOR[i])
	obj({"id": "salida_principal", "name": "Salida principal", "node": "MainExit", "cell": [68, 3], "fp": WIDE, "blocks": false,
		"kind": "container", "openable": true, "locked": true,
		"locked_text": "Cadenas por fuera, por el otro lado del cristal. Alguien la cerró desde la calle.",
		"examine": "La entrada principal del hospital. Por los ojos de buey se ve la calle: niebla y farolas apagadas.",
		"sounds": {"locked": "door_locked"}})
	obj({"id": "ascensor", "name": "Ascensor", "cell": [71, 3], "kind": "device", "blocks": false, "requires": "power_on",
		"blocked": "Pulsas el botón. No se enciende.", "device_label": "Llamar", "special": "elevator",
		"examine": "Las puertas del ascensor. Hay marcas de dedos en la rendija, por dentro.",
		"device_text": "El botón se enciende. Algo se pone en marcha en el hueco, muy abajo. Sube. Despacio."})
	for x: int in [65, 66]:
		obj({"id": "silla_vestibulo_%d" % x, "name": "Silla", "sprite": "chair", "cell": [x, 7], "examine": "Sillas de espera. Nadie espera."})
	obj({"id": "papelera_vestibulo", "name": "Papelera", "sprite": "trash_bin", "cell": [71, 8], "kind": "container",
		"examine": "Una papelera.", "empty": "Billetes de autobús. Todos de ida."})


func _room_recepcion() -> void:
	obj({"id": "mostrador_recepcion", "name": "Mostrador de admisiones", "sprite": "counter", "cell": [56, 23], "fp": WIDE,
		"kind": "container", "openable": true, "examine": "El mostrador de admisiones.",
		"search": "Un libro de admisiones, abierto por la última página escrita.", "loot": ["doc:registro_admisiones"],
		"empty": "Pulseras de paciente en blanco. Muchas."})
	obj({"id": "mostrador_recepcion_2", "name": "Mostrador", "sprite": "counter", "cell": [59, 23], "fp": WIDE, "icells": [[1, 0]],
		"kind": "container", "openable": true, "examine": "Otro tramo de mostrador.", "empty": "Formularios de consentimiento. Todos sin firmar."})
	obj({"id": "telefono_recepcion", "name": "Teléfono", "sprite": "phone", "cell": [59, 23], "kind": "device", "blocks": false,
		"examine": "El teléfono de recepción.", "device_label": "Descolgar",
		"device_text": "No hay línea. Solo un pitido largo, y debajo, muy lejos, una respiración que se parece a la tuya."})
	_wall_extra("recepcion", 66, 1, X_NOTICE)
	obj({"id": "plano_recepcion", "name": "Plano de evacuación", "cell": [66, 20], "kind": "readable", "blocks": false,
		"doc": "plano_hospital", "examine": "Un plano de evacuación pegado a la pared."})
	obj({"id": "silla_recepcion_1", "name": "Silla", "sprite": "chair", "cell": [66, 25], "examine": "Una silla de espera."})
	obj({"id": "silla_recepcion_2", "name": "Silla", "sprite": "chair", "cell": [67, 25], "frame": 1, "examine": "Tirada."})
	obj({"id": "silla_ruedas_recepcion", "name": "Silla de ruedas", "sprite": "wheelchair", "cell": [70, 26],
		"examine": "Una silla de ruedas con correas en los reposabrazos.", "shadow": [-12, -8, 24, 16]})
	obj({"id": "papelera_recepcion", "name": "Papelera", "sprite": "trash_bin", "cell": [71, 27], "kind": "container",
		"examine": "Una papelera.", "search": "Un paquete de pilas sin abrir.", "loot": [["pilas", 2]], "empty": "Nada."})


func _room_pasillo() -> void:
	obj({"id": "silla_ruedas_pasillo", "name": "Silla de ruedas", "sprite": "wheelchair", "cell": [9, 15],
		"examine": "Una silla de ruedas volcada en medio del pasillo.", "shadow": [-12, -8, 24, 16]})
	_bed("camilla_pasillo", "Camilla", [24, 16], 0, {"examine": "Una camilla con las correas abrochadas. Abrochadas sobre nadie.", "empty": "Nada."})
	for i: int in 3:
		obj({"id": "silla_pasillo_%d" % i, "name": "Silla", "sprite": "chair", "cell": [42 + i, 14], "frame": 1 if i == 1 else 0,
			"examine": "Sillas de espera. Nadie espera."})
	_wall_extra("pasillo", 8, 1, X_NOTICE)
	obj({"id": "cartel_pasillo", "name": "Cartel", "cell": [8, 13], "blocks": false,
		"examine": "«Horario de visitas: no hay visitas.» Alguien ha arañado el papel hasta romperlo."})
	_wall_extra("pasillo", 16, 1, X_HANDPRINT)
	obj({"id": "mano_pasillo", "name": "Mancha", "cell": [16, 13], "blocks": false,
		"examine": "Una mano de sangre, arrastrada hacia abajo. Los dedos son largos, demasiado."})
	_wall_extra("pasillo", 30, 1, X_SMEAR)
	_wall_extra("pasillo", 47, 2, X_SCRATCH)
	_wall_extra("pasillo", 54, 1, X_WINDOW)
	obj({"id": "ventana_pasillo", "name": "Ventana", "cell": [54, 13], "blocks": false,
		"examine": "Una ventana interior que da a una sala a oscuras. Las persianas están arrancadas. Algo blanco se mueve al fondo y se queda quieto."})
	for x: int in [6, 22, 40, 58]:
		_wall_extra("pasillo", x, 0, X_VENT)
	_wall_extra("pasillo", 34, 1, X_SPEAKER)


func _basement() -> void:
	obj({"id": "cajas_b_escalera", "name": "Cajas", "sprite": "crates", "cell": [1, 36], "examine": "Cajas mojadas. Huelen a sótano."})
	obj({"id": "cubo_b_escalera", "name": "Cubo", "sprite": "mop_bucket", "cell": [6, 37], "examine": "Un cubo con agua negra."})
	obj({"id": "cuadro_electrico", "name": "Cuadro eléctrico general", "sprite": "elec_panel", "cell": [10, 34], "node": "Panel",
		"kind": "container", "openable": true, "frame": 0, "frame_open": 1, "flag_open": "panel_abierto",
		"examine": "El cuadro general del hospital. Tiene un aviso: «F1 — ALTA TENSIÓN».",
		"examine_open": "Dentro, las bornas están sueltas y falta el fusible F1.",
		"search": "Las bornas están sueltas y el hueco del fusible F1 está vacío.", "empty": "",
		"sounds": {"open": "locker_open", "close": "door_close"},
		"uses": [
			{"item": "destornillador", "label": "Apretar las bornas", "durability": true, "flag": "panel_reparado", "frame": 2,
				"requires": ["panel_abierto"], "text": "Aprietas las bornas una a una. Salta una chispa azul, pero aguantan."},
			{"item": "fusible", "label": "Colocar el fusible", "consumes": true, "flag": "fusible_puesto", "frame": 3,
				"requires": ["panel_reparado"], "text": "El fusible encaja con un chasquido. Un piloto verde se enciende un instante y se apaga.\nFalta el generador."},
		]})
	obj({"id": "nota_cuadro", "name": "Nota", "sprite": "decal:papers", "cell": [11, 36], "kind": "readable", "doc": "nota_panel",
		"examine": "Una nota en el suelo, junto al cuadro."})
	obj({"id": "grabadora_sotano", "name": "Grabadora de cinta", "sprite": "tape_recorder", "cell": [16, 38], "kind": "device",
		"examine": "Otra grabadora. La cinta tiene tu voz grabada, aunque no recuerdas haber grabado nada aquí.",
		"device_label": "Grabar en la cinta", "special": "save"})
	obj({"id": "estanteria_electrica", "name": "Estantería", "sprite": "shelf", "cell": [14, 34], "fp": WIDE, "kind": "container",
		"frame": 0, "examine": "Cajas de recambios eléctricos.", "search": "Pilas, en una caja de bombillas fundidas.",
		"loot": [["pilas", 1]], "empty": "Bombillas fundidas."})
	obj({"id": "carro_lavanderia_1", "name": "Carro de lavandería", "sprite": "laundry_cart", "cell": [20, 36], "kind": "container",
		"examine": "Un carro lleno de sábanas.", "search": "Prendida a un saco hay una etiqueta escrita a mano.",
		"loot": ["doc:nota_lavanderia"], "empty": "Sábanas. Algunas brillan un poco en la oscuridad."})
	obj({"id": "carro_lavanderia_2", "name": "Carro de lavandería", "sprite": "laundry_cart", "cell": [25, 37], "kind": "container",
		"examine": "Otro carro.", "search": "Una venda limpia y un uniforme de celador, perdidos entre la ropa.",
		"loot": [["venda", 1], ["chaqueta_celador", 1], ["pantalon_celador", 1]], "empty": "Ropa de cama."})
	obj({"id": "estanteria_lavanderia", "name": "Estantería", "sprite": "shelf", "cell": [19, 34], "fp": WIDE, "kind": "container",
		"frame": 0, "examine": "Detergente y cajas.", "search": "Un paquete de pilas.", "loot": [["pilas", 2]], "empty": "Detergente."})
	obj({"id": "morgue", "name": "Cámara frigorífica", "sprite": "morgue", "cell": [2, 51], "fp": WIDE, "node": "Morgue",
		"kind": "container", "openable": true, "frame": 0, "frame_open": 1, "examine": "Cajones de la morgue. Uno tiene escrito «09» con rotulador.",
		"search": "En el cajón hay un cuerpo bajo una sábana. Solo asoma un pie. Lleva una etiqueta.", "loot": ["doc:etiqueta_morgue"],
		"flag_search": "morgue_vista", "empty": "", "sounds": {"open": "drawer_open", "close": "drawer_close"}})
	obj({"id": "morgue_vacia", "name": "Cámara frigorífica", "sprite": "morgue", "cell": [2, 51], "fp": WIDE, "node": "MorgueEmpty",
		"frame": 2, "hidden": true, "examine": "El cajón 09 está abierto y vacío. La sábana sigue doblada como si cubriera algo."})
	obj({"id": "morgue_2", "name": "Cámara frigorífica", "sprite": "morgue", "cell": [7, 51], "fp": WIDE, "kind": "container",
		"openable": true, "examine": "Más cajones.", "search": "Todos vacíos salvo uno: dentro, una pila. Alguien la guardó en frío.",
		"loot": [["pilas", 1]], "empty": "Todos los cajones están vacíos.", "frame": 0, "frame_open": 2})
	_bed("camilla_morgue", "Camilla", [9, 56], 0, {"examine": "Una camilla de la morgue con las correas abrochadas.", "empty": "Nada."})
	obj({"id": "generador", "name": "Generador de emergencia", "sprite": "generator", "cell": [15, 55], "node": "Generator",
		"fp": [[0, 0], [1, 0], [0, -1], [1, -1]], "kind": "device", "requires": "valvula_puesta", "groups": ["powered_props"],
		"blocked": "Le falta la válvula de presión. Hay un hueco con la rosca a la vista.", "device_label": "Arrancar",
		"special": "generator", "examine": "El grupo electrógeno. Huele a gasóleo y a algo dulce.", "shadow": [-14, -44, 60, 56],
		"uses": [
			{"item": "valvula_reparada", "label": "Instalar la válvula", "consumes": true, "flag": "valvula_puesta",
				"text": "Enroscas la válvula en su asiento. Ajusta. El manómetro tiembla y se queda quieto."},
			{"item": "valvula_averiada", "label": "Probar la válvula", "text": "No encaja: el asiento de la válvula está suelto. Habría que apretarlo antes."},
		]})
	obj({"id": "manual_generador", "name": "Instrucciones", "sprite": "decal:papers", "cell": [21, 56], "kind": "readable",
		"doc": "manual_generador", "examine": "Una hoja plastificada en el suelo."})
	obj({"id": "caldera", "name": "Caldera", "sprite": "boiler", "cell": [23, 52], "examine": "Una caldera apagada. Por dentro se oye agua moviéndose, aunque no hay presión.",
		"shadow": [-10, -10, 20, 20]})
	obj({"id": "cajas_calderas", "name": "Cajas", "sprite": "crates", "cell": [13, 52], "examine": "Cajas de repuestos con fechas de antes del Desvelo."})
	obj({"id": "estanteria_taller", "name": "Estantería", "sprite": "shelf", "cell": [31, 51], "fp": WIDE, "kind": "container",
		"frame": 0, "examine": "Piezas y herramientas rotas.",
		"search": "En la balda de abajo, la válvula de presión del generador. Desmontada: el asiento está suelto.",
		"loot": [["valvula_averiada", 1]], "empty": "Herramientas rotas."})
	obj({"id": "banco_taller", "name": "Banco de trabajo", "sprite": "workbench", "cell": [27, 54], "fp": WIDE, "kind": "container",
		"openable": true, "examine": "Un banco de trabajo.", "search": "Una libreta con las tapas manchadas de grasa, unas pilas y unas botas de goma con barro seco.",
		"loot": ["doc:diario_celador", ["pilas", 1], ["botas_goma", 1]], "empty": "Tornillos sueltos.", "shadow": [-14, -12, 60, 24]})
	obj({"id": "cubo_taller", "name": "Cubo", "sprite": "mop_bucket", "cell": [33, 56], "examine": "Agua negra."})
	obj({"id": "cajas_pasillo_b", "name": "Cajas", "sprite": "crates", "cell": [26, 44], "examine": "Cajas que bloquean media pared."})


# --- extras de pared, luces y calcomanías --------------------------------------------------------------------

func _build_fixtures_on_walls() -> void:
	pass


func _light(name: String, cell: Vector2i, color: Color, energy: float, scale: float, needs_power: bool, broken: bool,
		fixture_cell: Vector2i = Vector2i(-999, 0)) -> PoweredLight:
	var light: PoweredLight = PoweredLight.new()
	light.name = name
	light.texture = load("res://assets/sprites/lights/light_round.png")
	light.texture_scale = scale
	light.energy = energy
	light.color = color
	light.height = 80.0
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	light.range_item_cull_mask = LAYER_ALL
	light.shadow_item_cull_mask = LAYER_WORLD
	light.position = _center(cell)
	light.needs_power = needs_power
	light.broken = broken
	light.flicker_rate = 0.05
	_add(lights, light)
	if fixture_cell.x != -999:
		var lamp: Sprite2D = _sprite("wall_lamp")
		lamp.name = "Fixture"
		lamp.position = _center(fixture_cell) + Vector2(0, -6) - light.position
		lamp.frame = 1
		_add(light, lamp)
		for child: Node in lamp.get_children():
			child.owner = scene_root
		light.fixture = lamp
	return light


func _build_lights() -> void:
	var warm: Color = Color(0.95, 0.92, 0.8)
	var i: int = 0
	for id: String in rooms:
		var r: Rect2i = _rect(id)
		var xs: Array[int] = [r.position.x + r.size.x / 2]
		if r.size.x > 14:
			xs = []
			var x: int = r.position.x + 4
			while x < r.end.x:
				xs.append(x)
				x += 9
		for x: int in xs:
			var broken: bool = rng.randf() < 0.2 or id in ["hab11", "b_morgue"]
			_light("Light_%s_%d" % [id, i], Vector2i(x, r.position.y + 1), warm, 0.95, 1.5, true, broken,
				Vector2i(x, r.position.y - 3))
			i += 1
	# Monitor de la 09: la única luz al despertar.
	var monitor: PointLight2D = PointLight2D.new()
	monitor.name = "MonitorLight"
	monitor.texture = load("res://assets/sprites/lights/light_round.png")
	monitor.texture_scale = 0.9
	monitor.energy = 1.3
	monitor.height = 80.0
	monitor.color = Color("9cc04a")
	monitor.shadow_enabled = true
	monitor.range_item_cull_mask = LAYER_ALL
	monitor.shadow_item_cull_mask = LAYER_WORLD
	monitor.position = _center(Vector2i(1, 22)) + Vector2(0, -14)
	_add(lights, monitor, true)
	# Luces de emergencia: rojas, con batería propia (siempre, palpitando).
	for cell: Vector2i in [Vector2i(69, 15), Vector2i(17, 45), Vector2i(4, 15)]:
		var red: PointLight2D = PointLight2D.new()
		red.name = "Emergency_%d_%d" % [cell.x, cell.y]
		red.texture = load("res://assets/sprites/lights/light_round.png")
		red.texture_scale = 1.6
		red.energy = 1.8
		red.height = 80.0
		red.color = Color("c0392b")
		red.shadow_enabled = true
		red.range_item_cull_mask = LAYER_ALL
		red.shadow_item_cull_mask = LAYER_WORLD
		red.position = _center(cell) + Vector2(0, -40)
		red.add_to_group(&"emergency", true)
		_add(lights, red)
		var sprite: Sprite2D = _sprite("emergency_light")
		sprite.name = "Sprite"
		# Atornillada en el tramo alto del muro (encima de las puertas), no a media pared.
		sprite.position = Vector2(0, -78)
		_add(red, sprite)
		for child: Node in sprite.get_children():
			child.owner = scene_root
	# El emergencia oeste (junto a la 07) empieza apagada: se enciende cuando cambia el edificio.
	(lights.get_node("Emergency_4_15") as Node).add_to_group(&"emergency_west", true)
	# Señales de salida: verde tenue con batería propia (la calcomanía está en hospital_dressing.gd).
	for cell: Vector2i in [Vector2i(66, 11), Vector2i(67, 1), Vector2i(70, 18), Vector2i(3, 41)]:
		_ambient("ExitSign_%d_%d" % [cell.x, cell.y], _center(cell) + Vector2(0, -32), Color("5fb87a"), 0.55, 0.45)
	# Luz fría de noche por las ventanas (azul noche): apenas dibuja el suelo bajo el cristal.
	for cell: Vector2i in [Vector2i(5, 3), Vector2i(54, 13)]:
		_ambient("Window_%d_%d" % [cell.x, cell.y], _center(cell) + Vector2(0, 30), Color("3a4a7c"), 0.7, 0.8)
	# Piloto rojo de las grabadoras: un punto de luz que se ve desde lejos.
	for cell: Vector2i in [Vector2i(30, 27), Vector2i(16, 38)]:
		_ambient("Recorder_%d_%d" % [cell.x, cell.y], _center(cell) + Vector2(4, -14), Color("c0392b"), 0.6, 0.18)


## Luz ambiental pequeña que no depende de la corriente (no rompe la oscuridad general).
func _ambient(name: String, pos: Vector2, color: Color, energy: float, scale: float) -> void:
	var l: PointLight2D = PointLight2D.new()
	l.name = name
	l.texture = load("res://assets/sprites/lights/light_round.png")
	l.texture_scale = scale
	l.energy = energy
	l.height = 60.0
	l.color = color
	l.shadow_enabled = scale > 0.3
	l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	l.range_item_cull_mask = LAYER_ALL
	l.shadow_item_cull_mask = LAYER_WORLD
	l.position = pos
	_add(lights, l)


func _build_decals() -> void:
	var d: Dictionary = meta["decals"]
	var texture: CanvasTexture = _canvas(d["path"])
	var names: Array = d["names"]
	var list: Array = [
		["drops", Vector2i(3, 24), 0.0], ["drops", Vector2i(4, 22), 1.2], ["glass", Vector2i(5, 22), 0.0],
		["footprints", Vector2i(5, 16), PI / 2], ["footprints", Vector2i(6, 15), PI / 2], ["footprints", Vector2i(3, 15), -PI / 2],
		["drag", Vector2i(20, 16), 0.0], ["drag", Vector2i(21, 16), 0.0], ["drag", Vector2i(22, 16), 0.0],
		["papers", Vector2i(36, 16), 0.5], ["glass", Vector2i(46, 15), 0.0], ["drops", Vector2i(45, 16), 0.0],
		["drag", Vector2i(44, 24), PI / 2], ["drops", Vector2i(42, 23), 0.0], ["drops", Vector2i(48, 26), 1.0],
		["papers", Vector2i(50, 6), 0.2], ["papers", Vector2i(52, 7), 1.4], ["drops", Vector2i(27, 7), 0.0],
		["drag", Vector2i(8, 45), 0.0], ["drag", Vector2i(9, 45), 0.0], ["drops", Vector2i(3, 54), 0.0],
		["papers", Vector2i(60, 25), 0.9], ["glass", Vector2i(24, 23), 0.0],
	]
	for i: int in list.size():
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "Decal%d" % i
		sprite.texture = texture
		sprite.hframes = names.size()
		sprite.frame = names.find(list[i][0])
		sprite.position = _center(list[i][1])
		sprite.rotation = list[i][2]
		_add(decals, sprite)
	# Huellas húmedas del tamaño de tus pies: van hacia el muro oeste (donde se abrirá el pasillo).
	for x: int in range(1, 9):
		var fp: Sprite2D = Sprite2D.new()
		fp.name = "WestPrints%d" % x
		fp.texture = texture
		fp.hframes = names.size()
		fp.frame = names.find("footprints")
		fp.position = _center(Vector2i(x, 15))
		fp.rotation = -PI / 2
		fp.visible = false
		fp.add_to_group(&"west_prints", true)
		_add(decals, fp)
	# Decorado no interactivo: desgaste de suelos y paredes, muebles y máquinas (ver hospital_dressing.gd).
	DRESSING.new().build(self)


# --- el pasillo imposible -------------------------------------------------------------------------------------

func _paint_impossible(layer: TileMapLayer) -> void:
	var info: Dictionary = layout["impossible"]
	var rows: Array = info["rows"]
	var x0: int = int(info["to_x"])
	for x: int in range(x0, 1):
		for y: int in range(int(rows[0]), int(rows[1]) + 1):
			layer.set_cell(Vector2i(x, y), SRC, Vector2i([7, 2, 7, 0].pick_random(), 1))
		for k: int in 3:
			var col: int = [0, 1, 2, 3][posmod(x, 4)]
			var tile: Vector2i = Vector2i(col, 2 + k)
			if posmod(x, 5) == 0 and k == 1:
				tile = X_SMEAR if x < -10 else X_HANDPRINT
			layer.set_cell(Vector2i(x, 11 + k), SRC, tile)
		layer.set_cell(Vector2i(x, 10), SRC, CAP)
		layer.set_cell(Vector2i(x, 17), SRC, CAP)
	for y: int in range(10, 18):
		layer.set_cell(Vector2i(x0 - 1, y), SRC, CAP)
	# Puertas cerradas a lo largo del pasillo, todas iguales.
	for x: int in range(-4, x0, -5):
		for k: int in 3:
			layer.set_cell(Vector2i(x, 11 + k), SRC, DOOR_CLOSED[k])
	# Al fondo, una puerta abierta.
	for k: int in 3:
		layer.set_cell(Vector2i(x0 + 2, 11 + k), SRC, DOOR_OPEN[k])


func _build_impossible_content() -> void:
	var info: Dictionary = layout["impossible"]
	var x0: int = int(info["to_x"])
	for x: int in range(-4, x0, -5):
		obj({"id": "puerta_imposible_%d" % -x, "name": "Puerta 09", "cell": [x, 13], "blocks": false, "hidden": true,
			"groups": ["impossible"], "examine": "Una placa con un número: 09. Igual que la tuya. Igual que la anterior."})
	obj({"id": "puerta_final", "name": "Puerta 09", "cell": [x0 + 2, 13], "blocks": false, "hidden": true, "groups": ["impossible"],
		"examine": "Está abierta. Dentro, una luz verde late."})
	var glow: PointLight2D = PointLight2D.new()
	glow.name = "ImpossibleGlow"
	glow.texture = load("res://assets/sprites/lights/light_round.png")
	glow.texture_scale = 0.8
	glow.energy = 1.2
	glow.height = 80.0
	glow.color = Color("9cc04a")
	glow.enabled = false
	glow.position = _center(Vector2i(x0 + 2, 12))
	glow.add_to_group(&"impossible_lights", true)
	_add(lights, glow, true)


# --- eventos --------------------------------------------------------------------------------------------------

func _ev(id: String, trigger: HorrorEvent.Trigger, region: Rect2i, requires: Array, forbids: Array, actions: Array,
		delay: float = 0.0, once: bool = true, chance: float = 1.0) -> void:
	var e: HorrorEvent = HorrorEvent.new()
	e.id = StringName(id)
	e.trigger = trigger
	e.region = region
	var req: Array[StringName] = []
	for f: String in requires:
		req.append(StringName(f))
	e.requires_flags = req
	var forb: Array[StringName] = []
	for f: String in forbids:
		forb.append(StringName(f))
	e.forbids_flags = forb
	var acts: Array[EventAction] = []
	for a: EventAction in actions:
		acts.append(a)
	e.actions = acts
	e.delay = delay
	e.once = once
	e.chance = chance
	events.append(e)


func _build_events() -> void:
	var ENTER: HorrorEvent.Trigger = HorrorEvent.Trigger.ENTER_REGION
	var LEAVE: HorrorEvent.Trigger = HorrorEvent.Trigger.LEAVE_REGION
	var corridor: Rect2i = _rect("pasillo")
	# Teléfono que suena al pasar por el control (una vez).
	_ev("telefono_suena", ENTER, Rect2i(26, 14, 10, 3), ["linterna_cogida"], [], [
		EventActions.sound("phone_ring", Vector2i(32, 23), -2.0), EventActions.flag(&"telefono_sonando"), EventActions.mind(-3)], 0.6)
	# Cama que cruje en la 11, habitación vacía.
	_ev("cruje_11", ENTER, Rect2i(24, 14, 9, 3), ["linterna_cogida"], [], [
		EventActions.wait(0.8), EventActions.sound("bed_creak", Vector2i(26, 6), 0.0), EventActions.mind(-3),
		EventActions.flag(&"oyo_crujido")])
	_ev("entra_11", ENTER, _rect("hab11"), ["oyo_crujido"], [], [
		EventActions.message(PackedStringArray(["No hay nadie.", "La cama todavía se balancea un poco, como si alguien acabara de levantarse."])),
		EventActions.mind(-4)])
	# La cama de la 08 se mueve cuando no miras.
	_ev("sale_08", LEAVE, _rect("hab08"), [], [], [EventActions.flag(&"visito_08")], 0.0, true)
	_ev("cama_08_movida", ENTER, _rect("hab08"), ["visito_08", "llave_botiquin_cogida"], [], [
		EventActions.move("Bed08", Vector2(64, 64)), EventActions.sound("heavy_drag", Vector2i(10, 6), -6.0),
		EventActions.message(PackedStringArray(["La cama no estaba así.", "Está separada de la pared, en mitad de la habitación. Las correas siguen abrochadas."])),
		EventActions.mind(-5)])
	# El cadáver del quirófano desaparece al volver.
	_ev("sale_quirofano", LEAVE, _rect("quirofano"), ["cadaver_visto"], [], [EventActions.flag(&"salio_del_quirofano")])
	_ev("cadaver_desaparece", ENTER, _rect("quirofano"), ["salio_del_quirofano"], [], [
		EventActions.visibility("CorpseGurney", false), EventActions.visibility("EmptyGurney", true),
		EventActions.glitch(0.4, 0.5), EventActions.mind(-8),
		EventActions.message(PackedStringArray(["La sábana está en el suelo.", "Lo que había debajo, no."]))])
	# Golpes al otro lado de la pared de la 12 (desde la 10, cerrada).
	_ev("golpes_10", ENTER, _rect("hab12"), [], ["event:entra_10"], [
		EventActions.wait(1.5), EventActions.sound("knock", Vector2i(20, 6), -2.0), EventActions.mind(-2)])
	_ev("entra_10", ENTER, _rect("hab10"), [], [], [EventActions.message(PackedStringArray(["Aquí no hay nadie que pueda haber llamado."]))], 0.5)
	# Pasos en el pasillo cuando estás en una habitación.
	_ev("pasos_pasillo", ENTER, _rect("hab07"), ["linterna_cogida"], [], [
		EventActions.wait(2.0), EventActions.sound("steps_far", Vector2i(10, 15), -3.0)])
	# Una puerta que estaba abierta aparece cerrada.
	_ev("puerta_cerrada_sola", LEAVE, _rect("archivo"), ["fusible_cogido"], [], [
		EventActions.object_state(&"puerta_hab07", false), EventActions.sound("door_close", Vector2i(4, 13), -2.0),
		EventActions.flicker(corridor, 1.2)])
	# Susurro en el archivo, junto a tu expediente.
	_ev("susurro_archivo", ENTER, _rect("archivo"), [], [], [EventActions.wait(3.0), EventActions.sound("whisper", Vector2i(49, 5), -4.0)])
	# Parpadeo y zumbido al pasar por el pasillo (se repite a veces).
	_ev("parpadeo_pasillo", ENTER, Rect2i(40, 14, 12, 3), [], [], [EventActions.flicker(corridor, 0.8)], 0.0, false, 0.35)
	# Sótano: se abren los puntos al bajar; pasos arriba, donde ya no hay nadie.
	_ev("puntos_abiertos", ENTER, _rect("b_escalera"), [], [], [
		EventActions.bleed(PackedStringArray(["Al bajar el último peldaño, algo se rasga en tu espalda.", "Los puntos. Notas la bata pegándose a la piel. Necesitas vendarlo."]))])
	_ev("pasos_arriba", ENTER, _rect("b_pasillo"), [], [], [EventActions.wait(4.0), EventActions.sound("steps_far", Vector2i(4, 33), -2.0), EventActions.mind(-3)])
	_ev("goteo_lavanderia", ENTER, _rect("b_lavanderia"), [], [], [EventActions.sound("drip", Vector2i(24, 35), 0.0)], 0.0, false)
	# La morgue: el cajón 09 aparece vacío al volver.
	_ev("sale_morgue", LEAVE, _rect("b_morgue"), ["morgue_vista"], [], [EventActions.flag(&"salio_morgue")])
	_ev("morgue_vacia", ENTER, _rect("b_morgue"), ["salio_morgue"], [], [
		EventActions.visibility("Morgue", false), EventActions.visibility("MorgueEmpty", true), EventActions.mind(-6),
		EventActions.message(PackedStringArray(["El cajón 09 está abierto.", "Vacío."]))])
	# Tu habitación, hecha de nuevo, esperándote.
	_ev("hab09_preparada", ENTER, _rect("hab09"), ["leyo_expediente_09"], [], [
		EventActions.move("Stretcher09", Vector2.ZERO, 0), EventActions.mind(-4),
		EventActions.message(PackedStringArray(["Alguien ha hecho tu cama.", "Las correas están abrochadas otra vez. Esperando."]))])
	# Ruido en el hueco del ascensor.
	_ev("ascensor_ruido", ENTER, _rect("vestibulo"), [], [], [EventActions.wait(1.0), EventActions.sound("metal_bang", Vector2i(71, 3), -2.0)])
