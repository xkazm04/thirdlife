extends RefCounted
## M4 (spark world-sandbox): build mode's command tool, the LLM command bar (contracts/BUILD.md "The LLM command bar";
## kernel/world/build/COMMAND.md). Enter opens a text field (command_bar.gd); the person types a sentence and Enter
## sends it: the ask (command_ask.gd, tl.world-edit-ask/1) is written beside the Home and `foreman world-edit` is
## started (command_link.gd). Asking never blocks: a pending marker (command_marker.gd) stands at the spot with
## "thinking... 0:23", the person keeps building with the other tools, and at most MAX_PENDING asks wait at once. The
## answer (command_answer.gd, tl.world-edit/1) is shown as a ghost (home_build.gd `preview`, preview_mesh.gd) with its
## note and its counts ("212 blocks, 6 refused: game lot"); while it is shown the tool has the keyboard: Enter keeps it
## (ONE batch, author "llm", so one Ctrl+Z takes it all back; the counts are recomputed then, as the world may have
## changed), Esc or Backspace reverts it. Without a connected model the bar says why and does nothing. Every call is
## logged with the day's cap (command_calls.gd). The test hook TL_COMMAND_DEVICES is command_devices.gd.
## M5 (lane C): the ask lists only what play has unlocked (unlocks.gd); an answer that still names a locked material,
## shape or part has those ops refused "locked: <condition>" when it is shown, and again at accept, and the rest is
## applied. Every layer draws its part of the ghost (home_build.gd `preview_nodes`), and the note counts every kind.
## M6 (lane C): the ask carries the zones, rules and room (command_ask.gd); the note counts zones and rules and names
## the runs ("4 zones, 6 rules: Tower climb"); before accept the space check (command_space.gd) marks the problem cells
## in the ghost in red and adds its line to the note ("check: 2 blocks float; finish not reachable"). It never refuses.

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Ask := preload("res://kernel/world/build/command_ask.gd")
const Answer := preload("res://kernel/world/build/command_answer.gd")
const Calls := preload("res://kernel/world/build/command_calls.gd")
const Link := preload("res://kernel/world/build/command_link.gd")
const Bar := preload("res://kernel/world/build/command_bar.gd")
const Marker := preload("res://kernel/world/build/command_marker.gd")
const PreviewMesh := preload("res://kernel/world/build/preview_mesh.gd")
const Devices := preload("res://kernel/world/build/command_devices.gd")
const Unlocks := preload("res://kernel/world/build/unlocks.gd")
const Space := preload("res://kernel/world/build/command_space.gd")
const LOCKED_AT := -100000              # refused indices below this are locked ops of the expanded answer
const KEY_HELP := "T next tool   Shift+T previous tool   Ctrl+Z undo   Ctrl+Y redo   hold MMB or Alt look   B or Esc leave"
const MAX_PENDING := 2
const POLL_EVERY := 15                  # physics frames between looks at an answer file
const SAY_FRAMES := 600                 # how long a message stays in the info line
const FACING := ["north", "west", "south", "east"]

var id := "command"
var title := "Command"
var host: Node = null                   # build_mode.gd
var link: RefCounted = null             # command_link.gd (made on the first Enter)
var calls: RefCounted = null            # command_calls.gd
var bar: CanvasLayer = null
var preview: Node3D = null              # the blocks' ghost (preview_mesh.gd)
var layer_ghosts: Node3D = null         # every other layer's ghost (home_build.gd `preview_nodes`), under one node
var space_marks: Node3D = null          # M6: the space check's marks over the problem cells (command_space.gd)
var devices: RefCounted = null
var pending: Array = []                 # asks waiting: {id, sentence, cell, facing, ask, out, frame0, marker, rec}
var ready: Array = []                   # answers that came, waiting to be shown (the oldest first)
var shown := {}                         # the answer shown as a ghost (the call plus ops, preview, placed)
var door: RefCounted = null             # a case's door (dry); null: the flags' door
var keep_files := OS.get_environment("TL_COMMAND_KEEP") == "1"
var frame := 0
var asked := 0                          # asks sent, ghosts shown, answers kept (the test hook's anchors count them)
var ghosts := 0
var kept := 0
var said := ""
var said_red := false
var _said_at := -SAY_FRAMES
var _aim := {}                          # the cursor when the bar was opened: {cell, facing}
var _down := {}
var _dir := ""
var _latched := false                   # a key that closed the bar or decided a ghost is still held: build mode must
                                        # not read it as a new press (Enter would open the bar again, Esc would leave)
const KEYS := [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_BACKSPACE]


func setup(h: Node) -> void:
	host = h
	devices = Devices.new(self, OS.get_environment("TL_COMMAND_DEVICES"))


func polled() -> Array:
	return [KEY_ENTER, KEY_KP_ENTER]


func key(e: InputEvent) -> bool:
	var k := e as InputEventKey
	if k != null and k.pressed and (k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_KP_ENTER):
		open_bar()
		return true
	return false


func blocks_input() -> bool:
	return (bar != null and bar.is_open()) or not shown.is_empty() or _latched


func selected(on: bool) -> void:
	if not on and bar != null and bar.is_open():
		bar.close()


func slots() -> Array:
	var out := []
	for p: Dictionary in pending:
		out.append({"key": "", "label": "thinking %s" % _clock(frame - int(p.frame0)), "lit": false})
	for p: Dictionary in ready:
		out.append({"key": "", "label": "answer ready", "lit": true})
	return out


func status() -> Dictionary:
	var why := refusal()
	var info := ""
	if not shown.is_empty():
		info = "\"%s\"  %s" % [shown.answer.note, Answer.counts(shown.preview, int(shown.placed), shown.ops)]
		if str(shown.get("space", {}).get("line", "")) != "":
			info += "   check: " + str(shown.space.line)
	elif bar != null and bar.is_open():
		info = "> type what to build, Enter asks (%s)" % _today()
	elif frame - _said_at < SAY_FRAMES and not said.is_empty():
		info = said
	elif not pending.is_empty():
		info = "thinking... %s (%d asked); keep building, the answer comes as a ghost" % [_clock(frame - int(pending[0].frame0)), pending.size()]
	else:
		info = "Enter: say what to build at the cursor" + ((" (%s)" % _today()) if calls != null else "")
	var red := ""
	if shown.is_empty() and (why != "" or (said_red and frame - _said_at < SAY_FRAMES)):
		red = why if why != "" else said
	return {"info": info, "reason": red, "dim": link != null and link.refusal() != ""}


func hint() -> String:
	if not shown.is_empty():
		return "Enter keep it   Esc or Backspace revert   W A S D walk round it"
	if bar != null and bar.is_open():
		return "Enter ask   Esc close"
	return "Enter ask   " + KEY_HELP


func aim(_h: Dictionary, _mode: Dictionary) -> void:
	pass


## The spot an ask would build at: the cursor's place cell, in holo.
func ghost_state() -> Dictionary:
	var h: Dictionary = host.get("hit") if host != null else {}
	if h.is_empty() or not shown.is_empty():
		return {}
	return {"cell": h.place, "code": HomeBuild.code(1, 1), "mode": "place"}


func press(_button: int, _mods: Dictionary) -> bool:
	return false


func drag(_h: Dictionary) -> void:
	pass


func release(_button: int) -> void:
	pass


func dragging() -> bool:
	return false


# ------------------------------------------------------------------ asking
## "" or why an ask cannot be sent now: the Home's folder, the Foreman (door, probe), the day's cap, the asks pending.
func refusal() -> String:
	if host == null or str(host.get("dir")).is_empty():
		return "the Home is not loaded here: nothing can be asked"
	if link == null:
		return ""
	var why: String = link.refusal()
	if why == "" and pending.size() >= MAX_PENDING:
		why = "%d asks are waiting for the model: wait for one" % MAX_PENDING
	if why == "":
		why = calls.settings_error if calls.settings_error != "" else calls.refusal()
	return why


## Enter: the bar opens at the cursor, or says why it cannot.
func open_bar() -> void:
	_ensure()
	if not shown.is_empty():
		return
	var why := refusal()
	var h: Dictionary = host.get("hit")
	if why == "" and h.is_empty():
		why = "point the cursor at the ground or a block where it should go"
	if why != "":
		_say(why, true)
		return
	_aim = {"cell": h.place as Vector3i, "facing": HomeBuild.rot_facing(host.call("forward"))}
	var c: Vector3i = _aim.cell
	bar.open("Build at (%d, %d, %d), looking %s   %s   Enter ask   Esc close" % [c.x, c.y, c.z, FACING[int(_aim.facing)], _today()])


func _on_submitted(text: String) -> void:
	bar.close()
	_latched = true
	if text.strip_edges().is_empty():
		_say("nothing was asked", false)
		return
	var why := send(text, _aim.cell, int(_aim.facing))
	if why != "":
		_say(why, true)


## Sends `text` as an ask at `cell` facing `facing`. Returns "" or why it was not sent.
func send(text: String, cell: Vector3i, facing: int) -> String:
	_ensure()
	var why := refusal()
	if why != "":
		return why
	var sentence := text.replace("\n", " ").strip_edges().left(400)
	var ask: Dictionary = Ask.make(host.get("build"), host.get("land"), sentence, cell, facing, Ask.SIZE, Unlocks.new(_dir))
	if ask.has("error"):
		return str(ask.error)
	var cid: String = calls.new_id()
	var dir := _dir.path_join("llm")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var ask_path := ProjectSettings.globalize_path(dir.path_join(cid + ".ask.json"))
	var out_path := ProjectSettings.globalize_path(dir.path_join(cid + ".answer.json"))
	var f := FileAccess.open(ask_path, FileAccess.WRITE)
	if f == null:
		return "cannot write the ask (%s)" % ask_path
	var text_ask := JSON.stringify(ask, "", false)
	f.store_string(text_ask + "\n")
	f.close()
	why = link.ask(ask_path, out_path)
	if why != "":
		return "the Foreman could not be asked: " + why
	var rec: Dictionary = calls.write(cid, {"day": calls.today(), "sentence": sentence, "accepted": "pending"})
	var m: Node3D = Marker.new()
	host.add_child(m)
	m.place_at(cell)
	m.thinking(0)
	pending.append({"id": cid, "sentence": sentence, "cell": cell, "facing": facing, "ask": ask_path, "out": out_path,
		"frame0": frame, "marker": m, "rec": rec})
	asked += 1
	_say("asked: \"%s\"" % sentence, false)
	print(JSON.stringify({"schema": "tl.view/1", "kind": "command_ask", "id": cid, "cell": [cell.x, cell.y, cell.z],
		"facing": facing, "region": ask.region, "blocks": (ask.blocks as Array).size(), "refused": (ask.get("refused", []) as Array).size(),
		"ops": ask.ops, "mats": (ask.mats as Array).size(), "parts": (ask.get("parts", []) as Array).size(),
		"water": (ask.get("water", []) as Array).size(), "bytes": text_ask.length(), "frame": frame}, "", false))
	return ""


# ------------------------------------------------------------------ per frame
func tick(f: int) -> void:
	frame = f
	if host == null or not host.is_inside_tree():
		return
	devices.run(f)
	if bar != null and bar.is_open() and not (bar.line as LineEdit).has_focus():
		(bar.line as LineEdit).grab_focus()     # a click in the world took the keyboard from the field: give it back
	for p: Dictionary in pending.duplicate():
		(p.marker as Node3D).call("thinking", f - int(p.frame0))
		if (f - int(p.frame0)) % POLL_EVERY != 0:
			continue
		if FileAccess.file_exists(str(p.out)):
			_arrive(p)
		elif not link.busy(str(p.ask)):
			var why: String = link.error_of(str(p.ask))
			_fail(p, why if why != "" else "the Foreman ended without an answer")
	if shown.is_empty() and not ready.is_empty() and bool(host.get("active")):
		_show(ready.pop_front())
	if not shown.is_empty() and not (bar != null and bar.is_open()):
		if _edge(KEY_ENTER) or _edge(KEY_KP_ENTER):
			accept()
		elif _edge(KEY_ESCAPE) or _edge(KEY_BACKSPACE):
			revert()
	else:
		for k: int in KEYS:
			_down[k] = Input.is_physical_key_pressed(k)
	if _latched and KEYS.all(func(k: int) -> bool: return not Input.is_physical_key_pressed(k)):
		_latched = false


func _edge(k: int) -> bool:
	var now := Input.is_physical_key_pressed(k)
	var was: bool = _down.get(k, true)
	_down[k] = now
	return now and not was


func _arrive(p: Dictionary) -> void:
	var r: Dictionary = Answer.read(str(p.out))
	if not bool(r.ok):
		_fail(p, str(r.error))
		return
	pending.erase(p)
	p["answer"] = r
	ready.append(p)
	print(JSON.stringify({"schema": "tl.view/1", "kind": "command_answer", "id": p.id, "ops": (r.ops as Array).size(),
		"model": r.model, "durationMs": r.durationMs, "tokensIn": r.get("tokensIn", -1), "tokensOut": r.get("tokensOut", -1),
		"frames": frame - int(p.frame0)}, "", false))


func _fail(p: Dictionary, why: String) -> void:
	pending.erase(p)
	(p.marker as Node).queue_free()
	var rec: Dictionary = (p.rec as Dictionary).duplicate()
	rec["accepted"] = false
	rec["error"] = why
	calls.write(str(p.id), rec)
	_tidy(p)
	_say("the model built nothing for \"%s\": %s" % [str(p.sentence).left(40), why], true)
	print(JSON.stringify({"schema": "tl.view/1", "kind": "command_error", "id": p.id, "error": why, "frame": frame}, "", false))


## The answer as a ghost: its input ops expanded (home_build.gd `expand_input`: a pour becomes a flood op; one that
## cannot be is counted refused, at index -1 - i), the locked ops split out (refused "locked: <condition>", at index
## LOCKED_AT - i), a dry run of the rest, the blocks drawn by `preview` and every other layer's part by its own
## `preview_node` under `layer_ghosts`.
func _show(p: Dictionary) -> void:
	var build: RefCounted = host.get("build")
	var ex: Dictionary = build.expand_input(Answer.llm_ops(p.answer.ops))
	var lk: Dictionary = Answer.split_locked(ex.ops, Unlocks.new(_dir))
	var ops: Array = lk.ops
	var r: Dictionary = build.preview(ops)
	var early: Array = (ex.refused as Array).map(func(x: Array) -> Array: return [-1 - int(x[0]), x[1]])
	early.append_array((lk.refused as Array).map(func(x: Array) -> Array: return [LOCKED_AT - int(x[0]), x[1]]))
	p["expand_refused"] = early
	(r.refused as Array).append_array(p.expand_refused)
	p["ops"] = ops
	p["preview"] = r
	p["placed"] = int((r.store as RefCounted).get("total"))
	preview.call("show_stores", r.store, r.removed)
	_clear_layer_ghosts()
	for n: Node3D in build.preview_nodes(r, ["blocks"]):
		layer_ghosts.add_child(n)
	var top := float((p.cell as Vector3i).y)
	for s: Vector2i in (r.store as RefCounted).get("sections"):
		for idx: int in (r.store as RefCounted).get("sections")[s]:
			top = maxf(top, float((r.store as RefCounted).call("cell_of", s, idx).y) + 1.0)
	var t0 := Time.get_ticks_usec()
	var sp: Dictionary = Space.check(build, host.get("land"), r)
	p["space"] = sp
	var space_ms := (Time.get_ticks_usec() - t0) / 1000.0
	space_marks = Space.marks_node(sp.marks)
	if space_marks != null:
		host.add_child(space_marks)
	var note := str(p.answer.note) + ("" if str(sp.line) == "" else "
check: " + str(sp.line))
	(p.marker as Node3D).call("note", note, top - float((p.cell as Vector3i).y))
	shown = p
	ghosts += 1
	for k: int in KEYS:
		_down[k] = true                 # a key already held does not decide: only a new press
	if host.call("tool") != self:
		host.call("switch_tool", 0, "command")
	print(JSON.stringify({"schema": "tl.view/1", "kind": "command_ghost", "id": p.id, "applied": int(r.applied),
		"refused": (r.refused as Array).size(), "placed": p.placed, "counts": Answer.counts(r, int(p.placed), ops),
		"layers": layer_ghosts.get_children().map(func(n: Node) -> String: return str(n.get_meta(&"tl_layer", ""))), "space": sp.line,
		"space_nodes": sp.nodes, "space_marks": (sp.marks as Array).size(), "space_ms": snappedf(space_ms, 0.1), "frame": frame}, "", false))


## Enter on a ghost: its ops applied as ONE batch by "llm" (one undo step), the counts as they are now.
func accept() -> Dictionary:
	if shown.is_empty():
		return {}
	var p := shown
	var build: RefCounted = host.get("build")
	var lk: Dictionary = Answer.split_locked(p.ops, Unlocks.new(_dir))       # the backstop: a lock is asked again now
	if not (lk.refused as Array).is_empty():
		p.ops = lk.ops
		(p.expand_refused as Array).append_array((lk.refused as Array).map(func(x: Array) -> Array: return [LOCKED_AT - 50000 - int(x[0]), x[1]]))
	build.begin_batch("llm")
	var r: Dictionary = build.apply(p.ops)
	build.end_batch()
	(r.refused as Array).append_array(p.get("expand_refused", []))
	var bad := {}
	for x: Array in r.refused:
		bad[int(x[0])] = true
	var last := {}                          # cell -> the kind of the last op applied there: a cell placed twice is one block
	for i: int in (p.ops as Array).size():
		if not bad.has(i) and str(p.ops[i].op) in ["place", "remove"]:
			last[str(p.ops[i].at)] = str(p.ops[i].op)
	var placed := last.values().count("place")
	_decided(p, true, r)
	kept += 1
	_say("kept: %s. Ctrl+Z takes it all back" % Answer.counts(r, placed, p.ops), false)
	print(JSON.stringify({"schema": "tl.view/1", "kind": "command_kept", "id": p.id, "applied": int(r.applied),
		"refused": (r.refused as Array).size(), "placed": placed, "batch": int(build.get("edits").get("next_batch")) - 1,
		"blocks": int(build.get("blocks").get("total")), "frame": frame}, "", false))
	return r


## Esc or Backspace on a ghost: nothing is applied.
func revert() -> void:
	if shown.is_empty():
		return
	var p := shown
	_decided(p, false, p.preview)
	_say("reverted: nothing was built", false)
	print(JSON.stringify({"schema": "tl.view/1", "kind": "command_reverted", "id": p.id, "frame": frame}, "", false))


func _decided(p: Dictionary, keep: bool, r: Dictionary) -> void:
	preview.call("clear")
	_clear_layer_ghosts()
	if space_marks != null:
		space_marks.queue_free()
		space_marks = null
	_latched = true
	(p.marker as Node).queue_free()
	shown = {}
	var rec: Dictionary = (p.rec as Dictionary).duplicate()
	rec["accepted"] = keep
	for k: String in ["model", "tokensIn", "tokensOut", "durationMs"]:
		if p.answer.has(k):
			rec[k] = p.answer[k]
	rec["ops"] = (p.ops as Array).size()
	rec["applied"] = int(r.applied)
	rec["refused"] = (r.refused as Array).size()
	calls.write(str(p.id), rec)
	_tidy(p)


func _tidy(p: Dictionary) -> void:
	if keep_files:
		return
	for k: String in ["ask", "out"]:
		if FileAccess.file_exists(str(p[k])):
			DirAccess.remove_absolute(str(p[k]))


# ------------------------------------------------------------------ parts
## The link, the calls log, the bar and the ghost, made once the Home's folder is known (build mode's `dir`).
func _ensure() -> void:
	var d := str(host.get("dir"))
	if calls == null or d != _dir:
		_dir = d
		calls = Calls.new(d)
	if link == null and not d.is_empty():
		link = Link.new()
		link.setup(ProjectSettings.globalize_path(d.path_join("llm")), {"door": door} if door != null else {})
	if bar == null and host.is_inside_tree():
		bar = Bar.new()
		host.add_child(bar)
		bar.submitted.connect(_on_submitted)
		bar.cancelled.connect(func() -> void:
			bar.close()
			_latched = true
			_say("closed: nothing was asked", false))
		preview = PreviewMesh.new()
		host.add_child(preview)
		layer_ghosts = Node3D.new()
		layer_ghosts.name = "CommandLayerGhosts"
		host.add_child(layer_ghosts)


func _clear_layer_ghosts() -> void:
	if layer_ghosts == null:
		return
	for n: Node in layer_ghosts.get_children():
		layer_ghosts.remove_child(n)
		n.queue_free()


func _today() -> String:
	if calls == null:
		return ""
	return "%d of %d calls today" % [calls.used_today(), calls.cap]


func _say(text: String, red: bool) -> void:
	said = text
	said_red = red
	_said_at = frame


static func _clock(frames: int) -> String:
	var s := frames / 60
	return "%d:%02d" % [s / 60, s % 60]
