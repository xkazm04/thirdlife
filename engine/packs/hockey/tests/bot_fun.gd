extends Node
## Bot (L5, 21 Nov): the fun layer's three promises, one drill a row (level none):
##   a hard check (hit_head_on, b0 sprints at r0 and presses F): a hit-stop: every skater stands exactly still and the clock
##     does not run for the stop's frames (tuning fun.stop_frames_min..max), then the play goes on (b0 and r0 move again)
##   a small bump (hit_head_on, b0 skates at r0 at 2 m/s and presses F): no stop
##   a goal (goal_released): the pause after it replays the shot (fun.replay_t counts up), then the face-off as before
## ok: the three rows as stated. The stop's frames are counted in physics frames, as everything else.

var ctx
var s: Dictionary = {}
const ROWS: Array = [["hard check", "hit_head_on", 99.0], ["small bump", "hit_head_on", 2.0], ["goal and replay", "goal_released", 0.0]]
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
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _pos(id: String) -> Vector2:
	for k: Dictionary in s["skaters"]:
		if str(k["id"]) == id:
			return Vector2(float(k["pos"][0]), float(k["pos"][1]))
	return Vector2.ZERO


func _snap() -> Dictionary:
	var d: Dictionary = {"clock": int(s.get("clock_frames", 0))}
	for k: Dictionary in s["skaters"]:
		d[str(k["id"])] = k["pos"]
	return d


func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if str(s.get("mode", "base")) != "base":
		ctx.input.tap(&"mode_base")
		return
	if str(s.get("level", "none")) != "none":
		ctx.input.tap(&"level_none")
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
		if not pressed and age > 3 and _pos("b0").distance_to(_pos("r0")) < 1.5:
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
			var want_stop: bool = row == 0
			var fresh: bool = _given() > given0
			var ok: bool = fresh and stopped == want_stop and (not want_stop or (still_frames >= 3 and clock_still))
			results.append({"row": str(r[0]), "ok": ok, "detail": "%s closing %.2f m/s (%s), stop %s, frames held still %d, clock held %s" % ["a hit" if fresh else "NO HIT", float(lh.get("closing", 0.0)), str(lh.get("class", "-")), str(stopped), still_frames, str(clock_still)]})
			ctx.input.set_axis(&"left", &"right", 0.0)
			row += 1
			t0 = -1
		return
	replay_max = maxi(replay_max, int(fs.get("replay_t", 0)))
	var replayed: bool = int(fs.get("replays", 0)) > replays0
	if (replayed and not bool(s["frozen"]) and age > 30) or age > 400:
		results.append({"row": str(r[0]), "ok": replayed and replay_max > 30, "detail": "replays %d, replay ticks %d, live again %s" % [int(fs.get("replays", 0)) - replays0, replay_max, str(not bool(s["frozen"]))]})
		row += 1
		t0 = -1


## Body checks blue has landed so far (every class).
func _given() -> int:
	var n: int = 0
	var gv: Dictionary = s["hits"]["given"]["blue"]
	for k: String in gv:
		n += int(gv[k])
	return n


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var ok: bool = done and results.size() == ROWS.size()
	var parts: Array = []
	for x: Dictionary in results:
		ok = ok and bool(x["ok"])
		parts.append("%s: %s%s" % [x["row"], x["detail"], "" if x["ok"] else " MISS"])
	return {"ok": ok, "summary": " | ".join(parts), "rows": results}
