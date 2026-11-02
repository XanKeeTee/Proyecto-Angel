extends Node
## Construye la escena del protagonista (scenes/world/player/player.tscn):
## sprite con mapa de normales y brillo de la lente, capas de ropa con balanceo, colisión
## de los pies, halo, linterna, luz rebotada, polvo en suspensión y cámara.
## Lee tools/art/sprite_meta.json.
## Uso: "$GODOT_BIN" --headless --path . res://tools/levels/build_player.tscn

const META: String = "res://tools/art/sprite_meta.json"
const OUT: String = "res://scenes/world/player/player.tscn"
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_PROPS: int = 4
const LAYER_ALL: int = 7

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

	var tex: CanvasTexture = CanvasTexture.new()
	tex.diffuse_texture = load(m["path"])
	tex.normal_texture = load(String(m["path"]).get_basename() + "_n.png")
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex_path: String = String(m["path"]).get_basename() + "_canvas.tres"
	ResourceSaver.save(tex, tex_path)
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(tex_path)
	sprite.hframes = int(m["hframes"])
	sprite.vframes = int(m["vframes"])
	var frame: Array = m["frame"]
	var origin: Array = m["origin"]
	sprite.offset = Vector2(frame[0] / 2.0 - origin[0], frame[1] / 2.0 - origin[1])  # los pies en el nodo
	sprite.light_mask = LAYER_PLAYER  # la linterna no ilumina al que la lleva
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
	glow.texture = load(String(m["path"]).get_basename() + "_glow.png")
	glow.hframes = sprite.hframes
	glow.vframes = sprite.vframes
	glow.offset = sprite.offset
	glow.visible = false
	var unshaded: CanvasItemMaterial = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = unshaded
	sprite.add_child(glow)
	glow.owner = player

	# La luz sale de la lente: posición por fotograma (y una de reserva por orientación).
	var fallback: Array[Vector2] = []
	for lens: Dictionary in m["lens"]:
		fallback.append(Vector2(lens["screen"][0], lens["screen"][1]))
	player.set("flashlight_offsets", fallback)
	player.set("lens_frames", m.get("lens_frames", []))

	var aura: PointLight2D = _light("Aura", "light_round", 0.55, 0.75, 70.0, Color("d8d0c0"))
	aura.range_item_cull_mask = LAYER_ALL
	aura.shadow_enabled = true
	aura.shadow_item_cull_mask = LAYER_WORLD
	aura.shadow_filter = Light2D.SHADOW_FILTER_PCF5

	# Linterna: más alcance y más fuerza que antes; no ilumina al propio personaje.
	var flashlight: PointLight2D = _light("Flashlight", "flashlight_cone", 1.3, 2.7, 120.0, Color(1.0, 0.93, 0.8))
	flashlight.range_item_cull_mask = LAYER_WORLD | LAYER_PROPS
	flashlight.shadow_enabled = true
	flashlight.shadow_item_cull_mask = LAYER_WORLD
	flashlight.shadow_filter = Light2D.SHADOW_FILTER_PCF13
	flashlight.shadow_filter_smooth = 2.0
	flashlight.enabled = false

	var bounce: PointLight2D = _light("Bounce", "light_round", 1.6, 0.22, 60.0, Color(0.85, 0.82, 0.74))
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
	print("Jugador construido: %d x %d fotogramas." % [sprite.hframes, sprite.vframes])
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
