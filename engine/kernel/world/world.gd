extends Node
## N2. The world host: several packs alive in one process, each in its own holder (kernel/world/pack.gd) with its
## own context, input record, seeded generator, tick counter and physics space.
##
##   <godot> --headless --fixed-fps 60 --path <engine> res://kernel/host/host.tscn -- world --packs=<dir>,<dir>,...
##           [--frames=N] [--seeds=..] [--at=x:y:z,..] [--spacing=M] [--every=N,..] [--pause=i:from:len;..]
##           [--mode=smoke|bot] [--space=own|shared] [--trace=N] [--hold=N] [--state=1] [--out=<file>]
##   (tools/world.sh run does this.)
##
## List options take one value per pack, or one value for all. Output: one JSON line per pack (`"kind":"pack"`, with
## its state hash) and one for the world (`"kind":"world"`), schema tl.world/1. Exit code 0 when every pack loaded
## and no pack logged an error, else 1.
##
## One world tick, in this node's `_physics_process` (it runs before every other node):
##   1. a pack whose last tick has been stepped is finished (state hash, teardown) and switched off;
##   2. every other pack is asked whether it gets this world tick (`--every`, `--pause`); the ones that do not are
##      switched off (scripts and space), the ones that do are switched on and ticked: `ctx.frame` = the pack's own
##      tick count -> bot -> input latch -> `_pack_tick`;
##   3. the scene tree then ticks the nodes of the packs that are on, pack by pack, and the physics server steps the
##      spaces that are active. A pack that is off costs nothing in either.
## A pack's hash depends on its own tick count and its own input only, never on the world tick.
##
## N5a. A SCHEDULED world (`--walk=<script>` or `--replay=<world log>`): the scheduler (kernel/world/tiers.gd) decides
## every world tick which packs get it, from the player's scripted position and tiers.json; the run lasts the
## script's `ticks` world ticks; every decision is an event (`"kind":"event"` lines, `--log=<file>`), and a log
## replays to the same ticks and hashes. `--world=<file>` loads a world file (tl.world/1), `--save=<file>` writes
## one when the run ends. kernel/world/TIERS.md has the model, the proof and the numbers.

## N7. A world with a VISITOR (walk script `"visitor": true`): nobody is on stage until the visitor enters a plot
## (`events`: `enter`, `leave`), a game that ended by itself starts its next round after a pause, and whoever draws
## the world listens to `plot_event` and `ended` (kernel/world/draw/view.gd). kernel/world/WORLD.md.

signal plot_event(index: int, what: String, ev: Dictionary)   # "before_tier", "tier", "rebuilt": for whoever draws
signal ended(bad: bool)                                       # the run is over; the packs are freed right after

const PackScript: GDScript = preload("res://kernel/world/pack.gd")
const LoggerScript: GDScript = preload("res://kernel/runner/logger.gd")
const Tiers: GDScript = preload("res://kernel/world/tiers.gd")
const PlotFile: GDScript = preload("res://kernel/world/plotfile.gd")   # P5: the world file and a pack directory's hash (moved out: this file may not grow)
const Jobs: GDScript = preload("res://kernel/world/jobs.gd")           # P5: the build queue
const PACK_BASES: Array = ["res://seeds", "res://kernel/examples", "res://kernel/world/packs", "res://packs"]
const FOREVER: int = 1 << 40
const GuardScript: GDScript = preload("res://kernel/host/guard.gd")   # P1: the watchdog of this host (processor time per pack tick)

var opts: Dictionary = {}
var logger: Object
var packs: Array = []
var tick: int = 0
var hold_left: int = 0
var show_state: bool = false
var errors: Array = []
var pauses: Array = []                  # [pack index or -1 for all, from world tick, length]
var _last_usec: int = 0
var _last_due: int = 0
var _iter_all: PackedInt64Array = PackedInt64Array()      # iterations in which every pack was ticked
var _iter_any: PackedInt64Array = PackedInt64Array()      # every iteration with at least one pack still open
var _iter_hold: PackedInt64Array = PackedInt64Array()     # iterations of the hold phase (every pack switched off)
var _kernel_usec: PackedInt64Array = PackedInt64Array()   # this node's own work per world tick (calls into packs)
var _ended: bool = false
var _t_start: int = 0
var _load_ms: int = 0
var _mem_before: int = 0
var _mem_loaded: int = 0
# N5a: the scheduled world
var sched: RefCounted = null            # kernel/world/tiers.gd
var walk: Dictionary = {}               # the walk script (tl.walk/1)
var walk_ticks: int = 0
var player_script: Array = []           # [[world tick, [x, y, z]], ...]
var player_pos: Vector3 = Vector3.ZERO
var is_replay: bool = false
var replay_events: Dictionary = {}      # world tick -> events of a world log
var cost_measured: bool = false
var plot_defs: Array = []               # per pack: {id, dir, seed, origin, yaw, mode, frames, every, at, trace, own_space, ticks_before, data}
var ledger: Dictionary = {}             # pack index -> the plot record of a pack that is not in memory
var world_in: Dictionary = {}           # the world file this world was loaded from
var refused: String = ""                # a world file or walk script that could not be read: nothing runs
var _last_ticked: Array = []
var _event_lines: PackedStringArray = PackedStringArray()
var _load_marks: Array = []             # [[pack name, ms]]: how long each pack took to load
var _save_error: String = ""
# N7
var quit_on_end: bool = true            # false: the host of this world (the viewer) ends the process
var exit_code: int = 0
var _guard: RefCounted = GuardScript.new()   # P1: ends the process on a runaway tick; host.gd runs the world again without that pack
var _dead: PackedStringArray = PackedStringArray()   # P1: indices (as text) of packs that ran away in an earlier run: not loaded, never ticked
var player_live: bool = false           # true: `player_pos` is set from outside every tick (a person walks)
var jobs: RefCounted = null             # P5: the build queue (kernel/world/jobs.gd); null = every pack is built before the first tick


func _list(key: String, fallback: String) -> PackedStringArray:
	return str(opts.get(key, fallback)).split(",", false)


func _item(list: PackedStringArray, i: int, fallback: String) -> String:
	if list.is_empty():
		return fallback
	return list[i] if i < list.size() else list[list.size() - 1]


func start(options: Dictionary) -> void:
	opts = options
	print("[tl] world start")
	_t_start = Time.get_ticks_msec()
	process_physics_priority = -100000
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(false)
	logger = LoggerScript.new()
	OS.add_logger(logger)
	_guard.call("start", 250, str(opts.get("trip", "")))
	_dead = str(opts.get("dead", "")).split(",", false)
	for e: String in TLLaws.load_tables():
		errors.append("kernel data: " + e)
	var headless: bool = DisplayServer.get_name() == "headless"
	TLStandin.prepare_style(headless)
	if not headless:
		TLStandin.install_look(self)
	get_tree().node_added.connect(_on_node_added)
	show_state = opts.has("state")
	hold_left = int(opts.get("hold", "0"))
	for part: String in str(opts.get("pause", "")).split(";", false):
		var f: PackedStringArray = part.split(":")
		if f.size() == 3:
			pauses.append([-1 if f[0] == "all" else int(f[0]), int(f[1]), int(f[2])])
		else:
			errors.append("--pause wants <pack index or all>:<from world tick>:<ticks>, got '%s'" % part)
	_mem_before = OS.get_static_memory_usage()
	if opts.has("walk") or opts.has("replay"):
		_start_walk()
	elif opts.has("world"):
		_start_from_file()
	else:
		var dirs: PackedStringArray = _list("packs", "")
		var frames: PackedStringArray = _list("frames", "3600")
		var seeds: PackedStringArray = _list("seeds", "1")
		var ats: PackedStringArray = _list("at", "")
		var everys: PackedStringArray = _list("every", "1")
		var spacing: float = float(opts.get("spacing", "0"))
		for i: int in dirs.size():
			var at: Vector3 = Vector3(spacing * float(i), 0.0, 0.0)
			if not ats.is_empty():
				var xyz: PackedStringArray = _item(ats, i, "0:0:0").split(":")
				if xyz.size() == 3:
					at = Vector3(float(xyz[0]), float(xyz[1]), float(xyz[2]))
				else:
					errors.append("--at wants x:y:z per pack, got '%s'" % _item(ats, i, ""))
			var plot_at: Vector3 = at if not opts.has("plot-spacing") else Vector3(float(opts["plot-spacing"]) * float(i), 0.0, 0.0)
			plot_defs.append({"id": "p%d" % i, "dir": dirs[i], "seed": int(_item(seeds, i, "1")), "origin": plot_at, "yaw": 0.0,
				"mode": str(opts.get("mode", "smoke")), "frames": int(_item(frames, i, "3600")), "every": int(_item(everys, i, "1")),
				"at": at, "trace": int(opts.get("trace", "0")), "own_space": str(opts.get("space", "own")) != "shared",
				"on_stage": i == int(opts.get("stage", "0"))})
			packs.append(_spawn_plot(i, opts.has("save")))
	if not refused.is_empty():
		print(JSON.stringify({"schema": "tl.world/1", "kind": "world", "errors": [refused]}, "", false))
		print("[tl] world refused: " + refused)
		_guard.call("stop")
		get_tree().quit(2)
		return
	_mem_loaded = OS.get_static_memory_usage()
	_load_ms = Time.get_ticks_msec() - _t_start
	_last_usec = Time.get_ticks_usec()
	set_physics_process(true)


# ------------------------------------------------------------------------------------------- N5a: plots and files
func _resolve(pack: String) -> String:
	var p: String = pack.replace("\\", "/")
	if p.is_absolute_path() and DirAccess.dir_exists_absolute(p):
		return p
	for base: String in PACK_BASES:
		var full: String = ProjectSettings.globalize_path(base + "/" + p)
		if DirAccess.dir_exists_absolute(full):
			return full
	return str(PlotFile.call("beside_exe", p))      # P12 (PATCHES-P9 entry 2): the folder `games` beside the executable


## Builds the pack of plot `i` from its seed. `named`: the pack carries its plot id (scheduled worlds, world files).
func _spawn_plot(i: int, named: bool = true) -> Node:
	var def: Dictionary = plot_defs[i]
	var t0: int = Time.get_ticks_usec()
	var dir: String = str(def["dir"])
	var p: Node3D = PackScript.new()
	p.name = "P%d_%s" % [i, dir.replace("\\", "/").trim_suffix("/").get_file()]
	p.set("world", self)
	add_child(p)
	if named:
		p.set("plot_id", str(def["id"]))
	p.set("plot_origin", def.get("origin", Vector3.ZERO))
	p.set("plot_yaw", float(def.get("yaw", 0.0)))
	p.set("ticks_before", int(def.get("ticks_before", 0)))
	p.set_meta(&"tl_plot", {"id": str(def["id"]), "origin": def.get("origin", Vector3.ZERO), "yaw": float(def.get("yaw", 0.0))})
	if _dead.has(str(i)): return p     # P1: it ran away in an earlier run of this world: left unloaded
	if jobs != null and not def.has("go"): return p.call("stub", dir)     # P5: the build queue builds it, later
	var ok: bool = p.call("load_pack", dir, {"mode": str(def.get("mode", "smoke")), "seed": int(def.get("seed", 1)),
		"frames": int(def.get("frames", 3600)), "every": int(def.get("every", 1)), "at": def.get("at", Vector3.ZERO),
		"trace": int(def.get("trace", 0)), "own_space": bool(def.get("own_space", true)),
		"on_stage": bool(def.get("on_stage", false)),
		# N7 (decision of the Director): in a world a pack brings no far terrain and no forest of its own
		"scenery": str(opts.get("scenery", walk.get("scenery", "plot")))})
	if not ok:
		errors.append("pack %d (%s) did not load" % [i, dir])
	elif def.get("data", null) != null:
		p.call("restore", def["data"])
	_load_marks.append([String(p.name), snappedf(float(Time.get_ticks_usec() - t0) / 1000.0, 0.1)])
	return p


func _read_json(path: String, what: String) -> Variant:
	if not FileAccess.file_exists(path):
		refused = "%s not found: %s" % [what, path]
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		refused = "%s %s is not a whole JSON object (%d bytes, line %d: %s). It looks cut short. Nothing was loaded and the file was left as it is." % [
			what, path, text.length(), json.get_error_line() + 1, json.get_error_message() if json.get_error_message() != "" else "not an object"]
		return null
	return json.data


func _start_walk() -> void:
	var cfg: Dictionary = {}
	if opts.has("replay"):
		var lg: Variant = _read_json(str(opts["replay"]), "world log")
		if lg == null:
			return
		if str((lg as Dictionary).get("schema", "")) != "tl.worldlog/1":
			refused = "world log %s: schema is not tl.worldlog/1" % str(opts["replay"])
			return
		walk = (lg as Dictionary)["walk"]
		cfg = (lg as Dictionary)["tiers"]
		is_replay = true
		for ev: Dictionary in (lg as Dictionary)["events"]:
			for k: String in ["t", "slice", "pm", "ticks"]:
				if ev.has(k):
					ev[k] = int(ev[k])
			if not replay_events.has(int(ev["t"])):
				replay_events[int(ev["t"])] = []
			(replay_events[int(ev["t"])] as Array).append(ev)
	else:
		var w: Variant = _read_json(str(opts["walk"]), "walk script")
		if w == null:
			return
		walk = w
		var over: Variant = walk.get("tiers", {})
		var lc: Dictionary = Tiers.call("load_config", str(opts.get("tiers", "res://kernel/world/tiers.json")), over if typeof(over) == TYPE_DICTIONARY else {})
		if not bool(lc["ok"]):
			refused = str(lc["error"])
			return
		cfg = lc["cfg"]
		if opts.has("cost"):
			cfg["cost"] = str(opts["cost"])
		if opts.has("ticks"):
			walk["ticks"] = int(opts["ticks"])
		if opts.has("mode"):
			walk["mode"] = str(opts["mode"])
	walk_ticks = int(walk.get("ticks", 3600))
	# P5: how the packs arrive (tiers.json `load`, TIERS.md "Loading"). The mode that was used is part of the log.
	var lm: Dictionary = cfg.get("load", {}) if typeof(cfg.get("load")) == TYPE_DICTIONARY else {}
	var load_mode: String = str(lm.get("mode", "block")) if is_replay else str(opts.get("load", lm.get("mode", "block")))
	if load_mode == "auto":
		load_mode = "step" if DisplayServer.get_name() == "headless" else "queue"
	if not lm.is_empty() or load_mode != "block":
		lm["mode"] = load_mode
		cfg["load"] = lm
	if load_mode != "block":
		jobs = Jobs.new()
		jobs.call("setup", self, lm, load_mode, str(opts.get("scenery", walk.get("scenery", "plot"))), walk.get("edits", []))
	cost_measured = str(cfg.get("cost", "model")) == "measured"
	player_script = walk.get("player", [])
	var list: Array = []
	var src: Array = walk.get("plots", [])
	var default_size: Array = cfg.get("default_footprint_m", [40, 40])
	for i: int in src.size():
		var sp: Dictionary = src[i]
		plot_defs.append({"id": str(sp.get("id", "p%d" % i)), "dir": _resolve(str(sp.get("pack", ""))), "seed": int(sp.get("seed", 1)),
			"origin": Tiers.call("_v3", sp.get("origin", [0, 0, 0])), "yaw": float(sp.get("yaw", 0.0)),
			"mode": str(sp.get("mode", walk.get("mode", "smoke"))), "frames": FOREVER, "ticks_before": int(sp.get("ticks", 0)), "data": sp.get("data", null)})
		var p: Node = _spawn_plot(i)
		packs.append(p)
		var m: Dictionary = p.get("manifest")
		if jobs != null and m.is_empty() and not _dead.has(str(i)):
			errors.append("pack %d (%s) did not load" % [i, str((plot_defs[i] as Dictionary)["dir"])])
		var size: Vector2 = Vector2(float(default_size[0]), float(default_size[1]))
		var fp: Variant = sp.get("footprint", m.get("footprint", null))
		if typeof(fp) == TYPE_DICTIONARY and typeof((fp as Dictionary).get("size_m")) == TYPE_ARRAY:
			size = Vector2(float(((fp as Dictionary)["size_m"] as Array)[0]), float(((fp as Dictionary)["size_m"] as Array)[1]))
		var has_bot: bool = typeof(m.get("tests")) == TYPE_ARRAY and not (m["tests"] as Array).is_empty()
		var leave: String = str(sp.get("on_leave", m.get("on_leave", "bot" if has_bot else "pause")))
		(plot_defs[i] as Dictionary)["on_leave"] = leave
		list.append({"id": (plot_defs[i] as Dictionary)["id"], "pack": str(m.get("id", "")), "origin": (plot_defs[i] as Dictionary)["origin"],
			"yaw": (plot_defs[i] as Dictionary)["yaw"], "size": size, "on_leave": leave})
	sched = Tiers.new()
	sched.call("setup", cfg, list, walk.get("tickets", []), walk.get("events", []))
	sched.set("visitor", bool(walk.get("visitor", false)))


## `--world=<file>`: a world file (tl.world/1). Every pack is rebuilt from its seed; its live state is NOT restored,
## only what the pack itself saved (`_pack_save` / `_pack_load`), its tick count and its summary.
func _start_from_file() -> void:
	var path: String = str(opts["world"])
	var w: Variant = _read_json(path, "world file")
	if w == null:
		if FileAccess.file_exists(path + ".prev"):
			refused += " The revision before it is intact at %s.prev." % path
		return
	var doc: Dictionary = w
	if str(doc.get("schema", "")) != "tl.world/1" or typeof(doc.get("plots")) != TYPE_ARRAY:
		refused = "world file %s: not a tl.world/1 file (schema '%s', plots %s). Nothing was loaded." % [path, str(doc.get("schema", "")), "missing" if not doc.has("plots") else "not a list"]
		return
	var plots: Array = doc["plots"]
	for i: int in plots.size():
		var sp: Variant = plots[i]
		var okp: bool = typeof(sp) == TYPE_DICTIONARY
		if okp:
			var d: Dictionary = sp
			okp = typeof(d.get("origin")) == TYPE_ARRAY and (d["origin"] as Array).size() == 3 and typeof(d.get("pack")) == TYPE_DICTIONARY and d.has("id") and d.has("seed")
		if not okp:
			refused = "world file %s: plot %d lacks id, origin [x, y, z], pack or seed. Nothing was loaded." % [path, i]
			return
	world_in = doc
	for i: int in plots.size():
		var sp: Dictionary = plots[i]
		var pk: Dictionary = sp["pack"]
		var dir: String = _resolve(str(pk.get("dir", "")))
		plot_defs.append({"id": str(sp["id"]), "dir": dir, "seed": int(sp["seed"]), "origin": Tiers.call("_v3", sp["origin"]),
			"yaw": float(sp.get("yaw", 0.0)), "mode": str(opts.get("mode", "smoke")), "frames": int(opts.get("frames", "0")),
			"ticks_before": int(sp.get("ticks", 0)), "data": sp.get("data", null), "on_stage": i == 0})
		var p: Node = _spawn_plot(i)
		packs.append(p)
		if bool(p.get("loaded")) and str(pk.get("hash", "")) != "" and str(PlotFile.call("dir_hash", str(p.get("pack_dir")))) != str(pk["hash"]):
			errors.append("plot %s: the pack at %s has changed since the world was saved" % [str(sp["id"]), dir])
	var pl: Variant = doc.get("player", {})
	if typeof(pl) == TYPE_DICTIONARY and typeof((pl as Dictionary).get("position")) == TYPE_ARRAY:
		player_pos = Tiers.call("_v3", (pl as Dictionary)["position"])


func _plot_records() -> Array:
	var out: Array = []
	for i: int in packs.size():
		if ledger.has(i):
			out.append(ledger[i])
		else:
			out.append((packs[i] as Node).call("plot_record"))
	return out


# -------------------------------------------------------------------------------------- N5a: the scheduled tick
func _on_event(ev: Dictionary) -> void:
	_event_lines.append(JSON.stringify({"schema": "tl.world/1", "kind": "event"}.merged(ev), "", false))
	var i: int = int(sched.call("index_of", str(ev.get("plot", "")))) if ev.has("plot") else -1
	if i < 0:
		return
	var p: Node = packs[i]
	match str(ev.get("e", "")):
		"tier":
			plot_event.emit(i, "before_tier", ev)
			if str(ev["to"]) == "ledger" and not ledger.has(i):
				ledger[i] = p.call("unload")
				if jobs != null: jobs.call("cancel", i)
			elif jobs != null:
				jobs.call("want", i)               # P5: asked for once; it arrives with its own `built` event
			elif str(ev.get("from", "")) == "ledger" and ledger.has(i):
				_rebuild(i, ledger[i])
			var c: TLContext = (packs[i] as Node).get("ctx")
			if c != null:
				c.on_stage = str(ev["to"]) == "stage"
			plot_event.emit(i, "tier", ev)
		"leave":
			if str(ev.get("on_leave", "")) == "end" and not bool(p.get("finished")):
				p.call("finish", tick)
		"restart", "reload":                   # reload (P5): a fresh copy of the same directory; what the pack saved itself is handed on
			var rec: Dictionary = {"ticks": int(p.get("ticks_before")) + int(p.get("frames_done"))}
			if str(ev["e"]) == "reload" and bool(p.get("loaded")) and p.call("saved_data") != null: rec["data"] = p.call("saved_data")
			if jobs != null: jobs.call("want", i, true, rec)
			else: _rebuild(i, rec)
		"built":
			if jobs != null: jobs.call("attach", i, tick)


## A pack comes back from its plot record: a new holder, built from the seed; the pack's own saved data, if any.
func _rebuild(i: int, rec: Dictionary) -> void:
	var old: Node = packs[i]
	for c: Node in old.get_children():
		c.free()
	old.call("release_space")
	old.free()
	var def: Dictionary = plot_defs[i]
	def["ticks_before"] = int(rec.get("ticks", 0))
	def["data"] = rec.get("data", null)
	if jobs != null: def["on_stage"] = int(sched.get("stage")) == i
	packs[i] = _spawn_plot(i)
	ledger.erase(i)
	plot_event.emit(i, "rebuilt", {})


func _measure(span_usec: int) -> void:
	if _last_ticked.is_empty():
		return
	var plots: Array = sched.get("plots")
	var own: Array = []
	var own_sum: float = 0.0
	var weights: Array = []
	var weight_sum: float = 0.0
	for i: int in _last_ticked:
		var p: Node = packs[i]
		var calls: PackedInt64Array = p.get("tick_usec")
		var mine: float = float(int(p.get("tree_usec"))) + (float(calls[calls.size() - 1]) if not calls.is_empty() else 0.0)
		own.append(mine)
		own_sum += mine
		var wgt: float = 1.0 + float(int(p.get("awake_last")))
		weights.append(wgt)
		weight_sum += wgt
	var rest: float = maxf(0.0, float(span_usec) - own_sum)        # the physics step and what runs outside the brackets
	var shift: float = pow(2.0, float(int((sched.get("cfg") as Dictionary).get("ema_shift", 4))))
	for k: int in _last_ticked.size():
		var sample_ms: float = (float(own[k]) + rest * float(weights[k]) / weight_sum) / 1000.0
		var pl: Dictionary = plots[int(_last_ticked[k])]
		# The first samples of a pack are a plain running mean (the model's figure is only where the estimate starts,
		# and a backdrop pack is measured rarely). After that one stalled iteration (another process took the core)
		# must not look like a heavy pack: a sample counts for at most four times the estimate; a pack that really
		# got heavier is followed within a few ticks.
		var seen: int = int(pl.get("samples", 0))
		pl["samples"] = seen + 1
		if seen >= 3:        # the very first ticks of a pack (first contacts, first laws) are not its pace
			if float(seen - 2) < shift:
				pl["cost"] = float(pl["cost"]) + (sample_ms - float(pl["cost"])) / float(seen - 2)
			else:
				sample_ms = minf(sample_ms, float(pl["cost"]) * 4.0 + 0.05)
				pl["cost"] = float(pl["cost"]) + (sample_ms - float(pl["cost"])) / shift


func _walk_tick(span_usec: int) -> void:
	if cost_measured and not is_replay and tick > 0:
		_measure(span_usec)
	if tick >= walk_ticks:
		for p: Node in packs:
			if bool(p.get("loaded")) and not bool(p.get("finished")):
				p.call("finish", tick)
			p.set("due", false)
			p.call("set_running", false)
		_end()
		return
	if not player_live:
		player_pos = Tiers.call("position_at", player_script, tick)
	var events: Array = []
	if is_replay:
		for ev: Dictionary in replay_events.get(tick, []):
			if str(ev.get("e", "")) != "over":       # a game that ends by itself says so again in the replay
				sched.call("apply", ev)
				events.append(ev)
	else:
		events = sched.call("decide", tick, player_pos)
	for ev: Dictionary in events:
		_on_event(ev)
	if jobs != null and not is_replay:
		jobs.call("pump", tick)            # P5: the packs that arrive on this tick boundary (each a `built` event)
	var due: Array = sched.call("due", tick)
	_last_ticked = []
	for i: int in packs.size():
		var p: Node = packs[i]
		if not bool(p.get("loaded")) or bool(p.get("finished")):
			continue
		var d: bool = due.has(i)
		p.set("due", d)
		p.call("set_running", d)
		if d:
			_guard.call("tick", p, i, tick)    # P1
			_last_ticked.append(i)
			if bool(p.get("finished")):
				_on_event(sched.call("mark_over", tick, i, int(p.get("frames_done"))))
	TLContext.current = null
	_last_due = _last_ticked.size()
	_kernel_usec.append(Time.get_ticks_usec() - _last_usec)
	tick += 1


func _on_node_added(n: Node) -> void:
	if not (n is CollisionObject3D):
		return
	var up: Node = n.get_parent()
	while up != null and up != self:
		if up.get_parent() == self:
			if up.has_method("adopt"):
				up.call("adopt", n)
			return
		up = up.get_parent()


## Whether pack `i` gets world tick `tick`.
func _is_due(i: int, p: Node) -> bool:
	for w: Array in pauses:
		if (int(w[0]) == -1 or int(w[0]) == i) and tick >= int(w[1]) and tick < int(w[1]) + int(w[2]):
			return false
	return tick % int(p.get("every")) == 0


func _physics_process(_delta: float) -> void:
	if _ended:
		return
	var now: int = Time.get_ticks_usec()
	# P5: what a step-mode tick (or a replay) waited for its pack is loading (`load_ms`), not the tick's time
	var _span: int = now - _last_usec - (int(jobs.call("take_spent")) if jobs != null else 0)
	if tick > 0:
		var span: int = _span                     # the whole previous iteration: scripts, tree, every active space
		if _last_due < 0:
			_iter_hold.append(span)
		else:
			_iter_any.append(span)
			if _last_due == packs.size() and not packs.is_empty():
				_iter_all.append(span)
	_last_usec = now
	TLContext.current = null
	if sched != null:
		_walk_tick(_span)
		return
	var open: int = 0
	for p: Node in packs:
		if bool(p.get("loaded")) and not bool(p.get("finished")):
			if int(p.get("frames_done")) >= int(p.get("frames_target")):
				p.call("finish", tick)            # its last tick has been stepped: hash it now
			else:
				open += 1
	if open == 0:
		for p: Node in packs:
			p.set("due", false)
			p.call("set_running", false)
		if hold_left > 0:
			hold_left -= 1
			_last_due = -1
			tick += 1
			return
		_end()
		return
	var due_count: int = 0
	for i: int in packs.size():
		var p: Node = packs[i]
		if not bool(p.get("loaded")) or bool(p.get("finished")):
			continue
		var d: bool = _is_due(i, p)
		p.set("due", d)
		p.call("set_running", d)
		if d:
			_guard.call("tick", p, i, tick)    # P1
			due_count += 1
	TLContext.current = null
	_last_due = due_count
	_kernel_usec.append(Time.get_ticks_usec() - now)
	tick += 1
	if tick > 10000000:
		errors.append("the world ran ten million ticks without finishing")
		_end()


func _pct(values: PackedInt64Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedInt64Array = values.duplicate()
	sorted.sort()
	var idx: int = clampi(int(ceil(p * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return snappedf(float(sorted[idx]) / 1000.0, 0.0001)


func _mean(values: PackedInt64Array) -> float:
	if values.is_empty():
		return 0.0
	var sum: int = 0
	for v: int in values:
		sum += v
	return snappedf(float(sum) / float(values.size()) / 1000.0, 0.0001)


func _end() -> void:
	_ended = true
	set_physics_process(false)
	_guard.call("stop")
	var load_report: Dictionary = jobs.call("report") if jobs != null else {"mode": "block"}
	if jobs != null: jobs.call("stop")
	TLContext.current = null
	var lines: PackedStringArray = PackedStringArray()
	if opts.has("save"):
		_save_error = str(PlotFile.call("save", self, str(opts["save"]), _plot_records()))
		if not _save_error.is_empty():
			errors.append(_save_error)
	var bad: bool = not errors.is_empty()
	lines.append_array(_event_lines)
	var leaks: int = 0
	var wrong: int = 0
	for i: int in packs.size():
		var r: Dictionary = (packs[i] as Node).call("result", i)
		if _dead.has(str(i)): r["tripped"] = true
		if sched != null:
			var pl: Dictionary = (sched.get("plots") as Array)[i]
			r["tier"] = pl["tier"]
			r["tiers_seen"] = (pl["seen"] as Dictionary).keys()
			r["ticks_by_tier"] = pl["by_tier"]
			r["tier_changes"] = pl["changes"]
			r["max_gap"] = pl["max_gap"]
			r["on_leave"] = pl["on_leave"]
			r["held"] = pl["held"]
			r["over"] = pl["over"]
			r["cost_ms"] = snappedf(float(pl["cost"]), 0.001)
			r["speed_share"] = snappedf(float(int(r["frames"])) / float(maxi(1, tick)), 0.0001)
		bad = bad or (not bool(r["loaded"]) and not bool(r.get("ledgered", false))) or int(r["script_errors"]) > 0 or int(r["engine_errors"]) > 0
		leaks += int(r["gate_leaks"])
		wrong += int(r["wrong_pack_calls"])
		lines.append(JSON.stringify(r, "", false))
	var snap: Dictionary = logger.call("snapshot")
	var warns: Array = logger.call("warning_texts")
	var dropped: int = 0
	for w: Variant in warns:
		var low: String = str(w).to_lower()
		if low.contains("contact") or low.contains("body pair") or low.contains("max_bodies") or low.contains("maximum number of bodies"):
			dropped += 1
	var world_line: Dictionary = {"schema": "tl.world/1", "kind": "world", "packs": packs.size(), "world_ticks": tick,
		"load_ms": _load_ms + int(float(load_report.get("in_ticks_ms", 0.0))), "wall_ms": Time.get_ticks_msec() - _t_start,
		"iter_ms_p50_all_ticked": _pct(_iter_all, 0.5), "iter_ms_p99_all_ticked": _pct(_iter_all, 0.99),
		"iter_ms_mean_all_ticked": _mean(_iter_all), "iters_all_ticked": _iter_all.size(),
		"iter_ms_p50_last_third": _pct(_iter_all.slice(_iter_all.size() * 2 / 3), 0.5),
		"iter_ms_p50": _pct(_iter_any, 0.5), "iter_ms_mean": _mean(_iter_any), "iters": _iter_any.size(),
		"hold_iter_ms_p50": _pct(_iter_hold, 0.5), "hold_iter_ms_mean": _mean(_iter_hold), "hold_iters": _iter_hold.size(),
		"kernel_ms_p50": _pct(_kernel_usec, 0.5), "kernel_ms_mean": _mean(_kernel_usec),
		"static_mem_per_pack_kb": int(float(_mem_loaded - _mem_before) / 1024.0 / float(maxi(1, packs.size()))),
		"gate_leaks": leaks, "wrong_pack_calls": wrong,
		"script_errors": int(snap["script_errors"]), "engine_errors": int(snap["engine_errors"]),
		"engine_warnings": int(snap["warnings"]), "warning_texts": warns, "contact_or_body_limit_warnings": dropped,
		"errors": errors, "logged": snap["errors"], "load_ms_per_pack": _load_marks,
		"iter_ms_p99": _pct(_iter_any, 0.99), "iter_ms_max": _pct(_iter_any, 1.0),
		"first_iter_ms": (snappedf(float(_iter_any[0]) / 1000.0, 0.001) if not _iter_any.is_empty() else 0.0),
		"iter_ms_p50_settled": _pct(_iter_any.slice(mini(120, _iter_any.size())), 0.5),
		"iter_ms_mean_settled": _mean(_iter_any.slice(mini(120, _iter_any.size()))),
		"iter_ms_p99_settled": _pct(_iter_any.slice(mini(120, _iter_any.size())), 0.99)}
	if sched != null:
		world_line["load"] = load_report
		world_line["walk"] = str(walk.get("name", ""))
		world_line["replay"] = is_replay
		world_line["cost"] = "measured" if cost_measured else "model"
		world_line["events"] = (sched.get("log") as Array).size()
		world_line["valve_demotions"] = int(sched.get("valve_demotions"))
		world_line["speed_pm"] = int(sched.get("speed_pm"))
		world_line["speed_min_pm"] = int(sched.get("speed_min_pm"))
		world_line["slice"] = int(sched.get("slice"))
		world_line["slice_max_seen"] = int(sched.get("slice_max_seen"))
		if opts.has("log"):
			var packs_out: Array = []
			for i: int in packs.size():
				packs_out.append({"plot": (plot_defs[i] as Dictionary)["id"], "ticks": int((packs[i] as Node).get("frames_done")), "state_hash": str((packs[i] as Node).get("final_hash"))})
			var lf: FileAccess = FileAccess.open(str(opts["log"]), FileAccess.WRITE)
			if lf != null:
				lf.store_string(JSON.stringify({"schema": "tl.worldlog/1", "walk": walk, "tiers": sched.get("cfg"), "events": sched.get("log"), "packs": packs_out}, "", false) + "\n")
				lf.close()
			else:
				errors.append("cannot write the world log to %s" % str(opts["log"]))
				bad = true
	bad = bad or dropped > 0 or leaks > 0
	lines.append(JSON.stringify(world_line, "", false))
	for line: String in lines:
		print(line)
	if opts.has("out"):
		var f: FileAccess = FileAccess.open(str(opts["out"]), FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(lines) + "\n")
			f.close()
	print("[tl] world done: packs=%d ticks=%d" % [packs.size(), tick])
	exit_code = 1 if bad else 0
	ended.emit(bad)                 # whoever draws lets go of the packs' visuals now
	# leave nothing behind: nodes first, then the spaces they lived in
	for p: Node in packs:
		for c: Node in p.get_children():
			c.free()
		p.call("release_space")
	if quit_on_end:
		get_tree().quit(exit_code)
