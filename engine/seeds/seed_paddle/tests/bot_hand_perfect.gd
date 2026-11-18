extends Node
## Hand check (card.two_sides_ball, contracts/CARDS.md "Hand checks"): the policy of tests/bot_win.gd played through
## TLHand.create(ctx, hand_profile); this file is the perfect hand, and tests/bot_hand_<hand>.gd extend it with another
## profile ("idle" presses nothing). Done when the game is over. ok = it finished; won (bool) = the player won.
## `tl cards hands <this seed> --card <id>` and the Foreman count `won` over seeds 1..20.

var ctx
var s: Dictionary = {}
var done: bool = false
var longest_rally: int = 0
var hand_profile: String = "perfect"
var hand: TLHand


func _bot_setup(c) -> void:
	ctx = c
	if hand_profile != "idle":
		hand = TLHand.create(ctx, hand_profile)


func _bot_tick(_frame: int) -> void:
	s = ctx.pack_state()
	done = s["state"] == "over"
	longest_rally = maxi(longest_rally, int(s["rally"]))
	if hand == null:
		return
	var ball: Dictionary = s["ball"]
	var target: float = 0.0                                    # wait in the middle
	if float(ball["vx"]) < -0.1 and bool(s["in_play"]):
		var t: float = (float(s["player_x"]) - float(ball["x"])) / float(ball["vx"])      # seconds until it arrives
		var z: float = _mirror(float(ball["z"]) + float(ball["vz"]) * t, float(s["court"]["half_width"]) - float(s["court"]["ball_radius"]))
		# aim: the ball leaves toward the side of the paddle it hits, so offer the edge away from the rival
		var edge: float = -0.7 if float(s["rival_z"]) > 0.0 else 0.7
		target = z - edge * float(s["court"]["paddle_half"])
	var error: float = target - float(s["player_z"])
	hand.set_axis(&"left", &"right", clampf(error * 4.0, -1.0, 1.0))
	hand.tick()


## Folds a z coordinate back into the court as often as the walls would bounce it.
func _mirror(z: float, half: float) -> float:
	var span: float = half * 4.0
	var m: float = fposmod(z + half, span)
	return (m if m <= half * 2.0 else span - m) - half


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var tally: Dictionary = s.get("scores", {})
	var won: bool = done and str(s.get("winner", "")) == "player"
	return {"ok": done, "won": won, "goals": int(tally.get("player", 0)), "against": int(tally.get("rival", 0)), "frames": ctx.frame,
		"summary": "%s: %s %d : %d in %d frames" % [hand_profile, "won" if won else "lost", int(tally.get("player", 0)), int(tally.get("rival", 0)), ctx.frame]}
