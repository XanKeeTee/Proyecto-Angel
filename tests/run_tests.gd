extends Node
## Ejecuta todas las pruebas de tests/unit y tests/integration sin ventana.
## Uso: "$GODOT_BIN" --headless --path . res://tests/run_tests.tscn
## Sale con código 0 si todo pasa y 1 si algo falla.

const DIRS: Array[String] = ["res://tests/unit", "res://tests/integration"]


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	var total: int = 0
	var failed: PackedStringArray = []
	for dir: String in DIRS:
		for file: String in ResourceLoader.list_directory(dir):
			if not (file.begins_with("test_") and file.ends_with(".gd")):
				continue
			var script: GDScript = load(dir.path_join(file))
			var case: TestCase = script.new()
			case.host = self
			for method: Dictionary in script.get_script_method_list():
				var name: String = method["name"]
				if not name.begins_with("test_"):
					continue
				total += 1
				case.current = "%s · %s" % [file.get_basename(), name]
				var before: int = case.failures.size()
				var started: int = Time.get_ticks_msec()
				await case.call(name)
				var ms: int = Time.get_ticks_msec() - started
				if case.failures.size() > before:
					print("FALLA  ", case.current)
				else:
					print("ok     ", case.current, "  (%d ms)" % ms if ms > 200 else "")
			failed.append_array(case.failures)
	print("")
	for f: String in failed:
		print("  - ", f)
	print("%d pruebas, %d fallos" % [total, failed.size()])
	# Deja terminar sonidos y esperas pendientes de las escenas liberadas antes de salir.
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if failed.is_empty() else 1)
