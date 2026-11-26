extends RefCounted
## WP1: the edit log of the Home's blocks (tl.edit/1, contracts/BUILD.md). Every change to the store goes through
## here as one operation; the hand tools (WP2) and the LLM command bar (M4) write the same ops. Operations group into
## batches (one click or drag, one LLM job): undo and redo work per batch. A remove records what it removed, so a
## batch can be undone without reading the world.
##
## The journal (`edits.jsonl`, build_file.gd) is the sequence of changes as they happened: an undo appends the
## inverse operations as a new batch and a redo appends them again, so replaying the journal in order gives the
## store back whatever was undone. Undo and redo stacks live in memory only (a new session starts with none).

const Blocks := preload("res://kernel/world/build/blocks.gd")
const KEYS := ["v", "op", "at", "shape", "mat", "rot", "flip", "author", "batch"]
const BLOCK_KEYS := ["shape", "mat", "rot", "flip"]

var store: RefCounted                   # blocks.gd
var check: Callable                     # (cell: Vector3i, code: int) -> reason ("" = allowed): protect.gd, set by the owner
var history: Array = []                 # done batches, oldest first: {"batch": int, "ops": [op, ...]} as applied
var future: Array = []                  # undone batches, the next redo last
var next_batch := 1
var open := 0                           # the batch ops go into now (0: none open; each op is a batch of its own)
var depth := 0
var author := "hand"
var journal: FileAccess = null          # appended to as ops are applied (build_file.gd opens it)
var changes := 0                        # ops applied, undone or redone since the owner last looked (dirty)


# ------------------------------------------------------------------ ops
static func op_place(cell: Vector3i, c: int, who := "hand") -> Dictionary:
	var op := {"v": 1, "op": "place", "at": [cell.x, cell.y, cell.z], "shape": Blocks.shape_of(c), "mat": Blocks.mat_of(c),
		"rot": Blocks.rot_of(c)}
	if Blocks.flip_of(c):
		op["flip"] = true
	op["author"] = who
	return op


static func op_remove(cell: Vector3i, who := "hand") -> Dictionary:
	return {"v": 1, "op": "remove", "at": [cell.x, cell.y, cell.z], "author": who}


static func _int(x: Variant) -> Variant:
	if typeof(x) == TYPE_INT:
		return x
	if typeof(x) == TYPE_FLOAT and is_finite(x) and float(x) == floorf(x) and absf(x) < 1e9:
		return int(x)
	return null


## Why `op` is not a well-formed tl.edit/1 operation ("" = it is). `strict`: as read from a journal, every required
## key present (v, op, at, shape, mat, rot, author, batch). Not strict (an op handed to `apply`): v, author and batch may
## be left out (the log fills them in), and a remove may leave out what it removes.
static func malformed(op: Variant, strict := false) -> String:
	if typeof(op) != TYPE_DICTIONARY:
		return "an operation is a JSON object"
	var d: Dictionary = op
	for k: Variant in d:
		if not KEYS.has(k):
			return "unknown key '%s'" % str(k)
	if d.has("v") and _int(d.v) != 1:
		return "v must be 1"
	if not d.has("op") or not (str(d.op) in ["place", "remove"]) or typeof(d.op) != TYPE_STRING:
		return "op must be \"place\" or \"remove\""
	if typeof(d.get("at")) != TYPE_ARRAY or (d.at as Array).size() != 3:
		return "at must be [x, y, z]"
	for q: Variant in d.at:
		if _int(q) == null:
			return "at must hold three integers"
	var place: bool = d.op == "place"
	for k: String in ["shape", "mat", "rot"]:
		if d.has(k) and _int(d[k]) == null:
			return "%s must be an integer" % k
		if not d.has(k) and (place or strict):
			return "%s is missing" % k
	if d.has("shape") and (int(d.shape) < 1 or int(d.shape) > 8):
		return "unknown shape %d" % int(d.shape)
	if d.has("mat") and (int(d.mat) < 1 or int(d.mat) > 10):
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
	if d.has("author") and not (str(d.author) in ["hand", "llm"]):
		return "author must be \"hand\" or \"llm\""
	if d.has("batch") and (_int(d.batch) == null or int(d.batch) < 1):
		return "batch must be a positive integer"
	if strict:
		for k: String in ["v", "author", "batch"]:
			if not d.has(k):
				return "%s is missing" % k
	return ""


static func cell_of(op: Dictionary) -> Vector3i:
	return Vector3i(int(op.at[0]), int(op.at[1]), int(op.at[2]))


static func code_of(op: Dictionary) -> int:
	return Blocks.code(int(op.shape), int(op.mat), int(op.rot), bool(op.get("flip", false)))


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
	var why := malformed(op)
	if why != "":
		return why
	var d: Dictionary = op
	var cell := cell_of(d)
	var rec: Dictionary
	if d.op == "place":
		var c := code_of(d)
		why = store.refusal(cell)
		if why == "" and check.is_valid():
			why = str(check.call(cell, c))
		if why != "":
			return why
		store.put(cell, c)
		rec = op_place(cell, c, str(d.get("author", author)))
	else:
		var was: int = store.get_code(cell)
		if was == 0:
			return "empty"
		for k: String in BLOCK_KEYS:
			if d.has(k) and op_place(cell, was).get(k, false) != (bool(d[k]) if k == "flip" else int(d[k])):
				return "the cell holds another block (%s)" % k
		store.take(cell)
		rec = op_place(cell, was, str(d.get("author", author)))
		rec["op"] = "remove"
	_record(rec)
	future.clear()
	return ""


func _record(rec: Dictionary) -> void:
	rec["batch"] = open
	if history.is_empty() or int((history[history.size() - 1] as Dictionary).batch) != open:
		history.append({"batch": open, "ops": []})
	((history[history.size() - 1] as Dictionary).ops as Array).append(rec)
	_write(rec)


func _write(rec: Dictionary) -> void:
	changes += 1
	if journal != null:
		journal.store_string(line(rec) + "\n")


## An op as one journal line: keys in the contract's order, flip only when true.
static func line(rec: Dictionary) -> String:
	var out := {}
	for k: String in KEYS:
		if rec.has(k):
			out[k] = rec[k]
	return JSON.stringify(out, "", false)


# ------------------------------------------------------------------ undo / redo
## Undoes the last batch: its ops in reverse, each inverted. Returns how many ops (0: nothing to undo).
func undo() -> int:
	if depth > 0 or history.is_empty():
		return 0
	var b: Dictionary = history.pop_back()
	var ops: Array = b.ops
	var id := next_batch
	next_batch += 1
	for i: int in range(ops.size() - 1, -1, -1):
		var o: Dictionary = ops[i]
		var inv: Dictionary = o.duplicate()
		inv["op"] = "remove" if o.op == "place" else "place"
		inv["batch"] = id
		_raw(inv)
	future.append(b)
	if journal != null:
		journal.flush()
	return ops.size()


## Redoes the last undone batch. Returns how many ops (0: nothing to redo).
func redo() -> int:
	if depth > 0 or future.is_empty():
		return 0
	var b: Dictionary = future.pop_back()
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


## An op applied without asking the rules (undo, redo, a journal being replayed: the state it was made in is the
## state it meets). Returns "" or why it does not fit the store (a journal that does not match its build file).
func _raw(rec: Dictionary, write := true) -> String:
	var cell := cell_of(rec)
	if rec.op == "place":
		if not store.put(cell, code_of(rec)):
			return "cannot place at %s: %s" % [str(cell), store.refusal(cell)]
	else:
		if store.get_code(cell) != code_of(rec):
			return "cannot remove at %s: it holds something else" % str(cell)
		store.take(cell)
	if write:
		_write(rec)
	else:
		changes += 1
	return ""


## A journal line read back (build_file.gd `load`): strictly checked, applied raw, not written again.
func replay(rec: Variant) -> String:
	var why := malformed(rec, true)
	if why != "":
		return why
	next_batch = maxi(next_batch, int(rec.batch) + 1)
	return _raw(rec, false)
