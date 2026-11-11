extends Node
## N6: a scripted session with the designer panel, for the live-path proof (tools/ui.sh live). It acts only through
## input events pushed into the window (mouse motion, mouse buttons, keys with their characters), the same way a
## player's hands reach the panel, and it looks only at what the panel's own model shows. It calls no panel or door
## method to make something happen; the only direct calls are reads (to wait for a state) and the screenshots.
## Every step is written to <shots>/live_proof.txt with its time and with how it was done.

const JobModel = preload("res://ui/job_model.gd")

var host: Control
var panel: Control
var shots: String = ""
var proof: PackedStringArray = []
var t0: float = 0.0
var failed: bool = false


func start(the_host: Control, what: String, shots_dir: String) -> void:
	host = the_host
	panel = host.get("panel")
	shots = shots_dir
	t0 = Time.get_unix_time_from_system()
	DirAccess.make_dir_recursive_absolute(shots)
	if what == "live":
		await _live()
	elif what == "live2":
		await _live2()
	else:
		note("direct", "unknown drive '%s'" % what)
		failed = true
	_write_proof()
	# everything this session started must be gone before it leaves
	var door: RefCounted = host.get("door")
	for i: int in 100:
		if (door.call("pids_running") as PackedInt32Array).is_empty():
			break
		await get_tree().create_timer(0.2).timeout
	var left: PackedInt32Array = door.call("pids_running")
	print("[drive] processes still running at the end: %s" % str(left))
	print("[drive] %s" % ("FAILED" if failed else "ok"))
	get_tree().quit(1 if failed else 0)


func note(how: String, text: String) -> void:
	var line: String = "%6.1fs  %-8s %s" % [Time.get_unix_time_from_system() - t0, how, text]
	proof.append(line)
	print("[drive] " + line)
	_write_proof()


func _write_proof() -> void:
	var f: FileAccess = FileAccess.open(shots.path_join("live_proof.txt"), FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(proof) + "\n")
		f.close()


# ---------------------------------------------------------------- hands: input events only

func frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _mouse(pos: Vector2, pressed: Variant = null) -> void:
	if pressed == null:
		var m: InputEventMouseMotion = InputEventMouseMotion.new()
		m.position = pos
		m.global_position = pos
		Input.parse_input_event(m)
	else:
		var b: InputEventMouseButton = InputEventMouseButton.new()
		b.position = pos
		b.global_position = pos
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = bool(pressed)
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if bool(pressed) else 0
		Input.parse_input_event(b)


func click_at(pos: Vector2) -> void:
	_mouse(pos)
	await frames(2)
	_mouse(pos, true)
	await frames(2)
	_mouse(pos, false)
	await frames(3)


## Finds a control by its node name, waits until it is on screen, and clicks its middle. False when it never came.
func click(node_name: String, what: String, wait_s: float = 10.0) -> bool:
	var c: Control = await find(node_name, wait_s)
	if c == null:
		note("UI event", "CLICK FAILED: no %s (%s) on screen" % [node_name, what])
		failed = true
		return false
	var at: Vector2 = c.get_global_rect().get_center()
	await click_at(at)
	note("UI event", "mouse click at (%d, %d) on %s" % [int(at.x), int(at.y), what])
	return true


func click_control(c: Control, what: String) -> void:
	var at: Vector2 = c.get_global_rect().get_center()
	await click_at(at)
	note("UI event", "mouse click at (%d, %d) on %s" % [int(at.x), int(at.y), what])


func find(node_name: String, wait_s: float = 10.0) -> Control:
	var until: float = Time.get_unix_time_from_system() + wait_s
	while Time.get_unix_time_from_system() < until:
		var c: Control = panel.find_child(node_name, true, false) as Control
		if c != null and c.is_visible_in_tree() and c.size.x > 0.0:
			return c
		await frames(5)
	return null


func type(text: String, what: String) -> void:
	for i: int in text.length():
		var k: InputEventKey = InputEventKey.new()
		k.unicode = text.unicode_at(i)
		k.pressed = true
		Input.parse_input_event(k)
		var up: InputEventKey = InputEventKey.new()
		up.unicode = text.unicode_at(i)
		up.pressed = false
		Input.parse_input_event(up)
		if i % 6 == 5:
			await frames(1)
	await frames(3)
	note("UI event", "typed %d key events into %s: \"%s\"" % [text.length(), what, text])


func press_enter(what: String) -> void:
	for down: bool in [true, false]:
		var k: InputEventKey = InputEventKey.new()
		k.keycode = KEY_ENTER
		k.physical_keycode = KEY_ENTER
		k.pressed = down
		Input.parse_input_event(k)
		await frames(2)
	note("UI event", "Enter key in %s" % what)


func drag(from: Vector2, to: Vector2, what: String) -> void:
	_mouse(from)
	await frames(2)
	_mouse(from, true)
	await frames(2)
	for i: int in 9:
		var p: Vector2 = from.lerp(to, float(i + 1) / 9.0)
		var m: InputEventMouseMotion = InputEventMouseMotion.new()
		m.position = p
		m.global_position = p
		m.relative = (to - from) / 9.0
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
		await frames(1)
	_mouse(to, false)
	await frames(3)
	note("UI event", "mouse drag from (%d, %d) to (%d, %d) on %s" % [int(from.x), int(from.y), int(to.x), int(to.y), what])


# ---------------------------------------------------------------- eyes: reads only

func job() -> Dictionary:
	var id: String = str(panel.get("selected"))
	var jobs: Dictionary = panel.get("jobs")
	return jobs.get(id, {})


func wait_for(what: String, test: Callable, timeout_s: float) -> bool:
	var until: float = Time.get_unix_time_from_system() + timeout_s
	while Time.get_unix_time_from_system() < until:
		if test.call():
			note("read", "seen: %s" % what)
			return true
		await frames(6)
	note("read", "TIMEOUT after %ds waiting for: %s (phase now: %s)" % [int(timeout_s), what, str(job().get("phase", "no job selected"))])
	failed = true
	return false


func picture(name: String) -> void:
	await frames(4)
	var path: String = shots.path_join(name)
	var err: int = await host.call("shot", path)
	note("direct", "screenshot %s%s" % [name, "" if err == OK else " FAILED"])


# ---------------------------------------------------------------- the live session

func _live() -> void:
	var sentence: String = "Balls roll down a wooden ramp and the first across the line wins"
	var change_text: String = "More balls please: nine instead of five"
	await secs(1.0)
	note("direct", "session start; jobs root %s; %d jobs in the list" % [str(panel.get("jobs_root")), (panel.get("jobs") as Dictionary).size()])
	await picture("live-0-empty.png")

	# 1. describe
	if not await click("NewRow", "the row \"New game…\""):
		return
	if await find("NewField", 5.0) == null:
		note("read", "the field did not open")
		failed = true
		return
	await type(sentence, "the field \"Describe a game…\"")
	await picture("live-1-describe.png")
	await press_enter("the field (submits)")
	if not await wait_for("a job directory appeared and the panel selected it", func() -> bool: return not job().is_empty(), 30.0):
		return
	note("read", "job id: %s" % str(job()["id"]))
	if not await wait_for("the brief is there and waits for approval", func() -> bool: return job().get("phase", "") == "approve", 60.0):
		return
	await secs(2.2)
	await picture("live-2-waiting-for-approval.png")

	# 2. approve
	if not await click("ApproveButton", "the button \"Approve and build\""):
		return
	if not await wait_for("the brief is approved (brief_approved in the log)", func() -> bool: return not str(job().get("approved_by", "")).is_empty(), 30.0):
		return
	await secs(1.2)
	await picture("live-3-just-approved.png")
	if not await wait_for("the plan is set and the job runs", func() -> bool: return job().get("phase", "") == "running" and int(job().get("total", 0)) > 0, 90.0):
		return
	if not await wait_for("first package built, second at work (mid-build)", func() -> bool:
			return int(job().get("done", 0)) >= 1 and job().get("phase", "") == "running" and not (job().get("milestones", []) as Array).is_empty(), 240.0):
		return
	await secs(2.2)
	await picture("live-4-mid-build.png")
	if not await wait_for("the job is done and the pack is promoted", func() -> bool: return job().get("phase", "") == "done" and (job().get("promotions", []) as Array).size() == 1, 300.0):
		return
	await secs(2.2)
	await picture("live-5-done.png")

	# 2b. look around the finished job: a picture, the notes, a line of the brief
	var thumbs: Array = panel.find_children("Thumb_*", "Button", true, false)
	var box: Control = panel.find_child("Lightbox", true, false) as Control
	if thumbs.size() > 0 and box != null:
		await click_control(thumbs[0] as Control, "the first milestone picture")
		if await wait_for("the picture is enlarged", func() -> bool: return box.visible, 10.0):
			await secs(0.6)
			await picture("live-5b-picture-enlarged.png")
			await click_at(get_viewport().get_visible_rect().size * 0.5)
			note("UI event", "mouse click in the middle of the enlarged picture (closes it)")
			await wait_for("the picture is closed", func() -> bool: return not box.visible, 10.0)
	if await click("NotesFold", "the fold \"Builder notes\""):
		await wait_for("the notes are open", func() -> bool: return bool(panel.get("notes_open")), 10.0)
		await secs(0.6)
		await picture("live-5c-notes-open.png")
		await click("NotesFold", "the fold \"Builder notes\" (folds them away)")
		await wait_for("the notes are folded", func() -> bool: return not bool(panel.get("notes_open")), 10.0)

	# 3. a change request
	if not await click("Sec_change", "the section head \"Change\""):
		return
	if not await click("ChangeField", "the field \"What should be different?\""):
		return
	await type(change_text, "the change field")
	await picture("live-6-change-typed.png")
	if not await click("ChangeSend", "the button \"Send\""):
		return
	if not await wait_for("change_requested is in the log and the job runs again", func() -> bool:
			return (job().get("changes", []) as Array).size() == 1 and job().get("phase", "") == "running", 60.0):
		return
	if not await wait_for("the owner package is re-opened", func() -> bool: return str((job()["changes"] as Array)[0]["owner"]) != "", 60.0):
		return
	await secs(2.2)
	await picture("live-7-change-in-flight.png")
	if not await wait_for("second promotion: done again, pack 0.1.1", func() -> bool:
			return job().get("phase", "") == "done" and (job().get("promotions", []) as Array).size() == 2, 300.0):
		return
	var proms: Array = job()["promotions"]
	note("read", "promotions: %s -> %s; change outcome: %s" % [str(proms[0]["dest"]), str(proms[1]["dest"]), str((job()["changes"] as Array)[0]["outcome"])])
	await secs(2.2)
	await picture("live-8-second-promotion.png")

	# 4. tune by hand: drag the first slider of the promoted pack
	await click("Sec_change", "the section head \"Change\" (folds it)")
	if not await click("Sec_tune", "the section head \"Tune\""):
		return
	var slider: Control = await find("Tune_balls", 10.0)
	if slider == null:
		note("read", "no slider for the param 'balls' (the pack declares no params?)")
		failed = true
		return
	var pack_dir: String = str(job()["pack_dir"])
	var file: String = pack_dir.path_join("data/tuning.json")
	var before: Variant = JobModel.get_path_value(JobModel.read_json(file), "balls")
	var r: Rect2 = slider.get_global_rect()
	var from: Vector2 = Vector2(r.position.x + r.size.x * ((float(before) - 1.0) / 11.0), r.get_center().y)
	var to: Vector2 = Vector2(r.position.x + r.size.x * 0.25, r.get_center().y)
	await drag(from, to, "the slider \"Number of balls\"")
	var text: String = FileAccess.get_file_as_string(file)
	var parser: JSON = JSON.new()
	var valid: bool = parser.parse(text) == OK
	var after: Variant = JobModel.get_path_value(parser.data, "balls") if valid else null
	note("read", "tuning file %s: balls %s -> %s; valid JSON: %s" % [file.trim_prefix(str(panel.get("jobs_root")) + "/"), str(before), str(after), str(valid)])
	if not valid or after == null or float(after) == float(before):
		failed = true
		note("read", "THE SLIDER DID NOT CHANGE THE FILE")
	await secs(1.2)
	await picture("live-9-tuned.png")


# ---------------------------------------------------------------- the second session: question, dead Foreman, discard

func _live2() -> void:
	var sentence: String = "Balls on a ramp with a question from the builder"
	var answer: String = "No, leave core as it is and write the values anyway"
	await secs(1.0)
	note("direct", "session start; jobs root %s; %d jobs in the list" % [str(panel.get("jobs_root")), (panel.get("jobs") as Dictionary).size()])

	# 1. describe, approve, and wait for the builder's question
	if not await click("NewRow", "the row \"New game…\""):
		return
	if await find("NewField", 5.0) == null:
		failed = true
		return
	await type(sentence, "the field \"Describe a game…\"")
	await press_enter("the field (submits)")
	if not await wait_for("the new job is selected and waits for approval", func() -> bool: return job().get("sentence", "") == sentence and job().get("phase", "") == "approve", 60.0):
		return
	var qid: String = str(job()["id"])
	if not await click("ApproveButton", "the button \"Approve and build\""):
		return
	if not await wait_for("the job is paused on a builder's question", func() -> bool: return job().get("phase", "") == "paused" and job().get("pause_kind", "") == "question", 240.0):
		return
	await secs(2.2)
	await picture("live2-1-paused-on-question.png")

	# 2. answer it
	if not await click("AnswerField", "the field \"Your answer…\""):
		return
	await type(answer, "the answer field")
	# the choice "let it change core": open the list under the answer, click its second line
	var pick: OptionButton = await find("AnswerChange", 5.0) as OptionButton
	if pick != null:
		await click_control(pick, "the choice under the answer (opens its list)")
		await secs(0.4)
		var pop: PopupMenu = pick.get_popup()
		if pop.visible:
			var pr: Rect2 = Rect2(Vector2(pop.position), Vector2(pop.size))
			var at: Vector2 = Vector2(pr.position.x + pr.size.x * 0.5, pr.position.y + pr.size.y * (1.5 / float(maxi(1, pop.item_count))))
			await picture("live2-2a-choice-open.png")
			await click_at(at)
			note("UI event", "mouse click at (%d, %d) on the second line of the list" % [int(at.x), int(at.y)])
			await secs(0.3)
		note("read", "the choice now reads: \"%s\"" % pick.get_item_text(pick.selected))
		if pick.selected != 1:
			note("read", "THE CHOICE WAS NOT TAKEN by the click; the answer goes out as \"answer only\"")
	await picture("live2-2-answer-typed.png")
	if not await click("AnswerSend", "the button \"Answer\""):
		return
	if not await wait_for("the answer is in the log and the job runs again", func() -> bool:
			var qs: Array = job().get("questions", [])
			return qs.size() == 1 and not bool(qs[0]["open"]) and job().get("phase", "") == "running", 60.0):
		return

	# 3. the Foreman dies: this session kills the Foreman it started itself, while its builder is "thinking"
	if not await wait_for("the package feel is at work again", func() -> bool: return ((job().get("packages", {}) as Dictionary).get("feel", {}) as Dictionary).get("state", "") == "running", 180.0):
		return
	await secs(1.0)
	var lock: int = JobModel.read_lock(str(job()["dir"]))
	var door: RefCounted = host.get("door")
	var mine: bool = not str(door.call("busy", str(job()["dir"]))).is_empty()
	if lock <= 0 or not mine:
		note("direct", "no Foreman of this session to kill (lock %d, started here: %s)" % [lock, str(mine)])
		failed = true
		return
	OS.kill(lock)
	note("direct", "killed the Foreman this session started for %s (process %d, from its foreman.lock), to stage a dead Foreman" % [qid, lock])
	if not await wait_for("the panel shows the job as stalled", func() -> bool: return str(panel.call("shown_phase", qid)) == "stalled", 30.0):
		return
	await secs(2.2)
	await picture("live2-3-foreman-dead.png")

	# 4. resume
	if not await click("ResumeButton", "the button \"Resume\""):
		return
	if not await wait_for("a Foreman works on the job again", func() -> bool: return str(panel.call("shown_phase", qid)) == "running", 30.0):
		return
	if not await wait_for("the job is done and promoted", func() -> bool: return job().get("phase", "") == "done" and (job().get("promotions", []) as Array).size() >= 1, 300.0):
		return
	note("read", "change requests in the log: %s" % str((job().get("changes", []) as Array).map(func(c: Dictionary) -> String: return "%s -> %s (%s)" % [str(c["text"]), str(c["owner"]), str(c["outcome"])])))
	await secs(2.2)
	await picture("live2-4-resumed-and-done.png")

	# 5. a second game, discarded at the brief
	var sentence2: String = "A game I will not keep"
	if not await click("NewRow", "the row \"New game…\""):
		return
	if await find("NewField", 5.0) == null:
		failed = true
		return
	await type(sentence2, "the field \"Describe a game…\"")
	await press_enter("the field (submits)")
	if not await wait_for("the second job is selected and waits for approval", func() -> bool: return job().get("sentence", "") == sentence2 and job().get("phase", "") == "approve", 60.0):
		return
	await secs(1.2)
	if not await click("DiscardButton", "the button \"Discard\""):
		return
	if not await wait_for("the job is cancelled", func() -> bool: return job().get("phase", "") == "cancelled", 30.0):
		return
	await secs(2.2)
	await picture("live2-5-discarded.png")
