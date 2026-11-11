class_name TLContext
extends RefCounted
## The kernel's context object, handed to `_pack_setup(ctx)`, `generate(ctx)` and `_bot_setup(ctx)`.
## Capability: none (always available). See kernel/API.md.

## N2: the pack the kernel is calling right now. The kernel sets it around every call into a pack (setup, start,
## ticks, the bot, engine callbacks that kernel primitives hand on) and, in a world of several packs, clears it
## afterwards. It is NOT "the pack of this process" any more: a kernel node that needs its pack outside such a call
## asks `TLContext.of(node)`. Packs keep their own `ctx`.
static var current: TLContext = null
## Warn-once keys of calls made with no pack on the stack (kernel tools, tests).
static var _loose_warned: Dictionary = {}

var root: Node3D                       ## the pack builds its scene under this node
var rng: RandomNumberGenerator         ## seeded; the only source of randomness a pack may use
var seed: int = 1                      ## the run's seed (`--seed`)
var frame: int = 0                     ## current physics frame (60 per second), set by the kernel before every tick
var max_frames: int = 3600             ## frame budget of this run; a bot must finish before it
var pack_dir: String = ""              ## absolute directory of the pack
var pack_id: String = ""
var headless: bool = true              ## true when there is no window (verify runs): skip purely visual work
var manifest: Dictionary = {}          ## the parsed pack.json
var mode: String = "smoke"             ## "smoke", "bot", "capture" or "play"
var input: TLInput                     ## named actions (capability `input`)
var cameras: TLCameras                 ## named views, chase and orbit cameras (capability `camera`)


# ---- N2: everything a running pack owns hangs off its context ------------------------------------------------------
var instance: String = ""              ## the pack's name inside a world ("" in a single-pack run)
var holder: Node = null                ## the node every node of this pack lives under (the kernel's, not the pack's)
var origin: Vector3 = Vector3.ZERO     ## where the pack stands in the world (ctx.root's world position)
var on_stage: bool = true              ## false for a pack of a world the player is not in: its views do not take the viewport's camera
var space: RID = RID()                 ## the pack's own physics space; an invalid RID means the viewport's default space
var audio_events: Array = []           ## TLAudio's record of this pack: [{frame, preset, position?}]
var huds: Array = []                   ## the TLHud layers this pack made
var ball_group: StringName = &"tl_ball"   ## the scene-tree group of this pack's TLBalls (unique per pack in a world)
var _warned: Dictionary = {}           ## warn-once keys of the kernel primitives ("audio|preset", "laws|id", ...)
## N5a: "full" (a pack alone: its layout's far terrain and scattered forest are built) or "plot" (a world may ask for
## this: the landscape around a plot is the world's, so a `tl.layout/1` file is handed out with `forest.scatter` and
## `terrain.far` off; that is 70 to 90 % of a seed's loading time and no body of the simulation).
var scenery: String = "full"

var _cap_warned: Dictionary = {}
var _entry: Node = null
var _script_cache: Dictionary = {}


## True when the manifest declares the capability.
func has_capability(cap: String) -> bool:
	var caps: Variant = manifest.get("capabilities", [])
	return typeof(caps) == TYPE_ARRAY and (caps as Array).has(cap)


## Kernel primitives call this; using an undeclared capability is an error (once per capability and user).
static func require(cap: String, who: String) -> void:
	var c: TLContext = current
	if c == null or c.has_capability(cap):
		return
	var key: String = cap + "|" + who
	if not c._cap_warned.has(key):
		c._cap_warned[key] = true
		push_error("%s needs the capability '%s', which pack.json does not declare" % [who, cap])


## N2. The context of the pack a node belongs to: the nearest ancestor that carries one (the kernel tags the pack's
## holder node). A node that is not in a pack's tree yet (a factory is still building it) gets `current`.
static func of(node: Node) -> TLContext:
	var n: Node = node
	while n != null:
		if n.has_meta(&"tl_ctx"):
			return n.get_meta(&"tl_ctx") as TLContext
		n = n.get_parent()
	return current


## N2. Kernel side: makes `ctx` the pack being called and returns the one before, for `leave`. Kernel primitives
## use the pair around signals they hand to pack code from an engine callback (a contact, a trigger).
static func enter(ctx: TLContext) -> TLContext:
	var before: TLContext = current
	current = ctx
	return before


static func leave(before: TLContext) -> void:
	current = before


## N2. The physics queries of the pack `node` belongs to: its own space in a world, the viewport's space otherwise.
static func space_state_of(node: Node3D, ctx: TLContext = null) -> PhysicsDirectSpaceState3D:
	var c: TLContext = ctx if ctx != null else of(node)
	if c != null and c.space.is_valid():
		return PhysicsServer3D.space_get_direct_state(c.space)
	return node.get_world_3d().direct_space_state


## N2. True the first time `key` is seen by the pack being called (by the process when no pack is on the stack).
## The kernel's "log this error once" tables are per pack, so a second pack is told about its own mistake.
static func first_time(key: String, ctx: TLContext = null) -> bool:
	var c: TLContext = ctx if ctx != null else current
	var table: Dictionary = c._warned if c != null else _loose_warned
	if table.has(key):
		return false
	table[key] = true
	return true


## Reads a JSON file of the pack, by default from data/: `ctx.read_json("tuning.json")` reads `<pack>/data/tuning.json`.
## Returns the parsed value, or `null` after logging an error (missing file, bad JSON, path outside the pack).
func read_json(rel: String) -> Variant:
	var p: String = rel.replace("\\", "/")
	if p.contains("..") or p.contains("://") or p.is_absolute_path():
		push_error("ctx.read_json('%s'): the path must be relative to the pack's data/ directory" % rel)
		return null
	if not p.begins_with("data/"):
		p = "data/" + p
	var full: String = pack_dir + "/" + p
	if not FileAccess.file_exists(full):
		push_error("ctx.read_json('%s'): %s not found in the pack" % [rel, p])
		return null
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(full)) != OK:
		push_error("ctx.read_json('%s'): %s line %d: %s" % [rel, p, json.get_error_line() + 1, json.get_error_message()])
		return null
	if scenery == "plot" and typeof(json.data) == TYPE_DICTIONARY and str((json.data as Dictionary).get("schema", "")).begins_with("tl.layout/"):
		var layout: Dictionary = json.data
		var forest: Dictionary = layout.get("forest", {}) if typeof(layout.get("forest")) == TYPE_DICTIONARY else {}
		forest["scatter"] = false
		layout["forest"] = forest
		if typeof(layout.get("terrain")) == TYPE_DICTIONARY:
			(layout["terrain"] as Dictionary)["far"] = false
	return json.data


## Loads another script of the pack: `var Puck = ctx.load_script("scripts/puck.gd")`. Works wherever the pack lives.
func load_script(rel: String) -> GDScript:
	var p: String = rel.replace("\\", "/")
	if p.contains("..") or p.contains("://") or p.is_absolute_path() or p.get_extension() != "gd":
		push_error("ctx.load_script('%s'): the path must be a .gd file relative to the pack" % rel)
		return null
	if _script_cache.has(p):
		return _script_cache[p]
	var full: String = pack_dir + "/" + p
	if not FileAccess.file_exists(full):
		push_error("ctx.load_script('%s'): not found in the pack" % rel)
		return null
	var s: GDScript = _load_fresh(full)
	if s == null or not s.can_instantiate():
		push_error("ctx.load_script('%s'): the script did not load" % rel)
		return null
	_script_cache[p] = s
	return s


## P12 (PATCHES-P5 2b). A pack's script by absolute path, as it is on disk NOW: the engine's cache (`load`) keeps the
## first version for the whole process, so a world's `reload` saw a changed data file but not a changed `.gd`. Keyed by
## path and content (MD5; a modified time has one-second steps): an unchanged file is the script loaded before, a
## changed one is loaded again past the engine's cache (with what it preloads). Kernel side: pack.gd's loader, the
## build queue's preparation and `load_script` use it; any thread.
static var _fresh: Dictionary = {}       # absolute path -> [md5, GDScript]
static var _fresh_lock: Mutex = Mutex.new()


static func _load_fresh(full: String) -> GDScript:
	var md5: String = FileAccess.get_md5(full)
	_fresh_lock.lock()
	var got: Variant = _fresh.get(full, null)
	_fresh_lock.unlock()
	if got != null and str((got as Array)[0]) == md5:
		return (got as Array)[1]
	var s: GDScript = null
	if got == null:
		s = load(full) as GDScript                # first time in this process: the engine's cache, as before
	else:
		s = ResourceLoader.load(full, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as GDScript
	_fresh_lock.lock()
	_fresh[full] = [md5, s]
	_fresh_lock.unlock()
	return s


## The game state as the entry script reports it (`_pack_state()`); {} when the pack has none. This is how a bot
## reads the game: `var s := ctx.pack_state()`.
func pack_state() -> Dictionary:
	if _entry != null and is_instance_valid(_entry) and _entry.has_method("_pack_state"):
		var s: Variant = _entry.call("_pack_state")
		if typeof(s) == TYPE_DICTIONARY:
			return s
		push_error("_pack_state() must return a Dictionary")
	return {}


## Seconds for a frame count and back (the sim is fixed at 60 Hz).
func seconds(frame_count: int) -> float:
	return float(frame_count) / 60.0


func frames(seconds_: float) -> int:
	return int(round(seconds_ * 60.0))


## Deterministic replacements for Array.pick_random() and Array.shuffle().
func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[rng.randi_range(0, items.size() - 1)]


func shuffle(items: Array) -> void:
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Variant = items[i]
		items[i] = items[j]
		items[j] = t


## A log line that is easy to find in the run's output.
func info(message: String) -> void:
	print("[pack %s f%d] %s" % [pack_id, frame, message])
