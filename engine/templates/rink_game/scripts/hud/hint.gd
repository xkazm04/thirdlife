extends RefCounted
## The pack's hint slot (lane H2b, 25 Nov): one line a game's own script asks the base to show, drawn where it never covers
## the commentator's caption. G1's Arsenal drew "F: BUBBLE  Green spots reload it" as its own bottom label, right over the
## caption for the first ten seconds of every match. A game says it so instead:
##     ctx.root.set_meta(&"rink_hint", "F: BUBBLE  Green spots reload it")    # every frame it should show; "" = none
## (screen.gd reads the meta each drawn frame and hands it to hud.gd as ui "pack_hint").
## The slot: left-aligned with the controls panel, just above the room the panel keeps (rules.gd PANEL_RESERVE_H: the panel's
## eight rows at most), a dark plate in the HUD's look. It stays put while the panel comes and goes. It is moved up past
## anything it would touch among the caption's two places at their widest (the bottom strip, and the row under the
## scoreboard it takes when the bottom one would cover the human) and the caption actually drawn this frame.

const R := preload("rules.gd")

var rect: Rect2 = Rect2()               # the plate drawn this frame (Rect2() = none)


## The caption's two places on a vw x vh screen at their widest (captions.gd paint: the plate 16 + wrap + 16 wide, one line).
static func caption_rows(lay, vw: float, vh: float) -> Array:
	var wrap: float = clampf(vw - 600.0, 560.0, 880.0)
	var h: float = 6.0 + lay.measure("Ag", R.LINE_PT, "regular").y + 6.0
	var w: float = 16.0 + wrap + 16.0
	return [Rect2(Vector2(vw * 0.5 - w * 0.5, vh - 24.0 - h), Vector2(w, h)), Rect2(Vector2(vw * 0.5 - w * 0.5, 112.0), Vector2(w, h))]


## Where a plate of `plate` goes: above the panel's room, moved up past every rect of `avoid` it would come within 6 units of.
static func place(vh: float, plate: Vector2, avoid: Array) -> Rect2:
	var r := Rect2(Vector2(R.EDGE_PX, vh - R.EDGE_PX - R.PANEL_RESERVE_H - 10.0 - plate.y), plate)
	for _pass: int in 4:
		var moved: bool = false
		for a: Rect2 in avoid:
			if a.size != Vector2.ZERO and r.grow(6.0).intersects(a):
				r.position.y = a.position.y - 6.0 - 1.0 - plate.y
				moved = true
		if not moved:
			break
	return r


## One drawn frame: `text` ("" = nothing), `caption`: the caption's plate drawn this frame (captions.gd last_rect).
func paint(lay, vw: float, vh: float, text: String, caption: Rect2, shown: Dictionary) -> void:
	rect = Rect2()
	if text == "":
		return
	var sz: Vector2 = lay.measure(text, R.LINE_PT, "bold_condensed", R.TRACK_LABEL)
	var plate := Vector2(16.0 + sz.x + 16.0, 6.0 + sz.y + 6.0)
	rect = place(vh, plate, caption_rows(lay, vw, vh) + [caption])
	var fill := R.ML_PANEL
	fill.a = 0.86
	lay.box(rect.position, rect.size, fill, 4.0, R.ML_EDGE, 1.0)
	lay.text(rect.position + Vector2(16, 6), text, R.LINE_PT, R.PAPER, {"face": "bold_condensed", "tracking": R.TRACK_LABEL, "shadow": Vector2(0, 1), "shadow_color": Color(0, 0, 0, 0.45)})
	shown["pack_hint"] = text
