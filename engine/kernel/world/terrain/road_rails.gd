extends RefCounted
## Day of 20 Nov 2026 (lane cel-fable; the Director's word of 14:35): a row of rails along both sides of the main road,
## as board 2 shows. One function, called once from landscape.gd `build`, and only for a style that names
## `detail.road_rails` (metres from the road's edge to the row; absent or 0 = no rails: today's landscape, so classic
## and diorama are untouched).
##
## Presentation only. No collider is made: the visitor and every game collide with exactly what they did before, so
## no hash can move. It draws nothing from the landscape's random stream (posts stand at fixed steps along the road),
## so the scatter that follows is the same with and without it.
## Gaps: on the spur's side at every spur mouth, both sides at the bridge, wherever a plot or a lot reaches the row,
## at the river, and one open span in every `PASS_EVERY` so a walker always has a way through nearby.

const Felt: GDScript = preload("res://kits/tl_felt.gd")              # diorama day (dio-fable): under a style with felt nature
const Strew: GDScript = preload("res://kits/tl_felt_strew.gd")      # the row is turned posts and round rails with grain
const POST_GAP: float = 2.6        # metres between posts
const PASS_EVERY: int = 9          # every ninth span stays open
const POST_H: float = 1.25
const RAIL_H: Array = [0.50, 0.98]
## A rail is 0.15 m tall and a post 0.17 m wide: at 1080 lines and the visitor's lens (75 degrees) that is one pixel at
## about 105 m and 120 m. Thinner than a pixel they would flicker as the eye moves, so the row is cut into pieces of `CHUNK` spans
## (about 31 m) and a piece is not drawn when its middle is further than `SEEN_M` (+ `SEEN_MARGIN` before it returns).
const CHUNK: int = 12
const SEEN_M: float = 108.0
const SEEN_MARGIN: float = 8.0


## `main_path`: the main road (TLKitPath, 2 m samples); `half`: its half width; `spur_paths`: landscape.gd's
## [index, TLKitPath, ys] per spur (a spur ends on the main road); `bridge_a`..`bridge_b`: the bridge's samples (-1 = none);
## `centres`, `rad`: plots and lots. Adds MeshInstance3D nodes "WorldRoadRails<n>" to `parent` (one per piece of a row);
## returns the metres of rail.
static func build(parent: Node3D, terr: RefCounted, main_path: TLKitPath, half: float, spur_paths: Array, bridge_a: int, bridge_b: int,
		centres: Array, rad: Array, off: float) -> float:
	if main_path == null or off <= 0.0 or main_path.pts.size() < 4:
		return 0.0
	var pts: PackedVector2Array = main_path.pts
	var metres: float = 0.0
	# where a spur leaves the road, and to which side (+1 left of the direction of travel, -1 right)
	var mouths: Array = []
	for sp: Array in spur_paths:
		var spp: TLKitPath = sp[1]
		var j: Vector2 = spp.pts[spp.pts.size() - 1]
		var best: int = 0
		for q: int in pts.size():
			if pts[q].distance_squared_to(j) < pts[best].distance_squared_to(j):
				best = q
		var t0: Vector2 = (pts[mini(best + 1, pts.size() - 1)] - pts[maxi(best - 1, 0)]).normalized()
		mouths.append([j, signf(t0.orthogonal().dot(spp.pts[0] - j))])
	for hand: float in [-1.0, 1.0]:
		var run: PackedVector3Array = PackedVector3Array()     # the posts of the row that is being walked
		var walked: float = POST_GAP                           # metres since the last post
		for i: int in range(1, pts.size() - 1):
			walked += pts[i].distance_to(pts[i - 1])
			if walked < POST_GAP:
				continue
			walked = 0.0
			var tang: Vector2 = (pts[i + 1] - pts[i - 1]).normalized()
			var p: Vector2 = pts[i] + tang.orthogonal() * hand * (half + off)
			var open: bool = bridge_a >= 0 and i >= bridge_a - 3 and i <= bridge_b + 3
			for m: Array in mouths:
				open = open or (float(m[1]) == hand and pts[i].distance_to(m[0]) < half * 0.8 + 3.2)
			for k: int in centres.size():
				open = open or p.distance_to(centres[k]) < float(rad[k]) + 2.0
			open = open or float(terr.call("river_dist", p.x, p.y)) < 9.0 or not bool(terr.call("inside", p.x, p.y, 6.0))
			if open:
				metres += _row(parent, run)
				run = PackedVector3Array()
			else:
				run.append(Vector3(p.x, float(terr.call("gy", p.x, p.y)) - 0.05, p.y))
		metres += _row(parent, run)
	return snappedf(metres, 0.1)


## One unbroken row: its posts, and two rails from post to post (every `PASS_EVERY`th span left open), in pieces of
## `CHUNK` spans. A row of one post is not drawn (a post alone between two gaps). Returns the metres of rail.
static func _row(parent: Node3D, run: PackedVector3Array) -> float:
	if run.size() < 2:
		return 0.0
	var metres: float = 0.0
	for from: int in range(0, run.size() - 1, CHUNK):
		var to: int = mini(from + CHUNK, run.size() - 1)
		var mk: TLMesh = TLMesh.new(41)
		var felt: bool = Felt.enabled()
		for k: int in range(from, to + 1):
			if k > from or from == 0:      # the post two pieces share is drawn once
				if felt:
					Strew.fence_post(mk, run[k])
				else:
					mk.bar(run[k], run[k] + Vector3(0, POST_H, 0), 0.17, 0.17, "wood_dark", Color.WHITE, 0.02)
			if k > from and k % PASS_EVERY != 0:
				if felt:
					Strew.fence_rails(mk, run[k - 1], run[k], RAIL_H)
				else:
					for h: float in RAIL_H:
						mk.bar(run[k - 1] + Vector3(0, h, 0), run[k] + Vector3(0, h, 0), 0.10, 0.15, "wood", Color.WHITE, 0.01)
				metres += run[k - 1].distance_to(run[k])
		var mi: MeshInstance3D = mk.instance("WorldRoadRails%d" % parent.get_child_count())
		mi.visibility_range_end = SEEN_M
		mi.visibility_range_end_margin = SEEN_MARGIN
		parent.add_child(mi)
	return metres
