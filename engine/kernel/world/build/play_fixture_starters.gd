extends SceneTree
## Lane F3 (27 Nov 2026): writes a fixture Home holding the three starter courses (res://kernel/world/build/starters)
## placed on the valley's own grass as the stamp tool places them (the stamp's floor on the cell the ground is in at
## its anchor), for playing them in the exe (a window):
##   <godot> --headless --path engine --script res://kernel/world/build/play_fixture_starters.gd -- --out=<abs dir>
## then  TL_HOME_BUILD_DIR=<abs dir> TL_EXE_START=<printed> <godot> --path engine res://boot/boot.tscn
## In the landscape of boot/village.json (as play_fixture.gd builds it), at a patch east of (700, -60) where nothing
## refuses a cell: Pad hop along +x, Tower climb and Garden gate north of it. Prints one `FIXTURE ok dir=... ` line
## with each course's TL_EXE_START (a walk from the grass in front of it).

const Landscape := preload("res://kernel/world/landscape.gd")
const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const StampFile := preload("res://kernel/world/build/stamp_file.gd")
const Valley := preload("res://kernel/world/home/valley.gd")
const WALK_AT := Vector2i(700, -60)
const DIR := "res://kernel/world/build/starters"
## slug, offset of the stamp's corner from the site (x, z), the start walk: from, to (offsets of the corner)
const PLAN := [["pad-hop", Vector2i(0, 0), Vector2(-4.0, 3.5), Vector2(0.5, 3.5)],
	["tower-climb", Vector2i(0, 14), Vector2(-3.0, 2.0), Vector2(0.0, 2.0)],
	["garden-gate", Vector2i(20, 14), Vector2(6.5, -3.0), Vector2(6.5, 0.5)]]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var out := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	if out == "" or not out.is_absolute_path():
		print("FIXTURE fail: give -- --out=<abs dir>")
		quit(2)
		return
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
	var node := Node3D.new()
	root.add_child(node)
	TLStyle.set_headless(false)
	Landscape.build(node, xf, radii, own, cfg)
	Landscape.arrive(node)
	if not node.has_meta(&"tl_home"):
		print("FIXTURE fail: no Home in the landscape")
		quit(1)
		return
	var home: RefCounted = node.get_meta(&"tl_home")
	var valley: RefCounted = Valley.new(int(cfg.seed), node.get_meta(&"tl_terrain"))
	var stamps := {}
	for s: Dictionary in (StampFile.list(ProjectSettings.globalize_path(DIR)).stamps as Array):
		stamps[str(s.slug)] = s.stamp
	for k in 30:
		var site := Vector2i(WALK_AT.x + 12 * k, WALK_AT.y)
		var b: RefCounted = HomeBuild.attach(node, walk, valley, {})
		b.protect.visitor_at = func() -> Vector3: return Vector3(0, -500, 0)
		var why := ""
		var starts := []
		for pl: Array in PLAN:
			var st: Dictionary = stamps.get(pl[0], {})
			if st.is_empty():
				why = "no starter %s" % pl[0]
				break
			var size := Vector3i(int(st.size[0]), int(st.size[1]), int(st.size[2]))
			var corner := Vector2i(site.x + pl[1].x, site.y + pl[1].y)
			var mid := Vector2(corner.x + size.x / 2 + 0.5, corner.y + size.z / 2 + 0.5)
			for z in range(corner.y - 4, corner.y + size.z + 4):
				for x in range(corner.x - 4, corner.x + size.x + 4):
					home.call("ensure", Vector2(x, z))
			var gy := int(floorf(float(home.call("ground_y", mid.x, mid.y))))     # the stamp tool's anchor cell
			var po: Dictionary = StampFile.placed_ops(b, st, Vector3i(corner.x, gy, corner.y), 0)
			var r: Dictionary = b.apply(po.ops)
			if not bool(r.get("ok", false)):
				why = "%s: %s" % [pl[0], str(r.get("reason", r))]
				break
			var f: Vector2 = Vector2(corner) + (pl[2] as Vector2)
			var t2: Vector2 = Vector2(corner) + (pl[3] as Vector2)
			starts.append("%s=%.1f,%.1f,%.1f,%.1f" % [pl[0], f.x, f.y, t2.x, t2.y])
		if why == "":
			DirAccess.make_dir_recursive_absolute(out)
			var se: String = b.save(out)
			print("FIXTURE %s dir=%s site=%d,%d tries=%d %s %s" % ["ok" if se == "" else "fail", out, site.x, site.y, k + 1, " ".join(starts), se])
			b.free_all()
			quit(0 if se == "" else 1)
			return
		print("FIXTURE try %d at %d,%d refused: %s" % [k + 1, site.x, site.y, why])
		b.free_all()
	print("FIXTURE fail: no clear patch")
	quit(1)
