extends RefCounted
## M5 (spark world-sandbox, lane P; lane L's plant tool calls it): the trees and bushes a scatter brush stroke writes,
## as seeded `put` ops of the pieces layer (contracts/BUILD.md "Milestone 5": "Trees and bushes are put ops (the scatter
## brush writes one seeded put per tree)"). Static, no state; it reads the Home (`build`: home_build.gd) and never
## writes it: the caller applies the ops as one batch (one undo).
##   var ops: Array = PlantScatter.scatter(build, centre, 6.0, "tree", 4.0, seed)    # then build.apply(ops)
## Returns put ops `{"op": "put", "at": [x, y, z], "part": "tree" | "bush", "params"?: {...}, "rot": 0..3, "seed": n}`
## (no v, author or batch), each one the pieces layer takes now, for a disc of `radius_m` round `centre` at
## `per_100m2` plants per 100 m2. Points are thrown at random in the disc (Poisson-ish: no two closer than SPACING of
## the mean gap), from a generator seeded by the arguments, never the clock: the same arguments give the same ops.
## A point is skipped where the ground is protected for plants (protect.gd `refusal_area(cell, "plant")`: the village,
## lots, lanes, the river band, structures, blocks, pieces), in the water layer's water (`water_runs`), steeper than
## 35 degrees, on a path or within 1 m of one, where its footprint meets another plant of the stroke, or where the
## pieces layer refuses the put (blocks, pieces, a valley tree, the visitor). Trees take a few looks only, so their
## prototypes are shared (piece_catalog.gd: the op's seed picks one of 4 shapes): pine or broadleaf, 7, 9 or 12 m
## tall; bushes 0.7, 0.9 or 1.2 m round. Fewer plants than asked come back where the ground does not take them.

const Catalog := preload("res://kernel/world/build/piece_catalog.gd")
const KINDS := ["tree", "bush"]
const SPACING := 0.7                     # of the mean gap sqrt(100 / per_100m2): the least distance between two plants
const TRIES := 30                        # points thrown per plant asked
const STEEP_DEG := 35.0
const PATH_MARGIN := 1.0
const TREE_HEIGHTS := [7.0, 9.0, 12.0]
const TREE_SPECIES := ["pine", "broadleaf"]
const BUSH_SIZES := [0.7, 0.9, 1.2]
const MAX_PLANTS := 400                  # one stroke at most


static func scatter(build: RefCounted, centre: Vector3, radius_m: float, kind: String, per_100m2: float, seed: int) -> Array:
	if build == null or not (kind in KINDS) or radius_m <= 0.0 or per_100m2 <= 0.0:
		return []
	var pieces: RefCounted = build.layer("pieces")
	var land: RefCounted = build.layer("land")
	var paths: RefCounted = build.layer("paths")
	var protect: RefCounted = build.get("protect")
	if pieces == null:
		return []
	var area := PI * radius_m * radius_m
	var want := mini(MAX_PLANTS, roundi(per_100m2 * area / 100.0))
	if want <= 0:
		return []
	var gap := sqrt(100.0 / per_100m2) * SPACING
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, kind, snappedf(centre.x, 0.01), snappedf(centre.z, 0.01), snappedf(radius_m, 0.01), snappedf(per_100m2, 0.001)])
	var water := _water(build, centre, radius_m)
	var cell := maxf(gap, 0.5)
	var grid := {}                           # Vector2i (cells of `cell` m) -> [Vector2, ...] accepted points
	var taken := {}                          # Vector2i column -> true: the stroke's footprints
	var out := []
	var cos_steep := cos(deg_to_rad(STEEP_DEG))
	if land != null:
		land.begin_asking(Rect2(centre.x - radius_m - 6.0, centre.z - radius_m - 6.0, 2.0 * radius_m + 12.0, 2.0 * radius_m + 12.0))
	for t: int in want * TRIES:
		if out.size() >= want:
			break
		# every draw of a try is made up front, so the sequence does not depend on what was skipped
		var a := rng.randf() * TAU
		var r := radius_m * sqrt(rng.randf())
		var rot := rng.randi_range(0, 3)
		var sd := rng.randi_range(0, 999999)
		var look_a := rng.randi_range(0, 1)
		var look_b := rng.randi_range(0, 2)
		var q := Vector2(centre.x + cos(a) * r, centre.z + sin(a) * r)
		if _crowded(grid, q, gap, cell):
			continue
		var col := Vector2i(floori(q.x), floori(q.y))
		if water.has(col):
			continue
		var y := float(land.height_at(q.x, q.y)) if land != null else centre.y
		if land != null:
			var gx := float(land.height_at(q.x + 0.5, q.y)) - float(land.height_at(q.x - 0.5, q.y))
			var gz := float(land.height_at(q.x, q.y + 0.5)) - float(land.height_at(q.x, q.y - 0.5))
			if Vector3(-gx, 1.0, -gz).normalized().y < cos_steep:
				continue
		if paths != null and paths.has_method("covers") and bool(paths.call("covers", q.x, q.y, PATH_MARGIN)):
			continue
		if protect != null and str(protect.refusal_area(Rect2(col.x, col.y, 1.0, 1.0), "plant")) != "":
			continue
		var op := {"op": "put", "at": [col.x, floori(y), col.y], "part": kind}
		var params := {}
		if kind == "tree":
			params = {"species": TREE_SPECIES[look_a], "height": TREE_HEIGHTS[look_b]}
		else:
			params = {"size": BUSH_SIZES[look_b]}
		params = Catalog.trimmed(kind, params)
		if not params.is_empty():
			op["params"] = params
		op["rot"] = rot
		op["seed"] = sd
		var fp: Array = pieces.footprint_of(op)
		if fp.is_empty() or _overlaps(taken, fp[0], fp[1]):
			continue
		if str(pieces.can_apply(op)) != "":
			continue
		for z: int in range((fp[0] as Vector3i).z, (fp[1] as Vector3i).z + 1):
			for x: int in range((fp[0] as Vector3i).x, (fp[1] as Vector3i).x + 1):
				taken[Vector2i(x, z)] = true
		var gk := Vector2i(floori(q.x / cell), floori(q.y / cell))
		if not grid.has(gk):
			grid[gk] = []
		(grid[gk] as Array).append(q)
		out.append(op)
	if land != null:
		land.end_asking()
	return out


static func _crowded(grid: Dictionary, q: Vector2, gap: float, cell: float) -> bool:
	var k := Vector2i(floori(q.x / cell), floori(q.y / cell))
	var reach := ceili(gap / cell)
	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			for o: Vector2 in grid.get(k + Vector2i(dx, dz), []):
				if o.distance_to(q) < gap:
					return true
	return false


static func _overlaps(taken: Dictionary, lo: Vector3i, hi: Vector3i) -> bool:
	for z: int in range(lo.z, hi.z + 1):
		for x: int in range(lo.x, hi.x + 1):
			if taken.has(Vector2i(x, z)):
				return true
	return false


## The columns (x, z) of the water layer's water in the disc's box (its `water_runs`; none while it is a stub).
static func _water(build: RefCounted, centre: Vector3, radius_m: float) -> Dictionary:
	var out := {}
	var w: RefCounted = build.layer("water")
	if w == null or not w.has_method("water_runs"):
		return out
	var lo := Vector3i(floori(centre.x - radius_m), -16, floori(centre.z - radius_m))
	var hi := Vector3i(ceili(centre.x + radius_m), 111, ceili(centre.z + radius_m))
	var runs: Variant = w.call("water_runs", lo, hi)
	if typeof(runs) != TYPE_ARRAY:
		return out
	for s: Variant in runs:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		for run: Variant in (s as Dictionary).get("runs", []):
			if typeof(run) == TYPE_ARRAY and (run as Array).size() == 3:
				for x: int in range(int(run[1]), int(run[2]) + 1):
					out[Vector2i(x, int(run[0]))] = true
	return out
