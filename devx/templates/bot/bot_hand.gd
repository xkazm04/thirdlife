extends Node
## Bot for {{name}} through a person's hand (TLHand, profile `{{profile}}`): it decides intents, the hand presses them
## the way a person would (late, taps of human length, keys instead of an analog axis, now and then away). Use it for
## anything about feel, reach or difficulty, and quote a level's number with the hand it was read through
## (engine/seeds/README.md, "A bot is not a person"). A skeleton that finishes: replace the body of _bot_tick with play.
## Lint counts variables named score*, clock*, timer*, period*, lap* as hand-rolled rules: use other names.

var ctx
var done: bool = false
var state: Dictionary = {}
var hand: TLHand


func _bot_setup(c) -> void:
	ctx = c
	hand = TLHand.create(ctx, "{{profile}}")


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	# TODO: intents go to the hand, never to ctx.input: hand.tap(&"nudge"), hand.press(&"jump") / hand.release(&"jump"),
	# hand.set_axis(&"left", &"right", x), hand.steer(&"left", &"right", &"up", &"down", Vector2(x, y))
	var actions: PackedStringArray = ctx.input.declared()
	if not actions.is_empty() and frame % 90 == 30:
		hand.tap(StringName(actions[0]))
	hand.tick()                                   # last: the hand acts on what is due
	if frame >= 600:
		done = true


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	# TODO: decide ok from the state, not from the frame count; keep the hand's numbers in the result
	var h: Dictionary = hand.stats()
	return {"ok": done and (hand.is_perfect() or int(h["decisions"]) > 0),
		"summary": "skeleton bot ran %d frames through the hand '%s': %d decisions, %d presses, mean reaction %.1f frames" % [
			ctx.frame, hand.profile, h["decisions"], h["presses"], h["mean_reaction_frames"]],
		"hand": h}
