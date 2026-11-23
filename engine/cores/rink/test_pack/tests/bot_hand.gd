extends Node
## A fixed hand through the input door: skate up-ice with sprint, turn, hold shoot for 30 frames every 4 s, a pass every
## 5 s, a check every 7 s. The same hand every run, so two runs and a replay must end on the same core hash.

var ctx
var state: Dictionary = {}
var last: int = 0


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	last = frame
	var phase: int = (frame / 120) % 4
	ctx.input.release_all()
	match phase:
		0: ctx.input.press(&"right")
		1: ctx.input.press(&"up")
		2: ctx.input.press(&"left")
		3: ctx.input.press(&"down")
	if frame % 300 < 180:
		ctx.input.press(&"sprint")
	if frame % 240 >= 200 and frame % 240 < 230:
		ctx.input.press(&"shoot")
	if frame % 300 == 150:
		ctx.input.tap(&"pass")
	if frame % 420 == 210:
		ctx.input.tap(&"check")


func _bot_done() -> bool:
	return last >= 3000


func _bot_result() -> Dictionary:
	var r: Dictionary = state.get("rink", {})
	return {"ok": not r.is_empty() and int(r.get("frame", 0)) > 0, "summary": "core frame %d score %s hash %s" % [int(r.get("frame", 0)), str(r.get("score", [])), str(r.get("hash", ""))],
		"core_frame": int(r.get("frame", 0)), "core_hash": str(r.get("hash", ""))}
