extends "bot_hockey.gd"
## H5: the ladder: level rookie read through the perfect hand (the gap beside the newcomer row).
## H9: with the cursor through the hand (use_aim), shooting inside a person's range (16 m).
## H10: ok = blue WINS (the gate's one verdict about the game: the perfect hand beats rookie on 20 of 20 seeds 1..20).
## (The other cells: ok = played to the end and the hand acted; who won is a number in the result) (engine/seeds/README.md, "A bot is not a person").


func _init() -> void:
	hand_profile = "perfect"
	level = "rookie"
	use_pass = true
	require_win = false
	use_aim = true
	must_win = true
