extends Node
## Input-driven pack tests share the runner lifecycle and read the previous physics frame.
var ctx
var done := false
var s: Dictionary = {}

func _bot_setup(c) -> void:
	ctx = c

func _bot_done() -> bool:
	return done

func _v(pair: Array) -> Vector2:
	return Vector2(pair[0], pair[1])

func _sk(id: String) -> Dictionary:
	for skater: Dictionary in s.skaters:
		if skater.id == id:
			return skater
	return {}

func _pos(id: String) -> Vector2:
	return _v(_sk(id).pos)

func _me() -> Dictionary:
	return _sk("b0")

func classic() -> bool:
	if s.mode != "base":
		ctx.input.tap(&"mode_base")
	elif s.has("level"):
		ctx.input.tap(&"level_none")
	else:
		return true
	return false
