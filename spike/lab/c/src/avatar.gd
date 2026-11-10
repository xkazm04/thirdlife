class_name Avatar
extends CharacterBody3D
## The player avatar: voxel parts on the standard humanoid skeleton, clips idle/walk/run built from code,
## holding the holographic tablet. WASD is camera-relative.

const SPEED_WALK := 2.6
const SPEED_RUN := 5.6

var style: Style
var rig: Dictionary
var skel: Skeleton3D
var ap: AnimationPlayer
var model: Node3D
var face_yaw: float = 0.0
var cam_yaw: float = 0.0
var controllable: bool = true
var _state: String = ""
var tablet_node: Node3D


func setup(st: Style) -> void:
	style = st
	rig = Rig.build("biped", "res://assets/avatar.vxm", st)
	model = rig["root"]
	add_child(model)
	skel = rig["skel"]
	ap = rig["anim"]
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.7
	col.shape = cap
	col.position = Vector3(0, 0.86, 0)
	add_child(col)
	floor_snap_length = 0.7
	floor_max_angle = deg_to_rad(68)
	_build_tablet()
	_build_clips()
	ap.play("idle")


func _build_tablet() -> void:
	var ba := BoneAttachment3D.new()
	skel.add_child(ba)
	ba.bone_name = "RightHand"
	tablet_node = Node3D.new()
	ba.add_child(tablet_node)
	var ch := Vxm.load_chunks("res://assets/tablet.vxm", style)
	var mi := MeshInstance3D.new()
	mi.mesh = ch[0]["mesh"]
	# tablet sits on the palm: screen faces up/back toward the player's eyes
	tablet_node.position = Vector3(0.0, -0.045, -0.035)
	tablet_node.rotation = Vector3(deg_to_rad(-62), 0, 0)
	tablet_node.add_child(mi)
	var gl := OmniLight3D.new()
	gl.light_color = Color(0.25, 0.9, 1.0)
	gl.light_energy = 0.9
	gl.omni_range = 2.2
	gl.position = Vector3(0, 0.12, 0)
	tablet_node.add_child(gl)
	# floating blueprint hologram above the tablet (tiny wire arch)
	var bp := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 0.001, 0.12)
	bp.visible = false
	tablet_node.add_child(bp)
	# backpack light as a real light so it glows on the shoulders
	var pl := OmniLight3D.new()
	pl.light_color = Color(0.3, 0.9, 1.0)
	pl.light_energy = 0.6
	pl.omni_range = 1.6
	var ba2 := BoneAttachment3D.new()
	skel.add_child(ba2)
	ba2.bone_name = "Chest"
	ba2.add_child(pl)
	pl.position = Vector3(0.13, 0.32, 0.25)


func _q(x: float = 0.0, y: float = 0.0, z: float = 0.0) -> Quaternion:
	return Quaternion.from_euler(Vector3(x, y, z))


func _build_clips() -> void:
	var bones: Array = []
	for b: Array in Rig.rig_def("biped"):
		bones.append(b[0])
	var hold_ua := Vector3(deg_to_rad(52), 0, deg_to_rad(-9))
	var hold_la := deg_to_rad(78)

	var pose := func(b: String, u: float, mode: String) -> Variant:
		var ph := u * TAU
		var amp: float = 0.0
		var arm: float = 0.0
		var knee: float = 0.0
		var lean: float = 0.0
		var el: float = 0.0
		match mode:
			"walk":
				amp = 0.46; arm = 0.38; knee = 0.7; lean = -0.03; el = 0.28
			"run":
				amp = 0.95; arm = 0.8; knee = 1.35; lean = -0.20; el = 1.25
			_:
				amp = 0.0; arm = 0.0; knee = 0.0; lean = 0.0; el = 0.12
		var s := sin(ph)
		var c := cos(ph)
		var idle := mode == "idle"
		match b:
			"Hips":
				return _q(0, 0.06 * s * (0.0 if idle else 1.0), 0.03 * s * (0.0 if idle else 1.0))
			"Spine":
				return _q(lean * 0.6 + (0.018 * sin(ph) if idle else 0.0), -0.08 * s * (0.0 if idle else 1.0), 0)
			"Chest":
				return _q(lean * 0.6 + (0.012 * sin(ph + 0.6) if idle else 0.0), -0.05 * s * (0.0 if idle else 1.0), 0)
			"Neck":
				return _q(-lean * 0.4, 0, 0)
			"Head":
				return _q(-lean * 0.5 + (0.0 if not idle else 0.04), 0.09 * sin(ph * (1.0 if idle else 0.5)) * (1.0 if idle else 0.3), 0)
			"LeftUpperLeg":
				return _q(amp * s + (0.0), 0, 0.02)
			"RightUpperLeg":
				return _q(-amp * s, 0, -0.02)
			"LeftLowerLeg":
				return _q(-knee * maxf(0.0, -c * 0.5 + 0.5 * (1.0 if amp > 0 else 0.0)) * (1.0 if amp > 0 else 0.0), 0, 0)
			"RightLowerLeg":
				return _q(-knee * maxf(0.0, c * 0.5 + 0.5 * (1.0 if amp > 0 else 0.0)) * (1.0 if amp > 0 else 0.0), 0, 0)
			"LeftFoot":
				return _q(0.15 * s * (0.0 if idle else 1.0) + 0.0, 0, 0)
			"RightFoot":
				return _q(-0.15 * s * (0.0 if idle else 1.0), 0, 0)
			"LeftUpperArm":
				return _q(-arm * s + (0.03 * sin(ph + 1.0) if idle else 0.0), 0, -0.05)
			"LeftLowerArm":
				return _q(el + (0.0 if not idle else 0.03 * sin(ph)), 0, 0)
			"RightUpperArm":
				return Quaternion.from_euler(Vector3(hold_ua.x + (0.04 * s if not idle else 0.012 * sin(ph)), 0, hold_ua.z))
			"RightLowerArm":
				return _q(hold_la + (0.05 * s if not idle else 0.0), 0, 0)
			"RightHand":
				return _q(-0.5, 0, 0)
			"LeftHand":
				return _q(0.0, 0, 0)
		return null
	var pos := func(b: String, u: float, mode: String) -> Variant:
		if b == "Hips":
			var ph := u * TAU
			var base := Vector3(0, 0.80, 0)
			match mode:
				"walk":
					return base + Vector3(0, 0.022 * cos(2 * ph), 0)
				"run":
					return base + Vector3(0, -0.03 + 0.05 * cos(2 * ph), 0)
				_:
					return base + Vector3(0, 0.004 * sin(ph), 0)
		return null
	var clips: Dictionary = {}
	for mode: String in ["idle", "walk", "run"]:
		var length := 3.2 if mode == "idle" else (1.0 if mode == "walk" else 0.62)
		clips[mode] = Rig.make_clip(bones, length, func(b: String, u: float) -> Variant: return pose.call(b, u, mode),
			func(b: String, u: float) -> Variant: return pos.call(b, u, mode), 20)
	Rig.add_clips(ap, clips)


func play(state: String) -> void:
	if state != _state:
		_state = state
		ap.play(state, 0.18)
		ap.speed_scale = 1.0


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if controllable:
		var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if inp.length() > 0.05:
			var b := Basis(Vector3.UP, cam_yaw)
			dir = (b * Vector3(inp.x, 0, inp.y)).normalized()
	var running := Input.is_key_pressed(KEY_SHIFT)
	var sp := SPEED_RUN if running else SPEED_WALK
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.lerp(dir * sp, clampf(delta * 10.0, 0, 1))
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -1.0
	move_and_slide()
	if hv.length() > 0.2:
		var target := atan2(-hv.x, -hv.z)
		face_yaw = lerp_angle(face_yaw, target, clampf(delta * 12.0, 0, 1))
		model.rotation.y = face_yaw
		play("run" if hv.length() > 4.2 else "walk")
		ap.speed_scale = clampf(hv.length() / (SPEED_RUN if hv.length() > 4.2 else SPEED_WALK), 0.6, 1.3)
	else:
		play("idle")
