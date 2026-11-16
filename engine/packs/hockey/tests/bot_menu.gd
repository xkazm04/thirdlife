extends Node
## Bot (H14): the panel before the face-off, through its keys. It presses the keyless `menu` (a person's session opens the
## panel by itself: ctx.mode "play"), then 2 (pro), D twice (sudden death), Space: the match must start as pro / sudden
## death. With the autopilot it plays to the end, presses R: the panel must come back with pro / sudden death kept; this
## time it presses nothing: the panel must start by itself after menu.auto_start_frames with that choice.
## ok: each step as stated (the frames are in the result).

var ctx
var s: Dictionary = {}
var step: int = 0
var t: int = 0
var notes: Array = []
var ok_steps: int = 0
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if done:
		return
	var m: Dictionary = s.get("menu", {})
	match step:
		0:
			ctx.input.tap(&"menu")
			step = 1
			t = frame
		1:
			if not m.is_empty() and frame - t > 2:
				notes.append("panel open: level %s, mode %s" % [m["level"], m["mode"]])
				ctx.input.tap(&"pick_2")
				step = 2
				t = frame
		2:
			if frame - t == 3:
				ctx.input.tap(&"right")
			if frame - t == 13:
				ctx.input.tap(&"right")
			if frame - t == 23:
				notes.append("chosen: level %s, mode %s" % [m.get("level", "?"), m.get("mode", "?")])
				ctx.input.tap(&"shoot")
				step = 3
				t = frame
		3:
			if frame - t == 4:
				var started: bool = m.is_empty() and str(s["state"]) == "running" and str(s.get("level", "none")) == "pro" and str(s["mode"]) == "sudden_death"
				notes.append("Space: started %s (state %s, level %s, mode %s)" % [str(started), s["state"], s.get("level", "none"), s["mode"]])
				ok_steps += 1 if started else 0
				ctx.input.tap(&"autopilot")
				step = 4
		4:
			if str(s["state"]) == "over" and str(s.get("result", "")) != "":
				notes.append("match over at frame %d (%s)" % [frame, s["result"]])
				ctx.input.tap(&"restart")
				step = 5
				t = frame
		5:
			if frame - t == 4:
				var back: bool = not m.is_empty() and str(m["level"]) == "pro" and str(m["mode"]) == "sudden_death"
				notes.append("R: panel back %s (level %s, mode %s)" % [str(back), m.get("level", "?"), m.get("mode", "?")])
				ok_steps += 1 if back else 0
				step = 6
				t = frame
		6:
			if m.is_empty():
				var waited: int = frame - t
				var auto: bool = str(s["state"]) == "running" and str(s.get("level", "none")) == "pro" and str(s["mode"]) == "sudden_death" and waited >= 590 and waited <= 610
				notes.append("no input: started by itself after %d frames %s" % [waited, str(auto)])
				ok_steps += 1 if auto else 0
				done = true
			elif frame - t > 1200:
				notes.append("no input: still on the panel after 1200 frames")
				done = true


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	return {"ok": done and ok_steps == 3, "summary": " | ".join(notes), "steps_ok": ok_steps}
