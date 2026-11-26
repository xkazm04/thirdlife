extends "res://kernel/world/build/tools/stub_tool.gd"
## SEAM M5 stub of build mode's water tool. Lane W fills this file: LMB pours still water into a hollow, up to
## just under its spill level, as one flood op; RMB drains. Until then it does nothing and the hotbar says
## "Water: coming in M5". The tool interface is BUILD.md "Tools"; the lane's files are LANES.md.


func _init() -> void:
	id = "water"
	title = "Water"
	milestone = "M5"


func hint() -> String:
	return "%s: not built yet   %s" % [title, KEY_HELP]
