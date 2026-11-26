extends RefCounted
## M2 (spark world-sandbox): the valley's scatter (trees, rushes, hedges, stooks: MultiMeshes under the landscape whose
## meta "tl_xs" holds where each instance stands, terrain/village_parts.gd `multi`) follows the land. An instance whose
## ground moved by at most HIDE metres moves with it; one whose ground was lifted or lowered more is hidden (its basis
## scaled to zero), so no tree is buried to its crown or left standing in the air. Undo gives every instance its own
## transform back. The trunks the visitor bumps into follow the same rule (land_layer.gd `trunk_foot`).
## The forest belt's MultiMeshes ("WorldBelt*") are the village's (places.gd trims them, so their tl_xs is stale) and
## the village is protected: they are left out.

const HIDE := 0.5

var g: RefCounted                        # land_ground.gd
var landscape: Node3D
var by_chunk := {}                       # Vector2i -> [[MultiMesh, index, Transform3D as built], ...]
var state := {}                          # "<mm id>:<index>" -> "moved" | "hidden" (absent: as built)
var _ready := false


func _init(ground: RefCounted, parent: Node3D) -> void:
	g = ground
	landscape = parent


func _prepare() -> void:
	if _ready or landscape == null or g.flat():
		_ready = true
		return
	_ready = true
	var inner: Rect2 = g.border.grow(72.0)
	for child: Node in landscape.get_children():
		if not (child is MultiMeshInstance3D) or str(child.name).begins_with("World") or not child.has_meta(&"tl_xs"):
			continue
		var mm: MultiMesh = (child as MultiMeshInstance3D).multimesh
		var xs: Array = child.get_meta(&"tl_xs")
		if mm == null or xs.size() != mm.instance_count:
			continue
		for i: int in xs.size():
			var xf: Transform3D = xs[i]
			if inner.has_point(Vector2(xf.origin.x, xf.origin.z)):
				continue
			var id := chunk_of(xf.origin.x, xf.origin.z)
			if not by_chunk.has(id):
				by_chunk[id] = []
			(by_chunk[id] as Array).append([mm, i, xf])


## The chunk whose drawn rectangle holds (x, z) (land_ground.gd's partition).
func chunk_of(x: float, z: float) -> Vector2i:
	if g.flat():
		return Vector2i(floori(x / 96.0), floori(z / 96.0))
	return Vector2i(g.col_chunk[g.col_of(x)], g.row_chunk[g.row_of(z)])


## Every instance standing in chunk `id` as the ground is now (`delta`: (x, z) -> how far the ground moved there).
## Returns [moved, hidden] in the chunk.
func update(id: Vector2i, delta: Callable) -> Array:
	_prepare()
	var moved := 0
	var hidden := 0
	for e: Array in by_chunk.get(id, []):
		var mm: MultiMesh = e[0]
		var xf: Transform3D = e[2]
		var d: float = delta.call(xf.origin.x, xf.origin.z)
		var key := "%d:%d" % [mm.get_instance_id(), int(e[1])]
		var now := "" if d == 0.0 else ("hidden" if absf(d) > HIDE else "moved")
		if now == "moved":
			mm.set_instance_transform(int(e[1]), xf.translated(Vector3(0.0, d, 0.0)))
			moved += 1
		elif now == "hidden":
			mm.set_instance_transform(int(e[1]), Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin))
			hidden += 1
		elif state.has(key):
			mm.set_instance_transform(int(e[1]), xf)
		if now == "":
			state.erase(key)
		else:
			state[key] = now
	return [moved, hidden]


## The instances of chunk `id` and how each stands: [[origin as built, "" | "moved" | "hidden"], ...].
func report(id: Vector2i) -> Array:
	_prepare()
	var out := []
	for e: Array in by_chunk.get(id, []):
		out.append([(e[2] as Transform3D).origin, str(state.get("%d:%d" % [(e[0] as MultiMesh).get_instance_id(), int(e[1])], ""))])
	return out


## Every instance back as built (the builder leaves).
func restore() -> void:
	for id: Vector2i in by_chunk:
		for e: Array in by_chunk[id]:
			var key := "%d:%d" % [(e[0] as MultiMesh).get_instance_id(), int(e[1])]
			if state.has(key):
				(e[0] as MultiMesh).set_instance_transform(int(e[1]), e[2])
	state.clear()
