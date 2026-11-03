class_name DroppedItem
extends Interactable
## Un objeto descartado desde la custodia, en el suelo. Se recoge con E (si cabe) y conserva su
## estado (cantidad, desgaste, carga, contaminación). No usa el guardado de `Interactable`:
## lo guarda `CustodyWorldLink` en la lista de objetos sueltos.

## Lo ha recogido el jugador (para que el enlace lo borre de la lista).
signal picked_up(item: DroppedItem)

const ICON_MAX: float = 22.0

## Identificador único del objeto suelto (clave en el guardado).
var uid: String = ""
var stack: ItemStack


## Crea el nodo para `s` en `pos` (posición del mundo). Llama a `add_child` después.
static func create(s: ItemStack, pos: Vector2, id: String) -> DroppedItem:
	var d: DroppedItem = DroppedItem.new()
	d.uid = id
	d.stack = s
	d.name = "Dropped_" + id
	d.object_id = StringName("dropped:" + id)
	d.display_name = s.def.display_name + (" ×%d" % s.quantity if s.quantity > 1 else "")
	d.kind = Kind.PICKUP
	d.blocks = false
	d.examine_text = s.def.description
	d.position = pos
	var shadow: Sprite2D = Sprite2D.new()
	shadow.name = "Shadow"
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = s.def.icon
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if s.def.icon != null:
		var big: float = maxf(s.def.icon.get_width(), s.def.icon.get_height())
		sprite.scale = Vector2.ONE * minf(1.0, ICON_MAX / big)
		shadow.texture = s.def.icon
		shadow.scale = sprite.scale
	# Algo girado, como caído (siempre igual para el mismo objeto).
	sprite.rotation = (float(hash(id) % 100) / 100.0 - 0.5) * 1.2
	shadow.rotation = sprite.rotation
	shadow.position = Vector2(1, 2)
	shadow.modulate = Color(0, 0, 0, 0.55)
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	d.add_child(shadow)
	d.add_child(sprite)
	return d


func get_actions(_character: CharacterState) -> Array[Dictionary]:
	if not is_active():
		return []
	return [{"id": ACT_TAKE, "label": "Recoger"}]


func perform(action: StringName, character: CharacterState) -> InteractionResult:
	var result: InteractionResult = InteractionResult.new()
	if action == ACT_EXAMINE:
		result.add(examine_text if examine_text != "" else display_name + ".")
		return result
	if action != ACT_TAKE or taken:
		return result
	var left: int = character.custody.add_item(stack.def, stack.quantity, stack)
	var got: int = stack.quantity - left
	if got <= 0:
		result.add("No te cabe en la bandeja: " + stack.def.display_name + ". Haz sitio y vuelve.")
		return result
	EventBus.item_received.emit(stack.def, got)
	ItemSounds.play(self, stack.def, ItemSounds.Action.PICK, -4.0)
	stack.quantity = left
	if left > 0:
		display_name = stack.def.display_name + (" ×%d" % left if left > 1 else "")
		result.add("Coges %d. El resto no cabe." % got)
	else:
		taken = true
		_apply_visuals()
	picked_up.emit(self)
	state_changed.emit()
	return result


# El estado lo guarda CustodyWorldLink (lista de objetos sueltos), no GameState.objects[object_id].
func _save_state() -> void:
	pass


func _load_state() -> void:
	pass
