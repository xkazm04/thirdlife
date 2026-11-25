extends SceneTree
# Rink core, round 6 (K3): the playtester's advice on the human's seat (set_advisor / advise), not applied.
#   A: the playtester SEATED (set_human_mode("playtester:<kind>[:sprint]")) with an advisor of the same spec: on every frame the advice
#      asked before step() equals the input the seat then sent (last_human_input after the step), field for field
#   B: a second core with the human on set_human_input ("input"): each frame it asks advise() and sends exactly that, to the end of
#      the match. Reported, not a criterion: B cannot be A's match bit for bit, because a Vector2 in a Dictionary is single precision
#      (the advice's Move and Stick are rounded to float on the way out, as any hand's are); the line says where B's state hash parts
#   C: advise() asked twice on one frame answers the same (it thinks once a frame)
#   godot --headless --path engine --script res://cores/rink/tools/rink_advice.gd [-- --seed=1 --spec=playtester:regular:sprint --frames=N]
# Prints ADVICE lines and PASS / FAIL.

const REG := "res://cores/rink/native/content/Cartridges/hockey.regular.cartridge.json"

func make(mode: String, spec: String, seed: int) -> Object:
	var c: Object = ClassDB.instantiate("RinkCore")
	c.call("load_cartridge", FileAccess.get_file_as_string(REG))
	c.call("set_difficulty", "pro")
	c.call("set_human_mode", mode)
	if not c.call("set_advisor", spec): return null
	c.call("reset", seed)
	return c

func _init() -> void:
	var seed := 1
	var spec := "playtester:regular:sprint"
	var frames := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): seed = int(a.substr(7))
		if a.begins_with("--spec="): spec = a.substr(7)
		if a.begins_with("--frames="): frames = int(a.substr(9))
	if not ClassDB.class_exists("RinkCore"):
		print("FAIL  rink advice: RinkCore is not registered"); quit(2); return
	var a: Object = make(spec, spec, seed)
	var b: Object = make("input", spec, seed)
	if a == null or b == null:
		print("FAIL  rink advice: set_advisor refused '%s'" % spec); quit(1); return
	var bad: PackedStringArray = []
	var n := 0
	var pressed := 0
	var b_done := false
	var b_parted := -1
	while frames <= 0 or n < frames:
		if a.call("is_over"): break
		var adv_a: Dictionary = a.call("advise")
		var again: Dictionary = a.call("advise")
		var adv_b: Dictionary = {} if b_done else b.call("advise")
		if adv_a.is_empty(): bad.append("f=%d no advice on a running match" % n); break
		if str(again) != str(adv_a) and bad.size() < 4: bad.append("f=%d asked twice: %s then %s" % [n, adv_a, again])
		if not b_done:
			if adv_b.is_empty(): b_done = true
			else:
				b.call("set_human_input", adv_b)
				if not b.call("step"): b_done = true
		var ra: bool = a.call("step")
		if not ra: break
		var sent: Dictionary = a.call("last_human_input")
		if str(sent) != str(adv_a) and bad.size() < 4: bad.append("f=%d the seat sent %s, the advice was %s" % [n, sent, adv_a])
		if b_parted < 0 and (b_done or str(a.call("state_hash_hex")) != str(b.call("state_hash_hex"))): b_parted = n + 1
		for k in ["bShootHeld", "bPassHeld", "bCheck", "bPoke", "bLift", "bDeke", "bSpin", "bSprint", "bBrake", "bAbility"]:
			if bool(adv_a.get(k, false)): pressed += 1
		n += 1
		if bad.size() >= 4: break
	print("ADVICE seed=%d spec=%s frames=%d presses=%d score=%s hash %s | B (driven by its own advice through the Dictionary): score %s, its state hash parts from A's at frame %d (-1 = never)" % [
		seed, spec, n, pressed, str(a.call("get_score")), a.call("state_hash_hex"), str(b.call("get_score")), b_parted])
	if n < 600: bad.append("only %d frames played" % n)
	if pressed == 0: bad.append("the advice never pressed a button")
	if bad.is_empty():
		print("PASS  rink advice: %d of %d frames of a whole match: the advice = what the seated playtester sent, asked twice = once (hash %s)" % [n, n, a.call("state_hash_hex")])
		quit(0)
	else:
		print("FAIL  rink advice: " + "; ".join(bad))
		quit(1)
