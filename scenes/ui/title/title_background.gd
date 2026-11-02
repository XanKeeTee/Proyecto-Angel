class_name TitleBackground
extends Control
## Fondo animado del título: el pasillo de la planta con un fluorescente que falla, polvo en la
## luz y lluvia de estática. En algunos apagones largos se ve una figura al fondo del pasillo.
## La ilustración sale de tools/art/title_bg.py.

## El tubo se ha apagado o encendido (el título lo usa para el sonido y los fallos de cinta).
signal tube_changed(lit: bool)
## Un apagón largo con la figura al fondo.
signal figure_shown

const LIT: Texture2D = preload("res://assets/sprites/title/title_bg_lit.png")
const DARK: Texture2D = preload("res://assets/sprites/title/title_bg_dark.png")
const FIGURE: Texture2D = preload("res://assets/sprites/title/title_figure.png")
const NOISE: Shader = preload("res://shaders/tape_noise.gdshader")
## Centro del tubo en la ilustración (píxeles), para el polvo.
const TUBE_AT: Vector2 = Vector2(335, 150)
## Espera entre fallos del tubo (segundos).
const FLICKER_EVERY: Vector2 = Vector2(2.5, 7.0)
## Probabilidad de que un fallo sea un apagón largo con la figura.
const FIGURE_CHANCE: float = 0.3

var noise_material: ShaderMaterial

var _lit: TextureRect
var _figure: TextureRect
var _dust: CPUParticles2D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dark: TextureRect = _image(DARK)
	add_child(dark)
	_figure = _image(FIGURE)
	_figure.visible = false
	add_child(_figure)
	_lit = _image(LIT)
	add_child(_lit)
	_dust = _make_dust()
	add_child(_dust)
	var shade: TextureRect = TextureRect.new()
	shade.texture = _side_shade()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	noise_material = ShaderMaterial.new()
	noise_material.shader = NOISE
	var snow: ColorRect = ColorRect.new()
	snow.material = noise_material
	snow.set_anchors_preset(Control.PRESET_FULL_RECT)
	snow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(snow)
	set_noise(0.12)
	_flicker_loop()


## Intensidad de la nieve (0..1).
func set_noise(amount: float) -> void:
	noise_material.set_shader_parameter(&"amount", amount)


func is_lit() -> bool:
	return _lit.visible


func _flicker_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(_rng.randf_range(FLICKER_EVERY.x, FLICKER_EVERY.y)).timeout
		if not is_inside_tree():
			return
		var long_out: bool = _rng.randf() < FIGURE_CHANCE
		for i: int in _rng.randi_range(2, 5):
			_set_lit(false)
			await get_tree().create_timer(_rng.randf_range(0.04, 0.14)).timeout
			_set_lit(true)
			await get_tree().create_timer(_rng.randf_range(0.03, 0.2)).timeout
		if long_out:
			_set_lit(false)
			_figure.visible = true
			figure_shown.emit()
			await get_tree().create_timer(_rng.randf_range(0.7, 1.3)).timeout
			_figure.visible = false
			_set_lit(true)


func _set_lit(lit: bool) -> void:
	if _lit.visible == lit:
		return
	_lit.visible = lit
	_dust.modulate.a = 1.0 if lit else 0.15
	tube_changed.emit(lit)


func _image(texture: Texture2D) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_KEEP
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Polvo que flota en la luz del tubo: puntos de un píxel, hueso muy tenue.
func _make_dust() -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.position = TUBE_AT + Vector2(0, 40)
	p.amount = 70
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(70, 70)
	p.direction = Vector2(0.3, 1.0)
	p.spread = 60.0
	p.gravity = Vector2(0, 1.5)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 5.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(0.91, 0.88, 0.83, 0.0), Color(0.91, 0.88, 0.83, 0.5),
		Color(0.85, 0.92, 0.75, 0.4), Color(0.91, 0.88, 0.83, 0.0)])
	p.color_ramp = ramp
	return p


## Oscurece la izquierda (donde va el menú) para que se lea bien.
func _side_shade() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.55])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.82), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0)])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.width = 640
	tex.height = 4
	return tex
