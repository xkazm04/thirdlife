extends "rink_bot.gd"
## Bot (L5, 21 Nov): the first minute. It starts the drill with the keyless action `intro` (a person's session starts it
## by itself) and plays it as a person would, keys and the cursor (the aim), no hand profile:
##   skate: W A S D to the ring; take: wait for LEO's pass; pass: the cursor on LEO, Q; back: wait; shoot: skate in, the
##   cursor on the net's far side, Space; done: the match starts by itself.
## ok: every step done in order, the drill ended by a goal into the empty net within max_frames, then the match runs
## from 0 : 0 (the drill's goal is no score). With skip = true (bot_intro_skip.gd): Enter at frame 30 ends the drill and
## the match runs from 0 : 0.

var skip: bool = false
var max_frames: int = 1800

var started: int = -1
var seen_steps: Array = []

var ended_at: int = -1
var match_frames: int = 0

func _steer(d: Vector2) -> void:
	var n: Vector2 = d.normalized() if d.length() > 0.3 else Vector2.ZERO
	ctx.input.set_axis(&"left", &"right", n.x)
	ctx.input.set_axis(&"up", &"down", n.y)

func _aimed(at: Vector2) -> bool:
	ctx.input.set_aim(&"aim", Vector3(at.x, 0.0, at.y))
	if not s.has("stick"):
		return false
	var to: Vector2 = at - _pos("b0")
	return rad_to_deg(absf(_v(s["stick"]).angle_to(to))) < 4.0

func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if done:
		return
	if started < 0:
		ctx.input.tap(&"intro")
		started = frame
		return
	if s.has("intro"):
		var st: String = str(s["intro"]["step"])
		if seen_steps.is_empty() or seen_steps[-1] != st:
			seen_steps.append(st)
		if skip and frame - started == 30:
			ctx.input.tap(&"skip")
			return
		var me: Vector2 = _pos("b0")
		match st:
			"skate":
				_steer(_v(s["intro"]["ring"]) - me)
			"pass":
				_steer(Vector2.ZERO)
				if _aimed(_pos("b1")) and bool(s.get("pass_ready", false)):
					ctx.input.tap(&"pass")
			"shoot":
				var goal: Vector2 = Vector2(26.0, 0.0)
				if me.x > 20.0 or me.distance_to(goal) > 14.0:
					_steer(Vector2(14.0, 0.0) - me)
				else:
					_steer(Vector2.ZERO)
				var tgt: Vector2 = Vector2(26.0, -1.2)
				if _aimed(tgt) and bool(s.get("shoot_ready", false)) and me.x < 20.0 and me.distance_to(goal) < 16.0:
					ctx.input.tap(&"shoot")
			_:
				_steer(Vector2.ZERO)
		if frame - started > max_frames:
			done = true
		return
	if ended_at < 0:
		ended_at = frame
		ctx.input.clear_aim(&"aim")
		_steer(Vector2.ZERO)
	if str(s["state"]) == "running":
		match_frames += 1
	if match_frames >= 60 or frame - ended_at > 300:
		done = true

func _bot_result() -> Dictionary:
	var want: Array = ["skate", "take", "pass", "back", "shoot", "done"]
	var sc: Dictionary = s.get("scores", {})
	var nil: bool = int(sc.get("blue", 0)) == 0 and int(sc.get("red", 0)) == 0
	var end: String = str(s.get("intro_end", ""))
	var ok: bool = done and ended_at > 0 and match_frames >= 60 and nil
	if skip:
		ok = ok and end == "skip" and ended_at - started <= 35
	else:
		ok = ok and end == "goal" and seen_steps == want and ended_at - started <= max_frames
	return {"ok": ok, "summary": "steps %s; ended by %s after %d frames; the match then ran %d frames from %d : %d" % [
		str(seen_steps), end if end != "" else "nothing", ended_at - started if ended_at > 0 else -1, match_frames, int(sc.get("blue", 0)), int(sc.get("red", 0))],
		"frames": ended_at - started, "steps": seen_steps}
