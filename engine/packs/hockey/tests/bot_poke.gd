extends "rink_bot.gd"
## New owners get 24 protected frames so they can play the puck before another poke.
## Forty independent, seeded actions in each geometry. Probe recovery with the same poke key.

const DRILLS := ["poke_front", "poke_back", "poke_cut"]
var row := 0
var trial := 0
var resume_at := 10
var start := -1
var successes := [0, 0, 0]
var tries := [0, 0, 0]
var cuts := 0
var missed_cuts := []
var in_window := true
var before := 0
var attempts := 0
var recovery := true
var lock_ok := true
var turnover := false
var tested_lock := 0
var immunity := 0
var outsider_tries := 0
var outsider_started := false
var taken_at := 0

func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if start < 0:
		if frame < resume_at or s.state != "running" or s.frozen:
			return
		var drill: String = DRILLS[row] if row < 3 else ("poke_whiff" if row == 3 else "poke_lock")
		ctx.input.clear_aim(&"aim")
		ctx.input.tap(StringName("drill_" + drill))
		before = s.possession.pokes.b0
		attempts = s.possession.poke_tries.b0
		outsider_tries = s.possession.poke_tries.b2
		start = frame
		return
	var age := frame - start
	if row < 3:
		if row == 2:
			var dir := (_v(s.puck.pos) - _pos("b0")).normalized()
			ctx.input.set_aim(&"aim", Vector3(_pos("b0").x + 10 * dir.x, 0, _pos("b0").y + 10 * dir.y))
		var press_age := 7 if row == 2 else 5
		if age == press_age:
			ctx.input.tap(&"poke")
		var hit: int = s.possession.pokes.b0 - before
		if hit > 0 and s.possession.last.kind == "poked":
			in_window = in_window and int(s.possession.last.frame) - (start + press_age) in range(6, 13)
		if age == press_age + 6 and row == 2:
			if s.possession.get("cut", false):
				cuts += 1
			else:
				missed_cuts.append(trial)
		if age == 18:
			successes[row] += hit
			tries[row] += s.possession.poke_tries.b0 - attempts
			trial += 1
			start = -1
			if trial == 40:
				# Start each group with a fresh period so its active frames never cross intermission.
				ctx.input.tap(&"mode_base")
				resume_at = frame + 15
				row += 1
				trial = 0
		return
	if row == 3:
		var expected := 2.25 if age >= 14 and age < 29 else 4.5
		recovery = recovery and is_equal_approx(float(_me().turn_rate), expected)
		if age == 41:
			recovery = recovery and s.possession.poke_tries.b0 == attempts + 1
		if age == 43:
			recovery = recovery and s.possession.poke_tries.b0 == attempts + 2
			row += 1
			start = -1
		return
	# The opponent returns a slow puck into the victim's ring. Probe both ends of the lock.
	var last: Dictionary = s.possession.get("last", {})
	if last.get("kind") == "poked":
		turnover = true
	if turnover and s.puck.get("holder", "") == "r0":
		taken_at = s.possession.since
		var elapsed: int = frame - 1 - taken_at
		if elapsed < 24:
			lock_ok = lock_ok and s.possession.poke_tries.b2 == outsider_tries
			immunity += 1
			lock_ok = lock_ok and int(s.possession.get("poke_immune", 0)) == 24 - elapsed
		else:
			lock_ok = lock_ok and not s.possession.has("poke_immune")
			if elapsed == 24:
				outsider_started = s.possession.poke_tries.b2 == outsider_tries + 1
	if last.get("kind") == "pass" and turnover and _pos("b0").distance_to(_v(s.puck.pos)) < s.reach:
		var elapsed := frame - 1 - taken_at
		if elapsed < 30:
			tested_lock += 1
			lock_ok = lock_ok and not s.puck.has("holder")
		elif s.puck.get("holder", "") == "b0":
			lock_ok = lock_ok and s.possession.since == taken_at + 30
			done = true
	if age >= 65 and not done:
		# A legal front poke can whiff. Repeat the set start until it lands.
		if turnover or trial >= 12:
			done = true
		else:
			start = -1
			trial += 1

func _bot_result() -> Dictionary:
	var odds_ok: bool = successes[0] >= 18 and successes[0] <= 34 and successes[1] <= 16 and successes[2] < successes[0]
	var ok: bool = done and odds_ok and tries == [40,40,40] and cuts == 40 and in_window and recovery and lock_ok and immunity == 24 and outsider_started and tested_lock > 0 and s.puck.get("holder", "") == "b0"
	return {"ok": ok, "summary": "success %s / attempts %s, cuts %d (missed %s), windows %s, recovery %s, immunity %d, lock %d frames in reach (%s), final %s" % [successes, tries, cuts, missed_cuts, in_window, recovery, immunity, tested_lock, lock_ok, s.puck.get("holder","loose")]}
