extends RefCounted
## M3 (spark world-sandbox, 26 Nov 2026): the Home's trophies, `<home dir>/trophies.json` (contracts/BUILD.md "Unlocks
## from play"): {"schema":"tl.trophies/1", "packs":{"<pack id>":{"plays":n, "wins":n, "best":n}}}. Written when a
## dungeon a PERSON played ends (kernel/dungeon/dungeon.gd `close` calls `record`), from the pack's TLRules:
##   plays   +1 every time a loaded dungeon ends (left, finished or stopped)
##   wins    +1 when the rules are over and their winner is the player's side
##   best    the highest score the player's side reached in one play; omitted for a pack that keeps no score
## The player's side: a pack declares none today, so it is the FIRST of `rules.sides` (hockey's blue, paddle's
## "player", parkour's runner). PATCHES-M3.md proposes a manifest key `dungeon.results` for a pack that differs.
## Not written for a counted run (`frames` > 0: the gate's and the instruments' runs are not play), nor headless
## without TL_HOME_BUILD_DIR (a test's dungeon never writes a person's trophies). The folder is the Home's:
## TL_HOME_BUILD_DIR when it is an absolute path, else user://home. Written whole (temporary file, read back, rename).

const SCHEMA := "tl.trophies/1"
const FILE := "trophies.json"
const ENTRY := ["plays", "wins", "best"]


## The Home's folder for trophies now ("" = none: headless without TL_HOME_BUILD_DIR).
static func home_dir() -> String:
	var d := OS.get_environment("TL_HOME_BUILD_DIR")
	if d.is_absolute_path():
		return d
	return "" if DisplayServer.get_name() == "headless" else "user://home"


## dungeon.gd `close`: the pack's rules under `holder` (still loaded), `result` (its `pack` id), `frames_target`
## (0: a person plays until he leaves). Returns the entry written, or {} when nothing was written.
static func record(holder: Node, result: Dictionary, frames_target: int) -> Dictionary:
	var dir := home_dir()
	if frames_target > 0 or dir.is_empty() or str(result.get("pack", "")).is_empty() or holder == null:
		return {}
	var rules: Node = _find_rules(holder)
	var doc := read(dir)
	var packs: Dictionary = doc.packs
	var id := str(result.pack)
	var e: Dictionary = packs.get(id, {"plays": 0, "wins": 0})
	e.plays = int(e.plays) + 1
	if rules != null:
		var sides: PackedStringArray = rules.get("sides")
		var me: String = sides[0] if sides.size() > 0 else ""
		if me != "" and rules.call("is_over") and str(rules.get("winner")) == me:
			e.wins = int(e.wins) + 1
		var scores: Dictionary = rules.get("scores")
		if me != "" and scores.has(me):
			e.best = maxi(int(e.get("best", 0)), int(scores[me]))
	packs[id] = e
	var why := write(dir, packs)
	print(JSON.stringify({"schema": "tl.view/1", "kind": "trophies", "pack": id, "entry": e, "dir": dir, "ok": why == "", "error": why}, "", false))
	return e if why == "" else {}


static func _find_rules(n: Node) -> Node:
	if n is TLRules:
		return n
	for c: Node in n.get_children():
		var r := _find_rules(c)
		if r != null:
			return r
	return null


## {"ok", "reason", "packs": {id: {plays, wins, best?}}} of `dir`/trophies.json (absent: no trophies, ok).
static func read(dir: String) -> Dictionary:
	var path := dir.path_join(FILE)
	if not FileAccess.file_exists(path):
		return {"ok": true, "reason": "", "packs": {}}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or typeof(j.data) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "%s is not a JSON object" % path, "packs": {}}
	var d: Dictionary = j.data
	for k: Variant in d:
		if not str(k) in ["schema", "packs"]:
			return {"ok": false, "reason": "unknown key '%s'" % str(k), "packs": {}}
	if str(d.get("schema", "")) != SCHEMA or typeof(d.get("packs")) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "not %s" % SCHEMA, "packs": {}}
	var out := {}
	for id: Variant in d.packs:
		var e: Variant = d.packs[id]
		if typeof(e) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "packs.%s is not an object" % str(id), "packs": {}}
		var clean := {}
		for k: Variant in e:
			if not ENTRY.has(k) or not (e[k] is float or e[k] is int) or float(e[k]) < 0.0:
				return {"ok": false, "reason": "packs.%s.%s: not a count" % [str(id), str(k)], "packs": {}}
			clean[str(k)] = int(e[k])
		if not clean.has("plays"):
			return {"ok": false, "reason": "packs.%s: plays is missing" % str(id), "packs": {}}
		if not clean.has("wins"):
			clean["wins"] = 0
		out[str(id)] = clean
	return {"ok": true, "reason": "", "packs": out}


## The file's text: packs sorted by id, an entry's keys in contract order.
static func text_of(packs: Dictionary) -> String:
	var ids: Array = packs.keys()
	ids.sort()
	var parts := PackedStringArray()
	for id: String in ids:
		var e: Dictionary = packs[id]
		var kv := PackedStringArray()
		for k: String in ENTRY:
			if e.has(k):
				kv.append("\"%s\":%d" % [k, int(e[k])])
		parts.append("%s:{%s}" % [JSON.stringify(id), ",".join(kv)])
	return "{\"schema\":\"%s\",\"packs\":{%s}}\n" % [SCHEMA, ",".join(parts)]


## Writes `dir`/trophies.json whole. "" or what went wrong.
static func write(dir: String, packs: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(FILE)
	var text := text_of(packs)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "cannot write %s (error %d)" % [tmp, FileAccess.get_open_error()]
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_string(tmp) != text:
		DirAccess.remove_absolute(tmp)
		return "%s did not read back whole" % tmp
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var err := DirAccess.rename_absolute(tmp, path)
	return "" if err == OK else "could not rename %s (error %d)" % [tmp, err]
