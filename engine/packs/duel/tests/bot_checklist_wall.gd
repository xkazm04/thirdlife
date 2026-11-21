extends "support/pilot.gd"
## Plays-twice items 9 and 11 and the both-change rule over one match against the wall, regular hand: the rival never idle
## more than 120 frames, every rival wind-up at least 12 frames, no contact leaving a fighter unchanged.


func _init() -> void:
	rung = 0
	hand_profile = "regular"
	checklist = true
