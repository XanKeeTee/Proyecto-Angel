extends TestCase
## Botín aleatorio: la tirada es determinista con la semilla, respeta lo fijo y el reparto.

const PLAN: String = "res://data/loot/prologo.tres"
const CLOTHES: Array[StringName] = [&"zapatillas", &"gorro_lana", &"pantalon_pijama", &"gorro_quirurgico",
	&"bata_medico", &"chaqueta_celador", &"pantalon_celador", &"botas_goma"]


func _item(id: String) -> ItemDef:
	return Registry.item(StringName(id))


func _ids(result: Dictionary) -> Dictionary:
	var flat: Dictionary = {}
	for id: Variant in result:
		var list: Array = []
		for got: Dictionary in result[id]:
			list.append([(got["item"] as ItemDef).id, got["quantity"]])
		flat[id] = list
	return flat


func test_misma_semilla_mismo_botin() -> void:
	var plan: LootPlan = load(PLAN)
	check_eq(_ids(LootRoller.roll(plan, 1234)), _ids(LootRoller.roll(plan, 1234)), "misma semilla, mismo resultado")
	var different: bool = false
	for s: int in [1, 2, 3, 4, 5]:
		if _ids(LootRoller.roll(plan, s)) != _ids(LootRoller.roll(plan, 1234)):
			different = true
	check(different, "otra semilla cambia el reparto")


func test_reparto_garantizado_y_ropa_escasa() -> void:
	var plan: LootPlan = load(PLAN)
	var clothes_total: int = 0
	for s: int in 200:
		var result: Dictionary = LootRoller.roll(plan, s)
		var pilas: int = LootRoller.total(result, &"pilas")
		check(pilas >= 5 and pilas <= 12, "pilas entre 5 y 12 (semilla %d: %d)" % [s, pilas])
		check(LootRoller.total(result, &"venda") >= 2, "al menos dos vendas (semilla %d)" % s)
		for id: StringName in CLOTHES:
			var n: int = LootRoller.total(result, id)
			check(n <= 1, "cada prenda como mucho una vez (%s, semilla %d)" % [id, s])
			clothes_total += n
		# Nada del camino principal sale de las tablas.
		for fixed: StringName in plan.fixed_items:
			check_eq(LootRoller.total(result, fixed), 0, "lo fijo no se tira: " + fixed)
		# Todo cae en muebles del plan.
		for id: Variant in result:
			check(plan.slot(StringName(id)) != null, "mueble fuera del plan: " + str(id))
	var average: float = clothes_total / 200.0
	check(average > 2.5 and average < 6.0, "ropa: unas 4 prendas por partida (media %.2f)" % average)


func test_aplicar_respeta_lo_fijo() -> void:
	GameState.new_game()
	var plan: LootPlan = load(PLAN)
	var drawer: Interactable = Interactable.new()
	drawer.object_id = &"t_botin"
	drawer.kind = Interactable.Kind.CONTAINER
	var key: LootEntry = LootEntry.new()
	key.item = _item("llave_archivo")
	var lever: LootEntry = LootEntry.new()
	lever.item = _item("palanca")
	var doc: LootEntry = LootEntry.new()
	doc.document = Registry.document(&"circular_9")
	var loose: LootEntry = LootEntry.new()
	loose.item = _item("pilas")
	loose.quantity = 2
	drawer.contents = [key, lever, doc, loose]
	host.add_child(drawer)
	var extra: LootEntry = LootEntry.new()
	extra.item = _item("venda")
	drawer.replace_contents(plan.keeps, [extra])
	var ids: Array[StringName] = []
	for e: LootEntry in drawer.contents:
		ids.append(e.item.id if e.item != null else &"doc")
	check_eq(ids, [&"llave_archivo", &"palanca", &"doc", &"venda"] as Array[StringName], "quita lo suelto y conserva lo fijo")
	check_eq(drawer.remaining.size(), 4, "cantidades recalculadas")
	drawer.perform(Interactable.ACT_SEARCH, GameState.character)
	check(GameState.character.custody.has(&"venda") and not GameState.character.custody.has(&"pilas"), "se coge lo nuevo")
	drawer.queue_free()
	# Al recrearlo (como al cargar) con el mismo resultado, sigue vacío.
	var again: Interactable = Interactable.new()
	again.object_id = &"t_botin"
	again.kind = Interactable.Kind.CONTAINER
	again.contents = [key, lever, doc, loose]
	host.add_child(again)
	again.replace_contents(plan.keeps, [extra])
	check(again.is_empty(), "lo recogido no reaparece al cargar")
	again.queue_free()
