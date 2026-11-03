class_name Registry
extends RefCounted
## Busca por id los objetos, documentos y recetas de `data/`.
## Basta con añadir un `.tres` en la carpeta correspondiente para que exista en el juego.

const ITEMS_DIR: String = "res://data/items"
const DOCUMENTS_DIR: String = "res://data/documents"
const RECIPES_DIR: String = "res://data/recipes"

static var _items: Dictionary[StringName, ItemDef] = {}
static var _documents: Dictionary[StringName, DocumentDef] = {}
static var _recipes: Array[RecipeDef] = []
static var _loaded: bool = false


static func item(id: StringName) -> ItemDef:
	_ensure_loaded()
	return _items.get(id)


static func document(id: StringName) -> DocumentDef:
	_ensure_loaded()
	return _documents.get(id)


static func recipes() -> Array[RecipeDef]:
	_ensure_loaded()
	return _recipes


static func all_items() -> Array[ItemDef]:
	_ensure_loaded()
	return _items.values()


static func all_documents() -> Array[DocumentDef]:
	_ensure_loaded()
	return _documents.values()


static func find_recipe(a: ItemDef, b: ItemDef) -> RecipeDef:
	for recipe: RecipeDef in recipes():
		if recipe.matches(a, b):
			return recipe
	return null


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for res: Resource in _load_dir(ITEMS_DIR):
		var it: ItemDef = res as ItemDef
		if it != null:
			_items[it.id] = it
	for res: Resource in _load_dir(DOCUMENTS_DIR):
		var doc: DocumentDef = res as DocumentDef
		if doc != null:
			_documents[doc.id] = doc
	for res: Resource in _load_dir(RECIPES_DIR):
		var recipe: RecipeDef = res as RecipeDef
		if recipe != null:
			_recipes.append(recipe)


static func _load_dir(path: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for file: String in ResourceLoader.list_directory(path):
		# En una exportación los .tres pueden aparecer como .tres.remap.
		var clean: String = file.trim_suffix(".remap")
		if clean.ends_with(".tres") or clean.ends_with(".res"):
			var res: Resource = load(path.path_join(clean))
			if res != null:
				result.append(res)
	return result
