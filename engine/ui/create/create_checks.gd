extends RefCounted
## L3 (night of 21 Nov 2026): the checks of the Create page and of the designer v2 readers, from the fixture job logs
## (ui/fixtures/create/, written against contracts/JOB.md "Added 2026-11-20"). Shared by `tools/ui.sh selftest`
## (ui/selftest.gd) and the kernel selftest block 630 (ui/create/create_case.gd). Headless; nothing is started (the
## page's door is dry), nothing is written but under `tmp`.
##
##   var done: bool = await CreateChecks.run(tree, check, tmp)     check: func(name: String, ok: bool, detail: String)
## `done` is true only when every check ran (a script error stops a coroutine half way: the caller must count it).
## A coroutine: the page is checked in the live tree (one frame after it is added).

const SiteLog = preload("res://kernel/world/site/log.gd")
const EventSchema = preload("res://kernel/world/site/event_schema.gd")
const SiteScript = preload("res://kernel/world/site.gd")
const JobModel = preload("res://ui/job_model.gd")
const Door = preload("res://ui/foreman_door.gd")
const Model = preload("res://ui/create/create_model.gd")
const CreateScene = preload("res://ui/create/create.tscn")
const Dungeons = preload("res://kernel/dungeon/dungeons.gd")

const FIXTURES: String = "res://ui/fixtures/create"
const STUB: String = "res://seeds/seed_wall"

## Every fixture and the screen it must show (the six states of the brief, plus redesign, hold, failures).
const SCREENS: Dictionary = {
	"c1-designing": "designing", "c2-pitch": "pitch", "c3-reacted": "pitch", "c4-redesigned": "pitch",
	"c5-building": "building", "c6-phase-done": "phase_done", "c7-held": "building", "c8-phase2": "building",
	"c9-done": "done", "c10-failed": "failed", "c11-design-failed": "failed", "c12-run-through": "done",
}

## The 2026-11-20 keys a reader must take; the two "every key" fixtures together hold each of them.
const NEW_KEYS: PackedStringArray = ["job_created.creativity", "job_created.run_through", "brief.pitch", "brief.aspects",
	"aspect.id", "aspect.icon", "aspect.title", "aspect.line", "aspect.detail", "aspect.alternatives", "aspect.crazy",
	"alternative.id", "alternative.title", "alternative.line", "aspect_reacted.aspect", "aspect_reacted.choice",
	"aspect_reacted.note", "plan_set.phases", "phase.id", "phase.title", "phase.try", "phase.packages", "phase_done.phase",
	"phase_reviewed.phase", "phase_reviewed.verdict=pass", "phase_reviewed.verdict=hold", "phase_reviewed.note",
	"phase_reviewed.by=player", "phase_reviewed.by=auto"]


static func dir_of(name: String) -> String:
	return ProjectSettings.globalize_path(FIXTURES).path_join(name)


static func events_of(name: String) -> Array:
	return JobModel.read_events(dir_of(name))["events"]


const CHECKS: int = 27


static func run(tree: SceneTree, check: Callable, tmp: String) -> bool:
	var count: Array = [0]
	var counted: Callable = func(name: String, ok: bool, detail: String = "") -> void:
		count[0] += 1
		check.call(name, ok, detail)
	_schema(counted)
	_model(counted)
	_door(counted, tmp)
	await _page(tree, counted, tmp)
	_site(counted)
	check.call("create.complete: all %d checks ran" % CHECKS, count[0] == CHECKS, "%d ran" % count[0])
	return count[0] == CHECKS


# ---------------------------------------------------------------- the strict mirror (site/event_schema.gd)

static func _schema(check: Callable) -> void:
	var names: Array = SCREENS.keys()
	names.sort()
	var bad: PackedStringArray = []
	var total: int = 0
	var lines: int = 0
	for n: String in names:
		var lg: RefCounted = SiteLog.new()
		var text: String = FileAccess.get_file_as_string(dir_of(n).path_join("job.jsonl"))
		lg.call("feed", text)
		total += (lg.get("events") as Array).size()
		lines += text.strip_edges().split("\n").size()
		if not str(lg.get("error")).is_empty():
			bad.append("%s: %s" % [n, str(lg.get("error"))])
	check.call("create.schema: every fixture event passes the site's strict reader (%d logs, %d of %d lines)" % [names.size(), total, lines], bad.is_empty() and total == lines and names.size() == 12, "; ".join(bad))
	# every new key is in a fixture that the strict reader took whole
	var seen: Dictionary = {}
	for n: String in ["c9-done", "c12-run-through"]:
		for e: Dictionary in events_of(n):
			var t: String = str(e["type"])
			for k: String in e:
				seen["%s.%s" % [t, k]] = true
			match t:
				"brief_set":
					for k: String in e["brief"]:
						seen["brief." + k] = true
					for a: Dictionary in e["brief"].get("aspects", []):
						for k: String in a:
							seen["aspect." + k] = true
						for alt: Dictionary in a["alternatives"]:
							for k: String in alt:
								seen["alternative." + k] = true
				"plan_set":
					for ph: Dictionary in e.get("phases", []):
						for k: String in ph:
							seen["phase." + k] = true
				"phase_reviewed":
					seen["phase_reviewed.verdict=" + str(e["verdict"])] = true
					seen["phase_reviewed.by=" + str(e["by"])] = true
	var missing: PackedStringArray = []
	for k: String in NEW_KEYS:
		if not seen.has(k):
			missing.append(k)
	check.call("create.schema: the every-key fixtures (c9-done, c12-run-through) hold all %d new keys of JOB.md 2026-11-20" % NEW_KEYS.size(), missing.is_empty(), "missing " + ", ".join(missing))
	# what the strict reader refuses: one broken copy of a good event per rule
	var brief: Dictionary = {}
	var plan: Dictionary = {}
	var hold: Dictionary = {}
	var created: Dictionary = {}
	for e: Dictionary in events_of("c9-done"):
		var t: String = str(e["type"])
		if t == "job_created":
			created = e
		elif t == "brief_set" and brief.is_empty():
			brief = e
		elif t == "plan_set":
			plan = e
		elif t == "phase_reviewed" and hold.is_empty() and e["verdict"] == "hold":
			hold = e
	var cases: Array = [
		["an unknown aspect key", func(b: Dictionary) -> void: b.brief.aspects[0]["colour"] = "red", brief, "unknown key"],
		["an icon outside the set", func(b: Dictionary) -> void: b.brief.aspects[0].icon = "dragon", brief, "invalid value"],
		["a 5-word aspect title", func(b: Dictionary) -> void: b.brief.aspects[0].title = "A very small rockhopper penguin", brief, "at most 4"],
		["a 13-word aspect line", func(b: Dictionary) -> void: b.brief.aspects[0].line = "one two three four five six seven eight nine ten eleven twelve thirteen", brief, "at most 12"],
		["a 21-word pitch", func(b: Dictionary) -> void: b.brief.pitch = " ".join(PackedStringArray(range(21).map(func(i: int) -> String: return "w%d" % i))), brief, "at most 20"],
		["2 aspects", func(b: Dictionary) -> void: b.brief.aspects = b.brief.aspects.slice(0, 2), brief, "3 to 7"],
		["8 aspects", _eight_aspects, brief, "3 to 7"],
		["a repeated aspect id", func(b: Dictionary) -> void: b.brief.aspects[1].id = b.brief.aspects[0].id, brief, "not unique"],
		["one alternative", func(b: Dictionary) -> void: b.brief.aspects[0].alternatives = b.brief.aspects[0].alternatives.slice(0, 1), brief, "2 to 3"],
		["crazy: false (absent means not crazy)", func(b: Dictionary) -> void: b.brief.aspects[0].crazy = false, brief, "invalid value"],
		["creativity other than crazy", func(b: Dictionary) -> void: b.creativity = "wild", created, "invalid value"],
		["run_through: false (absent means stop)", func(b: Dictionary) -> void: b.run_through = false, created, "invalid value"],
		["a package in no phase", func(b: Dictionary) -> void: b.phases[2].packages = [], plan, "at least one"],
		["a package in two phases", func(b: Dictionary) -> void: b.phases[1].packages.append("ice_arena"), plan, "two phases"],
		["a package that is not in the plan", func(b: Dictionary) -> void: b.phases[2].packages.append("ghost"), plan, "not a package"],
		["a dependency in a later phase", _late_dependency, plan, "later phase"],
		["1 phase", func(b: Dictionary) -> void: b.phases = b.phases.slice(0, 1), plan, "2 to 5"],
		["a 13-word try line", func(b: Dictionary) -> void: b.phases[0]["try"] = "one two three four five six seven eight nine ten eleven twelve thirteen", plan, "at most 12"],
		["an unknown phase key", func(b: Dictionary) -> void: b.phases[0]["stops"] = true, plan, "unknown key"],
		["hold without a note", func(b: Dictionary) -> void: b.erase("note"), hold, "required with verdict hold"],
		["a verdict other than pass or hold", func(b: Dictionary) -> void: b.verdict = "skip", hold, "invalid value"],
		["an empty hold note", func(b: Dictionary) -> void: b.note = "", hold, "phase_reviewed.note"],
		["an alternative called keep", func(b: Dictionary) -> void: b.brief.aspects[0].alternatives[0].id = "keep", brief, "invalid value"],
		["an alternative called drop", func(b: Dictionary) -> void: b.brief.aspects[0].alternatives[1].id = "drop", brief, "invalid value"],
		["a phase id that is not snake_case", func(b: Dictionary) -> void: b.phases[0].id = "Slide-1", plan, "invalid value"],
	]
	var wrong: PackedStringArray = []
	for c: Array in cases:
		var e: Dictionary = (c[2] as Dictionary).duplicate(true)
		(c[1] as Callable).call(e)
		var why: String = EventSchema.check(e)
		if not why.contains(str(c[3])):
			wrong.append("%s: got '%s'" % [c[0], why])
	check.call("create.schema: %d broken copies of the new events are refused, each for its own reason" % cases.size(), wrong.is_empty(), "; ".join(wrong))
	var reacted_ok: bool = EventSchema.check({"v": 1, "seq": 9, "ts": "2026-11-21T19:00:00.000Z", "job": "x", "type": "aspect_reacted", "aspect": "orca", "choice": "drop"}).is_empty() \
		and not EventSchema.check({"v": 1, "seq": 9, "ts": "2026-11-21T19:00:00.000Z", "job": "x", "type": "aspect_reacted", "aspect": "orca", "choice": "drop", "note": ""}).is_empty() \
		and not EventSchema.check({"v": 1, "seq": 9, "ts": "2026-11-21T19:00:00.000Z", "job": "x", "type": "aspect_reacted", "aspect": "orca"}).is_empty() \
		and not EventSchema.check({"v": 1, "seq": 9, "ts": "2026-11-21T19:00:00.000Z", "job": "x", "type": "phase_done"}).is_empty()
	check.call("create.schema: aspect_reacted without its note passes; with an empty note, without its choice, and phase_done without its phase, are refused", reacted_ok)


static func _eight_aspects(b: Dictionary) -> void:
	var more: Array = b.brief.aspects.duplicate(true)
	for i: int in 3:
		var x: Dictionary = more[i].duplicate(true)
		x.id = "extra_%d" % i
		more.append(x)
	b.brief.aspects = more


static func _late_dependency(b: Dictionary) -> void:
	b.phases[0].packages = ["penguin_moves", "look_sound"]
	b.phases[2].packages = ["ice_arena"]


# ---------------------------------------------------------------- the model (job_model.gd + create_model.gd)

static func _model(check: Callable) -> void:
	var wrong: PackedStringArray = []
	for n: String in SCREENS:
		var j: Dictionary = JobModel.read_job(dir_of(n), 0.0)
		var got: String = Model.screen_of(j)
		if got != SCREENS[n]:
			wrong.append("%s: %s (want %s)" % [n, got, SCREENS[n]])
	check.call("create.model: each of %d fixtures shows its screen (idea is the empty job)" % SCREENS.size(), wrong.is_empty() and Model.screen_of({}) == "idea", "; ".join(wrong))
	var c2: Dictionary = JobModel.read_job(dir_of("c2-pitch"), 0.0)
	check.call("create.model: c2 crazy brief: pitch, 6 aspects, 2 crazy, no reaction", c2["creativity"] == "crazy" and str(c2["pitch"]).begins_with("Slide, bump") and (c2["aspects"] as Array).size() == 6
		and (c2["aspects"] as Array).filter(func(a: Dictionary) -> bool: return a.get("crazy", false) == true).size() == 2 and (c2["reactions"] as Dictionary).is_empty(), str(c2["reactions"]))
	var c3: Dictionary = JobModel.read_job(dir_of("c3-reacted"), 0.0)
	var r: Dictionary = c3["reactions"]
	check.call("create.model: c3 reactions: player -> tiny, orca keep with its note, cannon drop", r.size() == 3 and r["player"]["choice"] == "tiny" and r["orca"]["note"] == "make the orca funny, not scary" and r["cannon"]["choice"] == "drop", str(r))
	var c4: Dictionary = JobModel.read_job(dir_of("c4-redesigned"), 0.0)
	check.call("create.model: c4 a redesign's brief_set clears the reactions to the old brief (2 briefs, 5 aspects, 0 reactions)", int(c4["briefs"]) == 2 and (c4["aspects"] as Array).size() == 5 and (c4["reactions"] as Dictionary).is_empty())
	var iceberg: Dictionary = (c2["aspects"] as Array)[2]
	var walk: PackedStringArray = ["keep"]
	for i: int in 5:
		walk.append(Model.next_choice(iceberg, walk[walk.size() - 1]))
	check.call("create.model: one tap walks keep -> floes -> bowl -> ship -> drop -> keep", walk == PackedStringArray(["keep", "floes", "bowl", "ship", "drop", "keep"]), str(walk))
	var taps: Dictionary = {"player": {"choice": "tiny"}, "orca": {"choice": "keep", "note": "make the orca funny, not scary"}, "rivals": {"choice": "keep"}, "cannon": {"choice": "jet"}}
	var p2: Array = Model.pending(c2, taps)
	var p3: Array = Model.pending(c3, taps)
	check.call("create.model: pending sends only what the log lacks (c2: 3 of 4 taps, c3: only cannon)", str(p2) == str([["player", "tiny", ""], ["orca", "keep", "make the orca funny, not scary"], ["cannon", "jet", ""]])
		and str(p3) == str([["cannon", "jet", ""]]), "c2 %s; c3 %s" % [str(p2), str(p3)])
	var s5: Array = Model.strip(JobModel.read_job(dir_of("c5-building"), 0.0))
	var s6j: Dictionary = JobModel.read_job(dir_of("c6-phase-done"), 0.0)
	var s7: Array = Model.strip(JobModel.read_job(dir_of("c7-held"), 0.0))
	var s8: Array = Model.strip(JobModel.read_job(dir_of("c8-phase2"), 0.0))
	var states: Callable = func(s: Array) -> String: return ",".join(s.map(func(e: Dictionary) -> String: return "%s:%d/%d" % [e["state"], e["done"], e["total"]]))
	var want: Array = [[s5, "building:1/2,next:0/2,next:0/1"], [Model.strip(s6j), "done:2/2,next:0/2,next:0/1"], [s7, "held:1/2,next:0/2,next:0/1"], [s8, "passed:2/2,building:1/2,next:0/1"]]
	var got: PackedStringArray = []
	var ok: bool = true
	for w: Array in want:
		got.append(states.call(w[0]))
		ok = ok and states.call(w[0]) == w[1]
	check.call("create.model: the phase strip of c5, c6, c7, c8 (state:done/total per phase)", ok, " | ".join(got))
	check.call("create.model: c6 waits on phase slide (paused, reason phase) and says what to try", s6j["pause_kind"] == "phase" and Model.waiting(s6j).get("id", "") == "slide"
		and str(Model.waiting(s6j).get("try", "")).begins_with("Slide your penguin"))
	check.call("create.model: c7 the held phase carries the player's note", str(s7[0]["note"]) == "the penguin turns too slowly, make the brake snappier")
	var c12: Dictionary = JobModel.read_job(dir_of("c12-run-through"), 0.0)
	var autos: int = (c12["phase_events"] as Array).filter(func(e: Dictionary) -> bool: return e["type"] == "pass" and e["by"] == "auto").size()
	check.call("create.model: c12 run-through: 3 auto passes, every phase passed, never a pause on a phase", bool(c12["run_through"]) and autos == 3 and states.call(Model.strip(c12)) == "passed:2/2,passed:2/2,passed:1/1" and c12["pause_kind"] != "phase", "%d autos, %s" % [autos, states.call(Model.strip(c12))])
	check.call("create.model: phase line 'phase 2 of 3: Rivals and cracks' (c8)", Model.phase_line(JobModel.read_job(dir_of("c8-phase2"), 0.0)) == "phase 2 of 3: Rivals and cracks")
	# a job made before the designer v2 still reads: one phase, the brief's five parts as read-only cards
	var old: Array = []
	for e: Dictionary in events_of("c9-done"):
		var x: Dictionary = e.duplicate(true)
		match str(x["type"]):
			"job_created": x.erase("creativity")
			"brief_set":
				x.brief.erase("pitch")
				x.brief.erase("aspects")
			"plan_set": x.erase("phases")
		if not x["type"] in ["aspect_reacted", "phase_done", "phase_reviewed"]:
			old.append(x)
	var oj: Dictionary = JobModel.reduce(old, 0.0)
	var cards: Array = Model.cards_of(oj)
	check.call("create.model: a v1 job (no pitch, aspects, phases): one phase of 5 packages, 5 read-only cards, done", (oj["phases"] as Array).size() == 1 and int(Model.strip(oj)[0]["total"]) == 5
		and cards.size() == 5 and bool(cards[0]["read_only"]) and Model.screen_of(oj) == "done" and Model.phase_line(oj) == "", "%d phases, %d cards, %s" % [(oj["phases"] as Array).size(), cards.size(), Model.screen_of(oj)])


# ---------------------------------------------------------------- the command lines (JOB.md word for word)

static func _door(check: Callable, tmp: String) -> void:
	var d: Door = Door.new()
	d.setup(tmp, {"dry": true, "flags": {"new": ["--adapter", "fake"], "plan": ["--adapter", "fake"], "run": ["--adapter", "fake"], "resume": ["--adapter", "fake"]}})
	var job: String = dir_of("c6-phase-done")
	d.new_game("penguins pushing each other off an iceberg", {}, {}, [], {"creativity": "crazy", "run_through": true})
	d.new_game("robots", {}, {}, [], {"creativity": "standard"})
	d.redesign(job, [["player", "tiny", ""], ["orca", "keep", "make it \"funny\""]])
	d.approve_v2(job, [["cannon", "drop", ""]])
	d.phase(job, "pass", "", false)
	var busy_refused: String = d.phase(job, "hold", "brake\nsnappier", true)
	d.phase(job, "hold", "brake\nsnappier", false)
	var refused: String = d.phase(job, "hold", "  ", false)
	var bad_verdict: String = d.phase(job, "skip", "", false)
	var s: Array = d.dry_steps
	var want: Array = [
		[["new", "penguins pushing each other off an iceberg", "--site", tmp, "--adapter", "fake", "--creativity", "crazy", "--run-through"]],
		[["new", "robots", "--site", tmp, "--adapter", "fake"]],
		[["react", job, "player", "tiny"], ["react", job, "orca", "keep", "--note", "make it 'funny'"], ["redesign", job, "--adapter", "fake"]],
		[["react", job, "cannon", "drop"], ["approve", job], ["plan", job, "--adapter", "fake"], ["run", job, "--adapter", "fake"]],
		[["phase", job, "pass", "--adapter", "fake"]],
		[["phase", job, "hold", "--note", "brake snappier", "--adapter", "fake"]],
	]
	var wrong: PackedStringArray = []
	for i: int in want.size():
		if i >= s.size() or str(s[i]) != str(want[i]):
			wrong.append("call %d: %s" % [i, str(s[i]) if i < s.size() else "missing"])
	check.call("create.door: new --creativity crazy --run-through, react [--note], redesign, approve/plan/run, phase pass|hold --note: the JOB.md shapes", wrong.is_empty() and s.size() == want.size(), "; ".join(wrong))
	check.call("create.door: hold without a note, a verdict other than pass/hold, and a verdict while a Foreman holds the job start nothing",
		not refused.is_empty() and not bad_verdict.is_empty() and not busy_refused.is_empty() and s.size() == want.size(), "%s / %s / %s" % [refused, bad_verdict, busy_refused])
	var la: PackedStringArray = Dungeons.launch_args("C:/j/pack")
	check.call("create.door: Try it's process is L4's seam: dungeons.gd launch_args ends -- --dungeon=<dir> (the editor binary also gets --path <engine> res://boot/boot.tscn)",
		la.size() >= 2 and la[la.size() - 2] == "--" and la[la.size() - 1] == "--dungeon=C:/j/pack" and (OS.has_feature("thirdlife_exe") or la[2] == "res://boot/boot.tscn"), str(la))


# ---------------------------------------------------------------- the page itself, driven from the fixtures

static func _page(tree: SceneTree, check: Callable, tmp: String) -> void:
	var page: Control = CreateScene.instantiate()
	var stub: String = ProjectSettings.globalize_path(STUB)
	page.call("setup", {"jobs": tmp, "dry": true, "now": 1795289400.0, "try_stub": stub, "flags": {"new": ["--adapter", "fake"], "plan": [], "run": [], "resume": []}})
	await tree.process_frame              # the root is in the tree from the first frame on
	tree.root.add_child(page)
	page.call("open")
	var has: Callable = func(name: String) -> bool:
		var n: Node = page.find_child(name, true, false)
		return n != null and (n as CanvasItem).is_visible_in_tree()
	var words: Dictionary = {}
	# 1. idea
	var ok: bool = page.call("shown_screen") == "idea" and has.call("Sentence") and has.call("Go") and has.call("Standard") and has.call("Crazy") and has.call("Surprise") and has.call("Chip0") and not has.call("RunThrough")
	words["idea"] = int(Model.screen_words(page)["total"])
	(page.find_child("Crazy", true, false) as Button).pressed.emit()
	var crazy_line: String = (page.find_child("CreativityLine", true, false) as Label).text
	(page.find_child("Drawer", true, false) as Button).pressed.emit()
	ok = ok and has.call("RunThrough") and has.call("Recipe") and crazy_line == Model.CREATIVITY_LINE["crazy"]
	(page.find_child("RunThrough", true, false) as BaseButton).button_pressed = true
	(page.find_child("Surprise", true, false) as Button).pressed.emit()
	var said: String = str(page.get("sentence"))
	(page.find_child("Go", true, false) as Button).pressed.emit()
	var door: RefCounted = page.get("door")
	var steps: Array = door.get("dry_steps")
	check.call("create.page: idea: sentence, Go, Standard/Crazy with its line, surprise chips, the drawer closed until More; Go starts new --creativity crazy --run-through",
		ok and said == str(Model.SURPRISES[0][1]) and steps.size() == 1 and str(steps[0][0]) == str(["new", said, "--site", tmp, "--adapter", "fake", "--creativity", "crazy", "--run-through"])
		and page.call("shown_screen") == "designing", "steps %s, screen %s" % [str(steps), str(page.call("shown_screen"))])
	# the expert's recipe hint: the card's proposed answers (`--answers`, JOB.md 2026-11-19), the only card key of `new`
	page.call("new_idea")
	page.set("card_hint", "card.knock_down")
	page.set("sentence", "knock down a tower of crates")
	page.call("go")
	var hinted: Array = (door.get("dry_steps") as Array).back()[0]
	var at: int = hinted.find("--answers")
	var answers: Variant = JSON.parse_string(Marshalls.base64_to_utf8(str(hinted[at + 1]).trim_prefix("json64:"))) if at >= 0 else null
	check.call("create.page: the recipe hint (expert drawer) goes out as the card's proposed answers: new ... --answers {target, how, ...}",
		answers is Dictionary and (answers as Dictionary).get("target", "") == "wall" and (answers as Dictionary).get("how", "") == "throw", str(hinted))
	page.set("card_hint", "")
	# 2-6: each fixture
	var want: Dictionary = {"c1-designing": ["Thinking", "Clock"], "c2-pitch": ["Pitch", "Card_player", "Card_orca", "BuildIt", "Redesign"],
		"c5-building": ["Phase1", "Phase3", "TryLine", "Pkg_penguin_moves"], "c6-phase-done": ["TryIt", "Pass", "Hold", "Ready"],
		"c7-held": ["Phase1", "Pkg_penguin_moves"], "c8-phase2": ["Pkg_rivals_ai", "Pkg_cracks_orca"], "c9-done": ["Ready", "Play"],
		"c10-failed": ["FailCard", "TryAgain"], "c11-design-failed": ["FailCard"], "c12-run-through": ["Play"]}
	var wrong: PackedStringArray = []
	for n: String in want:
		page.call("show_job", dir_of(n))
		var shown: String = page.call("shown_screen")
		if shown != SCREENS[n]:
			wrong.append("%s shows %s" % [n, shown])
		for node: String in want[n]:
			if not has.call(node):
				wrong.append("%s lacks %s" % [n, node])
		words[n] = int(Model.screen_words(page)["total"])
	check.call("create.page: every fixture draws its screen with its controls (designing, pitch, building, phase done, done, failed)", wrong.is_empty(), "; ".join(wrong))
	# the 10-year-old path: tap tap, Build it
	page.call("show_job", dir_of("c2-pitch"))
	var base: int = (door.get("dry_steps") as Array).size()
	(page.find_child("Card_player", true, false) as Button).pressed.emit()
	(page.find_child("Card_player", true, false) as Button).pressed.emit()
	var face: String = (page.find_child("Card_player", true, false).find_child("CardTitle", true, false) as Label).text
	for i: int in 3:
		(page.find_child("Card_cannon", true, false) as Button).pressed.emit()
	(page.find_child("BuildIt", true, false) as Button).pressed.emit()
	var j: String = dir_of("c2-pitch")
	var built: Array = (door.get("dry_steps") as Array).slice(base)
	check.call("create.page: tap tap shows the alternative (Tiny rockhopper); Build it writes the reactions, then approve, plan, run",
		face == "Tiny rockhopper" and built.size() == 1 and str(built[0]) == str([["react", j, "player", "tiny"], ["react", j, "cannon", "drop"], ["approve", j], ["plan", j], ["run", j]])
		and page.call("shown_screen") == "building", "%s; %s" % [face, str(built)])
	# Tell me more: the detail, a direct pick, the expert's note; Redesign sends them
	page.call("show_job", dir_of("c2-pitch"))
	(page.find_child("More_orca", true, false) as Button).pressed.emit()
	var detail_ok: bool = has.call("Detail") and has.call("Pick_seals") and has.call("Note")
	(page.find_child("Pick_seals", true, false) as Button).pressed.emit()
	var note: LineEdit = page.find_child("Note", true, false)
	note.text = "seals in tiny hats"
	note.text_changed.emit(note.text)
	(page.find_child("SheetDone", true, false) as Button).pressed.emit()
	base = (door.get("dry_steps") as Array).size()
	(page.find_child("Redesign", true, false) as Button).pressed.emit()
	var red: Array = (door.get("dry_steps") as Array).slice(base)
	check.call("create.page: Tell me more shows the detail and every choice; a pick and a note go out with Redesign (react ... --note, redesign)",
		detail_ok and red.size() == 1 and str(red[0]) == str([["react", j, "orca", "seals", "--note", "seals in tiny hats"], ["redesign", j, "--adapter", "fake"]]) and page.call("shown_screen") == "designing", str(red))
	# phase done: Try it, Pass, Hold + note
	var j6: String = dir_of("c6-phase-done")
	page.call("show_job", j6)
	(page.find_child("TryIt", true, false) as Button).pressed.emit()
	var launch: PackedStringArray = page.get("last_launch")
	base = (door.get("dry_steps") as Array).size()
	(page.find_child("Pass", true, false) as Button).pressed.emit()
	var passed: Array = (door.get("dry_steps") as Array).slice(base)
	page.call("show_job", j6)
	(page.find_child("Hold", true, false) as Button).pressed.emit()
	var hold_box: bool = has.call("HoldNote") and has.call("SendHold") and not has.call("Pass")
	words["hold-note"] = int(Model.screen_words(page)["total"])
	(page.find_child("SendHold", true, false) as Button).pressed.emit()
	var empty_hold: int = (door.get("dry_steps") as Array).size()
	(page.find_child("HoldNote", true, false) as LineEdit).text = "the brake is too slow"
	(page.find_child("SendHold", true, false) as Button).pressed.emit()
	var held: Array = (door.get("dry_steps") as Array).slice(empty_hold)
	check.call("create.page: phase done: Try it launches --dungeon (the stub pack: the fixture has no pack/); Pass = phase pass (it builds on); Hold opens a note box, an empty note sends nothing",
		launch == Dungeons.launch_args(stub) and str(passed) == str([[["phase", j6, "pass"]]])
		and hold_box and empty_hold == base + 1 and str(held) == str([[["phase", j6, "hold", "--note", "the brake is too slow"]]]), "launch %s; pass %s; hold %s" % [str(launch), str(passed), str(held)])
	# words on each screen (reported; the 10-year-old path stays short)
	var path_words: int = int(words["idea"]) + int(words["c2-pitch"]) + int(words["c5-building"])
	check.call("create.page: words on screen idea %d, designing %d, pitch %d, building %d, phase done %d, hold %d, done %d, failed %d" % [words["idea"], words["c1-designing"], words["c2-pitch"], words["c5-building"],
		words["c6-phase-done"], words["hold-note"], words["c9-done"], words["c10-failed"]], int(words["idea"]) <= 45 and int(words["c1-designing"]) <= 20 and int(words["c9-done"]) <= 15 and int(words["c6-phase-done"]) <= 45, "path %d" % path_words)
	page.queue_free()


# ---------------------------------------------------------------- the village site's sign line

static func _site(check: Callable) -> void:
	var want: Dictionary = {"c4-redesigned": "", "c5-building": "phase 1 of 3: Slide and bump", "c6-phase-done": "phase 1 of 3: Slide and bump",
		"c7-held": "phase 1 of 3: Slide and bump", "c8-phase2": "phase 2 of 3: Rivals and cracks", "c9-done": "", "c12-run-through": ""}
	var wrong: PackedStringArray = []
	for n: String in want:
		var lg: RefCounted = SiteLog.new()
		lg.call("feed", FileAccess.get_file_as_string(dir_of(n).path_join("job.jsonl")))
		var got: String = str(SiteScript.phase_of(lg.get("events")).get("line", ""))
		if got != want[n]:
			wrong.append("%s: '%s'" % [n, got])
	check.call("create.site: the sign's phase line from the log (phase n of m: <title>; none before the plan or after the last pass)", wrong.is_empty(), "; ".join(wrong))
