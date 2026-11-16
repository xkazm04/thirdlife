extends Node
## Deliberately bad: _bot_result returns ok without a summary. Alone the runner fails the bot for it; a world must too.

var frames: int = 0


func _bot_setup(_ctx) -> void:
	pass


func _bot_tick(frame: int) -> void:
	frames = frame


func _bot_done() -> bool:
	return frames >= 299


func _bot_result() -> Dictionary:
	return {"ok": true}
