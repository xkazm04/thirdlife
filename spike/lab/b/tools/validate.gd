extends SceneTree
## Layout validator (pass 4). Run headless:  tools/g.sh validate <name | path.json>
## Checks a layout file against the contract written down in LAYOUT.md: unknown keys (an ERROR, not ignored), wrong
## types, values out of range, missing required keys, prop kinds that are not kit parts, palette keys that do not exist,
## missing cameras, and a few cross-field rules. Prints one line per finding and "[validate] <file>: OK" or "... FAIL".
## Exit code 0 = valid, 1 = invalid. The schema below is the machine form of LAYOUT.md: change both together.

# near terrain (terrain.gd NX0 / NZ0 / CELL * NNX): everything placed must sit inside it
const X0: float = -224.0
const X1: float = 192.0
const Z0: float = -288.0
const Z1: float = 128.0
const FAR: float = 2600.0

var errs: Array = []
var warns: Array = []
var palette: Dictionary = {}


static func N(lo: float, hi: float, req: bool = false) -> Dictionary:
	return {"t": "num", "min": lo, "max": hi, "req": req}


static func I(lo: int, hi: int, req: bool = false) -> Dictionary:
	return {"t": "int", "min": lo, "max": hi, "req": req}


static func XZ(req: bool = true, far: bool = false) -> Dictionary:
	return {"t": "xz", "req": req, "far": far}


static func XYZ(req: bool = true) -> Dictionary:
	return {"t": "xyz", "req": req}


static func B() -> Dictionary:
	return {"t": "bool"}


static func A(of: Dictionary, req: bool = false, minn: int = 0, maxn: int = 400) -> Dictionary:
	return {"t": "arr", "of": of, "req": req, "minn": minn, "maxn": maxn}


static func O(keys: Dictionary, req: bool = false) -> Dictionary:
	return {"t": "obj", "keys": keys, "req": req}


func schema() -> Dictionary:
	var house: Dictionary = O({"p": XYZ(), "yaw": N(-360, 360), "ext_side": {"t": "enum", "vals": [-1.0, 1.0]}, "frame": B()})
	var cam: Dictionary = O({"pos": {"t": "v3", "req": true}, "look": {"t": "v3", "req": true}, "fov": N(20, 90, true)})
	return O({
		"name": {"t": "str", "req": true},
		"seed": I(0, 1000000),
		"ridge": O({
			"a": XZ(), "b": XZ(), "fall": N(2, 60),
			"ramps": A(O({"c": XZ(), "w": N(4, 60), "fall": N(8, 80)})),
		}, true),
		"pads": A(O({"c": XZ(), "r": N(2, 120, true), "blend": N(1, 80, true), "h": N(-20, 10, true), "dirt": B()}), true),
		"mesas": A(O({"c": XZ(true, true), "r": N(5, 300, true), "h": N(5, 200, true), "blend": N(1, 100), "noise": N(0, 40)})),
		"waterfalls": A(O({"p": XZ(true, true), "to": XZ(true, true), "w": N(1, 40)})),
		"river": A(XZ(true, true), false, 2),
		"circuit": O({
			"y": N(-20, 5), "cps": A(XZ(), true, 4, 60), "wall_at": XZ(),
			"car_a": N(-500, 500), "car_b": N(-500, 500), "wall_blocks": I(3, 60),
		}, true),
		"arena": O({
			"c": XYZ(), "yaw": N(-360, 360), "rink": {"t": "rink", "req": true},
			"rows": I(0, 20), "ribs": I(0, 16, true), "built": I(0, 16, true), "rib_dx": N(3, 20, true), "rib_off": N(-5, 5), "apex": N(4, 40),
			"scaffolds": A(O({"p": {"t": "v2", "req": true}, "yaw": N(-360, 360), "bays": I(1, 8, true), "levels": I(1, 6, true), "decks": A(I(1, 6), true, 1, 6)})),
			"bots": A(O({"p": {"t": "v3", "req": true}, "yaw": N(-360, 360), "state": {"t": "enum", "vals": ["idle", "work"]}, "mobile": B()}), false, 0, 40),
		}, true),
		"cranes": A(O({"p": XZ(), "yaw": N(-360, 360), "trolley": N(0.1, 1.0), "h": N(10, 80), "jib": N(8, 60)}), false, 0, 8),
		"house": house,
		"houses": A(house, false, 0, 12),
		"hero_tree": XZ(false),
		"hero_rocks": A({"t": "rock"}, true, 2, 30),
		"clear": A({"t": "box4"}),
		"forest": O({"density": N(0, 4), "edges": A({"t": "edge5"})}),
		"props": A({"t": "prop"}, false, 0, 400),
		"cams": {"t": "map", "of": cam},
	}, true)


## prop kinds = the kit parts the dispatcher (world.gd _build_props) knows. args: [name, type, required, min, max]
const PROPS: Dictionary = {
	"lumber": [["length", "num", true, 0.5, 8.0], ["width", "num", true, 0.3, 4.0], ["layers", "int", true, 1, 10]],
	"pallet": [["rows", "int", false, 1, 6]],
	"barricade": [],
	"cone": [],
	"fence": [["end x", "num", true, X0, X1], ["end z", "num", true, Z0, Z1]],
	"site_fence": [["end x", "num", true, X0, X1], ["end z", "num", true, Z0, Z1]],
	"sign": [["palette key", "key", false, 0, 0]],
	"flag": [["height", "num", false, 2.0, 20.0], ["palette key", "key", false, 0, 0]],
	"light_mast": [["height", "num", false, 4.0, 30.0]],
	"cabin": [],
	"scoreboard": [],
	"tyres": [["columns", "int", false, 1, 20]],
	"marshal": [],
	"watch_tower": [["height", "num", false, 4.0, 20.0]],
	"entrance": [],
	"pond": [["half size x", "num", true, 2.0, 120.0], ["half size z", "num", true, 2.0, 120.0], ["palette key", "key", false, 0, 0]],
	"bridge": [["length", "num", false, 6.0, 80.0], ["width", "num", false, 2.0, 14.0], ["spans", "int", false, 1, 8]],
	"stones": [["count", "int", true, 1, 12]],
}
const PROP_KEYS: Array = ["k", "p", "s", "side", "off", "yaw", "a"]
const NEED_CAMS: Array = ["hero", "site", "track", "crumble"]


func e(path: String, msg: String) -> void:
	errs.append("%s: %s" % [path, msg])


static func is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT


static func is_int(v: Variant) -> bool:
	return is_num(v) and float(v) == floorf(float(v))


static func tname(v: Variant) -> String:
	match typeof(v):
		TYPE_FLOAT, TYPE_INT: return "number %s" % str(v)
		TYPE_STRING: return "string \"%s\"" % v
		TYPE_BOOL: return "boolean"
		TYPE_ARRAY: return "list of %d" % (v as Array).size()
		TYPE_DICTIONARY: return "object"
		TYPE_NIL: return "null"
	return "value"


func nums(path: String, v: Variant, n: int, what: String) -> bool:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() != n:
		e(path, "expected %s = a list of %d numbers, got %s" % [what, n, tname(v)])
		return false
	for x: Variant in v:
		if not is_num(x):
			e(path, "expected %s = a list of %d numbers, got a %s inside" % [what, n, tname(x)])
			return false
	return true


func in_near(path: String, x: float, z: float, far: bool) -> void:
	if far:
		if absf(x) > FAR or absf(z) > FAR:
			e(path, "(%s, %s) is outside the world (+-%d m)" % [x, z, int(FAR)])
	elif x < X0 or x > X1 or z < Z0 or z > Z1:
		e(path, "(%s, %s) is outside the near terrain (x %d..%d, z %d..%d)" % [x, z, int(X0), int(X1), int(Z0), int(Z1)])


func check(path: String, v: Variant, sp: Dictionary) -> void:
	match String(sp["t"]):
		"str":
			if typeof(v) != TYPE_STRING:
				e(path, "expected a string, got %s" % tname(v))
		"bool":
			if typeof(v) != TYPE_BOOL:
				e(path, "expected true or false, got %s" % tname(v))
		"num", "int":
			if not is_num(v):
				e(path, "expected a number, got %s" % tname(v))
			elif String(sp["t"]) == "int" and not is_int(v):
				e(path, "expected a whole number, got %s" % str(v))
			elif float(v) < float(sp["min"]) or float(v) > float(sp["max"]):
				e(path, "%s is out of range %s..%s" % [str(v), str(sp["min"]), str(sp["max"])])
		"enum":
			if not (sp["vals"] as Array).has(v):
				e(path, "expected one of %s, got %s" % [str(sp["vals"]), tname(v)])
		"v2":
			nums(path, v, 2, "[x, z] (arena-local metres)")
		"v3":
			nums(path, v, 3, "[x, y, z]")
		"xz":
			if nums(path, v, 2, "[x, z]"):
				in_near(path, float(v[0]), float(v[1]), bool(sp.get("far", false)))
		"xyz":
			if nums(path, v, 3, "[x, y, z]"):
				in_near(path, float(v[0]), float(v[2]), false)
				if float(v[1]) < -20.0 or float(v[1]) > 10.0:
					e(path, "y %s is out of range -20..10" % str(v[1]))
		"rink":
			if nums(path, v, 3, "[length, width, corner radius]"):
				if float(v[0]) < 10.0 or float(v[0]) > 120.0:
					e(path, "length %s is out of range 10..120" % str(v[0]))
				if float(v[1]) < 8.0 or float(v[1]) > 60.0:
					e(path, "width %s is out of range 8..60" % str(v[1]))
				if float(v[2]) < 0.0 or float(v[2]) > float(v[1]) * 0.5:
					e(path, "corner radius %s must be 0..half the width" % str(v[2]))
		"rock":
			if nums(path, v, 5, "[x, z, size, squash, seed]"):
				in_near(path, float(v[0]), float(v[1]), false)
				if float(v[2]) < 0.3 or float(v[2]) > 6.0:
					e(path, "size %s is out of range 0.3..6" % str(v[2]))
				if float(v[3]) < 0.2 or float(v[3]) > 1.5:
					e(path, "squash %s is out of range 0.2..1.5" % str(v[3]))
		"box4":
			if nums(path, v, 4, "[x0, x1, z0, z1]"):
				if float(v[0]) >= float(v[1]) or float(v[2]) >= float(v[3]):
					e(path, "box needs x0 < x1 and z0 < z1, got %s" % str(v))
		"edge5":
			if nums(path, v, 5, "[x0, x1, z0, z1, pines]"):
				if float(v[0]) >= float(v[1]) or float(v[2]) >= float(v[3]):
					e(path, "box needs x0 < x1 and z0 < z1, got %s" % str(v))
				if float(v[4]) < 0.0 or float(v[4]) > 1200.0:
					e(path, "pine count %s is out of range 0..1200" % str(v[4]))
		"arr":
			if typeof(v) != TYPE_ARRAY:
				e(path, "expected a list, got %s" % tname(v))
				return
			var a: Array = v
			if a.size() < int(sp.get("minn", 0)) or a.size() > int(sp.get("maxn", 400)):
				e(path, "has %d entries, allowed %d..%d" % [a.size(), int(sp.get("minn", 0)), int(sp.get("maxn", 400))])
			for i: int in a.size():
				check("%s[%d]" % [path, i], a[i], sp["of"])
		"map":
			if typeof(v) != TYPE_DICTIONARY:
				e(path, "expected an object, got %s" % tname(v))
				return
			for k: String in (v as Dictionary):
				check("%s.%s" % [path, k], v[k], sp["of"])
		"obj":
			if typeof(v) != TYPE_DICTIONARY:
				e(path, "expected an object, got %s" % tname(v))
				return
			var d: Dictionary = v
			var keys: Dictionary = sp["keys"]
			for k: String in d:
				if not keys.has(k):
					e("%s.%s" % [path, k] if path != "" else k, "unknown key (allowed here: %s)" % ", ".join(keys.keys()))
			for k: String in keys:
				var sub: String = "%s.%s" % [path, k] if path != "" else k
				if d.has(k):
					check(sub, d[k], keys[k])
				elif bool((keys[k] as Dictionary).get("req", false)):
					e(sub, "required key is missing")
		"prop":
			_prop(path, v)


func _prop(path: String, v: Variant) -> void:
	if typeof(v) != TYPE_DICTIONARY:
		e(path, "expected an object, got %s" % tname(v))
		return
	var d: Dictionary = v
	for k: String in d:
		if not PROP_KEYS.has(k):
			e("%s.%s" % [path, k], "unknown key (allowed here: %s)" % ", ".join(PROP_KEYS))
	if typeof(d.get("k")) != TYPE_STRING:
		e(path + ".k", "required key is missing (the prop kind)")
		return
	var kind: String = d["k"]
	if not PROPS.has(kind):
		e(path + ".k", "\"%s\" is not a kit part (known: %s)" % [kind, ", ".join(PROPS.keys())])
		return
	if d.has("p") == d.has("s"):
		e(path, "a prop needs exactly one of \"p\": [x, z] or \"s\": metres along the circuit")
	if d.has("p"):
		check(path + ".p", d["p"], XZ())
	if d.has("s"):
		check(path + ".s", d["s"], N(-2000, 2000))
		if kind in ["fence", "site_fence", "pond", "bridge"]:
			e(path, "\"%s\" must be placed with \"p\", not \"s\"" % kind)
	elif d.has("side") or d.has("off"):
		e(path, "\"side\" and \"off\" only apply to a prop placed with \"s\"")
	if d.has("side"):
		check(path + ".side", d["side"], {"t": "enum", "vals": [-1.0, 1.0]})
	if d.has("off"):
		check(path + ".off", d["off"], N(0, 60))
	if d.has("yaw"):
		check(path + ".yaw", d["yaw"], N(-360, 360))
	var args: Array = PROPS[kind]
	var a: Variant = d.get("a", [])
	if typeof(a) != TYPE_ARRAY:
		e(path + ".a", "expected a list, got %s" % tname(a))
		return
	var av: Array = a
	if av.size() > args.size():
		e(path + ".a", "\"%s\" takes at most %d argument(s), got %d" % [kind, args.size(), av.size()])
	for i: int in args.size():
		var sp: Array = args[i]
		var ap: String = "%s.a[%d] (%s)" % [path, i, sp[0]]
		if i >= av.size():
			if bool(sp[2]):
				e(ap, "required argument of \"%s\" is missing" % kind)
			continue
		match String(sp[1]):
			"num": check(ap, av[i], N(float(sp[3]), float(sp[4])))
			"int": check(ap, av[i], I(int(sp[3]), int(sp[4])))
			"key":
				if typeof(av[i]) != TYPE_STRING:
					e(ap, "expected a palette key (string), got %s" % tname(av[i]))
				elif not palette.has(av[i]):
					e(ap, "\"%s\" is not a palette key in data/style.json" % av[i])


## Rules that involve more than one key.
func cross(L: Dictionary) -> void:
	var A_: Variant = L.get("arena")
	if typeof(A_) == TYPE_DICTIONARY:
		var A: Dictionary = A_
		if is_num(A.get("ribs")) and is_num(A.get("built")) and float(A["built"]) > float(A["ribs"]):
			e("arena.built", "%s built ribs but only %s ribs" % [str(A["built"]), str(A["ribs"])])
		if typeof(A.get("scaffolds")) == TYPE_ARRAY:
			for i: int in (A["scaffolds"] as Array).size():
				var s: Variant = A["scaffolds"][i]
				if typeof(s) == TYPE_DICTIONARY and is_num(s.get("levels")) and typeof(s.get("decks")) == TYPE_ARRAY:
					for dk: Variant in s["decks"]:
						if is_num(dk) and float(dk) > float(s["levels"]):
							e("arena.scaffolds[%d].decks" % i, "deck level %s is above the %s levels of the scaffold" % [str(dk), str(s["levels"])])
		if typeof(A.get("bots")) == TYPE_ARRAY and typeof(A.get("rink")) == TYPE_ARRAY and (A["rink"] as Array).size() == 3 and is_num(A["rink"][0]):
			for i: int in (A["bots"] as Array).size():
				var b: Variant = A["bots"][i]
				if typeof(b) == TYPE_DICTIONARY and typeof(b.get("p")) == TYPE_ARRAY and (b["p"] as Array).size() == 3 and is_num(b["p"][0]) and is_num(b["p"][2]):
					if Vector2(float(b["p"][0]), float(b["p"][2])).length() > float(A["rink"][0]) * 0.5 + 60.0:
						e("arena.bots[%d].p" % i, "is arena-local; %s is more than 60 m outside the rink (world coordinates by mistake?)" % str(b["p"]))
	var C_: Variant = L.get("circuit")
	if typeof(C_) == TYPE_DICTIONARY and typeof(C_.get("cps")) == TYPE_ARRAY and typeof(C_.get("wall_at")) == TYPE_ARRAY and (C_["wall_at"] as Array).size() == 2:
		var best: float = 1e9
		var pts: Array = []
		for p: Variant in C_["cps"]:
			if typeof(p) == TYPE_ARRAY and (p as Array).size() == 2 and is_num(p[0]) and is_num(p[1]):
				pts.append(Vector2(float(p[0]), float(p[1])))
		if is_num(C_["wall_at"][0]) and is_num(C_["wall_at"][1]) and pts.size() >= 2:
			var w: Vector2 = Vector2(float(C_["wall_at"][0]), float(C_["wall_at"][1]))
			var total: float = 0.0
			for i: int in pts.size():
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[(i + 1) % pts.size()]
				total += a.distance_to(b)
				best = minf(best, Geometry2D.get_closest_point_to_segment(w, a, b).distance_to(w))
				if a.distance_to(b) < 6.0:
					e("circuit.cps[%d]" % i, "is only %.1f m from the next control point (minimum 6 m)" % a.distance_to(b))
			if best > 25.0:
				e("circuit.wall_at", "is %.0f m from the circuit; the wall stands on the road edge nearest to this point (maximum 25 m)" % best)
			if total < 120.0:
				e("circuit.cps", "the loop is about %.0f m long (minimum 120 m)" % total)
			var nb: float = float(C_.get("wall_blocks", 12)) if is_num(C_.get("wall_blocks", 12)) else 12.0
			if nb * 2.46 > total * 0.6:
				e("circuit.wall_blocks", "%s blocks = %.0f m of wall on a loop of about %.0f m" % [str(nb), nb * 2.46, total])
	# a mesa is applied after the road corridor and the pads: one that touches the circuit or the arena buries it
	if typeof(L.get("mesas")) == TYPE_ARRAY:
		for i: int in (L["mesas"] as Array).size():
			var m: Variant = L["mesas"][i]
			if typeof(m) != TYPE_DICTIONARY or typeof(m.get("c")) != TYPE_ARRAY or (m["c"] as Array).size() != 2 or not is_num(m["c"][0]) or not is_num(m["c"][1]) or not is_num(m.get("r")):
				continue
			var mc: Vector2 = Vector2(float(m["c"][0]), float(m["c"][1]))
			var reach: float = float(m["r"]) + (float(m["blend"]) if is_num(m.get("blend")) else 20.0)
			if typeof(C_) == TYPE_DICTIONARY and typeof(C_.get("cps")) == TYPE_ARRAY:
				var cp: Array = C_["cps"]
				for j: int in cp.size():
					var a2: Variant = cp[j]
					var b2: Variant = cp[(j + 1) % cp.size()]
					if typeof(a2) == TYPE_ARRAY and typeof(b2) == TYPE_ARRAY and (a2 as Array).size() == 2 and (b2 as Array).size() == 2 and is_num(a2[0]) and is_num(a2[1]) and is_num(b2[0]) and is_num(b2[1]):
						var dd: float = Geometry2D.get_closest_point_to_segment(mc, Vector2(float(a2[0]), float(a2[1])), Vector2(float(b2[0]), float(b2[1]))).distance_to(mc)
						if dd < reach + 8.0:
							e("mesas[%d]" % i, "reaches the circuit (its flank ends %.0f m from the centre, the road passes at %.0f m; keep 8 m clear): it would bury the road" % [reach, dd])
							break
			if typeof(A_) == TYPE_DICTIONARY and typeof(A_.get("c")) == TYPE_ARRAY and (A_["c"] as Array).size() == 3 and is_num(A_["c"][0]) and is_num(A_["c"][2]):
				var ar: float = 20.0
				if typeof(A_.get("rink")) == TYPE_ARRAY and (A_["rink"] as Array).size() == 3 and is_num(A_["rink"][0]):
					ar = float(A_["rink"][0]) * 0.5 + 6.0
				if mc.distance_to(Vector2(float(A_["c"][0]), float(A_["c"][2]))) < reach + ar:
					e("mesas[%d]" % i, "reaches the arena: it would bury the rink")
	if L.has("house") == false and (typeof(L.get("houses")) != TYPE_ARRAY or (L["houses"] as Array).is_empty()):
		warns.append("house / houses: the layout has no house (allowed)")
	var cams: Variant = L.get("cams", {})
	if typeof(cams) == TYPE_DICTIONARY and String(L.get("name", "")) != "main":
		for c: String in NEED_CAMS:
			if not (cams as Dictionary).has(c):
				e("cams.%s" % c, "camera is missing; data/cams.json would supply the MAIN layout's view of another place")
	elif typeof(cams) == TYPE_DICTIONARY and not (cams as Dictionary).has("hero"):
		e("cams.hero", "camera is missing")
	if typeof(L.get("waterfalls")) == TYPE_ARRAY and not (L["waterfalls"] as Array).is_empty() and (typeof(L.get("mesas")) != TYPE_ARRAY or (L["mesas"] as Array).is_empty()):
		e("waterfalls", "a waterfall needs a mesa to fall from (its \"p\" must be on a mesa top)")


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: tools/g.sh validate <name | path.json> ...")
		quit(2)
		return
	var sf: FileAccess = FileAccess.open("res://data/style.json", FileAccess.READ)
	palette = (JSON.parse_string(sf.get_as_text()) as Dictionary)["palette"]
	var sc: Dictionary = schema()
	var bad: int = 0
	for arg: String in args:
		errs = []
		warns = []
		var path: String = arg
		if not arg.ends_with(".json"):
			path = "res://data/layout.json" if arg == "main" else "res://data/layout_%s.json" % arg
		elif not (arg.begins_with("res://") or arg.is_absolute_path()):
			path = "res://" + arg
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f == null:
			print("[validate] %s: FAIL  cannot open the file" % path)
			bad += 1
			continue
		var js: JSON = JSON.new()
		if js.parse(f.get_as_text()) != OK:
			print("[validate] %s: FAIL  not valid JSON: line %d: %s" % [path, js.get_error_line(), js.get_error_message()])
			bad += 1
			continue
		check("", js.data, sc)
		if typeof(js.data) == TYPE_DICTIONARY:
			cross(js.data)
		for w: String in warns:
			print("[validate]   note   %s" % w)
		for x: String in errs:
			print("[validate]   error  %s" % x)
		if errs.is_empty():
			print("[validate] %s: OK" % path)
		else:
			print("[validate] %s: FAIL  %d error(s)" % [path, errs.size()])
			bad += 1
	quit(1 if bad > 0 else 0)
