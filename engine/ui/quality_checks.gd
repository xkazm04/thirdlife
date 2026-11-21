extends RefCounted
## L1b (day of 21 Nov 2026): the checks of the design room and quality loop readers (contracts/JOB.md "Added
## 2026-11-21") over two fixture logs written by a real Foreman run with the fake adapter (the L1 walkthrough):
##   ui/fixtures/create/c13-quality-hold   the room (a revise, then ok), a plan with `serves`, a blockout the critic
##                                         finds NOT ok after two revise rounds: `job_state paused` reason "quality"
##   ui/fixtures/create/c14-quality-done   the same job after `foreman quality accept`: done and promoted
## The strict site reader (kernel/world/site/log.gd, event_schema.gd) must take every line and every new key, and refuse
## broken copies; the panel model (ui/job_model.gd + job_v2.gd) and the Create page model must show the hold.
##   var n: int = QualityChecks.run(check)      check: func(name: String, ok: bool, detail: String); returns CHECKS

const SiteLog = preload("res://kernel/world/site/log.gd")
const EventSchema = preload("res://kernel/world/site/event_schema.gd")
const JobModel = preload("res://ui/job_model.gd")
const Model = preload("res://ui/create/create_model.gd")

const FIXTURES: String = "res://ui/fixtures/create"
const HOLD: String = "c13-quality-hold"
const DONE: String = "c14-quality-done"
const CHECKS: int = 6

## The 2026-11-21 keys a reader must take; the two fixtures together hold each of them.
const NEW_KEYS: Array[String] = ["design_reviewed.round", "design_reviewed.verdict=ok", "design_reviewed.verdict=revise",
	"design_reviewed.scores", "design_reviewed.notes", "brief.concept", "brief.design", "package.serves", "milestone.round",
	"milestone.kept", "milestone.strips", "job_state.reason=quality", "comment.text=quality accept"]


static func _text(name: String) -> String:
	return FileAccess.get_file_as_string(ProjectSettings.globalize_path(FIXTURES).path_join(name).path_join("job.jsonl"))


static func run(check: Callable) -> int:
	var n: int = 0
	var events: Dictionary = {}
	# 1. every line of both logs passes the site's strict reader
	var bad: PackedStringArray = []
	var lines: int = 0
	var taken: int = 0
	for name: String in [HOLD, DONE]:
		var lg: RefCounted = SiteLog.new()
		var text: String = _text(name)
		lg.call("feed", text)
		events[name] = lg.get("events")
		lines += text.strip_edges().split("\n").size()
		taken += (lg.get("events") as Array).size()
		if not str(lg.get("error")).is_empty():
			bad.append("%s: %s" % [name, str(lg.get("error"))])
	check.call("quality.schema: both v3 logs pass the site's strict reader (%d of %d lines)" % [taken, lines], bad.is_empty() and taken == lines and lines > 150, "; ".join(bad))
	n += 1
	# 2. every new key is in them
	var seen: Dictionary = {}
	for name: String in events:
		for e: Dictionary in events[name]:
			var t: String = str(e["type"])
			for k: String in e:
				seen["%s.%s" % [t, k]] = true
			match t:
				"design_reviewed": seen["design_reviewed.verdict=" + str(e["verdict"])] = true
				"brief_set":
					for k: String in e["brief"]:
						seen["brief." + k] = true
				"plan_set":
					for p: Dictionary in e["packages"]:
						for k: String in p:
							seen["package." + k] = true
				"job_state": seen["job_state.reason=" + str(e.get("reason", ""))] = true
				"comment": seen["comment.text=" + str(e["text"]).get_slice(":", 0)] = true
	var missing: PackedStringArray = []
	for k: String in NEW_KEYS:
		if not seen.has(k):
			missing.append(k)
	check.call("quality.schema: the fixtures hold all %d new keys of JOB.md 2026-11-21" % NEW_KEYS.size(), missing.is_empty(), "missing " + ", ".join(missing))
	n += 1
	# 3. broken copies are refused, one per rule
	var good: Dictionary = {}
	var look: Dictionary = {}
	for e: Dictionary in events[DONE]:
		if e["type"] == "design_reviewed" and good.is_empty():
			good = e
		if e["type"] == "milestone" and e.has("strips") and e.has("kept") and look.is_empty():
			look = e
	var broken: Array = []
	var x: Dictionary = good.duplicate(true)
	x["scores"]["fun"] = 1
	broken.append([x, "unknown key"])
	x = good.duplicate(true)
	x["verdict"] = "maybe"
	broken.append([x, "verdict"])
	x = good.duplicate(true)
	x["scores"]["gif"] = 1.5
	broken.append([x, "gif"])
	x = look.duplicate(true)
	x["kept"] = "both"
	broken.append([x, "kept"])
	x = look.duplicate(true)
	x["strips"] = [{"capture": "C:/abs.png", "label": "x"}]
	broken.append([x, "strips"])
	var accepted: PackedStringArray = []
	for b: Array in broken:
		var why: String = EventSchema.check(b[0])
		if why.is_empty() or not why.contains(str(b[1])):
			accepted.append("%s -> '%s'" % [str(b[1]), why])
	check.call("quality.schema: the strict reader refuses %d broken v3 events (scores key, verdict, score range, kept, strip path)" % broken.size(), not good.is_empty() and not look.is_empty() and accepted.is_empty(), "; ".join(accepted))
	n += 1
	# 4. the panel model shows the hold with the critic's words
	var hold: Dictionary = JobModel.reduce(events[HOLD], 0.0)
	var reviews: Array = (hold["design_reviews"] as Array).map(func(r: Dictionary) -> String: return "%d %s" % [int(r["round"]), str(r["verdict"])])
	check.call("quality.model: c13 is paused on quality, the critic's notes as the reason, the room's two reviews and the concept",
		hold["phase"] == "paused" and hold["pause_kind"] == "quality" and str(hold["job_reason"]).begins_with("the critic still finds blockout weak: ")
		and int((hold["quality_hold"] as Dictionary).get("round", 0)) == 2 and reviews == ["1 revise", "2 ok"]
		and not str(hold["concept_pitch"]).is_empty() and (hold["unknown_types"] as Array).is_empty(),
		"%s %s %s %s" % [hold["phase"], hold["pause_kind"], str(hold["job_reason"]).substr(0, 60), str(reviews)])
	n += 1
	# 5. after `quality accept`: done, the hold gone, three looks
	var done: Dictionary = JobModel.reduce(events[DONE], 0.0)
	check.call("quality.model: c14 (accepted) is done and promoted, no hold, the two revise looks and the greybox look",
		done["phase"] == "done" and (done["quality_hold"] as Dictionary).is_empty() and (done["milestones"] as Array).size() == 3
		and not (done["promotions"] as Array).is_empty() and (done["unknown_types"] as Array).is_empty(),
		"%s hold %s milestones %d" % [done["phase"], str(done["quality_hold"]), (done["milestones"] as Array).size()])
	n += 1
	# 6. the Create page: a held job is a job being built (with the pause callout), an accepted one is done
	check.call("quality.create: Create shows c13 as building (paused) and c14 as done", Model.screen_of(hold) == "building" and Model.screen_of(done) == "done",
		"%s / %s" % [Model.screen_of(hold), Model.screen_of(done)])
	n += 1
	return n
