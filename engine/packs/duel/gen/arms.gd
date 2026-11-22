extends RefCounted
## The duellists' arms: a sword, a rapier, a mace, a round shield, dual blades; and the rivals' gear (round 9: a helm and
## pauldrons for the Wall, a plumed hat and a cape for the Duelist, a hood with ribbons for the Dancer). Kit-style meshes (TLMesh, palette keys,
## the style's one toon material), visual only, parented to the rig's hand sockets. No kit part is a weapon; this is
## the pack's one generator of geometry (lint counts it in kit_parts_added). In a hand socket -Y runs along the grip
## out of the fist (the rig's hammer convention), so a blade is built along -Y.

const GRIP := Vector3(90.0, -25.0, 0.0)          ## measured on the cel figure's guard (a still with six test rods, 21 Nov):
                                               ## the socket's -Z points at the foe, +X up; the blade (built along -Y) goes forward, a little up


static func generate(ctx) -> void:
	ctx.root.set_meta(&"duel_arms", "gen/arms.gd")


## Builds `kind` under the socket; returns the node (null when the rig has no such socket).
static func attach(rig, kind: String) -> Node3D:
	if rig == null:
		return null
	var sock_name: StringName = &"hand_l" if kind in ["shield", "blade_l"] else &"hand_r"
	if kind in ["helm", "hat", "hood"]:
		sock_name = &"head"                          # the rival reads by silhouette (round 9): head socket (its Y points into the head)
	elif kind in ["pauldrons", "cape"]:
		sock_name = &"back"                          # between the shoulder blades, +Z behind him
	var sock: Node3D = rig.socket(sock_name)
	if sock == null:
		return null
	var mk := TLMesh.new(11)
	var node := Node3D.new()
	node.name = "Arm_" + kind
	match kind:
		"helm":                                      # the Wall: a bucket helm over the head, a T visor slit, a ridge (round 10: smaller)
			mk.push_at(Vector3.ZERO, Vector3(-90, 0, 0))     # the head socket: +X his right, +Y back, +Z down (probe, round 9): build Y up, -Z face
			mk.rbox(Vector3(0.66, 0.52, 0.6), "steel_dark", Color.WHITE, 0.08, Vector3(0, -0.27, -0.08))   # wide enough to hide the hair at its sides
			mk.box(Vector3(0.4, 0.045, 0.04), "black", Color.WHITE, 0.0, Vector3(0, -0.29, -0.37))
			mk.box(Vector3(0.05, 0.18, 0.04), "black", Color.WHITE, 0.0, Vector3(0, -0.39, -0.37))
			mk.box(Vector3(0.06, 0.07, 0.56), "steel_light", Color.WHITE, 0.02, Vector3(0, 0.0, -0.08))
			mk.pop()
		"pauldrons":
			for sx: float in [-1.0, 1.0]:
				mk.rbox(Vector3(0.34, 0.16, 0.38), "steel_dark", Color.WHITE, 0.06, Vector3(0.36 * sx, 0.02, -0.06))
				mk.rbox(Vector3(0.3, 0.06, 0.34), "steel_light", Color.WHITE, 0.03, Vector3(0.36 * sx, 0.11, -0.06))
		"hat":                                       # the Duelist: a wide brim, a crown, a red plume sweeping back
			mk.push_at(Vector3.ZERO, Vector3(-90, 0, 0))
			mk.cyl(0.46, 0.04, 16, "black", Color.WHITE, -1.0, Vector3(0, -0.06, 0))
			mk.cyl(0.24, 0.2, 12, "black", Color.WHITE, -1.0, Vector3(0, 0.04, 0))
			mk.cyl(0.25, 0.05, 12, "yellow", Color.WHITE, -1.0, Vector3(0, -0.03, 0))
			mk.hull([Vector3(-0.03, 0.08, 0.05), Vector3(0.03, 0.08, 0.05), Vector3(0, 0.12, 0.0), Vector3(-0.05, 0.42, 0.42),
				Vector3(0.05, 0.42, 0.42), Vector3(0, 0.3, 0.55)], "car_red")
			mk.pop()
		"cape":                                      # the back socket turns like the head's: build Y up, +Z behind
			mk.push_at(Vector3.ZERO, Vector3(-90, 0, 0))
			mk.hull([Vector3(-0.3, 0.05, 0.12), Vector3(0.3, 0.05, 0.12), Vector3(-0.3, 0.05, 0.16), Vector3(0.3, 0.05, 0.16),
				Vector3(-0.42, -1.0, 0.24), Vector3(0.42, -1.0, 0.24), Vector3(-0.42, -1.0, 0.28), Vector3(0.42, -1.0, 0.28)], "black")
			mk.pop()
		"hood":                                      # the Dancer (round 10): a headband, a high ponytail, two ribbons from the knot
			mk.push_at(Vector3.ZERO, Vector3(-90, 0, 0))
			mk.cyl(0.33, 0.08, 16, "neon_violet", Color.WHITE, -1.0, Vector3(0, -0.2, 0.04))
			mk.capsule(Vector3(0, 0.02, 0.14), Vector3(0, 0.3, 0.3), 0.09, "neon_pink")
			mk.capsule(Vector3(0, 0.3, 0.3), Vector3(0, 0.12, 0.62), 0.075, "neon_pink")
			for sx: float in [-1.0, 1.0]:
				mk.hull([Vector3(0.03 * sx, -0.2, 0.36), Vector3(0.09 * sx, -0.2, 0.36), Vector3(0.05 * sx, -0.24, 0.38),
					Vector3(0.22 * sx, -0.8, 0.6), Vector3(0.3 * sx, -0.78, 0.58), Vector3(0.27 * sx, -0.84, 0.64)], "neon_violet")
			mk.pop()
		"sword":
			_grip(mk, 0.2)
			mk.box(Vector3(0.26, 0.035, 0.05), "steel_dark", Color.WHITE, 0.01, Vector3(0, -0.11, 0))
			mk.hull([Vector3(-0.05, -0.13, -0.017), Vector3(0.05, -0.13, -0.017), Vector3(-0.05, -0.13, 0.017), Vector3(0.05, -0.13, 0.017),
				Vector3(-0.042, -0.95, -0.013), Vector3(0.042, -0.95, -0.013), Vector3(-0.042, -0.95, 0.013), Vector3(0.042, -0.95, 0.013),
				Vector3(0, -1.06, 0)], "steel_light")
			mk.box(Vector3(0.012, 0.8, 0.036), "steel_dark", Color.WHITE, 0.0, Vector3(0, -0.53, 0))      # the fuller: reads as a blade at range
		"rapier":
			_grip(mk, 0.18)
			mk.capsule(Vector3(-0.09, -0.1, 0), Vector3(0.09, -0.1, 0), 0.018, "yellow")
			mk.capsule(Vector3(0.0, -0.1, -0.07), Vector3(0.0, -0.1, 0.07), 0.014, "yellow")
			mk.hull([Vector3(-0.034, -0.12, -0.016), Vector3(0.034, -0.12, -0.016), Vector3(-0.034, -0.12, 0.016), Vector3(0.034, -0.12, 0.016),
				Vector3(-0.012, -1.0, -0.008), Vector3(0.012, -1.0, -0.008), Vector3(0, -1.1, 0)], "steel_light")
		"mace":
			mk.bar(Vector3(0, 0.12, 0), Vector3(0, -0.62, 0), 0.04, 0.045, "wood_dark", Color.WHITE, 0.006)
			mk.rbox(Vector3(0.17, 0.2, 0.17), "steel_dark", Color.WHITE, 0.03, Vector3(0, -0.66, 0))
			for a: float in [0.0, 90.0, 180.0, 270.0]:
				var d := Vector3(cos(deg_to_rad(a)), 0.0, sin(deg_to_rad(a)))
				mk.hull([d * 0.08 + Vector3(0, -0.6, 0), d * 0.08 + Vector3(0, -0.72, 0), d * 0.17 + Vector3(0, -0.66, 0),
					d * 0.08 + Vector3(0, -0.66, 0) + Vector3(d.z, 0, -d.x) * 0.04], "steel_light")
		"shield":
			mk.push_at(Vector3(-0.06, -0.08, 0.02), Vector3(90, 0, 0))
			mk.cyl(0.36, 0.06, 14, "wood", Color.WHITE)
			mk.cyl(0.38, 0.03, 14, "steel_dark", Color.WHITE, -1.0, Vector3(0, -0.005, 0))
			mk.cyl(0.09, 0.1, 8, "steel_light", Color.WHITE, 0.05, Vector3(0, 0.03, 0))
			mk.pop()
		"blade", "blade_l":
			_grip(mk, 0.15)
			mk.box(Vector3(0.14, 0.03, 0.04), "steel_dark", Color.WHITE, 0.008, Vector3(0, -0.09, 0))
			mk.hull([Vector3(-0.048, -0.1, -0.014), Vector3(0.048, -0.1, -0.014), Vector3(-0.048, -0.1, 0.014), Vector3(0.048, -0.1, 0.014),
				Vector3(0.02, -0.66, 0), Vector3(-0.034, -0.58, 0)], "neon_violet" if kind == "blade_l" else "steel_light")
	var mi := mk.instance("arm_" + kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	var tips: Dictionary = {"sword": 1.0, "rapier": 1.06, "mace": 0.7, "blade": 0.6, "blade_l": 0.6}
	if tips.has(kind):
		var tip := Node3D.new()
		tip.name = "Tip"                               # the swing's trail follows it (show.gd)
		tip.position = Vector3(0, -float(tips[kind]), 0)
		node.add_child(tip)
	if kind != "shield":
		node.rotation_degrees = GRIP if kind != "blade_l" else Vector3(GRIP.x, -GRIP.y, GRIP.z)
	sock.add_child(node)
	return node


static func _grip(mk: TLMesh, length: float) -> void:
	mk.bar(Vector3(0, length * 0.5, 0), Vector3(0, -0.1, 0), 0.032, 0.032, "strap", Color.WHITE, 0.005)
	mk.rbox(Vector3(0.05, 0.05, 0.05), "steel_dark", Color.WHITE, 0.015, Vector3(0, length * 0.5 + 0.02, 0))
