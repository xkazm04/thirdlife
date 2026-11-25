extends SceneTree
# Rink core v1.4 (lane H2, 25 Nov): the effect system's read-outs in snapshot(): Pickups, EffectEvents, Boosts (SNAPSHOT.md).
#   A: thirdjam's Arsenal cartridge (pickups every 120 frames in a hidden boost lane), its human played by thirdjam's playerbot:
#      every frame, a pickup Id new in `Pickups` has its `pickup_spawn` in `EffectEvents` on that frame at its Pos and Kind, an Id
#      gone has its `pickup_take` at its Pos; Ids are unique; `Boosts` has one entry per skater; some pickups are taken and some
#      boosts are seen (a game where nobody ever takes one does not prove the take)
#   B: the same match on a second core that is never asked for a snapshot: its state hash equals A's on every frame (the
#      read-outs step nothing)
#   C: the regular cartridge (no pickups, no effects): `Pickups` and `EffectEvents` empty on every frame, `Boosts` all ""
#   godot --headless --path engine --script res://cores/rink/tools/rink_pickups.gd [-- --seed=1 --frames=3600]
# Prints PICKUPS lines and PASS / FAIL.

const ARSENAL := "res://cores/rink/native/content/Cartridges/modes/hockey.mode.arsenal.cartridge.json"
const REG := "res://cores/rink/native/content/Cartridges/hockey.regular.cartridge.json"


func make(path: String, seed: int) -> Object:
	var c: Object = ClassDB.instantiate("RinkCore")
	var err: String = c.call("load_cartridge", FileAccess.get_file_as_string(path))
	if err != "":
		print("FAIL  rink pickups: %s does not load: %s" % [path, err])
		return null
	c.call("set_difficulty", "pro")
	c.call("set_human_mode", "playerbot")
	c.call("reset", seed)
	return c


func _init() -> void:
	var seed := 1
	var frames := 3600
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): seed = int(a.substr(7))
		if a.begins_with("--frames="): frames = int(a.substr(9))
	if not ClassDB.class_exists("RinkCore"):
		print("FAIL  rink pickups: RinkCore is not registered"); quit(2); return
	var a: Object = make(ARSENAL, seed)
	var b: Object = make(ARSENAL, seed)
	var c: Object = make(REG, seed)
	if a == null or b == null or c == null:
		quit(1); return
	var bad: PackedStringArray = []
	var on: Dictionary = {}            # Id -> {Kind, Pos}
	var ever: Dictionary = {}          # every Id seen
	var spawned := 0
	var taken := 0
	var boost_frames := 0
	var effect_starts := 0
	var kinds: Dictionary = {}
	var hash_equal := 0
	var n := 0
	while n < frames:
		var ga: bool = a.call("step")
		var gb: bool = b.call("step")
		c.call("step")
		n += 1
		if int(a.call("state_hash")) == int(b.call("state_hash")):
			hash_equal += 1
		elif bad.size() < 8:
			bad.append("frame %d: the hash parts from the core never asked for a snapshot" % n)
		var s: Dictionary = a.call("snapshot")
		for key in ["Pickups", "EffectEvents", "Boosts"]:
			if not s.has(key):
				bad.append("frame %d: no %s in the snapshot" % [n, key]); break
		var now: Dictionary = {}
		for p: Dictionary in s.get("Pickups", []):
			var id := int(p["Id"])
			if now.has(id) and bad.size() < 8: bad.append("frame %d: Id %d twice" % [n, id])
			now[id] = p
		var ev_spawn: Array = []
		var ev_take: Array = []
		for e: Dictionary in s.get("EffectEvents", []):
			match String(e["Name"]):
				"pickup_spawn": ev_spawn.append(e)
				"pickup_take": ev_take.append(e)
				"effect_start": effect_starts += 1
		for id: int in now:
			if on.has(id): continue
			if ever.has(id) and bad.size() < 8: bad.append("frame %d: Id %d came back" % [n, id])
			var p: Dictionary = now[id]
			var found := false
			for e: Dictionary in ev_spawn:
				if String(e["Kind"]) == String(p["Kind"]) and (e["Where"] as Vector2).distance_to(p["Pos"]) < 1e-3: found = true
			if not found and bad.size() < 8: bad.append("frame %d: pickup %d (%s) on the ice with no pickup_spawn there" % [n, id, p["Kind"]])
			spawned += 1
			ever[id] = true
			kinds[String(p["Kind"])] = int(kinds.get(String(p["Kind"]), 0)) + 1
		for id: int in on:
			if now.has(id): continue
			var p: Dictionary = on[id]
			var found := false
			for e: Dictionary in ev_take:
				if (e["Where"] as Vector2).distance_to(p["Pos"]) < 1e-3 and int(e["Who"]) >= 0: found = true
			if not found and bad.size() < 8: bad.append("frame %d: pickup %d left the ice with no pickup_take there" % [n, id])
			taken += 1
		if ev_spawn.size() != now.keys().filter(func(i): return not on.has(i)).size() and bad.size() < 8:
			bad.append("frame %d: %d pickup_spawn events, %d new pickups" % [n, ev_spawn.size(), now.keys().filter(func(i): return not on.has(i)).size()])
		on = now
		var bo: Array = s.get("Boosts", [])
		if bo.size() != (s["Skaters"] as Array).size() and bad.size() < 8:
			bad.append("frame %d: Boosts has %d entries for %d skaters" % [n, bo.size(), (s["Skaters"] as Array).size()])
		for k in bo:
			if String(k) != "":
				boost_frames += 1; break
		var sc: Dictionary = c.call("snapshot")
		if (not (sc.get("Pickups", [0]) as Array).is_empty() or not (sc.get("EffectEvents", [0]) as Array).is_empty()) and bad.size() < 8:
			bad.append("frame %d: the regular cartridge reports pickups or effect events" % n)
		for k in sc.get("Boosts", []):
			if String(k) != "" and bad.size() < 8: bad.append("frame %d: a boost on the regular cartridge" % n)
		if not ga or not gb:
			break
	if spawned == 0: bad.append("no pickup was put on the ice in %d frames" % n)
	if taken == 0: bad.append("no pickup was taken in %d frames" % n)
	if boost_frames == 0: bad.append("no boost seen on any skater in %d frames" % n)
	print("PICKUPS arsenal seed %d: %d frames, put down %d (%s), taken %d, standing %d, effect_start %d, frames with a boost %d, hash equal %d of %d, final %s" % [
		seed, n, spawned, JSON.stringify(kinds), taken, on.size(), effect_starts, boost_frames, hash_equal, n, a.call("state_hash_hex")])
	if bad.is_empty():
		print("PASS  rink pickups: every pickup's spawn and take is in EffectEvents on its frame; the read-outs move no hash (%d of %d frames)" % [hash_equal, n])
		quit(0)
	else:
		for l in bad: print("  " + l)
		print("FAIL  rink pickups: %s" % bad[0])
		quit(1)
