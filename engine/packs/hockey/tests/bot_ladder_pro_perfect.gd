extends "bot_hockey.gd"
## H5: the ladder: level pro read through the perfect hand.
## ok: played to the end and the hand acted; who won is a number in the result (engine/seeds/README.md, "A bot is not a person").


func _init() -> void:
	hand_profile = "perfect"
	level = "pro"
	use_pass = true
	require_win = false
