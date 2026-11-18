extends SceneTree
## Selftest cases `walk.*`, part b (bugfix-37, lane walker): regressions of the visitor's body (terrain/world_body.gd)
## and the visitor (visitor.gd), headless, counted in ticks. Same contract as walk_case.gd (whose static helpers `bank`
## and `flat` it uses): one line per case `WALKCASE <name> ok|fail <figures>`, then `WALKCASE done <n ok> <n>`; a filter
## that selects no case exits 2. Run by engine/tools/selftest.d/280-walk.sh together with walk_case.gd.
##   <godot> --headless --path engine --script res://kernel/world/walks/walk_case_b.gd [-- <name filter>]
## Cases: steep_rest (D6: put at rest on a 65 degree bank he slides from the first tick), slope_pit (D14: out of a pit
## of 62 degree walls by a jump from the slope; hopping into a 65 degree bank never stands higher on its face than jumps
## from the ground do), jump_buffer (D20: a press 1..BUFFER ticks before landing jumps, on the landing tick; BUFFER + 1
## does not), stage_pose (D7: a slide pose ends when a game goes on stage and on `put`), edge_slide (D19: a slide
## pressed on the tick he runs off an edge does not keep its pose through the fall).

const Space: GDScript = preload("res://kernel/world/terrain/world_space.gd")
const Body: GDScript = preload("res://kernel/world/terrain/world_body.gd")
const Visitor: GDScript = preload("res://kernel/world/visitor.gd")
const Walk: GDScript = preload("res://kernel/world/walks/walk_case.gd")

var _ok: int = 0
var _n: int = 0
var _filter: String = ""


func _say(name: String, ok: bool, figs: String) -> void:
	_n += 1
	if ok:
		_ok += 1
	print("WALKCASE %s %s %s" % [name, "ok" if ok else "fail", figs])


## The filter matches the printed name (`walk.<case>`), so `-- walk.slope_pit` and `-- slope_pit` select the same case.
func _want(name: String) -> bool:
	return _filter.is_empty() or ("walk." + name).contains(_filter)


func _drive(sp: RefCounted, feet: Vector3, wish: Vector3, jump: bool = false, slide: bool = false) -> Dictionary:
	return sp.call("drive", feet, wish, jump, slide)


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_filter = args[0] if args.size() > 0 else ""
	if _want("steep_rest"):
		_steep_rest()
	if _want("slope_pit"):
		_slope_pit()
	if _want("jump_buffer"):
		_jump_buffer()
	if _want("stage_pose"):
		await _stage_pose()
	if _want("edge_slide"):
		await _edge_slide()
	print("WALKCASE done %d %d" % [_ok, _n])
	# A filter that selected no case ran nothing: never a pass (docs/GATE-HONESTY.md), exit 2 "could not run".
	if _n == 0:
		print("WALKCASE none: no case matches the filter '%s'" % _filter)
		quit(2)
		return
	quit(0 if _ok == _n else 1)


## D6: put at rest on ground steeper than the limit (65 against 55) he does not stand there: the first tick is a slope
## slide and he goes down the bank; on a walkable 50 degree bank he stands (idle_bank's control).
func _steep_rest() -> void:
	var figs: Array = []
	var ok: bool = true
	for deg: float in [65.0, 50.0]:
		var sp: RefCounted = Space.new()
		Walk.bank(sp, deg)
		var feet: Vector3 = Vector3(0.0, sp.call("ground_at", 0.0, 0.0, 50.0), 0.0)
		var start: Vector3 = feet
		sp.call("place", feet)
		sp.call("rest")
		var first: String = ""
		var grounded: int = 0
		for i: int in 60:
			var r: Dictionary = _drive(sp, feet, Vector3.ZERO)
			feet = r["pos"]
			if i == 0:
				first = str(r["mode"])
			grounded += int(bool(r["grounded"]))
		var down: float = start.y - feet.y
		figs.append("%d deg: first tick %s, grounded %d of 60 ticks, %.2f m down" % [int(deg), first, grounded, down])
		if deg > 55.0:
			ok = ok and first == "slope" and grounded == 0 and down > 1.0
		else:
			ok = ok and first == "ground" and grounded == 60 and absf(down) < 0.01
		sp.call("free_all")
	_say("walk.steep_rest", ok, "put at rest, 60 ticks idle: %s" % ", ".join(figs))


## A pit of four `deg` walls `depth` deep whose walls meet at the bottom (bugfix-37 hunt-R r2), flat ground round it.
## Returns the half width of its rim.
static func pit(sp: RefCounted, deg: float, depth: float) -> float:
	var w: float = depth / tan(deg_to_rad(deg))
	var b: float = 0.05
	var t: float = b + w
	var f: PackedVector3Array = PackedVector3Array()
	var top: Array = [Vector3(-t, 0, -t), Vector3(t, 0, -t), Vector3(t, 0, t), Vector3(-t, 0, t)]
	var bot: Array = [Vector3(-b, -depth, -b), Vector3(b, -depth, -b), Vector3(b, -depth, b), Vector3(-b, -depth, b)]
	for i: int in 4:
		var j: int = (i + 1) % 4
		f.append_array(PackedVector3Array([top[i], top[j], bot[j], top[i], bot[j], bot[i]]))
	f.append_array(PackedVector3Array([bot[0], bot[1], bot[2], bot[0], bot[2], bot[3]]))
	var r: float = 30.0
	for q: Array in [[-r, r, -r, -t], [-r, r, t, r], [-r, -t, -t, t], [t, r, -t, t]]:
		f.append_array(PackedVector3Array([Vector3(q[0], 0, q[2]), Vector3(q[1], 0, q[2]), Vector3(q[1], 0, q[3]), Vector3(q[0], 0, q[2]), Vector3(q[1], 0, q[3]), Vector3(q[0], 0, q[3])]))
	sp.call("add_faces", f)
	return t


## D14: in a 0.8 m pit of 62 degree walls (steeper than the limit) he is in slope mode; W held outward and jump pressed
## every 10 ticks gets him out (the 45 degree pit is the control). R6 stays: hopping into a 65 degree bank 8 m high
## (walk.steep's) with jump pressed every tick never stands higher on its face than with jumps from the ground only.
func _slope_pit() -> void:
	var outs: Array = []
	var modes_in: Array = []
	for deg: float in [45.0, 62.0]:
		var sp: RefCounted = Space.new()
		var t: float = pit(sp, deg, 0.8)
		var feet: Vector3 = Vector3(0, 0, 3.0)
		sp.call("place", feet)
		sp.call("rest")
		var m_in: String = ""
		for i: int in 120:
			var r0: Dictionary = _drive(sp, feet, Vector3(0, 0, -2.0))
			feet = r0["pos"]
			m_in = str(r0["mode"])
		modes_in.append(m_in)
		var out_at: int = -1
		for i: int in 1200:
			feet = _drive(sp, feet, Vector3(0, 0, 9.0), i % 10 == 0)["pos"]
			if feet.y > -0.05 and Vector2(feet.x, feet.z).length() > t + 0.5:
				out_at = i
				break
		outs.append(out_at)
		sp.call("free_all")
	var t65: float = tan(deg_to_rad(65.0))
	var top_z: float = -8.0 / t65
	var face: Array = []
	var tops: Array = []
	for slope_jumps: bool in [false, true]:
		var sp2: RefCounted = Space.new()
		sp2.call("add_faces", PackedVector3Array([Vector3(-20, 8, top_z), Vector3(20, 8, top_z), Vector3(20, 0, 0), Vector3(-20, 8, top_z), Vector3(20, 0, 0), Vector3(-20, 0, 0)]))
		Walk.flat(sp2, 0.0, -20, 20, 0, 30)
		Walk.flat(sp2, 8.0, -20, 20, -20, top_z)
		var f: Vector3 = Vector3(0, 0, 2.0)
		sp2.call("place", f)
		sp2.call("rest")
		var mode: String = "ground"
		var hi: float = 0.0
		var top: float = 0.0
		for i: int in 1200:
			var r: Dictionary = _drive(sp2, f, Vector3(0, 0, -9.0), slope_jumps or mode == "ground")
			f = r["pos"]
			mode = str(r["mode"])
			top = maxf(top, f.y)
			if mode == "slope" or mode == "ground":
				hi = maxf(hi, f.y)
		face.append(hi)
		tops.append(top)
		sp2.call("free_all")
	var ok: bool = modes_in[1] == "slope" and outs[0] >= 0 and outs[1] >= 0 and float(face[1]) <= float(face[0]) + 0.01 and float(tops[1]) < 4.0
	_say("walk.slope_pit", ok, "0.8 m pit, W out + jump every 10 ticks: 45 deg walls out at tick %d, 62 deg walls (in %s mode) out at tick %d; 65 deg bank 8 m, W 9 m/s into it for 1200 ticks: highest standing or sliding on it %.2f m with ground jumps only, %.2f m with a jump pressed every tick (highest in the air %.2f / %.2f m)" % [outs[0], modes_in[1], outs[1], face[0], face[1], tops[0], tops[1]])


## D20: a jump on flat ground, then a second press k ticks before the landing tick (k = 1 .. BUFFER + 2): it jumps for
## k <= BUFFER, on the landing tick itself, and not for k > BUFFER.
func _jump_buffer() -> void:
	var land: int = int(_buffer_run(-1)[0])
	var marks: Array = []
	var ok: bool = land > 30
	for k: int in range(1, Body.BUFFER + 3):
		var r: Array = _buffer_run(land - k)
		var second: int = int(r[1])
		if k <= Body.BUFFER:
			ok = ok and second == land
		else:
			ok = ok and second < 0
		marks.append("k%d:%s" % [k, ("tick %d" % second) if second >= 0 else "no"])
	_say("walk.jump_buffer", ok, "first jump at tick 5 lands at tick %d; a second press k ticks before it jumps at: %s (BUFFER %d)" % [land, " ".join(marks), Body.BUFFER])


func _buffer_run(press2: int) -> Array:
	var sp: RefCounted = Space.new()
	Walk.flat(sp, 0.0, -20, 20, -20, 20)
	var feet: Vector3 = Vector3.ZERO
	sp.call("place", feet)
	sp.call("rest")
	var land: int = -1
	var second: int = -1
	for i: int in 120:
		var r: Dictionary = _drive(sp, feet, Vector3.ZERO, i == 5 or i == press2)
		feet = r["pos"]
		if (r["events"] as Array).has("land") and land < 0:
			land = i
		if (r["events"] as Array).has("jump") and i > 5 and second < 0:
			second = i
	sp.call("free_all")
	return [land, second]


## A visitor with steer on, on `faces` (visitor.gd as a person drives it), at `at`: [space, land node, visitor].
func _visitor(faces: PackedVector3Array, at: Vector3) -> Array:
	var sp: RefCounted = Space.new()
	sp.call("add_faces", faces)
	var land: Node3D = Node3D.new()
	land.set_meta(&"tl_space", sp)
	root.add_child(land)
	var vis: Node3D = Visitor.new()
	land.add_child(vis)
	vis.call("setup", at, Vector3.FORWARD)
	vis.call("steer_on")
	return [sp, land, vis]


func _free_visitor(v: Array) -> void:
	(v[1] as Node).queue_free()
	await process_frame
	(v[0] as RefCounted).call("free_all")


## D7: he runs, slides (C), and a game goes on stage while he slides (view.gd hides him): the slide pose ends while he
## is hidden; after `put` at the gate he walks in his locomotion, not on his hip. Same for a slope slide (put on a 65
## degree bank, hidden while sliding down it, put back on the flat).
func _stage_pose() -> void:
	var big: PackedVector3Array = PackedVector3Array([Vector3(-200, 0, -200), Vector3(200, 0, -200), Vector3(200, 0, 200), Vector3(-200, 0, -200), Vector3(200, 0, 200), Vector3(-200, 0, 200)])
	var v: Array = _visitor(big, Vector3.ZERO)
	var vis: Node3D = v[2]
	var rig: Node3D = vis.get("rig")
	var f: int = 0
	for i: int in 60:
		vis.call("wish", Vector3(0, 0, -9.0), false, i == 59)
		vis.call("step", Vector3.ZERO, f)
		f += 1
	var sliding: String = "%s/%s" % [vis.get("mode"), rig.get("clip")]
	vis.visible = false
	for i: int in 30:
		vis.call("wish", Vector3.ZERO, false, false)
		vis.call("step", Vector3.ZERO, f)
		f += 1
	var hidden: String = str(rig.get("clip"))
	vis.visible = true
	vis.call("put", Vector3(10, 0, 10), 0.0)
	for i: int in 60:
		vis.call("wish", Vector3(0, 0, -4.5), false, false)
		vis.call("step", Vector3.ZERO, f)
		f += 1
	var after: String = "%s/%s" % [vis.get("mode"), rig.get("clip")]
	await _free_visitor(v)
	# a slope slide: a 65 degree bank through the origin, and a flat away from it to be put on
	var tb: float = tan(deg_to_rad(65.0))
	var faces: PackedVector3Array = PackedVector3Array([Vector3(-30, -30 * tb, 30), Vector3(30, -30 * tb, 30), Vector3(30, 30 * tb, -30), Vector3(-30, -30 * tb, 30), Vector3(30, 30 * tb, -30), Vector3(-30, 30 * tb, -30),
		Vector3(100, 0, -20), Vector3(140, 0, -20), Vector3(140, 0, 20), Vector3(100, 0, -20), Vector3(140, 0, 20), Vector3(100, 0, 20)])
	var v2: Array = _visitor(faces, Vector3.ZERO)
	var vis2: Node3D = v2[2]
	var rig2: Node3D = vis2.get("rig")
	var has_slope: bool = (rig2.call("clips") as PackedStringArray).has("slope_slide")
	for i: int in 10:
		vis2.call("wish", Vector3.ZERO, false, false)
		vis2.call("step", Vector3.ZERO, i)
	var on_bank: String = "%s/%s" % [vis2.get("mode"), rig2.get("clip")]
	vis2.visible = false
	vis2.call("wish", Vector3.ZERO, false, false)
	vis2.call("step", Vector3.ZERO, 10)
	var hidden2: String = str(rig2.get("clip"))
	vis2.visible = true
	vis2.call("put", Vector3(120, 0, 0), 0.0)
	for i: int in 30:
		vis2.call("wish", Vector3.ZERO, false, false)
		vis2.call("step", Vector3.ZERO, 11 + i)
	var after2: String = "%s/%s" % [vis2.get("mode"), rig2.get("clip")]
	await _free_visitor(v2)
	var ok: bool = sliding == "slide/slide" and hidden == "" and after == "ground/" \
		and on_bank == ("slope/slope_slide" if has_slope else "slope/") and hidden2 == "" and after2 == "ground/"
	_say("walk.stage_pose", ok, "run slide: mode/clip %s, hidden 30 ticks: clip '%s', put at the gate and 60 ticks walking: %s; put on a 65 deg bank: %s, hidden: clip '%s', put on the flat: %s" % [sliding, hidden, after, on_bank, hidden2, after2])


## D19: running at 9 m/s toward a 3 m drop, C pressed on each tick in turn until a slide starts on the very tick he runs
## off the edge (events slide and end_slide in one tick): the slide pose must not stay on through the fall.
func _edge_slide() -> void:
	var faces: PackedVector3Array = PackedVector3Array([Vector3(-20, 3, -6), Vector3(20, 3, -6), Vector3(20, 3, 20), Vector3(-20, 3, -6), Vector3(20, 3, 20), Vector3(-20, 3, 20),
		Vector3(-20, 0, -60), Vector3(20, 0, -60), Vector3(20, 0, -6), Vector3(-20, 0, -60), Vector3(20, 0, -6), Vector3(-20, 0, -6)])
	var found: int = -1
	var at_edge: String = ""
	var falling: String = ""
	for press_at: int in range(40, 80):
		var v: Array = _visitor(faces, Vector3(0, 3, 0))
		var vis: Node3D = v[2]
		var rig: Node3D = vis.get("rig")
		for i: int in 70:
			vis.call("wish", Vector3(0, 0, -9.0), false, i == press_at)
			var before: String = str(vis.get("mode"))
			vis.call("step", Vector3.ZERO, i)
			if i == press_at and before == "ground" and str(vis.get("mode")) == "air":
				found = i
				at_edge = str(rig.get("clip"))
			if found >= 0 and i == found + 10:
				falling = "%s/%s" % [vis.get("mode"), rig.get("clip")]
		await _free_visitor(v)
		if found >= 0:
			break
	var ok: bool = found >= 0 and at_edge == "" and falling == "air/"
	_say("walk.edge_slide", ok, "C pressed on the edge tick (%d): clip '%s' that tick, 10 ticks into the fall mode/clip %s" % [found, at_edge, falling])
