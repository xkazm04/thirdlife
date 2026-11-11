extends Node
## N4 hole: `load(` let a relative path through (the engine reads it from its own root, so the kernel's scripts were
## loadable), judged only the first piece of a path built from pieces, and was not seen across a line break.
## Every line from "FENCE BEGIN" to "FENCE END" holds exactly one pattern that lint must now report with its line.


func _pack_setup(_ctx) -> void:
	pass


func _pack_start() -> void:
	pass


func reach() -> void:
# FENCE BEGIN
	var a = load("kernel/runner/worker.gd")
	var b = load("res://kits/" + "../kernel/host/host.gd")
# FENCE END
	var wrapped = load \
		("res://kernel/runner/worker.gd")
	var fine = preload("main.gd")
