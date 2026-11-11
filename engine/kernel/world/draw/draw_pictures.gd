extends "res://kernel/world/draw/draw_base.gd"
## The draw layer of a world, layer 2 of 4: the merged pictures of a far pack ("still", "mid", "far"), built in one
## walk over the pack's nodes (`_build_pictures`). draw/FAR.md says what each picture keeps and why.


## One merged mesh from the pack's static style geometry: palette columns, vertex colours and part-local coordinates
## kept (so it is drawn by the same palette material, with the same drawn surface detail and the same ink lines);
## instances smaller than `standin_min`, anything under a moving body or a skeleton, particles, glass and foreign
## materials dropped.
## What a stand-in is merged into (a class, not a Dictionary: packed arrays inside a Dictionary are copied on access).
class Acc:
	var v: PackedVector3Array = PackedVector3Array()
	var n: PackedVector3Array = PackedVector3Array()
	var c: PackedColorArray = PackedColorArray()
	var uv: PackedVector2Array = PackedVector2Array()
	var cu: PackedFloat32Array = PackedFloat32Array()
	var ix: PackedInt32Array = PackedInt32Array()
	var sheets: Array = []
	var extra: Dictionary = {}          # Material -> Acc: one more surface per flat-colour toon material (kernel-made boxes)
	var radius: float = 0.0
	var rim: float = 0.0
	var band: float = 0.0
	var kept: int = 0
	var dropped_small: int = 0
	var dropped_moving: int = 0
	var dropped_other: int = 0
	var dropped_outside: int = 0
	var src_tris: int = 0
	var kind: String = "still"          # P6: which picture this is ("still" | "mid" | "far")
	var min_size: float = 1.2
	var cell: float = 0.0               # > 0: terrain sheets are re-meshed on a grid of this size
	var cells: Dictionary = {}          # Vector2i -> vertex index (the sheets' shared grid)
	var thin: float = 0.0               # > 0: triangles narrower than this are dropped (not on the terrain)
	var small: float = 0.0              # > 0: triangles whose longest edge is shorter are dropped (not on the terrain)
	var dropped_tris: int = 0
	var sheet_tris: int = 0


## Builds the missing pictures of a pack in ONE walk over its nodes (each instance is appended to every picture that
## keeps it). P13: the walk on the main thread only lists what goes where (`_collect_standin`: transforms, materials,
## the surface arrays); the merging (`_append`, the long part) runs on a worker; `_poll_pictures` makes the meshes
## when it is done, in a later frame. `pic_worker` false = all of it now, in this frame (as P6 did).
func _build_pictures(e: Dictionary, kinds: Array) -> void:
	var t0: int = Time.get_ticks_usec()
	var holder: Node3D = e["holder"]
	_clip_v4(e, holder)                       # makes sure e["sheets"] is there
	var accs: Array = _new_accs(e, kinds)
	var jobs: Array = []
	_collect_standin(holder, holder, accs, jobs)
	if pic_worker:
		e["build"] = {"task": WorkerThreadPool.add_task(_run_jobs.bind(jobs)), "accs": accs, "jobs": jobs, "t0": t0,
			"main_us": Time.get_ticks_usec() - t0}
		return
	_run_jobs(jobs)
	_finish_pictures(e, accs, t0, Time.get_ticks_usec() - t0)


## Once per frame for a pack whose pictures are being merged on a worker: when the worker is done, the meshes are made
## and the pack's far state is applied again (it was drawn in full meanwhile). Returns true when it finished now.
func _poll_pictures(e: Dictionary) -> bool:
	var b: Dictionary = e["build"]
	if not WorkerThreadPool.is_task_completed(int(b["task"])):
		return false
	WorkerThreadPool.wait_for_task_completion(int(b["task"]))
	e.erase("build")
	_finish_pictures(e, b["accs"], int(b["t0"]), int(b["main_us"]))
	return true


## The merging of a picture (on a worker): a job is [picture, mesh, transform, sheet, terrain, picture counted, surface];
## each mesh surface's arrays are read once, here, off the main thread (reading them was most of the main thread's share).
func _run_jobs(jobs: Array) -> void:
	var arrays: Dictionary = {}
	for j: Array in jobs:
		var target: Acc = j[0]
		var before: int = target.ix.size()
		var key: Array = [j[1], int(j[6])]
		if not arrays.has(key):
			arrays[key] = (j[1] as Mesh).surface_get_arrays(int(j[6]))
		_append(target, arrays[key], j[2], bool(j[3]), bool(j[4]))
		if bool(j[3]):
			(j[5] as Acc).sheet_tris += (target.ix.size() - before) / 3


func _new_accs(e: Dictionary, kinds: Array) -> Array:
	var accs: Array = []
	for k: String in kinds:
		var acc: Acc = Acc.new()
		acc.kind = k
		acc.radius = float(e["radius"])
		acc.rim = float(e["rim"])
		acc.band = rim_band
		acc.sheets = e["sheets"]
		acc.min_size = standin_min if k == "still" else (mid_min if k == "mid" else far_min)
		acc.cell = far_cell if k == "far" else 0.0
		acc.thin = far_thin if k == "far" else 0.0
		acc.small = far_small if k == "far" else 0.0
		accs.append(acc)
	return accs


## The meshes of the merged pictures (main thread), placed, kept, and written to the picture cache (`_cache_save`).
## `main_us`: the part of the walk that ran on the main thread in the frame the build started.
func _finish_pictures(e: Dictionary, accs: Array, t0: int, main_us: int) -> void:
	var t1: int = Time.get_ticks_usec()
	var holder: Node3D = e["holder"] if is_instance_valid(e["holder"]) else null
	var hname: String = String(holder.name) if holder != null else "plot"
	for acc: Acc in accs:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Picture_%s_%s" % [acc.kind, hname]
		var mesh: ArrayMesh = ArrayMesh.new()
		var parts: Array = [[acc, _pal]]
		for mat: Variant in acc.extra:
			parts.append([acc.extra[mat], mat])
		var tris: int = 0
		var verts: int = 0
		for part: Array in parts:
			var pa: Acc = part[0]
			if pa.v.size() == 0 or pa.ix.size() == 0:
				continue
			if acc.kind == "far" and far_flat > 0.0:
				# a drawn background: every face leans to the sky, so a form keeps one tone and the ink pass, which
				# draws creases from normals, leaves only its outline
				for k: int in pa.n.size():
					pa.n[k] = pa.n[k].lerp(Vector3.UP, far_flat).normalized()
			var arr: Array = []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = pa.v
			arr[Mesh.ARRAY_NORMAL] = pa.n
			arr[Mesh.ARRAY_COLOR] = pa.c
			arr[Mesh.ARRAY_TEX_UV] = pa.uv
			arr[Mesh.ARRAY_CUSTOM0] = pa.cu
			arr[Mesh.ARRAY_INDEX] = pa.ix
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
			mesh.surface_set_material(mesh.get_surface_count() - 1, part[1])
			tris += pa.ix.size() / 3
			verts += pa.v.size()
			if pa != acc:
				acc.src_tris += pa.src_tris
				acc.dropped_tris += pa.dropped_tris
		if mesh.get_surface_count() > 0:
			mi.mesh = mesh
		mi.visible = false
		# P13: the far picture casts its shadow like the middle one. The style's shadow reaches 300 m from the camera,
		# the change of picture happens at 210 to 270 m from the plot EDGE: without it the shadow switched off visibly
		# (captures/p13/motion/before_*). Beyond 300 m the engine draws no shadow of it anyway.
		_place_standin(e, mi)
		add_child(mi)
		var old: Variant = (e["pics"] as Dictionary).get(acc.kind)
		if old != null and is_instance_valid(old):
			(old as Node).queue_free()             # a picture from the cache, replaced by the one of the pack as it is now
		(e["pics"] as Dictionary)[acc.kind] = mi
		var info: Dictionary = {"kind": acc.kind, "tris": tris, "vertices": verts, "surfaces": mesh.get_surface_count(),
			"kept": acc.kept, "dropped_small": acc.dropped_small, "dropped_moving": acc.dropped_moving,
			"dropped_other": acc.dropped_other, "dropped_outside": acc.dropped_outside, "src_tris": acc.src_tris,
			"sheet_tris": acc.sheet_tris, "dropped_tris": acc.dropped_tris, "build_ms": snappedf(float(Time.get_ticks_usec() - t0) / 1000.0, 0.1),
			"main_ms": snappedf(float(main_us + Time.get_ticks_usec() - t1) / 1000.0, 0.01), "from": "built"}
		(e["standin_info"] as Dictionary)[acc.kind] = info
		if mi.mesh != null:
			_cache_save(e, acc.kind, mi.mesh)
	var frame_ms: float = float(main_us + Time.get_ticks_usec() - t1) / 1000.0
	stats["pic_main_ms_max"] = maxf(float(stats.get("pic_main_ms_max", 0.0)), snappedf(frame_ms, 0.01))


## P13, the picture cache: `user://tl_cache/pictures/<key>_<kind>.res`, the key being the hash of the pack's directory
## (plotfile.gd `dir_hash`: its files' content), the plot's radius and rim and the picture rules. A plot whose pack is
## not built yet shows its last known picture from it; a pack that changed has another key. Written on a worker.
func _cache_key(e: Dictionary) -> String:
	if not is_instance_valid(e["holder"]):
		return ""
	var dir: String = str((e["holder"] as Node).get("pack_dir"))
	if dir.is_empty() or dir == "<null>" or OS.get_environment("TL_PICTURE_CACHE") == "off":
		return ""
	if not _dir_hashes.has(dir):
		_hash_dir_async(dir)
		return ""
	var slot: Array = _dir_hashes[dir]
	if not WorkerThreadPool.is_task_completed(int(slot[0])) or slot.size() < 2:
		return ""                      # its hash is still being read on a worker: no cache this time
	var rules: String = "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [PIC_VERSION, mid_min, far_min, far_cell, far_flat, far_thin, far_small, standin_min, rim_band]
	return ("%s|%s|%s|%s" % [slot[1], snappedf(float(e["radius"]), 0.01), snappedf(float(e["rim"]), 0.01), rules]).md5_text()


## The content hash of a pack directory reads every file of it (60 to 100 ms for the seeds): on a worker, never in a
## frame. `_dir_hashes[dir]` = [task] while it runs, [task, hash] when it is done (waited for in `clear`).
func _hash_dir_async(dir: String) -> void:
	if dir.is_empty() or _dir_hashes.has(dir):
		return
	var slot: Array = []
	slot.append(WorkerThreadPool.add_task(func() -> void: slot.append(str(PlotFile.call("dir_hash", dir)))))
	_dir_hashes[dir] = slot


func _cache_path(key: String, kind: String) -> String:
	return "%s/tl_cache/pictures/%s_%s.res" % [OS.get_user_data_dir(), key, kind]


func _cache_save(e: Dictionary, kind: String, mesh: ArrayMesh) -> void:
	var key: String = _cache_key(e)
	if key.is_empty() or FileAccess.file_exists(_cache_path(key, kind)):
		return
	# no material is written (a material in the file is a new material and costs a shader compile on loading): each
	# surface notes "pal" or the colour and metal of its flat toon material, made again by TLStyle on loading
	var copy: ArrayMesh = mesh.duplicate(false) as ArrayMesh
	var mats: Array = []
	for s: int in copy.get_surface_count():
		var m: Material = copy.surface_get_material(s)
		var lut: Variant = (m as ShaderMaterial).get_shader_parameter(&"pal_lut") if m is ShaderMaterial and m != _pal else null
		if m == _pal:
			mats.append("pal")
		elif lut is Texture2D and (lut as Texture2D).get_image() != null:
			var img: Image = (lut as Texture2D).get_image()
			var c: Color = img.get_pixel(0, 0).linear_to_srgb()
			mats.append([c.r, c.g, c.b, img.get_pixel(0, 1).r])
		else:
			return                     # a material that cannot be made again: this picture is not cached
		copy.surface_set_material(s, null)
	copy.set_meta(&"tl_mats", mats)
	DirAccess.make_dir_recursive_absolute(_cache_path(key, kind).get_base_dir())
	_cache_tasks.append(WorkerThreadPool.add_task(func() -> void: ResourceSaver.save(copy, _cache_path(key, kind))))


## The cached pictures of a pack, made into this layer's pictures; false when one is missing.
func _cache_load(e: Dictionary, kinds: Array) -> bool:
	var key: String = _cache_key(e)
	if key.is_empty():
		return false
	for k: String in kinds:
		if not FileAccess.file_exists(_cache_path(key, k)):
			return false
	var t0: int = Time.get_ticks_usec()
	for k: String in kinds:
		var mesh: ArrayMesh = ResourceLoader.load(_cache_path(key, k), "", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		if mesh == null:
			return false
		var mats: Array = mesh.get_meta(&"tl_mats", [])
		for s: int in mini(mats.size(), mesh.get_surface_count()):
			var f: Variant = mats[s]
			mesh.surface_set_material(s, _pal if typeof(f) == TYPE_STRING else TLStyle.flat_material(Color(float(f[0]), float(f[1]), float(f[2])), float(f[3])))
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Picture_%s_cached" % k
		mi.mesh = mesh
		mi.visible = false
		_place_standin(e, mi)
		add_child(mi)
		(e["pics"] as Dictionary)[k] = mi
		var tris: int = 0
		for s: int in mesh.get_surface_count():
			tris += mesh.surface_get_array_index_len(s) / 3
		(e["standin_info"] as Dictionary)[k] = {"kind": k, "tris": tris, "from": "cache", "main_ms": snappedf(float(Time.get_ticks_usec() - t0) / 1000.0, 0.01)}
	stats["pictures_from_cache"] = int(stats.get("pictures_from_cache", 0)) + 1
	return true


## A stand-in is drawn like the pack it stands for: the node stays at the origin and the shader moves it (candidate A),
## so the plot cut and the bent rim, which work in the pack's own coordinates, are the same as on the full pack.
func _place_standin(e: Dictionary, mi: MeshInstance3D) -> void:
	mi.transform = Transform3D.IDENTITY
	mi.set_instance_shader_parameter(PLOT, _plot_v4(e["rel"]))
	if float(e["radius"]) > 0.0:
		mi.set_instance_shader_parameter(CLIP, Vector4(float(e["radius"]), float(e["rim"]), 0.0, 0.0))    # cut, not bent: the bend is baked
	if mi.mesh != null:
		mi.custom_aabb = (e["rel"] as Transform3D) * mi.mesh.get_aabb().grow(4.0)


func _collect_standin(n: Node, holder: Node3D, accs: Array, jobs: Array) -> void:
	if n is Node3D and not (n as Node3D).visible:
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m: MeshInstance3D = n
		var moving: bool = _under_moving_body(m, holder) or m.get_skin_reference() != null
		var longest: float = m.mesh.get_aabb().size[m.mesh.get_aabb().get_longest_axis_index()] * m.global_basis.get_scale().x
		var xf: Transform3D = holder.global_transform.affine_inverse() * m.global_transform
		var arrays: Dictionary = {}          # surface -> arrays, read once for all pictures
		for acc: Acc in accs:
			var sheet: bool = acc.sheets.has(m)
			if moving:
				acc.dropped_moving += 1
			elif longest < acc.min_size:
				acc.dropped_small += 1
			elif acc.radius > 0.0 and Vector2(m.global_position.x, m.global_position.z).length() > acc.radius:
				acc.dropped_outside += 1
			else:
				for s: int in m.mesh.get_surface_count():
					var target: Acc = _target(acc, m.get_active_material(s))
					if target != null and _is_triangles(m.mesh, s):
						# only the kit's terrain is re-meshed for the far picture: a wide merged mesh of track and buildings
						# is a "sheet" for the rim too, and a grid would eat it (seen: the drive seed lost its track)
						jobs.append([target, m.mesh, xf, sheet, sheet and String(m.name).begins_with("Terrain"), acc, s])
						acc.kept += 1
					else:
						acc.dropped_other += 1
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null and (n as MultiMeshInstance3D).multimesh.mesh != null:
		var mmi: MultiMeshInstance3D = n
		var mm: MultiMesh = mmi.multimesh
		var base: Transform3D = holder.global_transform.affine_inverse() * mmi.global_transform
		var count: int = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		for s: int in mm.mesh.get_surface_count():
			var mat: Material = mmi.material_override if mmi.material_override != null else mm.mesh.surface_get_material(s)
			if mat != _pal or not _is_triangles(mm.mesh, s):
				for acc: Acc in accs:
					acc.dropped_other += 1
				continue
			var mlongest: float = mm.mesh.get_aabb().size[mm.mesh.get_aabb().get_longest_axis_index()]
			for i: int in count:
				var it: Transform3D = mm.get_instance_transform(i)
				var size: float = mlongest * it.basis.get_scale().y
				var io: Vector3 = (base * it).origin
				for acc: Acc in accs:
					if size < acc.min_size or acc.kept > 20000:
						acc.dropped_small += 1
					elif acc.radius > 0.0 and Vector2(io.x, io.z).length() > acc.radius:
						acc.dropped_outside += 1
					else:
						jobs.append([acc, mm.mesh, base * it, false, false, acc, s])
						acc.kept += 1
	for c: Node in n.get_children():
		_collect_standin(c, holder, accs, jobs)


## Where a surface of this material goes in the stand-in: the palette material into the first surface, another material
## of the toon shader (TLStyle.flat_material: the kernel's boxes and balls, in one colour) into a surface of its own,
## anything else (glass, water, a pack's own material) nowhere.
func _target(acc: Acc, mat: Material) -> Acc:
	if mat == _pal:
		return acc
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader == (_pal as ShaderMaterial).shader:
		if not acc.extra.has(mat):
			var child: Acc = Acc.new()
			child.kind = acc.kind
			child.thin = acc.thin
			child.small = acc.small
			child.radius = acc.radius
			child.rim = acc.rim
			child.band = acc.band
			acc.extra[mat] = child
		return acc.extra[mat]
	return null


func _append(acc: Acc, a: Array, xf: Transform3D, sheet: bool, terrain: bool = false) -> void:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var count: int = v.size()
	if count == 0:
		return
	var nb: Basis = xf.basis.inverse().transposed()
	var nrm: Variant = a[Mesh.ARRAY_NORMAL]
	var col: Variant = a[Mesh.ARRAY_COLOR]
	var uv: Variant = a[Mesh.ARRAY_TEX_UV]
	var cu: Variant = a[Mesh.ARRAY_CUSTOM0]
	var ix: Variant = a[Mesh.ARRAY_INDEX]
	var has_n: bool = nrm is PackedVector3Array and (nrm as PackedVector3Array).size() == count
	var has_c: bool = col is PackedColorArray and (col as PackedColorArray).size() == count
	var has_uv: bool = uv is PackedVector2Array and (uv as PackedVector2Array).size() == count
	var has_cu: bool = cu is PackedFloat32Array and (cu as PackedFloat32Array).size() == count * 4
	var out_v: PackedVector3Array = xf * v
	# the bent rim of toon.gdshader `tl_clip`, baked in: in the merged mesh the shader could not tell a terrain sheet
	# (bent per vertex) from what stands on it (moved as a whole by the height of its own origin)
	if acc.radius > 0.0 and acc.band > 0.0:
		var ro: float = Vector2(xf.origin.x, xf.origin.z).length()
		var whole: float = (acc.rim - xf.origin.y) * smoothstep(acc.radius - acc.band, acc.radius, ro)
		if sheet:
			for k: int in count:
				var p: Vector3 = out_v[k]
				p.y += (acc.rim - p.y) * smoothstep(acc.radius - acc.band, acc.radius, Vector2(p.x, p.z).length())
				out_v[k] = p
		elif whole != 0.0:
			for k: int in count:
				var q: Vector3 = out_v[k]
				q.y += whole
				out_v[k] = q
	var src: PackedInt32Array = ix if (ix is PackedInt32Array and (ix as PackedInt32Array).size() > 0) else PackedInt32Array()
	if src.is_empty():
		src.resize(count)
		for k: int in count:
			src[k] = k
	acc.src_tris += src.size() / 3
	var r: float = acc.radius
	var r2: float = (r + 3.0) * (r + 3.0)
	var slot: PackedInt32Array = PackedInt32Array()       # source vertex -> its place in the stand-in, -1 = not used
	slot.resize(count)
	slot.fill(-1)
	# P6, the far picture: a terrain sheet is re-meshed on a coarse grid (every vertex of a cell becomes the first one
	# met there; a triangle that lost a corner that way is dropped). The last cells before the plot edge keep every
	# vertex, so the rim still meets the world's ground without a gap.
	var grid: bool = terrain and acc.cell > 0.0
	var filter: bool = not terrain and (acc.thin > 0.0 or acc.small > 0.0)
	var small2: float = acc.small * acc.small
	var thin2: float = acc.thin * acc.thin
	var keep_r2: float = maxf(0.0, r - acc.cell * 2.0) * maxf(0.0, r - acc.cell * 2.0)
	var t: int = 0
	while t + 2 < src.size():
		# the plot cut of toon.gdshader, per triangle: a triangle wholly outside the plot is not part of the stand-in
		if r > 0.0:
			var a0: Vector3 = out_v[src[t]]
			var a1: Vector3 = out_v[src[t + 1]]
			var a2: Vector3 = out_v[src[t + 2]]
			if a0.x * a0.x + a0.z * a0.z > r2 and a1.x * a1.x + a1.z * a1.z > r2 and a2.x * a2.x + a2.z * a2.z > r2:
				t += 3
				continue
		# P6, the far picture: thin members and small detail inside a merged mesh go as whole triangles (FAR.md rule 8)
		if filter:
			var q0: Vector3 = out_v[src[t]]
			var ea: Vector3 = out_v[src[t + 1]] - q0
			var eb: Vector3 = out_v[src[t + 2]] - q0
			var long2: float = maxf(maxf(ea.length_squared(), eb.length_squared()), (ea - eb).length_squared())
			if long2 < small2 or ea.cross(eb).length_squared() < thin2 * long2:
				acc.dropped_tris += 1
				t += 3
				continue
		for c3: int in 3:
			var k: int = src[t + c3]
			if slot[k] < 0:
				var key: Vector2i = Vector2i.ZERO
				var in_grid: bool = false
				if grid:
					var pk: Vector3 = out_v[k]
					in_grid = not (r > 0.0 and pk.x * pk.x + pk.z * pk.z >= keep_r2)
					if in_grid:
						key = Vector2i(int(floor(pk.x / acc.cell)), int(floor(pk.z / acc.cell)))
						if acc.cells.has(key):
							slot[k] = int(acc.cells[key])
							continue
				slot[k] = acc.v.size()
				if in_grid:
					acc.cells[key] = slot[k]
				acc.v.append(out_v[k])
				acc.n.append((nb * (nrm as PackedVector3Array)[k]).normalized() if has_n else Vector3.UP)
				acc.c.append((col as PackedColorArray)[k] if has_c else Color.WHITE)
				acc.uv.append((uv as PackedVector2Array)[k] if has_uv else Vector2.ZERO)
				if has_cu:
					var f: PackedFloat32Array = cu
					acc.cu.append(f[k * 4])
					acc.cu.append(f[k * 4 + 1])
					acc.cu.append(f[k * 4 + 2])
					acc.cu.append(f[k * 4 + 3])
				else:
					acc.cu.append_array(PackedFloat32Array([0.0, 0.0, 0.0, 0.0]))
		var s0: int = slot[src[t]]
		var s1: int = slot[src[t + 1]]
		var s2: int = slot[src[t + 2]]
		if not (grid and (s0 == s1 or s0 == s2 or s1 == s2)):
			acc.ix.append(s0)
			acc.ix.append(s1)
			acc.ix.append(s2)
		t += 3
