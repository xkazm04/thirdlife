extends RefCounted
## P4. The world's own physics space, and the visitor's body in it.
##
## A pack is simulated in a space of its own and must stay untouched. The visitor is not part of any game: he walks the
## land between them, so the WORLD owns a space (`PhysicsServer3D`, no nodes, no scene tree) that holds only static
## things, all of them built once:
##   * the terrain's triangles (a triangle is left out where a plot's own ground carries him instead),
##   * a wall round every plot's fence, trunks of trees, boulders, the lots' machinery, the bridge,
##   * for every plot: a COPY of the pack's static colliders (add_pack): the shapes are shared (a shape belongs to no
##     space), the bodies are new bodies in this space, clipped to the plot's circle and moved to the plot's place with
##     the same bent rim the draw layer gives the pack's ground. The pack's own bodies are never touched.
## His own body is a kinematic capsule in that space; `walk()` moves it with the engine's test_motion (slide along what
## he meets, step up small steps, follow slopes down, refuse slopes steeper than `max_slope_deg`).
##
## Nothing here is read by a pack, a scheduler or a state hash: the scripted tour still gives the scheduler the
## scripted position; the body only decides where the visitor is DRAWN (and, when a person walks, where he is).

const RADIUS: float = 0.35
const HEIGHT: float = 1.8

var space: RID = RID()
var body: RID = RID()
var stats: Dictionary = {"bodies": 0, "faces": 0, "boxes": 0, "trunks": 0, "boulders": 0, "pack_shapes": 0, "pack_faces": 0}
var max_slope_deg: float = 55.0
var step_up: float = 0.55
var blocked_ticks: int = 0
var _bodies: Array = []
var _tags: Dictionary = {}           # body RID -> what it is (for the one line that says what stopped him)
var tag: String = ""                  # set by the builder: the tag of the bodies made next
var last_hit: Dictionary = {}
var _keep: Array = []                 # Shape3D resources that must outlive their bodies
var _cap: CapsuleShape3D = null
var _params: PhysicsTestMotionParameters3D = PhysicsTestMotionParameters3D.new()
var _res: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
var _cyl: Dictionary = {}             # radius key -> CylinderShape3D (shared by every trunk of that size)
var _spheres: Dictionary = {}


func _init() -> void:
	space = PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(space, true)
	_cap = CapsuleShape3D.new()
	_cap.radius = RADIUS
	_cap.height = HEIGHT
	body = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_KINEMATIC)
	PhysicsServer3D.body_set_space(body, space)
	PhysicsServer3D.body_add_shape(body, _cap.get_rid(), Transform3D(Basis(), Vector3(0.0, HEIGHT * 0.5, 0.0)))
	PhysicsServer3D.body_set_collision_layer(body, 2)          # the visitor is layer 2; the static things are layer 1
	PhysicsServer3D.body_set_collision_mask(body, 1)
	_params.margin = 0.03
	_params.max_collisions = 4
	_params.recovery_as_collision = false


## Called when everything static is in: the space holds no moving body, so it need not be stepped (queries still work).
func finish() -> void:
	PhysicsServer3D.space_set_active(space, false)


func free_all() -> void:
	for b: Variant in _bodies:
		PhysicsServer3D.free_rid(b as RID)
	_bodies.clear()
	if body.is_valid():
		PhysicsServer3D.free_rid(body)
		body = RID()
	if space.is_valid():
		PhysicsServer3D.free_rid(space)
		space = RID()
	_keep.clear()


func _static(shape: Shape3D, xf: Transform3D) -> void:
	var b: RID = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(b, space)
	PhysicsServer3D.body_add_shape(b, shape.get_rid(), xf)
	PhysicsServer3D.body_set_collision_layer(b, 1)
	PhysicsServer3D.body_set_collision_mask(b, 0)
	_bodies.append(b)
	_tags[b] = tag
	stats["bodies"] = int(stats["bodies"]) + 1


func add_faces(faces: PackedVector3Array) -> void:
	if faces.size() < 3:
		return
	var sh: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	sh.backface_collision = true
	sh.set_faces(faces)
	_keep.append(sh)
	_static(sh, Transform3D.IDENTITY)
	stats["faces"] = int(stats["faces"]) + faces.size() / 3


func add_box(xf: Transform3D, size: Vector3) -> void:
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	_keep.append(sh)
	_static(sh, xf)
	stats["boxes"] = int(stats["boxes"]) + 1


## A trunk: a cylinder standing on `foot`.
func add_trunk(foot: Vector3, radius: float, height: float = 4.0) -> void:
	var key: String = "%.2f_%.1f" % [radius, height]
	if not _cyl.has(key):
		var c: CylinderShape3D = CylinderShape3D.new()
		c.radius = radius
		c.height = height
		_cyl[key] = c
	_static(_cyl[key] as Shape3D, Transform3D(Basis(), foot + Vector3(0.0, height * 0.5, 0.0)))
	stats["trunks"] = int(stats["trunks"]) + 1


func add_boulder(centre: Vector3, radius: float) -> void:
	var key: String = "%.2f" % radius
	if not _spheres.has(key):
		var s: SphereShape3D = SphereShape3D.new()
		s.radius = radius
		_spheres[key] = s
	_static(_spheres[key] as Shape3D, Transform3D(Basis(), centre))
	stats["boulders"] = int(stats["boulders"]) + 1


## A wall of thin quads along a polyline of ground points: `height` metres tall from each point's own y. `closed`: the
## last point joins the first. Gaps are made by calling this once per stretch.
func add_wall(pts: PackedVector3Array, height: float) -> void:
	var faces: PackedVector3Array = PackedVector3Array()
	for i: int in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var a2: Vector3 = a + Vector3(0.0, height, 0.0)
		var b2: Vector3 = b + Vector3(0.0, height, 0.0)
		faces.append_array(PackedVector3Array([a, b, b2, a, b2, a2]))
	if faces.size() > 0:
		var sh: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		sh.backface_collision = true
		sh.set_faces(faces)
		_keep.append(sh)
		_static(sh, Transform3D.IDENTITY)
		stats["boxes"] = int(stats["boxes"]) + 1


## The static colliders of a pack, copied into the world's space (see the header). `plot`: the plot's transform in
## world coordinates (lift included), `radius`: the drawn circle, `rim`: the pack's own height at the plot edge in its
## own coordinates and `band`: the width over which the draw layer bends its ground to that height. Only
## StaticBody3D (a frozen rigid body is not copied); a concave shape (terrain) is clipped to the circle and bent like
## the drawn ground, every other shape is copied whole when its body stands inside the circle and is lifted by
## the amount the draw layer lifts something standing there.
func add_pack(holder: Node3D, plot: Transform3D, radius: float, rim: float, band: float) -> void:
	var inv: Transform3D = holder.global_transform.affine_inverse()
	_add_pack_walk(holder, holder, inv, plot, radius, rim, band)


func _bent(p: Vector3, radius: float, rim: float, band: float) -> Vector3:
	var r: float = Vector2(p.x, p.z).length()
	if band > 0.0 and radius > 0.0:
		p.y += (rim - p.y) * smoothstep(radius - band, radius, r)
	return p


func _add_pack_walk(n: Node, holder: Node3D, inv: Transform3D, plot: Transform3D, radius: float, rim: float, band: float) -> void:
	if n is StaticBody3D and (n as StaticBody3D).get_child_count() > 0:
		var sb: StaticBody3D = n
		for ch: Node in sb.get_children():
			if not (ch is CollisionShape3D) or (ch as CollisionShape3D).disabled or (ch as CollisionShape3D).shape == null:
				continue
			var cs: CollisionShape3D = ch
			var local: Transform3D = inv * cs.global_transform           # the shape in the pack's own coordinates
			var sh: Shape3D = cs.shape
			if sh is ConcavePolygonShape3D:
				var src: PackedVector3Array = (sh as ConcavePolygonShape3D).get_faces()
				var out: PackedVector3Array = PackedVector3Array()
				var r2: float = (radius + 4.0) * (radius + 4.0)
				var t: int = 0
				while t + 2 < src.size():
					var a: Vector3 = local * src[t]
					var b: Vector3 = local * src[t + 1]
					var c: Vector3 = local * src[t + 2]
					t += 3
					var cx: float = (a.x + b.x + c.x) / 3.0
					var cz: float = (a.z + b.z + c.z) / 3.0
					if radius > 0.0 and cx * cx + cz * cz > r2:
						continue
					out.append(plot * _bent(a, radius, rim, band))
					out.append(plot * _bent(b, radius, rim, band))
					out.append(plot * _bent(c, radius, rim, band))
				if out.size() > 0:
					var ns: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
					ns.backface_collision = true
					ns.set_faces(out)
					_keep.append(ns)
					_static(ns, Transform3D.IDENTITY)
					stats["pack_faces"] = int(stats["pack_faces"]) + out.size() / 3
			else:
				if radius > 0.0 and Vector2(local.origin.x, local.origin.z).length() > radius + 2.0:
					continue
				var lifted: Transform3D = local
				if band > 0.0 and radius > 0.0:
					lifted.origin = _bent(local.origin, radius, rim, band)
				_static(sh, plot * lifted)
				stats["pack_shapes"] = int(stats["pack_shapes"]) + 1
	for c: Node in n.get_children():
		_add_pack_walk(c, holder, inv, plot, radius, rim, band)


# ------------------------------------------------------------------------------------------------ the body
func _test(from: Transform3D, motion: Vector3) -> bool:
	_params.from = from
	_params.motion = motion
	return PhysicsServer3D.body_test_motion(body, _params, _res)


## Puts the body at `pos` (feet), unchecked.
func place(pos: Vector3) -> void:
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis(), pos))


## Moves the body from `from` (feet) by the horizontal `delta`. Slides along what it meets, steps up small steps,
## follows the ground down; a move that would end on a slope steeper than `max_slope_deg` is refused (he stays).
## Returns the new feet position. `blocked` says whether anything held him back this tick.
func walk(from: Vector3, delta: Vector3) -> Dictionary:
	var pos: Vector3 = from
	last_hit = {}
	var rest: Vector3 = Vector3(delta.x, 0.0, delta.z)
	var hit: bool = false
	# lift by the step height, move horizontally (slide up to three times), then drop to the ground
	var up: Vector3 = Vector3(0.0, step_up, 0.0)
	if _test(Transform3D(Basis(), pos), up):
		up = _res.get_travel()
	pos += up
	for it: int in 3:
		if rest.length() < 0.0005:
			break
		if _test(Transform3D(Basis(), pos), rest):
			hit = true
			last_hit = {"tag": _tags.get(_res.get_collider_rid(0), "?"), "at": _res.get_collision_point(0), "n": _res.get_collision_normal(0), "from": pos}
			var travel: Vector3 = _res.get_travel()
			pos += travel
			var rem: Vector3 = _res.get_remainder()
			var nrm: Vector3 = _res.get_collision_normal(0)
			nrm.y = 0.0
			rest = rem - nrm.normalized() * rem.dot(nrm.normalized()) if nrm.length() > 0.001 else Vector3.ZERO
		else:
			pos += rest
			rest = Vector3.ZERO
	var drop: float = up.y + 0.9
	var grounded: bool = false
	var ground_n: Vector3 = Vector3.UP
	if _test(Transform3D(Basis(), pos), Vector3(0.0, -drop, 0.0)):
		pos += _res.get_travel()
		ground_n = _res.get_collision_normal(0)
		grounded = true
	else:
		pos.y -= drop                               # nothing under him within reach: a ledge; he steps down by the reach
	var slope_ok: bool = not grounded or ground_n.y >= cos(deg_to_rad(max_slope_deg))
	if not slope_ok:
		# refuse: the move ends on something too steep to stand on; stay where he was
		hit = true
		pos = from
		if _test(Transform3D(Basis(), pos), Vector3(0.0, -0.6, 0.0)):
			pos += _res.get_travel()
	if hit:
		blocked_ticks += 1
	place(pos)
	return {"pos": pos, "blocked": hit, "grounded": grounded}


## The ground height under (x, z), looking down from `from_y`: NAN when there is none within 400 m.
func ground_at(x: float, z: float, from_y: float) -> float:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, from_y - 400.0, z), 1)
	var hit: Dictionary = PhysicsServer3D.space_get_direct_state(space).intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else NAN
