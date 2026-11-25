extends RefCounted
## E3g (25 Nov 2026): a pack started from a base counts only its own game lines against lint's MAX_PACK_LINES.
## A pack declares its base in pack.json (`"base": "<name>"`, a directory of engine/templates/). A line of a game
## script (any .gd outside tests/) is the base's when the base's file at the same path holds the same line (line endings
## aside; each base line answers one pack line). So a file byte-equal to the base's counts 0 lines, an edited base file
## counts its added or changed lines (a removed line costs nothing), and a file the base does not have counts every
## line. The base's files are still linted (fence, the per-script cap, capabilities); they are only not counted.
## foreman/src/testing/fake-runner-core.ts counts the same way. No global class names are used here (see manifest.gd).

const BASES_DIR: String = "res://templates/"


## {name, dir}: the base the manifest declares ("" and "" without one). A base the engine does not have is a layout error.
static func resolve(m: Dictionary, lay: Array) -> Dictionary:
	var name: String = str(m["base"]) if typeof(m.get("base")) == TYPE_STRING else ""
	if name.is_empty():
		return {"name": "", "dir": ""}
	if FileAccess.file_exists(BASES_DIR + name + "/pack.json"):
		return {"name": name, "dir": BASES_DIR + name}
	lay.append({"kind": "layout", "file": "pack.json", "message": "declares the base '%s', but the engine has no templates/%s/ (a base is a directory of engine/templates/ holding a pack.json)" % [name, name]})
	return {"name": name, "dir": ""}


## The pack's own lines of the game script `rel` (`src` with "\n" line ends, `nlines` its lines as the size rule counts them).
static func own_lines(src: String, base: Dictionary, rel: String, nlines: int) -> int:
	var dir: String = str(base.get("dir", ""))
	if dir.is_empty() or not FileAccess.file_exists(dir + "/" + rel):
		return nlines
	var left: Dictionary = {}
	for line: String in _lines_of(FileAccess.get_file_as_string(dir + "/" + rel).replace("\r\n", "\n")):
		left[line] = int(left.get(line, 0)) + 1
	var own: int = 0
	for line: String in _lines_of(src):
		if int(left.get(line, 0)) > 0:
			left[line] = int(left[line]) - 1
		else:
			own += 1
	return own


## The size errors of the game's and the tests' totals (PACK.md "Size limits"; tests/ has its own cap since 21 Nov).
static func size_errors(own: int, game: int, tests: int, base: Dictionary, max_lines: int) -> Array:
	if own <= max_lines and tests <= 4000:
		return []
	var with_base: bool = not str(base.get("dir", "")).is_empty()
	var note: String = "; %d more are the base templates/%s/ unchanged, not counted" % [game - own, str(base["name"])] if with_base else ""
	return [{"kind": "size", "file": "scripts/", "message": "%d lines of game GDScript%s (scripts/, gen/; at most %d%s), %d lines in tests/ (at most 4000)" % [own, " of its own" if with_base else "", max_lines, note, tests]}]


## " (N game lines of its own over the base B)" for the size check's detail; "" without a base.
static func detail(own: int, base: Dictionary) -> String:
	return "" if str(base.get("dir", "")).is_empty() else " (%d game lines of its own over the base %s)" % [own, str(base["name"])]


## The lines as the size rule counts them: a final newline ends the last line, it does not start one.
static func _lines_of(src: String) -> PackedStringArray:
	var parts: PackedStringArray = src.split("\n")
	if src.ends_with("\n"):
		parts.remove_at(parts.size() - 1)
	return parts
