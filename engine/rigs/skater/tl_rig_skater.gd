class_name TLRigSkater
extends Node3D
## thirdjam's skater in our engine (hockey campaign, lane K2, round 1): the shipped figure SK_SkaterTB1_P3, its 24-bone
## skeleton and its 202 clips, exported from the Unreal project (engine/tools/skater/export_skater.py) and baked by
## engine/tools/skater/build_skater.gd into skater_body.scn and skater_clips.res beside this file.
## The stick is part of the mesh (skinned to the bone `stick_socket`), 1.637 m tall at rest, 12,040 triangles.
##
## VISUAL ONLY, and frame-driven: nothing here reads a clock. `tick()` advances the playing clip by exactly one
## physics frame (1/60 s); the clips are keyed at 60 a second, so at rate 1 a tick is one key.
## The figure faces -Z (the engine's rig convention); the export faces +X, so the body sits under a quarter turn.
##
## Round 1 gives the body and plain clip playback (`play_clip`, `pose_at`, `tick`) and the sockets. The driver that
## mirrors thirdjam's IJamSkaterVisual call for call is round 2.

const DT: float = 1.0 / 60.0
## Rest height, metres: the highest vertex of the export (skater_clips.json is built with it; thirdjam ASSETS.md).
const HEIGHT_M: float = 1.637
const BODY_PATH: String = "res://rigs/skater/skater_body.scn"
const CLIPS_PATH: String = "res://rigs/skater/skater_clips.res"

## thirdjam's team colours, blue and orange: game.teams[].colour_hex of the cartridge PLAY NOW plays
## (Game/Content/Cartridges/hockey.regular.cartridge.json:155 and :196). The game passes them in through SetTeam.
const TEAM_COLOURS: Array = [Color("1d4ed8"), Color("e8651a")]
## The seven slots that are not the team's: the base colour of thirdjam's own material instance of the slot
## (MaterialInstanceConstant vector parameter `TeamColour`, linear RGB, read by export_skater.py into meta.json).
const SLOT_LINEAR: Dictionary = {
	"Pads": Color(0.022, 0.026, 0.06),     # MI_SkaterTB1_P3_PadsFelt
	"Trim": Color(0.8, 0.7, 0.5),          # MI_SkaterTB1_P3_TrimDeco
	"Skin": Color(0.75, 0.5, 0.38),        # MI_SkaterTB1_Skin
	"Gloves": Color(0.02, 0.02, 0.025),    # MI_SkaterTB1_P3_Gloves
	"Skate": Color(0.03, 0.03, 0.035),     # MI_SkaterTB1_P3_Skate
	"Blade": Color(0.6, 0.65, 0.72),       # MI_SkaterTB1_Blade
	"Stick": Color(0.3, 0.15, 0.05),       # MI_SkaterTB1_Stick
}
## The helmet is the team colour x 0.75 in linear light: thirdjam's shipped driver, BP_SkaterVisual_TB1_P3 SetTeam,
## `SetVectorParameterValue(HelmetMID, TeamColour, Colour * 0.75)` (node K2Node_CallFunction_1259 of HEAD's graph; the
## 0.5 of status/B4-report.md was the older TB1 figure's).
const HELMET_K: float = 0.75
## thirdjam's mesh socket `puck_socket`: on the bone stick_socket at (19.42, -141.45, 4.8) cm in Unreal's axes
## (meta.json, sockets); the exporter's axis change (x, y, z) cm -> (x, z, y) m gives the offset in the bone's space here.
const PUCK_ON_STICK: Vector3 = Vector3(0.1942, 0.048, -1.4145)

static var _body_scene: PackedScene
static var _lib: AnimationLibrary
static var _plans: Dictionary = {}     # clip name -> [[track, bone index, track type], ...]

var family: StringName = &"skater"
var team: int = 0
var clip: StringName = &""
var clip_k: float = 0.0               # keys into the clip (a key is 1/60 s): whole numbers at rate 1, so a loop wraps exactly
var clip_rate: float = 1.0
var clip_loop: bool = true
var _body: Node3D
var _sk: Skeleton3D
var _mesh: MeshInstance3D
var _anim: Animation
var _posed: bool = false


static func clip_library() -> AnimationLibrary:
	if _lib == null:
		_lib = load(CLIPS_PATH) as AnimationLibrary
	return _lib


static func clip_names() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for n: StringName in clip_library().get_animation_list():
		out.append(String(n))
	out.sort()
	return out


## Keys in a clip (60 a second): a clip of N keys lasts N - 1 frames.
static func clip_keys(cname: StringName) -> int:
	var a: Animation = clip_library().get_animation(cname)
	return 0 if a == null else roundi(a.length * 60.0) + 1


## Builds the figure. params: {"team": 0 | 1, "colour": Color (overrides the team's)}.
func setup(p: Dictionary = {}) -> void:
	if _body_scene == null:
		_body_scene = load(BODY_PATH) as PackedScene
	_body = _body_scene.instantiate() as Node3D
	_body.rotation.y = PI * 0.5       # the export faces +X with its right hand on +Z: a quarter turn puts forward on -Z, right on +X
	add_child(_body)
	_sk = _body.get_node("Skeleton3D") as Skeleton3D
	_mesh = _sk.get_node("Mesh") as MeshInstance3D
	# a rig's shading travels with it (RIGS.md, "A rig's shading travels with it"; TLRigs._mark_body): mottle and hatching
	# anchored to the body, no shadow of the figure on itself. The second number is 0.6 x the scale of a 2.0 m biped.
	_mesh.set_instance_shader_parameter(&"tl_body", Vector2(1.0, 0.6 * HEIGHT_M / 2.0))
	team = int(p.get("team", 0))
	set_team_colour(p.get("colour", TEAM_COLOURS[clampi(team, 0, 1)]) as Color)


## The jersey in `colour` (sRGB), the helmet in the same x HELMET_K (in linear light, as thirdjam multiplies).
func set_team_colour(colour: Color) -> void:
	var lin: Color = colour.srgb_to_linear()
	var helmet: Color = Color(lin.r * HELMET_K, lin.g * HELMET_K, lin.b * HELMET_K).linear_to_srgb()
	var mesh: Mesh = _mesh.mesh
	for s: int in range(mesh.get_surface_count()):
		var slot: String = mesh.surface_get_name(s)
		var c: Color
		match slot:
			"Jersey": c = colour
			"Helmet": c = helmet
			_: c = (SLOT_LINEAR.get(slot, Color(0.5, 0.5, 0.5)) as Color).linear_to_srgb()
		_mesh.set_surface_override_material(s, TLStyle.flat_material(Color(c.r, c.g, c.b), 0.6 if slot == "Blade" else 0.0))


## Starts a clip from its first key. `loop`: wraps at the clip's length (N - 1 frames), else holds the last key.
func play_clip(cname: StringName, loop: bool = true, rate: float = 1.0) -> bool:
	var a: Animation = clip_library().get_animation(cname)
	if a == null:
		push_warning("TLRigSkater: no clip '%s'" % cname)
		return false
	clip = cname
	_anim = a
	clip_k = 0.0
	clip_rate = rate
	clip_loop = loop
	_posed = false
	return true


## Advances one physics frame. The first tick after `play_clip` shows key 0; each later tick moves `clip_rate` keys.
## A looping clip of N keys has a period of N - 1 ticks at rate 1: after key N - 2 comes key 0 (the last key is the
## first key's twin and is passed over; thirdjam's Stride joins within 0.42 cm, ASSETS.md row AS_SkaterTB1_P3_Stride).
func tick() -> void:
	if _anim == null:
		return
	var last: float = float(clip_keys(clip) - 1)
	if _posed:
		clip_k += clip_rate
		if clip_loop and last > 0.0:
			clip_k = fposmod(clip_k, last)
		else:
			clip_k = clampf(clip_k, 0.0, last)
	_pose(_anim, clip, minf(clip_k * DT, _anim.length))
	_posed = true


## Poses the figure from a clip at a key (may be fractional), without playing it.
func pose_at(cname: StringName, key: float) -> bool:
	var a: Animation = clip_library().get_animation(cname)
	if a == null:
		return false
	_pose(a, cname, clampf(key * DT, 0.0, a.length))
	return true


## The key the playing clip shows (fractional when the rate is not 1).
func clip_key() -> float:
	return clip_k


func skeleton() -> Skeleton3D:
	return _sk


func mesh_instance() -> MeshInstance3D:
	return _mesh


## A bone's transform in the figure's own space (this node's), chained by hand from the bone poses: a Skeleton3D
## that is not inside the tree keeps its global poses at rest, and a test must not depend on that.
func bone_transform(bone: StringName) -> Transform3D:
	var bi: int = _sk.find_bone(bone)
	if bi < 0:
		return Transform3D.IDENTITY
	var t: Transform3D = _sk.get_bone_pose(bi)
	var p: int = _sk.get_bone_parent(bi)
	while p >= 0:
		t = _sk.get_bone_pose(p) * t
		p = _sk.get_bone_parent(p)
	return _body.transform * t


## thirdjam's three sockets, in the figure's own space: `stick_socket` (the grip, a bone), `puck_socket` (where a
## carried puck is drawn: on the blade, the mesh socket on the stick bone), `head_socket` (above the helmet, a bone).
func socket_transform(sname: StringName) -> Transform3D:
	match String(sname):
		"puck_socket": return bone_transform(&"stick_socket") * Transform3D(Basis.IDENTITY, PUCK_ON_STICK)
		"stick_socket", "head_socket": return bone_transform(sname)
	return Transform3D.IDENTITY


func metrics() -> Dictionary:
	var tris: int = 0
	var mesh: Mesh = _mesh.mesh
	for s: int in range(mesh.get_surface_count()):
		tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return {"height": HEIGHT_M, "bones": _sk.get_bone_count(), "triangles": tris, "clips": clip_library().get_animation_list().size()}


# ------------------------------------------------------------------ posing
static func _plan(cname: StringName, a: Animation, sk: Skeleton3D) -> Array:
	if _plans.has(cname):
		return _plans[cname]
	var plan: Array = []
	for t: int in range(a.get_track_count()):
		var bi: int = sk.find_bone(a.track_get_path(t).get_concatenated_subnames())
		if bi >= 0:
			plan.append([t, bi, a.track_get_type(t)])
	_plans[cname] = plan
	return plan


func _pose(a: Animation, cname: StringName, t: float) -> void:
	# every bone starts from rest, so a bone the clip does not key never keeps what an earlier clip left on it
	_sk.reset_bone_poses()
	for row: Array in _plan(cname, a, _sk):
		if int(row[2]) == Animation.TYPE_ROTATION_3D:
			_sk.set_bone_pose_rotation(int(row[1]), a.rotation_track_interpolate(int(row[0]), t))
		elif int(row[2]) == Animation.TYPE_POSITION_3D:
			_sk.set_bone_pose_position(int(row[1]), a.position_track_interpolate(int(row[0]), t))


## A Skeleton3D posed outside the tree keeps its global poses (and so its drawn skin) at rest until it is posed again
## inside it (see TLRigNode): pose again one deferred call after entering. `bone_transform` and `socket_transform` do
## not depend on that: they chain the bone poses themselves.
func _enter_tree() -> void:
	_repose.call_deferred()


func _repose() -> void:
	if _anim != null and _posed and _sk != null and _sk.is_inside_tree():
		_pose(_anim, clip, minf(clip_k * DT, _anim.length))
