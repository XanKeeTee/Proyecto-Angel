extends Control
## Pantalla de título: el pasillo de la planta en una cinta VHS (fondo animado, rótulos del
## vídeo, lluvia de estática) y el menú: Continuar, Nueva partida, Cargar, Opciones, Créditos y
## Salir. Se maneja con teclado, ratón o mando. Al entrar en la partida, la cinta se rebobina
## entre ruido y empieza a reproducirse. Suena música tensa del menú (si hay pista) que se
## funde al empezar la partida.
## Con argumentos de depuración tras `--` salta directamente al hospital, salvo los del propio
## título: `--screenshot=RUTA --screenshot-delay=S --title-panel=credits|load`.

const HOSPITAL: String = "res://scenes/world/hospital/hospital.tscn"
## Ranuras de guardado que se miran (SaveSystem guarda en la 0; las demás, para el futuro).
const SLOTS: int = 3
## Argumentos que no llevan al hospital.
const TITLE_ARGS: PackedStringArray = ["screenshot", "screenshot-delay", "title-panel"]
## Créditos. Aquí irá también la atribución de cada sonido de Freesound (autor, título, licencia).
## Atribuciones de sonido (texto llano, lo genera tools/audio/freesound.py).
const SOUND_CREDITS: String = "res://assets/audio/credits.txt"
const CREDITS: PackedStringArray = [
	"LA NOVENA VIGILIA — PRÓLOGO",
	"Guion, diseño, código y arte: el equipo de Proyecto-Angel.",
	"Hecho con Godot Engine (godotengine.org), licencia MIT.",
	"Arte provisional generado con las herramientas de tools/art/.",
	"",
	"SONIDO",
	"Efectos de Freesound.org: atribuciones pendientes.",
]
## Sonidos (si aún no existe el definitivo se usa el provisional; ver docs/tech/sonidos.md).
const SOUND_MOVE: String = "ui_move"
const SOUND_ACCEPT: String = "ui_accept"
const SOUND_BACK: String = "ui_back"
const SOUND_REWIND: String = "tape_rewind"
const SOUND_AMBIENCE: String = "title_ambience"
const SOUND_TUBE: String = "title_tube_flicker"
const FALLBACK_SOUNDS: Dictionary[String, String] = {
	"ui_move": "flashlight_click", "ui_accept": "flashlight_click", "ui_back": "flashlight_click",
	"tape_rewind": "pa_static", "title_ambience": "ambience_loop",
}
## Música del menú: una de estas pistas al azar (assets/audio/music/<nombre>.ogg, de Freesound;
## ver docs/tech/sonidos.md). Si no hay ninguna, no suena nada.
const MENU_TRACKS: PackedStringArray = ["music_menu_drone", "music_menu_piano", "music_menu_tension"]
const MUSIC_DB: float = -4.0
const MUSIC_FADE_IN: float = 6.0
const MUSIC_FADE_OUT: float = 1.4
## Con música, el ambiente del título baja para no ensuciarla.
const AMBIENCE_DB: float = -8.0
const AMBIENCE_UNDER_MUSIC_DB: float = -18.0
## Colores fantasma del título (aberración cromática).
const GHOST_RED: Color = Color(0.75, 0.22, 0.17, 0.5)
const GHOST_CYAN: Color = Color(0.37, 0.72, 0.69, 0.4)

var _vhs: VhsOverlay
var _background: TitleBackground
var _osd: TapeOsd
var _menu: VBoxContainer
var _title: Control
var _ghosts: Array[Label] = []
var _options: OptionsMenu
var _load_panel: TitlePanel
var _credits_panel: TitlePanel
var _fade: ColorRect
var _ambience: AudioStreamPlayer
var _music: MusicPlayer
var _info: Label
var _quiet: bool = true
var _leaving: bool = false
var _last_focus: Button


func _ready() -> void:
	if _wants_hospital():
		GameState.new_game()
		get_tree().change_scene_to_file.call_deferred(HOSPITAL)
		return
	_background = TitleBackground.new()
	add_child(_background)
	_background.tube_changed.connect(_on_tube_changed)
	_background.figure_shown.connect(func() -> void: _vhs.glitch(0.5, 0.35))
	_osd = TapeOsd.new()
	add_child(_osd)
	_build_title()
	_build_menu()
	_build_panels()
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_vhs = VhsOverlay.new()
	add_child(_vhs)
	_vhs.set_param(&"vignette_strength", 1.0)
	_play_music()
	_play_ambience()
	_intro()
	_take_debug_screenshot()


func _process(_delta: float) -> void:
	# El título tiembla un poco con la cinta.
	if _title != null and randf() < 0.01:
		_title.position.x = 34.0 + randf_range(-1.0, 1.0)


# --- construcción -----------------------------------------------------------------------------

func _build_title() -> void:
	_title = Control.new()
	_title.position = Vector2(34, 52)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	for ghost: Array in [[GHOST_RED, Vector2(-1, 0)], [GHOST_CYAN, Vector2(1, 0)]]:
		var g: Label = UiStyle.label("LA NOVENA VIGILIA", 26, ghost[0])
		g.position = ghost[1]
		_title.add_child(g)
		_ghosts.append(g)
	var title: Label = UiStyle.label("LA NOVENA VIGILIA", 26, UiStyle.BONE)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_y", 2)
	_title.add_child(title)
	var rule: ColorRect = ColorRect.new()
	rule.color = Color(UiStyle.BONE_DIM, 0.5)
	rule.position = Vector2(2, 38)
	rule.size = Vector2(150, 1)
	_title.add_child(rule)
	var sub: Label = UiStyle.label("P R Ó L O G O", 9, UiStyle.BONE_DIM, UiStyle.mono())
	sub.position = Vector2(2, 42)
	_title.add_child(sub)


func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.position = Vector2(30, 150)
	_menu.custom_minimum_size = Vector2(180, 0)
	_menu.add_theme_constant_override("separation", 1)
	add_child(_menu)
	var latest: int = _latest_slot()
	if latest >= 0:
		_add_item("Continuar", func() -> void: _load(latest))
	_add_item("Nueva partida", _new_game)
	if latest >= 0:
		_add_item("Cargar", func() -> void: _open_panel(_load_panel))
	_options = OptionsMenu.new()
	add_child(_options)
	_add_item("Opciones", func() -> void:
		_options.open()
		await _options.closed
		_focus_last())
	_add_item("Créditos", func() -> void: _open_panel(_credits_panel))
	_add_item("Salir", _quit)
	if latest >= 0:
		var info: Dictionary = SaveSystem.describe(latest)
		_info = UiStyle.label("Última grabación: %s · %d min" % [String(info["saved_at"]).replace("T", " "), int(info["play_time"] / 60.0)],
			8, UiStyle.ASH, UiStyle.mono())
		_info.position = Vector2(30, 290)
		add_child(_info)
	var hint: Label = UiStyle.label("↑↓ elegir    Intro aceptar    Esc volver", 8, UiStyle.BONE_DIM.darkened(0.25), UiStyle.mono())
	hint.position = Vector2(22, 334)
	add_child(hint)


func _build_panels() -> void:
	_load_panel = TitlePanel.new("CARGAR CINTA")
	add_child(_load_panel)
	for slot: int in SLOTS:
		var info: Dictionary = SaveSystem.describe(slot)
		var text: String = "Cinta %d   —   vacía" % (slot + 1)
		if not info.is_empty():
			text = "Cinta %d   %s   %d min" % [slot + 1, String(info["saved_at"]).replace("T", " "), int(info["play_time"] / 60.0)]
		var b: Button = _menu_button(text, 11)
		b.disabled = info.is_empty()
		b.focus_mode = Control.FOCUS_NONE if b.disabled else Control.FOCUS_ALL
		b.pressed.connect(func() -> void: _load(slot))
		_load_panel.body.add_child(b)
	_load_panel.closed.connect(_on_panel_closed)
	_credits_panel = TitlePanel.new("CRÉDITOS")
	add_child(_credits_panel)
	for line: String in _credit_lines():
		var heading: bool = line == line.to_upper() and line != ""
		var l: Label = UiStyle.label(line, 10 if heading else 9, UiStyle.BONE if heading else UiStyle.BONE_DIM,
			null if heading else UiStyle.mono())
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(326, 0)
		_credits_panel.body.add_child(l)
	_credits_panel.closed.connect(_on_panel_closed)


## Créditos con las atribuciones de sonido que escribe tools/audio/freesound.py (si existen).
func _credit_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	var sound_credits: String = FileAccess.get_file_as_string(SOUND_CREDITS) if FileAccess.file_exists(SOUND_CREDITS) else ""
	for line: String in CREDITS:
		if line.begins_with("Efectos de Freesound") and sound_credits.strip_edges() != "":
			lines.append("Efectos y música de Freesound.org:")
			lines.append_array(sound_credits.strip_edges().split("\n"))
		else:
			lines.append(line)
	return lines


func _add_item(text: String, action: Callable) -> Button:
	var b: Button = _menu_button(text, 13)
	b.pressed.connect(func() -> void:
		if _leaving:
			return
		_sound(SOUND_ACCEPT, -6.0)
		action.call())
	_menu.add_child(b)
	return b


## Entrada del menú: texto sobre la imagen; la elegida lleva una marca, una barra tenue y tiembla.
func _menu_button(text: String, font_size: int) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, font_size + 7)
	b.add_theme_font_override("font", UiStyle.serif())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", UiStyle.BONE_DIM.darkened(0.15))
	b.add_theme_color_override("font_hover_color", UiStyle.BONE)
	b.add_theme_color_override("font_focus_color", UiStyle.BONE)
	b.add_theme_color_override("font_pressed_color", UiStyle.BONE)
	b.add_theme_color_override("font_disabled_color", Color(UiStyle.ASH, 0.6))
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	b.add_theme_constant_override("shadow_offset_y", 1)
	var normal: StyleBoxEmpty = StyleBoxEmpty.new()
	normal.content_margin_left = 12
	var focus: StyleBoxFlat = StyleBoxFlat.new()
	focus.bg_color = Color(UiStyle.BONE, 0.07)
	focus.border_color = UiStyle.BONE
	focus.border_width_left = 2
	focus.content_margin_left = 16
	for state: String in ["normal", "disabled"]:
		b.add_theme_stylebox_override(state, normal)
	for state: String in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(state, focus)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.focus_entered.connect(func() -> void: _on_focus(b))
	return b


# --- comportamiento ----------------------------------------------------------------------------

func _intro() -> void:
	_set_menu_enabled(false)
	_background.set_noise(1.0)
	_vhs.glitch(1.2, 0.8)
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 0.0, 0.6)
	tween.parallel().tween_method(_background.set_noise, 1.0, TitleBackground.REST_NOISE, 1.0)
	await tween.finished
	_set_menu_enabled(true)
	_focus_first()
	_quiet = false
	if OS.get_cmdline_user_args().has("--title-panel=credits"):
		_open_panel(_credits_panel)
	elif OS.get_cmdline_user_args().has("--title-panel=load"):
		_open_panel(_load_panel)


func _on_focus(b: Button) -> void:
	if _menu.is_ancestor_of(b):
		_last_focus = b
	for child: Node in _menu.get_children():
		var item: Button = child as Button
		item.text = ("▸ " if item == b else "") + item.text.trim_prefix("▸ ")
	if _quiet or _leaving:
		return
	_sound(SOUND_MOVE, -12.0)
	_vhs.glitch(0.08, 0.12)


func _focus_first() -> void:
	for child: Node in _menu.get_children():
		var b: Button = child as Button
		if b.visible and not b.disabled:
			b.grab_focus()
			return


func _focus_last() -> void:
	if _last_focus != null:
		_quiet = true
		_last_focus.grab_focus()
		_quiet = false
	else:
		_focus_first()


func _set_menu_enabled(enabled: bool) -> void:
	for child: Node in _menu.get_children():
		var b: Button = child as Button
		b.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _open_panel(panel: TitlePanel) -> void:
	_set_menu_enabled(false)
	_menu.modulate.a = 0.45
	panel.open()


func _on_panel_closed() -> void:
	_sound(SOUND_BACK, -10.0)
	_menu.modulate.a = 1.0
	_set_menu_enabled(true)
	_focus_last()


func _on_tube_changed(lit: bool) -> void:
	if not lit:
		_title.modulate.a = 0.75
		for g: Label in _ghosts:
			g.position.x *= 2.0
	else:
		_title.modulate.a = 1.0
		_ghosts[0].position.x = -1.0
		_ghosts[1].position.x = 1.0
		if randf() < 0.3:
			_sound(SOUND_TUBE, -18.0)


func _new_game() -> void:
	GameState.new_game()
	await _enter_tape()
	get_tree().change_scene_to_file(HOSPITAL)


func _load(slot: int) -> void:
	if _leaving or not SaveSystem.load_game(slot):
		return
	await _enter_tape()
	get_tree().change_scene_to_file(GameState.player_scene if GameState.player_scene != "" else HOSPITAL)


## Transición a la partida: la cinta se rebobina entre nieve y empieza a reproducirse.
func _enter_tape() -> void:
	_leaving = true
	_set_menu_enabled(false)
	_load_panel.visible = false
	_credits_panel.visible = false
	_sound(SOUND_REWIND, -4.0)
	_music.fade_out(MUSIC_FADE_OUT)
	_osd.set_mode(TapeOsd.Mode.REWIND)
	_vhs.glitch(1.4, 1.0)
	var tween: Tween = create_tween()
	tween.tween_method(_background.set_noise, TitleBackground.REST_NOISE, 1.0, 1.0).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_menu, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(_title, "modulate:a", 0.0, 0.8)
	tween.tween_property(_fade, "color:a", 1.0, 0.25)
	await tween.finished
	_osd.set_mode(TapeOsd.Mode.PLAY)
	move_child(_osd, get_child_count() - 1)
	await get_tree().create_timer(0.45).timeout


func _quit() -> void:
	_leaving = true
	_osd.set_mode(TapeOsd.Mode.STOP)
	_music.fade_out(0.4)
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.4)
	await tween.finished
	get_tree().quit()


func _play_ambience() -> void:
	var stream: AudioStream = _stream(SOUND_AMBIENCE)
	if stream == null:
		return
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	if wav != null:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	_ambience = AudioStreamPlayer.new()
	_ambience.stream = stream
	_ambience.bus = &"Ambiente"
	_ambience.volume_db = AMBIENCE_UNDER_MUSIC_DB if _music.playing else AMBIENCE_DB
	add_child(_ambience)
	_ambience.play()


func _play_music() -> void:
	_music = MusicPlayer.new()
	_music.name = "Music"
	add_child(_music)
	_music.play_any(MENU_TRACKS, MUSIC_DB, MUSIC_FADE_IN)


func _sound(sound: String, volume_db: float) -> void:
	var stream: AudioStream = _stream(sound)
	if stream != null:
		Sfx.ui(self, stream, volume_db)


func _stream(sound: String) -> AudioStream:
	if ResourceLoader.exists(Sfx.DIR + sound + ".wav"):
		return Sfx.stream(sound)
	var fallback: String = FALLBACK_SOUNDS.get(sound, "")
	return Sfx.stream(fallback) if fallback != "" else null


## Ranura con la grabación más reciente, o -1.
func _latest_slot() -> int:
	var best: int = -1
	var best_at: String = ""
	for slot: int in SLOTS:
		var info: Dictionary = SaveSystem.describe(slot)
		if not info.is_empty() and String(info["saved_at"]) >= best_at:
			best = slot
			best_at = String(info["saved_at"])
	return best


func _wants_hospital() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		var key: String = arg.trim_prefix("--").split("=", true, 1)[0]
		if not TITLE_ARGS.has(key):
			return true
	return false


func _take_debug_screenshot() -> void:
	var path: String = ""
	var delay: float = 2.5
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			path = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--screenshot-delay="):
			delay = arg.trim_prefix("--screenshot-delay=").to_float()
	if path == "":
		return
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captura guardada en ", path)
	get_tree().quit()
