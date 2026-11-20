extends Node
## The frame of a style beyond the classic rig (night of 20 Nov, the diorama): which sky, post and grade shader a style
## uses, the sun's penumbra, and the lens (a tilt-shift depth of field that follows the camera in use).
## Reached only through `TLStyle.install`; no class_name, nothing here is public API (it lives in style/frame/, outside
## the folders `tl arch` reads the public surface from). Everything is keyed in the style
## file and an ABSENT key means the classic behaviour, so style.json renders as it always did:
##   sky.shader / ink.shader / grade.shader   the shader file of that layer (default "sky", "ink_post", "grade")
##   sun.angular       degrees: the sun's apparent size. > 0: shadows are tight where a thing stands and soften with
##                     distance from it (the engine's penumbra search); 0 or absent: one blur everywhere, as before
##   sun.soft_quality  0..5, the engine's soft shadow filter quality while this style is installed (absent: the project's)
##   env.lens          an object, see LENS below; absent: no lens node at all
##
## THE LENS. One node (`Lens`, under the style rig) looks every physics frame at the camera its viewport draws with and
## decides how much blur that view may have. The rule, in this order:
##   1. A camera that follows a subject (it has a `target`: TLChaseCam, TLOrbitCam, the visitor's camera; any other
##      camera can name one with the meta `tl_lens_subject`, a Node3D) focuses ON the subject. Things nearer than the
##      subject blur towards the lens, things far behind it blur a little: the miniature look, with the player always
##      sharp. The blur is scaled down
##        - by the camera's own say: the meta `tl_lens` (0..1) on the camera; the visitor's camera sets it to 0 in flight
##        - by the subject's speed: full to `speed_full` m/s, none from `speed_none` (a car at speed, a flight)
##        - by the camera's distance to the subject: full to `reach_full` metres, none from `reach_none` (an overview)
##   2. A fixed view of a game (TLCameras.add_view: the hockey arena, a course overview) has no subject and is never
##      blurred: the whole playing field stays readable.
##   3. Any other camera without a subject (the world's crane, a review or lab scene: a presentation, not play):
##        - looking DOWN on the land (from `tilt_from` degrees, full at `tilt_full`) it gets the photographer's band:
##          sharp in a level band, blurring towards the top and bottom edge (`tilt`, drawn by the grade shader, no
##          depth involved). Seen from above the land is a table top.
##        - looking level it gets a still photographer's depth of field at fixed distances (`still` x amount): only
##          what is within a few metres of the lens and the far backdrop soften. A close-up of a figure stays sharp
##          from hair to boots, and so does everything a person would look at in the picture.
##      The meta `tl_lens` scales both (0 = off).
## Changes are eased over a few frames (`ease`), counted in physics frames; a cut to another camera is not eased.
## Presentation only: the node reads the camera and the subject's place, and writes camera attributes and one grade
## uniform. It never runs headless (the style rig is not built there).
##
## LENS keys (env.lens), all optional:
##   amount 0.08       the engine's blur amount at full strength (0 = no depth of field)
##   near 0.22, near_soft 0.5    full blur nearer than near x focus distance; none from (near + near_soft) x focus
##   far 2.0, far_add 20.0, far_soft 260.0   none nearer than far x focus distance + far_add metres (what the player
##                     runs towards next stays sharp); full `far_soft` metres beyond that
##   speed_full 9.0, speed_none 15.0, reach_full 14.0, reach_none 26.0, ease 0.12
##   tilt 0.0          px of blur (at 1080) at the frame's top and bottom for a presentation camera (0 = none)
##   tilt_y 0.52, tilt_band 0.16, tilt_soft 0.34   the sharp band (grade_diorama.gdshader)
##   tilt_from 25.0, tilt_full 50.0   degrees a presentation camera looks down: no band flatter than the first
##   still 0.0         share of `amount` for a level presentation camera (0 = none); still_near 2.0, still_near_soft 5.0,
##                     still_far 70.0 (metres): full near blur to still_near, none from still_near + still_near_soft;
##                     far blur none to still_far, full `far_soft` metres beyond

const NODE: String = "Lens"
const QUALITY_SETTING: String = "rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"
const LENS_KEYS: PackedStringArray = ["amount", "near", "near_soft", "far", "far_add", "far_soft", "speed_full", "speed_none", "reach_full",
	"reach_none", "ease", "tilt", "tilt_y", "tilt_band", "tilt_soft", "tilt_from", "tilt_full", "still", "still_near", "still_near_soft", "still_far"]

var cfg: Dictionary = {}
var grade: ShaderMaterial
var attrs: CameraAttributesPractical = CameraAttributesPractical.new()
var gain: float = 0.0            ## read only: the share of the depth of field in use this frame (0..1)
var focus: float = 8.0           ## read only: metres to the subject in focus
var tilt: float = 0.0            ## read only: the band blur in use this frame (px at 1080)
var span: Vector4 = Vector4(2.0, 4.0, 40.0, 260.0)   ## read only, metres: near blur full to x, none from x + y; far blur none to z, full at z + w
var mode: String = "none"        ## read only: "subject", "game_view", "presentation" or "none"
var _cam_id: int = 0
var _subject_id: int = 0
var _last: Vector3 = Vector3.ZERO
var _speed: float = 0.0
static var _quality_set: bool = false


## Called at the end of TLStyle.install (windowed only), after the classic rig is in place.
static func apply(rig: Node3D, we: WorldEnvironment, sun: DirectionalLight3D, data: Dictionary) -> void:
	var sky_mat: ShaderMaterial = we.environment.sky.sky_material as ShaderMaterial
	sky_mat.shader = TLStyle._shader(_name(data, "sky", "sky"))
	var post: MeshInstance3D = rig.get_node_or_null("InkPost")
	if post != null and not post.is_queued_for_deletion():
		(post.material_override as ShaderMaterial).shader = TLStyle._shader(_name(data, "ink", "ink_post"))
	var grade_mat: ShaderMaterial = null
	var rect: ColorRect = rig.get_node_or_null("Grade/Rect")
	if rect != null and not rect.is_queued_for_deletion():
		grade_mat = rect.material as ShaderMaterial
		grade_mat.shader = TLStyle._shader(_name(data, "grade", "grade"))
	var s: Dictionary = data["sun"]
	sun.light_angular_distance = clampf(float(s.get("angular", 0.0)), 0.0, 6.0)
	if s.has("soft_quality"):
		RenderingServer.directional_soft_shadow_filter_set_quality(clampi(int(s["soft_quality"]), 0, 5) as RenderingServer.ShadowQuality)
		_quality_set = true
	elif _quality_set:      # a style without the key after one with it: the project's own quality again
		RenderingServer.directional_soft_shadow_filter_set_quality(int(ProjectSettings.get_setting(QUALITY_SETTING, 2)) as RenderingServer.ShadowQuality)
		_quality_set = false
	var lens_cfg: Variant = (data["env"] as Dictionary).get("lens", null)
	var lens: Node = rig.get_node_or_null(NODE)
	if lens_cfg is Dictionary:
		for k: String in lens_cfg:      # unknown keys are errors: said aloud, and the case style.frame_keys fails on one
			if not LENS_KEYS.has(k):
				printerr("[tl] style: env.lens.%s is not a lens key (allowed: %s)" % [k, ", ".join(LENS_KEYS)])
	if lens_cfg is Dictionary and (float(lens_cfg.get("amount", 0.08)) > 0.0 or float(lens_cfg.get("tilt", 0.0)) > 0.0):
		if lens == null:
			lens = (load("res://style/frame/tl_style_frame.gd") as GDScript).new()
			lens.name = NODE
			rig.add_child(lens)
		lens.set("cfg", lens_cfg)
		lens.set("grade", grade_mat)
		we.camera_attributes = lens.get("attrs")
		lens.call("_push")
	elif lens != null:
		lens.queue_free()
		if grade_mat != null:
			grade_mat.set_shader_parameter(&"tilt", 0.0)


static func _name(data: Dictionary, section: String, default: String) -> String:
	var n: String = String((data.get(section, {}) as Dictionary).get("shader", default))
	return n if ResourceLoader.exists(TLStyle.SHADER_DIR + n + ".gdshader") else default


func _ready() -> void:
	process_physics_priority = 1000      # after the cameras of this tick


func _num(key: String, default: float) -> float:
	return float(cfg.get(key, default))


func _physics_process(_delta: float) -> void:
	var vp: Viewport = get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp != null else null
	var want_gain: float = 0.0
	var want_tilt: float = 0.0
	var want_focus: float = focus
	var want_span: Vector4 = span
	mode = "none"
	if cam != null:
		var say: float = clampf(float(cam.get_meta(&"tl_lens", 1.0)), 0.0, 1.0)
		var named: Variant = cam.get("target") if "target" in cam else (cam.get_meta(&"tl_lens_subject") if cam.has_meta(&"tl_lens_subject") else null)
		var subject: Node3D = named as Node3D if is_instance_valid(named) else null
		if subject != null and subject.is_inside_tree():
			mode = "subject"
			var at: Vector3 = subject.global_position
			var look_h: Variant = cam.get("look_height")
			want_focus = maxf(cam.global_position.distance_to(at + Vector3.UP * (float(look_h) if look_h != null else 1.0)), 0.5)
			var id: int = subject.get_instance_id()
			if id != _subject_id:
				_subject_id = id
				_speed = 0.0
			else:
				_speed = lerpf(_speed, at.distance_to(_last) * float(Engine.physics_ticks_per_second), 0.2)
			_last = at
			var slow: float = 1.0 - smoothstep(_num("speed_full", 9.0), _num("speed_none", 15.0), _speed)
			var close: float = 1.0 - smoothstep(_num("reach_full", 14.0), _num("reach_none", 26.0), want_focus)
			want_gain = say * slow * close
			want_span = Vector4(want_focus * _num("near", 0.22), want_focus * _num("near_soft", 0.5),
				want_focus * _num("far", 2.0) + _num("far_add", 20.0), _num("far_soft", 260.0))
		elif cam.get_parent() != null and cam.get_parent().has_method(&"add_view"):
			mode = "game_view"
		else:
			mode = "presentation"
			var down: float = rad_to_deg(asin(clampf(cam.global_transform.basis.z.y, -1.0, 1.0)))   # degrees it looks down
			var table: float = smoothstep(_num("tilt_from", 25.0), _num("tilt_full", 50.0), down)
			want_tilt = _num("tilt", 0.0) * say * table
			want_gain = _num("still", 0.0) * say * (1.0 - table)
			want_span = Vector4(_num("still_near", 2.0), _num("still_near_soft", 5.0), _num("still_far", 70.0), _num("far_soft", 260.0))
		var cam_id: int = cam.get_instance_id()
		if cam_id != _cam_id:              # a cut to another camera: no easing across it
			_cam_id = cam_id
			gain = want_gain
			tilt = want_tilt
			focus = want_focus
			span = want_span
	var e: float = clampf(_num("ease", 0.12), 0.01, 1.0)
	gain = lerpf(gain, want_gain, e)
	tilt = lerpf(tilt, want_tilt, e)
	focus = lerpf(focus, want_focus, 0.35)
	span = span.lerp(want_span, 0.35)
	_push()


func _push() -> void:
	var amount: float = clampf(_num("amount", 0.08), 0.0, 0.3) * gain
	var on: bool = amount > 0.002
	attrs.dof_blur_near_enabled = on
	attrs.dof_blur_far_enabled = on
	if on:
		attrs.dof_blur_amount = amount
		attrs.dof_blur_near_distance = maxf(span.x, 0.05)
		attrs.dof_blur_near_transition = maxf(span.y, 0.05)
		attrs.dof_blur_far_distance = span.z
		attrs.dof_blur_far_transition = maxf(span.w, 1.0)
	if grade != null:
		grade.set_shader_parameter(&"tilt", tilt if tilt > 0.05 else 0.0)
		for k: String in ["tilt_y", "tilt_band", "tilt_soft"]:
			if cfg.has(k):
				grade.set_shader_parameter(k, float(cfg[k]))
