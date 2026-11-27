extends RefCounted
## M5 lane W (spark world-sandbox): the poured water drawn in the still-water look, and its ghost.
##   One TLMesh per 96 m chunk with water (TLStyle key "water": style crisp's water_cel.gdshader with TL_SHORE), flat
##   quads at each cell's level, plus ONE ring of rim cells round the water at the level of the water beside them. The
##   shader reads the scene's depth, so the waterline falls where the land rises through the level (a contour, not the
##   cells' edges) and the foam line follows it. The fill puts every cell where the land dips below the level in the
##   water (water_fill.gd), so the ring stands under the land: it is the margin for where the drawn land differs from the
##   lattice (the valley's 12 m creases in an unedited chunk, millimetres). A ring cell with a corner below the level is
##   left out (that corner is another hollow's: water drawn there would be a puddle the fill did not make).
##   UV.x < -0.5 on every vertex: the shader's still-water branch (a pond: still streaks in the world's plane, no flow).
##   Shadows off; no collider (a walker wades on the bed, as at the river).
##   LP (27 Nov): the land's 3 m triangles made the waterline a polygon of 3 m sides. Every vertex now carries the bank
##   depth (the water over the drawn lattice on a grid of 0.75 m, -1..2 m each, blurred over about 2 m (`_box`
##   twice each way: near a Gaussian of 0.6 m), less MARGIN) as UV.x = BANK_UV +
##   depth (so UV.x stays under -0.5), and the shader ends the water where that depth does (and takes the smaller of it
##   and the depth it reads for its shallows): the corners round off into one curve a little inside the polygon, and the
##   land still hides the water wherever it stands above it. Cells near the bank (`SHORE_D`) are drawn in SUB x SUB
##   squares so the curve runs in short segments; a whole cell beside one is a fan through its sides' points (no
##   T-junction). In the world, not the screen: a visitor wading in the water is not read as the bank.
##   The ghost (a dry run's, the tool's aim): the cells a flood adds in the style's holo, those a drain removes in a red
##   copy of it (as preview_mesh.gd), 2 cm over the level. No hand-made material.

const LATTICE := 3.0
const PER := 32                          # cells per chunk side
const POND_UV := Vector2(-1.0, 0.5)
const HOLO_UV := Vector2(0.5, 2.0)       # holo: a fill, no edge lines (PATCHES-M3 P5)
const BANK_UV := -10.0                   # UV.x of a pond vertex = BANK_UV + its bank depth (m, -2..2)
const SUB := 4                           # a bank cell is drawn in SUB x SUB squares (0.75 m)
const SHORE_D := 1.0                     # a cell with a corner whose bank depth is under this is a bank cell
const MARGIN := 0.12                     # metres: the water ends this far (in depth) inside the mean's contour
const BLUR := 1                          # the mean: a box of 2 BLUR + 1 points (2.25 m) twice along x and twice along z
const N8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]

var holder: Node3D = null                # "HomeWater" under the builder's root (null: nothing is drawn)
var nodes := {}                          # Vector2i chunk -> MeshInstance3D
var hashes := {}                         # Vector2i chunk -> TLMesh content hash
var tris := {}                           # Vector2i chunk -> triangles
var stats := {"drawn": 0, "usec": []}


func _init(root: Node3D) -> void:
	if root == null:
		return
	holder = Node3D.new()
	holder.name = "HomeWater"
	root.add_child(holder)


## Redraws chunk `ch` from `levels` (Vector2i cell -> cm, every chunk's). `h`: (Vector2i vertex) -> cm, the land now
## (for the ring). Returns the triangles drawn.
func draw(ch: Vector2i, levels: Dictionary, h: Callable) -> int:
	var t0 := Time.get_ticks_usec()
	if nodes.has(ch):
		(nodes[ch] as Node).queue_free()
		nodes.erase(ch)
	hashes.erase(ch)
	tris.erase(ch)
	var mk := surface(ch, levels, h)
	if mk.tri_count > 0 and holder != null:
		var mi: MeshInstance3D = mk.instance("HomeWater_%d_%d" % [ch.x, ch.y])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
		nodes[ch] = mi
		hashes[ch] = mk.content_hash()
		tris[ch] = mk.tri_count
	stats.drawn += 1
	(stats.usec as Array).append(Time.get_ticks_usec() - t0)
	return mk.tri_count


## The TLMesh of chunk `ch`: its water cells and its ring cells.
static func surface(ch: Vector2i, levels: Dictionary, h: Callable) -> TLMesh:
	var mk := TLMesh.new(1)
	var lo := ch * PER
	var hi := lo + Vector2i(PER, PER)
	var ring := {}
	var cells := {}                          # Vector2i cell -> cm: every cell drawn
	for c: Vector2i in levels:
		if c.x < lo.x - 1 or c.y < lo.y - 1 or c.x > hi.x or c.y > hi.y:
			continue
		var lv := int(levels[c])
		if c.x >= lo.x and c.y >= lo.y and c.x < hi.x and c.y < hi.y:
			cells[c] = lv
		for o: Vector2i in N8:
			var r: Vector2i = c + o
			if levels.has(r) or r.x < lo.x or r.y < lo.y or r.x >= hi.x or r.y >= hi.y:
				continue
			ring[r] = maxi(int(ring.get(r, -(1 << 30))), lv)
	var keys: Array = ring.keys()
	keys.sort()
	for r: Vector2i in keys:
		if _dry(r, int(ring[r]), h):
			cells[r] = int(ring[r])
	if cells.is_empty():
		return mk
	var g := _grid(cells, h)
	var fine := {}                           # Vector2i cell -> bool (a bank cell), this chunk's and the water beside it
	for c: Vector2i in cells:
		fine[c] = _is_bank(g, c, cells[c])
	var order: Array = cells.keys()
	order.sort()
	for c: Vector2i in order:
		var lv: int = cells[c]
		var f0: Vector2i = c * SUB
		if fine[c]:
			_fine_cell(mk, g, c, lv)
			continue
		# a whole cell: two triangles, or a fan through its sides' points where a side meets a bank cell
		var sides := [[Vector2i(0, -1), f0, Vector2i(1, 0)], [Vector2i(1, 0), f0 + Vector2i(SUB, 0), Vector2i(0, 1)],
			[Vector2i(0, 1), f0 + Vector2i(SUB, SUB), Vector2i(-1, 0)], [Vector2i(-1, 0), f0 + Vector2i(0, SUB), Vector2i(0, -1)]]
		var rim := []
		var split := false
		for sd: Array in sides:
			var nb: Vector2i = c + (sd[0] as Vector2i)
			var nlv := int(cells.get(nb, levels.get(nb, -(1 << 30))))
			if nlv == lv and not fine.has(nb):
				fine[nb] = _is_bank(g, nb, lv)   # (water of the next chunk: its own mesh splits its side the same)
			var n: int = SUB if nlv == lv and bool(fine[nb]) else 1
			split = split or n > 1
			for k: int in n:
				rim.append((sd[1] as Vector2i) + (sd[2] as Vector2i) * (k * SUB / n))
		if not split:
			_tri_up(mk, g, lv, [f0, f0 + Vector2i(SUB, 0), f0 + Vector2i(SUB, SUB)])
			_tri_up(mk, g, lv, [f0, f0 + Vector2i(SUB, SUB), f0 + Vector2i(0, SUB)])
			continue
		var mid: Vector2i = f0 + Vector2i(SUB / 2, SUB / 2)
		for k: int in rim.size():
			_tri_up(mk, g, lv, [mid, rim[k], rim[(k + 1) % rim.size()]])
	return mk


## The half-metre grid round `cells` (2 cells past them each way): the drawn lattice's height at every point (`land`,
## from h once per vertex) and, per level asked (`_bank_of`), the bank depth.
static func _grid(cells: Dictionary, h: Callable) -> Dictionary:
	var vmin := Vector2i(1 << 30, 1 << 30)
	var vmax := -vmin
	for c: Vector2i in cells:
		vmin = Vector2i(mini(vmin.x, c.x - 2), mini(vmin.y, c.y - 2))
		vmax = Vector2i(maxi(vmax.x, c.x + 3), maxi(vmax.y, c.y + 3))
	var vw := vmax.x - vmin.x + 1
	var vh := vmax.y - vmin.y + 1
	var hv := PackedFloat32Array()
	hv.resize(vw * vh)
	for j: int in vh:
		for i: int in vw:
			hv[j * vw + i] = int(h.call(vmin + Vector2i(i, j))) / 100.0
	var nx := (vw - 1) * SUB + 1
	var nz := (vh - 1) * SUB + 1
	var land := PackedFloat32Array()
	land.resize(nx * nz)
	for fj: int in nz:
		var j := mini(fj / SUB, vh - 2)
		var v := float(fj - j * SUB) / SUB
		for fi: int in nx:
			var i := mini(fi / SUB, vw - 2)
			var u := float(fi - i * SUB) / SUB
			var k := j * vw + i
			# the lattice triangles split from (i, j) to (i + 1, j + 1), as the land is drawn
			var h00 := hv[k]
			var h11 := hv[k + vw + 1]
			if u >= v:
				var h10 := hv[k + 1]
				land[fj * nx + fi] = h00 + u * (h10 - h00) + v * (h11 - h10)
			else:
				var h01 := hv[k + vw]
				land[fj * nx + fi] = h00 + v * (h01 - h00) + u * (h11 - h01)
	return {"f0": vmin * SUB, "nx": nx, "nz": nz, "land": land, "bank": {}}


## The bank depth grid of water at `lv` cm (made once per level).
static func _bank_of(g: Dictionary, lv: int) -> PackedFloat32Array:
	if (g.bank as Dictionary).has(lv):
		return g.bank[lv]
	var land: PackedFloat32Array = g.land
	var nx: int = g.nx
	var nz: int = g.nz
	var d := PackedFloat32Array()
	d.resize(land.size())
	var wl := lv / 100.0
	for k: int in land.size():
		d[k] = clampf(wl - land[k], -1.0, 2.0)
	d = _box(_box(d, nx, nz, true), nx, nz, true)
	d = _box(_box(d, nx, nz, false), nx, nz, false)
	for k: int in d.size():
		d[k] = clampf(d[k] - MARGIN, -2.0, 2.0)
	g.bank[lv] = d
	return d


## One pass of a box mean of 2 BLUR + 1 points along x (`along_x`) or z, the grid's edge repeated.
static func _box(src: PackedFloat32Array, nx: int, nz: int, along_x: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(src.size())
	var n := nx if along_x else nz
	var lines := nz if along_x else nx
	var step := 1 if along_x else nx
	var inv := 1.0 / (2 * BLUR + 1)
	for l: int in lines:
		var base := l * nx if along_x else l
		var sum := 0.0
		for t: int in range(-BLUR, BLUR + 1):
			sum += src[base + clampi(t, 0, n - 1) * step]
		for t: int in n:
			out[base + t * step] = sum * inv
			sum += src[base + mini(t + BLUR + 1, n - 1) * step] - src[base + maxi(t - BLUR, 0) * step]
	return out


## The bank depth at fine point `q` (SUB-ths of a cell, the world's) for water at `lv` cm.
static func _bank(g: Dictionary, q: Vector2i, lv: int) -> float:
	var b := _bank_of(g, lv)
	var f0: Vector2i = g.f0
	return b[(q.y - f0.y) * int(g.nx) + (q.x - f0.x)]


## True when cell `c` (water at `lv` cm) lies by the bank: a corner's bank depth under SHORE_D, or its land within
## SHORE_D of the level.
static func _is_bank(g: Dictionary, c: Vector2i, lv: int) -> bool:
	var f0: Vector2i = g.f0
	var land: PackedFloat32Array = g.land
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var q: Vector2i = (c + o) * SUB
		if _bank(g, q, lv) < SHORE_D or land[(q.y - f0.y) * int(g.nx) + (q.x - f0.x)] > lv / 100.0 - SHORE_D:
			return true
	return false


## Cell `c` (water at `lv` cm) in SUB x SUB squares, two triangles each, none where all three corners are dry.
static func _fine_cell(mk: TLMesh, g: Dictionary, c: Vector2i, lv: int) -> void:
	var bk := _bank_of(g, lv)
	var f0: Vector2i = g.f0
	var nx: int = g.nx
	var y := lv / 100.0
	var s := LATTICE / SUB
	var q0 := c * SUB
	var dv := PackedFloat32Array()
	var pv := PackedVector3Array()
	for j: int in SUB + 1:
		var row := (q0.y + j - f0.y) * nx + (q0.x - f0.x)
		for i: int in SUB + 1:
			dv.append(bk[row + i])
			pv.append(Vector3((q0.x + i) * s, y, (q0.y + j) * s))
	var w := SUB + 1
	for j: int in SUB:
		for i: int in SUB:
			var k := j * w + i
			var d00 := dv[k]
			var d10 := dv[k + 1]
			var d01 := dv[k + w]
			var d11 := dv[k + w + 1]
			if d00 > 0.0 or d10 > 0.0 or d11 > 0.0:
				mk.tri(pv[k], pv[k + w + 1], pv[k + 1], "water", Color.WHITE, Vector2(BANK_UV + d00, POND_UV.y), Vector2(BANK_UV + d11, POND_UV.y), Vector2(BANK_UV + d10, POND_UV.y))
			if d00 > 0.0 or d01 > 0.0 or d11 > 0.0:
				mk.tri(pv[k], pv[k + w], pv[k + w + 1], "water", Color.WHITE, Vector2(BANK_UV + d00, POND_UV.y), Vector2(BANK_UV + d01, POND_UV.y), Vector2(BANK_UV + d11, POND_UV.y))


## One water triangle at `lv` cm through the fine points `f` (Vector2i, SUB-ths of a cell), wound to face up, each
## vertex with its bank depth in UV.x; none where the bank depth is under 0 at all three.
static func _tri_up(mk: TLMesh, g: Dictionary, lv: int, f: Array) -> void:
	var y := lv / 100.0
	var p := []
	var uv := []
	var wet := false
	for q: Vector2i in f:
		var d := _bank(g, q, lv)
		wet = wet or d > 0.0
		p.append(Vector3(q.x * LATTICE / SUB, y, q.y * LATTICE / SUB))
		uv.append(Vector2(BANK_UV + d, POND_UV.y))
	if not wet:
		return                               # (dry at all three corners: the shader would discard all of it)
	if ((p[1] as Vector3) - (p[0] as Vector3)).cross((p[2] as Vector3) - (p[0] as Vector3)).y > 0.0:   # (as `quad`)
		mk.tri(p[0], p[1], p[2], "water", Color.WHITE, uv[0], uv[1], uv[2])
	else:
		mk.tri(p[0], p[2], p[1], "water", Color.WHITE, uv[0], uv[2], uv[1])


## True when every corner of cell `c` stands at or above `cm`.
static func _dry(c: Vector2i, cm: int, h: Callable) -> bool:
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		if int(h.call(c + o)) < cm:
			return false
	return true


static func quad(mk: TLMesh, c: Vector2i, y: float, key: String, uv: Vector2) -> void:
	var p := Vector3(c.x * LATTICE, y, c.y * LATTICE)
	var dx := Vector3(LATTICE, 0.0, 0.0)
	var dz := Vector3(0.0, 0.0, LATTICE)
	mk.tri(p, p + dz, p + dx + dz, key, Color.WHITE, uv, uv, uv)
	mk.tri(p, p + dx + dz, p + dx, key, Color.WHITE, uv, uv, uv)


func free_all() -> void:
	for ch: Vector2i in nodes:
		(nodes[ch] as Node).queue_free()
	nodes.clear()
	hashes.clear()
	tris.clear()
	if holder != null and is_instance_valid(holder):
		holder.queue_free()
	holder = null


# ------------------------------------------------------------------ the ghost
## A Node3D drawing `added` (Vector2i -> cm: cells a dry run floods or re-levels) in holo and `removed` (cells it
## drains, at the level they had) in red; null when both are empty. The caller adds it to the tree and frees it.
static func ghost(added: Dictionary, removed: Dictionary) -> Node3D:
	if added.is_empty() and removed.is_empty():
		return null
	var n := Node3D.new()
	n.name = "WaterGhost"
	n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for part: Array in [[added, false], [removed, true]]:
		var d: Dictionary = part[0]
		if d.is_empty():
			continue
		var mk := TLMesh.new(1)
		if part[1]:
			mk.mats["holo"] = _red()
		for c: Vector2i in d:
			quad(mk, c, int(d[c]) / 100.0 + 0.02, "holo", HOLO_UV)
		var mi: MeshInstance3D = mk.instance("Drained" if part[1] else "Flooded")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta(&"tl_cells", d.size())
		n.add_child(mi)
	return n


static func _red() -> Material:
	var m := TLStyle.material_instance("holo")
	if m is ShaderMaterial and not TLStyle.headless():
		var red := TLStyle.color("hazard_red")
		(m as ShaderMaterial).set_shader_parameter(&"holo", red)
		(m as ShaderMaterial).set_shader_parameter(&"edge", red.lightened(0.4))
	return m
