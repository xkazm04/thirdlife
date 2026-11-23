extends RefCounted
## thirdjam's front end, the path a first-time player takes to the puck (UJamMenuWidget, MenuWidget.cpp:683-967, 1266-1452,
## 2138-2150, 2378-2433; MenuFlow.cpp:387-425; grid MenuWidget.h:66-105), drawn before the match's frame 0 while the kernel's
## frame holds the pack paused (1.24). Two screens:
##   LANDING  the backdrop (device B's T_UI_MenuBackdrop) under the scrim; HOKEJ (Black 176 tracked 120, shadow 0 / 6), the team
##            rule 480 x 6, HOCKEY WITH THE WHISTLE TAKEN OUT. (Bold 24 tracked 160), PRESS ENTER (Black 28 tracked 200,
##            breathing 0.55 to 1 every 1.6 s), OR A, OR A CLICK; footer ENTER / A START, CLICK START. Enter or a click: HOME.
##   HOME     the header (T_UI_HeaderBar 80 high: HOKEJ, the rule, HOME, LEVEL and its chip), the team rule 8 under it, the left
##            column 640 wide at x 96: PLAY NOW (Black 48) with "ONE MATCH, <LEVEL>.  ENTER / A, OR CLICK.", the level row
##            ROOKIE / PRO / ALL-STAR (the lit one on T_UI_Segment_Lit), the level's line; the right column 704 wide: ONE
##            MATCH and its words, YOUR STICK; footer ENTER / A PLAY, LEFT / RIGHT LEVEL, UP / DOWN MOVE, ESC / B TITLE.
##            Left / Right step the level, Enter plays, Esc goes back to the title.
## SEASON, MODES, PLAY WITH A FRIEND, CONTROLS, SETTINGS, CREDITS and QUIT are not ported (HUD.md lists them).

const R := preload("rules.gd")
const LEVELS := ["rookie", "pro", "all_star"]
const LABELS := ["ROOKIE", "PRO", "ALL-STAR"]
const MEANING := ["New to hockey games? Start here: rookies are a step slower.", "Played one before? Pros hit as a habit.",
	"The wall. All-stars hunt the puck. Beat pro first."]       # MenuFlow.cpp:415-425
const SIDE := 96.0               # SideMargin
const HEADER_H := 80.0
const RULE_H := 8.0
const FOOTER_H := 56.0

var kit
var up: bool = false
var screen_: String = "landing"
var level: int = 1
var t: int = 0


func _init(kit_, level_id: String) -> void:
	kit = kit_
	level = maxi(0, LEVELS.find(level_id))


## The keys of this drawn frame: "" or "play" (the match starts at the lit level) or "leave".
func keys(ks: PackedStringArray) -> String:
	for k: String in ks:
		if screen_ == "landing":
			if k == "enter" or k == "click":
				screen_ = "home"
			elif k == "esc":
				return "leave"               # DEVIATION: thirdjam's title has no way out; the exe's menu is behind it
		else:
			match k:
				"left": level = maxi(0, level - 1)
				"right": level = mini(LEVELS.size() - 1, level + 1)
				"enter": return "play"
				"esc": screen_ = "landing"
	return ""


func level_id() -> String:
	return LEVELS[level]


func level_label() -> String:
	return LABELS[level]


func paint(lay, vw: float, vh: float) -> String:
	t += 1
	lay.box(Vector2.ZERO, Vector2(vw, vh), R.ML_INK)
	var bd: Texture2D = kit.tex.get("MenuBackdrop")
	if bd != null:
		lay.image(bd, Rect2(Vector2.ZERO, Vector2(vw, vh)))
	lay.box(Vector2.ZERO, Vector2(vw, vh), Color(0, 0, 0, 0.62))
	if screen_ == "landing":
		_landing(lay, vw, vh)
	else:
		_home(lay, vw, vh)
	return screen_


func _footer(lay, vw: float, vh: float, pairs: Array) -> void:
	lay.box(Vector2(0, vh - FOOTER_H), Vector2(vw, FOOTER_H), Color(R.ML_INK, 0.94))
	kit.hints(Vector2(SIDE, vh - FOOTER_H * 0.5), pairs)


func _landing(lay, vw: float, vh: float) -> void:
	var cx: float = vw * 0.5
	var h1: Vector2 = lay.measure("HOKEJ", 176, "black", 120)
	var tag := "HOCKEY WITH THE WHISTLE TAKEN OUT."
	var h2: Vector2 = lay.measure(tag, 24, "bold_condensed", 160)
	var h3: Vector2 = lay.measure("PRESS ENTER", 28, "black", 200)
	var h4: Vector2 = lay.measure("A", 14, "bold_condensed", 160)
	var total: float = h1.y + 8.0 + 6.0 + 24.0 + h2.y + 112.0 + h3.y + h4.y
	var y: float = vh * 0.5 - total * 0.5
	lay.text(Vector2(cx, y), "HOKEJ", 176, R.ML_TEXT, {"face": "black", "tracking": 120, "align": Vector2(0.5, 0), "shadow": Vector2(0, 6), "shadow_color": Color(0, 0, 0, 0.55)})
	y += h1.y + 8.0
	kit.team_rule(Vector2(cx - 240.0, y), 480.0, 6.0)
	y += 6.0 + 24.0
	lay.text(Vector2(cx, y), tag, 24, R.ML_TEXT, {"face": "bold_condensed", "tracking": 160, "align": Vector2(0.5, 0)})
	y += h2.y + 112.0
	var pulse: float = 0.55 + 0.45 * (0.5 + 0.5 * cos(float(t) / 60.0 * TAU / 1.6))   # PromptPulseSeconds 1.6 (MenuWidget.cpp:2380-2384)
	lay.text(Vector2(cx, y), "PRESS ENTER", 28, R.ML_TEXT, {"face": "black", "tracking": 200, "align": Vector2(0.5, 0), "alpha": pulse})
	y += h3.y
	lay.text(Vector2(cx, y), "OR A, OR A CLICK", 14, R.ML_TEXT_DIM, {"face": "bold_condensed", "tracking": 160, "align": Vector2(0.5, 0)})
	_footer(lay, vw, vh, [["ENTER / A", "START"], ["CLICK", "START"]])


func _home(lay, vw: float, vh: float) -> void:
	# the header: device B's bar, HOKEJ, a rule, HOME; LEVEL and its chip at the right margin; the team rule under it
	var hb: Texture2D = kit.tex.get("HeaderBar")
	if hb != null:
		lay.image(hb, Rect2(Vector2.ZERO, Vector2(vw, HEADER_H)))
	else:
		lay.box(Vector2.ZERO, Vector2(vw, HEADER_H), Color(R.ML_INK, 0.94))
	var my: float = HEADER_H * 0.5
	var logo: Rect2 = lay.text(Vector2(SIDE, my), "HOKEJ", 32, R.ML_TEXT, {"face": "black", "tracking": 160, "align": Vector2(0, 0.5)})
	lay.box(Vector2(logo.end.x + 24.0, my - 20.0), Vector2(2, 40), Color(1, 1, 1, 0.25))
	lay.text(Vector2(logo.end.x + 50.0, my), "HOME", 24, R.ML_TEXT_DIM, {"face": "bold_condensed", "tracking": R.TRACK_LABEL, "align": Vector2(0, 0.5)})
	var chip_sz: Vector2 = lay.measure(level_label(), 16, "black", R.TRACK_LABEL) + Vector2(32, 8)
	var chip := Rect2(Vector2(vw - SIDE - chip_sz.x, my - chip_sz.y * 0.5), chip_sz)
	lay.box(chip.position, chip.size, R.ML_HOME, 2.0)
	lay.text(chip.get_center(), level_label(), 16, Color.WHITE, {"face": "black", "tracking": R.TRACK_LABEL, "align": Vector2(0.5, 0.5)})
	lay.text(Vector2(chip.position.x - 16.0, my), "LEVEL", 14, R.ML_TEXT_DIM, {"face": "bold_condensed", "tracking": R.TRACK_LABEL, "align": Vector2(1, 0.5)})
	kit.team_rule(Vector2(0, HEADER_H - RULE_H * 0.5), vw, RULE_H)
	# the left column: PLAY NOW (it has the focus when HOME opens), the level row, the level's line
	var y: float = HEADER_H + RULE_H + 40.0
	var sub: String = "ONE MATCH, %s.  ENTER / A, OR CLICK." % level_label()
	y += kit.item(Vector2(SIDE, y), 640.0, "PLAY NOW", 48, 2, sub, 14, Vector2(12, 14)) + 8.0
	var seg_w: float = (640.0 - 2.0 * 8.0) / 3.0
	var seg_h: float = 10.0 + lay.measure("A", 16, "black", 100).y + 10.0
	for i: int in 3:
		var r := Rect2(Vector2(SIDE + i * (seg_w + 8.0), y), Vector2(seg_w, seg_h))
		kit.plate("Segment_Lit" if i == level else "Segment_Unlit", r, R.ML_HOME if i == level else Color(R.ML_PANEL, 0.9), i != level)
		lay.text(r.get_center(), LABELS[i], 16, Color.WHITE if i == level else R.ML_TEXT_DIM, {"face": "black", "tracking": 100, "align": Vector2(0.5, 0.5)})
	y += seg_h + 8.0
	lay.text(Vector2(SIDE, y), MEANING[level], 15, R.ML_TEXT_DIM, {"face": "regular"})
	# the right column: the feature panel (ONE MATCH) and YOUR STICK
	var rx: float = vw - SIDE - 704.0
	var body := ["Five-a-side hockey. WASD skates, the mouse is your stick.", "Hockey with the whistle taken out.", "",
		"The level is lit under PLAY NOW: left and right change it, and it is kept for the next time."]
	var lh: float = lay.measure("A", R.LINE_PT, "regular").y * 1.15
	var title_h: float = lay.measure("ONE MATCH", 32, "black", R.TRACK_LABEL).y
	var ph: float = 4.0 + 32.0 + title_h + 16.0 + lh * (body.size() + 1) + 32.0
	var py: float = HEADER_H + RULE_H + 40.0
	kit.panel(Rect2(Vector2(rx, py), Vector2(704, ph)))
	var ty: float = py + 4.0 + 32.0
	lay.text(Vector2(rx + 32.0, ty), "ONE MATCH", 32, R.ML_TEXT, {"face": "black", "tracking": R.TRACK_LABEL})
	ty += title_h + 16.0
	for ln: String in body:
		if ln == "The level is lit under PLAY NOW: left and right change it, and it is kept for the next time.":
			lay.text(Vector2(rx + 32.0, ty), "The level is lit under PLAY NOW: left and right change it,", R.LINE_PT, R.ML_TEXT, {"face": "regular"})
			ty += lh
			lay.text(Vector2(rx + 32.0, ty), "and it is kept for the next time.", R.LINE_PT, R.ML_TEXT, {"face": "regular"})
		else:
			lay.text(Vector2(rx + 32.0, ty), ln, R.LINE_PT, R.ML_TEXT, {"face": "regular"})
		ty += lh
	var sy: float = py + ph + 16.0
	var sh: float = 32.0 + lh * 3.0 + 24.0
	var fill := R.ML_PANEL
	fill.a = 0.9
	kit.plate("Panel", Rect2(Vector2(rx, sy), Vector2(704, sh)), fill, true)
	lay.text(Vector2(rx + 32.0, sy + 28.0), "YOUR STICK", R.LINE_PT, R.ML_TEXT_DIM, {"face": "bold_condensed", "tracking": R.TRACK_LABEL})
	lay.text(Vector2(rx + 32.0, sy + 28.0 + lh), "WITH THE PUCK:  LMB  SHOOT     RMB  PASS", R.LINE_PT, R.ML_TEXT, {"face": "bold_condensed", "tracking": R.TRACK_LABEL})
	lay.text(Vector2(rx + 32.0, sy + 28.0 + lh * 2.0), "WITHOUT IT:  LMB  CROSS-CHECK     RMB  CHECK", R.LINE_PT, R.ML_TEXT, {"face": "bold_condensed", "tracking": R.TRACK_LABEL})
	_footer(lay, vw, vh, [["ENTER / A", "PLAY"], ["LEFT / RIGHT", "LEVEL"], ["UP / DOWN", "MOVE"], ["ESC / B", "TITLE"]])
