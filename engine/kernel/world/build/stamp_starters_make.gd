extends SceneTree
## M6 round 3, lane T (27 Nov 2026): writes the three starter courses shipped with the game,
## res://kernel/world/build/starters/*.json (tl.stamp/2), from their recipes below: the blocks as boxes of one shape
## and material (the crisp cel materials 1-9, never locked), the zones and rules by the Rules tool's own presets
## (rules_tool_presets.gd, so a starter reads in the side card as a hand-made course does), then the stamp of the box
## (stamp_file.gd `from_region`). Run by hand when a recipe changes:
##   godot --headless --path engine --script res://kernel/world/build/stamp_starters_make.gd
## It prints one line per course and writes nothing else. 789 (stamp_starters_case.gd) holds the files to the rules.

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const StampFile := preload("res://kernel/world/build/stamp_file.gd")
const Presets := preload("res://kernel/world/build/rules_tool_presets.gd")
const B := preload("res://kernel/world/build/blocks.gd")
const OUT := "res://kernel/world/build/starters"


func _initialize() -> void:
	var dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	for c: Dictionary in courses():
		var b: RefCounted = HomeBuild.new(null, null, {})
		var ops := []
		for f: Array in c.blocks:
			for y in range(f[1], f[4] + 1):
				for z in range(f[2], f[5] + 1):
					for x in range(f[0], f[3] + 1):
						ops.append({"op": "place", "at": [x, y, z], "shape": f[6], "mat": f[7], "rot": 0})
		var r: Dictionary = b.apply(ops)
		var rl: RefCounted = b.layer("rules")
		var bad := [] if bool(r.ok) else [str(r.reason)]
		for z: Array in c.zones:
			var zr: Dictionary = b.apply(Presets.ops(rl, z[0], z[1], z[2], z[3] if z.size() > 3 else {}))
			if not bool(zr.ok):
				bad.append("%s: %s" % [z[0], str(zr.reason)])
		var st: Dictionary = StampFile.from_region(b, c.lo, c.hi, c.name)
		var path := dir.path_join(StampFile.slug_of(c.name) + ".json")
		var text: String = StampFile.text_of(st.stamp)
		var fa := FileAccess.open(path, FileAccess.WRITE)
		fa.store_string(text)
		fa.close()
		print("STARTER %s: %s, %d blocks, %d zones, %d rules, %d bytes%s" % [c.name, str(st.stamp.size), (st.stamp.get("blocks", []) as Array).size(),
			(st.stamp.get("zones", []) as Array).size(), (st.stamp.get("rules", []) as Array).size(), text.length(), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])
	quit(0)


## Each course: name, box lo..hi, blocks [x0, y0, z0, x1, y1, z1, shape, mat] and zones [kind, lo, hi, opt?].
static func courses() -> Array:
	return [
		{"name": "Tower climb", "lo": Vector3i(0, 0, 0), "hi": Vector3i(8, 6, 8),
		 "blocks": [[0, 0, 0, 8, 0, 8, B.CUBE, 2], [3, 1, 3, 5, 4, 5, B.CUBE, 1],
			[7, 1, 1, 7, 1, 1, B.CUBE, 3], [7, 1, 3, 7, 2, 3, B.CUBE, 3], [7, 1, 5, 7, 3, 5, B.CUBE, 3], [5, 1, 7, 5, 4, 7, B.CUBE, 3]],
		 "zones": [["start", Vector3i(0, 1, 0), Vector3i(1, 1, 1), {"run": "Tower climb"}],
			["coin", Vector3i(7, 2, 1), Vector3i(7, 2, 1)], ["coin", Vector3i(7, 3, 3), Vector3i(7, 3, 3)], ["coin", Vector3i(7, 4, 5), Vector3i(7, 4, 5)],
			["finish", Vector3i(4, 5, 4), Vector3i(4, 5, 4)]]},
		{"name": "Garden gate", "lo": Vector3i(0, 0, -4), "hi": Vector3i(10, 3, 10),
		 "blocks": [[0, 0, -4, 10, 0, 10, B.CUBE, 1],
			[0, 1, 0, 4, 1, 0, B.FENCE, 3], [6, 1, 0, 10, 1, 0, B.FENCE, 3], [0, 1, 10, 10, 1, 10, B.FENCE, 3],
			[0, 1, 1, 0, 1, 9, B.FENCE, 3], [10, 1, 1, 10, 1, 9, B.FENCE, 3],
			[5, 1, 0, 5, 2, 0, B.CUBE, 4], [4, 2, 0, 4, 2, 0, B.POST, 4], [6, 2, 0, 6, 2, 0, B.POST, 4],
			[2, 1, 3, 3, 1, 7, B.SLAB, 8], [7, 1, 3, 8, 1, 7, B.SLAB, 8]],
		 "zones": [["start", Vector3i(4, 1, -3), Vector3i(6, 1, -2), {"run": "Garden gate"}],
			["door", Vector3i(5, 1, 0), Vector3i(5, 2, 0), {"thin": 2}],
			["message", Vector3i(4, 1, 2), Vector3i(6, 1, 2), {"text": "Three coins hide in the beds"}],
			["coin", Vector3i(2, 1, 5), Vector3i(2, 1, 5)], ["coin", Vector3i(8, 1, 4), Vector3i(8, 1, 4)], ["coin", Vector3i(3, 1, 7), Vector3i(3, 1, 7)],
			["finish", Vector3i(5, 1, 9), Vector3i(5, 1, 9)]]},
		{"name": "Pad hop", "lo": Vector3i(0, 0, 0), "hi": Vector3i(24, 4, 4),
		 "blocks": [[0, 0, 0, 24, 0, 4, B.CUBE, 5],
			[0, 1, 0, 3, 2, 4, B.CUBE, 7], [8, 1, 0, 10, 2, 4, B.CUBE, 7], [15, 1, 0, 17, 2, 4, B.CUBE, 7], [22, 1, 0, 24, 2, 4, B.CUBE, 7]],
		 "zones": [["start", Vector3i(0, 3, 1), Vector3i(1, 3, 3), {"run": "Pad hop"}],
			["pad", Vector3i(3, 3, 2), Vector3i(3, 3, 2), {"fwd_cm": 300}],
			["hazard", Vector3i(4, 1, 0), Vector3i(7, 1, 4)],
			["checkpoint", Vector3i(9, 3, 1), Vector3i(9, 3, 3)],
			["pad", Vector3i(10, 3, 2), Vector3i(10, 3, 2), {"fwd_cm": 300}],
			["hazard", Vector3i(11, 1, 0), Vector3i(14, 1, 4)],
			["checkpoint", Vector3i(16, 3, 1), Vector3i(16, 3, 3)],
			["pad", Vector3i(17, 3, 2), Vector3i(17, 3, 2), {"fwd_cm": 300}],
			["hazard", Vector3i(18, 1, 0), Vector3i(21, 1, 4)],
			["finish", Vector3i(23, 3, 2), Vector3i(23, 3, 2)]]}]
