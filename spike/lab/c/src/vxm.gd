class_name Vxm
extends RefCounted
## Loader for the .vxm build output of gen/vox.py. One chunk = {pivot, bbox, mesh}. Surface 0 opaque, 1 glass/water.

static func load_chunks(path: String, style: Style) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("vxm missing: " + path)
		return []
	var magic := f.get_buffer(4).get_string_from_ascii()
	assert(magic == "VXM1")
	var vs := f.get_float()
	var nch := f.get_32()
	var res: Array = []
	for c in nch:
		var pivot := Vector3(f.get_float(), f.get_float(), f.get_float())
		var bb := PackedFloat32Array([f.get_float(), f.get_float(), f.get_float(), f.get_float(), f.get_float(), f.get_float()])
		var ns := f.get_32()
		var mesh := ArrayMesh.new()
		for s in ns:
			var cls := f.get_32()
			var nv := f.get_32()
			var ni := f.get_32()
			var pos := f.get_buffer(nv * 12).to_vector3_array()
			var nrm := f.get_buffer(nv * 12).to_vector3_array()
			var c0 := f.get_buffer(nv * 4)
			var idx := f.get_buffer(ni * 4).to_int32_array()
			var arr: Array = []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = pos
			arr[Mesh.ARRAY_NORMAL] = nrm
			arr[Mesh.ARRAY_CUSTOM0] = c0
			arr[Mesh.ARRAY_INDEX] = idx
			var flags: int = Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
			mesh.surface_set_material(mesh.get_surface_count() - 1, style.voxel_material(vs, cls == 1))
		res.append({"pivot": pivot, "bbox": bb, "mesh": mesh, "vs": vs})
	return res


## Single-chunk convenience: returns one ArrayMesh (first chunk).
static func load_mesh(path: String, style: Style) -> ArrayMesh:
	var ch := load_chunks(path, style)
	return ch[0]["mesh"] if ch.size() > 0 else null


static func mesh_stats(mesh: Mesh) -> Vector2i:
	var v := 0
	var t := 0
	for i in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(i)
		v += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		t += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return Vector2i(v, t)
