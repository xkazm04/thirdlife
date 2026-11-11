class_name TLVfx
extends RefCounted
## Visual effect presets by name. With the style installed they are drawn by the style layer (`TLStyleFx.preset`);
## without it by stand-in implementations (plain particle bursts). An effect frees itself
## after its lifetime, counted in physics frames. In headless runs no particles are made; the call still succeeds
## and returns a node that lives just as long, so game logic never depends on having a window. Capability: `vfx`.
##
##   TLVfx.burst(&"dust", wall.global_position, ctx.root)
##   var flame := TLVfx.attach(&"nitro_flame", car.rig.socket(&"exhaust_l"))     # until flame.queue_free()

## preset -> {color, amount, speed (m/s), spread (degrees), gravity (m/s2, + = falls), size, life (frames), up (bool)}
const PRESETS: Dictionary = {
	&"dust": {"color": Color(0.72, 0.68, 0.6, 0.8), "amount": 40, "speed": 2.5, "spread": 180.0, "gravity": 0.6, "size": 0.35, "life": 70},
	&"sparks": {"color": Color(1.0, 0.8, 0.3), "amount": 30, "speed": 6.0, "spread": 60.0, "gravity": 9.8, "size": 0.06, "life": 35},
	&"smoke": {"color": Color(0.3, 0.3, 0.32, 0.7), "amount": 24, "speed": 1.2, "spread": 30.0, "gravity": -1.0, "size": 0.5, "life": 120},
	&"ice_spray": {"color": Color(0.9, 0.96, 1.0, 0.9), "amount": 36, "speed": 4.0, "spread": 50.0, "gravity": 6.0, "size": 0.08, "life": 40},
	&"debris": {"color": Color(0.5, 0.5, 0.5), "amount": 20, "speed": 5.0, "spread": 120.0, "gravity": 9.8, "size": 0.14, "life": 80},
	&"nitro_flame": {"color": Color(0.35, 0.7, 1.0), "amount": 28, "speed": 5.0, "spread": 10.0, "gravity": 0.0, "size": 0.16, "life": 14},
	&"confetti": {"color": Color(1.0, 0.4, 0.6), "amount": 80, "speed": 6.0, "spread": 70.0, "gravity": 4.0, "size": 0.08, "life": 150},
	&"splash": {"color": Color(0.6, 0.8, 1.0, 0.8), "amount": 40, "speed": 4.5, "spread": 80.0, "gravity": 9.8, "size": 0.1, "life": 50},
	&"goal_flash": {"color": Color(1.0, 0.95, 0.6), "amount": 50, "speed": 8.0, "spread": 180.0, "gravity": 0.0, "size": 0.12, "life": 30},
}

# N2: the warn-once table is per pack (TLContext.first_time).


static func presets() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: StringName in PRESETS.keys():
		out.append(String(k))
	return out


## A one-shot effect at a world position, added under `parent` and freed after the preset's lifetime.
## Options: direction (Vector3, default up), scale (float), color (Color).
static func burst(preset: StringName, position: Vector3, parent: Node, opts: Dictionary = {}) -> Node3D:
	var fx: TLVfxNode = _make(preset, opts, true)
	parent.add_child(fx)
	fx.global_position = position
	return fx


## A continuous effect attached to a node (an exhaust socket, a skate). It runs until you free it or call
## `stop()` on it. Returns null when `target` is null (a rig without that socket).
static func attach(preset: StringName, target: Node3D, opts: Dictionary = {}) -> Node3D:
	if target == null:
		return null
	var fx: TLVfxNode = _make(preset, opts, false)
	target.add_child(fx)
	return fx


static func _make(preset: StringName, opts: Dictionary, one_shot: bool) -> TLVfxNode:
	TLContext.require("vfx", "TLVfx")
	if not PRESETS.has(preset):
		if TLContext.first_time("vfx|" + String(preset)):
			push_error("TLVfx: unknown preset '%s' (presets: %s)" % [preset, ", ".join(presets())])
		preset = &"dust"
	for k: String in opts.keys():
		if not ["direction", "scale", "color"].has(k):
			push_error("TLVfx: unknown option '%s' (direction, scale, color)" % k)
	var p: Dictionary = PRESETS[preset]
	var fx: TLVfxNode = TLVfxNode.new()
	fx.name = "Vfx_" + String(preset)
	fx.preset = preset
	fx.one_shot = one_shot
	fx.frames_left = int(p["life"]) + 5 if one_shot else -1
	var headless: bool = TLContext.current != null and TLContext.current.headless
	if not headless:
		var parts: CPUParticles3D = _style_particles(preset, int(p["life"]), opts, one_shot)
		if parts != null:
			fx.add_child(parts)
			fx.particles = parts
			return fx
		parts = CPUParticles3D.new()
		var scale_: float = float(opts.get("scale", 1.0))
		parts.amount = int(p["amount"])
		parts.lifetime = float(p["life"]) / 60.0
		parts.one_shot = one_shot
		parts.explosiveness = 0.9 if one_shot else 0.0
		parts.direction = opts.get("direction", Vector3.UP)
		parts.spread = float(p["spread"])
		parts.initial_velocity_min = float(p["speed"]) * 0.5 * scale_
		parts.initial_velocity_max = float(p["speed"]) * scale_
		parts.gravity = Vector3(0, -float(p["gravity"]), 0)
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2.ONE * float(p["size"]) * scale_
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = opts.get("color", p["color"])
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		quad.material = mat
		parts.mesh = quad
		parts.emitting = true
		fx.add_child(parts)
		fx.particles = parts
	return fx


## N5a. Squash and stretch on a VISUAL node (a rig, a mesh, a kit part without a body): the seam onto the style's
## helper (`TLStyleFx.squash`). Visual only; frame-counted. Without the style layer nothing happens.
static func squash(visual: Node3D, amount: float = 0.25, frames: int = 18, axis: Vector3 = Vector3.UP) -> void:
	TLContext.require("vfx", "TLVfx.squash")
	var fxs: GDScript = TLStandin.ext("TLStyleFx")
	if visual == null or fxs == null or not TLStandin.script_has(fxs, "squash"):
		return
	fxs.call("squash", visual, amount, frames, axis)


## N5a. A ribbon that follows `target` and fades behind it: the seam onto `TLStyleFx.trail`. Options `width`,
## `frames`, `color`, `offset`. Returns the trail node (free it to stop), or null without a target or the style layer.
static func trail(target: Node3D, opts: Dictionary = {}) -> Node3D:
	TLContext.require("vfx", "TLVfx.trail")
	var fxs: GDScript = TLStandin.ext("TLStyleFx")
	if target == null or fxs == null or not TLStandin.script_has(fxs, "trail"):
		return null
	return fxs.call("trail", target, opts) as Node3D


## WP5 (KIT-RIG-STYLE.md, second round): with the style installed a preset is drawn by the style layer's effects
## (`TLStyleFx.preset`), so it matches the look; null when the style is absent or does not know the preset.
## The lifetime stays the kernel's (frames), so a headless run and a windowed run free the effect on the same frame.
static func _style_particles(preset: StringName, life_frames: int, opts: Dictionary, one_shot: bool) -> CPUParticles3D:
	var fxs: GDScript = TLStandin.ext("TLStyleFx")
	if fxs == null or TLStandin.ext("TLStyle") == null or not TLStandin.script_has(fxs, "preset"):
		return null
	var so: Dictionary = opts.duplicate()
	so["life_frames"] = life_frames
	so["one_shot"] = one_shot
	return fxs.call("preset", String(preset), so) as CPUParticles3D
