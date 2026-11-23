extends SceneTree
# Rink core, item 4 of round 4: thirdjam's playtester as a hand that presses the REAL keys.
#   1. The playtester seated in the core (human mode "playtester:<kind>[:sprint]") plays seed S: its final hash must equal thirdjam's
#      own tournament playtester (-player=<kind> [-playersprint]) for that seed (passed in --want=<hash>).
#   2. Its per-frame decision (last_human_input) is turned into raw devices (keys, the move axis, the stick) by keys_for() and fed to a
#      second core in human mode "raw" (thirdjam's game-mode rules in the glue, the path a person's hands take). Both cores step in
#      lock: the first frame where the raw core's FJamInput or hash parts from the seat's is printed with its fields.
#   godot --headless --path engine --script res://cores/rink/tools/rink_keyshand.gd -- --kind=regular --sprint --seed=1 --want=<hash>
# Prints KEYSHAND lines; PASS / FAIL on the seat's hash only (the raw hand's parting is a measurement, reported, never a pass).

const BOOLS := ["bShoot", "bShootHeld", "bPass", "bPassHeld", "bCheck", "bBrake", "bPoke", "bLift", "bDeke", "bSprint", "bSpin", "bAbility", "bCrossHold"]


func make_core(mode: String, seed: int) -> RefCounted:
	var core: RefCounted = ClassDB.instantiate("RinkCore")
	core.load_cartridge(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://cores/rink/native/content/Cartridges/hockey.regular.cartridge.json")))
	core.set_difficulty("pro")
	core.set_human_mode(mode)
	core.reset(seed)
	return core


# The decision as a person's devices, with the camera fixed at yaw 0 (stick up = +x): Move = (Axis.y, Axis.x), the pad stick for the
# blade (Stick = (StickAxis.y, StickAxis.x)); the buttons by thirdjam's default bindings (InputMapping.cpp:98-120): LMB shoot with the
# puck and cross-check without, RMB pass with it and check without, Space poke, wheel deke, E spin, F ability, LShift sprint, LCtrl brake.
func keys_for(d: Dictionary, held: Dictionary) -> Dictionary:
	var down: PackedStringArray = []
	var pressed: PackedStringArray = []
	var want := func(key: String, on: bool) -> void:
		if on:
			down.append(key)
			if not held.get(key, false):
				pressed.append(key)
	want.call("LeftMouseButton", d["bShootHeld"] or d["bShoot"] or d["bLift"] or d["bCrossHold"])
	want.call("RightMouseButton", d["bPassHeld"] or d["bPass"] or d["bCheck"])
	want.call("LeftShift", d["bSprint"])
	want.call("LeftControl", d["bBrake"])
	if d["bPoke"]: pressed.append("SpaceBar")
	if d["bDeke"]: pressed.append("MouseScrollUp")
	if d["bSpin"]: pressed.append("E")
	if d["bAbility"]: pressed.append("F")
	for k in held.keys():
		held[k] = false
	for k in down:
		held[k] = true
	var m: Vector2 = d["Move"]
	var st: Vector2 = d["Stick"]
	return {"Down": down, "Pressed": pressed, "Axis": Vector2(m.y, m.x), "CameraYaw": 0.0, "StickAxis": Vector2(st.y, st.x), "CursorOnIce": false}


func _init() -> void:
	var kind := "regular"
	var sprint := false
	var seed := 1
	var want := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kind="): kind = a.substr(7)
		elif a == "--sprint": sprint = true
		elif a.begins_with("--seed="): seed = int(a.substr(7))
		elif a.begins_with("--want="): want = a.substr(7)
	var mode := "playtester:%s%s" % [kind, ":sprint" if sprint else ""]
	var seat := make_core(mode, seed)
	var raw := make_core("raw", seed)
	var held := {}
	var parted := -1
	var why := ""
	var frames := 0
	while frames < 36000:
		if not seat.step():
			break
		frames += 1
		var d: Dictionary = seat.last_human_input()
		if parted < 0:
			raw.set_raw_input(keys_for(d, held))
			raw.step()
			var g: Dictionary = raw.last_human_input()
			for k in d.keys():
				if d[k] != g[k]:
					why = "%s: seat %s, keys %s" % [k, str(d[k]), str(g[k])]
					break
			if why == "" and raw.state_hash_hex() != seat.state_hash_hex():
				why = "the hash (inputs equal as the snapshot shows them, single precision: the doubles differ)"
			if why != "":
				parted = int(seat.get_frame())
	var s: Dictionary = seat.snapshot()
	print("KEYSHAND seat %s seed=%d frames=%d score=%d:%d hash=%s want=%s" % [mode, seed, int(s["Frame"]), int(s["Score"][0]), int(s["Score"][1]), seat.state_hash_hex(), want])
	print("KEYSHAND keys: %s" % ("the raw hand equals the seat on every frame" if parted < 0 else "parts at frame %d: %s" % [parted, why]))
	if want != "" and seat.state_hash_hex() == want:
		print("PASS  rink keyshand: the seated playtester ends on thirdjam's own hash %s" % want)
		quit(0)
	else:
		print("FAIL  rink keyshand: seat hash %s, thirdjam's %s" % [seat.state_hash_hex(), want])
		quit(1)
