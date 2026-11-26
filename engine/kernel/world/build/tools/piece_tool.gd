extends "res://kernel/world/build/tools/stub_tool.gd"
## SEAM stub of build mode's piece tool (M3 fills this file: kit parts put and lifted, as put and lift ops). Until then it does nothing and the hotbar
## says "Pieces: coming in M3". The tool interface is BUILD.md "Tools"; the lane's files are LANES.md.


func _init() -> void:
	id = "piece"
	title = "Pieces"
	milestone = "M3"
