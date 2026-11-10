class_name KitRoad
extends RefCounted
## Kit part: road spline -> asphalt ribbon (5 shaded strips so tyre lines read), red/white curbs, optional start line.
## Params: half_w (road half width), curb_w, curb_h, curb_seg (segments per colour block).


static func right_of(t: Vector3) -> Vector3:
	return Vector3(-t.z, 0.0, t.x)


static func build(road: Path, half_w: float = 5.0, curb_w: float = 1.2, curb_h: float = 0.14, curb_seg: int = 2, lift: float = 0.07) -> MeshInstance3D:
	var mk: MK = MK.new(21)
	var offs: Array = [-half_w, -half_w * 0.66, -half_w * 0.16, half_w * 0.16, half_w * 0.66, half_w]
	var tones: Array = [1.08, 0.84, 1.0, 0.84, 1.08]   # rubbered-in tyre lanes read from the ridge
	var n: int = road.count()
	for i: int in n:
		var j: int = (i + 1) % n
		var pi: Vector3 = Vector3(road.pts[i].x, road.ys[i] + lift, road.pts[i].y)
		var pj: Vector3 = Vector3(road.pts[j].x, road.ys[j] + lift, road.pts[j].y)
		var ri: Vector3 = right_of(Vector3(road.tang[i].x, 0, road.tang[i].y))
		var rj: Vector3 = right_of(Vector3(road.tang[j].x, 0, road.tang[j].y))
		var br: float = 1.0 + 0.045 * sin(float(i) * 1.7) * cos(float(i) * 0.37)
		for k: int in 5:
			var c: float = float(tones[k]) * br
			mk.quad_up(pi + ri * float(offs[k]), pi + ri * float(offs[k + 1]), pj + rj * float(offs[k + 1]), pj + rj * float(offs[k]), "tarmac", Color(c, c, c))
		# painted edge lines, a start / finish line, and skid marks where the circuit bends hard (pass 3: reads at hero distance)
		var up2: Vector3 = Vector3(0, 0.012, 0)
		for sd2: float in [-1.0, 1.0]:
			mk.quad_up(pi + ri * sd2 * (half_w - 0.34) + up2, pi + ri * sd2 * (half_w - 0.12) + up2, pj + rj * sd2 * (half_w - 0.12) + up2, pj + rj * sd2 * (half_w - 0.34) + up2, "line_white", Color(0.96, 0.96, 0.96))
		if i == 2:
			for q: int in 10:
				var x0: float = -half_w + 0.5 + float(q) * (half_w * 2.0 - 1.0) / 10.0
				var x1: float = x0 + (half_w * 2.0 - 1.0) / 10.0
				for row: int in 2:
					var t0: float = float(row) * 0.5
					var t1: float = t0 + 0.5
					var key2: String = "line_white" if (q + row) % 2 == 0 else "black"
					mk.quad_up(pi.lerp(pj, t0) + ri * x0 + up2, pi.lerp(pj, t0) + ri * x1 + up2, pi.lerp(pj, t1) + rj * x1 + up2, pi.lerp(pj, t1) + rj * x0 + up2, key2)
		var cv: float = road.curvature(i)
		var side: float = -signf(cv)   # marks drift to the outside of the bend
		if absf(cv) > 0.008 and i % 4 != 0:   # pass 4: darker, wider, and a second pair nearer the kerb, so the marks read in the track frame
			for w: float in [0.0, 1.5, 2.6, 4.1]:
				if w > 2.0 and (i / 5) % 2 == 0:
					continue
				var o0: float = side * (0.5 + w * 0.82 + 0.5 * sin(float(i) * 0.9 + w))
				var o1: float = side * (0.5 + w * 0.82 + 0.5 * sin(float(i + 1) * 0.9 + w))
				var tk: float = 0.46 + 0.1 * sin(float(i) * 2.3 + w)
				mk.quad_up(pi + ri * o0 + up2, pi + ri * (o0 + 0.3) + up2, pj + rj * (o1 + 0.3) + up2, pj + rj * o1 + up2, "tarmac", Color(tk, tk, tk))
		# pass 4: verge detail. A concrete apron strip behind both kerbs, drain slots in it, and a gravel trap on the outside of the bends.
		for sd3: float in [-1.0, 1.0]:
			var e0: float = sd3 * (half_w + curb_w)
			var e1: float = sd3 * (half_w + curb_w + 0.45)
			var at: float = 0.9 + 0.08 * float(i % 3)
			var upv: Vector3 = Vector3(0, -0.03, 0)
			mk.quad_up(pi + ri * e0 + upv, pi + ri * e1 + upv, pj + rj * e1 + upv, pj + rj * e0 + upv, "concrete_dark", Color(at, at, at))
			if i % 4 == 1:
				var m0: Vector3 = pi.lerp(pj, 0.3)
				var m1: Vector3 = pi.lerp(pj, 0.7)
				mk.quad_up(m0 + ri * (e0 + sd3 * 0.12) + upv * 0.6, m0 + ri * (e1 - sd3 * 0.12) + upv * 0.6, m1 + rj * (e1 - sd3 * 0.12) + upv * 0.6, m1 + rj * (e0 + sd3 * 0.12) + upv * 0.6, "black", Color(1.6, 1.6, 1.6))
		var cvn: float = road.curvature(j)
		if absf(cv) > 0.006 and absf(cvn) > 0.006:
			var g0: float = side * (half_w + curb_w + 0.45)
			var gw0: float = side * (half_w + curb_w + 0.45 + clampf((absf(cv) - 0.006) * 260.0, 0.0, 2.6))
			var gw1: float = side * (half_w + curb_w + 0.45 + clampf((absf(cvn) - 0.006) * 260.0, 0.0, 2.6))
			var gt: float = 0.92 + 0.1 * float((i * 7) % 3) / 2.0
			var upg: Vector3 = Vector3(0, -0.035, 0)
			mk.quad_up(pi + ri * g0 + upg, pi + ri * gw0 + upg, pj + rj * gw1 + upg, pj + rj * g0 + upg, "sand", Color(gt, gt * 0.97, gt * 0.9))
		# curbs
		var red: bool = (i / curb_seg) % 2 == 0
		var key: String = "curb_red" if red else "curb_white"
		for sd: float in [-1.0, 1.0]:
			var a0: float = sd * half_w
			var a1: float = sd * (half_w + curb_w)
			var p0: Vector3 = pi + ri * a0
			var p1: Vector3 = pi + ri * a1
			var q0: Vector3 = pj + rj * a0
			var q1: Vector3 = pj + rj * a1
			var up: Vector3 = Vector3(0, curb_h, 0)
			var tp: float = 0.025
			mk.hull([p0, p1, q0, q1, p0 + up, p1 + up * 0.6, q0 + up, q1 + up * 0.6], key, Color(1, 1, 1))
	var mi: MeshInstance3D = mk.instance("road")
	mi.name = "Road"
	return mi


## River ribbon: UV.x runs along the flow (metres / 10), UV.y across 0..1. Water level = path y + lift.
static func river_ribbon(river: Path, half_w: float = 5.5, lift: float = 0.0) -> MeshInstance3D:
	var mk: MK = MK.new(22)
	var n: int = river.count()
	for i: int in n - 1:
		var j: int = i + 1
		var pi: Vector3 = Vector3(river.pts[i].x, river.ys[i] + lift, river.pts[i].y)
		var pj: Vector3 = Vector3(river.pts[j].x, river.ys[j] + lift, river.pts[j].y)
		var ri: Vector3 = right_of(Vector3(river.tang[i].x, 0, river.tang[i].y))
		var rj: Vector3 = right_of(Vector3(river.tang[j].x, 0, river.tang[j].y))
		var wi: float = half_w * (0.85 + 0.3 * sin(float(i) * 0.31))
		var wj: float = half_w * (0.85 + 0.3 * sin(float(j) * 0.31))
		var a: Vector3 = pi - ri * wi
		var b: Vector3 = pi + ri * wi
		var c: Vector3 = pj + rj * wj
		var d: Vector3 = pj - rj * wj
		var u0: float = river.s[i] / 10.0
		var u1: float = river.s[j] / 10.0
		var n1: Vector3 = (b - a).cross(c - a)
		if n1.y >= 0.0:
			mk.tri(a, b, c, "water", Color.WHITE, Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1))
			mk.tri(a, c, d, "water", Color.WHITE, Vector2(u0, 0), Vector2(u1, 1), Vector2(u1, 0))
		else:
			mk.tri(a, c, b, "water", Color.WHITE, Vector2(u0, 0), Vector2(u1, 1), Vector2(u0, 1))
			mk.tri(a, d, c, "water", Color.WHITE, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1))
	var mi: MeshInstance3D = mk.instance("river")
	mi.name = "River"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
