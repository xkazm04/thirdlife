class_name Site
extends Node3D
## Live-construction language: hologram rib -> built rib dissolve (site_advance), bots that go to work on it,
## crane sway. All procedural from sim time so captures with --t are deterministic.

var style: Style
var ribs: Array = []
var cranes: Array = []
var bots: Array = []
var active: Dictionary = {}
var arena_c: Vector3
var sim_t: float = 0.0
var holo_t: float = 0.0
const DISSOLVE := 3.0


func setup(st: Style, ribs_in: Array, cranes_in: Array, centre: Vector3, bot_defs: Array) -> void:
	style = st
	ribs = ribs_in
	cranes = cranes_in
	arena_c = centre
	for bd: Dictionary in bot_defs:
		var b := BotUnit.new()
		add_child(b)
		b.setup(st, bd["state"], bd["yaw"])
		b.position = Vector3(bd["pos"][0], bd["pos"][1], bd["pos"][2])
		b.set_meta("home_state", bd["state"])
		b.home = b.position
		bots.append(b)


func next_rib() -> int:
	for i in ribs.size():
		if not ribs[i]["built"] and not ribs[i]["done"] and not active.has(i):
			return i
	return -1


func advance() -> void:
	var i := next_rib()
	if i < 0:
		return
	var rib: Dictionary = ribs[i]
	# the 3 bots nearest to the rib front go to work on it
	var target := Vector3(rib["x"] + 1.6, arena_c.y, arena_c.z - 21.6 + 22.0 * 2.0 - 0.0)
	target = Vector3(rib["x"] + 1.8, arena_c.y, -51.3)
	var order := bots.duplicate()
	order.sort_custom(func(a: BotUnit, b: BotUnit) -> bool: return a.home.distance_to(target) < b.home.distance_to(target))
	var offs := [Vector3(0, 0, 0), Vector3(-2.2, 0, 0.2), Vector3(-4.0, 0, -0.1)]
	var crew: Array = []
	for k in 3:
		var b: BotUnit = order[k]
		var tgt := target + offs[k]
		tgt.y = b.home.y if b.home.y > arena_c.y + 0.5 else arena_c.y
		b.yaw = 0.0
		b.go_to(tgt, func(bb: BotUnit) -> void: bb.set_state("work"))
		crew.append(b)
	active[i] = {"t": -1.0, "crew": crew, "go": 0.0}


func _process(delta: float) -> void:
	sim_t += delta
	holo_t += delta
	# crane sway
	for c: Dictionary in cranes:
		var ph: float = c["phase"]
		var sw: float = c["sway"]
		(c["head"] as Node3D).rotation.y = float(c["yaw"]) + 0.035 * sw * sin(sim_t * 0.31 + ph)
		var l: Node3D = c["load"]
		l.rotation.z = 0.075 * sw * sin(sim_t * 0.95 + ph)
		l.rotation.x = 0.05 * sw * sin(sim_t * 0.71 + ph * 1.7)
	# hologram shimmer
	for rib: Dictionary in ribs:
		if not rib["built"] and not rib["done"]:
			(rib["hm"] as ShaderMaterial).set_shader_parameter(&"time_s", holo_t)
	# active dissolves
	for i: int in active.keys():
		var a: Dictionary = active[i]
		var rib: Dictionary = ribs[i]
		# wait until at least one bot arrived (state work), max 5 s
		a["go"] += delta
		var arrived := false
		for b: BotUnit in a["crew"]:
			if b.state == "work":
				arrived = true
		if a["t"] < 0.0 and (arrived or a["go"] > 4.5):
			a["t"] = 0.0
		if a["t"] >= 0.0:
			a["t"] += delta
			var p := clampf(a["t"] / DISSOLVE, 0.0, 1.0)
			(rib["sm"] as ShaderMaterial).set_shader_parameter(&"reveal", p if p < 1.0 else 1.0)
			(rib["wm"] as ShaderMaterial).set_shader_parameter(&"reveal", p)
			(rib["hm"] as ShaderMaterial).set_shader_parameter(&"amount", 1.0 - p)
			if p >= 1.0:
				(rib["wire"] as Node3D).visible = false
				(rib["skin"] as Node3D).visible = false
				rib["done"] = true
				rib["built"] = true
				if a["t"] > DISSOLVE + 1.2:
					for b: BotUnit in a["crew"]:
						b.yaw = 0.0
						b.go_to(b.home, func(bb: BotUnit) -> void: bb.set_state(str(bb.get_meta("home_state"))))
					active.erase(i)


func reset_all() -> void:
	for rib: Dictionary in ribs:
		if rib.get("node") != null:
			rib["done"] = false
			rib["built"] = false
			(rib["sm"] as ShaderMaterial).set_shader_parameter(&"reveal", 0.0)
			(rib["wm"] as ShaderMaterial).set_shader_parameter(&"reveal", 0.0)
			(rib["hm"] as ShaderMaterial).set_shader_parameter(&"amount", 1.0)
			(rib["wire"] as Node3D).visible = true
			(rib["skin"] as Node3D).visible = true
	active.clear()
	for b: BotUnit in bots:
		b.position = b.home
		b.has_target = false
		b.set_state(str(b.get_meta("home_state")))
