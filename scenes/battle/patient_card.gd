class_name PatientCard
extends Control
## Ficha de paciente de un miembro del grupo (abajo a la derecha): foto de la figura de espaldas,
## **Cuerpo** y **Mente** como líquido en tubos de vidrio graduados, el **mapa de heridas** (silueta
## con cada parte coloreada por su estado, y la que amenaza el enemigo parpadeando), el arma
## empuñada con su icono y los estados. Reacciona a los golpes: tiembla, se mancha de sangre y el
## líquido baja dejando un rastro que se vacía despacio. Admite hasta cuatro fichas en fila: si es
## estrecha, se compacta (sin foto).
##
## Al pasar el ratón o pulsar pide enseñar sus heridas (`details_requested`).

## Pide abrir (true) o cerrar (false) la ficha de heridas. `pinned`: se pulsó (se queda abierta).
signal details_requested(card: PatientCard, show: bool, pinned: bool)

const COMPACT_WIDTH: float = 220.0
const PHOTO_SIZE: Vector2 = Vector2(36, 52)
const TUBE_H: float = 8.0
const MINI_SIZE: Vector2 = Vector2(22, 40)
const MAX_STAINS: int = 7
const MINI_PARTS: Array[StringName] = [&"head", &"torso", &"arm_r", &"arm_l", &"leg_r", &"leg_l"]

var combatant: Combatant
## Icono del arma empuñada (null = a mano desnuda).
var weapon_icon: Texture2D
## Capas de la figura para la foto (las de `PartyBattler`).
var portrait: Array[Texture2D] = []
## Pies de la figura dentro de las capas (para encuadrar la foto).
var portrait_origin: Vector2 = Vector2(24, 62)
## Es quien elige ahora.
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
## Parte a la que apunta el enemigo (parpadea en el mapa de heridas); &"" = ninguna.
var threat_part: StringName = &""

var _body_shown: float = -1.0
var _mind_shown: float = -1.0
var _body_ghost: float = -1.0
var _mind_ghost: float = -1.0
var _shake: Vector2 = Vector2.ZERO
var _flash: float = 0.0
var _stains: Array[Dictionary] = []
var _time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(member: Combatant, icon: Texture2D, figure: Array[Texture2D] = [], figure_origin: Vector2 = Vector2(24, 62)) -> void:
	combatant = member
	weapon_icon = icon
	portrait = figure
	portrait_origin = figure_origin
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	if not mouse_entered.is_connected(_on_hover):
		mouse_entered.connect(_on_hover.bind(true))
		mouse_exited.connect(_on_hover.bind(false))
	_body_shown = member.body
	_mind_shown = member.mind
	_body_ghost = _body_shown
	_mind_ghost = _mind_shown
	queue_redraw()


func compact() -> bool:
	return size.x < COMPACT_WIDTH


## Zonas de la ficha (para las pruebas y para colocar cosas encima): photo, body, mind, wounds, weapon.
func layout() -> Dictionary[StringName, Rect2]:
	var result: Dictionary[StringName, Rect2] = {}
	var x: float = 8.0
	var top: float = 12.0
	if not compact():
		result[&"photo"] = Rect2(Vector2(x, top), PHOTO_SIZE)
		x += PHOTO_SIZE.x + 8.0
	var wounds_w: float = MINI_SIZE.x + 6.0
	var tubes_w: float = clampf(size.x - x - wounds_w - 120.0, 60.0, 200.0)
	if compact():
		tubes_w = size.x - x - wounds_w - 12.0
	result[&"body"] = Rect2(Vector2(x, top + 2), Vector2(tubes_w, 22))
	result[&"mind"] = Rect2(Vector2(x, top + 28), Vector2(tubes_w, 22))
	var wx: float = x + tubes_w + 8.0
	result[&"wounds"] = Rect2(Vector2(wx, top + 4), MINI_SIZE)
	if compact():
		result[&"weapon"] = Rect2(Vector2(8, size.y - 22), Vector2(size.x - 16, 16))
	else:
		var weapon_x: float = wx + wounds_w + 6.0
		result[&"weapon"] = Rect2(Vector2(weapon_x, top + 2), Vector2(size.x - weapon_x - 8.0, 48))
	return result


## El combate ha cambiado: los tubos van hacia el valor nuevo (bajan despacio, con rastro).
func refresh() -> void:
	queue_redraw()


## Golpe recibido: tiembla, se mancha y destella.
func hurt(strength: float = 1.0) -> void:
	_flash = clampf(strength, 0.0, 1.0)
	var tween: Tween = create_tween()
	for i: int in 6:
		tween.tween_method(func(v: Vector2) -> void:
			_shake = v
			queue_redraw(), _shake, Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-2, 2)) * strength, 0.035)
	tween.tween_method(func(v: Vector2) -> void:
		_shake = v
		queue_redraw(), Vector2(2, 1), Vector2.ZERO, 0.05)
	if strength >= 0.6 or _rng.randf() < 0.6:
		_stains.append({"p": Vector2(_rng.randf_range(10, size.x - 10), _rng.randf_range(8, size.y - 8)),
			"r": _rng.randf_range(2.0, 4.5) * strength, "seed": _rng.randi()})
		while _stains.size() > MAX_STAINS:
			_stains.pop_front()


func _process(delta: float) -> void:
	if combatant == null:
		return
	_time += delta
	_body_shown = move_toward(_body_shown, combatant.body, delta * 60.0)
	_mind_shown = move_toward(_mind_shown, combatant.mind, delta * 60.0)
	# El rastro se queda un momento arriba y luego se vacía.
	_body_ghost = _body_shown if _body_ghost < _body_shown else move_toward(_body_ghost, _body_shown, delta * 18.0)
	_mind_ghost = _mind_shown if _mind_ghost < _mind_shown else move_toward(_mind_ghost, _mind_shown, delta * 18.0)
	_flash = maxf(0.0, _flash - delta * 2.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		details_requested.emit(self, true, true)
		accept_event()


func _on_hover(inside: bool) -> void:
	details_requested.emit(self, inside, false)


func _draw() -> void:
	if combatant == null:
		return
	var lift: Vector2 = Vector2(0, -3) if selected else Vector2.ZERO
	draw_set_transform(_shake + lift, 0.0, Vector2.ONE)
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	BattleSkin.draw_paper(self, rect)
	var out: bool = not combatant.is_active()
	var zones: Dictionary[StringName, Rect2] = layout()
	if zones.has(&"photo"):
		_draw_photo(zones[&"photo"])
	_draw_tube(zones[&"body"], "CUERPO", _body_shown, _body_ghost, combatant.def.body_max, combatant.body,
		BattleSkin.LIQUID_BODY)
	if combatant.def.has_mind:
		_draw_tube(zones[&"mind"], "MENTE", _mind_shown, _mind_ghost, combatant.def.mind_max, combatant.mind,
			BattleSkin.LIQUID_MIND)
	_draw_wounds(zones[&"wounds"])
	_draw_weapon(zones[&"weapon"])
	for stain: Dictionary in _stains:
		_draw_stain(stain)
	if out:
		draw_rect(rect, Color(0.1, 0.08, 0.08, 0.35))
		var text: String = combatant.status_text()
		var font: Font = UiStyle.mono()
		draw_string(font, Vector2(rect.size.x * 0.5 - 30, rect.size.y * 0.55), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UiStyle.MONO_TEXT, BattleSkin.INK_RED)
	if _flash > 0.0:
		draw_rect(rect, Color(0.7, 0.05, 0.05, 0.35 * _flash))
	var tab_rect: Rect2 = BattleSkin.draw_tab(self, Vector2(10, -8), combatant.display_name().to_upper(),
		BattleSkin.INK_RED if selected else BattleSkin.INK)
	if selected:
		var check: Texture2D = BattleSkin.texture("check")
		if check != null:
			draw_texture(check, Vector2(tab_rect.end.x + 2, tab_rect.position.y))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_photo(zone: Rect2) -> void:
	draw_rect(zone.grow(1), Color(0.92, 0.9, 0.84))
	draw_rect(zone, Color(0.08, 0.08, 0.09))
	if not portrait.is_empty():
		var tex_size: Vector2 = portrait[0].get_size()
		var scale_f: float = zone.size.y * 1.15 / tex_size.y
		var origin: Vector2 = zone.position + Vector2(zone.size.x * 0.5, zone.size.y + 10.0) - portrait_origin * scale_f
		var sepia: Color = Color(0.85, 0.78, 0.68) if combatant.is_active() else Color(0.4, 0.36, 0.34)
		for tex: Texture2D in portrait:
			var dest: Rect2 = Rect2(origin, tex.get_size() * scale_f)
			var clip: Rect2 = dest.intersection(zone)
			if clip.size.x <= 0.0 or clip.size.y <= 0.0:
				continue
			var src: Rect2 = Rect2((clip.position - dest.position) / scale_f, clip.size / scale_f)
			draw_texture_rect_region(tex, clip, src, sepia)
	BattleSkin.draw_tape(self, zone.position + Vector2(-5, -4), -0.5)
	var font: Font = UiStyle.mono()
	draw_string(font, Vector2(zone.position.x, zone.end.y + 9), "EXP. %s" % _number(), HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiStyle.MONO_SMALL, BattleSkin.INK_SOFT)


func _draw_tube(zone: Rect2, label: String, shown: float, ghost: float, maximum: int, value: int, liquid: Color) -> void:
	var font: Font = UiStyle.mono()
	draw_string(font, Vector2(zone.position.x, zone.position.y + 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiStyle.MONO_SMALL, BattleSkin.INK_SOFT)
	var number: String = "%d/%d" % [value, maximum]
	var serif: Font = UiStyle.ui_bold()
	var nw: float = serif.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.SIZE_TEXT).x
	var low: bool = value * 4 < maximum
	draw_string(serif, Vector2(zone.end.x - nw, zone.position.y + 9), number, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiStyle.SIZE_TEXT, BattleSkin.INK_RED if low else BattleSkin.INK)
	var tube: Rect2 = Rect2(Vector2(zone.position.x, zone.position.y + 12), Vector2(zone.size.x, TUBE_H))
	var inner: Rect2 = Rect2(tube.position + Vector2(5, 2), Vector2(tube.size.x - 10, TUBE_H - 4))
	draw_rect(inner, Color(0.08, 0.09, 0.09, 0.9))
	var frac: float = clampf(shown / maxf(1.0, maximum), 0.0, 1.0)
	var ghost_frac: float = clampf(ghost / maxf(1.0, maximum), 0.0, 1.0)
	if ghost_frac > frac:
		draw_rect(Rect2(inner.position + Vector2(inner.size.x * frac, 0), Vector2(inner.size.x * (ghost_frac - frac),
			inner.size.y)), Color(liquid.lightened(0.45), 0.8))
	var fill: Rect2 = Rect2(inner.position, Vector2(roundf(inner.size.x * frac), inner.size.y))
	draw_rect(fill, liquid)
	draw_rect(Rect2(fill.position, Vector2(fill.size.x, 1)), liquid.lightened(0.3))
	if fill.size.x > 2:
		# menisco y una burbuja que sube de vez en cuando
		draw_line(Vector2(fill.end.x - 0.5, inner.position.y), Vector2(fill.end.x - 0.5, inner.end.y), liquid.lightened(0.5), 1.0)
		var bubble: float = fmod(_time * 0.35 + label.length() * 0.21, 1.0)
		draw_rect(Rect2(Vector2(inner.position.x + fill.size.x * bubble, inner.position.y + 1), Vector2(1, 1)),
			Color(1, 1, 1, 0.35))
	# graduación cada 10 %
	for i: int in range(1, 10):
		var gx: float = roundf(inner.position.x + inner.size.x * i / 10.0)
		draw_line(Vector2(gx, inner.position.y), Vector2(gx, inner.position.y + (2.0 if i % 5 else 3.0)),
			Color(0.9, 0.92, 0.88, 0.45), 1.0)
	var box: StyleBoxTexture = BattleSkin.tube_box()
	if box.texture != null:
		draw_style_box(box, tube)


func _draw_wounds(zone: Rect2) -> void:
	var font: Font = UiStyle.mono()
	draw_string(font, Vector2(zone.position.x - 2, zone.position.y - 1), "LES.", HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiStyle.MONO_SMALL, BattleSkin.INK_SOFT)
	var blink: bool = fmod(_time, 0.7) < 0.42
	for id: StringName in MINI_PARTS:
		var tex: Texture2D = BattleSkin.texture("diagram/mini_" + String(id))
		if tex == null:
			continue
		var color: Color = Color(0.72, 0.68, 0.6)
		if combatant.has_part(id):
			var state: int = combatant.parts[id].state
			if state == CombatTypes.PartState.AMPUTATED:
				continue
			if state != CombatTypes.PartState.HEALTHY:
				color = BattleSkin.STATE_COLORS[state]
		if id == combatant.guarded_part:
			color = color.lerp(Color("5f8a86"), 0.6)
		if id == threat_part and blink:
			color = Color(0.95, 0.2, 0.1)
		draw_texture_rect(tex, Rect2(zone.position + Vector2(0, 4), MINI_SIZE), false, color)
	var outline: Texture2D = BattleSkin.texture("diagram/mini_outline")
	if outline != null:
		draw_texture_rect(outline, Rect2(zone.position + Vector2(0, 4), MINI_SIZE), false)


func _draw_weapon(zone: Rect2) -> void:
	var font: Font = UiStyle.mono()
	var icon_box: Rect2 = Rect2(zone.position, Vector2(18, 18))
	draw_rect(icon_box, Color(0.1, 0.1, 0.1, 0.85))
	draw_rect(icon_box.grow(-0.5), Color(BattleSkin.INK, 0.8), false, 1.0)
	if weapon_icon != null:
		BattleSkin.draw_icon_at(self, weapon_icon, icon_box.get_center(), 16.0)
	else:
		BattleSkin.draw_icon_at(self, BattleSkin.order_icon(&"fist"), icon_box.get_center(), 16.0)
	var weapon: WeaponDef = combatant.current_weapon()
	var name_w: float = zone.size.x - 22.0
	draw_string(font, Vector2(zone.position.x + 22, zone.position.y + 8), weapon.display_name, HORIZONTAL_ALIGNMENT_LEFT,
		name_w, UiStyle.MONO_SMALL, BattleSkin.INK)
	var hands: String = "dos manos" if weapon.two_handed else "una mano"
	draw_string(font, Vector2(zone.position.x + 22, zone.position.y + 17), hands, HORIZONTAL_ALIGNMENT_LEFT, name_w,
		UiStyle.MONO_SMALL, BattleSkin.INK_SOFT)
	var icons: Array[Dictionary] = BattleFrame.status_icons(combatant)
	var y: float = zone.position.y + (zone.size.y - 8.0 if compact() else 30.0)
	if compact():
		y = zone.position.y + 8.0
	for i: int in mini(icons.size(), 6):
		var x: float = (zone.end.x - 7.0 - i * 13.0) if compact() else (zone.position.x + 7.0 + i * 13.0)
		BattleFrame.draw_icon(self, icons[i]["kind"], Vector2(x, y), icons[i]["letter"])


func _draw_stain(stain: Dictionary) -> void:
	var p: Vector2 = stain["p"]
	var r: float = stain["r"]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(stain["seed"])
	var color: Color = Color(BattleSkin.BLOOD_DARK, 0.75)
	draw_circle(p, r, color)
	for i: int in 5:
		var a: float = rng.randf() * TAU
		draw_circle(p + Vector2.from_angle(a) * r * rng.randf_range(1.1, 2.2), rng.randf_range(0.6, 1.4), color)
	if rng.randf() < 0.5:
		draw_rect(Rect2(p + Vector2(-0.5, r - 1), Vector2(1, rng.randf_range(3, 7))), color)


func _number() -> String:
	var digits: String = ""
	for c: String in combatant.display_name():
		if c.is_valid_int():
			digits += c
	return digits if digits != "" else "—"
