extends Node
## Bot (K5): reads the HUD's texts: the panel has three lines; the bottom note grows from one line to four by frame 160.

var ctx
var state: Dictionary = {}
var lines_at_10: int = 0


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	if frame == 10:
		lines_at_10 = str(state["note"]).count("\n") + 1


func _bot_done() -> bool:
	return int(state.get("ticks", 0)) >= 180


func _bot_result() -> Dictionary:
	var panel_lines: int = str(state["panel"]).count("\n") + 1
	var note_lines: int = str(state["note"]).count("\n") + 1
	return {"ok": panel_lines == 3 and lines_at_10 == 1 and note_lines == 4,
		"summary": "panel %d lines; bottom note %d line at frame 10, %d lines at the end" % [panel_lines, lines_at_10, note_lines],
		"panel_lines": panel_lines, "note_lines": note_lines}
