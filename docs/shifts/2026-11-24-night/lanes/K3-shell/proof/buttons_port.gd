extends SceneTree
# K3 round 3: the pack's port of the button rules (packs/hokej/scripts/human_input.gd step_buttons) on the same stream the
# button oracle reads (button_main.cpp's format), one output line per frame in the oracle's format.
#   godot --headless --path engine --script <this file> -- --in=<stream.txt> --out=<port.txt>
const KEYS: Array = ["LeftMouseButton", "MiddleMouseButton", "ThumbMouseButton", "RightMouseButton", "Q"]
func _init() -> void:
	var inp := ""; var outp := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--in="): inp = a.substr(5)
		elif a.begins_with("--out="): outp = a.substr(6)
	var H = load("res://packs/hokej/scripts/human_input.gd")
	var h = H.new({"carrier_reach": 1.65, "saucer_half": 8, "pass_power_full": 30})
	var lines := PackedStringArray()
	for l in FileAccess.get_file_as_string(inp).split("\n", false):
		var f := l.split(" ")
		var down := int(f[1]); var pressed := int(f[2])
		for i in 5:
			if pressed & (1 << i): h._press(KEYS[i])
			if not (down & (1 << i)): h._release(KEYS[i])
		var o: Dictionary = h.step_buttons({"with": f[3] == "1", "carrying": f[4] == "1", "in_reach": f[5] == "1", "dead_across": true,
			"saucer_delay": int(f[6]), "brace_delay": int(f[7])})
		lines.append("%s %d %d %d %d %d" % [f[0], int(o["bShootHeld"]), int(o["bPassHeld"]), int(o["bCheck"]), int(o["bLift"]), int(o["bCrossHeld"])])
	var fa := FileAccess.open(outp, FileAccess.WRITE)
	fa.store_string("\n".join(lines) + "\n")
	quit(0)
