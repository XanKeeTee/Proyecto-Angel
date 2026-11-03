class_name StatusFx
extends CanvasLayer
## Efectos de pantalla según el estado del personaje: herido (viñeta granate que late con el
## corazón), sangrando (regueros en los bordes y pérdidas de color), Mente baja (eco leve en los
## bordes) y cura (onda cálida al vendarse, suavizado con analgésicos o sedante).
## Va por debajo de la interfaz (no la tapa) y por encima del mundo. La intensidad se reduce con
## la opción de filtro VHS (sin llegar a desaparecer: es información de juego).
## Se añade por código desde WorldController._build_ui: `add_child(StatusFx.new())`.
## Escucha `Vitals.changed` del personaje activo y `EventBus.item_used`.
## Depuración (tras `--`): `--body=N`, `--mind=N`, `--bleed`, `--use=id_objeto@segundos`
## (p. ej. `--use=venda@2` usa una venda a los 2 s para ver la cura).

const SHADER: Shader = preload("res://shaders/status_fx.gdshader")
## Cuerpo a partir del cual se nota la herida y Cuerpo con la herida al máximo (el suelo del prólogo).
const HURT_FROM: float = 60.0
const HURT_FULL: float = 22.0
## Mente a partir de la cual hay eco y Mente con el eco al máximo (igual que WorldController).
const UNEASE_FROM: float = 45.0
const UNEASE_RANGE: float = 40.0
## Pulsaciones por minuto: en reposo y con la herida al máximo.
const BPM_CALM: float = 66.0
const BPM_HURT: float = 128.0
## Rapidez con la que los valores mostrados siguen al estado real (1/s).
const FOLLOW: float = 2.5
const DRAIN_TIME: float = 0.7
const HEAL_TIME: float = 1.8
const RELIEF_TIME: float = 3.0
const CALM_TIME: float = 2.8
## Sonidos (opcionales: si aún no existen, no suena nada; ver docs/tech/sonidos.md).
const SOUND_HEARTBEAT: String = "status_heartbeat"
const SOUND_RELIEF: String = "status_relief_breath"

var _rect: ColorRect
var _material: ShaderMaterial
var _vitals: Vitals
var _last_body: int = 0
var _hurt: float = 0.0
var _bleed: float = 0.0
var _unease: float = 0.0
var _drain: float = 0.0
var _heal_time: float = -1.0
var _heal_strength: float = 0.0
var _relief: float = 0.0
var _calm: float = 0.0
var _beat_phase: float = 0.0
var _pulse: float = 0.0
var _beats: int = 0


func _init() -> void:
	layer = 5  # mundo < estado < HUD (10) < textos y menús < filtro VHS (50)
	name = "StatusFx"


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	EventBus.item_used.connect(_on_item_used)
	_bind()
	_apply_debug_args()
	snap()


func _process(delta: float) -> void:
	if GameState.character.vitals != _vitals:
		_bind()
	var blend: float = 1.0 - exp(-FOLLOW * delta)
	_hurt = lerpf(_hurt, _hurt_target(), blend)
	_bleed = lerpf(_bleed, 1.0 if _vitals.bleeding else 0.0, blend)
	_unease = lerpf(_unease, _unease_target(), blend * 0.5)
	_drain = maxf(0.0, _drain - delta / DRAIN_TIME)
	_relief = maxf(0.0, _relief - delta / RELIEF_TIME)
	_calm = maxf(0.0, _calm - delta / CALM_TIME)
	if _heal_time >= 0.0:
		_heal_time += delta
		if _heal_time >= HEAL_TIME:
			_heal_time = -1.0
	_update_heart(delta)
	_apply()


## Lleva los efectos de golpe al estado actual (al cargar, en pruebas).
func snap() -> void:
	_hurt = _hurt_target()
	_bleed = 1.0 if _vitals.bleeding else 0.0
	_unease = _unease_target()
	_apply()


## Intensidad actual de la herida en pantalla (0..1).
func hurt_level() -> float:
	return _hurt * (1.0 - _relief * 0.7)


## Intensidad actual del sangrado en pantalla (0..1).
func bleed_level() -> float:
	return _bleed * (1.0 - _relief * 0.8)


## Si se está viendo la onda de una cura.
func is_healing() -> bool:
	return _heal_time >= 0.0


## Suavizado por analgésico o sedante (0..1).
func calm_level() -> float:
	return _calm


## Pérdida de color por sangrado (0..1).
func drain_level() -> float:
	return _drain


func _bind() -> void:
	if _vitals != null and _vitals.changed.is_connected(_on_vitals_changed):
		_vitals.changed.disconnect(_on_vitals_changed)
	_vitals = GameState.character.vitals
	_vitals.changed.connect(_on_vitals_changed)
	_last_body = _vitals.body


func _on_vitals_changed() -> void:
	# Cada punto de Cuerpo que se va por la herida: el color se escapa un instante.
	if _vitals.body < _last_body and _vitals.bleeding:
		_drain = 1.0
	_last_body = _vitals.body


func _on_item_used(item: ItemDef) -> void:
	var bandage: bool = false
	var soothing: bool = false
	for effect: ItemEffect in item.use_effects:
		var heal: HealEffect = effect as HealEffect
		if heal == null:
			continue
		if heal.stops_bleeding:
			bandage = true
		elif heal.body > 0 or heal.mind > 0:
			soothing = true
	if bandage:
		_heal_time = 0.0
		_heal_strength = 1.0
		_relief = 1.0
		_play(SOUND_RELIEF, -8.0)
	elif soothing:
		_heal_time = 0.0
		_heal_strength = 0.45
		_calm = 1.0


func _hurt_target() -> float:
	return clampf((HURT_FROM - _vitals.body) / (HURT_FROM - HURT_FULL), 0.0, 1.0)


func _unease_target() -> float:
	return clampf((UNEASE_FROM - _vitals.mind) / UNEASE_RANGE, 0.0, 1.0)


## Latido doble (lub-dub) más rápido cuanto peor está.
func _update_heart(delta: float) -> void:
	var stress: float = maxf(_hurt, _bleed * 0.6)
	if stress <= 0.01:
		_pulse = 0.0
		return
	var bpm: float = lerpf(BPM_CALM, BPM_HURT, stress)
	_beat_phase += delta * bpm / 60.0
	if _beat_phase >= 1.0:
		_beat_phase -= 1.0
		_beats += 1
		if stress > 0.55 and _beats % 2 == 0:
			_play(SOUND_HEARTBEAT, lerpf(-20.0, -10.0, stress))
	var p: float = _beat_phase
	_pulse = exp(-p * 14.0) + (0.6 * exp(-(p - 0.2) * 16.0) if p > 0.2 else 0.0)
	_pulse = clampf(_pulse, 0.0, 1.0)


func _apply() -> void:
	if _material == null:
		return
	var strength: float = lerpf(0.55, 1.0, Settings.vhs)
	_material.set_shader_parameter(&"hurt", hurt_level() * strength)
	_material.set_shader_parameter(&"bleed", bleed_level() * strength)
	_material.set_shader_parameter(&"pulse", _pulse)
	_material.set_shader_parameter(&"drain", _drain * strength)
	_material.set_shader_parameter(&"unease", _unease * strength)
	_material.set_shader_parameter(&"calm", _calm * strength)
	var heal_progress: float = clampf(_heal_time / HEAL_TIME, 0.0, 1.0) if _heal_time >= 0.0 else 0.0
	_material.set_shader_parameter(&"heal", heal_progress)
	_material.set_shader_parameter(&"heal_strength", _heal_strength * (1.0 - heal_progress) if _heal_time >= 0.0 else 0.0)
	# Sin nada que mostrar, el rectángulo no se dibuja (no copia la pantalla).
	_rect.visible = hurt_level() > 0.005 or bleed_level() > 0.005 or _unease > 0.005 or _calm > 0.0 or _heal_time >= 0.0


func _apply_debug_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		match pair[0]:
			"body":
				_vitals.body = pair[1].to_int()
			"mind":
				_vitals.mind = pair[1].to_int()
			"bleed":
				_vitals.bleeding = true
			"use":
				# Lo usa de verdad (tiene que estar en la custodia: --give=venda).
				var parts: PackedStringArray = pair[1].split("@")
				var id: StringName = StringName(parts[0])
				get_tree().create_timer(parts[1].to_float() if parts.size() > 1 else 1.0).timeout.connect(func() -> void:
					var stack: ItemStack = GameState.character.custody.find_first(id)
					if stack != null:
						GameState.character.use_item(stack))
	_last_body = _vitals.body


func _play(sound: String, volume_db: float) -> void:
	if ResourceLoader.exists(Sfx.DIR + sound + ".wav"):
		Sfx.ui(self, sound, volume_db)
