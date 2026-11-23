class_name TLCores
extends RefCounted
## `ctx.cores`: the engine's game cores (engine/cores/<id>/), compiled native simulations a pack drives frame by frame.
## Capability: none (always available). See kernel/API.md section 24.
##
##   var rink = ctx.cores.open("rink", "hockey.regular.cartridge.json")   # the core object, its cartridge loaded from data/
##   rink.set_difficulty("pro"); rink.reset(ctx.seed)
##   func _pack_tick(_f): rink.set_human_input({...}); rink.step()
##   func _pack_state(): return ctx.cores.state()                          # each open core's hash, frame and score
##
## A pack never loads an extension itself: open() is the one door (and view_script() the one door to a core's drawing side). A core that is not built is reported once with the
## command that builds it, and open() returns null.

## id -> the class the core's extension registers, and the command that builds it.
const KNOWN: Dictionary = {
	"rink": {"class": "RinkCore", "build": "bash engine/tools/rink.sh build"},
}

var _ctx: WeakRef = null
var _open: Array = []   # [[id, core], ...] in the order the pack opened them


func _init(ctx: Object = null) -> void:
	_ctx = weakref(ctx) if ctx != null else null


## The core `id` as an object (rink: RinkCore, engine/cores/rink/SNAPSHOT.md), or null with an error when the id is unknown,
## the core is not built, or `cartridge` does not load. `cartridge`: a file under the pack's data/ (as ctx.read_json reads
## it), handed to the core as text; "" = load nothing (the pack calls load_cartridge itself).
func open(id: String, cartridge: String = "") -> Object:
	if not KNOWN.has(id):
		push_error("ctx.cores.open: no core '%s' (known: %s)" % [id, ", ".join(PackedStringArray(KNOWN.keys()))])
		return null
	var cls: String = str(KNOWN[id]["class"])
	if not ClassDB.class_exists(cls):
		push_error("ctx.cores.open: the core '%s' is not built (%s)" % [id, str(KNOWN[id]["build"])])
		return null
	var core: Object = ClassDB.instantiate(cls)
	if cartridge != "":
		var c: Object = _ctx.get_ref() if _ctx != null else null
		var dir: String = str(c.get("pack_dir")) if c != null else ""
		var p: String = cartridge.replace("\\", "/")
		if dir == "" or p.contains("..") or p.is_absolute_path():
			push_error("ctx.cores.open: cartridge '%s' must be a file under the pack's data/" % cartridge)
			return null
		var full: String = dir + "/data/" + p
		if not FileAccess.file_exists(full):
			push_error("ctx.cores.open: cartridge data/%s not found" % p)
			return null
		var err: String = str(core.call("load_cartridge", FileAccess.get_file_as_string(full)))
		if err != "":
			push_error("ctx.cores.open: cartridge data/%s does not load: %s" % [p, err])
			return null
	_open.append([id, core])
	return core


## A presentation script of the core `id` (1.20): `engine/cores/<id>/view/<name>.gd`, the core's own drawing side that a
## pack may use beside the core (rink: "skater_pawn", thirdjam's AJamSkater, one per skater). `name` is a plain file name
## without `.gd`. Null and an error when the id is unknown or there is no such script. Presentation only: what the script
## does never enters the core's hash.
func view_script(id: String, name: String) -> GDScript:
	if not KNOWN.has(id):
		push_error("ctx.cores.view_script: no core '%s' (known: %s)" % [id, ", ".join(PackedStringArray(KNOWN.keys()))])
		return null
	if not RegEx.create_from_string("^[a-z_][a-z0-9_]*$").search(name):
		push_error("ctx.cores.view_script: '%s' is not a plain script name (lower case, digits, _)" % name)
		return null
	var path: String = "res://cores/%s/view/%s.gd" % [id, name]
	if not ResourceLoader.exists(path):
		push_error("ctx.cores.view_script: the core '%s' has no view script '%s'" % [id, name])
		return null
	return load(path) as GDScript


## What `_pack_state()` returns for the open cores: {"<id>": {"hash": 16 hex digits, "frame": int, "score": [a, b]}}
## ("<id>#2" for a second core of the same id). The core's own hash covers everything it simulates.
func state() -> Dictionary:
	var out: Dictionary = {}
	for e: Array in _open:
		var key: String = str(e[0])
		var n: int = 2
		while out.has(key):
			key = "%s#%d" % [e[0], n]
			n += 1
		var core: Object = e[1]
		out[key] = {"hash": str(core.call("state_hash_hex")), "frame": int(core.call("get_frame")), "score": core.call("get_score")}
	return out
