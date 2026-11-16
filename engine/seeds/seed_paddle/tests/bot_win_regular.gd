extends "bot_win.gd"
## bot_win.gd, the same decisions, pressed through TLHand's profile `regular` (reaction 8..13 frames, keys not an
## analog axis, taps of 5..8 frames, releases late, now and then away). ok: played to the end and the hand acted;
## who won is in the result. engine/seeds/README.md, "A bot is not a person".


func _init() -> void:
	hand_profile = "regular"
