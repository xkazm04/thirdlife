extends "res://kernel/world/build/stub_layer.gd"
## SEAM M5 stub of the `plants` layer (lane L fills this file): the op `plant`, the growth of 3 m land cells
## (contracts/BUILD.md "Milestone 5": meadow, flowers, tall_grass, or valley for the ground's own growth), saved as
## tl.build/3 `plants` and drawn by the ground's shader. Trees and bushes are `put` ops of the pieces layer (the
## scatter brush, plant_scatter.gd). The stub checks plant strictly (keys, cells [i, j, "<from>", "<to>"] with growth
## names, no cell twice) and refuses to apply it with "not built yet: plants"; it saves nothing and offers nothing.
## Interface: BUILD.md "Layers"; the lane's files are LANES.md.

const KEYS := ["v", "op", "cells", "author", "batch"]
const ORDER := ["v", "op", "cells"]
const GROWTHS := ["meadow", "flowers", "tall_grass", "valley"]


func _init(c: Dictionary) -> void:
	super(c)
	id = "plants"
	what = "plants"
	keys_saved = ["plants"]


func ops() -> PackedStringArray:
	return PackedStringArray(["plant"])


func malformed(op: Variant, strict := false) -> String:
	var why := OpUtil.head(op, KEYS)
	if why != "":
		return why
	var d: Dictionary = op
	if str(d.get("op")) != "plant":
		return "op must be \"plant\""
	why = cells_error(d.get("cells"), 4, _growth_error)
	if why != "":
		return why
	return OpUtil.tail(d, strict)


func _growth_error(e: Array) -> String:
	for g: Variant in [e[2], e[3]]:
		if typeof(g) != TYPE_STRING or not (str(g) in GROWTHS):
			return "cells: '%s' is not a growth" % str(g)
	return ""


func raw(op: Dictionary) -> Dictionary:
	var rec := OpUtil.ordered(op, ORDER)
	rec["v"] = 1
	return OpUtil.ordered(rec, ORDER)


## The cells set back: each entry's from and to swapped.
func invert(rec: Dictionary) -> Dictionary:
	var out := OpUtil.ordered(rec, ORDER)
	out["cells"] = (rec.cells as Array).map(func(e: Array) -> Array: return [e[0], e[1], e[3], e[2]])
	return out
