extends Node
## Row A is a control. Row C's displacement ends with the actual guard stun.

var ctx
var state: Dictionary = {}


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(_frame: int) -> void:
	state = ctx.pack_state()


func _bot_done() -> bool:
	return state.get("done", false)


func _bot_result() -> Dictionary:
	var rows: Array = state.get("pairs", [])
	var ok := _bot_done() and rows.size() == 3
	if ok:
		var b: Dictionary = rows[1]
		var c: Dictionary = rows[2]
		ok = b.min_centres >= b.radii_sum - 0.001 and c.min_centres >= c.radii_sum - 0.001
		ok = ok and c.contact.defender == "guardbroken" and c.stunned_ticks == 120 and c.stunned_travel > 0.5
	return {"ok": ok, "pairs": rows, "summary": "measured %d charging pairs" % rows.size()}
