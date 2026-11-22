extends SceneTree
## N3 (night of 22-23 Nov 2026): what the owner saw in the World (Wren Valley), measured on the landscape that
## landscape.gd builds for res://boot/village.json (the Home on), headless, as home/walk_case.gd builds it.
## Prints `N3 <case> ok|fail <detail>` lines and `N3 DONE`; engine/tools/selftest.d/770-n3-world-look.sh reads them.
##   n3.sight   the visitor's camera sees the whole Home: its far plane reaches across the drawn valley's diagonal
##              (it was TLChaseCam's 2000 m: hills, peaks and woods were cut at 2 km and slid in and out as he moved).
##              Control: the chase camera's own far plane is shorter than that diagonal (the case would fail without the fix).
##   n3.tufts   the village's grass tufts are drawn by their own distance: every tuft multimesh (WorldTufts*) has a
##              visibility range, and no tuft stands farther than TUFT_REACH m from the node whose distance decides it
##              (it was one multimesh over the whole village: all 1385 appeared and went at once, 120 m from its middle,
##              so tufts beside the visitor were missing at both ends of the village).
##   n3.far_ground  the far picture of a pack keeps the pack's own ground where it is: a rolling 100 m ground sheet is
##              merged into the mid and the far picture (draw_pictures.gd `_append`, the draw layer's own settings) and
##              the far ground's height under 400 points is at most FAR_DY from the mid ground's (the 6 m grid moved
##              seed_drive's ground by up to 2.07 m under objects that kept their height).
const Landscape := preload("res://kernel/world/landscape.gd")
const Visitor := preload("res://kernel/world/visitor.gd")
const FAR_DY := 0.05          # metres between the far and the mid picture's ground under the same point
const TUFT_REACH := 23.0      # metres: half the diagonal of a 32 m cell (22.6), rounded up

var node: Node3D


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	print("N3 %s %s %s" % [case_name, "ok" if ok else "fail", detail])


func run() -> void:
	var walk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://boot/village.json"))
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
		say("sight", false, "no Home: landscape.gd did not grow it (TL_HOME=%s)" % OS.get_environment("TL_HOME"))
		print("N3 DONE")
		quit(1)
		return
	sight()
	tufts()
	far_ground()
	print("N3 DONE")
	quit(0)


func sight() -> void:
	var valley: Node = node.get_node_or_null("WrenValley")
	if not (valley is MeshInstance3D):
		say("sight", false, "no WrenValley mesh under the landscape")
		return
	var box: AABB = (valley as MeshInstance3D).global_transform * (valley as MeshInstance3D).get_aabb()
	var diagonal: float = Vector2(box.size.x, box.size.z).length()
	var v: Node3D = Visitor.new()
	node.add_child(v)
	v.call("setup", Vector3(-200.0, 0.0, 3.0), Vector3(-1.0, 0.0, 0.0))
	var cam: Camera3D = v.get("cam")
	var probe := TLChaseCam.new()
	probe.setup(null, {})
	var chase_far: float = probe.far
	probe.free()
	var ok: bool = cam != null and cam.far >= diagonal and chase_far < diagonal
	say("sight", ok, "camera far %.0f m >= the drawn valley's diagonal %.0f m (%.0f x %.0f m); the chase camera alone: %.0f m" % [
		cam.far if cam != null else -1.0, diagonal, box.size.x, box.size.z, chase_far])


func tufts() -> void:
	var nodes := 0
	var count := 0
	var worst := 0.0
	var no_range := 0
	for c: Node in node.get_children():
		if not (c is MultiMeshInstance3D and str(c.name).begins_with("WorldTufts")):
			continue
		nodes += 1
		var at: Vector3 = (c as Node3D).global_position
		if (c as GeometryInstance3D).visibility_range_end <= 0.0:
			no_range += 1
		for x: Transform3D in c.get_meta(&"tl_xs", []):
			count += 1
			worst = maxf(worst, Vector2(x.origin.x - at.x, x.origin.z - at.z).length())
	var ok: bool = nodes > 0 and count > 0 and no_range == 0 and worst <= TUFT_REACH
	say("tufts", ok, "%d tufts in %d multimeshes, %d without a range; the farthest tuft stands %.1f m from the node its distance is measured to (at most %.0f)" % [
		count, nodes, no_range, worst, TUFT_REACH])


## A rolling ground sheet merged as the draw layer merges a pack's terrain; the height of each picture under a point.
func far_ground() -> void:
	var draw: Node3D = (load("res://kernel/world/draw/draw.gd") as GDScript).new()
	var e := {"radius": 64.0, "rim": 0.0, "sheets": [], "ground": true}
	var accs: Array = draw.call("_new_accs", e, ["mid", "far"])
	var v := PackedVector3Array()
	var ix := PackedInt32Array()
	var n := 51
	for j: int in n:
		for i: int in n:
			var x := -50.0 + 2.0 * i
			var z := -50.0 + 2.0 * j
			v.append(Vector3(x, 2.0 * sin(x / 11.0) + 1.5 * cos(z / 13.0), z))
	for j: int in n - 1:
		for i: int in n - 1:
			var k := j * n + i
			ix.append_array(PackedInt32Array([k, k + n + 1, k + 1, k, k + n, k + n + 1]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_INDEX] = ix
	for acc: Variant in accs:
		draw.call("_append", acc, arr, Transform3D.IDENTITY, true, true)
	var worst := 0.0
	var at := Vector2.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = 770
	for s: int in 400:
		var p := Vector2(rng.randf_range(-44.0, 44.0), rng.randf_range(-44.0, 44.0))
		var hm: float = _height(accs[0], p)
		var hf: float = _height(accs[1], p)
		if is_nan(hm) or is_nan(hf):
			continue
		if absf(hf - hm) > worst:
			worst = absf(hf - hm)
			at = p
	draw.free()
	var tris: Array = [(accs[0].get("ix") as PackedInt32Array).size() / 3, (accs[1].get("ix") as PackedInt32Array).size() / 3]
	say("far_ground", worst <= FAR_DY, "the far picture's ground is at most %.2f m from the mid picture's under 400 points (worst at (%.1f, %.1f); allowed %.2f); triangles mid %d, far %d" % [
		worst, at.x, at.y, FAR_DY, tris[0], tris[1]])


func _height(acc: Object, p: Vector2) -> float:
	var vv: PackedVector3Array = acc.get("v")
	var ii: PackedInt32Array = acc.get("ix")
	var from := Vector3(p.x, 100.0, p.y)
	for t: int in range(0, ii.size(), 3):
		var a: Vector3 = vv[ii[t]]
		var b: Vector3 = vv[ii[t + 1]]
		var c: Vector3 = vv[ii[t + 2]]
		if p.x < minf(a.x, minf(b.x, c.x)) or p.x > maxf(a.x, maxf(b.x, c.x)) or p.y < minf(a.z, minf(b.z, c.z)) or p.y > maxf(a.z, maxf(b.z, c.z)):
			continue
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, a, b, c)
		if hit == null:
			hit = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, a, c, b)
		if hit != null:
			return (hit as Vector3).y
	return NAN
