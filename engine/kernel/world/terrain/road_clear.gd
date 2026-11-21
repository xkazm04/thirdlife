extends RefCounted
## Day of 21 Nov 2026 (lane L6, crisp-harden; the owner: "continue with open items to harden"): the scatter keeps its
## objects off the roads by the terrain's `road_dist`, which is the distance of the nearest 3 m grid vertex to the
## nearest 2 m road sample. That is up to about 2 m wrong, so a bush or a grass tuft could stand on the road's edge or
## across crisp's rails (the night's L1 found a bush 1.8 m onto the road of the wf_feel village; it had made it
## walk-through, and it was still drawn there).
## `keep_off` is asked after an object kind is placed: an instance's foot must stay off every road's surface, by the
## exact distance to the road's line (each road by its own half width), and, for solid things in a look with road
## rails, off the main road's verge and its row of rails too. A solid one that does not is moved out, grass is left
## out. It draws nothing from any random stream, so every other object of the scatter stands where it stood.
##   var clear := RoadClear.new(terr.roads, TLStyle.num("detail", "road_rails", 0.0), terr)
##   bushes = clear.keep(bushes, TLKitNature.bush(300, 1.0), true)        # the mesh the bushes are drawn with

const CELL: float = 8.0
const FOOT_H: float = 1.2       # metres: a mesh's foot is what it has lower than this (a tree's trunk, not its crown)
const RAIL_W: float = 0.15      # the row's half thickness past `road_rails` (posts 0.17 m, rails 0.15 m)
const NUDGE: float = 3.5        # metres: the furthest a solid thing is moved out

var _cells: Dictionary = {}     # Vector2i -> [[a, b, half, main], ...]
var _reach: float = 0.0         # the widest half (+ verge) of any road
var _terr: RefCounted = null    # the village terrain (gy): where a moved thing stands
var verge: float = 0.0          # metres past the main road's edge that solid things keep clear of (crisp: to its rails)
var dropped: int = 0            # instances left out
var moved: int = 0              # solid instances moved off the road


## `roads`: village_terrain.gd `roads` ([{pts, half}, ...], the main road first, then the spurs); `rails`: the look's
## `detail.road_rails` (0 = no rails: only the road's surface is kept clear); `terr`: the terrain a moved thing stands
## on (null: nothing is moved, it is left out).
func _init(roads: Array, rails: float = 0.0, terr: RefCounted = null) -> void:
	_terr = terr
	verge = rails + RAIL_W if rails > 0.0 else 0.0
	for k: int in roads.size():
		var pts: PackedVector2Array = (roads[k] as Dictionary)["pts"]
		var half: float = float((roads[k] as Dictionary)["half"])
		_reach = maxf(_reach, half + (verge if k == 0 else 0.0))
		for i: int in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			for cx: int in range(floori(minf(a.x, b.x) / CELL), floori(maxf(a.x, b.x) / CELL) + 1):
				for cz: int in range(floori(minf(a.y, b.y) / CELL), floori(maxf(a.y, b.y) / CELL) + 1):
					var key: Vector2i = Vector2i(cx, cz)
					if not _cells.has(key):
						_cells[key] = []
					(_cells[key] as Array).append([a, b, half, k == 0])


## [the smallest gap between a foot of radius `r` at `p` and a road's surface (solid: and the main road's verge and
## rails; below 0 it stands on it), the way out (from that road's line through `p`)].
func gap(p: Vector2, r: float, solid: bool) -> Array:
	var span: int = ceili((_reach + r) / CELL)
	var k: Vector2i = Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var best: float = INF
	var out: Vector2 = Vector2.ZERO
	for dx: int in range(-span, span + 1):
		for dz: int in range(-span, span + 1):
			for s: Array in _cells.get(k + Vector2i(dx, dz), []):
				var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, s[0], s[1])
				var g: float = q.distance_to(p) - r - float(s[2]) - (verge if solid and bool(s[3]) else 0.0)
				if g < best:
					best = g
					out = (p - q).normalized()
	return [best, out]


## The instances of `xs` whose foot (`foot_r` x their scale) keeps clear; `solid`: a thing that stops a walker or that
## a rail would be drawn through (trees, rocks, bushes), against grass (left out where it is not clear). A solid thing
## that is not clear is moved straight out from the road until it is (at most `NUDGE` m, as high on the land as it
## stood), so the roadside keeps its bushes: behind the rails, not across them. One a move cannot clear is left out.
func keep_off(xs: Array, foot_r: float, solid: bool) -> Array:
	if _cells.is_empty():
		return xs
	var out: Array = []
	for x: Transform3D in xs:
		var p: Vector2 = Vector2(x.origin.x, x.origin.z)
		var r: float = foot_r * x.basis.get_scale().x
		var g: Array = gap(p, r, solid)
		if float(g[0]) >= 0.0:
			out.append(x)
			continue
		var to: Vector2 = p + (g[1] as Vector2) * (0.05 - float(g[0]))
		if not solid or _terr == null or -float(g[0]) > NUDGE or float(gap(to, r, solid)[0]) < 0.0:
			dropped += 1
			continue
		var lift: float = x.origin.y - float(_terr.call("gy", p.x, p.y))
		out.append(Transform3D(x.basis, Vector3(to.x, float(_terr.call("gy", to.x, to.y)) + lift, to.y)))
		moved += 1
	return out


## `keep_off` with the foot of the kit mesh `mk` the instances draw (or `min_r`, a collider's radius, when wider).
func keep(xs: Array, mk: TLMesh, solid: bool, min_r: float = 0.0) -> Array:
	return keep_off(xs, maxf(foot(mk), min_r), solid)


## The widest point of a kit mesh's foot (its vertices lower than `FOOT_H`), in its own frame.
static func foot(mk: TLMesh) -> float:
	var r: float = 0.0
	for v: Vector3 in mk.all_points():
		if v.y < FOOT_H:
			r = maxf(r, Vector2(v.x, v.z).length())
	return r
