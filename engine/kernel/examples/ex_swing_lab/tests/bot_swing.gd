extends Node

var ctx
var state: Dictionary


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(_frame: int) -> void:
	state = ctx.pack_state()


func _bot_done() -> bool:
	return state.get("lifetimes", []).size() == 3


func _bot_result() -> Dictionary:
	var ok: bool = state.lifetimes == [20, 40, 46] and state.freeze == 6 and not state.trail_alive
	ok = ok and state.tag_text == "HEAVY" and state.tag_color == TLStyle.color("car_red").to_html(false)
	return {"ok": ok, "summary": "trail lifetimes %s, frozen %d" % [state.lifetimes, state.freeze], "observed": state}
