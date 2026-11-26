extends "res://kernel/world/build/tools/stub_tool.gd"
## SEAM stub of build mode's paint tool (M2 fills this file: the ground material of 3 m cells, as paint ops). Until then it does nothing and the hotbar
## says "Paint: coming in M2". The tool interface is BUILD.md "Tools"; the lane's files are LANES.md.


func _init() -> void:
	id = "paint"
	title = "Paint"
	milestone = "M2"
