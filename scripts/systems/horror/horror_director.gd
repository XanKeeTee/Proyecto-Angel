class_name HorrorDirector
extends Node
## Terror ambiental aleatorio de un mapa: sustos pequeños (`ScareDef`, elegidos por
## `ScarePlanner`) y la entidad que sigue al jugador por la espalda (`Stalker`).
## Se crea con una línea desde el `_ready` del mapa:
##     HorrorDirector.attach(self, preload("res://data/horror/prologo.tres"))
## Nunca actúa con el control bloqueado (textos, eventos, menús, puertas), en pausa ni en salas
## iluminadas (la entidad). Los eventos guionizados (`EventDirector`) imponen un silencio.
## Lo único que se guarda: usos de los sustos limitados y objetos del decorado ya movidos.
## Diseño: docs/design/sistemas/terror-ambiental.md.

## La entidad se ha ido (&"light", &"reached", &"timeout", &"lost").
signal stalker_vanished(reason: StringName)
## Ha saltado un susto pequeño.
signal scare_played(scare: ScareDef)

const SAVE_KEY: StringName = &"horror"
const TILE_SIZE: int = 32
## Inquietud: 0 con la Mente en 45 o más, 1 con la Mente en 5 o menos (igual que WorldController).
const UNEASE_MIND: float = 45.0
const UNEASE_RANGE: float = 40.0
## Cada cuánto se apunta un punto del camino del jugador (píxeles).
const TRAIL_STEP: float = 8.0
const TRAIL_MAX: int = 64
## Un salto mayor que esto en un fotograma es un cambio de sala (puerta o escalera).
const WARP_DISTANCE: float = 48.0
const WALK_SPEED: float = 20.0
## Una luz del edificio ilumina la sala si el jugador está dentro de esta fracción de su radio.
const LIT_RADIUS: float = 0.42
## Distancia a la que se oye respirar a la entidad.
const BREATH_DISTANCE: float = 64.0
const FACE_TEXTURE: Texture2D = preload("res://assets/sprites/horror/face_flash.png")
## Sonidos provisionales mientras no estén los definitivos (ver docs/tech/sonidos.md).
const FALLBACK_SOUNDS: Dictionary[String, String] = {
	"entity_breath": "whisper", "entity_whisper": "whisper", "entity_dissolve": "phone_static",
	"scare_door_slam": "door_close", "scare_fall": "metal_bang", "scare_wall_knock": "knock",
	"scare_steps_above": "steps_far", "scare_roll": "heavy_drag", "scare_wheelchair": "heavy_drag",
	"scare_door_creak": "door_open", "scare_breath": "whisper", "scare_static_burst": "pa_static",
	"scare_glass": "glass", "scare_drip": "drip",
}

var world: WorldController
var profile: HorrorProfile
var planner: ScarePlanner
var stalker: Stalker
## Reloj propio: solo avanza mientras el jugador tiene el control (así los enfriamientos
## no se gastan en menús ni textos).
var clock: float = 0.0

var _player: Player
var _map: TileMapLayer
var _layer: Node2D
var _trail: Array[Vector2] = []
var _last_pos: Vector2 = Vector2.ZERO
var _walk_time: float = 0.0
var _stalker_ready_at: float = 0.0
var _breathed: bool = false
var _moved_props: PackedStringArray = []
var _face_layer: CanvasLayer
var _face: TextureRect
var _debug_stalker: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Crea el director como hijo del mapa y lo devuelve.
static func attach(world_controller: WorldController, horror_profile: HorrorProfile) -> HorrorDirector:
	var director: HorrorDirector = HorrorDirector.new()
	director.name = "HorrorDirector"
	director.world = world_controller
	director.profile = horror_profile
	world_controller.add_child(director)
	return director


func _ready() -> void:
	_rng.randomize()
	_player = world.player
	_map = world.get_node(^"%Map") as TileMapLayer
	_layer = world.get_node(^"%World") as Node2D
	planner = ScarePlanner.new(profile)
	_load_state()
	planner.schedule(clock, _unease())
	_stalker_ready_at = profile.stalker_first_delay
	stalker = Stalker.new()
	stalker.name = "Stalker"
	stalker.speed_factor = profile.stalker_speed
	stalker.reach = profile.stalker_reach
	_layer.add_child(stalker)
	stalker.vanished.connect(_on_stalker_vanished)
	EventBus.flag_set.connect(_on_flag_set)
	_last_pos = _player.position
	_debug_stalker = world.debug.has("stalker")
	if world.debug.has("scare"):
		_debug_scare.call_deferred(StringName(world.debug["scare"]))


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var pos: Vector2 = _player.position
	var warped: bool = pos.distance_to(_last_pos) > WARP_DISTANCE
	_last_pos = pos
	if warped:
		_trail.clear()
		stalker.hide_now(&"lost")
	if _debug_stalker:
		_update_debug_stalker(delta)
		return
	if not can_act():
		_walk_time = 0.0
		if stalker.is_active():
			stalker.vanish(&"lost")
		planner.hold(clock, 3.0)
		return
	clock += delta
	_record_trail(pos)
	var walking: bool = _player.velocity.length() > WALK_SPEED
	_walk_time = _walk_time + delta if walking else 0.0
	if stalker.is_active():
		_update_stalker(delta, walking)
	else:
		_maybe_spawn_stalker(delta)
		var scare: ScareDef = planner.next(_context())
		if scare != null:
			play_scare(scare)


# --- consultas ------------------------------------------------------------------------------

## Si el jugador está libre (sin textos, menús, eventos ni puertas) para que pase algo.
func can_act() -> bool:
	if not _player.input_enabled or not _player.visible:
		return false
	if world.message != null and world.message.is_open():
		return false
	if world.custody_screen != null and world.custody_screen.is_open():
		return false
	return true


## Si hay una luz del edificio encendida cerca de `pos` (sala iluminada).
func is_lit(pos: Vector2) -> bool:
	for node: Node in get_tree().get_nodes_in_group(PoweredLight.GROUP):
		var light: PoweredLight = node as PoweredLight
		if not light.enabled or light.texture == null:
			continue
		var radius: float = light.texture.get_width() * 0.5 * light.texture_scale * LIT_RADIUS
		if light.global_position.distance_to(pos) < radius:
			return true
	return false


## Si el haz de la linterna del jugador llega a `target` (ángulo, alcance y sin pared en medio).
func flashlight_hits(target: Vector2) -> bool:
	if not _player.has_flashlight_on():
		return false
	if not beam_touches(_player.position, _player.facing_angle, target, profile.beam_half_angle, profile.beam_range):
		return false
	return clear_line(_player.position, target)


## Geometría del cono de luz (pura, para pruebas).
static func beam_touches(origin: Vector2, angle: float, target: Vector2, half_angle_deg: float, beam_range: float) -> bool:
	var to: Vector2 = target - origin
	if to.length() > beam_range:
		return false
	if to.length() < 12.0:
		return true
	return absf(angle_difference(angle, to.angle())) <= deg_to_rad(half_angle_deg)


## Si no hay pared entre dos puntos (comprobado por casillas del mapa).
func clear_line(a: Vector2, b: Vector2) -> bool:
	var steps: int = maxi(1, ceili(a.distance_to(b) / 8.0))
	for i: int in range(1, steps):
		if is_wall(_cell_of(a.lerp(b, float(i) / steps))):
			return false
	return true


## Si una casilla no es suelo (pared, vacío o puerta cerrada con colisión).
func is_wall(cell: Vector2i) -> bool:
	var data: TileData = _map.get_cell_tile_data(cell)
	if data == null:
		return true
	return data.get_collision_polygons_count(0) > 0


# --- sustos pequeños ------------------------------------------------------------------------

## Ejecuta un susto ya elegido.
func play_scare(scare: ScareDef) -> void:
	scare_played.emit(scare)
	var sound: String = scare.sounds[_rng.randi() % scare.sounds.size()] if not scare.sounds.is_empty() else ""
	match scare.kind:
		ScareDef.Kind.SOUND:
			_sound_at_place(sound, scare.place, scare.volume_db)
		ScareDef.Kind.FLICKER:
			var cell: Vector2i = _player.cell
			world.flicker_lights(Rect2i(cell - Vector2i(9, 6), Vector2i(18, 12)), scare.duration)
			_sound_at_place(sound, scare.place, scare.volume_db)
		ScareDef.Kind.PASSING_SHADOW:
			if not _passing_shadow(scare.duration):
				return
			_sound_at_place(sound, scare.place, scare.volume_db)
		ScareDef.Kind.FACE_FLASH:
			_face_flash(scare.duration)
			_sound_at_place(sound, ScareDef.Place.ABOVE, scare.volume_db)
		ScareDef.Kind.MOVE_PROP:
			_move_prop(scare, sound)
	if scare.glitch_strength > 0.0:
		world.glitch(maxf(scare.duration, 0.25), scare.glitch_strength)
	if scare.mind_loss > 0:
		world.character.vitals.change_mind(-scare.mind_loss)
	_save_state()


func _sound_at_place(sound: String, place: ScareDef.Place, volume_db: float) -> void:
	if sound == "":
		return
	var stream: AudioStream = _stream(sound)
	if stream == null:
		return
	var forward: Vector2 = Vector2.from_angle(_player.facing_angle)
	match place:
		ScareDef.Place.BEHIND:
			Sfx.at(world, stream, _player.position - forward * 26.0, volume_db)
		ScareDef.Place.NEARBY:
			var dir: Vector2 = Vector2.from_angle(_rng.randf() * TAU)
			Sfx.at(world, stream, _player.position + dir * _rng.randf_range(130.0, 240.0), volume_db)
		ScareDef.Place.FAR:
			var dir_far: Vector2 = Vector2.from_angle(_rng.randf() * TAU)
			Sfx.at(world, stream, _player.position + dir_far * _rng.randf_range(320.0, 520.0), volume_db, 0.06, 1100.0)
		_:
			Sfx.ui(world, stream, volume_db)


## Una sombra cruza a lo lejos, delante, perpendicular a la mirada. False si no hay sitio.
func _passing_shadow(seconds: float) -> bool:
	var forward: Vector2 = Vector2.from_angle(_player.facing_angle)
	var side: Vector2 = forward.orthogonal()
	for attempt: int in 6:
		var center: Vector2 = _player.position + forward * _rng.randf_range(150.0, 230.0)
		var half: float = _rng.randf_range(40.0, 70.0)
		var from: Vector2 = center - side * half
		var to: Vector2 = center + side * half
		if _rng.randf() < 0.5:
			var swap: Vector2 = from
			from = to
			to = swap
		if is_wall(_cell_of(center)) or is_wall(_cell_of(from)) or is_wall(_cell_of(to)):
			continue
		if not clear_line(from, to) or not clear_line(_player.position, center):
			continue
		PassingShadow.cross(_layer, from, to, seconds)
		return true
	return false


func _face_flash(seconds: float) -> void:
	if _face_layer == null:
		_face_layer = CanvasLayer.new()
		_face_layer.layer = 49  # justo debajo del filtro VHS: le afecta el grano y la aberración
		add_child(_face_layer)
		_face = TextureRect.new()
		_face.texture = FACE_TEXTURE
		_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_face.set_anchors_preset(Control.PRESET_FULL_RECT)
		_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_face.visible = false
		_face_layer.add_child(_face)
	world.glitch(maxf(seconds, 0.4), 0.9)
	# Dos destellos de un par de fotogramas, desplazados como una imagen mal sintonizada.
	for i: int in 2:
		_face.position.x = _rng.randf_range(-40.0, 40.0)
		_face.modulate = Color(1, 1, 1, 0.75 - i * 0.3)
		_face.visible = true
		await get_tree().create_timer(0.06).timeout
		_face.visible = false
		await get_tree().create_timer(0.11).timeout


## Mueve un objeto del decorado que no esté a la vista (y lo recuerda en el guardado).
func _move_prop(scare: ScareDef, sound: String) -> void:
	for prop_name: String in scare.props:
		if _moved_props.has(prop_name):
			continue
		var node: Node2D = _layer.find_child(prop_name, true, false) as Node2D
		if node == null:
			continue
		var dist: float = node.position.distance_to(_player.position)
		if dist < 90.0 or dist > 460.0 or flashlight_hits(node.position):
			continue
		_moved_props.append(prop_name)
		var start: Vector2 = node.position
		var stream: AudioStream = _stream(sound)
		if stream != null:
			Sfx.at(world, stream, start, scare.volume_db)
		var tween: Tween = create_tween()
		tween.tween_property(node, "position", start + scare.prop_offset, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween.finished
		if is_instance_valid(node):
			node.position = start
			world.move_scenery(prop_name, scare.prop_offset)
		_save_state()
		return


# --- la entidad -----------------------------------------------------------------------------

func _maybe_spawn_stalker(delta: float) -> void:
	if not profile.stalker_enabled or clock < _stalker_ready_at or _walk_time < profile.stalker_walk_time:
		return
	if is_lit(_player.position):
		return
	var chance: float = lerpf(profile.stalker_chance.x, profile.stalker_chance.y, _unease())
	if _rng.randf() >= chance * delta:
		return
	try_spawn_stalker()


## Intenta que aparezca la entidad detrás del jugador, en el camino que acaba de recorrer.
## Devuelve false si no hay sitio (sin camino, en la luz o a la vista del haz).
func try_spawn_stalker() -> bool:
	if stalker.is_active() or _trail.size() < 4:
		return false
	var want: float = _rng.randf_range(profile.stalker_spawn_distance.x, profile.stalker_spawn_distance.y)
	var walked: float = _player.position.distance_to(_trail[-1])
	var index: int = _trail.size() - 1
	while index > 0 and walked < want:
		walked += _trail[index].distance_to(_trail[index - 1])
		index -= 1
	if walked < profile.stalker_spawn_distance.x * 0.8:
		return false
	var at: Vector2 = _trail[index]
	if is_lit(at) or flashlight_hits(at) or flashlight_hits(at + Vector2(0, -38)):
		return false
	# Tiene que quedar a la espalda: fuera del cono de visión con margen.
	var behind: float = absf(angle_difference(_player.facing_angle, (at - _player.position).angle()))
	if behind < deg_to_rad(profile.beam_half_angle + 40.0):
		return false
	var path: Array[Vector2] = _trail.slice(index + 1)
	stalker.appear(at, path, _rng.randf_range(profile.stalker_lifetime.x, profile.stalker_lifetime.y))
	_breathed = false
	return true


func _update_stalker(delta: float, walking: bool) -> void:
	if not stalker.is_solid():
		return
	if flashlight_hits(stalker.aim_point()) or flashlight_hits(stalker.position):
		_dissolve_stalker()
		return
	if is_lit(stalker.position):
		stalker.vanish(&"timeout")
		return
	if not _breathed and stalker.position.distance_to(_player.position) < BREATH_DISTANCE:
		_breathed = true
		_play("entity_breath", stalker.position, -10.0)
	if stalker.follow(delta, _player.position, walking):
		_stalker_reached()


func _dissolve_stalker() -> void:
	stalker.dissolve()
	_play("entity_dissolve", stalker.position, -6.0)
	world.glitch(0.3, 0.4)
	if profile.stalker_seen_mind_loss > 0:
		world.character.vitals.change_mind(-profile.stalker_seen_mind_loss)


func _stalker_reached() -> void:
	_play("entity_whisper", _player.position, -4.0)
	world.glitch(0.6, 0.55)
	world.character.vitals.change_mind(-profile.stalker_mind_loss)
	stalker.vanish(&"reached")


func _on_stalker_vanished(reason: StringName) -> void:
	_stalker_ready_at = clock + _rng.randf_range(profile.stalker_cooldown.x, profile.stalker_cooldown.y)
	planner.hold(clock, profile.quiet_after_event * 0.5)
	stalker_vanished.emit(reason)


func _update_debug_stalker(delta: float) -> void:
	# --stalker: la entidad aparece enseguida detrás del jugador y lo sigue aunque esté quieto
	# (para capturas). Con el haz encima se deshace como en el juego.
	if not stalker.is_active():
		var back: Vector2 = -Vector2.from_angle(_player.facing_angle)
		var at: Vector2 = _player.position + back * 96.0
		var path: Array[Vector2] = [_player.position + back * 60.0]
		stalker.appear(at, path, 999.0)
		stalker.set_process(true)
		return
	if stalker.is_solid() and flashlight_hits(stalker.aim_point()):
		_dissolve_stalker()
	elif stalker.is_solid() and stalker.position.distance_to(_player.position) > 60.0:
		stalker.follow(delta, _player.position, true)


func _debug_scare(id: StringName) -> void:
	await get_tree().create_timer(1.2).timeout
	for scare: ScareDef in profile.scares:
		if scare.id == id:
			play_scare(scare)


# --- utilidades -----------------------------------------------------------------------------

func _context() -> ScareContext:
	var context: ScareContext = ScareContext.new()
	context.now = clock
	context.cell = _player.cell
	context.flashlight_on = _player.has_flashlight_on()
	context.unease = _unease()
	context.flags = GameState.flags
	return context


func _unease() -> float:
	return clampf((UNEASE_MIND - world.character.vitals.mind) / UNEASE_RANGE, 0.0, 1.0)


func _record_trail(pos: Vector2) -> void:
	if _trail.is_empty() or _trail[-1].distance_to(pos) >= TRAIL_STEP:
		_trail.append(pos)
		if _trail.size() > TRAIL_MAX:
			_trail.pop_front()


func _cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE_SIZE), floori(pos.y / TILE_SIZE))


func _on_flag_set(flag: StringName) -> void:
	# Un evento guionizado acaba de saltar: silencio un rato y fuera la entidad.
	planner.hold(clock, profile.quiet_after_event if String(flag).begins_with("event:") else profile.quiet_after_event * 0.4)
	if stalker != null and stalker.is_solid():
		stalker.vanish(&"lost")


## Sonido con el nombre definitivo o, si aún no existe, el provisional.
func _stream(sound: String) -> AudioStream:
	if ResourceLoader.exists(Sfx.DIR + sound + ".wav"):
		return Sfx.stream(sound)
	var fallback: String = FALLBACK_SOUNDS.get(sound, "")
	return Sfx.stream(fallback) if fallback != "" else Sfx.stream(sound)


func _play(sound: String, pos: Vector2, volume_db: float) -> void:
	var stream: AudioStream = _stream(sound)
	if stream != null:
		Sfx.at(world, stream, pos, volume_db)


func _load_state() -> void:
	var state: Dictionary = GameState.object_state(SAVE_KEY)
	var saved_uses: Dictionary = state.get("uses", {})
	for id: Variant in saved_uses:
		planner.uses[StringName(str(id))] = int(saved_uses[id])
	_moved_props = PackedStringArray(state.get("moved", []))


func _save_state() -> void:
	var saved_uses: Dictionary = {}
	for id: StringName in planner.uses:
		saved_uses[String(id)] = planner.uses[id]
	GameState.save_object_state(SAVE_KEY, {"uses": saved_uses, "moved": Array(_moved_props)})
