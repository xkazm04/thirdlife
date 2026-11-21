extends SceneTree
## Night of 21 Nov 2026, lane L1: what the `harden.*` cases of harden_case.gd share (split from it at landing for
## the arch size budget; behaviour unchanged): the village built as in a window, the visitor walked by frames, the
## drawn rails found in their meshes, where he would start, and the stubs of a construction site. harden_case.gd
## extends this script; nothing here prints a case line.


const Landscape: GDScript = preload("res://kernel/world/landscape.gd")
const Space: GDScript = preload("res://kernel/world/terrain/world_space.gd")

const WALK: float = 4.5          # m/s, world_body.gd WALK_MPS
const TICKS: int = 70
const SUB: float = 0.5           # metres between two looks along a row of rails


class Viewer extends Node:
	var world: Node = null
	var landscape: Node3D = Node3D.new()


class World extends Node:
	var packs: Array = []
	var walk: Dictionary = {}


var _walk: Dictionary = {}
var _land: Node3D = null
var _ws: RefCounted = null
var _terr: RefCounted = null
var _road: TLKitPath = null
var _half: float = 3.0
var _tris: Dictionary = {}       # cell key -> PackedVector3Array of triangles (rail meshes)
const CELL: float = 4.0


func _line(name: String, why: Array, ok_detail: String) -> void:
	print("HARDEN %s %s %s" % [name, "ok" if why.is_empty() else "fail", ok_detail if why.is_empty() else "; ".join(why)])


# ------------------------------------------------------------------------------------------------ the village
func _build_village(path: String = "") -> void:
	var walk_path: String = path if not path.is_empty() else OS.get_environment("TL_HARDEN_WALK")      # another walk's village (a clip's), for a look
	_walk = JSON.parse_string(FileAccess.get_file_as_string(walk_path if not walk_path.is_empty() else "res://boot/village.json"))
	if _land != null:
		_land.get_parent().queue_free()        # the village before (its space is freed when it leaves the tree)
	_tris = {}
	var view: Viewer = Viewer.new()
	var world: World = World.new()
	world.walk = _walk
	view.world = world
	root.add_child(view)
	view.add_child(world)
	view.add_child(view.landscape)
	_land = view.landscape
	var plots: Array = []
	var radii: Array = []
	var has_ground: Array = []
	var footprints: Array[Vector2] = []
	for p: Dictionary in _walk["plots"]:
		var o: Array = p["origin"]
		plots.append(Transform3D(Basis(), Vector3(float(o[0]), float(o[1]), float(o[2]))))
		radii.append(float(p["radius"]))
		has_ground.append(false)
		var fp: Variant = (p.get("footprint", {}) as Dictionary).get("size_m", null)
		footprints.append(Vector2(float(fp[0]), float(fp[1])) if fp is Array else Vector2.ONE * float(p["radius"]) * 2.0)
	var cfg: Dictionary = (_walk["landscape"] as Dictionary).duplicate(true)
	cfg["road"] = _walk["road"]
	cfg["footprints"] = footprints
	cfg["edges_now"] = true
	_half = float(cfg.get("road_half_m", 2.6))
	Landscape.call("build", _land, plots, radii, has_ground, cfg)
	_ws = _land.get_meta(&"tl_space")
	_terr = _land.get_meta(&"tl_terrain")
	var cps: Array = []
	for q: Variant in _walk["road"]:
		cps.append(Vector2(float((q as Array)[0]), float((q as Array)[1])))
	_road = TLKitPath.new(cps, false, 2.0)


## Walks the body from `from` (x, z; the ground gives y) with the wish `dir` * WALK for `ticks`; returns the feet.
func _walk_from(from: Vector2, dir: Vector2, ticks: int = TICKS, space: RefCounted = null) -> Vector3:
	var ws: RefCounted = space if space != null else _ws
	var g: float = float(ws.call("ground_at", from.x, from.y, 200.0))
	var feet: Vector3 = Vector3(from.x, 0.0 if is_nan(g) else g, from.y)
	ws.call("place", feet)
	ws.call("rest")
	var wish: Vector3 = Vector3(dir.x, 0.0, dir.y).normalized() * WALK
	for t: int in ticks:
		feet = (ws.call("drive", feet, wish, false, false) as Dictionary)["pos"]
	return feet


func _what_stopped(space: RefCounted = null) -> String:
	var ws: RefCounted = space if space != null else _ws
	return str((ws.get("last_hit") as Dictionary).get("tag", "-")) if ws.get("last_hit") is Dictionary else "-"


# ------------------------------------------------------------------------------------------------ rails
func _index_rails() -> int:
	var n: int = 0
	for c: Node in _land.get_children():
		if c is MeshInstance3D and str(c.name).begins_with("WorldRoadRails"):
			var f: PackedVector3Array = ((c as MeshInstance3D).mesh as ArrayMesh).get_faces()
			var xf: Transform3D = (c as MeshInstance3D).transform
			for t: int in range(0, f.size(), 3):
				var a: Vector3 = xf * f[t]
				var b: Vector3 = xf * f[t + 1]
				var d: Vector3 = xf * f[t + 2]
				var lo: Vector2 = Vector2(minf(a.x, minf(b.x, d.x)), minf(a.z, minf(b.z, d.z)))
				var hi: Vector2 = Vector2(maxf(a.x, maxf(b.x, d.x)), maxf(a.z, maxf(b.z, d.z)))
				for cx: int in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
					for cz: int in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
						var k: Vector2i = Vector2i(cx, cz)
						var cell: PackedVector3Array = _tris.get(k, PackedVector3Array())     # a packed array is a value: set it back
						cell.append_array(PackedVector3Array([a, b, d]))
						_tris[k] = cell
				n += 1
	return n


## Is a rail drawn across the row at `p` (the short line across it, `n` its outward normal, at heights from 0.3 m under
## the land to 3.0 m over it: a row on a road bank carries its rails up to the road's edge)?
func _drawn(p: Vector2, n: Vector2) -> bool:
	var k: Vector2i = Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var gy: float = float(_terr.call("gy", p.x, p.y))
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			var tr: Variant = _tris.get(k + Vector2i(dx, dz), null)
			if tr == null:
				continue
			var t: PackedVector3Array = tr
			for h: int in 34:
				var y: float = gy - 0.3 + 0.1 * float(h)
				var a: Vector3 = Vector3(p.x - n.x * 0.4, y, p.y - n.y * 0.4)
				var b: Vector3 = Vector3(p.x + n.x * 0.4, y, p.y + n.y * 0.4)
				for i: int in range(0, t.size(), 3):
					if Geometry3D.segment_intersects_triangle(a, b, t[i], t[i + 1], t[i + 2]) != null:
						return true
	return false


## The drawn row along both sides of the road: per hand [[pos, outward normal, drawn], ...] every SUB metres.
func _rail_looks() -> Array:
	_index_rails()
	var off: float = TLStyle.num("detail", "road_rails", 0.0)
	var pts: PackedVector2Array = _road.pts
	var looks: Array = []          # per hand: [[pos, normal, drawn], ...] along the row
	for hand: float in [-1.0, 1.0]:
		var row: Array = []
		for i: int in range(1, pts.size() - 1):
			var tang: Vector2 = (pts[i + 1] - pts[i - 1]).normalized()
			var nrm: Vector2 = tang.orthogonal() * hand
			var a: Vector2 = pts[i] + nrm * (_half + off)
			var tang2: Vector2 = (pts[mini(i + 2, pts.size() - 1)] - pts[i]).normalized()
			var b: Vector2 = pts[i + 1] + tang2.orthogonal() * hand * (_half + off)
			var steps: int = maxi(1, int(a.distance_to(b) / SUB))
			for s: int in steps:
				var p: Vector2 = a.lerp(b, float(s) / float(steps))
				row.append([p, nrm, _drawn(p, nrm)])
		looks.append(row)
	return looks


## A place to walk into: drawn unbroken a metre either side; one every 4 m. [pos, normal, what he would start on: the
## top body 2 m inside the row ("terrain" on the road)].
func _rail_places(looks: Array) -> Array:
	var out: Array = []
	var last: Vector2 = Vector2.INF
	for row: Array in looks:
		for k: int in range(2, row.size() - 2):
			var all: bool = true
			for j: int in range(k - 2, k + 3):
				all = all and bool(row[j][2])
			if not all or (row[k][0] as Vector2).distance_to(last) < 4.0:
				continue
			last = row[k][0]
			var p: Vector2 = row[k][0]
			var n: Vector2 = row[k][1]
			out.append([p, n, _top_tag(p - n * 2.0, 200.0)])
	return out


## Walks into every place of `_rail_places`: [tried, crossed (lines), started on something else than the land (lines)].
func _walk_rails(places: Array) -> Array:
	var crossed: Array = []
	var on_top: Array = []
	for pl: Array in places:
		var p: Vector2 = pl[0]
		var n: Vector2 = pl[1]
		if str(pl[2]) != "terrain":
			on_top.append("(%.1f, %.1f) on %s" % [p.x, p.y, str(pl[2])])
		var f: Vector3 = _walk_from(p - n * 2.0, n)
		var past: float = (Vector2(f.x, f.z) - p).dot(n)
		if past > 0.3:
			crossed.append("(%.1f, %.1f) %.1f m beyond" % [p.x, p.y, past])
	return [places.size(), crossed, on_top]


## Would a bush's cylinder of radius `rad` at `c` reach onto the main road or a spur (village_parts.gd `bush_solids` leaves
## those walk-through)? The spurs as landscape.gd lays them: from each plot's and lot's edge to the nearest road sample.
func _on_road(c: Vector2, rad: float) -> bool:
	for q: Vector2 in _road.pts:
		if q.distance_to(c) < _half + rad:
			return true
	var centres: Array = []
	var radii: Array = []
	for p: Dictionary in _walk["plots"]:
		centres.append(Vector2(float(p["origin"][0]), float(p["origin"][2])))
		radii.append(float(p["radius"]))
	for l: Dictionary in (_walk["landscape"] as Dictionary).get("lots", []):
		centres.append(Vector2(float(l["at"][0]), float(l["at"][1])))
		radii.append(float(l.get("radius", 20.0)))
	for i: int in centres.size():
		var best: int = 0
		for q: int in _road.pts.size():
			if _road.pts[q].distance_squared_to(centres[i]) < _road.pts[best].distance_squared_to(centres[i]):
				best = q
		var from: Vector2 = centres[i] + (_road.pts[best] - centres[i]).normalized() * (float(radii[i]) + 0.5)
		if Geometry2D.get_closest_point_to_segment(c, from, _road.pts[best]).distance_to(c) < _half + rad + 1.0:
			return true
	return false


# ------------------------------------------------------------------------------------------------ a construction site's sign
class SiteView extends RefCounted:
	var view: Dictionary = {"stage": "building", "title": "Test", "arrived": false, "radius": 32.0, "job_state": "running",
		"packages": [{"id": "p1", "title": "One", "state": "running", "merged": false}], "total": 1, "built": 0}
	func view_of(_lot: int) -> Dictionary:
		return view


class FlatGround extends RefCounted:
	func gy(_x: float, _z: float) -> float:
		return 0.0


# ------------------------------------------------------------------------------------------------ where he is put
func _clear_at(at: Vector2, from_y: float) -> String:
	var g: float = float(_ws.call("ground_at", at.x, at.y, from_y))
	var gy: float = float(_terr.call("gy", at.x, at.y))
	if is_nan(g):
		return "no ground"
	if g - gy > 0.25:
		return "put %.2f m above the land, on %s" % [g - gy, _top_tag(at, from_y)]
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis(), Vector3(at.x, g + 0.95, at.y))
	q.collision_mask = 1
	q.exclude = [_ws.get("body")]
	var hits: Array = PhysicsServer3D.space_get_direct_state(_ws.get("space")).intersect_shape(q, 4)
	var tags: Array = []
	for h: Dictionary in hits:
		tags.append(str((_ws.get("_tags") as Dictionary).get(h["rid"], "?")))
	return "" if tags.is_empty() else "his capsule meets %s" % ", ".join(tags)


func _top_tag(at: Vector2, from_y: float) -> String:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(at.x, from_y, at.y), Vector3(at.x, from_y - 400.0, at.y), 1)
	q.exclude = [_ws.get("body")]
	var hit: Dictionary = PhysicsServer3D.space_get_direct_state(_ws.get("space")).intersect_ray(q)
	return str((_ws.get("_tags") as Dictionary).get(hit.get("rid", RID()), "?")) if not hit.is_empty() else "nothing"
