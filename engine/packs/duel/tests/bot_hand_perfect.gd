extends "support/pilot.gd"
## Hand check (card.duel): one best-of-3 against the Wall through the perfect hand; reports won.


func _init() -> void:
	rung = 0
	hand_profile = "perfect"
