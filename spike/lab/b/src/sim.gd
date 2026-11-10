class_name Sim
extends Node3D
## Everything that moves: crane load sway, cars (+nitro), builder bots (idle/work/walk + sparks), hologram->built rib
## conversion (site_advance), the pre-fractured barrier wall (crumble), reset. Driven from _process with a clamped dt.

const CRUISE: float = 14.0
const NITRO_SPEED: float = 31.0
const NITRO_TIME: float = 3.2
const RIB_TIME: float = 3.0
const BOT_SCALE: float = 1.45   # 0.8 m rig -> about 1.15 m (pass-2 contract amendment)

var world: World
var t: float = 0.0
var cars: Array = []
var bots: Array = []
var wall_blocks: Array = []
var wall_bodies: Array = []
var crumbled: bool = false
var crumble_t: float = -1.0
var wall_s: float = 0.0
var wall_side: float = 1.0
var wall_mid: float = 5.5
var active_rib: int = -1
var rib_p: float = 0.0
var dust: CPUParticles3D
var crane_base_yaw: Array = []
var rubble: MeshInstance3D


func setup(w: World) -> void:
	world = w
	for c: Node3D in world.cranes:
		crane_base_yaw.append((c.get_node("Slew") as Node3D).rotation.y)
	_setup_wall()
	_setup_cars()
	_setup_bots()


# ---------------------------------------------------------------------------------------------- wall
func _setup_wall() -> void:
	var road: Path = world.road
	var wa: Vector2 = World.v2(world.L["circuit"]["wall_at"])
	var q: Vector3 = road.query(wa.x, wa.y, 3)
	var i0: int = int(q.z)
	wall_s = road.s[i0]
	# outside of the bend = the side the wall target point is on
	var tg: Vector2 = road.tang[i0]
	var right: Vector2 = Vector2(-tg.y, tg.x)
	wall_side = 1.0 if (wa - road.pts[i0]).dot(right) >= 0.0 else -1.0
	var holder: Node3D = Node3D.new()
	holder.name = "Wall"
	world.add_child(holder)
	var nb: int = int(world.L["circuit"].get("wall_blocks", 12))   # layout C edit: the wall length is layout data
	wall_mid = (float(nb) - 1.0) * 0.5
	for b: int in nb:
		var s: float = wall_s + (float(b) - wall_mid) * 2.46
		var a: Dictionary = road.at(s)
		var tan: Vector3 = a["tan"]
		var rgt: Vector3 = KitRoad.right_of(tan) * wall_side
		var pos: Vector3 = (a["pos"] as Vector3) + rgt * 7.05
		pos.y = world.terrain.h(pos.x, pos.z) + 0.06
		var basis: Basis = Basis(tan, Vector3.UP, tan.cross(Vector3.UP).normalized())
		var data: Dictionary = KitWall.block(2.4, 1.0, 0.8, 8, 700 + b, 0.94 + 0.06 * float(b % 2))
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = data["merged"]
		mi.transform = Transform3D(basis, pos)
		mi.name = "Block%d" % b
		holder.add_child(mi)
		wall_blocks.append({"node": mi, "data": data, "out": rgt, "along": tan})
	var wc: Dictionary = road.at(wall_s)
	var cpos: Vector3 = (wc["pos"] as Vector3) + KitRoad.right_of(wc["tan"]) * wall_side * 7.0
	var col: StaticBody3D = world.terrain.collision_patch(cpos.x, cpos.z, 28.0)
	col.position.y = 0.06
	world.add_child(col)
	dust = Fx.dust_burst(80, 5.0)
	dust.position = cpos + Vector3(0, 0.5, 0)
	dust.rotation.y = atan2(-(wc["tan"] as Vector3).z, (wc["tan"] as Vector3).x)
	world.add_child(dust)


func crumble() -> void:
	if crumbled:
		return
	crumbled = true
	crumble_t = t
	var holder: Node3D = world.get_node("Wall")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	for b: int in wall_blocks.size():
		var blk: Dictionary = wall_blocks[b]
		var mi: MeshInstance3D = blk["node"]
		var k: float = exp(-pow(float(b) - wall_mid, 2.0) / 5.0)
		if k < 0.16:
			continue   # the far blocks hold; only the hit section breaks up
		mi.visible = false
		for ch: Dictionary in (blk["data"]["chunks"] as Array):
			var body: RigidBody3D = RigidBody3D.new()
			var cs: CollisionShape3D = CollisionShape3D.new()
			var sh: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
			sh.points = ch["pts"]
			cs.shape = sh
			body.add_child(cs)
			var m: MeshInstance3D = MeshInstance3D.new()
			m.mesh = ch["mesh"]
			body.add_child(m)
			body.mass = 120.0
			body.transform = mi.transform * Transform3D(Basis.IDENTITY, ch["centre"])
			holder.add_child(body)
			var out: Vector3 = blk["out"]
			var along: Vector3 = blk["along"]
			var hy: float = (ch["centre"] as Vector3).y
			body.linear_velocity = out * (0.3 + 6.0 * k * rng.randf()) + Vector3.UP * (0.2 + (2.0 + 3.0 * hy) * k * rng.randf()) + along * (rng.randf() - 0.5) * 3.0 * k
			body.angular_velocity = Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5) * 9.0 * k
			wall_bodies.append(body)
	dust.restart()
	dust.emitting = true


## Once every chunk sleeps, bake the rubble into ONE static mesh and free the bodies: frame cost returns to baseline.
func _bake_rubble() -> void:
	var holder: Node3D = world.get_node("Wall")
	var items: Array = []
	for b: RigidBody3D in wall_bodies:
		items.append([(b.get_child(1) as MeshInstance3D).mesh, b.transform])
		b.queue_free()
	wall_bodies.clear()
	var rub: MeshInstance3D = MeshInstance3D.new()
	rub.name = "Rubble"
	rub.mesh = MK.merge(items, "rubble")
	holder.add_child(rub)
	rubble = rub
	print("[wall] settled: rubble baked to 1 mesh at t=%.1f s after crumble" % (t - crumble_t))


func wall_awake() -> int:
	var n: int = 0
	for b: RigidBody3D in wall_bodies:
		if not b.sleeping:
			n += 1
	return n


# ---------------------------------------------------------------------------------------------- cars
func _setup_cars() -> void:
	var specs: Array = [["car_blue", "car_white", float(world.L["circuit"].get("car_a", 5.0)), 1.9, false], ["car_red", "car_white", float(world.L["circuit"].get("car_b", -9.0)), -1.9, true]]
	for sp: Array in specs:
		var n: Node3D = KitCar.build(String(sp[0]), String(sp[1]), bool(sp[4]))
		world.add_child(n)
		cars.append({"node": n, "s0": wall_s + float(sp[2]), "s": wall_s + float(sp[2]), "lane": float(sp[3]), "v": CRUISE, "nitro": 0.0, "is_b": bool(sp[4])})
	(cars[0]["node"] as Node3D).name = "CarA"
	(cars[1]["node"] as Node3D).name = "CarB"
	_place_cars(0.0)


func _place_cars(dt: float) -> void:
	var road: Path = world.road
	for c: Dictionary in cars:
		var n: Node3D = c["node"]
		var target: float = CRUISE
		if float(c["nitro"]) > 0.0:
			c["nitro"] = float(c["nitro"]) - dt
			target = NITRO_SPEED
		c["v"] = move_toward(float(c["v"]), target, (16.0 if target > float(c["v"]) else 7.0) * dt)
		c["s"] = float(c["s"]) + float(c["v"]) * dt
		var s: float = c["s"]
		var pf: Dictionary = road.at(s + 1.35)
		var pb: Dictionary = road.at(s - 1.35)
		var mid: Dictionary = road.at(s)
		var fwd: Vector3 = ((pf["pos"] as Vector3) - (pb["pos"] as Vector3)).normalized()
		var rgt: Vector3 = fwd.cross(Vector3.UP).normalized()
		var up: Vector3 = rgt.cross(fwd).normalized()
		var curv: float = road.curvature(int(mid["i"]))
		var roll: float = clampf(-curv * float(c["v"]) * float(c["v"]) * 0.012, -0.09, 0.09)
		var basis: Basis = Basis(rgt, up, -fwd).rotated(fwd, roll)
		var pos: Vector3 = ((pf["pos"] as Vector3) + (pb["pos"] as Vector3)) * 0.5 + rgt * float(c["lane"]) + Vector3(0, 0.07, 0)
		n.transform = Transform3D(basis, pos)
		var steer: float = clampf(atan(KitCar.WHEELBASE * curv), -0.6, 0.6)
		for wn: String in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
			var piv: Node3D = n.get_node(wn)
			if wn.begins_with("WheelF"):
				piv.rotation.y = steer
			(piv.get_node("Spin") as Node3D).rotation.x -= float(c["v"]) * dt / KitCar.WHEEL_R
		var nitro: Node3D = n.get_node("Nitro")
		var on: bool = float(c["nitro"]) > 0.0
		nitro.visible = on
		(nitro.get_node("NitroTrail") as CPUParticles3D).emitting = on
		(n.get_node("TyreDust") as CPUParticles3D).emitting = on
		if on:
			var fl: float = 0.85 + 0.25 * sin(t * 47.0) + 0.1 * sin(t * 113.0)
			(nitro.get_node("Flame") as Node3D).scale = Vector3(1.0 + 0.1 * sin(t * 61.0), 1.0 + 0.1 * sin(t * 61.0), fl * minf(1.0, float(c["nitro"]) * 2.0))
			(nitro.get_node("Light") as OmniLight3D).light_energy = 5.0 + 3.0 * sin(t * 47.0)


## Capture helper: move the cars back so that they reach their layout positions after secs seconds of cruising.
func rewind_cars(secs: float) -> void:
	for c: Dictionary in cars:
		c["s"] = float(c["s0"]) - CRUISE * secs


func nitro_pass() -> void:
	for c: Dictionary in cars:
		if c["is_b"]:
			c["nitro"] = NITRO_TIME


# ---------------------------------------------------------------------------------------------- bots
func _setup_bots() -> void:
	var specs: Array = world.L["arena"].get("bots", [])
	for i: int in specs.size():
		var sp: Dictionary = specs[i]
		var st: String = String(sp.get("state", "idle"))
		var pos: Vector3 = world.arena.transform * Vector3(sp["p"][0], sp["p"][1], sp["p"][2])
		var n: Node3D = KitBot.build({"body": "bot_body" if i % 3 != 1 else "bot_body2", "hat": ["hat_a", "hat_b", "hat_a", "hat_c"][i % 4]})
		n.name = "Bot%d" % (i + 1)
		n.scale = Vector3.ONE * BOT_SCALE
		world.add_child(n)
		n.position = pos
		n.rotation.y = world.arena.rotation.y + deg_to_rad(float(sp.get("yaw", 0.0)))
		var tip: Node3D = n.find_child("ToolTip", true, false)
		var sparks: CPUParticles3D = Fx.sparks()
		tip.add_child(sparks)
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = Color(Style.data["palette"]["spark"])
		light.omni_range = 4.0
		light.light_energy = 0.0
		light.shadow_enabled = false
		tip.add_child(light)
		var flash: MeshInstance3D = Fx.glow("spark")
		flash.visible = false
		tip.add_child(flash)
		var beacon: MeshInstance3D = Fx.glow("beacon")
		(n.find_child("Beacon", true, false) as Node3D).add_child(beacon)
		var ap: AnimationPlayer = n.get_node("AnimationPlayer")
		var b: Dictionary = {"flash": flash, "beacon": beacon, "node": n, "ap": ap, "sparks": sparks, "light": light, "state": "", "home": pos, "home_yaw": n.rotation.y, "home_state": st,
			"mobile": bool(sp.get("mobile", false)), "target": Vector3.ZERO, "after": "", "phase": float(i) * 0.37}
		bots.append(b)
		_bot_state(b, st)
		ap.seek(float(i) * 0.31, true)


func _bot_state(b: Dictionary, st: String) -> void:
	if b["state"] == st:
		return
	b["state"] = st
	(b["ap"] as AnimationPlayer).play(st, 0.15)
	var working: bool = st == "work"
	(b["sparks"] as CPUParticles3D).emitting = working
	((b["sparks"] as CPUParticles3D).get_node("Flash") as CPUParticles3D).emitting = working


func _update_bots(dt: float) -> void:
	for b: Dictionary in bots:
		var n: Node3D = b["node"]
		if b["state"] == "walk":
			var tgt: Vector3 = b["target"]
			var d: Vector3 = tgt - n.position
			d.y = 0.0
			var dist: float = d.length()
			if dist < 0.15:
				n.rotation.y = float(b["target_yaw"])
				_bot_state(b, String(b["after"]))
			else:
				var step: float = minf(dist, 3.2 * dt)
				n.position += d / dist * step
				n.position.y = world.terrain.h(n.position.x, n.position.z)
				n.rotation.y = lerp_angle(n.rotation.y, atan2(-d.x, -d.z), minf(1.0, dt * 10.0))
		var ph: float = float(b["phase"])
		var bp: float = pow(maxf(0.0, sin(t * 4.2 + ph * 5.0)), 6.0)
		(b["beacon"] as Node3D).scale = Vector3.ONE * (0.45 + 1.25 * bp) / BOT_SCALE
		var fl: MeshInstance3D = b["flash"]
		fl.visible = b["state"] == "work"
		if fl.visible:
			var fk: float = 0.6 + 0.5 * absf(sin(t * 31.0 + ph * 7.0)) + 0.4 * absf(sin(t * 73.0))
			fl.scale = Vector3.ONE * fk * 0.62 / BOT_SCALE
		var l: OmniLight3D = b["light"]
		if b["state"] == "work":
			l.light_energy = 1.2 + 1.0 * sin(t * 37.0 + float(b["phase"]) * 9.0) + 0.6 * sin(t * 91.0)
		else:
			l.light_energy = 0.0


# ---------------------------------------------------------------------------------------------- site
func site_advance() -> void:
	if active_rib >= 0:
		return
	for i: int in world.ribs.size():
		if float(world.ribs[i]["build"]) < 1.0:
			active_rib = i
			rib_p = 0.0
			(world.ribs[i]["built"] as MeshInstance3D).visible = true
			# send the mobile bots to the feet of this rib
			var x: float = world.rib_x(i)
			var zf: float = world.rib_span + 1.8
			var AT: Transform3D = world.arena.transform
			var spots: Array = [AT * Vector3(x - 1.6, 0, zf), AT * Vector3(x + 1.7, 0, zf + 0.2), AT * Vector3(x + 0.2, 0, zf + 1.3)]
			var k: int = 0
			for b: Dictionary in bots:
				if b["mobile"] and k < spots.size():
					b["target"] = spots[k]
					b["target_yaw"] = world.arena.rotation.y + (0.5 - float(k)) * 0.5
					b["after"] = "work"
					_bot_state(b, "walk")
					k += 1
			return


func _update_site(dt: float) -> void:
	if active_rib < 0:
		return
	rib_p += dt / RIB_TIME
	var r: Dictionary = world.ribs[active_rib]
	var v: float = clampf(rib_p, 0.0, 1.0)
	r["build"] = v
	(r["built"] as MeshInstance3D).set_instance_shader_parameter("build", v)
	(r["holo"] as MeshInstance3D).set_instance_shader_parameter("build", v)
	if rib_p >= 1.0:
		(r["holo"] as MeshInstance3D).visible = false
		if rib_p >= 1.6:
			for b: Dictionary in bots:
				if b["mobile"] and b["state"] == "work":
					_bot_state(b, "idle")
			active_rib = -1


# ---------------------------------------------------------------------------------------------- frame
func fire(ev: String) -> void:
	match ev:
		"crumble": crumble()
		"nitro_pass": nitro_pass()
		"site_advance": site_advance()
		"reset": reset()
		"cars_home":
			for c: Dictionary in cars:
				c["s"] = float(c["s0"]) - 8.0
				c["v"] = CRUISE


func reset() -> void:
	for b: RigidBody3D in wall_bodies:
		b.queue_free()
	wall_bodies.clear()
	if rubble != null:
		rubble.queue_free()
		rubble = null
	crumbled = false
	for blk: Dictionary in wall_blocks:
		(blk["node"] as MeshInstance3D).visible = true
	for i: int in world.ribs.size():
		var r: Dictionary = world.ribs[i]
		if r["static"]:
			continue
		var v: float = 0.0
		r["build"] = v
		(r["built"] as MeshInstance3D).set_instance_shader_parameter("build", v)
		(r["holo"] as MeshInstance3D).set_instance_shader_parameter("build", v)
		(r["built"] as MeshInstance3D).visible = v > 0.0
		(r["holo"] as MeshInstance3D).visible = v < 1.0
	active_rib = -1
	for c: Dictionary in cars:
		c["s"] = c["s0"]
		c["v"] = CRUISE
		c["nitro"] = 0.0
	for b: Dictionary in bots:
		(b["node"] as Node3D).position = b["home"]
		(b["node"] as Node3D).rotation.y = float(b["home_yaw"])
		_bot_state(b, String(b["home_state"]))
	_place_cars(0.0)


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	t += dt
	for i: int in world.cranes.size():
		var c: Node3D = world.cranes[i]
		var slew: Node3D = c.get_node("Slew")
		var hoist: Node3D = slew.get_node("Hoist")
		if i == 0:
			slew.rotation.y = float(crane_base_yaw[i]) + 0.07 * sin(t * 0.21)
			hoist.rotation.z = 0.055 * sin(t * 0.95)
			hoist.rotation.x = 0.04 * sin(t * 0.74 + 1.0)
		else:
			hoist.rotation.z = 0.012 * sin(t * 0.8 + 2.0)
	if crumbled and wall_bodies.size() > 0 and t - crumble_t > 2.0 and wall_awake() == 0:
		_bake_rubble()
	_place_cars(dt)
	_update_bots(dt)
	_update_site(dt)
