extends SceneTree
## M4 (spark world-sandbox): the LLM command bar (tools/command_tool.gd), headless, in the landscape of
## res://boot/village.json with build mode mounted, driven as a person drives it: keys through the engine's input state
## (build mode polls it), the typed letters pushed into the viewport (a headless run hands no event to the GUI by itself),
## the pointer set on a pixel. No model and no Foreman is run: the door is dry (it records the command line it would
## start) and the case writes the answer file the Foreman would write. Frames, not wall clock. Prints
## `HOME command.<case> ok|fail <detail>`, then `HOME command ok` (or fail) and `HOME DONE`;
## engine/tools/selftest.d/757-home-command.sh reads them.
##   command.open     B, then Enter: the command tool is current, the bar is open with the keyboard
##   command.typing   while the bar has the keyboard a TLInput (the visitor's input) sees no W, B does not leave build
##                    mode, T does not switch the tool; the letters land in the field; Esc closes it, nothing asked
##   command.ask      Enter, a sentence, Enter: the ask file is written (region, ground, tables, the blocks there), the
##                    door was asked `world-edit --in <ask> --out <answer>`, the pending marker says "thinking... 0:01"
##   command.ghost    the answer arrives: a ghost with the note and its counts ("24 blocks, 1 refused: occupied"); the
##                    Home's store and log are untouched
##   command.accept   Enter: one batch, every op by "llm", in the journal; one Ctrl+Z takes it all back
##   command.revert   a second answer, Esc: nothing applied, build mode still on, the ghost gone
##   command.pending  two asks wait; a third is refused; an error answer is logged and said
##   command.cap      the 31st call of the day is refused with the reason (26 calls were logged before the case)
##   command.offline  a door that finds no Foreman: Enter opens nothing and the bar says why
## With `-- ask <file>` (engine/tools/selftest.d/759-home-command-ask.sh) it only writes an ask next to a game lot to
## <file> and prints `HOME command.ask_file ok|fail <detail>`.

const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const Door := preload("res://ui/foreman_door.gd")
const Calls := preload("res://kernel/world/build/command_calls.gd")
const Lists := preload("res://kernel/world/build/seam_lists.gd")    # the op kinds an ask may name (M5: the stubs offer none)
const TMP := "user://tl_command_case"
const NEAR := Vector2i(700, -60)
const PRIOR := 26                       # calls logged today before the case starts

var walk: Dictionary
var node: Node3D
var ws: Object
var bm: Node
var b: RefCounted
var t: RefCounted                       # the command tool
var cam: Camera3D
var site := {}
var ok_all := true
var door: RefCounted


func _initialize() -> void:
	call_deferred("run")


func say(n: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME command.%s %s %s" % [n, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	TLStyle.set_headless(false)
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	walk = CaseUtil.walk()
	node = CaseUtil.landscape(root, walk)
	if not node.has_meta(&"tl_build_mode"):
		say("open", false, "no build mode was mounted")
		return finish()
	ws = node.get_meta(&"tl_space")
	bm = node.get_meta(&"tl_build_mode")
	b = node.get_meta(&"tl_build")
	for x: RefCounted in bm.get("tools"):
		if x.get("id") == "command":
			t = x
	_prior_calls()
	bm.call("open", TMP)
	door = Door.new()
	door.setup(ProjectSettings.globalize_path(TMP.path_join("llm")), {"dry": true, "flags": {"world_edit": ["--adapter", "fake"]}})
	t.set("door", door)
	cam = Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.current = true
	bm.set("cam", cam)
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "ask":
		await ask_file(args[1])
		return finish()
	site = find_site(NEAR)
	var away := Vector3(site.x + 2.5, site.y + 1.0, site.z + 40.0)
	bm.set("feet_at", func() -> Vector3: return away)
	over(Vector3(site.x + 2.5, site.y, site.z + 2.0))
	b.apply([{"op": "place", "at": [site.x + 6, site.y, site.z], "shape": 1, "mat": 2, "rot": 0},
		{"op": "place", "at": [site.x + 6, site.y, site.z + 2], "shape": 1, "mat": 2, "rot": 0}])
	await wait(3)
	await open_case()
	await typing_case()
	await ask_case()
	await ghost_case()
	await accept_case()
	await revert_case()
	await pending_case()
	await cap_case()
	await offline_case()
	finish()


func finish() -> void:
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	print("HOME command %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


# ------------------------------------------------------------------ devices
func tap(k: Key) -> void:
	CaseUtil.key(k, true)
	await wait(2)
	CaseUtil.key(k, false)
	await wait(2)


## Letters as a keyboard types them into the focused field (pushed into the viewport: the GUI's path).
func type_text(s: String) -> void:
	for i: int in s.length():
		var e := InputEventKey.new()
		e.pressed = true
		e.unicode = s.unicode_at(i)
		root.push_input(e)
	await wait(1)


func push_key(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	root.push_input(e)
	var up := e.duplicate() as InputEventKey
	up.pressed = false
	root.push_input(up)
	await wait(2)


func over(p: Vector3) -> void:
	cam.look_at_from_position(p + Vector3(0.0, 16.0, 0.0), p, Vector3.FORWARD)
	cam.reset_physics_interpolation()


func ground(x: int, z: int) -> float:
	return float(ws.call("ground_at", x + 0.5, z + 0.5, site.get("y", 0) + 60.0))


func point(c: Vector2i) -> void:
	bm.set("pointer", cam.unproject_position(Vector3(c.x + 0.5, ground(c.x, c.y), c.y + 0.5)))


## A 9 x 7 patch near `near` whose ground varies less than 0.6 m and that nothing protects.
func find_site(near: Vector2i) -> Dictionary:
	var home: RefCounted = node.get_meta(&"tl_home")
	for k in 30:
		var sx := near.x + 10 * k
		var sz := near.y
		home.ensure(Vector2(sx, sz))
		var lo := INF
		var hi := -INF
		var clear := true
		for z in range(sz - 1, sz + 6):
			for x in range(sx - 1, sx + 8):
				var g: float = float(ws.call("ground_at", x + 0.5, z + 0.5, 300.0))
				lo = minf(lo, g)
				hi = maxf(hi, g)
				clear = clear and b.protect.call("refusal", Vector3i(x, int(floorf(g + 0.01)), z)) == ""
		if clear and hi - lo < 0.6:
			return {"x": sx, "y": int(floorf(lo + 0.01)), "z": sz, "tries": k + 1}
	return {"x": near.x, "y": 0, "z": near.y, "tries": 30}


func _prior_calls() -> void:
	var c: RefCounted = Calls.new(TMP)
	for i in PRIOR:
		c.write("prior-%d" % i, {"day": c.today(), "sentence": "earlier call %d" % i, "accepted": false, "error": "a case's earlier call"})


func last_call() -> Dictionary:
	var all: Array = Calls.new(TMP).calls()
	return all[all.size() - 1] if not all.is_empty() else {}


func answer_for(p: Dictionary, ops: Array, note: String) -> void:
	var f := FileAccess.open(str(p.out), FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": "tl.world-edit/1", "ops": ops, "note": note, "model": "fake-model",
		"durationMs": 1234, "tokensIn": 900, "tokensOut": 300}) + "\n")
	f.close()


## Enter (the engine's key state: build mode polls it), the sentence typed, Enter in the field.
func ask_by_keys(sentence: String) -> void:
	await tap(KEY_ENTER)
	await type_text(sentence)
	await push_key(KEY_ENTER)
	await wait(2)


# ------------------------------------------------------------------ cases
func open_case() -> void:
	await tap(KEY_B)
	point(Vector2i(site.x + 2, site.z + 2))
	await wait(3)
	await tap(KEY_ENTER)
	var bar: CanvasLayer = t.get("bar")
	var focus: Control = root.gui_get_focus_owner()
	var ok: bool = bool(bm.get("active")) and bm.call("tool") == t and bar != null and bar.call("is_open") and focus is LineEdit and bool(t.call("blocks_input"))
	say("open", ok, "build mode on %s, tool '%s', bar open %s, focus %s, keyboard taken %s; site (%d, %d, %d) after %d tries" % [
		bm.get("active"), str(bm.call("tool").get("id")), bar != null and bar.call("is_open"), str(focus), t.call("blocks_input"), site.x, site.y, site.z, site.tries])


func typing_case() -> void:
	var probe := TLInput.new()
	probe.declare(&"forward", [KEY_W])
	probe.accept_devices = true
	root.add_child(probe)
	var tool_before: int = bm.get("tool_index")
	CaseUtil.key(KEY_W, true)
	CaseUtil.key(KEY_B, true)
	CaseUtil.key(KEY_T, true)
	await wait(3)
	probe._sample()
	var w_typing: bool = probe.pressed(&"forward")
	var still: bool = bm.get("active") and int(bm.get("tool_index")) == tool_before
	CaseUtil.key(KEY_B, false)
	CaseUtil.key(KEY_T, false)
	await type_text("hello")
	var text: String = t.get("bar").get("line").text
	await push_key(KEY_ESCAPE)
	var closed: bool = not t.get("bar").call("is_open")
	await wait(3)
	probe._sample()
	var w_after: bool = probe.pressed(&"forward")
	CaseUtil.key(KEY_W, false)
	await wait(2)
	probe.queue_free()
	var ok: bool = not w_typing and still and text == "hello" and closed and w_after and (t.get("pending") as Array).is_empty() and bool(bm.get("active"))
	say("typing", ok, "W seen by the visitor's input while typing %s (after the bar closed %s); B and T ignored %s; field '%s'; Esc closed it %s, asks %d, build mode on %s" % [
		w_typing, w_after, still, text, closed, (t.get("pending") as Array).size(), bm.get("active")])


func ask_case() -> void:
	point(Vector2i(site.x + 2, site.z + 2))
	await wait(3)
	var aimed: Vector3i = (bm.get("hit") as Dictionary).get("place", Vector3i.ZERO)
	await ask_by_keys("a little stone tower here")
	var pend: Array = t.get("pending")
	if pend.is_empty():
		say("ask", false, "nothing is pending; the hotbar says '%s'" % str(t.call("status")))
		return
	var p: Dictionary = pend[0]
	var ask: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(p.ask)))
	var a: Dictionary = ask if ask is Dictionary else {}
	var region: Dictionary = a.get("region", {})
	var size := [int(region.max[0]) - int(region.min[0]) + 1, int(region.max[1]) - int(region.min[1]) + 1, int(region.max[2]) - int(region.min[2]) + 1] if region.has("max") else []
	var rows: Array = a.get("ground", {}).get("rows", [])
	var steps: Array = door.get("dry_steps")
	var step: Array = steps[steps.size() - 1][0] if not steps.is_empty() else []
	await wait(62)
	var label: String = ((p.marker as Node).get("label") as Label3D).text
	var want_step := ["world-edit", "--in", str(p.ask), "--out", str(p.out), "--adapter", "fake"]
	var ok: bool = a.get("schema") == "tl.world-edit-ask/1" and a.get("sentence") == "a little stone tower here" and \
		ints(a.get("cursor", [])) == [aimed.x, aimed.y, aimed.z] and size == [32, 24, 32] and rows.size() == 32 and (rows[0] as Array).size() == 32 and \
		(a.get("blocks", []) as Array).size() == 2 and (a.get("shapes", []) as Array).size() == 8 and (a.get("mats", []) as Array).size() == 9 and \
		(a.get("ops") as Array).slice(0, 2) == ["place", "remove"] and (a.get("ops") as Array).all(func(o: String) -> bool: return Lists.ask_ops().has(o)) and step == want_step and label.begins_with("thinking... 0:01") and last_call().get("accepted") == "pending"
	say("ask", ok, "ask %s: cursor %s (aimed %s), region %s, ground %dx%d, blocks %d, shapes %d, mats %d, ops %s; door asked %s; marker '%s'; log '%s'" % [
		str(p.ask).get_file(), str(a.get("cursor")), str(aimed), str(size), rows.size(), (rows[0] as Array).size() if not rows.is_empty() else 0,
		(a.get("blocks", []) as Array).size(), (a.get("shapes", []) as Array).size(), (a.get("mats", []) as Array).size(), str(a.get("ops")),
		" ".join(step.slice(0, 1) + step.slice(5)), label, str(last_call().get("accepted"))])


## The answer: a ring of 3 x 3 x 3 stone round the cursor's column (24 blocks), a place on a held cell (refused:
## occupied), and a remove of the other held cell.
func tower_ops(cell: Vector3i) -> Array:
	var ops := []
	for y in 3:
		for z in range(cell.z - 1, cell.z + 2):
			for x in range(cell.x - 1, cell.x + 2):
				if x == cell.x and z == cell.z:
					continue
				ops.append({"op": "place", "at": [x, cell.y + y, z], "shape": 1, "mat": 1, "rot": 0})
	ops.append({"op": "place", "at": [site.x + 6, site.y, site.z], "shape": 1, "mat": 3, "rot": 0})
	ops.append({"op": "remove", "at": [site.x + 6, site.y, site.z + 2], "shape": 1, "mat": 2, "rot": 0})
	return ops


var _before := {}


func ghost_case() -> void:
	var p: Dictionary = (t.get("pending") as Array)[0]
	_before = {"total": int(b.blocks.total), "batches": (b.edits.history as Array).size()}
	answer_for(p, tower_ops(p.cell), "A little stone tower, three blocks high.")
	await wait(20)
	var shown: Dictionary = t.get("shown")
	var pv: Node3D = t.get("preview")
	var st: Dictionary = t.call("status")
	var untouched: bool = int(b.blocks.total) == int(_before.total) and (b.edits.history as Array).size() == int(_before.batches)
	var ok: bool = not shown.is_empty() and pv != null and bool(pv.get("shown")) and int(pv.call("stats").tris) > 0 and untouched and \
		str(st.info).contains("A little stone tower") and str(st.info).contains("24 blocks, 1 refused: occupied") and bool(t.call("blocks_input")) and \
		str(((shown.get("marker") as Node).get("label") as Label3D).text) == "A little stone tower, three blocks high."
	say("ghost", ok, "ghost shown %s (%d tris), info '%s', store untouched %s (blocks %d, batches %d)" % [
		not shown.is_empty(), int(pv.call("stats").tris) if pv != null else 0, str(st.info), untouched, int(b.blocks.total), (b.edits.history as Array).size()])


func accept_case() -> void:
	CaseUtil.key(KEY_ENTER, true)
	await wait(2)
	var total: int = b.blocks.total
	var hist: Array = b.edits.history
	var last: Dictionary = hist[hist.size() - 1] if not hist.is_empty() else {}
	var batches: int = hist.size() - int(_before.batches)
	var llm := true
	for o: Dictionary in last.get("ops", []):
		llm = llm and o.author == "llm"
	var journal := FileAccess.get_file_as_string(TMP.path_join("edits.jsonl"))
	var lines := journal.count("\"author\":\"llm\"")
	CaseUtil.key(KEY_ENTER, false)
	await wait(3)
	var reopened: bool = t.get("bar").call("is_open")
	var call := last_call()
	CaseUtil.key(KEY_CTRL, true)
	await tap(KEY_Z)
	CaseUtil.key(KEY_CTRL, false)
	await wait(2)
	var back: bool = int(b.blocks.total) == int(_before.total) and b.code_at(Vector3i(site.x + 6, site.y, site.z + 2)) != 0
	var ok: bool = (t.get("shown") as Dictionary).is_empty() and total == int(_before.total) + 23 and batches == 1 and \
		(last.get("ops", []) as Array).size() == 25 and llm and lines == 25 and not reopened and back and call.get("accepted") == true and \
		int(call.get("applied", 0)) == 25 and int(call.get("refused", 0)) == 1 and call.get("model") == "fake-model" and int(call.get("tokensIn", 0)) == 900
	say("accept", ok, "Enter kept it: blocks %d -> %d, %d batch(es), %d ops all by llm %s, %d journal lines by llm; the bar did not reopen %s; one Ctrl+Z: blocks %d, the removed block back %s; log %s" % [
		int(_before.total), total, batches, (last.get("ops", []) as Array).size(), llm, lines, not reopened, int(b.blocks.total), back, JSON.stringify(call)])


func revert_case() -> void:
	point(Vector2i(site.x + 3, site.z + 3))
	await wait(3)
	await ask_by_keys("a stone wall")
	var pend: Array = t.get("pending")
	if pend.is_empty():
		say("revert", false, "the second ask was not sent: '%s'" % str(t.call("status")))
		return
	var before: int = b.blocks.total
	var hist: int = (b.edits.history as Array).size()
	answer_for(pend[0], tower_ops(pend[0].cell).slice(0, 8), "A short stone wall.")
	await wait(20)
	var was_shown: bool = not (t.get("shown") as Dictionary).is_empty()
	CaseUtil.key(KEY_ESCAPE, true)
	await wait(2)
	CaseUtil.key(KEY_ESCAPE, false)
	await wait(3)
	var ok: bool = was_shown and (t.get("shown") as Dictionary).is_empty() and int(b.blocks.total) == before and (b.edits.history as Array).size() == hist and \
		bool(bm.get("active")) and not bool(t.get("preview").get("shown")) and last_call().get("accepted") == false
	say("revert", ok, "ghost shown %s; Esc: blocks %d -> %d, batches %d -> %d, build mode still on %s, ghost gone %s, log accepted %s" % [
		was_shown, before, int(b.blocks.total), hist, (b.edits.history as Array).size(), bm.get("active"), not bool(t.get("preview").get("shown")), str(last_call().get("accepted"))])


func pending_case() -> void:
	point(Vector2i(site.x + 2, site.z + 4))
	await wait(3)
	await ask_by_keys("a bench")
	await ask_by_keys("a lamp post")
	var n: int = (t.get("pending") as Array).size()
	await tap(KEY_ENTER)
	var refused: String = str(t.call("status").reason)
	var opened: bool = t.get("bar").call("is_open")
	for p: Dictionary in (t.get("pending") as Array).duplicate():
		var f := FileAccess.open(str(p.out), FileAccess.WRITE)
		f.store_string(JSON.stringify({"schema": "tl.world-edit/1", "error": "world_edit: builder error: the model is not reachable"}))
		f.close()
	await wait(20)
	var said: String = str(t.get("said"))
	var call := last_call()
	var ok: bool = n == 2 and refused.contains("2 asks are waiting") and not opened and (t.get("pending") as Array).is_empty() and \
		said.contains("not reachable") and call.get("accepted") == false and str(call.get("error", "")).contains("not reachable")
	say("pending", ok, "%d asks waiting; a third: '%s' (bar opened %s); error answers: '%s'; log %s" % [n, refused, opened, said, JSON.stringify(call)])


func cap_case() -> void:
	await wait(SAY_WAIT)
	var used: int = (t.get("calls") as RefCounted).call("used_today")
	await tap(KEY_ENTER)
	var why: String = str(t.call("status").reason)
	var label: String = ((bm.get("hotbar") as CanvasLayer).get("reason") as Label).text
	await wait(2)
	label = ((bm.get("hotbar") as CanvasLayer).get("reason") as Label).text
	var ok: bool = used == 30 and why.contains("30 of 30 calls today") and label.contains("30 of 30") and not t.get("bar").call("is_open")
	say("cap", ok, "calls today %d; Enter for the 31st: '%s' (hotbar '%s')" % [used, why, label])


const SAY_WAIT := 4


func offline_case() -> void:
	var lost := Door.new()
	lost.setup(ProjectSettings.globalize_path(TMP.path_join("llm")), {"cli": "C:/nowhere/foreman/dist/cli.js", "runner": "C:/nowhere/run.mjs",
		"flags": {"world_edit": ["--adapter", "claude-cli"]}})
	t.set("link", null)
	t.set("door", lost)
	await tap(KEY_ENTER)
	var why: String = str(t.call("status").reason)
	var ok: bool = why.contains("Foreman not found") and not t.get("bar").call("is_open") and bool(t.call("status").get("dim", false))
	say("offline", ok, "no Foreman: Enter says '%s', bar opened %s" % [why, t.get("bar").call("is_open")])


## JSON numbers (floats) as ints, through nested lists.
static func ints(v: Variant) -> Variant:
	if v is Array:
		return (v as Array).map(func(x: Variant) -> Variant: return ints(x))
	return int(v) if typeof(v) == TYPE_FLOAT else v


# ------------------------------------------------------------------ 759: the ask beside a game lot
func ask_file(out: String) -> void:
	var plot: Array = walk.plots[0].origin
	var r := float(walk.plots[0].radius)
	site = {"x": int(plot[0] + r + 6.0), "y": 0, "z": int(plot[2])}
	(node.get_meta(&"tl_home") as RefCounted).call("ensure", Vector2(site.x, site.z))
	site.y = int(floorf(ground(site.x, site.z) + 0.01))
	b.apply([{"op": "place", "at": [site.x, site.y, site.z], "shape": 7, "mat": 6, "rot": 1}])
	var away := Vector3(site.x + 0.5, site.y + 1.0, site.z + 60.0)
	bm.set("feet_at", func() -> Vector3: return away)
	await wait(2)
	var why: String = t.call("send", "a stone watchtower with a slate roof here", Vector3i(site.x, site.y, site.z), 3)
	var pend: Array = t.get("pending")
	if why != "" or pend.is_empty():
		say("ask_file", false, "the ask was not sent: %s" % why)
		return
	var text := FileAccess.get_file_as_string(str(pend[0].ask))
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var a: Dictionary = JSON.parse_string(text)
	var refused: Array = a.get("refused", [])
	var lot := refused.filter(func(x: Dictionary) -> bool: return x.reason == "game lot")
	var ground_ok := true
	for j: int in (a.ground.rows as Array).size():
		for i: int in (a.ground.rows[j] as Array).size():
			var x: int = int(a.region.min[0]) + i
			var z: int = int(a.region.min[2]) + j
			ground_ok = ground_ok and int(a.ground.rows[j][i]) == int(floorf(float((node.get_meta(&"tl_home") as Object).call("ground_y", x + 0.5, z + 0.5)) + 0.01))
	var ok: bool = not lot.is_empty() and ground_ok and ints(a.blocks) == [[site.x, site.y, site.z, 7, 6, 1, 0]] and int(a.facing) == 3 and int(a.caps.ops) == 4000
	say("ask_file", ok, "%d bytes; refused %s; ground = hook.ground_y %s; blocks %s; facing %d; caps %s" % [text.length(),
		str(refused.map(func(x: Dictionary) -> String: return "%s (%d runs)" % [x.reason, (x.runs as Array).size()])), ground_ok, str(ints(a.blocks)), int(a.facing), str(ints([a.caps.ops, a.caps.blocks_left]))])
