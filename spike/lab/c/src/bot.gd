class_name BotUnit
extends Node3D
## Builder bot on the shared small-bot skeleton. States: idle, walk, work (weld torch + sparks).

var style: Style
var rig: Dictionary
var skel: Skeleton3D
var ap: AnimationPlayer
var state: String = "idle"
var home: Vector3
var target: Vector3
var has_target: bool = false
var on_arrive: Callable
var sparks: GPUParticles3D
var weld_light: OmniLight3D
var yaw: float = 0.0
var _t: float = 0.0


func setup(st: Style, state0: String, yaw_deg: float) -> void:
	style = st
	rig = Rig.build("bot", "res://assets/bot.vxm", st)
	add_child(rig["root"])
	skel = rig["skel"]
	ap = rig["anim"]
	yaw = deg_to_rad(yaw_deg)
	rotation.y = yaw
	_build_clips()
	var tip := BoneAttachment3D.new()
	skel.add_child(tip)
	tip.bone_name = "Tool"
	var n3 := Node3D.new()
	n3.position = Vector3(0, -0.07, -0.23)
	tip.add_child(n3)
	sparks = Fx.sparks(n3)
	weld_light = OmniLight3D.new()
	weld_light.light_color = Color(1.0, 0.7, 0.35)
	weld_light.light_energy = 0.0
	weld_light.omni_range = 2.5
	n3.add_child(weld_light)
	set_state(state0)
	_t = randf() * 3.0
	ap.seek(randf() * 2.0)


func _q(x: float = 0.0, y: float = 0.0, z: float = 0.0) -> Quaternion:
	return Quaternion.from_euler(Vector3(x, y, z))


func _build_clips() -> void:
	var bones: Array = []
	for b: Array in Rig.rig_def("bot"):
		bones.append(b[0])
	var f := func(b: String, u: float, mode: String) -> Variant:
		var ph := u * TAU
		var s := sin(ph)
		if mode == "idle":
			match b:
				"Body": return _q(0.02 * s, 0, 0)
				"Head": return _q(0.0, 0.35 * s, 0.04 * cos(ph))
				"ArmL": return _q(0.06 * sin(ph + 1), 0, -0.08)
				"ArmR": return _q(-0.06 * sin(ph + 1), 0, 0.08)
				_: return _q()
		elif mode == "walk":
			match b:
				"Body": return _q(-0.06, 0.05 * s, 0)
				"Head": return _q(0.04, 0, 0)
				"ArmL": return _q(-0.7 * s, 0, -0.06)
				"ArmR": return _q(0.7 * s, 0, 0.06)
				"LegL": return _q(0.75 * s, 0, 0)
				"LegR": return _q(-0.75 * s, 0, 0)
				_: return _q()
		else:
			var j := sin(ph * 6.0) * 0.05 + sin(ph * 11.0) * 0.03
			match b:
				"Body": return _q(-0.14 + 0.02 * s, 0.25, 0)
				"Head": return _q(-0.35, -0.2, 0)
				"ArmL": return _q(0.9 + 0.05 * s, 0.1, -0.25)
				"ArmR": return _q(1.25 + j, -0.15, 0.2)
				"Tool": return _q(0.25 + j * 2.0, 0, 0)
				"LegL": return _q(0.1, 0, 0)
				"LegR": return _q(-0.12, 0, 0)
				_: return _q()
	var clips: Dictionary = {}
	for mode: String in ["idle", "walk", "work"]:
		var length := 2.4 if mode == "idle" else (0.5 if mode == "walk" else 1.2)
		clips[mode] = Rig.make_clip(bones, length, func(b: String, u: float) -> Variant: return f.call(b, u, mode), Callable(), 24)
	Rig.add_clips(ap, clips)


func set_state(s: String) -> void:
	state = s
	ap.play(s, 0.2)
	sparks.emitting = (s == "work")
	weld_light.light_energy = 0.0


func go_to(p: Vector3, cb: Callable = Callable()) -> void:
	target = p
	has_target = true
	on_arrive = cb
	set_state("walk")


func _process(delta: float) -> void:
	_t += delta
	if has_target:
		var d := target - position
		d.y = 0
		var dist := d.length()
		if dist < 0.15:
			has_target = false
			position = Vector3(target.x, position.y, target.z)
			rotation.y = yaw
			if on_arrive.is_valid():
				on_arrive.call(self)
		else:
			var step := minf(dist, 3.4 * delta)
			position += d / dist * step
			rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(delta * 10.0, 0, 1))
	if state == "work":
		weld_light.light_energy = 0.8 + 0.6 * sin(_t * 47.0) * sin(_t * 31.0)
