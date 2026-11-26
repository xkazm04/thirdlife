extends RefCounted
## SEAM M5 (spark world-sandbox): what a layer of the edit log that is not built yet does (BUILD.md "Layers"). It owns
## its op kinds (`ops`), checks them strictly against the contract (its file's `malformed`), and refuses to apply every
## one with the reason `NOT_YET + what` ("not built yet: water"). It offers no op to the LLM (`offers` is []), saves no
## key, reads only an absent or empty key of its own, draws no ghost, and expands no input op. The M5 stubs
## (water_layer.gd, paths_layer.gd, plants_layer.gd) extend this; a lane replaces its stub's file with the real layer
## and drops the extends (LANES.md), as tools/stub_tool.gd is for tools.

const OpUtil := preload("res://kernel/world/build/op_util.gd")
const NOT_YET := "not built yet: "

var id := "stub"
var what := "stub"                       # the word in the refusal: "not built yet: <what>"
var keys_saved: Array = []               # its keys of tl.build/3 (load_part refuses content in them)
var ctx: Dictionary


## `ctx`: home_build.gd's context (BUILD.md "Layers": blocks, mesh, check, protect, space, root, seed, home).
func _init(c: Dictionary) -> void:
	ctx = c


func ops() -> PackedStringArray:
	return PackedStringArray()


## The op kinds the Home takes from the LLM through this layer now: none while it is a stub.
func offers() -> Array:
	return []


func not_yet() -> String:
	return NOT_YET + what


func can_apply(_op: Dictionary) -> String:
	return not_yet()


func fits(_rec: Dictionary) -> String:
	return not_yet()


func apply(_rec: Dictionary) -> void:
	pass


func dirty_regions(_rec: Dictionary) -> Array:
	return []


# ------------------------------------------------------------------ files
func save_part() -> Dictionary:
	return {}


func load_part(doc: Dictionary) -> String:
	for k: String in keys_saved:
		if not doc.has(k):
			continue
		var v: Variant = doc[k]
		if typeof(v) != TYPE_DICTIONARY and typeof(v) != TYPE_ARRAY:
			return "%s must be an object or a list" % k
		if not v.is_empty():
			return "%s: %s" % [k, not_yet()]
	return ""


func clear() -> void:
	pass


func size() -> int:
	return 0


func content_hash() -> String:
	return ""


# ------------------------------------------------------------------ drawing, copies, reads, input
func step(_budget: int) -> int:
	return 0


func pending() -> int:
	return 0


func copy() -> RefCounted:
	return (get_script() as GDScript).new(ctx)


func read_region(_lo: Vector3i, _hi: Vector3i) -> Dictionary:
	return {}


## The ghost of this layer's part of a dry run (home_build.gd `preview_nodes`): a stub has none.
func preview_node(_scratch: Variant) -> Node3D:
	return null


func free_all() -> void:
	pass


# ------------------------------------------------------------------ what the stubs' checks share
## "" when `list` is a non-empty list of at most `most` entries, else the reason naming `key`.
static func list_error(list: Variant, key: String, most: int) -> String:
	if typeof(list) != TYPE_ARRAY or (list as Array).is_empty():
		return "%s must be a non-empty list" % key
	if (list as Array).size() > most:
		return "%s: at most %d entries" % [key, most]
	return ""


## The well-formed `cells` of a 3 m cell op: each entry `[i, j, ...rest]` with integer i and j within `IJ_MAX` and the
## rest checked by `rest` ((entry) -> "" or why); no cell named twice. "" or the reason.
static func cells_error(list: Variant, n: int, rest: Callable, most := 4096) -> String:
	var why := list_error(list, "cells", most)
	if why != "":
		return why
	var seen := {}
	for e: Variant in list:
		if typeof(e) != TYPE_ARRAY or (e as Array).size() != n:
			return "cells: every entry has %d values" % n
		if OpUtil.int_of(e[0]) == null or OpUtil.int_of(e[1]) == null:
			return "cells: i and j are integers"
		if absi(int(e[0])) > 100000 or absi(int(e[1])) > 100000:
			return "cells: [%d, %d] is outside the Home" % [int(e[0]), int(e[1])]
		var c := Vector2i(int(e[0]), int(e[1]))
		if seen.has(c):
			return "cells: [%d, %d] is named twice" % [c.x, c.y]
		seen[c] = true
		why = str(rest.call(e))
		if why != "":
			return why
	return ""
