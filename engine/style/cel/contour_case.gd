extends RefCounted
## Hold the projected rail width constant and vary only its distance.

static func _photo(tree: SceneTree) -> Image:
	for frame in 9:
		await RenderingServer.frame_post_draw
	return tree.root.get_texture().get_image()


static func measure(tree: SceneTree) -> bool:
	tree.root.size = Vector2i(1920,1080)
	var host := Node3D.new()
	tree.root.add_child(host)
	TLStyle.install(host,{"grade":false})
	var rig := host.get_node("TLStyleRig")
	var env := (rig.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#f1debd")
	env.fog_enabled = false
	var camera := Camera3D.new()
	camera.fov = 50
	camera.far = 850
	host.add_child(camera)
	camera.make_current()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#d8a854")
	wood.roughness = 1.0
	var distances := PackedFloat32Array([8.0,65.0,180.0])
	for i in distances.size():
		var depth := distances[i]
		var metre_per_px := 2.0*depth*tan(deg_to_rad(camera.fov)*.5)/1080.0
		var centre := 400+560*i
		for offset: float in [-13.0,13.0]:
			var rail := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(16,360)*metre_per_px
			rail.mesh = quad
			rail.material_override = wood
			rail.position = Vector3((centre+offset-960)*metre_per_px,0,-depth)
			host.add_child(rail)
	var ink := rig.get_node("InkPost") as MeshInstance3D
	var lined := await _photo(tree)
	ink.visible = false
	var plain := await _photo(tree)
	ink.visible = true
	var stable := await preload("res://style/cel/distant_aa_case.gd").measure(tree,rig.get_node("WorldEnvironment"),camera)
	host.free()
	if lined.get_size() != Vector2i(1920,1080) or lined.get_size() != plain.get_size():
		return false
	var widths := PackedInt32Array()
	var gap_delta := 0
	for i in distances.size():
		var centre := 400+560*i
		var samples := PackedInt32Array()
		for y in range(440,640,4):
			for offset: int in [-13,13]:
				var changed := 0
				for x in range(centre+offset-8,centre+offset+8):
					if plain.get_pixel(x,y).r8-lined.get_pixel(x,y).r8 > 20:
						changed += 1
				samples.append(changed)
			for x in range(centre-4,centre+4):
				gap_delta = maxi(gap_delta,absi(plain.get_pixel(x,y).r8-lined.get_pixel(x,y).r8))
		samples.sort()
		widths.append(samples[samples.size()/2])
	# Each count includes both edges of a 16-pixel rail. A one-pixel transition
	# may round differently on another GPU; the three depths must still taper.
	print("CEL_CONTOURS both_edges_px=",widths," gap_delta=",gap_delta)
	var expected := Vector3i(6,4,2)
	for i in widths.size():
		if absi(widths[i]-expected[i]) > 1:
			return false
	return widths[0] > widths[1] and widths[1] > widths[2] and gap_delta <= 1 and stable
