class_name TLKit
extends RefCounted
## The kit (kernelApi 0.1, contracts/KIT-RIG-STYLE.md). Static functions only.
##   TLKit.list()                      every part kind
##   TLKit.spec(kind)                  {params: {name: {type, default, min, max, enum, doc}}, material, fracturable, doc}
##   TLKit.validate(kind, params)      readable errors; empty = valid; unknown params are errors
##   TLKit.build(kind, params)         the part (Node3D); null + push_error when the params are invalid
##   TLKit.hash(node)                  identity of a built part (meshes, transforms, collision, tags)
##   TLKit.validate_layout(layout)     tl.layout/1 schema + sanity errors, without building
##   TLKit.build_layout(layout, parent) -> {ok, errors[], nodes{id: Node3D}, ...}   (see kits/LAYOUT.md)
## Node convention of a built part: see kits/KIT.md. Parts never call global random functions: variation comes
## from the `seed` param through a seeded RandomNumberGenerator inside TLMesh.

const MATERIALS: PackedStringArray = ["ice", "concrete", "steel", "wood", "rubber", "asphalt", "grass", "dirt", "glass", "plastic", "snow", "water", "stone", "fabric"]

## Compact spec table. kind -> [doc, material id, fracturable, {param: [type, default, min, max, doc]}]
## types: float, int, bool, enum (min = list of options), key (palette key), points (list of [x, z] or [x, y, z]; min = least count), ints (list; min..max per item)
const PARTS: Dictionary = {
	"ground_patch": ["Flat rectangular slab of ground, top at y = 0. The floor of a small venue.", "grass", false, {
		"size_x": ["float", 40.0, 1.0, 400.0, "length along X (m)"], "size_z": ["float", 40.0, 1.0, 400.0, "length along Z (m)"],
		"thickness": ["float", 0.5, 0.1, 5.0, "slab thickness below y = 0 (m)"],
		"surface": ["enum", "grass", ["grass", "dirt", "concrete", "asphalt", "ice", "snow", "stone", "wood"], "", "what it is made of: sets both the colour and the tl_material tag"]}],
	"road_spline": ["Road ribbon along a spline, with red/white kerbs, edge lines and concrete aprons.", "asphalt", false, {
		"points": ["points", [[-30, 0], [0, 12], [30, 0], [0, -12]], 2, "", "control points [x, z] (road at y) or [x, y, z]"],
		"closed": ["bool", true, "", "", "true = a loop"], "y": ["float", 0.0, -50.0, 50.0, "road height when points are [x, z]"],
		"half_width": ["float", 5.0, 1.5, 12.0, "half the tarmac width (m)"], "kerb_width": ["float", 1.2, 0.0, 3.0, "kerb width; 0 = no kerbs"]}],
	"kerb": ["Straight red and white kerb along X.", "concrete", false, {
		"length": ["float", 8.0, 1.0, 100.0, "length along X (m)"], "width": ["float", 1.2, 0.3, 3.0, "width (m)"], "height": ["float", 0.14, 0.03, 0.5, "height (m)"]}],
	"barrier_wall": ["Concrete barrier wall along X, pre-fractured (Intact / Pieces).", "concrete", true, {
		"blocks": ["int", 4, 1, 40, "number of blocks along X"], "block_w": ["float", 2.4, 0.8, 6.0, "block length (m)"], "height": ["float", 1.0, 0.4, 4.0, "height (m)"],
		"depth": ["float", 0.8, 0.2, 2.0, "thickness (m)"], "cells": ["int", 8, 3, 16, "pieces per block"], "seed": ["int", 1, 0, 1000000, "fracture pattern"]}],
	"rink": ["Ice rink centred on the origin, long axis X, ice surface at y = 0.05. Boards, glass, markings and goals are options.", "ice", false, {
		"length": ["float", 60.0, 10.0, 120.0, "length along X (m)"], "width": ["float", 26.0, 8.0, 60.0, "width along Z (m)"],
		"corner_r": ["float", 8.5, 0.0, 30.0, "corner radius (clamped to width / 2 - 0.5)"], "boards": ["bool", true, "", "", "boards with a kick plate (collision tag plastic)"],
		"glass": ["bool", true, "", "", "glass above the boards (needs boards)"], "glass_h": ["float", 2.0, 0.5, 4.0, "glass height (m)"],
		"markings": ["bool", true, "", "", "painted lines, circles and creases"], "goals": ["bool", true, "", "", "two goals (child parts GoalA at -X and GoalB at +X)"],
		"apron": ["float", 3.5, 0.0, 10.0, "concrete apron around the boards (m); 0 = none"]}],
	"stands": ["Raked spectator stand along X, rising towards -Z. Its front edge is at z = 0.", "concrete", false, {
		"length": ["float", 52.0, 4.0, 120.0, "length along X (m)"], "rows": ["int", 10, 1, 20, "rows of seats"],
		"row_depth": ["float", 0.95, 0.6, 1.6, "depth of a row (m)"], "rise": ["float", 0.46, 0.2, 0.9, "height of a row (m)"],
		"seed": ["int", 32, 0, 1000000, "seat tint pattern"]}],
	"arch_rib": ["Roof arch rib in the YZ plane (feet at z = +-span), optional purlins towards -X, optional concrete footings.", "steel", false, {
		"span": ["float", 15.5, 3.0, 40.0, "half span: feet at z = +-span (m)"], "apex": ["float", 14.0, 3.0, 40.0, "apex height (m)"],
		"exponent": ["float", 2.6, 1.2, 6.0, "arch shape: 2 = parabola, higher = flatter top"], "purlin_dx": ["float", 0.0, 0.0, 20.0, "length of purlins towards -X (the previous rib); 0 = none"],
		"footings": ["bool", true, "", "", "concrete footings (the only collision of the part)"],
		"hologram": ["bool", false, "", "", "true = drawn as a cyan hologram (not yet built); no collision"]}],
	"scaffold": ["Scaffold tower: corner at the origin, runs along +X, depth along +Z.", "steel", false, {
		"bays": ["int", 2, 1, 8, "bays along X"], "levels": ["int", 2, 1, 6, "levels"], "bay_w": ["float", 2.4, 1.2, 4.0, "bay width (m)"],
		"bay_d": ["float", 1.3, 0.8, 3.0, "depth (m)"], "level_h": ["float", 2.0, 1.6, 3.0, "level height (m)"],
		"decks": ["ints", [1, 2], 1, 6, "levels that carry a plank deck (entries above `levels` are ignored)"]}],
	"crane": ["Tower crane. Children: Tower, Slew (turn it about Y) / Jib, Slew/Hoist (slide along X) / Load.", "steel", false, {
		"height": ["float", 35.0, 10.0, 80.0, "tower height (m)"], "jib": ["float", 30.0, 8.0, 60.0, "jib length (m)"], "counter": ["float", 11.0, 4.0, 20.0, "counter-jib length (m)"],
		"mast": ["float", 2.3, 1.2, 4.0, "mast width (m)"], "slew": ["float", 0.0, -360.0, 360.0, "jib direction (degrees about Y)"], "trolley": ["float", 0.55, 0.1, 1.0, "hoist position as a share of the jib"]}],
	"house": ["Log cabin with a shingled gable roof, chimney, windows and porch. Centred on the origin, floor at y = 0.", "wood", false, {
		"width": ["float", 8.0, 4.0, 16.0, "length along X (m)"], "depth": ["float", 5.6, 3.0, 12.0, "depth along Z (m)"],
		"wall_h": ["float", 3.0, 2.2, 6.0, "wall height (m)"], "roof_rise": ["float", 2.7, 0.8, 6.0, "roof rise (m)"],
		"lights": ["bool", true, "", "", "warm window lights (skipped in headless)"]}],
	"timber_frame": ["Timber frame of a building under construction (posts, beams, rafters).", "wood", false, {
		"width": ["float", 6.0, 3.0, 16.0, "length along X (m)"], "depth": ["float", 5.6, 3.0, 12.0, "depth along Z (m)"],
		"height": ["float", 3.0, 2.2, 6.0, "post height (m)"], "roof_rise": ["float", 2.4, 0.8, 6.0, "rafter rise (m)"]}],
	"tree": ["A tree. Collision is the trunk only.", "wood", false, {
		"species": ["enum", "pine", ["pine", "broadleaf", "hero"], "", "pine, broadleaf, or the one large hero tree"],
		"height": ["float", 9.0, 2.0, 25.0, "height (m); ignored by `hero`"], "seed": ["int", 100, 0, 1000000, "shape variation"]}],
	"rock": ["A boulder.", "stone", false, {
		"size": ["float", 1.0, 0.2, 6.0, "radius (m)"], "squash": ["float", 0.7, 0.2, 1.5, "height as a share of the radius"], "seed": ["int", 200, 0, 1000000, "shape variation"]}],
	"bush": ["A bush (no collision).", "grass", false, {
		"size": ["float", 0.9, 0.3, 3.0, "radius (m)"], "seed": ["int", 300, 0, 1000000, "shape variation"]}],
	"fence": ["Fence from the origin along +X.", "wood", false, {
		"length": ["float", 8.0, 1.0, 200.0, "length (m)"], "style": ["enum", "rail", ["rail", "mesh"], "", "rail = wooden rail fence, mesh = steel site fence"]}],
	"light_mast": ["Floodlight mast with a warm light pool (the light is skipped in headless).", "steel", false, {
		"height": ["float", 14.0, 4.0, 30.0, "height (m)"], "light": ["bool", true, "", "", "add the spot light"]}],
	"sign": ["Board on two posts.", "wood", false, {"color": ["key", "sign", "", "", "palette key of the board"]}],
	"flag": ["Flag on a pole.", "steel", false, {"height": ["float", 7.0, 2.0, 20.0, "pole height (m)"], "color": ["key", "flag_a", "", "", "palette key of the cloth"]}],
	"scoreboard": ["Scoreboard on legs.", "steel", false, {}],
	"tyre_stack": ["Tyre barrier: columns of stacked tyres along X.", "rubber", false, {"columns": ["int", 5, 1, 20, "columns"]}],
	"watch_tower": ["Timber watch tower with a roofed platform, ladder and flag.", "wood", false, {"height": ["float", 9.0, 4.0, 20.0, "platform height (m)"]}],
	"pond": ["Flat irregular sheet: a frozen pond (collision tag ice) or still water with a sand shore (no collision; tag water on the part).", "ice", false, {
		"radius_x": ["float", 30.0, 2.0, 120.0, "half size along X (m)"], "radius_z": ["float", 20.0, 2.0, 120.0, "half size along Z (m)"],
		"surface": ["enum", "ice", ["ice", "water"], "", "ice = frozen (walkable), water = a small lake"]}],
	"bridge": ["Humpback stone arch bridge along X, deck ends at y = 0 above water at y = 0.", "stone", false, {
		"length": ["float", 26.0, 6.0, 80.0, "length (m)"], "width": ["float", 4.6, 2.0, 14.0, "width (m)"], "spans": ["int", 3, 1, 8, "arches"], "rise": ["float", 4.2, 1.0, 10.0, "hump height (m)"]}],
	"lumber": ["Stack of timber.", "wood", false, {"length": ["float", 3.2, 0.5, 8.0, "length (m)"], "width": ["float", 1.0, 0.3, 4.0, "width (m)"], "layers": ["int", 6, 1, 10, "layers"], "seed": ["int", 51, 0, 1000000, "board tint variation"]}],
	"pallet": ["Pallet of blocks.", "wood", false, {"rows": ["int", 3, 1, 6, "rows of blocks"], "seed": ["int", 52, 0, 1000000, "block tint variation"]}],
	"cone": ["Traffic cone.", "plastic", false, {}],
	"barricade": ["Striped road barricade.", "wood", false, {"width": ["float", 1.9, 1.0, 4.0, "width (m)"]}],
	"cabin": ["Site cabin.", "steel", false, {}],
	"marshal_post": ["Raised marshal post with roof, ladder and flag.", "wood", false, {}],
	"entrance": ["Arena entrance portal.", "concrete", false, {}],
	"stones": ["Row of dressed stone blocks.", "stone", false, {"count": ["int", 4, 1, 12, "blocks"]}],
	"goal": ["Hockey goal: frame at x = 0, opening faces -X, net extends towards +X. Bars are steel, the net is a fabric body.", "steel", false, {
		"width": ["float", 1.84, 1.0, 8.0, "opening width (m)"], "height": ["float", 1.22, 0.8, 3.0, "opening height (m)"], "depth": ["float", 1.0, 0.5, 3.0, "net depth (m)"]}],
	"puck": ["Hockey puck. Dynamic prop: no body; tl_shape, tl_material and tl_mass_hint are on the part node.", "rubber", false, {
		"radius": ["float", 0.038, 0.02, 0.5, "radius (m)"], "height": ["float", 0.0254, 0.01, 0.3, "height (m)"]}],
	"ball": ["Ball. Dynamic prop: no body; tl_shape, tl_material and tl_mass_hint are on the part node.", "rubber", false, {
		"radius": ["float", 0.11, 0.03, 1.0, "radius (m)"], "color": ["key", "white", "", "", "palette key"]}],
	"paddle": ["Paddle (bat) for paddle-and-ball games, long axis X. Dynamic prop: no body; tl_shape, tl_material and tl_mass_hint are on the part node.", "plastic", false, {
		"length": ["float", 1.6, 0.3, 6.0, "length along X (m)"], "height": ["float", 0.3, 0.1, 2.0, "height (m)"], "depth": ["float", 0.3, 0.1, 2.0, "thickness along Z (m)"], "color": ["key", "car_blue", "", "", "palette key"]}],
	"crate": ["Wooden crate, pre-fractured (Intact / Pieces).", "wood", true, {
		"size": ["float", 1.0, 0.3, 3.0, "edge length (m)"], "cells": ["int", 6, 3, 12, "pieces"], "seed": ["int", 3, 0, 1000000, "fracture pattern"]}],
}


static func list() -> PackedStringArray:
	return PackedStringArray(PARTS.keys())


static func spec(kind: String) -> Dictionary:
	if not PARTS.has(kind):
		return {}
	return expand_spec(PARTS[kind])


## Shared with TLRigs: turns a compact row into the contract's spec dictionary (absent members omitted).
static func expand_spec(row: Array) -> Dictionary:
	var params: Dictionary = {}
	var src: Dictionary = row[3]
	for pn: String in src:
		var a: Array = src[pn]
		var d: Dictionary = {"type": a[0], "default": a[1]}
		if a[0] == "enum":
			d["type"] = "string"
			d["enum"] = a[2]
		elif a[0] == "points":
			d["min"] = a[2]
		elif a[0] == "dict":
			d["keys"] = a[2]
		elif a[0] == "floats":
			d["count"] = a[2]
		elif not (a[2] is String):
			d["min"] = a[2]
			d["max"] = a[3]
		if String(a[4]) != "":
			d["doc"] = a[4]
		params[pn] = d
	var out: Dictionary = {"params": params, "fracturable": bool(row[2]), "doc": row[0]}
	if String(row[1]) != "":
		out["material"] = row[1]
	return out


static func validate(kind: String, params: Dictionary) -> PackedStringArray:
	if not PARTS.has(kind):
		return PackedStringArray(["'%s' is not a kit part (parts: %s)" % [kind, ", ".join(PARTS.keys())]])
	return check_params(kind, PARTS[kind][3], params)


## Shared with TLRigs and the layout validator. `table` is the compact param table.
static func check_params(what: String, table: Dictionary, params: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for pn: Variant in params:
		var n: String = str(pn)
		if n.begins_with("_"):
			continue
		if not table.has(n):
			out.append("%s: unknown param '%s' (params: %s)" % [what, n, ", ".join(table.keys())])
			continue
		var a: Array = table[n]
		var v: Variant = params[pn]
		var at: String = "%s.%s" % [what, n]
		match String(a[0]):
			"float", "int":
				if not (v is float or v is int) or (a[0] == "int" and float(v) != floorf(float(v))):
					out.append("%s = %s must be a %s" % [at, str(v), "whole number" if a[0] == "int" else "number"])
				elif float(v) < float(a[2]) or float(v) > float(a[3]):
					out.append("%s = %s is outside %s..%s" % [at, str(v), str(a[2]), str(a[3])])
			"bool":
				if not (v is bool):
					out.append("%s = %s must be true or false" % [at, str(v)])
			"enum":
				if not (v is String or v is StringName) or not (a[2] as Array).has(String(v)):
					out.append("%s = %s must be one of %s" % [at, str(v), ", ".join(a[2])])
			"key":
				if not (v is String or v is StringName) or not TLStyle.has_key(String(v)):
					out.append("%s = %s is not a palette key of the style file" % [at, str(v)])
			"points":
				if not (v is Array) or (v as Array).size() < int(a[2]):
					out.append("%s must be a list of at least %d points" % [at, int(a[2])])
				else:
					for q: Variant in (v as Array):
						if not _is_nums(q, 2, 3):
							out.append("%s: every point must be [x, z] or [x, y, z], got %s" % [at, str(q)])
							break
			"ints":
				if not (v is Array):
					out.append("%s must be a list of whole numbers" % at)
				else:
					for q: Variant in (v as Array):
						if not (q is float or q is int) or float(q) != floorf(float(q)) or float(q) < float(a[2]) or float(q) > float(a[3]):
							out.append("%s: entry %s must be a whole number in %s..%s" % [at, str(q), str(a[2]), str(a[3])])
			"vec3":
				if not (v is Vector3) and not _is_nums(v, 3, 3):
					out.append("%s must be a Vector3 or [x, y, z]" % at)
			"floats":
				if not _is_nums(v, int(a[2]), int(a[2])):
					out.append("%s must be a list of %d numbers" % [at, int(a[2])])
			"dict":
				if not (v is Dictionary):
					out.append("%s must be a dictionary" % at)
				else:
					for ck: Variant in (v as Dictionary):
						if not (a[2] as Array).has(str(ck)):
							out.append("%s: unknown key '%s' (keys: %s)" % [at, str(ck), ", ".join(a[2])])
						elif not TLStyle.has_key(str(v[ck])):
							out.append("%s.%s = %s is not a palette key" % [at, str(ck), str(v[ck])])
	return out


static func _is_nums(v: Variant, lo: int, hi: int) -> bool:
	if not (v is Array) or (v as Array).size() < lo or (v as Array).size() > hi:
		return false
	for q: Variant in (v as Array):
		if not (q is float or q is int):
			return false
	return true


## Defaults of a compact param table, overlaid with `params`.
static func with_defaults(table: Dictionary, params: Dictionary) -> Dictionary:
	var p: Dictionary = {}
	for pn: String in table:
		var dv: Variant = table[pn][1]
		p[pn] = (dv as Array).duplicate(true) if dv is Array else ((dv as Dictionary).duplicate(true) if dv is Dictionary else dv)
	for pn: Variant in params:
		if not str(pn).begins_with("_"):
			p[str(pn)] = params[pn]
	return p


static func build(kind: String, params: Dictionary = {}) -> Node3D:
	var errs: PackedStringArray = validate(kind, params)
	if errs.size() > 0:
		push_error("TLKit.build: " + "; ".join(errs))
		return null
	var p: Dictionary = with_defaults(PARTS[kind][3], params)
	var n: Node3D = Node3D.new()
	n.name = kind.to_pascal_case()
	n.set_meta("tl_kind", kind)
	n.set_meta("tl_params", p)
	TLKitParts.make(kind, n, p)
	return n


## Identity of a built part or rig: every mesh (content hash from the generator's arrays), every transform, every
## collision shape and every tl_* tag, in tree order. Same kind and params give the same string.
static func hash(node: Node) -> String:
	var hc: HashingContext = HashingContext.new()
	hc.start(HashingContext.HASH_SHA1)
	_hash_walk(node, hc, true)
	return hc.finish().hex_encode()


static func _hash_walk(n: Node, hc: HashingContext, is_root: bool) -> void:
	hc.update((n.get_class() + ":" + String(n.name)).to_utf8_buffer())
	if n is Node3D and not is_root:
		hc.update(var_to_bytes((n as Node3D).transform))
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m: Mesh = (n as MeshInstance3D).mesh
		hc.update(str(m.get_meta("tl_hash", "surfaces:%d" % m.get_surface_count())).to_utf8_buffer())
	if n is CollisionShape3D and (n as CollisionShape3D).shape != null:
		hc.update(shape_sig((n as CollisionShape3D).shape).to_utf8_buffer())
	for mk: String in ["tl_hash", "tl_material", "tl_mass_hint", "tl_kind", "tl_shape"]:
		if n.has_meta(mk):
			var mv: Variant = n.get_meta(mk)
			hc.update((mk + "=" + (shape_sig(mv) if mv is Shape3D else str(mv))).to_utf8_buffer())
	for c: Node in n.get_children():
		_hash_walk(c, hc, false)


static func shape_sig(s: Shape3D) -> String:
	if s is BoxShape3D:
		return "box%s" % str((s as BoxShape3D).size)
	if s is CylinderShape3D:
		return "cyl%s,%s" % [str((s as CylinderShape3D).radius), str((s as CylinderShape3D).height)]
	if s is SphereShape3D:
		return "sph%s" % str((s as SphereShape3D).radius)
	if s is ConvexPolygonShape3D:
		return "hull%d:%d" % [(s as ConvexPolygonShape3D).points.size(), var_to_bytes((s as ConvexPolygonShape3D).points).hex_encode().hash()]
	if s is ConcavePolygonShape3D:
		var f: PackedVector3Array = (s as ConcavePolygonShape3D).get_faces()
		return "tri%d:%d" % [f.size(), var_to_bytes(f).hex_encode().hash()]
	return s.get_class()


## Triangles of everything under a node (from the generators' own counts; MultiMesh = instances x mesh).
static func triangles(n: Node) -> int:
	var t: int = 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		t += int((n as MeshInstance3D).mesh.get_meta("tl_tris", 0))
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		t += mm.instance_count * int(mm.mesh.get_meta("tl_tris", 0))
	for c: Node in n.get_children():
		t += triangles(c)
	return t


static func validate_layout(layout: Dictionary) -> PackedStringArray:
	return TLKitLayout.validate(layout)


static func build_layout(layout: Dictionary, parent: Node3D) -> Dictionary:
	return TLKitLayout.build(layout, parent)
