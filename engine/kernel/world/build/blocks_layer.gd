extends RefCounted
## SEAM (spark world-sandbox): the `blocks` layer of the edit log: the ops `place` and `remove` of 1 m blocks
## (contracts/BUILD.md `tl.edit/1`), over the store (blocks.gd) and its mesher (block_mesh.gd). M1's behaviour, moved
## here from edit_log.gd and build_file.gd without a change: the same checks in the same order with the same reasons,
## the same journal lines, the same `chunks` records. The layer interface is in BUILD.md "Layers".

const Blocks := preload("res://kernel/world/build/blocks.gd")
const OpUtil := preload("res://kernel/world/build/op_util.gd")
const KEYS := ["v", "op", "at", "shape", "mat", "rot", "flip", "author", "batch"]
const ORDER := ["v", "op", "at", "shape", "mat", "rot", "flip"]
const BLOCK_KEYS := ["shape", "mat", "rot", "flip"]

var id := "blocks"
var store: RefCounted                   # blocks.gd
var mesh: RefCounted = null             # block_mesh.gd (null: a scratch copy, nothing drawn)
var check: Callable                     # (cell, code) -> reason: protect.gd `refusal`, set by the owner
var scratch := false                    # a preview's copy (`copy`): it remembers the cells its ops changed
var touched := {}                       # Vector3i -> true: those cells, in the order they were first changed


## `ctx`: "blocks" (the store), "mesh" (its mesher, optional), "check" (the protection callable, optional).
func _init(ctx: Dictionary) -> void:
	store = ctx.blocks
	mesh = ctx.get("mesh")
	check = ctx.get("check", Callable())


func ops() -> PackedStringArray:
	return PackedStringArray(["place", "remove"])


## The op kinds the LLM may write for this layer (command_ask.gd `ops_now`): always both.
func offers() -> Array:
	return ["place", "remove"]


# ------------------------------------------------------------------ ops
## Why `op` is not a well-formed place or remove ("" = it is). `strict`: as read from a journal (every required key).
## Not strict (an op handed to `apply`): v, author and batch may be left out, and a remove may leave out what it removes.
static func check_op(op: Variant, strict := false) -> String:
	var why := OpUtil.head(op, KEYS)
	if why != "":
		return why
	var d: Dictionary = op
	if not d.has("op") or not (str(d.op) in ["place", "remove"]) or typeof(d.op) != TYPE_STRING:
		return "op must be \"place\" or \"remove\""
	why = OpUtil.cell_error(d.get("at"))
	if why != "":
		return why
	var place: bool = d.op == "place"
	for k: String in ["shape", "mat", "rot"]:
		if d.has(k) and OpUtil.int_of(d[k]) == null:
			return "%s must be an integer" % k
		if not d.has(k) and (place or strict):
			return "%s is missing" % k
	if d.has("shape") and (int(d.shape) < 1 or int(d.shape) > 8):
		return "unknown shape %d" % int(d.shape)
	if d.has("mat") and (int(d.mat) < 1 or int(d.mat) > Blocks.MAT_MAX):
		return "unknown mat %d" % int(d.mat)
	if d.has("rot") and (int(d.rot) < 0 or int(d.rot) > 3):
		return "rot must be 0..3"
	if d.has("flip"):
		if typeof(d.flip) != TYPE_BOOL or not bool(d.flip):
			return "flip is written only when true"
		if d.has("shape") and not (int(d.shape) in [Blocks.STAIR, Blocks.RAMP, Blocks.ROOF]):
			return "flip is for stair, ramp and roof"
	if d.has("shape") and d.has("mat") and int(d.mat) == Blocks.GLASS:
		return "glass is only a window's pane (a window's frame takes another material)"
	return OpUtil.tail(d, strict)


static func code_of(op: Dictionary) -> int:
	return Blocks.code(int(op.shape), int(op.mat), int(op.rot), bool(op.get("flip", false)))


## The record of block `c` at `cell` (no author, no batch: the log adds them).
static func record(kind: String, cell: Vector3i, c: int) -> Dictionary:
	var rec := {"v": 1, "op": kind, "at": [cell.x, cell.y, cell.z], "shape": Blocks.shape_of(c), "mat": Blocks.mat_of(c),
		"rot": Blocks.rot_of(c)}
	if Blocks.flip_of(c):
		rec["flip"] = true
	return rec


func malformed(op: Variant, strict := false) -> String:
	return check_op(op, strict)


## Why the rules refuse a well-formed op now: the store's limits and protection for a place; for a remove, an empty
## cell or a cell holding another block than the op names.
func can_apply(op: Dictionary) -> String:
	var cell := OpUtil.cell(op.at)
	if op.op == "place":
		var why: String = store.refusal(cell)
		if why == "" and check.is_valid():
			why = str(check.call(cell, code_of(op)))
		return why
	var was: int = store.get_code(cell)
	if was == 0:
		return "empty"
	var rec := record("place", cell, was)
	for k: String in BLOCK_KEYS:
		if op.has(k) and rec.get(k, false) != (bool(op[k]) if k == "flip" else int(op[k])):
			return "the cell holds another block (%s)" % k
	return ""


## The op as it is journaled: complete (a remove names what it removes), keys in the contract's order.
func raw(op: Dictionary) -> Dictionary:
	var cell := OpUtil.cell(op.at)
	return record(op.op, cell, code_of(op) if op.op == "place" else store.get_code(cell))


## Why a complete record does not fit the store (undo, redo, a journal replayed: no rules asked). "" = it fits.
func fits(rec: Dictionary) -> String:
	var cell := OpUtil.cell(rec.at)
	if rec.op == "place":
		var why: String = store.refusal(cell)
		return "" if why == "" else "cannot place at %s: %s" % [str(cell), why]
	if store.get_code(cell) != code_of(rec):
		return "cannot remove at %s: it holds something else" % str(cell)
	return ""


func apply(rec: Dictionary) -> void:
	var cell := OpUtil.cell(rec.at)
	if scratch and not touched.has(cell):
		touched[cell] = true
	if rec.op == "place":
		store.put(cell, code_of(rec))
	else:
		store.take(cell)


func invert(rec: Dictionary) -> Dictionary:
	var out := OpUtil.ordered(rec, ORDER)
	out["op"] = "remove" if rec.op == "place" else "place"
	return out


func dirty_regions(rec: Dictionary) -> Array:
	return [AABB(Vector3(OpUtil.cell(rec.at)), Vector3.ONE)]


# ------------------------------------------------------------------ files (tl.build/1 and /2 `chunks`)
func save_part() -> Dictionary:
	var chunks := {}
	for ch: Vector2i in Blocks.sorted_ids(store.counts):
		chunks["%d,%d" % [ch.x, ch.y]] = Marshalls.raw_to_base64((store.chunk_pairs(ch) as PackedInt32Array).to_byte_array())
	return {"chunks": chunks}


## Reads `doc.chunks` into the (emptied) store. Returns "" or what is wrong with it.
func load_part(doc: Dictionary) -> String:
	if typeof(doc.get("chunks")) != TYPE_DICTIONARY:
		return "chunks must be an object"
	var chunks: Dictionary = doc.chunks
	for key: Variant in chunks:
		var xy := str(key).split(",")
		if xy.size() != 2 or not xy[0].is_valid_int() or not xy[1].is_valid_int() or typeof(chunks[key]) != TYPE_STRING:
			return "chunk %s is not \"<cx>,<cz>\": \"<base64>\"" % str(key)
		var ch := Vector2i(int(xy[0]), int(xy[1]))
		var pairs := Marshalls.base64_to_raw(str(chunks[key])).to_int32_array()
		if pairs.size() % 2 != 0:
			return "chunk %s holds an odd number of int32s" % str(key)
		for i: int in range(0, pairs.size(), 2):
			var local := pairs[i]
			if local < 0 or local >= Blocks.CHUNK * Blocks.CHUNK * Blocks.LEVELS:
				return "chunk %s: cell %d is outside the chunk" % [str(key), local]
			var cell := Blocks.pair_cell(ch, local)
			var c := pairs[i + 1]
			if Blocks.shape_of(c) < 1 or Blocks.shape_of(c) > 8 or Blocks.mat_of(c) < 1 or Blocks.mat_of(c) > Blocks.MAT_MAX or c >> 13 != 0:
				return "chunk %s: code %d at %s is not a block" % [str(key), c, str(cell)]
			if not store.put(cell, c):
				return "chunk %s: %s at %s" % [str(key), store.refusal(cell), str(cell)]
	return ""


func clear() -> void:
	store.clear()


func size() -> int:
	return store.total


## SHA-1 of what is built (blocks.gd `content_hash`): M1's identity of the saved content.
func content_hash() -> String:
	return store.content_hash()


# ------------------------------------------------------------------ drawing, copies, reads
func step(budget: int) -> int:
	return mesh.step(budget) if mesh != null else 0


func pending() -> int:
	return store.dirty.size() if mesh != null else 0


## A scratch copy: the same cells and caps, no mesher, the same protection (preview).
func copy() -> RefCounted:
	var s: RefCounted = Blocks.new(store.sec)
	s.sections = store.sections.duplicate(true)
	s.counts = store.counts.duplicate()
	s.total = store.total
	s.cap_chunk = store.cap_chunk
	s.cap_home = store.cap_home
	var c: RefCounted = (get_script() as GDScript).new({"blocks": s, "check": check})
	c.scratch = true
	return c


## What a scratch copy `s` (after a dry run's ops) would change in this store: {"store": the blocks it would fill or
## change, as they would be, "removed": the blocks it would take away}, both blocks.gd stores (home_build.gd `preview`).
func diff(s: RefCounted) -> Dictionary:
	var added: RefCounted = Blocks.new(store.sec)
	var removed: RefCounted = Blocks.new(store.sec)
	for b: RefCounted in [added, removed]:
		b.cap_chunk = 1 << 30
		b.cap_home = 1 << 30
	var after: RefCounted = s.get("store")
	for cell: Vector3i in (s.get("touched") as Dictionary):
		var was: int = store.get_code(cell)
		var now: int = after.get_code(cell)
		if now != 0 and now != was:
			added.put(cell, now)
		if was != 0 and now != was:
			removed.put(cell, was)
	added.dirty.clear()
	removed.dirty.clear()
	return {"store": added, "removed": removed}


## The ghost of this layer's part of a dry run (home_build.gd `preview_nodes`): the blocks it would add in holo and
## those it would take away in red (preview_mesh.gd), or null when it changes no block. The caller adds it to the tree.
func preview_node(s: Variant) -> Node3D:
	if not (s is RefCounted) or not (s as RefCounted).get("scratch"):
		return null
	var d := diff(s)
	if int((d.store as RefCounted).get("total")) == 0 and int((d.removed as RefCounted).get("total")) == 0:
		return null
	var pm: Node3D = (load("res://kernel/world/build/preview_mesh.gd") as GDScript).new()
	pm.call("show_stores", d.store, d.removed)
	return pm


## The blocks inside the cell box `lo`..`hi` (inclusive) as [[x, y, z, code], ...] sorted by z, then x, then y.
func read_region(lo: Vector3i, hi: Vector3i) -> Dictionary:
	var out := []
	var a: Vector2i = store.section_of(lo)
	var b: Vector2i = store.section_of(hi)
	for sz in range(a.y, b.y + 1):
		for sx in range(a.x, b.x + 1):
			var d: Variant = store.sections.get(Vector2i(sx, sz))
			if d == null:
				continue
			for idx: int in (d as Dictionary):
				var c: Vector3i = store.cell_of(Vector2i(sx, sz), idx)
				if c.x >= lo.x and c.x <= hi.x and c.y >= lo.y and c.y <= hi.y and c.z >= lo.z and c.z <= hi.z:
					out.append([c.x, c.y, c.z, int((d as Dictionary)[idx])])
	out.sort_custom(func(p: Array, q: Array) -> bool:
		return p[2] < q[2] or (p[2] == q[2] and (p[0] < q[0] or (p[0] == q[0] and p[1] < q[1]))))
	return {"blocks": out}


func free_all() -> void:
	if mesh != null:
		mesh.free_all()


# ------------------------------------------------------------------ M6: the open zones' mask (lane P draws it)
## SEAM M6: the cells whose blocks are not drawn and do not collide while a zone is open (contracts/BUILD.md "open"):
## the store, the saved file and `content_hash` never change. `set_mask(key, lo, hi, hidden)` adds (or with hidden
## false removes) box `key` (a zone id), inclusive cells, and marks the sections it touches dirty, so the mesh and the
## chunk's body follow in `step`; `masked(cell)` is true inside any box; `clear_masks()` drops them all (a visit ends).
## The seam keeps the boxes and marks the sections; lane P makes block_mesh.gd leave masked cells out of the drawing
## and the collider (LANES.md "M6").
var masks := {}                         # key -> [lo: Vector3i, hi: Vector3i]


func set_mask(key: int, lo: Vector3i, hi: Vector3i, hidden: bool) -> void:
	if mesh != null:
		mesh.set("mask", masks)            # lane P: the mesher reads these boxes (block_mesh.gd `mask`, the same Dictionary)
	if hidden:
		masks[key] = [lo, hi]
	elif masks.has(key):
		masks.erase(key)
	else:
		return
	_touch_box(lo, hi)


func masked(cell: Vector3i) -> bool:
	for k: int in masks:
		var b: Array = masks[k]
		var lo: Vector3i = b[0]
		var hi: Vector3i = b[1]
		if cell.x >= lo.x and cell.x <= hi.x and cell.y >= lo.y and cell.y <= hi.y and cell.z >= lo.z and cell.z <= hi.z:
			return true
	return false


func clear_masks() -> void:
	for k: int in masks.keys():
		set_mask(k, masks[k][0], masks[k][1], false)


func _touch_box(lo: Vector3i, hi: Vector3i) -> void:
	var a: Vector2i = store.section_of(lo - Vector3i(2, 0, 2))
	var b: Vector2i = store.section_of(hi + Vector3i(2, 0, 2))
	for sz in range(a.y, b.y + 1):
		for sx in range(a.x, b.x + 1):
			store.dirty[Vector2i(sx, sz)] = true
