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
	if visible("QualityCard") != null:
		return "quality"
	var s: String = str(p.call("shown_screen"))
	if s == "phase_done" and not bool(p.get("settling")) and str(p.get("busy")).is_empty():
		return "phase_done"
	if s in ["done", "failed", "error"]:
		return s
	return ""


func drive(h: Node) -> void:
	host = h
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
				h.call("_press", "SendAnswer")
				await h.call("_frames", 6)
				say("Answer sends foreman answer + resume, and the page says it is sent", str(page().get("busy")) == "answer" and visible("Sent") != null)
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
				await h.call("_frames", 6)
				say("quality %s is sent (the page waits for the Foreman)" % move, str(page().get("busy")) == "quality")
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
