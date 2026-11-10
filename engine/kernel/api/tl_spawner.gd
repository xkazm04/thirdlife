class_name TLSpawner
extends Node3D
## Spawns things over time from a factory, with limits, from the seeded generator. Capability: `spawn`.
##
##   var spawner := TLSpawner.create(func(): return TLBall.create({radius = 0.2}),
##       {points = [Vector3(0, 3, 0), Vector3(2, 3, 0)], every_frames = 45, max_alive = 8})
##   ctx.root.add_child(spawner)

signal spawned(node: Node3D)
signal despawned(node: Node3D)

const OPTIONS: Array = ["points", "every_frames", "max_alive", "max_total", "jitter", "lifetime_frames", "kill_below_y",
	"order", "active", "start_delay_frames", "name"]

var factory: Callable                 ## returns a new Node3D (not yet in the tree)
var points: Array = [Vector3.ZERO]    ## spawn points, local to the spawner
var every_frames: int = 60            ## 0 = only spawn_now()
var max_alive: int = 10
var max_total: int = 0                ## 0 = no limit
var jitter: Vector3 = Vector3.ZERO    ## random offset range (+-) per axis, from ctx.rng
var lifetime_frames: int = 0          ## 0 = for ever
var kill_below_y: float = -40.0       ## anything that falls below this is removed (the V3 budget is y = -50)
var order: StringName = &"cycle"      ## &"cycle" or &"random" choice of the spawn point
var active: bool = true
var start_delay_frames: int = 0
var total: int = 0
var _alive: Array = []                # [node, born_frame]
var _frame: int = 0
var _next_point: int = 0


static func create(factory_: Callable, opts: Dictionary = {}) -> TLSpawner:
	TLContext.require("spawn", "TLSpawner")
	var s: TLSpawner = TLSpawner.new()
	s.factory = factory_
	for k: String in opts.keys():
		if OPTIONS.has(k):
			s.set(k, opts[k])
		else:
			push_error("TLSpawner.create: unknown option '%s' (options: %s)" % [k, ", ".join(PackedStringArray(OPTIONS))])
	return s


## Spawns one now (limits still apply). Returns the node, or null.
func spawn_now() -> Node3D:
	if (max_total > 0 and total >= max_total) or _alive.size() >= max_alive or points.is_empty():
		return null
	var made: Variant = factory.call()
	if not (made is Node3D):
		push_error("TLSpawner: the factory must return a Node3D")
		return null
	var node: Node3D = made
	var rng: RandomNumberGenerator = TLContext.current.rng if TLContext.current != null else RandomNumberGenerator.new()
	var idx: int = _next_point % points.size()
	if order == &"random":
		idx = rng.randi_range(0, points.size() - 1)
	_next_point += 1
	var at: Vector3 = points[idx]
	at += Vector3(rng.randf_range(-jitter.x, jitter.x), rng.randf_range(-jitter.y, jitter.y), rng.randf_range(-jitter.z, jitter.z))
	node.position = position + basis * at
	get_parent().add_child(node)
	_alive.append([node, _frame])
	total += 1
	spawned.emit(node)
	return node


## The spawned nodes still alive, oldest first.
func alive() -> Array:
	var out: Array = []
	for a: Array in _alive:
		if is_instance_valid(a[0]):
			out.append(a[0])
	return out


func clear() -> void:
	for a: Array in _alive:
		if is_instance_valid(a[0]):
			despawned.emit(a[0])
			(a[0] as Node).queue_free()
	_alive.clear()


func _physics_process(_delta: float) -> void:
	_frame += 1
	var keep: Array = []
	for a: Array in _alive:
		var node: Variant = a[0]
		if not is_instance_valid(node) or (node as Node).is_queued_for_deletion():
			continue
		var gone: bool = (node as Node3D).global_position.y < kill_below_y
		gone = gone or (lifetime_frames > 0 and _frame - int(a[1]) >= lifetime_frames)
		if gone:
			despawned.emit(node)
			(node as Node).queue_free()
		else:
			keep.append(a)
	_alive = keep
	if active and every_frames > 0 and _frame > start_delay_frames and (_frame - start_delay_frames - 1) % every_frames == 0:
		spawn_now()
