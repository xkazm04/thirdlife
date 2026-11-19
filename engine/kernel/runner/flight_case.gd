extends SceneTree
## Exercise the same compact village, copied pack shapes and chase camera as a live visit.
const Landscape = preload("res://kernel/world/landscape.gd")
const Pack = preload("res://kernel/world/pack.gd")
const Space = preload("res://kernel/world/terrain/world_space.gd")
const Visitor = preload("res://kernel/world/visitor.gd")
const Visit = preload("res://kernel/runner/visit.gd")
const ROAD := Vector3(-60, 0, 2)
const CRUISE := 45.0
class Village extends Node3D:
	var walk: Dictionary
	var packs: Array = []
	var tick := 0
	var sched := preload("res://kernel/world/tiers.gd").new()
	var player_live := true
	var player_pos := Vector3.ZERO
class View extends Node3D:
	var world := Village.new()
	var plots: Array = []
	var radii: Array = []
	var visitor := Visitor.new()
	var stage := -1

var view := View.new()
var land := Node3D.new()
var sp: Space
var feet := ROAD
var capsule := PhysicsShapeQueryParameters3D.new()
var crown := PhysicsPointQueryParameters3D.new()
var failed := false
var own_ground := []

func _initialize() -> void:
	physics_frame.connect(_run, CONNECT_ONE_SHOT)

func _line(label: String, ok: bool, detail: String) -> void:
	print("FLIGHT %s %s %s" % [label, "PASS" if ok else "FAIL", detail])
	failed = failed or not ok

func _build() -> bool:
	root.add_child(view)
	view.add_child(view.world)
	view.add_child(land)
	var walk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://kernel/world/walks/wf_feel.json"))
	view.world.walk = walk
	for plot: Dictionary in walk.plots:
		var holder := Pack.new()
		view.world.add_child(holder)
		var dir := ("res://kernel/examples/" if str(plot.pack).begins_with("ex_") else "res://seeds/") + str(plot.pack)
		if not holder.load_pack(dir, {"seed": plot.seed, "mode": "smoke"}):
			push_error(str(holder.load_errors))
			return false
		view.world.packs.append(holder)
		var radius := float(plot.radius)
		var rim := preload("res://kernel/world/draw/draw_base.gd").edge_height(holder, radius)
		own_ground.append(is_finite(rim))
		var o: Array = plot.origin
		var y := float(o[1]) - (rim if is_finite(rim) else 0.0)
		view.plots.append(Transform3D(Basis(), Vector3(o[0], y, o[2])))
		view.radii.append(radius)
	var cfg: Dictionary = walk.landscape.duplicate(true)
	cfg.road = walk.road
	cfg.edges_now = true
	TLStyle.set_headless(false)
	Landscape.build(land, view.plots, view.radii, own_ground, cfg)
	TLStyle.set_headless(true)
	sp = land.get_meta(&"tl_space")
	land.add_child(view.visitor)
	view.visitor.setup(ROAD)
	view.visitor.steer_on()
	var shape := CapsuleShape3D.new()
	shape.radius = Space.RADIUS - 0.01
	shape.height = Space.HEIGHT - 0.02
	capsule.shape = shape
	capsule.exclude = [sp.body]
	capsule.collision_mask = 5
	crown.collision_mask = 4
	return sp.stats.pack_shapes > 0 and not sp.drawn_crowns.is_empty()

func _run() -> void:
	if not _build():
		quit(2)
		return
	if OS.get_cmdline_user_args() == PackedStringArray(["pose"]):
		_pose()
	else:
		_speed()
		_ceiling()
		_land()
		_collide()
		_sweep()
		_gate()
	for holder: Node in view.world.packs:
		holder.release_space()
	view.free()
	print("FLIGHT done %s" % ("fail" if failed else "pass"))     # the run completed; each case is judged by its own line
	quit(1 if failed else 0)

func _road() -> void:
	feet = ROAD
	feet.y = sp.ground_at(feet.x, feet.z, 100)
	sp.place(feet)
	sp.rest()

func _tick(wish := Vector3.ZERO, climb := 0.0, toggle := false) -> Dictionary:
	var result := sp.drive(feet, wish, false, false, toggle, climb)
	feet = result.pos
	return result

func _overlap(at: Vector3) -> bool:
	capsule.transform.origin = at + Vector3.UP * Space.HEIGHT * 0.5
	return not PhysicsServer3D.space_get_direct_state(sp.space).intersect_shape(capsule, 1).is_empty()

func _speed() -> void:
	_road()
	var start := Vector3.ZERO
	for t in 180:
		if t == 120:
			start = feet
		_tick(Vector3.RIGHT * 9)
	var run := feet.x - start.x
	_road()
	var initial := feet.y
	for t in 60:
		_tick(Vector3.ZERO, 0, t == 0)
	var lift := feet.y - initial
	var at95 := -1
	var max_dv := 0.0
	var prev := 0.0
	for t in 220:
		if t == 160:
			start = feet
		var v: Vector3 = _tick(Vector3.RIGHT * CRUISE).vel
		var speed := Vector2(v.x, v.z).length()
		max_dv = maxf(max_dv, absf(speed - prev))
		if at95 < 0 and speed >= CRUISE * 0.95:
			at95 = t + 1
		prev = speed
	var cruise := feet.x - start.x
	var ratio := cruise / run
	_line("ratio", absf(ratio - 5) <= 0.1, "run=%.3f cruise=%.3f ratio=%.3f" % [run, cruise, ratio])
	_tick(Vector3.FORWARD * CRUISE)
	var left_turn := rad_to_deg(float(sp._mover.fly_turn))
	_tick(Vector3.BACK * CRUISE)
	var right_turn := rad_to_deg(float(sp._mover.fly_turn))
	var stop := 0
	while stop < 140 and prev > 0.001:
		prev = (_tick().vel as Vector3).length()
		stop += 1
	_line("accel", absi(at95 - 60) <= 6 and max_dv <= 1.6 and absf(lift - 2.5) < 0.1 and absi(stop - 90) <= 15 and absf(left_turn - 140) < 0.1 and absf(right_turn + 140) < 0.1,
		"ticks95=%d max_dv=%.3f lift_m=%.3f glide_ticks=%d turns_deg_s=%.1f/%.1f" % [at95, max_dv, lift, stop, left_turn, right_turn])

func _ceiling() -> void:
	_road()
	var height := 0.0
	var peak := 0.0
	for t in 1800:
		_tick(Vector3.ZERO, 1, t == 0)
		height = feet.y - sp.ground_at(feet.x, feet.z, feet.y + 0.01)
		peak = maxf(peak, height)
	_line("ceiling", height >= 119 and peak <= 120.05, "ticks=1800 height=%.3f max=%.3f" % [height, peak])

func _land() -> void:
	_road()
	var first := _tick(Vector3.ZERO, 0, true)
	var mask := PhysicsServer3D.body_get_collision_mask(sp.body)
	for t in 60:
		_tick()
	var res: Dictionary
	for t in 90:
		res = _tick(Vector3.ZERO, -1)
		if res.mode != "fly":
			break
	var landed: bool = res.events.has("fly_land") and res.mode == "ground"
	var overlaps := _overlap(feet)
	var restore := PhysicsServer3D.body_get_collision_mask(sp.body)
	for t in 60:
		_tick(Vector3.ZERO, 0, t == 0)
	var end := _tick(Vector3.ZERO, 0, true)
	var airborne_y := feet.y
	var fell := false
	for t in 90:
		res = _tick()
		fell = fell or (res.mode == "air" and feet.y < airborne_y - 0.1)
		if res.events.has("land"):
			break
	var final_mode: String = res.mode
	var crown_contact := _descend_onto_crown()
	var ok: bool = crown_contact and first.events.has("fly_start") and landed and not overlaps and mask == 5 and restore == 1 and end.events.has("fly_end") and end.mode == "air" and fell and res.events.has("land")
	_line("land", ok, "fly_land=%s overlap=%s masks=%d/%d fly_end=%s fell=%s final=%s crown_stays_flying=%s" % [landed, overlaps, mask, restore, end.events, fell, final_mode, crown_contact])

func _descend_onto_crown() -> bool:
	var state := PhysicsServer3D.space_get_direct_state(sp.space)
	for rid: RID in sp.drawn_crowns:
		var base: Vector3 = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM).origin
		var ray := PhysicsRayQueryParameters3D.create(base + Vector3.UP * 40, base, 4)
		var peak := state.intersect_ray(ray)
		if peak.is_empty():
			continue
		_launch(peak.position + Vector3.UP, Vector3.ZERO)
		for t in 60:
			var res := _tick(Vector3.ZERO, -1)
			if res.blocked:
				var hit: RID = sp.last_hit.rid
				return PhysicsServer3D.body_get_collision_layer(hit) == 4 and res.mode == "fly" and not res.events.has("fly_land")
	return false

## Begin an independent airborne leg with a level, fully developed cruise.
func _launch(at: Vector3, dir: Vector3) -> void:
	sp.rest()
	sp.place(at)
	feet = at
	_tick()   # Unsupported feet enter air before deploying the wings.
	_tick(Vector3.ZERO, 0, true)
	sp._mover.vel = dir * CRUISE

func _impact(start: Vector3, finish: Vector3, tag: String) -> float:
	var dir := start.direction_to(finish)
	var q := PhysicsRayQueryParameters3D.create(start, finish, 1)
	q.exclude = [sp.body]
	var ray := PhysicsServer3D.space_get_direct_state(sp.space).intersect_ray(q)
	if ray.is_empty() or sp._tags.get(ray.rid) != tag:
		return -INF
	var plane: Vector3 = ray.position
	_launch(start, dir)
	for t in ceili(start.distance_to(finish) / 0.75) + 2:
		var r := _tick(dir * CRUISE)
		if r.blocked:
			if sp.last_hit.get("tag") != tag or sp.last_hit.get("rid") != ray.rid or _overlap(feet):
				return -INF
			# Keep thrust on past the unimpeded crossing time. A slope can carry
			# the capsule upwards, so measure on the normal of the struck face.
			var n: Vector3 = ray.normal
			var gap := (feet + Vector3.UP * Space.RADIUS - plane).dot(n)
			for after_hit in 12:
				_tick(dir * CRUISE)
				if _overlap(feet):
					return -INF
				gap = minf(gap, (feet + Vector3.UP * Space.RADIUS - plane).dot(n))
			return gap
	return -INF

func _collide() -> void:
	var y := sp.ground_at(0, -195, 90) + 2
	var bluff := _impact(Vector3(0, y, -195), Vector3(0, y, -224), "terrain")
	# A trunk FOUND in the space (lane flight round 2): the scatter moves trees when the terrain changes (the blend lane's
	# regrade did, 19 Nov), so no fixed position. Trunks are the tree-tagged cylinders on layer 1 (crowns are layer 4); in a
	# fixed order (nearest the reference point first), the first one a cruise can be aimed at with a clear line counts.
	var trunk := -INF
	var tried := 0
	var picked := Vector3.INF
	for c: Vector3 in _trunks(Vector3(0, 0, 0)):
		if tried >= 40:
			break
		tried += 1
		for side: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var from := c + side * 8.0
			var gy := sp.ground_at(from.x, from.z, c.y + 40.0)
			if is_nan(gy):
				continue
			# fly in low (0.25 m over the trunk's foot): the capsule's top stays under the crown, so the trunk is what it meets
			var at := Vector3(from.x, c.y - 2.0 + 0.25, from.z)
			var aim := Vector3(c.x, at.y, c.z)
			if gy > at.y - 0.05:
				continue                                   # the ground at the start is higher: no clear low line
			trunk = _impact(at, aim, "tree")
			if trunk > 0:
				picked = c
				break
		if trunk > 0:
			break
	# The example walker's room has a copied wall at x=6, extending well over capsule height.
	var o: Vector3 = view.plots[0].origin
	var wall := _impact(o + Vector3(0, 1, 4), o + Vector3(9, 1, 4), "pack 0")
	_line("collide", bluff > 0 and trunk > 0 and wall > 0, "cruise=45 near_side_m bluff=%.3f trunk=%.3f wall=%.3f trunk_at=[%.1f,%.1f] trunks_tried=%d" % [bluff, trunk, wall, picked.x, picked.z, tried])


## Centres of the tree trunks of the space (tree-tagged cylinders on layer 1), nearest `ref` first, ties by position.
func _trunks(ref: Vector3) -> Array:
	var out: Array = []
	for b: Variant in sp._bodies:
		var rid: RID = b
		if str(sp._tags.get(rid, "")) != "tree" or PhysicsServer3D.body_get_collision_layer(rid) & 1 == 0 or PhysicsServer3D.body_get_shape_count(rid) == 0:
			continue
		if PhysicsServer3D.shape_get_type(PhysicsServer3D.body_get_shape(rid, 0)) != PhysicsServer3D.SHAPE_CYLINDER:
			continue
		# the trunk's place is in its shape's transform (world_space `_static` adds the shape at it; the body sits at 0)
		out.append(((PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM) as Transform3D) * PhysicsServer3D.body_get_shape_transform(rid, 0)).origin)
	out.sort_custom(func(a: Vector3, b2: Vector3) -> bool:
		var da := a.distance_squared_to(ref)
		var db := b2.distance_squared_to(ref)
		return da < db if da != db else (a.x < b2.x if a.x != b2.x else a.z < b2.z))
	return out

func _sweep() -> void:
	var v := view.visitor
	var terrain: RefCounted = land.get_meta(&"tl_terrain")
	var state := PhysicsServer3D.space_get_direct_state(sp.space)
	var ticks := 0
	var blocked := 0
	var overlaps := 0
	var leaves := 0
	var under := 0
	var max_yaw := 0.0
	var max_pitch := 0.0
	var longest_arm := 0.0
	var pitch_drop := 0.0
	var camera_distance := v._cam_dist
	var flying_ticks := 0
	var cruises := 0
	var low := 0
	for leg in 80:
		var a := TAU * (leg % 16) / 16
		var dir := Vector3(sin(a), 0, cos(a))
		var at := Vector3(-dir.x * (55 + 50 * (leg / 16)), 0, -dir.z * (38 + 45 * (leg / 16)))
		if leg == 0:
			at = Vector3(60, 0, -148)
			dir = Vector3.FORWARD
		elif leg == 1:
			at = view.plots[0].origin
			dir = Vector3.RIGHT
		var h := float(terrain.call("gy", at.x, at.z))
		at.y = h + 2 + (leg % 5) * 4
		while _overlap(at):
			at.y += 0.5
		v.put(at, atan2(-dir.x, -dir.z))
		v.position = at
		v.feet = at
		v._last = at
		v.cam.snap()
		var prev := v.cam.position - (at + Vector3.UP * v.cam.look_height)
		for t in 260:
			var desired := dir.rotated(Vector3.UP, 0.85 * maxf(0, sin(TAU * (t - 100) / 220.0)))
			var altitude := v.feet.y - float(terrain.call("gy", v.feet.x, v.feet.z))
			var wanted := 2.0 + (leg % 5) * 4 + 3.0 * (1 - cos(t * TAU / 190.0))
			v.wish(desired * CRUISE, false, false, not v.flying, clampf((wanted - altitude) * 0.4, -1, 1))
			var hits := sp.blocked_ticks
			v.step(v.feet, t)
			v.cam._physics_process(1.0 / 60.0)
			var c := v.cam.position
			crown.position = c
			ticks += 1
			flying_ticks += int(v.flying)
			cruises += int(v.speed >= 42.75)
			low += int(altitude >= 2 and altitude <= 25)
			blocked += int(sp.blocked_ticks > hits)
			overlaps += int(_overlap(v.feet))
			leaves += int(not state.intersect_point(crown, 1).is_empty())
			under += int(c.y < float(terrain.call("gy", c.x, c.z)) - 0.01)
			var arm := c - (v.feet + Vector3.UP * v.cam.look_height)
			max_yaw = maxf(max_yaw, absf(rad_to_deg(angle_difference(atan2(prev.x, prev.z), atan2(arm.x, arm.z)))))
			max_pitch = maxf(max_pitch, absf(rad_to_deg(asin(arm.normalized().y) - asin(prev.normalized().y))))
			if arm.length() > longest_arm:
				longest_arm = arm.length()
				pitch_drop = rad_to_deg(v.look_pitch - asin(arm.normalized().y))
			prev = arm
	var arm_ratio := longest_arm / camera_distance
	var ok := absf(arm_ratio - 1.8) < 0.03 and absf(pitch_drop - 6.0) < 0.3 and flying_ticks >= 20000 and cruises > 5000 and low > 15000 and blocked > 0 and overlaps == 0 and leaves == 0 and under == 0 and max_yaw < 3 and max_pitch < 3
	_line("sweep", ok, "ticks=%d flying=%d headings=16 cruise_ticks=%d low_ticks=%d blocked=%d overlaps=%d cam_crown=%d cam_under=%d max_yaw_deg=%.3f max_pitch_deg=%.3f arm_ratio=%.3f pitch_drop_deg=%.3f" % [ticks, flying_ticks, cruises, low, blocked, overlaps, leaves, under, max_yaw, max_pitch, arm_ratio, pitch_drop])

func _gate() -> void:
	var i := own_ground.find(true)
	if i < 0:
		_line("gate", false, "missing plot ground")
		return
	var visit := Visit.new()
	view.add_child(visit)
	visit.setup(view, {})
	var v := view.visitor
	var o: Vector3 = view.plots[i].origin
	v.put(o, 0)
	v.feet = o + Vector3.UP * 30
	v.position = v.feet
	sp.place(v.feet)
	var high := true
	var previous := v.feet.y
	for t in 240:
		previous = v.feet.y - o.y
		v.wish(Vector3.ZERO, false, false, t == 0, -1)
		v.step(v.feet, t)
		if not v.flying:
			break
		high = high and v.feet.y - o.y >= 12
	var gate := visit._gate_dir(Vector2(o.x, o.z)) * (float(view.radii[i]) + Visit.GATE_OUT_M)
	var error := Vector2(v.feet.x - o.x, v.feet.z - o.z).distance_to(gate)
	var arrival := v.feet
	var arrival_mode := v.mode
	var arrival_t := v.fly_t
	var folded_at_gate := arrival_t == -1 and not v.flying and is_zero_approx(v.fly_turn)
	var cfg: Dictionary = view.world.sched.load_config("res://kernel/world/tiers.json", view.world.walk.tiers).cfg
	var defs := []
	for index in view.plots.size():
		var sizes: Array = view.world.walk.plots[index].footprint.size_m
		defs.append({"id": view.world.walk.plots[index].id, "origin": view.plots[index].origin, "size": Vector2(sizes[0], sizes[1])})
	view.world.sched.setup(cfg, defs)
	view.world.sched.visitor = true
	# The gate faces the road. Walk the same capsule through the opening before asking to enter.
	for t in 120:
		var inward := Vector3(o.x - v.feet.x, 0, o.z - v.feet.z).normalized()
		v.wish(inward * Visitor.Body.WALK_MPS, false, false)
		v.step(v.feet, 240 + t)
	var inside_m := float(view.radii[i]) - Vector2(v.feet.x - o.x, v.feet.z - o.z).length()
	var walked_m := Vector2(v.feet.x - arrival.x, v.feet.z - arrival.z).length()
	visit.input.tap(&"enter")
	visit.input._sample()
	visit.steer(360)
	view.world.sched.decide(361, v.feet)
	var stage := view.world.sched.stage
	var before_stage := v.fly_t
	v.hide()
	v.step(v.feet, 361)
	var ok := high and previous >= 12 and previous < 12.16 and error < 0.001 and arrival_mode == "ground" and folded_at_gate
	_line("gate", ok and inside_m > 0 and stage == i and v.fly_t == before_stage - 1,
		"plot=%d previous_height=%.3f gate_error_m=%.4f mode=%s fly_t=%d walked_m=%.3f inside_m=%.3f entered_stage=%d" % [i, previous, error, arrival_mode, arrival_t, walked_m, inside_m, stage])

## Take off on the road, reach cruise, bank both ways and descend with forward thrust.
## Observe the normal visitor step through landing and long enough to diagnose a late reset.
func _pose() -> void:
	var v := view.visitor
	v.put(ROAD, -PI / 2)
	var rig := v.rig
	if rig == null:
		_line("pose", false, "missing visitor rig")
		return
	var back: Node3D = rig.call("socket", &"back")
	var wing_root: Node3D = v.wings.get("root") if v.wings != null else null
	var attached := back != null and wing_root != null and wing_root.get_parent() == back
	# After a step on the ground this signal is emitted only for the body's fly_land event.
	var land_ticks: Array[int] = []
	v.flight_step.connect(func() -> void:
		if not v.flying:
			land_ticks.append(v.ticks))
	var cruise_speed := 0.0
	var cruise_lean := 0.0
	var max_step := 0.0
	var max_bank := 0.0
	var left_bank := 0.0
	var right_bank := 0.0
	var missing_clip_ticks := 0
	var airborne_ticks := 0
	var landing := -1
	var clip_exit := -1
	var reset := -1
	var lean40 := NAN
	var bank40 := NAN
	var pitch40 := NAN
	var roll40 := NAN
	var offset40 := NAN
	var neutral40 := false
	for t in 550:
		var wish := Vector3.RIGHT * CRUISE
		var climb := 0.0
		if t < 30 or landing >= 0:
			wish = Vector3.ZERO
		elif t < 90:
			climb = 1.0
		elif t >= 180 and t < 197:
			wish = Vector3.FORWARD * CRUISE
		elif t >= 197 and t < 230:
			wish = Vector3.BACK * CRUISE
		elif t >= 247:
			climb = -1.0
			if t >= 330:
				wish = Vector3.FORWARD * CRUISE  # Remain banked through touchdown.
		var before := v.lean
		var was_flying := v.flying
		v.wish(wish, false, false, t == 0, climb)
		v.step(v.feet, t)
		var fly_clip := StringName(rig.get("clip")) == &"fly"
		max_step = maxf(max_step, absf(v.lean - before))
		max_bank = maxf(max_bank, absf(v.bank))
		if v.flying:
			airborne_ticks += 1
			missing_clip_ticks += int(not fly_clip)
		if t == 179:
			cruise_lean = v.lean
			cruise_speed = v.speed
		if t == 196:
			left_bank = v.bank
		if t == 229:
			right_bank = v.bank
		if was_flying and v.mode == "ground" and climb < 0 and v.ticks in land_ticks:
			landing = t
		if landing < 0:
			continue
		var since := t - landing
		if not fly_clip and clip_exit < 0:
			clip_exit = since
		var yaw_only := Basis(Vector3.UP, rig.rotation.y)
		var neutral := v.lean == 0.0 and v.bank == 0.0 and rig.position == Vector3.ZERO and rig.basis.is_equal_approx(yaw_only)
		if neutral and reset < 0:
			reset = since
		if since == 40:
			neutral40 = neutral
			lean40 = v.lean
			bank40 = v.bank
			pitch40 = rad_to_deg(rig.rotation.x)
			roll40 = rad_to_deg(rig.rotation.z)
			offset40 = rig.position.length()
		if since >= 40 and neutral:
			break
	var ok := attached and cruise_speed >= 0.95 * CRUISE and absf(cruise_lean - 62) <= 3 and max_step <= 6
	ok = ok and left_bank > 0 and right_bank < 0 and max_bank <= 28 and airborne_ticks > 0 and missing_clip_ticks == 0
	ok = ok and landing >= 247 and clip_exit >= 0 and clip_exit <= 1 and reset >= 0 and reset <= 40 and neutral40
	_line("pose", ok, ("cruise_mps=%.3f lean_deg=%.3f max_lean_step_deg=%.3f bank_left/right_deg=%.3f/%.3f max_abs_bank_deg=%.3f " +
		"fly_clip_ticks=%d/%d clip_exit_ticks=%d back_socket=%s lean40=%.3f bank40=%.4f pitch40=%.3f roll40=%.4f offset40_m=%.5f neutral_ticks=%d") %
		[cruise_speed, cruise_lean, max_step, left_bank, right_bank, max_bank, airborne_ticks - missing_clip_ticks, airborne_ticks, clip_exit, attached, lean40, bank40, pitch40, roll40, offset40, reset])
