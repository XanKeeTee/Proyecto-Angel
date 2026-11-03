extends TestCase
## Planificador de sustos pequeños (lógica pura): enfriamientos, espera global, usos,
## contexto y geometría del haz de la linterna.


func _scare(id: String, cooldown: float = 60.0) -> ScareDef:
	var s: ScareDef = ScareDef.new()
	s.id = StringName(id)
	s.cooldown = cooldown
	return s


func _profile(scares: Array[ScareDef]) -> HorrorProfile:
	var p: HorrorProfile = HorrorProfile.new()
	p.scares = scares
	p.gap_calm = Vector2(10.0, 10.0)
	p.gap_uneasy = Vector2(4.0, 4.0)
	return p


func _context(now: float, unease: float = 0.0) -> ScareContext:
	var c: ScareContext = ScareContext.new()
	c.now = now
	c.unease = unease
	c.cell = Vector2i(5, 5)
	return c


func test_respeta_el_enfriamiento_de_cada_susto() -> void:
	var only: ScareDef = _scare("portazo", 60.0)
	var planner: ScarePlanner = ScarePlanner.new(_profile([only]), 1)
	planner.schedule(0.0, 0.0)
	check(planner.next(_context(5.0)) == null, "antes de la espera global no hay susto")
	check(planner.next(_context(10.0)) == only, "a los 10 s sale el primero")
	# La espera global ya ha pasado (10 s), pero el susto sigue enfriándose (60 s).
	check(planner.next(_context(25.0)) == null, "no repite antes de su enfriamiento")
	check(planner.next(_context(45.0)) == null, "sigue sin repetir a los 35 s")
	check(planner.next(_context(71.0)) == only, "vuelve a salir pasado el enfriamiento")


func test_la_mente_baja_acorta_la_espera() -> void:
	var planner: ScarePlanner = ScarePlanner.new(_profile([_scare("a")]), 2)
	planner.schedule(0.0, 0.0)
	check_eq(planner.next_at(), 10.0, "con la Mente alta, espera larga")
	planner.schedule(0.0, 1.0)
	check_eq(planner.next_at(), 4.0, "con la Mente muy baja, espera corta")


func test_no_repite_el_ultimo_si_hay_otros() -> void:
	var a: ScareDef = _scare("a", 0.0)
	var b: ScareDef = _scare("b", 0.0)
	var c: ScareDef = _scare("c", 0.0)
	var profile: HorrorProfile = _profile([a, b, c])
	profile.recent_factor = 0.0
	profile.memory = 2
	var planner: ScarePlanner = ScarePlanner.new(profile, 3)
	var previous: Array[StringName] = []
	for i: int in 30:
		var picked: ScareDef = planner.pick(_context(float(i)))
		check(not previous.has(picked.id), "no repite ninguno de los dos últimos (%d)" % i)
		planner.mark(picked, _context(float(i)))
		previous.append(picked.id)
		if previous.size() > 2:
			previous.pop_front()


func test_limite_de_usos_y_hold() -> void:
	var once: ScareDef = _scare("cara", 0.0)
	once.max_uses = 1
	var planner: ScarePlanner = ScarePlanner.new(_profile([once]), 4)
	planner.schedule(0.0, 0.0)
	check(planner.next(_context(10.0)) == once, "sale una vez")
	check(planner.next(_context(100.0)) == null, "no vuelve a salir: max_uses = 1")
	planner.hold(100.0, 20.0)
	check(not planner.is_due(110.0), "hold retrasa el siguiente susto")
	check(planner.is_due(120.0), "pasado el hold, vuelve a tocar")


func test_contexto_linterna_zona_mente_y_banderas() -> void:
	var s: ScareDef = _scare("sombra")
	s.flashlight = ScareDef.Light.ON
	s.min_unease = 0.3
	s.regions = [Rect2i(0, 0, 10, 10)]
	s.forbids_flags = [&"prologo_terminado"]
	var c: ScareContext = _context(0.0, 0.5)
	check(not s.fits(c), "necesita la linterna encendida")
	c.flashlight_on = true
	check(s.fits(c), "con linterna, en la zona y con la Mente baja")
	c.cell = Vector2i(20, 20)
	check(not s.fits(c), "fuera de la zona")
	c.cell = Vector2i(5, 5)
	c.unease = 0.1
	check(not s.fits(c), "con la Mente alta no sale")
	c.unease = 0.5
	c.flags[&"prologo_terminado"] = true
	check(not s.fits(c), "una bandera prohibida lo impide")


func test_geometria_del_haz() -> void:
	var origin: Vector2 = Vector2(100, 100)
	check(HorrorDirector.beam_touches(origin, 0.0, Vector2(250, 110), 22.0, 250.0), "delante, dentro del cono")
	check(not HorrorDirector.beam_touches(origin, 0.0, Vector2(250, 220), 22.0, 250.0), "fuera del ángulo")
	check(not HorrorDirector.beam_touches(origin, 0.0, Vector2(400, 100), 22.0, 250.0), "fuera del alcance")
	check(not HorrorDirector.beam_touches(origin, PI, Vector2(250, 100), 22.0, 250.0), "a la espalda no la alumbra")


func test_datos_del_prologo() -> void:
	var profile: HorrorProfile = load("res://data/horror/prologo.tres")
	check(profile.scares.size() >= 10, "hay una docena de sustos")
	var ids: Dictionary[StringName, bool] = {}
	for s: ScareDef in profile.scares:
		check(s.id != &"" and not ids.has(s.id), "id único: " + String(s.id))
		ids[s.id] = true
		check(s.cooldown >= 60.0, "%s: enfriamiento de al menos un minuto" % s.id)
		check(s.mind_loss <= 2, "%s: los sustos pequeños casi no cuestan Mente" % s.id)
