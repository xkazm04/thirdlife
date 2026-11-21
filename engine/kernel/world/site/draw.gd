extends Node3D
## S1. How a construction site looks (kernel/world/site.gd has the model). One node per site lot, a child of the
## landscape (re-based with it when a game is on stage), built by landscape.gd. Every frame it asks the world's site
## for the lot's view and builds its parts again only when that view changed. Drawing only: kit parts (TLKitSite) and
## TLMesh boxes in the style's palette, as the landscape draws; text is the job's own words.
##
## Read from 20 m: a sign by the gate (the job's title and "N of M built", or "This game could not
## be finished"); one bay per package in the plan's order, rising with its state (waiting: a slab and timber; building:
## walls and a scaffold; checking: higher walls, full scaffold, a beacon; on hold: a barricade; built: a finished
## house with a flag; failed: low walls behind red barricades); a crane that turns to the bay being built. When the
## game arrives the scaffold comes down: only the sign stays, and the game stands on the lot.

const STATE_WORD: Dictionary = {"queued": "waiting", "running": "building", "verifying": "checking", "blocked": "on hold",
	"promoted": "built", "failed": "failed"}

var site: RefCounted = null           # kernel/world/site.gd
var lot: int = -1
var radius: float = 20.0
var plot_radius: float = 20.0         # S4: the plot's radius (the landscape's pad); `radius` is the lot as it is now
var road_half_m := 2.6
var has_rails := true
var build_ms: float = 0.0             # S4: what the last build of the site's parts cost on the main thread
var _report_next: bool = false
var _shown: String = ""
var _parts: Node3D = null
var _crane: Node3D = null
var _target: float = 0.0              # where the crane's jib points (radians about the vertical)
var _bays_x: Array = []               # local x of every bay
var colliders: int = 0                # S2: how many bodies the site has in the world's space now
## S2: how high a bay's collider stands, by the package's state (a merged package: its house, 7.6 m)
const SOLID_H: Dictionary = {"queued": 1.2, "running": 3.4, "verifying": 5.4, "blocked": 1.9, "failed": 1.2, "promoted": 7.6}
var _bay_z: float = 0.0
## Night of 21 Nov 2026 (lane L1): the posts of the site's sign and of its plan board, [centre, size] in this node's
## (the gate's) frame, made solid with the rest in `_solid`: a walker passes under a board (its foot is 2 m up and more)
## but not through a post.
var _posts: Array = []
const POST_BOX: Vector3 = Vector3(0.3, 8.1, 0.3)
## Night of 21 Nov 2026 (lane L1, owner's B2: "the site fence follows the footprint"): while the game is being built
## the yard is fenced along its footprint, not a circle: the timber rail fence of the plots' entrances (TLKitSite
## `add_fence`, 1.2 m, a post every 3.4 m: a steel mesh fence of a 32 m lot measured 66 ms of worker time and 10,352 triangles, this one 36 ms and 3,696, busy machine) on the
## square of the lot's pad (landscape.gd pads a site plot with its footprint, a square of half side `radius` turned by
## the player's yaw), `HOARD_IN` m inside its edge, in the construction frame, open for `HOARD_GAP` m where the path
## from the gate meets it. Solid for the visitor (one box per straight stretch). It comes down when the game arrives.
const HOARD_IN: float = 1.0
const HOARD_GAP: float = 7.0
const HOARD_H: float = 1.2
var hoarding: int = 0                 # stretches of site fence in the last build (0 when the game is here)


## `centre`: the lot's centre on the ground (x, pad height, z); `gate`: the direction from the centre to its road
## (Vector2) or null; the node's +Z faces the gate.
static func make(site_: RefCounted, lot_: int, centre: Vector3, radius_: float, gate: Variant) -> Node3D:
	var n: Node3D = (load("res://kernel/world/site/draw.gd") as GDScript).new()
	n.name = "TLSite%d" % lot_
	n.set("site", site_)
	n.set("lot", lot_)
	n.set("radius", radius_)
	n.set("plot_radius", radius_)
	n.position = centre
	if gate != null:
		n.rotation.y = atan2((gate as Vector2).x, (gate as Vector2).y)
	return n


## landscape.gd: the lots that are construction sites with a plot are taken out of `lots` (they are drawn as plots,
## with the plot's pad and gate); returns them as [lot index, plot index, the world's site].
static func split_lots(parent: Node3D, lots: Array) -> Array:
	var view: Node = parent.get_parent()
	var world: Variant = view.get("world") if view != null else null
	var site: Variant = (world as Node).get("site") if world != null else null
	var out: Array = []
	if site == null:
		return out
	var plain: Array = []
	for k: int in lots.size():
		var sv: Dictionary = (site as RefCounted).call("view_of", k)
		if not sv.is_empty() and int(sv["plot"]) >= 0:
			out.append([k, int(sv["plot"]), site])
		else:
			plain.append(lots[k])
	lots.assign(plain)
	return out


## landscape.gd: one site node per construction site, on its plot's pad, facing its gate.
static func place(parent: Node3D, site_plots: Array, centres: Array, pad_h: Array, rad: Array, gates: Array, stats: Dictionary) -> void:
	for sp: Array in site_plots:
		var i: int = int(sp[1])
		var c: Vector2 = centres[i]
		var node := make(sp[2], int(sp[0]), Vector3(c.x, float(pad_h[i]), c.y), float(rad[i]), gates[i])
		var cfg: Dictionary = sp[2].world.walk.landscape
		node.set("road_half_m", float(cfg.get("road_half_m", 2.6)))
		node.set("has_rails", gates[i] != null and bool(cfg.get("fence", true)))
		parent.add_child(node)
		stats["sites"] = int(stats.get("sites", 0)) + 1


func _process(delta: float) -> void:
	if site == null:
		return
	if not _tasks.is_empty():
		_collect()
	var v: Dictionary = site.call("view_of", lot)
	var key: String = _key(v)
	if key != _shown:
		_shown = key
		_build(v)
	if _crane != null and is_instance_valid(_crane):
		var slew: Node3D = _crane.get_node_or_null("Slew") as Node3D
		if slew != null:
			slew.rotation.y = lerp_angle(slew.rotation.y, _target, clampf(delta * 0.8, 0.0, 1.0))


## S2. The site is solid: one box per bay (slab, walls or house, scaffold) and one for the crane's foot, in the world's
## space (terrain/world_space.gd) under the tag `site <lot>`, made again when the view changes and all taken away when
## the game arrives. Boxes use the construction frame (the gate frame for arch pillars). Rails always use the gate.
func _solid(boxes: Array, rails: PackedVector3Array, layout: Transform3D = Transform3D.IDENTITY, fence: PackedVector3Array = PackedVector3Array()) -> void:
	var land: Node = get_parent()
	if land == null or not land.has_meta(&"tl_space"):
		return
	var ws: RefCounted = land.get_meta(&"tl_space")
	var t: String = "site %d" % lot
	ws.call("remove_tag", t)
	var keep: String = str(ws.get("tag"))
	ws.set("tag", t)
	var xf: Transform3D = Transform3D(Basis(Vector3.UP, rotation.y), position)
	var box_frame := xf * layout
	for bx: Array in boxes:
		ws.call("add_box", box_frame.translated_local(bx[0]), bx[1])
	for bx: Array in _posts:
		ws.call("add_box", xf.translated_local(bx[0]), bx[1])
	for k: int in range(0, rails.size(), 2):
		ws.call("add_wall", PackedVector3Array([xf * rails[k], xf * rails[k + 1]]), 1.2)
	for k: int in range(0, fence.size(), 2):
		var d: Vector3 = fence[k + 1] - fence[k]
		var mid: Vector3 = (fence[k] + fence[k + 1]) * 0.5 + Vector3(0, HOARD_H * 0.5, 0)
		ws.call("add_box", xf * Transform3D(Basis(Vector3.UP, atan2(-d.z, d.x)), mid), Vector3(Vector2(d.x, d.z).length(), HOARD_H, 0.15))
	ws.set("tag", keep)
	var count := boxes.size() + _posts.size() + rails.size() / 2 + fence.size() / 2
	if count != colliders:
		print("[site] lot %d: scaffold colliders %d -> %d" % [lot, colliders, count])
	colliders = count


## The plot entrance rule in landscape.gd, in the site's gate-facing frame. The mesh and walls share endpoints.
func _rail_ends() -> PackedVector3Array:
	var rails := PackedVector3Array()
	if has_rails:
		var terr: RefCounted = get_parent().get_meta(&"tl_terrain")
		var gap := road_half_m * 0.8 + 2.0
		for side: float in [-1.0, 1.0]:
			for x: float in [gap, gap + clampf(radius * 0.24, 4.0, 10.0)]:
				var p := Vector3(x * side, 0, radius + 3.6)
				var v := transform * p
				p.y = terr.gy(v.x, v.z) - position.y
				rails.append(p)
	return rails


## B2 (21 Nov): the site fence's stretches, as pairs of ground points in this node's (the gate's) frame: the square of
## half side `radius - HOARD_IN` in the construction frame `layout`, walked round from one side of the gate's opening to
## the other (the opening is centred where the line from the centre to the gate meets the square), split at corners.
func _hoarding(layout: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var h: float = radius - HOARD_IN
	if h < HOARD_GAP:
		return out
	var g: Vector3 = layout.basis.inverse() * Vector3(0, 0, 1)
	var dir := Vector2(g.x, g.z).normalized()
	var at: Vector2 = dir * (h / maxf(absf(dir.x), absf(dir.y)))
	var sc: float = _perim_s(at, h)
	var s0: float = sc + HOARD_GAP * 0.5
	var s1: float = sc - HOARD_GAP * 0.5 + 8.0 * h
	var marks: Array = [s0]
	var c: float = (floorf(s0 / (2.0 * h)) + 1.0) * 2.0 * h
	while c < s1:
		marks.append(c)
		c += 2.0 * h
	marks.append(s1)
	var terr: Variant = get_parent().get_meta(&"tl_terrain") if get_parent() != null and get_parent().has_meta(&"tl_terrain") else null
	for k: int in marks.size() - 1:
		for s: float in [float(marks[k]), float(marks[k + 1])]:
			var q: Vector2 = _perim(s, h)
			var v: Vector3 = layout * Vector3(q.x, 0.0, q.y)
			if terr != null:
				var w: Vector3 = transform * v
				v.y = float((terr as RefCounted).call("gy", w.x, w.z)) - position.y
			out.append(v)
	return out


## A point of the square of half side `h` at `s` metres along its edge (from the corner (-h, -h), along +x first).
static func _perim(s: float, h: float) -> Vector2:
	s = fposmod(s, 8.0 * h)
	if s < 2.0 * h:
		return Vector2(-h + s, -h)
	if s < 4.0 * h:
		return Vector2(h, -h + (s - 2.0 * h))
	if s < 6.0 * h:
		return Vector2(h - (s - 4.0 * h), h)
	return Vector2(-h, h - (s - 6.0 * h))


static func _perim_s(p: Vector2, h: float) -> float:
	if absf(p.y + h) < 1e-3:
		return p.x + h
	if absf(p.x - h) < 1e-3:
		return 2.0 * h + p.y + h
	if absf(p.y - h) < 1e-3:
		return 4.0 * h + (h - p.x)
	return 6.0 * h + (h - p.y)


static func _hoarding_mesh(fence: PackedVector3Array) -> TLMesh:
	var mk: TLMesh = TLMesh.new(56)
	for k: int in range(0, fence.size(), 2):
		TLKitSite.add_fence(mk, fence[k], fence[k + 1], 3.4)
	return mk


static func _entrance_mesh(rails: PackedVector3Array, r: float, plot_r: float) -> TLMesh:
	var mk: TLMesh = TLMesh.new(55)
	for k: int in range(0, rails.size(), 2):
		TLKitSite.add_fence(mk, rails[k], rails[k + 1], 3.4)
	if plot_r - r > 1.0:
		var z0: float = r + 3.6 - 0.5
		var z1: float = plot_r + 1.0
		mk.quad_up(Vector3(-2.0, 0.06, z1), Vector3(2.0, 0.06, z1), Vector3(2.0, 0.06, z0), Vector3(-2.0, 0.06, z0), "dirt")
	return mk


static func _key(v: Dictionary) -> String:
	if v.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray([str(v["stage"]), str(v["title"]), str(v["arrived"]), str(v["job_state"]), str(v.get("radius", ""))])
	parts.append(str(v.get("yaw_deg", 0.0)))
	parts.append(str(v.get("phase_line", "")))     # 21 Nov, L3's PATCHES P1: the sign is built again when the phase moves
	for b: Dictionary in v["packages"]:
		parts.append("%s:%s:%s" % [str(b["id"]), str(b["state"]), str(b["merged"])])
	return "|".join(parts)


func _build(v: Dictionary) -> void:
	if _parts != null:
		_parts.free()
	_parts = Node3D.new()
	_parts.name = "Parts"
	add_child(_parts)
	_crane = null
	_posts = []
	if v.is_empty():
		return
	var t0: int = Time.get_ticks_usec()
	var was: float = radius
	radius = minf(float(v.get("radius", plot_radius)), plot_radius)
	var arrived: bool = bool(v["arrived"])
	var r: float = radius
	hoarding = 0
	_sign(v, arrived)
	var rails := _rail_ends()
	if not rails.is_empty() or plot_radius - r > 1.0:
		_show_mesh("entrance %s %s" % [r, plot_radius], _entrance_mesh.bind(rails, r, plot_radius), "site_rails")
	if arrived:
		_arrived_dressing(v, rails)                # the scaffold came down: the game stands here now, and says so
		build_ms = float(Time.get_ticks_usec() - t0) / 1000.0
		if was != radius or _report_next:
			print("[site] lot %d: lot %.0f m (was %.0f), its parts built in %.2f ms on the main thread%s" % [lot, radius, was, build_ms, " (worker meshes still coming)" if not _tasks.is_empty() else ""])
			_report_next = not _tasks.is_empty()
		return
	var construction := _parts
	var yaw := float(v.get("yaw_deg", 0.0))
	if yaw != 0.0:
		construction = Node3D.new()
		construction.name = "Construction"
		# The workbench turns +X toward +Z on its map. Cancel the parent's road-facing turn.
		construction.rotation.y = -deg_to_rad(yaw) - rotation.y
		_parts.add_child(construction)
	var mk: TLMesh = TLMesh.new(51)
	var pk: Array = v["packages"]
	var m: int = pk.size()
	# the bays: one per package, in the plan's order, across the lot
	var width: float = minf(2.0 * r - 10.0, maxf(1.0, float(m)) * 13.0)
	var bw: float = width / maxf(1.0, float(m))
	_bay_z = -r * 0.12
	_bays_x = []
	var active: int = -1
	for i: int in m:
		var b: Dictionary = pk[i]
		var x: float = -width * 0.5 + bw * (float(i) + 0.5)
		_bays_x.append(x)
		_bay(mk, b, Vector3(x, 0.0, _bay_z), bw - 1.4)
		if active < 0 and ["running", "verifying"].has(str(b["state"])):
			active = i
	if m == 0:
		# no plan yet: the first timber is there
		TLKitSite.add_lumber(mk, Vector3(-3.0, 0.0, _bay_z), 3.2, 1.0, 5, 15.0)
		TLKitSite.add_pallet(mk, Vector3(2.5, 0.0, _bay_z + 1.0), 3, -10.0)
	if str(v["stage"]) == "failed":
		for i: int in 5:
			TLKitSite.add_barricade(mk, Vector3(-8.0 + float(i) * 4.0, 0.0, r - 4.0), 1.8, 0.0)
	# timber and pallets by the side: a site at work
	TLKitSite.add_lumber(mk, Vector3(-r * 0.62, 0.0, r * 0.35), 3.2, 1.0, 6, 70.0)
	TLKitSite.add_pallet(mk, Vector3(-r * 0.5, 0.0, r * 0.55), 3, 20.0)
	var mi: MeshInstance3D = mk.instance("site_bays")
	construction.add_child(mi)
	if m > 0:
		# A turned yard carries its board on the working floor. The original board stands beside the sign.
		var board_at := Vector3(0, 0, -r * 0.60) if yaw != 0.0 else Vector3(21.2, 0, r + 6.2)
		_plan_board(pk, construction, board_at)
	# the crane: behind the bays, turning to the one being built (or slowly along them when none is)
	_crane = TLKitSite.crane(24.0, 2.0, maxf(16.0, width * 0.5 + 6.0), 7.0)
	_crane.position = Vector3(width * 0.5 + 3.0 if width * 0.5 + 3.0 < r - 3.0 else r - 4.0, 0.0, _bay_z - 8.0)
	construction.add_child(_crane)
	var boxes: Array = [[_crane.position + Vector3(0.0, 3.0, 0.0), Vector3(4.0, 6.0, 4.0)]]
	for i: int in m:
		var b: Dictionary = pk[i]
		var h: float = 7.6 if bool(b["merged"]) else float(SOLID_H.get(str(b["state"]), 1.2))
		# the slab, the walls or house and the scaffold in front of it (z to +2 m beyond the slab)
		boxes.append([Vector3(float(_bays_x[i]), h * 0.5, _bay_z + 1.0), Vector3(bw - 0.8, h, 8.6 + 2.0)])
	var fence: PackedVector3Array = _hoarding(construction.transform)
	hoarding = fence.size() / 2
	if not fence.is_empty():
		_show_mesh("hoarding %s %s" % [radius, yaw], _hoarding_mesh.bind(fence), "site_hoarding")
	_solid(boxes, rails, construction.transform, fence)
	var aim: Vector3 = Vector3(float(_bays_x[active]) if active >= 0 else 0.0, 0.0, _bay_z) - _crane.position
	_target = atan2(-aim.z, aim.x)
	if str(v["stage"]) == "failed":
		_target += 0.9                           # the jib turned away: nobody works here


## S3. A game is here: an entrance arch over the gate with the game's title, two light masts and
## flags, so that a small game on its lot reads from the road (the lot itself is fitted to the game:
## site.gd `fit_radius`). The arch's pillars are solid; the way between them is 5.4 m wide.
func _arrived_dressing(v: Dictionary, rails: PackedVector3Array) -> void:
	var g: float = radius + 3.6                  # the gate line
	_show_mesh("arrived %.1f" % radius, _dressing_mesh.bind(g), "site_arrived")
	var name_: Label3D = _text(str(v["title"]) if not str(v["title"]).is_empty() else "A new game", 64, 0.01, 820)
	name_.modulate = Color(0.98, 0.96, 0.9)
	name_.outline_size = 10
	name_.outline_modulate = Color(0.1, 0.08, 0.12)
	name_.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	name_.position = Vector3(0.0, 6.75, g + 0.62)
	_parts.add_child(name_)
	_solid([[Vector3(-3.4, 2.6, g), Vector3(1.4, 5.2, 1.4)], [Vector3(3.4, 2.6, g), Vector3(1.4, 5.2, 1.4)]], rails)


static func _dressing_mesh(g: float) -> TLMesh:
	var mk: TLMesh = TLMesh.new(54)
	TLKitSite.add_entrance(mk, Vector3(0.0, 0.0, g), 0.0)
	for side: float in [-1.0, 1.0]:
		var a: float = deg_to_rad(90.0 + side * 55.0)
		TLKitSite.add_light_mast(mk, Vector3(cos(a), 0.0, -sin(a)) * (g + 1.5), rad_to_deg(-a) - 90.0)
		for k: int in 3:
			var b: float = deg_to_rad(90.0 - side * (16.0 + 9.0 * float(k)))
			TLKitSite.add_flag(mk, Vector3(cos(b), 0.0, sin(b)) * (g + 0.8), 6.0, "flag_a" if k % 2 == 0 else "flag_b")
	return mk


## S4. The meshes that depend only on the lot's size (rails, path, arrival arch and masts) are built on a worker
## thread, once per size, and kept: a refit costs the main thread no mesh building. Until the new mesh is there the one
## of the size before stays shown (`stand_in`); when it is done the site is built again with it.
var _meshes: Dictionary = {}          # key -> ArrayMesh
var _tasks: Dictionary = {}           # key -> [task id, {"mesh": ArrayMesh}]
var _last_of: Dictionary = {}         # mesh name -> the last ArrayMesh shown under that name
func _show_mesh(key: String, make: Callable, mesh_name: String) -> void:
	var m: Variant = _meshes.get(key, null)
	if m == null and not _tasks.has(key):
		var box: Dictionary = {}
		var id: int = WorkerThreadPool.add_task(func() -> void: box["mesh"] = (make.call() as TLMesh).build(mesh_name))
		_tasks[key] = [id, box]
	if m == null:
		m = _last_of.get(mesh_name, null)
	if m == null:
		return
	_last_of[mesh_name] = m
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = m
	_parts.add_child(mi)


func _collect() -> void:
	for key: Variant in _tasks.keys():
		var t: Array = _tasks[key]
		if WorkerThreadPool.is_task_completed(int(t[0])):
			WorkerThreadPool.wait_for_task_completion(int(t[0]))
			_meshes[key] = (t[1] as Dictionary).get("mesh", null)
			_tasks.erase(key)
			_shown = ""                         # built again next frame, with the new mesh


## Day of 21 Nov 2026 (lane L6): waits for every worker mesh in flight and takes it, as `_collect` does once one is
## done (the site is built again on the next `_process`, or by the caller). For a caller that must see the finished
## site whatever the machine's load: a selftest that waited for them by counting frames ran out of frames on a busy
## machine (block 502, site.editor_yaw: the main loop spins frames while the worker builds).
func wait_meshes() -> void:
	for key: Variant in _tasks.keys():
		var t: Array = _tasks[key]
		WorkerThreadPool.wait_for_task_completion(int(t[0]))
		_meshes[key] = (t[1] as Dictionary).get("mesh", null)
		_tasks.erase(key)
		_shown = ""


func _exit_tree() -> void:
	for key: Variant in _tasks.keys():
		WorkerThreadPool.wait_for_task_completion(int((_tasks[key] as Array)[0]))
	_tasks.clear()


## One bay: a slab; above it what the package's state shows. A package merged before (and opened again by a change)
## keeps its finished house and gets a scaffold in front.
func _bay(mk: TLMesh, b: Dictionary, o: Vector3, w: float) -> void:
	var st: String = str(b["state"])
	var merged: bool = bool(b["merged"])
	var d: float = 8.0
	mk.box(Vector3(w + 0.6, 0.35, d + 0.6), "concrete", Color.WHITE, 0.04, o + Vector3(0, 0.175, 0))
	var top: float = 0.35
	if merged or st == "promoted":
		_house(mk, o + Vector3(0, top, 0), w, d)
	match st:
		"queued":
			if not merged:
				TLKitSite.add_lumber(mk, o + Vector3(-w * 0.2, top, 0.4), minf(3.2, w * 0.6), 1.0, 4, 0.0)
				TLKitSite.add_pallet(mk, o + Vector3(w * 0.22, top, -1.2), 2, 0.0)
		"running":
			if not merged:
				_walls(mk, o + Vector3(0, top, 0), w, d, 2.4, "concrete_dark")
			_scaffold(mk, o + Vector3(0, top, 0), w, d, 2)
		"verifying":
			if not merged:
				_walls(mk, o + Vector3(0, top, 0), w, d, 4.4, "concrete_dark")
			_scaffold(mk, o + Vector3(0, top, 0), w, d, 3)
			mk.box(Vector3(0.6, 0.6, 0.6), "beacon", Color.WHITE, 0.1, o + Vector3(0, top + (9.6 if merged else 5.0), 0))
		"blocked":
			if not merged:
				_walls(mk, o + Vector3(0, top, 0), w, d, 1.6, "concrete_dark")
			TLKitSite.add_barricade(mk, o + Vector3(-1.2, top, d * 0.5 + 0.9), 1.8, 0.0)
			TLKitSite.add_barricade(mk, o + Vector3(1.2, top, d * 0.5 + 0.9), 1.8, 0.0)
		"failed":
			if not merged:
				_walls(mk, o + Vector3(0, top, 0), w, d, 0.9, "stone_dark")
			for k: int in 3:
				TLKitSite.add_barricade(mk, o + Vector3(-2.2 + float(k) * 2.2, top, d * 0.5 + 0.9), 1.8, 0.0)
			TLKitSite.add_cone(mk, o + Vector3(-w * 0.5, top, d * 0.5 + 1.8))
			TLKitSite.add_cone(mk, o + Vector3(w * 0.5, top, d * 0.5 + 1.8))


func _walls(mk: TLMesh, o: Vector3, w: float, d: float, h: float, key: String) -> void:
	var t: float = 0.4
	mk.box(Vector3(w, h, t), key, Color.WHITE, 0.03, o + Vector3(0, h * 0.5, -d * 0.5 + t * 0.5))
	mk.box(Vector3(t, h, d), key, Color.WHITE, 0.03, o + Vector3(-w * 0.5 + t * 0.5, h * 0.5, 0))
	mk.box(Vector3(t, h, d), key, Color.WHITE, 0.03, o + Vector3(w * 0.5 - t * 0.5, h * 0.5, 0))
	var side: float = (w - 2.2) * 0.5
	if side > 0.2:
		mk.box(Vector3(side, h, t), key, Color.WHITE, 0.03, o + Vector3(-w * 0.5 + side * 0.5, h * 0.5, d * 0.5 - t * 0.5))
		mk.box(Vector3(side, h, t), key, Color.WHITE, 0.03, o + Vector3(w * 0.5 - side * 0.5, h * 0.5, d * 0.5 - t * 0.5))


func _house(mk: TLMesh, o: Vector3, w: float, d: float) -> void:
	var h: float = 7.0
	mk.box(Vector3(w, h, d), "cabin", Color.WHITE, 0.05, o + Vector3(0, h * 0.5, 0))
	mk.box(Vector3(w + 0.3, 0.3, d + 0.3), "cabin_trim", Color.WHITE, 0.03, o + Vector3(0, h + 0.15, 0))
	mk.hull([o + Vector3(-w * 0.5 - 0.2, h + 0.3, -d * 0.5 - 0.2), o + Vector3(w * 0.5 + 0.2, h + 0.3, -d * 0.5 - 0.2),
		o + Vector3(-w * 0.5 - 0.2, h + 0.3, d * 0.5 + 0.2), o + Vector3(w * 0.5 + 0.2, h + 0.3, d * 0.5 + 0.2),
		o + Vector3(-w * 0.5 - 0.2, h + 2.0, 0), o + Vector3(w * 0.5 + 0.2, h + 2.0, 0)], "roof")
	for k: int in 2:
		var x: float = (-0.25 + 0.5 * float(k)) * w
		mk.box(Vector3(minf(1.6, w * 0.3), 1.2, 0.08), "window", Color.WHITE, 0.0, o + Vector3(x, h * 0.62, d * 0.5 + 0.03))
	mk.box(Vector3(1.2, 2.2, 0.08), "cabin_trim", Color.WHITE, 0.0, o + Vector3(0, 1.1, d * 0.5 + 0.03))
	TLKitSite.add_flag(mk, o + Vector3(w * 0.5 - 0.4, h + 0.3, -d * 0.5 + 0.4), 3.2, "flag_b")


func _scaffold(mk: TLMesh, o: Vector3, w: float, d: float, levels: int) -> void:
	# poles and decks in front of the bay (the kit's scaffold bay drawn into this mesh)
	var n: int = maxi(1, int(round(w / 2.4)))
	var bw: float = w / float(n)
	var z0: float = d * 0.5 + 0.3
	var hh: float = float(levels) * 2.0
	for i: int in n + 1:
		var x: float = -w * 0.5 + float(i) * bw
		for z: float in [z0, z0 + 1.2]:
			mk.bar(o + Vector3(x, 0, z), o + Vector3(x, hh + 1.0, z), 0.16, 0.16, "yellow", Color.WHITE, 0.01)
	for l: int in range(1, levels + 1):
		var y: float = float(l) * 2.0
		mk.box(Vector3(w, 0.08, 1.2), "plank", Color.WHITE, 0.0, o + Vector3(0, y, z0 + 0.6))
		mk.bar(o + Vector3(-w * 0.5, y + 1.0, z0 + 1.2), o + Vector3(w * 0.5, y + 1.0, z0 + 1.2), 0.08, 0.08, "yellow_dark", Color.WHITE)
	TLKitSite.add_ladder(mk, o + Vector3(w * 0.5 - 0.4, 0, z0 + 1.0), o + Vector3(w * 0.5 - 0.4, 2.0, z0 + 1.0))


## S3. The plan: a board in the construction frame, one row per package in the plan's order:
## its state word and its title (the job's own words), coloured by state. Round 1 put the words on the bays, lying
## low in front of them: from the road they could not be read (stills before_site/04_site_mid_build_road.png).
const ROW_COLOUR: Dictionary = {"promoted": Color(0.1, 0.42, 0.16), "running": Color(0.72, 0.36, 0.0), "verifying": Color(0.72, 0.36, 0.0),
	"blocked": Color(0.66, 0.1, 0.08), "failed": Color(0.66, 0.1, 0.08), "queued": Color(0.32, 0.3, 0.34)}
func _plan_board(pk: Array, construction: Node3D, o: Vector3) -> void:
	var mk: TLMesh = TLMesh.new(53)
	var row: float = 0.72
	var h: float = 1.4 + row * float(pk.size())
	for sx: float in [-4.6, 4.6]:
		mk.bar(o + Vector3(sx, -0.5, 0), o + Vector3(sx, 2.4 + h, 0), 0.26, 0.26, "wood_dark", Color.WHITE, 0.02)
		_posts.append([construction.transform * (o + Vector3(sx, (1.9 + h) * 0.5, 0)), Vector3(POST_BOX.x, 2.9 + h, POST_BOX.z)])
	mk.box(Vector3(10.6, h + 0.4, 0.2), "sign", Color.WHITE, 0.05, o + Vector3(0, 2.2 + h * 0.5, 0))
	mk.box(Vector3(10.0, h - 0.2, 0.06), "cabin", Color.WHITE, 0.0, o + Vector3(0, 2.2 + h * 0.5, 0.12))
	construction.add_child(mk.instance("site_plan"))
	var head: Label3D = _text("The plan", 64, 0.01, 960)
	head.position = o + Vector3(0, 2.2 + h - 0.55, 0.2)
	construction.add_child(head)
	for i: int in pk.size():
		var b: Dictionary = pk[i]
		var st: String = "built" if bool(b["merged"]) and str(b["state"]) == "promoted" else str(STATE_WORD.get(str(b["state"]), str(b["state"])))
		var title: String = str(b["title"])
		if title.length() > 30:
			title = title.left(28) + "..."
		var lb: Label3D = _text("%s  %s" % [st, title], 46, 0.01, 960)
		lb.autowrap_mode = TextServer.AUTOWRAP_OFF
		lb.modulate = ROW_COLOUR.get(str(b["state"]), Color(0.12, 0.1, 0.14))
		lb.position = o + Vector3(0, 2.2 + h - 1.3 - row * float(i), 0.2)
		construction.add_child(lb)


## The sign: beside the gate, facing the road. The job's title; how far it is; when it failed,
## that it failed; when the game is there, that it can be played.
func _sign(v: Dictionary, arrived: bool) -> void:
	var mk: TLMesh = TLMesh.new(52)
	var o: Vector3 = Vector3(10.0, 0.0, radius + 6.2)
	var failed: bool = str(v["stage"]) == "failed"
	for sx: float in [-4.6, 4.6]:
		mk.bar(o + Vector3(sx, -0.5, 0), o + Vector3(sx, 7.6, 0), 0.26, 0.26, "wood_dark", Color.WHITE, 0.02)
		_posts.append([o + Vector3(sx, 3.55, 0), POST_BOX])
	mk.box(Vector3(10.6, 5.2, 0.2), "hazard_red" if failed else ("grass_dark" if arrived else "sign"), Color.WHITE, 0.05, o + Vector3(0, 4.9, 0))
	mk.box(Vector3(10.0, 4.6, 0.06), "cabin", Color.WHITE, 0.0, o + Vector3(0, 4.9, 0.12))
	_parts.add_child(mk.instance("site_sign"))
	var title: String = str(v["title"]) if not str(v["title"]).is_empty() else "A new game"
	var line: String = ""
	if failed:
		line = "This game could not be finished."
	elif arrived:
		line = "Ready. Walk in and press E to play."
	elif v.has("phase_line"):                       # 21 Nov, L3's PATCHES P1: a phased plan shows its phase
		var pl: String = str(v["phase_line"])
		line = pl.substr(0, 1).to_upper() + pl.substr(1)      # "Phase 2 of 3: Rivals and cracks"
	elif int(v["total"]) > 0:
		line = "%d of %d built" % [int(v["built"]), int(v["total"])]
	else:
		line = "Being planned"
	var t1: Label3D = _text(title, 80, 0.01, 960)
	t1.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM      # the title grows up from the middle of the board
	t1.position = o + Vector3(0, 5.15, 0.2)
	_parts.add_child(t1)
	var t2: Label3D = _text(line, 100 if line.length() < 16 else 84, 0.01, 960)
	t2.vertical_alignment = VERTICAL_ALIGNMENT_TOP         # the line below it grows down
	t2.position = o + Vector3(0, 4.85, 0.2)
	_parts.add_child(t2)


static func _text(s: String, size: int, px: float, width_px: int) -> Label3D:
	var lb: Label3D = Label3D.new()
	lb.text = s
	lb.font_size = size
	lb.pixel_size = px
	lb.width = float(width_px)
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.modulate = Color(0.12, 0.1, 0.14)
	lb.outline_size = 0
	lb.double_sided = false
	lb.shaded = false
	return lb
