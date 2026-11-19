extends "bot_course.gd"
## Repeat the same run after R with a deliberate start delay. Each stage keeps its own faster split.
var first: Array = []
var second_start := -1
var reset_seen := false
var summit_wait := 0
var result: Dictionary


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	if state.state == "over":
		if state.reason != "laps":
			result = {"ok": false, "summary": "timed out while verifying splits"}
		elif first.is_empty():
			first = state.stage_splits.duplicate()
			_restart_run()
			second_start = frame
		else:
			var second: Array = state.stage_splits
			var best: Array = state.stage_bests
			var correct := reset_seen and first.size() == 4 and second.size() == 4 and best.size() == 4
			if correct:
				correct = second[0] > first[0] + 50 and first[3] > second[3] + 30 and state.best_frames == mini(_sum(first), _sum(second))
				for i: int in 4:
					correct = correct and best[i] == mini(first[i], second[i])
			result = {"ok": correct, "summary": "R reset %s, first %s, second %s, best per stage %s" % [reset_seen, first, second, best]}
		return
	if second_start >= 0 and frame < second_start + 80:
		if state.stage_splits.is_empty() and state.stage_started == 0 and state.stage_bests == first and state.checkpoint == 0:
			reset_seen = true
		hand.release_all()
		hand.tick()
		return
	# Delay Skyline on the first lap so the second must replace its stored best.
	if second_start < 0 and state.checkpoint == 12 and summit_wait < 45:
		summit_wait += 1
		hand.release_all()
		hand.tick()
		return
	super._bot_tick(frame)


func _sum(times: Array) -> int:
	var total := 0
	for t: int in times:
		total += t
	return total


func _bot_done() -> bool:
	return not result.is_empty()


func _bot_result() -> Dictionary:
	return result
