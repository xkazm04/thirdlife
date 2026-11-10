class_name KitArena
extends RefCounted
## Kit parts for arenas. Every part is a static generator with parameters (see KIT.md for the table):
##   rrect(L, W, r)            rounded-rectangle path (rink outline, curb loops)
##   slab(mk, p0, p1, ...)     a thin wall segment between two points (boards, glass, walls)
##   rink(L, W, r, ...)        ice sheet + apron + boards + glass + two goals
##   stands(L, rows, ...)      raked tiers with seats, rear wall and aisles along one long side
##   rib(span, apex, p, ...)   parabolic-ish arch rib with purlins back to the previous rib, UV.x = param for dissolve
##   footing(...)              concrete plinth under a rib foot


static func rrect(L: float, W: float, r: float, n: int = 6) -> Array:
	var out: Array = []
	var hx: float = L * 0.5 - r
	var hz: float = W * 0.5 - r
	var corners: Array = [[Vector2(hx, -hz), -90.0], [Vector2(hx, hz), 0.0], [Vector2(-hx, hz), 90.0], [Vector2(-hx, -hz), 180.0]]
	for c: Array in corners:
		for k: int in n + 1:
			var a: float = deg_to_rad(float(c[1]) + 90.0 * float(k) / float(n))
			out.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * r)
	return out


## Thin wall between p0 and p1 (xz), width w across, from y0 to y1. `ext` overlaps neighbours.
static func slab(mk: MK, p0: Vector2, p1: Vector2, w: float, y0: float, y1: float, key: String, col: Color = Color.WHITE, ext: float = 0.04) -> void:
	var d: Vector2 = (p1 - p0)
	var l: float = d.length()
	if l < 1e-4:
		return
	d /= l
	var n: Vector2 = Vector2(-d.y, d.x) * w * 0.5
	var a: Vector2 = p0 - d * ext
	var b: Vector2 = p1 + d * ext
	mk.hull([Vector3(a.x + n.x, y0, a.y + n.y), Vector3(a.x - n.x, y0, a.y - n.y), Vector3(b.x + n.x, y0, b.y + n.y), Vector3(b.x - n.x, y0, b.y - n.y),
		Vector3(a.x + n.x, y1, a.y + n.y), Vector3(a.x - n.x, y1, a.y - n.y), Vector3(b.x + n.x, y1, b.y + n.y), Vector3(b.x - n.x, y1, b.y - n.y)], key, col)


static func goal(mk: MK, x: float, dir: float) -> void:
	# dir = +1 for the goal at +x (net extends further +x), -1 for -x
	var w: float = 0.92
	var hgt: float = 1.22
	var depth: float = 1.0
	mk.bar(Vector3(x, 0, -w), Vector3(x, hgt, -w), 0.1, 0.1, "goal_red", Color.WHITE, 0.02)
	mk.bar(Vector3(x, 0, w), Vector3(x, hgt, w), 0.1, 0.1, "goal_red", Color.WHITE, 0.02)
	mk.bar(Vector3(x, hgt, -w), Vector3(x, hgt, w), 0.1, 0.1, "goal_red", Color.WHITE, 0.02)
	var bx: float = x + dir * depth
	mk.hull([Vector3(x, 0.02, -w), Vector3(x, 0.02, w), Vector3(x, hgt, -w), Vector3(x, hgt, w), Vector3(bx, 0.02, -w * 0.85), Vector3(bx, 0.02, w * 0.85),
		Vector3(bx, hgt * 0.62, -w * 0.85), Vector3(bx, hgt * 0.62, w * 0.85)], "goal_net", Color(1, 1, 1))


static func rink(L: float = 60.0, W: float = 26.0, r: float = 8.5, glass_h: float = 2.0, with_goals: bool = true) -> MeshInstance3D:
	var mk: MK = MK.new(31)
	var path: Array = rrect(L, W, r, 7)
	var n: int = path.size()
	# ice sheet and concrete apron
	var poly: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in path:
		poly.append(p)
	mk.prism(poly, -0.5, 0.05, "ice", Color.WHITE, 1.0, true, false)
	var apron: Array = rrect(L + 7.0, W + 7.0, r + 3.5, 7)
	var apoly: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in apron:
		apoly.append(p)
	mk.prism(apoly, -0.9, -0.05, "concrete", Color(0.95, 0.95, 0.95), 1.0, true, false)
	# boards + kick plate, glass + posts
	for i: int in n:
		var p0: Vector2 = path[i]
		var p1: Vector2 = path[(i + 1) % n]
		slab(mk, p0, p1, 0.2, 0.05, 0.34, "boards_kick")
		slab(mk, p0, p1, 0.2, 0.34, 1.12, "boards")
		slab(mk, p0, p1, 0.28, 1.12, 1.2, "steel_light")
		slab(mk, p0, p1, 0.05, 1.2, 1.2 + glass_h, "glass", Color.WHITE, 0.0)
		if i % 3 == 0:
			mk.bar(Vector3(p0.x, 1.1, p0.y), Vector3(p0.x, 1.2 + glass_h + 0.15, p0.y), 0.12, 0.12, "steel_light", Color.WHITE, 0.02)
	if with_goals:
		goal(mk, L * 0.5 - 3.4, 1.0)
		goal(mk, -(L * 0.5 - 3.4), -1.0)
	var mi: MeshInstance3D = mk.instance("rink")
	mi.name = "Rink"
	return mi


## Raked stand along the -Z side of a rink of length L (width W): `rows` tiers, seats, rear wall, two aisles.
static func stands(L: float, W: float, rows: int = 10, row_d: float = 0.95, rise: float = 0.46, seat_cols: int = 0) -> MeshInstance3D:
	var mk: MK = MK.new(32)
	var len: float = L - 8.0
	var z0: float = -(W * 0.5 + 3.2)
	for i: int in rows:
		var z: float = z0 - float(i) * row_d
		var top: float = float(i + 1) * rise
		mk.boxm(Vector3(-len * 0.5, -0.5, z - row_d), Vector3(len * 0.5, top, z), "concrete", Color(1, 1, 1) * (0.96 + 0.04 * float(i % 2)), 0.03)
		# seats
		var sx: float = -len * 0.5 + 0.3
		var k: int = 0
		while sx < len * 0.5 - 0.6:
			if absf(sx - (-len * 0.17)) < 0.7 or absf(sx - len * 0.19) < 0.7:
				sx += 1.4
				continue
			var key: String = "seat" if (k + i) % 7 != 3 else "seat_alt"
			var t: float = 0.88 + 0.12 * mk.rng.randf()
			mk.boxm(Vector3(sx, top, z - 0.62), Vector3(sx + 0.5, top + 0.12, z - 0.18), key, Color(t, t, t))
			mk.boxm(Vector3(sx, top, z - 0.78), Vector3(sx + 0.5, top + 0.5, z - 0.68), key, Color(t, t, t))
			sx += 0.62
			k += 1
	# rear wall + columns (unfinished: only part-height on the right half)
	var zb: float = z0 - float(rows) * row_d
	var topb: float = float(rows) * rise
	mk.boxm(Vector3(-len * 0.5 - 0.5, -0.5, zb - 0.6), Vector3(len * 0.5 + 0.5, topb + 4.8, zb), "concrete_dark", Color.WHITE, 0.05)
	for i: int in 9:
		var x: float = -len * 0.5 + len * float(i) / 8.0
		mk.boxm(Vector3(x - 0.45, topb, zb - 0.9), Vector3(x + 0.45, topb + 5.6, zb - 0.1), "concrete", Color.WHITE, 0.05)
	# side retaining blocks
	for sx: float in [-1.0, 1.0]:
		mk.boxm(Vector3(sx * len * 0.5 - 0.35, -0.5, zb), Vector3(sx * len * 0.5 + 0.35, topb + 0.3, z0), "concrete_dark", Color.WHITE, 0.04)
	var mi: MeshInstance3D = mk.instance("stands")
	mi.name = "Stands"
	return mi


## Arch rib in the YZ plane at x=0. y(z) = apex * (1 - |z/span|^p). Returns a mesh whose UV.x runs 0..1 foot to foot.
## `prev_dx` > 0 adds purlins running to a previous rib that sits prev_dx metres at -X (same UV.x so they dissolve together).
static func rib_mesh(span: float, apex: float, p: float, prev_dx: float, key_main: String, key_bar: String, w: float = 0.7, d: float = 1.05, steps: int = 28) -> ArrayMesh:
	var mk: MK = MK.new(33)
	var path: PackedVector3Array = PackedVector3Array()
	for i: int in steps + 1:
		var u: float = float(i) / float(steps)
		var z: float = (u * 2.0 - 1.0) * span
		var y: float = apex * (1.0 - pow(absf(z / span), p))
		path.append(Vector3(0, y, z))
	var prof: PackedVector2Array = PackedVector2Array([Vector2(-d * 0.5, -w * 0.5), Vector2(d * 0.5, -w * 0.5), Vector2(d * 0.5, w * 0.5), Vector2(-d * 0.5, w * 0.5)])
	mk.sweep(path, prof, key_main, Color.WHITE, Vector3.RIGHT)
	if prev_dx > 0.0:
		mk.uv_fixed = true
		for i: int in range(2, steps - 1, 3):
			var u: float = float(i) / float(steps)
			mk.uv_value = Vector2(u, 2.0)
			var a: Vector3 = path[i]
			mk.bar(a, a + Vector3(-prev_dx, 0, 0), 0.34, 0.34, key_bar, Color.WHITE, 0.03)
		mk.uv_fixed = false
	return mk.build("rib")


static func footing(w: float = 1.8, h: float = 1.0) -> MK:
	var mk: MK = MK.new(34)
	mk.box(Vector3(w, h, w), "concrete", Color.WHITE, 0.08, Vector3(0, h * 0.5, 0))
	mk.box(Vector3(w * 0.72, 0.28, w * 0.72), "concrete_dark", Color.WHITE, 0.04, Vector3(0, h + 0.1, 0))
	return mk
