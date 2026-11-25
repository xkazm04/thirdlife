extends SceneTree
## H1d of 25 Nov 2026 (lane G1's first design: "drop a slow field" became an ordered core patch, 9 packages and 480
## minutes, and only the small print of one card said so; the Director chose (b)): a design card that needs new engine
## code carries `needs: "core"` and `hours`; the pitch says so on the card ("+6 h engine code") and in words where the
## hint stands, and a tap on the card (its data-only alternative) takes it away. The selftest block 862
## (tools/selftest.d/862-create-corecost.sh) runs this headless; one "PASS <name>" / "FAIL <name>  -> <why>" line each,
## then "[corecost] <n> passed, <m> failed". With `-- --shot=<abs png>` (a window) it also saves the pitch.

const Model = preload("res://ui/create/create_model.gd")
const EventSchema = preload("res://kernel/world/site/event_schema.gd")
const CreateScene = preload("res://ui/create/create.tscn")
const FIXTURE: String = "res://ui/fixtures/create/c2-pitch"

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	var tmp: String = OS.get_user_data_dir().path_join("tl_corecost_case_%d" % OS.get_process_id())
	var job: String = tmp.path_join("h1d-corecost")
	DirAccess.make_dir_recursive_absolute(job)
	# the fixture's pitch, with its Snowball cannon card made to need engine code (6 hours more)
	var lines: PackedStringArray = FileAccess.get_file_as_string(ProjectSettings.globalize_path(FIXTURE).path_join("job.jsonl")).strip_edges().split("\n")
	var brief_event: Dictionary = {}
	for i: int in lines.size():
		var e: Dictionary = JSON.parse_string(lines[i])
		if str(e.get("type", "")) == "brief_set":
			for a: Dictionary in e["brief"]["aspects"]:
				if str(a["id"]) == "cannon":
					a["needs"] = "core"
					a["hours"] = 6
			lines[i] = JSON.stringify(e)
			brief_event = e
	var f: FileAccess = FileAccess.open(job.path_join("job.jsonl"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	var schema_ok: String = EventSchema.check(brief_event)
	var bad: Dictionary = brief_event.duplicate(true)
	(bad["brief"]["aspects"] as Array)[0]["needs"] = "magic"
	_check("create.corecost.schema: the site's strict reader takes needs \"core\" and hours on a card, and refuses another needs",
		schema_ok.is_empty() and not EventSchema.check(bad).is_empty(), "%s | %s" % [schema_ok, EventSchema.check(bad)])

	var page: Control = CreateScene.instantiate()
	page.call("setup", {"jobs": tmp, "dry": true, "now": 1795289400.0, "flags": {"new": ["--adapter", "fake"], "plan": [], "run": [], "resume": []}})
	await process_frame
	root.add_child(page)
	page.call("open")
	page.call("show_job", job)
	await process_frame
	var tag: Label = page.find_child("Core_cannon", true, false) as Label
	var words: Label = page.find_child("CoreCost", true, false) as Label
	var want: String = "Snowball cannon needs new engine code: about 6 hours more. Tap it for a way with data only"
	_check("create.corecost.pitch: the card says \"+6 h engine code\" and the line under the cards says what it costs, in words",
		page.call("shown_screen") == "pitch" and tag != null and tag.text == "+6 h engine code" and words != null and words.text == want and page.find_child("Hint", true, false) == null,
		"tag %s, words %s" % ["none" if tag == null else tag.text, "none" if words == null else words.text])
	var shot: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.trim_prefix("--shot=")
	if not shot.is_empty() and DisplayServer.get_name() != "headless":
		for i: int in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		_check("create.corecost.shot: the pitch saved to %s" % shot, img != null and img.save_png(shot) == OK)
	# a tap takes the card to its first alternative (the data-only way): no engine code is asked for any more
	(page.find_child("Card_cannon", true, false) as Button).pressed.emit()
	await process_frame
	_check("create.corecost.swap: a tap on the card (its alternative) takes the engine code away; the hint is back",
		page.find_child("Core_cannon", true, false) == null and page.find_child("CoreCost", true, false) == null and page.find_child("Hint", true, false) != null
		and Model.core_cost_words(page.get("job"), page.get("taps")) == "")
	page.queue_free()
	print("[corecost] %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 and passed > 0 else 1)


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("PASS %s" % name)
	else:
		failed += 1
		print("FAIL %s%s" % [name, ("  -> " + detail) if not detail.is_empty() else ""])
