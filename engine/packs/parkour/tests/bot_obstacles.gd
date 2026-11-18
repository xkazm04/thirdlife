extends Node
## Negative controls through the same keys: miss both gaps, run into the lintel standing, try jumping, then restart.
var ctx: TLContext
var hand: TLHand
var phase := 0
var first_recovery := false
var second_recovery := false
var blocked_ticks := 0
var furthest := 0.0
var verdict: Dictionary


func _bot_setup(c: TLContext) -> void:
	ctx = c
	hand = TLHand.create(ctx, "perfect")


func _bot_tick(frame: int) -> void:
	var s := ctx.pack_state()
	var at := float(s.station)
	hand.press(&"forward")
	hand.press(&"run")
	match phase:
		0:
			if s.falls == 1:
				first_recovery = s.checkpoint == 0 and absf(at) < 0.2
				phase = 1
		1:
			if at >= s.first_lip - 0.85 and at < s.first_lip:
				hand.tap(&"jump")
				phase = 2
		2:
			if s.falls == 2:
				second_recovery = s.checkpoint == 1 and absf(at - (s.first_land + 2.5)) < 0.2
				phase = 3
		3:
			if at >= s.chain_lip - 0.85 and at < s.chain_lip:
				hand.tap(&"jump")
				phase = 4
		4:
			if at >= s.bar - 0.6:
				furthest = maxf(at, furthest)
				blocked_ticks += 1
				if blocked_ticks == 25:
					hand.tap(&"jump")
				if blocked_ticks == 85:
					hand.tap(&"restart")
					phase = 5
		5:
			verdict = {"ok": first_recovery and second_recovery and s.falls == 0 and s.checkpoint == 0 and at < 0.2
				and s.total_frames <= 1 and furthest < s.bar,
				"summary": "missed gaps respawned at start / checkpoint: %s / %s; with run and jump but no slide, furthest %.2f before bar %.2f in %d ticks; R reset station %.2f and time %d" % [
					first_recovery, second_recovery, furthest, s.bar, blocked_ticks, at, s.total_frames]}
	if frame >= 1000 and verdict.is_empty():
		verdict = {"ok": false, "summary": "failed obstacle probe in phase %d, station %.2f, falls %d" % [phase, at, s.falls]}
	hand.tick()


func _bot_done() -> bool:
	return not verdict.is_empty()


func _bot_result() -> Dictionary:
	return verdict
