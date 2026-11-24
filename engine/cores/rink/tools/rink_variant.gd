extends SceneTree
# Rink core, round 5: the thirdlife core (thirdjam + native/patches-thirdlife, lane K8) beside the plain one, selected by cartridge.
#   1. plain: RinkCore plays hockey.regular (pro, thirdjam's regular playtester, seed) -> a hash on every frame
#   2. off:   RinkCoreThirdlife plays it with a rules sidecar that turns every switch it names off -> the same hash on every frame
#             (the patches with their switches off are thirdjam)
#   3. on:    RinkCoreThirdlife with net_carry_wall on: plays to the end (reported; it may differ from 1)
#   4. the plain core refuses a rule (RinkCore.load_rules -> an error); the variant refuses an unknown rule and an unknown key
#   5. TLCores.open: a cartridge without a sidecar opens RinkCore, the same cartridge with a sidecar opens RinkCoreThirdlife
#   godot --headless --path engine --script res://cores/rink/tools/rink_variant.gd [-- --seed=1 --frames=N]
#   --plain-only: a tree without native/patches-thirdlife: the plain core refuses a rule and no RinkCoreThirdlife is registered
# Prints VARIANT lines and PASS / FAIL (exit 2 = the variant is not built).

class FakeCtx extends RefCounted:
	var pack_dir: String = ""

const REG := "res://cores/rink/native/content/Cartridges/hockey.regular.cartridge.json"

func play(cls: String, rules: String, seed: int, frames: int) -> Dictionary:
	var core: Object = ClassDB.instantiate(cls)
	var err: String = str(core.call("load_cartridge", FileAccess.get_file_as_string(REG)))
	if err != "": return {"err": "load_cartridge: " + err}
	if rules != "":
		err = str(core.call("load_rules", rules))
		if err != "": return {"err": "load_rules: " + err}
	core.call("set_difficulty", "pro")
	core.call("set_human_mode", "playtester:regular")
	if not core.call("reset", seed): return {"err": "reset failed"}
	var hashes: PackedStringArray = []
	while (frames <= 0 or hashes.size() < frames) and core.call("step"):
		hashes.append(str(core.call("state_hash_hex")))
	return {"hashes": hashes, "score": core.call("get_score"), "applied": str(core.call("rules_applied"))}

func _init() -> void:
	var seed := 1
	var frames := 0
	var plain_only := false
	for a in OS.get_cmdline_user_args():
		if a == "--plain-only": plain_only = true
		if a.begins_with("--seed="): seed = int(a.substr(7))
		if a.begins_with("--frames="): frames = int(a.substr(9))
	if not ClassDB.class_exists("RinkCore"):
		print("FAIL  rink variant: RinkCore is not registered"); quit(2); return
	if plain_only:
		var q: Object = ClassDB.instantiate("RinkCore")
		q.call("load_cartridge", FileAccess.get_file_as_string(REG))
		var e0: String = str(q.call("load_rules", '{"schema":"tl.rink.rules/1","rules":{"net_carry_wall":true}}'))
		if e0 == "" or ClassDB.class_exists("RinkCoreThirdlife"):
			print("FAIL  rink variant: plain-only tree: rule refused '%s', RinkCoreThirdlife registered %s" % [e0, ClassDB.class_exists("RinkCoreThirdlife")]); quit(1); return
		print("PASS  rink variant: no patches in this tree: the plain core refuses a rule (%s), no variant registered" % e0); quit(0); return
	if not ClassDB.class_exists("RinkCoreThirdlife"):
		print("NOT RUN  rink variant: RinkCoreThirdlife is not built (bash engine/tools/rink.sh build thirdlife)"); quit(2); return
	var bad: PackedStringArray = []
	var plain := play("RinkCore", "", seed, frames)
	var off := play("RinkCoreThirdlife", '{"schema":"tl.rink.rules/1","rules":{"net_carry_wall":false}}', seed, frames)
	var on := play("RinkCoreThirdlife", '{"schema":"tl.rink.rules/1","rules":{"net_carry_wall":true}}', seed, frames)
	for r in [plain, off, on]:
		if r.has("err"): bad.append(str(r["err"]))
	var first_diff := -1
	if bad.is_empty():
		var a: PackedStringArray = plain["hashes"]
		var b: PackedStringArray = off["hashes"]
		for i in range(min(a.size(), b.size())):
			if a[i] != b[i]: first_diff = i + 1; break
		if first_diff < 0 and a.size() != b.size(): first_diff = min(a.size(), b.size()) + 1
		if first_diff >= 0: bad.append("switches off differ from thirdjam at frame %d" % first_diff)
		var on_diff := -1
		var c: PackedStringArray = on["hashes"]
		for i in range(min(a.size(), c.size())):
			if a[i] != c[i]: on_diff = i + 1; break
		print("VARIANT seed=%d plain %d frames %s last %s | off %d frames applied '%s' last %s | on %d frames applied '%s' score %s first differs from plain at %d" % [
			seed, a.size(), str(plain["score"]), a[a.size() - 1], b.size(), off["applied"], b[b.size() - 1], c.size(), on["applied"], str(on["score"]), on_diff])
	# 4. refusals
	var p: Object = ClassDB.instantiate("RinkCore")
	p.call("load_cartridge", FileAccess.get_file_as_string(REG))
	var e1: String = str(p.call("load_rules", '{"schema":"tl.rink.rules/1","rules":{"net_carry_wall":true}}'))
	if e1 == "": bad.append("the plain core took a rule")
	var v: Object = ClassDB.instantiate("RinkCoreThirdlife")
	v.call("load_cartridge", FileAccess.get_file_as_string(REG))
	var e2: String = str(v.call("load_rules", '{"schema":"tl.rink.rules/1","rules":{"no_such_rule":1}}'))
	var e3: String = str(v.call("load_rules", '{"schema":"tl.rink.rules/1","colour":"red"}'))
	if e2 == "": bad.append("the variant took an unknown rule")
	if e3 == "": bad.append("the variant took an unknown key")
	print("VARIANT refusals: plain '%s' | unknown rule '%s' | unknown key '%s'" % [e1, e2, e3])
	# 5. TLCores.open picks the class by the sidecar
	var dir := "user://rink_variant"
	DirAccess.make_dir_recursive_absolute(dir + "/data")
	var txt := FileAccess.get_file_as_string(REG)
	for n in ["plain.cartridge.json", "tl.cartridge.json"]:
		var f := FileAccess.open(dir + "/data/" + n, FileAccess.WRITE); f.store_string(txt); f.close()
	var fr := FileAccess.open(dir + "/data/tl.rules.json", FileAccess.WRITE)
	fr.store_string('{"schema":"tl.rink.rules/1","title":"selftest","rules":{"net_carry_wall":true}}'); fr.close()
	DirAccess.remove_absolute(dir + "/data/plain.rules.json")
	var ctx := FakeCtx.new()
	ctx.pack_dir = dir
	var cores: Object = load("res://kernel/api/tl_cores.gd").new(ctx)
	var c_plain: Object = cores.call("open", "rink", "plain.cartridge.json")
	var c_tl: Object = cores.call("open", "rink", "tl.cartridge.json")
	var k1: String = c_plain.get_class() if c_plain != null else "null"
	var k2: String = c_tl.get_class() if c_tl != null else "null"
	var k2r: String = str(c_tl.call("rules_applied")) if c_tl != null else ""
	print("VARIANT TLCores.open: plain.cartridge.json -> %s | tl.cartridge.json + tl.rules.json -> %s (rules '%s')" % [k1, k2, k2r])
	if k1 != "RinkCore": bad.append("TLCores.open without a sidecar gave %s" % k1)
	if k2 != "RinkCoreThirdlife" or k2r != "net_carry_wall=1": bad.append("TLCores.open with a sidecar gave %s (rules '%s')" % [k2, k2r])
	if bad.is_empty():
		print("PASS  rink variant: switches off = thirdjam on all %d frames (seed %d); the plain core refuses rules; TLCores.open picks RinkCoreThirdlife by the sidecar" % [(plain["hashes"] as PackedStringArray).size(), seed])
		quit(0)
	else:
		print("FAIL  rink variant: " + "; ".join(bad))
		quit(1)
