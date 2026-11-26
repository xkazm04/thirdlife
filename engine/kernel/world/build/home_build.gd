extends RefCounted
## WP1: the Home's block building, in one object (no class_name: preload this path). The API build mode (WP2) and the
## LLM command bar (M4) call; BUILD.md documents it. It owns
##   blocks     blocks.gd       the sparse store (cells -> codes), its caps and its dirty sections
##   mesh       block_mesh.gd   section meshes under `root` ("HomeBlocks") and one static body per chunk in the
##                              visitor's WorldSpace (tag "home blocks", layer 1)
##   edits      edit_log.gd     tl.edit/1 ops, batches, undo/redo, the journal; each op kind goes to its layer
##   layers     blocks_layer.gd (place, remove), land_layer.gd (land, paint: M2), pieces_layer.gd (put, lift: M3),
##              water_layer.gd (flood, drain; the input op pour), paths_layer.gd (path, unpath), plants_layer.gd
##              (plant): M5, stubs until their lanes land
##   protect    protect.gd      where a block may not go (and the rules the layers add)
## Edits change the store at once; meshes and bodies follow in `step(budget)`, which the owner calls once per physics
## frame (time is frames). `dirty` is true from the first change after a save or load until the next save
## (`dirty_changed` says when it flips).

signal dirty_changed(dirty: bool)

const Blocks := preload("res://kernel/world/build/blocks.gd")
const Shapes := preload("res://kernel/world/build/shapes.gd")
const BlockMesh := preload("res://kernel/world/build/block_mesh.gd")
const EditLog := preload("res://kernel/world/build/edit_log.gd")
const BuildFile := preload("res://kernel/world/build/build_file.gd")
const Protect := preload("res://kernel/world/build/protect.gd")
const BlocksLayer := preload("res://kernel/world/build/blocks_layer.gd")
const LandLayer := preload("res://kernel/world/build/land_layer.gd")
const PiecesLayer := preload("res://kernel/world/build/pieces_layer.gd")
const WaterLayer := preload("res://kernel/world/build/water_layer.gd")
const PathsLayer := preload("res://kernel/world/build/paths_layer.gd")
const PlantsLayer := preload("res://kernel/world/build/plants_layer.gd")
const LAYER_KINDS := [BlocksLayer, LandLayer, PiecesLayer, WaterLayer, PathsLayer, PlantsLayer]   # seam_lists.gd LAYERS
const INPUT_OPS := {"pour": "water"}     # ops an LLM answer may carry that a layer's `expand_input` turns into ops
const REGION_MAX := 128                  # cells per axis `read_region` reads at most
const HOME_DIR := "user://home"
const NO_CELL := Vector3i(0, -32768, 0)  # cell_at_ray_hit: no block there
const STEP_BUDGET := 4                   # sections rebuilt per frame by default

var blocks: RefCounted
var mesh: RefCounted
var edits: RefCounted
var protect: RefCounted
var layers: Array = []                   # blocks, land, pieces, water, paths, plants (edit_log.gd `register`): BUILD.md "Layers"
var ctx := {}                            # what a layer is made with: blocks, mesh, check, protect, space, root, seed, home
var root: Node3D = null
var ws: Object = null
var home_seed := 7
var rev := 0                             # build.json's rev: +1 for every save that changes what is saved
var dirty := false
var dir := ""                            # where the journal is written ("" until a save or load names it)
var _saved := ""                         # content hash at the last save or load ("" = unknown: the next save bumps rev)


## `parent`: the node the section meshes hang under (null: no meshes). `space`: the visitor's WorldSpace (null: no
## colliders, no protection by the space). `opts`: "seed" (the Home's), "section" (m, 16), "cap_chunk", "cap_home".
func _init(parent: Node3D, space: Object, opts := {}) -> void:
	ws = space
	home_seed = int(opts.get("seed", 7))
	blocks = Blocks.new(int(opts.get("section", 16)))
	blocks.cap_chunk = int(opts.get("cap_chunk", Blocks.CAP_CHUNK))
	blocks.cap_home = int(opts.get("cap_home", Blocks.CAP_HOME))
	if parent != null:
		root = Node3D.new()
		root.name = "HomeBlocks"
		parent.add_child(root)
	mesh = BlockMesh.new(blocks, root, space)
	protect = Protect.new(space)
	edits = EditLog.new()
	edits.before_journal = Callable(self, "_mark_v")    # bound methods, not lambdas: a lambda would hold this object (a cycle)
	ctx = {"blocks": blocks, "mesh": mesh, "check": Callable(protect, "refusal"), "protect": protect, "space": space,
		"root": root, "seed": home_seed, "home": weakref(self)}
	for kind: GDScript in LAYER_KINDS:
		register(kind.new(ctx))
	_saved = _content()


## Adds a layer (BUILD.md "Layers"); one that owns an op another layer has replaces it (a test, a lane over its stub).
## A layer with `add_rules(protect)` adds its protection rules then (once: a scratch copy is never registered here).
func register(l: RefCounted) -> void:
	for gone: RefCounted in edits.register(l):
		layers.erase(gone)
	if not layers.has(l):
		layers.append(l)
		if l.has_method("add_rules"):
			l.add_rules(protect)


## The layer called `id` ("blocks", "land", "pieces", "water", "paths", "plants"), or null.
func layer(id: String) -> RefCounted:
	for l: RefCounted in layers:
		if l.get("id") == id:
			return l
	return null


## The Home's builder for a landscape built with a Home (home/hook.gd `grow`): the visitor's space from the parent's
## meta "tl_space", the protected lots from the walk (boot/village.json) and the valley's sites.
static func attach(parent: Node3D, walk: Dictionary, valley: RefCounted = null, opts := {}) -> RefCounted:
	var o := opts.duplicate()
	var land: Variant = walk.get("landscape", {})
	if not o.has("seed") and typeof(land) == TYPE_DICTIONARY:
		o["seed"] = int((land as Dictionary).get("seed", 7))
	var space: Object = parent.get_meta(&"tl_space") if parent.has_meta(&"tl_space") else null
	var b: RefCounted = (ResourceLoader.load("res://kernel/world/build/home_build.gd") as GDScript).new(parent, space, o)
	b.protect.from_walk(walk)
	if valley != null:
		b.protect.from_sites(valley.get("sites"))
	return b


# ------------------------------------------------------------------ edits
static func code(shape: int, mat: int, rot := 0, flip := false) -> int:
	return Blocks.code(shape, mat, rot, flip)


## The rot of a stair, ramp or roof that rises away from someone looking along `facing` (rot 0 rises toward -z).
static func rot_facing(facing: Vector3) -> int:
	if absf(facing.x) > absf(facing.z):
		return 3 if facing.x > 0.0 else 1
	return 2 if facing.z > 0.0 else 0


func code_at(cell: Vector3i) -> int:
	return blocks.get_code(cell)


## Why a block `c` may not be placed at `cell` now ("" = it may): occupancy, range, caps, the code itself, protection.
func can_place(cell: Vector3i, c: int) -> String:
	var why: String = blocks.refusal(cell)
	if why == "":
		why = EditLog.malformed(EditLog.op_place(cell, c))
	if why == "":
		why = protect.refusal(cell)
	return why


## One tl.edit/1 op or an Array of them (one batch, unless a batch is open). Returns {"ok", "reason", "applied",
## "refused": [[index, reason], ...]}. v, author and batch may be left out of an op; unknown keys are refused.
func apply(x: Variant) -> Dictionary:
	var r: Dictionary = edits.apply(x)
	_mark()
	return r


func place(cell: Vector3i, c: int, who := "hand") -> Dictionary:
	return apply(EditLog.op_place(cell, c, who))


func remove(cell: Vector3i, who := "hand") -> Dictionary:
	return apply(EditLog.op_remove(cell, who))


## Ops applied until `end_batch` are one undo step (a drag, an LLM job). Nested calls share the outer batch.
func begin_batch(who := "hand") -> int:
	return edits.begin_batch(who)


func end_batch() -> void:
	edits.end_batch()


## Undoes / redoes one batch. Returns how many ops changed (0: nothing to do, or a batch is open).
func undo() -> int:
	var n: int = edits.undo()
	_mark()
	return n


func redo() -> int:
	var n: int = edits.redo()
	_mark()
	return n


func _mark() -> void:
	if int(edits.changes) == 0:
		return
	edits.changes = 0
	if not dirty:
		dirty = true
		dirty_changed.emit(true)


## Rebuilds at most `budget` dirty sections and their chunks' bodies. Returns how many sections it rebuilt.
## Every layer gets the budget (its own unit: sections for blocks).
func step(budget := STEP_BUDGET) -> int:
	var n := 0
	for l: RefCounted in layers:
		n += int(l.step(budget))
	return n


## Rebuilds everything pending now (a load, a test).
func flush() -> int:
	var n := 0
	for l: RefCounted in layers:
		while int(l.pending()) > 0:
			n += int(l.step(1 << 20))
	return n


# ------------------------------------------------------------------ the cursor
## The cell a cursor ray that hit `pos` with surface normal `normal` names. `placing`: the empty cell a new block goes
## into (the cell in front of the face that was hit; on the ground the cell holding the point just above it, so a block
## is set into the ground, never floating). Not placing: the block that was hit, or NO_CELL.
func cell_at_ray_hit(pos: Vector3, normal: Vector3, placing: bool) -> Vector3i:
	var n := normal.normalized()
	var inside := Vector3i((pos - n * 0.01).floor())
	var front := Vector3i((pos + n * 0.01).floor())
	if not placing:
		if blocks.get_code(inside) != 0:
			return inside
		return front if blocks.get_code(front) != 0 else NO_CELL
	if blocks.get_code(front) == 0:
		return front
	var a := n.abs()
	var axis := 0 if a.x >= a.y and a.x >= a.z else (1 if a.y >= a.z else 2)
	front[axis] += 1 if n[axis] > 0.0 else -1
	return front


## A cursor ray from `from` to `to` against the visitor's space (ground, blocks, everything static; not the visitor).
## Returns {} for no hit, else {"pos", "normal", "block": bool (it hit a block), "place": Vector3i, "remove": Vector3i}.
func pick(from: Vector3, to: Vector3) -> Dictionary:
	if ws == null:
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var body: RID = ws.get("body")
	if body.is_valid():
		q.exclude = [body]
	var hit: Dictionary = PhysicsServer3D.space_get_direct_state(ws.get("space")).intersect_ray(q)
	if hit.is_empty():
		return {}
	var p: Vector3 = hit.position
	var nrm: Vector3 = hit.normal
	return {"pos": p, "normal": nrm, "block": str((ws.get("_tags") as Dictionary).get(hit.rid, "")) == BlockMesh.TAG,
		"place": cell_at_ray_hit(p, nrm, true), "remove": cell_at_ray_hit(p, nrm, false)}


# ------------------------------------------------------------------ reads and dry runs (M3 stamps, M4 the LLM)
## What is in the cell box `lo`..`hi` (inclusive; at most REGION_MAX cells per axis): {"min", "max", "blocks":
## [[x, y, z, code], ...] sorted by z, then x, then y}, plus every other layer's keys (its `read_region`), or
## {"error"} when the box is too large or upside down.
func read_region(lo: Vector3i, hi: Vector3i) -> Dictionary:
	var size := hi - lo + Vector3i.ONE
	if size.x < 1 or size.y < 1 or size.z < 1:
		return {"error": "the box's max is below its min"}
	if size.x > REGION_MAX or size.y > REGION_MAX or size.z > REGION_MAX:
		return {"error": "the box is larger than %d cells on a side" % REGION_MAX}
	var out := {"min": [lo.x, lo.y, lo.z], "max": [hi.x, hi.y, hi.z]}
	for l: RefCounted in layers:
		if l.has_method("read_region"):
			var part: Dictionary = l.read_region(lo, hi)
			for k: Variant in part:
				out[k] = part[k]
	return out


## A dry run: `ops` (one batch) applied to a scratch copy of every layer, with the same rules and protection, but no
## mesh, no body, no log and no file. Returns {"ok", "reason", "applied", "refused" (as `apply`), "store" (a blocks.gd
## store of the cells the ops fill or change, as they would be: what a ghost draws), "removed" (a store of the
## blocks they would take away), "scratch" ({layer id: its copy after the ops})}. The real Home is untouched.
func preview(ops: Array) -> Dictionary:
	var trial: RefCounted = EditLog.new()
	var scratch := {}
	for l: RefCounted in layers:
		var c: RefCounted = l.copy()
		scratch[str(l.get("id"))] = c
		trial.register(c)
	var r: Dictionary = trial.apply(ops)
	var d: Dictionary = layer("blocks").diff(scratch["blocks"])
	r["store"] = d.store
	r["removed"] = d.removed
	r["scratch"] = scratch
	return r


## The ghost of a dry run (`preview`'s result `r`), one Node3D per layer that has something to show (its
## `preview_node(r.scratch[id])`; blocks: the cells added in holo and removed in red), in the layers' order, each with
## the meta "tl_layer" = its layer's id. Layers named in `skip` are left out (a caller that draws them itself). The
## caller adds the nodes to the tree and frees them.
func preview_nodes(r: Dictionary, skip: Array = []) -> Array:
	var out := []
	var scratch: Dictionary = r.get("scratch", {})
	for l: RefCounted in layers:
		var lid := str(l.get("id"))
		if skip.has(lid) or not l.has_method("preview_node") or not scratch.has(lid):
			continue
		var n: Variant = l.call("preview_node", scratch[lid])
		if n is Node3D:
			(n as Node3D).set_meta(&"tl_layer", lid)
			out.append(n)
	return out


## An LLM answer's ops with every input-only op (INPUT_OPS: `pour`) expanded by its layer's `expand_input(op)`
## (which answers {"ops": [...]} or {"error"}); every other op passes through unchanged. Returns {"ops": the ops to
## preview and apply, "refused": [[index in `ops`, reason], ...] for the input ops that could not be expanded}. An
## expanded op takes the input op's `author` when it names none.
func expand_input(ops: Array) -> Dictionary:
	var out := []
	var refused := []
	for i: int in ops.size():
		var op: Variant = ops[i]
		var kind := str((op as Dictionary).get("op", "")) if op is Dictionary else ""
		if not INPUT_OPS.has(kind):
			out.append(op)
			continue
		var l := layer(str(INPUT_OPS[kind]))
		var e: Dictionary = l.call("expand_input", op) if l != null and l.has_method("expand_input") else {"error": "nothing expands %s" % kind}
		if e.has("error") or typeof(e.get("ops")) != TYPE_ARRAY:
			refused.append([i, str(e.get("error", "%s gave no ops" % kind))])
			continue
		for x: Variant in e.ops:
			var o: Dictionary = (x as Dictionary).duplicate(true)
			if (op as Dictionary).has("author") and not o.has("author"):
				o["author"] = op.author
			out.append(o)
	return {"ops": out, "refused": refused}


# ------------------------------------------------------------------ files
## Compacts the Home into `d`/build.json and empties `d`/edits.jsonl; later edits are journaled there. Returns "" or
## what went wrong.
func save(d := HOME_DIR) -> String:
	var h := _content()
	var r := rev + (1 if h != _saved else 0)
	_close_journal()
	var doc: Dictionary = BuildFile.text_of(layers, home_seed, r)
	var why: String = BuildFile.save(d, doc.text)
	if why == "":
		rev = r
		_saved = h
		edits.file_v = int(doc.v)
		if dirty:
			dirty = false
			dirty_changed.emit(false)
	_open_journal(d)
	return why


## Replaces the store with `d`'s build.json and journal. Returns build_file.gd `load_into`'s figures. Undo and redo
## start empty; meshes and bodies follow in `step` (or `flush`).
func load(d := HOME_DIR) -> Dictionary:
	_close_journal()
	edits.history.clear()
	edits.future.clear()
	var r: Dictionary = BuildFile.load_into(d, layers, edits, home_seed)
	edits.changes = 0
	edits.file_v = int(r.v)
	rev = int(r.rev)
	_saved = "" if int(r.replayed) > 0 or not r.ok else _content()
	var was := dirty
	dirty = int(r.replayed) > 0
	if dirty != was:
		dirty_changed.emit(dirty)
	if r.ok:
		_open_journal(d)
	return r


func _open_journal(d: String) -> void:
	dir = d
	var p := d.path_join(BuildFile.EDITS)
	var f := FileAccess.open(p, FileAccess.READ_WRITE) if FileAccess.file_exists(p) else FileAccess.open(p, FileAccess.WRITE)
	if f != null:
		f.seek_end()
	edits.journal = f


## The identity of what is saved: the blocks' content hash (M1's, so a blocks-only Home keeps its revs), then each
## other layer's.
func _content() -> String:
	var h := ""
	for l: RefCounted in layers:
		h += str(l.content_hash())
	return h


## edit_log.gd `before_journal`: build.json is raised to the version `rec`'s op kind needs (build_file.gd OP_V) before
## the first op of that version is journaled.
func _mark_v(rec: Dictionary) -> String:
	return BuildFile.mark_v(dir, home_seed, BuildFile.version_of(str(rec.get("op", "")))) if dir != "" else ""


func _close_journal() -> void:
	if edits.journal != null:
		(edits.journal as FileAccess).close()
		edits.journal = null


# ------------------------------------------------------------------ figures
func stats() -> Dictionary:
	var t := 0
	for s: Vector2i in mesh.tris:
		t += int(mesh.tris[s])
	return {"blocks": blocks.total, "chunks": blocks.counts.size(), "sections": mesh.tris.size(), "bodies": mesh.bodies.size(),
		"tris": t, "pending": blocks.dirty.size(), "undo": edits.history.size(), "redo": edits.future.size(), "rev": rev,
		"dirty": dirty, "rebuilt_sections": mesh.counters.sections, "rebuilt_chunks": mesh.counters.chunks}


## Everything gone from the scene and the space (the store stays): the owner is leaving the Home.
func free_all() -> void:
	_close_journal()
	for l: RefCounted in layers:
		l.free_all()
	if root != null:
		root.queue_free()
		root = null
