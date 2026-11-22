extends "rink_bot.gd"
## N3 wrist/full charge are 24/32 m/s. A reception press releases four frames after the take.
## Observe the actual puck velocity on the first frame after release. The opposing poker returns the
## puck to the same held button so a release cannot pass the loss test just because the puck is absent.

const HOLDS := [1, 4, 5, 15, 30, 40, 6]

var row := 0
var phase := "start"
var since := 0
var shots_before := 0
var take_frame := 0
var timers_before := 0
var speeds: Array[float] = []
var saw_poke := false
var regained := false
var clean := true

func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	var holder: String = s.puck.get("holder", "")
	var age := frame - since
	var shots: int = s.shots.b0
	var timers: int = s.possession.get("one_timers", {}).get("b0", 0)
	match phase:
		"start":
			var drill := "carry_alone"
			if row == HOLDS.size() - 1:
				drill = "goalie_cross"
			elif row == HOLDS.size():
				drill = "charge_loss"
			ctx.input.tap(StringName("drill_" + drill))
			since = frame
			phase = "ready"
		"ready":
			if holder == "b0" and s.shoot_ready:
				take_frame = s.possession.since
				ctx.input.press(&"shoot")
				shots_before = shots
				timers_before = timers
				since = frame
				phase = "loss" if row == HOLDS.size() else ("timer" if row == HOLDS.size() - 1 else "hold")
		"hold":
			clean = clean and shots == shots_before and holder == "b0" and s.possession.get("charge_frames", -1) == mini(age, 30)
			if age == HOLDS[row]:
				ctx.input.release(&"shoot")
				phase = "flight"
		"timer":
			clean = clean and not s.possession.has("charge_frames")
			if shots > shots_before:
				clean = clean and s.possession.last.frame - take_frame == 4
				ctx.input.release(&"shoot")
				phase = "flight"

		"loss":
			clean = clean and shots == shots_before
			if s.possession.get("last", {}).get("kind") == "poked":
				saw_poke = true
			if saw_poke:
				clean = clean and not s.possession.has("charge_frames")
				if holder == "b0":
					regained = true
			if regained and age >= 60:
				ctx.input.release(&"shoot")
				phase = "dead_release"
		"dead_release":
			clean = clean and shots == shots_before and holder == "b0"
			ctx.input.tap(&"shoot")
			phase = "repress"
		"repress":
			if shots == shots_before + 1:
				done = true
	if phase == "flight" and shots > shots_before:
		var vel := Vector2(s.puck.vel[0], s.puck.vel[1])
		speeds.append(vel.length())
		clean = clean and shots == shots_before + 1 and s.possession.last.kind == "shot" and holder == "" \
			and timers - timers_before == int(row == HOLDS.size() - 1)
		row += 1
		phase = "start"
	if frame > 1000:
		done = true

func _bot_result() -> Dictionary:
	var expected := [24.0, 24.0, 24.0 + 8.0 * 5 / 30, 28.0, 32.0, 32.0, 28.8]
	var ok := done and clean and saw_poke and regained and phase == "repress" and speeds.size() == expected.size()
	for i in speeds.size():
		ok = ok and absf(speeds[i] - expected[i]) <= 0.02
	return {"ok": ok and ctx.pack_state().shots.b0 == shots_before + 1, "summary": "release speeds %s m/s, poked %s, regained %s, shot count/charge edges %s" % [speeds, saw_poke, regained, clean],
		"speeds": speeds, "poked": saw_poke, "regained": regained, "edges": clean}

