extends SceneTree
## M3 (spark world-sandbox, 26 Nov 2026): stamps (tl.stamp/1, stamp_file.gd, tools/stamp_tool.gd), headless, without a
## landscape. Prints `HOME stamp.<case> ok|fail <detail>`, then `HOME stamp ok` (or fail) and `HOME DONE`;
## engine/tools/selftest.d/756-home-pieces.sh reads them. Frames, not wall clock.
##   stamp.save    a box of blocks (a small house: walls, a window, a stair, a roof) and pieces saved, listed, read back
##                 the same; a piece reaching out of the box is left out; an empty box refuses
##   stamp.turns   placed turned 0, 1, 2, 3: every cell and rot where an independent turn of the cell centres says, one
##                 batch per placing, one undo empties it; placed over itself it is refused whole
##   stamp.item    exported as a .tlitem: item.gd `check` passes as kind stamp, tier data; imported: the same stamp,
##                 byte for byte; a tampered archive and a non-stamp item are refused
##   stamp.tool    the tool through build mode's keys: 0, two corners, G opens the name field ("Stamp 1"), Enter saves
##                 it (M5: the field is command_bar.gd; 765 types a name of its own); 1 picks it, R turns, LMB
##                 places it (one undo); X exports; a .tlitem in the inbox is imported when the tool is picked

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const StampFile := preload("res://kernel/world/build/stamp_file.gd")
const BuildMode := preload("res://kernel/world/build/build_mode.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const Item := preload("res://kernel/share/item.gd")
const Zip := preload("res://kernel/share/tlzip.gd")
const TMP := "user://tl_stamp_case"

var ok_all := true


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME stamp.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	DirAccess.make_dir_recursive_absolute(TMP)
	var s := save_case()
	turns(s)
	item(s)
	await tool_case()
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	print("HOME stamp %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


## A 5 x 4 x 4 hut at `o`: plank walls with a window, a stair at the door, a roof row; a bench and a lamp beside it.
func hut(b: RefCounted, o: Vector3i) -> void:
	var ops := []
	for y in 3:
		for x in 5:
			for z in 4:
				if (x == 0 or x == 4 or z == 0 or z == 3) and not (z == 3 and x == 2 and y < 2):
					var shape := Blocks.WINDOW if (y == 1 and x == 0 and z == 1) else Blocks.CUBE
					ops.append({"op": "place", "at": [o.x + x, o.y + y, o.z + z], "shape": shape, "mat": 3, "rot": 1 if shape == Blocks.WINDOW else 0})
	for x in 5:
		ops.append({"op": "place", "at": [o.x + x, o.y + 3, o.z + 1], "shape": Blocks.ROOF, "mat": 5, "rot": 0})
		ops.append({"op": "place", "at": [o.x + x, o.y + 3, o.z + 2], "shape": Blocks.ROOF, "mat": 5, "rot": 2})
	ops.append({"op": "place", "at": [o.x + 2, o.y, o.z + 4], "shape": Blocks.STAIR, "mat": 4, "rot": 2})
	ops.append({"op": "put", "at": [o.x + 4, o.y, o.z + 6], "part": "bench", "rot": 0})
	ops.append({"op": "put", "at": [o.x + 0, o.y, o.z + 6], "part": "street_lamp", "rot": 1})
	ops.append({"op": "put", "at": [o.x + 7, o.y, o.z + 1], "part": "fence", "rot": 0})     # reaches out of the box
	var r: Dictionary = b.apply(ops)
	assert(r.ok, str(r.refused))


func save_case() -> Dictionary:
	var b: RefCounted = HomeBuild.new(null, null, {})
	hut(b, Vector3i(10, 0, 10))
	var r: Dictionary = StampFile.from_region(b, Vector3i(10, 0, 10), Vector3i(17, 4, 17), "Hut")
	var dir := TMP.path_join("stamps")
	var w: Dictionary = StampFile.save(dir, r.stamp)
	var again: Dictionary = StampFile.save(dir, r.stamp)
	var listed: Dictionary = StampFile.list(dir)
	var back: Dictionary = listed.stamps[0].stamp if not (listed.stamps as Array).is_empty() else {}
	var same: bool = StampFile.text_of(back) == StampFile.text_of(r.stamp)
	var empty: Dictionary = StampFile.from_region(b, Vector3i(100, 0, 100), Vector3i(104, 4, 104), "Nothing")
	var nb: int = (r.stamp.get("blocks", []) as Array).size()
	var np: int = (r.stamp.get("pieces", []) as Array).size()
	var ok: bool = r.ok and w.ok and again.path == w.path and (listed.stamps as Array).size() == 1 and same and int(r.left_out) == 1 \
		and nb == 51 and np == 2 and not empty.ok and StampFile.validate(r.stamp) == ""
	say("save", ok, "box 8 x 5 x 8: %d blocks, %d pieces (%d reaching out left out), saved %s (again: the same file %s), listed %d, read back the same %s; an empty box: '%s'" % [
		nb, np, int(r.left_out), str(w.path).get_file(), again.path == w.path, (listed.stamps as Array).size(), same, str(empty.reason)])
	return r.stamp


## The cell centre of relative cell `c` turned `r` quarter turns about +y round the box's own centre, as a rotation of
## points (not stamp_file's index formula): the independent check of `turn_cell`.
static func spun(c: Vector3i, size: Vector3i, r: int) -> Vector3i:
	var centre := Vector3(size.x, 0, size.z) * 0.5
	var p := Vector3(c.x + 0.5, c.y, c.z + 0.5) - centre
	var q := Basis(Vector3.UP, r * PI * 0.5) * p
	var ts := Vector3(size.z, 0, size.x) * 0.5 if r % 2 == 1 else centre
	var w := q + ts
	return Vector3i(floori(w.x), c.y, floori(w.z))


func turns(s: Dictionary) -> void:
	var size := Vector3i(int(s.size[0]), int(s.size[1]), int(s.size[2]))
	var bad := []
	var lines := []
	for r in 4:
		var b: RefCounted = HomeBuild.new(null, null, {})
		var at := Vector3i(40, 2, -30)
		var ops := StampFile.ops(s, at, r)
		var res: Dictionary = b.apply(ops)
		var batches: int = b.edits.history.size()
		var cells_ok := 0
		for blk: Array in s.blocks:
			var c := at + spun(Vector3i(int(blk[0]), int(blk[1]), int(blk[2])), size, r)
			var want := Blocks.code(Blocks.shape_of(int(blk[3])), Blocks.mat_of(int(blk[3])), (Blocks.rot_of(int(blk[3])) + r) % 4, Blocks.flip_of(int(blk[3])))
			if b.code_at(c) == want:
				cells_ok += 1
			elif bad.size() < 6:
				bad.append("r%d block %s: %d at %s, want %d" % [r, str(blk), b.code_at(c), str(c), want])
		var pieces_ok := 0
		for p: Dictionary in s.pieces:
			var c := at + spun(Vector3i(int(p.at[0]), int(p.at[1]), int(p.at[2])), size, r)
			var rec: Dictionary = b.layer("pieces").pieces.get(c, {})
			if not rec.is_empty() and int(rec.rot) == (int(p.rot) + r) % 4 and str(rec.part) == str(p.part):
				pieces_ok += 1
			else:
				bad.append("r%d piece %s: none or another at %s" % [r, str(p.at), str(c)])
		var twice: Dictionary = b.preview(StampFile.ops(s, at, r))
		var undone: int = b.undo()
		var empty: bool = b.blocks.total == 0 and b.layer("pieces").size() == 0
		lines.append("r%d: %d/%d blocks and %d/%d pieces where the turn puts them, %d batch, again over itself: %d refused; undo %d ops -> empty %s" % [
			r, cells_ok, (s.blocks as Array).size(), pieces_ok, (s.pieces as Array).size(), batches, (twice.refused as Array).size(), undone, empty])
		if not (res.ok and batches == 1 and cells_ok == (s.blocks as Array).size() and pieces_ok == (s.pieces as Array).size() and empty
				and (twice.refused as Array).size() == ops.size()):
			bad.append("r%d: ok %s batches %d undo %d empty %s refused-over-itself %d of %d" % [r, res.ok, batches, undone, empty, (twice.refused as Array).size(), ops.size()])
	say("turns", bad.is_empty(), "; ".join(lines) + ("" if bad.is_empty() else "; BAD " + "; ".join(bad)))


func item(s: Dictionary) -> void:
	var path := ProjectSettings.globalize_path(TMP.path_join("hut.tlitem"))
	var ex: Dictionary = StampFile.export_item(s, path)
	var rd: Dictionary = Item.read_archive(path)
	var ck: Dictionary = Item.check(rd.files) if bool(rd.ok) else {"ok": false, "errors": rd.errors, "mismatches": [], "card": {}}
	var kind := str((ck.card as Dictionary).get("kind", ""))
	var tier := str((ck.card as Dictionary).get("tier", ""))
	var im: Dictionary = StampFile.import_item(path)
	var same: bool = bool(im.ok) and StampFile.text_of(im.stamp) == StampFile.text_of(s)
	# tampered: the stamp's bytes changed after the card was made (the hash no longer matches)
	var files: Dictionary = (rd.files as Dictionary).duplicate()
	files[StampFile.FILE] = (StampFile.text_of(s).replace("\"Hut\"", "\"Hat\"")).to_utf8_buffer()
	var bad_path := ProjectSettings.globalize_path(TMP.path_join("tampered.tlitem"))
	var fa := FileAccess.open(bad_path, FileAccess.WRITE)
	fa.store_buffer(Zip.build(files).bytes)
	fa.close()
	var tampered: Dictionary = StampFile.import_item(bad_path)
	# a look item is not a stamp
	var look := {"look.json": "{\"palette\":{}}".to_utf8_buffer()}
	var card: Dictionary = Item.build_card(look, {"kind": "look", "title": "A look"})
	look[Item.CARD] = Item.card_text(card.card).to_utf8_buffer()
	var look_path := ProjectSettings.globalize_path(TMP.path_join("look.tlitem"))
	fa = FileAccess.open(look_path, FileAccess.WRITE)
	fa.store_buffer(Zip.build(look).bytes)
	fa.close()
	var not_stamp: Dictionary = StampFile.import_item(look_path)
	var ok: bool = ex.ok and bool(ck.ok) and kind == "stamp" and tier == "data" and same and not tampered.ok and not not_stamp.ok
	say("item", ok, "exported %d bytes; item check %s, kind %s, tier %s; imported the same stamp byte for byte %s; tampered: '%s'; a look item: '%s'%s" % [
		int(ex.bytes), bool(ck.ok), kind, tier, same, str(tampered.reason), str(not_stamp.reason),
		"" if bool(ck.ok) else "; check: %s %s" % [str(ck.errors), str(ck.mismatches)]])


# ------------------------------------------------------------------ the tool through build mode
func tap(k: Key, shift := false) -> void:
	if shift:
		CaseUtil.key(KEY_SHIFT, true)
	CaseUtil.key(k, true, shift)
	await wait(2)
	CaseUtil.key(k, false, shift)
	if shift:
		CaseUtil.key(KEY_SHIFT, false)
	await wait(2)


func tool_case() -> void:
	var home := ProjectSettings.globalize_path(TMP.path_join("home"))
	var b: RefCounted = HomeBuild.new(null, null, {})
	var bm: Node = BuildMode.new()
	bm.set("build", b)
	root.add_child(bm)
	bm.open(home)
	hut(b, Vector3i(0, 0, 0))
	await wait(2)
	await tap(KEY_B)
	for i in 4:
		await tap(KEY_T)
	var t: RefCounted = bm.call("tool")
	var tool_id := str(t.get("id"))
	await tap(KEY_0)
	bm.set("hit", {"pos": Vector3(0.5, 0.5, 0.5), "normal": Vector3.UP, "block": true, "place": Vector3i(0, 1, 0), "remove": Vector3i(0, 0, 0)})
	t.press(MOUSE_BUTTON_LEFT, {})
	bm.set("hit", {"pos": Vector3(4.5, 0.5, 3.5), "normal": Vector3.UP, "block": true, "place": Vector3i(4, 1, 3), "remove": Vector3i(4, 0, 3)})
	t.press(MOUSE_BUTTON_LEFT, {})
	var bx: Array = t.call("box")
	await tap(KEY_G)
	var e := InputEventKey.new()
	e.keycode = KEY_ENTER
	e.physical_keycode = KEY_ENTER
	e.pressed = true
	root.push_input(e)                  # Enter into the name field (the GUI's path), "Stamp 1" already in it
	await wait(2)
	var listed: int = (t.get("stamps") as Array).size()
	var name_ := str((t.call("stamp") as Dictionary).get("name", ""))
	await tap(KEY_1)
	await tap(KEY_R)
	var turn_now: int = int(t.get("turn"))
	var before: int = b.blocks.total
	var hist: int = b.edits.history.size()
	var why: String = t.call("place_at", Vector3i(30, 0, 30))
	var placed: int = b.blocks.total - before
	var one_batch: bool = b.edits.history.size() == hist + 1
	b.undo()
	var undone: bool = b.blocks.total == before
	await tap(KEY_X)
	var exported := home.path_join("stamps/export/stamp-1.tlitem")
	var ex_ok := FileAccess.file_exists(exported)
	DirAccess.make_dir_recursive_absolute(home.path_join("stamps/inbox"))
	DirAccess.copy_absolute(exported, home.path_join("stamps/inbox/friend.tlitem"))
	DirAccess.rename_absolute(home.path_join("stamps/stamp-1.json"), home.path_join("stamps/stamp-1.old"))
	await tap(KEY_T, true)
	await tap(KEY_T)
	var after_import: int = (t.get("stamps") as Array).size()
	var inbox_left := FileAccess.file_exists(home.path_join("stamps/inbox/friend.tlitem"))
	await tap(KEY_B)
	bm.queue_free()
	await wait(2)
	var ok: bool = tool_id == "stamp" and bx.size() == 2 and bx[1] == Vector3i(4, 3, 3) and listed == 1 and name_ == "Stamp 1" and turn_now == 1 \
		and why == "" and placed > 0 and one_batch and undone and ex_ok and after_import == 1 and not inbox_left
	say("tool", ok, "tool %s; corners -> box %s (top found %d); G saved '%s' (%d listed); 1, R (turn %d), placed %d blocks in 1 batch %s, undo %s; X exported %s; the inbox's .tlitem imported when picked: %d stamp, inbox empty %s%s" % [
		tool_id, str(bx), (bx[1] as Vector3i).y if bx.size() == 2 else -1, name_, listed, turn_now, placed, one_batch, undone, exported.get_file() if ex_ok else "NOTHING",
		after_import, not inbox_left, "" if why == "" else "; refused '%s'" % why])
