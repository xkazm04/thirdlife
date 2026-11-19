extends RefCounted

static func entrance(map, gate: Vector2, direction: Vector2) -> void:
	var front := direction.normalized()
	var side := front.orthogonal()
	var arch := PackedVector2Array()
	for i in 19:
		var a := PI * i / 18.0
		arch.append(gate + side * cos(a) * 7 - front * sin(a) * 7)
	map.draw_polyline(arch, map.col.ink, 5.0, true)
	map.draw_polyline(arch, map.col.honey, 2.3, true)
	for post in [arch[0], arch[-1]]:
		map.draw_circle(post, 3, map.col.ink)


static func spectators(map, hx: float, hz: float, long_x: bool) -> void:
	var end := maxf(hx, hz) * 0.78
	var edge := minf(hx, hz)
	for side in [-1, 1]:
		var inner: float = side * (edge + 0.3)
		var outer: float = side * (edge + 2.8)
		var band: PackedVector2Array = map._rect(-end, inner, end, outer) if long_x else map._rect(inner, -end, outer, end)
		map.draw_colored_polygon(band, map.col.honey)
		for x in range(ceili(-end), floori(end)-2, 3):
			var a := Vector2(x, inner) if long_x else Vector2(inner, x)
			var b := Vector2(x+2, outer) if long_x else Vector2(outer, x+2)
			map._line(a, b, map.col.wood_dark, 1.2)


## In the comparison view, label each candidate's nearest neighbour so the numbers and spurs stay legible.
static func neighbours(map) -> Array:
	var ids := []
	for place: Dictionary in map.proposals:
		var nearest := ""
		var gap := INF
		for lot: Dictionary in map.model.plots:
			var distance: float = map.model.fence_gap(place.at, map.model.lot_radius(), lot)
			if distance < gap:
				nearest = lot.id
				gap = distance
		ids.append(nearest)
	return ids


static func places(map) -> void:
	for i in map.proposals.size():
		var r: Dictionary = map.proposals[i]
		var c: Vector2 = map.to_screen(r.at)
		var radius: float = map.model.fence_radius(map.model.lot_radius()) * map._scale
		if not Rect2(Vector2.ZERO, map.size).grow(radius).has_point(c):
			continue
		var ink: Color = map.col.green if r.valid else map.col.hazard
		var width := 3.5 if i == map.highlight else 2.0
		if r.at != map.model.at:
			map.draw_circle(c, radius, Color(ink, 0.13 if i != map.highlight else 0.30), true, -1, true)
			map._dashed_circle(c, radius + map.model.FENCE_GAP_M * 0.5 * map._scale, Color(ink, 0.65), 1.0)
		map.draw_arc(c, radius, 0, TAU, 64, map.col.paper, width + 1, true)
		map._dashed_circle(c, radius, ink, width)
		map._dashed_line(map.to_screen(r.path.from), map.to_screen(r.path.to), ink, width)
		map._tag(c + Vector2(radius*0.52, -radius*0.88), str(i+1), ink, map.col.paper, 14)
