class_name TLMesh
extends RefCounted
## MeshKit: the generator toolbox every asset script uses. Flat-shaded faceted primitives accumulated per
## material key (a palette key in data/style.json) and baked to one ArrayMesh with one surface per key.
## Optional rigid skinning: set `bone` (index) before emitting and the part follows that bone.
## Conventions: metres, Y up, forward -Z. Primitives are emitted in the current transform `tf`.

class Surf:
	var v: PackedVector3Array = PackedVector3Array()
	var n: PackedVector3Array = PackedVector3Array()
	var c: PackedColorArray = PackedColorArray()
	var uv: PackedVector2Array = PackedVector2Array()
	var b: PackedInt32Array = PackedInt32Array()
	var w: PackedFloat32Array = PackedFloat32Array()
	var cu: PackedFloat32Array = PackedFloat32Array()   # CUSTOM0: part-local xyz + (face axis + 4 * grain axis + 16 * palette column)
	var k16: float = 0.0   # 16 * palette lookup column of this key (TLStyle.index)

var surfs: Dictionary = {}
var tf: Transform3D = Transform3D.IDENTITY
var bone: int = -1
var skinned: bool = false
var _stack: Array[Transform3D] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var tri_count: int = 0
var grain: int = 1   # preferred grain axis (0 x, 1 y, 2 z) in part-local space; box() uses its longest axis
var mats: Dictionary = {}   # optional key -> Material override (e.g. a hologram surface inside a toon mesh)
var uv_fixed: bool = false   # when true every vertex gets uv_value (hologram dissolve uses uv.x of a whole part)
var uv_value: Vector2 = Vector2.ZERO


func _init(seed_: int = 1) -> void:
	rng.seed = seed_


# ------------------------------------------------------------------ transform stack
func push(t: Transform3D) -> TLMesh:
	_stack.append(tf)
	tf = tf * t
	return self


func push_at(p: Vector3, euler_deg: Vector3 = Vector3.ZERO, s: Vector3 = Vector3.ONE) -> TLMesh:
	var b: Basis = Basis.from_euler(Vector3(deg_to_rad(euler_deg.x), deg_to_rad(euler_deg.y), deg_to_rad(euler_deg.z)))
	b = b.scaled(s)
	return push(Transform3D(b, p))


func pop() -> TLMesh:
	tf = _stack.pop_back()
	return self


func _surf(key: String) -> Surf:
	if not surfs.has(key):
		var ns: Surf = Surf.new()
		ns.k16 = 16.0 * float(TLStyle.index(key))
		surfs[key] = ns
	return surfs[key]


# ------------------------------------------------------------------ raw emit
func _custom(s: Surf, a: Vector3, b: Vector3, c: Vector3) -> void:
	# part-local coordinates (before tf) so procedural surface detail sticks to the part and needs no UVs
	var n: Vector3 = (b - a).cross(c - a).abs()
	var ax: int = 0 if (n.x >= n.y and n.x >= n.z) else (1 if n.y >= n.z else 2)
	var w: float = float(ax + 4 * grain) + s.k16
	for p: Vector3 in [a, b, c]:
		s.cu.append(p.x); s.cu.append(p.y); s.cu.append(p.z); s.cu.append(w)


## A triangle, CCW seen from outside (the side its normal points to). Emitted with Godot's CW winding.
func tri(p0: Vector3, p1: Vector3, p2: Vector3, key: String, col: Color = Color.WHITE, uv0: Vector2 = Vector2.ZERO,
		uv1: Vector2 = Vector2.ZERO, uv2: Vector2 = Vector2.ZERO) -> void:
	var a: Vector3 = tf * p0
	var b: Vector3 = tf * p1
	var c: Vector3 = tf * p2
	var nrm: Vector3 = (b - a).cross(c - a)
	if nrm.length_squared() < 1e-12:
		return
	nrm = nrm.normalized()
	var s: Surf = _surf(key)
	s.v.append(a); s.v.append(c); s.v.append(b)
	s.n.append(nrm); s.n.append(nrm); s.n.append(nrm)
	s.c.append(col); s.c.append(col); s.c.append(col)
	_custom(s, p0, p2, p1)
	if uv_fixed:
		s.uv.append(uv_value); s.uv.append(uv_value); s.uv.append(uv_value)
	else:
		s.uv.append(uv0); s.uv.append(uv2); s.uv.append(uv1)
	if skinned:
		for i: int in 3:
			s.b.append(bone); s.b.append(0); s.b.append(0); s.b.append(0)
			s.w.append(1.0); s.w.append(0.0); s.w.append(0.0); s.w.append(0.0)
	tri_count += 1


## Triangle with explicit per-vertex normals (already in world/tf space after transform by basis) and colours.
func tri_n(p0: Vector3, p1: Vector3, p2: Vector3, n0: Vector3, n1: Vector3, n2: Vector3, key: String,
		c0: Color, c1: Color, c2: Color) -> void:
	var a: Vector3 = tf * p0
	var b: Vector3 = tf * p1
	var c: Vector3 = tf * p2
	var nb: Basis = tf.basis.inverse().transposed()
	var s: Surf = _surf(key)
	s.v.append(a); s.v.append(c); s.v.append(b)
	s.n.append((nb * n0).normalized()); s.n.append((nb * n2).normalized()); s.n.append((nb * n1).normalized())
	s.c.append(c0); s.c.append(c2); s.c.append(c1)
	s.uv.append(Vector2.ZERO); s.uv.append(Vector2.ZERO); s.uv.append(Vector2.ZERO)
	_custom(s, p0, p2, p1)
	if skinned:
		for i: int in 3:
			s.b.append(bone); s.b.append(0); s.b.append(0); s.b.append(0)
			s.w.append(1.0); s.w.append(0.0); s.w.append(0.0); s.w.append(0.0)
	tri_count += 1


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, key: String, col: Color = Color.WHITE) -> void:
	tri(a, b, c, key, col)
	tri(a, c, d, key, col)


## Quad whose normal is forced to point up (+Y): terrain, roads, water.
func quad_up(a: Vector3, b: Vector3, c: Vector3, d: Vector3, key: String, col: Color = Color.WHITE) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.y < 0.0:
		quad(d, c, b, a, key, col)
	else:
		quad(a, b, c, d, key, col)


## Two-sided quad (skirts): emitted both ways so winding does not matter.
func quad_up_any(a: Vector3, b: Vector3, c: Vector3, d: Vector3, key: String, col: Color = Color.WHITE) -> void:
	quad(a, b, c, d, key, col)
	quad(d, c, b, a, key, col)


## Convex polygon fan, oriented so the normal points away from `centre` (local space).
func face_out(pts: Array, centre: Vector3, key: String, col: Color = Color.WHITE) -> void:
	var cen: Vector3 = Vector3.ZERO
	for p: Vector3 in pts:
		cen += p
	cen /= float(pts.size())
	var n: Vector3 = (pts[1] - pts[0]).cross(pts[2] - pts[0])
	var arr: Array = pts
	if n.dot(cen - centre) < 0.0:
		arr = pts.duplicate()
		arr.reverse()
	for i: int in range(1, arr.size() - 1):
		tri(arr[0], arr[i], arr[i + 1], key, col)


# ------------------------------------------------------------------ solids
func box(size: Vector3, key: String, col: Color = Color.WHITE, ch: float = 0.0, ofs: Vector3 = Vector3.ZERO) -> void:
	var h: Vector3 = size * 0.5
	var c: float = minf(ch, minf(h.x, minf(h.y, h.z)) * 0.95)
	var g_keep: int = grain
	grain = 0 if (size.x >= size.y and size.x >= size.z) else (1 if size.y >= size.z else 2)
	_box(h, c, key, col, ofs)
	grain = g_keep


func _box(h: Vector3, c: float, key: String, col: Color, ofs: Vector3) -> void:
	if c <= 0.0001:
		for sg: float in [-1.0, 1.0]:
			face_out([ofs + Vector3(sg * h.x, -h.y, -h.z), ofs + Vector3(sg * h.x, h.y, -h.z), ofs + Vector3(sg * h.x, h.y, h.z), ofs + Vector3(sg * h.x, -h.y, h.z)], ofs, key, col)
			face_out([ofs + Vector3(-h.x, sg * h.y, -h.z), ofs + Vector3(h.x, sg * h.y, -h.z), ofs + Vector3(h.x, sg * h.y, h.z), ofs + Vector3(-h.x, sg * h.y, h.z)], ofs, key, col)
			face_out([ofs + Vector3(-h.x, -h.y, sg * h.z), ofs + Vector3(h.x, -h.y, sg * h.z), ofs + Vector3(h.x, h.y, sg * h.z), ofs + Vector3(-h.x, h.y, sg * h.z)], ofs, key, col)
		return
	var S: Array = [-1.0, 1.0]
	var vx: Callable = func(sx: float, sy: float, sz: float) -> Vector3: return ofs + Vector3(sx * h.x, sy * (h.y - c), sz * (h.z - c))
	var vy: Callable = func(sx: float, sy: float, sz: float) -> Vector3: return ofs + Vector3(sx * (h.x - c), sy * h.y, sz * (h.z - c))
	var vz: Callable = func(sx: float, sy: float, sz: float) -> Vector3: return ofs + Vector3(sx * (h.x - c), sy * (h.y - c), sz * h.z)
	for s1: float in S:
		face_out([vx.call(s1, -1.0, -1.0), vx.call(s1, 1.0, -1.0), vx.call(s1, 1.0, 1.0), vx.call(s1, -1.0, 1.0)], ofs, key, col)
		face_out([vy.call(-1.0, s1, -1.0), vy.call(1.0, s1, -1.0), vy.call(1.0, s1, 1.0), vy.call(-1.0, s1, 1.0)], ofs, key, col)
		face_out([vz.call(-1.0, -1.0, s1), vz.call(1.0, -1.0, s1), vz.call(1.0, 1.0, s1), vz.call(-1.0, 1.0, s1)], ofs, key, col)
		for s2: float in S:
			face_out([vx.call(s1, s2, -1.0), vx.call(s1, s2, 1.0), vy.call(s1, s2, 1.0), vy.call(s1, s2, -1.0)], ofs, key, col)
			face_out([vy.call(-1.0, s1, s2), vy.call(1.0, s1, s2), vz.call(1.0, s1, s2), vz.call(-1.0, s1, s2)], ofs, key, col)
			face_out([vx.call(s1, -1.0, s2), vx.call(s1, 1.0, s2), vz.call(s1, 1.0, s2), vz.call(s1, -1.0, s2)], ofs, key, col)
			for s3: float in S:
				face_out([vx.call(s1, s2, s3), vy.call(s1, s2, s3), vz.call(s1, s2, s3)], ofs, key, col)


## Box spanning min..max (local space).
func boxm(mn: Vector3, mx: Vector3, key: String, col: Color = Color.WHITE, ch: float = 0.0) -> void:
	box(mx - mn, key, col, ch, (mn + mx) * 0.5)


## A square-section bar from a to b (w across X-ish, h across Y-ish of its own frame).
func bar(a: Vector3, b: Vector3, w: float, h: float, key: String, col: Color = Color.WHITE, ch: float = 0.0) -> void:
	var d: Vector3 = b - a
	var l: float = d.length()
	if l < 1e-5:
		return
	var z: Vector3 = d / l
	var up: Vector3 = Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x: Vector3 = up.cross(z).normalized()
	var y: Vector3 = z.cross(x)
	push(Transform3D(Basis(x, y, z), a))
	box(Vector3(w, h, l), key, col, ch, Vector3(0, 0, l * 0.5))
	pop()


## Convex hull of points (faceted solid). Used for wedges, tapered blocks, rock chunks, car bodies.
func hull(pts: Array, key: String, col: Color = Color.WHITE, key_fn: Callable = Callable()) -> void:
	var n: int = pts.size()
	var cen: Vector3 = Vector3.ZERO
	for p: Vector3 in pts:
		cen += p
	cen /= float(n)
	var seen: Dictionary = {}
	for i: int in n:
		for j: int in range(i + 1, n):
			for k: int in range(j + 1, n):
				var nr: Vector3 = (pts[j] - pts[i]).cross(pts[k] - pts[i])
				if nr.length_squared() < 1e-10:
					continue
				nr = nr.normalized()
				var d: float = nr.dot(pts[i])
				var pos: int = 0
				var neg: int = 0
				for p: Vector3 in pts:
					var s: float = nr.dot(p) - d
					if s > 1e-4:
						pos += 1
					elif s < -1e-4:
						neg += 1
				if pos > 0 and neg > 0:
					continue
				if pos > 0:
					nr = -nr
					d = -d
				var kq: String = "%d,%d,%d,%d" % [roundi(nr.x * 200.0), roundi(nr.y * 200.0), roundi(nr.z * 200.0), roundi(d * 100.0)]
				if seen.has(kq):
					continue
				seen[kq] = true
				var on: Array = []
				for p: Vector3 in pts:
					if absf(nr.dot(p) - d) < 1e-4:
						on.append(p)
				if on.size() < 3:
					continue
				var fc: Vector3 = Vector3.ZERO
				for p: Vector3 in on:
					fc += p
				fc /= float(on.size())
				var u: Vector3 = (on[0] - fc).normalized()
				var v: Vector3 = nr.cross(u)
				on.sort_custom(func(a: Vector3, b: Vector3) -> bool: return atan2((a - fc).dot(v), (a - fc).dot(u)) < atan2((b - fc).dot(v), (b - fc).dot(u)))
				# sorted CCW about nr: normal already outward
				var fk: String = key if not key_fn.is_valid() else String(key_fn.call(nr, d))
				for q: int in range(1, on.size() - 1):
					tri(on[0], on[q], on[q + 1], fk, col)


## Vertical prism: polygon (x,z pairs, convex) extruded from y0 to y1. top_scale shrinks the top ring (frustum).
func prism(poly: PackedVector2Array, y0: float, y1: float, key: String, col: Color = Color.WHITE, top_scale: float = 1.0,
		cap_top: bool = true, cap_bot: bool = true) -> void:
	var n: int = poly.size()
	var cx: float = 0.0
	var cz: float = 0.0
	for p: Vector2 in poly:
		cx += p.x; cz += p.y
	cx /= n; cz /= n
	var centre: Vector3 = Vector3(cx, (y0 + y1) * 0.5, cz)
	var bot: Array = []
	var top: Array = []
	for p: Vector2 in poly:
		bot.append(Vector3(p.x, y0, p.y))
		top.append(Vector3(cx + (p.x - cx) * top_scale, y1, cz + (p.y - cz) * top_scale))
	for i: int in n:
		var j: int = (i + 1) % n
		face_out([bot[i], bot[j], top[j], top[i]], centre, key, col)
	if cap_top:
		face_out(top, centre, key, col)
	if cap_bot:
		face_out(bot, centre, key, col)


func ngon(r: float, seg: int, rot: float = 0.0) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in seg:
		var a: float = rot + TAU * float(i) / float(seg)
		out.append(Vector2(cos(a) * r, sin(a) * r))
	return out


## Faceted cylinder/cone along +Y from y=0 to h (r2<0 => same radius, 0 => cone).
func cyl(r: float, h: float, seg: int, key: String, col: Color = Color.WHITE, r2: float = -1.0, ofs: Vector3 = Vector3.ZERO,
		cap_top: bool = true, cap_bot: bool = true) -> void:
	var ts: float = 1.0 if r2 < 0.0 else r2 / r
	push(Transform3D(Basis.IDENTITY, ofs))
	if ts <= 0.001:
		var poly: PackedVector2Array = ngon(r, seg)
		var apex: Vector3 = Vector3(0, h, 0)
		var centre: Vector3 = Vector3(0, h * 0.3, 0)
		var ring: Array = []
		for i: int in seg:
			var j: int = (i + 1) % seg
			ring.append(Vector3(poly[i].x, 0, poly[i].y))
			face_out([Vector3(poly[i].x, 0, poly[i].y), Vector3(poly[j].x, 0, poly[j].y), apex], centre, key, col)
		if cap_bot:
			face_out(ring, centre, key, col)
	else:
		prism(ngon(r, seg), 0.0, h, key, col, ts, cap_top, cap_bot)
	pop()


## Cylinder between two points.
func cyl_between(a: Vector3, b: Vector3, r: float, seg: int, key: String, col: Color = Color.WHITE, r2: float = -1.0) -> void:
	var d: Vector3 = b - a
	var l: float = d.length()
	if l < 1e-5:
		return
	var y: Vector3 = d / l
	var up: Vector3 = Vector3.RIGHT if absf(y.x) < 0.95 else Vector3.FORWARD
	var z: Vector3 = up.cross(y).normalized()
	var x: Vector3 = y.cross(z)
	push(Transform3D(Basis(x, y, z), a))
	cyl(r, l, seg, key, col, r2)
	pop()


## Low-poly blob (icosphere, subdivided `detail` times) with radial jitter: rocks, foliage, hair, bushes.
func blob(r: Vector3, detail: int, jitter: float, key: String, col: Color = Color.WHITE, vary: float = 0.0, ofs: Vector3 = Vector3.ZERO,
		keep_flat_bottom: bool = false) -> void:
	var t: float = (1.0 + sqrt(5.0)) * 0.5
	var vs: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i: int in vs.size():
		vs[i] = (vs[i] as Vector3).normalized()
	var fs: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for _d: int in detail:
		var nf: Array = []
		var cache: Dictionary = {}
		for f: Array in fs:
			var m: Array = []
			for e: int in 3:
				var a: int = f[e]
				var b: int = f[(e + 1) % 3]
				var kk: int = mini(a, b) * 100000 + maxi(a, b)
				if not cache.has(kk):
					vs.append(((vs[a] as Vector3) + (vs[b] as Vector3)).normalized())
					cache[kk] = vs.size() - 1
				m.append(cache[kk])
			nf.append([f[0], m[0], m[2]]); nf.append([f[1], m[1], m[0]]); nf.append([f[2], m[2], m[1]]); nf.append([m[0], m[1], m[2]])
		fs = nf
	var seed_off: float = rng.randf() * 100.0
	var pv: Array = []
	for v: Vector3 in vs:
		var h: float = sin(v.x * 12.9898 + v.y * 78.233 + v.z * 37.719 + seed_off) * 43758.5453
		h = h - floor(h)
		var p: Vector3 = v * (1.0 + jitter * (h - 0.5) * 2.0)
		p = Vector3(p.x * r.x, p.y * r.y, p.z * r.z)
		if keep_flat_bottom and p.y < -r.y * 0.35:
			p.y = -r.y * 0.35
		pv.append(p + ofs)
	for f: Array in fs:
		var cc: Color = col
		if vary > 0.0:
			var k: float = 1.0 + (rng.randf() - 0.5) * 2.0 * vary
			cc = Color(col.r * k, col.g * k, col.b * k, col.a)
		tri(pv[f[0]], pv[f[1]], pv[f[2]], key, cc)


## Loft through rings of equal point count (convex sections). Faces are oriented away from the section centre.
## uv: x = 0..1 along the loft, y = 0..1 around the ring (the hologram shader's edge lines read this).
func loft(rings: Array, key: String, col: Color = Color.WHITE, cap_start: bool = true, cap_end: bool = true) -> void:
	var nr: int = rings.size()
	var m: int = (rings[0] as Array).size()
	var cens: Array = []
	for r: Array in rings:
		var c: Vector3 = Vector3.ZERO
		for p: Vector3 in r:
			c += p
		cens.append(c / float(m))
	for i: int in nr - 1:
		var u0: float = float(i) / float(nr - 1)
		var u1: float = float(i + 1) / float(nr - 1)
		var ctr: Vector3 = (cens[i] + cens[i + 1]) * 0.5
		for j: int in m:
			var k: int = (j + 1) % m
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][k]
			var c2: Vector3 = rings[i + 1][k]
			var d: Vector3 = rings[i + 1][j]
			var v0: float = float(j) / float(m)
			var v1: float = float(j + 1) / float(m)
			var nrm: Vector3 = (b - a).cross(c2 - a)
			var mid: Vector3 = (a + b + c2 + d) * 0.25
			if nrm.dot(mid - ctr) >= 0.0:
				tri(a, b, c2, key, col, Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1))
				tri(a, c2, d, key, col, Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0))
			else:
				tri(a, c2, b, key, col, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1))
				tri(a, d, c2, key, col, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1))
	if cap_start:
		face_out(rings[0], cens[1], key, col)
	if cap_end:
		face_out(rings[nr - 1], cens[nr - 2], key, col)


## Sweep a convex 2D profile (x = right, y = up in the path frame) along a 3D path.
func sweep(path: PackedVector3Array, profile: PackedVector2Array, key: String, col: Color = Color.WHITE, up_hint: Vector3 = Vector3.UP,
		scale_fn: Callable = Callable()) -> void:
	var rings: Array = []
	var np: int = path.size()
	for i: int in np:
		var t: Vector3 = (path[mini(i + 1, np - 1)] - path[maxi(i - 1, 0)]).normalized()
		var x: Vector3 = t.cross(up_hint).normalized()
		if x.length_squared() < 0.01:
			x = Vector3.RIGHT
		var y: Vector3 = x.cross(t).normalized()
		var s: float = 1.0 if not scale_fn.is_valid() else float(scale_fn.call(float(i) / float(np - 1)))
		var ring: Array = []
		for p: Vector2 in profile:
			ring.append(path[i] + x * p.x * s + y * p.y * s)
		rings.append(ring)
	loft(rings, key, col)


# ------------------------------------------------------------------ rounded forms (pass 3)
func _quad_n(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n0: Vector3, n1: Vector3, n2: Vector3, n3: Vector3, key: String, col: Color) -> void:
	var g: Vector3 = (p1 - p0).cross(p2 - p0)
	if g.length_squared() < 1e-14:
		g = (p2 - p0).cross(p3 - p0)
	if g.dot(n0 + n1 + n2 + n3) < 0.0:
		var tp: Vector3 = p1; p1 = p3; p3 = tp
		var tn: Vector3 = n1; n1 = n3; n3 = tn
	if (p1 - p0).cross(p2 - p0).length_squared() > 1e-14:
		tri_n(p0, p1, p2, n0, n1, n2, key, col, col, col)
	if (p2 - p0).cross(p3 - p0).length_squared() > 1e-14:
		tri_n(p0, p2, p3, n0, n2, n3, key, col, col, col)


## Rounded box: an inner box inflated by a sphere of radius r, with smooth normals, so the part reads as a moulded toy
## form and the ink pass draws no crease on it. seg = arc steps per corner (1 = a smooth-shaded chamfer).
func rbox(size: Vector3, key: String, col: Color = Color.WHITE, r: float = 0.05, ofs: Vector3 = Vector3.ZERO, seg: int = 2) -> void:
	var h: Vector3 = size * 0.5
	var rr: float = minf(r, minf(h.x, minf(h.y, h.z)))
	var inner: Vector3 = h - Vector3(rr, rr, rr)
	var g_keep: int = grain
	grain = 0 if (size.x >= size.y and size.x >= size.z) else (1 if size.y >= size.z else 2)
	var sm: Array = []   # samples across one face coordinate: [offset sign, tan(angle)]
	for i: int in seg + 1:
		sm.append([-1.0, tan(deg_to_rad(-45.0 + 45.0 * float(i) / float(seg)))])
	for i: int in seg + 1:
		sm.append([1.0, tan(deg_to_rad(45.0 * float(i) / float(seg)))])
	var n: int = sm.size()
	for a: int in 3:
		var b: int = (a + 1) % 3
		var c: int = (a + 2) % 3
		for sg: float in [-1.0, 1.0]:
			var ps: Array = []
			var ns: Array = []
			for i: int in n:
				for j: int in n:
					var sv: Vector3 = Vector3.ZERO
					sv[a] = sg
					sv[b] = float(sm[i][1])
					sv[c] = float(sm[j][1])
					sv = sv.normalized()
					var p: Vector3 = Vector3.ZERO
					p[a] = sg * inner[a]
					p[b] = float(sm[i][0]) * inner[b]
					p[c] = float(sm[j][0]) * inner[c]
					ps.append(ofs + p + sv * rr)
					ns.append(sv)
			for i: int in n - 1:
				for j: int in n - 1:
					var i0: int = i * n + j
					var i1: int = (i + 1) * n + j
					var i2: int = (i + 1) * n + j + 1
					var i3: int = i * n + j + 1
					_quad_n(ps[i0], ps[i1], ps[i2], ps[i3], ns[i0], ns[i1], ns[i2], ns[i3], key, col)
	grain = g_keep


## Capsule from a to b (radius r at a, r2 at b) with smooth normals: limbs, thumbs, bumpers, bedrolls.
func capsule(a: Vector3, b: Vector3, r: float, key: String, col: Color = Color.WHITE, seg: int = 8, cap: int = 2, r2: float = -1.0) -> void:
	var d: Vector3 = b - a
	var l: float = d.length()
	if l < 1e-5:
		return
	var y: Vector3 = d / l
	var up: Vector3 = Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD
	var z: Vector3 = up.cross(y).normalized()
	var x: Vector3 = y.cross(z)
	var rb: float = r if r2 < 0.0 else r2
	var rings: Array = []   # [centre, radius, normal sin, normal cos]
	for i: int in cap + 1:
		var la: float = -PI * 0.5 + PI * 0.5 * float(i) / float(cap)
		rings.append([a + y * (sin(la) * r), cos(la) * r, sin(la), cos(la)])
	for i: int in cap + 1:
		var lb: float = PI * 0.5 * float(i) / float(cap)
		rings.append([b + y * (sin(lb) * rb), cos(lb) * rb, sin(lb), cos(lb)])
	var g_keep: int = grain
	grain = 1
	for k: int in rings.size() - 1:
		var ra: Array = rings[k]
		var rc: Array = rings[k + 1]
		for j: int in seg:
			var a0: float = TAU * float(j) / float(seg)
			var a1: float = TAU * float(j + 1) / float(seg)
			var d0: Vector3 = x * cos(a0) + z * sin(a0)
			var d1: Vector3 = x * cos(a1) + z * sin(a1)
			_quad_n((ra[0] as Vector3) + d0 * float(ra[1]), (ra[0] as Vector3) + d1 * float(ra[1]), (rc[0] as Vector3) + d1 * float(rc[1]), (rc[0] as Vector3) + d0 * float(rc[1]),
				d0 * float(ra[3]) + y * float(ra[2]), d1 * float(ra[3]) + y * float(ra[2]), d1 * float(rc[3]) + y * float(rc[2]), d0 * float(rc[3]) + y * float(rc[2]), key, col)
	grain = g_keep


# ------------------------------------------------------------------ bake
func build(mesh_name: String = "mk") -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.resource_name = mesh_name
	var keys: Array = surfs.keys()
	keys.sort()
	var shared: Surf = null   # every toon key goes into ONE surface with THE palette material (pass 3)
	for key: String in keys:
		var s: Surf = surfs[key]
		if not mats.has(key) and TLStyle.is_toon(key):
			if shared == null:
				shared = Surf.new()
			shared.v.append_array(s.v)
			shared.n.append_array(s.n)
			shared.c.append_array(s.c)
			shared.uv.append_array(s.uv)
			shared.cu.append_array(s.cu)
			shared.b.append_array(s.b)
			shared.w.append_array(s.w)
		else:
			_add_surface(mesh, s, mats[key] if mats.has(key) else TLStyle.material(key))
	if shared != null:
		_add_surface(mesh, shared, TLStyle.material("white"))
	mesh.set_meta("tl_hash", content_hash())
	mesh.set_meta("tl_tris", tri_count)
	return mesh


## SHA-1 over every vertex attribute of every surface (keys sorted): the byte identity of the generated mesh.
## Computed from the generator's own arrays, so it works under --headless where the renderer keeps nothing.
func content_hash() -> String:
	var hc: HashingContext = HashingContext.new()
	hc.start(HashingContext.HASH_SHA1)
	var keys: Array = surfs.keys()
	keys.sort()
	for key: String in keys:
		var s: Surf = surfs[key]
		hc.update(key.to_utf8_buffer())
		if s.v.size() == 0:
			continue
		hc.update(s.v.to_byte_array())
		hc.update(s.n.to_byte_array())
		hc.update(s.c.to_byte_array())
		hc.update(s.uv.to_byte_array())
		hc.update(s.cu.to_byte_array())
		if s.b.size() > 0:
			hc.update(s.b.to_byte_array())
	return hc.finish().hex_encode()


## Every triangle as three points (for a ConcavePolygonShape3D), optionally only the surfaces of some keys.
func faces(only_keys: Array = []) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var keys: Array = surfs.keys()
	keys.sort()
	for key: String in keys:
		if only_keys.is_empty() or only_keys.has(key):
			out.append_array((surfs[key] as Surf).v)
	return out


func aabb() -> AABB:
	var first: bool = true
	var bb: AABB = AABB()
	for key: String in surfs:
		for p: Vector3 in (surfs[key] as Surf).v:
			if first:
				bb = AABB(p, Vector3.ZERO)
				first = false
			else:
				bb = bb.expand(p)
	return bb


static func _add_surface(mesh: ArrayMesh, s: Surf, mat: Material) -> void:
	var arr: Array = []; arr.resize(Mesh.ARRAY_MAX)
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): mesh.set_meta(&"tl_arrays", (mesh.get_meta(&"tl_arrays", []) as Array) + [arr])   # P12: `merge` reads these on a worker thread instead of waiting a frame for the renderer
	arr[Mesh.ARRAY_VERTEX] = s.v
	arr[Mesh.ARRAY_NORMAL] = s.n
	arr[Mesh.ARRAY_COLOR] = s.c
	arr[Mesh.ARRAY_TEX_UV] = s.uv
	arr[Mesh.ARRAY_CUSTOM0] = s.cu
	if s.b.size() > 0:
		arr[Mesh.ARRAY_BONES] = s.b
		arr[Mesh.ARRAY_WEIGHTS] = s.w
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


func instance(mesh_name: String = "mk") -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = build(mesh_name)
	mi.name = mesh_name
	return mi


## All vertices (for a convex collision shape or bounds).
func all_points() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for key: String in surfs:
		out.append_array((surfs[key] as Surf).v)
	return out


## Merge whole meshes (each with a transform) into one ArrayMesh, one surface per material, keeping CUSTOM0.
## Used to bake rubble and to merge static site meshes so shadow cascades draw them once.
static func merge(items: Array, mesh_name: String = "merged") -> ArrayMesh:
	var acc: Dictionary = {}
	for it: Array in items:
		var m: Mesh = it[0]
		var t: Transform3D = it[1]
		var nb: Basis = t.basis.inverse().transposed()
		for si: int in m.get_surface_count():
			var mat: Material = m.surface_get_material(si)
			var arr: Array = (m.get_meta(&"tl_arrays") as Array)[si] if m.has_meta(&"tl_arrays") else m.surface_get_arrays(si)   # P12
			if not acc.has(mat):
				acc[mat] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array(), PackedFloat32Array()]
			var d: Array = acc[mat]
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			# packed arrays are values: take them out, append, put them back
			var av: PackedVector3Array = d[0]
			var an: PackedVector3Array = d[1]
			var ac: PackedColorArray = d[2]
			var au: PackedVector2Array = d[3]
			var af: PackedFloat32Array = d[4]
			for i: int in vs.size():
				av.append(t * vs[i])
				an.append((nb * ns[i]).normalized())
			ac.append_array(arr[Mesh.ARRAY_COLOR])
			au.append_array(arr[Mesh.ARRAY_TEX_UV])
			af.append_array(arr[Mesh.ARRAY_CUSTOM0])
			d[0] = av; d[1] = an; d[2] = ac; d[3] = au; d[4] = af
	var out: ArrayMesh = ArrayMesh.new()
	out.resource_name = mesh_name
	for mat: Material in acc:
		var d: Array = acc[mat]
		var arr2: Array = []
		arr2.resize(Mesh.ARRAY_MAX)
		arr2[Mesh.ARRAY_VERTEX] = d[0]
		arr2[Mesh.ARRAY_NORMAL] = d[1]
		arr2[Mesh.ARRAY_COLOR] = d[2]
		arr2[Mesh.ARRAY_TEX_UV] = d[3]
		arr2[Mesh.ARRAY_CUSTOM0] = d[4]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out
