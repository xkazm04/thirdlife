extends SceneTree
## Lane P (M6 rules and runs, 27 Nov 2026): the headless case of selftest 774 (engine/tools/selftest.d/774-home-rules-
## play.sh): the Home's rules in the visit, with the real facade (play_facade.gd). Prints `HOME rules-play.<case> ok|fail
## <detail>`, then `HOME rules-play ok` (or fail) and `HOME DONE`. Frames, not wall clock.
##   mask    block_mesh.gd leaves an open zone's cells out of the section mesh and the chunk body: the triangles and the
##           body's faces drop while masked, the faces the door hid are drawn, and with the mask off (or a mask that
##           meets no section) every hash, triangle and face count is what it was: no mask, no change
##   walk    the scripted walk of play_case_course.gd: start -> coin -> door (use) -> launch -> checkpoint -> lava ->
##           out of the world -> finish -> restart; the door blocks the walker, opens passable on E (the game's
##           enter request taken back), slides, closes solid; the HUD's clock, counters, say line and finish card;
##           records written (tl.records/1); E outside a use zone leaves a game's enter alone
##   same    the walk twice in two fresh worlds: the facade's calls are the same, in the same order (deterministic)
##   looks   play_looks.gd: one look per zone with a look, pads tinted by role, `look_of` for lane T, no body in a
##           look (a flag is run through), the shared meshes (100 coins: 100 nodes, one mesh)
##   build   build mode on mid-run: the run dropped, the open door shut at once (no slide), the looks and the HUD hidden

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const Course := preload("res://kernel/world/build/play_case_course.gd")
const PlayLooks := preload("res://kernel/world/build/play_looks.gd")
const PlayHud := preload("res://kernel/world/build/play_hud.gd")
const TMP := "user://tl_rules_play_case"

var ok_all := true


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME rules-play.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func run() -> void:
	TLStyle.set_headless(false)
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	DirAccess.make_dir_recursive_absolute(TMP + "/a")
	DirAccess.make_dir_recursive_absolute(TMP + "/b")
	DirAccess.make_dir_recursive_absolute(TMP + "/c")
	mask()
	var c1: RefCounted = Course.new(self)
	var why: String = c1.call("make", root, TMP + "/a")
	var w1: Dictionary = {"ok": false, "text": why, "calls": ""}
	if why == "":
		w1 = await c1.call("walk")
	var rec_file := FileAccess.get_file_as_string(TMP + "/a/records.json")
	var rec_ok := rec_file.contains("\"schema\":\"tl.records/1\"") or rec_file.contains("\"schema\": \"tl.records/1\"")
	say("walk", bool(w1.ok) and rec_ok, str(w1.text) + ("" if rec_ok else "; BAD records.json: '%s'" % rec_file.left(120)))
	c1.call("free_all")
	c1 = null
	await _wait(3)
	var c2: RefCounted = Course.new(self)
	var why2: String = c2.call("make", root, TMP + "/b")
	var w2: Dictionary = {"ok": false, "text": why2, "calls": ""}
	if why2 == "":
		w2 = await c2.call("walk")
	var same := str(w1.calls) == str(w2.calls) and str(w1.get("finish", {})) == str(w2.get("finish", {})) and str(w1.calls) != ""
	say("same", same, "two walks in two worlds: %d facade calls kept (last 64), equal %s; finish %s / %s" % [
		str(w1.calls).count("], ["), str(w1.calls) == str(w2.calls), str(w1.get("finish", {})), str(w2.get("finish", {}))])
	c2.call("free_all")
	c2 = null
	await _wait(3)
	looks()
	var c3: RefCounted = Course.new(self)
	var why3: String = c3.call("make", root, TMP + "/c")
	say("build", why3 == "" and await build_mid_run(c3), why3 if why3 != "" else _build_text)
	c3.call("free_all")
	c3 = null
	await _wait(3)
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	PlayLooks._meshes.clear()                  # the shared look meshes, so nothing is left in use at exit
	print("HOME rules-play %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


# ------------------------------------------------------------------ mask
func mask() -> void:
	var bad := []
	var holder := Node3D.new()
	root.add_child(holder)
	var b: RefCounted = HomeBuild.new(holder, null, {"seed": 3})
	b.begin_batch()
	for y: int in 3:
		for x: int in range(-3, 4):
			b.place(Vector3i(x, y, 0), Blocks.code(Blocks.CUBE, 1))
	b.place(Vector3i(0, 0, 1), Blocks.code(Blocks.STAIR, 2))
	b.place(Vector3i(14, 0, 0), Blocks.code(Blocks.CUBE, 1))          # a block in the next section (x 16 m sections: 0..15)
	b.place(Vector3i(17, 0, 0), Blocks.code(Blocks.CUBE, 3))
	b.end_batch()
	b.flush()
	var bl: RefCounted = b.layer("blocks")
	var m: RefCounted = b.mesh
	var ch := Vector2i(0, 0)
	var f0: Dictionary = m.call("chunk_figures", ch)
	var s0 := Vector2i(0, 0)
	var a0: Dictionary = m.call("arrays", s0)
	var h1: String = (m.get("hashes") as Dictionary).get(Vector2i(1, 0), "")
	bl.set_mask(3, Vector3i(-1, 0, 0), Vector3i(1, 2, 0), true)
	b.flush()
	var f1: Dictionary = m.call("chunk_figures", ch)
	var a1: Dictionary = m.call("arrays", s0)
	var h1_masked: String = (m.get("hashes") as Dictionary).get(Vector2i(1, 0), "")
	var hits := _ray_cells(a1, Vector3(0.5, 1.5, -3.0), Vector3(0.5, 1.5, 3.0))
	var hits0 := _ray_cells(a0, Vector3(0.5, 1.5, -3.0), Vector3(0.5, 1.5, 3.0))
	if int(f1.tris) >= int(f0.tris) or str(f1.hash) == str(f0.hash) or (a1.col as PackedVector3Array).size() >= (a0.col as PackedVector3Array).size():
		bad.append("masked: tris %d -> %d, collider %d -> %d" % [int(f0.tris), int(f1.tris), (a0.col as PackedVector3Array).size(), (a1.col as PackedVector3Array).size()])
	if hits != 0 or hits0 == 0:
		bad.append("a ray through the masked door meets %d collider triangles (before: %d)" % [hits, hits0])
	if h1_masked != h1 or h1 == "":
		bad.append("a section the mask does not meet changed (%s -> %s)" % [h1, h1_masked])
	# the faces the door hid: the wall's cells beside the door show their side faces into the gap
	var side := _faces_x(a1, 2.0)
	var side0 := _faces_x(a0, 2.0)
	if side <= side0:
		bad.append("the faces the door hid are not drawn (%d triangles in x = 2 masked, %d before)" % [side, side0])
	bl.set_mask(3, Vector3i(-1, 0, 0), Vector3i(1, 2, 0), false)
	b.flush()
	var f2: Dictionary = m.call("chunk_figures", ch)
	var a2: Dictionary = m.call("arrays", s0)
	if str(f2.hash) != str(f0.hash) or int(f2.tris) != int(f0.tris) or str(a2.hash) != str(a0.hash) or (a2.col as PackedVector3Array) != (a0.col as PackedVector3Array):
		bad.append("mask off: hash %s -> %s, tris %d -> %d, collider same %s" % [str(f0.hash).left(8), str(f2.hash).left(8), int(f0.tris), int(f2.tris), (a2.col as PackedVector3Array) == (a0.col as PackedVector3Array)])
	# a mask far away: the store's own cells, the same arrays
	bl.set_mask(9, Vector3i(500, 0, 500), Vector3i(501, 1, 501), true)
	var a3: Dictionary = m.call("arrays", s0)
	bl.clear_masks()
	if str(a3.hash) != str(a0.hash):
		bad.append("a mask that meets no section changed the arrays")
	b.free_all()
	holder.queue_free()
	say("mask", bad.is_empty(), "door 3x3 masked: tris %d -> %d, collider triangles %d -> %d, a ray through it %d -> %d hits, gap side triangles %d -> %d; mask off: hash %s = %s; far mask: same arrays%s" % [
		int(f0.tris), int(f1.tris), (a0.col as PackedVector3Array).size() / 3, (a1.col as PackedVector3Array).size() / 3, hits0, hits, side0, side,
		str(f0.hash).left(10), str(f2.hash).left(10), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


## Collider triangles (section-local metres) the segment a -> b crosses.
static func _ray_cells(arr: Dictionary, a: Vector3, b: Vector3) -> int:
	var col: PackedVector3Array = arr.get("col", PackedVector3Array())
	var n := 0
	for i: int in range(0, col.size() - 2, 3):
		if Geometry3D.segment_intersects_triangle(a, b, col[i], col[i + 1], col[i + 2]) != null:
			n += 1
	return n


## Drawn triangles lying in the plane x = `x` (section-local metres).
static func _faces_x(arr: Dictionary, x: float) -> int:
	var v: PackedVector3Array = arr.get("v", PackedVector3Array())
	var n := 0
	for i: int in range(0, v.size() - 2, 3):
		if is_equal_approx(v[i].x, x) and is_equal_approx(v[i + 1].x, x) and is_equal_approx(v[i + 2].x, x):
			n += 1
	return n


# ------------------------------------------------------------------ looks
func looks() -> void:
	var bad := []
	var rules := {1: {"id": 1, "when": {"on": "enter", "zone": 1}, "do": [{"do": "start", "run": "R"}]},
		2: {"id": 2, "when": {"on": "enter", "zone": 2}, "do": [{"do": "checkpoint", "zone": 3}]},
		3: {"id": 3, "when": {"on": "enter", "zone": 4}, "do": [{"do": "finish"}]}}
	var role: Dictionary = PlayLooks.roles(rules)
	if str(role) != str({1: "start", 3: "checkpoint", 4: "finish"}):
		bad.append("roles %s" % str(role))
	var pad: Node3D = PlayLooks.look_of({"id": 1, "box": [[0, 0, 0], [2, 0, 2]], "look": "pad"}, "start")
	var flag: Node3D = PlayLooks.look_of({"id": 4, "box": [[5, 1, 5], [5, 2, 5]], "look": "flag"})
	var none: Variant = PlayLooks.look_of({"id": 5, "box": [[0, 0, 0], [0, 0, 0]], "look": "none"})
	var bodies := _bodies(flag)
	if pad == null or pad.position != Vector3(1.5, 0, 1.5) or flag == null or flag.position != Vector3(5.5, 1, 5.5) or none != null or bodies != 0:
		bad.append("pad %s, flag %s, none %s, bodies in the flag %d" % [str(pad.position) if pad else "null", str(flag.position) if flag else "null", str(none), bodies])
	var holder := Node3D.new()
	root.add_child(holder)
	var l: RefCounted = PlayLooks.new(holder)
	var zones := {}
	for i: int in 100:
		zones[i + 1] = {"id": i + 1, "box": [[i, 0, 0], [i, 0, 0]], "look": "coin"}
	var layer := _FakeLayer.new()
	layer.zones = zones
	l.call("sync", layer)
	var meshes := {}
	for z: int in (l.get("nodes") as Dictionary):
		meshes[((l.get("nodes")[z] as Node3D).get_child(0) as MeshInstance3D).mesh.get_instance_id()] = true
	l.call("taken", 7, true, 0)
	for f: int in range(1, 20):
		l.call("tick", f)
	var hid: bool = l.call("is_hidden", 7)
	var spin: float = (l.get("nodes")[8] as Node3D).rotation.y
	if int(l.call("count")) != 100 or meshes.size() != 1 or not hid or absf(spin - 19 * PlayLooks.SPIN) > 1e-4:
		bad.append("100 coins: %d nodes, %d meshes, taken hidden %s, spin %.3f" % [int(l.call("count")), meshes.size(), hid, spin])
	l.call("clear")
	holder.queue_free()
	pad.free()
	flag.free()
	var clk: String = PlayHud.clock(3725)
	if clk != "01:02.08":
		bad.append("clock(3725) = %s (want 01:02.08)" % clk)
	say("looks", bad.is_empty(), "roles start/checkpoint/finish, pad at the floor centre, flag with no body, none -> null; 100 coins: 100 nodes, %d shared mesh, a taken coin hidden after its fly-up; clock(3725 frames) %s%s" % [
		meshes.size(), clk, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


class _FakeLayer extends RefCounted:
	var zones := {}
	var rules := {}
	var revision := 1


static func _bodies(n: Node) -> int:
	if n == null:
		return 0
	var c := 1 if n is CollisionObject3D else 0
	for ch: Node in n.get_children():
		c += _bodies(ch)
	return c


# ------------------------------------------------------------------ build mode mid-run
var _build_text := ""


func build_mid_run(c: RefCounted) -> bool:
	var bad := []
	var p: RefCounted = c.get("p")
	var bm: Node = c.get("bm")
	var run: RefCounted = p.get("run")
	var v: Node3D = c.get("v")
	await c.call("walk_until", Vector3(0, 0, -Course.SPEED), func() -> bool: return v.feet.z < 3.6 and absf(float(v.get("vel").z)) < 0.01, 400)
	await c.call("frame", Vector3.ZERO, true)
	await c.call("frame", Vector3.ZERO)
	var was_open: bool = run.call("is_open", 3)
	var was_running: bool = run.get("running")
	bm.call("enter")
	await c.call("frame", Vector3.ZERO)
	var fac: RefCounted = p.get("facade")
	var calls := str(fac.get("calls"))
	var masks: Dictionary = (c.get("b") as RefCounted).call("layer", "blocks").get("masks")
	var slides: int = p.get("doors").call("moving")
	var hud: Node = p.get("hud")
	var looks_shown := false
	for z: int in (p.get("looks").get("nodes") as Dictionary):
		looks_shown = looks_shown or (p.get("looks").get("nodes")[z] as Node3D).visible
	var pill: bool = (hud.get("_pill") as Control).visible if hud != null else true
	if not was_open or not was_running or bool(p.get("running")) or str(p.get("why_off")) != "build" or not calls.contains("[\"run_stopped\", \"Tower\", \"build\"]") \
			or not masks.is_empty() or slides != 0 or looks_shown or pill:
		bad.append("open %s running %s; after B: rules running %s why %s, masks %d, slides %d, looks shown %s, pill %s, calls %s" % [
			was_open, was_running, p.get("running"), p.get("why_off"), masks.size(), slides, looks_shown, pill, calls.right(160)])
	bm.call("leave")
	await c.call("frame", Vector3.ZERO)
	await c.call("frame", Vector3.ZERO)
	var back: bool = p.get("running")
	if not back:
		bad.append("build mode off: the rules did not run again")
	_build_text = "a run with the door open, B: the run dropped (run_stopped build), the door shut at once (no mask, no slide), looks and the HUD hidden; B again: running %s%s" % [
		back, "" if bad.is_empty() else "; BAD " + "; ".join(bad)]
	return bad.is_empty()
