extends RefCounted
## M3 (spark world-sandbox, 26 Nov 2026): the Home's pieces catalogue and the prototypes the pieces layer draws from.
## A piece is a kit part (TLKit) anchored at a cell (contracts/BUILD.md `put`). This file says, without state:
##   PARTS          the catalogue v1 in strip order (the scout's town ranking plus the two town parts bench, street_lamp)
##   KNOBS          the one number per part a person turns with [ and ] (fence length, tree height ...), with its step
##   CHOICES        the one choice per part V cycles (fence style, tree species, bench back ...)
##   placement()    where the part's origin stands: the anchor cell's floor centre (a part that runs along +X from its
##                  origin, fence and stones, starts at the cell's -x edge), turned `rot` quarter turns about +y
##                  (the blocks' rule: rot 1 turns -z to -x), lifted onto the ground when the cell holds it
##   footprint()    the turned bounds in whole cells: every cell the part overlaps by more than TOL on each axis, from
##                  the anchor's y up. A thin part on a cell line takes the cell its centre is in
##   proto()        the part built once per kind and params (TLKit.build, keyed as TLKit._key_of): its meshes, its
##                  collision shapes and its bounds, cached for the process; the built node is freed
## A part with a `seed` param that the op's params do not name is built with seed default + (op seed mod VARIANTS):
## the op's seed picks one of four looks, so pieces of one kind share a few prototypes (one MultiMesh each).

const PARTS := ["fence", "tree", "bush", "rock", "crate", "lumber", "pallet", "sign", "flag", "stones", "bench",
	"street_lamp", "cabin", "house", "timber_frame", "watch_tower", "light_mast"]
const ALONG_X := ["fence", "stones"]
const VARIANTS := 4
const TOL := 0.1                        # metres a part must reach into a cell for the cell to be in its footprint
const MAX_SIDE := 32                    # cells a footprint may span horizontally (the layer's neighbour search reach)
const KNOBS := {"fence": ["length", 1.0, 2.0, 16.0, "m"], "tree": ["height", 1.0, 4.0, 16.0, "m"],
	"bush": ["size", 0.25, 0.5, 2.0, "m"], "rock": ["size", 0.25, 0.5, 3.0, "m"], "crate": ["size", 0.25, 0.5, 2.0, "m"],
	"lumber": ["length", 0.5, 2.0, 6.0, "m"], "pallet": ["rows", 1, 1, 6, ""], "flag": ["height", 1.0, 3.0, 12.0, "m"],
	"stones": ["count", 1, 1, 12, ""], "bench": ["length", 0.2, 1.2, 3.0, "m"], "street_lamp": ["height", 0.2, 3.0, 6.0, "m"],
	"house": ["width", 1.0, 6.0, 12.0, "m"], "timber_frame": ["width", 1.0, 4.0, 12.0, "m"],
	"watch_tower": ["height", 1.0, 5.0, 14.0, "m"], "light_mast": ["height", 2.0, 6.0, 20.0, "m"]}
const CHOICES := {"fence": ["style", ["rail", "mesh"]], "tree": ["species", ["pine", "broadleaf"]],
	"bench": ["back", [true, false]], "sign": ["color", ["sign", "flag_a", "flag_b"]], "flag": ["color", ["flag_a", "flag_b"]],
	"street_lamp": ["light", [true, false]], "house": ["lights", [true, false]]}

static var _cache := {}                 # build key -> proto Dictionary


## The params a part is built with: the op's params, and the seed param from the op's seed (see the file's head).
static func build_params(part: String, params: Dictionary, seed_: int) -> Dictionary:
	var p := params.duplicate(true)
	var table: Dictionary = TLKit.PARTS.get(part, ["", "", false, {}])[3]
	if table.has("seed") and not p.has("seed"):
		p["seed"] = int(table.seed[1]) + posmod(seed_, VARIANTS)
	return p


## The default of `param` of `part` (TLKit's table), or null.
static func default_of(part: String, param: String) -> Variant:
	var table: Dictionary = TLKit.PARTS.get(part, ["", "", false, {}])[3]
	return table[param][1] if table.has(param) else null


## `params` in their table's types (an int param from JSON arrives as a float: written back it would read "3.0"), keys
## sorted, every value equal to its default dropped (the contract: params are omitted when all defaults). The one form
## a piece's params are kept, saved and compared in.
static func trimmed(part: String, params: Dictionary) -> Dictionary:
	var table: Dictionary = TLKit.PARTS.get(part, ["", "", false, {}])[3]
	var out := {}
	var keys: Array = params.keys()
	keys.sort()
	for k: Variant in keys:
		var v: Variant = params[k]
		var row: Array = table.get(str(k), [])
		if not row.is_empty() and (v is float or v is int):
			v = int(v) if row[0] == "int" else (float(v) if row[0] == "float" else v)
		if row.is_empty() or typeof(v) != typeof(row[1]) or v != row[1]:
			out[str(k)] = v
	return out


## The transform of a part anchored at `at`, turned `rot`, lifted `lift` metres.
static func placement(part: String, at: Vector3i, rot: int, lift := 0.0) -> Transform3D:
	var b := Basis(Vector3.UP, float(rot) * PI * 0.5)
	var off := Vector3(-0.5, 0.0, 0.0) if ALONG_X.has(part) else Vector3.ZERO
	return Transform3D(b, Vector3(at.x + 0.5, at.y + lift, at.z + 0.5) + b * off)


## The footprint [lo, hi] (inclusive cells) of bounds `local` (the part's own space) placed by `xf` at anchor `at`.
static func footprint(local: AABB, xf: Transform3D, at: Vector3i) -> Array:
	var w: AABB = xf * local
	var lo := Vector3i.ZERO
	var hi := Vector3i.ZERO
	for ax: int in [0, 2]:
		var a := floori(w.position[ax] + TOL)
		var b := ceili(w.end[ax] - TOL) - 1
		if b < a:
			a = floori(w.get_center()[ax])
			b = a
		lo[ax] = a
		hi[ax] = b
	lo.y = at.y
	hi.y = maxi(at.y, ceili(w.end.y - TOL) - 1)
	return [lo, hi]


## The prototype of `part` built with `p` (build_params): {"key", "meshes": [[Mesh, Transform3D, shadows: bool]],
## "shapes": [[Shape3D, Transform3D]], "aabb" (its own space), "lights" (it has a light), "breakable" (fracturable),
## "tris"}. Cached for the process: the same kind and params give the same proto.
static func proto(part: String, p: Dictionary) -> Dictionary:
	var key: String = TLKit._key_of(part, p)
	if _cache.has(key):
		return _cache[key]
	var n: Node3D = TLKit.build(part, p)
	var out := {"key": key, "part": part, "params": p, "meshes": [], "shapes": [], "aabb": AABB(), "lights": false,
		"breakable": bool(TLKit.PARTS[part][2]), "tris": 0}
	if n == null:
		return out
	var box := [null]
	_walk(n, Transform3D.IDENTITY, out, box)
	out.aabb = box[0] if box[0] != null else AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)
	out.tris = TLKit.triangles(n)
	n.free()
	_cache[key] = out
	return out


static func _walk(n: Node, xf: Transform3D, out: Dictionary, box: Array) -> void:
	for c: Node in n.get_children():
		var cx := xf
		if c is Node3D:
			if not (c as Node3D).visible:
				continue                                   # a fracturable part's hidden Pieces
			cx = xf * (c as Node3D).transform
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var mi := c as MeshInstance3D
			(out.meshes as Array).append([mi.mesh, cx, mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF])
			_grow(box, cx * mi.mesh.get_aabb())
		elif c is CollisionShape3D and not (c as CollisionShape3D).disabled and (c as CollisionShape3D).shape != null:
			var sh: Shape3D = (c as CollisionShape3D).shape
			(out.shapes as Array).append([sh, cx])
			var dm: Mesh = sh.get_debug_mesh()
			if dm != null:
				_grow(box, cx * dm.get_aabb())
		elif c is Light3D:
			out.lights = true
		_walk(c, cx, out, box)


static func _grow(box: Array, a: AABB) -> void:
	box[0] = a if box[0] == null else (box[0] as AABB).merge(a)


## The text a person reads for a knob's value: "length 8 m".
static func knob_text(part: String, params: Dictionary) -> String:
	if not KNOBS.has(part):
		return ""
	var k: Array = KNOBS[part]
	var v: Variant = params.get(k[0], default_of(part, k[0]))
	return ("%s %s %s" % [k[0], str(snappedf(float(v), 0.01)) if v is float else str(v), k[4]]).strip_edges()


## `params` with the knob of `part` turned by `steps` (clamped to its range).
static func turn_knob(part: String, params: Dictionary, steps: int) -> Dictionary:
	if not KNOBS.has(part):
		return params
	var k: Array = KNOBS[part]
	var v: float = float(params.get(k[0], default_of(part, k[0])))
	var nv: float = clampf(snappedf(v + float(k[1]) * steps, float(k[1])), float(k[2]), float(k[3]))
	var out := params.duplicate()
	out[k[0]] = int(nv) if default_of(part, k[0]) is int else nv
	return trimmed(part, out)


## `params` with the choice of `part` moved to its next value.
static func next_choice(part: String, params: Dictionary) -> Dictionary:
	if not CHOICES.has(part):
		return params
	var c: Array = CHOICES[part]
	var values: Array = c[1]
	var now: Variant = params.get(c[0], default_of(part, c[0]))
	var i := values.find(now)
	var out := params.duplicate()
	out[c[0]] = values[(i + 1) % values.size()]
	return trimmed(part, out)
