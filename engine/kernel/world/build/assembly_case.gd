extends SceneTree
## M6 round 3, lane A6 (27 Nov 2026): assemblies (contracts/BUILD.md "Assemblies (M6, round 3)"; assembly.gd,
## assembly_kinds.gd, blocks_layer.gd `expand_input`, tools/assembly_tool.gd), headless, no landscape. Prints
## `HOME assembly.<case> ok|fail <detail>`, then `HOME assembly ok` (or fail) and `HOME DONE`;
## engine/tools/selftest.d/794-home-assembly.sh reads them. Frames, not wall clock.
##   assembly.kinds     every kind at 3 sizes x 4 rots on a ground of its own (flat; a trench under a bridge): the op
##                      list the same twice, the same shape at every rot (each cell turned back), no block floating
##                      (command_space.gd), and walkable where the kind says so: from its start cell to its goal by the
##                      space check's estimate AND by a stricter walker that never jumps (steps of 0.55 m, and 1 m only
##                      up or down a stair block toward its high side)
##   assembly.compose   a stair assembly meeting a platform's railing opening: the ground reaches the platform's top
##   assembly.stairside a stair run joined only at its foot or its top (round 3, Q-A6): from the ground beside its first
##                      step yes, from a ledge beside its second step no, from the ground at its foot yes
##   assembly.windows   a house's opts.windows (round 4, Q-A8): 0, 1, 2, 4 front windows beside the door (none in the
##                      door's cells), the default 2 for 7 wide, the other walls unchanged
##   assembly.refusals  bad kinds, sizes, mats, opts, too small for what it says: refused with the reason
##   assembly.protect   a tower over a protected box and over an occupied cell: the place ops there are refused with
##                      the protection's reason and "occupied" by the dry run, `left_out` names the same cells
##   assembly.input     home_build.gd `expand_input`: an assemble becomes its place ops (author kept), a place passes, a
##                      bad assemble is refused at its index; the ask offers assemble; seam_lists' INPUT_OPS agrees;
##                      (round 4) the ask's land_refused marks a protected box's 3 m ground cells, omitted when none
##   assembly.tool      the Shapes tool: pick a kind, press a corner, drag the footprint, the wheel sets the height, ]
##                      cycles an opt: the ghost first (a dry run), release builds ONE batch equal to the expansion of
##                      the same assemble; one undo takes it back

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const BuildMode := preload("res://kernel/world/build/build_mode.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const Assembly := preload("res://kernel/world/build/assembly.gd")
const Space := preload("res://kernel/world/build/command_space.gd")
const CommandAsk := preload("res://kernel/world/build/command_ask.gd")
const Lists := preload("res://kernel/world/build/seam_lists.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const DIRS := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]
const BASE := 10                          # the test ground's cell y
const AT := Vector3i(40, BASE, 40)

var ok_all := true


func _initialize() -> void:
	call_deferred("run")


func say(n: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME assembly.%s %s %s" % [n, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	kinds_case()
	compose_case()
	stairside_case()
	windows_case()
	refusals_case()
	protect_case()
	input_case()
	if ResourceLoader.exists("res://kernel/world/build/tools/assembly_tool.gd"):
		await (load("res://kernel/world/build/assembly_tool_case.gd") as GDScript).new().run(self)
	print("HOME assembly %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


# ------------------------------------------------------------------ the walks
## Each kind's cases: [op, start local feet cell, goal local feet cell, local x range a walk may use ([] any), the depth
## of the bridge's trench (0 none)]. Start and goal are null for a shape that claims no walk.
func cases() -> Array:
	var out := []
	var a := func(kind: String, size: Array, opts := {}) -> Dictionary:
		var o := {"op": "assemble", "kind": kind, "at": [AT.x, AT.y, AT.z], "size": size, "rot": 0, "mat": 1, "trim": 2}
		if not opts.is_empty():
			o["opts"] = opts
		return o
	for wl: Array in [[5, 3], [9, 4], [15, 6]]:
		var door: int = wl[0] / 2
		out.append([a.call("wall", [wl[0], wl[1], 1], {"door": door, "windows": 3, "crenels": true}), Vector3i(door, 0, -3), Vector3i(door, 0, 3), [0, wl[0] - 1], 0])
	for th: Array in [[3, 5], [7, 12], [11, 20]]:
		out.append([a.call("tower", [th[0], th[1], 1], {"stairs": "outside", "crenels": true, "windows": 2, "door": th[0] / 2}),
			Vector3i(th[0] / 2, 0, -3), Vector3i(th[0] / 2, th[1], th[0] / 2), [], 0])
	for th: Array in [[5, 6], [7, 12], [9, 20]]:
		out.append([a.call("tower", [th[0], th[1], 1], {"stairs": "inside", "crenels": true, "windows": 3}),
			Vector3i(th[0] / 2, 0, -3), Vector3i(th[0] / 2, th[1], th[0] / 2), [], 0])
	for s: Array in [[3, 3, 3], [7, 4, 5], [6, 5, 11]]:
		out.append([a.call("house", s), Vector3i(s[0] / 2, 0, -3), Vector3i(s[0] / 2, 1, s[2] / 2), [], 0])
	for s: Array in [[1, 3], [3, 6], [2, 13]]:
		var last: int = s[1] - 1 + (s[1] - 1) / 6
		out.append([a.call("stair", [s[0], s[1], 1]), Vector3i(s[0] / 2, 0, -2), Vector3i(s[0] / 2, s[1] - 1, last), [], 0])
	for s: Array in [[1, 2, 4], [3, 3, 9], [5, 5, 20]]:
		var o: Dictionary = a.call("bridge", [s[0], 1, s[2]])
		o.at = [AT.x, AT.y + s[1], AT.z]                 # the deck s[1] over the banks
		var dh: int = s[1]
		out.append([o, Vector3i(s[0] / 2, -dh, -dh - 3), Vector3i(s[0] / 2, -dh, s[2] + dh + 2), [], 8])
	for s: Array in [[1, 1], [3, 3], [8, 6]]:
		var o: Dictionary = a.call("platform", [s[0], 1, s[1]])
		o.at = [AT.x, AT.y + 4, AT.z]
		var inner := 1 if s[0] >= 3 and s[1] >= 3 else 0
		out.append([o, Vector3i(inner, 1, inner), Vector3i(s[0] - 1 - inner, 1, s[1] - 1 - inner), [], 0])
	return out


## The ground of a case: flat at BASE, and `trench` cells deeper under the middle of a bridge's span (local z 1..d-2,
## any x), in the shape's own frame so it turns with it. Returns the cell callable.
func ground_for(op: Dictionary, trench: int) -> Callable:
	var at := Vector3i(int(op.at[0]), int(op.at[1]), int(op.at[2]))
	var r := int(op.rot)
	var d := int(op.size[2])
	return func(x: int, z: int) -> int:
		if trench <= 0:
			return BASE
		var l: Vector3i = Assembly.unturn(at, r, Vector3i(x, 0, z))
		return BASE - trench if l.z >= 1 and l.z <= d - 2 else BASE


func kinds_case() -> void:
	var bad := []
	var lines := PackedStringArray()
	var walks := 0
	for c: Array in cases():
		var base_op: Dictionary = c[0]
		var ref: Array = []
		var counts := []
		for r in 4:
			var op := base_op.duplicate(true)
			op.rot = r
			var gnd := ground_for(op, int(c[4]))
			var e1: Dictionary = Assembly.expand(op, gnd)
			var e2: Dictionary = Assembly.expand(op.duplicate(true), gnd)
			var tag := "%s %s rot %d" % [op.kind, str(op.size), r]
			if e1.has("error"):
				bad.append("%s: %s" % [tag, e1.error])
				continue
			if JSON.stringify(e1.ops) != JSON.stringify(e2.ops):
				bad.append("%s: not the same twice" % tag)
			var local := local_cells(op, e1.ops)
			if r == 0:
				ref = local
			elif JSON.stringify(local) != JSON.stringify(ref):
				bad.append("%s: not rot 0's shape turned" % tag)
			counts.append((e1.ops as Array).size())
			var w := walk(op, e1.ops, gnd, c[1], c[2], c[3])
			walks += 1
			if not bool(w.estimate) or not bool(w.strict) or int(w.floating) > 0:
				bad.append("%s: estimate %s, strict %s, %d floating (%s)" % [tag, w.estimate, w.strict, w.floating, w.why])
		lines.append("%s %s: %d" % [base_op.kind, str(base_op.size), counts[0] if not counts.is_empty() else -1])
	say("kinds", bad.is_empty(), "%d walks (6 kinds x 3 sizes, towers outside and inside, x 4 rots): %s%s" % [walks,
		", ".join(lines), "" if bad.is_empty() else "; BAD " + "; ".join(PackedStringArray(bad.slice(0, 8)))])


## The ops' cells turned back to the shape's frame, with shape, mat and the block's own turn undone: sorted strings.
func local_cells(op: Dictionary, ops: Array) -> Array:
	var at := Vector3i(int(op.at[0]), int(op.at[1]), int(op.at[2]))
	var out := []
	for o: Dictionary in ops:
		var l: Vector3i = Assembly.unturn(at, int(op.rot), Vector3i(int(o.at[0]), int(o.at[1]), int(o.at[2])))
		var r := posmod(int(o.rot) - int(op.rot), 4) if Assembly.TURNS.has(int(o.shape)) else int(o.rot)
		out.append("%d,%d,%d:%d:%d:%d" % [l.x, l.y, l.z, int(o.shape), int(o.mat), r])
	out.sort()
	return out


## Builds `ops` into a store over the case's ground and walks from local feet cell `from` to `to`:
## {"estimate", "strict", "floating", "why"}. `xs`: [x0, x1] the local x a walk may use (a wall's door: no way round).
func walk(op: Dictionary, ops: Array, gnd: Callable, from: Variant, to: Variant, xs: Array) -> Dictionary:
	var at := Vector3i(int(op.at[0]), int(op.at[1]), int(op.at[2]))
	var r := int(op.rot)
	var st: RefCounted = Blocks.new(16)
	var lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var hi := -lo
	for o: Dictionary in ops:
		var c := Vector3i(int(o.at[0]), int(o.at[1]), int(o.at[2]))
		st.put(c, Blocks.code(int(o.shape), int(o.mat), int(o.rot)))
		lo = lo.min(c)
		hi = hi.max(c)
	for p: Variant in [from, to]:
		if p != null:
			var c: Vector3i = Assembly.turn(at, r, p)
			lo = lo.min(c)
			hi = hi.max(c)
	lo = Vector3i(lo.x - 4, mini(lo.y, BASE - 10) - 2, lo.z - 4)
	hi = Vector3i(hi.x + 4, hi.y + 4, hi.z + 4)
	var rows := []
	for z in range(lo.z, hi.z + 1):
		var row := []
		for x in range(lo.x, hi.x + 1):
			row.append(float(gnd.call(x, z)) + 0.5)
		rows.append(row)
	var g: RefCounted = Space.Grid.new(lo, hi, st, rows)
	var added := []
	for o: Dictionary in ops:
		added.append(Vector3i(int(o.at[0]), int(o.at[1]), int(o.at[2])))
	var floating: Array = Space._floating(g, st, added)
	g.build_nodes()
	var out := {"estimate": true, "strict": true, "floating": floating.size(), "why": ""}
	if from == null:
		return out
	var a: Vector3i = Assembly.turn(at, r, from)
	var b: Vector3i = Assembly.turn(at, r, to)
	if not (g.nodes as Dictionary).has(a) or not (g.nodes as Dictionary).has(b):
		out.estimate = false
		out.strict = false
		out.why = "start %s %s, goal %s %s not feet cells" % [a, (g.nodes as Dictionary).has(a), b, (g.nodes as Dictionary).has(b)]
		return out
	var avoid := {}
	if not xs.is_empty():
		for n: Vector3i in g.nodes:
			var l: Vector3i = Assembly.unturn(at, r, n)
			if l.x < int(xs[0]) or l.x > int(xs[1]):
				avoid[n] = true
	var est: Dictionary = g.walk([a], {}, [], [], avoid)
	out.estimate = est.has(b)
	var strict := strict_walk(g, st, [a], avoid)
	out.strict = strict.has(b)
	out.why = "estimate reached %d cells, strict %d" % [est.size(), strict.size()]
	return out


## A walker who never jumps: to a side neighbour's feet cell at most Space.STEP up or down, or 1 m up or down when the
## lower cell is a stair block rising toward the higher one (with the headroom the estimate asks, Grid.clear).
func strict_walk(g: RefCounted, st: RefCounted, starts: Array, avoid: Dictionary) -> Dictionary:
	var seen := {}
	var q := []
	for c: Vector3i in starts:
		seen[c] = true
		q.append(c)
	var i := 0
	var nodes: Dictionary = g.get("nodes")
	var cols: Dictionary = g.get("columns")
	while i < q.size():
		var c: Vector3i = q[i]
		i += 1
		for dxz: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			for n: Vector3i in cols.get(Vector2i(c.x + dxz.x, c.z + dxz.y), []):
				if seen.has(n) or avoid.has(n):
					continue
				var dh := float(nodes[n]) - float(nodes[c])
				var ok := absf(dh) <= Space.STEP
				if not ok and absf(dh) <= 1.001:
					var low := c if dh > 0.0 else n
					var high := n if dh > 0.0 else c
					var code: int = st.get_code(low)
					ok = Blocks.shape_of(code) == Blocks.STAIR and Vector2i(high.x - low.x, high.z - low.z) == DIRS[Blocks.rot_of(code)] and g.clear(c, n)
				if ok:
					seen[n] = true
					q.append(n)
	return seen


## A stair (w 1, 5 steps) meeting the railing opening of a platform 5 over the ground: walked from the ground to the
## platform's middle.
func compose_case() -> void:
	var plat := {"op": "assemble", "kind": "platform", "at": [AT.x, AT.y + 4, AT.z], "size": [5, 1, 4], "rot": 0, "mat": 3, "trim": 4}
	var st := {"op": "assemble", "kind": "stair", "at": [AT.x + 2, AT.y, AT.z - 5], "size": [1, 5, 1], "rot": 0, "mat": 1}
	var gnd := func(_x: int, _z: int) -> int: return BASE
	var ops: Array = Assembly.expand(plat, gnd).ops + Assembly.expand(st, gnd).ops
	var w := walk(plat, ops, gnd, Vector3i(2, -4, -7), Vector3i(2, 1, 2), [])
	var only_plat := walk(plat, Assembly.expand(plat, gnd).ops, gnd, Vector3i(2, -4, -7), Vector3i(2, 1, 2), [])
	say("compose", bool(w.estimate) and bool(w.strict) and int(w.floating) == 0 and not bool(only_plat.strict),
		"platform 5 x 4 at 5 m + a 5-step stair to its opening: ground -> top estimate %s, strict %s, %d floating; the platform alone from the ground: strict %s (%s)" % [
		w.estimate, w.strict, w.floating, only_plat.strict, w.why])


func stairside_case() -> void:
	var gnd := func(_x: int, _z: int) -> int: return BASE
	var st_op := {"op": "assemble", "kind": "stair", "at": [AT.x, AT.y, AT.z], "size": [1, 3, 1], "rot": 0, "mat": 1}
	var ops: Array = Assembly.expand(st_op, gnd).ops
	ops.append({"op": "place", "at": [AT.x + 1, AT.y + 1, AT.z + 1], "shape": 1, "mat": 2, "rot": 0})   # a ledge beside step 2
	var st: RefCounted = Blocks.new(16)
	for o: Dictionary in ops:
		st.put(Vector3i(int(o.at[0]), int(o.at[1]), int(o.at[2])), Blocks.code(int(o.shape), int(o.mat), int(o.rot)))
	var lo := AT - Vector3i(4, 2, 4)
	var hi := AT + Vector3i(4, 6, 6)
	var rows := []
	for z in range(lo.z, hi.z + 1):
		rows.append(range(lo.x, hi.x + 1).map(func(_x: int) -> float: return BASE + 0.5))
	var g: RefCounted = Space.Grid.new(lo, hi, st, rows)
	g.build_nodes()
	var step1 := AT
	var step2 := AT + Vector3i(0, 1, 1)
	var side_ground := AT + Vector3i(1, 0, 0)
	var ledge := AT + Vector3i(1, 2, 1)
	var foot := AT + Vector3i(0, 0, -1)
	var a: bool = g.stair_entry(side_ground, step1)
	var b: bool = g.stair_entry(ledge, step2)
	var c: bool = g.stair_entry(foot, step1) and g.stair_entry(step1, step2)
	var w: Dictionary = g.walk([ledge], {}, [], [])
	var direct: bool = w.has(step2) and w[step2][0] == ledge
	say("stairside", a and not b and c and w.has(step2) and not direct and (g.nodes as Dictionary).has(ledge),
		"onto the first step from the side %s, onto the second from a ledge beside it %s, along the run %s; the walk from the ledge reaches step 2 %s, straight from the ledge %s (it goes down and round to the foot)" % [a, b, c, w.has(step2), direct])


func windows_case() -> void:
	var bad := []
	var got := []
	var back := -1
	for n: int in [-1, 0, 1, 2, 4]:
		var op := {"op": "assemble", "kind": "house", "at": [0, 0, 0], "size": [7, 3, 5], "rot": 0, "mat": 3, "trim": 6}
		if n >= 0:
			op["opts"] = {"windows": n}
		var e: Dictionary = Assembly.expand(op)
		if e.has("error"):
			bad.append("%d: %s" % [n, e.error])
			continue
		var front := []
		var others := 0
		for o: Dictionary in e.ops:
			if int(o.shape) == Blocks.WINDOW:
				if int(o.at[2]) == 0:
					front.append(int(o.at[0]))
				else:
					others += 1
		front.sort()
		got.append("%s -> %s" % ["default" if n < 0 else str(n), str(front)])
		if back < 0:
			back = others
		var want := 2 if n < 0 else n
		if front.size() != want or front.has(3) or others != back:
			bad.append("windows %d: front %s, others %d" % [n, str(front), others])
	say("windows", bad.is_empty(), "house 7 x 3 x 5, door at x 3: %s; %d windows on the other walls each time%s" % [
		", ".join(PackedStringArray(got)), back, "" if bad.is_empty() else "; BAD " + "; ".join(PackedStringArray(bad))])


func refusals_case() -> void:
	var good := {"op": "assemble", "kind": "tower", "at": [0, 0, 0], "size": [7, 10, 7], "rot": 1, "mat": 1, "trim": 2,
		"opts": {"stairs": "outside", "crenels": true}}
	var rows := [
		[{"kind": "castle"}, "unknown kind 'castle'"],
		[{"size": [7, 0, 7]}, "size must be"], [{"size": [49, 10, 7]}, "size must be"], [{"size": [7, 10]}, "size must be"],
		[{"rot": 4}, "rot must be 0..3"], [{"mat": 10}, "glass"], [{"mat": 13}, "unknown mat 13"], [{"trim": 10}, "glass"],
		[{"opts": {}}, "opts is written only when"], [{"opts": {"crenels": false}}, "crenels is written only when true"],
		[{"opts": {"stairs": "spiral"}}, "\"inside\" or \"outside\""], [{"opts": {"roof": true}}, "takes no opt 'roof'"],
		[{"opts": {"door": 0}}, "opts.door"], [{"opts": {"windows": 1}}, "opts.windows"],
		[{"size": [3, 10, 3], "opts": {"stairs": "inside"}}, "at least 5 wide"], [{"size": [7, 3, 7]}, "at least 4 high"],
		[{"kind": "house", "opts": {"door": 2}}, "a house takes no opt 'door' (only windows)"],
		[{"kind": "house", "size": [7, 4, 5], "opts": {"windows": 5}}, "0..4 for 7 wide"], [{"kind": "house", "size": [7, 4, 5], "opts": {"windows": -1}}, "opts.windows is how many"], [{"kind": "house", "size": [2, 4, 5], "opts": null}, "at least 3 x 3"],
		[{"kind": "wall", "size": [6, 2, 1], "opts": {"door": 2}}, "at least 3 high"], [{"extra": 1}, "unknown key 'extra'"],
		[{"op": "fill"}, "op must be \"assemble\""], [{"at": [0, 0]}, "at must be"]]
	var bad := []
	if Assembly.malformed(good) != "":
		bad.append("good refused: " + Assembly.malformed(good))
	for row: Array in rows:
		var o := good.duplicate(true)
		for k: String in row[0]:
			if row[0][k] == null:
				o.erase(k)
			else:
				o[k] = row[0][k]
		var why: String = Assembly.malformed(o)
		if not why.contains(str(row[1])):
			bad.append("%s -> '%s'" % [JSON.stringify(row[0]), why])
	say("refusals", bad.is_empty(), "%d bad assemblies refused with their reason, the good one taken%s" % [rows.size(),
		"" if bad.is_empty() else "; BAD " + "; ".join(PackedStringArray(bad))])


func protect_case() -> void:
	var b: RefCounted = HomeBuild.new(null, null, {})
	b.protect.add_box(AABB(Vector3(2, 0, 0), Vector3(2, 6, 2)), "test lot")      # cells x 2..3, y 0..5, z 0..1
	b.apply([{"op": "place", "at": [0, 3, 0], "shape": 1, "mat": 7, "rot": 0}])
	var op := {"op": "assemble", "kind": "tower", "at": [0, 0, 0], "size": [6, 6, 1], "rot": 0, "mat": 1, "author": "llm"}
	var ex: Dictionary = b.expand_input([op])
	var ops: Array = ex.ops
	var lo: Array = Assembly.left_out(ops, b)
	var r: Dictionary = b.preview(ops)
	var by := {}
	for x: Array in r.refused:
		by[str(x[1])] = int(by.get(str(x[1]), 0)) + 1
	var want_lot := 0
	for o: Dictionary in ops:
		if int(o.at[0]) >= 2 and int(o.at[0]) <= 3 and int(o.at[1]) <= 5 and int(o.at[2]) <= 1:
			want_lot += 1
	var same: bool = lo.size() == (r.refused as Array).size() and lo.all(func(x: Array) -> bool: return str(x[1]) in ["test lot", "occupied"])
	var ok: bool = int(by.get("test lot", 0)) == want_lot and want_lot > 0 and int(by.get("occupied", 0)) == 1 and same \
		and int(r.applied) == ops.size() - want_lot - 1 and int(b.blocks.total) == 1
	say("protect", ok, "tower 6 x 6 x 6 over a protected box and a stone block: %d place ops, %d refused 'test lot' (want %d), %d 'occupied', %d applied in the dry run; left_out names %d; the Home untouched (%d block)" % [
		ops.size(), int(by.get("test lot", 0)), want_lot, int(by.get("occupied", 0)), int(r.applied), lo.size(), int(b.blocks.total)])


func input_case() -> void:
	var b: RefCounted = HomeBuild.new(null, null, {})
	var asm := {"op": "assemble", "kind": "stair", "at": [0, 0, 0], "size": [2, 4, 1], "rot": 3, "mat": 1, "author": "llm"}
	var place := {"op": "place", "at": [9, 0, 9], "shape": 1, "mat": 1, "rot": 0, "author": "llm"}
	var broken := {"op": "assemble", "kind": "tower", "at": [0, 0, 0], "size": [2, 4, 2], "rot": 0, "mat": 1, "author": "llm"}
	var ex: Dictionary = b.expand_input([asm, place, broken])
	var want: Array = Assembly.expand(asm, Assembly.ground_of(b)).ops
	var got: Array = ex.ops
	var authored: bool = got.slice(0, want.size()).all(func(o: Dictionary) -> bool: return o.get("author") == "llm" and o.op == "place")
	var stripped := got.slice(0, want.size()).map(func(o: Dictionary) -> Dictionary:
		var c := o.duplicate()
		c.erase("author")
		return c)
	var ops_now: Array = CommandAsk.ops_now(b, Vector3i.ZERO)
	var ok: bool = JSON.stringify(stripped) == JSON.stringify(want) and authored and got.size() == want.size() + 1 and got[-1] == place \
		and str(ex.refused) == str([[2, "a tower is at least 3 wide (walls round a hollow)"]]) and ops_now.has("assemble") \
		and Lists.INPUT_OPS == HomeBuild.INPUT_OPS and Lists.layer_of("assemble") == "blocks"
	# round 4 (Q-A7): the ask's land_refused, the ground ops' refused columns in refused's shape (3 m cells)
	b.protect.add_box(AABB(Vector3(0, 0, 0), Vector3(6, 4, 3)), "test lot")
	var ask: Dictionary = CommandAsk.make(b, null, "a path", Vector3i(2, 0, 2), 0)
	var lr: Variant = ask.get("land_refused")
	var lr_ok := str(lr) == str([{"reason": "test lot", "runs": [[0, 0, 5], [1, 0, 5], [2, 0, 5]]}])
	var none_ok: bool = not CommandAsk.make(HomeBuild.new(null, null, {}), null, "a path", Vector3i(2, 0, 2), 0).has("land_refused")
	say("input", ok and lr_ok and none_ok, "expand_input: the stair's %d place ops (author llm), then the place; refused %s; ops_now %s; INPUT_OPS %s; the ask's land_refused over a protected box %s, none without one %s" % [
		want.size(), str(ex.refused), str(ops_now), str(HomeBuild.INPUT_OPS), str(lr), none_ok])
