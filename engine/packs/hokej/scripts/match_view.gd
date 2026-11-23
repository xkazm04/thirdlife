extends RefCounted
## The match drawn from the core's snapshot (K3 rounds 6 and 8): every skater is thirdjam's own figure (engine/rigs/skater,
## TLRigSkater, lane K2) driven by thirdjam's pawn (ctx.cores.view_script("rink", "skater_pawn"): AJamSkater::ApplySimFrame
## and ApplyRender, JamPawns.cpp:464-746 and :824-843), one pawn a skater fed its snapshot dictionary each frame, as
## AHokejGameMode::StepOnce does (HokejGameMode.cpp:1680-1694). What the game mode does around the pawns for the eye is lane
## K2's show object (ctx.cores.view_script("rink", "skater_show"), K3 round 8; GAMEMODE.md rows 20 and 23), the one owner of
## that logic: thirdjam's hit-stop picks and routing (HitStopRoute, HitStopPick, HitStopFramesFor, AJamPuck's hold) and the
## carrier the screen shows (FJamPuckShow: the carried puck on the blade's socket, the play calls by name).
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
var show                    # K2's skater_show.gd: the hit-stop and the shown carrier (both modes; the stand-ins hold by its pick)
var _puck_drawn: Variant = null   # where the show drew the puck last frame (Godot space, the puck's centre): what the figures look at


## `cart`: the cartridge (teams and their colours; the numbers the show reads). `pawn_script`, `show_script`:
## ctx.cores.view_script("rink", "skater_pawn") and ("rink", "skater_show").
func _init(root: Node3D, rink_gen, snap: Dictionary, puck_radius: float, cart: Dictionary, pawn_script: GDScript, show_script: GDScript, use_figures: bool) -> void:
	figures = use_figures and pawn_script != null
	show = show_script.new()
	show.cfg = show_script.config_of(cart)
	var sk: Array = snap["Skaters"]
	var human: int = int(snap["HumanIndex"])
	var teams: Array = cart["game"]["teams"]
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
	for fig: TLRigSkater in figs:
		fig.set_rivals(figs)                      # [ChkScan] reads the nearest opposing figure (K2's driver)
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


## The bus events a figure hears (AHokejGameMode::DeliverEvents, HokejGameMode.cpp:1664, before the hit-stop and the pawns),
## as K2's verb gym delivers them: OnBusEvent(name, its Who is this figure's skater, where in world centimetres, ...).
const BUS_EVENTS: Array = ["knockdown", "check", "lift", "deke"]


## One sim frame of the match, in thirdjam's order (HokejGameMode.cpp:1664-1707; skater_show.gd's header): the bus, the
## show's step (HitStopRoute, then FJamPuckShow::StepSim), every pawn's ApplySimFrame, the show's after_pawns (the wind-up
## takes, the puck's hold count), every pawn's ApplyRender and figure tick, then the show's Render: the puck where it is
## drawn (on the shown carrier's blade socket, or the sim's place, held through a hit-stop). Returns whether the
## presentation frame is held (the camera and HUD do not step: HokejGameMode.cpp:1710).
func draw(snap: Dictionary) -> bool:
	var sk: Array = snap["Skaters"]
	var frame: int = int(snap["Frame"])
	var live: Array = pawns.filter(func(a): return shown[int(a.sim_index)])
	if figures:
		for ev: Dictionary in snap.get("Events", []):
			var en: String = String(ev["Name"])
			if BUS_EVENTS.has(en):
				for i: int in sk.size():
					if shown[i]:
						figs[i].OnBusEvent(StringName(en), int(ev["Who"]) == i, (ev["Where"] as Vector2) * 100.0, float(ev["Strength"]), StringName(String(ev["Kind"])))
	show.step_sim(snap, live)
	var held: bool = show.presentation_held(frame)
	for i: int in sk.size():
		if not shown[i]:
			continue
		if figures:
			pawns[i].apply_sim_frame(sk[i], frame)
		elif not (held and [int(show.last_pick.get("Victim", -1)), int(show.last_pick.get("Checker", -1))].has(i)):
			_draw_standin(i, sk[i])                # the stand-ins hold by the show's pick (debugging only)
	show.after_pawns(snap, live)
	if figures:
		for i: int in sk.size():
			if shown[i]:
				_render_figure(i, sk[i], _puck_drawn)
	var d: Dictionary = show.render(snap, live, 1.0)
	var at: Vector3 = d["puck"]
	_puck_drawn = at
	# the stand-in puck's origin is its base (TLMesh.cyl from y = 0); the show gives the centre (AJamPuck HalfHeightM 0.04)
	_place(puck, Vector3(at.x, at.y - show_script_half_height(), at.z), Vector2(puck.position.x, puck.position.z).distance_to(Vector2(at.x, at.z)) > 3.0)
	return held


func show_script_half_height() -> float:
	return float(show.PUCK_HALF_HEIGHT_M)


## Where skater i's figure has its head for the HUD's marker (UJamHudWidget::HumanHeadWorld, HUDWidget.cpp:1089-1121): the
## figure's head_socket, come back along the head's own axis (head bone -> socket) by jam.hud.MarkerLiftCm -18 (HUDWidget.h:322;
## the world's up without a head bone). World space (Godot), as drawn this sim frame. Null with the stand-ins (the HUD keeps
## its own rule).
const MARKER_LIFT_M: float = -0.18
func head_world(i: int) -> Variant:
	if not figures or i < 0 or i >= figs.size():
		return null
	var fig: TLRigSkater = figs[i]
	var sock: Vector3 = fig.socket_transform(&"head_socket").origin
	var axis: Vector3 = sock - fig.bone_transform(&"head").origin
	axis = axis.normalized() if axis.length() > 1e-4 else Vector3.UP
	return fig.global_transform * (sock + axis * MARKER_LIFT_M)


## One skater alone (the proof modes: the gym's skater on empty ice, the replay's logged skater): no puck to look at, no
## show (no hits, no puck drawn).
func draw_skater(i: int, s: Dictionary, frame: int = 0) -> void:
	if figures:
		pawns[i].apply_sim_frame(s, frame)
		_render_figure(i, s, null)
	else:
		_draw_standin(i, s)


## AJamSkater::ApplyRender at alpha 1 (the engine interpolates), the look's puck in the figure's frame ([LookTick]'s PuckRef:
## thirdjam's figure reads the puck actor, i.e. where the puck was last drawn), then the figure's tick (its animation's one
## update a frame; thirdjam ticks it a rendered frame, ours a sim frame: DT 1/60, the law of physics frames).
func _render_figure(i: int, s: Dictionary, puck_at: Variant) -> void:
	var pawn = pawns[i]
	var fig: TLRigSkater = figs[i]
	var was: Vector3 = pawn.position
	pawn.apply_render(s, 1.0)
	if (s["PrevPos"] as Vector2) == (s["Pos"] as Vector2) and Vector2(was.x, was.z).distance_to(s["Pos"]) > 0.5:
		pawn.reset_physics_interpolation()
	if puck_at == null:
		fig.set_puck(null)
	else:
		var rel: Vector2 = Vector2((puck_at as Vector3).x, (puck_at as Vector3).z) - (s["Pos"] as Vector2)
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
