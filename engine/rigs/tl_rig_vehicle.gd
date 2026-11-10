class_name TLRigVehicle
extends TLRigNode
## The vehicle rig: a faceted coupe (lane B). Visual only; the kernel's vehicle controller owns the body and feeds
## the rig every frame through set_param. Faces -Z.
##   Car / Chassis (Body mesh, Nitro, sockets)   <- squats and rolls a little with the suspension values
##   Car / WheelFL | WheelFR | WheelRL | WheelRR (steer pivot, moves up with compression) / Spin (mesh)
## Params: steer (-1..1, + = left), throttle (0..1), brake (0..1), wheel_spin (rad/s, + = forward),
## suspension ([FL, FR, RL, RR] metres of compression), nitro (0..1), colors ({"body": key, "stripe": key}).
## Sockets: exhaust_l, exhaust_r, driver. Clips: idle.

const WHEEL_R: float = 0.34
const WHEELBASE: float = 2.7
const TRACK: float = 1.68
const MAX_STEER_DEG: float = 32.0
const WHEELS: Array = [["WheelFL", -0.84, -1.32], ["WheelFR", 0.84, -1.32], ["WheelRL", -0.84, 1.38], ["WheelRR", 0.84, 1.38]]

var _chassis: Node3D
var _body: MeshInstance3D
var _wheels: Array = []
var _nitro: Node3D
var _flame: MeshInstance3D
var _light: OmniLight3D
var _brake: MeshInstance3D
var _spin: float = 0.0


static func _mirror(pts: Array) -> Array:
	var out: Array = []
	for q: Vector3 in pts:
		out.append(q)
		out.append(Vector3(-q.x, q.y, q.z))
	return out


func setup(p: Dictionary) -> void:
	family = &"vehicle"
	params = p
	name = "Car"
	scale = Vector3.ONE * float(p["scale"])
	var s: float = float(p["scale"])
	_metrics = {"wheelbase": WHEELBASE * s, "track": TRACK * s, "wheel_radius": WHEEL_R * s, "ride_height": 0.2 * s, "length": 4.4 * s, "width": 1.86 * s, "mass_hint": 1150.0 * s * s * s, "triangles": 0, "bones": 0}
	_chassis = Node3D.new()
	_chassis.name = "Chassis"
	add_child(_chassis)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_chassis.add_child(_body)
	var tris: int = _rebuild_body()
	# wheels
	var wm: TLMesh = TLMesh.new(92)
	wm.push_at(Vector3(0.14, 0, 0), Vector3(0, 0, 90))
	wm.cyl(WHEEL_R, 0.28, 10, "tire")
	wm.cyl(0.2, 0.3, 8, "rim_metal", Color.WHITE, -1.0, Vector3(0, -0.01, 0))
	wm.pop()
	wm.box(Vector3(0.31, 0.07, 0.34), "steel_dark", Color.WHITE, 0.0)
	wm.box(Vector3(0.31, 0.34, 0.07), "steel_dark", Color.WHITE, 0.0)
	var wmesh: ArrayMesh = wm.build("wheel")
	for w: Array in WHEELS:
		var piv: Node3D = Node3D.new()
		piv.name = String(w[0])
		piv.position = Vector3(float(w[1]), WHEEL_R, float(w[2]))
		var spin: MeshInstance3D = MeshInstance3D.new()
		spin.name = "Spin"
		spin.mesh = wmesh
		piv.add_child(spin)
		add_child(piv)
		_wheels.append(piv)
	# nitro: emissive flame cones scaled by the `nitro` param, flicker keyed to the frame
	_nitro = Node3D.new()
	_nitro.name = "Nitro"
	_nitro.position = Vector3(0, 0.32, 2.25)
	_nitro.visible = false
	var fm: TLMesh = TLMesh.new(93)
	for sx: float in [-1.0, 1.0]:
		fm.push_at(Vector3(sx * 0.36, 0, 0), Vector3(90, 0, 0))
		fm.cyl(0.17, 1.9, 6, "nitro_hot", Color.WHITE, 0.0, Vector3.ZERO, false, false)
		fm.cyl(0.09, 1.1, 6, "nitro_core", Color.WHITE, 0.0, Vector3(0, 0.02, 0), false, false)
		fm.pop()
	_flame = fm.instance("nitro_flame")
	_flame.name = "Flame"
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_nitro.add_child(_flame)
	if not TLStyle.headless():
		_light = OmniLight3D.new()
		_light.name = "Light"
		_light.light_color = TLStyle.color("nitro_hot")
		_light.light_energy = 6.0
		_light.omni_range = 7.0
		_light.position = Vector3(0, 0.4, 1.0)
		_nitro.add_child(_light)
	_chassis.add_child(_nitro)
	# brake lights: a brighter bar over the tail lights, shown while braking
	var bm: TLMesh = TLMesh.new(94)
	for sx: float in [-1.0, 1.0]:
		bm.box(Vector3(0.40, 0.13, 0.03), "hot", Color.WHITE, 0.01, Vector3(sx * 0.56, 0.68, 2.215))
	_brake = bm.instance("brake_lights")
	_brake.name = "BrakeLights"
	_brake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_brake.visible = false
	_chassis.add_child(_brake)
	for sk: Array in [["exhaust_l", Vector3(-0.36, 0.3, 2.24)], ["exhaust_r", Vector3(0.36, 0.3, 2.24)], ["driver", Vector3(-0.36, 0.72, 0.35)]]:
		var sn: Node3D = Node3D.new()
		sn.name = String(sk[0])
		sn.position = sk[1]
		_chassis.add_child(sn)
		_sockets[String(sk[0])] = sn
	_metrics["triangles"] = tris + wm.tri_count * 4 + fm.tri_count + bm.tri_count
	add_clip("idle", 1.0, true, func(_t: float) -> Dictionary: return {})
	tick(0)


func _rebuild_body() -> int:
	var look: Dictionary = params.get("colors", {})
	var body_key: String = String(look.get("body", "car_red"))
	var stripe_key: String = String(look.get("stripe", "car_white"))
	var mk: TLMesh = TLMesh.new(91)
	mk.hull(_mirror([Vector3(0.82, 0.24, -2.2), Vector3(0.86, 0.50, -2.18), Vector3(0.93, 0.70, -0.75), Vector3(0.93, 0.80, 1.45), Vector3(0.88, 0.82, 2.15),
		Vector3(0.86, 0.34, 2.2), Vector3(0.9, 0.22, -1.9), Vector3(0.9, 0.22, 1.95)]), body_key)
	mk.hull(_mirror([Vector3(0.80, 0.70, -0.55), Vector3(0.64, 1.16, 0.15), Vector3(0.64, 1.16, 0.95), Vector3(0.78, 0.80, 1.6)]), "car_glass")
	mk.rbox(Vector3(1.34, 0.11, 0.94), body_key, Color(1.05, 1.05, 1.05), 0.05, Vector3(0, 1.165, 0.55))
	for sx: float in [-1.0, 1.0]:
		mk.bar(Vector3(sx * 0.8, 0.72, -0.55), Vector3(sx * 0.65, 1.17, 0.14), 0.07, 0.07, body_key)
		mk.bar(Vector3(sx * 0.79, 0.8, 1.6), Vector3(sx * 0.65, 1.17, 0.96), 0.07, 0.07, body_key)
	var lift: float = 0.014
	for sx: float in [-1.0, 1.0]:
		var x0: float = sx * 0.10
		var x1: float = sx * 0.34
		var segs: Array = [[-2.17, 0.50, -0.56, 0.726], [0.16, 1.21, 0.94, 1.21], [1.6, 0.807, 2.14, 0.82]]
		for sg: Array in segs:
			mk.hull([Vector3(x0, float(sg[1]) + lift, sg[0]), Vector3(x1, float(sg[1]) + lift, sg[0]), Vector3(x0, float(sg[3]) + lift, sg[2]), Vector3(x1, float(sg[3]) + lift, sg[2]),
				Vector3(x0, float(sg[1]) - 0.03, sg[0]), Vector3(x1, float(sg[1]) - 0.03, sg[0]), Vector3(x0, float(sg[3]) - 0.03, sg[2]), Vector3(x1, float(sg[3]) - 0.03, sg[2])], stripe_key)
	mk.box(Vector3(1.82, 0.07, 0.36), "black", Color.WHITE, 0.01, Vector3(0, 0.2, -2.12))
	mk.capsule(Vector3(-0.78, 0.31, 2.17), Vector3(0.78, 0.31, 2.17), 0.1, "black", Color.WHITE, 8, 2)
	mk.capsule(Vector3(-0.76, 0.33, -2.17), Vector3(0.76, 0.33, -2.17), 0.085, body_key, Color(0.92, 0.92, 0.92), 8, 2)
	for sx: float in [-1.0, 1.0]:
		mk.box(Vector3(0.34, 0.09, 0.06), "head_light", Color.WHITE, 0.01, Vector3(sx * 0.56, 0.46, -2.2))
		mk.box(Vector3(0.36, 0.1, 0.05), "tail_light", Color.WHITE, 0.01, Vector3(sx * 0.56, 0.68, 2.19))
		mk.push_at(Vector3(sx * 0.36, 0.3, 2.14), Vector3(90, 0, 0))
		mk.cyl(0.065, 0.16, 7, "steel_dark")
		mk.pop()
		mk.box(Vector3(0.06, 0.12, 2.0), "black", Color.WHITE, 0.01, Vector3(sx * 0.92, 0.27, 0.05))
		for wz: float in [-1.32, 1.38]:
			mk.box(Vector3(0.1, 0.5, 0.86), "black", Color.WHITE, 0.03, Vector3(sx * 0.86, 0.42, wz))
	if bool(params.get("spoiler", true)):
		for sx: float in [-1.0, 1.0]:
			mk.bar(Vector3(sx * 0.6, 0.8, 1.95), Vector3(sx * 0.6, 1.1, 2.02), 0.06, 0.14, "black")
			mk.box(Vector3(0.05, 0.2, 0.42), body_key, Color(0.9, 0.9, 0.9), 0.01, Vector3(sx * 0.93, 1.1, 2.04))
		mk.box(Vector3(1.84, 0.05, 0.36), body_key, Color.WHITE, 0.015, Vector3(0, 1.13, 2.04))
	_body.mesh = mk.build("car_body")
	return mk.tri_count


func _param_changed(pname: String, _value: Variant) -> void:
	if pname == "colors":
		_rebuild_body()


func tick(frame_no: int) -> void:
	frame = frame_no
	var steer: float = clampf(float(params.get("steer", 0.0)), -1.0, 1.0)
	var throttle: float = clampf(float(params.get("throttle", 0.0)), 0.0, 1.0)
	var brake: float = clampf(float(params.get("brake", 0.0)), 0.0, 1.0)
	var nitro: float = clampf(float(params.get("nitro", 0.0)), 0.0, 1.0)
	var sus: Array = [0.0, 0.0, 0.0, 0.0]
	var sv: Variant = params.get("suspension", null)
	if sv is Array and (sv as Array).size() == 4:
		sus = sv
	_spin = fposmod(_spin + float(params.get("wheel_spin", 0.0)) * DT, TAU)
	for i: int in 4:
		var piv: Node3D = _wheels[i]
		var c: float = clampf(float(sus[i]), -0.12, 0.16)
		piv.position.y = WHEEL_R + c                                     # the body is the reference: a compressed wheel moves up
		piv.rotation.y = deg_to_rad(steer * MAX_STEER_DEG) if i < 2 else 0.0
		(piv.get_child(0) as Node3D).rotation.x = -_spin                  # rolling forward (-Z)
	# the chassis answers the driver's feet a little, on top of whatever the physics body does
	_chassis.rotation.x = deg_to_rad(1.6 * throttle - 2.2 * brake) * -1.0
	_chassis.rotation.z = deg_to_rad(-2.5 * steer * clampf(absf(float(params.get("wheel_spin", 0.0))) / 40.0, 0.0, 1.0))
	_chassis.position.y = 0.006 * sin(float(frame) * 0.9) * (0.3 + throttle)   # engine shake, keyed to the frame
	_brake.visible = brake > 0.05
	_nitro.visible = nitro > 0.01
	if _nitro.visible:
		var fl: float = 0.85 + 0.15 * sin(float(frame) * 2.1) + 0.08 * sin(float(frame) * 5.3)
		_flame.scale = Vector3(0.7 + 0.5 * nitro, 0.7 + 0.5 * nitro, (0.35 + 0.9 * nitro) * fl)
		if _light != null:
			_light.light_energy = 6.0 * nitro * fl
