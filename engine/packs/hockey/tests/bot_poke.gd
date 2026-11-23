extends "rink_bot.gd"
## New owners get 24 protected frames so they can play the puck before another poke.
## Forty independent, seeded actions in each geometry. Probe recovery with the same poke key.
## H1 build (23 Nov), sheet rows S11-S14 (thirdjam's poke): live from the press for 8 frames (was frames 6-12), certain in reach
## in front and at the side, never through his back, x0.6 on a cutting carrier; again 14 frames after a take, a miss locks it
## 20 frames with no turning penalty; the puck is the poker's at once. The presses move 6 frames later so the new window covers
## the same frames of each drill as the old one did.

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
var press_age := -1                 # H1 build: the age of this trial's press
var cut_at_press := false           # H1 build: the carrier had just cut (x poke_cut_mult) when b0 pressed
var clean_misses := [0, 0, 0]       # H1 build (S11): trials pressed in reach, no cut, that did not take the puck
var in_reach := [0, 0, 0]           # H1 build: trials whose press came with the poke in reach (poke_ready)
var ready_at_press := false
var cut_tries := 0                  # H1 build: presses into a cut (row 2) and the pucks they took
var cut_takes := 0

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
		# H1 build (S12, A2): the window opens at the press and lasts 8 frames, and the drill's carrier now closes more slowly
		# (route A's thrust), so the press comes as a person's does: on the first frame the HUD says a poke can reach (poke_ready),
		# at age 70 at the latest. Before: a fixed press at age 5 (7 in the cut row) into a 6-12 window.
		if press_age < 0 and (bool(s.get("poke_ready", false)) or age >= 70):
			ctx.input.tap(&"poke")
			press_age = age
			cut_at_press = bool(s.possession.get("cut", false))
			ready_at_press = bool(s.get("poke_ready", false))
			if ready_at_press:
				in_reach[row] += 1
		var hit: int = s.possession.pokes.b0 - before
		if hit > 0 and s.possession.last.kind == "poked":
			in_window = in_window and press_age >= 0 and int(s.possession.last.frame) - (start + press_age) in range(0, 9)
		if press_age == age and row == 2:   # H1 build: the cut is read at the press (it was read at age 13, the old window's start)
			if cut_at_press:
				cuts += 1
			else:
				missed_cuts.append(trial)
		if press_age >= 0 and age == press_age + 12:
			press_age = -1
			if hit == 0 and ready_at_press and not cut_at_press:
				clean_misses[row] += 1
			if row == 2 and ready_at_press and cut_at_press:
				cut_tries += 1
				cut_takes += hit
			successes[row] += hit
			tries[row] += s.possession.poke_tries.b0 - attempts
			trial += 1
			start = -1
			resume_at = frame + 16   # H1 build (S13): the next trial's press must not fall inside this one's 14-frame cooldown
			if trial == 40:
				# Start each group with a fresh period so its active frames never cross intermission.
				ctx.input.tap(&"mode_base")
				resume_at = frame + 15
				row += 1
				trial = 0
		return
	if row == 3:
		var expected := 5.0   # H1 build (S13, S17): a miss no longer halves the turning (was 2.25 for frames 14-28 of 4.5)
		recovery = recovery and is_equal_approx(float(_me().turn_rate), expected)
		if age == 41:
			recovery = recovery and s.possession.poke_tries.b0 == attempts + 2   # H1 build (S13): the miss at frame 8 locks to 28, so the press at 40 is taken
		if age == 43:
			recovery = recovery and s.possession.poke_tries.b0 == attempts + 2   # ... and the press at 41 is inside its 14-frame cooldown
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
	# H1 build (S11): in front and at the side a poke in reach always takes, unless the carrier has just cut (x poke_cut_mult 0.6);
	# never through his back. Was: 18-34 of 40 in front, at most 16 behind.
	# the cut row: poke_cut_mult is 1.0 now (S11: a poke in reach always takes; thirdjam has no such chance), so it takes as the front
	var odds_ok: bool = clean_misses[0] == 0 and in_reach[0] >= 30 and successes[0] == in_reach[0] and successes[1] == 0 and in_reach[1] >= 30 and clean_misses[2] == 0 and in_reach[2] >= 30 and successes[2] == in_reach[2]
	# H1 build: every press made in reach was taken as a try (was: tries == [40, 40, 40] and cuts == 40, the fixed presses)
	var ok: bool = done and odds_ok and tries[0] >= in_reach[0] and tries[1] >= in_reach[1] and tries[2] >= in_reach[2] and in_window and recovery and lock_ok and immunity == 24 and outsider_started and tested_lock > 0 and s.puck.get("holder", "") == "b0"
	return {"ok": ok, "summary": "success %s (pressed in reach %s, clean misses %s, into a cut %d took %d) / attempts %s, cuts %d (missed %s), windows %s, recovery %s, immunity %d, lock %d frames in reach (%s), final %s" % [successes, in_reach, clean_misses, cut_tries, cut_takes, tries, cuts, missed_cuts, in_window, recovery, immunity, tested_lock, lock_ok, s.puck.get("holder","loose")]}
