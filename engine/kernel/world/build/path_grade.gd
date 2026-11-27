extends RefCounted
## M5 (spark world-sandbox, lane P): the grading a path tool writes with its path, as ONE land op in the same batch
## (contracts/BUILD.md "Milestone 5": grading is not part of the path op). Every 3 m lattice vertex within half the
## width + one lattice cell of the centre line moves toward the centre line's height there: fully within the half
## width, blended to nothing at half width + 3 m (smoothstep). The centre line's heights are the ground's now along the
## spline, averaged over SMOOTH metres either way, so the path's cross slope goes and its small bumps along it with it.
## No vertex moves more than MAX_CM (1.5 m); a vertex the rules refuse (a protected area, the visitor, blocks, a piece)
## is left out, and the path still lays. Reads the land layer; changes nothing.

const PathShape := preload("res://kernel/world/build/path_shape.gd")
const L := 3.0                          # the land lattice (metres)
const MAX_CM := 150
const SMOOTH := 4.0                     # metres of the centre line averaged either way


## Lays path op `op` with its grading through `build` (home_build.gd) as ONE batch (one undo): the path first, then,
## when it was taken, the land op. Returns {"ok", "reason", "id", "graded" (vertices moved), "skipped" (vertices the
## rules left out), "skip_reason", "usec"}. A refused path writes nothing.
static func lay(build: RefCounted, path_op: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var who := str(path_op.get("author", "hand"))
	build.begin_batch(who)
	var r: Dictionary = build.apply(path_op)
	var out := {"ok": bool(r.ok), "reason": str(r.reason), "id": int(path_op.get("id", 0)), "graded": 0, "skipped": 0, "skip_reason": ""}
	if bool(r.ok):
		var refused := [0, ""]
		var land: RefCounted = build.layer("land")
		var g := op(land, PathShape.sample(path_op.pts), float(path_op.width_cm) / 100.0, who, refused)
		out.skipped = refused[0]
		out.skip_reason = refused[1]
		if not g.is_empty():
			var r2: Dictionary = build.apply(g)
			out.graded = (g.verts as Array).size() if bool(r2.ok) else 0
			if not bool(r2.ok):
				out.skip_reason = "grading refused: " + str(r2.reason)
	build.end_batch()
	out["usec"] = Time.get_ticks_usec() - t0
	return out


## The land op ({"op": "land", "verts": [[i, j, from_cm, to_cm], ...], "author"}, sorted by j then i) that grades
## the path of samples `sm` (path_shape.gd `sample`) and width `width_m`; {} when no vertex moves. `refused` gets the
## number of vertices left out (out param: an Array, [0] is counted up), and `why` their first reason.
static func op(land: RefCounted, sm: Dictionary, width_m: float, who := "hand", refused: Array = [0, ""]) -> Dictionary:
	var p: PackedVector2Array = sm.p
	var n := p.size()
	if land == null or n < 2:
		return {}
	var h := width_m * 0.5
	var reach := h + L
	# the centre line's heights, averaged along it
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i: int in n:
		raw[i] = float(land.height_at(p[i].x, p[i].y))
	var k := maxi(1, roundi(SMOOTH / PathShape.STEP))
	var ys := PackedFloat32Array()
	ys.resize(n)
	for i: int in n:
		var s := 0.0
		var c := 0
		for q: int in range(maxi(0, i - k), mini(n - 1, i + k) + 1):
			s += raw[q]
			c += 1
		ys[i] = s / float(c)
	var index: RefCounted = PathShape.Index.new()
	index.add(1, p, reach)
	var box := PathShape.box_of(p, reach)
	var i0 := ceili(box.position.x / L)
	var i1 := floori(box.end.x / L)
	var j0 := ceili(box.position.y / L)
	var j1 := floori(box.end.y / L)
	var verts := []
	land.begin_asking(Rect2(i0 * L - L, j0 * L - L, (i1 - i0 + 2) * L, (j1 - j0 + 2) * L))
	for j: int in range(j0, j1 + 1):
		for i: int in range(i0, i1 + 1):
			var q := Vector2(i * L, j * L)
			var near: Dictionary = index.near(q)
			if not near.has(1):
				continue
			var r: Array = near[1]
			var d: float = r[0]
			var target: float = lerpf(ys[int(r[1])], ys[int(r[1]) + 1], float(r[2])) * 100.0
			var w := 1.0 if d <= h else 1.0 - smoothstep(h, reach, d)
			if w <= 0.0:
				continue
			var v := Vector2i(i, j)
			var from: int = land.cm_at(v)
			var to := from + clampi(roundi((target - from) * w), -MAX_CM, MAX_CM)
			if to == from:
				continue
			var why: String = str(land.refusal(v, "land"))
			if why == "":
				why = str(land.limit_refusal(v, to))
			if why != "":
				refused[0] = int(refused[0]) + 1
				if str(refused[1]) == "":
					refused[1] = why
				continue
			verts.append([i, j, from, to])
	land.end_asking()
	if verts.is_empty():
		return {}
	return {"op": "land", "verts": verts, "author": who}
