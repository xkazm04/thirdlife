extends SceneTree
## Diorama night (20 Nov), the frame pillar's cases (selftest block 570). One run prints one line per case:
##   FRAME keys ok|fail <detail>     the diorama file loads clean, names shader files that exist and has no unknown lens
##                                   key; the classic file has none of the frame keys (an absent key is the classic behaviour)
##   FRAME lens ok|fail <detail>     the lens rule of tl_style_frame.gd on seven cameras (headless: the node is driven by hand)
## and, in a window only (the style rig is not built headless):
##   FRAME rig ok|fail <detail>      classic installs the classic shaders, no lens, a sun without size; the diorama
##                                   installs its own; classic again puts every one back
##   FRAME seam ok|fail <detail>     the sky looked at across azimuth pi: the classic sky is cut there (a column of
##                                   jumps far above its neighbours), the diorama sky is not
## Counts physics frames, never a clock.

const FRAME: GDScript = preload("res://style/frame/tl_style_frame.gd")
const KEYS: Array = [["sky", "shader"], ["ink", "shader"], ["grade", "shader"], ["sun", "angular"], ["sun", "soft_quality"], ["env", "lens"]]
const CLASSIC: String = "res://style/style.json"
const DIORAMA: String = "res://style/style_diorama.json"


func _initialize() -> void:
	_run()


func _run() -> void:
	_keys()
	await _lens()
	if DisplayServer.get_name() != "headless":
		await _rig()
		await _seam()
	quit(0)


func _say(name: String, why: String, note: String) -> void:
	print("FRAME %s %s %s" % [name, "ok" if why.is_empty() else "fail", why if not why.is_empty() else note])


func _keys() -> void:
	var why: PackedStringArray = PackedStringArray()
	var classic: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLASSIC))
	for k: Array in KEYS:
		if (classic.get(k[0], {}) as Dictionary).has(k[1]):
			why.append("style.json has %s.%s" % k)
	var dio: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIORAMA))
	var notes: PackedStringArray = TLStyle.check(dio.duplicate(true))
	if notes.size() > 0:
		why.append("style_diorama.json: " + notes[0])
	var named: int = 0
	for sec: String in ["sky", "ink", "grade"]:
		var n: String = String((dio.get(sec, {}) as Dictionary).get("shader", ""))
		if n.is_empty():
			continue
		named += 1
		if not FileAccess.file_exists("res://style/shaders/%s.gdshader" % n):
			why.append("%s.shader names %s, which is not a file" % [sec, n])
	var lens_keys: int = 0
	for k: String in ((dio.get("env", {}) as Dictionary).get("lens", {}) as Dictionary):
		lens_keys += 1
		if not (FRAME.get("LENS_KEYS") as PackedStringArray).has(k):
			why.append("env.lens.%s is not a lens key" % k)
	# the palette is not this pillar's, but a frame change must never move it: the classic keys first, in the classic order
	var ck: Array = (classic["palette"] as Dictionary).keys()
	var dk: Array = (dio["palette"] as Dictionary).keys()
	if dk.slice(0, ck.size()) != ck:
		why.append("the diorama palette does not start with the classic keys in the classic order")
	_say("keys", "; ".join(why), "classic has 0 of %d frame keys; diorama names %d shader files, all there; 0 messages; %d lens keys, all known; palette order kept (%d keys)" % [KEYS.size(), named, lens_keys, ck.size()])


class Subject extends Node3D:
	var flying: bool = false


class Cam extends Camera3D:
	var target: Node3D
	var look_height: float = 1.0


class Views extends Node3D:
	func add_view() -> void:
		pass


func _ticks(n: int) -> void:
	for i: int in n:
		await physics_frame


func _lens() -> void:
	var why: PackedStringArray = PackedStringArray()
	var host: Node3D = Node3D.new()
	root.add_child(host)
	var lens: Node = FRAME.new()
	lens.set("cfg", {"amount": 0.05, "tilt": 8.0, "ease": 0.5, "still": 1.0})
	host.add_child(lens)
	var who: Subject = Subject.new()
	host.add_child(who)
	# 1. a camera that follows a subject 8 m away: the lens is on it, focused there
	var chase: Cam = Cam.new()
	chase.target = who
	chase.look_height = 0.0
	host.add_child(chase)
	chase.position = Vector3(0, 0, 8)
	chase.make_current()
	await _ticks(30)
	var g1: float = lens.get("gain")
	var f1: float = lens.get("focus")
	if lens.get("mode") != "subject" or g1 < 0.98 or absf(f1 - 8.0) > 0.1 or not (lens.get("attrs") as CameraAttributesPractical).dof_blur_near_enabled:
		why.append("a camera with a subject at 8 m: mode %s gain %.2f focus %.2f" % [lens.get("mode"), g1, f1])
	# 2. the camera says 0 (the visitor's camera in flight): off
	chase.set_meta(&"tl_lens", 0.0)
	await _ticks(30)
	var g2: float = lens.get("gain")
	if g2 > 0.01 or (lens.get("attrs") as CameraAttributesPractical).dof_blur_far_enabled:
		why.append("tl_lens = 0: gain %.3f" % g2)
	chase.set_meta(&"tl_lens", 1.0)
	# 3. the subject at 30 m/s (a car, a flight): off; at rest again: on
	for i: int in 60:
		who.position.x += 0.5
		chase.position.x += 0.5
		await physics_frame
	var g3: float = lens.get("gain")
	await _ticks(60)
	var g3b: float = lens.get("gain")
	if g3 > 0.01 or g3b < 0.98:
		why.append("a subject at 30 m/s: gain %.3f, at rest again %.3f" % [g3, g3b])
	# 4. the camera 40 m from its subject (an overview): off
	chase.position = who.position + Vector3(0, 0, 40)
	await _ticks(30)
	var g4: float = lens.get("gain")
	if g4 > 0.01:
		why.append("a subject 40 m away: gain %.3f" % g4)
	# 5. a fixed view of a game, looking straight down: neither depth of field nor the band
	var views: Views = Views.new()
	host.add_child(views)
	var arena: Camera3D = Camera3D.new()
	views.add_child(arena)
	arena.rotation_degrees.x = -80.0
	arena.make_current()
	await _ticks(10)
	var g5: float = lens.get("gain")
	var t5: float = lens.get("tilt")
	if lens.get("mode") != "game_view" or g5 > 0.001 or t5 > 0.001:
		why.append("a game's fixed view: mode %s gain %.3f tilt %.3f" % [lens.get("mode"), g5, t5])
	# 6. a presentation camera: the band when it looks down on the land, none when it looks level
	var crane: Camera3D = Camera3D.new()
	host.add_child(crane)
	crane.rotation_degrees.x = -60.0
	crane.make_current()
	await _ticks(20)
	var t6: float = lens.get("tilt")
	var g6: float = lens.get("gain")
	crane.rotation_degrees.x = -8.0
	await _ticks(20)
	var t6b: float = lens.get("tilt")
	var g6b: float = lens.get("gain")
	if lens.get("mode") != "presentation" or absf(t6 - 8.0) > 0.05 or g6 > 0.01 or t6b > 0.01 or g6b < 0.98:
		why.append("a crane: mode %s; looking down 60 deg band %.2f gain %.2f; looking down 8 deg band %.2f gain %.2f" % [lens.get("mode"), t6, g6, t6b, g6b])
	# 7. any camera can name its subject (the meta `tl_lens_subject`): it is then focused like a following camera
	crane.set_meta(&"tl_lens_subject", who)
	crane.position = who.position + Vector3(0, 0, 5)
	await _ticks(20)
	var f7: float = lens.get("focus")
	if lens.get("mode") != "subject" or absf(f7 - 5.1) > 0.2:
		why.append("a camera that names its subject: mode %s focus %.2f" % [lens.get("mode"), f7])
	_say("lens", "; ".join(why), "subject at 8 m: gain %.2f focus %.1f m; camera says 0: %.2f; subject at 30 m/s: %.2f; 40 m away: %.2f; game view: 0 and band 0; crane looking down 60 deg: band %.1f px, depth %.2f; at 8 deg: band %.1f, still depth %.2f; named subject at 5 m: focus %.1f" % [g1, f1, g2, g3, g4, t6, g6, t6b, g6b, f7])
	host.queue_free()
	await process_frame


func _shader_of(host: Node, path: String, override: bool) -> String:
	var n: Node = host.get_node_or_null(path)
	if n == null:
		return "-"
	var m: ShaderMaterial = ((n as MeshInstance3D).material_override if override else (n as CanvasItem).material) as ShaderMaterial
	return m.shader.resource_path.get_file().get_basename()


func _state(host: Node) -> String:
	var we: WorldEnvironment = host.get_node("TLStyleRig/WorldEnvironment")
	var sun: DirectionalLight3D = host.get_node("TLStyleRig/Sun")
	var lens: Node = host.get_node_or_null("TLStyleRig/Lens")
	return "%s %s %s lens=%s sun=%.1f attrs=%s" % [(we.environment.sky.sky_material as ShaderMaterial).shader.resource_path.get_file().get_basename(),
		_shader_of(host, "TLStyleRig/InkPost", true), _shader_of(host, "TLStyleRig/Grade/Rect", false),
		"yes" if lens != null and not lens.is_queued_for_deletion() else "no", sun.light_angular_distance, "yes" if we.camera_attributes != null else "no"]


func _rig() -> void:
	var why: PackedStringArray = PackedStringArray()
	var host: Node3D = Node3D.new()
	root.add_child(host)
	TLStyle.load_style(CLASSIC)
	TLStyle.install(host)
	var a: String = _state(host)
	TLStyle.load_style(DIORAMA)
	TLStyle.install(host)
	var b: String = _state(host)
	TLStyle.load_style(CLASSIC)
	TLStyle.install(host)
	await process_frame
	var c: String = _state(host)
	if a != "sky ink_post grade lens=no sun=0.0 attrs=no":
		why.append("classic installs '%s'" % a)
	if c != a:
		why.append("classic after the diorama installs '%s'" % c)
	var dio: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIORAMA))
	var want: String = "%s %s %s lens=%s" % [String(dio["sky"].get("shader", "sky")), String(dio["ink"].get("shader", "ink_post")), String(dio["grade"].get("shader", "grade")), "yes" if dio["env"].has("lens") else "no"]
	if not b.begins_with(want):
		why.append("the diorama installs '%s', its file asks for '%s'" % [b, want])
	_say("rig", "; ".join(why), "classic: %s | diorama: %s | classic again: as before" % [a, b])
	host.queue_free()
	await process_frame


## The jump across the middle column pairs against the 90th percentile of every column pair's jump, summed over rows.
## A cloud's own edge is not a cut: it never runs down one pixel column of the whole picture.
func _seam_ratio(img: Image) -> float:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var sums: PackedFloat32Array = PackedFloat32Array()
	sums.resize(w - 1)
	for y: int in range(0, h, 2):
		var prev: float = img.get_pixel(0, y).get_luminance()
		for x: int in range(1, w):
			var l: float = img.get_pixel(x, y).get_luminance()
			sums[x - 1] += absf(l - prev)
			prev = l
	var mid: float = maxf(sums[w / 2 - 1], maxf(sums[w / 2 - 2], sums[w / 2]))
	var sorted: Array = Array(sums)
	sorted.sort()
	return mid / maxf(float(sorted[sorted.size() * 9 / 10]), 0.0001)


func _seam() -> void:
	var why: PackedStringArray = PackedStringArray()
	var ratios: Dictionary = {}
	for path: String in [CLASSIC, DIORAMA]:
		var host: Node3D = Node3D.new()
		root.add_child(host)
		TLStyle.load_style(path)
		TLStyle.install(host, {"ink": false, "grade": false})
		var cam: Camera3D = Camera3D.new()
		host.add_child(cam)
		cam.fov = 70.0
		var worst: float = 0.0
		for pitch: float in [14.0, 30.0, 46.0]:
			cam.look_at_from_position(Vector3.ZERO, Vector3(-cos(deg_to_rad(pitch)), sin(deg_to_rad(pitch)), 0.0), Vector3.UP)   # azimuth pi
			cam.make_current()
			for i: int in 6:
				await process_frame
			await RenderingServer.frame_post_draw
			worst = maxf(worst, _seam_ratio(root.get_texture().get_image()))
		ratios[path] = worst
		host.queue_free()
		await process_frame
	var rc: float = ratios[CLASSIC]
	var rd: float = ratios[DIORAMA]
	if rd > 1.5:
		why.append("the diorama sky has a cut at azimuth pi: the middle column jumps %.1f x the 90th percentile" % rd)
	if rc < 3.0:
		why.append("the control did not show: the classic sky's cut measures only %.1f x (expected > 3)" % rc)
	_say("seam", "; ".join(why), "middle column against the 90th percentile of the others: classic %.1f x (the cut), diorama %.2f x" % [rc, rd])
	TLStyle.load_style(TLStyle._chosen_path())
