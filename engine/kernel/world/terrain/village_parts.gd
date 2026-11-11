extends RefCounted
## P4. Parts of the village landscape that need no terrain object: the far plain, a road strip on the ground, a bridge,
## the far mesas, the helpers of the scatter. Static functions; landscape.gd is the assembly.

## The far plain: the flat ground with a rectangular hole where the terrain is, so the valley is not covered.
static func far_ground(parent: Node3D, t: RefCounted, key: String) -> void:
	if TLStyle.headless():
		return
	var k: String = key if TLStyle.has_key(key) else "grass"
	var code: float = 1.0 + 16.0 * float(TLStyle.index(k))
	var big: float = 3000.0
	var x0: float = float(t.get("x0"))
	var z0: float = float(t.get("z0"))
	var x1: float = float(t.call("x1"))
	var z1: float = float(t.call("z1"))
	var rects: Array = [Rect2(-big, -big, big + x0, 2.0 * big), Rect2(x1, -big, big - x1, 2.0 * big),
		Rect2(x0, -big, x1 - x0, big + z0), Rect2(x0, z1, x1 - x0, big - z1)]
	var vs: PackedVector3Array = PackedVector3Array()
	var cu: PackedFloat32Array = PackedFloat32Array()
	var ix: PackedInt32Array = PackedInt32Array()
	for r: Rect2 in rects:
		var b: int = vs.size()
		for p: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			vs.append(Vector3(p.x, 0.0, p.y))
			cu.append_array([p.x, 0.0, p.y, code])
		ix.append_array(PackedInt32Array([b, b + 1, b + 2, b, b + 2, b + 3]))
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	var nn: PackedVector3Array = PackedVector3Array()
	var cc: PackedColorArray = PackedColorArray()
	var uu: PackedVector2Array = PackedVector2Array()
	for i: int in vs.size():
		nn.append(Vector3.UP)
		cc.append(Color.WHITE)
		uu.append(Vector2.ZERO)
	arr[Mesh.ARRAY_NORMAL] = nn
	arr[Mesh.ARRAY_COLOR] = cc
	arr[Mesh.ARRAY_TEX_UV] = uu
	arr[Mesh.ARRAY_CUSTOM0] = cu
	arr[Mesh.ARRAY_INDEX] = ix
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var base: Material = TLStyle.material(StringName(k))
	mesh.surface_set_material(0, base)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "WorldFarGround"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## A strip of road along `path`, every corner on the ground (`t.gy`) plus `dy`.
static func strip(mk: TLMesh, t: RefCounted, path: PackedVector2Array, half: float, dy: float, key: String, tone: float, rng: RandomNumberGenerator, skip_from: int = -1, skip_to: int = -1) -> void:
	var n: int = path.size()
	for i: int in n - 1:
		if i >= skip_from and i <= skip_to:
			continue
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var ta: Vector2 = (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var tb: Vector2 = (path[mini(i + 2, n - 1)] - path[i]).normalized()
		var ra: Vector2 = Vector2(-ta.y, ta.x) * half
		var rb: Vector2 = Vector2(-tb.y, tb.x) * half
		var c: float = tone * (0.94 + 0.12 * rng.randf())
		var pa0: Vector2 = a - ra
		var pa1: Vector2 = a + ra
		var pb1: Vector2 = b + rb
		var pb0: Vector2 = b - rb
		mk.quad_up(Vector3(pa0.x, float(t.call("gy", pa0.x, pa0.y)) + dy, pa0.y), Vector3(pa1.x, float(t.call("gy", pa1.x, pa1.y)) + dy, pa1.y),
			Vector3(pb1.x, float(t.call("gy", pb1.x, pb1.y)) + dy, pb1.y), Vector3(pb0.x, float(t.call("gy", pb0.x, pb0.y)) + dy, pb0.y), key, Color(c, c, c))


static func smooth(ys: PackedFloat32Array, win: int) -> void:
	var n: int = ys.size()
	var out: PackedFloat32Array = ys.duplicate()
	for i: int in n:
		var s: float = 0.0
		var c: int = 0
		for k: int in range(maxi(i - win, 0), mini(i + win, n - 1) + 1):
			s += ys[k]
			c += 1
		out[i] = s / float(c)
	for i: int in n:
		ys[i] = out[i]


## The first tree and the first rock that stand on gentle ground at least 10 m from a road: what a visitor walk may be aimed at.
static func probe_candidate(probe: Dictionary, kind: String, terr: RefCounted, at: Vector3, radius: float) -> void:
	if probe.has(kind):
		return
	if float(terr.call("road_dist", at.x, at.z)) < 10.0 or float(terr.call("river_dist", at.x, at.z)) < 50.0:
		return
	for k: int in range(-7, 8):
		if float(terr.call("slope", at.x + float(k), at.z)) > 0.12:
			return
	probe[kind] = [snappedf(at.x, 0.01), snappedf(at.z, 0.01), snappedf(radius, 0.01)]


## A bridge over the river: a deck on the road's own profile, rails, three piers. The road strips stop where it starts.
static func bridge(parent: Node3D, ws: RefCounted, terr: RefCounted, path: TLKitPath, ys: PackedFloat32Array, a: int, b: int, half: float) -> void:
	var mk: TLMesh = TLMesh.new(38)
	var w: float = half * 2.0 + 1.4
	for i: int in range(a, b):
		var p0: Vector2 = path.pts[i]
		var p1: Vector2 = path.pts[i + 1]
		var mid: Vector2 = (p0 + p1) * 0.5
		var t: Vector2 = (p1 - p0).normalized()
		var yaw: float = rad_to_deg(atan2(t.x, t.y))
		var y_top: float = (ys[i] + ys[i + 1]) * 0.5 + 0.06
		var len: float = p0.distance_to(p1) + 0.12
		mk.push_at(Vector3(mid.x, y_top - 0.25, mid.y), Vector3(0.0, yaw, 0.0))
		mk.box(Vector3(w, 0.5, len), "wood", Color(0.92, 0.9, 0.88), 0.03)
		mk.pop()
		ws.call("add_box", Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), Vector3(mid.x, y_top - 0.25, mid.y)), Vector3(w, 0.5, len))
		var side: Vector2 = Vector2(-t.y, t.x)
		for sg: float in [-1.0, 1.0]:
			var rc: Vector2 = mid + side * sg * (w * 0.5 - 0.12)
			mk.push_at(Vector3(rc.x, y_top + 0.5, rc.y), Vector3(0.0, yaw, 0.0))
			mk.box(Vector3(0.12, 0.1, len), "wood_dark", Color.WHITE, 0.0)
			mk.box(Vector3(0.1, 0.1, len), "wood_dark", Color.WHITE, 0.0, Vector3(0.0, -0.3, 0.0))
			mk.pop()
			ws.call("add_box", Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), Vector3(rc.x, y_top + 0.6, rc.y)), Vector3(0.3, 1.2, len))
			if (i - a) % 2 == 0:
				mk.push_at(Vector3(rc.x, y_top + 0.45, rc.y), Vector3(0.0, yaw, 0.0))
				mk.box(Vector3(0.2, 1.0, 0.2), "wood_dark", Color.WHITE, 0.02)
				mk.pop()
	for pier_i: int in [a + 2, (a + b) / 2, b - 2]:
		var pc: Vector2 = path.pts[pier_i]
		var t2: Vector2 = (path.pts[mini(pier_i + 1, path.pts.size() - 1)] - path.pts[maxi(pier_i - 1, 0)]).normalized()
		var foot: float = float(terr.call("gy", pc.x, pc.y)) - 1.0
		var top: float = ys[pier_i] - 0.2
		mk.push_at(Vector3(pc.x, (foot + top) * 0.5, pc.y), Vector3(0.0, rad_to_deg(atan2(t2.x, t2.y)), 0.0))
		mk.box(Vector3(w - 0.6, top - foot, 1.3), "concrete_dark", Color.WHITE, 0.05)
		mk.pop()
	parent.add_child(mk.instance("WorldBridge"))


## Far mesas: flat-topped cliffs on the skyline, one mesh (N7). Returns how many.
## P6: every mesa has a grass foot (it rises from the plain instead of standing on it) and, in `trees_out`, the places
## of pines at its foot and on its cap (Transform3D each; the caller draws them).
static func mesas(parent: Node3D, rng: RandomNumberGenerator, centre: Vector2, reach: float, count: int, trees_out: Array = []) -> int:
	var mk_far: TLMesh = TLMesh.new(35)
	var rng6: RandomNumberGenerator = RandomNumberGenerator.new()      # the mesas keep the shapes they had
	rng6.seed = 6060
	for i: int in count:
		var a: float = TAU * (float(i) + rng.randf() * 0.7) / float(maxi(1, count))
		var d: float = reach + 330.0 + rng.randf() * 420.0
		var r: float = 45.0 + rng.randf() * 85.0
		var h: float = 34.0 + rng.randf() * 70.0
		var at: Vector3 = Vector3(centre.x + cos(a) * d, -3.0, centre.y + sin(a) * d)
		var tone: float = 0.9 + 0.2 * rng.randf()
		var rot: float = rng.randf() * 360.0
		var sz: float = 0.6 + rng.randf() * 0.5
		mk_far.push_at(at, Vector3(0.0, rot, 0.0), Vector3(1.0, 1.0, sz))
		# an uneven outline (still star-shaped), a scree foot, three strata of other tones, a grass cap
		var sides: int = 9 + rng.randi_range(0, 3)
		var unit: PackedVector2Array = PackedVector2Array()
		for v: int in sides:
			var pa: float = TAU * float(v) / float(sides)
			unit.append(Vector2(cos(pa), sin(pa)) * (0.84 + 0.3 * rng.randf()))
		var outline: Callable = func(scale: float) -> PackedVector2Array:
			var out: PackedVector2Array = PackedVector2Array()
			for u: Vector2 in unit:
				out.append(u * scale)
			return out
		mk_far.prism(outline.call(r * 2.5), 2.4, h * 0.2, "grass_dry", Color(0.86, 0.93, 0.8), 0.54, true, false)
		var rb: Basis = Basis(Vector3.UP, deg_to_rad(rot))
		for q: int in 9 + rng6.randi_range(0, 7):
			var ta: float = rng6.randf() * TAU
			var tr: float = r * rng6.randf_range(1.5, 2.35)
			var ty: float = 2.4 + (h * 0.2 - 2.4) * clampf((2.5 * r - tr) / (1.15 * r), 0.0, 1.0) * 0.8
			var ts: float = rng6.randf_range(1.6, 2.6)
			trees_out.append(Transform3D(Basis(Vector3.UP, rng6.randf() * TAU).scaled(Vector3(ts, ts * rng6.randf_range(0.95, 1.2), ts)),
				Vector3(at.x, at.y + ty - 0.4, at.z) + rb * Vector3(cos(ta) * tr, 0.0, sin(ta) * tr * sz)))
		for q: int in 4 + rng6.randi_range(0, 4):
			var ta: float = rng6.randf() * TAU
			var tr: float = r * 0.81 * rng6.randf_range(0.15, 0.62)
			var ts: float = rng6.randf_range(1.5, 2.3)
			trees_out.append(Transform3D(Basis(Vector3.UP, rng6.randf() * TAU).scaled(Vector3(ts, ts, ts)),
				Vector3(at.x, at.y + h * 1.3 + 2.2, at.z) + rb * Vector3(cos(ta) * tr, 0.0, sin(ta) * tr * sz)))
		mk_far.prism(outline.call(r * 1.28), 0.0, h * 0.34, "cliff", Color(tone * 0.88, tone * 0.88, tone * 0.88), 0.82)
		for k: int in 3:
			var kt: float = tone * (0.9 + 0.1 * float((k + i) % 2)) * (0.94 + 0.06 * float(k))
			var y0: float = h * 0.3 + h * float(k) / 3.0
			mk_far.prism(outline.call(r * (1.0 - 0.07 * float(k))), y0, y0 + h / 3.0, "cliff", Color(kt, kt * 0.98, kt * 0.96), 0.95)
		mk_far.prism(outline.call(r * 0.81), h * 1.3, h * 1.3 + 2.5, "grass_dry", Color.WHITE, 0.96)
		if rng.randf() > 0.5:
			mk_far.push_at(Vector3(r * 0.18, 0.0, 0.0))
			mk_far.prism(outline.call(r * 0.46), h * 1.3, h * 1.75, "cliff", Color(tone, tone, tone), 0.84)
			mk_far.prism(outline.call(r * 0.38), h * 1.75, h * 1.75 + 2.0, "grass_dry", Color.WHITE, 0.96)
			mk_far.pop()
		mk_far.pop()
	if count > 0:
		var far: MeshInstance3D = mk_far.instance("WorldMesas")
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(far)
	return count


## P6. Trees and bushes along the roads between the venues: never on a road, a pad or the river (`is_free` is the
## landscape's own test), never on a steep bank. Returns [trees, bushes] (Transform3D each).
static func road_side(rng: RandomNumberGenerator, terr: RefCounted, road_pts: PackedVector2Array, half: float, rv_half: float, is_free: Callable, want_trees: int, want_bushes: int) -> Array:
	var trees: Array = []
	var bushes: Array = []
	if road_pts.is_empty():
		return [trees, bushes]
	var tries: int = 0
	while (trees.size() < want_trees or bushes.size() < want_bushes) and tries < (want_trees + want_bushes) * 30:
		tries += 1
		var tree: bool = trees.size() < want_trees and (tries % 2 == 0 or bushes.size() >= want_bushes)
		var q: Vector2 = road_pts[rng.randi_range(0, road_pts.size() - 1)]
		var a: float = rng.randf() * TAU
		var p: Vector2 = q + Vector2(cos(a), sin(a)) * (half + (6.5 + rng.randf() * 15.0 if tree else 1.6 + rng.randf() * 8.0))
		if not bool(is_free.call(p, 9.0 if tree else 6.5, half + (4.5 if tree else 1.2), rv_half + 4.0)) or float(terr.call("slope", p.x, p.y)) > 0.26:
			continue
		var sc: float = rng.randf_range(0.75, 1.2) if tree else rng.randf_range(0.7, 1.3)
		var x: Transform3D = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.15), sc)), Vector3(p.x, float(terr.call("gy", p.x, p.y)), p.y))
		if tree:
			trees.append(x)
		else:
			bushes.append(x)
	return [trees, bushes]


## P6. Clumps of pines on the far plain between the village's hills and the mesas, appended to `out`.
static func plain_clumps(rng: RandomNumberGenerator, terr: RefCounted, centre: Vector2, reach: float, count: int, out: Array) -> void:
	for k: int in count:
		var ca: float = rng.randf() * TAU
		var cc: Vector2 = centre + Vector2(cos(ca), sin(ca)) * (reach + 150.0 + rng.randf() * 420.0)
		if bool(terr.call("inside", cc.x, cc.y, -40.0)):
			continue
		for q: int in rng.randi_range(5, 10):
			var cp: Vector2 = cc + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * 34.0
			var cs: float = rng.randf_range(1.3, 2.2)
			out.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(cs, cs * rng.randf_range(0.95, 1.2), cs)), Vector3(cp.x, -0.3, cp.y)))


## P6. The rock edge of a pad: two or three rocks on one fence span (`a0`..`a1` round the pad's centre `f`, plot
## radius `r`), larger where `big` (0..1) is: the middle of the arc. Appended to `out`.
static func edge_rocks(rng: RandomNumberGenerator, f: Vector3, r: float, a0: float, a1: float, big: float, out: Array) -> void:
	for q: int in 2 + int(rng.randi_range(0, 1)):
		var qa: float = lerpf(a0, a1, (float(q) + rng.randf()) / 3.0)
		var qs: float = (0.9 + 1.5 * big * rng.randf()) * rng.randf_range(0.8, 1.25)
		var qp: Vector3 = f + Vector3(cos(qa), 0.0, sin(qa)) * (r + 3.4 + rng.randf() * 2.2)
		out.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(qs, qs * rng.randf_range(0.8, 1.3), qs)), qp + Vector3(0.0, -0.3, 0.0)))
