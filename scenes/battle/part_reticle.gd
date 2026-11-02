class_name PartReticle
extends Node2D
## Retícula sobre la parte del cuerpo apuntada: cuatro esquinas que laten y una ficha al lado con
## la parte, la probabilidad de acierto, el daño estimado y su estado.

const COLOR: Color = Color("d0a24a")
const SHADOW: Color = Color(0, 0, 0, 0.7)
const PANEL: Color = Color(0.03, 0.03, 0.05, 0.86)
const SIZE: float = 26.0
const ARM: float = 7.0

## Textos de la ficha (líneas). Vacío = sin ficha.
var lines: PackedStringArray = []
## Esquina superior izquierda de la ficha, en las coordenadas del padre (fija, para no tapar al enemigo).
var panel_at: Vector2 = Vector2(10, 150)
var font: Font

var _time: float = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()


func point_at(point: Vector2, info: PackedStringArray) -> void:
	position = point.round()
	lines = info
	visible = true
	queue_redraw()


func _draw() -> void:
	var pulse: float = 1.0 + 0.12 * sin(_time * 7.0)
	var h: float = SIZE * 0.5 * pulse
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var c: Vector2 = corner * h
		for pass_color: Color in [SHADOW, COLOR]:
			var o: Vector2 = Vector2(1, 1) if pass_color == SHADOW else Vector2.ZERO
			draw_line(c + o, c + o - Vector2(corner.x * ARM, 0), pass_color, 2.0)
			draw_line(c + o, c + o - Vector2(0, corner.y * ARM), pass_color, 2.0)
	draw_rect(Rect2(Vector2(-1, -1), Vector2(2, 2)), COLOR)
	if lines.is_empty() or font == null:
		return
	var font_size: int = UiStyle.MONO_SMALL
	var width: float = 0.0
	for line: String in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var box: Vector2 = Vector2(width + 10.0, lines.size() * 11.0 + 6.0)
	var origin: Vector2 = (panel_at - position).round()
	# Línea quebrada de la retícula a la ficha.
	var side: float = signf(origin.x + box.x * 0.5) if absf(origin.x + box.x * 0.5) > 1.0 else 1.0
	var exit: Vector2 = Vector2(side * (h + 2.0), 0)
	var dock: Vector2 = Vector2(origin.x + (0.0 if side > 0 else box.x), origin.y + 8.0)
	var elbow: Vector2 = Vector2(lerpf(exit.x, dock.x, 0.5), 0)
	draw_polyline(PackedVector2Array([exit, elbow, Vector2(elbow.x, dock.y), dock]), Color(COLOR, 0.7), 1.0)
	draw_rect(Rect2(origin, box), PANEL)
	draw_rect(Rect2(origin, box), COLOR, false, 1.0)
	for i: int in lines.size():
		var color: Color = COLOR if i == 0 else UiStyle.BONE
		draw_string(font, origin + Vector2(5, 13 + i * 11), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
