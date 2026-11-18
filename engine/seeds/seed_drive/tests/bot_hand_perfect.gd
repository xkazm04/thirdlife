extends Node
## Hand check (card.timed_drive, contracts/CARDS.md "Hand checks"): the policy of tests/bot_laps.gd played through
## TLHand.create(ctx, hand_profile); this file is the perfect hand, and tests/bot_hand_<hand>.gd extend it with another
## profile ("idle" presses nothing). Done when the game is over. ok = it finished; won (bool) = the player won.
## `tl cards hands <this seed> --card <id>` and the Foreman count `won` over seeds 1..20.

const FAST: float = 19.0
const SLOW: float = 10.0
const BOOST: float = 30.0              # speed allowed while the nitro burns

var hand_profile: String = "perfect"
var hand: TLHand
var ctx
var s: Dictionary = {}
var done: bool = false
var worst_off_line: float = 0.0
var boosting: bool = false


func _bot_setup(c) -> void:
	ctx = c
	if hand_profile != "idle":
		hand = TLHand.create(ctx, hand_profile)


func _bot_tick(_frame: int) -> void:
	s = ctx.pack_state()
	done = s["state"] == "over"
	if hand == null:
		return
	if done:
		hand.release_all()
		hand.tick()
		return
	var car: Dictionary = s["car"]
	hand.set_axis(&"left", &"right", clampf(_side(car, s["ahead"]) * 2.5, -1.0, 1.0))
	var bend: float = absf(_side(car, s["far"]))               # 0 = straight road ahead, 1 = a right angle
	if float(car["nitro_charge"]) >= 1.0 and bend < 0.05:
		boosting = true
	elif float(car["nitro_charge"]) <= 0.0 or bend > 0.2:
		boosting = false
	hand.press(&"nitro", 1.0 if boosting else 0.0)
	var limit: float = BOOST if boosting else lerpf(FAST, SLOW, clampf(bend * 4.0, 0.0, 1.0))
	var speed: float = float(car["forward_speed"])
	hand.press(&"gas", 1.0 if speed < limit else 0.0)
	hand.press(&"brake", 1.0 if speed > limit + 1.5 else 0.0)
	worst_off_line = maxf(worst_off_line, absf(float(s["off_line"])))
	hand.tick()


## How far to the side of the car's nose a point [x, z] is: -1 = hard left, 0 = dead ahead, +1 = hard right.
func _side(car: Dictionary, point: Array) -> float:
	var dx: float = float(point[0]) - float(car["x"])
	var dz: float = float(point[1]) - float(car["z"])
	return (float(car["fx"]) * dz - float(car["fz"]) * dx) / maxf(0.001, sqrt(dx * dx + dz * dz))


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var rounds: int = int((s.get("laps", {}) as Dictionary).get("car", 0))
	var won: bool = done and str(s.get("winner", "")) == "car" and str(s.get("reason", "")) == "laps"
	return {"ok": done, "won": won, "goals": rounds, "frames": int(s.get("total_frames", 0)),
		"summary": "%s: %s, %d laps, ended by %s" % [hand_profile, "won" if won else "lost", rounds, str(s.get("reason", ""))]}
