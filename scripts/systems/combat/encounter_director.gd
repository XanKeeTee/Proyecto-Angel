class_name EncounterDirector
extends Node
## Encuentro de combate en el mapa (docs/design/enemigos/enfermero.md § En el mapa).
##
## Se crea con una línea desde el guion del mapa: `EncounterDirector.attach(self, preload(...))`.
## - Al recibir el objeto que lo dispara (el tubo) activa la bandera y, si la mano está vacía,
##   lo empuña.
## - Con la bandera puesta, al entrar en una de sus zonas (el pasillo) aparece el enemigo: falla la
##   luz, se le oye arrastrar un pie y se acerca. Luego la cinta salta y empieza el combate.
## - Victoria: el cuerpo queda en el mapa (con las partes que perdió) y se recuerda en el guardado.
##   Huida: vuelve a aparecer más tarde, con sus heridas. Derrota: pantalla de muerte.
## Las constantes y heridas pasan del mapa al combate y de vuelta con CombatBridge.

## El combate ha terminado (antes de la pantalla de muerte, si la hay).
signal resolved(outcome: Battle.Outcome)

const NODE_NAME: StringName = &"EncounterDirector"
const TITLE_SCENE: String = "res://scenes/ui/title/title_screen.tscn"
const BATTLE_LAYER: int = 35
const TRANSITION_LAYER: int = 47
const WORLD_SCALE: float = 0.33
const APPROACH_SECONDS: float = 2.8
const STEP_EVERY: float = 0.75
const LIGHT_TEXTURE: Texture2D = preload("res://assets/sprites/lights/light_round.png")
const NOISE_SHADER: Shader = preload("res://shaders/tape_noise.gdshader")
const CORPSE_ID_SUFFIX: String = "_cadaver"
const STATE_DEAD: String = "dead"
const STATE_FLED: String = "fled"
## Sonidos (con su provisional si aún no está el definitivo).
const SOUND_STEPS: String = "enfermero_drag_steps"
const SOUND_TRANSITION: String = "combat_transition"
const SOUND_FALLBACK: Dictionary[String, String] = {
	"enfermero_drag_steps": "heavy_drag", "combat_transition": "pa_static", "enfermero_breath": "entity_breath",
	"enfermero_growl": "entity_breath",
}

var world: WorldController
var def: EncounterDef
## Para pruebas: si se asigna, resuelve el combate sin interfaz: `func(battle: Battle) -> void`
## (debe dejar `battle.outcome` distinto de ONGOING).
var battle_runner: Callable
## Muestra la pantalla de muerte al perder (las pruebas lo apagan).
var death_screen_enabled: bool = true

var _figure: EnemyView
var _figure_light: PointLight2D
var _corpse: Interactable
var _running: bool = false
## Desde la última aparición el jugador ha salido de las zonas (para que no reaparezca en el acto).
var _left_regions: bool = true
var _battle_scene: BattleScene


## Crea el director del encuentro en un mapa.
static func attach(p_world: WorldController, p_def: EncounterDef) -> EncounterDirector:
	var director: EncounterDirector = EncounterDirector.new()
	director.name = String(NODE_NAME) + "_" + String(p_def.id)
	director.world = p_world
	director.def = p_def
	# Sigue funcionando con el árbol en pausa (durante el combate el mapa se pausa).
	director.process_mode = Node.PROCESS_MODE_ALWAYS
	p_world.add_child(director)
	return director


func _ready() -> void:
	EventBus.item_received.connect(_on_item_received)
	world.player.cell_entered.connect(_on_cell_entered)
	_restore()
	# Depuración: `--encounter` lo hace aparecer junto al jugador nada más empezar.
	if world.debug.has("encounter") and state().get("state", "") != STATE_DEAD:
		var stack: ItemStack = world.character.custody.find_first(def.trigger_item)
		if stack != null and world.character.wielded() == null:
			world.character.wield(stack)
		await get_tree().create_timer(0.8).timeout
		start(world.player.cell, true)


func state() -> Dictionary:
	return GameState.object_state(def.state_key())


func is_running() -> bool:
	return _running


## Cadáver que queda en el mapa tras ganar (o null).
func corpse() -> Interactable:
	return _corpse


# --- disparo ---------------------------------------------------------------------------------------

func _on_item_received(item: ItemDef, _amount: int) -> void:
	if item.id != def.trigger_item:
		return
	GameState.set_flag(def.trigger_flag)
	var character: CharacterState = world.character
	if character.wielded() == null:
		var stack: ItemStack = character.custody.find_first(item.id)
		if stack != null and character.wield(stack) == "":
			world.hud.notice("Empuñas %s." % item.display_name.to_lower())


func _on_cell_entered(cell: Vector2i) -> void:
	if _running:
		return
	var current: Dictionary = state()
	var status: String = current.get("state", "")
	if status == STATE_DEAD:
		return
	if status == STATE_FLED:
		if not _in(cell, def.return_regions):
			_left_regions = true
			return
		if not _left_regions or GameState.play_time < float(current.get("return_at", 0.0)):
			return
		start(cell, false)
		return
	if GameState.has_flag(def.trigger_flag) and _in(cell, def.first_regions):
		start(cell, true)


func _in(cell: Vector2i, regions: Array[Rect2i]) -> bool:
	for region: Rect2i in regions:
		if region.has_point(cell):
			return true
	return false


func _region_of(cell: Vector2i) -> Rect2i:
	for region: Rect2i in def.first_regions + def.return_regions:
		if region.has_point(cell):
			return region
	return Rect2i(cell.x - def.spawn_distance - 2, cell.y, def.spawn_distance * 2 + 5, 1)


# --- aparición ---------------------------------------------------------------------------------------

## Aparece el enemigo cerca de `cell` y empieza el combate.
func start(cell: Vector2i, first_time: bool) -> void:
	if _running:
		return
	_running = true
	_left_regions = false
	world.lock()
	var region: Rect2i = _region_of(cell)
	var row: int = clampi(cell.y, region.position.y, region.end.y - 1)
	var direction: int = 1 if cell.x + def.spawn_distance < region.end.x else -1
	var spawn_cell: Vector2i = Vector2i(clampi(cell.x + direction * def.spawn_distance, region.position.x,
		region.end.x - 1), row)
	var stop_cell: Vector2i = Vector2i(cell.x + direction * def.stop_distance, row)
	_spawn_figure(world.cell_center(spawn_cell))
	world.player.face(Vector2i(direction, 0))
	var saved: Dictionary = state().get("enemy", {})
	if not saved.is_empty():
		for id: StringName in CombatBridge.lost_parts(saved):
			_figure.set_part_state(id, CombatTypes.PartState.AMPUTATED)
	await _introduce(first_time, world.cell_center(stop_cell))
	await _fight()


func _spawn_figure(point: Vector2) -> void:
	_figure = EnemyView.new()
	_figure.name = "Encounter_" + String(def.id)
	_figure.draw_scale = WORLD_SCALE
	_figure.light_mask = LightLayers.PROPS
	_figure.position = point
	_figure.setup(def.enemy)
	var layer: Node = world.get_node_or_null(^"%World")
	(layer if layer != null else world).add_child(_figure)
	_figure_light = PointLight2D.new()
	_figure_light.texture = LIGHT_TEXTURE
	_figure_light.texture_scale = 0.9
	_figure_light.color = Color(0.78, 0.86, 0.8)
	_figure_light.energy = 0.0
	_figure_light.range_item_cull_mask = LightLayers.ALL_ITEMS
	_figure_light.position = point + Vector2(0, -40)
	(layer if layer != null else world).add_child(_figure_light)


## Presentación: la luz falla sobre él, se le oye y se acerca.
func _introduce(first_time: bool, stop_point: Vector2) -> void:
	var lines: PackedStringArray = def.intro_lines if first_time else def.return_lines
	var region: Rect2i = Rect2i(Vector2i((_figure.position / WorldController.TILE_SIZE).floor()) - Vector2i(6, 3), Vector2i(12, 6))
	world.flicker_lights(region, 1.4)
	world.glitch(0.6, 0.45)
	_sound_at(SOUND_STEPS, _figure.position, -2.0)
	var flicker: Tween = create_tween()
	for i: int in 6:
		flicker.tween_property(_figure_light, "energy", randf_range(0.5, 1.1), 0.07)
		flicker.tween_property(_figure_light, "energy", 0.0, randf_range(0.06, 0.2))
	flicker.tween_property(_figure_light, "energy", 0.55, 0.3)
	if lines.size() > 0:
		await world.message.show_lines(lines.slice(0, mini(2, lines.size())))
	_sound_at(def.enemy.sound_idle, _figure.position, -4.0)
	var walk: Tween = create_tween()
	walk.tween_property(_figure, "position", stop_point, APPROACH_SECONDS)
	walk.parallel().tween_property(_figure_light, "position", stop_point + Vector2(0, -40), APPROACH_SECONDS)
	var steps: int = int(APPROACH_SECONDS / STEP_EVERY)
	for i: int in steps:
		_sound_at(SOUND_STEPS, _figure.position, -4.0)
		await get_tree().create_timer(STEP_EVERY).timeout
	if walk.is_running():
		await walk.finished
	if lines.size() > 2:
		await world.message.show_lines(lines.slice(2))
	_sound_at("enfermero_growl", _figure.position, -2.0)
	world.glitch(0.4, 0.6)


# --- combate -------------------------------------------------------------------------------------

func _fight() -> void:
	var saved: Dictionary = state().get("enemy", {})
	var seed_value: int = int(world.debug["battle-seed"]) if world.debug.has("battle-seed") else -1
	var battle: Battle = CombatBridge.build_battle(def, world.character, saved, seed_value)
	if battle_runner.is_valid():
		battle_runner.call(battle)
	else:
		await _run_battle_scene(battle)
	await _finish(battle)


func _run_battle_scene(battle: Battle) -> void:
	world.hud.visible = false
	await get_tree().process_frame
	var snapshot: Texture2D = _snapshot()
	var veil: CanvasLayer = _make_veil()
	var noise: ShaderMaterial = (veil.get_child(0) as ColorRect).material as ShaderMaterial
	_sound_ui(SOUND_TRANSITION, -2.0)
	world.glitch(1.0, 1.0)
	var cover: Tween = create_tween()
	cover.tween_method(func(v: float) -> void: noise.set_shader_parameter(&"amount", v), 0.0, 1.0, 0.55)
	await cover.finished
	get_tree().paused = true
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = BATTLE_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	world.add_child(layer)
	_battle_scene = BattleScene.new()
	var passthrough: Dictionary[String, String] = {}
	for key: String in ["battle-pick", "battle-maim", "battle-wound", "battle-seed"]:
		if world.debug.has(key):
			passthrough[key] = world.debug[key]
	_battle_scene.setup(battle, world.character, snapshot, def.music, passthrough)
	_battle_scene.vhs = world.vhs
	layer.add_child(_battle_scene)
	var uncover: Tween = create_tween()
	uncover.tween_method(func(v: float) -> void: noise.set_shader_parameter(&"amount", v), 1.0, 0.0, 0.6)
	# Las rayas de la cinta no dependen de `amount`: durante el combate, fuera (la pantalla es limpia).
	uncover.tween_callback(func() -> void: noise.set_shader_parameter(&"streaks", 0.0))
	await _battle_scene.battle_closed
	noise.set_shader_parameter(&"streaks", 1.0)
	_sound_ui(SOUND_TRANSITION, -6.0)
	var out: Tween = create_tween()
	out.tween_method(func(v: float) -> void: noise.set_shader_parameter(&"amount", v), 0.0, 1.0, 0.45)
	await out.finished
	layer.queue_free()
	_battle_scene = null
	get_tree().paused = false
	world.hud.visible = true
	var back: Tween = create_tween()
	back.tween_method(func(v: float) -> void: noise.set_shader_parameter(&"amount", v), 1.0, 0.0, 0.6)
	back.tween_callback(veil.queue_free)


## Escena del combate en curso (o null).
func battle_scene() -> BattleScene:
	return _battle_scene


func _make_veil() -> CanvasLayer:
	var veil: CanvasLayer = CanvasLayer.new()
	veil.layer = TRANSITION_LAYER
	veil.process_mode = Node.PROCESS_MODE_ALWAYS
	var rect: ColorRect = ColorRect.new()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = NOISE_SHADER
	material.set_shader_parameter(&"amount", 0.0)
	material.set_shader_parameter(&"streaks", 1.0)
	material.set_shader_parameter(&"roll", 1.0)
	rect.material = material
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(rect)
	world.add_child(veil)
	return veil


## Imagen del mapa justo antes del combate (fondo del combate). null si no se puede (headless).
func _snapshot() -> Texture2D:
	var texture: ViewportTexture = world.get_viewport().get_texture()
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


# --- después del combate -------------------------------------------------------------------------------

func _finish(battle: Battle) -> void:
	var outcome: Battle.Outcome = battle.outcome
	var hero: Combatant = battle.protagonist()
	var enemy: Combatant = battle.enemies[0]
	if outcome != Battle.Outcome.GAME_OVER:
		CombatBridge.to_vitals(hero, world.character.vitals)
	var current: Dictionary = {"enemy": CombatBridge.enemy_state(enemy)}
	match outcome:
		Battle.Outcome.VICTORY:
			current["state"] = STATE_DEAD
			current["x"] = _figure.position.x
			current["y"] = _figure.position.y
			GameState.save_object_state(def.state_key(), current)
			_figure_light.queue_free()
			_figure.sync_parts(enemy)
			_figure.show_dead()
			_make_corpse(_figure)
			resolved.emit(outcome)
			await world.message.show_lines(def.victory_lines)
		Battle.Outcome.PARTY_FLED, Battle.Outcome.PROTAGONIST_ESCAPED:
			current["state"] = STATE_FLED
			current["return_at"] = GameState.play_time + def.return_delay
			GameState.save_object_state(def.state_key(), current)
			var gone: Tween = create_tween()
			gone.tween_property(_figure, "modulate:a", 0.0, 0.6)
			gone.parallel().tween_property(_figure_light, "energy", 0.0, 0.6)
			await gone.finished
			_figure.queue_free()
			_figure_light.queue_free()
			_figure = null
			resolved.emit(outcome)
			await world.message.show_lines(def.flee_lines)
		_:
			resolved.emit(outcome)
			_running = false
			await _game_over()
			return
	_running = false
	world.unlock()


func _game_over() -> void:
	if not death_screen_enabled:
		return
	var screen: DeathScreen = DeathScreen.new()
	world.add_child(screen)
	get_tree().paused = true
	var choice: DeathScreen.Choice = await screen.choose(SaveSystem.has_save())
	get_tree().paused = false
	if choice == DeathScreen.Choice.LOAD and SaveSystem.load_game():
		get_tree().change_scene_to_file(GameState.player_scene if GameState.player_scene != "" else world.scene_file_path)
	else:
		get_tree().change_scene_to_file(TITLE_SCENE)


## El cuerpo del enemigo que queda en el mapa: se ve (con lo que perdió) y se puede examinar.
func _make_corpse(view: EnemyView) -> void:
	_corpse = Interactable.new()
	_corpse.name = "Corpse_" + String(def.id)
	_corpse.object_id = StringName(String(def.id) + CORPSE_ID_SUFFIX)
	_corpse.display_name = def.corpse_name
	_corpse.examine_text = def.corpse_examine
	_corpse.kind = Interactable.Kind.FIXTURE
	_corpse.blocks = false
	var cell: Vector2i = Vector2i((view.position / WorldController.TILE_SIZE).floor())
	_corpse.position = world.cell_center(cell)
	_corpse.footprint = [Vector2i.ZERO, Vector2i(1, 0)]
	view.get_parent().add_child(_corpse)
	view.reparent(_corpse)
	world.reindex()


## Al cargar el mapa: si ya se le venció, el cuerpo sigue donde quedó.
func _restore() -> void:
	var current: Dictionary = state()
	if current.get("state", "") != STATE_DEAD:
		return
	var view: EnemyView = EnemyView.new()
	view.draw_scale = WORLD_SCALE
	view.light_mask = LightLayers.PROPS
	view.position = Vector2(float(current.get("x", 0.0)), float(current.get("y", 0.0)))
	view.setup(def.enemy)
	var saved: Dictionary = current.get("enemy", {})
	var parts: Dictionary = saved.get("parts", {})
	for key: Variant in parts:
		view.set_part_state(StringName(key), int((parts[key] as Array)[0]))
	view.show_dead()
	var layer: Node = world.get_node_or_null(^"%World")
	(layer if layer != null else world).add_child(view)
	_figure = view
	_make_corpse(view)


func _sound_at(sound: String, point: Vector2, volume_db: float) -> void:
	var name: String = _resolve_sound(sound)
	if name != "":
		Sfx.at(world, name, point, volume_db)


func _sound_ui(sound: String, volume_db: float) -> void:
	var name: String = _resolve_sound(sound)
	if name != "":
		Sfx.ui(world, name, volume_db)


func _resolve_sound(sound: String) -> String:
	if sound == "":
		return ""
	if ResourceLoader.exists(Sfx.DIR + sound + ".wav"):
		return sound
	var fallback: String = SOUND_FALLBACK.get(sound, "")
	return fallback if fallback != "" and ResourceLoader.exists(Sfx.DIR + fallback + ".wav") else ""
