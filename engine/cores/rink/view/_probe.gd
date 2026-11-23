extends SceneTree
func _init() -> void:
	var txt: String = FileAccess.get_file_as_string("res://packs/hokej/data/hockey.regular.cartridge.json")
	var c: Dictionary = JSON.parse_string(txt)
	var mode: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "one"
	var teams: Array = c["game"]["teams"]
	if mode == "one":
		teams[0]["skaters"] = [teams[0]["skaters"][0]]
		teams[1]["skaters"] = []
	elif mode == "oneone":
		teams[0]["skaters"] = [teams[0]["skaters"][0]]
		teams[1]["skaters"] = [teams[1]["skaters"][0]]
	print("class ", ClassDB.class_exists("RinkCore"))
	var core: RefCounted = ClassDB.instantiate("RinkCore")
	print("load: '", core.load_cartridge(JSON.stringify(c)), "'")
	core.set_human_mode("input")
	core.reset(1)
	print("reset done")
	for f in range(240):
		core.set_human_input({"Move": Vector2(1, 0), "Stick": Vector2(0.5, 0.5) if f > 120 else Vector2.ZERO})
		core.step()
		if f % 30 == 0 or f == 239:
			var s: Dictionary = core.snapshot()
			var k: Dictionary = s["Skaters"][int(s["HumanIndex"])] if int(s["HumanIndex"]) >= 0 else {}
			print(f, " frame ", s["Frame"], " phase ", s["Phase"], " n ", (s["Skaters"] as Array).size(), " hum ", s["HumanIndex"], " pos ", k.get("Pos"), " vel ", k.get("Vel"), " yaw ", k.get("Yaw"), " blade ", k.get("BladePos"), " faceoff ", k.get("bAtFaceoff"), " cd ", s["FaceoffCountdown"], " puck ", s["Puck"]["Pos"], " carrier ", s["Carrier"])
	quit(0)
