extends Node3D
## M6 lane T (27 Nov 2026): the Home's zones (rules_layer.gd `zones`) drawn while building, hidden in play (lane P
## draws the play looks). Each zone is a frame along its box's 12 edges, its look's icon (pad: a flat disc on its
## floor, coin: an upright token at its centre, flag: a pole and a flag at its floor centre, none: nothing) and its
## name over it, all in the style's holo look (TLStyle.material("holo"); the selected zone in a copy tinted `yellow`,
## a removed one in a copy tinted `hazard_red`, as ghost.gd). No hand-made material.
## The node redraws only when the layer's `revision` or the selection moves (`sync`). The same parts make the rules
## layer's ghost (rules_layer.gd `preview_node`: `ghost_node`), so a preset's preview, an LLM answer's ghost and the
## zones in build mode look alike.

const Check := preload("res://kernel/world/build/rules_check.gd")
const EDGE := 0.05                       # metres: the frame's bar width
const LABEL_PX := 0.0011

var layer: RefCounted = null             # rules_layer.gd
var drawn_rev := -1
var drawn_sel := -1
var parts := {}                          # zone id -> its Node3D


func _init() -> void:
	name = "ZoneDraw"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## Redraws when the layer changed or another zone is selected (`selected`: a zone id, -1 none). Returns true if it drew.
func sync(l: RefCounted, selected: int) -> bool:
	if l == layer and int(l.get("revision")) == drawn_rev and selected == drawn_sel:
		return false
	layer = l
	drawn_rev = int(l.get("revision"))
	drawn_sel = selected
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	parts.clear()
	var zones: Dictionary = l.get("zones")
	var ids: Array = zones.keys()
	ids.sort()
	for zid: int in ids:
		var n := zone_node(zones[zid], "selected" if zid == selected else "holo")
		add_child(n)
		parts[zid] = n
	return true


## Zone `z` (a saved form) as a node: frame, icon, name (`mark` before it: "+ " new, "- " removed, "~ " changed, in a
## ghost). `tint`: "holo", "selected" or "red". Names of neighbouring zones are staggered in height by id.
static func zone_node(z: Dictionary, tint := "holo", mark := "") -> Node3D:
	var n := Node3D.new()
	n.name = "Zone %d" % int(z.id)
	var box: Array = z.box
	var lo := Vector3i(int(box[0][0]), int(box[0][1]), int(box[0][2]))
	var hi := Vector3i(int(box[1][0]), int(box[1][1]), int(box[1][2]))
	var mat := material(tint)
	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	frame.mesh = frame_mesh(lo, hi)
	frame.material_override = mat
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(frame)
	var icon := icon_node(str(z.look), box, mat)
	if icon != null:
		n.add_child(icon)
	var label := Label3D.new()
	label.name = "Name"
	label.text = mark + str(z.get("name", "zone %d" % int(z.id)))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = LABEL_PX
	label.font_size = 22
	label.outline_size = 7
	label.modulate = Color(1.0, 0.45, 0.4) if tint == "red" else (Color(1.0, 0.95, 0.6) if tint == "selected" else Color(0.85, 0.97, 1.0, 0.95))
	label.outline_modulate = Color(0.05, 0.05, 0.08, 0.9)
	var top := Check.floor_centre(box)
	top.y = float(hi.y) + 1.35 + 0.4 * float(int(z.id) % 3)
	label.position = top
	n.add_child(label)
	return n


## The look's icon (pad, coin, flag) in `mat`, or null for `none`.
static func icon_node(look: String, box: Array, mat: Material) -> Node3D:
	var floor_c := Check.floor_centre(box)
	var w := minf(float(int(box[1][0]) - int(box[0][0]) + 1), float(int(box[1][2]) - int(box[0][2]) + 1))
	match look:
		"pad":
			var m := CylinderMesh.new()
			m.top_radius = clampf(w * 0.4, 0.3, 3.0)
			m.bottom_radius = m.top_radius
			m.height = 0.06
			m.radial_segments = 24
			return _mi("Pad", m, mat, floor_c + Vector3(0, 0.04, 0))
		"coin":
			var m := CylinderMesh.new()
			m.top_radius = 0.32
			m.bottom_radius = 0.32
			m.height = 0.08
			m.radial_segments = 20
			var mi := _mi("Coin", m, mat, floor_c + Vector3(0, minf(0.9, (float(int(box[1][1]) - int(box[0][1])) + 1.0) * 0.5), 0))
			mi.rotation = Vector3(PI * 0.5, 0, 0)
			return mi
		"flag":
			var g := Node3D.new()
			g.name = "Flag"
			g.position = floor_c
			var pole := CylinderMesh.new()
			pole.top_radius = 0.04
			pole.bottom_radius = 0.04
			pole.height = 2.0
			g.add_child(_mi("Pole", pole, mat, Vector3(0, 1.0, 0)))
			var cloth := BoxMesh.new()
			cloth.size = Vector3(0.7, 0.45, 0.03)
			g.add_child(_mi("Cloth", cloth, mat, Vector3(0.39, 1.72, 0)))
			return g
	return null


static func _mi(nm: String, m: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	return mi


## The style's holo material: "holo" as it is, "selected" tinted `yellow`, "red" tinted `hazard_red`.
static var _tints := {}


static func material(tint: String) -> Material:
	if tint == "holo" or not (tint in ["selected", "red"]):
		return TLStyle.material("holo")
	if not _tints.has(tint):
		var m := TLStyle.material_instance("holo")
		var key := "yellow" if tint == "selected" else "hazard_red"
		if m is ShaderMaterial and TLStyle.has_key(key):
			var c := TLStyle.color(key)
			(m as ShaderMaterial).set_shader_parameter(&"holo", c)
			(m as ShaderMaterial).set_shader_parameter(&"edge", c.lightened(0.4))
		_tints[tint] = m
	return _tints[tint]


## A thin frame along the 12 edges of the cell box lo..hi (inclusive), UV y 0 (holo.gdshader's bright edge).
static func frame_mesh(lo: Vector3i, hi: Vector3i) -> ArrayMesh:
	var mn := Vector3(lo) - Vector3.ONE * 0.02
	var mx := Vector3(hi + Vector3i.ONE) + Vector3.ONE * 0.02
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ax: int in 3:
		var u := (ax + 1) % 3
		var v := (ax + 2) % 3
		for a: float in [mn[u], mx[u] - EDGE]:
			for b: float in [mn[v], mx[v] - EDGE]:
				var p := Vector3.ZERO
				var q := Vector3.ZERO
				p[ax] = mn[ax]
				q[ax] = mx[ax]
				p[u] = a
				q[u] = a + EDGE
				p[v] = b
				q[v] = b + EDGE
				_cube(st, p, q)
	return st.commit()


static func _cube(st: SurfaceTool, p: Vector3, q: Vector3) -> void:
	var c := [Vector3(p.x, p.y, p.z), Vector3(q.x, p.y, p.z), Vector3(q.x, q.y, p.z), Vector3(p.x, q.y, p.z),
		Vector3(p.x, p.y, q.z), Vector3(q.x, p.y, q.z), Vector3(q.x, q.y, q.z), Vector3(p.x, q.y, q.z)]
	for f: Array in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5]]:
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(Vector2(0, 0))
			st.add_vertex(c[f[i]])


# ------------------------------------------------------------------ the ghost of a dry run
## What `sc` (a rules layer after a dry run) changes against `now` (the Home's layer): one node per zone that is
## added or changed (holo), removed (red), or named by a rule that is added or changed (holo) or removed (red); null
## when nothing drawable changed. rules_layer.gd `preview_node` calls it.
static func ghost_node(now: RefCounted, sc: RefCounted) -> Node3D:
	var before: Dictionary = now.get("zones")
	var after: Dictionary = sc.get("zones")
	var rb: Dictionary = now.get("rules")
	var ra: Dictionary = sc.get("rules")
	var tint := {}                       # zone id -> "holo" | "red"
	var mark := {}                       # zone id -> "+ " | "- " | "~ "
	for zid: int in after:
		if not before.has(zid) or str(before[zid]) != str(after[zid]):
			tint[zid] = "holo"
			mark[zid] = "+ " if not before.has(zid) else "~ "
	for zid: int in before:
		if not after.has(zid):
			tint[zid] = "red"
			mark[zid] = "- "
	for rid: int in ra:
		if not rb.has(rid) or str(rb[rid]) != str(ra[rid]):
			for zid: int in Check.zones_named(ra[rid]):
				if not tint.has(zid):
					tint[zid] = "holo"
					mark[zid] = "~ "
	for rid: int in rb:
		if not ra.has(rid):
			for zid: int in Check.zones_named(rb[rid]):
				if not tint.has(zid):
					tint[zid] = "red"
					mark[zid] = "~ "
	if tint.is_empty():
		return null
	var node := Node3D.new()
	node.name = "RulesGhost"
	var ids: Array = tint.keys()
	ids.sort()
	for zid: int in ids:
		var z: Variant = after.get(zid, before.get(zid))
		if z is Dictionary:
			node.add_child(zone_node(z, str(tint[zid]), str(mark.get(zid, ""))))
	if node.get_child_count() == 0:
		node.free()
		return null
	return node
