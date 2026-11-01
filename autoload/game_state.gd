extends Node
## Estado persistente de la partida: banderas, estado de los objetos del mundo,
## protagonista activo y posición. SaveSystem lo vuelca a disco.

## Bandera que indica que la corriente del hospital está restablecida.
const FLAG_POWER: StringName = &"power_on"

var flags: Dictionary[StringName, bool] = {}
## Estado de cada objeto interactuable, por `object_id`.
var objects: Dictionary[StringName, Dictionary] = {}
## Protagonistas (preparado para los cinco). Solo uno activo a la vez.
var characters: Dictionary[StringName, CharacterState] = {}
var active_character: StringName = &"paciente_09"
## Dónde estaba el jugador al guardar (escena, celda en píxeles y ángulo).
var player_scene: String = ""
var player_position: Vector2 = Vector2.ZERO
var player_facing: float = PI / 2.0
var has_position: bool = false
## Tiempo jugado en segundos.
var play_time: float = 0.0


func _ready() -> void:
	InputActions.setup()
	new_game()


var character: CharacterState:
	get:
		return characters[active_character]


func new_game() -> void:
	flags.clear()
	objects.clear()
	characters.clear()
	var patient: CharacterState = CharacterState.new()
	characters[patient.id] = patient
	active_character = patient.id
	player_scene = ""
	has_position = false
	play_time = 0.0


# --- banderas -----------------------------------------------------------------------------

func has_flag(flag: StringName) -> bool:
	return flags.get(flag, false)


func set_flag(flag: StringName, value: bool = true) -> void:
	if flag == &"":
		return
	var was: bool = has_flag(flag)
	flags[flag] = value
	if value and not was:
		EventBus.flag_set.emit(flag)
		if flag == FLAG_POWER:
			EventBus.power_changed.emit(true)


# --- objetos del mundo ------------------------------------------------------------------------

func object_state(id: StringName) -> Dictionary:
	return objects.get(id, {})


func save_object_state(id: StringName, state: Dictionary) -> void:
	if id != &"":
		objects[id] = state


# --- objetos y documentos ---------------------------------------------------------------------

## Da objetos al protagonista. Devuelve las unidades que no cupieron.
func give_item(item: ItemDef, amount: int = 1) -> int:
	var left: int = character.custody.add_item(item, amount)
	if amount - left > 0:
		EventBus.item_received.emit(item, amount - left)
	return left


func give_document(doc: DocumentDef) -> bool:
	if doc == null or not character.custody.add_document(doc.id):
		return false
	EventBus.document_received.emit(doc)
	return true


# --- guardado ------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var chars: Dictionary = {}
	for id: StringName in characters:
		chars[String(id)] = characters[id].to_dict()
	var obj: Dictionary = {}
	for id: StringName in objects:
		obj[String(id)] = objects[id]
	var fl: Dictionary = {}
	for f: StringName in flags:
		fl[String(f)] = flags[f]
	return {
		"version": 1, "flags": fl, "objects": obj, "characters": chars,
		"active": String(active_character), "scene": player_scene,
		"position": [player_position.x, player_position.y], "facing": player_facing,
		"play_time": play_time,
	}


func from_dict(data: Dictionary) -> void:
	new_game()
	for f: Variant in data.get("flags", {}):
		flags[StringName(f)] = bool(data["flags"][f])
	for id: Variant in data.get("objects", {}):
		objects[StringName(id)] = data["objects"][id]
	characters.clear()
	for id: Variant in data.get("characters", {}):
		var c: CharacterState = CharacterState.from_dict(data["characters"][id])
		characters[c.id] = c
	if characters.is_empty():
		var patient: CharacterState = CharacterState.new()
		characters[patient.id] = patient
	active_character = StringName(data.get("active", "paciente_09"))
	player_scene = data.get("scene", "")
	var pos: Array = data.get("position", [0, 0])
	player_position = Vector2(float(pos[0]), float(pos[1]))
	player_facing = float(data.get("facing", PI / 2.0))
	has_position = player_scene != ""
	play_time = float(data.get("play_time", 0.0))
