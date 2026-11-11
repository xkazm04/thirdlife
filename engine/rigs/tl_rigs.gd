class_name TLRigs
extends RefCounted
## Rigs (kernelApi 0.1, contracts/KIT-RIG-STYLE.md): TLRigs.build(family, params) -> Node3D for `biped`, `vehicle`, `bot`.
## A rig is visual only. Every rig node answers: family, metrics(), clips(), play(clip, blend),
## set_locomotion(velocity_local, grounded), set_param(name, value), socket(name), tick(frame).
## TLRigs.spec(family) / TLRigs.validate(family, params) mirror the kit functions (same shapes as TLKit.spec / validate).
## Build params are also the initial values of the runtime params of the same name (set_param changes them later).

const BIPED_COLORS: Array = ["skin", "hair", "top", "trim", "legs", "boots", "pack", "strap", "stick"]

## family -> [doc, "", false, {param: [type, default, min, max, doc]}]  (the row format of TLKit.PARTS)
const FAMILIES: Dictionary = {
	"biped": ["Standard biped on Godot humanoid bone names, 29 bones. Clips: idle, walk, run, skate, skate_stop, shoot, pass, cheer, fall, carry, work.", "", false, {
		"seed": ["int", 1, 0, 1000000, "reserved for variation (no effect in v0.1)"], "scale": ["float", 1.0, 0.5, 2.0, "uniform scale (1 = 2.0 m tall with hair)"],
		"colors": ["dict", {}, ["skin", "hair", "top", "trim", "legs", "boots", "pack", "strap", "stick"], "", "palette key per part; absent parts keep the default look"],
		"mode": ["enum", "walk", ["walk", "skate"], "", "locomotion mode: walk = idle / walk / run by speed; skate = glide / stride by speed, skate blades shown"],
		"stick": ["bool", false, "", "", "show a hockey stick in hand_r; arms take the two-handed hold (same as prop = stick)"],
		"prop": ["enum", "auto", ["auto", "none", "stick", "hammer"], "", "what hand_r holds: auto = the stick in skate mode, nothing in walk mode; hammer goes with the work clip"],
		"headgear": ["enum", "auto", ["auto", "none", "helmet"], "", "auto = a team helmet in the top colour and the hockey kit (white hem band, number patch) in skate mode, hair in walk mode"],
		"backpack": ["bool", true, "", "", "the lane-B backpack (build time only)"],
		"expression": ["enum", "happy", ["happy", "focus", "blink"], "", "face"],
		"lean": ["float", 0.0, -1.0, 1.0, "side lean of the locomotion pose, + = right"]}],
	"vehicle": ["Coupe. Clips: idle. Wheels steer and spin, each wheel moves with its suspension value, nitro flame, brake lights.", "", false, {
		"seed": ["int", 1, 0, 1000000, "reserved for variation (no effect in v0.1)"], "scale": ["float", 1.0, 0.5, 2.0, "uniform scale"],
		"colors": ["dict", {}, ["body", "stripe"], "", "palette key per part"],
		"spoiler": ["bool", true, "", "", "rear wing (build time only)"],
		"steer": ["float", 0.0, -1.0, 1.0, "+ = left"], "throttle": ["float", 0.0, 0.0, 1.0, ""], "brake": ["float", 0.0, 0.0, 1.0, "shows the brake lights"],
		"wheel_spin": ["float", 0.0, -400.0, 400.0, "rad/s, + = rolling forward"],
		"suspension": ["floats", [0.0, 0.0, 0.0, 0.0], 4, "", "metres of compression, order FL FR RL RR"],
		"nitro": ["float", 0.0, 0.0, 1.0, "flame size"]}],
	"bot": ["Crew bot, 11 bones. Clips: idle, walk, work, carry, weld.", "", false, {
		"seed": ["int", 1, 0, 1000000, "reserved for variation (no effect in v0.1)"], "scale": ["float", 1.0, 0.3, 3.0, "uniform scale (1 = about 1.5 m with hat and beacon, the lane-B site size)"],
		"colors": ["dict", {}, ["body", "hat"], "", "palette key per part"],
		"beacon": ["bool", true, "", "", "the lamp on the hat glows"]}],
}
## runtime-only params (set_param), documented in spec() under `runtime`
const RUNTIME: Dictionary = {
	"biped": {"look_at": "Vector3 in world space, or null to clear: neck and head turn towards it (clamped)"},
	"vehicle": {},
	"bot": {"look_at": "Vector3 in world space, or null to clear: the head turns towards it"},
}


static func list() -> PackedStringArray:
	return PackedStringArray(FAMILIES.keys())


static func spec(family: String) -> Dictionary:
	if not FAMILIES.has(family):
		return {}
	var out: Dictionary = TLKit.expand_spec(FAMILIES[family])
	out["runtime"] = RUNTIME[family]
	return out


static func validate(family: String, params: Dictionary) -> PackedStringArray:
	if not FAMILIES.has(family):
		return PackedStringArray(["'%s' is not a rig family (families: %s)" % [family, ", ".join(FAMILIES.keys())]])
	return TLKit.check_params("rig " + family, FAMILIES[family][3], params)


static func build(family: String, params: Dictionary = {}) -> Node3D:
	var main: bool = OS.get_thread_caller_id() == OS.get_main_thread_id()
	var rig: Node3D = null
	if main:
		if _recording:
			_record.append([family, params.duplicate(true)])
		if _ahead_count > 0:
			rig = _take_ahead(_key_of(family, params))
	if rig == null:
		rig = _build_rig(family, params)
	return rig


# ---- P12: a rig built ahead of the `build` call that will ask for it (as TLKit's layouts, P5) ---------------------
# A rig references nothing outside rigs/kit/style and is built off the scene tree, so it may be built on a worker
# thread. `_rig_ahead(family, params)` builds exactly what `build` builds and keeps it; the next `build` of the same
# family and EQUAL params on the main thread takes it instead of building. One result serves one call. The kernel's
# loader learns which rigs a pack builds by recording a build of it (`record`), and builds those ahead next time.
static var _ahead: Dictionary = {}       # key -> Array of rigs
static var _ahead_count: int = 0
static var _ahead_lock: Mutex = Mutex.new()
static var _recording: bool = false
static var _record: Array = []


## The identity of a call: family and params (equal params give the same key).
static func _key_of(family: String, params: Dictionary) -> String:
	return family + "|" + var_to_str(params)


## Builds a rig ahead (any thread). Returns its key ("" when the params are not valid).
static func _rig_ahead(family: String, params: Dictionary) -> String:
	if validate(family, params).size() > 0:
		return ""
	var rig: Node3D = _build_rig(family, params)
	var key: String = _key_of(family, params)
	_ahead_lock.lock()
	if not _ahead.has(key):
		_ahead[key] = []
	(_ahead[key] as Array).append(rig)
	_ahead_count += 1
	_ahead_lock.unlock()
	return key


static func _take_ahead(key: String) -> Node3D:
	var rig: Node3D = null
	_ahead_lock.lock()
	if _ahead.has(key):
		var list: Array = _ahead[key]
		rig = list.pop_front()
		_ahead_count -= 1
		if list.is_empty():
			_ahead.erase(key)
	_ahead_lock.unlock()
	return rig


## Frees one rig built ahead that no `build` asked for (main thread). True when there was one.
static func _drop_rig(key: String) -> bool:
	var rig: Node3D = _take_ahead(key)
	if rig == null:
		return false
	rig.free()
	return true


## Main thread. `_record_rigs(true)` starts noting every `build` call; `_record_rigs(false)` stops and returns the calls as
## [[family, params], ...] in call order.
static func _record_rigs(on: bool) -> Array:
	_recording = on
	var out: Array = _record
	_record = []
	return out


static func _build_rig(family: String, params: Dictionary) -> Node3D:
	var errs: PackedStringArray = validate(family, params)
	if errs.size() > 0:
		push_error("TLRigs.build: " + "; ".join(errs))
		return null
	var p: Dictionary = TLKit.with_defaults(FAMILIES[family][3], params)
	var rig: TLRigNode
	match family:
		"biped": rig = TLRigBiped.new()
		"vehicle": rig = TLRigVehicle.new()
		_: rig = TLRigBot.new()
	rig.set_meta("tl_kind", "rig." + family)
	rig.set_meta("tl_params", p)
	rig.call("setup", p)
	return rig
