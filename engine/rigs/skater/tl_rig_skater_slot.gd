class_name TLRigSkaterSlot
extends RefCounted
## The takes of thirdjam's animation blueprint (its Slot "DefaultSlot" and the dynamic montages played on it by
## PlaySlotAnimationAsDynamicMontage) and Unreal's blend arithmetic, as UE 5.9 runs them at a fixed 1/60 s tick
## ("MON" = Engine/Private/Animation/AnimMontage.cpp / AnimInstance.cpp, AlphaBlend.cpp). The base of TLRigSkaterAnim,
## split from it in round 3 for the size rule. Internal to engine/rigs/skater.

var montages: Array = []             # [{id, clip, clip_len, len, pos, rate, out, trigger, w, begin, target, lerp, rem, T, playing, active, paused}]
var _next_id: int = 0


## A number as Unreal's single-precision float holds it. The blends' counters (time remaining, the lerp, a take's
## position) are floats there, and a blend ends on the tick where "remaining > delta" first fails: at a remaining time
## of exactly one tick that is decided by the last bit. Measured: in double precision a take ended one tick late.
static var _f32: PackedFloat32Array = PackedFloat32Array([0.0])


static func f32(x: float) -> float:
	_f32[0] = x
	return _f32[0]


## One step of FAlphaBlend::Update (Engine/Private/AlphaBlend.cpp:192-230): [lerp, remaining] after `dt`.
## A blend is complete when its VALUE has reached the desired one (FAlphaBlend::IsComplete, :315-324), not when the
## lerp has: in single precision the eased value of a lerp one bit short of 1 is already 1.
static func blend_step(lerp: float, rem: float, dt: float, begin: float = 0.0, target: float = 1.0) -> Array:
	if blend_value(lerp, begin, target) == f32(target):
		return [lerp, rem]
	var d: float = f32(dt)
	if rem > d:
		return [f32(lerp + f32(f32(f32(1.0 - lerp) / rem) * d)), f32(rem - d)]
	return [1.0, 0.0]


## FAlphaBlend's blended value: begin + (desired - begin) x S(lerp), single precision.
static func blend_value(lerp: float, begin: float, target: float) -> float:
	var x: float = f32(clampf(lerp, 0.0, 1.0))
	var e: float = f32(f32(x * x) * f32(3.0 - f32(2.0 * x)))
	return f32(f32(begin) + f32(f32(f32(target) - f32(begin)) * e))


## HermiteCubic (Engine/Private/AlphaBlend.cpp:247; FMath::SmoothStep).
static func scurve(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


# ------------------------------------------------------------------ montages (the Slot's takes)
## UAnimInstance::PlaySlotAnimationAsDynamicMontage (MON AnimInstance.cpp:2870-2945): every running take is told to
## blend out over the NEW take's blend-in time; the new one starts at weight 0.
## `trigger` is the montage's BlendOutTriggerTime: under 0 the take blends out over what is left when no more than
## its blend-out time is left; at 0 or more it blends out over its blend-out time when no more than `trigger` is left
## (AnimMontage.cpp, FAnimMontageInstance::Advance: bCustomBlendOutTriggerTime). `loops` is LoopCount: the montage is
## that many times the clip long (FAnimSegment::GetLength) and its position runs on through them.
## Returns the take's id (0 = no such clip).
func play_slot(clip: StringName, blend_in: float, blend_out: float, rate: float = 1.0, start: float = 0.0, loops: int = 1, trigger: float = -1.0) -> int:
	var a: Animation = TLRigSkater.clip_library().get_animation(clip)
	if a == null:
		return 0
	for i: int in range(montages.size() - 1, -1, -1):
		_stop(montages[i], blend_in)
	_next_id += 1
	montages.append({"id": _next_id, "trigger": trigger, "clip": clip, "clip_len": f32(a.length), "len": f32(f32(a.length) * float(loops)), "pos": f32(clampf(start, 0.0, a.length * float(loops))), "rate": f32(rate), "out": f32(blend_out), "w": 0.0, "begin": 0.0,
		"target": 1.0, "lerp": 0.0 if blend_in > 0.0 else 1.0, "rem": f32(blend_in), "T": f32(blend_in), "playing": true, "active": true, "paused": false})
	if blend_in <= 0.0:
		montages[-1]["w"] = 0.0      # the weight is taken on the next tick (begin 0 -> target 1 at lerp 1)
	return _next_id


## FAnimMontageInstance::Stop (MON AnimMontage.cpp:1558-1661).
func _stop(m: Dictionary, t: float) -> void:
	if float(m["target"]) != 0.0:
		m["begin"] = m["w"]
		m["target"] = 0.0
		m["lerp"] = 0.0
		m["rem"] = f32(t)
		m["T"] = f32(t)
		if t <= 0.0:
			m["w"] = 0.0
			m["lerp"] = 1.0
			m["playing"] = false
		m["active"] = false
	elif t < float(m["T"]):
		m["T"] = t
		m["begin"] = m["w"]
		m["lerp"] = 0.0
		m["rem"] = t


## UAnimInstance::IsAnyMontagePlaying: true while any instance lives, also paused or blending out (AnimInstance.cpp:3725).
func is_any_montage_playing() -> bool:
	return not montages.is_empty()


func _active_montage() -> Dictionary:
	for i: int in range(montages.size() - 1, -1, -1):
		if bool(montages[i]["active"]):
			return montages[i]
	return {}


## GetCurrentActiveMontage is valid (an instance that was not stopped).
func has_active_montage() -> bool:
	return not _active_montage().is_empty()


func montage_position() -> float:
	var m: Dictionary = _active_montage()
	return float(m["pos"]) if not m.is_empty() else 0.0


func montage_set_position(p: float) -> void:
	var m: Dictionary = _active_montage()
	if not m.is_empty():
		m["pos"] = p


func montage_pause() -> void:
	var m: Dictionary = _active_montage()
	if not m.is_empty():
		m["paused"] = true


## UAnimInstance::Montage_Stop(InBlendOutTime, nullptr): every take that was not stopped blends out over `t`.
func montage_stop_all(t: float) -> void:
	for m: Dictionary in montages:
		if bool(m["active"]):
			_stop(m, t)


## Montage_SetPlayRate(nullptr, rate): every take that was not stopped (AnimInstance.cpp, "do it on all active ones").
func montage_set_rate(rate: float) -> void:
	for m: Dictionary in montages:
		if bool(m["active"]):
			m["rate"] = f32(rate)


## GetPlayLength(GetCurrentActiveMontage): the clip's length times its loop count.
func montage_length() -> float:
	var m: Dictionary = _active_montage()
	return float(m["len"]) if not m.is_empty() else 0.0


## Montage_IsPlaying(GetCurrentActiveMontage): false once it is paused or has reached its end.
func montage_active_is_playing() -> bool:
	var m: Dictionary = _active_montage()
	return not m.is_empty() and bool(m["playing"]) and not bool(m["paused"])


## Where a take's clip is read at its position (a looping take wraps through its clip).
static func clip_time(m: Dictionary) -> float:
	var cl: float = float(m["clip_len"])
	var p: float = float(m["pos"])
	return p if p <= cl or cl <= 0.0 else fposmod(p, cl)


func _by_id(id: int) -> Dictionary:
	for m: Dictionary in montages:
		if int(m["id"]) == id and bool(m["active"]):
			return m
	return {}


## Montage_IsPlaying(Montage) of one take: it is the montage's active instance (not stopped: a stop takes it out of
## UAnimInstance::ActiveMontagesMap, FAnimMontageInstance::Stop -> OnMontageInstanceStopped) and it plays.
func montage_is_playing(id: int) -> bool:
	var m: Dictionary = _by_id(id)
	return not m.is_empty() and bool(m["playing"])


## Montage_GetPosition(Montage) of one take: 0 once it is no longer the montage's active instance.
func montage_position_of(id: int) -> float:
	var m: Dictionary = _by_id(id)
	return float(m["pos"]) if not m.is_empty() else 0.0


## Montage_Pause / Montage_Resume / Montage_SetPosition of one take (the dash's).
func montage_pause_id(id: int) -> void:
	var m: Dictionary = _by_id(id)
	if not m.is_empty():
		m["paused"] = true


func montage_resume_id(id: int) -> void:
	var m: Dictionary = _by_id(id)
	if not m.is_empty():
		m["paused"] = false


func montage_set_position_id(id: int, p: float) -> void:
	var m: Dictionary = _by_id(id)
	if not m.is_empty():
		m["pos"] = f32(p)


func _tick_montages(dt: float) -> void:
	for m: Dictionary in montages:
		var st: Array = blend_step(float(m["lerp"]), float(m["rem"]), dt, float(m["begin"]), float(m["target"]))
		m["lerp"] = st[0]
		m["rem"] = st[1]
		m["w"] = blend_value(float(m["lerp"]), float(m["begin"]), float(m["target"]))
	var keep: Array = []
	for m: Dictionary in montages:
		if bool(m["playing"]) and not bool(m["paused"]):
			m["pos"] = f32(float(m["pos"]) + f32(f32(dt) * float(m["rate"])))
			var left: float = f32(f32(float(m["len"]) - float(m["pos"])) / maxf(absf(float(m["rate"])), 1e-6))
			var custom: bool = float(m["trigger"]) >= 0.0
			if float(m["target"]) != 0.0 and left <= maxf(float(m["trigger"]) if custom else float(m["out"]), 1e-4):
				_stop(m, float(m["out"]) if custom else maxf(left, 0.0))
			if float(m["pos"]) >= float(m["len"]):
				m["playing"] = false
				m["pos"] = float(m["len"]) - 5e-5
		m["dead"] = float(m["target"]) == 0.0 and float(m["w"]) == 0.0      # stopped and its blend complete (AnimMontage.cpp:2784)
		keep.append(m)
	montages = keep


## The instances that ended are deleted after the tick's evaluation (UAnimInstance::PostUpdateAnimation).
func _reap_montages() -> void:
	var keep: Array = []
	for m: Dictionary in montages:
		if not bool(m.get("dead", false)):
			keep.append(m)
	montages = keep
