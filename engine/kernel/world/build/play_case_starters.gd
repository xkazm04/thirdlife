extends SceneTree
## Lane F3 (27 Nov 2026): the three starter courses (res://kernel/world/build/starters) played by the REAL walker, the
## way a person meets them: each stamp placed by its own ops on natural ground (a terrain box whose top is `GROUND`
## metres into the stamp's floor cell, as the stamp tool puts a stamp on grass: the playtest's 0.7 m curb), a real
## visitor (visitor.gd) steered at a walk (4.5 m/s) from the grass outside the course, build mode's rules in play over
## the real facade (rules_play.gd, play_facade.gd). Not the cell replay of 789: physics, the step, the jump, the pads.
## Prints `HOME starters-walked.<case> ok|fail <detail>`, `HOME starters-walked ok|fail`, `HOME DONE`; selftest 799
## (engine/tools/selftest.d/799-home-starters-walked.sh) reads them. Frames, not wall clock.
##   pad      Pad hop held W at a walk from the grass: up the stairs, the start, three launches, no hazard, the finish
##   padrun   the same with a run held (9 m/s): finishes (a run lands on the next pad and chains), no hazard
##   padlet   W let go the moment each pad throws him and pressed again on landing: still lands, finishes
##   tower    Tower climb at a walk, each hop jumped LEAD m before the step's edge (0.3, 0.6, 0.9 m): finishes, 3 coins
##   garden   Garden gate: to the gate (stopped there), the E prompt shown, E, through, the three coins, the flag
##   ground   the curb: from grass at 0.0, 0.3, 0.6 and 0.9 m into the floor cell he walks onto every course's floor

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const BuildMode := preload("res://kernel/world/build/build_mode.gd")
const StampFile := preload("res://kernel/world/build/stamp_file.gd")
const Space := preload("res://kernel/world/terrain/world_space.gd")
const Visitor := preload("res://kernel/world/visitor.gd")
const Tiers := preload("res://kernel/world/tiers.gd")
const PlayLooks := preload("res://kernel/world/build/play_looks.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const DIR := "res://kernel/world/build/starters"
const TMP := "user://tl_starters_walked_case"
const WALK := 4.5
const RUN := 9.0
const GROUND := 0.3

var ok_all := true
var land: Node3D
var sp: RefCounted
var b: RefCounted
var bm: Node
var v: Node3D
var p: RefCounted
var e_now := [false]
var t := 0
var n_world := 0


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME starters-walked.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func stamp(slug: String) -> Dictionary:
	var l: Dictionary = StampFile.list(ProjectSettings.globalize_path(DIR))
	for s: Dictionary in l.stamps:
		if str(s.slug) == slug:
			return s.stamp
	return {}


## A world of its own: terrain whose top is `g` m above y 0, the stamp `slug` placed with its box's corner at `at`
## (the recipe's lo: stamp_starters_make.gd's cells are the world's), a visitor at `from` facing `facing`.
func make(slug: String, at: Vector3i, g: float, from: Vector3, facing: Vector3) -> String:
	n_world += 1
	land = Node3D.new()
	land.name = "Land%d" % n_world
	root.add_child(land)
	sp = Space.new()
	sp.set("tag", "terrain")
	sp.call("add_box", Transform3D(Basis(), Vector3(0, g - 1.0, 0)), Vector3(120, 2, 120))
	sp.call("finish")
	land.set_meta(&"tl_space", sp)
	b = HomeBuild.new(land, sp, {"seed": 11})
	b.protect.visitor_at = func() -> Vector3: return Vector3(500, 0, 500)     # he is not there yet: placed from afar
	var st := stamp(slug)
	if st.is_empty():
		return "no starter %s" % slug
	var po: Dictionary = StampFile.placed_ops(b, st, at, 0)
	var r: Dictionary = b.apply(po.ops)
	if not bool(r.get("ok", false)):
		return "placing %s refused: %s" % [slug, str(r.get("reason", r))]
	b.flush()
	v = Visitor.new()
	land.add_child(v)
	v.setup(from, facing)
	v.steer_on()
	bm = BuildMode.new()
	bm.set("build", b)
	bm.set("feet_at", func() -> Vector3: return v.feet)
	bm.set("dir", ProjectSettings.globalize_path(TMP).path_join(slug + str(n_world)))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP).path_join(slug + str(n_world)))
	root.add_child(bm)
	p = bm.get("play")
	p.set("visitor", v)
	p.set("use_at", func() -> bool: return e_now[0])
	p.set("sched", Tiers.new())
	return ""


func free_world() -> void:
	if bm != null:
		bm.free()
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
	await wait(2)


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func frame(wish: Vector3, e := false, jump := false) -> void:
	await physics_frame
	t += 1
	e_now[0] = e
	v.call("wish", wish, jump, false)
	v.call("step", v.feet, t)


## Walks toward each leg's point (x, z) at its speed; a leg's `jumps` are distances to its point at which Space goes
## down once; "E" presses the use key; ["wait", n] stands. `stop` (Callable) ends the walk early. Returns frames.
func walk(legs: Array, stop: Callable, max_f := 1800, letgo := false) -> int:
	var f := 0
	for leg: Variant in legs:
		if leg is String and str(leg) == "E":
			await frame(Vector3.ZERO, true)
			f += 1
			continue
		if leg is Array and str(leg[0]) == "wait":
			for i: int in int(leg[1]):
				await frame(Vector3.ZERO)
				f += 1
			continue
		var to: Vector2 = leg[0]
		var speed: float = leg[1]
		var jumps: Array = (leg[2] as Array).duplicate() if leg.size() > 2 else []
		jumps.sort()
		jumps.reverse()
		var still := 0
		var last: Vector3 = v.feet
		while f < max_f:
			var d := Vector2(to.x - v.feet.x, to.y - v.feet.z)
			if d.length() < 0.25 or bool(stop.call()):
				break
			var jump := false
			if not jumps.is_empty() and d.length() <= float(jumps[0]):
				jumps.pop_front()
				jump = true
			var w := Vector3(d.x, 0, d.y).normalized() * speed
			if letgo and str(v.get("mode")) == "air" and int(p.get("facade").get("launched")) > 0:
				w = Vector3.ZERO
			await frame(w, false, jump)
			f += 1
			still = still + 1 if v.feet.distance_to(last) < 0.002 else 0
			last = v.feet
			if still > 40:
				break                                # blocked (a gate): the next leg says what he does
		if bool(stop.call()) or f >= max_f:
			break
	return f


func finished(run_name: String) -> Callable:
	return func() -> bool: return str((p.get("run").get("last_finish") as Dictionary).get("run", "")) == run_name


func result(run_name: String, frames: int) -> Dictionary:
	var fac: RefCounted = p.get("facade")
	var lf: Dictionary = p.get("run").get("last_finish")
	var st: Dictionary = p.get("run").call("state")
	var coins := int((st.counters as Dictionary).get("coins", 0))
	if lf.has("run"):
		coins = _coins_at_finish
	return {"done": str(lf.get("run", "")) == run_name, "frames": int(lf.get("frames", -1)), "walked": frames,
		"launches": int(fac.get("launched")), "respawns": int(fac.get("teleports")), "feet": v.feet, "coins": coins,
		"plays": int((p.get("records").call("of", run_name) as Dictionary).get("plays", 0)) if p.get("records") != null else -1}


var _coins_at_finish := 0


func run() -> void:
	TLStyle.set_headless(false)
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	DirAccess.make_dir_recursive_absolute(TMP)
	await pad_case("pad", WALK, false)
	await pad_case("padrun", RUN, false)
	await pad_case("padlet", WALK, true)
	await tower_case()
	await garden_case()
	await ground_case()
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	PlayLooks._meshes.clear()
	print("HOME starters-walked %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


## Watches the coins counter (a finish clears nothing, but read it the frame the run ends).
func coin_watch(run_name: String) -> Callable:
	return func() -> bool:
		var st: Dictionary = p.get("run").call("state")
		if bool(st.running):
			_coins_at_finish = int((st.counters as Dictionary).get("coins", 0))
		return str((p.get("run").get("last_finish") as Dictionary).get("run", "")) == run_name


func pad_case(name: String, speed: float, letgo: bool) -> void:
	var why := make("pad-hop", Vector3i(-5, 0, -1), GROUND, Vector3(-8.0, GROUND, 2.5), Vector3.RIGHT)
	if why != "":
		say(name, false, why)
		return
	var f := await walk([[Vector2(23.5, 2.5), speed]], finished("Pad hop"), 1500, letgo)
	var r := result("Pad hop", f)
	say(name, bool(r.done) and int(r.launches) == 3 and int(r.respawns) == 0 and int(r.plays) == 1,
		"at %.1f m/s%s: finished %s in %d frames (run clock), %d launches, %d respawns, plays %d, feet %s" % [
			speed, " (W let go in the air)" if letgo else "", r.done, int(r.frames), int(r.launches), int(r.respawns), int(r.plays), str(r.feet)])
	await free_world()


func tower_case() -> void:
	var parts := []
	var ok := true
	for lead: float in [0.3, 0.6, 0.9]:
		var why := make("tower-climb", Vector3i(-1, 0, -1), GROUND, Vector3(-3.5, GROUND, 1.0), Vector3.RIGHT)
		if why != "":
			say("tower", false, why)
			return
		_coins_at_finish = 0
		# leg 1 along +x on z 1.0 (the steps are 2 wide: z 0..1): step 1 walked up, hops off steps 1 and 2 before x 5
		# and x 8 (their edges), to the corner step's middle; leg 2 along +z on x 10.0: hops before z 2, 5, 8
		var legs := [[Vector2(10.0, 1.0), WALK, [10.0 - 5.0 + lead, 10.0 - 8.0 + lead]],
			[Vector2(10.0, 10.5), WALK, [10.5 - 2.0 + lead, 10.5 - 5.0 + lead, 10.5 - 8.0 + lead]]]
		var f := await walk(legs, coin_watch("Tower climb"), 1200)
		var r := result("Tower climb", f)
		var good := bool(r.done) and int(r.coins) == 3
		ok = ok and good
		parts.append("lead %.1f m: %s in %d frames, %d coins, feet %s" % [lead, "finished" if r.done else "NOT finished", int(r.frames), int(r.coins), str(r.feet)])
		await free_world()
	say("tower", ok, "; ".join(parts))


func garden_case() -> void:
	var why := make("garden-gate", Vector3i(-1, 0, -5), GROUND, Vector3(5.5, GROUND, -7.5), Vector3.BACK)
	if why != "":
		say("garden", false, why)
		return
	_coins_at_finish = 0
	var prompt := [""]
	var watch := coin_watch("Garden gate")
	var stop := func() -> bool:
		var h: Variant = p.get("hud")
		if h is Node and str((h as Node).get("lines").get("prompt", "")) != "":
			prompt[0] = str((h as Node).get("lines").prompt)
		return watch.call()
	var f := await walk([[Vector2(5.5, 0.5), WALK]], stop, 400)
	var at_gate: Vector3 = v.feet
	f += await walk(["E", ["wait", 30], [Vector2(5.5, 2.5), WALK], [Vector2(2.5, 5.5), WALK], [Vector2(3.5, 7.5), WALK],
		[Vector2(8.5, 4.5), WALK], [Vector2(5.5, 9.5), WALK]], stop, 1200)
	var r := result("Garden gate", f)
	say("garden", bool(r.done) and int(r.coins) == 3 and prompt[0] == "open Door 1" and at_gate.z < 0.0,
		"stopped at the gate at z %.2f, the prompt '%s', E; finished %s in %d frames, %d coins, %d respawns" % [
			at_gate.z, prompt[0], r.done, int(r.frames), int(r.coins), int(r.respawns)])
	await free_world()


func ground_case() -> void:
	var parts := []
	var ok := true
	var on := {"pad-hop": [Vector3i(-5, 0, -1), Vector3(-8.0, 0, 2.5), Vector2(-3.5, 2.5)],
		"tower-climb": [Vector3i(-1, 0, -1), Vector3(-3.5, 0, 6.0), Vector2(1.0, 6.0)],
		"garden-gate": [Vector3i(-1, 0, -5), Vector3(5.5, 0, -7.5), Vector2(5.5, -3.8)]}
	for g: float in [0.0, 0.3, 0.6, 0.9]:
		for slug: String in on:
			var c: Array = on[slug]
			var why := make(slug, c[0], g, Vector3((c[1] as Vector3).x, g, (c[1] as Vector3).z), Vector3.RIGHT)
			if why != "":
				say("ground", false, why)
				return
			await walk([[c[2], WALK]], func() -> bool: return false, 240)
			var up: bool = v.feet.y >= 0.99 and Vector2(v.feet.x, v.feet.z).distance_to(c[2]) < 0.5
			ok = ok and up
			if not up:
				parts.append("%s from %.1f: stopped at %s" % [slug, g, str(v.feet)])
			await free_world()
	say("ground", ok, "every course's floor walked onto from grass at 0.0, 0.3, 0.6, 0.9 m into the floor cell%s" % (
		"" if parts.is_empty() else "; BAD " + "; ".join(parts)))
