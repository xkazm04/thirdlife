extends Node
## Bot of a deliberately bad example pack: done after 30 frames.

var frames_seen: int = 0


func _bot_setup(_ctx) -> void:
	pass


func _bot_tick(_frame: int) -> void:
	frames_seen += 1


func _bot_done() -> bool:
	return frames_seen >= 30


func _bot_result() -> Dictionary:
	return {"ok": true, "summary": "ran %d frames" % frames_seen}
