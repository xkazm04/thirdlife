extends SceneTree
## Lane DN (day of 27 Nov 2026): the scene of the day-and-night captures, made headless and saved as a Home build file
## that a windowed run loads (TL_HOME_BUILD_DIR) for its pictures. A lamp-lit street: street lamps every --spacing m on
## both sides of a line, houses on one side, a light mast at each end, each put on the ground the cursor ray finds (as
## the piece tool does). Not a selftest: a capture helper.
##   godot --headless --fixed-fps 60 --path engine --script res://kernel/world/home/day_shots.gd -- --out=<abs dir>
##         --street=x0,z0,x1,z1 [--spacing=8] [--probe]
## Prints `SHOTS put <part> <n> refused <n> (<first reasons>)`, `SHOTS lights <n>` and `SHOTS DONE`. --probe only prints
## the valley's border and whether cells round the line can take a piece.

const CaseUtil := preload("res://kernel/world/build/case_util.gd")

var out := ""
var street := PackedFloat64Array()
var probe := false
var spacing := 8.0


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--street="):
			street = a.substr(9).split_floats(",")
		elif a.begins_with("--spacing="):
			spacing = float(a.substr(10))
		elif a == "--probe":
			probe = true
	call_deferred("run")


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	TLStyle.set_headless(false)
	if street.size() != 4 or (out == "" and not probe):
		print("SHOTS fail: --out=<abs dir> and --street=x0,z0,x1,z1 are needed")
		quit(1)
		return
	var node := CaseUtil.landscape(root, CaseUtil.walk())
	var b: RefCounted = node.get_meta(&"tl_build")
	await wait(5)
	var a := Vector2(street[0], street[1])
	var e := Vector2(street[2], street[3])
	var dir := (e - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	var n := int(a.distance_to(e) / spacing)
	var plan := []                                  # [part, xz, rot, params]
	var rot_l := _rot_facing(-side)
	var rot_r := _rot_facing(side)
	for i: int in n + 1:
		var p := a + dir * spacing * i
		plan.append(["street_lamp", p + side * 4.5, rot_l, {}])
		plan.append(["street_lamp", p - side * 4.5, rot_r, {}])
		if i % maxi(2, roundi(16.0 / spacing)) == 1:
			plan.append(["house", p + side * 12.0, rot_l, {}, [p - side * 12.0, rot_r], [p + side * 16.0, rot_l], [p - side * 16.0, rot_r]])
	plan.append(["light_mast", a - dir * 6.0, rot_r, {"height": 10.0}])
	plan.append(["light_mast", e + dir * 6.0, rot_l, {"height": 10.0}])
	var got := {}
	var why := {}
	for st: Array in plan:
		var part: String = st[0]
		var tries := [[st[1], st[2]]] + st.slice(4)       # the place, then the other places a house may take
		var last := ""
		for tr: Array in tries:
			var xz: Vector2 = tr[0]
			var hit: Dictionary = b.pick(Vector3(xz.x, 300.0, xz.y), Vector3(xz.x, -100.0, xz.y))
			if hit.is_empty():
				last = "no ground at %.0f,%.0f" % [xz.x, xz.y]
				continue
			var c: Vector3i = hit.place
			var op := {"op": "put", "at": [c.x, c.y, c.z], "part": part, "rot": tr[1]}
			if not (st[3] as Dictionary).is_empty():
				op["params"] = st[3]
			if probe:
				print("SHOTS probe %s at %.0f,%.0f cell %s: %s" % [part, xz.x, xz.y, c, b.layer("pieces").can_apply(op)])
				continue
			var r: Dictionary = b.apply(op)
			if bool(r.ok) and int(r.applied) == 1:
				got[part] = int(got.get(part, 0)) + 1
				last = ""
				break
			last = str(r.reason)
		if last != "":
			why[part] = (why.get(part, []) as Array) + [last]
	b.flush()
	for part: String in ["street_lamp", "house", "light_mast"]:
		var w: Array = why.get(part, [])
		print("SHOTS put %s %d refused %d (%s)" % [part, int(got.get(part, 0)), w.size(), ", ".join(PackedStringArray(w.slice(0, 3)))])
	var lamps: RefCounted = b.layer("pieces").get("draw").get("lamps")
	print("SHOTS lights %d" % int(lamps.call("count")))
	print("SHOTS border %s" % str(node.get_meta(&"tl_home").get("border")))
	if not probe:
		DirAccess.make_dir_recursive_absolute(out)
		print("SHOTS save %s" % str(b.save(out)))
	print("SHOTS DONE")
	quit(0)


static func _rot_facing(d: Vector2) -> int:
	# rot 0 faces +z (a street lamp's arm reaches over +Z); rot 1 turns -z to -x (BUILD.md), so +z to +x
	var ang := atan2(d.x, d.y)
	return posmod(roundi(ang / (PI * 0.5)), 4)
