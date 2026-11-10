extends RefCounted
## V0: pack.json checks. A hand-written mirror of contracts/pack.schema.json (tl.pack/0.1); unknown keys are errors.
## No global class names are used here: the supervisor loads this before the class cache is known to exist.

const KERNEL_API: String = "0.1"
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
}


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
		if rule["type"] == "string":
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
			"message": "kernelApi '%s' does not match this kernel (%s)" % [str(m["kernelApi"]), KERNEL_API]})
	return {"ok": errors.is_empty(), "manifest": m, "errors": errors}


static func api_compatible(v: String) -> bool:
	return v == KERNEL_API


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
