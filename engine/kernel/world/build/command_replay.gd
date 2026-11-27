extends RefCounted
## M6 lane C (27 Nov 2026): a headless replay of a Home's runs over a scripted walk, to say whether a course a person
## would meet can be finished when lane P's play (the looks, the mask, the HUD) is not in the tree. The walk is the
## space check's (command_space.gd): from the start zone it goes to the nearest coin it can reach, then the next, then
## to the nearest finish, over the standable cells (walks, steps, jumps within the check's limits). The runtime is the
## seam's rules_run.gd with a recording facade, stepped once per physics frame (FRAMES_PER_CELL frames in each feet
## cell, E never pressed), so the rules fire as they would for a walker who keeps to that path: start, coins taken,
## checkpoints, finish. It does not move a body: a launch or a teleport is not followed (the path already holds it).
## Static; reads the Home, never writes it.

const Space := preload("res://kernel/world/build/command_space.gd")
const RulesRun := preload("res://kernel/world/build/rules_run.gd")
const FRAMES_PER_CELL := 8              # physics frames in each feet cell of the walk (a cell at a run's 7.5 m/s)


## What the rules did: [frame, method, args...] (as rules_case_run.gd's Rec).
class Rec extends "res://kernel/world/build/rules_facade.gd":
	var log := []
	var run: WeakRef = null
	func _f() -> int: return int(run.get_ref().get("frame")) if run != null and run.get_ref() != null else -1
	func set_open(z: int, _box: Array, o: bool) -> void: log.append([_f(), "set_open", z, o])
	func look_taken(z: int, t: bool) -> void: log.append([_f(), "look_taken", z, t])
	func launch(u: int, f: int) -> void: log.append([_f(), "launch", u, f])
	func teleport(at: Vector3) -> void: log.append([_f(), "teleport", at])
	func say(t: String, n: int) -> void: log.append([_f(), "say", t, n])
	func run_started(n: String, fr: int) -> void: log.append([_f(), "run_started", n, fr])
	func run_finished(n: String, fr: int, best: int, nb: bool) -> void: log.append([_f(), "run_finished", n, fr, best, nb])
	func run_stopped(n: String, why: String) -> void: log.append([_f(), "run_stopped", n, why])


## Every run of the Home's rules (`build`: home_build.gd; `land`: the landscape node or null) walked and replayed:
## {"space": command_space.gd's check of every zone and rule, "runs": [{"run", "reachable" (the check's), "walk": feet
## cells walked, "coins", "coins_on_walk", "taken": coins the rules took, "finished": bool, "frames": the run's time
## in frames (-1 when not finished), "says": [text], "log": the facade's calls}]}.
static func replay(build: RefCounted, land: Node) -> Dictionary:
	var rl: RefCounted = build.layer("rules")
	var sp: Dictionary = Space.check(build, land, {"scratch": {"blocks": build.layer("blocks"), "rules": rl}}, true)
	var out := {"space": sp, "runs": []}
	var g: RefCounted = sp.grid
	if g == null:
		return out
	var zones: Dictionary = rl.get("zones")
	var mv := Space.moves(rl.get("rules"))
	for run: Dictionary in sp.runs:
		var res := {"run": run.run, "reachable": run.reachable, "walk": [], "coins": run.coins, "coins_on_walk": 0, "taken": 0,
			"finished": false, "frames": -1, "says": [], "log": []}
		if int(run.start) >= 0:
			var w := tour(g, zones, run, mv)
			res.walk = w.cells
			res.coins_on_walk = w.coins
			var played := play(rl, w.cells)
			res.merge(played, true)
		(out.runs as Array).append(res)
	return out


## The walk of `run`: from its start zone to each coin zone it can reach without crossing a finish, the nearest first,
## then to the nearest finish (or as far as it got). {"cells": [Vector3i], "coins": coins on it}.
static func tour(g: RefCounted, zones: Dictionary, run: Dictionary, mv: Dictionary) -> Dictionary:
	var starts: Array = g.call("nodes_in", zones[int(run.start)].box)
	if starts.is_empty():
		return {"cells": [], "coins": 0}
	var cells := [starts[0]]
	var left := zones.values().filter(func(z: Dictionary) -> bool: return str(z.look) == "coin")
	var got := 0
	var finish := {}                        # the finish cells: walked round while coins are left (they end the run)
	for f: int in run.finish:
		for c: Vector3i in g.call("nodes_in", zones[f].box):
			finish[c] = true
	while true:
		var walk: Dictionary = g.call("walk", [cells[cells.size() - 1]], zones, mv.launches, mv.teleports, {} if left.is_empty() else finish)
		var best := {}
		for z: Dictionary in left:
			for c: Vector3i in g.call("nodes_in", z.box):
				if walk.has(c) and (best.is_empty() or int(walk[c][1]) < int(best.steps)):
					best = {"zone": z, "cell": c, "steps": int(walk[c][1])}
		if best.is_empty():
			if not left.is_empty():         # round 3 (A6): coins out of reach no longer fence the finish off
				walk = g.call("walk", [cells[cells.size() - 1]], zones, mv.launches, mv.teleports)
			for f: int in run.finish:
				for c: Vector3i in g.call("nodes_in", zones[f].box):
					if walk.has(c) and (best.is_empty() or int(walk[c][1]) < int(best.steps)):
						best = {"cell": c, "steps": int(walk[c][1])}
			if not best.is_empty():
				cells.append_array(Space.path_to(walk, best.cell).slice(1))
			break
		cells.append_array(Space.path_to(walk, best.cell).slice(1))
		left.erase(best.zone)
		got += 1
	return {"cells": cells, "coins": got}


## The rules stepped over `cells` (FRAMES_PER_CELL frames each, then 2 s standing at the end): {"taken", "finished",
## "frames", "says", "log"}.
static func play(rl: RefCounted, cells: Array) -> Dictionary:
	var rec := Rec.new()
	var run: RefCounted = RulesRun.new(rl, rec, null)
	rec.run = weakref(run)
	if cells.is_empty():
		return {}
	var c0: Vector3i = cells[0]
	run.begin(0, Vector3(c0.x + 0.5, c0.y, c0.z + 0.5))
	var f := 0
	for c: Vector3i in cells:
		for k in FRAMES_PER_CELL:
			f += 1
			run.step(f, c, false)
	for k in 120:
		f += 1
		run.step(f, cells[cells.size() - 1], false)
	var taken := 0
	var says := []
	for e: Array in rec.log:
		if str(e[1]) == "look_taken" and bool(e[3]):
			taken += 1
		elif str(e[1]) == "say":
			says.append(str(e[2]))
	var fin: Dictionary = run.get("last_finish")
	return {"taken": taken, "finished": not fin.is_empty(), "frames": int(fin.get("frames", -1)), "says": says, "log": rec.log}
