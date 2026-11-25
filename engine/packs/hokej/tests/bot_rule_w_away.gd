extends Node
## Rule: W is away from the camera (AHokejGameMode::ReadHumanInput, S/JamGame/Private/HokejGameMode.cpp:937-958:
## Move = Fwd(camera yaw) * axis.y + Right * axis.x, the camera's yaw of the last sim frame). The hand skates W, then W + D
## (the skater turns and the camera turns after him), then W + A, then D alone. On every frame the move the game sent to the
## sim must be the keys' axis turned by the camera yaw of the frame before, within 1e-4.

const PLAN: Array = [[0, 60, "W"], [60, 150, "WD"], [150, 240, "WA"], [240, 300, "D"], [300, 330, ""]]
var ctx
var prev_cam_yaw: float = 0.0
var checked: int = 0
var worst: float = 0.0
var away: int = 0
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	if frame == 0:
		ctx.input.press(&"gym")          # the control rules are tested on the gym (one skater, empty ice)
	var s: Dictionary = ctx.pack_state()
	if frame > 0 and (float(s["axis_x"]) != 0.0 or float(s["axis_y"]) != 0.0):
		var y: float = deg_to_rad(prev_cam_yaw)
		var want: Vector2 = Vector2(cos(y), sin(y)) * float(s["axis_y"]) + Vector2(-sin(y), cos(y)) * float(s["axis_x"])
		worst = maxf(worst, want.distance_to(Vector2(float(s["move_x"]), float(s["move_y"]))))
		checked += 1
		if float(s["axis_y"]) > 0.0 and float(s["axis_x"]) == 0.0 and Vector2(float(s["move_x"]), float(s["move_y"])).dot(Vector2(cos(y), sin(y))) > 0.999:
			away += 1
	prev_cam_yaw = float(s["cam_yaw"])
	for k: StringName in [&"k_w", &"k_s", &"k_a", &"k_d"]:
		ctx.input.release(k)
	for p: Array in PLAN:
		if frame >= int(p[0]) and frame < int(p[1]):
			var keys: String = p[2]
			if keys.contains("W"): ctx.input.press(&"k_w")
			if keys.contains("A"): ctx.input.press(&"k_a")
			if keys.contains("D"): ctx.input.press(&"k_d")
	done = frame >= 330


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	return {"ok": done and checked >= 290 and worst < 1e-4 and away >= 55, "summary": "%d frames checked, worst move error %.6f, W alone straight away from the camera on %d frames" % [checked, worst, away],
		"frames": ctx.frame, "metrics": {"checked": checked, "worst": worst, "away": away}}
