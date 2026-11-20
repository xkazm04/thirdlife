extends RefCounted
## tl.job/1 (contracts/JOB.md, foreman/src/events.ts). The engine also reads
## exported games without the Foreman installed. A trailing ? means optional,
## and [] checks every array element with the named rule.
## 2026-11-20 (designer v2, JOB.md "Added 2026-11-20"): creativity, run_through, brief.pitch, brief.aspects,
## aspect_reacted, plan_set.phases, phase_done, phase_reviewed. Word limits are part of the shape (`words<=N`). Where the
## contract is silent this mirrors the Foreman's own schema (foreman/data/job-events.schema.json, L2's three narrowings):
## alternative and phase ids are snake_case ids, an alternative id is never keep or drop, a note is never empty.
const BASE := {"v": "version", "seq": "positive", "ts": "utc", "job": "nonempty", "type": "text"}
const EVENTS := {
	"job_created": {"sentence": "nonempty", "packId": "pack_id", "title": "nonempty", "answers": "answers?", "lot": "lot?",
		"creativity": "creativity?", "run_through": "true?"},
	"brief_set": {"brief": "brief", "estimate": "estimate"},
	"brief_approved": {"by": "approver"},
	"plan_set": {"packages": "package[]", "card": "card?", "phases": "phases?"},
	"package_state": {"package": "id", "state": "package_state", "round": "positive", "cause": "cause?", "detail": "text?"},
	"builder_run": {"package": "id?", "round": "positive?", "adapter": "adapter", "mode": "builder_mode", "model": "text", "outcome": "outcome",
		"durationMs": "count", "tokensIn": "count?", "tokensOut": "count?", "tokensCacheRead": "count?", "transcript": "path?"},
	"verify": {"package": "id?", "round": "positive", "level": "level", "verb": "verb", "ok": "bool", "report": "path", "exitCode": "integer?", "after": "id?"},
	"merge": {"package": "id", "files": "path[]", "removed": "path[]?"},
	"note": {"package": "id", "round": "positive", "text": "nonempty"},
	"change_requested": {"decision": "decision?", "text": "nonempty", "package": "id?", "inbox": "nonempty?"},
	"reopened": {"package": "id", "reason": "nonempty"},
	"question": {"package": "id", "text": "nonempty"},
	"answer": {"package": "id", "text": "nonempty", "by": "nonempty", "inbox": "nonempty?"},
	"milestone": {"milestone": "milestone", "captures": "path[]", "summary": "text"},
	"comment": {"milestone": "milestone", "text": "nonempty", "by": "player"},
	"replan": {"reason": "nonempty", "added": "id[]", "removed": "id[]", "changed": "id[]"},
	"budget": {"policy": "policy", "state": "budget_state", "reason": "text"},
	"billing": {"adapter": "adapter", "mode": "billing_mode", "evidence": "nonempty"},
	"promoted": {"packId": "pack_id", "version": "nonempty", "dest": "path"},
	"job_state": {"state": "job_state", "reason": "text?"},
	"aspect_reacted": {"aspect": "id", "choice": "id", "note": "nonempty?"},
	"phase_done": {"phase": "id"},
	"phase_reviewed": {"phase": "id", "verdict": "verdict", "note": "nonempty?", "by": "approver"},
}
const OBJECTS := {
	"lot": {"at": "coordinate_pair", "yaw_deg": "yaw", "radius": "lot_radius"},
	"decision": {"key": "id", "to": "option_id"},
	"brief": {"rules": "nonempty", "arena": "nonempty", "ai": "nonempty", "controls": "nonempty", "mood": "nonempty",
		"pitch": "words<=20?", "aspects": "aspects?"},
	"aspect": {"id": "id", "icon": "icon", "title": "words<=4", "line": "words<=12", "detail": "words<=60",
		"alternatives": "alternatives", "crazy": "true?"},
	"alternative": {"id": "alternative_id", "title": "words<=4", "line": "words<=12"},
	"phase": {"id": "id", "title": "nonempty", "try": "words<=12", "packages": "id[]"},
	"estimate": {"packages": "positive", "wallMinutes": "number", "tokens": "count"},
	"package": {"id": "id", "title": "nonempty", "milestone": "milestone", "deps": "id[]", "scope": "path[]",
		"contract": "nonempty", "acceptance": "acceptance[]", "registers": "registers?"},
	"acceptance": {"level": "level", "verb": "verb", "args": "text[]"},
	"registers": {"capabilities": "capability[]?", "assets": "asset[]?", "tests": "test[]?", "cameras": "id[]?"},
	"policy": {"kind": "budget_kind", "limit": "limit?"},
}
const ENUMS := {
	"approver": ["player", "auto"], "player": ["player"],
	"package_state": ["queued", "running", "blocked", "verifying", "promoted", "failed"],
	"cause": ["verify_failed", "builder_error", "builder_timeout", "builder_truncated", "budget", "dependency", "question",
		"cancelled", "no_visible_change", "kit_regression", "machine_busy"],
	"adapter": ["claude-cli", "messages-api", "fake"], "builder_mode": ["generate", "readonly-scan", "edit"],
	"outcome": ["ok", "timeout", "truncated", "error", "refused"],
	"level": ["V0", "V1", "V2", "V3", "V4", "V5", "V6"], "verb": ["lint", "smoke", "invariants", "bot", "capture"],
	"milestone": ["blockout", "greybox", "art_pass", "tuned"],
	"budget_kind": ["tokens_per_hour", "only_while_playing", "overnight"], "budget_state": ["running", "paused"],
	"billing_mode": ["subscription", "api_key", "none"], "job_state": ["running", "paused", "done", "failed", "cancelled"],
	"creativity": ["crazy"], "verdict": ["pass", "hold"],
	"icon": ["player", "rival", "arena", "goal", "twist", "camera", "power", "time", "crowd", "ball", "vehicle", "weapon", "build",
		"music", "story"],
	"capability": ["physics", "input", "ui", "audio", "vfx", "camera", "rules", "ai", "spawn", "fracture", "vehicle", "biped", "ball", "kit", "style"],
}
const PATTERNS := {
	"option_id": "^[a-z0-9_]+$",
	"alternative_id": "^(?!(keep|drop)$)[a-z][a-z0-9_]*$",   # L2 (foreman/src/events.ts): never keep or drop
	"utc": r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d{1,9})?Z$",
	"id": "^[a-z][a-z0-9_]*$", "pack_id": r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$", "card": r"^card\.[a-z][a-z0-9_]*$",
	"asset": r"^gen/[A-Za-z0-9_/]+\.gd$", "test": r"^tests/[A-Za-z0-9_/]+\.gd$",
	"path": r"^(?![A-Za-z]:|/|\\)(?!.*(^|/)\.\.(/|$))[^\\]+$", "window": r"^\d{1,2}:\d{2}-\d{1,2}:\d{2}$",
}
static var _patterns := {}

static func check(event: Dictionary) -> String:
	var type: Variant = event.get("type")
	if not type is String or not EVENTS.has(type):
		return "missing or unknown event type '%s'" % str(type)
	var why := _object_error(event, BASE.merged(EVENTS[type]), type)
	if not why.is_empty():
		return why
	match type:
		"package_state":
			if event.has("cause") != (event.state in ["failed", "blocked"]):
				return "package_state.cause must be present exactly when failed or blocked"
		"builder_run":
			if event.has("package") != event.has("round"):
				return "builder_run.package and round must be given together"
		"verify":
			if event.has("package") and event.has("after"):
				return "verify.after requires a whole-pack check"
		"plan_set":
			if event.has("phases"):
				return _phases_error(event.phases, event.packages)
		"phase_reviewed":
			if event.verdict == "hold" and str(event.get("note", "")).strip_edges().is_empty():
				return "phase_reviewed.note is required with verdict hold"
		"budget":
			var policy: Dictionary = event.policy
			match policy.kind:
				"only_while_playing":
					if policy.has("limit"):
						return "budget.policy.limit must be omitted for only_while_playing"
				"overnight":
					return _field_error(policy.get("limit"), "window", "budget.policy.limit")
				"tokens_per_hour":
					if policy.has("limit") or event.state != "paused":
						return _field_error(policy.get("limit"), "positive", "budget.policy.limit")
	return ""

## A list of `n_min`..`n_max` objects of one kind whose `id`s are unique (brief.aspects, aspect.alternatives).
const LISTS := {"aspects": ["aspect", 3, 7], "alternatives": ["alternative", 2, 3], "phases": ["phase", 2, 5]}


static func _list_error(value: Variant, rule: String, path: String) -> String:
	var spec: Array = LISTS[rule]
	if not value is Array or value.size() < spec[1] or value.size() > spec[2]:
		return "%s must hold %d to %d entries" % [path, spec[1], spec[2]]
	var seen := {}
	for i in value.size():
		var why := _field_error(value[i], spec[0], "%s[%d]" % [path, i])
		if not why.is_empty():
			return why
		if seen.has(value[i].id):
			return "%s[%d].id '%s' is not unique" % [path, i, value[i].id]
		seen[value[i].id] = true
	return ""


## plan_set.phases: every package of the plan in exactly one phase; a package's deps in its own phase or an earlier one.
static func _phases_error(phases: Array, packages: Array) -> String:
	var phase_of := {}
	for k in phases.size():
		for id: String in phases[k].packages:
			if phase_of.has(id):
				return "plan_set.phases: package '%s' is in two phases" % id
			phase_of[id] = k
	for p: Dictionary in packages:
		if not phase_of.has(p.id):
			return "plan_set.phases: package '%s' is in no phase" % p.id
		for dep: String in p.deps:
			if phase_of.has(dep) and phase_of[dep] > phase_of[p.id]:
				return "plan_set.phases: package '%s' depends on '%s' of a later phase" % [p.id, dep]
	if phase_of.size() != packages.size():
		for id: String in phase_of:
			if not packages.any(func(p: Dictionary) -> bool: return p.id == id):
				return "plan_set.phases: '%s' is not a package of the plan" % id
	return ""


static func _object_error(obj: Dictionary, fields: Dictionary, path: String) -> String:
	for key: String in obj:
		if not fields.has(key):
			return "unknown key '%s.%s'" % [path, key]
	for key: String in fields:
		var rule: String = fields[key]
		if not obj.has(key):
			if rule.ends_with("?"):
				continue
			return "missing key '%s.%s'" % [path, key]
		var why := _field_error(obj[key], rule.trim_suffix("?"), path + "." + key)
		if not why.is_empty():
			return why
	return ""

static func _field_error(value: Variant, rule: String, path: String) -> String:
	if LISTS.has(rule):
		return _list_error(value, rule, path)
	if rule.begins_with("words<="):
		var most := int(rule.substr(7))
		if not value is String or value.strip_edges().is_empty():
			return "%s must be a non-empty string" % path
		var n := word_count(value)
		if n > most:
			return "%s has %d words (at most %d)" % [path, n, most]
		return ""
	if rule == "answers":
		if not value is Dictionary or value.is_empty():
			return "%s must be a non-empty object" % path
		for key in value:
			if not _valid_scalar(key, "id") or not _valid_scalar(value[key], "option_id"):
				return "%s.%s must map a question key to an option id" % [path, key]
		return ""
	if rule == "coordinate_pair":
		if not value is Array or value.size() != 2:
			return "%s must hold two coordinates" % path
		rule = "finite[]"
	if rule.ends_with("[]"):
		if not value is Array:
			return "%s must be an array" % path
		if value.is_empty() and (rule == "package[]" or path.ends_with(".scope") or path.ends_with("].packages")):
			return "%s must have at least one entry" % path
		var item := rule.trim_suffix("[]")
		for i in value.size():
			var why := _field_error(value[i], item, "%s[%d]" % [path, i])
			if not why.is_empty():
				return why
			if item == "capability" and value.find(value[i]) != i:
				return "%s repeats capability '%s'" % [path, value[i]]
		return ""
	if OBJECTS.has(rule):
		if not value is Dictionary:
			return "%s must be an object" % path
		return _object_error(value, OBJECTS[rule], path)
	if _valid_scalar(value, rule):
		return ""
	return "%s has an invalid value (expected %s)" % [path, rule]

static func _valid_scalar(value: Variant, rule: String) -> bool:
	if ENUMS.has(rule):
		return value is String and value in ENUMS[rule]
	if PATTERNS.has(rule):
		if not _patterns.has(rule):
			_patterns[rule] = RegEx.create_from_string(PATTERNS[rule])
		return value is String and _patterns[rule].search(value) != null
	# Godot JSON represents numbers as floats, including integral wire values.
	var number := (value is float or value is int) and is_finite(value)
	match rule:
		"text": return value is String
		"nonempty": return value is String and not value.is_empty()
		"bool": return value is bool
		"true": return value is bool and value == true
		"finite": return number
		"yaw": return number and absf(value) <= 360
		"lot_radius": return number and value >= 12
		"number": return number and value >= 0
		"version": return number and value == 1
		"integer": return number and value == floor(value)
		"count": return number and value >= 0 and value == floor(value)
		"positive": return number and value >= 1 and value == floor(value)
		"limit": return number or value is String   # narrowed by the policy kind above
	return false


## Words as the contract counts them: pieces between white space.
static func word_count(text: String) -> int:
	var n := 0
	for piece in text.replace("	", " ").replace("
", " ").split(" ", false):
		n += 1
	return n
