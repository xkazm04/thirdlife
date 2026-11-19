extends RefCounted

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
			var distance: float = map.model.lot_gap(place.at, map.model.lot_radius(), lot)
			if distance < gap:
				nearest = lot.id
				gap = distance
		ids.append(nearest)
	return ids


static func places(map) -> void:
	for i in map.proposals.size():
		var r: Dictionary = map.proposals[i]
		var c: Vector2 = map.to_screen(r.at)
		var radius: float = map.model.edge_radius(map.model.lot_radius()) * map._scale
		if not Rect2(Vector2.ZERO, map.size).grow(radius).has_point(c):
			continue
		var ink: Color = map.col.green if r.valid else map.col.hazard
		if r.at != map.model.at:
			var f: Vector3 = map.model.footprint()
			map._pad(r.at, Vector2(f.x, f.y) * 0.5, r.yaw, Color(ink, 0.48 if i == map.highlight else 0.28))
			map._dashed_circle(c, radius, Color(ink, 0.55 if i == map.highlight else 0.38), 1.2)
			map._approach(r.at, map.model.lot_radius(), r.path.to, true)
			if not r.valid:
				map._clearance_hatching(c, radius)
		var anchor := c + Vector2(0.48, -0.46) * radius
		map._tag(anchor + Vector2(2, -20), str(i+1), ink, map.col.paper, 14, anchor)
