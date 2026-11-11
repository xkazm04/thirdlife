extends RefCounted
## V0: pack.json checks. A hand-written mirror of contracts/pack.schema.json (tl.pack/0.1); unknown keys are errors.
## No global class names are used here: the supervisor loads this before the class cache is known to exist.

## P7: API version 1. The surface a pack may use is written down by a machine (docs/generated/API-V1.json, checked by
## `tl arch` rule api-v1): a signature that is removed or changed needs a new major, an addition a new minor.
const KERNEL_API: String = "1.0"
## "0.1" was the name of this same surface before it was frozen: a pack that says 0.1 is run as a 1.0 pack.
const LEGACY_API: Dictionary = {"0.1": "1.0"}
const CAPABILITIES: Array = ["physics", "input", "ui", "audio", "vfx", "camera", "rules", "ai", "spawn", "fracture",
	"vehicle", "biped", "ball", "kit", "style"]
const ID_RE: String = "^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$"
const KEYS: Dictionary = {
	"id": {"type": "string", "pattern": ID_RE, "required": true},
	"version": {"type": "string", "pattern": "^\\d+\\.\\d+\\.\\d+$", "required": true},
	"kernelApi": {"type": "string", "pattern": "^\\d+\\.\\d+$", "required": true},
	"title": {"type": "string", "min": 1, "max": 80, "required": true},
	"capabilities": {"type": "array", "enum": CAPABILITIES, "unique": true, "required": true},
	"entry": {"type": "string", "pattern": "^scripts/[A-Za-z0-9_/]+\\.gd$", "required": true},
	"assets": {"type": "array", "pattern": "^gen/[A-Za-z0-9_/]+\\.gd$", "required": true},
	"tests": {"type": "array", "pattern": "^tests/[A-Za-z0-9_/]+\\.gd$", "min_items": 1, "required": true},
	"requires": {"type": "array", "pattern": ID_RE},
	"cameras": {"type": "array", "pattern": "^[a-z][a-z0-9_]*$"},
	# optional fields of 2026-11-11 (contracts/PACK.md, last section); a pack without them behaves as before
	"footprint": {"type": "shape"},
	"params": {"type": "shape"},
	"on_leave": {"type": "string", "pattern": "^(bot|pause|end)$"},
	"subject": {"type": "string", "pattern": "^[A-Za-z0-9_]+(/[A-Za-z0-9_]+)*$", "max": 120},
	"moments": {"type": "shape"},
}
const PARAM_KEYS: Array = ["name", "file", "path", "min", "max", "step", "label"]
const PARAM_NAME_RE: String = "^[a-z][a-z0-9_]*$"
const PARAM_FILE_RE: String = "^data/[A-Za-z0-9_/]+\\.json$"
const PARAM_PATH_RE: String = "^[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)*$"
const MOMENT_NAME_RE: String = "^[a-z][a-z0-9_]*$"
const MOMENT_EVENT_RE: String = "^[A-Za-z][A-Za-z0-9_.]*$"
const MAX_PARAMS: int = 64
const MAX_MOMENTS: int = 32


## Normalises a pack location to an absolute directory without a trailing slash ("" when it does not exist).
static func resolve_dir(pack: String) -> String:
	var p: String = pack.replace("\\", "/")
	if p.begins_with("res://") or p.begins_with("user://"):
		p = ProjectSettings.globalize_path(p)
	p = p.simplify_path()
	while p.ends_with("/"):
		p = p.substr(0, p.length() - 1)
	if p.is_empty() or not p.is_absolute_path() or not DirAccess.dir_exists_absolute(p):
		return ""
	return p


## Returns {ok: bool, manifest: Dictionary, errors: [{kind, file, line?, message}]}.
static func read(pack_dir: String) -> Dictionary:
	var errors: Array = []
	var path: String = pack_dir + "/pack.json"
	if not FileAccess.file_exists(path):
		errors.append({"kind": "schema", "file": "pack.json", "message": "pack.json not found in " + pack_dir})
		return {"ok": false, "manifest": {}, "errors": errors}
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		errors.append({"kind": "schema", "file": "pack.json", "line": json.get_error_line() + 1,
			"message": "not valid JSON: " + json.get_error_message()})
		return {"ok": false, "manifest": {}, "errors": errors}
	if typeof(json.data) != TYPE_DICTIONARY:
		errors.append({"kind": "schema", "file": "pack.json", "message": "top level must be an object"})
		return {"ok": false, "manifest": {}, "errors": errors}
	var m: Dictionary = json.data
	for key: Variant in m.keys():
		if not KEYS.has(key):
			errors.append({"kind": "schema", "file": "pack.json", "line": _line_of(text, str(key)),
				"message": "unknown key '%s' (unknown keys are errors)" % str(key)})
	for key: String in KEYS.keys():
		var rule: Dictionary = KEYS[key]
		if not m.has(key):
			if rule.get("required", false):
				errors.append({"kind": "schema", "file": "pack.json", "message": "missing required key '%s'" % key})
			continue
		var v: Variant = m[key]
		var line: int = _line_of(text, key)
		if v == null:
			errors.append({"kind": "schema", "file": "pack.json", "line": line,
				"message": "'%s' is null (an absent value is an omitted key, never null)" % key})
			continue
		if rule["type"] == "shape":
			_check_shape(key, v, line, errors)
		elif rule["type"] == "string":
			if typeof(v) != TYPE_STRING:
				errors.append({"kind": "schema", "file": "pack.json", "line": line, "message": "'%s' must be a string" % key})
				continue
			_check_string(key, v, rule, line, errors)
		else:
			if typeof(v) != TYPE_ARRAY:
				errors.append({"kind": "schema", "file": "pack.json", "line": line, "message": "'%s' must be an array" % key})
				continue
			var arr: Array = v
			if arr.size() < int(rule.get("min_items", 0)):
				errors.append({"kind": "schema", "file": "pack.json", "line": line,
					"message": "'%s' needs at least %d item(s)" % [key, int(rule["min_items"])]})
			var seen: Dictionary = {}
			for item: Variant in arr:
				if typeof(item) != TYPE_STRING:
					errors.append({"kind": "schema", "file": "pack.json", "line": line,
						"message": "'%s' items must be strings" % key})
					continue
				if rule.has("enum") and not (rule["enum"] as Array).has(item):
					errors.append({"kind": "schema", "file": "pack.json", "line": line,
						"message": "'%s': '%s' is not one of %s" % [key, item, ", ".join(PackedStringArray(rule["enum"]))]})
				if rule.get("unique", false) and seen.has(item):
					errors.append({"kind": "schema", "file": "pack.json", "line": line,
						"message": "'%s': duplicate item '%s'" % [key, item]})
				seen[item] = true
				_check_string(key + "[]", item, rule, line, errors)
	if errors.is_empty() and not api_compatible(str(m["kernelApi"])):
		errors.append({"kind": "schema", "file": "pack.json", "line": _line_of(text, "kernelApi"),
			"message": "kernelApi '%s' cannot run on this kernel, which offers API %s: %s" % [str(m["kernelApi"]), KERNEL_API, api_reason(str(m["kernelApi"]))]})
	return {"ok": errors.is_empty(), "manifest": m, "errors": errors}


## A pack runs when its major equals the kernel's and its minor is not greater ("0.1" is read as "1.0", see LEGACY_API).
static func api_compatible(v: String) -> bool:
	return api_reason(v).is_empty()


## "" when a pack built against API `v` runs on this kernel; otherwise the reason, for the manifest error.
static func api_reason(v: String) -> String:
	var a: PackedStringArray = str(LEGACY_API.get(v, v)).split(".")
	var b: PackedStringArray = KERNEL_API.split(".")
	if a.size() != 2 or not a[0].is_valid_int() or not a[1].is_valid_int():
		return "kernelApi is written major.minor"
	if int(a[0]) != int(b[0]):
		return "the pack was built for major version %d and this kernel is major version %d (a new major removes or changes signatures)" % [int(a[0]), int(b[0])]
	if int(a[1]) > int(b[1]):
		return "the pack needs minor version %d and this kernel has %d (the pack uses additions this kernel does not have yet)" % [int(a[1]), int(b[1])]
	return ""


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func _is_whole(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and float(v) == floorf(float(v)))


static func _matches(v: Variant, pattern: String) -> bool:
	return typeof(v) == TYPE_STRING and RegEx.create_from_string(pattern).search(str(v)) != null


## Exact key set of an object inside an optional field; every difference is one error.
static func _keys(d: Dictionary, required: Array, allowed: Array, where: String, line: int, errors: Array) -> bool:
	var ok: bool = true
	for k: String in required:
		if not d.has(k):
			errors.append({"kind": "schema", "file": "pack.json", "line": line, "message": "%s: missing key '%s'" % [where, k]})
			ok = false
	for k: Variant in d.keys():
		if not allowed.has(k):
			errors.append({"kind": "schema", "file": "pack.json", "line": line, "message": "%s: unknown key '%s'" % [where, str(k)]})
			ok = false
	return ok


## Shape checks of `footprint`, `params` and `moments` (contracts/PACK.md, amendments of 2026-11-11).
static func _check_shape(key: String, v: Variant, line: int, errors: Array) -> void:
	var bad: Callable = func(message: String) -> void:
		errors.append({"kind": "schema", "file": "pack.json", "line": line, "message": message})
	if key == "footprint":
		if typeof(v) != TYPE_DICTIONARY:
			bad.call("'footprint' must be an object {\"size_m\": [x, z], \"height_m\": h}")
			return
		var fp: Dictionary = v
		if not _keys(fp, ["size_m", "height_m"], ["size_m", "height_m"], "footprint", line, errors):
			return
		var size: Variant = fp["size_m"]
		if typeof(size) != TYPE_ARRAY or (size as Array).size() != 2 or not _is_num(size[0]) or not _is_num(size[1]) \
				or float(size[0]) <= 0.0 or float(size[1]) <= 0.0:
			bad.call("footprint.size_m must be [x, z]: two numbers above 0, in metres")
		if not _is_num(fp["height_m"]) or float(fp["height_m"]) <= 0.0:
			bad.call("footprint.height_m must be a number above 0, in metres")
	elif key == "params":
		if typeof(v) != TYPE_ARRAY:
			bad.call("'params' must be an array of {name, file, path, min, max, step, label}")
			return
		var arr: Array = v
		if arr.size() > MAX_PARAMS:
			bad.call("'params' has %d entries; at most %d" % [arr.size(), MAX_PARAMS])
		var names: Dictionary = {}
		for i: int in arr.size():
			var where: String = "params[%d]" % i
			if typeof(arr[i]) != TYPE_DICTIONARY:
				bad.call("%s must be an object" % where)
				continue
			var p: Dictionary = arr[i]
			if not _keys(p, PARAM_KEYS, PARAM_KEYS, where, line, errors):
				continue
			if not _matches(p["name"], PARAM_NAME_RE):
				bad.call("%s.name must match %s" % [where, PARAM_NAME_RE])
			elif names.has(p["name"]):
				bad.call("%s.name: '%s' twice" % [where, str(p["name"])])
			names[p["name"]] = true
			if not _matches(p["file"], PARAM_FILE_RE) or str(p["file"]).contains(".."):
				bad.call("%s.file must be a JSON file under data/ (%s)" % [where, PARAM_FILE_RE])
			if not _matches(p["path"], PARAM_PATH_RE):
				bad.call("%s.path must be a dotted path such as ball.speed" % where)
			if typeof(p["label"]) != TYPE_STRING or str(p["label"]).is_empty() or str(p["label"]).length() > 40:
				bad.call("%s.label must be a string of 1 to 40 characters" % where)
			if not _is_num(p["min"]) or not _is_num(p["max"]) or not _is_num(p["step"]):
				bad.call("%s: min, max and step must be numbers" % where)
			else:
				if float(p["min"]) >= float(p["max"]):
					bad.call("%s: min must be below max" % where)
				if float(p["step"]) <= 0.0:
					bad.call("%s: step must be above 0" % where)
	elif key == "moments":
		if typeof(v) != TYPE_ARRAY:
			bad.call("'moments' must be an array of {name, frame} or {name, event}")
			return
		var arr2: Array = v
		if arr2.size() > MAX_MOMENTS:
			bad.call("'moments' has %d entries; at most %d" % [arr2.size(), MAX_MOMENTS])
		var seen: Dictionary = {}
		for i: int in arr2.size():
			var where2: String = "moments[%d]" % i
			if typeof(arr2[i]) != TYPE_DICTIONARY:
				bad.call("%s must be an object" % where2)
				continue
			var mo: Dictionary = arr2[i]
			if not _keys(mo, ["name"], ["name", "frame", "event"], where2, line, errors):
				continue
			if not _matches(mo["name"], MOMENT_NAME_RE):
				bad.call("%s.name must match %s" % [where2, MOMENT_NAME_RE])
			elif seen.has(mo["name"]):
				bad.call("%s.name: '%s' twice" % [where2, str(mo["name"])])
			seen[mo["name"]] = true
			if mo.has("frame") == mo.has("event"):
				bad.call("%s needs exactly one of 'frame' and 'event'" % where2)
			elif mo.has("frame") and (not _is_whole(mo["frame"]) or float(mo["frame"]) < 0.0):
				bad.call("%s.frame must be a whole number, 0 or above" % where2)
			elif mo.has("event") and not _matches(mo["event"], MOMENT_EVENT_RE):
				bad.call("%s.event must match %s" % [where2, MOMENT_EVENT_RE])


static func _check_string(key: String, v: String, rule: Dictionary, line: int, errors: Array) -> void:
	if rule.has("pattern"):
		var re: RegEx = RegEx.create_from_string(rule["pattern"])
		if re.search(v) == null:
			errors.append({"kind": "schema", "file": "pack.json", "line": line,
				"message": "'%s': '%s' does not match %s" % [key, v, rule["pattern"]]})
	if rule.has("min") and v.length() < int(rule["min"]):
		errors.append({"kind": "schema", "file": "pack.json", "line": line, "message": "'%s' is too short" % key})
	if rule.has("max") and v.length() > int(rule["max"]):
		errors.append({"kind": "schema", "file": "pack.json", "line": line,
			"message": "'%s' is longer than %d characters" % [key, int(rule["max"])]})


static func _line_of(text: String, key: String) -> int:
	var at: int = text.find("\"" + key + "\"")
	if at < 0:
		return 1
	return text.count("\n", 0, at) + 1 if at > 0 else 1
