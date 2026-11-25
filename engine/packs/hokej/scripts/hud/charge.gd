extends RefCounted
## Two of lane A213's wave-2 pieces (HEAD 8dc713c6), presentation only: - the pass's target ring ... [base README: scripts/hud/charge.gd §1]

const R := preload("rules.gd")

var flight_target: int = -1   # HUDChargeLook.cpp:35 (statics of the session)
var flight_until: int = -1
var flight_passes: int = -1
var last_held_frames: int = 0
var last_held_target: int = -1
var tap_target: int = -1                 # the held-or-tap read on the last frame he carried (stands in for the release frame's own call)
# HUDTeach.cpp:25, h:619-620
var teach_state: Array = [{}, {}]        # ETeach::Pass, ETeach::Hit (FTeachState)
var teach_shown: int = -1
var teach_passes_seen: int = -1


func reset_session() -> void:
	teach_state = [{}, {}]
	teach_shown = -1
	teach_passes_seen = -1


## The pass ring this frame: the skater index it stands under, or -1 (HUDChargeLook.cpp:64-112). Call once a sim frame.
func pass_ring(snap: Dictionary, phase: String, me: int, f: int) -> int:
	if phase != "play":
		return -1
	var sk: Array = snap["Skaters"]
	var hu: Dictionary = sk[me]
	var ctl: Dictionary = snap.get("Controls", {})
	var carry: bool = int(snap["Carrier"]) == me
	var passes: int = int(hu.get("Passes", 0))
	var held_t: int = int(ctl.get("PassTargetHeld", ctl.get("PassTarget", -1)))
	if flight_passes < 0 or passes < flight_passes:
		flight_passes = passes
	if passes > flight_passes:                                                   # cpp:73-79
		flight_target = last_held_target if last_held_target >= 0 else tap_target
		flight_until = f + R.PASS_FLIGHT_RING_FRAMES
		flight_passes = passes
	var charge: int = int(hu.get("PassChargeFrames", 0))
	if charge <= 0 and not carry:                                                # cpp:80
		last_held_frames = 0
		last_held_target = -1
	var pk: Dictionary = snap["Puck"]
	var in_flight: bool = flight_target >= 0 and f < flight_until and int(pk.get("PassFrames", 0)) > 0 \
		and int(pk.get("PassBy", -1)) == me and flight_target < sk.size()             # cpp:82
	var out: int = -1
	if in_flight and _on_ice(sk, flight_target):
		out = flight_target
	if not in_flight and carry and R.POWER_FULL_FRAMES > 0 and charge > 0:         # cpp:97-112
		last_held_frames = charge
		last_held_target = held_t
		if held_t >= 0 and held_t < sk.size() and _on_ice(sk, held_t):
			out = held_t
	if carry:
		tap_target = held_t
	return out


static func _on_ice(sk: Array, i: int) -> bool:
	return R.ring_on_ice(int((sk[i] as Dictionary).get("PenaltyFrames", 0)) > 0)   # RingOnIce(BoxedRingOn(), InBox()) (lane A224)


## The teaching pulse this sim frame: 0 the pass, 1 the check, -1 none (HUDTeach.cpp:48-89). [base README: scripts/hud/charge.gd §2]
func teach(snap: Dictionary, phase: String, me: int, f: int, counting: bool, down: bool, last_drop: int, pressed_hit: bool) -> int:
	var show: int = -1
	if phase == "play" and not counting:
		var sk: Array = snap["Skaters"]
		var hu: Dictionary = sk[me]
		var carrier: int = int(snap["Carrier"])
		var ci: int = carrier if carrier >= 0 and carrier < sk.size() else -1
		var yaw: float = float(hu["Yaw"])
		var face := Vector2(cos(yaw), sin(yaw))
		var hpos: Vector2 = hu["Pos"]
		var passes: int = int(hu.get("Passes", 0))
		if teach_passes_seen < 0 or passes < teach_passes_seen:
			teach_passes_seen = passes
		var passed: bool = passes > teach_passes_seen
		teach_passes_seen = passes
		var hit: bool = pressed_hit
		for e: Dictionary in snap["Events"]:
			if int(e["Who"]) == me and (String(e["Name"]) == "check" or String(e["Name"]) == "lift"):
				hit = true
		var pass_due: bool = false
		if ci == me and R.POWER_FULL_FRAMES > 0 and not down:                     # cpp:64-74
			var ctl: Dictionary = snap.get("Controls", {})
			var t: int = int(ctl.get("PassTargetFacing", ctl.get("PassTarget", -1)))
			if t >= 0 and t < sk.size():
				var to: Vector2 = ((sk[t] as Dictionary)["Pos"] as Vector2) - hpos
				var d: float = to.length()
				pass_due = d >= 6.0 and d <= 30.0 and (to / maxf(d, 0.01)).dot(face) > 0.7
		var hit_due: bool = false
		if ci >= 0 and ci != me and int((sk[ci] as Dictionary)["Team"]) != int(hu["Team"]) and not down:   # cpp:77-82
			var to2: Vector2 = ((sk[ci] as Dictionary)["Pos"] as Vector2) - hpos
			var d2: float = to2.length()
			hit_due = d2 <= R.TEACH_HIT_RANGE_M and (to2 / maxf(d2, 0.01)).dot(face) > 0.5
		var pass_on: bool = R.teach_step(teach_state[0], pass_due, passed, f)
		var hit_on: bool = R.teach_step(teach_state[1], hit_due, hit, f)
		show = 0 if pass_on and ci == me else (1 if hit_on and ci != me else -1)   # cpp:85
		if down:
			show = -1
		if last_drop >= 0 and f >= last_drop and f - last_drop < R.TEACH_DROP_QUIET_FRAMES:   # cpp:88
			show = -1
	teach_shown = show
	return show
