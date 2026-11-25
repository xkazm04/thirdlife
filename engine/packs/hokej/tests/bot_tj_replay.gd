extends Node
## Proof: our camera against thirdjam's RENDERED game. data/tj_trace_regular_pro.json is thirdjam's own JAMCAM log of a match
## (the t5 build, cut hockey.regular, level pro, its measured hand jam.ScriptHuman 2): per camera step the human's position
## and yaw and the camera's pose. The bot presses `replay` on frame 0: the pack sets the skater from each row and steps our
## camera once a tick. Every pose must equal thirdjam's within 1 cm and 0.1 degree, except the rows inside a contact kick
## (the log's JAMKICK lines, CameraFollow.cpp:1269-1287: stair step 3, not ported), which are counted apart.

var ctx
var rows: Array = []
var kick_rows: Dictionary = {}
var checked: int = 0
var over: Array = []
var kicked: int = 0
var max_pos: float = 0.0
var max_h: float = 0.0
var max_pitch: float = 0.0
var max_yaw: float = 0.0
var boards: int = 0
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c
	var d: Dictionary = ctx.read_json("tj_trace_regular_pro.json")
	rows = d["rows"]
	var at: Dictionary = {}
	for i: int in rows.size():
		at[int(rows[i][0])] = i
	for k: Array in d["kicks"]:
		if at.has(int(k[0])):
			for j: int in int(k[1]):
				kick_rows[int(at[int(k[0])]) + j] = true


func _bot_tick(frame: int) -> void:
	if frame == 0:
		ctx.input.press(&"replay")
		return
	var s: Dictionary = ctx.pack_state()
	var i: int = int(s["replay_i"])
	if i >= 0 and i < rows.size() and i == frame - 1:
		var r: Array = rows[i]
		var dp: float = Vector2(float(s["cam_x"]) - float(r[4]), float(s["cam_y"]) - float(r[5])).length()
		var dh: float = absf(float(s["cam_h"]) - float(r[6]))
		var dpi: float = absf(float(s["cam_pitch"]) - float(r[7]))
		var dy: float = absf(wrapf(float(s["cam_yaw"]) - float(r[8]), -180.0, 180.0))
		if kick_rows.has(i):
			kicked += 1
		else:
			checked += 1
			boards += 1 if float(r[9]) > 0.0 else 0
			max_pos = maxf(max_pos, dp)
			max_h = maxf(max_h, dh)
			max_pitch = maxf(max_pitch, dpi)
			max_yaw = maxf(max_yaw, dy)
			if dp > 0.01 or dh > 0.01 or dpi > 0.1 or dy > 0.1:
				over.append(int(r[0]))
	done = frame >= rows.size()


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var ok: bool = done and over.is_empty() and checked + kicked == rows.size()
	return {"ok": ok, "summary": "%d of %d thirdjam camera steps checked (%d at the boards), %d inside contact kicks apart; worst %.2f cm, height %.2f cm, pitch %.3f deg, yaw %.3f deg; over 1 cm / 0.1 deg: %s" % [checked, rows.size(), boards, kicked, max_pos * 100.0, max_h * 100.0, max_pitch, max_yaw, str(over.slice(0, 10))],
		"frames": ctx.frame, "metrics": {"checked": checked, "kicked": kicked, "max_pos_cm": max_pos * 100.0, "max_pitch_deg": max_pitch, "max_yaw_deg": max_yaw}}
