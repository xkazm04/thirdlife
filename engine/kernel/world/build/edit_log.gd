extends RefCounted
## WP1 + SEAM: the edit log of the Home (tl.edit/1, contracts/BUILD.md). Every change goes through here as one
## operation; the hand tools (build mode) and the LLM command bar (M4) write the same ops. Operations group into
## batches (one click or drag, one LLM job): undo and redo work per batch. A removal records what it removed, so a
## batch can be undone without reading the world.
##
## Each op kind belongs to one LAYER (BUILD.md "Layers"): blocks (place, remove), land (land, paint), pieces (put,
## lift), water (flood, drain), paths (path, unpath), plants (plant). The log validates, applies, inverts and journals through the layer that `register` named for the op; it knows
## nothing of cells or heights itself.
##
## The journal (`edits.jsonl`, build_file.gd) is the sequence of changes as they happened: an undo appends the
## inverse operations as a new batch and a redo appends them again, so replaying the journal in order gives the
## store back whatever was undone. Undo and redo stacks live in memory only (a new session starts with none).
## Every op kind needs a version of build.json (build_file.gd OP_V: place, remove 1; land, paint, put, lift 2; flood,
## drain, path, unpath, plant 3). Before the first op of a version above build.json's is journaled, `before_journal`
## is called (home_build.gd raises build.json to that version then), so an older exe refuses the Home instead of
## compacting such an op away.

const BlocksLayer := preload("res://kernel/world/build/blocks_layer.gd")
const OpUtil := preload("res://kernel/world/build/op_util.gd")
const BuildFile := preload("res://kernel/world/build/build_file.gd")

var layers: Array = []                  # registered layers, in order
var by_op := {}                         # op name -> layer
var history: Array = []                 # done batches, oldest first: {"batch": int, "ops": [op, ...]} as applied
var future: Array = []                  # undone batches, the next redo last
var next_batch := 1
var open := 0                           # the batch ops go into now (0: none open; each op is a batch of its own)
var depth := 0
var author := "hand"
var journal: FileAccess = null          # appended to as ops are applied (build_file.gd opens it)
var changes := 0                        # ops applied, undone or redone since the owner last looked (dirty)
var before_journal: Callable            # (rec) -> "" or why build.json could not be raised to the version rec.op needs
var file_v := 0                         # build.json's version on disk (0: none; the owner sets it on load and save)
var v2_ready: bool:                     # M2-M4's name: build.json reads as tl.build/2 or later
	get: return file_v >= 2
	set(on): file_v = maxi(file_v, 2) if on else mini(file_v, 1)
var last_error := ""                    # why the last undo or redo did nothing although there was a batch


## Adds a layer: every op its `ops()` names is its own from now on. A layer that names an op another layer has
## replaces that one (a test layer, or a lane's layer over its stub). Returns the layers it replaced.
func register(layer: RefCounted) -> Array:
	var gone := []
	for o: String in layer.ops():
		var was: RefCounted = by_op.get(o)
		if was != null and was != layer and not gone.has(was):
			gone.append(was)
	for g: RefCounted in gone:
		layers.erase(g)
		for o: String in by_op.keys():
			if by_op[o] == g:
				by_op.erase(o)
	for o: String in layer.ops():
		by_op[o] = layer
	if not layers.has(layer):
		layers.append(layer)
	return gone


## The layer an op belongs to, or null (no such op, or not an object).
func layer_of(op: Variant) -> RefCounted:
	if typeof(op) != TYPE_DICTIONARY or typeof((op as Dictionary).get("op")) != TYPE_STRING:
		return null
	return by_op.get((op as Dictionary).op)


# ------------------------------------------------------------------ ops (M1 shorthands for blocks)
static func op_place(cell: Vector3i, c: int, who := "hand") -> Dictionary:
	var op := BlocksLayer.record("place", cell, c)
	op["author"] = who
	return op


static func op_remove(cell: Vector3i, who := "hand") -> Dictionary:
	return {"v": 1, "op": "remove", "at": [cell.x, cell.y, cell.z], "author": who}


## M1's check of a place or remove, without a log (home_build.gd `can_place`). Other ops: `validate`.
static func malformed(op: Variant, strict := false) -> String:
	return BlocksLayer.check_op(op, strict)


## Why `op` is not a well-formed tl.edit/1 operation of any registered layer ("" = it is). `strict`: as read from a
## journal (every required key). Not strict: v, author and batch may be left out (the log fills them in).
func validate(op: Variant, strict := false) -> String:
	if typeof(op) != TYPE_DICTIONARY:
		return "an operation is a JSON object"
	var l := layer_of(op)
	if l == null:
		return "op must be one of %s" % ", ".join(by_op.keys().map(func(k: String) -> String: return "\"%s\"" % k))
	return str(l.malformed(op, strict))


# ------------------------------------------------------------------ batches
## Opens a batch (nested calls share the outer one). Returns its number.
func begin_batch(who := "hand") -> int:
	if depth == 0:
		open = next_batch
		next_batch += 1
		author = who
	depth += 1
	return open


func end_batch() -> void:
	if depth == 0:
		return
	depth -= 1
	if depth == 0:
		open = 0
		if journal != null:
			journal.flush()


## Applies one op or an Array of them (one batch). Returns {"ok", "reason", "applied", "refused": [[i, reason], ...]}:
## a batch is applied as far as it goes; refused ops are reported and never written.
func apply(x: Variant) -> Dictionary:
	var ops: Array = x if typeof(x) == TYPE_ARRAY else [x]
	var own := depth == 0
	if own:
		var who := "hand"
		if not ops.is_empty() and typeof(ops[0]) == TYPE_DICTIONARY:
			who = str((ops[0] as Dictionary).get("author", "hand"))
		begin_batch(who)
	var refused := []
	var applied := 0
	for i: int in ops.size():
		var why := _one(ops[i])
		if why == "":
			applied += 1
		else:
			refused.append([i, why])
	if own:
		end_batch()
	return {"ok": refused.is_empty(), "reason": "" if refused.is_empty() else str(refused[0][1]), "applied": applied, "refused": refused}


func _one(op: Variant) -> String:
	var why := validate(op)
	if why != "":
		return why
	var l := layer_of(op)
	why = str(l.can_apply(op))
	if why != "":
		return why
	var rec: Dictionary = l.raw(op)
	why = _ready_for([rec])
	if why != "":
		return why
	l.apply(rec)
	_finish(rec, str((op as Dictionary).get("author", author)), open)
	_record(rec)
	future.clear()
	return ""


## The journal can take `recs`: when one of them needs a version of build.json above the one on disk (no file reads
## as version 1: a v1 reader takes a journal of blocks with no file), `before_journal` raises it first, once, to the
## highest version the records need. "" = go on.
func _ready_for(recs: Array) -> String:
	if journal == null or not before_journal.is_valid():
		return ""
	var need := maxi(file_v, 1)
	var first: Dictionary = {}
	for r: Dictionary in recs:
		var n := BuildFile.version_of(str(r.op))
		if n > need:
			need = n
			first = r
	if first.is_empty():
		return ""
	var why := str(before_journal.call(first))
	if why != "":
		return "cannot make build.json tl.build/%d before journaling %s (%s)" % [need, first.op, why]
	file_v = need
	return ""


## author and batch go last, in that order (the contract's key order for every op).
static func _finish(rec: Dictionary, who: String, batch: int) -> void:
	rec.erase("author")
	rec.erase("batch")
	rec["author"] = who
	rec["batch"] = batch


func _record(rec: Dictionary) -> void:
	if history.is_empty() or int((history[history.size() - 1] as Dictionary).batch) != open:
		history.append({"batch": open, "ops": []})
	((history[history.size() - 1] as Dictionary).ops as Array).append(rec)
	_write(rec)


func _write(rec: Dictionary) -> void:
	changes += 1
	if journal != null:
		journal.store_string(line(rec) + "\n")


## A record as one journal line (its keys are already in the contract's order: the layer's `raw`, then `_finish`).
static func line(rec: Dictionary) -> String:
	return JSON.stringify(rec, "", false)


# ------------------------------------------------------------------ undo / redo
## Undoes the last batch: its ops in reverse, each inverted by its layer. Returns how many ops (0: nothing to undo).
func undo() -> int:
	last_error = ""
	if depth > 0 or history.is_empty():
		return 0
	var b: Dictionary = history[history.size() - 1]
	last_error = _ready_for(b.ops)
	if last_error != "":
		return 0
	history.pop_back()
	var ops: Array = b.ops
	var id := next_batch
	next_batch += 1
	for i: int in range(ops.size() - 1, -1, -1):
		var o: Dictionary = ops[i]
		var inv: Dictionary = (by_op[o.op] as RefCounted).invert(o)
		_finish(inv, str(o.author), id)
		_raw(inv)
	future.append(b)
	if journal != null:
		journal.flush()
	return ops.size()


## Redoes the last undone batch. Returns how many ops (0: nothing to redo).
func redo() -> int:
	last_error = ""
	if depth > 0 or future.is_empty():
		return 0
	var b: Dictionary = future[future.size() - 1]
	last_error = _ready_for(b.ops)
	if last_error != "":
		return 0
	future.pop_back()
	var id := next_batch
	next_batch += 1
	for o: Dictionary in b.ops:
		var again: Dictionary = o.duplicate()
		again["batch"] = id
		_raw(again)
	history.append(b)
	if journal != null:
		journal.flush()
	return (b.ops as Array).size()


## A complete record applied without asking the rules (undo, redo, a journal being replayed: the state it was made in
## is the state it meets). Returns "" or why it does not fit (a journal that does not match its build file).
func _raw(rec: Dictionary, write := true) -> String:
	var l: RefCounted = by_op.get(rec.op)
	var why := str(l.fits(rec))
	if why != "":
		return why
	l.apply(rec)
	if write:
		_write(rec)
	else:
		changes += 1
	return ""


## A journal line read back (build_file.gd `load`): strictly checked, applied raw, not written again.
func replay(rec: Variant) -> String:
	var why := validate(rec, true)
	if why != "":
		return why
	next_batch = maxi(next_batch, int(rec.batch) + 1)
	return _raw(rec, false)
