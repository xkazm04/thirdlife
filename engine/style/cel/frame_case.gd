extends SceneTree
## Read the installed sky at the longitude join and the actual jacket shader
## at six known surface angles. Both checks include the display grade.
var failures := PackedStringArray()

class OverheadCamera extends Camera3D:
	func _miniature_tabletop() -> bool:
		return true


func _initialize() -> void:
	_run.call_deferred()


func _photo() -> Image:
	for i in 6:
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _difference(a: Color,b: Color) -> int:
	return maxi(absi(a.r8-b.r8),maxi(absi(a.g8-b.g8),absi(a.b8-b.b8)))


func _seam(im: Image,x: int) -> int:
	var steps := PackedInt32Array()
	for y in im.get_height():
		steps.append(_difference(im.get_pixel(x-1,y),im.get_pixel(x,y)))
	steps.sort()
	return steps[floori(.99*steps.size())]


func _check_sky(env: Environment, cam: Camera3D) -> void:
	# Native visitor-road aim and field of view, before adding the world geometry.
	cam.look_at(Vector3(-.975721,-.218146,.019514))
	cam.fov = 58.0
	var road := await _photo()
	var disc := Rect2i()
	var pale := 0
	for y in range(0,road.get_height()/3,2):
		for x in range(0,road.get_width()/4,2):
			var c := road.get_pixel(x,y)
			if mini(c.r8,mini(c.g8,c.b8)) > 235:
				var p := Vector2i(x,y)
				disc = Rect2i(p,Vector2i.ONE) if pale == 0 else disc.expand(p)
				pale += 1
	if pale < 100 or disc.position.x < 3 or disc.position.y < 3 or disc.end.x > road.get_width()/5:
		failures.append("road sun disc")
	print("CEL_SUN road_pale_samples=",pale," bounds=",disc)
	cam.look_at(Vector3(-1,.22,0))
	cam.fov = 45.0
	var painted := await _photo()
	var material := env.sky.sky_material as ShaderMaterial
	material.set_shader_parameter("cloud_scale",0.0)
	var clear := await _photo()
	var middle := painted.get_width()/2
	var seam := _seam(painted,middle)
	var neighbour := maxi(_seam(painted,middle-8),_seam(painted,middle+8))
	var cream := 0
	var lavender := 0
	var interior := 0
	for y in range(2,painted.get_height()-2,3):
		for x in range(2,painted.get_width()-2,3):
			var c := painted.get_pixel(x,y)
			if _difference(c,clear.get_pixel(x,y)) < 14:
				continue
			interior += 1
			if c.r8 > 235 and c.g8 > 192 and c.r8-c.b8 > 80:
				cream += 1
			elif c.r8 > 185 and c.r8-c.g8 > 40 and c.b8-c.g8 > 19:
				lavender += 1
	if seam > maxi(10,neighbour+4) or cream < 300 or lavender < 150 or cream+lavender < interior*.925:
		failures.append("sky coverage or join")
	print("CEL_SKY west_p99=",seam," neighbour=",neighbour," cream=",cream," lavender=",lavender," changed=",interior)


func _check_bands(host: Node3D, env: Environment, sun: DirectionalLight3D, cam: Camera3D) -> void:
	env.fog_enabled = false
	sun.shadow_enabled = false
	cam.look_at_from_position(Vector3(0,0,5),Vector3.ZERO)
	cam.fov = 45
	cam.reset_physics_interpolation()
	var key := sun.global_basis.z.normalized()
	var side := key.cross(Vector3.UP).normalized()
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var pigment := PackedColorArray()
	var finish := PackedVector2Array()
	var bind := PackedFloat32Array()
	var centres := PackedVector3Array()
	for i in 6:
		var centre := Vector3((i-2.5)*.9,0,0)
		var ndl: float = [-.70,-.30,.15,.35,.70,.95][i]
		var normal := key*ndl + side*sqrt(1.0-ndl*ndl)
		centres.append(centre)
		for offset: Vector2 in [Vector2(-1,1),Vector2(1,1),Vector2(1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
			vertices.append(centre+Vector3(offset.x*.40,offset.y*.65,0))
			normals.append(normal)
			pigment.append(Color.WHITE)
			finish.append(Vector2(0,6)) # the coat
			bind.append_array(PackedFloat32Array([0,1.1,0,TLStyle.index("jacket")]))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = pigment
	arrays[Mesh.ARRAY_TEX_UV] = finish
	arrays[Mesh.ARRAY_CUSTOM0] = bind
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var material := ShaderMaterial.new()
	material.shader = preload("res://style/shaders/body_cel.gdshader")
	material.set_shader_parameter("pal_lut",TLStyle.material("white").get_shader_parameter("pal_lut"))
	var card := MeshInstance3D.new()
	card.mesh = mesh
	card.material_override = material
	host.add_child(card)
	var picture := await _photo()
	var evidence := OS.get_environment("TL_CEL_EVIDENCE")
	if not evidence.is_empty():
		picture.save_png(evidence.path_join("jacket-bands.png"))
	var inks: Array[Color] = []
	for centre in centres:
		var pixel := cam.unproject_position(centre)
		var colour := picture.get_pixelv(Vector2i(pixel))
		inks.append(colour)
		if colour.r8 < 3*maxi(colour.g8,colour.b8):
			failures.append("lost jacket red")
	for i in [0,2,4]:
		if _difference(inks[i],inks[i+1]) > 4:
			failures.append("unsteady band")
	if inks[2].r8-inks[0].r8 < 12 or inks[4].r8-inks[2].r8 < 12:
		failures.append("missing band")
	print("CEL_BANDS ",inks.map(func(c: Color) -> String: return c.to_html(false)))


func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	TLStyle.install(host,{"ink":false})
	var world := host.get_node("TLStyleRig/WorldEnvironment") as WorldEnvironment
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.make_current()
	var sun := host.get_node("TLStyleRig/Sun") as DirectionalLight3D
	var overhead := OverheadCamera.new()
	host.add_child(overhead)
	overhead.make_current()
	await _photo()
	var plan_pitch := sun.rotation_degrees.x
	cam.make_current()
	await _photo()
	var road_pitch := sun.rotation_degrees.x
	if not is_equal_approx(plan_pitch,-39.0) or not is_equal_approx(road_pitch,-22.5):
		failures.append("overhead light or road restoration")
	print("CEL_LIGHT road=",road_pitch," overhead=",plan_pitch)
	overhead.free()
	if world.camera_attributes != null or not is_equal_approx(root.scaling_3d_scale,1.0):
		failures.append("native deep focus")
	await _check_sky(world.environment,cam)
	await _check_bands(host,world.environment,sun,cam)
	host.free()
	if not await preload("res://style/cel/contour_case.gd").measure(self):
		failures.append("1080p rail taper or open gap")
	print("CEL_FRAME ok=",failures.is_empty()," errors=",failures)
	quit(0 if failures.is_empty() else 1)
