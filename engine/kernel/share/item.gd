extends RefCounted
## A shareable item: the card (`item.json`, schema tl.item/1), the computed tier, the content hash and the limits.
## Spec: docs/SHARING.md sections 1 to 3; the reading of it that was built is kernel/share/SHARE.md.
## Everything works on a file set {relative path: PackedByteArray}, so a folder and an archive are judged by the same
## code. Nothing here loads or runs a file of the item. No global class names are used.

const Lint: GDScript = preload("res://kernel/runner/lint.gd")
const Manifest: GDScript = preload("res://kernel/runner/manifest.gd")
const Zip: GDScript = preload("res://kernel/share/tlzip.gd")

const SCHEMA: String = "tl.item/1"
const CARD: String = "item.json"
const KINDS: Array = ["game", "venue", "look", "tuning", "kit", "world"]
## The tier each kind must compute to (SHARING.md section 1). A venue that holds a script is not a venue.
const KIND_TIER: Dictionary = {"game": "code", "kit": "code", "venue": "data", "look": "data", "tuning": "data", "world": "data"}
const UID_ALPHABET: String = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const KEYS: Array = ["schema", "uid", "kind", "tier", "title", "summary", "description", "tags", "version", "created",
	"updated", "author", "licence", "engine", "capabilities", "footprint", "requires", "provenance", "verify", "content",
	"preview"]

const ARCHIVE_MAX: int = 8000000        # an archive stays under 8 MB
const THUMB_MAX: int = 1000000          # a preview picture stays under 1 MB
const MAX_FILES: int = 512
const MAX_SHOTS: int = 8
const VERBS: Array = ["lint", "smoke", "invariants", "bot"]

const RE_UID: String = "^[0-9A-HJKMNP-TV-Z]{26}$"
const RE_SEMVER: String = "^\\d+\\.\\d+\\.\\d+$"
const RE_TIME: String = "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$"
const RE_HASH: String = "^sha256:[0-9a-f]{64}$"
const RE_TAG: String = "^[a-z0-9][a-z0-9-]{0,31}$"
const RE_HANDLE: String = "^[a-z0-9][a-z0-9_-]{0,31}$"
const RE_LICENCE: String = "^[A-Za-z0-9][A-Za-z0-9.+-]{0,63}$"
const RE_API: String = "^\\d+\\.\\d+$"
const RE_VERSION_OR_EMPTY: String = "^(\\d+\\.\\d+(\\.\\d+)?)?$"
const RE_HEX_OR_EMPTY: String = "^([0-9a-f]{8,64})?$"
const RE_PREVIEW: String = "^preview/[A-Za-z0-9_.-]+\\.(png|jpg|jpeg|webp)$"
## What may never be in a card: an e-mail address, a machine path, a web address with an account in it.
const PRIVATE: Array = [
	["[^\\s@]+@[^\\s@]+\\.[A-Za-z]{2,}", "an e-mail address"],
	["(?<![A-Za-z])[A-Za-z]:[\\\\/]", "a machine path (drive letter)"],
	["\\\\\\\\[^\\s\\\\]", "a machine path (network share)"],
	["(?i)(^|[\\s\"'(=:])/(home|users|root|mnt|var|etc|tmp|opt|usr)/", "a machine path"],
	["(?i)[\\\\/]users[\\\\/]", "a machine path (user folder)"],
	["(?i)\\b(file|res|user)://", "a machine or engine path"],
]


# ------------------------------------------------------------------------------------------------- file sets
## Reads a folder into a file set. Engine and version-tool sidecars (Lint.file_class "ignored") are not part of an item.
## Returns {ok, files: {path: bytes}, errors: [String]}.
static func read_dir(dir: String) -> Dictionary:
	var errors: Array = []
	var files: Dictionary = {}
	var rels: Array = []
	Lint.list_all(dir, "", rels)
	var total: int = 0
	for rel: String in rels:
		if Lint.file_class(rel) == "ignored":
			continue
		var why: String = Zip.path_problem(rel)
		if not why.is_empty():
			errors.append("%s: %s" % [rel, why])
			continue
		var f: FileAccess = FileAccess.open(dir + "/" + rel, FileAccess.READ)
		if f == null:
			errors.append("%s: cannot be read" % rel)
			continue
		var size: int = f.get_length()
		total += size
		if total > ARCHIVE_MAX * 2:
			errors.append("the folder holds more than %d bytes: too large to be an item" % (ARCHIVE_MAX * 2))
			return {"ok": false, "files": {}, "errors": errors}
		files[rel] = f.get_buffer(size)
		f.close()
	if files.size() > MAX_FILES + 1:
		errors.append("%d files; an item holds at most %d" % [files.size(), MAX_FILES])
	return {"ok": errors.is_empty(), "files": files, "errors": errors}


## Reads a `.tlitem` archive as hostile input into a file set. Returns {ok, files, errors, archive_bytes}.
static func read_archive(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "files": {}, "errors": ["cannot open %s" % path.get_file()], "archive_bytes": 0}
	var size: int = f.get_length()
	if size > ARCHIVE_MAX:
		return {"ok": false, "files": {}, "errors": ["the archive has %d bytes; the limit is %d" % [size, ARCHIVE_MAX]], "archive_bytes": size}
	var buf: PackedByteArray = f.get_buffer(size)
	f.close()
	var r: Dictionary = Zip.read(buf, {"max_archive": ARCHIVE_MAX, "max_files": MAX_FILES + 1,
		"max_file": ARCHIVE_MAX, "max_total": ARCHIVE_MAX * 2})
	r["archive_bytes"] = size
	if r["ok"]:
		for p: String in (r["files"] as Dictionary).keys():
			if Lint.file_class(p) == "ignored":
				r["ok"] = false
				(r["errors"] as Array).append("entry '%s': engine and version-tool sidecars are never part of an item" % p)
	return r


# ------------------------------------------------------------------------------------------------- tier, hash, limits
## "" when the file is inert; otherwise why it makes the item `code`. The rule is written out in SHARE.md.
static func code_reason(rel: String, data: PackedByteArray) -> String:
	var cls: String = Lint.file_class(rel)
	if cls == "script":
		return "a GDScript file"
	if cls != "inert":
		var ext: String = rel.get_file().get_extension().to_lower() if rel.get_file().contains(".") else ""
		return "not an inert file type (%s)" % ("no extension" if ext.is_empty() else "." + ext)
	if rel == "pack.json":
		return "a pack manifest: a pack names an entry script"
	var ext2: String = rel.get_extension().to_lower()
	if ext2 == "png":
		if data.size() < 8 or data.slice(0, 8) != PackedByteArray([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]):
			return "named .png but not a PNG picture"
	elif ext2 == "jpg" or ext2 == "jpeg":
		if data.size() < 3 or data[0] != 0xff or data[1] != 0xd8 or data[2] != 0xff:
			return "named .%s but not a JPEG picture" % ext2
	elif ext2 == "webp":
		if data.size() < 12 or data.slice(0, 4).get_string_from_ascii() != "RIFF" or data.slice(8, 12).get_string_from_ascii() != "WEBP":
			return "named .webp but not a WebP picture"
	else:
		if data.has(0):
			return "named .%s but holds binary data" % ext2
		if ext2 == "json":
			var text: String = data.get_string_from_utf8()
			if text.is_empty() and not data.is_empty():
				return "named .json but not UTF-8 text"
			var j: JSON = JSON.new()
			if j.parse(text) != OK:
				return "named .json but not valid JSON"
	return ""


static func _count_lines(data: PackedByteArray) -> int:
	if data.is_empty():
		return 0
	var n: int = data.count(10)
	return n if data[data.size() - 1] == 10 else n + 1


## Everything that can be computed from the contents alone. The card (item.json) is never part of it.
## Returns {tier, code_reasons: [String], hash, files, bytes, script_lines, data_bytes, errors: [String]}.
static func analyse(files: Dictionary) -> Dictionary:
	var paths: Array = files.keys()
	paths.erase(CARD)
	paths.sort()
	var reasons: Array = []
	var errors: Array = []
	var listing: PackedStringArray = PackedStringArray()
	var total: int = 0
	var script_lines: int = 0
	var data_bytes: int = 0
	var lower: Dictionary = {}
	for p: String in paths:
		var data: PackedByteArray = files[p]
		var why: String = Zip.path_problem(p)
		if not why.is_empty():
			errors.append("%s: %s" % [p, why])
		if lower.has(p.to_lower()):
			errors.append("%s: the same path twice (names differing only in case count as the same)" % p)
		lower[p.to_lower()] = true
		var ctx: HashingContext = HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		if not data.is_empty():
			ctx.update(data)
		listing.append("%s\t%d\t%s\n" % [p, data.size(), ctx.finish().hex_encode()])
		total += data.size()
		var reason: String = code_reason(p, data)
		if not reason.is_empty():
			reasons.append("%s: %s" % [p, reason])
		# ---- limits: the pack limits that exist, applied to any item
		if Lint.file_class(p) == "script":
			var n: int = _count_lines(data)
			script_lines += n
			if n > int(Lint.MAX_SCRIPT_LINES):
				errors.append("%s: %d lines; one script may have at most %d" % [p, n, int(Lint.MAX_SCRIPT_LINES)])
		elif p.begins_with("preview/"):
			if data.size() >= THUMB_MAX:
				errors.append("%s: %d bytes; a preview picture stays under %d" % [p, data.size(), THUMB_MAX])
		else:
			data_bytes += data.size()
	if script_lines > int(Lint.MAX_PACK_LINES):
		errors.append("%d lines of GDScript; an item may have at most %d" % [script_lines, int(Lint.MAX_PACK_LINES)])
	if data_bytes > int(Lint.MAX_DATA_BYTES):
		errors.append("%d bytes of data; an item may have at most %d" % [data_bytes, int(Lint.MAX_DATA_BYTES)])
	if paths.size() > MAX_FILES:
		errors.append("%d files; an item holds at most %d" % [paths.size(), MAX_FILES])
	var h: HashingContext = HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	var text: PackedByteArray = "".join(listing).to_utf8_buffer()
	if not text.is_empty():
		h.update(text)
	return {"tier": "data" if reasons.is_empty() else "code", "code_reasons": reasons,
		"hash": "sha256:" + h.finish().hex_encode(), "files": paths.size(), "bytes": total,
		"script_lines": script_lines, "data_bytes": data_bytes, "errors": errors}


# ------------------------------------------------------------------------------------------------- the card
static func new_uid() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(26)
	var s: String = ""
	for b: int in bytes:
		s += UID_ALPHABET[b & 31]
	return s


static func now_utc() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


static func parse_json(data: PackedByteArray) -> Dictionary:
	var j: JSON = JSON.new()
	if j.parse(data.get_string_from_utf8()) != OK:
		return {"ok": false, "error": "not valid JSON (line %d: %s)" % [j.get_error_line() + 1, j.get_error_message()], "data": null}
	return {"ok": true, "error": "", "data": j.data}


static func _is_int(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and float(v) == floorf(float(v)) and absf(float(v)) < 9.0e15)


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func _str(d: Dictionary, key: String, where: String, re: String, max_len: int, errs: Array) -> void:
	var v: Variant = d.get(key)
	if typeof(v) != TYPE_STRING:
		errs.append("%s%s must be a string" % [where, key])
		return
	var s: String = v
	if s.length() > max_len:
		errs.append("%s%s is longer than %d characters" % [where, key, max_len])
	if not re.is_empty() and RegEx.create_from_string(re).search(s) == null:
		errs.append("%s%s: '%s' does not match %s" % [where, key, s.left(60), re])


## True when `v` is an object with exactly `keys`; each difference is reported.
static func _obj(v: Variant, keys: Array, where: String, errs: Array) -> bool:
	if typeof(v) != TYPE_DICTIONARY:
		errs.append("%s must be an object" % where)
		return false
	var d: Dictionary = v
	var ok: bool = true
	for k: String in keys:
		if not d.has(k):
			errs.append("%s: key '%s' is missing (a key is never left out; an absent value is \"\", [] or null)" % [where, k])
			ok = false
	for k: Variant in d.keys():
		if not keys.has(k):
			errs.append("%s: unknown key '%s'" % [where, str(k)])
			ok = false
	return ok


static func _str_list(v: Variant, where: String, re: String, max_items: int, errs: Array) -> void:
	if typeof(v) != TYPE_ARRAY:
		errs.append("%s must be a list" % where)
		return
	var arr: Array = v
	if arr.size() > max_items:
		errs.append("%s has more than %d entries" % [where, max_items])
	var seen: Dictionary = {}
	var rx: RegEx = RegEx.create_from_string(re) if not re.is_empty() else null
	for it: Variant in arr:
		if typeof(it) != TYPE_STRING:
			errs.append("%s: every entry must be a string" % where)
			continue
		if seen.has(it):
			errs.append("%s: '%s' twice" % [where, str(it)])
		seen[it] = true
		if rx != null and rx.search(str(it)) == null:
			errs.append("%s: '%s' does not match %s" % [where, str(it).left(60), re])


static func _private(v: Variant, where: String, errs: Array) -> void:
	match typeof(v):
		TYPE_STRING:
			for row: Array in PRIVATE:
				if RegEx.create_from_string(row[0]).search(str(v)) != null:
					errs.append("%s holds %s; a card never carries one" % [where, row[1]])
		TYPE_DICTIONARY:
			for k: Variant in (v as Dictionary).keys():
				_private((v as Dictionary)[k], where + "." + str(k) if not where.is_empty() else str(k), errs)
		TYPE_ARRAY:
			for i: int in (v as Array).size():
				_private((v as Array)[i], "%s[%d]" % [where, i], errs)


## Shape check of a card. Returns readable errors; empty when the card is a valid tl.item/1.
static func validate_card(card: Variant) -> Array:
	var errs: Array = []
	if typeof(card) != TYPE_DICTIONARY:
		return ["the card must be a JSON object"]
	var c: Dictionary = card
	if c.has("signature"):
		errs.append("'signature' is reserved for the store step and does not exist before it")
	for k: Variant in c.keys():
		if not KEYS.has(k) and str(k) != "signature":
			errs.append("unknown key '%s'" % str(k))
	for k: String in KEYS:
		if not c.has(k):
			errs.append("key '%s' is missing (a key is never left out; an absent value is \"\", [] or null)" % k)
	if not errs.is_empty():
		return errs
	if typeof(c["schema"]) != TYPE_STRING or str(c["schema"]) != SCHEMA:
		errs.append("schema must be \"%s\"" % SCHEMA)
	_str(c, "uid", "", RE_UID, 26, errs)
	if typeof(c["kind"]) != TYPE_STRING or not KINDS.has(c["kind"]):
		errs.append("kind must be one of %s" % ", ".join(PackedStringArray(KINDS)))
	if typeof(c["tier"]) != TYPE_STRING or not ["data", "code"].has(c["tier"]):
		errs.append("tier must be \"data\" or \"code\"")
	_str(c, "title", "", "", 80, errs)
	if typeof(c["title"]) == TYPE_STRING and str(c["title"]).strip_edges().is_empty():
		errs.append("title is empty")
	_str(c, "summary", "", "", 200, errs)
	_str(c, "description", "", "", 5000, errs)
	_str_list(c["tags"], "tags", RE_TAG, 16, errs)
	_str(c, "version", "", RE_SEMVER, 32, errs)
	_str(c, "created", "", RE_TIME, 20, errs)
	_str(c, "updated", "", RE_TIME, 20, errs)
	if _obj(c["author"], ["handle", "name"], "author", errs):
		_str(c["author"], "handle", "author.", RE_HANDLE, 32, errs)
		_str(c["author"], "name", "author.", "", 60, errs)
	_str(c, "licence", "", RE_LICENCE, 64, errs)
	if _obj(c["engine"], ["kernelApi", "kit", "style"], "engine", errs):
		_str(c["engine"], "kernelApi", "engine.", RE_API, 16, errs)
		_str(c["engine"], "kit", "engine.", RE_VERSION_OR_EMPTY, 16, errs)
		_str(c["engine"], "style", "engine.", RE_VERSION_OR_EMPTY, 16, errs)
	_str_list(c["capabilities"], "capabilities", "", 32, errs)
	if typeof(c["capabilities"]) == TYPE_ARRAY:
		var caps: Array = c["capabilities"]
		var sorted: Array = caps.duplicate()
		sorted.sort()
		if sorted != caps:
			errs.append("capabilities must be sorted")
		for cap: Variant in caps:
			if not (Manifest.CAPABILITIES as Array).has(cap):
				errs.append("capabilities: '%s' is not a kernel capability" % str(cap))
	if _obj(c["footprint"], ["size_m", "height_m"], "footprint", errs):
		var fp: Dictionary = c["footprint"]
		var size_ok: bool = typeof(fp["size_m"]) == TYPE_ARRAY and ((fp["size_m"] as Array).is_empty() or (fp["size_m"] as Array).size() == 2)
		if size_ok:
			for n: Variant in fp["size_m"]:
				if not _is_num(n) or float(n) <= 0.0:
					size_ok = false
		if not size_ok:
			errs.append("footprint.size_m must be [] (unknown) or [x, z] in metres, both above 0")
		if not _is_num(fp["height_m"]) or float(fp["height_m"]) < 0.0:
			errs.append("footprint.height_m must be a number, 0 when unknown")
	_str_list(c["requires"], "requires", "", 32, errs)
	if _obj(c["provenance"], ["built_by", "job", "sentence", "models", "human_code", "parent"], "provenance", errs):
		var pv: Dictionary = c["provenance"]
		_str(pv, "built_by", "provenance.", "", 40, errs)
		_str(pv, "job", "provenance.", "", 120, errs)
		_str(pv, "sentence", "provenance.", "", 2000, errs)
		_str_list(pv["models"], "provenance.models", "", 16, errs)
		if pv["human_code"] != null and typeof(pv["human_code"]) != TYPE_BOOL:
			errs.append("provenance.human_code must be true, false or null (unknown)")
		if pv["parent"] != null:
			if _obj(pv["parent"], ["uid", "version", "hash"], "provenance.parent", errs):
				_str(pv["parent"], "uid", "provenance.parent.", RE_UID, 26, errs)
				_str(pv["parent"], "version", "provenance.parent.", RE_SEMVER, 32, errs)
				_str(pv["parent"], "hash", "provenance.parent.", RE_HASH, 80, errs)
	if _obj(c["verify"], ["report", "verbs", "bot_state_hash", "bypasses", "script_lines"], "verify", errs):
		var vf: Dictionary = c["verify"]
		_str(vf, "report", "verify.", "^(tl\\.verify/1)?$", 16, errs)
		if _obj(vf["verbs"], VERBS, "verify.verbs", errs):
			for verb: String in VERBS:
				if vf["verbs"][verb] != null and typeof(vf["verbs"][verb]) != TYPE_BOOL:
					errs.append("verify.verbs.%s must be true, false or null (not run)" % verb)
		_str(vf, "bot_state_hash", "verify.", RE_HEX_OR_EMPTY, 64, errs)
		for key: String in ["bypasses", "script_lines"]:
			if vf[key] != null and (not _is_int(vf[key]) or float(vf[key]) < 0.0):
				errs.append("verify.%s must be a whole number or null (unknown)" % key)
	if _obj(c["content"], ["hash", "files", "bytes"], "content", errs):
		_str(c["content"], "hash", "content.", RE_HASH, 80, errs)
		for key: String in ["files", "bytes"]:
			if not _is_int(c["content"][key]) or float(c["content"][key]) < 0.0:
				errs.append("content.%s must be a whole number" % key)
	if _obj(c["preview"], ["thumb", "shots"], "preview", errs):
		_str(c["preview"], "thumb", "preview.", "^(preview/[A-Za-z0-9_.-]+\\.(png|jpg|jpeg|webp))?$", 120, errs)
		_str_list(c["preview"]["shots"], "preview.shots", RE_PREVIEW, MAX_SHOTS, errs)
	_private(c, "", errs)
	return errs


## The card as text: the spec's key order, two-space indent, whole numbers without a fraction, one trailing newline.
static func card_text(card: Dictionary) -> String:
	return _json(card, 0) + "\n"


static func _json(v: Variant, depth: int) -> String:
	var pad: String = "  ".repeat(depth + 1)
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return str(int(v)) if _is_int(v) else JSON.stringify(v)
		TYPE_STRING:
			return JSON.stringify(v)
		TYPE_ARRAY:
			var arr: Array = v
			if arr.is_empty():
				return "[]"
			var parts: PackedStringArray = PackedStringArray()
			for it: Variant in arr:
				parts.append(_json(it, depth))
			return "[" + ", ".join(parts) + "]"
		TYPE_DICTIONARY:
			var d: Dictionary = v
			if d.is_empty():
				return "{}"
			var rows: PackedStringArray = PackedStringArray()
			for k: Variant in d.keys():
				rows.append(pad + JSON.stringify(str(k)) + ": " + _json(d[k], depth + 1))
			return "{\n" + ",\n".join(rows) + "\n" + "  ".repeat(depth) + "}"
	return JSON.stringify(str(v))


static func _blank_card() -> Dictionary:
	return {
		"schema": SCHEMA, "uid": "", "kind": "", "tier": "", "title": "", "summary": "", "description": "",
		"tags": [], "version": "0.1.0", "created": "", "updated": "",
		"author": {"handle": "player", "name": ""},
		"licence": "all-rights-reserved",
		"engine": {"kernelApi": str(Manifest.KERNEL_API), "kit": "", "style": ""},
		"capabilities": [],
		"footprint": {"size_m": [], "height_m": 0},
		"requires": [],
		"provenance": {"built_by": "", "job": "", "sentence": "", "models": [], "human_code": null, "parent": null},
		"verify": {"report": "", "verbs": {"lint": null, "smoke": null, "invariants": null, "bot": null},
			"bot_state_hash": "", "bypasses": null, "script_lines": null},
		"content": {"hash": "", "files": 0, "bytes": 0},
		"preview": {"thumb": "", "shots": []},
	}


static func _guess_kind(files: Dictionary) -> String:
	if files.has("pack.json"):
		return "game"
	var found: Dictionary = {}
	for p: String in files.keys():
		if p == CARD or p.get_extension().to_lower() != "json":
			continue
		var pj: Dictionary = parse_json(files[p])
		if pj["ok"] and typeof(pj["data"]) == TYPE_DICTIONARY:
			var schema: String = str((pj["data"] as Dictionary).get("schema", ""))
			if schema.begins_with("tl.layout/"):
				found["venue"] = true
			elif schema.begins_with("tl.world/"):
				found["world"] = true
			elif schema.begins_with("tl.style/"):
				found["look"] = true
			elif schema.begins_with("tl.tuning/"):
				found["tuning"] = true
	return str(found.keys()[0]) if found.size() == 1 else ""


## Makes or refreshes the card of the item in `files` (the folder's file set, read by the caller).
## `opts`: kind, title, summary, description, tags, handle, name, licence, version (strings from the command line);
## lint, bot, smoke, invariants (parsed tl.verify/1 reports); job_lines (the lines of a job's job.jsonl), job_name.
## What is not known stays "", [] or null. Returns {ok, card, errors: [String], notes: [String]}.
static func build_card(files: Dictionary, opts: Dictionary) -> Dictionary:
	var notes: Array = []
	var errors: Array = []
	var card: Dictionary = _blank_card()
	var old: Dictionary = {}
	if files.has(CARD):
		var pj: Dictionary = parse_json(files[CARD])
		if pj["ok"] and validate_card(pj["data"]).is_empty():
			old = pj["data"]
		else:
			errors.append("the existing item.json is not a valid card; repair or remove it first (its uid must not be lost by accident)")
			return {"ok": false, "card": {}, "errors": errors, "notes": notes}
	var a: Dictionary = analyse(files)
	errors.append_array(a["errors"])
	var now: String = now_utc()
	if old.is_empty():
		card["uid"] = new_uid()
		card["created"] = now
		card["updated"] = now
	else:
		# made once: the uid and the creation time never change; what a person wrote is kept
		for k: String in ["uid", "created", "updated", "kind", "title", "summary", "description", "tags", "version",
				"author", "licence", "provenance", "verify", "preview"]:
			card[k] = old[k]
		if str(old["content"]["hash"]) != str(a["hash"]):
			card["updated"] = now
			# evidence about other bytes is not evidence about these
			card["verify"] = _blank_card()["verify"]
			notes.append("the contents changed since the last card: `updated` set, old `verify` evidence dropped")
	# ---- from pack.json
	var manifest: Dictionary = {}
	if files.has("pack.json"):
		var mj: Dictionary = parse_json(files["pack.json"])
		if not mj["ok"] or typeof(mj["data"]) != TYPE_DICTIONARY:
			errors.append("pack.json: " + str(mj["error"]))
		else:
			manifest = mj["data"]
			card["kind"] = "game" if not old.has("kind") else str(old["kind"])
			card["title"] = str(manifest.get("title", ""))
			card["version"] = str(manifest.get("version", card["version"]))
			card["engine"]["kernelApi"] = str(manifest.get("kernelApi", Manifest.KERNEL_API))
			var caps: Array = []
			if typeof(manifest.get("capabilities")) == TYPE_ARRAY:
				for cap: Variant in manifest["capabilities"]:
					if not caps.has(str(cap)):
						caps.append(str(cap))
			caps.sort()
			card["capabilities"] = caps
			if typeof(manifest.get("requires")) == TYPE_ARRAY:
				card["requires"] = (manifest["requires"] as Array).duplicate()
			if typeof(manifest.get("footprint")) == TYPE_DICTIONARY:
				var fp: Dictionary = manifest["footprint"]
				if typeof(fp.get("size_m")) == TYPE_ARRAY and fp.has("height_m"):
					card["footprint"] = {"size_m": (fp["size_m"] as Array).duplicate(), "height_m": fp["height_m"]}
	elif old.is_empty():
		card["kind"] = _guess_kind(files)
	# ---- from the command line
	for k: String in ["kind", "title", "summary", "description", "licence", "version"]:
		if opts.has(k):
			card[k] = str(opts[k])
	if opts.has("tags"):
		var tags: Array = []
		for t: String in str(opts["tags"]).split(",", false):
			tags.append(t.strip_edges())
		card["tags"] = tags
	if opts.has("handle"):
		card["author"]["handle"] = str(opts["handle"])
	if opts.has("name"):
		card["author"]["name"] = str(opts["name"])
	if str(card["kind"]).is_empty():
		errors.append("the kind cannot be told from the contents; say it: --kind=%s" % "|".join(PackedStringArray(KINDS)))
	if str(card["title"]).is_empty():
		errors.append("no title: give --title=\"...\" (a pack's title comes from pack.json)")
	# ---- computed, never declared
	card["tier"] = a["tier"]
	card["content"] = {"hash": a["hash"], "files": a["files"], "bytes": a["bytes"]}
	var shots: Array = []
	var thumb: String = ""
	var names: Array = files.keys()
	names.sort()
	for p: String in names:
		if p.begins_with("preview/") and RegEx.create_from_string(RE_PREVIEW).search(p) != null:
			if p.get_file().get_basename() == "thumb" and thumb.is_empty():
				thumb = p
			elif shots.size() < MAX_SHOTS:
				shots.append(p)
	card["preview"] = {"thumb": thumb, "shots": shots}
	# ---- evidence: verify reports of this pack, this version
	for verb: String in VERBS:
		if not opts.has(verb):
			continue
		var rep: Dictionary = opts[verb]
		if str(rep.get("schema", "")) != "tl.verify/1" or str(rep.get("verb", "")) != verb:
			errors.append("--%s: not a tl.verify/1 report of the verb '%s'" % [verb, verb])
			continue
		if not manifest.is_empty() and (str(rep.get("pack", "")) != str(manifest.get("id", "")) or str(rep.get("packVersion", "")) != str(manifest.get("version", ""))):
			errors.append("--%s: the report is about %s %s, not about this pack (%s %s)" % [verb, str(rep.get("pack", "?")),
				str(rep.get("packVersion", "?")), str(manifest.get("id", "?")), str(manifest.get("version", "?"))])
			continue
		card["verify"]["report"] = "tl.verify/1"
		card["verify"]["verbs"][verb] = bool(rep.get("ok", false))
		if verb == "lint" and typeof(rep.get("composability")) == TYPE_DICTIONARY:
			var comp: Dictionary = rep["composability"]
			if typeof(comp.get("bypasses")) == TYPE_ARRAY:
				card["verify"]["bypasses"] = (comp["bypasses"] as Array).size()
			if typeof(comp.get("gdscript_lines")) == TYPE_DICTIONARY:
				var total: int = 0
				for part: Variant in (comp["gdscript_lines"] as Dictionary).values():
					total += int(part)
				card["verify"]["script_lines"] = total
		if verb == "bot" and typeof(rep.get("metrics")) == TYPE_DICTIONARY:
			var met: Dictionary = rep["metrics"]
			card["verify"]["bot_state_hash"] = str(met.get("bot_state_hash", met.get("state_hash", "")))
	# ---- provenance: a job's own log, nothing else
	if opts.has("job_lines"):
		var pv: Dictionary = {"built_by": "", "job": "", "sentence": "", "models": [], "human_code": card["provenance"]["human_code"],
			"parent": card["provenance"]["parent"]}
		var models: Array = []
		for line: String in opts["job_lines"]:
			if line.strip_edges().is_empty():
				continue
			var j: JSON = JSON.new()
			if j.parse(line) != OK or typeof(j.data) != TYPE_DICTIONARY:
				continue
			var ev: Dictionary = j.data
			if str(ev.get("type", "")) == "job_created":
				pv["job"] = str(ev.get("job", ""))
				pv["sentence"] = str(ev.get("sentence", ""))
				pv["built_by"] = "foreman"
			elif str(ev.get("type", "")) == "builder_run" and ev.has("model") and not models.has(str(ev["model"])):
				models.append(str(ev["model"]))
		models.sort()
		pv["models"] = models
		if str(pv["job"]).is_empty():
			errors.append("--job: no job_created line in the job's log; provenance left as it was")
		else:
			for k: String in ["job", "sentence"]:
				var leak: Array = []
				_private(pv[k], k, leak)
				if not leak.is_empty():
					notes.append("provenance.%s left empty: the job's log %s" % [k, str(leak[0])])
					pv[k] = ""
			card["provenance"] = pv
	if opts.has("human_code"):
		card["provenance"]["human_code"] = str(opts["human_code"]) == "true"
	errors.append_array(validate_card(card))
	return {"ok": errors.is_empty(), "card": card, "errors": errors, "notes": notes}


# ------------------------------------------------------------------------------------------------- check
## Judges a file set that claims to be an item: the card's shape, then every statement of the card that the contents
## can prove or disprove. Returns {ok, errors: [String], mismatches: [String], card, analysis}.
static func check(files: Dictionary) -> Dictionary:
	var errors: Array = []
	var mismatches: Array = []
	if not files.has(CARD):
		return {"ok": false, "errors": ["no item.json at the root: not an item"], "mismatches": [], "card": {}, "analysis": {}}
	var pj: Dictionary = parse_json(files[CARD])
	if not pj["ok"]:
		return {"ok": false, "errors": ["item.json: " + str(pj["error"])], "mismatches": [], "card": {}, "analysis": {}}
	var shape: Array = validate_card(pj["data"])
	if not shape.is_empty():
		for e: String in shape:
			errors.append("item.json: " + e)
		return {"ok": false, "errors": errors, "mismatches": [], "card": {}, "analysis": {}}
	var card: Dictionary = pj["data"]
	var a: Dictionary = analyse(files)
	errors.append_array(a["errors"])
	if str(card["tier"]) != str(a["tier"]):
		var why: String = ""
		if not (a["code_reasons"] as Array).is_empty():
			why = " (%s%s)" % [str(a["code_reasons"][0]), "" if (a["code_reasons"] as Array).size() == 1 else ", and %d more" % ((a["code_reasons"] as Array).size() - 1)]
		mismatches.append("tier: the card says '%s', the contents are '%s'%s" % [str(card["tier"]), str(a["tier"]), why])
	if str(KIND_TIER[card["kind"]]) != str(a["tier"]):
		mismatches.append("kind: a '%s' is a %s item, the contents are '%s'" % [str(card["kind"]), str(KIND_TIER[card["kind"]]), str(a["tier"])])
	if str(card["content"]["hash"]) != str(a["hash"]):
		mismatches.append("content.hash: the card says %s, the contents give %s" % [str(card["content"]["hash"]), str(a["hash"])])
	if int(card["content"]["files"]) != int(a["files"]):
		mismatches.append("content.files: the card says %d, the contents have %d" % [int(card["content"]["files"]), int(a["files"])])
	if int(card["content"]["bytes"]) != int(a["bytes"]):
		mismatches.append("content.bytes: the card says %d, the contents have %d" % [int(card["content"]["bytes"]), int(a["bytes"])])
	var previews: Array = (card["preview"]["shots"] as Array).duplicate()
	if not str(card["preview"]["thumb"]).is_empty():
		previews.append(card["preview"]["thumb"])
	for p: Variant in previews:
		if not files.has(str(p)):
			mismatches.append("preview: the card names '%s', which is not in the item" % str(p))
	if files.has("pack.json"):
		var mj: Dictionary = parse_json(files["pack.json"])
		if not mj["ok"] or typeof(mj["data"]) != TYPE_DICTIONARY:
			errors.append("pack.json: " + str(mj["error"]))
		else:
			var m: Dictionary = mj["data"]
			var caps: Array = []
			if typeof(m.get("capabilities")) == TYPE_ARRAY:
				for cap: Variant in m["capabilities"]:
					if not caps.has(str(cap)):
						caps.append(str(cap))
			caps.sort()
			if caps != (card["capabilities"] as Array):
				mismatches.append("capabilities: the card says [%s], pack.json grants [%s]" % [", ".join(PackedStringArray(card["capabilities"])), ", ".join(PackedStringArray(caps))])
			if str(m.get("version", "")) != str(card["version"]):
				mismatches.append("version: the card says %s, pack.json says %s" % [str(card["version"]), str(m.get("version", ""))])
			if str(m.get("kernelApi", "")) != str(card["engine"]["kernelApi"]):
				mismatches.append("engine.kernelApi: the card says %s, pack.json says %s" % [str(card["engine"]["kernelApi"]), str(m.get("kernelApi", ""))])
			if not ["game", "kit"].has(card["kind"]):
				mismatches.append("kind: the item holds a pack.json, so it is a game or a kit, not a '%s'" % str(card["kind"]))
	elif not (card["capabilities"] as Array).is_empty():
		mismatches.append("capabilities: the card lists some, but the item holds no pack.json to grant them")
	return {"ok": errors.is_empty() and mismatches.is_empty(), "errors": errors, "mismatches": mismatches, "card": card, "analysis": a}
