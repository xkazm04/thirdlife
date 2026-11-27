extends RefCounted
## M5 (spark world-sandbox, lane P): the drawing of the Home's paths, one mesh per 96 m chunk a path crosses.
## A path of a ground paint (dirt, sand, rock_warm, grass_dry) is a ribbon in the TERRAIN material, as an edited
## land chunk is drawn (land_mesh.gd `_fill`: COLOR the pigment, CUSTOM0 = world xyz + the terrain code), draped on the
## ground (the land layer's `height_at`) and lifted LIFT. It is sampled every metre along the spline (path_shape.gd)
## and has at least 5 rows across: the outer rows (half width + EDGE) carry the ground's own colour, the rows at half
## width - EDGE the paint, and the colour between them is the path's soft field `f = (h + e - d) / 2e` (d: the
## distance to the centre line), so the cel shader's nearest-paint snap (toon_cel.gdshader, the land) draws ONE crisp,
## slightly wobbly edge along the curve, with the verge and the tufts hanging over a dirt or sand edge as on the
## valley's lanes. The ribbon runs on past both ends by h + e, so the field rounds the ends. Where two paths meet, each
## vertex takes the field of every path near it (in id order), so both ribbons draw the same edges at a crossing.
## A `plank` path is a boardwalk (SLABS): the kit's plank surface a little up, with a darker side down into the ground,
## through TLMesh. No collider: the graded ground carries the walker.
## LP (27 Nov): a `stone` path is a terrain ribbon too, with the dirt path's field (so the same crisp edge, verge and
## tufts over it, and the same round ends), and its vertices carry the path's own coordinates in UV2 (x = metres along
## from the first point, y = -1000 - metres across; every other ribbon writes 0): toon_cel.gdshader lays stones in rows
## across the path there, the joints following it (M5 drew a slab of the kit's masonry: square ends, the bricks on the
## world's axes).
## A hologram ribbon (`ghost`) is the path tool's live ghost and the layer's `preview_node`.

const PathShape := preload("res://kernel/world/build/path_shape.gd")
const CHUNK := 96.0
const LIFT := 0.05                       # metres over the ground (the valley's lanes float 0.22)
## The paints drawn as a slab through TLMesh instead of the terrain: [surface key, side key, lift (m)]. `plank` is a
## palette key, not a ground paint: a boardwalk. `stone` is no land paint either (toon_cel snaps the land to eight
## paints; measured in the exe: drawn as the land's rock it was a lavender-pink slab with purple strata, and its own
## grey snaps half way to dirt): a paved way of the kit's masonry, a low kerb at its sides.
const SLABS := {"plank": ["plank", "wood_dark", 0.12]}
const STONE_UV2 := -1000.0              # UV2.y of a stone ribbon is STONE_UV2 - metres across (the shader reads < -500)
const EDGE := 0.5                        # metres either side of the edge between the ground's colour and the paint
const ROW_GAP := 1.5                     # metres between inner rows at most
const GHOST_LIFT := 0.15
## The land paint each ground path paint is drawn with (toon_cel snaps the land to its eight paints).
const PIGMENT := {"dirt": "dirt", "sand": "sand", "rock_warm": "rock_warm", "grass_dry": "grass_dry", "stone": "dirt"}

var land: RefCounted = null              # land_layer.gd (read only): heights, the ground's colour, normals
var g: RefCounted = null                 # land_ground.gd
var growth: RefCounted = null            # a layer with `uv_at(x, z)` (the land mesh's growth channel), or null


func _init(land_layer: RefCounted, growth_layer: RefCounted = null) -> void:
	land = land_layer
	g = land_layer.ground() if land_layer != null else null
	growth = growth_layer if growth_layer != null and growth_layer.has_method("uv_at") else null


static func chunk_of(q: Vector2) -> Vector2i:
	return Vector2i(floori(q.x / CHUNK), floori(q.y / CHUNK))


## The rows across a path of half width `h` (metres from the centre line, left to right).
static func rows(h: float, plank: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var e := 0.0 if plank else edge_of(h)
	var inner := h - e
	if not plank:
		out.append(-(h + e))
	var n := maxi(2, ceili(2.0 * inner / ROW_GAP))
	for k: int in n + 1:
		out.append(-inner + 2.0 * inner * float(k) / float(n))
	if not plank:
		out.append(h + e)
	return out


static func edge_of(h: float) -> float:
	return minf(EDGE, h * 0.5)


## The sections a path is drawn through: [point, tangent] for every sample, and, for a ground paint, the run past
## each end (h + e) that rounds it (`ext_of` sections before the first sample).
static func ext_of(h: float, plank: bool) -> int:
	return 0 if plank else ceili((h + edge_of(h)) / PathShape.STEP)


static func sections(sm: Dictionary, h: float, plank: bool) -> Array:
	var p: PackedVector2Array = sm.p
	var t: PackedVector2Array = sm.t
	var out := []
	var n := p.size()
	var run := 0.0 if plank else h + edge_of(h)
	var k := ceili(run / PathShape.STEP)
	for i: int in range(k, 0, -1):
		out.append([p[0] - t[0] * minf(run, float(i) * PathShape.STEP), t[0]])
	for i: int in n:
		out.append([p[i], t[i]])
	for i: int in range(1, k + 1):
		out.append([p[n - 1] + t[n - 1] * minf(run, float(i) * PathShape.STEP), t[n - 1]])
	return out


# ------------------------------------------------------------------ the ground under it
func height(x: float, z: float) -> float:
	if g == null:
		return 0.0
	return float(g.y(x, z)) + _delta(x, z)


## The lattice's height deltas, read once per build (land_layer.gd `_d`: a vertex's height minus the ground's own).
var _dd := {}
var _gg := {}


## Forgets what `_delta` and `_grad` read: the land may have changed since the last build.
func begin() -> void:
	_dd.clear()
	_gg.clear()


func _d(v: Vector2i) -> float:
	var hs: Dictionary = land.store.heights
	if not hs.has(v):
		return 0.0
	if not _dd.has(v):
		_dd[v] = float(hs[v]) / 100.0 - float(g.y(v.x * 3.0, v.y * 3.0))
	return _dd[v]


## [k0, k1, k2, w0, w1, w2] of the lattice triangle under (x, z) (land_mesh.gd's split: the diagonal a..c).
static func _tri(x: float, z: float) -> Array:
	var li := floori(x / 3.0)
	var lj := floori(z / 3.0)
	var u := x / 3.0 - li
	var v := z / 3.0 - lj
	var a := Vector2i(li, lj)
	if u >= v:
		return [a, a + Vector2i(1, 0), a + Vector2i(1, 1), 1.0 - u, u - v, v]
	return [a, a + Vector2i(1, 1), a + Vector2i(0, 1), 1.0 - v, u, v - u]


## The land's delta at (x, z) (land_layer.gd `delta_at`, from the cache).
func _delta(x: float, z: float) -> float:
	if land == null or (land.store.heights as Dictionary).is_empty():
		return 0.0
	var t := _tri(x, z)
	return float(t[3]) * _d(t[0]) + float(t[4]) * _d(t[1]) + float(t[5]) * _d(t[2])


## The delta's gradient at lattice vertex `v` (central differences, land_mesh.gd `_fill`).
func _grad_at(v: Vector2i) -> Vector2:
	if not _gg.has(v):
		_gg[v] = Vector2(_d(v + Vector2i(1, 0)) - _d(v - Vector2i(1, 0)), _d(v + Vector2i(0, 1)) - _d(v - Vector2i(0, 1))) / 6.0
	return _gg[v]


## [y, colour, normal, code] of the ground at (x, z) as the land draws it: the valley's (land_ground.gd `attrs`) plus
## the land's delta; the land's paint added as land_mesh.gd adds it (each painted cell gives a quarter of (paint -
## ground) to its corners, interpolated on the lattice's triangles); the normal tilted by the delta's gradient the way
## land_mesh.gd tilts it, so the ribbon's rim shades as the ground beside it does.
func ground_at(x: float, z: float) -> Array:
	if g == null:
		return [0.0, Color(0.3, 0.5, 0.2), Vector3.UP, 1]
	var at: Array = g.attrs(x, z)
	var y: float = at[0] if not (g.border as Rect2).has_point(Vector2(x, z)) else float(g.y(x, z))
	var col: Color = at[1]
	var nrm: Vector3 = at[2]
	var code: int = at[3]
	var st: RefCounted = land.store
	var t: Array = []
	if not (st.paints as Dictionary).is_empty():
		t = _tri(x, z)
		var dc := Color(0, 0, 0, 0)
		var fp := 0.0
		for c: int in 3:
			var cv: Vector2i = t[c]
			var w: float = t[3 + c]
			if w <= 0.0:
				continue
			var base: Color = g.attrs(cv.x * 3.0, cv.y * 3.0)[1]
			for o: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				var cell := cv + o
				if (st.paints as Dictionary).has(cell):
					dc += (g.pigment(st.paint_at(cell), cv.x * 3.0, cv.y * 3.0) - base) * 0.25 * w
					fp += 0.25 * w
		if fp > 0.0:
			col = Color(maxf(col.r + dc.r, 0.0), maxf(col.g + dc.g, 0.0), maxf(col.b + dc.b, 0.0), 1.0)
			code = g.terrain_code
	if not (st.heights as Dictionary).is_empty():
		if t.is_empty():
			t = _tri(x, z)
		y += float(t[3]) * _d(t[0]) + float(t[4]) * _d(t[1]) + float(t[5]) * _d(t[2])
		var gr: Vector2 = _grad_at(t[0]) * float(t[3]) + _grad_at(t[1]) * float(t[4]) + _grad_at(t[2]) * float(t[5])
		if gr != Vector2.ZERO:
			var by := maxf(nrm.y, 0.05)
			nrm = Vector3(nrm.x / by - gr.x, 1.0, nrm.z / by - gr.y).normalized()
	return [y, col, nrm, code]


# ------------------------------------------------------------------ a chunk's mesh
## The arrays of chunk `chunk` for the paths `ids` at once (`job_of`, `run`, `result`).
func chunk_arrays(chunk: Vector2i, ids: Array, info: Dictionary, index: RefCounted) -> Dictionary:
	var job := job_of(chunk, ids, info)
	run(job, info, index, 1 << 30)
	return result(job)


## A chunk's drawing as a job that `run` works through a few vertices at a time: every segment of the paths `ids`
## (each `info[id]`: {"rec", "h", "plank", "secs", "rows", "ext", "n"}) whose middle lies in the chunk.
static func job_of(chunk: Vector2i, ids: Array, info: Dictionary) -> Dictionary:
	var todo := []
	for id: int in ids:
		if not info.has(id):
			continue
		var secs: Array = info[id].secs
		for j: int in secs.size() - 1:
			if chunk_of(((secs[j][0] as Vector2) + (secs[j + 1][0] as Vector2)) * 0.5) == chunk:
				todo.append([id, j])
	return {"chunk": chunk, "todo": todo, "k": 0, "pos": PackedVector3Array(), "nrm": PackedVector3Array(), "col": PackedColorArray(),
		"cus": PackedFloat32Array(), "uv": PackedVector2Array(), "uv2": PackedVector2Array(), "idx": PackedInt32Array(), "made": {}, "plank": null, "tris": 0}


## Works job `job` on until about `most` more vertices are made; true when it is done. Every path's field comes from
## `index` (path_shape.gd Index; ground paints only).
func run(job: Dictionary, info: Dictionary, index: RefCounted, most: int) -> bool:
	var pos: PackedVector3Array = job.pos
	var nrm: PackedVector3Array = job.nrm
	var col: PackedColorArray = job.col
	var cus: PackedFloat32Array = job.cus
	var uv: PackedVector2Array = job.uv
	var uv2: PackedVector2Array = job.uv2
	var idx: PackedInt32Array = job.idx
	var plank: RefCounted = job.plank
	var tris: int = job.tris
	var tcode: int = g.terrain_code if g != null else 1
	var todo: Array = job.todo
	var made_all: Dictionary = job.made
	var spent := 0
	var k: int = job.k
	begin()
	while k < todo.size() and spent < most:
		var id: int = todo[k][0]
		var j: int = todo[k][1]
		k += 1
		if not info.has(id):
			continue
		var it: Dictionary = info[id]
		var is_plank: bool = it.plank
		var secs: Array = it.secs
		var rw: PackedFloat32Array = it.rows
		var nr := rw.size()
		if not made_all.has(id):
			made_all[id] = {}
		var made: Dictionary = made_all[id]      # section index -> its first vertex in pos (terrain), or its points (plank)
		for s: int in [j, j + 1]:
			if made.has(s):
				continue
			spent += nr
			var q: Vector2 = secs[s][0]
			var side: Vector2 = (secs[s][1] as Vector2).orthogonal()
			if is_plank:
				var pts := []
				var lift: float = SLABS[it.rec.paint][2]
				for r: int in nr:
					var w := q + side * rw[r]
					pts.append(Vector3(w.x, height(w.x, w.y) + lift, w.y))
				made[s] = pts
				continue
			made[s] = pos.size()
			var si := clampi(s - int(it.ext), 0, int(it.n) - 1)
			var own_segs: Array = range(maxi(0, si - 3), mini(int(it.n) - 1, si + 3))
			for r: int in nr:
				var w := q + side * rw[r]
				var ga := ground_at(w.x, w.y)
				var c: Color = ga[1]
				var code: int = ga[3]
				var near: Dictionary = index.near(w, id, own_segs)
				var keys: Array = near.keys()
				keys.sort()
				for kk: int in keys:
					var ik: Dictionary = info.get(kk, {})
					if ik.is_empty() or bool(ik.plank):
						continue
					var e := edge_of(float(ik.h))
					var f := clampf((float(ik.h) + e - float(near[kk][0])) / (2.0 * e), 0.0, 1.0)
					if f > 0.0:
						c = c.lerp(g.pigment(PIGMENT[ik.rec.paint], w.x, w.y) if g != null else Color(0.6, 0.4, 0.3), f)
						code = tcode
				c.a = 1.0
				var y: float = float(ga[0]) + LIFT
				pos.append(Vector3(w.x, y, w.y))
				nrm.append(ga[2])
				col.append(c)
				cus.append_array([w.x, y, w.y, float(code)])
				uv.append(growth.uv_at(w.x, w.y) if growth != null else Vector2.ZERO)
				uv2.append(Vector2(float(s - int(it.ext)) * PathShape.STEP, STONE_UV2 - rw[r]) if str(it.rec.paint) == "stone" else Vector2.ZERO)
		if is_plank:
			if plank == null:
				plank = TLMesh.new()
			var pa: Array = made[j]
			var pb: Array = made[j + 1]
			var slab: Array = SLABS[it.rec.paint]
			for r: int in nr - 1:
				plank.quad_up(pa[r], pa[r + 1], pb[r + 1], pb[r], slab[0])
				tris += 2
			for r: int in [0, nr - 1]:
				var d := Vector3.DOWN * (float(slab[2]) + 0.1)
				plank.quad_up_any(pa[r], pb[r], pb[r] + d, pa[r] + d, slab[1])
				tris += 4
			continue
		var ka: int = made[j]
		var kb: int = made[j + 1]
		for r: int in nr - 1:
			var v0 := ka + r
			var v1 := ka + r + 1
			var v2 := kb + r + 1
			var v3 := kb + r
			# Godot's front face, seen from above: (b - a) x (c - a) points down (land_mesh.gd's winding)
			if (pos[v1] - pos[v0]).cross(pos[v2] - pos[v0]).y < 0.0:
				idx.append_array([v0, v1, v2, v0, v2, v3])
			else:
				idx.append_array([v0, v2, v1, v0, v3, v2])
			tris += 2
	job.pos = pos
	job.nrm = nrm
	job.col = col
	job.cus = cus
	job.uv = uv
	job.uv2 = uv2
	job.idx = idx
	job.plank = plank
	job.tris = tris
	job.k = k
	return k >= todo.size()


## A finished job's arrays: {"terrain": {pos, nrm, col, cus, uv, idx} or {}, "plank": TLMesh or null, "tris", "verts"}.
static func result(job: Dictionary) -> Dictionary:
	var pos: PackedVector3Array = job.pos
	var nrm: PackedVector3Array = job.nrm
	var col: PackedColorArray = job.col
	var cus: PackedFloat32Array = job.cus
	var uv: PackedVector2Array = job.uv
	var uv2: PackedVector2Array = job.uv2
	var idx: PackedInt32Array = job.idx
	var plank: RefCounted = job.plank
	var tris: int = job.tris
	var terrain := {}
	if not pos.is_empty():
		terrain = {"pos": pos, "nrm": nrm, "col": col, "cus": cus, "uv": uv, "uv2": uv2, "idx": idx}
	return {"terrain": terrain, "plank": plank, "tris": tris, "verts": pos.size()}


## The chunk's MeshInstance3D nodes for `arrays` (`chunk_arrays`): the terrain ribbon (no shadow: it lies on the
## ground) and the boardwalk.
static func instances(chunk: Vector2i, arrays: Dictionary) -> Array:
	var out := []
	var t: Dictionary = arrays.terrain
	if not t.is_empty():
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = t.pos
		arr[Mesh.ARRAY_INDEX] = t.idx
		arr[Mesh.ARRAY_COLOR] = t.col
		arr[Mesh.ARRAY_CUSTOM0] = t.cus
		arr[Mesh.ARRAY_NORMAL] = t.nrm
		arr[Mesh.ARRAY_TEX_UV] = t.uv
		if (t.uv2 as PackedVector2Array).size() == (t.pos as PackedVector3Array).size():
			arr[Mesh.ARRAY_TEX_UV2] = t.uv2
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		m.surface_set_material(0, TLStyle.material("terrain"))
		var mi := MeshInstance3D.new()
		mi.name = "Paths %d,%d" % [chunk.x, chunk.y]
		mi.mesh = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.append(mi)
	if arrays.plank != null:
		var pm: MeshInstance3D = (arrays.plank as RefCounted).call("instance", "Slabs %d,%d" % [chunk.x, chunk.y])
		out.append(pm)
	return out


## The identity of a chunk's arrays (the same ops give the same mesh).
static func hash_of(arrays: Dictionary) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	var t: Dictionary = arrays.terrain
	if not t.is_empty():
		for k: String in ["pos", "nrm", "col", "cus", "uv2", "idx"]:
			h.update((t[k] as Variant).to_byte_array())
	if arrays.plank != null:
		h.update(str((arrays.plank as RefCounted).call("content_hash")).to_utf8_buffer())
	return h.finish().hex_encode()


# ------------------------------------------------------------------ the hologram
## A hologram ribbon through samples `p` (metres) of half width `h`, every other sample: the path tool's live ghost
## and an LLM answer's ghost. `red`: a refused (or removed) path, in a red copy of the holo material.
func ghost(p: PackedVector2Array, h: float, red: bool, name := "PathGhost") -> MeshInstance3D:
	begin()
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var u := PackedVector2Array()
	var idx := PackedInt32Array()
	var count := p.size()
	var picks := []
	for i: int in range(0, count, 2):
		picks.append(i)
	if picks.is_empty() or picks[picks.size() - 1] != count - 1:
		picks.append(count - 1)
	var along := 0.0
	for k: int in picks.size():
		var i: int = picks[k]
		var t := (p[mini(i + 1, count - 1)] - p[maxi(i - 1, 0)]).normalized()
		var side := t.orthogonal()
		if k > 0:
			along += p[i].distance_to(p[picks[k - 1]])
		for r: int in 3:
			var off := (float(r) - 1.0) * h
			var w := p[i] + side * off
			v.append(Vector3(w.x, height(w.x, w.y) + GHOST_LIFT, w.y))
			n.append(Vector3.UP)
			u.append(Vector2(along / maxf(h * 2.0, 1.0), 0.0 if r != 1 else 1.0))
	for k: int in picks.size() - 1:
		for r: int in 2:
			var a := k * 3 + r
			var b := a + 1
			var c := a + 4
			var d := a + 3
			if (v[b] - v[a]).cross(v[c] - v[a]).y < 0.0:
				idx.append_array([a, b, c, a, c, d])
			else:
				idx.append_array([a, c, b, a, d, c])
	var mi := MeshInstance3D.new()
	mi.name = name
	if idx.is_empty():
		return mi
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = u
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = holo(red)
	return mi


static var _red: Material = null


static func holo(red: bool) -> Material:
	if not red:
		return TLStyle.material("holo")
	if _red == null:
		_red = TLStyle.material_instance("holo")
		if _red is ShaderMaterial:
			(_red as ShaderMaterial).set_shader_parameter(&"holo", TLStyle.color("hazard_red"))
	return _red
