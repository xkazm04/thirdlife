extends "res://kernel/world/draw/draw_life.gd"
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
## Far packs (`far_mode` "auto" beyond `far_dist`, or "all"; in a scheduled world the tiers `backdrop` and `ledger`):
## the pack's holder is hidden and one of two merged PICTURES of it is shown instead (P6, draw/FAR.md):
##   "mid"  the venue's large forms (instances shorter than `mid_min` dropped) plus signs of life: one mark per moving
##          body (a box in the body's colour, one multimesh per pack, moved when the pack ticks), a copy of its smoke,
##          a few of its lights;
##   "far"  a silhouette: only forms of at least `far_min`, its own ground re-meshed coarsely, normals leaning up so
##          it is drawn in flat tones with one outline; the marks stay (larger), so the picture still moves.
## Which of the two is decided per frame by the camera's distance to the plot edge (`picture_far_m`, with a margin
## both ways). "still" is N5b's stand-in (everything above 1.2 m, nothing moving), kept for comparison:
## the env variable TL_DRAW_PICTURE=still|mid|far forces one picture on every far pack.
## At every distance (near too) a kit scoreboard of the pack shows the pack's REAL score (`_build_boards`).
##
## P6: the layer is one class in four files (size rule of `tl arch`): draw_base.gd (constants, variables, helpers),
## draw_pictures.gd (the merged pictures), draw_life.gd (which picture, marks, smoke, lights, score), this file (plots,
## the stage rule, both offset mechanisms, culling, the per-frame loop, the report).


func setup(world_node: Node, plots: Array, radii: Array, rims: Array, stage_index: int) -> void:
	world = world_node
	scenario = get_viewport().find_world_3d().scenario
	_pal = TLStyle.material(&"white")
	if force_picture.is_empty():              # the viewer may set it (PATCHES-P6 entry 2); until then the env variable
		force_picture = OS.get_environment("TL_DRAW_PICTURE")
	var wcfg: Variant = world.get("cfg")          # tiers.json as the world host read it: the loading builder's file
	if typeof(wcfg) == TYPE_DICTIONARY:
		picture_far_m = float((wcfg as Dictionary).get("picture_far_m", picture_far_m))
		var wm: Variant = (wcfg as Dictionary).get("margin_m", {})
		if typeof(wm) == TYPE_DICTIONARY:
			picture_margin_m = float((wm as Dictionary).get("picture", picture_margin_m))
	var holders: Array = world.get("packs")
	for i: int in holders.size():
		entries.append({"holder": holders[i], "plot": plots[i], "radius": float(radii[i]) if i < radii.size() else 0.0,
			"rim": float(rims[i]) if i < rims.size() else 0.0,
			"clipped": [], "rel": Transform3D.IDENTITY, "a": [], "mirrors": [],
			"pics": {}, "kind": "", "life": {}, "boards": {}, "far": false, "placed": false, "standin_info": {}})
	get_tree().node_added.connect(_on_node_added)
	stage = stage_index             # the caller places the world with set_stage()


## Re-bases the world on another stage pack: once, not per tick. N7: `-1` = nobody is on stage (the visitor walks):
## every pack is drawn at its plot, in world coordinates.
func set_stage(index: int) -> void:
	stage = clampi(index, -1, entries.size() - 1)
	var inv: Transform3D = (entries[stage]["plot"] as Transform3D).affine_inverse() if stage >= 0 else Transform3D.IDENTITY
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
		_place_own(e)
		if i != stage:
			_place(e)
		elif float(e["radius"]) > 0.0:
			_clip_walk(e, e["holder"])        # the stage pack is cut to its plot too; nothing else of it is touched
		_set_far(e, _wants_far(e) and i != stage, true)


func _wants_far(e: Dictionary) -> bool:
	return bool(e["tier_far"]) if e.get("tier_far", null) != null else far_mode == "all"


## N7. The scheduler's tier decides how plot `i` is drawn: in full (`stage`, `sideline`) or as its stand-in
## (`backdrop`, `ledger`). Called at a tick boundary; the stand-in is built the first time it is needed.
func set_tier(i: int, tier: String) -> void:
	if i < 0 or i >= entries.size():
		return
	var e: Dictionary = entries[i]
	e["tier"] = tier
	e["tier_far"] = tier == "backdrop" or tier == "ledger"
	_set_far(e, bool(e["tier_far"]) and i != stage, false)


## N7. Plot `i` lost its pack's nodes (`ledger`): only the stand-in is left to draw.
func forget_nodes(i: int) -> void:
	if i >= 0 and i < entries.size():
		_unplace(entries[i])
		(entries[i] as Dictionary).erase("sheets")
		_drop_life(entries[i], false)         # the marks stay where they were: a still picture of a game that is not in memory


## N7. The pack of plot `i` was built again from its seed (next round, back from the ledger): a new holder with new
## nodes. The stand-in is kept: it is a still picture of the same venue.
func replace_holder(i: int, holder: Node) -> void:
	if i < 0 or i >= entries.size():
		return
	var e: Dictionary = entries[i]
	_unplace(e)                       # the old nodes are gone: this frees the mirrors and forgets the rest
	e["holder"] = holder
	e.erase("sheets")
	e["far"] = false                  # a new holder is visible
	_drop_life(e, true)               # new nodes: marks, smoke, lights and boards are found again when needed
	var ctx: TLContext = holder.get("ctx")
	if ctx != null:
		for h: Variant in ctx.huds:
			if is_instance_valid(h):
				(h as CanvasLayer).visible = i == stage
	if i != stage:
		_place(e)
	elif float(e["radius"]) > 0.0:
		_clip_walk(e, holder)
	_set_far(e, _wants_far(e) and i != stage, true)


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
		if is_instance_valid(e["holder"]) and (e["holder"] as Node).is_ancestor_of(n):
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
		_life(entries[i], i)              # P6: which far picture, marks on the pack's own ticks, the score on its boards
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
	if not is_instance_valid(e["holder"]):
		_show(e)
		return
	var holder: Node3D = e["holder"]
	if far:
		_ensure_pictures(e)
	_show(e)
	if holder.visible == far:
		holder.visible = not far              # drawing only: no script of a pack is told, no body moves
		for m: Dictionary in e["mirrors"]:
			var n: Variant = m["node"]
			if is_instance_valid(n):
				var vis: bool = (n as VisualInstance3D).is_visible_in_tree()
				m["vis"] = vis
				RenderingServer.instance_set_visible(m["rid"], vis)
				RenderingServer.instance_set_visible((n as VisualInstance3D).get_instance(), false)


# ------------------------------------------------------------------------------------------------ report, cleanup
func report() -> Dictionary:
	var far_count: int = 0
	var standins: Array = []
	var a_live: int = 0
	var mirror_live: int = 0
	var pictures: Dictionary = {}
	var marks: int = 0
	var boards: int = 0
	for e: Dictionary in entries:
		if bool(e["far"]):
			far_count += 1
		for k: String in (e["standin_info"] as Dictionary):
			var info: Dictionary = ((e["standin_info"] as Dictionary)[k] as Dictionary).duplicate()
			info["shown"] = bool(e["far"]) and str(e["kind"]) == k
			standins.append(info)
		var shown: String = str(e["kind"]) if bool(e["far"]) else "near"
		pictures[shown] = int(pictures.get(shown, 0)) + 1
		marks += ((e["life"] as Dictionary).get("movers", []) as Array).size()
		boards += ((e["boards"] as Dictionary).get("list", []) as Array).size()
		a_live += (e["a"] as Array).size()
		mirror_live += (e["mirrors"] as Array).size()
	var sorted: PackedInt64Array = sync_usec.duplicate()
	sorted.sort()
	var p50: float = float(sorted[sorted.size() / 2]) / 1000.0 if sorted.size() > 0 else 0.0
	return {"mech": mech, "cull": cull, "stage": stage, "far_mode": far_mode, "far_packs": far_count, "a_instances_live": a_live,
		"mirrors_live": mirror_live, "adopted": stats, "sync_ms_p50": snappedf(p50, 0.0001), "standins": standins,
		"pictures": pictures, "marks": marks, "boards": boards, "picture_far_m": picture_far_m, "force_picture": force_picture}


func clear() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	for e: Dictionary in entries:
		for m: Dictionary in e["mirrors"]:
			RenderingServer.free_rid(m["rid"])
		(e["mirrors"] as Array).clear()
		(e["a"] as Array).clear()
		for rid: RID in (e["life"] as Dictionary).get("lights", []):
			RenderingServer.free_rid(rid)
		(e["life"] as Dictionary).erase("lights")
	entries.clear()
	world = null


func _exit_tree() -> void:
	clear()
