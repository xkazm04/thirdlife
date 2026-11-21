extends "support/pilot.gd"
## Hand check (card.duel): one best-of-3 against the Wall through the idle hand (presses nothing but the rival choice: the round must still end, by the rival); reports won.


func _init() -> void:
	rung = 0
	hand_profile = "idle"
