extends "rink_bot.gd"
## N3 (22 Nov, director): the carrying burst is read on whichever red skater carries (the utility AI rotates roles; r0 is no
## longer always the chaser who carries).
## N3 uses 14.95 m/s² free thrust for the control push, with the same 26 m/s² reverse stop.
## H1 build (23 Nov), sheet rows A2/A3: free thrust 8.73 x 1.15 = 10.0395 m/s², reverse_decel 13: from 8 m/s still inside 30 frames
## (thirdjam's 29 from its top) over at most 2.3 m.
## Drive the warm-up, reversal and control through the same two movement keys.
## A fresh set start facing the push gives the control no cut, own stop or rest credit.

var phase := "start"
var t0 := 0
var entry := 0.0
var last := Vector2.ZERO
var travel := 0.0
var stop_frames := -1
var stops := 0
var push10 := 0.0
var push20 := 0.0
var control10 := 0.0
var control20 := 0.0
var control_clean := true
var free_skate := true
var red_frames := 0
var red_carried := 0

func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	var me: Dictionary = s.skaters[0]
	var speed: float = me.speed
	var pos := Vector2(me.pos[0], me.pos[1])
	var skate: Dictionary = s.get("skate", {})
	var bursts: Dictionary = skate.get("burst_left", {})
	var age := frame - t0
	if phase in ["run", "brake", "push", "control"]:
		free_skate = free_skate and not s.puck.has("holder")
	match phase:
		"start":
			ctx.input.tap(&"drill_reverse_lane")
			ctx.input.set_axis(&"left", &"right", 1.0)
			phase = "run"
		"run":
			if speed >= 7.99:
				entry = speed
				last = pos
				ctx.input.set_axis(&"left", &"right", -1.0)
				phase = "brake"
				t0 = frame
		"brake":
			travel += pos.distance_to(last)
			last = pos
			if speed < 0.05:   # H1 build (A3): at 13 m/s2 a frame takes 0.22 m/s off, so "under 0.3" fired a frame before the stop (at 26 it was the stop)
				stop_frames = age
				phase = "push"
				t0 = frame
		"push":
			if age == 10:
				push10 = speed
			if age == 20:
				push20 = speed
				stops = int(skate.get("stops", {}).get("b0", 0))
				ctx.input.tap(&"drill_push_lane")
				phase = "control"
				t0 = frame
		"control":
			control_clean = control_clean and not bursts.has("b0")
			if age == 10:
				control10 = speed
			if age == 20:
				control20 = speed
				ctx.input.set_axis(&"left", &"right", 0.0)
				ctx.input.tap(&"mode_base")
				phase = "autopilot"
		"autopilot":
			ctx.input.tap(&"level_none")
			ctx.input.tap(&"autopilot")
			phase = "match"
			t0 = frame
		"match":
			if s.autopilot and not s.has("drill") and bursts.has("r0"):
				red_frames += 1
			var h: String = str(s.puck.get("holder", ""))
			if s.autopilot and not s.has("drill") and h.begins_with("r") and bursts.has(h):
				red_carried += 1   # N3: roles rotate (F1/D1 by time to the puck), so any red carrier's burst counts, not r0's alone
			if age == 1800:
				done = true
	if frame > 2400:
		done = true

func _bot_result() -> Dictionary:
	var ok := done and free_skate and entry >= 7.99 and stop_frames > 0 and stop_frames <= 30 and travel <= 2.3 \
		and stops == 1 and control_clean and absf(control10 - (10.0395 - 9.8 * 0.015) * 10 / 60) < 0.02 and push10 >= 1.5 * control10 and push20 > control20 and red_carried > 0
	return {"ok": ok, "summary": "from %.3f m/s to under 0.05 in %d frames over %.3f m, stops %d, push vs control at 10f %.3f/%.3f, at 20f %.3f/%.3f, free %s clean %s, r0 burst frames %d (carrying %d)" % [entry, stop_frames, travel, stops, push10, control10, push20, control20, free_skate, control_clean, red_frames, red_carried]}

