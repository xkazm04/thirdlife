extends "bot_course.gd"
## Slip off either side. Keep that strafe held through the respawn, run ahead, then release and steer again.
var side := 1
var testing_beam := false
var respawn_frame := -1
var start_x := 0.0
var max_drift := 0.0
var straight_travel := 0.0
var observations: Array[String] = []
var verdict: Dictionary


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	if state.checkpoint == 8:
		testing_beam = true
	if not testing_beam:
		super(frame)
		return
	var key := &"right" if side == 1 else &"left"
	hand.release_all()
	hand.press(&"run")
	if state.falls == 0:
		hand.press(key)
		hand.tick()
		return
	if state.falls != 1 or state.swing_hits != 0 or state.checkpoint != 8 or state.stage_splits.size() != 1:
		_fail("a second fall, swing hit or checkpoint change during recovery")
		return
	if respawn_frame < 0:
		respawn_frame = frame
		start_x = state.return_x
		if absf(start_x - (state.beam_start + 0.6)) > 0.10:
			_fail("missed the beam checkpoint")
			return
	var elapsed := frame - respawn_frame
	if elapsed <= 36:
		max_drift = maxf(max_drift, absf(state.return_z))
	if elapsed == 18 and (state.speed > 0.05 or absf(state.return_x - start_x) > 0.05):
		_fail("a held strafe moved the walker from rest")
		return
	if elapsed == 36:
		straight_travel = float(state.return_x) - start_x
		if straight_travel < 1.4 or max_drift > 0.05 or state.motion != "ground":
			_fail("forward with the old strafe did not run straight down the beam")
			return
	if elapsed >= 18:
		hand.press(&"forward")
	if elapsed < 36 or elapsed >= 40:
		hand.press(key)
	hand.tick()
	if elapsed == 48:
		var steered := float(side) * float(state.return_z)
		if steered < 0.1:
			_fail("a fresh strafe failed to steer")
			return
		observations.append("%s held through placement, drift %.3f m, forward %.3f m, fresh strafe %.3f m" % [
			key, max_drift, straight_travel, steered])
		if side == -1:
			verdict = {"ok": true, "summary": "; ".join(observations)}
		else:
			side = -1
			testing_beam = false
			respawn_frame = -1
			max_drift = 0.0
			_restart_run()


func _fail(why: String) -> void:
	verdict = {"ok": false, "summary": "%s, side %d, drift %.3f m. %s" % [why, side, max_drift, _where()]}


func _bot_done() -> bool:
	return not verdict.is_empty() or state.get("state") == "over"


func _bot_result() -> Dictionary:
	return verdict if not verdict.is_empty() else {"ok": false, "summary": "Did not complete both beam recoveries"}
