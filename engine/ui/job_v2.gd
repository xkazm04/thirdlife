extends RefCounted
## L3 (night of 21 Nov 2026): the designer v2 part of the job picture (contracts/JOB.md "Added 2026-11-20"), folded into
## ui/job_model.gd `reduce` (kept apart for the size ratchet). Pure: events in, keys of the job Dictionary out.
##
## Keys it adds (absent keys of the log stay at these values: a job made before the v2 reads as before):
##   creativity "standard" | "crazy"; run_through bool; pitch ""; aspects []; reactions {aspect id: {choice, note?, seq}}
##   (the latest per aspect, on the latest brief); briefs (how many brief_set); phases [{id, title, try, packages, state,
##   note, done_count, holds}] (a plan without phases is one phase with id ""); phases_given bool; phase_events [];
##   phase_wait (the phase whose phase_done waits for a review, ""); phase_now (index of the first phase not passed, -1)
## L1 of 21 Nov (JOB.md "Added 2026-11-21", the design room and the quality loop): concept_pitch (the chosen concept's
##   pitch, ""); design_reviews [{round, verdict, notes}]; quality_hold {milestone, round, notes} while a milestone the
##   critic still finds NOT ok after its last revise round waits for `foreman quality` (pause_kind "quality").


const DEFAULTS: Dictionary = {"creativity": "standard", "run_through": false, "pitch": "", "aspects": [], "reactions": {}, "briefs": 0,
	"phases": [], "phases_given": false, "phase_events": [], "phase_wait": "", "phase_now": -1,
	"concept_pitch": "", "design_reviews": [], "quality_hold": {}}


static func defaults() -> Dictionary:
	return DEFAULTS.duplicate(true)


static func on_created(job: Dictionary, e: Dictionary) -> void:
	job["creativity"] = "crazy" if str(e.get("creativity", "")) == "crazy" else "standard"
	job["run_through"] = e.get("run_through", false) == true


static func on_brief(job: Dictionary, e: Dictionary) -> void:
	job["briefs"] = int(job["briefs"]) + 1
	var brief: Dictionary = e.get("brief", {}) if e.get("brief", {}) is Dictionary else {}
	job["pitch"] = str(brief.get("pitch", ""))
	job["aspects"] = (brief.get("aspects", []) as Array).duplicate(true) if brief.get("aspects", []) is Array else []
	job["reactions"] = {}          # reactions to an earlier brief no longer count
	var concept: Dictionary = brief.get("concept", {}) if brief.get("concept", {}) is Dictionary else {}
	var cands: Array = concept.get("candidates", []) if concept.get("candidates", []) is Array else []
	var k: int = int(concept.get("chosen", -1)) if concept.get("chosen", -1) is float or concept.get("chosen", -1) is int else -1
	job["concept_pitch"] = str((cands[k] as Dictionary).get("pitch", "")) if k >= 0 and k < cands.size() and cands[k] is Dictionary else ""


static func on_plan(job: Dictionary, e: Dictionary, order: Array) -> void:
	job["phases_given"] = e.get("phases", null) is Array
	job["phases"] = []
	job["phase_events"] = []
	job["phase_wait"] = ""
	if bool(job["phases_given"]):
		for ph: Variant in e["phases"]:
			if ph is Dictionary:
				(job["phases"] as Array).append({"id": str(ph.get("id", "")), "title": str(ph.get("title", "")), "try": str(ph.get("try", "")),
					"packages": (ph.get("packages", []) as Array).duplicate(), "state": "next", "note": "", "done_count": 0, "holds": 0})
	else:                              # a plan without phases runs as one phase, as before
		job["phases"] = [{"id": "", "title": "", "try": "", "packages": order.duplicate(), "state": "next", "note": "", "done_count": 0, "holds": 0}]


## Called for every event before job_model's own reading of it: job_created, brief_set, plan_set (after the plan's
## package order is known: it reads the packages itself), aspect_reacted, phase_done, phase_reviewed.
static func take(job: Dictionary, e: Dictionary) -> bool:
	match str(e.get("type", "")):
		"job_created":
			on_created(job, e)
		"brief_set":
			on_brief(job, e)
		"plan_set":
			var order: Array = []
			for spec: Variant in e.get("packages", []):
				if spec is Dictionary:
					order.append(str((spec as Dictionary).get("id", "")))
			on_plan(job, e, order)
		"aspect_reacted":
			var aid: String = str(e.get("aspect", ""))
			for a: Variant in job["aspects"]:
				if a is Dictionary and str((a as Dictionary).get("id", "")) == aid:
					var r: Dictionary = {"choice": str(e.get("choice", "")), "seq": int(e.get("seq", 0))}
					if e.has("note"):
						r["note"] = str(e["note"])
					job["reactions"][aid] = r      # the latest reaction per aspect counts
			job["activity"] = "you reacted to %s" % aid   # job_model writes no activity for these three
		"phase_done":
			(job["phase_events"] as Array).append({"type": "done", "phase": str(e.get("phase", "")), "seq": int(e.get("seq", 0))})
			job["phase_wait"] = str(e.get("phase", ""))
			job["activity"] = "phase %s is done: try it" % str(e.get("phase", ""))
		"phase_reviewed":
			var rev: Dictionary = {"type": str(e.get("verdict", "")), "phase": str(e.get("phase", "")), "by": str(e.get("by", "")), "seq": int(e.get("seq", 0))}
			if e.has("note"):
				rev["note"] = str(e["note"])
			(job["phase_events"] as Array).append(rev)
			job["phase_wait"] = ""
			job["activity"] = "phase %s: %s" % [str(e.get("phase", "")), "passed" if rev["type"] == "pass" else "held for a change"]
		"design_reviewed":
			(job["design_reviews"] as Array).append({"round": int(e.get("round", 0)), "verdict": str(e.get("verdict", "")), "notes": str(e.get("notes", ""))})
			job["activity"] = "the producer reviewed the design (round %d): %s" % [int(e.get("round", 0)), str(e.get("verdict", ""))]
		"milestone":
			on_look(job, e)
			return false            # job_model reads the milestone itself
		"comment":
			var hold: Dictionary = job["quality_hold"]
			if not hold.is_empty() and str(e.get("milestone", "")) == str(hold["milestone"]) and str(e.get("text", "")).begins_with("quality "):
				job["quality_hold"] = {}
		_:
			return false
	return true


## A look of the quality loop: round 2 or later still NOT ok holds the job for the owner; any later look clears it.
static func on_look(job: Dictionary, e: Dictionary) -> void:
	var summary: String = str(e.get("summary", ""))
	var at: int = summary.find("critic (V5) NOT ok: ")
	if int(e.get("round", 0)) >= 2 and at >= 0:
		var notes: String = summary.substr(at + 20).get_slice("[", 0).strip_edges()
		job["quality_hold"] = {"milestone": str(e.get("milestone", "")), "round": int(e.get("round", 0)), "notes": notes}
	elif not (job["quality_hold"] as Dictionary).is_empty() and str(e.get("milestone", "")) == str(job["quality_hold"]["milestone"]):
		job["quality_hold"] = {}


## After job_model's reduce: the phases' states, and a pause on a phase (pause_kind "phase").
static func finish(job: Dictionary) -> Dictionary:
	fold_phases(job)
	if str(job["phase"]) == "paused" and str(job["pause_kind"]) == "other" and waits_on_phase(job):
		job["pause_kind"] = "phase"
	var hold: Dictionary = job["quality_hold"]
	if str(job["phase"]) == "paused" and str(job["job_reason"]) == "quality" and not hold.is_empty():
		job["pause_kind"] = "quality"     # Create and the panel print job_reason: the critic's words, not the bare reason
		job["job_reason"] = "the critic still finds %s weak: %s" % [str(hold["milestone"]), str(hold["notes"])]
	return job


## A pause on a phase: the job is paused with reason "phase" and its last phase_done names a phase of the plan.
static func waits_on_phase(job: Dictionary) -> bool:
	return str(job["job_reason"]) == "phase" and (job["phases"] as Array).any(func(ph: Dictionary) -> bool: return str(ph["id"]) == str(job["phase_wait"]) and not str(ph["id"]).is_empty())


## Each phase's state from the plan's phases and the phase events since that plan.
##   passed    a `phase_reviewed pass` came after its last `phase_done`
##   done      its last `phase_done` waits for the player (or for the Foreman's auto pass)
##   held      `phase_reviewed hold`: a change round on its packages runs (`note` = the player's words)
##   building  the first phase not passed yet (its packages are being built)
##   next      a later phase
## `phase_now` is the index of the first phase that is not passed (-1 when every phase passed or there is no plan);
## each phase's `done_count` counts its packages that are promoted.
static func fold_phases(job: Dictionary) -> void:
	var phases: Array = job["phases"]
	var by_id: Dictionary = {}
	for ph: Dictionary in phases:
		by_id[str(ph["id"])] = ph
		var n: int = 0
		for id: Variant in ph["packages"]:
			if (job["packages"] as Dictionary).has(str(id)) and str(job["packages"][str(id)]["state"]) == "promoted":
				n += 1
		ph["done_count"] = n
	for ev: Dictionary in job["phase_events"]:
		var ph: Variant = by_id.get(str(ev["phase"]), null)
		if ph == null:
			continue
		match str(ev["type"]):
			"done": ph["state"] = "done"
			"pass": ph["state"] = "passed"
			"hold":
				ph["state"] = "held"
				ph["note"] = str(ev.get("note", ""))
				ph["holds"] = int(ph["holds"]) + 1
	job["phase_now"] = -1
	for k: int in phases.size():
		if str(phases[k]["state"]) != "passed":
			job["phase_now"] = k
			if str(phases[k]["state"]) == "next":
				phases[k]["state"] = "building"
			break
	# a job that ended done promoted every package: an old plan without phase events counts as passed
	if str(job["job_state"]) == "done" and not (job["promotions"] as Array).is_empty() and not bool(job["phases_given"]):
		for ph: Dictionary in phases:
			ph["state"] = "passed"
		job["phase_now"] = -1
