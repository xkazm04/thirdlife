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
		"stick": ["bool", false, "", "", "show a hockey stick in hand_r; arms take the two-handed hold"],
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
