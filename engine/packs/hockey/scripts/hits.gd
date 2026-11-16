extends RefCounted
## Hits (H2): body check (F) and cross-check (C), created by main.gd, no class_name. Numbers in data/tuning.json "hits".
## Body check: a skater WITHOUT the puck meets an opponent inside check_reach in his front cone. The closing speed
## along the line between the two bodies decides: under bump_speed a bump (both keep skating), up to knock_speed a
## stumble (the victim loses the puck, is slowed and cannot take it for stumble_frames), above it a knockdown (down
## for frames by the speed, the puck comes loose, then he gets up). A man standing still and bracing (holding the
## check key, or a drill's brace) holds a hit from his side: a bump at most. The carrier cannot check.
## Cross-check: a stick shove inside cross_reach: it moves the man and takes the puck off him; never a knockdown.
## Nothing is drawn: the figures show it. H7: the kernel's TLBiped does the body: `down(frames)` (the fall, lying, the rise),
## `stumble(frames, lean)` (a third of the intent, a side lean), `shove(impulse)` (bump, push, lunge); the hitter's `shoot`
## swing for the cross-check is the pack's.

const CLASSES: Array = ["none", "bump", "stumble", "knockdown"]

var api
var skaters: Dictionary = {}
var teams: Dictionary = {}
var order: Array = []
var cfg: Dictionary = {}
var ready_at: Dictionary = {}         ## id -> frame his next check or cross-check may come
var braced: Dictionary = {}           ## id -> true while he braces this frame
var counts: Dictionary = {}           ## class -> count, by side: {"blue": {...}, "red": {...}} (hits given)
var down_frames: Dictionary = {}      ## side -> frames its skaters spent down (summed over its skaters)
var side_down: Dictionary = {}        ## side -> frames in which at least one of its skaters was down
var last_hit: Dictionary = {}
var tries: Dictionary = {}             ## H7: id -> checks and cross-checks tried (whiffs included)
var by_id: Dictionary = {}            ## id -> checks and cross-checks he landed
var events: Array = []                ## [kind, hitter, victim] since main drained it
var _now: int = 0
var enabled: bool = true              ## H3: a mode without checks (pond): F and C do nothing


func setup(tune: Dictionary, a, sk: Dictionary, tm: Dictionary, ord: Array) -> void:
	cfg = tune["hits"]
	api = a
	skaters = sk
	teams = tm
	order = ord
	for id: String in order:
		ready_at[id] = 0
		by_id[id] = 0
		tries[id] = 0
		braced[id] = false
	for side: String in ["blue", "red"]:
		counts[side] = {"bump": 0, "stumble": 0, "knockdown": 0, "cross": 0}
		down_frames[side] = 0
		side_down[side] = 0


func _f(k: String) -> float:
	return float(cfg[k])


func tick(frame: int) -> void:
	_now = frame
	for id: String in order:
		braced[id] = false


func is_down(id: String) -> bool:
	return (skaters[id] as TLBiped).is_down()


func is_stumbling(id: String) -> bool:
	return (skaters[id] as TLBiped).is_stumbling()


## May he act (skate, take the puck, check)? Not while down (rising included) or stumbling.
func can_act(id: String) -> bool:
	var sk: TLBiped = skaters[id]
	return not sk.is_down() and not sk.is_stumbling()


func can_check(id: String) -> bool:
	return enabled and can_act(id) and api.carrier != id and _now >= int(ready_at[id])


func _vel(id: String) -> Vector3:
	var v: Vector3 = (skaters[id] as TLBiped).velocity
	return Vector3(v.x, 0.0, v.z)


## The opponent nearest in his front cone inside `reach`, or "".
func target(id: String, reach: float, cone_deg: float, stick: bool = false) -> String:
	var me: Vector3 = api.pos_of(id)
	var f: Vector3 = api.stick_of(id) if stick else api.fwd_of(id)
	var best: String = ""
	var best_d: float = reach
	for oid: String in order:
		if str(teams[oid]) == str(teams[id]) or is_down(oid):
			continue
		var to: Vector3 = api.pos_of(oid) - me
		var d: float = to.length()
		if d <= best_d and (d < 0.05 or f.dot(to.normalized()) >= cos(deg_to_rad(cone_deg))):
			best = oid
			best_d = d
	return best


## The closing speed of hitter on victim along the line between them (m/s, > 0 = closing).
func closing(hitter: String, victim: String) -> float:
	var n: Vector3 = api.pos_of(victim) - api.pos_of(hitter)
	if n.length() < 0.01:
		return 0.0
	return (_vel(hitter) - _vel(victim)).dot(n.normalized())


## The outcome class by closing speed, before the brace: 1 bump, 2 stumble, 3 knockdown.
func class_of(c: float) -> int:
	if c >= _f("knock_speed"):
		return 3
	if c >= _f("bump_speed"):
		return 2
	return 1


func down_frames_for(c: float) -> int:
	return int(clampf(_f("down_frames_min") + _f("down_frames_per_mps") * (c - _f("knock_speed")), _f("down_frames_min"), _f("down_frames_max")))


func _is_braced(victim: String, n: Vector3) -> bool:
	if not bool(braced[victim]):
		return false
	if _vel(victim).length() > _f("brace_speed"):
		return false
	return absf(api.fwd_of(victim).dot(n)) < _f("brace_side_dot")


func try_check(id: String) -> String:
	if not can_check(id):
		return ""
	tries[id] = int(tries[id]) + 1
	var v: String = target(id, _f("check_reach"), _f("check_cone_deg"))
	if v == "":
		ready_at[id] = _now + int(_f("whiff_cooldown_frames"))
		return ""
	ready_at[id] = _now + int(_f("check_cooldown_frames"))
	var n: Vector3 = (api.pos_of(v) - api.pos_of(id)).normalized()
	var c: float = closing(id, v)
	var k: int = class_of(c)
	var held: bool = _is_braced(v, n)
	if held:
		k = 1
	var hitter: TLBiped = skaters[id]
	var victim: TLBiped = skaters[v]
	hitter.shove(n * _f("lunge_speed") * hitter.body_mass)
	var side: String = str(teams[id])
	var lying: int = 0
	match k:
		1:
			victim.shove(n * maxf(c, 0.0) * _f("bump_push") * victim.body_mass)
		2:
			victim.shove(n * maxf(c, 0.0) * _f("stumble_push") * victim.body_mass)
			var lean: float = _f("stumble_lean") * (1.0 if victim.global_transform.basis.x.dot(n) > 0.0 else -1.0)
			victim.stumble(int(_f("stumble_frames")), lean)
			_lose_puck(v, n)
		3:
			victim.shove(n * maxf(c, 0.0) * _f("stumble_push") * victim.body_mass)
			lying = down_frames_for(c)
			victim.down(lying)
			_lose_puck(v, n)
	counts[side][CLASSES[k]] = int(counts[side][CLASSES[k]]) + 1
	by_id[id] = int(by_id[id]) + 1
	last_hit = {"by": id, "on": v, "class": CLASSES[k], "closing": snappedf(c, 0.001), "frame": _now, "braced": held}
	if k == 3:
		last_hit["down_frames"] = lying
		last_hit["down_with_rise"] = victim.down_frames_left()
	events.append([CLASSES[k], id, v])
	return CLASSES[k]


func try_cross(id: String) -> bool:
	if not can_check(id):
		return false
	tries[id] = int(tries[id]) + 1
	var v: String = target(id, _f("cross_reach"), _f("cross_cone_deg"), true)
	ready_at[id] = _now + int(_f("cross_cooldown_frames"))
	if v == "":
		return false
	var n: Vector3 = (api.pos_of(v) - api.pos_of(id)).normalized()
	var vb: TLBiped = skaters[v]
	vb.shove(n * _f("cross_push_speed") * vb.body_mass)
	_lose_puck(v, n)
	_clip(id, &"shoot")
	counts[str(teams[id])]["cross"] = int(counts[str(teams[id])]["cross"]) + 1
	by_id[id] = int(by_id[id]) + 1
	last_hit = {"by": id, "on": v, "class": "cross", "closing": snappedf(closing(id, v), 0.001), "frame": _now, "braced": false}
	events.append(["cross", id, v])
	return true


func _lose_puck(v: String, n: Vector3) -> void:
	if api.carrier == v:
		api.knock_loose(v, _vel(v) * 0.5 + n * _f("loose_puck_speed"))


func _clip(id: String, clip: StringName) -> void:
	var r = (skaters[id] as TLBiped).rig
	if r != null:
		r.play(clip)


## After everybody chose a move: a man down lies still, then gets up; a stumble ends. Counts frames down by side.
## H7: the kernel keeps a downed man down (move and brake ignored) and gets him up; here only the counting.
func enforce() -> void:
	var any: Dictionary = {}
	for id: String in order:
		if (skaters[id] as TLBiped).is_down():
			down_frames[str(teams[id])] = int(down_frames[str(teams[id])]) + 1
			any[str(teams[id])] = true
	for side: String in any:
		side_down[side] = int(side_down[side]) + 1


## Speed factor this frame: 1 (H7: a stumble's slowing is the kernel's, a third of the intent).
func speed_scale(_id: String) -> float:
	return 1.0


func reset() -> void:
	pass


func state() -> Dictionary:
	var s: Dictionary = {"given": counts.duplicate(true), "by": by_id.duplicate(), "tries": tries.duplicate(), "down_frames": down_frames.duplicate(), "side_down": side_down.duplicate()}
	var dn: Dictionary = {}
	var st: Dictionary = {}
	for id: String in order:
		var sk: TLBiped = skaters[id]
		if sk.is_down():
			dn[id] = sk.down_frames_left()
		elif sk.is_stumbling():
			st[id] = 1
	if not dn.is_empty():
		s["down"] = dn
	if not st.is_empty():
		s["stumbling"] = st
	if not last_hit.is_empty():
		s["last"] = last_hit.duplicate()
	return s
