extends Node
## The orbit has already consumed pointer input and placed itself when its child ticks.
## Compose the swing shot from that pose without changing the yaw used by the walker.
var cam: TLOrbitCam
var amount := 0.0
var swing_view := false

func _physics_process(_delta: float) -> void:
	if amount <= 0.0:
		return
	var back := cam.global_basis.z
	var focus := cam.global_position - back * cam.distance
	var heading := Vector3(back.x, 0.0, back.z).normalized()
	var direction := heading
	var tilt := 20.0
	var aim := Vector3.UP * 0.7 - heading * 1.25
	if swing_view:
		# Cut on the catch and release. Sweeping between these views passes behind a steel rib.
		direction = heading.rotated(Vector3.UP, deg_to_rad(78.0) * amount)
		tilt = 58.0
		aim = Vector3.UP * 0.8 - heading * 2.3
	var elevation := asin(clampf(back.y, -1.0, 1.0)) - deg_to_rad(tilt) * amount
	var eye := focus + (direction * cos(elevation) + Vector3.UP * sin(elevation)) * cam.distance
	cam.look_at_from_position(eye, focus + aim * amount, Vector3.UP)
