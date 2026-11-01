extends Node
## Opciones del juego (independientes de la partida): volumen por canal, brillo,
## filtro VHS, pantalla completa y velocidad del texto. Se guardan en user://settings.cfg.

signal changed

const PATH: String = "user://settings.cfg"
const BUS_AMBIENCE: StringName = &"Ambiente"
const BUS_SFX: StringName = &"Efectos"
const BUS_UI: StringName = &"Interfaz"
## Velocidad del texto: caracteres por segundo (lento, normal, rápido, instantáneo).
const TEXT_SPEEDS: Array[float] = [25.0, 45.0, 90.0, 10000.0]
const TEXT_SPEED_NAMES: Array[String] = ["Lento", "Normal", "Rápido", "Instantáneo"]

## Volúmenes lineales 0..1.
var master: float = 0.8
var ambience: float = 0.7
var sfx: float = 0.65
var ui: float = 0.6
## Brillo: 0,6 (más oscuro) .. 1,6 (más claro). 1 = el previsto.
var brightness: float = 1.0
## Intensidad del filtro VHS: 0 apagado .. 1 completo.
var vhs: float = 1.0
var fullscreen: bool = false
var text_speed: int = 1


func _ready() -> void:
	_ensure_buses()
	load_settings()
	apply()


func text_chars_per_second() -> float:
	return TEXT_SPEEDS[clampi(text_speed, 0, TEXT_SPEEDS.size() - 1)]


func apply() -> void:
	_set_bus(&"Master", master)
	_set_bus(BUS_AMBIENCE, ambience)
	_set_bus(BUS_SFX, sfx)
	_set_bus(BUS_UI, ui)
	if not DisplayServer.get_name() == "headless":
		var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	changed.emit()


func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for key: String in ["master", "ambience", "sfx", "ui", "brightness", "vhs", "fullscreen", "text_speed"]:
		cfg.set_value("opciones", key, get(key))
	cfg.save(PATH)


func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key: String in ["master", "ambience", "sfx", "ui", "brightness", "vhs", "fullscreen", "text_speed"]:
		if cfg.has_section_key("opciones", key):
			set(key, cfg.get_value("opciones", key))


func reset_defaults() -> void:
	master = 0.8
	ambience = 0.7
	sfx = 0.65
	ui = 0.6
	brightness = 1.0
	vhs = 1.0
	fullscreen = false
	text_speed = 1
	apply()
	save_settings()


func _ensure_buses() -> void:
	for bus: StringName in [BUS_AMBIENCE, BUS_SFX, BUS_UI]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, &"Master")
	# Un limitador suave en el maestro: nada puede saturar.
	var master_index: int = AudioServer.get_bus_index(&"Master")
	if AudioServer.get_bus_effect_count(master_index) == 0:
		var limiter: AudioEffectHardLimiter = AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.5
		AudioServer.add_bus_effect(master_index, limiter)


func _set_bus(bus: StringName, linear: float) -> void:
	var i: int = AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.001)
