extends RefCounted
## L3 (night of 21 Nov 2026): what the Create page shows, from one job's picture (ui/job_model.gd `read_job`) and the
## player's taps that are not in the log yet. Pure: no node, no file write, no process. The page (create.gd) draws it;
## the selftest (create_case.gd) checks it against the fixture logs (ui/fixtures/create/).
##
## Screens, in the order a player meets them (BRIEF "The page"):
##   idea        no job: the sentence box, Standard / Crazy, surprise chips, Go
##   designing   the job has no brief yet: the sentence and "the designer is thinking", elapsed time
##   pitch       a brief, not approved: the pitch line and one card per aspect; Redesign or Build it
##   building    approved, not waiting on a phase: the phase strip and the packages of the current phase
##   phase_done  the job waits on a phase (`job_state paused`, reason `phase`): Try it, Pass, Hold + note
##   done        the job is done with a promotion: "Your game is ready", Play
##   failed      the job failed or was cancelled
##   error       the job's log cannot be read

const JobModel = preload("res://ui/job_model.gd")

const SCREENS: PackedStringArray = ["idea", "designing", "pitch", "building", "phase_done", "done", "failed", "error"]

## The surprise-me chips for a player with no idea yet: a short label (at most 3 words) and the sentence it puts in
## the box. The dice walks this list in order (no clock, no random: the same taps give the same idea).
const SURPRISES: Array = [
	["Penguin push", "penguins pushing each other off an iceberg"],
	["Robot soccer", "tiny robots playing soccer on a moon"],
	["Lava race", "racing across a floor that turns to lava"],
	["Dino bowling", "a dinosaur bowling with boulders at cave towers"],
	["Snow fort war", "a snowball fight between two snow forts"],
	["Pirate duel", "two pirate ships firing cannons in a storm"],
	["Space taxi", "a taxi in space picking up aliens before time runs out"],
	["Ghost hide", "hide and seek in a haunted house with a ghost"],
]

## Creativity: what each side of the switch does, in one line (the Crazy line is the BRIEF's "one line on what it does").
const CREATIVITY_LINE: Dictionary = {
	"standard": "Your idea, made as fun as it can be.",
	"crazy": "Your idea plus one or two wild surprises.",
}


static func screen_of(job: Dictionary) -> String:
	if job.is_empty():
		return "idea"
	var ph: String = str(job.get("phase", ""))
	if ph == "unreadable":
		return "error"
	if ph in ["failed", "cancelled"]:
		# E4: a change that could not be made does not take the game away: the last promotion still plays
		return "done" if not (job.get("promotions", []) as Array).is_empty() and not person_changes(job).is_empty() else "failed"
	if (job.get("brief", {}) as Dictionary).is_empty():
		return "designing"
	if str(job.get("approved_by", "")).is_empty():
		return "pitch"
	if str(job.get("pause_kind", "")) == "phase":
		return "phase_done"
	if ph == "done":
		return "done" if not (job.get("promotions", []) as Array).is_empty() else "failed"
	return "building"


# ---------------------------------------------------------------- aspects

## The choices one tap walks through: keep, each alternative in order, drop; then keep again.
static func choices(aspect: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = ["keep"]
	for alt: Variant in aspect.get("alternatives", []):
		if alt is Dictionary:
			out.append(str((alt as Dictionary).get("id", "")))
	out.append("drop")
	return out


static func next_choice(aspect: Dictionary, current: String) -> String:
	var c: PackedStringArray = choices(aspect)
	var i: int = c.find(current)
	return c[(i + 1) % c.size()] if i >= 0 else "keep"


## What a card shows for a choice: {title, line, kind: keep | swap | drop}.
static func face(aspect: Dictionary, choice: String) -> Dictionary:
	if choice == "drop":
		return {"title": str(aspect.get("title", "")), "line": str(aspect.get("line", "")), "kind": "drop"}
	for alt: Variant in aspect.get("alternatives", []):
		if alt is Dictionary and str((alt as Dictionary).get("id", "")) == choice:
			return {"title": str(alt.get("title", "")), "line": str(alt.get("line", "")), "kind": "swap"}
	return {"title": str(aspect.get("title", "")), "line": str(aspect.get("line", "")), "kind": "keep"}


## The choice that stands for an aspect: the player's tap since the last read, else the log's latest reaction, else keep.
static func choice_of(job: Dictionary, taps: Dictionary, aspect_id: String) -> String:
	if taps.has(aspect_id):
		return str((taps[aspect_id] as Dictionary).get("choice", "keep"))
	var r: Variant = (job.get("reactions", {}) as Dictionary).get(aspect_id, null)
	return str((r as Dictionary).get("choice", "keep")) if r is Dictionary else "keep"


static func note_of(job: Dictionary, taps: Dictionary, aspect_id: String) -> String:
	if taps.has(aspect_id) and (taps[aspect_id] as Dictionary).has("note"):
		return str(taps[aspect_id]["note"])
	var r: Variant = (job.get("reactions", {}) as Dictionary).get(aspect_id, null)
	return str((r as Dictionary).get("note", "")) if r is Dictionary else ""


## The reactions to write before Redesign or Build it: [[aspect, choice, note], ...] in the brief's order, only where
## the player's choice or note differs from what the log already holds (a never-touched aspect is a keep: not sent).
static func pending(job: Dictionary, taps: Dictionary) -> Array:
	var out: Array = []
	for a: Variant in job.get("aspects", []):
		if not a is Dictionary:
			continue
		var id: String = str((a as Dictionary).get("id", ""))
		if not taps.has(id):
			continue
		var choice: String = choice_of(job, taps, id)
		var note: String = JobModel.one_line(note_of(job, taps, id))
		if not choices(a).has(choice):
			continue
		var r: Variant = (job.get("reactions", {}) as Dictionary).get(id, null)
		var logged_choice: String = str((r as Dictionary).get("choice", "keep")) if r is Dictionary else "keep"
		var logged_note: String = str((r as Dictionary).get("note", "")) if r is Dictionary else ""
		if choice != logged_choice or note != logged_note:
			out.append([id, choice, note])
	return out


## Cards for a brief without aspects (a job made before the designer v2): the five parts the Planner reads, read
## only (no alternatives, so no reaction can be written: `aspect_reacted` names an aspect of the brief).
const V1_PARTS: Array = [["rules", "goal", "The rules"], ["arena", "arena", "The place"], ["ai", "rival", "The others"],
	["controls", "player", "You"], ["mood", "music", "The mood"]]

static func cards_of(job: Dictionary) -> Array:
	var aspects: Array = job.get("aspects", [])
	if not aspects.is_empty():
		return aspects
	var out: Array = []
	var brief: Dictionary = job.get("brief", {})
	for p: Array in V1_PARTS:
		if brief.has(p[0]):
			out.append({"id": p[0], "icon": p[1], "title": p[2], "line": JobModel.one_line(str(brief[p[0]]), 80), "detail": str(brief[p[0]]),
				"alternatives": [], "read_only": true})
	return out


# ---------------------------------------------------------------- phases

## The strip: one entry per phase: {n, id, title, try, state, done, total, current, note}. A plan without phases is
## one phase titled by the job. Empty before the plan.
static func strip(job: Dictionary) -> Array:
	var out: Array = []
	var phases: Array = job.get("phases", [])
	var now: int = int(job.get("phase_now", -1))
	for k: int in phases.size():
		var ph: Dictionary = phases[k]
		var title: String = str(ph.get("title", ""))
		if title.is_empty():
			title = "The whole game"
		out.append({"n": k + 1, "id": str(ph.get("id", "")), "title": title, "try": str(ph.get("try", "")), "state": str(ph.get("state", "next")),
			"done": int(ph.get("done_count", 0)), "total": (ph.get("packages", []) as Array).size(), "current": k == now, "note": str(ph.get("note", ""))})
	return out


## The packages of the current phase (or of the waiting one): [{id, title, state, round}] in the plan's order.
static func phase_packages(job: Dictionary) -> Array:
	var phases: Array = job.get("phases", [])
	var k: int = int(job.get("phase_now", -1))
	if k < 0 or k >= phases.size():
		return []
	var out: Array = []
	var pk: Dictionary = job.get("packages", {})
	for id: Variant in (phases[k] as Dictionary).get("packages", []):
		if pk.has(str(id)):
			var p: Dictionary = pk[str(id)]
			out.append({"id": str(id), "title": str(p.get("title", id)), "state": str(p.get("state", "queued")), "round": int(p.get("round", 1))})
	return out


## The phase the job waits on: the strip entry, or {}.
static func waiting(job: Dictionary) -> Dictionary:
	var want: String = str(job.get("phase_wait", ""))
	for e: Dictionary in strip(job):
		if e["id"] == want and str(job.get("pause_kind", "")) == "phase":
			return e
	return {}


## "phase n of m: <title>" for the current phase, "" when there is no plan or the plan has no phases.
static func phase_line(job: Dictionary) -> String:
	if not bool(job.get("phases_given", false)):
		return ""
	var s: Array = strip(job)
	var k: int = int(job.get("phase_now", -1))
	if k < 0 or k >= s.size():
		return ""
	return "phase %d of %d: %s" % [k + 1, s.size(), str(s[k]["title"])]


# ---------------------------------------------------------------- where to try and play

## The pack a phase is tried from (the job's WIP pack) and the pack the finished game plays from (the last promotion).
static func try_dir(job: Dictionary) -> String:
	return str(job.get("dir", "")).path_join("pack")


static func play_dir(job: Dictionary) -> String:
	var d: String = str(job.get("pack_dir", ""))
	return d if not d.is_empty() else try_dir(job)


# ---------------------------------------------------------------- words

## The words of a text as the contract counts them (pieces between white space).
static func words(text: String) -> int:
	return text.replace("\n", " ").replace("\t", " ").split(" ", false).size()


## The words a person can read on a screen: every visible Label, Button, LineEdit (its text, else its placeholder) and
## RichTextLabel under `root`. Returns {total, items: [[words, text]]}.
static func screen_words(root: Node) -> Dictionary:
	var items: Array = []
	var total: int = 0
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
			continue
		for c: Node in n.get_children():
			stack.append(c)
		var t: String = ""
		if n is Label:
			t = (n as Label).text
		elif n is Button:
			t = (n as Button).text
		elif n is LineEdit:
			t = (n as LineEdit).text if not (n as LineEdit).text.is_empty() else (n as LineEdit).placeholder_text
		elif n is TextEdit:
			t = (n as TextEdit).text if not (n as TextEdit).text.is_empty() else (n as TextEdit).placeholder_text
		elif n is RichTextLabel:
			t = (n as RichTextLabel).get_parsed_text()
		var w: int = words(t)
		if w > 0:
			total += w
			items.append([w, t])
	return {"total": total, "items": items}


# ---------------------------------------------------------------- E4 (24-25 Nov): iterations, my games

## The change requests the person made (the Foreman's own `[foreman] ` requests, such as a wire-in, left out), oldest first:
## job_model.gd's change rows {seq, text, outcome: in flight | made | not made | failed | cancelled, version}.
static func person_changes(job: Dictionary) -> Array:
	return (job.get("changes", []) as Array).filter(func(c: Dictionary) -> bool: return not str(c.get("text", "")).begins_with("[foreman] "))


## The person's change being made now (its text), or "": the last one, while the job is not done with it.
static func changing(job: Dictionary) -> String:
	var mine: Array = person_changes(job)
	if mine.is_empty() or str(job.get("phase", "")) in ["done", "failed", "cancelled"]:
		return ""
	var c: Dictionary = mine.back()
	return str(c["text"]) if str(c.get("outcome", "")) == "in flight" else ""


## How many versions of the game there are (each promotion is one: the first build, then one per change made).
static func version_n(job: Dictionary) -> int:
	return (job.get("promotions", []) as Array).size()


## One line when the person's last change could not be made ("" otherwise): the game plays as before.
static func change_note(job: Dictionary) -> String:
	var mine: Array = person_changes(job)
	if mine.is_empty():
		return ""
	var c: Dictionary = mine.back()
	if str(c.get("outcome", "")) in ["not made", "failed", "cancelled"]:
		return "Your last change could not be made: \u201c%s\u201d" % JobModel.one_line(str(c["text"]), 60)
	return ""


## The packages a change round is working on when every phase has passed (no current phase): those not promoted.
static func working_packages(job: Dictionary) -> Array:
	var out: Array = []
	var pk: Dictionary = job.get("packages", {})
	for id: Variant in job.get("order", []):
		var p: Dictionary = pk.get(str(id), {})
		if not p.is_empty() and str(p.get("state", "")) != "promoted":
			out.append({"id": str(id), "title": str(p.get("title", id)), "state": str(p.get("state", "queued")), "round": int(p.get("round", 1))})
	return out


## What a game's row in My games says about it, in a person's words.
static func state_word(job: Dictionary) -> String:
	var n: int = version_n(job)
	match screen_of(job):
		"designing": return "The designer is thinking"
		"pitch": return "Waiting for you: the pitch"
		"phase_done": return "Waiting for you: try it"
		"done": return "Ready, version %d" % n if n > 1 else "Ready"
		"failed": return "Stopped"
		"error": return "Cannot be read"
	return "Changing" if not changing(job).is_empty() else "Building"


## My games: every job under the jobs root, newest first (by its first event): [{dir, title, word, screen, version, ts}].
## `limit` caps how many logs are read (a jobs root of a long night holds hundreds).
static func games(root: String, limit: int = 40) -> Array:
	var dirs: PackedStringArray = JobModel.list_job_dirs(root)
	var named: Array = []
	for d: String in dirs:
		named.append([FileAccess.get_modified_time(d.path_join("job.jsonl")), d])
	named.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]) or (int(a[0]) == int(b[0]) and str(a[1]) > str(b[1])))
	var out: Array = []
	for i: int in mini(limit, named.size()):
		var d: String = named[i][1]
		var j: Dictionary = JobModel.read_job(d, 0.0)
		var title: String = str(j.get("title", ""))
		if title.is_empty():
			title = JobModel.one_line(str(j.get("sentence", d.get_file())), 40)
		out.append({"dir": d, "title": title, "word": state_word(j), "screen": screen_of(j), "version": version_n(j), "ts": float(j.get("first_ts", 0.0)), "sentence": str(j.get("sentence", ""))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["ts"]) > float(b["ts"]) or (float(a["ts"]) == float(b["ts"]) and str(a["dir"]) > str(b["dir"])))
	return out
