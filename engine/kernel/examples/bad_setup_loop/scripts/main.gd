extends Node
## Deliberately bad: _pack_setup never returns. The watchdog ends the run (exit code 3) after the setup limit.

var spins: int = 0


func _pack_setup(_ctx) -> void:
	while true:
		spins += 1


func _pack_start() -> void:
	pass
