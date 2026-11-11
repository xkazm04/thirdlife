extends "res://kernel/world/draw/draw_pictures.gd"
## The draw layer of a world, layer 3 of 4 (P6): which far picture a pack shows, and its signs of life: a mark per
## moving body, a copy of its smoke, a few lights, the real score on its kit scoreboards. Reads a pack, never writes
## it. draw/FAR.md has the rules.


func _ensure_pictures(e: Dictionary) -> void:
	var t0: int = Time.get_ticks_usec()
	var want: Array = ["mid", "far"]
	if force_picture == "still":
		want.append("still")
	var missing: Array = []
	for k: String in want:
		if not (e["pics"] as Dictionary).has(k):
			missing.append(k)
	if not is_instance_valid(e["holder"]):
		return
	if not missing.is_empty() and (e["pics"] as Dictionary).is_empty() and _cache_load(e, missing):
		missing = []                    # P13: the pictures of this very pack directory, from an earlier run
	var built: bool = bool((e["holder"] as Node).get("loaded"))
	if not missing.is_empty() and built and not e.has("build"):
		_build_pictures(e, missing)
	if built and (e["life"] as Dictionary).is_empty():
		_build_life(e)
	# P13: what the frame in which a pack first goes far pays here (pictures started or loaded, marks found)
	stats["far_start_ms_max"] = maxf(float(stats.get("far_start_ms_max", 0.0)), snappedf(float(Time.get_ticks_usec() - t0) / 1000.0, 0.01))


# ------------------------------------------------------------------------------------------------ P6: which picture, signs of life
## Everything this layer made for a pack (pictures, marks, smoke, lights, score boards) is placed like the pack: once,
## and again when the stage changes.
func _place_own(e: Dictionary) -> void:
	for k: String in (e["pics"] as Dictionary):
		_place_standin(e, (e["pics"] as Dictionary)[k])
	var life: Dictionary = e["life"]
	for mm: Variant in life.get("mms", []):
		_place_free(e, mm)
	for s: Variant in life.get("smoke", []):
		_place_free(e, s)
	var lights: Array = life.get("lights", [])
	for k: int in lights.size():
		RenderingServer.instance_set_transform(lights[k], (e["rel"] as Transform3D) * ((life["light_t"] as Array)[k] as Transform3D))
	for b: Dictionary in (e["boards"] as Dictionary).get("list", []):
		_place_free(e, b["node"])


func _place_free(e: Dictionary, g: GeometryInstance3D) -> void:
	g.set_instance_shader_parameter(PLOT, _plot_v4(e["rel"]))
	g.extra_cull_margin = NEVER


## The picture a far pack shows now: "mid" or "far" by the camera's distance to the plot edge, with a margin both ways.
func _kind_for(e: Dictionary) -> String:
	if force_picture == "still" or force_picture == "mid" or force_picture == "far":
		return force_picture
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return "mid"
	var d: float = cam.global_position.distance_to((e["rel"] as Transform3D).origin) - float(e["radius"])
	if str(e["kind"]) == "far":
		return "far" if d > picture_far_m - picture_margin_m else "mid"
	return "far" if d > picture_far_m + picture_margin_m else "mid"


func _show(e: Dictionary) -> void:
	var far: bool = bool(e["far"])
	var pics: Dictionary = e["pics"]
	var kind: String = _kind_for(e) if far else ""
	if far and not pics.has(kind):
		for k: String in ["mid", "far", "still"]:
			if pics.has(k):
				kind = k
				break
	e["kind"] = kind
	for k: String in pics:
		(pics[k] as Node3D).visible = k == kind
	var life: Dictionary = e["life"]
	var alive: bool = far and kind != "still"
	for mm: Variant in life.get("mms", []):
		(mm as Node3D).visible = alive
		life["dirty"] = true
	for s: Variant in life.get("smoke", []):
		(s as Node3D).visible = alive
	for rid: RID in life.get("lights", []):
		RenderingServer.instance_set_visible(rid, far and kind == "mid")
	for b: Dictionary in (e["boards"] as Dictionary).get("list", []):
		(b["node"] as Node3D).visible = kind != "still"          # near, mid and far: one score at every distance


## Once per drawn frame and pack: the score on its boards and the marks of its moving bodies follow the pack's OWN
## ticks (a backdrop game ticks one world tick in `slice`, so its picture moves at that pace); a far pack changes
## between its two pictures when the camera crosses the threshold. Reads the pack, never writes it.
func _life(e: Dictionary, _i: int) -> void:
	var holder: Variant = e["holder"]
	var alive: bool = is_instance_valid(holder)
	var tick: int = -1
	if alive:
		var fd: Variant = (holder as Node).get("frames_done")
		tick = int(fd) if fd != null else Engine.get_physics_frames()
	var boards: Dictionary = e["boards"]
	if alive and not boards.has("list") and tick >= 2:
		_build_boards(e)
		_show(e)
		boards = e["boards"]
	if alive and not (boards.get("list", []) as Array).is_empty() and tick != int(boards.get("tick", -1)):
		boards["tick"] = tick
		_refresh_boards(boards)
	if not bool(e["far"]):
		return
	var kind: String = _kind_for(e)
	if kind != str(e["kind"]) and (e["pics"] as Dictionary).has(kind):
		_show(e)
	# P13: the far picture casts its shadow only where the style's shadow can still reach it (FAR.md rule 9); beyond,
	# a caster costs a pass per cascade and shows nothing
	var far_pic: Variant = (e["pics"] as Dictionary).get("far")
	if far_pic != null and str(e["kind"]) == "far":
		var shade: bool = _edge_dist(e) < far_shadow_m
		if shade != bool(e.get("far_shade", false)) or not e.has("far_shade"):
			e["far_shade"] = shade
			(far_pic as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shade else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var life: Dictionary = e["life"]
	if not life.has("mms") or str(e["kind"]) == "still":
		return
	if alive and not life.has("frozen") and (tick != int(life["tick"]) or bool(life["dirty"])):
		life["tick"] = tick
		_update_marks(e, holder)
	_draw_marks(e)


func _find_movers(n: Node, out: Array) -> void:
	if n is Node3D and not (n as Node3D).visible:
		return
	if (n is PhysicsBody3D and not (n is StaticBody3D) and not (n is RigidBody3D and (n as RigidBody3D).freeze)) or n is Skeleton3D:
		out.append(n)
		return
	for c: Node in n.get_children():
		_find_movers(c, out)


func _meshes_under(n: Node, out: Array) -> void:
	if n is Node3D and not (n as Node3D).visible:
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c: Node in n.get_children():
		_meshes_under(c, out)


func _find_class(n: Node, kind: String, out: Array) -> void:
	if n is Node3D and not (n as Node3D).visible:
		return
	if n.is_class(kind):
		out.append(n)
	for c: Node in n.get_children():
		_find_class(c, kind, out)


func _find_kit(n: Node, kind: String, out: Array) -> void:
	if n is Node3D and str(n.get_meta(&"tl_kind", "")) == kind:
		out.append(n)
	for c: Node in n.get_children():
		_find_kit(c, kind, out)


func _find_rules(n: Node) -> TLRules:
	if n is TLRules:
		return n as TLRules
	for c: Node in n.get_children():
		var r: TLRules = _find_rules(c)
		if r != null:
			return r
	return null


## The signs of life of a pack's far pictures. Marks: one box per moving body (a body that is not static and not
## frozen, or a skeleton that stands under none), as large as the body's meshes and in the colour most of the largest
## mesh has; all of a pack's marks are ONE multimesh. Smoke: a copy of up to `smoke_max` of its standing particle
## emitters (a copy, because a hidden emitter stops). Lights: the `mid_lights` strongest, as a second server instance.
func _build_life(e: Dictionary) -> void:
	var holder: Node3D = e["holder"]
	var inv: Transform3D = holder.global_transform.affine_inverse()
	var life: Dictionary = {"movers": [], "tick": -1, "at": 0, "dirty": true}
	e["life"] = life
	var found: Array = []
	_find_movers(holder, found)
	var movers: Array = life["movers"]
	for n: Node3D in found:
		if movers.size() >= marks_max:
			break
		var meshes: Array = []
		_meshes_under(n, meshes)
		if meshes.is_empty():
			continue
		var ninv: Transform3D = n.global_transform.affine_inverse()
		var box: AABB = AABB()
		var best: MeshInstance3D = null
		var best_size: float = -1.0
		for mi: MeshInstance3D in meshes:
			var b: AABB = (ninv * mi.global_transform) * mi.mesh.get_aabb()
			box = b if best == null else box.merge(b)
			if best == null or b.size.length() > best_size:
				best = mi
				best_size = b.size.length()
		var rigs: Array = []
		_find_class(n, "Skeleton3D", rigs)
		var fig: bool = not rigs.is_empty()
		if fig:
			# a figure: its rest pose spreads its arms (and a stick); the mark is a slim figure of its height (P13)
			var w: float = clampf(0.36 * box.size.y, 0.4, maxf(0.4, minf(box.size.x, box.size.z)))
			var c: Vector3 = box.get_center()
			box = AABB(Vector3(c.x - w * 0.5, box.position.y, c.z - w * 0.3), Vector3(w, box.size.y, w * 0.6))
		movers.append({"node": n, "box": box, "col": _mark_colour(best), "t": Transform3D.IDENTITY, "p": Transform3D.IDENTITY,
			"fig": fig, "gone": true, "mm": 0, "k": 0})
	# P13: ONE multimesh per pack, as in P6 (a second one cost a draw call per pack and pass): its mark is the slim
	# figure when most of its moving bodies are rigs (hockey: six skaters and a puck), else the box (draw/FAR.md rule 3)
	var figs: int = movers.filter(func(m: Dictionary) -> bool: return bool(m["fig"])).size()
	var as_fig: bool = figs * 2 > movers.size()
	for m: Dictionary in movers:
		m["fig"] = as_fig
	var mms: Array = []
	for want_fig: bool in [as_fig]:
		var mine: Array = movers
		if mine.is_empty():
			continue
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _mark_mesh(want_fig)
		mm.instance_count = mine.size()
		for k: int in mine.size():
			(mine[k] as Dictionary)["mm"] = mms.size()
			(mine[k] as Dictionary)["k"] = k
			mm.set_instance_transform(k, HIDDEN)
			mm.set_instance_color(k, ((mine[k] as Dictionary)["col"] as Color).srgb_to_linear())
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = ("Figures_" if want_fig else "Marks_") + String(holder.name)
		mmi.multimesh = mm
		mmi.visible = false
		add_child(mmi)
		_place_free(e, mmi)
		mms.append(mmi)
	if not mms.is_empty():
		life["mms"] = mms
	var smoke: Array = []
	var emitters: Array = []
	_find_class(holder, "CPUParticles3D", emitters)
	for p: CPUParticles3D in emitters:
		if smoke.size() >= smoke_max:
			break
		if p.get_script() != null or p.get_child_count() > 0 or not p.emitting or p.one_shot or _style_only(p) != 1 or _under_moving_body(p, holder):
			continue
		var copy: CPUParticles3D = p.duplicate(0) as CPUParticles3D
		if copy == null:
			continue
		copy.name = "Smoke_%s_%d" % [String(holder.name), smoke.size()]
		copy.transform = inv * p.global_transform
		copy.visible = false
		add_child(copy)
		_place_free(e, copy)
		smoke.append(copy)
	life["smoke"] = smoke
	var lamps: Array = []
	_find_class(holder, "OmniLight3D", lamps)
	_find_class(holder, "SpotLight3D", lamps)
	lamps = lamps.filter(func(l: Light3D) -> bool: return not _under_moving_body(l, holder))
	lamps.sort_custom(func(a: Light3D, b: Light3D) -> bool: return a.light_energy * float(a.get("omni_range") if a is OmniLight3D else a.get("spot_range")) > b.light_energy * float(b.get("omni_range") if b is OmniLight3D else b.get("spot_range")))
	var lights: Array = []
	var light_t: Array = []
	for l: Light3D in lamps:
		if lights.size() >= mid_lights:
			break
		var rid: RID = RenderingServer.instance_create2(l.get_base(), scenario)
		var lt: Transform3D = inv * l.global_transform
		RenderingServer.instance_set_transform(rid, (e["rel"] as Transform3D) * lt)
		RenderingServer.instance_set_visible(rid, false)
		lights.append(rid)
		light_t.append(lt)
	life["lights"] = lights
	life["light_t"] = light_t


## The colour of a mark: the palette column most vertices of the body's largest mesh carry (with their tint), or the
## colour of a flat toon material.
func _mark_colour(mi: MeshInstance3D) -> Color:
	var mat: Material = mi.get_active_material(0) if mi.mesh.get_surface_count() > 0 else null
	if mat != null and mat == _pal:
		var a: Array = mi.mesh.surface_get_arrays(0)
		var cu: Variant = a[Mesh.ARRAY_CUSTOM0]
		var col: Variant = a[Mesh.ARRAY_COLOR]
		if cu is PackedFloat32Array and (cu as PackedFloat32Array).size() >= 4:
			var f: PackedFloat32Array = cu
			var n: int = f.size() / 4
			var has_c: bool = col is PackedColorArray and (col as PackedColorArray).size() == n
			var votes: Dictionary = {}       # palette column -> [count, tint r, g, b summed]
			var step: int = maxi(1, n / 96)
			var k: int = 0
			while k < n:
				var idx: int = int(f[k * 4 + 3] + 0.5) / 16
				var tint: Color = (col as PackedColorArray)[k] if has_c else Color.WHITE
				var v: Array = votes.get(idx, [0, 0.0, 0.0, 0.0])
				votes[idx] = [int(v[0]) + 1, float(v[1]) + tint.r, float(v[2]) + tint.g, float(v[3]) + tint.b]
				k += step
			var best: int = -1
			var best_n: int = 0
			for idx: int in votes:
				if int((votes[idx] as Array)[0]) > best_n:
					best = idx
					best_n = int((votes[idx] as Array)[0])
			if best >= 0:
				if _pal_cols.is_empty():
					for key: String in TLStyle.palette():
						_pal_cols[TLStyle.index(key)] = TLStyle.color(key)
				var lin: Color = (_pal_cols.get(best, Color(0.6, 0.6, 0.6)) as Color).srgb_to_linear()
				var w: Array = votes[best]
				return Color(lin.r * float(w[1]) / float(best_n), lin.g * float(w[2]) / float(best_n), lin.b * float(w[3]) / float(best_n)).linear_to_srgb()
	elif mat is ShaderMaterial and (mat as ShaderMaterial).shader == (_pal as ShaderMaterial).shader:
		var lut: Variant = (mat as ShaderMaterial).get_shader_parameter(&"pal_lut")
		if lut is Texture2D:
			var img: Image = (lut as Texture2D).get_image()
			if img != null and img.get_width() > 0:
				var px: Color = img.get_pixel(0, 0)
				return Color(px.r, px.g, px.b).linear_to_srgb()
	return Color(0.55, 0.55, 0.6)


## The unit mesh of a mark (-0.5..0.5 on every axis; the mark's box scales it): a box, or a slim figure (legs, a
## body that narrows to the shoulders, a head), so a skater larger than about 12 pixels reads as a person (P13).
func _mark_mesh(fig: bool) -> ArrayMesh:
	if fig and _figure != null:
		return _figure
	if not fig and _mark != null:
		return _mark
	var mk: TLMesh = TLMesh.new(1)
	if not fig:
		mk.box(Vector3.ONE, "white")
		_mark = mk.build("draw_mark")
		return _mark
	# the unit box is scaled anisotropically (a mark is about 0.36 of its height wide): parts are boxes and an ellipsoid
	mk.box(Vector3(0.34, 0.47, 0.62), "white", Color.WHITE, 0.0, Vector3(-0.21, -0.265, 0.0))       # legs
	mk.box(Vector3(0.34, 0.47, 0.62), "white", Color.WHITE, 0.0, Vector3(0.21, -0.265, 0.0))
	mk.box(Vector3(1.0, 0.42, 0.8), "white", Color.WHITE, 0.0, Vector3(0.0, 0.03, 0.0))            # body to the shoulders
	mk.blob(Vector3(0.32, 0.105, 0.5), 0, 0.0, "white", Color.WHITE, 0.0, Vector3(0.0, 0.385, 0.0))  # head
	_figure = mk.build("draw_figure")
	return _figure


## The pack has ticked: every mark's last two known places move one step (the place shown before becomes "p", the new
## one "t"). `_draw_marks` draws between them on every frame. Reads the pack, never writes it.
func _update_marks(e: Dictionary, holder: Node3D) -> void:
	var life: Dictionary = e["life"]
	var movers: Array = life["movers"]
	var inv: Transform3D = holder.global_transform.affine_inverse()
	var all: bool = bool(life["dirty"]) or movers.size() <= 96
	var first: bool = bool(life["dirty"])
	life["dirty"] = false
	var now: float = _now_frames()
	life["span"] = clampf(now - float(life.get("tick_at", now - 1.0)), 1.0, 32.0)
	life["tick_at"] = now
	life["settled"] = false
	var at: int = int(life["at"])
	for step: int in (movers.size() if all else 96):
		at = (at + 1) % movers.size()
		var m: Dictionary = movers[at]
		var node: Variant = m["node"]
		if not is_instance_valid(node) or not (node as Node3D).visible:
			m["gone"] = true
			continue
		var t: Transform3D = inv * (node as Node3D).global_transform
		var was_gone: bool = bool(m["gone"])
		m["p"] = t if (was_gone or first or not all) else m["t"]       # more than 96 bodies: they step (round robin)
		m["t"] = t
		m["gone"] = false
	life["at"] = at


func _now_frames() -> float:
	return float(Engine.get_physics_frames()) + Engine.get_physics_interpolation_fraction()


## Every drawn frame of a far pack: each mark between its last two known places, by the share of the pack's own tick
## interval that has passed since the last tick (a backdrop game ticked one tick in 8 is drawn moving smoothly, one
## interval behind). Its size grows with distance, smoothly, to `far_mark_scale` (no step at the change of picture).
func _draw_marks(e: Dictionary) -> void:
	var life: Dictionary = e["life"]
	var scale: float = _mark_scale(e)
	var alpha: float = clampf((_now_frames() - float(life.get("tick_at", 0.0))) / float(life.get("span", 1.0)), 0.0, 1.0)
	if bool(life.get("settled", false)) and absf(scale - float(life.get("scale", 0.0))) < 0.002:
		return
	life["settled"] = alpha >= 1.0 or life.has("frozen")
	life["scale"] = scale
	var shade: bool = scale < 1.001 and _edge_dist(e) < mark_shadow_m
	if shade != bool(life.get("shade", true)) or not life.has("shade"):
		life["shade"] = shade      # a mark's shadow is a few pixels only close up; beyond, it costs a pass per cascade
		for mmi: Variant in life["mms"]:
			(mmi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shade else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mms: Array = life["mms"]
	for m: Dictionary in life["movers"]:
		var mm: MultiMesh = (mms[int(m["mm"])] as MultiMeshInstance3D).multimesh
		if bool(m["gone"]):
			mm.set_instance_transform(int(m["k"]), HIDDEN)
			continue
		var t: Transform3D = (m["p"] as Transform3D).interpolate_with(m["t"], alpha) if alpha < 1.0 else m["t"]
		var box: AABB = m["box"]
		var size: Vector3 = (box.size * scale).max(Vector3.ONE * mark_min * scale)
		mm.set_instance_transform(int(m["k"]), t * Transform3D(Basis.from_scale(size), box.get_center()))


## 1 near the threshold's middle side, `far_mark_scale` well beyond it, smooth between (camera to plot edge).
func _mark_scale(e: Dictionary) -> float:
	if force_picture == "far":
		return far_mark_scale
	if force_picture == "mid":
		return 1.0
	return lerpf(1.0, far_mark_scale, smoothstep(picture_far_m - 90.0, picture_far_m + 210.0, _edge_dist(e)))


func _edge_dist(e: Dictionary) -> float:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return picture_far_m
	return cam.global_position.distance_to((e["rel"] as Transform3D).origin) - float(e["radius"])


## `all`: the pack was built again (new nodes): everything is found again when it is needed. Otherwise the pack's
## nodes are gone (ledger): its lights go, its marks and its score stay where they were.
func _drop_life(e: Dictionary, all: bool) -> void:
	var life: Dictionary = e["life"]
	for rid: RID in life.get("lights", []):
		RenderingServer.free_rid(rid)
	life.erase("lights")
	if not all:
		if not life.is_empty():
			life["frozen"] = true
		(e["boards"] as Dictionary)["rules"] = null
		return
	for mm: Variant in life.get("mms", []):
		(mm as Node).queue_free()
	for s: Variant in life.get("smoke", []):
		(s as Node).queue_free()
	for b: Dictionary in (e["boards"] as Dictionary).get("list", []):
		(b["node"] as Node).queue_free()
	e["life"] = {}
	e["boards"] = {}


## The score a far visitor can read. The kit's scoreboard is a prop with fixed digits; where a pack placed one and has
## a TLRules, this layer lays a panel with the pack's real score over its face. Read from the rules object when the
## pack has ticked; nothing is connected to it.
func _build_boards(e: Dictionary) -> void:
	var holder: Node3D = e["holder"]
	var boards: Dictionary = {"list": [], "rules": _find_rules(holder), "shown": "", "tick": -1}
	e["boards"] = boards
	if boards["rules"] == null:
		return
	var found: Array = []
	_find_kit(holder, "scoreboard", found)
	var inv: Transform3D = holder.global_transform.affine_inverse()
	for n: Node3D in found:
		if (boards["list"] as Array).size() >= 4:
			break
		if n.has_meta(&"tl_score_bound"):
			continue                  # P13: the pack bound it itself (TLKitSite.bind_scoreboard): it tells the truth already
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Score_%s_%d" % [String(holder.name), (boards["list"] as Array).size()]
		mi.transform = inv * n.global_transform
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_place_free(e, mi)
		if float(e["radius"]) > 0.0:
			mi.set_instance_shader_parameter(CLIP, Vector4(float(e["radius"]), float(e["rim"]), rim_band, 0.0))    # lifted at the rim like the prop under it
		(boards["list"] as Array).append({"node": mi})


func _refresh_boards(boards: Dictionary) -> void:
	var rules: Variant = boards["rules"]
	if not is_instance_valid(rules):
		return
	var sc: Dictionary = (rules as TLRules).scores
	var sides: Array = sc.keys()
	var a: int = int(sc[sides[0]]) if sides.size() > 0 else 0
	var b: int = int(sc[sides[1]]) if sides.size() > 1 else -1
	var text: String = "%d:%d" % [a, b]
	if text == str(boards["shown"]):
		return
	boards["shown"] = text
	var mk: TLMesh = TLKitSite._score_face(a, b)        # P13: the kit's face (it was drawn here)
	var mesh: ArrayMesh = mk.build("draw_score")
	for bd: Dictionary in boards["list"]:
		((bd["node"]) as MeshInstance3D).mesh = mesh
