extends RefCounted
## Capsule motion queries shared by the village visitor and a pack biped. The caller owns both RIDs.

const RADIUS: float = 0.35
const HEIGHT: float = 1.8

var space: RID = RID()
var body: RID = RID()
var max_slope_deg: float = 55.0
var step_up: float = 0.55
var blocked_ticks: int = 0
var _tags: Dictionary = {}           # body RID -> what it is (for the one line that says what stopped him)
var last_hit: Dictionary = {}
var _params: PhysicsTestMotionParameters3D = PhysicsTestMotionParameters3D.new()
var _res: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()


func _init() -> void:
	_params.max_collisions = 4
	_params.recovery_as_collision = false


func _test(from: Transform3D, motion: Vector3, margin: float = 0.03) -> bool:
	_params.from = from
	_params.motion = motion
	_params.margin = margin
	return PhysicsServer3D.body_test_motion(body, _params, _res)


## Puts the body at `pos` (feet), unchecked.
func place(pos: Vector3) -> void:
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis(), pos))


## The ground height under (x, z), looking down from `from_y`: NAN when there is none within 400 m.
func ground_at(x: float, z: float, from_y: float) -> float:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, from_y - 400.0, z), 1)
	q.exclude = [body]
	var hit: Dictionary = PhysicsServer3D.space_get_direct_state(space).intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else NAN
