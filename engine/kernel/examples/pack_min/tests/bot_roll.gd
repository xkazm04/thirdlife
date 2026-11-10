extends Node
## Bot: waits for the balls to come down the ramp, presses "nudge" a few times through the input door, and is
## satisfied when at least one ball has passed the finish line. It reads game state only through _pack_state().

var ctx
var done: bool = false
var state: Dictionary = {}


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	if frame > 120 and frame % 90 == 0:
		ctx.input.tap(&"nudge")
	if int(state["past_finish"]) >= 1:
		done = true


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	return {"ok": done and int(state.get("nudges", 0)) >= 1, "summary": "%d ball(s) past the finish line after %d nudges" % [int(state.get("past_finish", 0)), int(state.get("nudges", 0))],
		"past_finish": int(state.get("past_finish", 0)), "nudges": int(state.get("nudges", 0)), "lead_x": float(state.get("lead_x", 0.0))}
