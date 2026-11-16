extends "bot_hockey.gd"
## H5: the ladder: level all-star read through the perfect hand.
## H9: with the cursor through the hand (use_aim), shooting inside a person's range (16 m).
## ok: played to the end and the hand acted; who won is a number in the result (engine/seeds/README.md, "A bot is not a person").


func _init() -> void:
	hand_profile = "perfect"
	level = "allstar"
	use_pass = true
	require_win = false
	use_aim = true
