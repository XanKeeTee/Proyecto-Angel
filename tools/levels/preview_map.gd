extends Node
## Vista de revisión del arte del hospital: renderiza una zona del mapa a pleno brillo
## (sin oscuridad ni luces) y la guarda como PNG, para revisar suelos, paredes, objetos
## y decorado sin la linterna. No forma parte del juego.
## Uso:
##   "$GODOT_BIN" --path . --rendering-driver opengl3 res://tools/levels/preview_map.tscn -- \
##     --region=0,0,74,30 --out=/ruta/planta3.png [--lit]
## Con --lit se mantienen la oscuridad y las luces con la corriente puesta (como en el juego).
## Necesita pantalla (xvfb-run en servidores).

const SCENE: String = "res://scenes/world/hospital/hospital.tscn"
const T: int = 32


func _ready() -> void:
	var region: Rect2i = Rect2i(0, 0, 74, 30)
	var out: String = "user://preview_map.png"
	var lit: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--region="):
			var p: PackedStringArray = arg.trim_prefix("--region=").split(",")
			region = Rect2i(int(p[0]), int(p[1]), int(p[2]), int(p[3]))
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--lit":
			lit = true
	if lit:
		GameState.set_flag(GameState.FLAG_POWER)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = region.size * T
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	var hospital: Node2D = (load(SCENE) as PackedScene).instantiate() as Node2D
	hospital.set_script(null)
	viewport.add_child(hospital)
	for name: String in ["Player", "FadeLayer", "Events", "Ambience"]:
		var node: Node = hospital.find_child(name, true, false)
		if node != null:
			node.queue_free()
	if not lit:
		(hospital.find_child("Darkness", true, false) as CanvasItem).visible = false
		(hospital.find_child("Lights", true, false) as CanvasItem).visible = false
	else:
		for light: Node in hospital.find_child("Lights", true, false).get_children():
			if light.has_method(&"set_powered"):
				light.call(&"set_powered", true)
	var camera: Camera2D = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera.position = Vector2(region.position * T)
	viewport.add_child(camera)
	camera.make_current()
	for i: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	img.save_png(out)
	print("Vista guardada: ", out, " ", img.get_size())
	get_tree().quit()
