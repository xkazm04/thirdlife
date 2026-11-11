extends Node3D
## N2. One pack alive in a world: the HOLDER node of a pack instance. Everything the pack owns hangs off it:
##
##   <holder>                 this node; carries the pack's TLContext (meta `tl_ctx`), stands at the pack's origin
##     _Begin                 marker: names this pack as "the pack being called" while the tree ticks its nodes
##     TLPack/World, Entry    the pack's scene (ctx.root) and its entry script
##     _Probe                 counts ticks; proves that nothing here runs on a world tick the pack did not get
##     TLInput, TLCameras     the pack's own input record and views
##     Bot                    optional
##     _End                   marker: clears "the pack being called"
##
## The kernel drives every tick. `tick()` makes the kernel's calls into the pack (start, bot, input latch,
## `_pack_tick`); the nodes of the pack that tick themselves in `_physics_process` (TLBiped, TLVehicle, TLHud, TLBall,
## cameras, spawners, a pack's own scripts) run right after, in tree order, because this holder is enabled; then the
## pack's own physics space is stepped. On a world tick the pack does not get, `set_running(false)` switches all
## three off at once: the holder's processing (PROCESS_MODE_DISABLED), so no script of the pack runs, and the space
## (`space_set_active(false)`), so no body moves. Every collision object of the pack keeps DISABLE_MODE_KEEP_ACTIVE,
## so switching the holder off does not take its bodies out of the space (the engine default would, and the contact
## cache would be lost).

const Manifest: GDScript = preload("res://kernel/runner/manifest.gd")
const WorkerScript: GDScript = preload("res://kernel/runner/worker.gd")
const PlotFile: GDScript = preload("res://kernel/world/plotfile.gd")   # P5: the pack directory's hash, the world file

const CENSUS_EVERY: int = 10            # the worker's rhythm: late-tagged bodies get their law on these frames


## Names the pack for the nodes of its subtree that the scene tree ticks (default process priority).
class Mark extends Node:
	var ctx: TLContext
	var opens: bool = true
	var pack: Node = null           # N5a: the holder; the closing mark tells it how long its nodes took this tick
	var mate: Mark = null
	var t_usec: int = 0

	func _physics_process(_delta: float) -> void:
		TLContext.current = ctx if opens else null
		if opens:
			t_usec = Time.get_ticks_usec()
		elif mate != null and pack != null:
			pack.call("contact_pass")       # P5: after every node of the pack, before its physics step
			pack.set("tree_usec", Time.get_ticks_usec() - mate.t_usec)

	func _process(_delta: float) -> void:
		TLContext.current = ctx if opens else null


## A script in the pack's subtree, ticked by the scene tree like any script of the pack.
class Probe extends Node:
	var pack: Node
	var physics_calls: int = 0
	var idle_calls: int = 0
	var leaks: int = 0              # calls on a world tick the pack did not get
	var wrong_pack: int = 0         # calls during which "the pack being called" was not this pack

	func _physics_process(_delta: float) -> void:
		physics_calls += 1
		if not bool(pack.get("due")):
			leaks += 1
		if TLContext.current != pack.get("ctx"):
			wrong_pack += 1

	func _process(_delta: float) -> void:
		idle_calls += 1
		if not bool(pack.get("due")):
			leaks += 1


var world: Node = null                  # the world host (logger, options)
var ctx: TLContext
var pack_dir: String = ""
var pack_node: Node3D
var entry: Node
var bot: Node
var probe: Probe
var mode: String = "smoke"
var seed_value: int = 1
var frames_target: int = 3600
var frames_done: int = 0                # the pack's own tick counter: how many ticks it has had
var every: int = 1                      # the pack is ticked on one world tick in `every`
var trace_every: int = 0
var own_space: bool = true
var space: RID = RID()
var loaded: bool = false
var started: bool = false
var finished: bool = false
var running: bool = true                # holder enabled and space active
var due: bool = false                   # the pack gets this world tick
var load_errors: Array = []
var hash_trace: Array = []
var final_hash: String = ""
var pack_state: Variant = null
var bot_info: Dictionary = {}
var entities_max: int = 0
var bodies_max: int = 0
var awake_last: int = 0
var tick_usec: PackedInt64Array = PackedInt64Array()
var toggles: int = 0
var finished_at_world_tick: int = -1
var _has_tick: bool = false
var _before: TLContext = null
# N5a: the plot this pack stands on in a scheduled world, and what a world file keeps of it
var plot_id: String = ""
var plot_origin: Vector3 = Vector3.ZERO  # where the plot is in the world (the pack itself is simulated at its own origin)
var plot_yaw: float = 0.0
var ticks_before: int = 0               # ticks this plot's game had before this pack was (re)built from its seed
var restored: bool = false              # `_pack_load(data)` was called with saved data
var tree_usec: int = 0                  # how long the scene tree spent in this pack's nodes on its last tick
var _begin_mark: Mark = null
var _kept_summary: Dictionary = {}
var _kept_data: Variant = null
var load_ms: Dictionary = {}            # where the loading time went: scripts, setup, laws, bot (milliseconds)
var ledgered: bool = false              # unloaded: only the plot record is left
var bot_off: bool = false               # N7: a person plays this pack (its bot waits); never set in a scripted run
var manifest: Dictionary = {}           # P5: the pack's manifest; a stub has it before the pack is built
var _tracker: Node = null               # P5: the pack's contact pass (TLContact.Tracker) as it stood when this tick began


# ------------------------------------------------------------------------------------------------------ loading
func _fail(file: String, message: String) -> bool:
	load_errors.append({"kind": "load", "file": file, "message": message})
	return false


func _enter() -> void:
	_before = TLContext.enter(ctx)
	if world != null:
		var lg: Object = world.get("logger")
		if lg != null:
			lg.set("tag", String(name))
			lg.set("pack_dir", pack_dir)
			lg.set("frame", frames_done if started else -1)


func _leave() -> void:
	TLContext.leave(_before)
	_before = null
	if world != null and world.get("logger") != null:
		(world.get("logger") as Object).set("tag", "")


func load_pack(dir_arg: String, options: Dictionary) -> bool:
	mode = str(options.get("mode", "smoke"))
	seed_value = int(options.get("seed", 1))
	frames_target = int(options.get("frames", 3600))
	every = maxi(1, int(options.get("every", 1)))
	trace_every = int(options.get("trace", 0))
	own_space = bool(options.get("own_space", true))
	pack_dir = Manifest.resolve_dir(dir_arg)
	if pack_dir.is_empty():
		return _fail("", "pack directory not found: " + dir_arg)
	var mres: Dictionary = Manifest.read(pack_dir)
	if not mres["ok"]:
		load_errors.append_array(mres["errors"])
		return false
	var m: Dictionary = mres["manifest"]
	manifest = m
	ctx = TLContext.new()
	ctx.manifest = m
	ctx.pack_dir = pack_dir
	ctx.pack_id = str(m["id"])
	ctx.seed = seed_value
	ctx.rng = RandomNumberGenerator.new()
	ctx.rng.seed = seed_value
	ctx.max_frames = frames_target
	ctx.headless = DisplayServer.get_name() == "headless"
	ctx.mode = mode
	ctx.instance = String(name)
	ctx.holder = self
	ctx.origin = options.get("at", Vector3.ZERO)
	ctx.on_stage = bool(options.get("on_stage", true))     # N7 (N5b patch 1): known before the pack's scripts load
	ctx.ball_group = StringName("tl_ball@" + String(name))
	ctx.scenery = str(options.get("scenery", "full"))
	set_meta(&"tl_ctx", ctx)
	position = ctx.origin
	if own_space:
		# what World3D does for the default space: gravity and damping come from the project settings
		space = PhysicsServer3D.space_create()
		PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY, ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
		PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, ProjectSettings.get_setting("physics/3d/default_gravity_vector", Vector3.DOWN))
		PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_LINEAR_DAMP, ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.1))
		PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_ANGULAR_DAMP, ProjectSettings.get_setting("physics/3d/default_angular_damp", 0.1))
		PhysicsServer3D.space_set_active(space, true)
		ctx.space = space
	var begin: Mark = Mark.new()
	begin.name = "_Begin"
	begin.ctx = ctx
	_begin_mark = begin
	add_child(begin)
	pack_node = Node3D.new()
	pack_node.name = "TLPack"
	add_child(pack_node)
	ctx.root = Node3D.new()
	ctx.root.name = "World"
	pack_node.add_child(ctx.root)
	probe = Probe.new()
	probe.name = "_Probe"
	probe.pack = self
	add_child(probe)
	ctx.input = TLInput.new()
	ctx.input.name = "TLInput"
	ctx.input.accept_devices = false          # a world's packs are played by bots or by the input the kernel routes
	add_child(ctx.input)
	ctx.cameras = TLCameras.new()
	ctx.cameras.name = "TLCameras"
	add_child(ctx.cameras)
	_enter()
	var ok: bool = _load_scripts(m, options)
	_leave()
	var done: Mark = Mark.new()
	done.name = "_End"
	done.ctx = ctx
	done.opens = false
	done.pack = self
	done.mate = _begin_mark
	add_child(done)
	loaded = ok
	return ok


func _lap(key: String, t0: int) -> int:
	var now: int = Time.get_ticks_usec()
	load_ms[key] = snappedf(float(load_ms.get(key, 0.0)) + float(now - t0) / 1000.0, 0.01)
	return now


func _load_scripts(m: Dictionary, options: Dictionary) -> bool:
	var t: int = Time.get_ticks_usec()
	for gen: String in m["assets"]:
		var gs: GDScript = _load_script(gen)
		if gs == null:
			return false
		if not _script_has(gs, "generate"):
			return _fail(gen, "an asset generator needs `static func generate(ctx) -> void`")
		gs.call("generate", ctx)
	t = _lap("assets", t)
	var es: GDScript = _load_script(str(m["entry"]))
	if es == null:
		return false
	t = _lap("script", t)
	var inst: Variant = es.new()
	if not (inst is Node):
		return _fail(str(m["entry"]), "the entry script must extend Node")
	entry = inst
	entry.name = "Entry"
	for need: String in ["_pack_setup", "_pack_start"]:
		if not entry.has_method(need):
			entry.free()
			entry = null
			return _fail(str(m["entry"]), "the entry script has no %s()" % need)
	_has_tick = entry.has_method("_pack_tick")
	ctx._entry = entry
	pack_node.add_child(entry)
	t = _lap("enter_tree", t)
	entry.call("_pack_setup", ctx)
	t = _lap("setup", t)
	TLLaws.apply_tree(pack_node)
	t = _lap("laws", t)
	if mode == "bot":
		var test: String = str(options.get("test", ""))
		if test.is_empty():
			test = str((m["tests"] as Array)[0])
		if not (m["tests"] as Array).has(test):
			return _fail(test, "the test must be one of the manifest's tests")
		var bs: GDScript = _load_script(test)
		if bs == null:
			return false
		var binst: Variant = bs.new()
		if not (binst is Node):
			return _fail(test, "a bot script must extend Node")
		bot = binst
		bot.name = "Bot"
		for need: String in ["_bot_setup", "_bot_tick", "_bot_done", "_bot_result"]:
			if not bot.has_method(need):
				bot.free()
				bot = null
				return _fail(test, "the bot script has no %s()" % need)
		add_child(bot)
		bot.call("_bot_setup", ctx)
		bot_info = {"test": test, "done": false, "frames": 0}
		t = _lap("bot", t)
	return true


func _load_script(rel: String) -> GDScript:
	var full: String = pack_dir + "/" + rel
	if not FileAccess.file_exists(full):
		_fail(rel, "file not found")
		return null
	var s: GDScript = TLContext._load_fresh(full)     # P12: a changed .gd is seen by a reload
	if s == null or not s.can_instantiate():
		_fail(rel, "the script did not load (parse error)")
		return null
	return s


func _script_has(s: GDScript, method: String) -> bool:
	for mi: Dictionary in s.get_script_method_list():
		if mi["name"] == method:
			return true
	return false


## Called by the world for every node that enters the tree under this holder.
func adopt(n: Node) -> void:
	if not (n is CollisionObject3D):
		return
	var co: CollisionObject3D = n
	co.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	if space.is_valid():
		if co is Area3D:
			PhysicsServer3D.area_set_space(co.get_rid(), space)
		else:
			PhysicsServer3D.body_set_space(co.get_rid(), space)
	if co.has_meta(&"tl_material") and not co.has_meta(&"tl_law_applied") and pack_node != null and pack_node.is_ancestor_of(co):
		TLLaws.apply(co)


# ------------------------------------------------------------------------------------------------------ ticking
## Switches the whole pack on or off for the coming world tick: its scripts and its physics space together.
func set_running(on: bool) -> void:
	if on == running:
		return
	running = on
	toggles += 1
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if space.is_valid():
		PhysicsServer3D.space_set_active(space, on)


## One tick of the pack's own clock: the kernel's calls into the pack for its frame `frames_done`.
func tick(world_tick: int) -> void:
	var t0: int = Time.get_ticks_usec()
	# P5 (PATCHES-P2 entry 1), the order of a tick in code: these calls, the pack's nodes, `contact_pass`, the physics step
	_tracker = ctx.get_meta(&"tl_tracker") if ctx.has_meta(&"tl_tracker") and is_instance_valid(ctx.get_meta(&"tl_tracker")) else null
	if _tracker != null and _tracker.is_physics_processing():
		_tracker.set_physics_process(false)        # this holder calls it by name from now on
	_enter()
	if not started:
		started = true
		entry.call("_pack_start")
	ctx.frame = frames_done
	if world != null and world.get("logger") != null:
		(world.get("logger") as Object).set("frame", frames_done)
	if bot != null and not bot_off:
		bot.call("_bot_tick", frames_done)
	ctx.input._sample()
	if _has_tick:
		entry.call("_pack_tick", frames_done)
	if frames_done % CENSUS_EVERY == 0:
		_census()
	if trace_every > 0 and frames_done % trace_every == 0:
		hash_trace.append([frames_done, state_hash().substr(0, 16)])
	var bot_done: bool = bot != null and not bot_off and bool(bot.call("_bot_done"))
	_leave()
	frames_done += 1
	tick_usec.append(Time.get_ticks_usec() - t0)
	if bot_done:
		# as the single-pack worker does: a bot run ends on the tick the bot says it is done, before that tick's step
		bot_info["done"] = true
		finish(world_tick)


## P5. The pack's contact pass of this tick; the closing mark calls it after every node of the pack. A tracker made
## during this tick has its first pass on the next one, as it had when the scene tree called it (priority 100).
func contact_pass() -> void:
	if _tracker != null and is_instance_valid(_tracker):
		_tracker.call("_physics_process", 0.0)


## Ends the pack's run: final census, state hash, `_pack_state`, teardown. The pack stays in memory, switched off.
func finish(world_tick: int) -> void:
	if finished:
		return
	if not started:
		# N5a: a pack that never had a tick (a world loaded and saved again, `--frames=0`) has no run to hash
		finished = true
		finished_at_world_tick = world_tick
		due = false
		set_running(false)
		return
	_kept_data = saved_data()           # N5a: while the pack can still answer `_pack_save`
	_enter()
	if bot != null:
		bot_info["frames"] = frames_done
		var r: Variant = bot.call("_bot_result")
		if typeof(r) == TYPE_DICTIONARY and typeof((r as Dictionary).get("ok")) == TYPE_BOOL:
			bot_info["result"] = WorkerScript.call("_plain", r)
		else:
			bot_info["result"] = {"ok": false, "summary": "_bot_result() did not return {ok: bool, summary: String}"}
	_census()
	final_hash = state_hash()
	_kept_summary = summary()
	if entry != null and entry.has_method("_pack_state"):
		pack_state = WorkerScript.call("_plain", entry.call("_pack_state"))
	if entry != null and entry.has_method("_pack_teardown"):
		entry.call("_pack_teardown")
	_leave()
	finished = true
	finished_at_world_tick = world_tick
	due = false
	set_running(false)


func _census() -> void:
	var counts: Array = [0, 0, 0]
	_census_node(pack_node, counts)
	entities_max = maxi(entities_max, int(counts[0]))
	bodies_max = maxi(bodies_max, int(counts[1]))
	awake_last = int(counts[2])


func _census_node(n: Node, counts: Array) -> void:
	counts[0] = int(counts[0]) + 1
	if n is PhysicsBody3D:
		counts[1] = int(counts[1]) + 1
		if n is RigidBody3D and not (n as RigidBody3D).sleeping and not (n as RigidBody3D).freeze:
			counts[2] = int(counts[2]) + 1
		if n.has_meta(&"tl_material") and not n.has_meta(&"tl_law_applied"):
			TLLaws.apply(n as CollisionObject3D)
	for c: Node in n.get_children():
		_census_node(c, counts)


# ------------------------------------------------------------------------------------------------------ hashing
## P11 (PATCHES-P7 section 1): the worker's state hash (kernel/host/statehash.gd): every physics body under the pack with
## positions relative to the pack's origin, `_pack_state()`, the seeded generator and the input state. A pack in a
## world hashes as `tl.sh smoke` / `bot` hashes it alone after the same number of its own ticks.
func state_hash() -> String:
	if ctx == null:
		return (load("res://kernel/host/statehash.gd") as GDScript).call("hash", pack_node, "")
	var tail: String = str(WorkerScript.call("_canon", entry.call("_pack_state"))) if entry != null and entry.has_method("_pack_state") else ""
	return (load("res://kernel/host/statehash.gd") as GDScript).call("hash", pack_node, tail, ctx.rng, ctx.input, ctx.origin)


## P11 (PATCHES-P7 section 2): a pack script's own event handlers (_input, _unhandled_input, ...) would read a device
## past ctx.input, so past the input record: switched off when the node is ready, as the worker does. Only scripts of
## this pack (by path), once per node. The holder enters the tree before `load_pack` makes any node.
func _enter_tree() -> void:
	get_tree().node_added.connect(func(n: Node) -> void:
		var sc: Script = n.get_script() as Script
		if sc == null or pack_dir.is_empty() or n.is_node_ready():
			return
		if not (sc.resource_path.begins_with(pack_dir) or sc.resource_path.begins_with(ProjectSettings.localize_path(pack_dir))):
			return
		n.ready.connect(func() -> void:
			n.set_process_input(false)
			n.set_process_unhandled_input(false)
			n.set_process_unhandled_key_input(false)
			n.set_process_shortcut_input(false), CONNECT_ONE_SHOT))


# ------------------------------------------------------------------------------------------------------ result
func _percentile(values: PackedInt64Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedInt64Array = values.duplicate()
	sorted.sort()
	var idx: int = clampi(int(ceil(p * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return snappedf(float(sorted[idx]) / 1000.0, 0.0001)


func result(index: int) -> Dictionary:
	var counts: Array = [0, 0]
	if world != null and world.get("logger") != null:
		counts = (world.get("logger") as Object).call("counts_of", String(name))
	var res: Dictionary = {"schema": "tl.world/1", "kind": "pack", "index": index, "instance": String(name),
		"pack": ctx.pack_id if ctx != null else "", "dir": pack_dir, "seed": seed_value,
		"at": [position.x, position.y, position.z], "every": every, "mode": mode, "loaded": loaded,
		"frames": frames_done, "state_hash": final_hash,
		"script_errors": int(counts[0]), "engine_errors": int(counts[1]),
		"entities_max": entities_max, "bodies_max": bodies_max, "awake_bodies_at_end": awake_last,
		"kernel_call_ms_p50": _percentile(tick_usec, 0.5), "kernel_call_ms_p99": _percentile(tick_usec, 0.99),
		"probe_physics_calls": probe.physics_calls if probe != null else 0,
		"probe_idle_calls": probe.idle_calls if probe != null else 0,
		"gate_leaks": probe.leaks if probe != null else 0, "wrong_pack_calls": probe.wrong_pack if probe != null else 0,
		"toggles": toggles, "finished_at_world_tick": finished_at_world_tick, "own_space": space.is_valid()}
	res["load_ms"] = load_ms
	if not plot_id.is_empty():
		res["plot"] = plot_id
		res["plot_origin"] = [plot_origin.x, plot_origin.y, plot_origin.z]
		res["ticks"] = ticks_before + frames_done
		res["restored"] = restored
		res["ledgered"] = ledgered
	if ctx != null:
		res["audio_events"] = ctx.audio_events.size()
	if not load_errors.is_empty():
		res["load_errors"] = load_errors
	if not bot_info.is_empty():
		res["bot"] = bot_info
	if trace_every > 0:
		res["hash_trace"] = hash_trace
	if pack_state != null and world != null and bool(world.get("show_state")):
		res["pack_state"] = pack_state
	return res


## P5. A plot whose pack is not built yet (the world's build queue, kernel/world/jobs.gd, builds it later): only the
## directory, the manifest and the plot record. For everything else it is a pack in the ledger.
func stub(dir_arg: String) -> Node:
	pack_dir = Manifest.resolve_dir(dir_arg)
	var mres: Dictionary = Manifest.read(pack_dir) if not pack_dir.is_empty() else {"ok": false, "errors": [{"kind": "load", "file": "", "message": "pack directory not found: " + dir_arg}]}
	if mres["ok"]:
		manifest = mres["manifest"]
	else:
		load_errors.append_array(mres["errors"])
	ledgered = bool(mres["ok"])
	finished = true
	running = false
	return self


# ------------------------------------------------------------------------------------------------ N5a: the plot
func _find_rules(n: Node) -> TLRules:
	if n is TLRules:
		return n as TLRules
	for c: Node in n.get_children():
		var r: TLRules = _find_rules(c)
		if r != null:
			return r
	return null


## The small summary a world keeps of a game it does not hold in memory: score, clock and phase from the pack's
## TLRules when it has one; always the tick count.
func summary() -> Dictionary:
	if finished and not _kept_summary.is_empty():
		var kept: Dictionary = _kept_summary.duplicate()
		return kept
	var s: Dictionary = {"ticks": ticks_before + frames_done, "over": bool(bot_info.get("done", false))}
	var rules: TLRules = _find_rules(pack_node) if pack_node != null and not finished else null
	if rules != null:
		s["phase"] = String(rules.state)
		s["score"] = rules.scores.duplicate()
		s["clock"] = rules.clock_text()
		s["clock_frames"] = rules.total_frames
		s["over"] = bool(s["over"]) or rules.is_over()
		if not rules.winner.is_empty():
			s["winner"] = rules.winner
	return s


## What the pack itself wants kept (`_pack_save() -> Dictionary`, optional), as plain JSON data; null without it.
func saved_data() -> Variant:
	if finished:
		return _kept_data
	if entry == null or not started or not entry.has_method("_pack_save") or not entry.has_method("_pack_load"):
		return null
	_enter()
	var d: Variant = WorkerScript.call("_plain", entry.call("_pack_save"))
	_leave()
	return d


## Hands saved data back to a pack that was just rebuilt from its seed (`_pack_load(data)`, optional).
func restore(data: Variant) -> bool:
	if data == null or entry == null or not entry.has_method("_pack_load") or not entry.has_method("_pack_save"):
		return false
	_enter()
	if not started:
		started = true
		entry.call("_pack_start")
	entry.call("_pack_load", data)
	_leave()
	restored = true
	return true


## N5a, `ledger`: takes the pack out of memory (nodes and physics space) and returns what the world keeps of it.
## The holder stays as a stub so the world's list keeps its shape; `world.gd` builds a new holder on the way back.
func unload() -> Dictionary:
	var rec: Dictionary = plot_record()
	_kept_summary = rec["summary"]
	ticks_before += frames_done
	frames_done = 0
	for c: Node in get_children():
		c.free()
	pack_node = null
	entry = null
	bot = null
	probe = null
	release_space()
	ledgered = true
	finished = true
	due = false
	running = false
	return rec


## One entry of a world file's `plots` (tl.world/1). The same record is what `ledger` keeps of an unloaded pack.
func plot_record() -> Dictionary:
	var m: Dictionary = manifest
	var fp: Variant = m.get("footprint", null)
	var rec: Dictionary = {"id": plot_id if not plot_id.is_empty() else String(name),
		"origin": [plot_origin.x, plot_origin.y, plot_origin.z], "yaw": plot_yaw, "footprint": fp,
		"pack": {"dir": pack_dir, "uid": str(m.get("id", "")), "version": str(m.get("version", "")), "hash": str(PlotFile.call("dir_hash", pack_dir))},
		"seed": seed_value, "ticks": ticks_before + frames_done, "summary": summary()}
	var d: Variant = saved_data()
	if d != null:
		rec["data"] = d
	return rec


## Frees the pack's physics space (after its nodes are gone).
func release_space() -> void:
	if space.is_valid():
		PhysicsServer3D.free_rid(space)
		space = RID()
