extends "res://tests/smoke_test.gd"
## Suite de regresión: las comprobaciones completas (smoke crítico + el resto).
## Reutiliza el cuerpo de smoke_test.gd forzando el modo completo, sin duplicar
## código ni estado de arena.
##
## Uso: godot --headless --path . --script res://tests/regression_test.gd


func _suite_solicitada() -> String:
	return "regression"
