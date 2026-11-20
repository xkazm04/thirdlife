extends RefCounted
## Diorama day (20 Nov 2026), nature and dressing, the second file of kits/tl_felt.gd (whose size is ratcheted): what
## is strewn and built round the felt things. Slab stacks (the mesas), the turned fence, pebbles, roadside dressing,
## meadow tufts, grit, and a scaffold's wooden dowels. Presentation only, under the same style keys; a kit recipe is
## never changed here.

const Felt: GDScript = preload("res://kits/tl_felt.gd")


## A closed outline through `pts` (a polygon), rounded: `n` points on the curve through its corners.
static func round_outline(pts: PackedVector2Array, n: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var m: int = pts.size()
	for i: int in n:
		var t: float = float(i) / float(n) * float(m)
		var k: int = int(t)
		var f: float = t - float(k)
		out.append(pts[k % m].cubic_interpolate(pts[(k + 1) % m], pts[(k + m - 1) % m], pts[(k + 2) % m], f))
	return out


## A bluff as slabs of clay laid one on another (the mesas of the skyline): `unit` = its rounded outline (radius about
## 1), from height y0 to y1, reach r0 at the foot and r1 at the top, `slabs` layers. Each slab is rolled (its side
## bulges, its edges turn in), sits a little off the one below and has a tone of its own. The top is closed inward.
static func slab_stack(out: TLMesh, key: String, unit: PackedVector2Array, y0: float, y1: float, r0: float, r1: float, slabs: int, col: Color, seed_: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_
	var seg: int = unit.size()
	var rings: Array = []
	var tone: PackedFloat32Array = PackedFloat32Array()
	var hs: float = (y1 - y0) / float(slabs)
	var rr: float = r1
	for k: int in slabs:
		var f: float = pow(float(k) / float(maxi(slabs - 1, 1)), 0.7)
		rr = lerpf(r0, r1, f) * rng.randf_range(0.975, 1.03)
		var off: Vector2 = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * rr * 0.025
		var waves: int = rng.randi_range(3, 6)
		var ph: float = rng.randf() * TAU
		var ph2: float = rng.randf() * TAU
		var bite_at: float = rng.randf() * TAU        # where the knife took a piece off this slab
		var bite_w: float = rng.randf_range(0.25, 0.6)
		var bite: float = rng.randf_range(0.03, 0.09)
		var tk: float = (0.93 if k % 2 == 0 else 1.05) * rng.randf_range(0.96, 1.04)
		var yb: float = y0 + hs * float(k)
		for step: Array in [[0.955, 0.0, 0.86], [1.0, 0.20, 1.0], [1.0, 0.78, 1.0], [0.962, 1.0, 1.08]]:
			var ring: PackedVector3Array = PackedVector3Array()
			for i: int in seg:
				var a: float = TAU * float(i) / float(seg)
				var cut: float = bite * (1.0 - smoothstep(0.0, bite_w, absf(angle_difference(a, bite_at))))
				var q: Vector2 = unit[i] * rr * float(step[0]) * (1.0 + 0.03 * sin(a * float(waves) + ph) + 0.018 * sin(a * float(waves * 2 + 3) + ph2) - cut) + off
				ring.append(Vector3(q.x, yb + hs * float(step[1]), q.y))
			rings.append(ring)
			tone.append(tk * float(step[2]))
	var lid: PackedVector3Array = PackedVector3Array()
	for i: int in seg:
		lid.append(Vector3(unit[i].x * rr * 0.45, y1, unit[i].y * rr * 0.45))
	rings.append(lid)
	tone.append(1.0)
	Felt._grid(out, key, rings, seg, col, tone, false)


## A rail fence as a hand would build it for a diorama: turned posts, a little out of true, and round rails from post
## to post (the kit's fence is square bars). The same places and the same reach as TLKitSite.add_fence.
static func fence(mk: TLMesh, a: Vector3, b: Vector3, post_gap: float) -> void:
	var l: float = a.distance_to(b)
	var n: int = maxi(1, roundi(l / post_gap))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(a) ^ hash(b)
	var tops: Array = []
	for i: int in n + 1:
		var p: Vector3 = a.lerp(b, float(i) / float(n))
		var lean: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * 0.035
		var h: float = 1.26 + rng.randf_range(-0.05, 0.06)
		var top: Vector3 = p + Vector3(0, h, 0) + lean
		mk.cyl_between(p - Vector3(0, 0.15, 0), top, 0.125, 12, "wood_dark", Color.WHITE, 0.112)
		mk.cyl_between(top, top + (top - p).normalized() * 0.035, 0.112, 12, "wood_light", Color(0.92, 0.92, 0.92), 0.085)     # the sawn end, chamfered
		tops.append([p, lean / h])
	for i: int in n:
		for h: float in [0.50, 0.96]:
			var p0: Vector3 = (tops[i][0] as Vector3) + Vector3(0, h + rng.randf_range(-0.035, 0.035), 0) + (tops[i][1] as Vector3) * h
			var p1: Vector3 = (tops[i + 1][0] as Vector3) + Vector3(0, h + rng.randf_range(-0.035, 0.035), 0) + (tops[i + 1][1] as Vector3) * h
			var d: Vector3 = (p1 - p0).normalized()
			var tone: float = rng.randf_range(0.9, 1.08)
			mk.cyl_between(p0 - d * 0.10, p1 + d * 0.10, 0.062, 10, "wood", Color(tone, tone, tone))


## Pebbles of rolled clay strewn on the roads (the drawn ones of the road shader are discs): Transform3D each, for
## three recipes. `terr` is the village terrain (road_dist, gy), `box` its extent. Its own stream; nothing else moves.
static func pebbles(terr: RefCounted, seed_: int, box: Rect2, road_half: float, want: int) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_ + 4242
	var out: Array = [[], [], []]
	var made: int = 0
	var tries: int = 0
	while made < want and tries < want * 400:
		tries += 1
		var p: Vector2 = box.position + Vector2(rng.randf() * box.size.x, rng.randf() * box.size.y)
		if float(terr.call("road_dist", p.x, p.y)) > road_half + 0.6:
			continue
		for q: int in rng.randi_range(2, 7):          # they lie in little strews, one large with small ones round it
			var pp: Vector2 = p + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * 2.4
			var sc: float = rng.randf_range(0.07, 0.14) if q > 0 else rng.randf_range(0.14, 0.27)
			var bs: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.6, 0.95), sc * rng.randf_range(0.75, 1.25)))
			(out[rng.randi_range(0, 2)] as Array).append(Transform3D(bs, Vector3(pp.x, float(terr.call("gy", pp.x, pp.y)) + sc * 0.12, pp.y)))
			made += 1
	# ... and stones along the river: larger, half sunk in the bank, a few of them in the shallows
	var river: Dictionary = terr.get("river") if terr.get("river") is Dictionary else {}
	var rhalf: float = float(river.get("half", 0.0))
	made = 0
	tries = 0
	while rhalf > 0.0 and made < want / 3 and tries < want * 400:
		tries += 1
		var p: Vector2 = box.position + Vector2(rng.randf() * box.size.x, rng.randf() * box.size.y)
		var rd: float = float(terr.call("river_dist", p.x, p.y))
		if rd < rhalf * 0.72 or rd > rhalf + 2.6:
			continue
		var sc: float = rng.randf_range(0.14, 0.5) * (0.7 if rd < rhalf else 1.0)
		var bs: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.6, 0.9), sc * rng.randf_range(0.75, 1.25)))
		(out[rng.randi_range(0, 2)] as Array).append(Transform3D(bs, Vector3(p.x, float(terr.call("gy", p.x, p.y)) + sc * 0.05, p.y)))
		made += 1
	return out


## Dressing of the roadsides, as a diorama builder strews it where the eye goes: knee-high felt pines, felt balls and
## stones a walker steps over (nothing here is tall enough to need a collider: the village's bushes have none either).
## Returns [pines, bushes, stones] (Transform3D each). `is_free` is the landscape's own test (plots, roads, river).
## Its own stream; nothing else moves.
static func dressing(terr: RefCounted, seed_: int, box: Rect2, road_half: float, is_free: Callable, want: int) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_ + 9191
	var out: Array = [[], [], []]
	var made: int = 0
	var tries: int = 0
	while made < want and tries < want * 500:
		tries += 1
		var p: Vector2 = box.position + Vector2(rng.randf() * box.size.x, rng.randf() * box.size.y)
		var rd: float = float(terr.call("road_dist", p.x, p.y))
		if rd < road_half + 1.6 or rd > road_half + 11.0:
			continue
		var n: int = rng.randi_range(1, 4)          # in little groups: a pine with a ball and a stone at its foot
		for q: int in n:
			var pp: Vector2 = p + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * 2.2
			if float(terr.call("road_dist", pp.x, pp.y)) < road_half + 1.2 or float(terr.call("slope", pp.x, pp.y)) > 0.24:
				continue
			if not bool(is_free.call(pp, 4.0, road_half + 0.6, 3.0)):
				continue
			var kind: int = 0 if q == 0 and rng.randf() < 0.7 else (1 if rng.randf() < 0.55 else 2)
			var y: float = float(terr.call("gy", pp.x, pp.y))
			var sc: float = rng.randf_range(0.075, 0.12) if kind == 0 else (rng.randf_range(0.32, 0.62) if kind == 1 else rng.randf_range(0.22, 0.42))     # a pine to the knee or the hip, never a tree he would run through
			var bs: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.15), sc))
			(out[kind] as Array).append(Transform3D(bs, Vector3(pp.x, y - (0.02 if kind == 0 else 0.06 * sc), pp.y)))
			made += 1
	return out


static func dowels_on() -> bool:
	return not TLStyle.headless() and TLStyle.num("detail", "dowels", 0.0) > 0.0


## A kit frame of square steel bars (a scaffold) drawn as a hand would build it for a diorama: turned wooden dowels.
## Every bar of a key in `keys` ({recipe key: wood key}) becomes a round dowel of the wood key, a little stouter, its
## grain along it; everything that is not a bar (decks, foot plates) is kept. The recipe is untouched and stays the
## part's identity (hash, triangles, collider). Null when the style does not ask (`detail.dowels`) and not `force`.
static func dowels(mk: TLMesh, mesh_name: String, keys: Dictionary, force: bool = false) -> ArrayMesh:
	if not force and not dowels_on():
		return null
	var out: TLMesh = TLMesh.new(1)
	var made: int = 0
	var kept_by_key: Dictionary = {}
	for key: String in mk.surfs:
		var s: TLMesh.Surf = mk.surfs[key]
		if not keys.has(key) or s.b.size() > 0:
			kept_by_key[key] = s
			continue
		var kept: TLMesh.Surf = TLMesh.Surf.new()
		kept.k16 = s.k16
		for comp: Array in Felt._components(s.v):
			var c: Vector3 = Vector3.ZERO
			for i: int in comp:
				c += s.v[i]
			c /= float(comp.size())
			var cov: Basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
			for i: int in comp:
				var d: Vector3 = s.v[i] - c
				cov.x += d * d.x
				cov.y += d * d.y
				cov.z += d * d.z
			var a: Vector3 = Vector3(0.61, 0.53, 0.59)
			for it: int in 24:               # the long axis: the direction the points spread most along
				var na: Vector3 = cov * a
				if na.length_squared() < 1e-20:
					break
				a = na.normalized()
			var t0: float = INF
			var t1: float = -INF
			var rmax: float = 0.0
			for i: int in comp:
				var d: Vector3 = s.v[i] - c
				var t: float = d.dot(a)
				t0 = minf(t0, t)
				t1 = maxf(t1, t)
				rmax = maxf(rmax, (d - a * t).length())
			if t1 - t0 > 3.0 * rmax and rmax < 0.2 and rmax > 0.005:
				# eight faces round, an end face only where an end can be seen from above (a post's top): a scaffold is
				# hundreds of bars, and the sun's shadow draws each of them four times over
				var yy: Vector3 = a if a.y >= 0.0 else -a
				var up: Vector3 = Vector3.RIGHT if absf(yy.x) < 0.95 else Vector3.FORWARD
				var zz: Vector3 = up.cross(yy).normalized()
				out.push(Transform3D(Basis(yy.cross(zz), yy, zz), c + yy * (t0 if a.y >= 0.0 else -t1)))
				out.cyl(rmax * 0.7071 * 1.22, t1 - t0, 8, String(keys[key]), s.c[comp[0]], -1.0, Vector3.ZERO, yy.y > 0.9, false)
				out.pop()
				made += 1
			else:
				for i: int in comp:
					kept.v.append(s.v[i]); kept.n.append(s.n[i]); kept.c.append(s.c[i]); kept.uv.append(s.uv[i])
					for j: int in 4:
						kept.cu.append(s.cu[i * 4 + j])
					if s.uv2.size() > i:
						if kept.uv2.size() < kept.v.size() - 1:
							kept.uv2.resize(kept.v.size() - 1)
						kept.uv2.append(s.uv2[i])
		if kept.v.size() > 0:
			kept_by_key[key] = kept
	if made == 0:
		return null
	for key: String in kept_by_key:          # what was kept, joined to a dowel surface of the same key when there is one
		var k: TLMesh.Surf = kept_by_key[key]
		if not out.surfs.has(key):
			out.surfs[key] = k
			continue
		var have: TLMesh.Surf = out.surfs[key]
		have.v.append_array(k.v); have.n.append_array(k.n); have.c.append_array(k.c); have.uv.append_array(k.uv)
		TLMesh.Bake.join(have, k)
		have.cu.append_array(k.cu)
	var m: ArrayMesh = out.build(mesh_name)
	m.set_meta("tl_look_tris", out.tri_count)
	m.set_meta("tl_hash", mk.content_hash())
	m.set_meta("tl_tris", mk.tri_count)
	return m


## Flock tufts over the whole meadow, in drifts (the board's flock is not a lawn: it stands in tufts): two lots of
## Transform3D, one for each dye. Never on a road, a plot or the river (`is_free`), never on a steep bank.
static func meadow_tufts(terr: RefCounted, seed_: int, box: Rect2, road_half: float, is_free: Callable, want: int) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_ + 7373
	var out: Array = [[], []]
	var made: int = 0
	var tries: int = 0
	while made < want and tries < want * 40:
		tries += 1
		var p: Vector2 = box.position + Vector2(rng.randf() * box.size.x, rng.randf() * box.size.y)
		# two drifts in three stand where the eye goes: within a stone's throw of a road (the land knows 13 m round one)
		if made % 3 != 0 and float(terr.call("road_dist", p.x, p.y)) > 12.5:
			continue
		if not bool(is_free.call(p, 3.0, road_half + 1.2, 2.5)) or float(terr.call("slope", p.x, p.y)) > 0.28:
			continue
		var dye: int = 0 if rng.randf() < 0.55 else 1
		for q: int in rng.randi_range(4, 11):          # a drift of them, close together
			var pp: Vector2 = p + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * rng.randf() * 3.4
			if float(terr.call("road_dist", pp.x, pp.y)) < road_half + 0.9:
				continue
			var sc: float = rng.randf_range(0.55, 1.5)
			var bs: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.7, 1.3), sc * rng.randf_range(0.8, 1.25)))
			(out[dye if rng.randf() < 0.8 else 1 - dye] as Array).append(Transform3D(bs, Vector3(pp.x, float(terr.call("gy", pp.x, pp.y)), pp.y)))
			made += 1
	return out


## The grit of a road: small stones strewn all over it, evenly (the board's road is strewn; the pebbles of `pebbles`
## lie in little strews with shadows, these are too small to cast one). Two lots of Transform3D.
static func grit(terr: RefCounted, seed_: int, box: Rect2, road_half: float, want: int) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_ + 5151
	var out: Array = [[], []]
	var made: int = 0
	var tries: int = 0
	while made < want and tries < want * 400:
		tries += 1
		var p: Vector2 = box.position + Vector2(rng.randf() * box.size.x, rng.randf() * box.size.y)
		if float(terr.call("road_dist", p.x, p.y)) > road_half + 0.9:
			continue
		for q: int in rng.randi_range(3, 8):
			var pp: Vector2 = p + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * 1.6
			var sc: float = rng.randf_range(0.5, 1.6)
			var bs: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.6, 1.0), sc * rng.randf_range(0.7, 1.4)))
			(out[rng.randi_range(0, 1)] as Array).append(Transform3D(bs, Vector3(pp.x, float(terr.call("gy", pp.x, pp.y)), pp.y)))
			made += 1
	return out
