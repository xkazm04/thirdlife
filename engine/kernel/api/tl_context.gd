class_name TLContext
extends RefCounted
## The kernel's context object, handed to `_pack_setup(ctx)`, `generate(ctx)` and `_bot_setup(ctx)`.
## Capability: none (always available). See kernel/API.md.

## The one live context of this process (a process runs one pack). Kernel primitives use it; packs keep their own `ctx`.
static var current: TLContext = null

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
	var s: GDScript = load(full) as GDScript
	if s == null or not s.can_instantiate():
		push_error("ctx.load_script('%s'): the script did not load" % rel)
		return null
	_script_cache[p] = s
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
