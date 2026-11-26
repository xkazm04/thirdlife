extends RefCounted
## M2 (spark world-sandbox): what land_case.gd measures, static (the case keeps its input and its verdicts). `land` is
## the Home's land layer (land_layer.gd), `home` home/hook.gd.


## max - min of the heights in `s` (Vector2i -> cm) within `r` cells of `centre`.
static func spread(s: Dictionary, centre: Vector2i, r: int) -> int:
	var lo := 1 << 30
	var hi := -(1 << 30)
	for v: Vector2i in s:
		if absi(v.x - centre.x) <= r and absi(v.y - centre.y) <= r:
			lo = mini(lo, int(s[v]))
			hi = maxi(hi, int(s[v]))
	return hi - lo


## Mean absolute difference from the 4 neighbours' mean over the (2r+1)^2 vertices round `c` (cm).
static func rough(land: RefCounted, s: Dictionary, c: Vector2i, r: int) -> float:
	var t := 0.0
	var n := 0
	for j: int in range(c.y - r, c.y + r + 1):
		for i: int in range(c.x - r, c.x + r + 1):
			var v := Vector2i(i, j)
			var m := 0.0
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				m += float(s.get(v + o, land.cm_at(v + o)))
			t += absf(float(s[v]) - m / 4.0)
			n += 1
	return t / n


## The seam: every rim vertex of every edited chunk against what it meets across the rim: the valley's own drawn
## edge there (linear between the valley's two vertices on that grid line), or the edited neighbour's own surface.
## {"rims", "valley" (worst gap, m), "open" (worst gap to an edited neighbour, m), "cells", "hidden"}.
static func rims(land: RefCounted, home: RefCounted) -> Dictionary:
	var g: RefCounted = land.ground()
	var gv: PackedVector3Array = home.ground.vertices
	var out := {"rims": 0, "valley": 0.0, "open": 0.0, "cells": 0, "hidden": 0}
	for id: Vector2i in land.mesh.chunks:
		var s: Dictionary = land.mesh.chunks[id]
		var X: PackedFloat32Array = s.X
		var Z: PackedFloat32Array = s.Z
		var ys: PackedFloat32Array = s.ys
		var cv: Vector4i = s.cells
		for j: int in range(cv.z, cv.w + 1):
			for i: int in range(cv.x, cv.y + 1):
				if not g.village_cell(i, j):
					out.cells += 1
					out.hidden += 1 if home.ground.hidden.has(Vector2i(i, j)) else 0
		for q: int in Z.size():
			for p: int in X.size():
				if p != 0 and q != 0 and p != X.size() - 1 and q != Z.size() - 1:
					continue
				out.rims += 1
				var side := Vector2i(-1 if p == 0 else (1 if p == X.size() - 1 else 0), -1 if q == 0 else (1 if q == Z.size() - 1 else 0))
				var y := ys[q * X.size() + p]
				for o: Vector2i in [Vector2i(side.x, 0), Vector2i(0, side.y)]:
					if o == Vector2i.ZERO:
						continue
					if land.mesh.chunks.has(id + o):
						out.open = maxf(out.open, absf(y - float(land.mesh.y_at(id + o, X[p], Z[q]))))
					else:
						out.valley = maxf(out.valley, absf(y - valley_edge(g, gv, X[p], Z[q], o.x != 0)))
	return out


## The valley's own drawn edge at (x, z) on a grid line (a column line when `on_x`): linear between its two vertices.
static func valley_edge(g: RefCounted, gv: PackedVector3Array, x: float, z: float, on_x: bool) -> float:
	var n: int = g.n
	var i: int = (g.xs as PackedFloat32Array).find(x) if on_x else g.col_of(x)
	var j: int = g.row_of(z) if on_x else (g.zs as PackedFloat32Array).find(z)
	if i < 0 or j < 0:
		return NAN
	if on_x:
		var t: float = (z - g.zs[j]) / (g.zs[j + 1] - g.zs[j])
		return lerpf(gv[j * n + i].y, gv[(j + 1) * n + i].y, t)
	var t2: float = (x - g.xs[i]) / (g.xs[i + 1] - g.xs[i])
	return lerpf(gv[j * n + i].y, gv[j * n + i + 1].y, t2)


## chunk -> the identity of its mesh's arrays, for every edited chunk.
static func hashes(land: RefCounted) -> Dictionary:
	var out := {}
	for id: Vector2i in land.mesh.chunks:
		out[id] = str(land.mesh.figures(id)[2])
	return out


## Per edited chunk: its own triangles minus the valley's it hides (2 per cell).
static func added_tris(land: RefCounted) -> Array:
	var out := []
	for id: Vector2i in land.mesh.chunks:
		var cv: Vector4i = (land.mesh.chunks[id] as Dictionary).cells
		var valley := 0
		for j: int in range(cv.z, cv.w + 1):
			for i: int in range(cv.x, cv.y + 1):
				valley += 0 if land.ground().village_cell(i, j) else 2
		out.append(int(land.mesh.figures(id)[0]) - valley)
	return out


## The `q` quantile of a sorted list of usec, in ms (-1 for an empty list).
static func ms(sorted: Array, q: float) -> float:
	if sorted.is_empty():
		return -1.0
	return float(sorted[clampi(int(q * (sorted.size() - 1)), 0, sorted.size() - 1)]) / 1000.0


## What one redraw of edited chunk `id` costs, by part, median of `n` (ms): [mesh, body, scatter].
static func parts(land: RefCounted, home: RefCounted, id: Vector2i, n: int) -> Array:
	var t := [[], [], []]
	for k: int in n:
		var t0 := Time.get_ticks_usec()
		land.mesh.draw(id, true)
		var t1 := Time.get_ticks_usec()
		home.refresh(id)
		var t2 := Time.get_ticks_usec()
		land.scatter.update(id, Callable(land, "delta_at"))
		var t3 := Time.get_ticks_usec()
		t[0].append(t1 - t0)
		t[1].append(t2 - t1)
		t[2].append(t3 - t2)
	var out := []
	for a: Array in t:
		a.sort()
		out.append(ms(a, 0.5))
	return out
