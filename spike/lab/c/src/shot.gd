extends Node3D
## Asset viewer for look-and-fix loops: --vxm=name[,name..] [--vs=..] [--yaw=deg] [--pitch=deg] [--dist=m] [--h=m] [--spacing=m] [--out=png] [--style=overcast] [--gi=none|sdfgi]
var _args: Dictionary = {}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var style := Style.new()
	style.load_file("res://data/style_overcast.json" if _args.get("style", "") == "overcast" else "res://data/style.json")
	var we := WorldEnvironment.new()
	we.environment = style.make_environment(_args.get("gi", "none"), false, true)
	add_child(we)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	style.apply_light(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("5d7a38")
	gm.roughness = 1.0
	ground.material_override = gm
	add_child(ground)
	var names: PackedStringArray = String(_args.get("vxm", "oak1")).split(",")
	var spacing: float = float(_args.get("spacing", "6"))
	var tris := 0
	var x0 := -spacing * (names.size() - 1) / 2.0
	for i in names.size():
		var ch := Vxm.load_chunks("res://assets/%s.vxm" % names[i], style)
		var root := Node3D.new()
		root.position = Vector3(x0 + i * spacing, 0, 0)
		add_child(root)
		for c: Dictionary in ch:
			var mi := MeshInstance3D.new()
			mi.mesh = c["mesh"]
			mi.position = c["pivot"]
			root.add_child(mi)
			tris += Vxm.mesh_stats(c["mesh"]).y
	print("tris=", tris)
	var cam := Camera3D.new()
	cam.fov = float(_args.get("fov", "35"))
	cam.far = 800.0
	add_child(cam)
	var yaw := deg_to_rad(float(_args.get("yaw", "30")))
	var pitch := deg_to_rad(float(_args.get("pitch", "20")))
	var dist := float(_args.get("dist", "14"))
	var tgt := Vector3(float(_args.get("tx", "0")), float(_args.get("h", "2")), float(_args.get("tz", "0")))
	cam.position = tgt + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.look_at(tgt)
	for i in 8:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(_args.get("out", "res://captures/tmp/shot.png")))
	get_tree().quit()
