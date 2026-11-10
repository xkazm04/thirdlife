extends Node
## Bot: watches the four lanes of the integration example and decides each from measured numbers. It presses
## nothing (the pack moves by itself); it is done when the ball has stopped, both parts have settled and the car
## has braked to a halt.

var ctx
var s: Dictionary = {}
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	done = frame > 330 and float(s["ice"]["speed"]) < 0.02 and s["wall"]["state"] == "settled" and s["crate"]["state"] == "settled" \
		and float(s["car"]["speed"]) < 0.1 and float(s["standin"]["car_speed"]) < 0.1


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var ice: Dictionary = s["ice"]
	var mu: float = 9.0 / (2.0 * 9.8 * maxf(0.01, float(ice["distance"])))        # from v0 = 3 m/s
	var ice_ok: bool = absf(mu - float(ice["law_friction"])) < 0.01 and ice["surface"] == "ice" and ice["material"] == "rubber"
	var wall_ok: bool = s["wall"]["state"] == "settled" and int(s["wall"]["pieces"]) == 16 and int(s["wall"]["awake"]) == 0 \
		and s["crate"]["state"] == "settled" and int(s["crate"]["pieces"]) >= 6 and int(s["crate"]["awake"]) == 0
	var w: Dictionary = s["walker"]
	var k: Dictionary = s["skater"]
	var biped_ok: bool = not bool(w["standin"]) and w["rig_family"] == "biped" and int(w["bones"]) == 29 and absf(float(w["top"]) - 2.3) < 0.1 \
		and float(w["leg_swing"]) > 0.2 and w["surface"] == "concrete" and k["mode"] == "skate" and float(k["top"]) > 9.0 \
		and float(k["coast"]) > 8.5 and k["surface"] == "ice"
	var c: Dictionary = s["car"]
	var car_ok: bool = not bool(c["standin"]) and absf(float(c["wheelbase"]) - 2.7) < 0.01 and float(c["top"]) > 9.0 \
		and float(c["wheel_spin_seen"]) > 0.5 and float(c["steer_wheel_yaw"]) < -0.05 and float(c["steer_turn"]) < -0.05 \
		and c["surface"] == "asphalt" and int(c["grounded_wheels"]) == 4
	var p: Dictionary = s["standin"]
	var standin_ok: bool = bool(p["walker_is_standin"]) and bool(p["car_is_standin"]) and absf(float(p["walk_top"]) - 2.3) < 0.1 and float(p["car_top"]) > 9.0
	return {"ok": done and ice_ok and wall_ok and biped_ok and car_ok and standin_ok,
		"summary": "kit ball on kit ice: slid %.2f m from 3 m/s (friction %.3f, law %.2f); kit wall %s into %d pieces, kit crate %s into %d; real biped rig (%d bones) walked at %.2f m/s with a leg swing of %.2f, skated to %.1f m/s and kept %.1f after 2 s; real car rig reached %.1f m/s, wheels spun, steering right turned the wheel %.2f rad and the car right" % [
			float(ice["distance"]), mu, float(ice["law_friction"]), s["wall"]["state"], int(s["wall"]["pieces"]), s["crate"]["state"], int(s["crate"]["pieces"]),
			int(w["bones"]), float(w["top"]), float(w["leg_swing"]), float(k["top"]), float(k["coast"]), float(c["top"]), float(c["steer_wheel_yaw"])],
		"kit_ice_ok": ice_ok, "kit_fracture_ok": wall_ok, "rig_biped_ok": biped_ok, "rig_vehicle_ok": car_ok, "standin_fallback_ok": standin_ok,
		"standin_walk_speed": float(p["walk_top"]), "standin_car_top_speed": float(p["car_top"]),
		"ice_friction_measured": mu, "ice_friction_law": float(ice["law_friction"]), "ball_mass_kg": float(ice["mass"]),
		"kit_bodies_tagged": int(s["kit_bodies_tagged"]), "wall_pieces": int(s["wall"]["pieces"]), "crate_pieces": int(s["crate"]["pieces"]),
		"wall_impulse": float(s["wall"]["impulse"]), "crate_impulse": float(s["crate"]["impulse"]),
		"walker_surface": str(w["surface"]), "skater_surface": str(k["surface"]), "car_surface": str(c["surface"]), "car_grounded_wheels": int(c["grounded_wheels"]),
		"walk_speed": float(w["top"]), "leg_swing": float(w["leg_swing"]), "skate_speed": float(k["top"]), "skate_coast": float(k["coast"]),
		"car_top_speed": float(c["top"]), "car_mass_kg": float(c["mass"]), "steer_wheel_yaw": float(c["steer_wheel_yaw"]), "steer_turn": float(c["steer_turn"])}
