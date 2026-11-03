class_name BodyDiagram
extends Control
## Lámina anatómica (vista anterior, dibujada a tinta) para elegir una parte del cuerpo: cada parte
## se colorea por su estado (Herida ámbar, Rota granate, Amputada borrada), la señalada se marca con
## un contorno rojo que late y, en cada línea de rótulo, va el acierto o el estado. Se elige con las
## flechas (desde el menú) o con el ratón sobre la lámina. Sirve para apuntar al enemigo y para
## elegir qué cubrir con la Guardia (con la parte que amenaza el enemigo señalada).
##
## Las partes que no están en la lámina (enemigos no humanoides) se eligen solo desde el menú.

## El ratón pasa por una parte de la lámina.
signal part_hovered(part_id: StringName)
## Clic sobre una parte.
signal part_pressed(part_id: StringName)

const OUTLINE_SHADER: Shader = preload("res://scenes/battle/part_outline.gdshader")
const PARTS: Array[StringName] = [&"head", &"torso", &"arm_r", &"arm_l", &"leg_r", &"leg_l"]
## Extremo de cada línea de rótulo (círculo) en la lámina, para el dato de la parte.
const LABEL_AT: Dictionary[StringName, Vector2] = {
	&"head": Vector2(14, 18), &"arm_r": Vector2(12, 80), &"leg_r": Vector2(12, 130),
	&"torso": Vector2(100, 60), &"arm_l": Vector2(100, 92), &"leg_l": Vector2(100, 136),
}
const PLATE_SIZE: Vector2 = Vector2(112, 160)
const THREAT_COLOR: Color = Color(0.85, 0.15, 0.1)

## Título de la pestaña («LÁMINA · ENFERMERO»).
var title: String = ""
## Parte señalada.
var selected: StringName = &"":
	set(value):
		selected = value
		_sync()
## Enseña el acierto en los rótulos (apuntar a un enemigo); en el cuerpo propio, el estado.
var show_chance: bool = true
## Parte que amenaza el enemigo (Guardia), con un aviso que parpadea; &"" = ninguna.
var threat_part: StringName = &""

var _parts: Dictionary[StringName, PartOption] = {}
var _overlays: Dictionary[StringName, TextureRect] = {}
var _outline: TextureRect
var _outline_material: ShaderMaterial
var _labels: Control
var _time: float = 0.0
var _hover: StringName = &""


func _init() -> void:
	size = PLATE_SIZE * BattleSkin.SCALE
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	var plate: TextureRect = TextureRect.new()
	plate.texture = BattleSkin.texture("diagram/plate")
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	for id: StringName in PARTS:
		var overlay: TextureRect = TextureRect.new()
		overlay.texture = BattleSkin.texture("diagram/" + String(id))
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.visible = false
		add_child(overlay)
		_overlays[id] = overlay
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE_SHADER
	_outline = TextureRect.new()
	_outline.material = _outline_material
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_outline)
	_labels = Control.new()
	_labels.size = size
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_labels.draw.connect(_draw_labels)
	add_child(_labels)
	_sync()


## Enseña la lámina con estas partes (estado, acierto y si se pueden elegir).
func show_parts(p_title: String, parts: Array[PartOption], p_selected: StringName, p_threat: StringName = &"") -> void:
	title = p_title
	_parts.clear()
	for option: PartOption in parts:
		_parts[option.id] = option
	threat_part = p_threat
	visible = true
	selected = p_selected


func close() -> void:
	visible = false
	_hover = &""


## Parte de la lámina bajo un punto local (o &"" si no hay ninguna elegible).
func part_at(point: Vector2) -> StringName:
	var pixel: Vector2i = Vector2i((point / BattleSkin.SCALE).floor())
	for id: StringName in [&"head", &"arm_r", &"arm_l", &"leg_r", &"leg_l", &"torso"]:
		if not _parts.has(id) or not _parts[id].enabled:
			continue
		var img: Image = BattleSkin.image("diagram/" + String(id))
		if img == null:
			continue
		if pixel.x < 0 or pixel.y < 0 or pixel.x >= img.get_width() or pixel.y >= img.get_height():
			continue
		if img.get_pixelv(pixel).a > 0.5:
			return id
	return &""


## Centro aproximado de una parte en la lámina (para pruebas y para el ratón).
func part_center(part_id: StringName) -> Vector2:
	var img: Image = BattleSkin.image("diagram/" + String(part_id))
	if img == null:
		return size * 0.5
	var used: Rect2i = img.get_used_rect()
	return Vector2(used.get_center()) * BattleSkin.SCALE


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	var pulse: float = 0.65 + 0.35 * sin(_time * 6.0)
	_outline_material.set_shader_parameter(&"line_color", Color(THREAT_COLOR, pulse))
	_labels.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		var id: StringName = part_at(motion.position)
		if id != &"" and id != _hover:
			_hover = id
			part_hovered.emit(id)
		elif id == &"":
			_hover = &""
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var id: StringName = part_at(click.position)
		if id != &"":
			accept_event()
			part_pressed.emit(id)


func _sync() -> void:
	if _outline == null:
		return
	for id: StringName in _overlays:
		var overlay: TextureRect = _overlays[id]
		var option: PartOption = _parts.get(id)
		if option == null:
			overlay.visible = false
			continue
		match option.state:
			CombatTypes.PartState.HEALTHY:
				overlay.visible = false
			CombatTypes.PartState.AMPUTATED:
				overlay.visible = true
				overlay.modulate = Color(BattleSkin.PAPER.darkened(0.08), 0.92)
			_:
				overlay.visible = true
				overlay.modulate = Color(BattleSkin.STATE_COLORS[option.state], 0.5)
	_outline.texture = BattleSkin.texture("diagram/" + String(selected)) if _overlays.has(selected) else null
	_outline_material.set_shader_parameter(&"fill", 0.22)
	_labels.queue_redraw()


func _draw_labels() -> void:
	var font: Font = UiStyle.mono()
	var font_size: int = UiStyle.MONO_SMALL
	if title != "":
		BattleSkin.draw_tab(_labels, Vector2(8, -9), title)
	for id: StringName in LABEL_AT:
		var option: PartOption = _parts.get(id)
		if option == null:
			continue
		var at: Vector2 = LABEL_AT[id] * BattleSkin.SCALE
		var text: String
		var color: Color = BattleSkin.STATE_INK[option.state]
		if option.state == CombatTypes.PartState.AMPUTATED:
			text = "—"
		elif option.bleeding > 0:
			text = "×%d" % option.bleeding
			color = BattleSkin.INK_RED
		elif not option.enabled:
			text = "—"
		elif show_chance and option.hit_chance > 0:
			text = "%d" % option.hit_chance
			color = BattleSkin.INK if option.state == CombatTypes.PartState.HEALTHY else color
		else:
			text = CombatTypes.PART_STATE_NAMES[option.state].substr(0, 1)
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var box: Rect2 = Rect2(at - Vector2(w * 0.5 + 2, 5), Vector2(w + 4, 10))
		var chosen: bool = id == selected
		_labels.draw_rect(box, BattleSkin.PAPER if not chosen else Color("8e1f1a"))
		_labels.draw_rect(box.grow(-0.5), Color(BattleSkin.INK, 0.6), false, 1.0)
		_labels.draw_string(font, Vector2(box.position.x + 2, at.y + 3.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, BattleSkin.PAPER if chosen else color)
		var icon: StringName = BattleFrame.part_icon(option.state as CombatTypes.PartState)
		if option.bleeding > 0:
			icon = BattleFrame.ICON_BLEED
		if icon != &"":
			var side: float = -1.0 if at.x > size.x * 0.5 else 1.0
			BattleFrame.draw_icon(_labels, icon, at + Vector2(side * (w * 0.5 + 9), 0))
	if threat_part != &"" and LABEL_AT.has(threat_part):
		var blink: bool = fmod(_time, 0.8) < 0.5
		if blink:
			var at: Vector2 = part_center(threat_part)
			_labels.draw_arc(at, 7.0, 0, TAU, 16, THREAT_COLOR, 1.5)
			_labels.draw_string(font, at + Vector2(-3, 3), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, THREAT_COLOR)
