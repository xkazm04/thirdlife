extends RefCounted
## WP1: where a block may not go (spark world-sandbox, W3 Q3: land and own builds are editable; authored structures
## and game lots are protected). `refusal(cell)` gives the first reason that applies, "" when the cell is free:
##   "game lot"                      a game plot of the walk (boot/village.json plots: the footprint square and the
##                                   drawn circle), a construction-site lot (landscape.lots), a Home site (valley.gd
##                                   sites: the footprint turned by its yaw)
##   "authored structure (<tag>)"    any static body of the visitor's space the cell would overlap that is not ground:
##                                   the mill, bridges, walls, rails, rocks, signs, a landmark, a copied pack collider
##                                   (asked of the space itself, so nothing authored has to be listed here)
##   "tree"                          a valley trunk (they ride on the Home's ground chunks, home/hook.gd)
##   "too close"                     the cell overlaps the visitor's capsule
##   anything added by add_circle / add_rect / add_box, with its own reason
## The space knows only what is loaded round the visitor (KEEP chunks of home/hook.gd): building happens there.

const GROUND_TAGS := ["terrain", "home ground", "home blocks"]
const MARGIN := 0.05                    # metres round the visitor's capsule

var circles := []                       # [Vector2 centre, radius, reason]
var rects := []                         # [Vector2 centre, Vector2 half size, yaw (rad), reason]
var boxes := []                         # [AABB, reason]
var ws: Object = null                   # the visitor's WorldSpace (walker_space.gd): its body is the visitor's capsule
var visitor_at: Callable                # () -> Vector3, the visitor's feet; the owner sets it (visit.gd holds where he
                                        # is: `drive` moves no body). Unset: the body's transform (`place`, `walk`)
var _box := BoxShape3D.new()
var _q := PhysicsShapeQueryParameters3D.new()


func _init(space: Object = null) -> void:
	ws = space
	_box.size = Vector3.ONE * 0.98
	_q.shape = _box
	_q.collision_mask = 1
	_q.collide_with_areas = false


func add_circle(centre: Vector2, radius: float, reason: String) -> void:
	circles.append([centre, radius, reason])


func add_rect(centre: Vector2, size: Vector2, yaw_deg: float, reason: String) -> void:
	rects.append([centre, size * 0.5, deg_to_rad(yaw_deg), reason])


func add_box(box: AABB, reason: String) -> void:
	boxes.append([box, reason])


## The walk's game plots and site lots (a boot/village.json document).
func from_walk(walk: Dictionary) -> void:
	for p: Variant in walk.get("plots", []):
		if typeof(p) != TYPE_DICTIONARY or typeof((p as Dictionary).get("origin")) != TYPE_ARRAY:
			continue
		var o: Array = p.origin
		var c := Vector2(float(o[0]), float(o[2]))
		add_circle(c, float(p.get("radius", 0.0)), "game lot")
		var fp: Variant = (p as Dictionary).get("footprint", {})
		if typeof(fp) == TYPE_DICTIONARY and typeof((fp as Dictionary).get("size_m")) == TYPE_ARRAY:
			add_rect(c, Vector2(float(fp.size_m[0]), float(fp.size_m[1])), 0.0, "game lot")
	var land: Variant = walk.get("landscape", {})
	if typeof(land) == TYPE_DICTIONARY:
		for lot: Variant in (land as Dictionary).get("lots", []):
			if typeof(lot) == TYPE_DICTIONARY and typeof((lot as Dictionary).get("at")) == TYPE_ARRAY:
				add_circle(Vector2(float(lot.at[0]), float(lot.at[1])), float(lot.get("radius", 0.0)), "game lot")


## The Home's sites (valley.gd `sites`: the greens its games and dungeon doors stand on).
func from_sites(sites: Array) -> void:
	for s: Dictionary in sites:
		add_rect(Vector2(float(s.centre[0]), float(s.centre[1])), Vector2(float(s.footprint[0]), float(s.footprint[1])), float(s.get("yaw", 0.0)), "game lot")


## `_code`: the block that would go there (edit_log.gd `check` passes it; no rule reads it yet).
func refusal(cell: Vector3i, _code := 0) -> String:
	var lo := Vector2(cell.x, cell.z)
	var hi := lo + Vector2.ONE
	var mid := lo + Vector2(0.5, 0.5)
	for c: Array in circles:
		var p: Vector2 = (c[0] as Vector2).clamp(lo, hi)
		if p.distance_to(c[0]) <= float(c[1]):
			return c[2]
	for r: Array in rects:
		var local := (mid - (r[0] as Vector2)).rotated(float(r[2]))
		var half: Vector2 = r[1]
		if absf(local.x) <= half.x + 0.71 and absf(local.y) <= half.y + 0.71:
			return r[3]
	var box := AABB(Vector3(cell) + Vector3.ONE * 0.01, Vector3.ONE * 0.98)
	for b: Array in boxes:
		if (b[0] as AABB).intersects(box):
			return b[1]
	if ws == null:
		return ""
	var body: RID = ws.get("body")
	if body.is_valid() or visitor_at.is_valid():
		var feet: Vector3 = visitor_at.call() if visitor_at.is_valid() else (PhysicsServer3D.body_get_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM) as Transform3D).origin
		var r: float = float(ws.get("walker_radius")) + MARGIN
		var capsule := AABB(feet - Vector3(r, MARGIN, r), Vector3(2.0 * r, float(ws.get("walker_height")) + 2.0 * MARGIN, 2.0 * r))
		if capsule.intersects(box):
			return "too close"
	var space: RID = ws.get("space")
	if not space.is_valid():
		return ""
	_q.transform = Transform3D(Basis.IDENTITY, Vector3(cell) + Vector3.ONE * 0.5)
	_q.exclude = [body] if body.is_valid() else []
	var tags: Dictionary = ws.get("_tags")
	for hit: Dictionary in PhysicsServer3D.space_get_direct_state(space).intersect_shape(_q, 16):
		var tag := str(tags.get(hit.rid, ""))
		if tag == "home ground" and int(hit.shape) > 0:
			return "tree"
		if not GROUND_TAGS.has(tag) and not tag.begins_with("pad "):
			return "authored structure (%s)" % (tag if tag != "" else "untagged")
	return ""
