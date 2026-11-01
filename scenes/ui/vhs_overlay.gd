class_name VhsOverlay
extends CanvasLayer
## Filtro VHS de pantalla completa. F2 lo activa o desactiva.
## Se añade por código: `var vhs := VhsOverlay.new(); add_child(vhs)`.

const SHADER: Shader = preload("res://shaders/vhs_post.gdshader")
const BASE_ABERRATION: float = 1.0

var _rect: ColorRect
var _material: ShaderMaterial
var _glitch_tween: Tween


func _init() -> void:
	layer = 50


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F2:
		_rect.visible = not _rect.visible


## Virado de color de la zona (blanco = sin virado).
func set_tint(color: Color) -> void:
	_material.set_shader_parameter("tint", color)


func set_enabled(enabled: bool) -> void:
	_rect.visible = enabled


## Distorsión de cinta que sube de golpe y se desvanece en `duration` segundos.
func glitch(duration: float, strength: float = 1.0) -> void:
	if _glitch_tween != null:
		_glitch_tween.kill()
	_material.set_shader_parameter("tracking", strength)
	_glitch_tween = create_tween()
	_glitch_tween.tween_method(_set_tracking, strength, 0.0, duration).set_ease(Tween.EASE_IN)


func _set_tracking(value: float) -> void:
	_material.set_shader_parameter("tracking", value)
	_material.set_shader_parameter("aberration_px", BASE_ABERRATION + value * 2.0)
