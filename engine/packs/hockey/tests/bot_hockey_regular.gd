extends "bot_hockey.gd"
## H5: bot_hockey.gd, the same decisions, pressed through TLHand's profile `regular`; no level (the opponents as in data/ai.json).
## ok: played to the end and the hand acted; who won is a number in the result (engine/seeds/README.md, "A bot is not a person").


func _init() -> void:
	hand_profile = "regular"
	level = "none"
	use_pass = false
