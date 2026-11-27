extends RefCounted
## E4 (night of 24-25 Nov 2026): the checks of the person's path through iterations on the Create page, run by
## create_checks.gd (ui.sh selftest and the kernel selftest block 630). Headless, the door dry; jobs are written under
## `tmp` from the done fixture (ui/fixtures/create/c9-done) plus the events a change round writes (JOB.md, "Added after
## N3": change_requested, reopened, a new promotion @0.1.<n>):
##   e4-made     a change made: version 2 promoted at promoted/game.penguin_push@0.1.1
##   e4-flight   a change in flight (job running, its Foreman gone)
##   e4-failed   a change that ended the job failed (the first promotion still plays)
## The person's dungeon list is a file under `tmp` (never the real user:// one).

const JobModel = preload("res://ui/job_model.gd")
const Model = preload("res://ui/create/create_model.gd")
const CreateScene = preload("res://ui/create/create.tscn")
const Dungeons = preload("res://kernel/dungeon/dungeons.gd")

const CHECKS: int = 12
const TEXT: String = "make the penguins faster"


static func _fixture() -> String:
	return ProjectSettings.globalize_path("res://ui/fixtures/create/c9-done")


## A copy of c9-done with more events (seq and ts follow the fixture's last), and pack.json files under promoted/.
static func _job(dir: String, extra: Array, promoted: Array) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var text: String = FileAccess.get_file_as_string(_fixture().path_join("job.jsonl")).strip_edges()
	var lines: PackedStringArray = text.split("\n")
	var last: Dictionary = JSON.parse_string(lines[lines.size() - 1])
	var seq: int = int(last["seq"])
	for i: int in extra.size():
		var e: Dictionary = {"v": 1, "seq": seq + 1 + i, "ts": "2026-11-21T20:%02d:00.000Z" % (10 + i), "job": str(last["job"])}
		e.merge(extra[i])
		lines.append(JSON.stringify(e))
	var f: FileAccess = FileAccess.open(dir.path_join("job.jsonl"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	for v: String in promoted:
		var name: String = "game.penguin_push" + ("" if v == "0.1.0" else "@" + v)
		DirAccess.make_dir_recursive_absolute(dir.path_join("promoted").path_join(name))
		var m: FileAccess = FileAccess.open(dir.path_join("promoted").path_join(name).path_join("pack.json"), FileAccess.WRITE)
		m.store_string(JSON.stringify({"id": "game.penguin_push", "version": v}))
		m.close()
	return dir


static func run(tree: SceneTree, check: Callable, tmp: String) -> bool:
	var jobs: String = tmp.path_join("e4-jobs")
	var asked: Dictionary = {"type": "change_requested", "text": TEXT}
	var running: Dictionary = {"type": "job_state", "state": "running", "reason": "change request"}
	var made: String = _job(jobs.path_join("e4-made"), [asked, running,
		{"type": "reopened", "package": "penguin_moves", "reason": "change request (event 76); the Planner names the package: speed is the mover's"},
		{"type": "package_state", "package": "penguin_moves", "state": "queued", "round": 3, "detail": "CHANGE REQUEST: " + TEXT},
		{"type": "package_state", "package": "penguin_moves", "state": "promoted", "round": 3},
		{"type": "change_requested", "package": "penguin_moves", "text": "[foreman] wire in x (added for change request event 76; new: x): call it"},
		{"type": "promoted", "packId": "game.penguin_push", "version": "0.1.1", "dest": "promoted/game.penguin_push@0.1.1"},
		{"type": "job_state", "state": "done", "reason": "promoted 0.1.1"}], ["0.1.0", "0.1.1"])
	var flight: String = _job(jobs.path_join("e4-flight"), [asked, running], ["0.1.0"])
	var failed: String = _job(jobs.path_join("e4-failed"), [asked, running, {"type": "job_state", "state": "failed", "reason": "the change was NOT made"}], ["0.1.0"])
	# N27 (lane T): a change built as asked that moved the balance: the Foreman's note (boundlift.ts BALANCE_MOVED), first line shown
	var moved: String = "[foreman] balance moved by your change: built as you asked; the gulls side now wins 3 of 3 of the Foreman's test rounds (was 1 of 3). Say \"make it fairer\" to tune it.\nfigures (tests/bot_tofu.gd, not judged in this change): close_rounds 0 (was 1)"
	var balanced: String = _job(tmp.path_join("e4-balance-jobs").path_join("e4-balance"), [asked, running,
		{"type": "note", "package": "penguin_moves", "round": 3, "text": moved},
		{"type": "promoted", "packId": "game.penguin_push", "version": "0.1.1", "dest": "promoted/game.penguin_push@0.1.1"},
		{"type": "job_state", "state": "done", "reason": "promoted 0.1.1"}], ["0.1.0", "0.1.1"])
	var list: String = tmp.path_join("e4-dungeons.user.json")
	DirAccess.remove_absolute(list)

	# 1. the model
	var jm: Dictionary = JobModel.read_job(made, 0.0)
	var jf: Dictionary = JobModel.read_job(flight, 0.0)
	var jx: Dictionary = JobModel.read_job(failed, 0.0)
	var jb: Dictionary = JobModel.read_job(balanced, 0.0)
	check.call("create.iterate.model: a change made is version 2 (Play opens @0.1.1); in flight it is building with its words; failed, the first version still plays with a note; the Foreman's own wire request is not the person's",
		Model.screen_of(jm) == "done" and Model.version_n(jm) == 2 and Model.play_dir(jm).ends_with("@0.1.1") and Model.person_changes(jm).size() == 1 and Model.change_note(jm).is_empty()
		and Model.screen_of(jf) == "building" and Model.changing(jf) == TEXT
		and Model.screen_of(jx) == "done" and Model.change_note(jx).begins_with("Your last change could not be made") and Model.play_dir(jx).ends_with("promoted/game.penguin_push")
		and Model.change_note(jb) == "Built as you asked; the gulls side now wins 3 of 3 of the Foreman's test rounds (was 1 of 3). Say \"make it fairer\" to tune it.",
		"made %s v%d %s; flight %s '%s'; failed %s '%s'; balance '%s'" % [Model.screen_of(jm), Model.version_n(jm), Model.play_dir(jm), Model.screen_of(jf), Model.changing(jf), Model.screen_of(jx), Model.change_note(jx), Model.change_note(jb)])

	# the page, as the exe mounts it (a dry door: every command is recorded)
	var page: Control = CreateScene.instantiate()
	var fake: Array = ["--adapter", "fake"]
	page.call("setup", {"jobs": jobs, "dry": true, "now": 1795289400.0, "menu_list": list, "flags": {"new": fake, "plan": fake, "run": fake, "resume": fake, "change": fake}})
	tree.root.add_child(page)
	page.call("open")
	await tree.process_frame
	var has: Callable = func(name: String) -> bool:
		var n: Node = page.find_child(name, true, false)
		return n != null and (n as CanvasItem).is_visible_in_tree()
	var press: Callable = func(name: String) -> void:
		(page.find_child(name, true, false) as BaseButton).pressed.emit()
	var door: RefCounted = page.get("door")

	# 2. done: Play, Add to menu, the change box; a change goes out as `foreman change` and the page shows it being made
	page.call("show_job", made)
	var title: String = (page.find_child("GameTitle", true, false) as Label).text
	var controls: bool = has.call("Play") and has.call("AddMenu") and has.call("ChangeBox") and has.call("SendChange") and title.contains("version 2")
	var base: int = (door.get("dry_steps") as Array).size()
	press.call("SendChange")
	var empty_sent: bool = (door.get("dry_steps") as Array).size() == base and not str(page.get("message")).is_empty()
	(page.find_child("ChangeBox", true, false) as LineEdit).text = TEXT
	press.call("SendChange")
	var sent: Array = (door.get("dry_steps") as Array).slice(base)
	var changing_shown: bool = page.call("shown_screen") == "building" and has.call("Changing") and (page.find_child("Changing", true, false).find_children("*", "Label", true, false)[0] as Label).text.contains(TEXT)
	check.call("create.iterate.change: done shows Play, Add to menu and the change box (version 2); an empty change sends nothing; Change it sends foreman change <job> \"<words>\" and the page says Changing: <words>",
		controls and empty_sent and str(sent) == str([[["change", made, TEXT] + fake]]) and changing_shown, "title '%s'; sent %s; screen %s" % [title, str(sent), str(page.call("shown_screen"))])

	# 3. a change in flight whose Foreman is gone: Changing, and Continue resumes it
	page.call("show_job", flight)
	var flight_ok: bool = page.call("shown_screen") == "building" and has.call("Changing") and has.call("Continue")
	base = (door.get("dry_steps") as Array).size()
	press.call("Continue")
	var resumed: Array = (door.get("dry_steps") as Array).slice(base)
	check.call("create.iterate.continue: a change in flight with no Foreman shows Changing and Continue; Continue runs foreman resume <job>",
		flight_ok and str(resumed) == str([[["resume", flight] + fake]]), "screen %s, resumed %s" % [str(page.call("shown_screen")), str(resumed)])

	# 4. Add to menu: the person's list (never engine/boot/dungeons.json), the menu's reader, the newest version, out again
	page.call("show_job", made)
	press.call("AddMenu")
	var rows: Array = Dungeons.read_user(list)["dungeons"]
	var row_ok: bool = rows.size() == 1 and str(rows[0]["pack"]) == made.path_join("promoted/game.penguin_push@0.1.1") and str(rows[0]["job"]) == made and str(rows[0]["title"]) == "Penguin Push"
	var listed: bool = has.call("RemoveMenu") and not has.call("AddMenu")
	OS.set_environment("TL_USER_DUNGEONS", list)
	var menu: Dictionary = Dungeons.read_menu()
	OS.unset_environment("TL_USER_DUNGEONS")
	var shipped: int = (Dungeons.read()["dungeons"] as Array).size()
	var mine: Array = (menu["dungeons"] as Array).filter(func(r: Dictionary) -> bool: return r.get("mine", false) == true)
	Dungeons.add_user(made.path_join("promoted/game.penguin_push"), "Penguin Push", made, list)      # an older version listed
	page.call("show_job", made)                                                                      # Create moves it to the newest
	var followed: bool = str((Dungeons.read_user(list)["dungeons"] as Array)[0]["pack"]).ends_with("@0.1.1")
	press.call("RemoveMenu")
	var gone: bool = (Dungeons.read_user(list)["dungeons"] as Array).is_empty() and has.call("AddMenu")
	check.call("create.iterate.menu: Add to menu writes the person's list (pack = the newest promotion, title, job); the menu reads the shipped dungeons then it (mine); a listed older version moves to the newest; In the menu takes it out",
		row_ok and listed and (menu["dungeons"] as Array).size() == shipped + 1 and mine.size() == 1 and followed and gone, "rows %s; menu %d of %d shipped + %d mine; followed %s; gone %s" % [str(rows), (menu["dungeons"] as Array).size(), shipped, mine.size(), str(followed), str(gone)])

	# 5. My games (26 Nov): one row per game, the builds of one title folded into it (the newest finished one opens); a
	# row reopens its job at its screen; more games than a page turn with Older / Newer
	page.call("new_idea")
	press.call("MyGames")
	var rows5: Array = page.get("games_rows")
	var one: bool = rows5.size() == 1 and str(rows5[0]["dir"]).get_file() == "e4-made" and int(rows5[0]["builds"]) == 3 and str(rows5[0]["word"]) == "Ready, version 2"
	var shown_games: bool = page.call("shown_screen") == "games" and has.call("Game0") and not has.call("Game1") and not has.call("GamesOlder") and not has.call("MyGames")
	var said: String = (page.find_child("Game0", true, false).find_child("GameState", true, false) as Label).text if has.call("Game0") else ""
	press.call("Game0")
	var opened: bool = str(page.get("job_dir")) == made and page.call("shown_screen") == "done"
	var many: Array = []
	for k: int in 12:
		many.append({"dir": made, "title": "Game %02d" % k, "word": "Ready", "screen": "done", "sentence": "", "builds": 1})
	page.set("games_rows", many)
	page.set("games_page", 0)
	page.set("showing_games", true)
	page.call("_rebuild")
	var name_of: Callable = func() -> String: return (page.find_child("Game0", true, false).find_child("GameName", true, false) as Label).text if has.call("Game0") else ""
	var p1: bool = has.call("Game4") and not has.call("Game5") and has.call("GamesOlder") and not has.call("GamesNewer") and name_of.call() == "Game 00"
	press.call("GamesOlder")
	var p2: bool = has.call("GamesNewer") and has.call("GamesOlder") and name_of.call() == "Game 05" and (page.find_child("GamesPage", true, false) as Label).text.begins_with("Page 2 of 3")
	press.call("GamesOlder")
	var p3: bool = not has.call("GamesOlder") and has.call("Game1") and not has.call("Game2") and name_of.call() == "Game 10"
	check.call("create.iterate.games: My games folds the 3 builds of Penguin Push into one row (e4-made, Ready, version 2, 3 builds) that reopens at its screen; 12 games show 5 a page and Older / Newer turn the pages (5, 5, 2)",
		one and shown_games and said.contains("3 builds") and opened and p1 and p2 and p3,
		"rows %s; said '%s'; opened %s; pages %s %s %s" % [str(rows5.map(func(r: Dictionary) -> String: return str(r["dir"]).get_file())), said, str(opened), str(p1), str(p2), str(p3)])
	page.queue_free()

	# 6. the list's rules: unknown keys and a relative pack are errors (the good row is kept), a missing file is empty
	var bad: String = tmp.path_join("e4-bad.user.json")
	var bf: FileAccess = FileAccess.open(bad, FileAccess.WRITE)
	bf.store_string(JSON.stringify({"schema": Dungeons.USER_SCHEMA, "dungeons": [{"pack": "packs/hockey", "title": "Relative"}, {"pack": made, "title": "Good"}, {"pack": made, "title": "Key", "colour": "red"}]}))
	bf.close()
	var rb: Dictionary = Dungeons.read_user(bad)
	var none: Dictionary = Dungeons.read_user(tmp.path_join("e4-missing.json"))
	var no_pack: String = Dungeons.add_user(tmp, "No pack here", "", list)
	check.call("create.iterate.list: the person's list refuses a relative pack and an unknown key (and keeps the good row), reads a missing file as empty, and Add refuses a folder without pack.json",
		not bool(rb["ok"]) and (rb["dungeons"] as Array).size() == 1 and (rb["errors"] as Array).size() == 2 and bool(none["ok"]) and (none["dungeons"] as Array).is_empty() and no_pack.begins_with("no pack.json"),
		"%s; missing %s; add '%s'" % [str(rb), str(none), no_pack])
	await _pauses(tree, check, tmp, fake)
	await _e4c(tree, check, tmp, fake)
	return true


## A copy of a fixture job with more events (seq after its last; ts given or the fixture's last), under tmp.
static func _copy_job(fixture: String, dir: String, extra: Array) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var lines: PackedStringArray = FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://ui/fixtures/create").path_join(fixture).path_join("job.jsonl")).strip_edges().split("\n")
	var last: Dictionary = JSON.parse_string(lines[lines.size() - 1])
	var seq: int = int(last["seq"])
	for e: Dictionary in extra:
		seq += 1
		var full: Dictionary = {"v": 1, "seq": seq, "ts": str(last["ts"]), "job": str(last["job"])}
		full.merge(e, true)
		lines.append(JSON.stringify(full))
	var f: FileAccess = FileAccess.open(dir.path_join("job.jsonl"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	return dir


## E4c (25 Nov): the phase pause's measured figures beside Try it / Pass / Hold (E3d's note and report); a question that
## asks for a package's scope gets "Yes, let it" (answer --change); E3d's asked-back change reads right with its own
## chip; the build clock counts the current run.
## The E4c jobs under tmp: {measured, words, scope, orange, clock, scope_q, orange_q, now} (also stage_pauses.gd stills).
static func e4c_jobs(tmp: String) -> Dictionary:
	var rep: String = "reports/core-phase-slide-s31.json"
	var note: String = "[foreman] measured at the phase pause slide: data/game.cartridge.json FAILED (rookie_wins_of_10 10, pro_goals_a_match 33.6, pro_minutes 6.2); GROSS DEFECTS: 33.6 goals a match at pro (thirdjam's regular playtester): thirdjam's own cartridges play 2.1 to 13.7, so 0 to 21.8 is the band; the house game hokej: pro_goals_a_match 3.4, pro_minutes 7.5 [report: %s]" % rep
	var measured: String = _copy_job("c6-phase-done", tmp.path_join("e4c-measured"), [{"type": "note", "package": "penguin_moves", "round": 1, "text": note}])
	DirAccess.make_dir_recursive_absolute(measured.path_join("reports"))
	var rf: FileAccess = FileAccess.open(measured.path_join(rep), FileAccess.WRITE)
	rf.store_string(JSON.stringify({"schema": "tl.foreman.measured/1", "phase": "slide", "file": "data/game.cartridge.json",
		"run": {"code": 1, "figures": {"pro_goals_a_match": 33.6, "pro_minutes": 6.2}, "summary": "GROSS DEFECTS: ...", "defects": ["33.6 goals a match at pro (thirdjam's regular playtester): thirdjam's own cartridges play 2.1 to 13.7, so 0 to 21.8 is the band"]},
		"house": {"code": 0, "figures": {"pro_goals_a_match": 3.4, "pro_minutes": 7.5}, "summary": "ok"}}))
	rf.close()
	var words_only: String = _copy_job("c6-phase-done", tmp.path_join("e4c-measured-words"), [{"type": "note", "package": "penguin_moves", "round": 1, "text": note.replace(rep, "reports/gone.json")}])
	var scope_q: String = "Can the zone and bumper drawing go to a package that owns `gen/tj_rink.gd` and `scripts/main.gd`, or can those two files be added to this package's scope?"
	var widen: String = _copy_job("c5-building", tmp.path_join("e4c-scope"), [{"type": "question", "package": "penguin_moves", "text": scope_q}, {"type": "job_state", "state": "paused", "reason": "waiting for answers: penguin_moves"}])
	var orange_q: String = "There is no orange team in this game: your side is red (Red Toques), the bots are blue (Blue Scarves). Did you mean the blue team, the bots? Say it again with the team's colour or name, and the change is made."
	var orange: String = _copy_job("c5-building", tmp.path_join("e4c-orange"), [{"type": "question", "package": "ice_arena", "text": orange_q}, {"type": "job_state", "state": "paused", "reason": "waiting for answers: ice_arena"}])
	var now: float = 1795289400.0
	var started: String = Time.get_datetime_string_from_unix_time(int(now) - 300) + ".000Z"
	var run5: String = _copy_job("c5-building", tmp.path_join("e4c-clock"), [{"type": "job_state", "state": "running", "reason": "resumed", "ts": started}])

	return {"measured": measured, "words": words_only, "scope": widen, "orange": orange, "clock": run5, "scope_q": scope_q, "orange_q": orange_q, "now": now}


static func _e4c(tree: SceneTree, check: Callable, tmp: String, fake: Array) -> void:
	var j: Dictionary = e4c_jobs(tmp)
	var measured: String = j["measured"]
	var words_only: String = j["words"]
	var widen: String = j["scope"]
	var orange: String = j["orange"]
	var run5: String = j["clock"]
	var orange_q: String = j["orange_q"]
	var now: float = j["now"]

	var page: Control = CreateScene.instantiate()
	page.call("setup", {"jobs": tmp, "dry": true, "now": now, "flags": {"run": fake, "resume": fake, "change": fake}})
	tree.root.add_child(page)
	page.call("open")
	await tree.process_frame
	var has: Callable = func(name: String) -> bool:
		var n: Node = page.find_child(name, true, false)
		return n != null and (n as CanvasItem).is_visible_in_tree()
	var text_of: Callable = func(name: String) -> String:
		var n: Node = page.find_child(name, true, false)
		return (n as Label).text if n is Label else ((n as Button).text if n is Button else "")
	var press: Callable = func(name: String) -> void:
		(page.find_child(name, true, false) as BaseButton).pressed.emit()
	var door: RefCounted = page.get("door")

	page.call("show_job", measured)
	var card: String = "%s | %s | %s | %s" % [text_of.call("Measured0"), text_of.call("House0"), text_of.call("Measured1"), text_of.call("Defect0")]
	var beside: bool = has.call("MeasuredCard") and has.call("TryIt") and has.call("Pass") and has.call("Hold")
	var red: bool = has.call("Defect0") and (page.find_child("Defect0", true, false) as Label).get_theme_color("font_color").r > 0.7
	page.call("show_job", words_only)
	var w: Dictionary = Model.measured_view(page.get("job"))
	check.call("create.e4c.measured: at a phase pause the measured figures stand beside Try it / Pass / Hold: goals a match and match length beside hokej's, a gross defect in red words; without its report the note's own figures",
		beside and red and card.contains("Goals a match: 33.6") and card.contains("hokej: 3.4") and card.contains("Match lasts: 6.2 min") and card.contains("33.6 goals a match at pro")
		and float(w.get("goals", -1)) == 33.6 and float(w.get("minutes", -1)) == 6.2 and (w.get("defects", []) as Array).size() == 1, "%s; words-only %s" % [card, str(w)])

	page.call("show_job", widen)
	var chips: bool = has.call("LetIt") and not has.call("Option0")   # its yes is the chip; anything else in words
	press.call("LetIt")
	var base: int = (door.get("dry_steps") as Array).size()
	press.call("SendAnswer")
	var sent: Array = (door.get("dry_steps") as Array).slice(base)
	var named: String = Model.scope_package({"order": ["core", "ice_arena"]}, {"package": "core", "text": "May ice_arena be changed so that it reads data/feel.json?"})
	var plain: String = Model.scope_package({"order": ["core"]}, {"package": "core", "text": "Should the orca chase the nearest penguin?"})
	check.call("create.e4c.scope: a question that asks for a package's scope has a “Yes, let it” chip: foreman answer <job> <package> \"...\" --change <package> then resume (the package it names, else the asker); other questions have none",
		chips and str(sent) == str([[["answer", widen, "penguin_moves", "Yes, let it change what it needs.", "--change", "penguin_moves"], ["resume", widen] + fake]]) and named == "ice_arena" and plain.is_empty(),
		"chips %s, sent %s, named '%s', plain '%s'" % [str(chips), str(sent), named, plain])

	page.call("show_job", orange)
	var oq: String = text_of.call("Question")
	check.call("create.e4c.orange: E3d's asked-back change reads whole in the question card with one chip (“Yes, the blue team, the bots”) and no scope chip",
		oq == orange_q and text_of.call("Option0") == "Yes, the blue team, the bots" and not has.call("Option1") and not has.call("LetIt"), "'%s' / '%s'" % [oq, text_of.call("Option0")])

	page.call("show_job", run5)
	var clock: String = text_of.call("Clock")
	check.call("create.e4c.clock: the build clock counts the current run (5:00 since its job_state running), not the job's first event",
		page.call("shown_screen") == "building" and clock == JobModel.fmt_time(300.0), "clock '%s' (want %s)" % [clock, JobModel.fmt_time(300.0)])
	page.queue_free()


## E4b (25 Nov): the two pauses E5 was stuck at. A builder's question (c5-building + question + paused) and a quality
## hold (c13-quality-hold, with a real picture where its milestone's capture is): the card, its words, its buttons, and
## the exact command lines (foreman answer + resume; foreman quality accept|retry + resume; quality accept + change).
static func _pauses(tree: SceneTree, check: Callable, tmp: String, fake: Array) -> void:
	var base5: String = ProjectSettings.globalize_path("res://ui/fixtures/create/c5-building")
	var qtext: String = "Should the orca chase the nearest penguin, or should it circle the iceberg first?"
	var asked: String = tmp.path_join("e4b-question")
	DirAccess.make_dir_recursive_absolute(asked)
	var lines: PackedStringArray = FileAccess.get_file_as_string(base5.path_join("job.jsonl")).strip_edges().split("\n")
	var last: Dictionary = JSON.parse_string(lines[lines.size() - 1])
	for e: Dictionary in [{"type": "question", "package": "penguin_moves", "text": qtext}, {"type": "job_state", "state": "paused", "reason": "waiting for answers: penguin_moves"}]:
		e.merge({"v": 1, "seq": int(last["seq"]) + lines.size(), "ts": "2026-11-21T19:20:00.000Z", "job": str(last["job"])})
		lines.append(JSON.stringify(e))
	var f: FileAccess = FileAccess.open(asked.path_join("job.jsonl"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	var held: String = tmp.path_join("e4b-quality")
	DirAccess.make_dir_recursive_absolute(held.path_join("captures"))
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://ui/fixtures/create/c13-quality-hold/job.jsonl"), held.path_join("job.jsonl"))
	var img: Image = Image.create(384, 216, false, Image.FORMAT_RGB8)
	img.fill(Color("#6fa8dc"))
	img.save_png(held.path_join("captures/blockout-hero-f150.png"))
	var opts: PackedStringArray = Model.question_options(qtext)
	var listed: PackedStringArray = Model.question_options("Which floor?\n- ice\n- sand\n- lava")
	var yes_no: PackedStringArray = Model.question_options("May core read data/feel.json?")

	var page: Control = CreateScene.instantiate()
	page.call("setup", {"jobs": tmp, "dry": true, "now": 1795289400.0, "flags": {"run": fake, "resume": fake, "change": fake}})
	tree.root.add_child(page)
	page.call("open")
	await tree.process_frame
	var has: Callable = func(name: String) -> bool:
		var n: Node = page.find_child(name, true, false)
		return n != null and (n as CanvasItem).is_visible_in_tree()
	var press: Callable = func(name: String) -> void:
		(page.find_child(name, true, false) as BaseButton).pressed.emit()
	var door: RefCounted = page.get("door")

	page.call("show_job", asked)
	var card_ok: bool = has.call("QuestionCard") and (page.find_child("Question", true, false) as Label).text == qtext and has.call("Option0") and has.call("Option1") and not has.call("Continue")
	press.call("Option1")
	var picked: String = (page.find_child("AnswerBox", true, false) as LineEdit).text
	var base: int = (door.get("dry_steps") as Array).size()
	press.call("SendAnswer")
	var sent: Array = (door.get("dry_steps") as Array).slice(base)
	check.call("create.pause.question: a builder's question shows its words, its options (“, or ” split; list lines; yes/no) and an answer box; Answer sends foreman answer <job> <package> \"<words>\" then resume",
		card_ok and opts.size() == 2 and str(opts[1]).begins_with("Should it circle") and listed == PackedStringArray(["ice", "sand", "lava"]) and yes_no == PackedStringArray(["Yes", "No"])
		and picked == opts[1] and str(sent) == str([[["answer", asked, "penguin_moves", picked], ["resume", asked] + fake]]) and has.call("Sent"),
		"opts %s, listed %s, yes/no %s, picked '%s', sent %s" % [str(opts), str(listed), str(yes_no), picked, str(sent)])

	page.call("show_job", held)
	var v: Dictionary = Model.quality_view(page.get("job"))
	var qcard: bool = has.call("QualityCard") and has.call("Still") and has.call("FixIt") and has.call("ItsFine") and has.call("ChangeIt") and not has.call("Continue")
	var reason0: String = (page.find_child("Reason0", true, false) as Label).text if has.call("Reason0") else ""
	var runs: Array = []
	for b: String in ["FixIt", "ItsFine"]:
		page.call("show_job", held)
		base = (door.get("dry_steps") as Array).size()
		press.call(b)
		runs.append((door.get("dry_steps") as Array).slice(base))
	page.call("show_job", held)
	press.call("ChangeIt")
	var box: LineEdit = page.find_child("QualityChange", true, false)
	box.text = "make the court blue"
	box.text_changed.emit(box.text)
	base = (door.get("dry_steps") as Array).size()
	press.call("SendQualityChange")
	runs.append((door.get("dry_steps") as Array).slice(base))
	var want: Array = [[[["quality", held, "retry", "--note", "the person asks for one more try"], ["resume", held] + fake]],
		[[["quality", held, "accept", "--note", "the person plays it as it is"], ["resume", held] + fake]],
		[[["quality", held, "accept", "--note", "the person changes it instead: make the court blue"], ["change", held, "make the court blue"] + fake]]]
	check.call("create.pause.quality: a quality hold shows the critic's reasons (no score rows) and the still it judged; Fix it = quality retry + resume, It's fine = quality accept + resume, Change it = accept + foreman change with the person's words",
		qcard and reason0.contains("the court is a grey slab") and not reason0.contains("silhouette") and str(v["still"]).ends_with("blockout-hero-f150.png") and str(runs) == str(want),
		"card %s, reason '%s', still '%s', runs %s" % [str(qcard), reason0, str(v.get("still", "")), str(runs)])
	page.queue_free()
