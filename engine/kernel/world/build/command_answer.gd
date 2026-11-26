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


## The note's counts over every op a preview or apply result `r` took (its `refused` [[i, reason]]: i indexes `ops`;
## a negative i is an op refused before the dry run, an unexpanded pour or a locked part): what was built, by kind in
## the order the kinds come, then the refusals by reason, the most first (at most REASONS named):
## "212 blocks, 3 parts, 40 m path, pond 120 cells; 6 refused: game lot, locked: win Parkour once". `placed`: the
## blocks figure (a dry run's cells added, or the places applied); a remove whose cell no later place fills is "removed".
static func counts(r: Dictionary, placed: int, ops: Array = []) -> String:
	var refused: Array = r.get("refused", [])
	var bad := {}
	for x: Array in refused:
		bad[int(x[0])] = true
	var parts := PackedStringArray()
	if placed > 0 or ops.is_empty():
		parts.append(_n(placed, "block"))
	var placed_at := {}
	for i: int in ops.size():
		if not bad.has(i) and ops[i] is Dictionary and str(ops[i].get("op")) == "place":
			placed_at[str(ops[i].get("at"))] = true
	var got := {}                            # kind -> [count, metres] in the order kinds come
	var order := []
	for i: int in ops.size():
		var o: Dictionary = ops[i] if ops[i] is Dictionary else {}
		var k := str(o.get("op", ""))
		if bad.has(i) or k == "" or k == "place" or (k == "remove" and placed_at.has(str(o.get("at")))):
			continue
		if not got.has(k):
			got[k] = [0, 0.0]
			order.append(k)
		got[k][0] = int(got[k][0]) + (1 if k in ["remove", "put", "lift", "path", "unpath", "pour"] else _entries(o))
		if k == "path":
			got[k][1] = float(got[k][1]) + _length_m(o.get("pts", []))
	for k: String in order:
		var n := int(got[k][0])
		match k:
			"remove": parts.append("%d removed" % n)
			"put": parts.append(_n(n, "part"))
			"lift": parts.append("%s lifted" % _n(n, "part"))
			"land": parts.append("land %d points" % n)
			"paint": parts.append("paint %d cells" % n)
			"flood": parts.append("pond %d cells" % n)
			"drain": parts.append("drained %d cells" % n)
			"path": parts.append("%d m path%s" % [roundi(float(got[k][1])), "" if n == 1 else " (%d)" % n])
			"unpath": parts.append("%s removed" % _n(n, "path"))
			"plant": parts.append("plants %d cells" % n)
			_: parts.append("%d %s" % [n, k])
	var s := ", ".join(parts) if not parts.is_empty() else "nothing"
	if refused.is_empty():
		return s
	var by := {}
	var first := []
	for x: Array in refused:
		var why := str(x[1])
		if not by.has(why):
			first.append(why)
		by[why] = int(by.get(why, 0)) + 1
	var seen := first.duplicate()
	first.sort_custom(func(a: String, b: String) -> bool: return int(by[a]) > int(by[b]) or (int(by[a]) == int(by[b]) and seen.find(a) < seen.find(b)))
	var named := ", ".join(PackedStringArray(first.slice(0, REASONS)))
	return "%s; %d refused: %s%s" % [s, refused.size(), named, "" if first.size() <= REASONS else ", ..."]


const REASONS := 3


static func _n(n: int, what: String) -> String:
	return "%d %s%s" % [n, what, "" if n == 1 else "s"]


## The entries a land, paint, flood, drain or plant op lists (its verts or cells).
static func _entries(o: Dictionary) -> int:
	var l: Variant = o.get("verts", o.get("cells", []))
	return (l as Array).size() if l is Array else 0


## The length of a path's control polyline in m (its pts are world cm).
static func _length_m(pts: Variant) -> float:
	var m := 0.0
	if not (pts is Array):
		return m
	for i: int in range(1, (pts as Array).size()):
		var a: Variant = pts[i - 1]
		var b: Variant = pts[i]
		if a is Array and b is Array and (a as Array).size() == 2 and (b as Array).size() == 2:
			m += Vector2(float(a[0]), float(a[1])).distance_to(Vector2(float(b[0]), float(b[1]))) / 100.0
	return m


static func _int(x: Variant) -> Variant:
	if typeof(x) == TYPE_INT:
		return x
	if typeof(x) == TYPE_FLOAT and is_finite(x) and float(x) == floorf(x) and absf(x) < 1e15:
		return int(x)
	return null


## The ops play has not unlocked, split out (contracts/BUILD.md "The LLM command bar, M5 additions": the exe still
## refuses a locked mat or part at accept): {"ops": the rest in order, "refused": [[i, "locked: <condition>"], ...]}, i
## indexing `ops`. A place naming a locked material or shape and a put naming a locked part are refused (unlocks.gd
## `locked`); a remove or a lift takes away what is there and is never locked.
static func split_locked(ops: Array, unlocks: RefCounted) -> Dictionary:
	var out := []
	var refused := []
	for i: int in ops.size():
		var o: Variant = ops[i]
		var why := ""
		if o is Dictionary and str(o.get("op")) == "place":
			for k: String in ["mat", "shape"]:
				if why == "" and (o.get(k) is int or o.get(k) is float):
					why = str(unlocks.call("locked", k + "s", int(o[k])))
		elif o is Dictionary and str(o.get("op")) == "put" and o.get("part") is String:
			why = str(unlocks.call("locked", "parts", str(o.part)))
		if why != "":
			refused.append([i, "locked: " + why])
		else:
			out.append(o)
	return {"ops": out, "refused": refused}
