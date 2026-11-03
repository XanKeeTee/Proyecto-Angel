extends Node
## Construye la escena del protagonista (scenes/world/player/player.tscn):
## sprite con mapa de normales y brillo de la lente, capas de ropa con balanceo, arma en la
## mano, colisión de los pies, halo, linterna, luz rebotada, polvo en suspensión y cámara.
## Lee tools/art/sprite_meta.json: las hojas del protagonista (andar, con linterna, acciones,
## levantarse) y, de cada fotograma, dónde está la lente y la mano libre. Las hojas se cargan
## en el juego solo cuando hacen falta (ver Player._use_sheet): aquí solo se crean sus
## CanvasTexture (protagonist<sufijo>_canvas.tres).
## Uso: "$GODOT_BIN" --headless --path . res://tools/levels/build_player.tscn

const META: String = "res://tools/art/sprite_meta.json"
const OUT: String = "res://scenes/world/player/player.tscn"
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_PROPS: int = 4
const LAYER_ALL: int = 7
## Linterna: tamaño del cono (alcance y anchura) y fuerza. Un 12 % más que en la primera versión.
const FLASHLIGHT_SCALE: float = 1.46
const FLASHLIGHT_ENERGY: float = 2.7

var player: CharacterBody2D


func _ready() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(META)))
	var m: Dictionary = meta["protagonist"]
	player = CharacterBody2D.new()
	player.name = "Player"
	player.set_script(load("res://scenes/world/player/player.gd"))
	player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	player.collision_layer = 2
	player.collision_mask = 1

	var feet: CollisionShape2D = CollisionShape2D.new()
	feet.name = "Feet"
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 6.0
	feet.shape = circle
	_add(player, feet)

	# Una CanvasTexture por hoja del cuerpo (se cargan al usarlas).
	var base: String = String(m["path"]).get_basename()
	var sheets: Dictionary = m["sheets"]
	var body_paths: Dictionary = {}
	for sheet: String in sheets:
		var suffix: String = sheets[sheet]["suffix"]
		var tex: CanvasTexture = CanvasTexture.new()
		tex.diffuse_texture = load(base + suffix + ".png")
		tex.normal_texture = load(base + suffix + "_n.png")
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex_path: String = base + suffix + "_canvas.tres"
		ResourceSaver.save(tex, tex_path)
		body_paths[sheet] = tex_path
	player.set("sheets", sheets)
	player.set("body_paths", body_paths)
	player.set("glow_base", base)
	# Dónde cae el origen de la camilla respecto a su nodo (para levantarse en su sitio exacto).
	if meta.has("stretcher"):
		var anchor: Array = meta["stretcher"]["anchor"]
		player.set("bed_anchor", Vector2(anchor[0], anchor[1]))

	var move: Dictionary = sheets["move"]
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite2D"
	# La textura la pone el jugador al arrancar (hoja de andar); aquí solo el formato.
	sprite.hframes = int(move["hframes"])
	sprite.vframes = int(move["vframes"])
	var frame: Array = move["frame"]
	var origin: Array = move["origin"]
	sprite.offset = Vector2(frame[0] / 2.0 - origin[0], frame[1] / 2.0 - origin[1])  # los pies en el nodo
	sprite.light_mask = LAYER_PLAYER  # la linterna no ilumina al que la lleva
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.frame = 0
	_add(player, sprite)
	# Capas de ropa (de abajo arriba). La textura la pone el juego según lo que lleve puesto.
	var cloth_shader: Shader = load("res://shaders/cloth_sway.gdshader")
	for layer_name: String in ["Feet", "Legs", "Body", "Head"]:
		var layer: Sprite2D = Sprite2D.new()
		layer.name = layer_name
		layer.hframes = sprite.hframes
		layer.vframes = sprite.vframes
		layer.offset = sprite.offset
		layer.light_mask = LAYER_PLAYER
		layer.visible = false
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = cloth_shader
		mat.resource_local_to_scene = true
		mat.set_shader_parameter(&"frames", Vector2(sprite.hframes, sprite.vframes))
		mat.set_shader_parameter(&"frame_px", Vector2(frame[0], frame[1]))
		mat.set_shader_parameter(&"feet_y", float(origin[1]))
		layer.material = mat
		sprite.add_child(layer)
		layer.owner = player
	var glow: Sprite2D = Sprite2D.new()
	glow.name = "Glow"
	glow.hframes = sprite.hframes
	glow.vframes = sprite.vframes
	glow.offset = sprite.offset
	glow.visible = false
	var unshaded: CanvasItemMaterial = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = unshaded
	sprite.add_child(glow)
	glow.owner = player
	# Arma en la mano libre (Player.set_held_weapon). Va la última: por delante del cuerpo; si
	# la mano queda detrás, se dibuja detrás (show_behind_parent).
	var weapon: Sprite2D = Sprite2D.new()
	weapon.name = "Weapon"
	weapon.light_mask = LAYER_PLAYER
	weapon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon.visible = false
	sprite.add_child(weapon)
	weapon.owner = player

	# Origen de reserva de la luz por orientación (si un fotograma no trae la lente).
	var fallback: Array[Vector2] = []
	var lens_move: Array = sheets["move_flash"]["lens"]
	for row: Array in lens_move:
		var p: Array = row[int(sheets["move_flash"]["anims"]["idle"][0])]
		fallback.append(Vector2(p[0], p[1]))
	player.set("flashlight_offsets", fallback)

	var aura: PointLight2D = _light("Aura", "light_round", 0.55, 0.75, 70.0, Color("d8d0c0"))
	aura.range_item_cull_mask = LAYER_ALL
	aura.shadow_enabled = true
	aura.shadow_item_cull_mask = LAYER_WORLD
	aura.shadow_filter = Light2D.SHADOW_FILTER_PCF5

	# Linterna: no ilumina al propio personaje.
	var flashlight: PointLight2D = _light("Flashlight", "flashlight_cone", FLASHLIGHT_SCALE, FLASHLIGHT_ENERGY, 120.0,
		Color(1.0, 0.93, 0.8))
	flashlight.range_item_cull_mask = LAYER_WORLD | LAYER_PROPS
	flashlight.shadow_enabled = true
	flashlight.shadow_item_cull_mask = LAYER_WORLD
	flashlight.shadow_filter = Light2D.SHADOW_FILTER_PCF13
	flashlight.shadow_filter_smooth = 2.0
	flashlight.enabled = false

	var bounce: PointLight2D = _light("Bounce", "light_round", 1.75, 0.22, 60.0, Color(0.85, 0.82, 0.74))
	bounce.range_item_cull_mask = LAYER_ALL
	bounce.enabled = false

	var dust: CPUParticles2D = CPUParticles2D.new()
	dust.name = "Dust"
	dust.amount = 90
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.local_coords = false
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(230, 150)
	dust.direction = Vector2(1, 0)
	dust.spread = 180.0
	dust.gravity = Vector2(0, 0.6)
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 4.0
	dust.color = Color(0.9, 0.87, 0.78, 0.55)
	dust.z_index = 1
	_add(player, dust)

	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera2D"
	camera.position = Vector2(0, -24)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	_add(player, camera)

	var packed: PackedScene = PackedScene.new()
	packed.pack(player)
	ResourceSaver.save(packed, OUT)
	print("Jugador construido: %d hojas, %d x %d fotogramas de andar." % [sheets.size(), sprite.hframes, sprite.vframes])
	player.free()
	get_tree().quit()


func _light(node_name: String, texture: String, scale: float, energy: float, height: float, color: Color) -> PointLight2D:
	var light: PointLight2D = PointLight2D.new()
	light.name = node_name
	light.texture = load("res://assets/sprites/lights/%s.png" % texture)
	light.texture_scale = scale
	light.energy = energy
	light.height = height
	light.color = color
	_add(player, light)
	return light


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = player
