extends RefCounted
## Test oracle: the single village mesh before chunking.

static func build_mesh(t, mat: Material, name_: String = "WorldTerrain") -> MeshInstance3D:
	var w: int = t.nx + 1
	var count: int = w * (t.nz + 1)
	var vs: PackedVector3Array = PackedVector3Array()
	var ns: PackedVector3Array = PackedVector3Array()
	var cs: PackedColorArray = PackedColorArray()
	var uv: PackedVector2Array = PackedVector2Array()
	var cu: PackedFloat32Array = PackedFloat32Array()
	vs.resize(count)
	ns.resize(count)
	uv.resize(count)
	cu.resize(count * 4)
	var code: float = 1.0 + 16.0 * float(TLStyle.index("terrain"))
	for j: int in t.nz + 1:
		var z: float = t.z0 + float(j) * t.cell
		for i: int in w:
			var k: int = j * w + i
			var x: float = t.x0 + float(i) * t.cell
			var y: float = t.heights[k] + t.GROUND_Y
			var nrm: Vector3 = Vector3(t.heights[t._v(i - 1, j)] - t.heights[t._v(i + 1, j)], 2.0 * t.cell, t.heights[t._v(i, j - 1)] - t.heights[t._v(i, j + 1)]).normalized()
			vs[k] = Vector3(x, y, z)
			ns[k] = nrm
			cu[k * 4] = x
			cu[k * 4 + 1] = y
			cu[k * 4 + 2] = z
			cu[k * 4 + 3] = code
	# The same colours drive the mesh and the pack-rim map. Workers read the finished grid and normals;
	# each writes a private slice, joined in vertex order before upload.
	var bands := clampi(OS.get_processor_count() - 1, 1, 8)
	var per := ceili(float(count) / bands)
	var slices: Array[PackedColorArray] = []
	slices.resize(bands)
	var paint := func(b: int) -> void:
		var start := mini(b * per, count)
		var end := mini(start + per, count)
		var colours := PackedColorArray()
		colours.resize(end - start)
		for k: int in range(start, end):
			var p := vs[k]
			colours[k - start] = t._col(p.x, p.y, p.z, ns[k], t.road_d[k], t.river_d[k], t.wear_map[k], t.meadow_map[k])
		slices[b] = colours
	WorkerThreadPool.wait_for_group_task_completion(WorkerThreadPool.add_group_task(paint, bands))
	for colours: PackedColorArray in slices:
		cs.append_array(colours)
	if not t.pads.is_empty():
		t.rim_material = t._rim_material(cs, Vector2i(w, t.nz + 1), Vector2(t.x0, t.z0), t.cell)
	var ix: PackedInt32Array = PackedInt32Array()
	ix.resize(t.nx * t.nz * 6)
	var q: int = 0
	for j: int in t.nz:
		for i: int in t.nx:
			var a: int = j * w + i
			var b: int = a + 1
			var d: int = a + w
			var c: int = d + 1
			# the faces look up (+y): Godot winds front faces clockwise seen from outside
			if (i + j) % 2 == 0:
				ix[q] = a; ix[q + 1] = b; ix[q + 2] = c
				ix[q + 3] = a; ix[q + 4] = c; ix[q + 5] = d
			else:
				ix[q] = a; ix[q + 1] = b; ix[q + 2] = d
				ix[q + 3] = b; ix[q + 4] = c; ix[q + 5] = d
			q += 6
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	arr[Mesh.ARRAY_COLOR] = cs
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_CUSTOM0] = cu
	arr[Mesh.ARRAY_INDEX] = ix
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	mesh.surface_set_material(0, mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi
