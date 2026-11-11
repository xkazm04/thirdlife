extends Node
## The item tool's entry (tools/item.sh starts it; it never goes through the runner's host).
##
##   <godot> --headless --path <engine> res://kernel/share/item_tool.tscn -- <command> <target> [--name=value ...]
##
##   card   <dir> [--lint=<report>] [--bot=<report>] [--smoke=<report>] [--invariants=<report>] [--job=<job dir>]
##                [--kind=] [--title=] [--summary=] [--description=] [--tags=a,b] [--handle=] [--name=] [--licence=]
##                [--version=] [--human-code=true|false]        writes <dir>/item.json (keeps uid and created)
##   pack   <dir> --out=<file.tlitem> | --library=<dir>         makes the card first when the folder has none
##   unpack <file.tlitem> --to=<dir>                            hostile input; writes nothing unless everything holds
##   check  <dir or file.tlitem>                                validates the card, recomputes hash and tier
##   tier   <dir or file.tlitem>                                prints the computed tier and why
##   forge  <kind> --out=<file>      selftest only: a deliberately hostile archive
##   zipreader <file.tlitem>         selftest only: Godot's own ZIPReader must read the same bytes
##
## Lines start with "[item]". Exit code: 0 done, 1 refused (the item is wrong), 2 could not run (usage, missing file).
## Nothing of an item is ever loaded or executed here: files are bytes.

const Item: GDScript = preload("res://kernel/share/item.gd")
const Zip: GDScript = preload("res://kernel/share/tlzip.gd")

var cmd: String = ""
var target: String = ""
var opts: Dictionary = {}


func _ready() -> void:
	var extra: PackedStringArray = PackedStringArray()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var eq: int = a.find("=")
			if eq < 0:
				opts[a.substr(2)] = "true"
			else:
				opts[a.substr(2, eq - 2)] = a.substr(eq + 1)
		elif cmd.is_empty():
			cmd = a
		elif target.is_empty():
			target = a
		else:
			extra.append(a)
	var code: int = 2
	if not extra.is_empty():
		say("ERROR unexpected argument(s): %s" % " ".join(extra))
	else:
		match cmd:
			"card":
				code = _card()
			"pack":
				code = _pack()
			"unpack":
				code = _unpack()
			"check":
				code = _check(false)
			"tier":
				code = _check(true)
			"forge":
				code = _forge()
			"zipreader":
				code = _zipreader()
			_:
				say("ERROR unknown command '%s' (card, pack, unpack, check, tier)" % cmd)
	get_tree().quit(code)


func say(text: String) -> void:
	print("[item] " + text)


func _abs(p: String) -> String:
	var q: String = p.replace("\\", "/")
	if q.begins_with("res://") or q.begins_with("user://"):
		q = ProjectSettings.globalize_path(q)
	q = q.simplify_path()
	while q.length() > 1 and q.ends_with("/"):
		q = q.substr(0, q.length() - 1)
	return q


func _only(allowed: Array) -> bool:
	for k: String in opts.keys():
		if not allowed.has(k):
			say("ERROR unknown option --%s for '%s' (allowed: %s)" % [k, cmd, ", ".join(PackedStringArray(allowed))])
			return false
	return true


func _sha256(data: PackedByteArray) -> String:
	var h: HashingContext = HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	if not data.is_empty():
		h.update(data)
	return h.finish().hex_encode()


## Reads the target as a file set: a folder, or an archive (hostile). {ok, files, errors, is_archive, archive_bytes}
func _load_target() -> Dictionary:
	var p: String = _abs(target)
	if target.is_empty():
		return {"ok": false, "files": {}, "errors": ["no target given"], "is_archive": false, "missing": true}
	if DirAccess.dir_exists_absolute(p):
		var r: Dictionary = Item.read_dir(p)
		r["is_archive"] = false
		return r
	if FileAccess.file_exists(p):
		var r2: Dictionary = Item.read_archive(p)
		r2["is_archive"] = true
		return r2
	return {"ok": false, "files": {}, "errors": ["'%s' is neither a folder nor a file" % target], "is_archive": false, "missing": true}


func _write(path: String, data: PackedByteArray) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		say("ERROR cannot write %s" % path.get_file())
		return false
	if not data.is_empty():
		f.store_buffer(data)
	f.close()
	return true


func _report(path: String) -> Variant:
	var p: String = _abs(path)
	if not FileAccess.file_exists(p):
		return null
	var j: JSON = JSON.new()
	if j.parse(FileAccess.get_file_as_string(p)) != OK or typeof(j.data) != TYPE_DICTIONARY:
		return null
	return j.data


# ------------------------------------------------------------------------------------------------- card
func _card() -> int:
	if not _only(["lint", "bot", "smoke", "invariants", "job", "kind", "title", "summary", "description", "tags", "handle",
			"name", "licence", "version", "human-code"]):
		return 2
	var dir: String = _abs(target)
	if target.is_empty() or not DirAccess.dir_exists_absolute(dir):
		say("ERROR card needs a folder: item.sh card <dir>")
		return 2
	var rd: Dictionary = Item.read_dir(dir)
	if not rd["ok"]:
		for e: String in rd["errors"]:
			say("ERROR " + e)
		return 1
	var o: Dictionary = {}
	for k: String in ["kind", "title", "summary", "description", "tags", "handle", "name", "licence", "version"]:
		if opts.has(k):
			o[k] = opts[k]
	if opts.has("human-code"):
		o["human_code"] = opts["human-code"]
	for verb: String in Item.VERBS:
		if opts.has(verb):
			var rep: Variant = _report(str(opts[verb]))
			if rep == null:
				say("ERROR --%s: no JSON report at that path" % verb)
				return 2
			o[verb] = rep
	if opts.has("job"):
		var log_path: String = _abs(str(opts["job"])) + "/job.jsonl"
		if not FileAccess.file_exists(log_path):
			say("ERROR --job: no job.jsonl in that folder")
			return 2
		o["job_lines"] = FileAccess.get_file_as_string(log_path).split("\n", false)
	var res: Dictionary = Item.build_card(rd["files"], o)
	for n: String in res["notes"]:
		say("note: " + n)
	if not res["ok"]:
		for e: String in res["errors"]:
			say("ERROR " + e)
		say("card: refused, nothing written")
		return 1
	var card: Dictionary = res["card"]
	var existed: bool = (rd["files"] as Dictionary).has(Item.CARD)
	if not _write(dir + "/" + Item.CARD, Item.card_text(card).to_utf8_buffer()):
		return 2
	say("card: %s item.json  uid=%s kind=%s tier=%s version=%s files=%d bytes=%d" % ["refreshed" if existed else "created",
		str(card["uid"]), str(card["kind"]), str(card["tier"]), str(card["version"]), int(card["content"]["files"]), int(card["content"]["bytes"])])
	say("card: content.hash=%s" % str(card["content"]["hash"]))
	return 0


# ------------------------------------------------------------------------------------------------- pack
func _pack() -> int:
	if not _only(["out", "library"]):
		return 2
	var dir: String = _abs(target)
	if target.is_empty() or not DirAccess.dir_exists_absolute(dir) or (opts.has("out") == opts.has("library")):
		say("ERROR usage: item.sh pack <dir> --out=<file.tlitem>   or   item.sh pack <dir> --library=<dir>")
		return 2
	var rd: Dictionary = Item.read_dir(dir)
	if not rd["ok"]:
		for e: String in rd["errors"]:
			say("ERROR " + e)
		return 1
	var files: Dictionary = rd["files"]
	if not files.has(Item.CARD):
		var made: Dictionary = Item.build_card(files, {})
		if not made["ok"]:
			for e: String in made["errors"]:
				say("ERROR " + e)
			say("pack: refused; the folder has no card and one could not be made (run item.sh card with the missing values)")
			return 1
		var text: PackedByteArray = Item.card_text(made["card"]).to_utf8_buffer()
		if not _write(dir + "/" + Item.CARD, text):
			return 2
		files[Item.CARD] = text
		say("pack: the folder had no card; created item.json (uid=%s). The uid is made once: keep this file." % str(made["card"]["uid"]))
	var ck: Dictionary = Item.check(files)
	if not _print_check(ck):
		say("pack: refused (if the contents changed on purpose, run item.sh card to refresh the card)")
		return 1
	var built: Dictionary = Zip.build(files)
	if not built["ok"]:
		say("ERROR " + str(built["error"]))
		return 1
	var bytes: PackedByteArray = built["bytes"]
	if bytes.size() >= Item.ARCHIVE_MAX:
		say("ERROR the archive would have %d bytes; an archive stays under %d" % [bytes.size(), Item.ARCHIVE_MAX])
		return 1
	var out: String = ""
	var card: Dictionary = ck["card"]
	if opts.has("library"):
		var lib: String = _abs(str(opts["library"]))
		DirAccess.make_dir_recursive_absolute(lib)
		out = "%s/%s-%s.tlitem" % [lib, str(card["uid"]), str(card["version"])]
		if FileAccess.file_exists(out):
			if FileAccess.get_file_as_bytes(out) == bytes:
				say("pack: %s is already in the library with the same bytes; nothing written" % out.get_file())
				say("pack: sha256=%s bytes=%d" % [_sha256(bytes), bytes.size()])
				return 0
			say("ERROR %s is already in the library with other bytes; a library file is never rewritten (raise the version)" % out.get_file())
			return 1
	else:
		out = _abs(str(opts["out"]))
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	if not _write(out, bytes):
		return 2
	say("pack: wrote %s  entries=%d bytes=%d tier=%s uid=%s version=%s" % [out.get_file(), files.size(), bytes.size(),
		str(card["tier"]), str(card["uid"]), str(card["version"])])
	say("pack: sha256=%s" % _sha256(bytes))
	return 0


# ------------------------------------------------------------------------------------------------- unpack
func _unpack() -> int:
	if not _only(["to"]):
		return 2
	var src: String = _abs(target)
	if target.is_empty() or not opts.has("to") or not FileAccess.file_exists(src):
		say("ERROR usage: item.sh unpack <file.tlitem> --to=<dir>")
		return 2
	var ra: Dictionary = Item.read_archive(src)
	if not ra["ok"]:
		for e: String in ra["errors"]:
			say("ERROR " + e)
		say("unpack: refused, nothing written")
		return 1
	var files: Dictionary = ra["files"]
	var ck: Dictionary = Item.check(files)
	if not _print_check(ck):
		say("unpack: refused, nothing written")
		return 1
	var to: String = _abs(str(opts["to"]))
	if DirAccess.dir_exists_absolute(to):
		var d: DirAccess = DirAccess.open(to)
		d.include_hidden = true
		if d == null or not d.get_files().is_empty() or not d.get_directories().is_empty():
			say("ERROR the target folder is not empty; unpack never writes over existing files")
			return 1
	elif FileAccess.file_exists(to):
		say("ERROR the target is a file")
		return 1
	var paths: Array = files.keys()
	paths.sort()
	for rel: String in paths:
		var full: String = (to + "/" + rel).simplify_path()
		if not Zip.path_problem(rel).is_empty() or not full.begins_with(to + "/"):
			say("ERROR entry '%s' would land outside the target; nothing more written" % rel)
			return 1
	for rel: String in paths:
		var full2: String = to + "/" + rel
		DirAccess.make_dir_recursive_absolute(full2.get_base_dir())
		if not _write(full2, files[rel]):
			return 2
	var card: Dictionary = ck["card"]
	say("unpack: wrote %d files  tier=%s kind=%s uid=%s version=%s" % [paths.size(), str(card["tier"]), str(card["kind"]),
		str(card["uid"]), str(card["version"])])
	return 0


# ------------------------------------------------------------------------------------------------- check, tier
func _print_check(ck: Dictionary) -> bool:
	for e: String in ck["errors"]:
		say("ERROR " + e)
	for m: String in ck["mismatches"]:
		say("MISMATCH " + m)
	return bool(ck["ok"])


func _check(tier_only: bool) -> int:
	if not _only([]):
		return 2
	var lt: Dictionary = _load_target()
	if not lt["ok"]:
		for e: String in lt["errors"]:
			say("ERROR " + e)
		say("%s: refused" % cmd)
		return 2 if lt.get("missing", false) else 1
	var files: Dictionary = lt["files"]
	if tier_only:
		var a: Dictionary = Item.analyse(files)
		for r: String in a["code_reasons"]:
			say("code: " + r)
		say("tier: %s  files=%d bytes=%d hash=%s" % [str(a["tier"]), int(a["files"]), int(a["bytes"]), str(a["hash"])])
		return 0
	var ck: Dictionary = Item.check(files)
	if not _print_check(ck):
		say("check: refused (%d error(s), %d mismatch(es))" % [(ck["errors"] as Array).size(), (ck["mismatches"] as Array).size()])
		return 1
	var card: Dictionary = ck["card"]
	say("check: ok  %s  uid=%s kind=%s tier=%s version=%s files=%d bytes=%d" % ["archive" if lt["is_archive"] else "folder",
		str(card["uid"]), str(card["kind"]), str(card["tier"]), str(card["version"]), int(card["content"]["files"]), int(card["content"]["bytes"])])
	say("check: content.hash=%s" % str(card["content"]["hash"]))
	return 0


# ------------------------------------------------------------------------------------------------- selftest helpers
func _replace(buf: PackedByteArray, from: String, to: String) -> PackedByteArray:
	var a: PackedByteArray = from.to_ascii_buffer()
	var b: PackedByteArray = to.to_ascii_buffer()
	var out: PackedByteArray = buf.duplicate()
	var i: int = 0
	while i + a.size() <= out.size():
		if out.slice(i, i + a.size()) == a:
			for k: int in b.size():
				out[i + k] = b[k]
			i += a.size()
		else:
			i += 1
	return out


## Hostile archives for the selftest. Each is a well-formed zip except for the one thing its name says.
func _forge() -> int:
	if not opts.has("out"):
		say("ERROR usage: forge <dotdot|absolute|drive|backslash|duplicate|sidecar|trailing|bomb|clock|unsorted> --out=<file>")
		return 2
	var files: Dictionary = {"item.json": "{}\n".to_utf8_buffer(), "aa/evil.txt": "outside\n".to_utf8_buffer()}
	var bytes: PackedByteArray = PackedByteArray()
	match target:
		"dotdot":
			bytes = _replace(Zip.build(files)["bytes"], "aa/evil.txt", "../evil.txt")
		"absolute":
			bytes = _replace(Zip.build(files)["bytes"], "aa/evil.txt", "/a/evil.txt")
		"drive":
			bytes = _replace(Zip.build(files)["bytes"], "aa/evil.txt", "C:/evil.txt")
		"backslash":
			bytes = _replace(Zip.build(files)["bytes"], "aa/evil.txt", "aa\\evil.txt")
		"duplicate":
			files["ab/evil.txt"] = "outside\n".to_utf8_buffer()
			bytes = _replace(Zip.build(files)["bytes"], "ab/evil.txt", "aa/evil.txt")
		"unsorted":
			bytes = _replace(Zip.build(files)["bytes"], "aa/evil.txt", "zz/evil.txt")
		"sidecar":
			files = {"item.json": "{}\n".to_utf8_buffer(), "aa/evil.gd.uid": "uid://x\n".to_utf8_buffer()}
			bytes = Zip.build(files)["bytes"]
		"trailing":
			bytes = Zip.build(files)["bytes"]
			bytes.append_array("extra".to_ascii_buffer())
		"clock":
			# the date field of the first local header (offset 12) set to another day
			bytes = Zip.build(files)["bytes"]
			bytes.encode_u16(12, 0x5b6b)
		"bomb":
			# a small deflate stream that claims to inflate to 1 GiB (declared size patched in both headers)
			var big: PackedByteArray = PackedByteArray()
			big.resize(4096)
			files = {"item.json": "{}\n".to_utf8_buffer(), "aa/evil.txt": big}
			bytes = Zip.build(files)["bytes"]
			var needle: PackedByteArray = PackedByteArray([0, 0x10, 0, 0])
			var i: int = 0
			while i + 4 <= bytes.size():
				if bytes.slice(i, i + 4) == needle:
					bytes.encode_u32(i, 1 << 30)
					i += 4
				else:
					i += 1
		_:
			say("ERROR unknown forge kind '%s'" % target)
			return 2
	if not _write(_abs(str(opts["out"])), bytes):
		return 2
	say("forge: wrote a hostile archive of kind '%s' (%d bytes)" % [target, bytes.size()])
	return 0


## The engine's own ZIPReader must list the same entries and give the same bytes: the archive is a standard zip.
func _zipreader() -> int:
	var src: String = _abs(target)
	var ra: Dictionary = Item.read_archive(src)
	if not ra["ok"]:
		for e: String in ra["errors"]:
			say("ERROR " + e)
		return 1
	var z: ZIPReader = ZIPReader.new()
	if z.open(src) != OK:
		say("ERROR ZIPReader could not open the archive")
		return 1
	var names: Array = Array(z.get_files())
	var mine: Array = (ra["files"] as Dictionary).keys()
	mine.sort()
	var same: bool = names == mine
	for n: String in mine:
		if not names.has(n) or z.read_file(n) != (ra["files"] as Dictionary)[n]:
			same = false
			say("ERROR ZIPReader disagrees about '%s'" % n)
	z.close()
	if not same:
		say("zipreader: the engine's reader and this tool disagree")
		return 1
	say("zipreader: %d entries, same order and same bytes as this tool's reader" % mine.size())
	return 0
