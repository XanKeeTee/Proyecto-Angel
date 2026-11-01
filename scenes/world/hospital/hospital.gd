extends WorldController
## Guion del prólogo de La Novena Vigilia: el hospital.
## Lo genérico (interacción, custodia, linterna, guardado, eventos de datos) está en WorldController
## y en los recursos de la escena. Aquí solo va lo que es propio de este lugar:
## despertar, linterna inicial, teléfono, generador, vuelta de la luz, megafonía,
## pasillo imposible y final.
## Diseño: docs/design/escenas/prologo.md.

const TITLE_SCENE: String = "res://scenes/ui/title/title_screen.tscn"
const START_CHARGE: float = 35.0
const STRETCHER_LYING: int = 1
const STRETCHER_SITTING: int = 2
const STRETCHER_MESSY: int = 3
const PA_LINE: String = "«El paciente de la habitación nueve ha recuperado la consciencia. Inicien el protocolo de recuperación»."
const FLAG_IMPOSSIBLE: StringName = &"pasillo_imposible"
const ENDING_X: int = -18
const HEARTBEAT_PERIOD: float = 0.95
const EMERGENCY_PERIOD: float = 1.5

@export var intro_lines: PackedStringArray = [
	"Frío.",
	"Huele a desinfectante. Debajo, a algo dulce.",
	"Al moverte, algo tira en la espalda. Puntos. Recientes.",
]

var _ending: bool = false
var _monitor_base: float = 1.0
var _emergency_base: Dictionary[Node, float] = {}

@onready var _stretcher: Interactable = find_object(&"cama_09")
@onready var _monitor_light: PointLight2D = %MonitorLight
@onready var _ambience: AudioStreamPlayer = %Ambience
@onready var _impossible: TileMapLayer = %Impossible


func _ready() -> void:
	super._ready()
	_monitor_base = _monitor_light.energy
	for node: Node in get_tree().get_nodes_in_group(&"emergency"):
		_emergency_base[node] = (node as PointLight2D).energy
	var loop: AudioStreamWAV = _ambience.stream as AudioStreamWAV
	if loop != null:
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
	_ambience.play()
	EventBus.flag_set.connect(_on_flag)
	_apply_power_state()


# --- inicio ------------------------------------------------------------------------------------

func start_new() -> void:
	player.place(start_cell, Vector2i.DOWN)
	player.visible = false
	lock()
	_stretcher.set_frames(STRETCHER_LYING)
	_fade.color.a = 1.0
	await get_tree().create_timer(1.4).timeout
	await message.stamp("Despierta.", 1.4)
	await get_tree().create_timer(0.6).timeout
	await _fade_to(0.55, 1.0)
	await _fade_to(1.0, 0.25)
	await get_tree().create_timer(0.7).timeout
	await _fade_to(0.3, 1.2)
	await _fade_to(0.85, 0.35)
	await _fade_to(0.0, 1.8)
	await message.show_lines(intro_lines)
	_stretcher.set_frames(STRETCHER_SITTING)
	Sfx.at(self, "bed_creak", _stretcher.position, -6.0)
	await get_tree().create_timer(1.0).timeout
	glitch(0.3, 0.35)
	_stretcher.set_frames(STRETCHER_MESSY)
	player.place(start_cell, Vector2i.DOWN)
	player.visible = true
	await message.show_lines(PackedStringArray(["Llevas una pulsera de plástico en la muñeca."]))
	GameState.give_document(Registry.document(&"pulsera_09"))
	hud.notice("WASD / flechas: moverse   ·   E: usar   ·   R: examinar   ·   Tab: custodia")
	unlock()


func on_debug_start() -> void:
	_stretcher.set_frames(STRETCHER_MESSY)
	if character.flashlight() != null:
		GameState.set_flag(&"linterna_cogida")


func on_resumed() -> void:
	_apply_power_state()


# --- ganchos de interacción ---------------------------------------------------------------------

func on_interacted(it: Interactable, _action: StringName, _result: InteractionResult) -> void:
	if it.object_id == &"mesita_09" and character.flashlight() != null and not GameState.has_flag(&"linterna_preparada"):
		GameState.set_flag(&"linterna_preparada")
		var lamp: ItemStack = character.flashlight()
		lamp.charge = START_CHARGE
		var pocket: int = character.custody.pockets.find(null)
		if pocket >= 0:
			character.custody.to_pocket(lamp, pocket)
		character.flashlight_on = true
		Sfx.at(self, "flashlight_click", player.position, -4.0)
		hud.notice("F: encender o apagar la linterna. Las pilas no durarán mucho.")


func on_special(id: StringName, it: Interactable) -> void:
	match id:
		&"phone":
			await _phone(it)
		&"elevator":
			Sfx.at(self, "metal_bang", it.position + Vector2(0, -40), 2.0)
			character.vitals.change_mind(-4)
		&"generator":
			await _generator(it)


func _phone(it: Interactable) -> void:
	if GameState.has_flag(&"telefono_sonando") and not GameState.has_flag(&"telefono_contestado"):
		GameState.set_flag(&"telefono_contestado")
		Sfx.at(self, "phone_static", it.position, 0.0)
		await message.show_lines(PackedStringArray([
			"Descuelgas. Estática.",
			"Debajo, alguien respira despacio. Al mismo ritmo que tú.",
			"Cuando contienes la respiración, al otro lado también la contienen.",
		]))
		character.vitals.change_mind(-5)
	else:
		await message.show_lines(PackedStringArray(["No hay línea. Solo un pitido largo."]))
	it.device_used = false


func _generator(it: Interactable) -> void:
	if not GameState.has_flag(&"fusible_puesto"):
		Sfx.at(self, "generator_start", it.position, -4.0)
		await message.show_lines(PackedStringArray([
			"Tiras de la palanca. El motor tose, se sacude y se para.",
			"Al cuadro general no le llega nada. Habrá que arreglarlo primero.",
		]))
		it.device_used = false
		return
	await _power_on(it)


# --- vuelta de la luz y megafonía -------------------------------------------------------------------

func _power_on(generator: Interactable) -> void:
	lock()
	Sfx.at(self, "generator_start", generator.position, 0.0)
	await message.show_lines(PackedStringArray(["Tiras de la palanca. El motor tose, se sacude… y aguanta."]))
	await get_tree().create_timer(2.5).timeout
	var hum: AudioStreamPlayer2D = Sfx.at(self, "generator_loop", generator.position, -6.0, 0.0)
	if hum != null:
		(hum.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	GameState.set_flag(GameState.FLAG_POWER)
	Sfx.ui(self, "fluorescent_on", -6.0)
	glitch(0.6, 0.4)
	await get_tree().create_timer(3.0).timeout
	Sfx.ui(self, "pa_chime", -2.0)
	await get_tree().create_timer(2.6).timeout
	Sfx.ui(self, "pa_static", -6.0)
	glitch(1.2, 0.5)
	await message.show_lines(PackedStringArray([
		"Los altavoces de todo el edificio se encienden a la vez.",
		PA_LINE,
	]))
	character.vitals.change_mind(-8)
	await get_tree().create_timer(0.8).timeout
	await message.show_lines(PackedStringArray([
		"La habitación nueve.",
		"Hablan de ti. Saben que estás despierto.",
		"Tienes que salir de aquí.",
	]))
	GameState.set_flag(FLAG_IMPOSSIBLE)
	unlock()


func _on_flag(flag: StringName) -> void:
	if flag == GameState.FLAG_POWER:
		_apply_power_state()
	elif flag == FLAG_IMPOSSIBLE:
		_reveal_impossible()


func _apply_power_state() -> void:
	var powered: bool = GameState.has_flag(GameState.FLAG_POWER)
	for node: Node in get_tree().get_nodes_in_group(&"computers"):
		(node as Interactable).set_frames(1 if powered else 0)
	for node: Node in get_tree().get_nodes_in_group(&"powered_props"):
		(node as Interactable).set_frames(1 if powered else 0)
	var exit: Interactable = find_object(&"salida_principal")
	if exit != null and powered:
		exit.locked_text = "Ahora el cierre magnético zumba. Aunque quitaras las cadenas, la puerta no se abriría.\nEl hospital no te deja salir por aquí."
	if GameState.has_flag(FLAG_IMPOSSIBLE):
		_reveal_impossible()


# --- el pasillo imposible y el final -------------------------------------------------------------

func _reveal_impossible() -> void:
	if _impossible.visible:
		return
	_impossible.visible = true
	_impossible.collision_enabled = true
	for y: int in range(11, 17):
		_map.erase_cell(Vector2i(0, y))
	for node: Node in get_tree().get_nodes_in_group(&"impossible"):
		(node as Interactable).set_hidden(false)
	for node: Node in get_tree().get_nodes_in_group(&"impossible_lights"):
		(node as PointLight2D).enabled = true
	for node: Node in get_tree().get_nodes_in_group(&"west_prints"):
		(node as Node2D).visible = true
	reindex()


func on_cell_entered(cell: Vector2i) -> void:
	if _ending or not GameState.has_flag(FLAG_IMPOSSIBLE):
		return
	if cell.x == -2 and not GameState.has_flag(&"vio_pasillo"):
		GameState.set_flag(&"vio_pasillo")
		show_lines(PackedStringArray([
			"Este pasillo no estaba aquí.",
			"Según el plano, al otro lado de este muro termina el edificio. Al otro lado solo debería haber calle.",
		]))
	elif cell.x <= ENDING_X:
		_run_ending()


func _run_ending() -> void:
	_ending = true
	lock()
	GameState.set_flag(&"prologo_terminado")
	await message.show_lines(PackedStringArray([
		"Al fondo hay una puerta abierta con un número: 09.",
		"Dentro se oye un monitor. Late al mismo ritmo que tu pecho.",
		"En la cama hay alguien tumbado, con las correas abrochadas.",
		"Tiene tu cara.",
	]))
	glitch(2.8, 1.0)
	player.flicker_flashlight(1.6)
	for node: Node in get_tree().get_nodes_in_group(PoweredLight.GROUP):
		(node as PoweredLight).flicker(1.5)
	await get_tree().create_timer(1.8).timeout
	await _fade_to(1.0, 0.8)
	_ambience.stop()
	await get_tree().create_timer(1.5).timeout
	message.set_stamp("La novena vigilia.")
	await get_tree().create_timer(3.0).timeout
	message.show_hint("Fin del prólogo.   Intro: volver al título.", 0.0)
	await message.wait_accept()
	if not debug.has("screenshot"):
		get_tree().change_scene_to_file(TITLE_SCENE)


# --- ambiente --------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	var now: float = Time.get_ticks_msec() / 1000.0
	var beat: float = fposmod(now, HEARTBEAT_PERIOD) / HEARTBEAT_PERIOD
	_monitor_light.energy = _monitor_base * (0.75 + 0.45 * exp(-beat * 9.0))
	var phase: float = fposmod(now, EMERGENCY_PERIOD) / EMERGENCY_PERIOD
	var level: float = pow(sin(phase / 0.62 * PI), 0.7) if phase < 0.62 else 0.0
	var west_on: bool = GameState.has_flag(FLAG_IMPOSSIBLE)
	for node: Node in _emergency_base:
		var light: PointLight2D = node as PointLight2D
		var on: bool = not _ending and (west_on or not light.is_in_group(&"emergency_west"))
		light.enabled = on and level > 0.01
		light.energy = _emergency_base[node] * level
		var sprite: Sprite2D = light.get_node_or_null(^"Sprite") as Sprite2D
		if sprite != null:
			sprite.frame = 0 if on and level > 0.3 else 1
			var glow: Sprite2D = sprite.get_node_or_null(^"Glow") as Sprite2D
			if glow != null:
				glow.visible = on and level > 0.05
				glow.modulate.a = level
