extends Node
## Hand check (card.knock_down, contracts/CARDS.md "Hand checks"): the policy of tests/bot_knock.gd played through
## TLHand.create(ctx, hand_profile); this file is the perfect hand, and tests/bot_hand_<hand>.gd extend it with another
## profile ("idle" presses nothing). Done when the game is over. ok = it finished; won (bool) = the player won.
## `tl cards hands <this seed> --card <id>` and the Foreman count `won` over seeds 1..20.

const NEAR: float = 5.0
const FAR: float = 9.5

var hand_profile: String = "perfect"
var ctx
var hand: TLHand
var s: Dictionary = {}
var done: bool = false
var retreating: bool = false
var frames: int = 0


func _bot_setup(c) -> void:
	ctx = c
	if hand_profile != "idle":
		hand = TLHand.create(ctx, hand_profile)


func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	frames = frame
	done = s["state"] == "over"      # no cap of its own: the game must end the round by itself (an idle player too)
	if hand == null:
		return
	if done:
		hand.release_all()
		hand.tick()
		return
	var me: Dictionary = s["player"]
	var target: Dictionary = _pick_block(float(me["x"]))
	var dx: float = float(target["x"]) - float(me["x"])
	var ahead: float = float(me["z"]) - float(target["z"])
	if ahead < NEAR:
		retreating = true
	elif ahead > FAR - 1.0:
		retreating = false
	hand.set_axis(&"left", &"right", clampf(dx * 2.0, -1.0, 1.0))
	if retreating:
		hand.set_axis(&"forward", &"back", 1.0)
	else:
		hand.set_axis(&"forward", &"back", -1.0 if ahead > FAR else -0.15)
	var aimed: bool = absf(dx) < 0.3 and float(me["fz"]) < -0.97 and ahead <= FAR + 0.5 and not retreating
	if aimed and bool(me["holding"]):
		hand.tap(&"throw")
	hand.tick()


func _pick_block(x: float) -> Dictionary:
	var best: Dictionary = {}
	for want_intact: bool in [true, false]:
		for b: Dictionary in s["blocks"]:
			if (b["state"] == "intact") == want_intact and (best.is_empty() or absf(float(b["x"]) - x) < absf(float(best["x"]) - x)):
				best = b
		if not best.is_empty():
			break
	return best


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var won: bool = s.get("state", "") == "over" and s.get("reason", "") == "score" and s.get("winner", "") == "player"
	return {"ok": done, "won": won, "summary": "%s: %s by %s, %d pieces down, %d throws, frame %d" % [hand_profile, "WIN" if won else "no win",
			str(s.get("reason", "-")), int(s.get("pieces_down", 0)), int(s.get("throws", 0)), frames],
		"goals": int(s.get("pieces_down", 0)), "shots": int(s.get("throws", 0)), "frames": frames}
