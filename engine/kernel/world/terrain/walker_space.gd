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
	_params.margin = 0.03
	_params.max_collisions = 4
	_params.recovery_as_collision = false


func _test(from: Transform3D, motion: Vector3) -> bool:
	_params.from = from
	_params.motion = motion
	return PhysicsServer3D.body_test_motion(body, _params, _res)


## Puts the body at `pos` (feet), unchecked.
func place(pos: Vector3) -> void:
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis(), pos))
