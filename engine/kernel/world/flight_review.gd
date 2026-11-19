extends Node3D
## Lane flight (19 Nov 2026): a look at the walker's wings outside the world (windowed; frames, never a clock).
##   godot --path engine res://kernel/world/flight_review.tscn -- --out=<dir> [--seq=1]
## Writes PNG stills of the biped with the wings: folded, unfolding (several k), spread in the fly pose at hover and
## leaning at cruise, from behind, three-quarter and the side. `--seq=1` also writes one PNG per tick of a take-off
## (unfold), a glide with a bank and a landing (fold), for a contact sheet / clip. Not part of any pack.

const Wings: GDScript = preload("res://kernel/world/flight_wings.gd")
var args: Dictionary = {}
var rig: Node3D
var pivot: Node3D
var wings: RefCounted
var cam: Camera3D
var frame: int = 0
var shots: Array = []      # [name, k, lean, bank turn, view, flying, speed_k]
var out: String = ""
var seq: bool = false
var _i: int = 0
var _wait: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	out = String(args.get("out", "user://flight_review"))
	DirAccess.make_dir_recursive_absolute(out)
	seq = args.has("seq")
	TLStyle.install(self, {})
	var fl: Node3D = TLKit.build("ground_patch", {"size_x": 60.0, "size_z": 60.0, "surface": "grass", "thickness": 0.3})
	add_child(fl)
	for i: int in 3:
		var tr: Node3D = TLKit.build("tree", {"species": "broadleaf", "height": 9.0, "seed": 11 + i})
		tr.position = Vector3(-9.0 + 9.0 * float(i), 0, -14.0)
		add_child(tr)
	pivot = Node3D.new()
	add_child(pivot)
	rig = TLRigs.build("biped", {})
	pivot.add_child(rig)
	wings = Wings.attach(rig)
	print("[flight_review] wings=%s parts=%s tris=%s" % [wings != null, wings.root.get_meta(&"tl_parts", []) if wings != null else [], wings.root.get_meta(&"tl_tris", 0) if wings != null else 0])
	cam = Camera3D.new()
	cam.fov = 36.0
	add_child(cam)
	cam.make_current()
	# name, k (0 folded..1), lean deg, bank deg, view, clip, height over ground
	shots = [
		["folded_back", 0.0, 0.0, 0.0, "back", "", 0.0],
		["folded_three", 0.0, 0.0, 0.0, "three", "", 0.0],
		["folded_side", 0.0, 0.0, 0.0, "side", "", 0.0],
		["unfold_25", 0.25, 5.0, 0.0, "back", "fly", 0.6],
		["unfold_50", 0.5, 8.0, 0.0, "back", "fly", 1.2],
		["unfold_75", 0.75, 10.0, 0.0, "back", "fly", 1.8],
		["spread_hover_back", 1.0, 14.0, 0.0, "back", "fly", 2.5],
		["spread_hover_three", 1.0, 14.0, 0.0, "three", "fly", 2.5],
		["cruise_three", 1.0, 62.0, 0.0, "three_high", "fly", 2.5],
		["cruise_side", 1.0, 62.0, 0.0, "side", "fly", 2.5],
		["cruise_chase", 1.0, 62.0, 0.0, "chase", "fly", 2.5],
		["bank_chase", 1.0, 62.0, 16.0, "chase", "fly", 2.5],
	]


func _pose_view(view: String, h: float) -> void:
	var c: Vector3 = Vector3(0, 1.2 + h, 0)
	match view:
		"back":
			cam.look_at_from_position(c + Vector3(0.0, 0.6, 7.5), c, Vector3.UP)
		"three":
			cam.look_at_from_position(c + Vector3(5.0, 1.4, 5.5), c, Vector3.UP)
		"three_high":
			cam.look_at_from_position(c + Vector3(5.0, 3.5, 5.0), c, Vector3.UP)
		"side":
			cam.look_at_from_position(c + Vector3(7.5, 0.4, 0.0), c, Vector3.UP)
		"chase":
			cam.look_at_from_position(c + Vector3(0.0, 3.2, 10.0), c + Vector3(0, 0.4, -2.0), Vector3.UP)


func _set_body(lean: float, bank: float, h: float) -> void:
	# the figure leans forward about a point at its middle (y = 1.0) and rolls with the bank
	var b: Basis = Basis.from_euler(Vector3(deg_to_rad(-lean), 0.0, deg_to_rad(bank)))
	var mid: Vector3 = Vector3(0, 1.0, 0)
	pivot.transform = Transform3D(b, Vector3(0, h, 0) + mid - b * mid)


func _physics_process(_d: float) -> void:
	frame += 1
	rig.call("set_locomotion", Vector3.ZERO, true)
	rig.call("tick", frame)
	if frame < 20:
		return
	if seq:
		_seq_tick()
		return
	if _i >= shots.size():
		get_tree().quit()
		return
	var s: Array = shots[_i]
	if _wait == 0:
		if String(s[5]) == "fly":
			rig.call("play", &"fly", 0.0)
		else:
			rig.call("play", &"", 0.0)
		wings.set("k", float(s[1]))
		wings.call("_pose", 1.0 if float(s[2]) < 30.0 else 0.0, 0.0 if float(s[2]) < 30.0 else 1.0)
		_set_body(float(s[2]), float(s[3]), float(s[6]))
		_pose_view(String(s[4]), float(s[6]))
	if float(s[3]) != 0.0:
		wings.set("bank", float(s[3]))
		wings.call("_pose", 0.0, 1.0)
	_wait += 1
	if _wait == 12:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_jpg("%s/%02d_%s.jpg" % [out, _i, String(s[0])], 0.9)
		print("[flight_review] shot %s" % s[0])
		_wait = 0
		_i += 1


var _st: int = 0


## A take-off (30 ticks unfold while rising 2.5 m), a glide with lean growing to cruise and a bank, a descent and a fold.
func _seq_tick() -> void:
	_st += 1
	var t: int = _st
	var flying: bool = t < 200
	var rise: float = clampf(float(t) / 30.0, 0.0, 1.0)
	var h: float = 2.5 * smoothstep(0.0, 1.0, rise) if t < 200 else 2.5 * (1.0 - smoothstep(200.0, 236.0, float(t)))
	var spd: float = smoothstep(50.0, 110.0, float(t)) * (1.0 - smoothstep(160.0, 200.0, float(t)))
	var turn: float = deg_to_rad(90.0) * smoothstep(110.0, 130.0, float(t)) * (1.0 - smoothstep(145.0, 160.0, float(t)))
	if t == 1:
		rig.call("play", &"fly", 0.25)
	if t == 200:
		rig.call("play", &"", 0.3)
	wings.call("tick", flying, spd, turn, t)
	_set_body(lerpf(12.0, 62.0, spd) if flying else 0.0, float(wings.get("bank")) * 1.4, h)
	_pose_view("chase" if t > 60 and t < 190 else "three", h)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_jpg("%s/seq_%03d.jpg" % [out, t], 0.85)
	if t >= 250:
		get_tree().quit()
