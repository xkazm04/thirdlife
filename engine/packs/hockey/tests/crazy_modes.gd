extends Node
## Play two full matches through the start panel, with both sides on autopilot.
## The result requires natural pickup takes in Arsenal and bot ability use in both modes.
const MODES := ["arsenal","shotgun"]
var ctx
var rows := []
var start := 0
var need_menu := true
var selecting := false
var on_ice := {}

## The bot drives only declared inputs and reads the public match snapshot.
func _bot_setup(c) -> void:
	ctx = c

## Open the panel and skate through its choices, then leave the match to the bots.
func _bot_tick(frame: int) -> void:
	if need_menu:
		ctx.input.tap(&"menu")
		need_menu = false
		selecting = true
		return
	if not selecting and frame % 10 != 0:
		return
	var s: Dictionary = ctx.pack_state()
	var mode: String = MODES[rows.size()]
	if selecting:
		if s.has("menu"):
			if s.menu.mode == mode:
				ctx.input.tap(&"shoot")
			elif frame % 2 == 0:
				ctx.input.tap(&"left")
			return
		selecting = false
		start = frame
		if not s.autopilot:
			ctx.input.tap(&"autopilot")
		ctx.input.tap(&"level_none")
		return
	if mode == "arsenal" and frame-start >= 600:
		var alive: int = s.crazy.pickups.size()
		on_ice[alive] = int(on_ice.get(alive,0)) + 1
	if s.state != "over" and frame-start < 18200:
		return
	var c: Dictionary = s.get("crazy",{})
	var row := {"mode":s.mode,"frames":frame-start,"reason":s.get("reason",""),"score":s.scores,
		"used":c.get("used",{}),"taken":c.get("taken",{})}
	if mode == "arsenal":
		row["packages_after_10s"] = on_ice.duplicate()
	row.ok = s.mode == mode and s.autopilot and s.state == "over" and frame-start > 120 and row.reason in ["time","score"] and not row.used.is_empty() and (mode != "arsenal" or not row.taken.is_empty())
	rows.append(row)
	need_menu = rows.size() < MODES.size()

## Both matches must reach a verdict.
func _bot_done() -> bool:
	return rows.size() == MODES.size()

## Keep scores, duration and per-kind counts alongside the verdict.
func _bot_result() -> Dictionary:
	return {"ok":_bot_done() and rows[0].ok and rows[1].ok,"summary":str(rows),"matches":rows}
