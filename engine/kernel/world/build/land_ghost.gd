extends Node3D
## M5 lane L (spark world-sandbox): the ghost of the ground's part of a dry run (home_build.gd `preview`): what an LLM
## answer would sculpt, paint or plant, seen before the player accepts it (BUILD.md "Layers" `preview_node`). Flat
## patches over 3 m cells in the style's holo material (a fill, UV (0.5, 2), as preview_mesh.gd draws blocks), tinted
## per kind by a private copy of it (as ghost.gd's red); no hand-made material. Kernel code, no input, no body.
##   land_layer.gd   the cells round every vertex the ops raise, at the new height, in holo; those they lower, on the
##                   ground as it is now, in red (the new ground lies under it and would be hidden); painted cells in
##                   the paint's colour, cells set back to the valley's in red
##   plants_layer.gd the cells whose growth changes, in their green (red: cleared)
## The caller adds the node to the tree and frees it.

const LIFT := 0.15                       # metres over the ground a patch floats (it must not z-fight the ground)
const L := 3.0

var cells_drawn := 0
var _parts := []                         # [tint, PackedVector3Array]: drawn when the node enters the tree (an orphan ghost
                                         # that nobody adds holds no mesh or material: 754 drops one unfreed)


func _init() -> void:
	name = "LandGhost"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_orphan_check.call_deferred()


## A ghost nobody added to the tree by the end of the frame it was made in is freed (BUILD.md "Layers": the caller adds
## `preview_nodes`' nodes to the tree and frees them; the command tool adds them at once; 754 drops one unfreed).
func _orphan_check() -> void:
	if not is_inside_tree() and get_parent() == null:
		queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		for part: Array in _parts:
			_draw(part[0], part[1])
		_parts = []


## Triangles drawn (or to be drawn) per tint: {tint: vertex count / 3}.
func tris() -> Dictionary:
	var out := {}
	for part: Array in _parts:
		out[part[0]] = int(out.get(part[0], 0)) + (part[1] as PackedVector3Array).size() / 3
	for mi: Node in get_children():
		if mi is MeshInstance3D:
			var t := str((mi as Node).get_meta(&"tint", ""))
			out[t] = int(out.get(t, 0)) + ((mi as MeshInstance3D).mesh as ArrayMesh).surface_get_array_len(0) / 3
	return out


## `cells`: Vector2i cell -> a tint key (a palette key, or "valley" / "" for red); `height`: (x, z) -> the ground's
## height there (an invalid Callable: 0). One mesh per tint.
func show_cells(cells: Dictionary, height: Callable) -> int:
	var by := {}
	for c: Vector2i in cells:
		var k := str(cells[c])
		if not by.has(k):
			by[k] = []
		(by[k] as Array).append(c)
	for k: String in by:
		_patches(by[k], height, k)
	return cells_drawn


## Heights: `raised` and `lowered` are lists of cells; `after` and `now` the ground's height after the ops and now.
func show_heights(raised: Array, lowered: Array, after: Callable, now: Callable) -> int:
	if not raised.is_empty():
		_patches(raised, after, "holo")
	if not lowered.is_empty():
		_patches(lowered, now, "valley")
	return cells_drawn


func _patches(list: Array, height: Callable, tint: String) -> void:
	var v := PackedVector3Array()
	for c: Vector2i in list:
		var p := [Vector2(c.x, c.y), Vector2(c.x + 1, c.y), Vector2(c.x + 1, c.y + 1), Vector2(c.x, c.y + 1)]
		var q := []
		for a: Vector2 in p:
			var y: float = float(height.call(a.x * L, a.y * L)) if height.is_valid() else 0.0
			q.append(Vector3(a.x * L, y + LIFT, a.y * L))
		for t: int in [0, 2, 1, 0, 3, 2]:
			v.append(q[t])
		cells_drawn += 1
	if v.is_empty():
		return
	if is_inside_tree():
		_draw(tint, v)
	else:
		_parts.append([tint, v])


func _draw(tint: String, v: PackedVector3Array) -> void:
	var uv := PackedVector2Array()
	uv.resize(v.size())
	uv.fill(Vector2(0.5, 2.0))
	var nrm := PackedVector3Array()
	nrm.resize(v.size())
	nrm.fill(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uv
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, _look(tint))
	var mi := MeshInstance3D.new()
	mi.name = "Ghost %s" % tint
	mi.set_meta(&"tint", tint)
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## The ghost of the land layer `real`'s scratch copy `after` (a dry run): the cells round each vertex whose height the
## ops change (raised in holo at the new height, lowered in red on the ground now) and the cells whose paint they
## change (in the paint, red where it is erased). null when they change nothing.
static func of_land(real: RefCounted, after: RefCounted) -> Node3D:
	var up := {}
	var down := {}
	var keys: Dictionary = (after.store.heights as Dictionary).duplicate()
	keys.merge(real.store.heights as Dictionary)
	for v: Vector2i in keys:
		var a: int = after.cm_at(v)
		var b: int = real.cm_at(v)
		if a == b:
			continue
		for o: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO]:
			if a > b:
				up[v + o] = true
			else:
				down[v + o] = true
	var paint := {}
	var cells: Dictionary = (after.store.paints as Dictionary).duplicate()
	cells.merge(real.store.paints as Dictionary)
	for c: Vector2i in cells:
		if after.store.paint_at(c) != real.store.paint_at(c):
			paint[c] = after.store.paint_at(c)
	if up.is_empty() and down.is_empty() and paint.is_empty():
		return null
	var gh: Node3D = (load("res://kernel/world/build/land_ghost.gd") as GDScript).new()
	gh.call("show_heights", up.keys(), down.keys(), Callable(after, "height_at"), Callable(real, "height_at"))
	gh.call("show_cells", paint, Callable(after, "height_at"))
	return gh


## The holo material, or a private copy of it tinted by the palette key `tint` ("valley" or "": hazard red).
static func _look(tint: String) -> Material:
	if tint == "holo":
		return TLStyle.material("holo")
	var m: Material = TLStyle.material_instance("holo")
	if m is ShaderMaterial and not TLStyle.headless():
		var c: Color = TLStyle.color("hazard_red") if tint == "" or tint == "valley" or not TLStyle.has_key(tint) else TLStyle.color(tint)
		(m as ShaderMaterial).set_shader_parameter(&"holo", c)
		(m as ShaderMaterial).set_shader_parameter(&"edge", c.lightened(0.4))
	return m
