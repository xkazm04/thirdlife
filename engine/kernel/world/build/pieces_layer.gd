extends RefCounted
## SEAM stub of the `pieces` layer (spark world-sandbox M3 fills it): the ops `put` and `lift` of a kit part anchored at
## a cell (contracts/BUILD.md "More operations"). The stub checks both ops strictly against the contract (keys, the
## cell and its y range, the part and its params by TLKit.validate, rot 0-3, seed an integer) and refuses to apply them
## with the reason NOT_YET; it saves nothing and loads only an absent or empty `pieces`. M3 replaces the bodies of this
## file (and adds files of its own); the interface is BUILD.md "Layers", the lane's files are LANES.md.

const OpUtil := preload("res://kernel/world/build/op_util.gd")
const NOT_YET := "not built yet (M3)"
const KEYS := ["v", "op", "at", "part", "params", "rot", "seed", "author", "batch"]
const ORDER := ["v", "op", "at", "part", "params", "rot", "seed"]
const Y_MIN := -16
const Y_MAX := 111

var id := "pieces"
var ctx: Dictionary


## `ctx`: home_build.gd's context (BUILD.md "Layers": blocks, protect, space, root, seed, home).
func _init(c: Dictionary) -> void:
	ctx = c


func ops() -> PackedStringArray:
	return PackedStringArray(["put", "lift"])


## Not strict (an op handed to `apply`): v, author and batch may be left out; a put may leave out its seed (the layer
## gives it one); a lift may leave out what it lifts (part, params, rot, seed), as a remove may.
func malformed(op: Variant, strict := false) -> String:
	var why := OpUtil.head(op, KEYS)
	if why != "":
		return why
	var d: Dictionary = op
	var put: bool = d.op == "put"
	why = OpUtil.cell_error(d.get("at"))
	if why != "":
		return why
	if int(d.at[1]) < Y_MIN or int(d.at[1]) > Y_MAX:
		return "out of range (y %d..%d)" % [Y_MIN, Y_MAX]
	if not d.has("part"):
		if put or strict:
			return "part is missing"
	elif typeof(d.part) != TYPE_STRING or str(d.part).is_empty():
		return "part must be a kit part's kind"
	if d.has("params"):
		if typeof(d.params) != TYPE_DICTIONARY:
			return "params must be an object"
		if (d.params as Dictionary).is_empty():
			return "params are written only when not all defaults"
		for k: Variant in d.params:
			if str(k).begins_with("_"):
				return "params: '%s' is not a param" % str(k)
	if d.has("part"):
		var bad: PackedStringArray = TLKit.validate(str(d.part), d.get("params", {}))
		if not bad.is_empty():
			return bad[0]
	if d.has("rot") and (OpUtil.int_of(d.rot) == null or int(d.rot) < 0 or int(d.rot) > 3):
		return "rot must be 0..3"
	if not d.has("rot") and (put or strict):
		return "rot is missing"
	if d.has("seed") and OpUtil.int_of(d.seed) == null:
		return "seed must be an integer"
	if not d.has("seed") and strict:
		return "seed is missing"
	return OpUtil.tail(d, strict)


func can_apply(_op: Dictionary) -> String:
	return NOT_YET


func fits(_rec: Dictionary) -> String:
	return NOT_YET


func raw(op: Dictionary) -> Dictionary:
	var rec := OpUtil.ordered(op, ORDER)
	rec["v"] = 1
	return OpUtil.ordered(rec, ORDER)


func apply(_rec: Dictionary) -> void:
	pass


func invert(rec: Dictionary) -> Dictionary:
	var out := OpUtil.ordered(rec, ORDER)
	out["op"] = "lift" if rec.op == "put" else "put"
	return out


## World boxes the op changes. The stub knows no footprint: the anchor cell (M3: the part's turned bounds).
func dirty_regions(rec: Dictionary) -> Array:
	return [AABB(Vector3(OpUtil.cell(rec.at)), Vector3.ONE)]


# ------------------------------------------------------------------ files (tl.build/2 `pieces`)
func save_part() -> Dictionary:
	return {}


func load_part(doc: Dictionary) -> String:
	if not doc.has("pieces"):
		return ""
	if typeof(doc.pieces) != TYPE_ARRAY:
		return "pieces must be a list"
	return "" if (doc.pieces as Array).is_empty() else "pieces: " + NOT_YET


func clear() -> void:
	pass


func size() -> int:
	return 0


func content_hash() -> String:
	return ""


# ------------------------------------------------------------------ drawing, copies, reads
func step(_budget: int) -> int:
	return 0


func pending() -> int:
	return 0


func copy() -> RefCounted:
	return (get_script() as GDScript).new(ctx)


## M3 adds the pieces of the box here (M4's ask reads them).
func read_region(_lo: Vector3i, _hi: Vector3i) -> Dictionary:
	return {}


func free_all() -> void:
	pass
