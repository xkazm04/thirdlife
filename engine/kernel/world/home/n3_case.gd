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
const Landscape := preload("res://kernel/world/landscape.gd")
const Visitor := preload("res://kernel/world/visitor.gd")
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
