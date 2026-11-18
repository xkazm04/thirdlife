extends SceneTree
## Bugfix-37 rig regressions (selftest block 330-bugfix-rig.sh), headless. One `RIGCASE <name> ok|fail <figures>` line per
## case; a case that prints nothing is a FAIL in the block. Frame-counted, no clock.
##   pose_rest   (D11) a bone the clip omits returns to rest: shoulders after cheer -> idle match a rig that only idled
##   gaze        (D11) look_at during `fall` (which omits the neck) stays within its 28 degree share, never accumulates
##   land_turn   (Q11) a turn made in the air does not twist the feet planted on landing
##   spawn_face  (Q27) a biped first ticked at frame 100 has open eyes at 120, as one ticked from 1
##   build_blink (Q28) expression = blink at build shuts the eyes, as set_param does
##   stick_color (Q29) a runtime `colors` with a stick key recolours the stick as the same key at build does

func _initialize() -> void:
	run.call_deferred()


func _line(cname: String, ok: bool, figures: String) -> void:
	print("RIGCASE %s %s %s" % [cname, "ok" if ok else "fail", figures])


func run() -> void:
	_pose_rest()
	_gaze()
	_land_turn()
	_spawn_face()
	_build_blink()
	_stick_color()
	quit()


func _pose_rest() -> void:
	var rig: TLRigNode = TLRigs.build("biped")
	var sk: Skeleton3D = rig.get_node("Model/Skeleton3D")
	var b: int = sk.find_bone("LeftShoulder")
	rig.play(&"cheer", 0.0)
	rig.tick(1)
	rig.play(&"idle", 0.0)
	var other: TLRigNode = TLRigs.build("biped")
	other.play(&"idle", 0.0)
	for f: int in range(2, 122):
		rig.tick(f)
		other.tick(f)
	var osk: Skeleton3D = other.get_node("Model/Skeleton3D")
	var delta: float = rad_to_deg(sk.get_bone_pose_rotation(b).angle_to(osk.get_bone_pose_rotation(b)))
	_line("pose_rest", delta <= 0.1, "shoulder_diff_deg=%.2f" % delta)
	rig.free()
	other.free()


func _gaze() -> void:
	# the look's share of the neck = the angle between the neck of a rig that looks and one that does not (same clip)
	var rig: TLRigNode = TLRigs.build("biped")
	var plain: TLRigNode = TLRigs.build("biped")
	root.add_child(rig)
	root.add_child(plain)
	var sk: Skeleton3D = rig.get_node("Model/Skeleton3D")
	var psk: Skeleton3D = plain.get_node("Model/Skeleton3D")
	var neck: int = sk.find_bone("Neck")
	rig.set_param(&"look_at", Vector3(100, 1.75, 0))
	rig.play(&"fall")
	plain.play(&"fall")
	var peak: float = 0.0
	for f: int in range(1, 61):
		rig.tick(f)
		plain.tick(f)
		peak = maxf(peak, rad_to_deg(sk.get_bone_pose_rotation(neck).angle_to(psk.get_bone_pose_rotation(neck))))
	_line("gaze", peak <= 28.1 and peak >= 27.0, "look_share_of_neck_peak_deg=%.1f limit=28" % peak)
	rig.free()
	plain.free()


func _land_turn() -> void:
	var control: float = _landed_yaw(false)
	var turned: float = _landed_yaw(true)
	_line("land_turn", absf(turned - control) <= 1.0, "boot_yaw_control=%.1f turned_in_air=%.1f" % [control, turned])


## A vertical jump; the body faces 30 degrees at the landing either way (turned in the air, or built that way).
func _landed_yaw(turn_in_air: bool) -> float:
	var rig: TLRigNode = TLRigs.build("biped")
	rig.rotation.y = 0.0 if turn_in_air else deg_to_rad(30.0)
	root.add_child(rig)
	rig.set_locomotion(Vector3.ZERO, true)
	rig.tick(1)
	for f: int in range(2, 32):
		if turn_in_air:
			rig.rotation.y = deg_to_rad(f - 1.0)
		var vy: float = 5.8 - 0.4 * (f - 2)
		rig.position.y += vy / 60.0
		rig.set_locomotion(Vector3(0, vy, 0), false)
		rig.tick(f)
	rig.position.y = 0.0
	rig.set_locomotion(Vector3.ZERO, true)
	rig.play(&"land")
	for f: int in range(32, 36):
		rig.tick(f)
	var sk: Skeleton3D = rig.get_node("Model/Skeleton3D")
	var yaw: float = rad_to_deg(sk.get_bone_global_pose(sk.find_bone("LeftFoot")).basis.get_euler().y)
	rig.free()
	return yaw


func _eye(rig: TLRigNode) -> float:
	var sk: Skeleton3D = rig.get_node("Model/Skeleton3D")
	return sk.get_bone_pose_scale(sk.find_bone("LeftEye")).y


func _spawn_face() -> void:
	var late: TLRigNode = TLRigs.build("biped")
	var control: TLRigNode = TLRigs.build("biped")
	for f: int in range(1, 121):
		control.tick(f)
		if f >= 100:
			late.tick(f)
	var a: float = _eye(late)
	var e: float = _eye(control)
	_line("spawn_face", absf(a - e) <= 0.01 and e > 0.5, "eye_late=%.2f eye_control=%.2f" % [a, e])
	late.free()
	control.free()


func _build_blink() -> void:
	var built: TLRigNode = TLRigs.build("biped", {"expression": "blink"})
	var runtime: TLRigNode = TLRigs.build("biped")
	runtime.set_param(&"expression", &"blink")
	var at_build: float = _eye(built)
	for f: int in range(1, 241):
		built.tick(f)
		runtime.tick(f)
	var a: float = _eye(built)
	var e: float = _eye(runtime)
	_line("build_blink", absf(a - e) <= 0.01 and e < 0.2 and at_build < 0.2, "eye_built=%.2f (at build %.2f) eye_set_param=%.2f" % [a, at_build, e])
	built.free()
	runtime.free()


func _stick_hash(rig: TLRigNode) -> String:
	var mi: MeshInstance3D = rig.find_child("StickMesh", true, false)
	return str(mi.mesh.get_meta("tl_hash"))


func _stick_color() -> void:
	var colors: Dictionary = {"stick": "car_red"}
	var changed: TLRigNode = TLRigs.build("biped", {"mode": "skate"})
	var built: TLRigNode = TLRigs.build("biped", {"mode": "skate", "colors": colors})
	var old: String = _stick_hash(changed)
	changed.set_param(&"colors", colors)
	var after: String = _stick_hash(changed)
	var ref: String = _stick_hash(built)
	_line("stick_color", old != ref and after == ref, "distinct_at_build=%s runtime_matches_build=%s" % [old != ref, after == ref])
	changed.free()
	built.free()
