extends SceneTree
# Rink core: a scripted hand through the person's input path (human mode "raw": thirdjam's game-mode rules in the core's glue,
# GAMEMODE.md). The same per-frame raw device stream is fed twice; both runs must give the same FJamInput every frame and the
# same state hash. Also a gym check: set_bot_mode("off") keeps the nine others in the penalty box (no body) while the human skates.
#   godot --headless --path engine --script res://cores/rink/tools/rink_rawhand.gd [-- --frames=3600 --seed=5]
# Prints RAWHAND lines and PASS / FAIL.

const Hand := preload("res://cores/rink/tools/rink_hand.gd")


func run(seed: int, frames: int) -> Dictionary:
	var core: RefCounted = ClassDB.instantiate("RinkCore")
	var path := ProjectSettings.globalize_path("res://cores/rink/native/content/Cartridges/hockey.regular.cartridge.json")
	var err: String = core.load_cartridge(FileAccess.get_file_as_string(path))
	if err != "":
		return {"error": err}
	core.set_difficulty("pro")
	core.set_human_mode("raw")
	core.reset(seed)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var counts := {"bShootHeld": 0, "bPassHeld": 0, "bCheck": 0, "bLift": 0, "bCrossHold": 0, "bSprint": 0, "bPoke": 0, "bSpin": 0, "bAbility": 0}
	var signals := 0
	var last_intent := -1
	var s: Dictionary = core.snapshot()
	for f in frames:
		core.set_raw_input(Hand.raw_at(f, s))
		if not core.step():
			break
		var hi: Dictionary = core.last_human_input()
		ctx.update(var_to_str(hi).to_utf8_buffer())
		for k in counts.keys():
			if bool(hi[k]):
				counts[k] += 1
		s = core.snapshot()
		var ik: int = int(s["Controls"]["IntentIssuedFrame"]) if int(s["Controls"]["IntentKind"]) != 0 else -1
		if ik != last_intent and ik >= 0:
			signals += 1
			last_intent = ik
	return {"frames": int(core.get_frame()), "hash": core.state_hash_hex(), "inputs": ctx.finish().hex_encode().substr(0, 16), "counts": counts, "signals": signals,
		"score": core.get_score()}


func gym(seed: int, frames: int) -> Dictionary:
	var core: RefCounted = ClassDB.instantiate("RinkCore")
	var path := ProjectSettings.globalize_path("res://cores/rink/native/content/Cartridges/hockey.regular.cartridge.json")
	core.load_cartridge(FileAccess.get_file_as_string(path))
	core.set_human_mode("input")
	core.set_bot_mode("off")     # the gym: the other nine in the penalty box (no body, no contact)
	core.reset(seed)
	core.step()
	var start: Array = []
	var centre: Array = []
	for k in core.snapshot()["Skaters"]:
		start.append(k["Pos"])
		centre.append(bool(k["bCentre"]))
	for f in frames:
		core.set_human_input({"Move": Vector2(1, 0) if f < 240 else Vector2(0, 1), "bSprint": f % 200 < 100})
		core.step()
	var s: Dictionary = core.snapshot()
	var hi := int(s["HumanIndex"])
	var moved_human: float = (s["Skaters"][hi]["Pos"] - start[hi]).length()
	var moved_bots := 0.0
	var moved_centre := 0.0
	for i in s["Skaters"].size():
		if i == hi:
			continue
		var d: float = (s["Skaters"][i]["Pos"] - start[i]).length()
		if centre[i]:
			moved_centre = maxf(moved_centre, d)
		else:
			moved_bots = maxf(moved_bots, d)
	return {"human_m": moved_human, "bots_max_m": moved_bots, "centre_m": moved_centre}


func _init() -> void:
	var frames := 3600
	var seed := 5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="): frames = int(a.substr(9))
		elif a.begins_with("--seed="): seed = int(a.substr(7))
	if not ClassDB.class_exists("RinkCore"):
		print("FAIL  rink rawhand: RinkCore is not registered")
		quit(2)
		return
	var a := run(seed, frames)
	var b := run(seed, frames)
	if a.has("error"):
		print("FAIL  rink rawhand: ", a["error"])
		quit(1)
		return
	print("RAWHAND run1 frames=%d hash=%s inputs=%s score=%s signals=%d counts=%s" % [a["frames"], a["hash"], a["inputs"], str(a["score"]), a["signals"], str(a["counts"])])
	print("RAWHAND run2 frames=%d hash=%s inputs=%s" % [b["frames"], b["hash"], b["inputs"]])
	var g := gym(seed, 600)
	print("RAWHAND gym (bot mode off) human moved %.2f m; the other nine at most %.3f m" % [g["human_m"], maxf(g["bots_max_m"], g["centre_m"])])
	var c: Dictionary = a["counts"]
	var why := ""
	if a["hash"] != b["hash"] or a["inputs"] != b["inputs"]:
		why = "the two runs differ"
	elif a["frames"] < 600:
		why = "the run stopped at frame %d" % a["frames"]
	elif int(c["bShootHeld"]) + int(c["bLift"]) == 0 or int(c["bPassHeld"]) + int(c["bCheck"]) == 0 or int(c["bSprint"]) == 0 or int(c["bPoke"]) == 0:
		why = "a verb never reached the sim: %s" % str(c)
	elif g["human_m"] < 5.0 or maxf(g["bots_max_m"], g["centre_m"]) > 0.0:
		why = "gym: human %.2f m, bots %.3f m" % [g["human_m"], g["bots_max_m"]]
	if why == "":
		print("PASS  rink rawhand: same input stream (%s) and hash (%s) twice; verbs %s; gym ok" % [a["inputs"], a["hash"], str(c)])
		quit(0)
	else:
		print("FAIL  rink rawhand: ", why)
		quit(1)
