extends RefCounted
## H1g (25 Nov 2026, lane G4: a person asked for "the camera steady behind me like a TV game, no swinging"; the view
## kept moving with the player, and nothing measured it). How much the game's active camera turns and travels: each
## physics frame the runner samples the active camera's heading and position; the figures are the yaw turned (degrees)
## and the distance travelled (metres) over each one second window, as sums of the frame-to-frame changes, so a camera
## that swings or slides back and forth counts, not only one that ends elsewhere. G4's play camera keeps one heading and
## slides after the player (the hoop crosses the frame): the yaw is 0 and the travel is not, which is why both are kept.
## A window that holds a cut (another camera became active) is left out. Shake moves the camera's h/v offsets, not its
## transform, so it adds nothing. Read only: it changes nothing in the run and nothing in the state hash.
## metrics.camera_yaw_p90_dps, camera_yaw_max_dps, camera_move_p90_mps, camera_move_max_mps; all absent when no camera
## was active for a whole second.

const WINDOW: int = 60      # one second of physics frames

var _last_yaw: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _last_id: int = 0
var _yaw_run: Array[float] = []    # frame-to-frame turns since the last cut (degrees; an Array: _push appends to it, a packed array would be a copy)
var _move_run: Array[float] = []   # frame-to-frame travel since the last cut (metres)
var _yaw_sum: float = 0.0
var _move_sum: float = 0.0
var _yaw_s: PackedFloat32Array = PackedFloat32Array()      # degrees turned in each full one second window
var _move_s: PackedFloat32Array = PackedFloat32Array()     # metres travelled in each full one second window


## The heading of `cam` in degrees: its forward direction on the ground plane; for a camera that looks straight down,
## its up direction on the ground plane.
static func yaw_of(cam: Camera3D) -> float:
	var b: Basis = cam.global_transform.basis
	var f: Vector3 = -b.z
	if Vector2(f.x, f.z).length() < 0.05:
		f = b.y
	return rad_to_deg(atan2(f.x, f.z))


## One sample per physics frame: the active camera, or null.
func sample(cam: Camera3D) -> void:
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		_cut(0)
		return
	var id: int = cam.get_instance_id()
	var yaw: float = yaw_of(cam)
	var pos: Vector3 = cam.global_position
	if id != _last_id:
		_cut(id)
		_last_yaw = yaw
		_last_pos = pos
		return
	_yaw_sum = _push(_yaw_run, _yaw_sum, absf(wrapf(yaw - _last_yaw, -180.0, 180.0)))
	_move_sum = _push(_move_run, _move_sum, pos.distance_to(_last_pos))
	_last_yaw = yaw
	_last_pos = pos
	if _yaw_run.size() >= WINDOW:
		_yaw_s.append(_yaw_sum)
		_move_s.append(_move_sum)


static func _push(run: Array[float], sum: float, v: float) -> float:
	run.append(v)
	sum += v
	if run.size() > WINDOW:
		sum -= run[run.size() - WINDOW - 1]
	return sum


func _cut(id: int) -> void:
	_last_id = id
	_yaw_run = []
	_move_run = []
	_yaw_sum = 0.0
	_move_sum = 0.0


static func _p90_max(xs: PackedFloat32Array) -> Array:
	var sorted: PackedFloat32Array = xs.duplicate()
	sorted.sort()
	var idx: int = clampi(int(ceil(0.9 * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return [snappedf(sorted[idx], 0.1), snappedf(sorted[sorted.size() - 1], 0.1)]


## The four figures, or {} when no window was full.
func summary() -> Dictionary:
	if _yaw_s.is_empty():
		return {}
	var y: Array = _p90_max(_yaw_s)
	var m: Array = _p90_max(_move_s)
	return {"camera_yaw_p90_dps": y[0], "camera_yaw_max_dps": y[1], "camera_move_p90_mps": m[0], "camera_move_max_mps": m[1]}
