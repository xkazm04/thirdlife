extends SceneTree
## H1c of 25 Nov 2026 (lane G1's Arsenal job: the shield changed no match, pro 8 of 20 with and without it, and nobody was
## told): at a phase pause of a game on a core, the measured card says which toy changes nothing, in the check's own
## words (coreroute.ts toyLines -> the report's run.toys). The selftest block 861 (tools/selftest.d/861-create-toys.sh) runs
## this headless; one "PASS <name>" / "FAIL <name>  -> <why>" line each, then "[toys] <n> passed, <m> failed".
## With `-- --shot=<abs png>` (a window, not headless) it also saves the pause screen.

const Model = preload("res://ui/create/create_model.gd")
const IterateChecks = preload("res://ui/create/create_iterate_checks.gd")
const CreateScene = preload("res://ui/create/create.tscn")

var passed: int = 0
var failed: int = 0

## The real check of G1's cartridge on the real lab (H1c, 25 Nov): its toy lines, word for word.
const TOYS: Array = ["The F ability: changes little (8 of 20 wins with, 8 without)",
	"The pickups: changes little (8 of 20 wins with, 8 without)"]


func _initialize() -> void:
	var tmp: String = OS.get_user_data_dir().path_join("tl_toys_case_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(tmp)
	var rep: String = "reports/core-phase-slide-s31.json"
	var note: String = "[foreman] measured at the phase pause slide: data/harbour.cartridge.json ok (pro_goals_a_match 6.8, pro_minutes 1.5); measured, warnings: toy: the F ability (shield, slow_puck): worth about nothing, pro 8 of 20 wins with it, 8 without (+0 points), paired goal difference +0.2, F pressed 1.6 times a match (thirdjam's regular playtester) [report: %s]" % rep
	var job: String = IterateChecks._copy_job("c6-phase-done", tmp.path_join("h1c-toys"), [{"type": "note", "package": "penguin_moves", "round": 1, "text": note}])
	DirAccess.make_dir_recursive_absolute(job.path_join("reports"))
	var rf: FileAccess = FileAccess.open(job.path_join(rep), FileAccess.WRITE)
	rf.store_string(JSON.stringify({"schema": "tl.foreman.measured/1", "phase": "slide", "file": "data/harbour.cartridge.json",
		"run": {"code": 0, "figures": {"pro_goals_a_match": 6.8, "pro_minutes": 1.5}, "summary": "measured, warnings: ...", "toys": TOYS},
		"house": {"code": 0, "figures": {"pro_goals_a_match": 4.2, "pro_minutes": 3.1}, "summary": "ok"}}))
	rf.close()
	var page: Control = CreateScene.instantiate()
	page.call("setup", {"jobs": tmp, "dry": true, "now": 1795289400.0, "flags": {"new": ["--adapter", "fake"], "plan": [], "run": [], "resume": []}})
	await process_frame
	root.add_child(page)
	page.call("open")
	page.call("show_job", job)
	await process_frame
	var v: Dictionary = Model.measured_view(page.get("job"))
	_check("create.toys.model: the measured view carries the check's toy lines", (v.get("toys", []) as Array) == TOYS, str(v.get("toys")))
	var t0: Label = page.find_child("Toy0", true, false) as Label
	var t1: Label = page.find_child("Toy1", true, false) as Label
	var card: Control = page.find_child("MeasuredCard", true, false) as Control
	var inside: bool = card != null and t1 != null and t1.position.y + t1.get_minimum_size().y <= card.size.y
	_check("create.toys.card: the pause's measured card says which toys are worth about nothing, inside the card, beside Try it",
		t0 != null and t0.is_visible_in_tree() and t0.text == TOYS[0] and t1 != null and t1.text == TOYS[1] and inside and page.find_child("TryIt", true, false) != null,
		"Toy0 %s, Toy1 %s, card %s" % ["none" if t0 == null else "\"%s\" at %s" % [t0.text, str(t0.position)], "none" if t1 == null else "\"%s\" at %s" % [t1.text, str(t1.position)], "none" if card == null else str(card.size)])
	var shot: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.trim_prefix("--shot=")
	if not shot.is_empty() and DisplayServer.get_name() != "headless":
		for i: int in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		_check("create.toys.shot: the pause saved to %s" % shot, img != null and img.save_png(shot) == OK)
	page.queue_free()
	print("[toys] %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 and passed > 0 else 1)


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("PASS %s" % name)
	else:
		failed += 1
		print("FAIL %s%s" % [name, ("  -> " + detail) if not detail.is_empty() else ""])
