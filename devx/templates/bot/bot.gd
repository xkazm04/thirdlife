extends Node
## Bot for {{name}}: a skeleton that finishes. Replace the body of _bot_tick with play, and make `ok` mean "the game
## was won / the mechanism really ran", read from ctx.pack_state() (put what the bot needs into _pack_state()).
## Lint counts variables named score*, clock*, timer*, period*, lap* as hand-rolled rules: use other names.

var ctx
var done: bool = false
var state: Dictionary = {}


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	# TODO: press declared actions here, e.g. ctx.input.tap(&"nudge")
	if frame >= 600:
		done = true


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	# TODO: decide ok from the state, not from the frame count
	return {"ok": done, "summary": "skeleton bot ran %d frames" % ctx.frame}
