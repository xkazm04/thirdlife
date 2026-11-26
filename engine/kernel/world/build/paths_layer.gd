extends "res://kernel/world/build/stub_layer.gd"
## SEAM M5 stub of the `paths` layer (lane P fills this file): the ops `path` and `unpath` of splines draped on the
## ground (contracts/BUILD.md "Milestone 5"), saved as tl.build/3 `paths`. The stub checks both ops strictly (keys, id a
## positive integer, 2-64 points [x_cm, z_cm] of integers 100-4,800 cm apart, width_cm 150-800, a path paint) and
## refuses to apply them with "not built yet: paths"; it saves nothing and offers nothing. Grading is not part of the
## op: the path tool writes a land op in the same batch. Interface: BUILD.md "Layers"; the lane's files are LANES.md.

const KEYS := ["v", "op", "id", "pts", "width_cm", "paint", "author", "batch"]
const ORDER := ["v", "op", "id", "pts", "width_cm", "paint"]
const PAINTS := ["dirt", "sand", "stone", "rock_warm", "grass_dry", "plank"]
const PTS_MIN := 2
const PTS_MAX := 64
const GAP_MIN_CM := 100
const GAP_MAX_CM := 4800
const WIDTH_MIN_CM := 150
const WIDTH_MAX_CM := 800
const XZ_MAX_CM := 10000000              # |x|, |z| in cm (100 km)


func _init(c: Dictionary) -> void:
	super(c)
	id = "paths"
	what = "paths"
	keys_saved = ["paths"]


func ops() -> PackedStringArray:
	return PackedStringArray(["path", "unpath"])


## Every key is required on input too (an unpath carries the whole path it removes); v, author and batch may be left
## out when not strict.
func malformed(op: Variant, strict := false) -> String:
	var why := OpUtil.head(op, KEYS)
	if why != "":
		return why
	var d: Dictionary = op
	if not (str(d.get("op")) in ["path", "unpath"]):
		return "op must be \"path\" or \"unpath\""
	for k: String in ["id", "pts", "width_cm", "paint"]:
		if not d.has(k):
			return "%s is missing" % k
	if OpUtil.int_of(d.id) == null or int(d.id) < 1:
		return "id must be a positive integer"
	why = pts_error(d.pts)
	if why != "":
		return why
	if OpUtil.int_of(d.width_cm) == null or int(d.width_cm) < WIDTH_MIN_CM or int(d.width_cm) > WIDTH_MAX_CM:
		return "width_cm must be an integer %d..%d" % [WIDTH_MIN_CM, WIDTH_MAX_CM]
	if typeof(d.paint) != TYPE_STRING or not (str(d.paint) in PAINTS):
		return "paint must be one of %s" % ", ".join(PAINTS)
	return OpUtil.tail(d, strict)


## "" when `pts` is 2-64 points [x_cm, z_cm] of integers, consecutive points 100-4,800 cm apart.
static func pts_error(pts: Variant) -> String:
	if typeof(pts) != TYPE_ARRAY or (pts as Array).size() < PTS_MIN or (pts as Array).size() > PTS_MAX:
		return "pts must be %d-%d points" % [PTS_MIN, PTS_MAX]
	var last := Vector2.ZERO
	var first := true
	for p: Variant in pts:
		if typeof(p) != TYPE_ARRAY or (p as Array).size() != 2 or OpUtil.int_of(p[0]) == null or OpUtil.int_of(p[1]) == null:
			return "pts: every point is [x_cm, z_cm] of integers"
		if absi(int(p[0])) > XZ_MAX_CM or absi(int(p[1])) > XZ_MAX_CM:
			return "pts: [%d, %d] is outside the Home" % [int(p[0]), int(p[1])]
		var here := Vector2(int(p[0]), int(p[1]))
		if not first:
			var gap := here.distance_to(last)
			if gap < GAP_MIN_CM or gap > GAP_MAX_CM:
				return "pts: consecutive points are %d-%d cm apart (%d)" % [GAP_MIN_CM, GAP_MAX_CM, int(gap)]
		last = here
		first = false
	return ""


func raw(op: Dictionary) -> Dictionary:
	var rec := OpUtil.ordered(op, ORDER)
	rec["v"] = 1
	return OpUtil.ordered(rec, ORDER)


func invert(rec: Dictionary) -> Dictionary:
	var out := OpUtil.ordered(rec, ORDER)
	out["op"] = "unpath" if rec.op == "path" else "path"
	return out
