extends Node
## Bot of a deliberately bad example pack: presses `flip` once, at frame 200; done after 300 frames (before the push).

var ctx
var frames_seen: int = 0


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	frames_seen += 1
	if frame == 200:
		ctx.input.tap(&"flip")


func _bot_done() -> bool:
	return frames_seen >= 300


func _bot_result() -> Dictionary:
	return {"ok": int(ctx.pack_state()["flips"]) > 0, "summary": "%d flips in %d frames" % [int(ctx.pack_state()["flips"]), frames_seen]}
