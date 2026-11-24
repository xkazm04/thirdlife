extends SceneTree
# Rink core: the C++ verdicts on a corpus of cartridges and rules sidecars, for the Foreman's parity test (foreman/src/cartridge.ts).
#   cartridge: RinkCore.load_cartridge(text) (thirdjam's UJamCartridge::LoadFromString: strict parse + Validate); "" = ok
#   rules:     RinkCoreThirdlife.load_cartridge(hockey.regular) + load_rules(text) + reset(1) (a level tune is applied at reset)
# The corpus comes from `node foreman/dist/cartridge_corpus.js --write <dir>`.
#   godot --headless --path engine --script res://cores/rink/tools/rink_validate.gd -- --dir=<corpus dir> --out=<verdicts.json>

const REG := "res://cores/rink/native/content/Cartridges/hockey.regular.cartridge.json"

func _init() -> void:
	var dir := ""
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="): dir = a.substr(6)
		if a.begins_with("--out="): out = a.substr(6)
	var man: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/manifest.json"))
	if not (man is Array) or out == "":
		print("NOT RUN  rink validate: no manifest in '%s' or no --out" % dir); quit(2); return
	var have_tl := ClassDB.class_exists("RinkCoreThirdlife")
	var verdicts: Array = []
	var n_ok := 0
	for c: Dictionary in man:
		var text: String = FileAccess.get_file_as_bytes("%s/%d.json" % [dir, int(c["n"])]).get_string_from_utf8()
		var err := ""
		if String(c["kind"]) == "cartridge":
			var core: Object = ClassDB.instantiate("RinkCore")
			err = str(core.call("load_cartridge", text))
		else:
			if not have_tl:
				print("NOT RUN  rink validate: RinkCoreThirdlife is not built"); quit(2); return
			var v: Object = ClassDB.instantiate("RinkCoreThirdlife")
			v.call("load_cartridge", FileAccess.get_file_as_string(REG))
			err = str(v.call("load_rules", text))
			if err == "" and not v.call("reset", 1): err = "reset refused the rules (a level tune the core does not know)"
		if err == "": n_ok += 1
		verdicts.append({"name": c["name"], "kind": c["kind"], "sha1": c["sha1"], "ok": err == "", "error": err})
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"tool": "rink_validate/1", "source": "RinkCore " + str(ClassDB.class_call_static("RinkCore", "source_tree")), "cases": verdicts}, " "))
	f.close()
	print("PASS  rink validate: %d cases, %d accepted, %d refused -> %s" % [verdicts.size(), n_ok, verdicts.size() - n_ok, out])
	quit(0)
