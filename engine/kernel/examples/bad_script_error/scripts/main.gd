extends Node
## Deliberately bad: a runtime error at frame 30. Godot prints it and carries on; the runner must fail the run.

var thing = null


func _pack_setup(_ctx) -> void:
	pass


func _pack_start() -> void:
	pass


func _pack_tick(frame: int) -> void:
	if frame == 30:
		var size: int = thing.size()
		print(size)
