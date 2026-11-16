extends Node
## Bot (H3): the rule dial through a person's keys. It starts the drill still_beside (everybody else parked, no goal can
## end the match before period 2, so the test is about the dial); the period clock runs. In period 1 it presses T
## (the match pauses); the first dial (skate speed) is selected, W moves it one step up and closes it. A second T
## in period 1 must be refused. In period 2 it presses T, D (to shot speed), W. It reads every step from the state.
## ok: the panel paused the match, both changes are in the state (skate +1, shot +1), the third try was refused,
## each change is recorded in its own period.

var ctx
var s: Dictionary = {}
var step: int = 0
var wait_until: int = 0
var saw_paused: int = 0
var notes: Array = []
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if done or frame < wait_until:
		return
	var dl: Dictionary = s["dial"]
	if bool(dl["open"]) and str(s["state"]) == "paused":
		saw_paused += 1
	match step:
		0:
			ctx.input.tap(&"drill_still_beside")
			step = 1
			wait_until = frame + 120
		1:
			if str(s["state"]) == "running" and int(s["period"]) == 1:
				ctx.input.tap(&"dial")
				step = 2
				wait_until = frame + 3
		2:
			notes.append("p1 open=%s selected=%s state=%s" % [str(dl["open"]), str(dl.get("selected", "")), str(s["state"])])
			ctx.input.tap(&"up")
			step = 3
			wait_until = frame + 3
		3:
			notes.append("p1 after W: skate=%d open=%s state=%s line='%s'" % [int(dl["values"]["skate"]), str(dl["open"]), str(s["state"]), str(s.get("rule_line", ""))])
			ctx.input.tap(&"dial")
			step = 4
			wait_until = frame + 3
		4:
			notes.append("p1 third try: open=%s refused=%d line='%s'" % [str(dl["open"]), int(dl["refused"]), str(s.get("rule_line", ""))])
			step = 5
		5:
			if str(s["state"]) == "over":
				notes.append("the match ended in period %d before period 2" % int(s["period"]))
				done = true
			elif str(s["state"]) == "running" and int(s["period"]) == 2:
				ctx.input.tap(&"dial")
				step = 6
				wait_until = frame + 3
		6:
			notes.append("p2 open=%s state=%s" % [str(dl["open"]), str(s["state"])])
			ctx.input.tap(&"right")
			step = 7
			wait_until = frame + 3
		7:
			notes.append("p2 selected=%s" % str(dl.get("selected", "")))
			ctx.input.tap(&"up")
			step = 8
			wait_until = frame + 3
		8:
			notes.append("p2 after W: shot=%d open=%s line='%s'" % [int(dl["values"]["shot"]), str(dl["open"]), str(s.get("rule_line", ""))])
			done = true


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var dl: Dictionary = s.get("dial", {})
	var v: Dictionary = dl.get("values", {})
	var used: Dictionary = dl.get("used", {})
	var ok: bool = done and step == 8 and int(v.get("skate", 0)) == 1 and int(v.get("shot", 0)) == 1 and int(dl.get("refused", 0)) >= 1 \
		and used.has("1") and used.has("2") and saw_paused > 0 and not bool(dl.get("open", true))
	return {"ok": ok, "summary": "dials %s used %s refused %d; paused frames seen %d; %s" % [str(v), str(used), int(dl.get("refused", 0)), saw_paused, " | ".join(notes)],
		"dials": v, "used": used}
