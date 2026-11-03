class_name VhsOverlay
extends CanvasLayer
## Filtro de pantalla completa (shaders/film_grade.gdshader): color desaturado y de baja saturación,
## sombras con contraste, grano de película, viñeta oscura y tramado sutil. Los fallos de cinta
## (`glitch`) quedan solo para sustos y eventos. Su intensidad y el brillo salen de las opciones.
## F2 lo apaga o enciende rápidamente (el brillo se mantiene).
## (El nombre de la clase se conserva por compatibilidad con el resto del código.)
## Se añade por código: `var vhs := VhsOverlay.new(); add_child(vhs)`.

const SHADER: Shader = preload("res://shaders/film_grade.gdshader")
## Parámetros que escalan con la intensidad elegida en opciones.
const SCALED: Array[StringName] = [&"grain_amount", &"aberration_px", &"tracking", &"desaturation", &"shadow_contrast", &"dither_amount"]

var _rect: ColorRect
var _material: ShaderMaterial
var _glitch_tween: Tween
var _base: Dictionary[StringName, Variant] = {
	&"grain_amount": 0.05, &"aberration_px": 0.0, &"vignette_strength": 0.85, &"tracking": 0.0,
	&"tint": Color.WHITE, &"desaturation": 0.38, &"saturation": 0.78, &"shadow_contrast": 0.22,
	&"dither_amount": 0.6,
}
var _enabled: bool = true


func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	Settings.changed.connect(_apply)
	_apply()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F2:
		set_enabled(not _enabled)


## Virado de color de la zona (blanco = sin virado).
func set_tint(color: Color) -> void:
	set_param(&"tint", color)


## Cambia un parámetro base del shader (antes de aplicar la intensidad de opciones).
func set_param(param: StringName, value: Variant) -> void:
	_base[param] = value
	_apply()


## Valor base de un parámetro (el que se pasó con `set_param`), o `fallback` si no se ha fijado.
func get_param(param: StringName, fallback: Variant = null) -> Variant:
	return _base.get(param, fallback)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_apply()


## Distorsión de cinta que sube de golpe y se desvanece en `duration` segundos.
func glitch(duration: float, strength: float = 1.0) -> void:
	if _glitch_tween != null:
		_glitch_tween.kill()
	_glitch_tween = create_tween()
	_glitch_tween.tween_method(func(v: float) -> void: set_param(&"tracking", v), strength, 0.0, duration).set_ease(Tween.EASE_IN)


func _apply() -> void:
	if _material == null:
		return
	var strength: float = Settings.vhs if _enabled else 0.0
	for param: StringName in _base:
		var value: Variant = _base[param]
		if SCALED.has(param):
			value = float(value) * strength
		elif param == &"vignette_strength":
			value = float(value) * lerpf(0.55, 1.0, strength)
		elif param == &"saturation":
			value = lerpf(1.0, float(value), strength)
		_material.set_shader_parameter(param, value)
	_material.set_shader_parameter(&"gamma", Settings.brightness)
