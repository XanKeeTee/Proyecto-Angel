class_name OptionsMenu
extends CanvasLayer
## Menú de opciones (desde el título y la pausa). Cambia Settings en vivo y lo guarda al cerrar.

signal closed

var _first: Control
var _speed_button: Button
var _fullscreen: CheckButton
var _echo: CheckButton
var _sliders: Dictionary[String, HSlider] = {}


func _init() -> void:
	layer = 48  # por debajo del filtro de imagen: así el brillo se ve al ajustarlo
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(56, 14)
	panel.custom_minimum_size = Vector2(528, 332)
	panel.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("101214"), Color("3a4046"), 0.97))
	add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	panel.add_child(col)
	col.add_child(UiStyle.title("OPCIONES"))

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 3)
	col.add_child(grid)
	_slider(grid, "Volumen general", "master", 0.0, 1.0)
	_slider(grid, "Ambiente", "ambience", 0.0, 1.0)
	_slider(grid, "Música", "music", 0.0, 1.0)
	_slider(grid, "Efectos", "sfx", 0.0, 1.0)
	_slider(grid, "Interfaz", "ui", 0.0, 1.0)
	_slider(grid, "Brillo", "brightness", 0.6, 1.6)
	_slider(grid, "Filtro de imagen", "vhs", 0.0, 1.0)

	grid.add_child(UiStyle.label("Velocidad del texto", UiStyle.SIZE_TEXT, UiStyle.BONE_DIM))
	_speed_button = UiStyle.button("")
	_speed_button.custom_minimum_size = Vector2(200, 0)
	_speed_button.pressed.connect(func() -> void:
		Settings.text_speed = (Settings.text_speed + 1) % Settings.TEXT_SPEEDS.size()
		_refresh()
		Settings.apply())
	grid.add_child(_speed_button)
	grid.add_child(Control.new())

	grid.add_child(UiStyle.label("Pantalla completa", UiStyle.SIZE_TEXT, UiStyle.BONE_DIM))
	_fullscreen = CheckButton.new()
	UiStyle.style_control(_fullscreen)
	_fullscreen.focus_mode = Control.FOCUS_ALL
	_fullscreen.toggled.connect(func(on: bool) -> void:
		Settings.fullscreen = on
		Settings.apply())
	grid.add_child(_fullscreen)
	grid.add_child(Control.new())

	# Eco: reverberación y ecualización según la sala (ver AudioBuses / RoomAcoustics).
	grid.add_child(UiStyle.label("Eco de las salas", UiStyle.SIZE_TEXT, UiStyle.BONE_DIM))
	_echo = CheckButton.new()
	UiStyle.style_control(_echo)
	_echo.focus_mode = Control.FOCUS_ALL
	_echo.toggled.connect(func(on: bool) -> void:
		Settings.echo = on
		Settings.apply())
	grid.add_child(_echo)
	grid.add_child(Control.new())

	var calib: HBoxContainer = HBoxContainer.new()
	calib.add_theme_constant_override("separation", 8)
	var patch: ColorRect = ColorRect.new()
	patch.color = Color.BLACK
	patch.custom_minimum_size = Vector2(28, 28)
	var mark: ColorRect = ColorRect.new()
	mark.color = Color(0.055, 0.055, 0.065)
	mark.position = Vector2(8, 8)
	mark.size = Vector2(12, 12)
	patch.add_child(mark)
	calib.add_child(patch)
	var hint: Label = UiStyle.label("Brillo: súbelo hasta que el cuadrado del recuadro negro
apenas se distinga. La oscuridad es parte del juego.", UiStyle.MONO_SMALL, UiStyle.ASH, UiStyle.mono())
	calib.add_child(hint)
	col.add_child(calib)
	var keys: Label = UiStyle.label(
		"Mover: WASD / flechas / stick · Correr: Shift / L3 / L2 · Usar: E · Examinar: R\nLinterna: F · Custodia: Tab · Bolsillos: 1-5 · Pausa: Esc · Filtro: F2",
		UiStyle.MONO_SMALL, UiStyle.ASH, UiStyle.mono())
	col.add_child(keys)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	col.add_child(buttons)
	var reset: Button = UiStyle.button("Restablecer")
	reset.pressed.connect(func() -> void:
		Settings.reset_defaults()
		_refresh())
	buttons.add_child(reset)
	var back: Button = UiStyle.button("Volver")
	back.pressed.connect(close)
	buttons.add_child(back)


func open() -> void:
	visible = true
	_refresh()
	_first.grab_focus()


func close() -> void:
	Settings.save_settings()
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed(&"pause")):
		get_viewport().set_input_as_handled()
		close()


func _slider(grid: GridContainer, title: String, key: String, low: float, high: float) -> void:
	grid.add_child(UiStyle.label(title, UiStyle.SIZE_TEXT, UiStyle.BONE_DIM))
	var slider: HSlider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(200, 16)
	slider.focus_mode = Control.FOCUS_ALL
	var value_label: Label = UiStyle.label("", UiStyle.MONO_TEXT, UiStyle.BONE, UiStyle.mono())
	slider.value_changed.connect(func(v: float) -> void:
		Settings.set(key, v)
		value_label.text = "%d %%" % roundi(v * 100.0)
		Settings.apply())
	grid.add_child(slider)
	grid.add_child(value_label)
	_sliders[key] = slider
	if _first == null:
		_first = slider


func _refresh() -> void:
	for key: String in _sliders:
		_sliders[key].set_value_no_signal(float(Settings.get(key)))
		var label: Label = _sliders[key].get_parent().get_child(_sliders[key].get_index() + 1) as Label
		label.text = "%d %%" % roundi(float(Settings.get(key)) * 100.0)
	_speed_button.text = Settings.TEXT_SPEED_NAMES[Settings.text_speed]
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	_echo.set_pressed_no_signal(Settings.echo)
