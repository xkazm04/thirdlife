extends RefCounted
## The one lifecycle of a pack. The lone worker (runner/worker.gd) and a world's holder (world/pack.gd) both drive
## this core, so "a game in a world plays as it does alone" holds for the lifecycle by construction: one context, one
## load sequence, one frame order, one census, one bot verdict, one script loader, one state hash.
##
## Each driver keeps what is its own: the worker its watchdog guards, session replay, capture and trips; the holder its
## physics space, marks, slicing and load laps. They reach in through three hooks, so the core knows neither:
##   on_begin(phase)          before every call into pack code (phase: "generate <file>", "_pack_setup", "_bot_tick", ..)
##   on_end(phase) -> bool    after it; false: the driver is stopping the run (a watchdog trip)
##   on_mark(key)             after each load step ("assets", "script", "enter_tree", "setup", "laws", "bot")
##
## Load:  make_context -> make_scene -> make_io -> load_entry (generators, entry, _pack_setup, laws) -> find_idle_scripts
##        -> load_bot (the bot and _bot_setup)
## Frame f (tick): ctx.frame = f -> _bot_tick(f) -> pre_sample(f) (the worker's input session) -> ctx.input latches
##        -> _pack_tick(f). The driver starts the pack once before its first tick (start) and counts with census.

const StateHash: GDScript = preload("res://kernel/host/statehash.gd")

const ORDER_FRAME: int = 3              # E6: TL_BODY_ORDER=<file> writes the pack space's body order at this frame
const BELOW_Y: float = -50.0            # pack-local height under which a body has fallen out of the game
const MAX_WARNINGS: int = 8
const BOT_RESULT_BAD: String = "_bot_result() did not return {ok: bool, summary: String}"
const BOT_RESULT_ERROR: String = "_bot_result() must return a Dictionary with ok (bool) and summary (String)"

var ctx: TLContext
var holder: Node                        # the driver's node: TLInput, TLCameras, the bot and TLPack hang off it
var pack_dir: String = ""
var pack_node: Node3D
var entry: Node
var bot: Node
var test: String = ""
var has_tick: bool = false
var load_errors: Array = []             # the driver hands in its own list
var warnings: Array = []                # the driver hands in its own list
var entities_max: int = 0
var bodies_max: int = 0
var awake_last: int = 0
var below_count: int = 0
var below: Dictionary = {}

var on_begin: Callable = Callable()
var on_end: Callable = Callable()
var on_mark: Callable = Callable()


func _begin(phase: String) -> void:
	if on_begin.is_valid():
		on_begin.call(phase)


func _end(phase: String) -> bool:
	return bool(on_end.call(phase)) if on_end.is_valid() else true


func _mark(key: String) -> void:
	if on_mark.is_valid():
		on_mark.call(key)


func fail(file: String, message: String) -> bool:
	load_errors.append({"kind": "load", "file": file, "message": message})
	return false


# ------------------------------------------------------------------------------------------------------ loading
## The pack's context, with what both drivers set; the driver adds its own fields (a world's origin, instance, ...).
func make_context(holder_node: Node, m: Dictionary, dir: String, seed_value: int, frames: int, mode: String) -> TLContext:
	holder = holder_node
	pack_dir = dir
	ctx = TLContext.new()
	ctx.holder = holder                 # N2: kernel nodes find their pack through the holder (TLContext.of)
	holder.set_meta(&"tl_ctx", ctx)
	ctx.manifest = m
	ctx.pack_dir = dir
	ctx.pack_id = str(m["id"])
	ctx.seed = seed_value
	ctx.rng = RandomNumberGenerator.new()
	ctx.rng.seed = seed_value
	ctx.max_frames = frames
	ctx.headless = DisplayServer.get_name() == "headless"
	ctx.mode = mode
	return ctx


## TLPack and its World (ctx.root) under the holder.
func make_scene() -> Node3D:
	pack_node = Node3D.new()
	pack_node.name = "TLPack"
	holder.add_child(pack_node)
	ctx.root = Node3D.new()
	ctx.root.name = "World"
	pack_node.add_child(ctx.root)
	return pack_node


## The pack's input record and views under the holder. `devices`: a person's devices reach ctx.input (play only).
func make_io(devices: bool) -> void:
	ctx.input = TLInput.new()
	ctx.input.name = "TLInput"
	ctx.input.accept_devices = devices
	holder.add_child(ctx.input)
	ctx.cameras = TLCameras.new()
	ctx.cameras.name = "TLCameras"
	holder.add_child(ctx.cameras)


## Generators, the entry and `_pack_setup`, then the laws on the tree. False (with a load error) when the pack cannot run.
func load_entry() -> bool:
	for step: Callable in load_steps():
		if not bool(step.call()):
			return false
	return true


## L4b: the same load as separate steps, in load_entry's order (one per asset generator, then the entry), so a driver
## may draw a frame between them (a dungeon's load screen). Each step returns false (with a load error) to stop.
func load_steps() -> Array:
	var steps: Array = []
	for gen: String in ctx.manifest["assets"]:
		steps.append(_generator_step.bind(gen))
	steps.append(_entry_step)
	return steps


func _generator_step(gen: String) -> bool:
	var gs: GDScript = load_script(gen)
	if gs == null:
		return false
	if not script_has(gs, "generate"):
		return fail(gen, "an asset generator needs `static func generate(ctx) -> void`")
	_begin("generate " + gen)
	gs.call("generate", ctx)
	_end("generate " + gen)
	return true


func _entry_step() -> bool:
	var m: Dictionary = ctx.manifest
	_mark("assets")
	var es: GDScript = load_script(str(m["entry"]))
	if es == null:
		return false
	_mark("script")
	var inst: Variant = es.new()
	if not (inst is Node):
		return fail(str(m["entry"]), "the entry script must extend Node")
	entry = inst
	entry.name = "Entry"
	for need: String in ["_pack_setup", "_pack_start"]:
		if not entry.has_method(need):
			entry.free()
			entry = null
			return fail(str(m["entry"]), "the entry script has no %s()" % need)
	has_tick = entry.has_method("_pack_tick")
	ctx._entry = entry
	pack_node.add_child(entry)
	_mark("enter_tree")
	_begin("_pack_setup")
	entry.call("_pack_setup", ctx)
	_end("_pack_setup")
	_mark("setup")
	TLLaws.apply_tree(pack_node)
	_mark("laws")
	return true


## The bot of test `t` (one of the manifest's tests) and its `_bot_setup`.
func load_bot(t: String) -> bool:
	test = t
	var tests: Array = ctx.manifest["tests"]
	if not tests.has(t):
		return fail(t, "--test must be one of the manifest's tests: %s" % ", ".join(PackedStringArray(tests)))
	var bs: GDScript = load_script(t)
	if bs == null:
		return false
	var binst: Variant = bs.new()
	if not (binst is Node):
		return fail(t, "a bot script must extend Node")
	bot = binst
	bot.name = "Bot"
	for need: String in ["_bot_setup", "_bot_tick", "_bot_done", "_bot_result"]:
		if not bot.has_method(need):
			bot.free()
			bot = null
			return fail(t, "the bot script has no %s()" % need)
	holder.add_child(bot)
	_begin("_bot_setup")
	bot.call("_bot_setup", ctx)
	_end("_bot_setup")
	_mark("bot")
	return true


## P12: one loader for both drivers. A changed .gd is seen by a world's reload; the first load in a process is the
## engine's cache, as a lone run always loaded it.
func load_script(rel: String) -> GDScript:
	var full: String = pack_dir + "/" + rel
	if not FileAccess.file_exists(full):
		fail(rel, "file not found")
		return null
	var s: GDScript = TLContext._load_fresh(full)
	if s == null or not s.can_instantiate():
		fail(rel, "the script did not load (parse error; see the script_error entries)")
		return null
	return s


static func script_has(s: GDScript, method: String) -> bool:
	for mi: Dictionary in s.get_script_method_list():
		if mi["name"] == method:
			return true
	return false


func _is_pack_script(sc: Script) -> bool:
	return sc != null and not pack_dir.is_empty() and (sc.resource_path.begins_with(pack_dir) or sc.resource_path.begins_with(ProjectSettings.localize_path(pack_dir)))


## WP5. A pack script on a node in the tree that defines `_process` or `_physics_process` while the node is not
## processing never runs: the usual cause is `set_script` after `add_child` (the engine switches processing on only
## when a node becomes ready). It fails nothing; alone the supervisor shows it in `smoke.loads`, a world on the plot line.
func find_idle_scripts(n: Node = null) -> void:
	if n == null:
		n = pack_node
	var sc: Script = n.get_script() as Script
	if sc is GDScript and n != entry and n.is_inside_tree() and _is_pack_script(sc) and warnings.size() < MAX_WARNINGS:
		var idle: PackedStringArray = PackedStringArray()
		if script_has(sc as GDScript, "_physics_process") and not n.is_physics_processing():
			idle.append("_physics_process")
		if script_has(sc as GDScript, "_process") and not n.is_processing():
			idle.append("_process")
		if not idle.is_empty():
			var rel: String = sc.resource_path.trim_prefix(pack_dir).trim_prefix(ProjectSettings.localize_path(pack_dir)).trim_prefix("/")
			var text: String = "%s on node '%s' never runs (%s is off): call set_script before add_child, or do the work in _pack_tick" % [
				rel, str(pack_node.get_path_to(n)), ", ".join(idle)]
			warnings.append(text)
			print("[tl] warning: " + text)
	for c: Node in n.get_children():
		find_idle_scripts(c)


## P7: a pack script's own event handlers (_input, _unhandled_input, ...) would read a device past ctx.input, and so
## past the input record: switched off when the node is ready (lint counts the handler as a bypass). Drivers call
## this for every node that enters the tree; only scripts of this pack, once per node.
func mute_if_pack(n: Node) -> void:
	if n.is_node_ready() or not _is_pack_script(n.get_script() as Script):
		return
	if not n.ready.is_connected(_mute.bind(n)):
		n.ready.connect(_mute.bind(n), CONNECT_ONE_SHOT)


static func _mute(n: Node) -> void:
	n.set_process_input(false)
	n.set_process_unhandled_input(false)
	n.set_process_unhandled_key_input(false)
	n.set_process_shortcut_input(false)


# ------------------------------------------------------------------------------------------------------ frames
## `_pack_start`, once, before the pack's first tick.
func start() -> void:
	_begin("_pack_start")
	entry.call("_pack_start")
	_end("_pack_start")


## The kernel's calls into the pack for its frame `f`. False when a call ran over its limit or `pre_sample` ended the
## run (the driver is stopping it). `bot_on`: the bot plays this frame (a world's person-played pack: false).
func tick(f: int, bot_on: bool = true, pre_sample: Callable = Callable()) -> bool:
	ctx.frame = f
	if f == ORDER_FRAME and OS.has_environment("TL_BODY_ORDER"):
		write_body_order(OS.get_environment("TL_BODY_ORDER"))
	if bot != null and bot_on:
		_begin("_bot_tick")
		bot.call("_bot_tick", f)
		if not _end("_bot_tick"):
			return false
	if pre_sample.is_valid() and not bool(pre_sample.call(f)):
		return false
	ctx.input._sample()
	if has_tick:
		_begin("_pack_tick")
		entry.call("_pack_tick", f)
		if not _end("_pack_tick"):
			return false
	return true


func bot_done(bot_on: bool = true) -> bool:
	return bot != null and bot_on and bool(bot.call("_bot_done"))


## The bot's verdict as both drivers report it: `{ok: bool, summary: String}` (plain JSON), or a failed result and a
## load error of kind `bot` when the bot returned anything else.
func bot_result() -> Dictionary:
	_begin("_bot_result")
	var r: Variant = bot.call("_bot_result")
	_end("_bot_result")
	if typeof(r) == TYPE_DICTIONARY and typeof((r as Dictionary).get("ok")) == TYPE_BOOL and typeof((r as Dictionary).get("summary")) == TYPE_STRING:
		return plain(r)
	load_errors.append({"kind": "bot", "file": test, "message": BOT_RESULT_ERROR})
	return {"ok": false, "summary": BOT_RESULT_BAD}


## E6 (selftest 760-e6-world-alone.sh): the colliders of the pack's physics space in the order a whole-space query
## lists them (its broadphase order), one path relative to the pack per line after `n=<count>`. Both drivers write it at
## frame ORDER_FRAME when TL_BODY_ORDER names a file (a world writes `<file>.<instance>`). Equal files in a world and
## alone mean the two spaces were built alike; a probe only, it changes nothing the pack can see.
func write_body_order(path: String) -> void:
	var st: PhysicsDirectSpaceState3D = TLContext.space_state_of(pack_node, ctx)
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(100000.0, 100000.0, 100000.0)
	q.shape = box
	q.transform = Transform3D(Basis.IDENTITY, ctx.origin)
	q.collide_with_areas = true
	q.collision_mask = 0xFFFFFFFF
	var hits: Array[Dictionary] = st.intersect_shape(q, 65536)
	var lines: PackedStringArray = ["n=%d" % hits.size()]
	for h: Dictionary in hits:
		var c: Object = h.get("collider")
		lines.append(str(pack_node.get_path_to(c as Node)) if c is Node and pack_node.is_ancestor_of(c as Node) else "<outside:%s>" % str(c))
	var file: String = path if ctx.instance.is_empty() else "%s.%s" % [path, ctx.instance]
	var fa: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	if fa != null:
		fa.store_string("\n".join(lines) + "\n")
		fa.close()


## Counts nodes, bodies and awake bodies under the pack, notes bodies below the ground budget (pack-local height),
## applies laws to bodies tagged late. Returns [nodes, bodies, awake]; `f` is the frame a first fall is noted at.
func census(f: int) -> Array:
	var counts: Array = [0, 0, 0]
	_census_node(pack_node, counts, f)
	entities_max = maxi(entities_max, int(counts[0]))
	bodies_max = maxi(bodies_max, int(counts[1]))
	awake_last = int(counts[2])
	return counts


func _census_node(n: Node, counts: Array, f: int) -> void:
	counts[0] = int(counts[0]) + 1
	if n is PhysicsBody3D:
		counts[1] = int(counts[1]) + 1
		if n is RigidBody3D and not (n as RigidBody3D).sleeping and not (n as RigidBody3D).freeze:
			counts[2] = int(counts[2]) + 1
		var y: float = (n as PhysicsBody3D).global_position.y - ctx.origin.y
		if y < BELOW_Y:
			below_count += 1
			if below.is_empty():
				below = {"node": str(pack_node.get_path_to(n)), "frame": f, "y": snappedf(y, 0.01)}
		if n.has_meta(&"tl_material") and not n.has_meta(&"tl_law_applied"):
			TLLaws.apply(n as CollisionObject3D)
	for c: Node in n.get_children():
		_census_node(c, counts, f)


# ------------------------------------------------------------------------------------------------------ the end
## SHA-256 over every physics body under the pack (pack-local), the canonical form of entry._pack_state(), the seeded
## generator and the input state (kernel/host/statehash.gd). `bodies_only`: bodies and state alone (the worker's
## hash_parts).
func state_hash(bodies_only: bool = false) -> String:
	var tail: String = canon(entry.call("_pack_state")) if entry != null and entry.has_method("_pack_state") else ""
	if bodies_only:
		return StateHash.call("hash", pack_node, tail)
	return StateHash.call("hash", pack_node, tail, ctx.rng, ctx.input, ctx.origin)


## `_pack_state()` as plain JSON data; null without it.
func pack_state() -> Variant:
	return plain(entry.call("_pack_state")) if entry != null and entry.has_method("_pack_state") else null


func teardown() -> void:
	if entry != null and entry.has_method("_pack_teardown"):
		_begin("_pack_teardown")
		entry.call("_pack_teardown")
		_end("_pack_teardown")


static func canon(v: Variant) -> String:
	return StateHash.call("canon", v)


## A JSON-safe copy of a pack-provided value (vectors become arrays, objects become their type name).
static func plain(v: Variant) -> Variant:
	return StateHash.call("plain", v)
