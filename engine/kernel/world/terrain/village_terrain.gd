extends RefCounted
## P4. The world's ground has height. One heightfield for the village (a few hundred metres across), built once:
## rolling land, a ring of hills, a bluff with a cliff face behind the northern venues, a low valley with a river,
## a flat pad under every plot (a bank all round it, steep where the pad is cut into the land or filled up), and
## roads that follow the land.
##
##   var t = VillageTerrain.new(seed, Rect2(x0, z0, w, d), cell_m)
##   t.pads / t.roads / t.river / t.ponds are filled by the caller (landscape.gd), then
##   t.build_grid()           the heights (stamps for roads and river: no per-vertex path queries)
##   t.build_mesh(material)   one MeshInstance3D, indexed, smooth normals, vertex colours from slope / height / noise
##   t.gy(x, z)               the drawn ground height at (x, z), consistent with the mesh triangles
##
## Visual by itself. The visitor's collider (terrain faces) is `collision_faces()`; nothing here ticks.
## Colour and strata are the style's: the palette key "terrain" (class ground: tufts, strata on steep faces).

const GROUND_Y: float = 0.0

var x0: float = 0.0
var z0: float = 0.0
var cell: float = 3.0
var nx: int = 0                      # cells in x
var nz: int = 0
var heights: PackedFloat32Array = PackedFloat32Array()
var centre: Vector2 = Vector2(5.0, -20.0)
var pads: Array = []                 # {c: Vector2, r: float (flat radius), h: float, own: bool}
var roads: Array = []                # {pts: PackedVector2Array, ys: PackedFloat32Array, half: float}
var river: Dictionary = {}           # {pts, ys (water level), half}
var ponds: Array = []                # {c: Vector2, r: float, y: float}
var road_d: PackedFloat32Array = PackedFloat32Array()      # per grid vertex: distance to the nearest road sample
var river_d: PackedFloat32Array = PackedFloat32Array()
var build_ms: int = 0
var _nl: FastNoiseLite = FastNoiseLite.new()
var _nm: FastNoiseLite = FastNoiseLite.new()
var _nh: FastNoiseLite = FastNoiseLite.new()
var _nr: FastNoiseLite = FastNoiseLite.new()
var _np: FastNoiseLite = FastNoiseLite.new()
var _nd: FastNoiseLite = FastNoiseLite.new()
var _c: Dictionary = {}


func _init(seed_: int, box: Rect2, cell_m: float = 3.0) -> void:
	x0 = box.position.x
	z0 = box.position.y
	cell = cell_m
	nx = int(round(box.size.x / cell))
	nz = int(round(box.size.y / cell))
	_nl.seed = seed_
	_nl.frequency = 0.0075
	_nl.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_nm.seed = seed_ + 1
	_nm.frequency = 0.026
	_nm.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_nh.seed = seed_ + 2
	_nh.frequency = 0.09
	_nh.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_nr.seed = seed_ + 3
	_nr.frequency = 0.006
	_nr.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_np.seed = seed_ + 4
	_np.frequency = 0.017
	_np.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_nd.seed = seed_ + 5
	_nd.frequency = 0.05
	_nd.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	for k: String in ["grass", "grass_dry", "grass_dark", "dirt", "sand", "rock", "rock_dark", "rock_warm", "cliff"]:
		_c[k] = TLStyle.color(k)


func x1() -> float:
	return x0 + float(nx) * cell


func z1() -> float:
	return z0 + float(nz) * cell


## The land before any pad, road or river: rolling ground, the ring of hills, the bluff behind the northern venues.
func base_h(x: float, z: float) -> float:
	var h: float = 4.2 * _nl.get_noise_2d(x, z) + 1.2 * _nm.get_noise_2d(x, z) + 0.12 * _nh.get_noise_2d(x, z)
	var e: Vector2 = Vector2((x - centre.x) / 300.0, (z - centre.y) / 200.0)
	var rid: float = 0.55 + 0.45 * (_nr.get_noise_2d(x, z) * 0.5 + 0.5)
	h += 24.0 * smoothstep(0.80, 1.28, e.length()) * rid
	var zc: float = -205.0 + 16.0 * _nl.get_noise_2d(x * 0.45, 40.0)
	var ledge: float = smoothstep(-3.0, 3.0, zc - z) * smoothstep(-300.0, -255.0, z) * smoothstep(-205.0, -120.0, x) * (1.0 - smoothstep(170.0, 260.0, x))
	h += 9.5 * ledge
	var m: float = smoothstep(0.0, 60.0, minf(minf(x - x0, x1() - x), minf(z - z0, z1() - z)))
	return h * m


func _v(i: int, j: int) -> int:
	return clampi(j, 0, nz) * (nx + 1) + clampi(i, 0, nx)


## Builds the heights. Roads and river are stamped (every sample marks the vertices around it).
func build_grid() -> void:
	var t0: int = Time.get_ticks_msec()
	var w: int = nx + 1
	var count: int = w * (nz + 1)
	heights.resize(count)
	road_d.resize(count)
	river_d.resize(count)
	road_d.fill(1e9)
	river_d.fill(1e9)
	var road_y: PackedFloat32Array = PackedFloat32Array()
	road_y.resize(count)
	var river_y: PackedFloat32Array = PackedFloat32Array()
	river_y.resize(count)
	# 1. the land and the pads
	for j: int in nz + 1:
		var z: float = z0 + float(j) * cell
		for i: int in w:
			var x: float = x0 + float(i) * cell
			var h: float = base_h(x, z)
			for pd: Dictionary in pads:
				var c: Vector2 = pd["c"]
				var dx: float = x - c.x
				var dz: float = z - c.y
				var r: float = float(pd["r"])
				var lim: float = r + 24.0
				if absf(dx) > lim or absf(dz) > lim:
					continue
				var d: float = sqrt(dx * dx + dz * dz)
				if d <= r:
					h = float(pd["h"])
				elif d < lim:
					var ph: float = float(pd["h"])
					var bw: float = clampf(absf(ph - h) * (0.7 if ph < h else 1.1), 3.5, 22.0)
					if d < r + bw:
						h = lerpf(ph, h, smoothstep(0.0, 1.0, (d - r) / bw))
			heights[j * w + i] = h
	# 2. stamps
	for rd: Dictionary in roads:
		_stamp(rd["pts"], rd["ys"], float(rd["half"]) + 10.0, road_d, road_y)
	if not river.is_empty():
		_stamp(river["pts"], river["ys"], 40.0, river_d, river_y)
	# 3. roads grade the land along them, then the river digs its valley and channel
	var rhalf: float = 3.0
	if not roads.is_empty():
		rhalf = float((roads[0] as Dictionary)["half"])
	var rv_half: float = float(river.get("half", 6.0))
	for k: int in count:
		var h: float = heights[k]
		var d: float = road_d[k]
		if d < 1e8:
			var ph: float = road_y[k]
			h = lerpf(h, ph - 0.02, 1.0 - smoothstep(rhalf + 1.6, rhalf + 9.0, d))
		var dr: float = river_d[k]
		if dr < 1e8:
			var lvl: float = river_y[k]
			var wv: float = 1.0 - smoothstep(5.0, 36.0, dr)
			h = minf(h, lerpf(h, lvl + 0.6, wv))
			h = lerpf(h, lvl - 1.0, 1.0 - smoothstep(rv_half * 0.55, rv_half + 5.0, dr))
		heights[k] = h
	for pn: Dictionary in ponds:
		var c: Vector2 = pn["c"]
		var pr: float = float(pn["r"])
		for j: int in nz + 1:
			var z: float = z0 + float(j) * cell
			if absf(z - c.y) > pr + 14.0:
				continue
			for i: int in w:
				var x: float = x0 + float(i) * cell
				var d2: float = Vector2(x, z).distance_to(c)
				if d2 < pr + 14.0:
					var k2: int = j * w + i
					heights[k2] = lerpf(heights[k2], float(pn["y"]) - 1.2, 1.0 - smoothstep(pr * 0.7, pr + 7.0, d2))
	build_ms = Time.get_ticks_msec() - t0


func _stamp(pts: PackedVector2Array, ys: PackedFloat32Array, reach: float, dist: PackedFloat32Array, yy: PackedFloat32Array) -> void:
	var w: int = nx + 1
	var rc: int = int(ceil(reach / cell))
	for s: int in pts.size():
		var p: Vector2 = pts[s]
		var ci: int = int(round((p.x - x0) / cell))
		var cj: int = int(round((p.y - z0) / cell))
		for j: int in range(maxi(cj - rc, 0), mini(cj + rc, nz) + 1):
			var z: float = z0 + float(j) * cell
			for i: int in range(maxi(ci - rc, 0), mini(ci + rc, nx) + 1):
				var dx: float = x0 + float(i) * cell - p.x
				var dz: float = z - p.y
				var d: float = sqrt(dx * dx + dz * dz)
				var k: int = j * w + i
				if d < dist[k]:
					dist[k] = d
					yy[k] = ys[s]


## The height at (x, z), consistent with the mesh triangles (the same diagonal rule as the kit's terrain).
func h(x: float, z: float) -> float:
	var fx: float = clampf((x - x0) / cell, 0.0, float(nx) - 0.0001)
	var fz: float = clampf((z - z0) / cell, 0.0, float(nz) - 0.0001)
	var i: int = int(fx)
	var j: int = int(fz)
	var u: float = fx - float(i)
	var v: float = fz - float(j)
	var a: float = heights[_v(i, j)]
	var b: float = heights[_v(i + 1, j)]
	var c: float = heights[_v(i + 1, j + 1)]
	var d: float = heights[_v(i, j + 1)]
	if (i + j) % 2 == 0:
		if u >= v:
			return a + (b - a) * u + (c - b) * v
		return a + (c - d) * u + (d - a) * v
	if u + v <= 1.0:
		return a + (b - a) * u + (d - a) * v
	return c + (d - c) * (1.0 - u) + (b - c) * (1.0 - v)


## The drawn ground (the mesh is the heightfield itself: a pack's ground and the world's ground meet at the same height).
func gy(x: float, z: float) -> float:
	return h(x, z) + GROUND_Y


## Slope as 1 - normal.y (0 flat, 0.29 at 45 degrees, 0.5 at 60).
func slope(x: float, z: float) -> float:
	var e: float = cell * 0.5
	var dx: float = h(x + e, z) - h(x - e, z)
	var dz: float = h(x, z + e) - h(x, z - e)
	return 1.0 - 2.0 * e / sqrt(dx * dx + dz * dz + 4.0 * e * e)


func inside(x: float, z: float, margin: float = 0.0) -> bool:
	return x >= x0 + margin and x <= x1() - margin and z >= z0 + margin and z <= z1() - margin


func river_dist(x: float, z: float) -> float:
	if not inside(x, z):
		return 1e9
	return river_d[_v(int(round((x - x0) / cell)), int(round((z - z0) / cell)))]


func road_dist(x: float, z: float) -> float:
	if not inside(x, z):
		return 1e9
	return road_d[_v(int(round((x - x0) / cell)), int(round((z - z0) / cell)))]


# ------------------------------------------------------------------------------------------------ colour and mesh
func _col(x: float, y: float, z: float, n: Vector3, rd: float, rvd: float) -> Color:
	var slope_: float = 1.0 - n.y
	var np: float = _np.get_noise_2d(x, z) * 0.5 + 0.5
	var base: Color = (_c["grass_dark"] as Color).lerp(_c["grass"], 0.5 + 0.5 * smoothstep(0.2, 0.8, np))
	var dry: float = smoothstep(0.55, 0.85, _nd.get_noise_2d(x * 0.4, z * 0.4) * 0.5 + 0.5) * 0.3 + smoothstep(-4.0, 6.0, y) * 0.12
	base = base.lerp(_c["grass_dry"], clampf(dry, 0.0, 0.85))
	base = base.lerp(_c["rock_warm"], smoothstep(14.0, 34.0, y) * 0.55)
	var rk: float = smoothstep(0.17, 0.34, slope_)
	var rock: Color = (_c["rock"] as Color).lerp(_c["cliff"], smoothstep(0.3, 0.7, np)).lerp(_c["rock_warm"], smoothstep(0.55, 0.85, _nd.get_noise_2d(x, z + 5.0) * 0.5 + 0.5) * 0.6)
	base = base.lerp(rock, rk)
	if rd < 30.0:
		base = base.lerp((_c["grass_dark"] as Color).lerp(_c["dirt"], 0.35), (1.0 - smoothstep(3.5, 12.0, rd)) * 0.5 * (1.0 - rk))
	if rvd < 40.0:
		base = base.lerp(_c["sand"], (1.0 - smoothstep(float(river.get("half", 6.0)) * 0.6, float(river.get("half", 6.0)) + 7.0, rvd)) * 0.7 * (1.0 - rk * 0.6))
	return base.srgb_to_linear()


func build_mesh(mat: Material, name_: String = "WorldTerrain") -> MeshInstance3D:
	var t0: int = Time.get_ticks_msec()
	var w: int = nx + 1
	var count: int = w * (nz + 1)
	var vs: PackedVector3Array = PackedVector3Array()
	var ns: PackedVector3Array = PackedVector3Array()
	var cs: PackedColorArray = PackedColorArray()
	var uv: PackedVector2Array = PackedVector2Array()
	var cu: PackedFloat32Array = PackedFloat32Array()
	vs.resize(count)
	ns.resize(count)
	cs.resize(count)
	uv.resize(count)
	cu.resize(count * 4)
	var code: float = 1.0 + 16.0 * float(TLStyle.index("terrain"))
	for j: int in nz + 1:
		var z: float = z0 + float(j) * cell
		for i: int in w:
			var k: int = j * w + i
			var x: float = x0 + float(i) * cell
			var y: float = heights[k] + GROUND_Y
			var nrm: Vector3 = Vector3(heights[_v(i - 1, j)] - heights[_v(i + 1, j)], 2.0 * cell, heights[_v(i, j - 1)] - heights[_v(i, j + 1)]).normalized()
			vs[k] = Vector3(x, y, z)
			ns[k] = nrm
			cs[k] = _col(x, y, z, nrm, road_d[k], river_d[k])
			cu[k * 4] = x
			cu[k * 4 + 1] = y
			cu[k * 4 + 2] = z
			cu[k * 4 + 3] = code
	var ix: PackedInt32Array = PackedInt32Array()
	ix.resize(nx * nz * 6)
	var q: int = 0
	for j: int in nz:
		for i: int in nx:
			var a: int = j * w + i
			var b: int = a + 1
			var d: int = a + w
			var c: int = d + 1
			# the faces look up (+y): Godot winds front faces clockwise seen from outside
			if (i + j) % 2 == 0:
				ix[q] = a; ix[q + 1] = b; ix[q + 2] = c
				ix[q + 3] = a; ix[q + 4] = c; ix[q + 5] = d
			else:
				ix[q] = a; ix[q + 1] = b; ix[q + 2] = d
				ix[q + 3] = b; ix[q + 4] = c; ix[q + 5] = d
			q += 6
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	arr[Mesh.ARRAY_COLOR] = cs
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_CUSTOM0] = cu
	arr[Mesh.ARRAY_INDEX] = ix
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	mesh.surface_set_material(0, mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	build_ms += Time.get_ticks_msec() - t0
	return mi


## Triangles of the heightfield for the visitor's collider (world coordinates, GROUND_Y included). `skip` is a Callable
## (centre x, centre z) -> bool: true leaves the triangle out (a plot whose own ground carries the visitor there).
func collision_faces(skip: Callable) -> PackedVector3Array:
	var faces: PackedVector3Array = PackedVector3Array()
	for j: int in nz:
		for i: int in nx:
			var xa: float = x0 + float(i) * cell
			var za: float = z0 + float(j) * cell
			var a: Vector3 = Vector3(xa, heights[_v(i, j)] + GROUND_Y, za)
			var b: Vector3 = Vector3(xa + cell, heights[_v(i + 1, j)] + GROUND_Y, za)
			var c: Vector3 = Vector3(xa + cell, heights[_v(i + 1, j + 1)] + GROUND_Y, za + cell)
			var d: Vector3 = Vector3(xa, heights[_v(i, j + 1)] + GROUND_Y, za + cell)
			var tris: Array = [[a, b, c], [a, c, d]] if (i + j) % 2 == 0 else [[a, b, d], [b, c, d]]
			for t: Array in tris:
				var cx: float = ((t[0] as Vector3).x + (t[1] as Vector3).x + (t[2] as Vector3).x) / 3.0
				var cz: float = ((t[0] as Vector3).z + (t[1] as Vector3).z + (t[2] as Vector3).z) / 3.0
				if bool(skip.call(cx, cz)):
					continue
				faces.append(t[0])
				faces.append(t[2])
				faces.append(t[1])
	return faces
