class_name TLRigSkaterBlendSpace
extends RefCounted
## One of thirdjam's three blend spaces (BS_SkaterTB1_P3_Skate, _SkateReady, _Aim) and a player of it, evaluated as
## Unreal 5.9 does (Engine/Private/Animation/BlendSpace.cpp = BS, AnimInterpFilter.cpp = FLT,
## AnimGraphRuntime/.../AnimNode_BlendSpacePlayer.cpp = PL, Core/Public/Math/UnrealMathUtility.h = MU). Internal to
## engine/rigs/skater. The tables are Unreal's own (skater_blendspaces.json, written by tools/skater/blendspace_table.py).
##   - weights: the stored triangulation, barycentric inside the triangle that holds the (clamped, normalised) input
##     (BS:3158-3190; bInterpolateUsingGrid is false, BlendSpace.h:910); weights under 1e-5 dropped, sorted by
##     falling weight, renormalised (BS:1451, :1543-1564). At most three samples.
##   - the input is smoothed per axis by a critically damped spring of the axis' InterpolationTime (FLT:192-297,
##     MU:1741-1750; the default filter BSIT_SpringDamper, damping ratio 1), unsmoothed when the time is 0.
##   - one normalised clock t in 0..1 for all samples: it advances by dt x play rate x sum(w x rate scale / length)
##     and wraps (BS:600, :821-823, :2172-2201); sample i is read at t x its length. The advance comes before the
##     evaluation, so the first tick already shows t1 (PL).
##   - the poses are blended by TLRigSkaterPose.blend in that falling order (BS:1319, :1410).
## DEVIATION: where the input lies within 1e-4 of an edge of the triangulation Unreal's answer depends on the
## triangle it visited last (the weights then differ by up to about 1e-3); here the triangle with the largest
## smallest barycentric weight is taken.

static var _tables: Dictionary = {}

var space: Dictionary
var play_rate: float = 1.0
var t: float = 0.0                 # the normalised clock
var samples: PackedInt32Array = PackedInt32Array()     # the samples of the last update, heaviest first
var weights: PackedFloat32Array = PackedFloat32Array()
var filtered: Vector2 = Vector2.ZERO
var _fx: Array = [0.0, 0.0]        # filter state per axis: value
var _fv: Array = [0.0, 0.0]        # ... and velocity
var _has: Array = [false, false]
var _lens: PackedFloat32Array = PackedFloat32Array()
# the table unpacked once, for the tick (a dictionary read per number was most of a figure's frame)
var _clips: Array = []                                   # StringName per sample
var _rates: PackedFloat64Array = PackedFloat64Array()
var _vx: PackedFloat64Array = PackedFloat64Array()        # the samples' normalised places
var _vy: PackedFloat64Array = PackedFloat64Array()
var _tris: PackedInt32Array = PackedInt32Array()          # three sample indices a triangle
var _lo: Vector2
var _hi: Vector2
var _smooth: Vector2


static func table(sname: String) -> Dictionary:
	if _tables.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://rigs/skater/skater_blendspaces.json"))
		_tables = (d as Dictionary)["spaces"]
	return _tables[sname]


func _init(sname: String, rate: float = 1.0) -> void:
	space = table(sname)
	play_rate = rate
	var ax: Dictionary = space["axes"][0]
	var ay: Dictionary = space["axes"][1]
	_lo = Vector2(float(ax["min"]), float(ay["min"]))
	_hi = Vector2(float(ax["max"]), float(ay["max"]))
	_smooth = Vector2(float(ax["smooth_s"]), float(ay["smooth_s"]))
	for s: Dictionary in space["samples"]:
		var a: Animation = TLRigSkater.clip_library().get_animation(StringName(String(s["clip"])))
		_lens.append(a.length)
		_clips.append(StringName(String(s["clip"])))
		_rates.append(float(s["rate"]))
		var v: Vector2 = _norm(s, ax, ay)
		_vx.append(v.x)
		_vy.append(v.y)
	for tri: Array in space["triangles"]:
		for k: int in range(3):
			_tris.append(int(tri[k]))
	reset()


## FAnimNode_BlendSpacePlayer::Initialize (PL:55-65, :197-219): the clock, the sample cache and the filter start over.
func reset() -> void:
	t = 0.0
	samples = PackedInt32Array()
	weights = PackedFloat32Array()
	_has = [false, false]
	_fx = [0.0, 0.0]
	_fv = [0.0, 0.0]


func _filter(axis: int, target: float, dt: float) -> float:
	var time: float = _smooth[axis]
	if time <= 0.0:
		return target
	if dt <= 1e-4:
		return float(_fx[axis])
	if not bool(_has[axis]):
		_has[axis] = true
		_fx[axis] = target
		_fv[axis] = 0.0
	# FMath::CriticallyDampedSmoothing with SmoothingTime = time / e (FLT:239; MU:1741-1750, the exp approximation MU:1553-1559)
	var w: float = 2.0 * exp(1.0) / time
	var x: float = float(_fx[axis])
	var v: float = float(_fv[axis])
	var err: float = x - target
	var c2: float = v + err * w
	var a: float = w * dt
	var e: float = 1.0 / (1.0 + 1.00746054 * a + 0.45053901 * a * a + 0.25724632 * a * a * a)
	x = target + (err + c2 * dt) * e
	v = (c2 - err * w - c2 * w * dt) * e
	var lo: float = _lo[axis]
	var hi: float = _hi[axis]
	if x > hi:
		x = hi
		v = minf(v, 0.0)
	if x < lo:
		x = lo
		v = maxf(v, 0.0)
	_fx[axis] = x
	_fv[axis] = v
	return x


## The sample weights for an input (already smoothed): BS:2220-2257 (clamp, normalise), :3158-3190, :1451, :1543-1564.
func weigh(x: float, y: float) -> void:
	var px: float = (clampf(x, _lo.x, _hi.x) - _lo.x) / (_hi.x - _lo.x)
	var py: float = (clampf(y, _lo.y, _hi.y) - _lo.y) / (_hi.y - _lo.y)
	var best: float = -INF
	var bi: Array = []
	var bw: Array = []
	for t3: int in range(0, _tris.size(), 3):
		var i0: int = _tris[t3]
		var i1: int = _tris[t3 + 1]
		var i2: int = _tris[t3 + 2]
		var ax_: float = _vx[i0]
		var ay_: float = _vy[i0]
		var bx: float = _vx[i1]
		var by: float = _vy[i1]
		var cx: float = _vx[i2]
		var cy: float = _vy[i2]
		var den: float = (by - cy) * (ax_ - cx) + (cx - bx) * (ay_ - cy)
		if absf(den) < 1e-12:
			continue
		var wa: float = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / den
		var wb: float = ((cy - ay_) * (px - cx) + (ax_ - cx) * (py - cy)) / den
		var wc: float = 1.0 - wa - wb
		var m: float = minf(wa, minf(wb, wc))
		if m > best:
			best = m
			bi = [i0, i1, i2]
			bw = [wa, wb, wc]
	# drop the light ones, sort by falling weight (Unreal's selection sort leaves equal weights in reverse order:
	# Core/Public/Algo/IntroSort.h:63-82), renormalise
	var rows: Array = []
	for k: int in range(bi.size()):
		if float(bw[k]) > 1e-5:
			rows.append([float(bw[k]), int(bi[k])])
	for i: int in range(rows.size() - 1, 0, -1):
		var lightest: int = 0
		for j: int in range(1, i + 1):
			if float(rows[j][0]) < float(rows[lightest][0]):
				lightest = j
		var tmp: Array = rows[lightest]
		rows[lightest] = rows[i]
		rows[i] = tmp
	var total: float = 0.0
	for r: Array in rows:
		total += float(r[0])
	samples = PackedInt32Array()
	weights = PackedFloat32Array()
	for r: Array in rows:
		samples.append(int(r[1]))
		weights.append(float(r[0]) / total if total > 0.0 else 0.0)


static func _norm(s: Dictionary, ax: Dictionary, ay: Dictionary) -> Vector2:
	return Vector2((float(s["x"]) - float(ax["min"])) / (float(ax["max"]) - float(ax["min"])), (float(s["y"]) - float(ay["min"])) / (float(ay["max"]) - float(ay["min"])))


## One tick of the player (FAnimNode_BlendSpacePlayer::UpdateAssetPlayer -> UBlendSpace::TickAssetPlayer, BS:560-960):
## smooth the input, find the samples, advance the clock.
func update(x: float, y: float, dt: float) -> void:
	filtered = Vector2(_filter(0, x, dt), _filter(1, y, dt))
	weigh(filtered.x, filtered.y)
	var delta: float = play_rate * dt
	var speed: float = 0.0
	for k: int in range(samples.size()):
		var i: int = samples[k]
		speed += clampf(weights[k], 0.0, 1.0) * _rates[i] / _lens[i]
	var length: float = 0.0 if speed == 0.0 else 1.0 / speed
	var now: float = t * length + delta
	if now < 0.0 or now > length:
		now = fposmod(now, length) if length != 0.0 else 0.0
	t = now / length if length != 0.0 else 0.0


## The blended pose of the last update.
func evaluate() -> TLRigSkaterPose:
	var poses: Array = []
	for k: int in range(samples.size()):
		var i: int = samples[k]
		poses.append(TLRigSkater.sample_clip(_clips[i] as StringName, clampf(t, 0.0, 1.0) * _lens[i]))
	if poses.is_empty():
		return TLRigSkaterPose.rest()
	var w: PackedFloat32Array = PackedFloat32Array()
	for k: int in range(weights.size()):
		w.append(clampf(weights[k], 0.0, 1.0))
	return TLRigSkaterPose.blend(poses, w)
