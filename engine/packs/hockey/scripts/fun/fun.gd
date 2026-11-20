extends RefCounted
## L5 (21 Nov): the fun layer. What a hit, a goal and the end of a match feel like; created by main.gd, no class_name;
## g = main. Numbers in data/tuning.json "fun"; the play camera is scripts/fun/cam.gd ("follow").
##   Hit-stop: a body check whose closing speed is at least stop_closing freezes the game for stop_frames (more for a harder
##     hit): every skater's and the clock's physics processing is off and a loose puck is frozen with its velocity kept,
##     so the picture holds at the contact; then everything goes on exactly where it was. Counted in physics frames.
##   Shake: ctx.cameras.shake scaled by the closing speed; an ice burst at the contact and a squash of the victim's figure.
##   Goal moment: the pause after a goal (pause_s) holds the net for hold_frames, then replays the shot in slow motion
##     (the bodies' recorded places, interpolated, slow = the pause's frames left over the frames replayed); the goal card
##     ("GOAL!  <scorer>", the score) stays over it; then the face-off as before. The replay only moves bodies the pause
##     already holds; the face-off places everybody, so the next live frame is as it was without it.
##   Match-end card: the result, the score, the best moment (the hardest check, else the longest goal), R and Esc.
## Toggles: tuning "fun" stop / shake / replay (true / false) for comparison; the README's "Fun" section.

var cfg: Dictionary = {}
var cam = null                         ## scripts/fun/cam.gd
var stop_left: int = 0                 ## frames of the hit-stop still to hold
var stops: int = 0                     ## hit-stops so far in this match
var _puck_vel: Vector3 = Vector3.ZERO
var _puck_frozen: bool = false
var rec: Array = []                    ## live snapshots every REC_STEP frames, newest last: [puck, positions, yaws, velocities]
var _rec_tick: int = 0
const REC_STEP: int = 3                ## a snapshot every third live frame (the replay interpolates; budget: frame p50)
var shot_age: int = 100000             ## live frames since the last shot
var shot_from: Vector3 = Vector3.ZERO
var replay: Array = []                 ## the snapshots being replayed
var replay_t: int = -1                 ## replay tick (-1 = none)
var replay_slow: float = 1.0
var hold_left: int = 0
var goal_text: String = ""
var best: Dictionary = {}              ## {kind: hit|goal, text, value}
var replays: int = 0
var save_text: String = ""             ## "SAVE!  VLAD" for save_frames after a goalie catches a shot
var save_left: int = 0
var _spots: Array = []                 ## [node, frame to free it] (burst)


func setup(g) -> void:
	cfg = g.tune["fun"]
	_thaw(g)
	rec = []
	shot_age = 100000
	replay = []
	replay_t = -1
	hold_left = 0
	goal_text = ""
	best = {}
	stops = 0
	replays = 0
	if cam == null:
		cam = g.ctx.load_script("scripts/fun/cam.gd").new()
	cam.setup(g)


func name_of(g, id: String) -> String:
	return str((g.tune["look"]["names"] as Dictionary).get(id, id.to_upper()))


## At the start of a live tick: true while a hit-stop holds the game (main then skips the tick).
func stop(g) -> bool:
	if stop_left <= 0:
		return false
	stop_left -= 1
	if stop_left > 0:
		return true
	_thaw(g)
	return false


func _freeze(g, frames: int) -> void:
	if stop_left > 0:
		stop_left = maxi(stop_left, frames)
		return
	stop_left = frames
	stops += 1
	for id: String in g.order:
		(g.skaters[id] as Node).set_physics_process(false)
	g.rules.set_physics_process(false)
	if g.puck.holder() == null:
		_puck_vel = g.puck.linear_velocity
		g.puck.freeze = true
		_puck_frozen = true


func _thaw(g) -> void:
	stop_left = 0
	for id: String in g.order:
		(g.skaters[id] as Node).set_physics_process(true)
	if g.rules != null:
		g.rules.set_physics_process(true)
	if _puck_frozen and g.puck != null:
		_puck_frozen = false
		if g.puck.holder() == null:
			g.puck.freeze = false
			g.puck.sleeping = false
			g.puck.linear_velocity = _puck_vel


## The tick's events (main's _flush_events, before fx): shots, hits, goals, face-offs.
func on_events(g, events: Array) -> void:
	for e: Array in events:
		var name: String = str(e[0])
		if name == "shot":
			shot_age = 0
			shot_from = e[1]
		elif name == "hit_stumble" or name == "hit_knockdown":
			_hit(g)
		elif name == "goal":
			_goal(g, str(e[2]))
			save_left = 0
		elif name == "one_timer":
			save_text = "ONE-TIMER!"            # L5b: a short card and a kick of the camera (drawing only)
			save_left = int(cfg["save_frames"])
			if bool(cfg["shake"]):
				g.ctx.cameras.shake(float(cfg["save_shake"]), 12)
		elif name == "big_save":
			_save(g, e[1], str(e[2]))
		elif name == "faceoff":
			if cam != null:
				cam.snap()                    # a cut to the face-off, never a long pan
			rec = []
			shot_age = 100000
			replay_t = -1
			hold_left = 0
			goal_text = ""


func _hit(g) -> void:
	var lh: Dictionary = g.hits.last_hit
	if lh.is_empty() or bool(lh.get("braced", false)):
		return
	var c: float = float(lh["closing"])
	if c > float(best.get("hit", 0.0)):
		best["hit"] = c
		best["hit_text"] = "%s %s %s at %.1f m/s" % [name_of(g, str(lh["by"])), "flattened" if str(lh["class"]) == "knockdown" else "rocked", name_of(g, str(lh["on"])), c]
	var lo: float = float(cfg["stop_closing"])
	if c < lo:
		return                                # a small bump stays quiet
	var k: float = clampf((c - lo) / maxf(float(cfg["hard_closing"]) - lo, 0.1), 0.0, 1.0)
	var victim: TLBiped = g.skaters[str(lh["on"])]
	if victim.global_position.distance_to((g.skaters["b0"] as Node3D).global_position) > float(cfg["stop_radius"]):
		return                                # far from him (off his picture): no stop, no shake
	if bool(cfg["shake"]):
		g.ctx.cameras.shake(lerpf(float(cfg["shake_min"]), float(cfg["shake_max"]), k), int(lerpf(12.0, 26.0, k)))
		var at: Vector3 = victim.global_position.lerp((g.skaters[str(lh["by"])] as Node3D).global_position, 0.4) + Vector3(0, 0.4, 0)
		burst(g, &"ice_spray", at, {"scale": lerpf(3.0, 4.5, k), "color": Color(0.45, 0.7, 1.0)})     # snow: blue on the cream ice
		burst(g, &"debris", at + Vector3(0, 0.6, 0), {"scale": lerpf(1.3, 2.2, k), "color": Color(0.62, 0.84, 1.0)})   # inked ice chips
		cam.punch(lerpf(0.12, 0.22, k), 40)
		if victim.rig != null:
			TLVfx.squash(victim.rig, lerpf(0.15, 0.3, k), 10)
	if bool(cfg["stop"]):
		_freeze(g, int(round(lerpf(float(cfg["stop_frames_min"]), float(cfg["stop_frames_max"]), k))))


## A burst drawn where it is asked for: TLVfx.burst places its node after adding it, and with physics interpolation a
## one-shot burst came out at the pack's origin, the centre spot (seen in a window, 21 Nov). So it goes under a spot
## node that is placed before it enters the tree, freed 200 frames later.
func burst(g, preset: StringName, at: Vector3, opts: Dictionary = {}) -> void:
	if g.ctx.headless:
		return                                # drawing only
	var spot: Node3D = Node3D.new()
	spot.name = "FxSpot"
	spot.position = g.ctx.root.global_transform.affine_inverse() * at
	g.ctx.root.add_child(spot)
	TLVfx.burst(preset, at, spot, opts)
	_spots.append([spot, g.ctx.frame + 200])


## A goalie caught a shot: a short card, a small shake, snow at his glove (visual only).
func _save(g, at: Vector3, team: String) -> void:
	save_text = "SAVE!  %s" % name_of(g, str(g.keeper.ids.get(team, "")))
	var gk: TLBiped = g.skaters.get(str(g.keeper.ids.get(team, "")))
	if gk != null and gk.rig != null and not g.ctx.headless:
		gk.rig.play(&"pass")                  # L5b: the glove stab (his rig is ticked by tick(), drawing only)
		TLVfx.squash(gk.rig, 0.22, 12)
	save_left = int(cfg["save_frames"])
	if bool(cfg["shake"]) and at.distance_to((g.skaters["b0"] as Node3D).global_position) <= float(cfg["stop_radius"]) * 1.5:
		g.ctx.cameras.shake(float(cfg["save_shake"]), 14)
		burst(g, &"ice_spray", at + Vector3(0, 0.5, 0), {"scale": 2.2, "color": Color(0.45, 0.7, 1.0)})


func _goal(g, side: String) -> void:
	var api = g.api
	var by: String = api.carrier if api.carrier != "" else str(api.last_release.get("by", ""))
	var who: String = name_of(g, by) if by != "" else side.to_upper()
	var own: bool = by != "" and str(g.teams[by]) != side
	goal_text = "%s  %s" % ["OWN GOAL" if own else "GOAL!", who]
	if not own and by != "" and shot_age < 240:
		var gl: Vector3 = Vector3(float(g.tune["goals"]["red" if side == "blue" else "blue"][0]), 0.0, 0.0) + g.ctx.root.global_position
		var d: float = Vector3(shot_from.x, 0.0, shot_from.z).distance_to(gl)
		if d > float(best.get("goal", 0.0)):
			best["goal"] = d
			best["goal_text"] = "%s scored from %d m" % [who, int(round(d))]
	if bool(cfg["shake"]):
		g.ctx.cameras.shake(float(cfg["goal_shake"]), 30)
	# the replay: from a little before the last shot (when it is in the record), else the last replay_frames
	hold_left = int(cfg["hold_frames"])
	replay_t = -1
	if not bool(cfg["replay"]) or rec.size() < 4:
		return
	var avail: int = (g.reset_in if g.reset_in > 0 else int(cfg["end_replay_frames"])) - hold_left - int(cfg["card_tail"])
	var n: int = mini(rec.size() * REC_STEP, clampi(shot_age + int(cfg["before_shot"]), int(cfg["replay_min"]), int(cfg["replay_max"])))
	n = mini(n, int(float(avail) / float(cfg["slow_min"])))      # slow enough to read: at least slow_min (n in frames)
	replay = rec.slice(rec.size() - maxi(2, n / REC_STEP))
	n = (replay.size() - 1) * REC_STEP
	replay_slow = clampf(float(avail) / float(n), 1.0, float(cfg["slow_max"]))
	if avail > n:
		replay_t = 0
		replays += 1


## Every tick, last (main's _flush_events): the record, the replay, the camera.
func tick(g) -> void:
	while not _spots.is_empty() and int(_spots[0][1]) <= g.ctx.frame:
		var sp: Node = _spots.pop_front()[0]
		if is_instance_valid(sp):
			sp.queue_free()
	var live: bool = not g.frozen and g.rules.is_running() and stop_left <= 0 and g.drill_id != "intro"
	if live:
		_rec_tick += 1
	if live and _rec_tick % REC_STEP == 0:
		var ps: PackedVector3Array = PackedVector3Array()
		var ys: PackedFloat32Array = PackedFloat32Array()
		var vs: PackedVector3Array = PackedVector3Array()
		for id: String in g.order:
			var sk: TLBiped = g.skaters[id]
			ps.append(sk.position)
			ys.append(sk.rotation.y)
			vs.append(sk.velocity)
		rec.append([g.puck.position, ps, ys, vs])
		if rec.size() > int(cfg["replay_max"]) / REC_STEP:
			rec.pop_front()
	if live:
		shot_age += 1
	_tick_goalie_rigs(g)
	var playing: bool = false
	if save_left > 0:
		save_left -= 1
	if hold_left > 0:
		hold_left -= 1
	elif replay_t >= 0:
		playing = _replay_step(g)
	if cam != null:
		cam.tick(g, playing, stop_left > 0)


## L5b: the goalies' own biped step is off (the pack places them), so their figures are ticked here: a stance that
## breathes and the stab of a save. Drawing only: nothing here is a body or in the state.
func _tick_goalie_rigs(g) -> void:
	if g.ctx.headless:
		return
	for t: String in g.keeper.ids:
		var gk: TLBiped = g.skaters.get(str(g.keeper.ids[t]))
		if gk != null and gk.rig != null and gk.is_inside_tree() and not gk.is_physics_processing():
			gk.rig.set_locomotion(Vector3.ZERO, true)
			gk.rig.tick(g.ctx.frame)


func _replay_step(g) -> bool:
	var at: float = float(replay_t) / replay_slow / float(REC_STEP)     # in snapshots
	var i: int = int(at)
	if i >= replay.size() - 1:
		replay_t = -1
		return false
	replay_t += 1
	var f: float = at - float(i)
	var a: Array = replay[i]
	var b: Array = replay[i + 1]
	for j: int in g.order.size():
		if j >= (a[1] as PackedVector3Array).size():
			break
		var sk: TLBiped = g.skaters[g.order[j]]
		var p: Vector3 = (a[1] as PackedVector3Array)[j].lerp((b[1] as PackedVector3Array)[j], f)
		sk.place(g.ctx.root.global_transform * p, lerp_angle((a[2] as PackedFloat32Array)[j], (b[2] as PackedFloat32Array)[j], f))
		sk.velocity = (a[3] as PackedVector3Array)[j] / replay_slow
	if g.puck.holder() == null:
		g.puck.place(g.ctx.root.global_transform * (a[0] as Vector3).lerp(b[0] as Vector3, f))
	return true


## The text in the centre of the screen: the match-end card, else the goal card (with the replay mark).
func card(g) -> String:
	if g.result != "":
		var sc: String = "%d : %d" % [g.rules.score("blue"), g.rules.score("red")]
		var head: String = {"WIN": "YOU WIN", "LOSE": "YOU LOSE"}.get(g.result, "DRAW")
		var line: String = str(best.get("hit_text", best.get("goal_text", "")))
		var lines: Array = ["%s   %s" % [head, sc]]
		if line != "":
			lines.append("Best moment: " + line)
		lines.append(str(g.tune["look"]["again"]))
		return "\n".join(lines)
	if save_left > 0:
		return save_text
	if goal_text != "" and g.drill_id == "intro" and hold_left > 0:
		return goal_text                      # the first-minute drill's goal counts for nothing: no score line
	if goal_text != "" and (g.reset_in > 0 or hold_left > 0 or replay_t >= 0):
		var t: String = "%s\nBLUE %d : %d RED" % [goal_text, g.rules.score("blue"), g.rules.score("red")]
		return t + ("\nREPLAY" if replay_t >= 0 and hold_left <= 0 else "")
	return ""


func state() -> Dictionary:
	var s: Dictionary = {}
	if stops > 0:
		s["stops"] = stops
	if stop_left > 0:
		s["stop_left"] = stop_left
	if replays > 0:
		s["replays"] = replays
	if replay_t >= 0:
		s["replay_t"] = replay_t
	return s
