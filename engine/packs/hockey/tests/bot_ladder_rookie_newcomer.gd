extends "bot_hockey.gd"
## H5: the ladder: level rookie read through the hand it is meant for (`newcomer`).
## ok: played to the end and the hand acted; who won is a number in the result (engine/seeds/README.md, "A bot is not a person").


func _init() -> void:
	hand_profile = "newcomer"
	level = "rookie"
	use_pass = true
	require_win = false
