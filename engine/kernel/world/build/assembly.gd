extends RefCounted
## M6 round 3, lane A6 (27 Nov 2026): assemblies, the big shapes (contracts/BUILD.md "Assemblies (M6, round 3)"). The
## research behind it (docs/research/sandbox/THESIS.md): a model fails at space, not at syntax; the GDMC winners placed
## hand-made templates by terrain rules; Townscaper lets the player set the large shapes and writes the small ones. So
## the model (or the hand's Shapes tool) says `{"op":"assemble","kind":"tower","at":[x,y,z],"size":[7,12,7],"rot":0,
## "mat":1,"trim":2,"opts":{"stairs":"outside","crenels":true}}` and this file writes the cells: `place` ops of the
## block grammar, the same for the same input (no randomness), walkable where the kind says so (assembly_kinds.gd).
## An assemble is input only: home_build.gd `expand_input` hands it to blocks_layer.gd `expand_input`, which calls
## `expand`; it is never journaled or saved. Blocks it would put in a protected or occupied cell are refused by the
## place ops themselves when the batch is previewed or applied ("left out with the place ops' reasons"); `left_out`
## lists them beforehand (the hand tool's ghost, the cases).
##   var e := Assembly.expand(op, func(x: int, z: int) -> int: return 0)   # {"ops": [place ops]} or {"error"}
## Conventions (the prompt teaches them): `at` is the low corner cell before the turn, its y the ground y there (the
## floor row of a tower or a house, the first step of a stair, sits in that cell, as the ask's ground says a block
## stands); `rot` turns the shape about the centre of the `at` cell: rot 1 takes local +x to world -z and local +z to
## world +x (a stair's rot 0 rises toward -z, 1 toward -x, 2 toward +z, 3 toward +x: shapes.gd). Static; no state.

const Blocks := preload("res://kernel/world/build/blocks.gd")
const OpUtil := preload("res://kernel/world/build/op_util.gd")
const Kinds := preload("res://kernel/world/build/assembly_kinds.gd")
const KINDS := ["wall", "tower", "house", "stair", "bridge", "platform"]
const KEYS := ["v", "op", "kind", "at", "size", "rot", "mat", "trim", "opts", "author", "batch"]
const OPTS := {"wall": ["door", "windows", "crenels"], "tower": ["door", "windows", "crenels", "stairs"], "house": ["windows"],
	"stair": [], "bridge": [], "platform": []}
const STAIRS := ["inside", "outside"]
const SIZE_MAX := 48
const WINDOWS_MIN := 2
const WINDOWS_MAX := 16
const TURNS := [Blocks.STAIR, Blocks.RAMP, Blocks.ROOF, Blocks.WINDOW]
## What each kind's size means and the least it takes (the Foreman's world_edit_assemble.ts holds the same words).
const SIZE_NOTES := {"wall": "[length, height, unused]", "tower": "[side, height, unused]", "house": "[width, height, depth]",
	"stair": "[width, steps, unused]", "bridge": "[width, unused, length]", "platform": "[width, unused, depth]"}


## Why `op` is not a well-formed assemble ("" = it is): the contract's keys and ranges, each kind's opts, and the least
## size a kind needs to be what it says (a tower's door and top floor, inside stairs that leave headroom).
static func malformed(op: Variant) -> String:
	var why := OpUtil.head(op, KEYS)
	if why != "":
		return why
	var d: Dictionary = op
	if typeof(d.get("op")) != TYPE_STRING or str(d.op) != "assemble":
		return "op must be \"assemble\""
	for k: String in ["kind", "at", "size", "rot", "mat"]:
		if not d.has(k):
			return "%s is missing" % k
	if typeof(d.kind) != TYPE_STRING or not KINDS.has(str(d.kind)):
		return "unknown kind '%s': one of %s" % [str(d.kind), ", ".join(PackedStringArray(KINDS))]
	why = OpUtil.cell_error(d.at)
	if why != "":
		return why
	if typeof(d.size) != TYPE_ARRAY or (d.size as Array).size() != 3 or not (d.size as Array).all(func(v: Variant) -> bool:
			return OpUtil.int_of(v) != null and int(v) >= 1 and int(v) <= SIZE_MAX):
		return "size must be [w, h, d] of whole cells, each 1-%d (%s: %s)" % [SIZE_MAX, d.kind, SIZE_NOTES[d.kind]]
	if OpUtil.int_of(d.rot) == null or int(d.rot) < 0 or int(d.rot) > 3:
		return "rot must be 0..3"
	for k: String in ["mat", "trim"]:
		if d.has(k):
			why = mat_error(d[k], k)
			if why != "":
				return why
	var opts: Dictionary = {}
	if d.has("opts"):
		if typeof(d.opts) != TYPE_DICTIONARY:
			return "opts must be an object"
		opts = d.opts
		if opts.is_empty():
			return "opts is written only when it holds an option (leave it out)"
	why = opts_error(str(d.kind), opts, int(d.size[0]))
	if why != "":
		return why
	why = size_error(str(d.kind), int(d.size[0]), int(d.size[1]), int(d.size[2]), opts)
	if why != "":
		return why
	return OpUtil.tail(d, false)


static func mat_error(v: Variant, key: String) -> String:
	if OpUtil.int_of(v) == null:
		return "%s must be an integer" % key
	if int(v) == Blocks.GLASS:
		return "%s 10 (glass) is only a window's pane" % key
	if int(v) < 1 or int(v) > Blocks.MAT_MAX:
		return "unknown %s %d" % [key, int(v)]
	return ""


static func opts_error(kind: String, opts: Dictionary, w: int) -> String:
	for k: Variant in opts:
		if not (OPTS[kind] as Array).has(k):
			if (OPTS[kind] as Array).is_empty():
				return "a %s takes no opts" % kind
			return "a %s takes no opt '%s' (only %s)" % [kind, str(k), ", ".join(PackedStringArray(OPTS[kind]))]
	if opts.has("door"):
		var lo := 1 if kind == "tower" else 0
		var hi := w - 2 if kind == "tower" else w - 1
		if OpUtil.int_of(opts.door) == null or int(opts.door) < lo or int(opts.door) > hi:
			return "opts.door is the door's cell along the %s's front, %d..%d" % [kind, lo, hi]
	if opts.has("windows") and kind == "house":            # round 4 (Q-A8): a house's windows are a count on its front
		if OpUtil.int_of(opts.windows) == null or int(opts.windows) < 0 or int(opts.windows) > house_windows_max(w):
			return "opts.windows is how many windows on the house's front beside the door, 0..%d for %d wide" % [house_windows_max(w), w]
	elif opts.has("windows") and (OpUtil.int_of(opts.windows) == null or int(opts.windows) < WINDOWS_MIN or int(opts.windows) > WINDOWS_MAX):
		return "opts.windows is a window every N cells, N %d..%d" % [WINDOWS_MIN, WINDOWS_MAX]
	if opts.has("crenels") and (typeof(opts.crenels) != TYPE_BOOL or not bool(opts.crenels)):
		return "opts.crenels is written only when true"
	if opts.has("stairs") and (typeof(opts.stairs) != TYPE_STRING or not STAIRS.has(str(opts.stairs))):
		return "opts.stairs is \"inside\" or \"outside\""
	return ""


## The most front windows a house `w` wide takes: every front cell but the corners and the door (0 under 3 wide).
static func house_windows_max(w: int) -> int:
	return maxi(0, w - 3)


## The least size a kind needs (beyond 1-48): "" when `w`, `h`, `d` make the shape it says.
static func size_error(kind: String, w: int, h: int, d: int, opts: Dictionary) -> String:
	match kind:
		"wall":
			if opts.has("door") and h < 3:
				return "a wall with a door is at least 3 high (a sill, then a 2-cell opening)"
			if opts.has("windows") and h < 2:
				return "a wall with windows is at least 2 high"
		"tower":
			if w < 3:
				return "a tower is at least 3 wide (walls round a hollow)"
			if h < 4:
				return "a tower is at least 4 high (a floor, a 2-cell door, a top)"
			if str(opts.get("stairs", "")) == "inside" and w < 5:
				return "a tower with inside stairs is at least 5 wide (stairs round a 1-cell well)"
		"house":
			if w < 3 or d < 3:
				return "a house is at least 3 x 3"
			if h < 3:
				return "a house is at least 3 high (a floor and a 2-cell door)"
	return ""


## The place ops of `op` in the order they are built: {"ops": [{"op": "place", "at", "shape", "mat", "rot"}, ...]} or
## {"error"}. `ground`: (x: int, z: int) -> int, the ground cell of world column (x, z) (the cell a block standing
## there takes: command_ask.gd `cells_of`); an invalid Callable is flat ground at `at`'s y. Piers, posts and a bridge's
## end steps reach down to it.
static func expand(op: Variant, ground: Callable = Callable()) -> Dictionary:
	var why := malformed(op)
	if why != "":
		return {"error": why}
	var s := Shape.new(op, ground)
	Kinds.build(s)
	return {"ops": s.ops()}


## The cells of `ops` (place ops) a build would refuse now, with the reason: [[Vector3i, reason], ...] in op order
## (home_build.gd `can_place`: occupied, out of range, the caps, protection).
static func left_out(ops: Array, build: RefCounted) -> Array:
	var out := []
	for o: Dictionary in ops:
		var c := Vector3i(int(o.at[0]), int(o.at[1]), int(o.at[2]))
		var why: String = build.can_place(c, Blocks.code(int(o.shape), int(o.mat), int(o.rot)))
		if why != "":
			out.append([c, why])
	return out


## The world cell of local cell `l` of a shape at `at` turned `rot` (about the centre of the `at` cell).
static func turn(at: Vector3i, rot: int, l: Vector3i) -> Vector3i:
	return Shape.turned(at, rot, l)


## The local cell of world cell `c` (`turn` undone).
static func unturn(at: Vector3i, rot: int, c: Vector3i) -> Vector3i:
	var p := Vector2i(c.x - at.x, c.z - at.z)
	for i in rot:
		p = Vector2i(-p.y, p.x)
	return Vector3i(p.x, c.y - at.y, p.y)


## The ground of `build` (home_build.gd) as `expand` reads it: its land layer's height at a column's middle, as the
## cell a block standing there takes (command_ask.gd `heights` + `cells_of`); flat 0 without a land layer.
static func ground_of(build: RefCounted) -> Callable:
	var land: RefCounted = build.layer("land") if build != null else null
	if land == null or not land.has_method("height_at"):
		return func(_x: int, _z: int) -> int: return 0
	return func(x: int, z: int) -> int: return floori(float(land.call("height_at", x + 0.5, z + 0.5)) + 0.01)


## A shape being written: its cells in local coordinates (x along the front, z away from it, y up from `at`), turned
## to the world only when the ops are written.
class Shape:
	var kind := ""
	var at := Vector3i.ZERO
	var w := 1
	var h := 1
	var d := 1
	var rot := 0
	var mat := 1
	var trim := 1
	var opts := {}
	var ground: Callable
	var cells := {}                     # Vector3i local -> [shape, mat, local rot], in the order first put

	func _init(op: Dictionary, g: Callable) -> void:
		kind = str(op.kind)
		at = OpUtil.cell(op.at)
		w = int(op.size[0])
		h = int(op.size[1])
		d = int(op.size[2])
		rot = int(op.rot)
		mat = int(op.mat)
		trim = int(op.get("trim", op.mat))
		opts = op.get("opts", {})
		ground = g

	static func turned(a: Vector3i, r: int, l: Vector3i) -> Vector3i:
		var p := Vector2i(l.x, l.z)
		for i in r:
			p = Vector2i(p.y, -p.x)
		return Vector3i(a.x + p.x, a.y + l.y, a.z + p.y)

	func put(x: int, y: int, z: int, shape: int, m: int, lrot := 0) -> void:
		cells[Vector3i(x, y, z)] = [shape, m, lrot]

	func cut(x: int, y: int, z: int) -> void:
		cells.erase(Vector3i(x, y, z))

	func has(x: int, y: int, z: int) -> bool:
		return cells.has(Vector3i(x, y, z))

	## The ground cell under local column (x, z), in local y (0: the ground is in `at`'s cell).
	func gnd(x: int, z: int) -> int:
		if not ground.is_valid():
			return 0
		var c := turned(at, rot, Vector3i(x, 0, z))
		return int(ground.call(c.x, c.z)) - at.y

	func ops() -> Array:
		var out := []
		for l: Vector3i in cells:
			var v: Array = cells[l]
			var c := turned(at, rot, l)
			var r := (int(v[2]) + rot) % 4 if TURNS.has(int(v[0])) else 0
			out.append({"op": "place", "at": [c.x, c.y, c.z], "shape": int(v[0]), "mat": int(v[1]), "rot": r})
		return out
