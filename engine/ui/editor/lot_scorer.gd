extends RefCounted
## Placement uses the village's unfitted land and the same road samples and spur as landscape.gd.
const VillageTerrain = preload("res://kernel/world/terrain/village_terrain.gd")
const PAD_EXTRA := 10.5

## Precompute geometry shared by every centre in this sweep. The height cache belongs to this
## particular terrain and Callable. Normal scoring never reuses samples from a previous request.
class Sweep:
	var river_box := Rect2()
	var road_sample_slack := 0.001
	var offsets := PackedVector2Array()
	var samples: Dictionary[Vector2, float] = {}

	func _init(model, disc: PackedVector2Array) -> void:
		var road: PackedVector2Array = model.road_samples
		for i in range(1, road.size()):
			road_sample_slack = maxf(road_sample_slack, 0.5 * road[i].distance_to(road[i-1]) + 0.001)
		if not model.river_samples.is_empty():
			river_box = Rect2(model.river_samples[0], Vector2.ZERO)
			for point: Vector2 in model.river_samples:
				river_box = river_box.expand(point)
			river_box = river_box.grow(model.river_half_m)
		offsets = disc


static func terrain(model, cfg: Dictionary) -> RefCounted:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for lot: Dictionary in model.plots:
		var extent := Vector2.ONE * (float(lot.r) + PAD_EXTRA)
		lo = lo.min(lot.at - extent)
		hi = hi.max(lot.at + extent)
	for p: Vector2 in model.road:
		lo = lo.min(p)
		hi = hi.max(p)
	for p: Vector2 in model.river:
		lo = lo.min(p - Vector2.ONE * 40)
		hi = hi.max(p + Vector2.ONE * 40)
	var cell := float(cfg.get("cell_m", 3))
	var margin := Vector2.ONE * float(cfg.get("margin_m", 110))
	var start := ((lo - margin) / cell).floor() * cell
	var end := ((hi + margin) / cell).ceil() * cell
	var land := VillageTerrain.new(int(cfg.get("seed", 7)), Rect2(start, end - start), cell)
	land.centre = (lo + hi) * 0.5
	land.relief = float(cfg.get("relief", 1.0))
	return land


static func spur(model, at: Vector2, radius: float) -> Dictionary:
	var to: Vector2 = model.road_point(at)
	var gate := at + at.direction_to(to) * (radius + 0.5)
	return {"from": gate, "to": to, "length_m": gate.distance_to(to)}


static func line_distance(p: Vector2, line: PackedVector2Array) -> float:
	var best := INF
	for i in range(1, line.size()):
		best = minf(best, p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p, line[i-1], line[i])))
	return sqrt(best)


static func errors(model, at: Vector2, radius: float, path: Dictionary) -> Array:
	return _errors(model, at, radius, path, _bank(model, at, radius), Rect2())


# A sweep reuses the river's bank-to-bank bounding box. Beyond the 60 m fact range its exact
# distance cannot affect either the verdict or the displayed facts. The spur is checked separately.
static func _bank(model, at: Vector2, radius: float, river_box := Rect2()) -> float:
	var edge: float = model.edge_radius(radius)
	if river_box.has_area() and not river_box.grow(edge + 60).has_point(at):
		return INF
	return line_distance(at, model.river_samples) - edge - float(model.river_half_m)


static func _errors(model, at: Vector2, radius: float, path: Dictionary, bank: float, river_box: Rect2, road_sample_slack := INF) -> Array:
	var out: Array = []
	for lot: Dictionary in model.plots:
		var gap: float = model.lot_gap(at, radius, lot)
		if gap < model.LOT_GAP_M - model.FIT_EPS_M:
			var words := "its edge would cross %s's by %.1f m" % [lot.label, -gap] if gap < 0 else (
				"%.1f m from %s's lot edge (needs %.0f m)" % [gap, lot.label, model.LOT_GAP_M])
			out.append({"level": "error", "what": "overlap", "with": lot.id, "text": words})
		elif _crosses_lot(path, lot.at, model.edge_radius(lot.r)):
			out.append({"level": "error", "what": "path", "with": lot.id, "text": "the path crosses %s's lot" % lot.label})
	# Every point on a road segment lies within half its length of a sampled endpoint.
	# The spur already found the nearest sample. Only borderline rings need the exact segment check.
	var road_clearance: float = model.edge_radius(radius) + model.road_half_m + model.ROAD_GAP_M - model.FIT_EPS_M
	if at.distance_to(path.to) <= road_clearance + road_sample_slack and line_distance(at, model.road_samples) < road_clearance:
		out.append({"level": "error", "what": "road", "text": "keep the lot 1 m off the road edge"})
	var river: PackedVector2Array = model.river_samples
	if bank < model.RING_GAP_M - model.FIT_EPS_M:
		out.append({"level": "error", "what": "river", "text": "keep the lot 2 m off the riverbank"})
	elif path.length_m > 0 and (not river_box.has_area() or river_box.intersects(Rect2(path.from, Vector2.ZERO).expand(path.to), true)):
		for i in range(1, river.size()):
			var pair := Geometry2D.get_closest_points_between_segments(path.from, path.to, river[i-1], river[i])
			if pair[0].distance_to(pair[1]) <= model.river_half_m:
				out.append({"level": "error", "what": "path", "text": "the path crosses the river"})
				break
	if model.road_samples.is_empty():
		out.append({"level": "error", "what": "road", "text": "there is no road to reach"})
	if not model.lot_inside(at, radius):
		out.append({"level": "error", "what": "outside", "text": "its lot edge reaches outside the village"})
	return out


static func _crosses_lot(path: Dictionary, centre: Vector2, radius: float) -> bool:
	return path.length_m > 0 and centre.distance_to(Geometry2D.get_closest_point_to_segment(centre, path.from, path.to)) < radius


static func score(model, at: Vector2, yaw: float, heights: Callable) -> Dictionary:
	return _score(model, at, yaw, heights, model.lot_radius(), false)


static func _score(model, at: Vector2, yaw: float, heights: Callable, radius: float, facts_needed: bool, sweep: Sweep = null) -> Dictionary:
	var path := spur(model, at, radius)
	var lines: Array = []
	var river_box := sweep.river_box if sweep else Rect2()
	var bank := _bank(model, at, radius, river_box)
	var blocked := _errors(model, at, radius, path, bank, river_box, sweep.road_sample_slack if sweep else INF)
	var result := {"at": at, "yaw": yaw, "reason": "", "valid": blocked.is_empty(), "score": 0, "lines": lines, "path": path}
	for problem: Dictionary in blocked:
		lines.append({"text": problem.text, "points": 0})
	if not blocked.is_empty():
		return result
	# Day 19 Nov (lane lead): the walk is paid on every visit, the earthwork once (and the blend lane softens it), so
	# a long walk weighs more than steep ground: 0.5 a metre from 8 to 40 m, then 1 a metre, at most 60; ground 4 a
	# metre over 1.5 m, at most 30. (Round 3's caps of 30 and 36 ranked a 121 m walk above a 17 m one.)
	var walk_m := float(path.length_m)
	var walk_cost := minf(60.0, clampf((walk_m - 8.0) * 0.5, 0, 16) + maxf(0.0, walk_m - 40.0))
	lines.append({"text": "%.0f m walk to the road" % path.length_m, "points": walk_cost})
	var delta := _ground_delta(at, radius + PAD_EXTRA, heights, sweep)
	lines.append({"text": "ground %s %.1f m under the pad" % ["falls" if delta < 0 else "rises", absf(delta)],
		"points": clampf((absf(delta) - 1.5) * 4, 0, 30)})
	var gap := INF
	var nearest := ""
	for lot: Dictionary in model.plots:
		var d: float = model.lot_gap(at, radius, lot)
		if d < gap:
			gap = d
			nearest = lot.label
	if not nearest.is_empty():
		lines.append({"text": "next to %s (%.0f m between lots)" % [nearest, gap], "points": 0})
		if gap > 12:
			lines.append({"text": "stands apart from its neighbours", "points": clampf((gap - 12) / 28 * 10, 0, 10)})
	if bank < 60:
		lines.append({"text": "%.0f m from the riverbank" % bank, "points": 0})
	var total := 100.0
	for line: Dictionary in lines:
		total -= float(line.points)
	result.score = snappedf(total, 0.1)
	if facts_needed:
		result.facts = _facts(model, at, radius, result, delta, bank)
	return result


static func disc_offsets(pad: float) -> PackedVector2Array:
	var offsets := PackedVector2Array()
	var steps := floori(pad / 4.0)
	for z in range(-steps, steps + 1):
		for x in range(-steps, steps + 1):
			var offset := Vector2(x, z) * 4.0
			if offset.length_squared() <= pad * pad:
				offsets.append(offset)
	return offsets


static func _ground_delta(at: Vector2, pad: float, heights: Callable, sweep: Sweep) -> float:
	var base := float(heights.call(at.x, at.y))
	var extreme := 0.0
	var offsets := sweep.offsets if sweep else disc_offsets(pad)
	# Fractional roadside centres have their own sample lattice. Share only exact grid points.
	var share := sweep != null and at == at.round()
	for offset in offsets:
		var point := at + offset
		var sample: float
		if share and sweep.samples.has(point):
			sample = sweep.samples[point]
		else:
			sample = heights.call(at.x + offset.x, at.y + offset.y)
			if share:
				sweep.samples[point] = sample
		var delta := sample - base
		if absf(delta) > absf(extreme):
			extreme = delta
	return extreme


# North is -z (up on the map). Report the gate's road sample relative to the road's halfway point.
static func _direction(offset: Vector2) -> String:
	if absf(offset.x) > absf(offset.y):
		return "east" if offset.x > 0 else "west"
	return "south" if offset.y > 0 else "north"


static func _road_middle(samples: PackedVector2Array) -> Vector2:
	var length := 0.0
	for i in range(1, samples.size()):
		length += samples[i].distance_to(samples[i-1])
	var remaining := length * 0.5
	for i in range(1, samples.size()):
		var span := samples[i].distance_to(samples[i-1])
		if remaining <= span and span > 0:
			return samples[i-1].lerp(samples[i], remaining / span)
		remaining -= span
	return samples[0]


static func _facts(model, at: Vector2, radius: float, result: Dictionary, delta: float, bank: float) -> Array:
	var road: Vector2 = result.path.to
	var offset := road - _road_middle(model.road_samples)
	var along := "near the middle"
	if offset.length() >= 5:
		along = "about %.0f m %s of the middle" % [maxf(absf(offset.x), absf(offset.y)), _direction(offset)]
	var facts := ["%s of the road, %s" % [_direction(at - road), along]]
	var neighbours := []
	for lot: Dictionary in model.plots:
		neighbours.append({"label": lot.label, "gap": model.lot_gap(at, radius, lot)})
	neighbours.sort_custom(func(a, b): return a.gap < b.gap if a.gap != b.gap else a.label < b.label)
	for neighbour: Dictionary in neighbours.slice(0, 2):
		facts.append("next to %s (%.0f m between lots)" % [neighbour.label, neighbour.gap])
	facts.append("%.0f m walk from the gate to the road" % result.path.length_m)
	if bank < 60:
		facts.append("%.0f m from the riverbank" % bank)
	facts.append("flat ground" if absf(delta) < 1.5 else "ground %s %.1f m across the pad" % ["falls" if delta < 0 else "rises", absf(delta)])
	facts.append("score %.1f / 100" % result.score)
	return facts


static func candidates(model, heights: Callable, n := 10) -> Array:
	if n <= 0 or not model.village_ok or model.road_samples.is_empty():
		return []
	var radius: float = model.lot_radius()
	var positions: PackedVector2Array = model.roadside_positions(radius)
	var inside: Rect2 = model.bounds.grow(-model.edge_radius(radius))
	for z in range(ceili(inside.position.y), floori(inside.end.y) + 1, 8):
		for x in range(ceili(inside.position.x), floori(inside.end.x) + 1, 8):
			positions.append(Vector2(x, z))
	var sweep := Sweep.new(model, disc_offsets(radius + PAD_EXTRA))
	var free := []
	for at in positions:
		if not model.lot_inside(at, radius):
			continue
		var blocked := false
		for lot: Dictionary in model.plots:
			if model.lot_gap(at, radius, lot) < model.LOT_GAP_M - model.FIT_EPS_M:
				blocked = true
				break
		if blocked:
			continue
		var result := _score(model, at, 0, heights, radius, false, sweep)
		if result.valid:
			free.append(result)
	free.sort_custom(func(a, b): return a.score > b.score if a.score != b.score else a.at < b.at)
	var chosen := []
	var centres := PackedVector2Array()
	var separation := maxf(40, radius)
	for result: Dictionary in free:
		var at: Vector2 = result.at
		var close := false
		for centre in centres:
			if at.distance_to(centre) < separation:
				close = true
				break
		if close:
			continue
		var measured := _score(model, at, 0, heights, radius, true, sweep)
		chosen.append({"id": _candidate_id(chosen.size()), "at": [at.x, at.y], "score": measured.score, "facts": measured.facts})
		centres.append(at)
		if chosen.size() >= n:
			break
	return chosen


static func _candidate_id(index: int) -> String:
	var letters := ""
	while index >= 0:
		letters = String.chr(65 + index % 26) + letters
		index = floori(index / 26.0) - 1
	return letters


static func rank(model, proposals: Array, heights: Callable) -> Array:
	var ranked: Array = []
	for i in proposals.size():
		var p: Dictionary = proposals[i]
		var r := score(model, Vector2(p.at[0], p.at[1]), deg_to_rad(p.yaw_deg), heights)
		if p.has("candidate"):
			r.candidate = p.candidate
		r.reason = p.reason
		r.index = i
		ranked.append(r)
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.valid != b.valid:
			return a.valid
		if a.score != b.score:
			return a.score > b.score
		if a.at != b.at:
			return a.at < b.at
		return a.index < b.index)
	for r: Dictionary in ranked:
		r.erase("index")
	return ranked
