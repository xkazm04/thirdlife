extends SceneTree
## Lane flight round 3 (19 Nov 2026): a PACK biped's figure on a ledge and a bar (selftest block 535), and a pack's
## chase camera under a bar. Headless, frames only. A TLBiped (feel walker, moves ledge + bar) in an ordinary scene: a
## floor, a wall whose top is 2.4 m up, a bar 2.8 m up marked with TLBiped.mark_bar; a TLChaseCam with avoid_space =
## the biped's own space. Prints `BIPEDGRIP ok=<bool> ...`:
##   hang    the rig plays `hang`, hangs 0.4 m below the body, its hands within 0.35 m of the lip (past the blend in);
##   mantle  he ends standing on top; the rig's transform is back to what it was before the grip within 15 frames;
##   bar     `swing` plays, the hands within 0.30 m of the bar through a pumped swing, the facing stays across the bar
##           (it turns less than 1 deg while he swings), upright again within 20 frames of the release;
##   camera  the chase camera does not avoid the marked bar: its lift and pull are those of the same run with nothing to
##           avoid (avoid_mask 0; the arm's own easing shows about 0.1 m of `avoid_pull` there), largest step under 0.6 m;
##           the control, the same bar left out of the `tl_bar` group (as before round 3), lifts or pulls well beyond it.

var _frames: int = 0


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var a: Dictionary = _run(true, 1)
		var b: Dictionary = _run(false, 1)
		var c: Dictionary = _run(true, 0)
		# the camera's own arm easing shows a small `avoid_pull` with nothing to avoid (mask 0): that is the baseline
		var cam_ok: bool = float(a["lift"]) <= float(c["lift"]) + 0.01 and float(a["pull"]) <= float(c["pull"]) + 0.001
		var ok: bool = bool(a["ok"]) and cam_ok and (float(b["lift"]) > float(c["lift"]) + 1.0 or float(b["pull"]) > float(c["pull"]) + 0.5)
		print("BIPEDGRIP ok=%s %s | camera with nothing to avoid (mask 0): cam_lift_deg=%.3f cam_pull_m=%.3f | control (bar not in tl_bar): cam_lift_deg=%.3f cam_pull_m=%.3f" % [ok, a["detail"], c["lift"], c["pull"], b["lift"], b["pull"]])
		quit(0 if ok else 1)
	return false


func _static(shape: Shape3D, at: Vector3, basis: Basis = Basis.IDENTITY) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = shape
	cs.transform = Transform3D(basis, at)
	body.add_child(cs)
	root.add_child(body)
	return body


func _hands(w: TLBiped) -> Vector3:
	var sk: Skeleton3D = w.rig.find_children("*", "Skeleton3D", true, false)[0]
	var p: Vector3 = Vector3.ZERO
	for b: String in ["RightHand", "LeftHand"]:
		p += sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b)).origin
	return p * 0.5


func _clip(w: TLBiped) -> String:
	return str(w.rig.get("clip"))


func _run(grouped: bool, mask: int) -> Dictionary:
	var made: Array = []
	var floor_shape: BoxShape3D = BoxShape3D.new()
	floor_shape.size = Vector3(100, 2, 100)
	made.append(_static(floor_shape, Vector3.DOWN))
	var wall: BoxShape3D = BoxShape3D.new()
	wall.size = Vector3(6, 2.4, 2)
	made.append(_static(wall, Vector3(0, 1.2, -3.0)))               # face at z = -2, top 2.4 m
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.height = 6.0
	cyl.radius = 0.05
	var bar: StaticBody3D = _static(cyl, Vector3(20, 2.8, 0), Basis(Vector3.BACK, PI / 2))   # along x
	made.append(bar)
	TLBiped.mark_bar(bar)
	if not grouped:
		bar.remove_from_group(&"tl_bar")
	var w: TLBiped = TLBiped.create({"feel": &"walker", "moves": [&"ledge", &"bar"]})
	root.add_child(w)
	w.collision_layer = 2                  # the player on a layer of its own, as a pack's camera leaves him out (mask 1)
	w.set_physics_process(false)
	var cam: TLChaseCam = TLChaseCam.new()
	root.add_child(cam)
	await_none()
	var base: Transform3D = w.rig.transform
	# ---- the ledge
	w.place(Vector3(0, 0.01, 1.0))
	var hang_n: int = 0
	var hang_clip: bool = false
	var hand_lip: float = 0.0
	var sink: float = 0.0
	var mantled_at: int = -1
	var upright_after: int = -1
	var was: StringName = &"ground"
	for f: int in 300:
		var m: StringName = w.walker_motion()
		if f == 8:
			w.jump()
		if m == &"hang" and hang_n == 40:
			w.jump()                                               # mantle
		w.move(Vector3.FORWARD if f < 45 and hang_n == 0 and m != &"hang" else Vector3.ZERO)   # moving into the wall would mantle at once
		w._physics_process(1.0 / 60.0)
		m = w.walker_motion()
		if m == &"hang":
			hang_n += 1
			hang_clip = hang_clip or _clip(w) == "hang"
			sink = w.rig.transform.origin.y - base.origin.y
			if hang_n > 10:
				var h: Vector3 = _hands(w)
				var e: Vector3 = w.ledge_top
				hand_lip = maxf(hand_lip, h.distance_to(Vector3(h.x, e.y, e.z)))
		if was == &"mantle" and m != &"mantle":
			mantled_at = f
		if mantled_at >= 0 and upright_after < 0 and w.rig.transform.is_equal_approx(base):
			upright_after = f - mantled_at
		was = m
	var on_top: bool = w.global_position.y > 2.35 and w.walker_motion() == &"ground"
	# ---- the bar (the camera behind him, its avoid space the biped's own)
	w.place(Vector3(20, 0.01, 0.25))
	cam.setup(w, {"avoid_space": PhysicsServer3D.body_get_space(w.get_rid()), "avoid_mask": mask, "distance": 8.5, "height": 3.6, "look_height": 1.7})
	cam.snap()
	var last: Vector3 = cam.global_position
	var lift: float = 0.0
	var pull: float = 0.0
	var step: float = 0.0
	var swing_clip: bool = false
	var hand_bar: float = 0.0
	var bar_n: int = 0
	var yaw0: float = INF
	var yaw_drift: float = 0.0
	var released_at: int = -1
	var up_release: int = -1
	var max_theta: float = 0.0
	for f: int in 480:
		var m2: StringName = w.walker_motion()
		if f == 3:
			w.jump()
		var mv: Vector3 = Vector3.ZERO
		if m2 == &"bar":
			var face: Vector3 = -w.global_transform.basis.z
			var tangent: Vector3 = w.bar_axis.cross(Vector3.DOWN)
			var sgn: float = 1.0 if tangent.dot(face) >= 0.0 else -1.0
			mv = face * (1.0 if w.bar_omega * sgn >= 0.0 else -1.0)
			if f == 400:
				w.jump()                                               # release
				released_at = f
		w.move(mv)
		w._physics_process(1.0 / 60.0)
		cam._physics_process(1.0 / 60.0)
		if w.walker_motion() == &"bar":
			bar_n += 1
			swing_clip = swing_clip or _clip(w) == "swing"
			max_theta = maxf(max_theta, absf(rad_to_deg(w.bar_theta)))
			if bar_n > 10:
				var hb: Vector3 = _hands(w)
				hand_bar = maxf(hand_bar, hb.distance_to(Vector3(hb.x, w.bar_point.y, w.bar_point.z)))
				if yaw0 == INF:
					yaw0 = w.rotation.y
				yaw_drift = maxf(yaw_drift, absf(rad_to_deg(angle_difference(yaw0, w.rotation.y))))
		if released_at >= 0 and f > released_at and up_release < 0 and w.rig.transform.is_equal_approx(base):
			up_release = f - released_at
		lift = maxf(lift, absf(cam.avoid_lift))
		pull = maxf(pull, cam.avoid_pull)
		step = maxf(step, cam.global_position.distance_to(last))
		last = cam.global_position
	cam.queue_free()
	w.queue_free()
	for n: Node in made:
		n.queue_free()
	var ok: bool = hang_clip and absf(sink + 0.4) < 0.001 and hand_lip <= 0.35 and on_top and upright_after >= 0 and upright_after <= 15 \
		and swing_clip and hand_bar <= 0.30 and max_theta >= 20.0 and yaw_drift < 1.0 and up_release >= 0 and up_release <= 20 \
		and step < 0.6
	return {"ok": ok, "lift": lift, "pull": pull, "detail": "hang_clip=%s sink_m=%.3f hands_to_lip_m=%.3f on_top=%s upright_after_mantle=%d swing_clip=%s hands_to_bar_m=%.3f max_theta_deg=%.1f facing_drift_deg=%.3f upright_after_release=%d cam_lift_deg=%.4f cam_pull_m=%.4f cam_step_m=%.3f" % [
		hang_clip, sink, hand_lip, on_top, upright_after, swing_clip, hand_bar, max_theta, yaw_drift, up_release, lift, pull, step]}


func await_none() -> void:
	pass
