class_name TLRigSkaterWhip
extends TLRigSkaterPuck
## thirdjam's Blueprint BP_SkaterVisual_TB1_P3: the whip (the upper body's snap on a hit: WhipGo, WhipGoS, WhipStr,
## WhipTick), where the rink's walls are (FindRink, WallAt), and the helpers of the falls (degrees, clip pickers).
## From engine/rigs/skater/driver-ref/BP_SkaterVisual_TB1_P3.EventGraph.txt; `[Name]` is the listing's entry.
## Internal to engine/rigs/skater (TLRigSkater's `takes` is the last of the chain Puck <- Whip <- Falls <- Contact).

# ---- the Blueprint's variables (class defaults from the export's defaults.json)
var UpMode: int = 0              # only [SetTestMode] writes it (no caller in thirdjam's C++)
var bWall: bool = false
var RinkHX: float = 0.0
var RinkHY: float = 0.0
var RinkR: float = 0.0
var bWhip: bool = false
var WhipK: float = 0.0
var WhipS: float = 0.0
var WhipDX: float = 0.0
var WhipDY: float = 0.0
var WhipT0: float = 0.0
var WhipHeadW: float = 1.0
var WhipArmW: float = 1.0
var ChkStr: float = 0.0
var ChkStrT: float = 0.0
var bEqAny: bool = false          # the held ability's props (TLRigSkaterToys)
var bSlideFx: bool = false        # the Niagara component SlideFx is active ([KnockDown] L590, L605): the figure draws it
var brake_fx_n: int = 0           # BrakeFx was activated this many times ([StopTick] L1753, L1768) ...
var brake_fx_strength: float = 0.0     # ... the last time with this User.Strength


## [EquipApply]: the props' part is TLRigSkaterToys'.
func EquipApply() -> void:
	pass


static func _len(clip: StringName) -> float:
	return TLRigSkater.clip_library().get_animation(clip).length      # GetPlayLength(Anim)


static func _dcos(deg: float) -> float:
	return cos(deg_to_rad(deg))


static func _dsin(deg: float) -> float:
	return sin(deg_to_rad(deg))


static func _datan2(y: float, x: float) -> float:
	return rad_to_deg(atan2(y, x))


## RLerp(A, B, Alpha, bShortestPath = true) of two yaw-only rotators: the yaw along the shorter arc.
static func _rlerp_yaw(a: float, b: float, alpha: float) -> float:
	return a + wrapf(b - a, -180.0, 180.0) * alpha


# ------------------------------------------------------------------ the whip
## [WhipGo] L1947-1949
func WhipGo(DX: float, DY: float, K: float) -> void:
	WhipK = K
	WhipGoS(DX, DY, K * (ChkStr if absf(f._now - ChkStrT) < 0.02 else 0.6))


## [WhipGoS] L1951-1958
func WhipGoS(DX: float, DY: float, S: float) -> void:
	if S > 0.0 and (not bWhip or S > WhipS):
		var n: float = maxf(sqrt(DX * DX + DY * DY), 0.001)
		WhipDX = DX / n
		WhipDY = DY / n
		WhipS = S
		WhipT0 = f._now
		bWhip = UpMode < 16


## [WhipStr] L1960-1965
func WhipStr(S: float) -> void:
	ChkStr = clampf(S, 0.0, 1.0)
	ChkStrT = f._now
	if bWhip and WhipK > 0.0 and absf(f._now - WhipT0) < 0.02:
		WhipS = WhipK * ChkStr


## [WhipTick] L1967-1980 (from [ReceiveTick] L1277-1278 while bWhip)
func WhipTick() -> void:
	var t: float = f._now - WhipT0
	if t >= 0.3334:
		bWhip = false
		f.anim.WhipA = 0.0
		return
	# RotatorFromAxisAndAngle(InverseTransformDirection(K2_GetComponentToWorld(Mesh), (-WhipDY, WhipDX, 0)), angle)
	var axis_w: Vector3 = Vector3(-WhipDY, WhipDX, 0.0)
	var axis_c: Vector3 = axis_w.rotated(Vector3(0, 0, 1), -deg_to_rad(f.mesh_world_yaw_deg()))
	var c: float = clampf((0.3167 - t) / 0.1167, 0.0, 1.0)
	var env: float = (c * c) * (3.0 - 2.0 * c)
	var osc: float = (WhipS * 2.1137) * (exp(-12.566 * t) * sin(21.766 * t))
	var t2: float = maxf(t - 0.05, 0.0)
	var osc_late: float = (WhipS * 2.1137) * (exp(-12.566 * t2) * sin(21.766 * t2))
	f.anim.WhipRot = TLRigSkaterPose.ue_axis_angle_quat(axis_c, (osc * env) * 15.0)
	f.anim.WhipHead = TLRigSkaterPose.ue_axis_angle_quat(axis_c, (osc * env) * (18.0 * WhipHeadW))
	f.anim.WhipArm = TLRigSkaterPose.ue_axis_angle_quat(axis_c, ((osc_late * env) - (osc * env)) * (5.0 * WhipArmW))
	f.anim.WhipA = 1.0


# ------------------------------------------------------------------ the rink's walls
## [FindRink] L460-476
func FindRink() -> void:
	RinkHX = 0.0
	var r: Vector3 = f.rink_cm()
	if r != Vector3.ZERO:
		RinkHX = r.x
		RinkHY = r.y
		RinkR = r.z      # extent Y / 6, or the ice material's CornerRadiusCm when that is over 1 (f.rink_cm decides)


## [WallAt] L1838-1839: is there a wall 150 cm from the actor along (DX, DY)?
func WallAt(DX: float, DY: float) -> void:
	var loc: Vector2 = f.actor_xy_cm()
	var ax: float = absf(loc.x + DX * 150.0)
	var ay: float = absf(loc.y + DY * 150.0)
	var cx: float = ax - (RinkHX - RinkR)
	var cy: float = ay - (RinkHY - RinkR)
	bWall = ax > RinkHX or ay > RinkHY or (cx > 0.0 and cy > 0.0 and (cx * cx + cy * cy) > RinkR * RinkR)


static func _board_fall_clip(kind: int) -> StringName:
	if kind == 5:
		return &"Board_Fall_Front"
	if kind == 6:
		return &"Board_Fall_Left"
	if kind == 7:
		return &"Board_Fall_Right"
	return &"Board_Fall_Back"


static func _lie_clip(kind: int) -> StringName:
	if kind == 5:
		return &"Lie_Loop_Wall"
	if kind == 6:
		return &"Lie_Loop_Wall_Left"
	if kind == 7:
		return &"Lie_Loop_Wall_Right"
	if kind == 8:
		return &"Lie_Loop_Wall_Back"
	if kind == 1:
		return &"Lie_Loop_Side_Left"
	if kind == 2 or kind == 4:
		return &"Lie_Loop_Side_Right"
	if kind == 3:
		return &"Lie_Loop_Front"
	return &"Lie_Loop"
