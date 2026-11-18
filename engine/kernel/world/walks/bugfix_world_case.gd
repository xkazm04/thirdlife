extends SceneTree
## bugfix-37 lane world: the selftest cases `ground.*` of tools/selftest.d/320-bugfix-world.sh. Headless; the terrain is
## built as in a window (TLStyle.set_headless(false): landscape.gd `build` makes no terrain and no visitor's space under a
## headless style). Prints one line per case: `BFWORLD <case> ok|fail <detail>`; a case with no line is a FAIL there.
##   ledger_shapes   D9: the world's copy of a pack's box collider keeps its shape when the pack's holder is freed
##                   (copied at once and in slices)
##   shut_pad_solid  D3: a plot whose game has not arrived (its hole shut, the pad drawn) has ground under the pad; when
##                   the game's colliders are copied in (draw/view_seam.gd `copy_colliders`) the pad goes; a game built
##                   with the landscape gets no pad
##   rotated_cover   D4: a 40 x 90 m deck turned 45 degrees covers a third of the rim, as unturned (no hole cut)
##   crossing_faces  D13: a 100 m plane of two triangles over a 40 m plot is kept in both far pictures
##   flat_holes      D16: the flat ground (`--landscape=off`) registers its material: a hole can be shut there
##   bridge_end      Q15: a road that ends 16 m from the river builds (no bridge)
##   pad_lift        Q17: without `pad_h` a pad stands at the pack's rim height, not at the lifted plot origin
##   road_width      Q21: every road is graded with its own half width

const Space: GDScript = preload("res://kernel/world/terrain/world_space.gd")
const Landscape: GDScript = preload("res://kernel/world/landscape.gd")
const DrawBase: GDScript = preload("res://kernel/world/draw/draw_base.gd")
const Draw: GDScript = preload("res://kernel/world/draw/draw.gd")
const Seam: GDScript = preload("res://kernel/world/draw/view_seam.gd")
const Terrain: GDScript = preload("res://kernel/world/terrain/village_terrain.gd")

const QUIET: Dictionary = {"relief": 0, "trees": 0, "broadleaf": 0, "rocks": 0, "bushes": 0, "belt": 0, "mesas": 0,
	"soft_patches": 0, "plain_clumps": 0, "edges_now": true}


class Viewer extends Node:
	var world: Node = null
	var draw: Node = null
	var landscape: Node3D = Node3D.new()
	var has_ground: Array = [true]
	var radii: Array = [25.0]
	var _arrived: Dictionary = {}


class World extends Node:
	var packs: Array = []


class Holder extends Node3D:
	var loaded: bool = true
	var pack_dir: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _line(name: String, why: Array, ok_detail: String) -> void:
	print("BFWORLD %s %s %s" % [name, "ok" if why.is_empty() else "fail", ok_detail if why.is_empty() else "; ".join(why)])


func _box_body(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = at
	parent.add_child(body)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)


func _run() -> void:
	TLStyle.set_headless(false)
	await _ledger_shapes()
	_shut_pad_solid()
	_rotated_cover()
	_crossing_faces()
	_flat_holes()
	_bridge_end()
	_pad_lift()
	_road_width()
	quit()


func _ledger_shapes() -> void:
	var why: Array = []
	var got: Array = []
	for sliced: bool in [false, true]:
		var holder: Node3D = Node3D.new()
		root.add_child(holder)
		_box_body(holder, Vector3(6, 1, 6), Vector3.ZERO)
		var sp: RefCounted = Space.new()
		if sliced:
			var job: Dictionary = sp.call("begin_pack", holder, Transform3D.IDENTITY, 10.0, 0.0, 0.0)
			while not bool(sp.call("step_pack", job, 2000)):
				pass
			job.clear()
		else:
			sp.call("add_pack", holder, Transform3D.IDENTITY, 10.0, 0.0, 0.0)
		sp.call("finish")
		var before: float = float(sp.call("ground_at", 0.0, 0.0, 4.0))
		holder.free()
		await physics_frame
		await physics_frame
		var after: float = float(sp.call("ground_at", 0.0, 0.0, 4.0))
		got.append("%s %.2f -> %s" % ["sliced" if sliced else "at once", before, str(snappedf(after, 0.01))])
		if not (is_equal_approx(before, 0.5) and is_equal_approx(after, 0.5)):
			why.append("%s copy: ground %.2f before the holder is freed, %s after (want 0.5 both)" % ["sliced" if sliced else "immediate", before, str(after)])
		sp.call("free_all")
	_line("ground.ledger_shapes", why, "a pack's 6 m box floor in the world's copy, top y before -> after its holder is freed: %s" % ", ".join(got))


func _shut_pad_solid() -> void:
	var why: Array = []
	var view: Viewer = Viewer.new()
	root.add_child(view)
	view.add_child(view.landscape)
	view.draw = Draw.new()
	view.draw.get("entries").append({"pics": {}})
	Landscape.call("build", view.landscape, [Transform3D.IDENTITY], view.radii, view.has_ground, QUIET)
	Seam.call("shut_holes", view)
	var hole: Vector4 = ((view.landscape.get_meta(&"tl_ground_mat") as ShaderMaterial).get_shader_parameter(&"tl_holes") as Array)[0]
	var ws: RefCounted = view.landscape.get_meta(&"tl_space")
	var visible_y: float = float((view.landscape.get_meta(&"tl_terrain") as RefCounted).call("gy", 0.0, 0.0))
	var support: float = float(ws.call("ground_at", 0.0, 0.0, 10.0))
	var feet: Vector3 = Vector3(0.0, visible_y, 0.0)
	ws.call("place", feet)
	ws.call("rest")
	for tick: int in 60:
		feet = (ws.call("drive", feet, Vector3.ZERO, false, false) as Dictionary)["pos"]
	if hole.z != 0.0:
		why.append("the hole is not shut (radius %.1f)" % hole.z)
	if is_nan(support) or absf(support - visible_y) > 0.05 or absf(feet.y - visible_y) > 0.05:
		why.append("shut pad drawn at y %.2f: ground under it %s, feet after 60 ticks %.2f" % [visible_y, str(support), feet.y])
	# the game arrives: its colliders are copied in (a 30 m floor 0.3 m above the pad), the pad goes
	var holder: Node3D = Node3D.new()
	root.add_child(holder)
	_box_body(holder, Vector3(30, 1, 30), Vector3(0, -0.2, 0))
	ws.set("tag", "pack 0")                                   # as view.gd does before `begin_pack`
	var copies: Array = [{"i": 0, "job": ws.call("begin_pack", holder, Transform3D.IDENTITY, 25.0, 0.0, 9.0)}]
	var pads_before: float = float(ws.call("ground_at", 20.0, 0.0, 10.0))
	Seam.call("copy_colliders", copies, ws, [Transform3D.IDENTITY], view.radii, Vector3(0, 0, 0))
	var floor_y: float = float(ws.call("ground_at", 0.0, 0.0, 10.0))
	var pads_after: float = float(ws.call("ground_at", 20.0, 0.0, 10.0))
	if not copies.is_empty() or is_nan(floor_y) or absf(floor_y - 0.3) > 0.01 or is_nan(pads_before) or not is_nan(pads_after):
		why.append("after the copy: %d copies left, floor %s (want 0.3), pad 20 m out %s -> %s (want ground -> none)" % [copies.size(), str(floor_y), str(pads_before), str(pads_after)])
	holder.free()
	var pad_faces: int = int((ws.get("stats") as Dictionary).get("pad_faces", 0))
	view.draw.free()
	view.free()
	# a game that is there when the landscape is built: its colliders are copied by `build`, no pad
	var view2: Viewer = Viewer.new()
	root.add_child(view2)
	view2.add_child(view2.landscape)
	var w: World = World.new()
	view2.world = w
	view2.add_child(w)
	var h2: Holder = Holder.new()
	w.add_child(h2)
	w.packs.append(h2)
	_box_body(h2, Vector3(30, 1, 30), Vector3(0, -0.2, 0))
	Landscape.call("build", view2.landscape, [Transform3D.IDENTITY], view2.radii, view2.has_ground, QUIET)
	var ws2: RefCounted = view2.landscape.get_meta(&"tl_space")
	var pad2: int = int((ws2.get("stats") as Dictionary).get("pad_faces", 0))
	var out2: float = float(ws2.call("ground_at", 20.0, 0.0, 10.0))
	if pad2 != 0 or not is_nan(out2):
		why.append("a game built with the landscape got a pad: %d triangles, ground 20 m out %s" % [pad2, str(out2)])
	view2.free()
	_line("ground.shut_pad_solid", why, "shut hole radius %.1f, pad y %.2f, ground under it %.2f, feet after 60 idle ticks %.2f; %d pad triangles; after the game's copy: floor %.2f, pad 20 m out %.2f -> none; a game built with the landscape: no pad" % [
		hole.z, visible_y, support, feet.y, pad_faces, floor_y, pads_before])


func _rotated_cover() -> void:
	var why: Array = []
	var holder: Node3D = Node3D.new()
	root.add_child(holder)
	var deck: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(40, 90)
	plane.subdivide_depth = 17
	plane.subdivide_width = 7
	deck.mesh = plane
	holder.add_child(deck)
	var got: Array = []
	for yaw: float in [0.0, 45.0]:
		deck.rotation_degrees.y = yaw
		var measured: float = float(DrawBase.call("ground_cover", holder, 40.0, [deck]))
		var real_hits: int = 0
		for radius: float in [38.0, 42.0]:
			for k: int in 72:
				var angle: float = TAU * float(k) / 72.0
				var local: Vector3 = deck.to_local(Vector3(radius * cos(angle), 0, radius * sin(angle)))
				if absf(local.x) <= 20.0 and absf(local.z) <= 45.0:
					real_hits += 1
		var owns: bool = not is_nan(float(DrawBase.call("edge_height", holder, 40.0)))
		got.append("yaw %d: %d/144 under the deck, cover %.3f, hole %s" % [int(yaw), real_hits, measured, "cut" if owns else "none"])
		if owns or absf(measured - float(real_hits) / 144.0) > 0.03:
			why.append("yaw %d: %d/144 rim points under the deck, cover reported %.3f, hole %s" % [int(yaw), real_hits, measured, "cut" if owns else "none"])
	holder.free()
	_line("ground.rotated_cover", why, "; ".join(got))


func _crossing_faces() -> void:
	var why: Array = []
	var draw: Node3D = Draw.new()
	root.add_child(draw)
	draw.set_process(false)
	draw.set("pic_worker", false)
	draw.set("_pal", TLStyle.material(&"white"))
	var got: Array = []
	for subdivisions: int in [0, 3]:
		var holder: Holder = Holder.new()
		root.add_child(holder)
		var ground: MeshInstance3D = MeshInstance3D.new()
		var mesh: PlaneMesh = PlaneMesh.new()
		mesh.size = Vector2(100, 100)
		mesh.subdivide_depth = subdivisions
		mesh.subdivide_width = subdivisions
		ground.mesh = mesh
		ground.material_override = draw.get("_pal")
		holder.add_child(ground)
		var entry: Dictionary = {"holder": holder, "radius": 40.0, "rim": 0.0, "ground": false,
			"rel": Transform3D.IDENTITY, "pics": {}, "standin_info": {}}
		draw.call("_build_pictures", entry, ["mid", "far"])
		var info: Dictionary = entry["standin_info"]
		var mid: int = int((info.get("mid", {}) as Dictionary).get("tris", 0))
		var far: int = int((info.get("far", {}) as Dictionary).get("tris", 0))
		got.append("%d subdivisions: mid %d, far %d triangles" % [subdivisions, mid, far])
		if mid == 0 or far == 0:
			why.append("a 100 m plane of %d subdivisions over a 40 m plot: mid %d, far %d triangles" % [subdivisions, mid, far])
		holder.free()
	draw.free()
	_line("ground.crossing_faces", why, "; ".join(got))


func _flat_holes() -> void:
	var why: Array = []
	var view: Viewer = Viewer.new()
	root.add_child(view)
	view.add_child(view.landscape)
	view.draw = Draw.new()
	view.draw.get("entries").append({"pics": {}})
	Landscape.call("ground", view.landscape, [Transform3D.IDENTITY], view.radii, view.has_ground)
	var registered: bool = view.landscape.has_meta(&"tl_ground_mat")
	var before: float = -1.0
	var after: float = -1.0
	if registered:
		var gm: ShaderMaterial = view.landscape.get_meta(&"tl_ground_mat")
		before = ((gm.get_shader_parameter(&"tl_holes") as Array)[0] as Vector4).z
		Seam.call("shut_holes", view)
		after = ((gm.get_shader_parameter(&"tl_holes") as Array)[0] as Vector4).z
	if not registered or before <= 0.0 or after != 0.0:
		why.append("flat ground: material registered %s, hole radius %.1f -> %.1f after shut_holes (want > 0 -> 0)" % [str(registered), before, after])
	view.draw.free()
	view.free()
	_line("ground.flat_holes", why, "flat ground (--landscape=off): the material is on the landscape node; a pending plot's hole %.1f m -> %.1f m" % [before, after])


func _bridge_end() -> void:
	var why: Array = []
	var view: Viewer = Viewer.new()
	root.add_child(view)
	var land: Node3D = Node3D.new()
	view.add_child(land)
	var cfg: Dictionary = QUIET.duplicate()
	cfg.merge({"road": [[-30, 0], [0, 0]], "river": {"path": [[16, -20], [16, 20]], "half_m": 6}, "cell_m": 1, "margin_m": 8, "spurs": false})
	var st: Dictionary = Landscape.call("build", land, [Transform3D(Basis(), Vector3(-20, 0, 30))], [10.0], [false], cfg)
	var built: bool = st.has("terrain_verts") and land.has_meta(&"tl_terrain") and st.has("space")
	if not built:
		why.append("a road ending 16 m from the river: the build stopped (stats %s)" % str(st.keys()))
	view.free()
	_line("ground.bridge_end", why, "a road ending 16 m from the river: built, %s" % ("bridge %s m" % str(st["bridge_m"]) if st.has("bridge_m") else "no bridge"))


func _pad_lift() -> void:
	var why: Array = []
	var view: Viewer = Viewer.new()
	root.add_child(view)
	var w: World = World.new()
	view.world = w
	view.add_child(w)
	var holder: Node3D = Node3D.new()
	w.add_child(holder)
	w.packs.append(holder)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var sheet: PlaneMesh = PlaneMesh.new()
	sheet.size = Vector2(100, 100)
	sheet.subdivide_width = 49
	sheet.subdivide_depth = 49
	floor_mesh.mesh = sheet
	floor_mesh.position.y = 5.0
	holder.add_child(floor_mesh)
	var rim: float = float(DrawBase.call("edge_height", holder, 40.0))
	var plot: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, -rim, 0))      # view.gd: an authored plot at y 0, lifted
	var got: Array = []
	for explicit: bool in [true, false]:
		var land: Node3D = Node3D.new()
		view.add_child(land)
		var cfg: Dictionary = QUIET.duplicate()
		cfg["fence"] = false
		if explicit:
			cfg["pad_h"] = [0]
		Landscape.call("build", land, [plot], [40.0], [true], cfg)
		var pad: float = float((land.get_meta(&"tl_terrain") as RefCounted).call("gy", 45.0, 0.0))
		got.append("%s pad_h: pad %.2f" % ["with" if explicit else "without", pad])
		if absf(pad - (plot.origin.y + rim)) > 0.01:
			why.append("%s pad_h: pad at %.2f, the pack's rim at %.2f" % ["with" if explicit else "without", pad, plot.origin.y + rim])
		land.free()
	view.free()
	_line("ground.pad_lift", why, "a pack whose floor is 5 m up (rim %.2f, plot lifted to %.2f): %s" % [rim, plot.origin.y, ", ".join(got)])


func _road_width() -> void:
	var why: Array = []
	var narrow: Dictionary = {"pts": PackedVector2Array([Vector2(-30, 0), Vector2(-30, 2)]), "ys": PackedFloat32Array([2, 2]), "half": 2.0}
	var wide: Dictionary = {"pts": PackedVector2Array([Vector2(30, 0), Vector2(30, 2)]), "ys": PackedFloat32Array([20, 20]), "half": 9.0}
	var hs: Array = []
	for roads: Array in [[wide, narrow], [narrow, wide]]:
		var t: RefCounted = Terrain.new(7, Rect2(-50, -20, 100, 40), 1.0)
		t.set("relief", 0.0)
		t.set("roads", roads)
		t.call("build_grid")
		hs.append(float(t.call("gy", 38.0, 0.0)))        # inside the wide road, 8 m from its line
	if absf(float(hs[0]) - float(hs[1])) > 0.01 or absf(float(hs[0]) - 19.98) > 0.05:
		why.append("8 m from a 9 m half-width road at y 20: %.2f with it first, %.2f with a 2 m road first" % [hs[0], hs[1]])
	_line("ground.road_width", why, "8 m from a 9 m half-width road at y 20: %.2f listed first, %.2f listed after a 2 m road" % [hs[0], hs[1]])
