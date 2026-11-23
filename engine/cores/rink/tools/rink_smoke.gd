extends SceneTree
# Rink core smoke (engine/tools/selftest.d/800-rink-core.sh): thirdjam's regular 5 v 5 (hockey.regular, HEAD) played by bots only
# (human mode "brain": nobody human, JamBotMatch.h EJamPlayerMode::Brain) for 3,600 frames, twice with the same seed.
# PASS = the extension loaded, the match ran 3,600 frames, a snapshot has 10 skaters and the puck, and both runs end on the same hash.
#   godot --headless --path engine --script res://cores/rink/tools/rink_smoke.gd [-- --frames=3600 --seed=7 --difficulty=pro]

func _run(seed: int, frames: int, difficulty: String) -> Dictionary:
	var core: RefCounted = ClassDB.instantiate("RinkCore")
	var path := ProjectSettings.globalize_path("res://cores/rink/native/content/Cartridges/hockey.regular.cartridge.json")
	var err: String = core.load_cartridge(FileAccess.get_file_as_string(path))
	if err != "":
		return {"error": "cartridge: " + err}
	if not core.set_difficulty(difficulty):
		return {"error": "difficulty " + difficulty}
	core.set_human_mode("brain")
	core.reset(seed)
	var stepped := 0
	var goals := 0
	for f in frames:
		if not core.step():
			break
		stepped += 1
		for e in core.snapshot()["Events"]:
			if e["Name"] == "goal":
				goals += 1
	var s: Dictionary = core.snapshot()
	return {"frames": stepped, "frame": s["Frame"], "score": s["Score"], "goals": goals, "hash": core.state_hash_hex(),
		"skaters": s["Skaters"].size(), "has_puck": s.has("Puck"), "phase": s["Phase"]}

func _init() -> void:
	var frames := 3600
	var seed := 7
	var difficulty := "pro"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="): frames = int(a.substr(9))
		elif a.begins_with("--seed="): seed = int(a.substr(7))
		elif a.begins_with("--difficulty="): difficulty = a.substr(13)
	if not ClassDB.class_exists("RinkCore"):
		print("FAIL  rink smoke: RinkCore is not registered (build it: engine/tools/rink.sh build)")
		quit(2)
		return
	var t0 := Time.get_ticks_msec()
	var a := _run(seed, frames, difficulty)
	var ms := Time.get_ticks_msec() - t0
	var b := _run(seed, frames, difficulty)
	if a.has("error") or b.has("error"):
		print("FAIL  rink smoke: ", a.get("error", b.get("error", "")))
		quit(1)
		return
	print("RINKSMOKE tree=", ClassDB.class_call_static("RinkCore", "source_tree"), " seed=", seed, " difficulty=", difficulty,
		" frames=", a["frames"], " score=", a["score"][0], ":", a["score"][1], " goal_events=", a["goals"], " phase=", a["phase"],
		" hash=", a["hash"], " skaters=", a["skaters"], " ms=", ms)
	var ok: bool = a["frames"] == frames and a["skaters"] == 10 and a["has_puck"] and a["hash"] == b["hash"] and a["score"] == b["score"]
	if ok:
		print("PASS  rink smoke: %d of %d frames, 10 skaters, same hash twice (%s)" % [a["frames"], frames, a["hash"]])
		quit(0)
	else:
		print("FAIL  rink smoke: frames %d of %d, skaters %d, hash %s vs %s" % [a["frames"], frames, a["skaters"], a["hash"], b["hash"]])
		quit(1)
