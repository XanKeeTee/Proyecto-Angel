class_name PassingShadow
extends Node2D
## Una sombra que cruza deprisa a lo lejos (susto PASSING_SHADOW). Usa la misma silueta que la
## entidad, más oscura y sin máscara. Aparece tramada, cruza de `from` a `to` y se borra sola.

const SHEET: Texture2D = preload("res://assets/sprites/horror/entity.png")
const SHADER: Shader = preload("res://shaders/entity_dissolve.gdshader")
const FRAMES: int = 8


## Crea la sombra en `parent` y la hace cruzar en `seconds`.
static func cross(parent: Node, from: Vector2, to: Vector2, seconds: float) -> PassingShadow:
	var shadow: PassingShadow = PassingShadow.new()
	parent.add_child(shadow)
	shadow._run(from, to, seconds)
	return shadow


func _run(from: Vector2, to: Vector2, seconds: float) -> void:
	position = from
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"fade", 0.0)
	material.set_shader_parameter(&"waver_px", 2.5)
	var body: Sprite2D = Sprite2D.new()
	body.texture = SHEET
	body.hframes = FRAMES
	body.frame = randi() % FRAMES
	body.offset = Stalker.FEET_OFFSET
	body.flip_h = to.x < from.x
	body.material = material
	body.skew = 0.18 if to.x > from.x else -0.18  # inclinada hacia donde va
	add_child(body)
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", to, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var fade: Tween = create_tween()
	fade.tween_method(func(v: float) -> void: material.set_shader_parameter(&"fade", v), 0.0, 1.0, seconds * 0.25)
	fade.tween_interval(seconds * 0.4)
	fade.tween_method(func(v: float) -> void: material.set_shader_parameter(&"fade", v), 1.0, 0.0, seconds * 0.35)
	await tween.finished
	queue_free()
