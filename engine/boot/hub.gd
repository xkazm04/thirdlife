extends RefCounted
## L4 (night of 21 Nov): the main menu and the dungeons of the exe; boot.gd (held at 600 lines) hands them to this file.
## No class_name; `b` is the boot node (its options, its walk, its world and viewer, its scripted keys).
##
## A person's start with no arguments (and no TL_EXE_* instrument in the environment) shows the main menu (boot/menu.gd):
##   World     the village, as before; Esc there ends the walk and returns to the menu (the world and its viewer freed)
##   Dungeons  engine/boot/dungeons.json: one pack alone (kernel/dungeon/dungeon.gd) with its own camera, HUD and look;
##             no world is loaded; Esc opens the pause card (Resume, Leave: back to the menu, the default look again)
##   Create    res://ui/create/create.tscn when it is in the build (its root: open(), signal closed); else "coming tonight"
##   Quit
## Every flag path (check, probe, tag, --record, --input, --site-job, --games, ...) and every unattended start
## (TL_EXE_CAPTURE, _CAPTURE_AT, _QUIT_AT, _KEYS, _WARM, _TRACE, _FRAMES) goes straight to the village exactly as before
## (menu_decision); `--menu` or TL_EXE_MENU=1 shows the menu anyway (scripted clips).
##   ThirdLife.exe -- --dungeon=<pack dir> [--look=<name>] [--seed=N]   that pack straight as a dungeon; its "Back to
##                    Create" ends the process (L3's "Try it" starts it so: kernel/dungeon/dungeons.gd `launch`)
##   ... --headless -- --dungeon=<dir> --frames=N [--seed=N] [--out=<abs file>]   a counted dungeon without a window:
##                    ends after N frames, prints (and writes) its state hash; exit 0, 1 (a script error), 2 (refused)
##   ... -- --tripped=<record> [--back=<label>] [--then=menu|quit] [--out=<abs file>]   L4b: the card of a dungeon the
##                    watchdog stopped (kernel/dungeon/watch.gd starts this process on its record, then ends its own):
##                    Leave goes to the menu (then=menu) or ends this process with exit code 3 (then=quit, a Try-it run)
##   ... --headless -- trips --out=<abs file> [--trips=3] [--ticks=600] [--frames=600] [--dungeon-index=0]
##                    menu -> World -> menu -> dungeon -> menu, N times, a census at every menu (selftest 640)
## A census line (`"kind":"census"`) is printed at every menu, in the world once it stands (240 frames) and in a dungeon
## (60 frames): nodes, objects, resources, orphan nodes, video memory, static memory (debug binaries only).

const MENU_SCRIPT: String = "res://boot/menu.gd"
const DUNGEON_SCRIPT: String = "res://kernel/dungeon/dungeon.gd"
const DUNGEON_LIST: String = "res://kernel/dungeon/dungeons.gd"
const CREATE_SCENE: String = "res://ui/create/create.tscn"
const WORLD_SCRIPT: String = "res://kernel/world/world.gd"
## the instruments of unattended starts: any of them in the environment means "the village, as before" (not the menu)
const UNATTENDED_ENV: Array = ["TL_EXE_CAPTURE", "TL_EXE_CAPTURE_AT", "TL_EXE_QUIT_AT", "TL_EXE_KEYS", "TL_EXE_WARM", "TL_EXE_TRACE", "TL_EXE_FRAMES"]

var b = null                            # the boot node (untyped: its members are read by name)
var menu: CanvasLayer = null
var dungeon: Node = null
var create_node: Node = null
var dungeon_rows: Array = []            # [{pack, title, look?, dir, pack_id?}]
var census: Array = []                  # the census lines (and the trips' world and dungeon results)
var _menus_shown: int = 0
var _trips_left: int = 0
var _trip_n: int = 0


func _init(boot: Node) -> void:
	b = boot


## The menu is for a person's start: no verb, no flag, no unattended instrument, a window.
func menu_wanted() -> bool:
	var env: Dictionary = {}
	for k: String in UNATTENDED_ENV + ["TL_EXE_MENU"]:
		if OS.has_environment(k):
			env[k] = OS.get_environment(k)
	return menu_decision(b.opts, env, DisplayServer.get_name() == "headless")


## The decision alone (selftest 640 asks it for every old flag path): the command line's options, the TL_EXE_* variables
## that are set, and whether the run is headless. A verb (check, probe, tag, trips) never gets here.
static func menu_decision(o: Dictionary, env: Dictionary, headless: bool) -> bool:
	if o.has("menu") or str(env.get("TL_EXE_MENU", "")) == "1":
		return true
	if not o.is_empty() or headless:
		return false
	for k: String in UNATTENDED_ENV:
		if env.has(k):
			return false
	return true


func menu_start() -> void:
	b.menu_mode = true
	b._read_env()
	if not b._window_setup("the menu needs a window (started headless)"):
		return
	b.get_tree().auto_accept_quit = false          # closing the window ends what is open cleanly (boot _notification)
	var id: Dictionary = b._identity()
	id["verb"] = "menu"
	print(JSON.stringify(id, "", false))
	b.process_physics_priority = 200000
	b.set_physics_process(true)
	show_menu()


## The dungeons of engine/boot/dungeons.json with their folders in this build ("" when it does not carry one).
func load_rows() -> Array:
	var list: GDScript = load(DUNGEON_LIST) as GDScript
	var r: Dictionary = list.call("read")
	for e: String in r["errors"]:
		print("[boot] dungeons.json: " + e)
	var out: Array = []
	for d: Dictionary in r["dungeons"]:
		var row: Dictionary = d.duplicate()
		row["dir"] = str(list.call("resolve", str(d["pack"]), str(b.games_dir)))
		if not str(row["dir"]).is_empty():
			var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(row["dir"]) + "/pack.json"))
			if m is Dictionary and (m as Dictionary).has("id"):
				row["pack_id"] = str(m["id"])
		else:
			print("[boot] dungeon '%s' (%s) is not in this build" % [str(d["title"]), str(d["pack"])])
		out.append(row)
	return out


func show_menu() -> void:
	if menu != null and is_instance_valid(menu):
		return
	dungeon_rows = load_rows()
	menu = (load(MENU_SCRIPT) as GDScript).new()
	b.add_child(menu)
	menu.call("open", dungeon_rows, str(b.tag), ResourceLoader.exists(CREATE_SCENE))
	menu.connect("world", _menu_world)
	menu.connect("dungeon", _menu_dungeon)
	menu.connect("create", _menu_create)
	menu.connect("quit", _menu_quit)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menus_shown += 1
	census_later("menu", _menus_shown)


func _free_menu() -> void:
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
	menu = null


## A census of this process `wait` frames later (what was freed is gone by then); nothing when what it was meant to
## count was left meanwhile. One JSON line on the log; the trips verb writes them to its --out.
func census_later(at: String, n: int, wait: int = 3) -> void:
	for i: int in wait:
		await b.get_tree().process_frame
	if (at == "world" and (b.world == null or not is_instance_valid(b.world))) or (at == "dungeon" and (dungeon == null or not is_instance_valid(dungeon))):
		return
	var line: Dictionary = {"schema": "thirdlife.exe/1", "kind": "census", "at": at, "n": n, "frame": int(b._frame),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"video_mb": snappedf(float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / 1048576.0, 0.01)}
	if OS.get_static_memory_usage() > 0:              # a release template (the exe) does not count it: the key is left out
		line["static_mb"] = snappedf(float(OS.get_static_memory_usage()) / 1048576.0, 0.01)
	census.append(line)
	print(JSON.stringify(line, "", false))


func _menu_quit() -> void:
	print("[boot] quit from the menu")
	b._end_world()


func _menu_world() -> void:
	_free_menu()
	print("[boot] menu: World")
	if b.verb == "trips":
		_trip_world()
	else:
		b._open_world()
	census_later("world", _menus_shown, 240)       # in the world, once it stands: what leaving it must give back


## Esc in the village (the visitor quits: the walk ends, the world prints its lines): the viewer lets go of what it
## drew, the world and its viewer are freed, the menu is back. A close request meanwhile ends the process as before.
func on_menu_world_ended(bad: bool) -> void:
	var view: Node = b.view
	if b._ending:
		view.call("_on_world_ended", bad)           # the viewer's own end: it quits with the world's exit code
		return
	if view.get("visit") != null:
		view.get("visit").call("finish")
	if view.get("draw") != null:
		view.get("draw").call("clear")
	close_world()
	show_menu()


func close_world() -> void:
	var world: Node = b.world
	if world != null and is_instance_valid(world) and world.get("logger") != null:
		OS.remove_logger(world.get("logger"))      # the world adds one and never removes it (it used to end the process)
	var gone: Node = b.view if b.view != null and is_instance_valid(b.view) else world
	b.view = null
	b.world = null
	b._hint = null
	if b._hint_layer != null and is_instance_valid(b._hint_layer):
		b._hint_layer.queue_free()
	b._hint_layer = null
	if gone != null and is_instance_valid(gone):
		gone.queue_free()
	if not str(b._walk_tmp).is_empty() and FileAccess.file_exists(b._walk_tmp):
		DirAccess.remove_absolute(b._walk_tmp)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _menu_dungeon(i: int) -> void:
	if i < 0 or i >= dungeon_rows.size() or str((dungeon_rows[i] as Dictionary).get("dir", "")).is_empty():
		return
	var row: Dictionary = dungeon_rows[i]
	_free_menu()
	print("[boot] menu: dungeon '%s' (%s)" % [str(row["title"]), str(row["pack"])])
	var o: Dictionary = {"title": str(row["title"]), "back": "Leave"}
	if row.has("look"):
		o["look"] = str(row["look"])
	if b.verb == "trips":
		o["frames"] = int(b.opts.get("frames", "600"))
	open_dungeon(str(row["dir"]), o)


func _menu_create() -> void:
	if not ResourceLoader.exists(CREATE_SCENE):
		return
	_free_menu()
	print("[boot] menu: Create")
	create_node = (load(CREATE_SCENE) as PackedScene).instantiate()
	b.add_child(create_node)
	if create_node.has_signal("closed"):
		create_node.connect("closed", _on_create_closed)
	if create_node.has_method("open"):
		create_node.call("open")


func _on_create_closed() -> void:
	if create_node != null and is_instance_valid(create_node):
		create_node.queue_free()
	create_node = null
	if b._ending:
		b.get_tree().quit(0)
		return
	show_menu()


# ------------------------------------------------------------------------------------------------ a dungeon
## No world is loaded when a dungeon opens (the menu is between them); the dungeon brings its own camera, HUD and look.
## The boot node keeps running while the dungeon's pause card pauses the tree (the scripted keys, the capture, the quit).
func open_dungeon(dir: String, o: Dictionary) -> void:
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	dungeon = (load(DUNGEON_SCRIPT) as GDScript).new()
	b.add_child(dungeon)
	dungeon.connect("left", _on_dungeon_left)
	var trip: String = "%s/dungeon_trip_%d.json" % [OS.get_user_data_dir().replace("\\", "/"), OS.get_process_id()]
	o["trip"] = trip
	o["relaunch"] = relaunch_args(trip, str(o.get("back", "Leave")))
	var ok: bool = await dungeon.call("open", dir, o)
	if ok and DisplayServer.get_name() != "headless":
		_set_aa_of_style()                         # the dungeon's look names its own antialiasing
	if ok and b.menu_mode:
		census_later("dungeon", _menus_shown, 60)


func _set_aa_of_style() -> void:
	var override := OS.get_environment("TL_EXE_AA")
	var style := preload("res://kernel/standin/tl_standin.gd").ext("TLStyle")
	var settings: Dictionary = style.get("data").get("env", {}) if style != null else {}
	b._set_aa(override if not override.is_empty() else str(settings.get("exe_aa", b.EXE_AA)))


## L4b: the arguments of the process the watchdog starts on its record: the same executable (the editor binary with
## --path and the boot scene), headless when this one is, `-- --tripped=<record>`, where Leave goes, and --out.
func relaunch_args(record: String, back: String) -> PackedStringArray:
	var a: PackedStringArray = PackedStringArray()
	if DisplayServer.get_name() == "headless":
		a.append_array(["--headless", "--fixed-fps", "60"])
	if not OS.has_feature("thirdlife_exe"):
		a.append_array(["--path", ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/"), "res://boot/boot.tscn"])
	a.append_array(["--", "--tripped=" + record, "--back=" + back, "--then=" + ("quit" if b.dungeon_only else "menu")])
	if str(b.opts.get("out", "")).is_absolute_path():
		a.append("--out=" + str(b.opts["out"]))
	return a


## The process the watchdog started: the card, then the menu (then=menu) or the end (then=quit, exit code 3).
func tripped_start() -> void:
	var then: String = str(b.opts.get("then", "menu"))
	b.dungeon_only = then == "quit"
	b.menu_mode = then == "menu"
	b._read_env()                                  # TL_EXE_KEYS press Leave in a scripted run (selftest 640), also headless
	if DisplayServer.get_name() != "headless":
		if not b._window_setup(""):
			return
		b.get_tree().auto_accept_quit = false
	b.process_physics_priority = 200000
	b.set_physics_process(true)
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	dungeon = (load(DUNGEON_SCRIPT) as GDScript).new()
	b.add_child(dungeon)
	dungeon.connect("left", _on_dungeon_left)
	dungeon.call("open_tripped", str(b.opts["tripped"]), {"back": str(b.opts.get("back", "Leave"))})


func _on_dungeon_left(why: String) -> void:
	var d: Node = dungeon
	dungeon = null
	var res: Dictionary = d.get("result") if d != null else {}
	if d != null and is_instance_valid(d):
		d.queue_free()
	b.process_mode = Node.PROCESS_MODE_INHERIT
	if b.dungeon_only:
		var code: int = 0
		if why == "refused":
			code = 2
		elif why == "tripped":
			code = 3                               # RUNNER.md: the watchdog had to stop it
		elif why == "error" or int(res.get("script_errors", 0)) > 0 or int(res.get("engine_errors", 0)) > 0:
			code = 1
		var out: String = str(b.opts.get("out", ""))
		if out.is_absolute_path():
			DirAccess.make_dir_recursive_absolute(out.get_base_dir())
			var f: FileAccess = FileAccess.open(out, FileAccess.WRITE)
			if f == null:
				code = 2
			else:
				f.store_string(JSON.stringify(res, "", false) + "\n")
				f.close()
		print("[boot] the dungeon ended (%s): exit code %d" % [why, code])
		b.get_tree().quit(code)
		return
	if b._ending:
		b.get_tree().quit(0)
		return
	if b.verb == "trips":
		census.append(res)
	elif DisplayServer.get_name() != "headless":
		_set_aa_of_style()                         # the default look's antialiasing again
	show_menu()
	if b.verb == "trips":
		_trip_next.call_deferred()


## --dungeon=<pack dir>: that pack straight as a dungeon, a window and a "Back to Create" that ends the process; headless
## only as a counted run (--frames=N), which prints its state hash and ends (exit 0, 1 a script error, 2 refused).
func dungeon_start() -> void:
	b.dungeon_only = true
	var opts: Dictionary = b.opts
	var o: Dictionary = {"back": "Back to Create"}
	for k: String in ["seed", "frames"]:
		if opts.has(k):
			if not str(opts[k]).is_valid_int():
				b._stop("--%s must be a whole number" % k, 2)
				return
			o[k] = int(opts[k])
	if opts.has("look"):
		o["look"] = str(opts["look"])
	if DisplayServer.get_name() == "headless":
		if int(o.get("frames", 0)) <= 0:
			b._stop("--dungeon without a window is a counted run: give --frames=N", 2)
			return
	else:
		b._read_env()
		if not b._window_setup(""):
			return
		b.get_tree().auto_accept_quit = false
		b.process_physics_priority = 200000
		b.set_physics_process(true)
	# a listed dungeon keeps its title and look
	var dir: String = str(opts["dungeon"]).trim_suffix("/")
	for row: Dictionary in load_rows():
		if not str(row["dir"]).is_empty() and str(row["dir"]).simplify_path() == dir.simplify_path():
			o["title"] = str(row["title"])
			if row.has("look") and not o.has("look"):
				o["look"] = str(row["look"])
	print("[boot] --dungeon=%s" % dir)
	open_dungeon(dir, o)


# ------------------------------------------------------------------------------------------------ the trips
## `-- trips`: menu -> World (headless: the world host runs the village walk for --ticks) -> menu -> dungeon (a counted
## run of --frames) -> menu, --trips times, through the same functions the menu's buttons call. A census at every menu.
func trips_start() -> void:
	if not b.opts.has("out") or not str(b.opts["out"]).is_absolute_path():
		b._stop("trips: --out=<abs file> is required", 2)
		return
	b.menu_mode = true
	_trips_left = int(b.opts.get("trips", "3"))
	b.set_physics_process(true)
	show_menu()
	_trip_next.call_deferred()


func _trip_next() -> void:
	for i: int in 5:
		await b.get_tree().process_frame           # the census of this menu is taken first
	if _trips_left <= 0:
		_trips_end()
		return
	if _trip_n % 2 == 0:
		_menu_world()
	else:
		_trips_left -= 1
		_menu_dungeon(int(b.opts.get("dungeon-index", "0")))
	_trip_n += 1


func _trip_world() -> void:
	b.kept.clear()
	b.dropped.clear()
	b.kept_sites.clear()
	if not b.opts.has("ticks"):
		b.opts["ticks"] = "600"
	var path: String = b._make_walk()
	if path.is_empty():
		return
	var world: Node = (load(WORLD_SCRIPT) as GDScript).new()
	world.name = "World"
	world.set("quit_on_end", false)
	b.world = world
	b.add_child(world)
	world.connect("ended", _on_trip_world_ended)
	world.call("start", {"walk": path})


func _on_trip_world_ended(bad: bool) -> void:
	census.append({"kind": "world", "n": _trip_n, "bad": bad, "ticks": int(b.world.get("tick"))})
	close_world()
	show_menu()
	_trip_next.call_deferred()


func _trips_end() -> void:
	var f: FileAccess = FileAccess.open(str(b.opts["out"]), FileAccess.WRITE)
	if f == null:
		b._stop("trips: cannot write %s" % str(b.opts["out"]), 2)
		return
	for line: Dictionary in census:
		f.store_line(JSON.stringify(line, "", false))
	f.close()
	print("[boot] trips done: %d lines in %s" % [census.size(), str(b.opts["out"])])
	b.get_tree().quit(0)
