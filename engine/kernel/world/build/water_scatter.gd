extends RefCounted
## M5 lane W (spark world-sandbox): the valley's scatter (trees, rushes, hedges: MultiMeshes under the landscape whose
## meta "tl_xs" holds where each instance stands, as land_scatter.gd reads them) standing in poured water is hidden
## while it is under water and back when the water is drained. An instance is under water when its 3 m cell holds a
## level above the ground at its foot (land_layer.gd `height_at`) by more than WET metres.
## LOCAL FALLBACK (PATCHES-W.md W1): land_scatter.gd owns those transforms (lane L). Here an instance this file hid is
## shown again as the land would have it (land_scatter.gd's rule: moved with the ground up to HIDE m, else hidden), and
## when the land layer redraws a body (its scatter may then set a hidden instance's transform back) every instance
## hidden here is hidden again in the same frame's step. The visitor's trunk colliders are not touched (home/hook.gd
## asks only the land: PATCHES-W.md W2).

const WET := 0.05
const HIDE := 0.5                        # land_scatter.gd HIDE
const VILLAGE_BAND := 72.0

var land: RefCounted                     # land_layer.gd (read only)
var landscape: Node3D
var by_chunk := {}                       # Vector2i 96 m chunk -> [[MultiMesh, index, Transform3D as built], ...]
var hidden := {}                         # "<mm id>:<index>" -> [MultiMesh, index, Transform3D as built]
var set_to := {}                         # "<mm id>:<index>" -> the transform this file set last (a case reads it)
var _ready := false
var _land_bodies := -1                   # land stats.body_usec size at the last look


func _init(l: RefCounted, parent: Node3D) -> void:
	land = l
	landscape = parent


func _prepare() -> void:
	if _ready:
		return
	_ready = true
	if landscape == null or land == null:
		return
	var g: RefCounted = land.ground()
	if g.flat():
		return
	var inner: Rect2 = (g.border as Rect2).grow(VILLAGE_BAND)
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
			var id := Vector2i(floori(xf.origin.x / 96.0), floori(xf.origin.z / 96.0))
			if not by_chunk.has(id):
				by_chunk[id] = []
			(by_chunk[id] as Array).append([mm, i, xf])


## Every instance standing in 96 m chunk `id` as the water `levels` (Vector2i cell -> cm) is now. Returns
## [hidden now in the chunk, shown again].
func update(id: Vector2i, levels: Dictionary) -> Array:
	_prepare()
	var wet := 0
	var back := 0
	for e: Array in by_chunk.get(id, []):
		var xf: Transform3D = e[2]
		var mm: MultiMesh = e[0]
		var key := "%d:%d" % [mm.get_instance_id(), int(e[1])]
		var c := Vector2i(floori(xf.origin.x / 3.0), floori(xf.origin.z / 3.0))
		var under: bool = levels.has(c) and int(levels[c]) / 100.0 > float(land.height_at(xf.origin.x, xf.origin.z)) + WET
		if under:
			_put(key, mm, int(e[1]), Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin))
			hidden[key] = e
			wet += 1
		elif hidden.has(key):
			hidden.erase(key)
			_put(key, mm, int(e[1]), _as_land(xf))
			back += 1
	return [wet, back]


func _put(key: String, mm: MultiMesh, i: int, xf: Transform3D) -> void:
	mm.set_instance_transform(i, xf)
	set_to[key] = xf


## What land_scatter.gd would show for an instance built at `xf` (its rule, read from the land's delta).
func _as_land(xf: Transform3D) -> Transform3D:
	var d: float = land.delta_at(xf.origin.x, xf.origin.z)
	if absf(d) > HIDE:
		return Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin)
	return xf.translated(Vector3(0.0, d, 0.0)) if d != 0.0 else xf


## Once a frame (the water layer's step): when the land layer redrew a body since the last look, its scatter may have
## shown an instance hidden here; hide them all again.
func keep() -> void:
	if land == null or hidden.is_empty():
		return
	var n := int((land.get("stats") as Dictionary).get("body_usec", []).size()) if land.get("stats") is Dictionary else 0
	if n == _land_bodies:
		return
	_land_bodies = n
	for key: String in hidden:
		var e: Array = hidden[key]
		_put(key, e[0], int(e[1]), Transform3D(Basis.from_scale(Vector3.ZERO), (e[2] as Transform3D).origin))


## The instances of chunk `id`: [[origin as built, hidden here?], ...] (a case reads it).
func report(id: Vector2i) -> Array:
	_prepare()
	var out := []
	for e: Array in by_chunk.get(id, []):
		out.append([(e[2] as Transform3D).origin, hidden.has("%d:%d" % [(e[0] as MultiMesh).get_instance_id(), int(e[1])])])
	return out


## Every instance hidden here shown again as the land has it (the builder leaves).
func restore() -> void:
	for key: String in hidden:
		var e: Array = hidden[key]
		_put(key, e[0], int(e[1]), _as_land(e[2]))
	hidden.clear()
