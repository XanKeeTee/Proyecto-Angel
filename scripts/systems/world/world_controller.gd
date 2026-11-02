class_name WorldController
extends Node2D
## Base de cualquier mapa explorable. Reúne los sistemas de exploración:
## interacción, puertas, linterna y batería, bolsillos, custodia, inspector, lector,
## constantes, guardado, escenario persistente y utilidades para los eventos.
## Cada mapa concreto (p. ej. el hospital) hereda de aquí y añade su guion.
##
## Nodos que espera la escena (nombres únicos): %Map, %Player, %World, %Fade, %Darkness.
## Opcional: %Events (EventDirector), %Ambience (AudioStreamPlayer en bucle).

const TILE_SIZE: int = 32
## Carga que gasta la linterna por segundo encendida (100 = carga completa).
const FLASHLIGHT_DRAIN: float = 100.0 / 540.0
const SAVE_SPECIAL: StringName = &"save"
## Segundos desde que empieza un gesto hasta que la mano toca el objeto (ahí suena y cambia el
## estado). Si el jugador tiene la señal `action_contact`, manda ella (con CONTACT_TIMEOUT de margen).
const ACTION_CONTACT: Dictionary = {
	&"reach_low": 0.42, &"reach_mid": 0.32, &"reach_high": 0.45, &"pickup": 0.5,
	&"key": 0.55, &"valve": 0.7, &"lever": 0.5, &"pry": 0.8,
}
const CONTACT_SIGNAL: StringName = &"action_contact"
const CONTACT_TIMEOUT: float = 1.5
## Escaleras: andar hacia el hueco mientras funde, negro con pasos y vuelta.
const WARP_WALK: float = 14.0
const WARP_FADE_OUT: float = 0.45
const WARP_HOLD: float = 0.45
const WARP_FADE_IN: float = 0.6
const DEBUG_ARGS_HELP: String = "--skip-intro --at=X,Y --face=dir --give=id,id --flag=f,f --wear=id,id --aim=grados --open-doors --loot-seed=N --custody --outfit --doc=id --screenshot=RUTA --screenshot-delay=S --auto-advance=S --no-vhs"

## Virado de color de la zona.
@export var zone_tint: Color = Color(0.9, 1.0, 0.96)
@export var start_cell: Vector2i = Vector2i.ZERO
@export var start_facing: Vector2i = Vector2i.DOWN
## Botín aleatorio del mapa (opcional).
@export var loot_plan: LootPlan
## Pensamientos / objetivo actual del protagonista (opcional; tecla T).
@export var thoughts: ThoughtSet

var player: Player
var character: CharacterState:
	get:
		return GameState.character
var message: MessageBox
var vhs: VhsOverlay
var hud: Hud
var custody_screen: CustodyScreen
var inspector: Inspector
var pause_menu: PauseMenu
var director: EventDirector
var debug: Dictionary[String, String] = {}

var _map: TileMapLayer
var _world: Node2D
var _fade: ColorRect
var _interactables: Dictionary[Vector2i, Array] = {}
var _doors: Array[Door] = []
var _watched_doors: Dictionary[Door, bool] = {}
var _focused: Interactable
var _busy: bool = false
var _warping: bool = false
var _out_of_charge_warned: bool = false
var _mind_noise_timer: float = 8.0
var _all_interactables: Array[Interactable] = []
var _last_thought: String = ""


func _ready() -> void:
	_parse_debug_args()
	_map = %Map
	player = %Player
	_world = %World
	_fade = %Fade
	LightLayers.setup_player(player)
	_build_ui()
	_restore_scenery()
	_apply_loot()
	_index_interactables()
	player.interact_requested.connect(_on_interact)
	player.examine_requested.connect(_on_examine)
	player.cell_entered.connect(_on_cell_entered)
	EventBus.item_received.connect(_on_item_received)
	EventBus.document_received.connect(_on_document_received)
	EventBus.flag_set.connect(_on_flag_for_hints)
	director = get_node_or_null(^"%Events") as EventDirector
	if director != null:
		director.setup(self)
	_apply_debug_state()
	apply_outfit()
	character.outfit_changed.connect(apply_outfit)
	_last_thought = current_thought()
	if _resume_from_save():
		_fade.color.a = 1.0
		_fade_to(0.0, 0.8)
		unlock()
	elif debug.has("skip-intro") or debug.has("at"):
		_start_debug()
	else:
		start_new()
	if debug.has("screenshot"):
		_take_screenshot_later(debug["screenshot"], debug.get("screenshot-delay", "1.5").to_float())


## Comienzo de partida nueva. Las escenas lo sobrescriben (secuencia de inicio).
func start_new() -> void:
	player.place(start_cell, start_facing)
	_fade.color.a = 0.0
	unlock()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	GameState.play_time += delta
	_update_flashlight(delta)
	_update_vitals(delta)
	_update_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or get_tree().paused or not player.input_enabled:
		return
	if event.is_action_pressed(InputActions.CUSTODY):
		get_viewport().set_input_as_handled()
		open_custody()
	elif event.is_action_pressed(InputActions.PAUSE):
		get_viewport().set_input_as_handled()
		pause_menu.open()
	elif event.is_action_pressed(InputActions.FLASHLIGHT):
		get_viewport().set_input_as_handled()
		toggle_flashlight()
	elif event.is_action_pressed(InputActions.THOUGHTS):
		get_viewport().set_input_as_handled()
		show_thoughts()
	else:
		for i: int in InputActions.POCKETS.size():
			if event.is_action_pressed(InputActions.POCKETS[i]):
				get_viewport().set_input_as_handled()
				use_pocket(i)
				return


# --- API para guiones y eventos ---------------------------------------------------------------

func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE) + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)


## Vuelve a indexar los objetos (tras mover u ocultar algo).
func reindex() -> void:
	_index_interactables()


func find_object(id: StringName) -> Interactable:
	for node: Node in find_children("*", "Interactable", true, false):
		var it: Interactable = node as Interactable
		if it.object_id == id:
			return it
	return null


func sfx_at(sound: String, position: Vector2, volume_db: float = 0.0) -> void:
	Sfx.at(self, sound, position, volume_db)


func glitch(duration: float, strength: float) -> void:
	vhs.glitch(duration, strength)


## Muestra textos bloqueando al jugador.
func show_lines(lines: PackedStringArray) -> void:
	if lines.is_empty():
		return
	lock()
	await message.show_lines(lines)
	unlock()


func lock() -> void:
	player.input_enabled = false
	player.stop()


## Devuelve el control dos fotogramas después (para que el Intro que cerró un texto no vuelva a actuar).
func unlock() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not message.is_open() and not _busy and not debug.has("screenshot"):
		player.input_enabled = true


## Parpadeo de las luces de una zona (Rect2i vacío = todas) y de la linterna.
func flicker_lights(region: Rect2i, duration: float) -> void:
	for node: Node in get_tree().get_nodes_in_group(PoweredLight.GROUP):
		var light: PoweredLight = node as PoweredLight
		if region.size == Vector2i.ZERO or region.has_point(Vector2i((light.position / TILE_SIZE).floor())):
			light.flicker(duration)
	if player.has_flashlight_on():
		player.flicker_flashlight(duration * 0.6)
		get_tree().create_timer(duration * 0.6 + 0.05).timeout.connect(func() -> void:
			player.set_light_on(character.flashlight_on and _lamp_charge() > 0.0))


## Desplaza un elemento del escenario por nombre (y lo recuerda).
func move_scenery(node_name: String, offset: Vector2, frame: int = -1) -> void:
	var node: Node2D = _world.find_child(node_name, true, false) as Node2D
	if node == null:
		push_warning("Escenario: no existe " + node_name)
		return
	node.position += offset
	var it: Interactable = node as Interactable
	if frame >= 0 and it != null:
		it.set_frames(frame)
	elif frame >= 0:
		var sprite: Sprite2D = node.get_node_or_null(^"Sprite2D") as Sprite2D
		if sprite != null:
			sprite.frame = frame
	_save_scenery(node)
	reindex()


func set_scenery_visible(node_name: String, show: bool) -> void:
	var node: Node2D = _world.find_child(node_name, true, false) as Node2D
	if node == null:
		return
	var it: Interactable = node as Interactable
	if it != null:
		it.set_hidden(not show)
	else:
		node.visible = show
		_save_scenery(node)
	reindex()


func open_custody(document_id: StringName = &"") -> void:
	lock()
	custody_screen.open(CustodyScreen.Tab.DOSSIER if document_id != &"" else CustodyScreen.Tab.TRAY, document_id)
	await custody_screen.closed
	hud.refresh_pockets()
	unlock()


## Viste al jugador con lo que lleva puesto el personaje: capas del sprite, balanceo de la
## tela y sonido de las pisadas según el calzado. Las hojas de la ropa se cargan aquí (solo
## las de lo que lleva puesto) y se sueltan al quitársela.
func apply_outfit() -> void:
	for slot: ItemDef.EquipSlot in [ItemDef.EquipSlot.HEAD, ItemDef.EquipSlot.BODY, ItemDef.EquipSlot.LEGS, ItemDef.EquipSlot.FEET]:
		var stack: ItemStack = character.worn(slot)
		if stack != null:
			var def: ItemDef = stack.def
			player.set_outfit(ItemDef.slot_layer(slot), def.wear_path, def.cloth_sway, def.cloth_waist, def.cloth_hem)
		else:
			player.set_outfit(ItemDef.slot_layer(slot), "")
	var feet: ItemStack = character.worn(ItemDef.EquipSlot.FEET)
	var shod: bool = feet != null and feet.def.step_sound != ""
	player.step_sound = feet.def.step_sound if shod else "step"
	player.step_volume_db = feet.def.step_volume_db if shod else -10.0


func toggle_flashlight() -> void:
	var lamp: ItemStack = character.flashlight()
	if lamp == null:
		return
	if lamp.charge <= 0.0:
		hud.notice("La linterna no tiene pilas.")
		Sfx.at(self, "flashlight_click", player.position, -6.0)
		return
	character.flashlight_on = not character.flashlight_on
	Sfx.at(self, "flashlight_click", player.position, -4.0)


func use_pocket(index: int) -> void:
	var stack: ItemStack = character.custody.pockets[index]
	hud.flash_pocket(index)
	if stack == null:
		return
	if stack.def.id == &"linterna":
		toggle_flashlight()
		return
	if not stack.def.usable:
		hud.notice(stack.def.display_name + ": no se puede usar así.")
		return
	var text: String = character.use_item(stack)
	hud.notice(text if text != "" else "Ahora no lo necesitas.")
	hud.refresh_pockets()


## Guardar en una grabadora.
func save_at_station() -> void:
	lock()
	var choice: int = await message.ask("¿Grabar en la cinta?", PackedStringArray(["Grabar", "No"]))
	if choice == 0:
		GameState.player_scene = scene_file_path
		GameState.player_position = player.position
		GameState.player_facing = player.facing_angle
		if SaveSystem.save_game():
			Sfx.at(self, "tape_save", player.position, -4.0)
			await message.show_lines(PackedStringArray(["Pulsas el botón rojo y hablas cerca del micrófono.", "No reconoces del todo tu propia voz."]))
	unlock()


# --- interacción --------------------------------------------------------------------------------

func _index_interactables() -> void:
	_interactables.clear()
	_doors.clear()
	_all_interactables.clear()
	for node: Node in find_children("*", "Interactable", true, false):
		var it: Interactable = node as Interactable
		_all_interactables.append(it)
		var door: Door = it as Door
		if door != null:
			door.tile_layer = _map
			door._apply_visuals()
			_doors.append(door)
			if not _watched_doors.has(door):
				_watched_doors[door] = true
				door.state_changed.connect(_on_door_changed.bind(door))
		for c: Vector2i in it.cells():
			if not _interactables.has(c):
				_interactables[c] = []
			_interactables[c].append(it)
	_refresh_glints()


## Objetos cercanos al protagonista (sus casillas a dos o menos de distancia).
func _candidates() -> Array[Interactable]:
	var result: Array[Interactable] = []
	var here: Vector2i = player.cell
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			for node: Variant in _interactables.get(here + Vector2i(dx, dy), []):
				# Un objeto soltado y recogido se libera: puede quedar en el índice un instante.
				if not is_instance_valid(node):
					continue
				var it: Interactable = node as Interactable
				if it != null and not result.has(it):
					result.append(it)
	return result


## El objeto con el que se interactuaría ahora (por cercanía y por hacia dónde mira).
func pick_target() -> Interactable:
	return InteractionPicker.pick(_candidates(), player.position, player.facing_angle)


## Acciones que se ofrecen ahora para un objeto (sin cerrar una puerta con el jugador dentro).
func actions_for(it: Interactable) -> Array[Dictionary]:
	var actions: Array[Dictionary] = it.get_actions(character)
	var door: Door = it as Door
	if door != null and door.passage_cells().has(player.cell):
		actions = actions.filter(func(a: Dictionary) -> bool: return a["id"] != Interactable.ACT_CLOSE)
	return actions


func _update_focus() -> void:
	if not player.input_enabled:
		_set_focus(null)
		hud.set_prompt("", [])
		return
	var it: Interactable = pick_target()
	_set_focus(it)
	if it == null:
		hud.set_prompt("", [])
		return
	var keys: Array[String] = []
	var labels: PackedStringArray = []
	for action: Dictionary in actions_for(it):
		labels.append(action["label"])
	if not labels.is_empty():
		keys.append("[E] " + " / ".join(labels))
	keys.append("[R] Examinar")
	var state: String = it.prompt_state()
	hud.set_prompt(it.display_name + ("  · " + state if state != "" else ""), keys)


## Cambia el objeto enfocado y su contorno.
func _set_focus(it: Interactable) -> void:
	if it == _focused:
		return
	if _focused != null and is_instance_valid(_focused):
		FocusOutline.detach(_focused.get_node_or_null(^"Sprite2D") as Sprite2D)
	_focused = it
	if it != null:
		var sprite: Sprite2D = it.get_node_or_null(^"Sprite2D") as Sprite2D
		if sprite != null:
			FocusOutline.attach(sprite)


func _on_interact(_cells: Array[Vector2i] = []) -> void:
	if _busy:
		return
	var it: Interactable = pick_target()
	if it == null:
		return
	var actions: Array[Dictionary] = actions_for(it)
	if actions.is_empty():
		await _perform(it, Interactable.ACT_EXAMINE)
		return
	if actions.size() == 1:
		await _perform(it, actions[0]["id"])
		return
	# Varias acciones: se elige (la última opción cancela).
	_busy = true
	lock()
	var labels: PackedStringArray = []
	for action: Dictionary in actions:
		labels.append(action["label"])
	labels.append("Nada")
	var choice: int = await message.ask(it.display_name + ":", labels)
	_busy = false
	if choice < 0 or choice >= actions.size():
		unlock()
		return
	await _perform(it, actions[choice]["id"])


func _on_examine(_cells: Array[Vector2i] = []) -> void:
	if _busy:
		return
	var it: Interactable = pick_target()
	if it == null:
		return
	await _perform(it, Interactable.ACT_EXAMINE)


## Ejecuta una acción sobre un objeto: el protagonista hace el gesto (si lo tiene), y el cambio de
## estado y el sonido llegan cuando la mano toca el objeto; luego el texto y lo que venga después.
func _perform(it: Interactable, action: StringName) -> void:
	_busy = true
	lock()
	var anim: StringName = it.anim_for(action)
	var gesture: Dictionary = {"done": true}
	if anim != &"" and player.has_method(&"play_action"):
		gesture["done"] = false
		var target: Vector2 = _contact_point(it)
		var run: Callable = func() -> void:
			await player.call(&"play_action", anim, target)
			gesture["done"] = true
		run.call()
		await _wait_contact(anim, gesture)
	var result: InteractionResult = it.perform(action, character)
	if result.sound != null:
		Sfx.at(self, result.sound, it.position, -4.0)
	await on_interacted(it, action, result)
	while not gesture["done"]:
		await get_tree().process_frame
	if result.inspect_sheet != null:
		inspector.show_item(result.inspect_title, "\n".join(result.lines), result.inspect_sheet, result.inspect_views)
		await inspector.closed
		get_tree().paused = false
	elif not result.lines.is_empty():
		await message.show_lines(result.lines)
	if result.read_document != null:
		_busy = false
		await open_custody(result.read_document.id)
		_busy = true
	if result.special == SAVE_SPECIAL:
		_busy = false
		await save_at_station()
		_busy = true
	elif result.special != &"":
		await on_special(result.special, it)
	hud.refresh_pockets()
	_refresh_glints()
	_check_thoughts()
	_busy = false
	unlock()


## Punto del objeto hacia el que se gira la mano: el centro de su casilla más cercana.
func _contact_point(it: Interactable) -> Vector2:
	var best: Vector2 = it.position
	var best_d: float = INF
	for c: Vector2i in it.cells():
		var p: Vector2 = cell_center(c)
		var d: float = p.distance_squared_to(player.position)
		if d < best_d:
			best_d = d
			best = p
	return best


## Espera a que la mano llegue: la señal `action_contact` del jugador si existe, si no el
## tiempo de ACTION_CONTACT. Nunca más que lo que dure el gesto.
func _wait_contact(anim: StringName, gesture: Dictionary) -> void:
	var touched: Array[bool] = [false]
	var on_touch: Callable = func(_a: Variant = null, _b: Variant = null) -> void:
		touched[0] = true
	var by_signal: bool = player.has_signal(CONTACT_SIGNAL)
	if by_signal:
		player.connect(CONTACT_SIGNAL, on_touch, CONNECT_ONE_SHOT)
	var limit: float = CONTACT_TIMEOUT if by_signal else float(ACTION_CONTACT.get(anim, 0.35))
	var waited: float = 0.0
	while not touched[0] and not gesture["done"] and waited < limit:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if by_signal and player.is_connected(CONTACT_SIGNAL, on_touch):
		player.disconnect(CONTACT_SIGNAL, on_touch)


## Gancho para las escenas: algo ha pasado con un objeto (antes de mostrar el texto).
func on_interacted(_it: Interactable, _action: StringName, _result: InteractionResult) -> void:
	pass


## Gancho para las escenas: dispositivo con evento especial (teléfono, generador…).
func on_special(_id: StringName, _it: Interactable) -> void:
	pass


## Una puerta se ha cerrado (también sola, por un evento) con el jugador dentro del hueco:
## sale hacia el lado más cercano para no quedar atrapado en la colisión.
func _on_door_changed(door: Door) -> void:
	_refresh_glints()
	if door.is_open or not door.is_active():
		return
	var passage: Array[Vector2i] = door.passage_cells()
	if not passage.has(player.cell):
		return
	var base: Vector2i = door.base_cell()
	var middle: float = cell_center(base).y - 1.5 * TILE_SIZE
	if player.position.y >= middle:
		player.place(base + Vector2i.DOWN, Vector2i.UP)
	else:
		player.place(base + Vector2i(0, -4), Vector2i.DOWN)


func _on_cell_entered(cell: Vector2i) -> void:
	if _warping:
		return
	for door: Door in _doors:
		var warp: Array = door.warp_for(cell)
		if not warp.is_empty():
			_warp(warp[0], warp[1], door)
			return
	on_cell_entered(cell)


## Gancho para las escenas.
func on_cell_entered(_cell: Vector2i) -> void:
	pass


## Cambio de planta (escaleras): sigue andando hacia el hueco mientras funde a negro, con pasos.
func _warp(target: Vector2i, facing: Vector2i, door: Door) -> void:
	_warping = true
	var heading: Vector2 = player.velocity if player.velocity.length() > 1.0 else door.position - player.position
	lock()
	var ahead: Vector2 = heading.normalized() * WARP_WALK
	var walk: Tween = create_tween()
	walk.tween_property(player, "position", player.position + ahead, WARP_FADE_OUT * 0.8)
	Sfx.at(self, "%s_%d" % [player.step_sound, 1], player.position, player.step_volume_db)
	await _fade_to(1.0, WARP_FADE_OUT)
	player.place(target, facing)
	for i: int in 3:
		Sfx.at(self, "%s_%d" % [player.step_sound, 2 + i], player.position, player.step_volume_db - 2.0 * i)
		await get_tree().create_timer(WARP_HOLD / 3.0).timeout
	await _fade_to(0.0, WARP_FADE_IN)
	_warping = false
	unlock()


func _on_item_received(item: ItemDef, amount: int) -> void:
	# «Has cogido linterna», «Has cogido pilas ×4».
	var item_name: String = item.display_name.left(1).to_lower() + item.display_name.substr(1)
	hud.notice("Has cogido " + item_name + (" ×%d" % amount if amount > 1 else "") + ".")
	hud.poke()
	_refresh_glints()


# --- pistas: destellos y pensamientos ---------------------------------------------------------------

## Pone o quita el destello de los objetos que deben llamar la atención (Interactable.wants_attention).
func _refresh_glints() -> void:
	if player == null:
		return
	for it: Interactable in _all_interactables:
		if not is_instance_valid(it):
			continue
		var want: bool = it.wants_attention(character)
		var glint: Glint = it.get_node_or_null(NodePath(String(Glint.NODE_NAME))) as Glint
		if want and glint == null:
			glint = Glint.attach(it, _glint_point(it))
			glint.watcher = player
		elif glint != null:
			glint.visible = want


## Dónde brilla: arriba a la derecha del dibujo del objeto (o sobre su casilla si no tiene).
func _glint_point(it: Interactable) -> Vector2:
	var sprite: Sprite2D = it.get_node_or_null(^"Sprite2D") as Sprite2D
	if sprite == null:
		return Vector2(4, -10)
	var rect: Rect2 = sprite.get_rect()
	return sprite.position + Vector2(rect.position.x + rect.size.x * 0.68, rect.position.y + rect.size.y * 0.3)


## Lo que el protagonista sabe que tiene que hacer ahora (tecla T).
func current_thought() -> String:
	if thoughts == null:
		return ""
	return thoughts.current_text(GameState.has_flag, character.custody.has)


func show_thoughts() -> void:
	if thoughts == null:
		return
	var lines: PackedStringArray = []
	if character.vitals.bleeding and thoughts.bleeding_text != "":
		lines.append(thoughts.bleeding_text)
	var text: String = current_thought()
	if text != "":
		lines.append(text)
	_last_thought = text
	await show_lines(lines)


## Avisa (sin interrumpir) cuando cambia lo que el protagonista tiene en la cabeza.
func _check_thoughts() -> void:
	var text: String = current_thought()
	if text == _last_thought:
		return
	if _last_thought != "" and text != "":
		hud.notice("Algo nuevo en lo que pensar  ·  T")
	_last_thought = text


func _on_flag_for_hints(_flag: StringName) -> void:
	_refresh_glints()
	_check_thoughts.call_deferred()


# --- botín aleatorio ---------------------------------------------------------------------------------

## Tira el botín del mapa con la semilla de la partida (nueva al empezar, guardada después).
## Las partidas guardadas antes de existir el botín aleatorio conservan el contenido original.
func _apply_loot() -> void:
	if loot_plan == null:
		return
	var state: Dictionary = GameState.object_state(LootRoller.STATE_KEY)
	var seed_value: int = LootRoller.LEGACY_SEED
	if state.is_empty():
		if GameState.objects.is_empty():
			seed_value = int(debug["loot-seed"]) if debug.has("loot-seed") else LootRoller.new_seed()
		GameState.save_object_state(LootRoller.STATE_KEY, {"seed": seed_value})
	else:
		seed_value = int(state.get("seed", LootRoller.LEGACY_SEED))
	if seed_value == LootRoller.LEGACY_SEED:
		return
	var rolled: Dictionary = LootRoller.roll(loot_plan, seed_value)
	for id: Variant in rolled:
		var it: Interactable = find_object(StringName(id))
		if it == null:
			push_warning("Botín: no existe el objeto " + str(id))
			continue
		var slot: LootSlot = loot_plan.slot(StringName(id))
		if slot != null and slot.override_search:
			it.search_text = slot.search_text
		it.replace_contents(loot_plan.keeps, LootRoller.to_entries(rolled[id]))


func _on_document_received(doc: DocumentDef) -> void:
	hud.notice("Expediente: " + doc.title)
	Sfx.at(self, "paper", player.position, -8.0)


# --- linterna y constantes -------------------------------------------------------------------------

func _lamp_charge() -> float:
	var lamp: ItemStack = character.flashlight()
	return lamp.charge if lamp != null else 0.0


func _update_flashlight(delta: float) -> void:
	var lamp: ItemStack = character.flashlight()
	player.set_holding_flashlight(lamp != null)
	if lamp == null:
		player.set_light_on(false)
		return
	if character.flashlight_on and lamp.charge > 0.0:
		lamp.charge = maxf(0.0, lamp.charge - FLASHLIGHT_DRAIN * delta)
		if lamp.charge <= 0.0:
			character.flashlight_on = false
			hud.notice("La linterna se apaga. Necesita pilas.")
			Sfx.at(self, "flashlight_click", player.position, -8.0)
	player.set_light_on(character.flashlight_on and lamp.charge > 0.0)
	player.set_light_level(lamp.charge / lamp.def.max_charge)


func _update_vitals(delta: float) -> void:
	if not player.input_enabled:
		return
	var v: Vitals = character.vitals
	v.tick(delta)
	# Cuerpo bajo: más lento y con la imagen enrojecida.
	var hurt: float = clampf((50.0 - v.body) / 30.0, 0.0, 1.0)
	player.speed_scale = lerpf(1.0, 0.7, hurt)
	vhs.set_tint(zone_tint.lerp(Color(1.0, 0.75, 0.75), hurt * 0.6))
	# Mente baja: ruidos y distorsiones que no existen.
	var unease: float = clampf((45.0 - v.mind) / 40.0, 0.0, 1.0)
	vhs.set_param("aberration_px", 1.0 + unease * 1.5)
	_mind_noise_timer -= delta * (0.3 + unease)
	if _mind_noise_timer <= 0.0:
		_mind_noise_timer = randf_range(14.0, 30.0)
		if unease > 0.2:
			var dir: Vector2 = Vector2.from_angle(randf() * TAU)
			Sfx.at(self, ["whisper", "steps_far", "knock"].pick_random(), player.position + dir * 160.0, -10.0)
			if unease > 0.6:
				glitch(0.3, 0.3)


# --- escenario persistente ----------------------------------------------------------------------------

func _save_scenery(node: Node2D) -> void:
	var sprite: Sprite2D = node.get_node_or_null(^"Sprite2D") as Sprite2D
	GameState.save_object_state(StringName("scenery:" + node.name), {
		"x": node.position.x, "y": node.position.y, "visible": node.visible,
		"frame": sprite.frame if sprite != null else -1,
	})


func _restore_scenery() -> void:
	for key: StringName in GameState.objects:
		if not String(key).begins_with("scenery:"):
			continue
		var node: Node2D = _world.find_child(String(key).trim_prefix("scenery:"), true, false) as Node2D
		if node == null:
			continue
		var s: Dictionary = GameState.objects[key]
		node.position = Vector2(float(s.get("x", node.position.x)), float(s.get("y", node.position.y)))
		if not node is Interactable:
			node.visible = bool(s.get("visible", true))
		var sprite: Sprite2D = node.get_node_or_null(^"Sprite2D") as Sprite2D
		if sprite != null and int(s.get("frame", -1)) >= 0:
			sprite.frame = int(s["frame"])
		var body: CollisionObject2D = node.get_node_or_null(^"Body") as CollisionObject2D
		if body != null and not node.visible:
			body.process_mode = Node.PROCESS_MODE_DISABLED


# --- arranque, carga y depuración ---------------------------------------------------------------------

func _resume_from_save() -> bool:
	if not GameState.has_position or GameState.player_scene != scene_file_path:
		return false
	player.position = GameState.player_position
	player.facing_angle = GameState.player_facing
	player.place(player.cell, Vector2i.DOWN)
	player.position = GameState.player_position
	player.facing_angle = GameState.player_facing
	GameState.has_position = false
	on_resumed()
	return true


## Gancho: se ha cargado una partida en este mapa.
func on_resumed() -> void:
	pass


func _apply_debug_state() -> void:
	if debug.has("give"):
		for id: String in debug["give"].split(","):
			var item: ItemDef = Registry.item(StringName(id))
			if item != null:
				GameState.give_item(item, maxi(1, item.max_stack))
	if debug.has("flag"):
		for f: String in debug["flag"].split(","):
			GameState.set_flag(StringName(f))
	if debug.has("wear"):
		for id: String in debug["wear"].split(","):
			var item: ItemDef = Registry.item(StringName(id))
			if item != null and item.is_wearable():
				GameState.give_item(item)
				character.equip(character.custody.find_first(item.id))
	if debug.has("open-doors"):
		for node: Node in find_children("*", "Door", true, false):
			(node as Door).force_state(true, false)
	if debug.has("auto-advance"):
		message.auto_advance = debug["auto-advance"].to_float()
	vhs.set_enabled(not debug.has("no-vhs"))


func _start_debug() -> void:
	_fade.color.a = 0.0
	var cell: Vector2i = start_cell
	if debug.has("at"):
		var parts: PackedStringArray = debug["at"].split(",")
		cell = Vector2i(parts[0].to_int(), parts[1].to_int())
	var names: Dictionary[String, Vector2i] = {
		"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT,
		"up_left": Vector2i(-1, -1), "up_right": Vector2i(1, -1), "down_left": Vector2i(-1, 1), "down_right": Vector2i(1, 1),
	}
	player.place(cell, names.get(debug.get("face", "down"), Vector2i.DOWN))
	if character.flashlight() != null:
		character.flashlight_on = true
	on_debug_start()
	await get_tree().create_timer(0.5).timeout
	unlock()
	if debug.has("options"):
		var options: OptionsMenu = OptionsMenu.new()
		add_child(options)
		options.open()
	if debug.has("aim"):
		player.forced_aim = Vector2.from_angle(deg_to_rad(debug["aim"].to_float()))
	if debug.has("outfit"):
		custody_screen.open(CustodyScreen.Tab.CHARACTER)
	if debug.has("custody") or debug.has("doc"):
		if debug.has("doc"):
			GameState.give_document(Registry.document(StringName(debug["doc"])))
		open_custody(StringName(debug.get("doc", "")))


## Gancho: arranque de depuración (las escenas preparan su estado).
func on_debug_start() -> void:
	pass


func _parse_debug_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var pair: PackedStringArray = arg.substr(2).split("=", true, 1)
			debug[pair[0]] = pair[1] if pair.size() > 1 else ""


func _take_screenshot_later(path: String, delay: float) -> void:
	await get_tree().create_timer(delay, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captura guardada en ", path)
	get_tree().quit()


func _fade_to(alpha: float, seconds: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", alpha, seconds)
	await tween.finished


func _build_ui() -> void:
	message = MessageBox.new()
	add_child(message)
	vhs = VhsOverlay.new()
	add_child(vhs)
	vhs.set_tint(zone_tint)
	vhs.set_param("grain_amount", 0.085)
	vhs.set_param("vignette_strength", 0.95)
	add_child(StatusFx.new())
	hud = Hud.new()
	add_child(hud)
	var reticle: AimReticle = AimReticle.new()
	reticle.player = player
	add_child(reticle)
	custody_screen = CustodyScreen.new()
	add_child(custody_screen)
	inspector = Inspector.new()
	add_child(inspector)
	custody_screen.inspect_requested.connect(func(stack: ItemStack) -> void:
		inspector.show_item(stack.def.display_name, stack.def.description, stack.def.inspect_sheet, stack.def.inspect_views, stack.def.icon))
	inspector.closed.connect(func() -> void:
		if not custody_screen.is_open():
			get_tree().paused = false)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	add_child(CustodyWorldLink.create(self))  # objetos descartados, arma en la mano y sonidos de uso
