extends RefCounted
## What an eye would reject on thirdjam's skater, measured on the posed figure every frame (hockey campaign, lane
## K2: "a visible defect is a failed test"). `measure(figure)` reads one frame; `judge(rows)` holds a run of frames to
## the bands below and says which frames break which. Used by the figure gym (cores/rink/view/figure_gym.gd) and its
## selftest block. Everything is in metres above the ice (the figure's own y = 0) unless said.
##   blade      the stick's blade: its lowest vertex (slot Stick, skinned), while the stick is "on the ice"
##              (the driver's aim layer is the whole upper body and no take plays): never under the ice by more
##              than BLADE_UNDER, never higher than BLADE_OVER
##   skates     the skate blades' lowest vertex (slot Blade), while he skates or stands (no take): one skate at
##              least within SKATE_BAND of the ice, none under it by more than SKATE_UNDER
##   lengths    every bone as long as at rest (the two bones thirdjam's clips move are left out): BONE_STRETCH
##   pop        no joint turns more than POP_DEG in one frame (local rotation), no joint centre moves more than
##              POP_M in the figure's frame in one frame
##   stick      the stick's shaft (grip to heel) never nearer than SHAFT_CLEAR to the axis of a thigh or a shin
##              (thirdjam's legs are about 7 cm thick there), while the stick is on the ice
##   puck       the puck socket rides on the blade: PUCK_BAND above the ice while the stick is on the ice
## TWO LEVELS. The bands below are what an eye wants (IDEAL). thirdjam's own figure does not keep all of them. On the
## gym's run (cores/rink/view/gym_hand.json, seed 5; ours stands where thirdjam's does within 0.2 mm on every frame
## of it) its blade's toe dips up to 4.9 cm under the ice at the far ends of the aim, a skate sinks up to 10.7 cm in a
## hard turn at speed, the stick arm turns up to 94 degrees in one frame when the aim crosses the body at its fastest,
## and in the full stride with the stick held at rest the shaft runs within a millimetre of a shin's axis (through the
## leg) on half of the frames. We port before we change, so the GATE is parity: on that run no more frames may break
## a band than thirdjam's own figure breaks, and none worse.

## check -> [frames thirdjam's own figure breaks the ideal band on the gym run, the worst it reaches]
## (blade: lowest m; skates: lowest m; pop: degrees in a frame; stick: least clearance m; puck: lowest m).
## Measured 23 Nov 2026. GYM_ALLOWED_ORACLE: the run as thirdjam's figure was given it in Unreal (no thirdjam game
## mode in that world: the brake's stop take never starts), the run the two figures were compared on.
## GYM_ALLOWED: the same hand with the game mode's part ported (the stop takes play): ours alone, not compared.
const GYM_ALLOWED_ORACLE: Dictionary = {"blade": [42, -0.0485], "skates": [158, -0.1068], "pop": [8, 93.74], "stick": [322, 0.0009], "puck": [1, 0.0128], "lengths": [0, 0.0]}
const GYM_ALLOWED: Dictionary = {"blade": [43, -0.0425], "skates": [144, -0.1068], "pop": [8, 94.62], "stick": [275, 0.0004], "puck": [1, 0.0186], "lengths": [0, 0.0]}

const BLADE_UNDER: float = 0.004
const BLADE_OVER: float = 0.06
const SKATE_BAND: float = 0.02
const SKATE_UNDER: float = 0.004
const BONE_STRETCH: float = 0.0005
const POP_DEG: float = 40.0
const POP_M: float = 0.20
const SHAFT_CLEAR: float = 0.045
const PUCK_BAND: Vector2 = Vector2(0.02, 0.11)

const LEG_BONES: Array = [["thigh_l", "calf_l"], ["calf_l", "foot_l"], ["thigh_r", "calf_r"], ["calf_r", "foot_r"]]
const CHECKS: Array = ["blade", "skates", "lengths", "pop", "stick", "puck"]

var _verts: Dictionary = {}        # slot -> [PackedVector3Array, PackedInt32Array bones, PackedFloat32Array weights, per]
var _binds: Array = []
var _bind_bone: PackedInt32Array = PackedInt32Array()
var _prev_q: Array = []
var _prev_p: Array = []
var _rest_len: PackedFloat32Array = PackedFloat32Array()


func _bind(fig: TLRigSkater) -> void:
	var mesh: Mesh = fig.mesh_instance().mesh
	var skin: Skin = fig.mesh_instance().skin
	var sk: Skeleton3D = fig.skeleton()
	for b: int in range(skin.get_bind_count()):
		var bi: int = skin.get_bind_bone(b)
		if bi < 0:
			bi = sk.find_bone(skin.get_bind_name(b))
		_bind_bone.append(bi)
		_binds.append(skin.get_bind_pose(b))
	for s: int in range(mesh.get_surface_count()):
		var slot: String = mesh.surface_get_name(s)
		if slot != "Stick" and slot != "Blade":
			continue
		var arr: Array = mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		_verts[slot] = [vs, bones, arr[Mesh.ARRAY_WEIGHTS], bones.size() / vs.size()]
	for b: int in range(TLRigSkaterPose.N):
		_rest_len.append((TLRigSkaterPose.rest_t[b] as Vector3).length())


## The lowest and (for the skates) per-side lowest skinned vertex of a slot, in the figure's frame.
func _lowest(fig: TLRigSkater, slot: String) -> Array:
	var d: Array = _verts[slot]
	var vs: PackedVector3Array = d[0]
	var bones: PackedInt32Array = d[1]
	var ws: PackedFloat32Array = d[2]
	var per: int = d[3]
	var pal: Array = []
	for b: int in range(_binds.size()):
		pal.append(fig.bone_xf(_bind_bone[b]) * (_binds[b] as Transform3D))
	var lo: float = INF
	var lo_left: float = INF
	var lo_right: float = INF
	var foot_l: int = TLRigSkaterPose.bone("foot_l")
	for v: int in range(vs.size()):
		var p: Vector3 = Vector3.ZERO
		var heavy: float = 0.0
		var heavy_bone: int = -1
		for j: int in range(per):
			var w: float = ws[v * per + j]
			if w > 0.0:
				p += (pal[bones[v * per + j]] as Transform3D * vs[v]) * w
				if w > heavy:
					heavy = w
					heavy_bone = _bind_bone[bones[v * per + j]]
		lo = minf(lo, p.y)
		# left or right by the bone that carries the vertex (the skates of slot Blade hang on foot_l / foot_r)
		if heavy_bone == foot_l:
			lo_left = minf(lo_left, p.y)
		else:
			lo_right = minf(lo_right, p.y)
	return [lo, lo_left, lo_right]


static func _seg_dist(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> float:
	# the distance between two segments
	var u: Vector3 = a1 - a0
	var v: Vector3 = b1 - b0
	var w: Vector3 = a0 - b0
	var a: float = u.dot(u)
	var b: float = u.dot(v)
	var c: float = v.dot(v)
	var d: float = u.dot(w)
	var e: float = v.dot(w)
	var den: float = a * c - b * b
	var s: float = clampf((b * e - c * d) / den, 0.0, 1.0) if den > 1e-9 else 0.0
	var t: float = clampf((b * s + e) / c, 0.0, 1.0) if c > 1e-9 else 0.0
	s = clampf((b * t - d) / a, 0.0, 1.0) if a > 1e-9 else 0.0
	return ((a0 + u * s) - (b0 + v * t)).length()


## One frame of the figure. `on_ice`: the stick is on the ice (the caller knows the driver's state);
## `skating`: he skates or stands with no take playing.
func measure(fig: TLRigSkater, on_ice: bool, skating: bool) -> Dictionary:
	if _verts.is_empty():
		_bind(fig)
	var out: Dictionary = {"on_ice": on_ice, "skating": skating}
	var blade: Array = _lowest(fig, "Stick")
	var skates: Array = _lowest(fig, "Blade")
	out["blade"] = snappedf(float(blade[0]), 0.0001)
	out["skate_l"] = snappedf(float(skates[1]), 0.0001)
	out["skate_r"] = snappedf(float(skates[2]), 0.0001)
	out["puck"] = snappedf(fig.socket_transform(&"puck_socket").origin.y, 0.0001)
	# bone lengths against rest
	var stretch: float = 0.0
	var p_now: Array = []
	var q_now: Array = fig.local_rotations()
	for b: int in range(TLRigSkaterPose.N):
		var x: Transform3D = fig.bone_xf(b)
		p_now.append(x.origin)
		var par: int = TLRigSkaterPose.parents[b]
		if par >= 0 and b != TLRigSkaterPose.PELVIS and b != TLRigSkaterPose.STICK:
			stretch = maxf(stretch, absf((x.origin - fig.bone_xf(par).origin).length() - _rest_len[b]))
	out["stretch"] = snappedf(stretch, 0.00001)
	# pops against the frame before
	var turn: float = 0.0
	var jump: float = 0.0
	var turn_bone: int = -1
	if _prev_q.size() == q_now.size():
		for b: int in range(TLRigSkaterPose.N):
			var ang: float = rad_to_deg((_prev_q[b] as Quaternion).angle_to(q_now[b] as Quaternion))
			if ang > turn:
				turn = ang
				turn_bone = b
			jump = maxf(jump, ((p_now[b] as Vector3) - (_prev_p[b] as Vector3)).length())
	_prev_q = q_now
	_prev_p = p_now
	out["turn_deg"] = snappedf(turn, 0.01)
	out["turn_bone"] = TLRigSkaterPose.bone_names[turn_bone] if turn_bone >= 0 else ""
	out["jump"] = snappedf(jump, 0.0001)
	# the shaft against the legs
	var stick: Transform3D = fig.bone_xf(TLRigSkaterPose.STICK)
	var grip: Vector3 = stick.origin
	var heel: Vector3 = stick * TLRigSkaterPose.from_ue_vec(TLRigSkater.HEEL_ON_STICK_UE)
	var clear: float = INF
	for pair: Array in LEG_BONES:
		clear = minf(clear, _seg_dist(grip, heel, fig.bone_xf(TLRigSkaterPose.bone(String(pair[0]))).origin, fig.bone_xf(TLRigSkaterPose.bone(String(pair[1]))).origin))
	out["shaft_clear"] = snappedf(clear, 0.0001)
	return out


## A run's frames against the bands: per check the frames that break it (count, the first, the worst value), and the
## extremes met, so that a band can be read against what the run did.
static func judge(rows: Array) -> Dictionary:
	var bad: Dictionary = {}
	for c: String in CHECKS:
		bad[c] = {"frames": 0, "first": -1, "worst": 0.0}
	var ext: Dictionary = {"blade_min": INF, "blade_max": -INF, "skate_min": INF, "skate_planted_max": -INF, "stretch_max": 0.0, "turn_max": 0.0, "turn_at": "",
		"jump_max": 0.0, "shaft_clear_min": INF, "puck_min": INF, "puck_max": -INF, "frames_on_ice": 0, "frames_skating": 0}
	for i: int in range(rows.size()):
		var r: Dictionary = rows[i]
		var f: int = int(r.get("f", i))
		var on_ice: bool = bool(r["on_ice"])
		var skating: bool = bool(r["skating"])
		if on_ice:
			ext["frames_on_ice"] = int(ext["frames_on_ice"]) + 1
			ext["blade_min"] = minf(float(ext["blade_min"]), float(r["blade"]))
			ext["blade_max"] = maxf(float(ext["blade_max"]), float(r["blade"]))
			ext["shaft_clear_min"] = minf(float(ext["shaft_clear_min"]), float(r["shaft_clear"]))
			ext["puck_min"] = minf(float(ext["puck_min"]), float(r["puck"]))
			ext["puck_max"] = maxf(float(ext["puck_max"]), float(r["puck"]))
			if float(r["blade"]) < -BLADE_UNDER or float(r["blade"]) > BLADE_OVER:
				_note(bad["blade"], f, float(r["blade"]))
			if float(r["shaft_clear"]) < SHAFT_CLEAR:
				_note(bad["stick"], f, float(r["shaft_clear"]))
			if float(r["puck"]) < PUCK_BAND.x or float(r["puck"]) > PUCK_BAND.y:
				_note(bad["puck"], f, float(r["puck"]))
		if skating:
			ext["frames_skating"] = int(ext["frames_skating"]) + 1
			var lo: float = minf(float(r["skate_l"]), float(r["skate_r"]))
			ext["skate_min"] = minf(float(ext["skate_min"]), lo)
			ext["skate_planted_max"] = maxf(float(ext["skate_planted_max"]), lo)
			if lo < -SKATE_UNDER or lo > SKATE_BAND:
				_note(bad["skates"], f, lo)
		ext["stretch_max"] = maxf(float(ext["stretch_max"]), float(r["stretch"]))
		if float(r["stretch"]) > BONE_STRETCH:
			_note(bad["lengths"], f, float(r["stretch"]))
		if float(r["turn_deg"]) > float(ext["turn_max"]):
			ext["turn_max"] = float(r["turn_deg"])
			ext["turn_at"] = "frame %d %s" % [f, r["turn_bone"]]
		ext["jump_max"] = maxf(float(ext["jump_max"]), float(r["jump"]))
		if float(r["turn_deg"]) > POP_DEG or float(r["jump"]) > POP_M:
			_note(bad["pop"], f, maxf(float(r["turn_deg"]), float(r["jump"]) * 100.0))
	var ok: bool = true
	for c: String in CHECKS:
		if int(bad[c]["frames"]) > 0:
			ok = false
	for k: String in ext.keys():
		if ext[k] is float:
			ext[k] = snappedf(float(ext[k]), 0.0001) if is_finite(float(ext[k])) else 0.0
	return {"ok": ok, "frames": rows.size(), "broken": bad, "met": ext}


## The gate on the gym's run: the run's verdict against thirdjam's own counts (5 % and a frame of slack) and worsts
## (a millimetre, a degree). Returns what is broken ("" = nothing).
static func gate(verdict: Dictionary, allowed_table: Dictionary = GYM_ALLOWED) -> String:
	var out: Array = []
	var met: Dictionary = verdict["met"]
	for c: String in CHECKS:
		var n: int = int(verdict["broken"][c]["frames"])
		var allowed: int = int(allowed_table[c][0])
		if n > int(ceil(float(allowed) * 1.05)) + (1 if allowed > 0 else 0):
			out.append("%s: %d frames break the band (thirdjam's own figure: %d), first at frame %d" % [c, n, allowed, int(verdict["broken"][c]["first"])])
	if float(met["blade_min"]) < float(allowed_table["blade"][1]) - 0.001:
		out.append("blade: %.4f m under the ice (thirdjam's: %.4f)" % [float(met["blade_min"]), float(allowed_table["blade"][1])])
	if float(met["skate_min"]) < float(allowed_table["skates"][1]) - 0.001:
		out.append("skates: %.4f m under the ice (thirdjam's: %.4f)" % [float(met["skate_min"]), float(allowed_table["skates"][1])])
	if float(met["turn_max"]) > float(allowed_table["pop"][1]) + 1.0:
		out.append("pop: a joint turns %.1f degrees in a frame at %s (thirdjam's: %.1f)" % [float(met["turn_max"]), met["turn_at"], float(allowed_table["pop"][1])])
	if float(met["shaft_clear_min"]) < float(allowed_table["stick"][1]) - 0.001:
		out.append("stick: the shaft %.4f m from a leg's axis (thirdjam's: %.4f)" % [float(met["shaft_clear_min"]), float(allowed_table["stick"][1])])
	return "; ".join(out)


static func _note(b: Dictionary, f: int, value: float) -> void:
	if int(b["frames"]) == 0:
		b["first"] = f
		b["worst"] = value
	b["frames"] = int(b["frames"]) + 1
	if absf(value) > absf(float(b["worst"])):
		b["worst"] = snappedf(value, 0.0001)
