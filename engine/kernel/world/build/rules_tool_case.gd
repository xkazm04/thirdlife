extends SceneTree
## M6 lane T (27 Nov 2026): the Rules hand tool (tools/rules_tool.gd, rules_tool_presets.gd, zone_draw.gd, the rules
## layer's `preview_node`), headless, without a landscape, through build mode's own input path: keys polled by build
## mode from the engine's input state (CaseUtil.key), the cursor as build mode's `hit` with the tool's press / drag /
## release, the name field through the viewport. Prints `HOME rules-tool.<case> ok|fail <detail>`, then
## `HOME rules-tool ok` (or fail) and `HOME DONE`; engine/tools/selftest.d/775-home-rules-tool.sh reads them. Frames.
##   rules-tool.presets   each of the 8 presets (armed by its key, then a click or a drag; a box first, then its key)
##                        writes its zone and rules as ONE batch, the look and the rules its preset says
##   rules-tool.undo      one Ctrl+Z takes each preset away whole, Ctrl+Y brings it back
##   rules-tool.delete    a click on a zone selects it; Delete removes it and every rule naming it in one batch
##   rules-tool.field     the first Start asks the run's name ("Run 1" selected); Enter held after it closes neither
##                        opens the command bar nor leaves build mode; Esc places nothing and stays building; later
##                        Starts use the name without asking
##   rules-tool.describe  the side card lists the selected zone's rules as describe's sentences, and the Home's rules
##   rules-tool.knobs     coin value, door seconds (0 -> 1 -> 0: two rules, three, two), pad up / forward, message text
##                        (G), each one batch
##   rules-tool.ghost     preview_node: one node per changed zone (holo), a removed one red, null when nothing
##                        changed; the armed tool's ghost after a steady aim; a refused preset red with its reason
##   rules-tool.draw      zone_draw shows every zone while building (any tool), the selected one yellow, none in play
##   rules-tool.runs      the presets as made play (rules_run.gd over a recording facade, a scripted feet path):
##                        start, checkpoint, coin, the door (E opens, leaving closes; timed: closes within its
##                        seconds), the pad's launch, the hazard's respawn at the checkpoint, the finish

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const BuildMode := preload("res://kernel/world/build/build_mode.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const Presets := preload("res://kernel/world/build/rules_tool_presets.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const RulesRun := preload("res://kernel/world/build/rules_run.gd")


class Rec extends "res://kernel/world/build/rules_facade.gd":
	var log := []
	var run: WeakRef = null
	func _f() -> int: return int(run.get_ref().get("frame")) if run != null and run.get_ref() != null else -1
	func set_open(z: int, _box: Array, o: bool) -> void: log.append([_f(), "set_open", z, o])
	func look_taken(z: int, tk: bool) -> void: log.append([_f(), "look_taken", z, tk])
	func launch(u: int, f: int) -> void: log.append([_f(), "launch", u, f])
	func teleport(at: Vector3) -> void: log.append([_f(), "teleport", at])
	func say(tx: String, n: int) -> void: log.append([_f(), "say", tx, n])
	func run_started(n: String, fr: int) -> void: log.append([_f(), "run_started", n])
	func run_finished(n: String, fr: int, _best: int, _nb: bool) -> void: log.append([_f(), "run_finished", n, fr])
	func run_stopped(n: String, why: String) -> void: log.append([_f(), "run_stopped", n, why])

var ok_all := true
var b: RefCounted
var bm: Node
var t: RefCounted
var rl: RefCounted


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME rules-tool.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func tap(k: Key, shift := false, ctrl := false) -> void:
	if shift:
		CaseUtil.key(KEY_SHIFT, true)
	if ctrl:
		CaseUtil.key(KEY_CTRL, true)
	CaseUtil.key(k, true, shift)
	await wait(2)
	CaseUtil.key(k, false, shift)
	if ctrl:
		CaseUtil.key(KEY_CTRL, false)
	if shift:
		CaseUtil.key(KEY_SHIFT, false)
	await wait(2)


func push_key(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	root.push_input(e)                  # a headless run hands the engine's key to no GUI: the field gets it here
	await wait(2)


static func ground(x: int, y: int, z: int) -> Dictionary:
	return {"pos": Vector3(x + 0.5, y, z + 0.5), "normal": Vector3.UP, "block": false, "place": Vector3i(x, y, z), "remove": HomeBuild.NO_CELL}


static func on_block(c: Vector3i, n: Vector3i) -> Dictionary:
	return {"pos": Vector3(c) + Vector3(0.5, 0.5, 0.5) + Vector3(n) * 0.5, "normal": Vector3(n), "block": true, "place": c + n, "remove": c}


## A click (press and release on one cell) with the cursor on `h`.
func click(h: Dictionary) -> void:
	bm.set("hit", h)
	if t.press(MOUSE_BUTTON_LEFT, {}):
		t.release(MOUSE_BUTTON_LEFT)


func drag_box(h1: Dictionary, h2: Dictionary) -> void:
	bm.set("hit", h1)
	if t.press(MOUSE_BUTTON_LEFT, {}):
		t.drag(h2)
		t.release(MOUSE_BUTTON_LEFT)


func run() -> void:
	b = HomeBuild.new(null, null, {})
	bm = BuildMode.new()
	bm.set("build", b)
	root.add_child(bm)
	rl = b.layer("rules")
	# a wall along z at x = 10 (z 3..9, y 0..2) with door blocks at z 6, y 0..1
	var wall := []
	for y in 3:
		for z in range(3, 10):
			wall.append({"op": "place", "at": [10, y, z], "shape": Blocks.CUBE, "mat": 2, "rot": 0})
	b.apply(wall)
	await wait(2)
	await tap(KEY_B)
	while str(bm.call("tool").get("id")) != "rules":
		await tap(KEY_T)
	t = bm.call("tool")
	var made := await presets_case()
	await undo_case(made)
	await delete_case(made)
	await field_case()
	describe_case(made)
	await knobs_case(made)
	await ghost_case()
	await draw_case()
	runs_case(made)
	await tap(KEY_B)
	bm.queue_free()
	await wait(2)
	print("HOME rules-tool %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


## kind -> {"zone": id, "rules": [ids], "batch": history size after it}
func presets_case() -> Dictionary:
	var made := {}
	var bad := []
	var lines := []
	# armed by its key then a click or a drag, or a box first then the key; the field asks the run's name / the text
	var plan := [
		["start", "arm", [ground(0, 0, 0)]],
		["checkpoint", "arm", [ground(0, 0, 8), ground(1, 0, 9)]],
		["coin", "arm", [ground(3, 0, 0)]],
		["door", "arm", [on_block(Vector3i(10, 0, 6), Vector3i(-1, 0, 0)), on_block(Vector3i(10, 1, 6), Vector3i(-1, 0, 0))]],
		["pad", "box", [ground(5, 0, 0), ground(6, 0, 1)]],
		["hazard", "box", [ground(0, 0, 12), ground(4, 0, 13)]],
		["message", "arm", [ground(-3, 0, 0)]],
		["finish", "box", [ground(14, 0, 6), ground(15, 0, 7)]]]
	for p: Array in plan:
		var kind: String = p[0]
		var key_ := (KEY_1 + Presets.KINDS.find(kind)) as Key
		var hist: int = b.edits.history.size()
		var z0: int = rl.zones.size()
		var r0: int = rl.rules.size()
		var hits: Array = p[2]
		if p[1] == "arm":
			await tap(key_)
			if str(t.get("armed")) != kind:
				bad.append("%s: key %d armed '%s'" % [kind, key_ - KEY_0, str(t.get("armed"))])
			if hits.size() == 1:
				click(hits[0])
			else:
				drag_box(hits[0], hits[1])
		else:
			if str(t.get("armed")) != "":
				await tap(KEY_0)
			drag_box(hits[0], hits[1])
			if not bool(t.get("has_box")):
				bad.append("%s: no box after the drag" % kind)
			if kind == "finish":
				bm.call("_input", _wheel_up())
				bm.call("_input", _wheel_up())
				await wait(2)
			await tap(key_)
		if t.call("naming"):
			var line: LineEdit = (t.get("name_bar") as CanvasLayer).get("line")
			lines.append("%s asked '%s'" % [kind, line.text])
			if kind == "start":
				line.text = "Tower"
			await push_key(KEY_ENTER)
			await wait(4)
		if p[1] == "arm":
			await tap(key_)                 # the same key again stops it
		var zid: int = rl.next_zone_id() - 1
		var rids: Array = rl.named_by.get(zid, {}).keys()
		rids.sort()
		made[kind] = {"zone": zid, "rules": rids, "batch": b.edits.history.size()}
		var z: Dictionary = rl.zones.get(zid, {})
		var one: bool = b.edits.history.size() == hist + 1
		var want_rules := 2 if kind == "door" else 1
		var ok_k: bool = one and rl.zones.size() == z0 + 1 and rl.rules.size() == r0 + want_rules and str(z.get("look", "")) == Presets.LOOKS[kind] \
			and Presets.kind_of(rl, zid) == kind and rids.size() == want_rules
		var desc: Array = rids.map(func(n: int) -> String: return rl.describe(n))
		lines.append("%s: %s %s %s, %d rules (%s)%s" % [kind, str(z.get("name", "?")), str(z.get("look", "?")), str(z.get("box", [])), rids.size(), " | ".join(desc), "" if one else " NOT ONE BATCH"])
		if not ok_k:
			bad.append("%s: one batch %s, zones %d->%d, rules %d->%d, look '%s', kind '%s', reason '%s'" % [kind, one, z0, rl.zones.size(), r0, rl.rules.size(),
				str(z.get("look", "")), Presets.kind_of(rl, zid), str(t.get("reason"))])
	var door: Dictionary = rl.zones.get(made.door.zone, {})
	if str(door.get("box", [])) != str([[9, 0, 6], [11, 1, 6]]):
		bad.append("door box %s, want [[9, 0, 6], [11, 1, 6]] (the blocks grown through the wall)" % str(door.get("box", [])))
	var fin: Dictionary = rl.zones.get(made.finish.zone, {})
	if str(fin.get("box", [])) != str([[14, 0, 6], [15, 2, 7]]):
		bad.append("finish box %s, want [[14, 0, 6], [15, 2, 7]] (two wheel notches: 3 high, as drawn)" % str(fin.get("box", [])))
	var start_rule: Dictionary = rl.rules.get(made.start.rules[0], {})
	if str(start_rule.get("do", [])) != str([{"do": "start", "run": "Tower"}]):
		bad.append("start rule %s" % str(start_rule))
	say("presets", bad.is_empty(), "; ".join(lines) + ("" if bad.is_empty() else "; BAD " + "; ".join(bad)))
	return made


func _wheel_up() -> InputEventMouseButton:
	var w := InputEventMouseButton.new()
	w.button_index = MOUSE_BUTTON_WHEEL_UP
	w.pressed = true
	return w


func undo_case(made: Dictionary) -> void:
	var before := JSON.stringify(rl.save_part())
	var n0: int = rl.size()
	var bad := []
	var steps := []
	for kind: String in ["finish", "message", "hazard", "pad", "door", "coin", "checkpoint", "start"]:
		var zid: int = made[kind].zone
		var had: int = rl.size()
		await tap(KEY_Z, false, true)
		var gone: bool = not rl.zones.has(zid) and (made[kind].rules as Array).all(func(n: int) -> bool: return not rl.rules.has(n))
		steps.append("%s -%d" % [kind, had - rl.size()])
		if not gone:
			bad.append("%s still there after one undo" % kind)
	var empty: bool = rl.size() == 0
	for i in 8:
		await tap(KEY_Y, false, true)
	var back := JSON.stringify(rl.save_part()) == before
	say("undo", bad.is_empty() and empty and back, "one Ctrl+Z per preset: %s; empty %s; 8 Ctrl+Y: the same %d zones and rules again %s%s" % [
		", ".join(steps), empty, n0, back, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func delete_case(made: Dictionary) -> void:
	if str(t.get("armed")) != "":
		await tap(KEY_0)
	var zid: int = made.door.zone
	click(on_block(Vector3i(10, 1, 6), Vector3i(-1, 0, 0)))      # on the door's blocks: selects the door
	var sel: int = int(t.get("chosen"))
	var hist: int = b.edits.history.size()
	var n0: int = rl.size()
	await tap(KEY_DELETE)
	var gone: bool = not rl.zones.has(zid) and (made.door.rules as Array).all(func(n: int) -> bool: return not rl.rules.has(n))
	var one: bool = b.edits.history.size() == hist + 1
	var removed: int = n0 - rl.size()
	await tap(KEY_Z, false, true)
	var back: bool = rl.zones.has(zid) and (made.door.rules as Array).all(func(n: int) -> bool: return rl.rules.has(n))
	# Backspace on a coin
	click(ground(3, 0, 0))
	var csel: int = int(t.get("chosen"))
	await tap(KEY_BACKSPACE)
	var coin_gone: bool = not rl.zones.has(made.coin.zone)
	await tap(KEY_Z, false, true)
	var ok: bool = sel == zid and gone and one and removed == 3 and back and csel == made.coin.zone and coin_gone and rl.zones.has(made.coin.zone)
	say("delete", ok, "a click on the door's blocks selected zone %d (the door %d); Delete removed %d (the zone and its 2 rules) in one batch %s; undo back %s; a click on Coin selected %d, Backspace removed it %s, undo back %s" % [
		sel, zid, removed, one, back, csel, coin_gone, rl.zones.has(made.coin.zone)])


func field_case() -> void:
	var hb := HomeBuild.new(null, null, {})
	# a fresh Home for the field: the first Start asks
	var old: RefCounted = bm.get("build")
	bm.set("build", hb)
	var l: RefCounted = hb.layer("rules")
	await tap(KEY_1)
	click(ground(40, 0, 40))
	var bar: CanvasLayer = t.get("name_bar")
	var line: LineEdit = bar.get("line") if bar != null else null
	var asked: bool = bool(t.call("naming"))
	var shown: String = line.text if line != null else ""
	var selected: bool = line != null and line.has_selection() and line.get_selected_text() == shown
	var focus: bool = line != null and root.gui_get_focus_owner() == line
	var blocks: bool = bool(t.call("blocks_input"))
	line.text = "My run"
	CaseUtil.key(KEY_ENTER, true)             # held, as a person holds it: the field takes it, build mode must not
	await wait(1)
	if bar.call("is_open"):
		await push_key(KEY_ENTER)
	await wait(8)
	var held_ok: bool = str(bm.call("tool").get("id")) == "rules" and bool(bm.get("active")) and bool(t.call("blocks_input"))
	CaseUtil.key(KEY_ENTER, false)
	await wait(4)
	var after_ok: bool = str(bm.call("tool").get("id")) == "rules" and bool(bm.get("active")) and not bool(t.call("blocks_input"))
	var run1 := Presets.run_name(l)
	# Esc: a Message's text field, then Esc: nothing placed, still building
	var n0: int = l.size()
	await tap(KEY_8)
	click(ground(44, 0, 40))
	CaseUtil.key(KEY_ESCAPE, true)
	await wait(1)
	if bar.call("is_open"):
		await push_key(KEY_ESCAPE)
	await wait(4)
	var esc_none: bool = l.size() == n0
	var esc_ok: bool = bool(bm.get("active")) and esc_none and not bar.call("is_open")
	CaseUtil.key(KEY_ESCAPE, false)
	await wait(4)
	await tap(KEY_8)
	# a second Start: no field, the run's name again
	await tap(KEY_1)
	click(ground(48, 0, 40))
	var asked2: bool = bool(t.call("naming"))
	await tap(KEY_1)
	var starts := 0
	for n: int in l.rules:
		for e: Dictionary in l.rules[n].do:
			if str(e.do) == "start" and str(e.run) == "My run":
				starts += 1
	bm.set("build", old)
	var ok: bool = asked and shown == "Run 1" and selected and focus and blocks and held_ok and after_ok and run1 == "My run" and esc_ok and not asked2 and starts == 2
	say("field", ok, "the first Start asked: field '%s' selected %s focus %s, blocks_input %s; typed 'My run', Enter held 8 frames: tool %s, building %s, still latched %s; let go: free %s; run '%s'; a Message then Esc: building %s, nothing placed %s; a second Start asked %s, %d starts of 'My run'" % [
		shown, selected, focus, blocks, str(bm.call("tool").get("id")), bm.get("active"), held_ok, after_ok, run1, esc_ok, esc_none, asked2, starts])


func describe_case(made: Dictionary) -> void:
	var want := {
		"start": ["when you enter Start: start the run Tower"],
		"checkpoint": ["when you enter Checkpoint 1 if a run is going: checkpoint at Checkpoint 1, say \"Checkpoint\""],
		"coin": ["when you enter Coin 1: take Coin 1, add 1 to coins"],
		"door": ["when you press E in Door 1: open Door 1", "when you leave Door 1: close Door 1"],
		"pad": ["when you enter Jump pad 1: launch 10 m/s up, 4 m/s forward"],
		"hazard": ["when you enter Hazard 1: back to the respawn"],
		"message": ["when you enter Message 1: say \"Hello!\""],
		"finish": ["when you enter Finish if a run is going: finish the run"]}
	var bad := []
	var shown := []
	for kind: String in want:
		t.set("chosen", int(made[kind].zone))
		var c: Dictionary = t.call("card_of")
		var got: Array = c.get("lines", [])
		if str(got) != str(want[kind]):
			bad.append("%s: %s" % [kind, str(got)])
		shown.append("%s: %s" % [str(c.get("title", "")), " | ".join(got)])
	t.set("chosen", -1)
	var all: Dictionary = t.call("card_of")
	var n_lines: int = (all.get("lines", []) as Array).size()
	var title_ok: bool = str(all.get("title", "")).begins_with("Rules: 8 zones, 9 rules")
	say("describe", bad.is_empty() and n_lines == 9 and title_ok, "%s; nothing selected: '%s', %d lines%s" % [
		"; ".join(shown), str(all.get("title", "")), n_lines, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func knobs_case(made: Dictionary) -> void:
	var bad := []
	var seen := []
	# coin: ] twice -> value 3
	t.set("chosen", int(made.coin.zone))
	var h0: int = b.edits.history.size()
	await tap(KEY_BRACKETRIGHT)
	await tap(KEY_BRACKETRIGHT)
	var coin_by := int(Presets._effect(Presets.rules_naming(rl, made.coin.zone), "add").get("by", 0))
	seen.append("coin ] ] -> value %d (%d batches)" % [coin_by, b.edits.history.size() - h0])
	if coin_by != 3 or b.edits.history.size() != h0 + 2:
		bad.append("coin")
	# door: ] -> 1 s (3 rules), [ -> 0 (2 rules)
	t.set("chosen", int(made.door.zone))
	await tap(KEY_BRACKETRIGHT)
	var timed: Array = Presets.rules_naming(rl, made.door.zone)
	var timed_lines: Array = timed.map(func(r: Dictionary) -> String: return rl.describe(int(r.id)))
	var secs := Presets.door_seconds(timed)
	await tap(KEY_BRACKETLEFT)
	var back: Array = Presets.rules_naming(rl, made.door.zone)
	seen.append("door ] -> %d s, %d rules (%s); [ -> %d rules" % [secs, timed.size(), " | ".join(timed_lines), back.size()])
	if secs != 1 or timed.size() != 3 or back.size() != 2 or Presets.kind_of(rl, made.door.zone) != "door":
		bad.append("door")
	# pad: ] up +1 m/s, Shift+] forward +1 m/s
	t.set("chosen", int(made.pad.zone))
	await tap(KEY_BRACKETRIGHT)
	await tap(KEY_BRACKETRIGHT, true)
	var e := Presets._effect(Presets.rules_naming(rl, made.pad.zone), "launch")
	seen.append("pad ] Shift+] -> up %d fwd %d cm/s" % [int(e.get("up_cm", 0)), int(e.get("fwd_cm", 0))])
	if int(e.get("up_cm", 0)) != 1100 or int(e.get("fwd_cm", 0)) != 500:
		bad.append("pad")
	# message: G, a new text, Enter; ] shown 4 s
	t.set("chosen", int(made.message.zone))
	await tap(KEY_G)
	var line: LineEdit = (t.get("name_bar") as CanvasLayer).get("line")
	var was := line.text
	line.text = "Jump the gap"
	await push_key(KEY_ENTER)
	await wait(4)
	await tap(KEY_BRACKETRIGHT)
	var say_e := Presets._effect(Presets.rules_naming(rl, made.message.zone), "say")
	seen.append("message G '%s' -> '%s', ] -> %d frames" % [was, str(say_e.get("text", "")), int(say_e.get("frames", 0))])
	if was != "Hello!" or str(say_e.get("text", "")) != "Jump the gap" or int(say_e.get("frames", 0)) != 240:
		bad.append("message")
	var card: Dictionary = t.call("card_of")
	t.set("chosen", -1)
	say("knobs", bad.is_empty(), "; ".join(seen) + "; card keys: " + str(card.get("keys", "")).replace("\n", " | ") + ("" if bad.is_empty() else "; BAD " + ", ".join(bad)))


func ghost_case() -> void:
	var bad := []
	# preview_node over a preset's ops: one node (the new zone), holo
	var ops := Presets.ops(rl, "coin", Vector3i(20, 0, 20), Vector3i(20, 0, 20))
	var r: Dictionary = b.preview(ops)
	var n: Node3D = rl.preview_node(r.scratch.rules)
	var kids := n.get_child_count() if n != null else -1
	var plus: String = (n.get_child(0).get_node("Name") as Label3D).text if kids > 0 else ""
	# an LLM-like answer: two zones and a rule linking them (via preview_nodes, as the command tool shows it)
	var ans := [{"op": "zone", "id": rl.next_zone_id(), "box": [[30, 0, 30], [31, 1, 31]], "look": "pad", "name": "A"},
		{"op": "zone", "id": rl.next_zone_id() + 1, "box": [[36, 0, 30], [37, 1, 31]], "look": "none", "name": "B"},
		{"op": "rule", "id": rl.next_rule_id(), "when": {"on": "enter", "zone": rl.next_zone_id()}, "do": [{"do": "teleport", "zone": rl.next_zone_id() + 1}]}]
	var r2: Dictionary = b.preview(ans)
	var nodes: Array = b.preview_nodes(r2, ["blocks"])
	var rules_nodes: Array = nodes.filter(func(x: Node3D) -> bool: return str(x.get_meta(&"tl_layer", "")) == "rules")
	var two: int = (rules_nodes[0] as Node3D).get_child_count() if not rules_nodes.is_empty() else -1
	# a delete: the zone in red
	var del: Array = Presets.delete_ops(rl, int(rl.zones.keys().min()))
	var r3: Dictionary = b.preview(del)
	var n3: Node3D = rl.preview_node(r3.scratch.rules)
	var red_ok := false
	if n3 != null and n3.get_child_count() == 1:
		var fr: MeshInstance3D = n3.get_child(0).get_node("Frame")
		red_ok = fr.material_override != TLStyle.material("holo") and (n3.get_child(0).get_node("Name") as Label3D).text.begins_with("- ")
	# nothing changed: null
	var r4: Dictionary = b.preview([])
	var n4: Node3D = rl.preview_node(r4.scratch.rules)
	var null_ok := n4 == null
	var blocks_only: Dictionary = b.preview([{"op": "place", "at": [50, 0, 50], "shape": 1, "mat": 1, "rot": 0}])
	var n5: Node3D = rl.preview_node(blocks_only.scratch.rules)
	null_ok = null_ok and n5 == null
	# the tool's own ghost: Coin armed, a steady aim
	await tap(KEY_4)
	var h := ground(22, 0, 22)
	for i in 6:
		t.aim(h, {})
	var g: Array = t.call("ghost_nodes")
	var gk: int = (g[0] as Node3D).get_child_count() if not g.is_empty() else -1
	# refused: a coin at the top of the grid (2 cells high, the top out of range): red, the reason in the hotbar
	var hr := ground(22, 111, 22)
	for i in 6:
		t.aim(hr, {})
	var gr: Array = t.call("ghost_nodes")
	var red_tool := false
	if not gr.is_empty():
		var fr2: Node = (gr[0] as Node3D).get_node_or_null("Frame")
		red_tool = fr2 is MeshInstance3D and (fr2 as MeshInstance3D).material_override != TLStyle.material("holo")
	var why := str(t.get("reason"))
	var n_before: int = rl.size()
	click(hr)
	var none_placed: bool = rl.size() == n_before
	await tap(KEY_4)
	for x in [n, n3]:
		if x != null:
			x.free()
	for x: Node3D in nodes:
		x.free()
	var ok: bool = kids == 1 and plus == "+ Coin 2" and two == 2 and red_ok and null_ok and gk == 1 and red_tool and why.contains("out of range") and none_placed
	say("ghost", ok, "a coin preset's preview: %d node '%s'; an answer with 2 zones and a rule: %d nodes under the rules ghost (%d layer nodes); a delete: red %s; nothing changed / blocks only: null %s; the armed tool's ghost after a steady aim: %d node; at the grid's top: red %s, '%s', a click placed nothing %s" % [
		kids, plus, two, nodes.size(), red_ok, null_ok, gk, red_tool, why, none_placed])


func draw_case() -> void:
	await wait(2)
	var d: Node3D = t.get("drawer")
	var n_zones: int = rl.zones.size()
	var shown_build: bool = d != null and d.visible and d.get_child_count() == n_zones
	# another tool: still drawn
	await tap(KEY_T)
	await wait(2)
	var other: String = str(bm.call("tool").get("id"))
	var shown_other: bool = d.visible and d.get_child_count() == n_zones
	await tap(KEY_T, true)
	# selected: yellow
	t.set("chosen", int(rl.zones.keys().min()))
	await wait(2)
	var sel_node: Node3D = (d.get("parts") as Dictionary).get(int(rl.zones.keys().min()))
	var yellow: bool = sel_node != null and (sel_node.get_node("Frame") as MeshInstance3D).material_override != TLStyle.material("holo")
	t.set("chosen", -1)
	var card: CanvasLayer = t.get("card")
	var card_on: bool = card != null and (card.get("panel") as Control).visible
	# play: build mode off -> hidden
	await tap(KEY_B)
	await wait(2)
	var hidden: bool = not d.visible and not (card.get("panel") as Control).visible
	await tap(KEY_B)
	await wait(2)
	var ok: bool = shown_build and shown_other and other == "command" and yellow and card_on and hidden
	say("draw", ok, "building: %d zone nodes of %d shown %s; on %s too %s; the selected one yellow %s; the card on %s; build mode off: hidden %s" % [
		d.get_child_count() if d != null else -1, n_zones, shown_build, other, shown_other, yellow, card_on, hidden])


func runs_case(made: Dictionary) -> void:
	var rec := Rec.new()
	var rr: RefCounted = RulesRun.new(rl, rec)
	rec.run = weakref(rr)
	rr.begin(0, Vector3(-6, 0, -6))
	# [cell, frames, E down on the first frame]
	var path := [[Vector3i(-6, 0, -6), 3, false], [Vector3i(0, 0, 0), 3, false], [Vector3i(0, 0, 8), 3, false],
		[Vector3i(3, 0, 0), 3, false], [Vector3i(9, 0, 6), 3, true], [Vector3i(10, 0, 6), 3, false], [Vector3i(12, 0, 6), 3, false],
		[Vector3i(5, 0, 0), 3, false], [Vector3i(2, 0, 12), 3, false], [Vector3i(14, 0, 6), 3, false]]
	var f := 0
	for p: Array in path:
		for i: int in int(p[1]):
			f += 1
			rr.step(f, p[0], bool(p[2]) and i == 0)
	var kinds: Array = rec.log.map(func(e: Array) -> String: return str(e[1]))
	var want := ["run_started", "say", "look_taken", "set_open", "set_open", "launch", "teleport", "run_finished"]
	var door_z: int = made.door.zone
	var opened: Array = rec.log.filter(func(e: Array) -> bool: return str(e[1]) == "set_open" and int(e[2]) == door_z)
	var lau: Array = rec.log.filter(func(e: Array) -> bool: return str(e[1]) == "launch")
	var tel: Array = rec.log.filter(func(e: Array) -> bool: return str(e[1]) == "teleport")
	var ok1: bool = kinds == want and opened.size() == 2 and bool(opened[0][3]) and not bool(opened[1][3]) and int(lau[0][2]) == 1100 		and (tel[0][2] as Vector3).is_equal_approx(Vector3(1, 0, 9))
	# the timed door: 2 s
	t.call("set_knob", door_z, "seconds", 2)
	rec.log.clear()
	rr.begin(1000, Vector3(-6, 0, -6))
	f = 1000
	for i in 300:
		f += 1
		rr.step(f, Vector3i(9, 0, 6) if i < 2 else Vector3i(-6, 0, -6), i == 0)
	var tl: Array = rec.log.filter(func(e: Array) -> bool: return str(e[1]) == "set_open")
	var open_for: int = int(tl[1][0]) - int(tl[0][0]) if tl.size() == 2 else -1
	t.call("set_knob", door_z, "seconds", 0)
	var ok2: bool = tl.size() == 2 and bool(tl[0][3]) and not bool(tl[1][3]) and open_for > 60 and open_for <= 120
	say("runs", ok1 and ok2, "the course as placed: %s; door open frame %s, closed %s; launch %s; respawn at %s (the checkpoint's floor); a 2 s door: open %d frames%s" % [
		" > ".join(kinds), str(opened[0][0]) if opened.size() > 0 else "-", str(opened[1][0]) if opened.size() > 1 else "-",
		str(lau[0].slice(2)) if not lau.is_empty() else "-", str(tel[0][2]) if not tel.is_empty() else "-", open_for, "" if ok1 and ok2 else "; LOG " + str(rec.log)])
