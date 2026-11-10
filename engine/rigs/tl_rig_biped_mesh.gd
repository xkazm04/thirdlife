class_name TLRigBipedMesh
extends RefCounted
## The biped's skinned mesh (ported from spike/lab/b/src/kit_biped.gd, pass 4): rounded toy forms, rigid weights,
## face parts on their own bones. Godot humanoid bone names, identity rest rotations. Faces -Z; left is -X.

const BONES: Array = [
	["Hips", "", Vector3(0, 0.98, 0)], ["Spine", "Hips", Vector3(0, 1.10, 0)], ["Chest", "Spine", Vector3(0, 1.26, 0)], ["UpperChest", "Chest", Vector3(0, 1.40, 0)],
	["Neck", "UpperChest", Vector3(0, 1.50, 0)], ["Head", "Neck", Vector3(0, 1.56, 0)],
	["LeftShoulder", "UpperChest", Vector3(-0.2, 1.47, 0)], ["RightShoulder", "UpperChest", Vector3(0.2, 1.47, 0)],
	["Backpack", "UpperChest", Vector3(0, 1.5, 0.15)], ["Hair", "Head", Vector3(0, 1.9, 0.02)],
	["LeftEye", "Head", Vector3(-0.088, 1.765, -0.18)], ["RightEye", "Head", Vector3(0.088, 1.765, -0.18)],
	["Brows", "Head", Vector3(0, 1.826, -0.18)], ["MouthCorners", "Head", Vector3(0, 1.64, -0.18)], ["Glints", "Head", Vector3(0, 1.765, -0.18)],
	["LeftUpperArm", "LeftShoulder", Vector3(-0.29, 1.44, 0)], ["LeftLowerArm", "LeftUpperArm", Vector3(-0.29, 1.17, 0)], ["LeftHand", "LeftLowerArm", Vector3(-0.29, 0.92, 0)],
	["RightUpperArm", "RightShoulder", Vector3(0.29, 1.44, 0)], ["RightLowerArm", "RightUpperArm", Vector3(0.29, 1.17, 0)], ["RightHand", "RightLowerArm", Vector3(0.29, 0.92, 0)],
	["LeftUpperLeg", "Hips", Vector3(-0.11, 0.94, 0)], ["LeftLowerLeg", "LeftUpperLeg", Vector3(-0.11, 0.52, 0)], ["LeftFoot", "LeftLowerLeg", Vector3(-0.11, 0.10, 0)], ["LeftToes", "LeftFoot", Vector3(-0.11, 0.03, -0.12)],
	["RightUpperLeg", "Hips", Vector3(0.11, 0.94, 0)], ["RightLowerLeg", "RightUpperLeg", Vector3(0.11, 0.52, 0)], ["RightFoot", "RightLowerLeg", Vector3(0.11, 0.10, 0)], ["RightToes", "RightFoot", Vector3(0.11, 0.03, -0.12)],
]
const LOOK: Dictionary = {"skin": "skin", "hair": "hair", "top": "jacket", "trim": "jacket_trim", "legs": "pants", "boots": "boots", "pack": "pack", "strap": "strap"}


## L = palette keys per part (LOOK overlaid with the rig's `colors`); pack = with the backpack.
static func build_mesh(sk: Skeleton3D, L: Dictionary, pack: bool) -> TLMesh:
	var mk: TLMesh = TLMesh.new(71)
	mk.skinned = true
	var B: Callable = func(n: String) -> void: mk.bone = sk.find_bone(n)
	# rounded toy forms (TLMesh.rbox / TLMesh.capsule): smooth normals, so the ink pass draws silhouettes, not facet creases
	B.call("Hips")
	mk.rbox(Vector3(0.40, 0.24, 0.26), L["legs"], Color.WHITE, 0.09, Vector3(0, 0.95, 0))
	mk.rbox(Vector3(0.43, 0.07, 0.28), L["strap"], Color.WHITE, 0.03, Vector3(0, 1.06, 0), 1)
	mk.box(Vector3(0.08, 0.08, 0.03), "yellow", Color.WHITE, 0.01, Vector3(0, 1.06, -0.145))
	B.call("Spine")
	mk.rbox(Vector3(0.41, 0.20, 0.265), L["top"], Color(0.94, 0.94, 0.94), 0.08, Vector3(0, 1.17, 0))
	B.call("Chest")
	mk.rbox(Vector3(0.48, 0.32, 0.30), L["top"], Color.WHITE, 0.12, Vector3(0, 1.38, 0))
	B.call("UpperChest")
	mk.rbox(Vector3(0.33, 0.11, 0.33), L["trim"], Color.WHITE, 0.05, Vector3(0, 1.52, 0), 1)
	B.call("Chest")
	mk.box(Vector3(0.02, 0.34, 0.012), L["trim"], Color(0.78, 0.78, 0.78), 0.0, Vector3(0, 1.33, -0.153))
	for sx: float in [-1.0, 1.0]:
		mk.box(Vector3(0.07, 0.42, 0.02), L["strap"], Color.WHITE, 0.0, Vector3(sx * 0.14, 1.33, -0.156))
	# backpack with bedroll, pocket and the small glowing light (own bone: it lags a little)
	if pack:
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
	return mk
