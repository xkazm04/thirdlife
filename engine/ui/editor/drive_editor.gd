extends RefCounted
## E1/E2: the workbench session of ui/drive.gd (tools/ui.sh editor), kept in its own file (drive.gd's size is
## ratcheted). It acts only through the drive's hands (input events) and reads only, like drive.gd's own sessions.

## Ask for places through the UI and compare the first job event with the chosen draft.
func run_place(d: Node) -> void:
	if not await d.click("WorkbenchRow", "New game in the workbench"):
		return
	if not await d.click("IdeaField", "the idea field"):
		return
	# Round 2: the words name a place ("by the river"), so Find a place asks the Designer (the fake answers);
	# --measured: no place words, so the editor offers its own three measured places and calls no model
	var measured: bool = (d.host.get("args") as Dictionary).has("measured")
	await d.type("ice hockey, three against three" + ("" if measured else " by the river"), "the idea")
	var wb: Control = await d.find("Workbench")
	if wb == null:
		d.failed = true
		return
	var m = wb.model
	if not await _place_wait(d, func() -> bool: return m.recipe == "team_possession", "team possession recipe"):
		return
	if not await d.click("CloseUpButton", "close up on the footprint"):
		return
	await d.picture("p-1-recipe.png")
	for step in [["rink", "small", "p-2-small"], ["dressing", "bare", "p-3-bare"], ["dressing", "arena", "p-4-stands"], ["dressing", "bare", "p-5-no-stands"]]:
		var chip := "Opt_%s_%s" % [step[0], step[1]]
		await d.scroll_to(chip)
		if not await d.click(chip, "the " + str(step[1]) + " option"):
			return
		if not await _place_wait(d, func() -> bool: return m.value(step[0]).id == step[1], chip):
			return
		await d.frames(60 if d.slow else 6)
		await d.picture(step[2] + ".png")
	await d.scroll_to("TakeProposals")
	if not await d.click("TakeProposals", "accept the remaining proposed answers"):
		return
	if not wb._places.status.text.is_empty():
		d.failed = true
		d.note("read", "FAILED: unexpected placement message before Find a place")
		return
	if not await d.click("FindPlace", "Find a place"):
		return
	# Move off Find so its hover tooltip does not cover the map while the answer arrives.
	d._mouse(wb._map.global_position + Vector2(12, 12))
	# --any-places: a real Designer answers (flags/real.json): any 2-3 places, checked only for the scorer's order
	# (valid first, then by score); the fake's fixed answer is checked exactly.
	var any_places: bool = (d.host.get("args") as Dictionary).has("any-places") or measured
	if not await _place_wait(d, func() -> bool: return wb._places.ranked.size() >= (2 if any_places else 3), "ranked places"):
		return
	var rows: Array = wb._places.ranked
	var ordered := true
	for i in range(1, rows.size()):
		ordered = ordered and (rows[i - 1].valid or not rows[i].valid) and (rows[i - 1].valid != rows[i].valid or rows[i - 1].score >= rows[i].score)
	if any_places:
		if not ordered or not rows[0].valid:
			d.failed = true
			d.note("read", "FAILED: the places are not in the scorer's order, or none is valid: " + str(rows))
			return
		if measured and (rows.size() != 3 or not rows.all(func(r: Dictionary) -> bool: return r.valid) or not m.place_calls.is_empty()):
			d.failed = true
			d.note("read", "FAILED: no place words: expected the editor's three valid places and no model call: %s calls %s" % [str(rows), str(m.place_calls)])
			return
		d.note("read", "%d places from the %s, %d valid, best %.1f" % [rows.size(), "editor (no model call)" if measured else "Designer", rows.filter(func(r: Dictionary) -> bool: return r.valid).size(), rows[0].score])
	elif not (rows[0].valid and rows[1].valid and rows[0].score >= rows[1].score and not rows[2].valid):
		d.failed = true
		d.note("read", "FAILED: expected two valid places by score, then a refusal: " + str(rows))
		return
	await d.picture("p-6-ranked.png")
	if measured:
		# Round 3: the map follows the requirements: a bigger rink measures the editor's three places again
		var ring0: float = m.lot_radius()
		await d.scroll_to("Opt_rink_standard")
		if not await d.click("Opt_rink_standard", "the Standard 60 x 30 m option"):
			return
		if not await _place_wait(d, func() -> bool: return m.lot_radius() > ring0 and is_equal_approx(wb._places.measured_for, m.lot_radius()) and wb._places.ranked.size() == 3, "places measured again for the bigger ring"):
			return
		rows = wb._places.ranked
		if not rows.all(func(r: Dictionary) -> bool: return r.valid):
			d.failed = true
			d.note("read", "FAILED: after the size change the measured places are not all valid: " + str(rows))
			return
		d.note("read", "ring %d -> %d m: the three measured places follow (best %.1f)" % [int(ring0), int(m.lot_radius()), rows[0].score])
		await d.picture("p-6b-ranked-bigger.png")
	# --take=N: take the N-th ranked place (default the top one)
	var take: int = clampi(int(str((d.host.get("args") as Dictionary).get("take", "1"))), 1, rows.size())
	var chosen: Dictionary = rows[take - 1]
	if not await d.click("TakePlace%d" % take, "take the place ranked %d" % take):
		return
	if not await _place_wait(d, func() -> bool: return m.at == chosen.at and m.yaw == chosen.yaw and m.placed_by == "proposal", "selected place and yaw"):
		return
	await d.frames(60 if d.slow else 6)
	await d.picture("p-7-chosen.png")
	if (d.host.get("args") as Dictionary).has("no-build"):
		d.note("direct", "--no-build: the session stops before Build it (nothing is started)")
		return
	var root: String = wb.jobs_root
	if not await d.click("BuildButton", "Build it"):
		return
	if not await _place_wait(d, func() -> bool: return not d.job().is_empty() and d.job().get("phase") == "approve", "new job brief"):
		return
	var dir := root.path_join(str(d.job().id))
	var file := FileAccess.open(dir.path_join("job.jsonl"), FileAccess.READ)
	var event: Variant = JSON.parse_string(file.get_line()) if file != null else null
	if not event is Dictionary or event.get("type") != "job_created" or not event.get("sentence") is String:
		d.failed = true
		d.note("read", "FAILED: expected a readable job_created event on the first line")
		return
	var draft: Dictionary = preload("res://ui/editor/game_sheet.gd").find_draft(root, event.sentence)
	var ids := {}
	for key in draft.get("answers", {}):
		ids[key] = draft.answers[key].id
	if ids.is_empty() or event.get("answers") != ids or not draft.get("lot") is Dictionary or event.get("lot") != draft.lot or draft.get("placed_by") != "proposal":
		d.failed = true
		d.note("read", "FAILED: logged answers or lot differ from the chosen draft")
	else:
		d.note("read", "job and draft agree: %s, lot %s" % [dir, str(event.lot)])
	# Round 2: every place call the workbench made is a job-level builder_run in the new job (tl ledger counts it)
	var runs: Array = []
	for line in FileAccess.get_file_as_string(dir.path_join("job.jsonl")).split("
", false):
		var e: Variant = JSON.parse_string(line)
		if e is Dictionary and e.get("type") == "builder_run" and not e.has("package") and not e.has("transcript"):
			runs.append(e)
	var calls: Array = m.place_calls
	if measured:
		if not runs.is_empty():
			d.failed = true
			d.note("read", "FAILED: no model call was made, yet the job logs place runs: %s" % str(runs))
		else:
			d.note("read", "no place call made, none logged")
	elif calls.is_empty() or runs.size() != calls.size() or int(runs[0].get("tokensIn", -1)) != int(calls[0].get("tokensIn", -2)):
		d.failed = true
		d.note("read", "FAILED: place calls %s were not logged as builder runs: %s" % [str(calls), str(runs)])
	else:
		d.note("read", "place calls logged in the job: %d, tokens in %d, out %d" % [runs.size(), int(runs[0].get("tokensIn", 0)), int(runs[0].get("tokensOut", 0))])
	# --build: approve in the game sheet and wait until the game is promoted, so the village can show it arrived
	if (d.host.get("args") as Dictionary).has("build") and not d.failed:
		if not await d.click("ApproveButton", "the button \"Approve and build\" in the game sheet"):
			return
		if not await _wait_build(d, "the game is done (verified and promoted)", func() -> bool: return d.job().get("phase", "") == "done"):
			return
		await d.picture("p-8-done.png")
		d.note("read", "built and promoted: %s" % dir)


func _place_wait(d: Node, ready: Callable, description: String) -> bool:
	for i in 3600:
		if ready.call():
			return true
		await d.get_tree().physics_frame
	d.failed = true
	d.note("read", "FAILED: %s after 3600 physics frames" % description)
	return false


## A real build can take several minutes across packages. Each new Foreman event proves progress.
## A silent job still times out after four minutes of physics frames, and an endless stream after twelve.
func _wait_build(d: Node, description: String, ready: Callable) -> bool:
	const IDLE_FRAMES := 4 * 60 * 60
	var last_seq := -1
	var idle := 0
	for frame in 3 * IDLE_FRAMES:
		if ready.call():
			d.note("read", "seen: " + description)
			return true
		var seq := int(d.job().get("last_seq", 0))
		if seq != last_seq:
			idle = 0
			last_seq = seq
		elif idle >= IDLE_FRAMES:
			break
		idle += 1
		await d.get_tree().physics_frame
	d.failed = true
	d.note("read", "FAILED waiting for %s (last event %d, %d idle frames)" % [description, last_seq, idle])
	return false


func run(d: Node) -> void:
	var sentence: String = "ice hockey, three against three, against the computer"
	var pause: float = 1.6 if d.slow else 0.7
	await d.secs(0.8)
	d.note("direct", "session start; jobs root %s; %d jobs in the list" % [str(d.panel.get("jobs_root")), (d.panel.get("jobs") as Dictionary).size()])
	await d.picture("e-0-list.png")
	if not await d.click("WorkbenchRow", "the row \"New game in the workbench…\""):
		return
	var wb: Control = await d.find("Workbench", 5.0)
	if wb == null:
		d.note("read", "the workbench did not open")
		d.failed = true
		return
	var m: RefCounted = wb.get("model")
	await d.secs(pause)
	await d.picture("e-1-workbench-empty.png")
	if not await d.click("IdeaField", "the field \"What do you want to play?\""):
		return
	await d.type(sentence, "the idea field")
	await d.secs(pause)
	if not await d.wait_for("the recipe Team possession matched the sentence", func() -> bool: return str(m.get("recipe")) == "team_possession", 5.0):
		return
	var answered: Dictionary = m.get("answers")
	d.note("read", "answers read from the sentence: %s" % str(answered.keys()))
	if not (answered.has("sport") and answered.has("players")):
		d.note("read", "FAILED: sport and players were not read out of the sentence")
		d.failed = true
	await d.picture("e-2-recipe-matched.png")
	if not await d.click("Opt_opponents_pro", "the chip \"Pro\""):
		return
	await took(d, m, "opponents", "pro")
	await d.secs(0.3)
	await d.scroll_to("Opt_match_one")
	if not await d.click("Opt_match_one", "the chip \"One 3-minute period\""):
		return
	await took(d, m, "match", "one")
	await d.secs(pause)
	var small: Vector3 = m.call("footprint")
	var r0: float = m.call("lot_radius")
	await d.picture("e-3-answered.png")
	await d.scroll_to("Opt_rink_big")
	if not await d.click("Opt_rink_big", "the chip \"Big ice 80 x 40 m\""):
		return
	await took(d, m, "rink", "big")
	await d.secs(pause)
	var big: Vector3 = m.call("footprint")
	var r1: float = m.call("lot_radius")
	d.note("read", "footprint %s -> %s, lot ring %d -> %d m" % [str(small), str(big), int(r0), int(r1)])
	if not (big.x > small.x and r1 > r0):
		d.note("read", "FAILED: big ice did not grow the footprint")
		d.failed = true
	await d.picture("e-4-big-ice.png")
	await d.scroll_to("TakeProposals")
	if not await d.click("TakeProposals", "the chip \"Take the proposal(s)\""):
		return
	await d.secs(0.4)
	# drag the ghost onto the house hockey plot
	var map: Control = await d.find("Map", 3.0)
	var hockey: Vector2 = Vector2.ZERO
	for e: Dictionary in m.get("plots"):
		if e["id"] == "hockey":
			hockey = e["at"]
	var ghost_s: Vector2 = map.global_position + (map.call("to_screen", m.get("at")) as Vector2)
	var hockey_s: Vector2 = map.global_position + (map.call("to_screen", hockey + Vector2(-30, 0)) as Vector2)
	await d.drag(ghost_s, hockey_s, "the map: the ghost onto the hockey plot")
	await d.secs(pause)
	var blocker: String = m.call("blocker")
	var build: Button = await d.find("BuildButton", 2.0)
	d.note("read", "blocker: \"%s\"; Build it disabled: %s" % [blocker, str(build.disabled)])
	if blocker.find("edge would cross") == -1 or not build.disabled:
		d.note("read", "FAILED: an overlap must block Build it with its reason")
		d.failed = true
	await d.picture("e-5-overlap-refused.png")
	var at_s: Vector2 = map.global_position + (map.call("to_screen", m.get("at")) as Vector2)
	await d.wheel(at_s, true, "the map (turn the ghost 15 degrees)")
	await d.wheel(at_s, true, "the map (turn the ghost 15 degrees)")
	d.note("read", "yaw now %.1f degrees" % rad_to_deg(float(m.get("yaw"))))
	# a free spot: the nearest grid point to the hockey plot whose checks have no error (read from the model)
	var r: float = m.call("lot_radius")
	var best: Vector2 = Vector2.INF
	var bd: float = INF
	var b: Rect2 = m.get("bounds")
	for gx: int in range(int(b.position.x), int(b.end.x), 8):
		for gz: int in range(int(b.position.y), int(b.end.y), 8):
			var c: Vector2 = Vector2(gx, gz)
			if (m.call("_errors_at", c, r) as Array).is_empty():
				var dist: float = c.distance_to(hockey)
				if dist < bd:
					bd = dist
					best = c
	if best == Vector2.INF:
		d.failed = true
		d.note("read", "FAILED: no fitting grid point for the big rink")
		return
	at_s = map.global_position + (map.call("to_screen", m.get("at")) as Vector2)
	d.note("read", "free spot nearest the hockey plot: (%d, %d)" % [int(best.x), int(best.y)])
	await d.drag(at_s, map.global_position + (map.call("to_screen", best) as Vector2), "the map: the ghost to free ground")
	await d.secs(pause)
	d.note("read", "fits: %s; checks: %s; gate path %d m" % [str(m.call("fits")), str(m.call("checks")), int(m.call("path_m"))])
	if not m.call("fits"):
		d.note("read", "FAILED: the free spot does not fit")
		d.failed = true
		return
	await d.picture("e-6-placed.png")
	if not await d.click("CloseUpButton", "the button \"Close up\""):
		return
	await d.secs(pause * 1.5)
	await d.picture("e-6b-close-up.png")
	var request: String = m.call("request")
	if not await d.click("BuildButton", "the button \"Build it\""):
		return
	await d.secs(0.5)
	var drafts: PackedStringArray = DirAccess.get_files_at(str(d.panel.get("jobs_root")).path_join("_editor"))
	d.note("read", "drafts under <jobs>/_editor: %s" % str(drafts))
	if drafts.is_empty():
		d.failed = true
	if not await d.wait_for("the workbench closed and the panel selected the new job", func() -> bool: return d.host.get("workbench") == null and not d.job().is_empty(), 40.0):
		await d.picture("e-7-build-failed.png")
		return
	d.note("read", "job id: %s; its sentence starts \"%s\"" % [str(d.job()["id"]), str(d.job().get("sentence", "")).left(60)])
	var want: String = (load("res://ui/foreman_door.gd") as GDScript).call("clean_text", request)
	if str(d.job().get("sentence", "")) != want:
		d.note("read", "FAILED: the job's sentence is not the request the workbench showed")
		d.failed = true
	if not await d.wait_for("the brief is there and waits for approval", func() -> bool: return d.job().get("phase", "") == "approve", 60.0):
		return
	# E2: the game opens in its game sheet (Decided / Open / Now, its lot)
	if await d.find("GameSheet", 10.0) == null:
		d.note("read", "FAILED: the game sheet did not open for the workbench's game")
		d.failed = true
		return
	await d.secs(pause * 1.5)
	await d.picture("e-7-game-sheet-brief.png")
	if (d.host.get("args") as Dictionary).has("no-build"):
		d.note("direct", "--no-build: the session leaves the brief waiting (nothing approved, nothing built)")
		return
	if not await d.click("ApproveButton", "the button \"Approve and build\" in the game sheet"):
		return
	if not await d.wait_for("the plan is cut: one bay per package on the lot", func() -> bool: return int(d.job().get("total", 0)) > 0, 90.0):
		return
	if not await d.wait_for("a bay is being built or checked", func() -> bool:
		for id: String in d.job().get("order", []):
			if str(d.job()["packages"][id]["state"]) in ["running", "verifying"]:
				return true
		return false, 90.0):
		return
	await d.secs(pause)
	await d.picture("e-8-game-sheet-building.png")
	if not await _wait_build(d, "the game is done (verified and promoted)", func() -> bool: return d.job().get("phase", "") == "done"):
		await d.picture("e-9-game-sheet-not-done.png")
		return
	await d.secs(pause * 1.5)
	await d.picture("e-9-game-sheet-done.png")
	# E3: change a decision from the game sheet: big ice -> standard, see the lot refit, send it as a change request
	var gs: Control = await d.find("GameSheet", 3.0)
	var gm: RefCounted = gs.get("model")
	var ring0: float = gm.call("lot_radius")
	if not await d.click("Decided_rink", "the line \"How big is the rink?\" under Decided"):
		return
	await d.secs(pause)
	if not await d.click("Change_rink_standard", "the chip \"Standard 60 x 30 m\""):
		return
	await d.secs(pause)
	var ring1: float = gm.call("lot_radius")
	d.note("read", "the lot's ring %d -> %d m before anything is sent; size line: \"%s\"" % [int(ring0), int(ring1), str((await d.find("SizeLine", 2.0)).get("text"))])
	if not ring1 < ring0:
		d.note("read", "FAILED: the picked option did not refit the lot")
		d.failed = true
	await d.picture("e-11-change-picked.png")
	if not await d.click("SendChange", "the button \"Send the change\""):
		return
	if not await d.wait_for("the change request is in the job's log", func() -> bool: return not (d.job().get("changes", []) as Array).is_empty(), 30.0):
		return
	var sent: String = str((d.job()["changes"] as Array)[-1]["text"])
	d.note("read", "change request: \"%s\"" % sent)
	await d.secs(pause)
	await d.picture("e-12-change-sent.png")
	if not await _wait_build(d, "the change was made (a new promotion)", func() -> bool: return str((d.job()["changes"] as Array)[-1]["outcome"]) == "made" and d.job().get("phase", "") == "done"):
		await d.picture("e-13-change-not-made.png")
		return
	await d.secs(pause * 1.5)
	await d.picture("e-13-change-made.png")
	var after: Dictionary = (gm.get("answers") as Dictionary).get("rink", {})
	d.note("read", "rink now %s (by %s, changed %s)" % [str(after.get("id", "")), str(after.get("by", "")), str(after.get("changed", false))])
	if str(after.get("id", "")) != "standard":
		d.note("read", "FAILED: the made change is not shown as decided")
		d.failed = true
	if not await d.click("GamesButton", "the button \"< Games\""):
		return
	await d.secs(pause)
	await d.picture("e-10-back-to-the-list.png")


## A click on a chip must become the player's answer: read it back, fail the session when it was lost.
func took(d: Node, m: RefCounted, key: String, id: String) -> void:
	var ok: bool = await d.wait_for("the answer %s = %s is the player's" % [key, id], func() -> bool:
		var v: Dictionary = m.call("value", key)
		return str(v["id"]) == id and str(v["by"]) == "player", 3.0)
	if not ok:
		d.note("read", "FAILED: the click on %s was lost; the answer stands at %s" % [id, str(m.call("value", key))])


## The lost-click hunt: N times (--n=, default 40) retype the idea (Ctrl+A, then the sentence key by key), wait for
## the recipe, wait for a drawn frame as a screenshot does, then click the opponents chip that is not chosen and read
## back whether it took. Logs the press and release frames and every chip-row rebuild between typing and release.
func run_chips(d: Node) -> void:
	var n: int = int((d.host.get("args") as Dictionary).get("n", "40"))
	await d.secs(0.5)
	if not await d.click("WorkbenchRow", "the row \"New game in the workbench…\""):
		return
	var wb: Control = await d.find("Workbench", 5.0)
	var m: RefCounted = wb.get("model")
	var lost: int = 0
	for i: int in n:
		if not await d.click("IdeaField", "the idea field"):
			return
		var k: InputEventKey = InputEventKey.new()
		k.keycode = KEY_A
		k.ctrl_pressed = true
		k.pressed = true
		Input.parse_input_event(k)
		var ku: InputEventKey = k.duplicate()
		ku.pressed = false
		Input.parse_input_event(ku)
		await d.frames(2)
		var typed_at: int = Engine.get_process_frames()
		await d.type("ice hockey, three against three, against the computer" if i % 2 == 0 else "ice hockey, three against three, versus the computer", "the idea field")
		await d.wait_for("recipe", func() -> bool: return str(m.get("recipe")) == "team_possession", 5.0)
		await d.frames(4)
		await RenderingServer.frame_post_draw
		var want: String = "pro" if str((m.call("value", "opponents") as Dictionary)["id"]) != "pro" else "rookie"
		var rects: Callable = func() -> String:
			var out: PackedStringArray = []
			for nm: String in ["Opt_opponents_rookie", "Opt_opponents_pro", "Opt_opponents_allstar"]:
				for nd: Node in d.host.find_children(nm, "", true, false):
					var r: Rect2 = (nd as Control).get_global_rect()
					out.append("%s x%d-%d y%d" % [nm.get_slice("_", 2), int(r.position.x), int(r.end.x), int(r.position.y)])
			return " ".join(out)
		var r_before: String = rects.call()
		var f_before: int = Engine.get_process_frames()
		if not await d.click("Opt_opponents_" + want, "the chip " + want):
			return
		var r_after: String = rects.call()
		var v: Dictionary = m.call("value", "opponents")
		var ok: bool = str(v["id"]) == want and str(v["by"]) == "player"
		var during: Array = []
		for f: int in wb.get("rebuilds"):
			if f >= typed_at:
				during.append(f)
		d.note("read", "%2d %s press %d release %d; rebuilds since typing: %s" % [i, "ok  " if ok else "LOST", d.press_frame, d.release_frame, str(during.slice(maxi(0, during.size() - 4)))])
		if not ok:
			lost += 1
			d.note("read", "   want %s; rects at frame %d: %s" % [want, f_before, r_before])
			d.note("read", "   rects after release: %s" % r_after)
			d.note("read", "   focus owner: %s; hovered: %s" % [str(wb.get_viewport().gui_get_focus_owner()), str(wb.get_viewport().gui_get_hovered_control())])
	d.note("read", "chips: %d of %d clicks lost" % [lost, n])
	if lost > 0:
		d.failed = true


## E5: the home session (tools/ui.sh home): the empty village board, New game -> the workbench (an example idea, the
## proposals taken, the lot the workbench chose) -> Build it -> the game sheet: approve -> back to the board, where
## the game stands on its lot in the site's words while it is built -> ready to play -> a click on its lot opens it
## again -> the jobs list and back. Input events only; positions on the map are read from the board's model.
func run_home(d: Node) -> void:
	var pause: float = 1.4 if d.slow else 0.6
	await d.secs(0.8)
	var bd: Control = await d.find("VillageBoard", 5.0)
	if bd == null:
		d.note("read", "FAILED: no village board (is --home given?)")
		d.failed = true
		return
	await d.picture("h-0-board-empty.png")
	if not await d.click("NewGameButton", "the button \"+ New game\" on the board"):
		return
	await d.secs(pause)
	if not await d.click("ExampleHockey", "the example idea \"ice hockey, three against three, …\""):
		return
	var wb: Control = await d.find("Workbench", 3.0)
	var m: RefCounted = wb.get("model")
	await d.secs(pause)
	await d.scroll_to("TakeProposals")
	if not await d.click("TakeProposals", "the chip \"Take the proposals\""):
		return
	await d.secs(pause)
	if not m.call("fits"):
		# E6: with the river in the checks no free place by the road holds the proposed 45 m arena: say so, then build
		# a small bare rink, as a player would after reading the reason under Build it
		d.note("read", "the proposed size does not fit: \"%s\"" % str(m.call("blocker")))
		await d.picture("h-1a-no-room.png")
		for opt: String in ["Opt_rink_small", "Opt_dressing_bare"]:
			await d.scroll_to(opt)
			if not await d.click(opt, "the chip " + opt):
				return
			await d.secs(pause * 0.5)
	await d.picture("h-1-workbench.png")
	d.note("read", "lot by the workbench: %s, ring %d m, fits %s" % [str(m.get("at")), int(m.call("lot_radius")), str(m.call("fits"))])
	if not await d.click("BuildButton", "the button \"Build it\""):
		return
	if not await d.wait_for("the game sheet opened on the brief", func() -> bool: return d.host.get("game_sheet") != null and d.job().get("phase", "") == "approve", 60.0):
		return
	await d.secs(pause)
	if not await d.click("ApproveButton", "the button \"Approve and build\""):
		return
	await d.secs(0.5)
	if not await d.click("GamesButton", "the button \"< Games\" (back to the village)"):
		return
	if not await d.wait_for("the board shows the game on its lot, being built", func() -> bool:
		for g: Dictionary in bd.get("games"):
			if bool(g["lot"]) and str(g["words"]).begins_with("building"):
				return true
		return false, 90.0):
		return
	await d.secs(pause)
	await d.picture("h-2-board-building.png")
	if not await d.wait_for("the board says the game is ready to play", func() -> bool:
		for g: Dictionary in bd.get("games"):
			if bool(g["lot"]) and str(g["words"]) == "ready to play":
				return true
		return false, 240.0):
		return
	await d.secs(pause)
	await d.picture("h-3-board-ready.png")
	var map: Control = await d.find("HomeMap", 3.0)
	var at: Vector2 = Vector2.ZERO
	for lot: Dictionary in (bd.get("model") as RefCounted).get("plots"):
		if lot["kind"] == "game":
			at = lot["at"]
	await d.click_at(map.global_position + (map.call("to_screen", at) as Vector2))
	d.note("UI event", "mouse click on the game's lot on the village map")
	if await d.find("GameSheet", 5.0) == null:
		d.note("read", "FAILED: a click on the lot did not open the game sheet")
		d.failed = true
		return
	await d.secs(pause)
	await d.picture("h-4-sheet-from-the-lot.png")
	if not await d.click("GamesButton", "the button \"< Games\""):
		return
	if not await d.click("JobsListButton", "the button \"Jobs list\""):
		return
	await d.secs(pause)
	await d.picture("h-5-jobs-list.png")
	if not await d.click("VillageButton", "the button \"Village\" (back to the board)"):
		return
	await d.secs(pause)
	if await d.find("HomeMap", 3.0) == null:
		d.note("read", "FAILED: the board did not come back")
		d.failed = true
