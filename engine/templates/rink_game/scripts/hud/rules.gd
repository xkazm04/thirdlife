extends RefCounted
## thirdjam's HUD rules, pure (no camera, no node): the constants and the show rules of UJamHudWidget ... [base README: scripts/hud/rules.gd §1]
const INK := Color("#0e1014")
const PAPER := Color("#f4f4f0")
const BLUE := Color("#1d4ed8")
const ORANGE := Color("#e8651a")
const YELLOW := Color("#ffd966")
const MUTED := Color("#9aa0a8")
const ML_HOME := Color("#2f6bff")          # FJamMenuLook::Home
const ML_AWAY := Color("#f26a1b")          # FJamMenuLook::Away (= Focus)
const ML_INK := Color("#0a0c10")
const ML_PANEL := Color("#141821")         # alpha 0.90 in the menu; each HUD plate sets its own
const ML_EDGE := Color(1, 1, 1, 0.12)      # FJamMenuLook::PanelEdge
const ML_TEXT := Color("#f5f6f8")
const ML_TEXT_DIM := Color("#a3abb8")
const ML_ON_FOCUS := Color(1, 1, 1)
const LOOSE_GREY := Color("#6b727a")       # the puck marker's loose colour (cpp:1352)
const EDGE_PX := 24.0                      # FJamUiStyle::EdgePx (MenuStyle.h:76)
const TRACK_LABEL := 60                    # FJamMenuLook::TrackLabel (MenuWidget.h:110)
const LABEL_PT := 14   # type sizes of the one look (h:1146-1148), Unreal points
const LINE_PT := 18
const VALUE_PT := 40

# ---- rings, marker, labels (h)
const YOU_RING_M := 1.1                    # h:789
const CARRIER_RING_M := 0.8                # h:790
const RING_FADE_START_M := 20.0            # h:791
const RING_FADE_END_M := 24.0              # h:792
const RING_BACK_FRAMES := 12               # h:234
const YOU_MARKER_GAP_PX := 4.0             # h:195
const YOU_MARKER_SIZE_PX := 48.0           # h:196
const MARKER_YIELD_PAD_PX := 10.0          # h:335
const MARKER_GHOST_ALPHA := 0.3            # h:336
const YOU_HAVE_RING_SCALE := 1.25          # h:506
const YOU_HAVE_RING_ALPHA := 0.75          # h:507
const LOOSE_RING_M := 0.42                 # h:508
const LOOSE_RING_MIN_PX := 40.0            # h:509
const LOOSE_RING_FAR_M := 22.0             # h:512
const POSSESS_PULSE_FRAMES := 14           # h:513
const POSSESS_PULSE_GROW := 0.6            # h:514
const TAKE_GRACE_RING_GROW := 0.5          # h:459
const NEAR_CAM_RING_ALPHA := 0.3           # HUDPossession.cpp:33
const NEAR_CAM_FADE_M := 2.5               # HUDPossession.cpp:34
const NEAR_CAM_FULL_M := 3.5
const LABEL_PLATE_OPACITY := 0.62          # h:209
const LABEL_PLATE_PAD_X := 8.0             # h:210
const LABEL_PLATE_PAD_Y := 2.0             # h:211
const MARKER_EDGE_PX := 48.0               # h:808
const NET_CROSSBAR_M := 0.61               # h:840
const NET_BADGE_LIFT_M := 1.20             # h:841
const NET_BADGE_GAP_PX := 40.0             # h:842
const EDGE_SLOT_PX := 48.0                 # h:843
const PUCK_MARKER_INNER_FRAC := 0.85       # h:844
const PUCK_MARKER_FADE_FRAMES := 6         # h:845
const PUCK_MARKER_CARD_FRAMES := 150       # h:846
const CORNER_FURNITURE_W := 410.0          # h:309
const CORNER_FURNITURE_H := 246.0          # h:310
const NET_INSET_M := 4.0                   # HokejGameMode.cpp:1617
# ---- faceoff dial (h)
const DROP_FRAMES := 30                    # h:772
const FACEOFF_HINT_COUNT := 3              # h:800
const DRAW_RESULT_FRAMES := 40             # h:803
const RING_OFFSET_CLEAR_X := 440.0         # h:434 (jam.hud.ClearMiddle 1)
const RING_BOX_PX := 220.0                 # h:435
const YOU_TAG_START_FRAMES := 300          # h:782
const YOU_TAG_AFTER_DROP_FRAMES := 120     # h:783
const PANEL_MAX_ROWS := 8   # ---- controls panel (h:111-119, HUDControlsPanel.cpp)
const PANEL_FADE_FRAMES := 6
const PANEL_MAX_W := 300.0
const PANEL_KEYCAP_H := 22.0
const PANEL_KEYCAP_MIN_W := 84.0
const PANEL_RESERVE_H := 300.0
const PANEL_MIN_W := 264.0
const PANEL_PAD := 12.0
const PANEL_ROW_GAP := 4.0
const PANEL_HOLD_FRAMES := 12              # jam.hud.PanelHoldFrames (HUDControlsPanel.cpp:36)
const BADGE_DOWN_OPACITY := 0.3            # h:72
const SPRINT_SPENT_BELOW := 0.25           # h:140
const BRACE_HOLD_FRAMES := 13              # JamControls::BraceHoldFrames (lane A199), human_input.gd BRACE_HOLD
const RADAR_W := 200.0   # ---- radar (RadarWidget.h:44-45)
const RADAR_H := 100.0


# ---------------------------------------------------------------- formats
static func format_period(take: int) -> String:              # h:354
	return "PERIOD %d" % maxi(1, take)


static func format_goal_rule(score_to_win: int) -> String:    # h:355
	return "FIRST TO %d" % score_to_win if score_to_win > 0 else ""


static func format_timer(frames_remaining: int) -> String:    # cpp:431-435
	var secs: int = maxi(0, ceili(frames_remaining / 60.0))
	return "%d:%02d" % [secs / 60, secs % 60]


static func own_label_text(distance_m: int) -> String:        # h:1184 (jam.hud.OneLook 1)
	return "OWN  %d M" % distance_m


static func box_plate_text(frames_left: int) -> String:       # h:148
	return "IN THE BOX  %d" % ((frames_left + 59) / 60) if frames_left > 0 else ""


static func faceoff_cue(countdown_frames: int, dropped: bool) -> String:   # h:798
	return "HOLD" if countdown_frames > 0 else ("DROP" if dropped else "")


static func draw_result_text(won: bool) -> String:            # h:804
	return "WON" if won else "LOST"


static func faceoff_hint_text() -> String:                    # h:801, upper-cased by the one look (HUDOneLook.cpp:86)
	return "press shoot at the drop, not before".to_upper()


# ---------------------------------------------------------------- show rules
static func ring_alpha_at(camera_distance_m: float) -> float:              # h:793-796
	return 1.0 - clampf((camera_distance_m - RING_FADE_START_M) / (RING_FADE_END_M - RING_FADE_START_M), 0.0, 1.0)


## jam.hud.ClearDown 1: 0 while down, a ramp over RingBackFrames from the get-up frame (h:246-252).
static func ring_down_alpha(down: bool, sim_frame: int, up_since: int) -> float:
	if down:
		return 0.0
	if up_since < 0 or sim_frame < up_since:
		return 1.0
	return clampf(float(sim_frame - up_since + 1) / float(RING_BACK_FRAMES), 0.0, 1.0)


## jam.hud.BoxedRing 0: no ring under a skater in the box (h:244).
static func ring_on_ice(in_box: bool) -> bool:
	return not in_box


## The YOU tag (jam.hud.YouMarker 1, jam.hud.ClearMiddle 1): while a faceoff counts down (h:344-347).
static func show_you_tag_live(counting_down: bool) -> bool:
	return counting_down


static func marker_box_has_puck(lo: Vector2, hi: Vector2, puck: Vector2, pad: float = MARKER_YIELD_PAD_PX) -> bool:   # h:337-340
	return puck.x >= lo.x - pad and puck.x <= hi.x + pad and puck.y >= lo.y - pad and puck.y <= hi.y + pad


static func you_chevron_box(tip: Vector2) -> Rect2:           # h:325-328
	return Rect2(tip + Vector2(-YOU_MARKER_SIZE_PX * 0.5, -YOU_MARKER_SIZE_PX), Vector2(YOU_MARKER_SIZE_PX, YOU_MARKER_SIZE_PX))


static func you_tag_box(tip: Vector2) -> Rect2:               # h:329-332
	return Rect2(tip + Vector2(-38.0, -(YOU_MARKER_SIZE_PX + 4.0 + 34.0)), Vector2(76.0, 34.0))


## The pulse at a pickup: 1 + Grow at the pickup, easing to 1 at PossessPulseFrames (h:516-521).
static func possess_pulse_scale(age: int) -> float:
	if age < 0 or age >= POSSESS_PULSE_FRAMES:
		return 1.0
	var t: float = 1.0 - float(age) / float(POSSESS_PULSE_FRAMES)
	return 1.0 + POSSESS_PULSE_GROW * t * t


static func take_grace_ring_scale(left: int, total: int) -> float:         # h:465-468
	return 1.0 if left <= 0 or total <= 0 else 1.0 + TAKE_GRACE_RING_GROW * clampf(float(left) / float(total), 0.0, 1.0)


## jam.hud.SwellAtHit 0: a grace won by the carrier's own hit keeps the ring's size (h:462). [base README: scripts/hud/rules.gd §2]
static func scaled(r: Rect2, k: float) -> Rect2:
	if k == 1.0:
		return r
	var s: Vector2 = r.size * k
	return Rect2(r.get_center() - s * 0.5, s)


static func grace_ring_scale_for(from_hit: bool, left: int, total: int) -> float:
	return 1.0 if from_hit else take_grace_ring_scale(left, total)


## 0 loose, 1 you, 2 mate, 3 opponent (h:497-503).
static func possess_of(carrier: int, human: int, carrier_team: int, human_team: int) -> int:
	if carrier < 0:
		return 0
	if carrier == human:
		return 1
	return 2 if carrier_team == human_team else 3


static func in_middle_third(lo: Vector2, hi: Vector2, vw: float, vh: float) -> bool:   # h:217-220
	return hi.x > vw / 3.0 and lo.x < vw * 2.0 / 3.0 and hi.y > vh / 3.0 and lo.y < vh * 2.0 / 3.0


## jam.hud.LabelPlates 1: no net badge during the goal pause (h:212). Phase: the presentation phase (see phase_of).
static func show_net_badges(phase: String) -> bool:
	return phase != "goal_pause"


## jam.hud.OwnMarkOnNet 0: the own-net marker only while that net is off the frame (h:281).
static func show_own_marker(on_screen: bool) -> bool:
	return not on_screen


## jam.hud.OwnThird 1: the own-net marker only in his own third (h:548).
static func in_own_third(human_x: float, attack_sign: float, rink_length: float) -> bool:
	return -attack_sign * human_x > rink_length / 6.0


static func clamp_marker(sp: Vector2, vw: float, vh: float, half_w: float, top: float, bottom: float) -> Vector2:   # h:809-812
	return Vector2(clampf(sp.x, MARKER_EDGE_PX + half_w, vw - MARKER_EDGE_PX - half_w), clampf(sp.y, top, vh - MARKER_EDGE_PX - bottom))


static func keep_off_panel(p: Vector2, vh: float, panel_top: float, pad: float, edge_px: float) -> Vector2:   # h:182-186
	if panel_top <= 0.0 or p.x >= edge_px + PANEL_MAX_W + pad or p.y <= vh - panel_top - pad:
		return p
	return Vector2(p.x, vh - panel_top - pad)


static func keep_off_radar(p: Vector2, vw: float, vh: float, half_w: float, below: float) -> Vector2:   # h:311-315
	if p.x + half_w > vw - CORNER_FURNITURE_W and p.y + below > vh - CORNER_FURNITURE_H:
		p.y = vh - CORNER_FURNITURE_H - below
	return p


static func outside_inner_frame(sp: Vector2, vw: float, vh: float, frac: float = PUCK_MARKER_INNER_FRAC) -> bool:   # h:848-851
	return sp.x < vw * (1.0 - frac) * 0.5 or sp.x > vw * (1.0 + frac) * 0.5 or sp.y < vh * (1.0 - frac) * 0.5 or sp.y > vh * (1.0 + frac) * 0.5


static func puck_marker_edge_point(dir: Vector2, vw: float, vh: float, left: float, right: float, top: float, bottom: float) -> Vector2:   # h:853-860
	if dir.is_zero_approx():
		dir = Vector2(0, 1)
	var c := Vector2(vw * 0.5, vh * 0.5)
	var tx: float = ((right - c.x) if dir.x > 0 else (c.x - left)) / absf(dir.x) if absf(dir.x) > 1e-4 else INF
	var ty: float = ((bottom - c.y) if dir.y > 0 else (c.y - top)) / absf(dir.y) if absf(dir.y) > 1e-4 else INF
	return c + dir * minf(tx, ty)


static func label_plate_pos(label_pos: Vector2, align: Vector2) -> Vector2:   # h:214
	return label_pos + Vector2(LABEL_PLATE_PAD_X * (2.0 * align.x - 1.0), LABEL_PLATE_PAD_Y * (2.0 * align.y - 1.0))


## The controls panel shows while play runs: not paused, no GOAL banner (h:108).
static func show_controls_panel(phase: String, paused: bool, goal_banner_up: bool) -> bool:
	return phase == "play" and not paused and not goal_banner_up


static func legs_spent(stamina01: float, sprinting: bool) -> bool:          # h:141
	return not sprinting and stamina01 < SPRINT_SPENT_BELOW


## The one look: markers stand down while a card is up (h:1161, jam.hud.OneLook 1).
static func labels_stand_down(match_card: bool, banner: bool, pause: bool, end: bool) -> bool:
	return match_card or banner or pause or end


## W7 (jam.hud.FaceoffCueInBox 0): the dial and its hint are not drawn for a man in the box (h:1182).
static func faceoff_cue_hidden_in_box(penalty_frames: int) -> bool:
	return penalty_frames > 0


## thirdjam's presentation phase from the sim's (HokejGameMode.cpp:1622-1628): play (also the faceoff), goal_pause, win, lose.
static func phase_of(snap: Dictionary) -> String:
	match int(snap["Phase"]):
		1:
			return "goal_pause"
		2:
			var me: int = int(snap["HumanIndex"])
			var team: int = int((snap["Skaters"][me] as Dictionary)["Team"])
			return "win" if int(snap["Winner"]) == team else "lose"
		_:
			return "play"


# ---------------------------------------------------------------- the controls panel's rows ... [base README: scripts/hud/rules.gd §3]
const KEYCAP := {"Shoot": "LMB", "CrossCheck": "LMB", "Pass": "RMB", "Check": "RMB", "Poke": "SPACE", "Deke": "WHEEL", "Spin": "E",
	"Ability": "F", "Sprint": "SHIFT", "Brake": "CTRL", "Skate": "WASD"}
const LABEL := {"Shoot": "SHOOT", "CrossCheck": "CROSS-CHECK", "Pass": "PASS", "Check": "CHECK", "Poke": "POKE", "Deke": "DEKE",
	"Spin": "SPIN", "Ability": "ABILITY", "Sprint": "SPRINT", "Brake": "BRAKE", "Skate": "SKATE"}   # GVerbs (InputMapping.cpp:82-87); the skate row says SKATE


## Rows: [{verb, key, word, lit, poss}]. held: {verb: true}; saucer / braced: the hold's words.
static func panel_rows(with_puck: bool, ability: bool, held: Dictionary, saucer: bool, braced: bool) -> Array:
	var rows: Array = []
	if with_puck:
		rows.append(_row("Shoot", LABEL["Shoot"], true, held))
		rows.append(_row("Pass", "SAUCER" if saucer and held.has("Pass") else LABEL["Pass"], true, held))
		rows.append(_row("Deke", LABEL["Deke"], true, held))
		rows.append(_row("Spin", LABEL["Spin"], true, held))
	else:
		rows.append(_row("CrossCheck", "BRACED" if braced and held.has("CrossCheck") else LABEL["CrossCheck"], true, held))
		rows.append(_row("Check", LABEL["Check"], true, held))
		rows.append(_row("Poke", LABEL["Poke"], true, held))
	rows.append(_row("Skate", "SKATE", false, held))
	rows.append(_row("Sprint", LABEL["Sprint"], false, held))
	rows.append(_row("Brake", LABEL["Brake"], false, held))
	if ability:
		rows.append(_row("Ability", LABEL["Ability"], false, held))
	return rows


static func _row(v: String, word: String, poss: bool, held: Dictionary) -> Dictionary:
	return {"verb": v, "key": KEYCAP[v], "word": word, "lit": held.has(v), "poss": poss}


## FControlsPanelSwap::Step (HUDControlsPanel.cpp:87-104): the half shown. [base README: scripts/hud/rules.gd §4]
static func panel_swap_step(st: Dictionary, with: bool, press: bool, frame: int, hold: int = PANEL_HOLD_FRAMES) -> bool:
	if frame < int(st.get("last_frame", -1)):
		st.clear()
	if st.is_empty():
		st.merge({"shown": -1, "last_swap": -1000000, "loss_start": -1, "last_frame": -1})
	st["last_frame"] = frame
	var truth: int = 1 if with else 0
	if truth == 1:
		st["loss_start"] = -1
	elif int(st["loss_start"]) < 0:
		st["loss_start"] = frame
	if int(st["shown"]) < 0:
		st["shown"] = truth
		return false
	if truth == int(st["shown"]):
		return false
	var go: bool
	if hold <= 0 or press:
		go = true
	elif frame - int(st["last_swap"]) < hold:
		go = false
	elif truth == 1:
		go = true
	else:
		go = frame - int(st["loss_start"]) >= hold
	if not go:
		return false
	st["shown"] = truth
	st["last_swap"] = frame
	return true


# ---------------------------------------------------------------- the teaching pulse (HUDTeach.cpp; HUDWidget.h:590-622)
const TEACH_MAX_SHOWS := 3                 # h:598
const TEACH_SHOW_FRAMES := 90              # h:599
const TEACH_GAP_FRAMES := 900              # h:600
const TEACH_HIT_RANGE_M := 2.6             # h:601
const TEACH_DROP_QUIET_FRAMES := 60        # HUDTeach.cpp:88: no teaching in the draw's first second
const PASS_FLIGHT_RING_FRAMES := 45        # HUDChargeLook.cpp:34
const PASS_RING_SCALE := 1.15              # HUDChargeLook.cpp:87, :104: CarrierRingRadiusM * 1.15
const POWER_FULL_FRAMES := 30              # FJamPassConfig::PowerFullFrames (JamCartridge.h:363); the cartridge has no game.pass


## One sim frame of a kind's rule (TeachStep, h:604-616): true while its pulse shows this frame. [base README: scripts/hud/rules.gd §5]
static func teach_step(st: Dictionary, due: bool, did: bool, frame: int) -> bool:
	if st.is_empty():
		st.merge({"shows": 0, "done": false, "shown_at": -1, "last_end": -1000000})
	if did:
		st["done"] = true
	if frame < int(st["last_end"]) or (int(st["shown_at"]) >= 0 and frame < int(st["shown_at"])):   # a new match: the count went back
		st["last_end"] = -1000000
		st["shown_at"] = -1
	if int(st["shown_at"]) >= 0:
		if not bool(st["done"]) and frame >= int(st["shown_at"]) and frame < int(st["shown_at"]) + TEACH_SHOW_FRAMES:
			return true
		st["last_end"] = frame
		st["shown_at"] = -1
	if bool(st["done"]) or not due or int(st["shows"]) >= TEACH_MAX_SHOWS or frame - int(st["last_end"]) < TEACH_GAP_FRAMES:
		return false
	st["shown_at"] = frame
	st["shows"] = int(st["shows"]) + 1
	return true
