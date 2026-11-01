class_name InteractionResult
extends RefCounted
## Lo que devuelve una interacción para que la escena lo muestre: textos, sonido,
## documento a abrir en el lector…

var lines: PackedStringArray = []
var sound: AudioStream
## Documento que hay que abrir en el lector (al Leer).
var read_document: DocumentDef
## Hoja de vistas para el inspector (al Examinar algo que se puede girar).
var inspect_sheet: Texture2D
var inspect_views: int = 1
var inspect_title: String = ""
## Evento especial que debe gestionar la escena (grabadora, teléfono…).
var special: StringName = &""


func add(text: String) -> InteractionResult:
	if text.strip_edges() != "":
		lines.append(text)
	return self
