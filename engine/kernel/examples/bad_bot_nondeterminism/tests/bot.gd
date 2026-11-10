extends Node
## Bot of a deliberately bad example pack: kicks the crate every 20 frames, done after 120 frames.

var ctx
var frames_seen: int = 0


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	frames_seen += 1
	if frame % 20 == 5:
		ctx.input.tap(&"kick")


func _bot_done() -> bool:
	return frames_seen >= 120


func _bot_result() -> Dictionary:
	return {"ok": int(ctx.pack_state()["kicks"]) >= 5, "summary": "%d kicks in %d frames" % [int(ctx.pack_state()["kicks"]), frames_seen]}
