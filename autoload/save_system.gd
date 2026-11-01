extends Node
## Guarda y carga la partida en JSON (`user://saves/slot_N.json`).

const SAVE_DIR: String = "user://saves"


func slot_path(slot: int) -> String:
	return SAVE_DIR.path_join("slot_%d.json" % slot)


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func save_game(slot: int = 0) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file: FileAccess = FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("No se pudo guardar: %s" % error_string(FileAccess.get_open_error()))
		return false
	var data: Dictionary = GameState.to_dict()
	data["saved_at"] = Time.get_datetime_string_from_system()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	EventBus.game_saved.emit()
	return true


func load_game(slot: int = 0) -> bool:
	if not has_save(slot):
		return false
	var text: String = FileAccess.get_file_as_string(slot_path(slot))
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Partida guardada dañada: %s" % slot_path(slot))
		return false
	GameState.from_dict(data)
	EventBus.game_loaded.emit()
	return true


## Resumen para el menú (fecha y tiempo jugado), o {} si no hay partida.
func describe(slot: int = 0) -> Dictionary:
	if not has_save(slot):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return {"saved_at": data.get("saved_at", ""), "play_time": float(data.get("play_time", 0.0))}


func delete_save(slot: int = 0) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(slot_path(slot))
