class_name TestCase
extends RefCounted
## Base de las pruebas: cada método que empieza por `test_` es una prueba.
## (Ejecutor mínimo mientras no se instale GUT; ver docs/tech/tests.md.)

var failures: PackedStringArray = []
var current: String = ""


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s: %s" % [current, message])


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("%s: %s (esperado %s, obtenido %s)" % [current, message, str(expected), str(actual)])
