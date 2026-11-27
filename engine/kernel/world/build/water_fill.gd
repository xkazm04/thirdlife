extends RefCounted
## M5 lane W (spark world-sandbox): the pour's fill (contracts/BUILD.md "Milestone 5": "from the clicked cell it floods
## 4-neighbour cells up to just under the spill level, the lowest rim the water would cross"). Static, pure: it reads
## lattice heights through a callable and nothing else (no scene, no clock, no random), so the same land gives the same
## fill. The layer (water_layer.gd) checks protection and the river on the result.
##
## How (a priority flood on the 3 m land lattice, the surface the land layer draws):
##   1. From the clicked cell's lowest corner the water runs downhill (steepest of the 8 neighbours, strictly lower) to
##      a low point, at most DESCENT steps; a slope that keeps falling is "no hollow here".
##   2. From the low point the flood takes the lowest vertex next to what it holds (a min-heap) and keeps the highest
##      one taken, `w`. The first vertex taken below `w` is the far side of the rim: the water would cross at `w`, the
##      spill level. Vertices are joined to their 8 neighbours: the land's triangles join a cell's corners along one
##      diagonal, and water leaks along it; joining both diagonals can only find a LOWER spill, so the water never
##      stands above a gap it would run out of (a leak would show as a blocky edge where the quads end over lower land).
##   3. The level is the spill minus UNDER_CM (and what the wheel lowered). The wet vertices are those taken below the
##      level (a prefix: the heights taken rise until the rim). The water cells are the 3 m cells with a wet corner:
##      every cell where the land dips below the level, so the depth shore draws the waterline inside them.
##   A flood that takes PLATEAU_RUN vertices in a row within PLATEAU_CM of each other has reached a plateau round the
##   hollow (flat ground, a flattened terrace): the plateau is the spill (and a plateau at the low point itself, flat
##   ground everywhere, is "no hollow here"). One that takes EXPLORE vertices still rising is a basin too big to fill:
##   "spills: too big". So is a fill of CAP cells or more.

const CAP := 2048                        # water cells a fill must stay under (contracts/BUILD.md)
const EXPLORE := 2600                    # vertices the flood takes at most
const DESCENT := 64                      # downhill steps from the click to its low point (192 m)
const UNDER_CM := 10                     # the level stands this far under the spill
const PLATEAU_CM := 2
const PLATEAU_RUN := 256                 # level vertices in a row that make a plateau (2,300 m2)
const NO_HOLLOW := "no hollow here: dig one first"
const TOO_BIG := "spills: too big"
const N8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]
const OFF := 131072                      # heap key: (h + OFF) << 36 | (x + OFF) << 18 | (y + OFF)


## The fill from 3 m cell `start`. `h`: (Vector2i vertex) -> int cm, the land's height there now. `lower_cm`: how far
## under the highest level the person asked for. Returns {"reason": "" or why, "cells": [Vector2i, ...] sorted by j
## then i, "level", "spill", "floor" (cm), "verts" (wet vertices), "explored", "bottom": Vector2i}.
static func fill(h: Callable, start: Vector2i, lower_cm := 0) -> Dictionary:
	var hc := {}
	var at := func(v: Vector2i) -> int:
		if not hc.has(v):
			hc[v] = int(h.call(v))
		return hc[v]
	var out := {"reason": "", "cells": [], "level": 0, "spill": 0, "floor": 0, "verts": 0, "explored": 0, "bottom": start}
	# 1. downhill to a low point
	var b := start
	for o: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		if int(at.call(start + o)) < int(at.call(b)):
			b = start + o
	var steps := 0
	while true:
		var next := b
		for o: Vector2i in N8:
			if int(at.call(b + o)) < int(at.call(next)):
				next = b + o
		if next == b:
			break
		b = next
		steps += 1
		if steps > DESCENT:
			out.reason = NO_HOLLOW
			return out
	out.bottom = b
	out.floor = int(at.call(b))
	# 2. the priority flood from the low point
	var heap := Heap.new()
	var seen := {b: true}
	heap.push(int(at.call(b)), b)
	var w: int = at.call(b)
	var taken: Array = []                # [Vector2i, cm] in the order taken (rising)
	var rim := false
	var base := w                        # where the current run of level ground began
	var run := 0                         # vertices taken since the heights last rose more than PLATEAU_CM
	while not heap.is_empty():
		var k := heap.pop()
		var hv := int(k >> 36) - OFF
		var v := Vector2i(int((k >> 18) & 0x3FFFF) - OFF, int(k & 0x3FFFF) - OFF)
		if hv < w:
			rim = true
			break
		w = maxi(w, hv)
		taken.append([v, hv])
		if hv > base + PLATEAU_CM:
			base = hv
			run = 0
		run += 1
		if run >= PLATEAU_RUN or taken.size() >= EXPLORE:
			break
		for o: Vector2i in N8:
			var u: Vector2i = v + o
			if not seen.has(u):
				seen[u] = true
				heap.push(int(at.call(u)), u)
	out.explored = taken.size()
	if not rim:
		if run < PLATEAU_RUN:
			out.reason = TOO_BIG
			return out
		if base - int(out.floor) <= PLATEAU_CM:
			out.reason = NO_HOLLOW
			return out
	out.spill = w
	var level := w - UNDER_CM - maxi(0, lower_cm)
	out.level = level
	# 3. the wet vertices and their cells
	var cells := {}
	var wet := 0
	for e: Array in taken:
		if int(e[1]) >= level:
			break
		wet += 1
		var v: Vector2i = e[0]
		for c: Vector2i in [v, v - Vector2i(1, 0), v - Vector2i(0, 1), v - Vector2i(1, 1)]:
			cells[c] = true
	out.verts = wet
	if wet == 0:
		out.reason = NO_HOLLOW if lower_cm <= 0 else "no water at that level: raise it (wheel up)"
		return out
	if cells.size() >= CAP:
		out.reason = TOO_BIG
		return out
	var list: Array = cells.keys()
	list.sort_custom(func(a: Vector2i, c: Vector2i) -> bool: return a.y < c.y or (a.y == c.y and a.x < c.x))
	out.cells = list
	return out


# ------------------------------------------------------------------ a binary min-heap of int64 keys
class Heap extends RefCounted:
	var a := PackedInt64Array()

	func is_empty() -> bool:
		return a.is_empty()

	func push(hv: int, v: Vector2i) -> void:
		a.append(((clampi(hv, -OFF + 1, OFF - 1) + OFF) << 36) | ((v.x + OFF) << 18) | (v.y + OFF))
		var i := a.size() - 1
		while i > 0:
			var p := (i - 1) >> 1
			if a[p] <= a[i]:
				break
			var t := a[p]
			a[p] = a[i]
			a[i] = t
			i = p

	func pop() -> int:
		var top := a[0]
		var last := a[a.size() - 1]
		a.resize(a.size() - 1)
		if a.is_empty():
			return top
		a[0] = last
		var i := 0
		var n := a.size()
		while true:
			var l := 2 * i + 1
			var r := l + 1
			var m := i
			if l < n and a[l] < a[m]:
				m = l
			if r < n and a[r] < a[m]:
				m = r
			if m == i:
				break
			var t := a[m]
			a[m] = a[i]
			a[i] = t
			i = m
		return top
