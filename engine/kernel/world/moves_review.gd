extends Node3D
## Lane flight round 2 (19 Nov 2026): a look at the walker's ledge and bar poses outside the world (windowed, frames).
##   godot --path engine res://kernel/world/moves_review.tscn -- --out=<dir>
## A wall 2.4 m high and a bar 2.2 m over the floor; the biped hangs on the wall's edge, mantles (several moments of the
## clip), and swings on the bar at several angles. Writes JPG stills. Not part of any pack or gate.

var args: Dictionary = {}
var rig: Node3D
var cam: Camera3D
var frame: int = 0
var out: String = ""
var shots: Array = []
var _i: int = 0
var _wait: int = 0
const WALL_H: float = 2.4
const BAR_H: float = 2.2


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	out = String(args.get("out", "user://moves_review"))
	DirAccess.make_dir_recursive_absolute(out)
	TLStyle.install(self, {})
	var fl: Node3D = TLKit.build("ground_patch", {"size_x": 60.0, "size_z": 60.0, "surface": "concrete", "thickness": 0.3})
	add_child(fl)
	# the wall: a box whose face is at z = -0.36 (the figure at the origin faces -z, the capsule radius 0.35 + 1 cm)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mk: TLMesh = TLMesh.new(1)
	mk.box(Vector3(6.0, WALL_H, 1.0), "concrete_dark", Color.WHITE, 0.0, Vector3(0, WALL_H * 0.5, -0.86))
	mi.mesh = mk.build("wall")
	add_child(mi)
	# the bar, 8 m to the left: a steel rod on two posts
	var mb: TLMesh = TLMesh.new(1)
	mb.box(Vector3(3.0, 0.07, 0.07), "steel_light", Color.WHITE, 0.0, Vector3(-8.0, BAR_H, 0.0))
	mb.box(Vector3(0.12, BAR_H + 0.1, 0.12), "steel_dark", Color.WHITE, 0.0, Vector3(-9.5, (BAR_H + 0.1) * 0.5, 0.0))
	mb.box(Vector3(0.12, BAR_H + 0.1, 0.12), "steel_dark", Color.WHITE, 0.0, Vector3(-6.5, (BAR_H + 0.1) * 0.5, 0.0))
	var bi: MeshInstance3D = MeshInstance3D.new()
	bi.mesh = mb.build("bar")
	add_child(bi)
	rig = TLRigs.build("biped", {})
	add_child(rig)
	cam = Camera3D.new()
	cam.fov = 36.0
	add_child(cam)
	cam.make_current()
	# name, clip, ticks into the clip, where: "wall" (feet so the hands meet the top) | "bar" (theta deg), view
	shots = [
		["hang_side", "hang", 30, "wall", 0.0, "side_wall"],
		["hang_back", "hang", 30, "wall", 0.0, "back_wall"],
		["mantle_25", "mantle", 7, "wall", 0.0, "side_wall"],
		["mantle_50", "mantle", 14, "wall", 0.0, "side_wall"],
		["mantle_75", "mantle", 21, "wall", 0.0, "side_wall"],
		["mantle_100", "mantle", 28, "wall", 0.0, "side_wall"],
		["swing_0", "swing", 20, "bar", 0.0, "side_bar"],
		["swing_back40", "swing", 20, "bar", -40.0, "side_bar"],
		["swing_fwd60", "swing", 20, "bar", 60.0, "side_bar"],
		["swing_three", "swing", 20, "bar", 25.0, "three_bar"],
	]


## Feet for a pose. Hanging: the hands (about 2.15 m over the feet with the arms up and forward) on the wall's top.
## On the bar: the figure turned by theta about the bar (hands at BAR_H), the feet 2.2 m down the body axis. Mantle: the
## body path the controller drives (up 0..0.45, then forward onto the top), approximated here.
func _place(where: String, theta: float, clip: String, t: int) -> void:
	if where == "wall":
		var feet: Vector3 = Vector3(0, WALL_H - 2.1, 0)
		if clip == "mantle":
			var k: float = float(t) / 28.0
			var up: float = smoothstep(0.0, 0.55, k)
			var fwd: float = smoothstep(0.45, 1.0, k)
			feet = Vector3(0, lerpf(WALL_H - 2.1, WALL_H, up), lerpf(0.0, -0.75, fwd))
		rig.transform = Transform3D(Basis(), feet)
	else:
		var b: Basis = Basis(Vector3.RIGHT, deg_to_rad(-theta))
		var hands: Vector3 = Vector3(-8.0, BAR_H, 0.0)
		rig.transform = Transform3D(b, hands - b * Vector3(0, 2.2, 0))


func _view(v: String) -> void:
	match v:
		"side_wall":
			cam.look_at_from_position(Vector3(7.0, 2.6, 1.2), Vector3(0, 2.0, -0.4), Vector3.UP)
		"back_wall":
			cam.look_at_from_position(Vector3(0.8, 2.2, 5.5), Vector3(0, 1.4, -0.4), Vector3.UP)
		"side_bar":
			cam.look_at_from_position(Vector3(-15.0, 1.8, 2.2), Vector3(-8.0, 1.2, 0.0), Vector3.UP)
		"three_bar":
			cam.look_at_from_position(Vector3(-12.5, 2.4, 5.5), Vector3(-8.0, 1.2, 0.0), Vector3.UP)


func _physics_process(_d: float) -> void:
	frame += 1
	if frame < 20:
		rig.call("set_locomotion", Vector3.ZERO, true)
		rig.call("tick", frame)
		return
	if _i >= shots.size():
		get_tree().quit()
		return
	var s: Array = shots[_i]
	if _wait == 0:
		rig.call("play", StringName(String(s[1])), 0.0)
	_wait += 1
	rig.call("set_locomotion", Vector3.ZERO, false)
	rig.call("tick", frame)
	var t: int = mini(_wait, int(s[2]))
	_place(String(s[3]), float(s[4]), String(s[1]), t)
	_view(String(s[5]))
	if _wait == int(s[2]) + 2:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_jpg("%s/%02d_%s.jpg" % [out, _i, String(s[0])], 0.9)
		print("[moves_review] shot %s" % s[0])
		_wait = 0
		_i += 1
