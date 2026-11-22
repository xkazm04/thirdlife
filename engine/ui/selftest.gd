extends SceneTree
## N6 selftest (tools/ui.sh selftest): headless checks of the model behind the designer panel. Reads the real marble
## job (read only), writes only into the user's temporary directory. One PASS/FAIL line per check; exit code 1 when
## any failed.

const JobModel = preload("res://ui/job_model.gd")
const Door = preload("res://ui/foreman_door.gd")
const PlacePanel = preload("res://ui/editor/place_panel.gd")

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
	# N4 (night of 22-23 Nov): in an exported build res:// globalizes to "" (boot/probe.gd), and the walk up from "" found no
	# Foreman: GO in Create said "The builders cannot start: Foreman not found" in every exe. The door as an exe sets it up.
	var exe_path: String = repo.path_join("dist/ThirdLife/ThirdLife.exe")
	eq("exe layout: the walk up from res:// as the exe globalizes it ('') finds nothing (the bug of 22 Nov)", Door.find_cli(""), "")
	eq("exe layout: the Foreman is looked for from the executable's folder", Door.disk_dir_of("", exe_path), repo.path_join("dist/ThirdLife"))
	var exe: Door = Door.new()
	exe.setup(tmp, {"res_dir": "", "exe": exe_path, "flags": {"new": []}})
	check("exe layout: the door finds the checkout's Foreman and its starter, and node answers", exe.available, exe.problem)
	eq("exe layout: cli and starter are the checkout's files on disk", [exe.cli_path, exe.runner_path],
		[repo.path_join("foreman/dist/cli.js"), repo.path_join("engine/ui/foreman_run.mjs")])
	var far: Door = Door.new()
	far.setup(tmp, {"res_dir": "", "exe": tmp.path_join("no_repo/ThirdLife/ThirdLife.exe"), "flags": {"new": []}})
	check("exe with no checkout above it: says where it looked", not far.available and far.problem.contains(tmp.path_join("no_repo/ThirdLife")), far.problem)
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
	var answers := {"players": "3"}
	var lot := {"at": [-100.0, 40.0], "yaw_deg": -15.0, "radius": 22.0}
	var decision := {"key": "players", "to": "2"}
	dry.new_game("Hockey", answers, lot)
	dry.change("J", "Fewer players", decision)
	for row in [[8, "--answers", answers], [8, "--lot", lot], [9, "--decision", decision]]:
		var args: Array = dry.dry_steps[row[0]][0]
		var flag := args.find(row[1])
		var arg: String = args[flag + 1] if flag >= 0 and flag + 1 < args.size() else ""
		check("door: %s is one json64 argument" % row[1], arg.begins_with("json64:") and
			JSON.parse_string(Marshalls.base64_to_utf8(arg.trim_prefix("json64:"))) == row[2])
	# Round 2 (19 Nov): the editor's place calls travel to `foreman new --place-calls` (logged as builder runs)
	var pdry: Door = Door.new()
	pdry.setup(tmp, {"cli": repo.path_join("foreman/dist/cli.js"), "flags": {"new": []}, "dry": true})
	var pm := {"place_calls": []}
	PlacePanel.record_call(pm, {"schema": "tl.place-answer/1", "proposals": [], "adapter": "claude-cli", "model": "claude-sonnet-5-5", "durationMs": 8125.0, "tokensIn": 5296.0, "tokensOut": 581.0})
	PlacePanel.record_call(pm, {"schema": "tl.place-answer/1", "error": "builder timeout"})
	eq("place: a model call's figures are kept, an error without figures is not", pm.place_calls, [{"adapter": "claude-cli", "model": "claude-sonnet-5-5", "durationMs": 8125, "tokensIn": 5296, "tokensOut": 581}])
	pdry.new_game("Hockey", {}, {}, pm.place_calls)
	pdry.new_game("Hockey")
	var pargs: Array = pdry.dry_steps[0][0]
	var pflag := pargs.find("--place-calls")
	check("door: --place-calls is one json64 argument with the calls", pflag >= 0 and str(pargs[pflag + 1]).begins_with("json64:") and
		Marshalls.base64_to_utf8(str(pargs[pflag + 1]).trim_prefix("json64:")) == JSON.stringify(pm.place_calls), str(pargs))
	check("door: no place calls, no --place-calls flag", not (pdry.dry_steps[1][0] as Array).has("--place-calls"), str(pdry.dry_steps[1]))
	var reduced := JobModel.reduce([{"type": "job_created", "answers": answers, "lot": lot},
		{"type": "change_requested", "text": "Fewer players", "decision": decision}], 0)
	check("job model: answers, placement and change decision survive reduction",
		reduced.get("answers") == answers and reduced.get("lot") == lot and reduced.changes[0].get("decision") == decision)
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

	# ---- 7. lane C4: the recipe and the hand checks in a person's words (no ids on screen)
	var hc: Callable = func(rows: Array) -> Array: return [{"seq": 90, "summary": {"seeds": 20, "rows": rows}}]
	var base_job: Dictionary = {"plan_revisions": 1, "card": "card.knock_down", "recipe": {}, "hand_checks": [], "hand_rounds": []}
	eq("recipe: no plan yet says nothing", JobModel.recipe_words({"plan_revisions": 0}), "")
	eq("recipe: a plan without a card", JobModel.recipe_words({"plan_revisions": 1, "card": ""}), "Built without a recipe.")
	eq("recipe: a card that had no hand checks (tonight's crate job)", JobModel.recipe_words(base_job), "Built from the knock-down recipe. This recipe had no hand checks when the game was built.")
	var asked: Dictionary = base_job.duplicate(true)
	asked["recipe"] = {"hands": {"seeds": 20, "checks": [{"hand": "idle"}]}}
	eq("recipe: checks owed, not run yet", JobModel.recipe_words(asked), "Built from the knock-down recipe. Its hand checks run when the game is finished.")
	var held: Dictionary = base_job.duplicate(true)
	held["hand_checks"] = hc.call([{"hand": "idle", "wins": 0, "completed": 20, "seeds": 20, "ok": true, "wins_max": 0}, {"hand": "sharp", "wins": 18, "completed": 20, "seeds": 20, "ok": true, "wins_min": 13}])
	eq("recipe: checks that held, in words", JobModel.recipe_words(held), "Built from the knock-down recipe. Doing nothing never wins; a sharp player wins 18 of 20.")
	var missed: Dictionary = held.duplicate(true)
	missed["hand_checks"] = hc.call([{"hand": "idle", "wins": 2, "completed": 20, "seeds": 20, "ok": false, "wins_max": 0}, {"hand": "perfect", "wins": 9, "completed": 20, "seeds": 20, "ok": false, "wins_min": 16}])
	missed["hand_rounds"] = ["court"]
	eq("recipe: a check missed twice, in words", JobModel.recipe_words(missed), "Built from the knock-down recipe. Doing nothing won 2 of 20 (it should never win); a flawless player won only 9 of 20 (the recipe expects at least 16). The builder got one more round, and it still missed: the game was not handed over.")
	check("recipe: no developer words on screen", not JobModel.recipe_words(missed).contains("card.") and not JobModel.recipe_words(missed).contains("wins_min") and not JobModel.recipe_words(missed).contains("_"))
	var rj: Dictionary = JobModel.read_job(marble, 0.0)
	eq("recipe: the real marble job has no card (built before cards)", [str(rj.get("card", "?")), str(rj.get("recipe_words", "?"))], ["", "Built without a recipe."])

	_workbench_checks()
	preload("res://ui/editor/selftest_place.gd").run(self, tmp)
	# ---- 8. night of 21 Nov (L3): the Create page and the designer v2 readers, from ui/fixtures/create/
	var create_done: Variant = await preload("res://ui/create/create_checks.gd").run(self, func(name: String, ok: bool, detail: String = "") -> void: check(name, ok, detail), tmp)
	if create_done != true:
		check("create: the Create page's checks ran to their end", false, "stopped half way (a script error above)")
	# a v2 key in a marble prefix: the panel's model takes it (creativity, a pause on a phase)
	var v2_tail: String = (head % 49) + "\"type\":\"phase_done\",\"phase\":\"first\"}
" + (head % 50) + "\"type\":\"job_state\",\"state\":\"paused\",\"reason\":\"phase\"}
"
	var dv2: Dictionary = JobModel.read_job(cut.call(48, "v2_phase", v2_tail), 0.0)
	eq("v2: a phase_done on a plan without phases is not a known phase: paused, not a phase wait", [dv2["phase"], dv2["pause_kind"], (dv2["unknown_types"] as Array).size()], ["paused", "other", 0])

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


## E1: the workbench's model (ui/editor/editor_model.gd) and the recipe cards' interviews and the editor's none.json.
func _workbench_checks() -> void:
	var M: GDScript = load("res://ui/editor/editor_model.gd")
	var m: RefCounted = M.new()
	m.call("load_all")
	eq("workbench: the card interviews and the fallback load", m.get("load_errors"), [])
	var names: PackedStringArray = m.get("interview_order")
	eq("workbench: one interview per card, none last", names, ["knock_down", "team_possession", "timed_drive", "two_sides_ball", "none"])
	var counts: Array = []
	for name in names:
		counts.append(m.get("interviews")[name].questions.size())
	eq("workbench: original question counts for the sorted recipes and fallback", counts, [4, 6, 4, 3, 4])
	# the template rule (registry, templates-scaffolding): every proposal is a member of its own options; ids unique
	var bad: PackedStringArray = []
	var allowed_q: Array = ["key", "group", "ask", "options", "propose", "reason"]
	var allowed_o: Array = ["id", "label", "say", "size", "from_words", "shape", "stands"]
	for n: String in names:
		var iv: Dictionary = (m.get("interviews") as Dictionary)[n]
		var keys: Dictionary = {}
		for q: Dictionary in iv.get("questions", []):
			for k: String in q:
				if not allowed_q.has(k):
					bad.append("%s.%s: unknown key %s" % [n, str(q.get("key")), k])
			if keys.has(q["key"]):
				bad.append("%s: question %s twice" % [n, str(q["key"])])
			keys[q["key"]] = true
			if not ["who", "win", "where"].has(str(q["group"])):
				bad.append("%s.%s: group %s" % [n, str(q["key"]), str(q["group"])])
			var ids: Dictionary = {}
			for o: Dictionary in q["options"]:
				for k: String in o:
					if not allowed_o.has(k):
						bad.append("%s.%s.%s: unknown key %s" % [n, str(q["key"]), str(o["id"]), k])
				if ids.has(o["id"]):
					bad.append("%s.%s: option %s twice" % [n, str(q["key"]), str(o["id"])])
				ids[o["id"]] = true
			if not ids.has(q["propose"]):
				bad.append("%s.%s: proposal %s is not one of its options" % [n, str(q["key"]), str(q["propose"])])
			if str(q.get("reason", "")).is_empty():
				bad.append("%s.%s: a proposal without a reason" % [n, str(q["key"])])
		for v: Dictionary in iv.get("variants", []):
			for k: String in (v["set"] as Dictionary):
				var q: Dictionary = {}
				for qq: Dictionary in iv["questions"]:
					if qq["key"] == k:
						q = qq
				if q.is_empty() or (m.call("option", q, str(v["set"][k])) as Dictionary).is_empty():
					bad.append("%s: variant \"%s\" sets %s=%s, not an option" % [n, str(v["ask"]), k, str(v["set"][k])])
		if n != "none":
			var card: Dictionary = (m.get("cards") as Dictionary).get(str(iv["card"]), {})
			var asks: Array = []
			for cv: Dictionary in card.get("variants", []):
				asks.append(cv["ask"])
			for v: Dictionary in iv.get("variants", []):
				if not asks.has(v["ask"]):
					bad.append("%s: variant \"%s\" is not one of the card's" % [n, str(v["ask"])])
	eq("workbench: interviews are well formed (proposal among options, reasons, variants are the card's)", bad, [])

	# matching and reading answers out of the sentence
	m.call("set_sentence", "ice hockey, three against three, against the computer")
	eq("workbench: hockey sentence -> team possession", m.get("recipe"), "team_possession")
	eq("workbench: answers read from the hockey sentence", [m.call("value", "sport"), m.call("value", "players")],
		[{"id": "ice_hockey", "by": "sentence", "words": "ice hockey"}, {"id": "3", "by": "sentence", "words": "three against three"}])
	eq("workbench: an unanswered question stands at its proposal", m.call("value", "opponents"), {"id": "rookie", "by": "proposal"})
	m.call("set_sentence", "street hockey, five a side")
	eq("workbench: the longest phrase wins (street hockey over hockey)", [str((m.call("value", "sport") as Dictionary)["id"]), str((m.call("value", "players") as Dictionary)["id"])], ["street", "5"])
	m.call("answer", "sport", "football")
	m.call("set_sentence", "street hockey, five a side, quickly")
	eq("workbench: the sentence never overwrites the player's answer", (m.call("value", "sport") as Dictionary)["by"], "player")
	var m2: RefCounted = M.new()
	m2.call("load_all")
	m2.call("set_sentence", "an arena where I fight waves of goblins with a sword")
	eq("workbench: arena RPG -> no recipe, the generic interview", [m2.get("recipe"), m2.call("has_card")], ["none", false])
	m2.call("set_sentence", "a Takeshi's castle obstacle course with jumps and a slide")
	eq("workbench: obstacle course -> no recipe, sized like Timber Run", [m2.get("recipe"), m2.call("footprint")], ["none", Vector3(18, 50, 12)])
	m2.call("set_sentence", "knock down a tower of crates with a ball")
	eq("workbench: crates sentence -> knock down", m2.get("recipe"), "knock_down")
	m2.call("set_sentence", "race")
	eq("workbench: one word chooses nothing", m2.get("recipe"), "")
	m2.call("set_sentence", "ice h")
	eq("workbench: no \"no recipe\" flash while the first words are typed", m2.get("recipe"), "")
	m2.call("set_sentence", "a car race of three laps on ice")
	m2.call("first_free")
	m2.call("place", m2.call("first_free"), "auto")
	check("workbench: a 96 x 70 m track has no room by the road -> said so, first", bool(m2.get("no_free")) and str((m2.call("checks") as Array)[0]["what"]) == "no_room", str(m2.call("checks")))
	eq("workbench: drive sentence -> timed drive, road read as ice", [m2.get("recipe"), str((m2.call("value", "road") as Dictionary)["id"])], ["timed_drive", "ice"])
	# Day 19 Nov: nothing by the road holds a 47 m arena; the best measured place further back is taken, and said
	m2.call("set_sentence", "an arena where I fight waves of goblins with a sword")
	m2.call("place", m2.call("first_free"), "auto")
	check("workbench: no room by the road for a %d m arena ring -> the best measured place further back, said so" % int(m2.call("lot_radius")),
		bool(m2.get("auto_far")) and bool(m2.call("fits")) and (m2.call("checks") as Array).any(func(c: Dictionary) -> bool: return c["what"] == "no_roadside"), str(m2.call("checks")))

	# size: the base, set and add; the lot ring by the world's rule
	var h: RefCounted = M.new()
	h.call("load_all")
	h.call("set_sentence", "ice hockey, three against three")
	eq("workbench: hockey footprint, proposals (rink 67 x 37 + stands 8 m)", h.call("footprint"), Vector3(67, 45, 12))
	eq("workbench: lot ring = ceil(half diagonal + 4)", h.call("lot_radius"), ceilf(Vector2(67, 45).length() * 0.5 + 4.0))
	h.call("answer", "rink", "big")
	h.call("answer", "players", "5")
	eq("workbench: big ice sets, five a side adds", h.call("footprint"), Vector3(84 + 8, 44 + 4 + 8, 12))
	h.call("answer", "rink", "small")
	h.call("answer", "players", "3")
	h.call("answer", "dressing", "bare")
	eq("workbench: a small bare rink", h.call("footprint"), Vector3(47, 27, 9))
	eq("workbench: the ring is at least 12 m", maxf(12.0, 1.0) <= float(h.call("lot_radius")), true)

	# the village: plots, road, checks
	check("workbench: the village map is read (plots, sites, road)", bool(h.get("village_ok")) and (h.get("plots") as Array).size() == 10 and (h.get("road") as PackedVector2Array).size() == 7,
		"plots %d road %d" % [(h.get("plots") as Array).size(), (h.get("road") as PackedVector2Array).size()])
	eq("workbench: nothing placed yet -> Build it names it", h.call("blocker"), "the place: no place chosen on the map yet")
	h.call("place", Vector2(194, 61))
	var ck: Array = h.call("checks")
	check("workbench: on the hockey plot -> overlap named", ck.size() > 0 and str(ck[0]["text"]).begins_with("its edge would cross hockey's"), str(ck))
	h.call("place", Vector2(0, 0))
	var on_road: bool = false
	for c: Dictionary in h.call("checks"):
		if c["what"] == "road":
			on_road = true
	check("workbench: on the road -> named", on_road, str(h.call("checks")))
	h.call("place", Vector2(5000, 0))
	var outside: bool = false
	for c: Dictionary in h.call("checks"):
		if c["what"] == "outside":
			outside = true
	check("workbench: far away -> outside the village", outside)
	h.call("place", Vector2(-250, -30))
	var in_river: bool = false
	for c: Dictionary in h.call("checks"):
		if c["what"] == "river":
			in_river = true
	check("workbench: on the river -> named (E6: the tour put a lot in it)", in_river, str(h.call("checks")))
	var free: Vector2 = h.call("first_free")
	h.call("place", free)
	eq("workbench: a place set by hand is the player's", h.get("placed_by"), "player")
	check("workbench: first_free fits, gate faces the road", bool(h.call("fits")) and float(h.call("path_m")) < 40.0, "at %s checks %s" % [str(free), str(h.call("checks"))])
	var g: Vector2 = h.call("gate")
	var rp: Vector2 = h.call("road_point", free)
	check("workbench: the gate is on the ring, toward the road", absf(g.distance_to(free) - float(h.call("lot_radius")) - 0.5) < 0.01 and g.distance_to(rp) < free.distance_to(rp))
	h.call("turn", 2)
	eq("workbench: Q / E turn by 15 degrees", snappedf(rad_to_deg(float(h.get("yaw"))), 0.1), 30.0)

	# what is sent: the player's words first, verbatim; a draft with no null and no empty list
	var req: String = h.call("request")
	check("workbench: the request starts with the player's words", req.begins_with("ice hockey, three against three. Decided: "), req)
	check("workbench: the request carries every decision", req.contains("a small 40 x 20 m rink") and req.contains("nothing around it but the boards") and req.contains("rookie opponents"), req)
	var d: Dictionary = h.call("draft")
	eq("workbench: draft keys", d.keys(), ["schema", "sentence", "request", "answers", "footprint", "lot", "placed_by", "why", "card", "left_to_proposal"])
	check("workbench: no null in the draft", not JSON.stringify(d).contains("null"))
	h.call("take_proposals")
	check("workbench: after Take the proposals nothing is left to the proposal", not (h.call("draft") as Dictionary).has("left_to_proposal"))
	eq("workbench: a fitting placement leaves nothing blocking", h.call("blocker"), "")

	# E2: the game sheet finds the workbench's draft by the job's sentence (the door turns " into ' on the command line)
	var GS: GDScript = load("res://ui/editor/game_sheet.gd")
	var root: String = OS.get_user_data_dir().path_join("tl_ui_selftest_drafts_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(root.path_join("_editor"))
	var dd: Dictionary = h.call("draft")
	dd["request"] = "a game called \"Puck\". Decided: three against three."
	var f: FileAccess = FileAccess.open(root.path_join("_editor/x.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(dd))
	f.close()
	eq("game sheet: the draft is found by the job's sentence", str((GS.call("find_draft", root, "a game called 'Puck'. Decided: three against three.") as Dictionary).get("schema", "")), "tl.editor-draft/1")
	eq("game sheet: no draft for another sentence", (GS.call("find_draft", root, "something else") as Dictionary).is_empty(), true)
	eq("game sheet: no _editor directory, no draft", (GS.call("find_draft", root.path_join("nowhere"), "x") as Dictionary).is_empty(), true)
	# E6: the construction site reads the same draft: the lot the player chose, for the job whose sentence it is
	var SiteGd: GDScript = load("res://kernel/world/site.gd")
	DirAccess.make_dir_recursive_absolute(root.path_join("puck-1"))
	DirAccess.make_dir_recursive_absolute(root.path_join("other-1"))
	for jd: Array in [["puck-1", "a game called 'Puck'. Decided: three against three."], ["other-1", "something else entirely"]]:
		var jf: FileAccess = FileAccess.open(root.path_join(str(jd[0])).path_join("job.jsonl"), FileAccess.WRITE)
		jf.store_string(JSON.stringify({"v": 1, "seq": 1, "ts": "2026-11-19T03:00:00.000Z", "job": str(jd[0]), "type": "job_created", "sentence": str(jd[1]), "packId": "game.puck", "title": "Puck"}) + "
")
		jf.close()
	var sl: Dictionary = SiteGd.call("draft_lot", root.path_join("puck-1"))
	eq("site: the lot of a workbench game comes from its draft", [sl.get("at", []), sl.get("radius", 0.0), sl.get("file", "")], [[float((dd["lot"]["at"] as Array)[0]), float((dd["lot"]["at"] as Array)[1])], float(dd["lot"]["radius"]), "x.json"])
	eq("site: a job without a draft keeps the walk's lot", (SiteGd.call("draft_lot", root.path_join("other-1")) as Dictionary).is_empty(), true)
	var log_path := root.path_join("puck-1/job.jsonl")
	var created: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(log_path))
	eq("site: old job has no logged placement", SiteGd.call("job_lot", root.path_join("puck-1")), {})
	for placement in [{"at": [-100.0, 40.0], "yaw_deg": -15.0, "radius": 22.0},
			{"at": [1, "x"], "yaw_deg": 0, "radius": 12}, {"at": [0, 0], "yaw_deg": 0, "radius": 5}]:
		created["lot"] = placement
		var log_file := FileAccess.open(log_path, FileAccess.WRITE)
		log_file.store_line(JSON.stringify(created))
		log_file.close()
		check("site: job_lot checks placement %s" % str(placement), SiteGd.call("job_lot", root.path_join("puck-1")) ==
			(placement if placement.radius == 22 else {}))
	_remove(root)

	# E3: changing a decision from the game sheet (no scene: the sheet's model, job and draft set by hand)
	var sheet: Control = GS.new()
	var sm: RefCounted = M.new()
	sm.call("load_all")
	sheet.set("model", sm)
	var hd: Dictionary = {"schema": "tl.editor-draft/1", "sentence": "ice hockey, three against three",
		"answers": {"sport": {"id": "ice_hockey", "by": "sentence"}, "rink": {"id": "big", "by": "player"}},
		"lot": {"at": [-220, 73], "yaw_deg": 0, "radius": 54}, "card": "card.team_possession"}
	sheet.set("draft", hd)
	sheet.call("_model_from_draft")
	var rq: Dictionary = sm.call("question", "rink")
	var ct: String = sheet.call("_change_text", rq, "big", "standard")
	eq("change: the request names the question, both options and what to make", ct, "Change of a decision: How big is the rink? Standard 60 x 30 m instead of Big ice 80 x 40 m. Make it a 60 x 30 m rink.")
	sheet.set("job", {"done": 0, "changes": []})
	eq("change: nothing built yet -> the panel's own reason", sheet.call("_change_blocker"), "A change can be asked for once the first package is built.")
	sheet.set("job", {"done": 2, "changes": [], "shown": "done"})
	eq("change: no door -> said so", sheet.call("_change_blocker"), "No Foreman.")
	hd["changes"] = [{"key": "rink", "from": "big", "to": "standard", "text": ct}]
	sheet.set("job", {"done": 2, "changes": [{"text": ct, "outcome": "in flight"}], "shown": "running"})
	sheet.call("_apply_answers")
	eq("change: in flight -> the decision stands as it was", str((sm.call("value", "rink") as Dictionary)["id"]), "big")
	sheet.set("job", {"done": 2, "changes": [{"text": ct, "outcome": "made"}], "shown": "done"})
	sheet.call("_apply_answers")
	eq("change: made -> the decision is the new option, marked changed", [str((sm.call("value", "rink") as Dictionary)["id"]), bool((sm.call("value", "rink") as Dictionary).get("changed", false))], ["standard", true])
	sheet.set("job", {"changes": [{"text": ct, "outcome": "failed", "decision": {"key": "rink", "to": "small"}},
		{"text": "Different wording", "outcome": "made", "decision": {"key": "rink", "to": "standard"}}]})
	sheet.call("_apply_answers")
	eq("change: the structured decision identifies the request even when its words differ", sheet.get("_outcomes"), ["made"])
	hd.changes.append(hd.changes[0].duplicate())
	sheet.call("_apply_answers")
	eq("change: an earlier outcome cannot complete a second request for the same option", sheet.get("_outcomes"), ["made", ""])
	hd.changes.pop_back()
	sheet.set("job", {"done": 2, "changes": [{"text": ct, "outcome": "not made"}], "shown": "done"})
	sheet.call("_apply_answers")
	eq("change: not made -> the decision stands as it was", str((sm.call("value", "rink") as Dictionary)["id"]), "big")
	var big_ring: float = sm.call("lot_radius")
	sheet.set("_pending", {"key": "rink", "to": "small"})
	sheet.call("_apply_answers")
	check("change: a picked option refits the ring before anything is sent", float(sm.call("lot_radius")) < big_ring, "%s -> %s" % [str(big_ring), str(sm.call("lot_radius"))])
	sheet.free()

	# E5: the village board says what a game is doing in the site's words
	var VB: GDScript = load("res://ui/editor/village_board.gd")
	eq("board: words per phase", [VB.call("words", {}, "designing"), VB.call("words", {}, "approve"), VB.call("words", {"done": 1, "total": 3}, "running"),
		VB.call("words", {"pause_kind": "question"}, "paused"), VB.call("words", {}, "done"), VB.call("words", {}, "failed"), VB.call("words", {}, "stalled")],
		["being designed", "waits for you", "building 1 of 3", "waits for your answer", "ready to play", "could not be finished", "stopped"])
	eq("board: a running job before its plan", VB.call("words", {"done": 0, "total": 0}, "running"), "building")
