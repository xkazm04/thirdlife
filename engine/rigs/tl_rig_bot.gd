class_name TLRigBot
extends TLRigNode
## The crew bot (about 1.5 m with its hard hat and beacon at scale 1: the lane-B rig at its x1.45 site scale): 11 bones, lane-B mesh, procedural clips idle, walk, work, carry, weld.
## Params: colors ({"body": key, "hat": key}), beacon (bool: the lamp on the hat glows), look_at (Vector3 world or null).
## Sockets: tool (tip of the right forearm: sparks, a carried part), head (top of the hat: the beacon), carry (in front of the chest).

const BONES: Array = [
	["Hips", "", Vector3(0, 0.30, 0)], ["Spine", "Hips", Vector3(0, 0.36, 0)], ["Head", "Spine", Vector3(0, 0.60, 0)],
	["LeftUpperArm", "Spine", Vector3(-0.215, 0.52, 0)], ["LeftLowerArm", "LeftUpperArm", Vector3(-0.215, 0.36, 0)],
	["RightUpperArm", "Spine", Vector3(0.215, 0.52, 0)], ["RightLowerArm", "RightUpperArm", Vector3(0.215, 0.36, 0)],
	["LeftUpperLeg", "Hips", Vector3(-0.09, 0.28, 0)], ["LeftLowerLeg", "LeftUpperLeg", Vector3(-0.09, 0.15, 0)],
	["RightUpperLeg", "Hips", Vector3(0.09, 0.28, 0)], ["RightLowerLeg", "RightUpperLeg", Vector3(0.09, 0.15, 0)],
]

const BASE_SCALE: float = 1.45   # lane B built the rig 0.8 m tall and showed it at x1.45

var _model: Node3D
var _beacon: MeshInstance3D
var _flash: MeshInstance3D   # weld flash at the tool tip, visible only while `weld` plays


func setup(p: Dictionary) -> void:
	family = &"bot"
	params = p
	name = "Bot"
	_model = Node3D.new()
	_model.name = "Model"
	_model.scale = Vector3.ONE * float(p["scale"]) * BASE_SCALE
	add_child(_model)
	var sk: Skeleton3D = make_skeleton(BONES)
	var s: float = float(p["scale"]) * BASE_SCALE
	_metrics = {"height": 1.06 * s, "radius": 0.24 * s, "eye_height": 0.71 * s, "bones": sk.get_bone_count(), "triangles": 0}
	_rebuild_mesh(sk)
	add_socket("tool", "RightLowerArm", Vector3(0.215, 0.07, 0))
	add_socket("head", "Head", Vector3(0, 1.04, 0))
	add_socket("carry", "Spine", Vector3(0, 0.50, -0.32))
	if not TLStyle.headless():
		_beacon = TLStyleFx.glow("beacon", 0.3)
		_beacon.name = "BeaconGlow"
		socket(&"head").add_child(_beacon)
		_flash = TLStyleFx.glow("spark", 0.2)
		_flash.name = "WeldFlash"
		_flash.visible = false
		socket(&"tool").add_child(_flash)
	add_clip("idle", 3.0, true, _idle)
	add_clip("walk", 0.5, true, _walk)
	add_clip("work", 0.8, true, _work)
	add_clip("carry", 0.5, true, _carry)
	add_clip("weld", 1.6, true, _weld)
	_param_changed("beacon", p["beacon"])
	tick(0)


func _rebuild_mesh(sk: Skeleton3D) -> void:
	var look: Dictionary = params.get("colors", {})
	var body_k: String = String(look.get("body", "bot_body"))
	var hat_k: String = String(look.get("hat", "hat_a"))
	var mk: TLMesh = TLMesh.new(81)
	mk.skinned = true
	var B: Callable = func(n: String) -> void: mk.bone = sk.find_bone(n)
	B.call("Hips")
	mk.box(Vector3(0.22, 0.09, 0.18), "bot_dark", Color.WHITE, 0.02, Vector3(0, 0.295, 0))
	B.call("Spine")
	mk.rbox(Vector3(0.34, 0.26, 0.27), body_k, Color.WHITE, 0.08, Vector3(0, 0.45, 0))
	mk.box(Vector3(0.22, 0.13, 0.03), "bot_white", Color.WHITE, 0.01, Vector3(0, 0.44, -0.135))
	mk.box(Vector3(0.05, 0.05, 0.02), "cyan", Color.WHITE, 0.0, Vector3(-0.05, 0.46, -0.153))
	mk.box(Vector3(0.09, 0.02, 0.02), "bot_dark", Color.WHITE, 0.0, Vector3(0.04, 0.47, -0.153))
	mk.box(Vector3(0.09, 0.02, 0.02), "bot_dark", Color.WHITE, 0.0, Vector3(0.04, 0.43, -0.153))
	mk.box(Vector3(0.24, 0.2, 0.08), "bot_dark", Color.WHITE, 0.02, Vector3(0, 0.46, 0.16))
	mk.box(Vector3(0.06, 0.06, 0.02), "hot", Color.WHITE, 0.0, Vector3(0.06, 0.5, 0.205))
	for sx: float in [-1.0, 1.0]:
		mk.box(Vector3(0.06, 0.1, 0.1), "bot_dark", Color.WHITE, 0.02, Vector3(sx * 0.185, 0.52, 0))
	mk.box(Vector3(0.36, 0.035, 0.29), "bot_dark", Color.WHITE, 0.0, Vector3(0, 0.34, 0))
	B.call("Head")
	mk.rbox(Vector3(0.36, 0.23, 0.28), "bot_white", Color.WHITE, 0.09, Vector3(0, 0.715, 0))
	mk.box(Vector3(0.30, 0.14, 0.04), "bot_dark", Color.WHITE, 0.02, Vector3(0, 0.71, -0.135))
	for sx: float in [-1.0, 1.0]:
		mk.box(Vector3(0.065, 0.075, 0.02), "bot_visor", Color.WHITE, 0.01, Vector3(sx * 0.07, 0.712, -0.158))
		mk.box(Vector3(0.04, 0.12, 0.14), body_k, Color.WHITE, 0.015, Vector3(sx * 0.19, 0.715, 0))
	# hard hat (brim + dome) with a beacon lamp on top: reads from the ridge
	mk.cyl(0.25, 0.03, 10, hat_k, Color(0.92, 0.92, 0.92), -1.0, Vector3(0, 0.825, -0.02))
	mk.cyl(0.21, 0.11, 10, hat_k, Color.WHITE, 0.13, Vector3(0, 0.85, 0))
	mk.box(Vector3(0.05, 0.035, 0.34), hat_k, Color(0.85, 0.85, 0.85), 0.01, Vector3(0, 0.955, 0))
	mk.cyl(0.05, 0.03, 8, "bot_dark", Color.WHITE, -1.0, Vector3(0, 0.96, 0))
	mk.cyl(0.045, 0.07, 8, "beacon", Color.WHITE, 0.03, Vector3(0, 0.985, 0))
	for side: Array in [["Left", -1.0], ["Right", 1.0]]:
		var sx: float = side[1]
		var x: float = sx * 0.215
		B.call(String(side[0]) + "UpperArm")
		mk.capsule(Vector3(x, 0.375, 0), Vector3(x, 0.505, 0), 0.036, "bot_dark", Color.WHITE, 6, 1)
		B.call(String(side[0]) + "LowerArm")
		mk.rbox(Vector3(0.1, 0.15, 0.1), body_k, Color.WHITE, 0.04, Vector3(x, 0.29, 0), 1)
		if sx < 0.0:
			mk.box(Vector3(0.03, 0.07, 0.08), "bot_dark", Color.WHITE, 0.0, Vector3(x - 0.03, 0.185, 0))
			mk.box(Vector3(0.03, 0.07, 0.08), "bot_dark", Color.WHITE, 0.0, Vector3(x + 0.03, 0.185, 0))
		else:
			mk.cyl(0.035, 0.1, 6, "bot_dark", Color.WHITE, -1.0, Vector3(x, 0.125, 0))
			mk.cyl(0.02, 0.05, 6, "hot", Color.WHITE, 0.008, Vector3(x, 0.125, 0), true, true)
			mk.push_at(Vector3(x, 0.125, 0), Vector3(180, 0, 0))
			mk.cyl(0.022, 0.05, 6, "hot", Color.WHITE, 0.006)
			mk.pop()
		var lx: float = sx * 0.09
		B.call(String(side[0]) + "UpperLeg")
		mk.capsule(Vector3(lx, 0.16, 0), Vector3(lx, 0.27, 0), 0.036, "bot_dark", Color.WHITE, 6, 1)
		B.call(String(side[0]) + "LowerLeg")
		mk.rbox(Vector3(0.12, 0.13, 0.17), body_k, Color.WHITE, 0.05, Vector3(lx, 0.07, -0.02), 1)
		mk.box(Vector3(0.125, 0.025, 0.175), "bot_dark", Color.WHITE, 0.0, Vector3(lx, 0.012, -0.02))
	attach_skinned(_model, sk, mk, "bot")
	_metrics["triangles"] = mk.tri_count


func _param_changed(pname: String, value: Variant) -> void:
	match pname:
		"beacon":
			if _beacon != null:
				_beacon.visible = bool(value)
		"colors":
			_rebuild_mesh(_sk)


func _loco_pose() -> Dictionary:
	var v: float = Vector2(_vel.x, _vel.z).length() if _loco_on else 0.0
	return TLRigBiped._mixe(_idle(float(frame) * DT), _walk(_phase * 0.5), smoothstep(0.1, 0.6, v))


func _advance() -> void:
	_phase = fposmod(_phase + clampf(Vector2(_vel.x, _vel.z).length() / 0.9, 0.7, 1.6) / 0.5 * DT, 1.0)


func _post_pose() -> void:
	if _flash != null:
		_flash.visible = String(clip) == "weld" and (frame % 9) < 6
		if _flash.visible:
			_flash.scale = Vector3.ONE * (0.35 + 0.25 * float((frame * 7) % 5) / 4.0)
	if _beacon != null and _beacon.visible:
		_beacon.scale = Vector3.ONE * (0.42 + 0.14 * float((frame / 20) % 2))   # a slow two-step flash, keyed to the frame
	var la: Variant = params.get("look_at", null)
	if la is Vector3:
		var a: Vector2 = look_angles(la, Vector3(0, 0.71 * float(params["scale"]) * BASE_SCALE, 0))
		var bi: int = _sk.find_bone("Head")
		_sk.set_bone_pose_rotation(bi, Quaternion.from_euler(Vector3(deg_to_rad(clampf(a.y, -25.0, 30.0)), deg_to_rad(clampf(a.x, -80.0, 80.0)), 0)))


func _idle(t: float) -> Dictionary:
	var b: float = sin(TAU * t / 3.0)
	var b2: float = sin(TAU * t / 1.5)
	return {
		"_hips": Vector3(0, 0.006 * b2, 0), "Hips": Vector3(0, 0, 0), "Spine": Vector3(-2.0 * b, 0, 0), "Head": Vector3(3.0 * b2, 28.0 * b, 0),
		"LeftUpperArm": Vector3(6.0 * b, 0, -7.0), "LeftLowerArm": Vector3(12.0, 0, 0),
		"RightUpperArm": Vector3(-6.0 * b, 0, 7.0), "RightLowerArm": Vector3(12.0, 0, 0),
		"LeftUpperLeg": Vector3(0, 0, 0), "LeftLowerLeg": Vector3(0, 0, 0), "RightUpperLeg": Vector3(0, 0, 0), "RightLowerLeg": Vector3(0, 0, 0),
	}


func _walk(t: float) -> Dictionary:
	var p: float = TAU * t / 0.5
	var s: float = sin(p)
	var c: float = cos(p)
	return {
		"_hips": Vector3(0, 0.012 * cos(2.0 * p), 0), "Hips": Vector3(-5.0, 0, 5.0 * s), "Spine": Vector3(-5.0, 0, -3.0 * s), "Head": Vector3(6.0, 0, -3.0 * s),
		"LeftUpperArm": Vector3(-32.0 * s, 0, -6.0), "LeftLowerArm": Vector3(20.0, 0, 0),
		"RightUpperArm": Vector3(32.0 * s, 0, 6.0), "RightLowerArm": Vector3(20.0, 0, 0),
		"LeftUpperLeg": Vector3(5.0 + 36.0 * s, 0, 0), "LeftLowerLeg": Vector3(-(8.0 + 30.0 * maxf(0.0, c)), 0, 0),
		"RightUpperLeg": Vector3(5.0 - 36.0 * s, 0, 0), "RightLowerLeg": Vector3(-(8.0 + 30.0 * maxf(0.0, -c)), 0, 0),
	}


## Hammering / fastening: leaning in, the tool arm pumping.
func _work(t: float) -> Dictionary:
	var p: float = TAU * t / 0.8
	return {
		"_hips": Vector3(0, -0.02 + 0.004 * sin(4.0 * p), 0), "Hips": Vector3(-6.0, 0, 0), "Spine": Vector3(-14.0 - 2.0 * sin(p), 6.0, 0),
		"Head": Vector3(-6.0 - 3.0 * sin(2.0 * p), 10.0, 0),
		"LeftUpperArm": Vector3(54.0, -12.0, -6.0), "LeftLowerArm": Vector3(48.0 + 4.0 * sin(p), 0, 0),
		"RightUpperArm": Vector3(72.0 + 14.0 * sin(2.0 * p), 16.0, 0), "RightLowerArm": Vector3(30.0 + 18.0 * sin(2.0 * p + 1.0), 0, 0),
		"LeftUpperLeg": Vector3(14.0, 0, -6.0), "LeftLowerLeg": Vector3(-8.0, 0, 0), "RightUpperLeg": Vector3(14.0, 0, 6.0), "RightLowerLeg": Vector3(-8.0, 0, 0),
	}


## Walking with both arms held out in front under a load (parent the load to the `carry` socket).
func _carry(t: float) -> Dictionary:
	var out: Dictionary = _walk(t)
	var p: float = TAU * t / 0.5
	out.merge({
		"Spine": Vector3(6.0, 0, 0), "Head": Vector3(-4.0, 0, 0), "Hips": Vector3(2.0, 0, 3.0 * sin(p)),
		"LeftUpperArm": Vector3(62.0 + 3.0 * cos(2.0 * p), 0, 8.0), "LeftLowerArm": Vector3(34.0, 0, 0),
		"RightUpperArm": Vector3(62.0 + 3.0 * cos(2.0 * p), 0, -8.0), "RightLowerArm": Vector3(34.0, 0, 0),
	}, true)
	return out


## Welding: crouched and still, the torch arm steady on the joint, the head tracking the seam, a small shake.
func _weld(t: float) -> Dictionary:
	var p: float = TAU * t / 1.6
	var j: float = sin(TAU * t * 7.5) * 0.6
	return {
		"_hips": Vector3(0, -0.05, 0), "Hips": Vector3(-10.0, 0, 0), "Spine": Vector3(-18.0, -8.0 + 3.0 * sin(p), 0), "Head": Vector3(-10.0, -6.0 + 6.0 * sin(p), 0),
		"LeftUpperArm": Vector3(30.0, 0, -18.0), "LeftLowerArm": Vector3(70.0, 0, 0),
		"RightUpperArm": Vector3(86.0 + j + 5.0 * sin(p), 10.0, 0), "RightLowerArm": Vector3(16.0 + j, 0, 0),
		"LeftUpperLeg": Vector3(40.0, 0, -8.0), "LeftLowerLeg": Vector3(-62.0, 0, 0), "RightUpperLeg": Vector3(40.0, 0, 8.0), "RightLowerLeg": Vector3(-62.0, 0, 0),
	}
