extends RefCounted
## Diorama day (20 Nov 2026), nature. A kit tree, bush or rock is a recipe of a few facets: a pine tier is a cone of
## seven sides, a bush two icosahedra. Under a style that asks for it (`detail.nature` > 0, a windowed run) the village
## and the kit (a layout's forest, the parts tree, rock, bush) DRAW each recipe as the thing a hand would make of it:
##   a cone of a pine key      a felt skirt: puffed, its rim cut in lobes that hang, a rolled lip, a dark underside
##   a blob of a leaf key      a ball of felted wool: lumps and nodules, flat where it sits
##   a blob of a rock key      a lump of clay rolled in the hand, pressed flat here and there
## Everything else of the recipe (trunks, blades) is kept as it is. The recipe itself is untouched and stays the
## source of the crown hulls, the colliders and the kit hashes: this is presentation only, built once per recipe.
## The new faces carry smooth normals and, in UV2, the round thing's own normal (tl_mesh_bake.gd, a turned side), so
## the diorama shader wraps the felt and clay textures around them without a seam.

const PINE: PackedStringArray = ["pine", "pine_light"]
const LEAF: PackedStringArray = ["leaf", "leaf_light", "leaf_dark"]
const ROCK: PackedStringArray = ["rock", "rock_warm"]

static var _ico: Dictionary = {}     # detail -> [unit vertices, faces]


static func enabled() -> bool:
	return not TLStyle.headless() and TLStyle.num("detail", "nature", 0.0) > 0.0


## A pack's own forest (a layout's scatter: about a thousand pines a pack, most of them cut away by its plot in a
## world, all of them still run through the vertex shader) is drawn as felt only from `detail.nature` 2.
static func forests() -> bool:
	return enabled() and TLStyle.num("detail", "nature", 0.0) >= 2.0


## The look of the recipe `mk`, or null when the style does not ask for one. `seg` = faces around a pine tier
## (18 near, fewer for trees that only stand on the skyline); `detail` = subdivisions of a lump (3 near).
## `force`: also headless and under a style that does not ask (the selftest).
static func look(mk: TLMesh, mesh_name: String, seg: int = 18, detail: int = 3, force: bool = false) -> ArrayMesh:
	if not force and not enabled():
		return null
	var out: TLMesh = TLMesh.new(1)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(mesh_name)
	var made: int = 0
	for key: String in mk.surfs:
		var s: TLMesh.Surf = mk.surfs[key]
		var kind: int = 1 if PINE.has(key) else (2 if LEAF.has(key) else (3 if ROCK.has(key) else 0))
		if kind == 0:
			out.surfs[key] = s        # kept as it is (build() only reads it)
			continue
		var comps: Array = _components(s.v)
		var fine: int = detail if (kind == 3 or comps.size() <= 2) else maxi(detail - 1, 1)     # a crown of many balls: each a little coarser
		for comp: Array in comps:
			var pts: PackedVector3Array = PackedVector3Array()
			var col: Color = Color(0, 0, 0, 0)
			for i: int in comp:
				pts.append(s.v[i])
				col += s.c[i]
			col /= float(comp.size())
			col.a = 1.0
			if kind == 1:
				_skirt(out, key, pts, col, seg, rng)
			else:
				_lump(out, key, pts, col, fine, kind == 3, rng)
			made += 1
	if made == 0:
		return null
	var m: ArrayMesh = out.build(mesh_name)
	m.set_meta("tl_look_tris", out.tri_count)
	m.set_meta("tl_hash", mk.content_hash())      # the identity and the budget of a part are its recipe's
	m.set_meta("tl_tris", mk.tri_count)
	return m


## The connected triangle groups of a triangle soup (corners that share a position are one vertex): vertex indices.
static func _components(v: PackedVector3Array) -> Array:
	var uniq: Dictionary = {}
	var up: PackedInt32Array = PackedInt32Array()
	var vid: PackedInt32Array = PackedInt32Array()
	vid.resize(v.size())
	for i: int in v.size():
		if not uniq.has(v[i]):
			uniq[v[i]] = up.size()
			up.append(up.size())
		vid[i] = uniq[v[i]]
	for i: int in range(0, v.size() - 2, 3):
		for j: int in [1, 2]:
			var a: int = vid[i]
			var b: int = vid[i + j]
			while up[a] != a:
				a = up[a]
			while up[b] != b:
				b = up[b]
			if a != b:
				up[b] = a
	var groups: Dictionary = {}
	for i: int in v.size():
		var a: int = vid[i]
		while up[a] != a:
			a = up[a]
		if not groups.has(a):
			groups[a] = []
		(groups[a] as Array).append(i)        # a plain Array: a packed array inside a Dictionary is a copy when cast
	return groups.values()


## One triangle with its own normals and tones; UV2 says it is a turned side with these normals.
static func _tri(out: TLMesh, key: String, p: Array, n: Array, c: Array) -> void:
	var flip: bool = ((p[1] as Vector3) - (p[0] as Vector3)).cross((p[2] as Vector3) - (p[0] as Vector3)).dot((n[0] as Vector3) + (n[1] as Vector3) + (n[2] as Vector3)) < 0.0
	var o: Array = [0, 2, 1] if flip else [0, 1, 2]
	out.tri_n(p[o[0]], p[o[1]], p[o[2]], n[o[0]], n[o[1]], n[o[2]], key, c[o[0]], c[o[1]], c[o[2]])
	var s: TLMesh.Surf = out.surfs[key]
	if s.uv2.size() < s.v.size() - 3:
		s.uv2.resize(s.v.size() - 3)
	var nb: Basis = out.tf.basis.inverse().transposed()
	for i: int in [o[0], o[2], o[1]]:          # tri_n appends p0, p2, p1
		var nn: Vector3 = (nb * (n[i] as Vector3)).normalized()
		s.uv2.append(Vector2(0.5 + 0.45 * nn.x, 0.5 + 0.45 * nn.z))


## A grid of points (rings x seg, closed around) as smooth quads. `tone` = one multiplier per ring.
static func _grid(out: TLMesh, key: String, rings: Array, seg: int, col: Color, tone: PackedFloat32Array, apex: bool) -> void:
	var nr: int = rings.size()
	var raw: Array = []
	for j: int in nr:
		var row: PackedVector3Array = PackedVector3Array()
		for i: int in seg:
			var a: Vector3 = (rings[j] as PackedVector3Array)[(i + 1) % seg] - (rings[j] as PackedVector3Array)[(i + seg - 1) % seg]
			var b: Vector3 = (rings[mini(j + 1, nr - 1)] as PackedVector3Array)[i] - (rings[maxi(j - 1, 0)] as PackedVector3Array)[i]
			var n: Vector3 = b.cross(a)
			row.append(n.normalized() if n.length_squared() > 1e-12 else Vector3.UP)
		raw.append(row)
	# the grid's own winding may be either way round: outside is where the second ring's normal points away from the axis
	var mid: Vector3 = Vector3.ZERO
	for i: int in seg:
		mid += (rings[1] as PackedVector3Array)[i]
	mid /= float(seg)
	var probe: Vector3 = (rings[1] as PackedVector3Array)[0] - mid
	var sgn: float = -1.0 if (raw[1] as PackedVector3Array)[0].dot(Vector3(probe.x, 0.0, probe.z)) < 0.0 else 1.0
	var up: Vector3 = Vector3.ZERO           # the first ring of a tip is one point: the mean of the ring below, tipped up
	for i: int in seg:
		up += (raw[1] as PackedVector3Array)[i] * sgn
	up = (up.normalized() + Vector3.UP).normalized() if up.length_squared() > 1e-9 else Vector3.UP
	var nrm: Array = []
	for j: int in nr:
		var row: PackedVector3Array = PackedVector3Array()
		for i: int in seg:
			row.append(up if (apex and j == 0) else (raw[j] as PackedVector3Array)[i] * sgn)
		nrm.append(row)
	for j: int in nr - 1:
		var c0: Color = Color(col.r * tone[j], col.g * tone[j], col.b * tone[j])
		var c1: Color = Color(col.r * tone[j + 1], col.g * tone[j + 1], col.b * tone[j + 1])
		for i: int in seg:
			var k: int = (i + 1) % seg
			var p00: Vector3 = (rings[j] as PackedVector3Array)[i]
			var p01: Vector3 = (rings[j] as PackedVector3Array)[k]
			var p10: Vector3 = (rings[j + 1] as PackedVector3Array)[i]
			var p11: Vector3 = (rings[j + 1] as PackedVector3Array)[k]
			var n00: Vector3 = (nrm[j] as PackedVector3Array)[i]
			var n01: Vector3 = (nrm[j] as PackedVector3Array)[k]
			var n10: Vector3 = (nrm[j + 1] as PackedVector3Array)[i]
			var n11: Vector3 = (nrm[j + 1] as PackedVector3Array)[k]
			if not (apex and j == 0):
				_tri(out, key, [p00, p10, p01], [n00, n10, n01], [c0, c1, c0])
			_tri(out, key, [p01, p10, p11], [n01, n10, n11], [c0, c1, c1])


## A cone of the recipe (its points) as a felt skirt of the same tip, height and reach.
static func _skirt(out: TLMesh, key: String, pts: PackedVector3Array, col: Color, seg: int, rng: RandomNumberGenerator) -> void:
	var top: Vector3 = pts[0]
	var y0: float = INF
	for p: Vector3 in pts:
		if p.y > top.y:
			top = p
		y0 = minf(y0, p.y)
	var h: float = top.y - y0
	var reach: float = 0.0
	for p: Vector3 in pts:
		if p.y < y0 + 0.02 * h:
			reach = maxf(reach, Vector2(p.x - top.x, p.z - top.z).length())
	if h < 1e-4 or reach < 1e-4:
		return
	# the profile from the tip to the rim, round the lip and back in under the skirt: [reach, drop] as fractions
	var prof: Array = [[0.0, 0.0], [0.34, 0.20], [0.62, 0.45], [0.84, 0.72], [0.97, 0.93], [1.0, 1.03], [0.94, 1.10], [0.60, 1.0], [0.20, 0.82]]
	var tone: PackedFloat32Array = PackedFloat32Array([0.90, 0.94, 0.98, 1.03, 1.10, 1.12, 0.80, 0.50, 0.42])
	if seg < 12:
		prof = [[0.0, 0.0], [0.62, 0.45], [0.97, 0.93], [1.0, 1.06], [0.60, 1.0]]
		tone = PackedFloat32Array([0.90, 0.98, 1.10, 1.0, 0.46])
	var lobes: int = rng.randi_range(5, 6) if seg >= 12 else (3 if seg >= 10 else 2)     # four faces or more to a lobe: a wave, not a saw
	var ph: float = rng.randf() * TAU
	var ph2: float = rng.randf() * TAU
	var lean: Vector2 = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * reach * 0.05
	var rings: Array = []
	var rim: int = 0
	for j: int in prof.size():
		if float(prof[j][0]) >= float(prof[rim][0]):
			rim = j
	for j: int in prof.size():
		var f: float = prof[j][0]
		var g: float = prof[j][1]
		var k: float = f * f if (j <= rim or f >= 0.9) else 0.5       # under the skirt the lobes are half as deep
		var ring: PackedVector3Array = PackedVector3Array()
		for i: int in seg:
			var a: float = TAU * float(i) / float(seg)
			var w: float = sin(a * float(lobes) + ph)
			var w2: float = sin(a * float(lobes + 2) + ph2)
			var r: float = reach * f * (1.0 + k * (0.10 * w + 0.045 * w2))
			var y: float = top.y - h * g - h * 0.08 * k * (w * 0.8 + w2 * 0.4)
			ring.append(Vector3(top.x + lean.x * g + cos(a) * r, y, top.z + lean.y * g + sin(a) * r))
		rings.append(ring)
	_grid(out, key, rings, seg, col, tone, true)


static func _icosphere(detail: int) -> Array:
	if _ico.has(detail):
		return _ico[detail]
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
	_ico[detail] = [vs, fs]
	return _ico[detail]


## A blob of the recipe (its points) as a rolled lump of the same place and size: felted wool, or clay (`clay`).
static func _lump(out: TLMesh, key: String, pts: PackedVector3Array, col: Color, detail: int, clay: bool, rng: RandomNumberGenerator) -> void:
	var lo: Vector3 = pts[0]
	var hi: Vector3 = pts[0]
	for p: Vector3 in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var on_floor: int = 0
	for p: Vector3 in pts:
		if p.y < lo.y + 1e-4:
			on_floor += 1
	var r: Vector3 = (hi - lo) * 0.5 * 0.96
	var c: Vector3 = (hi + lo) * 0.5
	var flat: bool = on_floor >= 9             # the recipe cut its bottom flat: three or more triangles lie there
	if flat:
		r.y = (hi.y - lo.y) / 1.36
		c.y = lo.y + 0.36 * r.y
	if flat and not clay and minf(r.x, r.z) > 0.75:      # (the small second blob of a kit bush stays one ball beside the cluster)
		# a bush is not one lump: felt balls rolled one by one and pressed together, a ring of them and one or two on top
		var n: int = rng.randi_range(4, 5)
		var a0: float = rng.randf() * TAU
		var rr: float = minf(r.x, r.z)
		for i: int in n + 2:
			var top: bool = i >= n
			var a: float = a0 + TAU * float(i) / float(n) + rng.randf_range(-0.25, 0.25)
			var d: float = (0.50 if not top else 0.16 * float(i - n)) * rng.randf_range(0.85, 1.1)
			var br: float = rr * (rng.randf_range(0.46, 0.60) if not top else rng.randf_range(0.50, 0.62))
			var bc: Vector3 = Vector3(c.x + cos(a) * r.x * d, lo.y + (br * 0.55 if not top else r.y * 0.78 + br * 0.30), c.z + sin(a) * r.z * d)
			var tone: float = rng.randf_range(0.90, 1.10) * (1.06 if top else 1.0)
			_ball(out, key, bc, Vector3(br, br * rng.randf_range(0.82, 0.95), br), lo.y, hi.y, true, Color(col.r * tone, col.g * tone, col.b * tone), maxi(detail - 1, 1), false, rng, Vector3(c.x, lo.y, c.z), rr)
		return
	_ball(out, key, c, r, lo.y, hi.y, flat, col, detail, clay, rng, Vector3.ZERO, 0.0)


## One rolled ball about `c` with radii `r`: lumps, nodules, clay pressed flat here and there; cut at `floor_y` when
## `flat`. `core`, `core_r`: the middle of a cluster it belongs to (0 = none): it is darker where it faces the others.
static func _ball(out: TLMesh, key: String, c: Vector3, r: Vector3, floor_y: float, top_y: float, flat: bool, col: Color, detail: int, clay: bool, rng: RandomNumberGenerator, core: Vector3, core_r: float) -> void:
	var ico: Array = _icosphere(detail)
	var vs: Array = ico[0]
	var fs: Array = ico[1]
	var n1: FastNoiseLite = FastNoiseLite.new()
	n1.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n1.seed = rng.randi() & 0xffff
	n1.frequency = 0.55 if clay else 0.75
	var n2: FastNoiseLite = FastNoiseLite.new()
	n2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n2.seed = rng.randi() & 0xffff
	n2.frequency = 1.7 if clay else 2.1
	var a1: float = 0.17 if clay else 0.13
	var a2: float = 0.035 if clay else 0.075
	var press: Array = []                        # clay is pressed flat here and there
	if clay:
		for i: int in 4:
			press.append([Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.2, 1.0), rng.randf_range(-1.0, 1.0)).normalized(), rng.randf_range(0.80, 0.93)])
	var ps: PackedVector3Array = PackedVector3Array()
	for u: Vector3 in vs:
		var d: float = 1.0 + a1 * n1.get_noise_3dv(u * 2.0) + a2 * n2.get_noise_3dv(u * 2.0)
		var q: Vector3 = u * d
		for pr: Array in press:
			var over: float = q.dot(pr[0]) - float(pr[1])
			if over > 0.0:
				q -= (pr[0] as Vector3) * over * 0.85
		var p: Vector3 = c + Vector3(q.x * r.x, q.y * r.y, q.z * r.z)
		if flat and p.y < floor_y - 0.02:
			p.y = floor_y - 0.02
		ps.append(p)
	var ns: PackedVector3Array = PackedVector3Array()
	ns.resize(ps.size())
	for f: Array in fs:
		var fn: Vector3 = (ps[f[1]] - ps[f[0]]).cross(ps[f[2]] - ps[f[0]])
		for e: int in 3:
			ns[f[e]] += fn
	for i: int in ns.size():
		var outw: Vector3 = (ps[i] - c).normalized()
		var n: Vector3 = ns[i].normalized() if ns[i].length_squared() > 1e-16 else outw
		ns[i] = n if n.dot(outw) > 0.0 else -n
	for f: Array in fs:
		var cs: Array = []
		for e: int in 3:
			var up: float = clampf(((ps[f[e]].y - floor_y) / maxf(top_y - floor_y, 1e-4)), 0.0, 1.0)
			var k: float = 0.72 + 0.34 * smoothstep(0.0, 0.7, up)        # darker where it sits: it shades itself there
			if core_r > 0.0:
				var away: float = Vector2(ps[f[e]].x - core.x, ps[f[e]].z - core.z).length() / core_r
				k *= 0.66 + 0.34 * smoothstep(0.25, 0.85, away + 0.5 * up)      # ... and where it is pressed against the other balls
			cs.append(Color(col.r * k, col.g * k, col.b * k))
		_tri(out, key, [ps[f[0]], ps[f[1]], ps[f[2]]], [ns[f[0]], ns[f[1]], ns[f[2]]], cs)


## The roadside tufts (the kit's are blades that sway; nothing sways on a diorama): a clump of flock, two small balls.
static func tuft_look(mesh_name: String) -> ArrayMesh:
	if not enabled():
		return null
	var mk: TLMesh = TLMesh.new(77)
	mk.blob(Vector3(0.32, 0.15, 0.27), 1, 0.2, "leaf", Color(1.28, 1.04, 0.92), 0.0, Vector3(0, 0.04, 0), true)     # near the meadow's own dye: a clump of the same flock, not a dot on it
	return look(mk, mesh_name, 18, 1)


## A clump of flock or a grit stone as its own small mesh (a ball of twenty faces, smooth, flat where it sits): the
## meadow's tufts, the dark flock at a pine's foot, the grit of a road. `r` = its radii, `sink` = how far it sits
## in the ground. Null when the style does not ask for felt nature.
static func clump_mesh(mesh_name: String, key: String, col: Color, r: Vector3, sink: float, clay: bool, seed_: int) -> ArrayMesh:
	if not enabled():
		return null
	var out: TLMesh = TLMesh.new(1)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_
	_ball(out, key, Vector3(0.0, r.y * 0.36 - sink, 0.0), r, -sink, r.y * 1.36 - sink, true, col, 0, clay, rng, Vector3.ZERO, 0.0)
	return out.build(mesh_name)
