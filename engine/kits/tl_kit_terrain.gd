class_name TLKitTerrain
extends RefCounted
## Kit part: parametric faceted terrain. One height function (valley + ridge + flat pads + road corridor + river channel
## + far mountains) drives (a) a 4 m near mesh with vertex-coloured facets, (b) a coarse far mesh with the mountain
## backdrop, (c) height queries consistent with the near mesh, (d) collision patches. Everything is flat-shaded facets;
## colour comes from slope / height / noise / feature masks, mapped through palette keys.

const CELL: float = 4.0
const NX0: float = -224.0
const NZ0: float = -288.0
const NNX: int = 104   # cells in x -> 416 m (aligned to the 32 m far grid)
const NNZ: int = 104   # cells in z -> 416 m
const FAR_CELL: float = 32.0
const FAR_HALF: int = 80   # +-2560 m

## kit (tl.layout/1): lists instead of singletons
var roads: Array = []         # {path: TLKitPath, half_w: float}: each flattens its own corridor
var rivers: Array = []        # {path: TLKitPath, half_w: float}: each digs its own channel
var ridges: Array = []        # {a: Vector2, b: Vector2, fall: float, half_w: float, h: float, ramps: [{c, w, fall}]}
var base_y: float = -14.0     # valley floor height
var mesas: Array = []         # {c: Vector2, r: float, h: float}: flat-topped cliffs for the skyline
var pads: Array = []          # {c: Vector2, r: float, blend: float, h: float}
var heights: PackedFloat32Array = PackedFloat32Array()
var n_low: FastNoiseLite = FastNoiseLite.new()
var n_mid: FastNoiseLite = FastNoiseLite.new()
var n_hi: FastNoiseLite = FastNoiseLite.new()
var n_mnt: FastNoiseLite = FastNoiseLite.new()
var n_patch: FastNoiseLite = FastNoiseLite.new()
var n_forest: FastNoiseLite = FastNoiseLite.new()
var _c: Dictionary = {}


func _init(seed_: int = 7) -> void:
	n_low.seed = seed_; n_low.frequency = 0.0055; n_low.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_mid.seed = seed_ + 1; n_mid.frequency = 0.021; n_mid.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_hi.seed = seed_ + 2; n_hi.frequency = 0.08; n_hi.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_mnt.seed = seed_ + 3; n_mnt.frequency = 0.0011; n_mnt.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_mnt.fractal_type = FastNoiseLite.FRACTAL_RIDGED; n_mnt.fractal_octaves = 4
	n_patch.seed = seed_ + 4; n_patch.frequency = 0.017; n_patch.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_forest.seed = seed_ + 5; n_forest.frequency = 0.011; n_forest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	for k: String in ["grass", "grass_dry", "grass_dark", "dirt", "sand", "rock", "rock_dark", "rock_warm", "cliff", "pine", "leaf"]:
		_c[k] = TLStyle.color(k)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func raw_h(x: float, z: float) -> float:
	var p: Vector2 = Vector2(x, z)
	var h: float = base_y + n_low.get_noise_2d(x, z) * 3.2 + n_mid.get_noise_2d(x, z) * 0.9 + n_hi.get_noise_2d(x, z) * 0.18
	# ridges: raised walkable land (the first one is where the avatar stands in the lane-B layouts)
	for rg: Dictionary in ridges:
		var d: float = _seg_dist(p, rg["a"], rg["b"])
		var fall: float = float(rg["fall"])
		for rp: Dictionary in (rg["ramps"] as Array):
			fall = lerpf(fall, float(rp["fall"]), 1.0 - smoothstep(float(rp["w"]) * 0.5, float(rp["w"]), p.distance_to(rp["c"])))
		var r: float = 1.0 - smoothstep(float(rg["half_w"]), float(rg["half_w"]) + fall, d)
		var ridge_h: float = float(rg["h"]) + n_mid.get_noise_2d(x + 40.0, z) * 0.8 + n_hi.get_noise_2d(x, z + 9.0) * 0.25
		h = lerpf(h, ridge_h, r)
	# flat pads: construction yard, house terrace
	for pd: Dictionary in pads:
		var c: Vector2 = pd["c"]
		var w: float = 1.0 - smoothstep(float(pd["r"]), float(pd["r"]) + float(pd["blend"]), p.distance_to(c))
		h = lerpf(h, float(pd["h"]), w)
	# road corridors
	for rd: Dictionary in roads:
		var q: Vector3 = (rd["path"] as TLKitPath).query(x, z)
		var hw: float = rd["half_w"]
		if q.x < hw + 19.0:
			var w2: float = 1.0 - smoothstep(hw + 3.5, hw + 15.0, q.x)
			h = lerpf(h, q.y - 0.05, w2)
	# river channels
	for rv: Dictionary in rivers:
		var rq: Vector3 = (rv["path"] as TLKitPath).query(x, z, 3)
		var rw: float = rv["half_w"]
		if rq.x < rw + 24.5:
			var w3: float = 1.0 - smoothstep(rw, rw + 11.5, rq.x)
			h = lerpf(h, rq.y - 1.0, w3)
	# far mountains: mesas and peaks beyond ~250 m
	var rr: float = Vector2(x + 10.0, z + 60.0).length()
	var m: float = smoothstep(260.0, 900.0, rr)
	if m > 0.0:
		var mn: float = n_mnt.get_noise_2d(x, z) * 0.5 + 0.5
		var amp: float = 60.0 + 260.0 * smoothstep(500.0, 1700.0, rr)
		var mh: float = pow(mn, 1.4) * amp
		var terr: float = 22.0
		mh = lerpf(mh, floorf(mh / terr) * terr + terr * smoothstep(0.0, 1.0, fposmod(mh / terr, 1.0) * 1.6 - 0.3), 0.55)
		h += m * mh
	for ms: Dictionary in mesas:
		var dm: float = p.distance_to(ms["c"]) + n_mid.get_noise_2d(x * 0.6, z * 0.6) * float(ms.get("noise", 14.0))
		var top: float = base_y + float(ms["h"]) + n_low.get_noise_2d(x * 2.0, z * 2.0) * 5.0
		h = maxf(h, lerpf(h, top, 1.0 - smoothstep(float(ms["r"]), float(ms["r"]) + float(ms.get("blend", 20.0)), dm)))
	return h


func build_grid() -> void:
	heights.resize((NNX + 1) * (NNZ + 1))
	for j: int in NNZ + 1:
		for i: int in NNX + 1:
			heights[j * (NNX + 1) + i] = raw_h(NX0 + i * CELL, NZ0 + j * CELL)


func in_near(x: float, z: float) -> bool:
	return x >= NX0 and x <= NX0 + NNX * CELL and z >= NZ0 and z <= NZ0 + NNZ * CELL


func _gh(i: int, j: int) -> float:
	return heights[clampi(j, 0, NNZ) * (NNX + 1) + clampi(i, 0, NNX)]


## Height consistent with the near mesh triangles.
func h(x: float, z: float) -> float:
	if not in_near(x, z):
		return raw_h(x, z)
	var fx: float = (x - NX0) / CELL
	var fz: float = (z - NZ0) / CELL
	var i: int = clampi(floori(fx), 0, NNX - 1)
	var j: int = clampi(floori(fz), 0, NNZ - 1)
	var u: float = fx - i
	var v: float = fz - j
	var a: float = _gh(i, j)
	var b: float = _gh(i + 1, j)
	var c: float = _gh(i + 1, j + 1)
	var d: float = _gh(i, j + 1)
	if (i + j) % 2 == 0:
		# diagonal a-c: triangles (a,b,c) where u>=v and (a,c,d)
		if u >= v:
			return a + (b - a) * u + (c - b) * v
		return a + (c - d) * u + (d - a) * v
	# diagonal b-d: triangles (a,b,d) where u+v<=1 and (b,c,d)
	if u + v <= 1.0:
		return a + (b - a) * u + (d - a) * v
	return c + (d - c) * (1.0 - u) + (b - c) * (1.0 - v)


func normal_at(x: float, z: float) -> Vector3:
	var e: float = 1.0
	var dx: float = h(x + e, z) - h(x - e, z)
	var dz: float = h(x, z + e) - h(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


func _col(p: Vector3, n: Vector3, far: bool) -> Color:
	var slope: float = 1.0 - n.y
	var np: float = n_patch.get_noise_2d(p.x, p.z) * 0.5 + 0.5
	var nf: float = n_forest.get_noise_2d(p.x + 300.0, p.z) * 0.5 + 0.5
	var base: Color = (_c["grass_dark"] as Color).lerp(_c["grass"], smoothstep(0.25, 0.7, np))
	# sun-baked yellow on the high ridge and dry patches
	var dry: float = smoothstep(0.55, 0.85, n_hi.get_noise_2d(p.x * 0.4, p.z * 0.4) * 0.5 + 0.5) * 0.55 + smoothstep(-4.0, 0.0, p.y) * 0.3
	base = base.lerp(_c["grass_dry"], clampf(dry, 0.0, 0.9))
	if far or p.y > 20.0 or true:
		var hf: float = smoothstep(18.0, 120.0, p.y)
		base = base.lerp((_c["rock_dark"] as Color).lerp(_c["pine"], 0.45), smoothstep(0.35, 0.8, nf) * 0.0)
		base = base.lerp(_c["rock_warm"], hf * 0.8)
	# forest floor patches in the valley (read as dark pine canopy from far away)
	var forest: float = smoothstep(0.58, 0.72, nf) * (1.0 - smoothstep(-8.0, 6.0, p.y)) * (1.0 if far else 0.0) + smoothstep(0.62, 0.78, nf) * (0.35 if far else 0.0)
	base = base.lerp(_c["pine"], clampf(forest, 0.0, 0.85))
	# steep = rock
	var rk: float = smoothstep(0.16, 0.34, slope)
	var rock: Color = (_c["rock"] as Color).lerp(_c["cliff"], smoothstep(0.3, 0.7, np)).lerp(_c["rock_warm"], smoothstep(0.55, 0.85, n_hi.get_noise_2d(p.x, p.z) * 0.5 + 0.5) * 0.7)
	base = base.lerp(rock, rk)
	# dirt on pads and verges
	for pd: Dictionary in pads:
		var w: float = 1.0 - smoothstep(float(pd["r"]) * 0.8, float(pd["r"]) + float(pd["blend"]) * 0.7, Vector2(p.x, p.z).distance_to(pd["c"]))
		if pd.get("dirt", false):
			var dn: float = n_hi.get_noise_2d(p.x * 0.6, p.z * 0.6) * 0.5 + 0.5
			var dirt: Color = (_c["dirt"] as Color).lerp(_c["sand"], np * 0.6).lerp((_c["dirt"] as Color).darkened(0.18), smoothstep(0.55, 0.75, dn) * 0.8)
			base = base.lerp(dirt, w * 0.9)
	for rd: Dictionary in roads:
		var q: Vector3 = (rd["path"] as TLKitPath).query(p.x, p.z)
		var hw: float = rd["half_w"]
		if q.x < hw + 9.0:
			base = base.lerp((_c["grass_dark"] as Color).lerp(_c["dirt"], 0.35), (1.0 - smoothstep(hw + 1.0, hw + 9.0, q.x)) * 0.55)
	for rv: Dictionary in rivers:
		var rq: Vector3 = (rv["path"] as TLKitPath).query(p.x, p.z, 3)
		var rw: float = rv["half_w"]
		if rq.x < rw + 10.5:
			base = base.lerp(_c["sand"], (1.0 - smoothstep(rw - 0.5, rw + 6.5, rq.x)) * 0.75)
	return base.srgb_to_linear()


func _tri(mk: TLMesh, a: Vector3, b: Vector3, c: Vector3, far: bool) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.y < 0.0:
		var t: Vector3 = b
		b = c
		c = t
		n = -n
	n = n.normalized()
	var cen: Vector3 = (a + b + c) / 3.0
	var col: Color = _col(cen, n, far)
	# per-facet brightness wobble: painterly patchwork
	var k: float = 1.0 + (n_hi.get_noise_2d(cen.x * 3.1, cen.z * 3.1)) * 0.06
	col = Color(col.r * k, col.g * k, col.b * k)
	mk.tri(a, b, c, "terrain", col)


func build_near() -> MeshInstance3D:
	var mk: TLMesh = TLMesh.new(11)
	for j: int in NNZ:
		for i: int in NNX:
			var x0: float = NX0 + i * CELL
			var z0: float = NZ0 + j * CELL
			var a: Vector3 = Vector3(x0, _gh(i, j), z0)
			var b: Vector3 = Vector3(x0 + CELL, _gh(i + 1, j), z0)
			var c: Vector3 = Vector3(x0 + CELL, _gh(i + 1, j + 1), z0 + CELL)
			var d: Vector3 = Vector3(x0, _gh(i, j + 1), z0 + CELL)
			if (i + j) % 2 == 0:
				_tri(mk, a, b, c, false)
				_tri(mk, a, c, d, false)
			else:
				_tri(mk, a, b, d, false)
				_tri(mk, b, c, d, false)
	# skirts hide the seam to the far mesh
	var low: float = -40.0
	var dark: Color = Color(0.12, 0.12, 0.12)
	for i: int in NNX:
		var x0: float = NX0 + i * CELL
		var xe: float = NX0 + NNX * CELL
		var ze: float = NZ0 + NNZ * CELL
		mk.quad_up_any(Vector3(x0, _gh(i, 0), NZ0), Vector3(x0 + CELL, _gh(i + 1, 0), NZ0), Vector3(x0 + CELL, low, NZ0), Vector3(x0, low, NZ0), "terrain", dark)
		mk.quad_up_any(Vector3(x0, _gh(i, NNZ), ze), Vector3(x0 + CELL, _gh(i + 1, NNZ), ze), Vector3(x0 + CELL, low, ze), Vector3(x0, low, ze), "terrain", dark)
	for j: int in NNZ:
		var z0: float = NZ0 + j * CELL
		var xe2: float = NX0 + NNX * CELL
		mk.quad_up_any(Vector3(NX0, _gh(0, j), z0), Vector3(NX0, _gh(0, j + 1), z0 + CELL), Vector3(NX0, low, z0 + CELL), Vector3(NX0, low, z0), "terrain", dark)
		mk.quad_up_any(Vector3(xe2, _gh(NNX, j), z0), Vector3(xe2, _gh(NNX, j + 1), z0 + CELL), Vector3(xe2, low, z0 + CELL), Vector3(xe2, low, z0), "terrain", dark)
	var mi: MeshInstance3D = mk.instance("terrain_near")
	mi.name = "TerrainNear"
	(mi.mesh as ArrayMesh).resource_name = "terrain_near"
	return mi


func build_far() -> MeshInstance3D:
	var mk: TLMesh = TLMesh.new(12)
	var near_x1: float = NX0 + NNX * CELL
	var near_z1: float = NZ0 + NNZ * CELL
	var hs: Dictionary = {}
	for j: int in range(-FAR_HALF, FAR_HALF + 1):
		for i: int in range(-FAR_HALF, FAR_HALF + 1):
			hs[Vector2i(i, j)] = raw_h(i * FAR_CELL, j * FAR_CELL)
	for j: int in range(-FAR_HALF, FAR_HALF):
		for i: int in range(-FAR_HALF, FAR_HALF):
			var x0: float = i * FAR_CELL
			var z0: float = j * FAR_CELL
			if x0 + FAR_CELL > NX0 and x0 < near_x1 and z0 + FAR_CELL > NZ0 and z0 < near_z1:
				continue
			var a: Vector3 = Vector3(x0, hs[Vector2i(i, j)], z0)
			var b: Vector3 = Vector3(x0 + FAR_CELL, hs[Vector2i(i + 1, j)], z0)
			var c: Vector3 = Vector3(x0 + FAR_CELL, hs[Vector2i(i + 1, j + 1)], z0 + FAR_CELL)
			var d: Vector3 = Vector3(x0, hs[Vector2i(i, j + 1)], z0 + FAR_CELL)
			if (i + j) % 2 == 0:
				_tri(mk, a, b, c, true)
				_tri(mk, a, c, d, true)
			else:
				_tri(mk, a, b, d, true)
				_tri(mk, b, c, d, true)
	var mi: MeshInstance3D = mk.instance("terrain_far")
	mi.name = "TerrainFar"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Collision for a square patch of the near grid (chunks land on it).
func collision_patch(cx: float, cz: float, half: float) -> StaticBody3D:
	var faces: PackedVector3Array = PackedVector3Array()
	var i0: int = clampi(floori((cx - half - NX0) / CELL), 0, NNX - 1)
	var i1: int = clampi(ceili((cx + half - NX0) / CELL), 1, NNX)
	var j0: int = clampi(floori((cz - half - NZ0) / CELL), 0, NNZ - 1)
	var j1: int = clampi(ceili((cz + half - NZ0) / CELL), 1, NNZ)
	for j: int in range(j0, j1):
		for i: int in range(i0, i1):
			var x0: float = NX0 + i * CELL
			var z0: float = NZ0 + j * CELL
			var a: Vector3 = Vector3(x0, _gh(i, j), z0)
			var b: Vector3 = Vector3(x0 + CELL, _gh(i + 1, j), z0)
			var c: Vector3 = Vector3(x0 + CELL, _gh(i + 1, j + 1), z0 + CELL)
			var d: Vector3 = Vector3(x0, _gh(i, j + 1), z0 + CELL)
			var tris: Array = [[a, b, c], [a, c, d]] if (i + j) % 2 == 0 else [[a, b, d], [b, c, d]]
			for t: Array in tris:
				var nn: Vector3 = (t[1] - t[0]).cross(t[2] - t[0])
				if nn.y < 0.0:
					faces.append(t[0]); faces.append(t[1]); faces.append(t[2])
				else:
					faces.append(t[0]); faces.append(t[2]); faces.append(t[1])
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "TerrainCollision"
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "Shape"
	var sh: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	sh.set_faces(faces)
	cs.shape = sh
	body.add_child(cs)
	return body
