extends "rink_bot.gd"
## N3 measures the 1.2x replay shot and the 24 m/s wrist shot after the press window.
## Measures both skaters and the clock through hit-stop, goal replay, and immediate versus delayed shots off a pass.

const ROWS: Array = [["hard check", "hit_head_on", 99.0], ["small bump", "hit_head_on", 2.0], ["goal and replay", "goal_released", 0.0],
	["one-timer", "goalie_cross", 0.0], ["held, then shot", "goalie_cross", 16.0]]
var row: int = 0
var t0: int = -1
var stops0: int = 0
var replays0: int = 0
var pressed: bool = false
var pressed_at: int = 0
var still_frames: int = 0
var clock_still: bool = true
var prev: Dictionary = {}
var replay_max: int = 0
var given0: int = 0
var results: Array = []

func _snap() -> Dictionary:
	var d: Dictionary = {"clock": int(s.get("clock_frames", 0))}
	for k: Dictionary in s["skaters"]:
		d[str(k["id"])] = k["pos"]
	return d

func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if not classic():
		return
	if done:
		return
	if row >= ROWS.size():
		ctx.input.set_axis(&"left", &"right", 0.0)
		done = true
		return
	var r: Array = ROWS[row]
	var fs: Dictionary = s.get("fun", {})
	if t0 < 0:
		if str(s["state"]) == "over":
			ctx.input.tap(&"restart")
			return
		if bool(s["frozen"]) or str(s["state"]) != "running" or int(fs.get("stop_left", 0)) > 0 or not (s["hits"].get("down", {}) as Dictionary).is_empty():
			return
		stops0 = int(fs.get("stops", 0))
		replays0 = int(fs.get("replays", 0))
		pressed = false
		still_frames = 0
		clock_still = true
		prev = {}
		replay_max = 0
		given0 = _given()
		ctx.input.tap(StringName("drill_" + str(r[1])))
		t0 = frame
		return
	var age: int = frame - t0
	if row < 2:
		var spd: float = 0.0
		for k: Dictionary in s["skaters"]:
			if str(k["id"]) == "b0":
				spd = float(k["speed"])
		ctx.input.set_axis(&"left", &"right", 1.0 if not pressed and spd < float(r[2]) else 0.0)     # a person keeps his speed
		if row == 0:
			ctx.input.press(&"sprint")
		if not pressed and age > 3 and _pos("b0").distance_to(_pos("r0")) < 2.0 * float(s.body_radius) + 0.18:
			ctx.input.tap(&"check")
			pressed = true
			pressed_at = age
		if int(fs.get("stop_left", 0)) > 0:
			var now: Dictionary = _snap()
			if not prev.is_empty():
				var same: bool = true
				for k: String in now:
					if k != "clock" and str(now[k]) != str(prev[k]):
						same = false
				if same:
					still_frames += 1
				clock_still = clock_still and int(now["clock"]) == int(prev["clock"])
			prev = now
		var stopped: bool = int(fs.get("stops", 0)) > stops0
		if (pressed and age - pressed_at > 60) or age > 400:
			ctx.input.release(&"sprint")
			var lh: Dictionary = s["hits"].get("last", {})
			var want_stop: bool = false   # H1 build (23 Nov), sheet row S10: fun.stop false: no hit freezes the game (row 0 wanted a stop before)
			var fresh: bool = _given() > given0
			var ok: bool = fresh and stopped == want_stop and (not want_stop or (still_frames >= 3 and clock_still))
			results.append({"row": str(r[0]), "ok": ok, "detail": "%s closing %.2f m/s (%s), stop %s, frames held still %d, clock held %s" % ["a hit" if fresh else "NO HIT", float(lh.get("closing", 0.0)), str(lh.get("class", "-")), str(stopped), still_frames, str(clock_still)]})
			ctx.input.set_axis(&"left", &"right", 0.0)
			row += 1
			t0 = -1
		return
	if row >= 3:
		_one_timer_row(r, age)
		return
	replay_max = maxi(replay_max, int(fs.get("replay_t", 0)))
	var replayed: bool = int(fs.get("replays", 0)) > replays0
	if (replayed and not bool(s["frozen"]) and age > 30) or age > 400:
		results.append({"row": str(r[0]), "ok": replayed and replay_max > 30, "detail": "replays %d, replay ticks %d, live again %s" % [int(fs.get("replays", 0)) - replays0, replay_max, str(not bool(s["frozen"]))]})
		row += 1
		t0 = -1

## L5b: b0 takes LEO's pass across (drill goalie_cross) and shoots after r[2] frames
## with the puck: at once it is a one-timer (1.2x the shot speed), after 16 frames an ordinary shot.
var _took: int = -1
var _shot: int = -1
var _ot0: int = 0

func _one_timer_row(r: Array, age: int) -> void:
	if age == 1:
		_took = -1
		_shot = -1
		_ot0 = int(s["possession"].get("one_timers", {}).get("b0", 0))
	if _took < 0 and str(s["puck"].get("holder", "")) == "b0":
		_took = age
	if _took >= 0 and _shot < 0 and age - _took >= int(r[2]) and bool(s.get("shoot_ready", false)):
		ctx.input.tap(&"shoot")
		_shot = age + 1
	if (_shot >= 0 and age - _shot == 4) or age > 200:
		var v: Array = s["puck"]["vel"]
		var spd: float = Vector2(float(v[0]), float(v[1])).length()
		var n: int = int(s["possession"].get("one_timers", {}).get("b0", 0)) - _ot0
		var want: bool = int(r[2]) == 0
		var ok: bool = _shot >= 0 and (n == 1) == want and absf(spd - (28.8 if want else 24.0)) < 0.35
		results.append({"row": str(r[0]), "ok": ok, "detail": "took at %d, shot at %d, one-timers %d, puck %.1f m/s" % [_took, _shot, n, spd]})
		row += 1
		t0 = -1

## Body checks blue has landed so far (every class).
func _given() -> int:
	var n: int = 0
	var gv: Dictionary = s["hits"]["given"]["blue"]
	for k: String in gv:
		n += int(gv[k])
	return n

func _bot_result() -> Dictionary:
	var ok: bool = done and results.size() == ROWS.size()
	var parts: Array = []
	for x: Dictionary in results:
		ok = ok and bool(x["ok"])
		parts.append("%s: %s%s" % [x["row"], x["detail"], "" if x["ok"] else " MISS"])
	return {"ok": ok, "summary": " | ".join(parts), "rows": results}
