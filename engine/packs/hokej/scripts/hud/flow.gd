extends RefCounted
## thirdjam's match flow on the screen (lane K5, round 2), HEAD 8dc713c6, every cvar at its default:
##   the GOAL banner   HUDGoalBanner.cpp:30-252: device B's T_UI_Banner_Goal (exported, assets/hud/) stretched into
##                     760 x 176 at (0.5 W, 0.30 H) (0.205 H when the scorer stands under that band), tinted lerp(white, the
##                     scoring side's colour, 0.25); in over 12 frames, out over 12, gone 6 before the pause ends; a punch
##                     1.25 -> 1 in, 1 -> 0.96 out; only when a score grew; on the match-ending goal it plays in the end card's wait;
##   the end card      HUDWidget.cpp:446-497, 772-799, 952-982; HUDEndWait.cpp; HUDEndStats.cpp; HUDOneLook.cpp:123-181:
##                     after 1.9 s, a panel 704 wide at (0.5 W, 0.4 H): YOU WIN / BEATEN / NO WINNER, YOU  a : b  THEM, the
##                     stats table, the team rule, the key caps R / VIEW REMATCH, ESC / START MENU;
##   IN THE BOX n      HUDWidget.cpp:578-586, 836-845 (jam.cam.BoxFollowsPlay 1).
## Presentation only. Time is the HUD's own frame count where the sim stands still (the end phase).

const R := preload("rules.gd")
const BANNER_W := 760.0
const BANNER_H := 176.0
const BANNER_IN := 12            # h:1113-1115
const BANNER_OUT := 12
const BANNER_LEAD := 6
const END_WAIT_FRAMES := 114     # EndCardWaitSec 1.9 s (h:628) at 60 frames a second: DEVIATION (thirdjam counts wall-clock seconds)
const END_CARD_W := 704.0        # h:730
const END_WORD_PT := 72          # h:731
const PASS_ARRIVE := 180         # h:568

var lay
var hud
var art_banner: Texture2D
var art_panel: Texture2D
var goal_pause_frames: int = 120
# the banner
var last_home: int = -1
var last_away: int = -1
var banner_start: int = -1       # the HUD tick the banner began
var banner_team: int = 0         # the scoring team id
var banner_y: float = 0.30
var banner_alpha: float = 0.0
# the end
var end_seen: int = -1           # the HUD tick the end phase was first seen
var tick: int = 0
# the stats (FEndStats)
var st: Dictionary = {}
var seen: Dictionary = {}
var pass_pending: int = -1
var last_frame: int = -1
var final_counted: bool = false
var shown: Dictionary = {}
var _since: int = -1
var _paint_args: Array = []


func _init(owner, game: Dictionary) -> void:
	hud = owner
	lay = owner.lay
	goal_pause_frames = int((game.get("rules", {}) as Dictionary).get("goal_pause_frames", 120))
	if lay.has_method("image_of"):
		art_banner = lay.image_of("assets/hud/T_UI_Banner_Goal.png")
		art_panel = lay.image_of("assets/hud/T_UI_Panel.png")
	_reset_stats({})


static func banner_alpha_at(since: int, pause: int) -> float:       # GoalBannerAlpha (HUDGoalBanner.cpp:69-79)
	if since < 0 or pause <= 0:
		return 0.0
	var i: int = BANNER_IN
	var o: int = BANNER_OUT
	var lead: int = BANNER_LEAD
	if pause < i + o + lead + 12:
		i = maxi(1, pause / 3)
		o = i
		lead = 0
	var end: int = pause - lead
	if since >= end:
		return 0.0
	if since < i:
		return float(since + 1) / float(i)
	if since >= end - o:
		return clampf(float(end - since) / float(o), 0.0, 1.0)
	return 1.0


static func banner_centre_y(top_y: float, foot_y: float) -> float:   # GoalBannerCentreY (HUDGoalBanner.cpp:81-92)
	var mid := 0.30
	var high := 0.205
	if top_y < 0.0:
		return mid
	var half: float = BANNER_H * 0.5 / 1080.0
	var at_mid: float = maxf(0.0, minf(foot_y, mid + half) - maxf(top_y, mid - half))
	if at_mid <= 0.0:
		return mid
	var at_high: float = maxf(0.0, minf(foot_y, high + half) - maxf(top_y, high - half))
	return high if at_high < at_mid else mid


static func end_card_word(phase: String, mine: int, theirs: int) -> String:   # EndCardWord, CardFor (cpp:446-462)
	if phase == "lose" and mine == theirs:
		return "NO WINNER"
	return "YOU WIN" if phase == "win" else ("BEATEN" if phase == "lose" else "")


static func end_card_score(mine: int, theirs: int) -> String:      # cpp:464-467
	return "YOU  %d : %d  THEM" % [mine, theirs]


## One drawn frame. Returns {"banner": bool, "end": bool} for the HUD's stand-down rules (the panel, the markers).
func frame(snap: Dictionary, phase: String, vw: float, vh: float, paused: bool = false) -> Dictionary:
	shown = {}
	if not paused:
		tick += 1                                  # a paused world stands still (its banner and the end's wait too)
	var sk: Array = snap["Skaters"]
	var me: int = int(snap["HumanIndex"])
	var hu: Dictionary = sk[me]
	var my_team: int = int(hu["Team"])
	var score: Array = snap["Score"]
	var home: int = int(score[my_team])
	var away: int = int(score[1 - my_team])
	var end: bool = phase == "win" or phase == "lose"
	_count_stats(snap, end)
	if not end:
		end_seen = -1
	elif end_seen < 0:
		end_seen = tick
	var waiting: bool = end and tick - end_seen < END_WAIT_FRAMES
	# ---- the GOAL banner: the goal pause, or the end card's wait (the match-ending goal has no pause)
	if last_home < 0 or int(snap["Frame"]) < last_frame:
		last_home = home
		last_away = away
	var in_pause: bool = phase == "goal_pause" or (end and waiting)
	if not in_pause:
		banner_start = -1
		banner_alpha = 0.0
		last_home = home
		last_away = away
	elif banner_start < 0 and (home > last_home or away > last_away):
		banner_start = tick
		var scored_home: bool = not (away > last_away and home <= last_home)
		banner_team = my_team if scored_home else 1 - my_team
		banner_y = _banner_band(snap, banner_team, vw, vh)
	_since = tick - banner_start if banner_start >= 0 else -1
	banner_alpha = banner_alpha_at(_since, goal_pause_frames) if banner_start >= 0 else 0.0
	_paint_args = [phase, home, away, my_team, vw, vh, int(hu.get("PenaltyFrames", 0)), end and not waiting]
	last_frame = int(snap["Frame"])
	return {"banner": banner_alpha > 0.0, "end": end}


## Draws what frame() decided: the banner (z 40: over the marks), IN THE BOX, then the end card (last: over everything).
func paint() -> void:
	if _paint_args.is_empty():
		return
	var phase: String = _paint_args[0]
	var home: int = _paint_args[1]
	var away: int = _paint_args[2]
	var my_team: int = _paint_args[3]
	var vw: float = _paint_args[4]
	var vh: float = _paint_args[5]
	if banner_alpha > 0.0:
		var k: float = 1.25 - 0.25 * banner_alpha if _since < BANNER_IN else 0.96 + 0.04 * banner_alpha
		var rect := Rect2(Vector2(vw * 0.5 - BANNER_W * 0.5, vh * banner_y - BANNER_H * 0.5), Vector2(BANNER_W, BANNER_H))
		var team_lin: Color = hud.col(banner_team).srgb_to_linear()
		var tint: Color = Color(1, 1, 1).lerp(team_lin, 0.25).linear_to_srgb()     # FMath::Lerp in linear colour (HUDGoalBanner.cpp:50)
		tint.a = banner_alpha
		if art_banner != null:
			lay.image(art_banner, rect, tint, k)
		else:
			var c: Color = hud.col(banner_team)
			c.a = 0.94 * banner_alpha
			lay.box(rect.position, rect.size, c, 14.0, R.PAPER, 4.0)
			lay.text(rect.get_center(), "GOAL", 84, R.PAPER, {"face": "black", "tracking": 120, "align": Vector2(0.5, 0.5), "outline": 2.0, "alpha": banner_alpha})
		shown["banner"] = "GOAL %s" % ("home" if banner_team == my_team else "away")
	# IN THE BOX n (the regular cartridge has penalties off: it never shows there)
	var box_t: String = R.box_plate_text(int(_paint_args[6])) if phase == "play" else ""
	if box_t != "":
		var pl := Vector2(300, 44)
		var tl := Vector2(vw * 0.5 - pl.x * 0.5, 122)
		var fill := R.ML_PANEL
		fill.a = 0.86
		lay.box(tl, pl, fill, 4.0, R.ML_EDGE, 1.0)
		lay.text(tl + pl * 0.5, box_t, R.LINE_PT, R.ML_TEXT, {"face": "bold_condensed", "tracking": R.TRACK_LABEL, "align": Vector2(0.5, 0.5), "shadow": Vector2(0, 1), "shadow_color": Color(0, 0, 0, 0.45)})
		shown["box"] = box_t
	if bool(_paint_args[7]):
		_end_card(phase, home, away, my_team, vw, vh)


## The scorer: the scoring side's skater nearest the puck; his figure from 0 to 2 m projected (HUDGoalBanner.cpp:206-233).
func _banner_band(snap: Dictionary, team: int, vw: float, vh: float) -> float:
	var pk: Vector2 = (snap["Puck"] as Dictionary)["Pos"]
	var best: float = INF
	var scorer: Dictionary = {}
	for s: Dictionary in snap["Skaters"]:
		if int(s["Team"]) == team and (s["Pos"] as Vector2).distance_squared_to(pk) < best:
			best = (s["Pos"] as Vector2).distance_squared_to(pk)
			scorer = s
	if scorer.is_empty():
		return 0.30
	var p: Vector2 = scorer["Pos"]
	var head: Vector3 = lay.project(Vector3(p.x, 2.0, p.y))
	var foot: Vector3 = lay.project(Vector3(p.x, 0.0, p.y))
	if head.z <= 0.0 or foot.z <= 0.0 or head.x < -50.0 or head.x > vw + 50.0:
		return banner_centre_y(-1.0, -1.0)
	var top: float = minf(head.y, foot.y) / vh
	var bot: float = maxf(head.y, foot.y) / vh
	if head.x < vw * 0.5 - BANNER_W * 0.5 - 40.0 or head.x > vw * 0.5 + BANNER_W * 0.5 + 40.0:
		return banner_centre_y(-1.0, -1.0)
	return banner_centre_y(top, bot)


func _reset_stats(hu: Dictionary) -> void:
	st = {"shots": 0, "goals": 0, "passes": 0, "arrived": 0, "hits": 0, "carry": 0}
	seen = {"passes": int(hu.get("Passes", 0)), "shots": int(hu.get("Shots", 0)), "goals": int(hu.get("Goals", 0))}
	pass_pending = -1
	final_counted = false


## UpdateEndStats (HUDEndStats.cpp:24-65): counted frame by frame from the sim's fields and events, frozen after the first end frame.
func _count_stats(snap: Dictionary, end: bool) -> void:
	var f: int = int(snap["Frame"])
	var sk: Array = snap["Skaters"]
	var me: int = int(snap["HumanIndex"])
	var hu: Dictionary = sk[me]
	if f < last_frame or last_frame < 0:
		_reset_stats(hu)
		return
	if not end:
		final_counted = false
	if f == last_frame or (end and final_counted):
		return
	if end:
		final_counted = true
	for k: String in ["shots", "goals"]:
		var now: int = int(hu.get(k.capitalize(), 0))
		if now > int(seen[k]):
			st[k] += now - int(seen[k])
		seen[k] = now
	var toucher: int = int((snap["Puck"] as Dictionary)["LastTouch"])
	if pass_pending >= 0 and toucher != me and toucher >= 0 and toucher < sk.size():
		if int((sk[toucher] as Dictionary)["Team"]) == int(hu["Team"]):
			st["arrived"] += 1
		pass_pending = -1
	if pass_pending >= 0 and f - pass_pending > PASS_ARRIVE:
		pass_pending = -1
	var passes: int = int(hu.get("Passes", 0))
	if passes > int(seen["passes"]):
		st["passes"] += passes - int(seen["passes"])
		pass_pending = f
	seen["passes"] = passes
	for e: Dictionary in snap["Events"]:
		if int(e["Who"]) == me and String(e["Name"]) == "check":
			st["hits"] += 1
	if int(snap["Carrier"]) == me:
		st["carry"] += 1


func stats_rows() -> Array:                                          # EndStatsRows (HUDOneLook.cpp:123-133)
	var sec: int = int(st["carry"]) / 60
	return [["SHOTS", str(st["shots"])], ["GOALS", str(st["goals"])], ["PASSES THAT ARRIVED", "%d OF %d" % [st["arrived"], st["passes"]]],
		["HITS LANDED", str(st["hits"])], ["WITH THE PUCK", "%d:%02d" % [sec / 60, sec % 60]]]


func _end_card(phase: String, home: int, away: int, my_team: int, vw: float, vh: float) -> void:
	var word: String = end_card_word(phase, home, away)
	var score_t: String = end_card_score(home, away)
	var word_c: Color = (R.ML_AWAY if my_team == 1 else R.ML_HOME) if phase == "win" else R.ML_TEXT   # EndCardWordColour (cpp:2038-2042)
	var shadow := {"shadow": Vector2(0, 1), "shadow_color": Color(0, 0, 0, 0.6)}
	var w_sz: Vector2 = lay.measure(word, END_WORD_PT, "black", 120)
	var s_sz: Vector2 = lay.measure(score_t, 32, "black", 60)
	var rows: Array = stats_rows()
	var row_h: float = lay.measure("A", R.LINE_PT, "bold_condensed", 60).y + 10.0
	var table_h: float = rows.size() * row_h + (rows.size() - 1) * 1.0
	var hints: Array = [["R / VIEW", "REMATCH"], ["ESC / START", "MENU"]]        # EndCardHints over EndCardKeys (cpp:469-497)
	var cap_h: float = lay.measure("R", 14, "black", 40).y + 6.0
	var body_h: float = w_sz.y + s_sz.y + 16.0 + table_h + 24.0 + 1.0 + 12.0 + cap_h
	var panel_h: float = 4.0 + 24.0 + body_h + 24.0
	var tl := Vector2(vw * 0.5 - END_CARD_W * 0.5, vh * 0.4 - panel_h * 0.5)
	# MakePanel: the team rule (4) over device B's T_UI_Panel, a box brush at half its pixels, margins 0.2 / 0.35 (MenuWidget.cpp:229-240, 316-332)
	lay.box(tl, Vector2(END_CARD_W * 0.5, 4), R.ML_HOME)
	lay.box(tl + Vector2(END_CARD_W * 0.5, 0), Vector2(END_CARD_W * 0.5, 4), R.ML_AWAY)
	var prect := Rect2(tl + Vector2(0, 4), Vector2(END_CARD_W, panel_h - 4))
	if art_panel != null:
		lay.nine(art_panel, prect, Vector4(0.2, 0.35, 0.2, 0.35), 2.0)
	else:
		var fill := R.ML_PANEL
		fill.a = 0.9
		lay.box(prect.position, prect.size, fill, 4.0, R.ML_EDGE, 1.0)
	var cx: float = vw * 0.5
	var y: float = prect.position.y + 24.0
	lay.text(Vector2(cx, y), word, END_WORD_PT, word_c, {"face": "black", "tracking": 120, "align": Vector2(0.5, 0)})
	y += w_sz.y
	lay.text(Vector2(cx, y), score_t, 32, R.ML_TEXT, {"face": "black", "tracking": 60, "align": Vector2(0.5, 0)})
	y += s_sz.y + 16.0
	var tx0: float = cx - 240.0
	for i: int in rows.size():
		if i > 0:
			lay.box(Vector2(tx0, y), Vector2(480, 1), R.ML_EDGE)
			y += 1.0
		lay.text(Vector2(tx0, y + row_h * 0.5), rows[i][0], R.LINE_PT, R.ML_TEXT_DIM, {"face": "bold_condensed", "tracking": 60, "align": Vector2(0, 0.5)})
		lay.text(Vector2(tx0 + 480.0, y + row_h * 0.5), rows[i][1], R.LINE_PT, R.ML_TEXT, {"face": "black", "tracking": 60, "align": Vector2(1, 0.5)})
		y += row_h
	y += 24.0
	lay.box(Vector2(prect.position.x + 32.0, y), Vector2((END_CARD_W - 64.0) * 0.5, 1), R.ML_HOME)
	lay.box(Vector2(cx, y), Vector2((END_CARD_W - 64.0) * 0.5, 1), R.ML_AWAY)
	y += 1.0 + 12.0
	# the key caps (FJamMenuLook::FillHints, MenuWidget.cpp:334-351): a cap white@0.14 padding 8 / 3, the key Black 14 tracked 40, the action Bold 14 tracked 60 dim
	var widths: Array = []
	var total: float = 0.0
	for j: int in hints.size():
		var kw: float = lay.measure(hints[j][0], 14, "black", 40).x + 16.0
		var aw: float = lay.measure(hints[j][1], 14, "bold_condensed", 60).x
		widths.append([kw, aw])
		total += kw + 8.0 + aw + (32.0 if j < hints.size() - 1 else 0.0)
	var x: float = cx - total * 0.5
	for j: int in hints.size():
		lay.box(Vector2(x, y), Vector2(widths[j][0], cap_h), Color(1, 1, 1, 0.14), 4.0)
		lay.text(Vector2(x + widths[j][0] * 0.5, y + cap_h * 0.5), hints[j][0], 14, R.ML_TEXT, {"face": "black", "tracking": 40, "align": Vector2(0.5, 0.5)})
		x += widths[j][0] + 8.0
		lay.text(Vector2(x, y + cap_h * 0.5), hints[j][1], 14, R.ML_TEXT_DIM, {"face": "bold_condensed", "tracking": 60, "align": Vector2(0, 0.5)})
		x += widths[j][1] + 32.0
	shown["end_card"] = "%s | %s | %s" % [word, score_t, " / ".join(PackedStringArray(rows.map(func(r: Array) -> String: return "%s %s" % [r[0], r[1]])))]
