extends RefCounted
## E4b (night of 24-25 Nov 2026): stage.gd --mode=pauses. The two pauses E5 found a person stuck at, answered on the
## page with a real Foreman behind it (the phases fixture of foreman/dist/testing/grow-steps.js --pauses: fake adapter,
## fake runner; the rival's builder asks a question, the critic finds every look weak):
##   ... res://ui/create/stage.tscn -- --mode=pauses --job=<abs job dir> --flags=<abs json> --jobs=<abs dir>
##       [--repo=<repo>: the door as the exe meets it] [--shots=<abs dir>]
## Continue; at every quality card the next of: Fix it, It's fine go on, Change it ("the rallies are too slow: make the
## court smaller"), then It's fine; the question card: tap its second option, Answer; Pass at every phase; until done.
## One "[create] pauses PASS|FAIL <step>" line per step, then "[create] pauses all held" or "NOT all held"; exit 0 / 1.

const Model = preload("res://ui/create/create_model.gd")
const CHANGE_WORDS: String = "the rallies are too slow: make the court smaller"

var host: Node = null
var ok_all: bool = true
var said: Dictionary = {}
var sent_frames: int = 6
var sent_delay_ms: int = 0     # H1g: the proof (not the selftest) lets wall time pass per frame, as a machine under load does
var _sends: Dictionary = {}    # kind -> the door's started count before the last press (H2c's quality_sent, for both kinds)


func say(what: String, ok: bool) -> void:
	ok_all = ok_all and ok
	print("[create] pauses %s %s (frame %d)" % ["PASS" if ok else "FAIL", what, Engine.get_process_frames()])


func page() -> Control:
	return host.get("page")


func visible(name_: String) -> Node:
	var n: Node = page().find_child(name_, true, false)
	return n if n != null and (n as CanvasItem).is_visible_in_tree() else null


## What the page waits on now: question | quality | phase_done | done | failed | "" (building).
func waits() -> String:
	var p: Control = page()
	if visible("QuestionCard") != null:
		return "question"
	# H1g: while a revise round runs the card stays up with the critic's reasons and no buttons ("the builders are still
	# at work on this game"); only a card a person can answer is a quality pause
	# and (H1g, run 2 of 3) the card's buttons show while the Foreman that wrote the hold is still letting go of the job;
	# a press then is refused with "the builders are still at work on this game" (the page keeps the card: a person
	# presses again). The stage presses once the Foreman has let go, as Pass waits for `settling`.
	if visible("QualityCard") != null and (visible("FixIt") != null or visible("ItsFine") != null) and not _foreman_alive():
		return "quality"
	var s: String = str(p.call("shown_screen"))
	if s == "phase_done" and not bool(p.get("settling")) and str(p.get("busy")).is_empty():
		return "phase_done"
	if s in ["done", "failed", "error"]:
		return s
	return ""


## H1g (reconciled with H2c's door check, one rule for every send): after a send, what the page shows: "not started"
## (the door started no process for it, or the page says a message), "waiting" (still busy with it), "taken" (the log
## moved past the pause it answered: the Foreman took it), or "lost" (not busy, and the job still held on the SAME pause
## it answered, `mark`). A later pause of the same kind (the next revise round's hold, the next question) is "taken".
func _after(kind: String, mark: Variant) -> String:
	if _started(kind) <= int(_sends.get(kind, 0)) or str(page().get("message")) != "":
		return "not started"
	if str(page().get("busy")) == kind:
		return "waiting"
	return "lost" if str(_pause_mark(kind)) == str(mark) else "taken"


## Is a Foreman still holding the page's job (the door's process, or the lock's pid)?
func _foreman_alive() -> bool:
	var d: Variant = page().get("door")
	if d == null:
		return false
	return bool(d.call("foreman_alive", str(page().get("job_dir")), int((page().get("job") as Dictionary).get("lock_pid", 0))))


## H2c: the door processes started for answers ("answer") or quality verdicts ("quality", also Change it) so far.
func _started(kind: String) -> int:
	var d: Variant = page().get("door")
	if d == null:
		return 0
	return (d.get("started") as Array).filter(func(st: Dictionary) -> bool: return str(st.get("label", "")) == kind).size()


## Before a press: how many processes of this kind the door has started (a send must add one).
func _before_send(kind: String) -> void:
	_sends[kind] = _started(kind)


## A send held when the door started its process and the page waits for it or the Foreman has taken it.
func _held(kind: String, mark: Variant) -> bool:
	return _after(kind, mark) in ["waiting", "taken"]


## The pause the page shows now: the open question's seq, or the quality hold; "" when not held on one.
func _pause_mark(kind: String) -> Variant:
	var job: Dictionary = page().get("job")
	if str(job.get("phase", "")) != "paused":
		return ""
	if kind == "answer":
		return int(Model.open_question(job).get("seq", -1))
	return job.get("quality_hold", {}) if str(job.get("pause_kind", "")) == "quality" else ""


## The frames after a send before the page is read again (6 in the selftest; the proof adds wall time per frame).
func _sent_wait(h: Node) -> void:
	for i: int in sent_frames:
		await h.get_tree().process_frame
		if sent_delay_ms > 0:
			OS.delay_msec(sent_delay_ms)


func drive(h: Node) -> void:
	host = h
	sent_frames = int(str((h.get("args") as Dictionary).get("sent-frames", "6")))   # H1g: the proof runs it with a slow page
	sent_delay_ms = int(str((h.get("args") as Dictionary).get("sent-delay-ms", "0")))
	await h.call("_frames", 10)
	var dir: String = str((h.get("args") as Dictionary).get("job", ""))
	page().call("show_job", dir)
	await h.call("_frames", 4)
	h.call("_press", "Continue")
	var quality_moves: Array = ["retry", "accept", "change"]
	var steps: int = 0
	while steps < 30:
		steps += 1
		var at: String = ""
		for i: int in 30000:                     # counted frames, 10 ms each: about 5 minutes for the Foreman to answer
			at = waits()
			if not at.is_empty():
				break
			await h.get_tree().process_frame
			OS.delay_msec(10)
		match at:
			"question":
				var q: String = (visible("Question") as Label).text
				var opts: int = 0
				while visible("Option%d" % opts) != null:
					opts += 1
				if not said.has("question"):
					say("a builder's question shows its words and %d options (“%s”)" % [opts, q.substr(0, 60)], q.contains("Rival Rex") and opts == 2)
					await h.call("_shot", "pz-01-question")
				h.call("_press", "Option1")
				await h.call("_frames", 4)
				var box: LineEdit = visible("AnswerBox")
				if not said.has("question"):
					say("tapping an option puts it in the answer box", box != null and box.text.contains("wait at the centre"))
					await h.call("_shot", "pz-02-question-option")
				said["question"] = true
				var mark_a: Variant = _pause_mark("answer")
				_before_send("answer")
				h.call("_press", "SendAnswer")
				# H1g (H2 found it: failed 2 of 3 on 25 Nov): the page says "sent" on the press itself; a fast Foreman may
				# answer within the frames after it, and then the page rightly shows the next state. Read it at the press.
				var sent_a: bool = str(page().get("busy")) == "answer" and visible("Sent") != null
				await _sent_wait(h)
				say("Answer sends foreman answer + resume, and the page says it is sent (then waits, or the Foreman took it: %s)" % _after("answer", mark_a), sent_a and _held("answer", mark_a))
				await h.call("_shot", "pz-03-answer-sent")
			"quality":
				var reasons: String = (visible("Reason0") as Label).text if visible("Reason0") != null else ""
				var move: String = str(quality_moves.pop_front()) if not quality_moves.is_empty() else "accept"
				if not said.has("quality"):
					said["quality"] = true
					say("a quality hold shows the critic's reasons in words (“%s”) and Fix it / It's fine / Change it" % reasons.substr(0, 50),
						reasons.contains("grey slab") and visible("FixIt") != null and visible("ItsFine") != null and visible("ChangeIt") != null)
					await h.call("_shot", "pz-04-quality-hold")
					var clock: Node = page().find_child("Clock", true, false)
					var ct: String = (clock as Label).text if clock is Label else ""
					say("the build clock counts this run (%s), not the job's first event (the fixture's is days old)" % ct, ct.count(":") == 1)   # E4c
				var mark_q: Variant = _pause_mark("quality")
				_before_send("quality")
				match move:
					"retry":
						h.call("_press", "FixIt")
					"accept":
						h.call("_press", "ItsFine")
					"change":
						h.call("_press", "ChangeIt")
						await h.call("_frames", 4)
						var cb: LineEdit = visible("QualityChange")
						cb.text = CHANGE_WORDS
						cb.text_changed.emit(cb.text)
						await h.call("_shot", "pz-05-quality-change")
						h.call("_press", "SendQualityChange")
				var sent_q: bool = str(page().get("busy")) == "quality"     # H1g: read at the press, not 6 frames later
				await _sent_wait(h)
				say("quality %s is sent (the page waits for the Foreman, or the Foreman took it: %s)" % [move, _after("quality", mark_q)], sent_q and _held("quality", mark_q))
			"phase_done":
				h.call("_press", "Pass")
				await h.call("_frames", 10)
			"done":
				var job: Dictionary = page().get("job")
				var words: Array = (job.get("changes", []) as Array).map(func(c: Dictionary) -> String: return str(c.get("text", "")))
				say("the job is done and promoted; the person's Change it became a change request", not (job.get("promotions", []) as Array).is_empty() and words.has(CHANGE_WORDS))
				await h.call("_shot", "pz-06-done")
				break
			_:
				say("the page reached an answerable state (got '%s', message '%s')" % [at, str(page().get("message"))], false)
				break
	for want: String in ["question", "quality"]:
		if not said.has(want):
			say("the %s pause was met" % want, false)
	print("[create] pauses %s" % ("all held" if ok_all else "NOT all held"))
	h.get_tree().quit(0 if ok_all else 1)


## E4c: stage.gd --mode=e4c --shots=<abs dir>: stills of the E4c screens from create_iterate_checks.gd e4c_jobs (a dry
## door, the jobs' own fixed clock): the phase pause with its measured figures, the scope question with "Yes, let it",
## E3d's asked-back change, the build clock of a run that started 5 minutes ago.
func stills(h: Node) -> void:
	host = h
	var tmp: String = OS.get_user_data_dir().path_join("tl_e4c_stills_%d" % OS.get_process_id())
	var j: Dictionary = (load("res://ui/create/create_iterate_checks.gd") as GDScript).call("e4c_jobs", tmp)
	(h.get("page") as Node).free()
	var p: Control = (load("res://ui/create/create.tscn") as PackedScene).instantiate()
	var fake: Array = ["--adapter", "fake"]
	p.call("setup", {"jobs": tmp, "dry": true, "now": float(j["now"]), "flags": {"run": fake, "resume": fake, "change": fake}})
	h.set("page", p)
	h.add_child(p)
	p.call("open")
	await h.call("_frames", 4)
	for shot: Array in [["measured", "e4c-1-phase-measured"], ["scope", "e4c-2-scope-question"], ["orange", "e4c-4-orange-question"], ["clock", "e4c-5-run-clock"]]:
		p.call("show_job", str(j[shot[0]]))
		await h.call("_shot", shot[1])
		if shot[0] == "scope":
			h.call("_press", "LetIt")
			await h.call("_shot", "e4c-3-scope-let-it")
	print("[create] e4c stills done")
	h.get_tree().quit(0)
