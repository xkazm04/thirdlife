extends RefCounted
## M3 (spark world-sandbox, 26 Nov 2026): build mode's piece tool: kit parts put and lifted (`put` / `lift` ops,
## contracts/BUILD.md; the layer is pieces_layer.gd, the catalogue piece_catalog.gd; PIECES.md has the keys).
##   wheel        next / previous part of the catalogue      1-9   a part of the shown page   Tab / Shift+Tab page
##   [ ]          the part's knob (fence length, tree height, house width ...)            V   its choice (style, species ...)
##   R            turn (+1 quarter turn on top of facing the camera: a part's front, +z, looks back at the viewer)
##   LMB          put (one op, one batch)                    RMB   lift the piece under the cursor
## The ghost is the part's own meshes in holo where it would stand (red with the reason when refused, or when the part
## is locked: the hotbar says the condition); while RMB is held or Ctrl is down it shows the piece a lift would take.
## A locked part (unlocks.gd) shows "locked" in its slot and refuses with its condition. The tool interface is BUILD.md
## "Tools".

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Catalog := preload("res://kernel/world/build/piece_catalog.gd")
const Unlocks := preload("res://kernel/world/build/unlocks.gd")
const PieceGhost := preload("res://kernel/world/build/piece_ghost.gd")
const PAGE := 9
const RECHECK := 15                     # frames between refusal checks of an unchanged aim (the visitor moves)
const KEY_HELP := "LMB put   RMB lift   wheel or 1-9 part   Tab page   [ ] size   V kind   R turn   Ctrl+Z undo   Ctrl+Y redo   hold MMB or Alt look   T tool   B or Esc leave"

var id := "piece"
var title := "Pieces"
var host: Node = null                   # build_mode.gd
var part_index := 0
var params := {}                        # part -> its params as the person set them (trimmed)
var turn := 0
var reason := ""
var unlocks: RefCounted = null
var ghost: Node3D = null
var _aim := {}                          # {op, lift: bool, key, at_frame}
var _checked := ""                      # the aim key the reason belongs to
var _checked_at := -100


func setup(h: Node) -> void:
	host = h
	unlocks = Unlocks.new("")


func polled() -> Array:
	return [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_TAB, KEY_R, KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_V]


func part() -> String:
	return Catalog.PARTS[part_index]


func params_now() -> Dictionary:
	return params.get(part(), {})


func rot_now() -> int:
	return (HomeBuild.rot_facing(host.forward()) + turn) % 4


## Build mode on or off with this tool, or the tool picked: the unlocks are read again (a dungeon may have ended).
func selected(on: bool) -> void:
	reason = ""
	_aim = {}
	_checked = ""
	if on:
		turn = 0
		unlocks = Unlocks.new(str(host.get("dir")))
	_ghost_node().hide_ghost()


func _ghost_node() -> Node3D:
	if ghost == null or not is_instance_valid(ghost):
		ghost = PieceGhost.new()
		host.add_child(ghost)
	return ghost


func slots() -> Array:
	var out := []
	var page := part_index / PAGE
	for i: int in range(page * PAGE, mini(page * PAGE + PAGE, Catalog.PARTS.size())):
		var p: String = Catalog.PARTS[i]
		var label := p.replace("_", " ")
		if unlocks.locked("parts", p) != "":
			label += "\nlocked"
		out.append({"key": str(i - page * PAGE + 1), "label": label, "lit": i == part_index})
	return out


func status() -> Dictionary:
	var bits := PackedStringArray([part().replace("_", " ")])
	var knob: String = Catalog.knob_text(part(), params_now())
	if knob != "":
		bits.append(knob)
	if Catalog.CHOICES.has(part()):
		var c: Array = Catalog.CHOICES[part()]
		var v: Variant = params_now().get(c[0], Catalog.default_of(part(), c[0]))
		bits.append("%s %s" % [c[0], ("on" if v else "off") if v is bool else str(v).replace("_", " ")])
	bits.append("rot %d" % rot_now())
	var pages := ceili(float(Catalog.PARTS.size()) / PAGE)
	bits.append("page %d/%d" % [part_index / PAGE + 1, pages])
	return {"info": "   ".join(bits), "reason": reason}


func hint() -> String:
	return KEY_HELP


func blocks_input() -> bool:
	return false


func key(e: InputEvent) -> bool:
	var n: int = Catalog.PARTS.size()
	if e is InputEventMouseButton:
		var bi: int = (e as InputEventMouseButton).button_index
		if bi == MOUSE_BUTTON_WHEEL_UP or bi == MOUSE_BUTTON_WHEEL_DOWN:
			part_index = posmod(part_index + (1 if bi == MOUSE_BUTTON_WHEEL_DOWN else -1), n)
			_checked = ""
			return true
		return false
	var k := e as InputEventKey
	if k == null or not k.pressed:
		return false
	var code: int = k.physical_keycode
	if code >= KEY_1 and code <= KEY_9:
		var i: int = (part_index / PAGE) * PAGE + code - KEY_1
		if i < n:
			part_index = i
	elif code == KEY_TAB:
		var pages := ceili(float(n) / PAGE)
		part_index = mini(posmod(part_index / PAGE + (-1 if k.shift_pressed else 1), pages) * PAGE, n - 1)
	elif code == KEY_R:
		turn = (turn + 1) % 4
	elif code == KEY_BRACKETLEFT or code == KEY_BRACKETRIGHT:
		params[part()] = Catalog.turn_knob(part(), params_now(), -1 if code == KEY_BRACKETLEFT else 1)
	elif code == KEY_V:
		params[part()] = Catalog.next_choice(part(), params_now())
	else:
		return false
	_checked = ""
	return true


## The put op a click would make at `cell` now.
func op_at(cell: Vector3i) -> Dictionary:
	var op := {"op": "put", "at": [cell.x, cell.y, cell.z], "part": part(), "rot": rot_now()}
	if not params_now().is_empty():
		op["params"] = params_now().duplicate()
	return op


# ------------------------------------------------------------------ the cursor
func _pieces() -> RefCounted:
	return host.build.layer("pieces")


## The piece the cursor names for a lift: the one whose footprint holds the point just behind the surface hit.
func aimed_piece(h: Dictionary) -> Dictionary:
	if h.is_empty():
		return {}
	var n: Vector3 = (h.normal as Vector3).normalized()
	for d: float in [0.01, 0.3]:
		var r: Dictionary = _pieces().at_cell(Vector3i(((h.pos as Vector3) - n * d).floor()))
		if not r.is_empty():
			return r
	return {}


func aim(h: Dictionary, mode: Dictionary) -> void:
	var g := _ghost_node()
	if h.is_empty():
		_aim = {}
		reason = ""
		g.hide_ghost()
		return
	if bool(mode.get("rmb", false)) or bool(mode.get("ctrl", false)):
		var r := aimed_piece(h)
		_aim = {"lift": r}
		reason = "" if not r.is_empty() else "no piece there"
		if r.is_empty():
			g.hide_ghost()
		else:
			g.show_pieces([[r.proto, r.xf]], true, "lift %s" % str(r.at))
		return
	var op := op_at(h.place)
	var k := JSON.stringify(op)
	var frames: int = int(host.get("frames"))
	if k != _checked or frames - _checked_at >= RECHECK:
		_checked = k
		_checked_at = frames
		reason = unlocks.locked("parts", part())
		reason = "locked: " + reason if reason != "" else str(host.build.edits.validate(op))
		if reason == "":
			reason = str(_pieces().can_apply(op))
	_aim = {"op": op}
	var fp: Array = _pieces().footprint_of(op)
	if fp.is_empty():
		g.hide_ghost()
	else:
		g.show_pieces([[fp[3], fp[2]]], reason != "", k)


func ghost_state() -> Dictionary:
	return {}                                   # the shared block ghost stays hidden: this tool draws its own


# ------------------------------------------------------------------ edits
func press(button: int, _mods: Dictionary) -> bool:
	var h: Dictionary = host.hit
	if h.is_empty():
		return false
	var r: Dictionary
	var what := ""
	if button == MOUSE_BUTTON_LEFT:
		var locked: String = unlocks.locked("parts", part())
		if locked != "":
			reason = "locked: " + locked
			return false
		var op := op_at(h.place)
		r = host.build.apply(op)
		what = "put %s" % part()
	elif button == MOUSE_BUTTON_RIGHT:
		var p := aimed_piece(h)
		if p.is_empty():
			reason = "no piece there"
			return false
		r = host.build.apply({"op": "lift", "at": [p.at.x, p.at.y, p.at.z]})
		what = "lift %s" % str(p.part)
	else:
		return false
	reason = "" if bool(r.ok) else str(r.reason)
	_checked = ""
	if host.scripted():
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_edit", "frame": host.frames, "op": what,
			"at": str(h.place), "ok": bool(r.ok), "reason": str(r.reason)}, "", false))
	return false


func drag(_h: Dictionary) -> void:
	pass


func release(_button: int) -> void:
	pass


func dragging() -> bool:
	return false


func tick(_frame: int) -> void:
	if ghost != null and is_instance_valid(ghost) and (not bool(host.get("active")) or host.call("tool") != self or bool(host.get("looking"))):
		ghost.hide_ghost()
