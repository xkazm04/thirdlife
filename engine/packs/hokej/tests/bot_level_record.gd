extends Node
## Lane K5 round 4: the level chosen on HOME is an input. A session that starts at ROOKIE (HOME's PLAY NOW taps the key-less
## action `level_rookie` for frame 0; this bot does the same) plays its first 600 frames at ROOKIE: the shell applies the
## level on frame 0 from the input (screen.gd start_level). Selftest 830 records this run and replays it from the record alone.

const FRAMES: int = 600
var ctx
var done: bool = false
var level: String = ""
var core_hash: String = ""


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	if frame == 0:
		ctx.input.tap(&"level_rookie")
		return
	if frame == 1:
		level = String(ctx.root.get_meta(&"hokej_level", ""))
	if frame >= FRAMES:
		core_hash = String((ctx.pack_state().get("rink", {}) as Dictionary).get("hash", ""))
		done = true


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	return {"ok": done and level == "rookie", "summary": "level %s at frame 1; core hash %s after %d frames" % [level, core_hash, FRAMES]}
