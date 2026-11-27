extends RefCounted
## SEAM M6 (rules and runs): the Home's run records, `tl.records/1` in `<dir>/records.json` (contracts/BUILD.md "Runs
## are recorded"; the exe's dir is user://home):
##   {"schema":"tl.records/1", "runs":{"<run name>":{"plays":<int>, "finishes":<int>, "best_frames":<int>}}}
## `best_frames` omitted until the first finish; runs sorted by name; keys in that order, so load then save gives the
## same bytes. `started` counts a play, `finished` a finish and the best, and each writes the file at once (temporary
## file, read back and compared, the old one kept as .prev, rename: build_file.gd's pattern). A file that cannot be read
## is never written over (`blocked` says why; the counts still move in memory). Unknown keys are errors.

const BuildFile := preload("res://kernel/world/build/build_file.gd")
const Check := preload("res://kernel/world/build/rules_check.gd")
const OpUtil := preload("res://kernel/world/build/op_util.gd")
const SCHEMA := "tl.records/1"
const FILE := "records.json"
const ENTRY := ["plays", "finishes", "best_frames"]

var dir := ""                            # "" = nothing is written (a test, a Home that was never loaded)
var runs := {}                           # name -> {"plays", "finishes", "best_frames"?}
var blocked := ""                        # why the file is not written (it could not be read)
var last_error := ""                     # the last write's error ("" none)


func _init(d := "") -> void:
	dir = d


## Reads `<dir>/records.json` (absent: no runs). Returns "" or why it was refused (then nothing is ever written there).
func load() -> String:
	runs.clear()
	blocked = ""
	if dir == "" or not FileAccess.file_exists(dir.path_join(FILE)):
		return ""
	var why := _read(FileAccess.get_file_as_string(dir.path_join(FILE)))
	if why != "":
		runs.clear()
		blocked = "%s: %s" % [dir.path_join(FILE), why]
	return blocked


func _read(text: String) -> String:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return "not a JSON object"
	var d: Dictionary = json.data
	for k: Variant in d:
		if not (k in ["schema", "runs"]):
			return "unknown key '%s'" % str(k)
	if d.get("schema") != SCHEMA:
		return "schema must be %s" % SCHEMA
	if typeof(d.get("runs")) != TYPE_DICTIONARY:
		return "runs must be an object"
	for name: Variant in d.runs:
		if not Check.printable(name, Check.NAME_MAX):
			return "runs: a run's name is 1-%d printable characters" % Check.NAME_MAX
		var e: Variant = d.runs[name]
		if typeof(e) != TYPE_DICTIONARY:
			return "runs: '%s' is not an object" % str(name)
		for k: Variant in e:
			if not ENTRY.has(k):
				return "runs: '%s': unknown key '%s'" % [str(name), str(k)]
		var out := {}
		for k: String in ENTRY:
			if not (e as Dictionary).has(k):
				if k == "best_frames":
					continue
				return "runs: '%s': %s is missing" % [str(name), k]
			var n: Variant = OpUtil.int_of(e[k])
			if n == null or int(n) < 0:
				return "runs: '%s': %s must be a whole number of at least 0" % [str(name), k]
			out[k] = int(n)
		runs[str(name)] = out
	return ""


## The file's text: keys in order, runs sorted by name.
func text() -> String:
	var names: Array = runs.keys()
	names.sort()
	var parts := PackedStringArray()
	for n: String in names:
		var e: Dictionary = runs[n]
		var t := "\"plays\":%d,\"finishes\":%d" % [int(e.plays), int(e.finishes)]
		if e.has("best_frames"):
			t += ",\"best_frames\":%d" % int(e.best_frames)
		parts.append("%s:{%s}" % [JSON.stringify(n), t])
	return "{\"schema\":\"%s\",\"runs\":{%s}}\n" % [SCHEMA, ",".join(parts)]


## Writes the file now. Returns "" or what went wrong.
func save() -> String:
	if dir == "":
		return ""
	if blocked != "":
		return blocked
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK and not DirAccess.dir_exists_absolute(dir):
		last_error = "cannot make %s (error %d)" % [dir, err]
		return last_error
	last_error = BuildFile._write_whole(dir.path_join(FILE), text())
	return last_error


## Run `name` (or {} when it was never played): {"plays", "finishes", "best_frames"?}.
func of(name: String) -> Dictionary:
	return (runs.get(name, {}) as Dictionary).duplicate()


## A run started: plays + 1, written.
func started(name: String) -> String:
	var e: Dictionary = runs.get(name, {"plays": 0, "finishes": 0})
	e["plays"] = int(e.plays) + 1
	runs[name] = e
	return save()


## A run finished in `frames`: finishes + 1, the best kept, written. Returns {"plays", "finishes", "best_frames",
## "new_best", "error"}: `new_best` true when there was no best or `frames` is below it.
func finished(name: String, frames: int) -> Dictionary:
	var e: Dictionary = runs.get(name, {"plays": 0, "finishes": 0})
	e["finishes"] = int(e.finishes) + 1
	var best := not e.has("best_frames") or frames < int(e.best_frames)
	if best:
		e["best_frames"] = frames
	runs[name] = e
	var why := save()
	return {"plays": int(e.plays), "finishes": int(e.finishes), "best_frames": int(e.best_frames), "new_best": best, "error": why}
