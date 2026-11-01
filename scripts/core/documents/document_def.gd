class_name DocumentDef
extends Resource
## Documento del Expediente personal: notas, expedientes, fotografías, mapas…
## No ocupa sitio en la bandeja. Se crea un `.tres` por documento en `data/documents/`.

enum Kind { NOTE, RECORD, REPORT, PHOTO, MAP, LABEL }
## Aspecto en el lector: papel mecanografiado, nota a mano, ficha clínica…
enum Style { TYPED, HANDWRITTEN, FORM, PHOTO }

@export var id: StringName = &""
@export var title: String = ""
@export var kind: Kind = Kind.NOTE
@export var style: Style = Style.TYPED
## Fecha que aparece en el documento (puede estar vacía o ser ilegible a propósito).
@export var date_text: String = ""
## Cuerpo en BBCode sencillo ([b], [i], [s]); los tachones con [s].
@export_multiline var body: String = ""
## Imagen para fotografías y mapas.
@export var image: Texture2D
## Sello o anotación en rojo sobre el papel ("ARCHIVADO", "NO REANIMAR"…).
@export var stamp: String = ""


func kind_label() -> String:
	return ["Nota", "Expediente", "Informe", "Fotografía", "Plano", "Etiqueta"][kind]
