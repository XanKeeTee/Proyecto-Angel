class_name ActionOption
extends RefCounted
## Una opción del menú de combate (contrato con la interfaz: `Battle.action_menu`). La interfaz la
## enseña tal cual, sin conocer las reglas.

var id: StringName = &""
## Categoría del menú: &"attack", &"skill", &"guard", &"item" u &"other".
var category: StringName = &""
var label: String = ""
var description: String = ""
## Clave que la interfaz traduce a un icono (&"attack", &"skill_empujon", &"item_venda"…).
var icon_key: StringName = &""
var enabled: bool = true
## Por qué no se puede ("" si se puede).
var disabled_reason: String = ""
var cost_body: int = 0
var cost_mind: int = 0
var needs_target: bool = false
var needs_part: bool = false
## Objeto de la custodia (ItemStack) o, en el prototipo, el id del objeto. null si no es un objeto.
var item: Variant = null
## Habilidad (SkillDef) o null.
## Unidades que quedan de un objeto (0 si no es un objeto).
var quantity: int = 0
var skill: SkillDef

# --- Campos añadidos por Q (la interfaz puede ignorarlos) ---
## Tipo de orden que genera.
var action_type: CombatTypes.ActionType = CombatTypes.ActionType.ATTACK
## Tratamiento por partes del objeto (TreatmentDef) o null.
var treatment: TreatmentDef
## Ataca con el arma de la mano no dominante.
var use_offhand: bool = false
## Texto corto para la derecha del menú («62 %», «×2», «+19 Mente»).
var value_text: String = ""
## A quién va: &"enemy", &"ally" (uno mismo o un aliado) o &"" (a nadie).
var target_side: StringName = &""
