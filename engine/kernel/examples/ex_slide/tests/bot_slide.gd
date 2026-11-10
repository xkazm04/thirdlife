extends Node
## Bot: waits until every block has stopped, then compares the measured slide distance with the law.
## A block pushed to speed v on friction mu stops after v*v / (2 * mu * g). The result carries the numbers.

var ctx
const G: float = 9.8

var still_frames: int = 0
var done: bool = false
var state: Dictionary = {}


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	if frame < 40:
		return
	state = ctx.pack_state()
	var moving: bool = false
	for key: String in state.keys():
		if state[key] is Dictionary and float(state[key]["speed"]) > 0.01:
			moving = true
	still_frames = 0 if moving else still_frames + 1
	done = still_frames >= 30


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var v: float = float(state.get("start_speed", 0.0))
	var out: Dictionary = {}
	var ok: bool = done
	var parts: PackedStringArray = PackedStringArray()
	for key: String in state.keys():
		if not (state[key] is Dictionary):
			continue
		var d: float = float(state[key]["distance"])
		var mu_law: float = float(state[key]["law_friction"])
		var mu_measured: float = v * v / (2.0 * G * d) if d > 0.001 else 0.0
		out[key + "_distance_m"] = snappedf(d, 0.001)
		out[key + "_expected_m"] = snappedf(v * v / (2.0 * G * mu_law), 0.001)
		out[key + "_friction_measured"] = snappedf(mu_measured, 0.0001)
		out[key + "_friction_law"] = mu_law
		if absf(mu_measured - mu_law) > 0.12 * mu_law:
			ok = false
		parts.append("%s %.2f m" % [key, d])
	out["ok"] = ok
	out["summary"] = "slide from %.1f m/s: %s" % [v, ", ".join(parts)]
	return out
