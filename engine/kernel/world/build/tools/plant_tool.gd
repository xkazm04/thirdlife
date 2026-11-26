extends "res://kernel/world/build/tools/stub_tool.gd"
## SEAM M5 stub of build mode's plant tool. Lane L fills this file: paint meadow, flowers and tall grass on 3 m cells
## (plant ops) and scatter trees and bushes (put ops from plant_scatter.gd). Until then it does nothing and the hotbar
## says "Plants: coming in M5". The tool interface is BUILD.md "Tools"; the lane's files are LANES.md.


func _init() -> void:
	id = "plant"
	title = "Plants"
	milestone = "M5"


func hint() -> String:
	return "%s: not built yet   %s" % [title, KEY_HELP]
