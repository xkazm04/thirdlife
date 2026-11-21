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
const MAX_GRADE: float = 66.0

var base_seed: int
var fixed_chunks := {}
var x0: float = 0.0
var z0: float = 0.0
var cell: float = 3.0
var nx: int = 0                      # cells in x
var nz: int = 0
var heights: PackedFloat32Array = PackedFloat32Array()
var centre: Vector2 = Vector2(5.0, -20.0)
var pads: Array = []                 # oriented footprint, clip radius, height and yard approach from landscape.gd
static var _village_shader: Shader
var rim_material: ShaderMaterial
var wear_map := PackedFloat32Array()
var meadow_map := PackedFloat32Array()
const SINK: float = 0.06              # walker-feel T: the pad under a plot without ground of its own lies this much lower
const SINK_BAND: float = 3.5          # ... over the plot's radius, rising to the pad's height in this band beyond it (the plot cut ends at r + 3)
var roads: Array = []                # {pts: PackedVector2Array, ys: PackedFloat32Array, half: float}
var river: Dictionary = {}           # {pts, ys (water level), half}
var ponds: Array = []                # {c: Vector2, r: float, y: float}
var road_d: PackedFloat32Array = PackedFloat32Array()      # per grid vertex: distance to the nearest road sample
var river_d: PackedFloat32Array = PackedFloat32Array()
var build_ms: int = 0
var skip_near: PackedVector3Array = PackedVector3Array()     # P13: (x, z, radius) of plots `collision_faces` may skip
var relief: float = 1.0              # P6: scale of the land's own height (0 = a flat study ground; pads, roads and river still stamp)
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
	base_seed = seed_
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
	return h * m * relief


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
	# 1. the land. P13: in bands of rows on workers (each band its own array, joined in order: the same
	# numbers as one loop); it was a third of the time to the first frame of a village of thirty games.
	var bands: int = clampi(OS.get_processor_count() - 1, 1, 8)
	var per: int = int(ceil(float(nz + 1) / float(bands)))
	var out: Array = []
	for b: int in bands:
		out.append(PackedFloat32Array())
	var task: int = WorkerThreadPool.add_group_task(func(b: int) -> void: out[b] = _land_rows(b * per, mini((b + 1) * per, nz + 1)), bands)
	WorkerThreadPool.wait_for_group_task_completion(task)
	var joined: PackedFloat32Array = PackedFloat32Array()
	for b: int in bands:
		joined.append_array(out[b])
	heights = joined
	var support := _grade_pads()
	# 2. stamps
	# bugfix-37 Q21: each vertex also learns the half width of the road it is nearest to (every road was graded with
	# the first road's half width: the village's spurs, 0.8 of the main road, were graded as wide as the main road)
	var road_hh: PackedFloat32Array = PackedFloat32Array()
	road_hh.resize(count)
	for rd: Dictionary in roads:
		_stamp(rd["pts"], rd["ys"], float(rd["half"]) + 10.0, road_d, road_y, road_hh, float(rd["half"]))
	if not river.is_empty():
		_stamp(river["pts"], river["ys"], 40.0, river_d, river_y)
	# 3. roads grade the land along them (each by its own half width), then the river digs its valley and channel
	var rv_half: float = float(river.get("half", 6.0))
	for k: int in count:
		var h: float = heights[k]
		var d: float = road_d[k]
		if d < 1e8:
			var ph: float = road_y[k]
			var rhalf: float = road_hh[k]
			wear_map[k] = maxf(wear_map[k], 1.0 - smoothstep(rhalf * 0.5, rhalf + 2.0, d))
			h = lerpf(h, ph - 0.02, 1.0 - smoothstep(rhalf + 1.6, rhalf + 9.0, d))
		var dr: float = river_d[k]
		if dr < 1e8:
			var lvl: float = river_y[k]
			var wv: float = 1.0 - smoothstep(5.0, 36.0, dr)
			h = minf(h, lerpf(h, lvl + 0.6, wv))
			h = lerpf(h, lvl - 1.0, 1.0 - smoothstep(rv_half * 0.55, rv_half + 5.0, dr))
		heights[k] = lerpf(h, heights[k], support[k])
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
					heights[k2] = lerpf(heights[k2], float(pn["y"]) - 1.2, (1.0 - smoothstep(pr * 0.7, pr + 7.0, d2)) * (1.0 - support[k2]))
	build_ms = Time.get_ticks_msec() - t0


## Heights of the unworked land for rows j0 .. j1 - 1 (runs on a worker: reads only).
func _land_rows(j0: int, j1: int) -> PackedFloat32Array:
	var w: int = nx + 1
	var rows: PackedFloat32Array = PackedFloat32Array()
	rows.resize(maxi(0, j1 - j0) * w)
	for j: int in range(j0, j1):
		var z: float = z0 + float(j) * cell
		for i: int in w:
			var x: float = x0 + float(i) * cell
			rows[(j - j0) * w + i] = base_h(x, z)
	return rows


## Stamp the pads before carving the road and water profiles. Return how much of each vertex must stay flat.
## Where two shoulders meet, combine their influences against the same original height. The supporting
## triangles inside the runtime clip take precedence over another footprint's corner or shoulder.
func _grade_pads() -> PackedFloat32Array:
	var support := PackedFloat32Array()
	support.resize(heights.size())
	wear_map.resize(heights.size())
	wear_map.fill(0.0)
	meadow_map.resize(heights.size())
	meadow_map.fill(0.0)
	var total := PackedFloat32Array()
	total.resize(heights.size())
	var cover := PackedFloat32Array()
	cover.resize(heights.size())
	var weights := PackedFloat32Array()
	weights.resize(heights.size())
	for pd: Dictionary in pads:
		var c: Vector2 = pd["c"]
		var extent: Vector2 = pd["extent"]
		var axis: Vector2 = pd["axis"]
		var side := Vector2(-axis.y, axis.x)
		var r: float = pd["rp"]
		var ph: float = pd["h"]
		var yard: bool = pd["yard"]
		var sink := not yard and not bool(pd["own"])
		var flat_margin := 2.0 if yard else 3.0 + cell * sqrt(2.0)
		var guard := r + flat_margin if not yard else 0.0
		var corner := minf(5.0, minf(extent.x, extent.y) * 0.2)
		var footprint_bounds := axis.abs() * (extent.x + flat_margin) + side.abs() * (extent.y + flat_margin)
		var flat_bounds := footprint_bounds.max(Vector2.ONE * guard)
		var reach := flat_bounds + Vector2.ONE * MAX_GRADE
		var grid := Vector2(x0, z0)
		var lo := Vector2i(((c - reach - grid) / cell).floor()).max(Vector2i.ZERO)
		var hi := Vector2i(((c + reach - grid) / cell).ceil()).min(Vector2i(nx, nz))
		var approach: Vector2 = pd["approach"]
		var entry := approach * r
		var path_half := float(pd.get("path_half", 0.0))
		var run_in := clampf(r * 0.40, 5.0, 19.0)
		for j: int in range(lo.y, hi.y + 1):
			var z := z0 + j * cell
			for i: int in range(lo.x, hi.x + 1):
				var x := x0 + i * cell
				var k := j * (nx + 1) + i
				var width := minf(20.0 + absf(ph - heights[k]) * 2.25, MAX_GRADE)
				if not yard and (absf(x - c.x) > flat_bounds.x + width or absf(z - c.y) > flat_bounds.y + width):
					continue
				var p := Vector2(x, z) - c
				var radial := p.length()
				if not yard and path_half > 0.0 and radial <= r + cell * 2.0:
					# Carry foot traffic past the posts. The tread narrows and grass returns as feet disperse.
					var depth := r - p.dot(approach)
					if depth >= -2.0 * cell and depth < run_in:
						var along := 1.0 - smoothstep(0.0, run_in, depth)
						var cross_path := absf(p.cross(approach) + (1.0 - along) * path_half * 0.7)
						var tread := 1.0 - smoothstep(path_half * 0.5 * along, path_half + 2.0, cross_path)
						wear_map[k] = maxf(wear_map[k], along * tread)
				if not yard and radial <= guard:
					# A negative weight locks this floor. Where two grid margins touch, keep the nearer clip.
					support[k] = 1.0
					var lock_weight := minf(-0.0001, radial - guard)
					if weights[k] >= lock_weight:
						total[k] = ph
						if sink:
							total[k] -= SINK * (1.0 - smoothstep(r, r + SINK_BAND, radial))
						weights[k] = lock_weight
					continue
				var local := Vector2(p.dot(axis), p.dot(side))
				var q := local.abs() - extent + Vector2.ONE * (corner - flat_margin)
				var edge := q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0) - corner
				if not yard:
					edge = minf(edge, radial - guard)
				var clearance := edge if yard else radial - guard
				if yard and radial < r + 6.0:
					# Wear runs from the spur to the crane, then along the stack of supplies.
					var crane := Vector2(-0.38, -0.22) * r
					var access := Geometry2D.get_closest_point_to_segment(p, entry, crane)
					var stores := Geometry2D.get_closest_point_to_segment(p, crane, Vector2(0.40, 0.32) * r)
					var d := minf(p.distance_to(access), p.distance_to(stores)) + 3.0 * _nd.get_noise_2d(x, z)
					wear_map[k] = maxf(wear_map[k], 1.0 - smoothstep(1.2, clampf(r * 0.43, 6.0, 14.0), d))

				if edge < width and weights[k] >= 0.0:
					# Zero slope and curvature at both ends, including where a road crosses the bank.
					var u := clampf(edge / width, 0.0, 1.0)
					var w := 1.0 - u * u * u * (10.0 + u * (-15.0 + 6.0 * u))
					support[k] = maxf(support[k], w)
					# Intersecting shoulders share a grade. Close to a protected floor its height wins smoothly.
					var influence := w * w / maxf(0.0001, smoothstep(0.0, width, clearance))
					total[k] += ph * influence
					weights[k] += influence
					cover[k] += (1.0 - cover[k]) * w
	for k: int in heights.size():
		if weights[k] < 0.0:
			heights[k] = total[k]
		elif weights[k] > 0.0:
			heights[k] = lerpf(heights[k], total[k] / weights[k], cover[k])
	return support


## Marks the vertices within `reach` of each sample of `pts` with their distance (`dist`) and the sample's y (`yy`) when
## that sample is the nearest so far; `hh` (optional, a road's) takes `half` there too.
func _stamp(pts: PackedVector2Array, ys: PackedFloat32Array, reach: float, dist: PackedFloat32Array, yy: PackedFloat32Array,
		hh: PackedFloat32Array = PackedFloat32Array(), half: float = 0.0) -> void:
	var w: int = nx + 1
	var rc: int = int(ceil(reach / cell))
	var with_h: bool = not hh.is_empty()
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
					if with_h:
						hh[k] = half


func alternating_diagonal(i: int, j: int) -> bool:
	return (i + j) % 2 == 0 and (fixed_chunks.is_empty() or not fixed_chunks.has(Vector2i(i >> 5, j >> 5)))


## The height at (x, z), consistent with the mesh triangles (the same diagonal rule as the kit's terrain).
func h(x: float, z: float) -> float:
	var fx: float = clampf((x - x0) / cell, 0.0, float(nx) - 0.0001)
	var fz: float = clampf((z - z0) / cell, 0.0, float(nz) - 0.0001)
	var i: int = int(fx)
	var j: int = int(fz)
	var u: float = fx - float(i)
	var v: float = fz - float(j)
	var pitch := nx + 1
	var k := j * pitch + i
	var right := j * pitch + mini(i + 1, nx)
	var below := mini(j + 1, nz) * pitch
	var a := heights[k]
	var b := heights[right]
	var c := heights[below + mini(i + 1, nx)]
	var d := heights[below + i]
	if (fixed_chunks.is_empty() or not fixed_chunks.has(Vector2i(i >> 5, j >> 5))) and ((i + j) & 1) == 0:
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
func paint_patch(p: Vector2, r: float, radii: PackedFloat32Array, tone: float, dirt: bool) -> void:
	# Paint into the same 3 m samples as the hill; a separate fan cut through convex ground.
	var seg := radii.size()
	var grid := Vector2(x0, z0)
	var lo := Vector2i(((p - Vector2.ONE * r - grid) / cell).floor()).max(Vector2i.ZERO)
	var hi := Vector2i(((p + Vector2.ONE * r - grid) / cell).ceil()).min(Vector2i(nx, nz))
	for j: int in range(lo.y, hi.y + 1):
		for i: int in range(lo.x, hi.x + 1):
			var q := grid + Vector2(i, j) * cell - p
			var a := fposmod(q.angle(), TAU) * seg / TAU
			var k := int(a) % seg
			var reach := lerpf(radii[k], radii[(k + 1) % seg], fmod(a, 1.0))
			var amount := tone * (1.0 - smoothstep(reach * 0.25, reach, q.length()))
			var index := j * (nx + 1) + i
			if dirt:
				wear_map[index] = maxf(wear_map[index], amount * 0.78)
			else:
				meadow_map[index] = maxf(meadow_map[index], amount)


func _col(x: float, y: float, z: float, n: Vector3, rd: float, rvd: float, wear: float = 0.0, meadow: float = 0.0) -> Color:
	var slope_: float = 1.0 - n.y
	var np: float = _np.get_noise_2d(x, z) * 0.5 + 0.5
	var base: Color = (_c["grass_dark"] as Color).lerp(_c["grass"], 0.5 + 0.5 * smoothstep(0.2, 0.8, np))
	var dry: float = smoothstep(0.55, 0.85, _nd.get_noise_2d(x * 0.4, z * 0.4) * 0.5 + 0.5) * 0.3 + smoothstep(-4.0, 6.0, y) * 0.12
	base = base.lerp(_c["grass_dry"], clampf(dry, 0.0, 0.85))
	base = base.lerp(_c["rock_warm"], smoothstep(14.0, 34.0, y) * 0.55)
	var rk: float = smoothstep(0.17, 0.34, slope_)
	var rock: Color = (_c["rock"] as Color).lerp(_c["cliff"], smoothstep(0.3, 0.7, np)).lerp(_c["rock_warm"], smoothstep(0.55, 0.85, _nd.get_noise_2d(x, z + 5.0) * 0.5 + 0.5) * 0.6)
	base = base.lerp(_c["grass_dark"], meadow)
	base = base.lerp(rock, rk)
	if rd < 30.0:
		base = base.lerp((_c["grass_dark"] as Color).lerp(_c["dirt"], 0.35), (1.0 - smoothstep(3.5, 12.0, rd)) * 0.5 * (1.0 - rk))
	if wear > 0.0:
		base = base.lerp((_c["dirt"] as Color).lerp(_c["sand"], np * 0.35), wear * 0.90)
	if rvd < 40.0:
		base = base.lerp(_c["sand"], (1.0 - smoothstep(float(river.get("half", 6.0)) * 0.6, float(river.get("half", 6.0)) + 7.0, rvd)) * 0.7 * (1.0 - rk * 0.6))
	return base.srgb_to_linear()


func build_mesh(mat: Material, name_: String = "WorldTerrain") -> MeshInstance3D:
	var start := Time.get_ticks_msec()
	var samples := preload("res://kernel/world/land/chunk_mesh.gd").new()
	samples.prepare(self, {})
	var mesh := samples.build(self, Rect2i(0, 0, nx, nz), mat, name_, 0, false)
	build_ms += Time.get_ticks_msec() - start
	return mesh


## Compile the village pigment path once. A pack running alone keeps the original shader program.
static func _village_material() -> ShaderMaterial:
	var palette := TLStyle.material(&"terrain") as ShaderMaterial
	if palette == null or palette.shader == null:
		return null
	if _village_shader == null:
		_village_shader = Shader.new()
		_village_shader.code = "#define TL_VILLAGE\n" + palette.shader.code
	var mat := ShaderMaterial.new()
	mat.shader = _village_shader
	mat.set_shader_parameter(&"pal_lut", palette.get_shader_parameter(&"pal_lut"))
	return mat


## A village lends its ground colours to the outer vertices of the kit terrain on its plots.
## The texels are the mesh's linear vertex colours. Texel centres coincide with heightfield samples.
static func _rim_material(colours: PackedColorArray, grid: Vector2i, origin: Vector2, cell: float) -> ShaderMaterial:
	var mat := _village_material()
	if mat == null:
		return null
	var img := Image.create_from_data(grid.x, grid.y, false, Image.FORMAT_RGBAF, colours.to_byte_array())
	img.convert(Image.FORMAT_RGBA8)
	var scale_ := Vector2.ONE / (Vector2(grid) * cell)
	var offset := (Vector2.ONE * cell * 0.5 - origin) * scale_
	mat.set_shader_parameter(&"tl_land_colours", ImageTexture.create_from_image(img))
	mat.set_shader_parameter(&"tl_land_uv", Vector4(scale_.x, scale_.y, offset.x, offset.y))
	mat.set_shader_parameter(&"tl_land_index", TLStyle.index("terrain"))
	return mat


## Triangles of the heightfield for the visitor's collider (world coordinates, GROUND_Y included). `skip` is a Callable
## (centre x, centre z) -> bool: true leaves the triangle out (a plot whose own ground carries the visitor there).
func collision_faces(skip: Callable) -> PackedVector3Array:
	# P13: the same triangles in the same order as P4's loop, without an Array per cell, and `skip` asked only for
	# cells near a plot whose own ground carries the visitor (`skip_near`: centres and radii; empty = ask everywhere)
	var faces: PackedVector3Array = PackedVector3Array()
	faces.resize(nx * nz * 6)
	var n: int = 0
	var near: bool = not skip_near.is_empty()
	for j: int in nz:
		var za: float = z0 + float(j) * cell
		for i: int in nx:
			var xa: float = x0 + float(i) * cell
			var a: Vector3 = Vector3(xa, heights[_v(i, j)] + GROUND_Y, za)
			var b: Vector3 = Vector3(xa + cell, heights[_v(i + 1, j)] + GROUND_Y, za)
			var c: Vector3 = Vector3(xa + cell, heights[_v(i + 1, j + 1)] + GROUND_Y, za + cell)
			var d: Vector3 = Vector3(xa, heights[_v(i, j + 1)] + GROUND_Y, za + cell)
			var ask: bool = true
			if near:
				ask = false
				for q: Vector3 in skip_near:
					if absf(xa + cell * 0.5 - q.x) < q.z + cell and absf(za + cell * 0.5 - q.y) < q.z + cell:
						ask = true
						break
			var even: bool = alternating_diagonal(i, j)
			var t0a: Vector3 = a
			var t0b: Vector3 = b
			var t0c: Vector3 = c if even else d
			var t1a: Vector3 = a if even else b
			var t1b: Vector3 = c
			var t1c: Vector3 = d
			if not ask or not bool(skip.call((t0a.x + t0b.x + t0c.x) / 3.0, (t0a.z + t0b.z + t0c.z) / 3.0)):
				faces[n] = t0a
				faces[n + 1] = t0c
				faces[n + 2] = t0b
				n += 3
			if not ask or not bool(skip.call((t1a.x + t1b.x + t1c.x) / 3.0, (t1a.z + t1b.z + t1c.z) / 3.0)):
				faces[n] = t1a
				faces[n + 1] = t1c
				faces[n + 2] = t1b
				n += 3
	faces.resize(n)
	return faces


## bugfix-37 D3: the triangles `collision_faces` leaves out for one plot: those of the heightfield whose centre lies
## within `r` of `c` (the plot's own ground carries the visitor there once its game has arrived). Same triangles, same
## order and winding as `collision_faces`; landscape.gd puts them in the visitor's space as the plot's pad until then.
func faces_in_disc(c: Vector2, r: float) -> PackedVector3Array:
	var faces: PackedVector3Array = PackedVector3Array()
	var i0: int = clampi(int(floor((c.x - r - x0) / cell)) - 1, 0, nx)
	var i1: int = clampi(int(ceil((c.x + r - x0) / cell)) + 1, 0, nx)
	var j0: int = clampi(int(floor((c.y - r - z0) / cell)) - 1, 0, nz)
	var j1: int = clampi(int(ceil((c.y + r - z0) / cell)) + 1, 0, nz)
	for j: int in range(j0, j1):
		var za: float = z0 + float(j) * cell
		for i: int in range(i0, i1):
			var xa: float = x0 + float(i) * cell
			var a: Vector3 = Vector3(xa, heights[_v(i, j)] + GROUND_Y, za)
			var b: Vector3 = Vector3(xa + cell, heights[_v(i + 1, j)] + GROUND_Y, za)
			var cc: Vector3 = Vector3(xa + cell, heights[_v(i + 1, j + 1)] + GROUND_Y, za + cell)
			var d: Vector3 = Vector3(xa, heights[_v(i, j + 1)] + GROUND_Y, za + cell)
			var even: bool = alternating_diagonal(i, j)
			var t0c: Vector3 = cc if even else d
			var t1a: Vector3 = a if even else b
			if Vector2((a.x + b.x + t0c.x) / 3.0, (a.z + b.z + t0c.z) / 3.0).distance_to(c) < r:
				faces.append_array(PackedVector3Array([a, t0c, b]))
			if Vector2((t1a.x + cc.x + d.x) / 3.0, (t1a.z + cc.z + d.z) / 3.0).distance_to(c) < r:
				faces.append_array(PackedVector3Array([t1a, d, cc]))
	return faces


## The samples of `pts` (a road) from the first to the last within `reach` of the river, as (first, last): where a
## bridge stands. (-1, -1) when none is, or when fewer than three samples are (bugfix-37 Q15: a road that only ends
## near the river; village_parts.gd `bridge` and landscape.gd's rail probe read the samples either side of its middle).
func bridge_span(pts: PackedVector2Array, reach: float) -> Vector2i:
	var a: int = -1
	var b: int = -1
	for i: int in pts.size():
		if river_dist(pts[i].x, pts[i].y) < reach:
			if a < 0:
				a = i
			b = i
	return Vector2i(a, b) if b - a >= 2 else Vector2i(-1, -1)
