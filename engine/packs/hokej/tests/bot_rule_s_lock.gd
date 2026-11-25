extends Node
## Rule: the S lock (HokejGameMode.cpp:940-952, lane A93): while the keys pull back (axis.y < -0.3) the move is read in the
## camera's yaw of the moment the pull began, so S is one direction on the ice until it is let go: the skater brakes, turns
## and skates back that way while the camera comes round behind him. The hand skates W for 90 frames, holds S for 150, lets go
## for 10, then holds S again (a new pull: a new lock at the camera's yaw of that moment).

var ctx
var prev_cam_yaw: float = 0.0
var lock_yaw: float = 0.0
var held_frames: int = 0
var worst: float = 0.0
var cam_turned: float = 0.0
var relocked: bool = false
var end_heading_err: float = 180.0
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	if frame == 0:
		ctx.input.press(&"gym")          # the control rules are tested on the gym (one skater, empty ice)
	var s: Dictionary = ctx.pack_state()
	if float(s["axis_y"]) < -0.3:
		if held_frames == 0 or frame == 251:
			var first_lock: float = lock_yaw
			lock_yaw = prev_cam_yaw          # the camera yaw the move was read in on the pull's first frame
			if frame == 251:                 # a new pull: the move is read in the camera's yaw of now, not the first pull's
				var mv := Vector2(float(s["move_x"]), float(s["move_y"]))
				relocked = mv.distance_to(-Vector2(cos(deg_to_rad(lock_yaw)), sin(deg_to_rad(lock_yaw)))) < 1e-4 and absf(wrapf(lock_yaw - first_lock, -180.0, 180.0)) > 1.0
		var y: float = deg_to_rad(lock_yaw)
		var want: Vector2 = -Vector2(cos(y), sin(y))
		worst = maxf(worst, want.distance_to(Vector2(float(s["move_x"]), float(s["move_y"]))))
		cam_turned = maxf(cam_turned, absf(wrapf(float(s["cam_yaw"]) - lock_yaw, -180.0, 180.0)))
		held_frames += 1
		if frame == 240:
			end_heading_err = absf(wrapf(float(s["yaw_deg"]) - (lock_yaw + 180.0), -180.0, 180.0))
	prev_cam_yaw = float(s["cam_yaw"])
	ctx.input.release(&"k_w")
	ctx.input.release(&"k_s")
	if frame < 90:
		ctx.input.press(&"k_w")
	elif frame < 240 or (frame >= 250 and frame < 300):
		ctx.input.press(&"k_s")
	done = frame >= 300


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var ok: bool = done and worst < 1e-4 and cam_turned > 150.0 and end_heading_err < 1.0 and relocked
	return {"ok": ok, "summary": "S held %d frames: move off the lock by %.6f at worst while the camera turned %.1f deg; heading %.2f deg off the locked back direction at the end; a new pull relocked: %s" % [held_frames, worst, cam_turned, end_heading_err, str(relocked)],
		"frames": ctx.frame, "metrics": {"worst": worst, "cam_turned": cam_turned, "end_heading_err": end_heading_err}}
