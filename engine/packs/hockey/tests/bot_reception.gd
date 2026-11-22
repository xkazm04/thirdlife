extends "rink_bot.gd"
## Loose pickups bobble at 15 to under 20 m/s relative, intended passes at 28, and both retain 40% of world speed.
## Measure pass arrival first, then replay the same pass with a fresh human press six or twelve frames earlier.

const EARLY := {1: 6, 2: 12, 10: 8, 11: 9}
const DRILLS := ["recv_line", "recv_line", "recv_line", "recv_magnet", "recv_hard", "recv_loose",
	"flight_pass", "flight_shot", "flight_board", "recv_fast", "recv_line", "recv_line", "recv_line", "recv_line",
	"recv_clean_loose", "recv_clean_hard"]
var row := 0
var start := -1
var warmed := false
var arrival := -1
var take := -1
var bobble := -1
var press_at := -1
var shots := 0
var timers := 0
var shot_frame := -1
var speed := 0.0
var initial_miss := -1.0
var best_miss := INF
var hard_speed := 0.0
var hard_bobble := 0.0
var before_bobble := 0.0
var first_speed := 0.0
var stayed_free := true
var rows := []
var rebound := -1
var flight_ok := true
var flight_end := -1
var passed_ring := false

func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if frame < 10:
		return
	if start < 0:
		ctx.input.tap(StringName("drill_" + str(DRILLS[row])))
		ctx.input.clear_aim(&"aim")
		ctx.input.set_axis(&"left", &"right", -1.0 if row == 4 else 0.0)
		start = frame
		take = -1
		bobble = -1
		press_at = -1
		shots = s.shots.b0
		timers = s.possession.get("one_timers", {}).get("b0", 0)
		flight_ok = true
		flight_end = -1
		speed = 0.0
		return
	var age := frame - start
	var p: Dictionary = s.possession
	var vel := _v(s.puck.vel)
	if s.puck.get("holder", "") == "b0" and take < 0:
		take = p.since - start
	if p.get("last", {}).get("kind") == "bobble" and bobble < 0:
		bobble = p.last.frame - start
		if row == 4:
			hard_bobble = vel.length()
		elif row == 5:
			first_speed = vel.length()
	if EARLY.has(row) and age == arrival - int(EARLY[row]):
		press_at = age
		ctx.input.tap(&"shoot")
	if row in [12, 13] and take >= 0 and age == take + (6 if row == 12 else 7):
		press_at = age
		ctx.input.tap(&"shoot")
	if row == 3 and p.puck_state == "pass":
		var anchor := _pos("b0") + Vector2.LEFT.rotated(deg_to_rad(24.1)) * 1.2375
		var miss := absf((anchor - _v(s.puck.pos)).cross(vel.normalized()))
		if initial_miss < 0:
			initial_miss = miss
		best_miss = minf(best_miss, miss)
	if row == 4 and p.puck_state == "pass":
		hard_speed = maxf(hard_speed, vel.length())
		before_bobble = vel.length()
	if row == 5 and bobble >= 0 and age - 1 < bobble + 10:
		stayed_free = stayed_free and not s.puck.has("holder")
	if s.shots.b0 > shots and speed == 0.0:
		shot_frame = p.last.frame
		speed = vel.length()
	if row in [6, 7, 8] and age >= 16:
		var elapsed := age - 1 - 15
		var kind := "shot" if row == 7 else "pass"
		if p.puck_state == "loose" and flight_end < 0:
			flight_end = elapsed
		if row == 8:
			if rebound < 0 and vel.x < 0:
				rebound = elapsed
			flight_ok = flight_ok and p.puck_state == (kind if rebound < 0 else "loose")
		else:
			flight_ok = flight_ok and p.puck_state == (kind if elapsed < (60 if row == 7 else 90) else "loose")
	if row == 9 and _pos("b0").distance_to(_v(s.puck.pos)) <= s.reach:
		passed_ring = true
	var new_timers: int = p.get("one_timers", {}).get("b0", 0) - timers
	var ok := false
	match row:
		0:
			ok = take > 0 and bobble < 0
			arrival = take
		1, 10: ok = take - press_at == int(EARLY[row]) and new_timers == 1 and absf(speed - 28.8) < 0.03 and shot_frame == start + take + 4
		2, 11: ok = take - press_at == int(EARLY[row]) and s.shots.b0 == shots and new_timers == 0
		3: ok = initial_miss >= 1.45 and initial_miss <= 1.55 and best_miss < initial_miss * 0.85 and take >= 0
		4: ok = bobble >= 0 and absf(hard_speed - 23.0) < 0.03 and absf(hard_bobble - before_bobble * 0.4) < 0.03
		5: ok = bobble >= 0 and stayed_free and take == bobble + 10 and absf(first_speed - 7.2) < 0.15
		6: ok = flight_ok and flight_end == 90
		7: ok = flight_ok and flight_end == 60
		8: ok = flight_ok and flight_end == rebound and rebound > 0 and rebound < 30
		9: ok = passed_ring and take < 0 and bobble < 0
		12: ok = new_timers == 1 and shot_frame == start + take + 6 and absf(speed - 28.8) < 0.03
		14, 15: ok = take > 0 and bobble < 0
		13: ok = press_at == take + 7 and new_timers == 0 and absf(speed - 24.0) < 0.03
	if age == (110 if row in [6, 7] else (38 if row in [8, 9] else 85)):
		if row == 0 and not warmed:
			warmed = true
			start = -1
			return
		rows.append({"ok": ok, "take": take, "bobble": bobble, "shot_speed": speed, "timers": new_timers, "flight_end": flight_end})
		row += 1
		start = -1
		done = row == DRILLS.size()

func _bot_result() -> Dictionary:
	return {"ok": done and rows.all(func(r): return r.ok), "summary": "%s, magnet miss %.3f to %.3f, hard %.2f (%.2f to %.2f), loose bobble %.2f, board reversal at %d" % [rows, initial_miss, best_miss, hard_speed, before_bobble, hard_bobble, first_speed, rebound]}
