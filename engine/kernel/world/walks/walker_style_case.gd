extends SceneTree
## Lane walker round 2 (night of 19 Nov 2026), hunt2 B12: a rejected FIRST style load (a missing --style file) must leave
## the default palette reachable, and a rejected reload after the default keeps it. Prints `STYLECASE first_reject ok|fail ...`.
## Run: godot --headless --path engine --script res://kernel/world/walks/walker_style_case.gd


func _initialize() -> void:
	var missing: String = "res://style/absent-walker-style-case.json"
	var errors: PackedStringArray = TLStyle.load_style(missing)
	var first: int = TLStyle.palette().size()
	var defaults: PackedStringArray = TLStyle.load_style(TLStyle.DEFAULT_PATH)
	var expected: int = TLStyle.palette().size()
	var again: PackedStringArray = TLStyle.load_style(missing)
	var warm: int = TLStyle.palette().size()
	var ok: bool = not errors.is_empty() and defaults.is_empty() and not again.is_empty() and expected > 0 and first == expected and warm == expected
	print("STYLECASE first_reject %s palette keys after a rejected first load %d, default %d, rejected reload after the default %d" % ["ok" if ok else "fail", first, expected, warm])
	quit(0 if ok else 1)
