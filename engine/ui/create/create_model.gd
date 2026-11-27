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
const Notes = preload("res://ui/create/create_notes.gd")   # D27: the Foreman notes a change is told by (balance, measure kept, not finished)

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
	# N27 T2: a job that ended done on the earlier version without promoting the change ("the change was NOT made") is
	# not made either; the Foreman's "change not finished" note says why, in words
	var ended: bool = str(c.get("outcome", "")) == "in flight" and str(job.get("phase", "")) == "done" and str(job.get("job_reason", "")).begins_with("the change was NOT made")
	if ended or str(c.get("outcome", "")) in ["not made", "failed", "cancelled"]:
		var why: String = Notes.not_finished(job, int(c.get("seq", 0)))
		return "Your last change could not be made: \u201c%s\u201d%s" % [JobModel.one_line(str(c["text"]), 60), ("\n" + why) if not why.is_empty() else ""]
	var kept: String = Notes.measure_note(job, int(c.get("seq", 0)))
	var lost: String = Notes.not_made_note(job, int(c.get("seq", 0)))   # D27 round 4, item 18
	var moved: String = Notes.balance_note(job, int(c.get("seq", 0)))
	var parts: PackedStringArray = []
	for p: String in [kept, lost, moved]:
		if not p.is_empty():
			parts.append(p)
	return "\n".join(parts)


## S2-juice (27 Nov): the Foreman's juice-pass note on the person's last made change (foreman/src/juicepass.ts):
## "ran" (the standard juice pass went with it), "offered" (arm B: a move built plain; Create offers "make it juicy"),
## or "". JUICY_FOLLOW_UP is the one-click follow-up's words; the Foreman runs the pass on them.
const JUICE_RAN := "[foreman] juice pass: "
const JUICE_OFFER := "[foreman] juice pass offered: "
const JUICY := "Make it juicy."
static func juice_of(job: Dictionary) -> String:
	var mine: Array = person_changes(job)
	if mine.is_empty() or str((mine.back() as Dictionary).get("outcome", "")) != "made":
		return ""
	var seq: int = int((mine.back() as Dictionary).get("seq", 0))
	var said: String = ""
	for n: Variant in job.get("notes", []):
		if n is Dictionary and int((n as Dictionary).get("seq", 0)) > seq:
			var t: String = str((n as Dictionary).get("text", ""))
			said = "ran" if t.begins_with(JUICE_RAN) else "offered" if t.begins_with(JUICE_OFFER) and said.is_empty() else said
	return said


static func juicy_follow_up(job: Dictionary) -> String:
	var mine: Array = person_changes(job)
	var last: String = str((mine.back() as Dictionary).get("text", "")) if not mine.is_empty() else ""
	return "Make it juicy: the move I just added (“%s”). Keep its rules as they are." % JobModel.one_line(last, 300)


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
	if str(job.get("job_reason", "")).begins_with("moving to the newest base"):
		return "Moving to the newest base"      # H2: foreman rebase is verifying the game on the newest base
	return "Changing" if not changing(job).is_empty() else "Building"


## My games: the jobs under the jobs root, newest first (by its first event), one row per game (one_per_game):
## [{dir, title, word, screen, version, ts, sentence, behind, builds}].
## `limit` caps how many logs are read (a jobs root of a long night holds hundreds).
static func games(root: String, limit: int = 400) -> Array:
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
		out.append({"dir": d, "title": title, "word": state_word(j), "screen": screen_of(j), "version": version_n(j), "ts": float(j.get("first_ts", 0.0)), "sentence": str(j.get("sentence", "")),
			"behind": base_behind(d) if screen_of(j) == "done" else 0})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["ts"]) > float(b["ts"]) or (float(a["ts"]) == float(b["ts"]) and str(a["dir"]) > str(b["dir"])))
	return one_per_game(out)


## 26 Nov (the owner: "Colosseum is there multiple times across versions"): jobs with the same title are builds of one
## game and get one row: the final version, i.e. the newest finished build (Ready), else the newest build; "builds" counts
## them. Rows come newest first and keep that order.
static func one_per_game(rows: Array) -> Array:
	var by: Dictionary = {}
	for g: Dictionary in rows:
		var k: String = str(g["title"]).strip_edges().to_lower()
		if not by.has(k):
			by[k] = []
		(by[k] as Array).append(g)
	var out: Array = []
	for k: String in by.keys():                     # a Dictionary keeps the order keys were added: newest first
		var all: Array = by[k]
		var pick: Dictionary = all[0]
		for g: Dictionary in all:
			if str(g["screen"]) == "done":
				pick = g
				break
		pick = pick.duplicate()
		pick["builds"] = all.size()
		out.append(pick)
	return out


## H2 (25 Nov): the newest base a game on the rink core can move to (engine/templates/rink_game).
const BASE_DIR: String = "res://templates/rink_game"
## The base's own code: what a game made on it holds from it (its data is the game's).
const BASE_PARTS: PackedStringArray = ["scripts", "gen", "tests"]


## H2: how many of the newest base's own files (scripts/, gen/, tests/) a finished game made on that base lacks or holds in
## another version (its pack/ beside job.jsonl): more than 0 = My games offers "Newest base" (foreman rebase). 0 for a game
## not made on the base (no gen/tj_rink.gd in its pack), and when either is not there.
static func base_behind(job_dir: String, base_dir: String = BASE_DIR) -> int:
	var pack: String = job_dir.path_join("pack")
	if not FileAccess.file_exists(pack.path_join("gen/tj_rink.gd")) or not FileAccess.file_exists(base_dir.path_join("pack.json")):
		return 0
	var n: int = 0
	for part: String in BASE_PARTS:
		for rel: String in _files(base_dir, part):
			var mine: String = pack.path_join(rel)
			if not FileAccess.file_exists(mine) or FileAccess.get_file_as_bytes(mine) != FileAccess.get_file_as_bytes(base_dir.path_join(rel)):
				n += 1
	return n


## Files under <root>/<rel> (recursive, pack-relative), engine caches (.uid, .import) left out.
static func _files(root: String, rel: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var d: DirAccess = DirAccess.open(root.path_join(rel))
	if d == null:
		return out
	for f: String in d.get_files():
		if not (f.ends_with(".uid") or f.ends_with(".import")):
			out.append(rel.path_join(f))
	for sub: String in d.get_directories():
		out.append_array(_files(root, rel.path_join(sub)))
	return out


# ---------------------------------------------------------------- E4b (25 Nov): the pauses a person answers

## The builder's open question (the newest): {package, title, text, seq}, or {} when none is open.
static func open_question(job: Dictionary) -> Dictionary:
	var qs: Array = job.get("questions", [])
	for i: int in range(qs.size() - 1, -1, -1):
		var q: Dictionary = qs[i]
		if bool(q.get("open", false)):
			var p: Dictionary = (job.get("packages", {}) as Dictionary).get(str(q["package"]), {})
			return {"package": str(q["package"]), "title": str(p.get("title", q["package"])), "text": str(q.get("text", "")).strip_edges(), "seq": int(q.get("seq", 0))}
	return {}


## The choices a question offers, in its own words (at most 3): its list lines ("- x", "1. x", "a) x"), else the two
## sides of "..., or ...?" ; else Yes / No for a question that asks for one ("May ...", "Can ...", "Should ...").
static func question_options(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var re: RegEx = RegEx.create_from_string("^\\s*(?:[-*\u2022]|\\d+[.)]|[a-cA-C][.)])\\s+(.+)$")
	for line: String in text.split("\n"):
		var m: RegExMatch = re.search(line)
		if m != null and out.size() < 3:
			out.append(JobModel.one_line(m.get_string(1).strip_edges(), 90))
	if not out.is_empty():
		return out
	var flat: String = JobModel.one_line(text)
	var guess: RegExMatch = RegEx.create_from_string("Did you mean ([^?]+)\\?").search(flat)   # E4c: E3d's asked-back change
	if guess != null:
		out.append("Yes, " + guess.get_string(1).strip_edges())
		return out
	var q: String = flat.substr(flat.rfind(". ") + 2) if flat.rfind(". ") >= 0 and flat.rfind(". ") < flat.length() - 3 else flat
	var at: int = q.find(", or ")
	if at > 0:
		out.append(JobModel.one_line(q.substr(0, at).strip_edges().trim_suffix("?"), 90))
		var second: String = q.substr(at + 5).strip_edges().trim_suffix("?")
		out.append(JobModel.one_line(second.substr(0, 1).to_upper() + second.substr(1), 90))
		return out
	var first: String = q.get_slice(" ", 0).to_lower()
	if q.ends_with("?") and first in ["may", "can", "should", "shall", "is", "are", "do", "does", "will", "would"]:
		out.append_array(["Yes", "No"])
	return out


## A quality hold in a person's words: {milestone, reasons: [<= 3 short lines], still: <abs png or "">}, or {}.
static func quality_view(job: Dictionary) -> Dictionary:
	var hold: Dictionary = job.get("quality_hold", {})
	if hold.is_empty() or str(job.get("pause_kind", "")) != "quality":
		return {}
	var reasons: PackedStringArray = []
	for part: String in str(hold.get("notes", "")).replace("|", ";").split(";"):
		var t: String = part.strip_edges()
		if t.is_empty() or t.begins_with("slop:") or RegEx.create_from_string("^[a-z_]+ [0-9.]+(, [a-z_]+ [0-9.]+)*$").search(t) != null:
			continue                       # the score row and the slop tags are for the Foreman, not for a person
		if reasons.size() < 3:
			reasons.append(JobModel.one_line(t, 110))
	var still: String = ""
	for m: Variant in job.get("milestones", []):
		if m is Dictionary and str((m as Dictionary).get("milestone", "")) == str(hold.get("milestone", "")):
			var caps: Array = (m as Dictionary).get("captures", [])
			for c: Variant in caps:
				var f: String = str(job.get("dir", "")).path_join(str(c))
				if FileAccess.file_exists(f):
					still = f
					break
	return {"milestone": str(hold.get("milestone", "")), "reasons": reasons, "still": still}


# ---------------------------------------------------------------- E4c (25 Nov): the phase pause's figures, a scope "yes"

## The measured check at the waiting phase of a game on a core (coregate.ts phaseCheck writes the note "[foreman]
## measured at the phase pause <phase>: ..." and its report tl.foreman.measured/1), in a person's figures:
## {goals, minutes, house_goals, house_minutes, defects: [lines], toys: [lines], measured: bool}; {} when the phase has none.
## H1c: toys are the check's words about a toy that changes nothing or is worth about nothing (coreroute.ts toyLines).
static func measured_view(job: Dictionary) -> Dictionary:
	var e: Dictionary = waiting(job)
	if e.is_empty():
		return {}
	var head: String = "[foreman] measured at the phase pause %s:" % str(e["id"])
	var note: String = ""
	for n: Variant in job.get("notes", []):
		if n is Dictionary and str((n as Dictionary).get("text", "")).begins_with(head):
			note = str(n["text"])
	if note.is_empty():
		return {}
	var out: Dictionary = {"goals": -1.0, "minutes": -1.0, "house_goals": -1.0, "house_minutes": -1.0, "defects": [], "toys": [], "measured": true}
	var at: int = note.rfind("[report: ")
	var rep: Variant = JobModel.read_json(str(job.get("dir", "")).path_join(note.substr(at + 9).trim_suffix("]"))) if at >= 0 else null
	if rep is Dictionary:
		var run: Dictionary = (rep as Dictionary).get("run", {})
		var fig: Dictionary = run.get("figures", {})
		out["goals"] = float(fig.get("pro_goals_a_match", -1.0))
		out["minutes"] = float(fig.get("pro_minutes", -1.0))
		out["measured"] = int(run.get("code", 2)) != 2
		out["defects"] = (run.get("defects", []) as Array).map(func(d: Variant) -> String: return JobModel.one_line(str(d).get_slice(" (", 0).get_slice(": thirdjam", 0), 90))
		out["toys"] = (run.get("toys", []) as Array).map(func(d: Variant) -> String: return JobModel.one_line(str(d), 110))
		var house: Dictionary = (rep as Dictionary).get("house", {}).get("figures", {}) if (rep as Dictionary).get("house") is Dictionary else {}
		out["house_goals"] = float(house.get("pro_goals_a_match", -1.0))
		out["house_minutes"] = float(house.get("pro_minutes", -1.0))
	else:
		# no report on disk: the figures in the note's words
		var g: RegExMatch = RegEx.create_from_string("pro_goals_a_match ([0-9.]+)").search(note)
		var m: RegExMatch = RegEx.create_from_string("pro_minutes ([0-9.]+)").search(note)
		out["goals"] = float(g.get_string(1)) if g != null else -1.0
		out["minutes"] = float(m.get_string(1)) if m != null else -1.0
		out["measured"] = not note.contains(" not measured ")
		if note.contains("GROSS DEFECTS: "):
			out["defects"] = [JobModel.one_line(note.get_slice("GROSS DEFECTS: ", 1).get_slice(";", 0).get_slice(": thirdjam", 0), 90)]
	return out


## The package a question asks to be allowed to change (a scope it wants widened: "May core be changed ...", "can those
## files be added to this package's scope?"): a package of the plan named in it, else the asking package; "" for any
## other question. Its chip "Yes, let it" answers with `foreman answer ... --change <package>`.
static func scope_package(job: Dictionary, q: Dictionary) -> String:
	var text: String = str(q.get("text", ""))
	if RegEx.create_from_string("(?i)\\b(scope|be changed|be added to|another package|a package that owns|may change|allowed to (change|edit))\\b").search(text) == null:
		return ""
	for id: Variant in job.get("order", []):
		if str(id) != str(q.get("package", "")) and RegEx.create_from_string("\\b%s\\b" % str(id)).search(text) != null:
			return str(id)
	return str(q.get("package", ""))


## H1b of 25 Nov (G2's finding: the brief's estimate never reached the pitch): what building it will take, in a person's
## words, from brief_set's estimate {packages, wallMinutes, tokens}: "About 8 hours and 6.5 M tokens to build (9 parts)".
## "" when the job has no estimate.
static func estimate_words(est: Dictionary) -> String:
	var minutes: int = int(est.get("wallMinutes", 0))
	var tokens: int = int(est.get("tokens", 0))
	var parts: int = int(est.get("packages", 0))
	if minutes <= 0 and tokens <= 0:
		return ""
	var time: String = ""
	if minutes > 0 and minutes < 60:
		time = "%d minutes" % (int(roundf(float(minutes) / 5.0)) * 5 if minutes >= 10 else minutes)
	elif minutes >= 60:
		var halves: int = int(roundf(float(minutes) / 30.0))
		time = "1 hour" if halves == 2 else ("%d hours" % (halves / 2) if halves % 2 == 0 else "%.1f hours" % (float(halves) / 2.0))
	var tok: String = ""
	if tokens >= 1000000:
		var m: float = roundf(float(tokens) / 100000.0) / 10.0
		tok = ("%d M tokens" % int(m)) if is_equal_approx(m, roundf(m)) else ("%.1f M tokens" % m)
	elif tokens > 0:
		tok = "%d k tokens" % int(roundf(float(tokens) / 1000.0))
	var what: String = " and ".join(PackedStringArray([time, tok].filter(func(s: String) -> bool: return not s.is_empty())))
	return "About %s to build%s" % [what, (" (%d parts)" % parts) if parts > 0 else ""]


## H1d (the Director's choice (b)): the engine code the cards still kept ask for, in a person's words: "Fair-game trap
## needs new engine code: about 6 hours more"; "" when no kept card needs it. A card swapped to an alternative or dropped
## needs none (an alternative is the data-only way).
static func core_cost_words(job: Dictionary, taps: Dictionary) -> String:
	var parts: PackedStringArray = []
	var total: int = 0
	for a: Variant in job.get("aspects", []):
		if not (a is Dictionary) or str((a as Dictionary).get("needs", "")) != "core":
			continue
		if choice_of(job, taps, str(a.get("id", ""))) != "keep":
			continue
		total += int(a.get("hours", 0))
		parts.append(str(a.get("title", "")))
	if parts.is_empty():
		return ""
	return "%s %s new engine code: about %d hour%s more. Tap %s for a way with data only" % [
		" and ".join(parts), "needs" if parts.size() == 1 else "need", total, "" if total == 1 else "s", "it" if parts.size() == 1 else "them"]
