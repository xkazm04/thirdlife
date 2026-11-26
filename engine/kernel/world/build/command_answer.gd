extends RefCounted
## M4 (spark world-sandbox): reads the Foreman's answer to a world edit, `tl.world-edit/1` (contracts/BUILD.md "The
## LLM command bar"): {schema, ops, note, model, durationMs, tokensIn?, tokensOut?} or {schema, error}. Unknown keys
## are errors; an op may not carry `v`, `author` or `batch` (the exe fills them in: `author: "llm"`, one batch). The
## ops' own rules are the layers' (home_build.gd `preview` and `apply` refuse what does not fit, with the reason). Static.

const SCHEMA := "tl.world-edit/1"
const KEYS := ["schema", "ops", "note", "model", "durationMs", "tokensIn", "tokensOut"]
const OWN := ["v", "author", "batch"]


## The answer in `path`: {"ok": true, "ops", "note", "model", "durationMs", "tokensIn"?, "tokensOut"?} or {"ok": false,
## "error"} (the Foreman's own error, or why the file is not a world-edit answer).
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "no answer file"}
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return check(j)


static func check(j: Variant) -> Dictionary:
	if typeof(j) != TYPE_DICTIONARY:
		return {"ok": false, "error": "the answer is not a JSON object"}
	var d: Dictionary = j
	if d.get("schema") != SCHEMA:
		return {"ok": false, "error": "the answer is not %s" % SCHEMA}
	if d.has("error"):
		if d.size() != 2 or typeof(d.error) != TYPE_STRING:
			return {"ok": false, "error": "an error answer holds only schema and error"}
		return {"ok": false, "error": str(d.error), "foreman": true}
	for k: Variant in d:
		if not KEYS.has(k):
			return {"ok": false, "error": "unknown key '%s' in the answer" % str(k)}
	for k: String in ["ops", "note", "model", "durationMs"]:
		if not d.has(k):
			return {"ok": false, "error": "%s is missing from the answer" % k}
	if typeof(d.ops) != TYPE_ARRAY or (d.ops as Array).is_empty():
		return {"ok": false, "error": "ops must be a non-empty list"}
	if typeof(d.note) != TYPE_STRING or typeof(d.model) != TYPE_STRING:
		return {"ok": false, "error": "note and model are strings"}
	var out := {"ok": true, "ops": [], "note": str(d.note).replace("\n", " ").strip_edges(), "model": str(d.model)}
	for k: String in ["durationMs", "tokensIn", "tokensOut"]:
		if d.has(k):
			var n: Variant = _int(d[k])
			if n == null or int(n) < 0:
				return {"ok": false, "error": "%s must be a whole number" % k}
			out[k] = int(n)
	for i: int in (d.ops as Array).size():
		var op: Variant = d.ops[i]
		if typeof(op) != TYPE_DICTIONARY:
			return {"ok": false, "error": "ops[%d] is not an object" % i}
		for k: String in OWN:
			if (op as Dictionary).has(k):
				return {"ok": false, "error": "ops[%d] carries %s (the exe fills it in)" % [i, k]}
		(out.ops as Array).append(op)
	return out


## The ops as the exe applies them: each with `author: "llm"` (the log numbers the batch and fills `v`).
static func llm_ops(ops: Array) -> Array:
	var out := []
	for op: Dictionary in ops:
		var o := op.duplicate(true)
		o["author"] = "llm"
		out.append(o)
	return out


## "212 blocks, 6 refused: game lot" from a preview or apply result (its `refused` [[i, reason]] counted by reason).
static func counts(r: Dictionary, placed: int) -> String:
	var s := "%d block%s" % [placed, "" if placed == 1 else "s"]
	var refused: Array = r.get("refused", [])
	if refused.is_empty():
		return s
	var by := {}
	for x: Array in refused:
		by[str(x[1])] = int(by.get(str(x[1]), 0)) + 1
	var top := ""
	var most := 0
	for k: String in by:
		if int(by[k]) > most:
			most = int(by[k])
			top = k
	return "%s, %d refused: %s" % [s, refused.size(), top]


static func _int(x: Variant) -> Variant:
	if typeof(x) == TYPE_INT:
		return x
	if typeof(x) == TYPE_FLOAT and is_finite(x) and float(x) == floorf(x) and absf(x) < 1e15:
		return int(x)
	return null
