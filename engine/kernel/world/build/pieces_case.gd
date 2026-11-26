extends SceneTree
## M3 (spark world-sandbox, 26 Nov 2026): the pieces layer, headless (engine/tools/selftest.d/756-home-pieces.sh).
## Prints `HOME pieces.<case> ok|fail <detail>`, then `HOME pieces ok` (or fail) and `HOME DONE`. Frames, not wall clock
## (wall-clock figures are measured and printed, never decided on).
##   pieces.each     every catalogue part: put, drawn, lift, undo (back), undo (gone), redo; a record per piece
##   pieces.refuse   a block in a footprint, a piece over a block and over a piece, land and paint under a piece (the area
##                   rule), a lift of nothing, a footprint too large, the y range, a game lot
##   pieces.hash     the same ops in two Homes give the same content hash, save bytes and draw figures
##   pieces.files    tl.build/2 with `pieces`: save, load, save byte for byte; the journal's puts and lifts replay
##   pieces.region   read_region gives the pieces anchored in the box, sorted; a dry run leaves the Home untouched
##   pieces.walk     in the Home's landscape: a walker driven at a placed cabin is stopped by it (frames counted);
##                   lifted, he walks through; the body is tagged "home pieces" in the visitor's space only
##   pieces.draw     500 fences and 200 trees: multimeshes, instances, nodes, bodies, build ms; in a window (not
##                   headless, TL_PIECES_DRAW=1) also the draw calls and frame ms of a view over them

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const Catalog := preload("res://kernel/world/build/piece_catalog.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const BuildFile := preload("res://kernel/world/build/build_file.gd")
const TMP := "user://tl_pieces_case"
const SITE_AT := Vector2i(640, -40)     # where the walker meets the cabin (moved east until a cabin fits)

var ok_all := true
var holder: Node3D


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME pieces.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	holder = Node3D.new()
	root.add_child(holder)
	DirAccess.make_dir_recursive_absolute(TMP)
	each()
	refuse()
	hashes()
	files()
	region()
	await draw_case()
	await walk_case()
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	print("HOME pieces %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


func put(at: Vector3i, part: String, rot := 0, params := {}) -> Dictionary:
	var op := {"op": "put", "at": [at.x, at.y, at.z], "part": part, "rot": rot}
	if not params.is_empty():
		op["params"] = params
	return op


# ------------------------------------------------------------------ cases
func each() -> void:
	var b: RefCounted = HomeBuild.new(holder, null, {})
	var L: RefCounted = b.layer("pieces")
	var bad := []
	var seen := []
	for i: int in Catalog.PARTS.size():
		var part: String = Catalog.PARTS[i]
		var at := Vector3i(i * 40, 2, 0)
		var r: Dictionary = b.apply(put(at, part, i % 4))
		b.flush()
		var f: Dictionary = L.figures()
		var drawn: int = int(f.multimeshes) + int(f.nodes)
		var u1: int = b.undo()
		var gone_after_lift := false
		var r2: Dictionary = b.apply(put(at, part, i % 4))
		var lift: Dictionary = b.apply({"op": "lift", "at": [at.x, at.y, at.z]})
		gone_after_lift = L.size() == 0
		var back: int = b.undo()
		var after_undo: int = L.size()
		b.undo()
		var after_two: int = L.size()
		b.redo()
		var after_redo: int = L.size()
		b.undo()
		b.flush()
		var fp: Array = L.footprint_of(put(at, part, i % 4))
		var size: Vector3i = (fp[1] as Vector3i) - (fp[0] as Vector3i) + Vector3i.ONE
		seen.append("%s %dx%dx%d" % [part, size.x, size.y, size.z])
		if not (r.ok and r2.ok and lift.ok and drawn >= 1 and u1 == 1 and gone_after_lift and back == 1 and after_undo == 1 and after_two == 0 and after_redo == 1 and L.size() == 0):
			bad.append("%s: put %s '%s', drawn %d, lift %s gone %s, undo %d -> %d, %d, redo %d" % [part, r.ok, r.reason, drawn, lift.ok, gone_after_lift, back, after_undo, after_two, after_redo])
	var f2: Dictionary = L.figures()
	var empty: bool = int(f2.multimeshes) == 0 and int(f2.nodes) == 0
	b.free_all()
	say("each", bad.is_empty() and empty, "%d parts put, drawn, lifted, undone and redone; footprints %s; after the last undo nothing drawn %s%s" % [
		Catalog.PARTS.size(), ", ".join(seen), empty, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func refuse() -> void:
	var b: RefCounted = HomeBuild.new(null, null, {})
	b.protect.add_circle(Vector2(500.5, 500.5), 3.0, "game lot")
	var got := {}
	b.apply(put(Vector3i(0, 0, 0), "fence"))                                   # cells x 0..7, y 0..1, z 0
	got["block in a fence"] = str(b.place(Vector3i(3, 1, 0), Blocks.code(1, 3)).reason)
	got["block beside it"] = str(b.place(Vector3i(3, 0, 1), Blocks.code(1, 3)).reason)
	got["crate on a block"] = str(b.apply(put(Vector3i(3, 0, 1), "crate")).reason)
	got["crate in the fence"] = str(b.apply(put(Vector3i(5, 0, 0), "crate")).reason)
	got["house over the fence"] = str(b.apply(put(Vector3i(4, 0, -5), "house")).reason)
	got["crate on the fence's end"] = str(b.apply(put(Vector3i(8, 0, 0), "crate")).reason)
	b.apply(put(Vector3i(40, 0, 40), "house"))
	got["land under the house"] = str(b.protect.refusal_area(Rect2(39, 39, 3, 3), "land"))
	got["paint beside it"] = str(b.protect.refusal_area(Rect2(60, 60, 3, 3), "paint"))
	got["lift of nothing"] = str(b.apply({"op": "lift", "at": [9, 9, 9]}).reason)
	got["lift naming another part"] = str(b.apply({"op": "lift", "at": [40, 0, 40], "part": "cabin"}).reason)
	got["a 40 m fence"] = str(b.apply(put(Vector3i(0, 0, 80), "fence", 0, {"length": 40.0})).reason)
	got["a mast at y 100"] = str(b.apply(put(Vector3i(0, 100, 120), "light_mast")).reason)
	got["a bench on a lot"] = str(b.apply(put(Vector3i(500, 0, 500), "bench")).reason)
	var want := {"block in a fence": "piece (fence)", "block beside it": "", "crate on a block": "occupied (a block at 3, 0, 1)",
		"crate in the fence": "occupied (fence)", "house over the fence": "occupied (fence)", "crate on the fence's end": "",
		"land under the house": "piece (house)", "paint beside it": "", "lift of nothing": "no piece there",
		"lift naming another part": "the cell holds another piece (part)", "a 40 m fence": "too large for a piece",
		"a mast at y 100": "out of range", "a bench on a lot": "game lot"}
	var bad := []
	var lines := []
	for k: String in want:
		lines.append("%s: '%s'" % [k, got[k]])
		if not (str(got[k]).begins_with(want[k]) and (want[k] != "" or got[k] == "")):
			bad.append("%s: '%s', want '%s'" % [k, got[k], want[k]])
	var logged := 0
	for h: Dictionary in b.edits.history:
		logged += (h.ops as Array).size()
	say("refuse", bad.is_empty() and logged == 4, "; ".join(lines) + "; ops logged %d (2 puts, a block, a crate)" % logged + ("" if bad.is_empty() else "; BAD " + "; ".join(bad)))


func town_ops(n_fence: int, n_tree: int, x0 := 0, z0 := 0) -> Array:
	var ops := []
	for i: int in n_fence:
		ops.append(put(Vector3i(x0 + (i % 25) * 9, 0, z0 + (i / 25) * 3), "fence", 0))
	for i: int in n_tree:
		ops.append(put(Vector3i(x0 + (i % 20) * 12, 0, z0 + 70 + (i / 20) * 12), "tree", i % 4, {"species": "broadleaf"} if i % 3 == 0 else {}))
	return ops


func hashes() -> void:
	var out := []
	for k in 2:
		var b: RefCounted = HomeBuild.new(holder, null, {})
		var r: Dictionary = b.apply(town_ops(60, 30))
		b.place(Vector3i(-5, 0, -5), Blocks.code(1, 3))
		b.flush()
		var L: RefCounted = b.layer("pieces")
		var doc: Dictionary = BuildFile.text_of(b.layers, 7, 1)
		out.append({"ok": r.ok, "hash": L.content_hash(), "text": doc.text, "fig": L.figures()})
		b.free_all()
	var same: bool = out[0].hash == out[1].hash and out[0].text == out[1].text and str(out[0].fig) == str(out[1].fig)
	say("hash", out[0].ok and out[1].ok and same and out[0].hash != "", "90 puts twice: content hash %s (%s), build file %d bytes (%s), figures %s" % [
		str(out[0].hash).left(12), "same" if out[0].hash == out[1].hash else "DIFFERENT", (out[0].text as String).length(),
		"same" if out[0].text == out[1].text else "DIFFERENT", str(out[0].fig)])


func files() -> void:
	var d := TMP.path_join("files")
	var b: RefCounted = HomeBuild.new(null, null, {"seed": 11})
	b.load(d)
	b.apply(town_ops(10, 5))
	b.place(Vector3i(-5, 0, -5), Blocks.code(1, 3))
	var e1 := str(b.save(d))
	var t1 := FileAccess.get_file_as_string(d.path_join("build.json"))
	var c: RefCounted = HomeBuild.new(null, null, {"seed": 11})
	var r1: Dictionary = c.load(d)
	var e2 := str(c.save(d))
	var t2 := FileAccess.get_file_as_string(d.path_join("build.json"))
	# journal: puts and a lift after the save replay over it
	c.apply(put(Vector3i(300, 0, 300), "bench", 1, {"length": 2.4}))
	c.apply(put(Vector3i(310, 0, 300), "street_lamp", 2))
	c.apply({"op": "lift", "at": [0, 0, 0]})
	var lines := FileAccess.get_file_as_string(d.path_join("edits.jsonl")).strip_edges().split("\n")
	var want: Array = c.layer("pieces").sorted()
	var e: RefCounted = HomeBuild.new(null, null, {"seed": 11})
	var r2: Dictionary = e.load(d)
	var got: Array = e.layer("pieces").sorted()
	var v2: bool = t1.begins_with("{\"v\":2,") and t1.contains("\"pieces\":[{\"at\":")
	var ok: bool = e1 == "" and e2 == "" and r1.ok and t1 == t2 and v2 and r2.ok and int(r2.replayed) == 3 and str(got) == str(want) and lines.size() == 3
	say("files", ok, "saved v2 %s (%d bytes, pieces %d); load + save byte-identical %s; 3 journal lines (%s) replayed %d, pieces %d = %d%s" % [
		v2, t1.length(), b.layer("pieces").size(), t1 == t2, lines[0].left(90), int(r2.replayed), got.size(), want.size(),
		"" if ok else "; errors '%s' '%s' load %s/%s bad %s" % [e1, e2, r1.reason, r2.reason, str(r2.bad)]])


func region() -> void:
	var b: RefCounted = HomeBuild.new(null, null, {})
	b.apply([put(Vector3i(5, 0, 9), "crate"), put(Vector3i(2, 0, 3), "bench"), put(Vector3i(8, 1, 3), "rock"), put(Vector3i(50, 0, 50), "tree")])
	var reg: Dictionary = b.read_region(Vector3i(0, 0, 0), Vector3i(10, 5, 10))
	var ats: Array = (reg.get("pieces", []) as Array).map(func(p: Dictionary) -> String: return str(p.at))
	var before: String = b.layer("pieces").content_hash()
	var hist: int = b.edits.history.size()
	var pv: Dictionary = b.preview([put(Vector3i(20, 0, 20), "cabin"), put(Vector3i(5, 0, 9), "crate")])
	var scratch_has: bool = (pv.scratch.pieces as RefCounted).pieces.has(Vector3i(20, 0, 20))
	var untouched: bool = b.layer("pieces").content_hash() == before and b.edits.history.size() == hist and not b.layer("pieces").pieces.has(Vector3i(20, 0, 20))
	var ok: bool = ats == ["[2, 0, 3]", "[8, 1, 3]", "[5, 0, 9]"] and int(pv.applied) == 1 and (pv.refused as Array).size() == 1 and scratch_has and untouched
	say("region", ok, "pieces in the box %s; a dry run of 2 puts applied %d, refused %s; the scratch copy has the cabin %s; the Home untouched %s" % [
		str(ats), int(pv.applied), str(pv.refused), scratch_has, untouched])


func draw_case() -> void:
	var b: RefCounted = HomeBuild.new(holder, null, {})
	var ops := town_ops(500, 200, -110, -60)
	var t0 := Time.get_ticks_usec()
	var r: Dictionary = b.apply(ops)
	var t1 := Time.get_ticks_usec()
	b.flush()
	var t2 := Time.get_ticks_usec()
	var f: Dictionary = b.layer("pieces").figures()
	var tris := 0
	for p: Dictionary in b.layer("pieces").pieces.values():
		tris += int(p.proto.tris)
	var ok: bool = r.ok and int(f.pieces) == 700 and int(f.instances) == 700 and int(f.nodes) == 0
	var detail := "500 fences + 200 trees: applied %d in %.0f ms, drawn in %.0f ms: %d sections, %d multimeshes, %d instances, %d nodes, %d triangles" % [
		int(r.applied), (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, int(f.sections), int(f.multimeshes), int(f.instances), int(f.nodes), tris]
	if DisplayServer.get_name() != "headless":
		detail += "; " + await _rendered(b)
	say("draw", ok, detail)
	b.free_all()


## In a window: a camera over the town, 120 frames; the frame's draw calls and the median process and render ms.
func _rendered(_b: RefCounted) -> String:
	var cam := Camera3D.new()
	holder.add_child(cam)
	cam.global_position = Vector3(0, 60, 80)
	cam.look_at(Vector3(0, 0, -10))
	cam.make_current()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var calls := []
	var cpu := []
	var gpu := []
	for i in 120:
		await process_frame
		if i >= 30:
			calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	calls.sort()
	cpu.sort()
	gpu.sort()
	cam.queue_free()
	return "in a window: %d draw calls a frame (median), render %.2f ms cpu, %.2f ms gpu (median of 90 frames)" % [int(calls[calls.size() / 2]), cpu[cpu.size() / 2], gpu[gpu.size() / 2]]


# ------------------------------------------------------------------ the walk (in the Home's landscape)
func walk_case() -> void:
	var walk := CaseUtil.walk()
	TLStyle.set_headless(false)                     # landscape.gd builds nothing in headless style
	var land: Node3D = CaseUtil.landscape(root, walk)
	if not land.has_meta(&"tl_build"):
		say("walk", false, "no Home builder on the landscape (TL_HOME=%s)" % OS.get_environment("TL_HOME"))
		return
	var b: RefCounted = land.get_meta(&"tl_build")
	var ws: Object = land.get_meta(&"tl_space")
	var home: Object = land.get_meta(&"tl_home")
	b.protect.visitor_at = Callable()
	var L: RefCounted = b.layer("pieces")
	var site := {}
	for k in 30:
		var x := SITE_AT.x + 8 * k
		var z := SITE_AT.y
		home.call("ensure", Vector2(x, z))
		var gy := int(floorf(float(home.call("ground_y", x + 0.5, z + 0.5))))
		var op := put(Vector3i(x, gy, z), "cabin")
		ws.call("place", Vector3(x + 0.5, gy + 1.0, z + 30.5))
		var why: String = str(b.edits.validate(op))
		if why == "":
			why = str(L.can_apply(op))
		if why == "":
			site = {"x": x, "y": gy, "z": z, "op": op, "tries": k + 1}
			break
	if site.is_empty():
		say("walk", false, "no free cabin site from %s in 30 tries" % str(SITE_AT))
		return
	var r: Dictionary = b.apply(site.op)
	b.flush()
	var rec: Dictionary = L.pieces[Vector3i(site.x, site.y, site.z)]
	var tags: Dictionary = ws.get("_tags")
	var tagged := 0
	for rid: Variant in tags:
		if str(tags[rid]) == "home pieces":
			tagged += 1
	var start := Vector3(site.x + 0.5, float(home.call("ground_y", site.x + 0.5, site.z + 12.5)) + 0.05, site.z + 12.5)
	var w1 := walker(ws, start, rec.lo.z + 0.0, rec.hi.z + 1.0)
	b.apply({"op": "lift", "at": [site.x, site.y, site.z]})
	b.flush()
	var w2 := walker(ws, start, rec.lo.z + 0.0, rec.hi.z + 1.0)
	var bodies_after := 0
	for rid: Variant in (ws.get("_tags") as Dictionary):
		if str((ws.get("_tags") as Dictionary)[rid]) == "home pieces":
			bodies_after += 1
	var ok: bool = r.ok and tagged == 1 and bool(w1.stopped) and not bool(w2.stopped) and bodies_after == 0 and float(rec.lift) >= 0.0
	say("walk", ok, "cabin at (%d, %d, %d) after %d tries (stands %.2f m up on the ground, footprint z %d..%d), 1 body tagged home pieces: %d; driven at 4.5 m/s toward -z: %s; lifted: %s; bodies left %d" % [
		site.x, site.y, site.z, site.tries, float(rec.lift), rec.lo.z, rec.hi.z, tagged, w1.text, w2.text, bodies_after])
	await wait(1)


## A walker driven from `from` toward -z for 300 frames: stopped (10 still frames) before the cabin's far side?
func walker(ws: Object, from: Vector3, near_z: float, far_z: float) -> Dictionary:
	var pos := from
	ws.call("place", pos)
	ws.call("rest")
	var still := 0
	var stopped := -1
	var min_z := pos.z
	for f: int in 300:
		var d: Dictionary = ws.call("drive", pos, Vector3(0.0, 0.0, -4.5), false, false)
		var moved: float = absf(float(d.pos.z) - pos.z)
		pos = d.pos
		min_z = minf(min_z, pos.z)
		still = still + 1 if moved < 0.001 else 0
		if stopped < 0 and still >= 10:
			stopped = f - 9
			break
	var at_wall: bool = stopped >= 0 and min_z > near_z
	return {"stopped": at_wall, "text": ("stopped at frame %d with his feet at z %.2f, inside the footprint's edge (z %.0f) at the cabin's wall" % [stopped, min_z, far_z]) if at_wall
		else "not stopped in 300 frames (furthest z %.2f, the cabin's footprint %.0f..%.0f)" % [min_z, near_z, far_z]}
