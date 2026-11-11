extends Node
## N4 hole: the tree above ctx.root. `get_tree().root` was fenced; the same node by any other road was not.
## Every line from "FENCE BEGIN" to "FENCE END" holds exactly one pattern that lint must now report with its line.


var where: String = "Wheel"


func _pack_setup(_ctx) -> void:
	pass


func _pack_start() -> void:
	pass


func reach() -> void:
# FENCE BEGIN
	var a = get_tree()
	var b = get_node("/root")
	var c = get_node_or_null("/root/Host")
	var d = get_node("../..")
	var e = $"/root"
	var f = $/root
	var g = get_parent()
	var h = get_window()
	var i = get_viewport()
	var j = has_node(^"/root/Host")
	var k = get_node(where)
	var l = get_node("" + "/root")
# FENCE END
	var fine = get_node_or_null("Wheel/Spin")
