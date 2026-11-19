extends Node3D
## The draw layer of a world, layer 1 of 4 (draw_base.gd < draw_pictures.gd < draw_life.gd < draw.gd; the layers are
## one class split over four files, each extends the one before; `draw.gd` is the script a world instantiates and
## has the description). This file: every constant and variable of the layer, and the helpers that need nothing else.


const NEVER: float = 16384.0
const PLOT: StringName = &"tl_plot"
const WATCH: int = 24
const CLIP: StringName = &"tl_clip"

var mech: String = "a"
var cull: String = "auto"
var far_mode: String = "off"            # off | auto | all
var far_dist: float = 150.0
var far_margin: float = 0.15            # hysteresis: far beyond dist * (1 + m), near again inside dist * (1 - m)
var rim_band: float = NAN                # an explicit width in metres overrides the radius-dependent default
var rim_material: ShaderMaterial        # this landscape's vertex colours, shared by its live and cached terrain
var grounds: Array = []                 # walker-feel T2: per plot, the pack has ground of its own (view.gd `has_ground`)
var standin_min: float = 1.2            # metres: a mesh instance whose longest side is shorter is dropped ("still")
# P6: the pictures of a far game (draw/FAR.md has the study these numbers come from)
var mid_min: float = 2.5                # "mid": instances shorter than this are clutter at 100 m and more
var far_min: float = 5.0                # "far": only the forms that make the skyline and the plan
var far_cell: float = 6.0               # "far": the pack's own ground is re-meshed on a grid of this size (0 = kept as it is)
var far_flat: float = 0.0               # "far": how far every normal leans to straight up (P6 had 0.5; P13: 0, the tone of the middle picture, so the change does not show)
var far_thin: float = 0.1               # "far": a triangle narrower than this is a thin member (rail, wire, lattice): dropped (0 = kept)
var far_small: float = 0.4              # "far": a triangle whose longest edge is shorter is small detail: dropped (0 = kept)
var picture_far_m: float = 240.0        # camera to plot edge: beyond it the far picture (tiers.json `picture_far_m` when present)
var picture_margin_m: float = 30.0      # hysteresis both ways (tiers.json `margin_m.picture` when present)
var force_picture: String = ""          # "still" | "mid" | "far": every far pack shows this picture (TL_DRAW_PICTURE)
var marks_max: int = 400                # moving bodies of one pack that get a mark
var mark_min: float = 0.45              # metres: a mark is never smaller (a ball, a puck)
var far_mark_scale: float = 1.6         # a mark in the far picture is this much larger, so it stays a visible fleck
var far_shadow_m: float = 300.0        # P13: camera to plot edge: nearer, the far picture casts a shadow (style shadow_max)
var mark_shadow_m: float = 120.0       # P13: camera to plot edge: nearer, the marks cast a shadow (a figure's is a few pixels)
var mid_lights: int = 4                 # lights of a pack kept in its "mid" picture (the strongest)
var smoke_max: int = 2                  # particle emitters of a pack copied into its far pictures
var stage: int = 0
var world: Node = null
var entries: Array = []                 # one Dictionary per pack
var scenario: RID
var sync_usec: PackedInt64Array = PackedInt64Array()
var _pending: Array = []
var _shader_ok: Dictionary = {}         # Shader -> bool (declares tl_plot)
var _pal: Material = null
var _mark: ArrayMesh = null             # P6: the unit box every mark is an instance of
const PlotFile: GDScript = preload("res://kernel/world/plotfile.gd")
const PIC_VERSION: int = 15             # P13: part of the picture cache's key; count it up when a picture's rules change (T2: 14; bugfix-37 D13: 15)
var pic_worker: bool = true             # P13: pictures are merged on a worker (false: in the frame, as P6 did)
var _dir_hashes: Dictionary = {}        # P13: pack directory -> content hash (the picture cache's key)
var _cache_tasks: Array = []            # P13: picture cache writes in flight
var _figure: ArrayMesh = null          # P13: the unit figure the mark of a rig is an instance of
var _pal_cols: Dictionary = {}          # P6: palette column -> colour
var _motion: Array = []                 # P13: camera keys [[world tick, from, to], ..] (TL_DRAW_CAMERA): the motion study
var _motion_cam: Camera3D = null        # P13: the camera those keys drive; drawing only
var notes: Array = []                   # P14: what this layer did in the frame ("what ms"), drained by view.gd per frame


func _note(what: String, t0: int) -> void:
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	if ms >= 1.0:
		notes.append("%s %.1f" % [what, ms])
var HIDDEN: Transform3D = Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3(0.0, -20000.0, 0.0))
var stats: Dictionary = {"a_instances": 0, "mirrors": 0, "light_mirrors": 0, "foreign": 0, "foreign_names": [], "late": 0}


## The clip parameter of a pack (toon.gdshader `tl_clip`): radius, rim height, width of the bent band.
func _clip_v4(e: Dictionary, g: Node) -> Vector4:
	if not e.has("sheets"):
		var wide: Array = []
		_wide_meshes(e["holder"], maxf(30.0, float(e["radius"])), wide)
		e["sheets"] = wide
	var w: float = (1.0 if (e["sheets"] as Array).has(g) else 0.0) + (2.0 if reaches_in(e["holder"], g, float(e["radius"])) else 0.0)
	return Vector4(float(e["radius"]), float(e["rim"]), _band(e), w)


## The picture builder can keep a slab that overlaps the plot. Its merged instance is centred on the plot.
## Live instances still use the shader's origin cut, including those with the overlap bit set in tl_clip.w.
static func reaches_in(holder: Node, g: Node, radius: float) -> bool:
	if radius <= 0.0 or not (g is GeometryInstance3D) or not (holder is Node3D):
		return false
	var xf: Transform3D = (holder as Node3D).global_transform.affine_inverse() * (g as Node3D).global_transform
	if Vector2(xf.origin.x, xf.origin.z).length() <= radius:
		return false
	var bb: AABB = xf * (g as GeometryInstance3D).get_aabb()
	var cx: float = clampf(0.0, bb.position.x, bb.end.x)          # the box's nearest point to the plot centre
	var cz: float = clampf(0.0, bb.position.z, bb.end.z)
	return Vector2(cx, cz).length() < radius


## Larger terrain sheets have room for the rim to meet the pad over several mesh cells.
static func rim_width(radius: float, configured: float) -> float:
	return clampf(radius * 0.25, 9.0, 16.0) if is_nan(configured) else configured


## Walker-feel T2: the width of the bent band of plot `e`. Only a pack with ground of its own is bent at its rim (its
## ground meets the world's there); a pack without one (ex_car, the hockey arena: the world's pad lies under it) is
## drawn as it is built: before, its wide meshes (the arena's stands) were bent down toward height 0 in the last 9 m.
## TL_RIM_BEND=all: as before (before pictures).
func _band(e: Dictionary) -> float:
	return rim_width(float(e.get("radius", 0.0)), rim_band) if bool(e.get("ground", true)) or OS.get_environment("TL_RIM_BEND") == "all" else 0.0


## Bind the village palette only where the pack used the shared toon palette. The actual disc cut and all
## cached mesh data stay pack-local. Record a live sheet's overrides so unplacing it restores the pack.
func _dress_ground(e: Dictionary, mi: MeshInstance3D, live: bool) -> void:
	if rim_material == null or mi.mesh == null or (live and not e["ground"]):
		return
	var whole := mi.material_override != null
	var dressed := false
	for s: int in (1 if whole else mi.mesh.get_surface_count()):
		var base := mi.get_active_material(s)
		var mat: ShaderMaterial
		if e["ground"] and base == _pal:
			mat = rim_material
		elif not e["ground"] and base != _pal and base is ShaderMaterial and (base as ShaderMaterial).shader == (_pal as ShaderMaterial).shader:
			mat = _picture_floor_material(e, mi.mesh as ArrayMesh, s, base)
		if mat == null:
			continue
		if live:
			e["dressed"].append([mi, -1 if whole else s, base if whole else mi.get_surface_override_material(s)])
		if whole:
			mi.material_override = mat
		else:
			mi.set_surface_override_material(s, mat)
		dressed = true
	if dressed:
		var plot: Transform3D = e["plot"]
		mi.set_instance_shader_parameter(&"tl_land_plot", Vector4(plot.origin.x, plot.origin.z, plot.basis.x.x, plot.basis.x.z))


## A merged picture retains its floor box corners in plot coordinates. Dress only that existing surface.
func _picture_floor_material(e: Dictionary, mesh: ArrayMesh, surface: int, base: ShaderMaterial) -> ShaderMaterial:
	if mesh == null or mesh.surface_get_array_len(surface) > 24:
		return null
	var points: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
	if points.size() < 4:
		return null
	var box := AABB(points[0], Vector3.ZERO)
	for p: Vector3 in points:
		box = box.expand(p)
	var radius := float(e["radius"])
	if absf(box.end.y - float(e["rim"])) > 0.05 or box.size.y > 1.2 or minf(box.size.x, box.size.z) < radius:
		return null
	if Vector2(box.get_center().x, box.get_center().z).length() <= radius:
		return null
	for p: Vector3 in points:
		var dx := minf(absf(p.x - box.position.x), absf(p.x - box.end.x))
		var dz := minf(absf(p.z - box.position.z), absf(p.z - box.end.z))
		if maxf(dx, dz) > 0.01:
			return null
	var mat := ShaderMaterial.new()
	mat.shader = rim_material.shader
	mat.set_shader_parameter(&"pal_lut", base.get_shader_parameter(&"pal_lut"))
	mat.set_shader_parameter(&"tl_floor_rect", Vector4(box.position.x, box.position.z, box.end.x, box.end.z))
	mat.set_shader_parameter(&"tl_land_colours", rim_material.get_shader_parameter(&"tl_land_colours"))
	mat.set_shader_parameter(&"tl_land_uv", rim_material.get_shader_parameter(&"tl_land_uv"))
	return mat


func _plot_v4(rel: Transform3D) -> Vector4:
	var yaw: float = rel.basis.get_euler().y
	var v: Vector4 = Vector4(rel.origin.x, rel.origin.y, rel.origin.z, yaw)
	if v == Vector4.ZERO:
		v.y = 0.000001          # a pack on the stage's own plot that is not the stage still takes the shifted path
	return v


## 1 = every material of the instance is a style shader that knows `tl_plot`; 0 = it carries something else (a pack's
## own StandardMaterial3D, a default material, a label); the caller mirrors it, so it still stands at its plot.
func _style_only(n: GeometryInstance3D) -> int:
	if n.material_override != null:
		return 1 if _mat_ok(n.material_override) else 0
	var mesh: Mesh = null
	if n is MeshInstance3D:
		mesh = (n as MeshInstance3D).mesh
		if mesh == null:
			return 1
		for s: int in mesh.get_surface_count():
			if not _mat_ok((n as MeshInstance3D).get_active_material(s)):
				return 0
		return 1
	if n is CPUParticles3D:
		mesh = (n as CPUParticles3D).mesh
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
		mesh = (n as MultiMeshInstance3D).multimesh.mesh
	else:
		return 0
	if mesh == null:
		return 0
	for s: int in mesh.get_surface_count():
		if not _mat_ok(mesh.surface_get_material(s)):
			return 0
	return 1


func _mat_ok(m: Material) -> bool:
	if not (m is ShaderMaterial) or (m as ShaderMaterial).shader == null:
		return false
	var sh: Shader = (m as ShaderMaterial).shader
	if not _shader_ok.has(sh):
		_shader_ok[sh] = sh.code.contains("instance uniform vec4 tl_plot")
	return _shader_ok[sh]


## Candidate A culling: the engine culls (camera and every shadow cascade) with the instance's box, which stands where
## the pack is simulated. `custom_aabb` is in the node's own space: T^-1 * rel * T * box. With no yaw it depends on
## the node's rotation only, so a node that only slides never needs a refresh.
func _refresh_aabb(rec: Dictionary, rel: Transform3D) -> void:
	var g: GeometryInstance3D = rec["node"]
	var t: Transform3D = g.global_transform
	rec["t"] = t
	var box: AABB = g.get_aabb()
	if box.size == Vector3.ZERO:
		box = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	if g is CPUParticles3D:
		box = box.grow(6.0)
	g.custom_aabb = t.affine_inverse() * (rel * (t * box))


func _is_triangles(mesh: Mesh, surface: int) -> bool:
	if mesh is ArrayMesh:
		return (mesh as ArrayMesh).surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES
	return mesh is PrimitiveMesh           # boxes, spheres, cylinders: triangles


func _under_moving_body(n: Node, top: Node) -> bool:
	var up: Node = n.get_parent()
	while up != null and up != top:
		if up is PhysicsBody3D and not (up is StaticBody3D) and not (up is RigidBody3D and (up as RigidBody3D).freeze):
			return true
		if up is Skeleton3D:
			return true
		up = up.get_parent()
	return false


## Does the face's XZ projection touch the plot disc? Used by far pictures and both collision copies.
static func tri_meets_disc(v0: Vector3, v1: Vector3, v2: Vector3, r2: float) -> bool:
	var a := Vector2(v0.x, v0.z)
	var b := Vector2(v1.x, v1.z)
	var c := Vector2(v2.x, v2.z)
	if a.length_squared() <= r2 or b.length_squared() <= r2 or c.length_squared() <= r2:
		return true
	if _edge_meets_disc(a, b, r2) or _edge_meets_disc(b, c, r2) or _edge_meets_disc(c, a, r2):
		return true
	# Edges already handle boundary contact, including triangles seen edge-on.
	# Only a strictly enclosed origin remains.
	var s0 := (b - a).cross(-a)
	var s1 := (c - b).cross(-b)
	var s2 := (a - c).cross(-c)
	return (s0 > 0.0 and s1 > 0.0 and s2 > 0.0) or (s0 < 0.0 and s1 < 0.0 and s2 < 0.0)


static func _edge_meets_disc(a: Vector2, b: Vector2, r2: float) -> bool:
	var d := b - a
	var l2 := d.length_squared()
	if l2 == 0.0:
		return false
	var u := clampf(-a.dot(d) / l2, 0.0, 1.0)
	return (a + d * u).length_squared() <= r2

## The height of a pack's own ground where its plot ends: the median height of its terrain sheets in a ring around
## `radius` (the shader bends the ring to exactly this height). The viewer lifts the plot by minus this, so the rim of the pack's ground meets the world's ground.
## NAN when the pack has no terrain sheet that reaches the ring.
static func edge_height(holder: Node3D, radius: float) -> float:
	if radius <= 0.0:
		return NAN
	var wide: Array = []
	_wide_meshes(holder, maxf(30.0, radius), wide)
	var ys: PackedFloat32Array = PackedFloat32Array()
	var soil := PackedFloat32Array()
	var sectors := PackedByteArray()
	sectors.resize(16)
	var terrain_index := TLStyle.index("terrain")
	var r_in: float = (radius - 3.0) * (radius - 3.0)
	var r_out: float = (radius + 4.0) * (radius + 4.0)
	for m: MeshInstance3D in wide:
		var xf: Transform3D = holder.global_transform.affine_inverse() * m.global_transform
		for s: int in m.mesh.get_surface_count():
			var arrays := m.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = xf * (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			var custom: Variant = arrays[Mesh.ARRAY_CUSTOM0]
			var coded: bool = custom is PackedFloat32Array and custom.size() == 4 * verts.size()
			for k: int in verts.size():
				var v := verts[k]
				var d2: float = v.x * v.x + v.z * v.z
				if d2 >= r_in and d2 <= r_out:
					ys.append(v.y)
					if coded and (int(custom[4 * k + 3] + 0.5) >> 4) == terrain_index:
						soil.append(v.y)
						sectors[posmod(floori(atan2(v.z, v.x) * 16.0 / TAU), 16)] = 1
	if ys.is_empty():
		return NAN         # no ground of its own at the plot edge: the world's ground runs through under it
	if OS.get_environment("TL_GROUND_COVER") != "off" and ground_cover(holder, radius, wide) < COVER_MIN:
		return NAN         # walker-feel T: some wide boxes touch the ring but leave most of the plot open: no hole
	# A merged scenery mesh can contain more treetop vertices than the soil beneath them.
	# Prefer tagged ground that encircles the plot. Deck-only venues still use their sheet median.
	if sectors.count(1) >= 14:
		ys = soil
	ys.sort()
	return ys[ys.size() / 2]


## Walker-feel T (blink B1): the share of the plot's rim that the pack's own wide meshes really cover. The world's
## ground is cut open to radius + 2.5 m for a pack with ground of its own; ex_car's ground is two boxes 60 m wide
## (its plot is 80 m across) and the 400 m ice box stands with its origin 200 m out, so the plot cut drops it whole:
## the corners of the boxes reached the rim ring and the hole was cut, and most of the plot showed the sky.
## Points on two circles (radius - 2 and radius + 2, 72 each) count as covered when a triangle of a wide mesh that the
## plot cut keeps (its origin inside the radius) lies over or under them: a vertical ray there meets it (bugfix-37 D4:
## the mesh's axis-aligned box, which this counted before, covers the whole rim of a square deck turned 45 degrees
## that covers a third of it). TL_GROUND_COVER=off: the rule before the cover (the before pictures; the rim cache then
## uses the key without "|cover").
const COVER_MIN: float = 0.95


static func ground_cover(holder: Node3D, radius: float, wide: Array) -> float:
	var pts: PackedVector2Array = PackedVector2Array()
	for rr: float in [radius - 2.0, radius + 2.0]:
		for k: int in 72:
			var a: float = TAU * float(k) / 72.0
			pts.append(Vector2(cos(a), sin(a)) * rr)
	var n: int = pts.size()
	var r_lo: float = radius - 2.0
	var r_hi: float = radius + 2.0
	for m: MeshInstance3D in wide:
		var xf: Transform3D = holder.global_transform.affine_inverse() * m.global_transform
		if Vector2(xf.origin.x, xf.origin.z).length() > radius:
			continue                                  # toon.gdshader drops an instance whose origin is outside the plot
		var f: PackedVector3Array = xf * m.mesh.get_faces()
		var t: int = 0
		while t + 2 < f.size() and not pts.is_empty():
			var a: Vector2 = Vector2(f[t].x, f[t].z)
			var b: Vector2 = Vector2(f[t + 1].x, f[t + 1].z)
			var c: Vector2 = Vector2(f[t + 2].x, f[t + 2].z)
			t += 3
			var lo: Vector2 = a.min(b).min(c)
			var hi: Vector2 = a.max(b).max(c)
			# only a triangle that reaches the band between the two circles can cover a point of them
			if maxf(maxf(a.length(), b.length()), c.length()) < r_lo:
				continue
			if Vector2(maxf(lo.x, minf(0.0, hi.x)), maxf(lo.y, minf(0.0, hi.y))).length() > r_hi:
				continue
			var area: float = (b - a).cross(c - a)
			if absf(area) < 1e-6:
				continue                              # a wall or a box's side seen from above: no ground
			for q: int in range(pts.size() - 1, -1, -1):
				var p: Vector2 = pts[q]
				if p.x < lo.x or p.x > hi.x or p.y < lo.y or p.y > hi.y:
					continue
				var w0: float = (b - a).cross(p - a) * signf(area)
				var w1: float = (c - b).cross(p - b) * signf(area)
				var w2: float = (a - c).cross(p - c) * signf(area)
				if w0 >= 0.0 and w1 >= 0.0 and w2 >= 0.0:
					pts.remove_at(q)
	return float(n - pts.size()) / float(n)


## Meshes at least `width` metres wide both ways and flat-ish (wider than tall): the terrain sheets of a pack.
static func _wide_meshes(n: Node, width: float, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible:
		var bb: AABB = (n as MeshInstance3D).mesh.get_aabb()
		if minf(bb.size.x, bb.size.z) >= width and bb.size.y < minf(bb.size.x, bb.size.z):
			out.append(n)
	for c: Node in n.get_children():
		_wide_meshes(c, width, out)
