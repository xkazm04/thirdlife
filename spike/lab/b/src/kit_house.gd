class_name KitHouse
extends RefCounted
## Kit parts for buildings. house(w, d, wall_h, rise): stone footing, log-siding walls, shingled gable roof, chimney, glowing
## windows with shutters, porch. frame(w, d, h): the half-built timber-frame extension (posts, beams, rafters, partial floor).
## Origin = centre of the footprint at ground level, front faces +Z, long axis X.


static func _roof_slab(mk: MK, w: float, d: float, y_eave: float, y_ridge: float, over: float, sgn: float, rows: int = 6) -> void:
	# one roof plane from the ridge (z=0) to the eave (z = sgn*(d/2+over)), split into shingle rows
	var xe: float = w * 0.5 + 0.55
	var ze: float = sgn * (d * 0.5 + over)
	for r: int in rows:
		var f0: float = float(r) / float(rows)
		var f1: float = float(r + 1) / float(rows)
		var z0: float = ze * f0
		var z1: float = ze * f1
		var yy0: float = lerpf(y_ridge, y_eave, f0)
		var yy1: float = lerpf(y_ridge, y_eave, f1)
		var th: float = 0.2
		var k: float = 0.92 + 0.08 * float(r % 2) + 0.03 * mk.rng.randf()
		mk.hull([Vector3(-xe, yy0, z0), Vector3(xe, yy0, z0), Vector3(-xe, yy1, z1), Vector3(xe, yy1, z1),
			Vector3(-xe, yy0 - th, z0), Vector3(xe, yy0 - th, z0), Vector3(-xe, yy1 - th, z1), Vector3(xe, yy1 - th, z1)], "roof", Color(k, k, k))


static func house(w: float = 8.0, d: float = 5.6, wall_h: float = 3.0, rise: float = 2.7) -> MeshInstance3D:
	var mk: MK = MK.new(61)
	var f: float = 0.75
	# footing: stone blocks
	var nb: int = int(w / 1.0)
	for i: int in nb:
		var t: float = 0.88 + 0.14 * mk.rng.randf()
		mk.boxm(Vector3(-w * 0.5 - 0.2 + (w + 0.4) * float(i) / nb, 0, d * 0.5 - 0.1), Vector3(-w * 0.5 - 0.2 + (w + 0.4) * float(i + 1) / nb - 0.04, f, d * 0.5 + 0.22), "stone", Color(t, t, t), 0.04)
	mk.boxm(Vector3(-w * 0.5 - 0.2, 0, -d * 0.5 - 0.2), Vector3(w * 0.5 + 0.2, f - 0.05, d * 0.5 + 0.1), "stone_dark", Color.WHITE, 0.03)
	var y0: float = f
	var y1: float = f + wall_h
	mk.boxm(Vector3(-w * 0.5, y0, -d * 0.5), Vector3(w * 0.5, y1, d * 0.5), "wood", Color.WHITE, 0.03)
	# log siding strips on all four sides
	var rows: int = 7
	for r: int in rows:
		var y: float = y0 + 0.2 + (wall_h - 0.3) * float(r) / float(rows)
		var tt: float = 0.84 + 0.1 * float(r % 2)
		mk.boxm(Vector3(-w * 0.5 - 0.05, y, d * 0.5 - 0.02), Vector3(w * 0.5 + 0.05, y + 0.13, d * 0.5 + 0.07), "wood_dark", Color(tt, tt, tt), 0.0)
		mk.boxm(Vector3(-w * 0.5 - 0.05, y, -d * 0.5 - 0.07), Vector3(w * 0.5 + 0.05, y + 0.13, -d * 0.5 + 0.02), "wood_dark", Color(tt, tt, tt), 0.0)
		mk.boxm(Vector3(w * 0.5 - 0.02, y, -d * 0.5 - 0.05), Vector3(w * 0.5 + 0.07, y + 0.13, d * 0.5 + 0.05), "wood_dark", Color(tt, tt, tt), 0.0)
		mk.boxm(Vector3(-w * 0.5 - 0.07, y, -d * 0.5 - 0.05), Vector3(-w * 0.5 + 0.02, y + 0.13, d * 0.5 + 0.05), "wood_dark", Color(tt, tt, tt), 0.0)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mk.boxm(Vector3(sx * w * 0.5 - 0.14, y0, sz * d * 0.5 - 0.14), Vector3(sx * w * 0.5 + 0.14, y1 + 0.05, sz * d * 0.5 + 0.14), "wood_dark", Color.WHITE, 0.02)
	# gable ends (triangular, wood) and roof
	var y_r: float = y1 + rise
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * (w * 0.5 - 0.1)
		mk.hull([Vector3(x - 0.1, y1, -d * 0.5), Vector3(x + 0.1, y1, -d * 0.5), Vector3(x - 0.1, y1, d * 0.5), Vector3(x + 0.1, y1, d * 0.5), Vector3(x - 0.1, y_r - 0.3, 0), Vector3(x + 0.1, y_r - 0.3, 0)], "wood", Color(0.96, 0.96, 0.96))
	_roof_slab(mk, w, d, y1 - 0.15, y_r, 0.75, 1.0)
	_roof_slab(mk, w, d, y1 - 0.15, y_r, 0.75, -1.0)
	mk.bar(Vector3(-w * 0.5 - 0.6, y_r + 0.02, 0), Vector3(w * 0.5 + 0.6, y_r + 0.02, 0), 0.3, 0.2, "roof", Color(0.8, 0.8, 0.8), 0.04)
	# chimney
	var cx: float = w * 0.26
	var cz: float = -d * 0.14
	mk.boxm(Vector3(cx - 0.5, y1 - 0.5, cz - 0.5), Vector3(cx + 0.5, y_r + 1.1, cz + 0.5), "stone", Color(0.95, 0.95, 0.95), 0.05)
	mk.boxm(Vector3(cx - 0.62, y_r + 1.0, cz - 0.62), Vector3(cx + 0.62, y_r + 1.22, cz + 0.62), "stone_dark", Color.WHITE, 0.04)
	# windows: frame, glowing pane, shutters
	for wx: float in [-w * 0.3, w * 0.3]:
		_window(mk, Vector3(wx, y0 + 1.5, d * 0.5 + 0.02), 1.1, 1.0)
	_window(mk, Vector3(w * 0.5 + 0.02, y0 + 1.5, 0.0), 1.0, 1.0, true)
	_window(mk, Vector3(-w * 0.5 - 0.02, y0 + 1.5, 0.0), 1.0, 1.0, true, -1.0)
	# door, porch
	mk.boxm(Vector3(-0.5, y0, d * 0.5 - 0.02), Vector3(0.5, y0 + 2.0, d * 0.5 + 0.1), "wood_dark", Color(0.8, 0.8, 0.8), 0.03)
	mk.boxm(Vector3(-0.62, y0 + 1.95, d * 0.5 - 0.02), Vector3(0.62, y0 + 2.12, d * 0.5 + 0.14), "wood_light", Color.WHITE, 0.02)
	mk.boxm(Vector3(-1.6, 0, d * 0.5 + 0.1), Vector3(1.6, 0.18, d * 0.5 + 1.7), "stone", Color.WHITE, 0.04)
	mk.boxm(Vector3(-1.2, 0, d * 0.5 + 1.7), Vector3(1.2, 0.12, d * 0.5 + 2.2), "stone_dark", Color.WHITE, 0.03)
	for sx: float in [-1.0, 1.0]:
		mk.bar(Vector3(sx * 1.45, 0.18, d * 0.5 + 1.55), Vector3(sx * 1.45, y0 + 2.4, d * 0.5 + 1.55), 0.16, 0.16, "wood_dark", Color.WHITE, 0.02)
	mk.hull([Vector3(-1.9, y0 + 2.4, d * 0.5 - 0.1), Vector3(1.9, y0 + 2.4, d * 0.5 - 0.1), Vector3(-1.9, y0 + 2.4, d * 0.5 + 1.9), Vector3(1.9, y0 + 2.4, d * 0.5 + 1.9),
		Vector3(-1.9, y0 + 3.0, d * 0.5 - 0.1), Vector3(1.9, y0 + 3.0, d * 0.5 - 0.1), Vector3(-1.9, y0 + 2.45, d * 0.5 + 1.9), Vector3(1.9, y0 + 2.45, d * 0.5 + 1.9)], "roof", Color(0.9, 0.9, 0.9))
	mk.box(Vector3(0.16, 0.26, 0.16), "window", Color.WHITE, 0.02, Vector3(0.8, y0 + 2.0, d * 0.5 + 0.22))
	var mi: MeshInstance3D = mk.instance("house")
	mi.name = "House"
	return mi


static func _window(mk: MK, c: Vector3, w: float, h: float, side: bool = false, dir: float = 1.0) -> void:
	mk.push_at(c, Vector3(0, 90.0 * dir if side else 0.0, 0))
	mk.box(Vector3(w + 0.3, h + 0.3, 0.14), "wood_light", Color.WHITE, 0.03, Vector3(0, 0, 0.0))
	mk.box(Vector3(w, h, 0.18), "window", Color.WHITE, 0.0, Vector3(0, 0, 0.0))
	mk.bar(Vector3(0, -h * 0.5, 0.1), Vector3(0, h * 0.5, 0.1), 0.05, 0.05, "wood_light", Color.WHITE)
	mk.bar(Vector3(-w * 0.5, 0, 0.1), Vector3(w * 0.5, 0, 0.1), 0.05, 0.05, "wood_light", Color.WHITE)
	for sx: float in [-1.0, 1.0]:
		mk.box(Vector3(w * 0.36, h + 0.3, 0.07), "wood_dark", Color.WHITE, 0.02, Vector3(sx * (w * 0.5 + 0.38), 0, 0.03))
	mk.pop()


## The half-built timber-frame extension.
static func frame(w: float = 6.0, d: float = 5.6, h: float = 3.0, rise: float = 2.4) -> MeshInstance3D:
	var mk: MK = MK.new(62)
	mk.boxm(Vector3(-w * 0.5 - 0.15, 0, -d * 0.5 - 0.15), Vector3(w * 0.5 + 0.15, 0.7, d * 0.5 + 0.15), "stone_dark", Color.WHITE, 0.04)
	mk.boxm(Vector3(-w * 0.5 - 0.15, 0.7, -d * 0.5 - 0.15), Vector3(-w * 0.1, 0.78, d * 0.5 + 0.15), "plank", Color.WHITE, 0.01)
	var y0: float = 0.78
	var nx: int = 4
	for i: int in nx:
		var x: float = -w * 0.5 + w * float(i) / float(nx - 1)
		for z: float in [-d * 0.5, d * 0.5]:
			mk.bar(Vector3(x, y0, z), Vector3(x, y0 + h, z), 0.24, 0.24, "wood_light", Color.WHITE, 0.02)
			mk.bar(Vector3(x, y0 + h * 0.55, z), Vector3(x + (w / (nx - 1)) * 0.5 * (1 if i < nx - 1 else -1), y0 + h, z), 0.1, 0.1, "wood_light", Color.WHITE)
	for z: float in [-d * 0.5, d * 0.5]:
		mk.bar(Vector3(-w * 0.5, y0 + h, z), Vector3(w * 0.5, y0 + h, z), 0.24, 0.22, "wood_light", Color.WHITE, 0.02)
		mk.bar(Vector3(-w * 0.5, y0 + 0.9, z), Vector3(w * 0.5, y0 + 0.9, z), 0.12, 0.12, "wood", Color.WHITE)
	for i: int in nx:
		var x: float = -w * 0.5 + w * float(i) / float(nx - 1)
		mk.bar(Vector3(x, y0 + h, -d * 0.5), Vector3(x, y0 + h, d * 0.5), 0.22, 0.22, "wood_light", Color.WHITE, 0.02)
		# rafter pair (gable along X, ridge at z=0)
		mk.bar(Vector3(x, y0 + h, -d * 0.5 - 0.4), Vector3(x, y0 + h + rise, 0), 0.16, 0.2, "wood_light", Color.WHITE, 0.02)
		mk.bar(Vector3(x, y0 + h, d * 0.5 + 0.4), Vector3(x, y0 + h + rise, 0), 0.16, 0.2, "wood_light", Color.WHITE, 0.02)
		mk.bar(Vector3(x, y0 + h + rise * 0.55, -d * 0.2), Vector3(x, y0 + h + rise * 0.55, d * 0.2), 0.1, 0.1, "wood", Color.WHITE)
	mk.bar(Vector3(-w * 0.5 - 0.2, y0 + h + rise, 0), Vector3(w * 0.5 + 0.2, y0 + h + rise, 0), 0.2, 0.22, "wood_light", Color.WHITE, 0.02)
	# a few roof battens on the first bay + studs
	for k: int in 3:
		var z: float = -d * 0.5 + 0.9 * k
		mk.bar(Vector3(-w * 0.5, y0 + 0.1, z), Vector3(-w * 0.5, y0 + h, z), 0.1, 0.1, "wood", Color.WHITE)
	mk.bar(Vector3(w * 0.5 + 0.7, 0, d * 0.5 + 0.3), Vector3(w * 0.5 + 0.1, y0 + h * 0.85, d * 0.5 + 0.3), 0.07, 0.05, "wood", Color.WHITE)
	var mi: MeshInstance3D = mk.instance("frame")
	mi.name = "Frame"
	return mi
