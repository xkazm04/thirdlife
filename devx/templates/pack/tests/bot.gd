extends Node
## Bot: presses "nudge" now and then and is done when a ball has passed the finish line.
## It reads state only through ctx.pack_state() and presses only declared actions.

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
	return {"ok": done and int(state.get("nudges", 0)) >= 1,
		"summary": "%d ball(s) past the finish line after %d nudges" % [int(state.get("past_finish", 0)), int(state.get("nudges", 0))],
		"past_finish": int(state.get("past_finish", 0)), "nudges": int(state.get("nudges", 0))}
