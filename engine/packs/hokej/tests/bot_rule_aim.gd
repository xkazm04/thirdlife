extends Node
## Rule: the cursor on the ice (AHokejGameMode::CursorAimFromHit, HokejGameMode.cpp:756-767). The skater stands; the aim is
## put at a distance d straight ahead of him. Inside 0.7 m (0.5 m once aiming) the stick is zero; outside it points from
## him to the point with a size 0.5 + 0.5 * clamp((d - 0.5) / 2.5, 0, 1). Each step holds 5 frames.
## [d, expect aiming, expect size]: enter at 0.8, hold at 0.6 (hysteresis), leave at 0.45, 0.6 again stays out, the ramp.
const STEPS: Array = [[0.6, false, 0.0], [0.69, false, 0.0], [0.8, true, 0.56], [0.6, true, 0.52], [0.51, true, 0.502],
	[0.45, false, 0.0], [0.6, false, 0.0], [0.71, true, 0.542], [1.75, true, 0.75], [3.0, true, 1.0], [5.0, true, 1.0], [0.3, false, 0.0]]

var ctx
var fails: Array = []
var passed: int = 0
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	if frame == 0:
		ctx.input.press(&"gym")          # the control rules are tested on the gym (one skater, empty ice)
	var s: Dictionary = ctx.pack_state()
	var i: int = frame / 5
	if frame > 0 and frame % 5 == 4 and i < STEPS.size():
		var st: Array = STEPS[i]
		var size: float = Vector2(float(s["stick_x"]), float(s["stick_y"])).length()
		if bool(s["aiming"]) == bool(st[1]) and absf(size - float(st[2])) < 1e-3:
			passed += 1
		else:
			fails.append("d=%.2f aiming=%s size=%.4f" % [st[0], str(s["aiming"]), size])
	if i >= STEPS.size():
		done = true
		return
	var d: float = float(STEPS[i][0])
	var yaw: float = deg_to_rad(float(s["yaw_deg"]))
	ctx.input.set_aim(&"aim", Vector3(float(s["x"]) + cos(yaw) * d, 0.0, float(s["y"]) + sin(yaw) * d))


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	return {"ok": done and fails.is_empty() and passed == STEPS.size(), "summary": "%d of %d aim steps as thirdjam's rule%s" % [passed, STEPS.size(), "" if fails.is_empty() else ": " + ", ".join(fails)],
		"frames": ctx.frame}
