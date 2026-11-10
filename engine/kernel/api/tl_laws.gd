class_name TLLaws
extends RefCounted
## The law tables: materials (res://kernel/data/materials.json) and surface rules (res://kernel/data/surfaces.json).
## Any collision body tagged with metadata `tl_material` gets its physics from the table. Capability: `physics`.
##
## Pair law: friction = the lower of the two, restitution = the sum (at most 1), unless surfaces.json has a row for
## the pair. Bodies the kernel moves (TLBall, TLVehicle wheels, TLBiped, bodies from TLBodies.make) follow the
## pairwise overrides; a plain tagged body gets the default pair law from the physics engine.

const MATERIALS_PATH: String = "res://kernel/data/materials.json"
const SURFACES_PATH: String = "res://kernel/data/surfaces.json"
const COLUMNS: Array = ["density", "friction", "restitution", "hardness", "flammability", "sound", "breaks_into"]
const FALLBACK: String = "concrete"

static var _materials: Dictionary = {}
static var _pairs: Dictionary = {}
static var _loaded: bool = false
static var _warned: Dictionary = {}
static var impulse_per_hardness: float = 40.0


## Loads and checks both tables. Returns readable errors (empty when valid). Called by the kernel before a pack loads.
static func load_tables() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	_materials = {}
	_pairs = {}
	_loaded = true
	var mj: Variant = JSON.parse_string(FileAccess.get_file_as_string(MATERIALS_PATH))
	if typeof(mj) != TYPE_DICTIONARY or typeof((mj as Dictionary).get("materials")) != TYPE_DICTIONARY:
		errors.append("materials.json: not an object with 'materials'")
		return errors
	for k: String in (mj as Dictionary).keys():
		if not ["schema", "_doc", "impulse_per_hardness", "materials"].has(k):
			errors.append("materials.json: unknown key '%s'" % k)
	impulse_per_hardness = float((mj as Dictionary).get("impulse_per_hardness", 40.0))
	var mats: Dictionary = (mj as Dictionary)["materials"]
	for id: String in mats.keys():
		var row: Dictionary = mats[id]
		for c: String in COLUMNS:
			if not row.has(c):
				errors.append("materials.json: '%s' has no '%s'" % [id, c])
		for c: String in row.keys():
			if not COLUMNS.has(c):
				errors.append("materials.json: '%s' has an unknown column '%s'" % [id, c])
		_materials[id] = row
	for id: String in mats.keys():
		if not _materials.has(str((mats[id] as Dictionary).get("breaks_into", id))):
			errors.append("materials.json: '%s' breaks into an unknown material" % id)
	var sj: Variant = JSON.parse_string(FileAccess.get_file_as_string(SURFACES_PATH))
	if typeof(sj) != TYPE_DICTIONARY or typeof((sj as Dictionary).get("pairs")) != TYPE_ARRAY:
		errors.append("surfaces.json: not an object with 'pairs'")
		return errors
	for row: Dictionary in (sj as Dictionary)["pairs"]:
		for c: String in row.keys():
			if not ["a", "b", "friction", "restitution"].has(c):
				errors.append("surfaces.json: unknown column '%s'" % c)
		var a: String = str(row.get("a", ""))
		var b: String = str(row.get("b", ""))
		if not _materials.has(a) or not _materials.has(b):
			errors.append("surfaces.json: pair '%s' + '%s' names an unknown material" % [a, b])
			continue
		_pairs[_key(a, b)] = row
	return errors


static func _ensure() -> void:
	if not _loaded:
		for e: String in load_tables():
			push_error(e)


static func _key(a: String, b: String) -> String:
	return a + "|" + b if a <= b else b + "|" + a


## Every material id in the table.
static func ids() -> PackedStringArray:
	_ensure()
	return PackedStringArray(_materials.keys())


static func has(id: String) -> bool:
	_ensure()
	return _materials.has(id)


## One row of the table: {density, friction, restitution, hardness, flammability, sound, breaks_into}.
## An unknown id logs an error once and answers with concrete.
static func material(id: String) -> Dictionary:
	_ensure()
	if _materials.has(id):
		return _materials[id]
	if not _warned.has(id):
		_warned[id] = true
		push_error("TLLaws: unknown material '%s' (known: %s); using %s" % [id, ", ".join(ids()), FALLBACK])
	return _materials.get(FALLBACK, {"density": 2400.0, "friction": 0.75, "restitution": 0.1, "hardness": 6.5,
		"flammability": 0.0, "sound": "concrete", "breaks_into": "stone"})


## The pair law for two materials: {friction, restitution, override: bool}.
static func pair(a: String, b: String) -> Dictionary:
	_ensure()
	var ma: Dictionary = material(a)
	var mb: Dictionary = material(b)
	var out: Dictionary = {
		"friction": minf(float(ma["friction"]), float(mb["friction"])),
		"restitution": clampf(float(ma["restitution"]) + float(mb["restitution"]), 0.0, 1.0),
		"override": false,
	}
	var row: Variant = _pairs.get(_key(a, b))
	if row != null:
		out["override"] = true
		if (row as Dictionary).has("friction"):
			out["friction"] = float((row as Dictionary)["friction"])
		if (row as Dictionary).has("restitution"):
			out["restitution"] = float((row as Dictionary)["restitution"])
	return out


## The material id a collider is tagged with ("" when it has no tag).
static func material_of(node: Object) -> String:
	if node != null and node.has_meta(&"tl_material"):
		return str(node.get_meta(&"tl_material"))
	return ""


## Tags a body (when `id` is given) and sets its friction and restitution from the table. A RigidBody3D tagged with
## metadata `tl_mass_from_density` = true also gets its mass from density x shape volume. Safe to call twice.
static func apply(body: CollisionObject3D, id: String = "") -> void:
	_ensure()
	if body == null:
		return
	if id.is_empty():
		id = material_of(body)
	if id.is_empty():
		return
	var row: Dictionary = material(id)
	body.set_meta(&"tl_material", id)
	body.set_meta(&"tl_law_applied", id)
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = float(row["friction"])
	pm.bounce = float(row["restitution"])
	if body is RigidBody3D:
		(body as RigidBody3D).physics_material_override = pm
		if bool(body.get_meta(&"tl_mass_from_density", false)):
			(body as RigidBody3D).mass = maxf(0.01, float(row["density"]) * volume_of(body))
	elif body is StaticBody3D:
		(body as StaticBody3D).physics_material_override = pm


## Applies the table to every tagged body under `root` that has not had it yet. Returns how many it touched.
## The kernel calls this after `_pack_setup` and for bodies added later.
static func apply_tree(root: Node) -> int:
	var n: int = 0
	if root is CollisionObject3D and root.has_meta(&"tl_material") and not root.has_meta(&"tl_law_applied"):
		apply(root as CollisionObject3D)
		n += 1
	for c: Node in root.get_children():
		n += apply_tree(c)
	return n


## Volume in cubic metres of a body's collision shapes (convex shapes are estimated from their bounds).
static func volume_of(body: CollisionObject3D) -> float:
	var v: float = 0.0
	for c: Node in body.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
			var s: Shape3D = (c as CollisionShape3D).shape
			if s is BoxShape3D:
				var e: Vector3 = (s as BoxShape3D).size
				v += e.x * e.y * e.z
			elif s is SphereShape3D:
				v += 4.0 / 3.0 * PI * pow((s as SphereShape3D).radius, 3.0)
			elif s is CylinderShape3D:
				v += PI * pow((s as CylinderShape3D).radius, 2.0) * (s as CylinderShape3D).height
			elif s is CapsuleShape3D:
				var r: float = (s as CapsuleShape3D).radius
				v += PI * r * r * maxf(0.0, (s as CapsuleShape3D).height - 2.0 * r) + 4.0 / 3.0 * PI * r * r * r
			elif s is ConvexPolygonShape3D:
				var pts: PackedVector3Array = (s as ConvexPolygonShape3D).points
				if pts.size() > 0:
					var box: AABB = AABB(pts[0], Vector3.ZERO)
					for p: Vector3 in pts:
						box = box.expand(p)
					v += box.size.x * box.size.y * box.size.z * 0.6
	return v


## The impulse (N*s) a body of this material takes in one hit before it is damaged: hardness x impulse_per_hardness.
static func impact_threshold(id: String) -> float:
	return float(material(id)["hardness"]) * impulse_per_hardness


## Casts down from `from` and answers what is underneath: {hit: bool, material, position, normal, collider, distance}.
## `material` is "" for an untagged collider. `exclude` holds RIDs (a body's own `get_rid()`).
static func surface_under(world_node: Node3D, from: Vector3, depth: float, exclude: Array = [],
		down: Vector3 = Vector3.DOWN) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = world_node.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + down * depth)
	var rids: Array[RID] = []
	for r: Variant in exclude:
		rids.append(r as RID)
	q.exclude = rids
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return {"hit": false, "material": ""}
	return {"hit": true, "material": material_of(hit["collider"]), "position": hit["position"],
		"normal": hit["normal"], "collider": hit["collider"], "distance": (hit["position"] as Vector3).distance_to(from)}
