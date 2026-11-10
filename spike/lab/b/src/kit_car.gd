class_name KitCar
extends RefCounted
## Kit part: the vehicle rig. Car(Node3D) / Body, WheelFL|FR|RL|RR (steer pivot) / Spin (mesh), Nitro (flame + trail + light).
## Faceted coupe from convex hulls. Params: body/stripe palette keys, spoiler. Faces -Z.

const WHEEL_R: float = 0.34
const WHEELBASE: float = 2.7


static func _mirror(pts: Array) -> Array:
	var out: Array = []
	for p: Vector3 in pts:
		out.append(p)
		out.append(Vector3(-p.x, p.y, p.z))
	return out


static func build(body_key: String = "car_red", stripe_key: String = "car_white", spoiler: bool = true) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Car"
	var mk: MK = MK.new(91)
	mk.hull(_mirror([Vector3(0.82, 0.24, -2.2), Vector3(0.86, 0.50, -2.18), Vector3(0.93, 0.70, -0.75), Vector3(0.93, 0.80, 1.45), Vector3(0.88, 0.82, 2.15),
		Vector3(0.86, 0.34, 2.2), Vector3(0.9, 0.22, -1.9), Vector3(0.9, 0.22, 1.95)]), body_key)
	mk.hull(_mirror([Vector3(0.80, 0.70, -0.55), Vector3(0.64, 1.16, 0.15), Vector3(0.64, 1.16, 0.95), Vector3(0.78, 0.80, 1.6)]), "car_glass")
	mk.rbox(Vector3(1.34, 0.11, 0.94), body_key, Color(1.05, 1.05, 1.05), 0.05, Vector3(0, 1.165, 0.55))   # moulded roof
	# pillars
	for sx: float in [-1.0, 1.0]:
		mk.bar(Vector3(sx * 0.8, 0.72, -0.55), Vector3(sx * 0.65, 1.17, 0.14), 0.07, 0.07, body_key)
		mk.bar(Vector3(sx * 0.79, 0.8, 1.6), Vector3(sx * 0.65, 1.17, 0.96), 0.07, 0.07, body_key)
	# racing stripes hugging hood, roof and tail deck
	var lift: float = 0.014
	for sx: float in [-1.0, 1.0]:
		var x0: float = sx * 0.10
		var x1: float = sx * 0.34
		var segs: Array = [[-2.17, 0.50, -0.56, 0.726], [0.16, 1.21, 0.94, 1.21], [1.6, 0.807, 2.14, 0.82]]
		for sg: Array in segs:
			mk.hull([Vector3(x0, float(sg[1]) + lift, sg[0]), Vector3(x1, float(sg[1]) + lift, sg[0]), Vector3(x0, float(sg[3]) + lift, sg[2]), Vector3(x1, float(sg[3]) + lift, sg[2]),
				Vector3(x0, float(sg[1]) - 0.03, sg[0]), Vector3(x1, float(sg[1]) - 0.03, sg[0]), Vector3(x0, float(sg[3]) - 0.03, sg[2]), Vector3(x1, float(sg[3]) - 0.03, sg[2])], stripe_key)
	# splitter, diffuser, lights, exhausts, side skirts
	mk.box(Vector3(1.82, 0.07, 0.36), "black", Color.WHITE, 0.01, Vector3(0, 0.2, -2.12))
	mk.capsule(Vector3(-0.78, 0.31, 2.17), Vector3(0.78, 0.31, 2.17), 0.1, "black", Color.WHITE, 8, 2)   # rear bumper
	mk.capsule(Vector3(-0.76, 0.33, -2.17), Vector3(0.76, 0.33, -2.17), 0.085, body_key, Color(0.92, 0.92, 0.92), 8, 2)   # front bumper
	for sx: float in [-1.0, 1.0]:
		mk.box(Vector3(0.34, 0.09, 0.06), "head_light", Color.WHITE, 0.01, Vector3(sx * 0.56, 0.46, -2.2))
		mk.box(Vector3(0.36, 0.1, 0.05), "tail_light", Color.WHITE, 0.01, Vector3(sx * 0.56, 0.68, 2.19))
		mk.push_at(Vector3(sx * 0.36, 0.3, 2.14), Vector3(90, 0, 0))
		mk.cyl(0.065, 0.16, 7, "steel_dark")
		mk.pop()
		mk.box(Vector3(0.06, 0.12, 2.0), "black", Color.WHITE, 0.01, Vector3(sx * 0.92, 0.27, 0.05))
		# wheel arch shadows
		for wz: float in [-1.32, 1.38]:
			mk.box(Vector3(0.1, 0.5, 0.86), "black", Color.WHITE, 0.03, Vector3(sx * 0.86, 0.42, wz))
	if spoiler:
		for sx: float in [-1.0, 1.0]:
			mk.bar(Vector3(sx * 0.6, 0.8, 1.95), Vector3(sx * 0.6, 1.1, 2.02), 0.06, 0.14, "black")
			mk.box(Vector3(0.05, 0.2, 0.42), body_key, Color(0.9, 0.9, 0.9), 0.01, Vector3(sx * 0.93, 1.1, 2.04))
		mk.box(Vector3(1.84, 0.05, 0.36), body_key, Color.WHITE, 0.015, Vector3(0, 1.13, 2.04))
	var body: MeshInstance3D = mk.instance("car_body")
	body.name = "Body"
	root.add_child(body)
	# wheels
	var wm: MK = MK.new(92)
	wm.push_at(Vector3(0.14, 0, 0), Vector3(0, 0, 90))
	wm.cyl(WHEEL_R, 0.28, 10, "tire")
	wm.cyl(0.2, 0.3, 8, "rim_metal", Color.WHITE, -1.0, Vector3(0, -0.01, 0))
	wm.pop()
	wm.box(Vector3(0.31, 0.07, 0.34), "steel_dark", Color.WHITE, 0.0)
	wm.box(Vector3(0.31, 0.34, 0.07), "steel_dark", Color.WHITE, 0.0)
	var wmesh: ArrayMesh = wm.build("wheel")
	for w: Array in [["WheelFL", -0.84, -1.32], ["WheelFR", 0.84, -1.32], ["WheelRL", -0.84, 1.38], ["WheelRR", 0.84, 1.38]]:
		var piv: Node3D = Node3D.new()
		piv.name = String(w[0])
		piv.position = Vector3(float(w[1]), WHEEL_R, float(w[2]))
		var spin: MeshInstance3D = MeshInstance3D.new()
		spin.name = "Spin"
		spin.mesh = wmesh
		piv.add_child(spin)
		root.add_child(piv)
	# nitro: emissive flame cones (scaled/flickered by the sim), trail particles, light
	var nitro: Node3D = Node3D.new()
	nitro.name = "Nitro"
	nitro.position = Vector3(0, 0.32, 2.25)
	nitro.visible = false
	var fm: MK = MK.new(93)
	for sx: float in [-1.0, 1.0]:
		fm.push_at(Vector3(sx * 0.36, 0, 0), Vector3(90, 0, 0))
		fm.cyl(0.17, 1.9, 6, "nitro_hot", Color.WHITE, 0.0, Vector3.ZERO, false, false)
		fm.cyl(0.09, 1.1, 6, "nitro_core", Color.WHITE, 0.0, Vector3(0, 0.02, 0), false, false)
		fm.pop()
	var flame: MeshInstance3D = fm.instance("nitro_flame")
	flame.name = "Flame"
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nitro.add_child(flame)
	var trail: CPUParticles3D = Fx.nitro_trail()
	trail.position = Vector3(0, 0, 0.4)
	nitro.add_child(trail)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(Style.data["palette"]["nitro_hot"])
	light.light_energy = 6.0
	light.omni_range = 7.0
	light.position = Vector3(0, 0.4, 1.0)
	nitro.add_child(light)
	root.add_child(nitro)
	var dust: CPUParticles3D = Fx.tyre_dust()
	dust.position = Vector3(0, 0.15, 2.0)
	dust.name = "TyreDust"
	root.add_child(dust)
	root.set_meta("tris", mk.tri_count + wm.tri_count * 4)
	return root
