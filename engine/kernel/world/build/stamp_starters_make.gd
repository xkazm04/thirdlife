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
## Lane F3 (27 Nov, the playtest: Pad hop threw a walker 4.0 m into its hazard for ever; Tower climb's 1 m hops are
## out of a walking jump's reach, 0.87 m; a stamp sat a 0.7 m curb proud of the grass and Pad hop's start was a 2.7 m
## wall): every course stands on a ring of slabs one cell outside its floor (the stamp's floor goes on the cell the
## ground is in, so ground -> slab -> floor is two rises of at most 0.5 m, under the walker's 0.55 m step), Pad hop has
## half-block stairs onto its start, a pad across the whole platform, checkpoints the width of the landing and a
## finish on the whole last platform with a wall behind it; its pads throw 6.5 m/s forward (the walker keeps it in the
## air), so a walking launch lands about 5.4 m on, a held run about 7 m (onto the next pad) and a launch with no key
## held about the walking one. Tower climb is an L of 2 x 2 steps 0.5 m apart over 1-cell gaps, up to a 3 m tower.
## Figures: play_case_starters.gd (selftest 799), the real walker at a walk.
const PAD_FWD := 650
const PAD_UP := 1000


static func _apron(lo: Vector3i, hi: Vector3i, m: int) -> Array:
	return [[lo.x - 1, 0, lo.z - 1, hi.x + 1, 0, lo.z - 1, B.SLAB, m], [lo.x - 1, 0, hi.z + 1, hi.x + 1, 0, hi.z + 1, B.SLAB, m],
		[lo.x - 1, 0, lo.z, lo.x - 1, 0, hi.z, B.SLAB, m], [hi.x + 1, 0, lo.z, hi.x + 1, 0, hi.z, B.SLAB, m]]


static func courses() -> Array:
	var pad := {"fwd_cm": PAD_FWD, "up_cm": PAD_UP}
	return [
		{"name": "Tower climb", "lo": Vector3i(-1, 0, -1), "hi": Vector3i(12, 6, 12),
		 "blocks": [[0, 0, 0, 11, 0, 11, B.CUBE, 2]] + _apron(Vector3i(0, 0, 0), Vector3i(11, 0, 11), 2) + [
			[3, 1, 0, 4, 1, 1, B.SLAB, 3],                                  # step 1, +0.5 m (walked up)
			[6, 1, 0, 7, 1, 1, B.CUBE, 3],                                  # step 2, +1.0 (a hop over a gap)
			[9, 1, 0, 10, 1, 1, B.CUBE, 3], [9, 2, 0, 10, 2, 1, B.SLAB, 3],  # step 3, the corner, +1.5
			[9, 1, 3, 10, 2, 4, B.CUBE, 3],                                 # step 4, +2.0
			[9, 1, 6, 10, 2, 7, B.CUBE, 3], [9, 3, 6, 10, 3, 7, B.SLAB, 3],  # step 5, +2.5
			[8, 1, 9, 11, 3, 11, B.CUBE, 1]],                               # the tower, +3.0
		 "zones": [["start", Vector3i(0, 1, 0), Vector3i(1, 1, 1), {"run": "Tower climb"}],
			["coin", Vector3i(6, 2, 0), Vector3i(7, 2, 1)], ["coin", Vector3i(9, 3, 3), Vector3i(10, 3, 4)], ["coin", Vector3i(9, 3, 6), Vector3i(10, 3, 7)],
			["finish", Vector3i(8, 4, 9), Vector3i(11, 4, 11)]]},
		{"name": "Garden gate", "lo": Vector3i(-1, 0, -5), "hi": Vector3i(11, 3, 11),
		 "blocks": [[0, 0, -4, 10, 0, 10, B.CUBE, 1]] + _apron(Vector3i(0, 0, -4), Vector3i(10, 0, 10), 1) + [
			[0, 1, 0, 4, 1, 0, B.FENCE, 3], [6, 1, 0, 10, 1, 0, B.FENCE, 3], [0, 1, 10, 10, 1, 10, B.FENCE, 3],
			[0, 1, 1, 0, 1, 9, B.FENCE, 3], [10, 1, 1, 10, 1, 9, B.FENCE, 3],
			[5, 1, 0, 5, 2, 0, B.CUBE, 4], [4, 2, 0, 4, 2, 0, B.POST, 4], [6, 2, 0, 6, 2, 0, B.POST, 4],
			[2, 1, 3, 3, 1, 7, B.SLAB, 8], [7, 1, 3, 8, 1, 7, B.SLAB, 8]],
		 "zones": [["start", Vector3i(4, 1, -3), Vector3i(6, 1, -2), {"run": "Garden gate"}],
			["door", Vector3i(5, 1, 0), Vector3i(5, 2, 0), {"thin": 2}],
			["message", Vector3i(4, 1, 2), Vector3i(6, 1, 2), {"text": "Three coins hide in the beds"}],
			["coin", Vector3i(2, 1, 5), Vector3i(2, 1, 5)], ["coin", Vector3i(8, 1, 4), Vector3i(8, 1, 4)], ["coin", Vector3i(3, 1, 7), Vector3i(3, 1, 7)],
			["finish", Vector3i(5, 1, 9), Vector3i(5, 1, 9)]]},
		{"name": "Pad hop", "lo": Vector3i(-5, 0, -1), "hi": Vector3i(26, 4, 5),
		 "blocks": [[-4, 0, 0, 25, 0, 4, B.CUBE, 5]] + _apron(Vector3i(-4, 0, 0), Vector3i(25, 0, 4), 5) + [
			[-3, 1, 0, -3, 1, 4, B.SLAB, 7], [-2, 1, 0, -2, 1, 4, B.CUBE, 7], [-1, 1, 0, -1, 1, 4, B.CUBE, 7], [-1, 2, 0, -1, 2, 4, B.SLAB, 7],
			[0, 1, 0, 3, 2, 4, B.CUBE, 7], [8, 1, 0, 10, 2, 4, B.CUBE, 7], [15, 1, 0, 17, 2, 4, B.CUBE, 7], [22, 1, 0, 24, 2, 4, B.CUBE, 7],
			[25, 1, 0, 25, 4, 4, B.CUBE, 7]],
		 "zones": [["start", Vector3i(0, 3, 1), Vector3i(1, 3, 3), {"run": "Pad hop"}],
			["pad", Vector3i(3, 3, 0), Vector3i(3, 3, 4), pad],
			["hazard", Vector3i(4, 1, 0), Vector3i(7, 1, 4)],
			["checkpoint", Vector3i(8, 3, 0), Vector3i(9, 3, 4)],
			["pad", Vector3i(10, 3, 0), Vector3i(10, 3, 4), pad],
			["hazard", Vector3i(11, 1, 0), Vector3i(14, 1, 4)],
			["checkpoint", Vector3i(15, 3, 0), Vector3i(16, 3, 4)],
			["pad", Vector3i(17, 3, 0), Vector3i(17, 3, 4), pad],
			["hazard", Vector3i(18, 1, 0), Vector3i(21, 1, 4)],
			["finish", Vector3i(22, 3, 0), Vector3i(24, 3, 4)]]}]
