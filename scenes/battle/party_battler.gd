class_name PartyBattler
extends Node2D
## Un miembro del grupo en el escenario del combate, **de espaldas** y en primer plano, como en
## *Fear & Hunger*. La posición del nodo son sus pies.
##
## La imagen es un dato: `textures` (capas apiladas, de abajo arriba) con los pies en `origin`.
## Si el `CombatantDef` trae `battle_back`, se usa esa; si no, mientras se rehace el arte en 2D,
## el fotograma de espaldas del sprite del mapa (con la ropa puesta) ampliado ×2 sin suavizar.

## Hoja del protagonista en el mapa: rejilla de 48×68, fila 8 = de espaldas, columna 0 = reposo.
const MAP_SHEET: String = "res://assets/sprites/characters/protagonist.png"
const MAP_FRAME: Vector2i = Vector2i(48, 68)
const MAP_BACK_ROW: int = 8
const MAP_ORIGIN: Vector2 = Vector2(24, 62)
## Ampliación del fotograma del mapa.
const MAP_SCALE: float = 2.0
## De espaldas a la luz: un poco más oscuro que el enemigo.
const TINT: Color = Color(0.9, 0.88, 0.9)
const FALLEN_TINT: Color = Color(0.3, 0.28, 0.3)

## Capas de la imagen de espaldas (la primera es el cuerpo).
var textures: Array[Texture2D] = []
## Pies dentro de la imagen, en píxeles de la textura.
var origin: Vector2 = MAP_ORIGIN
## Ampliación al dibujar.
var draw_scale: float = MAP_SCALE
var combatant: Combatant
## Posición de reposo (las sacudidas y los pasos vuelven siempre aquí).
var home: Vector2 = Vector2.ZERO

var _hurt: float = 0.0
var _hurt_tween: Tween
var _move_tween: Tween


## Prepara la figura de un miembro. `character` (opcional) aporta la ropa puesta.
func setup(member: Combatant, character: CharacterState = null) -> void:
	combatant = member
	textures.clear()
	if member != null and member.def.battle_back != null:
		textures.append(member.def.battle_back)
		origin = member.def.battle_back_origin
		draw_scale = 1.0
	else:
		textures = map_back_layers(character)
		origin = MAP_ORIGIN
		draw_scale = MAP_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


## Capas del fotograma de espaldas del sprite del mapa: el cuerpo y la ropa que lleva puesta.
static func map_back_layers(character: CharacterState = null) -> Array[Texture2D]:
	var sheets: Array[Texture2D] = []
	if ResourceLoader.exists(MAP_SHEET):
		sheets.append(load(MAP_SHEET))
	if character != null:
		for slot: ItemDef.EquipSlot in [ItemDef.EquipSlot.LEGS, ItemDef.EquipSlot.FEET, ItemDef.EquipSlot.BODY,
				ItemDef.EquipSlot.HEAD]:
			var worn: ItemStack = character.worn(slot)
			if worn == null or worn.def.wear_path == "" or not ResourceLoader.exists(worn.def.wear_path):
				continue
			var tex: Texture2D = load(worn.def.wear_path)
			var canvas: CanvasTexture = tex as CanvasTexture
			sheets.append(canvas.diffuse_texture if canvas != null else tex)
	var result: Array[Texture2D] = []
	for sheet: Texture2D in sheets:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(Vector2(0, MAP_BACK_ROW * MAP_FRAME.y), Vector2(MAP_FRAME))
		result.append(atlas)
	return result


## Punto del pecho (para números flotantes y sangre), en coordenadas del padre.
func chest() -> Vector2:
	return position + Vector2(0, -origin.y * draw_scale * 0.62)


## Altura dibujada.
func height() -> float:
	return origin.y * draw_scale


## Destello rojo y sacudida al recibir un golpe.
func hurt(strength: float = 1.0) -> void:
	if _hurt_tween != null:
		_hurt_tween.kill()
	_hurt = strength
	_hurt_tween = create_tween()
	_hurt_tween.tween_method(_set_hurt, strength, 0.0, 0.45)
	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween()
	for i: int in 5:
		_move_tween.tween_property(self, "position", home + Vector2(randf_range(-4, 4), randf_range(-2, 2)) * strength, 0.03)
	_move_tween.tween_property(self, "position", home, 0.05)


## Paso hacia el enemigo al atacar.
func bump() -> void:
	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", home + Vector2(6, -10), 0.09).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "position", home, 0.16)


func _set_hurt(value: float) -> void:
	_hurt = value
	queue_redraw()


func _draw() -> void:
	if textures.is_empty():
		return
	# Sombra en el suelo, al borde de la luz.
	var shadow: PackedVector2Array = []
	for i: int in 16:
		var a: float = TAU * i / 16.0
		shadow.append(Vector2(cos(a) * 15.0 * draw_scale, sin(a) * 3.0 * draw_scale + 1.0))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.55))
	var tint: Color = TINT
	if combatant != null and (combatant.dead or combatant.fallen):
		tint = FALLEN_TINT
	tint = tint.lerp(Color(1.6, 0.35, 0.3), clampf(_hurt, 0.0, 1.0) * 0.7)
	for texture: Texture2D in textures:
		var tex_size: Vector2 = texture.get_size()
		draw_texture_rect(texture, Rect2(-origin * draw_scale, tex_size * draw_scale), false, tint)
