extends Node3D
## Lane flight round 2 (19 Nov 2026): a windowed course for the clip of the walker's new moves (clip-moves.mp4).
##   godot --path engine res://kernel/world/moves_demo.tscn --write-movie <file.avi> -- [--quit=<ticks>]
## The village visitor (kernel/world/visitor.gd with its body, rig, wings and camera) in a small world space of its own:
## a floor, a wall 2.4 m high, a bar 2.4 m up. A scripted person, tick by tick: runs at the wall and jumps (catch, hang),
## mantles, turns, runs off the top, runs to the bar and jumps (catch), pumps the swing, releases, lands, then F (take-off
## with a puff of dust), hovers, C down and lands (dust). Prints a `MOVESDEMO` line per phase. Not part of any gate.

const Space = preload("res://kernel/world/terrain/world_space.gd")
const Visitor = preload("res://kernel/world/visitor.gd")
const WALL_TOP: float = 2.4
const BAR_Y: float = 2.8
const BAR_Z: float = 9.0

var land: Node3D
var v: Node3D
var t: int = 0
var phase: String = "run_wall"
var _phase_t: int = 0
var _quit: int = 1400
var _turned: float = 0.0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--quit="):
			_quit = int(a.trim_prefix("--quit="))
	TLStyle.install(self, {})
	land = Node3D.new()
	add_child(land)
	var fl: Node3D = TLKit.build("ground_patch", {"size_x": 80.0, "size_z": 80.0, "surface": "grass", "thickness": 0.3})
	fl.position.y = -0.0
	land.add_child(fl)
	var mk: TLMesh = TLMesh.new(1)
	mk.box(Vector3(8.0, WALL_TOP, 2.0), "concrete", Color.WHITE, 0.0, Vector3(0, WALL_TOP * 0.5, -3.0))
	mk.box(Vector3(4.0, 0.08, 0.08), "steel_light", Color.WHITE, 0.0, Vector3(0, BAR_Y, BAR_Z))
	mk.box(Vector3(0.14, BAR_Y + 0.1, 0.14), "yellow", Color.WHITE, 0.0, Vector3(-2.0, (BAR_Y + 0.1) * 0.5, BAR_Z))
	mk.box(Vector3(0.14, BAR_Y + 0.1, 0.14), "yellow", Color.WHITE, 0.0, Vector3(2.0, (BAR_Y + 0.1) * 0.5, BAR_Z))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mk.build("course")
	land.add_child(mi)
	for i: int in 4:
		var tr: Node3D = TLKit.build("tree", {"species": "broadleaf", "height": 8.0, "seed": 21 + i})
		tr.position = Vector3(-14.0 + 9.0 * float(i), 0, -16.0)
		land.add_child(tr)
	var sp: RefCounted = Space.new()
	sp.add_box(Transform3D(Basis(), Vector3(0, -0.5, 0)), Vector3(80, 1, 80))
	sp.add_box(Transform3D(Basis(), Vector3(0, WALL_TOP * 0.5, -3.0)), Vector3(8, WALL_TOP, 2))
	var bar: CylinderShape3D = CylinderShape3D.new()
	bar.radius = 0.05
	bar.height = 4.0
	(sp.get("_keep") as Array).append(bar)          # the shape must outlive this function (world_space keeps copied shapes so)
	sp.call("_copy_solid", bar, Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(0, BAR_Y, BAR_Z)), true)
	sp.call("finish")
	land.set_meta(&"tl_space", sp)
	v = Visitor.new()
	land.add_child(v)
	v.setup(Vector3(0.6, 0, 5.0), Vector3.FORWARD)
	v.steer_on()
	v.turn(0.0, deg_to_rad(-6.0), deg_to_rad(-10.0), deg_to_rad(60.0))
	(v.get("cam") as Camera3D).make_current()


func _go(p: String) -> void:
	print("MOVESDEMO t=%d %s -> %s feet=%s mode=%s" % [t, phase, p, v.feet, v.mode])
	phase = p
	_phase_t = 0


func _physics_process(_d: float) -> void:
	t += 1
	_phase_t += 1
	var fwd: Vector3 = Vector3(-sin(v.look_yaw), 0.0, -cos(v.look_yaw))
	var wish: Vector3 = Vector3.ZERO
	var jump: bool = false
	var slide: bool = false
	var fly: bool = false
	var climb: float = 0.0
	match phase:
		"run_wall":                                   # stand a moment, then run at the wall and jump
			if t > 40:
				wish = fwd * 9.0
				jump = v.feet.z < -0.6 and v.mode == "ground"
			if v.mode == "hang":
				_go("hang")
		"hang":
			if _phase_t == 50:
				jump = true                           # Space: mantle
			if v.mode == "ground" and _phase_t > 50:
				_go("on_top")
		"on_top":                                     # turn round on the top (the view turns 180 deg over 40 ticks)
			if _phase_t > 20 and _turned < PI:
				var step: float = minf(PI / 40.0, PI - _turned)
				v.turn(step, 0.0, deg_to_rad(-10.0), deg_to_rad(60.0))
				_turned += step
			elif _turned >= PI:
				_go("to_bar")
		"to_bar":                                     # run off the top and on to the bar, jump under it
			if v.feet.z < BAR_Z - 1.6:
				wish = fwd * 9.0
			elif v.feet.z < BAR_Z - 0.05:
				wish = fwd * 2.0
			jump = v.mode == "ground" and v.feet.z >= BAR_Z - 0.05 and v.speed < 0.3
			if v.mode == "bar":
				_go("swing")
		"swing":                                      # pump with the swing, then let go at a forward peak
			if _phase_t <= 45:                         # the view turns 80 deg to watch the swing from the side
				v.turn(deg_to_rad(80.0) / 45.0, 0.0, deg_to_rad(-10.0), deg_to_rad(60.0))
			var face: Vector3 = Vector3(-sin(v.face_yaw), 0.0, -cos(v.face_yaw))
			if _phase_t < 170:
				wish = face * (4.5 if v.bar_omega * _swing_sign() >= 0.0 else -4.5)
			elif v.bar_omega * _swing_sign() > 0.0 and v.bar_theta * _swing_sign() > 0.35:
				jump = true
			if v.mode == "air":
				_go("fly_off")
		"fly_off":                                    # land, walk a step, then F
			if v.mode == "ground" and _phase_t > 40 and _phase_t < 60:
				wish = fwd * 2.0
			if _phase_t == 80:
				fly = true
			if v.flying:
				_go("hover")
		"hover":
			climb = 1.0 if _phase_t < 50 else 0.0
			wish = fwd * 6.0 if _phase_t > 40 and _phase_t < 100 else Vector3.ZERO
			if _phase_t > 130:
				climb = -1.0
			if v.mode == "ground":
				_go("landed")
		"landed":
			pass
	v.wish(wish, jump, slide, fly, climb)
	v.step(v.feet, t)
	if t >= _quit or (phase == "landed" and _phase_t > 90):
		print("MOVESDEMO t=%d end feet=%s mode=%s" % [t, v.feet, v.mode])
		get_tree().quit()


## +1 when a positive theta swings him the way he faces (forward), else -1.
func _swing_sign() -> float:
	var tangent: Vector3 = v.bar_axis.cross(Vector3.DOWN)
	var fwd: Vector3 = Vector3(-sin(v.face_yaw), 0.0, -cos(v.face_yaw))
	return 1.0 if tangent.dot(fwd) >= 0.0 else -1.0
