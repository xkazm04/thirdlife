class_name CarUnit
extends Node3D
## Vehicle on the shared vehicle skeleton (Root + 4 wheel bones). Drives the track spline kinematically;
## steering = front wheel bone yaw, spin = wheel bone pitch, body roll from lateral acceleration.

var style: Style
var rig: Dictionary
var skel: Skeleton3D
var track: Track
var station: float = 0.0
var speed: float = 17.0
var base_speed: float = 17.0
var offset: float = 1.9
var wheel_spin: float = 0.0
var nitro_t: float = -1.0
var flames: Array = []
var trail: GPUParticles3D
var roll: float = 0.0
var body_pivot: Node3D
const WHEEL_R := 0.4
const WHEELBASE := 2.76


func setup(st: Style, tr: Track, asset: String, off: float, spd: float, start: float) -> void:
	style = st
	track = tr
	offset = off
	speed = spd
	base_speed = spd
	station = start
	rig = Rig.build("vehicle", "res://assets/%s.vxm" % asset, st)
	body_pivot = Node3D.new()
	add_child(body_pivot)
	body_pivot.add_child(rig["root"])
	skel = rig["skel"]
	var wh := Vxm.load_chunks("res://assets/car_wheel.vxm", st)
	for wn: String in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
		var ba := BoneAttachment3D.new()
		skel.add_child(ba)
		ba.bone_name = wn
		var mi := MeshInstance3D.new()
		mi.mesh = wh[0]["mesh"]
		ba.add_child(mi)
	for sx: float in [-1.0, 1.0]:
		var f := Fx.flame(rig["root"])
		f.position = Vector3(sx * 0.35, 0.45, 2.4)
		flames.append(f)
	trail = Fx.trail(rig["root"])
	trail.position = Vector3(0, 0.45, 2.5)
	var hl := SpotLight3D.new()
	hl.light_energy = 2.0
	hl.spot_range = 22.0
	hl.spot_angle = 28.0
	hl.light_color = Color(1.0, 0.95, 0.8)
	hl.position = Vector3(0, 0.55, -2.2)
	hl.rotation.x = deg_to_rad(-3)
	rig["root"].add_child(hl)


func fire_nitro() -> void:
	nitro_t = 0.0


func step(delta: float) -> void:
	if nitro_t >= 0.0:
		nitro_t += delta
		var k := 1.0
		if nitro_t < 0.5:
			k = nitro_t / 0.5
		elif nitro_t > 4.0:
			k = maxf(0.0, 1.0 - (nitro_t - 4.0) / 1.0)
		speed = base_speed + 15.0 * k
		var on := nitro_t < 5.0
		for f: GPUParticles3D in flames:
			f.emitting = on and k > 0.3
		trail.emitting = on and k > 0.3
		if nitro_t > 5.0:
			nitro_t = -1.0
			speed = base_speed
	station = fposmod(station + speed * delta, track.length)
	var s := track.sample(station)
	var s2 := track.sample(station + 4.0)
	var pos: Vector3 = s["pos"] + s["right"] * offset
	var ahead: Vector3 = s2["pos"] + s2["right"] * offset
	var hd := ahead - pos
	hd.y = 0
	position = pos
	rotation.y = atan2(-hd.x, -hd.z)
	var curv: float = s["curv"]
	var lat := speed * speed * curv
	roll = lerpf(roll, clampf(lat * 0.0016, -0.08, 0.08), clampf(delta * 5.0, 0, 1))
	body_pivot.rotation.z = roll
	body_pivot.rotation.x = -0.012 * (speed - base_speed) / 5.0
	wheel_spin += speed * delta / WHEEL_R
	var steer := atan(WHEELBASE * curv)
	var spin := Quaternion.from_euler(Vector3(-wheel_spin, 0, 0))
	var st := Quaternion.from_euler(Vector3(0, steer, 0))
	skel.set_bone_pose_rotation(rig["idx"]["WheelFL"], st * spin)
	skel.set_bone_pose_rotation(rig["idx"]["WheelFR"], st * spin)
	skel.set_bone_pose_rotation(rig["idx"]["WheelRL"], spin)
	skel.set_bone_pose_rotation(rig["idx"]["WheelRR"], spin)
