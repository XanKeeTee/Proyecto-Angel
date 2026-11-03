class_name CustodyWorldLink
extends Node
## Lleva al mundo lo que pasa en la custodia:
## - **Objetos descartados**: aparecen a los pies del jugador como `DroppedItem` recogibles y se
##   guardan con la partida (en `GameState.objects["dropped_items"]`, por escena).
## - **Arma empuñada**: se dibuja en la mano del jugador (`Player.set_held_weapon`, si existe).
## - **Sonidos de uso** (`EventBus.item_used`): pilas, vendas, pastillas, jeringa…
## Lo crea `WorldController._build_ui` con una línea.

const STATE_KEY: StringName = &"dropped_items"

var world: WorldController

var _nodes: Dictionary[String, DroppedItem] = {}


static func create(owner_world: WorldController) -> CustodyWorldLink:
	var link: CustodyWorldLink = CustodyWorldLink.new()
	link.name = "CustodyWorldLink"
	link.world = owner_world
	return link


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.item_discarded.connect(_on_discarded)
	EventBus.item_used.connect(_on_item_used)
	# Espera a que el mapa esté listo (el controlador indexa los objetos al final de su _ready).
	_restore.call_deferred()


func _exit_tree() -> void:
	if EventBus.item_discarded.is_connected(_on_discarded):
		EventBus.item_discarded.disconnect(_on_discarded)
	if EventBus.item_used.is_connected(_on_item_used):
		EventBus.item_used.disconnect(_on_item_used)


## Objetos sueltos guardados (todas las escenas): [{uid, scene, x, y, stack}].
static func saved_entries() -> Array:
	return GameState.object_state(STATE_KEY).get("items", [])


## Deja un montón en el suelo en `pos` de esta escena. Devuelve el nodo creado.
func drop(stack: ItemStack, pos: Vector2) -> DroppedItem:
	var uid: String = "%d_%d" % [Time.get_ticks_usec(), randi() % 10000]
	var entries: Array = saved_entries().duplicate(true)
	entries.append({"uid": uid, "scene": _scene(), "x": pos.x, "y": pos.y, "stack": stack.to_dict()})
	_save(entries)
	return _spawn(uid, stack, pos)


func _on_discarded(stack: ItemStack) -> void:
	if world == null or world.player == null:
		return
	# A los pies, con un poco de desorden para que dos objetos no queden uno encima de otro.
	var offset: Vector2 = Vector2(randf_range(-6.0, 6.0), randf_range(2.0, 8.0))
	drop(stack, world.player.position + offset)
	ItemSounds.play(self, stack.def, ItemSounds.Action.DISCARD, -4.0)


func _on_item_used(item: ItemDef) -> void:
	ItemSounds.play(self, item, ItemSounds.Action.USE, -4.0)


## Sincroniza el arma en la mano del jugador (contrato con el agente del personaje).
func sync_weapon() -> void:
	if world == null or world.player == null or not world.player.has_method(&"set_held_weapon"):
		return
	var stack: ItemStack = GameState.character.wielded()
	world.player.call(&"set_held_weapon", stack.def.icon if stack != null else null)


func _on_weapon_changed(_stack: ItemStack) -> void:
	sync_weapon()


func _restore() -> void:
	if world == null:
		return
	GameState.character.weapon_changed.connect(_on_weapon_changed)
	sync_weapon()
	for entry: Variant in saved_entries():
		var e: Dictionary = entry
		if String(e.get("scene", "")) != _scene():
			continue
		var stack: ItemStack = ItemStack.from_dict(e.get("stack", {}))
		if stack != null:
			_spawn(String(e["uid"]), stack, Vector2(float(e.get("x", 0.0)), float(e.get("y", 0.0))))
	# Depuración (capturas): --drop=id,id deja esos objetos en el suelo junto al jugador.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--drop="):
			for id: String in arg.trim_prefix("--drop=").split(","):
				var def: ItemDef = Registry.item(StringName(id))
				if def != null and world.player != null:
					drop(ItemStack.create(def, 1), world.player.position + Vector2(20 + randf_range(-4, 4), 6))


func _spawn(uid: String, stack: ItemStack, pos: Vector2) -> DroppedItem:
	var node: DroppedItem = DroppedItem.create(stack, pos, uid)
	node.picked_up.connect(_on_picked_up)
	var parent: Node = world.get_node_or_null(^"%World") if world != null else null
	(parent if parent != null else self).add_child(node)
	_nodes[uid] = node
	if world != null:
		world.reindex()
	return node


func _on_picked_up(node: DroppedItem) -> void:
	var entries: Array = saved_entries().duplicate(true)
	for i: int in range(entries.size() - 1, -1, -1):
		if String(entries[i].get("uid", "")) != node.uid:
			continue
		if node.stack.quantity <= 0:
			entries.remove_at(i)
		else:
			entries[i]["stack"] = node.stack.to_dict()
	_save(entries)
	if node.stack.quantity <= 0:
		_nodes.erase(node.uid)
		node.queue_free.call_deferred()
		if world != null:
			world.reindex.call_deferred()


func _save(entries: Array) -> void:
	GameState.save_object_state(STATE_KEY, {"items": entries})


func _scene() -> String:
	return world.scene_file_path if world != null else ""
