extends SceneTree
## H1i of 25 Nov 2026 (lane G5: the bumper-kart job failed on its last hand check after two hours of work, and the card
## offered only "Try again", a new game from the sentence): a failed job's card offers Resume (the work so far stays, the
## stopped part runs again with the current editor) beside Try again, and says why it stopped in a person's words. The
## selftest block 864 runs this headless; one "PASS <name>" / "FAIL <name>  -> <why>" line each, then
## "[failed] <n> passed, <m> failed". With `-- --shot=<abs png>` (a window, not headless) it also saves the card.

const CreateScene = preload("res://ui/create/create.tscn")
const IterateChecks = preload("res://ui/create/create_iterate_checks.gd")
const Fail = preload("res://ui/create/create_fail.gd")

var passed: int = 0
var failed: int = 0

## G5's real reason (d25-kart job event 411), word for word.
const G5_REASON: String = "hand check of card.team_possession failed, nothing promoted: perfect: 20 run(s) have no boolean \"won\" in their bot result"


func _initialize() -> void:
	var tmp: String = OS.get_user_data_dir().path_join("tl_failed_case_%d" % OS.get_process_id())
	# c10-failed: a package failed after its rounds; and a copy whose every package was built and the last check failed (G5)
	var pkg_failed: String = IterateChecks._copy_job("c10-failed", tmp.path_join("h1i-pkg"), [])
	var g5: String = IterateChecks._copy_job("c9-done", tmp.path_join("h1i-g5"), [{"type": "job_state", "state": "failed", "reason": G5_REASON}])
	var fake: Array = ["--adapter", "fake"]
	var page: Control = CreateScene.instantiate()
	page.call("setup", {"jobs": tmp, "dry": true, "now": 1795289400.0, "flags": {"run": fake, "resume": fake, "change": fake}})
	await process_frame
	root.add_child(page)
	page.call("open")
	var has: Callable = func(name: String) -> bool:
		var n: Node = page.find_child(name, true, false)
		return n != null and (n as CanvasItem).is_visible_in_tree()
	var text: Callable = func(name: String) -> String:
		var n: Node = page.find_child(name, true, false)
		return (n as Label).text if n is Label else ((n as Button).text if n is Button else "")
	var door: RefCounted = page.get("door")

	page.call("show_job", g5)
	await process_frame
	var why: String = text.call("Why")
	_check("create.failed.card: a failed job's card offers Resume (“keeps the work so far”) beside Try again (“starts a new game from your sentence”)",
		str(page.call("shown_screen")) == "failed" and has.call("FailCard") and has.call("Resume") and has.call("TryAgain") and text.call("ResumeWords") == "keeps the work so far"
		and text.call("TryAgainWords") == "starts a new game from your sentence",
		"screen %s, Resume %s, TryAgain %s" % [str(page.call("shown_screen")), str(has.call("Resume")), str(has.call("TryAgain"))])
	_check("create.failed.words: why it stopped, in a person's words (G5's hand check: no ids, no “boolean”, no report paths)",
		why == "Every part was built, but the last check plays your game with a bot hand, and it could not tell who won. Nothing was released."
		and Fail.fail_words({"order": ["rivals_ai"], "packages": {"rivals_ai": {"state": "failed", "cause": "verify_failed", "title": "Rival penguins"}}}) == "The builders could not get “Rival penguins” to work: its checks kept failing.",
		"why '%s'" % why)
	var base: int = (door.get("dry_steps") as Array).size()
	(page.find_child("Resume", true, false) as BaseButton).pressed.emit()
	var sent: Array = (door.get("dry_steps") as Array).slice(base)
	_check("create.failed.resume: Resume runs foreman resume <job> with the run settings and --retry-failed (the work stays), not a new job",
		str(sent) == str([[["resume", g5] + fake + ["--retry-failed"]]]), str(sent))
	var shot: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.trim_prefix("--shot=")
	if not shot.is_empty() and DisplayServer.get_name() != "headless":
		page.call("show_job", g5)
		for i: int in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		_check("create.failed.shot: the card saved to %s" % shot, img != null and img.save_png(shot) == OK)
	# a package that failed: Resume too, and its words name the part
	page.call("show_job", pkg_failed)
	await process_frame
	_check("create.failed.package: a job whose part failed offers Resume as well, and names the part by its title",
		has.call("Resume") and str(text.call("Why")).begins_with("The builders could not get “") and not str(text.call("Why")).contains("rivals_ai"),
		"why '%s'" % str(text.call("Why")))
	page.queue_free()
	print("[failed] %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 and passed > 0 else 1)


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("PASS %s" % name)
	else:
		failed += 1
		print("FAIL %s%s" % [name, ("  -> " + detail) if not detail.is_empty() else ""])
