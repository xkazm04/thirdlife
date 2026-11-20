class_name TLRigBiped
extends TLRigNode
## The standard biped: 29 bones on Godot humanoid names (+ Backpack, Hair and five face bones), rigid-weighted toy
## forms from lane B, and a procedural clip library driven by tick(frame).
## Clips: idle, walk, run, skate, skate_stop, shoot, pass, cheer, fall, carry, work, jump, land, slide, slope_slide, air.
## Params (set_param): mode (&"walk" | &"skate"), look_at (Vector3 world, or null to clear), expression (&"happy" |
## &"focus" | &"blink"), lean (-1..1, + = right), stick (bool), colors ({part: palette key}).
## Sockets: hand_r, hand_l, head, back, foot_r, foot_l.

const UPPER: PackedStringArray = ["Spine", "Chest", "UpperChest", "Neck", "Head", "LeftShoulder", "RightShoulder",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "Backpack", "Hair"]
const CROUCH: float = 0.84   # two leg segments of 0.42 m: hips drop = CROUCH * (1 - cos(a)) for a knee half-angle a

var _model: Node3D
var _stick: Node3D
var _hammer: Node3D
var _helmet_built: bool = false
var _skates: Array = []
var _stick_on: bool = false
var _was_air: bool = false
var _air_w: float = 0.0     # 0 = on the ground .. 1 = the air pose (eased over 5 ticks)
var _air_vy: float = 0.0    # the last vertical speed seen in the air (m/s at scale 1)
var _impact: float = 0.0    # the fall speed of the last landing
var _crouch_x: float = 0.0  # extra crouch under the gait (the landing)
var _tri_extra: int = 0
var stride_k: float = 1.0   # cadence multiplier (review tool; 1 = shipped)
var amp_override: float = -1.0   # P3 review tool, kept for API v1: the gait has no swing amplitude any more (the stride follows the speed)
var _gait: TLRigBipedGait = TLRigBipedGait.new()
var _amp: float = 1.0   # swing amplitude of the walk and run clips played by name (their authored swing)
var _face_now: Vector2 = Vector2(-1.0, -1.0)   # the (mood, blink) the face bones show (skips rewriting an unchanged face)
var _feel: TLRigBipedFeel   # diorama night: not null = the style asks for the toy figure (biped/tl_rig_biped_toy.gd, _feel.gd); null = this figure as it was


func setup(p: Dictionary) -> void:
	family = &"biped"
	params = p
	name = "Biped"
	_model = Node3D.new()
	_model.name = "Model"
	_model.scale = Vector3.ONE * float(p["scale"])
	add_child(_model)
	_feel = TLRigBipedFeel.new() if TLRigBipedToy.on() else null
	var sk: Skeleton3D = make_skeleton(TLRigBipedToy.bones() if _feel != null else TLRigBipedMesh.final_bones())
	var s: float = float(p["scale"])
	_metrics = {"height": 2.0 * s, "radius": 0.3 * s, "eye_height": 1.765 * s, "bones": sk.get_bone_count(), "triangles": 0}
	_rebuild_mesh(sk)
	for b: String in UPPER:
		_upper[sk.find_bone(b)] = true
	add_socket("hand_r", "RightHand", Vector3(0.29, 0.845, -0.03))
	add_socket("hand_l", "LeftHand", Vector3(-0.29, 0.845, -0.03))
	add_socket("head", "Head", Vector3(0, 2.0 if not _helmet() else 2.0, 0))
	add_socket("back", "UpperChest", Vector3(0, 1.35, 0.2))
	add_socket("foot_r", "RightFoot", Vector3(0.11, 0.0, 0))
	add_socket("foot_l", "LeftFoot", Vector3(-0.11, 0.0, 0))
	_build_stick()
	_build_skates()
	add_clip("idle", 4.0, true, _idle)
	add_clip("walk", 0.9, true, _walk)
	add_clip("run", 0.6, true, _run)
	add_clip("skate", 1.2, true, _skate)
	add_clip("skate_stop", 0.4, false, _skate_stop, false, true)
	add_clip("shoot", 0.85, false, _shoot, true)
	add_clip("pass", 0.55, false, _pass, true)
	add_clip("cheer", 1.2, true, _cheer)
	add_clip("fall", 1.0, false, TLRigBipedMoves.fall_down, false, true)
	add_clip("carry", 0.9, true, _carry)
	add_clip("work", 0.8, true, TLRigBipedMoves.work)
	add_clip("jump", 0.3, false, TLRigBipedMoves.jump)
	add_clip("land", 0.45, false, _land)
	add_clip("slide", 0.3, false, TLRigBipedMoves.slide, false, true)
	add_clip("slope_slide", 1.6, true, TLRigBipedMoves.slope_slide)
	add_clip("air", 1.0, true, _air)
	add_clip("fly", 1.6, true, TLRigBipedMoves.fly)
	add_clip("hang", 2.0, true, TLRigBipedMoves.hang)
	add_clip("mantle", 0.47, false, TLRigBipedMoves.mantle, false, true)
	add_clip("swing", 1.3, true, TLRigBipedMoves.swing)
	_build_hammer()
	_param_changed("stick", p["stick"])
	_param_changed("mode", p["mode"])
	_expr()
	tick(0)


func _rebuild_mesh(sk: Skeleton3D) -> void:
	var look: Dictionary = TLRigBipedMesh.LOOK.duplicate()
	look.merge(params.get("colors", {}), true)
	_helmet_built = _helmet()
	_metrics["triangles"] = TLRigBipedToy.attach(self, _model, sk, look, bool(params["backpack"]), _helmet_built, _feel != null) + _tri_extra


## headgear "auto" = a team helmet (and the hockey kit) in skate mode, nothing in walk mode.
func _helmet() -> bool:
	var h: String = String(params.get("headgear", "auto"))
	return h == "helmet" or (h == "auto" and String(params.get("mode", "walk")) == "skate")


## prop "auto" = the stick in skate mode; `stick = true` still forces it; "hammer" goes with the `work` clip.
func _prop() -> String:
	var pr: String = String(params.get("prop", "auto"))
	if bool(params.get("stick", false)) and pr in ["auto", "stick"]:
		return "stick"
	if pr == "auto":
		return "stick" if String(params.get("mode", "walk")) == "skate" else "none"
	return pr


func _build_hammer() -> void:
	_hammer = Node3D.new()
	_hammer.name = "Hammer"
	var mk: TLMesh = TLMesh.new(74)
	mk.bar(Vector3(0, 0.12, 0), Vector3(0, -0.34, 0), 0.03, 0.04, "wood_light", Color.WHITE, 0.004)
	mk.rbox(Vector3(0.09, 0.09, 0.26), "steel_dark", Color.WHITE, 0.025, Vector3(0, -0.34, -0.02))
	mk.rbox(Vector3(0.095, 0.095, 0.07), "steel_light", Color.WHITE, 0.02, Vector3(0, -0.34, -0.17))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "HammerMesh"
	mi.mesh = TLRigBipedToy.dressed(mk.build("hammer"), _feel != null)
	_hammer.add_child(mi)
	_hammer.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	socket(&"hand_r").add_child(_hammer)
	_hammer.visible = false
	_tri_extra += mk.tri_count
	_metrics["triangles"] = int(_metrics["triangles"]) + mk.tri_count


func _build_stick() -> void:
	_stick = Node3D.new()
	_stick.name = "Stick"
	var mk: TLMesh = TLRigBipedMesh._stick_mesh(params.get("colors", {}))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "StickMesh"
	mi.mesh = TLRigBipedToy.dressed(mk.build("stick"), _feel != null)
	_stick.add_child(mi)
	_stick.rotation_degrees = Vector3(40.0, -30.0, 0.0)   # blade end forward of the hand and out to the right; butt towards the left hip
	socket(&"hand_r").add_child(_stick)
	_tri_extra += mk.tri_count
	_metrics["triangles"] = int(_metrics["triangles"]) + mk.tri_count
	var tip: Node3D = Node3D.new()
	tip.name = "blade"
	tip.position = Vector3(-0.17, -1.0, 0)
	_stick.add_child(tip)
	_sockets["stick_blade"] = tip


func _build_skates() -> void:
	for side: Array in [["foot_l", -0.11], ["foot_r", 0.11]]:
		var mk: TLMesh = TLMesh.new(73)
		mk.box(Vector3(0.025, 0.05, 0.36), "steel_light", Color.WHITE, 0.004, Vector3(0, -0.025, -0.06))
		mk.box(Vector3(0.06, 0.03, 0.10), "steel_dark", Color.WHITE, 0.0, Vector3(0, 0.0, 0.03))
		mk.box(Vector3(0.06, 0.03, 0.10), "steel_dark", Color.WHITE, 0.0, Vector3(0, 0.0, -0.15))
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Skate"
		mi.mesh = TLRigBipedToy.dressed(mk.build("skate"), _feel != null)
		socket(StringName(side[0])).add_child(mi)
		_skates.append(mi)
		_tri_extra += mk.tri_count
		_metrics["triangles"] = int(_metrics["triangles"]) + mk.tri_count


func _param_changed(pname: String, value: Variant) -> void:
	match pname:
		"stick", "prop":
			_apply_prop()
		"headgear":
			_rebuild_mesh(_sk)
		"mode":
			for s: MeshInstance3D in _skates:
				s.visible = String(value) == "skate"
			_apply_prop()
			if _helmet() != _helmet_built:
				_rebuild_mesh(_sk)
			# on blades the body stands 5 cm higher
			_model.position.y = 0.05 * float(params["scale"]) if String(value) == "skate" else 0.0
		"colors":
			_rebuild_mesh(_sk)
			(_stick.get_node("StickMesh") as MeshInstance3D).mesh = TLRigBipedToy.dressed(TLRigBipedMesh._stick_mesh(params.get("colors", {})).build("stick"), _feel != null)   # the stick is a part too
		"expression":
			_expr()


func _apply_prop() -> void:
	var pr: String = _prop()
	_stick_on = pr == "stick"
	_stick.visible = _stick_on
	if _hammer != null:
		_hammer.visible = pr == "hammer"


func _expr() -> void:
	match String(params.get("expression", "happy")):
		"focus": _face(0.0, 0.0)
		"blink": _face(1.0, 1.0)
		_: _face(1.0, 0.0)


## mood 0 = focused (flat mouth, low brows) .. 1 = happy; blink 0 = open .. 1 = closed. Face bones are not touched by clips.
func _face(mood: float, blink: float) -> void:
	var bl: float = clampf(blink, 0.0, 1.0)
	if Vector2(mood, bl) == _face_now:
		return
	_face_now = Vector2(mood, bl)
	var open: float = lerpf(1.0, 0.07, bl) * lerpf(0.8, 1.0, mood)
	for n: String in ["LeftEye", "RightEye"]:
		_sk.set_bone_pose_scale(_sk.find_bone(n), Vector3(lerpf(1.0, 1.12, bl), open, 1.0))
	_sk.set_bone_pose_scale(_sk.find_bone("Glints"), Vector3(1.0, clampf(1.0 - bl / 0.45, 0.0, 1.0) * lerpf(0.8, 1.0, mood), 1.0))
	var bi: int = _sk.find_bone("Brows")
	_sk.set_bone_pose_position(bi, _sk.get_bone_rest(bi).origin + Vector3(0, lerpf(-0.02, 0.006, mood), 0))
	var mi: int = _sk.find_bone("MouthCorners")
	_sk.set_bone_pose_position(mi, _sk.get_bone_rest(mi).origin + Vector3(0, lerpf(-0.012, 0.004, mood), 0))
	_sk.set_bone_pose_scale(mi, Vector3(lerpf(0.6, 1.0, mood), lerpf(0.32, 1.0, mood), 1.0))


# ------------------------------------------------------------------ locomotion
func _speed() -> float:
	return Vector2(_vel.x, _vel.z).length()


func _advance() -> void:
	if String(params.get("mode", "walk")) == "skate":
		_phase = fposmod(_phase + clampf(0.55 + 0.07 * _speed(), 0.55, 1.25) * stride_k * DT, 1.0)
		return
	var vm: Vector2 = Vector2(_vel.x, _vel.z) / float(params["scale"]) if _loco_on else Vector2.ZERO
	if _grounded or not _loco_on:
		if _was_air:
			_gait.land(vm)
		_gait.step(vm, stride_k, global_transform.basis.get_euler().y if is_inside_tree() else NAN)
	_was_air = _loco_on and not _grounded
	_air_w = move_toward(_air_w, 1.0 if _was_air else 0.0, 0.2 if _was_air else 0.34)


func _loco_pose() -> Dictionary:
	var t: float = float(frame) * DT
	var v: float = _speed() if _loco_on else 0.0
	var out: Dictionary
	if String(params.get("mode", "walk")) == "skate":
		var glide: Dictionary = _skate_pose(_phase, 0.12)
		out = _mixe(glide, _skate_pose(_phase, 1.0), smoothstep(0.3, 2.5, v))
	elif _air_w >= 1.0:
		out = _air(t)
	else:      # the side lean is part of the gait: the feet stay where they stand
		return _gait_pose(t) if _air_w <= 0.0 else _mixe(_gait_pose(t), _air(t), _air_w * _air_w * (3.0 - 2.0 * _air_w))
	var lean: float = clampf(float(params.get("lean", 0.0)), -1.0, 1.0)
	if lean != 0.0:
		out = add_pose(out, {"Hips": Vector3(0, 0, -16.0 * lean), "Spine": Vector3(0, 0, -5.0 * lean)})
	return out


## Euler-space mix of two pose dictionaries (small angles; the frame blend in tick() is quaternion based).
static func _mixe(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	if k <= 0.0:
		return a
	if k >= 1.0:
		return b
	var out: Dictionary = {}
	for key: String in a:
		out[key] = (a[key] as Vector3).lerp(b.get(key, Vector3.ZERO), k)
	for key: String in b:
		if not a.has(key):
			out[key] = Vector3.ZERO.lerp(b[key], k)
	return out


func _post_pose() -> void:
	# blink: closed for 6 frames every 204 frames, unless the expression holds the eyes shut. The face is a function of
	# this frame alone (not of the frames ticked before it): a biped first ticked late, or one whose ticks skipped the end
	# of a blink, shows the expression's face, not the half-shut eyes of the last blink it happened to see
	var ex: String = String(params.get("expression", "happy"))
	var ph: int = frame % 204
	if ex != "blink" and ph < 6:
		_face(0.0 if ex == "focus" else 1.0, 1.0 if ph < 4 else 0.5)
	else:
		_expr()
	var la: Variant = params.get("look_at", null)
	if la is Vector3:
		var a: Vector2 = look_angles(la, Vector3(0, 1.75 * float(params["scale"]), 0))
		var yaw: float = clampf(a.x, -70.0, 70.0)
		var pitch: float = clampf(a.y, -30.0, 35.0)
		for b: Array in [["Neck", 0.4], ["Head", 0.6]]:
			var bi: int = _sk.find_bone(b[0])
			var extra: Quaternion = Quaternion.from_euler(Vector3(deg_to_rad(pitch * float(b[1])), deg_to_rad(yaw * float(b[1])), 0))
			_sk.set_bone_pose_rotation(bi, extra * _sk.get_bone_pose_rotation(bi))
	if _feel != null and not _helmet_built: _feel.post(self)   # the bare-headed toy's springs and hand solves; a helmeted skater ticks as he did


# ------------------------------------------------------------------ the walking gait (biped/tl_rig_biped_gait.gd)
## The locomotion pose on the ground: idle, walk, jog, run and sprint are one gait read at the speed.
func _gait_pose(t: float) -> Dictionary:
	var gt: TLRigBipedGait = _gait
	var v: float = gt.v
	var d: float = gt.d
	var ph: float = gt.phase
	var still: float = 1.0 - smoothstep(0.1, 0.7, v)
	var run_w: float = smoothstep(2.0, 3.4, v)
	var amp: float = clampf(gt.ls / 0.6, 0.0, 1.2)
	var s: float = cos(TAU * (ph - (d - 0.5) * 0.5)) * amp        # + = the left leg is ahead
	var lean: float = clampf(float(params.get("lean", 0.0)), -1.0, 1.0)
	var pitch: float = lerpf(-(1.5 + 2.4 * minf(v, 6.5)), 3.0, gt.back_w * (1.0 - still)) - 46.0 * _crouch_x
	var yaw: float = rad_to_deg(gt.psi) - lerpf(4.0, 7.0, run_w) * s
	var b: float = sin(TAU * t / 4.0)
	var y_style: float = -_crouch_x - gt.crouch() - gt.bounce() * cos(2.0 * TAU * (ph - d * 0.5)) + (-0.012 + 0.006 * b) * still
	var sway: float = -lerpf(0.022, 0.008, run_w) * cos(TAU * (ph - d * 0.5)) * minf(amp, 1.0)
	var out: Dictionary = gt.legs_pose(Vector3(pitch, yaw, -16.0 * lean), y_style, Vector3(sway, 0.0, 0.0))
	var bounce: float = cos(2.0 * TAU * (ph - d * 0.5) - 1.0) * minf(amp, 1.0)
	var tw: float = lerpf(5.0, 9.0, run_w) * s        # the shoulders turn against the pelvis
	var sw: float = lerpf(24.0, 44.0, run_w) * s * lerpf(1.0, 0.6, gt.back_w)
	var elbow: float = lerpf(16.0, 80.0, run_w)
	var up: Dictionary = {
		"Spine": Vector3(lerpf(-2.0, -4.0, run_w), -0.5 * yaw + 0.5 * tw, -5.0 * lean), "Chest": Vector3(lerpf(-2.0, -4.0, run_w), -0.5 * yaw + 0.5 * tw, 0),
		"Neck": Vector3(lerpf(2.0, 7.0, run_w), -0.5 * tw, 0), "Head": Vector3(lerpf(3.0, 7.0, run_w) - 0.25 * pitch * run_w, -0.5 * tw, 0),
		"Backpack": Vector3(lerpf(3.5, 7.0, run_w) * bounce, 0, 2.0 * s), "Hair": Vector3(lerpf(4.0, 9.0, run_w) * cos(2.0 * TAU * (ph - d * 0.5) - 1.4) * minf(amp, 1.0), 0, 0),
		"LeftUpperArm": Vector3(lerpf(5.0, 14.0, run_w) - sw, 0, lerpf(-6.0, -8.0, run_w)), "LeftLowerArm": Vector3(elbow + lerpf(14.0, 12.0, run_w) * maxf(0.0, -s), 0, 0), "LeftHand": Vector3(0, 0, 0),
		"RightUpperArm": Vector3(lerpf(5.0, 14.0, run_w) + sw, 0, lerpf(6.0, 8.0, run_w)), "RightLowerArm": Vector3(elbow + lerpf(14.0, 12.0, run_w) * maxf(0.0, s), 0, 0), "RightHand": Vector3(0, 0, 0),
	}
	if _stick_on:
		up.merge(_stick_arms(pitch - 5.0, -4.0 * (1.0 - run_w)), true)
	if _feel != null and not _helmet_built: _feel.upper(up, s, sw, run_w, _stick_on)
	if still > 0.0:
		var idle: Dictionary = _idle(t) if (_feel == null or _helmet_built) else _feel.idle(_idle(t), t, _stick_on)
		var iu: Dictionary = {}
		for key: String in idle:
			if UPPER.has(key):
				iu[key] = idle[key]
		up = _mixe(up, iu, still)
	out.merge(up, true)
	return out


# ------------------------------------------------------------------ pose helpers
## A leg with knee half-angle a under a pelvis pitched by `pitch` (the foot stays flat): returns [upper, lower, foot] x angles.
static func _leg(a: float, pitch: float, swing: float = 0.0) -> Array:
	return [a - pitch + swing, -2.0 * a, a - swing]


static func _sm(t: float, t0: float, t1: float) -> float:
	return smoothstep(t0, t1, t)


## Interpolates keyed poses: keys = [[time, pose], ...] in time order (smooth in and out of every key).
static func _keys(t: float, keys: Array) -> Dictionary:
	if t <= float(keys[0][0]):
		return keys[0][1]
	for i: int in range(1, keys.size()):
		if t <= float(keys[i][0]):
			return _mixe(keys[i - 1][1], keys[i][1], smoothstep(float(keys[i - 1][0]), float(keys[i][0]), t))
	return keys[keys.size() - 1][1]


## Both hands on the stick, blade on the ice ahead of the right foot. `pitch` = total forward lean of the torso (deg, negative).
func _stick_arms(pitch: float, reach: float = 0.0) -> Dictionary:
	return {
		"RightShoulder": Vector3(0, 0, 0), "RightUpperArm": Vector3(2.0 - pitch + reach, 0, 6.0), "RightLowerArm": Vector3(14.0, 0, 0), "RightHand": Vector3(0, 0, 0),
		"LeftUpperArm": Vector3(14.0 - pitch + reach * 0.5, 0, 34.0), "LeftLowerArm": Vector3(88.0, 0, 0), "LeftHand": Vector3(0, 0, 0),
	}


# ------------------------------------------------------------------ clips (pose functions of time in seconds)
func _idle(t: float) -> Dictionary:
	var b: float = sin(TAU * t / 4.0)
	var b2: float = sin(TAU * t / 2.0 + 0.6)
	var out: Dictionary = {
		"_hips": Vector3(0, -0.012 + 0.006 * b, 0), "Hips": Vector3(0, 0, 0),
		"Backpack": Vector3(1.2 * sin(TAU * t / 4.0 - 0.9), 0, 0), "Hair": Vector3(1.5 * sin(TAU * t / 2.0 - 0.4), 0, 1.0 * b),
		"Spine": Vector3(-1.0 - 1.0 * b, 0, 0), "Chest": Vector3(-1.5 - 1.5 * b, 2.0, 0), "Neck": Vector3(1.0, 3.0, 0),
		"Head": Vector3(2.0 + 2.0 * b2, 6.0 + 5.0 * b, 0),
		"LeftUpperArm": Vector3(4.0 + 2.0 * b, 0, -7.0), "LeftLowerArm": Vector3(14.0 - 2.0 * b, 0, 0), "LeftHand": Vector3(0, 0, 0),
		"RightUpperArm": Vector3(3.0 - 2.0 * b2, 0, 7.0), "RightLowerArm": Vector3(16.0 + 3.0 * b2, 0, 0), "RightHand": Vector3(0, 0, 0),
		"LeftUpperLeg": Vector3(0, 0, -4.0), "LeftLowerLeg": Vector3(0, 0, 0), "LeftFoot": Vector3(0, 6.0, 4.0),
		"RightUpperLeg": Vector3(3.0, 0, 4.0), "RightLowerLeg": Vector3(-5.0, 0, 0), "RightFoot": Vector3(2.0, -8.0, -4.0),
	}
	if _stick_on:
		out.merge(_stick_arms(-2.5, -4.0), true)
	return out


func _walk(t: float) -> Dictionary:
	var A: float = _amp
	var p: float = TAU * t / 0.9
	var s: float = sin(p)
	var c: float = cos(p)
	var kl: float = -(8.0 + 44.0 * maxf(0.0, c))
	var kr: float = -(8.0 + 44.0 * maxf(0.0, -c))
	var out: Dictionary = {
		"_hips": Vector3(0, -0.025 + 0.022 * cos(2.0 * p), 0), "Hips": Vector3(-3.0, 6.0 * s, 0),
		"Backpack": Vector3(3.5 * cos(2.0 * p - 1.0), 0, 2.0 * sin(p - 0.6)), "Hair": Vector3(4.0 * cos(2.0 * p - 1.4), 0, 0),
		"LeftToes": Vector3(22.0 * maxf(0.0, -s), 0, 0), "RightToes": Vector3(22.0 * maxf(0.0, s), 0, 0),
		"Spine": Vector3(-2.0, -5.0 * s, 0), "Chest": Vector3(-2.0, -6.0 * s, 0), "Neck": Vector3(2.0, 4.0 * s, 0), "Head": Vector3(3.0, 3.0 * s, 0),
		"LeftUpperArm": Vector3(5.0 - 28.0 * (0.5 + 0.5 * A) * s, 0, -6.0), "LeftLowerArm": Vector3(16.0 + 14.0 * maxf(0.0, -s), 0, 0), "LeftHand": Vector3(0, 0, 0),
		"RightUpperArm": Vector3(5.0 + 28.0 * (0.5 + 0.5 * A) * s, 0, 6.0), "RightLowerArm": Vector3(16.0 + 14.0 * maxf(0.0, s), 0, 0), "RightHand": Vector3(0, 0, 0),
		"LeftUpperLeg": Vector3(3.0 + 30.0 * A * s, 0, 0), "LeftLowerLeg": Vector3(kl, 0, 0), "LeftFoot": Vector3(-(30.0 * A * s + kl) * 0.55, 0, 0),
		"RightUpperLeg": Vector3(3.0 - 30.0 * A * s, 0, 0), "RightLowerLeg": Vector3(kr, 0, 0), "RightFoot": Vector3(-(-30.0 * A * s + kr) * 0.55, 0, 0),
	}
	if _stick_on:
		out.merge(_stick_arms(-7.0, -4.0), true)
	return out


func _run(t: float) -> Dictionary:
	var A: float = _amp
	var p: float = TAU * t / 0.6
	var s: float = sin(p)
	var c: float = cos(p)
	var kl: float = -(22.0 + 72.0 * maxf(0.0, c))
	var kr: float = -(22.0 + 72.0 * maxf(0.0, -c))
	var out: Dictionary = {
		"_hips": Vector3(0, -0.05 + 0.05 * cos(2.0 * p), 0), "Hips": Vector3(-12.0, 9.0 * s, 0),
		"Backpack": Vector3(7.0 * cos(2.0 * p - 1.0), 0, 3.0 * sin(p - 0.6)), "Hair": Vector3(9.0 * cos(2.0 * p - 1.4), 0, 0),
		"LeftToes": Vector3(30.0 * maxf(0.0, -s), 0, 0), "RightToes": Vector3(30.0 * maxf(0.0, s), 0, 0),
		"Spine": Vector3(-4.0, -7.0 * s, 0), "Chest": Vector3(-4.0, -9.0 * s, 0), "Neck": Vector3(8.0, 6.0 * s, 0), "Head": Vector3(8.0, 4.0 * s, 0),
		"LeftUpperArm": Vector3(18.0 - 48.0 * (0.5 + 0.5 * A) * s, 0, -8.0), "LeftLowerArm": Vector3(82.0, 0, 0), "LeftHand": Vector3(0, 0, 0),
		"RightUpperArm": Vector3(18.0 + 48.0 * (0.5 + 0.5 * A) * s, 0, 8.0), "RightLowerArm": Vector3(82.0, 0, 0), "RightHand": Vector3(0, 0, 0),
		"LeftUpperLeg": Vector3(20.0 + 46.0 * A * s, 0, 0), "LeftLowerLeg": Vector3(kl, 0, 0), "LeftFoot": Vector3(-(46.0 * A * s + kl) * 0.4, 0, 0),
		"RightUpperLeg": Vector3(20.0 - 46.0 * A * s, 0, 0), "RightLowerLeg": Vector3(kr, 0, 0), "RightFoot": Vector3(-(-46.0 * A * s + kr) * 0.4, 0, 0),
	}
	if _stick_on:
		out.merge(_stick_arms(-20.0, 0.0), true)
	return out


## In the air (also the `air` clip): rising, apex or falling by the vertical speed of `set_locomotion`.
func _air(_t: float) -> Dictionary:
	return TLRigBipedMoves.air(_vel.y / float(params["scale"]))


## Landing (one shot, 0.45 s): the gait's own legs, feet where they stand, under a crouch that takes the fall. Soft from
## 4 m/s of fall, hard (deep, slow to rise, arms out) at 14 m/s; the fall speed is the last vertical speed seen in the air.
func _land(t: float) -> Dictionary:
	var k: float = smoothstep(4.0, 14.0, _impact)
	var c: float = smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.10, lerpf(0.28, 0.45, k), t))
	_crouch_x = lerpf(0.12, 0.40, k) * c
	var out: Dictionary = _gait_pose(float(frame) * DT)
	_crouch_x = 0.0
	return add_pose(out, {"Chest": Vector3(-6.0 * c, 0, 0), "Head": Vector3(lerpf(6.0, 16.0, k) * c, 0, 0),
		"LeftUpperArm": Vector3(lerpf(14.0, 30.0, k) * c, 0, -lerpf(18.0, 46.0, k) * c), "RightUpperArm": Vector3(lerpf(14.0, 30.0, k) * c, 0, lerpf(18.0, 46.0, k) * c)})


## The landing takes the fall at once: its blend is never longer than 4 frames.
func _blend_of(cname: StringName, blend: float) -> float:
	return minf(blend, 0.07) if cname == &"land" else blend


func _locomotion_changes(velocity_local: Vector3, grounded_now: bool) -> void:
	if not grounded_now:
		_air_vy = velocity_local.y / float(params["scale"])
	elif not _grounded:
		_impact = maxf(0.0, -minf(_air_vy, velocity_local.y / float(params["scale"])))


func _skate(t: float) -> Dictionary:
	return _skate_pose(t / 1.2, 1.0)


## The skating stride. phase in cycles; amp 0 = a still glide in the hockey stance, 1 = full push and recover.
func _skate_pose(phase: float, amp: float) -> Dictionary:
	var p: float = TAU * phase
	var s: float = sin(p)
	var push_l: float = pow(maxf(0.0, s), 0.8) * amp
	var push_r: float = pow(maxf(0.0, -s), 0.8) * amp
	var pitch: float = -30.0 - 6.0 * amp
	var a: float = 36.0
	var out: Dictionary = {
		"_hips": Vector3(0.07 * s * amp, -CROUCH * (1.0 - cos(deg_to_rad(a))) + 0.03 * absf(s) * amp, 0),
		"Hips": Vector3(pitch, 7.0 * s * amp, -5.0 * s * amp),
		"Spine": Vector3(-6.0, -6.0 * s * amp, 0), "Chest": Vector3(-5.0, -8.0 * s * amp, 0), "UpperChest": Vector3(0, 0, 0),
		"Neck": Vector3(16.0, 5.0 * s * amp, 0), "Head": Vector3(20.0, 0, 0),
		"Backpack": Vector3(3.0 * cos(p), 0, 0), "Hair": Vector3(-6.0 - 3.0 * cos(p), 0, 0),
	}
	var tp: float = pitch - 11.0   # torso pitch seen by the arms
	for side: Array in [["Left", push_l, -1.0], ["Right", push_r, 1.0]]:
		var push: float = side[1]
		var sx: float = side[2]
		var aa: float = a * (1.0 - 0.72 * push)                 # the pushing leg straightens
		var world: float = lerpf(aa, -16.0, push)               # ... and trails back
		var upper: float = world - pitch
		var lower: float = -2.0 * aa
		out[String(side[0]) + "UpperLeg"] = Vector3(upper, 0, sx * (4.0 + 24.0 * push))   # out to the side
		out[String(side[0]) + "LowerLeg"] = Vector3(lower, 0, 0)
		out[String(side[0]) + "Foot"] = Vector3(-(pitch + upper + lower) - 10.0 * push, -sx * 28.0 * push, -sx * 10.0 * push)
		out[String(side[0]) + "Toes"] = Vector3(0, 0, 0)
	if _stick_on:
		out.merge(_stick_arms(tp, 6.0 * s * amp), true)
	else:
		out["LeftUpperArm"] = Vector3(-tp * 0.75 + 38.0 * s * amp, 0, -14.0 - 14.0 * push_r)
		out["LeftLowerArm"] = Vector3(34.0, 0, 0)
		out["RightUpperArm"] = Vector3(-tp * 0.75 - 38.0 * s * amp, 0, 14.0 + 14.0 * push_l)
		out["RightLowerArm"] = Vector3(34.0, 0, 0)
		out["LeftHand"] = Vector3(0, 0, 0)
		out["RightHand"] = Vector3(0, 0, 0)
	return out


## Hockey stop: the body snaps sideways (left shoulder back), both skates across the line of travel, deep knees, lean
## away from the direction of travel, head still looking where it was going. Holds its last pose.
func _skate_stop(t: float) -> Dictionary:
	var k: float = _sm(t, 0.0, 0.28)
	var settle: float = 0.5 + 0.5 * cos(minf(t, 0.4) / 0.4 * PI)   # 1 -> 0: the over-rotation settles
	var a: float = 46.0
	var pitch: float = -14.0
	var lg: Array = _leg(a, pitch)
	var stop: Dictionary = {
		"_hips": Vector3(0, -CROUCH * (1.0 - cos(deg_to_rad(a))), 0.05), "Hips": Vector3(pitch, 78.0 + 10.0 * settle, 17.0),
		"Spine": Vector3(-6.0, -8.0, -4.0), "Chest": Vector3(-6.0, -10.0, -4.0), "Neck": Vector3(8.0, -28.0, 0), "Head": Vector3(8.0, -34.0, 0),
		"LeftUpperLeg": Vector3(float(lg[0]) + 8.0, 0, -12.0), "LeftLowerLeg": Vector3(float(lg[1]), 0, 0), "LeftFoot": Vector3(float(lg[2]) - 8.0, 0, -6.0),
		"RightUpperLeg": Vector3(float(lg[0]) - 8.0, 0, 16.0), "RightLowerLeg": Vector3(float(lg[1]) + 14.0, 0, 0), "RightFoot": Vector3(float(lg[2]) - 6.0, 0, -12.0),
		"Backpack": Vector3(-6.0 * settle, 0, 0), "Hair": Vector3(0, 0, 10.0 * settle),
	}
	if _stick_on:
		stop.merge(_stick_arms(pitch - 12.0, 0.0), true)
	else:
		stop.merge({"LeftUpperArm": Vector3(20.0, 0, -52.0), "LeftLowerArm": Vector3(30.0, 0, 0), "RightUpperArm": Vector3(24.0, 0, 46.0), "RightLowerArm": Vector3(34.0, 0, 0)}, true)
	return _mixe(_skate_pose(0.0, 0.12), stop, k)


## The hockey stance the shot and the pass start from and return to.
func _stance(pitch: float = -30.0) -> Dictionary:
	var a: float = 34.0
	var lg: Array = _leg(a, pitch)
	var out: Dictionary = {
		"_hips": Vector3(0, -CROUCH * (1.0 - cos(deg_to_rad(a))), 0), "Hips": Vector3(pitch, 0, 0),
		"Spine": Vector3(-6.0, 0, 0), "Chest": Vector3(-5.0, 0, 0), "UpperChest": Vector3(0, 0, 0), "Neck": Vector3(16.0, 0, 0), "Head": Vector3(18.0, 0, 0),
		"LeftUpperLeg": Vector3(float(lg[0]), 0, -9.0), "LeftLowerLeg": Vector3(float(lg[1]), 0, 0), "LeftFoot": Vector3(float(lg[2]), 6.0, 9.0),
		"RightUpperLeg": Vector3(float(lg[0]), 0, 9.0), "RightLowerLeg": Vector3(float(lg[1]), 0, 0), "RightFoot": Vector3(float(lg[2]), -6.0, -9.0),
	}
	out.merge(_stick_arms(pitch - 11.0, 0.0), true)
	return out


## Slap shot, one-shot (0.85 s): wind-up (stick back and up, chest turned to the stick side) 0..0.30, swing through
## the puck 0.30..0.42, follow-through high with the back leg lifting 0.42..0.6, recover.
func _shoot(t: float) -> Dictionary:
	var base: Dictionary = _stance()
	var wind: Dictionary = add_pose(base, {
		"Hips": Vector3(4.0, -22.0, 0), "Chest": Vector3(0, -30.0, 0), "UpperChest": Vector3(0, -14.0, 0), "Head": Vector3(0, 46.0, 0),
		"RightUpperArm": Vector3(-98.0, 0, 30.0), "RightLowerArm": Vector3(-8.0, 0, 0), "RightHand": Vector3(-62.0, 0, 0),
		"LeftUpperArm": Vector3(-14.0, 0, 16.0), "LeftLowerArm": Vector3(14.0, 0, 0),
		"_hips": Vector3(0.05, 0.02, 0.03), "RightUpperLeg": Vector3(-6.0, 0, 6.0), "LeftUpperLeg": Vector3(6.0, 0, 0)})
	var hit: Dictionary = add_pose(base, {
		"Hips": Vector3(-4.0, 8.0, 0), "Chest": Vector3(-4.0, 8.0, 0), "Head": Vector3(-6.0, -6.0, 0),
		"RightUpperArm": Vector3(10.0, 0, 0), "RightHand": Vector3(8.0, 0, 0), "LeftUpperArm": Vector3(8.0, 0, 0),
		"_hips": Vector3(-0.05, -0.04, -0.05)})
	var follow: Dictionary = add_pose(base, {
		"Hips": Vector3(-6.0, 30.0, 0), "Chest": Vector3(2.0, 34.0, 0), "UpperChest": Vector3(0, 12.0, 0), "Head": Vector3(2.0, -40.0, 0),
		"RightUpperArm": Vector3(74.0, 0, -10.0), "RightLowerArm": Vector3(6.0, 0, 0), "RightHand": Vector3(26.0, 0, 0),
		"LeftUpperArm": Vector3(44.0, 0, 10.0), "LeftLowerArm": Vector3(-20.0, 0, 0),
		"_hips": Vector3(-0.08, 0.02, -0.08), "RightUpperLeg": Vector3(-44.0, 0, 8.0), "RightLowerLeg": Vector3(8.0, 0, 0), "RightFoot": Vector3(30.0, 0, 0),
		"LeftUpperLeg": Vector3(4.0, 0, 0)})
	return _keys(t, [[0.0, base], [0.30, wind], [0.42, hit], [0.56, follow], [0.66, follow], [0.85, base]])


## Pass, one-shot (0.55 s): a short low sweep, the blade stays on the ice, no leg lift.
func _pass(t: float) -> Dictionary:
	var base: Dictionary = _stance(-26.0)
	var back: Dictionary = add_pose(base, {
		"Hips": Vector3(0, -8.0, 0), "Chest": Vector3(0, -16.0, 0), "Head": Vector3(0, 22.0, 0),
		"RightUpperArm": Vector3(-24.0, 0, 8.0), "LeftUpperArm": Vector3(-10.0, 0, 4.0), "RightHand": Vector3(-8.0, 0, 0), "_hips": Vector3(0.03, 0, 0.02)})
	var push: Dictionary = add_pose(base, {
		"Hips": Vector3(-5.0, 14.0, 0), "Chest": Vector3(-3.0, 26.0, 0), "Head": Vector3(4.0, -30.0, 0),
		"RightUpperArm": Vector3(15.0, 0, -8.0), "RightLowerArm": Vector3(-8.0, 0, 0), "LeftUpperArm": Vector3(12.0, 0, 6.0), "RightHand": Vector3(-6.0, 0, 0), "_hips": Vector3(-0.04, -0.04, -0.05)})
	return _keys(t, [[0.0, base], [0.16, back], [0.30, push], [0.38, push], [0.55, base]])


func _cheer(t: float) -> Dictionary:
	var p: float = TAU * t / 1.2
	var hop: float = maxf(0.0, sin(2.0 * p))
	var land: float = maxf(0.0, -sin(2.0 * p))
	var a: float = 8.0 + 22.0 * land
	var lg: Array = _leg(a, 4.0)
	var w: float = sin(p)
	return {
		"_hips": Vector3(0, 0.14 * hop - CROUCH * (1.0 - cos(deg_to_rad(a))), 0), "Hips": Vector3(4.0, 0, 3.0 * w),
		"Spine": Vector3(4.0, 0, 0), "Chest": Vector3(5.0, 0, 0), "Neck": Vector3(8.0, 0, 0), "Head": Vector3(12.0, 8.0 * w, 0),
		"LeftShoulder": Vector3(0, 0, -12.0), "RightShoulder": Vector3(0, 0, 12.0),
		"LeftUpperArm": Vector3(170.0 + 8.0 * w, 0, -34.0 - 8.0 * hop), "LeftLowerArm": Vector3(8.0 + 14.0 * hop, 0, 0), "LeftHand": Vector3(0, 0, 0),
		"RightUpperArm": Vector3(170.0 - 8.0 * w, 0, 34.0 + 8.0 * hop), "RightLowerArm": Vector3(8.0 + 14.0 * hop, 0, 0), "RightHand": Vector3(-50.0 if _stick_on else 0.0, 0, 0),
		"LeftUpperLeg": Vector3(float(lg[0]), 0, -5.0), "LeftLowerLeg": Vector3(float(lg[1]), 0, 0), "LeftFoot": Vector3(float(lg[2]) - 14.0 * hop, 0, 0),
		"RightUpperLeg": Vector3(float(lg[0]), 0, 5.0), "RightLowerLeg": Vector3(float(lg[1]), 0, 0), "RightFoot": Vector3(float(lg[2]) - 14.0 * hop, 0, 0),
		"Backpack": Vector3(-8.0 * hop, 0, 0), "Hair": Vector3(-8.0 * hop, 0, 0),
	}


func _carry(t: float) -> Dictionary:
	if String(params.get("mode", "walk")) == "walk" and _loco_on:
		# walker-feel: under a load the legs are the gait's (planted, at the real speed and direction); the arms hold the load
		var g: Dictionary = _gait_pose(t)
		var q: float = TAU * _gait.phase
		g.merge({
			"Spine": Vector3(3.0, 0, 0) + Vector3(0, (g["Spine"] as Vector3).y, 0), "Chest": Vector3(3.0, 0, 0) + Vector3(0, (g["Chest"] as Vector3).y, 0), "Head": Vector3(2.0, 0, 0),
			"LeftUpperArm": Vector3(34.0 + 2.0 * cos(2.0 * q), 0, 10.0), "LeftLowerArm": Vector3(62.0, 0, 0), "LeftHand": Vector3(0, 0, -20.0),
			"RightUpperArm": Vector3(34.0 + 2.0 * cos(2.0 * q), 0, -10.0), "RightLowerArm": Vector3(62.0, 0, 0), "RightHand": Vector3(0, 0, 20.0),
		}, true)
		return g
	var out: Dictionary = _walk(t)
	var p: float = TAU * t / 0.9
	out.merge({
		"Hips": Vector3(2.0, 3.0 * sin(p), 0), "Spine": Vector3(3.0, 0, 0), "Chest": Vector3(3.0, 0, 0), "Head": Vector3(2.0, 0, 0),
		"LeftUpperArm": Vector3(34.0 + 2.0 * cos(2.0 * p), 0, 10.0), "LeftLowerArm": Vector3(62.0, 0, 0), "LeftHand": Vector3(0, 0, -20.0),
		"RightUpperArm": Vector3(34.0 + 2.0 * cos(2.0 * p), 0, -10.0), "RightLowerArm": Vector3(62.0, 0, 0), "RightHand": Vector3(0, 0, 20.0),
	}, true)
	for k: String in ["LeftUpperLeg", "RightUpperLeg"]:
		out[k] = (out[k] as Vector3) * Vector3(0.75, 1, 1)
	return out
