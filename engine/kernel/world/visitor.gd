extends Node3D
## N7 / P4. The visitor: the player as a walker between the games of a world. Kernel-owned. P4: he has a BODY: a
## kinematic capsule in a physics space that belongs to the world (terrain/world_space.gd, built by the landscape),
## so he walks on the terrain, stands on a plot's own ground inside the plot, and stops at fences, trees, rocks, walls
## and rails. He is in no pack's physics space and no pack can see him: the packs are untouched.
##
## Where the SCHEDULER thinks he is stays the world's `player_pos` (the walk script, or WASD when a person walks): a
## scripted walk gives the scheduler the scripted position and the body follows it (it cannot pass an obstacle, so it
## can fall behind; `max_dev` says how far, and a walk that is meant to pass must be adjusted); when a person walks,
## the body decides and `player_pos` is set from it each tick.
##
##   visitor.setup(at, facing)      after the node is in the tree (the camera becomes its sibling)
##   visitor.step(pos, frame)       once per world tick; `pos` is the wanted position (feet, x and z matter)
##   visitor.cam                    the chase camera (make it current while nobody is on stage)
## At the last tick of a walk one `tl.view/1` line of kind `visitor` is printed: ticks, ticks blocked, largest and final distance
## between the body and the scripted position.

var rig: Node3D = null
var cam: TLChaseCam = null
var speed: float = 0.0                  # metres per second, from the last two positions of the body
var space: RefCounted = null            # the world's space (terrain/world_space.gd), null when there is no landscape
var feet: Vector3 = Vector3.ZERO        # where the body stands
var max_dev: float = 0.0
var end_dev: float = 0.0
var ticks: int = 0
var catch_up_m: float = 0.5             # metres per tick the body may close on a scripted position it has fallen behind
var _last: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _world: Node = null
var _reported: bool = false
var _logged: int = 0
var _frame_usec: PackedInt64Array = PackedInt64Array()      # the wall time of every frame while he walks (cost line)
var _frame_last: int = 0


func setup(at: Vector3, facing: Vector3 = Vector3.FORWARD, cam_opts: Dictionary = {}) -> void:
	name = "TLVisitor"
	var land: Node = get_parent()
	if land != null and land.has_meta(&"tl_space"):
		space = land.get_meta(&"tl_space")
	var view: Node = land.get_parent() if land != null else null
	_world = view.get("world") if view != null else null
	if space != null:
		var g: float = space.call("ground_at", at.x, at.z, at.y + 80.0)
		if not is_nan(g):
			at.y = g
		space.call("place", at)
	feet = at
	position = at
	_last = at
	if space != null and _world != null:
		var walk: Dictionary = _world.get("walk")
		if typeof(walk.get("visitor_probe")) == TYPE_ARRAY:
			_run_probes(walk["visitor_probe"], land.get_meta(&"tl_probe", {}), at)
	if facing.length() > 0.001:
		_yaw = atan2(-facing.x, -facing.z)
	rotation.y = _yaw
	rig = TLRigs.build("biped", {})
	if rig != null:
		add_child(rig)
	cam = TLChaseCam.new()
	cam.name = "VisitorCam"
	get_parent().add_child(cam)
	var o: Dictionary = {"distance": 8.5, "height": 3.6, "look_height": 1.7, "stiffness": 0.05, "fov": 60.0}
	o.merge(cam_opts, true)
	cam.setup(self, o)


func step(pos: Vector3, frame: int) -> void:
	ticks += 1
	if space != null:
		var want: Vector3 = Vector3(pos.x - feet.x, 0.0, pos.z - feet.z)
		var dist: float = want.length()
		if dist > catch_up_m:
			want = want / dist * catch_up_m
		var res: Dictionary = space.call("walk", feet, want)
		feet = res["pos"]
		if bool(res["blocked"]) and _logged < 6 and (ticks % 30 == 1 or _logged < 2):
			_logged += 1
			var lh: Dictionary = space.get("last_hit")
			print(JSON.stringify({"schema": "tl.view/1", "kind": "visitor_blocked", "world_tick": int(_world.get("tick")) if _world != null else -1,
				"feet": [snappedf(feet.x, 0.01), snappedf(feet.y, 0.01), snappedf(feet.z, 0.01)], "want": [snappedf(pos.x, 0.01), snappedf(pos.z, 0.01)],
				"hit": str(lh.get("tag", "none")), "at": str(lh.get("at", "")), "normal": str(lh.get("n", ""))}, "", false))
		var dev: float = Vector2(pos.x - feet.x, pos.z - feet.z).length()
		max_dev = maxf(max_dev, dev)
		end_dev = dev
		if _world != null and bool(_world.get("player_live")):
			_world.set("player_pos", Vector3(feet.x, pos.y, feet.z))        # a person walks: the body decides
		_report_at_end()
	else:
		feet = pos
	var d: Vector3 = feet - _last
	d.y = 0.0
	speed = d.length() * 60.0
	if speed > 0.2:
		_yaw = lerp_angle(_yaw, atan2(-d.x, -d.z), 0.18)
	position = feet
	rotation.y = _yaw
	_last = feet
	if rig != null and visible:
		rig.call("set_locomotion", Vector3(0.0, 0.0, -speed), true)
		rig.call("tick", frame)


## Probes (a walk's `visitor_probe`): the body is put at `from`, told to walk to `to`, and the line says where it ended.
## `{"name", "from": [x, z], "to": [x, z], "expect": "stop" | "pass"}`; the element "auto" adds a tree, a rock and the
## bridge's rail from the landscape (the first of each on gentle ground). `stop`: the body must end more than 0.5 m
## short of `to`, `pass`: within 0.3 m. Results are printed as `tl.view/1` lines of kind `visitor_probe`; the body is put back.
func _run_probes(list: Array, auto: Dictionary, back_to: Vector3) -> void:
	var probes: Array = []
	for p: Variant in list:
		if typeof(p) == TYPE_STRING and str(p) == "auto":
			if auto.has("tree"):
				var t: Array = auto["tree"]
				probes.append({"name": "tree", "from": [float(t[0]) - 6.0, float(t[1])], "to": [float(t[0]) + 6.0, float(t[1])], "expect": "stop"})
			if auto.has("rock"):
				var r: Array = auto["rock"]
				probes.append({"name": "rock", "from": [float(r[0]) - 6.0, float(r[1])], "to": [float(r[0]) + 6.0, float(r[1])], "expect": "stop"})
			if auto.has("rail"):
				var b: Array = auto["rail"]
				probes.append({"name": "bridge_rail", "from": [float(b[0]), float(b[1])], "to": [float(b[0]) + float(b[2]) * 8.0, float(b[1]) + float(b[3]) * 8.0], "expect": "stop"})
		elif typeof(p) == TYPE_DICTIONARY:
			probes.append(p)
	for pr: Dictionary in probes:
		var f: Array = pr["from"]
		var to: Array = pr["to"]
		var g: float = space.call("ground_at", float(f[0]), float(f[1]), 120.0)
		var pos: Vector3 = Vector3(float(f[0]), 0.0 if is_nan(g) else g, float(f[1]))
		space.call("place", pos)
		var settle: Dictionary = space.call("walk", pos, Vector3.ZERO)
		pos = settle["pos"]
		var target: Vector2 = Vector2(float(to[0]), float(to[1]))
		var still: int = 0
		var steps: int = 0
		var hit: String = "none"
		while steps < 900:
			steps += 1
			var want: Vector2 = target - Vector2(pos.x, pos.z)
			if want.length() < 0.05:
				break
			if want.length() > 0.12:
				want = want.normalized() * 0.12
			var res: Dictionary = space.call("walk", pos, Vector3(want.x, 0.0, want.y))
			var np: Vector3 = res["pos"]
			if Vector2(np.x - pos.x, np.z - pos.z).length() < 0.01:
				still += 1
			else:
				still = 0
			if bool(res["blocked"]):
				hit = str((space.get("last_hit") as Dictionary).get("tag", "slope"))
			pos = np
			if still > 20:
				break
		var short: float = Vector2(pos.x, pos.z).distance_to(target)
		var expect: String = str(pr.get("expect", "stop"))
		var ok: bool = short > 0.5 if expect == "stop" else short < 0.3
		print(JSON.stringify({"schema": "tl.view/1", "kind": "visitor_probe", "name": str(pr.get("name", "")), "expect": expect, "ok": ok, "from": f, "to": to,
			"end": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)], "short_of_target_m": snappedf(short, 0.01), "stopped_by": hit, "ticks": steps}, "", false))
	space.set("blocked_ticks", 0)
	space.call("place", back_to)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _frame_last > 0:
		_frame_usec.append(now - _frame_last)
	_frame_last = now


func _frame_ms(p: float) -> float:
	if _frame_usec.is_empty():
		return 0.0
	var sorted: PackedInt64Array = _frame_usec.duplicate()
	sorted.sort()
	return snappedf(float(sorted[clampi(int(ceil(p * float(sorted.size()))) - 1, 0, sorted.size() - 1)]) / 1000.0, 0.001)


func _report_at_end() -> void:
	if _reported or _world == null or bool(_world.get("player_live")):
		return
	if int(_world.get("tick")) >= int(_world.get("walk_ticks")) - 2:
		_reported = true
		var s: Dictionary = space.get("stats")
		print(JSON.stringify({"schema": "tl.view/1", "kind": "visitor", "ticks": ticks, "blocked_ticks": int(space.get("blocked_ticks")), "max_dev_m": snappedf(max_dev, 0.01),
			"end_dev_m": snappedf(end_dev, 0.01), "frame_ms_p50": _frame_ms(0.5), "frame_ms_p99": _frame_ms(0.99), "frame_ms_max": _frame_ms(1.0), "end": [snappedf(feet.x, 0.01), snappedf(feet.y, 0.01), snappedf(feet.z, 0.01)],
			"space": s}, "", false))


func snap() -> void:
	if cam != null:
		cam.snap()
