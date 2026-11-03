class_name LootEntry
extends Resource
## Algo que se encuentra dentro de un objeto: un objeto de la custodia o un documento.

@export var item: ItemDef
@export var quantity: int = 1
@export var document: DocumentDef
## Frase opcional al encontrarlo ("Debajo de la almohada hay…").
@export_multiline var text: String = ""


func label() -> String:
	if item != null:
		return item.display_name + (" ×%d" % quantity if quantity > 1 else "")
	if document != null:
		return document.title
	return ""
