class_name KitBiped
extends RefCounted
## Kit part: the standard biped. Godot humanoid bone names, identity rest rotations, rigid-weighted blocky parts.
## Faces -Z; anatomical left is -X. Clips: idle, walk, run (in place; the controller moves the node).
## Params: look = palette keys per part (so NPCs can reuse the rig with other colours), tablet = add the holo tablet.

const BONES: Array = [
	["Hips", "", Vector3(0, 0.98, 0)], ["Spine", "Hips", Vector3(0, 1.10, 0)], ["Chest", "Spine", Vector3(0, 1.26, 0)],
	["Neck", "Chest", Vector3(0, 1.50, 0)], ["Head", "Neck", Vector3(0, 1.56, 0)],
	["LeftShoulder", "Chest", Vector3(-0.2, 1.47, 0)], ["RightShoulder", "Chest", Vector3(0.2, 1.47, 0)],
	["Backpack", "Chest", Vector3(0, 1.5, 0.15)], ["Hair", "Head", Vector3(0, 1.9, 0.02)],
	["LeftEye", "Head", Vector3(-0.088, 1.765, -0.18)], ["RightEye", "Head", Vector3(0.088, 1.765, -0.18)],
	["Brows", "Head", Vector3(0, 1.826, -0.18)], ["MouthCorners", "Head", Vector3(0, 1.64, -0.18)], ["Glints", "Head", Vector3(0, 1.765, -0.18)],
	["LeftUpperArm", "LeftShoulder", Vector3(-0.29, 1.44, 0)], ["LeftLowerArm", "LeftUpperArm", Vector3(-0.29, 1.17, 0)], ["LeftHand", "LeftLowerArm", Vector3(-0.29, 0.92, 0)],
	["RightUpperArm", "RightShoulder", Vector3(0.29, 1.44, 0)], ["RightLowerArm", "RightUpperArm", Vector3(0.29, 1.17, 0)], ["RightHand", "RightLowerArm", Vector3(0.29, 0.92, 0)],
	["LeftUpperLeg", "Hips", Vector3(-0.11, 0.94, 0)], ["LeftLowerLeg", "LeftUpperLeg", Vector3(-0.11, 0.52, 0)], ["LeftFoot", "LeftLowerLeg", Vector3(-0.11, 0.10, 0)], ["LeftToes", "LeftFoot", Vector3(-0.11, 0.03, -0.12)],
	["RightUpperLeg", "Hips", Vector3(0.11, 0.94, 0)], ["RightLowerLeg", "RightUpperLeg", Vector3(0.11, 0.52, 0)], ["RightFoot", "RightLowerLeg", Vector3(0.11, 0.10, 0)], ["RightToes", "RightFoot", Vector3(0.11, 0.03, -0.12)],
]
const HOLD_DEG: float = 105.0   # total forward rotation of the tablet forearm in the hold pose


static func build(tablet: bool = true, look: Dictionary = {}) -> Node3D:
	var L: Dictionary = {"skin": "skin", "hair": "hair", "top": "jacket", "trim": "jacket_trim", "legs": "pants", "boots": "boots", "pack": "pack", "strap": "strap"}
	L.merge(look, true)
	var sk: Skeleton3D = Rig.skeleton(BONES)
	var mk: MK = MK.new(71)
	mk.skinned = true
	var B: Callable = func(n: String) -> void: mk.bone = sk.find_bone(n)
	# rounded toy forms (MK.rbox / MK.capsule): smooth normals, so the ink pass draws silhouettes, not facet creases
	B.call("Hips")
	mk.rbox(Vector3(0.40, 0.24, 0.26), L["legs"], Color.WHITE, 0.09, Vector3(0, 0.95, 0))
	mk.rbox(Vector3(0.43, 0.07, 0.28), L["strap"], Color.WHITE, 0.03, Vector3(0, 1.06, 0), 1)
	mk.box(Vector3(0.08, 0.08, 0.03), "yellow", Color.WHITE, 0.01, Vector3(0, 1.06, -0.145))
	B.call("Spine")
	mk.rbox(Vector3(0.41, 0.20, 0.265), L["top"], Color(0.94, 0.94, 0.94), 0.08, Vector3(0, 1.17, 0))
	B.call("Chest")
	mk.rbox(Vector3(0.48, 0.32, 0.30), L["top"], Color.WHITE, 0.12, Vector3(0, 1.38, 0))
	mk.rbox(Vector3(0.33, 0.11, 0.33), L["trim"], Color.WHITE, 0.05, Vector3(0, 1.52, 0), 1)
	mk.box(Vector3(0.02, 0.34, 0.012), L["trim"], Color(0.78, 0.78, 0.78), 0.0, Vector3(0, 1.33, -0.153))
	for sx: float in [-1.0, 1.0]:
		mk.box(Vector3(0.07, 0.42, 0.02), L["strap"], Color.WHITE, 0.0, Vector3(sx * 0.14, 1.33, -0.156))
	# backpack with bedroll, pocket and the small glowing light (own bone: it lags a little)
	B.call("Backpack")
	mk.rbox(Vector3(0.38, 0.46, 0.20), L["pack"], Color.WHITE, 0.08, Vector3(0, 1.30, 0.24))
	mk.rbox(Vector3(0.40, 0.13, 0.22), L["pack"], Color(0.8, 0.8, 0.8), 0.05, Vector3(0, 1.50, 0.24), 1)
	mk.rbox(Vector3(0.24, 0.16, 0.07), L["pack"], Color(0.86, 0.86, 0.86), 0.03, Vector3(0, 1.20, 0.36), 1)
	mk.box(Vector3(0.05, 0.40, 0.02), L["strap"], Color.WHITE, 0.0, Vector3(-0.1, 1.32, 0.345))
	mk.box(Vector3(0.05, 0.40, 0.02), L["strap"], Color.WHITE, 0.0, Vector3(0.1, 1.32, 0.345))
	mk.capsule(Vector3(-0.2, 1.63, 0.23), Vector3(0.2, 1.63, 0.23), 0.085, L["trim"], Color(0.9, 0.9, 0.9), 8, 2)
	mk.box(Vector3(0.11, 0.11, 0.05), "cyan", Color.WHITE, 0.02, Vector3(0, 1.40, 0.35))
	mk.box(Vector3(0.15, 0.15, 0.03), L["strap"], Color.WHITE, 0.02, Vector3(0, 1.40, 0.34))
	B.call("Neck")
	mk.capsule(Vector3(0, 1.49, 0), Vector3(0, 1.58, 0), 0.062, L["skin"], Color(0.9, 0.9, 0.9), 8, 1)
	B.call("Head")
	mk.rbox(Vector3(0.37, 0.34, 0.35), L["skin"], Color.WHITE, 0.14, Vector3(0, 1.75, 0), 3)
	# hair: a few large calm shapes on their own bone (cap, back, swept fringe, quiff)
	B.call("Hair")
	mk.rbox(Vector3(0.41, 0.17, 0.39), L["hair"], Color.WHITE, 0.085, Vector3(0, 1.895, 0.025))
	mk.rbox(Vector3(0.40, 0.25, 0.14), L["hair"], Color(0.9, 0.9, 0.9), 0.065, Vector3(0, 1.80, 0.16))
	mk.push_at(Vector3(0.02, 1.885, -0.165), Vector3(-14, 0, -7))
	mk.rbox(Vector3(0.36, 0.09, 0.11), L["hair"], Color(1.1, 1.08, 1.0), 0.045)
	mk.pop()
	mk.push_at(Vector3(0.05, 2.0, -0.07), Vector3(-28, 0, -10))
	mk.rbox(Vector3(0.24, 0.13, 0.22), L["hair"], Color(1.12, 1.1, 1.0), 0.06)
	mk.pop()
	mk.push_at(Vector3(-0.06, 1.99, 0.1), Vector3(22, 0, 12))
	mk.rbox(Vector3(0.2, 0.1, 0.18), L["hair"], Color(1.0, 1.0, 1.0), 0.05)
	mk.pop()
	# face: ears, cheeks, nose and the mouth bar on the head; eyes, brows and mouth corners on their own bones (set_face)
	B.call("Head")
	# pass 4: every face part is laid ON the head's curved surface (the head is a box inflated by a 0.14 m sphere, so only
	# a 9 x 6 cm patch of the front is flat): discs and capsules are turned to the local surface normal, mirrored exactly.
	for sx: float in [-1.0, 1.0]:
		mk.rbox(Vector3(0.05, 0.10, 0.09), L["skin"], Color(0.9, 0.9, 0.9), 0.025, Vector3(sx * 0.19, 1.74, 0.02), 1)
		mk.push_at(Vector3(sx * 0.1235, 1.6895, -0.1505), Vector3(-102, -sx * 34.0, 0))   # cheek: a flat round blush disc
		mk.cyl(0.03, 0.005, 14, L["skin"], Color(1.13, 0.80, 0.80))
		mk.pop()
	mk.rbox(Vector3(0.055, 0.06, 0.05), L["skin"], Color(0.88, 0.88, 0.88), 0.025, Vector3(0, 1.715, -0.185), 1)
	for side: Array in [["Left", -1.0], ["Right", 1.0]]:
		var ex: float = float(side[1]) * 0.0808
		B.call(String(side[0]) + "Eye")
		mk.push_at(Vector3(ex, 1.765, -0.1735), Vector3(-90, -float(side[1]) * 14.5, 0))
		mk.push(Transform3D(Basis.from_scale(Vector3(0.9, 1.0, 1.1)), Vector3.ZERO))
		mk.cyl(0.04, 0.012, 16, "black")
		mk.pop()
		mk.pop()
	B.call("Glints")   # eye highlights on their own bone, so a blink can remove them (pass 3 left a white sliver)
	for sx: float in [-1.0, 1.0]:
		mk.push_at(Vector3(sx * 0.0808 + sx * 0.013 - sx * 0.002, 1.781, -0.1735 - 0.0075), Vector3(-90, -sx * 14.5, 0))
		mk.cyl(0.0115, 0.004, 10, "white")
		mk.pop()
	B.call("Brows")
	for sx: float in [-1.0, 1.0]:
		mk.capsule(Vector3(sx * 0.047, 1.829, -0.170), Vector3(sx * 0.126, 1.823, -0.1445), 0.0125, L["hair"], Color.WHITE, 8, 2)
	B.call("MouthCorners")   # the mouth is one shape: a half-ellipse smile with a row of teeth, tilted to the chin's slope
	mk.push_at(Vector3(0, 1.6485, -0.1590), Vector3(-30, 0, 0))
	var mp: Array = []
	for k: int in 11:
		var a: float = PI * float(k) / 10.0
		for z: float in [-0.006, 0.006]:
			mp.append(Vector3(cos(a) * 0.052, 0.016 - sin(a) * 0.036, z))
	mk.hull(mp, "roof", Color(0.62, 0.55, 0.55))
	mk.box(Vector3(0.076, 0.010, 0.004), "white", Color.WHITE, 0.0, Vector3(0, 0.0095, -0.0065))
	mk.pop()
	# arms (mirrored), legs
	for side: Array in [["Left", -1.0], ["Right", 1.0]]:
		var sx: float = side[1]
		var x: float = sx * 0.29
		B.call(String(side[0]) + "Shoulder")
		mk.rbox(Vector3(0.19, 0.15, 0.21), L["top"], Color(0.92, 0.92, 0.92), 0.07, Vector3(x, 1.47, 0))
		B.call(String(side[0]) + "UpperArm")
		mk.capsule(Vector3(x, 1.41, 0), Vector3(x, 1.20, 0), 0.084, L["top"], Color.WHITE, 8, 2, 0.078)
		mk.cyl(0.088, 0.06, 8, L["trim"], Color.WHITE, -1.0, Vector3(x, 1.235, 0))
		B.call(String(side[0]) + "LowerArm")
		mk.capsule(Vector3(x, 1.14, 0), Vector3(x, 0.97, 0), 0.076, L["top"], Color(0.95, 0.95, 0.95), 8, 2, 0.068)
		mk.cyl(0.08, 0.05, 8, L["trim"], Color.WHITE, -1.0, Vector3(x, 0.925, 0))
		B.call(String(side[0]) + "Hand")
		mk.rbox(Vector3(0.115, 0.15, 0.125), L["boots"], Color(0.8, 0.8, 0.8), 0.055, Vector3(x, 0.845, -0.005))
		mk.capsule(Vector3(x - sx * 0.045, 0.885, -0.04), Vector3(x - sx * 0.085, 0.825, -0.065), 0.026, L["boots"], Color(0.88, 0.88, 0.88), 6, 1)
		var lx: float = sx * 0.11
		B.call(String(side[0]) + "UpperLeg")
		mk.rbox(Vector3(0.19, 0.46, 0.22), L["legs"], Color.WHITE, 0.085, Vector3(lx, 0.74, 0))
		B.call(String(side[0]) + "LowerLeg")
		mk.rbox(Vector3(0.165, 0.32, 0.185), L["legs"], Color(0.92, 0.92, 0.92), 0.07, Vector3(lx, 0.40, 0))
		mk.rbox(Vector3(0.20, 0.22, 0.22), L["boots"], Color.WHITE, 0.07, Vector3(lx, 0.21, 0))
		mk.rbox(Vector3(0.212, 0.05, 0.232), L["trim"], Color(0.85, 0.85, 0.85), 0.02, Vector3(lx, 0.31, 0), 1)
		B.call(String(side[0]) + "Foot")
		mk.rbox(Vector3(0.20, 0.12, 0.21), L["boots"], Color.WHITE, 0.05, Vector3(lx, 0.078, 0.02))
		mk.box(Vector3(0.20, 0.03, 0.21), "black", Color.WHITE, 0.0, Vector3(lx, 0.015, 0.02))
		B.call(String(side[0]) + "Toes")
		mk.rbox(Vector3(0.20, 0.10, 0.17), L["boots"], Color(0.93, 0.93, 0.93), 0.05, Vector3(lx, 0.068, -0.15))
		mk.box(Vector3(0.20, 0.03, 0.17), "black", Color.WHITE, 0.0, Vector3(lx, 0.015, -0.15))
	if tablet:
		# built in the HOLD frame of the left hand (the frame the hand has after the forearm swung HOLD_DEG forward)
		B.call("LeftHand")
		var hm: ShaderMaterial = ShaderMaterial.new()
		hm.shader = load("res://shaders/holo.gdshader")
		Style.push("holo", hm)
		hm.set_shader_parameter("dissolve", 0.0)
		hm.set_shader_parameter("grid_u", 7.0)
		hm.set_shader_parameter("segs_v", 5.0)
		hm.set_shader_parameter("alpha", 0.55)
		hm.set_shader_parameter("edge_k", 0.9)
		mk.mats["tablet_holo"] = hm
		mk.push(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-HOLD_DEG)), Vector3(-0.29, 0.86, 0)))
		mk.push(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(42.0)) * Basis(Vector3.UP, deg_to_rad(-8.0)), Vector3(0.13, 0.12, -0.03)))
		var tw: float = 0.21
		var th: float = 0.15
		# open frame (four rim bars, no back plate) so the hologram screen reads from both sides
		for sz: float in [-1.0, 1.0]:
			mk.box(Vector3(tw * 2.0 + 0.05, 0.018, 0.025), "bot_dark", Color.WHITE, 0.004, Vector3(0, 0, sz * (th + 0.012)))
			mk.box(Vector3(0.025, 0.018, th * 2.0 + 0.05), "bot_dark", Color.WHITE, 0.004, Vector3(sz * (tw + 0.012), 0, 0))
		var y: float = 0.004
		mk.tri(Vector3(-tw, y, th), Vector3(tw, y, th), Vector3(tw, y, -th), "tablet_holo", Color.WHITE, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1))
		mk.tri(Vector3(-tw, y, th), Vector3(tw, y, -th), Vector3(-tw, y, -th), "tablet_holo", Color.WHITE, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1))
		# a tiny projected arena blueprint floating above the screen
		for i: int in 4:
			var xx: float = -0.12 + 0.08 * i
			mk.box(Vector3(0.012, 0.012, 0.16), "cyan", Color.WHITE, 0.0, Vector3(xx, 0.035 + 0.045 * sin(float(i + 1) * 0.8), 0))
		mk.box(Vector3(0.3, 0.008, 0.008), "cyan", Color.WHITE, 0.0, Vector3(0, 0.03, 0.08))
		mk.box(Vector3(0.3, 0.008, 0.008), "cyan", Color.WHITE, 0.0, Vector3(0, 0.03, -0.08))
		mk.pop()
		mk.pop()
	var clips: Dictionary = {"idle": Rig.clip(sk, 4.0, _idle), "walk": Rig.clip(sk, 0.9, _walk), "run": Rig.clip(sk, 0.6, _run)}
	var root: Node3D = Rig.assemble("Avatar", sk, mk, clips)
	root.set_meta("tris", mk.tri_count)
	return root


## The face is a parameter, not a clip: mood 0 = focused (flat mouth, low brows) .. 1 = happy (smile, raised brows),
## blink 0 = open .. 1 = closed. The face bones are not touched by the body clips, so this can be set every frame.
static func set_face(root: Node3D, mood: float, blink: float) -> void:
	var sk: Skeleton3D = root.get_node("Skeleton3D")
	var bl: float = clampf(blink, 0.0, 1.0)
	var open: float = lerpf(1.0, 0.07, bl) * lerpf(0.8, 1.0, mood)   # closed = a drawn lid line, nothing white left
	for n: String in ["LeftEye", "RightEye"]:
		sk.set_bone_pose_scale(sk.find_bone(n), Vector3(lerpf(1.0, 1.12, bl), open, 1.0))
	sk.set_bone_pose_scale(sk.find_bone("Glints"), Vector3(1.0, clampf(1.0 - bl / 0.45, 0.0, 1.0) * lerpf(0.8, 1.0, mood), 1.0))
	var bi: int = sk.find_bone("Brows")
	sk.set_bone_pose_position(bi, sk.get_bone_rest(bi).origin + Vector3(0, lerpf(-0.02, 0.006, mood), 0))
	var mi: int = sk.find_bone("MouthCorners")
	sk.set_bone_pose_position(mi, sk.get_bone_rest(mi).origin + Vector3(0, lerpf(-0.012, 0.004, mood), 0))
	sk.set_bone_pose_scale(mi, Vector3(lerpf(0.6, 1.0, mood), lerpf(0.32, 1.0, mood), 1.0))


static func _idle(t: float) -> Dictionary:
	var b: float = sin(TAU * t / 4.0)
	var b2: float = sin(TAU * t / 2.0 + 0.6)
	return {
		"_hips": Vector3(0, -0.012 + 0.006 * b, 0), "Hips": Vector3(0, 0, 0),
		"Backpack": Vector3(1.2 * sin(TAU * t / 4.0 - 0.9), 0, 0), "Hair": Vector3(1.5 * sin(TAU * t / 2.0 - 0.4), 0, 1.0 * b),
		"Spine": Vector3(2.0 + 1.0 * b, 0, 0), "Chest": Vector3(3.0 + 1.5 * b, 3.0, 0), "Neck": Vector3(8.0, 5.0, 0),
		"Head": Vector3(12.0 + 2.0 * b2, 9.0 + 5.0 * b, 0),
		"LeftUpperArm": Vector3(28.0 + 1.5 * b, -24.0, 0), "LeftLowerArm": Vector3(77.0 - 1.5 * b, 0, 0), "LeftHand": Vector3(0, 0, 0),
		"RightUpperArm": Vector3(34.0 + 4.0 * b2, 30.0, 8.0), "RightLowerArm": Vector3(62.0 + 8.0 * b2, 0, 0), "RightHand": Vector3(10.0 * b2, 0, 0),
		"LeftUpperLeg": Vector3(0, 0, -4.0), "LeftLowerLeg": Vector3(0, 0, 0), "LeftFoot": Vector3(0, 6.0, 4.0),
		"RightUpperLeg": Vector3(3.0, 0, 4.0), "RightLowerLeg": Vector3(-5.0, 0, 0), "RightFoot": Vector3(2.0, -8.0, -4.0),
	}


static func _walk(t: float) -> Dictionary:
	var p: float = TAU * t / 0.9
	var s: float = sin(p)
	var c: float = cos(p)
	var kl: float = -(8.0 + 44.0 * maxf(0.0, c))
	var kr: float = -(8.0 + 44.0 * maxf(0.0, -c))
	return {
		"_hips": Vector3(0, -0.025 + 0.022 * cos(2.0 * p), 0), "Hips": Vector3(4.0, 6.0 * s, 0),
		"Backpack": Vector3(3.5 * cos(2.0 * p - 1.0), 0, 2.0 * sin(p - 0.6)), "Hair": Vector3(4.0 * cos(2.0 * p - 1.4), 0, 0),
		"LeftToes": Vector3(22.0 * maxf(0.0, -s), 0, 0), "RightToes": Vector3(22.0 * maxf(0.0, s), 0, 0),
		"Spine": Vector3(2.0, -5.0 * s, 0), "Chest": Vector3(2.0, -6.0 * s, 0), "Neck": Vector3(2.0, 4.0 * s, 0), "Head": Vector3(4.0, 3.0 * s, 0),
		"LeftUpperArm": Vector3(26.0 - 4.0 * s, -22.0, 0), "LeftLowerArm": Vector3(79.0, 0, 0), "LeftHand": Vector3(0, 0, 0),
		"RightUpperArm": Vector3(28.0 * s, 0, 6.0), "RightLowerArm": Vector3(16.0 + 14.0 * maxf(0.0, s), 0, 0), "RightHand": Vector3(0, 0, 0),
		"LeftUpperLeg": Vector3(30.0 * s, 0, 0), "LeftLowerLeg": Vector3(kl, 0, 0), "LeftFoot": Vector3(-(30.0 * s + kl) * 0.55, 0, 0),
		"RightUpperLeg": Vector3(-30.0 * s, 0, 0), "RightLowerLeg": Vector3(kr, 0, 0), "RightFoot": Vector3(-(-30.0 * s + kr) * 0.55, 0, 0),
	}


static func _run(t: float) -> Dictionary:
	var p: float = TAU * t / 0.6
	var s: float = sin(p)
	var c: float = cos(p)
	var kl: float = -(22.0 + 72.0 * maxf(0.0, c))
	var kr: float = -(22.0 + 72.0 * maxf(0.0, -c))
	return {
		"_hips": Vector3(0, -0.05 + 0.05 * cos(2.0 * p), 0), "Hips": Vector3(13.0, 9.0 * s, 0),
		"Backpack": Vector3(7.0 * cos(2.0 * p - 1.0), 0, 3.0 * sin(p - 0.6)), "Hair": Vector3(9.0 * cos(2.0 * p - 1.4), 0, 0),
		"LeftToes": Vector3(30.0 * maxf(0.0, -s), 0, 0), "RightToes": Vector3(30.0 * maxf(0.0, s), 0, 0),
		"Spine": Vector3(4.0, -7.0 * s, 0), "Chest": Vector3(4.0, -9.0 * s, 0), "Neck": Vector3(-6.0, 6.0 * s, 0), "Head": Vector3(-6.0, 4.0 * s, 0),
		"LeftUpperArm": Vector3(8.0 - 26.0 * s, -16.0, 0), "LeftLowerArm": Vector3(97.0, 0, 0), "LeftHand": Vector3(0, 0, 0),
		"RightUpperArm": Vector3(-8.0 + 48.0 * s, 0, 8.0), "RightLowerArm": Vector3(78.0, 0, 0), "RightHand": Vector3(0, 0, 0),
		"LeftUpperLeg": Vector3(8.0 + 46.0 * s, 0, 0), "LeftLowerLeg": Vector3(kl, 0, 0), "LeftFoot": Vector3(-(46.0 * s + kl) * 0.4, 0, 0),
		"RightUpperLeg": Vector3(8.0 - 46.0 * s, 0, 0), "RightLowerLeg": Vector3(kr, 0, 0), "RightFoot": Vector3(-(-46.0 * s + kr) * 0.4, 0, 0),
	}
