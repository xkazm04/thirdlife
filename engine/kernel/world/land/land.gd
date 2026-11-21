extends RefCounted
## The far ring builds nothing. A far impostor is deferred.
## Workers prepare load-time geometry. Chunk nodes, resources and physics bodies are installed in stream order.
const Record := preload("res://kernel/world/land/land_record.gd")
const Samples := preload("res://kernel/world/land/chunk_mesh.gd")
const Collider := preload("res://kernel/world/land/chunk_collider.gd")
const NEAR := 0
const MID := 1
const FAR := 2

var terr
var dimensions: Vector2i
var chunks := {}
var deltas := {}
var original_heights := {}  # Only touched vertices, for seam conflicts across load batches.
var proposed_heights := {}
var disputed := {}
var paint_vertices := {}
var stats := {"chunks": [], "records": 0, "delta_vertices": 0, "painted_cells": 0, "water_cells": 0,
	"near": 0, "mid": 0, "far": 0, "all_near": false, "mesh_ms": 0, "collider_ms": 0, "forced": 0}
var near := 2
var mid := 6
var budget := 2
var all_near_max := 100
var kind: String
var samples := Samples.new()
var container: Node3D
var material: Material
var space
var skip: Callable
var face_usec := 0
var load_faces := {}  # Near chunk -> packed triangles, consumed when the visitor space is built.
var pending := false
var last_focus := Vector2(INF, INF)
var order: Array = []

func _init(t, options: Variant = {}, collider_kind := "faces") -> void:
	terr = t
	kind = collider_kind
	dimensions = Vector2i(ceili(float(t.nx) / Record.SIZE), ceili(float(t.nz) / Record.SIZE))
	stats.chunks = [dimensions.x, dimensions.y]
	var error := _options_error(options)
	if error != "":
		push_error("land: " + error)
		options = {}
	near = int(options.get("near", near))
	mid = int(options.get("mid", mid))
	budget = int(options.get("budget", budget))
	all_near_max = int(options.get("all_near_max", all_near_max))
	stats.all_near = dimensions.x * dimensions.y <= all_near_max
	for z in dimensions.y:
		for x in dimensions.x:
			var id := Vector2i(x, z)
			var corner := id * Record.SIZE
			var size := (Vector2i(t.nx, t.nz) - corner).min(Vector2i.ONE * Record.SIZE)
			var centre: Vector2 = Vector2(t.x0, t.z0) + (Vector2(corner) + Vector2(size) * 0.5) * t.cell
			chunks[id] = {"rect": Rect2i(corner, size), "centre": centre, "wanted": FAR, "lod": FAR,
				"mesh": null, "collider": {}, "distance": 0.0}
			if kind == "heightmap":
				t.fixed_chunks[id] = true
	if options.has("records"):
		_load_dir(options.records)


func _options_error(opts: Variant) -> String:
	if not opts is Dictionary:
		return "expected a land object"
	for k in opts:
		if k == "records":
			if not opts[k] is String or not opts[k].is_absolute_path():
				return "records must be an absolute directory or res:// path"
		elif k not in ["near", "mid", "budget", "all_near_max"]:
			return "unknown key %s" % k
		elif not Record.integer(opts[k]) or opts[k] < 0:
			return "%s must be a nonnegative integer" % k
	if opts.get("near", near) > opts.get("mid", mid):
		return "near exceeds mid"
	return ""


static func make_record(t, cx: int, cz: int) -> Dictionary:
	return Record.make_record(t, cx, cz)


func records() -> Array:
	var result := []
	for id: Vector2i in chunks:
		var record: Dictionary = deltas.get(id, make_record(terr, id.x, id.y)).duplicate(true)
		if terr.fixed_chunks.has(id):
			record.split = "fixed"
		result.append(record)
	return result


func _load_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("land: cannot open records at " + path)
		return
	var incoming := []
	for file in dir.get_files():  # Godot returns file names in alphabetical order.
		if file.get_extension().to_lower() != "json":
			continue
		var read := Record.decode(FileAccess.get_file_as_string(path.path_join(file)))
		if read.ok:
			incoming.append(read.record)
		else:
			push_error("land: %s: %s" % [file, read.error])
	for error in apply_records(incoming):
		push_error("land: " + error)


## Load-time transaction: validate all contributions to shared vertices before writing a height.
func apply_records(incoming: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	var values := {}
	for r in incoming:
		var error := Record.validate(r)
		if error != "":
			errors.append(error)
			continue
		var id := Vector2i(r.chunk[0], r.chunk[1])
		if not chunks.has(id):
			errors.append("chunk outside the terrain: %s" % id)
			continue
		var base := make_record(terr, id.x, id.y)
		if r.base.kind != base.base.kind or r.base.seed != base.base.seed:
			errors.append("wrong base kind or seed for %s" % id)
			continue
		if r.origin_m != base.origin_m or r.cells != base.cells or r.cell_m != base.cell_m:
			errors.append("chunk geometry disagrees with lattice at %s" % id)
			continue
		if kind == "heightmap" and r.split != "fixed":
			errors.append("heightmap requires fixed split at %s" % id)
			continue
		if deltas.has(id):
			errors.append("duplicate record for %s" % id)
			continue
		deltas[id] = r.duplicate(true)
		if r.split == "fixed":
			terr.fixed_chunks[id] = true
		var rect: Rect2i = chunks[id].rect
		for pair in r.get("heights", []):
			var k := _global_index(rect, int(pair[0]), rect.size.x + 1)
			var h := float(r.h_zero_m) + int(pair[1]) * float(r.h_step_m)
			if proposed_heights.has(k) and proposed_heights[k] != h:
				if not disputed.has(k):
					errors.append("seam height mismatch at vertex %d" % k)
				disputed[k] = true
			proposed_heights[k] = h
			values[k] = h
		for pair in r.get("materials", []):
			var k := _global_index(rect, int(pair[0]), rect.size.x)
			var col := TLStyle.color(Record.MATERIALS[int(pair[1])]).srgb_to_linear()
			for corner in [k, k + 1, k + terr.nx + 1, k + terr.nx + 2]:
				paint_vertices[corner] = col
			stats.painted_cells += 1
		for group in r.get("water", []):
			stats.water_cells += group.cells.size()
	for k: int in values:
		if not original_heights.has(k):
			original_heights[k] = terr.heights[k]
		terr.heights[k] = original_heights[k] if disputed.has(k) else values[k]
	stats.delta_vertices = original_heights.size() - disputed.size()
	if not disputed.is_empty():
		for id: Vector2i in deltas:
			var r: Dictionary = deltas[id]
			if r.has("heights"):
				var rect: Rect2i = chunks[id].rect
				r.heights = r.heights.filter(func(pair: Array) -> bool:
					return not disputed.has(_global_index(rect, int(pair[0]), rect.size.x + 1)))
	stats.records = deltas.size()
	return errors


func _global_index(rect: Rect2i, k: int, stride: int) -> int:
	return (rect.position.y + k / stride) * (terr.nx + 1) + rect.position.x + k % stride


static func focus(parent: Node3D, spawn := false) -> Vector2:
	var view := parent.get_parent()
	var world: Variant = view.get("world") if view != null else null
	if world != null:
		var path: Variant = world.get("player_script")
		if spawn and path is Array and not path.is_empty() and world.get("tick") == 0:
			var point: Array = path[0][1]
			return Vector2(point[0], point[2])
		var p: Variant = world.get("player_pos")
		if p is Vector3:
			return Vector2(p.x, p.z)
	return Vector2.ZERO


func _focus_chunk(p: Vector2) -> Vector2i:
	return Vector2i(((p - Vector2(terr.x0, terr.z0)) / (Record.SIZE * terr.cell)).floor())


func _want(p: Vector2) -> void:
	if p == last_focus or (stats.all_near and not order.is_empty()):
		return
	var centre := _focus_chunk(p)
	stats.near = 0
	stats.mid = 0
	stats.far = 0
	for id: Vector2i in chunks:
		var ch: Dictionary = chunks[id]
		var offset := (id - centre).abs()
		var distance := maxi(offset.x, offset.y)
		var ring := FAR
		if stats.all_near or distance <= maxi(1, near) or (ch.wanted == NEAR and distance <= near + 1):
			ring = NEAR
		elif distance <= mid or (ch.wanted <= MID and distance <= mid + 1):
			ring = MID
		ch.wanted = ring
		ch.distance = p.distance_squared_to(ch.centre)
		stats[["near", "mid", "far"][ring]] += 1
	order = chunks.keys()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: float = chunks[a].distance
		var db: float = chunks[b].distance
		return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
	last_focus = p
	pending = true


## Only these immutable plot centres and radii are captured by the load workers.
func configure_plot_holes(centres: Array, radii: Array, has_ground: Array) -> void:
	var holes := PackedVector2Array()
	var sizes := PackedFloat64Array()
	var near_plots := PackedVector3Array()
	for i in has_ground.size():
		if has_ground[i] and radii[i] > 0.0:
			var c: Vector2 = centres[i]
			holes.append(c)
			sizes.append(radii[i])
			near_plots.append(Vector3(c.x, c.y, radii[i]))
	terr.skip_near = near_plots
	skip = func(x: float, z: float) -> bool:
		for i in holes.size():
			if Vector2(x, z).distance_to(holes[i]) < sizes[i] - 1.0:
				return true
		return false


func build_meshes(parent: Node3D, mat: Material, p: Vector2) -> void:
	var start := Time.get_ticks_usec()
	_want(p)
	material = mat
	samples.prepare(terr, paint_vertices)
	container = Node3D.new()
	container.name = "WorldTerrain"
	parent.add_child(container)
	var meshes: Array[Vector2i] = []
	var colliders: Array[Vector2i] = []
	for id: Vector2i in order:
		if chunks[id].wanted != FAR:
			meshes.append(id)
		if chunks[id].wanted == NEAR and kind == "faces" and skip.is_valid():
			colliders.append(id)
	var surfaces: Array[Array] = []
	var triangles: Array[PackedVector3Array] = []
	var mesh_done: Array[int] = []
	surfaces.resize(meshes.size())
	mesh_done.resize(meshes.size())
	triangles.resize(colliders.size())
	var plot_filter := skip if not terr.skip_near.is_empty() else Callable()
	var prepare := func(i: int) -> void:
		if i < meshes.size():
			var id := meshes[i]
			var ch: Dictionary = chunks[id]
			surfaces[i] = samples.chunk_arrays(terr, ch.rect, ch.wanted, terr.fixed_chunks.has(id))
			mesh_done[i] = Time.get_ticks_usec()
		else:
			var slot := i - meshes.size()
			triangles[slot] = Collider.faces(terr, chunks[colliders[slot]].rect, plot_filter)
	if not meshes.is_empty():
		var task := WorkerThreadPool.add_group_task(prepare, meshes.size() + colliders.size(), 8)
		WorkerThreadPool.wait_for_group_task_completion(task)
		if not colliders.is_empty():
			# Mesh and face preparation overlap. Charge only the tail after the last mesh to collision.
			face_usec = Time.get_ticks_usec() - int(mesh_done.max())
	for i in colliders.size():
		load_faces[colliders[i]] = triangles[i]
	for i in meshes.size():
		_mesh(meshes[i], surfaces[i])
	stats.mesh_ms = roundi((Time.get_ticks_usec() - start - face_usec) / 1000.0)
	terr.build_ms += stats.mesh_ms


func _mesh(id: Vector2i, arrays: Array = []) -> void:
	var ch: Dictionary = chunks[id]
	if ch.mesh != null:
		ch.mesh.free()
		ch.mesh = null
	ch.lod = ch.wanted
	if ch.lod != FAR:
		if arrays.is_empty():
			arrays = samples.chunk_arrays(terr, ch.rect, ch.lod, terr.fixed_chunks.has(id))
		ch.mesh = Samples.instance_from_arrays(arrays, material, "WorldTerrain_%d_%d" % [id.x, id.y])
		container.add_child(ch.mesh)
		samples.add_water(ch.mesh, terr, ch.rect, deltas.get(id, {}).get("water", []))



func build_colliders(ws, skip_cell := Callable()) -> void:
	var start := Time.get_ticks_msec()
	space = ws
	var prepaid_ms := roundi(face_usec / 1000.0)
	if skip_cell.is_valid():
		skip = skip_cell
		load_faces.clear()
	for id: Vector2i in order:
		if chunks[id].wanted == NEAR:
			_collider(id)
	stats.collider_ms = prepaid_ms + Time.get_ticks_msec() - start
	pending = false
	if not stats.all_near:
		ws.ensure_land = ensure_safe


func _collider(id: Vector2i) -> void:
	var rect: Rect2i = chunks[id].rect
	var triangles := PackedVector3Array()
	if load_faces.has(id):
		triangles = load_faces[id]
		load_faces.erase(id)
	elif kind == "faces":
		var start := Time.get_ticks_usec()
		triangles = Collider.faces(terr, rect, skip)
		face_usec += Time.get_ticks_usec() - start
	chunks[id].collider = Collider.build(terr, rect, triangles, kind, space)


func ensure_safe(p: Vector2) -> Array:
	var forced := []
	var centre := _focus_chunk(p)
	for z in range(centre.y - 1, centre.y + 2):
		for x in range(centre.x - 1, centre.x + 2):
			var id := Vector2i(x, z)
			if chunks.has(id) and chunks[id].collider.is_empty():
				forced.append(id)
	forced.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := p.distance_squared_to(chunks[a].centre)
		var db := p.distance_squared_to(chunks[b].centre)
		return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
	var jobs := []
	for id: Vector2i in forced:
		_collider(id)
		jobs.append([id, "force"])
		stats.forced += 1
		pending = true
	return jobs


func step(p: Vector2, limit: int) -> Array:
	_want(p)
	var jobs := ensure_safe(p)
	if not pending:
		return jobs
	pending = false
	for id: Vector2i in order:
		var ch: Dictionary = chunks[id]
		var needs_body: bool = ch.wanted == NEAR
		if ch.lod == ch.wanted and needs_body == (not ch.collider.is_empty()):
			continue
		for action in ["drop_collider", "mesh", "collider"]:
			if action == "drop_collider" and (needs_body or ch.collider.is_empty()):
				continue
			if action == "mesh" and ch.lod == ch.wanted:
				continue
			if action == "collider" and (not needs_body or not ch.collider.is_empty()):
				continue
			if limit <= 0:
				pending = true
				return jobs
			limit -= 1
			var start := Time.get_ticks_msec()
			match action:
				"drop_collider":
					Collider.drop(ch.collider, space)
					ch.collider = {}
				"mesh":
					_mesh(id)
				"collider":
					_collider(id)
			stats["mesh_ms" if action == "mesh" else "collider_ms"] += Time.get_ticks_msec() - start
			jobs.append([id, action])
	return jobs
