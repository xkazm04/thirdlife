extends RefCounted
## thirdjam's follow camera, ported line by line (K3 shell, campaign night 23-24 Nov 2026). Not tuned, not improved.
## Source: thirdjam HEAD 8dc713c6, S = Game/Source. `cpp:N` = S/JamGame/Private/CameraFollow.cpp line N,
## `h:N` = S/JamGame/Public/CameraFollow.h line N. Everything is in thirdjam's own units and frame: rink metres,
## x along the rink, y across (the Godot mapping is the caller's: Vector3(x, height, y)), yaw and pitch in degrees
## (yaw 0 = +x, turning towards +y; pitch < 0 looks down). One call of `step` = one simulation frame (h:254-264).
##
## What is ported: StepThirdPerson (cpp:266-599) as the shipped game runs it (StepSimFrame cpp:1210-1253 with the
## console variables' defaults cpp:39-78: Boards 1, RigYaw 1, KeepHuman 0.31, CornerLift 3, KeepYaw 0, Bound 0), with
## FJamSpring (cpp:80-100), FJamCameraFilter (cpp:102-125), the boards' inset (cpp:181-233), FarNetLeadDeg (cpp:250-264),
## RayToBoards (cpp:601-611), BoardsViewTarget (cpp:613-668), FrameFraction (cpp:978-985).
## Not ported (DEVIATIONS in the lane report): KeepHumanInFrame (cpp:670-873) and the A186 bound (cpp:406-490): with
## the boards view on, StepThirdPerson zeroes KeepHuman and CornerLift itself (cpp:269-275) and jam.camera.Bound is 0,
## so neither runs in the shipped game; `settings()` refuses a setting that would turn one on. The punch and the kick
## (cpp:1257-1287) belong to stair step 3 (contact). Box follow (cpp:1231-1249) needs penalties: not in the gym.


class Spring:
	## FJamSpring (h:256-264, cpp:80-100): critically damped, stepped once per sim frame, exact over one frame.
	var x: float = 0.0
	var v: float = 0.0
	var init: bool = false

	func reset(value: float) -> void:            # cpp:80-85
		x = value
		v = 0.0
		init = true

	func step(target: float, omega: float) -> void:   # cpp:87-100
		if not init or omega <= 0.0:
			reset(target)
			return
		var e: float = exp(-omega)
		var j0: float = x - target
		var j1: float = v + omega * j0
		x = target + (j0 + j1) * e
		v = (v - j1 * omega) * e


## FJamCameraSettings (h:19-252) as the shipped game's StepSimFrame fills `Live` (cpp:1210-1230). The cartridge's
## game.camera supplies distance, height, look-ahead, lag, fov (FromCartridge cpp:21-34); absent keys keep the
## FJamCameraConfig defaults (S/JamCore/Public/JamCartridge.h:650-661).
static func settings(cart_cam: Dictionary) -> Dictionary:
	var c: Dictionary = {
		"DistanceM": 6.0, "HeightM": 3.5, "LookAheadM": 5.0, "FovDeg": 70.0, "LagFrames": 4,   # h:28-42, JamCartridge.h:651-655
		"OffAxisM": 0.7,                          # h:46 ("Off-axis stays 0.7 m", h:250)
		"BoardsMarginM": 0.8, "EndHeightM": 3.0, "FarNetBias": 0.2,   # JamCartridge.h:658-661
		"MiddleThirdYawDeg": 12.0, "MiddleThirdPitchDeg": 6.5, "ChestM": 1.0,   # h:64-70
		"KeepYawDeg": 0.0,                        # cpp:77 jam.camera.KeepYaw default 0 (cpp:1211)
		"CornerLiftM": 3.0,                       # cpp:39 jam.camera.CornerLift 3 (cpp:1212); zeroed by the boards view (cpp:269-275)
		"CornerNearM": 5.0, "CornerFullM": 2.0, "CornerLookAheadKeep": 0.2,   # h:97-103
		"KeepHumanFrac": 0.31,                    # cpp:42 jam.camera.KeepHuman 0.31 (cpp:1213); zeroed by the boards view
		"KeepAspect": 16.0 / 9.0,                 # h:128; main.gd sets the window's each frame (ctx.cameras.aspect, 1.17) as StepSimFrame does (cpp:1226-1230)
		"BoundPx": 0.0,                           # cpp:62 jam.camera.Bound 0 (cpp:1220)
		"bRigYaw": true,                          # cpp:64 jam.camera.RigYaw 1 (cpp:1221)
		"BoardsView": 1.0,                        # cpp:71 jam.camera.Boards 1 (cpp:1222)
		"BoardsGateM": 8.0, "BoardsGateFullM": 4.0, "BoardsNearM": 6.0, "BoardsFullM": 1.0, "BoardsSlideM": 3.0,   # h:236-240
		"BoardsViewMarginM": 0.4,                 # h:241
		"BoardsMinHeightM": 2.0,                  # cpp:73 jam.camera.BoardsMinHeight 2 clamped to [1.5, HeightM] (cpp:1223)
		"BoardsShortArmM": 4.0, "BoardsHeadM": 1.8, "BoardsPitchCapDeg": 55.0, "BoardsIceTopFrac": 0.45, "BoardsKeepFrac": 0.85,   # h:243-247
		"BoardsSpringFrames": 0.0,                # h:248
		"SpringFrames": 8.0, "LiftLookAheadGain": 1.5, "FarNetBiasNearM": 8.0, "FarNetBiasFarM": 20.0,   # h:193-202
	}
	var keymap: Dictionary = {"distance_m": "DistanceM", "height_m": "HeightM", "look_ahead_m": "LookAheadM", "lag_frames": "LagFrames",
		"fov_deg": "FovDeg", "boards_margin_m": "BoardsMarginM", "end_height_m": "EndHeightM", "far_net_bias": "FarNetBias"}
	for k: String in keymap:
		if cart_cam.has(k):
			c[keymap[k]] = int(cart_cam[k]) if k == "lag_frames" else float(cart_cam[k])
	c["BoardsMinHeightM"] = clampf(float(c["BoardsMinHeightM"]), 1.5, float(c["HeightM"]))   # cpp:1223
	if float(c["BoardsView"]) <= 0.0 or float(c["BoundPx"]) > 0.0 or float(c["KeepYawDeg"]) > 0.0 or not bool(c["bRigYaw"]):
		push_error("hokej cam: a setting that turns on a stage this port leaves out (KeepHumanInFrame, the bound, KeepYaw, the yaw budget)")
	return c


# FJamCameraFilter (h:267-320): the lag filter and every spring, one value per camera.
var pivot: Vector2 = Vector2.ZERO
var yaw_deg: float = 0.0
var init: bool = false
var lift: Spring = Spring.new()
var yaw_offset: Spring = Spring.new()
var pitch_spring: Spring = Spring.new()
var corner: Spring = Spring.new()
var rig_lead: Spring = Spring.new()
var boards_corr: Array = [Spring.new(), Spring.new(), Spring.new(), Spring.new()]
var last_clamp_s: float = 0.0
var last_clamp_n: Vector2 = Vector2.ZERO
var last_boards_weight: float = 0.0
var boards_last_foot: Vector2 = Vector2.ZERO
var boards_last_rig: Vector2 = Vector2.ZERO
var boards_last: bool = false
var last_yaw_rig: float = 0.0
var last_yaw_out: float = 0.0
## The pose of the last step: the camera's point on the ice, its height, pitch and yaw (UJamFollowCamera::PoseCurrent).
var pose: Dictionary = {}

var C: Dictionary


func _init(cfg: Dictionary) -> void:
	C = cfg


static func unwind(a: float) -> float:   # FMath::UnwindDegrees
	while a > 180.0:
		a -= 360.0
	while a < -180.0:
		a += 360.0
	return a


static func alpha_for_lag(lag: int) -> float:   # cpp:102-105
	return 1.0 if lag <= 0 else 1.0 - exp(-1.0 / float(lag))


func filter_reset(target: Vector2, target_yaw: float) -> void:   # cpp:107-112
	pivot = target
	yaw_deg = target_yaw
	init = true


func filter_step(target: Vector2, target_yaw: float, lag: int) -> void:   # cpp:114-125
	if not init:
		filter_reset(target, target_yaw)
		return
	var a: float = alpha_for_lag(lag)
	pivot += (target - pivot) * a
	yaw_deg += unwind(target_yaw - yaw_deg) * a
	yaw_deg = unwind(yaw_deg)


static func derived_pitch(c: Dictionary) -> float:   # cpp:167-170
	return -rad_to_deg(atan(float(c["HeightM"]) / (float(c["DistanceM"]) + float(c["LookAheadM"]))))


# ---- the boards' inset region (cpp:181-233); rink = {"L", "W", "R"} (FJamCameraRink, h:323-330)

static func _inset(rink: Dictionary, margin: float) -> Array:   # cpp:184-195
	var hx: float = maxf(0.0, float(rink["L"]) * 0.5 - margin)
	var hy: float = maxf(0.0, float(rink["W"]) * 0.5 - margin)
	var r: float = clampf(float(rink["R"]) - margin, 0.0, minf(hx, hy))
	return [hx, hy, r]


static func _in_corner_square(p: Vector2, i: Array) -> bool:
	return i[2] > 0.0 and absf(p.x) > i[0] - i[2] and absf(p.y) > i[1] - i[2]


static func _corner_centre(p: Vector2, i: Array) -> Vector2:
	return Vector2(signf(p.x) * (i[0] - i[2]), signf(p.y) * (i[1] - i[2]))


static func is_inside(p: Vector2, rink: Dictionary, margin: float) -> bool:   # cpp:198-206
	var i: Array = _inset(rink, margin)
	if absf(p.x) > i[0] or absf(p.y) > i[1]:
		return false
	return not _in_corner_square(p, i) or p.distance_squared_to(_corner_centre(p, i)) <= i[2] * i[2] + 1e-9


static func nearest_inside(p: Vector2, rink: Dictionary, margin: float) -> Vector2:   # cpp:208-223
	var i: Array = _inset(rink, margin)
	var q: Vector2 = Vector2(clampf(p.x, -i[0], i[0]), clampf(p.y, -i[1], i[1]))
	if _in_corner_square(q, i):
		var k: Vector2 = _corner_centre(q, i)
		var d: Vector2 = q - k
		var ln: float = d.length()
		if ln > i[2] and ln > 1e-9:
			q = k + d * (i[2] / ln)
	return q


## Returns [the point, s (displacement over the arm, 0..1), its unit direction] (cpp:225-233).
static func clamp_to_boards(want: Vector2, rink: Dictionary, margin: float, arm: float) -> Array:
	var p: Vector2 = nearest_inside(want, rink, margin)
	var d: Vector2 = p - want
	var ln: float = d.length()
	var s: float = clampf(ln / arm, 0.0, 1.0) if arm > 1e-6 else 0.0
	var n: Vector2 = d / ln if ln > 1e-9 else Vector2.ZERO
	return [p, s, n]


static func far_net_lead(c: Dictionary, pv: Vector2, yaw: float, net: Vector2) -> float:   # cpp:250-264
	var to_net: Vector2 = net - pv
	var dist: float = to_net.length()
	if dist < 1e-3 or float(c["FarNetBias"]) <= 0.0:
		return 0.0
	var yaw_to_net: float = rad_to_deg(atan2(to_net.y, to_net.x))
	var delta: float = unwind(yaw_to_net - yaw)
	var y: float = deg_to_rad(yaw)
	var toward: float = clampf((cos(y) * to_net.x + sin(y) * to_net.y) / dist, 0.0, 1.0)
	var band: float = clampf((dist - float(c["FarNetBiasNearM"])) / maxf(float(c["FarNetBiasFarM"]) - float(c["FarNetBiasNearM"]), 1e-3), 0.0, 1.0)
	return float(c["FarNetBias"]) * toward * band * delta


static func ray_to_boards(p: Vector2, yaw: float, rink: Dictionary, max_m: float = 200.0) -> float:   # cpp:601-611
	if not is_inside(p, rink, 0.0):
		return 0.0
	var y: float = deg_to_rad(yaw)
	var dir: Vector2 = Vector2(cos(y), sin(y))
	if is_inside(p + dir * max_m, rink, 0.0):
		return max_m
	var lo: float = 0.0
	var hi: float = max_m
	for i: int in 24:
		var mid: float = 0.5 * (lo + hi)
		if is_inside(p + dir * mid, rink, 0.0):
			lo = mid
		else:
			hi = mid
	return lo


static func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## BoardsViewTarget (cpp:613-668): [foot, height, pitch, weight] for the pivot P and the rig's yaw.
static func boards_view_target(c: Dictionary, rink: Dictionary, p: Vector2, yaw: float) -> Array:
	var y: float = deg_to_rad(yaw)
	var fwd: Vector2 = Vector2(cos(y), sin(y))
	var right: Vector2 = Vector2(-sin(y), cos(y))
	var hx: float = float(rink["L"]) * 0.5
	var hy: float = float(rink["W"]) * 0.5
	var dist: Array = [hx - p.x, hx + p.x, hy - p.y, hy + p.y]                    # cpp:621
	var outs: Array = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]   # cpp:622
	var into: Vector2 = Vector2.ZERO
	var dmin: float = 1e9
	for i: int in 4:                                                             # cpp:625-629
		into -= (outs[i] as Vector2) * _smooth((float(c["BoardsNearM"]) - float(dist[i])) / maxf(float(c["BoardsNearM"]) - float(c["BoardsFullM"]), 0.1))
		dmin = minf(dmin, float(dist[i]))
	if into.length() > 1.0:                                                      # cpp:630
		into /= into.length()
	var weight: float = _smooth((float(c["BoardsGateM"]) - dmin) / maxf(float(c["BoardsGateM"]) - float(c["BoardsGateFullM"]), 0.1))   # cpp:631
	var slide: float = float(c["BoardsSlideM"]) * into.dot(right)               # cpp:633
	var want: Vector2 = p - fwd * float(c["DistanceM"]) + right * (float(c["OffAxisM"]) + slide)   # cpp:634
	var foot: Vector2 = want                                                     # cpp:637-644
	var vm: float = float(c["BoardsViewMarginM"])
	if not is_inside(want, rink, vm):
		var o: Vector2 = nearest_inside(p, rink, vm)
		var lo: float = 0.0
		var hi: float = 1.0
		for i: int in 20:
			var mid: float = 0.5 * (lo + hi)
			if is_inside(o + (want - o) * mid, rink, vm):
				lo = mid
			else:
				hi = mid
		foot = o + (want - o) * lo
	var rho: float = (p - foot).dot(fwd)                                         # cpp:646
	var t: float = clampf(rho / maxf(float(c["BoardsShortArmM"]), 0.1), 0.0, 1.0)
	var hc: float = float(c["HeightM"])
	var h: float = minf(hc, float(c["BoardsMinHeightM"]) + (hc - float(c["BoardsMinHeightM"])) * t)   # cpp:648
	var zs: float = float(c["ChestM"]) + (float(c["BoardsHeadM"]) - float(c["ChestM"])) * (1.0 - t)
	var tan_v: float = tan(deg_to_rad(clampf(float(c["FovDeg"]), 1.0, 179.0) * 0.5)) / maxf(float(c["KeepAspect"]), 0.1)   # cpp:652
	var ahead: float = ray_to_boards(foot, yaw, rink)
	var down_rig: float = rad_to_deg(atan(h / maxf(rho + float(c["LookAheadM"]), 1e-3)))
	var down_ice: float = rad_to_deg(atan(h / maxf(ahead, 1e-3)) + atan(float(c["BoardsIceTopFrac"]) * tan_v))
	var to_him: float = rad_to_deg(atan2(h - zs, maxf(rho, 0.05)))               # cpp:658
	var to_blade: float = rad_to_deg(atan2(h - 0.05, maxf(rho + 0.9, 0.05)))
	var edge: float = rad_to_deg(atan(float(c["BoardsKeepFrac"]) * tan_v))
	var lo2: float = maxf(to_him, to_blade) - edge
	var hi2: float = minf(to_him, to_blade) + edge
	var down: float = maxf(down_rig, down_ice)                                    # cpp:662-664
	down = clampf(down, lo2, hi2) if lo2 <= hi2 else 0.5 * (lo2 + hi2)
	down = minf(down, float(c["BoardsPitchCapDeg"]))
	return [foot, h, -down, weight]


## FrameFraction (cpp:978-985): where a world point (metres, z up) lands in the frame of a pose: x, y in [-1, 1].
static func frame_fraction(pos: Vector2, height: float, pitch: float, yaw: float, hfov: float, aspect: float, world: Vector3) -> Vector2:
	# FTransform(FRotator(pitch, yaw, 0)).InverseTransformPositionNoScale in centimetres (UE's rotation matrix, roll 0)
	var sp: float = sin(deg_to_rad(pitch))
	var cp: float = cos(deg_to_rad(pitch))
	var sy: float = sin(deg_to_rad(yaw))
	var cy: float = cos(deg_to_rad(yaw))
	var d: Vector3 = (world - Vector3(pos.x, pos.y, height)) * 100.0
	var lx: float = d.x * cp * cy + d.y * cp * sy + d.z * sp
	var ly: float = -d.x * sy + d.y * cy
	var lz: float = -d.x * sp * cy - d.y * sp * sy + d.z * cp
	if lx <= 1e-3:
		return Vector2(9.0 if ly >= 0.0 else -9.0, 9.0 if lz >= 0.0 else -9.0)
	var tan_h: float = tan(deg_to_rad(clampf(hfov, 1.0, 179.0) * 0.5))
	var tan_v: float = tan_h / maxf(aspect, 0.1)
	return Vector2((ly / lx) / tan_h, (lz / lx) / tan_v)


func _desired(yaw_cam: float) -> Vector2:   # cpp:290-295
	var y: float = deg_to_rad(yaw_cam)
	var fwd: Vector2 = Vector2(cos(y), sin(y))
	var right: Vector2 = Vector2(-sin(y), cos(y))
	return pivot - fwd * float(C["DistanceM"]) + right * float(C["OffAxisM"])


## One simulation frame of StepThirdPerson (cpp:266-599). `frame`: {"pos": Vector2 (the human, rink metres),
## "yaw": degrees (FMath::RadiansToDegrees(S.Yaw), HokejGameMode.cpp:1563), "rink": {"L","W","R"},
## "net": Vector2 (GetFarNetWorldCm / 100, HUDFeed.cpp:8-12)}. Returns the pose {"pos", "height", "pitch", "yaw"}.
func step(frame: Dictionary) -> Dictionary:
	var c: Dictionary = C
	if float(c["BoardsView"]) > 0.0 and (float(c["CornerLiftM"]) > 0.0 or float(c["KeepHumanFrac"]) > 0.0):   # cpp:269-275
		c = c.duplicate()
		c["CornerLiftM"] = 0.0
		c["KeepHumanFrac"] = 0.0
	var s_pos: Vector2 = frame["pos"]
	var s_yaw: float = float(frame["yaw"])
	var rink: Dictionary = frame["rink"]
	if init and s_pos.distance_to(pivot) > 5.0:                                   # cpp:279: a teleport snaps the filter
		filter_reset(s_pos, s_yaw)
		yaw_offset.init = false
		lift.init = false
		pitch_spring.init = false
		corner.init = false
		rig_lead.init = false
		for b: Spring in boards_corr:
			b.init = false
		boards_last = false
	filter_step(s_pos, s_yaw, int(c["LagFrames"]))                               # cpp:280
	var net: Vector2 = frame["net"]
	var lead: float = far_net_lead(c, pivot, yaw_deg, net)                       # cpp:283
	if not yaw_offset.init:
		yaw_offset.reset(lead)
	if not rig_lead.init:
		rig_lead.reset(lead)
	if not lift.init:
		lift.reset(0.0)
	var omega: float = 1.0 / float(c["SpringFrames"]) if float(c["SpringFrames"]) > 0.0 else 0.0   # cpp:287

	# 1. targets from the arm as it stands (cpp:297-311); with bRigYaw the boards never turn the camera
	var r0: Array = clamp_to_boards(_desired(unwind(yaw_deg + yaw_offset.x)), rink, float(c["BoardsMarginM"]), float(c["DistanceM"]))
	var offset_target: float = lead
	if not bool(c["bRigYaw"]):
		push_error("hokej cam: bRigYaw off is not ported")
	yaw_offset.step(offset_target, omega)                                        # cpp:342
	rig_lead.step(lead, omega)                                                   # cpp:343

	# 2. the arm with the new yaw, and the boards' answer (cpp:346-348)
	var yaw_cam: float = unwind(yaw_deg + yaw_offset.x)
	var want: Vector2 = _desired(yaw_cam)
	var r2: Array = clamp_to_boards(want, rink, float(c["BoardsMarginM"]), float(c["DistanceM"]))
	var p: Vector2 = r2[0]
	last_clamp_s = r2[1]
	last_clamp_n = r2[2]

	# 3. lift and tilt (cpp:351-365)
	lift.step(last_clamp_s, omega)
	var lift_v: float = clampf(lift.x, 0.0, 1.0)
	var corner_target: float = 0.0                                               # CornerLiftM is 0 here (cpp:269-275)
	if not corner.init:
		corner.reset(corner_target)
	corner.step(corner_target, omega * 0.5)
	var corner_v: float = 0.0
	var height: float = float(c["HeightM"]) + (maxf(float(c["EndHeightM"]), float(c["HeightM"])) - float(c["HeightM"])) * lift_v + float(c["CornerLiftM"]) * corner_v
	var yr: float = deg_to_rad(yaw_cam)
	var fwd_cam: Vector2 = Vector2(cos(yr), sin(yr))
	var arm: float = maxf(0.0, (pivot.x - p.x) * fwd_cam.x + (pivot.y - p.y) * fwd_cam.y)
	var extra: float = float(c["LiftLookAheadGain"]) * lift_v * float(c["DistanceM"])
	var look_ahead: float = float(c["LookAheadM"]) * (1.0 - (1.0 - clampf(float(c["CornerLookAheadKeep"]), 0.0, 1.0)) * corner_v)
	var pitch: float = -rad_to_deg(atan2(height, maxf(arm + look_ahead + extra, 1e-3)))

	# 4. the pitch within the middle third of the chest's bearing, through a spring (cpp:370-381)
	var flat: float = (pivot - p).length()
	if flat > 1.0:
		var chest_pitch: float = -rad_to_deg(atan2(height - float(c["ChestM"]), flat))
		pitch = chest_pitch + clampf(pitch - chest_pitch, -float(c["MiddleThirdPitchDeg"]), float(c["MiddleThirdPitchDeg"]))
	if not pitch_spring.init:
		pitch_spring.reset(pitch)
	pitch_spring.step(pitch, omega)
	pitch = pitch_spring.x

	# 5. KeepHumanInFrame: off here (cpp:386-396, KeepHumanFrac zeroed above). 6. the bound: jam.camera.Bound 0 (cpp:406-491).
	var pos_m: Vector2 = p
	var height_m: float = height
	var yaw_out: float = yaw_cam

	# 7. the boards view (cpp:496-594)
	if float(c["BoardsView"]) > 0.0:
		var yaw_rig: float = unwind(yaw_deg + rig_lead.x)
		var rig_foot: Vector2 = _desired(yaw_rig)
		var rig_pitch: float = derived_pitch(c)
		var t: Array = boards_view_target(c, rink, pivot, yaw_rig)
		var wt: float = t[3]
		var bwant: Array = [wt * ((t[0] as Vector2).x - rig_foot.x), wt * ((t[0] as Vector2).y - rig_foot.y), wt * (float(t[1]) - float(c["HeightM"])), wt * (float(t[2]) - rig_pitch)]
		var om_b: float = 1.0 / float(c["BoardsSpringFrames"]) if float(c["BoardsSpringFrames"]) > 0.0 else 0.0
		var none: bool = true
		for i: int in 4:                                                         # cpp:507-523
			var sp: Spring = boards_corr[i]
			if not sp.init:
				sp.reset(bwant[i])
			elif om_b > 0.0:
				sp.step(bwant[i], om_b)
			else:
				var max_step: float = 0.25 if i < 2 else (0.05 if i == 2 else 5.0)
				var was: float = sp.x
				sp.x = was + clampf(float(bwant[i]) - was, -max_step, max_step)
				sp.v = sp.x - was
			if float(bwant[i]) == 0.0 and absf(sp.x) < 1e-4 and absf(sp.v) < 1e-4:
				sp.reset(0.0)
			none = none and sp.x == 0.0
		if om_b <= 0.0 and (boards_corr[0] as Spring).init:                       # cpp:526-562: the guard
			var now: Array = [(boards_corr[0] as Spring).x, (boards_corr[1] as Spring).x, (boards_corr[2] as Spring).x, (boards_corr[3] as Spring).x]
			if not _sees(c, rink, rig_foot, rig_pitch, yaw_rig, s_pos, now) and _sees(c, rink, rig_foot, rig_pitch, yaw_rig, s_pos, bwant):
				var lo: float = 0.0
				var hi: float = 1.0
				var cr: Array = [0.0, 0.0, 0.0, 0.0]
				for n: int in 12:
					var mid: float = 0.5 * (lo + hi)
					for i: int in 4:
						cr[i] = float(now[i]) + (float(bwant[i]) - float(now[i])) * mid
					if _sees(c, rink, rig_foot, rig_pitch, yaw_rig, s_pos, cr):
						hi = mid
					else:
						lo = mid
				var gx: float = (float(bwant[0]) - float(now[0])) * hi
				var gy: float = (float(bwant[1]) - float(now[1])) * hi
				var glen: float = sqrt(gx * gx + gy * gy)
				var gk: float = 0.6 / glen if glen > 0.6 else 1.0
				for i: int in 4:
					var bi: Spring = boards_corr[i]
					bi.x = float(now[i]) + (float(bwant[i]) - float(now[i])) * hi * (gk if i < 2 else 1.0)
				var b2: Spring = boards_corr[2]
				var b3: Spring = boards_corr[3]
				b2.x = float(now[2]) + clampf(b2.x - float(now[2]), -0.05, 0.05)
				b3.x = float(now[3]) + clampf(b3.x - float(now[3]), -2.5, 2.5)
				none = false
		last_boards_weight = wt
		yaw_out = yaw_rig
		if none:                                                                 # cpp:565-570
			pos_m = rig_foot
			height_m = float(c["HeightM"])
			pitch = rig_pitch
		else:                                                                    # cpp:571-589
			var vm: float = float(c["BoardsViewMarginM"])
			var c0: Spring = boards_corr[0]
			var c1: Spring = boards_corr[1]
			pos_m = nearest_inside(Vector2(rig_foot.x + c0.x, rig_foot.y + c1.x), rink, vm)
			if boards_last:
				var stp: Vector2 = pos_m - boards_last_foot
				var cap: float = maxf(0.99, rig_foot.distance_to(boards_last_rig))
				if stp.length() > cap:
					pos_m = nearest_inside(boards_last_foot + stp * (cap / stp.length()), rink, vm)
					c0.x = pos_m.x - rig_foot.x
					c1.x = pos_m.y - rig_foot.y
			height_m = float(c["HeightM"]) + (boards_corr[2] as Spring).x
			pitch = clampf(rig_pitch + (boards_corr[3] as Spring).x, -89.0, 89.0)
		boards_last_foot = pos_m
		boards_last_rig = rig_foot
		boards_last = true
	else:
		last_boards_weight = 0.0
		boards_last = false
	last_yaw_rig = yaw_cam                                                       # cpp:595-597
	last_yaw_out = yaw_out
	pose = {"pos": pos_m, "height": height_m, "pitch": pitch, "yaw": yaw_out}
	return pose


## The guard's test (cpp:528-542): with the correction `cr`, is his chest, head or skates (1, 1.8, 0.2 m) inside 0.95 of the frame?
func _sees(c: Dictionary, rink: Dictionary, rig_foot: Vector2, rig_pitch: float, yaw_rig: float, s_pos: Vector2, cr: Array) -> bool:
	var f: Vector2 = nearest_inside(Vector2(rig_foot.x + float(cr[0]), rig_foot.y + float(cr[1])), rink, float(c["BoardsViewMarginM"]))
	var pitch: float = clampf(rig_pitch + float(cr[3]), -89.0, 89.0)
	var h: float = float(c["HeightM"]) + float(cr[2])
	for z: float in [1.0, 1.8, 0.2]:
		var fr: Vector2 = frame_fraction(f, h, pitch, yaw_rig, float(c["FovDeg"]), float(c["KeepAspect"]), Vector3(s_pos.x, s_pos.y, z))
		if absf(fr.x) <= 0.95 and absf(fr.y) <= 0.95:
			return true
	return false
