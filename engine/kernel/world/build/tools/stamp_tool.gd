extends "res://kernel/world/build/tools/stub_tool.gd"
## SEAM stub of build mode's stamp tool (M3 fills this file: a tl.stamp/1 placed as one batch of place and put ops). Until then it does nothing and the hotbar
## says "Stamps: coming in M3". The tool interface is BUILD.md "Tools"; the lane's files are LANES.md.


func _init() -> void:
	id = "stamp"
	title = "Stamps"
	milestone = "M3"
