extends RefCounted
## Small presentation-only corrections after a clip has posed the skeleton.
## Everything advances on tick(frame); the face may be reapplied on tree entry.
const PALM := Vector3(0,-.075,-.03) # both hand sockets, relative to their wrist
var last_frame := -1
var last_head := Quaternion.IDENTITY
var last_chest := Quaternion.IDENTITY
var hair := Vector3.ZERO
var hair_velocity := Vector3.ZERO
var collar := Vector3.ZERO
var collar_velocity := Vector3.ZERO
# Travel along each joint's own vertical, in metres. The satchel and collar
# on the shoulders are heavier and take longer to settle than the hair curl.
var drop := Vector2.ZERO
var drop_velocity := Vector2.ZERO


static func palm_width(side: float) -> Vector3:
	return Vector3(.86*side,0,.51).normalized()


static func palm_axis(side: float) -> Vector3:
	return Vector3.UP.cross(palm_width(side))


func touch_down(fall_speed: float) -> void:
	drop_velocity -= Vector2(.015,.020) * smoothstep(2.5,12.0,fall_speed)


func settle(sk: Skeleton3D, frame: int) -> void:
	var tuft := sk.find_bone("Hair")
	var lip := sk.find_bone("Backpack") # collar and satchel settle on the same shoulder pivot
	if frame != last_frame:
		var head := sk.get_bone_global_pose(sk.find_bone("Head")).basis.get_rotation_quaternion()
		var chest := sk.get_bone_global_pose(sk.find_bone("UpperChest")).basis.get_rotation_quaternion()
		var hair_target := sk.get_bone_pose_rotation(tuft).get_euler() * .68
		var collar_target := sk.get_bone_pose_rotation(lip).get_euler() * .55
		if frame == last_frame + 1 and last_frame >= 0:
			hair_target += (head.inverse() * last_head).get_euler() * 3.0
			collar_target += (chest.inverse() * last_chest).get_euler() * 2.6
		hair_target = hair_target.limit_length(.29)
		collar_target = collar_target.limit_length(.13)
		hair_velocity = .67 * hair_velocity + .22 * (hair_target - hair)
		collar_velocity = .59 * collar_velocity + .24 * (collar_target - collar)
		hair += hair_velocity
		collar += collar_velocity
		if drop != Vector2.ZERO or drop_velocity != Vector2.ZERO:
			drop_velocity = drop_velocity * Vector2(.62,.73) - drop * Vector2(.24,.15)
			drop = (drop+drop_velocity).clamp(Vector2(-.032,-.044),Vector2(.016,.019))
			if drop.length_squared() + drop_velocity.length_squared() < .00000002:
				drop = Vector2.ZERO
				drop_velocity = Vector2.ZERO
			sk.set_bone_pose_position(tuft,sk.get_bone_rest(tuft).origin + Vector3.UP*drop.x)
			sk.set_bone_pose_position(lip,sk.get_bone_rest(lip).origin + Vector3(0,drop.y,-.22*drop.y))
		last_head = head
		last_chest = chest
		last_frame = frame
	sk.set_bone_pose_rotation(tuft, Quaternion.from_euler(hair))
	sk.set_bone_pose_rotation(lip, Quaternion.from_euler(collar))


## Both palms on the sensed contact line. Work in bind metres even on a scaled
## rig. When the bar hangs above full reach, lift the dangling figure by the
## missing reach. The controller's feet and the game's capsule stay in place.
static func grip(sk: Skeleton3D, line: Vector3, axis: Vector3, amount: float, bare_hands: bool) -> void:
	var center := sk.to_local(line)
	var across := (sk.global_transform.basis.inverse() * axis).normalized()
	if across.dot(Vector3.RIGHT) < 0:
		across = -across
	var targets := [center - across * .285, center + across * .285]
	var turns: Array[Quaternion] = []
	var lift := Vector3.ZERO
	for i in 2:
		var side := "Left" if i == 0 else "Right"
		var hand := sk.get_bone_global_pose(sk.find_bone(side + "Hand"))
		var shoulder := sk.get_bone_global_pose(sk.find_bone(side + "UpperArm")).origin
		# Roll the opening between thumb and curled fingers onto the support.
		# This changes the wrist offset used for both the lift and the IK.
		var turn := Quaternion.IDENTITY
		if bare_hands:
			var channel := hand.basis * palm_axis(-1.0 if i == 0 else 1.0)
			turn = Quaternion(channel.normalized(),across)
		turns.append(turn)
		var reach: Vector3 = targets[i] - turn * (hand.basis * PALM) - shoulder
		lift += reach.normalized() * maxf(0.0, reach.length() - .495) * .5
	var hips := sk.find_bone("Hips")
	sk.set_bone_pose_position(hips, sk.get_bone_pose_position(hips) + lift.limit_length(.32) * amount)
	for i in 2:
		var side := "Left" if i == 0 else "Right"
		var pole := Vector3(-.54 if i == 0 else .54, -.10, .72)
		reach_palm(sk, side, targets[i], pole, amount, turns[i])


## Two-link IK with an optional wrist turn in skeleton space.
static func reach_palm(sk: Skeleton3D, side: String, palm: Vector3, pole: Vector3, amount: float, turn := Quaternion.IDENTITY) -> void:
	var upper := sk.find_bone(side + "UpperArm")
	var lower := sk.find_bone(side + "LowerArm")
	var hand := sk.find_bone(side + "Hand")
	var wrist := sk.get_bone_global_pose(hand)
	var arm := sk.get_bone_global_pose(upper)
	var forearm := sk.get_bone_global_pose(lower)
	var delta := palm - turn * (wrist.basis * PALM) - arm.origin
	if delta.length_squared() < .000001:
		return
	var direction := delta.normalized()
	var a := sk.get_bone_rest(lower).origin.length()
	var b := sk.get_bone_rest(hand).origin.length()
	var d := clampf(delta.length(), absf(a-b)+.0001, a+b-.0001)
	var along := (a*a + d*d - b*b) / (2.0*d)
	var perpendicular := (pole - direction * pole.dot(direction)).normalized()
	var elbow := direction * along + perpendicular * sqrt(maxf(0.0, a*a - along*along))
	# Solve both links in the same snapshot of the skeleton. Reading them back
	# between writes would propagate partially solved transforms down the chain.
	var shoulder_turn := Quaternion((forearm.origin - arm.origin).normalized(), elbow.normalized())
	var forearm_turn := Quaternion((wrist.origin - forearm.origin).normalized(), (direction*d - elbow).normalized())
	var upper_q := arm.basis.get_rotation_quaternion()
	var lower_q := forearm.basis.get_rotation_quaternion()
	var shoulder_q := upper_q * sk.get_bone_pose_rotation(upper).inverse()
	var new_upper := shoulder_turn * upper_q
	var new_lower := forearm_turn * lower_q
	_turn(sk, upper, shoulder_q.inverse() * new_upper, amount)
	_turn(sk, lower, new_upper.inverse() * new_lower, amount)
	_turn(sk, hand, new_lower.inverse() * turn * wrist.basis.get_rotation_quaternion(), amount)


static func _turn(sk: Skeleton3D, bone: int, rotation: Quaternion, amount: float) -> void:
	var q := rotation.normalized()
	sk.set_bone_pose_rotation(bone, q if amount >= 1.0 else sk.get_bone_pose_rotation(bone).slerp(q, amount))
