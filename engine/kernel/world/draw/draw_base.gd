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
var rim_band: float = 9.0                # metres inside the plot edge over which a pack's ground is bent to the world's
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
const PIC_VERSION: int = 13             # P13: part of the picture cache's key; count it up when a picture's rules change
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
	return Vector4(float(e["radius"]), float(e["rim"]), rim_band, 1.0 if (e["sheets"] as Array).has(g) else 0.0)


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


## The height of a pack's own ground where its plot ends: the median height of its terrain sheets in a ring around
## `radius` (the shader bends the ring to exactly this height). The viewer lifts the plot by minus this, so the rim of the pack's ground meets the world's ground.
## NAN when the pack has no terrain sheet that reaches the ring.
static func edge_height(holder: Node3D, radius: float) -> float:
	if radius <= 0.0:
		return NAN
	var wide: Array = []
	_wide_meshes(holder, maxf(30.0, radius), wide)
	var ys: PackedFloat32Array = PackedFloat32Array()
	var r_in: float = (radius - 3.0) * (radius - 3.0)
	var r_out: float = (radius + 4.0) * (radius + 4.0)
	for m: MeshInstance3D in wide:
		var xf: Transform3D = holder.global_transform.affine_inverse() * m.global_transform
		for s: int in m.mesh.get_surface_count():
			var verts: PackedVector3Array = xf * (m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			for v: Vector3 in verts:
				var d2: float = v.x * v.x + v.z * v.z
				if d2 >= r_in and d2 <= r_out:
					ys.append(v.y)
	if ys.is_empty():
		return NAN         # no ground of its own at the plot edge: the world's ground runs through under it
	ys.sort()          # the median: a skirt under the far sheet or the foot of a cliff must not decide
	return ys[ys.size() / 2]


## Meshes at least `width` metres wide both ways and flat-ish (wider than tall): the terrain sheets of a pack.
static func _wide_meshes(n: Node, width: float, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible:
		var bb: AABB = (n as MeshInstance3D).mesh.get_aabb()
		if minf(bb.size.x, bb.size.z) >= width and bb.size.y < minf(bb.size.x, bb.size.z):
			out.append(n)
	for c: Node in n.get_children():
		_wide_meshes(c, width, out)
