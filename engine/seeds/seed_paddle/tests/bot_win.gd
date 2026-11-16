extends Node
## Bot: plays seed.paddle to the end through the player's two actions (left, right) and wins.
##
## How it plays: when the ball flies toward it, it works out where the ball will cross the paddle line (straight
## flight, mirrored at the side walls) and goes there. It does not meet the ball with the middle of the paddle: it
## offers the edge that sends the ball to the side of the court the rival is NOT on, which the slow rival cannot reach.
## How it decides it won: the rules say the game is over, the winner is "player" and the player's score is the
## score_to_win. It reads all of that from ctx.pack_state(), the same snapshot the HUD shows.
##
## Whose hand: it presses through TLHand. This file plays with the hand `perfect` (every press on the frame it is
## decided, the axis as an analog value: the result and state hash it had before the hand existed). The same bot
## through a person's hand: bot_win_regular.gd and bot_win_newcomer.gd (a won game is not required there; the
## result says who won and proves the hand ran).

var ctx
var s: Dictionary = {}
var done: bool = false
var longest_rally: int = 0
var hand_profile: String = "perfect"
var hand: TLHand


func _bot_setup(c) -> void:
	ctx = c
	hand = TLHand.create(ctx, hand_profile)


func _bot_tick(_frame: int) -> void:
	s = ctx.pack_state()
	done = s["state"] == "over"
	longest_rally = maxi(longest_rally, int(s["rally"]))
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
	var mine: int = int(tally.get("player", 0))
	var theirs: int = int(tally.get("rival", 0))
	var ok: bool = done and s["winner"] == "player" and s["reason"] == "score" and mine == 5 and str(s["hud"]["hint"]) == "PLAYER wins"
	if not hand.is_perfect():
		# through a person's hand the game may be lost: ok is "it was played to the end, and the hand really acted"
		var h: Dictionary = hand.stats()
		var played: bool = done and s["reason"] == "score" and maxi(mine, theirs) == 5 and str(s["hud"]["hint"]) == "%s wins" % str(s["winner"]).to_upper()
		return {"ok": played and int(h["decisions"]) > 0 and int(h["presses"]) > 0 and float(h["mean_reaction_frames"]) > 0.0,
			"summary": "hand %s: %s %d : %d in %d frames (%.0f s); longest rally %d; %d decisions, mean reaction %.1f frames, %d presses, %d taps lengthened, %d held through a change, %d overshoots, %d lapses (%d frames)" % [
				hand.profile, "won" if s["winner"] == "player" else "lost", mine, theirs, ctx.frame, ctx.seconds(ctx.frame), longest_rally,
				h["decisions"], h["mean_reaction_frames"], h["presses"], h["lengthened"], h["sticks"], h["overshoots"], h["lapses"], h["lapse_frames"]],
			"player": mine, "rival": theirs, "frames": ctx.frame, "longest_rally": longest_rally, "winner": str(s.get("winner", "")), "hand": h}
	return {"ok": ok, "summary": "the bot won %d : %d in %d frames (%.0f s); longest rally %d paddle hits" % [mine, theirs, ctx.frame, ctx.seconds(ctx.frame), longest_rally],
		"player": mine, "rival": theirs, "frames": ctx.frame, "longest_rally": longest_rally, "winner": str(s.get("winner", ""))}
