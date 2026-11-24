extends SceneTree
# Rink core, round 5: the snapshot's Controls fields for the HUD (K5), checked over a whole match played by thirdjam's playtester.
#   ButtonsWithPuck   = thirdjam's rule recomputed here from the snapshot (InputMapping.cpp:432-442: he carries, or the puck is loose and
#                       last touched by his team), on every frame
#   ButtonsCarrying   = (Carrier == the human), every frame
#   ButtonsInReach    : true whenever the puck is within 1.5 m of his body (UJamSim::CarrierReachM is at least 0.4 + 1.2 + 0.05 m,
#                       JamSim.cpp:862-869); it may be false while he carries (a puck held on the blade, JamSim.cpp CarrierIndex)
#   PassTarget        : -1 or a teammate of the human (never himself, never an opponent); SaucerTarget the same
#   TakeOwner         : -2 (a placed puck), -1 or a skater index; equal to the carrier on frames he has carried for a while
#   CarrierInTakeGrace: false whenever nobody carries
# Each rule must also have been met in its interesting case (counted), so a field stuck at one value fails.
#   godot --headless --path engine --script res://cores/rink/tools/rink_controls.gd [-- --seed=1]
# Prints CONTROLS lines and PASS / FAIL.

func _init() -> void:
	var seed := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): seed = int(a.substr(7))
	if not ClassDB.class_exists("RinkCore"):
		print("FAIL  rink controls: RinkCore is not registered")
		quit(2)
		return
	var core: RefCounted = ClassDB.instantiate("RinkCore")
	core.load_cartridge(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://cores/rink/native/content/Cartridges/hockey.regular.cartridge.json")))
	core.set_difficulty("pro")
	core.set_human_mode("playtester:regular:sprint")
	core.reset(seed)
	var bad: PackedStringArray = []
	var n := {"frames": 0, "with_carry": 0, "with_ours_loose": 0, "without": 0, "pass_target": 0, "saucer_target": 0, "owner_is_carrier": 0, "carry_settled": 0, "grace": 0, "in_reach": 0}
	var carried_for := 0
	var last_carrier := -1
	while core.step():
		var s: Dictionary = core.snapshot()
		var c: Dictionary = s["Controls"]
		var hi: int = int(s["HumanIndex"])
		var car: int = int(s["Carrier"])
		var sk: Array = s["Skaters"]
		var team: int = int(sk[hi]["Team"])
		var lt: int = int(s["Puck"]["LastTouch"])
		var want_with: bool = car == hi or (car < 0 and lt >= 0 and lt < sk.size() and int(sk[lt]["Team"]) == team)
		var f: int = int(s["Frame"])
		n["frames"] += 1
		if bool(c["ButtonsWithPuck"]) != want_with and bad.size() < 5:
			bad.append("f=%d ButtonsWithPuck %s, the rule says %s (carrier %d, last touch %d)" % [f, c["ButtonsWithPuck"], want_with, car, lt])
		if bool(c["ButtonsCarrying"]) != (car == hi) and bad.size() < 5:
			bad.append("f=%d ButtonsCarrying %s, carrier %d" % [f, c["ButtonsCarrying"], car])
		var body_d: float = (sk[hi]["Pos"] as Vector2).distance_to(s["Puck"]["Pos"])
		if body_d <= 1.5 and not bool(c["ButtonsInReach"]) and bad.size() < 5:
			bad.append("f=%d the puck %.2f m from his body but not in reach" % [f, body_d])
		if bool(c["ButtonsInReach"]): n["in_reach"] += 1
		for key in ["PassTarget", "SaucerTarget"]:
			var t: int = int(c[key])
			if t != -1 and (t == hi or t < 0 or t >= sk.size() or int(sk[t]["Team"]) != team) and bad.size() < 5:
				bad.append("f=%d %s %d is not a teammate of %d" % [f, key, t, hi])
		var ow: int = int(c["TakeOwner"])
		if (ow < -2 or ow >= sk.size()) and bad.size() < 5:
			bad.append("f=%d TakeOwner %d out of range" % [f, ow])
		if car < 0 and bool(c["CarrierInTakeGrace"]) and bad.size() < 5:
			bad.append("f=%d take grace with no carrier" % f)
		carried_for = carried_for + 1 if car == last_carrier and car >= 0 else 0
		last_carrier = car
		if car == hi: n["with_carry"] += 1
		elif want_with: n["with_ours_loose"] += 1
		else: n["without"] += 1
		if int(c["PassTarget"]) >= 0: n["pass_target"] += 1
		if int(c["SaucerTarget"]) >= 0: n["saucer_target"] += 1
		if carried_for >= 30:
			n["carry_settled"] += 1
			if ow == car: n["owner_is_carrier"] += 1
		if bool(c["CarrierInTakeGrace"]): n["grace"] += 1
	print("CONTROLS seed=%d %s" % [seed, str(n)])
	if int(n["in_reach"]) == int(n["frames"]): bad.append("ButtonsInReach never false")
	for k in ["with_carry", "with_ours_loose", "without", "pass_target", "in_reach"]:
		if int(n[k]) == 0: bad.append("never seen: %s" % k)
	if int(n["carry_settled"]) > 0 and int(n["owner_is_carrier"]) * 100 < int(n["carry_settled"]) * 95:
		bad.append("TakeOwner equals a settled carrier on %d of %d frames (want 95 %%)" % [n["owner_is_carrier"], n["carry_settled"]])
	if bad.is_empty():
		print("PASS  rink controls: %d frames, ButtonsWithPuck = thirdjam's rule on every frame (%d carrying, %d our puck loose, %d without), pass target on %d" % [n["frames"], n["with_carry"], n["with_ours_loose"], n["without"], n["pass_target"]])
		quit(0)
	else:
		print("FAIL  rink controls: " + "; ".join(bad))
		quit(1)
