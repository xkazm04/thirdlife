extends RefCounted
## M5 (spark world-sandbox, lane P): build mode's path tool. A person clicks points along the ground (LMB); a hologram
## ribbon follows the cursor from the last point; RMB, Enter or a click on the last point lays the path. The path and
## its grading are ONE batch (path_grade.gd `lay`: a path op, then a land op that levels the ground across it), so
## Ctrl+Z takes both back. The wheel or [ ] sets the width (1.5-8 m, half a metre a notch); 1-6 the paint (dirt, sand,
## stone, rock_warm, grass_dry, plank); 0 the remove slot: LMB on a path unpaths it (only there: an RMB meant to lay
## a draft whose points never took must not remove a path). Backspace drops the last point; leaving the tool or build
## mode drops the draft.
## Enter belongs to the host (it picks the command tool): while a path is being drawn this tool takes it in `tick`,
## before the host polls, and holds the keyboard (`blocks_input`) until the key is let go, so the host never sees it.
## A point is refused (red ghost, the reason in the hotbar) when it is more than 48 m from the last one or the ground
## to it is protected; one closer than 1 m to the last point finishes the path. Interface: BUILD.md "Tools".

const PathGrade := preload("res://kernel/world/build/path_grade.gd")
const PathShape := preload("res://kernel/world/build/path_shape.gd")
const PAINTS := ["dirt", "sand", "stone", "rock_warm", "grass_dry", "plank"]
const REMOVE := 6
const WIDTH_MIN := 150
const WIDTH_MAX := 800
const WIDTH_STEP := 50
const GAP_MAX := 48.0
const GAP_MIN := 1.0
const PTS_MAX := 64
const KEY_HELP := "LMB a point   RMB or Enter lay it   Backspace drop a point   1-6 paint   0 remove   wheel or [ ] width   Ctrl+Z undo   Ctrl+Y redo   hold MMB or Alt look   T tool   B or Esc leave"

var id := "path"
var title := "Paths"
var host: Node = null                    # build_mode.gd
var slot := 0                            # PAINTS index, or REMOVE
var width_cm := 300
var pts: Array = []                      # Vector2 (metres, whole cm): the draft's points
var reason := ""
var last := {}                           # the last lay: path_grade.gd `lay`'s result (the case and the exe read it)
var _cursor: Variant = null              # where the cursor meets the ground (Vector3), or null
var _cursor_ok := ""                     # why a point at the cursor is refused ("" = it may go there)
var _ghost: Node3D = null
var _ghost_key := ""
var _ask_key := ""
var _ask_why := ""
var _enter_was := false
var _enter_hold := false


func setup(h: Node) -> void:
	host = h


func layer() -> RefCounted:
	return host.build.layer("paths") if host != null and host.build != null else null


func polled() -> Array:
	return [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_0, KEY_BACKSPACE, KEY_BRACKETLEFT, KEY_BRACKETRIGHT]


func selected(on: bool) -> void:
	pts.clear()
	reason = ""
	_enter_hold = false
	if not on:
		_show(null)


func slots() -> Array:
	var out := []
	for i: int in PAINTS.size():
		out.append({"key": str(i + 1), "label": PAINTS[i].replace("_", " "), "lit": i == slot})
	out.append({"key": "0", "label": "remove", "lit": slot == REMOVE})
	return out


func paint() -> String:
	return PAINTS[slot] if slot < PAINTS.size() else ""


func status() -> Dictionary:
	var st := {"reason": reason if reason != "" else _cursor_ok}
	if slot == REMOVE:
		st["info"] = "remove: LMB on a path"
		return st
	var key := paint()
	st["swatch"] = TLStyle.color(key)
	var n := pts.size()
	st["info"] = "%s   %.1f m wide   %s" % [key.replace("_", " "), width_cm / 100.0,
		"LMB the first point" if n == 0 else ("%d point%s   RMB or Enter lays it" % [n, "" if n == 1 else "s"])]
	return st


func hint() -> String:
	return KEY_HELP


func blocks_input() -> bool:
	return _enter_hold


func key(e: InputEvent) -> bool:
	if e is InputEventMouseButton:
		var bi: int = (e as InputEventMouseButton).button_index
		if bi == MOUSE_BUTTON_WHEEL_UP or bi == MOUSE_BUTTON_WHEEL_DOWN:
			width_cm = clampi(width_cm + (WIDTH_STEP if bi == MOUSE_BUTTON_WHEEL_UP else -WIDTH_STEP), WIDTH_MIN, WIDTH_MAX)
			return true
		return false
	var k := e as InputEventKey
	if k == null or not k.pressed:
		return false
	var code: int = k.physical_keycode
	if code >= KEY_1 and code <= KEY_6:
		slot = code - KEY_1
		reason = ""
		return true
	if code == KEY_0:
		slot = REMOVE
		pts.clear()
		reason = ""
		return true
	if code == KEY_BRACKETLEFT or code == KEY_BRACKETRIGHT:
		width_cm = clampi(width_cm + (WIDTH_STEP if code == KEY_BRACKETRIGHT else -WIDTH_STEP), WIDTH_MIN, WIDTH_MAX)
		return true
	if code == KEY_BACKSPACE:
		if not pts.is_empty():
			pts.pop_back()
			reason = ""
		return true
	return false


# ------------------------------------------------------------------ the cursor and the ghost
func aim(h: Dictionary, _mode: Dictionary) -> void:
	_cursor = h.get("pos")
	_cursor_ok = ""
	if _cursor == null:
		_show(null)
		return
	var q := _snap(_cursor)
	var l := layer()
	if slot == REMOVE:
		var n: int = l.path_at(q.x, q.y) if l != null else 0
		_show(["remove", n], func() -> Node3D: return l.ghost_of(l.paths[n], true) if n > 0 else null)
		return
	var ask := "%s|%d|%s" % [str(pts.back() if not pts.is_empty() else null), width_cm, str((q * 4.0).round())]
	if ask != _ask_key:                  # asked again only when the cursor moved a quarter metre (or the draft changed)
		_ask_key = ask
		_ask_why = _point_refusal(q)
	_cursor_ok = _ask_why
	var draft := pts.duplicate()
	if draft.is_empty() or (draft[draft.size() - 1] as Vector2).distance_to(q) >= GAP_MIN:
		draft.append(q)
	if draft.size() == 1:                    # a short piece across the cursor shows the width
		var f: Vector3 = host.forward()
		var a := Vector2(f.x, f.z).normalized() * 0.6
		draft = [q - a, q + a]
	var ws := float(width_cm) / 200.0
	var key := "%s|%d|%d|%s|%s" % [str(pts), width_cm, slot, str((q * 4.0).round()), _cursor_ok]
	var red := _cursor_ok != ""
	_show([key], func() -> Node3D: return _ghost_ribbon(draft, ws, red))


func _ghost_ribbon(draft: Array, h: float, red: bool) -> Node3D:
	var l := layer()
	if l == null:
		return null
	var cm := []
	for q: Vector2 in draft:
		cm.append([roundi(q.x * 100.0), roundi(q.y * 100.0)])
	var sm := PathShape.sample(cm)
	return l._mesher().ghost(sm.p, h, red, "PathToolGhost")


## The ghost shown now is the one `make` draws for `key` (made again only when the key changes); null key: none.
func _show(key: Variant, make := Callable()) -> void:
	var k := str(key)
	if key == null:
		k = ""
	if k == _ghost_key and (k == "" or _ghost != null):
		return
	_ghost_key = k
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	if key == null or not make.is_valid():
		return
	var n: Variant = make.call()
	if n is Node3D and host != null:
		_ghost = n
		host.add_child(_ghost)


func ghost_node() -> Node3D:
	return _ghost


func ghost_state() -> Dictionary:
	return {}


static func _snap(p: Vector3) -> Vector2:
	return Vector2(roundf(p.x * 100.0) / 100.0, roundf(p.z * 100.0) / 100.0)


## Why a next point at `q` is refused: too far from the last point, or the ground on the way there protected.
func _point_refusal(q: Vector2) -> String:
	var l := layer()
	if l == null:
		return ""
	if pts.is_empty():
		return str(l.refusal_of({"pts": [_cm(q), _cm(q + Vector2(1.0, 0.0))], "width_cm": width_cm}))
	var a: Vector2 = pts[pts.size() - 1]
	var d := a.distance_to(q)
	if d > GAP_MAX:
		return "points are at most %d m apart (%d m)" % [int(GAP_MAX), int(d)]
	if d < GAP_MIN:
		return ""
	return str(l.refusal_of({"pts": [_cm(a), _cm(q)], "width_cm": width_cm}))


static func _cm(q: Vector2) -> Array:
	return [roundi(q.x * 100.0), roundi(q.y * 100.0)]


# ------------------------------------------------------------------ buttons
func press(button: int, _mods: Dictionary) -> bool:
	if not host.hit.has("pos"):
		return false
	var q := _snap(host.hit.pos)
	var l := layer()
	if button == MOUSE_BUTTON_RIGHT:
		if not pts.is_empty():
			finish()
		return false
	if button != MOUSE_BUTTON_LEFT:
		return false
	if slot == REMOVE:
		_unpath(l.path_at(q.x, q.y) if l != null else 0)
		return false
	if not pts.is_empty() and (pts[pts.size() - 1] as Vector2).distance_to(q) < GAP_MIN:
		finish()
		return false
	var why := _point_refusal(q)
	if why != "":
		reason = why
		return false
	reason = ""
	pts.append(q)
	if pts.size() >= PTS_MAX:
		finish()
	return false


## Lays the draft (two points or more; one point is dropped) with its grading: one batch.
func finish() -> void:
	if pts.size() < 2:
		pts.clear()
		return
	var l := layer()
	var cm := []
	for q: Vector2 in pts:
		cm.append(_cm(q))
	pts.clear()
	var op := {"op": "path", "id": l.next_id(), "pts": cm, "width_cm": width_cm, "paint": paint(), "author": "hand"}
	var why: String = l.malformed(op)
	if why != "":
		reason = why
		return
	last = PathGrade.lay(host.build, op)
	reason = "" if bool(last.ok) else str(last.reason)
	_ghost_key = "-"
	if host.scripted():
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_edit", "frame": host.frames, "op": "path", "id": int(op.id),
			"pts": cm.size(), "width_cm": width_cm, "paint": op.paint, "graded": int(last.graded), "skipped": int(last.skipped), "skip_reason": str(last.skip_reason),
			"usec": int(last.usec), "ok": bool(last.ok), "reason": str(last.reason)}, "", false))


func _unpath(n: int) -> void:
	var l := layer()
	if l == null or n <= 0:
		reason = "no path here"
		return
	var rec: Dictionary = (l.paths[n] as Dictionary).duplicate(true)
	rec["op"] = "unpath"
	rec["author"] = "hand"
	var r: Dictionary = host.build.apply(rec)
	reason = "" if bool(r.ok) else str(r.reason)
	_ghost_key = "-"
	if host.scripted():
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_edit", "frame": host.frames, "op": "unpath", "id": n,
			"ok": bool(r.ok), "reason": str(r.reason)}, "", false))


func drag(_h: Dictionary) -> void:
	pass


func release(_button: int) -> void:
	pass


func dragging() -> bool:
	return false


## Every physics frame, before the host polls: Enter lays the draft while one is drawn (the host would pick the
## command tool), and the keyboard is held until Enter is let go.
func tick(_frame: int) -> void:
	var down := Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER)
	var mine: bool = host != null and bool(host.get("active")) and host.call("tool") == self
	if down and not _enter_was and mine and not pts.is_empty():
		finish()
		_enter_hold = true
	if not down:
		_enter_hold = false
	_enter_was = down
