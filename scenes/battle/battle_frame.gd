class_name BattleFrame
extends Control
## Caja de la interfaz del combate, a la manera de los RPG clásicos: fondo oscuro translúcido y
## marco fino de dos tonos (claro por fuera, oscuro por dentro). También dibuja los iconos
## pequeños de estado (sangrado, rota, amputada…) que se usan sobre el enemigo y en las fichas.

const BACKGROUND: Color = Color(0.035, 0.032, 0.035, 0.84)
const BORDER_OUTER: Color = Color("9c968b")
const BORDER_INNER: Color = Color("26231f")
const BORDER_GLOW: Color = Color(0.62, 0.59, 0.53, 0.35)
## Franja de la opción o fila seleccionada.
const BAND: Color = Color(0.86, 0.82, 0.74, 0.14)
const BAND_BORDER: Color = Color(0.86, 0.82, 0.74, 0.32)
## Azul grisáceo de las palabras Cuerpo y Mente.
const LABEL_BLUE: Color = Color("7f8fb4")
const BAR_BODY: Color = Color("8e2a24")
const BAR_MIND: Color = Color("4d5d8e")
const BAR_BACK: Color = Color(0.16, 0.13, 0.13, 0.9)
## Lado de los iconos de estado.
const ICON_SIZE: float = 11.0
## Iconos: qué representa cada uno.
const ICON_BLEED: StringName = &"bleed"
const ICON_WOUND: StringName = &"wound"
const ICON_BROKEN: StringName = &"broken"
const ICON_AMPUTATED: StringName = &"amputated"
const ICON_STUN: StringName = &"stun"
const ICON_GUARD: StringName = &"guard"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_box(self, Rect2(Vector2.ZERO, size))


## Dibuja una caja con el marco de dos tonos en cualquier lienzo.
static func draw_box(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, BACKGROUND)
	canvas.draw_rect(rect.grow(-0.5), BORDER_OUTER, false, 1.0)
	canvas.draw_rect(rect.grow(-1.5), BORDER_INNER, false, 1.0)
	canvas.draw_rect(rect.grow(-2.5), BORDER_GLOW, false, 1.0)


## Franja de selección (opción del menú o fila del miembro activo).
static func draw_band(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, BAND)
	canvas.draw_rect(rect.grow(-0.5), BAND_BORDER, false, 1.0)


## Icono de estado con su marquito, centrado en `center`. `letter` sirve para estados sin dibujo.
static func draw_icon(canvas: CanvasItem, kind: StringName, center: Vector2, letter: String = "") -> void:
	var half: float = ICON_SIZE * 0.5
	var box: Rect2 = Rect2((center - Vector2(half, half)).round(), Vector2(ICON_SIZE, ICON_SIZE))
	canvas.draw_rect(box, Color(0.08, 0.075, 0.08, 0.92))
	canvas.draw_rect(box.grow(-0.5), Color("8d877d"), false, 1.0)
	var c: Vector2 = box.get_center()
	match kind:
		ICON_BLEED, ICON_WOUND:
			# Gota: punta arriba, panza abajo.
			var red: Color = Color("c42a1e") if kind == ICON_BLEED else Color("b3261c")
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(2.6, 0.5),
				c + Vector2(-2.6, 0.5)]), red)
			canvas.draw_circle(c + Vector2(0, 1.2), 2.6, red)
			canvas.draw_rect(Rect2(c + Vector2(-1.4, -0.4), Vector2(1, 1.4)), Color(1, 0.75, 0.7, 0.7))
		ICON_BROKEN:
			# Hueso partido en dos con la grieta en medio.
			var bone: Color = Color("ddd5c4")
			canvas.draw_line(c + Vector2(-3.5, 3.5), c + Vector2(-0.8, 0.8), bone, 1.6)
			canvas.draw_line(c + Vector2(0.8, -0.8), c + Vector2(3.5, -3.5), bone, 1.6)
			canvas.draw_circle(c + Vector2(-3.6, 3.0), 1.1, bone)
			canvas.draw_circle(c + Vector2(-3.0, 3.6), 1.1, bone)
			canvas.draw_circle(c + Vector2(3.6, -3.0), 1.1, bone)
			canvas.draw_circle(c + Vector2(3.0, -3.6), 1.1, bone)
			canvas.draw_line(c + Vector2(-1.4, -1.6), c + Vector2(1.4, 1.6), Color("b3261c"), 1.0)
		ICON_AMPUTATED:
			# Muñón visto de frente: carne roja con el hueso en medio.
			canvas.draw_circle(c, 3.8, Color("7d1712"))
			canvas.draw_circle(c, 2.6, Color("b3261c"))
			canvas.draw_circle(c, 1.2, Color("ddd5c4"))
		ICON_STUN:
			for i: int in 3:
				var a: float = TAU * i / 3.0 - PI / 2.0
				canvas.draw_circle(c + Vector2(cos(a), sin(a)) * 2.6, 1.1, UiStyle.AMBER)
		ICON_GUARD:
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -3.5), c + Vector2(3, -3.5),
				c + Vector2(3, 0.5), c + Vector2(0, 4), c + Vector2(-3, 0.5)]), Color("8fa9a3"))
		_:
			var font: Font = UiStyle.ui_bold()
			var text: String = letter.substr(0, 1).to_upper()
			var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			canvas.draw_string(font, Vector2(c.x - width * 0.5, c.y + 3.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
				UiStyle.AMBER)


## Icono que corresponde al estado de una parte ("" si está sana).
static func part_icon(state: CombatTypes.PartState) -> StringName:
	match state:
		CombatTypes.PartState.WOUNDED:
			return ICON_WOUND
		CombatTypes.PartState.BROKEN:
			return ICON_BROKEN
		CombatTypes.PartState.AMPUTATED:
			return ICON_AMPUTATED
	return &""
