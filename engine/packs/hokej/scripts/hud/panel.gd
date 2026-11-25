extends RefCounted
## thirdjam's controls panel (lane A222; HUDControlsPanel.cpp, HEAD 8dc713c6): bottom left on the safe margin, all match,
## while play runs. The front end's panel (FJamMenuLook::MakePanel): the two team colours along its top edge (3 units),
## the panel fill at 0.78 with the 4-unit corner and the hairline edge; a head (a dot in his team's colour, WITH THE PUCK /
## WITHOUT THE PUCK), the possession half (fading in over 6 frames when it swaps), a hairline, the always half. A row: a
## light keycap (84 x 22 at least, the key in Black 14 tracked 40, ink) and the verb (Bold 16 tracked 60). A lit row
## (its button down) takes the menu's focus: the away orange cap and white type. The teaching pulse (HUDTeach.cpp, `teach`
## 0 = the pass, 1 = the check; cpp:318-331) lights its row: the take-yellow keycap, ink type, the word in yellow.

const R := preload("rules.gd")

var swap: Dictionary = {}            # FControlsPanelSwap
var swap_frame: int = -1000
var shown_rows: Array = []
var shown_with: int = -1
var visible: bool = false
var box := Rect2()


func hide() -> void:
	visible = false
	shown_rows = []


## Paints the panel; returns its rows as "KEY=WORD" (a lit row ends with *, a taught row with !).
func paint(lay, vh: float, f: int, with_puck: bool, press: bool, held: Dictionary, saucer: bool, braced: bool, ability: bool,
		team: Color, dim: bool, legs_spent: bool, teach: int = -1) -> String:
	visible = true
	if f < swap_frame:
		swap_frame = -1000                                             # a restart
	if R.panel_swap_step(swap, with_puck, press, f):
		swap_frame = f
	var show_with: bool = int(swap["shown"]) == 1
	shown_with = int(swap["shown"])
	var since: int = f - swap_frame
	var fade: float = clampf(float(since + 1) / float(R.PANEL_FADE_FRAMES), 0.0, 1.0)
	var rows: Array = R.panel_rows(show_with, ability, held, saucer, braced)
	shown_rows = rows
	var plate_a: float = R.BADGE_DOWN_OPACITY if dim else 1.0

	# ---- measure (the SizeBox: min 264, max 300 wide; rows of the 8 slots that are filled)
	var cap_font := "black"
	var word_font := "bold_condensed"
	var head_t: String = "WITH THE PUCK" if show_with else "WITHOUT THE PUCK"
	var head_sz: Vector2 = lay.measure(head_t, 12, word_font, R.TRACK_LABEL)
	var head_h: float = maxf(10.0, head_sz.y)
	var content_w: float = 2.0 + 10.0 + 8.0 + head_sz.x
	var row_h: Array = []
	var cap_w: Array = []
	for r: Dictionary in rows:
		var ks: Vector2 = lay.measure(r["key"], 14, cap_font, 40)
		var ws: Vector2 = lay.measure(r["word"], 16, word_font, R.TRACK_LABEL)
		var cw: float = maxf(R.PANEL_KEYCAP_MIN_W, ks.x + 16.0)
		cap_w.append(cw)
		row_h.append(maxf(R.PANEL_KEYCAP_H, ws.y))
		content_w = maxf(content_w, cw + 10.0 + ws.x)
	var w: float = clampf(content_w + 2.0 * R.PANEL_PAD, R.PANEL_MIN_W, R.PANEL_MAX_W)
	var body_h: float = head_h + 6.0
	var n_poss: int = 0
	for i: int in rows.size():
		if rows[i]["poss"]:
			n_poss += 1
		body_h += float(row_h[i]) + R.PANEL_ROW_GAP
	body_h += 2.0 + 1.0 + 6.0                                          # the hairline and its padding
	var plate_h: float = (R.PANEL_PAD - 4.0) + body_h + R.PANEL_PAD
	var total_h: float = 3.0 + plate_h
	var top_left := Vector2(R.EDGE_PX, vh - R.EDGE_PX - total_h)
	box = Rect2(top_left, Vector2(w, total_h))

	# ---- paint
	lay.box(top_left, Vector2(w * 0.5, 3.0), _a(R.ML_HOME, plate_a))
	lay.box(top_left + Vector2(w * 0.5, 0), Vector2(w * 0.5, 3.0), _a(R.ML_AWAY, plate_a))
	var fill := R.ML_PANEL
	fill.a = 0.78 * plate_a
	lay.box(top_left + Vector2(0, 3), Vector2(w, plate_h), fill, 4.0, _a(R.ML_EDGE, plate_a), 1.0)
	var x0: float = top_left.x + R.PANEL_PAD
	var y: float = top_left.y + 3.0 + (R.PANEL_PAD - 4.0)
	lay.box(Vector2(x0 + 2.0, y + head_h * 0.5 - 5.0), Vector2(10, 10), _a(team, plate_a), 5.0)
	lay.text(Vector2(x0 + 20.0, y + head_h * 0.5), head_t, 12, _a(R.ML_TEXT if show_with else R.ML_TEXT_DIM, plate_a),
		{"face": word_font, "tracking": R.TRACK_LABEL, "align": Vector2(0, 0.5)})
	y += head_h + 6.0
	var out := PackedStringArray()
	for i: int in rows.size():
		var r: Dictionary = rows[i]
		if i == n_poss:
			lay.box(Vector2(x0, y + 2.0), Vector2(w - 2.0 * R.PANEL_PAD, 1.0), _a(R.ML_EDGE, plate_a))
			y += 2.0 + 1.0 + 6.0
		var a: float = plate_a * (fade if r["poss"] else 1.0)
		var taught: bool = (teach == 0 and r["verb"] == "Pass") or (teach == 1 and r["verb"] == "Check")    # cpp:318
		var look: int = 2 if r["lit"] else (1 if taught else (3 if r["verb"] == "Sprint" and legs_spent else 0))   # cpp:319
		var cap_fill: Color = R.ML_AWAY if look == 2 else (R.YELLOW if look == 1 else Color(R.ML_TEXT.r, R.ML_TEXT.g, R.ML_TEXT.b, 0.92))
		var cap_ink: Color = R.ML_ON_FOCUS if look == 2 else R.ML_INK
		var word_c: Color = R.ML_ON_FOCUS if look == 2 else (R.YELLOW if look == 1 else (R.ML_TEXT_DIM if look == 3 else R.ML_TEXT))
		var rh: float = row_h[i]
		var cw: float = cap_w[i]
		var cap_at := Vector2(x0, y + rh * 0.5 - R.PANEL_KEYCAP_H * 0.5)
		lay.box(cap_at, Vector2(cw, R.PANEL_KEYCAP_H), _a(cap_fill, a), 4.0)
		lay.text(cap_at + Vector2(cw * 0.5, R.PANEL_KEYCAP_H * 0.5), r["key"], 14, _a(cap_ink, a), {"face": cap_font, "tracking": 40, "align": Vector2(0.5, 0.5)})
		lay.text(Vector2(x0 + cw + 10.0, y + rh * 0.5), r["word"], 16, _a(word_c, a), {"face": word_font, "tracking": R.TRACK_LABEL, "align": Vector2(0, 0.5)})
		y += rh + R.PANEL_ROW_GAP
		out.append("%s=%s%s" % [r["key"], r["word"], "*" if look == 2 else ("!" if look == 1 else "")])
	return ",".join(out)


static func _a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)
