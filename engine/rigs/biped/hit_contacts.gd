extends RefCounted
## Contact shapes in bind metres for the authored ground poses. The reference
## plane is the rig's own sole plane, including when the controller is airborne.
## Sampling the blended pose keeps a boot tangent between widely spaced keys.

static func _bottom(xf: Transform3D, center: Vector3, half_box: Vector3, radius: float) -> float:
	# Rounded box. Project its three axes on vertical without building corners.
	var y := Vector3(xf.basis.x.y, xf.basis.y.y, xf.basis.z.y)
	return (xf * center).y - half_box.dot(y.abs()) - radius


static func support(rig: TLRigBiped) -> void:
	if not rig.clip.begins_with("fall_") and not rig.clip.begins_with("get_up_"):
		return
	var sk := rig._sk
	var floor_y := -rig._model.position.y / float(rig.params["scale"])
	var head := sk.get_bone_global_pose(sk.find_bone("Head"))
	var low := _bottom(head, Vector3(0,.215,.015), Vector3(.06,.045,.04), .265)
	var hips := sk.get_bone_global_pose(rig._root_bone)
	low = minf(low, _bottom(hips, Vector3(0,.055,.005), Vector3(.16,.08,.07), .12))
	if rig.params["backpack"]:
		var bag := sk.get_bone_global_pose(sk.find_bone("Backpack"))
		low = minf(low, _bottom(bag, Vector3(.015,-.29,.10), Vector3(.12,.07,.055), .07))
		# The buckle is below the bag pivot and swings with its secondary motion.
		low = minf(low, (bag * Vector3(.035,-.39,.22)).y - .05)
	for side: String in ["Left", "Right"]:
		var sign_x := -1.0 if side == "Left" else 1.0
		var foot := sk.get_bone_global_pose(sk.find_bone(side + "Foot"))
		low = minf(low, _bottom(foot, Vector3(.06*sign_x,-.025,-.053), Vector3(.115,.044,.17), .033))
		low = minf(low, (foot * Vector3(0,-.07,-.27)).y)
		low = minf(low, (foot * Vector3(-.107*sign_x,-.10,.125)).y)
		var toes := sk.get_bone_global_pose(sk.find_bone(side + "Toes"))
		low = minf(low, _bottom(toes, Vector3(0,-.015,-.03), Vector3(.107,.015,.085), 0.0))
		if floor_y < 0.0:
			low = minf(low, _bottom(foot, Vector3(0,-.125,-.06), Vector3(.011,.024,.178), .002))
		var knee := sk.get_bone_global_pose(sk.find_bone(side + "LowerLeg"))
		low = minf(low, _bottom(knee, Vector3(.03*sign_x,.005,.01), Vector3(.01,.012,.028), .112))
		var elbow := sk.get_bone_global_pose(sk.find_bone(side + "LowerArm"))
		low = minf(low, elbow.origin.y - .11)
		var wrist := sk.get_bone_global_pose(sk.find_bone(side + "Hand"))
		low = minf(low, _bottom(wrist, Vector3(0,-.087,-.025), Vector3(.03,.045,.035), .071))
		if floor_y == 0.0:
			low = minf(low, _bottom(wrist, Vector3(0,-.20,.035), Vector3(.019,.006,.012), .017))
			# The outside edge of the bare thumb bears weight as the palm rolls flat.
			low = minf(low, (wrist * Vector3(.121*sign_x,-.127,-.050)).y - .001)
	var lift := maxf(0.0, floor_y - low)
	if lift > 0.0:
		var shift := Vector3.UP * lift
		sk.set_bone_pose_position(rig._root_bone, sk.get_bone_pose_position(rig._root_bone) + shift)
		rig._last["h"] += shift
	if rig._stick_on:
		_clear_stick(rig, floor_y)


static func _clear_stick(rig: TLRigBiped, floor_y: float) -> void:
	# Turn the gripping wrist when a blade or butt would cross the plane.
	# The prop remains a child of hand_r, with the original local transform.
	var sk := rig._sk
	var bone := sk.find_bone("RightHand")
	var wrist := sk.get_bone_global_pose(bone)
	var palm := rig.socket(&"hand_r").position
	var basis := wrist.basis
	for tip: Vector3 in [Vector3(-.38,-1.03,0), Vector3(.035,-1.03,0), Vector3(0,.56,0)]:
		var end := basis * (palm + rig._stick.basis * tip)
		var limit := floor_y + .025 - wrist.origin.y
		if end.y >= limit:
			continue
		var flat := Vector3(end.x, 0, end.z).normalized()
		if flat.is_zero_approx():
			flat = Vector3.RIGHT
		var target := flat * sqrt(maxf(0.0, end.length_squared() - limit * limit)) + Vector3.UP * limit
		basis = Basis(Quaternion(end.normalized(), target.normalized())) * basis
	var parent := sk.get_bone_global_pose(sk.get_bone_parent(bone)).basis
	var local := (parent.inverse() * basis).get_rotation_quaternion()
	sk.set_bone_pose_rotation(bone, local)
	rig._last["q"][bone] = local
