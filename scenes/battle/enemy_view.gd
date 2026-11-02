class_name EnemyView
extends Node2D
## Dibujo de un enemigo de combate. La posición del nodo son sus pies.
##
## Con hojas por capas (EnemySpriteDef, contrato con el arte) apila un Sprite2D por capa, oculta las
## partes amputadas y enseña su muñón (`stump_<parte>`), y reproduce las animaciones idle, windup,
## attack, hit, stagger y death. Sin hojas, dibuja un marcador provisional del enfermero
## (silueta por partes) con las mismas animaciones y mutilaciones.
## Se usa en el combate (escala 1) y en el mapa (escalado, iluminado por las luces 2D).

signal anim_finished(anim_name: StringName)

const META_PATH: String = "res://tools/art/sprite_meta.json"
## Duración de las animaciones del marcador provisional.
const PLACEHOLDER_ANIMS: Dictionary[StringName, float] = {
	&"idle": 2.6, &"windup": 0.45, &"attack": 0.32, &"hit": 0.3, &"stagger": 0.6, &"death": 1.1,
}
const BROKEN_TINT: Color = Color(0.78, 0.58, 0.56)
## Colores del marcador provisional.
const C_UNIFORM: Color = Color("aca694")
const C_UNIFORM_SHADE: Color = Color("6f6a5e")
const C_STAIN: Color = Color("5e2a22")
const C_SKIN: Color = Color("6a7682")
const C_SKIN_DARK: Color = Color("3f4853")
const C_VEIN: Color = Color("2a2f3a")
const C_MASK: Color = Color("d9d2c2")
const C_MASK_SHADE: Color = Color("b5ae9e")
const C_SURGICAL: Color = Color("8fa9a3")
const C_METAL: Color = Color("b9c0c4")
const C_METAL_DARK: Color = Color("5d666c")
const C_BLOOD: Color = Color("6e1410")
const C_BLOOD_LIGHT: Color = Color("a3241c")
const C_FLUID: Color = Color("1d1a22")
const C_OUTLINE: Color = Color("0d0c10")

## Escala del dibujo (1 en combate).
var draw_scale: float = 1.0
## Parte que se está apuntando (resalta el marcador provisional; en combate hay retícula aparte).
var highlight_part: StringName = &""

var _sprites: EnemySpriteDef
var _layers: Dictionary[StringName, Sprite2D] = {}
var _part_states: Dictionary[StringName, int] = {}
var _anim: StringName = &"idle"
var _anim_time: float = 0.0
var _anim_length: float = 1.0
var _anim_loop: bool = true
var _frame_start: int = 0
var _frame_count: int = 1
var _fps: float = 8.0
var _dead: bool = false
var _time: float = 0.0
var _flash_tween: Tween


## Prepara la vista para un enemigo. Busca sus hojas (horneadas o, en desarrollo, en el JSON).
func setup(def: CombatantDef) -> void:
	_sprites = def.sprites if def != null else null
	if _sprites == null and def != null and def.sprite_key != "":
		_sprites = EnemySpriteDef.from_meta_file(META_PATH, def.sprite_key)
	for child: Node in _layers.values():
		child.queue_free()
	_layers.clear()
	if _sprites != null:
		_build_layers()
	play(&"idle")


## Usa hojas concretas (pruebas, o arte que no está en el JSON).
func setup_sprites(sprites: EnemySpriteDef) -> void:
	_sprites = sprites
	_build_layers()
	play(&"idle")


func has_sprites() -> bool:
	return _sprites != null


## Estado de una parte (CombatTypes.PartState): oculta las amputadas y enseña su muñón.
func set_part_state(part_id: StringName, state: int) -> void:
	_part_states[part_id] = state
	if _sprites != null:
		var layer: StringName = EnemySpriteDef.PART_LAYERS.get(part_id, part_id)
		var amputated: bool = state == CombatTypes.PartState.AMPUTATED
		if _layers.has(layer):
			_layers[layer].visible = not amputated
			_layers[layer].self_modulate = BROKEN_TINT if state == CombatTypes.PartState.BROKEN else Color.WHITE
		var stump: StringName = StringName(EnemySpriteDef.STUMP_PREFIX + String(part_id))
		if _layers.has(stump):
			_layers[stump].visible = amputated
	queue_redraw()


func part_state(part_id: StringName) -> int:
	return _part_states.get(part_id, CombatTypes.PartState.HEALTHY)


## Copia el estado de las partes de un combatiente.
func sync_parts(combatant: Combatant) -> void:
	for id: StringName in combatant.part_order:
		if part_state(id) != combatant.parts[id].state:
			set_part_state(id, combatant.parts[id].state)


## Centro de una parte, en coordenadas locales del nodo (pies = 0,0), ya escalado.
func anchor(part_id: StringName) -> Vector2:
	if _sprites != null:
		return _sprites.anchor_from_feet(part_id) * draw_scale
	return _placeholder_anchor(part_id) * draw_scale


## Altura aproximada del dibujo (para colocar textos encima).
func height() -> float:
	if _sprites != null:
		return _sprites.origin.y * draw_scale
	return 236.0 * draw_scale


## Reproduce una animación; si no es en bucle, vuelve a idle al terminar (salvo death).
func play(anim_name: StringName) -> void:
	if _dead and anim_name != &"death":
		return
	_anim = anim_name
	_anim_time = 0.0
	if _sprites != null:
		var data: Array = _sprites.anims.get(anim_name, _sprites.anims.get(&"idle", [0, 1, 8.0, 1]))
		_frame_start = int(data[0])
		_frame_count = maxi(1, int(data[1]))
		_fps = maxf(1.0, float(data[2]))
		_anim_loop = int(data[3]) != 0 and anim_name != &"death"
		_anim_length = _frame_count / _fps
		_apply_frame(_frame_start)
	else:
		_anim_length = PLACEHOLDER_ANIMS.get(anim_name, 0.4)
		_anim_loop = anim_name == &"idle"
	if anim_name == &"death":
		_dead = true
	queue_redraw()


## Duración de una animación en segundos.
func anim_length(anim_name: StringName) -> float:
	if _sprites != null and _sprites.anims.has(anim_name):
		var data: Array = _sprites.anims[anim_name]
		return maxi(1, int(data[1])) / maxf(1.0, float(data[2]))
	return PLACEHOLDER_ANIMS.get(anim_name, 0.4)


## Se queda tendido en el último fotograma de la muerte (cuerpo en el mapa).
func show_dead() -> void:
	play(&"death")
	_anim_time = _anim_length
	if _sprites != null:
		_apply_frame(_frame_start + _frame_count - 1)
	queue_redraw()


func is_dead() -> bool:
	return _dead


## Destello de golpe (blanco o del color que se pida).
func flash(color: Color = Color(2.4, 2.2, 2.0), seconds: float = 0.18) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, seconds)


func _process(delta: float) -> void:
	_time += delta
	_anim_time += delta
	if _anim_time >= _anim_length:
		if _anim_loop:
			_anim_time = fmod(_anim_time, _anim_length)
		elif _anim != &"idle" and not _dead:
			var finished_anim: StringName = _anim
			play(&"idle")
			anim_finished.emit(finished_anim)
			return
		elif _dead:
			_anim_time = _anim_length
	if _sprites != null:
		var index: int = mini(_frame_count - 1, int(_anim_time * _fps))
		_apply_frame(_frame_start + index)
	else:
		queue_redraw()


# --- hojas por capas --------------------------------------------------------------------------

func _build_layers() -> void:
	var order: Array[StringName] = _sprites.order.duplicate()
	for key: StringName in _sprites.layers:
		if not order.has(key):
			order.append(key)
	var columns: int = _sprites.columns()
	var rows: int = _sprites.rows()
	for key: StringName in order:
		if not _sprites.layers.has(key):
			continue
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "Layer_" + String(key)
		var texture: Texture2D = _sprites.layers[key]
		if _sprites.normals.has(key):
			var canvas: CanvasTexture = CanvasTexture.new()
			canvas.diffuse_texture = texture
			canvas.normal_texture = _sprites.normals[key]
			texture = canvas
		sprite.texture = texture
		sprite.hframes = columns
		sprite.vframes = rows
		sprite.centered = false
		sprite.offset = -Vector2(_sprites.origin)
		sprite.scale = Vector2(draw_scale, draw_scale)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.light_mask = light_mask
		sprite.visible = not String(key).begins_with(EnemySpriteDef.STUMP_PREFIX)
		add_child(sprite)
		_layers[key] = sprite
	for id: StringName in _part_states:
		set_part_state(id, _part_states[id])


func _apply_frame(index: int) -> void:
	for sprite: Sprite2D in _layers.values():
		sprite.frame = clampi(index, 0, sprite.hframes * sprite.vframes - 1)


# --- marcador provisional -----------------------------------------------------------------------

## Pose del marcador: [brazo der. levantado 0–1, inclinación −1–1, caída 0–1].
func _pose() -> Vector3:
	var t: float = clampf(_anim_time / maxf(0.01, _anim_length), 0.0, 1.0)
	match _anim:
		&"windup":
			return Vector3(ease(t, 0.5), -0.25 * t, 0.0)
		&"attack":
			return Vector3(1.0 - ease(t, 2.0), 0.6 * sin(t * PI), 0.0)
		&"hit":
			return Vector3(0.0, -0.7 * sin(t * PI), 0.0)
		&"stagger":
			return Vector3(0.0, -0.9 * sin(t * PI) + 0.2 * sin(t * TAU * 3.0), 0.15 * sin(t * PI))
		&"death":
			return Vector3(0.0, -0.3, ease(t, 1.6))
	return Vector3.ZERO


func _placeholder_anchor(part_id: StringName) -> Vector2:
	var crawl: float = 26.0 if _crawling() else 0.0
	match part_id:
		&"head":
			return Vector2(4, -212 + crawl * 2.4)
		&"torso":
			return Vector2(0, -150 + crawl * 1.8)
		&"arm_r":
			return Vector2(-44, -128 + crawl * 1.6)
		&"arm_l":
			return Vector2(42, -132 + crawl * 1.6)
		&"leg_r":
			return Vector2(-14, -50)
		&"leg_l":
			return Vector2(14, -50)
	return Vector2(0, -120)


func _crawling() -> bool:
	return part_state(&"leg_l") >= CombatTypes.PartState.BROKEN and part_state(&"leg_r") >= CombatTypes.PartState.BROKEN


func _draw() -> void:
	if _sprites != null:
		return
	var pose: Vector3 = _pose()
	var breathe: float = sin(_time * 2.4) * 1.5
	var fall: float = pose.z
	# Sombra en el suelo.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(draw_scale, draw_scale))
	draw_circle(Vector2.ZERO, 1.0, Color(0, 0, 0, 0))
	_draw_ellipse(Vector2(0, 2), Vector2(46, 7), Color(0, 0, 0, 0.45))
	# Al morir se desploma hacia un lado; arrastrándose, el cuerpo baja.
	var crawl: float = 26.0 if _crawling() else 0.0
	var rotation_angle: float = -fall * 1.35
	var drop: Vector2 = Vector2(fall * 30.0, fall * 6.0)
	draw_set_transform(drop * draw_scale, rotation_angle, Vector2(draw_scale, draw_scale))
	var lean: float = pose.y * 10.0
	var hip: Vector2 = Vector2(0, -108 + crawl * 3.2)
	var neck: Vector2 = Vector2(4 + lean, -196 + breathe + crawl * 2.4)
	_draw_legs(hip, crawl)
	_draw_arm_back(neck, pose, crawl)
	_draw_torso(hip, neck)
	_draw_head(neck, breathe)
	_draw_arm_front(neck, pose, crawl)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _part_color(part_id: StringName, base: Color) -> Color:
	var color: Color = base
	if part_state(part_id) == CombatTypes.PartState.BROKEN:
		color = base * BROKEN_TINT
	elif part_state(part_id) == CombatTypes.PartState.WOUNDED:
		color = base.lerp(C_STAIN, 0.18)
	if highlight_part == part_id:
		color = color.lightened(0.18)
	return color


func _gone(part_id: StringName) -> bool:
	return part_state(part_id) == CombatTypes.PartState.AMPUTATED


func _draw_legs(hip: Vector2, crawl: float) -> void:
	for side: int in [-1, 1]:
		var id: StringName = &"leg_r" if side < 0 else &"leg_l"
		var top: Vector2 = hip + Vector2(side * 11, 0)
		if _gone(id):
			_draw_stump(top + Vector2(0, 6), Vector2(9, 6))
			continue
		var broken: bool = part_state(id) == CombatTypes.PartState.BROKEN
		var knee: Vector2 = top + Vector2(side * 3, 56 - crawl * 1.4)
		var foot: Vector2 = Vector2(side * 16, 0)
		if broken:
			knee += Vector2(side * 9, 4)
		if crawl > 0.0:
			foot = knee + Vector2(side * 30, 6)
		var color: Color = _part_color(id, C_UNIFORM_SHADE)
		_limb(top, knee, 15.0, 12.0, color, side > 0)
		_limb(knee, foot, 12.0, 9.0, color, side > 0)
		_draw_ellipse(foot + Vector2(side * 3, -2), Vector2(9, 4), C_OUTLINE)
		# Manchas en el pantalón.
		draw_circle(knee.lerp(foot, 0.35) + Vector2(side * 2, 0), 3.0, C_STAIN)


func _draw_torso(hip: Vector2, neck: Vector2) -> void:
	var color: Color = _part_color(&"torso", C_UNIFORM)
	var shade: Color = _part_color(&"torso", C_UNIFORM_SHADE)
	# Hombros altos y encogidos, cintura estrecha y la casaca del uniforme hasta medio muslo.
	var points: PackedVector2Array = [
		neck + Vector2(-8, -2), neck + Vector2(-34, 4), neck + Vector2(-31, 24), hip + Vector2(-19, -16),
		hip + Vector2(-24, 14), hip + Vector2(24, 14), hip + Vector2(19, -16), neck + Vector2(33, 22),
		neck + Vector2(35, 2), neck + Vector2(10, -3),
	]
	draw_colored_polygon(points, color)
	# Lado en sombra (la luz viene de arriba a la izquierda).
	draw_colored_polygon(PackedVector2Array([neck + Vector2(14, 2), neck + Vector2(35, 2), neck + Vector2(33, 22),
		hip + Vector2(19, -16), hip + Vector2(24, 14), hip + Vector2(6, 14), hip + Vector2(4, -20)]), shade)
	draw_polyline(points + PackedVector2Array([points[0]]), C_OUTLINE, 2.0)
	# Escote en pico y costura central rota.
	draw_colored_polygon(PackedVector2Array([neck + Vector2(-9, -1), neck + Vector2(10, -2), neck + Vector2(1, 22)]),
		C_SKIN_DARK)
	draw_line(neck + Vector2(1, 22), hip + Vector2(1, 12), shade.darkened(0.3), 1.0)
	draw_line(hip + Vector2(-24, 13), hip + Vector2(24, 13), C_OUTLINE, 1.0)
	# Manchas de sangre vieja y roturas.
	draw_circle(neck.lerp(hip, 0.55) + Vector2(-10, 0), 7.0, C_STAIN)
	draw_circle(neck.lerp(hip, 0.62) + Vector2(-4, 6), 4.0, C_STAIN)
	draw_circle(neck.lerp(hip, 0.85) + Vector2(12, 0), 5.0, C_STAIN.darkened(0.2))
	# Vías y tubos que le entran en el pecho, con líquido oscuro.
	var chest: Vector2 = neck.lerp(hip, 0.3)
	for i: int in 3:
		var start: Vector2 = chest + Vector2(-8 + i * 7, 2 + i * 3)
		var bend: Vector2 = start + Vector2(16 + i * 6, 30 + i * 8)
		var end: Vector2 = bend + Vector2(10 - i * 12, 46)
		draw_polyline(_curve(start, bend, end), C_FLUID, 3.0)
		draw_polyline(_curve(start, bend, end), C_METAL_DARK, 1.0)
		draw_circle(start, 2.5, C_METAL)
	if part_state(&"torso") >= CombatTypes.PartState.BROKEN:
		_drip(chest + Vector2(6, 10), 3)


func _draw_head(neck: Vector2, breathe: float) -> void:
	if _gone(&"head"):
		_draw_stump(neck + Vector2(0, -2), Vector2(10, 6))
		return
	# La cabeza se hunde entre los hombros (columna arqueada, demasiado larga).
	var center: Vector2 = neck + Vector2(3, -17 + breathe * 0.4)
	var skin: Color = _part_color(&"head", C_SKIN)
	draw_rect(Rect2(neck + Vector2(-6, -8), Vector2(12, 12)), skin)
	_draw_ellipse(center + Vector2(1, 1), Vector2(18, 23), C_OUTLINE)
	_draw_ellipse(center, Vector2(17, 22), skin)
	# Mascarilla quirúrgica cosida a la cara: de la nariz a la barbilla, con puntadas en el borde.
	var surgical: PackedVector2Array = [center + Vector2(-16, 1), center + Vector2(16, 1), center + Vector2(12, 17),
		center + Vector2(0, 21), center + Vector2(-12, 17)]
	draw_colored_polygon(surgical, _part_color(&"head", C_SURGICAL))
	draw_line(center + Vector2(-14, 9), center + Vector2(14, 9), _part_color(&"head", C_SURGICAL).darkened(0.25), 1.0)
	for i: int in 7:
		var x: float = -15.0 + i * 5.0
		draw_line(center + Vector2(x, -1), center + Vector2(x + 2, 3), C_OUTLINE, 1.0)
	# Máscara de porcelana agrietada sobre los ojos: lisa, sin rasgos, con dos ranuras.
	var mask: Color = _part_color(&"head", C_MASK)
	var shell: PackedVector2Array = [center + Vector2(-16, -2), center + Vector2(-15, -14), center + Vector2(-7, -21),
		center + Vector2(7, -21), center + Vector2(15, -14), center + Vector2(16, -2), center + Vector2(6, 2),
		center + Vector2(0, 0), center + Vector2(-6, 2)]
	draw_colored_polygon(shell, mask)
	draw_colored_polygon(PackedVector2Array([center + Vector2(5, -20), center + Vector2(15, -14), center + Vector2(16, -2),
		center + Vector2(7, 1)]), _part_color(&"head", C_MASK_SHADE))
	draw_polyline(shell + PackedVector2Array([shell[0]]), C_OUTLINE, 1.0)
	draw_line(center + Vector2(-10, -9), center + Vector2(-4, -8), C_OUTLINE, 2.0)
	draw_line(center + Vector2(4, -8), center + Vector2(10, -9), C_OUTLINE, 2.0)
	var crack: PackedVector2Array = [center + Vector2(-3, -21), center + Vector2(-1, -15), center + Vector2(-4, -11),
		center + Vector2(-2, -5)]
	if part_state(&"head") >= CombatTypes.PartState.WOUNDED:
		crack.append(center + Vector2(1, 1))
	draw_polyline(crack, C_OUTLINE, 1.0)
	if part_state(&"head") == CombatTypes.PartState.BROKEN:
		draw_polyline(PackedVector2Array([center + Vector2(1, -11), center + Vector2(9, -14)]), C_OUTLINE, 1.0)
		_drip(center + Vector2(0, 0), 2)


## Brazo de la jeringa (izquierdo del enfermero, a la derecha de la pantalla).
func _draw_arm_back(neck: Vector2, _pose_data: Vector3, crawl: float) -> void:
	var shoulder: Vector2 = neck + Vector2(30, 8)
	if _gone(&"arm_l"):
		_draw_stump(shoulder + Vector2(4, 4), Vector2(7, 8))
		return
	var broken: bool = part_state(&"arm_l") == CombatTypes.PartState.BROKEN
	var elbow: Vector2 = shoulder + Vector2(9, 50 - crawl * 0.6)
	var hand: Vector2 = elbow + (Vector2(14, 44) if broken else Vector2(3, 46))
	if crawl > 0.0:
		hand = elbow + Vector2(24, 26)
	var skin: Color = _part_color(&"arm_l", C_SKIN)
	_limb(shoulder, elbow, 13.0, 10.0, _part_color(&"arm_l", C_UNIFORM_SHADE), true)
	_limb(elbow, hand, 9.0, 7.0, skin, true)
	draw_line(elbow + Vector2(1, 4), hand + Vector2(0, -6), C_VEIN, 1.0)
	draw_circle(hand, 5.0, skin)
	# Jeringa grande.
	var tilt: Vector2 = Vector2(0.35, 1.0).normalized()
	var barrel_a: Vector2 = hand + Vector2(-4, -2)
	var barrel_b: Vector2 = barrel_a + tilt * 34.0
	if broken:
		barrel_b = barrel_a + Vector2(-6, 30)
	draw_line(barrel_a, barrel_b, C_METAL_DARK, 9.0)
	draw_line(barrel_a, barrel_b, Color(0.75, 0.78, 0.8, 0.85), 7.0)
	draw_line(barrel_a.lerp(barrel_b, 0.35), barrel_b, C_FLUID, 5.0)
	draw_line(barrel_b, barrel_b + (barrel_b - barrel_a).normalized() * 16.0, C_METAL, 1.0)
	draw_line(barrel_a - tilt * 8.0, barrel_a, C_METAL_DARK, 2.0)


## Brazo de instrumental (derecho del enfermero, a la izquierda de la pantalla).
func _draw_arm_front(neck: Vector2, pose_data: Vector3, crawl: float) -> void:
	var shoulder: Vector2 = neck + Vector2(-30, 9)
	if _gone(&"arm_r"):
		_draw_stump(shoulder + Vector2(-4, 4), Vector2(8, 9))
		_drip(shoulder + Vector2(-4, 10), 3)
		return
	var broken: bool = part_state(&"arm_r") == CombatTypes.PartState.BROKEN
	var raise: float = 0.0 if broken else pose_data.x
	var elbow: Vector2 = shoulder + Vector2(-11, 50).lerp(Vector2(-22, -28), raise)
	var wrist: Vector2 = elbow + Vector2(-5, 42).lerp(Vector2(-6, -38), raise)
	if broken:
		elbow = shoulder + Vector2(-8, 46)
		wrist = elbow + Vector2(12, 34)
	if crawl > 0.0 and not broken:
		elbow = shoulder + Vector2(-26, 22)
		wrist = elbow + Vector2(-30, 18)
	_limb(shoulder, elbow, 13.0, 11.0, _part_color(&"arm_r", C_UNIFORM))
	_limb(elbow, wrist, 11.0, 10.0, _part_color(&"arm_r", C_SKIN))
	draw_line(elbow + Vector2(-2, 3), wrist, C_VEIN, 1.0)
	# Donde la carne se funde con el metal: costura de grapas.
	draw_circle(wrist, 7.0, _part_color(&"arm_r", C_SKIN_DARK))
	for i: int in 4:
		var a: float = TAU * i / 4.0
		draw_rect(Rect2(wrist + Vector2(cos(a), sin(a)) * 6.0 - Vector2(1, 1), Vector2(2, 2)), C_METAL)
	var direction: Vector2 = (wrist - elbow).normalized()
	var side: Vector2 = Vector2(-direction.y, direction.x)
	# Bisturíes que le salen de la carne y una sierra de hueso.
	for i: int in 3:
		var root: Vector2 = wrist + side * (-5.0 + i * 5.0)
		var tip: Vector2 = root + direction * (30.0 + i * 6.0) + side * (-4.0 + i * 4.0)
		draw_colored_polygon(PackedVector2Array([root - side * 1.5, root + side * 1.5, tip]), _part_color(&"arm_r", C_METAL))
		draw_line(root, tip, C_METAL_DARK, 1.0)
	var saw_a: Vector2 = wrist + side * 8.0
	var saw_b: Vector2 = saw_a + direction * 44.0
	draw_line(saw_a, saw_b, _part_color(&"arm_r", C_METAL), 4.0)
	for i: int in 8:
		var p: Vector2 = saw_a.lerp(saw_b, (i + 0.5) / 8.0) + side * 2.0
		draw_colored_polygon(PackedVector2Array([p, p + direction * 4.0, p + side * 4.0 + direction * 2.0]), C_METAL_DARK)
	if part_state(&"arm_r") >= CombatTypes.PartState.WOUNDED:
		_drip(wrist, 2)


func _draw_stump(center: Vector2, radii: Vector2) -> void:
	_draw_ellipse(center, radii, C_BLOOD)
	_draw_ellipse(center + Vector2(0, -1), radii * 0.6, C_BLOOD_LIGHT)
	draw_circle(center + Vector2(radii.x * 0.2, 0), radii.x * 0.25, C_MASK_SHADE)
	_drip(center + Vector2(0, radii.y), 3)


## Gotas que caen y se repiten.
func _drip(from: Vector2, count: int) -> void:
	for i: int in count:
		var phase: float = fmod(_time * 0.9 + i * 0.37, 1.0)
		var p: Vector2 = from + Vector2((i - count / 2.0) * 3.0, phase * 26.0)
		draw_rect(Rect2(p, Vector2(2, 3)), C_BLOOD_LIGHT if i % 2 == 0 else C_BLOOD)


## Un segmento de miembro con sombra en un lado (`shaded`: el lado lejos de la luz).
func _limb(a: Vector2, b: Vector2, width_a: float, width_b: float, color: Color, shaded: bool = false) -> void:
	var d: Vector2 = (b - a).normalized()
	var n: Vector2 = Vector2(-d.y, d.x)
	if n.x < 0.0:
		n = -n
	var points: PackedVector2Array = [a + n * width_a * 0.5, b + n * width_b * 0.5, b - n * width_b * 0.5,
		a - n * width_a * 0.5]
	draw_colored_polygon(points, color)
	draw_colored_polygon(PackedVector2Array([a + n * width_a * 0.5, b + n * width_b * 0.5, b + n * width_b * 0.1,
		a + n * width_a * 0.1]), color.darkened(0.45 if shaded else 0.3))
	draw_polyline(points + PackedVector2Array([points[0]]), C_OUTLINE, 1.5)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = []
	for i: int in 20:
		var a: float = TAU * i / 20.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)


func _curve(a: Vector2, b: Vector2, c: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for i: int in 9:
		var t: float = i / 8.0
		points.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	return points
