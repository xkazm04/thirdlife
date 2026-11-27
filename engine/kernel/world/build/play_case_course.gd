extends RefCounted
## Lane P (M6): the scripted walk of selftest 774 (play_case.gd `walk`): a small course in a world space of its own
## (a 40 m floor, no landscape), a real visitor (visitor.gd, steered as a person's keys steer it) and the Home's build
## mode with its rules in play (rules_play.gd and the real facade, play_facade.gd). Frames, not wall clock.
##
## Along -z from (0, 0, 12): Start pad (enter: start "Tower") -> a coin (take, coins + 1) -> a wall of 27 blocks with
## a 3-wide door zone in it and a Switch pad before it (use: open the door, say) -> a Jump pad (launch up 12 m/s,
## forward 4.5 m/s; close the door) -> a 2-high platform -> a Checkpoint pad on it -> off its side onto Lava (enter:
## respawn) -> out of the world (no ground: respawn_now) -> the Flag (enter: finish) -> back to the Start (coins back).

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const BuildMode := preload("res://kernel/world/build/build_mode.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const Space := preload("res://kernel/world/terrain/world_space.gd")
const Visitor := preload("res://kernel/world/visitor.gd")
const Tiers := preload("res://kernel/world/tiers.gd")
const Check := preload("res://kernel/world/build/rules_check.gd")
const RR := preload("res://kernel/world/build/rules_run.gd")
const SPEED := 4.5

var tree: SceneTree
var land: Node3D
var sp: RefCounted
var b: RefCounted
var bm: Node
var v: Node3D
var p: RefCounted
var sched: RefCounted
var e_now := [false]
var t := 0
var log := []                            # what happened, in order: [frame, what]


func _init(tr: SceneTree) -> void:
	tree = tr


static func zone(n: int, lo: Array, hi: Array, look: String, name: String) -> Dictionary:
	return {"op": "zone", "id": n, "box": [lo, hi], "look": look, "name": name}


static func rule(n: int, when: Dictionary, effects: Array) -> Dictionary:
	return {"op": "rule", "id": n, "when": when, "do": effects}


static func ops() -> Array:
	return [
		zone(1, [-1, 0, 8], [1, 1, 10], "pad", "Start"), zone(2, [0, 0, 5], [0, 1, 5], "coin", "Coin"),
		zone(3, [-1, 0, 2], [1, 2, 2], "none", "Door"), zone(4, [-1, 0, 3], [1, 1, 3], "pad", "Switch"),
		zone(5, [-1, 0, -1], [1, 0, -1], "pad", "Jump"), zone(6, [-1, 2, -6], [1, 3, -5], "pad", "Checkpoint"),
		zone(7, [3, 0, -10], [8, 1, -2], "none", "Lava"), zone(8, [-1, 2, -8], [1, 3, -8], "flag", "Flag"),
		rule(1, {"on": "enter", "zone": 1}, [{"do": "start", "run": "Tower"}]),
		rule(2, {"on": "enter", "zone": 2}, [{"do": "take", "zone": 2}, {"do": "add", "counter": "coins", "by": 1}]),
		rule(3, {"on": "use", "zone": 4}, [{"do": "open", "zone": 3}, {"do": "say", "text": "The door slides open", "frames": 90}]),
		rule(4, {"on": "enter", "zone": 5}, [{"do": "launch", "up_cm": 1200, "fwd_cm": 450}, {"do": "close", "zone": 3}]),
		rule(5, {"on": "enter", "zone": 6}, [{"do": "checkpoint", "zone": 6}, {"do": "say", "text": "Checkpoint", "frames": 60}]),
		rule(6, {"on": "enter", "zone": 7}, [{"do": "respawn"}]),
		rule(7, {"on": "enter", "zone": 8}, [{"do": "finish"}]),
	]


## The world: the floor, the wall and the platform, the zones and rules; build mode mounted (off: the rules run).
func make(root: Node, dir: String) -> String:
	land = Node3D.new()
	land.name = "Land"
	root.add_child(land)
	sp = Space.new()
	sp.set("tag", "terrain")
	sp.call("add_box", Transform3D(Basis(), Vector3(0, -0.5, 0)), Vector3(40, 1, 40))
	sp.call("finish")
	land.set_meta(&"tl_space", sp)
	b = HomeBuild.new(land, sp, {"seed": 11})
	var cells := []
	for y: int in 3:
		for x: int in range(-4, 5):
			cells.append(Vector3i(x, y, 2))
	for y: int in 2:
		for z: int in range(-9, -2):
			for x: int in range(-2, 3):
				cells.append(Vector3i(x, y, z))
	b.begin_batch()
	for c: Vector3i in cells:
		var r: Dictionary = b.place(c, Blocks.code(Blocks.CUBE, 1))
		if not bool(r.get("ok", false)):
			b.end_batch()
			return "block %s refused: %s" % [str(c), str(r)]
	b.end_batch()
	var r2: Dictionary = b.apply(ops())
	if not bool(r2.get("ok", false)):
		return "zones/rules refused: %s" % str(r2)
	b.flush()
	v = Visitor.new()
	land.add_child(v)
	v.setup(Vector3(0, 0, 12), Vector3.FORWARD)
	v.steer_on()
	bm = BuildMode.new()
	bm.set("build", b)
	bm.set("feet_at", func() -> Vector3: return v.feet)
	bm.set("dir", dir)
	root.add_child(bm)
	p = bm.get("play")
	p.set("visitor", v)
	p.set("use_at", func() -> bool: return e_now[0])
	sched = Tiers.new()
	p.set("sched", sched)
	return ""


## One frame of a person's keys: `wish` (m/s, world axes) before the visitor's step, as view.gd does at 100000; build
## mode ticks the rules after it (150000).
func frame(wish: Vector3, e := false, jump := false) -> void:
	await tree.physics_frame
	t += 1
	e_now[0] = e
	v.call("wish", wish, jump, false)
	v.call("step", v.feet, t)


## Walks with `wish` until `done` (a Callable over nothing) is true or `max_f` frames; returns the frames walked.
func walk_until(wish: Vector3, done: Callable, max_f: int) -> int:
	for i: int in max_f:
		await frame(wish)
		if bool(done.call()):
			return i + 1
	return -1


func ray_hits(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [sp.get("body")]
	return not PhysicsServer3D.space_get_direct_state(sp.get("space")).intersect_ray(q).is_empty()


## The whole walk: returns {"ok", "text", "calls"} (calls: the facade's log, for determinism).
func walk() -> Dictionary:
	var bad := []
	var fac: RefCounted = p.get("facade")
	var run: RefCounted = p.get("run")
	var hud: Node = null
	var fwd := Vector3(0, 0, -SPEED)
	await walk_until(Vector3.ZERO, func() -> bool: return bool(p.get("running")), 10)
	var looks_n: int = p.get("looks").call("count")
	if looks_n != 6:
		bad.append("%d looks made (want 6: pads Start, Switch, Jump, Checkpoint, a coin, a flag)" % looks_n)
	# 1. start, the coin, the wall: blocked at the door
	var still := [0, v.feet.z]
	var stopped := await walk_until(fwd, func() -> bool:
		still[0] = still[0] + 1 if absf(v.feet.z - float(still[1])) < 0.001 else 0
		still[1] = v.feet.z
		return still[0] >= 10, 400)
	var st: Dictionary = run.call("state")
	hud = p.get("hud")
	var hl: Dictionary = hud.get("lines") if hud != null else {}
	if stopped < 0 or v.feet.z < 3.2 or v.feet.z > 3.5 or not bool(st.running) or str(st.run) != "Tower" or int((st.counters as Dictionary).get("coins", 0)) != 1:
		bad.append("to the door: stopped %d at z %.2f, state %s" % [stopped, v.feet.z, str(st)])
	if not bool(p.get("looks").call("is_hidden", 2)):
		bad.append("the coin's look is not hidden after it was taken")
	if str(hl.get("run", "")) != "Tower" or str(hl.get("clock", "")) != hud.call("clock", int(st.frames)) or str(hl.get("counters", "")) != "coins 1":
		bad.append("HUD %s against state %s" % [str(hl), str(st)])
	var solid_before := ray_hits(Vector3(0, 0.5, 4.5), Vector3(0, 0.5, 0.5))
	# 2. E elsewhere keeps a game's enter; E on the Switch takes it back and opens the door
	var claimed0: int = p.get("claimed")
	sched.call("request", "enter")
	await frame(Vector3.ZERO, true)
	await frame(Vector3.ZERO)                  # (what a frame's tick did is read in the next frame: build mode ticks after this)
	var opened: bool = run.call("is_open", 3)
	var asks_after: int = (sched.get("_requests") as Array).size()
	await frame(Vector3.ZERO)
	await frame(Vector3.ZERO)
	var passable := not ray_hits(Vector3(0, 0.5, 4.5), Vector3(0, 0.5, 0.5))
	var say_line := str((hud.get("lines") as Dictionary).get("say", ""))
	var door_node: Variant = (p.get("doors").get("slides") as Dictionary).get(3, {}).get("node")
	var sliding := door_node is Node3D and (door_node as Node3D).position.y < -0.05
	if not solid_before or not opened or asks_after != 0 or int(p.get("claimed")) != claimed0 + 1 or not passable or say_line != "The door slides open" or not sliding:
		bad.append("door: solid before %s, open after E %s, enter requests left %d, claimed %d, passable %s, say '%s', slide %s" % [
			solid_before, opened, asks_after, int(p.get("claimed")) - claimed0, passable, say_line, sliding])
	# 3. through the door onto the Jump pad: launched onto the platform
	var high := [0.0]
	var landed := await walk_until(fwd, func() -> bool:
		high[0] = maxf(high[0], v.feet.y)
		return v.feet.z < -2.6 and str(v.mode) == "ground", 240)
	var launches: int = fac.get("launched")
	if launches != 1 or landed < 0 or absf(v.feet.y - 2.0) > 0.05 or high[0] < 2.6:
		bad.append("jump pad: launched %d, landed after %d frames at %s, highest feet %.2f" % [launches, landed, str(v.feet), high[0]])
	await walk_until(Vector3.ZERO, func() -> bool: return int(p.get("doors").call("moving")) == 0, 60)
	var closed := not bool(run.call("is_open", 3)) and ray_hits(Vector3(0, 0.5, 4.5), Vector3(0, 0.5, 0.5))
	if not closed:
		bad.append("the door is not solid again after it closed (open %s)" % bool(run.call("is_open", 3)))
	# 4. the checkpoint, then off the side onto the Lava: respawned at the checkpoint
	var cp := await walk_until(fwd, func() -> bool: return RR.feet_cell(v.feet).z <= -5, 120)
	await frame(Vector3.ZERO)
	var respawn: Vector3 = run.call("state").respawn
	var want_cp := Check.floor_centre([[-1, 2, -6], [1, 3, -5]])
	var tele0: int = fac.get("teleports")
	var lava := await walk_until(Vector3(SPEED, 0, 0), func() -> bool: return int(fac.get("teleports")) > tele0, 240)
	await frame(Vector3.ZERO)
	var back: Vector3 = v.feet
	if cp < 0 or respawn != want_cp or lava < 0 or back.distance_to(want_cp) > 0.1:
		bad.append("checkpoint after %d frames, respawn %s (want %s); lava respawn after %d frames, feet %s" % [cp, str(respawn), str(want_cp), lava, str(back)])
	# 5. out of the world: no ground under him, below the grid -> respawn_now at the checkpoint
	v.call("put", Vector3(100, -40, 0), float(v.get("look_yaw")), false)
	var falls0: int = p.get("falls")
	var out := await walk_until(Vector3.ZERO, func() -> bool: return int(p.get("falls")) > falls0, 30)
	await frame(Vector3.ZERO)
	if out < 0 or v.feet.distance_to(want_cp) > 0.1:
		bad.append("out of the world: respawned after %d frames, feet %s" % [out, str(v.feet)])
	# 6. the flag: finished, the card, the records
	var fin := await walk_until(fwd, func() -> bool: return not bool(run.get("running")), 120)
	await frame(Vector3.ZERO)
	var lf: Dictionary = run.get("last_finish")
	var card := str((hud.get("lines") as Dictionary).get("card", ""))
	var recs: RefCounted = p.get("records")
	var rec: Dictionary = recs.call("of", "Tower") if recs != null else {}
	if fin < 0 or str(lf.get("run", "")) != "Tower" or not bool(lf.get("new_best", false)) or not card.begins_with("New best! | Tower | ") \
			or int(rec.get("finishes", 0)) != 1 or int(rec.get("plays", 0)) != 1 or int(rec.get("best_frames", -1)) != int(lf.get("frames", -2)):
		bad.append("finish after %d frames: last_finish %s, card '%s', record %s" % [fin, str(lf), card, str(rec)])
	# 7. back to the Start: a new run, the coin back
	v.call("put", Vector3(0, 0, 9.5), float(v.get("look_yaw")), false)
	await frame(Vector3.ZERO)
	await frame(Vector3.ZERO)
	var again: bool = run.get("running")
	var coin_back := not bool(p.get("looks").call("is_hidden", 2)) and not bool(run.call("is_taken", 2))
	rec = recs.call("of", "Tower") if recs != null else {}
	if not again or not coin_back or int(rec.get("plays", 0)) != 2 or str((hud.get("lines") as Dictionary).get("card", "x")) != "":
		bad.append("restart: running %s, coin back %s, record %s, card '%s'" % [again, coin_back, str(rec), str((hud.get("lines") as Dictionary).get("card", ""))])
	# 8. E with no use zone under him: the game's enter stays
	sched.call("request", "enter")
	await frame(Vector3.ZERO, true)
	await frame(Vector3.ZERO)
	var kept := (sched.get("_requests") as Array).size()
	if kept != 1:
		bad.append("E outside a use zone: %d enter requests left (want 1)" % kept)
	return {"ok": bad.is_empty(), "calls": str(fac.get("calls")), "finish": lf,
		"text": "door stop z %.2f, E opened it (enter request taken back), passable, slide, closed solid; launched to %.2f m, landed on the platform; checkpoint, lava and out-of-world respawns; finish %d frames (%s), card, records %s; restart: coin back%s" % [
			still[1], high[0], int(lf.get("frames", -1)), str(lf.get("new_best", "")), str(rec), "" if bad.is_empty() else "; BAD " + "; ".join(bad)]}


func free_all() -> void:
	if bm != null:
		bm.free()                                  # its exit drops the run and frees the Home's meshes and bodies
	if b != null:
		b.free_all()
	if land != null:
		land.free()
	if sp != null:
		sp.call("free_all")
	bm = null
	land = null
	v = null
	p = null
	b = null
	sp = null
	sched = null
