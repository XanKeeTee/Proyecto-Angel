extends TestCase
## Regresión de la pantalla de EQUIPO (antes PERSONAJE): la vista previa del protagonista no debe
## volver a leer las hojas grandes en cada fotograma (bajaba a 5 FPS y salía un rectángulo blanco),
## debe mostrar la ropa puesta y girar sin cargar nada.

const SCENE: String = "res://scenes/world/hospital/hospital.tscn"


## Píxeles distintos entre dos imágenes en el fotograma (columna, orientación).
func _diff_in_frame(a: Image, b: Image, frame: Vector2i) -> int:
	var n: int = 0
	var origin: Vector2i = frame * OutfitPreview.FRAME
	for y: int in OutfitPreview.FRAME.y:
		for x: int in OutfitPreview.FRAME.x:
			if not a.get_pixel(origin.x + x, origin.y + y).is_equal_approx(b.get_pixel(origin.x + x, origin.y + y)):
				n += 1
	return n


func test_carga_una_vez_y_muestra_la_ropa() -> void:
	OutfitPreview.clear_cache()
	var ch: CharacterState = CharacterState.new()
	var preview: OutfitPreview = OutfitPreview.new()
	host.add_child(preview)
	var before: int = OutfitPreview.sheet_loads
	preview.character = ch
	check_eq(OutfitPreview.sheet_loads - before, 2, "lee dos hojas: el cuerpo y la bata")
	var image: Image = preview.composed_image()
	check(image != null, "compone la imagen")
	if image == null:
		preview.queue_free()
		return
	check_eq(image.get_size(), Vector2i(OutfitPreview.IDLE_FRAMES, OutfitPreview.DIRECTIONS) * OutfitPreview.FRAME,
		"solo guarda los fotogramas de reposo de las 16 orientaciones")
	var naked: Image = OutfitPreview.body_strip()
	check(_diff_in_frame(image, naked, Vector2i(0, 0)) > 150, "de frente se ve la bata encima del cuerpo")
	check(_diff_in_frame(image, naked, Vector2i(3, 8)) > 150, "y de espaldas")
	var loads: int = OutfitPreview.sheet_loads
	var draws: int = preview.draws
	for i: int in 60:
		await host.get_tree().process_frame
	check_eq(OutfitPreview.sheet_loads, loads, "no vuelve a leer hojas mientras respira y gira")
	check(preview.draws - draws < 30, "no se redibuja en cada fotograma (%d dibujos en 60)" % (preview.draws - draws))
	# Girar a mano redibuja en cada paso: debe costar poco (antes cada dibujo leía la hoja de la
	# ropa del disco, ~70 ms). Se mide el tiempo, no solo el contador, por si alguien vuelve a
	# cargar texturas por otro camino.
	draws = preview.draws
	var start: int = Time.get_ticks_usec()
	for i: int in OutfitPreview.DIRECTIONS:
		preview.turn(1)
		await host.get_tree().process_frame
	var per_frame_ms: float = (Time.get_ticks_usec() - start) / 1000.0 / OutfitPreview.DIRECTIONS
	check(preview.draws - draws >= OutfitPreview.DIRECTIONS - 1, "redibuja al girar")
	check(per_frame_ms < 30.0, "cada fotograma girando cuesta poco (%.1f ms)" % per_frame_ms)
	check_eq(OutfitPreview.sheet_loads, loads, "girar a mano no carga nada")
	# Cambiar de ropa: solo se lee la prenda nueva, una vez.
	ch.custody.add_item(Registry.item(&"chaqueta_celador"))
	ch.equip(ch.custody.find_first(&"chaqueta_celador"))
	check_eq(OutfitPreview.sheet_loads, loads + 1, "ponerse la chaqueta lee solo su hoja")
	var jacket: Image = preview.composed_image().duplicate() as Image
	check(_diff_in_frame(jacket, image, Vector2i(0, 0)) > 100, "y se ve la chaqueta en vez de la bata")
	ch.equip(ch.custody.find_first(&"bata_paciente"))
	ch.equip(ch.custody.find_first(&"chaqueta_celador"))
	check_eq(OutfitPreview.sheet_loads, loads + 1, "volver a cambiar usa la caché")
	preview.queue_free()


func test_la_pestana_de_equipo_no_carga_cada_fotograma() -> void:
	GameState.new_game()
	var w: WorldController = load(SCENE).instantiate()
	host.add_child(w)
	w.message.auto_advance = 0.01
	await host.get_tree().process_frame
	w.custody_screen.open(CustodyScreen.Tab.CHARACTER)
	await host.get_tree().process_frame
	var loads: int = OutfitPreview.sheet_loads
	for i: int in 30:
		await host.get_tree().process_frame
	check_eq(OutfitPreview.sheet_loads, loads, "con la pestaña abierta no se leen hojas")
	var preview: OutfitPreview = w.custody_screen.find_children("*", "OutfitPreview", true, false)[0]
	check(preview.composed_image() != null, "la vista previa tiene imagen")
	check(preview.is_visible_in_tree(), "y se ve")
	await w.custody_screen.close()
	w.queue_free()
	await host.get_tree().process_frame
