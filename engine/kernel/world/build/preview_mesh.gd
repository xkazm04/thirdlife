extends Node3D
## SEAM (spark world-sandbox): draws a blocks.gd store as a hologram, the ghost of a dry run (home_build.gd `preview`):
## M4's answer before the player accepts it, M3's stamp before it is placed. The cells are meshed by the Home's own
## mesher (block_mesh.gd, no space: no body, no collision) and drawn in the style's holo material; the blocks a dry run
## would take away are drawn in a red copy of it (as ghost.gd). No hand-made material. Kernel code, no input.
##   var p := PreviewMesh.new(); landscape.add_child(p)
##   var r: Dictionary = build.preview(ops); p.show_stores(r.store, r.removed)    # p.clear() to hide it
## Moved and redrawn only when told; left out of physics interpolation.

const BlockMesh := preload("res://kernel/world/build/block_mesh.gd")

var shown := false
var _ok: Material
var _bad: Material
var _add: RefCounted = null             # block_mesh.gd of the cells added
var _rem: RefCounted = null             # block_mesh.gd of the cells removed
var _hold_add: Node3D
var _hold_rem: Node3D


func _init() -> void:
	name = "BuildPreview"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ok = TLStyle.material("holo")
	_bad = TLStyle.material_instance("holo")
	if _bad is ShaderMaterial and not TLStyle.headless():
		var red := TLStyle.color("hazard_red")
		(_bad as ShaderMaterial).set_shader_parameter(&"holo", red)
		(_bad as ShaderMaterial).set_shader_parameter(&"edge", red.lightened(0.4))
	_hold_add = Node3D.new()
	_hold_add.name = "Added"
	add_child(_hold_add)
	_hold_rem = Node3D.new()
	_hold_rem.name = "Removed"
	add_child(_hold_rem)


## Draws `store` (the blocks that would be there) in holo and `removed` (the blocks that would go) in red. Returns
## the triangles drawn.
func show_stores(store: RefCounted, removed: RefCounted = null) -> int:
	clear()
	_add = _draw(store, _hold_add, _ok)
	if removed != null:
		_rem = _draw(removed, _hold_rem, _bad)
	shown = true
	return int(stats().tris)


func _draw(store: RefCounted, holder: Node3D, look: Material) -> RefCounted:
	var m: RefCounted = BlockMesh.new(store, holder, null)
	m.look = look
	for s: Vector2i in store.sections:
		store.dirty[s] = true
	while store.dirty.size() > 0:
		m.step(1 << 20)
	return m


func clear() -> void:
	for m: RefCounted in [_add, _rem]:
		if m != null:
			m.free_all()
	_add = null
	_rem = null
	shown = false


## {"sections", "tris"} drawn now.
func stats() -> Dictionary:
	var n := 0
	var t := 0
	for m: RefCounted in [_add, _rem]:
		if m == null:
			continue
		n += (m.tris as Dictionary).size()
		for s: Vector2i in m.tris:
			t += int(m.tris[s])
	return {"sections": n, "tris": t}
