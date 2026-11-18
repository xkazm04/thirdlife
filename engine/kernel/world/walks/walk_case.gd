extends SceneTree
## Selftest cases `walk.*` (tools/selftest.sh; lane M, walker-feel, 18 Nov 2026): the visitor's body with weight
## (terrain/world_space.gd `drive()`) on ground built for the case, headless, counted in ticks. One line per case:
## `WALKCASE <name> ok|fail <figures>`, then `WALKCASE done <n ok> <n>`.
##   <godot> --headless --path engine --script res://kernel/world/walks/walk_case.gd [-- <name filter>]
## Cases: idle_bank (600 ticks idle on walkable banks of 20, 35, 50 degrees, and after walking onto one: drift < 1 cm),
## jump (height 0.9..1.1 m, air ticks), ledge (walking off 3 m falls with gravity: no tick drops more than
## 0.75 m, the fall takes more than 12 ticks), steep (on a 65 degree bank he slides to its foot and stops on the flat),
## pace (W held reaches 4.5 m/s, Shift 9.0, in ticks; a 6-tick tap moves 0.3..1.0 m; release stops), slide (a run slide
## carries him further than stopping and ends), camera (TLChaseCam with `avoid_space`: walking along a bank with the
## view pitched low, the camera is never closer to the ground than its margin; without it, it is under the ground).

const Space: GDScript = preload("res://kernel/world/terrain/world_space.gd")
const DT: float = 1.0 / 60.0

var _ok: int = 0
var _n: int = 0
var _filter: String = ""


func _say(name: String, ok: bool, figs: String) -> void:
	_n += 1
	if ok:
		_ok += 1
	print("WALKCASE %s %s %s" % [name, "ok" if ok else "fail", figs])


func _want(name: String) -> bool:
	return _filter.is_empty() or name.contains(_filter)


## A plane through the origin rising toward -z at `deg` (60 m square), with a flat floor at its foot from z = foot_z.
static func bank(sp: RefCounted, deg: float, half: float = 30.0) -> void:
	var t: float = tan(deg_to_rad(deg))
	var p: Array = [Vector3(-half, -half * t, half), Vector3(half, -half * t, half), Vector3(half, half * t, -half), Vector3(-half, half * t, -half)]
	sp.call("add_faces", PackedVector3Array([p[0], p[1], p[2], p[0], p[2], p[3]]))


static func flat(sp: RefCounted, y: float, x0: float, x1: float, z0: float, z1: float) -> void:
	sp.call("add_faces", PackedVector3Array([Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]))


func _drive(sp: RefCounted, feet: Vector3, wish: Vector3, jump: bool = false, slide: bool = false) -> Dictionary:
	return sp.call("drive", feet, wish, jump, slide)


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_filter = args[0] if args.size() > 0 else ""
	if _want("biped_parity"):
		await _biped_parity()
	if _want("idle_bank"):
		_idle_bank()
	if _want("jump"):
		_jump()
	if _want("ledge"):
		_ledge()
	if _want("steep"):
		_steep()
	if _want("pace"):
		_pace()
	if _want("slide"):
		_slide()
	if _want("camera"):
		await _camera()
	if _want("canopy"):
		await _canopy()
	print("WALKCASE done %d %d" % [_ok, _n])
	quit(0 if _ok == _n else 1)


func _idle_bank() -> void:
	var worst: float = 0.0
	var figs: Array = []
	for deg: float in [20.0, 35.0, 50.0]:
		var sp: RefCounted = Space.new()
		bank(sp, deg)
		var feet: Vector3 = Vector3(0.0, sp.call("ground_at", 0.0, 0.0, 50.0), 0.0)
		sp.call("place", feet)
		sp.call("rest")
		var start: Vector3 = feet
		for i: int in 600:
			feet = _drive(sp, feet, Vector3.ZERO)["pos"]
		var d: float = feet.distance_to(start)
		# walk across the bank for a second, let go, then 600 ticks idle
		for i: int in 60:
			feet = _drive(sp, feet, Vector3(4.5, 0.0, 0.0))["pos"]
		for i: int in 30:
			feet = _drive(sp, feet, Vector3.ZERO)["pos"]
		var at: Vector3 = feet
		for i: int in 600:
			feet = _drive(sp, feet, Vector3.ZERO)["pos"]
		var d2: float = feet.distance_to(at)
		worst = maxf(worst, maxf(d, d2))
		figs.append("%d deg: %.4f / %.4f m" % [int(deg), d, d2])
		sp.call("free_all")
	_say("walk.idle_bank", worst < 0.01, "drift placed / after a walk, 600 ticks: %s" % ", ".join(figs))


func _jump() -> void:
	var sp: RefCounted = Space.new()
	flat(sp, 0.0, -20, 20, -20, 20)
	var feet: Vector3 = Vector3.ZERO
	sp.call("place", feet)
	sp.call("rest")
	var top: float = 0.0
	var air: int = 0
	var landed: int = -1
	var ev: Array = []
	for i: int in 120:
		var r: Dictionary = _drive(sp, feet, Vector3.ZERO, i == 5)
		feet = r["pos"]
		top = maxf(top, feet.y)
		if not bool(r["grounded"]):
			air += 1
		ev.append_array(r["events"])
		if (r["events"] as Array).has("land") and landed < 0:
			landed = i
	# coyote: walking off a 1 m step, the jump pressed 4 ticks after leaving still jumps; 12 ticks after: not
	var sp2: RefCounted = Space.new()
	flat(sp2, 1.0, -20, 20, -20, 0)
	flat(sp2, 0.0, -20, 20, 0, 20)
	var coy: Array = []
	for late: int in [4, 12]:
		var f: Vector3 = Vector3(0, 1.0, -2.0)
		sp2.call("place", f)
		sp2.call("rest")
		var left: int = -1
		var jumped: bool = false
		var down: bool = false
		for i: int in 120:
			var r2: Dictionary = _drive(sp2, f, Vector3(0, 0, 4.5), left >= 0 and i == left + late)
			f = r2["pos"]
			if left < 0 and str(r2["mode"]) == "air":
				left = i
			if (r2["events"] as Array).has("land"):
				down = true
			if (r2["events"] as Array).has("jump") and not down:
				jumped = true                     # a jump in the air off the edge (a later one is the buffer, on landing)
		coy.append(jumped)
	# buffer: pressed 5 ticks before landing still jumps
	sp.call("place", Vector3.ZERO)
	sp.call("rest")
	feet = Vector3.ZERO
	var jumps: int = 0
	var land_at: int = 5 + landed - 5
	for i: int in 160:
		var r3: Dictionary = _drive(sp, feet, Vector3.ZERO, i == 5 or i == land_at - 4)
		feet = r3["pos"]
		if (r3["events"] as Array).has("jump"):
			jumps += 1
	var ok: bool = top > 0.9 and top < 1.1 and air >= 30 and air <= 40 and coy == [true, false] and jumps == 2 and ev.has("jump") and ev.has("land")
	_say("walk.jump", ok, "height %.3f m, %d ticks in the air, jump in the air pressed 4 / 12 ticks after walking off a 1 m step: %s, buffered press 4 ticks before landing jumps again: %s" % [top, air, coy, jumps == 2])
	sp.call("free_all")
	sp2.call("free_all")


func _ledge() -> void:
	var sp: RefCounted = Space.new()
	flat(sp, 3.0, -20, 20, -20, 0)
	flat(sp, 0.0, -20, 20, 0, 20)
	var feet: Vector3 = Vector3(0, 3.0, -1.0)
	sp.call("place", feet)
	sp.call("rest")
	var ys: Array = []
	var biggest: float = 0.0
	var fall: int = 0
	var landed: bool = false
	for i: int in 90:
		var r: Dictionary = _drive(sp, feet, Vector3(0, 0, 4.5))
		var ny: float = (r["pos"] as Vector3).y
		biggest = maxf(biggest, feet.y - ny)
		if str(r["mode"]) == "air":
			fall += 1
		if (r["events"] as Array).has("land"):
			landed = true
		feet = r["pos"]
		ys.append(snappedf(feet.y, 0.01))
	var ok: bool = biggest < 0.75 and fall > 12 and landed and absf(feet.y) < 0.02
	_say("walk.ledge", ok, "3 m ledge at 4.5 m/s: %d ticks falling, largest drop in one tick %.3f m, landed %s, feet y %s" % [fall, biggest, landed, ys.slice(10, 40)])
	sp.call("free_all")


func _steep() -> void:
	var sp: RefCounted = Space.new()
	# a 65 degree bank from y 8 at z -3.7 down to y 0 at z 0, flat ground below and above
	var t: float = tan(deg_to_rad(65.0))
	var top_z: float = -8.0 / t
	sp.call("add_faces", PackedVector3Array([Vector3(-20, 8, top_z), Vector3(20, 8, top_z), Vector3(20, 0, 0), Vector3(-20, 8, top_z), Vector3(20, 0, 0), Vector3(-20, 0, 0)]))
	flat(sp, 0.0, -20, 20, 0, 30)
	flat(sp, 8.0, -20, 20, -20, top_z)
	# 1. walking off the top edge onto it: he slides down to its foot and stops on the flat
	var feet: Vector3 = Vector3(0, 8.0, top_z - 1.0)
	sp.call("place", feet)
	sp.call("rest")
	var modes: Dictionary = {}
	var top_speed: float = 0.0
	var stop_tick: int = -1
	for i: int in 240:
		var r: Dictionary = _drive(sp, feet, Vector3(0, 0, 4.5) if i < 20 else Vector3.ZERO)
		feet = r["pos"]
		modes[str(r["mode"])] = int(modes.get(str(r["mode"]), 0)) + 1
		top_speed = maxf(top_speed, (r["vel"] as Vector3).length())
		if stop_tick < 0 and i > 20 and str(r["mode"]) == "ground" and (r["vel"] as Vector3).length() < 0.01:
			stop_tick = i
	var ok1: bool = modes.has("slope") and absf(feet.y) < 0.05 and feet.z > 0.0 and stop_tick > 0
	# 2. walking up into it from below: refused (a wall), he does not climb
	var f2: Vector3 = Vector3(0, 0, 2.0)
	sp.call("place", f2)
	sp.call("rest")
	for i: int in 120:
		f2 = _drive(sp, f2, Vector3(0, 0, -4.5))["pos"]
	var ok2: bool = f2.y < 0.6
	_say("walk.steep", ok1 and ok2, "65 deg bank 8 m: walked off the top, %d ticks sliding, top speed %.2f m/s, stopped at tick %d at z %.2f y %.3f (foot at z 0); walking up into it from below ends at y %.2f" % [int(modes.get("slope", 0)), top_speed, stop_tick, feet.z, feet.y, f2.y])
	sp.call("free_all")


func _pace() -> void:
	var sp: RefCounted = Space.new()
	flat(sp, 0.0, -200, 200, -200, 200)
	var feet: Vector3 = Vector3.ZERO
	sp.call("place", feet)
	sp.call("rest")
	var t_walk: int = -1
	var t_run: int = -1
	var t_stop: int = -1
	for i: int in 120:
		var r: Dictionary = _drive(sp, feet, Vector3(0, 0, -4.5))
		feet = r["pos"]
		if t_walk < 0 and (r["vel"] as Vector3).length() >= 4.49:
			t_walk = i + 1
	var a: Vector3 = feet
	for i: int in 60:
		feet = _drive(sp, feet, Vector3(0, 0, -4.5))["pos"]
	var walk_mps: float = feet.distance_to(a)
	for i: int in 120:
		var r: Dictionary = _drive(sp, feet, Vector3(0, 0, -9.0))
		feet = r["pos"]
		if t_run < 0 and (r["vel"] as Vector3).length() >= 8.99:
			t_run = i + 1
	var stop_from: Vector3 = feet
	for i: int in 60:
		var r: Dictionary = _drive(sp, feet, Vector3.ZERO)
		feet = r["pos"]
		if t_stop < 0 and (r["vel"] as Vector3).length() < 0.001:
			t_stop = i + 1
	var stop_m: float = feet.distance_to(stop_from)
	# a tap: 6 ticks of W from rest
	var b: Vector3 = feet
	for i: int in 60:
		feet = _drive(sp, feet, Vector3(0, 0, -4.5) if i < 6 else Vector3.ZERO)["pos"]
	var tap: float = feet.distance_to(b)
	# 180 ticks of W from rest (P11's figure was 13.50 m at once-full speed)
	var c: Vector3 = feet
	for i: int in 180:
		feet = _drive(sp, feet, Vector3(4.5, 0, 0))["pos"]
	var w180: float = feet.distance_to(c)
	for i: int in 30:
		feet = _drive(sp, feet, Vector3.ZERO)["pos"]
	var ok: bool = t_walk > 0 and t_walk <= 15 and absf(walk_mps - 4.5) < 0.01 and t_run > 0 and t_run <= 25 and t_stop > 0 and t_stop <= 15 and tap >= 0.3 and tap <= 1.0
	_say("walk.pace", ok, "rest to 4.5 m/s in %d ticks (then %.3f m in 60 ticks), 4.5 to 9.0 in %d ticks, 9.0 to rest in %d ticks over %.2f m, a 6-tick tap moves %.2f m, W 180 ticks from rest %.2f m" % [t_walk, walk_mps, t_run, t_stop, stop_m, tap, w180])
	sp.call("free_all")


func _slide() -> void:
	var sp: RefCounted = Space.new()
	flat(sp, 0.0, -200, 200, -200, 200)
	var feet: Vector3 = Vector3.ZERO
	sp.call("place", feet)
	sp.call("rest")
	for i: int in 60:
		feet = _drive(sp, feet, Vector3(0, 0, -9.0))["pos"]
	var at: Vector3 = feet
	var ticks: int = 0
	var ended: int = -1
	var ev: Array = []
	for i: int in 120:
		var r: Dictionary = _drive(sp, feet, Vector3.ZERO, false, i == 0)
		feet = r["pos"]
		ev.append_array(r["events"])
		if str(r["mode"]) == "slide":
			ticks += 1
		elif ended < 0 and i > 0:
			ended = i
	var slid: float = feet.distance_to(at)
	# into a run: the slide ends while W + Shift are held, he is running again
	sp.call("rest")
	for i: int in 60:
		feet = _drive(sp, feet, Vector3(0, 0, -9.0))["pos"]
	var v_end: float = 0.0
	for i: int in 120:
		var r2: Dictionary = _drive(sp, feet, Vector3(0, 0, -9.0), false, i == 0)
		feet = r2["pos"]
		v_end = (r2["vel"] as Vector3).length()
	var ok: bool = ev.has("slide") and ev.has("end_slide") and ticks >= 20 and slid > 4.0 and v_end > 8.9
	_say("walk.slide", ok, "a run slide from 9 m/s: %d ticks low, %.2f m to a stop (a stop without it: 0.97 m), ends into a run at %.2f m/s when W stays held" % [ticks, slid, v_end])
	sp.call("free_all")


func _camera() -> void:
	# a hill rising toward -z at 30 degrees from z = 0, the visitor walks along x at its foot looking along it, the view
	# pitched to its lowest (-10 degrees: the camera below his head) and turned so the camera stands over the hill
	var res: Array = []
	for avoid: bool in [false, true]:
		var sp: RefCounted = Space.new()
		var t: float = tan(deg_to_rad(30.0))
		sp.call("add_faces", PackedVector3Array([Vector3(-60, 0, 0), Vector3(60, 0, 0), Vector3(60, 30.0 * t, -30), Vector3(-60, 0, 0), Vector3(60, 30.0 * t, -30), Vector3(-60, 30.0 * t, -30)]))
		flat(sp, 0.0, -60, 60, 0, 30)
		var holder: Node3D = Node3D.new()
		root.add_child(holder)
		var who: Node3D = Node3D.new()
		holder.add_child(who)
		who.position = Vector3(-20, 0, 0.6)
		who.rotation.y = deg_to_rad(-120.0)      # looking east-south-east: the camera behind him is up the hill
		var cam: TLChaseCam = TLChaseCam.new()
		holder.add_child(cam)
		var pitch: float = deg_to_rad(-10.0)
		var dist: float = Vector2(8.5, 3.6 - 1.7).length()
		var o: Dictionary = {"distance": dist * cos(pitch), "height": 1.7 + dist * sin(pitch), "look_height": 1.7, "stiffness": 1.0, "follow": 1.0, "aim": 1.0}
		if avoid:
			o["avoid_space"] = sp.get("space")
		cam.setup(who, o)
		cam.make_current()
		var worst: float = INF
		for i: int in 240:
			who.position.x += 4.5 / 60.0
			await physics_frame
			var c: Vector3 = cam.global_position
			var g: float = sp.call("ground_at", c.x, c.z, 60.0)
			worst = minf(worst, c.y - g)
		res.append(worst)
		holder.queue_free()
		await process_frame
		sp.call("free_all")
	var ok: bool = res[0] < 0.0 and res[1] > 0.2
	_say("walk.camera", ok, "camera height over the ground, lowest of 240 ticks along a 30 deg hill, view pitched -10 deg: without avoid_space %.2f m (under the ground), with it %.2f m" % [res[0], res[1]])


func _canopy() -> void:
	# round 2 (T-PATCHES M2): he runs along x past a row of trees just off his line; the chase camera behind him. A
	# tick is "blocked" when the line from the point looked at to the camera passes through a crown (layer 4), "inside"
	# when the camera itself is in one. Without the crowns in the camera's mask (round 1) and with them.
	var res: Array = []
	for mask: int in [1, 1 | 4]:
		var sp: RefCounted = Space.new()
		flat(sp, 0.0, -80, 80, -40, 40)
		sp.set("tag", "tree")
		for x: float in [-30.0, -18.0, -6.0, 6.0, 18.0]:
			sp.call("add_trunk", Vector3(x, 0.0, -1.2), 0.5)
		var holder: Node3D = Node3D.new()
		root.add_child(holder)
		var who: Node3D = Node3D.new()
		holder.add_child(who)
		who.position = Vector3(-40, 0, 0)
		who.rotation.y = deg_to_rad(-90.0)        # looking along +x
		var cam: TLChaseCam = TLChaseCam.new()
		holder.add_child(cam)
		cam.setup(who, {"distance": 8.5, "height": 3.6, "look_height": 1.7, "stiffness": 1.0, "follow": 1.0, "aim": 1.0, "anchor_follow": 0.45, "anchor_follow_y": 0.18,
			"avoid_space": sp.get("space"), "avoid_mask": mask})
		cam.make_current()
		var blocked: int = 0
		var inside: int = 0
		var nearest: float = INF
		for i: int in 360:
			who.position.x += 9.0 / 60.0
			await physics_frame
			var c: Vector3 = cam.global_position
			var look: Vector3 = who.global_position + Vector3.UP * 1.7
			var st: PhysicsDirectSpaceState3D = PhysicsServer3D.space_get_direct_state(sp.get("space"))
			if not st.intersect_ray(PhysicsRayQueryParameters3D.create(look, c, 4)).is_empty():
				blocked += 1
			var q: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
			q.position = c
			q.collision_mask = 4
			if not st.intersect_point(q, 1).is_empty():
				inside += 1
			nearest = minf(nearest, c.distance_to(look))
		res.append([blocked, inside, nearest])
		holder.queue_free()
		await process_frame
		sp.call("free_all")
	var ok: bool = int(res[0][0]) > 0 and int(res[1][0]) == 0 and int(res[1][1]) == 0
	_say("walk.canopy", ok, "360 ticks at 9 m/s past 5 trees: camera mask 1 (round 1): the view through a crown in %d ticks, the camera inside one in %d; mask 1|4: %d and %d, nearest camera %.2f m from the point looked at" % [res[0][0], res[0][1], res[1][0], res[1][1], res[1][2]])

## The public pack controller and the visitor see the same fixed geometry through separate capsules.
## Drive the pack through move/jump/slide and measure its resulting position and velocity.
func _biped_parity() -> void:
	await process_frame
	var sp = Space.new()
	var angle := deg_to_rad(65.0)
	var lip := -8.0 / tan(angle)
	flat(sp, 8.0, -20, 20, -80, lip)
	flat(sp, 0.0, -20, 20, 0, 40)
	var a := Vector3(-20, 8, lip)
	var b := Vector3(20, 8, lip)
	var c := Vector3(20, 0, 0)
	var d := Vector3(-20, 0, 0)
	sp.add_faces(PackedVector3Array([a, b, c, a, c, d]))
	var actor := TLBiped.create({"feel": &"walker"})
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.collision_layer = 2
	PhysicsServer3D.body_set_space(actor.get_rid(), sp.space)
	var observations: Array[Dictionary] = []
	for use_pack: bool in [false, true]:
		var pos := Vector3(0, 8, -60)
		actor.place(pos)
		sp.rest()
		sp.place(pos)
		var m := {"apex": 0.0, "air": 0, "run": 0, "slide": 0.0, "slide_ticks": 0, "slope": 0, "peak": 0.0}
		var entry := 0.0
		var sliding := false
		for tick: int in 360:
			var wish := Vector3.BACK if tick >= 45 else Vector3.ZERO
			if tick == 75:
				entry = pos.z
			if tick == 150:
				pos = Vector3(0, 8, lip - 1.0)
				sp.rest()
				sp.place(pos)
				actor.place(pos)
			var run := tick < 150
			if tick >= 170:
				wish = Vector3.ZERO
			var motion: String
			var v: Vector3
			if use_pack:
				actor.move(wish, run)
				if tick == 5:
					actor.jump()
				if tick == 75:
					actor.slide()
				actor._physics_process(DT)
				pos = actor.global_position
				motion = actor.walker_motion()
				v = actor.velocity
			else:
				var res: Dictionary = sp.drive(pos, wish * (9.0 if run else 4.5), tick == 5, tick == 75)
				pos = res.pos
				motion = res.mode
				v = res.vel
			if tick < 45:
				m.apex = maxf(m.apex, pos.y - 8.0)
				if motion == "air":
					m.air += 1
			elif tick < 75 and m.run == 0 and v.z >= 8.999:
				m.run = tick - 45 + 1
			if motion == "slide":
				m.slide_ticks += 1
				sliding = true
			elif sliding:
				m.slide = pos.z - entry
				sliding = false
			if motion == "slope":
				m.slope += 1
				m.peak = maxf(m.peak, v.length())
		m.foot = pos.y
		observations.append(m)
	var visitor := observations[0]
	var pack := observations[1]
	var ok: bool = absf(pack.apex - visitor.apex) < 0.005 and pack.air == visitor.air and pack.run == visitor.run \
		and absf(pack.slide - visitor.slide) < 0.02 and pack.slide_ticks == visitor.slide_ticks \
		and pack.slope == visitor.slope and absf(pack.peak - visitor.peak) < 0.05 \
		and pack.apex > 0.9 and pack.apex < 1.1 and pack.air >= 32 and pack.air <= 35 and pack.run == 16 \
		and pack.slide > 5 and pack.slope == 54 and absf(pack.foot) < 0.05
	_say("walk.biped_parity", ok, "visitor %s; pack %s" % [visitor, pack])
	actor.free()
	sp.free_all()
