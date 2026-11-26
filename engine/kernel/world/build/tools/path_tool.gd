extends "res://kernel/world/build/tools/stub_tool.gd"
## SEAM M5 stub of build mode's path tool. Lane P fills this file: lay a path spline on the ground and grade it, as a
## path op and a land op in one batch. Until then it does nothing and the hotbar says "Paths: coming in M5". The tool
## interface is BUILD.md "Tools"; the lane's files are LANES.md.


func _init() -> void:
	id = "path"
	title = "Paths"
	milestone = "M5"


func hint() -> String:
	return "%s: not built yet   %s" % [title, KEY_HELP]
