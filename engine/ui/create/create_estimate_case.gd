extends SceneTree
## H1b of 25 Nov 2026 (G2's finding: brief_set carries an estimate, e.g. 9 packages, 480 min, 6.5 M tokens, and no Create
## file read it): the pitch says what building the game takes, in a person's words, above Build it. The selftest block
## 860 (tools/selftest.d/860-create-estimate.sh) runs this headless; one "PASS <name>" / "FAIL <name>  -> <why>" line each,
## then "[estimate] <n> passed, <m> failed".
## With `-- --shot=<abs png>` (a window, not headless) it also saves the pitch screen of the fixture c2-pitch.

const Model = preload("res://ui/create/create_model.gd")
const CreateScene = preload("res://ui/create/create.tscn")
const FIXTURE: String = "res://ui/fixtures/create/c2-pitch"

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	# The words, from the game lanes' real estimates (G2 robot soccer, G4 half court) and the fixture's.
	var words: Dictionary = {
		"About 8 hours and 6.5 M tokens to build (9 parts)": {"packages": 9, "wallMinutes": 480, "tokens": 6500000},
		"About 8 hours and 8 M tokens to build (10 parts)": {"packages": 10, "wallMinutes": 480, "tokens": 8000000},
		"About 1 hour and 1.8 M tokens to build (5 parts)": {"packages": 5, "wallMinutes": 70, "tokens": 1800000},
		"About 1.5 hours and 900 k tokens to build (4 parts)": {"packages": 4, "wallMinutes": 95, "tokens": 900000},
		"About 25 minutes and 300 k tokens to build (2 parts)": {"packages": 2, "wallMinutes": 23, "tokens": 300000},
		"": {},
	}
	var wrong: PackedStringArray = []
	for want: String in words:
		var got: String = Model.estimate_words(words[want])
		if got != want:
			wrong.append("%s -> \"%s\" (want \"%s\")" % [JSON.stringify(words[want]), got, want])
	_check("create.estimate.words: brief_set's estimate in a person's words (hours to the half, tokens in M or k, parts)", wrong.is_empty(), "; ".join(wrong))

	var tmp: String = OS.get_user_data_dir().path_join("tl_estimate_case_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(tmp)
	var page: Control = CreateScene.instantiate()
	page.call("setup", {"jobs": tmp, "dry": true, "now": 1795289400.0, "flags": {"new": ["--adapter", "fake"], "plan": [], "run": [], "resume": []}})
	await process_frame
	root.add_child(page)
	page.call("open")
	page.call("show_job", ProjectSettings.globalize_path(FIXTURE))
	await process_frame
	var est: Label = page.find_child("Estimate", true, false) as Label
	var build: Control = page.find_child("BuildIt", true, false) as Control
	var ok: bool = page.call("shown_screen") == "pitch" and est != null and est.is_visible_in_tree() and est.text == "About 1 hour and 1.8 M tokens to build (5 parts)"
	# above Build it's row, left of the buttons, inside the page
	ok = ok and build != null and est.position.y + est.get_minimum_size().y <= build.position.y + build.size.y and est.position.x + est.size.x <= build.position.x - 200.0
	_check("create.estimate.pitch: the pitch of c2-pitch shows \"About 1 hour and 1.8 M tokens to build (5 parts)\" beside Build it",
		ok, "screen %s, label %s" % [str(page.call("shown_screen")), "none" if est == null else "\"%s\" at %s size %s" % [est.text, str(est.position), str(est.size)]])
	# a job whose brief has no estimate (an empty one) shows no line, never "About 0 minutes"
	_check("create.estimate.none: no estimate, no line", Model.estimate_words({}) == "" and Model.estimate_words({"packages": 3}) == "")

	var shot: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.trim_prefix("--shot=")
	if not shot.is_empty() and DisplayServer.get_name() != "headless":
		for i: int in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		_check("create.estimate.shot: the pitch screen saved to %s" % shot, img != null and img.save_png(shot) == OK)
	page.queue_free()
	DirAccess.remove_absolute(tmp)
	print("[estimate] %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 and passed > 0 else 1)


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("PASS %s" % name)
	else:
		failed += 1
		print("FAIL %s%s" % [name, ("  -> " + detail) if not detail.is_empty() else ""])
