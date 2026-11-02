class_name PartyCard
extends Control
## Ficha de un miembro del grupo en la parte de abajo del combate: retrato, Cuerpo, Mente, estado,
## silueta con las heridas de cada parte, lista de heridas y arma.

const PORTRAIT_SHEET: String = "res://assets/sprites/characters/protagonist.png"
## Fotograma de frente en reposo y recorte de cabeza y hombros dentro de él.
const PORTRAIT_FRAME: Vector2i = Vector2i(48, 68)
const PORTRAIT_REGION: Rect2 = Rect2(10, 2, 28, 34)
const PORTRAIT_RECT: Rect2 = Rect2(4, 16, 46, 56)
const BAR_X: float = 56.0
const BAR_W: float = 104.0
const COLOR_BODY: Color = Color("b03a34")
const COLOR_MIND: Color = Color("7d8ad0")
const COLOR_BAR_BG: Color = Color(0.1, 0.09, 0.1)
const COLOR_FRAME: Color = Color(0.3, 0.29, 0.33)

var combatant: Combatant
## Para el arma y la ropa del retrato (opcional).
var character: CharacterState
var selected: bool = false
## Posición de reposo (las sacudidas y saltos vuelven siempre aquí).
var home: Vector2 = Vector2.ZERO

var _diagram: BodyDiagram
var _portrait_layers: Array[Texture2D] = []
var _flash_tween: Tween
var _shake_tween: Tween
var _hurt: float = 0.0


func setup(member: Combatant, state: CharacterState = null) -> void:
	combatant = member
	character = state
	custom_minimum_size = Vector2(272, 100)
	size = custom_minimum_size
	clip_contents = true
	_portrait_layers.clear()
	if ResourceLoader.exists(PORTRAIT_SHEET):
		_portrait_layers.append(load(PORTRAIT_SHEET))
	if state != null:
		for slot: ItemDef.EquipSlot in [ItemDef.EquipSlot.LEGS, ItemDef.EquipSlot.FEET, ItemDef.EquipSlot.BODY, ItemDef.EquipSlot.HEAD]:
			var worn: ItemStack = state.worn(slot)
			if worn == null or worn.def.wear_path == "" or not ResourceLoader.exists(worn.def.wear_path):
				continue
			var tex: Texture2D = load(worn.def.wear_path)
			var canvas: CanvasTexture = tex as CanvasTexture
			_portrait_layers.append(canvas.diffuse_texture if canvas != null else tex)
	if _diagram == null:
		_diagram = BodyDiagram.new()
		_diagram.position = Vector2(170, 20)
		_diagram.size = Vector2(36, 50)
		_diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_diagram)
	_diagram.combatant = member
	refresh()


func refresh() -> void:
	if _diagram != null:
		_diagram.queue_redraw()
	queue_redraw()


## Resalta una parte propia (al elegir qué cubrir).
func highlight(part_id: StringName) -> void:
	if _diagram != null:
		_diagram.highlight_part = part_id
		_diagram.queue_redraw()


## Destello rojo y sacudida al recibir un golpe.
func hurt(strength: float = 1.0) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_hurt = strength
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "_hurt", 0.0, 0.45)
	_flash_tween.parallel().tween_method(func(_v: float) -> void: queue_redraw(), 0.0, 1.0, 0.45)
	if _shake_tween != null:
		_shake_tween.kill()
	var base: Vector2 = home
	_shake_tween = create_tween()
	for i: int in 5:
		_shake_tween.tween_property(self, "position", base + Vector2(randf_range(-3, 3), randf_range(-2, 2)) * strength, 0.03)
	_shake_tween.tween_property(self, "position", base, 0.04)


## Pequeño salto al atacar.
func bump() -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "position", home + Vector2(0, -8), 0.08)
	_shake_tween.tween_property(self, "position", home, 0.12)


func _draw() -> void:
	if combatant == null:
		return
	var font: Font = UiStyle.ui()
	var bold: Font = UiStyle.ui_bold()
	var mono: Font = UiStyle.mono()
	# Marco.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.04, 0.06, 0.9))
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.AMBER if selected else COLOR_FRAME, false, 1.0)
	draw_string(bold, Vector2(6, 13), ("▸ " if selected else "") + combatant.display_name(), HORIZONTAL_ALIGNMENT_LEFT,
		150, UiStyle.SIZE_SMALL, UiStyle.AMBER if selected else UiStyle.BONE)
	_draw_portrait()
	# Barras de Cuerpo y Mente.
	_draw_bar(Vector2(BAR_X, 20), "CUERPO", combatant.body, combatant.def.body_max, COLOR_BODY, mono)
	if combatant.def.has_mind:
		_draw_bar(Vector2(BAR_X, 42), "MENTE", combatant.mind, combatant.def.mind_max, COLOR_MIND, mono)
	# Estado (sangrado, sedación, agarre…).
	var status: String = combatant.status_text()
	if status != "":
		draw_string(font, Vector2(BAR_X, 76), status, HORIZONTAL_ALIGNMENT_LEFT, BAR_W + 8, UiStyle.SIZE_SMALL - 1,
			UiStyle.BLOOD.lightened(0.25))
	# Arma.
	var weapon: WeaponDef = combatant.current_weapon()
	draw_string(mono, Vector2(BAR_X, 92), "Arma: " + weapon.display_name, HORIZONTAL_ALIGNMENT_LEFT, 150,
		UiStyle.MONO_SMALL, UiStyle.ASH)
	# Heridas por parte (solo las que no están sanas).
	var y: float = 22.0
	draw_string(mono, Vector2(212, 13), "HERIDAS", HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.MONO_SMALL, UiStyle.ASH)
	var any: bool = false
	for id: StringName in combatant.part_order:
		var part: BodyPartState = combatant.parts[id]
		if part.state == CombatTypes.PartState.HEALTHY:
			continue
		any = true
		var color: Color = UiStyle.AMBER if part.state == CombatTypes.PartState.WOUNDED else UiStyle.BLOOD.lightened(0.2)
		draw_string(mono, Vector2(212, y + 6), _short(part.def.display_name), HORIZONTAL_ALIGNMENT_LEFT, 58,
			UiStyle.MONO_SMALL - 1, UiStyle.BONE_DIM)
		draw_string(mono, Vector2(212, y + 15), CombatTypes.PART_STATE_NAMES[part.state], HORIZONTAL_ALIGNMENT_LEFT, 58,
			UiStyle.MONO_SMALL - 1, color)
		y += 19.0
		if y > 90.0:
			break
	if not any:
		draw_string(mono, Vector2(212, 30), "Ninguna", HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.MONO_SMALL - 1, UiStyle.ASH)
	if _hurt > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.7, 0.05, 0.05, 0.45 * _hurt))


func _draw_portrait() -> void:
	draw_rect(PORTRAIT_RECT.grow(1.0), COLOR_FRAME, false, 1.0)
	draw_rect(PORTRAIT_RECT, Color(0.08, 0.08, 0.1))
	for tex: Texture2D in _portrait_layers:
		draw_texture_rect_region(tex, PORTRAIT_RECT, PORTRAIT_REGION)
	# Pálido con el Cuerpo bajo; en negro si cae.
	var ratio: float = float(combatant.body) / combatant.def.body_max
	if combatant.dead or combatant.fallen:
		draw_rect(PORTRAIT_RECT, Color(0, 0, 0, 0.7))
	elif ratio < 0.5:
		draw_rect(PORTRAIT_RECT, Color(0.5, 0.0, 0.0, (0.5 - ratio) * 0.8))
	if combatant.breakable_status() != null:
		draw_rect(PORTRAIT_RECT, UiStyle.AMBER, false, 2.0)


func _draw_bar(at: Vector2, label: String, value: int, maximum: int, color: Color, font: Font) -> void:
	draw_string(font, at + Vector2(0, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.MONO_SMALL, UiStyle.ASH)
	var number: String = "%d" % value
	draw_string(font, at + Vector2(BAR_W - font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.MONO_SMALL).x, 0),
		number, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.MONO_SMALL, UiStyle.BONE)
	var rect: Rect2 = Rect2(at + Vector2(0, 4), Vector2(BAR_W, 6))
	draw_rect(rect, COLOR_BAR_BG)
	draw_rect(Rect2(rect.position, Vector2(BAR_W * clampf(float(value) / maximum, 0.0, 1.0), 6)), color)
	draw_rect(rect, COLOR_FRAME, false, 1.0)


func _short(text: String) -> String:
	return text.replace("Brazo", "Br.").replace("Pierna", "Pi.")
