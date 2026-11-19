extends RefCounted
## E1/E2: the workbench session of ui/drive.gd (tools/ui.sh editor), kept in its own file (drive.gd's size is
## ratcheted). It acts only through the drive's hands (input events) and reads only, like drive.gd's own sessions.

## The workbench session: open it from the list, type an idea, see the recipe it matched, answer questions, grow the
## rink, drag the ghost onto a neighbour (refused, with the reason), turn it, drag it to free ground, Build it; the
## job appears in the panel with the request as its sentence. Input events only; the map's screen positions and the
## free spot are read from the workbench's model (reads, like the job reads above).
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
	await d.secs(0.3)
	await d.scroll_to("Opt_match_one")
	if not await d.click("Opt_match_one", "the chip \"One 3-minute period\""):
		return
	await d.secs(pause)
	var small: Vector3 = m.call("footprint")
	var r0: float = m.call("lot_radius")
	await d.picture("e-3-answered.png")
	await d.scroll_to("Opt_rink_big")
	if not await d.click("Opt_rink_big", "the chip \"Big ice 80 x 40 m\""):
		return
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
	if blocker.find("overlaps") == -1 or not build.disabled:
		d.note("read", "FAILED: an overlap must block Build it with its reason")
		d.failed = true
	await d.picture("e-5-overlap-refused.png")
	var at_s: Vector2 = map.global_position + (map.call("to_screen", m.get("at")) as Vector2)
	await d.wheel(at_s, true, "the map (turn the ghost 15 degrees)")
	await d.wheel(at_s, true, "the map (turn the ghost 15 degrees)")
	d.note("read", "yaw now %.1f degrees" % rad_to_deg(float(m.get("yaw"))))
	# a free spot: the nearest grid point to the hockey plot whose checks have no error (read from the model)
	var r: float = m.call("lot_radius")
	var best: Vector2 = Vector2.ZERO
	var bd: float = INF
	var b: Rect2 = m.get("bounds")
	for gx: int in range(int(b.position.x), int(b.end.x), 8):
		for gz: int in range(int(b.position.y), int(b.end.y), 8):
			var c: Vector2 = Vector2(gx, gz)
			if (m.call("_errors_at", c, r) as Array).is_empty() and (m.call("road_point", c) as Vector2).distance_to(c) < r + 30.0:
				var dist: float = c.distance_to(hockey)
				if dist < bd:
					bd = dist
					best = c
	d.note("read", "free spot by the road nearest the hockey plot: (%d, %d)" % [int(best.x), int(best.y)])
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
	if not await d.wait_for("the game is done (verified and promoted)", func() -> bool: return d.job().get("phase", "") == "done", 240.0):
		await d.picture("e-9-game-sheet-not-done.png")
		return
	await d.secs(pause * 1.5)
	await d.picture("e-9-game-sheet-done.png")
	if not await d.click("GamesButton", "the button \"< Games\""):
		return
	await d.secs(pause)
	await d.picture("e-10-back-to-the-list.png")
