class_name TLKitSite
extends RefCounted
## Kit parts for construction sites: tower crane, scaffold bay set, ladders, lumber, block pallets, barricades, cones, fences.
##   crane(height, mast, jib, counter)  -> Node3D {Tower mesh, Slew (rotating: jib mesh, Hoist pivot -> Load)}
##   scaffold(bays, levels, bw, bd, lh, decks)
##   lumber(len, w, layers), pallet(blocks), barricade(w), cone(), ladder(h), fence(len, posts)


static func lattice(mk: TLMesh, a: Vector3, b: Vector3, side: float, bay: float, chord_key: String, brace_key: String, ch_w: float = 0.2, br_w: float = 0.09) -> void:
	# square lattice mast from a (bottom centre) to b (top centre), vertical only
	var h: float = b.y - a.y
	var n: int = maxi(1, roundi(h / bay))
	var hh: float = side * 0.5
	var cs: Array = [Vector2(-hh, -hh), Vector2(hh, -hh), Vector2(hh, hh), Vector2(-hh, hh)]
	for c: Vector2 in cs:
		mk.bar(Vector3(a.x + c.x, a.y, a.z + c.y), Vector3(a.x + c.x, b.y, a.z + c.y), ch_w, ch_w, chord_key, Color.WHITE, 0.02)
	for i: int in n:
		var y0: float = a.y + h * float(i) / float(n)
		var y1: float = a.y + h * float(i + 1) / float(n)
		for k: int in 4:
			var c0: Vector2 = cs[k]
			var c1: Vector2 = cs[(k + 1) % 4]
			var flip: bool = (i + k) % 2 == 0
			var p0: Vector3 = Vector3(a.x + c0.x, y0 if flip else y1, a.z + c0.y)
			var p1: Vector3 = Vector3(a.x + c1.x, y1 if flip else y0, a.z + c1.y)
			mk.bar(p0, p1, br_w, br_w, brace_key, Color.WHITE)
			mk.bar(Vector3(a.x + c0.x, y1, a.z + c0.y), Vector3(a.x + c1.x, y1, a.z + c1.y), br_w, br_w, brace_key, Color.WHITE)


static func crane(height: float = 35.0, mast: float = 2.3, jib: float = 30.0, counter: float = 11.0) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Crane"
	var mk: TLMesh = TLMesh.new(41)
	# ballast + base
	mk.box(Vector3(mast + 3.2, 0.8, mast + 3.2), "concrete", Color.WHITE, 0.08, Vector3(0, 0.4, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mk.box(Vector3(1.4, 0.9, 1.4), "concrete_dark", Color.WHITE, 0.06, Vector3(sx * (mast * 0.5 + 0.8), 1.2, sz * (mast * 0.5 + 0.8)))
	lattice(mk, Vector3(0, 0.8, 0), Vector3(0, height, 0), mast, 2.6, "yellow", "yellow_dark", 0.38, 0.15)   # pass 4: chunky members, so the yellow survives the ink pass at hero distance
	var tower: MeshInstance3D = mk.instance("crane_tower")
	tower.name = "Tower"
	root.add_child(tower)
	# slewing part (rotates): turntable, cab, A-frame, jib and counter jib lattices, counterweights
	var slew: Node3D = Node3D.new()
	slew.name = "Slew"
	slew.position = Vector3(0, height, 0)
	root.add_child(slew)
	var m2: TLMesh = TLMesh.new(42)
	m2.cyl(mast * 0.62, 0.7, 10, "steel_dark", Color.WHITE, -1.0, Vector3(0, 0, 0))
	m2.box(Vector3(2.2, 2.3, 2.0), "yellow", Color.WHITE, 0.08, Vector3(-0.2, 1.8, 1.9))
	m2.box(Vector3(0.1, 1.0, 1.4), "car_glass", Color.WHITE, 0.0, Vector3(0.93, 2.1, 1.9))
	var top: float = 7.0
	# A-frame
	m2.bar(Vector3(-mast * 0.45, 0.7, 0), Vector3(0, top, 0), 0.3, 0.3, "yellow", Color.WHITE, 0.03)
	m2.bar(Vector3(mast * 0.45, 0.7, 0), Vector3(0, top, 0), 0.3, 0.3, "yellow", Color.WHITE, 0.03)
	m2.box(Vector3(0.7, 0.5, 0.7), "yellow_dark", Color.WHITE, 0.04, Vector3(0, top, 0))
	# jib lattice (triangular section): x from -counter .. +jib, chords at y=0.8 (top) and y=0, z=+-0.85
	var j0: float = -counter
	var jn: int = roundi((jib - j0) / 2.0)
	for k: int in 3:
		var yy: float = 1.15 if k == 0 else 0.0
		var zz: float = 0.0 if k == 0 else (-0.85 if k == 1 else 0.85)
		m2.bar(Vector3(j0, 0.35 + yy, zz), Vector3(jib, 0.35 + yy, zz), 0.32, 0.32, "yellow", Color.WHITE, 0.02)
	for i: int in jn:
		var x0: float = j0 + (jib - j0) * float(i) / float(jn)
		var x1: float = j0 + (jib - j0) * float(i + 1) / float(jn)
		var f: bool = i % 2 == 0
		m2.bar(Vector3(x0, 0.35, -0.85), Vector3(x1 if f else x0, 1.5, 0), 0.13, 0.13, "yellow_dark", Color.WHITE)
		m2.bar(Vector3(x0, 0.35, 0.85), Vector3(x1 if f else x0, 1.5, 0), 0.13, 0.13, "yellow_dark", Color.WHITE)
		m2.bar(Vector3(x1, 0.35, -0.85), Vector3(x1, 0.35, 0.85), 0.13, 0.13, "yellow_dark", Color.WHITE)
	# tie rods from the A-frame head to jib tip and counter end
	m2.bar(Vector3(0, top, 0), Vector3(jib * 0.82, 1.5, 0), 0.07, 0.07, "steel_dark", Color.WHITE)
	m2.bar(Vector3(0, top, 0), Vector3(j0 * 0.9, 1.5, 0), 0.07, 0.07, "steel_dark", Color.WHITE)
	# counterweights
	for i: int in 4:
		m2.box(Vector3(1.4, 1.5, 1.9), "concrete", Color(0.92 + 0.04 * (i % 2), 0.92, 0.92), 0.06, Vector3(j0 + 0.9 + float(i) * 1.5, 0.0, 0))
	var jibmesh: MeshInstance3D = m2.instance("crane_jib")
	jibmesh.name = "Jib"
	slew.add_child(jibmesh)
	# trolley + hoist + load
	var hoist: Node3D = Node3D.new()
	hoist.name = "Hoist"
	hoist.position = Vector3(jib * 0.62, 0.0, 0.0)
	slew.add_child(hoist)
	var m3: TLMesh = TLMesh.new(43)
	m3.box(Vector3(1.2, 0.5, 1.2), "steel_dark", Color.WHITE, 0.05, Vector3(0, 0.1, 0))
	var drop: float = 11.0
	m3.bar(Vector3(0, 0.0, 0), Vector3(0, -drop + 1.0, 0), 0.06, 0.06, "black", Color.WHITE)
	m3.box(Vector3(0.7, 0.6, 0.5), "yellow", Color.WHITE, 0.05, Vector3(0, -drop + 0.8, 0))
	var trolley: MeshInstance3D = m3.instance("crane_trolley")
	trolley.name = "Trolley"
	hoist.add_child(trolley)
	var load: Node3D = Node3D.new()
	load.name = "Load"
	load.position = Vector3(0, -drop + 0.5, 0)
	hoist.add_child(load)
	var m4: TLMesh = TLMesh.new(44)
	m4.bar(Vector3(0, 0.3, 0), Vector3(-1.3, -0.9, 0), 0.05, 0.05, "black", Color.WHITE)
	m4.bar(Vector3(0, 0.3, 0), Vector3(1.3, -0.9, 0), 0.05, 0.05, "black", Color.WHITE)
	m4.box(Vector3(3.0, 0.6, 0.7), "concrete", Color.WHITE, 0.06, Vector3(0, -1.2, 0))
	m4.box(Vector3(3.06, 0.14, 0.76), "steel", Color.WHITE, 0.02, Vector3(0, -1.0, 0))
	var lm: MeshInstance3D = m4.instance("crane_load")
	lm.name = "LoadMesh"
	load.add_child(lm)
	return root


## Scaffold: bays x levels. Origin at the front-left-bottom corner footprint centre; extends +X by bays*bw, depth bd.
static func scaffold(bays: int = 2, levels: int = 2, bw: float = 2.4, bd: float = 1.3, lh: float = 2.0, deck_levels: Array = [1, 2]) -> TLMesh:
	var mk: TLMesh = TLMesh.new(45)
	var W: float = float(bays) * bw
	var H: float = float(levels) * lh
	for i: int in bays + 1:
		var x: float = float(i) * bw
		for z: float in [0.0, bd]:
			mk.bar(Vector3(x, 0, z), Vector3(x, H + 1.0, z), 0.16, 0.16, "yellow", Color.WHITE, 0.01)
			mk.box(Vector3(0.28, 0.08, 0.28), "steel_dark", Color.WHITE, 0.0, Vector3(x, 0.04, z))
	for l: int in range(1, levels + 1):
		var y: float = float(l) * lh
		for z: float in [0.0, bd]:
			mk.bar(Vector3(0, y, z), Vector3(W, y, z), 0.11, 0.11, "orange", Color.WHITE)
			mk.bar(Vector3(0, y + 1.0, z), Vector3(W, y + 1.0, z), 0.09, 0.09, "orange", Color.WHITE)
			mk.bar(Vector3(0, y + 0.5, z), Vector3(W, y + 0.5, z), 0.07, 0.07, "orange", Color.WHITE)
		for i: int in bays + 1:
			mk.bar(Vector3(float(i) * bw, y, 0), Vector3(float(i) * bw, y, bd), 0.07, 0.07, "orange", Color.WHITE)
		if deck_levels.has(l):
			for i: int in bays:
				mk.boxm(Vector3(float(i) * bw + 0.04, y + 0.04, -0.06), Vector3(float(i + 1) * bw - 0.04, y + 0.12, bd + 0.06), "plank", Color(0.95 + 0.05 * (i % 2), 0.95, 0.95), 0.01)
	for i: int in bays:
		var x0: float = float(i) * bw
		var x1: float = x0 + bw
		for l: int in levels:
			var y0: float = float(l) * lh
			var y1: float = y0 + lh
			var f: bool = (i + l) % 2 == 0
			mk.bar(Vector3(x0 if f else x1, y0, 0), Vector3(x1 if f else x0, y1, 0), 0.05, 0.05, "yellow_dark", Color.WHITE)
	mk.bar(Vector3(W, 0, 0), Vector3(W, H, bd), 0.05, 0.05, "yellow_dark", Color.WHITE)
	# ladder up the end bay
	for z: float in [bd * 0.35, bd * 0.65]:
		mk.bar(Vector3(W + 0.25, 0, z), Vector3(W + 0.05, H + 0.9, z), 0.06, 0.06, "wood_light", Color.WHITE)
	var rungs: int = int(H / 0.35)
	for i: int in rungs:
		var f: float = float(i) / float(rungs)
		var y: float = 0.25 + f * (H + 0.5)
		mk.bar(Vector3(W + 0.25 - 0.2 * f, y, bd * 0.35), Vector3(W + 0.25 - 0.2 * f, y, bd * 0.65), 0.05, 0.05, "wood_light", Color.WHITE)
	return mk


static func add_lumber(mk: TLMesh, origin: Vector3, len: float = 3.2, w: float = 1.0, layers: int = 6, yaw_deg: float = 0.0) -> void:
	mk.push_at(origin, Vector3(0, yaw_deg, 0))
	mk.boxm(Vector3(-len * 0.45, 0, -w * 0.4), Vector3(-len * 0.45 + 0.18, 0.14, w * 0.4), "wood_dark")
	mk.boxm(Vector3(len * 0.45 - 0.18, 0, -w * 0.4), Vector3(len * 0.45, 0.14, w * 0.4), "wood_dark")
	for l: int in layers:
		for k: int in 4:
			var t: float = 0.9 + 0.1 * mk.rng.randf()
			var z0: float = -w * 0.5 + (float(k) + 0.5) * w / 4.0
			mk.box(Vector3(len * (0.96 + 0.04 * mk.rng.randf()), 0.11, w / 4.0 - 0.03), "plank" if (l + k) % 3 else "wood_light", Color(t, t, t), 0.01, Vector3(0, 0.14 + 0.11 * (l + 0.5), z0))
	mk.pop()


static func add_pallet(mk: TLMesh, origin: Vector3, rows: int = 3, yaw_deg: float = 0.0) -> void:
	mk.push_at(origin, Vector3(0, yaw_deg, 0))
	mk.box(Vector3(2.0, 0.14, 1.2), "wood", Color.WHITE, 0.01, Vector3(0, 0.07, 0))
	for r: int in rows:
		for c: int in 2:
			for k: int in 2:
				var t: float = 0.92 + 0.08 * mk.rng.randf()
				mk.box(Vector3(0.92, 0.38, 0.55), "concrete", Color(t, t, t), 0.03, Vector3(-0.48 + c * 0.96, 0.14 + 0.2 + r * 0.4, -0.29 + k * 0.58))
	mk.pop()


static func add_barricade(mk: TLMesh, origin: Vector3, w: float = 1.8, yaw_deg: float = 0.0) -> void:
	mk.push_at(origin, Vector3(0, yaw_deg, 0))
	for sx: float in [-1.0, 1.0]:
		mk.bar(Vector3(sx * w * 0.5, 0, -0.35), Vector3(sx * w * 0.5, 0.95, 0), 0.07, 0.07, "steel_dark", Color.WHITE)
		mk.bar(Vector3(sx * w * 0.5, 0, 0.35), Vector3(sx * w * 0.5, 0.95, 0), 0.07, 0.07, "steel_dark", Color.WHITE)
	var n: int = 6
	for r: int in 2:
		for i: int in n:
			var x0: float = -w * 0.5 + w * float(i) / float(n)
			var x1: float = x0 + w / float(n)
			var key: String = "hazard_red" if (i + r) % 2 == 0 else "curb_white"
			mk.boxm(Vector3(x0, 0.55 + r * 0.22, -0.05), Vector3(x1, 0.73 + r * 0.22, 0.05), key, Color.WHITE, 0.01)
	mk.pop()


static func add_cone(mk: TLMesh, origin: Vector3) -> void:
	mk.cyl(0.22, 0.6, 8, "hot", Color.WHITE, 0.04, origin)
	mk.cyl(0.17, 0.1, 8, "curb_white", Color.WHITE, 0.13, origin + Vector3(0, 0.26, 0))
	mk.box(Vector3(0.5, 0.04, 0.5), "black", Color.WHITE, 0.01, origin + Vector3(0, 0.02, 0))


static func add_fence(mk: TLMesh, a: Vector3, b: Vector3, post_gap: float = 2.2) -> void:
	var l: float = a.distance_to(b)
	var n: int = maxi(1, roundi(l / post_gap))
	for i: int in n + 1:
		var p: Vector3 = a.lerp(b, float(i) / float(n))
		mk.bar(p, p + Vector3(0, 1.2, 0), 0.12, 0.12, "wood_dark", Color.WHITE, 0.02)
	for h: float in [0.5, 0.95]:
		mk.bar(a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.07, 0.12, "wood", Color.WHITE, 0.01)


static func add_ladder(mk: TLMesh, base: Vector3, top: Vector3) -> void:
	var d: Vector3 = (top - base)
	var side: Vector3 = Vector3(d.z, 0, -d.x).normalized() * 0.28
	mk.bar(base + side, top + side, 0.07, 0.05, "wood_light", Color.WHITE)
	mk.bar(base - side, top - side, 0.07, 0.05, "wood_light", Color.WHITE)
	var n: int = maxi(3, int(d.length() / 0.4))
	for i: int in range(1, n):
		var p: Vector3 = base + d * (float(i) / float(n))
		mk.bar(p + side, p - side, 0.05, 0.05, "wood", Color.WHITE)


# ------------------------------------------------------------------ pass 2: site density parts (all placed by layout data)
static func add_site_fence(mk: TLMesh, a: Vector3, b: Vector3, gap: float = 2.6) -> void:
	var l: float = a.distance_to(b)
	var n: int = maxi(1, roundi(l / gap))
	for i: int in n + 1:
		var p: Vector3 = a.lerp(b, float(i) / float(n))
		mk.bar(p, p + Vector3(0, 2.0, 0), 0.07, 0.07, "steel", Color.WHITE)
		mk.box(Vector3(0.5, 0.14, 0.22), "concrete", Color.WHITE, 0.02, p + Vector3(0, 0.07, 0))
	for hh: float in [0.3, 1.1, 1.9]:
		mk.bar(a + Vector3(0, hh, 0), b + Vector3(0, hh, 0), 0.04, 0.04, "steel", Color.WHITE)
	for i: int in n * 4:
		var p: Vector3 = a.lerp(b, (float(i) + 0.5) / float(n * 4))
		mk.bar(p + Vector3(0, 0.3, 0), p + Vector3(0, 1.9, 0), 0.025, 0.025, "steel_light", Color.WHITE)


static func add_sign(mk: TLMesh, o: Vector3, yaw: float, key: String = "sign") -> void:
	mk.push_at(o, Vector3(0, yaw, 0))
	for sx: float in [-0.7, 0.7]:
		mk.bar(Vector3(sx, 0, 0), Vector3(sx, 2.6, 0), 0.09, 0.09, "wood_dark", Color.WHITE)
	mk.box(Vector3(2.0, 1.2, 0.08), key, Color.WHITE, 0.03, Vector3(0, 2.0, 0.06))
	mk.box(Vector3(1.84, 1.04, 0.02), "black", Color.WHITE, 0.0, Vector3(0, 2.0, 0.105))
	mk.box(Vector3(1.74, 0.94, 0.02), key, Color.WHITE, 0.0, Vector3(0, 2.0, 0.11))
	mk.box(Vector3(1.2, 0.12, 0.02), "black", Color.WHITE, 0.0, Vector3(0, 2.2, 0.125))
	mk.box(Vector3(0.9, 0.09, 0.02), "black", Color.WHITE, 0.0, Vector3(-0.15, 1.95, 0.125))
	mk.box(Vector3(0.28, 0.28, 0.02), "hazard_red", Color.WHITE, 0.0, Vector3(0.6, 1.78, 0.125))
	mk.pop()


static func add_flag(mk: TLMesh, o: Vector3, h: float = 7.0, key: String = "flag_a") -> void:
	mk.bar(o, o + Vector3(0, h, 0), 0.09, 0.09, "steel_light", Color.WHITE)
	mk.box(Vector3(0.16, 0.16, 0.16), "yellow", Color.WHITE, 0.04, o + Vector3(0, h + 0.05, 0))
	var y1: float = h - 0.15
	var y0: float = h - 1.25
	mk.hull([o + Vector3(0.05, y0, 0), o + Vector3(0.05, y1, 0), o + Vector3(0.9, y1 - 0.08, 0.22), o + Vector3(0.9, y0 + 0.04, 0.22), o + Vector3(0.05, y0, 0.03), o + Vector3(0.9, y1 - 0.08, 0.25)], key)
	mk.hull([o + Vector3(0.9, y1 - 0.08, 0.22), o + Vector3(0.9, y0 + 0.04, 0.22), o + Vector3(1.75, y1 - 0.2, -0.05), o + Vector3(1.75, y0 - 0.05, -0.05), o + Vector3(0.9, y0 + 0.04, 0.25), o + Vector3(1.75, y1 - 0.2, -0.02)], key, Color(0.9, 0.9, 0.9))


static func add_light_mast(mk: TLMesh, o: Vector3, h: float = 14.0, yaw: float = 0.0) -> void:
	mk.push_at(o, Vector3(0, yaw, 0))
	mk.box(Vector3(1.4, 0.5, 1.4), "concrete", Color.WHITE, 0.06, Vector3(0, 0.25, 0))
	lattice(mk, Vector3(0, 0.5, 0), Vector3(0, h, 0), 0.7, 1.6, "steel", "steel_dark", 0.09, 0.05)
	mk.push_at(Vector3(0, h + 0.5, 0), Vector3(-22, 0, 0))
	mk.box(Vector3(2.8, 1.2, 0.3), "steel_dark", Color.WHITE, 0.04)
	for ix: int in 4:
		for iy: int in 2:
			mk.box(Vector3(0.52, 0.42, 0.06), "window", Color.WHITE, 0.02, Vector3(-1.02 + ix * 0.68, -0.27 + iy * 0.54, 0.17))
	mk.pop()
	mk.pop()


static func add_cabin(mk: TLMesh, o: Vector3, yaw: float = 0.0) -> void:
	mk.push_at(o, Vector3(0, yaw, 0))
	for sx: float in [-2.6, 2.6]:
		mk.box(Vector3(0.5, 0.3, 2.3), "concrete_dark", Color.WHITE, 0.03, Vector3(sx, 0.15, 0))
	mk.box(Vector3(6.0, 2.5, 2.4), "cabin", Color.WHITE, 0.06, Vector3(0, 1.55, 0))
	for i: int in 13:
		mk.box(Vector3(0.07, 2.2, 0.04), "cabin", Color(0.86, 0.86, 0.86), 0.0, Vector3(-2.76 + i * 0.46, 1.55, 1.215))
	mk.box(Vector3(6.1, 0.14, 2.5), "cabin_trim", Color.WHITE, 0.03, Vector3(0, 2.82, 0))
	mk.box(Vector3(6.1, 0.14, 2.5), "cabin_trim", Color.WHITE, 0.03, Vector3(0, 0.33, 0))
	mk.box(Vector3(0.95, 1.95, 0.08), "cabin_trim", Color.WHITE, 0.03, Vector3(-1.9, 1.38, 1.24))
	mk.box(Vector3(0.1, 0.1, 0.06), "yellow", Color.WHITE, 0.02, Vector3(-1.58, 1.35, 1.3))
	mk.box(Vector3(1.7, 0.95, 0.08), "window", Color.WHITE, 0.0, Vector3(0.9, 1.85, 1.22))
	mk.box(Vector3(1.86, 1.1, 0.05), "steel_dark", Color.WHITE, 0.02, Vector3(0.9, 1.85, 1.205))
	mk.bar(Vector3(0.9, 1.38, 1.27), Vector3(0.9, 2.32, 1.27), 0.05, 0.03, "steel_dark", Color.WHITE)
	mk.box(Vector3(0.9, 0.5, 0.7), "steel", Color.WHITE, 0.04, Vector3(2.0, 3.12, -0.5))
	mk.box(Vector3(1.2, 0.16, 0.7), "plank", Color.WHITE, 0.01, Vector3(-1.9, 0.16, 1.6))
	mk.pop()


static func add_scoreboard(mk: TLMesh, o: Vector3, yaw: float = 0.0) -> void:
	mk.push_at(o, Vector3(0, yaw, 0))
	for sx: float in [-3.2, 3.2]:
		mk.bar(Vector3(sx, 0, 0), Vector3(sx, 11.5, 0), 0.4, 0.4, "steel", Color.WHITE, 0.04)
	mk.box(Vector3(8.4, 4.0, 0.5), "steel_dark", Color.WHITE, 0.08, Vector3(0, 9.4, 0))
	mk.box(Vector3(7.8, 3.4, 0.06), "black", Color.WHITE, 0.0, Vector3(0, 9.4, 0.27))
	# seven-segment style score "2 : 1" and a clock bar, all emissive boxes
	for dgt: Array in [[-2.4, "window"], [2.4, "cyan"]]:
		var x: float = dgt[0]
		for yy: float in [10.3, 9.4, 8.5]:
			mk.box(Vector3(1.1, 0.2, 0.05), String(dgt[1]), Color.WHITE, 0.0, Vector3(x, yy, 0.31))
		mk.box(Vector3(0.2, 0.9, 0.05), String(dgt[1]), Color.WHITE, 0.0, Vector3(x + 0.55, 9.85, 0.31))
		mk.box(Vector3(0.2, 0.9, 0.05), String(dgt[1]), Color.WHITE, 0.0, Vector3(x - 0.55 * signf(x), 8.95, 0.31))
	for yy: float in [9.75, 9.05]:
		mk.box(Vector3(0.22, 0.22, 0.05), "hazard_red", Color.WHITE, 0.0, Vector3(0, yy, 0.31))
	mk.box(Vector3(3.0, 0.16, 0.05), "hazard_red", Color.WHITE, 0.0, Vector3(0, 7.95, 0.31))
	mk.pop()


static func add_tyres(mk: TLMesh, o: Vector3, yaw: float = 0.0, cols: int = 5) -> void:
	mk.push_at(o, Vector3(0, yaw, 0))
	for c: int in cols:
		for l: int in 3:
			var key: String = "tire" if (c + l) % 3 != 0 else ("curb_white" if l % 2 == 0 else "curb_red")
			mk.cyl(0.36, 0.24, 9, key, Color.WHITE, -1.0, Vector3((float(c) - float(cols - 1) * 0.5) * 0.76, l * 0.25, 0))
	mk.pop()


static func add_marshal_post(mk: TLMesh, o: Vector3, yaw: float = 0.0) -> void:
	mk.push_at(o, Vector3(0, yaw, 0))
	for sx: float in [-0.9, 0.9]:
		for sz: float in [-0.7, 0.7]:
			mk.bar(Vector3(sx, 0, sz), Vector3(sx, 3.4, sz), 0.1, 0.1, "wood_dark", Color.WHITE)
	mk.box(Vector3(2.2, 0.12, 1.8), "plank", Color.WHITE, 0.02, Vector3(0, 1.2, 0))
	mk.box(Vector3(2.2, 0.7, 0.08), "hot", Color.WHITE, 0.02, Vector3(0, 1.75, -0.86))
	mk.box(Vector3(2.2, 0.14, 0.09), "curb_white", Color.WHITE, 0.0, Vector3(0, 1.75, -0.87))
	mk.hull([Vector3(-1.3, 3.4, -1.1), Vector3(1.3, 3.4, -1.1), Vector3(-1.3, 3.4, 1.1), Vector3(1.3, 3.4, 1.1), Vector3(-1.3, 3.75, -1.1), Vector3(1.3, 3.75, -1.1), Vector3(-1.3, 3.5, 1.1), Vector3(1.3, 3.5, 1.1)], "roof")
	add_ladder(mk, Vector3(1.3, 0, 0.3), Vector3(1.0, 1.25, 0.3))
	mk.pop()
	add_flag(mk, o + Vector3(0, 3.6, 0), 2.2, "flag_a")


static func add_entrance(mk: TLMesh, o: Vector3, yaw: float = 0.0) -> void:
	mk.push_at(o, Vector3(0, yaw, 0))
	for sx: float in [-3.4, 3.4]:
		mk.box(Vector3(1.4, 5.2, 1.4), "concrete", Color.WHITE, 0.1, Vector3(sx, 2.6, 0))
		mk.box(Vector3(1.7, 0.4, 1.7), "concrete_dark", Color.WHITE, 0.06, Vector3(sx, 5.3, 0))
	mk.box(Vector3(8.6, 1.3, 1.1), "concrete", Color.WHITE, 0.08, Vector3(0, 6.0, 0))
	mk.box(Vector3(5.6, 0.8, 0.1), "seat", Color.WHITE, 0.02, Vector3(0, 6.0, 0.6))
	for i: int in 5:
		mk.box(Vector3(0.6, 0.45, 0.05), "boards", Color.WHITE, 0.0, Vector3(-2.0 + i * 1.0, 6.0, 0.67))
	mk.pop()


## Humpback stone arch bridge along local X. Origin at the water line under its centre. Any span count and length.
static func add_bridge(mk: TLMesh, o: Vector3, yaw: float = 0.0, length: float = 26.0, width: float = 4.6, spans: int = 3, rise: float = 4.2) -> void:
	mk.push_at(o, Vector3(0, yaw, 0))
	var hl: float = length * 0.5
	var hw: float = width * 0.5
	var pier: float = 1.3
	var span: float = (length - pier * float(spans + 1)) / float(spans)
	var deck: Callable = func(x: float) -> float: return rise + 1.3 - 1.6 * pow(clampf(x / hl, -1.0, 1.0), 2.0)
	for s: int in spans + 1:
		var px: float = -hl + pier * 0.5 + float(s) * (span + pier)
		var dy: float = deck.call(px)
		mk.boxm(Vector3(px - pier * 0.5, -1.6, -hw), Vector3(px + pier * 0.5, dy, hw), "stone", Color.WHITE, 0.06)
		mk.box(Vector3(pier * 1.5, 1.3, width + 1.2), "stone_dark", Color.WHITE, 0.2, Vector3(px, -0.3, 0))
	var K: int = 6
	for s: int in spans:
		var x0: float = -hl + pier + float(s) * (span + pier)
		var ah: float = rise * (0.82 + 0.18 * (1.0 - absf(float(s) - float(spans - 1) * 0.5) / maxf(1.0, float(spans) * 0.5)))
		for k: int in K:
			var a0: float = PI * float(k) / float(K)
			var a1: float = PI * float(k + 1) / float(K)
			var xa: float = x0 + span * 0.5 - cos(a0) * span * 0.5
			var xb: float = x0 + span * 0.5 - cos(a1) * span * 0.5
			var ya: float = sin(a0) * ah
			var yb: float = sin(a1) * ah
			var da: float = deck.call(xa)
			var db: float = deck.call(xb)
			var tone: float = 0.93 + 0.09 * float((k + s) % 2)
			mk.hull([Vector3(xa, ya, -hw), Vector3(xb, yb, -hw), Vector3(xa, da, -hw), Vector3(xb, db, -hw), Vector3(xa, ya, hw), Vector3(xb, yb, hw), Vector3(xa, da, hw), Vector3(xb, db, hw)], "stone", Color(tone, tone, tone))
			for sz: float in [-hw - 0.1, hw + 0.1]:
				mk.bar(Vector3(xa, ya, sz), Vector3(xb, yb, sz), 0.2, 0.55, "stone_dark", Color.WHITE)
	var de: float = deck.call(hl)
	for sg: float in [-1.0, 1.0]:   # approach ramps down to the banks
		mk.hull([Vector3(sg * hl, -1.2, -hw), Vector3(sg * hl, de, -hw), Vector3(sg * (hl + 11.0), -1.2, -hw), Vector3(sg * (hl + 11.0), 0.5, -hw),
			Vector3(sg * hl, -1.2, hw), Vector3(sg * hl, de, hw), Vector3(sg * (hl + 11.0), -1.2, hw), Vector3(sg * (hl + 11.0), 0.5, hw)], "stone")
	var P: int = 10
	for i: int in P:   # parapets follow the hump
		var xa2: float = lerpf(-hl, hl, float(i) / float(P))
		var xb2: float = lerpf(-hl, hl, float(i + 1) / float(P))
		var pa: float = deck.call(xa2)
		var pb: float = deck.call(xb2)
		for sz: float in [-hw, hw]:
			mk.bar(Vector3(xa2, pa + 0.4, sz), Vector3(xb2, pb + 0.4, sz), 0.45, 0.85, "stone_dark", Color.WHITE, 0.05)
	mk.pop()


## Flat irregular sheet (a frozen pond, a pool) of half-sizes rx, rz lying 6 cm above the ground at o.
static func add_pond(mk: TLMesh, o: Vector3, rx: float = 30.0, rz: float = 20.0, key: String = "pond_ice", seg: int = 22) -> void:
	var pts: Array = []
	for i: int in seg:
		var a: float = TAU * float(i) / float(seg)
		var k: float = 1.0 + 0.10 * sin(a * 3.0 + 0.7) + 0.06 * sin(a * 5.0 + 2.1)
		pts.append(o + Vector3(cos(a) * rx * k, 0.06, sin(a) * rz * k))
	var lake: bool = not TLStyle.is_toon(key)   # layout D edit 2 (after the freeze): a water key makes a lake with a sand shore
	for i: int in seg:
		var t: float = 0.94 + 0.08 * float(i % 3) / 2.0
		if lake:
			var p0: Vector3 = pts[i]
			var p1: Vector3 = pts[(i + 1) % seg]
			mk.tri(o + Vector3(0, 0.06, 0), p1, p0, key, Color.WHITE, Vector2(-1.0, 0.5), Vector2(-1.0, 1.0), Vector2(-1.0, 1.0))   # UV.x = -1 tells water.gdshader "still water"
			var s0: Vector3 = o + (p0 - o) * 1.0 + (p0 - o).normalized() * (2.2 + 0.9 * float(i % 2)) - Vector3(0, 0.03, 0)
			var s1: Vector3 = o + (p1 - o) * 1.0 + (p1 - o).normalized() * (2.2 + 0.9 * float((i + 1) % 2)) - Vector3(0, 0.03, 0)
			mk.quad_up(p0 - Vector3(0, 0.03, 0), p1 - Vector3(0, 0.03, 0), s1, s0, "sand", Color(t, t, t))
			continue
		mk.quad_up(o + Vector3(0, 0.06, 0), pts[i], pts[(i + 1) % seg], pts[(i + 1) % seg], key, Color(t, t, t))


## pass 4, AFTER the layout-D freeze (layout D edit 1): a timber watch tower. Prop kind `watch_tower`, a = [height].
static func add_watch_tower(mk: TLMesh, o: Vector3, yaw: float = 0.0, h: float = 9.0) -> void:
	mk.push_at(o, Vector3(0, yaw, 0))
	var b: float = 1.9
	var t: float = 1.25
	var cs: Array = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for c: Vector2 in cs:
		mk.bar(Vector3(c.x * b, 0, c.y * b), Vector3(c.x * t, h, c.y * t), 0.24, 0.24, "wood_dark", Color.WHITE)
		mk.bar(Vector3(c.x * (t + 0.45), h + 0.2, c.y * (t + 0.45)), Vector3(c.x * (t + 0.45), h + 2.3, c.y * (t + 0.45)), 0.16, 0.16, "wood_dark", Color.WHITE)
	for l: int in 3:
		var w0: float = lerpf(b, t, float(l) / 3.0)
		var w1: float = lerpf(b, t, float(l + 1) / 3.0)
		for k: int in 4:
			var c0: Vector2 = cs[k]
			var c1: Vector2 = cs[(k + 1) % 4]
			var f: bool = (l + k) % 2 == 0
			mk.bar(Vector3(c0.x * (w0 if f else w1), h * float(l if f else l + 1) / 3.0, c0.y * (w0 if f else w1)), Vector3(c1.x * (w1 if f else w0), h * float(l + 1 if f else l) / 3.0, c1.y * (w1 if f else w0)), 0.13, 0.13, "wood", Color.WHITE)
			mk.bar(Vector3(c0.x * w1, h * float(l + 1) / 3.0, c0.y * w1), Vector3(c1.x * w1, h * float(l + 1) / 3.0, c1.y * w1), 0.14, 0.14, "wood_dark", Color.WHITE)
	var dw: float = (t + 0.6) * 2.0
	mk.box(Vector3(dw, 0.18, dw), "plank", Color.WHITE, 0.03, Vector3(0, h + 0.1, 0))
	for k: int in 4:   # parapet: three plank walls and an open side with a rail
		var c0: Vector2 = cs[k] * (t + 0.45)
		var c1: Vector2 = cs[(k + 1) % 4] * (t + 0.45)
		if k == 1:
			mk.bar(Vector3(c0.x, h + 1.15, c0.y), Vector3(c1.x, h + 1.15, c1.y), 0.1, 0.1, "wood_dark", Color.WHITE)
		else:
			mk.bar(Vector3(c0.x, h + 0.7, c0.y), Vector3(c1.x, h + 0.7, c1.y), 0.08, 0.95, "wood_light", Color(0.95, 0.95, 0.95))
	var e: float = t + 1.1
	mk.hull([Vector3(-e, h + 2.3, -e), Vector3(e, h + 2.3, -e), Vector3(e, h + 2.3, e), Vector3(-e, h + 2.3, e), Vector3(-0.25, h + 3.5, -0.25), Vector3(0.25, h + 3.5, -0.25), Vector3(0.25, h + 3.5, 0.25), Vector3(-0.25, h + 3.5, 0.25)], "roof")
	add_ladder(mk, Vector3(b + 0.9, 0, 0.5), Vector3(t + 0.55, h + 0.2, 0.5))
	mk.pop()
	add_flag(mk, o + Vector3(0, h + 3.4, 0), 2.4, "flag_b")
