class_name LightLayers
extends RefCounted
## Capas de luz y sombra del mapa (bits de `light_mask`, `range_item_cull_mask`,
## `shadow_item_cull_mask` y `occluder_light_mask`).
##
## En Godot 2D, `shadow_item_cull_mask` de una luz decide a la vez qué oclusores proyectan
## sombra y qué objetos la reciben. Por eso:
## - Los muros (tiles y puertas cerradas) ocluyen en WORLD | PROPS: todas las luces los usan,
##   y su sombra cae sobre el suelo y sobre los muebles (la luz no cruza paredes).
## - Los muebles ocluyen solo en PROP_OCCLUDERS: su sombra cae sobre el suelo (WORLD) con la
##   linterna, pero nunca sobre los propios muebles (si no, un mueble se oscurecería a sí mismo).
## - La linterna son dos luces: la principal ilumina el suelo y las paredes con sombras de
##   muros y muebles, y una gemela ilumina los muebles con sombras solo de muros.
## Lo usan tools/levels/build_hospital.gd (al generar) y WorldController (luces del jugador).

## Suelo, paredes y marcos de puerta.
const WORLD: int = 1
## El protagonista (la linterna no le ilumina).
const PLAYER: int = 2
## Muebles y objetos.
const PROPS: int = 4
## Oclusores de los muebles.
const PROP_OCCLUDERS: int = 8
const ALL_ITEMS: int = WORLD | PLAYER | PROPS
## Máscara de los oclusores de muros y puertas cerradas.
const WALL_OCCLUDERS: int = WORLD | PROPS
## Luces fijas (techo, emergencia, monitores): sombras de muros sobre suelo y muebles.
const FIXED_LIGHT_SHADOWS: int = WORLD | PROPS
## Linterna principal: sombras de muros y muebles sobre el suelo y las paredes.
const FLASHLIGHT_SHADOWS: int = WORLD | PROP_OCCLUDERS
## Gemela de la linterna para los muebles: solo sombras de muros.
const FLASHLIGHT_PROP_SHADOWS: int = PROPS
const FLASHLIGHT_PROPS_NODE: StringName = &"FlashlightProps"
const BOUNCE_CLAMP_NODE: StringName = &"BounceClamp"


## Ajusta las luces del jugador (halo, linterna y rebote) a las capas de arriba y añade la
## gemela de la linterna y el limitador del rebote. Se puede llamar varias veces.
static func setup_player(player: Node2D) -> void:
	var aura: PointLight2D = player.get_node_or_null(^"Aura") as PointLight2D
	if aura != null:
		aura.shadow_enabled = true
		aura.shadow_item_cull_mask = FIXED_LIGHT_SHADOWS
	var flashlight: PointLight2D = player.get_node_or_null(^"Flashlight") as PointLight2D
	if flashlight != null:
		flashlight.range_item_cull_mask = WORLD
		flashlight.shadow_enabled = true
		flashlight.shadow_item_cull_mask = FLASHLIGHT_SHADOWS
		if flashlight.get_node_or_null(NodePath(String(FLASHLIGHT_PROPS_NODE))) == null:
			var twin: LightMirror = LightMirror.new()
			twin.name = FLASHLIGHT_PROPS_NODE
			twin.texture = flashlight.texture
			twin.texture_scale = flashlight.texture_scale
			twin.height = flashlight.height
			twin.range_item_cull_mask = PROPS
			twin.shadow_enabled = true
			twin.shadow_item_cull_mask = FLASHLIGHT_PROP_SHADOWS
			twin.shadow_filter = flashlight.shadow_filter
			twin.shadow_filter_smooth = flashlight.shadow_filter_smooth
			flashlight.add_child(twin)
	var bounce: PointLight2D = player.get_node_or_null(^"Bounce") as PointLight2D
	if bounce != null:
		bounce.shadow_enabled = true
		bounce.shadow_item_cull_mask = FIXED_LIGHT_SHADOWS
		if flashlight != null and player.get_node_or_null(NodePath(String(BOUNCE_CLAMP_NODE))) == null:
			var clamp: BounceClamp = BounceClamp.new()
			clamp.name = BOUNCE_CLAMP_NODE
			clamp.source = flashlight
			clamp.bounce = bounce
			player.add_child(clamp)
