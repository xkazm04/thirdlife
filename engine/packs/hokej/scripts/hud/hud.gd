extends RefCounted
## thirdjam's match HUD on our screen (lane K5, round 1: the in-play set). UJamHudWidget::RefreshFromFrame (HUDWidget.cpp:895-1084)
## as HEAD 8dc713c6 ships it, every console variable at its default, in the one look (jam.hud.OneLook 1, HUDOneLook.cpp):
## the score plates, the rings on the ice (yours, the carrier's, yours doubled while you carry, the loose puck's), the YOU
## chevron and tag, the far-net and own-net badges with their distances, the off-screen puck arrow, the edge-slot rule,
## the controls panel, the radar, the faceoff dial and its hint. Positions in layout units (1920 x 1080 at 16:9, as
## Slate's DPI curve). Presentation only: it reads the snapshot and the buttons and writes nothing back.
## One call a frame: `frame(snap, ui)` after the camera has stepped (main.gd). The rules are rules.gd's.

const R := preload("rules.gd")
const PanelView := preload("panel.gd")
const Markers := preload("markers.gd")
const Cards := preload("cards.gd")
const Flow := preload("flow.gd")
const Captions := preload("captions.gd")
const Barks := preload("barks.gd")
const Charge := preload("charge.gd")

var lay                       # TLHudLayer
var length_m: float = 90.0
var width_m: float = 45.0
var team_col: Array = [R.BLUE, R.ORANGE]
var take_grace_total: int = 30          # FJamStickConfig::TakeGraceFrames (JamCartridge.h:202); the cartridge has no game.stick
var head_override: Vector3 = Vector3.INF   # this frame's head anchor from the figure (screen.gd head_world)
var head_m: float = 1.64                # the head anchor: the stand-in's top of bounds (HumanHeadWorld source 1, cpp:1089-1131)
var figure_box_m: Vector3 = Vector3(0.42, 1.64, 0.25)   # the STAND-IN's bounds (FigureBoxOnScreen source 1); a figure with a skeleton is boxed by its bones (source 2, screen.gd bone_points)
var panel                               # panel.gd
var markers                             # markers.gd
var art_ring: Texture2D                 # assets/hud/: thirdjam's own UI textures, exported once from its project (K5 round 2)
var art_dial: Texture2D
var cards                               # cards.gd: the take and the MATCH card
var flow                                # flow.gd: the GOAL banner, the end card, IN THE BOX
var captions                            # captions.gd: the commentator's lines
var barks                               # barks.gd: the skaters' barks and their lane
var charge = Charge.new()               # charge.gd: the pass's target ring and the teaching pulse
var pass_ring_at: int = -1
var booth_frame: int = -1
var booth_end_said: bool = false
var last_take: int = 0

# memories (HUDWidget.h private state)
var last_sim_frame: int = -1
var faceoffs_this_session: int = 0      # static in thirdjam: a session (process)
var last_faceoff_frames: int = 0
var drop_until: int = -1
var last_drop_frame: int = -1
var draw_result_until: int = -1
var last_draw_won: bool = false
var countdown_seen: bool = false
var marker_yield: float = 1.0
var human_down: bool = false
var human_up_since: int = -1
var possess_carrier: int = -2
var possess_since: int = -1
var rel_carrier: int = -2
var rel_passes: int = -1
var rel_shots: int = -1
var released: bool = false
var cue_grace_carrier: int = -1
var grace_from_hit: bool = false
# what the last frame showed (tests read it)
var shown: Dictionary = {}


func _init(layer, game: Dictionary, level_id: String = "pro", match_seed: int = 0, bark_rows: Array = []) -> void:
	lay = layer
	var rk: Dictionary = game["rink"]
	length_m = float(rk["length_m"])
	width_m = float(rk["width_m"])
	var teams: Array = game.get("teams", [])
	for t: int in mini(2, teams.size()):
		if (teams[t] as Dictionary).has("colour_hex"):
			team_col[t] = Color(String(teams[t]["colour_hex"]))      # FJamPresentationFrame::TeamColour0/1 (HokejGameMode.cpp:1632)
	take_grace_total = int((game.get("stick", {}) as Dictionary).get("take_grace_frames", 30))
	panel = PanelView.new()
	markers = Markers.new(self)
	cards = Cards.new(game, level_id)
	flow = Flow.new(self, game)
	captions = Captions.new(game, match_seed)
	barks = Barks.new(game, bark_rows, match_seed)
	if lay.has_method("image_of"):
		art_ring = lay.image_of("assets/hud/T_UI_RingPlain.png")
		art_dial = lay.image_of("assets/hud/T_UI_Ring.png")


func col(team: int) -> Color:
	return team_col[0] if team == 0 else team_col[1]


## One frame. ui: {"with_puck": bool (JamControls::HasPuckForButtons), "held": {verb: true}, "saucer": bool, "braced": bool,
## "press": bool (a two-role button down), "paused": bool}.
func frame(snap: Dictionary, ui: Dictionary) -> void:
	lay.clear()
	shown = {}
	var ext: Vector2 = lay.extent()
	var vw: float = ext.x
	var vh: float = ext.y
	var f: int = int(snap["Frame"])
	var phase: String = R.phase_of(snap)
	var sk: Array = snap["Skaters"]
	var me: int = int(snap["HumanIndex"])
	var hu: Dictionary = sk[me]
	var my_team: int = int(hu["Team"])
	var attack: float = 1.0 if my_team == 0 else -1.0
	var hpos: Vector2 = hu["Pos"]
	var carrier: int = int(snap["Carrier"])
	var puck: Dictionary = snap["Puck"]
	var puck_pos: Vector2 = puck["Pos"]
	var paused: bool = bool(ui.get("paused", false))
	head_override = ui.get("head", Vector3.INF)

	# ---- the frame's memories (cpp:903, 1012-1027)
	if f < last_sim_frame:
		human_up_since = -1
		human_down = false
		last_drop_frame = -1
		draw_result_until = -1
	var advanced: bool = f != last_sim_frame
	last_sim_frame = f
	var down_now: bool = bool(hu.get("IsDown", false))
	if human_down and not down_now:
		human_up_since = f
	human_down = down_now
	var frames: int = int(snap["FaceoffCountdown"]) if int(snap["Phase"]) == 3 else 0     # FaceoffCountdownFrames (HokejGameMode.cpp:1625)
	for e: Dictionary in snap["Events"]:
		if String(e["Name"]) == "faceoff":                                                  # HandleJamEvent (cpp:1545-1564)
			if String(e["Kind"]) == "drop":
				last_drop_frame = f
			elif String(e["Kind"]) == "won" and int(e["Who"]) >= 0 and int(e["Who"]) < sk.size():
				last_draw_won = int((sk[int(e["Who"])] as Dictionary)["Team"]) == my_team
				draw_result_until = f + R.DRAW_RESULT_FRAMES
	if frames <= 0 and last_faceoff_frames > 0:
		drop_until = f + R.DROP_FRAMES
		if last_drop_frame < 0 or last_drop_frame > f:
			last_drop_frame = f
	if f < last_faceoff_frames - 1 and frames <= 0:
		drop_until = -1
	if frames > 0 and not countdown_seen:
		faceoffs_this_session += 1
		countdown_seen = true
	if frames <= 0:
		countdown_seen = false
	last_faceoff_frames = frames
	var b_result: bool = draw_result_until >= 0 and f < draw_result_until and phase == "play"
	var b_drop: bool = not b_result and frames <= 0 and drop_until >= 0 and f < drop_until and phase == "play"
	var b_count: bool = frames > 0 and phase == "play"
	var end: bool = phase == "win" or phase == "lose"
	var match_card: bool = cards.step(snap, phase)
	var fl: Dictionary = flow.frame(snap, phase, vw, vh, paused)
	# the booth: once a sim frame (the end phase holds its frame: its events are not heard twice); the game mode's events
	# `period` (UpdateTake's broadcast, HokejGameMode.cpp:385-397: at the build, a restart and every take change) and `win` / `lose`
	if f != booth_frame:
		var extra: Array = []
		if f < booth_frame or booth_frame < 0 or cards.take != last_take:
			extra.append(["period", "take_%d" % cards.take])
			booth_end_said = false
		if end and not booth_end_said:
			extra.append(["win" if phase == "win" else "lose", ""])
			booth_end_said = true
		last_take = cards.take
		booth_frame = f
		barks.step(snap, extra)                                    # the barks first: the booth hears them on the same frame
		for bk: Array in barks.said:
			var sit: String = bk[1]
			var at_human: bool = not (sit == "goal_against" or sit == "faceoff") and (sit != "goal_for" or Barks._team(snap, int(bk[0])) == my_team)
			captions.bark(at_human)
			shown["bark_said"] = sit
		var said: Dictionary = captions.step(snap, extra)
		if not said.is_empty():
			captions.show(said, flow.tick)
			shown["line_started"] = said["id"]          # UpdateGoalBanner runs early in RefreshFromFrame (cpp:950): its state rules the rest
	var banner: bool = bool(fl["banner"])

	# ---- the human's figure box on the screen (UpdateKeepClear's HumanBoxNow: the bounds plus FigurePadCm 14, HUDClearDown.cpp)
	var hbox: Rect2 = _bones_box(ui.get("bones", PackedVector3Array())) if not (ui.get("bones", PackedVector3Array()) as PackedVector3Array).is_empty() else _figure_box(hpos, float(hu["Yaw"]), down_now)

	# ---- the panel's state first: its top is what the markers keep clear of (ControlsPanelTopNow)
	var panel_on: bool = R.show_controls_panel(phase, paused, banner)
	var panel_top: float = (R.EDGE_PX + R.PANEL_RESERVE_H) if panel_on else 0.0

	# ================================================================ z -1: rings made on first use, under every element
	var rings: Dictionary = _rings(snap, phase, me, hu, carrier, b_count, hbox, f, advanced)
	if rings.has("you_have"):
		_ring(rings["you_have"][0], rings["you_have"][1])
		shown["you_have_ring"] = true
	if rings.has("loose"):
		_ring(rings["loose"][0], rings["loose"][1])
		shown["loose_ring"] = true
	if advanced:                                       # UpdateChargeLook and UpdateTeach read the sim frame (cpp:183, 185)
		pass_ring_at = charge.pass_ring(snap, phase, me, f)
		charge.teach(snap, phase, me, f, b_count, down_now, last_drop_frame, bool(ui.get("hit_pressed", false)))
	var pr: Rect2 = lay.ground_ring(Vector3((sk[pass_ring_at] as Dictionary)["Pos"].x, 0.03, (sk[pass_ring_at] as Dictionary)["Pos"].y), R.CARRIER_RING_M * R.PASS_RING_SCALE) if pass_ring_at >= 0 else Rect2()
	if pr.size != Vector2.ZERO:                        # HUDChargeLook.cpp:87-111: z -1, the team's colour at full alpha
		_ring(pr, Color(col(my_team), 1.0))
		shown["pass_ring"] = pass_ring_at

	# ================================================================ the scoreboard (cpp:522-569, one look HUDOneLook.cpp:59-78)
	_scoreboard(snap, vw, my_team)

	# ================================================================ the rings (cpp:591-595)
	if rings.has("you"):
		_ring(rings["you"][0], rings["you"][1])
		shown["you_ring"] = true
	if rings.has("carrier"):
		_ring(rings["carrier"][0], rings["carrier"][1])
		shown["carrier_ring"] = true

	# ================================================================ the markers (UpdateMarker, UpdateOwnMarker, UpdatePuckMarker, ResolveEdgeSlots)
	var covered: bool = b_count or frames > 0 or f < R.PUCK_MARKER_CARD_FRAMES
	var marks: Array = markers.build(snap, phase, hpos, attack, carrier, puck_pos, vw, vh, panel_top, covered, paused, advanced, f)
	markers.label_boxes = []
	if not R.labels_stand_down(match_card, banner, paused, end):     # HideLabelsUnderCards (HUDOneLook.cpp:277-295)
		markers.paint(marks)

	# ================================================================ the YOU chevron and tag (UpdateYours cpp:1629-1687)
	if phase == "play" or phase == "goal_pause":
		_you_marker(hu, puck_pos, rings.get("ring_ok", false), b_count, advanced)

	# ================================================================ the controls panel (HUDControlsPanel.cpp)
	if panel_on:
		var team_c: Color = col(my_team)
		var dim: bool = down_now or int(hu.get("PenaltyFrames", 0)) > 0          # jam.hud.Words 1: dims while down; boxed dims (A227)
		var held: Dictionary = (ui.get("held", {}) as Dictionary).duplicate()
		var stamina01: float = float(ui.get("stamina01", 1.0))
		held.erase("Sprint")                                                     # jam.hud.SprintOnIce 0: the row is the sprint (cpp:401-406)
		if bool(hu.get("bSprinting", false)):
			held["Sprint"] = true
		if int(hu.get("PenaltyFrames", 0)) > 0:
			held = {}
		shown["panel"] = panel.paint(lay, vh, f, bool(ui.get("with_puck", false)), bool(ui.get("press", false)), held,
			bool(ui.get("saucer", false)), bool(ui.get("braced", false)), false, team_c, dim, R.legs_spent(stamina01, bool(hu.get("bSprinting", false))), charge.teach_shown)
	else:
		panel.hide()

	# ================================================================ the commentator's caption (cpp:713-722, 1467-1525); the one-line rule:
	# the faceoff hint wins over it (HUDOneLine.cpp)
	var hint_up: bool = b_count and faceoffs_this_session <= R.FACEOFF_HINT_COUNT and not R.faceoff_cue_hidden_in_box(int(hu.get("PenaltyFrames", 0)))
	var cap: String = captions.paint(lay, vw, vh, flow.tick, paused, hint_up, hbox, markers.label_boxes)
	if cap != "":
		shown["caption"] = cap

	# ================================================================ the radar (cpp:724-733, RadarWidget.cpp; one look frame HUDOneLook.cpp:110-112)
	_radar(snap, vw, vh, me)

	# ================================================================ the faceoff dial and its hint (cpp:1017-1062)
	var cue_hidden: bool = R.faceoff_cue_hidden_in_box(int(hu.get("PenaltyFrames", 0)))
	if (b_count or b_drop or b_result) and not cue_hidden:
		_dial(vw, vh, frames, b_count, b_drop, b_result, col(my_team))
	if b_count and faceoffs_this_session <= R.FACEOFF_HINT_COUNT and not cue_hidden:
		_faceoff_hint(vw, vh)

	# ================================================================ the GOAL banner (z 40), IN THE BOX, the end card (flow.gd)
	flow.paint()
	shown.merge(flow.shown)

	# ================================================================ the MATCH card (UJamDirectorsCallHudWidget, viewport z 5: over the HUD)
	if match_card:
		cards.paint(lay, vw)
		shown["match_card"] = cards.sub_line()

	# ================================================================ the barks' lane (UJamBarkWidget, viewport z 50)
	var drawn: Array = barks.paint(lay, snap, vw, vh, f, paused, cap != "" or hint_up, hbox, team_col)
	if not drawn.is_empty():
		shown["bark"] = drawn


# ---------------------------------------------------------------- the scoreboard
func _scoreboard(snap: Dictionary, vw: float, my_team: int) -> void:
	var score: Array = snap["Score"]
	var home: int = int(score[my_team])                     # ScoreHome = the human's side (HokejGameMode.cpp:1615-1617)
	var away: int = int(score[1 - my_team])
	var digits_h := "%02d" % home
	var digits_a := "%02d" % away
	var val_w: float = maxf(56.0, lay.measure(digits_h, R.VALUE_PT, "bold_condensed").x)
	var val_wa: float = maxf(56.0, lay.measure(digits_a, R.VALUE_PT, "bold_condensed").x)
	var val_h: float = lay.measure("00", R.VALUE_PT, "bold_condensed").y
	var home_sz := Vector2(18 + val_w + 18, 2 + val_h + 2)
	var away_sz := Vector2(18 + val_wa + 18, 2 + val_h + 2)
	var period := R.format_period(cards.take)                      # F.Take: the game mode's take (HokejGameMode.cpp:1619)
	var rule := R.format_goal_rule(cards.score_to_win)
	var p_sz: Vector2 = lay.measure(period, R.LABEL_PT, "bold_condensed", R.TRACK_LABEL)
	var r_sz: Vector2 = lay.measure(rule, R.LINE_PT, "bold_condensed", R.TRACK_LABEL)
	var centre_w: float = 24 + maxf(p_sz.x, r_sz.x) + 24
	var centre_content_h: float = p_sz.y - 2 + r_sz.y
	var h: float = maxf(home_sz.y, 6 + centre_content_h + 6)
	var total: float = home_sz.x + 6 + centre_w + 6 + away_sz.x
	var x: float = vw * 0.5 - total * 0.5
	var y: float = 14.0
	var shadow := {"shadow": Vector2(0, 1), "shadow_color": Color(0, 0, 0, 0.45)}
	# home plate: FillBrush(white, edge) tinted with the team's colour (the edge is tinted too)
	var c0: Color = col(my_team)
	lay.box(Vector2(x, y), Vector2(home_sz.x, h), c0, 4.0, Color(c0.r, c0.g, c0.b, 0.12), 1.0)
	lay.text(Vector2(x + home_sz.x * 0.5, y + h * 0.5), digits_h, R.VALUE_PT, R.ML_TEXT, _o("bold_condensed", 0, Vector2(0.5, 0.5), shadow))
	x += home_sz.x + 6
	var panel_c := R.ML_PANEL
	panel_c.a = 0.9
	lay.box(Vector2(x, y), Vector2(centre_w, h), panel_c, 4.0, R.ML_EDGE, 1.0)
	var cy: float = y + h * 0.5 - centre_content_h * 0.5
	lay.text(Vector2(x + centre_w * 0.5, cy), period, R.LABEL_PT, R.ML_TEXT_DIM, _o("bold_condensed", R.TRACK_LABEL, Vector2(0.5, 0), shadow))
	lay.text(Vector2(x + centre_w * 0.5, cy + p_sz.y - 2), rule, R.LINE_PT, R.ML_TEXT, _o("bold_condensed", R.TRACK_LABEL, Vector2(0.5, 0), shadow))
	x += centre_w + 6
	var c1: Color = col(1 - my_team)
	lay.box(Vector2(x, y), Vector2(away_sz.x, h), c1, 4.0, Color(c1.r, c1.g, c1.b, 0.12), 1.0)
	lay.text(Vector2(x + away_sz.x * 0.5, y + h * 0.5), digits_a, R.VALUE_PT, R.ML_TEXT, _o("bold_condensed", 0, Vector2(0.5, 0.5), shadow))
	shown["score"] = "%s : %s" % [digits_h, digits_a]
	shown["period"] = period
	shown["rule"] = rule


static func _o(face: String, tracking: int, align: Vector2, extra: Dictionary = {}) -> Dictionary:
	var o := {"face": face, "tracking": tracking, "align": align}
	o.merge(extra)
	return o


# ---------------------------------------------------------------- the rings (UpdateYours cpp:1601-1706, UpdateCarrierCues cpp:1895-1932,
# UpdatePossession HUDPossession.cpp:84-210): each ring as [Rect2, Color]
func _rings(snap: Dictionary, phase: String, me: int, hu: Dictionary, carrier: int, counting: bool, hbox: Rect2, f: int, advanced: bool) -> Dictionary:
	var out: Dictionary = {}
	var sk: Array = snap["Skaters"]
	var play: bool = phase == "play" or phase == "goal_pause"
	if not play:
		possess_carrier = -2
		possess_since = -1
		return out
	var hpos: Vector2 = hu["Pos"]
	var my_team: int = int(hu["Team"])
	var team: Color = col(my_team)
	# yours: 1.1 m, team colour, fading 20 to 24 m from the camera; none while down (and back over 12 frames), none in the box
	var you_r: Rect2 = lay.ground_ring(Vector3(hpos.x, 0.03, hpos.y), R.YOU_RING_M)
	var ring_ok: bool = you_r.size != Vector2.ZERO
	out["ring_ok"] = ring_ok
	var dist: float = lay.eye().distance_to(Vector3(hpos.x, 0.03, hpos.y))
	var ring_a: float = (R.ring_alpha_at(dist) if ring_ok and R.ring_on_ice(int(hu.get("PenaltyFrames", 0)) > 0) else 0.0) * R.ring_down_alpha(human_down, f, human_up_since)
	var you_col := Color(team.r, team.g, team.b, ring_a)
	var you_size_k: float = 1.0
	# the carrier's ring (not you): 0.8 m
	var car_r := Rect2()
	if carrier >= 0 and carrier != me and carrier < sk.size() and R.ring_on_ice(int((sk[carrier] as Dictionary).get("PenaltyFrames", 0)) > 0):
		var cp: Vector2 = (sk[carrier] as Dictionary)["Pos"]
		car_r = lay.ground_ring(Vector3(cp.x, 0.03, cp.y), R.CARRIER_RING_M)
	var car_col := Color(R.PAPER.r, R.PAPER.g, R.PAPER.b, 0.9)
	var car_size_k: float = 1.0
	# the take grace (UpdateCarrierCues): the carrier's ring closes from 1.5 x unless the grace was won by his own hit
	# (cpp:1904-1908: UJamSim::InTakeGrace, the core's Controls.CarrierInTakeGrace, which includes the frame the puck is won in;
	# on that frame TakeGraceLeft is still 0 and the ring stands at the full count)
	var grace: bool = carrier >= 0 and bool((snap.get("Controls", {}) as Dictionary).get("CarrierInTakeGrace", false))
	if grace:
		var gl: int = int((sk[carrier] as Dictionary).get("TakeGraceLeft", 0))
		var left: int = gl if gl > 0 else take_grace_total
		if cue_grace_carrier != carrier:
			grace_from_hit = false
			for e: Dictionary in snap["Events"]:
				if String(e["Name"]) == "check" and int(e["Who"]) == carrier:
					grace_from_hit = true
			for v: Dictionary in sk:
				if int(v.get("ContactBy", -1)) == carrier and int(v["Index"]) != carrier:
					grace_from_hit = true
		var gs: float = R.grace_ring_scale_for(grace_from_hit, left, take_grace_total)
		shown["grace"] = [carrier, gs, left]
		if carrier == me:
			you_size_k *= gs
		else:
			car_size_k *= gs
	cue_grace_carrier = carrier if grace else -1
	# possession at a glance
	var p: int = R.possess_of(carrier, me, int((sk[carrier] as Dictionary)["Team"]) if carrier >= 0 else -1, my_team)
	if carrier != possess_carrier or f < possess_since:
		possess_carrier = carrier
		possess_since = f
	for e: Dictionary in snap["Events"]:
		if String(e["Name"]) == "possess" and int(e["Who"]) == carrier and carrier >= 0:
			possess_since = f
	if carrier != rel_carrier or int(hu.get("Passes", 0)) < rel_passes or int(hu.get("Shots", 0)) < rel_shots:
		rel_carrier = carrier
		rel_passes = int(hu.get("Passes", 0))
		rel_shots = int(hu.get("Shots", 0))
		released = false
	if carrier == me and (int(hu.get("Passes", 0)) > rel_passes or int(hu.get("Shots", 0)) > rel_shots):
		released = true
	var is_released: bool = released and carrier == me
	var age: int = f - possess_since
	var pulse: float = 1.0 if grace else R.possess_pulse_scale(age)
	# his own rings fade near the camera's eye (jam.hud.RingNearCam 1)
	var near: float = lerpf(R.NEAR_CAM_RING_ALPHA, 1.0, clampf((lay.eye().distance_to(Vector3(hpos.x, 0, hpos.y)) - R.NEAR_CAM_FADE_M) / (R.NEAR_CAM_FULL_M - R.NEAR_CAM_FADE_M), 0.0, 1.0))
	you_col.a *= near
	if p == 1 and not is_released and ring_a > 0.0:
		you_size_k *= pulse
		var have := R.scaled(you_r, you_size_k * R.YOU_HAVE_RING_SCALE)
		out["you_have"] = [have, Color(team.r, team.g, team.b, you_col.a * R.YOU_HAVE_RING_ALPHA)]
	if (p == 2 or p == 3) and car_r.size != Vector2.ZERO:
		var cc: Color = col(int((sk[carrier] as Dictionary)["Team"]))
		car_col = Color(cc.r, cc.g, cc.b, 0.95)
		car_size_k *= pulse
	if ring_a > 0.0:
		out["you"] = [R.scaled(you_r, you_size_k), you_col]
	if car_r.size != Vector2.ZERO:
		out["carrier"] = [R.scaled(car_r, car_size_k), car_col]
	# the loose puck (jam.hud.Possess 1): a chalk ring of 0.42 m, yellow past 22 m, never under 40 units across
	if p == 0 and phase == "play" and not counting:
		var pp: Vector2 = (snap["Puck"] as Dictionary)["Pos"]
		var lr: Rect2 = lay.ground_ring(Vector3(pp.x, 0.03, pp.y), R.LOOSE_RING_M)
		if lr.size != Vector2.ZERO:
			var lsz: Vector2 = lr.size * R.possess_pulse_scale(age)
			if lsz.x > 0.0 and lsz.x < R.LOOSE_RING_MIN_PX:
				lsz *= R.LOOSE_RING_MIN_PX / lsz.x
			var lrect := Rect2(lr.get_center() - lsz * 0.5, lsz)
			var flying: bool = int((snap["Puck"] as Dictionary).get("PassFrames", 0)) > 0
			var on_him: bool = hbox.size != Vector2.ZERO and lrect.intersects(hbox)
			if not flying and not on_him:
				var pdist: float = lay.eye().distance_to(Vector3(pp.x, 0.03, pp.y))
				var lc: Color = R.YELLOW if pdist > R.LOOSE_RING_FAR_M else R.PAPER
				out["loose"] = [lrect, Color(lc.r, lc.g, lc.b, 0.9)]
	shown["possess"] = ["loose", "you", "mate", "opponent"][0 if is_released else p]
	return out


## A figure's box on the screen from its bones (source 2): every joint projected, grown by FigurePadCm (14 cm, h:239) at the
## figure's depth; Rect2() when a joint is behind the camera.
func _bones_box(pts: PackedVector3Array) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var sum := Vector3.ZERO
	for w: Vector3 in pts:
		var p: Vector3 = lay.project(w)
		if p.z <= 0.0:
			return Rect2()
		lo = lo.min(Vector2(p.x, p.y))
		hi = hi.max(Vector2(p.x, p.y))
		sum += w
	var c: Vector3 = sum / float(pts.size())
	var a: Vector3 = lay.project(c)
	var b: Vector3 = lay.project(c + Vector3(0, 0.14, 0))
	var pad: float = absf(a.y - b.y) if a.z > 0.0 and b.z > 0.0 else 0.0
	return Rect2(lo - Vector2(pad, pad), hi - lo + Vector2(pad, pad) * 2.0)


## A figure's box on the screen: its bounds plus FigurePadCm (h:239) projected; Rect2() off the frame (the stand-in, source 1).
func _figure_box(pos: Vector2, yaw: float, down: bool) -> Rect2:
	var pad: float = 0.14
	var top: float = (0.4 if down else figure_box_m.y) + pad
	var r: float = figure_box_m.x + pad
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for dx: float in [-r, r]:
		for dz: float in [-r, r]:
			for y: float in [0.0, top]:
				var p: Vector3 = lay.project(Vector3(pos.x + dx, y, pos.y + dz))
				if p.z <= 0.0:
					return Rect2()
				lo = lo.min(Vector2(p.x, p.y))
				hi = hi.max(Vector2(p.x, p.y))
	return Rect2(lo, hi - lo)


# ---------------------------------------------------------------- the YOU chevron and tag
func _you_marker(hu: Dictionary, puck_pos: Vector2, ring_ok: bool, counting: bool, advanced: bool) -> void:
	var hp: Vector2 = hu["Pos"]
	var hw: Vector3 = head_override if head_override != Vector3.INF else Vector3(hp.x, head_m, hp.y)   # the head socket, else the stand-in's bounds top
	var head3: Vector3 = lay.project(hw)
	var b_head: bool = ring_ok and head3.z > 0.0
	if not b_head:
		return
	var head := Vector2(head3.x, head3.y)
	var tip: Vector2 = head + Vector2(0, -R.YOU_MARKER_GAP_PX)
	var chev: Rect2 = R.you_chevron_box(tip)
	var tag: Rect2 = R.you_tag_box(tip)
	var pk3: Vector3 = lay.project(Vector3(puck_pos.x, 0.1, puck_pos.y))
	var b_puck: bool = pk3.z > 0.0
	var puck_px := Vector2(pk3.x, pk3.y)
	var target: float = R.MARKER_GHOST_ALPHA if b_puck and R.marker_box_has_puck(chev.position, chev.end, puck_px) else 1.0
	if advanced:
		marker_yield += clampf(target - marker_yield, -0.12, 0.12)
	var tag_on_puck: bool = b_puck and R.marker_box_has_puck(tag.position, tag.end, puck_px)
	# the chevron: take-yellow, a 2.5 ink edge (cpp:1666-1672), its bottom centre on the tip
	var yc := R.YELLOW
	yc.a = marker_yield
	lay.chevron(tip, R.YOU_MARKER_SIZE_PX, yc, Color(0, 0, 0, 0.95), 2.5, 0.0, Vector2(0.5, 1.0))
	shown["chevron"] = marker_yield
	# the tag: while a faceoff counts down, never on the puck; over the chevron (alignment 0.5, 1 at head - 56)
	if R.show_you_tag_live(counting) and not tag_on_puck:
		var t_sz: Vector2 = lay.measure("YOU", R.LINE_PT, "black", R.TRACK_LABEL)
		var plate := Vector2(12 + t_sz.x + 12, 3 + t_sz.y + 4)
		var at: Vector2 = head + Vector2(0, -(R.YOU_MARKER_GAP_PX + R.YOU_MARKER_SIZE_PX + 4.0))
		var tl: Vector2 = at - Vector2(plate.x * 0.5, plate.y)
		var tc: Color = col(int(hu["Team"]))
		lay.box(tl, plate, tc, 4.0, Color(0, 0, 0, 0.9), 2.0)                     # YouTagBrush (HUDOneLook.cpp:264-267)
		lay.text(tl + Vector2(12, 3), "YOU", R.LINE_PT, R.ML_TEXT, _o("black", R.TRACK_LABEL, Vector2.ZERO, {"shadow": Vector2(0, 1), "shadow_color": Color(0, 0, 0, 0.45)}))
		shown["you_tag"] = true


# ---------------------------------------------------------------- the radar (RadarWidget.cpp), framed in the one look
func _radar(snap: Dictionary, vw: float, vh: float, me: int) -> void:
	var frame_sz := Vector2(R.RADAR_W + 12.0, R.RADAR_H + 12.0)
	var at := Vector2(vw - R.EDGE_PX - frame_sz.x, vh - R.EDGE_PX - frame_sz.y)
	var fill := R.ML_PANEL
	fill.a = 0.82
	lay.box(at, frame_sz, fill, 4.0, R.ML_EDGE, 1.0)
	var o: Vector2 = at + Vector2(6, 6)
	var w: float = R.RADAR_W
	var h: float = R.RADAR_H
	lay.box(o, Vector2(w, h), Color(0.02, 0.05, 0.10, 0.65).linear_to_srgb())     # FLinearColor literals are linear (Slate draws in sRGB)
	var line_c := Color(1, 1, 1, 0.45)
	lay.box(o + Vector2(w * 0.5 - 0.5, 0), Vector2(1, h), line_c)
	var edge := Color(1, 1, 1, 0.35)
	lay.box(o, Vector2(w, 1), edge)
	lay.box(o + Vector2(0, h - 1), Vector2(w, 1), edge)
	lay.box(o, Vector2(1, h), edge)
	lay.box(o + Vector2(w - 1, 0), Vector2(1, h), edge)
	var field := Vector2(length_m, width_m)
	var dots: Array = []
	var sk: Array = snap["Skaters"]
	var my_team: int = int((sk[me] as Dictionary)["Team"])
	for i: int in sk.size():
		var s: Dictionary = sk[i]
		if i == me:
			dots.append({"at": s["Pos"], "size": 16.0, "color": Color(1.0, 0.9, 0.2).linear_to_srgb()})   # the yellow square under the human
		dots.append({"at": s["Pos"], "size": 12.0 if i == me else 9.0, "color": col(int(s["Team"]))})
	for s: Dictionary in sk:                                         # jam.hit.OffScreen 1: the downed men (HokejGameMode.cpp:1583)
		if bool(s.get("IsDown", false)):
			var kd: Vector2 = s.get("KnockDir", Vector2.ZERO)
			var mid: Vector2 = (s["Pos"] as Vector2) + kd.normalized() * (1.7 * 0.5)
			dots.append({"at": mid, "size": 15.0, "color": col(int(s["Team"])), "mark": "hollow" if int(s["Team"]) == my_team else "x"})
	dots.append({"at": (snap["Puck"] as Dictionary)["Pos"], "size": 6.0, "color": Color.WHITE})
	lay.minimap(o, Vector2(w, h), field, dots)
	shown["radar"] = dots.size()


# ---------------------------------------------------------------- the faceoff dial (cpp:741-770, 1032-1061)
func _dial(vw: float, vh: float, frames: int, counting: bool, drop: bool, result: bool, human_c: Color) -> void:
	var c := Vector2(vw * 0.5 + R.RING_OFFSET_CLEAR_X, vh * 0.66)
	var s: float = R.RING_BOX_PX
	if art_dial != null:
		lay.image(art_dial, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)))   # S::Ring(220): T_UI_Ring, untinted (MenuStyle.h:156-160)
	else:
		_ring_art(c, s)
	if counting:
		var digit := str(ceili(frames / 60.0))
		var dsz: Vector2 = lay.measure(digit, 72, "black")
		var wsz: Vector2 = lay.measure("HOLD", 24, "black", 60)
		var top: float = c.y - (dsz.y + wsz.y - 6.0) * 0.5
		lay.text(Vector2(c.x, top), digit, 72, R.PAPER, {"face": "black", "align": Vector2(0.5, 0), "outline": 2.0, "outline_color": Color(0, 0, 0, 0.9)})
		lay.text(Vector2(c.x, top + dsz.y - 6.0), R.faceoff_cue(frames, false), 24, R.YELLOW, {"face": "black", "tracking": 60, "align": Vector2(0.5, 0), "outline": 2.0, "outline_color": Color(0, 0, 0, 0.9)})
		shown["dial"] = digit + " HOLD"
	else:
		var word: String = R.draw_result_text(last_draw_won) if result else R.faceoff_cue(0, true)
		var wc: Color = human_c if result else R.YELLOW
		lay.text(c, word, 44, wc, {"face": "black", "tracking": 60, "align": Vector2(0.5, 0.5), "outline": 2.0, "outline_color": Color(0, 0, 0, 0.9)})
		shown["dial"] = word


## T_UI_Ring (the film leader's ring, an AI-made texture we do not have): drawn here as its parts read on thirdjam's stills
## (h43-02-faceoff-stands.png): a chalk ring with an ink edge, the home blue and away orange arcs inside it, four ticks.
## The ground ring: T_UI_RingPlain (exported from thirdjam's project, 512 px) stretched into the ellipse's box and tinted
## (MakeGroundRing cpp:351-361); without the picture, the band drawn to its measure.
func _ring(r: Rect2, c: Color) -> void:
	if art_ring != null:
		lay.image(art_ring, r, c)
	else:
		lay.ring(r, c)


func _ring_art(c: Vector2, s: float) -> void:
	var r := Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
	lay.ring(r, R.PAPER, 0.03, 0.006)
	var inner := Rect2(c - Vector2(s, s) * 0.42, Vector2(s, s) * 0.84)
	lay.ring(inner, R.PAPER, 0.012, 0.0)
	for q: int in 4:
		var a0: float = deg_to_rad(-80.0 + 90.0 * q)
		var pts := PackedVector2Array()
		for i: int in 13:
			var t: float = a0 + deg_to_rad(70.0) * i / 12.0
			pts.append(c + Vector2(cos(t), sin(t)) * s * 0.455)
		for i: int in range(12, -1, -1):
			var t: float = a0 + deg_to_rad(70.0) * i / 12.0
			pts.append(c + Vector2(cos(t), sin(t)) * s * 0.425)
		lay.polygon(pts, R.ML_HOME if q % 2 == 1 else R.ML_AWAY)
	for q: int in 4:
		var d := Vector2.RIGHT.rotated(PI * 0.5 * q)
		lay.line(c + d * s * 0.36, c + d * s * 0.53, R.PAPER, 3.0)


func _faceoff_hint(vw: float, vh: float) -> void:
	var t: String = R.faceoff_hint_text()
	var sz: Vector2 = lay.measure(t, R.LINE_PT, "bold_condensed", R.TRACK_LABEL)
	var plate := Vector2(16 + sz.x + 16, 6 + sz.y + 6)
	var top := Vector2(vw * 0.5 + R.RING_OFFSET_CLEAR_X, vh * 0.66 + 124.0)
	var tl: Vector2 = top - Vector2(plate.x * 0.5, 0)
	var fill := R.ML_PANEL
	fill.a = 0.86
	lay.box(tl, plate, fill, 4.0, R.ML_EDGE, 1.0)
	lay.text(tl + Vector2(16, 6), t, R.LINE_PT, R.ML_TEXT, {"face": "bold_condensed", "tracking": R.TRACK_LABEL, "shadow": Vector2(0, 1), "shadow_color": Color(0, 0, 0, 0.45)})
	shown["faceoff_hint"] = t
