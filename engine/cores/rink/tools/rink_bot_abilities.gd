extends SceneTree
# Rink core, patch 0005 (lane S4-core, 27 Nov spike, arm A): the bots' abilities and the dive (CARTRIDGE.md section 1).
#   1. off: RinkCoreThirdlife with every 0005 switch at 0 plays thirdjam's Shotgun mode as RinkCore does: the same hash every frame
#   2. on:  the switches on (both teams' bots hold the shotgun, they dive): bots use it (ability events by bots), bots dive and
#           stop shots (dive / dive_block events), the human's seat is thirdjam's playtester; the same run twice hashes the same
#   3. a value outside a switch's range and an unknown key are refused
#   godot --headless --path engine --script res://cores/rink/tools/rink_bot_abilities.gd [-- --seed=1 --frames=3600]
# Prints BOTAB lines and PASS / FAIL (exit 2 = the variant is not built).

const SHOTGUN := "res://cores/rink/native/content/Cartridges/modes/hockey.mode.shotgun.cartridge.json"
const OFF := "{\"schema\": \"tl.rink.rules/1\", \"rules\": {\"bot_ability_share\": 0, \"dive_share\": 0, \"dive_shot_share\": 0}}"
const ON := "{\"schema\": \"tl.rink.rules/1\", \"rules\": {\"bot_ability_share\": 0.8, \"bot_ability_skill\": 0.6, \"bot_ability_team\": 0, \"dive_share\": 0.8, \"dive_shot_share\": 0.3}}"


func play(cls: String, rules: String, seed: int, frames: int) -> Dictionary:
	var core: Object = ClassDB.instantiate(cls)
	var err: String = str(core.call("load_cartridge", FileAccess.get_file_as_string(SHOTGUN)))
	if err != "":
		return {"err": "load_cartridge: " + err}
	if rules != "":
		err = str(core.call("load_rules", rules))
		if err != "":
			return {"err": "load_rules: " + err}
	core.call("set_difficulty", "pro")
	core.call("set_human_mode", "playtester:regular")
	if not core.call("reset", seed):
		return {"err": "reset failed"}
	var hashes: PackedStringArray = []
	var n: Dictionary = {"bot_uses": 0, "human_uses": 0, "dives": 0, "blocks": 0, "blocks_shotgun": 0, "bot_shotgun_shots": 0}
	while hashes.size() < frames and core.call("step"):
		hashes.append(str(core.call("state_hash_hex")))
		var snap: Dictionary = core.call("snapshot")
		var hi: int = int(snap["HumanIndex"])
		var pk: Dictionary = snap["Puck"]
		for e: Dictionary in snap["Events"]:
			var nm: String = str(e["Name"])
			if nm == "ability" and float(e["Strength"]) > 0.5:
				n["human_uses" if int(e["Who"]) == hi else "bot_uses"] += 1
			elif nm == "dive":
				n["dives"] += 1
			elif nm == "dive_block":
				n["blocks"] += 1
				if str(e["Kind"]) == "shotgun":
					n["blocks_shotgun"] += 1
			elif nm == "shot" and int(e["Who"]) != hi and int(pk.get("ShotgunFrames", 0)) > 0 and int(pk.get("ShotgunBy", -1)) == int(e["Who"]):
				n["bot_shotgun_shots"] += 1
	return {"hashes": hashes, "n": n, "applied": str(core.call("rules_applied"))}


func _init() -> void:
	var seed := 1
	var frames := 3600
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): seed = int(a.substr(7))
		if a.begins_with("--frames="): frames = int(a.substr(9))
	if not ClassDB.class_exists("RinkCoreThirdlife"):
		print("NOT RUN  rink bot abilities: RinkCoreThirdlife is not registered (bash engine/tools/rink.sh build thirdlife)")
		quit(2)
		return
	var fails: PackedStringArray = []
	# 1. off = thirdjam
	var plain: Dictionary = play("RinkCore", "", seed, frames)
	var off: Dictionary = play("RinkCoreThirdlife", OFF, seed, frames)
	if plain.has("err") or off.has("err"):
		fails.append("off: %s %s" % [plain.get("err", ""), off.get("err", "")])
	else:
		var a: PackedStringArray = plain["hashes"]
		var b: PackedStringArray = off["hashes"]
		var first: int = -1
		for i in mini(a.size(), b.size()):
			if a[i] != b[i]:
				first = i
				break
		if a.size() != b.size() or first >= 0 or a.size() < mini(frames, 600):   # a match may end before `frames` (the same frame in both)
			fails.append("off: %d vs %d frames, first difference at %d" % [a.size(), b.size(), first])
		print("BOTAB off: %d of %d frames hash as RinkCore (last %s); plain uses %s" % [b.size(), a.size(), b[b.size() - 1] if b.size() > 0 else "-", JSON.stringify(off["n"])])
	# 2. on, twice
	var on1: Dictionary = play("RinkCoreThirdlife", ON, seed, frames)
	var on2: Dictionary = play("RinkCoreThirdlife", ON, seed, frames)
	if on1.has("err") or on2.has("err"):
		fails.append("on: %s %s" % [on1.get("err", ""), on2.get("err", "")])
	else:
		var h1: PackedStringArray = on1["hashes"]
		var h2: PackedStringArray = on2["hashes"]
		var n1: Dictionary = on1["n"]
		print("BOTAB on: %s; %d frames, last hash %s / %s; applied %s" % [JSON.stringify(n1), h1.size(), h1[h1.size() - 1], h2[h2.size() - 1], on1["applied"]])
		if h1 != h2:
			fails.append("on: two runs of the same seed hash differently")
		if h1.size() < mini(frames, 600):
			fails.append("on: the match stopped at %d of %d frames" % [h1.size(), frames])
		if int(n1["bot_uses"]) == 0:
			fails.append("on: no bot used the ability")
		if int(n1["dives"]) == 0:
			fails.append("on: no bot dived")
		if h1.size() > 0 and off.has("hashes") and (off["hashes"] as PackedStringArray).size() == h1.size() and (off["hashes"] as PackedStringArray)[h1.size() - 1] == h1[h1.size() - 1]:
			fails.append("on: the switches changed nothing")
	# 3. refused
	var core: Object = ClassDB.instantiate("RinkCoreThirdlife")
	core.call("load_cartridge", FileAccess.get_file_as_string(SHOTGUN))
	var e1: String = str(core.call("load_rules", "{\"schema\": \"tl.rink.rules/1\", \"rules\": {\"bot_ability_share\": 2}}"))
	var e2: String = str(core.call("load_rules", "{\"schema\": \"tl.rink.rules/1\", \"rules\": {\"bot_ability_often\": 1}}"))
	if e1 == "" or e2 == "":
		fails.append("refusal: out of range '%s', unknown '%s'" % [e1, e2])
	print("BOTAB refused: %s | %s" % [e1, e2])
	if fails.is_empty():
		print("PASS  rink bot abilities: off = RinkCore every frame, on: bots use it and dive, the same hash twice, bad rules refused")
		quit(0)
	else:
		print("FAIL  rink bot abilities: " + "; ".join(fails))
		quit(1)
