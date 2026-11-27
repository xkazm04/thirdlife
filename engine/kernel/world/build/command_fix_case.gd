extends "res://kernel/world/build/command_m6_case.gd"
## Round 2 lane C (27 Nov 2026): "fix it" and the space check's findings, headless, on command_m6_case.gd's stone
## platform with its DRY Foreman door and FAKE answer files. Two groups, chosen by the first user argument:
##   fix        (selftest 786, `HOME command-fix ...`)
##     command-fix.offer   a floating-block answer: the ghost's hotbar note ends "R: fix it", the hint names R; a clean
##                         answer offers nothing and R there sends nothing
##     command-fix.flow    R on the floating ghost sends ONE fix ask: the same sentence and spot, measured again, with
##                         `fix.ops` (the answer's ops) and `fix.findings` (naming the floating cell); the ghost stays
##                         while it waits; the fake Foreman's corrected answer replaces it, the new ghost has no
##                         warning, and only Enter keeps it (one batch)
##     command-fix.calls   the fix is a call: the day's count went up by one per ask; the calls log holds the first call
##                         "accepted": false (reverted: replaced by its fix) and the fix "fix: <sentence>", kept; the
##                         second argument names a file the log is copied to (the shell script runs `tl ledger` on it)
##   findings   (selftest 787, `HOME command-findings ...`)
##     command-findings.floating  the findings name the floating cell, the pad with no floor (zone, box) and the coin in a
##                         block, one line each
##     command-findings.gap       a 5-cell gap: "a gap too wide: ... 6.0 m across (5 empty cells)" and the climb from
##                         the platform "2.0 m up"; the 1-cell gap has no finding (round 3: 3 m + 1 m up is past the body)
##     command-findings.wall      a flag on a 2-block pillar beside the start: "a climb too high ... 2.0 m up"

var group := "fix"
var calls_out := ""


func cases() -> void:
	var args := OS.get_cmdline_user_args()
	group = args[0] if args.size() >= 1 else "fix"
	calls_out = args[1] if args.size() >= 2 else ""
	prefix = "command-" + group
	if group == "fix":
		await offer_case()
		await flow_case()
	else:
		await findings_floating()
		await findings_reach()


func floating_ops() -> Array:
	var x: int = site.x + 6
	var y: int = site.top
	return [place([x, y + 3, site.z + 4], 1, 1), place([x + 1, y, site.z + 4], 1, 1),
		zone(1, [x, y + 5, site.z + 8], [x + 1, y + 5, site.z + 9], "pad", "Sky"),
		zone(2, [x + 1, y, site.z + 4], [x + 1, y, site.z + 4], "coin")]


# ------------------------------------------------------------------ fix
func offer_case() -> void:
	var shown := await ghost("a clean wall", [place([site.x + 6, site.top, site.z + 4], 1, 1)], "A stone.")
	var clean_info := str(t.call("status").info)
	var clean_hint := str(t.call("hint"))
	var asked0: int = t.get("asked")
	await tap(KEY_R)
	var none_sent: bool = int(t.get("asked")) == asked0 and (t.get("pending") as Array).is_empty()
	await key_on_ghost(KEY_ESCAPE)
	var bad := await ghost("a block in the air", floating_ops(), "A floating block.")
	var info := str(t.call("status").info)
	var hint := str(t.call("hint"))
	var ok: bool = not shown.is_empty() and not bad.is_empty() and not clean_info.contains("R: fix it") and not clean_hint.contains("R fix it") and \
		none_sent and info.ends_with("R: fix it") and hint.contains("R fix it")
	say("offer", ok, "clean: note '%s', hint '%s', R sent nothing %s; floating: note '%s', hint '%s'" % [clean_info, clean_hint, none_sent, info, hint])


func flow_case() -> void:
	var first: Dictionary = t.get("shown")          # the floating ghost of offer_case
	if first.is_empty():
		say("flow", false, "no floating ghost to fix: %s" % str(t.call("status")))
		return
	var used0: int = (t.get("calls") as RefCounted).call("used_today")
	var hist: int = (b.edits.history as Array).size()
	await tap(KEY_R)
	var pend: Array = t.get("pending")
	var fixp: Dictionary = pend[pend.size() - 1] if not pend.is_empty() else {}
	var a: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(fixp.get("ask", "")))) if not fixp.is_empty() else {}
	var fx: Dictionary = a.get("fix", {})
	var findings: Array = fx.get("findings", [])
	var float_cell := "(%d, %d, %d)" % [site.x + 6, site.top + 3, site.z + 4]
	var still: bool = str((t.get("shown") as Dictionary).get("id", "")) == str(first.id)
	var waiting := str(t.call("status").info)
	await tap(KEY_R)                                # a second R while the fix is asked sends nothing more
	var one_ask: bool = (t.get("pending") as Array).size() == 1
	var fixed_ops := [place([site.x + 6, site.top, site.z + 4], 1, 1), place([site.x + 6, site.top + 1, site.z + 4], 1, 1),
		place([site.x + 6, site.top + 2, site.z + 4], 1, 1), place([site.x + 6, site.top + 3, site.z + 4], 1, 1)]
	if not fixp.is_empty():
		answer_for(fixp, fixed_ops, "The block now stands on a stone pillar.")
	await wait(20)
	var now: Dictionary = t.get("shown")
	var info := str(t.call("status").info)
	var applied_before_enter: bool = (b.edits.history as Array).size() != hist
	await key_on_ghost(KEY_ENTER)
	var batches := (b.edits.history as Array).size() - hist
	var used1: int = (t.get("calls") as RefCounted).call("used_today")
	var ok: bool = not fixp.is_empty() and str(fixp.get("replaces", "")) == str(first.id) and str(a.get("sentence")) == str(first.sentence) and \
		(fx.get("ops", []) as Array) == (first.answer.ops as Array) and findings.any(func(f: String) -> bool: return f.contains(float_cell)) and \
		still and waiting.contains("fixing...") and one_ask and not now.is_empty() and str(now.get("id")) == str(fixp.get("id")) and \
		str(now.space.line) == "" and not info.contains("check:") and not applied_before_enter and batches == 1 and used1 == used0 + 1
	say("flow", ok, "R: fix ask %s replaces %s, sentence same %s, fix.ops %d (= the answer's), findings %s; old ghost kept while waiting %s ('%s'); second R: one ask %s; new ghost %s, note '%s'; nothing applied before Enter %s; Enter: %d batch; calls today %d -> %d" % [
		str(fixp.get("id")), str(first.id), str(a.get("sentence")) == str(first.sentence), (fx.get("ops", []) as Array).size(), JSON.stringify(findings),
		still, waiting, one_ask, str(now.get("id")), info, not applied_before_enter, batches, used0, used1])
	var lines: Array = (t.get("calls") as RefCounted).call("calls")
	var by := {}
	for l: Dictionary in lines:
		by[str(l.id)] = l
	var old: Dictionary = by.get(str(first.id), {})
	var fixed: Dictionary = by.get(str(fixp.get("id", "")), {})
	var cok: bool = old.get("accepted") == false and not old.has("error") and fixed.get("accepted") == true and \
		str(fixed.get("sentence")) == "fix: " + str(first.sentence)
	if calls_out != "":
		var src := ProjectSettings.globalize_path(TMP.path_join("llm_calls.jsonl"))
		DirAccess.make_dir_recursive_absolute(calls_out)
		DirAccess.copy_absolute(src, calls_out.path_join("llm_calls.jsonl"))
	say("calls", cok, "the floating answer: %s; the fix: %s" % [JSON.stringify(old), JSON.stringify(fixed)])


# ------------------------------------------------------------------ findings
func findings_floating() -> void:
	var shown := await ghost("a block in the air", floating_ops(), "A floating block.")
	var f: Array = shown.get("space", {}).get("findings", [])
	var x: int = site.x + 6
	var ok: bool = f.size() == 3 and str(f[0]).begins_with("1 block float") and str(f[0]).contains("(%d, %d, %d)" % [x, site.top + 3, site.z + 4]) and \
		str(f[1]).contains("the pad Sky (zone 1, box") and str(f[1]).contains("has no floor") and str(f[2]).contains("inside a solid block")
	say("floating", ok, JSON.stringify(f))
	await key_on_ghost(KEY_ESCAPE)


func findings_reach() -> void:
	var got := {}
	for f: Array in [["ok", 1, false], ["gap", 5, false], ["wall", 0, true]]:   # round 3 (A6): the reachable gap is 1 cell (2 m + 1 m up)
		var shown := await ghost("a course", course_ops(int(f[1]), bool(f[2]), false), "A course.")
		got[f[0]] = shown.get("space", {}).get("findings", [])
		await key_on_ghost(KEY_ESCAPE)
	var gap: String = str(got.gap[0]) if (got.gap as Array).size() == 1 else ""
	var wall: String = str(got.wall[0]) if (got.wall as Array).size() == 1 else ""
	var x: int = site.x + 2
	say("gap", (got.ok as Array).is_empty() and gap.begins_with("finish of Hop not reachable from its start") and \
		gap.contains("a gap too wide: from feet cell (") and gap.contains(", %d, %d) to the finish" % [site.top + 1, site.z + 7]) and gap.contains("6.0 m across (5 empty cells)") and \
		gap.contains("2.0 m up"), "1-cell gap: %s; 5-cell gap: %s" % [JSON.stringify(got.ok), gap])
	say("wall", wall.contains("a climb too high") and wall.contains("2.0 m up") and not wall.contains("a gap too wide"), wall)
