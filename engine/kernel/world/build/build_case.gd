extends SceneTree
## WP1 (spark world-sandbox, M1): the Home's block core, headless, in the landscape of res://boot/village.json (the
## Home grown by home/hook.gd), as walk_case.gd builds it. Prints `HOME build.<case> ok|fail <detail>`, then
## `HOME build ok` (or `HOME build fail`) and `HOME DONE`; engine/tools/selftest.d/752-home-build.sh reads them.
##   build.forms   joins and hidden faces on small builds (cube runs, slab against cube, stair corners, fence links)
##   build.bulk    20,000 scripted placements (80 houses) across 4 chunks mesh and collide: section and chunk rebuild ms
##                 (median, max; wall clock is measured and printed, never decided on), triangles per chunk, rays onto
##                 the ridges hit the blocks' bodies; one edit inside a section rebuilds that section and its chunk,
##                 one on the chunk seam rebuilds both chunks; the same build with 96 m sections for comparison
##   build.same    the same op list in a second builder gives the same per-chunk mesh hash
##   build.undo    undo of every batch empties the store (no body left), redo gives the same store and mesh hash
##   build.files   save -> load -> save is byte-identical; edits after a save are journaled and replayed by a load
##   build.refuse  refused with a reason: a game plot, a Home site, an authored structure, a tree, the visitor,
##                 a full chunk and a full Home (lowered caps), malformed ops (unknown key, glass, flip, range)
##   build.walk    the visitor's body (world_space.gd `drive`, one call per frame) climbs a 3-block stair onto a platform
##                 and is stopped by a 3-high wall on it, both counted in frames
const Landscape := preload("res://kernel/world/landscape.gd")
const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const Shapes := preload("res://kernel/world/build/shapes.gd")
const EditLog := preload("res://kernel/world/build/edit_log.gd")
const Valley := preload("res://kernel/world/home/valley.gd")
const TMP := "user://tl_build_case"
const BULK := 20000
const AREA := Vector2i(672, -288)     # the corner of the 2 x 2 chunks (7..8, -3..-2) the houses stand in
const WALK_AT := Vector2i(700, -60)   # where the stair is built (moved east in 10 m steps until nothing refuses it)

var node: Node3D
var ws: Object
var home: RefCounted
var walk: Dictionary
var valley: RefCounted
var ok_all := true
var bulk_ops := []
var b1: RefCounted


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME build.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func run() -> void:
	walk = JSON.parse_string(FileAccess.get_file_as_string("res://boot/village.json"))
	var cfg: Dictionary = walk.landscape.duplicate(true)
	cfg.road = walk.road
	cfg.footprints = []
	var xf := []
	var radii := []
	var own := []
	for p: Dictionary in walk.plots:
		xf.append(Transform3D(Basis.IDENTITY, Vector3(p.origin[0], p.origin[1], p.origin[2])))
		radii.append(p.radius)
		own.append(false)
		cfg.footprints.append(Vector2(p.footprint.size_m[0], p.footprint.size_m[1]))
	node = Node3D.new()
	root.add_child(node)
	TLStyle.set_headless(false)
	Landscape.build(node, xf, radii, own, cfg)
	Landscape.arrive(node)
	if not node.has_meta(&"tl_home"):
		say("forms", false, "no Home: landscape.gd did not grow it (TL_HOME=%s)" % OS.get_environment("TL_HOME"))
		print("HOME build fail")
		print("HOME DONE")
		quit(1)
		return
	ws = node.get_meta(&"tl_space")
	home = node.get_meta(&"tl_home")
	valley = Valley.new(int(cfg.seed), node.get_meta(&"tl_terrain"))
	DirAccess.make_dir_recursive_absolute(TMP)
	forms()
	var site := walk_site()
	ws.call("place", site.feet)                     # the visitor stands at the stair, away from the houses
	ws.call("drive", site.feet, Vector3.ZERO, false, false)
	bulk()
	same()
	undo_redo()
	files()
	refuse(site.feet)
	climb(site)
	b1.free_all()
	_remove_dir(ProjectSettings.globalize_path(TMP))
	print("HOME build %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


func median(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var s := xs.duplicate()
	s.sort()
	return float(s[s.size() / 2])


# ------------------------------------------------------------------ forms
func forms() -> void:
	var bad := []
	var b: RefCounted = HomeBuild.new(node, null, {})
	var tris := func(cells: Array) -> int:
		b.blocks.clear()
		for c: Array in cells:
			b.blocks.put(c[0], c[1])
		b.flush()
		return int(b.stats().tris)
	var cube := Blocks.code(Blocks.CUBE, 1)
	var slab := Blocks.code(Blocks.SLAB, 1)
	var cube3 := []
	for y in 3:
		for z in 3:
			for x in 3:
				cube3.append([Vector3i(x, y, z), cube])
	var want := {"one cube": [[[Vector3i(0, 0, 0), cube]], 12], "two cubes": [[[Vector3i(0, 0, 0), cube], [Vector3i(1, 0, 0), cube]], 20],
		"3x3x3 cubes": [cube3, 108], "two slabs": [[[Vector3i(0, 0, 0), slab], [Vector3i(1, 0, 0), slab]], 20],
		"slab and cube": [[[Vector3i(0, 0, 0), slab], [Vector3i(1, 0, 0), cube]], 22]}
	var got := []
	for k: String in want:
		var n: int = tris.call(want[k][0])
		got.append("%s %d" % [k, n])
		if n != int(want[k][1]):
			bad.append("%s: %d triangles, want %d" % [k, n, want[k][1]])
	# forms read from a grid: a stair whose neighbour behind faces left is an outer-left corner, one in front an inner
	var form_of := func(cells: Array, at: Vector3i) -> int:
		var w := 7
		var grid := PackedInt32Array()
		grid.resize(w * w * 3)
		for c: Array in cells:
			var p: Vector3i = c[0] + Vector3i(3, 1, 3)
			grid[p.x + w * (p.z + w * p.y)] = c[1]
		var q := at + Vector3i(3, 1, 3)
		return (Shapes.key_at(grid, q.x + w * (q.z + w * q.y), PackedInt32Array([1, -1, w * w, -w * w, w, -w])) >> 8) & 15
	var stair0 := Blocks.code(Blocks.STAIR, 1, 0)
	var stair1 := Blocks.code(Blocks.STAIR, 1, 1)
	var fence := Blocks.code(Blocks.FENCE, 3)
	var cases := {"outer-left stair": [[[Vector3i(0, 0, 0), stair0], [Vector3i(0, 0, -1), stair1]], 1],
		"inner-left stair": [[[Vector3i(0, 0, 0), stair0], [Vector3i(0, 0, 1), stair1]], 3],
		"straight run": [[[Vector3i(0, 0, 0), stair0], [Vector3i(1, 0, 0), stair0], [Vector3i(0, 0, -1), stair1], [Vector3i(1, 0, -1), stair0]], 0],
		"fence between cubes": [[[Vector3i(0, 0, 0), fence], [Vector3i(1, 0, 0), cube], [Vector3i(-1, 0, 0), cube]], 3],
		"fence to fence and post": [[[Vector3i(0, 0, 0), fence], [Vector3i(0, 0, 1), fence], [Vector3i(0, 0, -1), Blocks.code(Blocks.POST, 4)]], 12],
		"fence by a slab": [[[Vector3i(0, 0, 0), fence], [Vector3i(1, 0, 0), slab]], 0]}
	for k: String in cases:
		var f: int = form_of.call(cases[k][0], Vector3i.ZERO)
		got.append("%s form %d" % [k, f])
		if f != int(cases[k][1]):
			bad.append("%s: form %d, want %d" % [k, f, cases[k][1]])
	# every shape in every rot and flip meshes alone to a closed set of faces (no shape draws nothing)
	var shapes_tris := []
	for s: int in range(1, 9):
		var n: int = tris.call([[Vector3i(0, 0, 0), Blocks.code(s, 1 if s != Blocks.WINDOW else 3, 1, s in [3, 4, 7])]])
		shapes_tris.append("%s %d" % [Blocks.SHAPE_NAMES[s], n])
		if n < 4:
			bad.append("%s draws %d triangles" % [Blocks.SHAPE_NAMES[s], n])
	b.free_all()
	say("forms", bad.is_empty(), "%s; alone (rot 1): %s%s" % ["; ".join(got), ", ".join(shapes_tris), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


# ------------------------------------------------------------------ bulk
## A house of about 250 blocks at (x0, base, z0): a stone floor, plank or white walls with windows and a door, a gable
## roof of 45-degree roof blocks with a ridge, cube gables, a fence with posts in front. One batch per house.
func house(x0: int, base: int, z0: int, k: int) -> Array:
	var ops := []
	var wall := Blocks.code(Blocks.CUBE, 3 if k % 2 == 0 else 9)
	var put := func(x: int, y: int, z: int, c: int) -> void: ops.append(EditLog.op_place(Vector3i(x0 + x, base + y, z0 + z), c))
	for z in 7:
		for x in 9:
			put.call(x, 0, z, Blocks.code(Blocks.CUBE, 1 + k % 2))
	for y in range(1, 4):
		for z in 7:
			for x in 9:
				if x != 0 and x != 8 and z != 0 and z != 6:
					continue
				if z == 0 and x == 4 and y < 3:
					continue                                    # the door
				if y == 2 and ((z == 0 or z == 6) and (x == 2 or x == 6)):
					put.call(x, y, z, Blocks.code(Blocks.WINDOW, 4, 0))
				elif y == 2 and (x == 0 or x == 8) and z == 3:
					put.call(x, y, z, Blocks.code(Blocks.WINDOW, 4, 1))
				else:
					put.call(x, y, z, wall)
	var roof_mat := 5 if k % 3 != 0 else 6
	for layer in 3:
		for x in range(-1, 10):
			put.call(x, 4 + layer, layer, Blocks.code(Blocks.ROOF, roof_mat, 2))
			put.call(x, 4 + layer, 6 - layer, Blocks.code(Blocks.ROOF, roof_mat, 0))
	for x in range(-1, 10):
		put.call(x, 7, 3, Blocks.code(Blocks.SLAB, roof_mat))
	for end: int in [0, 8]:
		for layer in 3:
			for z in range(1 + layer, 6 - layer):
				put.call(end, 4 + layer, z, wall)
	put.call(-1, 1, -2, Blocks.code(Blocks.POST, 4))
	for x in range(0, 9):
		if x != 4:
			put.call(x, 1, -2, Blocks.code(Blocks.FENCE, 4))
	put.call(9, 1, -2, Blocks.code(Blocks.POST, 4))
	return ops


func bulk() -> void:
	var top := -INF
	for z in range(AREA.y, AREA.y + 192, 4):
		for x in range(AREA.x, AREA.x + 192, 4):
			top = maxf(top, float(home.ground_y(x, z)))
	var base := int(ceilf(top)) + 6                    # over the valley's trunks: the houses stand on a plinth in the air
	var batches := []
	for j in 8:
		for i in 10:
			batches.append(house(AREA.x + 3 + i * 19, base, AREA.y + 4 + j * 24, i + j))
	var count := 0
	for bt: Array in batches:
		var take := mini(bt.size(), BULK - count)
		bulk_ops.append(bt.slice(0, take))
		count += take
		if count >= BULK:
			break
	b1 = HomeBuild.attach(node, walk, valley, {})
	b1.mesh.keep_times = true
	var t0 := Time.get_ticks_usec()
	var refused := []
	for bt: Array in bulk_ops:
		var r: Dictionary = b1.apply(bt)
		refused.append_array(r.refused)
	var apply_ms := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	var sections: int = b1.flush()
	var build_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var per := []
	var chunk_ms := {}
	var sec_us: Array = (b1.mesh.counters.section_usec as Array).duplicate()
	var sec_at: Array = (b1.mesh.counters.section_at as Array).duplicate()
	for i: int in sec_at.size():
		var ch: Vector2i = b1.blocks.chunk_of_section(sec_at[i])
		chunk_ms[ch] = float(chunk_ms.get(ch, 0.0)) + sec_us[i] / 1000.0
	var bad := []
	if b1.blocks.total != BULK or not refused.is_empty():
		bad.append("%d blocks placed of %d (%d refused: %s)" % [b1.blocks.total, BULK, refused.size(), str(refused.slice(0, 3))])
	for ch: Vector2i in Blocks.sorted_ids(b1.blocks.counts):
		var f: Dictionary = b1.mesh.chunk_figures(ch)
		per.append("(%d,%d) %d blocks %d tris %.0f ms" % [ch.x, ch.y, b1.blocks.counts[ch], f.tris, chunk_ms.get(ch, 0.0)])
	if b1.blocks.counts.size() != 4:
		bad.append("%d chunks hold blocks, want 4" % b1.blocks.counts.size())
	# a ray down onto the ridge of one house per chunk hits a body tagged "home blocks" at the ridge's top
	var hits := 0
	for idx: int in [0, 9, 70, 79]:
		var ridge := Vector3(AREA.x + 3 + (idx % 10) * 19 + 4.5, base + 7.5, AREA.y + 4 + (idx / 10) * 24 + 3.5)
		var p: Dictionary = b1.pick(ridge + Vector3.UP * 20.0, ridge - Vector3.UP * 20.0)
		if not p.is_empty() and bool(p.block) and absf(float(p.pos.y) - ridge.y) < 0.02:
			hits += 1
		else:
			bad.append("ray onto ridge %s: %s" % [str(ridge), str(p)])
	# one edit inside a section, one on the chunk seam (x = 768): which sections and chunks are rebuilt
	var before_s: int = b1.mesh.counters.sections
	var before_c: int = b1.mesh.counters.chunks
	(b1.mesh.counters.section_usec as Array).clear()
	(b1.mesh.counters.chunk_usec as Array).clear()
	b1.place(Vector3i(AREA.x + 8, base + 9, AREA.y + 8), Blocks.code(Blocks.CUBE, 7))
	var one_dirty: int = b1.blocks.dirty.size()
	b1.flush()
	var one := [b1.mesh.counters.sections - before_s, b1.mesh.counters.chunks - before_c]
	var one_us: Array = (b1.mesh.counters.section_usec as Array).duplicate()
	var body_us: Array = (b1.mesh.counters.chunk_usec as Array).duplicate()
	b1.place(Vector3i(767, base + 9, AREA.y + 8), Blocks.code(Blocks.CUBE, 7))
	b1.flush()
	var seam := [b1.mesh.counters.sections - before_s - one[0], b1.mesh.counters.chunks - before_c - one[1]]
	b1.undo()
	b1.undo()
	b1.flush()
	if one != [1, 1]:
		bad.append("an edit inside a section rebuilt %d sections and %d chunks (want 1, 1)" % one)
	if seam != [2, 2]:
		bad.append("an edit on the chunk seam rebuilt %d sections and %d chunks (want 2, 2)" % seam)
	# the same build drawn with 96 m sections (one mesh per chunk): what a single edit would cost then
	var b96: RefCounted = HomeBuild.new(node, null, {"section": 96})
	b96.mesh.keep_times = true
	for bt: Array in bulk_ops:
		b96.apply(bt)
	b96.flush()
	var c96: Array = (b96.mesh.counters.section_usec as Array).filter(func(u: int) -> bool: return u > 0)
	b96.free_all()
	say("bulk", bad.is_empty(), "%d ops in %d batches applied in %.0f ms (%.1f us/op with protection); first build %d sections in %.0f ms (per chunk: blocks, triangles, ms of its sections); section rebuild median %.2f ms max %.2f ms; %s; %d of 4 ridge rays hit; one edit: %d dirty, rebuilt %d section(s) %d chunk(s) (%.2f ms mesh, %.2f ms body); seam edit rebuilt %d sections %d chunks; with 96 m sections a chunk rebuild is median %.1f ms max %.1f ms%s" % [
		BULK, bulk_ops.size(), apply_ms, apply_ms * 1000.0 / BULK, sections, build_ms, median(sec_us) / 1000.0, sec_us.max() / 1000.0,
		"; ".join(per), hits, one_dirty, one[0], one[1], median(one_us) / 1000.0, median(body_us) / 1000.0, seam[0], seam[1],
		median(c96) / 1000.0, c96.max() / 1000.0 if not c96.is_empty() else 0.0, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func hashes(b: RefCounted) -> Dictionary:
	var out := {}
	for ch: Vector2i in Blocks.sorted_ids(b.blocks.counts):
		out["%d,%d" % [ch.x, ch.y]] = b.mesh.chunk_figures(ch).hash
	return out


# ------------------------------------------------------------------ determinism, undo, files
func same() -> void:
	var b2: RefCounted = HomeBuild.new(node, null, {})
	for bt: Array in bulk_ops:
		b2.apply(bt)
	b2.flush()
	var h1 := hashes(b1)
	var h2 := hashes(b2)
	b2.free_all()
	var first: String = str(h1.values()[0]).substr(0, 12) if not h1.is_empty() else "-"
	say("same", h1 == h2 and h1.size() == 4, "%d chunk hashes equal over two builds of the same %d ops (first %s): %s" % [h1.size(), BULK, first, str(h1 == h2)])


func undo_redo() -> void:
	var h0: String = b1.blocks.content_hash()
	var m0 := hashes(b1)
	var n := 0
	var undone := 0
	while true:
		var k: int = b1.undo()
		if k == 0:
			break
		n += 1
		undone += k
	b1.flush()
	var empty_total: int = b1.blocks.total
	var empty_bodies: int = b1.mesh.bodies.size()
	var empty_meshes: int = b1.mesh.meshes.size()
	var redone := 0
	var r := 0
	for i: int in n:                                       # the two undone edits of build.bulk are under these
		var k: int = b1.redo()
		if k == 0:
			break
		r += 1
		redone += k
	b1.flush()
	var ok: bool = empty_total == 0 and empty_bodies == 0 and empty_meshes == 0 and b1.blocks.content_hash() == h0 and hashes(b1) == m0 and n == r
	say("undo", ok, "%d batches (%d ops) undone: %d blocks, %d bodies, %d meshes left; %d batches (%d ops) redone: store hash %s, mesh hashes %s" % [
		n, undone, empty_total, empty_bodies, empty_meshes, r, redone, "equal" if b1.blocks.content_hash() == h0 else "DIFFER", "equal" if hashes(b1) == m0 else "DIFFER"])


func files() -> void:
	var a := TMP.path_join("a")
	var bdir := TMP.path_join("b")
	var bad := []
	var why: String = b1.save(a)
	if why != "":
		bad.append("save: " + why)
	var bytes_a := FileAccess.get_file_as_bytes(a.path_join("build.json"))
	var b3: RefCounted = HomeBuild.new(null, null, {"seed": b1.home_seed})
	var r: Dictionary = b3.load(a)
	if not r.ok:
		bad.append("load: " + str(r.reason))
	why = b3.save(bdir)
	var bytes_b := FileAccess.get_file_as_bytes(bdir.path_join("build.json"))
	var same_bytes := bytes_a == bytes_b and bytes_a.size() > 0
	if not same_bytes:
		bad.append("build.json differs after load and save (%d vs %d bytes)" % [bytes_a.size(), bytes_b.size()])
	b3.flush()
	if hashes(b3) != hashes(b1):
		bad.append("the loaded build meshes differently")
	# edits after the save go to the journal; a load replays them over the compacted file
	var cell := Vector3i(AREA.x + 20, 60, AREA.y + 20)
	b1.begin_batch()
	b1.place(cell, Blocks.code(Blocks.STAIR, 2, 1, true))
	b1.place(cell + Vector3i(1, 0, 0), Blocks.code(Blocks.CUBE, 8))
	b1.end_batch()
	b1.remove(cell + Vector3i(1, 0, 0))
	b1.undo()
	var lines := FileAccess.get_file_as_string(a.path_join("edits.jsonl")).strip_edges().split("\n")
	var b4: RefCounted = HomeBuild.new(null, null, {"seed": b1.home_seed})
	var r4: Dictionary = b4.load(a)
	if b4.blocks.content_hash() != b1.blocks.content_hash() or int(r4.replayed) != 4 or not (r4.bad as Array).is_empty():
		bad.append("journal: %d lines, %d replayed, bad %s, stores %s" % [lines.size(), r4.replayed, str(r4.bad), "equal" if b4.blocks.content_hash() == b1.blocks.content_hash() else "DIFFER"])
	var wrong: RefCounted = HomeBuild.new(null, null, {"seed": b1.home_seed + 1})
	var rw: Dictionary = wrong.load(a)
	if rw.ok or wrong.blocks.total != 0:
		bad.append("a build file of another seed was taken")
	b1.undo()                                           # back to the 20,000
	say("files", bad.is_empty(), "build.json %d bytes (rev %d), equal after load and save: %s; journal %d lines (first %s), %d replayed into the same store; another seed: %s%s" % [
		bytes_a.size(), b1.rev, str(same_bytes), lines.size(), lines[0], r4.replayed, str(rw.reason), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


# ------------------------------------------------------------------ refusals
func refuse(feet: Vector3) -> void:
	var got := []
	var bad := []
	var cube := Blocks.code(Blocks.CUBE, 1)
	var expect := func(what: String, why: String, want: String) -> void:
		got.append("%s: '%s'" % [what, why])
		if not why.begins_with(want):
			bad.append("%s: '%s', want '%s'" % [what, why, want])
	var plot: Array = walk.plots[0].origin
	expect.call("game plot %s" % walk.plots[0].id, b1.can_place(Vector3i(int(plot[0]), int(plot[1]) + 1, int(plot[2])), cube), "game lot")
	var site: Dictionary = valley.sites[0]
	expect.call("Home site %s" % site.id, b1.can_place(Vector3i(int(site.centre[0]), 40, int(site.centre[1])), cube), "game lot")
	var solid := authored()
	expect.call("authored %s at %s" % [solid[1], str(solid[0])], b1.can_place(solid[0], cube) if solid[0] != HomeBuild.NO_CELL else "none found", "authored structure")
	var tree := trunk()
	expect.call("trunk at %s" % str(tree), b1.can_place(tree, cube) if tree != HomeBuild.NO_CELL else "none found", "tree")
	var at := feet + Vector3(0.0, -0.6, 0.0)            # where his owner says he is (visit.gd sets `visitor_at`)
	b1.protect.visitor_at = func() -> Vector3: return at
	expect.call("the visitor at %s" % str(at.snapped(Vector3.ONE * 0.01)), b1.can_place(Vector3i((at + Vector3.UP).floor()), cube), "too close")
	var small: RefCounted = HomeBuild.new(null, null, {"cap_chunk": 10, "cap_home": 15})
	for i in 10:
		small.place(Vector3i(i, 0, 0), cube)
	expect.call("11th block in a chunk of cap 10", str(small.place(Vector3i(10, 0, 0), cube).reason), "chunk full")
	for i in 5:
		small.place(Vector3i(200 + i, 0, 0), cube)
	expect.call("16th block in a Home of cap 15", str(small.place(Vector3i(300, 0, 0), cube).reason), "home full")
	var undo_before: int = b1.edits.history.size()
	var malformed := {"unknown key": {"v": 1, "op": "place", "at": [0, 60, 0], "shape": 1, "mat": 1, "rot": 0, "colour": "red"},
		"glass cube": {"op": "place", "at": [0, 60, 0], "shape": 1, "mat": 10, "rot": 0},
		"flip false": {"op": "place", "at": [0, 60, 0], "shape": 3, "mat": 1, "rot": 0, "flip": false},
		"flipped cube": {"op": "place", "at": [0, 60, 0], "shape": 1, "mat": 1, "rot": 0, "flip": true},
		"no mat": {"op": "place", "at": [0, 60, 0], "shape": 1, "rot": 0},
		"y 112": {"op": "place", "at": [0, 112, 0], "shape": 1, "mat": 1, "rot": 0},
		"remove of nothing": {"op": "remove", "at": [0, 60, 0]}}
	var wants := {"unknown key": "unknown key 'colour'", "glass cube": "glass is only", "flip false": "flip is written only when true",
		"flipped cube": "flip is for", "no mat": "mat is missing", "y 112": "out of range", "remove of nothing": "empty"}
	for k: String in malformed:
		expect.call(k, str(b1.apply(malformed[k]).reason), wants[k])
	if b1.edits.history.size() != undo_before:
		bad.append("a refused op reached the log")
	say("refuse", bad.is_empty(), "; ".join(got) + ("" if bad.is_empty() else "; BAD " + "; ".join(bad)))


## The centre cell of the first box, sphere or cylinder static in the visitor's space that is authored (not ground,
## not a pad, not a block) and stands outside every lot, as [cell, tag].
func authored() -> Array:
	var tags: Dictionary = ws.get("_tags")
	var order := ["home solid", "bridge", "rock", "wall", "landmark", "sign", "bush", "tree"]
	for want: String in order:
		for b: RID in ws.get("_bodies"):
			if str(tags.get(b, "")) != want or PhysicsServer3D.body_get_shape_count(b) == 0:
				continue
			var t := PhysicsServer3D.shape_get_type(PhysicsServer3D.body_get_shape(b, 0))
			if not t in [PhysicsServer3D.SHAPE_BOX, PhysicsServer3D.SHAPE_SPHERE, PhysicsServer3D.SHAPE_CYLINDER]:
				continue
			var xf: Transform3D = PhysicsServer3D.body_get_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM)
			var c := Vector3i((xf * PhysicsServer3D.body_get_shape_transform(b, 0)).origin.floor())
			if b1.protect.call("refusal", c).begins_with("authored"):
				return [c, want]
	return [HomeBuild.NO_CELL, ""]


## A cell inside a valley trunk whose ground chunk is made (home/hook.gd hangs trunks on the chunk bodies).
func trunk() -> Vector3i:
	var ids: Array = home.trees.keys()
	ids.sort()
	for id: Vector2i in ids:
		for t: Array in home.trees[id]:
			var foot: Vector3 = t[0]
			home.ensure(Vector2(foot.x, foot.z))
			var c := Vector3i((foot + Vector3(0.0, 1.5, 0.0)).floor())
			if home.bodies.has(id) and float(t[1]) >= 0.3 and Blocks.in_range(c) and b1.protect.call("refusal", c) == "tree":
				return c
	return HomeBuild.NO_CELL


# ------------------------------------------------------------------ the walk
## A clear patch near WALK_AT (nothing refuses its cells, the ground varies less than 0.8 m over it): the stair's
## origin cell and the visitor's start on the first platform.
func walk_site() -> Dictionary:
	var probe: RefCounted = HomeBuild.attach(node, walk, valley, {})
	for k in 20:
		var sx := WALK_AT.x + 10 * k
		var sz := WALK_AT.y
		home.ensure(Vector2(sx, sz))
		var lo := INF
		var hi := -INF
		for z in range(sz - 13, sz + 1):
			for x in range(sx - 2, sx + 3):
				var g: float = home.ground_y(x + 0.5, z + 0.5)
				lo = minf(lo, g)
				hi = maxf(hi, g)
		var gy := int(floorf(hi))
		var clear := hi - lo < 0.8
		for c: Vector3i in stair_cells(sx, gy, sz).keys():
			clear = clear and probe.protect.call("refusal", c) == ""
		if clear:
			probe.free_all()
			return {"x": sx, "y": gy, "z": sz, "feet": Vector3(sx + 0.5, gy + 1.0, sz + 0.5), "tries": k + 1, "ground": [lo, hi]}
	probe.free_all()
	return {"x": WALK_AT.x, "y": 0, "z": WALK_AT.y, "feet": Vector3(WALK_AT.x, 50, WALK_AT.y), "tries": 20, "ground": [0, 0]}


## The stair build, cell -> code: a 3 x 3 platform on the ground, three stairs 3 wide rising toward -z on supports,
## a 3 x 4 platform at the third stair's top, a wall 3 high and 5 wide at its far end.
func stair_cells(sx: int, gy: int, sz: int) -> Dictionary:
	var out := {}
	var cube := Blocks.code(Blocks.CUBE, 7)
	for x in range(sx - 1, sx + 2):
		for z in range(sz - 2, sz + 1):
			out[Vector3i(x, gy, z)] = cube
		for s in 3:
			for y in range(gy, gy + 1 + s):
				out[Vector3i(x, y, sz - 3 - s)] = cube
			out[Vector3i(x, gy + 1 + s, sz - 3 - s)] = Blocks.code(Blocks.STAIR, 1, 0)
		for z in range(sz - 9, sz - 5):
			for y in range(gy, gy + 4):
				out[Vector3i(x, y, z)] = cube
	for x in range(sx - 2, sx + 3):
		for y in range(gy + 4, gy + 7):
			out[Vector3i(x, y, sz - 10)] = Blocks.code(Blocks.CUBE, 2)
	return out


func climb(site: Dictionary) -> void:
	var cells := stair_cells(site.x, site.y, site.z)
	ws.call("place", site.feet + Vector3(0.0, 0.0, 30.0))     # out of the way while it is built
	b1.protect.visitor_at = Callable()
	var keys: Array = cells.keys()
	keys.sort()
	var ops := []
	for c: Vector3i in keys:
		ops.append(EditLog.op_place(c, cells[c]))
	var r: Dictionary = b1.apply(ops)
	b1.flush()
	var runs := []
	var ok: bool = r.ok
	for how: Array in [["walk", 4.5], ["drive", 4.5], ["drive", 9.0]]:
		var w: Dictionary = walker(site, how[0], how[1])
		runs.append("%s %.1f m/s: %s" % [how[0], how[1], w.text])
		ok = ok and bool(w.ok)
	say("walk", ok, "site (%d, %d, %d) after %d tries (ground %.2f..%.2f m), %d blocks; %s%s" % [
		site.x, site.y, site.z, site.tries, site.ground[0], site.ground[1], cells.size(), "; ".join(runs),
		"" if r.ok else "; REFUSED " + str(r.refused.slice(0, 3))])


## One walker from the first platform toward -z, one move per frame: `walk` (world_space.gd's kinematic step) or
## `drive` (the body with weight a person's keys move, world_body.gd).
func walker(site: Dictionary, how: String, speed: float) -> Dictionary:
	var top: float = site.y + 4.0
	var wall_face: float = site.z - 9.0                             # the wall's +z face
	var pos: Vector3 = site.feet
	ws.call("place", pos)
	ws.call("rest")
	var on_top := -1
	var stopped := -1
	var min_z := pos.z
	var still := 0
	var high := pos.y
	for f: int in 600:
		var d: Dictionary
		if how == "walk":
			d = ws.call("walk", pos, Vector3(0.0, 0.0, -speed / 60.0))
		else:
			d = ws.call("drive", pos, Vector3(0.0, 0.0, -speed), false, false)
		var moved: float = absf(float(d.pos.z) - pos.z)
		if OS.get_environment("TL_BUILD_TRACE") == "1" and f % 10 == 0:
			print("[trace] %s f%d %s %s g=%s blocked=%s hit=%s" % [how, f, str(d.pos), d.get("mode", ""), d.get("grounded", ""), d.get("blocked", ""), str(ws.get("last_hit"))])
		pos = d.pos
		min_z = minf(min_z, pos.z)
		high = maxf(high, pos.y)
		if on_top < 0 and pos.y > top - 0.05 and pos.z < site.z - 5.0:
			on_top = f
		if stopped < 0:
			still = still + 1 if moved < 0.001 else 0
			if still >= 10:
				stopped = f - 9
		if stopped >= 0 and f > stopped + 60:
			break
	var gap: float = min_z - wall_face
	var ok: bool = on_top >= 0 and stopped >= 0 and gap > 0.2 and gap < 0.5 and high < top + 0.2
	return {"ok": ok, "text": "on the platform (feet %.2f) at frame %d, stopped at frame %d %.3f m from the 3-high wall (capsule radius 0.35; furthest z %.2f), highest feet %.2f" % [
		top, on_top, stopped, gap, min_z, high]}


func _remove_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f: String in d.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in d.get_directories():
		_remove_dir(path.path_join(sub))
	DirAccess.remove_absolute(path)
