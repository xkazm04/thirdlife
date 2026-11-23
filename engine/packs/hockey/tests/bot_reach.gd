extends "rink_bot.gd"
## N3 times clean eligible pickups after the six-frame release lock and a late poke through its active window.
## Bot (H1): the reach table, played the way a person's hand meets it. Each row starts a drill (a declared action with
## no key) and then presses only the game's keys: it faces away, skates through at three speeds, holds Space or Q
## through the take, holds Space through a poke, reacts late to a poke chance. It measures from the state it sees
## (one frame late, as a person sees the screen): frames from "inside his reach" to "his".
## Then 10 passes in open ice to a mate the drill places (and moves) from the seeded generator.
## ok: every row within its bound and at least 8 of 10 passes reach the mate.

const ROWS: Array = [
	# name, drill, bound (frames), inputs
	["still beside him", "still_beside", 1, "none"],
	["behind him", "behind", 1, "none"],
	["in the ring, he faces away", "facing_away", 1, "none"],
	["slides into the ring from behind him (3 m/s)", "slides_from_behind", 1, "none"],
	["slides in from the side, he faces away (4 m/s)", "slides_from_side_facing_away", 1, "none"],
	["skates through at walk (2 m/s, then glides)", "through", 1, "walk"],
	["skates through at full speed", "through", 1, "full"],
	["skates through at sprint (Shift)", "through", 1, "sprint"],
	["skates through with Space held", "through", 1, "shoot_held"],
	["skates through with Q held", "through", 1, "pass_held"],
	["own pass to nobody, he chases it", "own_pass", 1, "own_pass"],
	["an opponent pokes it, Space held through", "poked", 1, "poked"],
	["he pokes theirs, 12 frames late", "poke_them", 12, "poke_late"],
]
const PASS_TRIES: int = 10
const ROW_FRAMES: int = 420
const PASS_FRAMES: int = 150

var row: int = 0
var phase: String = "start"
var t0: int = 0
var results: Array = []
var first_in: int = -1
var first_his: int = -1
var top_speed: float = 0.0
var take_speed: float = 0.0
var released_at: int = -1
var early_retake: bool = false
var lock_in_reach: int = 0
var other_took: String = ""
var other_frames: int = -1
var poke_chance := -1
var tries_before := 0
var pokes_before := 0
var poke_resolved := false
var poke_age := -1
var stretch_start: int = -1
var walk_reached: bool = false
var passes_tried: int = 0
var passes_ok: int = 0
var pass_log: Array = []

func _holder() -> String:
	return str(s["puck"].get("holder", ""))

func _keys(right: float, sprint: bool, shoot: bool, pss: bool) -> void:
	ctx.input.set_axis(&"left", &"right", right)
	ctx.input.set_axis(&"up", &"down", 0.0)
	if sprint:
		ctx.input.press(&"sprint")
	else:
		ctx.input.release(&"sprint")
	if shoot:
		ctx.input.press(&"shoot")
	else:
		ctx.input.release(&"shoot")
	if pss:
		ctx.input.press(&"pass")
	else:
		ctx.input.release(&"pass")

func _reset_row() -> void:
	first_in = -1
	first_his = -1
	top_speed = 0.0
	take_speed = 0.0
	released_at = -1
	early_retake = false
	lock_in_reach = 0
	other_took = ""
	other_frames = -1
	poke_chance = -1
	stretch_start = -1
	walk_reached = false

func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if not classic():
		return
	if done:
		_keys(0.0, false, false, false)
		return
	if row < ROWS.size():
		_row_tick(frame)
	else:
		_pass_tick(frame)

func _row_tick(frame: int) -> void:
	var r: Array = ROWS[row]
	var mode: String = str(r[3])
	if phase == "start":
		_reset_row()
		tries_before = s.possession.poke_tries.b0
		pokes_before = s.possession.pokes.b0
		poke_resolved = false
		poke_age = -1
		_keys(0.0, false, mode == "poked", false)
		ctx.input.tap(StringName("drill_" + str(r[1])))
		t0 = frame
		phase = "run"
		return
	var age: int = frame - t0
	if age < 2:
		return
	var me: Dictionary = _me()
	var pos: Vector2 = _v(me["pos"])
	var spd: float = float(me["speed"])
	top_speed = maxf(top_speed, spd)
	var puck: Vector2 = _v(s["puck"]["pos"])
	var h: String = _holder()
	var reach: float = float(s["reach"])
	var inside: bool = h == "" and pos.distance_to(puck) <= reach
	if mode == "own_pass" and released_at >= 0:
		var rel := (_v(s.puck.vel) - _v(me.vel)).length()
		var last: Dictionary = s.possession.last
		var lock := 10 if last.kind == "bobble" else 6
		inside = inside and rel < 11 and frame - int(last.frame) >= lock
	# the hand
	match mode:
		"walk":
			if spd >= 2.0:
				walk_reached = true
			_keys(0.0 if walk_reached else 1.0, false, false, false)
		"full":
			_keys(1.0, false, false, false)
		"sprint":
			_keys(1.0, true, false, false)
		"shoot_held":
			_keys(1.0, false, true, false)
		"pass_held":
			_keys(1.0, false, false, true)
		"own_pass":
			if age == 4:
				ctx.input.tap(&"pass")
			if age > 5:
				# H8: he chases the puck where it is (a person steers at it; holding D only caught it on 10 of 20 seeds,
				# when the rebound off the boards happened to come back along his line)
				_keys(0.0, true, false, false)
				var to: Vector2 = (puck - pos).normalized() if (puck - pos).length() > 0.05 else Vector2.ZERO
				ctx.input.set_axis(&"left", &"right", to.x)
				ctx.input.set_axis(&"up", &"down", to.y)
		"poked":
			_keys(0.0, false, true, false)
		"poke_late":
			if poke_chance < 0 and s.poke_ready:
				poke_chance = frame
			if poke_chance >= 0 and frame - poke_chance == 12:
				ctx.input.tap(&"poke")
			if poke_chance >= 0 and s.possession.poke_tries.b0 == tries_before + 1:
				# H1 build (S12, S13): the window is frames 0-7 of the press and a miss no longer halves the turning: a whiff is its window running out
				if s.possession.pokes.b0 == pokes_before + 1 or frame - 1 - (poke_chance + 12) >= 8:
					poke_age = frame - 1 - (poke_chance + 12)
					poke_resolved = true
					_finish(frame)
					return
		_:
			_keys(0.0, false, false, false)
	# the measurement
	var release_row: bool = mode == "own_pass" or mode == "poked"
	if release_row and released_at < 0:
		if h != "b0" and age > 3:
			released_at = frame
			if h != "":
				other_took = h
				other_frames = 0
		_maybe_end(frame, age)
		return
	if release_row:
		if h != "" and h != "b0" and other_took == "":
			other_took = h
			other_frames = frame - released_at
		if h == "b0" and frame - released_at < (6 if mode == "own_pass" else 30):
			early_retake = true
		if inside and frame - released_at <= 40:
			lock_in_reach += 1
		if other_took != "" and mode == "poked":
			_finish(frame)
			return
	if inside and stretch_start < 0:
		stretch_start = frame
	if not inside and h != "b0":
		stretch_start = -1
	if inside and first_in < 0:
		first_in = frame
	if h == "b0" and first_his < 0:
		first_his = frame
		take_speed = spd
		_finish(frame)
		return
	_maybe_end(frame, age)

func _maybe_end(frame: int, age: int) -> void:
	if age >= ROW_FRAMES:
		_finish(frame)

func _finish(_frame: int) -> void:
	var r: Array = ROWS[row]
	var mode: String = str(r[3])
	var frames: int = -1
	if first_his >= 0:
		frames = 0 if stretch_start < 0 else first_his - stretch_start
	var ok: bool = frames >= 0 and frames <= int(r[2])
	var note: String = ""
	if mode == "own_pass":
		ok = ok and not early_retake
		note = "released, in his reach %d frames right after (not taken: lock %d frames), retaken %s; taken meanwhile by %s at %d frames" % [lock_in_reach, 6, "yes" if first_his >= 0 else "no", other_took if other_took != "" else "nobody", other_frames]
	elif mode == "poke_late":
		frames = poke_age
		ok = poke_resolved and frames >= 0 and frames <= 7   # H1 build (S12): was 6-12
		note = "one start after the 12-frame reaction; success or measured whiff"
	elif mode == "poked":
		frames = other_frames
		ok = other_took == "r0" and other_frames >= 0 and other_frames <= 12 and first_his < 0
		note = "r0 had it %d frames after the poke; b0 (Space held) in his reach %d frames, not his (poke lock 30)" % [other_frames, lock_in_reach]
	elif mode in ["walk", "full", "sprint", "shoot_held", "pass_held"]:
		note = "top %.1f m/s, %.1f m/s at the take" % [top_speed, take_speed]
	results.append({"row": str(r[0]), "frames": frames, "bound": int(r[2]), "ok": ok, "note": note})
	row += 1
	phase = "start"

func _pass_tick(frame: int) -> void:
	if passes_tried >= PASS_TRIES:
		done = true
		return
	if phase == "start":
		_keys(0.0, false, false, false)
		ctx.input.tap(&"drill_pass_open")
		t0 = frame
		phase = "run"
		return
	var age: int = frame - t0
	if age == 5:
		ctx.input.tap(&"pass")
	if age <= 6:
		return
	var h: String = _holder()
	if h == "b1" or (h != "" and h != "b0") or age > PASS_FRAMES:
		var mate: Vector2 = Vector2.ZERO
		for k: Dictionary in s["skaters"]:
			if k["id"] == "b1":
				mate = _v(k["pos"])
		var good: bool = h == "b1"
		if good:
			passes_ok += 1
		pass_log.append("%s@%d(%.0f,%.0f)" % [h if h != "" else "none", age, mate.x, mate.y])
		passes_tried += 1
		phase = "start"

func _bot_result() -> Dictionary:
	var all_ok: bool = results.size() == ROWS.size()
	var parts: Array = []
	for r: Dictionary in results:
		all_ok = all_ok and bool(r["ok"])
		parts.append("%s: %d (bound %d) %s%s" % [r["row"], int(r["frames"]), int(r["bound"]), "ok" if r["ok"] else "MISS", (" [" + str(r["note"]) + "]") if str(r["note"]) != "" else ""])
	var ok: bool = done and all_ok and passes_ok >= 8
	return {"ok": ok, "summary": "rows %d/%d; passes %d of %d reached the mate (%s); %s" % [results.filter(func(x): return x["ok"]).size(), ROWS.size(), passes_ok, passes_tried, " ".join(pass_log), " | ".join(parts)],
		"rows": results, "passes_ok": passes_ok, "passes_tried": passes_tried}
