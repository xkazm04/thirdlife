## Created by abilities.gd to manage seeded rink-local packages and timed boosts. Base matches never tick it.
extends RefCounted
const FIELDS := {
	"speed":["frames","magnitude"], "precision":["frames","cone_deg"],
	"big_puck":["frames","magnitude"], "heavy_puck":["frames","magnitude","drag"],
	"shotgun":["frames","magnitude","down_frames","path_margin","min_speed"],
	"hip_check":["frames","magnitude","down_frames","shove_m"], "shield":["frames"], "slow_puck":["frames","magnitude"]
}
var effects := {}
var key_hints := {}
var drills := {}
var config := {}
var packages: Array = []
var taken := {}
var active := {} # id -> kind -> exclusive end frame
var puck_until := {}
var next_spawn := 0
var original_accel := {}
var draw
var puck_visuals := {}
var puck_shape: CylinderShape3D
var radius := 0.0
var auras := {}

## Reject unknown data fields with their path in boosts.json.
func keys(row: Dictionary, allowed: Array, path: String) -> void:
	for key in row:
		if not allowed.has(key):
			push_error("data/boosts.json: unknown key '%s.%s'" % [path,key])

## Read and validate authored effects and drill extensions before the first match.
func setup(g) -> void:
	var data: Dictionary = g.ctx.read_json("boosts.json")
	keys(data, ["about","key_hints","effects","drills"], "root")
	if not data.get("about") is String or str(data.about).is_empty():
		push_error("data/boosts.json: 'about' must describe the catalogue")
	if data.get("key_hints") is Dictionary:
		key_hints = data.key_hints
		keys(key_hints, ["arsenal", "shotgun"], "key_hints")
	for mode in ["arsenal", "shotgun"]:
		if not key_hints.get(mode) is String or str(key_hints[mode]).strip_edges().is_empty():
			push_error("data/boosts.json: 'key_hints.%s' must be a non-empty string" % mode)
	for e: Dictionary in data.effects:
		var k := str(e.kind)
		if not FIELDS.has(k):
			push_error("data/boosts.json: unknown effects[].kind '%s'" % k)
			continue
		keys(e, ["kind","color"] + FIELDS[k], k)
		if effects.has(k) or not e.get("color") in ["cyan","bot_visor","beacon","nitro_hot","nitro_core","tail_light","head_light","window","neon_pink","neon_lime","neon_violet"]:
			push_error("data/boosts.json: duplicate '%s' or unknown emissive color" % k)
		for field in FIELDS[k]:
			if not e.has(field) or not (e[field] is float or e[field] is int) or float(e[field]) <= 0:
				push_error("data/boosts.json: invalid '%s.%s'" % [k, field])
		effects[k] = e
	for kind: String in FIELDS:
		if not effects.has(kind):
			push_error("data/boosts.json: missing effect '%s'" % kind)
	for d: Dictionary in data.drills:
		keys(d, g.DRILL_KEYS + ["grant","packages"], str(d.id))
		for entry: Dictionary in d.get("packages", []):
			keys(entry, ["kind","pos"], str(d.id) + ".packages[]")
			if not effects.has(entry.kind):
				push_error("data/boosts.json: unknown package kind '%s'" % entry.kind)
		if d.has("grant") and not g.modes_lib.ABILITY_KINDS.has(d.grant):
			push_error("data/boosts.json: unknown grant '%s'" % d.grant)
		if drills.has(d.id):
			push_error("data/boosts.json: duplicate drill id '%s'" % d.id)
		drills[d.id] = d
	if not g.ctx.headless:
		draw = g.ctx.load_script("gen/crazy_hook.gd").new()

## Allow time to read the ability key even if a returning player is already skating.
func with_ability_hint(g, controls: String) -> String:
	var hint: String = key_hints.get(g.mode_id, "")
	if hint.is_empty() or g.menu_lib.open:
		return controls
	if controls.is_empty():
		return hint if g.rules.total_frames < 180 else ""
	return controls + "\n" + hint

## Reset this arena's package population and remember the unmodified bodies.
func build(g, m: Dictionary) -> void:
	config = m.get("pickups", {})
	packages.clear()
	taken.clear()
	active.clear()
	puck_until.clear()
	auras.clear() # All meshes are children of the retiring arena.
	original_accel.clear()
	for id in g.order:
		original_accel[id] = g.skaters[id].skate_accel
	next_spawn = g.ctx.frame + int(config.get("first_frames", 1))
	radius = g.puck.radius
	puck_visuals.clear()
	# The kit's dynamic part publicly exposes the same tl_shape used by TLBall.create.
	for child in g.puck.get_children():
		if child.has_meta(&"tl_shape"):
			puck_shape = child.get_meta(&"tl_shape") as CylinderShape3D
			puck_visuals[child] = child.scale
		elif child is MeshInstance3D:
			puck_visuals[child] = child.scale

## Resize the kit cylinder, its public radius and the puck's drawn parts together.
func resize(g, factor: float) -> void:
	g.puck.radius = radius * factor
	if puck_shape != null:
		puck_shape.radius = g.puck.radius
	if not g.ctx.headless:
		for part in puck_visuals:
			if is_instance_valid(part):
				part.scale = puck_visuals[part] * Vector3(factor,1,factor)

## Return both the puck body and its drawing to the configured regulation size and drag.
func reset_puck(g) -> void:
	if puck_until.has("big_puck"):
		resize(g, 1.0)
	g.puck.linear_damp = float(g.tune.puck.drag)
	puck_until.clear()
	g.puck.max_speed = float(g.tune.puck.max_speed)

## Compose the heavy-puck and shot-flight multipliers without overwriting either one.
func speed_cap(g, flight_scale: float) -> void:
	var heavy := float(effects.heavy_puck.magnitude) if puck_until.has("heavy_puck") else 1.0
	g.puck.max_speed = float(g.tune.puck.max_speed) * heavy * flight_scale

## Return the skater's horizontal position relative to this pack.
func local_pos(g, id: String) -> Vector3:
	var p: Vector3 = g.skaters[id].position
	return Vector3(p.x, 0, p.z)

## Place a package at a rink-local position, with its beacon in a rendered match.
func add(g, kind: String, pos: Vector3) -> void:
	var entry := {"kind":kind, "pos":pos}
	if not g.ctx.headless:
		entry.node = draw.beacon(g.arena, pos, kind, str(effects[kind].color))
	packages.append(entry)

## Sample a weighted kind and a free spot in one of the mode's zones.
func spawn(g) -> void:
	if packages.size() >= int(config.max_alive):
		return
	for attempt in 12:
		var z: Array = config.zones[g.ctx.rng.randi_range(0, config.zones.size()-1)]
		var p := Vector3(g.ctx.rng.randf_range(z[0],z[2]),0,g.ctx.rng.randf_range(z[1],z[3]))
		if p.length() < 2.5 or p.distance_to(g.goal_pos.blue) < 4 or p.distance_to(g.goal_pos.red) < 4:
			continue
		var clear := true
		for id in g.order:
			if local_pos(g,id).distance_squared_to(p) < 4:
				clear = false
				break
		for other in packages:
			if p.distance_squared_to(other.pos) < 4:
				clear = false
		if not clear:
			continue
		var total := 0.0
		for e in config.kinds:
			total += float(e.weight)
		var ticket: float = g.ctx.rng.randf() * total
		for e in config.kinds:
			ticket -= float(e.weight)
			if ticket <= 0:
				add(g, e.kind, p)
				return

## Expire boosts and award each package to the nearest eligible skater.
func tick(g, abilities) -> void:
	var now: int = g.ctx.frame
	for id in active.keys():
		for k in active[id].keys():
			if now >= int(active[id][k]):
				active[id].erase(k)
				if k == "speed":
					g.skaters[id].skate_accel = original_accel[id]
		if active[id].is_empty():
			active.erase(id)
	for k in puck_until.keys():
		if now >= int(puck_until[k]):
			puck_until.erase(k)
			if k == "big_puck":
				resize(g, 1.0)
			else:
				g.puck.linear_damp = float(g.tune.puck.drag)
	if config.is_empty():
		return
	if now >= next_spawn:
		spawn(g)
		next_spawn = now + int(config.every_frames)
	for i in range(packages.size()-1,-1,-1):
		var e: Dictionary = packages[i]
		var nearest := ""
		var dist := INF
		for id: String in g.order:
			if g.api.goalies.has(id) or g.hits.is_down(id) or not abilities.accepts(id, e.kind):
				continue
			var d := local_pos(g,id).distance_to(e.pos)
			if d < dist and d <= g.skaters[id].body_radius() + float(config.take_margin):
				dist = d
				nearest = id
		if nearest == "":
			continue
		var kind: String = e.kind
		var until := now + int(effects[kind].frames)
		match kind:
			"speed","precision":
				if not active.has(nearest):
					active[nearest] = {}
				active[nearest][kind] = until
			"big_puck":
				puck_until[kind] = until
				resize(g, effects[kind].magnitude)
			"heavy_puck":
				puck_until[kind] = until
				# Base drag is zero, so heavy puck uses an absolute damping rate.
				g.puck.linear_damp = effects[kind].drag
			_: abilities.grant(nearest, kind)
		taken[kind] = int(taken.get(kind,0)) + 1
		abilities.flash(g, "pickup", g.ctx.root.to_global(e.pos), nearest)
		if e.has("node"):
			e.node.queue_free()
		packages.remove_at(i)

## Apply the multiplier after normal carry and sprint modifiers, preserving acceleration.
func apply_speed(g) -> void:
	for id in active:
		if active[id].has("speed"):
			var sk: TLBiped = g.skaters[id]
			sk.skate_speed *= float(effects.speed.magnitude)
			sk.skate_accel *= float(effects.speed.magnitude)   # L4 merge: on top of this frame's skating rules (burst, reverse brake: scripts/skate.gd)

## Turn an assisted shot inside the cone toward the centre of the opposing goal.
func aim(g, id: String) -> void:
	if not active.get(id,{}).has("precision"):
		return
	var goal: Vector3 = g.goal_pos["red" if g.teams[id] == "blue" else "blue"]
	var to: Vector3 = g.ctx.root.to_global(goal) - g.puck.global_position
	to.y = 0
	var velocity: Vector3 = g.puck.linear_velocity
	# Thirdjam's default cone was 15 degrees. Precision doubles it to 30.
	if to.length_squared() > 0.001 and velocity.angle_to(to) <= deg_to_rad(effects.precision.cone_deg):
		g.puck.linear_velocity = to.normalized() * velocity.length()

## Animate nearby beacons and equipped waist rings using the simulation frame.
func render(g, slots: Dictionary) -> void:
	for e in packages:
		var d := INF
		for id in g.order:
			d = minf(d, local_pos(g,id).distance_to(e.pos))
		draw.pose(e.node, d, g.ctx.frame)
	for id in slots:
		var slot: Dictionary = slots[id]
		var shield := slot.has("shield_until")
		var kind := str(slot.get("armed",slot.get("held","")))
		if shield:
			kind = "shield"
		if kind == "" and active.has(id):
			kind = str(active[id].keys()[0])
		var key := kind + ("_on" if shield else "")
		if auras.has(id) and auras[id].key != key:
			auras[id].node.queue_free()
			auras.erase(id)
		if kind == "":
			continue
		if not auras.has(id):
			auras[id] = {"key":key,"node":draw.aura(g.arena,effects[kind].color,shield)}
		var n: Node3D = auras[id].node
		n.position = g.skaters[id].position + Vector3.UP * 1.85
		n.rotation.y = g.ctx.frame * (0.095 if slot.has("armed") or shield else 0.031)
		n.visible = not g.hits.is_down(id)

## Report package positions to the nearest millimetre without retaining visual nodes.
func package_state() -> Array:
	var out := []
	for e in packages:
		out.append({"kind":e.kind,"pos":[snappedf(e.pos.x,0.001),snappedf(e.pos.z,0.001)]})
	return out
