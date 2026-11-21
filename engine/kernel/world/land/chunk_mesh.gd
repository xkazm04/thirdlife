extends RefCounted
## Global vertex samples keep shading and the plot-rim colour lookup continuous across chunks.

var positions: PackedVector3Array
var normals: PackedVector3Array
var colours: PackedColorArray
var uvs: PackedVector2Array
var custom: PackedFloat32Array
var bounds: AABB
var holes := {}  # Global indices of NaN heightfield samples.

func prepare(t, paint_vertices: Dictionary) -> void:
	var rows: int = t.nz + 1
	var width: int = t.nx + 1
	var bands := clampi(OS.get_processor_count() - 1, 1, mini(rows, 8))
	var per := ceili(float(rows) / bands)
	var code := 1.0 + 16.0 * float(TLStyle.index("terrain"))
	var slices: Array[Dictionary] = []
	slices.resize(bands)
	var sample := func(b: int) -> void:
		slices[b] = _sample_rows(t, b * per, mini((b + 1) * per, rows), code)
	WorkerThreadPool.wait_for_group_task_completion(WorkerThreadPool.add_group_task(sample, bands))
	positions = PackedVector3Array()
	normals = PackedVector3Array()
	colours = PackedColorArray()
	custom = PackedFloat32Array()
	uvs = PackedVector2Array()
	uvs.resize(width * rows)
	holes.clear()
	for band in slices:
		positions.append_array(band.positions)
		normals.append_array(band.normals)
		colours.append_array(band.colours)
		custom.append_array(band.custom)
		holes.merge(band.holes)
	for k: int in paint_vertices:
		colours[k] = paint_vertices[k]
	if not t.pads.is_empty():
		t.rim_material = t._rim_material(colours, Vector2i(width, rows), Vector2(t.x0, t.z0), t.cell)
	bounds = AABB(positions[0], Vector3.ZERO)
	for p: Vector3 in positions:
		bounds = bounds.expand(p)


## Read neighbouring heights from the whole grid even at the edge of a worker's band.
static func _sample_rows(t, first: int, end: int, code: float) -> Dictionary:
	var heights: PackedFloat32Array = t.heights
	var roads: PackedFloat32Array = t.road_d
	var rivers: PackedFloat32Array = t.river_d
	var wear: PackedFloat32Array = t.wear_map
	var meadow: PackedFloat32Array = t.meadow_map
	var nx: int = t.nx
	var nz: int = t.nz
	var x0: float = t.x0
	var z0: float = t.z0
	var cell: float = t.cell
	var ground_y: float = t.GROUND_Y
	var w := nx + 1
	var count := maxi(0, end - first) * w
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var cs := PackedColorArray()
	var cu := PackedFloat32Array()
	var missing := {}
	vs.resize(count)
	ns.resize(count)
	cs.resize(count)
	cu.resize(count * 4)
	var dst := 0
	for j in range(first, end):
		var row := j * w
		var above := maxi(0, j - 1) * w
		var below := mini(nz, j + 1) * w
		var z := z0 + float(j) * cell
		for i in w:
			var k := row + i
			var x := x0 + float(i) * cell
			var y := heights[k] + ground_y
			var nrm := Vector3(heights[row + maxi(0, i - 1)] - heights[row + mini(nx, i + 1)],
				2.0 * cell, heights[above + i] - heights[below + i])
			if not is_finite(y):
				if is_nan(y):
					missing[k] = true
				y = 0.0
			nrm = nrm.normalized() if nrm.is_finite() else Vector3.UP
			var p := Vector3(x, y, z)
			vs[dst] = p
			ns[dst] = nrm
			cs[dst] = t._col(p.x, p.y, p.z, nrm, roads[k], rivers[k], wear[k], meadow[k])
			cu[dst * 4] = x
			cu[dst * 4 + 1] = y
			cu[dst * 4 + 2] = z
			cu[dst * 4 + 3] = code
			dst += 1
	return {"positions": vs, "normals": ns, "colours": cs, "custom": cu, "holes": missing}


func build(t, rect: Rect2i, mat: Material, label: String, lod: int, fixed: bool) -> MeshInstance3D:
	return instance_from_arrays(chunk_arrays(t, rect, lod, fixed), mat, label)


func chunk_arrays(t, rect: Rect2i, lod: int, fixed: bool) -> Array:
	var stride := 1 << lod
	var width := ceili(float(rect.size.x) / stride) + 1
	var depth := ceili(float(rect.size.y) / stride) + 1
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var cs := PackedColorArray()
	var uv := PackedVector2Array()
	var cu := PackedFloat32Array()
	var ix := PackedInt32Array()
	var pitch: int = t.nx + 1
	if lod == 0:
		for row in depth:
			var start := (rect.position.y + row) * pitch + rect.position.x
			var end := start + width
			vs.append_array(positions.slice(start, end))
			ns.append_array(normals.slice(start, end))
			cs.append_array(colours.slice(start, end))
			uv.append_array(uvs.slice(start, end))
			cu.append_array(custom.slice(start * 4, end * 4))
	else:
		for row in depth:
			var z := mini(rect.position.y + row * stride, rect.end.y)
			for col in width:
				var x := mini(rect.position.x + col * stride, rect.end.x)
				var k := z * pitch + x
				vs.append(positions[k])
				ns.append(normals[k])
				cs.append(colours[k])
				uv.append(uvs[k])
				cu.append_array(custom.slice(k * 4, k * 4 + 4))
	var missing := {}
	if not holes.is_empty():
		for row in depth:
			var z := mini(rect.position.y + row * stride, rect.end.y)
			for col in width:
				var x := mini(rect.position.x + col * stride, rect.end.x)
				if holes.has(z * pitch + x):
					missing[row * width + col] = true
	# A whole-grid build may span multiple split rules. Normal chunk jobs resolve their split once.
	var splits: Dictionary = t.fixed_chunks
	var mixed := not fixed and not splits.is_empty() and (rect.position / 32) != ((rect.end - Vector2i.ONE) / 32)
	fixed = fixed or (not mixed and splits.has(rect.position / 32))
	ix.resize((depth - 1) * (width - 1) * 6)
	var n := 0
	for row in depth - 1:
		var z := rect.position.y + row * stride
		for col in width - 1:
			var x := rect.position.x + col * stride
			var a := row * width + col
			var b := a + 1
			var d := a + width
			var c := d + 1
			var even := not fixed and ((x + z) & 1) == 0 and (not mixed or not splits.has(Vector2i(x >> 5, z >> 5)))
			var diag := c if even else d
			if missing.is_empty() or not (missing.has(a) or missing.has(b) or missing.has(diag)):
				ix[n] = a
				ix[n + 1] = b
				ix[n + 2] = diag
				n += 3
			var first := a if even else b
			if missing.is_empty() or not (missing.has(first) or missing.has(c) or missing.has(d)):
				ix[n] = first
				ix[n + 1] = c
				ix[n + 2] = d
				n += 3
	ix.resize(n)
	if lod > 0:
		# Walk the perimeter clockwise. A vertical skirt hides even the lowest omitted odd sample.
		var edge := PackedInt32Array()
		for x in width:
			edge.append(x)
		for z in range(1, depth):
			edge.append(z * width + width - 1)
		for x in range(width - 2, -1, -1):
			edge.append((depth - 1) * width + x)
		for z in range(depth - 2, 0, -1):
			edge.append(z * width)
		var bottom := vs.size()
		for i in edge.size():
			var k := edge[i]
			var p := vs[k]
			p.y = bounds.position.y - t.cell
			vs.append(p)
			ns.append(ns[k])
			cs.append(cs[k])
			uv.append(uv[k])
			cu.append_array(PackedFloat32Array([p.x, p.y, p.z, cu[4 * k + 3]]))
			var j := (i + 1) % edge.size()
			ix.append_array(PackedInt32Array([edge[j], edge[i], bottom + i, edge[j], bottom + i, bottom + j]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vs
	arrays[Mesh.ARRAY_NORMAL] = ns
	arrays[Mesh.ARRAY_COLOR] = cs
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_CUSTOM0] = cu
	arrays[Mesh.ARRAY_INDEX] = ix
	return arrays


static func instance_from_arrays(arrays: Array, mat: Material, label: String) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	if not (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		mesh.surface_set_material(0, mat)
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return instance

## One palette surface per wet chunk, with the same world-space UVs as the village ponds.
func add_water(parent: MeshInstance3D, t, rect: Rect2i, groups: Array) -> void:
	if groups.is_empty():
		return
	var water := TLMesh.new(t.base_seed)
	for group in groups:
		for cell in group.cells:
			var x := rect.position.x + int(cell) % rect.size.x
			var z := rect.position.y + int(cell) / rect.size.x
			var p := Vector3(t.x0 + x * t.cell, group.level_m, t.z0 + z * t.cell)
			var dx := Vector3.RIGHT * float(t.cell)
			var dz := Vector3.BACK * float(t.cell)
			_water_tri(water, p, p + dz, p + dx + dz)
			_water_tri(water, p, p + dx + dz, p + dx)
	if water.tri_count > 0:
		var node := water.instance("ChunkWater")
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)


static func _water_tri(water: TLMesh, a: Vector3, b: Vector3, c: Vector3) -> void:
	water.tri(a, b, c, "water", Color.WHITE, Vector2(a.x,a.z) * 0.1, Vector2(b.x,b.z) * 0.1, Vector2(c.x,c.z) * 0.1)
