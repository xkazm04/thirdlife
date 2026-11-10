class_name Track
extends RefCounted
## Closed circuit polyline sampled at ~2 m (from layout.json). sample(station) -> {pos, tangent, right, curv}.

var pts: Array[Vector3] = []
var cum: PackedFloat32Array = PackedFloat32Array()
var length: float = 0.0
var width: float = 10.0


func load_from(d: Dictionary) -> void:
	for p: Array in d["points"]:
		pts.append(Vector3(p[0], p[1], p[2]))
	width = d["width"]
	cum.append(0.0)
	var acc := 0.0
	for i in pts.size():
		acc += pts[i].distance_to(pts[(i + 1) % pts.size()])
		cum.append(acc)
	length = acc


func _idx(s: float) -> int:
	var lo := 0
	var hi := cum.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if cum[mid] <= s:
			lo = mid
		else:
			hi = mid
	return lo


func _pos(s: float) -> Vector3:
	s = fposmod(s, length)
	var i := _idx(s)
	var j := (i + 1) % pts.size()
	var seg := cum[i + 1] - cum[i]
	return pts[i].lerp(pts[j], (s - cum[i]) / maxf(seg, 0.001))


func sample(s: float) -> Dictionary:
	var p := _pos(s)
	var a := _pos(s - 3.0)
	var b := _pos(s + 3.0)
	var t := b - a
	t.y = 0
	t = t.normalized()
	var right := Vector3(-t.z, 0, t.x)
	var t0 := p - a
	t0.y = 0
	var t1 := b - p
	t1.y = 0
	var ang := t0.normalized().signed_angle_to(t1.normalized(), Vector3.UP)
	# signed_angle_to about +Y: positive = counter-clockwise from above (left turn); curvature positive = right turn
	return {"pos": p, "tangent": t, "right": right, "curv": -ang / 3.0}
