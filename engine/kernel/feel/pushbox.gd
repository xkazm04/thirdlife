extends Node
## K8 feel kit (lane N1, night of 22 Nov 2026): the pushbox of one pack. Bodies that opted in with TLHit.pushbox never end
## a physics frame closer (centre to centre, on the ground plane) than the sum of their pushbox radii. It runs after every
## other node of the frame (process_physics_priority) and resolves each pair once, in the order the bodies opted in:
##   each of a pair moves away by half the penetration (move_and_collide, the other body of the pair excepted: a wall
##   still stops him); a body in hit-stop does not move (the other takes it all); a body in a stun or on the ground does
##   not push back (it takes it all from one that stands free); two in hit-stop stay as they are.
## Deterministic: no randomness, no clock; a pair exactly on top of each other parts along the first body's right.

const PRIORITY: int = 1000
const TALL: float = 1.6               # two bodies further apart than this in height (one on a ledge above) do not push

var bodies: Array = []


func _init() -> void:
	name = "TLPushbox"
	process_physics_priority = PRIORITY


func add(b: TLBiped) -> void:
	if not bodies.has(b):
		bodies.append(b)


func remove(b: TLBiped) -> void:
	bodies.erase(b)


## Smallest centre distance (ground plane) minus the sum of the radii over all pairs now: >= 0 when nothing overlaps.
func worst_gap() -> float:
	var live := _live()
	var worst := INF
	for i: int in live.size():
		for j: int in range(i + 1, live.size()):
			var a: TLBiped = live[i]
			var b: TLBiped = live[j]
			var d := Vector2(b.global_position.x - a.global_position.x, b.global_position.z - a.global_position.z).length()
			worst = minf(worst, d - _radius(a) - _radius(b))
	return worst


func _live() -> Array:
	var out: Array = []
	for b: Variant in bodies:
		if is_instance_valid(b) and (b as Node).is_inside_tree():
			out.append(b)
	return out


static func _radius(b: TLBiped) -> float:
	var r: float = b._feel.box_radius if b._feel != null else -1.0
	return r if r > 0.0 else b.body_radius() + 0.02


static func _fixed(b: TLBiped) -> bool:
	return b._feel != null and b._feel.stop_left > 0


static func _limp(b: TLBiped) -> bool:
	return b.is_down() or (b._feel != null and b._feel.stun_left > 0)


func _physics_process(_delta: float) -> void:
	var live := _live()
	for i: int in live.size():
		for j: int in range(i + 1, live.size()):
			_pair(live[i], live[j])


func _pair(a: TLBiped, b: TLBiped) -> void:
	var pa := a.global_position
	var pb := b.global_position
	if absf(pa.y - pb.y) > TALL:
		return
	var d := Vector2(pb.x - pa.x, pb.z - pa.z)
	var need := _radius(a) + _radius(b)
	var dist := d.length()
	if dist >= need:
		return
	var n := d / dist if dist > 0.0001 else Vector2(a.global_transform.basis.x.x, a.global_transform.basis.x.z).normalized()
	var pen := need - dist
	var fa := _fixed(a)
	var fb := _fixed(b)
	if fa and fb:
		return
	var wa := 0.5
	if fa:
		wa = 0.0
	elif fb:
		wa = 1.0
	elif _limp(a) != _limp(b):
		wa = 1.0 if _limp(a) else 0.0
	_part(a, b, Vector3(-n.x, 0.0, -n.y) * pen * wa)
	_part(b, a, Vector3(n.x, 0.0, n.y) * pen * (1.0 - wa))


static func _part(who: TLBiped, other: TLBiped, by: Vector3) -> void:
	if by.length_squared() < 1e-10:
		return
	var had := who.get_collision_exceptions().has(other)
	if not had:
		who.add_collision_exception_with(other)
	who.move_and_collide(by)
	if not had:
		who.remove_collision_exception_with(other)
