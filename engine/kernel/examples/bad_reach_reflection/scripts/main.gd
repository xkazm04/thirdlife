extends Node
## N4 hole: a method or property named in a string is invisible to a text check, so the fenced name never appears.
## Every line from "FENCE BEGIN" to "FENCE END" holds exactly one pattern that lint must now report with its line.

var target: Object
var holder: Node
var code: Object


func _pack_setup(_ctx) -> void:
	pass


func _pack_start() -> void:
	pass


func reach() -> void:
# FENCE BEGIN
	var a = target.call("get_name")
	var b = target.callv("get_name", [])
	target.call_deferred("free")
	holder.propagate_call("queue_free")
	var e = Callable(target, "get_name")
	target.set("script", null)
	target.set_deferred("script", null)
	holder.set_script(null)
	holder.script = null
	code.source_code = "extends Node"
	code.reload()
	var l = instance_from_id(1)
# FENCE END
	var same = holder.script == null
