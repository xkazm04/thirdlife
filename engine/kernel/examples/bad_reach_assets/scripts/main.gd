extends Node
## N4 hole: lint read only scripts/, gen/, tests/ and examples/. This entry is clean; the script it loads from
## assets/ is not, and `ctx.load_script` loads any .gd of the pack. Lint must read assets/hidden.gd too.

var helper: Object


func _pack_setup(ctx) -> void:
	helper = ctx.load_script("assets/hidden.gd").new()


func _pack_start() -> void:
	pass
