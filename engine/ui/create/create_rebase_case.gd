extends SceneTree
## H2 (25 Nov 2026): My games offers a finished game on the rink core the newest base, in one control (Newest base), and
## sends `foreman rebase <job>`. Headless, the door dry; two copies of the done fixture (ui/fixtures/create/c9-done) under
## user://, each given a pack/ beside its log:
##   old    made on the base (gen/tj_rink.gd), scripts/main.gd an older version and no rink_toys.gd: behind
##   fresh  the newest base's scripts/, gen/ and tests/ byte for byte: current, no control
## Checks: the model counts what the old game lacks (and 0 for the fresh one and for a game not on the base); My games draws
## Newest base on the old row only; pressing it sends exactly ["rebase", <job>] and says it in words; a job the Foreman is
## moving reads "Moving to the newest base".
##   godot --headless --path engine --script res://ui/create/create_rebase_case.gd
## Prints PASS / FAIL create.rebase.* lines and a trailer "[create-rebase] n passed, m failed".

const Model = preload("res://ui/create/create_model.gd")
const JobModel = preload("res://ui/job_model.gd")
const CreateScene = preload("res://ui/create/create.tscn")

var passed: int = 0
var failed: int = 0


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		passed += 1
		print("PASS %s" % name)
	else:
		failed += 1
		print("FAIL %s: %s" % [name, detail])


static func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


static func _copy(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to.get_base_dir())
	var f: FileAccess = FileAccess.open(to, FileAccess.WRITE)
	f.store_buffer(FileAccess.get_file_as_bytes(from))
	f.close()


## A copy of the done fixture's log (extra events after its last), and a pack/ beside it.
static func _job(dir: String, extra: Array) -> void:
	# four different games (My games folds builds of one title into one row): each job's game title is its folder's name
	var text: String = FileAccess.get_file_as_string("res://ui/fixtures/create/c9-done/job.jsonl").strip_edges().replace("\"title\":\"Penguin Push\"", "\"title\":\"%s\"" % dir.get_file())
	var lines: PackedStringArray = text.split("\n")
	var last: Dictionary = JSON.parse_string(lines[lines.size() - 1])
	for i: int in extra.size():
		var e: Dictionary = {"v": 1, "seq": int(last["seq"]) + 1 + i, "ts": "2026-11-21T20:%02d:00.000Z" % (10 + i), "job": str(last["job"])}
		e.merge(extra[i])
		lines.append(JSON.stringify(e))
	_write(dir.path_join("job.jsonl"), "\n".join(lines) + "\n")


static func _rm(dir: String) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	for f: String in d.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
	for sub: String in d.get_directories():
		_rm(dir.path_join(sub))
	DirAccess.remove_absolute(dir)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var root: String = ProjectSettings.globalize_path("user://h2_rebase_case")
	_rm(root)
	var jobs: String = root.path_join("jobs")
	var old: String = jobs.path_join("h2-old")
	var fresh: String = jobs.path_join("h2-fresh")
	var plain: String = jobs.path_join("h2-plain")
	var moving: String = jobs.path_join("h2-moving")
	_job(old, [])
	_job(fresh, [])
	_job(plain, [])
	_job(moving, [{"type": "job_state", "state": "running", "reason": "moving to the newest base (engine/templates/rink_game), then the whole verification"}])
	var base: String = Model.BASE_DIR
	# old: on the base, two files an older base had (gen and the camera), main.gd from before the toys, no rink_toys.gd
	_copy(base.path_join("gen/tj_rink.gd"), old.path_join("pack/gen/tj_rink.gd"))
	_write(old.path_join("pack/scripts/main.gd"), "extends Node\n# an older base's main.gd\n")
	# fresh: every file of the base's scripts/, gen/, tests/
	var n_base: int = 0
	for part: String in Model.BASE_PARTS:
		for rel: String in Model._files(base, part):
			_copy(base.path_join(rel), fresh.path_join("pack").path_join(rel))
			n_base += 1
	# plain: a game with a pack that is not on the base
	_write(plain.path_join("pack/scripts/main.gd"), "extends Node\n")
	var b_old: int = Model.base_behind(old)
	var b_fresh: int = Model.base_behind(fresh)
	var b_plain: int = Model.base_behind(plain)
	_check("create.rebase.model: a game on an older base is behind by the base files it lacks or holds older; the newest base's copy and a game not on the base are not",
		n_base > 10 and b_old == n_base - 1 and b_fresh == 0 and b_plain == 0, "base files %d; old %d (want %d), fresh %d, plain %d" % [n_base, b_old, n_base - 1, b_fresh, b_plain])
	var jm: Dictionary = JobModel.read_job(moving, 0.0)
	_check("create.rebase.word: a job the Foreman is moving to the newest base reads so in My games",
		Model.state_word(jm) == "Moving to the newest base", "word '%s' (screen %s)" % [Model.state_word(jm), Model.screen_of(jm)])

	var page: Control = CreateScene.instantiate()
	page.call("setup", {"jobs": jobs, "dry": true, "now": 1795289400.0, "menu_list": root.path_join("dungeons.user.json")})
	root_add(page)
	await process_frame
	page.call("open")
	await process_frame
	page.call("open_games")
	await process_frame
	var rows: Array = page.get("games_rows")
	var old_i: int = -1
	var fresh_i: int = -1
	for i: int in rows.size():
		if str(rows[i]["dir"]) == old: old_i = i
		if str(rows[i]["dir"]) == fresh: fresh_i = i
	var has: Callable = func(name: String) -> bool:
		var nd: Node = page.find_child(name, true, false)
		return nd != null
	var shown: bool = old_i >= 0 and fresh_i >= 0 and has.call("Base%d" % old_i) and not has.call("Base%d" % fresh_i)
	var controls: int = 0
	for i: int in rows.size():
		if has.call("Base%d" % i): controls += 1
	_check("create.rebase.row: My games draws Newest base on the row of the game on an older base only (one control)",
		shown and controls == 1, "rows %d, old at %d, fresh at %d, controls %d" % [rows.size(), old_i, fresh_i, controls])
	var door: RefCounted = page.get("door")
	var before: int = (door.get("dry_steps") as Array).size()
	if old_i >= 0 and has.call("Base%d" % old_i):
		(page.find_child("Base%d" % old_i, true, false) as BaseButton).pressed.emit()
	await process_frame
	var sent: Array = (door.get("dry_steps") as Array).slice(before)
	var said: String = str(page.get("message"))
	_check("create.rebase.send: Newest base sends foreman rebase <job> (no model) and says what happens in words; My games stays open",
		str(sent) == str([[["rebase", old]]]) and said.begins_with("Moving") and said.contains("newest base") and page.call("shown_screen") == "games",
		"sent %s; said '%s'; screen %s" % [str(sent), said, str(page.call("shown_screen"))])
	page.queue_free()
	print("[create-rebase] %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


func root_add(n: Node) -> void:
	get_root().add_child(n)
