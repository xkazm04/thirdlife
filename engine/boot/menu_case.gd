extends SceneTree
## 26 Nov (the owner: the Dungeons list has no way "to browse through dozens of games", and one game shows once per
## version): selftest 641. Headless; nothing is started.
##   menu.pages     12 rows: the list shows 5 a page; Next / Previous (and turn()) walk 5, 5, 2; the page line says so;
##                  a row's press still emits its index in the whole list
##   menu.versions  the person's list holds two versions of one game and one other game: read_menu keeps one row per
##                  game (the highest version, 0.1.10 over 0.1.9), the person's newest game first, after the shipped ones

const Menu: GDScript = preload("res://boot/menu.gd")
const Dungeons: GDScript = preload("res://kernel/dungeon/dungeons.gd")

var passed: int = 0
var failed: int = 0


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		passed += 1
		print("PASS %s" % name)
	else:
		failed += 1
		print("FAIL %s: %s" % [name, detail])


func _initialize() -> void:
	_run.call_deferred()


func _names(m: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for b: Node in m.find_children("Dungeon*", "Button", true, false):
		if (b as Control).is_visible_in_tree() and str(b.name).trim_prefix("Dungeon").is_valid_int():
			out.append(str(b.name))
	return out


func _run() -> void:
	await process_frame
	var rows: Array = []
	for i: int in 12:
		rows.append({"title": "Game %02d" % i, "dir": "C:/x/game%02d" % i, "mine": true})
	var m: CanvasLayer = Menu.new()
	root.add_child(m)
	m.call("open", rows, "", true)
	await process_frame
	m.call("_show_list")
	await process_frame
	var picked: Array = []
	m.connect("dungeon", func(i: int) -> void: picked.append(i))
	var p1: PackedStringArray = _names(m)
	var next: Button = m.find_child("Next", true, false) as Button
	var prev: Button = m.find_child("Previous", true, false) as Button
	var first_off: bool = prev != null and prev.disabled and next != null and not next.disabled
	next.pressed.emit()
	await process_frame
	var p2: PackedStringArray = _names(m)
	var line: String = (m.find_child("Page", true, false) as Label).text
	m.call("turn", 1)
	await process_frame
	var p3: PackedStringArray = _names(m)
	var last_off: bool = (m.find_child("Next", true, false) as Button).disabled and not (m.find_child("Previous", true, false) as Button).disabled
	(m.find_child("Dungeon11", true, false) as Button).pressed.emit()
	m.call("turn", -2)
	await process_frame
	var back: PackedStringArray = _names(m)
	_check("menu.pages: 12 games show 5 a page (Dungeon0-4, 5-9, 10-11); Next / Previous turn and switch off at the ends; the page line says 'page 2 of 3'; a row emits its index in the whole list",
		",".join(p1) == "Dungeon0,Dungeon1,Dungeon2,Dungeon3,Dungeon4" and ",".join(p2) == "Dungeon5,Dungeon6,Dungeon7,Dungeon8,Dungeon9" and ",".join(p3) == "Dungeon10,Dungeon11"
			and first_off and last_off and line.begins_with("page 2 of 3") and picked == [11] and ",".join(back) == ",".join(p1),
		"pages %s | %s | %s; ends %s %s; line '%s'; picked %s; back %s" % [",".join(p1), ",".join(p2), ",".join(p3), str(first_off), str(last_off), line, str(picked), ",".join(back)])
	m.queue_free()

	# the person's list: two versions of one game (0.1.9 then 0.1.10) and one other game
	var tmp: String = ProjectSettings.globalize_path("user://menu_case")
	DirAccess.make_dir_recursive_absolute(tmp)
	var packs: Array = [["a_v019", "game.alpha", "0.1.9", "Alpha v0.1.9"], ["b_v010", "game.beta", "0.1.0", "Beta"], ["a_v0110", "game.alpha", "0.1.10", "Alpha v0.1.10"]]
	var list: Array = []
	for p: Array in packs:
		var dir: String = tmp.path_join(str(p[0]))
		DirAccess.make_dir_recursive_absolute(dir)
		var f: FileAccess = FileAccess.open(dir.path_join("pack.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"id": p[1], "version": p[2]}))
		f.close()
		list.append({"pack": dir, "title": p[3]})
	var lf: FileAccess = FileAccess.open(tmp.path_join("dungeons.user.json"), FileAccess.WRITE)
	lf.store_string(JSON.stringify({"schema": "tl.dungeons.user/1", "dungeons": list}))
	lf.close()
	OS.set_environment("TL_USER_DUNGEONS", tmp.path_join("dungeons.user.json"))
	var menu: Dictionary = Dungeons.call("read_menu")
	OS.unset_environment("TL_USER_DUNGEONS")
	var mine: Array = (menu["dungeons"] as Array).filter(func(r: Dictionary) -> bool: return r.get("mine", false) == true)
	var titles: Array = mine.map(func(r: Dictionary) -> String: return str(r["title"]))
	var shipped: int = (Dungeons.call("read")["dungeons"] as Array).size()
	_check("menu.versions: read_menu keeps one row per game, the highest version (Alpha v0.1.10 over v0.1.9), the person's newest game first, after the %d shipped" % shipped,
		titles == ["Beta", "Alpha v0.1.10"] and (menu["dungeons"] as Array).size() == shipped + 2 and (menu["dungeons"] as Array)[0].get("mine", false) != true,
		"mine %s; rows %d (shipped %d); errors %s" % [str(titles), (menu["dungeons"] as Array).size(), shipped, str(menu["errors"])])
	# 28 Nov: one row per game with its variations inside; the name only, the version beside it; Q / E switch what Enter opens
	var vpacks: Array = [["g_v011", "game.gamma", "0.1.1", "Gamma", ""], ["g_a", "game.gamma_a", "0.1.1", "Gamma", "spike A"],
		["g_h", "game.gamma_h", "0.1.0", "Gamma", "by hand"], ["d_x", "game.delta_x", "0.2.0", "Delta", "lone variant"]]
	var vlist: Array = []
	for p: Array in vpacks:
		var dir2: String = tmp.path_join(str(p[0]))
		DirAccess.make_dir_recursive_absolute(dir2)
		var f2: FileAccess = FileAccess.open(dir2.path_join("pack.json"), FileAccess.WRITE)
		f2.store_string(JSON.stringify({"id": p[1], "version": p[2]}))
		f2.close()
		var vr: Dictionary = {"pack": dir2, "title": p[3]}
		if not str(p[4]).is_empty():
			vr["variant"] = p[4]
		vlist.append(vr)
	var vf: FileAccess = FileAccess.open(tmp.path_join("variants.user.json"), FileAccess.WRITE)
	vf.store_string(JSON.stringify({"schema": "tl.dungeons.user/1", "dungeons": vlist}))
	vf.close()
	OS.set_environment("TL_USER_DUNGEONS", tmp.path_join("variants.user.json"))
	var vmenu: Dictionary = Dungeons.call("read_menu")
	OS.unset_environment("TL_USER_DUNGEONS")
	var vmine: Array = (vmenu["dungeons"] as Array).filter(func(r: Dictionary) -> bool: return r.get("mine", false) == true)
	var gamma: Dictionary = {}
	for r: Dictionary in vmine:
		if str(r["title"]) == "Gamma":
			gamma = r
	var labels: Array = (gamma.get("variants", []) as Array).map(func(v: Dictionary) -> String: return str(v["variant"]))
	var grow: Dictionary = gamma.duplicate()
	grow["dir"] = str(gamma.get("pack", ""))
	grow["choices"] = [{"variant": "latest", "dir": grow["dir"], "version": "0.1.1"}]
	for v: Dictionary in gamma.get("variants", []):
		grow["choices"].append({"variant": str(v["variant"]), "dir": str(v["pack"]), "version": str(v.get("version", ""))})
	var vm2: CanvasLayer = (load("res://boot/menu.gd") as GDScript).new()
	root.add_child(vm2)
	vm2.call("open", [grow], "", false)
	await process_frame
	var t0: String = (vm2.find_child("Dungeon0", true, false) as Button).text
	vm2.call("cycle_variant", 0, 1)
	var t1: String = (vm2.find_child("Dungeon0", true, false) as Button).text
	var d1: String = str(grow["dir"])
	vm2.call("cycle_variant", 0, -2)
	var d2: String = str(grow["dir"])
	vm2.queue_free()
	_check("menu.variants: rows titled with the game's name fold their 'variant' rows inside it (no extra rows; a lone variant stands alone); the row shows the name, then v<version>; Q / E switch the variant Enter opens",
		vmine.size() == 2 and labels == ["spike A", "by hand"] and t0.begins_with("Gamma\nv0.1.1") and t1.contains("spike A  (Q E: 2 of 3)")
			and d1.ends_with("g_a") and d2.ends_with("g_h") and vmenu["errors"].is_empty(),
		"mine %d; labels %s; t0 '%s'; t1 '%s'; dirs %s %s; errors %s" % [vmine.size(), str(labels), t0.replace("\n", "|"), t1.replace("\n", "|"), d1, d2, str(vmenu["errors"])])
	print("[menu] %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
