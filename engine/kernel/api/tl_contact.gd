class_name TLContact
extends Node
## Contact tracker for one dynamic body (it is a child of a RigidBody3D). Two jobs:
##   1. report impacts: signal `hit(other, impulse, speed)` and routing to TLDamage on either side;
##   2. make the body follow the surface rules: while it touches (or is about to touch) a tagged surface, its
##      friction and restitution are set so the pair behaves as TLLaws.pair() says, overrides included.
## TLBodies.make attaches one to every dynamic body; TLBall and TLVehicle own one. Capability: `physics`.

signal hit(other: Node, impulse: float, speed: float)   ## impulse in N*s (estimate), closing speed in m/s

var body: RigidBody3D
var material: String = ""            ## the body's own material id
var surface: String = ""             ## material id of what it is touching or about to touch ("" = nothing tagged)
var min_hit_speed: float = 0.5       ## slower contacts are not reported as hits
var _prev_velocity: Vector3 = Vector3.ZERO
var _pm: PhysicsMaterial
var _reach: float = 0.5


func _ready() -> void:
	body = get_parent() as RigidBody3D
	if body == null:
		push_error("TLContact must be a child of a RigidBody3D")
		set_physics_process(false)
		return
	body.contact_monitor = true
	body.max_contacts_reported = maxi(body.max_contacts_reported, 6)
	body.body_entered.connect(_on_body_entered)
	process_physics_priority = 100
	_reach = maxf(0.05, pow(maxf(TLLaws.volume_of(body), 0.0001), 1.0 / 3.0))


func _physics_process(_delta: float) -> void:
	material = TLLaws.material_of(body)
	if material.is_empty():
		_prev_velocity = body.linear_velocity
		return
	var found: String = ""
	var other_bounce: float = 0.0
	# Touching several tagged surfaces at once: follow the slipperiest pair, and the alphabetically first id on a
	# tie. Never "the first one reported": the physics engine reports contacts in an order that can differ between
	# two runs of the same seed (found by seed.wall: a ball lying against rubble and ground at the same time).
	var found_mu: float = INF
	for other: Node3D in body.get_colliding_bodies():
		var m: String = TLLaws.material_of(other)
		if not m.is_empty() and not other.has_node("TLContact"):
			var mu: float = float(TLLaws.pair(material, m)["friction"])
			if mu < found_mu or (mu == found_mu and m < found):
				found = m
				found_mu = mu
	if found.is_empty() and body.is_inside_tree():
		# look ahead along the velocity (and down, for something resting or sliding) so the first touch is right too
		var v: Vector3 = body.linear_velocity
		var dirs: Array = [Vector3.DOWN * (_reach + 0.1)]
		if v.length() > 0.5:
			dirs.push_front(v.normalized() * (_reach + v.length() / 20.0))
		var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
		for d: Vector3 in dirs:
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(body.global_position, body.global_position + d)
			q.exclude = [body.get_rid()]
			var h: Dictionary = space.intersect_ray(q)
			if not h.is_empty():
				var m: String = TLLaws.material_of(h["collider"])
				if not m.is_empty() and not (h["collider"] as Node).has_node("TLContact"):
					found = m
					break
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
			var law: Dictionary = TLLaws.pair(material, surface)
			other_bounce = float(TLLaws.material(surface)["restitution"])
			_pm.rough = true
			_pm.friction = float(law["friction"])
			var diff: float = float(law["restitution"]) - other_bounce
			_pm.absorbent = diff < 0.0
			_pm.bounce = absf(diff)
		body.physics_material_override = _pm
	_prev_velocity = body.linear_velocity


func _on_body_entered(other: Node) -> void:
	var other_v: Vector3 = Vector3.ZERO
	var other_mass: float = INF
	if other is RigidBody3D:
		other_v = (other as RigidBody3D).linear_velocity
		other_mass = (other as RigidBody3D).mass
		if other.has_node("TLContact"):
			other_v = (other.get_node("TLContact") as TLContact)._prev_velocity
	elif other is CharacterBody3D:
		other_v = (other as CharacterBody3D).velocity
	var speed: float = (_prev_velocity - other_v).length()
	if speed < min_hit_speed:
		return
	var m_eff: float = body.mass if is_inf(other_mass) else body.mass * other_mass / (body.mass + other_mass)
	var impulse: float = m_eff * speed
	hit.emit(other, impulse, speed)
	TLAudio.contact(TLLaws.material_of(other), impulse, body.global_position)
	TLDamage.report(other, impulse, body)
	TLDamage.report(body, impulse, other)
