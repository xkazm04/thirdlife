extends RefCounted
## M6 lane C (27 Nov 2026): the space check of an LLM answer before accept (contracts/BUILD.md "The LLM command bar, M6
## additions"; COMMAND.md "M6"). Research behind it (docs/research/sandbox/THESIS.md): a model fails at space, not at
## syntax, so the exe measures what an answer would build and shows it with the ghost; it never refuses. Over a dry run
## (home_build.gd `preview`: the scratch copies of the layers after the answer) it finds
##   blocks that rest on nothing  an added block joined (face to face, through added blocks) to no block that was there
##                                and to no ground (a block at or below the ground cell of its column stands on it)
##   a pad or a flag with no floor the zone's floor-centre cell is not a feet cell (below)
##   a coin inside a solid block  the zone's centre is inside a cube or a window, or the lower half of a slab, stair,
##                                ramp or roof
##   a finish out of reach        for each run an added rule starts: none of the finish zones' feet cells is reached
##                                from a feet cell of the start zone over the standable cells: walking (steps of at most
##                                STEP m up or down), jumps of at most JUMP_UP m up and JUMP_ACROSS m across (cell centre
##                                to cell centre, nothing solid in the way), any drop within JUMP_ACROSS, a launch zone's
##                                longer jump and a teleport. The blocks of a zone some rule opens are passable (the
##                                estimate is kind to doors). Coins of the run's answer out of reach are counted too.
## A feet cell is where the visitor's feet cell (rules_run.gd `feet_cell`) is while he stands: an empty cell over a cube
## or a window (feet at its bottom), a slab, stair, ramp or roof cell (feet half way up), or the ground's cell of an
## empty column (feet on the ground), with headroom for 1.8 m. Static; reads the scratch copies, never the Home.
##   var s := CommandSpace.check(build, land, r)   # r = build.preview(ops); s.line: "2 blocks float; finish not reachable"

const Blocks := preload("res://kernel/world/build/blocks.gd")
const Check := preload("res://kernel/world/build/rules_check.gd")
const Ask := preload("res://kernel/world/build/command_ask.gd")
const STEP := 0.55                      # m: a walker's step up or down (stairs, slabs: half a block)
const JUMP_UP := 1.2                    # m up a jump climbs
const JUMP_ACROSS := 4.0                # m across, cell centre to cell centre (3 empty cells)
const HEAD := 1.8                       # m of headroom a standing person needs
const GRAVITY := 24.0                   # m/s2 (kernel/world/terrain/world_body.gd GRAVITY): a launch zone's jump
const LAUNCH_MAX := 16.0                # m across a launch is searched at most
const PAD := 6                          # cells round the answer's blocks and zones the walk is searched in
const MARKS_MAX := 64                   # problem cells marked in the ghost at most
const SIDE_MAX := 96                    # cells a side of the searched box at most (larger is clipped, and said)
const PARTIAL := [Blocks.SLAB, Blocks.STAIR, Blocks.RAMP, Blocks.ROOF]
const FULL_TOP := [Blocks.CUBE, Blocks.WINDOW]


## The check of dry run `r` (home_build.gd `preview`) of `build` (home_build.gd) on the ground of `land` (the
## landscape node; null: the land layer's or 0). Returns {"floating": [Vector3i], "no_floor": [zone id], "coin_in_block":
## [zone id], "runs": [{"run", "start", "finish": [zone id], "reachable", "path": [Vector3i feet cells], "coins",
## "coins_reached"}], "marks": [Vector3i], "line": String ("" when nothing was found), "nodes": feet cells searched,
## "clipped": bool, "grid": the Grid searched (null when nothing was)}. `all`: every zone and rule of `r`'s scratch is
## checked as if new (a kept course read back: `r` = {"scratch": {"blocks": the live layer, "rules": the live layer}}).
static func check(build: RefCounted, land: Node, r: Dictionary, all := false) -> Dictionary:
	var out := {"floating": [], "no_floor": [], "coin_in_block": [], "runs": [], "marks": [], "line": "", "nodes": 0, "clipped": false, "grid": null,
		"findings": []}
	var sc: Dictionary = r.get("scratch", {})
	var bl: RefCounted = sc.get("blocks")
	if bl == null:
		return out
	var after: RefCounted = bl.get("store")
	var added := _cells(r.get("store"))
	var live: RefCounted = build.layer("rules")
	var rl: RefCounted = sc.get("rules")
	var new_zones := []
	var new_rules := []
	if rl != null:
		for n: int in (rl.get("zones") as Dictionary).keys():
			if all or live == null or str((live.get("zones") as Dictionary).get(n)) != str(rl.get("zones")[n]):
				new_zones.append(rl.get("zones")[n])
		for n: int in (rl.get("rules") as Dictionary).keys():
			if all or live == null or str((live.get("rules") as Dictionary).get(n)) != str(rl.get("rules")[n]):
				new_rules.append(rl.get("rules")[n])
	if added.is_empty() and new_zones.is_empty():
		return out
	# the box searched: the added cells and the new zones, PAD round them in x and z, 3 below and 4 above
	var lo := Vector3i(1 << 30, 1 << 30, 1 << 30)
	var hi := -lo
	for c: Vector3i in added:
		lo = lo.min(c)
		hi = hi.max(c)
	for z: Dictionary in new_zones:
		lo = lo.min(Vector3i(z.box[0][0], z.box[0][1], z.box[0][2]))
		hi = hi.max(Vector3i(z.box[1][0], z.box[1][1], z.box[1][2]))
	lo = Vector3i(lo.x - PAD, maxi(Blocks.Y_MIN, lo.y - 3), lo.z - PAD)
	hi = Vector3i(hi.x + PAD, mini(Blocks.Y_MAX, hi.y + 4), hi.z + PAD)
	var size := hi - lo + Vector3i.ONE
	if size.x > SIDE_MAX or size.y > SIDE_MAX or size.z > SIDE_MAX:
		out.clipped = true
		hi = lo + size.mini(SIDE_MAX) - Vector3i.ONE
	var g := Grid.new(lo, hi, after, Ask.heights(build, land, lo, hi))
	out.grid = g
	var rules: Dictionary = rl.get("rules") if rl != null else {}
	var zones: Dictionary = rl.get("zones") if rl != null else {}
	g.open_zones(zones, rules)
	out.floating = _floating(g, after, added)
	for z: Dictionary in new_zones:
		var look := str(z.look)
		if look == "pad" or look == "flag":
			var fc := Check.floor_centre(z.box)
			var c := Vector3i(floori(fc.x), int(z.box[0][1]), floori(fc.z))
			if is_nan(g.support(c)):
				out.no_floor.append(int(z.id))
				out.marks.append(c + Vector3i.DOWN)
		elif look == "coin":
			var p := (Vector3(z.box[0][0], z.box[0][1], z.box[0][2]) + Vector3(z.box[1][0], z.box[1][1], z.box[1][2]) + Vector3.ONE) * 0.5
			var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
			var s := g.shape_at(c)
			if s in FULL_TOP or (s in PARTIAL and p.y - floorf(p.y) < 0.5):
				out.coin_in_block.append(int(z.id))
				out.marks.append(c)
	out.marks.append_array(out.floating)
	g.build_nodes()
	out.nodes = g.nodes.size()
	out.runs = _runs(g, zones, rules, new_rules, new_zones)
	for run: Dictionary in out.runs:
		if not bool(run.reachable):
			for f: int in run.finish:
				out.marks.append(Vector3i(zones[f].box[0][0], zones[f].box[0][1], zones[f].box[0][2]))
	out.line = line(out, zones)
	out["findings"] = findings(out, zones)
	return out


## The findings as the note's line: "2 blocks float; the flag Finish has no floor; finish not reachable" ("" = none).
static func line(s: Dictionary, zones: Dictionary = {}) -> String:
	var parts := PackedStringArray()
	var nf: int = (s.floating as Array).size()
	if nf > 0:
		parts.append("1 block floats" if nf == 1 else "%d blocks float" % nf)
	var named := func(id: int) -> String:
		var z: Dictionary = zones.get(id, {})
		return "the %s %s" % [str(z.get("look", "zone")), str(z.name)] if z.has("name") else "a %s" % str(z.get("look", "zone"))
	var nn: int = (s.no_floor as Array).size()
	if nn == 1:
		parts.append("%s has no floor" % named.call(int(s.no_floor[0])))
	elif nn > 1:
		parts.append("%d pads or flags have no floor" % nn)
	var nc: int = (s.coin_in_block as Array).size()
	if nc > 0:
		parts.append("a coin is inside a block" if nc == 1 else "%d coins are inside blocks" % nc)
	var runs: Array = s.runs
	var away := 0
	for run: Dictionary in runs:
		away += int(run.coins) - int(run.coins_reached)
		if (run.finish as Array).is_empty():
			parts.append(("run %s: " % run.run if runs.size() > 1 else "") + "no finish zone")
		elif not bool(run.reachable):
			parts.append("finish not reachable" if runs.size() == 1 else "finish of %s not reachable" % run.run)
	if away > 0:
		parts.append("1 coin out of reach" if away == 1 else "%d coins out of reach" % away)
	if bool(s.get("clipped", false)):
		parts.append("checked within %d m" % SIDE_MAX)
	return "; ".join(parts)


## The marks over the problem cells (`check`'s `marks`, at most MARKS_MAX): a box a little larger than the cell in a
## red copy of the style's holo material (as ghost.gd's refused place), drawn with the ghost. null when there are none.
## The caller adds it to the tree and frees it.
static func marks_node(cells: Array) -> Node3D:
	if cells.is_empty():
		return null
	var root := Node3D.new()
	root.name = "SpaceMarks"
	root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var mat: Material = TLStyle.material_instance("holo")
	if mat is ShaderMaterial and not TLStyle.headless():
		var red := TLStyle.color("hazard_red")
		(mat as ShaderMaterial).set_shader_parameter(&"holo", red)
		(mat as ShaderMaterial).set_shader_parameter(&"edge", red.lightened(0.4))
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 1.12
	var done := {}
	for c: Vector3i in cells:
		if done.has(c) or done.size() >= MARKS_MAX:
			continue
		done[c] = true
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(c) + Vector3.ONE * 0.5
		root.add_child(mi)
	return root


## The cells of a blocks.gd store (a dry run's added cells).
static func _cells(store: Variant) -> Array:
	var out := []
	if not (store is RefCounted):
		return out
	var secs: Dictionary = (store as RefCounted).get("sections")
	for s: Vector2i in secs:
		for idx: int in (secs[s] as Dictionary):
			out.append((store as RefCounted).call("cell_of", s, idx))
	return out


## The added cells joined to no block that was there and to no ground (through added blocks, face to face).
static func _floating(g: Grid, after: RefCounted, added: Array) -> Array:
	var mine := {}
	for c: Vector3i in added:
		mine[c] = true
	var held := {}
	var queue := []
	for c: Vector3i in added:
		var on := c.y <= g.ground_cell(c.x, c.z)
		if not on:
			for d: Vector3i in Grid.SIX:
				var n := c + d
				if not mine.has(n) and int(after.call("get_code", n)) != 0:
					on = true
					break
		if on:
			held[c] = true
			queue.append(c)
	var i := 0
	while i < queue.size():
		var c: Vector3i = queue[i]
		i += 1
		for d: Vector3i in Grid.SIX:
			var n := c + d
			if mine.has(n) and not held.has(n):
				held[n] = true
				queue.append(n)
	var out := []
	for c: Vector3i in added:
		if not held.has(c):
			out.append(c)
	out.sort()
	return out


## Every run an added rule starts: its start zone (the starting rule's trigger zone), its finish zones (the trigger
## zones of the rules that finish), whether a finish feet cell is reached from a start feet cell, the path, and the
## answer's coins reached.
static func _runs(g: Grid, zones: Dictionary, rules: Dictionary, new_rules: Array, new_zones: Array) -> Array:
	var mv := moves(rules)
	var finish: Array = mv.finish
	var launches: Array = mv.launches
	var teleports: Array = mv.teleports
	var coins := new_zones.filter(func(z: Dictionary) -> bool: return str(z.look) == "coin")
	var out := []
	var seen := {}
	for r: Dictionary in new_rules:
		for e: Dictionary in r.do:
			if str(e.do) != "start" or seen.has(str(e.run)):
				continue
			seen[str(e.run)] = true
			var at: Variant = (r.when as Dictionary).get("zone")
			var run := {"run": str(e.run), "start": -1 if at == null else int(at), "finish": finish.filter(func(f: int) -> bool: return zones.has(f)),
				"reachable": false, "path": [], "coins": coins.size(), "coins_reached": 0}
			if at != null and zones.has(int(at)):
				var walk := g.walk(g.nodes_in(zones[int(at)].box), zones, launches, teleports)
				var best := -1
				for f: int in run.finish:
					for c: Vector3i in g.nodes_in(zones[f].box):
						if walk.has(c) and (best == -1 or int(walk[c][1]) < best):
							best = int(walk[c][1])
							run.path = path_to(walk, c)
				run.reachable = best >= 0
				run["coins_away"] = []
				for z: Dictionary in coins:
					if g.nodes_in(z.box).any(func(c: Vector3i) -> bool: return walk.has(c)):
						run.coins_reached = int(run.coins_reached) + 1
					else:
						(run.coins_away as Array).append(int(z.id))
				if not run.reachable:
					run["gap"] = _gap(g, walk, zones, run.finish)
			out.append(run)
	return out


## Where a walk stops short of the finish, from the reached feet cells to the finish zones' feet cells: "gap", the
## shortest jump across among those low enough to climb (up <= JUMP_UP), and "wall", the lowest climb among those near
## enough (across <= JUMP_ACROSS), each {"from", "to", "across" m, "up" m} or absent; "to_floor" false when no finish zone
## has a feet cell at all.
static func _gap(g: Grid, walk: Dictionary, zones: Dictionary, finish: Array) -> Dictionary:
	var ends := []
	for f: int in finish:
		ends.append_array(g.nodes_in(zones[f].box))
	if ends.is_empty():
		return {"to_floor": false}
	var out := {"to_floor": true}
	for c: Vector3i in walk:
		for e: Vector3i in ends:
			var across := Vector2(e.x - c.x, e.z - c.z).length()
			var up := float(g.nodes[e]) - float(g.nodes[c])
			var j := {"from": c, "to": e, "across": across, "up": up}
			if up <= JUMP_UP and (not out.has("gap") or across < float(out.gap.across) - 0.001):
				out["gap"] = j
			if across <= JUMP_ACROSS + 0.001 and (not out.has("wall") or up < float(out.wall.up) - 0.001):
				out["wall"] = j
	return out


## The findings in words a model can act on, one line each, with cells: "2 blocks float: (3, 12, 5), (4, 12, 5)";
## "the pad Start (zone 1, box ...) has no floor: nothing to stand on at (x, y, z)"; "finish of Hop not reachable:
## the walk from the start gets as close as feet cell (..), 6.0 m across and 1.0 m up from the finish's (..); a jump
## crosses at most 4 m (3 empty cells) and climbs 1.2 m". Empty when nothing was found (command_tool.gd's fix ask).
static func findings(s: Dictionary, zones: Dictionary) -> Array:
	var out := []
	var cell := func(c: Vector3i) -> String: return "(%d, %d, %d)" % [c.x, c.y, c.z]
	var fl: Array = s.floating
	if not fl.is_empty():
		out.append("%s (joined to no block and no ground): %s%s" % ["1 block floats" if fl.size() == 1 else "%d blocks float" % fl.size(),
			", ".join(PackedStringArray(fl.slice(0, 12).map(cell))), "" if fl.size() <= 12 else ", ..."])
	var zname := func(id: int) -> String:
		var z: Dictionary = zones.get(id, {})
		return "the %s %s(zone %d, box %s)" % [str(z.get("look", "zone")), (str(z.name) + " ") if z.has("name") else "", id, JSON.stringify(z.get("box", []))]
	for id: int in s.no_floor:
		var fc := Check.floor_centre(zones[id].box)
		out.append("%s has no floor: its bottom row is not a feet cell over a block or the ground at (%d, %d, %d)" % [zname.call(id), floori(fc.x), int(zones[id].box[0][1]), floori(fc.z)])
	for id: int in s.coin_in_block:
		out.append("%s has its token inside a solid block: move it up so its bottom cell is a feet cell" % zname.call(id))
	for run: Dictionary in s.runs:
		if (run.finish as Array).is_empty():
			out.append("run %s has no finish: no rule with a zone trigger does finish" % run.run)
		elif not bool(run.reachable):
			var gp: Dictionary = run.get("gap", {})
			if not bool(gp.get("to_floor", true)):
				out.append("finish of %s not reachable: no finish zone has a feet cell (a cell over a block or the ground with 1.8 m of headroom)" % run.run)
			elif gp.has("gap") or gp.has("wall"):
				var why := PackedStringArray()
				if gp.has("gap"):
					why.append("a gap too wide: from feet cell %s to the finish's %s is %.1f m across (%d empty cells)" % [cell.call(gp.gap.from),
						cell.call(gp.gap.to), float(gp.gap.across), maxi(0, roundi(float(gp.gap.across)) - 1)])
				if gp.has("wall"):
					why.append("a climb too high: from feet cell %s to the finish's %s is %.1f m up" % [cell.call(gp.wall.from), cell.call(gp.wall.to), float(gp.wall.up)])
				out.append("finish of %s not reachable from its start; the nearest the walk gets: %s. A step climbs 0.55 m (stairs, slabs), a jump at most 1.2 m up and 4 m across (3 empty cells)" % [
					run.run, "; ".join(why)])
			else:
				out.append("finish of %s not reachable: the walk from the start (if its zone has a feet cell at all) reaches nothing within 1.2 m below the finish or 4 m across from it" % run.run)
		for id: int in run.get("coins_away", []):
			out.append("%s is out of reach of the walk from the start" % zname.call(id))
	return out


## What the rules make of space: {"finish": [the trigger zones of the rules that finish], "launches": [[zone id, up m/s,
## fwd m/s]], "teleports": [[from zone, to zone]]}, by rule id.
static func moves(rules: Dictionary) -> Dictionary:
	var finish := []
	var launches := []
	var teleports := []
	for n: int in RulesIds.sorted(rules):
		var r: Dictionary = rules[n]
		var at: Variant = (r.when as Dictionary).get("zone")
		for e: Dictionary in r.do:
			if at == null:
				continue
			match str(e.do):
				"finish":
					if not finish.has(int(at)):
						finish.append(int(at))
				"launch":
					launches.append([int(at), int(e.up_cm) / 100.0, int(e.fwd_cm) / 100.0])
				"teleport":
					teleports.append([int(at), int(e.zone)])
	return {"finish": finish, "launches": launches, "teleports": teleports}


## The feet cells from a walk's start to `end` (Grid.walk's result).
static func path_to(walk: Dictionary, end: Vector3i) -> Array:
	var out := [end]
	var c: Variant = walk[end][0]
	while c != null:
		out.push_front(c)
		c = walk[c][0]
	return out


class RulesIds:
	static func sorted(d: Dictionary) -> Array:
		var ids := d.keys()
		ids.sort()
		return ids


## The searched box: the shapes of its cells after the answer (open zones' cells passable), the ground, the feet cells.
class Grid:
	const SIX := [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.DOWN, Vector3i.UP, Vector3i.FORWARD, Vector3i.BACK]
	var lo: Vector3i
	var hi: Vector3i
	var size: Vector3i
	var shapes := PackedByteArray()
	var heights: Array                    # rows[z - lo.z][x - lo.x]: the ground in m
	var nodes := {}                       # Vector3i feet cell -> feet height in m
	var columns := {}                     # Vector2i (x, z) -> [Vector3i feet cells], low first
	var jump_up := JUMP_UP                # the limits of a plain jump (a stricter walker: smaller ones)
	var jump_across := JUMP_ACROSS

	func _init(a: Vector3i, b: Vector3i, store: RefCounted, hs: Array) -> void:
		lo = a
		hi = b
		size = b - a + Vector3i.ONE
		heights = hs
		shapes.resize(size.x * size.y * size.z)
		var s0: Vector2i = store.call("section_of", a)
		var s1: Vector2i = store.call("section_of", b)
		var secs: Dictionary = store.get("sections")
		for sz in range(s0.y, s1.y + 1):
			for sx in range(s0.x, s1.x + 1):
				var d: Variant = secs.get(Vector2i(sx, sz))
				if d == null:
					continue
				for idx: int in (d as Dictionary):
					var c: Vector3i = store.call("cell_of", Vector2i(sx, sz), idx)
					if inside(c):
						shapes[_i(c)] = Blocks.shape_of(int((d as Dictionary)[idx]))

	func inside(c: Vector3i) -> bool:
		return c.x >= lo.x and c.x <= hi.x and c.y >= lo.y and c.y <= hi.y and c.z >= lo.z and c.z <= hi.z

	func _i(c: Vector3i) -> int:
		return ((c.y - lo.y) * size.z + (c.z - lo.z)) * size.x + (c.x - lo.x)

	func shape_at(c: Vector3i) -> int:
		return shapes[_i(c)] if inside(c) else 0

	func ground(x: int, z: int) -> float:
		if x < lo.x or x > hi.x or z < lo.z or z > hi.z:
			return -INF
		return float(heights[z - lo.z][x - lo.x])

	func ground_cell(x: int, z: int) -> int:
		var h := ground(x, z)
		return -(1 << 30) if is_inf(h) else floori(h + 0.01)

	## The cells of every zone a rule opens or toggles are passable (a door the walker can open).
	func open_zones(zones: Dictionary, rules: Dictionary) -> void:
		for n: int in rules:
			for e: Dictionary in rules[n].do:
				if str(e.do) in ["open", "toggle"] and zones.has(int(e.zone)):
					var b: Array = zones[int(e.zone)].box
					for y in range(int(b[0][1]), int(b[1][1]) + 1):
						for z in range(int(b[0][2]), int(b[1][2]) + 1):
							for x in range(int(b[0][0]), int(b[1][0]) + 1):
								if inside(Vector3i(x, y, z)):
									shapes[_i(Vector3i(x, y, z))] = 0

	## The height (m) of the floor a person's feet rest on when his feet cell is `c` (NAN: no floor there): a slab,
	## stair, ramp or roof in `c` (half way up), a cube or a window under an empty `c` (its top), or the ground of an
	## empty column whose ground cell is `c`.
	func support(c: Vector3i) -> float:
		var s := shape_at(c)
		if s in PARTIAL:
			return c.y + 0.5
		if s != 0:
			return NAN
		var below := shape_at(c + Vector3i.DOWN)
		if below in FULL_TOP:
			return c.y
		if below == 0 and ground_cell(c.x, c.z) == c.y:
			return ground(c.x, c.z)
		return NAN

	## The feet height (m) of a person standing with his feet cell `c` (a floor and 1.8 m of headroom), or NAN.
	func feet(c: Vector3i) -> float:
		var base := support(c)
		if is_nan(base):
			return NAN
		for y in range(c.y + 1, floori(base + HEAD - 0.01) + 1):
			if shape_at(Vector3i(c.x, y, c.z)) != 0:
				return NAN
		return base

	func build_nodes() -> void:
		for z in range(lo.z, hi.z + 1):
			for x in range(lo.x, hi.x + 1):
				var col := []
				for y in range(lo.y, hi.y + 1):
					var c := Vector3i(x, y, z)
					var f := feet(c)
					if not is_nan(f):
						nodes[c] = f
						col.append(c)
				if not col.is_empty():
					columns[Vector2i(x, z)] = col

	func nodes_in(box: Array) -> Array:
		var out := []
		for z in range(int(box[0][2]), int(box[1][2]) + 1):
			for x in range(int(box[0][0]), int(box[1][0]) + 1):
				for c: Vector3i in columns.get(Vector2i(x, z), []):
					if c.y >= int(box[0][1]) and c.y <= int(box[1][1]):
						out.append(c)
		return out

	## Nothing solid between the feet cells `p` and `q`: in the columns strictly between theirs at a step over the higher
	## feet and at head height, and in their own columns from above each feet cell up to that head height (he rises out
	## of one and drops into the other).
	func clear(p: Vector3i, q: Vector3i) -> bool:
		var a := Vector3(p.x + 0.5, float(nodes[p]), p.z + 0.5)
		var b := Vector3(q.x + 0.5, float(nodes[q]), q.z + 0.5)
		var top := maxf(a.y, b.y)
		var head := floori(top + HEAD - 0.1)
		for e: Vector3i in [p, q]:
			for y in range(e.y + 1, head + 1):
				if shape_at(Vector3i(e.x, y, e.z)) != 0:
					return false
		var d := Vector2(b.x - a.x, b.z - a.z)
		var n := maxi(1, ceili(d.length() / 0.5))
		var ca := Vector2i(floori(a.x), floori(a.z))
		var cb := Vector2i(floori(b.x), floori(b.z))
		for k in range(1, n):
			var m := Vector2(a.x, a.z) + d * (float(k) / n)
			var col := Vector2i(floori(m.x), floori(m.y))
			if col == ca or col == cb:
				continue
			for h: float in [top + 0.1, top + HEAD - 0.1]:
				if shape_at(Vector3i(col.x, floori(h), col.y)) != 0:
					return false
		return true

	## Breadth first over the feet cells from `starts`: {Vector3i: [parent or null, steps]}. The cells in `avoid` are
	## never entered (a walk round a finish that would end the run too early).
	func walk(starts: Array, zones: Dictionary, launches: Array, teleports: Array, avoid := {}) -> Dictionary:
		var seen := {}
		var queue := []
		for c: Vector3i in starts:
			seen[c] = [null, 0]
			queue.append(c)
		var jump_in := {}                   # feet cell -> [up m, across m] of the launch zone it is in
		for l: Array in launches:
			if zones.has(int(l[0])):
				var up := JUMP_UP + pow(float(l[1]), 2.0) / (2.0 * GRAVITY)
				var across := minf(LAUNCH_MAX, JUMP_ACROSS + float(l[2]) * 2.0 * float(l[1]) / GRAVITY)
				for c: Vector3i in nodes_in(zones[int(l[0])].box):
					jump_in[c] = [up, across]
		var hop := {}                       # feet cell -> [feet cells it teleports to]
		for t: Array in teleports:
			if zones.has(int(t[0])) and zones.has(int(t[1])):
				var to := nodes_in(zones[int(t[1])].box)
				for c: Vector3i in nodes_in(zones[int(t[0])].box):
					hop[c] = to
		var i := 0
		while i < queue.size():
			var c: Vector3i = queue[i]
			i += 1
			var steps: int = seen[c][1] + 1
			var a_y := float(nodes[c])
			var up := jump_up
			var across := jump_across
			if jump_in.has(c):
				up = jump_in[c][0]
				across = jump_in[c][1]
			var r := ceili(across)
			for dz in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx == 0 and dz == 0:
						continue
					var dist := Vector2(dx, dz).length()
					if dist > across + 0.001:
						continue
					for n: Vector3i in columns.get(Vector2i(c.x + dx, c.z + dz), []):
						if seen.has(n) or avoid.has(n):
							continue
						var dh := float(nodes[n]) - a_y
						var ok := false
						if dist <= 1.001 and absf(dh) <= STEP:
							ok = true                   # a walk or a step
						elif dh <= up:
							ok = clear(c, n)            # a jump, a drop
						if ok:
							seen[n] = [c, steps]
							queue.append(n)
			for n: Vector3i in hop.get(c, []):
				if not seen.has(n) and not avoid.has(n):
					seen[n] = [c, steps]
					queue.append(n)
		return seen
