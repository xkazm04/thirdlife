extends RefCounted
## The rail cards have identical projected width at 8, 65 and 180 metres.
## Sweep their vertical edges across pixels along the same short camera path.

static func _sweep(tree: SceneTree, camera: Camera3D) -> Array[Image]:
	camera.rotation = Vector3.ZERO
	for i in 5:
		await RenderingServer.frame_post_draw
	var strips: Array[Image] = []
	for i in 17:
		camera.rotation.y = deg_to_rad(0.017*i)
		await RenderingServer.frame_post_draw
		strips.append(tree.root.get_texture().get_image().get_region(Rect2i(0,537,1920,6)))
	return strips


static func measure(tree: SceneTree, world: WorldEnvironment, camera: Camera3D) -> bool:
	var style := preload("res://style/cel/style_cel.gd")
	var strength := float(TLStyle.data.env.distant_aa)
	style.configure_distant_aa(world,0.0)
	var plain := await _sweep(tree,camera)
	style.configure_distant_aa(world,strength)
	var effect := world.compositor
	style.configure_distant_aa(world,strength)
	if effect == null or world.compositor != effect or effect.compositor_effects.size() != 1:
		return false
	var resolved := await _sweep(tree,camera)
	for i in 3:
		await RenderingServer.frame_post_draw
	var rest := tree.root.get_texture().get_image().get_region(Rect2i(0,537,1920,6))
	var near_delta := 0
	var rest_delta := 0
	var energies := Vector2.ZERO
	for i in range(1,plain.size()):
		for y in 6:
			for x in range(365,445):
				near_delta = maxi(near_delta,absi(plain[i].get_pixel(x,y).r8-resolved[i].get_pixel(x,y).r8))
			for centre: int in [960,1520]:
				for x in range(centre-35,centre+45):
					var base := plain[i].get_pixel(x,y).r8-plain[i-1].get_pixel(x,y).r8
					var filtered := resolved[i].get_pixel(x,y).r8-resolved[i-1].get_pixel(x,y).r8
					energies += Vector2(base*base,filtered*filtered)
	var last: Image = plain.back()
	for y in rest.get_height():
		for x in rest.get_width():
			rest_delta = maxi(rest_delta,absi(rest.get_pixel(x,y).r8-last.get_pixel(x,y).r8))
	print("CEL_MOTION near_delta=",near_delta," rest_delta=",rest_delta," distant_step_rms=",sqrt(energies.x/15360.0)," -> ",sqrt(energies.y/15360.0))
	return near_delta <= 1 and rest_delta <= 1 and energies.x > 0.0 and energies.y < 0.95*energies.x
