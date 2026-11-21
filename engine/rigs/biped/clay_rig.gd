extends TLRigBiped
## Painted figure on the same joints, sockets and clip clock as the classic biped.
const _Sculpt = preload("res://rigs/biped/clay_biped.gd")
const _Motion = preload("res://rigs/biped/clay_motion.gd")
const POCKET := Vector3(.211,1.043,-.163)
var _secondary := _Motion.new()
var _skate_built := false
var _right_leads := false
var _pocket_weight := 0.0
var _pocket_frame := -1
var _shoulder_drop := 0.0
var _shoulder_frame := -1
var _hand_mesh: MeshInstance3D
var _grip_weight := 0.0


func setup(p: Dictionary) -> void:
	super.setup(p)
	_clips["jump"]["fn"] = _clay_jump
	_clips["fly"]["fn"] = _clay_flight


func _rebuild_mesh(sk: Skeleton3D) -> void:
	var look := TLRigBipedMesh.LOOK.duplicate()
	look.merge(params.get("colors", {}), true)
	_helmet_built = _helmet()
	_skate_built = String(params["mode"]) == "skate"
	var figure := _sculptor()
	figure.sculpt(sk, look, bool(params["backpack"]), _helmet_built, _skate_built)
	_hand_mesh = attach_skinned(_model, sk, figure, "biped")
	if not _skate_built:
		_hand_mesh.set_blend_shape_value(0,_grip_weight)
	_metrics["triangles"] = figure.tri_count + _tri_extra


func _sculptor() -> _Sculpt:
	return _Sculpt.new()


func _param_changed(pname: String, value: Variant) -> void:
	super._param_changed(pname, value)
	# If headgear is forced, a mode change still changes the mittens.
	if pname == "mode" and _skate_built != (String(value) == "skate"):
		_rebuild_mesh(_sk)


func _build_stick() -> void:
	super._build_stick()
	# Run the shaft across the front of the sweater; plant its blade beside the skate.
	_stick.rotation_degrees = Vector3(44.4, -93.3, -2.9)


func _loco_pose() -> Dictionary:
	if String(params["mode"]) != "skate":
		return super._loco_pose()
	var v := _speed() if _loco_on else 0.0
	var pose := _skate_pose(_phase, lerpf(.12, 1.0, smoothstep(.3, 2.5, v)))
	var lean := clampf(float(params.get("lean", 0.0)), -1.0, 1.0)
	return add_pose(pose, {"Hips": Vector3(0,0,-16*lean), "Spine": Vector3(0,0,-5*lean)}) if lean != 0.0 else pose


func _post_pose() -> void:
	super._post_pose()
	if _grip_weight > 0.0 and clip not in [&"hang",&"mantle",&"swing"]:
		_hand_grip(move_toward(_grip_weight,0.0,.17))
	_relax_shoulders()
	_secondary.settle(_sk, frame)
	if not _skate_built and not _stick_on and not _hammer.visible and _grounded and clip in [&"", &"idle"]:
		var beat := fposmod(clip_t if clip == &"idle" else frame * DT, 4.0)
		var hold := _pocket_beat(beat) * (1.0 - smoothstep(.1,.8,_speed()))
		# A quick start can take the controller past walking speed in one
		# frame. Give the hand a few ticks to come away from the jacket.
		if frame != _pocket_frame:
			_pocket_weight = move_toward(_pocket_weight,hold,.12)
			_pocket_frame = frame
		if _pocket_weight > 0.0:
			var spine := _sk.find_bone("Spine")
			var target := _sk.get_bone_global_pose(spine) * (_sk.get_bone_global_rest(spine).affine_inverse() * POCKET)
			_Motion.reach_palm(_sk,"Right",target,Vector3(.94,-.32,.24),_pocket_weight)
			_save_arm("Right")
	else:
		_pocket_weight = 0.0
	if _stick_on and (clip in [&"", &"idle", &"walk", &"run", &"skate", &"skate_stop", &"pass", &"shoot"] or clip in TLRigBipedFight.STICK_CLIPS):
		var hand := _sk.get_bone_global_pose(_sk.find_bone("RightHand"))
		var shaft := (hand.basis * _stick.basis.y).normalized()
		var grip := hand * _Motion.PALM
		var shoulder := _sk.get_bone_global_pose(_sk.find_bone("LeftUpperArm")).origin
		var along := clampf((shoulder - grip).dot(shaft), .19, .48)
		_Motion.reach_palm(_sk, "Left", grip + shaft * along, Vector3(-1,-.4,.25), 1.0)


func _relax_shoulders() -> void:
	# The little coat hangs from a sloping shoulder. The clavicles lift back
	# into their action pose for a grab or takeoff without moving the root.
	var relaxed := not _skate_built and not _stick_on and _grounded and clip in [&"", &"idle", &"walk", &"run", &"land"]
	var drop := .063 if relaxed else 0.0
	if _shoulder_frame == frame or (_shoulder_drop == drop and _shoulder_frame >= 0):
		return
	_shoulder_drop = drop if _shoulder_frame < 0 else move_toward(_shoulder_drop,drop,.009)
	_shoulder_frame = frame
	for name_ in [&"LeftShoulder",&"RightShoulder"]:
		var bone := _sk.find_bone(name_)
		_sk.set_bone_pose_position(bone,_sk.get_bone_rest(bone).origin + Vector3.DOWN*_shoulder_drop)


## The controllers supply the actual support line after tick. Save the solved
## pose as the start of the blend out when the player lets go.
func _fit_grip(point: Vector3, axis: Vector3, mantle: float) -> void:
	if axis.is_zero_approx():
		return
	var w := 1.0 - smoothstep(.21,.51,mantle)
	if clip != &"mantle":
		w *= smoothstep(0.0,.10,clip_t)
	_hand_grip(w)
	if w <= 0.0:
		return
	_Motion.grip(_sk, point, axis, w, not _skate_built)
	_last["h"] = _sk.get_bone_pose_position(_root_bone) - _root_rest
	_save_arm("Left")
	_save_arm("Right")


func _hand_grip(weight: float) -> void:
	if _grip_weight == weight:
		return
	_grip_weight = weight
	if not _skate_built:
		_hand_mesh.set_blend_shape_value(0,weight)


func _save_arm(side: String) -> void:
	for segment: String in ["UpperArm","LowerArm","Hand"]:
		var bi := _sk.find_bone(side + segment)
		_last["q"][bi] = _sk.get_bone_pose_rotation(bi)


func _pocket_beat(beat: float) -> float:
	return smoothstep(1.12,1.93,beat) * (1.0 - smoothstep(2.69,3.68,beat))


func _idle(t: float) -> Dictionary:
	var pose := super._idle(t)
	if not _stick_on:
		# A glance across the path, a held beat, then a return. Both cuffs clear
		# the flared hem and the idle shares its feet with the planted walk.
		var beat := fposmod(t,4.0)
		var b := sin(TAU * t / 4.0)
		var b2 := sin(TAU * t / 2.0 + .6)
		var glance := smoothstep(.8,1.6,beat) * (1.0 - smoothstep(2.55,3.46,beat))
		pose["Head"] = Vector3(2.0 + 2.0*b2, -3.0 + 14.0*glance, 2.8*glance)
		# The head looks first, the jacket follows, then a thumb brushes the pocket.
		var follow := _pocket_beat(beat) if not _skate_built and not _hammer.visible else 0.0
		pose["Chest"] += Vector3(0, 5.0*follow, -3.0*follow)
		pose["LeftUpperArm"] = Vector3(4.0 + 2.0*b, 0, -18.0 - 1.8*b)
		pose["RightUpperArm"] = Vector3(3.0 - b2 - 4.0*follow, -13.0*follow, 17.0 - 6.0*follow)
		pose["RightLowerArm"] += Vector3(26.0*follow, 0, -4.0*follow)
	return pose


func _gait_pose(t: float) -> Dictionary:
	var pose := super._gait_pose(t)
	var stride := smoothstep(.25,1.55,_gait.v)
	if stride == 0.0 or _stick_on:
		return pose
	# Weight arrives above the planted boot, then the elbow and cuff follow.
	# The lower body keeps the planted gait's solved rotations and position.
	var phase := TAU * (_gait.phase - .43 * _gait.d)
	var support := cos(phase) * stride
	var roll := lerpf(7.2,4.4,smoothstep(2.5,6.0,_gait.v)) * support
	var catch := cos(2.0*phase + .78) * stride
	pose["Chest"] += Vector3(-3.2*catch, 0, roll)
	pose["Neck"] += Vector3(2.0*catch, 0, -.66*roll)
	var lag := sin(phase - .50) * stride
	pose["LeftUpperArm"] += Vector3(0,-3.5*support,-7.5*stride)
	pose["RightUpperArm"] += Vector3(0,-3.5*support,7.5*stride)
	pose["LeftLowerArm"] += Vector3(8.0*lag,0,0)
	pose["RightLowerArm"] += Vector3(-8.0*lag,0,0)
	return pose


func _clay_flight(t: float) -> Dictionary:
	var pose := TLRigBipedMoves.fly(t)
	# One heel kicks up at summon. clip_t counts the whole flight, while t
	# wraps with the breathing loop. The outside arm opens into a bank.
	var kick := smoothstep(.02,.22,clip_t) * (1.0 - smoothstep(.32,.85,clip_t))
	var attitude := (global_basis if is_inside_tree() else basis).orthonormalized().get_euler()
	var bank := clampf(attitude.z / deg_to_rad(28.0), -1.0, 1.0)
	var sail := maxf(smoothstep(5.0,32.0,_speed()), smoothstep(.33,1.0,-attitude.x))
	var left := maxf(bank,0.0)
	var right := maxf(-bank,0.0)
	pose["LeftUpperLeg"] += Vector3(9.0 + 22.0*kick, 0, -5.0 - 5.0*left)
	pose["LeftLowerLeg"] += Vector3(-16.0 - 26.0*kick + 8.0*sail, 0, 0)
	pose["RightUpperLeg"] += Vector3(-9.0 - 6.0*sail, 0, 5.0 + 5.0*right)
	pose["RightLowerLeg"] += Vector3(-5.0*right, 0, 0)
	pose["LeftUpperArm"] += Vector3(-8.0*sail, 0, -6.0 - 22.0*left - 10.0*kick)
	pose["RightUpperArm"] += Vector3(-8.0*sail, 0, 6.0 + 22.0*right + 10.0*kick)
	return pose


func _locomotion_changes(velocity_local: Vector3, grounded_now: bool) -> void:
	if _grounded and not grounded_now:
		var right := _sk.get_bone_global_pose(_sk.find_bone("RightFoot"))
		var left := _sk.get_bone_global_pose(_sk.find_bone("LeftFoot"))
		_right_leads = right.origin.z < left.origin.z
	super._locomotion_changes(velocity_local, grounded_now)
	if grounded_now and not _grounded:
		_secondary.touch_down(_impact)


func _land(t: float) -> Dictionary:
	var pose := super._land(t)
	if _skate_built or _stick_on:
		return pose
	# The boot and hip catch first. The jacket tips over that leg, the head
	# nods a few ticks later, and the wrists swing back under the cuffs.
	var weight := smoothstep(2.5,12.0,_impact)
	var compress := smoothstep(.01,.085,t) * (1.0-smoothstep(.105,.24,t))
	var nod := smoothstep(.045,.125,t) * (1.0-smoothstep(.14,.29,t))
	var rise := smoothstep(.13,.22,t) * (1.0-smoothstep(.24,.42,t))
	var side := (-1.0 if _right_leads else 1.0) * smoothstep(.4,2.8,_speed()/float(params["scale"]))
	pose["Chest"] += weight * Vector3(-11*compress+6*rise, 6*side*compress, 11*side*compress)
	pose["Head"] += weight * Vector3(-15*nod+5*rise,0,-6*side*nod)
	pose["LeftHand"] += Vector3(-20*nod+10*rise,0,-8*compress)*weight
	pose["RightHand"] += Vector3(-20*nod+10*rise,0,8*compress)*weight
	return pose


func _air(t: float) -> Dictionary:
	return _jump_lead(super._air(t))


func _clay_jump(t: float) -> Dictionary:
	var live := TLRigBipedMoves.air(_vel.y / float(params["scale"]))
	var pose := _mixe(TLRigBipedMoves.jump(t), live, smoothstep(.14,.30,t))
	var push := smoothstep(.025,.11,t) * (1.0 - smoothstep(.15,.27,t))
	pose["LeftUpperLeg"] += Vector3(18.0,0,-3.0) * push
	pose["LeftLowerLeg"] += Vector3(-18.0,0,0) * push
	return _jump_lead(pose,smoothstep(0.0,.10,t))


func _jump_lead(pose: Dictionary, swing: float = 1.0) -> Dictionary:
	# Opposite elbow and knee drive the running takeoff. As the ascent ends,
	# both arms open back into the balancing pose for the landing.
	var scale_m := float(params["scale"])
	var drive := swing * smoothstep(.6,3.0,_speed()/scale_m) * smoothstep(-1.4,3.6,_vel.y/scale_m)
	if drive > 0.0 and not _stick_on:
		pose["LeftUpperArm"] = (pose["LeftUpperArm"] as Vector3).lerp(Vector3(-24,0,-24),drive)
		pose["LeftLowerArm"] = (pose["LeftLowerArm"] as Vector3).lerp(Vector3(58,0,0),drive)
		pose["RightUpperArm"] = (pose["RightUpperArm"] as Vector3).lerp(Vector3(86,0,22),drive)
		pose["RightLowerArm"] = (pose["RightLowerArm"] as Vector3).lerp(Vector3(49,0,0),drive)
		pose["Chest"] += Vector3(1, -7 if _right_leads else 7, 0) * drive
	if _right_leads:
		for segment: String in ["UpperLeg","LowerLeg","Foot","Toes","UpperArm","LowerArm","Hand"]:
			var l := "Left" + segment
			var r := "Right" + segment
			var left: Vector3 = pose.get(l,Vector3.ZERO)
			pose[l] = (pose.get(r,Vector3.ZERO) as Vector3) * Vector3(1,-1,-1)
			pose[r] = left * Vector3(1,-1,-1)
	return pose
