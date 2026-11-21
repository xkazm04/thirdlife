extends SceneTree
## Day of 21 Nov 2026, lane L6 (crisp-harden): `harden.kit_tops` of tools/selftest.d/700-harden-day.sh. Headless, no
## frames stepped (the spaces hold only static bodies, queried directly).
## Every kit part (TLKit.list(), its defaults; VARIANTS for parts whose bodies follow their numbers), straight and turned
## 30 degrees: rays straight down on a grid over its footprint meet the drawn mesh (every visible MeshInstance3D's
## triangles) and its colliders (every CollisionShape3D of a static body: what a game's balls and the world's visitor
## meet). Per column the collider's top must be the mesh's top within TOL: higher is a ledge in the air (a wall he
## walks into before he reaches what he sees, a floor over a roof), lower is a hole (he walks into a footing; a thing
## put on it sinks). Stacked: a column counts only when every column within FOOT/2 of it does too, so what is
## measured is what a thing FOOT wide stood on the part meets (a crack between two planks does not count).
## A part whose picture and body differ on purpose names it in ALLOW, with why; every part is held to MAX_SHARE.
## Prints `HARDEN harden.kit_tops ok|fail <detail>`; TL_KIT_TOPS_DEBUG=1 prints a line per part.

const TOL: float = 0.12
const MAX_SHARE: float = 0.03       # columns that may differ (edges of slanted or rounded pieces on the grid)

var _debug: bool = OS.get_environment("TL_KIT_TOPS_DEBUG") == "1"


func _initialize() -> void:
	call_deferred("_run")


func _xf(root_: Node3D, n: Node3D) -> Transform3D:
	return root_.global_transform.affine_inverse() * n.global_transform


func _collect(root_: Node3D, n: Node, faces: PackedVector3Array, shapes: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).is_visible_in_tree() and (n as MeshInstance3D).mesh != null:
		var x: Transform3D = _xf(root_, n as Node3D)
		for v: Vector3 in (n as MeshInstance3D).mesh.get_faces():
			faces.append(x * v)
	if n is CollisionShape3D and not (n as CollisionShape3D).disabled and (n as CollisionShape3D).shape != null and n.get_parent() is StaticBody3D:
		shapes.append([(n as CollisionShape3D).shape, _xf(root_, n as Node3D)])
	for c: Node in n.get_children():
		_collect(root_, c, faces, shapes)


func _space(faces: PackedVector3Array, shapes: Array, xf: Transform3D) -> RID:     # its one body is freed with it (`_free`)
	var sp: RID = PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(sp, true)
	var b: RID = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(b, sp)
	if not faces.is_empty():
		var cp: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		cp.backface_collision = true
		cp.set_faces(faces)
		_keep.append(cp)
		PhysicsServer3D.body_add_shape(b, cp.get_rid(), xf)
	for s: Array in shapes:
		PhysicsServer3D.body_add_shape(b, (s[0] as Shape3D).get_rid(), xf * (s[1] as Transform3D))
	_bodies[sp] = b
	return sp


var _bodies: Dictionary = {}


func _free(sp: RID) -> void:
	PhysicsServer3D.free_rid(_bodies[sp] as RID)
	_bodies.erase(sp)
	PhysicsServer3D.free_rid(sp)


var _keep: Array = []


func _top(sp: RID, x: float, z: float, hi: float, lo: float) -> float:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, hi, z), Vector3(x, lo, z))
	q.hit_back_faces = true
	var hit: Dictionary = PhysicsServer3D.space_get_direct_state(sp).intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else -INF


## [columns that meet anything, phantoms, holes, the worst lines]: mesh `m` and collider `c` spaces over `box`. A
## column counts as a phantom (or a hole) only when every column round it within FOOT does too: what a thing FOOT
## wide stood on it would meet (a crack between two planks, a grid line along a rounded edge, are not counted).
const FOOT: float = 0.25
func _columns(m: RID, c: RID, box: AABB) -> Array:
	var step: float = maxf(0.08, maxf(box.size.x, box.size.z) / 140.0)
	var hi: float = box.end.y + 1.0
	var lo: float = box.position.y - 1.0
	var nx: int = int((box.size.x + 0.4) / step) + 1
	var nz: int = int((box.size.z + 0.4) / step) + 1
	var state: PackedByteArray = PackedByteArray()          # 0 none, 1 match, 2 phantom, 3 hole
	state.resize(nx * nz)
	var gap: PackedFloat32Array = PackedFloat32Array()
	gap.resize(nx * nz)
	var n: int = 0
	for i: int in nx:
		for j: int in nz:
			var x: float = box.position.x - 0.2 + float(i) * step
			var z: float = box.position.z - 0.2 + float(j) * step
			var mt: float = _top(m, x, z, hi, lo)
			var ct: float = _top(c, x, z, hi, lo)
			if mt == -INF and ct == -INF:
				continue
			n += 1
			var mm: float = mt if mt > -INF else box.position.y
			var cc: float = ct if ct > -INF else box.position.y
			state[i * nz + j] = 2 if cc > mm + TOL else (3 if mm > cc + TOL else 1)
			gap[i * nz + j] = cc - mm
	var k: int = maxi(1, ceili(FOOT * 0.5 / step))
	var ph: int = 0
	var ho: int = 0
	var worst: Array = [0.0, "", 0.0, ""]
	for i: int in range(k, nx - k):
		for j: int in range(k, nz - k):
			var s0: int = state[i * nz + j]
			if s0 < 2:
				continue
			var all: bool = true
			for di: int in range(-k, k + 1):
				for dj: int in range(-k, k + 1):
					all = all and state[(i + di) * nz + j + dj] == s0
			if not all:
				continue
			var g: float = gap[i * nz + j]
			var at: String = "(%.2f, %.2f) body %s mesh by %.2f m" % [box.position.x - 0.2 + float(i) * step, box.position.z - 0.2 + float(j) * step, "over" if s0 == 2 else "under", absf(g)]
			if s0 == 2:
				ph += 1
				if g > float(worst[0]):
					worst[0] = g
					worst[1] = at
			else:
				ho += 1
				if -g > float(worst[2]):
					worst[2] = -g
					worst[3] = at
	return [n, ph, ho, worst]


## Parts whose picture and body differ on purpose: kind -> {"holes" | "phantom": why}. Everything else is held to MAX_SHARE.
const ALLOW: Dictionary = {
	"arch_rib": {"holes": "its footings are its only collision (KIT.md): the rib stands out of reach"},
	"crane": {"holes": "the mast and its base are solid; the jib, counter-jib, hoist and load hang out of reach"},
	"tree": {"holes": "collision is the trunk only (KIT.md): its crown is out of reach"},
	"light_mast": {"holes": "the pole is solid; its lamp head is out of reach"},
	"entrance": {"holes": "the opening between its two piers stays walkable: the lintel over it is not solid"},
	"goal": {"phantom": "the net's top is one flat box at 0.85 of the crossbar where the drawn net slopes to 0.62 of it; the hockey lanes play this goal today and its body moves their hashes (left to them)"},
}
## More than the defaults for the parts whose bodies are built from their numbers (21 Nov L6).
const VARIANTS: Array = [["barricade", {"width": 3.2}], ["house", {"width": 12.0, "depth": 8.0, "wall_h": 4.0, "roof_rise": 4.0}],
	["timber_frame", {"width": 10.0, "depth": 7.0, "height": 4.0, "roof_rise": 3.0}]]


func _run() -> void:
	TLStyle.set_headless(true)
	var why: Array = []
	var parts: int = 0
	var cols: int = 0
	var allowed: Array = []
	var builds: Array = []
	for kind: String in TLKit.list():
		builds.append([kind, {}])
	builds.append_array(VARIANTS)
	for bp: Array in builds:
		var kind: String = bp[0]
		var part: Node3D = TLKit.build(kind, bp[1])
		if part == null:
			why.append("%s: did not build" % kind)
			continue
		root.add_child(part)
		var faces: PackedVector3Array = PackedVector3Array()
		var shapes: Array = []
		_collect(part, part, faces, shapes)
		if faces.is_empty() or shapes.is_empty():
			if _debug:
				print("KITTOPS %-14s faces %d shapes %d: skipped (nothing drawn or nothing solid)" % [kind, faces.size() / 3, shapes.size()])
			part.free()
			continue
		parts += 1
		var bb: AABB = AABB(faces[0], Vector3.ZERO)
		for v: Vector3 in faces:
			bb = bb.expand(v)
		var lines: Array = []
		var allow: Dictionary = ALLOW.get(kind, {})
		for yaw: float in [0.0, 30.0]:
			var xf: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), Vector3.ZERO)
			var ms: RID = _space(faces, [], xf)
			var cs: RID = _space(PackedVector3Array(), shapes, xf)
			var got: Array = _columns(ms, cs, xf * bb)
			_free(ms)
			_free(cs)
			cols += int(got[0])
			var n: float = maxf(1.0, float(got[0]))
			var ph: float = float(got[1]) / n
			var ho: float = float(got[2]) / n
			lines.append("yaw %d: %d cols, phantom %.1f%% (%s), holes %.1f%% (%s)" % [int(yaw), int(got[0]), 100.0 * ph, got[3][1], 100.0 * ho, got[3][3]])
			var name: String = kind + ("" if (bp[1] as Dictionary).is_empty() else str(bp[1]))
			if ph > MAX_SHARE and not allow.has("phantom"):
				why.append("%s turned %d: its body stands over its mesh in %.0f%% of its columns, e.g. %s" % [name, int(yaw), 100.0 * ph, got[3][1]])
			if ho > MAX_SHARE and not allow.has("holes"):
				why.append("%s turned %d: its mesh stands over its body in %.0f%% of its columns, e.g. %s" % [name, int(yaw), 100.0 * ho, got[3][3]])
		for k: String in allow:
			if not allowed.has(kind + " " + k):
				allowed.append(kind + " " + k)
		if _debug:
			print("KITTOPS %-14s %s" % [kind, " | ".join(lines)])
		part.free()
	print("HARDEN harden.kit_tops %s " % ("ok" if why.is_empty() else "fail") + ("%d parts straight and turned 30 degrees, %d columns: every body top within %.2f m of its mesh top (a %.2f m foot; allowed by name: %s)" % [parts, cols, TOL, FOOT, ", ".join(allowed)] if why.is_empty() else "; ".join(why)))
	quit()
