extends Node
## Bot of the bench pack: presses nothing and is done after 600 frames.

var ctx
var frames: int = 0


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	frames = frame


func _bot_done() -> bool:
	return frames >= 599


func _bot_result() -> Dictionary:
	return {"ok": true, "summary": "waited %d frames" % (frames + 1)}
