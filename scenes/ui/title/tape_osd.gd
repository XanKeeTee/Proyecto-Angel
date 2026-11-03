class_name TapeOsd
extends Control
## Rótulos en pantalla de un vídeo doméstico (OSD): modo de la cinta con su símbolo, contador
## de cinta y fecha y hora de la grabación (las del sistema). Letra de máquina, blanco hueso
## con sombra dura, como los caracteres que genera el aparato.

enum Mode { PLAY, REWIND, STOP }

## Segundos de cinta con los que empieza el contador (la cinta ya estaba empezada).
const COUNTER_START: float = 9.0 * 60.0 + 9.0
## Velocidad del contador al rebobinar (segundos de cinta por segundo).
const REWIND_SPEED: float = 900.0
const MONTHS: PackedStringArray = ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]

var mode: Mode = Mode.PLAY
## Segundos de cinta que marca el contador.
var counter: float = COUNTER_START

var _mode_label: Label
var _counter_label: Label
var _date_label: Label
var _blink: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_label = _osd(Vector2(22, 16))
	_counter_label = _osd(Vector2(508, 16))
	_date_label = _osd(Vector2(470, 330))
	_refresh()


func _process(delta: float) -> void:
	_blink += delta
	match mode:
		Mode.PLAY:
			counter += delta
		Mode.REWIND:
			counter = maxf(0.0, counter - REWIND_SPEED * delta)
	_refresh()


func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_blink = 0.0
	_refresh()


func _refresh() -> void:
	match mode:
		Mode.PLAY:
			_mode_label.text = "PLAY ▶" if fmod(_blink, 1.6) < 1.1 else "PLAY"
		Mode.REWIND:
			_mode_label.text = "◀◀ REW"
		Mode.STOP:
			_mode_label.text = "STOP ■"
	var total: int = int(counter)
	_counter_label.text = "%d:%02d:%02d" % [floori(total / 3600.0), floori(total / 60.0) % 60, total % 60]
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var hour: int = int(now["hour"])
	_date_label.text = "%s %02d %d\n%s %2d:%02d" % [MONTHS[int(now["month"]) - 1], int(now["day"]), int(now["year"]),
		"AM" if hour < 12 else "PM", (hour + 11) % 12 + 1, int(now["minute"])]


func _osd(at: Vector2) -> Label:
	var l: Label = UiStyle.label("", 11, UiStyle.BONE, UiStyle.mono())
	l.position = at
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 0)
	add_child(l)
	return l
