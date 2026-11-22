extends SceneTree
## N4 (night of 22-23 Nov 2026): the kernel selftest block 780 (tools/selftest.d/780-create-go.sh). Create's GO as an
## exported build meets it, for real: the page's door is set up with the exe's layout (res:// globalizes to "", the
## executable in <repo>/dist/ThirdLife), a surprise chip and GO start `foreman new` through the door's runner with the
## fake adapter (no model is called), and the page must reach the Designer's first answer (the pitch). Every check in
## the repository's other selftests ran the door dry, so none saw that GO in the exe found no Foreman (22 Nov).
##
##   godot --headless --fixed-fps 60 --path engine --script res://ui/create/create_go_case.gd -- --repo=<dir>
##       --flags=<flags.fake-designer.json> --jobs=<empty dir>
## Prints "PASS <name>" or "FAIL <name>  -> <why>" per check, then "[create-go] <n> passed, <m> failed".

const CreateScene = preload("res://ui/create/create.tscn")
const JobModel = preload("res://ui/job_model.gd")
const Model = preload("res://ui/create/create_model.gd")

## Frames to wait for the fake Designer (each frame also sleeps 10 ms: about 40 s for node to answer).
const WAIT_FRAMES: int = 4000

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	var a: Dictionary = {}
	for s: String in OS.get_cmdline_user_args():
		if s.begins_with("--") and s.contains("="):
			a[s.substr(2).get_slice("=", 0)] = s.get_slice("=", 1)
	var repo: String = str(a.get("repo", "")).replace("\\", "/").trim_suffix("/")
	var jobs: String = str(a.get("jobs", "")).replace("\\", "/").trim_suffix("/")
	var f: Variant = JobModel.read_json(str(a.get("flags", "")))
	if repo.is_empty() or jobs.is_empty() or not (f is Dictionary):
		_check("create.go.args: --repo, --jobs and a readable --flags file", false, str(a))
		_end()
		return
	DirAccess.make_dir_recursive_absolute(jobs)
	await process_frame
	var page: Control = CreateScene.instantiate()
	page.call("setup", {"jobs": jobs, "flags": (f as Dictionary).get("flags", {}), "flags_name": str((f as Dictionary).get("name", "")),
		"door": {"res_dir": "", "exe": repo.path_join("dist/ThirdLife/ThirdLife.exe")}})
	root.add_child(page)
	page.call("open")
	var door: RefCounted = page.get("door")
	_check("create.go.door: as in an exe, the door finds the checkout's Foreman and its starter on disk, and node answers",
		str(door.get("from_dir")) == repo.path_join("dist/ThirdLife")
		and bool(door.get("available")) and str(door.get("cli_path")) == repo.path_join("foreman/dist/cli.js")
		and str(door.get("runner_path")) == repo.path_join("engine/ui/foreman_run.mjs"),
		"looked from %s, available %s, problem '%s', cli %s, starter %s" % [str(door.get("from_dir")), str(door.get("available")), str(door.get("problem")), str(door.get("cli_path")), str(door.get("runner_path"))])
	(page.find_child("Chip0", true, false) as Button).pressed.emit()
	var said: String = str(page.get("sentence"))
	(page.find_child("Go", true, false) as Button).pressed.emit()
	_check("create.go.started: a chip and GO start foreman new (no toast) and the page says the Designer is thinking",
		said == str(Model.SURPRISES[0][1]) and str(page.get("message")).is_empty() and (door.get("started") as Array).size() == 1
		and page.call("shown_screen") == "designing",
		"sentence '%s', message '%s', started %d, screen %s" % [said, str(page.get("message")), (door.get("started") as Array).size(), str(page.call("shown_screen"))])
	var waited: int = 0
	while waited < WAIT_FRAMES and page.call("shown_screen") != "pitch" and str(page.get("message")).is_empty():
		await process_frame
		OS.delay_msec(10)
		waited += 1
	var job_dir: String = str(page.get("job_dir"))
	var job: Dictionary = page.get("job")
	var on: Callable = func(n: String) -> bool:
		var c: Node = page.find_child(n, true, false)
		return c != null and (c as CanvasItem).is_visible_in_tree()
	_check("create.go.pitch: the Designer's first answer is on screen (pitch, aspect cards, Build it), from the job GO started",
		page.call("shown_screen") == "pitch" and on.call("Pitch") and on.call("BuildIt") and job_dir.begins_with(jobs)
		and str(job.get("sentence", "")) == said and (job.get("aspects", []) as Array).size() >= 3,
		"after %d frames: screen %s, message '%s', job %s, %s" % [waited, str(page.call("shown_screen")), str(page.get("message")), job_dir, _door_log(door)])
	page.queue_free()
	_end()


## The last lines the Foreman wrote through the door (why GO did not get to the pitch).
func _door_log(door: RefCounted) -> String:
	var st: Array = door.get("started")
	if st.is_empty():
		return "nothing was started"
	var lf: String = str((st.back() as Dictionary)["log"])
	if not FileAccess.file_exists(lf):
		return "no door log at " + lf
	var lines: PackedStringArray = FileAccess.get_file_as_string(lf).strip_edges().split("\n")
	return "door log: " + " | ".join(lines.slice(maxi(0, lines.size() - 3)))


func _end() -> void:
	print("[create-go] %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 and passed > 0 else 1)


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("PASS %s" % name)
	else:
		failed += 1
		print("FAIL %s%s" % [name, ("  -> " + detail) if not detail.is_empty() else ""])
