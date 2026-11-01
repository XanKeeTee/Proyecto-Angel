class_name PoweredLight
extends PointLight2D
## Luz del edificio. Si necesita corriente, está apagada hasta que se activa la bandera
## de corriente (GameState.FLAG_POWER) y se enciende con un arranque de fluorescente.
## Puede parpadear de vez en cuando o estar rota (no se enciende nunca).

const GROUP: StringName = &"powered_lights"

@export var needs_power: bool = true
@export var broken: bool = false
## Probabilidad por segundo de un parpadeo.
@export var flicker_rate: float = 0.08
## Sprite del aplique (fotograma 0 encendido, 1 apagado), opcional.
@export var fixture: Sprite2D

var _base_energy: float = 1.0
var _powered: bool = false
var _flickering: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	_base_energy = energy
	_powered = not needs_power or GameState.has_flag(GameState.FLAG_POWER)
	EventBus.power_changed.connect(_on_power_changed)
	_set_lit(_powered and not broken)


func _process(delta: float) -> void:
	if not enabled or _flickering or flicker_rate <= 0.0:
		return
	if randf() < flicker_rate * delta:
		flicker(randf_range(0.15, 0.6))


## Parpadeo corto (también lo usan los eventos).
func flicker(duration: float) -> void:
	if broken or not _powered or _flickering:
		return
	_flickering = true
	var t: float = 0.0
	while t < duration:
		var wait: float = randf_range(0.03, 0.12)
		_set_lit(randf() < 0.45)
		await get_tree().create_timer(wait).timeout
		t += wait
	_set_lit(_powered and not broken)
	_flickering = false


## Arranque de fluorescente: varios destellos antes de quedarse fija.
func power_up(delay: float = 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	_powered = true
	if broken:
		_set_lit(true)
		await get_tree().create_timer(0.08).timeout
		_set_lit(false)
		return
	await flicker(randf_range(0.4, 1.1))
	_set_lit(true)


func _on_power_changed(on: bool) -> void:
	if on and needs_power and not _powered:
		power_up(randf_range(0.0, 1.2))


func _set_lit(lit: bool) -> void:
	enabled = lit
	energy = _base_energy
	if fixture != null:
		fixture.frame = 0 if lit else 1
