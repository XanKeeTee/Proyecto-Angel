class_name ItemThumbs
extends RefCounted
## Miniaturas de los objetos para las listas de la custodia: el icono reducido (sin deformar) a
## una caja pequeña. Se hacen una vez por objeto y tamaño y se guardan en caché.

static var _cache: Dictionary[String, Texture2D] = {}


## Miniatura del objeto que cabe en `box` píxeles (null si no tiene icono).
static func thumb(def: ItemDef, box: Vector2i = Vector2i(22, 22)) -> Texture2D:
	if def == null or def.icon == null:
		return null
	var key: String = "%s@%dx%d" % [def.id, box.x, box.y]
	if _cache.has(key):
		return _cache[key]
	var result: Texture2D = def.icon
	var image: Image = def.icon.get_image()
	if image != null and not image.is_empty():
		if image.is_compressed():
			image.decompress()
		var k: float = minf(float(box.x) / image.get_width(), float(box.y) / image.get_height())
		if k < 1.0:
			image.resize(maxi(1, roundi(image.get_width() * k)), maxi(1, roundi(image.get_height() * k)),
				Image.INTERPOLATE_LANCZOS)
		result = ImageTexture.create_from_image(image)
	_cache[key] = result
	return result


## Primera vista del inspector (o el icono) para el panel de detalles.
static func first_view(def: ItemDef) -> Texture2D:
	if def == null:
		return null
	var sheet: Texture2D = def.inspect_sheet
	if sheet == null:
		return def.icon
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(0, 0, sheet.get_height(), sheet.get_height())
	return atlas
