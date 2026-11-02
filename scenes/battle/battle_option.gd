class_name BattleOption
extends Button
## Opción del menú de órdenes: el texto a la izquierda y, en gris, un dato alineado a la derecha
## (probabilidad de acierto, de huir…). La seleccionada se ve con la franja del tema.

## Dato a la derecha («64 %»). Vacío = nada.
var suffix: String = ""


func _draw() -> void:
	if suffix == "":
		return
	var font: Font = get_theme_font(&"font")
	var font_size: int = get_theme_font_size(&"font_size")
	var width: float = font.get_string_size(suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var color: Color = UiStyle.ASH if disabled else BattleFrame.LABEL_BLUE
	var baseline: float = (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(size.x - width - 6.0, baseline), suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
