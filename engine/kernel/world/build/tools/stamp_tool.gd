extends RefCounted
## M3 (spark world-sandbox, 26 Nov 2026): build mode's stamp tool (tl.stamp/1, stamp_file.gd; PIECES.md has the keys).
##   0            a new selection: LMB the first corner, LMB the opposite corner (the block under the cursor, or the
##                cell on the ground), wheel the box's top; G names it in a field (command_bar.gd, "Stamp N" already
##                in it and selected: type to replace it, at most 60 characters), Enter saves it as
##                user://home/stamps/<slug>.json, Esc cancels. While the field is open the tool has the keyboard
##   1-9          a saved stamp of the shown page (Tab / Shift+Tab page, wheel the next or previous stamp)
##   R            turn the stamp (quarter turns)          LMB   place it: ONE batch of place and put ops (one undo)
##   X            export the current stamp as a shared item: user://home/stamps/export/<slug>.tlitem (kind stamp)
##   I            import every .tlitem dropped into user://home/stamps/inbox/ (also when the tool is picked)
## Enter is the host's (the command bar), so a selection is saved with G. While placing, the ghost is the stamp's blocks
## (preview_mesh.gd) and pieces (piece_ghost.gd) where they would go, red when `build.preview(ops)` refuses any of them
## (the reason in the hotbar); a refused stamp is not placed at all. A stamp holding a locked part or material
## (unlocks.gd) refuses with the condition. The tool interface is BUILD.md "Tools".

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const StampFile := preload("res://kernel/world/build/stamp_file.gd")
const Unlocks := preload("res://kernel/world/build/unlocks.gd")
const PreviewMesh := preload("res://kernel/world/build/preview_mesh.gd")
const PieceGhost := preload("res://kernel/world/build/piece_ghost.gd")
const Catalog := preload("res://kernel/world/build/piece_catalog.gd")
const Bar := preload("res://kernel/world/build/command_bar.gd")
const NAME_KEYS := [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]
const PAGE := 9
const SCAN_UP := 48                     # cells above the box's floor the automatic top looks for content
const STEADY := 6                       # frames the aim stays on one cell before the dry run is asked
const KEY_HELP := "0 new box: LMB corner, LMB corner, wheel top, G save   1-9 stamp   Tab page   R turn   LMB place   X export   I import   Ctrl+Z undo   T tool   B or Esc leave"

var id := "stamp"
var title := "Stamps"
var host: Node = null                   # build_mode.gd
var stamps: Array = []                  # stamp_file.gd list(): [{slug, path, stamp}]
var current := -1                       # index into stamps; -1: selecting a new box
var turn := 0
var corner_a: Variant = null            # Vector3i or null
var corner_b: Variant = null
var top := 0                            # the box's top cell y
var reason := ""
var note := ""                          # the last thing done ("saved Stamp 2", "imported 1")
var unlocks: RefCounted = null
var preview: Node3D = null              # preview_mesh.gd of the current stamp at turn `turn`, relative cells
var pghost: Node3D = null               # piece_ghost.gd
var box_ghost: MeshInstance3D = null
var _drawn := ""                        # "<slug>|<turn>" drawn in `preview`
var _aim_cell: Variant = null
var _steady := 0
var _checked := ""
var name_bar: CanvasLayer = null        # command_bar.gd: the stamp's name, opened by G
var _latched := false                   # Enter or Esc closed the name field and is still held: build mode must not read
                                        # it as a new press (Enter would open the command bar, Esc would leave)


func setup(h: Node) -> void:
	host = h
	unlocks = Unlocks.new("")


func polled() -> Array:
	return [KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_TAB, KEY_R, KEY_G, KEY_X, KEY_I]


## The Home's folders: <dir>/stamps, <dir>/stamps/inbox, <dir>/stamps/export ("" when nothing is saved here).
func stamps_dir() -> String:
	var d := str(host.get("dir"))
	return "" if d == "" else d.path_join("stamps")


func selected(on: bool) -> void:
	reason = ""
	if not on and naming():
		name_bar.close()
	_checked = ""
	_hide()
	if on:
		turn = 0
		unlocks = Unlocks.new(str(host.get("dir")))
		import_inbox()
		refresh()


func refresh() -> void:
	var dir := stamps_dir()
	stamps = StampFile.list(dir).stamps if dir != "" else []
	if current >= stamps.size():
		current = stamps.size() - 1
	_drawn = ""


func stamp() -> Dictionary:
	return stamps[current].stamp if current >= 0 and current < stamps.size() else {}


func slots() -> Array:
	var out := [{"key": "0", "label": "new box", "lit": current < 0}]
	var page := maxi(current, 0) / PAGE
	for i: int in range(page * PAGE, mini(page * PAGE + PAGE, stamps.size())):
		var label := str(stamps[i].stamp.name)
		if locked_in(stamps[i].stamp) != "":
			label += "\nlocked"
		out.append({"key": str(i - page * PAGE + 1), "label": label, "lit": i == current})
	return out


func status() -> Dictionary:
	var info := ""
	if current < 0:
		if corner_a == null:
			info = "new box: LMB the first corner"
		elif corner_b == null:
			info = "new box: LMB the opposite corner"
		else:
			var b := box()
			var s: Vector3i = b[1] - b[0] + Vector3i.ONE
			info = "box %d x %d x %d   wheel top   G save" % [s.x, s.y, s.z]
	else:
		var d := stamp()
		info = "%s   %d blocks   %d pieces   rot %d" % [str(d.name), (d.get("blocks", []) as Array).size(), (d.get("pieces", []) as Array).size(), turn]
	if note != "":
		info += "   (%s)" % note
	return {"info": info, "reason": reason}


func hint() -> String:
	return "Enter save   Esc cancel" if naming() else KEY_HELP


## True while the name field has the keyboard, and until the key that closed it is let go.
func blocks_input() -> bool:
	return naming() or _latched


func naming() -> bool:
	return name_bar != null and name_bar.is_open()


## The selection box [lo, hi] (inclusive cells), or [] while a corner is missing.
func box() -> Array:
	if corner_a == null or corner_b == null:
		return []
	var a: Vector3i = corner_a
	var b: Vector3i = corner_b
	var lo := Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z))
	var hi := Vector3i(maxi(a.x, b.x), maxi(top, maxi(a.y, b.y)), maxi(a.z, b.z))
	return [lo, hi]


func key(e: InputEvent) -> bool:
	if e is InputEventMouseButton:
		var bi: int = (e as InputEventMouseButton).button_index
		if bi != MOUSE_BUTTON_WHEEL_UP and bi != MOUSE_BUTTON_WHEEL_DOWN:
			return false
		var up := bi == MOUSE_BUTTON_WHEEL_UP
		if current < 0 and corner_b != null:
			var floor_y: int = mini((corner_a as Vector3i).y, (corner_b as Vector3i).y)
			top = clampi(top + (1 if up else -1), floor_y, floor_y + StampFile.SIDE_MAX - 1)
		elif not stamps.is_empty():
			current = posmod(current + (-1 if up else 1), stamps.size())
		_checked = ""
		return true
	var k := e as InputEventKey
	if k == null or not k.pressed:
		return false
	var code: int = k.physical_keycode
	note = ""
	if code == KEY_0:
		current = -1
		corner_a = null
		corner_b = null
	elif code >= KEY_1 and code <= KEY_9:
		var i: int = (maxi(current, 0) / PAGE) * PAGE + code - KEY_1
		if i < stamps.size():
			current = i
	elif code == KEY_TAB:
		if not stamps.is_empty():
			var pages := ceili(float(stamps.size()) / PAGE)
			current = mini(posmod(maxi(current, 0) / PAGE + (-1 if k.shift_pressed else 1), pages) * PAGE, stamps.size() - 1)
	elif code == KEY_R:
		turn = (turn + 1) % 4
	elif code == KEY_G:
		ask_name()
	elif code == KEY_X:
		export_current()
	elif code == KEY_I:
		import_inbox()
		refresh()
	else:
		return false
	_checked = ""
	return true


# ------------------------------------------------------------------ saving, sharing
## G: the name field opens with the next free default name ("Stamp N"), or the hotbar says why nothing can be saved.
func ask_name() -> void:
	if box().is_empty() or stamps_dir() == "":
		save_box()                      # says why: no corners, or no Home file here
		return
	if name_bar == null or not is_instance_valid(name_bar):
		name_bar = Bar.new()
		name_bar.name = "StampName"
		host.add_child(name_bar)
		name_bar.submitted.connect(_on_named)
		name_bar.cancelled.connect(func() -> void:
			name_bar.close()
			_latched = true
			note = "not saved")
	var s: Vector3i = box()[1] - box()[0] + Vector3i.ONE
	name_bar.open("Name the stamp (box %d x %d x %d)   Enter save   Esc cancel" % [s.x, s.y, s.z],
		StampFile.next_name(stamps_dir()), StampFile.NAME_MAX, "a name for this stamp")


func _on_named(text: String) -> void:
	name_bar.close()
	_latched = true
	var n := text.replace("\n", " ").strip_edges()
	save_box(n if n != "" else StampFile.next_name(stamps_dir()))


## Saves the selection box as a new stamp ("Stamp N"). Returns "" or why not.
func save_box(name := "") -> String:
	var b := box()
	var dir := stamps_dir()
	if b.is_empty():
		reason = "choose two corners first"
	elif dir == "":
		reason = "not saved (no Home file here)"
	else:
		var r: Dictionary = StampFile.from_region(host.build, b[0], b[1], name if name != "" else StampFile.next_name(dir))
		if not bool(r.ok):
			reason = str(r.reason)
		else:
			var w: Dictionary = StampFile.save(dir, r.stamp)
			reason = "" if bool(w.ok) else str(w.reason)
			if reason == "":
				refresh()
				for i: int in stamps.size():
					if str(stamps[i].path) == str(w.path):
						current = i
				note = "saved %s%s" % [str(r.stamp.name), "" if int(r.left_out) == 0 else ", %d pieces reach out of the box: left out" % int(r.left_out)]
				corner_a = null
				corner_b = null
				print(JSON.stringify({"schema": "tl.view/1", "kind": "build_stamp", "saved": str(w.path), "frame": host.frames}, "", false))
	return reason


## Writes the current stamp as <stamps>/export/<slug>.tlitem. Returns its path, or "".
func export_current() -> String:
	if current < 0 or stamps_dir() == "":
		reason = "choose a stamp to export"
		return ""
	var path := stamps_dir().path_join("export").path_join(str(stamps[current].slug) + ".tlitem")
	var r: Dictionary = StampFile.export_item(stamp(), path)
	reason = "" if bool(r.ok) else str(r.reason)
	if reason == "":
		note = "exported %s" % path.get_file()
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_stamp", "exported": path, "bytes": int(r.bytes), "frame": host.frames}, "", false))
	return path if reason == "" else ""


## Imports every .tlitem in <stamps>/inbox: a good one becomes a stamp and leaves the inbox; a bad one stays and its
## reason is shown. Returns how many were imported.
func import_inbox() -> int:
	var dir := stamps_dir()
	if dir == "":
		return 0
	var inbox := dir.path_join("inbox")
	var da := DirAccess.open(inbox)
	if da == null:
		return 0
	var n := 0
	var names: Array = Array(da.get_files())
	names.sort()
	for f: String in names:
		if f.get_extension() != "tlitem":
			continue
		var r: Dictionary = StampFile.import_item(inbox.path_join(f))
		if bool(r.ok):
			var w: Dictionary = StampFile.save(dir, r.stamp)
			if bool(w.ok):
				DirAccess.remove_absolute(inbox.path_join(f))
				n += 1
				continue
			r.reason = w.reason
		reason = "%s: %s" % [f, str(r.reason)]
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_stamp", "refused": f, "reason": str(r.reason)}, "", false))
	if n > 0:
		note = "imported %d" % n
		refresh()
	return n


## "" or the condition of the first locked part or material stamp `d` holds.
func locked_in(d: Dictionary) -> String:
	for p: Dictionary in d.get("pieces", []):
		var why: String = unlocks.locked("parts", str(p.part))
		if why != "":
			return "%s is locked: %s" % [str(p.part).replace("_", " "), why]
	var seen := {}
	for b: Array in d.get("blocks", []):
		var m := Blocks.mat_of(int(b[3]))
		if not seen.has(m):
			seen[m] = true
			var why: String = unlocks.locked("mats", m)
			if why != "":
				return "%s is locked: %s" % [Blocks.mat_key(m), why]
	return ""


# ------------------------------------------------------------------ the cursor
## Where the stamp's turned box goes for an aim at `cell`: centred on it in x and z, its floor on the cell's y.
func anchor_for(cell: Vector3i) -> Vector3i:
	var s := StampFile.turned_size(Vector3i(int(stamp().size[0]), int(stamp().size[1]), int(stamp().size[2])), turn)
	return cell - Vector3i(s.x / 2, 0, s.z / 2)


func ops_at(cell: Vector3i) -> Array:
	return StampFile.ops(stamp(), anchor_for(cell), turn)


func _corner_of(h: Dictionary) -> Vector3i:
	return h.remove if bool(h.get("block", false)) and h.remove != HomeBuild.NO_CELL else h.place


func aim(h: Dictionary, _mode: Dictionary) -> void:
	if h.is_empty():
		_hide()
		return
	if current < 0:
		_show_box(h)
		return
	var cell: Vector3i = h.place
	if _aim_cell != cell:
		_aim_cell = cell
		_steady = 0
	_steady += 1
	_draw_stamp()
	var at := anchor_for(cell)
	(preview as Node3D).position = Vector3(at)
	var items := []
	for op: Dictionary in ops_at(cell):
		if op.op == "put":
			var fp: Array = host.build.layer("pieces").footprint_of(op)
			if not fp.is_empty():
				items.append([fp[3], fp[2]])
	var k := "%s|%d|%s" % [str(stamps[current].slug), turn, str(cell)]
	if _steady >= STEADY and _checked != k:
		_checked = k
		reason = check_at(cell)
	elif _checked != k:
		reason = ""
	pghost.show_pieces(items, reason != "", k + reason)
	box_ghost.visible = false


## "" or why the current stamp may not be placed at `cell` now: a lock, or the dry run's first refusal.
func check_at(cell: Vector3i) -> String:
	var why := locked_in(stamp())
	if why != "":
		return why
	var r: Dictionary = host.build.preview(ops_at(cell))
	return "" if bool(r.ok) else "%d of %d refused: %s" % [(r.refused as Array).size(), (r.refused as Array).size() + int(r.applied), str(r.reason)]


func _draw_stamp() -> void:
	_nodes()
	var k := "%s|%d" % [str(stamps[current].slug), turn]
	if _drawn == k:
		preview.visible = true
		return
	_drawn = k
	var store: RefCounted = Blocks.new(16)
	store.cap_chunk = 1 << 30
	store.cap_home = 1 << 30
	for op: Dictionary in StampFile.ops(stamp(), Vector3i.ZERO, turn):
		if op.op == "place":
			store.put(Vector3i(int(op.at[0]), int(op.at[1]), int(op.at[2])), Blocks.code(int(op.shape), int(op.mat), int(op.rot), bool(op.get("flip", false))))
	store.dirty.clear()
	preview.show_stores(store, null)
	preview.visible = true


func _show_box(h: Dictionary) -> void:
	_nodes()
	preview.visible = false
	pghost.hide_ghost()
	var a: Variant = corner_a
	var b: Variant = corner_b if corner_b != null else (_corner_of(h) if corner_a != null else null)
	if a == null:
		var c := _corner_of(h)
		_box_mesh(c, c)
		return
	var lo := Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z))
	var hi := Vector3i(maxi(a.x, b.x), maxi(a.y, b.y), maxi(a.z, b.z))
	if corner_b != null:
		hi.y = maxi(hi.y, top)
	_box_mesh(lo, hi)


## The selection's outline: a thin frame along the box's 12 edges in the style's holo look.
func _box_mesh(lo: Vector3i, hi: Vector3i) -> void:
	var mn := Vector3(lo) - Vector3.ONE * 0.02
	var mx := Vector3(hi + Vector3i.ONE) + Vector3.ONE * 0.02
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.05
	for ax: int in 3:
		var u := (ax + 1) % 3
		var v := (ax + 2) % 3
		for a: float in [mn[u], mx[u] - w]:
			for b: float in [mn[v], mx[v] - w]:
				var p := Vector3.ZERO
				var q := Vector3.ZERO
				p[ax] = mn[ax]
				q[ax] = mx[ax]
				p[u] = a
				q[u] = a + w
				p[v] = b
				q[v] = b + w
				_cube(st, p, q)
	box_ghost.mesh = st.commit()
	box_ghost.visible = true


static func _cube(st: SurfaceTool, p: Vector3, q: Vector3) -> void:
	var c := [Vector3(p.x, p.y, p.z), Vector3(q.x, p.y, p.z), Vector3(q.x, q.y, p.z), Vector3(p.x, q.y, p.z),
		Vector3(p.x, p.y, q.z), Vector3(q.x, p.y, q.z), Vector3(q.x, q.y, q.z), Vector3(p.x, q.y, q.z)]
	for f: Array in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5]]:
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(Vector2(0, 0))
			st.add_vertex(c[f[i]])


func _nodes() -> void:
	if preview == null or not is_instance_valid(preview):
		preview = PreviewMesh.new()
		host.add_child(preview)
		pghost = PieceGhost.new()
		host.add_child(pghost)
		box_ghost = MeshInstance3D.new()
		box_ghost.name = "StampBox"
		box_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		box_ghost.material_override = TLStyle.material("holo")
		host.add_child(box_ghost)


func _hide() -> void:
	if preview != null and is_instance_valid(preview):
		preview.visible = false
		pghost.hide_ghost()
		box_ghost.visible = false


func ghost_state() -> Dictionary:
	return {}


# ------------------------------------------------------------------ edits
func press(button: int, _mods: Dictionary) -> bool:
	var h: Dictionary = host.hit
	if button != MOUSE_BUTTON_LEFT or h.is_empty():
		return false
	if current < 0:
		var c := _corner_of(h)
		if corner_a == null or corner_b != null:
			corner_a = c
			corner_b = null
		else:
			corner_b = c
			top = _auto_top(corner_a, corner_b)
		return false
	place_at(h.place)
	return false


## Places the current stamp aimed at `cell` as one batch. Returns "" or why nothing was placed.
func place_at(cell: Vector3i) -> String:
	reason = check_at(cell)
	if reason != "":
		return reason
	var r: Dictionary = host.build.apply(ops_at(cell))
	reason = "" if bool(r.ok) else str(r.reason)
	_checked = ""
	if host.scripted():
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_edit", "frame": host.frames, "op": "stamp %s" % str(stamps[current].slug),
			"at": str(cell), "ok": bool(r.ok), "applied": int(r.applied), "reason": str(r.reason)}, "", false))
	return reason


## The highest cell with a block or a piece over the box's columns (at most SCAN_UP above its floor), or the corners'.
func _auto_top(a: Vector3i, b: Vector3i) -> int:
	var lo := Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z))
	var hi := Vector3i(maxi(a.x, b.x), lo.y + SCAN_UP, maxi(a.z, b.z))
	var t := maxi(a.y, b.y)
	var reg: Dictionary = host.build.read_region(lo, hi)
	for blk: Array in reg.get("blocks", []):
		t = maxi(t, int(blk[1]))
	var layer: RefCounted = host.build.layer("pieces")
	for p: Dictionary in reg.get("pieces", []):
		t = maxi(t, int((layer.pieces[Vector3i(int(p.at[0]), int(p.at[1]), int(p.at[2]))] as Dictionary).hi.y))
	return t


func drag(_h: Dictionary) -> void:
	pass


func release(_button: int) -> void:
	pass


func dragging() -> bool:
	return false


func tick(_frame: int) -> void:
	if naming() and not (name_bar.line as LineEdit).has_focus():
		(name_bar.line as LineEdit).grab_focus()     # a click in the world took the keyboard from the field: give it back
	if _latched and NAME_KEYS.all(func(k: int) -> bool: return not Input.is_physical_key_pressed(k)):
		_latched = false
	if preview != null and is_instance_valid(preview) and (not bool(host.get("active")) or host.call("tool") != self or bool(host.get("looking"))):
		_hide()
