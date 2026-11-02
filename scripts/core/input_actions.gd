class_name InputActions
extends RefCounted
## Acciones de juego con teclado y mando. Se registran al arrancar (GameState._ready),
## así no dependen de editar el mapa de entrada a mano.

const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const MOVE_UP: StringName = &"move_up"
const MOVE_DOWN: StringName = &"move_down"
const INTERACT: StringName = &"interact"
const EXAMINE: StringName = &"examine"
const FLASHLIGHT: StringName = &"flashlight"
const CUSTODY: StringName = &"custody"
const PAUSE: StringName = &"pause"
## Pensar: lo que el protagonista sabe que tiene que hacer ahora.
const THOUGHTS: StringName = &"thoughts"
const POCKETS: Array[StringName] = [&"pocket_1", &"pocket_2", &"pocket_3", &"pocket_4", &"pocket_5"]


static func setup() -> void:
	_action(MOVE_LEFT, [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_action(MOVE_RIGHT, [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_action(MOVE_UP, [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_action(MOVE_DOWN, [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_action(INTERACT, [KEY_E, KEY_ENTER, KEY_SPACE], [JOY_BUTTON_A])
	_action(EXAMINE, [KEY_R], [JOY_BUTTON_X])
	_action(FLASHLIGHT, [KEY_F], [JOY_BUTTON_Y])
	_action(CUSTODY, [KEY_TAB, KEY_I], [JOY_BUTTON_BACK])
	_action(PAUSE, [KEY_ESCAPE], [JOY_BUTTON_START])
	_action(THOUGHTS, [KEY_T], [JOY_BUTTON_LEFT_SHOULDER])
	var keys: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
	for i: int in POCKETS.size():
		_action(POCKETS[i], [keys[i]], [])


static func _action(action: StringName, keys: Array, buttons: Array, axis: int = -1, axis_value: float = 0.0) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.35)
	for key: Key in keys:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	for button: JoyButton in buttons:
		var joy: InputEventJoypadButton = InputEventJoypadButton.new()
		joy.button_index = button
		InputMap.action_add_event(action, joy)
	if axis >= 0:
		var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion.axis = axis as JoyAxis
		motion.axis_value = axis_value
		InputMap.action_add_event(action, motion)
