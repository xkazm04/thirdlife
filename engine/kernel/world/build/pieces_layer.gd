extends RefCounted
## M3 (spark world-sandbox, 26 Nov 2026): the `pieces` layer of the edit log: `put` and `lift` of a kit part anchored at
## a cell (contracts/BUILD.md "More operations"; the layer interface is BUILD.md "Layers"; the working notes PIECES.md).
##   op checks     as the seam's stub: keys, the cell and its y range, the part and its params by TLKit.validate, rot
##                 0-3, seed an integer (`malformed`, unchanged)
##   a piece       the part's footprint (piece_catalog.gd `footprint`: its turned bounds in whole cells) is occupied:
##                 a put is refused when the footprint holds a block or another piece, passes y 111 or MAX_SIDE, lies
##                 on a game lot, an authored structure, a valley tree or the visitor; a block is refused in it (a
##                 "cell" rule) and land and paint under it (an "area" rule), both added in `add_rules`
##   standing      a piece whose anchor cell holds the ground stands on it (lifted to the ground's height there: the
##                 land layer's `height_at` when M2 gives one, else the Home's rendered ground, home/hook.gd `ground_y`)
##   records       one per anchor cell; params in their table's types, defaults left out (piece_catalog `trimmed`);
##                 a put that names no seed gets one from its cell and part, so the same op always gives the same piece
##   files         `pieces` of tl.build/2: [{at, part, params?, rot, seed}] sorted by at (z, then x, then y)
##   drawing       piece_draw.gd: MultiMeshes per prototype per 16 m section, bodies in the visitor's WorldSpace

const OpUtil := preload("res://kernel/world/build/op_util.gd")
const Catalog := preload("res://kernel/world/build/piece_catalog.gd")
const Draw := preload("res://kernel/world/build/piece_draw.gd")
const KEYS := ["v", "op", "at", "part", "params", "rot", "seed", "author", "batch"]
const ORDER := ["v", "op", "at", "part", "params", "rot", "seed"]
const SAVED := ["at", "part", "params", "rot", "seed"]
const Y_MIN := -16
const Y_MAX := 111
const SEC := 16
const GROUND_TAGS := ["terrain", "home ground", "home blocks", "home pieces"]

var id := "pieces"
var ctx: Dictionary
var scratch := false                    # a copy for a dry run: no drawing, no bodies, no rules of its own
var pieces := {}                        # anchor Vector3i -> record (see `_record`)
var cells := {}                         # every footprint cell -> its anchor
var by_sec := {}                        # section Vector2i -> {anchor: true}
var dirty := {}                         # sections to redraw
var draw: RefCounted = null             # piece_draw.gd (null: a scratch copy)
var _box := BoxShape3D.new()
var _q := PhysicsShapeQueryParameters3D.new()


## `ctx`: home_build.gd's context (BUILD.md "Layers": blocks, protect, space, root, seed, home).
func _init(c: Dictionary, as_scratch := false) -> void:
	ctx = c
	scratch = as_scratch
	if not scratch:
		draw = Draw.new(ctx.get("root"), ctx.get("space"))
	_q.shape = _box
	_q.collision_mask = 1
	_q.collide_with_areas = false


func ops() -> PackedStringArray:
	return PackedStringArray(["put", "lift"])


## The op kinds the LLM may write for this layer (command_ask.gd `ops_now`, BUILD.md "Layers"): put, lift.
func offers() -> Array:
	return ["put", "lift"]


func add_rules(protect: RefCounted) -> void:
	protect.add_rule(Callable(self, "_cell_rule"), "cell")
	protect.add_rule(Callable(self, "_area_rule"), "area")


# ------------------------------------------------------------------ op checks (the seam's, unchanged)
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


# ------------------------------------------------------------------ records
## The seed a put that names none gets: from its cell and part (the same op gives the same piece on every machine).
static func seed_for(at: Vector3i, part: String) -> int:
	var h := (at.x * 73856093) ^ (at.y * 19349663) ^ (at.z * 83492791) ^ part.hash()
	return posmod(h, 1000000)


## The record of a complete op (put or lift): its saved keys, the build params, the prototype, the placement and the
## footprint. `params` are trimmed (piece_catalog `trimmed`).
func _record(op: Dictionary) -> Dictionary:
	var at := OpUtil.cell(op.at)
	var part := str(op.part)
	var params: Dictionary = Catalog.trimmed(part, op.get("params", {}))
	var sd := int(op.seed)
	var bp: Dictionary = Catalog.build_params(part, params, sd)
	var pr: Dictionary = Catalog.proto(part, bp)
	var lift := _lift(at)
	var xf: Transform3D = Catalog.placement(part, at, int(op.rot), lift)
	var fp: Array = Catalog.footprint(pr.aabb, xf, at)
	return {"at": at, "part": part, "params": params, "rot": int(op.rot), "seed": sd, "bp": bp, "proto": pr, "xf": xf,
		"lift": lift, "lo": fp[0], "hi": fp[1]}


## The saved form of a record: {at, part, params?, rot, seed} (contract order).
static func saved(r: Dictionary) -> Dictionary:
	var out := {"at": [r.at.x, r.at.y, r.at.z], "part": r.part}
	if not (r.params as Dictionary).is_empty():
		out["params"] = (r.params as Dictionary).duplicate(true)
	out["rot"] = r.rot
	out["seed"] = r.seed
	return out


## Metres a piece anchored at `at` stands above the cell's floor: the ground's height there when it lies in the cell.
func _lift(at: Vector3i) -> float:
	var g := ground_y(at.x + 0.5, at.z + 0.5)
	if is_nan(g) or g < float(at.y) or g >= float(at.y) + 1.0:
		return 0.0
	return snappedf(g - float(at.y), 0.001)


## The ground's height at (x, z): M2's land layer (`height_at`) when it has one, else the Home's rendered ground
## (the landscape's meta tl_home, home/hook.gd `ground_y`), else NAN (a case without a landscape).
func ground_y(x: float, z: float) -> float:
	var home: Variant = (ctx.home as WeakRef).get_ref() if ctx.get("home") is WeakRef else null
	if home != null:
		var land: Variant = home.call("layer", "land")
		if land != null and (land as Object).has_method("height_at"):
			return float(land.call("height_at", x, z))
	var root: Node = ctx.get("root")
	var parent: Node = root.get_parent() if root != null and is_instance_valid(root) else null
	if parent != null and parent.has_meta(&"tl_home"):
		return float((parent.get_meta(&"tl_home") as Object).call("ground_y", x, z))
	return NAN


static func section_of(c: Vector3i) -> Vector2i:
	return Vector2i(floori(float(c.x) / SEC), floori(float(c.z) / SEC))


## The piece whose footprint holds `cell`, or {}.
func at_cell(cell: Vector3i) -> Dictionary:
	var a: Variant = cells.get(cell)
	return pieces[a] if a != null else {}


func _sections_of(r: Dictionary) -> Array:
	var out := []
	var a := section_of(r.lo)
	var b := section_of(r.hi)
	for sz in range(a.y, b.y + 1):
		for sx in range(a.x, b.x + 1):
			out.append(Vector2i(sx, sz))
	return out


# ------------------------------------------------------------------ the rules
## Why the rules refuse a well-formed op now.
func can_apply(op: Dictionary) -> String:
	if op.op == "lift":
		var at := OpUtil.cell(op.at)
		if not pieces.has(at):
			return "no piece there"
		var r: Dictionary = pieces[at]
		if op.has("part") and str(op.part) != r.part:
			return "the cell holds another piece (part)"
		for k: String in ["rot", "seed"]:
			if op.has(k) and int(op[k]) != int(r[k]):
				return "the cell holds another piece (%s)" % k
		if op.has("part") and Catalog.trimmed(r.part, op.get("params", {})) != r.params:
			return "the cell holds another piece (params)"
		return ""
	var full := op.duplicate()
	if not full.has("seed"):
		full["seed"] = seed_for(OpUtil.cell(op.at), str(op.part))
	return refusal(_record(full))


## Why the piece record `r` may not stand where it is ("" = it may): its size, the y range, blocks and pieces in its
## footprint, then protection (lots, boxes, the other layers' cell rules, the visitor, the visitor's space).
func refusal(r: Dictionary) -> String:
	var lo: Vector3i = r.lo
	var hi: Vector3i = r.hi
	if hi.x - lo.x + 1 > Catalog.MAX_SIDE or hi.z - lo.z + 1 > Catalog.MAX_SIDE:
		return "too large for a piece (at most %d m a side)" % Catalog.MAX_SIDE
	if hi.y > Y_MAX:
		return "out of range (y %d..%d)" % [Y_MIN, Y_MAX]
	var why := _occupied(r)
	if why != "":
		return why
	return _protected(r)


func _occupied(r: Dictionary) -> String:
	var store: RefCounted = ctx.get("blocks")
	var lo: Vector3i = r.lo
	var hi: Vector3i = r.hi
	for y in range(lo.y, hi.y + 1):
		for z in range(lo.z, hi.z + 1):
			for x in range(lo.x, hi.x + 1):
				var c := Vector3i(x, y, z)
				var a: Variant = cells.get(c)
				if a != null and a != r.at:
					return "occupied (%s)" % str(pieces[a].part).replace("_", " ")
				if store != null and int(store.get_code(c)) != 0:
					return "occupied (a block at %d, %d, %d)" % [x, y, z]
	return ""


## protect.gd's checks over the footprint: its circles and rectangles per column, its boxes, the other layers' "cell"
## rules on the bottom row, the visitor's capsule and ONE box query of the visitor's space (protect.gd asks one per
## cell; a house has some 900).
func _protected(r: Dictionary) -> String:
	var protect: RefCounted = ctx.get("protect")
	if protect == null:
		return ""
	var lo: Vector3i = r.lo
	var hi: Vector3i = r.hi
	for z in range(lo.z, hi.z + 1):
		for x in range(lo.x, hi.x + 1):
			var a := Vector2(x, z)
			var b := a + Vector2.ONE
			var mid := a + Vector2(0.5, 0.5)
			for c: Array in protect.circles:
				var p: Vector2 = (c[0] as Vector2).clamp(a, b)
				if p.distance_to(c[0]) <= float(c[1]):
					return c[2]
			for q: Array in protect.rects:
				var local := (mid - (q[0] as Vector2)).rotated(float(q[2]))
				var half: Vector2 = q[1]
				if absf(local.x) <= half.x + 0.71 and absf(local.y) <= half.y + 0.71:
					return q[3]
			for rule: Array in protect.rules:
				if rule[1] == "cell" and (rule[0] as Callable).is_valid() and (rule[0] as Callable).get_object() != self:
					var why := str((rule[0] as Callable).call(Vector3i(x, lo.y, z), 0))
					if why != "":
						return why
	var box := AABB(Vector3(lo) + Vector3.ONE * 0.01, Vector3(hi - lo + Vector3i.ONE) - Vector3.ONE * 0.02)
	for bx: Array in protect.boxes:
		if (bx[0] as AABB).intersects(box):
			return bx[1]
	var ws: Object = ctx.get("space")
	if ws == null:
		return ""
	var body: RID = ws.get("body")
	var feet_at: Callable = protect.visitor_at
	if body.is_valid() or feet_at.is_valid():
		var feet: Vector3 = feet_at.call() if feet_at.is_valid() else (PhysicsServer3D.body_get_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM) as Transform3D).origin
		var rad: float = float(ws.get("walker_radius")) + 0.05
		var capsule := AABB(feet - Vector3(rad, 0.05, rad), Vector3(2.0 * rad, float(ws.get("walker_height")) + 0.1, 2.0 * rad))
		if capsule.intersects(box):
			return "too close"
	var space: RID = ws.get("space")
	if not space.is_valid():
		return ""
	_box.size = box.size
	_q.transform = Transform3D(Basis.IDENTITY, box.get_center())
	_q.exclude = [body] if body.is_valid() else []
	var tags: Dictionary = ws.get("_tags")
	for hit: Dictionary in PhysicsServer3D.space_get_direct_state(space).intersect_shape(_q, 32):
		var tag := str(tags.get(hit.rid, ""))
		if tag == "home ground" and int(hit.shape) > 0:
			return "tree"
		if not GROUND_TAGS.has(tag) and not tag.begins_with("pad "):
			return "authored structure (%s)" % (tag if tag != "" else "untagged")
	return ""


## protect.gd "cell" rule: a block may not go into a piece's footprint.
func _cell_rule(cell: Vector3i, _code: int) -> String:
	var r := at_cell(cell)
	return "" if r.is_empty() else "piece (%s)" % str(r.part).replace("_", " ")


## protect.gd "area" rule: land and paint may not change the ground under a piece.
func _area_rule(rect: Rect2, _what: String) -> String:
	var a := Vector2i(floori(rect.position.x / SEC) - 2, floori(rect.position.y / SEC) - 2)
	var b := Vector2i(floori(rect.end.x / SEC), floori(rect.end.y / SEC))
	for sz in range(a.y, b.y + 1):
		for sx in range(a.x, b.x + 1):
			for at: Vector3i in by_sec.get(Vector2i(sx, sz), {}):
				var r: Dictionary = pieces[at]
				var fp := Rect2(r.lo.x, r.lo.z, r.hi.x - r.lo.x + 1, r.hi.z - r.lo.z + 1)
				if fp.intersects(rect):
					return "piece (%s)" % str(r.part).replace("_", " ")
	return ""


# ------------------------------------------------------------------ the log's calls
## The op as it is journaled: complete (a put gets its seed, a lift names what it lifts), keys in the contract's order.
func raw(op: Dictionary) -> Dictionary:
	var at := OpUtil.cell(op.at)
	var rec := {"v": 1, "op": op.op, "at": [at.x, at.y, at.z]}
	if op.op == "lift" and pieces.has(at):
		var have := saved(pieces[at])
		for k: String in ["part", "params", "rot", "seed"]:
			if have.has(k):
				rec[k] = have[k]
		return OpUtil.ordered(rec, ORDER)
	rec["part"] = str(op.part)
	var params: Dictionary = Catalog.trimmed(str(op.part), op.get("params", {}))
	if not params.is_empty():
		rec["params"] = params
	rec["rot"] = int(op.rot)
	rec["seed"] = int(op.seed) if op.has("seed") else seed_for(at, str(op.part))
	return OpUtil.ordered(rec, ORDER)


## Why a complete record does not fit (undo, redo, a journal replayed: no rules asked). "" = it fits.
func fits(rec: Dictionary) -> String:
	var at := OpUtil.cell(rec.at)
	if rec.op == "put":
		if pieces.has(at):
			return "cannot put at %s: a piece is there" % str(at)
		var why := _occupied(_record(rec))
		return "" if why == "" else "cannot put at %s: %s" % [str(at), why]
	if not pieces.has(at) or saved(pieces[at]) != _saved_of(rec):
		return "cannot lift at %s: it holds something else" % str(at)
	return ""


static func _saved_of(rec: Dictionary) -> Dictionary:
	var out := {"at": [int(rec.at[0]), int(rec.at[1]), int(rec.at[2])], "part": str(rec.part)}
	var params: Dictionary = Catalog.trimmed(str(rec.part), rec.get("params", {}))
	if not params.is_empty():
		out["params"] = params
	out["rot"] = int(rec.rot)
	out["seed"] = int(rec.seed)
	return out


func apply(rec: Dictionary) -> void:
	if rec.op == "put":
		_add(_record(rec))
	else:
		_take(OpUtil.cell(rec.at))


func _add(r: Dictionary) -> void:
	pieces[r.at] = r
	for y in range(r.lo.y, r.hi.y + 1):
		for z in range(r.lo.z, r.hi.z + 1):
			for x in range(r.lo.x, r.hi.x + 1):
				cells[Vector3i(x, y, z)] = r.at
	var s := section_of(r.at)
	if not by_sec.has(s):
		by_sec[s] = {}
	by_sec[s][r.at] = true
	dirty[s] = true


func _take(at: Vector3i) -> void:
	var r: Dictionary = pieces.get(at, {})
	if r.is_empty():
		return
	pieces.erase(at)
	for y in range(r.lo.y, r.hi.y + 1):
		for z in range(r.lo.z, r.hi.z + 1):
			for x in range(r.lo.x, r.hi.x + 1):
				if cells.get(Vector3i(x, y, z)) == at:
					cells.erase(Vector3i(x, y, z))
	var s := section_of(at)
	(by_sec[s] as Dictionary).erase(at)
	if (by_sec[s] as Dictionary).is_empty():
		by_sec.erase(s)
	dirty[s] = true


func invert(rec: Dictionary) -> Dictionary:
	var out := OpUtil.ordered(rec, ORDER)
	out["op"] = "lift" if rec.op == "put" else "put"
	return out


## The world box of the piece's footprint (a put's, or the lifted piece's).
func dirty_regions(rec: Dictionary) -> Array:
	var at := OpUtil.cell(rec.at)
	var r: Dictionary = pieces.get(at, {})
	if r.is_empty() and rec.has("part") and rec.has("rot") and rec.has("seed"):
		r = _record(rec)
	if r.is_empty():
		return [AABB(Vector3(at), Vector3.ONE)]
	return [AABB(Vector3(r.lo), Vector3(r.hi - r.lo + Vector3i.ONE))]


# ------------------------------------------------------------------ files (tl.build/2 `pieces`)
## The pieces in the contract's order: by at, z, then x, then y.
func sorted() -> Array:
	var keys: Array = pieces.keys()
	keys.sort_custom(func(p: Vector3i, q: Vector3i) -> bool:
		return p.z < q.z or (p.z == q.z and (p.x < q.x or (p.x == q.x and p.y < q.y))))
	return keys.map(func(k: Vector3i) -> Dictionary: return saved(pieces[k]))


func save_part() -> Dictionary:
	return {} if pieces.is_empty() else {"pieces": sorted()}


func load_part(doc: Dictionary) -> String:
	if not doc.has("pieces"):
		return ""
	if typeof(doc.pieces) != TYPE_ARRAY:
		return "pieces must be a list"
	for i: int in (doc.pieces as Array).size():
		var e: Variant = doc.pieces[i]
		if typeof(e) != TYPE_DICTIONARY:
			return "pieces[%d] is not an object" % i
		for k: Variant in e:
			if not SAVED.has(k):
				return "pieces[%d]: unknown key '%s'" % [i, str(k)]
		var op: Dictionary = (e as Dictionary).duplicate()
		op["op"] = "put"
		var why := malformed(op, false)
		if why == "" and not op.has("seed"):
			why = "seed is missing"
		if why == "":
			why = fits(op)
		if why != "":
			return "pieces[%d]: %s" % [i, why]
		apply(op)
	return ""


func clear() -> void:
	pieces.clear()
	cells.clear()
	for s: Vector2i in by_sec:
		dirty[s] = true
	by_sec.clear()


func size() -> int:
	return pieces.size()


## SHA-1 of the saved pieces ("" when there are none: a Home without pieces keeps M1's revs).
func content_hash() -> String:
	if pieces.is_empty():
		return ""
	return JSON.stringify(sorted(), "", false).sha1_text()


# ------------------------------------------------------------------ drawing, copies, reads
func step(budget: int) -> int:
	if draw == null:
		dirty.clear()
		return 0
	var ids: Array = dirty.keys()
	ids.sort()
	var n := 0
	for s: Vector2i in ids:
		if n >= budget:
			break
		dirty.erase(s)
		var recs := []
		var anchors: Array = (by_sec.get(s, {}) as Dictionary).keys()
		anchors.sort()
		for a: Vector3i in anchors:
			recs.append(pieces[a])
		draw.rebuild(s, recs)
		n += 1
	return n


func pending() -> int:
	return dirty.size() if draw != null else 0


## A scratch copy (a dry run): the same pieces and rules, no drawing, no bodies, no rules added to protect.
func copy() -> RefCounted:
	var c: RefCounted = (get_script() as GDScript).new(ctx, true)
	c.pieces = pieces.duplicate()
	c.cells = cells.duplicate()
	c.by_sec = by_sec.duplicate(true)
	return c


## The pieces anchored in the cell box `lo`..`hi` (inclusive), saved form, sorted by at (z, x, y); the key is left out
## when there are none (absent = omitted).
func read_region(lo: Vector3i, hi: Vector3i) -> Dictionary:
	var out := []
	for p: Dictionary in sorted():
		var a: Array = p.at
		if a[0] >= lo.x and a[0] <= hi.x and a[1] >= lo.y and a[1] <= hi.y and a[2] >= lo.z and a[2] <= hi.z:
			out.append(p)
	return {} if out.is_empty() else {"pieces": out}


## M5 (lane C): this layer's part of a dry run's ghost (home_build.gd `preview_nodes`, BUILD.md "Layers"): the pieces
## the dry run's scratch copy `s` holds and this layer does not, in holo, and those it would lift, in red (piece_ghost.gd:
## each prototype's meshes with the holo fill UV (0.5, 2), where the piece would stand); null when it puts and lifts
## nothing. The caller adds the node to the tree and frees it.
func preview_node(s: Variant) -> Node3D:
	if not (s is RefCounted) or not bool((s as RefCounted).get("scratch")):
		return null
	var after: Dictionary = (s as RefCounted).get("pieces")
	var added := []
	var gone := []
	for a: Vector3i in after:
		if not pieces.has(a) or not is_same(pieces[a], after[a]):
			added.append([after[a].proto, after[a].xf])
	for a: Vector3i in pieces:
		if not after.has(a) or not is_same(pieces[a], after[a]):
			gone.append([pieces[a].proto, pieces[a].xf])
	if added.is_empty() and gone.is_empty():
		return null
	var node := Node3D.new()
	node.name = "PiecesPreview"
	for part: Array in [[added, false, "Added"], [gone, true, "Removed"]]:
		if not (part[0] as Array).is_empty():
			var g: Node3D = (load("res://kernel/world/build/piece_ghost.gd") as GDScript).new()
			g.name = str(part[2])
			node.add_child(g)
			g.call("show_pieces", part[0], part[1])
	return node


## The footprint [lo, hi] a put of `op` would have (a tool's ghost, a stamp's box), or [] when it is not well-formed.
func footprint_of(op: Dictionary) -> Array:
	var full := op.duplicate()
	full["op"] = "put"
	if not full.has("seed"):
		full["seed"] = seed_for(OpUtil.cell(op.at), str(op.part))
	if malformed(full) != "":
		return []
	var r := _record(full)
	return [r.lo, r.hi, r.xf, r.proto]


func figures() -> Dictionary:
	var f: Dictionary = draw.figures() if draw != null else {}
	f["pieces"] = pieces.size()
	f["cells"] = cells.size()
	return f


func free_all() -> void:
	if draw != null:
		draw.free_all()
