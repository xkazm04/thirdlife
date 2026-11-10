class_name KitBot
extends RefCounted
## Kit part: the builder bot (about 0.8 m) on the shared small-bot skeleton. Clips: idle, work, walk.
## Root / Skeleton3D / Mesh, AnimationPlayer, and a "ToolTip" Node3D riding the right forearm (spark emitter mount).

const BONES: Array = [
	["Hips", "", Vector3(0, 0.30, 0)], ["Spine", "Hips", Vector3(0, 0.36, 0)], ["Head", "Spine", Vector3(0, 0.60, 0)],
	["LeftUpperArm", "Spine", Vector3(-0.215, 0.52, 0)], ["LeftLowerArm", "LeftUpperArm", Vector3(-0.215, 0.36, 0)],
	["RightUpperArm", "Spine", Vector3(0.215, 0.52, 0)], ["RightLowerArm", "RightUpperArm", Vector3(0.215, 0.36, 0)],
	["LeftUpperLeg", "Hips", Vector3(-0.09, 0.28, 0)], ["LeftLowerLeg", "LeftUpperLeg", Vector3(-0.09, 0.15, 0)],
	["RightUpperLeg", "Hips", Vector3(0.09, 0.28, 0)], ["RightLowerLeg", "RightUpperLeg", Vector3(0.09, 0.15, 0)],
]


## look: {"body": palette key, "hat": palette key}: colourways are data, the rig and clips are shared.
static func build(look: Dictionary = {}) -> Node3D:
	var body_k: String = String(look.get("body", "bot_body"))
	var hat_k: String = String(look.get("hat", "hat_a"))
	var sk: Skeleton3D = Rig.skeleton(BONES)
	var mk: MK = MK.new(81)
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
	var clips: Dictionary = {"idle": Rig.clip(sk, 3.0, _idle), "work": Rig.clip(sk, 0.8, _work), "walk": Rig.clip(sk, 0.5, _walk)}
	var root: Node3D = Rig.assemble("Bot", sk, mk, clips)
	var tip: Node3D = Node3D.new()
	tip.name = "ToolTip"
	tip.position = Vector3(0, -0.29, 0)
	var ba: BoneAttachment3D = Rig.attach(sk, "RightLowerArm", tip)
	ba.name = "ToolMount"
	var lamp: Node3D = Node3D.new()
	lamp.name = "Beacon"
	lamp.position = Vector3(0, 0.44, 0)
	var hb: BoneAttachment3D = Rig.attach(sk, "Head", lamp)
	hb.name = "HeadMount"
	root.set_meta("tris", mk.tri_count)
	return root


static func _idle(t: float) -> Dictionary:
	var b: float = sin(TAU * t / 3.0)
	var b2: float = sin(TAU * t / 1.5)
	return {
		"_hips": Vector3(0, 0.006 * b2, 0), "Hips": Vector3(0, 0, 0), "Spine": Vector3(2.0 * b, 0, 0), "Head": Vector3(3.0 * b2, 28.0 * b, 0),
		"LeftUpperArm": Vector3(6.0 * b, 0, -7.0), "LeftLowerArm": Vector3(12.0, 0, 0),
		"RightUpperArm": Vector3(-6.0 * b, 0, 7.0), "RightLowerArm": Vector3(12.0, 0, 0),
		"LeftUpperLeg": Vector3(0, 0, 0), "LeftLowerLeg": Vector3(0, 0, 0), "RightUpperLeg": Vector3(0, 0, 0), "RightLowerLeg": Vector3(0, 0, 0),
	}


static func _work(t: float) -> Dictionary:
	var p: float = TAU * t / 0.8
	return {
		"_hips": Vector3(0, -0.02 + 0.004 * sin(4.0 * p), 0), "Hips": Vector3(6.0, 0, 0), "Spine": Vector3(16.0 + 2.0 * sin(p), 6.0, 0),
		"Head": Vector3(10.0 + 3.0 * sin(2.0 * p), 10.0, 0),
		"LeftUpperArm": Vector3(42.0, -12.0, -6.0), "LeftLowerArm": Vector3(48.0 + 4.0 * sin(p), 0, 0),
		"RightUpperArm": Vector3(58.0 + 7.0 * sin(2.0 * p), 16.0, 0), "RightLowerArm": Vector3(30.0 + 9.0 * sin(2.0 * p + 1.0), 0, 0),
		"LeftUpperLeg": Vector3(-14.0, 0, -6.0), "LeftLowerLeg": Vector3(8.0, 0, 0), "RightUpperLeg": Vector3(-14.0, 0, 6.0), "RightLowerLeg": Vector3(8.0, 0, 0),
	}


static func _walk(t: float) -> Dictionary:
	var p: float = TAU * t / 0.5
	var s: float = sin(p)
	var c: float = cos(p)
	return {
		"_hips": Vector3(0, 0.012 * cos(2.0 * p), 0), "Hips": Vector3(5.0, 0, 5.0 * s), "Spine": Vector3(5.0, 0, -3.0 * s), "Head": Vector3(-4.0, 0, -3.0 * s),
		"LeftUpperArm": Vector3(-32.0 * s, 0, -6.0), "LeftLowerArm": Vector3(20.0, 0, 0),
		"RightUpperArm": Vector3(32.0 * s, 0, 6.0), "RightLowerArm": Vector3(20.0, 0, 0),
		"LeftUpperLeg": Vector3(36.0 * s, 0, 0), "LeftLowerLeg": Vector3(-(8.0 + 30.0 * maxf(0.0, c)), 0, 0),
		"RightUpperLeg": Vector3(-36.0 * s, 0, 0), "RightLowerLeg": Vector3(-(8.0 + 30.0 * maxf(0.0, -c)), 0, 0),
	}
