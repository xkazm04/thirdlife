extends RefCounted
## M6 lane T (27 Nov 2026): build mode's Rules tool (after plants, before command; contracts/BUILD.md "Milestone 6",
## the tool interface BUILD.md "Tools"). The hand makes what the LLM can: a zone and its rules from a preset, ONE batch
## (one undo) each (rules_tool_presets.gd). Two ways, both a person finds without a manual:
##   preset first   1-8 arms a preset (the slot lights): every click places one on the cell under the cursor, a drag
##                  places one over the dragged box (the coin trail: 4, click, click, click). The same key again, or
##                  0, stops it. While armed the ghost is the preset where it would go (rules_layer.gd `preview_node`
##                  over `build.preview`), red with the reason when it would be refused
##   box first      with nothing armed, LMB drag (or click) a box on the ground, the wheel raises its top, then 1-8
##                  writes that preset on it
## 1 Start, 2 Checkpoint, 3 Finish, 4 Coin, 5 Door (drawn on the door's blocks; grown one cell through the wall so E
## opens it from either side), 6 Jump pad, 7 Hazard, 8 Message. The first Start asks the run's name in a field
## (command_bar.gd, as the stamp name: "Run 1" selected, Enter places, Esc places nothing); a Message asks its text.
## Edit: with nothing armed, a click on a zone selects it (yellow); the side card (rules_tool_card.gd) lists its rules
## as sentences (`describe`) and its knobs: [ ] the first (coin value, door seconds, pad up, message seconds), Shift+[ ]
## the second (pad forward), G the text (run name, message text); Delete or Backspace removes the zone and every rule
## that names it (one batch). Zones show in build mode in every tool (zone_draw.gd), never in play.
## Keys: 0-8, [ ], G, Delete, Backspace, the wheel and LMB; none of the host's (B, Esc, T, Enter, Ctrl+Z / Y), not E.

const Presets := preload("res://kernel/world/build/rules_tool_presets.gd")
const ZoneDraw := preload("res://kernel/world/build/zone_draw.gd")
const Card := preload("res://kernel/world/build/rules_tool_card.gd")
const Bar := preload("res://kernel/world/build/command_bar.gd")
const Check := preload("res://kernel/world/build/rules_check.gd")
const NAME_KEYS := [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]
const STEADY := 4                       # frames the aim stays on one cell before the dry run is asked
const KEY_HELP := "1-8 preset: click or drag   or drag a box, then 1-8   wheel top   click a zone: edit   [ ] knob   G text   Del remove   0 stop   T tool   B leave"

var id := "rules"
var title := "Rules"
var host: Node = null                   # build_mode.gd
var armed := ""                         # a preset kind armed (Presets.KINDS), "" none
var corner_a: Variant = null            # {"place", "remove", "normal"} of the press, or null
var corner_b: Variant = null
var has_box := false                    # a box is drawn and waits for a preset
var top_extra := 0                      # cells the wheel raised the box's top
var chosen := -1                        # the chosen zone's id, -1 none
var hover := -1                         # the zone under the cursor (nothing armed)
var reason := ""
var note := ""
var drawer: Node3D = null               # zone_draw.gd
var card: CanvasLayer = null            # rules_tool_card.gd
var ghost_root: Node3D = null
var name_bar: CanvasLayer = null        # command_bar.gd: the run's name, a message's text
var ask := {}                           # what the field's text is for: {"field": "run"|"text"|"knob", ...}
var placed := 0                         # presets placed (figures)
var _dragging := false
var _latched := false                   # Enter or Esc closed the field and is still held (see stamp_tool.gd)
var _ghost_key := ""
var _aim_key := ""
var _steady := 0


func setup(h: Node) -> void:
	host = h


func polled() -> Array:
	return [KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_G,
		KEY_DELETE, KEY_BACKSPACE]


func layer() -> RefCounted:
	return host.build.layer("rules") if host != null and host.build != null else null


func selected(on: bool) -> void:
	reason = ""
	if not on and naming():
		name_bar.close()
		ask = {}
	_dragging = false
	_clear_ghost()


func slots() -> Array:
	var out := [{"key": "0", "label": "box", "lit": armed == ""}]
	for i: int in Presets.KINDS.size():
		var k: String = Presets.KINDS[i]
		out.append({"key": str(i + 1), "label": Presets.TITLES[k], "lit": armed == k})
	return out


func status() -> Dictionary:
	var info := ""
	var l := layer()
	if naming():
		info = "type, then Enter"
	elif armed != "":
		info = "%s: click or drag to place   (%s again or 0: stop)" % [Presets.TITLES[armed], str(Presets.KINDS.find(armed) + 1)]
		if top_extra > 0:
			info += "   top +%d (wheel)" % top_extra
	elif has_box or _dragging:
		var b := box_of("")
		var s: Vector3i = b[1] - b[0] + Vector3i.ONE
		info = "box %d x %d x %d   wheel top   1-8 make it a preset" % [s.x, s.y, s.z]
	elif chosen >= 0 and l != null and (l.zones as Dictionary).has(chosen):
		info = "%s selected   %d rules   Del remove" % [_zname(chosen), Presets.rules_naming(l, chosen).size()]
	elif hover >= 0 and l != null and (l.zones as Dictionary).has(hover):
		info = "click: edit %s" % _zname(hover)
	else:
		info = "pick a preset 1-8, or drag a box on the ground"
	if note != "":
		info += "   (%s)" % note
	return {"info": info, "reason": reason}


func hint() -> String:
	return "Enter place   Esc cancel" if naming() else KEY_HELP


## True while the field has the keyboard, and until the key that closed it is let go.
func blocks_input() -> bool:
	return naming() or _latched


func naming() -> bool:
	return name_bar != null and is_instance_valid(name_bar) and name_bar.is_open()


func _zname(zid: int) -> String:
	var z: Dictionary = layer().zones.get(zid, {})
	return str(z.get("name", "zone %d" % zid))


# ------------------------------------------------------------------ keys
func key(e: InputEvent) -> bool:
	if e is InputEventMouseButton:
		var bi: int = (e as InputEventMouseButton).button_index
		if bi != MOUSE_BUTTON_WHEEL_UP and bi != MOUSE_BUTTON_WHEEL_DOWN:
			return false
		top_extra = clampi(top_extra + (1 if bi == MOUSE_BUTTON_WHEEL_UP else -1), 0, Check.SIDE_MAX - 1)
		_ghost_key = ""
		return true
	var k := e as InputEventKey
	if k == null or not k.pressed:
		return false
	var code: int = k.physical_keycode
	note = ""
	reason = ""
	if code >= KEY_1 and code <= KEY_8:
		var kind: String = Presets.KINDS[code - KEY_1]
		if has_box:
			var b := box_of(kind)
			place(kind, b[0], b[1])
		else:
			armed = "" if armed == kind else kind
			chosen = -1
	elif code == KEY_0:
		armed = ""
		has_box = false
		corner_a = null
		corner_b = null
		chosen = -1
		top_extra = 0
	elif code == KEY_DELETE or code == KEY_BACKSPACE:
		if chosen >= 0:
			remove_zone(chosen)
		elif has_box:
			has_box = false
	elif code == KEY_BRACKETLEFT or code == KEY_BRACKETRIGHT:
		turn_knob(1 if k.shift_pressed else 0, 1 if code == KEY_BRACKETRIGHT else -1)
	elif code == KEY_G:
		edit_text()
	else:
		return false
	_ghost_key = ""
	return true


# ------------------------------------------------------------------ the box
func _corner(h: Dictionary) -> Dictionary:
	var place: Vector3i = h.place
	var rm: Vector3i = h.remove if bool(h.get("block", false)) and h.get("remove") != null and h.remove.y > -32768 else place
	return {"place": place, "remove": rm, "normal": h.get("normal", Vector3.UP)}


## The box [lo, hi] the corners and the wheel make for preset `kind` (a door takes the blocks clicked, the others the
## cells in front of them); [] while there is no corner.
func box_of(kind: String) -> Array:
	if corner_a == null:
		return []
	var which := "remove" if kind == "door" else "place"
	var a: Vector3i = corner_a[which]
	var b: Vector3i = (corner_b if corner_b != null else corner_a)[which]
	var lo := Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z))
	var hi := Vector3i(maxi(a.x, b.x), maxi(a.y, b.y), maxi(a.z, b.z))
	hi.y = mini(hi.y + top_extra, lo.y + Check.SIDE_MAX - 1)
	return [lo, hi]


## The axis a door is thin along (the face clicked: 0 x, 2 z), -1 when the click was on a top or a bottom.
func _thin() -> int:
	var n: Vector3 = (corner_a as Dictionary).get("normal", Vector3.UP) if corner_a != null else Vector3.UP
	var a := n.abs()
	if a.y >= a.x and a.y >= a.z:
		return -1
	return 0 if a.x >= a.z else 2


func press(button: int, _mods: Dictionary) -> bool:
	var h: Dictionary = host.hit
	if button != MOUSE_BUTTON_LEFT or h.is_empty() or naming():
		return false
	reason = ""
	note = ""
	if armed == "":
		var zid := zone_under(h)
		if zid >= 0:
			chosen = zid
			has_box = false
			corner_a = null
			return false
		chosen = -1
	corner_a = _corner(h)
	corner_b = corner_a
	has_box = false
	if armed == "":
		top_extra = 0
	_dragging = true
	_ghost_key = ""
	return true


func drag(h: Dictionary) -> void:
	if _dragging and not h.is_empty():
		corner_b = _corner(h)


## The button went up (a drag ends: an armed preset is placed over the box, else the box waits for 1-8), or the hold
## was cut (undo, look, leave, a tool switch: the button still down): nothing is placed.
func release(_button: int) -> void:
	if not _dragging:
		return
	_dragging = false
	_ghost_key = ""
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		corner_a = null
		return
	if armed != "":
		var b := box_of(armed)
		place(armed, b[0], b[1])
	else:
		has_box = true


func dragging() -> bool:
	return _dragging


## The zone the cursor's hit is in (the cell in front, or the block hit), the last one listed; -1 none.
func zone_under(h: Dictionary) -> int:
	var l := layer()
	if l == null or h.is_empty():
		return -1
	var c := _corner(h)
	for cell: Vector3i in [c.remove, c.place]:
		var ids: Array = l.zones_at(cell)
		if not ids.is_empty():
			return int(ids[ids.size() - 1])
	return -1


# ------------------------------------------------------------------ edits (each one batch)
## Places preset `kind` on lo..hi: the run's name or the message's text is asked first when needed. Returns "" or why
## nothing was placed ("asked": the field is open).
func place(kind: String, lo: Vector3i, hi: Vector3i, opt := {}) -> String:
	var l := layer()
	if l == null:
		return "no Home"
	var o := opt.duplicate()
	if kind == "start" and not o.has("run"):
		var run := Presets.run_name(l)
		if run == "":
			open_field({"field": "run", "kind": kind, "lo": lo, "hi": hi}, "Name the run (the clock, the best time)   Enter place   Esc cancel", Presets.RUN, Check.NAME_MAX)
			return "asked"
		o["run"] = run
	if kind == "message" and not o.has("text"):
		open_field({"field": "text", "kind": kind, "lo": lo, "hi": hi}, "What should it say?   Enter place   Esc cancel", Presets.TEXT, Check.TEXT_MAX)
		return "asked"
	if kind == "door":
		o["thin"] = _thin()
	if top_extra > 0:
		o["exact"] = true
	o["stand"] = Callable(self, "stand_at")   # F2: the box fitted to the ground he stands on
	var ops := Presets.ops(l, kind, lo, hi, o)
	var why := _write(ops, "%s refused" % Presets.TITLES[kind])
	if why == "":
		placed += 1
		chosen = int(ops[0].id)
		note = "placed %s" % str(ops[0].name)
		has_box = false
		corner_a = null
		corner_b = null
	_log("preset %s" % kind, ops, why)
	return why


## F2: the height a person's feet stand at, at (x, z), for a preset box whose cells are `lo_y`..`hi_y`
## (rules_tool_presets.gd `fit_ground`): NAN when a block fills that column inside the box (a wall, the door's own
## blocks: nobody stands there); else the top of the highest block in the two cells under the box, or the ground's
## drawn height (what the walker's collider is), whichever is higher. Read only.
func stand_at(x: float, z: float, lo_y: int, hi_y: int) -> float:
	var b: RefCounted = host.build if host != null else null
	if b == null:
		return NAN
	var cx := floori(x)
	var cz := floori(z)
	for y: int in range(lo_y, hi_y + 1):
		if b.blocks.get_code(Vector3i(cx, y, cz)) != 0:
			return NAN
	var h := -INF
	var land: RefCounted = b.layer("land")
	if land != null:
		h = float(land.drawn_height_at(x, z))
	for y: int in [lo_y - 1, lo_y - 2]:
		if b.blocks.get_code(Vector3i(cx, y, cz)) != 0:
			h = maxf(h, float(y + 1))
			break
	return h if h > -INF else NAN


## Removes zone `zid` and the rules that name it. Returns "" or why not.
func remove_zone(zid: int) -> String:
	var l := layer()
	var ops := Presets.delete_ops(l, zid)
	if ops.is_empty():
		chosen = -1
		return "no zone %d" % zid
	var nm := _zname(zid)
	var why := _write(ops, "not removed")
	if why == "":
		note = "removed %s and %d rules" % [nm, ops.size() - 1]
		chosen = -1
	_log("remove %d" % zid, ops, why)
	return why


## Knob `which` (0: [ ], 1: Shift+[ ]) of the chosen zone one step `dir` (+1 / -1). Returns "" or why not.
func turn_knob(which: int, dir: int) -> String:
	if chosen < 0:
		return ""
	var nums := Presets.knobs(layer(), chosen).filter(func(k: Dictionary) -> bool: return not k.has("text"))
	if which >= nums.size():
		return ""
	var kb: Dictionary = nums[which]
	var v := clampi(int(kb.value) + dir * int(kb.step), int(kb.min), int(kb.max))
	if v == int(kb.value):
		return ""
	return set_knob(chosen, str(kb.name), v)


func set_knob(zid: int, nm: String, value: Variant) -> String:
	var ops := Presets.knob_ops(layer(), zid, nm, value)
	if ops.is_empty():
		reason = "%s has no %s" % [_zname(zid), nm]
		return reason
	var why := _write(ops, "not changed")
	if why == "":
		note = "%s: %s" % [_zname(zid), _shown(nm, value)]
	_log("knob %d %s" % [zid, nm], ops, why)
	return why


## G: the chosen zone's text knob (a Start's run name, a Message's text) in the field.
func edit_text() -> void:
	if chosen < 0:
		return
	for kb: Dictionary in Presets.knobs(layer(), chosen):
		if kb.has("text"):
			var most := Check.NAME_MAX if str(kb.name) == "run" else Check.TEXT_MAX
			open_field({"field": "knob", "zid": chosen, "name": str(kb.name)}, "%s of %s   Enter keep   Esc cancel" % [str(kb.label), _zname(chosen)], str(kb.value), most)
			return


static func _shown(nm: String, v: Variant) -> String:
	if nm.ends_with("_cm"):
		return "%s %s m/s" % [nm.trim_suffix("_cm").replace("fwd", "forward"), str(int(v) / 100.0)]
	if nm == "frames":
		return "shown %d s" % (int(v) / 60)
	return "%s %s" % [nm, str(v)]


## Dry run first: a preset is placed whole or not at all.
func _write(ops: Array, what: String) -> String:
	var r: Dictionary = host.build.preview(ops)
	if not bool(r.ok):
		reason = "%s: %s" % [what, str(r.reason)]
		return reason
	var a: Dictionary = host.build.apply(ops)
	reason = "" if bool(a.ok) else "%s: %s" % [what, str(a.reason)]
	_ghost_key = ""
	return reason


func _log(what: String, ops: Array, why: String) -> void:
	if host.scripted():
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_edit", "frame": host.frames, "op": "rules %s" % what,
			"ops": ops.size(), "ok": why == "", "reason": why}, "", false))


# ------------------------------------------------------------------ the field
func open_field(a: Dictionary, head: String, text: String, most: int) -> void:
	if name_bar == null or not is_instance_valid(name_bar):
		name_bar = Bar.new()
		name_bar.name = "RulesText"
		host.add_child(name_bar)
		name_bar.submitted.connect(_on_text)
		name_bar.cancelled.connect(func() -> void:
			name_bar.close()
			_latched = true
			ask = {}
			note = "nothing placed")
	ask = a
	name_bar.open(head, text, most, text)


func _on_text(text: String) -> void:
	name_bar.close()
	_latched = true
	var a := ask
	ask = {}
	var t := ""
	for ch: String in text.replace("\n", " ").strip_edges():
		if Check.printable(ch, 1):
			t += ch
	match str(a.get("field", "")):
		"run":
			place(str(a.kind), a.lo, a.hi, {"run": (t if t != "" else Presets.RUN).left(Check.NAME_MAX)})
		"text":
			place(str(a.kind), a.lo, a.hi, {"text": (t if t != "" else Presets.TEXT).left(Check.TEXT_MAX)})
		"knob":
			if t != "":
				set_knob(int(a.zid), str(a.name), t.left(Check.NAME_MAX if str(a.name) == "run" else Check.TEXT_MAX))


# ------------------------------------------------------------------ the cursor, the ghost, the card
func aim(h: Dictionary, _mode: Dictionary) -> void:
	hover = zone_under(h) if armed == "" and not _dragging else -1
	var k := ""
	if _dragging or has_box:
		var b := box_of(armed if armed != "" else "")
		k = "box|%s|%s|%s" % [armed, str(b), str(chosen)]
	elif armed != "" and not h.is_empty():
		k = "arm|%s|%s|%s|%d" % [armed, str(h.place), str(h.remove), top_extra]
	if k != _aim_key:
		_aim_key = k
		_steady = 0
	_steady += 1
	if k == "":
		_clear_ghost()
		return
	if k == _ghost_key or (_steady < STEADY and not k.begins_with("box")):
		return
	_ghost_key = k
	if armed == "":
		var b := box_of("")
		_show_ghost(ZoneDraw.zone_node({"id": 0, "box": [[b[0].x, b[0].y, b[0].z], [b[1].x, b[1].y, b[1].z]], "look": "none", "name": "new box"}, "holo"))
		return
	if not _dragging:
		corner_a = _corner(h)
		corner_b = corner_a
	_show_ghost(ghost_of(armed))


## The armed preset's ghost over the current box: what it would add, in holo, or the zone in red with the reason.
func ghost_of(kind: String) -> Node3D:
	var l := layer()
	var b := box_of(kind)
	var o := {"run": Presets.run_name(l) if Presets.run_name(l) != "" else Presets.RUN, "text": Presets.TEXT}
	if kind == "door":
		o["thin"] = _thin()
	if top_extra > 0:
		o["exact"] = true
	o["stand"] = Callable(self, "stand_at")   # F2: the box fitted to the ground he stands on
	var ops := Presets.ops(l, kind, b[0], b[1], o)
	var r: Dictionary = host.build.preview(ops)
	if not bool(r.ok):
		reason = "%s refused: %s" % [Presets.TITLES[kind], str(r.reason)]
		var z := Check.zone_of(ops[0])
		return ZoneDraw.zone_node(z, "red")
	reason = ""
	return l.preview_node((r.scratch as Dictionary).get("rules"))


func _show_ghost(n: Node3D) -> void:
	_clear_ghost()
	if n == null:
		return
	if ghost_root == null or not is_instance_valid(ghost_root):
		ghost_root = Node3D.new()
		ghost_root.name = "RulesGhost"
		host.add_child(ghost_root)
	ghost_root.add_child(n)
	ghost_root.visible = true


func _clear_ghost() -> void:
	if ghost_root != null and is_instance_valid(ghost_root):
		for c: Node in ghost_root.get_children():
			ghost_root.remove_child(c)
			c.queue_free()
	_ghost_key = ""


## The ghost's nodes now (the case reads them).
func ghost_nodes() -> Array:
	return ghost_root.get_children() if ghost_root != null and is_instance_valid(ghost_root) else []


func ghost_state() -> Dictionary:
	return {}


## The side card's content now: the chosen zone (its rules as sentences, its knobs) or the Home's rules.
func card_of() -> Dictionary:
	var l := layer()
	if l == null:
		return {}
	if chosen >= 0 and not (l.zones as Dictionary).has(chosen):
		chosen = -1
	if chosen >= 0:
		var kind := Presets.kind_of(l, chosen)
		var lines := []
		for r: Dictionary in Presets.rules_naming(l, chosen):
			lines.append(l.describe(int(r.id)))
		var keys := []
		var nums := 0
		for kb: Dictionary in Presets.knobs(l, chosen):
			if kb.has("text"):
				keys.append("G  %s: %s" % [str(kb.label), str(kb.value)])
			else:
				var v := str(int(kb.value) / 100.0) if str(kb.name).ends_with("_cm") else (str(int(kb.value) / 60) if str(kb.name) == "frames" else str(kb.value))
				keys.append("%s  %s: %s" % ["[ ]" if nums == 0 else "Shift+[ ]", str(kb.label), v])
				nums += 1
		keys.append("Del  remove it and its %d rules" % lines.size())
		return {"title": "%s   (%s)" % [_zname(chosen), Presets.TITLES.get(kind, "Zone")], "lines": lines, "keys": "\n".join(keys)}
	var all := []
	var ids: Array = (l.rules as Dictionary).keys()
	ids.sort()
	for rid: int in ids:
		if all.size() >= Card.LINES:
			all.append("and %d more" % (ids.size() - Card.LINES))
			break
		all.append(l.describe(rid))
	var run := Presets.run_name(l)
	return {"title": "Rules: %d zones, %d rules%s" % [(l.zones as Dictionary).size(), ids.size(), "" if run == "" else "   run: " + run],
		"lines": all, "keys": "1-8 a preset, then click or drag; or drag a box, then 1-8.\nClick a zone to see and change it."}


func tick(_frame: int) -> void:
	if naming() and not (name_bar.line as LineEdit).has_focus():
		(name_bar.line as LineEdit).grab_focus()
	if _latched and NAME_KEYS.all(func(k: int) -> bool: return not Input.is_physical_key_pressed(k)):
		_latched = false
	if host == null or not host.is_inside_tree() or layer() == null:
		return
	var building := bool(host.get("active"))
	var current: bool = building and host.call("tool") == self
	if drawer == null or not is_instance_valid(drawer):
		drawer = ZoneDraw.new()
		host.add_child(drawer)
		card = Card.new()
		host.add_child(card)
	drawer.visible = building
	if building:
		drawer.sync(layer(), chosen if current else -1)
	card.show_card(card_of() if current and not bool(host.get("looking")) else {})
	if ghost_root != null and is_instance_valid(ghost_root):
		ghost_root.visible = current and not bool(host.get("looking"))
