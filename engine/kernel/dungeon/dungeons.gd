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

const LIST_RES: String = "res://boot/dungeons.json"
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
