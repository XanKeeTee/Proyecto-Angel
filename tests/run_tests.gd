extends SceneTree
## Ejecuta todas las pruebas de tests/unit y tests/integration sin ventana.
## Uso: "$GODOT_BIN" --headless --path . -s tests/run_tests.gd
## Sale con código 0 si todo pasa y 1 si algo falla.

const DIRS: Array[String] = ["res://tests/unit", "res://tests/integration"]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var total: int = 0
	var failed: PackedStringArray = []
	for dir: String in DIRS:
		for file: String in ResourceLoader.list_directory(dir):
			if not (file.begins_with("test_") and file.ends_with(".gd")):
				continue
			var script: GDScript = load(dir.path_join(file))
			var case: TestCase = script.new()
			for method: Dictionary in script.get_script_method_list():
				var name: String = method["name"]
				if not name.begins_with("test_"):
					continue
				total += 1
				case.current = "%s · %s" % [file.get_basename(), name]
				var before: int = case.failures.size()
				var result: Variant = case.call(name)
				if result is Signal:
					await result
				if case.failures.size() > before:
					print("FALLA  ", case.current)
				else:
					print("ok     ", case.current)
			failed.append_array(case.failures)
	print("")
	for f: String in failed:
		print("  - ", f)
	print("%d pruebas, %d fallos" % [total, failed.size()])
	quit(0 if failed.is_empty() else 1)
