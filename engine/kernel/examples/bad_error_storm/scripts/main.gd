extends Node
## Deliberately bad: a runtime error on every frame. More than 20 errors trip the watchdog (exit code 3).

var missing = null


func _pack_setup(_ctx) -> void:
	pass


func _pack_start() -> void:
	pass


func _pack_tick(_frame: int) -> void:
	missing.call("anything")
