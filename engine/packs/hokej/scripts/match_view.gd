extends RefCounted
## The match drawn from the core's snapshot (K3 round 6): every skater is thirdjam's own figure (engine/rigs/skater,
## TLRigSkater, lane K2) driven by thirdjam's pawn (ctx.cores.view_script("rink", "skater_pawn"): AJamSkater::ApplySimFrame
## and ApplyRender, JamPawns.cpp:464-746 and :824-843), one pawn a skater fed its snapshot dictionary each frame, as
## AHokejGameMode::StepOnce does (HokejGameMode.cpp:1680-1694). The puck is drawn where the sim has it until K2's shown
## carrier (FJamPuckShow, GAMEMODE.md row 23).
## data/view.json `figures: false` draws the round-3 STAND-INS instead (debugging): a 1.64 m capsule a skater with a facing
## mark and a stick bar to the sim's blade.
## Interpolation between the 60 Hz frames: the pawn is placed once a sim frame (ApplyRender at alpha 1) and the engine's
## physics interpolation draws it between frames, as ApplyRender lerps PrevPos -> Pos (JamPawns.cpp:824-846). A jump the sim
## does not move through (a faceoff's reset: PrevPos = Pos there) is not drawn as a slide: the node's interpolation is reset.

const DT: float = 1.0 / 60.0

var figures: bool = true
var bodies: Array = []      # the node a skater stands at (the pawn, or the stand-in's body): the camera's subject
var sticks: Array = []      # stand-ins only
var pawns: Array = []       # figures only: thirdjam's pawn a skater (Node3D)
var figs: Array = []        # figures only: TLRigSkater a skater
var shown: Array = []       # whether a skater is drawn (the proof modes show one)
var puck: Node3D
# AJamPuck's hit-stop (JamPawns.cpp:984-1017): HoldLeft, CatchUpLeft, HoldTotal, HeldLoc, LastPlaced
var _puck_hold_left: int = 0
var _puck_catch_left: int = 0
var _puck_total: int = 0
var _puck_held_at: Vector3 = Vector3.ZERO
var _puck_last: Vector3 = Vector3.ZERO


## `cart_game`: the cartridge's "game" (teams and their colours). `pawn_script`: ctx.cores.view_script("rink", "skater_pawn").
func _init(root: Node3D, rink_gen, snap: Dictionary, puck_radius: float, cart_game: Dictionary, pawn_script: GDScript, use_figures: bool) -> void:
	figures = use_figures and pawn_script != null
	var sk: Array = snap["Skaters"]
	var human: int = int(snap["HumanIndex"])
	var teams: Array = cart_game["teams"]
	var slot_in_team: Dictionary = {}
	for i: int in sk.size():
		var team: int = int(sk[i]["Team"])
		shown.append(true)
		if not figures:
			var parts: Array = rink_gen.standin_figure(root, "car_blue" if team == 0 else "orange", "Skater%d" % i)   # cartridge colours #1D4ED8, #E8651A
			bodies.append(parts[0])
			sticks.append(parts[1])
			continue
		# AHokejGameMode's spawn (one AJamSkater a sim skater, its visual a child) and AJamSkater::InitSkater (JamPawns.cpp:395-400):
		# the team's colour (game.teams[].colour_hex, linear as FLinearColor) and the jersey's number (JerseyNumberFor,
		# HokejGameMode.cpp:439-444, by the skater's slot in its team in sim order)
		var slot: int = int(slot_in_team.get(team, 0))
		slot_in_team[team] = slot + 1
		var pawn = pawn_script.new()
		pawn.name = "Skater%d" % i
		root.add_child(pawn)
		var fig: TLRigSkater = TLRigSkater.new()
		fig.setup({"team": team})
		pawn.add_child(fig)
		fig.set_human(i == human)
		var colour: Color = Color(String(teams[team]["colour_hex"])) if team < teams.size() else Color.WHITE
		pawn.init_skater(i, team, colour.srgb_to_linear(), jersey_number(team, slot), fig)
		pawns.append(pawn)
		figs.append(fig)
		bodies.append(pawn)
	puck = rink_gen.standin_puck(root, puck_radius)


## AHokejGameMode::JerseyNumberFor (HokejGameMode.cpp:439-444).
static func jersey_number(team: int, slot: int) -> int:
	const NUMBERS: Array = [[7, 13, 42], [9, 21, 88]]
	if slot >= 0 and slot < 3 and (team == 0 or team == 1):
		return int(NUMBERS[team][slot])
	return clampi(team * 10 + slot + 1, 0, 99)


## The proof modes draw one skater: the others and the puck are put away (and their figures not ticked).
func show_only(i: int) -> void:
	for k: int in bodies.size():
		shown[k] = k == i
		(bodies[k] as Node3D).visible = k == i
		if not figures:
			(sticks[k] as Node3D).visible = k == i
	puck.visible = false


## AHokejGameMode::HitStopRoute's calls (HokejGameMode.cpp:1767-1768): the victim's and the checker's pawns hold the hit
## frame (AJamSkater::BeginHitStop), and the puck (AJamPuck::BeginHitStop). Before the pawns apply the frame.
func begin_hit_stop(who: Array, frames: int) -> void:
	if figures:
		for i: int in who:
			if i >= 0 and i < pawns.size():
				pawns[i].begin_hit_stop(frames)
	if frames > 0:                                # AJamPuck::BeginHitStop (JamPawns.cpp:984-993): held where it was last drawn
		_puck_total = clampi(frames, 1, 6)
		_puck_hold_left = _puck_total + 1
		_puck_catch_left = 0
		_puck_held_at = _puck_last


## One frame. `hold` (stand-ins only): indices whose stand-ins hold their last pose (a hit-stop's victim and checker; -1 the
## puck). With figures the pawns hold themselves (begin_hit_stop) and the puck holds by its own count.
func draw(snap: Dictionary, hold: Dictionary = {}) -> void:
	var sk: Array = snap["Skaters"]
	var frame: int = int(snap["Frame"])
	for i: int in sk.size():
		if not shown[i]:
			continue
		if figures:
			_draw_figure(i, sk[i], frame, snap["Puck"]["Pos"])
		elif not hold.has(i):
			_draw_standin(i, sk[i])
	var p: Dictionary = snap["Puck"]
	var pp: Vector2 = p["Pos"]
	var live := Vector3(pp.x, float(p["Z"]), pp.y)
	var teleport: bool = (p["PrevPos"] as Vector2) == pp if p.has("PrevPos") else false
	if not figures:
		if not hold.has(-1):
			_place(puck, live, teleport)
		return
	# AJamPuck::StepSimFrame after the pawns (HokejGameMode.cpp:1697; JamPawns.cpp:995-1002), then Place at alpha 1 (:1004-1017)
	if _puck_hold_left > 0:
		_puck_hold_left -= 1
		if _puck_hold_left == 0:
			_puck_catch_left = _puck_total
	elif _puck_catch_left > 0:
		_puck_catch_left -= 1
	var at: Vector3 = live
	if _puck_hold_left > 0:
		at = _puck_held_at
	elif _puck_catch_left > 0 and _puck_total > 0:
		at = _puck_held_at.lerp(live, clampf((float(_puck_total - _puck_catch_left) + 1.0) / float(_puck_total), 0.0, 1.0))
	_puck_last = at
	_place(puck, at, teleport)


## One skater alone (the proof modes: the gym's skater on empty ice, the replay's logged skater): no puck to look at.
func draw_skater(i: int, s: Dictionary, frame: int = 0) -> void:
	if figures:
		_draw_figure(i, s, frame, null)
	else:
		_draw_standin(i, s)


## AJamSkater::ApplySimFrame then ApplyRender at alpha 1 (the engine interpolates), the look's puck in the figure's frame
## ([LookTick]'s PuckRef: thirdjam's figure reads the puck actor), then the figure's tick (its animation's one update a
## frame; thirdjam ticks it a rendered frame, ours a sim frame: DT 1/60, the law of physics frames).
func _draw_figure(i: int, s: Dictionary, frame: int, puck_pos: Variant) -> void:
	var pawn = pawns[i]
	var fig: TLRigSkater = figs[i]
	var was: Vector3 = pawn.position
	pawn.apply_sim_frame(s, frame)
	pawn.apply_render(s, 1.0)
	if (s["PrevPos"] as Vector2) == (s["Pos"] as Vector2) and Vector2(was.x, was.z).distance_to(s["Pos"]) > 0.5:
		pawn.reset_physics_interpolation()
	if puck_pos == null:
		fig.set_puck(null)
	else:
		var rel: Vector2 = (puck_pos as Vector2) - (s["Pos"] as Vector2)
		var yaw: float = float(s["Yaw"])
		fig.set_puck(Vector2(rel.dot(Vector2(cos(yaw), sin(yaw))), rel.dot(Vector2(-sin(yaw), cos(yaw)))))
	fig.tick()


func _draw_standin(i: int, s: Dictionary) -> void:
	var pos: Vector2 = s["Pos"]
	var body: Node3D = bodies[i]
	var teleport: bool = (s["PrevPos"] as Vector2) == pos and Vector2(body.position.x, body.position.z).distance_to(pos) > 0.5
	body.rotation = Vector3(0.0, -float(s["Yaw"]), 0.0)       # rink yaw (towards +y) -> Godot: about -Y
	_place(body, Vector3(pos.x, 0.0, pos.y), teleport)
	# the stick: from the body's edge (0.25 m) to the blade on the ice (FJamSkaterState::BladePos)
	var blade: Vector2 = s["BladePos"]
	if blade.distance_to(pos) > 3.0:              # a blade the sim has not placed yet (BladePos (0, 0) before the first step):
		blade = pos + Vector2(cos(float(s["Yaw"])), sin(float(s["Yaw"]))) * 1.0   # held ahead (stand-in rule; no reach is 3 m)
	var d: Vector2 = blade - pos
	var st: Node3D = sticks[i]
	var yaw: float = atan2(d.y, d.x) if d.length() > 0.01 else float(s["Yaw"])
	var from: Vector2 = pos + Vector2(cos(yaw), sin(yaw)) * 0.25
	st.rotation = Vector3(0.0, -yaw, 0.0)
	st.scale = Vector3(maxf(0.05, blade.distance_to(from)), 1.0, 1.0)
	_place(st, Vector3(from.x, 0.0, from.y), teleport)


static func _place(n: Node3D, at: Vector3, teleport: bool) -> void:
	n.position = at
	if teleport:
		n.reset_physics_interpolation()


## After the first placement: nothing slides in from where the nodes were made.
func reset_interpolation() -> void:
	for n: Node3D in bodies + sticks + [puck]:
		n.reset_physics_interpolation()
