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

const CHECKS: int = 8
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
	var list: String = tmp.path_join("e4-dungeons.user.json")
	DirAccess.remove_absolute(list)

	# 1. the model
	var jm: Dictionary = JobModel.read_job(made, 0.0)
	var jf: Dictionary = JobModel.read_job(flight, 0.0)
	var jx: Dictionary = JobModel.read_job(failed, 0.0)
	check.call("create.iterate.model: a change made is version 2 (Play opens @0.1.1); in flight it is building with its words; failed, the first version still plays with a note; the Foreman's own wire request is not the person's",
		Model.screen_of(jm) == "done" and Model.version_n(jm) == 2 and Model.play_dir(jm).ends_with("@0.1.1") and Model.person_changes(jm).size() == 1 and Model.change_note(jm).is_empty()
		and Model.screen_of(jf) == "building" and Model.changing(jf) == TEXT
		and Model.screen_of(jx) == "done" and Model.change_note(jx).begins_with("Your last change could not be made") and Model.play_dir(jx).ends_with("promoted/game.penguin_push"),
		"made %s v%d %s; flight %s '%s'; failed %s '%s'" % [Model.screen_of(jm), Model.version_n(jm), Model.play_dir(jm), Model.screen_of(jf), Model.changing(jf), Model.screen_of(jx), Model.change_note(jx)])

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

	# 5. My games: every job, newest first, in a person's words; one opens where its log stands
	page.call("new_idea")
	press.call("MyGames")
	var names: PackedStringArray = []
	for r: Dictionary in page.get("games_rows"):
		names.append("%s:%s" % [str(r["dir"]).get_file(), str(r["word"])])
	var shown_games: bool = page.call("shown_screen") == "games" and has.call("Game0") and has.call("Game2") and not has.call("MyGames")
	press.call("Game1")
	check.call("create.iterate.games: My games lists the 3 jobs newest first (e4-made Ready, version 2 / e4-flight Changing / e4-failed Ready); a row reopens its job at its screen",
		shown_games and ",".join(names) == "e4-made:Ready, version 2,e4-flight:Changing,e4-failed:Ready" and str(page.get("job_dir")) == flight and page.call("shown_screen") == "building",
		"%s; then job %s screen %s" % [",".join(names), str(page.get("job_dir")), str(page.call("shown_screen"))])
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
	return true


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
