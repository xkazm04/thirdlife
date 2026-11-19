extends "bot_course.gd"
## Replay the same course with one instruction removed each time. Judge the missing landing or the blocked face.
const CASES := ["no steering", "keep the first pad line", "skip the second hop", "run off the wall lip",
	"no tower jumps", "hold run on the tower", "normal run"]
const FALL_GATE := [5, 7, 6, 9, -1, 11]
var trial := 0
var blocked_ticks := 0
var observations: Array[String] = []
var verdict: Dictionary


func _aim_return(frame: int) -> void:
	if trial == 0 or (trial == 1 and state.checkpoint >= 6):
		return
	super._aim_return(frame)


func _return_inputs(frame: int) -> void:
	var gate := int(state.checkpoint)
	if (trial == 2 and gate == 6) or (trial == 3 and gate == 9) or (trial == 4 and gate >= 10):
		last_leap = frame
	super._return_inputs(frame)
	if trial == 5 and gate >= 10:
		hand.press(&"run")


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	if trial == 4 and state.checkpoint == 10 and state.motion == "ground":
		var face: float = state.crest + state.tier_length
		if state.return_x >= face - 0.45 and state.return_x < face:
			blocked_ticks += 1
			if blocked_ticks == 90:
				_next("blocked below the first tower ledge for 90 ticks")
				return
	if state.falls > 0:
		if trial < FALL_GATE.size() and state.swing_hits == 0 and state.checkpoint == FALL_GATE[trial]:
			_next("fell back to checkpoint %d" % state.checkpoint)
		else:
			_fail()
		return
	if state.state == "over":
		if trial == CASES.size() - 1 and state.reason == "laps" and passed_weight and jumped_wall and tower_air == [true, true]:
			observations.append("normal run finished in %d frames" % state.total_frames)
			verdict = {"ok": true, "summary": "; ".join(observations)}
		else:
			_fail()
		return
	super._bot_tick(frame)


func _next(observation: String) -> void:
	observations.append("%s: %s" % [CASES[trial], observation])
	trial += 1
	_restart_run()


func _fail() -> void:
	verdict = {"ok": false, "summary": "unexpected result for %s, %s, after %s" % [CASES[trial], _where(), observations]}


func _bot_done() -> bool:
	return not verdict.is_empty()


func _bot_result() -> Dictionary:
	return verdict
