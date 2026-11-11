class_name TLContact
extends Node
## Contact tracker for one dynamic body (it is a child of a RigidBody3D). Two jobs:
##   1. report impacts: signal `hit(other, impulse, speed)` and routing to TLDamage on either side;
##   2. make the body follow the surface rules: while it touches (or is about to touch) a tagged surface, its
##      friction and restitution are set so the pair behaves as TLLaws.pair() says, overrides included.
## TLBodies.make attaches one to every dynamic body; TLBall and TLVehicle own one. Capability: `physics`.
##
## P2: a TLContact has no `_physics_process` of its own any more. The pack has ONE `Tracker` (an inner node, a child of
## the pack's `TLPack` node, ticked at process priority 100 like the contact nodes were) that walks every tracked body
## of the pack in one loop per tick: same work, in registration order (the order the bodies entered the tree), with
## the ray query object, the physics space and the surface answers shared instead of rebuilt per body. A contact whose
## pack has no tracker (made outside any pack call, a kernel tool) still ticks itself, with the same step.

signal hit(other: Node, impulse: float, speed: float)   ## impulse in N*s (estimate), closing speed in m/s

var body: RigidBody3D
var material: String = ""            ## the body's own material id
var surface: String = ""             ## material id of what it is touching or about to touch ("" = nothing tagged)
var min_hit_speed: float = 0.5       ## slower contacts are not reported as hits
var _prev_velocity: Vector3 = Vector3.ZERO
var _pm: PhysicsMaterial
var _reach: float = 0.5
var _ctx: TLContext = null           # N2: the pack this body belongs to
var _tracker: Tracker = null         # P2: the pack's one pass over its bodies (null: this contact ticks itself)
var _exclude: Array[RID] = []        # the body's own rid, for the ray query (built once)
var _mat_age: int = 0                # ticks until the body's material tag is read again
var _touch: Dictionary = {}          # instance id -> material id of each tagged, untracked body touched now (from signals)
var _touch_dirty: bool = false
var _touch_found: String = ""        # the surface the touched bodies give (slipperiest pair)
var _touching: bool = false          # _touch_found is not empty
var _travel: float = 0.0             # metres moved (estimated from speed) since the last ray cast
var _recast: float = 0.075           # a body casts its ray again after this much travel (15 % of its reach)
var _ray_found: String = ""
var _ray_valid: bool = false

const MATERIAL_REFRESH: int = 30


## P2. The one pass of a pack over its tracked bodies. Not for pack code: it is created by the kernel the first time
## a TLContact is made inside a pack, and lives under the pack's `TLPack` node, so it is switched off and on with the pack.
class Tracker extends Node:
	var ctx: TLContext = null
	var entries: Array[TLContact] = []
	var by_id: Dictionary = {}               # instance id of the body -> its TLContact (replaces `has_node("TLContact")`)
	var dirty: bool = false                  # a tracked body left the tree: the list is compacted at the next pass
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	var space: PhysicsDirectSpaceState3D = null
	var passes: int = 0                      # for tests and the bench: passes made
	var casts: int = 0                       # for tests and the bench: ray casts made
	var pass_usec: int = 0                   # for tests and the bench: wall time spent in the passes

	func _init() -> void:
		process_physics_priority = 100
		name = "TLTracker"

	func _physics_process(_delta: float) -> void:
		passes += 1
		var t0: int = Time.get_ticks_usec()
		if dirty:
			compact()
		space = null
		for c: TLContact in entries:
			c._step(self)
		pass_usec += Time.get_ticks_usec() - t0

	## Drops the entries that left the tree (or were freed); the order of the others is kept.
	func compact() -> void:
		dirty = false
		var keep: Array[TLContact] = []
		for c: TLContact in entries:
			if is_instance_valid(c) and c.body != null and by_id.get(c.body.get_instance_id()) == c:
				keep.append(c)
		entries = keep

	func add(c: TLContact) -> void:
		if dirty:
			compact()
		var id: int = c.body.get_instance_id()
		if not by_id.has(id):
			by_id[id] = c
			entries.append(c)

	func remove(c: TLContact) -> void:
		if c.body != null:
			by_id.erase(c.body.get_instance_id())
		dirty = true

	## The physics queries of this pack, fetched once per pass.
	func space_state(from: Node3D) -> PhysicsDirectSpaceState3D:
		if space == null:
			space = TLContext.space_state_of(from, ctx)
		return space


## The tracker of a pack, made on first use; null when there is no pack to put it in.
static func tracker_of(c: TLContext) -> Tracker:
	if c == null:
		return null
	var t: Variant = c.get_meta(&"tl_tracker") if c.has_meta(&"tl_tracker") else null
	if t != null and is_instance_valid(t):
		return t as Tracker
	if c.root == null or not is_instance_valid(c.root):
		return null
	var host: Node = c.root.get_parent()
	if host == null or not host.is_inside_tree():
		return null
	var tr: Tracker = Tracker.new()
	tr.ctx = c
	host.add_child(tr)
	c.set_meta(&"tl_tracker", tr)
	return tr


func _init() -> void:
	# a factory of the kernel runs inside a call into the pack: make the pack's tracker now, while its tree is quiet
	_tracker = tracker_of(TLContext.current)


func _enter_tree() -> void:
	body = get_parent() as RigidBody3D
	if body == null:
		return
	_ctx = TLContext.of(self)
	var tr: Tracker = tracker_of(_ctx)
	if tr != _tracker and _tracker != null and is_instance_valid(_tracker):
		_tracker.remove(self)
	_tracker = tr
	_exclude = [body.get_rid()]
	if _tracker != null:
		_tracker.add(self)
		set_physics_process(false)
	else:
		set_physics_process(true)


func _exit_tree() -> void:
	if _tracker != null and is_instance_valid(_tracker):
		_tracker.remove(self)


func _ready() -> void:
	body = get_parent() as RigidBody3D
	if body == null:
		push_error("TLContact must be a child of a RigidBody3D")
		set_physics_process(false)
		if _tracker != null and is_instance_valid(_tracker):
			_tracker.remove(self)
		return
	body.contact_monitor = true
	body.max_contacts_reported = maxi(body.max_contacts_reported, 6)
	body.body_entered.connect(_on_body_entered)
	body.body_exited.connect(_on_body_exited)
	process_physics_priority = 100
	set_physics_process(_tracker == null)     # the engine switches it on at ready: a tracked contact stays off
	_ctx = TLContext.of(self)
	_reach = maxf(0.05, pow(maxf(TLLaws.volume_of(body), 0.0001), 1.0 / 3.0))
	_recast = _reach * 0.15


## Only used by a contact that has no pack tracker.
func _physics_process(_delta: float) -> void:
	_step(null)

## One tick of one body. `tr` is the pack's tracker (shared ray query and space), or null for a lone contact.
##
## Work per awake body, in the order of cost: read the sleep flag and the velocity (two engine calls); take the surface
## from the contacts the engine reported by signal (`_touch`, kept by `_note_touch`, no per-tick scan); cast a ray only
## when it has moved (estimated from its speed) 15 % of its reach since the last cast: a puck at 30 m/s casts every tick,
## a box resting in a pile once in many ticks; between casts the last answer stands.
func _step(tr: Tracker) -> void:
	# N5a: a sleeping body touches nothing new and moves nowhere: its surface, its material override and its last
	# velocity (zero) all stand. `_pm != null`: a body that starts asleep still gets its law once.
	if body.sleeping and _pm != null:
		_prev_velocity = body.linear_velocity
		return
	var v: Vector3 = body.linear_velocity
	_prev_velocity = v
	if _mat_age <= 0:
		_mat_age = MATERIAL_REFRESH
		var m_now: String = TLLaws.material_of(body)
		if m_now != material:
			material = m_now
			_touch_dirty = true
			_ray_valid = false
	else:
		_mat_age -= 1
	var speed: float = v.length()
	_travel += speed * (1.0 / 60.0)
	# the usual tick of a body that is awake but unchanged: same contacts, not yet moved far enough to look again
	if _pm != null and not _touch_dirty and (_touching or (_ray_valid and _travel < _recast)):
		return
	if material.is_empty():
		return
	if _touch_dirty:
		_recompute_touch()
	var found: String = _touch_found
	if _touching:
		_ray_valid = false
	elif _travel >= _recast or not _ray_valid:
		if tr != null:
			tr.casts += 1
		found = _cast(tr, v, speed)
		_ray_found = found
		_ray_valid = true
		_travel = 0.0
	else:
		found = _ray_found
	if found != surface or _pm == null:
		surface = found
		_pm = PhysicsMaterial.new()
		var own: Dictionary = TLLaws.material(material)
		if surface.is_empty():
			_pm.friction = float(own["friction"])
			_pm.bounce = float(own["restitution"])
		else:
			# the engine combines friction as "the rough one wins" and bounce as a sum: set this body so that the
			# pair comes out as the law says
			var law: Dictionary = TLLaws.pair_cached(material, surface)
			var other_bounce: float = float(TLLaws.material(surface)["restitution"])
			_pm.rough = true
			_pm.friction = float(law["friction"])
			var diff: float = float(law["restitution"]) - other_bounce
			_pm.absorbent = diff < 0.0
			_pm.bounce = absf(diff)
		body.physics_material_override = _pm


## Look ahead along the velocity (and down, for something resting or sliding) so the first touch is right too.
## The material id of the first tagged, untracked collider the rays find ("" when nothing, or only bodies that follow
## the law themselves).
func _cast(tr: Tracker, v: Vector3, speed: float) -> String:
	if not body.is_inside_tree():
		return ""
	var pos: Vector3 = body.global_position
	var space: PhysicsDirectSpaceState3D = tr.space_state(body) if tr != null else TLContext.space_state_of(body, _ctx)   # N2: the pack's own space
	var q: PhysicsRayQueryParameters3D = tr.query if tr != null else PhysicsRayQueryParameters3D.new()
	q.exclude = _exclude
	q.from = pos
	if speed > 0.5:
		q.to = pos + v / speed * (_reach + speed / 20.0)
		var m: String = _ray_material(space, q)
		if not m.is_empty():
			return m
	q.to = pos + Vector3.DOWN * (_reach + 0.1)
	return _ray_material(space, q)


func _ray_material(space: PhysicsDirectSpaceState3D, q: PhysicsRayQueryParameters3D) -> String:
	var h: Dictionary = space.intersect_ray(q)
	if not h.is_empty():
		var collider: Object = h["collider"]
		var m: String = TLLaws.material_of(collider)
		if not m.is_empty() and not _follows_law(collider as Node):
			return m
	return ""


## True for a body that has a tracker of its own (it follows the law itself, so it is never a surface).
func _follows_law(other: Node) -> bool:
	if _tracker != null and _tracker.by_id.has(other.get_instance_id()):
		return true
	return other.has_node("TLContact")


## Keeps the set of tagged, untracked bodies this one touches, from the engine's enter and exit signals.
func _note_touch(other: Node, entered: bool) -> void:
	var id: int = other.get_instance_id()
	if entered:
		var m: String = TLLaws.material_of(other)
		if not m.is_empty() and not _follows_law(other):
			_touch[id] = m
			_touch_dirty = true
	elif _touch.erase(id):
		_touch_dirty = true


## Touching several tagged surfaces at once: follow the slipperiest pair, and the alphabetically first id on a
## tie. Never "the first one reported": the physics engine reports contacts in an order that can differ between
## two runs of the same seed (found by seed.wall: a ball lying against rubble and ground at the same time).
func _recompute_touch() -> void:
	_touch_dirty = false
	var found: String = ""
	var found_mu: float = INF
	for id: int in _touch:
		var m: String = _touch[id]
		var mu: float = float(TLLaws.pair_cached(material, m)["friction"])
		if mu < found_mu or (mu == found_mu and m < found):
			found = m
			found_mu = mu
	_touch_found = found
	_touching = not found.is_empty()


func _on_body_exited(other: Node) -> void:
	_note_touch(other, false)


func _on_body_entered(other: Node) -> void:
	_note_touch(other, true)
	var other_v: Vector3 = Vector3.ZERO
	var other_mass: float = INF
	if other is RigidBody3D:
		other_v = (other as RigidBody3D).linear_velocity
		other_mass = (other as RigidBody3D).mass
		var oc: TLContact = _tracker.by_id.get(other.get_instance_id()) as TLContact if _tracker != null else null
		if oc == null and other.has_node("TLContact"):
			oc = other.get_node("TLContact") as TLContact
		if oc != null:
			other_v = oc._prev_velocity
	elif other is CharacterBody3D:
		other_v = (other as CharacterBody3D).velocity
	var speed: float = (_prev_velocity - other_v).length()
	if speed < min_hit_speed:
		return
	var m_eff: float = body.mass if is_inf(other_mass) else body.mass * other_mass / (body.mass + other_mass)
	var impulse: float = m_eff * speed
	# N2: this is an engine callback (no kernel call is on the stack): name the pack before pack code hears of it
	var before: TLContext = TLContext.enter(_ctx if _ctx != null else TLContext.of(self))
	hit.emit(other, impulse, speed)
	TLAudio.contact(TLLaws.material_of(other), impulse, body.global_position)
	TLDamage.report(other, impulse, body)
	TLDamage.report(body, impulse, other)
	TLContext.leave(before)
