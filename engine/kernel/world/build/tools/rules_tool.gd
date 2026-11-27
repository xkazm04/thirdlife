extends "res://kernel/world/build/tools/stub_tool.gd"
## SEAM M6 stub of build mode's Rules tool (after plants, before command in the strip). Lane T fills this file: the
## Rules hand tool with presets (start, checkpoint, finish, coin, door, jump pad, hazard, message), zones visible in
## build mode, the rules layer's ghost (`rules_layer.gd` `preview_node`), the rule list read with `describe`. Until then
## it does nothing and the hotbar says "Rules: coming in M6". The tool interface is BUILD.md "Tools"; the lanes'
## files are LANES.md "M6".


func _init() -> void:
	id = "rules"
	title = "Rules"
	milestone = "M6"


func hint() -> String:
	return "%s: not built yet   %s" % [title, KEY_HELP]
