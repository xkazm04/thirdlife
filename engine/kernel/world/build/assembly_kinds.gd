extends RefCounted
## M6 round 3, lane A6 (27 Nov 2026): the six assembly kinds of contracts/BUILD.md "Assemblies (M6, round 3)", each
## written in the local frame of assembly.gd's Shape `s` (x along the front, z away from it, y up from `at`, whose cell
## holds the floor row, the ground under it). Walkable by construction where a kind says so (selftest 794 walks each at
## three sizes and four rots with command_space.gd's estimate and a stricter walker that never jumps):
##   wall      cubes w x h at z 0; opts.door: the door cell's sill stays, the 2 cells over it open, a slab step each side;
##             opts.windows: a window every N cells in row 1; opts.crenels: merlons (trim) on every other cell on top
##   tower     a floor (row 0), walls 1 thick w x w x h with trim corners, a top floor (row h-1, the walk on top);
##             opts.door (default the middle of the front when the stairs are inside), a slab step out of it;
##             opts.windows every N cells in rows 2, 6, 10, ...; opts.crenels merlons on top (a gap where outside
##             stairs arrive); opts.stairs "outside": a stair (trim) round the walls from the ground by the door to the
##             top, a landing at each corner and after every 6 steps; "inside": the same round the inner ring from the
##             floor by the door, the top floor opened over the last turn (the hatch)
##             (round 3) outside stairs: a stringer of trim on the outer side at each stair's level, a slab-high
##             parapet at each landing, a fence on each; nothing to the ground (the door's front stays open)
##   house     a floor, walls w x d x h, a door in the middle of the front with a slab step, windows in row 2 (the
##             front: opts.windows of them beside the door, default 2 cells either side then every 3 (round 4); the
##             other walls every 3), a pitched roof (trim)
##             of roof blocks rising from the two long walls to a ridge (a ridge row of cubes when the span is odd),
##             gables of the wall's material
##   stair     w wide, h steps climbing +z, each step a stair block on a cube (trim) under it, a landing every 6 steps
##   bridge    a deck w x d at y 0 (mat), fence railings (trim) on its two long edges when w >= 3, piers (trim) every 6
##             cells along both edges down to the ground or bed, and steps at both ends down to the ground (each on a
##             solid fill to its column's ground)
##   platform  a floor w x d at y 0 (mat), a fence railing round it (trim) with an opening in the middle of the front
##             when w and d >= 3, posts (trim) at the corners and every 6 cells along the edges down to the ground
## Deterministic: integer loops in a fixed order, no randomness; the ground is read through `s.gnd(x, z)`.

const Blocks := preload("res://kernel/world/build/blocks.gd")
const DIRS := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]   # local rot -> where a stair rises
const LANDING_EVERY := 6
const STEPS_MAX := 32                   # a bridge end's steps at most (deeper ground: the space check says so)
const DEPTH_MAX := 48                   # a pier, a post or a fill reaches at most this far down
const RAIL_MIN := 3                     # a railing needs a lane of 1 between two rails
const SPAN := 6                         # piers and posts every SPAN cells


static func build(s: RefCounted) -> void:
	match str(s.kind):
		"wall": wall(s)
		"tower": tower(s)
		"house": house(s)
		"stair": stair(s)
		"bridge": bridge(s)
		"platform": platform(s)


static func rot_to(dir: Vector2i) -> int:
	return DIRS.find(dir)


# ------------------------------------------------------------------ wall
static func wall(s: RefCounted) -> void:
	var w: int = s.w
	var h: int = s.h
	for y in h:
		for x in w:
			s.put(x, y, 0, Blocks.CUBE, s.mat)
	var door := int(s.opts.get("door", -1))
	if s.opts.has("windows"):
		var n := int(s.opts.windows)
		for x in range(1, w - 1):
			if posmod(x - w / 2, n) == 0 and (door < 0 or absi(x - door) > 1):
				s.put(x, 1, 0, Blocks.WINDOW, s.mat, 0)
	if door >= 0:
		s.cut(door, 1, 0)
		s.cut(door, 2, 0)
		s.put(door, 0, -1, Blocks.SLAB, s.trim)
		s.put(door, 0, 1, Blocks.SLAB, s.trim)
	if s.opts.has("crenels"):
		for x in w:
			if (x % 2 == 0 or x == w - 1) and s.has(x, h - 1, 0):     # none over a door that opens to the top
				s.put(x, h, 0, Blocks.CUBE, s.trim)


# ------------------------------------------------------------------ tower
static func tower(s: RefCounted) -> void:
	var w: int = s.w
	var h: int = s.h
	var stairs := str(s.opts.get("stairs", ""))
	var door := int(s.opts.get("door", w / 2 if stairs == "inside" else -1))
	for y in h:
		for z in w:
			for x in w:
				var ex := x == 0 or x == w - 1
				var ez := z == 0 or z == w - 1
				if ex or ez:
					s.put(x, y, z, Blocks.CUBE, s.trim if ex and ez else s.mat)
				elif y == 0 or y == h - 1:
					s.put(x, y, z, Blocks.CUBE, s.mat)
	if s.opts.has("windows"):
		var n := int(s.opts.windows)
		for y in range(2, h - 2, 4):
			for t in range(1, w - 1):
				if posmod(t - w / 2, n) != 0:
					continue
				if not (door >= 0 and absi(t - door) <= 1 and y < 4):
					s.put(t, y, 0, Blocks.WINDOW, s.mat, 0)
				s.put(t, y, w - 1, Blocks.WINDOW, s.mat, 0)
				s.put(0, y, t, Blocks.WINDOW, s.mat, 1)
				s.put(w - 1, y, t, Blocks.WINDOW, s.mat, 1)
	if door >= 0:
		s.cut(door, 1, 0)
		s.cut(door, 2, 0)
		s.put(door, 0, -1, Blocks.SLAB, s.trim)
	var gap := Vector2i(-1, -1)              # the wall cell outside stairs arrive on (no merlon there)
	if stairs == "outside":
		gap = _outside_stairs(s, door if door >= 0 else w / 2)
	elif stairs == "inside":
		_inside_stairs(s, door)
	if s.opts.has("crenels"):
		for z in w:
			for x in w:
				var ex := x == 0 or x == w - 1
				var ez := z == 0 or z == w - 1
				if (ex or ez) and ((ex and ez) or (x + z) % 2 == 0) and Vector2i(x, z) != gap:
					s.put(x, h, z, Blocks.CUBE, s.trim)


## The ring of cells round the square lo..hi (inclusive), in walk order from (lo, lo): +x, +z, -x, -z. Its corners.
static func ring(lo: int, hi: int) -> Array:
	var out := []
	for x in range(lo, hi):
		out.append(Vector2i(x, lo))
	for z in range(lo, hi):
		out.append(Vector2i(hi, z))
	for x in range(hi, lo, -1):
		out.append(Vector2i(x, hi))
	for z in range(hi, lo, -1):
		out.append(Vector2i(lo, z))
	return out


## Climbs along `path` (a closed ring of local (x, z) cells in walk order) from index `start` at feet level `f0` up to
## level `top`: a stair (rising toward the next cell) in each straight cell, the level +1; a landing (a cube just under
## the level; none on the ground, level 0) at each corner of the ring and after every LANDING_EVERY stairs in a row.
## Returns {"cells": [[Vector2i, feet cell y, "stair" | "landing"]], "next": the index after the last stair}.
static func climb(s: RefCounted, path: Array, corners: Dictionary, start: int, f0: int, top: int, m: int) -> Dictionary:
	var out := []
	var f := f0
	var run := 0
	var i := start
	var n := path.size()
	var guard := n * (top - f0 + 2)
	while f < top and guard > 0:
		guard -= 1
		var c: Vector2i = path[posmod(i, n)]
		var nx: Vector2i = path[posmod(i + 1, n)]
		if corners.has(c) or run >= LANDING_EVERY:
			if f >= 1:
				s.put(c.x, f - 1, c.y, Blocks.CUBE, m)
			out.append([c, f, "landing"])
			run = 0
		else:
			s.put(c.x, f, c.y, Blocks.STAIR, m, rot_to(nx - c))
			out.append([c, f, "stair"])
			f += 1
			run += 1
		i += 1
	return {"cells": out, "next": i}


## Outside stairs: round the ring one cell out from the walls, from the ground just past the door's step to the wall
## top, then a landing beside the wall; returns the wall cell they arrive on (its merlon is left out). Round 3 (the
## Director's Q-A5, after the body fell off at a run): on the outer side of every stair a cube of trim at the stair's
## level (a stringer: its top is the stair's top), and of every landing a slab-high parapet (a slab on a cube), at the
## corners on both outer sides and the diagonal, each with a fence on top (without it the stringer's tops were a second
## stair of 1 m steps that the estimate and the body took). Nothing reaches the ground: the door's front stays open.
static func _outside_stairs(s: RefCounted, door: int) -> Vector2i:
	var w: int = s.w
	var path := ring(-1, w)
	var corners := {Vector2i(-1, -1): true, Vector2i(w, -1): true, Vector2i(w, w): true, Vector2i(-1, w): true}
	var c := climb(s, path, corners, path.find(Vector2i(door, -1)) + 1, 0, int(s.h), s.trim)
	var i: int = c.next
	var at: Vector2i = path[posmod(i, path.size())]
	var cells: Array = c.cells
	for k in 4:
		at = path[posmod(i + k, path.size())]
		s.put(at.x, int(s.h) - 1, at.y, Blocks.CUBE, s.trim)
		cells.append([at, int(s.h), "landing"])
		if not corners.has(at):
			break
	for e: Array in cells:
		var f: int = e[1]
		for o: Vector2i in _outside_of(e[0], w):
			if e[2] == "stair":
				s.put(o.x, f, o.y, Blocks.CUBE, s.trim)
				s.put(o.x, f + 1, o.y, Blocks.FENCE, s.trim)  # a rail on it: the stringer is no second stair
			elif f >= 1:
				s.put(o.x, f - 1, o.y, Blocks.CUBE, s.trim)
				s.put(o.x, f, o.y, Blocks.SLAB, s.trim)
				s.put(o.x, f + 1, o.y, Blocks.FENCE, s.trim)
	return Vector2i(clampi(at.x, 0, w - 1), clampi(at.y, 0, w - 1))


## The cells just outside ring cell `c` of a tower `w` wide (one side; a corner: both sides and the diagonal).
static func _outside_of(c: Vector2i, w: int) -> Array:
	var dx := -1 if c.x < 0 else (1 if c.x >= w else 0)
	var dz := -1 if c.y < 0 else (1 if c.y >= w else 0)
	var out := []
	if dx != 0:
		out.append(c + Vector2i(dx, 0))
	if dz != 0:
		out.append(c + Vector2i(0, dz))
	if dx != 0 and dz != 0:
		out.append(c + Vector2i(dx, dz))
	return out


## Inside stairs: round the inner ring from the floor just past the door's inner cell to the top floor, which is left
## open over every stair or landing whose headroom it would cut (the hatch).
static func _inside_stairs(s: RefCounted, door: int) -> void:
	var w: int = s.w
	var top := int(s.h)
	var path := ring(1, w - 2)
	var corners := {Vector2i(1, 1): true, Vector2i(w - 2, 1): true, Vector2i(w - 2, w - 2): true, Vector2i(1, w - 2): true}
	var c := climb(s, path, corners, path.find(Vector2i(door, 1)) + 1, 1, top, s.trim)
	var roof := top - 1
	for e: Array in c.cells:
		var at: Vector2i = e[0]
		var f: int = e[1]
		var stair: bool = e[2] == "stair"
		var need_hi := f + (3 if stair else 1)       # the cells over the feet a person 1.8 m tall needs empty, and over a
		                                             # stair those his head passes going up to the next (Grid.clear)
		if roof >= f and roof <= need_hi and not (stair and f == roof):
			s.cut(at.x, roof, at.y)


# ------------------------------------------------------------------ house
static func house(s: RefCounted) -> void:
	var w: int = s.w
	var h: int = s.h
	var d: int = s.d
	for y in h:
		for z in d:
			for x in w:
				if y == 0 or x == 0 or z == 0 or x == w - 1 or z == d - 1:
					s.put(x, y, z, Blocks.CUBE, s.mat)
	var door := w / 2
	for t: int in front_windows(w, int(s.opts.get("windows", -1))):
		s.put(t, 2, 0, Blocks.WINDOW, s.mat, 0)
	for t in range(1, w - 1):
		if posmod(t - w / 2, 3) == 0:
			s.put(t, 2, d - 1, Blocks.WINDOW, s.mat, 0)
	for t in range(1, d - 1):
		if posmod(t - d / 2, 3) == 0:
			s.put(0, 2, t, Blocks.WINDOW, s.mat, 1)
			s.put(w - 1, 2, t, Blocks.WINDOW, s.mat, 1)
	s.cut(door, 1, 0)
	s.cut(door, 2, 0)
	s.put(door, 0, -1, Blocks.SLAB, s.mat)
	# the roof: slopes rise from the two long walls (across the short span `n`) to the ridge along the long side
	var along_x := w >= d
	var n := d if along_x else w
	var long := w if along_x else d
	var cell := func(u: int, v: int) -> Vector2i: return Vector2i(u, v) if along_x else Vector2i(v, u)
	var up := 2 if along_x else 3            # the front slope rises toward +v (+z, or +x when the ridge runs along z)
	var down := 0 if along_x else 1
	var k := 0
	while k < n - 1 - k:
		for u in long:
			var a: Vector2i = cell.call(u, k)
			var b: Vector2i = cell.call(u, n - 1 - k)
			s.put(a.x, h + k, a.y, Blocks.ROOF, s.trim, up)
			s.put(b.x, h + k, b.y, Blocks.ROOF, s.trim, down)
		for v in range(k + 1, n - 1 - k):            # the gables under this row of the slopes
			for u: int in [0, long - 1]:
				var g: Vector2i = cell.call(u, v)
				s.put(g.x, h + k, g.y, Blocks.CUBE, s.mat)
		k += 1
	if n % 2 == 1:                                   # an odd span: a ridge row of cubes level with the last slopes
		var y := h + maxi(0, k - 1)
		for u in long:
			var r: Vector2i = cell.call(u, n / 2)
			s.put(r.x, y, r.y, Blocks.CUBE, s.trim)


## The front cells of a house `w` wide that hold its windows: `n` of them (-1: the default by width), nearest the
## door first, left before right: the cells 2, 5, 8 ... from the door (spaced), then 1, 3, 4, 6 ... (filling).
## Default: the spaced ones (round 3's rule: a 7-wide house has 2, either side of the door).
static func front_windows(w: int, n: int) -> Array:
	var door := w / 2
	var spaced := []
	var rest := []
	for k in range(1, w):
		for t: int in [door - k, door + k]:
			if t < 1 or t > w - 2:
				continue
			(spaced if k >= 2 and (k - 2) % 3 == 0 else rest).append(t)
	var order := spaced + rest
	return spaced if n < 0 else order.slice(0, mini(n, order.size()))


# ------------------------------------------------------------------ stair
static func stair(s: RefCounted) -> void:
	var w: int = s.w
	var h: int = s.h
	var z := 0
	for k in h:
		for x in w:
			s.put(x, k, z, Blocks.STAIR, s.mat, 2)
			if k >= 1:
				s.put(x, k - 1, z, Blocks.CUBE, s.trim)
		z += 1
		if (k + 1) % LANDING_EVERY == 0 and k < h - 1:
			for x in w:
				s.put(x, k, z, Blocks.CUBE, s.mat)
			z += 1


# ------------------------------------------------------------------ bridge
static func bridge(s: RefCounted) -> void:
	var w: int = s.w
	var d: int = s.d
	for z in d:
		for x in w:
			s.put(x, 0, z, Blocks.CUBE, s.mat)
	if w >= RAIL_MIN:
		for z in d:
			s.put(0, 1, z, Blocks.FENCE, s.trim)
			s.put(w - 1, 1, z, Blocks.FENCE, s.trim)
	var zs := range(0, d, SPAN)
	if not zs.has(d - 1):
		zs.append(d - 1)
	for z: int in zs:
		for x: int in ([0] if w == 1 else [0, w - 1]):
			_down(s, x, -1, z, Blocks.CUBE)
	_end_steps(s, -1, 2)                     # the near end: steps toward -z, each rising toward the deck (+z)
	_end_steps(s, 1, 0)                      # the far end: toward +z, rising toward -z


## A column of `shape` (trim) from local y `top` down to the ground of column (x, z) (none when the ground is at or over
## `top`), at most DEPTH_MAX cells.
static func _down(s: RefCounted, x: int, top: int, z: int, shape: int) -> void:
	var g: int = s.gnd(x, z)
	for y in range(top, maxi(g, top - DEPTH_MAX + 1) - 1, -1):
		s.put(x, y, z, shape, s.trim)


## Steps from the deck (top at local 1) down one end, toward `dz`: row k at y 1 - k, while the row's highest ground is
## at or under it; each stair on a fill to its own column's ground; the last sits in the ground cell.
static func _end_steps(s: RefCounted, dz: int, lrot: int) -> void:
	var w: int = s.w
	var d: int = s.d
	for k in range(1, STEPS_MAX + 1):
		var z := -k if dz < 0 else d - 1 + k
		var y := 1 - k
		var g := -(1 << 20)
		for x in w:
			g = maxi(g, int(s.gnd(x, z)))
		if y < g:
			return
		for x in w:
			s.put(x, y, z, Blocks.STAIR, s.mat, lrot)
			if int(s.gnd(x, z)) < y:
				_down(s, x, y - 1, z, Blocks.CUBE)
		if y <= g:
			return


# ------------------------------------------------------------------ platform
static func platform(s: RefCounted) -> void:
	var w: int = s.w
	var d: int = s.d
	for z in d:
		for x in w:
			s.put(x, 0, z, Blocks.CUBE, s.mat)
	if w >= RAIL_MIN and d >= RAIL_MIN:
		for z in d:
			for x in w:
				var edge := x == 0 or z == 0 or x == w - 1 or z == d - 1
				if edge and Vector2i(x, z) != Vector2i(w / 2, 0):
					s.put(x, 1, z, Blocks.FENCE, s.trim)
	var xs := range(0, w, SPAN)
	if not xs.has(w - 1):
		xs.append(w - 1)
	var zs := range(0, d, SPAN)
	if not zs.has(d - 1):
		zs.append(d - 1)
	for z: int in zs:
		for x: int in xs:
			if x == 0 or z == 0 or x == w - 1 or z == d - 1:
				_down(s, x, -1, z, Blocks.POST)
