class_name Hud
extends CanvasLayer
## HUD de exploración, discreto: indicador de interacción, bolsillos, batería y avisos.
## Los bolsillos y la batería se ocultan solos cuando no cambian.

const SHOW_TIME: float = 3.5
const LOW_CHARGE: float = 0.2

var _prompt_name: Label
var _prompt_keys: Label
var _prompt_box: Control
var _pockets: Control
var _pocket_slots: Array[Panel] = []
var _pocket_icons: Array[TextureRect] = []
var _pocket_qty: Array[Label] = []
var _battery: Control
var _battery_fill: ColorRect
var _battery_label: Label
var _bleed: Label
var _notices: VBoxContainer
var _visible_timer: float = 0.0
var _last_charge: float = -1.0
var _blink: float = 0.0


func _init() -> void:
	layer = 10


func _ready() -> void:
	_build()
	set_prompt("", [])


func _process(delta: float) -> void:
	var character: CharacterState = GameState.character
	var lamp: ItemStack = character.flashlight()
	_battery.visible = lamp != null
	if lamp != null:
		var ratio: float = lamp.charge / lamp.def.max_charge
		if absf(ratio - _last_charge) > 0.005:
			if _last_charge >= 0.0 and int(ratio * 100) / 10 != int(_last_charge * 100) / 10:
				poke()
			_last_charge = ratio
		_battery_fill.size.x = 26.0 * ratio
		_battery_fill.color = UiStyle.SICK_GREEN if ratio > LOW_CHARGE else UiStyle.BLOOD
		_battery_label.text = "%d %%" % roundi(ratio * 100.0)
		_blink += delta
		if ratio <= LOW_CHARGE:
			_battery.modulate.a = 0.5 + 0.5 * absf(sin(_blink * 4.0))
			_visible_timer = SHOW_TIME
	_bleed.visible = character.vitals.bleeding
	_visible_timer -= delta
	var target: float = 1.0 if _visible_timer > 0.0 else 0.0
	_pockets.modulate.a = move_toward(_pockets.modulate.a, target, delta * 3.0)
	if lamp != null and lamp.charge / lamp.def.max_charge > LOW_CHARGE:
		_battery.modulate.a = move_toward(_battery.modulate.a, maxf(target, 0.35), delta * 3.0)


## Muestra el nombre del objeto y sus acciones ([E] Abrir · [R] Examinar). Vacío = oculto.
func set_prompt(object_name: String, actions: Array[String]) -> void:
	_prompt_box.visible = object_name != ""
	_prompt_name.text = object_name
	_prompt_keys.text = "    ".join(actions)


## Saca los bolsillos y la batería un rato.
func poke() -> void:
	_visible_timer = SHOW_TIME
	refresh_pockets()


func refresh_pockets() -> void:
	var custody: Custody = GameState.character.custody
	for i: int in Custody.POCKETS:
		var stack: ItemStack = custody.pockets[i]
		_pocket_icons[i].texture = stack.def.icon if stack != null else null
		_pocket_qty[i].text = ("×%d" % stack.quantity) if stack != null and stack.quantity > 1 else ""
		if stack != null and stack.def.icon == null:
			_pocket_qty[i].text = stack.def.display_name.substr(0, 3)
		if stack != null and stack.def.icon != null:
			# Reducción entera para que el icono no se deforme (1/1, 1/2, 1/3).
			var big: float = maxf(stack.def.icon.get_width(), stack.def.icon.get_height())
			var k: float = 1.0 / ceilf(big / 30.0)
			_pocket_icons[i].size = (stack.def.icon.get_size() * k).floor()
			_pocket_icons[i].position = ((Vector2(34, 34) - _pocket_icons[i].size) / 2.0).floor()


## Pulso visual en un bolsillo al usarlo.
func flash_pocket(index: int) -> void:
	poke()
	var slot: Panel = _pocket_slots[index]
	slot.modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(slot, "modulate", Color.WHITE, 0.3)


## Aviso breve arriba en el centro ("Coges: Pilas ×2").
func notice(text: String) -> void:
	if text.strip_edges() == "" or text == "·":
		return
	var l: Label = UiStyle.label(text, UiStyle.SIZE_TEXT, UiStyle.BONE)
	UiStyle.add_shadow(l)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(640, 0)
	l.modulate.a = 0.0
	_notices.add_child(l)
	var tween: Tween = create_tween()
	tween.tween_property(l, "modulate:a", 1.0, 0.25)
	tween.tween_interval(2.6)
	tween.tween_property(l, "modulate:a", 0.0, 0.8)
	tween.tween_callback(l.queue_free)


func _build() -> void:
	_prompt_box = PanelContainer.new()
	_prompt_box.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("0c0d0f"), Color("3a4046"), 0.72))
	_prompt_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_box.offset_bottom = -56
	add_child(_prompt_box)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_prompt_box.add_child(col)
	_prompt_name = UiStyle.label("", UiStyle.SIZE_TEXT, UiStyle.BONE, UiStyle.ui_bold())
	_prompt_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_prompt_name)
	_prompt_keys = UiStyle.label("", UiStyle.MONO_TEXT, UiStyle.BONE_DIM, UiStyle.mono())
	_prompt_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_prompt_keys)

	_pockets = HBoxContainer.new()
	_pockets.position = Vector2(8, 318)
	_pockets.add_theme_constant_override("separation", 3)
	_pockets.modulate.a = 0.0
	add_child(_pockets)
	for i: int in Custody.POCKETS:
		var slot: Panel = Panel.new()
		slot.custom_minimum_size = Vector2(34, 34)
		slot.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("0e1012"), Color("3a4046"), 0.8))
		_pockets.add_child(slot)
		var icon: TextureRect = TextureRect.new()
		icon.position = Vector2(2, 2)
		icon.size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.add_child(icon)
		var key: Label = UiStyle.label(str(i + 1), UiStyle.MONO_SMALL, UiStyle.ASH, UiStyle.mono())
		key.position = Vector2(3, 0)
		slot.add_child(key)
		var qty: Label = UiStyle.label("", UiStyle.MONO_SMALL, UiStyle.BONE, UiStyle.mono())
		UiStyle.add_shadow(qty)
		qty.position = Vector2(14, 20)
		slot.add_child(qty)
		_pocket_slots.append(slot)
		_pocket_icons.append(icon)
		_pocket_qty.append(qty)

	_battery = Control.new()
	_battery.position = Vector2(596, 336)
	add_child(_battery)
	var shell: Panel = Panel.new()
	shell.size = Vector2(30, 10)
	shell.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("0e1012"), UiStyle.BONE_DIM, 0.8))
	_battery.add_child(shell)
	var tip: ColorRect = ColorRect.new()
	tip.color = UiStyle.BONE_DIM
	tip.position = Vector2(30, 3)
	tip.size = Vector2(2, 4)
	_battery.add_child(tip)
	_battery_fill = ColorRect.new()
	_battery_fill.position = Vector2(2, 2)
	_battery_fill.size = Vector2(26, 6)
	_battery.add_child(_battery_fill)
	_battery_label = UiStyle.label("", UiStyle.MONO_SMALL, UiStyle.BONE_DIM, UiStyle.mono())
	UiStyle.add_shadow(_battery_label)
	_battery_label.position = Vector2(-38, -3)
	_battery.add_child(_battery_label)

	_bleed = UiStyle.label("SANGRADO", UiStyle.MONO_TEXT, UiStyle.BLOOD, UiStyle.mono())
	UiStyle.add_shadow(_bleed)
	_bleed.position = Vector2(566, 316)
	add_child(_bleed)

	_notices = VBoxContainer.new()
	_notices.position = Vector2(0, 14)
	_notices.add_theme_constant_override("separation", 2)
	add_child(_notices)
