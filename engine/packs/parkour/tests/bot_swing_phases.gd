extends "bot_course.gd"
## Twelve matched start delays. Keep running after a hit to measure the actual checkpoint cost.
const DELAYS := [0, 13, 26, 39, 52, 65, 78, 91, 104, 117, 130, 143]
var pair := 0
var blind := true
var initialized := false
var blind_frames := 0
var blind_hits := 0
var witnessed := 0
var hit_delays: Array[int] = []
var open_delays: Array[int] = []
var recovery_costs: Array[int] = []
var clean_time_mismatches: Array[int] = []
var verdict: Dictionary


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	if not initialized:
		initialized = true
		_next_trial()
		return
	if state.total_frames < DELAYS[pair]:
		hand.release_all()
		hand.tick()
		return
	if state.falls > witnessed:
		# Check both the actual touch and the return to the near checkpoint. A missed pad is a failed test.
		var swept: bool = (state.swing_hits == state.falls and state.falls == witnessed + 1
			and state.checkpoint == 8 and absf(state.return_x - (state.beam_start + 0.6)) < 0.25
			and state.stage_splits.size() == 1)
		if not blind or not swept:
			_fail("unexpected fall")
			return
		witnessed += 1
	if state.state == "over":
		_score_trial()
		return
	super._bot_tick(frame)


func _crossing_open(t: float) -> bool:
	return blind or super(t)


func _score_trial() -> void:
	if state.reason != "laps" or not passed_weight:
		_fail("did not finish beyond the pendulum")
		return
	if blind:
		blind_frames = state.total_frames
		blind_hits = witnessed
		blind = false
	else:
		var cost := blind_frames - int(state.total_frames)
		if blind_hits > 0:
			if cost <= 0:
				_fail("charging through a strike was as fast or faster")
				return
			hit_delays.append(DELAYS[pair])
			recovery_costs.append(cost)
		else:
			if cost != 0:
				clean_time_mismatches.append(DELAYS[pair])
			open_delays.append(DELAYS[pair])
		pair += 1
		blind = true
		if pair == DELAYS.size():
			var ok := hit_delays.size() >= 4 and open_delays.size() >= 2 and clean_time_mismatches.is_empty()
			verdict = {"ok": ok, "timed_finishes": pair, "clean_time_mismatches": clean_time_mismatches,
				"hit_delays": hit_delays, "cost_frames": recovery_costs, "open_delays": open_delays,
				"summary": "%d clean timed finishes. Charging took a hit at %s, cost %s ticks; no contact at %s; unequal clean times at %s" % [
					pair, hit_delays, recovery_costs, open_delays, clean_time_mismatches]}
			return
	_next_trial()


func _next_trial() -> void:
	_restart_run()
	through = blind
	witnessed = 0


func _fail(reason: String) -> void:
	verdict = {"ok": false, "summary": "%s at delay %d, blind %s, race %d, blind race %d, hits %d, %s" % [
		reason, DELAYS[pair], blind, state.total_frames, blind_frames, state.swing_hits, _where()]}


func _bot_done() -> bool:
	return not verdict.is_empty()


func _bot_result() -> Dictionary:
	return verdict
