class_name HorrorProfile
extends Resource
## Ajustes del terror ambiental de un mapa: la lista de sustos pequeños, el ritmo entre ellos
## y la entidad que sigue al jugador. Un `.tres` por mapa en data/horror/.

@export var scares: Array[ScareDef] = []

@export_group("Ritmo de los sustos")
## Espera entre dos sustos (segundos, al azar en el rango) con la Mente alta…
@export var gap_calm: Vector2 = Vector2(55.0, 110.0)
## …y con la Mente muy baja.
@export var gap_uneasy: Vector2 = Vector2(28.0, 60.0)
## Silencio tras un evento guionizado, un texto o un susto de la entidad (segundos).
@export var quiet_after_event: float = 20.0
## Cuántos sustos recientes se recuerdan para no repetirlos (su peso se reduce mucho).
@export var memory: int = 3
## Factor del peso de un susto reciente.
@export_range(0.0, 1.0) var recent_factor: float = 0.15

@export_group("Entidad")
@export var stalker_enabled: bool = true
## Probabilidad por segundo de que aparezca mientras el jugador camina (Mente alta / muy baja).
@export var stalker_chance: Vector2 = Vector2(0.012, 0.05)
## Primera aparición posible tras empezar el mapa (segundos).
@export var stalker_first_delay: float = 75.0
## Enfriamiento tras desaparecer (segundos, al azar en el rango).
@export var stalker_cooldown: Vector2 = Vector2(90.0, 170.0)
## Segundos caminando seguidos antes de que pueda aparecer.
@export var stalker_walk_time: float = 2.0
## Distancia a la que aparece, detrás (píxeles, a lo largo del camino recorrido).
@export var stalker_spawn_distance: Vector2 = Vector2(120.0, 170.0)
## Velocidad (relativa a la máxima del jugador) con la que lo sigue.
@export var stalker_speed: float = 0.82
## Si se acerca tanto (píxeles) sin que lo alumbren, «alcanza» al jugador.
@export var stalker_reach: float = 24.0
## Segundos máximos que dura antes de irse por su cuenta.
@export var stalker_lifetime: Vector2 = Vector2(14.0, 22.0)
## Mente que resta si alcanza al jugador.
@export var stalker_mind_loss: int = 3
## Mente que resta al verla deshacerse con la linterna (un susto, pero lo has espantado tú).
@export var stalker_seen_mind_loss: int = 1
## Ángulo (grados) y alcance (píxeles) del haz de la linterna que la deshace.
@export var beam_half_angle: float = 22.0
@export var beam_range: float = 250.0
