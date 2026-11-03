class_name BloodFx
extends Node2D
## Salpicaduras de sangre: gotas que saltan, caen y se quedan como manchas en el suelo
## (`floor_y`, en coordenadas locales). Sin partículas de GPU: funciona igual en Compatibility.

const COLORS: Array[Color] = [Color("6e1410"), Color("8e1d16"), Color("a3241c"), Color("4c0d0a")]
const GRAVITY: float = 520.0
const MAX_STAINS: int = 90

## Altura del suelo donde se quedan las manchas (local). INF = no dejan mancha.
var floor_y: float = INF

var _drops: Array[Dictionary] = []
var _stains: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Salpicadura en `point` (local) hacia `direction` (normalizada; cero = en todas direcciones).
func burst(point: Vector2, amount: int, direction: Vector2 = Vector2.ZERO, force: float = 160.0) -> void:
	for i: int in amount:
		var angle: float = _rng.randf() * TAU
		var dir: Vector2 = Vector2.from_angle(angle)
		if direction != Vector2.ZERO:
			dir = direction.rotated(_rng.randf_range(-0.7, 0.7))
		var speed: float = force * _rng.randf_range(0.35, 1.15)
		_drops.append({
			"p": point + Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3)),
			"v": dir * speed + Vector2(0, -force * 0.35),
			"s": _rng.randi_range(1, 3),
			"c": COLORS[_rng.randi_range(0, COLORS.size() - 1)],
			"life": _rng.randf_range(0.5, 1.1),
		})


func clear() -> void:
	_drops.clear()
	_stains.clear()
	queue_redraw()


func drop_count() -> int:
	return _drops.size()


func _process(delta: float) -> void:
	if _drops.is_empty():
		return
	for drop: Dictionary in _drops:
		drop["v"] = (drop["v"] as Vector2) + Vector2(0, GRAVITY * delta)
		drop["p"] = (drop["p"] as Vector2) + (drop["v"] as Vector2) * delta
		drop["life"] = float(drop["life"]) - delta
		var p: Vector2 = drop["p"]
		if p.y >= floor_y:
			drop["life"] = 0.0
			_stains.append({"p": Vector2(p.x, floor_y + _rng.randf_range(-2, 4)), "w": _rng.randi_range(2, 6),
				"c": drop["c"]})
	_drops = _drops.filter(func(d: Dictionary) -> bool: return float(d["life"]) > 0.0)
	while _stains.size() > MAX_STAINS:
		_stains.pop_front()
	queue_redraw()


func _draw() -> void:
	for stain: Dictionary in _stains:
		var p: Vector2 = stain["p"]
		var w: int = stain["w"]
		draw_rect(Rect2(p - Vector2(w / 2.0, 1), Vector2(w, 2)), stain["c"])
	for drop: Dictionary in _drops:
		var s: int = drop["s"]
		var v: Vector2 = drop["v"]
		var p: Vector2 = drop["p"]
		draw_rect(Rect2(p, Vector2(s, s)), drop["c"])
		# Estela corta en la dirección del movimiento.
		draw_line(p, p - v.normalized() * (s + 2.0), drop["c"], 1.0)
