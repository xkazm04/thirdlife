extends "bot_hockey.gd"
## L5 (21 Nov): a ladder cell of the full table (levels x hands): level rookie read through the regular hand, with the cursor through the hand and passes.
## ok = played to the end and the hand acted; who won is the ladder's figure (tl ladder --pack engine/packs/hockey).


func _init() -> void:
	hand_profile = "regular"
	level = "rookie"
	use_pass = true
	require_win = false
	use_aim = true
