extends Node3D
## S1. How a construction site looks (kernel/world/site.gd has the model). One node per site lot, a child of the
## landscape (re-based with it when a game is on stage), built by landscape.gd. Every frame it asks the world's site
## for the lot's view and builds its parts again only when that view changed. Drawing only: kit parts (TLKitSite) and
## TLMesh boxes in the style's palette, as the landscape draws; text is the job's own words.
##
## Read from 20 m: a sign by the gate (outside the fence: the job's title and "N of M built", or "This game could not
## be finished"); one bay per package in the plan's order, rising with its state (waiting: a slab and timber; building:
## walls and a scaffold; checking: higher walls, full scaffold, a beacon; on hold: a barricade; built: a finished
## house with a flag; failed: low walls behind red barricades); a crane that turns to the bay being built. When the
## game arrives the scaffold comes down: only the sign stays, and the game stands on the lot.

const STATE_WORD: Dictionary = {"queued": "waiting", "running": "building", "verifying": "checking", "blocked": "on hold",
	"promoted": "built", "failed": "failed"}

var site: RefCounted = null           # kernel/world/site.gd
var lot: int = -1
var radius: float = 20.0
var _shown: String = ""
var _parts: Node3D = null
var _crane: Node3D = null
var _target: float = 0.0              # where the crane's jib points (radians about the vertical)
var _bays_x: Array = []               # local x of every bay
var _bay_z: float = 0.0


## `centre`: the lot's centre on the ground (x, pad height, z); `gate`: the direction from the centre to its road
## (Vector2) or null; the node's +Z faces the gate.
static func make(site_: RefCounted, lot_: int, centre: Vector3, radius_: float, gate: Variant) -> Node3D:
	var n: Node3D = (load("res://kernel/world/site/draw.gd") as GDScript).new()
	n.name = "TLSite%d" % lot_
	n.set("site", site_)
	n.set("lot", lot_)
	n.set("radius", radius_)
	n.position = centre
	if gate != null:
		n.rotation.y = atan2((gate as Vector2).x, (gate as Vector2).y)
	return n


## landscape.gd: the lots that are construction sites with a plot are taken out of `lots` (they are drawn as plots,
## with the plot's pad, fence and gate); returns them as [lot index, plot index, the world's site].
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
		parent.add_child(make(sp[2], int(sp[0]), Vector3(c.x, float(pad_h[i]), c.y), float(rad[i]), gates[i]))
		stats["sites"] = int(stats.get("sites", 0)) + 1


func _process(delta: float) -> void:
	if site == null:
		return
	var v: Dictionary = site.call("view_of", lot)
	var key: String = _key(v)
	if key != _shown:
		_shown = key
		_build(v)
	if _crane != null and is_instance_valid(_crane):
		var slew: Node3D = _crane.get_node_or_null("Slew") as Node3D
		if slew != null:
			slew.rotation.y = lerp_angle(slew.rotation.y, _target, clampf(delta * 0.8, 0.0, 1.0))


static func _key(v: Dictionary) -> String:
	if v.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray([str(v["stage"]), str(v["title"]), str(v["arrived"]), str(v["job_state"])])
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
	if v.is_empty():
		return
	var arrived: bool = bool(v["arrived"])
	var r: float = radius
	_sign(v, arrived)
	if arrived:
		return                                   # the scaffold came down: the game stands here now
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
		# no plan yet: the pad is fenced and the first timber is there
		TLKitSite.add_lumber(mk, Vector3(-3.0, 0.0, _bay_z), 3.2, 1.0, 5, 15.0)
		TLKitSite.add_pallet(mk, Vector3(2.5, 0.0, _bay_z + 1.0), 3, -10.0)
	if str(v["stage"]) == "failed":
		for i: int in 5:
			TLKitSite.add_barricade(mk, Vector3(-8.0 + float(i) * 4.0, 0.0, r - 4.0), 1.8, 0.0)
	# timber and pallets by the side: a site at work
	TLKitSite.add_lumber(mk, Vector3(-r * 0.62, 0.0, r * 0.35), 3.2, 1.0, 6, 70.0)
	TLKitSite.add_pallet(mk, Vector3(-r * 0.5, 0.0, r * 0.55), 3, 20.0)
	var mi: MeshInstance3D = mk.instance("site_bays")
	_parts.add_child(mi)
	for i: int in m:
		_bay_label(pk[i], Vector3(float(_bays_x[i]), 0.0, _bay_z + 5.6))
	# the crane: behind the bays, turning to the one being built (or slowly along them when none is)
	_crane = TLKitSite.crane(24.0, 2.0, maxf(16.0, width * 0.5 + 6.0), 7.0)
	_crane.position = Vector3(width * 0.5 + 3.0 if width * 0.5 + 3.0 < r - 3.0 else r - 4.0, 0.0, _bay_z - 8.0)
	_parts.add_child(_crane)
	var aim: Vector3 = Vector3(float(_bays_x[active]) if active >= 0 else 0.0, 0.0, _bay_z) - _crane.position
	_target = atan2(-aim.z, aim.x)
	if str(v["stage"]) == "failed":
		_target += 0.9                           # the jib turned away: nobody works here


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


func _bay_label(b: Dictionary, at: Vector3) -> void:
	var lb: Label3D = _text("%s\n%s" % [str(b["title"]), str(STATE_WORD.get(str(b["state"]), str(b["state"])))], 56, 0.012, 900)
	lb.position = at + Vector3(0, 0.75, 0)
	_parts.add_child(lb)


## The sign: outside the fence beside the gate, facing the road. The job's title; how far it is; when it failed,
## that it failed; when the game is there, that it can be played.
func _sign(v: Dictionary, arrived: bool) -> void:
	var mk: TLMesh = TLMesh.new(52)
	var o: Vector3 = Vector3(10.0, 0.0, radius + 8.0)
	var failed: bool = str(v["stage"]) == "failed"
	for sx: float in [-4.6, 4.6]:
		mk.bar(o + Vector3(sx, -0.5, 0), o + Vector3(sx, 7.6, 0), 0.26, 0.26, "wood_dark", Color.WHITE, 0.02)
	mk.box(Vector3(10.6, 5.2, 0.2), "hazard_red" if failed else ("grass_dark" if arrived else "sign"), Color.WHITE, 0.05, o + Vector3(0, 4.9, 0))
	mk.box(Vector3(10.0, 4.6, 0.06), "cabin", Color.WHITE, 0.0, o + Vector3(0, 4.9, 0.12))
	_parts.add_child(mk.instance("site_sign"))
	var title: String = str(v["title"]) if not str(v["title"]).is_empty() else "A new game"
	var line: String = ""
	if failed:
		line = "This game could not be finished."
	elif arrived:
		line = "Ready. Walk in and press E to play."
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
