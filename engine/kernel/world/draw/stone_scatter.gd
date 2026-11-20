extends RefCounted
## Display-only scatter. Each group uses a separate seed stream.


## A few stone chips pressed into the road edges. Batch them into one instanced
## mesh; they are below shoe height and never enter the simulation or its RNG.
static func road_grit(terrain: RefCounted, seed_: int, is_free: Callable) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ + 8121
	var chips: Array = []
	for road: Dictionary in terrain.get("roads"):
		var pts: PackedVector2Array = road["pts"]
		for i in range(1, pts.size()):
			if rng.randf() > 0.58:
				continue
			var across := pts[i - 1].direction_to(pts[i]).orthogonal()
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var patch := pts[i - 1].lerp(pts[i], rng.randf()) + side * across * float(road["half"]) * rng.randf_range(0.40, 1.16)
			if not is_free.call(patch, 0.8, 0.0, float(terrain.river.get("half", 6.0)) + 5.0):
				continue
			for k in rng.randi_range(1, 4):
				var p := patch + Vector2(rng.randf_range(-0.46, 0.46), rng.randf_range(-0.40, 0.40))
				var r := rng.randf_range(0.065, 0.17) * (1.0 if k == 0 else 0.62)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(r, r * 0.43, r * 0.77))
				chips.append(Transform3D(basis, Vector3(p.x, terrain.gy(p.x, p.y) + r * 0.04, p.y)))
	return chips


## Half-submerged stones interrupt the edge of the resin and cast onto its surface.
## Locate the actual waterline on the displayed heightfield so a change of bank
## slope or river width cannot leave the stones hanging above the pour.
static func waterline(terrain: RefCounted, seed_: int, is_free: Callable) -> Array:
	var river: Dictionary = terrain.get("river")
	if river.is_empty():
		return []
	var pts: PackedVector2Array = river["pts"]
	var levels: PackedFloat32Array = river["ys"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ + 4147
	var xs: Array = []
	var i := 1
	while i < pts.size() - 1:
		var centre := pts[i]
		var level := levels[i]
		var along := pts[i - 1].direction_to(pts[i + 1])
		var across := along.orthogonal() * (-1.0 if rng.randf() < 0.5 else 1.0)
		i += rng.randi_range(2, 6)
		var wet := centre
		var dry := centre + across * (float(river["half"]) + 8.0)
		if terrain.gy(wet.x, wet.y) >= level or terrain.gy(dry.x, dry.y) <= level:
			continue
		for step in 6:
			var mid := wet.lerp(dry, 0.5)
			if terrain.gy(mid.x, mid.y) < level:
				wet = mid
			else:
				dry = mid
		var radius := rng.randf_range(0.65, 1.32)
		for k in rng.randi_range(2, 5):
			var r := radius if k == 0 else radius * rng.randf_range(0.24, 0.55)
			var p := wet + across * rng.randf_range(-1.65, 0.42) + along * rng.randf_range(-2.0, 2.0)
			if is_free.call(p, r + 0.75, 5.0, -1.0):
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(r, r * 0.67, r * 0.83))
				xs.append(Transform3D(basis, Vector3(p.x, terrain.gy(p.x, p.y) + r * 0.10, p.y)))
	return xs
