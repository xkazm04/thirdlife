class_name TLKitNature
extends RefCounted
## Kit parts for nature. Each returns an ArrayMesh template (scattered with MultiMesh) or a node.
##   pine(seed, h, tiers)     faceted conifer from stacked cones
##   broadleaf(seed, h)       trunk + jittered blobs (hero tree is a bigger one with branches)
##   rock(seed, r, flat)      jittered low-poly boulder
##   bush(seed, r)            small foliage blob
##   grass_tuft(seed)         crossed blades with up-normals and tip-weighted sway (COLOR.a = sway weight)


static func pine(seed_: int, h: float = 9.0, tiers: int = 5, r: float = 2.2) -> TLMesh:
	var mk: TLMesh = TLMesh.new(seed_)
	mk.cyl(0.22 * h / 9.0, h * 0.3, 6, "trunk", Color.WHITE, 0.14 * h / 9.0)
	for i: int in tiers:
		var f: float = float(i) / float(tiers)
		var rr: float = r * (1.0 - f * 0.72) * (0.92 + 0.16 * mk.rng.randf())
		var y: float = h * (0.16 + f * 0.62)
		var ht: float = h * (0.36 - f * 0.12)
		var tint: float = 0.86 + 0.34 * f
		mk.push_at(Vector3(0, y, 0), Vector3(0, mk.rng.randf() * 60.0, 0))
		mk.cyl(rr, ht, 7, "pine_light" if i % 2 == 0 else "pine", Color(tint, tint, tint), 0.0)
		mk.pop()
	return mk


static func broadleaf(seed_: int, h: float = 7.0) -> TLMesh:
	var mk: TLMesh = TLMesh.new(seed_)
	mk.cyl(0.28 * h / 7.0, h * 0.55, 6, "trunk", Color.WHITE, 0.17 * h / 7.0)
	var n: int = 4
	for i: int in n:
		var a: float = TAU * float(i) / float(n) + mk.rng.randf() * 0.8
		var rr: float = h * (0.22 + 0.1 * mk.rng.randf())
		var p: Vector3 = Vector3(cos(a) * h * 0.2, h * (0.62 + 0.14 * mk.rng.randf()), sin(a) * h * 0.2)
		mk.blob(Vector3(rr, rr * 0.85, rr), 1, 0.2, "leaf" if i % 2 == 0 else "leaf_light", Color.WHITE, 0.08, p)
	mk.blob(Vector3(h * 0.27, h * 0.24, h * 0.27), 1, 0.2, "leaf_light", Color.WHITE, 0.08, Vector3(0, h * 0.88, 0))
	return mk


static func hero_tree() -> TLMesh:
	var mk: TLMesh = TLMesh.new(77)
	var h: float = 15.0
	# trunk: stacked tapered prisms with a lean, plus two limbs
	var pts: Array = [Vector3(0, 0, 0), Vector3(0.3, 4.0, 0.2), Vector3(0.1, 8.0, -0.3), Vector3(0.7, 12.0, 0.1)]
	for i: int in pts.size() - 1:
		var r0: float = 0.85 - 0.18 * i
		var r1: float = 0.85 - 0.18 * (i + 1)
		mk.cyl_between(pts[i], pts[i + 1], r0, 7, "trunk", Color(0.95 + 0.05 * (i % 2), 0.95, 0.95), r1)
	mk.cyl_between(Vector3(0.2, 6.5, 0), Vector3(3.8, 10.5, 1.0), 0.32, 6, "trunk", Color.WHITE, 0.18)
	mk.cyl_between(Vector3(0.2, 8.5, -0.2), Vector3(-3.4, 12.0, -1.2), 0.3, 6, "trunk", Color.WHITE, 0.16)
	var cl: Array = [[Vector3(0.7, 13.6, 0.1), 4.6], [Vector3(4.2, 11.2, 1.2), 3.4], [Vector3(-3.8, 12.6, -1.4), 3.6], [Vector3(2.0, 16.2, -0.8), 3.0], [Vector3(-1.2, 15.4, 1.4), 3.0]]
	for i: int in cl.size():
		var r: float = cl[i][1]
		mk.blob(Vector3(r, r * 0.8, r), 2, 0.2, "leaf" if i % 2 == 0 else "leaf_light", Color.WHITE, 0.1, cl[i][0])
	return mk


static func rock(seed_: int, r: float = 1.0, flat: float = 0.7) -> TLMesh:
	var mk: TLMesh = TLMesh.new(seed_)
	var k: float = mk.rng.randf()
	mk.blob(Vector3(r, r * flat, r * (0.8 + 0.4 * k)), 1, 0.28, "rock", Color.WHITE, 0.07, Vector3.ZERO, true)
	if mk.rng.randf() > 0.4:
		mk.blob(Vector3(r * 0.5, r * flat * 0.55, r * 0.5), 1, 0.25, "rock_warm", Color.WHITE, 0.07, Vector3(r * 0.7, -r * 0.1, r * 0.35), true)
	return mk


static func bush(seed_: int, r: float = 0.9) -> TLMesh:
	var mk: TLMesh = TLMesh.new(seed_)
	mk.blob(Vector3(r, r * 0.75, r), 1, 0.22, "leaf", Color.WHITE, 0.1, Vector3(0, r * 0.35, 0), true)
	mk.blob(Vector3(r * 0.7, r * 0.55, r * 0.7), 1, 0.22, "leaf_light", Color.WHITE, 0.1, Vector3(r * 0.5, r * 0.5, r * 0.2), true)
	return mk


static func grass_tuft(seed_: int, blades: int = 6, h: float = 0.7) -> TLMesh:
	var mk: TLMesh = TLMesh.new(seed_)
	var up: Vector3 = Vector3.UP
	for i: int in blades:
		var a: float = mk.rng.randf() * TAU
		var d: Vector3 = Vector3(cos(a), 0, sin(a))
		var bh: float = h * (0.6 + 0.6 * mk.rng.randf())
		var lean: float = 0.12 + 0.25 * mk.rng.randf()
		var side: Vector3 = Vector3(-d.z, 0, d.x) * 0.11
		var base: Vector3 = d * (0.06 + 0.12 * mk.rng.randf())
		var tip: Vector3 = base + d * lean * bh + Vector3(0, bh, 0)
		var mid: Vector3 = base + d * lean * bh * 0.3 + Vector3(0, bh * 0.5, 0)
		var dark: Color = Color(0.62, 0.7, 0.45, 0.0)
		var light: Color = Color(1.1, 1.1, 0.9, 1.0)
		var midc: Color = dark.lerp(light, 0.5)
		# two-sided blade (both windings), normals up so the tuft is lit like the ground
		var bl: Vector3 = base - side
		var br: Vector3 = base + side
		var ml: Vector3 = mid - side * 0.6
		var mr: Vector3 = mid + side * 0.6
		mk.tri_n(bl, br, mr, up, up, up, "grass_blade", dark, dark, midc)
		mk.tri_n(bl, mr, ml, up, up, up, "grass_blade", dark, midc, midc)
		mk.tri_n(ml, mr, tip, up, up, up, "grass_blade", midc, midc, light)
		mk.tri_n(br, bl, mr, up, up, up, "grass_blade", dark, dark, midc)
		mk.tri_n(mr, ml, bl, up, up, up, "grass_blade", midc, midc, dark)
		mk.tri_n(mr, ml, tip, up, up, up, "grass_blade", midc, midc, light)
	return mk
