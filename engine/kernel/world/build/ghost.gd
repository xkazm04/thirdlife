extends Node3D
## WP2 (spark world-sandbox, M1): build mode's preview of the next edit, a hologram in the cell the cursor names.
##   place     the selected shape, material, rot and flip, in the style's holo look, with the cell's edges
##   refused   the same, red: the hotbar says why (build_mode.gd `reason`)
##   remove    a red cube with edges round the block a right click takes away
## The shape's triangles are the mesher's own (shapes.gd `entry`, form 0: a joined corner is not previewed), so the
## ghost is what the block will be. Kernel code: the holo material comes from the style (TLStyle.material("holo") and a
## private copy tinted with the palette's `hazard_red`); no hand-made material. Moved per drawn frame (build_mode.gd
## `_process`), so it is left out of physics interpolation.

const Shapes := preload("res://kernel/world/build/shapes.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const EDGE := 0.03                      # metres: the edge bars' thickness
const GROW := 0.015                     # metres the preview stands out of its cell (no flicker against a neighbour)

var shown := ""                         # "" hidden, "place", "refused", "remove"
var cell := Vector3i.ZERO
var code := 0
var _fill: MeshInstance3D
var _edge: MeshInstance3D
var _ok: Material
var _bad: Material
var _meshes := {}                       # code -> ArrayMesh of the shape (the preview of a place)
var _cube: ArrayMesh = null             # the preview of a remove


func _init() -> void:
	name = "BuildGhost"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ok = TLStyle.material("holo")
	_bad = TLStyle.material_instance("holo")
	if _bad is ShaderMaterial and not TLStyle.headless():
		var red := TLStyle.color("hazard_red")
		(_bad as ShaderMaterial).set_shader_parameter(&"holo", red)
		(_bad as ShaderMaterial).set_shader_parameter(&"edge", red.lightened(0.4))
	_fill = _instance("Fill")
	_edge = _instance("Edges")
	_edge.mesh = _outline()
	visible = false


func _instance(n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(mi)
	return mi


## Shows the preview at `c`: `mode` "place" or "refused" (the shape of `c_code`), or "remove" (a cube).
func show_at(c: Vector3i, c_code: int, mode: String) -> void:
	if shown == mode and cell == c and code == c_code:
		return
	shown = mode
	cell = c
	code = c_code
	position = Vector3(c)
	_fill.mesh = _shape(c_code) if mode != "remove" else _cube_mesh()
	var m: Material = _ok if mode == "place" else _bad
	_fill.material_override = m
	_edge.material_override = m
	visible = true


func hide_ghost() -> void:
	shown = ""
	visible = false


func _shape(c: int) -> ArrayMesh:
	if _meshes.has(c):
		return _meshes[c]
	var e: Shapes.Entry = Shapes.entry(Shapes.key_of(c, 0), Blocks.mat_of(c))
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	for s: int in 7:
		v.append_array(e.v[s])
		n.append_array(e.n[s])
		v.append_array(e.gv[s])
		n.append_array(e.gn[s])
	var centre := Vector3.ONE * 0.5
	for i: int in v.size():
		v[i] = centre + (v[i] - centre) * (1.0 + 2.0 * GROW)
	var m := _mesh(v, n, 2.0)
	_meshes[c] = m
	return m


func _cube_mesh() -> ArrayMesh:
	if _cube == null:
		var v := PackedVector3Array()
		var n := PackedVector3Array()
		_box(v, n, Vector3.ONE * -GROW, Vector3.ONE * (1.0 + GROW))
		_cube = _mesh(v, n, 2.0)
	return _cube


## The 12 edges of the cell as thin bars (UV y 0: holo.gdshader draws them as its bright edge lines).
func _outline() -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var lo := -GROW - EDGE * 0.5
	var hi := 1.0 + GROW + EDGE * 0.5
	for ax: int in 3:
		for a: float in [lo, hi - EDGE]:
			for b: float in [lo, hi - EDGE]:
				var mn := Vector3.ZERO
				var mx := Vector3.ZERO
				var u := (ax + 1) % 3
				var w := (ax + 2) % 3
				mn[ax] = lo
				mx[ax] = hi
				mn[u] = a
				mx[u] = a + EDGE
				mn[w] = b
				mx[w] = b + EDGE
				_box(v, n, mn, mx)
	return _mesh(v, n, 0.0)


## A box's 12 triangles, Godot's winding (clockwise seen from outside).
static func _box(v: PackedVector3Array, n: PackedVector3Array, mn: Vector3, mx: Vector3) -> void:
	for ax: int in 3:
		for side: int in 2:
			var nrm := Vector3.ZERO
			nrm[ax] = 1.0 if side == 1 else -1.0
			var u := (ax + 1) % 3
			var w := (ax + 2) % 3
			var q := []
			for k: Array in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var p := Vector3.ZERO
				p[ax] = mx[ax] if side == 1 else mn[ax]
				p[u] = mx[u] if k[0] == 1 else mn[u]
				p[w] = mx[w] if k[1] == 1 else mn[w]
				q.append(p)
			var tri := [q[0], q[2], q[1], q[0], q[3], q[2]] if side == 1 else [q[0], q[1], q[2], q[0], q[2], q[3]]
			for p: Vector3 in tri:
				v.append(p)
				n.append(nrm)


static func _mesh(v: PackedVector3Array, n: PackedVector3Array, uv_y: float) -> ArrayMesh:
	var m := ArrayMesh.new()
	if v.is_empty():
		return m
	var uv := PackedVector2Array()
	uv.resize(v.size())
	uv.fill(Vector2(0.0, uv_y))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
