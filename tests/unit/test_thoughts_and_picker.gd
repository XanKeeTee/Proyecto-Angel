extends TestCase
## Pensamientos (objetivo actual) y elección del objeto con el que se interactúa.

const THOUGHTS: String = "res://data/thoughts/prologo.tres"


func _query(flags: Array, items: Array) -> Array[Callable]:
	var has_flag: Callable = func(f: StringName) -> bool: return flags.has(String(f))
	var has_item: Callable = func(i: StringName) -> bool: return items.has(String(i))
	return [has_flag, has_item]


func _text(thought_set: ThoughtSet, flags: Array, items: Array = []) -> String:
	var q: Array[Callable] = _query(flags, items)
	return thought_set.current_text(q[0], q[1])


func test_pensamientos_siguen_la_cadena() -> void:
	var thoughts: ThoughtSet = load(THOUGHTS)
	var seen: PackedStringArray = []
	var steps: Array = [
		[[], []],
		[["linterna_cogida"], []],
		[["linterna_cogida", "quirofano_atascado"], []],
		[["linterna_cogida", "quirofano_atascado"], ["palanca"]],
		[["linterna_cogida", "quirofano_abierto", "oyo_crujido"], ["destornillador"]],
		[["linterna_cogida", "quirofano_abierto", "oyo_crujido", "llave_botiquin_cogida"], ["destornillador", "llave_botiquin"]],
		[["linterna_cogida", "quirofano_abierto", "llave_botiquin_cogida", "llave_archivo_cogida"], ["destornillador", "llave_archivo"]],
		[["llave_archivo_cogida", "archivo_abierto"], ["destornillador"]],
		[["llave_archivo_cogida", "archivo_abierto", "fusible_cogido"], ["destornillador", "fusible", "llave_sotano"]],
		[["fusible_cogido", "escalera_abierta"], ["destornillador", "fusible"]],
		[["fusible_cogido", "escalera_abierta", "event:puntos_abiertos"], ["destornillador", "fusible"]],
		[["fusible_cogido", "event:puntos_abiertos", "panel_abierto"], ["destornillador", "fusible"]],
		[["fusible_cogido", "event:puntos_abiertos", "panel_abierto", "panel_reparado"], ["destornillador", "fusible"]],
		[["event:puntos_abiertos", "panel_abierto", "panel_reparado", "fusible_puesto"], ["destornillador"]],
		[["event:puntos_abiertos", "panel_reparado", "fusible_puesto"], ["destornillador", "valvula_averiada"]],
		[["event:puntos_abiertos", "panel_reparado", "fusible_puesto"], ["valvula_reparada"]],
		[["event:puntos_abiertos", "fusible_puesto", "valvula_puesta"], []],
		[["fusible_puesto", "valvula_puesta", "power_on", "pasillo_imposible"], []],
	]
	for step: Array in steps:
		var text: String = _text(thoughts, step[0], step[1])
		check(text != "" and text != thoughts.fallback, "hay pensamiento para %s / %s" % [str(step[0]), str(step[1])])
		check(not seen.has(text), "cada paso cambia el pensamiento: " + text.left(40))
		seen.append(text)


func test_elige_por_cercania_y_mirada() -> void:
	var left: Interactable = Interactable.new()
	left.position = Vector2(2 * 32 + 16, 5 * 32 + 16)
	var up: Interactable = Interactable.new()
	up.position = Vector2(3 * 32 + 16, 4 * 32 + 16)
	var far: Interactable = Interactable.new()
	far.position = Vector2(3 * 32 + 16, 8 * 32 + 16)
	var feet: Vector2 = Vector2(3 * 32 + 16, 5 * 32 + 16)
	var all: Array = [left, up, far]
	check(InteractionPicker.pick(all, feet, -PI / 2.0) == up, "mirando arriba, el de arriba")
	check(InteractionPicker.pick(all, feet, PI) == left, "mirando a la izquierda, el de la izquierda")
	check(InteractionPicker.pick(all, feet, PI / 2.0) == null, "abajo no hay nada al alcance")
	check(InteractionPicker.pick(all, feet, -PI / 2.0 - 0.3) == up, "en diagonal gana el más alineado")
	check(InteractionPicker.pick(all, feet, PI - 0.5) == left, "y al revés")
	for it: Interactable in [left, up, far]:
		it.free()
