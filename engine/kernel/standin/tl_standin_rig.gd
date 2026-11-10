class_name TLStandinRig
extends Node3D
## The minimal rig: answers every member of the rig table in contracts/KIT-RIG-STYLE.md with plain shapes
## (a capsule for a biped or bot, a box on four cylinders for a vehicle). Visual only; controllers own the body.

var family: StringName = &"biped"
var _metrics: Dictionary = {}
var _params: Dictionary = {}
var _clip: StringName = &"idle"
var _frame: int = 0
var _sockets: Dictionary = {}
var _wheels: Array = []
var _body_mesh: MeshInstance3D
var _velocity_local: Vector3 = Vector3.ZERO
var _grounded: bool = true


func build(family_: StringName, params: Dictionary = {}) -> void:
	family = family_
	var scale_: float = float(params.get("scale", 1.0))
	var color: Color = Color(0.85, 0.5, 0.2)
	if family == &"vehicle":
		_metrics = {"wheelbase": 2.6 * scale_, "track": 1.6 * scale_, "wheel_radius": 0.34 * scale_, "ride_height": 0.45 * scale_,
			"length": 4.2 * scale_, "width": 1.8 * scale_, "mass_hint": 1100.0 * scale_}
		_body_mesh = _box(Vector3(float(_metrics["width"]), 0.7 * scale_, float(_metrics["length"])), Vector3(0, 0.55 * scale_, 0), color)
		_box(Vector3(float(_metrics["width"]) * 0.8, 0.45 * scale_, float(_metrics["length"]) * 0.45), Vector3(0, 1.1 * scale_, 0.2 * scale_), color.darkened(0.25))
		for i: int in 4:
			var w: MeshInstance3D = MeshInstance3D.new()
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = float(_metrics["wheel_radius"])
			cm.bottom_radius = float(_metrics["wheel_radius"])
			cm.height = 0.24 * scale_
			w.mesh = cm
			w.material_override = TLStandin.material(Color(0.1, 0.1, 0.1))
			var pivot: Node3D = Node3D.new()
			# order FL FR RL RR; -z is forward
			pivot.position = Vector3((-0.5 if i % 2 == 0 else 0.5) * float(_metrics["track"]), float(_metrics["wheel_radius"]),
				(-0.5 if i < 2 else 0.5) * float(_metrics["wheelbase"]))
			w.rotation_degrees = Vector3(0, 0, 90)
			pivot.add_child(w)
			add_child(pivot)
			_wheels.append(pivot)
		for s: Array in [[&"exhaust_l", Vector3(-0.5, 0.35, 2.1)], [&"exhaust_r", Vector3(0.5, 0.35, 2.1)], [&"driver", Vector3(0, 1.0, 0.2)]]:
			_socket(s[0], (s[1] as Vector3) * scale_)
	else:
		var h: float = (1.8 if family == &"biped" else 1.15) * scale_
		var r: float = (0.3 if family == &"biped" else 0.28) * scale_
		_metrics = {"height": h, "radius": r, "eye_height": h * 0.92}
		_body_mesh = MeshInstance3D.new()
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = r
		cap.height = h
		_body_mesh.mesh = cap
		_body_mesh.position.y = h * 0.5
		_body_mesh.material_override = TLStandin.material(color if family == &"biped" else Color(0.9, 0.75, 0.2))
		add_child(_body_mesh)
		_box(Vector3(r * 0.9, r * 0.35, r * 0.5), Vector3(0, h * 0.88, -r * 0.8), Color(0.15, 0.15, 0.18))   # a visor: shows the facing
		for s: Array in [[&"hand_r", Vector3(r * 1.2, h * 0.5, 0)], [&"hand_l", Vector3(-r * 1.2, h * 0.5, 0)], [&"head", Vector3(0, h, 0)],
				[&"back", Vector3(0, h * 0.7, r)], [&"foot_r", Vector3(r * 0.5, 0, 0)], [&"foot_l", Vector3(-r * 0.5, 0, 0)]]:
			_socket(s[0], s[1])


func _box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = at
	mi.material_override = TLStandin.material(color)
	add_child(mi)
	return mi


func _socket(socket_name: StringName, at: Vector3) -> void:
	var n: Node3D = Node3D.new()
	n.name = String(socket_name)
	n.position = at
	add_child(n)
	_sockets[socket_name] = n


func metrics() -> Dictionary:
	return _metrics


func clips() -> PackedStringArray:
	if family == &"biped":
		return PackedStringArray(["idle", "walk", "run", "skate", "skate_stop", "shoot", "pass", "cheer", "fall", "carry", "work"])
	if family == &"bot":
		return PackedStringArray(["idle", "walk", "work", "carry", "weld"])
	return PackedStringArray(["idle"])


func play(clip: StringName, _blend: float = 0.15) -> void:
	_clip = clip


func current_clip() -> StringName:
	return _clip


func set_locomotion(velocity_local: Vector3, grounded: bool) -> void:
	_velocity_local = velocity_local
	_grounded = grounded


func set_param(param: StringName, value: Variant) -> void:
	_params[param] = value
	if family == &"vehicle":
		if param == &"steer":
			for i: int in 2:
				(_wheels[i] as Node3D).rotation.y = float(value) * 0.5      # + = left, as the real rig (RIGS.md)
		elif param == &"suspension" and (value is Array or value is PackedFloat32Array) and value.size() == 4:
			for i: int in 4:
				(_wheels[i] as Node3D).position.y = float(_metrics["wheel_radius"]) + float(value[i])


func get_param(param: StringName) -> Variant:
	return _params.get(param)


func socket(socket_name: StringName) -> Node3D:
	return _sockets.get(socket_name) as Node3D


func tick(frame: int) -> void:
	_frame = frame
	if family != &"vehicle" and _body_mesh != null:
		# a small bob while moving, counted in frames
		var speed: float = Vector2(_velocity_local.x, _velocity_local.z).length()
		_body_mesh.position.y = float(_metrics["height"]) * 0.5 + (sin(float(frame) * 0.35) * 0.03 * minf(speed, 3.0) if _grounded else 0.0)
