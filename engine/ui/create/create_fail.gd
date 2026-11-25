extends "res://ui/create/create_pause.gd"
## H1i of 25 Nov 2026 (lane G5: a bumper-kart job failed on a hand check after two hours of work; the failed card offered
## only "Try again", which starts a new game from the sentence and throws the work away). A failed job's card offers
## "Resume" (`foreman resume <job> --retry-failed` with the run settings: the work so far stays, the stopped part runs again
## with the current editor) beside "Try again" (start over from the sentence), and says why it stopped in a person's words,
## not the log's. (The card was create_build.gd's `_failed`; it moved here whole.)


func _failed() -> void:
	var card: Panel = Panel.new()
	card.name = "FailCard"
	card.add_theme_stylebox_override("panel", _box(PAPER, RED, 6, 26, 14))
	card.position = Vector2(190, 150)
	card.size = Vector2(900, 440)
	_body.add_child(card)
	var ic: Icon = Icon.new("cross", 96)
	ic.disc = RED
	ic.position = Vector2(402, 24)
	ic.size = Vector2(96, 96)
	card.add_child(ic)
	var designing: bool = (job.get("brief", {}) as Dictionary).is_empty()
	var t: Label = _label("The designer got stuck" if designing else "This build stopped", 46, 950, INK, 820, HORIZONTAL_ALIGNMENT_CENTER)
	t.name = "Stopped"
	t.position = Vector2(40, 132)
	card.add_child(t)
	var w: Label = _label(fail_words(job), 22, 600, Color(INK, 0.75), 820, HORIZONTAL_ALIGNMENT_CENTER)
	w.name = "Why"
	w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w.custom_minimum_size = Vector2(820, 0)
	w.position = Vector2(40, 196)
	card.add_child(w)
	# Resume only where there is work to keep: a plan (a design that never got one has nothing to pick up)
	var can_resume: bool = not designing and not (job.get("order", []) as Array).is_empty()
	if can_resume:
		var go: Button = _button("Resume", "Resume", "play", GREEN, Vector2(110, 300), Vector2(320, 76), 30)
		go.pressed.connect(resume_failed)
		card.add_child(go)
		var keep: Label = _label("keeps the work so far", 18, 600, Color(INK, 0.6), 320, HORIZONTAL_ALIGNMENT_CENTER)
		keep.name = "ResumeWords"
		keep.position = Vector2(110, 384)
		card.add_child(keep)
	var again: Button = _button("TryAgain", "Try again", "redo", HONEY, Vector2(470, 300) if can_resume else Vector2(300, 300), Vector2(320, 76), 30)
	again.pressed.connect(func() -> void:
		sentence = str(job.get("sentence", sentence))
		creativity = str(job.get("creativity", creativity))
		new_idea())
	card.add_child(again)
	var fresh: Label = _label("starts a new game from your sentence", 18, 600, Color(INK, 0.6), 320, HORIZONTAL_ALIGNMENT_CENTER)
	fresh.name = "TryAgainWords"
	fresh.position = again.position + Vector2(0, 84)
	card.add_child(fresh)


## The failed job goes on from where it stopped: its failed parts queued again, with the editor as it is now.
func resume_failed() -> void:
	if door == null:
		return
	var err: String = door.resume_failed(job_dir)
	if not err.is_empty() and not door.dry:
		message = err
	else:
		message = ""
		busy = "continue"
	_rebuild()


## Why a job stopped, in a person's words: the part that could not be made (by its title, no ids), or the last check
## that failed, in words; never the log's line with its ids and report paths.
static func fail_words(j: Dictionary) -> String:
	for id: Variant in j.get("order", []):
		var p: Dictionary = (j.get("packages", {}) as Dictionary).get(str(id), {})
		if str(p.get("state", "")) == "failed" and str(p.get("cause", "")) != "cancelled":
			var cause: String = {"verify_failed": "its checks kept failing", "round_limit": "it ran out of tries", "kit_regression": "it gave up kit parts it had used",
				"no_visible_change": "its changes did not show on screen", "builder_error": "its builder stopped", "timeout": "its builder ran out of time"}.get(str(p.get("cause", "")), "")
			return "The builders could not get “%s” to work%s." % [str(p.get("title", id)), (": " + cause) if not cause.is_empty() else ""]
	var why: String = str(j.get("job_reason", ""))
	if why.begins_with("hand check of"):
		return "Every part was built, but the last check plays your game with a bot hand, and %s. Nothing was released." % ("it could not tell who won" if why.contains("\"won\"") else "that check failed")
	if why.begins_with("final verification failed"):
		return "Every part was built, but the last check of the whole game failed. Nothing was released."
	if why.begins_with("promotion refused"):
		return "The game was ready but was not released: %s" % ("it shows errors when it is played in a window." if why.contains("error") else "it did not pass the release check.")
	if why.contains("is not available"):
		return "The builders could not be reached."
	if why.contains("no longer holds files"):
		return "Files of this game went missing from its folder."
	if why.contains("budget") or why.contains("rate"):
		return "The builders hit their limit for now."
	return "It stopped before it was done."
