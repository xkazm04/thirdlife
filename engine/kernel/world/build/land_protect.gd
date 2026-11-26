extends RefCounted
## M2 (spark world-sandbox): where the Home's ground may not be sculpted or painted (contracts/BUILD.md "More
## operations": the village, game sites, lanes, the river band, columns that hold blocks, the visitor). The land layer
## adds `rule` to protect.gd as an "area" rule; protect.gd asks its own circles, rectangles and boxes first (the walk's
## game plots, the site footprints). Reasons, short and stable (the hotbar shows them):
##   "outside the Home"                beyond the valley's drawn extent
##   "village"                         the village's rectangle and 72 m round it (the valley blends into it there)
##   "game lot"                        a site's footprint and 34 m round it (the pad's blend, valley.gd `height`)
##   "lane"                            within 12 m of a lane, its verge or the bridge deck (home/hook.gd `lanes`)
##   "river"                           within 71 m of the river's line: the water ribbon is 136 m wide and clipped by
##                                     the ground's depth, so a hollow there would fill with a river that is not there
##   "field"                           (land only) a ploughed parcel: its furrows are one mesh and cannot follow
##   "authored structure (<name>)"     a house, the mill, a stall, the hoist, a flag, a gate, a portal, a sign: every
##                                     drawn thing of the valley that is not ground or scatter (found in the scene)
##   "blocks"                          a column that holds a block (the ground under it would bury or float it)
##   "too close"                       the visitor stands there
## Nothing is protected on flat ground (a builder without a valley) except blocks and the visitor.

const VILLAGE_BAND := 72.0
const SITE_BAND := 34.0
const LANE_BAND := 12.0
const RIVER_BAND := 71.0
const LANE_CELL := 24.0
const FURROWED := ["dirt", "grass_dry", "sand"]
const GROUND_NAMES := ["WrenValley", "WrenWater", "ValleyLanes", "ValleyGreens", "Furrows", "HomeBlocks", "HomeLand",
	"HomeBuildMode", "WorldFarGround", "WorldMesas", "WorldMesaPines"]
const STRUCTURE_MAX := 160.0             # metres: a drawn thing wider than this is ground or a whole area, not a structure

var g: RefCounted                        # land_ground.gd
var blocks: RefCounted                   # blocks.gd (read only)
var protect: RefCounted                  # protect.gd (the visitor)
var landscape: Node3D = null             # where the valley's things hang (the structures are looked for there)
var height_at: Callable                  # (x, z) -> the ground's height now (land_layer.gd)
var _ready := false
var _lanes := {}                         # Vector2i cell (LANE_CELL m) -> [PackedVector2Array triangle, ...]
var _things := []                        # [Vector2 centre, radius, name]
var _columns: Variant = null             # a batch's block columns: [Rect2, {Vector2i: true}] (`begin_batch`)


func _init(ground: RefCounted, store: RefCounted, p: RefCounted, parent: Node3D) -> void:
	g = ground
	blocks = store
	protect = p
	landscape = parent


## The protect.gd "area" rule: why the ground in `rect` may not take `what` ("land" or "paint"), "" when it may.
func rule(rect: Rect2, what: String) -> String:
	if not g.flat():
		_prepare()
		var why := _valley(rect, what)
		if why != "":
			return why
	if _has_blocks(rect):
		return "blocks"
	if _visitor_in(rect):
		return "too close"
	return ""


## Block columns of `rect` are read once for the calls that follow (a brush stroke's vertices), until `end_batch`.
func begin_batch(rect: Rect2) -> void:
	_columns = [rect, _block_columns(rect)]


func end_batch() -> void:
	_columns = null


# ------------------------------------------------------------------ the valley's areas
func _valley(rect: Rect2, what: String) -> String:
	var v: RefCounted = g.valley
	var lim: float = float(v.LIMIT) - 96.0
	if rect.position.x < -lim or rect.position.y < -lim or rect.end.x > lim or rect.end.y > lim:
		return "outside the Home"
	if g.border.grow(VILLAGE_BAND).intersects(rect):
		return "village"
	var reach := rect.size.length() * 0.5
	var mid := rect.get_center()
	for s: Dictionary in v.sites:
		var local := (mid - Vector2(float(s.centre[0]), float(s.centre[1]))).rotated(deg_to_rad(float(s.get("yaw", 0.0))))
		if absf(local.x) <= float(s.footprint[0]) * 0.5 + SITE_BAND + reach and absf(local.y) <= float(s.footprint[1]) * 0.5 + SITE_BAND + reach:
			return "game lot"
	for z: float in [rect.position.y, mid.y, rect.end.y]:
		var rx: float = v.river_x(z)
		if maxf(0.0, maxf(rect.position.x - rx, rx - rect.end.x)) < RIVER_BAND:
			return "river"
	if _near_lane(rect):
		return "lane"
	if what == "land":
		for p: Vector2 in [mid, rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
			var parcel: Dictionary = v.parcel_at(p.x, p.y)
			if not parcel.is_empty() and str(parcel.get("soil", "")) in FURROWED:
				return "field"
	for t: Array in _things:
		var c: Vector2 = t[0]
		if c.clamp(rect.position, rect.end).distance_to(c) <= float(t[1]):
			return "authored structure (%s)" % str(t[2])
	return ""


func _near_lane(rect: Rect2) -> bool:
	var big := rect.grow(LANE_BAND)
	var reach := rect.size.length() * 0.5 + LANE_BAND
	var mid := rect.get_center()
	for cz: int in range(floori(big.position.y / LANE_CELL), floori(big.end.y / LANE_CELL) + 1):
		for cx: int in range(floori(big.position.x / LANE_CELL), floori(big.end.x / LANE_CELL) + 1):
			for t: PackedVector2Array in _lanes.get(Vector2i(cx, cz), []):
				if Geometry2D.point_is_inside_triangle(mid, t[0], t[1], t[2]):
					return true
				for e: int in 3:
					if Geometry2D.get_closest_point_to_segment(mid, t[e], t[(e + 1) % 3]).distance_to(mid) <= reach:
						return true
	return false


## Once: the lanes' triangles by cell, and the valley's structures (every drawn node under the landscape that is not
## ground, water, lanes, scatter or the village's, by its drawn bounds).
func _prepare() -> void:
	if _ready:
		return
	_ready = true
	var lanes: Dictionary = g.hook.get("lanes")
	for id: Vector2i in lanes:
		var f: PackedVector3Array = lanes[id]
		for t: int in range(0, f.size() - 2, 3):
			var tri := PackedVector2Array([Vector2(f[t].x, f[t].z), Vector2(f[t + 1].x, f[t + 1].z), Vector2(f[t + 2].x, f[t + 2].z)])
			var box := Rect2(tri[0], Vector2.ZERO).expand(tri[1]).expand(tri[2])
			for cz: int in range(floori(box.position.y / LANE_CELL), floori(box.end.y / LANE_CELL) + 1):
				for cx: int in range(floori(box.position.x / LANE_CELL), floori(box.end.x / LANE_CELL) + 1):
					var k := Vector2i(cx, cz)
					if not _lanes.has(k):
						_lanes[k] = []
					(_lanes[k] as Array).append(tri)
	if landscape == null:
		return
	var inner: Rect2 = (g.border as Rect2).grow(VILLAGE_BAND)
	for child: Node in landscape.get_children():
		# a drawn thing of the valley: a kit part (meta tl_kind) or a mesh of its own (TLMesh `instance`); never the visitor,
		# build mode or anything else that moves
		var drawn: bool = child is MeshInstance3D or child.has_meta(&"tl_kind")
		if not drawn or str(child.name) in GROUND_NAMES or str(child.name).begins_with("World"):
			continue
		var box := _bounds(child as Node3D)
		if box.size == Vector3.ZERO:
			continue
		var r := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		if r.size.x > STRUCTURE_MAX or r.size.y > STRUCTURE_MAX or inner.encloses(r):
			continue
		_things.append([r.get_center(), r.size.length() * 0.5 + 2.0, str(child.get_meta(&"tl_kind")) if child.has_meta(&"tl_kind") else str(child.name)])


static func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array = [n]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		if x is VisualInstance3D and not (x is MultiMeshInstance3D):
			var b: AABB = (x as VisualInstance3D).global_transform * (x as VisualInstance3D).get_aabb()
			if b.size != Vector3.ZERO:
				box = b if first else box.merge(b)
				first = false
		stack.append_array(x.get_children())
	return box


func things() -> Array:
	_prepare()
	return _things


# ------------------------------------------------------------------ blocks and the visitor
func _has_blocks(rect: Rect2) -> bool:
	if blocks == null or int(blocks.total) == 0:
		return false
	var cols: Dictionary
	if _columns != null and (_columns[0] as Rect2).encloses(rect):
		cols = _columns[1]
	else:
		cols = _block_columns(rect)
	for z: int in range(floori(rect.position.y), ceili(rect.end.y)):
		for x: int in range(floori(rect.position.x), ceili(rect.end.x)):
			if cols.has(Vector2i(x, z)):
				return true
	return false


## The columns (x, z) of `rect` that hold a block: every section the rect meets is read once.
func _block_columns(rect: Rect2) -> Dictionary:
	var out := {}
	if blocks == null or int(blocks.total) == 0:
		return out
	var sec: int = blocks.sec
	for sz: int in range(floori(rect.position.y / sec), floori((rect.end.y - 0.001) / sec) + 1):
		for sx: int in range(floori(rect.position.x / sec), floori((rect.end.x - 0.001) / sec) + 1):
			var d: Variant = (blocks.sections as Dictionary).get(Vector2i(sx, sz))
			if d == null:
				continue
			for idx: int in d:
				var lx := idx % sec
				var lz := (idx / sec) % sec
				out[Vector2i(sx * sec + lx, sz * sec + lz)] = true
	return out


func _visitor_in(rect: Rect2) -> bool:
	if protect == null:
		return false
	var feet: Variant = null
	if (protect.visitor_at as Callable).is_valid():
		feet = protect.visitor_at.call()
	elif protect.ws != null and (protect.ws.get("body") as RID).is_valid():
		feet = (PhysicsServer3D.body_get_state(protect.ws.get("body"), PhysicsServer3D.BODY_STATE_TRANSFORM) as Transform3D).origin
	if not (feet is Vector3):
		return false
	var f: Vector3 = feet
	var r := 0.4 if protect.ws == null else float(protect.ws.get("walker_radius")) + 0.05
	if not rect.grow(r).has_point(Vector2(f.x, f.z)):
		return false
	var under: float = height_at.call(f.x, f.z) if height_at.is_valid() else f.y
	return f.y - under < 26.0                # 24 m of land and a body: higher up he flies over it
