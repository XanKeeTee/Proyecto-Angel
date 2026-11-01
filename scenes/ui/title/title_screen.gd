extends Control
## Pantalla de título: Continuar (si hay partida), Nueva partida, Salir.
## Con argumentos de depuración tras `--` salta directamente al hospital.

const HOSPITAL: String = "res://scenes/world/hospital/hospital.tscn"

var _vhs: VhsOverlay
var _continue: Button


func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		GameState.new_game()
		get_tree().change_scene_to_file.call_deferred(HOSPITAL)
		return
	var bg: ColorRect = ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title: Label = UiStyle.label("LA NOVENA VIGILIA", 22, UiStyle.BONE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 96)
	title.size = Vector2(640, 30)
	add_child(title)
	var sub: Label = UiStyle.label("PRÓLOGO", 9, UiStyle.ASH, UiStyle.mono())
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 128)
	sub.size = Vector2(640, 14)
	add_child(sub)
	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(260, 180)
	box.custom_minimum_size = Vector2(120, 0)
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_continue = UiStyle.button("Continuar")
	_continue.pressed.connect(_on_continue)
	_continue.visible = SaveSystem.has_save()
	box.add_child(_continue)
	var new_game: Button = UiStyle.button("Nueva partida")
	new_game.pressed.connect(_on_new_game)
	box.add_child(new_game)
	var options: OptionsMenu = OptionsMenu.new()
	add_child(options)
	var options_button: Button = UiStyle.button("Opciones")
	options_button.pressed.connect(func() -> void:
		options.open()
		await options.closed
		options_button.grab_focus())
	box.add_child(options_button)
	var quit: Button = UiStyle.button("Salir")
	quit.pressed.connect(get_tree().quit)
	box.add_child(quit)
	var info: Dictionary = SaveSystem.describe()
	if not info.is_empty():
		var minutes: int = int(info["play_time"] / 60.0)
		var l: Label = UiStyle.label("Última grabación: %s  ·  %d min" % [String(info["saved_at"]).replace("T", " "), minutes], 7, UiStyle.ASH, UiStyle.mono())
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(0, 250)
		l.size = Vector2(640, 12)
		add_child(l)
	_vhs = VhsOverlay.new()
	add_child(_vhs)
	(_continue if _continue.visible else new_game).grab_focus()
	_flicker(title)


func _flicker(title: Label) -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(2.0, 6.0)).timeout
		if not is_inside_tree():
			return
		title.modulate.a = 0.3
		_vhs.glitch(0.25, 0.4)
		await get_tree().create_timer(0.07).timeout
		title.modulate.a = 1.0


func _on_continue() -> void:
	if SaveSystem.load_game():
		get_tree().change_scene_to_file(GameState.player_scene if GameState.player_scene != "" else HOSPITAL)


func _on_new_game() -> void:
	GameState.new_game()
	get_tree().change_scene_to_file(HOSPITAL)
