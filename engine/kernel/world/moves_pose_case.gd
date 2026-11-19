extends SceneTree
## Lane flight round 2 (19 Nov 2026): the village visitor's FIGURE on a ledge and a bar (selftest block 531). Headless,
## ticks only. A visitor node with its rig in a small world space of its own: a floor, a wall whose top is 2.4 m up, a
## bar 2.4 m up. Prints one line `MOVESPOSE ok=<bool> ...`:
##   hang: the rig plays `hang`, faces the wall, hangs HANG_SINK below the capsule, its hands within 0.35 m of the edge (every tick past the blend in);
##   mantle: `mantle` plays, he ends standing on top and the rig is upright with no offset within 15 ticks after;
##   bar: `swing` plays, the hands stay within 0.30 m of the bar over the whole swing past the clip's 10-tick blend in;
##   release: upright again (no tilt, no offset) within 20 ticks; two runs give the same rig transforms.

const Space = preload("res://kernel/world/terrain/world_space.gd")
const Visitor = preload("res://kernel/world/visitor.gd")
const WALL_TOP: float = 2.4
const BAR_Y: float = 2.4
const BAR_Z: float = 30.0

var _frames: int = 0


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var a: Dictionary = _run()
		var b: Dictionary = _run()
		var same: bool = (a.get("trace", []) as Array) == (b.get("trace", []) as Array)
		var ok: bool = bool(a.get("ok", false)) and same
		print("MOVESPOSE ok=%s %s same=%s" % [ok, str(a.get("detail", a.get("error", ""))), same])
		quit(0 if ok else 1)
	return false


func _hand_mid(v: Node3D) -> Vector3:
	# the skeleton's own posed bones (a socket's BoneAttachment only follows them in a drawn frame)
	var sk: Skeleton3D = v.rig.find_children("*", "Skeleton3D", true, false)[0]
	var p: Vector3 = Vector3.ZERO
	for b: String in ["RightHand", "LeftHand"]:
		p += sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b)).origin
	return p * 0.5


func _upright(v: Node3D) -> bool:
	var t: Transform3D = v.rig.transform
	return t.origin.length() < 0.0005 and absf(t.basis.y.normalized().dot(Vector3.UP) - 1.0) < 0.00001


func _run() -> Dictionary:
	var land: Node3D = Node3D.new()
	root.add_child(land)
	var sp: RefCounted = Space.new()
	sp.add_box(Transform3D(Basis(), Vector3(0, -0.5, 0)), Vector3(80, 1, 80))
	sp.add_box(Transform3D(Basis(), Vector3(0, WALL_TOP * 0.5, -3.0)), Vector3(8, WALL_TOP, 2))    # face at z = -2
	var bar: CylinderShape3D = CylinderShape3D.new()
	bar.radius = 0.05
	bar.height = 4.0
	(sp.get("_keep") as Array).append(bar)
	sp.call("_copy_solid", bar, Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(0, BAR_Y, BAR_Z)), true)   # along x
	sp.call("finish")
	land.set_meta(&"tl_space", sp)
	var v: Node3D = Visitor.new()
	land.add_child(v)
	v.setup(Vector3(0, 0, 0), Vector3.FORWARD)
	v.steer_on()
	var trace: Array = []
	var t: int = 0
	var clip_hang: bool = false
	var hang_ok: bool = false
	var hang_hand: float = 0.0
	var hang_n: int = 0
	var hang_sink: float = 0.0
	var mantle_seen: bool = false
	var up_after_mantle: int = -1
	var end_mantle_t: int = -1
	# 1. run at the wall and jump: catch, hang 30 ticks, mantle (Space)
	var mode_was: String = "ground"
	for i: int in 260:
		t += 1
		var w: Vector3 = Vector3(0, 0, -6.0) if i < 40 else Vector3.ZERO
		var jump: bool = i == 14
		var mantle_now: bool = v.mode == "hang" and i > 0 and not mantle_seen and _hang_ticks(trace) >= 30
		v.wish(w, jump or mantle_now, false)
		v.step(v.feet, t)
		trace.append([v.mode, v.rig.transform])
		if v.mode == "hang":
			clip_hang = clip_hang or str(v.rig.get("clip")) == "hang"
			hang_sink = v.rig.transform.origin.y
			var e: Vector3 = v.ledge_top
			var h: Vector3 = _hand_mid(v)
			hang_n += 1
			if hang_n > 10:                             # past the clip's blend in
				hang_hand = maxf(hang_hand, h.distance_to(Vector3(h.x, e.y, e.z)))
			if OS.has_environment("MOVESPOSE_DEBUG") and i % 10 == 0:
				print("dbg hands=%s edge=%s feet=%s" % [h, e, v.feet])
			var facing: Vector3 = -(v.rig.global_transform.basis.z)
			hang_ok = facing.dot(-v.wall_normal) > 0.98
		if v.mode == "mantle":
			mantle_seen = mantle_seen or str(v.rig.get("clip")) == "mantle"
		if mode_was == "mantle" and v.mode != "mantle":
			end_mantle_t = t
		if end_mantle_t > 0 and up_after_mantle < 0 and _upright(v):
			up_after_mantle = t - end_mantle_t
		mode_was = v.mode
	var on_top: bool = v.feet.y > WALL_TOP - 0.05 and v.mode == "ground"
	# 2. the bar: put him under it, jump, pump forward a while, release
	v.put(Vector3(0, 0, BAR_Z + 0.05), 0.0)
	var swing_clip: bool = false
	var bar_hand: float = 0.0
	var max_theta: float = 0.0
	var caught: bool = false
	var released_t: int = -1
	var bar_ticks: int = 0
	var up_after_release: int = -1
	for i: int in 420:
		t += 1
		var w2: Vector3 = Vector3.ZERO
		if v.mode == "bar" and i < 300:
			w2 = Vector3(0, 0, -4.5 if v.bar_omega >= 0.0 else 4.5)
		var rel: bool = v.mode == "bar" and i >= 300 and released_t < 0
		v.wish(w2, i == 4 or rel, false)
		v.step(v.feet, t)
		trace.append([v.mode, v.rig.transform])
		if v.mode == "bar":
			bar_ticks += 1
		if v.mode == "bar" and bar_ticks > 10:          # past the clip's blend in (0.15 s)
			caught = true
			swing_clip = swing_clip or str(v.rig.get("clip")) == "swing"
			bar_hand = maxf(bar_hand, _hand_mid(v).distance_to(Vector3(_hand_mid(v).x, v.bar_point.y, v.bar_point.z)))
			max_theta = maxf(max_theta, absf(rad_to_deg(v.bar_theta)))
			if OS.has_environment("MOVESPOSE_DEBUG") and i % 15 == 0:
				print("dbgbar i=%d theta=%.1f hands=%s bar=%s feet=%s axis=%s" % [i, rad_to_deg(v.bar_theta), _hand_mid(v), v.bar_point, v.feet, v.bar_axis])
		if rel:
			released_t = t
		if released_t > 0 and t > released_t and up_after_release < 0 and _upright(v):
			up_after_release = t - released_t
	land.queue_free()
	var ok: bool = clip_hang and hang_ok and absf(hang_sink + v.HANG_SINK) < 0.001 and hang_hand <= 0.35 and mantle_seen and on_top \
		and up_after_mantle >= 0 and up_after_mantle <= 15 and caught and swing_clip and bar_hand <= 0.30 and max_theta >= 20.0 \
		and up_after_release >= 0 and up_after_release <= 20
	return {"ok": ok, "trace": trace, "detail": "hang_clip=%s faces_wall=%s sink_m=%.3f hands_to_edge_m=%.3f mantle_clip=%s on_top=%s upright_after_mantle=%d swing_clip=%s hands_to_bar_max_m=%.3f max_theta_deg=%.1f upright_after_release=%d" % [
		clip_hang, hang_ok, hang_sink, hang_hand, mantle_seen, on_top, up_after_mantle, swing_clip, bar_hand, max_theta, up_after_release]}


func _hang_ticks(trace: Array) -> int:
	var n: int = 0
	for i: int in range(trace.size() - 1, -1, -1):
		if str((trace[i] as Array)[0]) != "hang":
			break
		n += 1
	return n
