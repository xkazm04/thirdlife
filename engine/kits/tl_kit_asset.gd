class_name TLKitAsset
extends RefCounted
## A mesh asset (`.glb` / `.gltf` of `assets/<owner>/`, contracts/ASSETS.md) drawn in the house look.
##
## The file's own materials are never used. Each glTF material NAME is a palette key of the style file
## (`yellow`, `flag_a`, ...): every triangle is emitted again through `TLMesh` (flat face, palette column in CUSTOM0,
## the style's one toon material), so an imported mesh gets the same bands, ink, hatching and palette as a kit part,
## and a style swap recolours it like everything else. An unknown key is drawn `white` with a warning.
##
## Every glTF node becomes a node of the same name with the same local transform (a `MeshInstance3D` when it has a
## mesh, a `Node3D` otherwise), so a model's moving parts stay separate and keep their pivots for later animation.
##   var pip: Node3D = TLKitAsset.build("C:/.../assets/engine/pip.glb")     # null + push_error when unreadable
## Root: `Node3D` named after the file, metadata `tl_asset` (the path), `tl_tris`, `tl_parts` (names of mesh parts).
## Visual only: no body. Works under --headless (stub material, as every kit part).


static func build(path: String) -> Node3D:
	if not FileAccess.file_exists(path):
		push_error("TLKitAsset: no file %s" % path)
		return null
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var err: Error = doc.append_from_file(path, state)
	if err != OK:
		push_error("TLKitAsset: cannot read %s (%s)" % [path, error_string(err)])
		return null
	var nodes: Array = state.get_nodes()
	var meshes: Array = state.get_meshes()
	var root: Node3D = Node3D.new()
	root.name = path.get_file().get_basename()
	var made: Array = []
	made.resize(nodes.size())
	var tris: int = 0
	var parts: PackedStringArray = PackedStringArray()
	for i: int in nodes.size():
		var gn: GLTFNode = nodes[i]
		var nm: String = str(gn.get("original_name")) if str(gn.get("original_name")) != "" else gn.resource_name
		var n: Node3D
		if gn.mesh >= 0 and gn.mesh < meshes.size():
			var mk: TLMesh = TLMesh.new(1)
			_emit(mk, (meshes[gn.mesh] as GLTFMesh).mesh, path)
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = mk.build(nm)
			mi.set_meta(&"tl_tris", mk.tri_count)
			tris += mk.tri_count
			parts.append(nm)
			n = mi
		else:
			n = Node3D.new()
		n.name = nm
		n.transform = Transform3D(Basis(gn.rotation).scaled(gn.scale), gn.position)
		made[i] = n
	for i: int in nodes.size():
		var gn: GLTFNode = nodes[i]
		if gn.parent >= 0:
			(made[gn.parent] as Node3D).add_child(made[i])
		else:
			root.add_child(made[i])
	root.set_meta(&"tl_asset", path)
	root.set_meta(&"tl_tris", tris)
	root.set_meta(&"tl_parts", parts)
	return root


## Every triangle of every surface, keyed by the surface's material name; outward winding taken from the file's
## normals (flat faces: the file's own normals only decide which side is out).
static func _emit(mk: TLMesh, im: ImporterMesh, path: String) -> void:
	if im == null:
		return
	for s: int in im.get_surface_count():
		var key: String = ""
		var mat: Material = im.get_surface_material(s)
		if mat != null:
			key = mat.resource_name
		if not TLStyle.has_key(key):
			push_warning("TLKitAsset: %s: material '%s' is not a palette key, drawn white" % [path.get_file(), key])
			key = "white"
		var arr: Array = im.get_surface_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(vs.size())
			for k: int in vs.size():
				idx[k] = k
		for t: int in range(0, idx.size() - 2, 3):
			var a: Vector3 = vs[idx[t]]
			var b: Vector3 = vs[idx[t + 1]]
			var c: Vector3 = vs[idx[t + 2]]
			var out: Vector3 = (b - a).cross(c - a)
			if not ns.is_empty():
				var fn: Vector3 = ns[idx[t]] + ns[idx[t + 1]] + ns[idx[t + 2]]
				if out.dot(fn) < 0.0:
					mk.tri(a, c, b, key)
					continue
			mk.tri(a, b, c, key)
