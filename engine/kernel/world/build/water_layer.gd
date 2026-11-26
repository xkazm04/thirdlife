extends "res://kernel/world/build/stub_layer.gd"
## SEAM M5 stub of the `water` layer (lane W fills this file): the ops `flood` and `drain` of still water over 3 m land
## cells (contracts/BUILD.md "Milestone 5"), saved as tl.build/3 `water`, and the input-only op `pour` (an LLM answer's
## "fill from this cell", expanded by `expand_input` into one flood op). The stub checks flood and drain strictly
## (keys, cells [i, j, level_cm] of integers, no cell twice) and refuses to apply them with "not built yet: water"; it
## saves nothing, offers nothing, measures no water (`water_runs` []) and expands no pour. Interface: BUILD.md
## "Layers" (offers, preview_node, expand_input, water_runs are the M5 additions); the lane's files are LANES.md.

const KEYS := ["v", "op", "cells", "author", "batch"]
const ORDER := ["v", "op", "cells"]
const CM_MAX := 100000                   # |level| in cm


func _init(c: Dictionary) -> void:
	super(c)
	id = "water"
	what = "water"
	keys_saved = ["water"]


func ops() -> PackedStringArray:
	return PackedStringArray(["flood", "drain"])


## Not strict (an op handed to `apply`): v, author and batch may be left out.
func malformed(op: Variant, strict := false) -> String:
	var why := OpUtil.head(op, KEYS)
	if why != "":
		return why
	var d: Dictionary = op
	if not (str(d.get("op")) in ["flood", "drain"]):
		return "op must be \"flood\" or \"drain\""
	why = cells_error(d.get("cells"), 3, _level_error, 2048)
	if why != "":
		return why
	return OpUtil.tail(d, strict)


func _level_error(e: Array) -> String:
	if OpUtil.int_of(e[2]) == null:
		return "cells: a level is integer cm"
	return "cells: a level is within %d cm" % CM_MAX if absi(int(e[2])) > CM_MAX else ""


func raw(op: Dictionary) -> Dictionary:
	var rec := OpUtil.ordered(op, ORDER)
	rec["v"] = 1
	return OpUtil.ordered(rec, ORDER)


func invert(rec: Dictionary) -> Dictionary:
	var out := OpUtil.ordered(rec, ORDER)
	out["op"] = "drain" if rec.op == "flood" else "flood"
	return out


## An input op (`pour`) as the ops it stands for: {"ops": [flood op]} or {"error"} (home_build.gd `expand_input`).
func expand_input(_op: Dictionary) -> Dictionary:
	return {"error": not_yet()}


## The water in the cell box `lo`..`hi`, shaped as the ask's `water` key: [{"y": <cell y of the surface>, "runs":
## [[z, x0, x1], ...]}, ...] (contracts/BUILD.md "The LLM command bar, M5 additions"). The stub measures none.
func water_runs(_lo: Vector3i, _hi: Vector3i) -> Array:
	return []
