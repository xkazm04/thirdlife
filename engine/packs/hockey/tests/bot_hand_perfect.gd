extends "bot_hockey.gd"
## Hand check (card.team_possession, contracts/CARDS.md "Hand checks"): level rookie through the perfect hand, with the
## cursor through the hand and passes, as bot_ladder_rookie_perfect.gd plays. ok = played to the end and the hand acted;
## won (bool) is in the result: `tl cards hands engine/packs/hockey --card team_possession` counts it over seeds 1..20.


func _init() -> void:
	hand_profile = "perfect"
	level = "rookie"
	use_pass = true
	require_win = false
	use_aim = true
