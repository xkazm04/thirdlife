extends Node
## Require the post itself among the blockers and restoration throughout the
## clear window. The walker's measured x independently verifies both sight lines.

var ctx
var state: Dictionary = {}


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(_frame: int) -> void:
	state = ctx.pack_state()


func _bot_done() -> bool:
	return state.get("done", false)


func _bot_result() -> Dictionary:
	var windows: Dictionary = state.get("windows", {})
	var ok := _bot_done() and windows.size() == 3
	if ok:
		var off: Dictionary = windows.behind_off
		var on: Dictionary = windows.behind_on
		var clear: Dictionary = windows.clear_on
		for w: Dictionary in [off, on, clear]:
			ok = ok and w.samples == 11
		ok = ok and absf(off.min_x) < 0.35 and absf(on.max_x) < 0.35 and clear.min_x > 2.0
		ok = ok and off.max_count == 0 and off.max_alpha_loss < 0.001
		ok = ok and on.min_count == 1 and on.max_count == 1 and on.pillar_samples == 11 and on.min_alpha_loss >= 0.65
		ok = ok and clear.max_count == 0 and clear.max_alpha_loss < 0.001
	return {"ok": ok, "windows": windows, "summary": "checked %d sight-line windows" % windows.size()}
