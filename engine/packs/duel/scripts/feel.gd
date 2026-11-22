extends RefCounted
## THE feel-kit adapter (shift 2026-11-22 night, lane N2). Every call the duel makes to the kernel's feel kit (lane N1,
## kernel API 1.13: docs/shifts/2026-11-22-night/FEEL-KIT-API.md, engine/kernel/API.md) goes through this file and
## nowhere else, so a rename is a change here only. Since N1 landed (main 8e2202a) these are the kernel's calls:
##   impact(a, b, frames) / stop_left(f) / holding(a, b)   TLHit.impact: hit-stop on BOTH bodies and rigs; the pack holds
##                                             its own counters (wind-ups, buffers, the rival's mind) while it runs
##   hit / blocked / parried / clash / guard_break / wall_splat   TLHit.*: the mutual reactions of DUEL-PLAYBOOK 6.3.
##                                             contact.gd owns the RULES (which contact, how long each stun lasts,
##                                             damage, posture) and passes them as the kernel's tune keys (stop, frames,
##                                             attacker_frames, push, recoil); the kernel owns the bodies (freeze, push,
##                                             reaction clips: hit_<side>, block_stun, recoil, parried, guard_broken,
##                                             wall_splat). The kernel's own wall test decides a splat (StaticBody3D).
##   down(f, frames, from_dir)                 TLHit.down (falls arm A)
##   owns_body(f)                              TLHit.busy_left > 0: the kernel moves the body; the fighter writes no
##                                             velocity and no facing then
##   join(f) / leave(f) / pushbox_gap(a, b)    TLHit.pushbox at 0.45 m per duellist (scaled), N1's measurement
##   fade_occluders(a, b)                      ctx.cameras.fade_occluders with both duellists as subjects
##   clear(f)                                  TLHit.clear at a round restart
## Rig clocks: TLBiped.play_clip (1.14) runs a fight clip (14-30 frames) on the rules' frames (wind-ups 18-54) from a
## [move frame, clip frame] map, so the wind-up (the tell) lasts as the rules say; the pack's own rig.clip_t shim is
## gone. The posture break (BROKEN, not a kernel stun) is a pose too. slide() is only for the pack's own moves.

const DT: float = 1.0 / 60.0
const PUSHBOX: float = 0.45

var ctx
var stops: int = 0


func setup(c) -> void:
	ctx = c


## --- hit-stop ------------------------------------------------------------------------------------------------------
func impact(a, b, frames: int) -> void:
	if frames > 0:
		stops += 1
		TLHit.impact(a.body if a != null else null, b.body if b != null else null, frames)


func stop_left(f) -> int:
	return TLHit.stop_left(f.body) if f != null and is_instance_valid(f.body) else 0


## First call of every live tick: true while a hit-stop holds either duellist (the caller skips its tick).
func holding(a, b) -> bool:
	return stop_left(a) > 0 or stop_left(b) > 0


func owns_body(f) -> bool:
	return TLHit.busy_left(f.body) > 0


func clear(f) -> void:
	TLHit.clear(f.body)
	f.slide_n = 0
	f.anim_clip = &""


## --- the contacts (6.3): tune in the kernel's keys; the kernel plays the reaction clips -----------------------------
func hit(att, def, heavy: bool, counter: bool, tune: Dictionary, _pose: Dictionary) -> Dictionary:
	stops += 1
	def.anim_clip = &""
	return TLHit.hit(att.body, def.body, heavy, counter, tune)


func blocked(att, def, heavy: bool, tune: Dictionary, _pose: Dictionary) -> Dictionary:
	stops += 1
	def.anim_clip = &""
	if heavy:
		att.anim_clip = &""
	return TLHit.blocked(att.body, def.body, heavy, tune)


func parried(att, def, heavy: bool, tune: Dictionary, _pose: Dictionary) -> Dictionary:
	stops += 1
	att.anim_clip = &""
	def.anim_clip = &""
	return TLHit.parried(att.body, def.body, heavy, tune)


func clash(a, b, a_heavy: bool, b_heavy: bool, tune: Dictionary, _pose: Dictionary) -> Dictionary:
	stops += 1
	a.anim_clip = &""
	b.anim_clip = &""
	return TLHit.clash(a.body, b.body, a_heavy, b_heavy, tune)


## A bash that lands; the result's defender stun says whether the kernel found the wall behind him (&"wallsplat").
func guard_break(att, def, tune: Dictionary, _pose: Dictionary) -> Dictionary:
	stops += 1
	def.anim_clip = &""
	return TLHit.guard_break(att.body, def.body, tune)


func wall_splat(def, wall_normal: Vector3, att, tune: Dictionary, _pose: Dictionary) -> Dictionary:
	stops += 1
	def.anim_clip = &""
	return TLHit.wall_splat(def.body, wall_normal, att.body if att != null else null, int(tune.get("frames", 60)), {"stop": int(tune["stop"])} if tune.has("stop") else {})


## The kernel's stun on a fighter now (&"" none): contact.gd reads a knock that met the wall (&"wallsplat").
func stun_of(f) -> StringName:
	return TLHit.stun_of(f.body)


func stun_left(f) -> int:
	return TLHit.stun_left(f.body)


func down(f, frames: int, from_dir: Vector3) -> void:
	f.anim_clip = &""
	TLHit.down(f.body, frames, from_dir)


## --- pushbox and camera --------------------------------------------------------------------------------------------
func join(f) -> void:
	TLHit.pushbox(f.body, true, pushbox_r(f))


func leave(f) -> void:
	TLHit.pushbox(f.body, false)


func pushbox(_a, _b) -> void:
	pass                                            # the kernel's pushbox runs after every other node


func pushbox_gap(a, _b) -> float:
	var g: float = TLHit.pushbox_gap(a.body)
	return g if g < 1000.0 else -1.0


## 0.45 m at scale 1: the big-headed figures lean heads and arms into a strike (N1: they overlap at 0.32).
static func pushbox_r(f) -> float:
	return PUSHBOX * f.radius / 0.3


func fade_occluders(a, b) -> void:
	ctx.cameras.fade_occluders(true, {"view": &"duel", "subjects": [a.body, b.body]})


## --- rig clocks (pack-side) ----------------------------------------------------------------------------------------
## A state pose through the kernel's clip clock (TLBiped.play_clip, API 1.14; engine need E1): the clip's time runs
## from `anim` ([state frame, clip frame] knots; a negative state frame counts back from `frames`, the state's length;
## [] = the clip's own pace). `start` > 0 joins the timeline at that frame (a heavy that turns into the charged heavy
## mid wind-up). An empty clip returns the rig to its locomotion (and drops a held block).
func pose(f, clip: StringName, anim: Array, frames: int, strength: float = -1.0, blend: float = 0.034, start: int = 0) -> void:
	if f.rig == null:
		return
	if strength >= 0.0 and String(clip).begins_with("hit_"):
		_size(f, clip, strength)
	f.anim_clip = clip
	f.body.play_clip(clip, timeline(anim, frames, start), blend if clip != &"" else 0.1)


## The kernel's timeline from a duel map: negative knots resolved against `frames`, shifted to start at `start`.
static func timeline(anim: Array, frames: int, start: int = 0) -> Array:
	if anim.is_empty():
		return []
	var out: Array = []
	if start > 0:
		out.append([0, clip_frame(anim, float(start), frames)])
	for p: Array in anim:
		var x: float = float(p[0]) if float(p[0]) >= 0.0 else float(frames) + float(p[0])
		x -= float(start)
		if x < 0.0 or (start > 0 and x <= 0.0):
			continue
		if not out.is_empty() and x <= float(out[-1][0]):
			continue                                  # the kernel takes rising frames only
		out.append([x, float(p[1])])
	return out


## The duellist's stance between moves: the fight clips' guard (fists up, left foot ahead) held, legs on the gait.
func stance(f) -> void:
	pose(f, &"strike", [[0, 0.0], [1000000, 0.0]], 0, -1.0, 0.12)


## Piecewise linear [frame, clip frame] map; negative frames are counted back from `length`.
static func clip_frame(anim: Array, t: float, length: int) -> float:
	var prev_x: float = 0.0
	var prev_y: float = float(anim[0][1])
	for p: Array in anim:
		var x: float = float(p[0]) if float(p[0]) >= 0.0 else float(length) + float(p[0])
		var y: float = float(p[1])
		if t <= x:
			if x <= prev_x:
				return y
			return lerpf(prev_y, y, (t - prev_x) / (x - prev_x))
		prev_x = x
		prev_y = y
	return prev_y


## An exact slide for the pack's own moves: `metres` along `dir` over `frames`, fastest first, added to the walk.
## The weapon's arc (TLHit.swing_trail, API 1.15; engine need E2b): weight 0 = a light's thin quick flick (0.12 m, 5
## samples), 1 = a heavy's broad slow sweep (0.36 m, 12); follows the weapon's tip; hit-stop holds it.
func trail(f, weight: float, frames: int, color: Variant = "white", width: float = -1.0) -> void:
	if f.tip == null:
		return
	var o: Dictionary = {"node": f.tip, "color": color}
	if width > 0.0:
		o["width"] = width
	TLHit.swing_trail(f.body, weight, frames, o)


func slide(f, dir: Vector3, metres: float, frames: int) -> void:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.001 or metres <= 0.0 or frames <= 0:
		return
	f.slide_dir = d.normalized()
	f.slide_m = metres
	f.slide_n = frames
	f.slide_i = 0


static func side_of(f, from_dir: Vector3) -> String:
	var basis: Basis = f.body.basis.orthonormalized()
	var local: Vector3 = basis.inverse() * Vector3(from_dir.x, 0.0, from_dir.z)
	if absf(local.x) > absf(local.z):
		return "right" if local.x > 0.0 else "left"
	return "front" if local.z <= 0.0 else "back"


func _size(f, clip: StringName, strength: float) -> void:
	if f.rig != null and f.rig.has_method("_size_hit"):
		f.rig._size_hit(clip, strength, 0)
