extends RefCounted
## L4 (night of 21 Nov): the dungeon list and the launch seam. No class_name (boot.gd loads it by path).
##
## The list: engine/boot/dungeons.json, `{"schema": "tl.dungeons/1", "dungeons": [{"pack", "title", "look"?}]}`
## (docs/shifts/2026-11-21-night/COMMON.md). `pack` is a folder relative to engine/ ("packs/hockey"); `look` is a
## TL_STYLE name (crisp, classic, diorama, overcast: any style/style_<name>.json, "classic" = style/style.json); absent:
## the default look. Unknown keys are errors; an absent value is an absent key.
##
##   read(path)                  -> {ok, dungeons: [{pack, title, look?}], errors: [text]}
##   resolve(pack, games_dir)    -> the absolute folder of a listed pack ("" when this build does not carry it)
##   look_path(name)             -> the style file of a look name ("" for the default: TL_STYLE, else crisp)
##   launch_args(pack_dir)       -> the arguments that open `pack_dir` as a dungeon in a second game process
##   launch(pack_dir)            -> that process's id (OS.create_process), or -1
##
## The launch seam (L3's "Try it"): `load("res://kernel/dungeon/dungeons.gd").launch(<job dir>/pack)` starts the same
## executable that runs now: in the exported game `ThirdLife.exe -- --dungeon=<dir>`; under the editor binary
## `<godot> --path <engine> res://boot/boot.tscn -- --dungeon=<dir>` (the editor binary's main scene is the host).

## E4 (night of 24-25 Nov 2026): the person's own dungeons. A game made in Create is put in the menu by one press and
## taken out again; the editor never writes the shipped list. Its list lies beside it, in the person's data folder:
##   user://dungeons.user.json   (TL_USER_DUNGEONS names another file: the checks use their own)
##   {"schema": "tl.dungeons.user/1", "dungeons": [{"pack": <absolute folder with a pack.json>, "title", "job"?, "look"?}]}
## `job` is the Create job directory the pack was promoted from (Create finds the row by it and moves `pack` to the
## job's newest promotion). read_menu() is the shipped list, then this one (rows marked `mine: true`); hub.gd reads it.
##   read_menu()                       -> {ok, dungeons, errors}: both lists
##   read_user(path?) / user_row(job, path?) / add_user(pack, title, job, path?) / remove_user(job, path?)
const LIST_RES: String = "res://boot/dungeons.json"
const USER_RES: String = "user://dungeons.user.json"
const USER_SCHEMA: String = "tl.dungeons.user/1"
const USER_KEYS: Array = ["pack", "title", "job", "look"]
const SCHEMA: String = "tl.dungeons/1"
const TOP_KEYS: Array = ["schema", "dungeons"]
const ENTRY_KEYS: Array = ["pack", "title", "look"]
const TITLE_MAX: int = 80


static func read(path: String = LIST_RES) -> Dictionary:
	var errors: Array = []
	if not FileAccess.file_exists(path):
		return {"ok": false, "dungeons": [], "errors": ["%s is not there" % path]}
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"ok": false, "dungeons": [], "errors": ["%s line %d: %s" % [path.get_file(), json.get_error_line() + 1, json.get_error_message()]]}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {"ok": false, "dungeons": [], "errors": ["%s: the list is a JSON object" % path.get_file()]}
	var d: Dictionary = json.data
	for k: Variant in d.keys():
		if not TOP_KEYS.has(k):
			errors.append("unknown key '%s' (unknown keys are errors)" % str(k))
	if str(d.get("schema", "")) != SCHEMA:
		errors.append("schema is '%s', wanted '%s'" % [str(d.get("schema", "")), SCHEMA])
	if typeof(d.get("dungeons")) != TYPE_ARRAY:
		errors.append("'dungeons' is a list")
		return {"ok": false, "dungeons": [], "errors": errors}
	var out: Array = []
	var seen: Dictionary = {}
	for i: int in (d["dungeons"] as Array).size():
		var e: Variant = d["dungeons"][i]
		if typeof(e) != TYPE_DICTIONARY:
			errors.append("dungeons[%d] is an object {pack, title, look?}" % i)
			continue
		var bad: bool = false
		for k: Variant in (e as Dictionary).keys():
			if not ENTRY_KEYS.has(k):
				errors.append("dungeons[%d]: unknown key '%s' (unknown keys are errors)" % [i, str(k)])
				bad = true
		for k: String in ["pack", "title"]:
			if typeof((e as Dictionary).get(k)) != TYPE_STRING or str(e[k]).strip_edges().is_empty():
				errors.append("dungeons[%d]: '%s' is a non-empty text" % [i, k])
				bad = true
		if bad:
			continue
		var pack: String = str(e["pack"]).replace("\\", "/").trim_suffix("/")
		if pack.is_absolute_path() or pack.begins_with("res://") or pack.contains(".."):
			errors.append("dungeons[%d]: 'pack' is a folder relative to engine/ (for example packs/hockey), not '%s'" % [i, pack])
			continue
		if seen.has(pack):
			errors.append("dungeons[%d]: '%s' is listed twice" % [i, pack])
			continue
		seen[pack] = true
		if str(e["title"]).length() > TITLE_MAX:
			errors.append("dungeons[%d]: the title is longer than %d characters" % [i, TITLE_MAX])
			continue
		var row: Dictionary = {"pack": pack, "title": str(e["title"]).strip_edges()}
		if (e as Dictionary).has("look"):
			if typeof(e["look"]) != TYPE_STRING or not look_known(str(e["look"])):
				errors.append("dungeons[%d]: look '%s' is not a style name (%s)" % [i, str(e["look"]), ", ".join(PackedStringArray(look_names()))])
				continue
			row["look"] = str(e["look"])
		out.append(row)
	return {"ok": errors.is_empty(), "dungeons": out, "errors": errors}


## The style file a look name stands for, as TLStyle._chosen_path maps TL_STYLE; "" = the default.
static func look_path(name: String) -> String:
	var n: String = name.strip_edges()
	if n.is_empty():
		return ""
	if n == "crisp":
		return "res://style/style_crisp.json"
	if n == "classic":
		return "res://style/style.json"
	return "res://style/style_%s.json" % n


static func look_known(name: String) -> bool:
	return not name.strip_edges().is_empty() and name.is_valid_identifier() and FileAccess.file_exists(look_path(name))


## The look names this build has: crisp, classic and every style/style_<name>.json.
static func look_names() -> Array:
	var names: Array = ["crisp", "classic"]
	var d: DirAccess = DirAccess.open("res://style")
	if d != null:
		for f: String in d.get_files():
			f = f.trim_suffix(".remap")
			if f.begins_with("style_") and f.ends_with(".json"):
				var n: String = f.trim_prefix("style_").trim_suffix(".json")
				if not names.has(n):
					names.append(n)
	return names


## Where a listed pack is: under the editor binary the engine's own folder (res://<pack>); in the exported game (or with
## --games) the folder of `games/` that engine/boot/games.json copies it to (its `from` is "engine/<pack>"), else a
## folder of that name. "" when it is not there.
static func resolve(pack: String, games_dir: String) -> String:
	var p: String = pack.replace("\\", "/").trim_suffix("/")
	if p.is_absolute_path():
		return p if FileAccess.file_exists(p + "/pack.json") else ""
	if games_dir.is_empty():
		var full: String = ProjectSettings.globalize_path("res://" + p).replace("\\", "/").trim_suffix("/")
		return full if FileAccess.file_exists(full + "/pack.json") else ""
	var cat: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://boot/games.json"))
	for g: Variant in (cat.get("games", []) if cat is Dictionary else []):
		if typeof(g) == TYPE_DICTIONARY and str(g.get("from", "")).trim_suffix("/") == "engine/" + p:
			var dir: String = games_dir + "/" + str(g.get("name", ""))
			if FileAccess.file_exists(dir + "/pack.json"):
				return dir
	var by_name: String = games_dir + "/" + p.get_file()
	return by_name if FileAccess.file_exists(by_name + "/pack.json") else ""


## The arguments of a second game process that opens `pack_dir` as a dungeon and quits when it is left.
static func launch_args(pack_dir: String) -> PackedStringArray:
	var args: PackedStringArray = PackedStringArray()
	if not OS.has_feature("thirdlife_exe"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/"), "res://boot/boot.tscn"])
	args.append_array(["--", "--dungeon=" + pack_dir.replace("\\", "/")])
	return args


static func launch(pack_dir: String) -> int:
	var pid: int = OS.create_process(OS.get_executable_path(), launch_args(pack_dir))
	print("[dungeon] launched %s as a dungeon in process %d" % [pack_dir, pid])
	return pid if pid > 0 else -1


# ---------------------------------------------------------------- E4: the person's own list

## The file of the person's list: TL_USER_DUNGEONS, else user://dungeons.user.json, as a disk path.
static func user_path() -> String:
	var env: String = OS.get_environment("TL_USER_DUNGEONS")
	return (env if not env.is_empty() else ProjectSettings.globalize_path(USER_RES)).replace("\\", "/")


## The person's list. A missing file is an empty list (ok); unknown keys, a relative pack, a title over 80 are errors
## (the row is left out, the rest is read).
static func read_user(path: String = "") -> Dictionary:
	var file: String = path if not path.is_empty() else user_path()
	if not FileAccess.file_exists(file):
		return {"ok": true, "dungeons": [], "errors": []}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not (d is Dictionary) or str((d as Dictionary).get("schema", "")) != USER_SCHEMA or not ((d as Dictionary).get("dungeons") is Array):
		return {"ok": false, "dungeons": [], "errors": ["%s: not a %s list {schema, dungeons: [...]}" % [file.get_file(), USER_SCHEMA]]}
	var errors: Array = []
	for k: Variant in (d as Dictionary).keys():
		if not TOP_KEYS.has(k):
			errors.append("%s: unknown key '%s' (unknown keys are errors)" % [file.get_file(), str(k)])
	var out: Array = []
	var rows: Array = d["dungeons"]
	for i: int in rows.size():
		var e: Variant = rows[i]
		var why: String = _user_row_problem(e)
		if not why.is_empty():
			errors.append("%s dungeons[%d]: %s" % [file.get_file(), i, why])
			continue
		var row: Dictionary = {"pack": str(e["pack"]).replace("\\", "/").trim_suffix("/"), "title": str(e["title"]).strip_edges()}
		for k: String in ["job", "look"]:
			if (e as Dictionary).has(k):
				row[k] = str(e[k])
		out.append(row)
	return {"ok": errors.is_empty(), "dungeons": out, "errors": errors}


static func _user_row_problem(e: Variant) -> String:
	if not (e is Dictionary):
		return "a row is an object {pack, title, job?, look?}"
	for k: Variant in (e as Dictionary).keys():
		if not USER_KEYS.has(k):
			return "unknown key '%s' (unknown keys are errors)" % str(k)
	for k: String in ["pack", "title"]:
		if typeof((e as Dictionary).get(k)) != TYPE_STRING or str(e[k]).strip_edges().is_empty():
			return "'%s' is a non-empty text" % k
	if not str(e["pack"]).replace("\\", "/").is_absolute_path():
		return "'pack' is an absolute folder (a promoted pack), not '%s'" % str(e["pack"])
	if str(e["title"]).length() > TITLE_MAX:
		return "the title is longer than %d characters" % TITLE_MAX
	if (e as Dictionary).has("job") and (typeof(e["job"]) != TYPE_STRING or str(e["job"]).is_empty()):
		return "'job' is a non-empty text"
	if (e as Dictionary).has("look") and (typeof(e["look"]) != TYPE_STRING or not look_known(str(e["look"]))):
		return "look '%s' is not a style name" % str(e["look"])
	return ""


static func _write_user(rows: Array, path: String) -> String:
	var file: String = path if not path.is_empty() else user_path()
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var tmp: String = file + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "cannot write %s" % tmp
	f.store_line(JSON.stringify({"schema": USER_SCHEMA, "dungeons": rows}, " "))
	f.close()
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
	return "" if DirAccess.rename_absolute(tmp, file) == OK else "cannot replace %s" % file


## The row of a Create job (by its job directory), or {}.
static func user_row(job_dir: String, path: String = "") -> Dictionary:
	var j: String = job_dir.replace("\\", "/").trim_suffix("/")
	for r: Dictionary in read_user(path)["dungeons"]:
		if str(r.get("job", "")).trim_suffix("/") == j:
			return r
	return {}


## Puts a pack in the person's list (or moves the job's row to this pack): "" or why not.
static func add_user(pack_dir: String, title: String, job_dir: String = "", path: String = "") -> String:
	var pack: String = pack_dir.replace("\\", "/").trim_suffix("/")
	var row: Dictionary = {"pack": pack, "title": title.strip_edges().substr(0, TITLE_MAX)}
	if not job_dir.is_empty():
		row["job"] = job_dir.replace("\\", "/").trim_suffix("/")
	var why: String = _user_row_problem(row)
	if not why.is_empty():
		return why
	if not FileAccess.file_exists(pack + "/pack.json"):
		return "no pack.json in %s" % pack
	var rows: Array = []
	for r: Dictionary in read_user(path)["dungeons"]:
		if str(r["pack"]) != pack and (not row.has("job") or str(r.get("job", "")) != str(row["job"])):
			rows.append(r)
	rows.append(row)
	return _write_user(rows, path)


## Takes a job's row (or a pack's, when `job_or_pack` is its folder) out of the person's list: "" or why not.
static func remove_user(job_or_pack: String, path: String = "") -> String:
	var k: String = job_or_pack.replace("\\", "/").trim_suffix("/")
	var rows: Array = []
	for r: Dictionary in read_user(path)["dungeons"]:
		if str(r.get("job", "")) != k and str(r["pack"]) != k:
			rows.append(r)
	return _write_user(rows, path)


## What the menu lists: the shipped dungeons, then the person's own (marked `mine: true`), newest first and one row per
## game: 26 Nov (the owner: one final version, not every version): rows whose packs share a pack id keep only the highest
## version (pack.json `version`; the later row on a tie).
static func read_menu(path: String = LIST_RES) -> Dictionary:
	var r: Dictionary = read(path)
	var u: Dictionary = read_user()
	var rows: Array = (r["dungeons"] as Array).duplicate()
	var best: Dictionary = {}                  # pack id (or the folder when unreadable) -> [version parts, row]
	var order: Array = []
	for row: Dictionary in u["dungeons"]:
		var m: Dictionary = row.duplicate()
		m.erase("job")
		m["mine"] = true
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(m["pack"]) + "/pack.json")) if FileAccess.file_exists(str(m["pack"]) + "/pack.json") else null
		var id: String = str((meta as Dictionary).get("id", m["pack"])) if meta is Dictionary else str(m["pack"])
		var v: Array = Array(str((meta as Dictionary).get("version", "0")).split(".")).map(func(x: String) -> int: return x.to_int()) if meta is Dictionary else [0]
		if not best.has(id):
			order.append(id)
		elif _older(v, best[id][0]):
			continue
		best[id] = [v, m]
	order.reverse()                            # the person's newest game first
	for id: String in order:
		rows.append(best[id][1])
	var errors: Array = (r["errors"] as Array) + (u["errors"] as Array)
	return {"ok": errors.is_empty(), "dungeons": rows, "errors": errors}


## Is version a older than version b (lists of numbers, "0.1.12" -> [0, 1, 12])?
static func _older(a: Array, b: Array) -> bool:
	for i: int in maxi(a.size(), b.size()):
		var x: int = int(a[i]) if i < a.size() else 0
		var y: int = int(b[i]) if i < b.size() else 0
		if x != y:
			return x < y
	return false
