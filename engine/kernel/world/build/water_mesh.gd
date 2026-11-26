extends RefCounted
## M5 lane W (spark world-sandbox): the poured water drawn in the still-water look, and its ghost.
##   One TLMesh per 96 m chunk with water (TLStyle key "water": style crisp's water_cel.gdshader with TL_SHORE), flat
##   quads at each cell's level, plus ONE ring of rim cells round the water at the level of the water beside them. The
##   shader reads the scene's depth, so the waterline falls where the land rises through the level (a contour, not the
##   cells' edges) and the foam line follows it. The fill puts every cell where the land dips below the level in the
##   water (water_fill.gd), so the ring stands under the land: it is the margin for where the drawn land differs from the
##   lattice (the valley's 12 m creases in an unedited chunk, millimetres). A ring cell with a corner below the level is
##   left out (that corner is another hollow's: water drawn there would be a puddle the fill did not make).
##   UV (-1, 0.5) on every vertex: the shader's still-water branch (`UV.x < -0.5`, a pond: still streaks in the world's
##   plane, no flow). Shadows off; no collider (a walker wades on the bed, as at the river).
##   The ghost (a dry run's, the tool's aim): the cells a flood adds in the style's holo, those a drain removes in a red
##   copy of it (as preview_mesh.gd), 2 cm over the level. No hand-made material.

const LATTICE := 3.0
const PER := 32                          # cells per chunk side
const POND_UV := Vector2(-1.0, 0.5)
const HOLO_UV := Vector2(0.5, 2.0)       # holo: a fill, no edge lines (PATCHES-M3 P5)
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
	for c: Vector2i in levels:
		if c.x < lo.x - 1 or c.y < lo.y - 1 or c.x > hi.x or c.y > hi.y:
			continue
		var lv := int(levels[c])
		if c.x >= lo.x and c.y >= lo.y and c.x < hi.x and c.y < hi.y:
			quad(mk, c, lv / 100.0, "water", POND_UV)
		for o: Vector2i in N8:
			var r: Vector2i = c + o
			if levels.has(r) or r.x < lo.x or r.y < lo.y or r.x >= hi.x or r.y >= hi.y:
				continue
			ring[r] = maxi(int(ring.get(r, -(1 << 30))), lv)
	var keys: Array = ring.keys()
	keys.sort()
	for r: Vector2i in keys:
		var lv: int = ring[r]
		if _dry(r, lv, h):
			quad(mk, r, lv / 100.0, "water", POND_UV)
	return mk


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
