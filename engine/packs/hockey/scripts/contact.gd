extends RefCounted
## H1 build (23 Nov, the behaviour sheet S7 and S8 of docs/research/hockey-teardown/BEHAVIOUR-HAND.md): thirdjam's contact
## laws that scripts/hits.gd (at its size budget) did not have. Created by main.gd, no class_name; h = the hits object.
## Tuning: data/tuning.json "contact".

const KEYS := ["cross_strip_gap", "bounce", "bounce_min"]
var cross_strip_gap: float         ## S7: the cross-check's stick takes a carrier's puck at the press within this body gap (thirdjam LiftRangeM 1.0)
var bounce: bool                   ## S8: two bodies that meet without a hit exchange speed (thirdjam's collision) instead of stopping dead
var bounce_min: float              ## ... from this closing speed (m/s); slower meetings are left to the bodies' slide
var strips: Dictionary = {}        ## presser id -> pucks his cross-check took at the press
var bounces := 0                   ## body meetings resolved by bounce_bodies

func setup(cfg: Dictionary) -> void:
	for key: String in cfg:
		if key not in KEYS:
			push_error("tuning.json: unknown contact.%s" % key)
	for key: String in KEYS:
		self[key] = cfg[key]

func state() -> Dictionary:
	var s := {}
	if not strips.is_empty():
		s["strips"] = strips.duplicate()
	if bounces > 0:
		s["bounces"] = bounces
	return s

## H1 build (S7): thirdjam's lift (JamSim.cpp ResolveLift): the cross-check's stick takes an opposing carrier's puck at the
## press when his body is within cross_strip_gap and inside the stick's cone, not through his back; the puck comes off toward
## the presser (h.strip_speed, plus half his velocity). The body's shove still lands when the swing does.
func strip_at_press(h, id: String) -> void:
	var c: String = h.api.carrier
	if c == "" or c == id or not h._opponent(id, c) or not h.api.can_strip(id, c):
		return
	var d: Vector3 = h._dir(id, c)
	if h.api.pos_of(c).distance_to(h.api.pos_of(id)) > h.touch_distance(id, c) + cross_strip_gap or not h.in_cross_cone(id, c):
		return
	if d.dot(h.api.fwd_of(c)) > h.arc_dot:
		return                               # his body is between the stick and the puck
	h.api._release("poked", c, -d * h.strip_speed + h._vel(id) * 0.5)
	strips[id] = int(strips.get(id, 0)) + 1

## H1 build (S8): thirdjam's collision (JamSim.cpp, JAMSTAND "no press" rows): two skaters on their feet that meet in this step
## exchange speed along the line between them with the hit law's h.restitution and each man's brace as effective mass (a
## standing man braced at his side takes 5x), instead of the kinematic bodies stopping dead against each other.
func bounce_bodies(h) -> void:
	if not bounce:
		return
	# one pass over the bodies (flat positions, velocities, radii), then the pairs by arithmetic: it runs every frame
	var count: int = h.bodies.size()
	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
	var rad := PackedFloat32Array()
	var live := PackedByteArray()
	pos.resize(count); vel.resize(count); rad.resize(count); live.resize(count)
	for i in count:
		var sk: TLBiped = h.bodies[i]
		var gp: Vector3 = sk.global_position
		pos[i] = Vector3(gp.x, 0.0, gp.z)
		vel[i] = Vector3(sk.velocity.x, 0.0, sk.velocity.z)
		rad[i] = sk.body_radius()
		live[i] = int(not h.shield.has(h.order[i]) and not sk.is_down())
	for a in count:
		if live[a] == 0:
			continue
		for b in range(a + 1, count):
			if live[b] == 0:
				continue
			var dv: Vector3 = pos[b] - pos[a]
			var reach: float = rad[a] + rad[b] + 0.5          # no meeting this step is possible farther out (0.5 m: 30 m/s of closing)
			var d2: float = dv.length_squared()
			if d2 > reach * reach or d2 < 0.00000001:
				continue
			var dist: float = sqrt(d2)
			var n: Vector3 = dv / dist
			var c: float = (vel[a] - vel[b]).dot(n)
			if c < bounce_min or dist - rad[a] - rad[b] - c / 60.0 > 0.02:
				continue
			var sa: TLBiped = h.bodies[a]
			var sb: TLBiped = h.bodies[b]
			var ma: float = sa.body_mass * h.brace(h.order[a], -n, "body")
			var mb: float = sb.body_mass * h.brace(h.order[b], n, "body")
			var j: float = (1.0 + h.restitution) * c / (1.0 / ma + 1.0 / mb)
			sa.shove(-n * j * sa.body_mass / ma)
			sb.shove(n * j * sb.body_mass / mb)
			vel[a] = Vector3(sa.velocity.x, 0.0, sa.velocity.z)
			vel[b] = Vector3(sb.velocity.x, 0.0, sb.velocity.z)
			bounces += 1
