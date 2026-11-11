class_name TLTrigger
extends Area3D
## A trigger volume: tells you when bodies enter and leave (a goal mouth, a checkpoint, a pickup, a kill zone).
## Make one with `TLBodies.trigger(&"box", Vector3(2, 2, 0.5), {position = ...})`. Capability: `physics`.
## A TLBall that crosses the whole volume inside one physics step (a fast puck through a thin goal line) is still
## reported: the trigger also tests the ball's path of the last step. `entered` and `left` then come together.

signal entered(body: Node3D)      ## a physics body came in (after the group filter)
signal left(body: Node3D)

var group_filter: StringName = &""   ## when set, only bodies in this group count
var enter_count: int = 0             ## how many entries so far
var _inside: Array = []
var _half: Vector3 = Vector3.ZERO          # half extents of the volume in local space (set by TLBodies.trigger)
var _round: bool = false                   # sphere: test the distance instead of the box
var _ctx: TLContext = null                 # N2: the pack this trigger belongs to (found once it is in the tree)


func _init() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_in)
	body_exited.connect(_on_out)


func _passes(body: Node3D) -> bool:
	return group_filter == &"" or body.is_in_group(group_filter)


## N2: the pack this trigger belongs to. The overlap signals arrive from the physics server, outside any kernel
## call, so the trigger names its pack itself before it hands them to pack code.
func _pack() -> TLContext:
	if _ctx == null and is_inside_tree():
		_ctx = TLContext.of(self)
	return _ctx


func _on_in(body: Node3D) -> void:
	if _passes(body) and not _inside.has(body):
		_inside.append(body)
		enter_count += 1
		var before: TLContext = TLContext.enter(_pack())
		entered.emit(body)
		TLContext.leave(before)


func _on_out(body: Node3D) -> void:
	if _inside.has(body):
		_inside.erase(body)
		var before: TLContext = TLContext.enter(_pack())
		left.emit(body)
		TLContext.leave(before)


func _physics_process(_delta: float) -> void:
	if _half == Vector3.ZERO or not is_inside_tree():
		return
	var to_local: Transform3D = global_transform.affine_inverse()
	var pack: TLContext = _pack()
	# N2: only the balls of this trigger's own pack (the group is per pack in a world), never the whole tree's
	for ball: Node in get_tree().get_nodes_in_group(pack.ball_group if pack != null else &"tl_ball"):
		if _inside.has(ball) or not _passes(ball as Node3D):
			continue
		var step: Array = (ball as TLBall).last_step()
		var a: Vector3 = to_local * (step[0] as Vector3)
		var b: Vector3 = to_local * (step[1] as Vector3)
		var grow: float = (ball as TLBall).radius
		if _contains(a, grow) or _contains(b, grow):
			continue                       # it starts or ends inside: the physics engine reports that overlap itself
		if _segment_hits(a, b, grow):
			enter_count += 1
			var before: TLContext = TLContext.enter(pack)
			entered.emit(ball)
			left.emit(ball)
			TLContext.leave(before)


func _contains(p: Vector3, grow: float) -> bool:
	if _round:
		return p.length() <= _half.x + grow
	return absf(p.x) <= _half.x + grow and absf(p.y) <= _half.y + grow and absf(p.z) <= _half.z + grow


func _segment_hits(a: Vector3, b: Vector3, grow: float) -> bool:
	var d: Vector3 = b - a
	if _round:
		var len2: float = d.length_squared()
		var t: float = clampf(-a.dot(d) / len2, 0.0, 1.0) if len2 > 0.0000001 else 0.0
		return (a + d * t).length() <= _half.x + grow
	var t0: float = 0.0
	var t1: float = 1.0
	for axis: int in 3:
		var h: float = _half[axis] + grow
		if absf(d[axis]) < 0.0000001:
			if absf(a[axis]) > h:
				return false
		else:
			var u0: float = (-h - a[axis]) / d[axis]
			var u1: float = (h - a[axis]) / d[axis]
			t0 = maxf(t0, minf(u0, u1))
			t1 = minf(t1, maxf(u0, u1))
			if t0 > t1:
				return false
	return true


## Bodies inside right now, in the order they came in.
func inside() -> Array:
	var out: Array = []
	for b: Variant in _inside:
		if is_instance_valid(b):
			out.append(b)
	return out


func has_inside(body: Node3D) -> bool:
	return _inside.has(body)
