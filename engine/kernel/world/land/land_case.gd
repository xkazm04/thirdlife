extends "res://kernel/world/terrain/harden_walks.gd"
## Compare the installed village meshes, shade map and visitor space with the original whole-grid builders.
const Land := preload("res://kernel/world/land/land.gd")
const Reference := preload("res://kernel/world/land/reference_mesh.gd")
const Shade := preload("res://kernel/world/terrain/tree_shade.gd")
const Synthetic := preload("res://kernel/world/land/synthetic_cases.gd")
const Host := preload("res://kernel/world/world.gd")
const WALK_FILE := "res://kernel/world/land/ledger_walk.json"

func _initialize() -> void:
	call_deferred("_run")


func verdict(label: String, errors: Array, detail: String) -> void:
	print("LAND land.%s %s %s" % [label, "ok" if errors.is_empty() else "fail",
		detail if errors.is_empty() else str(errors[0])])


func _run() -> void:
	TLStyle.load_style("res://style/style_crisp.json")
	TLStyle.set_headless(false)
	var meshes := []
	var seams := []
	var collision := []
	var select := OS.get_environment("TL_LAND_CASE")
	if select in ["", "same_mesh", "seams", "colliders"]:
		for path in ["res://boot/village.json", "res://kernel/world/walks/tour.json"]:
			var stats := _build_village(path, true)
			var land: Land = _land.get_meta(&"tl_land")
			print("LANDSTATS ", path, " ", JSON.stringify({"build_ms": stats.build_ms, "terrain_ms": stats.terrain_ms,
				"space_ms": stats.space_ms, "land": stats.land}))
			var dims := Vector2i(9, 7) if path.contains("boot") else Vector2i(8, 7)
			if land.dimensions != dims or not land.stats.all_near or land.stats.near != dims.x * dims.y:
				meshes.append("village chunk counts %s" % land.dimensions)
			var ref := Reference.build_mesh(_terr, land.material)
			_compare(land, ref, meshes, seams)
			_shade(land, ref, meshes)
			ref.free()
			_colliders(land, collision)
			if not land.step(Vector2(1e5, 1e5), 2).is_empty() or land.pending or _land.has_meta(&"tl_land_rest"):
				meshes.append("all-near village still streaming")
		_skirt(_land.get_meta(&"tl_land"), seams)
		verdict("same_mesh", meshes, "exe and tour: all vertex channels, triangles, shared material and tree shade match")
		verdict("seams", seams, "every shared edge matches and the mid skirt covers the near border")
		verdict("colliders", collision, "119 terrain bodies, exact face totals, 2000 seeded rays per village including holes")
		_land.get_parent().free()
	if select in ["", "heightmap"]:
		verdict("heightmap", Synthetic.heightmap(), "fixed-split mesh, Jolt rays and a NaN hole")
	if select in ["", "record"]:
		verdict("record", Synthetic.record(), "canonical bytes, sparse heights, paint, water and seam/error checks")
	if select in ["", "rings"]:
		verdict("rings", Synthetic.rings(), "20 x 20 chunks, budget 2, hysteresis, forced neighbours and identical replay")
	if select in ["", "ledger"]:
		await _ledger()
	print("LAND DONE")
	quit()


func _compare(land: Land, ref: MeshInstance3D, errors: Array, seams: Array) -> void:
	var base := ref.mesh.surface_get_arrays(0)
	var width: int = _terr.nx + 1
	var seen := {}
	var triangles := {}
	var ri: PackedInt32Array = base[Mesh.ARRAY_INDEX]
	for j in range(0, ri.size(), 3):
		triangles[Vector3i(ri[j], ri[j + 1], ri[j + 2])] = true
	for id: Vector2i in land.chunks:
		var ch: Dictionary = land.chunks[id]
		var mi: MeshInstance3D = ch.mesh
		if mi.get_parent() != land.container or mi.name != "WorldTerrain_%d_%d" % [id.x, id.y] or mi.material_override != land.material or mi.mesh.surface_get_material(0) != land.material or mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			errors.append("chunk placement/material/shadows at %s" % id)
		var a := mi.mesh.surface_get_arrays(0)
		var rect: Rect2i = ch.rect
		var stride := rect.size.x + 1
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		if v.size() != stride * (rect.size.y + 1):
			errors.append("incorrect partial chunk extent at %s" % id)
			continue
		var global_indices := PackedInt32Array()
		for k in v.size():
			var g := (rect.position.y + k / stride) * width + rect.position.x + k % stride
			global_indices.append(g)
			var n: Vector3 = a[Mesh.ARRAY_NORMAL][k]
			if seen.has(g) and (v[k] != seen[g][0] or n != seen[g][1]) and seams.is_empty():
				seams.append("shared position/normal at %d" % g)
			seen[g] = [v[k], n]
			if errors.is_empty():
				for channel in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV]:
					if a[channel][k] != base[channel][g]:
						errors.append("vertex %d channel %d" % [g, channel])
				for i in 4:
					if a[Mesh.ARRAY_CUSTOM0][4*k+i] != base[Mesh.ARRAY_CUSTOM0][4*g+i]:
						errors.append("custom0 at vertex %d" % g)
		var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for j in range(0, indices.size(), 3):
			var tri := Vector3i(global_indices[indices[j]], global_indices[indices[j+1]], global_indices[indices[j+2]])
			if not triangles.erase(tri) and errors.is_empty():
				errors.append("extra or reversed triangle %s" % tri)
	if not triangles.is_empty() or seen.size() != base[Mesh.ARRAY_VERTEX].size():
		errors.append("incomplete single mesh coverage")


func _shade(land: Land, ref: MeshInstance3D, errors: Array) -> void:
	var images := []
	var capture := func(image: Image) -> void: images.append(image.get_data())
	var count := Shade.build(_land, 1.0, capture)
	var uv: Variant = land.material.get_shader_parameter("cel_shade_uv")
	var tex: Variant = land.material.get_shader_parameter("cel_shade")
	land.container.name = "ChunkContainer"
	_land.add_child(ref)
	var old := Shade.build(_land, 1.0, capture)
	if count <= 0 or count != old or images.size() != 2 or images[0] != images[1] or uv != land.material.get_shader_parameter("cel_shade_uv") or tex == null:
		errors.append("tree shade texture/uniforms or number of stamps differ")
	_land.remove_child(ref)
	land.container.name = "WorldTerrain"


func _skirt(land: Land, errors: Array) -> void:
	var ch: Dictionary = land.chunks[Vector2i.ZERO]
	var mi := land.samples.build(_terr, ch.rect, land.material, "Mid", 1, false)
	var arrays := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ix: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var neighbour: PackedVector3Array = land.chunks[Vector2i.RIGHT].mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var expected := 17 * 17
	if v.size() != expected + 64 or ix.size() != (256 + 64) * 6:
		errors.append("mid skirt incomplete")
	else:
		for j in 16:
			var top := j * 17 + 16
			var bottom := expected + 16 + j
			var next := bottom + 1
			var offset := (256 + 16 + j) * 6
			if v[top] != neighbour[2 * j * 33] or v[bottom].x != v[top].x or v[bottom].z != v[top].z or maxf(v[bottom].y, v[next].y) >= minf(neighbour[(2*j+1)*33].y, minf(v[top].y, v[top+17].y)) or ix.slice(offset, offset+6) != PackedInt32Array([top+17, top, bottom, top+17, bottom, next]):
				errors.append("mid skirt does not cover near edge at %d" % j)
				break
	mi.free()


func _colliders(land: Land, errors: Array) -> void:
	var bodies := {}
	for rid: RID in _ws._bodies:
		if _ws._tags.get(rid) == "terrain":
			bodies[rid] = true
		else:
			PhysicsServer3D.body_set_collision_layer(rid, 0)
	for id: Vector2i in land.chunks:
		var col: Dictionary = land.chunks[id].collider
		if not bodies.erase(col.body) or PhysicsServer3D.body_get_space(col.body) != _ws.space or PhysicsServer3D.body_get_shape_count(col.body) != 1 or not col.shape is ConcavePolygonShape3D or not col.shape.backface_collision:
			errors.append("terrain body at %s" % id)
	# The reference skip is written here from the walk's plots, as landscape.gd wrote it before the chunks (not land.skip):
	# every plot carries ground of its own in this build (_build_village(path, true)).
	var centres := []
	var radii := []
	for p: Dictionary in _walk["plots"]:
		centres.append(Vector2(float(p["origin"][0]), float(p["origin"][2])))
		radii.append(float(p["radius"]))
	var skip := func(cx: float, cz: float) -> bool:
		for i: int in centres.size():
			if radii[i] > 0.0 and Vector2(cx, cz).distance_to(centres[i]) < radii[i] - 1.0:
				return true
		return false
	var faces: PackedVector3Array = _terr.collision_faces(skip)
	if not bodies.is_empty() or _ws.stats.faces != faces.size() / 3:
		errors.append("unexpected terrain body or face total")
	var installed := {}
	var offsets := {}
	for id: Vector2i in land.chunks:
		installed[id] = land.chunks[id].collider.shape.get_faces()
		offsets[id] = 0
	for k in range(0, faces.size(), 3):
		var centroid := (faces[k] + faces[k+1] + faces[k+2]) / 3
		var id := Vector2i(floori((centroid.x - _terr.x0) / (32 * _terr.cell)), floori((centroid.z - _terr.z0) / (32 * _terr.cell)))
		var at: int = offsets[id]
		var tris: PackedVector3Array = installed[id]
		if at + 3 > tris.size() or tris[at] != faces[k] or tris[at+1] != faces[k+1] or tris[at+2] != faces[k+2]:
			errors.append("reference triangle or winding differs at %s triangle %d" % [id, at / 3])
			break
		offsets[id] += 3
	var reference: RefCounted = Space.new()
	reference.add_faces(faces)
	reference.finish()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9713
	var misses := 0
	for i in 2000:
		var x := rng.randf_range(_terr.x0, _terr.x1())
		var z := rng.randf_range(_terr.z0, _terr.z1())
		var old: float = reference.ground_at(x, z, 100.0)
		var hit: float = _ws.ground_at(x, z, 100.0)
		if is_nan(old):
			misses += 1
		if is_nan(old) != is_nan(hit) or (not is_nan(old) and (absf(hit - _terr.gy(x, z)) > 0.001 or absf(hit - old) > 0.001)):
			errors.append("ray %d at (%f,%f), reference %f, chunk %f, grid %f" % [i, x,z,old,hit,_terr.gy(x,z)])
			break
	if misses == 0:
		errors.append("no skipped plot ground sampled")
	reference.free_all()


## The ledger tier as tiers.json ships it (no override in the walk): the game is unloaded beyond backdrop_m + the
## margin, the world keeps its plot record unchanged while it is away (ticks, summary, saved data), and the rebuilt game
## carries on from it: the same ticks and, for a pack with _pack_save (ex_bounce), the same score. The rebuilt game's
## round starts again from its seed (TIERS.md "the world file": its clock restarts), so the clock is not compared.
func _ledger() -> void:
	var world := Host.new()
	root.add_child(world)
	world.quit_on_end = false
	var trace := {"unloaded": false, "returned": false, "rebuilt": false, "kept": {}, "away": {}, "live": {}, "continues": false}
	world.plot_event.connect(func(i: int, event: String, ev: Dictionary) -> void:
		var pack: Node = world.packs[i]
		if event == "tier" and ev.to == "ledger":
			trace.unloaded = pack.ledgered and pack.pack_node == null and world.ledger.has(i)
			trace.kept = world._plot_records()[i].summary.duplicate(true)
		if event == "tier" and ev.get("from") == "ledger":
			trace.returned = true
		if event == "rebuilt" and trace.unloaded:
			trace.rebuilt = pack.restored and not pack.ledgered and not world.ledger.has(i)
			trace.live = world._plot_records()[i].summary.duplicate(true))
	var away := func() -> void:
		if int(world.get("tick")) == 200 and world.ledger.has(0):
			trace.away = world._plot_records()[0].summary.duplicate(true)
	physics_frame.connect(away)
	world.ended.connect(func(_bad: bool) -> void:
		trace.continues = world._plot_records()[0].ticks > int(trace.kept.get("ticks", 0)))
	world.start({"walk": WALK_FILE})
	var bad: bool = await world.ended
	physics_frame.disconnect(away)
	var errors := []
	var tiers: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://kernel/world/tiers.json"))
	var walk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WALK_FILE))
	var far_m: float = 1200.0 - 20.0           # the walk's far point to the plot's edge (default footprint 40 m)
	if walk.has("tiers") or float(tiers.backdrop_m) <= 0.0 or far_m <= float(tiers.backdrop_m) + float(tiers.margin_m.backdrop):
		errors.append("the walk must reach beyond the shipped backdrop_m %s + margin without an override" % tiers.backdrop_m)
	elif bad or not (trace.unloaded and trace.returned and trace.rebuilt and trace.continues):
		errors.append("ledger transitions or ticks missing: %s" % trace)
	elif trace.away != trace.kept:
		errors.append("the record changed while away: unload %s, at tick 200 %s" % [trace.kept, trace.away])
	elif int(trace.live.ticks) != int(trace.kept.ticks) or trace.live.get("score") != trace.kept.get("score") or int(trace.kept.get("score", {}).get("bin", 0)) <= 0:
		errors.append("rebuilt from the record lost ticks or score: unload %s, rebuilt %s" % [trace.kept, trace.live])
	verdict("ledger", errors, "unloaded beyond the shipped backdrop_m %s m: record unchanged while away (%s), rebuilt with ticks %d and score %s" % [tiers.backdrop_m, JSON.stringify(trace.kept), int(trace.live.get("ticks", -1)), JSON.stringify(trace.live.get("score"))])
	world.queue_free()
