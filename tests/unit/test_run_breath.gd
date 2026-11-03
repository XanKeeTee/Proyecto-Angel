extends TestCase
## Aliento para correr (RunBreath): se agota corriendo, se recupera andando o parado, y el
## Cuerpo bajo o el sangrado lo empeoran.


func _run_until_winded(b: RunBreath, limit: float = 30.0) -> float:
	var t: float = 0.0
	while not b.winded and t < limit:
		b.tick(0.05, 1.0, true)
		t += 0.05
	return t


func test_se_agota_en_unos_segundos() -> void:
	var b: RunBreath = RunBreath.new()
	var fired: Array[bool] = [false]
	b.exhausted.connect(func() -> void: fired[0] = true)
	check(b.can_run(), "con el aliento lleno puede correr")
	var t: float = _run_until_winded(b)
	check(t > 3.0 and t < 6.0, "aguanta unos pocos segundos (%.1f s)" % t)
	check(b.winded and not b.can_run(), "agotado no puede correr")
	check(fired[0], "avisa al agotarse (respiración agitada)")


func test_se_recupera_parado_antes_que_andando() -> void:
	var still: RunBreath = RunBreath.new()
	var walking: RunBreath = RunBreath.new()
	_run_until_winded(still)
	_run_until_winded(walking)
	for i: int in 60:  # 3 s
		still.tick(0.05, 0.0, false)
		walking.tick(0.05, 0.0, true)
	check(still.amount > walking.amount, "parado se recupera más deprisa (%.2f > %.2f)" % [still.amount, walking.amount])
	check(walking.amount > 0.0, "andando también se recupera")
	check(still.can_run(), "tras 3 s parado puede volver a correr")
	for i: int in 400:  # 20 s
		still.tick(0.05, 0.0, false)
	check_eq(still.amount, 1.0, "acaba lleno")


func test_no_vuelve_a_correr_hasta_recuperar_una_parte() -> void:
	var b: RunBreath = RunBreath.new()
	_run_until_winded(b)
	b.tick(1.0, 0.0, false)
	b.tick(0.3, 0.0, false)
	check(b.amount > 0.0 and b.amount < RunBreath.RECOVER_TO_RUN, "algo recuperado (%.2f)" % b.amount)
	check(not b.can_run(), "pero aún no basta para correr")


func test_cuerpo_bajo_y_sangrado_empeoran() -> void:
	var fit: RunBreath = RunBreath.new()
	fit.set_condition(0.82, false)
	var hurt: RunBreath = RunBreath.new()
	hurt.set_condition(0.25, false)
	var bleeding: RunBreath = RunBreath.new()
	bleeding.set_condition(0.82, true)
	var t_fit: float = _run_until_winded(fit)
	check(_run_until_winded(hurt) < t_fit * 0.7, "con el Cuerpo bajo se agota antes")
	check(_run_until_winded(bleeding) < t_fit * 0.8, "sangrando se agota antes")
	check(hurt.speed_multiplier() < fit.speed_multiplier(), "con el Cuerpo bajo corre menos")
	check(bleeding.speed_multiplier() < fit.speed_multiplier(), "sangrando corre menos")
	check(fit.speed_multiplier() >= 1.45 and fit.speed_multiplier() <= 1.6, "en forma, ×1,45–1,6")
	check(hurt.speed_multiplier() > 1.0, "aun herido, correr es algo más rápido que andar")
