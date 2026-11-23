class_name TLRigSkaterBody
extends Node3D
## The body of thirdjam's skater (hockey campaign, lane K2): the shipped figure SK_SkaterTB1_P3 (12,040 triangles, 24
## bones, the stick skinned in, 1.637 m at rest), its 202 clips, the nine slots' materials, thirdjam's sockets, and
## plain clip playback for the review tools (`play_clip`, `pose_at`, `pose_rest`, `tick`). Exported from the Unreal
## project and baked by engine/tools/skater (skater_body.scn, skater_clips.res). The figure the game uses is
## TLRigSkater (tl_rig_skater.gd), which adds thirdjam's driver on top of this.
## VISUAL ONLY and frame-driven: `tick()` is one physics frame (1/60 s; the clips are keyed at 60 a second).
## Faces -Z (the engine's rig convention); the export faces +X, so the body sits under a quarter turn.

const DT: float = 1.0 / 60.0
const HEIGHT_M: float = 1.637
const BODY_PATH: String = "res://rigs/skater/skater_body.scn"
const CLIPS_PATH: String = "res://rigs/skater/skater_clips.res"
const BONE_SPINE_03: int = 4
const BONE_HEAD: int = 6

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
## [SetTeam]: the helmet's TeamColour = Colour x 0.75 (node CallFunction_1259).
const HELMET_K: float = 0.75
## thirdjam's mesh socket `puck_socket`: on the bone stick_socket at (19.42, -141.45, 4.8) cm in Unreal's axes
## (meta.json, sockets); the exporter's axis change (x, y, z) cm -> (x, z, y) m gives the offset in the bone's space here.
const PUCK_ON_STICK: Vector3 = Vector3(0.1942, 0.048, -1.4145)
## [SK3Fix]: the blade's heel in the stick bone's space, Unreal's axes, centimetres (MakeVector(5.13, -140.72, 9.65)).
const HEEL_ON_STICK_UE: Vector3 = Vector3(5.13, -140.72, 9.65)

static var _body_scene: PackedScene
static var _lib: AnimationLibrary
static var _plans: Dictionary = {}     # clip name -> [[track, bone index, track type], ...]
static var _first_keys: Dictionary = {}   # clip name -> its pose at time 0
static var upper_mask: Array = []      # per bone: under spine_01 (the layer mask of LayeredBoneBlend_0 / _1 / _2)

var family: StringName = &"skater"
var team: int = 0
var number: int = 0

# ---- round 1: plain clip playback
var clip: StringName = &""
var clip_k: float = 0.0               # keys into the clip (a key is 1/60 s)
var clip_rate: float = 1.0
var clip_loop: bool = true
var _anim_clip: Animation
var _posed: bool = false
var _clip_mode: bool = false

var _body: Node3D
var _sk: Skeleton3D
var _mesh: MeshInstance3D
var _g: Array = []                    # the component-space transforms of the pose shown (the mesh's own space)
## REVIEW TOOLS ONLY: deliberate faults, to show a defect test red (rigs/skater/review/skater_defects.gd). All zero in play.
var debug_sink_m: float = 0.0         # the whole body this far under where it should stand
var debug_stretch_m: float = 0.0      # the right forearm this much longer
var debug_stick_yaw_deg: float = 0.0  # the stick turned about its grip by this much more


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


## Builds the figure. params: {"team": 0 | 1, "colour": Color (sRGB; overrides the team's)}.
func setup(p: Dictionary = {}) -> void:
	if _body_scene == null:
		_body_scene = load(BODY_PATH) as PackedScene
	_body = _body_scene.instantiate() as Node3D
	_body.rotation.y = PI * 0.5       # the export faces +X with its right hand on +Z: a quarter turn puts forward on -Z, right on +X
	add_child(_body)
	_sk = _body.get_node("Skeleton3D") as Skeleton3D
	_mesh = _sk.get_node("Mesh") as MeshInstance3D
	TLRigSkaterPose.bind(_sk)
	if upper_mask.is_empty():
		for b: int in range(TLRigSkaterPose.N):
			upper_mask.append(b >= 2 and b <= 16)       # spine_01 .. stick_socket
	# a rig's shading travels with it (RIGS.md, "A rig's shading travels with it"; TLRigs._mark_body): mottle and hatching
	# anchored to the body, no shadow of the figure on itself. The second number is 0.6 x the scale of a 2.0 m biped.
	_mesh.set_instance_shader_parameter(&"tl_body", Vector2(1.0, 0.6 * HEIGHT_M / 2.0))
	team = int(p.get("team", 0))
	set_team_colour(p.get("colour", TEAM_COLOURS[clampi(team, 0, 1)]) as Color)
	_g = TLRigSkaterPose.rest().globals()


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


# ------------------------------------------------------------------ the figure's own frame, in Unreal's terms
## The mesh component's yaw against the actor, degrees (Unreal: positive to the right): the stick lift's turn (and
## the falls', when they are ported). K2_SetRelativeRotation(Mesh, (0, 0, yaw)).
var _mesh_yaw: float = 0.0


func _mesh_yaw_deg() -> float:
	return _mesh_yaw


func set_mesh_yaw_deg(deg: float) -> void:
	if deg != _mesh_yaw:
		_mesh_yaw = deg
		_body.rotation.y = PI * 0.5 - deg_to_rad(deg)


## The mesh component's space to the actor's (Unreal's axes): the yaw about z.
func _to_actor(v: Vector3) -> Vector3:
	if _mesh_yaw == 0.0:
		return v
	var c: float = cos(deg_to_rad(_mesh_yaw))
	var sn: float = sin(deg_to_rad(_mesh_yaw))
	return Vector3(v.x * c - v.y * sn, v.x * sn + v.y * c, v.z)


## A bone's place in the actor's frame as the Blueprint reads it: centimetres, x forward, y right, z up.
func _bone_ue(b: int) -> Vector3:
	return _to_actor(TLRigSkaterPose.ue_vec((_g[b] as Transform3D).origin))


## A vector given in the stick bone's space (Unreal's axes, cm) in the actor's frame (GreaterGreater_VectorRotator
## with the bone's rotation).
func _stick_vec_ue(v: Vector3) -> Vector3:
	return _to_actor(TLRigSkaterPose.ue_vec((_g[TLRigSkaterPose.STICK] as Transform3D).basis * TLRigSkaterPose.from_ue_vec(v)))


func _puck_socket_ue() -> Vector3:
	return _to_actor(TLRigSkaterPose.ue_vec(_g[TLRigSkaterPose.STICK] as Transform3D * PUCK_ON_STICK))


## Where a bone or thirdjam's socket stands in the actor's frame, centimetres, Unreal's axes (x forward, y right,
## z up): what thirdjam's own figure is compared with (tools/skater/driver_oracle.py).
func point_ue(pname: String) -> Vector3:
	if pname == "puck_socket":
		return _puck_socket_ue()
	var b: int = TLRigSkaterPose.bone(pname)
	return _bone_ue(b) if b >= 0 else Vector3.ZERO


func _tick_clip() -> void:
	if _anim_clip == null:
		return
	var last: float = float(clip_keys(clip) - 1)
	if _posed:
		clip_k += clip_rate
		if clip_loop and last > 0.0:
			clip_k = fposmod(clip_k, last)
		else:
			clip_k = clampf(clip_k, 0.0, last)
	_show(sample_clip(clip, minf(clip_k * DT, _anim_clip.length)))
	_posed = true


## One physics frame of the clip being played (review tools). The first tick after `play_clip` shows key 0; each later
## tick moves `clip_rate` keys. A looping clip of N keys has a period of N - 1 ticks at rate 1.
func tick() -> void:
	_tick_clip()


## Starts a clip from its first key (review tools). `loop`: wraps at the clip's length (N - 1 frames), else holds the last key.
func play_clip(cname: StringName, loop: bool = true, rate: float = 1.0) -> bool:
	var a: Animation = clip_library().get_animation(cname)
	if a == null:
		push_warning("TLRigSkater: no clip '%s'" % cname)
		return false
	_clip_mode = true
	clip = cname
	_anim_clip = a
	clip_k = 0.0
	clip_rate = rate
	clip_loop = loop
	_posed = false
	return true


## Poses the figure from a clip at a key (may be fractional), without playing it.
func pose_at(cname: StringName, key: float) -> bool:
	var a: Animation = clip_library().get_animation(cname)
	if a == null:
		return false
	_clip_mode = true
	_show(sample_clip(cname, clampf(key * DT, 0.0, a.length)))
	return true


## The rest pose (review tools).
func pose_rest() -> void:
	_clip_mode = true
	_show(TLRigSkaterPose.rest())


## The key the playing clip shows (fractional when the rate is not 1).
func clip_key() -> float:
	return clip_k


static func _plan(cname: StringName, a: Animation) -> Array:
	if _plans.has(cname):
		return _plans[cname]
	var plan: Array = []
	for t: int in range(a.get_track_count()):
		var bi: int = TLRigSkaterPose.bone(a.track_get_path(t).get_concatenated_subnames())
		if bi >= 0:
			plan.append([t, bi, a.track_get_type(t)])
	_plans[cname] = plan
	return plan


## A clip's pose at a time in seconds (clamped to the clip). A bone the clip does not key stands at rest.
## DEVIATION: between two keys Unreal blends the rotations by a normalised lerp; Godot's track read is a slerp.
## Adjacent keys are 1/60 s apart: the two differ by less than 1e-5 rad.
static func sample_clip(cname: StringName, time: float) -> TLRigSkaterPose:
	# the first key of a clip is asked for every tick by the aim (24 holds read at time 0 by four players): kept.
	# The kept pose is shared: nothing may write to what this function returns (the blends make their own).
	if time <= 0.0 and _first_keys.has(cname):
		return _first_keys[cname]
	var a: Animation = clip_library().get_animation(cname)
	var pose: TLRigSkaterPose = TLRigSkaterPose.rest()
	if a == null:
		return pose
	if time <= 0.0:
		_first_keys[cname] = pose
	var t: float = clampf(time, 0.0, a.length)
	for row: Array in _plan(cname, a):
		if int(row[2]) == Animation.TYPE_ROTATION_3D:
			pose.q[int(row[1])] = a.rotation_track_interpolate(int(row[0]), t)
		elif int(row[2]) == Animation.TYPE_POSITION_3D:
			if int(row[1]) == TLRigSkaterPose.PELVIS:
				pose.tp = a.position_track_interpolate(int(row[0]), t)
			elif int(row[1]) == TLRigSkaterPose.STICK:
				pose.ts = a.position_track_interpolate(int(row[0]), t)
	return pose


func _show(pose: TLRigSkaterPose) -> void:
	_g = pose.globals()
	if debug_stretch_m != 0.0:
		var hand: int = TLRigSkaterPose.bone("hand_r")
		var along: Vector3 = ((_g[hand] as Transform3D).origin - (_g[TLRigSkaterPose.parents[hand]] as Transform3D).origin).normalized()
		_g[hand] = Transform3D((_g[hand] as Transform3D).basis, (_g[hand] as Transform3D).origin + along * debug_stretch_m)
	for b: int in range(TLRigSkaterPose.N):
		_sk.set_bone_pose_rotation(b, pose.q[b] as Quaternion)
	_sk.set_bone_pose_position(TLRigSkaterPose.PELVIS, pose.tp)
	_sk.set_bone_pose_position(TLRigSkaterPose.STICK, pose.ts)
	_last_pose = pose


var _last_pose: TLRigSkaterPose


func skeleton() -> Skeleton3D:
	return _sk


func mesh_instance() -> MeshInstance3D:
	return _mesh


## A bone's transform in the figure's own space by its index, from the pose shown.
func bone_xf(b: int) -> Transform3D:
	var t: Transform3D = _body.transform * (_g[b] as Transform3D)
	t.origin.y -= debug_sink_m
	return t


## The local rotations of the pose shown (24 Quaternion).
func local_rotations() -> Array:
	return _last_pose.q.duplicate() if _last_pose != null else TLRigSkaterPose.rest_q.duplicate()


## A bone's transform in the figure's own space (this node's), from the pose shown (works outside the tree).
func bone_transform(bone: StringName) -> Transform3D:
	var bi: int = TLRigSkaterPose.bone(String(bone))
	if bi < 0:
		return Transform3D.IDENTITY
	return bone_xf(bi)


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


## A Skeleton3D posed outside the tree keeps its drawn skin at rest until it is posed again inside it (see TLRigNode):
## pose again one deferred call after entering.
func _enter_tree() -> void:
	_repose.call_deferred()


func _repose() -> void:
	if _last_pose != null and _sk != null and _sk.is_inside_tree():
		_show(_last_pose)
