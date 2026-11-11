class_name TLKitLayout
extends RefCounted
## tl.layout/1: a whole venue as data (documented in kits/LAYOUT.md; change both together).
## Lists everywhere (arenas[], circuits[], houses[], cranes[], ponds[], walls[], rivers[], ridges[] ...), unknown keys
## are errors, keys starting with `_` are comments. Every prop is a kit part: {"kind", "params"} checked by TLKit.validate.
##   TLKitLayout.validate(layout) -> PackedStringArray         schema + sanity, builds nothing
##   TLKitLayout.build(layout, parent) -> {ok, errors[], nodes{id: Node3D}, root, cams{name: {pos, look, fov}},
##                                         spawn: Transform3D, terrain: TLKitTerrain or null, triangles: int}
## Field spec rows: [type, required, min, max]; types: num, int, bool, str, enum (min = options), v2, v3, v23,
## obj (min = key table), list (min = item spec row, max = most items), box4, any.

const NEAR: Rect2 = Rect2(-224, -288, 416, 416)

static var _schema: Dictionary = {}


static func schema() -> Dictionary:
	if not _schema.is_empty():
		return _schema
	var on: Array = ["obj", false, {"circuit": ["str", true], "s": ["num", false, -100000.0, 100000.0], "near": ["v2", false], "ds": ["num", false, -5000.0, 5000.0],
		"side": ["enum", false, [-1, 1]], "off": ["num", false, 0.0, 60.0]}]
	var ramp: Array = ["obj", false, {"c": ["v2", true], "w": ["num", false, 4.0, 60.0], "fall": ["num", false, 8.0, 80.0]}]
	var scaffold: Array = ["obj", false, {"p": ["v2", true], "yaw": ["num", false, -360.0, 360.0], "bays": ["int", true, 1, 8], "levels": ["int", true, 1, 6],
		"decks": ["list", true, ["int", false, 1, 6], 6], "bay_w": ["num", false, 1.2, 4.0], "bay_d": ["num", false, 0.8, 3.0], "level_h": ["num", false, 1.6, 3.0]}]
	var bot: Array = ["obj", false, {"p": ["v3", true], "yaw": ["num", false, -360.0, 360.0], "clip": ["enum", false, ["idle", "walk", "work", "carry", "weld"]],
		"params": ["any", false]}]
	_schema = {
		"schema": ["enum", true, ["tl.layout/1"]], "name": ["str", true], "seed": ["int", false, 0, 1000000],
		"spawn": ["obj", false, {"p": ["v2", true], "yaw": ["num", false, -360.0, 360.0]}],
		"terrain": ["obj", false, {
			"base_y": ["num", false, -60.0, 20.0], "far": ["bool", false],
			"ridges": ["list", false, ["obj", false, {"a": ["v2", true], "b": ["v2", true], "fall": ["num", false, 2.0, 60.0], "half_w": ["num", false, 4.0, 80.0],
				"h": ["num", false, -20.0, 40.0], "ramps": ["list", false, ramp, 16]}], 8],
			"pads": ["list", false, ["obj", false, {"c": ["v2", true], "r": ["num", true, 2.0, 160.0], "blend": ["num", true, 1.0, 80.0], "h": ["num", true, -40.0, 40.0], "dirt": ["bool", false]}], 64],
			"mesas": ["list", false, ["obj", false, {"c": ["v2", true], "r": ["num", true, 5.0, 300.0], "h": ["num", true, 5.0, 200.0], "blend": ["num", false, 1.0, 100.0], "noise": ["num", false, 0.0, 40.0]}], 32]}],
		"rivers": ["list", false, ["obj", false, {"id": ["str", false], "points": ["list", true, ["v2", false], 200], "width": ["num", false, 3.0, 60.0], "y": ["num", false, -60.0, 20.0]}], 8],
		"waterfalls": ["list", false, ["obj", false, {"p": ["v2", true], "to": ["v2", true], "w": ["num", false, 1.0, 40.0]}], 16],
		"circuits": ["list", false, ["obj", false, {"id": ["str", true], "points": ["list", true, ["v2", false], 60], "y": ["num", false, -40.0, 30.0], "roll": ["num", false, 0.0, 3.0],
			"half_width": ["num", false, 1.5, 12.0], "kerb_width": ["num", false, 0.0, 3.0], "closed": ["bool", false]}], 8],
		"walls": ["list", false, ["obj", false, {"id": ["str", true], "circuit": ["str", false], "at": ["v2", false], "p": ["v23", false], "yaw": ["num", false, -360.0, 360.0],
			"blocks": ["int", false, 1, 60], "seed": ["int", false, 0, 1000000]}], 16],
		"arenas": ["list", false, ["obj", false, {"id": ["str", true], "c": ["v3", true], "yaw": ["num", false, -360.0, 360.0], "rink": ["any", false],
			"stands": ["list", false, ["obj", false, {"side": ["enum", true, [-1, 1]], "rows": ["int", false, 1, 20], "row_depth": ["num", false, 0.6, 1.6], "rise": ["num", false, 0.2, 0.9]}], 2],
			"ribs": ["obj", false, {"count": ["int", true, 0, 16], "built": ["int", false, 0, 16], "dx": ["num", false, 3.0, 20.0], "off": ["num", false, -5.0, 5.0], "apex": ["num", false, 4.0, 40.0],
				"exponent": ["num", false, 1.2, 6.0], "holograms": ["list", false, ["int", false, 1, 16], 16]}],
			"scaffolds": ["list", false, scaffold, 32], "bots": ["list", false, bot, 40]}], 8],
		"cranes": ["list", false, ["obj", false, {"id": ["str", false], "p": ["v2", true], "h": ["num", false, 10.0, 80.0], "jib": ["num", false, 8.0, 60.0], "yaw": ["num", false, -360.0, 360.0], "trolley": ["num", false, 0.1, 1.0]}], 8],
		"houses": ["list", false, ["obj", false, {"id": ["str", false], "p": ["v3", true], "yaw": ["num", false, -360.0, 360.0], "ext_side": ["enum", false, [-1, 1]], "frame": ["bool", false], "params": ["any", false]}], 24],
		"ponds": ["list", false, ["obj", false, {"id": ["str", false], "p": ["v23", true], "yaw": ["num", false, -360.0, 360.0], "rx": ["num", true, 2.0, 120.0], "rz": ["num", true, 2.0, 120.0], "surface": ["enum", false, ["ice", "water"]]}], 16],
		"trees": ["list", false, ["obj", false, {"id": ["str", false], "p": ["v2", true], "species": ["enum", false, ["pine", "broadleaf", "hero"]], "height": ["num", false, 2.0, 25.0], "seed": ["int", false, 0, 1000000]}], 200],
		"rocks": ["list", false, ["obj", false, {"id": ["str", false], "p": ["v2", true], "size": ["num", false, 0.2, 6.0], "squash": ["num", false, 0.2, 1.5], "seed": ["int", false, 0, 1000000]}], 200],
		"forest": ["obj", false, {"scatter": ["bool", false], "density": ["num", false, 0.0, 4.0], "edges": ["list", false, ["box5", false], 32], "clear": ["list", false, ["box4", false], 32]}],
		"props": ["list", false, ["obj", false, {"id": ["str", false], "kind": ["str", true], "p": ["v23", false], "on": on, "yaw": ["num", false, -360.0, 360.0], "to": ["v2", false], "params": ["any", false]}], 600],
		"actors": ["list", false, ["obj", false, {"id": ["str", true], "rig": ["enum", true, ["biped", "vehicle", "bot"]], "p": ["v23", false], "on": on, "yaw": ["num", false, -360.0, 360.0],
			"clip": ["str", false], "params": ["any", false]}], 64],
		"cams": ["any", false],
	}
	return _schema


# ------------------------------------------------------------------ validation
static func validate(layout: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	_check_obj("layout", layout, schema(), out)
	if out.size() > 0 and (not layout.has("schema") or not layout.has("name")):
		return out
	var has_terrain: bool = layout.get("terrain") is Dictionary
	var ids: Dictionary = {}
	var circuit_ids: Dictionary = {}
	for c: Variant in _list(layout, "circuits"):
		if not (c is Dictionary) or not (c.get("points") is Array):
			continue
		circuit_ids[str(c.get("id", ""))] = true
		var pts: Array = c["points"]
		if pts.size() < 4:
			out.append("circuits[%s].points needs at least 4 control points" % str(c.get("id", "?")))
			continue
		var total: float = 0.0
		for i: int in pts.size():
			if not TLKit._is_nums(pts[i], 2, 2) or not TLKit._is_nums(pts[(i + 1) % pts.size()], 2, 2):
				continue
			var d: float = Vector2(pts[i][0], pts[i][1]).distance_to(Vector2(pts[(i + 1) % pts.size()][0], pts[(i + 1) % pts.size()][1]))
			if d < 6.0 and (bool(c.get("closed", true)) or i < pts.size() - 1):
				out.append("circuits[%s].points %d and %d are %.1f m apart (6 m or more)" % [str(c["id"]), i, (i + 1) % pts.size(), d])
			total += d
		if total < 120.0:
			out.append("circuits[%s] is %.0f m long (120 m or more)" % [str(c["id"]), total])
	for group: String in ["circuits", "walls", "arenas", "cranes", "houses", "ponds", "trees", "rocks", "props", "actors", "rivers"]:
		var i: int = 0
		for it: Variant in _list(layout, group):
			if it is Dictionary and (it as Dictionary).has("id"):
				var id: String = str(it["id"])
				if ids.has(id):
					out.append("%s[%d].id '%s' is already used by %s (ids are unique across the layout)" % [group, i, id, ids[id]])
				ids[id] = "%s[%d]" % [group, i]
			i += 1
	var wi: int = 0
	for w: Variant in _list(layout, "walls"):
		if w is Dictionary:
			var on_c: bool = (w as Dictionary).has("circuit")
			if on_c == (w as Dictionary).has("p"):
				out.append("walls[%d] needs exactly one of `circuit` (+ `at`) or `p`" % wi)
			if on_c and not (w as Dictionary).has("at"):
				out.append("walls[%d] on a circuit needs `at`: the wall stands on the road edge nearest to that point" % wi)
			if on_c and not circuit_ids.has(str(w["circuit"])):
				out.append("walls[%d].circuit '%s' is not a circuit id (%s)" % [wi, str(w["circuit"]), ", ".join(circuit_ids.keys())])
		wi += 1
	var ai: int = 0
	for a: Variant in _list(layout, "arenas"):
		if a is Dictionary:
			var at: String = "arenas[%d]" % ai
			if (a as Dictionary).has("rink"):
				if not (a["rink"] is Dictionary):
					out.append("%s.rink must be an object of `rink` part params" % at)
				else:
					out.append_array(_prefix(at, TLKit.validate("rink", a["rink"])))
			var rb: Variant = (a as Dictionary).get("ribs", null)
			if rb is Dictionary:
				if float(rb.get("built", 0)) > float(rb.get("count", 0)):
					out.append("%s.ribs.built = %s is more than ribs.count = %s" % [at, str(rb.get("built")), str(rb.get("count"))])
				if int(float(rb.get("count", 0))) > 0 and not (rb as Dictionary).has("dx"):
					out.append("%s.ribs.dx is required when ribs.count > 0" % at)
				for hv: Variant in rb.get("holograms", []):
					if (hv is float or hv is int) and float(hv) > float(rb.get("count", 0)):
						out.append("%s.ribs.holograms: rib %s does not exist (count %s)" % [at, str(hv), str(rb.get("count"))])
			var bi: int = 0
			for b: Variant in (a as Dictionary).get("bots", []) if (a as Dictionary).get("bots", []) is Array else []:
				if b is Dictionary:
					if TLKit._is_nums(b.get("p"), 3, 3) and Vector2(b["p"][0], b["p"][2]).length() > 90.0:
						out.append("%s.bots[%d].p = %s is more than 90 m from the rink centre: bot positions are arena-local" % [at, bi, str(b["p"])])
					if b.get("params") is Dictionary:
						out.append_array(_prefix("%s.bots[%d]" % [at, bi], TLRigs.validate("bot", b["params"])))
				bi += 1
			var si: int = 0
			for sc: Variant in (a as Dictionary).get("scaffolds", []) if (a as Dictionary).get("scaffolds", []) is Array else []:
				if sc is Dictionary and sc.get("decks") is Array:
					for dl: Variant in sc["decks"]:
						if (dl is float or dl is int) and float(dl) > float(sc.get("levels", 0)):
							out.append("%s.scaffolds[%d].decks: level %s is above levels = %s" % [at, si, str(dl), str(sc.get("levels"))])
				si += 1
			if has_terrain and TLKit._is_nums((a as Dictionary).get("c"), 3, 3) and not NEAR.has_point(Vector2(a["c"][0], a["c"][2])):
				out.append("%s.c is outside the near terrain (x -224..192, z -288..128)" % at)
		ai += 1
	var hi: int = 0
	for h: Variant in _list(layout, "houses"):
		if h is Dictionary and h.get("params") is Dictionary:
			out.append_array(_prefix("houses[%d]" % hi, TLKit.validate("house", h["params"])))
		hi += 1
	var pi: int = 0
	for pr: Variant in _list(layout, "props"):
		if pr is Dictionary:
			var at2: String = "props[%d]" % pi
			var kind: String = str(pr.get("kind", ""))
			if (pr as Dictionary).has("kind") and not TLKit.PARTS.has(kind):
				out.append("%s.kind '%s' is not a kit part (parts: %s)" % [at2, kind, ", ".join(TLKit.list())])
			elif (pr as Dictionary).has("kind"):
				var pp: Variant = pr.get("params", {})
				if not (pp is Dictionary):
					out.append("%s.params must be an object" % at2)
				else:
					out.append_array(_prefix(at2, TLKit.validate(kind, pp)))
			_check_place(at2, pr, circuit_ids, has_terrain, out)
			if (pr as Dictionary).has("to") and kind != "fence":
				out.append("%s.to is only for kind `fence` (the fence runs from p to that point)" % at2)
		pi += 1
	var ci: int = 0
	for ac: Variant in _list(layout, "actors"):
		if ac is Dictionary:
			var at3: String = "actors[%d]" % ci
			if ac.get("params") is Dictionary and TLRigs.FAMILIES.has(str(ac.get("rig", ""))):
				out.append_array(_prefix(at3, TLRigs.validate(str(ac["rig"]), ac["params"])))
			elif (ac as Dictionary).has("params") and not (ac["params"] is Dictionary):
				out.append("%s.params must be an object" % at3)
			_check_place(at3, ac, circuit_ids, has_terrain, out)
		ci += 1
	if layout.get("waterfalls") is Array and (layout["waterfalls"] as Array).size() > 0:
		if not has_terrain or not (layout["terrain"].get("mesas") is Array) or (layout["terrain"]["mesas"] as Array).is_empty():
			out.append("waterfalls need terrain.mesas: a fall starts on a mesa top")
	if has_terrain:
		for ms: Variant in layout["terrain"].get("mesas", []) if layout["terrain"].get("mesas", []) is Array else []:
			if not (ms is Dictionary) or not TLKit._is_nums(ms.get("c"), 2, 2) or not (ms.get("r") is float or ms.get("r") is int):
				continue
			var mc: Vector2 = Vector2(ms["c"][0], ms["c"][1])
			var reach: float = float(ms["r"]) + float(ms.get("blend", 20.0))
			for a2: Variant in _list(layout, "arenas"):
				if a2 is Dictionary and TLKit._is_nums(a2.get("c"), 3, 3) and mc.distance_to(Vector2(a2["c"][0], a2["c"][2])) < reach + 20.0:
					out.append("terrain.mesas at %s would bury arena '%s' (a mesa is applied after pads and roads)" % [str(ms["c"]), str(a2.get("id", "?"))])
			for c2: Variant in _list(layout, "circuits"):
				if c2 is Dictionary and c2.get("points") is Array:
					for q: Variant in c2["points"]:
						if TLKit._is_nums(q, 2, 2) and mc.distance_to(Vector2(q[0], q[1])) < reach + 8.0:
							out.append("terrain.mesas at %s would bury circuit '%s' near %s" % [str(ms["c"]), str(c2.get("id", "?")), str(q)])
							break
	var cams: Variant = layout.get("cams", {})
	if not (cams is Dictionary):
		out.append("cams must be an object: name -> {pos, look, fov}")
	else:
		for cn: Variant in cams:
			if str(cn).begins_with("_"):
				continue
			var cv: Variant = cams[cn]
			if not (cv is Dictionary):
				out.append("cams.%s must be {pos, look, fov}" % str(cn))
				continue
			_check_obj("cams.%s" % str(cn), cv, {"pos": ["v3", true], "look": ["v3", true], "fov": ["num", true, 10.0, 100.0]}, out)
	return out


static func _prefix(at: String, errs: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for e: String in errs:
		out.append(at + ": " + e)
	return out


static func _list(d: Dictionary, key: String) -> Array:
	var v: Variant = d.get(key, [])
	return v if v is Array else []


static func _check_place(at: String, it: Dictionary, circuit_ids: Dictionary, has_terrain: bool, out: PackedStringArray) -> void:
	if it.has("p") == it.has("on"):
		out.append("%s needs exactly one placement: `p` ([x, z] on the ground or [x, y, z]) or `on` ({circuit, s | near})" % at)
		return
	if it.has("on") and it["on"] is Dictionary:
		var on: Dictionary = it["on"]
		if on.has("circuit") and not circuit_ids.has(str(on["circuit"])):
			out.append("%s.on.circuit '%s' is not a circuit id (%s)" % [at, str(on["circuit"]), ", ".join(circuit_ids.keys())])
		if on.has("s") == on.has("near"):
			out.append("%s.on needs exactly one of `s` (metres along the circuit) or `near` ([x, z]: the nearest point of the circuit)" % at)
	elif it.has("p") and TLKit._is_nums(it["p"], 2, 3):
		var q: Array = it["p"]
		if not has_terrain and q.size() == 2:
			pass   # no terrain: the ground is y = 0
		elif has_terrain and not NEAR.has_point(Vector2(q[0], q[q.size() - 1])):
			out.append("%s.p = %s is outside the near terrain (x -224..192, z -288..128)" % [at, str(q)])


static func _check_obj(at: String, d: Dictionary, keys: Dictionary, out: PackedStringArray) -> void:
	for k: Variant in d:
		var ks: String = str(k)
		if ks.begins_with("_"):
			continue
		if not keys.has(ks):
			out.append("%s: unknown key '%s' (allowed: %s)" % [at, ks, ", ".join(keys.keys())])
			continue
		_check_val("%s.%s" % [at, ks] if at != "layout" else ks, d[k], keys[ks], out)
	for k: String in keys:
		if bool(keys[k][1]) and not d.has(k):
			out.append("%s: missing required key '%s'" % [at, k])


static func _check_val(at: String, v: Variant, row: Array, out: PackedStringArray) -> void:
	match String(row[0]):
		"num", "int":
			if not (v is float or v is int) or (row[0] == "int" and float(v) != floorf(float(v))):
				out.append("%s = %s must be a %s" % [at, str(v), "whole number" if row[0] == "int" else "number"])
			elif row.size() > 3 and (float(v) < float(row[2]) or float(v) > float(row[3])):
				out.append("%s = %s is outside %s..%s" % [at, str(v), str(row[2]), str(row[3])])
		"bool":
			if not (v is bool):
				out.append("%s = %s must be true or false" % [at, str(v)])
		"str":
			if not (v is String) or String(v) == "":
				out.append("%s must be a non-empty string" % at)
		"enum":
			var ok: bool = false
			for o: Variant in (row[2] as Array):
				if (o is String and v is String and String(o) == String(v)) or ((o is int or o is float) and (v is int or v is float) and float(o) == float(v)):
					ok = true
			if not ok:
				out.append("%s = %s must be one of %s" % [at, str(v), str(row[2])])
		"v2":
			if not TLKit._is_nums(v, 2, 2):
				out.append("%s = %s must be [x, z]" % [at, str(v)])
		"v3":
			if not TLKit._is_nums(v, 3, 3):
				out.append("%s = %s must be [x, y, z]" % [at, str(v)])
		"v23":
			if not TLKit._is_nums(v, 2, 3):
				out.append("%s = %s must be [x, z] or [x, y, z]" % [at, str(v)])
		"box4":
			if not TLKit._is_nums(v, 4, 4) or float(v[0]) >= float(v[1]) or float(v[2]) >= float(v[3]):
				out.append("%s = %s must be [x0, x1, z0, z1] with x0 < x1 and z0 < z1" % [at, str(v)])
		"box5":
			if not TLKit._is_nums(v, 5, 5) or float(v[0]) >= float(v[1]) or float(v[2]) >= float(v[3]) or float(v[4]) < 0.0 or float(v[4]) > 1200.0:
				out.append("%s = %s must be [x0, x1, z0, z1, pines 0..1200] with x0 < x1 and z0 < z1" % [at, str(v)])
		"obj":
			if not (v is Dictionary):
				out.append("%s must be an object" % at)
			else:
				_check_obj(at, v, row[2], out)
		"list":
			if not (v is Array):
				out.append("%s must be a list" % at)
			else:
				if row.size() > 3 and (v as Array).size() > int(row[3]):
					out.append("%s has %d entries (at most %d)" % [at, (v as Array).size(), int(row[3])])
				for i: int in (v as Array).size():
					_check_val("%s[%d]" % [at, i], v[i], row[2], out)
		_:
			pass


# ------------------------------------------------------------------ build
static func v2(a: Array) -> Vector2:
	return Vector2(a[0], a[1])


static func build(layout: Dictionary, parent: Node3D) -> Dictionary:
	var got: Dictionary = take_ahead(key_of(layout)) if _ahead_count > 0 else {}
	if not got.is_empty():
		var tmp: Node = got["_tmp"]          # P5: built ahead on a worker thread, attached here
		got.erase("_tmp")
		tmp.remove_child(got["root"])
		tmp.free()
		parent.add_child(got["root"])
		return got
	var errs: PackedStringArray = validate(layout)
	if errs.size() > 0:
		return {"ok": false, "errors": errs, "nodes": {}}
	var b: TLKitLayoutBuild = TLKitLayoutBuild.new()
	return b.run(layout, parent)


# ---- P5: a layout built ahead of the call that asks for it --------------------------------------------------------
# `TLKitLayoutBuild.run` builds the whole venue under a root that is not in the scene tree and attaches it last, and
# the kit references nothing outside itself: so the build may run on a worker thread. `build_ahead(layout)` does
# exactly what `build` does, under a parent of its own, and keeps the result; the next `build` of an EQUAL layout
# (same keys and values) takes it and only attaches it. One result serves one `build` call: nothing is shared.
static var _ahead: Dictionary = {}       # key -> Array of results (each with its temporary parent under "_tmp")
static var _ahead_count: int = 0
static var _ahead_lock: Mutex = Mutex.new()


## The identity of a layout: its JSON text with sorted keys, hashed.
static func key_of(layout: Dictionary) -> String:
	return JSON.stringify(layout, "", true).sha1_text()


## Builds `layout` now, off the scene tree, for a later `build`. Safe on a worker thread. Returns the key, "" when the
## layout is not valid (the later `build` then reports the errors as it always did).
static func build_ahead(layout: Dictionary) -> String:
	var key: String = key_of(layout)
	if validate(layout).size() > 0:
		return ""
	var tmp: Node3D = Node3D.new()
	var res: Dictionary = TLKitLayoutBuild.new().run(layout, tmp)
	res["_tmp"] = tmp
	_ahead_lock.lock()
	if not _ahead.has(key):
		_ahead[key] = []
	(_ahead[key] as Array).append(res)
	_ahead_count += 1
	_ahead_lock.unlock()
	return key


## Takes one result built ahead for `key`; {} when there is none.
static func take_ahead(key: String) -> Dictionary:
	var res: Dictionary = {}
	_ahead_lock.lock()
	if _ahead.has(key):
		var list: Array = _ahead[key]
		res = list.pop_front()
		_ahead_count -= 1
		if list.is_empty():
			_ahead.erase(key)
	_ahead_lock.unlock()
	return res


## Frees one result built ahead that no `build` asked for (main thread). True when there was one.
static func drop_ahead(key: String) -> bool:
	var res: Dictionary = take_ahead(key)
	if res.is_empty():
		return false
	(res["_tmp"] as Node).free()
	return true
