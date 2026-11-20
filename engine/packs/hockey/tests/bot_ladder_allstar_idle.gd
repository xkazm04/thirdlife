extends "bot_hockey.gd"
## L5 (21 Nov): a ladder cell of the full table (levels x hands): level allstar read through the idle hand (presses nothing: the blue mates and the goalie play on their own).
## ok = played to the end; who won is the ladder's figure (tl ladder --pack engine/packs/hockey).


func _init() -> void:
	hand_profile = "idle"
	level = "allstar"
	use_pass = true
	require_win = false
	use_aim = true
