extends RefCounted
## 1.10 (lane flight round 2): TLBiped's figure on a ledge or a bar (internal to TLBiped, not pack API). On a bar the rig
## turns about the bar by the swing's angle (the body put the feet on that arc, so the hands meet the bar) and faces
## across the bar; on a ledge it hangs SINK lower (its arms are overhead; the body's hands are at chest height), easing
## back through the mantle; after a release or a drop it turns upright again over about 12 ticks. A biped that never
## grips keeps its rig transform untouched.

const SINK: float = 0.4
var tilt: Quaternion = Quaternion.IDENTITY
var sink: float = 0.0
var base: Transform3D = Transform3D.IDENTITY
var kept: bool = false


## The facing across the bar nearest the body's current one (it does not flip each half swing).
static func bar_facing(body: Node3D, walker: RefCounted) -> float:
	var side: Vector3 = (walker.get("bar_axis") as Vector3).cross(Vector3.DOWN)
	side.y = 0.0
	if side.length() < 0.001:
		return body.rotation.y
	side = side.normalized()
	if (-body.global_transform.basis.z).dot(side) < 0.0:
		side = -side
	return atan2(-side.x, -side.z)


func pose(body: Node3D, rig: Node3D, walker: RefCounted, body_scale: float) -> void:
	var m: String = str(walker.get("mode"))
	var gripping: bool = m == "bar" or m == "hang" or m == "mantle"
	if not gripping and tilt.is_equal_approx(Quaternion.IDENTITY) and sink == 0.0:
		if kept:
			rig.transform = base
			kept = false
		return
	if not kept:
		base = rig.transform
		kept = true
	if m == "bar":
		tilt = Quaternion(Basis((walker.get("bar_axis") as Vector3).normalized(), float(walker.get("bar_theta"))))
		sink = 0.0
	elif m == "hang" or m == "mantle":
		tilt = Quaternion.IDENTITY
		sink = SINK * body_scale if m == "hang" else SINK * body_scale * (1.0 - smoothstep(0.0, 0.6, float(walker.get("mantle_progress"))))
	else:
		tilt = tilt.slerp(Quaternion.IDENTITY, 0.25)
		if tilt.angle_to(Quaternion.IDENTITY) < 0.01:
			tilt = Quaternion.IDENTITY
		sink = move_toward(sink, 0.0, 0.06)
	var own: Basis = body.global_transform.basis.orthonormalized()
	rig.transform = Transform3D(own.inverse() * Basis(tilt) * own * base.basis, base.origin + Vector3(0.0, -sink, 0.0))
