extends RefCounted
## D27 (lane T-editor): the Foreman notes Create tells a person after a change, in plain words, moved out of
## create_model.gd (its size budget): the balance a change moved, a change the Foreman undid because it rewrote a measure,
## and why a change could not be finished. Pure: a job picture (ui/job_model.gd read_job) in, words out.
const JobModel = preload("res://ui/job_model.gd")


## D27 item 9 (S35's biplane copy, events 750-787: the person asked to put the test pilot back, the Foreman's freeze undid
## it, v0.1.5 was v0.1.4 byte for byte, and Create said nothing): a change the Foreman undid because it rewrote a measure,
## in plain words, and "nothing in the game changed" when the what-changed note says so. Whether a person may unfreeze a
## measure is the owner's question; this only makes the refusal visible.
const MEASURE_KEPT := "[foreman] measure kept: "
const NOTHING_CHANGED := "nothing changed in the game"
static func measure_note(job: Dictionary, seq: int) -> String:
	var files: PackedStringArray = []
	var nothing: bool = false
	for n: Variant in job.get("notes", []):
		if not (n is Dictionary) or int((n as Dictionary).get("seq", 0)) <= seq:
			continue
		var t: String = str((n as Dictionary).get("text", ""))
		if t.begins_with(MEASURE_KEPT):
			for f: String in t.substr(MEASURE_KEPT.length()).get_slice(" is a measure", 0).get_slice(" are measures", 0).split(", "):
				if not files.has(f):
					files.append(f)
		elif t.begins_with("[foreman] what changed in") and t.contains(NOTHING_CHANGED):
			nothing = true
	if files.is_empty():
		return ""
	var them: String = "them" if files.size() > 1 else "it"
	var line: String = "Not applied: a change to %s was undone. The Foreman judges the game by %s, so a change may not rewrite %s." % [", ".join(files), them, them]
	return line + (" Nothing in the game changed in this version." if nothing else "")


## N27 T2: why a change could not be finished (p10gate.ts CHANGE_NOT_FINISHED), from the newest such note after `seq`.
const NOT_FINISHED := "[foreman] change not finished: "
static func not_finished(job: Dictionary, seq: int) -> String:
	var said: String = ""
	for n: Variant in job.get("notes", []):
		if n is Dictionary and int((n as Dictionary).get("seq", 0)) > seq and str((n as Dictionary).get("text", "")).begins_with(NOT_FINISHED):
			said = str((n as Dictionary)["text"]).substr(NOT_FINISHED.length())
	return JobModel.one_line(said.substr(0, 1).to_upper() + said.substr(1), 220) if not said.is_empty() else ""


## N27 (lane T): the balance a person's change moved, in the Foreman's plain words (boundlift.ts BALANCE_MOVED: its first
## line), from the notes after the change request `seq`; "" when the change moved no bound. The change was built as
## asked; this says what it did to the balance and how to tune it ("make it fairer"). D27 item 6: one line for each
## thing it moved (who wins the test rounds, a hand check's wins, how long matches run: the words before " now "), the
## newest line of each, in the order they were first told (boundlift.ts balanceLines); before, only the newest of all.
const BALANCE_MOVED := "[foreman] balance moved by your change: "
static func balance_note(job: Dictionary, seq: int) -> String:
	var order: Array = []
	var newest: Dictionary = {}
	for n: Variant in job.get("notes", []):
		if n is Dictionary and int((n as Dictionary).get("seq", 0)) > seq and str((n as Dictionary).get("text", "")).begins_with(BALANCE_MOVED):
			var said: String = str((n as Dictionary)["text"]).substr(BALANCE_MOVED.length()).get_slice("\n", 0)
			var key: String = said.get_slice(" now ", 0)
			if not newest.has(key):
				order.append(key)
			newest[key] = said
	var lines: PackedStringArray = []
	for key: Variant in order:
		var l: String = str(newest[key])
		lines.append(l.substr(0, 1).to_upper() + l.substr(1))
	return "\n".join(lines)

## D27 round 4, item 18 (JB-back's Arsenal: "the net bulges ... the glass shakes" was not made, and only a log note said so):
## each part of the change a builder could not make and nobody took on, as "Not made: ..." (the Foreman's NOT_MADE notes
## that end there; a part handed on to another package is not one).
const NOT_MADE := "[foreman] part of your change was NOT made: "
static func not_made_note(job: Dictionary, seq: int) -> String:
	var lines: PackedStringArray = []
	for n: Variant in job.get("notes", []):
		if n is Dictionary and int((n as Dictionary).get("seq", 0)) > seq and str((n as Dictionary).get("text", "")).begins_with(NOT_MADE):
			var said: String = str((n as Dictionary)["text"]).substr(NOT_MADE.length())
			lines.append("Not made: " + JobModel.one_line(said, 200))
	return "\n".join(lines)
