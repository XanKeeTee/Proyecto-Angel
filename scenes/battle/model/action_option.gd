class_name ActionOption
extends RefCounted
## Una cosa que puede hacer un combatiente ahora mismo (contrato de la interfaz del combate, ver
## docs/tech/interfaz-combate.md). La interfaz la enseña sin conocer las reglas.
##
## PROVISIONAL (agente P): si las reglas ya definen `ActionOption` con estos mismos campos, se borra
## este archivo al fusionar y se queda el suyo.

## Identificador estable (&"attack", &"guard", &"breathe", &"item:venda", &"flee_all"…).
var id: StringName = &""
## Categoría del menú: &"attack", &"skill", &"guard", &"item" u &"other".
var category: StringName = &"other"
var label: String = ""
var description: String = ""
## Clave del icono (la interfaz la traduce a una imagen: &"pipe", &"guard", &"lungs"…).
var icon_key: StringName = &""
var enabled: bool = true
## Por qué no se puede (si `enabled` es false).
var disabled_reason: String = ""
## Coste al usarla (positivo = se gasta).
var cost_body: int = 0
var cost_mind: int = 0
## Hay que elegir a quién.
var needs_target: bool = false
## Hay que elegir una parte del cuerpo (del objetivo, o propia en la Guardia).
var needs_part: bool = false
## ItemStack del objeto que se usa (o null).
var item: Variant = null
## Habilidad (recurso) o null.
var skill: Resource = null
## Unidades que quedan (objetos). Campo añadido por la interfaz: 0 = no se muestra.
var quantity: int = 0
