extends RefCounted
## SEAM (spark world-sandbox, M2-M4): what every layer's validation shares (contracts/BUILD.md `tl.edit/1`): the
## common keys `v`, `author` and `batch`, integers that arrive from JSON as floats, cells. No state; static only.
## A layer's `malformed` calls `common` first with its own key list, then checks its own keys.

const COMMON := ["v", "author", "batch"]


## `x` as an int when it is a whole number (JSON numbers arrive as floats), else null.
static func int_of(x: Variant) -> Variant:
	if typeof(x) == TYPE_INT:
		return x
	if typeof(x) == TYPE_FLOAT and is_finite(x) and float(x) == floorf(x) and absf(x) < 1e9:
		return int(x)
	return null


## The checks every op shares, in the order the M1 log made them: an object, no key outside `keys` (the op's own keys
## and the common ones), `v` 1. `author` and `batch` are checked by `tail` (they come last in M1's order).
static func head(op: Variant, keys: Array) -> String:
	if typeof(op) != TYPE_DICTIONARY:
		return "an operation is a JSON object"
	var d: Dictionary = op
	for k: Variant in d:
		if not keys.has(k):
			return "unknown key '%s'" % str(k)
	if d.has("v") and int_of(d.v) != 1:
		return "v must be 1"
	return ""


## `author` and `batch` well-formed; `strict` (a journal line): v, author and batch present.
static func tail(d: Dictionary, strict: bool) -> String:
	if d.has("author") and not (str(d.author) in ["hand", "llm"]):
		return "author must be \"hand\" or \"llm\""
	if d.has("batch") and (int_of(d.batch) == null or int(d.batch) < 1):
		return "batch must be a positive integer"
	if strict:
		for k: String in COMMON:
			if not d.has(k):
				return "%s is missing" % k
	return ""


## "" when `v` is [x, y, z] of integers, else the reason naming `key`.
static func cell_error(v: Variant, key := "at") -> String:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() != 3:
		return "%s must be [x, y, z]" % key
	for q: Variant in v:
		if int_of(q) == null:
			return "%s must hold three integers" % key
	return ""


static func cell(v: Array) -> Vector3i:
	return Vector3i(int(v[0]), int(v[1]), int(v[2]))


## A record's keys in `order` (the contract's), keys not named there dropped: the journal's key order.
static func ordered(rec: Dictionary, order: Array) -> Dictionary:
	var out := {}
	for k: String in order:
		if rec.has(k):
			out[k] = rec[k]
	return out
