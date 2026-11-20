extends RefCounted
## Walker-feel T1 (a test instrument of boot.gd, moved here unchanged by L4 on 21 Nov: boot.gd is held at 600 lines).
## TL_EXE_FRAMES=<abs dir> writes every drawn frame while the physics frame lies in TL_EXE_FRAMES_RANGE=<from>:<to>,
## numbered in the order drawn (<dir>/f<n>.raw: RGB8 bytes, every other pixel of the window, so 960x540 for 1920x1080; a
## raw copy costs a few milliseconds where a PNG costs 200, so the run keeps the wall-clock pace a person meets), and one
## line per picture in <dir>/frames.jsonl (the physics frame, the size, the camera's place and look, the stage). The blink
## detector (kernel/world/walks/blink_detect.py) reads it. TL_EXE_FRAMES_FULL=1: full size. TL_EXE_SKYMASK=1: sky magenta.
## No class_name; `b` is the boot node (its `_frame`, `view`, `world`).

var b: Node = null
var _frames_dir: String = ""
var _frames_range: Vector2i = Vector2i(1, 1200)
var _frames_log: FileAccess = null
var _frames_n: int = 0


func start(boot: Node, dir: String) -> void:
	b = boot
	_frames_dir = dir
	var fr: PackedStringArray = OS.get_environment("TL_EXE_FRAMES_RANGE").split(":")
	if fr.size() == 2 and fr[0].is_valid_int() and fr[1].is_valid_int():
		_frames_range = Vector2i(int(fr[0]), int(fr[1]))
	DirAccess.make_dir_recursive_absolute(_frames_dir)
	_frames_log = FileAccess.open(_frames_dir + "/frames.jsonl", FileAccess.WRITE)
	RenderingServer.frame_post_draw.connect(_frame_drawn)
	if OS.get_environment("TL_EXE_SKYMASK") == "1":
		_sky_mask()


func flush() -> void:
	if _frames_log != null:
		_frames_log.flush()


## TL_EXE_SKYMASK=1 (with TL_EXE_FRAMES): every pixel where nothing was drawn (the depth buffer still holds the far
## plane: sky) is painted pure magenta, so the detector reads "nothing drawn here" exactly instead of guessing sky by
## its colour. An instrument only: the picture is otherwise the same.
func _sky_mask() -> void:
	var sh: Shader = Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, skip_vertex_transform, cull_disabled, fog_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
void fragment() {
	if (texture(depth_tex, SCREEN_UV).r > 0.0) { discard; }
	ALBEDO = vec3(1.0, 0.0, 1.0);
}
"""
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = sh
	mat.render_priority = 127
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "SkyMask"
	mi.mesh = q
	mi.material_override = mat
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add_child(mi)


func _frame_drawn() -> void:
	var view: Node = b.get("view")
	var world: Node = b.get("world")
	var frame: int = int(b.get("_frame"))
	if frame < _frames_range.x or frame > _frames_range.y or view == null or not is_instance_valid(view):
		return
	var img: Image = b.get_viewport().get_texture().get_image()
	if img == null:
		return
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	if OS.get_environment("TL_EXE_FRAMES_FULL") != "1":            # T3: full size, for the antialiasing study
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_NEAREST)
	var f: FileAccess = FileAccess.open("%s/f%05d.raw" % [_frames_dir, _frames_n], FileAccess.WRITE)
	if f != null:
		f.store_buffer(img.get_data())
		f.close()
	var cam: Camera3D = b.get_viewport().get_camera_3d()
	var line: Dictionary = {"n": _frames_n, "frame": frame, "size": [img.get_width(), img.get_height()], "stage": int(view.get("stage")),
		"usec": Time.get_ticks_usec()}
	_frames_n += 1
	if cam != null:
		var o: Vector3 = cam.global_position
		var fw: Vector3 = -cam.global_basis.z
		line["cam"] = [snappedf(o.x, 0.01), snappedf(o.y, 0.01), snappedf(o.z, 0.01)]
		line["look"] = [snappedf(fw.x, 0.001), snappedf(fw.y, 0.001), snappedf(fw.z, 0.001)]
		line["fov"] = snappedf(cam.fov, 0.01)
	if world != null and is_instance_valid(world):
		var pos: Vector3 = world.get("player_pos")
		line["player"] = [snappedf(pos.x, 0.01), snappedf(pos.z, 0.01)]
	_frames_log.store_line(JSON.stringify(line, "", false))
	if _frames_n % 60 == 0:
		_frames_log.flush()
