extends Node
## Bot: plays seed.paddle to the end through the player's two actions (left, right) and wins.
##
## How it plays: when the ball flies toward it, it works out where the ball will cross the paddle line (straight
## flight, mirrored at the side walls) and goes there. It does not meet the ball with the middle of the paddle: it
## offers the edge that sends the ball to the side of the court the rival is NOT on, which the slow rival cannot reach.
## How it decides it won: the rules say the game is over, the winner is "player" and the player's score is the
## score_to_win. It reads all of that from ctx.pack_state(), the same snapshot the HUD shows.

var ctx
var s: Dictionary = {}
var done: bool = false
var longest_rally: int = 0


func _bot_setup(c) -> void:
	ctx = c


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
	ctx.input.set_axis(&"left", &"right", clampf(error * 4.0, -1.0, 1.0))


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
	return {"ok": ok, "summary": "the bot won %d : %d in %d frames (%.0f s); longest rally %d paddle hits" % [mine, theirs, ctx.frame, ctx.seconds(ctx.frame), longest_rally],
		"player": mine, "rival": theirs, "frames": ctx.frame, "longest_rally": longest_rally, "winner": str(s.get("winner", ""))}
