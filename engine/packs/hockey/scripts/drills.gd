extends RefCounted
## Drills (H1): set starts from data/drills.json, called by a test through keyless declared actions drill_<id>.
## Skaters a drill does not place go to the park spots and hold still unless it moves them. Created by main.gd.

func yaw_of(fx_: float, fz: float) -> float:
	return atan2(-fx_, -fz)


## A drill: a set start (data/drills.json). Skaters it does not place go to the park spots and hold still.
func start(g, d: Dictionary, frame: int) -> void:
	g.api.reset()
	g.hits.reset()
	g.drill_brace = (d.get("brace", []) as Array).duplicate()
	g.drill_id = str(d["id"])
	g.drill_t0 = frame
	g.frozen = false
	g.reset_in = 0
	g._flag_goal = ""
	g.drill_moves = {}
	g.drill_script = (d.get("script", []) as Array).duplicate(true)
	var park: Array = g.drills["park"]
	var pi: int = 0
	var place: Dictionary = d.get("place", {})
	var rplace: Dictionary = d.get("random_place", {})
	for id: String in g.order:
		var sk: TLBiped = g.skaters[id]
		sk.brake(false)
		if place.has(id):
			var p: Array = place[id]
			sk.place(Vector3(float(p[0]), 0.1, float(p[1])), yaw_of(float(p[2]), float(p[3])))
		elif rplace.has(id):
			var b: Array = rplace[id]
			sk.place(Vector3(g.ctx.rng.randf_range(float(b[0][0]), float(b[0][1])), 0.1, g.ctx.rng.randf_range(float(b[1][0]), float(b[1][1]))), g._face_yaw(str(g.teams[id])))
		else:
			var q: Array = park[pi % park.size()]
			pi += 1
			sk.place(Vector3(float(q[0]), 0.1, float(q[1])), g._face_yaw(str(g.teams[id])))
	for id: String in d.get("move", {}):
		if g.skaters.has(id):
			var m: Array = d["move"][id]
			g.drill_moves[id] = Vector3(float(m[0]), 0.0, float(m[1]))
	for id: String in d.get("random_move", {}):
		if g.skaters.has(id):
			var b2: Array = d["random_move"][id]
			g.drill_moves[id] = Vector3(g.ctx.rng.randf_range(float(b2[0][0]), float(b2[0][1])), 0.0, g.ctx.rng.randf_range(float(b2[1][0]), float(b2[1][1])))
	var pk: Array = d["puck"]
	g.puck.place(Vector3(float(pk[0]), 0.07, float(pk[1])))
	if d.has("puck_vel"):
		g.puck.linear_velocity = Vector3(float(d["puck_vel"][0]), 0.0, float(d["puck_vel"][1]))
	if d.has("carrier") and g.skaters.has(str(d["carrier"])):
		g.api.give(str(d["carrier"]))


func tick(g, frame: int) -> void:
	for id: String in g.order:
		if id == "b0" and not g.autopilot:
			continue
		var sk: TLBiped = g.skaters[id]
		var rc: Vector3 = g.api.receive_dir(id)
		if rc != Vector3.ZERO:
			sk.brake(false)
			sk.move(rc)
		elif g.drill_moves.has(id):
			sk.brake(false)
			sk.move(g.drill_moves[id])
		else:
			sk.move(Vector3.ZERO)
			sk.brake(true)
	for id in g.drill_brace:
		if g.skaters.has(str(id)):
			g.hits.braced[str(id)] = true
	for st: Array in g.drill_script:
		if frame - g.drill_t0 == int(st[0]) and g.skaters.has(str(st[1])):
			match str(st[2]):
				"check": g.hits.try_check(str(st[1]))
				"cross": g.hits.try_cross(str(st[1]))
				"poke": g.api.try_poke(str(st[1]))
				"pass": g.api.try_pass(str(st[1]))
				"shoot": g.api.try_shoot(str(st[1]))
