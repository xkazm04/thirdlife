extends "res://kernel/world/build/tools/stub_tool.gd"
## SEAM stub of build mode's sculpt tool (M2 fills this file: raise, lower and smooth the ground on the 3 m lattice, as land ops). Until then it does nothing and the hotbar
## says "Sculpt: coming in M2". The tool interface is BUILD.md "Tools"; the lane's files are LANES.md.


func _init() -> void:
	id = "sculpt"
	title = "Sculpt"
	milestone = "M2"
