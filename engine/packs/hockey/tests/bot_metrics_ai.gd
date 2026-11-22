extends "bot_hockey.gd"
## N3 (22 Nov): the AI on all six skaters (autopilot: the brain plays b0 too), for the five bot metrics of the game
## itself (HOCKEY-ARCADE 5.5); red plays at the level set here, blue the plain data/ai.json. ok: played to the end.

var tapped: bool = false

func _init() -> void:
	level = "pro"
	hand_profile = "idle"
	require_win = false

func _bot_tick(frame: int) -> void:
	super(frame)
	if not tapped and str(s.get("state", "")) == "running" and str(s.get("level", "none")) == level and s.get("mode", "") == "base":
		ctx.input.tap(&"autopilot")
		tapped = true
