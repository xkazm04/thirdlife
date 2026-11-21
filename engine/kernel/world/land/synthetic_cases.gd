extends RefCounted
const Land := preload("res://kernel/world/land/land.gd")
const Record := preload("res://kernel/world/land/land_record.gd")
const Terrain := preload("res://kernel/world/terrain/village_terrain.gd")
const Space := preload("res://kernel/world/terrain/world_space.gd")

static func _terrain(nx: int, nz: int) -> Terrain:
	var t := Terrain.new(19, Rect2(-48, 27, nx * 3, nz * 3), 3)
	t.build_grid()
	return t


static func _never(_x: float, _z: float) -> bool:
	return false


static func heightmap() -> Array:
	# Three chunks, including a partial east and south border, exercise centring and sample pitch.
	var t := _terrain(69, 36)
	var hole := 11 * (t.nx + 1) + 11
	t.heights[hole] = NAN
	var land := Land.new(t, {}, "heightmap")
	var parent := Node3D.new()
	var ws := Space.new()
	land.build_meshes(parent, TLStyle.material("terrain"), Vector2.ZERO)
	land.build_colliders(ws, _never)
	ws.finish()
	var err := []
	var rays := 0
	for id: Vector2i in land.chunks:
		var ch: Dictionary = land.chunks[id]
		var shape: HeightMapShape3D = ch.collider.shape
		if shape == null or Vector2i(shape.map_width, shape.map_depth) != ch.rect.size + Vector2i.ONE:
			err.append("heightmap sample dimensions at %s" % id)
			break
		var a: Array = ch.mesh.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for i in range(0, ix.size(), 3):
			var p := (v[ix[i]] + v[ix[i+1]] + v[ix[i+2]]) / 3
			var y := ws.ground_at(p.x, p.z, 100)
			if is_nan(y) or absf(y - p.y) > 0.001:
				err.append("heightmap at %s: ray %f, drawn %f" % [p, y, p.y])
				break
			rays += 1
	if rays == 0 or not is_nan(ws.ground_at(t.x0 + 33.1, t.z0 + 33.1, 100)):
		err.append("NaN sample did not leave a hole")
	ws.free_all()
	parent.free()
	return err


static func record() -> Array:
	var t := _terrain(36, 32)
	var land := Land.new(t)
	var left := Land.make_record(t, 0, 0)
	var right := Land.make_record(t, 1, 0)
	var err := []
	var original := t.heights.duplicate()
	var base_text := Record.encode(left)
	left.merge({"h_zero_m": -32.0, "h_step_m": 0.002, "heights": [[0, 5], [32, 34000]],
		"materials": [[0, 3]], "water": [{"cells": [7, 8], "level_m": 1.25}]})
	var source := Record.encode(left)
	if base_text != '{"schema":"tl.land/1","chunk":[0,0],"origin_m":[-48,27],"cell_m":3,"cells":[32,32],"base":{"kind":"village","seed":19},"split":"alternate"}':
		err.append("unexpected canonical base bytes")
	for pair in [[left, source], [Land.make_record(t, 0, 0), base_text]]:
		var result := Record.decode(pair[1])
		if not result.ok or result.record != pair[0] or Record.encode(result.record) != pair[1]:
			err.append("codec round trip: %s" % result)
	var cases := [[source.replace('"schema":', '"extra":1,"schema":'), "unknown key"],
		[source.replace('"cell_m":3','"cell_m":null'), "null value"],
		[source.replace("34000", "65536"), "u16"], [source.replace("tl.land/1", "invalid"), "schema"]]
	for pair in cases:
		var res := Record.decode(pair[0])
		if res.ok or not res.error.contains(pair[1]):
			err.append("expected %s, got %s" % [pair[1], res])
	var wrong := right.duplicate(true)
	wrong.base.seed += 1
	var refused := land.apply_records([wrong])
	if refused.size() != 1 or not refused[0].contains("seed") or land.stats.records != 0:
		err.append("wrong base accepted")
	var decoded := Record.decode(source)
	if not decoded.ok:
		return err
	var applied := land.apply_records([decoded.record])
	var expected := original.duplicate()
	expected[0] = -32.0 + 5 * 0.002
	expected[32] = 36
	if not applied.is_empty() or t.heights != expected or land.stats.delta_vertices != 2 or land.stats.painted_cells != 1 or land.stats.water_cells != 2 or land.records()[0] != left:
		err.append("sparse edit altered other samples or failed to load: %s" % [applied])
	var from_dir := Land.new(_terrain(36, 32), {"records": "res://kernel/world/land/fixtures"})
	if from_dir.records() != land.records() or from_dir.terr.heights != expected:
		err.append("records directory did not load onto the procedural base")
	var parent := Node3D.new()
	land.build_meshes(parent, TLStyle.material("terrain"), Vector2.ZERO)
	var a: Array = land.chunks[Vector2i.ZERO].mesh.mesh.surface_get_arrays(0)
	var b: Array = land.chunks[Vector2i.RIGHT].mesh.mesh.surface_get_arrays(0)
	if a[Mesh.ARRAY_VERTEX][32].y != 36 or b[Mesh.ARRAY_VERTEX][0].y != 36:
		err.append("seam twin missed height")
	for k in [0, 1, 33, 34]:
		# Vertex colour is stored by ArrayMesh as RGBA8. Check the uncompressed global pigment too.
		if land.samples.colours[(k / 33) * (t.nx + 1) + k % 33] != TLStyle.color("rock").srgb_to_linear():
			err.append("paint missing corner")
	var water_node := parent.get_node_or_null("WorldTerrain/WorldTerrain_0_0/ChunkWater") as MeshInstance3D
	if water_node == null or water_node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		err.append("missing chunk water")
	else:
		var faces := water_node.mesh.get_faces()
		if faces.size() != 12:
			err.append("incorrect flooded cell count")
		for v in faces:
			if v.y != 1.25:
				err.append("incorrect water level")
	parent.free()
	t.heights = original.duplicate()
	var conflict := Land.new(t)
	right.merge({"h_zero_m": -32.0, "h_step_m": 0.002, "heights": [[0, 33999]]})
	var errors := conflict.apply_records([left, right])
	if errors.size() != 1 or not errors[0].contains("seam") or t.heights[32] != original[32] or t.heights[0] != expected[0]:
		err.append("seam disagreement applied or valid edit lost")
	return err


static func rings() -> Array:
	var t := _terrain(640, 640)
	var errors := []
	var replay := []
	for run in 2:
		var land := Land.new(t, {"near": 2, "mid": 3, "all_near_max": 100})
		var parent := Node3D.new()
		var ws := Space.new()
		var start := Vector2i(3, 3)
		var origin := Vector2(t.x0, t.z0) + Vector2.ONE * 48
		land.build_meshes(parent, TLStyle.material("terrain"), origin + Vector2(start) * 96)
		land.build_colliders(ws, _never)
		var model := {}
		for id: Vector2i in land.chunks:
			var off := (id - start).abs()
			var d := maxi(off.x, off.y)
			var ring := 0 if d <= 2 else (1 if d <= 3 else 2)
			model[id] = [ring, ring, ring == 0]  # desired, mesh LOD, collider
		var steps := []
		for coord in [Vector2i(4,3), Vector2i(5,3), Vector2i(6,3), Vector2i(7,3), Vector2i(14,12)]:
			for frame in (180 if coord == Vector2i(14,12) else 3):
				var p := origin + Vector2(coord) * 96
				var expected := _advance(model, coord)
				var jobs := land.step(p, 2)
				steps.append(jobs)
				if jobs != expected:
					errors.append("focus %s frame %d expected %s got %s" % [coord, frame, expected, jobs])
					break
				for id: Vector2i in model:
					var ch: Dictionary = land.chunks[id]
					var installed: bool = not ch.collider.is_empty()
					if ch.wanted != model[id][0] or ch.lod != model[id][1] or installed != model[id][2] or (ch.mesh == null) != (ch.lod == 2):
						errors.append("built set differs at %s" % id)
						break
					if ch.mesh != null:
						var vertices: int = ch.mesh.mesh.surface_get_array_len(0)
						if vertices != (1089 if ch.lod == 0 else 353):
							errors.append("incorrect installed mesh resolution at %s" % id)
							break
					if installed and (ws._tags.get(ch.collider.body) != "terrain" or PhysicsServer3D.body_get_space(ch.collider.body) != ws.space):
						errors.append("collider missing from space at %s" % id)
						break
				if not errors.is_empty():
					break
			if not errors.is_empty():
				break
		if land.stats.forced < 9 or land.pending:
			errors.append("forced %d, pending %s" % [land.stats.forced, land.pending])
		if run == 1 and replay != steps:
			errors.append("different job log on replay")
		replay = steps
		ws.free_all()
		parent.free()
		if not errors.is_empty():
			return errors
	var small := Land.new(_terrain(40, 32))
	var p := Node3D.new()
	var ws := Space.new()
	small.build_meshes(p, TLStyle.material("terrain"), Vector2.ZERO)
	small.build_colliders(ws, _never)
	if small.stats.near != 2 or ws.stats.bodies != 2 or not small.stats.all_near or not small.step(Vector2(9000, 9000), 2).is_empty():
		errors.append("small land was not built in full at load")
	ws.free_all()
	p.free()
	return errors


## Independent oracle: enumerate all eligible jobs, sort by distance/z/x and take the first two.
static func _advance(model: Dictionary, centre: Vector2i) -> Array:
	var candidates := []
	var result := []
	for id: Vector2i in model:
		var state: Array = model[id]
		var off := (id - centre).abs()
		var distance := maxi(off.x, off.y)
		var before: int = state[0]
		state[0] = 2
		if distance <= 3 + int(before <= 1):
			state[0] = 1
		if distance <= 2 + int(before == 0):
			state[0] = 0
		if distance <= 1 and not state[2]:
			state[2] = true
			result.append([id, "force"])
		if state[2] and state[0] != 0:
			candidates.append([id, "drop_collider", 0])
		if state[1] != state[0]:
			candidates.append([id, "mesh", 1])
		if not state[2] and state[0] == 0:
			candidates.append([id, "collider", 2])
	result.sort_custom(func(a: Array, b: Array) -> bool:
		var x: Vector2i = a[0]
		var y: Vector2i = b[0]
		var dx := x.distance_squared_to(centre)
		var dy := y.distance_squared_to(centre)
		return dx < dy if dx != dy else (x.y < y.y if x.y != y.y else x.x < y.x))
	candidates.sort_custom(func(a: Array, b: Array) -> bool:
		var x: Vector2i = a[0]
		var y: Vector2i = b[0]
		var dx := x.distance_squared_to(centre)
		var dy := y.distance_squared_to(centre)
		if dx != dy: return dx < dy
		if x.y != y.y: return x.y < y.y
		if x.x != y.x: return x.x < y.x
		return a[2] < b[2])
	for job in candidates.slice(0, 2):
		var state: Array = model[job[0]]
		match job[1]:
			"mesh": state[1] = state[0]
			"collider": state[2] = true
			"drop_collider": state[2] = false
		result.append(job.slice(0, 2))
	return result
