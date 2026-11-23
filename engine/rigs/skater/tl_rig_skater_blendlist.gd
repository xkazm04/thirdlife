class_name TLRigSkaterBlendList
extends RefCounted
## FAnimNode_BlendListBase with two children (BLB:108-265): child 0 is the `true` pose.
var w: Array = [0.0, 0.0]
var begin: Array = [0.0, 0.0]
var target: Array = [0.0, 0.0]
var lerp: Array = [1.0, 1.0]
var rem: Array = [0.0, 0.0]
var last: int = -1
var times: Array = [0.1, 0.1]

func _init(t0: float, t1: float) -> void:
	times = [t0, t1]

func reset() -> void:
	w = [0.0, 0.0]
	last = -1

func update(b: bool, dt: float) -> void:
	var idx: int = 0 if b else 1
	if idx != last:
		var t: float = 0.0 if last == -1 else float(times[idx]) * clampf(absf(1.0 - float(w[idx])), 0.0, 1.0)
		for i: int in range(2):
			begin[i] = w[i]
			target[i] = 1.0 if i == idx else 0.0
			lerp[i] = 1.0 if (float(begin[i]) == float(target[i]) or t <= 0.0) else 0.0
			rem[i] = TLRigSkaterAnim.f32(t)
		last = idx
	var total: float = 0.0
	for i: int in range(2):
		var st: Array = TLRigSkaterAnim.blend_step(float(lerp[i]), float(rem[i]), dt, float(begin[i]), float(target[i]))
		lerp[i] = st[0]
		rem[i] = st[1]
		w[i] = TLRigSkaterAnim.blend_value(float(lerp[i]), float(begin[i]), float(target[i]))
		total += float(w[i])
	if absf(total - 1.0) > 1e-5 and total > 0.0:
		w[0] = float(w[0]) / total
		w[1] = float(w[1]) / total
