class_name EventDirector
extends Node
## Vigila al jugador y lanza los HorrorEvent cuando se cumplen sus condiciones.
## Lo que ya ha ocurrido se guarda como bandera ("event:<id>"), así no se repite al cargar.

@export var events: Array[HorrorEvent] = []

## Escena del mapa (WorldController): ofrece sonidos, textos, objetos, luces…
var world: WorldController

var _inside: Dictionary[StringName, bool] = {}
var _pending: Dictionary[StringName, bool] = {}


func setup(world_controller: WorldController) -> void:
	world = world_controller
	world.player.cell_entered.connect(_on_cell_entered)
	EventBus.flag_set.connect(_on_flag_set)
	var cell: Vector2i = world.player.cell
	for event: HorrorEvent in events:
		_inside[event.id] = event.region.has_point(cell)


## Lanza un evento a mano (desde guiones de la escena).
func fire(id: StringName) -> void:
	for event: HorrorEvent in events:
		if event.id == id:
			_run(event)


func _on_cell_entered(cell: Vector2i) -> void:
	for event: HorrorEvent in events:
		var was: bool = _inside.get(event.id, false)
		var now: bool = event.region.has_point(cell)
		_inside[event.id] = now
		match event.trigger:
			HorrorEvent.Trigger.ENTER_REGION:
				if now and not was:
					_try(event)
			HorrorEvent.Trigger.LEAVE_REGION:
				if was and not now:
					_try(event)
			HorrorEvent.Trigger.TIMER:
				_try(event)


func _on_flag_set(flag: StringName) -> void:
	for event: HorrorEvent in events:
		if event.trigger == HorrorEvent.Trigger.FLAG and event.trigger_flag == flag:
			_try(event)


func _try(event: HorrorEvent) -> void:
	if _pending.get(event.id, false):
		return
	if event.once and GameState.has_flag(event.done_flag()):
		return
	for flag: StringName in event.requires_flags:
		if not GameState.has_flag(flag):
			return
	for flag: StringName in event.forbids_flags:
		if GameState.has_flag(flag):
			return
	if randf() > event.chance:
		return
	_run(event)


func _run(event: HorrorEvent) -> void:
	_pending[event.id] = true
	if event.once:
		GameState.set_flag(event.done_flag())
	if event.delay > 0.0:
		await get_tree().create_timer(event.delay).timeout
	for action: EventAction in event.actions:
		await action.run(self)
	_pending[event.id] = false
