extends SceneTree
## Regression for a material/mesh swap that keeps the classic rig contract.
## Count actual triangle indices, including hidden tools. Measure the palm at
## the socket offset, because the wrist bone is several centimetres behind it.
var failures := PackedStringArray()
var grip_degrees := 0.0
const FORM = preload("res://rigs/biped/clay_form.gd")


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


func _mesh(rig: Node3D) -> Mesh:
	return (rig.get_node("Model/Skeleton3D/Mesh") as MeshInstance3D).mesh


func _drawn_tris(rig: Node3D) -> int:
	var count := 0
	for mi: MeshInstance3D in rig.find_children("*","MeshInstance3D",true,false):
		var mesh := mi.mesh as ArrayMesh
		for surface in mesh.get_surface_count():
			var indices := mesh.surface_get_array_index_len(surface)
			count += (indices if indices > 0 else mesh.surface_get_array_len(surface)) / 3
	return count


func _has_coat(rig: Node3D) -> bool:
	var uv: PackedVector2Array = _mesh(rig).surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	for point in uv:
		if point.y == FORM.Finish.JACKET:
			return true
	return false


func _run() -> void:
	TLStyle.load_style(TLStyle.DEFAULT_PATH)
	var classic: TLRigNode = TLRigs.build("biped", {"backpack":false})
	var clips := classic.clips()
	var skeleton: Skeleton3D = classic.get_node("Model/Skeleton3D")
	var layout := skeleton.get_concatenated_bone_names()
	var shell := _mesh(classic).get_meta(&"tl_hash") as String
	_expect(not classic.has_method("_fit_grip"), "classic routed to the clay rig")
	classic.free()
	TLStyle.load_style("res://style/style_diorama.json")
	var count := 0
	var min_tris := 12000
	var max_tris := 0
	for mode: String in ["walk","skate"]:
		for pack: bool in [false,true]:
			for gear: String in ["auto","none","helmet"]:
				var p := {"mode":mode,"backpack":pack,"headgear":gear}
				var rig: TLRigNode = TLRigs.build("biped",p)
				var m := rig.metrics()
				var sk: Skeleton3D = rig.get_node("Model/Skeleton3D")
				var tris := _drawn_tris(rig)
				_expect(m.height == 2.0 and m.radius == .3, "capsule metrics %s" % p)
				_expect(sk.get_concatenated_bone_names() == layout and sk.get_bone_count() == 29, "skeleton %s" % p)
				_expect(rig.clips() == clips and rig.socket(&"back") != null, "clips/sockets %s" % p)
				_expect(_has_coat(rig) == (mode == "walk"), "headgear changed the uniform %s" % p)
				_expect(tris == m.triangles and tris > 0 and tris <= 12000, "triangle count %s: %d/%d" % [p,tris,m.triangles])
				_expect(_mesh(rig).get_meta(&"tl_hash") != shell, "diorama reused classic shell")
				min_tris = mini(min_tris,tris)
				max_tris = maxi(max_tris,tris)
				rig.free()
				count += 1
	var rig: TLRigNode = TLRigs.build("biped", {"backpack":false})
	root.add_child(rig)
	var red := _mesh(rig).get_meta(&"tl_hash") as String
	rig.set_param(&"colors", {"top":"flag_b"})
	var blue := _mesh(rig).get_meta(&"tl_hash") as String
	rig.set_param(&"colors", {})
	_expect(blue != red and _mesh(rig).get_meta(&"tl_hash") == red, "runtime palette rebuild")
	var hang := _grip_error(rig, &"hang", Vector3(0,2.0,-.31))
	var bar := _grip_error(rig, &"swing", Vector3(0,2.20,0))
	var clearance := _channel_radius(rig)
	_expect(grip_degrees < .1 and clearance.x < .015 and clearance.y >= .050,
		"hand opening did not fit the 5 cm support")
	var stick := _stick_error(rig)
	_expect(hang < .012 and bar < .012, "palm missed the support")
	_expect(stick < .025, "off hand missed the shaft")
	rig.free()
	var motion := _body_motion()
	_expect(motion.walk_min < -4.0 and motion.walk_max > 4.0, "weight did not cross between the planted feet")
	_expect(motion.kick > 12.0 and motion.bank > 15.0, "flight kick or bank response lost")
	_expect(motion.rest > .14 and motion.pocket < .06, "idle hand did not reach the welt")
	var soft := _landing(1.5)
	var hard := _landing(12.0)
	_expect(soft.depth.is_zero_approx() and hard.depth.x > .010 and hard.depth.y > .022,
		"accessory response did not follow the landing speed")
	_expect(hard.peak.x < hard.peak.y and hard.settled, "curl and collar did not settle in order")
	var leads := []
	for takeoff in [64,72,80,88]:
		leads.append(_jump_lead(takeoff))
	_expect(leads.has("L") and leads.has("R") and not leads.has("mismatch"), "takeoff changed the leading knee")
	print("CLAY ok=%s wardrobes=%d triangles=%d..%d bones=29 clips=%d height=2.0 radius=0.3 palm_max_m hang=%.5f bar=%.5f stick=%.5f jump_leads=%s pocket_rest_hold_m=%.3f/%.3f chest_roll_deg=%.1f..%.1f launch_knee_deg=%.1f bank_arm_deg=%.1f errors=%s" %
		[failures.is_empty(),count,min_tris,max_tris,clips.size(),hang,bar,stick,leads,motion.rest,motion.pocket,motion.walk_min,motion.walk_max,motion.kick,motion.bank,failures])
	print("CLAY_CONTACT channel_radius_m=%.5f..%.5f max_axis_error_deg=%.5f heavy_travel_m=%s peak_ticks=%s soft_travel_m=%s settled=%s" %
		[clearance.x,clearance.y,grip_degrees,hard.depth,hard.peak,soft.depth,hard.settled])
	quit(0 if failures.is_empty() else 1)


func _palm(sk: Skeleton3D, side: String) -> Transform3D:
	var wrist := sk.get_bone_global_pose(sk.find_bone(side + "Hand"))
	return wrist.translated_local(Vector3(0,-.075,-.03))


func _body_motion() -> Dictionary:
	var rig := TLRigs.build("biped", {"backpack":false}) as TLRigNode
	root.add_child(rig)
	var sk: Skeleton3D = rig.get_node("Model/Skeleton3D")
	var chest := sk.find_bone("Chest")
	var knee := sk.find_bone("LeftLowerLeg")
	var sleeve := sk.find_bone("LeftUpperArm")
	var low := 0.0
	var high := 0.0
	var rest := 0.0
	var pocket := 0.0
	var spine := sk.find_bone("Spine")
	# Independent landmark at the upper end of the right welt on the mesh.
	var welt := sk.get_bone_global_rest(spine).affine_inverse() * Vector3(.194,1.034,-.127)
	for f in range(1,131):
		rig.set_locomotion(Vector3.ZERO,true)
		rig.tick(f)
		if f == 25 or f == 130:
			var distance := _palm(sk,"Right").origin.distance_to(sk.get_bone_global_pose(spine) * welt)
			if f == 25:
				rest = distance
			else:
				pocket = distance
	for f in range(1,181):
		rig.set_locomotion(Vector3(0,0,-1.8),true)
		rig.tick(f + 130)
		var roll := rad_to_deg(sk.get_bone_pose_rotation(chest).get_euler().z)
		low = minf(low,roll)
		high = maxf(high,roll)
	rig.play(&"fly",0.0)
	var launch := 0.0
	var cruise := 0.0
	var arm := 0.0
	# Compare identical points of the breathing loop, 96 ticks apart.
	for f in range(1,207):
		rig.rotation.z = deg_to_rad(28.0 if f <= 110 else -28.0)
		rig.set_locomotion(Vector3(0,0,-20),false)
		rig.tick(f + 310)
		if f == 14:
			launch = rad_to_deg(sk.get_bone_pose_rotation(knee).get_euler().x)
		if f == 110:
			cruise = rad_to_deg(sk.get_bone_pose_rotation(knee).get_euler().x)
			arm = rad_to_deg(sk.get_bone_pose_rotation(sleeve).get_euler().z)
	var bank_delta := rad_to_deg(sk.get_bone_pose_rotation(sleeve).get_euler().z) - arm
	rig.free()
	return {"walk_min":low,"walk_max":high,"kick":cruise-launch,"bank":bank_delta,"rest":rest,"pocket":pocket}


func _grip_error(rig: TLRigNode, clip: StringName, center: Vector3) -> float:
	rig.position = Vector3(2,3,4)
	rig.scale = Vector3.ONE * 1.35
	var sk: Skeleton3D = rig.get_node("Model/Skeleton3D")
	rig.play(clip,.10)
	var worst := 0.0
	for tick in range(1,91):
		rig.rotation = Vector3(.9*sin(tick*.08) if clip == &"swing" else 0.0,.7,0.0)
		var point := rig.to_global(center)
		var axis := rig.global_transform.basis.x.normalized()
		rig.tick(tick)
		rig.call("_fit_grip",point,axis,0.0)
		if tick >= 10:
			for side: String in ["Left","Right"]:
				var palm := sk.to_global(_palm(sk, side).origin)
				var target := point + axis * (-.285 if side == "Left" else .285) * rig.scale.x
				worst = maxf(worst,palm.distance_to(target))
				var hand := sk.get_bone_global_pose(sk.find_bone(side+"Hand"))
				var channel := (sk.global_basis * hand.basis * Vector3(.51,0,.86 if side=="Left" else -.86)).normalized()
				grip_degrees = maxf(grip_degrees,rad_to_deg(atan2(channel.cross(axis).length(),absf(channel.dot(axis)))))
	var mesh := rig.get_node("Model/Skeleton3D/Mesh") as MeshInstance3D
	_expect(is_equal_approx(mesh.get_blend_shape_value(0),1.0),"hand grip did not engage")
	return worst


## Project the actual hand triangles perpendicular to the bar. The nearest
## projected face sets the largest cylinder that fits through both hands.
func _channel_radius(rig: Node3D) -> Vector2:
	var mesh := _mesh(rig)
	var arrays := mesh.surface_get_arrays(0)
	var shapes := mesh.surface_get_blend_shape_arrays(0)
	if shapes.size() != 1:
		return Vector2.ZERO
	var sk := rig.get_node("Model/Skeleton3D") as Skeleton3D
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var result := Vector2(INF,INF)
	for side: float in [-1.0,1.0]:
		var hand := sk.find_bone("LeftHand" if side < 0.0 else "RightHand")
		var center := sk.get_bone_global_rest(hand) * Vector3(0,-.075,-.03)
		var width := Vector3(.86*side,0,.51).normalized()
		for mode in 2:
			var positions: PackedVector3Array = (arrays if mode == 0 else shapes[0])[Mesh.ARRAY_VERTEX]
			for i in range(0,indices.size(),3):
				if bones[indices[i]*4] != hand:
					continue
				var corners := PackedVector2Array()
				for j in 3:
					var point := positions[indices[i+j]]-center
					corners.append(Vector2(point.dot(width),point.y))
				if absf((corners[1]-corners[0]).cross(corners[2]-corners[0])) > 1e-10 and Geometry2D.point_is_inside_triangle(Vector2.ZERO,corners[0],corners[1],corners[2]):
					result[mode] = 0.0
				for j in 3:
					var a := corners[j]
					var edge := corners[(j+1)%3]-a
					var t := clampf(-a.dot(edge)/maxf(edge.length_squared(),1e-12),0.0,1.0)
					result[mode] = minf(result[mode],(a+edge*t).length())
	return result


func _landing(fall_speed: float) -> Dictionary:
	var rig := TLRigs.build("biped",{}) as TLRigNode
	root.add_child(rig)
	var sk := rig.get_node("Model/Skeleton3D") as Skeleton3D
	var joints := [sk.find_bone("Hair"),sk.find_bone("Backpack")]
	var depth := Vector2.ZERO
	var peak := Vector2i.ZERO
	var travel := Vector2.ZERO
	rig.set_locomotion(Vector3(0,-fall_speed,-4),false)
	rig.tick(1)
	rig.play(&"land")
	for t in range(1,61):
		rig.set_locomotion(Vector3(0,0,-4),true)
		rig.tick(1+t)
		for i in 2:
			travel[i] = sk.get_bone_rest(joints[i]).origin.y - sk.get_bone_pose_position(joints[i]).y
			if travel[i] > depth[i]:
				depth[i] = travel[i]
				peak[i] = t
	rig.free()
	return {"depth":depth,"peak":peak,"settled":travel.is_zero_approx()}


func _stick_error(rig: TLRigNode) -> float:
	rig.transform = Transform3D.IDENTITY
	rig.play(&"",0.0)
	rig.set_param(&"mode",&"skate")
	var sk: Skeleton3D = rig.get_node("Model/Skeleton3D")
	var stick: Node3D = rig.socket(&"hand_r").get_node("Stick")
	var worst := 0.0
	for f in range(1,121):
		rig.set_locomotion(Vector3(0,0,-5.0),true)
		rig.tick(f)
		var right := _palm(sk,"Right")
		var shaft := (right.basis * stick.basis.y).normalized()
		var offset := _palm(sk,"Left").origin - right.origin
		worst = maxf(worst,(offset - shaft * clampf(offset.dot(shaft),.16,.5)).length())
	return worst


## Leave the ground at four different points in the stride. The boot leading
## at takeoff should be the knee driven up at the end of the push.
func _jump_lead(takeoff: int) -> String:
	var rig: TLRigNode = TLRigs.build("biped", {"backpack":false})
	root.add_child(rig)
	var sk: Skeleton3D = rig.get_node("Model/Skeleton3D")
	for f in range(1,takeoff):
		rig.set_locomotion(Vector3(0,0,-4.5),true)
		rig.tick(f)
	var left := sk.get_bone_global_pose(sk.find_bone("LeftFoot")).origin
	var right := sk.get_bone_global_pose(sk.find_bone("RightFoot")).origin
	var left_leads := left.z <= right.z
	rig.play(&"jump")
	for f in range(takeoff,takeoff+17):
		rig.set_locomotion(Vector3(0,8.0-(f-takeoff)*.4,-4.5),false)
		rig.tick(f)
	var left_thigh := sk.get_bone_pose_rotation(sk.find_bone("LeftUpperLeg")).get_euler().x
	var right_thigh := sk.get_bone_pose_rotation(sk.find_bone("RightUpperLeg")).get_euler().x
	rig.free()
	if left_leads != (left_thigh > right_thigh):
		return "mismatch"
	return "L" if left_leads else "R"
