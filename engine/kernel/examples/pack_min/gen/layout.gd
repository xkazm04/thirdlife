extends RefCounted
## Asset generator: runs before the entry script. This one only prepares data (where the balls start), from ctx.rng,
## and leaves it under ctx.root as metadata for the entry script. A real generator would build kit parts here.


static func generate(ctx) -> void:
	var tuning: Dictionary = ctx.read_json("tuning.json")
	var starts: Array = []
	for i: int in int(tuning["balls"]):
		starts.append(Vector3(-4.0 + ctx.rng.randf_range(-0.4, 0.4), 4.0 + float(i) * 0.9, ctx.rng.randf_range(-2.0, 2.0)))
	ctx.root.set_meta("ball_starts", starts)
