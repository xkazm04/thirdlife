extends RefCounted
## Drills (H1): set starts from data/drills.json, called by a test through keyless declared actions drill_<id>.
## Skaters a drill does not place go to the park spots and hold still unless it moves them. Created by main.gd.

var sprint_slots := PackedInt32Array()

func yaw_of(fx_: float, fz: float) -> float:
	return atan2(-fx_, -fz)

## A drill: a set start (data/drills.json). Skaters it does not place go to the park spots and hold still.
func start(g, d: Dictionary, frame: int) -> void:
	g.skate.reset()
	g.skate.stamina.fill(g.skate.stamina_full)
	sprint_slots.clear()
	for id: String in d.get("sprint", []):
		sprint_slots.append(g.skate.slots[id])
	g.api.reset()
	g.hits.reset()
	g.keeper.in_drill = bool(d.get("goalies", false))     # L5: a goalie drill keeps them in their nets
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
	var relative: Dictionary = d.get("place_from", {})
	var rplace: Dictionary = d.get("random_place", {})
	for id: String in g.order:
		var sk: TLBiped = g.skaters[id]
		g.skate.brake(id, false)
		if place.has(id):
			var p: Array = place[id]
			sk.place(Vector3(float(p[0]), 0.1, float(p[1])), yaw_of(float(p[2]), float(p[3])))
		elif relative.has(id):
			# [fixed skater, surface gap x/z, facing x/z]. Read the fixed mark before either body moves.
			var p: Array = relative[id]
			var anchor: Array = place[p[0]]
			var gap := Vector2(p[1], p[2])
			var radii := sk.body_radius() + (g.skaters[p[0]] as TLBiped).body_radius()
			var center := Vector2(anchor[0], anchor[1]) + gap + gap.normalized() * radii
			sk.place(Vector3(center.x, 0.1, center.y), yaw_of(p[3], p[4]))
		elif g.keeper.is_goalie(id) and g.keeper.in_drill:
			sk.place(g.spawns[id], g._face_yaw(str(g.teams[id])))
		elif g.keeper.is_goalie(id):
			var bq: Array = g.drills["bench"][0 if str(g.teams[id]) == "blue" else 1]      # L5: a drill has no goalies
			sk.place(Vector3(float(bq[0]), 0.1, float(bq[1])), g._face_yaw(str(g.teams[id])))
		elif rplace.has(id):
			var b: Array = rplace[id]
			sk.place(Vector3(g.ctx.rng.randf_range(float(b[0][0]), float(b[0][1])), 0.1, g.ctx.rng.randf_range(float(b[1][0]), float(b[1][1]))), g._face_yaw(str(g.teams[id])))
		else:
			var q: Array = park[pi % park.size()]
			pi += 1
			sk.place(Vector3(float(q[0]), 0.1, float(q[1])), g._face_yaw(str(g.teams[id])))
	for id: String in d.get("velocity", {}):
		if g.skaters.has(id):
			var v: Array = d["velocity"][id]
			var sk: TLBiped = g.skaters[id]
			sk.shove(Vector3(float(v[0]), 0, float(v[1])) * sk.body_mass)
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

func pace(g) -> void:
	if g.drill_id == "":
		return
	for i in sprint_slots:
		g.skate.pace(i, true, g.drill_moves.get(g.skate.ids[i], Vector3.ZERO))

func tick(g, frame: int) -> void:
	for id: String in g.order:
		if (id == "b0" and not g.autopilot) or (g.keeper.in_drill and g.keeper.is_goalie(id)):
			continue
		var rc: Vector3 = g.api.receive_dir(id)
		if rc != Vector3.ZERO:
			g.skate.brake(id, false)
			g.skate.want(id, rc)
		elif g.drill_moves.has(id):
			g.skate.brake(id, false)
			g.skate.want(id, g.drill_moves[id])
		else:
			g.skate.want(id, Vector3.ZERO)
			g.skate.brake(id, true)
	for st: Array in g.drill_script:
		if frame - g.drill_t0 == int(st[0]) and g.skaters.has(str(st[1])):
			match str(st[2]):
				"check": g.hits.try_check(str(st[1]))
				"cross": g.hits.try_cross(str(st[1]))
				"poke": g.api.try_poke(str(st[1]))
				"pass": g.api.try_pass(str(st[1]))
				"shoot": g.api.try_shoot(str(st[1]))
				"aim":       # L5: [frames, id, "aim", x, z]: his stick points at (x, z) for the step's pass or shot
					var to: Vector3 = Vector3(float(st[3]), 0.0, float(st[4])) + g.ctx.root.global_position - g.api.puck_pos()
					g.api.stick_dir[str(st[1])] = to.normalized()

