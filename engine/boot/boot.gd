extends Node
## P9. The door of the exported game (engine/tools/export.sh makes dist/ThirdLife/ThirdLife.exe; docs/EXE.md).
##
##   ThirdLife.exe [--record=<abs file>]        the village for a person: a window; W A S D walk (he turns toward
##                                              where he walks), the mouse looks, Shift runs, Space jumps, C slides
##                                              while running, F toggles flight (Space up, C down), E enters, Q leaves, Esc quits
##                                              (kernel/runner/visit.gd; --record writes the visit as tl.input/1)
##   ThirdLife.exe --input=<abs file>           a recorded visit again (no device is read)
##   ThirdLife.exe -- --site-job=<abs dir>      S2: the village's construction site follows that Foreman job directory
##                                              live, as it grows (also with `check`); missing or without job.jsonl:
##                                              the exported copy, and a warning
##   ... -- check --edits=<abs json file>       S3 (a test instrument): the walk's `edits` ([[tick, file, replacement]],
##                                              kernel/world/jobs.gd): a file is copied over another at a world tick
##   ThirdLife.exe --headless --fixed-fps 60 -- check --out=<abs file> [--ticks=N] [--games=<dir>]
##                                              the scripted tour of the same village without a window; one tl.world/1
##                                              line per pack (its state hash) in --out; `export.sh check` compares it
##                                              with the same run of the editor binary
##   ThirdLife.exe --headless -- probe --out=<abs file>
##                                              what works inside an exported build (the table of docs/EXE.md)
##   ThirdLife.exe --headless -- tag             prints "[boot] build: <tag>" and ends (every verb prints that line
##                                              first; `export.sh check` compares it with the commit just exported)
##   The same three from the editor binary: <godot> --path <engine> res://boot/boot.tscn [-- check ...]
##
## Why not kernel/host/host.gd: its `_ensure_import` looks for the class cache as a file beside `res://` and starts
## the executable again with `--import` when it is missing; in an exported build that file is inside the pack file
## and the second start would be the game itself. This script starts the same two nodes the host starts
## (kernel/world/draw/view.gd for the window, kernel/world/world.gd without one) with the same `start(options)`.
##
## Games are plain folders in `games/` beside the exe (`--games=<dir>` names another folder; the editor binary without `--games`
## uses the engine's own packs, by folder or by games.json). The walk is `res://boot/village.json`; each plot's `pack` is a folder
## name in `games/`. A plot whose folder is missing is left out and said so.
##
## Environment, for unattended starts (export.sh check): TL_EXE_CAPTURE=<abs png> writes one picture after 120 physics frames
## (TL_EXE_CAPTURE_AT=<frame> names another frame); TL_EXE_QUIT_AT=<frame> ends the world cleanly at that frame;
## TL_EXE_WINDOW_POS=x,y moves the window; TL_EXE_KEYS="60:+W;400:-W;420:+E;900:+Escape" presses and releases keys at physics frames
## (the same Input state a keyboard sets: this is how the keys were tested without a person); P11: `<frame>:~<dx>,<dy>` moves the
## mouse by that many pixels (the same event a mouse makes); TL_EXE_TRACE=<abs file> writes where the visitor is and who is on stage
## every 30 frames. P14: the caches a build ships (`cache` beside the exe: rims, far pictures, rig recipes, keyed by each game's
## content) are copied into the user's cache on every start when a file is missing there (PlotFile.seed_cache). TL_EXE_WARM=1
## (export.sh, with TL_CACHE_DIR): the window runs the village's scripted tour to its end, unattended, which fills that cache for
## the games beside the exe. Walker-feel T: TL_EXE_FRAMES=<abs dir> (+ TL_EXE_FRAMES_RANGE=a:b, TL_EXE_FRAMES_FULL=1,
## TL_EXE_SKYMASK=1) writes every drawn frame for the blink detector; TL_EXE_AA=<spec> overrides the window's antialiasing (EXE_AA).
## No global class name is declared here, and none of the kernel's is used by name.
## L4 (21 Nov): a person's start with nothing asked shows the main menu; every flag path and unattended start goes to the
## village as before. The menu, --dungeon=<pack dir> and the `trips` verb live in boot/hub.gd (their usage is there).

const WALK_RES: String = "res://boot/village.json"
const VIEW_SCRIPT: String = "res://kernel/world/draw/view.gd"
const WORLD_SCRIPT: String = "res://kernel/world/world.gd"
const PACK_BASES: Array = ["res://seeds", "res://kernel/examples", "res://kernel/world/packs", "res://packs"]
const KEYS_WALK: String = "W A S D  walk      mouse  look      Shift  run      Space  jump      C  slide (running)      F  fly (Space up, C down)      E  enter the game you stand in      B  build      Esc  quit"
const KEYS_STAGE: String = "Q or Esc  leave the game"
const Hub: GDScript = preload("res://boot/hub.gd")
const Frames: GDScript = preload("res://boot/frames.gd")
const CAPTURE_FRAME: int = 120
## Night jam-lessons-home T1: which build is this. export.sh writes one line beside the exe, "<short commit> <date
## time>" (for example "4e20087 2026-11-16 01:40"); it is read at start, printed to the log ("[boot] build: <tag>")
## and shown small in the window's top right corner. The editor binary is "dev". No file: nothing is shown.
const TAG_FILE: String = "BUILD-TAG.txt"
const TAG_MAX: int = 64
const PlotFile: GDScript = preload("res://kernel/world/plotfile.gd")
## Fallback when the style names no env.exe_aa. Walker-feel T3 (docs/reports/walker-feel/T.md): TAA cuts flicker, softens.
const EXE_AA: String = "msaa=2,taa=1"

var verb: String = ""
var opts: Dictionary = {}
var games_dir: String = ""
var view: Node = null
var world: Node = null
var dropped: Array = []                 # plots left out: [{id, pack, why}]
var kept: Array = []                    # [{id, pack, dir}]
var kept_sites: Array = []              # S: [{lot, job, dir}]: the construction sites whose job log was found
var _frame: int = 0
var _hint: Label = null
var _capture_path: String = ""
var _capture_done: bool = false
var _captured: bool = false
var _capture_at: int = CAPTURE_FRAME
var _keys_held: Dictionary = {}         # keycode -> true: the keys TL_EXE_KEYS holds down now (M2-PATCHES 2)
var _keys: Dictionary = {}              # physics frame -> [[pressed, keycode], ...] or [["move", Vector2]] (TL_EXE_KEYS)
var _trace: FileAccess = null
var _quit_at: int = -1
var _walk_tmp: String = ""
var _ending: bool = false
var _unattended: bool = false
var tag: String = ""                    # the build tag: "dev" in the editor binary, "" when the exe has no tag file
var hub: RefCounted = null              # L4: the menu and the dungeons (boot/hub.gd)
var menu_mode: bool = false             # L4: the world, the dungeons and Create are reached from the menu and return to it
var dungeon_only: bool = false          # L4: started with --dungeon: leaving the dungeon ends the process
var _hint_layer: CanvasLayer = null
var _frames: RefCounted = null          # TL_EXE_FRAMES (boot/frames.gd)


func _ready() -> void:
	set_physics_process(false)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var eq: int = a.find("=")
			if eq < 0:
				opts[a.substr(2)] = "true"
			else:
				opts[a.substr(2, eq - 2)] = a.substr(eq + 1)
		elif verb.is_empty():
			verb = a
	for k: String in ["games", "out", "record", "input", "site-job", "edits", "dungeon", "tripped"]:
		if opts.has(k):
			opts[k] = _win_path(str(opts[k]))
	if opts.has("games"):
		games_dir = str(opts["games"]).trim_suffix("/")
	elif exported():
		games_dir = OS.get_executable_path().get_base_dir().replace("\\", "/") + "/games"
	if exported() and verb.is_empty():
		# the engine's own log (user://logs/godot.log) is shared with every other engine process on the machine and
		# is rotated away by them within seconds: the last run of THIS exe is kept beside it
		var rl: Logger = (load("res://boot/run_log.gd") as GDScript).new()
		# L4: a dungeon started by --dungeon (a second process: Create's "Try it") keeps its own log beside it
		var log_name: String = "ThirdLife-last-dungeon.log" if opts.has("dungeon") else "ThirdLife-last-run.log"
		if bool(rl.call("open", OS.get_executable_path().get_base_dir().replace("\\", "/") + "/" + log_name)):
			OS.add_logger(rl)
	if exported():
		var seeded: int = int(PlotFile.call("seed_cache", OS.get_executable_path().get_base_dir().replace("\\", "/") + "/cache"))
		if seeded > 0:
			print("[boot] %d cache files of this build copied to %s" % [seeded, str(PlotFile.call("cache_dir"))])
	tag = build_tag()
	print("[boot] build: %s" % (tag if not tag.is_empty() else "none (no readable %s beside the exe)" % TAG_FILE))
	hub = Hub.new(self)
	match verb:
		"":
			if opts.has("tripped"):
				hub.call("tripped_start")              # L4b: the card of a dungeon the watchdog stopped
			elif opts.has("dungeon"):
				hub.call("dungeon_start")
			elif bool(hub.call("menu_wanted")):
				hub.call("menu_start")
			else:
				_visit()
		"trips":
			hub.call("trips_start")
		"check":
			_check()
		"tag":
			get_tree().quit(0)                     # export.sh check: the line above is all it asks for
		"probe":
			var p: RefCounted = (load("res://boot/probe.gd") as GDScript).new()
			p.call("run", self, str(opts.get("out", "")))
		_:
			_stop("unknown verb '%s' (none: the menu or the village for a person; check; probe; tag; trips)" % verb, 2)


## True in a build made by export.sh (the preset's own feature tag), false under the editor binary.
func exported() -> bool:
	return OS.has_feature("thirdlife_exe")


## The build tag: "dev" under the editor binary; in the exe the first line of BUILD-TAG.txt beside it when it has
## the export's shape, "<7 to 40 hex digits or 'unknown'> <YYYY-MM-DD> <HH:MM>" (so no path or name can reach the
## screen); "" when the file is absent or holds anything else (the log says which).
func build_tag() -> String:
	if not exported():
		return "dev"
	var p: String = OS.get_executable_path().get_base_dir().replace("\\", "/") + "/" + TAG_FILE
	if not FileAccess.file_exists(p):
		return ""
	var line: String = FileAccess.get_file_as_string(p).replace("\r", "").split("\n")[0].strip_edges().left(TAG_MAX)
	var shape: RegEx = RegEx.create_from_string("^([0-9a-f]{7,40}|unknown) [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}$")
	if shape.search(line) == null:
		print("[boot] %s beside the exe is not a build tag (wanted '<commit> <YYYY-MM-DD> <HH:MM>'): not shown" % TAG_FILE)
		return ""
	return line


func _win_path(p: String) -> String:
	var q: String = p.replace("\\", "/")
	if q.length() >= 3 and q[0] == "/" and q[2] == "/" and q[1].to_lower() >= "a" and q[1].to_lower() <= "z":
		return q[1].to_upper() + ":" + q.substr(2)
	return q


## Ends the process with a reason a person can read: on the log, and in a message box when a person started it.
func _stop(reason: String, code: int) -> void:
	print("[boot] " + reason)
	printerr("[boot] " + reason)
	if verb.is_empty() and not _unattended and DisplayServer.get_name() != "headless":
		OS.alert(reason, "Third Life")
	get_tree().quit(code)


# ------------------------------------------------------------------------------------------------ the walk file
## Where a plot's pack is on disk: a folder of `games/`, or (editor binary, no --games) one of the engine's own.
func _pack_dir(pack: String) -> String:
	var p: String = pack.replace("\\", "/")
	if p.is_absolute_path():
		return p if FileAccess.file_exists(p + "/pack.json") else ""
	if not games_dir.is_empty():
		return games_dir + "/" + p if FileAccess.file_exists(games_dir + "/" + p + "/pack.json") else ""
	for base: String in PACK_BASES:
		var full: String = ProjectSettings.globalize_path(base + "/" + p)
		if FileAccess.file_exists(full + "/pack.json"):
			return full
	var cat: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://boot/games.json"))   # hunt2 A2: an export name
	for g: Variant in (cat.get("games", []) if cat is Dictionary else []):                       # that is not its folder's name
		if str(g.get("name", "")) == p: return _pack_dir(ProjectSettings.globalize_path("res://" + str(g.get("from", "")).trim_prefix("engine/")))
	return ""


## Reads res://boot/village.json, points every plot at its folder, leaves out plots whose folder is missing (and
## the pad height that belongs to them), and writes the result where the world host can read it. A person's walk
## keeps the scripted events: the viewer runs none of them (P11). Returns the file's path, or "" after `_stop`.
func _make_walk() -> String:
	if not FileAccess.file_exists(WALK_RES):
		_stop("the walk %s is not in this build" % WALK_RES, 2)
		return ""
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(WALK_RES)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		_stop("the walk %s is not a JSON object (line %d: %s)" % [WALK_RES, json.get_error_line() + 1, json.get_error_message()], 2)
		return ""
	var walk: Dictionary = json.data
	var land: Dictionary = walk.get("landscape", {}) if typeof(walk.get("landscape")) == TYPE_DICTIONARY else {}
	var pad_in: Array = land.get("pad_h", []) if typeof(land.get("pad_h")) == TYPE_ARRAY else []
	var plots: Array = []
	var pads: Array = []
	var src: Array = walk.get("plots", [])
	for i: int in src.size():
		var sp: Dictionary = src[i]
		var dir: String = _pack_dir(str(sp.get("pack", "")))
		if dir.is_empty():
			dropped.append({"id": str(sp.get("id", "")), "pack": str(sp.get("pack", "")),
				"why": "no folder '%s' with a pack.json in %s" % [str(sp.get("pack", "")), games_dir if not games_dir.is_empty() else "the engine's seeds and examples"]})
			continue
		kept.append({"id": str(sp.get("id", "")), "pack": str(sp.get("pack", "")), "dir": dir})
		sp["pack"] = dir
		plots.append(sp)
		if i < pad_in.size():
			pads.append(pad_in[i])
	for d: Dictionary in dropped:
		print("[boot] plot '%s' is left out: %s" % [str(d["id"]), str(d["why"])])
	if plots.is_empty():
		_stop("no game was found: %s holds none of the games of the village (%s). The folder 'games' must stand beside ThirdLife.exe." % [
			games_dir if not games_dir.is_empty() else "the engine", ", ".join(PackedStringArray(dropped.map(func(d: Dictionary) -> String: return str(d["pack"]))))], 2)
		return ""
	walk["plots"] = plots
	if land.has("pad_h"):
		land["pad_h"] = pads
	_site_lots(land)
	if not dropped.is_empty():
		# a scripted `enter` that names a plot which is not there would be refused; without a name it enters where he stands
		var evs: Array = []
		for ev: Variant in walk.get("events", []):
			var gone: bool = false
			for d: Dictionary in dropped:
				gone = gone or (typeof(ev) == TYPE_DICTIONARY and str((ev as Dictionary).get("plot", "")) == str(d["id"]))
			if not gone:
				evs.append(ev)
		walk["events"] = evs
	if opts.has("ticks") and str(opts["ticks"]).is_valid_int():
		walk["ticks"] = int(opts["ticks"])
	if OS.get_environment("TL_EXE_START").split_floats(",").size() == 4:     # D1 22 Nov, a test instrument: start at x,z facing x2,z2
		var at: PackedFloat64Array = OS.get_environment("TL_EXE_START").split_floats(",")
		walk["player"] = [[0, [at[0], 0, at[1]]], [60, [at[0], 0, at[1]]], [61, [at[2], 0, at[3]]]]
	if opts.has("edits"):
		# S3: a test instrument (the walk's `edits`, kernel/world/jobs.gd): [[world tick, file, replacement file]]
		# from a JSON file; a file is copied over another at a tick, so a "job that grows" is a function of the ticks
		var ed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(opts["edits"])))
		if typeof(ed) == TYPE_ARRAY:
			walk["edits"] = ed
		else:
			print("[boot] warning: --edits=%s is not a JSON list of [tick, file, replacement]: no edits" % str(opts["edits"]))
	var dir_out: String = OS.get_user_data_dir().replace("\\", "/") + "/boot"
	DirAccess.make_dir_recursive_absolute(dir_out)
	_walk_tmp = "%s/village_%d.json" % [dir_out, OS.get_process_id()]
	var f: FileAccess = FileAccess.open(_walk_tmp, FileAccess.WRITE)
	if f == null:
		_stop("cannot write the walk to %s (error %d)" % [_walk_tmp, FileAccess.get_open_error()], 2)
		return ""
	f.store_string(JSON.stringify(walk, "", false) + "\n"); f.close()
	return _walk_tmp


## S (engine-world-next): a lot of the village with a `job` is a construction site (kernel/world/site.gd). In the
## exe its job is the folder `sites/<job folder name>` beside `games/` (export.sh copies the job's job.jsonl and its
## last promoted game there); the editor binary with --games looks beside that folder too, without it the job
## directory of the walk is used as it is (relative to the repository). A job that is not found leaves a plain
## building site, said on the log (like a game that is not there).
func _site_lots(land: Dictionary) -> void:
	for k: int in (land.get("lots", []) as Array).size():
		var lot: Variant = (land["lots"] as Array)[k]
		if typeof(lot) != TYPE_DICTIONARY or not (lot as Dictionary).has("job"):
			continue
		var job: String = str((lot as Dictionary)["job"]).replace("\\", "/").trim_suffix("/")
		var dir: String = job
		if not games_dir.is_empty():
			dir = games_dir.get_base_dir() + "/sites/" + job.get_file()
		elif not job.is_absolute_path():
			dir = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/").get_base_dir() + "/" + job
			var wt: int = dir.find("/.claude/worktrees/")
			if wt >= 0 and not FileAccess.file_exists(dir + "/job.jsonl"):
				dir = dir.substr(0, wt) + "/" + job           # site/ (job output) is in the main checkout only
		if opts.has("site-job") and kept_sites.is_empty():
			# S2: a person points the first site lot at a job that is running now (an absolute job directory)
			var live: String = str(opts["site-job"]).trim_suffix("/")
			if live.is_absolute_path() and FileAccess.file_exists(live + "/job.jsonl"):
				print("[boot] lot %d follows the job %s live (--site-job)" % [k, live])
				dir = live
				job = live
				(lot as Dictionary).erase("replay")
			else:
				print("[boot] warning: --site-job=%s is not an absolute job directory with a job.jsonl: lot %d shows %s" % [live, k, dir])
		if FileAccess.file_exists(dir + "/job.jsonl"):
			(lot as Dictionary)["job"] = dir
			kept_sites.append({"lot": k, "job": job.get_file(), "dir": dir})
		else:
			(lot as Dictionary).erase("job")
			(lot as Dictionary).erase("replay")
			dropped.append({"id": "lot %d" % k, "pack": job.get_file(), "why": "no job log at %s/job.jsonl: a plain building site" % dir})
			print("[boot] lot %d is a plain building site: its job '%s' has no job.jsonl at %s" % [k, job, dir])


func _exit_tree() -> void:
	if _frames != null:
		_frames.call("flush")
	if not _walk_tmp.is_empty() and FileAccess.file_exists(_walk_tmp):
		DirAccess.remove_absolute(_walk_tmp)


func _identity() -> Dictionary:
	var v: Dictionary = Engine.get_version_info()
	var id: Dictionary = {"schema": "thirdlife.exe/1", "kind": "boot", "verb": verb if not verb.is_empty() else "visit", "exported": exported(),
		"godot": str(v.get("string", "")), "executable": OS.get_executable_path().replace("\\", "/"), "games": games_dir,
		"display": DisplayServer.get_name(), "user_dir": OS.get_user_data_dir().replace("\\", "/"), "plots": kept, "sites": kept_sites, "left_out": dropped}
	if not tag.is_empty():
		id["build"] = tag                          # absent value: the key is left out
	return id


# ------------------------------------------------------------------------------------------------ a person walks
func _visit() -> void:
	_read_env()
	if not _window_setup("the village needs a window (started headless); `-- check --out=<file>` is the run without one"):
		return
	_open_world()


## The instruments of unattended starts (TL_EXE_CAPTURE, _QUIT_AT, _CAPTURE_AT, _KEYS).
func _read_env() -> void:
	_capture_path = _win_path(OS.get_environment("TL_EXE_CAPTURE")) if OS.has_environment("TL_EXE_CAPTURE") else ""
	if OS.has_environment("TL_EXE_QUIT_AT") and OS.get_environment("TL_EXE_QUIT_AT").is_valid_int():
		_quit_at = int(OS.get_environment("TL_EXE_QUIT_AT"))
	if OS.has_environment("TL_EXE_CAPTURE_AT") and OS.get_environment("TL_EXE_CAPTURE_AT").is_valid_int():
		_capture_at = int(OS.get_environment("TL_EXE_CAPTURE_AT"))
	for part: String in OS.get_environment("TL_EXE_KEYS").split(";", false):
		var f: PackedStringArray = part.strip_edges().split(":")
		if f.size() == 2 and f[0].is_valid_int() and f[1].begins_with("~") and f[1].substr(1).split(",").size() == 2:
			var xy: PackedStringArray = f[1].substr(1).split(",")
			if not _keys.has(int(f[0])):
				_keys[int(f[0])] = []
			(_keys[int(f[0])] as Array).append(["move", Vector2(float(xy[0]), float(xy[1]))])
			continue
		var code: Key = OS.find_keycode_from_string(f[1].substr(1)) if f.size() == 2 and f[1].length() > 1 else KEY_NONE
		if f.size() == 2 and f[0].is_valid_int() and code != KEY_NONE and (f[1][0] == "+" or f[1][0] == "-"):
			if not _keys.has(int(f[0])):
				_keys[int(f[0])] = []
			(_keys[int(f[0])] as Array).append([f[1][0] == "+", code])
		else:
			print("[boot] TL_EXE_KEYS: cannot read '%s' (wanted <frame>:+<Key> or <frame>:-<Key>)" % part)
	_unattended = not _capture_path.is_empty() or _quit_at >= 0 or not _keys.is_empty()


## The person's window: where it opens, its title, vsync. False (after `_stop`) when the run is headless.
func _window_setup(headless_reason: String) -> bool:
	if DisplayServer.get_name() == "headless":
		_stop(headless_reason, 2)
		return false
	if OS.has_environment("TL_EXE_WINDOW_POS"):
		var xy: PackedStringArray = OS.get_environment("TL_EXE_WINDOW_POS").split(",")
		if xy.size() == 2 and xy[0].is_valid_int() and xy[1].is_valid_int():
			DisplayServer.window_set_position(Vector2i(int(xy[0]), int(xy[1])))
	get_window().title = "Third Life"
	# the project runs windows without vsync (captures and benches); a person's window follows the screen
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	return true


## The village in the window (the visitor, the games). From the menu (L4) Esc returns to the menu instead of ending.
func _open_world() -> void:
	if menu_mode:
		kept.clear()
		dropped.clear()
		kept_sites.clear()
	var path: String = _make_walk()
	if path.is_empty():
		return
	print(JSON.stringify(_identity(), "", false))
	get_tree().auto_accept_quit = false            # closing the window ends the world cleanly (see _notification)
	view = (load(VIEW_SCRIPT) as GDScript).new()
	view.name = "WorldView"
	add_child(view)
	var vo: Dictionary = {"walk": path, "live": "true"}
	if OS.get_environment("TL_EXE_WARM") == "1":
		vo.erase("live")                           # P14: the scripted tour, to its end (export.sh fills the shipped cache)
	for k: String in ["record", "input"]:
		if opts.has(k):
			vo[k] = opts[k]
	view.call("start", vo)
	world = view.get("world")
	if view.get("draw") == null:
		# the viewer said why on the log and asked the tree to quit; a person gets the reason in a box
		var why: String = "the world did not load"
		if world != null:
			if not str(world.get("refused")).is_empty():
				why = str(world.get("refused"))
			elif not (world.get("errors") as Array).is_empty():
				why = "; ".join(PackedStringArray(world.get("errors")))
		_stop("Third Life could not start: %s. What it printed is in ThirdLife-last-run.log beside ThirdLife.exe." % why, 1)
		return
	if menu_mode:
		# L4: the end of the walk (Esc) returns to the menu; the viewer's own handler would end the process
		world.disconnect("ended", Callable(view, "_on_world_ended"))
		world.connect("ended", Callable(hub, "on_menu_world_ended"))
	var layer: CanvasLayer = CanvasLayer.new()
	_hint_layer = layer
	layer.name = "BootHint"
	layer.layer = 100
	add_child(layer)
	_hint = Label.new()
	_hint.text = _keys_walk()
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.9))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(28, get_viewport().get_visible_rect().size.y - 58)
	layer.add_child(_hint)
	if not tag.is_empty():
		# which build is this: small, in the top right corner, in the key line's look
		var tl: Label = Label.new()
		tl.name = "BuildTag"
		tl.text = tag
		tl.add_theme_font_size_override("font_size", 14)
		tl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		tl.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.7))
		tl.add_theme_constant_override("outline_size", 4)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		tl.offset_left = -360
		tl.offset_right = -14
		tl.offset_top = 10
		layer.add_child(tl)
	if OS.has_environment("TL_EXE_TRACE") and _trace == null:
		_trace = FileAccess.open(_win_path(OS.get_environment("TL_EXE_TRACE")), FileAccess.WRITE)
	if OS.has_environment("TL_EXE_FRAMES") and _frames == null:
		_frames = Frames.new()
		_frames.call("start", self, _win_path(OS.get_environment("TL_EXE_FRAMES")))
	process_physics_priority = 200000              # after the viewer (100000): its `stage` of this tick is known
	set_physics_process(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and view != null:
		_end_world()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and (menu_mode or dungeon_only):
		_end_world()                               # L4: the menu, a dungeon or Create: the process ends


## Ends the world the way a scripted run ends: the world host stops its watchdog and its helper process, prints its
## lines, and the viewer quits the tree with the world's exit code.
func _end_world() -> void:
	if _ending:
		return
	_ending = true
	set_physics_process(false)
	var dg: Node = hub.get("dungeon") if hub != null else null
	if dg != null and is_instance_valid(dg):
		dg.call("close", "quit")                   # L4: its `left` ends the process (the hub sees _ending)
		return
	if world != null and is_instance_valid(world) and not bool(world.get("_ended")):
		print("[boot] ending the world at frame %d" % _frame)
		world.call("_end")
	else:
		get_tree().quit(0)


func _physics_process(_delta: float) -> void:
	_frame += 1
	# M2-PATCHES 2: a key TL_EXE_KEYS holds is pressed again when the engine let go of it (another window took the focus)
	for k: Variant in _keys_held.keys():
		if not Input.is_physical_key_pressed(int(k)):
			var again: InputEventKey = InputEventKey.new()
			again.keycode = int(k)
			again.physical_keycode = int(k)
			again.pressed = true
			Input.parse_input_event(again)
	if _frame == 2:
		var override := OS.get_environment("TL_EXE_AA")
		var style := preload("res://kernel/standin/tl_standin.gd").ext("TLStyle")
		var settings: Dictionary = style.get("data").get("env", {}) if style != null else {}
		_set_aa(override if not override.is_empty() else str(settings.get("exe_aa", EXE_AA)))
	for k: Array in _keys.get(_frame, []):
		if str(k[0]) == "move":
			var mv: InputEventMouseMotion = InputEventMouseMotion.new()
			mv.relative = k[1]
			Input.parse_input_event(mv)
			continue
		var ev: InputEventKey = InputEventKey.new()
		ev.keycode = k[1]
		ev.physical_keycode = k[1]
		ev.pressed = bool(k[0])
		Input.parse_input_event(ev)
		if bool(k[0]):
			_keys_held[int(k[1])] = true
		else:
			_keys_held.erase(int(k[1]))
	if view == null or not is_instance_valid(view):
		_menu_frame()                              # L4: the menu, a dungeon or Create is on the screen, no world
		return
	var stage: int = int(view.get("stage"))
	if _trace != null and _frame % 30 == 0:
		var pos: Vector3 = world.get("player_pos")
		var feet: Vector3 = (view.get("visitor") as Node3D).get("feet")
		_trace.store_line(JSON.stringify({"frame": _frame, "world_tick": int(world.get("tick")), "stage": stage,
			"pos": [snappedf(pos.x, 0.01), snappedf(pos.z, 0.01)], "feet": [snappedf(feet.x, 0.01), snappedf(feet.y, 0.01), snappedf(feet.z, 0.01)],
			"yaw_deg": snappedf(rad_to_deg(float((view.get("visitor") as Node3D).get("look_yaw"))), 0.01)}, "", false))
		_trace.flush()
	if _hint != null:
		_hint.text = (str(view.get("visit").call("stage_hint")) if view.get("visit") != null else KEYS_STAGE) if stage >= 0 else _keys_walk()   # K8: Esc alone when the game uses Q
		var bm: Variant = (view.get("landscape") as Node).get_meta(&"tl_build_mode") if view.get("landscape") is Node and (view.get("landscape") as Node).has_meta(&"tl_build_mode") else null
		_hint.visible = not (is_instance_valid(bm) and bool((bm as Node).get("active")))   # WP2: build mode's hotbar shows its own keys
		_hint.position.y = get_viewport().get_visible_rect().size.y - 58
	if not _capture_path.is_empty() and not _capture_done and _frame >= _capture_at:
		_capture_done = true
		_capture()
	if _quit_at >= 0 and _frame >= _quit_at and (_capture_path.is_empty() or _captured):
		_end_world()


func _capture() -> void:
	for i: int in 3:
		await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_capture_path.get_base_dir())
	var err: Error = img.save_png(_capture_path)
	print(JSON.stringify({"schema": "thirdlife.exe/1", "kind": "capture", "out": _capture_path, "saved": err == OK, "frame": _frame,
		"width": img.get_width(), "height": img.get_height(), "driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name()}, "", false))
	_captured = true


## Frame two uses TL_EXE_AA first, then the installed style's env.exe_aa, then the classic EXE_AA.
## Accepted controls are msaa 0/2/4/8, ss off/fxaa/smaa and taa 0/1. The boot report records the viewport values.
func _set_aa(spec: String) -> void:
	var vp: Viewport = get_viewport()
	for part: String in spec.split(",", false):
		var kv: PackedStringArray = part.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"msaa": vp.msaa_3d = {"0": Viewport.MSAA_DISABLED, "2": Viewport.MSAA_2X, "4": Viewport.MSAA_4X, "8": Viewport.MSAA_8X}.get(kv[1], vp.msaa_3d)
			"ss": vp.screen_space_aa = {"off": Viewport.SCREEN_SPACE_AA_DISABLED, "fxaa": Viewport.SCREEN_SPACE_AA_FXAA, "smaa": Viewport.SCREEN_SPACE_AA_SMAA}.get(kv[1], vp.screen_space_aa)
			"taa": vp.use_taa = kv[1] == "1"
	print(JSON.stringify({"schema": "thirdlife.exe/1", "kind": "aa", "msaa_3d": vp.msaa_3d, "screen_space_aa": vp.screen_space_aa, "taa": vp.use_taa}, "", false))


# ------------------------------------------------------------------------------------------------ the check
## The scripted tour of the village without a window: the world host alone, as `world.sh tour <walk> --headless`
## runs it. Its lines (one per pack with `state_hash`) go to --out; what this build is goes to <out>.boot.json.
func _check() -> void:
	if not opts.has("out") or not str(opts["out"]).is_absolute_path():
		_stop("check: --out=<abs file> is required", 2)
		return
	var path: String = _make_walk()
	if path.is_empty():
		return
	var id_line: String = JSON.stringify(_identity(), "", false)
	print(id_line)
	DirAccess.make_dir_recursive_absolute(str(opts["out"]).get_base_dir())
	var f: FileAccess = FileAccess.open(str(opts["out"]) + ".boot.json", FileAccess.WRITE)
	if f == null:                          # hunt2 C9: a report that cannot be written is never a clean exit
		_stop("check: cannot write %s.boot.json" % str(opts["out"]), 2)
		return
	f.store_string(id_line + "\n"); f.close()
	world = (load(WORLD_SCRIPT) as GDScript).new()
	world.name = "World"
	add_child(world)
	world.call("start", {"walk": path, "out": str(opts["out"])})    # ends the process itself: 0, 1 (a pack failed) or 2 (refused)


# ------------------------------------------------------------------------------------------------ L4
func _keys_walk() -> String:
	return KEYS_WALK.replace("Esc  quit", "Esc  menu") if menu_mode else KEYS_WALK


## No world on the screen (the menu, a dungeon, Create): the unattended capture and quit frame still count.
func _menu_frame() -> void:
	if not _capture_path.is_empty() and not _capture_done and _frame >= _capture_at:
		_capture_done = true
		_capture()
	if _quit_at >= 0 and _frame >= _quit_at and (_capture_path.is_empty() or _captured):
		_end_world()
