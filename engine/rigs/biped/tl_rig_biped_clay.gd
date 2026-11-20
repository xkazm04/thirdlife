class_name TLRigBipedClay
extends RefCounted
## Diorama night (20 Nov 2026): the clay forms the toy figure is made of (rigs/biped/tl_rig_biped_toy.gd lays them out).
## Every form is a closed, smooth lump emitted into a TLMesh with its own normals, tones and chip mask:
##   ball / ball_fn   an ellipsoid, or any `fn(unit direction) -> point`
##   loft             rounded sections along a spine, a small dome at each end
##   ring             a rolled ring (collar, cuff)
## Each is displaced by a low noise (a hand made it), may stand on a floor (a sole) and may pick its palette key per quad
## (a stripe, a hem). The vertex colour carries the tone (darker towards an end that presses into a neighbour, and the
## baked contact tone below); the vertex alpha carries where paint chips. Internal to the rig; no random, no clock.

# Contact tone (the shade where two lumps press together), baked per vertex. A build runs under `_cache_lock`: first a dry
# pass that only notes every lump as a few spheres (`_collect`), then the real pass, where each grid vertex is darkened by
# the spheres its normal looks at. The result depends on the pieces only (backpack, helmet), not on the colours, so it
# is kept per variant and read back in the same order by every later look.
static var _collect: bool = false
static var _occ: PackedFloat32Array = PackedFloat32Array()     # x, y, z, r of every sphere
static var _ao: PackedFloat32Array = PackedFloat32Array()      # one value per grid vertex, in the order they are emitted
static var _ao_i: int = 0
static var _ao_bake: bool = false
static var _ao_cache: Dictionary = {}
static var _contact_k: float = 1.5
static var _geo: String = ""


## Starts the build of a variant (`geo` names its pieces; k = the strength of the contact tone). True = not baked yet:
## build once now (dry: lumps are only noted), then call bake_real, build for real, bake_end. Call under one lock.
static func bake_begin(geo: String, k: float) -> bool:
	_geo = "%s|%s" % [geo, k]
	_contact_k = 1.5 * k
	_ao_bake = not _ao_cache.has(_geo)
	_collect = _ao_bake
	if _ao_bake:
		_occ = PackedFloat32Array()
	return _ao_bake


static func bake_real() -> void:
	_collect = false
	_ao = PackedFloat32Array() if _ao_bake else _ao_cache[_geo]
	_ao_i = 0


static func bake_end() -> void:
	if _ao_bake:
		_ao_cache[_geo] = _ao
	_ao_bake = false


## Notes a lump as spheres for the contact tone (dry pass): a rolled ring as beads along its centre line, a ball as one
## sphere of its volume, a loft as a sphere at every other section.
static func _note(P: Array, C: Array, pole1: Variant, wrap: bool) -> void:
	var ni: int = P.size()
	var nj: int = (P[0] as Array).size()
	var rad: Array = []
	for i: int in ni:
		var r: float = 0.0
		for j: int in nj:
			r += ((P[i][j] as Vector3) - (C[i] as Vector3)).length()
		rad.append(r / float(nj))
	if not wrap and ni > 1 and (C[0] as Vector3).is_equal_approx(C[ni - 1]):
		var rm: float = 0.0
		for r: float in rad:
			rm = maxf(rm, r)
		var polar: float = ((pole1 as Vector3) - (C[0] as Vector3)).length() if pole1 is Vector3 else rm
		var c: Vector3 = C[0]
		_occ.append_array(PackedFloat32Array([c.x, c.y, c.z, pow(rm * rm * polar, 1.0 / 3.0)]))
		return
	var step: int = maxi(1, ni / 6) if wrap else 2
	for i: int in range(0, ni, step):
		var c2: Vector3 = C[i]
		_occ.append_array(PackedFloat32Array([c2.x, c2.y, c2.z, float(rad[i]) * (1.0 if wrap else 0.92)]))


## How much of its light a point keeps under the lumps its normal looks at (1 = all of it).
static func _contact(p: Vector3, n: Vector3, k: float) -> float:
	var occ: float = 0.0
	var m: int = _occ.size()
	var i: int = 0
	while i < m:
		var d: Vector3 = Vector3(_occ[i] - p.x, _occ[i + 1] - p.y, _occ[i + 2] - p.z)
		var r2: float = _occ[i + 3] * _occ[i + 3]
		i += 4
		var l2: float = d.length_squared()
		if l2 > 6.25 * r2:
			continue
		var dn: float = n.dot(d)
		if dn <= 0.0:
			continue
		occ += minf(r2 / maxf(l2, 0.000001), 1.0) * dn / sqrt(maxf(l2, 0.000001))
	return 1.0 / (1.0 + k * occ)


static func _hash(x: int, y: int, z: int) -> float:
	var h: int = (x * 374761393 + y * 668265263 + z * 1440662683) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


## Smooth value noise, 0..1.
static func _vn(p: Vector3) -> float:
	var i: Vector3i = Vector3i(floori(p.x), floori(p.y), floori(p.z))
	var f: Vector3 = p - Vector3(i)
	f = f * f * (Vector3(3, 3, 3) - 2.0 * f)
	var a: float = lerpf(lerpf(_hash(i.x, i.y, i.z), _hash(i.x + 1, i.y, i.z), f.x), lerpf(_hash(i.x, i.y + 1, i.z), _hash(i.x + 1, i.y + 1, i.z), f.x), f.y)
	var b: float = lerpf(lerpf(_hash(i.x, i.y, i.z + 1), _hash(i.x + 1, i.y, i.z + 1), f.x), lerpf(_hash(i.x, i.y + 1, i.z + 1), _hash(i.x + 1, i.y + 1, i.z + 1), f.x), f.y)
	return lerpf(a, b, f.z)


static func _se(c: float, pw: float) -> float:
	return signf(c) * pow(absf(c), 2.0 / pw)


static func _quad(mk: TLMesh, p: Array, n: Array, c: Array, key: String) -> void:
	var p1: Vector3 = p[1]; var p3: Vector3 = p[3]
	var n1: Vector3 = n[1]; var n3: Vector3 = n[3]
	var c1: Color = c[1]; var c3: Color = c[3]
	var g: Vector3 = (p1 - p[0]).cross(p[2] - p[0])
	if g.length_squared() < 1e-14:
		g = (p[2] - p[0]).cross(p3 - p[0])
	if g.dot(n[0] + n1 + n[2] + n3) < 0.0:
		var tp: Vector3 = p1; p1 = p3; p3 = tp
		var tn: Vector3 = n1; n1 = n3; n3 = tn
		var tc: Color = c1; c1 = c3; c3 = tc
	if (p1 - p[0]).cross(p[2] - p[0]).length_squared() > 1e-14:
		mk.tri_n(p[0], p1, p[2], n[0], n1, n[2], key, c[0], c1, c[2])
	if (p[2] - p[0]).cross(p3 - p[0]).length_squared() > 1e-14:
		mk.tri_n(p[0], p[2], p3, n[0], n[2], n3, key, c[0], c[2], c3)


## Emits a grid of points as one smooth clay form. P[i][j]: ring i, point j (rings always close around j).
## C[i] = the centre of ring i (which way is out). pole0 / pole1: a point that closes the first / last ring (or null).
## o: key, col, lump (m), lumpf (1/m), seed, groove (m), groovef, ao0, ao1, aow, chip, chip0, chip1, chipw, floor (y), dark (y),
##    keyfn (Callable(Vector3) -> String), wrap (rings close along i too: a rolled ring)
static func _emit(mk: TLMesh, P: Array, C: Array, pole0: Variant, pole1: Variant, o: Dictionary) -> void:
	var ni: int = P.size()
	var nj: int = (P[0] as Array).size()
	var wrap: bool = bool(o.get("wrap", false))
	var lump: float = float(o.get("lump", 0.004))
	var lf: float = float(o.get("lumpf", 9.0))
	var seed_v: Vector3 = Vector3(1.7, 9.2, 4.1) * float(o.get("seed", 1.0))
	var groove: float = float(o.get("groove", 0.0))
	var gf: float = float(o.get("groovef", 60.0))
	var has_floor: bool = o.has("floor")
	var floor_y: float = float(o.get("floor", 0.0))
	if _collect:
		_note(P, C, pole1, wrap)
		return
	# displace: lumps along the way out, tool grooves, then the floor (a sole stands flat)
	for i: int in ni:
		for j: int in nj:
			var p: Vector3 = P[i][j]
			var out: Vector3 = (p - (C[i] as Vector3)).normalized()
			var d: float = (_vn(p * lf + seed_v) - 0.5) * 2.0 * lump + (_vn(p * lf * 2.3 + seed_v * 1.9) - 0.5) * lump * 0.7
			if groove > 0.0:
				var w: float = _vn(p * 7.0 + seed_v) * 2.4
				d -= groove * pow(absf(sin((p.x * 0.9 + p.y * 0.35 + p.z * 0.6) * gf + w * 3.0)), 6.0)
			p += out * d
			if has_floor and p.y < floor_y:
				p.y = floor_y
			P[i][j] = p
	if has_floor:
		if pole0 is Vector3 and (pole0 as Vector3).y < floor_y:
			pole0 = Vector3((pole0 as Vector3).x, floor_y, (pole0 as Vector3).z)
		if pole1 is Vector3 and (pole1 as Vector3).y < floor_y:
			pole1 = Vector3((pole1 as Vector3).x, floor_y, (pole1 as Vector3).z)
	# normals from the displaced surface
	var N: Array = []
	for i: int in ni:
		var row: Array = []
		for j: int in nj:
			var jp: int = (j + 1) % nj
			var jm: int = (j + nj - 1) % nj
			var a: Vector3
			var b: Vector3
			if wrap:
				a = P[(i + ni - 1) % ni][j]
				b = P[(i + 1) % ni][j]
			else:
				a = P[i - 1][j] if i > 0 else (pole0 if pole0 is Vector3 else P[i][j])
				b = P[i + 1][j] if i < ni - 1 else (pole1 if pole1 is Vector3 else P[i][j])
			var nn: Vector3 = ((P[i][jp] as Vector3) - (P[i][jm] as Vector3)).cross((b as Vector3) - (a as Vector3))
			var out2: Vector3 = (P[i][j] as Vector3) - (C[i] as Vector3)
			if nn.length_squared() < 1e-16:
				nn = out2
			nn = nn.normalized()
			if nn.dot(out2) < 0.0:
				nn = -nn
			if has_floor and (P[i][j] as Vector3).y <= floor_y + 0.0005:
				nn = (nn + Vector3(0, -1.6, 0)).normalized()
			row.append(nn)
		N.append(row)
	# tone and chip mask
	var col: Color = o.get("col", Color.WHITE)
	var ao0: float = float(o.get("ao0", 0.0))
	var ao1: float = float(o.get("ao1", 0.0))
	var aow: float = float(o.get("aow", 0.3))
	var chip: float = float(o.get("chip", 0.0))
	var chip0: float = float(o.get("chip0", 0.0))
	var chip1: float = float(o.get("chip1", 0.0))
	var chipw: float = float(o.get("chipw", 0.25))
	var dark_on: bool = o.has("dark")
	var dark_y: float = float(o.get("dark", 0.0))
	var K: Array = []
	for i: int in ni:
		var u: float = float(i) / float(maxi(ni - 1, 1))
		var sh: float = 1.0 - ao0 * (1.0 - smoothstep(0.0, aow, u)) - ao1 * smoothstep(1.0 - aow, 1.0, u)
		var al: float = clampf(1.0 - chip - chip0 * (1.0 - smoothstep(0.0, chipw, u)) - chip1 * smoothstep(1.0 - chipw, 1.0, u), 0.0, 1.0)
		var row: Array = []
		for j: int in nj:
			var s2: float = sh
			if _ao_bake:
				_ao.append(_contact(P[i][j], N[i][j], _contact_k))
			if _ao_i < _ao.size():
				s2 *= _ao[_ao_i]
			_ao_i += 1
			if dark_on and (P[i][j] as Vector3).y < dark_y:
				s2 *= 0.55
			row.append(Color(col.r * s2, col.g * s2, col.b * s2, al))
		K.append(row)
	var key: String = String(o.get("key", "white"))
	var keyfn: Callable = o.get("keyfn", Callable())
	var last: int = ni if wrap else ni - 1
	for i: int in last:
		var i2: int = (i + 1) % ni
		for j: int in nj:
			var j2: int = (j + 1) % nj
			var k: String = key
			if keyfn.is_valid():
				k = String(keyfn.call(((P[i][j] as Vector3) + (P[i2][j2] as Vector3)) * 0.5))
			_quad(mk, [P[i][j], P[i][j2], P[i2][j2], P[i2][j]], [N[i][j], N[i][j2], N[i2][j2], N[i2][j]], [K[i][j], K[i][j2], K[i2][j2], K[i2][j]], k)
	for e: Array in [[pole0, 0, -1.0], [pole1, ni - 1, 1.0]]:
		if not (e[0] is Vector3) or wrap:
			continue
		var pp: Vector3 = e[0]
		var ri: int = e[1]
		var pn: Vector3 = (pp - (C[ri] as Vector3))
		pn = pn.normalized() if pn.length_squared() > 1e-10 else Vector3(0, float(e[2]), 0)
		if has_floor and pp.y <= floor_y + 0.0005:
			pn = Vector3.DOWN
		var pc: Color = K[ri][0]
		for j: int in nj:
			var j2: int = (j + 1) % nj
			var a3: Vector3 = P[ri][j]
			var b3: Vector3 = P[ri][j2]
			var g: Vector3 = (b3 - a3).cross(pp - a3)
			if g.length_squared() < 1e-14:
				continue
			var k2: String = key
			if keyfn.is_valid():
				k2 = String(keyfn.call((a3 + b3 + pp) / 3.0))
			if g.dot(pn) >= 0.0:
				mk.tri_n(a3, b3, pp, N[ri][j], N[ri][j2], pn, k2, K[ri][j], K[ri][j2], pc)
			else:
				mk.tri_n(b3, a3, pp, N[ri][j2], N[ri][j], pn, k2, K[ri][j2], K[ri][j], pc)


## A ball-like lump: `fn(unit direction) -> point`. m points round, n rings from the bottom pole to the top.
static func ball_fn(mk: TLMesh, fn: Callable, m: int, n: int, o: Dictionary) -> void:
	var P: Array = []
	var C: Array = []
	var cen: Vector3 = ((fn.call(Vector3.UP) as Vector3) + (fn.call(Vector3.DOWN) as Vector3)) * 0.5
	for i: int in range(1, n):
		var la: float = -PI * 0.5 + PI * float(i) / float(n)
		var row: Array = []
		for j: int in m:
			var a: float = TAU * float(j) / float(m)
			row.append(fn.call(Vector3(cos(la) * cos(a), sin(la), cos(la) * sin(a))))
		P.append(row)
		C.append(cen)
	_emit(mk, P, C, fn.call(Vector3.DOWN), fn.call(Vector3.UP), o)


## An ellipsoid lump at c with radii r, turned by `euler_deg`.
static func ball(mk: TLMesh, c: Vector3, r: Vector3, o: Dictionary, m: int = 12, n: int = 7, euler_deg: Vector3 = Vector3.ZERO) -> void:
	var b: Basis = Basis.from_euler(Vector3(deg_to_rad(euler_deg.x), deg_to_rad(euler_deg.y), deg_to_rad(euler_deg.z)))
	ball_fn(mk, func(d: Vector3) -> Vector3: return c + b * Vector3(r.x * d.x, r.y * d.y, r.z * d.z), m, n, o)


## A loft through rounded sections [centre, rx, rz] (rings level, in XZ), closed by a small dome at each end.
## pw = the section's roundness (2 = an ellipse, 3 = a soft box). n rings are laid through the sections (Catmull-Rom).
static func loft(mk: TLMesh, secs: Array, m: int, n: int, o: Dictionary) -> void:
	var pw: float = float(o.get("pw", 2.0))
	var ns: int = secs.size()
	var P: Array = []
	var C: Array = []
	var R: Array = []
	for i: int in n:
		var t: float = float(i) / float(n - 1) * float(ns - 1)
		var k: int = mini(int(t), ns - 2)
		var f: float = t - float(k)
		var s0: Array = secs[maxi(k - 1, 0)]
		var s1: Array = secs[k]
		var s2: Array = secs[k + 1]
		var s3: Array = secs[mini(k + 2, ns - 1)]
		var c: Vector3 = (s1[0] as Vector3).cubic_interpolate(s2[0], s0[0], s3[0], f)
		var rx: float = maxf(0.004, cubic_interpolate(float(s1[1]), float(s2[1]), float(s0[1]), float(s3[1]), f))
		var rz: float = maxf(0.004, cubic_interpolate(float(s1[2]), float(s2[2]), float(s0[2]), float(s3[2]), f))
		var row: Array = []
		for j: int in m:
			var a: float = TAU * float(j) / float(m)
			row.append(c + Vector3(rx * _se(cos(a), pw), 0.0, rz * _se(sin(a), pw)))
		P.append(row)
		C.append(c)
		R.append(minf(rx, rz))
	var d0: Vector3 = ((C[0] as Vector3) - (C[1] as Vector3)).normalized()
	var d1: Vector3 = ((C[n - 1] as Vector3) - (C[n - 2] as Vector3)).normalized()
	var dome: float = float(o.get("dome", 0.45))
	_emit(mk, P, C, (C[0] as Vector3) + d0 * float(R[0]) * dome, (C[n - 1] as Vector3) + d1 * float(R[n - 1]) * dome, o)


## A rolled ring (collar, cuff): centre c, turned by euler_deg; the roll's centre line is an ellipse (rx, rz), the roll
## itself is `rr` thick outwards and `ry` thick up and down.
static func ring(mk: TLMesh, c: Vector3, rx: float, rz: float, rr: float, ry: float, o: Dictionary, m: int = 14, n: int = 6, euler_deg: Vector3 = Vector3.ZERO) -> void:
	var b: Basis = Basis.from_euler(Vector3(deg_to_rad(euler_deg.x), deg_to_rad(euler_deg.y), deg_to_rad(euler_deg.z)))
	var P: Array = []
	var C: Array = []
	for i: int in m:
		var a: float = TAU * float(i) / float(m)
		var row: Array = []
		for j: int in n:
			var t: float = TAU * float(j) / float(n)
			row.append(c + b * Vector3((rx + rr * cos(t)) * cos(a), ry * sin(t), (rz + rr * cos(t)) * sin(a)))
		P.append(row)
		C.append(c + b * Vector3(rx * cos(a), 0.0, rz * sin(a)))
	var o2: Dictionary = o.duplicate()
	o2["wrap"] = true
	_emit(mk, P, C, null, null, o2)
