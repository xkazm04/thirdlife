extends RefCounted
## thirdjam's key and mouse mapping, ported (K3 shell). S = thirdjam HEAD 8dc713c6 Game/Source.
##   keys     FJamBindings::Defaults (S/JamGame/Private/InputMapping.cpp:98-119): W/Up forward, S/Down back, A/Left, D/Right,
##            LeftShift sprint, LeftControl brake (the rest are verbs of later steps: shoot, pass, check, poke, deke, spin, ability).
##   axis     UJamPlayerInput::OnMove (InputMapping.cpp:950-958): the keys' 2D value with each axis clamped to [-1, 1]
##            (W + D is (1, 1); the sim clamps the move's length to 1, JamSim.h:31-34).
##   move     AHokejGameMode::ReadHumanInput (S/JamGame/Private/HokejGameMode.cpp:937-958): camera-relative (W = away from the
##            camera); while the axis pulls back (y < -0.3) the move is read in the camera's yaw of the moment the pull began.
##   aim      AHokejGameMode::CursorAimFromHit (HokejGameMode.cpp:756-767): the cursor's point on the ice; inside 0.7 m of
##            the skater (0.5 m once aiming: hysteresis) the stick is zero (the blade held ahead); else it points from the
##            skater to the point with a size 0.5 + 0.5 * clamp((d - 0.5) / 2.5, 0, 1).

var back_held: bool = false      # bBackYawHeld (HokejGameMode.h)
var back_yaw: float = 0.0        # BackYawRad
var aiming: bool = false         # bCursorAiming


## The keys' axis, x right, y forward (OnMove: ClampAxes(-1, 1) of the summed key values).
static func axis(fwd: float, back: float, left: float, right: float) -> Vector2:
	return Vector2(clampf(right - left, -1.0, 1.0), clampf(fwd - back, -1.0, 1.0))


## FJamInput::Move from the axis and the camera's yaw in radians (HokejGameMode.cpp:940-958).
func move(ax: Vector2, cam_yaw: float) -> Vector2:
	var move_yaw: float = cam_yaw
	if ax.y < -0.3:
		if not back_held:
			back_held = true
			back_yaw = cam_yaw
		move_yaw = back_yaw
	else:
		back_held = false
	var move_fwd: Vector2 = Vector2(cos(move_yaw), sin(move_yaw))
	var move_right: Vector2 = Vector2(-sin(move_yaw), cos(move_yaw))
	return move_fwd * ax.y + move_right * ax.x


## FJamInput::Stick from the cursor's point on the ice (HokejGameMode.cpp:756-767). No hit (cursor off the ice): ZERO, and
## the hysteresis state is kept as CursorAimRink keeps it (its early returns leave bCursorAiming alone, cpp:741-754).
func stick(hit: Vector2, skater: Vector2) -> Vector2:
	var delta: Vector2 = hit - skater
	var dist: float = delta.length()
	var enter: float = 0.5 if aiming else 0.7
	if dist < enter:
		aiming = false
		return Vector2.ZERO
	aiming = true
	var mag: float = 0.5 + 0.5 * clampf((dist - 0.5) / 2.5, 0.0, 1.0)
	return delta / dist * mag
