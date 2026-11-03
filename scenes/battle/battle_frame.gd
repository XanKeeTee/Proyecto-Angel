class_name BattleFrame
extends Control
## Caja de chapa oxidada con remaches (9 cortes, `BattleSkin.metal_box`) y, si se le da, una
## pestaña de papel con cinta arriba a la izquierda («ÓRDENES», «OBJETOS»…), como el menú principal.
## También dibuja los iconos de estado (sangrado, hueso roto, amputado…) que se usan sobre el
## enemigo y en las fichas.

## Azul de tinta para datos secundarios (porcentajes, cantidades).
const LABEL_BLUE: Color = Color("8f9cc0")
## Lado de los iconos de estado.
const ICON_SIZE: float = 12.0
## Iconos: qué representa cada uno.
const ICON_BLEED: StringName = &"bleed"
const ICON_WOUND: StringName = &"wound"
const ICON_BROKEN: StringName = &"broken"
const ICON_AMPUTATED: StringName = &"amputated"
const ICON_STUN: StringName = &"stunned"
const ICON_GUARD: StringName = &"guard"
const ICON_PANIC: StringName = &"panic"

## Texto de la pestaña ("" = sin pestaña).
var tab: String = "":
	set(value):
		tab = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	BattleSkin.draw_metal(self, Rect2(Vector2.ZERO, size))
	if tab != "":
		BattleSkin.draw_tab(self, Vector2(18, -8), tab)


## Icono de estado con su textura, centrado en `center`. `letter` sirve para estados sin dibujo.
static func draw_icon(canvas: CanvasItem, kind: StringName, center: Vector2, letter: String = "") -> void:
	var tex: Texture2D = BattleSkin.status_icon(kind)
	if tex != null:
		BattleSkin.draw_icon_at(canvas, tex, center)
		return
	var half: float = ICON_SIZE * 0.5
	var box: Rect2 = Rect2((center - Vector2(half, half)).round(), Vector2(ICON_SIZE, ICON_SIZE))
	canvas.draw_rect(box, Color(0.08, 0.075, 0.08, 0.92))
	canvas.draw_rect(box.grow(-0.5), Color("8d877d"), false, 1.0)
	var font: Font = UiStyle.ui_bold()
	var text: String = letter.substr(0, 1).to_upper()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	canvas.draw_string(font, Vector2(box.get_center().x - width * 0.5, box.get_center().y + 3.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiStyle.AMBER)


## Icono que corresponde al estado de una parte (&"" si está sana).
static func part_icon(state: CombatTypes.PartState) -> StringName:
	match state:
		CombatTypes.PartState.WOUNDED:
			return ICON_WOUND
		CombatTypes.PartState.BROKEN:
			return ICON_BROKEN
		CombatTypes.PartState.AMPUTATED:
			return ICON_AMPUTATED
	return &""


## Iconos de los estados de un combatiente: [{kind, letter, label}]. El sangrado de todas las partes
## va junto; los estados apagados (la analgesia tapa el dolor) salen entre paréntesis.
static func status_icons(member: Combatant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var bleed: int = 0
	for entry: Dictionary in member.status_entries():
		if StringName(entry["id"]) == CombatTypes.STATUS_BLEED:
			bleed += int(entry["stacks"])
			continue
		var label: String = String(entry["name"])
		if int(entry["rounds"]) > 0:
			label += " (%d)" % int(entry["rounds"])
		if bool(entry["suppressed"]):
			label = "(%s)" % label
		result.append({"kind": StringName(entry["icon"]), "letter": String(entry["name"]), "label": label})
	if bleed > 0:
		result.insert(0, {"kind": ICON_BLEED, "letter": "", "label": "Sangrado ×%d" % bleed})
	if member.guarded_part != &"":
		result.append({"kind": ICON_GUARD, "letter": "", "label": "Se cubre"})
	if member.is_panicking() and not member.has_status(CombatTypes.STATUS_TERROR):
		result.append({"kind": ICON_PANIC, "letter": "", "label": "Pánico"})
	return result
