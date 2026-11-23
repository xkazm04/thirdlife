extends RefCounted
## thirdjam's pause card (UJamDirectorsCallWidget, DirectorsCallWidget.cpp:170-232, 373-382, 506-530, 772-792; HEAD 8dc713c6)
## on the kernel's frame pause (1.24: ctx.own_pause, TLHud.on_paused, ctx.input.menu_keys, ctx.resume, ctx.leave_game).
## The scrim (black 0.62) and a panel 808 wide (padding 32 / 24): PAUSED (Black 40 tracked 120), "PERIOD n   -   PRO (YOUR
## LEVEL)" (Bold 14 tracked 60, dim), the items at 22 (RESUME, CHANGE A RULE, RESTART, CONTROLS, QUIT TO MENU), the two
## mouse buttons by possession (Bold 18 tracked 60, line height 1.25), EVERY KEY, AND TO REBIND IT: CONTROLS, the team rule,
## the key hints ESC / START RESUME, ENTER / A SELECT, R / VIEW RESTART. Up / Down move, Enter selects, Esc resumes; QUIT
## TO MENU asks LEAVE THE MATCH? first (NO, KEEP PLAYING has the focus).

const R := preload("rules.gd")
const W := 808.0                 # PauseCardWidth (DirectorsCallWidget.h:64)
const PAD := Vector2(32, 24)
const ITEM_PT := 22              # PauseItemSize
# CHANGE A RULE (the Director's Call) and CONTROLS (the rebinding screen) are not ported: their rows stand disabled.
const ITEMS := [["RESUME", true], ["CHANGE A RULE", false], ["RESTART", true], ["CONTROLS", false], ["QUIT TO MENU", true]]
const WHY := "The score of this match is thrown away. The season keeps what you have won."   # DirectorsCallWidget.cpp:777
const LEAVE_ITEMS := [["NO, KEEP PLAYING", true], ["YES, LEAVE TO THE MENU", true]]

var kit
var screen_: String = "pause"    # pause | leave
var focus: int = 0


func _init(kit_) -> void:
	kit = kit_


func open() -> void:
	screen_ = "pause"
	focus = 0                    # Pause() focuses RESUME (DirectorsCallController.cpp:212-244)


## The keys of this drawn frame; returns what the card asks: "", "resume", "restart", "leave".
func keys(ks: PackedStringArray) -> String:
	var items: Array = ITEMS if screen_ == "pause" else LEAVE_ITEMS
	for k: String in ks:
		match k:
			"esc":
				if screen_ == "leave":
					screen_ = "pause"
					focus = 4
				else:
					return "resume"
			"up", "down":
				var step: int = -1 if k == "up" else 1
				for n: int in items.size():
					focus = (focus + step + items.size()) % items.size()
					if bool(items[focus][1]):
						break
			"enter":
				if screen_ == "leave":
					if focus == 1:
						return "leave"
					screen_ = "pause"
					focus = 4
				else:
					match focus:
						0: return "resume"
						2: return "restart"
						4:
							screen_ = "leave"
							focus = 0
	return ""


func paint(lay, vw: float, vh: float, period: int, level: String) -> String:
	lay.box(Vector2.ZERO, Vector2(vw, vh), Color(0, 0, 0, 0.62))          # FJamMenuLook::Scrim
	var inner: float = W - 2.0 * PAD.x
	var title: String = "PAUSED" if screen_ == "pause" else "LEAVE THE MATCH?"
	var t_sz: Vector2 = lay.measure(title, 40, "black", 120)
	var items: Array = ITEMS if screen_ == "pause" else LEAVE_ITEMS
	var item_h: float = 12.0 + lay.measure("A", ITEM_PT, "bold_condensed", R.TRACK_LABEL).y + 12.0
	var line_h: float = lay.measure("A", 14, "bold_condensed", R.TRACK_LABEL).y
	var stick_h: float = lay.measure("A", R.LINE_PT, "bold_condensed", R.TRACK_LABEL).y * 1.25
	var body_h: float = t_sz.y
	if screen_ == "pause":
		body_h += line_h + 16.0 + items.size() * item_h + (items.size() - 1) * 8.0 + 12.0 + stick_h * 2.0 + 4.0 + line_h
	else:
		var why_lines: int = kit.wrap(WHY, R.LINE_PT, "regular", inner).size()
		body_h += 12.0 + lay.measure("A", R.LINE_PT, "regular").y * why_lines + 16.0 + items.size() * item_h + (items.size() - 1) * 8.0
	body_h += 16.0 + 1.0 + 12.0 + line_h + 6.0
	var h: float = 4.0 + PAD.y + body_h + PAD.y
	var tl := Vector2(vw * 0.5 - W * 0.5, vh * 0.5 - h * 0.5)
	kit.panel(Rect2(tl, Vector2(W, h)))
	var x: float = tl.x + PAD.x
	var y: float = tl.y + 4.0 + PAD.y
	lay.text(Vector2(x, y), title, 40, R.ML_TEXT, {"face": "black", "tracking": 120})
	y += t_sz.y
	if screen_ == "pause":
		lay.text(Vector2(x, y), "PERIOD %d   -   %s (YOUR LEVEL)" % [period, level], 14, R.ML_TEXT_DIM, {"face": "bold_condensed", "tracking": R.TRACK_LABEL})
		y += line_h + 16.0
	else:
		y += 12.0
		for ln: String in kit.wrap(WHY, R.LINE_PT, "regular", inner):              # wrapped at the card's inner width
			lay.text(Vector2(x, y), ln, R.LINE_PT, R.ML_TEXT_DIM, {"face": "regular"})
			y += lay.measure("A", R.LINE_PT, "regular").y
		y += 16.0
	for i: int in items.size():
		var state: int = 2 if i == focus else (1 if bool(items[i][1]) else 0)
		y += kit.item(Vector2(x, y), inner, items[i][0], ITEM_PT, state) + 8.0
	y -= 8.0
	if screen_ == "pause":
		# PauseStickText (DirectorsCallWidget.cpp:153-156): the two mouse buttons by possession, from the bindings
		y += 12.0
		lay.text(Vector2(x, y), "WITH THE PUCK      LMB  SHOOT     RMB  PASS", R.LINE_PT, R.ML_TEXT, {"face": "bold_condensed", "tracking": R.TRACK_LABEL})
		y += stick_h
		lay.text(Vector2(x, y), "WITHOUT IT      LMB  CROSS-CHECK     RMB  CHECK", R.LINE_PT, R.ML_TEXT, {"face": "bold_condensed", "tracking": R.TRACK_LABEL})
		y += stick_h + 4.0
		lay.text(Vector2(x, y), "EVERY KEY, AND TO REBIND IT: CONTROLS", 14, R.ML_TEXT_DIM, {"face": "bold_condensed", "tracking": R.TRACK_LABEL})
		y += line_h
	y += 16.0
	kit.team_rule(Vector2(x, y), inner, 1.0)
	y += 1.0 + 12.0
	kit.hints(Vector2(x, y + (line_h + 6.0) * 0.5), [["ESC / START", "RESUME"], ["ENTER / A", "SELECT"], ["R / VIEW", "RESTART"]])
	return "%s focus=%s" % [title, items[focus][0]]
