extends Node
## Bot: nothing to press. It waits until the carried puck has been released and has stopped, then checks both pucks.

var ctx
var state: Dictionary = {}
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	done = frame > 120 and float(state["carried_speed"]) < 0.01


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var slide: float = float(state["carried_slide"])
	var mu: float = 9.0 / (2.0 * 9.8 * slide) if slide > 0.01 else 0.0
	var stayed_in: bool = float(state["fast_min_z"]) > -20.05 and float(state["fast_min_y"]) > 0.0 and float(state["fast_max_y"]) < 0.1
	var ok: bool = done and stayed_in and float(state["fast_min_up"]) > 0.99 and int(state["fast_bounces"]) >= 1 \
		and int(state["gate_passes"]) >= 2 and int(state["held_frames"]) == 60 and absf(mu - float(state["law_friction"])) < 0.012
	# bodies made from parts took shape, mass and material from the part's metadata
	var puck_ok: bool = state["carried_kind"] == "puck" and absf(float(state["carried_mass"]) - 0.17) < 0.001 and state["carried_material"] == "rubber"
	var paddle_ok: bool = absf(float(state["paddle_mass"]) - 1.5) < 0.001 and state["paddle_material"] == "wood" and absf(float(state["paddle_y"]) - 0.05) < 0.02
	ok = ok and puck_ok and paddle_ok
	return {"ok": ok, "summary": "fast puck at 30 m/s: turned back at z = %.2f (rail face at -20.00), %d bounces, stayed flat (%.3f) and on the lane, gate saw it %d times; carried puck: held 60 frames, then slid %.2f m from 3 m/s (friction %.3f, law %.2f)" % [
			float(state["fast_min_z"]), int(state["fast_bounces"]), float(state["fast_min_up"]), int(state["gate_passes"]), slide, mu, float(state["law_friction"])],
		"fast_min_z": float(state["fast_min_z"]), "gate_passes": int(state["gate_passes"]), "carried_slide_m": slide,
		"parts_ok": puck_ok and paddle_ok, "carried_mass_kg": float(state["carried_mass"]), "paddle_mass_kg": float(state["paddle_mass"]), "friction_measured": mu, "friction_law": float(state["law_friction"]), "fast_bounces": int(state["fast_bounces"])}
