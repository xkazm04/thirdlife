extends Node
## Bot (K4): wants the aim on the target every tick and decides to shoot 40 frames after each jump, through a TLHand of
## the profile `profile` (this file: perfect; bot_aim_<profile>.gd set another one). The hand moves the aim as a
## person's cursor and presses as a person's finger. ok: all TARGETS targets were played; under `perfect`, every shot hit.

const DECIDE: int = 40
var profile: String = "perfect"
var ctx
var hand: TLHand
var state: Dictionary = {}
var last_index: int = -1
var shoot_at: int = -1
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c
	hand = TLHand.create(ctx, profile)


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	if not bool(state.get("over", false)) and int(state.get("index", -1)) >= 0:
		hand.set_aim(&"aim", Vector3(float(state["target_x"]), 0.0, float(state["target_z"])))
		if int(state["index"]) != last_index:
			last_index = int(state["index"])
			shoot_at = frame + DECIDE
		if frame == shoot_at:
			hand.tap(&"shoot")
	done = bool(state.get("over", false))
	hand.tick()


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var st: Dictionary = hand.stats()
	var ok: bool = done and (int(state["hits"]) == int(state["shots"]) and int(state["shots"]) == 20 if hand.is_perfect() else int(st["aim_targets"]) > 0)
	return {"ok": ok, "summary": "%s: hits %d of %d shots (20 targets); mean aim error at the shot %.3f m; mean lag to reach a target %.1f frames; hand: %d aim targets, mean aim reaction %.1f frames, %d lapses, %d taps lost to a lapse" % [
			profile, int(state["hits"]), int(state["shots"]), float(state["mean_error"]), float(state["mean_lag"]), int(st["aim_targets"]),
			float(st["mean_aim_lag_frames"]), int(st["lapses"]), int(st["taps_lost"])],
		"profile": profile, "hits": int(state["hits"]), "shots": int(state["shots"]), "mean_error": snappedf(float(state["mean_error"]), 0.001),
		"mean_lag": snappedf(float(state["mean_lag"]), 0.1), "taps_lost": int(st["taps_lost"]), "lapses": int(st["lapses"])}
