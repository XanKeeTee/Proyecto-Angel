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
const DEBUG_ARGS_HELP: String = "--skip-intro --at=X,Y --face=dir --give=id,id --flag=f,f --wear=id,id --aim=grados --custody --outfit --doc=id --screenshot=RUTA --screenshot-delay=S --auto-advance=S --no-vhs"

## Virado de color de la zona.
@export var zone_tint: Color = Color(0.9, 1.0, 0.96)
@export var start_cell: Vector2i = Vector2i.ZERO
@export var start_facing: Vector2i = Vector2i.DOWN

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
var _focused: Interactable
var _busy: bool = false
var _warping: bool = false
var _out_of_charge_warned: bool = false
var _mind_noise_timer: float = 8.0


func _ready() -> void:
	_parse_debug_args()
	_map = %Map
	player = %Player
	_world = %World
	_fade = %Fade
	_build_ui()
	_restore_scenery()
	_index_interactables()
	player.interact_requested.connect(_on_interact)
	player.examine_requested.connect(_on_examine)
	player.cell_entered.connect(_on_cell_entered)
	EventBus.item_received.connect(_on_item_received)
	EventBus.document_received.connect(_on_document_received)
	director = get_node_or_null(^"%Events") as EventDirector
	if director != null:
		director.setup(self)
	_apply_debug_state()
	apply_outfit()
	character.outfit_changed.connect(apply_outfit)
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
## tela y sonido de las pisadas según el calzado.
func apply_outfit() -> void:
	for slot: ItemDef.EquipSlot in [ItemDef.EquipSlot.HEAD, ItemDef.EquipSlot.BODY, ItemDef.EquipSlot.LEGS, ItemDef.EquipSlot.FEET]:
		var stack: ItemStack = character.worn(slot)
		if stack != null:
			player.set_outfit_layer(ItemDef.slot_layer(slot), stack.def.wear_sheet, stack.def.cloth_sway)
		else:
			player.set_outfit_layer(ItemDef.slot_layer(slot), null)
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
	for node: Node in find_children("*", "Interactable", true, false):
		var it: Interactable = node as Interactable
		var door: Door = it as Door
		if door != null:
			door.tile_layer = _map
			door._apply_visuals()
			_doors.append(door)
		for c: Vector2i in it.cells():
			if not _interactables.has(c):
				_interactables[c] = []
			_interactables[c].append(it)


func _target(cells: Array[Vector2i]) -> Interactable:
	for c: Vector2i in cells:
		for node: Variant in _interactables.get(c, []):
			var it: Interactable = node as Interactable
			if it != null and it.is_active():
				return it
	return null


func _update_focus() -> void:
	if not player.input_enabled:
		hud.set_prompt("", [])
		return
	var it: Interactable = _target(player.probe_cells())
	_focused = it
	if it == null:
		hud.set_prompt("", [])
		return
	var keys: Array[String] = []
	var primary: Dictionary = it.primary_action(character)
	if not primary.is_empty():
		keys.append("[E] " + primary["label"])
	keys.append("[R] Examinar")
	hud.set_prompt(it.display_name, keys)


func _on_interact(cells: Array[Vector2i]) -> void:
	var it: Interactable = _target(cells)
	if it == null or _busy:
		return
	var primary: Dictionary = it.primary_action(character)
	if primary.is_empty():
		_on_examine(cells)
		return
	await _perform(it, primary["id"])


func _on_examine(cells: Array[Vector2i]) -> void:
	var it: Interactable = _target(cells)
	if it == null or _busy:
		return
	await _perform(it, Interactable.ACT_EXAMINE)


func _perform(it: Interactable, action: StringName) -> void:
	_busy = true
	lock()
	var result: InteractionResult = it.perform(action, character)
	if result.sound != null:
		Sfx.at(self, result.sound, it.position, -4.0)
	await on_interacted(it, action, result)
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
	_busy = false
	unlock()


## Gancho para las escenas: algo ha pasado con un objeto (antes de mostrar el texto).
func on_interacted(_it: Interactable, _action: StringName, _result: InteractionResult) -> void:
	pass


## Gancho para las escenas: dispositivo con evento especial (teléfono, generador…).
func on_special(_id: StringName, _it: Interactable) -> void:
	pass


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


func _warp(target: Vector2i, facing: Vector2i, door: Door) -> void:
	_warping = true
	lock()
	if door.sound_open != null:
		Sfx.at(self, door.sound_open, door.position, -6.0)
	await _fade_to(1.0, 0.22)
	player.place(target, facing)
	await get_tree().create_timer(0.12).timeout
	await _fade_to(0.0, 0.3)
	_warping = false
	unlock()


func _on_item_received(item: ItemDef, amount: int) -> void:
	hud.notice("Custodia: " + item.display_name + (" ×%d" % amount if amount > 1 else ""))
	hud.poke()


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
