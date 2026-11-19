extends RefCounted
## Field-guide ground cover. Sample a fixed lattice in village metres, including just the cells
## around the view. The ink marks and tree groups stay on the ground as the camera recentres.

const Art = preload("res://ui/editor/workshop_art.gd")


static func paint(map: Control, world: Rect2, scale: float, col: Dictionary) -> void:
	var offset: Vector2 = -world.position * scale
	_ground(map, world, scale, col)
	var rng := RandomNumberGenerator.new()
	var area := world.grow(70)
	for y: int in range(floori(area.position.y / 102), ceili(area.end.y / 102)):
		for x: int in range(floori(area.position.x / 102), ceili(area.end.x / 102)):
			rng.seed = hash(Vector3i(x, y, 13))
			var c := (Vector2(x, y) * 102 + Vector2(rng.randf_range(8, 70), rng.randf_range(8, 80))) * scale + offset
			var radii := Vector2(rng.randf_range(25, 68), rng.randf_range(11, 28)) * scale
			var tilt := rng.randf_range(-0.48, 0.4)
			var phase := rng.randf_range(-PI, PI)
			var pts := PackedVector2Array()
			for i: int in 44:
				var a := TAU * i / 44.0
				var v := Vector2.from_angle(a) * (1.0 + 0.14 * sin(3 * a + phase) + 0.07 * sin(5 * a - phase))
				pts.append(c + (v * radii).rotated(tilt))
			var light := rng.randf() > 0.47
			var tint: Color = col["meadow_light"] if light else col["meadow_dark"]
			map.draw_colored_polygon(pts, Color(tint, 0.29))
			# Two short changes in tone along a bank pick out its slope in the sunlight.
			var edge := pts.slice(5, 20)
			map.draw_polyline(edge, Color(tint, 0.44), maxf(1, 0.7 * scale), true)
			for i: int in edge.size():
				edge[i] = c + (edge[i] - c) * 1.085
			map.draw_polyline(edge, Color(tint, 0.36), 1, true)

	for y: int in range(floori(area.position.y / 13), ceili(area.end.y / 13)):
		for x: int in range(floori(area.position.x / 13), ceili(area.end.x / 13)):
			rng.seed = hash(Vector3i(x, y, 31))
			var pos := (Vector2(x, y) + Vector2(rng.randf(), rng.randf())) * 13 * scale + offset
			var h := rng.randf_range(0.85, 2.0) * scale
			if not Rect2(Vector2.ZERO, map.size).grow(h * 4).has_point(pos):
				continue
			var ink := Color(col["green"], 0.21 if scale < 1.35 else 0.30)
			map.draw_line(pos + Vector2(-h, -0.7 * h), pos, ink, 1, true)
			map.draw_line(pos + Vector2(0.45 * h, -1.4 * h), pos, ink, 1, true)
			map.draw_line(pos + Vector2(1.7 * h, -0.5 * h), pos + Vector2(h, 0), Color(col["paper"], 0.28), 1, true)
	for y: int in range(floori(area.position.y / 29), ceili(area.end.y / 29)):
		for x: int in range(floori(area.position.x / 29), ceili(area.end.x / 29)):
			rng.seed = hash(Vector3i(x, y, 71))
			if rng.randf() < 0.59:
				continue
			var w := (Vector2(x, y) + Vector2(rng.randf(), rng.randf())) * 29
			# The road and the occupied plots have their own surface dressing.
			if map.model.road_point(w).distance_to(w) < map.model.road_half_m + 7:
				continue
			var clear: bool = not map.model.placed or w.distance_to(map.model.at) > map.model.lot_radius() + 6
			for plot: Dictionary in map.model.plots:
				if w.distance_to(plot["at"]) < float(plot["r"]) + 4:
					clear = false
					break
			if not clear:
				continue
			var tree: String = ["pine", "pine", "copse", "stone"][rng.randi_range(0, 3)]
			var count := rng.randi_range(1, 3)
			for i: int in count:
				var scatter := Vector2(i * rng.randf_range(3.3, 7.6), i * rng.randf_range(-1.7, 3.6))
				var foot := (w + scatter) * scale + offset
				var height := rng.randf_range(10.5, 18.2) * scale
				if tree == "stone":
					height *= 0.54
				var symbol := Rect2(foot - Vector2(height * 0.72, height * 0.93), Vector2(height * 1.44, height))
				map.draw_colored_polygon(PackedVector2Array([foot - Vector2(0, height * 0.2), foot + Vector2(height * 0.72, height * 0.03), foot + Vector2(height * 0.5, height * 0.17), foot - Vector2(height * 0.18, 0)]), Color(col["shade"], 0.22))
				map.draw_texture_rect(Art.stamp(tree, col, symbol.size.x), symbol, false)


## Two scales of colour in the meadow: a continuous sun-warmed wash below the distinct
## banks and blades. The seamless swatch is generated once and has no scene material.
static func _ground(map: Control, world: Rect2, scale: float, col: Dictionary) -> void:
	var cache: Dictionary = col["stamps"]
	if not cache.has("meadow_wash"):
		var noise := FastNoiseLite.new()
		noise.seed = 7
		noise.frequency = 0.014
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_octaves = 4
		var grain := noise.get_seamless_image(256, 256)
		grain.convert(Image.FORMAT_L8)
		var values := grain.get_data()
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([col["meadow_dark"].lerp(col["pine_light"], 0.24),
			col["map"], col["meadow_light"].lerp(col["wood"], 0.31)])
		gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
		var lut := PackedInt64Array()
		for i: int in 256:
			lut.append(gradient.sample(i / 255.0).lerp(col["map"], 0.28).to_rgba32())
		var rgb := PackedByteArray()
		rgb.resize(values.size() * 3)
		for i: int in values.size():
			var swatch := lut[values[i]]
			rgb[3*i] = (swatch >> 24) & 255
			rgb[3*i+1] = (swatch >> 16) & 255
			rgb[3*i+2] = (swatch >> 8) & 255
		cache["meadow_wash"] = ImageTexture.create_from_image(Image.create_from_data(256, 256, false, Image.FORMAT_RGB8, rgb))
	var period := 136.0
	for y: int in range(floori(world.position.y / period), ceili(world.end.y / period)):
		for x: int in range(floori(world.position.x / period), ceili(world.end.x / period)):
			var at := ((Vector2(x, y) * period - world.position) * scale).round()
			var end := ((Vector2(x+1, y+1) * period - world.position) * scale).round()
			map.draw_texture_rect(cache["meadow_wash"], Rect2(at, end-at), false)
