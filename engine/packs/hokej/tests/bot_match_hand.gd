extends Node
## A whole match (thirdjam's regular cartridge on K1's core, the bots at data/match.json's level) played by a scripted
## hand through the pack's key and mouse mapping only: the eight skate keys in the camera's frame (re-decided every
## `REACT` frames, as jam.ScriptHumanCam decides, HokejGameMode.cpp:864-872), Shift, the mouse buttons and the cursor on the
## ice (with its pixel, kernel 1.17). Its decisions are a plain script, NOT thirdjam's playtester (RinkCore v1 does not expose
## FJamPlayerBot's inputs): chase the loose puck with the cursor on it; carrying, skate at the net and, inside 14 m, aim at it
## and hold the left button 18 frames (a charged shot on the release); an opponent carrying within 2.5 m: the right button
## (the body check) or Space (the poke); at a faceoff, the left button at the drop. Up to MAX_FRAMES or the match's end.
## Its result carries, per frame, the raw devices the pack sent, the FJamInput the core's glue made of them and the core's hash
## (for rink_rawtrace.gd and the core-only replay tool).

const REACT: int = 12
const MAX_FRAMES: int = 10800
const SKATE: Array = [&"k_w", &"k_s", &"k_a", &"k_d"]

var ctx
var decided: int = -100000
var keys: String = ""
var shot_hold: int = 0
var tap_left: int = 0
var tap_right: int = 0
var tap_space: int = 0
var inputs: Array = []
var raws: Array = []
var hashes: Array = []
var shots: int = 0
var checks: int = 0
var carried_frames: int = 0
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _keys_toward(s: Dictionary, to: Vector2) -> String:
	if to.length() < 0.5:
		return ""
	var want: Vector2 = to.normalized()
	var cy: float = deg_to_rad(float(s["cam_yaw"]))
	var a: float = atan2(want.dot(Vector2(-sin(cy), cos(cy))), want.dot(Vector2(cos(cy), sin(cy))))
	var a8: float = roundf(a / (PI / 4.0)) * (PI / 4.0)
	var kx: float = sin(a8)
	var ky: float = cos(a8)
	return ("W" if ky > 0.3 else "") + ("S" if ky < -0.3 else "") + ("D" if kx > 0.3 else "") + ("A" if kx < -0.3 else "")


func _bot_tick(frame: int) -> void:
	var s: Dictionary = ctx.pack_state()
	if frame > 0:
		inputs.append(s["in"])
		raws.append(s["raw"])
		hashes.append(String(s["rink"]["hash"]))
	if frame >= MAX_FRAMES or bool(s.get("over", false)):
		done = true
		ctx.input.release_all()
		return
	var me := Vector2(float(s["x"]), float(s["y"]))
	var puck := Vector2(float(s["puck_x"]), float(s["puck_y"]))
	var carrier: int = int(s["carrier"])
	var net := Vector2(41.0 if int(s["team"]) == 0 else -41.0, 0.0)
	var target: Vector2 = puck
	var aim: Vector2 = puck
	var sprint: bool = false
	if int(s["phase"]) == 3:                                   # a faceoff: wait, then the left button at the drop
		target = me
		if int(s["faceoff"]) <= 1 and tap_left == 0:
			tap_left = 2
	elif carrier == int(s["human"]):
		carried_frames += 1
		target = net
		aim = net
		sprint = me.distance_to(net) > 20.0
		if me.distance_to(net) < 14.0 and shot_hold == 0:
			shot_hold = 18
	elif carrier >= 0 and me.distance_to(puck) < 2.5 and tap_right == 0 and tap_space == 0:
		if frame % 2 == 0:
			tap_right = 2
		else:
			tap_space = 2
		checks += 1
	else:
		sprint = me.distance_to(puck) > 15.0
	if frame - decided >= REACT:
		keys = _keys_toward(s, target - me)
		decided = frame
	for i: int in 4:
		if keys.contains(["W", "S", "A", "D"][i]):
			ctx.input.press(SKATE[i])
		else:
			ctx.input.release(SKATE[i])
	if sprint:
		ctx.input.press(&"k_shift")
	else:
		ctx.input.release(&"k_shift")
	# the cursor on the aim point (a moving hand: its pixel follows the point)
	ctx.input.set_aim(&"aim", Vector3(aim.x, 0.0, aim.y), Vector2(640.0 + aim.x, 360.0 + aim.y))
	# the left button: a held shot (released on its last frame: the charged shot fires), or a tap
	if shot_hold > 0:
		ctx.input.press(&"m_left")
		shot_hold -= 1
		if shot_hold == 0:
			shots += 1
			ctx.input.release(&"m_left")
	elif tap_left > 0:
		if tap_left == 2:
			ctx.input.press(&"m_left")
		else:
			ctx.input.release(&"m_left")
		tap_left -= 1
	else:
		ctx.input.release(&"m_left")
	if tap_right > 0:
		if tap_right == 2:
			ctx.input.press(&"m_right")
		else:
			ctx.input.release(&"m_right")
		tap_right -= 1
	if tap_space > 0:
		if tap_space == 2:
			ctx.input.press(&"k_space")
		else:
			ctx.input.release(&"k_space")
		tap_space -= 1


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var s: Dictionary = ctx.pack_state()
	var score: Array = s["rink"]["score"]
	var ok: bool = done and inputs.size() > 600 and carried_frames > 0 and shots > 0
	return {"ok": ok, "summary": "%d frames, score %d:%d%s, carried %d frames, %d shots, %d checks/pokes, core hash %s" % [inputs.size(), int(score[0]), int(score[1]),
		" (over)" if bool(s["over"]) else "", carried_frames, shots, checks, String(s["rink"]["hash"])],
		"frames": ctx.frame, "metrics": {"carried_frames": carried_frames, "shots": shots, "raw": {"inputs": inputs, "hashes": hashes, "devices": raws}}}
