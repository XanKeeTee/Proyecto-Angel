class_name FocusOutline
extends Sprite2D
## Contorno tenue alrededor del sprite del objeto enfocado. Se cuelga como hijo del sprite,
## copia su fotograma y late despacio. No recibe luz: se ve aunque el objeto esté a oscuras,
## pero muy apagado (shaders/focus_outline.gdshader).

const SHADER: Shader = preload("res://shaders/focus_outline.gdshader")
const NODE_NAME: StringName = &"FocusOutline"
const BASE_STRENGTH: float = 0.28
const PULSE: float = 0.12
const PULSE_SPEED: float = 2.2

var _time: float = 0.0


## Añade (o devuelve) el contorno de `sprite`.
static func attach(sprite: Sprite2D) -> FocusOutline:
	var existing: FocusOutline = sprite.get_node_or_null(NodePath(String(NODE_NAME))) as FocusOutline
	if existing != null:
		return existing
	var outline: FocusOutline = FocusOutline.new()
	outline.name = NODE_NAME
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	outline.material = mat
	sprite.add_child(outline)
	outline._copy()
	return outline


static func detach(sprite: Sprite2D) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var existing: Node = sprite.get_node_or_null(NodePath(String(NODE_NAME)))
	if existing != null:
		existing.queue_free()


func _process(delta: float) -> void:
	_time += delta
	_copy()
	(material as ShaderMaterial).set_shader_parameter(&"strength", BASE_STRENGTH + PULSE * sin(_time * PULSE_SPEED))


func _copy() -> void:
	var source: Sprite2D = get_parent() as Sprite2D
	if source == null:
		return
	var tex: Texture2D = source.texture
	var canvas: CanvasTexture = tex as CanvasTexture
	texture = canvas.diffuse_texture if canvas != null else tex
	hframes = source.hframes
	vframes = source.vframes
	frame = source.frame
	offset = source.offset
	centered = source.centered
	flip_h = source.flip_h
	flip_v = source.flip_v
	visible = source.visible
