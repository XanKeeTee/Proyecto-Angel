class_name EventActions
extends RefCounted
## Fábrica de acciones de evento para construir eventos por código (generadores).
## Las clases de cada acción están en este mismo directorio.


static func sound(sound_name: String, cell: Vector2i, volume_db: float = 0.0) -> PlaySoundAction:
	var a: PlaySoundAction = PlaySoundAction.new()
	a.sound = sound_name
	a.cell = cell
	a.volume_db = volume_db
	return a


static func message(lines: PackedStringArray) -> MessageAction:
	var a: MessageAction = MessageAction.new()
	a.lines = lines
	return a


static func flag(name: StringName) -> SetFlagAction:
	var a: SetFlagAction = SetFlagAction.new()
	a.flag = name
	return a


static func object_state(object_id: StringName, open: bool, locked: bool = false, remove: bool = false) -> SetObjectAction:
	var a: SetObjectAction = SetObjectAction.new()
	a.object_id = object_id
	a.open = open
	a.locked = locked
	a.remove = remove
	return a


static func move(node_name: String, offset: Vector2, frame: int = -1) -> MoveNodeAction:
	var a: MoveNodeAction = MoveNodeAction.new()
	a.node_name = node_name
	a.offset = offset
	a.frame = frame
	return a


static func visibility(node_name: String, show: bool) -> NodeVisibilityAction:
	var a: NodeVisibilityAction = NodeVisibilityAction.new()
	a.node_name = node_name
	a.visible = show
	return a


static func flicker(region: Rect2i, duration: float) -> FlickerAction:
	var a: FlickerAction = FlickerAction.new()
	a.region = region
	a.duration = duration
	return a


static func glitch(duration: float, strength: float) -> GlitchAction:
	var a: GlitchAction = GlitchAction.new()
	a.duration = duration
	a.strength = strength
	return a


static func mind(amount: int) -> MindAction:
	var a: MindAction = MindAction.new()
	a.amount = amount
	return a


static func wait(seconds: float) -> WaitAction:
	var a: WaitAction = WaitAction.new()
	a.seconds = seconds
	return a


static func bleed(text: PackedStringArray) -> BleedAction:
	var a: BleedAction = BleedAction.new()
	a.lines = text
	return a
