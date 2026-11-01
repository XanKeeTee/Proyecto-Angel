class_name Interactable
extends Node2D
## Algo del mundo con lo que se puede interactuar. Todo se configura en el inspector:
## qué es, en qué estado empieza, qué tiene dentro, qué llave pide, qué objetos se pueden
## usar sobre él, qué textos muestra y qué banderas activa.
##
## Estados: cerrado / abierto, bloqueado, registrado, vacío e inspeccionado.
## Se guardan en GameState por `object_id`, así que un cajón abierto sigue abierto
## y lo recogido no reaparece.
##
## La posición del nodo es el centro de su casilla base; `footprint` son las casillas que
## ocupa, relativas a esa base.

signal state_changed

enum Kind {
	FIXTURE,  ## Solo se examina (ventanas, carteles, máquinas sin uso…).
	CONTAINER,  ## Se abre o se registra y puede tener cosas dentro.
	PICKUP,  ## Un objeto suelto que se recoge.
	READABLE,  ## Un documento que se lee (y pasa al expediente).
	DEVICE,  ## Se acciona (interruptor, teléfono, grabadora…).
}

const TILE_SIZE: int = 32
const ACT_EXAMINE: StringName = &"examine"
const ACT_OPEN: StringName = &"open"
const ACT_CLOSE: StringName = &"close"
const ACT_SEARCH: StringName = &"search"
const ACT_TAKE: StringName = &"take"
const ACT_READ: StringName = &"read"
const ACT_UNLOCK: StringName = &"unlock"
const ACT_DEVICE: StringName = &"device"
const ACT_ITEM_PREFIX: String = "item:"

## Identificador único y estable: es la clave del guardado. No lo cambies una vez publicado.
@export var object_id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.FIXTURE
## Casillas que ocupa, relativas a la base.
@export var footprint: Array[Vector2i] = [Vector2i.ZERO]
## Si impide el paso (la escena crea su colisión).
@export var blocks: bool = true

@export_group("Textos")
@export_multiline var examine_text: String = ""
## Al examinarlo abierto (vacío = el normal).
@export_multiline var examine_open_text: String = ""
## Al examinarlo ya registrado o vacío (vacío = el normal).
@export_multiline var examine_done_text: String = ""
## Al abrirlo o registrarlo, antes de decir lo que hay.
@export_multiline var search_text: String = ""
@export_multiline var empty_text: String = "No hay nada."
@export_multiline var locked_text: String = "Está cerrado con llave."
@export_multiline var unlock_text: String = ""
## Si falta `requires_flag`.
@export_multiline var blocked_text: String = ""
## Verbo de registrar para cosas que no se abren ("Registrar", "Mirar debajo"…).
@export var search_verb: String = "Registrar"

@export_group("Estado inicial")
@export var openable: bool = false
@export var start_open: bool = false
@export var start_locked: bool = false
@export var key_item: ItemDef
## La llave se queda puesta (y deja de ocupar sitio).
@export var consume_key: bool = true
## Bandera necesaria para abrir o accionar (p. ej. "power_on").
@export var requires_flag: StringName = &""

@export_group("Contenido")
@export var contents: Array[LootEntry] = []
## Para READABLE: el documento que se lee.
@export var document: DocumentDef
## Para PICKUP: el objeto suelto.
@export var pickup_item: ItemDef
@export var pickup_quantity: int = 1

@export_group("Usos")
@export var item_uses: Array[ItemUse] = []
## Para DEVICE: texto del botón y lo que pasa.
@export var device_label: String = "Usar"
@export_multiline var device_text: String = ""
@export var device_once: bool = false
## Evento que gestiona la escena al accionarlo (grabadora, teléfono…).
@export var device_special: StringName = &""

@export_group("Banderas")
@export var flag_on_open: StringName = &""
@export var flag_on_search: StringName = &""
@export var flag_on_examine: StringName = &""

@export_group("Inspección")
## Vistas giradas para examinar desde varios ángulos (opcional).
@export var inspect_sheet: Texture2D
@export var inspect_views: int = 1

@export_group("Aspecto")
@export var frame_closed: int = 0
@export var frame_open: int = 1
@export var frame_empty: int = -1
## Al recogerlo (PICKUP) o cuando la escena lo retire, desaparece.
@export var hide_when_taken: bool = true

@export_group("Sonido")
@export var sound_open: AudioStream
@export var sound_close: AudioStream
@export var sound_locked: AudioStream
@export var sound_take: AudioStream

var is_open: bool = false
var is_locked: bool = false
var searched: bool = false
var inspected: bool = false
var taken: bool = false
var device_used: bool = false
var uses_done: Array[int] = []
## Cantidades que quedan de cada entrada de `contents` (por índice).
var remaining: Array[int] = []

@onready var _sprite: Sprite2D = get_node_or_null(^"Sprite2D") as Sprite2D


func _ready() -> void:
	is_open = start_open
	is_locked = start_locked
	remaining.clear()
	for entry: LootEntry in contents:
		remaining.append(entry.quantity if entry.item != null else 1)
	_load_state()
	_apply_visuals()


# --- consulta ------------------------------------------------------------------------------

func base_cell() -> Vector2i:
	return Vector2i(floori(position.x / TILE_SIZE), floori(position.y / TILE_SIZE))


func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in footprint:
		result.append(base_cell() + offset)
	return result


func is_empty() -> bool:
	for amount: int in remaining:
		if amount > 0:
			return false
	return true


func is_active() -> bool:
	return not (taken and hide_when_taken)


## Estado legible (para depurar y para el texto de examinar).
func state_name() -> String:
	if is_locked:
		return "Bloqueado"
	if openable and not is_open:
		return "Cerrado"
	if searched and is_empty():
		return "Vacío"
	if searched:
		return "Registrado"
	if openable and is_open:
		return "Abierto"
	return "Inspeccionado" if inspected else ""


## Acciones disponibles ahora, la principal primero: [{id, label}].
func get_actions(character: CharacterState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if not is_active():
		return actions
	for i: int in item_uses.size():
		var use: ItemUse = item_uses[i]
		if uses_done.has(i) or not character.custody.has(use.item.id):
			continue
		if not _flags_ok(use.requires_flags):
			continue
		actions.append({"id": StringName(ACT_ITEM_PREFIX + str(i)), "label": use.action_label()})
	match kind:
		Kind.READABLE:
			actions.append({"id": ACT_READ, "label": "Leer"})
		Kind.PICKUP:
			actions.append({"id": ACT_TAKE, "label": "Recoger"})
		Kind.DEVICE:
			if not (device_once and device_used):
				actions.append({"id": ACT_DEVICE, "label": device_label})
		Kind.CONTAINER:
			_container_actions(actions, character)
	return actions


func primary_action(character: CharacterState) -> Dictionary:
	var actions: Array[Dictionary] = get_actions(character)
	return actions[0] if not actions.is_empty() else {}


# --- acciones ---------------------------------------------------------------------------------

func perform(action: StringName, character: CharacterState) -> InteractionResult:
	var result: InteractionResult = InteractionResult.new()
	var text: String = String(action)
	if text.begins_with(ACT_ITEM_PREFIX):
		_use_item(int(text.trim_prefix(ACT_ITEM_PREFIX)), character, result)
	else:
		match action:
			ACT_EXAMINE: _examine(result)
			ACT_OPEN: _open(result, character)
			ACT_UNLOCK: _unlock(result, character)
			ACT_CLOSE: _close(result)
			ACT_SEARCH, ACT_TAKE: _search(result)
			ACT_READ: _read(result)
			ACT_DEVICE: _device(result)
	_save_state()
	_apply_visuals()
	state_changed.emit()
	return result


## Cambia el estado desde fuera (eventos: una puerta que se cierra sola, un objeto que desaparece…).
func force_state(open: bool, locked: bool = false) -> void:
	is_open = open
	is_locked = locked
	_save_state()
	_apply_visuals()
	state_changed.emit()


func remove_from_world() -> void:
	taken = true
	hide_when_taken = true
	_save_state()
	_apply_visuals()
	state_changed.emit()


func _container_actions(actions: Array[Dictionary], character: CharacterState) -> void:
	if openable:
		if is_locked:
			if key_item != null and character.custody.has(key_item.id):
				actions.append({"id": ACT_UNLOCK, "label": "Abrir con " + key_item.display_name.to_lower()})
			else:
				actions.append({"id": ACT_OPEN, "label": "Abrir"})
		elif not is_open:
			actions.append({"id": ACT_OPEN, "label": "Abrir"})
		elif not is_empty():
			actions.append({"id": ACT_SEARCH, "label": "Coger"})
		else:
			actions.append({"id": ACT_CLOSE, "label": "Cerrar"})
	elif not searched:
		actions.append({"id": ACT_SEARCH, "label": search_verb})
	elif not is_empty():
		actions.append({"id": ACT_SEARCH, "label": "Coger"})


func _examine(result: InteractionResult) -> void:
	var text: String = examine_text
	if openable and is_open and examine_open_text != "":
		text = examine_open_text
	if searched and is_empty() and examine_done_text != "":
		text = examine_done_text
	result.add(text if text != "" else display_name + ".")
	if inspect_sheet != null:
		result.inspect_sheet = inspect_sheet
		result.inspect_views = inspect_views
		result.inspect_title = display_name
	inspected = true
	_set_flag(flag_on_examine)


func _open(result: InteractionResult, character: CharacterState) -> void:
	if is_locked:
		result.add(locked_text)
		result.sound = sound_locked
		return
	if not _flags_ok([requires_flag]):
		result.add(blocked_text if blocked_text != "" else locked_text)
		result.sound = sound_locked
		return
	is_open = true
	result.sound = sound_open
	_set_flag(flag_on_open)
	if kind == Kind.CONTAINER:
		_search(result)


func _unlock(result: InteractionResult, character: CharacterState) -> void:
	if key_item == null or not character.custody.has(key_item.id):
		_open(result, character)
		return
	is_locked = false
	if consume_key:
		character.custody.take(key_item.id)
	result.add(unlock_text if unlock_text != "" else "La llave gira. Se abre.")
	_open(result, character)


func _close(result: InteractionResult) -> void:
	is_open = false
	result.sound = sound_close


func _search(result: InteractionResult) -> void:
	var first_time: bool = not searched
	searched = true
	_set_flag(flag_on_search)
	if first_time:
		result.add(search_text)
	if is_empty():
		if first_time or kind != Kind.PICKUP:
			result.add(empty_text)
		return
	var gained: PackedStringArray = []
	for i: int in contents.size():
		if remaining[i] <= 0:
			continue
		var entry: LootEntry = contents[i]
		if entry.text != "" and first_time:
			result.add(entry.text)
		if entry.document != null:
			GameState.give_document(entry.document)
			remaining[i] = 0
			gained.append("Expediente: " + entry.document.title)
			continue
		var left: int = GameState.give_item(entry.item, remaining[i])
		var got: int = remaining[i] - left
		remaining[i] = left
		if got > 0:
			gained.append("Coges: " + entry.item.display_name + (" ×%d" % got if got > 1 else ""))
		if left > 0:
			gained.append("No te cabe en la bandeja: " + entry.item.display_name + ". Haz sitio y vuelve.")
	if not gained.is_empty():
		result.add("\n".join(gained))
		result.sound = sound_take if sound_take != null else result.sound
	if kind == Kind.PICKUP and is_empty():
		taken = true


func _read(result: InteractionResult) -> void:
	inspected = true
	if document != null:
		GameState.give_document(document)
		result.read_document = document
	result.add(search_text)


func _device(result: InteractionResult) -> void:
	if not _flags_ok([requires_flag]):
		result.add(blocked_text)
		result.sound = sound_locked
		return
	device_used = true
	result.add(device_text)
	result.special = device_special
	result.sound = sound_open
	_set_flag(flag_on_open)


func _use_item(index: int, character: CharacterState, result: InteractionResult) -> void:
	var use: ItemUse = item_uses[index]
	var stack: ItemStack = character.custody.find_first(use.item.id)
	if stack == null:
		return
	uses_done.append(index)
	if use.consumes_item:
		character.custody.consume(stack)
	elif use.uses_durability:
		character.custody.consume(stack, true)
	if use.unlocks:
		is_locked = false
	if use.opens:
		is_locked = false
		is_open = true
		result.sound = sound_open
	result.add(use.text)
	_set_flag(use.sets_flag)
	if use.frame_after >= 0 and _sprite != null:
		frame_open = use.frame_after
		frame_closed = use.frame_after
	if use.opens and kind == Kind.CONTAINER:
		_search(result)


# --- estado y guardado ---------------------------------------------------------------------------

func _flags_ok(flags: Array[StringName]) -> bool:
	for flag: StringName in flags:
		if flag != &"" and not GameState.has_flag(flag):
			return false
	return true


func _set_flag(flag: StringName) -> void:
	if flag != &"":
		GameState.set_flag(flag)


func _save_state() -> void:
	GameState.save_object_state(object_id, {
		"open": is_open, "locked": is_locked, "searched": searched, "inspected": inspected,
		"taken": taken, "device": device_used, "uses": uses_done.duplicate(), "remaining": remaining.duplicate(),
		"frames": [frame_closed, frame_open],
	})


func _load_state() -> void:
	var s: Dictionary = GameState.object_state(object_id)
	if s.is_empty():
		return
	is_open = s.get("open", is_open)
	is_locked = s.get("locked", is_locked)
	searched = s.get("searched", false)
	inspected = s.get("inspected", false)
	taken = s.get("taken", false)
	device_used = s.get("device", false)
	uses_done.clear()
	for u: Variant in s.get("uses", []):
		uses_done.append(int(u))
	var saved: Array = s.get("remaining", [])
	for i: int in mini(saved.size(), remaining.size()):
		remaining[i] = int(saved[i])
	var frames: Array = s.get("frames", [frame_closed, frame_open])
	frame_closed = int(frames[0])
	frame_open = int(frames[1])


func _apply_visuals() -> void:
	visible = is_active()
	if _sprite == null:
		return
	var frame: int = frame_open if (openable and is_open) else frame_closed
	if frame_empty >= 0 and searched and is_empty():
		frame = frame_empty
	if frame >= 0 and frame < _sprite.hframes * _sprite.vframes:
		_sprite.frame = frame
