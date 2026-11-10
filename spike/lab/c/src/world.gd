class_name WorldBuilder
extends RefCounted
## Builds the static world from kit meshes: terrain chunks + collider, instanced vegetation (MultiMesh in spatial
## cells so frustum culling works), arena kit, house, site props. Everything is placed from data/layout.json
## (generated) and data/site.json (authored).

var style: Style
var root: Node3D
var meshes: Dictionary = {}
var stats: Dictionary = {"mesh_instances": 0, "multimesh_groups": 0, "instances": 0, "tris": 0}
var layout: Dictionary
var site: Dictionary


func _init(st: Style, r: Node3D) -> void:
	style = st
	root = r
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/layout.json"))
	site = JSON.parse_string(FileAccess.get_file_as_string("res://data/site.json"))


func mesh(kind: String) -> ArrayMesh:
	if not meshes.has(kind):
		var m := Vxm.load_mesh("res://assets/%s.vxm" % kind, style)
		meshes[kind] = m
		if m != null:
			stats["tris"] += Vxm.mesh_stats(m).y
	return meshes[kind]


func place(kind: String, pos: Vector3, yaw_deg: float = 0.0, scale: float = 1.0, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(kind)
	mi.position = pos
	mi.rotation.y = deg_to_rad(yaw_deg)
	mi.scale = Vector3.ONE * scale
	(parent if parent != null else root).add_child(mi)
	stats["mesh_instances"] += 1
	return mi


func scatter(items: Array, cell: float, kind_of: Callable = Callable(), cast_shadow: bool = true) -> void:
	var groups: Dictionary = {}
	for it: Dictionary in items:
		var k: String = it["k"] if it.has("k") else kind_of.call(it)
		var key := "%s|%d|%d" % [k, int(floor(it["x"] / cell)), int(floor(it["z"] / cell))]
		if not groups.has(key):
			groups[key] = {"k": k, "list": []}
		groups[key]["list"].append(it)
	for key: String in groups:
		var g: Dictionary = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh(g["k"])
		var lst: Array = g["list"]
		mm.instance_count = lst.size()
		for i in lst.size():
			var it: Dictionary = lst[i]
			var b := Basis(Vector3.UP, it["yaw"]).scaled(Vector3.ONE * float(it.get("s", 1.0)))
			mm.set_instance_transform(i, Transform3D(b, Vector3(it["x"], it["y"], it["z"])))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
		stats["multimesh_groups"] += 1
		stats["instances"] += lst.size()
		stats["tris"] += 0


func build_terrain() -> Dictionary:
	var info := {"chunks": 0}
	for name: String in ["terrain0", "terrain1"]:
		var chunks := Vxm.load_chunks("res://assets/%s.vxm" % name, style)
		for ch: Dictionary in chunks:
			var mi := MeshInstance3D.new()
			mi.mesh = ch["mesh"]
			mi.name = name
			if name == "terrain1":
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
			stats["tris"] += Vxm.mesh_stats(ch["mesh"]).y
			info["chunks"] += 1
	# collider from the same heights
	var f := FileAccess.open("res://assets/terrain_h.bin", FileAccess.READ)
	var nx := int(f.get_float())
	var nz := int(f.get_float())
	var x0 := f.get_float()
	var z0 := f.get_float()
	var res := f.get_float()
	var data := f.get_buffer(nx * nz * 4).to_float32_array()
	var shape := HeightMapShape3D.new()
	shape.map_width = nx
	shape.map_depth = nz
	shape.map_data = data
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.scale = Vector3(res, 1.0, res)
	body.position = Vector3(x0 + res * (0.5 + (nx - 1) / 2.0), 0, z0 + res * (0.5 + (nz - 1) / 2.0))
	root.add_child(body)
	return info


func build_vegetation() -> void:
	scatter(layout["trees"], 70.0)
	scatter(layout["rocks"], 80.0)
	scatter(layout["tufts"], 40.0, Callable(), false)
	var far: Array = []
	for t: Dictionary in layout["far_trees"]:
		var d: Dictionary = t.duplicate()
		d["k"] = "pine_far"
		far.append(d)
	scatter(far, 160.0, Callable(), false)
	for l: Dictionary in layout["lamps"]:
		place("lamp", Vector3(l["x"], l["y"], l["z"]), rad_to_deg(l["yaw"]) + 90.0)


func build_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n: int = style.d["clouds"]["count"]
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh("cloud%d" % (1 + i % 2))
		mi.position = Vector3(rng.randf_range(-260, 260), rng.randf_range(95, 150), rng.randf_range(-330, -120))
		mi.rotation.y = rng.randf_range(-0.5, 0.5)
		mi.scale = Vector3.ONE * rng.randf_range(1.2, 2.4)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)


func build_house() -> Dictionary:
	var h: Dictionary = layout["house"]
	var p := Vector3(h["pos"][0], h["pos"][1], h["pos"][2])
	place("house", p)
	var fp: Array = h["frame_pos"]
	place("house_frame", Vector3(fp[0], fp[1], fp[2]))
	# chimney smoke + window glow lights
	var sm := Fx.smoke(root)
	sm.global_position = p + Vector3(-3.4, 8.0, -0.2)
	sm.emitting = true
	for x: float in [-1.9, 2.6]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.72, 0.4)
		l.light_energy = 1.4
		l.omni_range = 5.0
		l.position = p + Vector3(x, 1.5, 4.2)
		root.add_child(l)
	return {"smoke": sm}


func build_arena() -> Dictionary:
	var a: Dictionary = layout["arena"]
	var c := Vector3(a["centre"][0], a["centre"][1], a["centre"][2])
	var ice_y: float = a["ice_y"]
	place("ice", Vector3(c.x, ice_y, c.z))
	place("boards", Vector3(c.x, ice_y, c.z))
	for k: String in ["stands", "benches", "goals"]:
		for it: Dictionary in site[k]:
			place(it["k"], Vector3(it["pos"][0], it["pos"][1], it["pos"][2]), it["yaw"])
	# ribs
	var ribs: Array = []
	var ribs_l: Array = a["ribs"]
	for i in ribs_l.size():
		var rx: float = ribs_l[i]["x"]
		var pos := Vector3(rx, c.y, c.z)
		if ribs_l[i]["built"]:
			place("rib", pos)
			ribs.append({"x": rx, "built": true})
		else:
			var node := Node3D.new()
			node.position = pos
			root.add_child(node)
			var solid := MeshInstance3D.new()
			solid.mesh = mesh("rib")
			var sm := style.voxel_material(0.25, false, true)
			sm.set_shader_parameter(&"reveal", 0.0)
			sm.set_shader_parameter(&"reveal_h", 15.0)
			solid.material_override = null
			for s in solid.mesh.get_surface_count():
				pass
			solid.set_surface_override_material(0, sm)
			node.add_child(solid)
			var wire := MeshInstance3D.new()
			wire.mesh = mesh("rib_holo")
			var wm := style.voxel_material(0.125, false, true)
			wm.set_shader_parameter(&"reveal", 0.0)
			wm.set_shader_parameter(&"inv", true)
			wm.set_shader_parameter(&"reveal_h", 15.0)
			wire.set_surface_override_material(0, wm)
			node.add_child(wire)
			var skin := MeshInstance3D.new()
			skin.mesh = mesh("rib_skin")
			var hm := style.holo_material(0.25, 4.0)
			skin.set_surface_override_material(0, hm if skin.mesh.get_surface_count() == 1 else hm)
			if skin.mesh.get_surface_count() > 1:
				skin.set_surface_override_material(1, hm)
			skin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(skin)
			wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ribs.append({"x": rx, "built": false, "node": node, "solid": solid, "wire": wire, "skin": skin, "sm": sm, "wm": wm, "hm": hm, "p": 0.0, "done": false})
	# purlins + cladding in the built bays
	var arch := ArchInfo.new()
	for i in 4:
		var x0: float = ribs_l[i]["x"] + 0.5
		for t in [-0.88, -0.66, -0.44, -0.22, 0.0, 0.22, 0.44, 0.66, 0.88]:
			var pt := arch.point(t)
			place("purlin", Vector3(x0, c.y + pt.y + 0.45, c.z + pt.x))
		if i < 2:
			place("roof_skin", Vector3(x0, c.y, c.z))
	return {"ribs": ribs, "centre": c}


func build_site() -> Dictionary:
	for it: Dictionary in site["scaffolds"]:
		place(it["k"], Vector3(it["pos"][0], it["pos"][1], it["pos"][2]), it["yaw"])
	for k: String in ["props", "fences"]:
		for it: Dictionary in site[k]:
			place(it["k"], Vector3(it["pos"][0], it["pos"][1], it["pos"][2]), it["yaw"])
	var cranes: Array = []
	for cd: Dictionary in site["cranes"]:
		var node := Node3D.new()
		node.position = Vector3(cd["pos"][0], cd["pos"][1], cd["pos"][2])
		root.add_child(node)
		var mast := MeshInstance3D.new()
		mast.mesh = mesh("crane_mast")
		node.add_child(mast)
		var head := Node3D.new()
		head.position = Vector3(0, 30.5, 0)
		node.add_child(head)
		var hm := MeshInstance3D.new()
		hm.mesh = mesh("crane_head")
		head.add_child(hm)
		var piv := Node3D.new()
		piv.position = Vector3(cd["trolley"], -0.45, 0)
		head.add_child(piv)
		var ld := MeshInstance3D.new()
		ld.mesh = mesh(cd["load"])
		piv.add_child(ld)
		cranes.append({"node": node, "head": head, "load": piv, "yaw": cd["yaw"], "sway": cd["sway"], "phase": randf() * 6.0})
	return {"cranes": cranes}


class ArchInfo:
	extends RefCounted
	const SPAN := 22.0
	const SPRING := 6.0
	const APEX := 14.0
	const TH := 1.2

	func point(t: float) -> Vector2:
		var rise := APEX - SPRING
		var r := (SPAN * SPAN + rise * rise) / (2 * rise)
		var cy := APEX - r
		var rm := r - TH / 2.0 - 0.0
		var amax := asin(SPAN / r)
		var a := t * amax
		return Vector2(rm * sin(a), cy + rm * cos(a))
