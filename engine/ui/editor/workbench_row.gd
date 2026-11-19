extends RefCounted
## E1: the list's first row, "New game in the workbench…", made with the panel's own row parts so it looks like the
## rows under it. Kept out of panel.gd (its size is ratcheted); it tells the host through the panel's
## `action_started` signal with what = "workbench" (host.gd opens the workbench).


static func make(panel: Control) -> Button:
	var col: Dictionary = panel.get("_col")
	var b: Button = panel.call("_row_button", "WorkbenchRow", false)
	var h: HBoxContainer = panel.call("_fill_row", b)
	h.add_child(panel.call("_label", "+", col["accent"], 13, 10))
	h.add_child(panel.call("_label", "New game in the workbench…", col["text"]))
	h.add_child(panel.call("_label", "questions, size, place", col["dim"], 11, 140, HORIZONTAL_ALIGNMENT_RIGHT))
	b.pressed.connect(func() -> void: panel.emit_signal("action_started", "workbench", ""))
	return b
