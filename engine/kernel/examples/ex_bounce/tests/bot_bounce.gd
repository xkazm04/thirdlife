extends Node
## Bot: nothing to press here. It waits for the game to end (five pellets in the bin) and for four seconds of
## bouncing, then compares each ball's first rebound with the law: a ball dropped from h on a pair with
## restitution e comes back to e*e*h.

var ctx
var state: Dictionary = {}
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	done = frame >= 240 and state["state"] == "over"


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var h: float = float(state.get("drop_height", 0.0))
	var out: Dictionary = {}
	var ok: bool = done and state["winner"] == "bin" and state["reason"] == "score" and int(state["scores"]["bin"]) == 5
	var parts: PackedStringArray = PackedStringArray()
	for key: String in state.keys():
		if not (state[key] is Dictionary) or not (state[key] as Dictionary).has("rebound"):
			continue
		var rebound: float = float(state[key]["rebound"])
		var e_law: float = float(state[key]["law"])
		var e_measured: float = sqrt(maxf(0.0, rebound) / h)
		out[key + "_rebound_m"] = snappedf(rebound, 0.001)
		out[key + "_expected_m"] = snappedf(e_law * e_law * h, 0.001)
		out[key + "_restitution_measured"] = snappedf(e_measured, 0.001)
		out[key + "_restitution_law"] = e_law
		if absf(e_measured - e_law) > 0.06:
			ok = false
		parts.append("%s %.2f (law %.2f)" % [key, e_measured, e_law])
	out["ok"] = ok
	out["summary"] = "restitution measured from the first rebound: %s; %d pellets spawned, 5 scored, game over by %s" % [
		", ".join(parts), int(state.get("spawned", 0)), str(state.get("reason", ""))]
	out["spawned"] = int(state.get("spawned", 0))
	return out
