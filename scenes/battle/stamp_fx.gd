class_name StampFx
extends Node2D
## Sello de caucho que cae sobre la pantalla: entra grande y transparente, golpea (se encoge de
## golpe), se queda un momento y se desvanece. Sirve para «AUTORIZADO» al confirmar una orden y para
## los rótulos de impacto («FRACTURA», «AMPUTACIÓN»…). Si falta la imagen, escribe el texto en rojo.

## El sello ha golpeado (para el sonido y la sacudida).
signal landed

var texture: Texture2D
var text: String = ""
var _alpha: float = 0.0
var _scale_f: float = 1.0
var _angle: float = 0.0
var _big: float = 1.0


## Estampa en `center` y se borra sola. Devuelve el tween por si se quiere esperar.
func stamp(tex: Texture2D, center: Vector2, label: String = "", hold: float = 0.55, big: float = 1.0) -> Tween:
	texture = tex
	text = label
	position = center.round()
	_big = big
	_angle = randf_range(-0.12, -0.03)
	var tween: Tween = create_tween()
	tween.tween_method(_set_drop, 0.0, 1.0, 0.09).set_ease(Tween.EASE_IN)
	tween.tween_callback(landed.emit)
	tween.tween_method(func(v: float) -> void:
		_scale_f = big * (1.0 + 0.06 * v)
		queue_redraw(), 1.0, 0.0, 0.08)
	tween.tween_interval(hold)
	tween.tween_method(func(v: float) -> void:
		_alpha = v
		queue_redraw(), 1.0, 0.0, 0.35)
	tween.tween_callback(queue_free)
	return tween


func _set_drop(t: float) -> void:
	_alpha = t
	_scale_f = _big * lerpf(1.8, 1.0, t)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, _angle, Vector2(_scale_f, _scale_f))
	if texture != null:
		draw_texture(texture, -(texture.get_size() * 0.5).round(), Color(1, 1, 1, _alpha))
	elif text != "":
		var font: Font = UiStyle.ui_bold()
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.SIZE_TITLE).x
		var box: Rect2 = Rect2(Vector2(-w * 0.5 - 6, -14), Vector2(w + 12, 24))
		var red: Color = Color(0.6, 0.11, 0.1, _alpha)
		draw_rect(box, red, false, 2.0)
		draw_string(font, Vector2(-w * 0.5, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.SIZE_TITLE, red)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
