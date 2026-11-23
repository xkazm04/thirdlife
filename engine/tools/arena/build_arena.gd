extends SceneTree
## Step 3 of the arena bake: arena_prep.py's file -> the core's own files (campaign rule 6: engine/cores/rink/arena/).
##   godot --headless --path engine -s res://tools/arena/build_arena.gd -- --src=<arena_src.json>
## Writes  res://cores/rink/arena/arena.scn   Node3D "RinkArena": one child a group (a MeshInstance3D, or a
##                                            MultiMeshInstance3D where the group has more than one instance or carries
##                                            per-instance data), named as arena.json names it. No material is stored:
##                                            the materials are made at run time by the style (rink_arena.gd).
##         res://cores/rink/arena/arena.json  the table: every group (mesh, thirdjam materials per surface, instance
##                                            count, triangles, its Unreal sources), every thirdjam material with its
##                                            parameters as the game had them, the rig's lights, its post settings.
## A mesh is thirdjam's own: positions, normals, UV0 and triangles as exported. Vertex colour is kept where thirdjam's
## material reads it (M_ClayCrowd, M_ArenaWood) and left out elsewhere. The fans' two cheering poses (their offsets,
## UV2..UV7 in Unreal) ride in CUSTOM0 and CUSTOM1; a fan's six per-instance floats are packed into the MultiMesh's
## custom data: x = weight, y = coat, z = accent, w = end * (4 + delay + 2 * pose).
## Prints one line `tl.arena.build/1 {...}` last; exit 0 only when every group was built.

const OUT_DIR := "res://cores/rink/arena/"
const VERTEX_COLOUR_MASTERS: PackedStringArray = ["M_ClayCrowd", "M_ArenaWood"]


func _init() -> void:
	var src := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--src="):
			src = a.substr(6)
	var rep := {"ok": false}
	var txt := FileAccess.get_file_as_string(src)
	var d: Variant = JSON.parse_string(txt) if txt != "" else null
	if not (d is Dictionary):
		rep["error"] = "cannot read %s" % src
		_finish(rep, 1)
		return
	var data: Dictionary = d
	var mats: Dictionary = data["materials"]
	var meshes: Dictionary = {}
	var root := Node3D.new()
	root.name = "RinkArena"
	var table_groups: Array = []
	var built := 0
	var tris := 0
	for g: Dictionary in data["groups"]:
		var mname: String = g["mesh"]
		var gm: Array = g["materials"]
		var mkey: String = str(g["name"])        # a mesh of its own a group: its surfaces take the group's materials at run time
		meshes[mkey] = _mesh(mname, data["meshes"][mname], gm, mats)
		var mesh: ArrayMesh = meshes[mkey]
		var inst: Array = g["instances"]
		var node: GeometryInstance3D
		if inst.size() == 1 and not g.has("custom"):
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.transform = _xf(inst[0])
			node = mi
		else:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = g.has("custom")
			mm.mesh = mesh
			# The instances ride on the node as a MultiMesh buffer (12 floats a transform in rows, then 4 of custom data):
			# a MultiMesh filled in a headless run keeps nothing (the dummy renderer stores no buffer), so the run-time
			# script (rink_arena.gd) sets instance_count and buffer from these.
			var stride: int = 16 if g.has("custom") else 12
			var buf := PackedFloat32Array()
			buf.resize(inst.size() * stride)
			for i: int in inst.size():
				var a: Array = inst[i]
				var o: int = i * stride
				for r: int in 3:
					buf[o + r * 4] = a[r]
					buf[o + r * 4 + 1] = a[3 + r]
					buf[o + r * 4 + 2] = a[6 + r]
					buf[o + r * 4 + 3] = a[9 + r]
				if g.has("custom"):
					var c: Array = g["custom"][i]
					buf[o + 12] = float(c[0])
					buf[o + 13] = float(c[1])
					buf[o + 14] = float(c[2])
					buf[o + 15] = signf(float(c[3])) * (4.0 + clampf(float(c[4]), 0.0, 0.999) + 2.0 * float(c[5]))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.set_meta(&"tl_count", inst.size())
			mmi.set_meta(&"tl_buffer", buf)
			node = mmi
		node.name = str(g["name"])
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(g["cast_shadow"]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
		node.owner = root
		built += 1
		tris += int(g["triangles"])
		table_groups.append({"name": g["name"], "mesh": mname, "layer": g["layer"], "count": inst.size(), "triangles": int(g["triangles"]),
			"materials": gm, "cast_shadow": bool(g["cast_shadow"]), "sources": g["sources"], "first": inst[0]})
	var packed := PackedScene.new()
	var err: int = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_DIR + "arena.scn", ResourceSaver.FLAG_COMPRESS)
	rep["scene_err"] = err
	var table := {
		"schema": "tl.rink.arena/1",
		"note": "thirdjam's hall as its game draws it (hockey.regular, look tier p3_clay), exported by engine/tools/arena (export_arena.py -> arena_prep.py -> build_arena.gd). Axes: rink x -> x, rink y -> z, up -> y, metres. 'first' = the first instance's transform (three basis columns, then the origin). Material parameters are thirdjam's own, read from the running game.",
		"source": data["source"], "totals": data["totals"], "left_out": data["left_out"],
		"groups": table_groups, "materials": mats, "rink_surfaces": data["rink_surfaces"], "lights": data["lights"], "sky": data["sky"], "post": data["post"],
		"light_sum": data["light_sum"], "collections": data["collections"],
		"fan_custom": "x = weight, y = coat, z = accent, w = end * (4 + delay + 2 * pose)",
	}
	var f := FileAccess.open(OUT_DIR + "arena.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(table, " ", false) + "\n")
	f.close()
	rep["groups_found"] = (data["groups"] as Array).size()
	rep["groups_built"] = built
	rep["meshes"] = meshes.size()
	rep["triangles"] = tris
	rep["scene_bytes"] = FileAccess.get_file_as_bytes(OUT_DIR + "arena.scn").size()
	rep["ok"] = err == OK and built == rep["groups_found"]
	root.free()
	_finish(rep, 0 if rep["ok"] else 1)


func _finish(rep: Dictionary, code: int) -> void:
	print("tl.arena.build/1 " + JSON.stringify(rep))
	quit(code)


func _master(mats: Dictionary, m: String) -> String:
	return str((mats.get(m, {}) as Dictionary).get("master", ""))


func _xf(a: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])), Vector3(a[9], a[10], a[11]))


func _mesh(mname: String, m: Dictionary, gm: Array, mats: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.resource_name = mname
	var surfaces: Array = m["surfaces"]
	for s: int in surfaces.size():
		var sd: Dictionary = surfaces[s]
		var master: String = _master(mats, str(gm[s])) if s < gm.size() else ""
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		var v: Array = sd["v"]
		var n: int = v.size() / 3
		var pv := PackedVector3Array()
		var pn := PackedVector3Array()
		pv.resize(n)
		pn.resize(n)
		var nn: Array = sd["n"]
		for i: int in n:
			pv[i] = Vector3(v[i * 3], v[i * 3 + 1], v[i * 3 + 2])
			pn[i] = Vector3(nn[i * 3], nn[i * 3 + 1], nn[i * 3 + 2])
		arr[Mesh.ARRAY_VERTEX] = pv
		arr[Mesh.ARRAY_NORMAL] = pn
		if sd.has("uv"):
			var uv: Array = sd["uv"]
			var pu := PackedVector2Array()
			pu.resize(n)
			for i: int in n:
				pu[i] = Vector2(uv[i * 2], uv[i * 2 + 1])
			arr[Mesh.ARRAY_TEX_UV] = pu
		if sd.has("c") and VERTEX_COLOUR_MASTERS.has(master):
			var c: Array = sd["c"]
			var pc := PackedColorArray()
			pc.resize(n)
			for i: int in n:
				pc[i] = Color(c[i * 4], c[i * 4 + 1], c[i * 4 + 2], c[i * 4 + 3])
			arr[Mesh.ARRAY_COLOR] = pc
		var flags: int = 0
		if sd.has("pose_a"):
			var pa: Array = sd["pose_a"]
			var pb: Array = sd["pose_b"]
			var c0 := PackedFloat32Array()
			var c1 := PackedFloat32Array()
			c0.resize(n * 3)
			c1.resize(n * 3)
			for i: int in n * 3:
				c0[i] = pa[i]
				c1[i] = pb[i]
			arr[Mesh.ARRAY_CUSTOM0] = c0
			arr[Mesh.ARRAY_CUSTOM1] = c1
			flags |= Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
			flags |= Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
		arr[Mesh.ARRAY_INDEX] = PackedInt32Array(sd["i"])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		mesh.surface_set_name(s, "slot%d" % s)
	return mesh
