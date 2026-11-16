extends "bot_win.gd"
## bot_win.gd, the same decisions, pressed through TLHand's profile `newcomer` (reaction 14..23 frames, keys not an
## analog axis, taps of 6..9 frames, releases late, buttons held through a change, away more often). ok: played to
## the end and the hand acted; who won is in the result. engine/seeds/README.md, "A bot is not a person".


func _init() -> void:
	hand_profile = "newcomer"
