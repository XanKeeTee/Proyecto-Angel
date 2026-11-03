class_name BattleOption
extends Button
## Opción del menú de órdenes: marca roja a mano y franja granate cuando está elegida (como en el
## menú principal), su icono, el texto y, a la derecha, un dato (acierto, cantidad, coste). Las
## desactivadas se ven tachadas a lápiz; su motivo lo cuenta la ficha de detalle.

## Hueco a la izquierda para la marca y el icono.
const LEFT: float = 30.0

## Dato a la derecha («64 %», «×2»). Vacío = nada.
var suffix: String = ""
## Icono de la orden (16×16) o null.
var icon_texture: Texture2D
## Opción del modelo que representa (o null en las de navegación: «Atrás», categorías…).
var option: ActionOption
## Categoría que abre (en el menú principal) o &"".
var category: StringName = &""
## Parte que señala (al apuntar) o &"".
var part_id: StringName = &""
## Momento en que ganó el foco (para la animación de entrada de la marca).
var _focus_time: float = 0.0


func _ready() -> void:
	focus_entered.connect(func() -> void:
		_focus_time = 0.0
		set_process(true))
	set_process(false)


func _process(delta: float) -> void:
	_focus_time += delta
	queue_redraw()
	if _focus_time > 0.3:
		set_process(false)


func _draw() -> void:
	var font: Font = get_theme_font(&"font")
	var font_size: int = get_theme_font_size(&"font_size")
	var baseline: float = (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var focused: bool = has_focus()
	if focused:
		var check: Texture2D = BattleSkin.texture("check")
		if check != null:
			var grow: float = clampf(_focus_time / 0.12, 0.0, 1.0)
			var rect: Rect2 = Rect2(Vector2(2, size.y * 0.5 - 6), Vector2(12 * grow, 12))
			draw_texture_rect_region(check, rect, Rect2(Vector2.ZERO, Vector2(12 * grow, 12)))
	if icon_texture != null:
		var tint: Color = Color(1, 1, 1, 0.4) if disabled else (Color.WHITE if focused else Color(0.82, 0.8, 0.76))
		BattleSkin.draw_icon_at(self, icon_texture, Vector2(21, size.y * 0.5), 14.0, tint)
	if disabled:
		var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var y: float = roundf(size.y * 0.5) + 0.5
		draw_line(Vector2(LEFT - 1, y), Vector2(LEFT + text_w + 2, y - 1), Color(BattleSkin.BLOOD, 0.7), 1.0)
	if suffix == "":
		return
	var width: float = font.get_string_size(suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var color: Color = UiStyle.ASH if disabled else (BattleSkin.AMBER if focused else BattleFrame.LABEL_BLUE)
	draw_string(font, Vector2(size.x - width - 6.0, baseline), suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
