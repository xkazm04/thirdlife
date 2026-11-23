extends SceneTree
# K3 round 5: K1's core glue (RinkCore human mode "raw") on a seeded stream of the five two-role keys in a real match
# (skating at the puck so possession changes), one line per frame:
#   in:  "frame down pressed with carrying inreach saucer_delay brace_delay"  (button_main.cpp's input: what thirdjam's
#        FJamButtonResolver gets; the context read from the snapshot BEFORE the step, as JamControls::ButtonContext reads
#        the sim, InputMapping.cpp:474-486, HasPuckForButtons 432-442, CarrierReachM = 1.65 m on the regular cut)
#   out: "frame shootHeld passHeld check lift crossHold" from the FJamInput the glue gave the human (last_human_input)
#   godot --headless --path engine --script <this file> -- --frames=N --seed=S --in=<file> --out=<file>
const KEYS: Array = ["LeftMouseButton", "MiddleMouseButton", "ThumbMouseButton", "RightMouseButton", "Q"]
func _init() -> void:
	var n := 6000; var seed := 7; var inp := ""; var outp := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="): n = int(a.substr(9))
		elif a.begins_with("--seed="): seed = int(a.substr(7))
		elif a.begins_with("--in="): inp = a.substr(5)
		elif a.begins_with("--out="): outp = a.substr(6)
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var core: RefCounted = ClassDB.instantiate("RinkCore")
	core.load_cartridge(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://packs/hokej/data/hockey.regular.cartridge.json")))
	core.set_difficulty("pro"); core.set_human_mode("raw"); core.reset(1)
	var down := 0
	var ins := PackedStringArray(); var outs := PackedStringArray()
	for f in range(1, n + 1):
		var s: Dictionary = core.snapshot()
		var me: int = int(s["HumanIndex"]); var sk: Array = s["Skaters"]; var carrier: int = int(s["Carrier"])
		var last: int = int(s["Puck"]["LastTouch"])
		var with: bool = carrier == me or (carrier < 0 and last >= 0 and last < sk.size() and int(sk[last]["Team"]) == int(sk[me]["Team"]))
		var reach: bool = (sk[me]["Pos"] as Vector2).distance_to(s["Puck"]["Pos"]) <= 1.65
		var pressed := 0
		for i in 5:
			var bit := 1 << i
			if down & bit:
				if rng.randf() < 0.06: down &= ~bit
			elif rng.randf() < 0.03:
				pressed |= bit
				if rng.randf() < 0.85: down |= bit
		var dn := PackedStringArray(); var pr := PackedStringArray()
		for i in 5:
			if down & (1 << i): dn.append(KEYS[i])
			if pressed & (1 << i): pr.append(KEYS[i])
		# skate at the puck in the camera-free frame (CameraYaw 0: W is +x), so the possession changes under the keys
		var to: Vector2 = (s["Puck"]["Pos"] as Vector2) - (sk[me]["Pos"] as Vector2)
		var ax := Vector2(clampf(to.y, -1, 1), clampf(to.x, -1, 1)).sign() if to.length() > 1.0 else Vector2.ZERO
		core.set_raw_input({"Down": dn, "Pressed": pr, "Axis": ax, "CameraYaw": 0.0})
		if not core.step():
			break
		var h: Dictionary = core.last_human_input()
		ins.append("%d %d %d %d %d %d 0 3" % [f, down, pressed, 1 if with else 0, 1 if carrier == me else 0, 1 if reach else 0])
		outs.append("%d %d %d %d %d %d" % [f, int(h["bShootHeld"]), int(h["bPassHeld"]), int(h["bCheck"]), int(h["bLift"]), int(h["bCrossHold"])])
	FileAccess.open(inp, FileAccess.WRITE).store_string("\n".join(ins) + "\n")
	FileAccess.open(outp, FileAccess.WRITE).store_string("\n".join(outs) + "\n")
	print("BUTTONS glue frames=%d" % ins.size())
	quit(0)
