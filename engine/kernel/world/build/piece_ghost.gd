extends Node3D
## M3 (spark world-sandbox, 26 Nov 2026): pieces drawn as a hologram, the ghost of the next put (tools/piece_tool.gd)
## and of a stamp's pieces (tools/stamp_tool.gd). Each piece is its prototype's meshes (piece_catalog.gd `proto`) in
## the style's holo material, or in a private copy tinted `hazard_red` when refused (as ghost.gd); a lift's target is
## shown red. No hand-made material. Moved per drawn frame, so it is left out of physics interpolation.
##   g.show_pieces([[proto, xf], ...], refused)    g.hide_ghost()

var shown := false
var key := ""                           # what is shown now (redrawn only when it changes)
var _ok: Material
var _bad: Material
var _pool: Array = []                   # MeshInstance3D children, reused


func _init() -> void:
	name = "PieceGhost"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ok = TLStyle.material("holo")
	_bad = TLStyle.material_instance("holo")
	if _bad is ShaderMaterial and not TLStyle.headless():
		var red := TLStyle.color("hazard_red")
		(_bad as ShaderMaterial).set_shader_parameter(&"holo", red)
		(_bad as ShaderMaterial).set_shader_parameter(&"edge", red.lightened(0.4))
	visible = false


## Shows `items` ([proto, Transform3D] pairs), red when `refused`. `k` names what is shown: the same `k` again does
## nothing.
func show_pieces(items: Array, refused: bool, k := "") -> void:
	var want := "%s|%s" % [k, refused] if k != "" else ""
	if want != "" and want == key and shown:
		return
	key = want
	var n := 0
	for it: Array in items:
		var pr: Dictionary = it[0]
		for m: Array in pr.meshes:
			var mi: MeshInstance3D
			if n < _pool.size():
				mi = _pool[n]
			else:
				mi = MeshInstance3D.new()
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
				add_child(mi)
				_pool.append(mi)
			mi.mesh = ghost_mesh(m[0])
			mi.transform = (it[1] as Transform3D) * (m[1] as Transform3D)
			mi.material_override = _bad if refused else _ok
			mi.visible = true
			n += 1
	for i: int in range(n, _pool.size()):
		(_pool[i] as MeshInstance3D).visible = false
	shown = n > 0
	visible = shown


static var _ghosts := {}                # kit mesh -> its ghost copy


## A kit mesh as the holo shader wants a fill: the same triangles with UV (0.5, 2) on every vertex. The kit's UVs
## carry its own surface data, which holo.gdshader reads as edge lines and dissolve fronts (the first try drew a lamp
## as a white glare, red or not); ghost.gd fills its cells the same way (UV y 2: the faint fill, no lines).
static func ghost_mesh(m: Mesh) -> Mesh:
	if _ghosts.has(m):
		return _ghosts[m]
	var out := ArrayMesh.new()
	for s: int in m.get_surface_count():
		var arr: Array = m.surface_get_arrays(s)
		var n: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var keep := []
		keep.resize(Mesh.ARRAY_MAX)
		keep[Mesh.ARRAY_VERTEX] = arr[Mesh.ARRAY_VERTEX]
		keep[Mesh.ARRAY_NORMAL] = arr[Mesh.ARRAY_NORMAL]
		keep[Mesh.ARRAY_INDEX] = arr[Mesh.ARRAY_INDEX]
		var uv := PackedVector2Array()
		uv.resize(n)
		uv.fill(Vector2(0.5, 2.0))
		keep[Mesh.ARRAY_TEX_UV] = uv
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, keep)
	_ghosts[m] = out
	return out


func hide_ghost() -> void:
	if shown:
		for mi: MeshInstance3D in _pool:
			mi.visible = false
	shown = false
	key = ""
	visible = false
