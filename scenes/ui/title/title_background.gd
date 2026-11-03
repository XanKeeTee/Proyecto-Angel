class_name TitleBackground
extends Control
## Fondo animado del título: la Habitación 09 de verdad, con los mismos tiles, muebles y luces
## del mapa, vista desde una cámara fija. La camilla está deshecha, el monitor late, el
## fluorescente falla, flota polvo y cae lluvia de estática. En algunos apagones largos la
## entidad se intuye en la penumbra.
##
## La escena del hospital se instancia SIN su guion (se le quita el script de WorldController
## antes de entrar al árbol) y sin jugador, eventos, ambiente ni fundido: no toca GameState, ni
## el guardado, ni suena nada del juego. Va dentro de un SubViewport con su propio mundo 2D.

## El tubo se ha apagado o encendido (el título lo usa para el sonido y los fallos de cinta).
signal tube_changed(lit: bool)
## Un apagón largo con la entidad en la penumbra.
signal figure_shown

const HOSPITAL: String = "res://scenes/world/hospital/hospital.tscn"
const NOISE: Shader = preload("res://shaders/tape_noise.gdshader")
## Lluvia de estática en reposo (la pantalla de título la sube en las transiciones).
const REST_NOISE: float = 0.02
## Refuerzo del fluorescente de la habitación (en el juego alumbra menos: aquí es el foco).
const TUBE_BOOST: float = 2.4
## Nodos de la escena del hospital que no deben existir en el fondo.
const STRIP: PackedStringArray = ["Player", "Events", "Ambience", "FadeLayer"]
## Centro de la cámara: la habitación queda a la derecha y el vacío fuera del mapa, a la
## izquierda, deja el menú sobre negro.
const VIEW_CENTER: Vector2 = Vector2(-30, 724)
const ROOM_LIGHT: String = "Light_hab09_16"
const MONITOR_LIGHT: String = "MonitorLight"
const STRETCHER: String = "Stretcher09"
## Fotograma de la camilla deshecha (ver hospital.gd: STRETCHER_MESSY).
const STRETCHER_MESSY: int = 3
## Oscuridad de la escena (un poco menos que en el juego, para que se lea la habitación).
const DARKNESS: Color = Color(0.07, 0.07, 0.09)
const HEARTBEAT_PERIOD: float = 0.95
## Donde puede asomar la entidad: rincones de la habitación fuera de la luz (píxeles del mapa).
const FIGURE_SPOTS: Array[Vector2] = [Vector2(226, 708), Vector2(206, 884), Vector2(40, 884)]
## Espera entre fallos del tubo (segundos).
const FLICKER_EVERY: Vector2 = Vector2(2.5, 7.0)
## Probabilidad de que un fallo sea un apagón largo con la entidad.
const FIGURE_CHANCE: float = 0.3

var noise_material: ShaderMaterial

var _viewport: SubViewport
var _scene: Node2D
var _tube: PointLight2D
var _monitor: PointLight2D
var _monitor_base: float = 1.0
var _figure: Stalker
var _dust: CPUParticles2D
var _lit: bool = true
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var container: SubViewportContainer = SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.snap_2d_transforms_to_pixel = true
	_viewport.snap_2d_vertices_to_pixel = true
	_viewport.audio_listener_enable_2d = false
	_viewport.handle_input_locally = false
	_viewport.gui_disable_input = true
	container.add_child(_viewport)
	_build_scene()
	add_child(_side_shade())
	noise_material = ShaderMaterial.new()
	noise_material.shader = NOISE
	var snow: ColorRect = ColorRect.new()
	snow.material = noise_material
	snow.set_anchors_preset(Control.PRESET_FULL_RECT)
	snow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(snow)
	set_noise(REST_NOISE)
	_flicker_loop()


func _process(_delta: float) -> void:
	if _monitor == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var beat: float = fposmod(now, HEARTBEAT_PERIOD) / HEARTBEAT_PERIOD
	_monitor.energy = _monitor_base * (0.75 + 0.45 * exp(-beat * 9.0))


## Intensidad de la nieve (0..1).
func set_noise(amount: float) -> void:
	noise_material.set_shader_parameter(&"amount", amount)


func is_lit() -> bool:
	return _lit


## La escena del hospital, sin guion ni jugador, con la cámara fija en la Habitación 09.
func _build_scene() -> void:
	_scene = (load(HOSPITAL) as PackedScene).instantiate() as Node2D
	_scene.set_script(null)  # sin WorldController: ni interfaz, ni guion, ni GameState
	for node_name: String in STRIP:
		var node: Node = _scene.get_node_or_null(NodePath(node_name))
		if node == null:
			node = _scene.find_child(node_name, true, false)
		if node != null:
			node.get_parent().remove_child(node)
			node.free()
	_viewport.add_child(_scene)
	var darkness: CanvasModulate = _scene.get_node_or_null(^"Darkness") as CanvasModulate
	if darkness != null:
		darkness.color = DARKNESS
	var stretcher: Node = _scene.find_child(STRETCHER, true, false)
	if stretcher != null:
		var sprite: Sprite2D = stretcher.get_node_or_null(^"Sprite2D") as Sprite2D
		if sprite != null:
			sprite.frame = STRETCHER_MESSY
	_tube = _scene.find_child(ROOM_LIGHT, true, false) as PointLight2D
	if _tube != null:
		_tube.energy *= TUBE_BOOST
	_monitor = _scene.find_child(MONITOR_LIGHT, true, false) as PointLight2D
	if _monitor != null:
		_monitor_base = _monitor.energy
	var camera: Camera2D = Camera2D.new()
	camera.position = VIEW_CENTER
	_scene.add_child(camera)
	camera.make_current()
	_dust = _make_dust()
	_scene.add_child(_dust)
	_figure = Stalker.new()
	var world: Node = _scene.get_node_or_null(^"World")
	(world if world != null else _scene).add_child(_figure)
	_set_tube(true)


func _flicker_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(_rng.randf_range(FLICKER_EVERY.x, FLICKER_EVERY.y)).timeout
		if not is_inside_tree():
			return
		var long_out: bool = _rng.randf() < FIGURE_CHANCE
		for i: int in _rng.randi_range(2, 5):
			_set_tube(false)
			await get_tree().create_timer(_rng.randf_range(0.04, 0.14)).timeout
			_set_tube(true)
			await get_tree().create_timer(_rng.randf_range(0.03, 0.2)).timeout
		if long_out:
			_set_tube(false)
			var spot: Vector2 = FIGURE_SPOTS[_rng.randi() % FIGURE_SPOTS.size()]
			var path: Array[Vector2] = []
			_figure.appear(spot, path, 999.0)
			figure_shown.emit()
			await get_tree().create_timer(_rng.randf_range(1.4, 2.2)).timeout
			_figure.vanish(&"timeout")
			await get_tree().create_timer(0.3).timeout
			_set_tube(true)


## Enciende o apaga el fluorescente de la habitación (luz y aplique).
func _set_tube(lit: bool) -> void:
	if _tube == null:
		return
	_tube.enabled = lit
	var fixture: Sprite2D = _tube.get("fixture") as Sprite2D
	if fixture != null:
		fixture.frame = 0 if lit else 1
		var glow: Sprite2D = fixture.get_node_or_null(^"Glow") as Sprite2D
		if glow != null:
			glow.visible = lit
			glow.frame = fixture.frame
	if _dust != null:
		_dust.modulate.a = 1.0 if lit else 0.2
	if lit != _lit:
		_lit = lit
		tube_changed.emit(lit)


## Polvo que flota en la luz de la habitación: puntos de un píxel, hueso muy tenue.
func _make_dust() -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.position = _tube.position if _tube != null else VIEW_CENTER
	p.z_index = 1
	p.amount = 60
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(100, 90)
	p.direction = Vector2(0.3, 1.0)
	p.spread = 60.0
	p.gravity = Vector2(0, 1.5)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 5.0
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(0.91, 0.88, 0.83, 0.0), Color(0.91, 0.88, 0.83, 0.45),
		Color(0.85, 0.92, 0.75, 0.35), Color(0.91, 0.88, 0.83, 0.0)])
	p.color_ramp = ramp
	var unshaded: CanvasItemMaterial = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = unshaded
	return p


## Oscurece la izquierda (donde va el menú) para que se lea bien.
func _side_shade() -> TextureRect:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.32, 0.55])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.85), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.0)])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.width = 640
	tex.height = 4
	var shade: TextureRect = TextureRect.new()
	shade.texture = tex
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shade
