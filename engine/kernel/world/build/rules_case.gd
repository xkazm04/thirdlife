extends SceneTree
## SEAM M6 (rules and runs, 27 Nov 2026): the seam's headless case (engine/tools/selftest.d/773-home-rules-seam.sh).
## No landscape: a bare builder, build mode mounted on it for the wiring. Prints `HOME rules-seam.<case> ok|fail
## <detail>`, then `HOME rules-seam ok` (or fail) and `HOME DONE`. Frames, not wall clock.
##   ops       every zone, unzone, rule and unrule refusal of contracts/BUILD.md "Milestone 6", one row per reason
##             (shapes, ids, caps, protected areas, zones a rule names, counters), none of them logged
##   undo      a batch of zones and rules applied, undone (unrule and unzone journaled whole) and redone; an unrule
##             and an unzone of the zone it names in one batch
##   files     tl.build/4 written in key order and loaded back byte for byte; a v3 Home loads and saves as v3 byte
##             for byte; build.json raised to v4 before the first zone op is journaled; a reader of max 3 refuses
##             v4 and leaves it; a v3 file with zones and unsorted or dangling entries are refused
##   renumber  an answer's zones and rules get the next free ids, its references follow, the Home's own stay, a
##             doubled id is refused (home_build.gd `expand_input`)
##   region    read_region's `zones` and `rules`, `room`, `ask_part`, `describe`
##   run, records, play   rules_case_run.gd

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const BuildFile := preload("res://kernel/world/build/build_file.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const Lists := preload("res://kernel/world/build/seam_lists.gd")
const CaseRun := preload("res://kernel/world/build/rules_case_run.gd")
const TMP := "user://tl_rules_seam_case"
const SEED := 11

var ok_all := true


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME rules-seam.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func run() -> void:
	TLStyle.set_headless(false)
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	DirAccess.make_dir_recursive_absolute(TMP)
	ops()
	undo()
	files()
	renumber()
	region()
	var r: RefCounted = CaseRun.new(TMP)
	for c: Array in [r.call("run"), r.call("records")]:
		say(str(c[0]), bool(c[1]), str(c[2]))
	var p: Array = await r.call("play", root, self)
	say(str(p[0]), bool(p[1]), str(p[2]))
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	print("HOME rules-seam %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


static func zone(n: int, lo: Array, hi: Array, look := "pad", name := "") -> Dictionary:
	var z := {"op": "zone", "id": n, "box": [lo, hi], "look": look}
	if name != "":
		z["name"] = name
	return z


static func rule(n: int, when: Dictionary, effects: Array, conds: Array = []) -> Dictionary:
	var r := {"op": "rule", "id": n, "when": when, "do": effects}
	if not conds.is_empty():
		r["if"] = conds
	return r


static func _with(op: Dictionary, k: String, v: Variant) -> Dictionary:
	var o := op.duplicate(true)
	o[k] = v
	return o


static func _without(op: Dictionary, k: String) -> Dictionary:
	var o := op.duplicate(true)
	o.erase(k)
	return o


static func un(op: Dictionary) -> Dictionary:
	return _with(op, "op", "un" + str(op.op))


# ------------------------------------------------------------------ ops
func ops() -> void:
	var b: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	b.protect.add_circle(Vector2(500, 500), 10.0, "game lot")
	b.protect.add_box(AABB(Vector3(600, 0, 600), Vector3(4, 10, 4)), "authored structure (mill)")
	var Z: Dictionary = Lists.M6_EXAMPLES.zone
	var R: Dictionary = Lists.M6_EXAMPLES.rule
	var enter := {"on": "enter", "zone": 1}
	var fin := [{"do": "finish"}]
	var nine := []
	for i in 9:
		nine.append({"running": true})
	var malformed := [
		[_with(Z, "size", 3), "unknown key 'size'"], [_without(Z, "id"), "id is missing"], [_without(Z, "box"), "box is missing"],
		[_without(Z, "look"), "look is missing"], [_with(Z, "id", 0), "id must be a positive integer"],
		[_with(Z, "box", [[0, 5, 0]]), "box must be [[x0, y0, z0], [x1, y1, z1]]"],
		[_with(Z, "box", [[0, 5, 0], [1.5, 6, 1]]), "box: each corner is [x, y, z] of integers"],
		[_with(Z, "box", [[2, 5, 0], [0, 7, 2]]), "box: x0 <= x1, y0 <= y1 and z0 <= z1"],
		[_with(Z, "box", [[0, 5, 0], [64, 7, 2]]), "box: at most 64 cells a side (65 x 3 x 3)"],
		[_with(Z, "box", [[0, 110, 0], [1, 112, 1]]), "box: out of range (y -16..111)"],
		[_with(Z, "box", [[200000, 5, 0], [200001, 5, 0]]), "box: outside the Home"],
		[_with(Z, "look", "lava"), "look must be one of none, pad, coin, flag"],
		[_with(Z, "name", ""), "name must be 1-24 printable characters"], [_with(Z, "name", "x".repeat(25)), "name must be 1-24"],
		[_with(Z, "name", "a\nb"), "name must be 1-24"], [_with(Z, "v", 2), "v must be 1"],
		[_with(Z, "author", "bot"), "author must be \"hand\" or \"llm\""],
		[_with(R, "size", 3), "unknown key 'size'"], [_without(R, "id"), "id is missing"], [_without(R, "when"), "when is missing"],
		[_without(R, "do"), "do is missing"], [_with(R, "when", "enter"), "when: a trigger is an object"],
		[_with(R, "when", {"on": "jump"}), "when: on must be one of enter, leave, use, every, count, start, finish"],
		[_with(R, "when", {"on": "enter"}), "when: zone is missing"],
		[_with(R, "when", {"on": "enter", "zone": 1, "frames": 60}), "when: unknown key 'frames'"],
		[_with(R, "when", {"on": "use", "zone": -1}), "when: zone must be a positive integer"],
		[_with(R, "when", {"on": "every", "frames": 59}), "when: frames must be an integer 60..36000"],
		[_with(R, "when", {"on": "every", "frames": 36001}), "when: frames must be an integer 60..36000"],
		[_with(R, "when", {"on": "count", "counter": "Coins", "at": 3}), "when: counter must be 1-16 of a-z and _"],
		[_with(R, "when", {"on": "count", "counter": "coins", "at": 0}), "when: at must be an integer 1..999"],
		[_with(R, "when", {"on": "start", "zone": 1}), "when: unknown key 'zone'"],
		[_with(R, "if", []), "if must be a non-empty list (omit it when empty)"], [_with(R, "if", nine), "if: at most 8 conditions"],
		[_with(R, "if", [3]), "if: every condition is an object"], [_with(R, "if", [{"running": "yes"}]), "if: running must be true or false"],
		[_with(R, "if", [{"running": true, "counter": "a"}]), "if: {\"running\": true|false} stands alone"],
		[_with(R, "if", [{"counter": "a"}]), "if: counter a needs min or max"],
		[_with(R, "if", [{"min": 1}]), "if: a condition is"], [_with(R, "if", [{"counter": "a", "most": 3}]), "if: unknown key 'most'"],
		[_with(R, "if", [{"counter": "a", "min": 1000}]), "if: min must be an integer 0..999"],
		[_with(R, "if", [{"counter": "a", "min": 5, "max": 3}]), "if: min is above max"],
		[_with(R, "if", [{"counter": "A1", "min": 1}]), "if: counter must be 1-16 of a-z and _"],
		[_with(R, "do", []), "do must be 1-8 effects"], [_with(R, "do", fin + fin + fin + fin + fin + fin + fin + fin + fin), "do must be 1-8 effects"],
		[_with(R, "do", [3]), "do: every effect is an object"], [_with(R, "do", [{"do": "fly"}]), "do: 'fly' is not an effect"],
		[_with(R, "do", [{"do": "start"}]), "do[0] start: run is missing"],
		[_with(R, "do", [{"do": "finish", "zone": 1}]), "do[0] finish: unknown key 'zone'"],
		[_with(R, "do", [{"do": "start", "run": ""}]), "do[0] start: run must be 1-24 printable characters"],
		[_with(R, "do", [{"do": "add", "counter": "a", "by": 0}]), "do[0] add: by must be an integer -99..99, not 0"],
		[_with(R, "do", [{"do": "add", "counter": "a", "by": 100}]), "do[0] add: by must be"],
		[_with(R, "do", [{"do": "add", "counter": "x-y", "by": 1}]), "do[0] add: counter must be 1-16 of a-z and _"],
		[_with(R, "do", [{"do": "launch", "up_cm": 3001, "fwd_cm": 0}]), "do[0] launch: up_cm must be an integer 0..3000"],
		[_with(R, "do", [{"do": "launch", "up_cm": 0, "fwd_cm": -1}]), "do[0] launch: fwd_cm must be an integer 0..3000"],
		[_with(R, "do", [{"do": "say", "text": "x".repeat(61), "frames": 60}]), "do[0] say: text must be 1-60 printable characters"],
		[_with(R, "do", [{"do": "say", "text": "hi", "frames": 29}]), "do[0] say: frames must be an integer 30..600"],
		[_with(R, "do", fin + [{"do": "open", "zone": "door"}]), "do[1] open: zone must be a positive integer"]]
	var bad := []
	var seen := 0
	for row: Array in malformed:
		var why := str(b.apply(row[0]).reason)
		seen += 1
		if not why.begins_with(str(row[1])):
			bad.append("'%s' want '%s'" % [why, row[1]])
	var strict := str(b.edits.validate({"v": 1, "op": "zone", "id": 1, "box": [[0, 5, 0], [1, 5, 1]], "look": "pad", "author": "hand"}, true))
	if strict != "batch is missing":
		bad.append("a journal zone line without batch: '%s'" % strict)
	# the rules over the Home
	var lot := str(b.apply(zone(5, [495, 5, 495], [497, 6, 497])).reason)
	var mill := str(b.apply(zone(5, [598, 5, 598], [601, 6, 601])).reason)
	var z1 := str(b.apply(Z).reason)
	var cases := [
		[Z, "id 1 is taken (the next free id is 2)"], [zone(9, [0, 0, 0], [0, 0, 0]).merged({"op": "unzone"}, true), "no zone 9"],
		[_with(un(Z), "look", "coin"), "zone 1 is another zone (unzone carries the whole zone)"],
		[rule(5, {"on": "enter", "zone": 9}, fin), "rule 5 names zone 9, which is not there"],
		[rule(5, {"on": "start"}, [{"do": "teleport", "zone": 7}]), "rule 5 names zone 7, which is not there"]]
	var r1 := str(b.apply(R).reason)
	cases.append_array([[un(Z), "zone 1 is named by rule 1 (remove the rule first, in the same batch)"],
		[R, "id 1 is taken (the next free id is 3)"], [rule(9, enter, fin).merged({"op": "unrule"}, true), "no rule 9"],
		[_with(un(R), "do", fin), "rule 1 is another rule (unrule carries the whole rule)"]])
	var counters := []
	for c: String in ["a", "b", "c", "d", "e", "f", "g", "h"]:
		counters.append({"do": "add", "counter": c, "by": 1})
	var eight := str(b.apply(rule(2, {"on": "start"}, counters)).reason)
	cases.append([rule(3, {"on": "count", "counter": "i", "at": 1}, fin), "the Home has 8 counters (a, b, c, d, e, f, g, h): 'i' would pass 8"])
	for row: Array in cases:
		var n0: int = b.edits.history.size()
		var why := str(b.apply(row[0]).reason)
		seen += 1
		if why != str(row[1]) or b.edits.history.size() != n0:
			bad.append("'%s' want '%s'" % [why, row[1]])
	if lot != "game lot" or mill != "authored structure (mill)" or z1 != "" or r1 != "" or eight != "":
		bad.append("game lot '%s', box '%s', zone 1 '%s', rule 1 '%s', eight counters '%s'" % [lot, mill, z1, r1, eight])
	# the caps: 512 zones, 512 rules
	var c: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	var many := []
	for i in 512:
		many.append(zone(i + 1, [i * 2, 0, 0], [i * 2, 0, 0], "none"))
	var a512: int = c.apply(many).applied
	var z513 := str(c.apply(zone(513, [0, 9, 0], [0, 9, 0])).reason)
	many.clear()
	for i in 512:
		many.append(rule(i + 1, {"on": "enter", "zone": i + 1}, fin))
	var r512: int = c.apply(many).applied
	var r513 := str(c.apply(rule(513, {"on": "start"}, fin)).reason)
	if a512 != 512 or z513 != "the Home holds 512 zones" or r512 != 512 or r513 != "the Home holds 512 rules":
		bad.append("caps: %d zones then '%s', %d rules then '%s'" % [a512, z513, r512, r513])
	seen += 2
	say("ops", bad.is_empty(), "%d refusals as the contract (%d shapes, %d Home rules, 2 caps), journal line without batch '%s'; game lot '%s', a box '%s'; none logged%s" % [
		seen, malformed.size(), cases.size(), strict, lot, mill, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


# ------------------------------------------------------------------ undo
func undo() -> void:
	var bad := []
	var d := TMP.path_join("undo")
	var b: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	b.save(d)
	var batch := [zone(1, [0, 5, 0], [2, 7, 2], "coin", "Coin"), zone(2, [4, 5, 0], [4, 7, 0], "none", "Door"),
		rule(1, {"on": "enter", "zone": 1}, [{"do": "take", "zone": 1}, {"do": "add", "counter": "coins", "by": 1}]),
		rule(2, {"on": "use", "zone": 2}, [{"do": "toggle", "zone": 2}], [{"counter": "coins", "min": 1}])]
	var r: Dictionary = b.apply(batch)
	var l: RefCounted = b.layer("rules")
	var after := [l.zones.size(), l.rules.size()]
	var undone: int = b.undo()
	var gone := [l.zones.size(), l.rules.size()]
	var redone: int = b.redo()
	var back := [l.zones.size(), l.rules.size(), l.content_hash()]
	var lines: Array = FileAccess.get_file_as_string(d.path_join("edits.jsonl")).strip_edges().split("\n")
	var kinds: Array = lines.map(func(x: String) -> String: return str((JSON.parse_string(x) as Dictionary).op))
	var unr2: Dictionary = JSON.parse_string(lines[4])           # the undo: unrule 2, unrule 1, unzone 2, unzone 1
	var unr: Dictionary = JSON.parse_string(lines[5])
	var unz: Dictionary = JSON.parse_string(lines[6])
	if not r.ok or after != [2, 2] or undone != 4 or gone != [0, 0] or redone != 4 or back.slice(0, 2) != [2, 2]:
		bad.append("applied %s, after %s, undo %d -> %s, redo %d -> %s" % [str(r.refused), str(after), undone, str(gone), redone, str(back)])
	if kinds != ["zone", "zone", "rule", "rule", "unrule", "unrule", "unzone", "unzone", "zone", "zone", "rule", "rule"]:
		bad.append("journal %s" % str(kinds))
	if unr2.keys() != ["v", "op", "id", "when", "if", "do", "author", "batch"] or unr.keys() != ["v", "op", "id", "when", "do", "author", "batch"] 			or unz.keys() != ["v", "op", "id", "box", "look", "name", "author", "batch"] or str(unz.box) != "[[4.0, 5.0, 0.0], [4.0, 7.0, 0.0]]" and str(unz.box) != "[[4, 5, 0], [4, 7, 0]]":
		bad.append("undo lines %s / %s / %s" % [str(unr2.keys()), str(unr.keys()), str(unz)])
	# an unrule and an unzone of the zone it names, in one batch; its undo puts the zone back before the rule
	var both: Dictionary = b.apply([un(batch[3]), un(batch[1])])
	var one_undo: int = b.undo()
	if not both.ok or one_undo != 2 or l.zones.size() != 2 or l.rules.size() != 2:
		bad.append("unrule + unzone in a batch: %s, undo %d -> %d zones %d rules" % [str(both.refused), one_undo, l.zones.size(), l.rules.size()])
	var c: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	var lr: Dictionary = c.load(d)
	if not lr.ok or int(lr.replayed) != lines.size() + 4 or c.layer("rules").content_hash() != l.content_hash():
		bad.append("journal replay %s" % str(lr))
	say("undo", bad.is_empty(), "a batch of 2 zones and 2 rules: undo %d ops (journal %s), redo %d; unrule then unzone in one batch, undone together; the journal replays to the same rules (%d lines)%s" % [
		undone, ",".join(kinds.slice(4, 8)), redone, int(lr.replayed), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


# ------------------------------------------------------------------ files
static func _text(d: String) -> String:
	return FileAccess.get_file_as_string(d.path_join("build.json"))


static func _write(d: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(d)
	var f := FileAccess.open(d.path_join("build.json"), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func files() -> void:
	var bad := []
	# a v3 Home (plants) loads and saves as v3, byte for byte
	var b: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	b.place(Vector3i(3, 4, 5), Blocks.code(Blocks.CUBE, 2))
	var pl := str(b.apply({"op": "plant", "cells": [[1, 2, "valley", "meadow"]]}).reason)
	var d3 := TMP.path_join("v3")
	b.save(d3)
	var t3 := _text(d3)
	var c3: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	var r3: Dictionary = c3.load(d3)
	c3.save(TMP.path_join("v3-again"))
	var same3 := _text(TMP.path_join("v3-again")) == t3
	if pl != "" or not t3.begins_with("{\"v\":3,") or not r3.ok or not same3:
		bad.append("v3: plant '%s', %s..., load %s, re-saved same %s" % [pl, t3.substr(0, 8), str(r3.reason), same3])
	# v4: zones and rules after every v3 key, loaded back, re-saved byte for byte
	var ops := [zone(2, [0, 5, 0], [2, 7, 2], "coin", "Coin"), zone(1, [-3, -2, 9], [-1, 0, 9], "flag"),
		rule(1, {"on": "enter", "zone": 2}, [{"do": "take", "zone": 2}, {"do": "add", "counter": "coins", "by": 1}]),
		rule(4, {"on": "every", "frames": 600}, [{"do": "say", "text": "Ten seconds", "frames": 120}], [{"running": true}])]
	var ra: Dictionary = b.apply(ops)
	var d4 := TMP.path_join("v4")
	b.save(d4)
	var t4 := _text(d4)
	var order := t4.begins_with("{\"v\":4,\"seed\":11,\"rev\":") and t4.find("\"plants\":") < t4.find("\"zones\":") and t4.find("\"zones\":") < t4.find("\"rules\":") \
		and t4.find("{\"id\":1,\"box\":[[-3,-2,9],[-1,0,9]],\"look\":\"flag\"}") > 0 and t4.find("\"if\":[{\"running\":true}]") > 0
	var c4: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	var r4: Dictionary = c4.load(d4)
	c4.save(TMP.path_join("v4-again"))
	var same4 := _text(TMP.path_join("v4-again")) == t4
	if not ra.ok or not order or not r4.ok or int(r4.v) != 4 or not same4 or c4.layer("rules").content_hash() != b.layer("rules").content_hash():
		bad.append("v4: %s, order %s (%s), load %s, re-saved same %s" % [str(ra.refused), order, t4.substr(t4.find("\"zones\""), 80), str(r4), same4])
	# a reader of max 3 refuses v4 and leaves it; a v3 file with zones; malformed saved entries
	var c5: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	var old: Dictionary = BuildFile.load_into(d4, c5.layers, c5.edits, SEED, 3)
	var left := _text(d4) == t4
	var refusals := {}
	for k: String in ["v3 zones", "unsorted", "dangling", "unknown key"]:
		var text := ""
		match k:
			"v3 zones": text = "{\"v\":3,\"seed\":11,\"rev\":1,\"chunks\":{},\"zones\":[]}\n"
			"unsorted": text = "{\"v\":4,\"seed\":11,\"rev\":1,\"chunks\":{},\"zones\":[{\"id\":2,\"box\":[[0,0,0],[0,0,0]],\"look\":\"pad\"},{\"id\":1,\"box\":[[0,0,0],[0,0,0]],\"look\":\"pad\"}]}\n"
			"dangling": text = "{\"v\":4,\"seed\":11,\"rev\":1,\"chunks\":{},\"rules\":[{\"id\":1,\"when\":{\"on\":\"enter\",\"zone\":3},\"do\":[{\"do\":\"finish\"}]}]}\n"
			"unknown key": text = "{\"v\":4,\"seed\":11,\"rev\":1,\"chunks\":{},\"zones\":[{\"id\":1,\"box\":[[0,0,0],[0,0,0]],\"look\":\"pad\",\"op\":\"zone\"}]}\n"
		_write(TMP.path_join(k), text)
		refusals[k] = str(HomeBuild.new(null, null, {"seed": SEED}).load(TMP.path_join(k)).reason).get_file()
	var want := {"v3 zones": "build.json: unknown key 'zones'", "unsorted": "build.json: zones: ids are unique and sorted (1 after 2)",
		"dangling": "build.json: rules: rule 1 names zone 3, which is not there", "unknown key": "build.json: zones: unknown key 'op'"}
	if old.ok or not str(old.reason).contains("tl.build/4 is newer than this exe reads (1..3)") or not left or refusals != want:
		bad.append("max-3 reader '%s', file kept %s; refusals %s" % [str(old.reason), left, str(refusals)])
	# build.json is raised to v4 before the first zone op is journaled
	var dm := TMP.path_join("mark4")
	var e: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	e.place(Vector3i(1, 1, 1), Blocks.code(Blocks.CUBE, 1))
	e.save(dm)
	var before := _text(dm)
	var seen := []
	var hook: Callable = e.edits.before_journal
	e.edits.before_journal = func(rec: Dictionary) -> String:
		var why := str(hook.call(rec))
		seen.append([_text(dm).substr(0, 7), FileAccess.get_file_as_string(dm.path_join("edits.jsonl")).length(), rec.op])
		return why
	e.apply(zone(1, [0, 0, 0], [1, 1, 1]))
	e.apply(zone(2, [3, 0, 0], [3, 1, 1]))
	var marked := _text(dm) == "{\"v\":4," + before.substr(7)
	if str(seen) != str([["{\"v\":4,", 0, "zone"]]) or not marked:
		bad.append("mark: %s, content kept %s" % [str(seen), marked])
	var f: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	var rf: Dictionary = f.load(dm)
	e.undo()
	e.undo()
	e.edits.before_journal = hook
	e.save(dm)
	var v1_again := _text(dm).begins_with("{\"v\":1,")
	if not rf.ok or int(rf.replayed) != 2 or f.layer("rules").zones.size() != 2 or not v1_again:
		bad.append("replay over v4 %s; undo + save -> v1 %s" % [str(rf), v1_again])
	say("files", bad.is_empty(), "v3 %d B loads and re-saves byte for byte; v4 %d B (zones, rules after plants) loads back v%d and re-saves byte for byte; max-3 reader: '%s', file kept %s; refused: %s; v1 -> v4 before the first zone line (%s), replayed %d; undo + save -> v1 %s%s" % [
		t3.length(), t4.length(), int(r4.v), str(old.reason).get_slice(": ", 1), left, str(refusals.values()), str(seen), int(rf.replayed), v1_again,
		"" if bad.is_empty() else "; BAD " + "; ".join(bad)])


# ------------------------------------------------------------------ renumber
func renumber() -> void:
	var bad := []
	var b: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	b.apply([zone(1, [0, 0, 0], [0, 0, 0]), zone(2, [2, 0, 0], [2, 0, 0]), zone(3, [4, 0, 0], [4, 0, 0], "flag", "Goal"),
		rule(1, {"on": "enter", "zone": 3}, [{"do": "finish"}])])
	var answer := [
		{"op": "place", "at": [9, 0, 9], "shape": 1, "mat": 1, "rot": 0, "author": "llm"},
		zone(1, [10, 0, 0], [11, 1, 1], "flag", "Start"), zone(2, [14, 0, 0], [14, 2, 0], "none", "Door"),
		rule(1, {"on": "enter", "zone": 1}, [{"do": "start", "run": "Dash"}, {"do": "open", "zone": 2}, {"do": "teleport", "zone": 3}]),
		rule(2, {"on": "enter", "zone": 3}, [{"do": "say", "text": "Goal", "frames": 60}]),
		{"op": "unzone", "id": 1, "box": [[0, 0, 0], [0, 0, 0]], "look": "pad"},
		zone(1, [20, 0, 0], [20, 0, 0])]
	var ex: Dictionary = b.expand_input(answer)
	var got: Array = ex.ops
	var want_ids := [null, 4, 5, 2, 3, 1]
	var ids: Array = got.map(func(o: Dictionary) -> Variant: return o.get("id"))
	var refs := [got[3].when.zone, got[3].do[1].zone, got[3].do[2].zone, got[4].when.zone]
	if ids != want_ids or refs != [4, 5, 3, 3] or str(ex.refused) != str([[6, "the answer names zone 1 twice"]]) or got[0] != answer[0]:
		bad.append("ids %s want %s, refs %s want [4, 5, 3, 3], refused %s" % [str(ids), str(want_ids), str(refs), str(ex.refused)])
	if answer[1].id != 1 or answer[3].when.zone != 1:
		bad.append("the answer itself was changed")
	var pv: Dictionary = b.preview(got)
	var sc: RefCounted = pv.scratch.rules
	if not pv.ok or sc.zones.keys().size() != 4 or not sc.rules.has(3) or b.layer("rules").zones.size() != 3:
		bad.append("preview %s, scratch zones %s, Home zones %d" % [str(pv.refused), str(sc.zones.keys()), b.layer("rules").zones.size()])
	say("renumber", bad.is_empty(), "answer zones 1, 2 -> %s, rules 1, 2 -> %s; references -> %s (zone 3 is the Home's and stays); unzone 1 unchanged; %s; the dry run takes it whole (%d applied), the Home untouched%s" % [
		str(ids.slice(1, 3)), str(ids.slice(3, 5)), str(refs), str(ex.refused), int(pv.applied), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


# ------------------------------------------------------------------ region
func region() -> void:
	var bad := []
	var b: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	var empty: Dictionary = b.read_region(Vector3i(0, 0, 0), Vector3i(10, 10, 10))
	b.apply([zone(1, [0, 5, 0], [2, 7, 2], "coin", "Coin"), zone(2, [50, 5, 0], [52, 7, 2], "none", "Door"), zone(3, [8, 9, 8], [12, 12, 12], "pad"),
		rule(1, {"on": "enter", "zone": 1}, [{"do": "take", "zone": 1}, {"do": "add", "counter": "coins", "by": 1}]),
		rule(2, {"on": "use", "zone": 2}, [{"do": "toggle", "zone": 2}], [{"counter": "coins", "min": 3}]),
		rule(3, {"on": "every", "frames": 300}, [{"do": "say", "text": "Five seconds", "frames": 90}], [{"running": true}]),
		rule(4, {"on": "enter", "zone": 3}, [{"do": "launch", "up_cm": 1250, "fwd_cm": 300}, {"do": "add", "counter": "hops", "by": -2}]),
		rule(5, {"on": "count", "counter": "coins", "at": 3}, [{"do": "start", "run": "Tower"}, {"do": "checkpoint", "zone": 3}, {"do": "respawn"}])])
	var r: Dictionary = b.read_region(Vector3i(0, 0, 0), Vector3i(10, 10, 10))
	var zs: Array = (r.get("zones", []) as Array).map(func(z: Dictionary) -> int: return int(z.id))
	var rs: Array = (r.get("rules", []) as Array).map(func(x: Dictionary) -> int: return int(x.id))
	var l: RefCounted = b.layer("rules")
	var room: Dictionary = l.room()
	var part: Dictionary = l.ask_part(Vector3i(0, 0, 0), Vector3i(10, 10, 10))
	var lines := []
	for n: int in [1, 2, 3, 4, 5]:
		lines.append(l.describe(n))
	var want_lines := ["when you enter Coin: take Coin, add 1 to coins", "when you press E in Door if coins is at least 3: open or close Door",
		"every 5 s if a run is going: say \"Five seconds\"", "when you enter zone 3: launch 12.50 m/s up, 3 m/s forward, take 2 from hops",
		"when coins reaches 3: start the run Tower, checkpoint at zone 3, back to the respawn"]
	if empty.has("zones") or empty.has("rules") or zs != [1, 3] or rs != [1, 3, 4, 5] or str(r.zones[0]) != str({"id": 1, "box": [[0, 5, 0], [2, 7, 2]], "look": "coin", "name": "Coin"}):
		bad.append("read_region zones %s rules %s (want [1, 3], [1, 3, 4, 5]); empty Home %s" % [str(zs), str(rs), str(empty.keys())])
	if str(room) != str({"zones_left": 509, "rules_left": 507, "counters": ["coins", "hops"]}) or part.keys() != ["zones", "rules", "rules_room"]:
		bad.append("room %s, ask_part keys %s" % [str(room), str(part.keys())])
	if lines != want_lines:
		bad.append("describe %s" % str(lines))
	say("region", bad.is_empty(), "a box meets zones %s, rules %s (and the zoneless rule 3); an empty Home adds no key; room %s; ask_part %s; describe: %s%s" % [
		str(zs), str(rs), str(room), str(part.keys()), " | ".join(lines), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])
