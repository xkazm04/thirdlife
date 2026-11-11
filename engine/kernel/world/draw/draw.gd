extends Node3D
## N5b. The draw layer of a world: every pack is SIMULATED at the origin of its own physics space (N2), and DRAWN at
## its plot. This node never touches a physics body, a transform of a pack node, or anything a state hash reads.
##
## The stage rule: the stage pack (the one the player is in) is drawn natively, at zero offset. Every other pack, the
## landscape and the far stand-ins are drawn at `rel_i = plot_stage^-1 * plot_i`. `set_stage(i)` re-bases all of it once.
##
## Two mechanisms, chosen with `mech` (see DRAW.md for the measurement that decided):
##   "a"  offset in the shaders: `instance uniform vec4 tl_plot` (xyz offset, w yaw) of every style shader, set once on
##        each GeometryInstance3D of a pack. Whatever is not style geometry (lights, a pack's own material) is mirrored.
##   "b"  mirror instances: one RenderingServer instance per visual with the SAME base (mesh, multimesh, light), at
##        `rel * node.global_transform`; the node's own instance is hidden on the server. Moved nodes are re-sent in
##        `_process` (one comparison per visual per frame).
## Culling for "a" (`cull`): the engine culls with the box of the place where the pack is simulated, so each instance
## needs help. "auto" (kept): an instance that stands still gets a `custom_aabb` around its drawn place, once; an
## instance under a moving body, a skeleton or a particle emitter is never culled (`extra_cull_margin`); a slow
## round-robin check (WATCH instances per pack per frame) moves any "still" instance that a script turned after all
## into the never-culled class. "aabb" refreshes every box every frame (exact, one comparison per instance per frame),
## "margin" never culls anything of a non-stage pack.
##
## Far packs (`far_mode` "auto" beyond `far_dist`, or "all"): the pack's holder is hidden and ONE merged mesh built
## from its static style geometry at placement is shown instead (`_build_standin`).

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
var standin_min: float = 1.2            # metres: a mesh instance whose longest side is shorter is dropped
var stage: int = 0
var world: Node = null
var entries: Array = []                 # one Dictionary per pack
var scenario: RID
var sync_usec: PackedInt64Array = PackedInt64Array()
var _pending: Array = []
var _shader_ok: Dictionary = {}         # Shader -> bool (declares tl_plot)
var _pal: Material = null
var stats: Dictionary = {"a_instances": 0, "mirrors": 0, "light_mirrors": 0, "foreign": 0, "foreign_names": [], "late": 0}


## The clip parameter of a pack (toon.gdshader `tl_clip`): radius, rim height, width of the bent band.
func _clip_v4(e: Dictionary, g: Node) -> Vector4:
	if not e.has("sheets"):
		var wide: Array = []
		_wide_meshes(e["holder"], maxf(30.0, float(e["radius"])), wide)
		e["sheets"] = wide
	return Vector4(float(e["radius"]), float(e["rim"]), rim_band, 1.0 if (e["sheets"] as Array).has(g) else 0.0)


func setup(world_node: Node, plots: Array, radii: Array, rims: Array, stage_index: int) -> void:
	world = world_node
	scenario = get_viewport().find_world_3d().scenario
	_pal = TLStyle.material(&"white")
	var holders: Array = world.get("packs")
	for i: int in holders.size():
		entries.append({"holder": holders[i], "plot": plots[i], "radius": float(radii[i]) if i < radii.size() else 0.0,
			"rim": float(rims[i]) if i < rims.size() else 0.0,
			"clipped": [], "rel": Transform3D.IDENTITY, "a": [], "mirrors": [],
			"standin": null, "far": false, "placed": false, "standin_info": {}})
	get_tree().node_added.connect(_on_node_added)
	stage = stage_index             # the caller places the world with set_stage()


## Re-bases the world on another stage pack: once, not per tick.
func set_stage(index: int) -> void:
	stage = clampi(index, 0, maxi(0, entries.size() - 1))
	var inv: Transform3D = (entries[stage]["plot"] as Transform3D).affine_inverse() if not entries.is_empty() else Transform3D.IDENTITY
	for i: int in entries.size():
		var e: Dictionary = entries[i]
		_unplace(e)
		e["rel"] = inv * (e["plot"] as Transform3D)
		var ctx: TLContext = (e["holder"] as Node).get("ctx")
		if ctx != null:
			ctx.on_stage = i == stage
			for h: Variant in ctx.huds:
				if is_instance_valid(h):
					(h as CanvasLayer).visible = i == stage
		if e["standin"] != null:
			_place_standin(e, e["standin"])
		if i != stage:
			_place(e)
		elif float(e["radius"]) > 0.0:
			_clip_walk(e, e["holder"])        # the stage pack is cut to its plot too; nothing else of it is touched
		_set_far(e, far_mode == "all" and i != stage, true)


# ------------------------------------------------------------------------------------------------ placing a pack
func _place(e: Dictionary) -> void:
	e["placed"] = true
	_walk(e, e["holder"])


func _clip_walk(e: Dictionary, n: Node) -> void:
	if n is GeometryInstance3D:
		_clip(e, n)
	for c: Node in n.get_children():
		_clip_walk(e, c)


func _clip(e: Dictionary, g: GeometryInstance3D) -> void:
	if float(e["radius"]) > 0.0 and not g.has_meta(&"tl_clip"):
		g.set_meta(&"tl_clip", true)
		g.set_instance_shader_parameter(CLIP, _clip_v4(e, g))
		(e["clipped"] as Array).append(g)


func _walk(e: Dictionary, n: Node) -> void:
	if n is GeometryInstance3D:
		_clip(e, n)
	if n is VisualInstance3D:
		_adopt(e, n)
	for c: Node in n.get_children():
		_walk(e, c)


func _plot_v4(rel: Transform3D) -> Vector4:
	var yaw: float = rel.basis.get_euler().y
	var v: Vector4 = Vector4(rel.origin.x, rel.origin.y, rel.origin.z, yaw)
	if v == Vector4.ZERO:
		v.y = 0.000001          # a pack on the stage's own plot that is not the stage still takes the shifted path
	return v


func _adopt(e: Dictionary, n: VisualInstance3D) -> void:
	if n.has_meta(&"tl_draw"):
		return
	var rel: Transform3D = e["rel"]
	if mech == "a" and n is GeometryInstance3D:
		var verdict: int = _style_only(n)
		if verdict == 1:
			var g: GeometryInstance3D = n
			n.set_meta(&"tl_draw", 1)
			g.set_instance_shader_parameter(PLOT, _plot_v4(rel))
			var rec: Dictionary = {"node": g, "margin": g.extra_cull_margin, "aabb": g.custom_aabb, "t": Transform3D(Basis(), Vector3(INF, 0, 0))}
			if cull == "margin" or (cull == "auto" and (g is CPUParticles3D or g is GPUParticles3D or _under_moving_body(g, e["holder"]))):
				g.extra_cull_margin = NEVER
				rec["never"] = true
			else:
				_refresh_aabb(rec, rel)
			(e["a"] as Array).append(rec)
			stats["a_instances"] = int(stats["a_instances"]) + 1
			return
		if verdict == 0:
			stats["foreign"] = int(stats["foreign"]) + 1
			if (stats["foreign_names"] as Array).size() < 12:
				(stats["foreign_names"] as Array).append(String(n.get_path()).get_slice("/", 3) + "/.../" + String(n.name))
	_mirror(e, n)


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


func _mirror(e: Dictionary, n: VisualInstance3D) -> void:
	n.set_meta(&"tl_draw", 2)
	var rid: RID = RenderingServer.instance_create2(n.get_base(), scenario)
	RenderingServer.instance_set_layer_mask(rid, n.layers)
	if n is GeometryInstance3D:
		var g: GeometryInstance3D = n
		RenderingServer.instance_geometry_set_cast_shadows_setting(rid, g.cast_shadow as RenderingServer.ShadowCastingSetting)
		if g.material_override != null:
			RenderingServer.instance_geometry_set_material_override(rid, g.material_override.get_rid())
		if g.material_overlay != null:
			RenderingServer.instance_geometry_set_material_overlay(rid, g.material_overlay.get_rid())
		# a mirror is drawn with the plot inside its model matrix, so the shader's cut (which works in the pack's own
		# coordinates) cannot be used on it: candidate B draws the whole pack, far scenery included
		RenderingServer.instance_geometry_set_shader_parameter(rid, CLIP, Vector4.ZERO)
		var b: Variant = g.get_instance_shader_parameter(&"build")
		if b != null:
			RenderingServer.instance_geometry_set_shader_parameter(rid, &"build", b)
		if g is MeshInstance3D:
			var mi: MeshInstance3D = g
			for s: int in mi.get_surface_override_material_count():
				var om: Material = mi.get_surface_override_material(s)
				if om != null:
					RenderingServer.instance_set_surface_override_material(rid, s, om.get_rid())
			var sr: SkinReference = mi.get_skin_reference()
			if sr != null:
				RenderingServer.instance_attach_skeleton(rid, sr.get_skeleton())
		stats["mirrors"] = int(stats["mirrors"]) + 1
	else:
		stats["light_mirrors"] = int(stats["light_mirrors"]) + 1
	var vis: bool = n.is_visible_in_tree()
	var t: Transform3D = n.global_transform
	RenderingServer.instance_set_transform(rid, (e["rel"] as Transform3D) * t)
	RenderingServer.instance_set_visible(rid, vis)
	RenderingServer.instance_set_visible(n.get_instance(), false)      # server side only: the node's `visible` is untouched
	(e["mirrors"] as Array).append({"node": n, "rid": rid, "t": t, "vis": vis, "base": n.get_base()})


func _unplace(e: Dictionary) -> void:
	for rec: Dictionary in e["a"]:
		var g: Variant = rec["node"]
		if is_instance_valid(g):
			(g as GeometryInstance3D).set_instance_shader_parameter(PLOT, null)
			(g as GeometryInstance3D).extra_cull_margin = rec["margin"]
			(g as GeometryInstance3D).custom_aabb = rec["aabb"]
			(g as Node).remove_meta(&"tl_draw")
	(e["a"] as Array).clear()
	for m: Dictionary in e["mirrors"]:
		RenderingServer.free_rid(m["rid"])
		var n: Variant = m["node"]
		if is_instance_valid(n):
			(n as Node).remove_meta(&"tl_draw")
			RenderingServer.instance_set_visible((n as VisualInstance3D).get_instance(), (n as VisualInstance3D).is_visible_in_tree())
	(e["mirrors"] as Array).clear()
	for g: Variant in e["clipped"]:
		if is_instance_valid(g):
			(g as GeometryInstance3D).set_instance_shader_parameter(CLIP, null)
			(g as Node).remove_meta(&"tl_clip")
	(e["clipped"] as Array).clear()
	e["placed"] = false


func _on_node_added(n: Node) -> void:
	if n is VisualInstance3D and world != null and world.is_ancestor_of(n):
		_pending.append(n)


func _entry_of(n: Node) -> Dictionary:
	for e: Dictionary in entries:
		if (e["holder"] as Node).is_ancestor_of(n):
			return e
	return {}


# ------------------------------------------------------------------------------------------------ every frame
func _process(_delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	if not _pending.is_empty():
		var todo: Array = _pending
		_pending = []
		for n: Variant in todo:
			if is_instance_valid(n) and (n as Node).is_inside_tree():
				var e: Dictionary = _entry_of(n)
				if not e.is_empty() and n is GeometryInstance3D:
					_clip(e, n)
				if not e.is_empty() and bool(e["placed"]):
					stats["late"] = int(stats["late"]) + 1
					_adopt(e, n)
	if far_mode == "auto":
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam != null:
			var at: Vector3 = cam.global_position
			for i: int in entries.size():
				if i == stage:
					continue
				var e: Dictionary = entries[i]
				var d: float = Vector2(at.x, at.z).distance_to(Vector2((e["rel"] as Transform3D).origin.x, (e["rel"] as Transform3D).origin.z))
				if not bool(e["far"]) and d > far_dist * (1.0 + far_margin):
					_set_far(e, true, false)
				elif bool(e["far"]) and d < far_dist * (1.0 - far_margin):
					_set_far(e, false, false)
	for i: int in entries.size():
		if i == stage:
			continue
		var e: Dictionary = entries[i]
		if bool(e["far"]):
			continue                      # hidden: nothing to follow until it comes near again
		var rel: Transform3D = e["rel"]
		var mirrors: Array = e["mirrors"]
		var k: int = 0
		while k < mirrors.size():
			var m: Dictionary = mirrors[k]
			var n: Variant = m["node"]
			if not is_instance_valid(n) or not (n as Node).is_inside_tree():
				RenderingServer.free_rid(m["rid"])
				mirrors.remove_at(k)
				continue
			var v: VisualInstance3D = n
			var t: Transform3D = v.global_transform
			if t != m["t"]:
				m["t"] = t
				RenderingServer.instance_set_transform(m["rid"], rel * t)
			var vis: bool = v.is_visible_in_tree()
			if vis != m["vis"]:
				m["vis"] = vis
				RenderingServer.instance_set_visible(m["rid"], vis)
				RenderingServer.instance_set_visible(v.get_instance(), false)
			if v.get_base() != m["base"]:
				m["base"] = v.get_base()
				RenderingServer.instance_set_base(m["rid"], v.get_base())
			k += 1
		if cull == "auto":
			var watch: Array = e["a"]
			var at: int = int(e.get("watch_at", 0))
			var plain_w: bool = rel.basis.is_equal_approx(Basis.IDENTITY)
			for w: int in mini(WATCH, watch.size()):
				at = (at + 1) % watch.size()
				var wr: Dictionary = watch[at]
				var wg: Variant = wr["node"]
				if wr.has("never") or not is_instance_valid(wg):
					continue
				var wt: Transform3D = (wg as Node3D).global_transform
				var ww: Transform3D = wr["t"]
				if (plain_w and wt.basis != ww.basis) or (not plain_w and wt != ww):
					wr["never"] = true                    # it moves after all: stop culling it, keep it drawn
					(wg as GeometryInstance3D).extra_cull_margin = NEVER
					stats["promoted"] = int(stats.get("promoted", 0)) + 1
			e["watch_at"] = at
		elif cull == "aabb":
			var plain: bool = rel.basis.is_equal_approx(Basis.IDENTITY)
			var list: Array = e["a"]
			var j: int = 0
			while j < list.size():
				var rec: Dictionary = list[j]
				var g: Variant = rec["node"]
				if not is_instance_valid(g):
					list.remove_at(j)
					continue
				var gt: Transform3D = (g as Node3D).global_transform
				var was: Transform3D = rec["t"]
				if (plain and gt.basis != was.basis) or (not plain and gt != was):
					_refresh_aabb(rec, rel)
				j += 1
	sync_usec.append(Time.get_ticks_usec() - t0)


# ------------------------------------------------------------------------------------------------ far stand-ins
func _set_far(e: Dictionary, far: bool, force: bool) -> void:
	if far == bool(e["far"]) and not force:
		return
	e["far"] = far
	var holder: Node3D = e["holder"]
	if far and e["standin"] == null:
		_build_standin(e)
	if e["standin"] != null:
		(e["standin"] as Node3D).visible = far
	if holder.visible == far:
		holder.visible = not far              # drawing only: no script of a pack is told, no body moves
		for m: Dictionary in e["mirrors"]:
			var n: Variant = m["node"]
			if is_instance_valid(n):
				var vis: bool = (n as VisualInstance3D).is_visible_in_tree()
				m["vis"] = vis
				RenderingServer.instance_set_visible(m["rid"], vis)
				RenderingServer.instance_set_visible((n as VisualInstance3D).get_instance(), false)


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


## One merged mesh from the pack's static style geometry: palette columns, vertex colours and part-local coordinates
## kept (so it is drawn by the same palette material, with the same drawn surface detail and the same ink lines);
## instances smaller than `standin_min`, anything under a moving body or a skeleton, particles, glass and foreign
## materials dropped.
## What a stand-in is merged into (a class, not a Dictionary: packed arrays inside a Dictionary are copied on access).
class Acc:
	var v: PackedVector3Array = PackedVector3Array()
	var n: PackedVector3Array = PackedVector3Array()
	var c: PackedColorArray = PackedColorArray()
	var uv: PackedVector2Array = PackedVector2Array()
	var cu: PackedFloat32Array = PackedFloat32Array()
	var ix: PackedInt32Array = PackedInt32Array()
	var sheets: Array = []
	var extra: Dictionary = {}          # Material -> Acc: one more surface per flat-colour toon material (kernel-made boxes)
	var radius: float = 0.0
	var rim: float = 0.0
	var band: float = 0.0
	var kept: int = 0
	var dropped_small: int = 0
	var dropped_moving: int = 0
	var dropped_other: int = 0
	var dropped_outside: int = 0
	var src_tris: int = 0


func _build_standin(e: Dictionary) -> void:
	var t0: int = Time.get_ticks_msec()
	var holder: Node3D = e["holder"]
	var acc: Acc = Acc.new()
	acc.radius = float(e["radius"])
	acc.rim = float(e["rim"])
	acc.band = rim_band
	_clip_v4(e, holder)                       # makes sure e["sheets"] is there
	acc.sheets = e["sheets"]
	_collect_standin(holder, holder, acc)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Standin_" + String(holder.name)
	var mesh: ArrayMesh = ArrayMesh.new()
	var parts: Array = [[acc, _pal]]
	for mat: Variant in acc.extra:
		parts.append([acc.extra[mat], mat])
	var tris: int = 0
	var verts: int = 0
	for part: Array in parts:
		var pa: Acc = part[0]
		if pa.v.size() == 0:
			continue
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pa.v
		arr[Mesh.ARRAY_NORMAL] = pa.n
		arr[Mesh.ARRAY_COLOR] = pa.c
		arr[Mesh.ARRAY_TEX_UV] = pa.uv
		arr[Mesh.ARRAY_CUSTOM0] = pa.cu
		arr[Mesh.ARRAY_INDEX] = pa.ix
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		mesh.surface_set_material(mesh.get_surface_count() - 1, part[1])
		tris += pa.ix.size() / 3
		verts += pa.v.size()
		if pa != acc:
			acc.src_tris += pa.src_tris
	if mesh.get_surface_count() > 0:
		mi.mesh = mesh
	mi.visible = false
	_place_standin(e, mi)
	add_child(mi)
	e["standin"] = mi
	e["standin_info"] = {"tris": tris, "vertices": verts, "surfaces": mesh.get_surface_count(),
		"kept": acc.kept, "dropped_small": acc.dropped_small, "dropped_moving": acc.dropped_moving,
		"dropped_other": acc.dropped_other, "dropped_outside": acc.dropped_outside, "src_tris": acc.src_tris, "build_ms": Time.get_ticks_msec() - t0}


## A stand-in is drawn like the pack it stands for: the node stays at the origin and the shader moves it (candidate A),
## so the plot cut and the bent rim, which work in the pack's own coordinates, are the same as on the full pack.
func _place_standin(e: Dictionary, mi: MeshInstance3D) -> void:
	mi.transform = Transform3D.IDENTITY
	mi.set_instance_shader_parameter(PLOT, _plot_v4(e["rel"]))
	if float(e["radius"]) > 0.0:
		mi.set_instance_shader_parameter(CLIP, Vector4(float(e["radius"]), float(e["rim"]), 0.0, 0.0))    # cut, not bent: the bend is baked
	if mi.mesh != null:
		mi.custom_aabb = (e["rel"] as Transform3D) * mi.mesh.get_aabb().grow(4.0)


func _collect_standin(n: Node, holder: Node3D, acc: Acc) -> void:
	if n is Node3D and not (n as Node3D).visible:
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m: MeshInstance3D = n
		if _under_moving_body(m, holder) or m.get_skin_reference() != null:
			acc.dropped_moving += 1
		elif m.mesh.get_aabb().size[m.mesh.get_aabb().get_longest_axis_index()] * m.global_basis.get_scale().x < standin_min:
			acc.dropped_small += 1
		elif acc.radius > 0.0 and Vector2(m.global_position.x, m.global_position.z).length() > acc.radius:
			acc.dropped_outside += 1
		else:
			var xf: Transform3D = holder.global_transform.affine_inverse() * m.global_transform
			for s: int in m.mesh.get_surface_count():
				var target: Acc = _target(acc, m.get_active_material(s))
				if target != null and _is_triangles(m.mesh, s):
					_append(target, m.mesh.surface_get_arrays(s), xf, acc.sheets.has(m))
					acc.kept += 1
				else:
					acc.dropped_other += 1
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null and (n as MultiMeshInstance3D).multimesh.mesh != null:
		var mmi: MultiMeshInstance3D = n
		var mm: MultiMesh = mmi.multimesh
		var base: Transform3D = holder.global_transform.affine_inverse() * mmi.global_transform
		var count: int = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		for s: int in mm.mesh.get_surface_count():
			var mat: Material = mmi.material_override if mmi.material_override != null else mm.mesh.surface_get_material(s)
			if mat != _pal or not _is_triangles(mm.mesh, s):
				acc.dropped_other += 1
				continue
			var arrays: Array = mm.mesh.surface_get_arrays(s)
			var longest: float = mm.mesh.get_aabb().size[mm.mesh.get_aabb().get_longest_axis_index()]
			for i: int in count:
				var it: Transform3D = mm.get_instance_transform(i)
				if longest * it.basis.get_scale().y < standin_min or acc.v.size() > 600000:
					acc.dropped_small += 1
					continue
				var io: Vector3 = (base * it).origin
				if acc.radius > 0.0 and Vector2(io.x, io.z).length() > acc.radius:
					acc.dropped_outside += 1
					continue
				_append(acc, arrays, base * it, false)
				acc.kept += 1
	for c: Node in n.get_children():
		_collect_standin(c, holder, acc)


## Where a surface of this material goes in the stand-in: the palette material into the first surface, another material
## of the toon shader (TLStyle.flat_material: the kernel's boxes and balls, in one colour) into a surface of its own,
## anything else (glass, water, a pack's own material) nowhere.
func _target(acc: Acc, mat: Material) -> Acc:
	if mat == _pal:
		return acc
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader == (_pal as ShaderMaterial).shader:
		if not acc.extra.has(mat):
			var child: Acc = Acc.new()
			child.radius = acc.radius
			child.rim = acc.rim
			child.band = acc.band
			acc.extra[mat] = child
		return acc.extra[mat]
	return null


func _append(acc: Acc, a: Array, xf: Transform3D, sheet: bool) -> void:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var count: int = v.size()
	if count == 0:
		return
	var nb: Basis = xf.basis.inverse().transposed()
	var nrm: Variant = a[Mesh.ARRAY_NORMAL]
	var col: Variant = a[Mesh.ARRAY_COLOR]
	var uv: Variant = a[Mesh.ARRAY_TEX_UV]
	var cu: Variant = a[Mesh.ARRAY_CUSTOM0]
	var ix: Variant = a[Mesh.ARRAY_INDEX]
	var has_n: bool = nrm is PackedVector3Array and (nrm as PackedVector3Array).size() == count
	var has_c: bool = col is PackedColorArray and (col as PackedColorArray).size() == count
	var has_uv: bool = uv is PackedVector2Array and (uv as PackedVector2Array).size() == count
	var has_cu: bool = cu is PackedFloat32Array and (cu as PackedFloat32Array).size() == count * 4
	var out_v: PackedVector3Array = xf * v
	# the bent rim of toon.gdshader `tl_clip`, baked in: in the merged mesh the shader could not tell a terrain sheet
	# (bent per vertex) from what stands on it (moved as a whole by the height of its own origin)
	if acc.radius > 0.0 and acc.band > 0.0:
		var ro: float = Vector2(xf.origin.x, xf.origin.z).length()
		var whole: float = (acc.rim - xf.origin.y) * smoothstep(acc.radius - acc.band, acc.radius, ro)
		if sheet:
			for k: int in count:
				var p: Vector3 = out_v[k]
				p.y += (acc.rim - p.y) * smoothstep(acc.radius - acc.band, acc.radius, Vector2(p.x, p.z).length())
				out_v[k] = p
		elif whole != 0.0:
			for k: int in count:
				var q: Vector3 = out_v[k]
				q.y += whole
				out_v[k] = q
	var src: PackedInt32Array = ix if (ix is PackedInt32Array and (ix as PackedInt32Array).size() > 0) else PackedInt32Array()
	if src.is_empty():
		src.resize(count)
		for k: int in count:
			src[k] = k
	acc.src_tris += src.size() / 3
	var r: float = acc.radius
	var r2: float = (r + 3.0) * (r + 3.0)
	var slot: PackedInt32Array = PackedInt32Array()       # source vertex -> its place in the stand-in, -1 = not used
	slot.resize(count)
	slot.fill(-1)
	var t: int = 0
	while t + 2 < src.size():
		# the plot cut of toon.gdshader, per triangle: a triangle wholly outside the plot is not part of the stand-in
		if r > 0.0:
			var a0: Vector3 = out_v[src[t]]
			var a1: Vector3 = out_v[src[t + 1]]
			var a2: Vector3 = out_v[src[t + 2]]
			if a0.x * a0.x + a0.z * a0.z > r2 and a1.x * a1.x + a1.z * a1.z > r2 and a2.x * a2.x + a2.z * a2.z > r2:
				t += 3
				continue
		for c3: int in 3:
			var k: int = src[t + c3]
			if slot[k] < 0:
				slot[k] = acc.v.size()
				acc.v.append(out_v[k])
				acc.n.append((nb * (nrm as PackedVector3Array)[k]).normalized() if has_n else Vector3.UP)
				acc.c.append((col as PackedColorArray)[k] if has_c else Color.WHITE)
				acc.uv.append((uv as PackedVector2Array)[k] if has_uv else Vector2.ZERO)
				if has_cu:
					var f: PackedFloat32Array = cu
					acc.cu.append(f[k * 4])
					acc.cu.append(f[k * 4 + 1])
					acc.cu.append(f[k * 4 + 2])
					acc.cu.append(f[k * 4 + 3])
				else:
					acc.cu.append_array(PackedFloat32Array([0.0, 0.0, 0.0, 0.0]))
			acc.ix.append(slot[k])
		t += 3


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


# ------------------------------------------------------------------------------------------------ report, cleanup
func report() -> Dictionary:
	var far_count: int = 0
	var standins: Array = []
	var a_live: int = 0
	var mirror_live: int = 0
	for e: Dictionary in entries:
		if bool(e["far"]):
			far_count += 1
		if not (e["standin_info"] as Dictionary).is_empty():
			standins.append(e["standin_info"])
		a_live += (e["a"] as Array).size()
		mirror_live += (e["mirrors"] as Array).size()
	var sorted: PackedInt64Array = sync_usec.duplicate()
	sorted.sort()
	var p50: float = float(sorted[sorted.size() / 2]) / 1000.0 if sorted.size() > 0 else 0.0
	return {"mech": mech, "cull": cull, "stage": stage, "far_mode": far_mode, "far_packs": far_count, "a_instances_live": a_live,
		"mirrors_live": mirror_live, "adopted": stats, "sync_ms_p50": snappedf(p50, 0.0001), "standins": standins}


func clear() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	for e: Dictionary in entries:
		for m: Dictionary in e["mirrors"]:
			RenderingServer.free_rid(m["rid"])
		(e["mirrors"] as Array).clear()
		(e["a"] as Array).clear()
	entries.clear()
	world = null


func _exit_tree() -> void:
	clear()
