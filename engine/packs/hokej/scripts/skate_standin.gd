extends RefCounted
## STAND-IN for lane K1's rink core (engine/cores/rink, SNAPSHOT.md draft v0): ONE free skater on empty ice, driven by the
## frame-exact port of thirdjam's skating law in docs/research/hockey-teardown/probes/hand_tj_skate.mjs (itself a port of
## UJamSim::StepSkater, the free-skater path, C:/t/t5 JamSim.cpp:1266-1478, checked there against the build's own
## Jam.Core.Movement timing lines). No lunge, spin, zone, breakaway, contact, puck or bots. Do not tune: swap it out.
## The surface mirrors the core's planned one (SNAPSHOT.md "GDScript surface"): reset(), set_human_input({Move, bSprint,
## bBrake, ...}), step(), snapshot() -> {"Frame", "HumanIndex", "Skaters": [{"Pos", "Vel", "Yaw", "PrevPos", "PrevYaw",
## "bSprinting", "Stamina", "bBraking", "Stick"}]}. Field names are thirdjam's (FJamInput, FJamSkaterState).

const DT: float = 1.0 / 60.0
# hand_tj_skate.mjs:13 (thirdjam constants JamSim.h:499-505)
const SLOW: float = 2.0
const REST: float = 1.0
const CUTF: int = 10
const CUTDOT: float = 0.5
const REVDOT: float = -0.5
const PIVOT: float = 0.5
const CAP: float = 0.97

var c: Dictionary            # hand_tj_skate.mjs REG (hockey.regular): speed, accel, turn, grip, glide from the cartridge
var frame: int = 0
var p: Vector2 = Vector2.ZERO
var v: Vector2 = Vector2.ZERO
var yaw: float = 0.0
var prev_p: Vector2 = Vector2.ZERO
var prev_yaw: float = 0.0
var stam: float = 0.0
var hist: Array = []
var hi: int = 0
var burst: int = 0
var earned: bool = false
var rest: int = 0
var carrying: bool = false
var sprinting: bool = false
var braking: bool = false
var input: Dictionary = {}


## law: the stand-in's constants (data/standin_law.json, = hand_tj_skate.mjs REG); spawn: [x, y] and yaw in radians.
func _init(law: Dictionary) -> void:
	c = law


func reset(spawn: Vector2, spawn_yaw: float) -> void:
	frame = 0
	p = spawn
	v = Vector2.ZERO
	yaw = spawn_yaw
	prev_p = p
	prev_yaw = yaw
	stam = float(c["drain"]) * float(c["refill"])
	hist = []
	for i: int in CUTF:
		hist.append(Vector2.ZERO)
	hi = 0
	burst = 0
	earned = false
	rest = int(c["restFrames"])
	input = {}


## FJamInput subset: "Move" (Vector2, rink frame), "bSprint", "bBrake", "Stick" (Vector2; carried, drawn, not simulated here).
func set_human_input(inp: Dictionary) -> void:
	input = inp


static func _wrap(a: float) -> float:
	while a > PI:
		a -= TAU
	while a < -PI:
		a += TAU
	return a


static func _rot(y: float, t: float, st: float) -> float:
	var d: float = _wrap(t - y)
	return t if absf(d) <= st else y + signf(d) * st


static func _mt(a: float, b: float, d: float) -> float:
	return b if absf(b - a) <= d else a + signf(b - a) * d


## One frame: hand_tj_skate.mjs step() (lines 25-71), statement for statement. True, as RinkCore.step() while the match runs.
func step() -> bool:
	prev_p = p
	prev_yaw = yaw
	var move: Vector2 = input.get("Move", Vector2.ZERO)
	var sprint: bool = bool(input.get("bSprint", false))
	var brake: bool = bool(input.get("bBrake", false))
	var full: float = float(c["drain"]) * float(c["refill"])
	var mag: float = move.length()
	var carry_mul: float = float(c["carry"]) if carrying else 1.0
	var sb: float = float(c["sprintCarry"]) if carrying else float(c["sprint"])
	var want_sprint: bool = sprint and sb > 0.0 and stam > 0.0 and mag * mag > 0.0025
	if want_sprint:
		stam = maxf(0.0, stam - float(c["refill"]))
	elif stam < full:
		stam = minf(full, stam + float(c["drain"]))
	sprinting = want_sprint
	var sprint_mul: float = 1.0 + sb if want_sprint else 1.0
	if carrying and want_sprint:
		sprint_mul = maxf(1.0, minf(sprint_mul, (1.0 + float(c["sprint"])) * CAP / carry_mul))
	var first: bool = false
	if int(c["burstFrames"]) > 0:
		var md: Vector2 = move / mag if mag * mag > 0.0025 else Vector2.ZERO
		var cut: bool = false
		if md != Vector2.ZERO:
			for w: Vector2 in hist:
				if w != Vector2.ZERO and w.dot(md) < CUTDOT:
					cut = true
					break
		if cut:
			for i: int in CUTF:
				hist[i] = md
		hist[hi] = md
		hi = (hi + 1) % CUTF
		if not bool(c["ownStop"]):
			earned = false
		var rest_kept: float = maxf(REST, float(c["restKept"])) if float(c["restKept"]) > 0.0 else REST
		var arm_own: bool = cut or (v.dot(v) < SLOW * SLOW and (not bool(c["ownStop"]) or earned))
		var rested: bool = int(c["restFrames"]) > 0 and rest >= int(c["restFrames"]) and v.dot(v) < rest_kept * rest_kept
		if arm_own:
			burst = int(c["burstFrames"])
		elif rested:
			burst = maxi(burst, int(c["burstFrames"]))
		first = burst > 0
		if not (arm_own or rested) and burst > 0:
			burst -= 1
	braking = false
	var thrust: bool = false
	var free_mul: float = 1.0 if carrying else float(c["free"])
	var top0: float = float(c["speed"]) * sprint_mul * carry_mul * free_mul
	var acc: float = float(c["accel"]) * sprint_mul * carry_mul * free_mul * (maxf(1.0, float(c["burstMult"])) if first else 1.0)
	if mag > 1.0:
		move = move / mag
		mag = 1.0
	thrust = mag > 0.05
	var top: float = top0 * mag
	if mag > 0.05:
		yaw = _rot(yaw, atan2(move.y, move.x), float(c["turn"]) * DT)
	var f: Vector2 = Vector2(cos(yaw), sin(yaw))
	var vv: float = v.length()
	var rev: bool = float(c["rev"]) > 0.0 and mag > 0.05 and not brake and vv > 1e-6 and move.dot(v) < REVDOT * mag * vv
	if rev:
		var cutv: float = float(c["rev"]) * minf(mag, 1.0) * DT
		if vv > 1.0:
			braking = true
		v = v * (vv - cutv) / vv if vv > cutv else Vector2.ZERO
	else:
		var along: float = v.dot(f)
		var side: Vector2 = v - f * along
		var pivot: bool = float(c["rev"]) > 0.0 and mag > 0.05 and vv < PIVOT and move.dot(f) < REVDOT * mag
		if pivot and float(c["restKept"]) > 0.0:
			thrust = false
		if mag > 0.05 and not brake and not pivot and along < top:
			along = minf(top, along + acc * mag * DT)
		along = _mt(along, 0.0, (float(c["glide"]) + (float(c["brake"]) if brake else 0.0)) * DT)
		var k: float = maxf(0.0, 1.0 - (float(c["grip"]) + (float(c["brake"]) * 0.5 if brake else 0.0)) * DT)
		side = side * k
		v = f * along + side
		if brake and vv > 1.0:
			braking = true
	if bool(c["ownStop"]) and int(c["burstFrames"]) > 0:
		if braking:
			earned = true
		elif v.dot(v) >= SLOW * SLOW:
			earned = false
	if int(c["restFrames"]) > 0 and int(c["burstFrames"]) > 0:
		var v2: float = v.dot(v)
		var hold: float = maxf(maxf(REST, float(c["restHold"])), float(c["restKept"]))
		if v2 < REST * REST and not thrust:
			rest = mini(rest + 1, int(c["restFrames"]))
		elif v2 >= hold * hold or thrust:
			rest = 0
	p = p + v * DT
	_collide_static()
	frame += 1
	return true


# ---- UJamSim::CollideSkaterStatic (HEAD JamSim.cpp:2211-2296), as UJamSim::Step calls it after StepSkater (cpp:1015):
# the boards (BoardDistance cpp:885-904, SkaterRadius 0.4 JamSim.h:494, SkaterBoardBounce 0.3 cpp:61) and the two nets as
# solid boxes (PushOutOfBox cpp:105-126, NetDepth 1.5). The regular cartridge has no obstacles. No events (step 3).

const SKATER_R: float = 0.4
const BOUNCE: float = 0.3
const EPS: float = 0.05
var rink: Dictionary = {}     # {"L", "W", "R", "goal_w"} from the cartridge's game.rink


func set_rink(r: Dictionary) -> void:
	rink = r


func _board_distance(q: Vector2) -> Array:
	var hx: float = float(rink["L"]) * 0.5
	var hz: float = float(rink["W"]) * 0.5
	var rc: float = clampf(float(rink["R"]), 0.0, minf(hx, hz))
	var sx: float = 1.0 if q.x >= 0.0 else -1.0
	var sz: float = 1.0 if q.y >= 0.0 else -1.0
	var qx: float = absf(q.x) - (hx - rc)
	var qz: float = absf(q.y) - (hz - rc)
	if qx > 0.0 and qz > 0.0:
		var ln: float = sqrt(qx * qx + qz * qz)
		return [ln - rc, Vector2(sx * qx / ln, sz * qz / ln) if ln > 1e-12 else Vector2(sx, 0.0)]
	var n: Vector2 = Vector2(sx, 0.0) if qx > qz else Vector2(0.0, sz)
	var outside: float = sqrt(pow(maxf(qx, 0.0), 2.0) + pow(maxf(qz, 0.0), 2.0))
	var inside: float = minf(maxf(qx, qz), 0.0)
	return [outside + inside - rc, n]


static func _push_out_of_box(q: Vector2, r: float, mn: Vector2, mx: Vector2) -> Array:   # [hit, new position, normal]
	var c: Vector2 = Vector2(clampf(q.x, mn.x, mx.x), clampf(q.y, mn.y, mx.y))
	var d: Vector2 = q - c
	var d2: float = d.length_squared()
	if d2 >= r * r:
		return [false, q, Vector2.ZERO]
	if d2 > 1e-12:
		var n: Vector2 = d / sqrt(d2)
		return [true, c + n * r, n]
	var l: float = q.x - mn.x
	var rr: float = mx.x - q.x
	var b: float = q.y - mn.y
	var t: float = mx.y - q.y
	var m: float = minf(minf(l, rr), minf(b, t))
	if m == l:
		return [true, Vector2(mn.x - r, q.y), Vector2(-1, 0)]
	if m == rr:
		return [true, Vector2(mx.x + r, q.y), Vector2(1, 0)]
	if m == b:
		return [true, Vector2(q.x, mn.y - r), Vector2(0, -1)]
	return [true, Vector2(q.x, mx.y + r), Vector2(0, 1)]


func _collide_static() -> void:
	if rink.is_empty():
		return
	var bd: Array = _board_distance(p)
	if float(bd[0]) + SKATER_R > 0.0:
		var n: Vector2 = bd[1]
		p -= n * (float(bd[0]) + SKATER_R)
		var vn: float = v.dot(n)
		if vn > 0.0:
			v -= n * ((1.0 + BOUNCE) * vn)
	var gl: float = float(rink["L"]) * 0.5 - 4.0
	var hw: float = float(rink["goal_w"]) * 0.5
	for side: int in [-1, 1]:
		var x0: float = gl if side > 0 else -gl - 1.5
		var x1: float = gl + 1.5 if side > 0 else -gl
		var r: Array = _push_out_of_box(p, SKATER_R, Vector2(x0, -hw), Vector2(x1, hw))
		if bool(r[0]):
			p = r[1]
			var n: Vector2 = r[2]
			var vn: float = v.dot(n)
			if vn < 0.0:
				v -= n * vn
				var slide: Vector2 = Vector2(0.0, 1.0 if p.y >= 0.0 else -1.0) if absf(n.x) > 0.5 else Vector2(1.0 if p.x >= 0.0 else -1.0, 0.0)
				v += slide * (-vn * 0.8)
	var bd2: Array = _board_distance(p)
	if float(bd2[0]) + SKATER_R > EPS:
		var n2: Vector2 = bd2[1]
		p -= n2 * (float(bd2[0]) + SKATER_R)
		var vn2: float = v.dot(n2)
		if vn2 > 0.0:
			v -= n2 * vn2


func snapshot() -> Dictionary:
	# the stand-in blade: FJamInput::Stick's direction at 0.4 + size x 1.2 m (SkaterRadius + reach); no aim: ahead at half size
	var st: Vector2 = input.get("Stick", Vector2.ZERO)
	var bd: Vector2 = Vector2(cos(yaw), sin(yaw)) * (0.4 + 0.5 * 1.2) if st == Vector2.ZERO else st.normalized() * (0.4 + st.length() * 1.2)
	return {"Frame": frame, "HumanIndex": 0, "Carrier": -1, "Puck": {"Pos": Vector2(1000, 1000), "PrevPos": Vector2(1000, 1000), "Z": 0.0, "LastTouch": -1},
		"Skaters": [{"Team": 0, "Pos": p, "Vel": v, "Yaw": yaw, "PrevPos": prev_p, "PrevYaw": prev_yaw, "BladePos": p + bd,
		"bSprinting": sprinting, "Stamina": int(stam), "bBraking": braking, "Stick": st}]}
