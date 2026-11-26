extends SceneTree
## M3 (spark world-sandbox, 26 Nov 2026): unlocks from play (unlocks.gd, unlocks.json, trophies.gd and the few lines in
## kernel/dungeon/dungeon.gd `close`), headless (engine/tools/selftest.d/758-home-unlocks.sh). Prints
## `HOME unlocks.<case> ok|fail <detail>`, then `HOME unlocks ok` (or fail) and `HOME DONE`. Frames, not wall clock.
##   unlocks.rules     the shipped rules read without an error; M1's shapes 1-8 and materials 1-9 are never locked; a
##                     rules file granting an M1 material, or with an unknown key, is refused
##   unlocks.dungeon   a scripted dungeon end writes trophies.json: the paddle seed played to 5 (plays 1, wins 1, best 5),
##                     played again and left at 0 (plays 2, wins 1, best 5); a counted run (frames > 0) writes nothing
##   unlocks.met       with those trophies: what "play once" and "score 5 in Paddle court" grant is free, what "play 3
##                     times" and "win Parkour once" grant is locked, each with its condition
##   unlocks.tools     a locked part refuses in the piece tool with its condition (nothing put; the slot says locked);
##                     a free one puts; a locked material refuses in the blocks tool; a stamp holding a locked part is refused

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const BuildMode := preload("res://kernel/world/build/build_mode.gd")
const Unlocks := preload("res://kernel/world/build/unlocks.gd")
const Trophies := preload("res://kernel/world/build/trophies.gd")
const StampFile := preload("res://kernel/world/build/stamp_file.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const Catalog := preload("res://kernel/world/build/piece_catalog.gd")
const Dungeon := preload("res://kernel/dungeon/dungeon.gd")
const TMP := "user://tl_unlock_case"

var ok_all := true
var home := ""


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME unlocks.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	home = ProjectSettings.globalize_path(TMP.path_join("home"))
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	DirAccess.make_dir_recursive_absolute(home)
	OS.set_environment("TL_HOME_BUILD_DIR", home)
	rules_case()
	await dungeon_case()
	met_case()
	await tools_case()
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	print("HOME unlocks %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


func rules_case() -> void:
	var u: RefCounted = Unlocks.new("")
	var m1_free := true
	for m in range(1, 10):
		m1_free = m1_free and u.locked("mats", m) == ""
	for s in range(1, 9):
		m1_free = m1_free and u.locked("shapes", s) == ""
	var bad_path := ProjectSettings.globalize_path(TMP.path_join("bad_rules.json"))
	var f := FileAccess.open(bad_path, FileAccess.WRITE)
	f.store_string("{\"schema\":\"tl.unlocks/1\",\"rules\":[{\"id\":\"a\",\"when\":{\"pack\":\"*\",\"plays\":1},\"grant\":{\"mats\":[3]}},{\"id\":\"b\",\"when\":{\"pack\":\"*\",\"plays\":1},\"grant\":{\"parts\":[\"bench\"]},\"title\":\"x\"}]}")
	f.close()
	var bad: Dictionary = Unlocks.read_rules(bad_path)
	var ok: bool = u.errors.is_empty() and u.rules.size() == 5 and m1_free and (bad.errors as Array).size() == 2 and (bad.rules as Array).is_empty()
	say("rules", ok, "%d rules, errors %s; M1's shapes 1-8 and materials 1-9 free %s; locked with no play: %s; a bad file: %s" % [
		u.rules.size(), str(u.errors), m1_free, str(u.locks().keys()), str(bad.errors)])


## Opens the paddle seed as a dungeon a person plays (frames 0), runs `frames` frames, gives the player `score`
## points, leaves. Returns the trophies entry written (or {}).
func play(score: int, frames := 20, counted := 0) -> Dictionary:
	var d: Node = Dungeon.new()
	root.add_child(d)
	var ok: bool = await d.call("open", ProjectSettings.globalize_path("res://seeds/seed_paddle"), {"seed": 1, "frames": counted})
	if not ok:
		d.queue_free()
		return {"error": str(d.get("problem"))}
	await wait(frames)
	var rules: Node = Trophies._find_rules(d)
	if rules != null and score > 0:
		rules.call("add_score", (rules.get("sides") as PackedStringArray)[0], score)
	await wait(2)
	if not bool(d.get("finished")):
		d.call("close", "leave")
	await wait(2)
	d.queue_free()
	await wait(1)
	return Trophies.read(home).packs.get("seed.paddle", {})


func dungeon_case() -> void:
	var first: Dictionary = await play(5)
	var second: Dictionary = await play(0)
	var counted: Dictionary = await play(0, 10, 30)
	var text := FileAccess.get_file_as_string(home.path_join("trophies.json"))
	var ok: bool = str(first) == str({"plays": 1, "wins": 1, "best": 5}) and str(second) == str({"plays": 2, "wins": 1, "best": 5}) \
		and str(counted) == str(second) and text == "{\"schema\":\"tl.trophies/1\",\"packs\":{\"seed.paddle\":{\"plays\":2,\"wins\":1,\"best\":5}}}\n"
	say("dungeon", ok, "paddle to 5: %s; again, left at 0: %s; a counted run of 30 frames: %s (unchanged); trophies.json %s" % [
		str(first), str(second), str(counted), text.strip_edges()])


func met_case() -> void:
	var u: RefCounted = Unlocks.new(home)
	var got := {}
	for k: Array in [["parts", "bench"], ["parts", "light_mast"], ["mats", 11], ["parts", "street_lamp"], ["mats", 12], ["parts", "house"],
			["parts", "watch_tower"], ["parts", "fence"]]:
		got["%s:%s" % [k[0], str(k[1])]] = u.locked(k[0], k[1])
	var want := {"parts:bench": "", "parts:light_mast": "", "mats:11": "", "parts:street_lamp": "play any dungeon 3 times",
		"mats:12": "play any dungeon 3 times", "parts:house": "win Parkour once", "parts:watch_tower": "win Ice hockey once", "parts:fence": ""}
	say("met", str(got) == str(want), "with plays 2, wins 1, best 5 at the paddle court: %s" % str(got))


func tools_case() -> void:
	var b: RefCounted = HomeBuild.new(null, null, {})
	var bm: Node = BuildMode.new()
	bm.set("build", b)
	root.add_child(bm)
	bm.open(home)
	await wait(2)
	bm.call("enter")
	bm.call("switch_tool", 0, "piece")
	var t: RefCounted = bm.call("tool")
	t.set("part_index", Catalog.PARTS.find("house"))
	bm.set("hit", {"pos": Vector3(0.5, 0.0, 0.5), "normal": Vector3.UP, "block": false, "place": Vector3i(0, 0, 0), "remove": HomeBuild.NO_CELL})
	t.press(MOUSE_BUTTON_LEFT, {})
	var house_why := str(t.get("reason"))
	var slot_house := ""
	for s: Dictionary in t.slots():
		if str(s.label).begins_with("house"):
			slot_house = str(s.label).replace("\n", " ")
	t.set("part_index", Catalog.PARTS.find("bench"))
	t.press(MOUSE_BUTTON_LEFT, {})
	var bench_why := str(t.get("reason"))
	var pieces: int = b.layer("pieces").size()
	bm.call("switch_tool", 0, "blocks")
	var bt: RefCounted = bm.call("tool")
	bt.set("mat", 12)
	bm.set("hit", {"pos": Vector3(20.5, 0.0, 0.5), "normal": Vector3.UP, "block": false, "place": Vector3i(20, 0, 0), "remove": HomeBuild.NO_CELL})
	var held: bool = bt.press(MOUSE_BUTTON_LEFT, {})
	var plaster_why := str(bt.get("reason"))
	bt.set("mat", 11)
	held = bt.press(MOUSE_BUTTON_LEFT, {}) or held
	bt.release(MOUSE_BUTTON_LEFT)
	var brick_placed: bool = b.code_at(Vector3i(20, 0, 0)) == Blocks.code(Blocks.CUBE, 11)
	var stamp := {"schema": "tl.stamp/1", "name": "Mill", "size": [9, 8, 9], "pieces": [{"at": [4, 0, 4], "part": "house", "rot": 0, "seed": 1}]}
	var dir := home.path_join("stamps")
	StampFile.save(dir, stamp)
	bm.call("switch_tool", 0, "stamp")
	var st: RefCounted = bm.call("tool")
	st.set("current", 0)
	var stamp_why: String = st.call("place_at", Vector3i(40, 0, 40))
	var stamp_slot := str((st.slots()[1] as Dictionary).label).replace("\n", " ")
	bm.call("leave")
	bm.queue_free()
	await wait(2)
	var ok: bool = house_why == "locked: win Parkour once" and slot_house == "house locked" and bench_why == "" and pieces == 1 \
		and plaster_why == "locked: play any dungeon 3 times" and brick_placed and stamp_why == "house is locked: win Parkour once" \
		and stamp_slot == "Mill locked" and b.layer("pieces").size() == 1
	say("tools", ok, "house: '%s' (slot '%s'); bench: '%s' (%d piece put); plaster: '%s'; brick placed %s; a stamp with a house: '%s' (slot '%s')" % [
		house_why, slot_house, bench_why, pieces, plaster_why, brick_placed, stamp_why, stamp_slot])
