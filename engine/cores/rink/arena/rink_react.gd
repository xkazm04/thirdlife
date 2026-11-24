extends RefCounted
## thirdjam's arena answering the game (K6 round 3, hockey port): ARinkActor's reactions (RinkActor.cpp:1363-1424,
## 1530-1858; constants RinkActor.h:86-179) and BP_ArenaCrowd's cheer, on the hall this core bakes (arena.scn), driven by
## the core's snapshot events once a simulated frame.
##
##   var react = arena.reactions(ctx.root)       # rink_arena.gd: after build
##   react.frame(snap)                            # every simulated frame, also under a hit-stop (thirdjam's bus frame)
##
## What answers (each with its thirdjam source):
##   a goal       the scorer's table's lamp and the lamp behind the scored net flash 108 frames (LampAt: an 18-frame
##                sawtooth 1 -> 0.35, the last 36 frames fading; Emissive 0.5 + 8.5 x it on MI_Trim_Lamp, lane A172);
##                the scored net's cords shake 54 frames (NetShakeAt, depth +-12 %, height -+6 %, one frame ahead);
##                the caps behind the scored goal line hop in a wave from the posts, once a lamp pulse (ApplyCaps' wave);
##                the crowd of that end stands: BP_ArenaCrowd's scalar up over 28 frames, held to 88, down by 108
##                (ASSETS.md BP_ArenaCrowd, status/AR13-report.md section 1).
##   a board hit  a skater `board` event at Strength 0.45 or more: the nearest cap rocks 26 degrees away from the rink and
##                hops 22 cm at Strength 1 (CapRockAt: 14 frames), its two neighbours each side 2 frames later per place at
##                0.55 and 0.25; a hit on a long side within 2 m of a bench, box or table rocks it 3.5 degrees (RattleAt,
##                18 frames). Up to 4 ripples live at once (a free one first, else the oldest).
## Not ported (DEVIATIONS, ROUND-3.md): the lamps' point lights, the hit flash and the wave's two lights (the hall's
## materials are lit by the rig's list, not by engine lights); the penalty box's door, clock hand and light.
## Visual only: nothing here is state; headless the values are computed (tests read them) and nothing is drawn.

const LAMP_FLASH_FRAMES: int = 108          # RinkActor.h:90
const LAMP_PULSE_FRAMES: int = 18           # h:91
const LAMP_FADE_FRAMES: int = 36            # h:92
const LAMP_TRIM_REST: float = 0.5           # h:97 (MI_Trim_Lamp: jam.rink.lamp.trim 1)
const LAMP_TRIM_PEAK: float = 9.0           # h:100
const NET_SHAKE_FRAMES: int = 54            # h:101
const NET_SHAKE_DEPTH: float = 0.12         # h:102
const NET_SHAKE_HEIGHT: float = 0.06        # h:103
const NET_SHAKE_LEAD: int = 1               # h:179
const RATTLE_FRAMES: int = 18               # h:104
const RATTLE_MAX_DEG: float = 3.5           # h:106
const RATTLE_MIN_STRENGTH: float = 0.45     # h:105
const RATTLE_REACH_M: float = 2.0           # h:107
const CAP_ROCK_FRAMES: int = 14             # h:127
const CAP_RIPPLE_REACH: int = 2             # h:128
const CAP_RIPPLE_DELAY: int = 2             # h:129
const CAP_RIPPLE_FRAMES: int = CAP_ROCK_FRAMES + CAP_RIPPLE_REACH * CAP_RIPPLE_DELAY
const CAP_ROCK_DEG: float = 26.0            # h:131
const CAP_HOP_CM: float = 22.0              # h:132
const CAP_RIPPLES: int = 4                  # h:133
const CAP_SHARE: Array = [1.0, 0.55, 0.25]  # ApplyCaps (cpp:1586)
const WAVE_REACH_M: float = 10.0            # h:150 (WaveReachM)
const WAVE_CAP_SHARE: float = 0.6           # h:152
const WAVE_START_HALF_M: float = 2.0        # h:183 (WaveStartHalfM)
const WAVE_SHARE: float = 0.12              # jam.rink.react.wave default (cpp:93)
const STANCHION_SPACING_M: float = 3.6      # h:67
const BOARD_THICKNESS_M: float = 0.2        # h:61
const BOARD_HEIGHT_M: float = 1.2           # h:59
const CHEER_RISE: int = 28                  # BP_ArenaCrowd (AR13): up over 28 frames
const CHEER_HOLD_END: int = 88              # held to 88
const CHEER_END: int = 108                  # down to 0 by 108
## The pieces a hit rocks (RattlePiece, cpp:1690-1702): bench -x, bench +x (+y side), box -x, box +x, table (-y side).
const RATTLE_GROUPS: Array = ["ArenaBenchNeg", "ArenaBenchPos", "ArenaBoxNeg", "ArenaBoxPos", "ArenaTable"]
## Their half lengths along the boards (cpp:1095): the benches L x 0.1 / 2 (ArenaBenchLengthFactor), the boxes 2.26, the table 0.70.
const BENCH_LENGTH_FACTOR: float = 0.1
const RATTLE_HALF_FIXED: Array = [-1.0, -1.0, 2.26, 2.26, 0.70]
## The lamps (cpp:1072): 0 the scorer's table's, 1 the goal light behind the -x net, 2 behind the +x net, with their material.
const LAMP_PIECES: Array = [["ArenaTable", "MID_MI_Trim_Lamp_0"], ["ArenaGoalLightNeg", "MID_MI_Trim_Lamp_1"], ["ArenaGoalLightPos", "MID_MI_Trim_Lamp_2"]]

var L: float = 90.0
var W: float = 45.0
var goal_line_x: float = 41.0
# the caps: thirdjam's ring order (Build's walk, cpp:525-550) and where each instance of the two halves sits
var cap_at: Array = []            # Vector2 rink metres, ring index k
var cap_yaw_deg: Array = []       # CapYawDeg[k] + Turn[k]: the cap's rest yaw (its +y along `out`)
var cap_side: PackedInt32Array = []
var cap_inst: PackedInt32Array = []
var cap_rest: Array = []          # Transform3D per k (Godot space), from the baked instances
var cap_now: Dictionary = {}      # k -> Vector2(tilt deg, hop cm): the caps off rest
var ripples: Array = []           # {frame, index, strength}
# the goal
var goal_frame: int = -1
var goal_end: int = 0             # +1: the +x net was scored on, -1: the -x net
var lamp_now: Array = [LAMP_TRIM_REST, LAMP_TRIM_REST, LAMP_TRIM_REST]
var net_scale: Array = [Vector2.ONE, Vector2.ONE]   # (depth, height) factors, [-x net, +x net]
# the rattle
var rattle_frame: int = -1
var rattle_index: int = -1
var rattle_strength: float = 0.0
var rattle_deg: float = 0.0
var rattle_centre_x: Array = [0.0, 0.0, 0.0, 0.0, 0.0]
var rattle_half: Array = [0.0, 0.0, 0.0, 0.0, 0.0]
# the crowd (BP_ArenaCrowd): the frame each end's net was last scored on
var cheer_from: Array = [-1000000, -1000000]   # [+x, -x]
var cheer_now: Vector2 = Vector2.ZERO          # (plus, minus)
# counts (tests): thirdjam's GetGoalReactionCount, GetRattleCount, GetCapRockCount
var goal_reactions: int = 0
var rattle_reactions: int = 0
var cap_rock_reactions: int = 0
var last_cap_index: int = -1
var last_cap_dist: float = 0.0
var rows: Array = []              # what answered: [frame, what, detail] (the reaction table)

var _last_frame: int = -1
var _draw: bool = false
var _caps_mm: Array = [null, null]          # MultiMesh of ArenaCaps (x < 0), ArenaCapsPos (x >= 0)
var _net_mm: MultiMesh = null               # ArenaGoalNetNeg: instance 0 the -x net, 1 the +x net
var _net_rest: Array = []
var _net_inst: Array = []                   # per baked instance: 0 the -x net, 1 the +x net
var _lamp_mats: Array = [null, null, null]
var _lamp_glow: Array = [Color(), Color(), Color()]   # TeamColour x ClayGlowMul (the emit at Emissive 1)
var _rattle_nodes: Array = [null, null, null, null, null]
var _rattle_rest: Array = []


## `hall`: the node rink_arena.build returned (RinkArena), or any node above it. `rink`: thirdjam's game.rink. `table`:
## arena.json. With `draw` false (headless) nothing is touched.
func _init(hall: Node, rink: Dictionary, table: Dictionary, draw: bool) -> void:
	L = float(rink["length_m"])
	W = float(rink["width_m"])
	goal_line_x = L * 0.5 - 4.0                                     # FJamRinkConfig::GoalLineX (JamCartridge.h:43)
	_walk_caps(L, W, float(rink["corner_radius_m"]))
	var root: Node = hall if hall == null or hall.name == "RinkArena" else hall.find_child("RinkArena", true, false)
	var groups: Dictionary = {}
	for g: Dictionary in table.get("groups", []):
		groups[str(g["name"])] = g
	# the caps' rest transforms, from the baked buffers (they ride on the node as meta, headless too)
	var halves: Array = [_instances(root, "ArenaCaps"), _instances(root, "ArenaCapsPos")]
	for k: int in cap_at.size():
		var h: Array = halves[cap_side[k]]
		cap_rest.append(h[cap_inst[k]] if cap_inst[k] < h.size() else Transform3D())
	var nets: Array = _instances(root, "ArenaGoalNetNeg")              # both nets, in the order the bake met them
	for t: Transform3D in nets:
		_net_inst.append(1 if t.origin.x > 0.0 else 0)
		_net_rest.append(t)
	for i: int in 5:
		var gname: String = RATTLE_GROUPS[i]
		var n: Node3D = root.get_node_or_null(NodePath(gname)) as Node3D if root != null else null
		_rattle_nodes[i] = n
		_rattle_rest.append(n.transform if n != null else Transform3D())
		var first: Array = (groups.get(gname, {}) as Dictionary).get("first", [])
		rattle_centre_x[i] = float(first[9]) if first.size() >= 12 else 0.0
		rattle_half[i] = L * BENCH_LENGTH_FACTOR * 0.5 if float(RATTLE_HALF_FIXED[i]) < 0.0 else float(RATTLE_HALF_FIXED[i])
	var mats: Dictionary = table.get("materials", {})
	for i: int in 3:
		var m: Dictionary = mats.get(LAMP_PIECES[i][1], {})
		var tc: Array = (m.get("vectors", {}) as Dictionary).get("TeamColour", [1, 0, 0, 1])
		_lamp_glow[i] = Color(float(tc[0]), float(tc[1]), float(tc[2])) * float((m.get("scalars", {}) as Dictionary).get("ClayGlowMul", 1.0))
	_draw = draw and root != null
	if not _draw:
		return
	for s: int in 2:
		var mmi: MultiMeshInstance3D = root.get_node_or_null(NodePath(["ArenaCaps", "ArenaCapsPos"][s])) as MultiMeshInstance3D
		_caps_mm[s] = mmi.multimesh if mmi != null else null
	var nm: MultiMeshInstance3D = root.get_node_or_null(^"ArenaGoalNetNeg") as MultiMeshInstance3D
	_net_mm = nm.multimesh if nm != null else null
	for i: int in 3:
		var gi: GeometryInstance3D = root.get_node_or_null(NodePath(str(LAMP_PIECES[i][0]))) as GeometryInstance3D
		var names: Array = (groups.get(str(LAMP_PIECES[i][0]), {}) as Dictionary).get("materials", [])
		var slot: int = names.find(LAMP_PIECES[i][1])
		if gi is MeshInstance3D and slot >= 0 and slot < (gi as MeshInstance3D).mesh.get_surface_count():
			_lamp_mats[i] = (gi as MeshInstance3D).mesh.surface_get_material(slot)


## ARinkActor::Build's stanchion walk (RinkActor.cpp:525-550, the outline of cpp:416-432 at 12 arc segments): a cap at every
## stanchion's foot, T / 2 outward of the outline; its yaw, and the size and turn Build gives it (cpp:1044-1051); which half
## holds it and at which instance (CapSide, CapInst: the halves are filled in ring order).
func _walk_caps(l: float, w: float, r: float) -> void:
	var line: Array = []
	var hx: float = l * 0.5
	var hz: float = w * 0.5
	var rc: float = clampf(r, 0.0, minf(hx, hz))
	var centres: Array = [Vector2(hx - rc, hz - rc), Vector2(-(hx - rc), hz - rc), Vector2(-(hx - rc), -(hz - rc)), Vector2(hx - rc, -(hz - rc))]
	for c: int in 4:
		var start: float = float(c) * PI * 0.5
		var segs: int = 12 if rc > 0.0 else 1
		for i: int in segs + 1:
			var a: float = start + (PI * 0.5) * float(i) / float(segs)
			line.append((centres[c] as Vector2) + Vector2(cos(a), sin(a)) * rc)
	var perimeter: float = 0.0
	for i: int in line.size():
		perimeter += (line[i] as Vector2).distance_to(line[(i + 1) % line.size()])
	var count: int = maxi(4, roundi(perimeter / STANCHION_SPACING_M))
	var step: float = perimeter / float(count)
	var seg: int = 0
	var seg_start: float = 0.0
	var seg_len: float = (line[0] as Vector2).distance_to(line[1 % line.size()])
	var halves: Array = [0, 0]
	for k: int in count:
		var s: float = float(k) * step
		while s > seg_start + seg_len and seg < line.size() - 1:
			seg_start += seg_len
			seg += 1
			seg_len = (line[seg] as Vector2).distance_to(line[(seg + 1) % line.size()])
		var a: Vector2 = line[seg]
		var b: Vector2 = line[(seg + 1) % line.size()]
		var dir: Vector2 = (b - a).normalized()
		var out := Vector2(dir.y, -dir.x)
		var m: Vector2 = a + dir * clampf(s - seg_start, 0.0, seg_len) + out * (BOARD_THICKNESS_M * 0.5)
		cap_at.append(m)
		var hh: int = ((k + 1) * 2654435761) & 0xffffffff
		hh = hh ^ (hh >> 15)
		var turn: float = -9.0 + 18.0 * (float((hh >> 8) & 0xff) / 255.0)
		cap_yaw_deg.append(rad_to_deg(atan2(-out.x, out.y)) + turn)
		var side: int = 1 if m.x >= 0.0 else 0
		cap_side.append(side)
		cap_inst.append(halves[side])
		halves[side] += 1


## A baked group's instance transforms (build_arena.gd's buffer: 12 floats a transform in rows, then 4 of custom data
## when the group has any), or its node's own transform.
static func _instances(root: Node, gname: String) -> Array:
	var out: Array = []
	var n: Node = root.get_node_or_null(NodePath(gname)) if root != null else null
	if n is MultiMeshInstance3D:
		var buf: PackedFloat32Array = n.get_meta(&"tl_buffer", PackedFloat32Array())
		var count: int = int(n.get_meta(&"tl_count", 0))
		var stride: int = buf.size() / maxi(count, 1)
		for i: int in count:
			var o: int = i * stride
			out.append(Transform3D(Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]),
				Vector3(buf[o + 2], buf[o + 6], buf[o + 10])), Vector3(buf[o + 3], buf[o + 7], buf[o + 11])))
	elif n is Node3D:
		out.append((n as Node3D).transform)
	return out


# ------------------------------------------------------------------ the pure curves (RinkActor.cpp:1368-1406)

## LampAt: 0 outside [0, 108), else an 18-frame sawtooth from 1 down to 0.35, the last 36 frames fading.
static func lamp_at(since: int) -> float:
	if since < 0 or since >= LAMP_FLASH_FRAMES:
		return 0.0
	var pulse: float = 1.0 - 0.65 * float(since % LAMP_PULSE_FRAMES) / float(LAMP_PULSE_FRAMES)
	var left: int = LAMP_FLASH_FRAMES - since
	var env: float = 1.0 if left >= LAMP_FADE_FRAMES else float(left) / float(LAMP_FADE_FRAMES)
	return pulse * env


## NetShakeAt: 0 outside [0, 54), else a damped sine one frame ahead.
static func net_shake_at(since: int) -> float:
	if since < 0 or since >= NET_SHAKE_FRAMES:
		return 0.0
	var t: float = float(since + NET_SHAKE_LEAD)
	return exp(-t / 16.0) * sin(2.0 * PI * t / 10.0)


## RattleAt: 0 outside [0, 18), else a damped cosine times the clamped Strength.
static func rattle_at(since: int, strength: float) -> float:
	if since < 0 or since >= RATTLE_FRAMES:
		return 0.0
	var t: float = float(since)
	return clampf(strength, 0.0, 1.0) * exp(-t / 6.0) * cos(2.0 * PI * t / 8.0)


## CapRockAt: 0 outside [0, 14), else a damped cosine times the clamped Strength.
static func cap_rock_at(since: int, strength: float) -> float:
	if since < 0 or since >= CAP_ROCK_FRAMES:
		return 0.0
	var t: float = float(since)
	return clampf(strength, 0.0, 1.0) * exp(-t / 4.0) * cos(2.0 * PI * t / 8.0)


## BP_ArenaCrowd's scalar for an end, `since` frames after its net was scored on.
static func cheer_at(since: int) -> float:
	if since < 0 or since >= CHEER_END:
		return 0.0
	if since <= CHEER_HOLD_END:
		return minf(1.0, float(since) / float(CHEER_RISE))
	return float(CHEER_END - since) / float(CHEER_END - CHEER_HOLD_END)


# ------------------------------------------------------------------ the frame

## One simulated frame: the frame's events start reactions (ReactToEvent), then every live one advances to this frame
## (AdvanceReactions). A frame already seen does nothing; a frame before the last one (a restart) puts everything at rest.
func frame(snap: Dictionary) -> void:
	var f: int = int(snap.get("Frame", 0))
	if f == _last_frame:
		return
	if f < _last_frame:
		reset()
	_last_frame = f
	for e: Dictionary in snap.get("Events", []):
		react(str(e.get("Name", "")), str(e.get("Kind", "")), e.get("Where", Vector2.ZERO), float(e.get("Strength", 0.0)), f)
	advance(f)


## ReactToEvent (RinkActor.cpp:1730-1838): a goal, a hard skater board hit. `where`: rink metres.
func react(ev: String, kind: String, where: Vector2, strength: float, f: int) -> void:
	if ev == "goal":
		if goal_frame >= 0:
			_goal_apply(1 << 30)                                     # a second goal inside the first one's flash: that end back to rest
		goal_frame = f
		goal_end = 1 if where.x > 0.0 else -1                        # the side of the net the puck is in
		goal_reactions += 1
		cheer_from[0 if goal_end > 0 else 1] = f                     # BP_ArenaCrowd: the end whose net was scored (Where.X sign)
		rows.append([f, "goal", "+x" if goal_end > 0 else "-x"])
		_goal_apply(0)
		_caps_apply(f)                                               # the wave's first front leaves the goal light (cpp:1752)
	elif ev == "board" and kind == "skater" and strength >= RATTLE_MIN_STRENGTH:
		# the nearest cap answers anywhere on the ring
		var cap: int = 0
		var best: float = INF
		for k: int in cap_at.size():
			var d: float = (cap_at[k] as Vector2).distance_squared_to(where)
			if d < best:
				best = d
				cap = k
		var slot: int = -1
		for i: int in ripples.size():
			if int(ripples[i]["frame"]) < 0:
				slot = i
				break
		if slot < 0 and ripples.size() < CAP_RIPPLES:
			ripples.append({"frame": -1, "index": -1, "strength": 0.0})
			slot = ripples.size() - 1
		if slot < 0:                                                 # the oldest
			slot = 0
			for i: int in range(1, ripples.size()):
				if int(ripples[i]["frame"]) < int(ripples[slot]["frame"]):
					slot = i
		ripples[slot] = {"frame": f, "index": cap, "strength": strength}
		last_cap_index = cap
		last_cap_dist = sqrt(best)
		cap_rock_reactions += 1
		_caps_apply(f)                                               # cpp:1790
		rows.append([f, "cap", "%d of %d, strength %.2f, tilt %.1f deg hop %.1f cm, %.2f m" % [cap, cap_at.size(), strength, cap_tilt(cap), cap_hop(cap), last_cap_dist]])
		# the bench, box or table behind a long side's hit (an end board or a corner has none)
		if absf(where.y) >= W * 0.5 - 1.5:
			var pick: int = -1
			var best_d: float = RATTLE_REACH_M + 1e-6
			for i: int in 5:
				if (i < 2) != (where.y > 0.0):
					continue                                         # benches on +y, boxes and table on -y
				var d2: float = maxf(0.0, absf(where.x - float(rattle_centre_x[i])) - float(rattle_half[i]))
				if d2 < best_d:
					best_d = d2
					pick = i
			if pick >= 0:
				if rattle_frame >= 0 and rattle_index != pick:
					_rattle_apply(1 << 30)
				rattle_frame = f
				rattle_index = pick
				rattle_strength = strength
				rattle_reactions += 1
				rows.append([f, "rattle", "%s, strength %.2f" % [RATTLE_GROUPS[pick], strength]])
				_rattle_apply(0)


## AdvanceReactions (cpp:1841-1858) and BP_ArenaCrowd's tick.
func advance(f: int) -> void:
	if goal_frame >= 0:
		var since: int = f - goal_frame
		if since < 0 or since >= maxi(LAMP_FLASH_FRAMES, NET_SHAKE_FRAMES):
			_goal_apply(1 << 30)
			goal_frame = -1
		else:
			_goal_apply(since)
	if rattle_frame >= 0:
		var since2: int = f - rattle_frame
		if since2 < 0 or since2 >= RATTLE_FRAMES:
			_rattle_apply(1 << 30)
			rattle_frame = -1
		else:
			_rattle_apply(since2)
	_caps_apply(f)
	cheer_now = Vector2(cheer_at(f - int(cheer_from[0])), cheer_at(f - int(cheer_from[1])))
	if _draw:
		TLStyleArena.set_cheer(cheer_now.x, cheer_now.y, float(f) / 60.0)


## ResetReactions (cpp:1720-1729): everything at rest (a restart, a rebuild).
func reset() -> void:
	if goal_frame >= 0:
		_goal_apply(1 << 30)
	if rattle_frame >= 0:
		_rattle_apply(1 << 30)
	goal_frame = -1
	rattle_frame = -1
	rattle_deg = 0.0
	ripples.clear()
	_caps_apply(0)
	cheer_from = [-1000000, -1000000]
	cheer_now = Vector2.ZERO
	if _draw:
		TLStyleArena.set_cheer(0.0, 0.0, 0.0)


## ApplyGoalReaction (cpp:1704-1724): the two lamps (the table's and the scored end's) and the scored net's cords.
func _goal_apply(since: int) -> void:
	var l: float = lamp_at(since)
	var end_lamp: int = 2 if goal_end > 0 else 1
	for i: int in [0, end_lamp]:
		lamp_now[i] = LAMP_TRIM_REST + l * (LAMP_TRIM_PEAK - LAMP_TRIM_REST)   # L = 0 writes the resting value exactly
		if _draw and _lamp_mats[i] != null:
			TLStyleArena.set_glow(_lamp_mats[i], (_lamp_glow[i] as Color) * float(lamp_now[i]))
	var w: float = net_shake_at(since)
	var ni: int = 1 if goal_end > 0 else 0
	net_scale[ni] = Vector2(1.0 + NET_SHAKE_DEPTH * w, 1.0 - NET_SHAKE_HEIGHT * w)
	var inst: int = _net_inst.find(ni)
	if _draw and _net_mm != null and inst >= 0:
		_net_mm.set_instance_transform(inst, _net_shaken(_net_rest[inst], float(goal_end), net_scale[ni]))


## The net's own scale (the mouth stays on the goal line, the mesh's origin): deeper into its goal (rink x outward of the
## goal line) and lower, as SetRelativeScale3D(X, Y (1 + 0.12 W), Z (1 - 0.06 W)) does on the net's own axes.
static func _net_shaken(rest: Transform3D, end_sign: float, s: Vector2) -> Transform3D:
	var inv: Basis = rest.basis.inverse()
	var d: Vector3 = (inv * Vector3(end_sign, 0.0, 0.0)).normalized()      # the net's depth axis in its own space
	var u: Vector3 = (inv * Vector3.UP).normalized()                         # its height axis
	# I + (sd - 1) d d^T + (sh - 1) u u^T, column by column
	var kd: float = s.x - 1.0
	var ku: float = s.y - 1.0
	var m := Basis(Vector3(1, 0, 0) + d * (d.x * kd) + u * (u.x * ku), Vector3(0, 1, 0) + d * (d.y * kd) + u * (u.y * ku),
		Vector3(0, 0, 1) + d * (d.z * kd) + u * (u.z * ku))
	return Transform3D(rest.basis * m, rest.origin)


## ApplyRattle (cpp:1712-1719): a roll about the piece's own axis along the boards through its rink-side foot; positive
## tips its top away from the rink (FRotator roll: the local z towards the local +y, which points away from the rink).
func _rattle_apply(since: int) -> void:
	if rattle_index < 0:
		return
	rattle_deg = RATTLE_MAX_DEG * rattle_at(since, rattle_strength)
	if not _draw:
		return
	var n: Node3D = _rattle_nodes[rattle_index]
	if n == null:
		return
	var rest: Transform3D = _rattle_rest[rattle_index]
	var away: float = 1.0 if rattle_index < 2 else -1.0              # benches on +y (Godot +z), boxes and table on -y
	n.transform = Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(rattle_deg) * away) * rest.basis, rest.origin)


## ApplyCaps (cpp:1582-1662): the ripples of hard hits and the goal's wave, every cap off rest written, the ones that
## came to rest put back.
func _caps_apply(f: int) -> void:
	var n: int = cap_at.size()
	var next: Dictionary = {}
	for rp: Dictionary in ripples:
		if int(rp["frame"]) < 0:
			continue
		var since: int = f - int(rp["frame"])
		if n <= 0 or since < 0 or since >= CAP_RIPPLE_FRAMES:
			rp["frame"] = -1                                         # over, or a frame before its start: a new match began
			continue
		for d: int in range(-CAP_RIPPLE_REACH, CAP_RIPPLE_REACH + 1):
			var ring: int = absi(d)
			var cv: float = cap_rock_at(since - ring * CAP_RIPPLE_DELAY, float(rp["strength"])) * float(CAP_SHARE[ring])
			if cv == 0.0:
				continue
			var k: int = posmod(int(rp["index"]) + d, n)
			var v: Vector2 = next.get(k, Vector2.ZERO)
			next[k] = v + Vector2(CAP_ROCK_DEG * cv, CAP_HOP_CM * absf(cv))
	if goal_frame >= 0 and n > 0 and WAVE_SHARE > 0.0:
		var since_g: int = f - goal_frame
		if since_g >= 0 and since_g < LAMP_FLASH_FRAMES:
			var left: int = LAMP_FLASH_FRAMES - since_g
			var env: float = 1.0 if left >= LAMP_FADE_FRAMES else float(left) / float(LAMP_FADE_FRAMES)
			var in_pulse: int = since_g % LAMP_PULSE_FRAMES
			for k: int in n:
				var at: Vector2 = cap_at[k]
				if at.x * float(goal_end) <= goal_line_x:
					continue
				var along: float = absf(at.y)
				if along > WAVE_REACH_M:
					continue
				var t: int = in_pulse - roundi(maxf(0.0, along - WAVE_START_HALF_M) / WAVE_REACH_M * float(LAMP_PULSE_FRAMES - 1))
				if t < 0:
					if since_g < LAMP_PULSE_FRAMES:
						continue                                     # the first front has not reached it yet
					t += LAMP_PULSE_FRAMES                           # still swinging from the pulse before
				var cv2: float = cap_rock_at(t, 1.0) * WAVE_CAP_SHARE * env
				if cv2 == 0.0:
					continue
				var v2: Vector2 = next.get(k, Vector2.ZERO)
				next[k] = v2 + Vector2(CAP_ROCK_DEG * cv2, CAP_HOP_CM * absf(cv2))
	if _draw:
		for k: int in cap_now:
			if not next.has(k):
				_cap_write(k, Vector2.ZERO)
		for k: int in next:
			_cap_write(k, next[k])
	cap_now = next


## Cap k's transform: a roll about its own x axis (along the boards) through its foot, the top towards its +y (away from
## the rink), and a hop straight up. Unreal's local x of a cap at yaw a is (cos a, sin a, 0): here (cos a, 0, sin a).
func _cap_write(k: int, v: Vector2) -> void:
	var mm: MultiMesh = _caps_mm[cap_side[k]]
	if mm == null or k >= cap_rest.size():
		return
	var rest: Transform3D = cap_rest[k]
	var a: float = deg_to_rad(float(cap_yaw_deg[k]))
	var axis := Vector3(cos(a), 0.0, sin(a))
	mm.set_instance_transform(cap_inst[k], Transform3D(Basis(axis, deg_to_rad(v.x)) * rest.basis, rest.origin + Vector3.UP * (v.y * 0.01)))


## Cap k's tilt (degrees) and hop (cm) now; 0 at rest (GetCapTiltDeg, GetCapHopCm).
func cap_tilt(k: int) -> float:
	return (cap_now.get(k, Vector2.ZERO) as Vector2).x


func cap_hop(k: int) -> float:
	return (cap_now.get(k, Vector2.ZERO) as Vector2).y
