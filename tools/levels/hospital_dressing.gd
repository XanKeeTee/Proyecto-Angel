extends RefCounted
## Decorado NO interactivo del hospital del prólogo: lo llama build_hospital.gd (desde
## `_build_decals`) después de colocar suelos, paredes, puertas, objetos y luces.
##
## Qué pone:
## - Calcomanías de suelo: sombra al pie de las paredes y en los rincones, desgaste según
##   el tipo de suelo (grietas, baldosas rotas, mugre, rodadas, aceite, humedad…) y manchas
##   grandes (charcos, cercos, moho, quemaduras).
## - Calcomanías de pared (columna de 32x96): humedades, moho, desconchones, enchufes,
##   tuberías, conductos, carteles, tomas de oxígeno… solo sobre tramos de pared lisos.
## - Muebles y máquinas de decorado (props3.DRESSING), en `World` para que se ordenen con
##   el jugador, con colisión si ocupan sitio y oclusor de luz si son altos.
## - Sombra de contacto bajo los objetos sueltos del suelo (`item:`) y el fotograma
##   «vacío» de los contenedores (`frame_empty`) según su sprite.
##
## Todo es determinista (semilla fija). Lo que choque con un objeto interactuable, una
## puerta o su paso se descarta con un aviso, para no bloquear nunca el camino.
## Cada sala cuenta algo con lo que tiene: ver docs/tech/arquitectura.md (decorado).

const T: int = 32
const LAYER_WORLD: int = 1
const LAYER_PROPS: int = 4
const GROUP: StringName = &"dressing"

## Tiles de pared lisos (sin puerta, ventana, espejo…), en las filas alto/medio/bajo.
const PLAIN_WALL_COLUMNS: Dictionary = {2: [0, 1, 2, 3], 7: [0, 1, 2, 5]}

## Desgaste por tipo de suelo: [nombre de calcomanía, probabilidad por casilla].
const FLOOR_WEAR: Dictionary = {
	"room": [["grime", 0.07], ["crack", 0.03], ["crack_b", 0.02], ["tile_broken", 0.025], ["dust", 0.05]],
	"lino": [["tracks", 0.05], ["grime", 0.06], ["crack", 0.025], ["dust", 0.03]],
	"wood": [["dust", 0.09], ["grime", 0.05], ["papers", 0.03]],
	"terrazzo": [["grime", 0.06], ["crack_b", 0.03], ["dust", 0.05], ["butts", 0.015]],
	"or": [["grime", 0.06], ["drops", 0.025], ["tracks", 0.03]],
	"concrete": [["grime", 0.07], ["oil", 0.04], ["rust", 0.03], ["crack", 0.04], ["dust", 0.05], ["puddle", 0.02]],
}

## Calcomanías de pared por estilo: [nombre, peso].
const WALL_WEAR: Dictionary = {
	"ward": [["damp", 3], ["peel", 3], ["crack_w", 2], ["socket", 2], ["grime_low", 3], ["scrapes", 3], ["mold_top", 1],
		["drip_rust", 1], ["conduit", 1]],
	"or": [["grime_low", 2], ["socket", 2], ["crack_w", 1], ["scrapes", 1]],
	"basement": [["pipe_v", 3], ["pipes_v2", 2], ["damp", 3], ["mold_top", 3], ["drip_rust", 3], ["crack_w", 2],
		["grime_low", 3], ["junction", 1]],
}

## Fotograma «vacío» de cada sprite de contenedor (ver tools/art/props3.py).
const EMPTY_FRAMES: Dictionary = {
	"nightstand": {1: 2}, "locker": {1: 2}, "desk": {1: 2}, "workbench": {1: 2}, "filing_cabinet": {1: 2},
	"med_cabinet": {1: 2}, "counter": {1: 2}, "shelf": {0: 2, 1: 3}, "trash_bin": {0: 1}, "laundry_cart": {0: 1},
}

var b: Node
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Casillas ocupadas por objetos interactuables o reservadas (puertas, escaleras, paso).
var reserved: Dictionary = {}
## Casillas ocupadas por el decorado (las usa la prueba de accesibilidad).
var dressed: Dictionary = {}
var _decal_count: int = 0
var _prop_count: int = 0


## Construye todo el decorado. `builder` es el nodo de build_hospital.gd.
func build(builder: Node) -> void:
	b = builder
	rng.seed = 1990
	_reserve()
	for id: String in _rooms():
		_room_floor(id)
		_room_walls(id)
	_story_decals()
	_place_props()
	_post_interactables()
	print("Decorado: %d calcomanías, %d objetos." % [_decal_count, _prop_count])


# --- acceso al constructor ----------------------------------------------------------------------

func _rooms() -> Dictionary:
	return b.get("rooms")


func _rect(id: String) -> Rect2i:
	return b.call("_rect", id)


func _center(c: Vector2i) -> Vector2:
	return Vector2(c * T) + Vector2(T / 2.0, T / 2.0)


func _map() -> TileMapLayer:
	return b.get("map")


func _meta() -> Dictionary:
	return b.get("meta")


func _add(parent: Node, child: Node) -> void:
	b.call("_add", parent, child)


func _floor_of(c: Vector2i) -> String:
	var fr: Dictionary = b.get("floor_room")
	return fr.get(c, "")


# --- casillas reservadas ------------------------------------------------------------------------

func _reserve() -> void:
	var world: Node = b.get("world")
	for node: Node in world.get_children():
		if node is Door:
			var door: Door = node as Door
			var base: Vector2i = Vector2i(floori(door.position.x / T), floori(door.position.y / T))
			for c: Vector2i in [base + Vector2i(0, 1), base + Vector2i(0, 2), base + Vector2i(0, -4), base + Vector2i(0, -5),
					door.warp_front_to, door.warp_back_to]:
				reserved[c] = "puerta"
				reserved[c + Vector2i(0, 1)] = "puerta"
		elif node is Interactable:
			var it: Interactable = node as Interactable
			for off: Vector2i in it.footprint:
				reserved[it.base_cell() + off] = String(it.object_id)
				# Lo que está en la pared (ventanas, carteles…) se usa desde la casilla de debajo.
				if _floor_of(it.base_cell() + off) == "":
					reserved[it.base_cell() + off + Vector2i(0, 1)] = String(it.object_id)
	# La cama de la 08 se desplaza (evento): su destino queda libre.
	for c: Vector2i in [Vector2i(12, 6), Vector2i(12, 7), Vector2i(12, 8)]:
		reserved[c] = "cama_08_movida"
	# El extremo oeste del pasillo se abre al final: libre.
	for y: int in range(14, 17):
		for x: int in range(1, 4):
			reserved[Vector2i(x, y)] = "pasillo_imposible"


# --- calcomanías ---------------------------------------------------------------------------------

func _decal(sheet: String, name: String, pos: Vector2, rot: float = 0.0, flip: bool = false, parent: Node = null) -> Sprite2D:
	var d: Dictionary = _meta()[sheet]
	var names: Array = d["names"]
	var idx: int = names.find(name)
	if idx < 0:
		push_warning("Decorado: no existe la calcomanía %s/%s" % [sheet, name])
		return null
	var s: Sprite2D = Sprite2D.new()
	_decal_count += 1
	s.name = "%s_%d" % [name, _decal_count]
	s.texture = b.call("_canvas", d["path"])
	s.hframes = names.size()
	s.frame = idx
	s.position = pos
	s.rotation = rot
	s.flip_h = flip
	s.light_mask = LAYER_WORLD
	_add(parent if parent != null else b.get("decals"), s)
	if d.get("glow", false):
		var glow: Sprite2D = Sprite2D.new()
		glow.name = "Glow"
		glow.texture = load(String(d["path"]).get_basename() + "_glow.png")
		glow.hframes = s.hframes
		glow.frame = idx
		var mat: CanvasItemMaterial = CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		glow.material = mat
		_add(s, glow)
	return s


func _floor_decal(name: String, c: Vector2i, random_turn: bool = true) -> void:
	var rot: float = float(rng.randi_range(0, 3)) * PI / 2.0 if random_turn else 0.0
	_decal("decals", name, _center(c), rot, rng.randf() < 0.5)


func _big_decal(name: String, pos: Vector2) -> void:
	_decal("decals_big", name, pos, float(rng.randi_range(0, 3)) * PI / 2.0, rng.randf() < 0.5)


func _room_floor(id: String) -> void:
	var r: Rect2i = _rect(id)
	var kind: String = _rooms()[id]["floor"]
	# Sombra al pie de las paredes y en los rincones.
	for x: int in range(r.position.x, r.end.x):
		_decal("decals", "wallbase", _center(Vector2i(x, r.position.y)), 0.0, x % 2 == 0)
		_decal("decals", "wallbase", _center(Vector2i(x, r.end.y - 1)), PI, x % 2 == 0)
	for y: int in range(r.position.y, r.end.y):
		_decal("decals", "wallbase", _center(Vector2i(r.position.x, y)), -PI / 2.0, y % 2 == 0)
		_decal("decals", "wallbase", _center(Vector2i(r.end.x - 1, y)), PI / 2.0, y % 2 == 0)
	var corners: Array = [[r.position, 0.0], [Vector2i(r.end.x - 1, r.position.y), PI / 2.0],
		[Vector2i(r.end.x - 1, r.end.y - 1), PI], [Vector2i(r.position.x, r.end.y - 1), -PI / 2.0]]
	for corner: Array in corners:
		_decal("decals", "corner", _center(corner[0]), corner[1])
	# Desgaste repartido.
	var wear: Array = FLOOR_WEAR.get(kind, [])
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			for w: Array in wear:
				if rng.randf() < float(w[1]):
					_floor_decal(w[0], Vector2i(x, y))
					break
	# Manchas grandes: más en el sótano.
	var bigs: Array = ["grime_big", "damp_big"]
	if kind == "concrete":
		bigs = ["grime_big", "damp_big", "mold_big", "oil_big", "rust_big"]
	var count: int = maxi(1, r.get_area() / 24)
	for i: int in count:
		var pos: Vector2 = Vector2(rng.randf_range(r.position.x + 0.5, r.end.x - 0.5), rng.randf_range(r.position.y + 0.5, r.end.y - 0.5)) * T
		_big_decal(bigs[rng.randi() % bigs.size()], pos)


func _plain_wall(x: int, top: int) -> bool:
	var map: TileMapLayer = _map()
	for k: int in 3:
		var a: Vector2i = map.get_cell_atlas_coords(Vector2i(x, top + k))
		var ok: bool = false
		for base_row: int in PLAIN_WALL_COLUMNS:
			if a.y == base_row + k and (PLAIN_WALL_COLUMNS[base_row] as Array).has(a.x):
				ok = true
		if not ok:
			return false
	return true


func _wall_decal(name: String, x: int, top: int) -> void:
	_decal("decals_wall", name, Vector2(x * T + T / 2.0, top * T + 48.0))


func _room_walls(id: String) -> void:
	var r: Rect2i = _rect(id)
	var style: String = _rooms()[id]["walls"]
	var table: Array = WALL_WEAR.get(style, [])
	var total: int = 0
	for w: Array in table:
		total += int(w[1])
	var top: int = r.position.y - 3
	var chance: float = 0.5 if style == "basement" else 0.38
	for x: int in range(r.position.x, r.end.x):
		if not _plain_wall(x, top) or rng.randf() > chance:
			continue
		var pick: int = rng.randi() % total
		for w: Array in table:
			pick -= int(w[1])
			if pick < 0:
				_wall_decal(w[0], x, top)
				break
		# A veces, una segunda capa (moho sobre una humedad, mugre baja bajo un enchufe…).
		if rng.randf() < 0.25:
			_wall_decal(["grime_low", "mold_top", "drip_rust"][rng.randi() % 3], x, top)


## Calcomanías colocadas a mano: lo que cuenta cada sala.
func _story_decals() -> void:
	var F: String = "decals"
	var list: Array = [
		# Hab. 09: te despertaste solo. Gasas, una jeringa y el tubo del oxígeno arrancado.
		["gauze", Vector2i(3, 25)], ["syringe", Vector2i(2, 24)], ["drops", Vector2i(4, 23)], ["bandage", Vector2i(6, 23)],
		# Hab. 07: alguien que no estaba quieto. Pastillas, pelo y una sábana arrancada.
		["pills", Vector2i(3, 7)], ["hair", Vector2i(4, 6)], ["leaflets", Vector2i(5, 5)],
		# Hab. 10: el cuaderno y sus hojas sueltas hasta la puerta.
		["leaflets", Vector2i(19, 8)], ["papers", Vector2i(21, 7)], ["leaflets", Vector2i(22, 8)], ["smear", Vector2i(20, 7)],
		# Hab. 11: polvo de meses.
		["dust", Vector2i(28, 6)], ["dust", Vector2i(29, 8)], ["dust", Vector2i(26, 8)],
		# Hab. 12: el hueco de la otra cama.
		["tracks", Vector2i(13, 26)], ["dust", Vector2i(14, 26)],
		# Pasillo: rodadas de camillas, papeles y cristales.
		["tracks", Vector2i(14, 15)], ["tracks", Vector2i(15, 15)], ["tracks", Vector2i(30, 15)], ["tracks", Vector2i(31, 15)],
		["leaflets", Vector2i(40, 16)], ["glass", Vector2i(55, 14)], ["butts", Vector2i(64, 14)], ["cables", Vector2i(48, 16)],
		# Almacén y baños: agua por todas partes.
		["puddle", Vector2i(20, 24)], ["drain", Vector2i(25, 24)], ["puddle", Vector2i(26, 25)], ["hair", Vector2i(27, 22)],
		["puddle", Vector2i(23, 26)],
		# Control: el turno se fue corriendo.
		["leaflets", Vector2i(33, 24)], ["papers", Vector2i(32, 26)], ["tape", Vector2i(31, 27)],
		# Enfermería y quirófano.
		["gauze", Vector2i(39, 6)], ["pills", Vector2i(41, 8)], ["syringe", Vector2i(37, 7)],
		["gauze", Vector2i(44, 26)], ["drain", Vector2i(46, 27)], ["bandage", Vector2i(42, 26)], ["cables", Vector2i(43, 25)],
		# Archivo: fichas por el suelo.
		["leaflets", Vector2i(49, 6)], ["leaflets", Vector2i(54, 6)], ["papers", Vector2i(47, 6)],
		# Recepción y vestíbulo.
		["leaflets", Vector2i(61, 25)], ["butts", Vector2i(67, 26)], ["glass", Vector2i(68, 5)],
		# Sótano.
		["puddle", Vector2i(3, 37)], ["drain", Vector2i(5, 38)], ["cables", Vector2i(12, 37)], ["cables", Vector2i(13, 35)],
		["screws", Vector2i(15, 36)], ["drain", Vector2i(23, 36)], ["puddle", Vector2i(24, 36)], ["puddle", Vector2i(21, 38)],
		["tracks", Vector2i(10, 45)], ["tracks", Vector2i(11, 45)], ["puddle", Vector2i(20, 45)],
		["drain", Vector2i(5, 56)], ["puddle", Vector2i(4, 56)], ["drops", Vector2i(6, 54)], ["tracks", Vector2i(7, 53)],
		["oil", Vector2i(17, 56)], ["screws", Vector2i(18, 54)], ["oil", Vector2i(29, 55)], ["screws", Vector2i(30, 54)],
		["screws", Vector2i(28, 56)],
	]
	for e: Array in list:
		_floor_decal(e[0], e[1])
	var bigs: Array = [
		["sheet", Vector2(5.5, 7.5)], ["blood_big", Vector2(45.5, 26.0)], ["puddle_big", Vector2(25.0, 25.0)],
		["damp_big", Vector2(29.0, 6.0)], ["scorch", Vector2(10.5, 36.0)], ["puddle_big", Vector2(23.0, 37.0)],
		["oil_big", Vector2(16.0, 57.0)], ["rust_big", Vector2(22.0, 54.0)], ["puddle_big", Vector2(5.0, 56.5)],
		["puddle_big", Vector2(3.5, 38.0)], ["oil_big", Vector2(28.5, 56.0)], ["mold_big", Vector2(2.0, 46.0)],
	]
	for e: Array in bigs:
		_big_decal(e[0], (e[1] as Vector2) * T)
	# Señales de salida (con su capa de brillo) y tomas de oxígeno en la cabecera de las camas.
	for e: Array in [["exit", 66, 11], ["exit", 67, 1], ["exit", 70, 18], ["exit", 3, 41],
			["oxygen", 2, 1], ["oxygen", 10, 1], ["oxygen", 18, 1], ["oxygen", 26, 1], ["oxygen", 2, 18], ["oxygen", 10, 18],
			["call", 3, 18], ["call", 11, 1], ["switch", 5, 18], ["switch", 13, 18], ["switch", 37, 1], ["switch", 50, 1],
			["cobweb", 25, 1], ["cobweb", 1, 31], ["cobweb", 26, 48], ["poster", 31, 18], ["poster", 56, 18],
			["poster", 41, 11], ["hand_low", 21, 1], ["scrapes", 23, 11], ["scrapes", 47, 11], ["hand_low", 9, 31],
			["pipe_h", 13, 48], ["pipe_h", 14, 48], ["pipe_h", 20, 48], ["pipe_h", 21, 48], ["pipe_h", 22, 48]]:
		if _plain_wall(e[1], e[2]):
			_wall_decal(e[0], e[1], e[2])
	# El pasillo del sótano: tuberías vistas a lo largo de todo el muro.
	var bp: Rect2i = _rect("b_pasillo")
	for x: int in range(bp.position.x, bp.end.x):
		if _plain_wall(x, bp.position.y - 3):
			_wall_decal("pipe_h", x, bp.position.y - 3)


# --- muebles y máquinas ---------------------------------------------------------------------------

## Una entrada de decorado: clave del sprite, casilla base y opciones.
##   f: fotograma · fp: casillas que ocupa (relativas) · solid: colisión (por defecto sí)
##   off: desplazamiento en píxeles del nodo · wall: cuelga de la pared (sin colisión)
##   occ: rectángulo [x, y, ancho, alto] del oclusor de luz, relativo al nodo · flip: espejo
func _props() -> Array:
	var W: Array = [[0, 0], [1, 0]]
	var V: Array = [[0, 0], [0, -1]]
	return [
		# Hab. 09 (inicio)
		{"k": "o2_tank", "c": [1, 25]}, {"k": "wheelchair_up", "c": [1, 27], "f": 1},
		{"k": "screen", "c": [5, 27], "fp": W, "off": [16, 0], "occ": [-30, -6, 60, 4]}, {"k": "iv_bags_box", "c": [7, 22]},
		# Hab. 12: el sitio vacío de la otra cama.
		{"k": "o2_tank", "c": [9, 26]}, {"k": "wheelchair_up", "c": [15, 24], "f": 1}, {"k": "boxes", "c": [15, 27], "f": 2},
		# Hab. 07: alguien que no se estaba quieto.
		{"k": "o2_tank", "c": [1, 7]}, {"k": "plant", "c": [1, 4]}, {"k": "clock", "c": [4, 4], "wall": true},
		{"k": "office_chair", "c": [7, 7], "f": 1, "solid": false},
		# Hab. 08
		{"k": "screen", "c": [14, 5], "f": 1, "fp": W, "off": [16, 0], "solid": false}, {"k": "o2_tank", "c": [9, 7]},
		{"k": "plant", "c": [15, 4]},
		# Hab. 10: cerrada desde fuera; dentro, desorden.
		{"k": "wheelchair_up", "c": [23, 8]}, {"k": "office_chair", "c": [17, 8], "f": 1, "solid": false},
		{"k": "iv_fallen", "c": [21, 6], "fp": W, "off": [16, 0], "solid": false},
		# Hab. 11: vacía desde marzo.
		{"k": "screen", "c": [29, 7], "fp": W, "off": [16, 0], "occ": [-30, -6, 60, 4]}, {"k": "wheelchair_up", "c": [31, 9], "f": 1},
		{"k": "o2_tank", "c": [25, 7]},
		# Enfermería
		{"k": "scale", "c": [33, 4]}, {"k": "lightbox", "c": [37, 4], "wall": true, "off": [0, -10]},
		{"k": "cart_med", "c": [33, 6]}, {"k": "cart_instr", "c": [44, 7]}, {"k": "o2_tank", "c": [33, 9]},
		{"k": "screen", "c": [40, 7], "fp": W, "off": [16, 0], "occ": [-30, -6, 60, 4]}, {"k": "clock", "c": [39, 4], "wall": true},
		{"k": "wheelchair_up", "c": [44, 9]},
		# Archivo
		{"k": "boxes", "c": [46, 4], "f": 1}, {"k": "ladder", "c": [53, 4]}, {"k": "boxes", "c": [57, 4], "f": 2},
		{"k": "files_pile", "c": [50, 6], "solid": false}, {"k": "files_pile", "c": [52, 8], "solid": false},
		{"k": "boxes", "c": [57, 6]}, {"k": "clock", "c": [51, 4], "wall": true},
		# Escalera de servicio: cajas para tapar la puerta.
		{"k": "boxes", "c": [59, 6], "f": 1}, {"k": "boxes", "c": [59, 8]}, {"k": "extinguisher", "c": [63, 4], "wall": true},
		{"k": "bags", "c": [63, 6]},
		# Vestíbulo
		{"k": "bench", "c": [65, 4], "fp": W, "off": [16, 0]}, {"k": "plant", "c": [65, 9]}, {"k": "water_cooler", "c": [70, 4]},
		# Pasillo
		{"k": "bench", "c": [31, 14], "fp": W, "off": [16, 0]}, {"k": "bench", "c": [52, 14], "fp": W, "off": [16, 0]},
		{"k": "plant", "c": [36, 14]}, {"k": "plant", "c": [70, 14]}, {"k": "wheelchair_up", "c": [48, 14], "f": 1},
		{"k": "gurney_tipped", "c": [56, 16], "fp": W, "off": [16, 0]},
		{"k": "iv_fallen", "c": [15, 16], "fp": W, "off": [16, 0], "solid": false}, {"k": "cart_med", "c": [65, 16]},
		{"k": "extinguisher", "c": [26, 14], "wall": true}, {"k": "extinguisher", "c": [58, 14], "wall": true},
		{"k": "o2_tank", "c": [7, 14]}, {"k": "boxes", "c": [41, 16]},
		# Almacén
		{"k": "bags", "c": [21, 27]}, {"k": "boxes", "c": [17, 27], "f": 1}, {"k": "ladder", "c": [17, 24]},
		{"k": "linen_pile", "c": [20, 27], "solid": false},
		# Baños
		{"k": "toilet", "c": [24, 21]}, {"k": "toilet", "c": [28, 21]},
		{"k": "bathtub", "c": [23, 27], "fp": W, "off": [16, 0]},
		# Control de enfermería
		{"k": "boxes", "c": [30, 22], "f": 2}, {"k": "files_pile", "c": [36, 22], "solid": false},
		{"k": "office_chair", "c": [33, 27], "f": 1, "solid": false}, {"k": "cart_med", "c": [36, 24]},
		{"k": "clock", "c": [35, 21], "wall": true},
		# Quirófano
		{"k": "anesthesia", "c": [43, 24]}, {"k": "cart_instr", "c": [47, 26]}, {"k": "o2_tank", "c": [38, 23]},
		{"k": "iv_bags_box", "c": [52, 27]}, {"k": "screen", "c": [49, 27], "fp": W, "off": [16, 0], "occ": [-30, -6, 60, 4]},
		{"k": "lightbox", "c": [43, 21], "wall": true, "off": [0, -10]}, {"k": "cart_instr", "c": [38, 27]},
		# Recepción
		{"k": "bench", "c": [63, 23], "fp": W, "off": [16, 0]}, {"k": "bench", "c": [68, 23], "fp": W, "off": [16, 0]},
		{"k": "plant", "c": [54, 21]}, {"k": "plant", "c": [71, 21]}, {"k": "water_cooler", "c": [64, 21]},
		{"k": "boxes", "c": [54, 27], "f": 2}, {"k": "files_pile", "c": [58, 26], "solid": false},
		{"k": "clock", "c": [60, 21], "wall": true},
		# Sótano · escalera
		{"k": "drum", "c": [1, 38]}, {"k": "pallet", "c": [6, 39]}, {"k": "bags", "c": [2, 39]},
		# Sótano · sala eléctrica
		{"k": "transformer", "c": [8, 34], "occ": [-14, -10, 28, 12]}, {"k": "cable_reel", "c": [17, 36]},
		{"k": "toolbox", "c": [9, 38], "solid": false}, {"k": "ladder", "c": [13, 34]},
		# Sótano · lavandería
		{"k": "washer", "c": [21, 34], "occ": [-14, -12, 28, 12]}, {"k": "washer", "c": [22, 34], "occ": [-14, -12, 28, 12]},
		{"k": "dryer", "c": [24, 34], "occ": [-13, -12, 26, 12]}, {"k": "dryer", "c": [25, 34], "occ": [-13, -12, 26, 12]},
		{"k": "basket", "c": [19, 38]}, {"k": "linen_pile", "c": [27, 38], "solid": false}, {"k": "bags", "c": [27, 35]},
		# Sótano · pasillo de mantenimiento
		{"k": "drum", "c": [8, 44]}, {"k": "pallet", "c": [15, 46]}, {"k": "drum", "c": [21, 46], "f": 1},
		{"k": "boxes", "c": [34, 44], "f": 1}, {"k": "bags", "c": [33, 46]},
		# Sótano · morgue
		{"k": "cold_door", "c": [9, 51], "fp": W, "off": [16, -6], "wall": true},
		{"k": "autopsy_table", "c": [5, 55], "fp": V, "off": [0, -16], "occ": [-10, -40, 20, 52]},
		{"k": "body_bags", "c": [1, 57]}, {"k": "cart_instr", "c": [3, 57]}, {"k": "scale", "c": [10, 53]},
		# Sótano · calderas
		{"k": "tank_h", "c": [20, 52], "fp": W, "off": [16, 0], "occ": [-30, -10, 60, 12]}, {"k": "drum", "c": [12, 57]},
		{"k": "drum", "c": [24, 57], "f": 1}, {"k": "pallet", "c": [13, 54]}, {"k": "gas_bottles", "c": [24, 54]},
		# Sótano · taller
		{"k": "pegboard", "c": [27, 51], "fp": W, "off": [16, -10], "wall": true}, {"k": "gas_bottles", "c": [34, 51]},
		{"k": "drum", "c": [26, 57]}, {"k": "toolbox", "c": [29, 57], "solid": false}, {"k": "boxes", "c": [34, 57], "f": 1},
		{"k": "ladder", "c": [26, 51]},
	]


func _place_props() -> void:
	var world: Node2D = b.get("world")
	for e: Dictionary in _props():
		var base: Vector2i = Vector2i(int(e["c"][0]), int(e["c"][1]))
		var fp: Array[Vector2i] = []
		for f: Array in e.get("fp", [[0, 0]]):
			fp.append(base + Vector2i(int(f[0]), int(f[1])))
		var wall: bool = e.get("wall", false)
		var clash: String = ""
		for c: Vector2i in fp:
			if _floor_of(c) == "":
				clash = "fuera del suelo"
			elif not wall and reserved.has(c):
				clash = String(reserved[c])
			elif not wall and dressed.has(c):
				clash = "otro decorado"
		if clash != "":
			push_warning("Decorado: %s en %s choca con %s; se omite." % [e["k"], base, clash])
			continue
		var node: Node2D = Node2D.new()
		_prop_count += 1
		node.name = "Dress_%s_%d" % [e["k"], _prop_count]
		var off: Array = e.get("off", [0, 0])
		node.position = _center(base) + Vector2(float(off[0]), float(off[1]))
		_add(world, node)
		node.add_to_group(GROUP, true)
		var sprite: Sprite2D = b.call("_sprite", e["k"])
		sprite.frame = int(e.get("f", 0))
		sprite.flip_h = e.get("flip", false)
		_add(node, sprite)
		var solid: bool = e.get("solid", not wall)
		if solid:
			for c: Vector2i in fp:
				dressed[c] = String(e["k"])
			node.set_meta(&"cells", fp)
			_add_body(node, fp, base, off)
		if e.has("occ"):
			var r: Array = e["occ"]
			var poly: OccluderPolygon2D = OccluderPolygon2D.new()
			poly.polygon = PackedVector2Array([Vector2(r[0], r[1]), Vector2(r[0] + r[2], r[1]), Vector2(r[0] + r[2], r[1] + r[3]),
				Vector2(r[0], r[1] + r[3])])
			var o: LightOccluder2D = LightOccluder2D.new()
			o.name = "Shadow"
			o.occluder = poly
			_add(node, o)


func _add_body(node: Node2D, cells: Array[Vector2i], base: Vector2i, off: Array) -> void:
	var area: Rect2 = Rect2(_center(cells[0]), Vector2.ZERO)
	for c: Vector2i in cells:
		area = area.expand(_center(c))
	area = area.grow(12.0)
	area.position -= node.position
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	_add(node, body)
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = area.size
	shape.shape = rect
	shape.position = area.get_center()
	_add(body, shape)


# --- retoques sobre los objetos interactuables ------------------------------------------------------

func _post_interactables() -> void:
	var meta: Dictionary = _meta()
	var by_path: Dictionary = {}
	for key: String in meta:
		var m: Dictionary = meta[key]
		if m.has("path"):
			by_path[String(m["path"]).get_basename() + "_canvas.tres"] = key
	var world: Node = b.get("world")
	for node: Node in world.get_children():
		if not node is Interactable:
			continue
		var it: Interactable = node as Interactable
		var sprite: Sprite2D = it.get_node_or_null(^"Sprite2D") as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var path: String = sprite.texture.resource_path
		var key: String = by_path.get(path, "")
		# Fotograma «vacío» del contenedor, si su sprite lo tiene y no se ha fijado a mano.
		if it.frame_empty < 0 and EMPTY_FRAMES.has(key) and it.kind == Interactable.Kind.CONTAINER:
			var frames: Dictionary = EMPTY_FRAMES[key]
			var shown: int = it.frame_open if it.openable else it.frame_closed
			if frames.has(shown):
				it.frame_empty = int(frames[shown])
		# Objetos sueltos (iconos de objeto): sombra de contacto para que se vean apoyados.
		if not sprite.texture is CanvasTexture:
			var shadow: Sprite2D = _decal("decals", "contact", Vector2(0, 9), 0.0, false, it)
			if shadow != null:
				it.move_child(shadow, 0)
