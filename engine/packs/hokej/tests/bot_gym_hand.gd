extends Node
## The gym's scripted hand (data/hand_gym.json): start, sprint, hard turns both ways, the S pull-back, a lap along the boards
## through the corners, a stop near the end boards. It plays through the keys alone, as a person's keyboard does (a perfect
## hand: every key on the frame it is decided). 'goto' segments steer the way thirdjam's jam.ScriptHumanCam does
## (S/JamGame/Private/HokejGameMode.cpp:864-872): the wanted direction becomes eight-way keys in the camera's frame of the
## last sim frame, re-decided every `react` frames. Its result carries the per-frame trace (skater and camera) that
## the side-by-side compares with thirdjam's own camera code (docs/shifts/2026-11-24-night/lanes/K3-shell/).

const KEYS: Dictionary = {"W": &"k_w", "S": &"k_s", "A": &"k_a", "D": &"k_d", "+": &"k_shift", "C": &"k_ctrl"}

var ctx
var hand: Dictionary
var trace: Array = []
var decided: int = -1000000
var held: String = ""
var max_speed: float = 0.0
var max_x: float = -1e9
var min_x: float = 1e9
var bad: int = 0
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c
	hand = ctx.read_json("hand_gym.json")


func _segment(frame: int) -> Dictionary:
	for g: Dictionary in hand["segments"]:
		if frame >= int(g["from"]) and frame < int(g["to"]):
			return g
	return {}


func _press(keys: String) -> void:
	for k: String in KEYS:
		if keys.contains(k):
			ctx.input.press(KEYS[k])
		else:
			ctx.input.release(KEYS[k])


func _bot_tick(frame: int) -> void:
	if frame == 0:
		ctx.input.press(&"gym")          # the control rules are tested on the gym (one skater, empty ice)
	var s: Dictionary = ctx.pack_state()
	if true:
		trace.append([int(s["frame"]), snappedf(s["x"], 1e-5), snappedf(s["y"], 1e-5), snappedf(s["yaw_deg"], 1e-4),
			snappedf(s["cam_x"], 1e-5), snappedf(s["cam_y"], 1e-5), snappedf(s["cam_h"], 1e-5), snappedf(s["cam_pitch"], 1e-4), snappedf(s["cam_yaw"], 1e-4)])
		for k: String in ["x", "y", "cam_x", "cam_y", "cam_h", "cam_pitch", "cam_yaw"]:
			if is_nan(float(s[k])) or is_inf(float(s[k])):
				bad += 1
		max_speed = maxf(max_speed, float(s["speed"]))
		max_x = maxf(max_x, float(s["x"]))
		min_x = minf(min_x, float(s["x"]))
	if frame >= int(hand["frames"]):
		_press("")
		done = true
		return
	var g: Dictionary = _segment(frame)
	if g.has("keys"):
		held = ""
		decided = -1000000
		_press(String(g["keys"]))
		return
	# goto: jam.ScriptHumanCam's eight ways in the camera's frame (HokejGameMode.cpp:864-872)
	var to: Vector2 = Vector2(float(g["goto"][0]), float(g["goto"][1])) - Vector2(float(s["x"]), float(s["y"]))
	if frame - decided >= int(hand["react"]) and to.length() > 1e-6:
		var want: Vector2 = to.normalized()
		var cy: float = deg_to_rad(float(s["cam_yaw"]))
		var fwd := Vector2(cos(cy), sin(cy))
		var right := Vector2(-sin(cy), cos(cy))
		var a: float = atan2(want.dot(right), want.dot(fwd))
		var a8: float = roundf(a / (PI / 4.0)) * (PI / 4.0)
		var kx: float = sin(a8)
		var ky: float = cos(a8)
		held = ("W" if ky > 0.3 else "") + ("S" if ky < -0.3 else "") + ("D" if kx > 0.3 else "") + ("A" if kx < -0.3 else "")
		decided = frame
	_press(held + ("+" if bool(g.get("sprint", false)) else "") + ("C" if bool(g.get("brake", false)) else ""))


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var s: Dictionary = ctx.pack_state()
	var ok: bool = done and bad == 0 and trace.size() > int(hand["frames"]) and max_speed > 11.0 and max_x - min_x > 40.0
	return {"ok": ok, "summary": "%d frames, top speed %.2f m/s, x %.1f..%.1f, ends at (%.2f, %.2f) speed %.2f" % [trace.size(), max_speed, min_x, max_x, s["x"], s["y"], s["speed"]],
		"frames": ctx.frame, "metrics": {"top_speed": max_speed, "end_speed": float(s["speed"]), "raw": {"trace": trace}}}
