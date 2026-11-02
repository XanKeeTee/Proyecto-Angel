class_name LightMirror
extends PointLight2D
## Luz gemela: copia de su luz padre el encendido, la energía y el color en cada fotograma
## (la transformación la hereda por ser hija). Sirve para iluminar otra capa con otras sombras
## (ver LightLayers).


func _process(_delta: float) -> void:
	var source: PointLight2D = get_parent() as PointLight2D
	if source == null:
		return
	enabled = source.enabled and source.is_visible_in_tree()
	energy = source.energy
	color = source.color
	texture_scale = source.texture_scale
