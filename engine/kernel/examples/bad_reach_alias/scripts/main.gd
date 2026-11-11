extends Node
## N4 hole: several fenced names were only matched with their dot or their bracket (`OS.`, `ClassDB.`, `get_tree()`).
## A singleton, a class or a method kept in a variable is the same door one line later.
## Every line from "FENCE BEGIN" to "FENCE END" holds exactly one pattern that lint must now report with its line.

var target: Object


func _pack_setup(_ctx) -> void:
	pass


func _pack_start() -> void:
	pass


func reach() -> void:
# FENCE BEGIN
	var a = OS
	var b = ProjectSettings
	var c = ClassDB
	var d = Engine
	var e = Time
	var f = Input
	var g = GDScript
	var h = get_tree
	var i = get_parent
	var j = target.call
	var k = target.set
	var l = target.set_script
# FENCE END
	var fine: GDScript = null
