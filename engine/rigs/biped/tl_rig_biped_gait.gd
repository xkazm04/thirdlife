class_name TLRigBipedGait
extends RefCounted
## The biped's walking gait (walker-feel, 18 Nov 2026): foot paths and solved legs. State only; `TLRigBiped` owns one,
## steps it once a tick and asks it for the pelvis and leg pose. Nothing here reads a clock or a random function.
## The gait is foot paths; the legs are solved (two bones, exact). A stance foot's anchor (where its ankle stands when the
## boot is flat, in model x and z) moves each tick by exactly minus the body's velocity, so the sole stands still on the
## floor at any speed, direction and acceleration. Cadence (cycles per second), duty (the share of a cycle a foot is down),
## lift, crouch and bounce are keyed by the speed; the stride follows from them (stride = duty x speed / cadence). The
## pelvis rides as high as the style asks and no higher than both legs can reach, so a walk vaults over the standing leg.
## Sidestep and backward: the feet travel along the real direction of `velocity_local`; the pelvis turns 0.6 of the way
## towards it (the chest turns back, so he keeps facing forward); past about 100 degrees he backpedals.
const LEG: float = 0.42          # each leg segment, metres (hip to knee, knee to ankle)
const LEG_MAX: float = 0.832     # the furthest the ankle goes from the hip joint (a locked knee reads as a stick)
const ANKLE_H: float = 0.10      # the ankle above the sole
const _G_V: Array = [0.0, 0.5, 1.0, 1.4, 2.0, 2.6, 3.5, 4.5, 6.0, 9.0, 12.0]            # speed keys, m/s at scale 1
const _G_F: Array = [0.70, 0.75, 1.00, 1.18, 1.45, 1.50, 1.50, 1.52, 1.75, 2.35, 2.70]   # cadence, cycles/s (two steps)
const _G_D: Array = [0.66, 0.66, 0.64, 0.62, 0.56, 0.44, 0.36, 0.30, 0.26, 0.215, 0.18]  # duty: under 0.5 = a flight phase
const _G_H: Array = [0.05, 0.06, 0.08, 0.10, 0.13, 0.20, 0.27, 0.32, 0.36, 0.42, 0.45]   # ankle lift in the swing, m
const _G_DROP: Array = [0.004, 0.004, 0.006, 0.008, 0.02, 0.05, 0.065, 0.075, 0.085, 0.095, 0.10]   # crouch, m
const _G_BOB: Array = [0.0, 0.0, 0.0, 0.0, 0.006, 0.024, 0.032, 0.035, 0.033, 0.028, 0.025]          # run bounce, m
const _G_OFF: Array = [20.0, 25.0, 32.0, 35.0, 38.0, 42.0, 45.0, 48.0, 50.0, 52.0, 52.0]   # heel lift at the end of stance, deg
const _G_HS: Array = [0.0, 8.0, 14.0, 16.0, 16.0, 10.0, 6.0, 4.0, 2.0, 0.0, 0.0]            # toes up at heel strike, deg
const _G_KICK: Array = [0.0, 0.0, 4.0, 6.0, 10.0, 22.0, 32.0, 40.0, 48.0, 58.0, 60.0]      # heel kick behind in the swing, deg

var feet: Array = []             # per foot (0 = left): stance flag, anchor, ankle position, pitch, yaw ... (see reset)
var standing_half_width := 0.115 # hip centre to a planted ankle, in bind metres
var phase: float = 0.0           # the stride phase, in cycles
var psi: float = 0.0             # the pelvis heading against the facing, radians (+ = left)
var back_w: float = 0.0          # 0 = moves forward, 1 = backpedals (eased)
var v: float = 0.0               # this tick's speed (m/s at scale 1), cadence, duty, stride and forwardness
var f: float = 0.7
var d: float = 0.66
var ls: float = 0.0
var fw: float = 1.0
var _backpedal: bool = false
var _yaw_seen: float = NAN       # the rig's yaw in the world at the last tick: a turn leaves standing feet where they are


static func _tab(x: float, ys: Array) -> float:
	if x <= float(_G_V[0]):
		return float(ys[0])
	for i: int in range(1, _G_V.size()):
		if x <= float(_G_V[i]):
			return lerpf(float(ys[i - 1]), float(ys[i]), (x - float(_G_V[i - 1])) / (float(_G_V[i]) - float(_G_V[i - 1])))
	return float(ys[ys.size() - 1])


func reset() -> void:
	feet = []
	for i: int in 2:
		var sx: float = -standing_half_width if i == 0 else standing_half_width
		var yaw: float = deg_to_rad(6.0 if i == 0 else -8.0)
		feet.append({"st": true, "a": Vector2(sx, 0.0), "yaw": yaw, "yaw0": yaw, "u": 0.5 * float(i), "u0": 0.0, "from": Vector3.ZERO, "fp": 0.0,
			"ft0": 0.0, "hs": 0.0, "pos": Vector3(sx, ANKLE_H, 0.0), "pitch": 0.0, "toes": 0.0, "w": 0.0})
	phase = 0.0
	psi = 0.0


## A standing foot is out of place: more than 5 cm from where it belongs, or turned more than 20 degrees (he turned on the spot).
func _foot_off(i: int, half: float) -> bool:
	var ft: Dictionary = feet[i]
	return ((ft["a"] as Vector2) - _foot_centre(i, half)).length() > 0.05 or absf(wrapf(float(ft["yaw"]) - psi, -PI, PI)) > 0.35


func _foot_centre(i: int, half: float) -> Vector2:
	var sx: float = -half if i == 0 else half
	return Vector2(sx * cos(psi), -sx * sin(psi))


## Where the ankle goes when the boot tips by `theta` (radians; + = heel up, turning on the ball; - = toes up, turning on
## the heel) with the turning point left on the floor: the offset from the flat ankle position, for a boot heading `yaw`.
static func _pivot(theta: float, yaw: float) -> Vector3:
	var df: float
	var dy: float
	if theta >= 0.0:
		df = 0.12 * (1.0 - cos(theta)) + 0.07 * sin(theta)      # about the toe joint (3 cm up, 12 cm ahead): the toe piece lies still
		dy = 0.07 * (cos(theta) - 1.0) + 0.12 * sin(theta)
	else:
		df = 0.125 * (cos(theta) - 1.0) + 0.10 * sin(theta)
		dy = 0.10 * (cos(theta) - 1.0) - 0.125 * sin(theta)
	return Vector3(-sin(yaw) * df, dy, -cos(yaw) * df)


## The lowest the ankle may be for a boot tipped by `theta` with the toes bent back up by `toes` (radians): nothing under the floor.
static func _ankle_floor(theta: float, toes: float) -> float:
	if theta >= 0.0:
		return 0.03 + 0.07 * cos(theta) + 0.12 * sin(theta) + 0.115 * sin(maxf(theta - toes, 0.0))
	return 0.10 * cos(theta) - 0.125 * sin(theta)


## A foot that stands: the heel comes down after the strike, and lifts (turning on the toe joint) as the foot falls behind.
func _foot_stance(ft: Dictionary, c: Vector2, that: Vector2, fb: float) -> void:
	var a: Vector2 = ft["a"]
	var behind: float = -(a - c).dot(that)
	var off: float = deg_to_rad(_tab(v, _G_OFF)) * smoothstep(0.06, maxf(0.2, (1.0 - fb) * ls), behind) * maxf(fw, 0.0)
	ft["pitch"] = float(ft["hs"]) + off
	ft["toes"] = maxf(0.0, float(ft["pitch"]))
	ft["pos"] = Vector3(a.x, ANKLE_H, a.y) + _pivot(float(ft["pitch"]), float(ft["yaw"]))


## One tick of the gait: the stance anchors move against the body's velocity, feet lift and land by the phase.
## `vm` = the velocity in model x and z (m/s at scale 1), `cadence_k` = cadence multiplier (1 = shipped), `yaw_world` = the
## rig's yaw in the world (NAN outside the tree).
func step(vm: Vector2, cadence_k: float, yaw_world: float) -> void:
	if feet.is_empty():
		reset()
	v = vm.length()
	var that: Vector2 = vm / v if v > 0.001 else Vector2(-sin(psi), -cos(psi))
	# the body turned since the last tick: a foot on the floor keeps its place and its heading there (it does not spin with him)
	if not is_nan(yaw_world):
		if not is_nan(_yaw_seen):
			var dyaw: float = wrapf(yaw_world - _yaw_seen, -PI, PI)
			if dyaw != 0.0 and absf(dyaw) < 0.6:
				for ft: Dictionary in feet:
					if bool(ft["st"]):
						ft["a"] = (ft["a"] as Vector2).rotated(dyaw)
						ft["yaw"] = float(ft["yaw"]) - dyaw
	_yaw_seen = yaw_world
	var psi_t: float = 0.0
	if v > 0.15:
		var alpha: float = atan2(vm.x, -vm.y)       # 0 = forward, + = to the right
		if absf(alpha) > deg_to_rad(100.0):
			_backpedal = true
		elif absf(alpha) < deg_to_rad(80.0):
			_backpedal = false
		psi_t = -0.6 * (wrapf(alpha - PI, -PI, PI) if _backpedal else alpha) * smoothstep(0.15, 1.0, v)
	else:
		_backpedal = false
	psi = lerpf(psi, psi_t, 0.18)
	back_w = lerpf(back_w, 1.0 if _backpedal else 0.0, 0.18)
	fw = -that.x * sin(psi) - that.y * cos(psi)      # 1 = travels the way the pelvis heads, -1 = against it
	f = _tab(v, _G_F)
	d = _tab(v, _G_D)
	ls = d * v / f
	var fb: float = lerpf(0.5, lerpf(0.44, 0.38, smoothstep(2.0, 3.5, v)), clampf(fw, 0.0, 1.0))   # share of the stride ahead of the hip
	var half: float = lerpf(standing_half_width, 0.09, smoothstep(2.0, 4.0, v)) + 0.05 * (1.0 - fw * fw)
	var still: float = 1.0 - smoothstep(0.1, 0.7, v)
	var settled: bool = v < 0.05
	if settled:
		for i: int in 2:
			if not bool(feet[i]["st"]) or _foot_off(i, half):
				settled = false
	var du: float = 0.0 if settled else (f if v >= 0.3 else maxf(f, 1.15)) * cadence_k * TLRigNode.DT
	phase = fposmod(phase + du, 1.0)
	var hs_t: float = -deg_to_rad(_tab(v, _G_HS)) * fw
	for i: int in 2:
		var ft: Dictionary = feet[i]
		var u: float = fposmod(phase + 0.5 * float(i), 1.0)
		var wrapped: bool = du > 0.0 and u < float(ft["u"])
		var c: Vector2 = _foot_centre(i, half)
		var yaw1: float = psi + deg_to_rad(6.0 if i == 0 else -8.0) * still
		# a foot lands and lifts at its exact phase, part way through a tick (`tau` = the share of this tick after the event):
		# at 9 m/s a tick is 15 cm of floor, and a foot that waits for the tick's end hovers or drags for that long
		if not bool(ft["st"]) and wrapped:
			var tau: float = clampf(u / du, 0.0, 1.0)
			ft["st"] = true
			ft["a"] = c + that * ls * fb
			ft["yaw"] = yaw1
			ft["hs"] = hs_t * pow(0.7, tau)
			ft["a"] = (ft["a"] as Vector2) - vm * TLRigNode.DT * tau
			_foot_stance(ft, c, that, fb)
		elif bool(ft["st"]):
			var lift: bool = u >= d and not wrapped and not settled and (v >= 0.05 or _foot_off(i, half))
			var tau: float = clampf((u - d) / du, 0.0, 1.0) if lift and du > 0.0 else 0.0
			ft["a"] = (ft["a"] as Vector2) - vm * TLRigNode.DT * (1.0 - tau)
			ft["hs"] = float(ft["hs"]) * 0.7
			_foot_stance(ft, c, that, fb)
			if lift:
				ft["st"] = false
				ft["u0"] = u - tau * du
				ft["from"] = ft["pos"]
				ft["fp"] = ft["pitch"]
				ft["ft0"] = ft["toes"]
				ft["yaw0"] = ft["yaw"]
		if not bool(ft["st"]):
			var u0: float = float(ft["u0"])
			var w: float = clampf((u - u0) / maxf(1.0 - u0, 0.05), 0.0, 1.0)
			var a1: Vector2 = c + that * ls * fb
			var p1: Vector3 = Vector3(a1.x, ANKLE_H, a1.y) + _pivot(hs_t, yaw1)
			var p0: Vector3 = ft["from"]
			var chord: float = Vector2(p1.x - p0.x, p1.z - p0.z).length()
			var tsw: float = (1.0 - u0) / f
			# the swing leaves and arrives moving with the floor (the follow-through behind, the paw back before landing)
			var m0: Vector2 = (-vm * tsw * 0.8).limit_length(1.5 * chord + 0.05)
			var m1: Vector2 = (-vm * tsw * 1.0).limit_length(chord + 0.05)
			var w2: float = w * w
			var w3: float = w2 * w
			var xz: Vector2 = Vector2(p0.x, p0.z) * (2.0 * w3 - 3.0 * w2 + 1.0) + m0 * (w3 - 2.0 * w2 + w) + Vector2(p1.x, p1.z) * (-2.0 * w3 + 3.0 * w2) + m1 * (w3 - w2)
			var lift_h: float = _tab(v, _G_H) * clampf(chord / 0.3, 0.35, 1.0) * lerpf(0.6, 1.0, clampf(fw, 0.0, 1.0))
			var kick: float = deg_to_rad(_tab(v, _G_KICK)) * maxf(fw, 0.0)
			ft["pitch"] = float(ft["fp"]) * (1.0 - smoothstep(0.0, 0.5, w)) + kick * pow(sin(PI * clampf(w / 0.7, 0.0, 1.0)), 2.0) + hs_t * smoothstep(0.65, 1.0, w)
			ft["toes"] = float(ft["ft0"]) * (1.0 - smoothstep(0.0, 0.3, w))
			ft["yaw"] = lerp_angle(float(ft["yaw0"]), yaw1, smoothstep(0.0, 1.0, w))
			var y: float = lerpf(p0.y, p1.y, smoothstep(0.0, 1.0, w)) + lift_h * sin(PI * pow(w, 0.9))
			ft["pos"] = Vector3(xz.x, maxf(y, _ankle_floor(float(ft["pitch"]), float(ft["toes"]))), xz.y)
			ft["w"] = w
		ft["u"] = u


## After a jump or a fall: both feet are put down under the body as it faces now, the one ahead first. The yaw seen before
## take-off is forgotten (step() is not called in the air): a turn made in the air must not twist the newly planted feet.
func land(vm: Vector2) -> void:
	if feet.is_empty():
		reset()
	_yaw_seen = NAN
	var sp: float = vm.length()
	var that: Vector2 = vm / sp if sp > 0.001 else Vector2(0.0, -1.0)
	var reach: float = minf(ls, 0.5)
	for i: int in 2:
		var ft: Dictionary = feet[i]
		ft["st"] = true
		ft["a"] = _foot_centre(i, 0.11) + that * reach * (0.3 if i == 0 else -0.2)
		ft["yaw"] = psi
		ft["hs"] = 0.0
		ft["pitch"] = 0.0
		ft["toes"] = 0.0
		ft["pos"] = Vector3((ft["a"] as Vector2).x, ANKLE_H, (ft["a"] as Vector2).y)
		ft["u"] = 0.5 * float(i)
	phase = 0.0


## Two-bone leg. `rp` = the pelvis rotation, `hip` and `ankle` in model space, `foot` = the boot's rotation in model
## space. Returns the euler degrees of the upper leg, the lower leg and the foot.
static func _leg_ik(rp: Basis, hip: Vector3, ankle: Vector3, foot: Basis) -> Array:
	var t: Vector3 = rp.inverse() * (ankle - hip)
	var dist: float = clampf(t.length(), 0.22, 2.0 * LEG * 0.9995)
	var th: Vector3 = t.normalized() if t.length() > 0.0001 else Vector3.DOWN
	var a: float = acos(clampf(dist / (2.0 * LEG), -1.0, 1.0))          # the knee's half angle
	var zu: float = asin(clampf(th.x / maxf(cos(a), 0.05), -1.0, 1.0))
	var xu: float = wrapf(atan2(th.z, th.y) - atan2(sin(a), -cos(a) * cos(zu)), -PI, PI)
	var ru: Basis = Basis.from_euler(Vector3(xu, 0.0, zu))
	var rl: Basis = Basis.from_euler(Vector3(-2.0 * a, 0.0, 0.0))
	var fe: Vector3 = ((rp * ru * rl).inverse() * foot).get_euler()
	return [Vector3(rad_to_deg(xu), 0.0, rad_to_deg(zu)), Vector3(rad_to_deg(-2.0 * a), 0.0, 0.0), Vector3(rad_to_deg(fe.x), rad_to_deg(fe.y), rad_to_deg(fe.z))]


## Pelvis and legs for the feet as they stand now: the pelvis pose (euler degrees), where the style wants its height
## (`y_style`, metres against the rest height) and a side shift; the height is cut to what both legs can reach.
func legs_pose(hips_deg: Vector3, y_style: float, shift: Vector3) -> Dictionary:
	if feet.is_empty():
		reset()
	var rp: Basis = Basis.from_euler(Vector3(deg_to_rad(hips_deg.x), deg_to_rad(hips_deg.y), deg_to_rad(hips_deg.z)))
	var k: float = 0.012
	var acc: float = exp(-y_style / k)
	var joints: Array = []
	for i: int in 2:
		var ft: Dictionary = feet[i]
		var p: Vector3 = ft["pos"]
		var jo: Vector3 = rp * Vector3(-0.11 if i == 0 else 0.11, -0.04, 0.0)
		joints.append(jo)
		var r2: float = Vector2(shift.x + jo.x - p.x, shift.z + jo.z - p.z).length_squared()
		var allowed: float = p.y + sqrt(maxf(LEG_MAX * LEG_MAX - r2, 0.04)) - jo.y - 0.98
		if not bool(ft["st"]):
			var w: float = float(ft["w"])
			allowed += 0.5 * (smoothstep(0.0, 0.15, w) - smoothstep(0.85, 1.0, w))
		acc += exp(-clampf(allowed, -0.6, 0.6) / k)
	var y: float = -k * log(acc)
	var out: Dictionary = {"_hips": Vector3(shift.x, y + shift.y, shift.z), "Hips": hips_deg}
	for i: int in 2:
		var ft: Dictionary = feet[i]
		var side: String = "Left" if i == 0 else "Right"
		var hip: Vector3 = Vector3(shift.x, 0.98 + y + shift.y, shift.z) + (joints[i] as Vector3)
		var lg: Array = _leg_ik(rp, hip, ft["pos"], Basis.from_euler(Vector3(-float(ft["pitch"]), float(ft["yaw"]), 0.0)))
		out[side + "UpperLeg"] = lg[0]
		out[side + "LowerLeg"] = lg[1]
		out[side + "Foot"] = lg[2]
		out[side + "Toes"] = Vector3(rad_to_deg(float(ft["toes"])), 0.0, 0.0)
	return out


## The style's crouch (m under the rest height) and run bounce (m) at this tick's speed.
func crouch() -> float:
	return _tab(v, _G_DROP)


func bounce() -> float:
	return _tab(v, _G_BOB)
