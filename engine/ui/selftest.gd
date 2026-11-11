extends SceneTree
## N6 selftest (tools/ui.sh selftest): headless checks of the model behind the designer panel. Reads the real marble
## job (read only), writes only into the user's temporary directory. One PASS/FAIL line per check; exit code 1 when
## any failed.

const JobModel = preload("res://ui/job_model.gd")
const Door = preload("res://ui/foreman_door.gd")

var passed: int = 0
var failed: int = 0


func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("PASS %s" % name)
	else:
		failed += 1
		print("FAIL %s%s" % [name, ("  -> " + detail) if not detail.is_empty() else ""])


func eq(name: String, got: Variant, want: Variant) -> void:
	check(name, str(got) == str(want), "got %s, want %s" % [str(got), str(want)])


func _initialize() -> void:
	var repo: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--repo="):
			repo = a.substr(7)
	if repo.is_empty():
		repo = Door.find_cli(ProjectSettings.globalize_path("res://")).get_base_dir().get_base_dir().get_base_dir()
	var marble: String = repo.path_join("site/marble-run-three-marbles-20261110-2")
	var tmp: String = OS.get_user_data_dir().path_join("tl_ui_selftest_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(tmp)
	print("[selftest] marble job: %s" % marble)

	# ---- 1. the real marble job
	var j: Dictionary = JobModel.read_job(marble, 0.0)
	check("marble: job.jsonl is read", bool(j["ok"]) and int(j["n_events"]) == 126, "ok=%s events=%s (%s)" % [str(j["ok"]), str(j["n_events"]), str(j["error"])])
	eq("marble: no torn line, no bad line, no unknown event type", [j["torn"], j["bad_lines"], j["unknown_types"]], [false, 0, []])
	eq("marble: title and sentence", [j["title"], str(j["sentence"]).begins_with("A marble run: three marbles")], ["A marble run", true])
	eq("marble: 3 packages in plan order", j["order"], ["core_run", "workshop_look", "slide_feel"])
	var states: Array = []
	var rounds: Array = []
	for id: String in j["order"]:
		states.append(j["packages"][id]["state"])
		rounds.append(j["packages"][id]["round"])
	eq("marble: every package promoted, each in round 2", [states, rounds], [["promoted", "promoted", "promoted"], [2, 2, 2]])
	eq("marble: 3 of 3 packages done", [j["done"], j["total"]], [3, 3])
	var ms: Array = []
	var caps: int = 0
	var caps_exist: int = 0
	for m: Dictionary in j["milestones"]:
		ms.append(m["milestone"])
		for c: String in m["captures"]:
			caps += 1
			if FileAccess.file_exists(marble.path_join(c)):
				caps_exist += 1
	eq("marble: milestones blockout, art_pass, tuned", ms, ["blockout", "art_pass", "tuned"])
	eq("marble: 6 milestone pictures, all on disk", [caps, caps_exist], [6, 6])
	eq("marble: 6 builder notes", (j["notes"] as Array).size(), 6)
	var qs: Array = j["questions"]
	check("marble: 1 question, asked by workshop_look", qs.size() == 1 and qs[0]["package"] == "workshop_look" and str(qs[0]["text"]).begins_with("Can `core_run` enlarge"))
	check("marble: the question is answered, by the player", qs.size() == 1 and not bool(qs[0]["open"]) and qs[0]["by"] == "player" and str(qs[0]["answer"]).begins_with("No. core_run is finished"))
	eq("marble: final state done, shown as done", [j["job_state"], j["phase"]], ["done", "done"])
	eq("marble: one promotion, version 0.1.0", [(j["promotions"] as Array).size(), j["promotions"][0]["version"], j["promotions"][0]["dest"]], [1, "0.1.0", "promoted/game.marble_run_three_marbles"])
	var state: Variant = JobModel.read_json(marble.path_join("state.json"))
	if state is Dictionary:
		var tk: Dictionary = (state as Dictionary)["tokens"]
		eq("marble: token totals equal the Foreman's own state.json (in, out, cache read)", [j["tokens_in"], j["tokens_out"], j["tokens_cache"]], [int(tk["in"]), int(tk["out"]), int(tk["cacheRead"])])
	else:
		check("marble: state.json is there for the cross-check", false)
	eq("marble: token totals in figures", [j["tokens_in"], j["tokens_out"], j["tokens_cache"]], [2009179, 85150, 1689227])
	eq("marble: package tokens (in + out)", [int(j["packages"]["core_run"]["tokens_in"]) + int(j["packages"]["core_run"]["tokens_out"]), int(j["packages"]["workshop_look"]["tokens_in"]) + int(j["packages"]["workshop_look"]["tokens_out"]),
		int(j["packages"]["slide_feel"]["tokens_in"]) + int(j["packages"]["slide_feel"]["tokens_out"])], [1098007 + 33587, 471848 + 13898, 240780 + 4254])
	eq("marble: time from first to last event is 14:45", JobModel.fmt_time(float(j["elapsed_s"])), "14:45")
	check("marble: elapsed is 885.4 s", absf(float(j["elapsed_s"]) - 885.4) < 0.01, str(j["elapsed_s"]))
	eq("marble: builder time, 16 runs", [j["builder_runs"], int(j["builder_ms"]) > 600000], [16, true])
	var core_s: float = float(j["packages"]["core_run"]["work_s"])
	check("marble: core_run worked 5.2 minutes (running and verifying)", absf(core_s - 309.2) < 0.1, str(core_s))
	eq("marble: brief has the five parts, estimate 5 packages / 45 min / 600000 tokens", [(j["brief"] as Dictionary).keys(), int(j["estimate"]["packages"]), int(j["estimate"]["wallMinutes"]), int(j["estimate"]["tokens"])],
		[["rules", "arena", "ai", "controls", "mood"], 5, 45, 600000])
	eq("marble: approved (auto), no change request", [j["approved_by"], (j["changes"] as Array).size()], ["auto", 0])
	eq("marble: the promoted pack declares no params", [str(j["pack_dir"]).ends_with("promoted/game.marble_run_three_marbles"), (j["params"] as Array).size()], [true, 0])

	# ---- 2. prefixes of the log: the states the panel must show
	var text: String = FileAccess.get_file_as_string(marble.path_join("job.jsonl"))
	var lines: PackedStringArray = text.split("\n")
	var cut: Callable = func(n: int, name: String, tail: String = "") -> String:
		var d: String = tmp.path_join(name)
		DirAccess.make_dir_recursive_absolute(d)
		var f: FileAccess = FileAccess.open(d.path_join("job.jsonl"), FileAccess.WRITE)
		f.store_string("\n".join(lines.slice(0, n)) + "\n" + tail)
		f.close()
		return d
	var d1: Dictionary = JobModel.read_job(cut.call(1, "designing"), 0.0)
	eq("prefix 1 event: designing, no brief", [d1["phase"], (d1["brief"] as Dictionary).is_empty()], ["designing", true])
	var d4: Dictionary = JobModel.read_job(cut.call(4, "approve"), 0.0)
	eq("prefix 4 events: waits for approval, brief present", [d4["phase"], (d4["brief"] as Dictionary).size()], ["approve", 5])
	var d5: Dictionary = JobModel.read_job(cut.call(5, "planning"), 0.0)
	eq("prefix 5 events: planning", d5["phase"], "planning")
	var d48: Dictionary = JobModel.read_job(cut.call(48, "running"), 0.0)
	eq("prefix 48 events: running, 1 of 3 built, workshop_look at work", [d48["phase"], d48["done"], d48["total"], d48["packages"]["workshop_look"]["state"]], ["running", 1, 3, "running"])
	var d69: Dictionary = JobModel.read_job(cut.call(69, "question"), 0.0)
	eq("prefix 69 events: paused on a question, open, package blocked", [d69["phase"], d69["pause_kind"], d69["questions"][0]["open"], d69["packages"]["workshop_look"]["state"]], ["paused", "question", true, "blocked"])
	var head: String = "{\"v\":1,\"seq\":%d,\"ts\":\"2026-11-10T21:05:00.000Z\",\"job\":\"x\","
	var budget_tail: String = (head % 49) + "\"type\":\"budget\",\"policy\":{\"kind\":\"tokens_per_hour\",\"limit\":3000000},\"state\":\"paused\",\"reason\":\"3000000 tokens used this hour\"}\n" \
		+ (head % 50) + "\"type\":\"job_state\",\"state\":\"paused\",\"reason\":\"budget: 3000000 tokens used this hour\"}\n"
	var db: Dictionary = JobModel.read_job(cut.call(48, "budget", budget_tail), 0.0)
	eq("budget pause: paused, kind budget", [db["phase"], db["pause_kind"]], ["paused", "budget"])
	var fail_tail: String = (head % 49) + "\"type\":\"package_state\",\"package\":\"workshop_look\",\"state\":\"failed\",\"round\":4,\"cause\":\"verify_failed\",\"detail\":\"smoke: script error in scripts/look.gd line 41\"}\n" \
		+ (head % 50) + "\"type\":\"job_state\",\"state\":\"failed\",\"reason\":\"workshop_look failed after 4 rounds and 3 re-plans\"}\n"
	var df: Dictionary = JobModel.read_job(cut.call(48, "failed", fail_tail), 0.0)
	check("failed: failed, with its cause in one line", df["phase"] == "failed" and str(df["fail_line"]).begins_with("workshop_look: verify failed.") and not str(df["fail_line"]).contains("\n"), str(df["fail_line"]))
	var change_tail: String = (head % 127) + "\"type\":\"change_requested\",\"text\":\"Make the marbles bigger.\"}\n" \
		+ (head % 128) + "\"type\":\"job_state\",\"state\":\"running\",\"reason\":\"reopened by a change request (was done)\"}\n" \
		+ (head % 129) + "\"type\":\"reopened\",\"package\":\"core_run\",\"reason\":\"change request (event 127): the Planner names this package\"}\n" \
		+ (head % 130) + "\"type\":\"package_state\",\"package\":\"core_run\",\"state\":\"queued\",\"round\":3,\"detail\":\"CHANGE REQUEST: Make the marbles bigger.\"}\n"
	var dc: Dictionary = JobModel.read_job(cut.call(126, "change", change_tail), 0.0)
	eq("change in flight: running again, owner core_run, outcome in flight, 2 of 3 built", [dc["phase"], dc["changes"][0]["owner"], dc["changes"][0]["outcome"], dc["done"]], ["running", "core_run", "in flight", 2])
	var done_tail: String = change_tail + (head % 131) + "\"type\":\"package_state\",\"package\":\"core_run\",\"state\":\"promoted\",\"round\":3}\n" \
		+ (head % 132) + "\"type\":\"promoted\",\"packId\":\"game.marble_run_three_marbles\",\"version\":\"0.1.1\",\"dest\":\"promoted/game.marble_run_three_marbles@0.1.1\"}\n" \
		+ (head % 133) + "\"type\":\"job_state\",\"state\":\"done\",\"reason\":\"promotion 2\"}\n"
	var dd: Dictionary = JobModel.read_job(cut.call(126, "change_done", done_tail), 0.0)
	eq("change made: done again, outcome made, version 0.1.1, 2 promotions", [dd["phase"], dd["changes"][0]["outcome"], dd["changes"][0]["version"], (dd["promotions"] as Array).size()], ["done", "made", "0.1.1", 2])

	# ---- 3. a half-written job.jsonl
	var half: String = tmp.path_join("half")
	DirAccess.make_dir_recursive_absolute(half)
	var whole: String = "\n".join(lines.slice(0, 60)) + "\n"
	var f2: FileAccess = FileAccess.open(half.path_join("job.jsonl"), FileAccess.WRITE)
	f2.store_string(whole + lines[60].substr(0, lines[60].length() / 2))
	f2.close()
	var h: Dictionary = JobModel.read_job(half, 0.0)
	eq("half-written log: read without failing, 60 whole events, torn tail reported", [h["ok"], h["n_events"], h["torn"], h["bad_lines"], h["last_seq"]], [true, 60, true, 0, 60])
	eq("half-written log: still a picture (running, 2 of 3)", [h["phase"], h["done"], h["total"]], ["running", 2, 3])
	var worst: bool = true
	for n: int in [1, 7, 200, 900, 2000, 5000, 20000, text.length() / 2, text.length() - 3]:
		var f3: FileAccess = FileAccess.open(half.path_join("job.jsonl"), FileAccess.WRITE)
		f3.store_string(text.substr(0, n))
		f3.close()
		var hh: Dictionary = JobModel.read_job(half, 0.0)
		if not (hh.has("phase") and hh.has("order") and int(hh["bad_lines"]) == 0):
			worst = false
	check("half-written log: 9 cuts at arbitrary bytes all give a picture and no bad line", worst)
	var empty: String = tmp.path_join("empty")
	DirAccess.make_dir_recursive_absolute(empty)
	FileAccess.open(empty.path_join("job.jsonl"), FileAccess.WRITE).close()
	var he: Dictionary = JobModel.read_job(empty, 0.0)
	eq("empty log: shown as unreadable with a reason, not as a job", [he["phase"], str(he["error"]).is_empty()], ["unreadable", false])
	var gone: Dictionary = JobModel.read_job(tmp.path_join("no_such_job"), 0.0)
	eq("missing job directory: unreadable, no crash", [gone["ok"], gone["phase"]], [false, "unreadable"])
	eq("jobs root: lists job directories only", JobModel.list_job_dirs(tmp).size(), 11)
	eq("empty jobs root: empty list", JobModel.list_job_dirs(tmp.path_join("no_such_root")).size(), 0)

	# ---- 4. the Foreman: missing, present, dead
	var none: Door = Door.new()
	none.setup(tmp, {"cli": tmp.path_join("nowhere/foreman/dist/cli.js"), "flags": {"new": []}})
	check("missing Foreman: reported, with the path", not none.available and none.problem.begins_with("Foreman not found"), none.problem)
	eq("missing Foreman: a new game is refused with that reason, nothing is started", [none.new_game("a game").begins_with("Foreman not found"), none.started.size()], [true, 0])
	print("[selftest] the engine prints one ERROR line next (Could not create child process): that is the missing node being tried")
	var nonode: Door = Door.new()
	nonode.setup(tmp, {"cli": repo.path_join("foreman/dist/cli.js"), "node": "no-such-node-exe", "flags": {"new": []}})
	check("missing node: reported", not nonode.available and nonode.problem.begins_with("Node not found"), nonode.problem)
	var real: Door = Door.new()
	real.setup(tmp, {"cli": repo.path_join("foreman/dist/cli.js"), "flags": {"new": []}})
	check("the repository's Foreman is found and node answers", real.available and real.node_version.begins_with("v"), real.problem)
	eq("Foreman found by walking up from the engine", Door.find_cli(ProjectSettings.globalize_path("res://")).ends_with("foreman/dist/cli.js"), true)
	var noflags: Door = Door.new()
	noflags.setup(tmp, {"cli": repo.path_join("foreman/dist/cli.js")})
	check("no Foreman settings: nothing can be started, and it says so", not noflags.available and noflags.problem.begins_with("No Foreman settings"), noflags.problem)
	var dry: Door = Door.new()
	dry.setup(tmp, {"cli": repo.path_join("foreman/dist/cli.js"), "flags": {"new": []}, "dry": true})
	eq("capture mode: starts nothing", [dry.new_game("x").is_empty(), dry.started.size()], [false, 0])
	dry.flags = {"new": ["--adapter", "fake"], "plan": ["--adapter", "fake", "--max-packages", "4"], "run": ["--adapter", "fake", "--parallel", "1"]}
	dry.dry_steps.clear()
	dry.new_game("A game with \"quotes\"\nand a line break")
	eq("door: New game starts new <sentence> --site <jobs root> <flags>, the sentence as one clean argument", dry.dry_steps[0], [["new", "A game with 'quotes' and a line break", "--site", tmp, "--adapter", "fake"]])
	dry.approve("J")
	eq("door: Approve starts approve, then plan, then run, as one chain", dry.dry_steps[1], [["approve", "J"], ["plan", "J", "--adapter", "fake", "--max-packages", "4"], ["run", "J", "--adapter", "fake", "--parallel", "1"]])
	dry.answer("J", "feel", "yes", "core")
	eq("door: an answer that lets a package change starts answer --change, then resume (with run's flags)", dry.dry_steps[2], [["answer", "J", "feel", "yes", "--change", "core"], ["resume", "J", "--adapter", "fake", "--parallel", "1"]])
	dry.answer("J", "feel", "no", "")
	eq("door: a plain answer starts answer, then resume", dry.dry_steps[3], [["answer", "J", "feel", "no"], ["resume", "J", "--adapter", "fake", "--parallel", "1"]])
	dry.change("J", "bigger marbles")
	eq("door: Send in Change starts change <job> <text> <flags>", dry.dry_steps[4], [["change", "J", "bigger marbles", "--adapter", "fake", "--parallel", "1"]])
	dry.discard("J")
	eq("door: Discard starts cancel", dry.dry_steps[5], [["cancel", "J", "--reason", "discarded by the player"]])
	dry.resume("J", true, true)
	dry.resume("J", false, false)
	eq("door: Resume starts resume, or plan and run when there is no plan yet", [dry.dry_steps[6], dry.dry_steps[7]], [[["resume", "J", "--adapter", "fake", "--parallel", "1"]], [["plan", "J", "--adapter", "fake", "--max-packages", "4"], ["run", "J", "--adapter", "fake", "--parallel", "1"]]])
	eq("door: empty text is refused before anything is started", [dry.new_game("  "), dry.change("J", ""), dry.answer("J", "feel", " ", ""), dry.dry_steps.size()], ["describe the game first", "say what should be different first", "write the answer first", 8])
	eq("a dead pid is not alive; this process is", [real.pid_alive(999999), real.pid_alive(OS.get_process_id())], [false, true])
	var stale: String = cut.call(31, "stale")
	var lf: FileAccess = FileAccess.open(stale.path_join("foreman.lock"), FileAccess.WRITE)
	lf.store_string("999999")
	lf.close()
	var ds: Dictionary = JobModel.read_job(stale, 0.0)
	eq("a running job whose lock names a dead process: no Foreman alive", [ds["phase"], ds["lock_pid"], real.foreman_alive(stale, int(ds["lock_pid"]))], ["running", 999999, false])

	# ---- 5. Tune: a slider's write to a copy of a pack's data file
	var pack: String = tmp.path_join("pack")
	DirAccess.make_dir_recursive_absolute(pack.path_join("data"))
	var src: String = marble.path_join("promoted/game.marble_run_three_marbles")
	DirAccess.copy_absolute(src.path_join("data/tuning.json"), pack.path_join("data/tuning.json"))
	var man: Dictionary = JobModel.read_json(src.path_join("pack.json"))
	man["params"] = [
		{"name": "rubber_drag", "file": "data/tuning.json", "path": "marbles.rubber.linear_damp", "min": 0.1, "max": 2.0, "step": 0.05, "label": "Rubber marble drag"},
		{"name": "settle_frames", "file": "data/tuning.json", "path": "settle_frames", "min": 30, "max": 240, "step": 10, "label": "Frames until settled"},
		{"name": "nope", "file": "data/tuning.json", "path": "marbles.glass.linear_damp", "min": 0, "max": 1, "step": 0.1, "label": "Not there"},
	]
	var mf: FileAccess = FileAccess.open(pack.path_join("pack.json"), FileAccess.WRITE)
	mf.store_string(JobModel.to_json(man, 0))
	mf.close()
	var params: Array = JobModel.read_params(pack)
	eq("tune: 3 params read, current values from the data file", [params.size(), params[0]["value"], params[1]["value"], params[0]["ok"], params[2]["ok"]], [3, 1.2, 90.0, true, false])
	var before: Dictionary = JobModel.read_json(pack.path_join("data/tuning.json"))
	eq("tune: write 0.85 to marbles.rubber.linear_damp", JobModel.write_param(pack, params[0], 0.85), "")
	eq("tune: write 120 to settle_frames", JobModel.write_param(pack, params[1], 120.0), "")
	var after_text: String = FileAccess.get_file_as_string(pack.path_join("data/tuning.json"))
	var parser: JSON = JSON.new()
	check("tune: the file is still valid JSON", parser.parse(after_text) == OK and parser.data is Dictionary)
	var after: Dictionary = parser.data
	eq("tune: both values are in the file", [after["marbles"]["rubber"]["linear_damp"], after["settle_frames"]], [0.85, 120.0])
	before["marbles"]["rubber"]["linear_damp"] = 0.85
	before["settle_frames"] = 120.0
	eq("tune: nothing else in the file changed, key order kept", [after == before, after.keys()], [true, before.keys()])
	check("tune: whole numbers are written without a fraction", after_text.contains("\"settle_frames\": 120,") and after_text.contains("\"order\": 0"), after_text.substr(0, 120))
	check("tune: a param with no value at its path is refused", not JobModel.write_param(pack, params[2], 0.5).is_empty())
	check("tune: a file outside the pack is refused", not JobModel.write_param(pack, {"file": "../x.json", "path": "a"}, 1.0).is_empty())
	check("tune: no temporary file is left", not FileAccess.file_exists(pack.path_join("data/tuning.json.tmp")))

	# ---- 6. small things the rows rely on
	eq("figures: tokens", [JobModel.fmt_tokens(2094329), JobModel.fmt_tokens(485746), JobModel.fmt_tokens(5200), JobModel.fmt_tokens(0)], ["2.09M", "486k", "5.2k", "0"])
	eq("figures: time", [JobModel.fmt_time(885.4), JobModel.fmt_time(3725.0), JobModel.fmt_minutes(309.2)], ["14:45", "1:02:05", "5.2 min"])
	eq("one line: no line breaks, no markdown marks, cut with an ellipsis", JobModel.one_line("- **Ramp**\nlayout: `x`  y", 12), "Ramp layout…")

	_remove(tmp)
	print("[selftest] %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _remove(dir: String) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	for sub: String in d.get_directories():
		_remove(dir.path_join(sub))
	for f: String in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(dir)
