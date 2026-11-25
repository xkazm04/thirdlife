extends SceneTree
## H1h of 25 Nov 2026 (the Director's answer to H1g; create.pause.path run 2 of 3: the quality card's buttons showed while
## the Foreman that wrote the hold was still letting go of the job, and a press was refused with "the builders are still
## at work on this game"): the quality card waits as Pass does (`settling`). The selftest block 864 runs this headless; one
## "PASS <name>" / "FAIL <name>  -> <why>" line each, then "[settle] <n> passed, <m> failed".

const CreateScene = preload("res://ui/create/create.tscn")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	var tmp: String = OS.get_user_data_dir().path_join("tl_settle_case_%d" % OS.get_process_id())
	var held: String = tmp.path_join("h1h-quality")
	DirAccess.make_dir_recursive_absolute(held)
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://ui/fixtures/create/c13-quality-hold/job.jsonl"), held.path_join("job.jsonl"))
	# a Foreman still holds the job: its lock names a live process (this one)
	var lock: FileAccess = FileAccess.open(held.path_join("foreman.lock"), FileAccess.WRITE)
	lock.store_string(str(OS.get_process_id()))
	lock.close()
	var page: Control = CreateScene.instantiate()
	page.call("setup", {"jobs": tmp, "dry": true, "now": 1795289400.0, "flags": {"run": [], "resume": [], "change": []}})
	await process_frame
	root.add_child(page)
	page.call("open")
	page.call("show_job", held)
	await process_frame
	var has: Callable = func(name: String) -> bool:
		var n: Node = page.find_child(name, true, false)
		return n != null and (n as CanvasItem).is_visible_in_tree()
	_check("create.settle.wait: while the Foreman that wrote a quality hold still holds the job, the card shows no Fix it / It's fine / Change it (the page says the builders are at work, as for Pass)",
		bool(page.get("settling")) and not has.call("FixIt") and not has.call("ItsFine") and not has.call("ChangeIt") and str(page.call("shown_screen")) == "building",
		"settling %s, FixIt %s, ItsFine %s, screen %s" % [str(page.get("settling")), str(has.call("FixIt")), str(has.call("ItsFine")), str(page.call("shown_screen"))])
	# the Foreman lets go: the card is a person's to answer
	DirAccess.remove_absolute(held.path_join("foreman.lock"))
	page.call("show_job", held)
	await process_frame
	_check("create.settle.card: once it has let go, the card shows its three answers",
		not bool(page.get("settling")) and has.call("QualityCard") and has.call("FixIt") and has.call("ItsFine") and has.call("ChangeIt"),
		"settling %s, card %s, FixIt %s" % [str(page.get("settling")), str(has.call("QualityCard")), str(has.call("FixIt"))])
	page.queue_free()
	print("[settle] %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 and passed > 0 else 1)


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("PASS %s" % name)
	else:
		failed += 1
		print("FAIL %s%s" % [name, ("  -> " + detail) if not detail.is_empty() else ""])
