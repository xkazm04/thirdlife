extends "bot_match_hand.gd"
## The player's first match as he will meet it (K3 round 10): HOME's PLAY NOW at ROOKIE (the key-less `level_rookie` tapped for
## frame 0, as screen.gd's front end does and bot_level_record.gd checks), then the whole match by bot_match_hand.gd's hand
## through the key and mouse mapping only, and END_HOLD frames after the final whistle with nothing pressed (the end card).
## Its hand is the pack's scripted one, NOT thirdjam's playtester: a playtester seated in a second core and pressed as keys
## parts from the pack's match within seconds (REPORT r10: the puck 39 m apart at 10 s), so its decisions would be about
## another match. Passes when the level is ROOKIE, the match ends inside MAX_FRAMES and the end is held.

const END_HOLD: int = 300
var level: String = ""
var over_at: int = -1


func _bot_tick(frame: int) -> void:
	if frame == 0:
		ctx.input.tap(&"level_rookie")
		return
	if frame == 1:
		level = String(ctx.root.get_meta(&"hokej_level", ""))
	if over_at >= 0:
		ctx.input.release_all()
		if frame >= over_at + END_HOLD:
			done = true
		return
	super._bot_tick(frame)
	if done:
		done = false
		over_at = frame


func _bot_result() -> Dictionary:
	var r: Dictionary = super._bot_result()
	var s: Dictionary = ctx.pack_state()
	r["ok"] = done and level == "rookie" and bool(s["over"])
	r["summary"] = "level %s; %s; the end held %d frames from frame %d" % [level, String(r["summary"]), END_HOLD, over_at]
	(r["metrics"] as Dictionary).erase("raw")
	return r
