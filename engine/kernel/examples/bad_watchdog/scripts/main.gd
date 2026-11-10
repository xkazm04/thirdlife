extends Node
## Deliberately bad: an endless loop at frame 20. The run must end with exit code 3 and outcome "watchdog".

var spins: int = 0


func _pack_setup(_ctx) -> void:
	pass


func _pack_start() -> void:
	pass


func _pack_tick(frame: int) -> void:
	if frame == 20:
		while true:
			spins += 1
