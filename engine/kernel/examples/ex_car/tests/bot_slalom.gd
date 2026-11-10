extends Node
## Bot: drives the slalom with the same input actions a player has (left, right, gas, brake, nitro), steering toward
## the next gate. After the lap it brakes twice from the same speed: once on asphalt, once on ice, and reports both
## stopping distances. Phases: slalom -> brake_asphalt -> to_ice -> brake_ice -> done.

const TEST_SPEED: float = 14.0

var ctx
var state: Dictionary = {}
var phase: String = "slalom"
var brake_from: Dictionary = {}
var asphalt_stop_m: float = -1.0
var ice_stop_m: float = -1.0
var asphalt_speed: float = 0.0
var ice_speed: float = 0.0
var slalom_frames: int = -1
var slalom_speed_limit: float = 13.0
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _steer_to(car: Dictionary, tx: float, tz: float) -> void:
	var dx: float = tx - float(car["x"])
	var dz: float = tz - float(car["z"])
	var dist: float = maxf(0.001, sqrt(dx * dx + dz * dz))
	var cross: float = (float(car["fx"]) * dz - float(car["fz"]) * dx) / dist
	ctx.input.set_axis(&"left", &"right", clampf(cross * 2.5, -1.0, 1.0))


func _hold_speed(car: Dictionary, target: float) -> void:
	ctx.input.press(&"gas", 1.0 if float(car["forward_speed"]) < target else 0.0)


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	var car: Dictionary = state["car"]
	match phase:
		"slalom":
			_steer_to(car, float(state["next_gate"][0]), float(state["next_gate"][1]))
			_hold_speed(car, slalom_speed_limit)
			# a short nitro burst on the way to the first gate
			if frame == 30:
				ctx.input.press(&"nitro")
			if frame == 75:
				ctx.input.release(&"nitro")
			if state["state"] == "over":
				slalom_frames = frame
				phase = "settle_asphalt"
		"settle_asphalt":      # straighten up and reach the test speed on asphalt
			_steer_to(car, 0.0, -400.0)
			_hold_speed(car, TEST_SPEED)
			if float(car["z"]) < -126.0 and float(car["forward_speed"]) >= TEST_SPEED - 0.5:
				_start_brake(car)
				asphalt_speed = float(car["speed"])
				phase = "brake_asphalt"
			elif float(car["z"]) < -146.0:
				phase = "to_ice"      # too late to test on asphalt: reported as -1
		"brake_asphalt":
			if float(car["speed"]) < 0.1:
				asphalt_stop_m = _stopped(car)
				ctx.input.release(&"brake")
				phase = "to_ice"
		"to_ice":
			_steer_to(car, 0.0, -400.0)
			_hold_speed(car, TEST_SPEED)
			if float(car["z"]) < -170.0 and car["surface"] == "ice" and float(car["forward_speed"]) >= TEST_SPEED - 0.5:
				_start_brake(car)
				ice_speed = float(car["speed"])
				phase = "brake_ice"
		"brake_ice":
			if float(car["speed"]) < 0.1:
				ice_stop_m = _stopped(car)
				done = true


func _start_brake(car: Dictionary) -> void:
	brake_from = car
	ctx.input.release(&"gas")
	ctx.input.set_axis(&"left", &"right", 0.0)
	ctx.input.press(&"brake")


func _stopped(car: Dictionary) -> float:
	return absf(float(car["z"]) - float(brake_from["z"]))


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var mu_asphalt: float = asphalt_speed * asphalt_speed / (2.0 * 9.8 * asphalt_stop_m) if asphalt_stop_m > 0.0 else 0.0
	var mu_ice: float = ice_speed * ice_speed / (2.0 * 9.8 * ice_stop_m) if ice_stop_m > 0.0 else 0.0
	var ok: bool = done and state["winner"] == "car" and state["reason"] == "laps" and int(state["nitro_starts"]) >= 1 \
		and asphalt_stop_m > 0.0 and ice_stop_m > 4.0 * asphalt_stop_m and absf(mu_ice - 0.1) < 0.03
	var pace: Dictionary = state["pace"]
	var pace_ok: bool = float(pace["progress"]) > float(pace["length"]) - 9.0 and float(pace["offset_max"]) < 2.5 and float(pace["speed"]) < 0.5
	ok = ok and pace_ok and int(state["horns"]) == 1 and int(state["flames_lit"]) == 1 and str(state["hud_speed"]).ends_with("km/h")
	return {"ok": ok, "summary": "slalom of 4 gates done in %d frames (top speed %.1f m/s, %d nitro burst, %d cone hits); braking from %.1f m/s: %.1f m on asphalt, %.1f m on ice; AI pace car followed the line for %.0f of %.0f m, at most %.2f m off it" % [
			slalom_frames, float(state["top_speed"]), int(state["nitro_starts"]), int(state["cone_hits"]), ice_speed, asphalt_stop_m, ice_stop_m,
			float(pace["progress"]), float(pace["length"]), float(pace["offset_max"])],
		"pace_progress_m": float(pace["progress"]), "pace_offset_max_m": float(pace["offset_max"]), "horns": int(state["horns"]), "hud_speed": str(state["hud_speed"]),
		"slalom_frames": slalom_frames, "top_speed": float(state["top_speed"]), "brake_asphalt_m": asphalt_stop_m, "brake_ice_m": ice_stop_m,
		"brake_asphalt_from": asphalt_speed, "brake_ice_from": ice_speed, "grip_measured_asphalt": mu_asphalt, "grip_measured_ice": mu_ice,
		"grip_law_asphalt": 1.0, "grip_law_ice": 0.1, "cone_hits": int(state["cone_hits"])}
