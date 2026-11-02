class_name ItemSounds
extends RefCounted
## Sonidos de los objetos en la custodia, al estilo de Tarkov: cada objeto suena según su
## material al cogerlo, colocarlo, girarlo, equiparlo, descartarlo, rasgarlo o usarlo.
##
## Nombres que se buscan, en este orden (el primero que exista en assets/audio/sfx/):
##   1. `inv_<material>_<acción>`  p. ej. inv_metal_heavy_pick, inv_cloth_place, inv_keys_rotate
##   2. `inv_<acción>`             genérico para cualquier material
##   3. un sonido que ya existe y se parece (provisional, hasta tener los de Freesound)
## Para usar: `ItemDef.use_sound` (use_battery_insert, use_bandage_apply…) y su provisional.
## La lista completa de sonidos que faltan está en docs/design/sistemas/custodia.md.

enum Action { PICK, PLACE, ROTATE, EQUIP, UNEQUIP, DISCARD, TEAR, CRAFT, USE }

const ACTION_NAMES: Array[String] = ["pick", "place", "rotate", "equip", "unequip", "drop", "tear", "craft", "use"]
## Sonido existente que se usa mientras falte el propio, por material (índice de SoundMaterial).
const MATERIAL_PROVISIONAL: Array[String] = [
	"pickup", "pickup", "pickup", "pickup", "bandage", "paper", "pickup", "glass", "pills", "battery", "pickup",
	"pickup", "pickup",
]
## Tono del provisional por material: grave para lo pesado, agudo para lo pequeño.
const MATERIAL_PITCH: Array[float] = [1.0, 0.72, 1.25, 1.4, 1.0, 1.0, 1.12, 1.0, 1.0, 1.0, 0.92, 0.85, 1.05]
## Provisionales para los sonidos de uso, rasgar y fabricar.
const NAMED_PROVISIONAL: Dictionary[String, String] = {
	"use_battery_insert": "battery", "use_bandage_apply": "bandage", "use_pills_swallow": "pills",
	"use_syringe_inject": "pills", "use_tourniquet_tighten": "bandage", "cloth_tear": "bandage",
	"craft_generic": "pickup", "craft_combine": "pickup", "craft_cloth": "bandage",
}

static var _exists_cache: Dictionary[String, bool] = {}


## Nombres candidatos para un objeto y una acción, del más concreto al provisional.
static func candidates(def: ItemDef, action: Action) -> PackedStringArray:
	var result: PackedStringArray = []
	if action == Action.USE:
		if def.use_sound != "":
			result.append(def.use_sound)
			if NAMED_PROVISIONAL.has(def.use_sound):
				result.append(NAMED_PROVISIONAL[def.use_sound])
		return result
	if action == Action.TEAR:
		return PackedStringArray(["cloth_tear", NAMED_PROVISIONAL["cloth_tear"]])
	var mat: int = def.resolved_sound_material()
	var verb: String = ACTION_NAMES[action]
	result.append("inv_%s_%s" % [ItemDef.SOUND_MATERIAL_NAMES[mat], verb])
	result.append("inv_" + verb)
	result.append(MATERIAL_PROVISIONAL[mat])
	return result


## El primer candidato que existe ("" si ninguno).
static func resolve(names: PackedStringArray) -> String:
	for n: String in names:
		if _exists(n):
			return n
	return ""


## Suena el objeto. Sirve aunque el juego esté en pausa (la custodia lo pausa).
static func play(parent: Node, def: ItemDef, action: Action, volume_db: float = -8.0) -> void:
	if parent == null or def == null:
		return
	var names: PackedStringArray = candidates(def, action)
	var sound: String = resolve(names)
	if sound == "":
		return
	# Si es el provisional genérico, se cambia el tono según el material.
	var provisional: bool = names.size() > 0 and sound == names[names.size() - 1] and sound != names[0]
	var pitch: float = MATERIAL_PITCH[def.resolved_sound_material()] if provisional else 1.0
	if action == Action.DISCARD and provisional:
		pitch *= 0.85
		volume_db += 2.0
	_play_stream(parent, sound, volume_db - (4.0 if provisional and action == Action.ROTATE else 0.0), pitch)


## Sonido con nombre (fabricar, combinar) y su provisional.
static func play_named(parent: Node, sound_name: String, volume_db: float = -8.0) -> void:
	var names: PackedStringArray = [sound_name]
	if NAMED_PROVISIONAL.has(sound_name):
		names.append(NAMED_PROVISIONAL[sound_name])
	var sound: String = resolve(names)
	if sound != "" and parent != null:
		_play_stream(parent, sound, volume_db, 1.0)


static func _play_stream(parent: Node, sound: String, volume_db: float, pitch: float) -> void:
	var stream: AudioStream = Sfx.stream(sound)
	if stream == null:
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch * (1.0 + randf_range(-0.05, 0.05))
	player.bus = &"Interfaz"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _exists(sound_name: String) -> bool:
	if sound_name == "":
		return false
	if not _exists_cache.has(sound_name):
		_exists_cache[sound_name] = ResourceLoader.exists(Sfx.DIR + sound_name + ".wav")
	return _exists_cache[sound_name]
