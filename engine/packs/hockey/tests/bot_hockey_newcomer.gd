extends "bot_hockey.gd"
## H5: bot_hockey.gd, the same decisions, pressed through TLHand's profile `newcomer`; no level.
## ok: played to the end and the hand acted; who won is a number in the result (engine/seeds/README.md, "A bot is not a person").


func _init() -> void:
	hand_profile = "newcomer"
	level = ""
	use_pass = false
