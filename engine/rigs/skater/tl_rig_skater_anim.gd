class_name TLRigSkaterAnim
extends TLRigSkaterSlot
## thirdjam's animation blueprint ABP_SkaterTB1_P3, ported node by node from its exported graph
## (engine/rigs/skater/driver-ref/ABP_SkaterTB1_P3.AnimGraph.txt: the node names in the comments are that
## listing's), and run as Unreal 5.9 runs it at a fixed 1/60 s tick (the engine's own source is cited as
## "SM" = Engine/Private/Animation/AnimNode_StateMachine.cpp, "BLB" = AnimGraphRuntime/.../AnimNodeTLRigSkaterBlendListBase.cpp,
## "LBB" = AnimNode_LayeredBoneBlend.cpp + AnimationRuntime.cpp:2128-2202, "MB" = BoneControllers/AnimNode_ModifyBone.cpp,
## "MON" = AnimMontage.cpp / AnimInstance.cpp, "SLOT" = AnimNode_Slot.cpp + AnimInstanceProxy.cpp:2063-2177).
## thirdjam's build blends with a cubic ease by default: UE::Anim::DefaultBlendOption = HermiteCubic
## (Engine/Public/AlphaBlend.h:33), so state cross-fades, blend lists and montage blends follow S(x) = x^2 (3 - 2x).
## Internal to engine/rigs/skater: the figure (TLRigSkater) owns one and sets its variables as the Blueprint does.
##
## The graph, innermost first (what a tick evaluates):
##   StateMachine_0  Idle | Skate (BlendListByBool_0 on bReady: SkateReady / Skate blend space, X = Speed, Y = TurnRate)
##                   | Fall | FallForward | GetUp | GetUpFront
##   BlendListByBool_4 (bStLoco)  the machine, or BlendListByBool_5 (bStFace): Faceoff_Ready, or _6 (bStHold):
##                                Goalie_Hold, or _7 (bStRight): Goalie_Block_Right / _Left
##   LayeredBoneBlend_1 (AimW)    spine_01 and above take the aim: four Aim blend-space players at reach 1.0 / 1.3 / 1.45 /
##                                1.6 m mixed by T1..T3 (TwoWayBlend_0, _2, _3)
##   LayeredBoneBlend_0 (HoldW)   the cross-check hold: NOT PORTED YET (weight stays 0)
##   LayeredBoneBlend_2 (PassW)   spine_01 and above take SequencePlayer_10 (Pass_Charge, looping): the held pass
##   ModifyBone_1 stick_socket (StickRot, StickOff), _5 spine_01 (GraceRot), _6 hand_r (LockRot), _7 spine_03 (LookRot1),
##   _8 head (LookRot2)           component space, additive
##   TwoWayBlend_1 (ChargeAlpha)  all of the above against SequenceEvaluator_1: Shot_Slap at ChargeTime (the held shot's
##                                wind-up); at alpha 1 the above is neither ticked nor evaluated (the machine starts
##                                over when it comes back: "TWB" = AnimGraphRuntime/.../AnimNode_TwoWayBlend.cpp)
##   Slot DefaultSlot             the takes played by PlaySlotAnimationAsDynamicMontage
##   ModifyBone_0, _2, _3, _4     the whip (WhipA): NOT PORTED YET (0)
## Carry poses (bCarry1..5) and the cross-check hold are named above so that a later round finds their place; with
## their variables at 0 / false they change nothing here.

const DT: float = 1.0 / 60.0
const EPS: float = 1e-5

enum { IDLE, SKATE, FALL, FALL_FORWARD, GET_UP, GET_UP_FRONT }
const STATE_NAMES: Array = ["Idle", "Skate", "Fall", "FallForward", "GetUp", "GetUpFront"]
const STATE_CLIP: Array = ["Idle", "", "Fall", "Fall_Forward", "GetUp", "GetUp_Front"]
const AIM_REACH: Array = [1.0, 1.3, 1.45, 1.6]      # BlendSpacePlayer_1, _0, _2, _3: Y pins

# ---- the blueprint's variables (set by BP_SkaterVisual_TB1_P3; all start at zero / false: the class defaults)
var Speed: float = 0.0
var TurnRate: float = 0.0
var bKnockedDown: bool = false
var bFallForward: bool = false
var bReady: bool = false
var AimAngle: float = 0.0
var AimReach: float = 0.0
var T1: float = 0.0
var T2: float = 0.0
var T3: float = 0.0
var AimW: float = 0.0
var ChargeTime: float = 0.0
var ChargeAlpha: float = 0.0
var bStLoco: bool = false
var bStFace: bool = false
var bStHold: bool = false
var bStRight: bool = false
var HoldW: float = 0.0
var PassW: float = 0.0
var StickRot: Quaternion = Quaternion.IDENTITY     # Unreal's component axes (the Blueprint's rotator, kept as its quaternion)
var StickOff: Vector3 = Vector3.ZERO               # Unreal's component axes, centimetres
var GraceRot: Quaternion = Quaternion.IDENTITY
var GraceA: float = 0.0
var LockRot: Quaternion = Quaternion.IDENTITY
var StickA: float = 0.0
var LookRot1: Quaternion = Quaternion.IDENTITY
var LookRot2: Quaternion = Quaternion.IDENTITY
var WhipA: float = 0.0

# ---- run state
var state: int = IDLE
var transitions: Array = []        # [{prev, next, D, el, lerp, rem, alpha}]
var _first: bool = true
var _sm_ticked: bool = false       # the machine was ticked in the last update
var _seq_t: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]     # each state's sequence player
var _bs_skate: TLRigSkaterBlendSpace
var _bs_ready: TLRigSkaterBlendSpace
var _ready_list: TLRigSkaterBlendList          # BlendListByBool_0 inside Skate
var _loco_list: TLRigSkaterBlendList           # BlendListByBool_4
var _face_list: TLRigSkaterBlendList           # BlendListByBool_5
var _hold_list: TLRigSkaterBlendList           # BlendListByBool_6
var _right_list: TLRigSkaterBlendList          # BlendListByBool_7
var _players: Dictionary = {"Faceoff_Ready": 0.0, "Goalie_Hold": 0.0, "Goalie_Block_Right": 0.0, "Goalie_Block_Left": 0.0, "Pass_Charge": 0.0}     # SequencePlayer_4 .. _7, _10
var _a_ticked: bool = true           # TwoWayBlend_1's A side (everything under the shot charge) was ticked
var _aim: Array = []                 # four players of the Aim blend space
var _aim_ticked: bool = false
var _source_ticked: bool = true
var _ticked_states: Dictionary = {}
var not_ported: Dictionary = {}      # what a tick met and could not show: name -> ticks


func _init() -> void:
	_bs_skate = TLRigSkaterBlendSpace.new("Skate")
	_bs_ready = TLRigSkaterBlendSpace.new("SkateReady")
	_ready_list = TLRigSkaterBlendList.new(0.1, 0.1)
	_loco_list = TLRigSkaterBlendList.new(0.1, 0.1)
	_face_list = TLRigSkaterBlendList.new(0.1, 0.1)
	_hold_list = TLRigSkaterBlendList.new(0.1, 0.1)
	_right_list = TLRigSkaterBlendList.new(0.1, 0.1)
	for i: int in range(4):
		_aim.append(TLRigSkaterBlendSpace.new("Aim", 0.0))


func _miss(what: String) -> void:
	not_ported[what] = int(not_ported.get(what, 0)) + 1


# ------------------------------------------------------------------ the state machine
func _rules(s: int) -> Array:
	# [next state, the rule's value, cross-fade seconds, automatic]; in Unreal's order of evaluation (SM spec: the
	# Out pin's links through the priority sort)
	var fall: bool = bKnockedDown and not bFallForward
	var fallf: bool = bKnockedDown and bFallForward
	match s:
		IDLE: return [[FALL, fall, 0.15, false], [FALL_FORWARD, fallf, 0.15, false], [SKATE, Speed > 0.3, 0.3, false]]
		SKATE: return [[FALL, fall, 0.15, false], [FALL_FORWARD, fallf, 0.15, false], [IDLE, Speed < 0.25, 0.4, false]]
		FALL: return [[GET_UP, not bKnockedDown, 0.15, false]]
		FALL_FORWARD: return [[GET_UP_FRONT, not bKnockedDown, 0.2, false]]
		_: return [[FALL, fall, 0.15, false], [FALL_FORWARD, fallf, 0.15, false], [SKATE, false, 0.3, true]]


func _state_weight(s: int) -> float:
	if transitions.is_empty():
		return 1.0 if s == state else 0.0
	var w: Dictionary = {int(transitions[0]["prev"]): 1.0}
	for tr: Dictionary in transitions:
		var a: float = float(tr["alpha"])
		for k: int in w.keys():
			w[k] = float(w[k]) * (1.0 - a)
		w[int(tr["next"])] = float(w.get(int(tr["next"]), 0.0)) + a
	return float(w.get(s, 0.0))


func _init_state(s: int) -> void:
	_seq_t[s] = 0.0
	if s == SKATE:
		_bs_skate.reset()
		_bs_ready.reset()
		_ready_list.reset()


func _tick_state(s: int, dt: float) -> void:
	if _ticked_states.has(s):
		return
	_ticked_states[s] = true
	if s == SKATE:
		_ready_list.update(bReady, dt)
		if float(_ready_list.w[0]) > EPS:
			_bs_ready.update(Speed, TurnRate, dt)
		if float(_ready_list.w[1]) > EPS:
			_bs_skate.update(Speed, TurnRate, dt)
		return
	var length: float = TLRigSkater.clip_library().get_animation(StringName(String(STATE_CLIP[s]))).length
	var t: float = float(_seq_t[s]) + dt
	if s == IDLE:
		if t > length:
			t = fposmod(t, length)
	else:
		t = minf(t, length)
	_seq_t[s] = t


func _update_machine(dt: float) -> void:
	if not _first and not _sm_ticked:
		state = IDLE
		transitions = []
		_first = true
		_init_state(IDLE)
	for _i: int in range(3):
		var took: bool = false
		for rule: Array in _rules(state):
			var fires: bool = bool(rule[1])
			var crossfade: float = float(rule[2])
			var adj: float = 0.0
			if bool(rule[3]):
				# the automatic rule: when the state's clip has no more left than the cross-fade (SM:817-859); not on the
				# tick the state was entered (its player has no cached weight yet)
				var clip_len: float = TLRigSkater.clip_library().get_animation(StringName(String(STATE_CLIP[state]))).length
				var remaining: float = clip_len - float(_seq_t[state])
				adj = crossfade - remaining
				fires = adj >= 0.0 and not _entered_this_tick
			if not fires:
				continue
			var nxt: int = int(rule[0])
			var w: float = _state_weight(nxt)
			var x: float = 1.0 - w
			var d: float = maxf(crossfade - adj, 0.0) * (4.0 / 3.0 * x * x * x - 2.0 * x * x + 5.0 / 3.0 * x)
			transitions.append({"prev": state, "next": nxt, "D": f32(d), "el": 0.0, "lerp": 0.0, "rem": f32(d), "alpha": 0.0})
			if w <= 0.0:
				_init_state(nxt)
			state = nxt
			_entered_this_tick = true
			took = true
			break
		if not took:
			break
	if _first:
		transitions = []
		_first = false
	var last_finished: int = -1
	for i: int in range(transitions.size()):
		var tr: Dictionary = transitions[i]
		tr["el"] = float(tr["el"]) + dt
		if float(tr["D"]) <= 0.0:
			tr["lerp"] = 1.0
		else:
			var st: Array = blend_step(float(tr["lerp"]), float(tr["rem"]), dt)
			tr["lerp"] = st[0]
			tr["rem"] = st[1]
		tr["el"] = f32(float(tr["el"]))
		tr["alpha"] = scurve(float(tr["el"]) / float(tr["D"])) if float(tr["D"]) > 0.0 else 0.0
		if blend_value(float(tr["lerp"]), 0.0, 1.0) == 1.0:
			last_finished = i
		else:
			_tick_state(int(tr["prev"]), dt)
			_tick_state(int(tr["next"]), dt)
	if last_finished >= 0:
		transitions = transitions.slice(last_finished + 1)
	if transitions.is_empty():
		_tick_state(state, dt)
	_entered_this_tick = false


var _entered_this_tick: bool = false


func _state_pose(s: int) -> TLRigSkaterPose:
	if s == SKATE:
		var w0: float = float(_ready_list.w[0])
		if w0 >= 1.0 - EPS:
			return _bs_ready.evaluate()
		if w0 <= EPS:
			return _bs_skate.evaluate()
		return TLRigSkaterPose.blend([_bs_ready.evaluate(), _bs_skate.evaluate()], PackedFloat32Array([w0, float(_ready_list.w[1])]))
	return TLRigSkater.sample_clip(StringName(String(STATE_CLIP[s])), float(_seq_t[s]))


func _machine_pose() -> TLRigSkaterPose:
	if transitions.is_empty():
		return _state_pose(state)
	var a0: float = float(transitions[0]["alpha"])
	var out: TLRigSkaterPose = TLRigSkaterPose.blend2(_state_pose(int(transitions[0]["prev"])), _state_pose(int(transitions[0]["next"])), a0)
	for i: int in range(1, transitions.size()):
		out = TLRigSkaterPose.blend2(out, _state_pose(int(transitions[i]["next"])), float(transitions[i]["alpha"]))
	return out


# ------------------------------------------------------------------ one tick
## UAnimInstance::UpdateAnimation at 1/60 s: the montages first (weights, then positions), then the graph.
func update(dt: float = DT) -> void:
	_tick_montages(dt)
	var w_total: float = 0.0
	for m: Dictionary in montages:
		if float(m["w"]) > EPS:
			w_total += float(m["w"])
	# SLOT: the source below the slot is ticked only while it has weight
	_source_ticked = (1.0 - minf(w_total, 1.0)) > EPS
	_ticked_states = {}
	var machine_ticked: bool = false
	_aim_ticked = false
	# TwoWayBlend_1: under the threshold only A is ticked, at 1 only B (TWB: FAnimNode_TwoWayBlend::Update_AnyThread)
	_a_ticked = _source_ticked and clampf(ChargeAlpha, 0.0, 1.0) < 1.0 - EPS
	if _a_ticked:
		if PassW > EPS:
			_tick_player("Pass_Charge", true, dt)       # LayeredBoneBlend_2's layer, while it has weight (LBB)
		if HoldW > EPS:
			_miss("LayeredBoneBlend_0 HoldW (the cross-check hold)")
		# LayeredBoneBlend_1: the layer before the base (LBB), neither when its weight is nothing
		if AimW > EPS:
			# the four players stand still in time (play rate 0): a tick only finds their samples, and a player on the
			# far side of a TwoWayBlend at 0 or 1 is not ticked at all. So each is weighed where it is read (_aim_at).
			_aim_ticked = true
		_loco_list.update(bStLoco, dt)
		if float(_loco_list.w[0]) > EPS:
			_update_machine(dt)
			machine_ticked = true
		if float(_loco_list.w[1]) > EPS:
			_face_list.update(bStFace, dt)
			if float(_face_list.w[0]) > EPS:
				_tick_player("Faceoff_Ready", true, dt)
			if float(_face_list.w[1]) > EPS:
				_hold_list.update(bStHold, dt)
				if float(_hold_list.w[0]) > EPS:
					_tick_player("Goalie_Hold", true, dt)
				if float(_hold_list.w[1]) > EPS:
					_right_list.update(bStRight, dt)
					if float(_right_list.w[0]) > EPS:
						_tick_player("Goalie_Block_Right", false, dt)
					if float(_right_list.w[1]) > EPS:
						_tick_player("Goalie_Block_Left", false, dt)
	_sm_ticked = machine_ticked
	if GraceA > EPS or StickA > EPS:
		_miss("ModifyBone_5 / _6 (take grace, stick lock)")
	if WhipA > EPS:
		_miss("ModifyBone_0 / _2 / _3 / _4 (the whip)")


## A sequence player outside the machine (FAnimNode_SequencePlayer): it advances while it has weight, wraps or holds
## its last key, and is never reset.
func _tick_player(cname: String, loop: bool, dt: float) -> void:
	var length: float = TLRigSkater.clip_library().get_animation(StringName(cname)).length
	var t: float = float(_players[cname]) + dt
	if loop:
		if t > length:
			t = fposmod(t, length)
	else:
		t = minf(t, length)
	_players[cname] = t


func _player_pose(cname: String) -> TLRigSkaterPose:
	return TLRigSkater.sample_clip(StringName(cname), float(_players[cname]))


static func _list_pose(l: TLRigSkaterBlendList, a: Callable, b: Callable) -> TLRigSkaterPose:
	var w0: float = float(l.w[0])
	if w0 >= 1.0 - EPS:
		return a.call()
	if w0 <= EPS:
		return b.call()
	return TLRigSkaterPose.blend([a.call(), b.call()], PackedFloat32Array([w0, float(l.w[1])]))


## BlendListByBool_5 and under: the faceoff stance, the goalie's hold and blocks.
func _stance_pose() -> TLRigSkaterPose:
	return _list_pose(_face_list, _player_pose.bind("Faceoff_Ready"), func() -> TLRigSkaterPose:
		return _list_pose(_hold_list, _player_pose.bind("Goalie_Hold"), func() -> TLRigSkaterPose:
			return _list_pose(_right_list, _player_pose.bind("Goalie_Block_Right"), _player_pose.bind("Goalie_Block_Left"))))


func _aim_at(i: int) -> TLRigSkaterPose:
	var p: TLRigSkaterBlendSpace = _aim[i]
	p.weigh(AimAngle, float(AIM_REACH[i]))
	return p.evaluate()


func _aim_pose() -> TLRigSkaterPose:
	# TwoWayBlend_3 (T3) [ TwoWayBlend_2 (T2) [ TwoWayBlend_0 (T1) [ reach 1.0, reach 1.3 ], reach 1.45 ], reach 1.6 ]
	var p: TLRigSkaterPose
	var a3: float = clampf(T3, 0.0, 1.0)
	if a3 >= 1.0 - EPS:
		return _aim_at(3)
	var a2: float = clampf(T2, 0.0, 1.0)
	if a2 >= 1.0 - EPS:
		p = _aim_at(2)
	else:
		var a1: float = clampf(T1, 0.0, 1.0)
		if a1 >= 1.0 - EPS:
			p = _aim_at(1)
		elif a1 <= EPS:
			p = _aim_at(0)
		else:
			p = TLRigSkaterPose.blend2(_aim_at(0), _aim_at(1), a1)
		if a2 > EPS:
			p = TLRigSkaterPose.blend2(p, _aim_at(2), a2)
	if a3 > EPS:
		p = TLRigSkaterPose.blend2(p, _aim_at(3), a3)
	return p


## FAnimationRuntime::BlendPosesPerBoneFilter with mesh-space rotation blending (LBB: AnimationRuntime.cpp:2128-2202):
## the layer's bones from spine_01 up (the mask of BranchFilters spine_01, BlendDepth 0) at weight w; rotations are
## blended in mesh space, translations stay local.
static func layered(base: TLRigSkaterPose, layer: TLRigSkaterPose, w: float) -> TLRigSkaterPose:
	var out: TLRigSkaterPose = base.copy()
	var ms: Array = base.global_rotations()
	var mt: Array = layer.global_rotations()
	var mb: Array = []
	mb.resize(TLRigSkaterPose.N)
	var ww: float = clampf(w, 0.0, 1.0)
	for b: int in range(TLRigSkaterPose.N):
		var wb: float = ww if TLRigSkater.upper_mask[b] else 0.0
		if wb <= EPS:
			mb[b] = ms[b]
		elif wb >= 1.0 - EPS:
			mb[b] = mt[b]
			if b == TLRigSkaterPose.STICK:
				out.ts = layer.ts
		else:
			var s: Quaternion = ms[b]
			var t: Quaternion = mt[b]
			var k: float = (1.0 - wb) * (1.0 if s.dot(t) >= 0.0 else -1.0)
			mb[b] = Quaternion(t.x * wb + s.x * k, t.y * wb + s.y * k, t.z * wb + s.z * k, t.w * wb + s.w * k).normalized()
			if b == TLRigSkaterPose.STICK:
				out.ts = base.ts.lerp(layer.ts, wb)
		var p: int = TLRigSkaterPose.parents[b]
		if p >= 0 and wb > EPS:
			out.q[b] = ((mb[p] as Quaternion).inverse() * (mb[b] as Quaternion)).normalized()
	return out


## FAnimNode_ModifyBone, rotation (and translation) additive in component space (MB:40-111), Alpha 1.
## `rot` and `offset_cm` are in Unreal's component axes.
static func modify_bone(pose: TLRigSkaterPose, b: int, rot: Quaternion, offset_cm: Vector3 = Vector3.ZERO) -> void:
	var parent: int = TLRigSkaterPose.parents[b]
	var chain: Array = []
	var p: int = parent
	while p >= 0:
		chain.append(p)
		p = TLRigSkaterPose.parents[p]
	var pg: Transform3D = Transform3D.IDENTITY
	for i: int in range(chain.size() - 1, -1, -1):
		pg = pg * Transform3D(Basis(pose.q[int(chain[i])] as Quaternion), pose.local_t(int(chain[i])))
	var c: Transform3D = pg * Transform3D(Basis(pose.q[b] as Quaternion), pose.local_t(b))
	var cq: Quaternion = (TLRigSkaterPose.from_ue_quat(rot) * c.basis.get_rotation_quaternion()).normalized()
	var ct: Vector3 = c.origin + TLRigSkaterPose.from_ue_vec(offset_cm)
	var pq: Quaternion = pg.basis.get_rotation_quaternion()
	pose.q[b] = (pq.inverse() * cq).normalized()
	if b == TLRigSkaterPose.STICK and not offset_cm.is_zero_approx():
		pose.ts = pg.affine_inverse() * ct


## The pose of the tick `update` just ran.
func evaluate() -> TLRigSkaterPose:
	var out: TLRigSkaterPose = null
	var w_total: float = 0.0
	var live: Array = []
	for m: Dictionary in montages:
		if float(m["w"]) > EPS:
			live.append(m)
			w_total += float(m["w"])
	if _a_ticked:
		var loco: TLRigSkaterPose = _list_pose(_loco_list, _machine_pose, _stance_pose)
		out = layered(loco, _aim_pose(), AimW) if _aim_ticked else loco.copy()
		if PassW > EPS:
			out = layered(out, _player_pose("Pass_Charge"), PassW)       # LayeredBoneBlend_2
		# ModifyBone_1, then _7 and _8 (the look): component space, alpha 1
		if not StickRot.is_equal_approx(Quaternion.IDENTITY) or not StickOff.is_zero_approx():
			modify_bone(out, TLRigSkaterPose.STICK, StickRot, StickOff)
		if not LookRot1.is_equal_approx(Quaternion.IDENTITY):
			modify_bone(out, TLRigSkater.BONE_SPINE_03, LookRot1)
		if not LookRot2.is_equal_approx(Quaternion.IDENTITY):
			modify_bone(out, TLRigSkater.BONE_HEAD, LookRot2)
	if _source_ticked and ChargeAlpha > EPS:
		# TwoWayBlend_1's B: SequenceEvaluator_1, Shot_Slap at the explicit time ChargeTime
		var wind: TLRigSkaterPose = TLRigSkater.sample_clip(&"Shot_Slap", ChargeTime)
		out = TLRigSkaterPose.blend2(out, wind, clampf(ChargeAlpha, 0.0, 1.0)) if out != null else wind
	if not live.is_empty():
		# SLOT: the takes at their weights (normalised when they exceed 1), the source last at what is left
		var poses: Array = []
		var ws: PackedFloat32Array = PackedFloat32Array()
		var scale: float = 1.0 / w_total if w_total > 1.0 else 1.0
		for m: Dictionary in live:
			poses.append(TLRigSkater.sample_clip(m["clip"] as StringName, float(m["pos"])))
			ws.append(float(m["w"]) * scale)
		var src: float = 0.0 if w_total > 1.0 else 1.0 - w_total
		if src > EPS and out != null:
			poses.append(out)
			ws.append(src)
		out = TLRigSkaterPose.blend(poses, ws)
	_reap_montages()
	return out if out != null else TLRigSkaterPose.rest()
