extends Node3D
## N7. The visitor: the player as a walker between the games of a world. Kernel-owned, visual only: a biped rig on
## the world's ground and a chase camera. It has no body and is in no pack's physics space, so it cannot change a
## game. Where it stands is the world's `player_pos` (the walk script in a scripted run, WASD when a person walks);
## that position is what the scheduler reads.
##
##   visitor.setup(at, facing)      after the node is in the tree (the camera becomes its sibling)
##   visitor.step(pos, frame)       once per world tick
##   visitor.cam                    the chase camera (make it current while nobody is on stage)

var rig: Node3D = null
var cam: TLChaseCam = null
var speed: float = 0.0                  # metres per second, from the last two positions
var _last: Vector3 = Vector3.ZERO
var _yaw: float = 0.0


func setup(at: Vector3, facing: Vector3 = Vector3.FORWARD, cam_opts: Dictionary = {}) -> void:
	name = "TLVisitor"
	position = at
	_last = at
	if facing.length() > 0.001:
		_yaw = atan2(-facing.x, -facing.z)
	rotation.y = _yaw
	rig = TLRigs.build("biped", {})
	if rig != null:
		add_child(rig)
	cam = TLChaseCam.new()
	cam.name = "VisitorCam"
	get_parent().add_child(cam)
	var o: Dictionary = {"distance": 8.5, "height": 3.6, "look_height": 1.7, "stiffness": 0.05, "fov": 60.0}
	o.merge(cam_opts, true)
	cam.setup(self, o)


func step(pos: Vector3, frame: int) -> void:
	var d: Vector3 = pos - _last
	d.y = 0.0
	speed = d.length() * 60.0
	if speed > 0.2:
		_yaw = lerp_angle(_yaw, atan2(-d.x, -d.z), 0.18)
	position = pos
	rotation.y = _yaw
	_last = pos
	if rig != null and visible:
		rig.call("set_locomotion", Vector3(0.0, 0.0, -speed), true)
		rig.call("tick", frame)


func snap() -> void:
	if cam != null:
		cam.snap()
