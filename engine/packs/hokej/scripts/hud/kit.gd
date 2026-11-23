extends RefCounted
## thirdjam's front-end makers (FJamMenuLook, MenuWidget.cpp:224-351), drawn on a TLHudLayer with device B's kit as
## exported to assets/hud/ (each a box brush at half its pixels, margins 0.2 / 0.35: KitOr, MenuWidget.cpp:229-240):
## the item (a kit button plate, the 8-unit focus bar, the label), the panel (the team rule over the kit panel), the team
## rule, the key hints (FillHints). Shared by the pause card and the menu.

const R := preload("rules.gd")
const UNIT := 8.0
const ITEM_PAD_X := 24.0
const FOCUS_BAR_W := 8.0
const MARGIN := Vector4(0.2, 0.35, 0.2, 0.35)

var lay
var tex: Dictionary = {}


func _init(layer) -> void:
	lay = layer
	if lay.has_method("image_of"):
		for n: String in ["Button_Normal", "Button_Focused", "Button_Disabled", "Segment_Lit", "Segment_Unlit", "Panel", "HeaderBar", "MenuBackdrop"]:
			tex[n] = lay.image_of("assets/hud/T_UI_%s.png" % n)


## A kit plate (KitOr), or its flat fallback (FillBrush) when the picture is absent.
func plate(name: String, r: Rect2, fallback: Color, edge: bool = false) -> void:
	var t: Texture2D = tex.get(name)
	if t != null:
		lay.nine(t, r, MARGIN, 2.0)
	else:
		lay.box(r.position, r.size, fallback, 4.0, R.ML_EDGE if edge else Color(0, 0, 0, 0), 1.0 if edge else 0.0)


func team_rule(at: Vector2, w: float, h: float) -> void:            # MakeTeamRule (MenuWidget.cpp:299-314)
	lay.box(at, Vector2(w * 0.5, h), R.ML_HOME)
	lay.box(at + Vector2(w * 0.5, 0), Vector2(w * 0.5, h), R.ML_AWAY)


## MakePanel (MenuWidget.cpp:316-332): the team rule (4) over the kit panel.
func panel(r: Rect2) -> void:
	team_rule(r.position, r.size.x, 4.0)
	var fill := R.ML_PANEL
	fill.a = 0.9
	plate("Panel", Rect2(r.position + Vector2(0, 4), r.size - Vector2(0, 4)), fill, true)


## An item (MakeItem + ItemStyle, MenuWidget.cpp:242-297): state 0 disabled, 1 rest, 2 focus. Returns its height.
func item(at: Vector2, w: float, label: String, pt: int, state: int, sub: String = "", sub_pt: int = 14, pad_y: Vector2 = Vector2(12, 12)) -> float:
	var l_sz: Vector2 = lay.measure(label, pt, "bold_condensed" if pt < 40 else "black", R.TRACK_LABEL)
	var s_sz: Vector2 = lay.measure(sub, sub_pt, "bold_condensed", R.TRACK_LABEL) if sub != "" else Vector2.ZERO
	var h: float = pad_y.x + l_sz.y + s_sz.y + pad_y.y
	var r := Rect2(at, Vector2(w, h))
	match state:
		0: plate("Button_Disabled", r, Color(R.ML_INK, 0.55))
		2: plate("Button_Focused", r, R.ML_AWAY)
		_: plate("Button_Normal", r, Color(R.ML_PANEL, 0.9), true)
	if state == 2:
		lay.box(at, Vector2(FOCUS_BAR_W, h), R.ML_ON_FOCUS)          # the focus bar, white on the focus
	var tc: Color = R.ML_ON_FOCUS if state == 2 else (Color("#4a505c") if state == 0 else R.ML_TEXT)
	lay.text(at + Vector2(FOCUS_BAR_W + ITEM_PAD_X, pad_y.x), label, pt, tc, {"face": "bold_condensed" if pt < 40 else "black", "tracking": R.TRACK_LABEL})
	if sub != "":
		lay.text(at + Vector2(FOCUS_BAR_W + ITEM_PAD_X, pad_y.x + l_sz.y), sub, sub_pt, tc if state == 2 else R.ML_TEXT_DIM, {"face": "bold_condensed", "tracking": R.TRACK_LABEL})
	return h


## FillHints (MenuWidget.cpp:334-351): key caps (white @ 0.14, padding 8 / 3, Black 14 tracked 40) and the action (Bold 14
## tracked 60, dim), 32 units between pairs. `at` is the row's left (align 0) or centre (align 0.5), its vertical middle.
func hints(at: Vector2, pairs: Array, align: float = 0.0) -> void:
	var total: float = 0.0
	var ws: Array = []
	for j: int in pairs.size():
		var kw: float = lay.measure(pairs[j][0], 14, "black", 40).x + 16.0
		var aw: float = lay.measure(pairs[j][1], 14, "bold_condensed", R.TRACK_LABEL).x
		ws.append([kw, aw])
		total += kw + UNIT + aw + (UNIT * 4.0 if j < pairs.size() - 1 else 0.0)
	var cap_h: float = lay.measure("A", 14, "black", 40).y + 6.0
	var x: float = at.x - total * align
	for j: int in pairs.size():
		lay.box(Vector2(x, at.y - cap_h * 0.5), Vector2(ws[j][0], cap_h), Color(1, 1, 1, 0.14), 4.0)
		lay.text(Vector2(x + ws[j][0] * 0.5, at.y), pairs[j][0], 14, R.ML_TEXT, {"face": "black", "tracking": 40, "align": Vector2(0.5, 0.5)})
		x += ws[j][0] + UNIT
		lay.text(Vector2(x, at.y), pairs[j][1], 14, R.ML_TEXT_DIM, {"face": "bold_condensed", "tracking": R.TRACK_LABEL, "align": Vector2(0, 0.5)})
		x += ws[j][1] + UNIT * 4.0


## Words wrapped at `width` units (a text block's SetWrapTextAt): the lines.
func wrap(text: String, pt: float, face: String, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for w: String in text.split(" "):
		var t: String = w if line == "" else line + " " + w
		if line != "" and lay.measure(t, pt, face).x > width:
			out.append(line)
			line = w
		else:
			line = t
	if line != "":
		out.append(line)
	return out
