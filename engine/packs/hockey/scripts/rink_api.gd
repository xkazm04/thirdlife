extends RefCounted
## Possession (H1): who has the puck, carrying it, shooting, passing and poking. Created by main.gd, no class_name.
## The rule: a loose puck that comes inside a skater's reach circle (or that his body skates through) becomes his on
## that frame, whatever he faces, at any speed, with any button held. He carries it at his stick side (TLBall.hold)
## until he shoots, passes, is poked or (H2) is hit. Every number is in data/tuning.json "shoot" and "carry".

var puck: TLBall
var skaters: Dictionary = {}
var teams: Dictionary = {}
var order: Array = []
var speed: float = 18.0                ## shot speed, m/s
var cooldown_frames: int = 24
var reach: float = 1.1                 ## carry: the reach circle's radius, m
var offset: Vector3 = Vector3(0.3, 0.07, -0.75)
var own_lock_frames: int = 12
var own_lock_speed: float = 4.0
var flight_take_speed: float = 7.0
var flight_take_dist: float = 0.6
var pass_speed: float = 14.0
var pass_cone_dot: float = 0.5
var pass_lead_max_frames: int = 60
var poke_reach: float = 1.7
var poke_cooldown_frames: int = 30
var poke_speed: float = 4.0
var poke_lock_frames: int = 20
var carry_speed_scale: float = 0.92
var sprint_speed_scale: float = 1.25
var rink_half: Vector2 = Vector2(30.0, 15.0)
var rink_corner: float = 5.0
var rink_margin: float = 0.35

var carrier: String = ""               ## "" = the puck is loose
var carry_since: int = 0
var behind_frames: int = 0             ## H6: frames the carrier has stayed in the zone behind his own net
var behind_limit: int = 90
var net_zone_half: float = 3.5
var own_goal_x: Dictionary = {}         ## team -> x of its own goal line
var ease_frames: int = 8               ## H9: a taken puck slides out to the blade over this many frames (no snap)
var ease_left: int = 0
var ease_from: Vector3 = Vector3.ZERO
var carry_min: float = 1.0             ## H9a: the nearest the puck is carried to his centre (clear of his body)
var hold_at: Vector3 = Vector3.ZERO      ## where on him the puck is held now (the stick side, or another side at the boards)
var last_release: Dictionary = {}      ## {kind: shot|pass|poked|board, by, team, frame}; empty after a face-off
var shots: Dictionary = {}
var passes: Dictionary = {}
var pokes: Dictionary = {}
var takes: Dictionary = {}
var events: Array = []                 ## [kind, id] since main last drained it (kind: shot, pass, poke, take)
var base_speed: Dictionary = {}
var sprinting: Dictionary = {}
var _now: int = 0
var _ready_at: Dictionary = {}
var _poke_at: Dictionary = {}
var stick_dir: Dictionary = {}          ## H4: id -> where his stick points (the human's aim); absent = his facing
var poke_cone_dot: float = -1.0         ## H4: a poke with a stick direction reaches only inside this cone
var hits = null:                       ## scripts/hits.gd (H2): a man down or stumbling cannot take the puck
	get:                                 # hunt2 A8: held weakly (hits.gd holds this helper; main.gd holds both), so the
		return _hits_ref.get_ref() if _hits_ref != null else null   # pair is freed with the pack, never a cycle
	set(v):
		_hits_ref = weakref(v) if v != null else null
var _hits_ref: WeakRef = null


func setup(tune: Dictionary, p: TLBall, sk: Dictionary, tm: Dictionary, ord: Array) -> void:
	var s: Dictionary = tune["shoot"]
	speed = float(s["speed"])
	cooldown_frames = int(round(float(s["cooldown_s"]) * 60.0))
	var c: Dictionary = tune["carry"]
	reach = float(c["reach"])
	offset = Vector3(float(c["offset"][0]), float(c["offset"][1]), float(c["offset"][2]))
	own_lock_frames = int(c["own_lock_frames"])
	own_lock_speed = float(c["own_lock_speed"])
	flight_take_speed = float(c["flight_take_speed"])
	flight_take_dist = float(c["flight_take_dist"])
	pass_speed = float(c["pass_speed"])
	pass_cone_dot = cos(deg_to_rad(float(c["pass_cone_deg"])))
	pass_lead_max_frames = int(c["pass_lead_max_frames"])
	poke_reach = float(c["poke_reach"])
	poke_cooldown_frames = int(c["poke_cooldown_frames"])
	poke_speed = float(c["poke_speed"])
	poke_lock_frames = int(c["poke_lock_frames"])
	carry_speed_scale = float(c["carry_speed_scale"])
	sprint_speed_scale = float(tune["skater_sprint_scale"])
	carry_min = float(c["carry_min"])
	ease_frames = int(c["ease_frames"])
	behind_limit = int(c["behind_net_frames"])
	net_zone_half = float(c["behind_net_half_width"])
	own_goal_x = {"blue": float(tune["goals"]["blue"][0]), "red": float(tune["goals"]["red"][0])}
	var r: Dictionary = tune["rink"]
	rink_half = Vector2(float(r["half_length"]), float(r["half_width"]))
	rink_corner = float(r["corner_r"])
	rink_margin = float(r["margin"])
	puck = p
	skaters = sk
	teams = tm
	order = ord
	for id: String in order:
		shots[id] = 0
		passes[id] = 0
		pokes[id] = 0
		takes[id] = 0
		_ready_at[id] = 0
		_poke_at[id] = 0
		base_speed[id] = (skaters[id] as TLBiped).skate_speed
		sprinting[id] = false


func tick(frame: int) -> void:
	_now = frame


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func pos_of(id: String) -> Vector3:
	return _flat((skaters[id] as Node3D).global_position)


func fwd_of(id: String) -> Vector3:
	return _flat((skaters[id] as TLBiped).forward()).normalized()


## H4: where a skater's stick points: the aim's heading when the human has one, else the way he faces (as before H4).
func stick_of(id: String) -> Vector3:
	if stick_dir.has(id):
		return stick_dir[id]
	return fwd_of(id)


func puck_pos() -> Vector3:
	return _flat(puck.global_position)


## Distance from a skater to the puck's path of the last physics step (a fast puck cannot jump his circle).
func dist_to_puck(id: String) -> float:
	var step: Array = puck.last_step()
	var a: Vector3 = _flat(step[0])
	var b: Vector3 = _flat(step[1])
	var p: Vector3 = pos_of(id)
	var ab: Vector3 = b - a
	var t: float = 0.0 if ab.length_squared() < 1e-8 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func in_reach(id: String) -> bool:
	return carrier == "" and dist_to_puck(id) <= reach


## Whether the loose puck may become his now (the locks after a release, the rule for a puck in flight).
func may_take(id: String, d: float) -> bool:
	if last_release.is_empty():
		return true
	var age: int = _now - int(last_release["frame"])
	var kind: String = str(last_release["kind"])
	var by: String = str(last_release["by"])
	var spd: float = _flat(puck.linear_velocity).length()
	if kind == "poked":
		return id != by or age >= poke_lock_frames
	if kind == "hit":
		return id != by or age >= poke_lock_frames
	if id == by:
		return age >= own_lock_frames or spd < own_lock_speed
	if kind == "pass" and str(teams[id]) == str(last_release["team"]):
		return true
	return spd < flight_take_speed or d < flight_take_dist


## Called once a tick before anybody acts: the carried puck stays on the ice, a loose one becomes the nearest
## eligible skater's whose reach it is inside.
func update_possession() -> void:
	if carrier != "":
		# H6: a carrier who stays behind his own net longer than behind_net_frames loses the puck's protection there:
		# an opponent whose reach it is in takes it (else a match could stall there until the time limit)
		var gx: float = float(own_goal_x[str(teams[carrier])])
		var pp: Vector3 = puck_pos()
		if (pp.x - gx) * signf(gx) > 0.0 and absf(pp.z) < net_zone_half:
			behind_frames += 1
		else:
			behind_frames = 0
		if behind_frames > behind_limit:
			var best_o: String = ""
			var best_od: float = reach
			for oid: String in order:
				if str(teams[oid]) == str(teams[carrier]) or (hits != null and not hits.can_act(oid)):
					continue
				var od: float = pos_of(oid).distance_to(pp)
				if od <= best_od:
					best_o = oid
					best_od = od
			if best_o != "":
				behind_frames = 0
				give(best_o)
				return
			if behind_frames > behind_limit * 2:
				# H9a: nobody can reach him there (the puck on his blade, 2.8 m out, can lie in the corner past the net):
				# he loses it in front of his net; he may not take it back for poke_lock_frames (the lock of a hit)
				var by: String = carrier
				behind_frames = 0
				_release("hit", by, Vector3.ZERO)
				puck.place(Vector3(gx - signf(gx) * 2.0, 0.07, clampf(pp.z, -3.0, 3.0)))
				return
		# at the boards the stick side would be outside them: he moves the puck to a side of him that is inside
		# (a release there gave it straight back to him every second frame, a loop a person reads as a frozen game;
		# a puck tucked UNDER him was a kinematic body inside his capsule and shoved him through the boards)
		# H9a: the puck rides on the stick's blade (carry.offset: the rig's blade socket measured on the ice), turned with
		# the stick when the human aims (H4's stick heading); at the boards it comes in along the stick, then to his front
		var tf: Transform3D = (skaters[carrier] as Node3D).global_transform
		var y: float = offset.y
		var base: Vector3 = offset
		if stick_dir.has(carrier):
			var turn: float = fwd_of(carrier).signed_angle_to(stick_dir[carrier], Vector3.UP)
			base = offset.rotated(Vector3.UP, turn)
			base.y = y
		if ease_left > 0:
			# H9: the take eases the puck from where it was (inside his ring) out to the blade
			base = ease_from.lerp(base, 1.0 - float(ease_left) / float(maxi(ease_frames, 1)))
			base.y = y
			ease_left -= 1
		var want: Vector3 = base
		if not _inside(_flat(tf * base)):
			want = Vector3(0.0, y, carry_min)
			var cm: float = carry_min
			for c: Vector3 in [Vector3(base.x * 0.8, y, base.z * 0.8), Vector3(base.x * 0.6, y, base.z * 0.6), Vector3(base.x * 0.45, y, base.z * 0.45),
					Vector3(-base.x, y, base.z), Vector3(0.0, y, -cm), Vector3(-cm, y, 0.0), Vector3(cm, y, 0.0), Vector3(0.0, y, cm)]:
				if Vector2(c.x, c.z).length() >= cm - 0.01 and _inside(_flat(tf * c)):
					want = c
					break
		if want != hold_at:
			hold_at = want
			puck.hold(skaters[carrier], want)
		return
	var best: String = ""
	var best_d: float = 1e9
	for id: String in order:
		if hits != null and not hits.can_act(id):
			continue
		var d: float = dist_to_puck(id)
		if d <= reach and d < best_d and may_take(id, d):
			best = id
			best_d = d
	if best != "":
		give(best)


func give(id: String) -> void:
	if carrier != "":
		_drop()
	carrier = id
	carry_since = _now
	behind_frames = 0
	takes[id] = int(takes[id]) + 1
	var local: Vector3 = (skaters[id] as Node3D).global_transform.affine_inverse() * puck.global_position
	local.y = offset.y
	if Vector2(local.x, local.z).length() < carry_min:
		local = Vector3(local.x, offset.y, local.z).normalized() * carry_min if Vector2(local.x, local.z).length() > 0.01 else Vector3(0.0, offset.y, -carry_min)
		local.y = offset.y
	ease_from = local
	ease_left = ease_frames
	hold_at = local
	puck.hold(skaters[id], local)
	events.append(["take", id])


func _drop() -> void:
	carrier = ""
	puck.release(Vector3.ZERO)


## A face-off or a drill: nobody has it, no lock.
func reset() -> void:
	if carrier != "":
		_drop()
	last_release = {}


func _release(kind: String, by: String, vel: Vector3) -> void:
	carrier = ""
	puck.release(vel)
	last_release = {"kind": kind, "by": by, "team": str(teams[by]), "frame": _now}


## Sets each skater's top speed for this frame: carrying is slower, sprinting faster (numbers in data).
func apply_speeds() -> void:
	for id: String in order:
		var v: float = float(base_speed[id])
		if id == carrier:
			v *= carry_speed_scale
		if bool(sprinting[id]):
			v *= sprint_speed_scale
		if hits != null:
			v *= hits.speed_scale(id)
		(skaters[id] as TLBiped).skate_speed = v


func can_shoot(id: String) -> bool:
	return carrier == id and _now >= int(_ready_at[id])


func try_shoot(id: String) -> bool:
	if not can_shoot(id):
		return false
	_release("shot", id, stick_of(id) * speed)
	_clip(id, &"shoot")
	_ready_at[id] = _now + cooldown_frames
	shots[id] = int(shots[id]) + 1
	events.append(["shot", id])
	return true


## The mate nearest his facing inside the pass cone, or "".
func pass_target(id: String) -> String:
	var me: Vector3 = pos_of(id)
	var f: Vector3 = stick_of(id)
	var best: String = ""
	var best_dot: float = pass_cone_dot
	for mid: String in order:
		if mid == id or str(teams[mid]) != str(teams[id]):
			continue
		var to: Vector3 = pos_of(mid) - me
		if to.length() < 1.5:
			continue
		var dt: float = f.dot(to.normalized())
		if dt >= best_dot:
			best_dot = dt
			best = mid
	return best


## Where a pass to `mid` should go: where he will be when it arrives (two refinements, lead bounded in data).
func lead_point(mid: String) -> Vector3:
	var from: Vector3 = puck_pos()
	var mp: Vector3 = pos_of(mid)
	var mv: Vector3 = _flat((skaters[mid] as TLBiped).velocity)
	var tgt: Vector3 = mp
	for i: int in 2:
		var t: float = minf(from.distance_to(tgt) / pass_speed, float(pass_lead_max_frames) / 60.0)
		tgt = mp + mv * t
	return tgt


func try_pass(id: String) -> bool:
	if carrier != id:
		return false
	var mid: String = pass_target(id)
	var dir: Vector3 = stick_of(id)
	if mid != "":
		var to: Vector3 = lead_point(mid) - puck_pos()
		if to.length() > 0.1:
			dir = to.normalized()
	_release("pass", id, dir * pass_speed)
	_clip(id, &"pass")
	if mid != "":
		last_release["to"] = mid
	passes[id] = int(passes[id]) + 1
	events.append(["pass", id])
	return true


## The mate a pass is meant for skates to meet it while it is loose and moving: towards the nearest point of its
## path ahead of the puck. Vector3.ZERO when he is not receiving.
func receive_dir(id: String) -> Vector3:
	if carrier != "" or last_release.is_empty() or str(last_release["kind"]) != "pass" or str(last_release.get("to", "")) != id:
		return Vector3.ZERO
	if _now - int(last_release["frame"]) > pass_lead_max_frames * 2:
		return Vector3.ZERO
	var v: Vector3 = _flat(puck.linear_velocity)
	if v.length() < 1.0:
		return Vector3.ZERO
	var me: Vector3 = pos_of(id)
	var pp: Vector3 = puck_pos()
	var u: Vector3 = v.normalized()
	var along: float = maxf((me - pp).dot(u), 0.0)
	var meet: Vector3 = pp + u * along
	var to: Vector3 = meet - me
	return to.normalized() if to.length() > 0.2 else Vector3.ZERO


## A hit takes the puck off him: loose, with a velocity (H2).
func knock_loose(victim: String, vel: Vector3) -> void:
	if carrier != victim:
		return
	_release("hit", victim, vel)


func can_poke(id: String) -> bool:
	return carrier != "" and carrier != id and str(teams[carrier]) != str(teams[id]) and _now >= int(_poke_at[id]) \
		and pos_of(id).distance_to(puck_pos()) <= poke_reach


## A stick poke at an opponent's carried puck: it comes loose towards the poker. A miss costs the cooldown too.
func try_poke(id: String) -> bool:
	if _now < int(_poke_at[id]) or carrier == "" or carrier == id or str(teams[carrier]) == str(teams[id]):
		return false
	_poke_at[id] = _now + poke_cooldown_frames
	if pos_of(id).distance_to(puck_pos()) > poke_reach:
		return false
	if stick_dir.has(id) and pos_of(id).distance_to(puck_pos()) > 0.05 and (stick_dir[id] as Vector3).dot((puck_pos() - pos_of(id)).normalized()) < poke_cone_dot:
		return false
	var victim: String = carrier
	var dir: Vector3 = pos_of(id) - puck_pos()
	dir = dir.normalized() if dir.length() > 0.05 else -fwd_of(victim)
	_release("poked", victim, dir * poke_speed)
	_poke_at[victim] = maxi(int(_poke_at[victim]), _now + poke_lock_frames)     # no poke straight back
	pokes[id] = int(pokes[id]) + 1
	events.append(["poke", id])
	return true


func _clip(id: String, clip: StringName) -> void:
	var r = (skaters[id] as TLBiped).rig
	if r != null:
		r.play(clip)


func _inside(p: Vector3) -> bool:
	var hx: float = rink_half.x - rink_margin
	var hz: float = rink_half.y - rink_margin
	if absf(p.x) > hx or absf(p.z) > hz:
		return false
	var r: float = rink_corner - rink_margin
	var dx: float = maxf(absf(p.x) - (hx - r), 0.0)
	var dz: float = maxf(absf(p.z) - (hz - r), 0.0)
	return Vector2(dx, dz).length() <= r


## Possession for _pack_state(): absent values are omitted.
func state() -> Dictionary:
	var s: Dictionary = {"takes": takes.duplicate(), "passes": passes.duplicate(), "pokes": pokes.duplicate()}
	if carrier != "":
		s["carrier"] = carrier
		s["team"] = str(teams[carrier])
		s["since"] = carry_since
	if not last_release.is_empty():
		s["last"] = last_release.duplicate()
	return s


const GOAL_TOP := 1.55   ## the crossbar: data/venue.json's goals stand at y 0.05 and are 1.5 m high


## H11 (moved from main.gd in H13, its 600-line limit): the side that scores when the puck's centre lies in a goal volume (the trigger's box: 1.5 m deep behind the line,
## the goal's width, under the goal's crossbar), else "". hunt2 A7: a puck flying over the net is no goal.
func goal_by_position(g: Dictionary) -> String:
	var p: Vector3 = puck.position   # the pack's own coordinates (the goals' too), wherever a world puts the pack
	for side: String in ["blue", "red"]:
		var gx: float = float(g[side][0])
		if absf(p.x - (gx + signf(gx) * 0.75)) <= 0.75 and absf(p.z) <= float(g["half_width"]) and p.y <= GOAL_TOP:
			return "red" if side == "blue" else "blue"
	return ""
