extends RefCounted
const Model = preload("res://ui/editor/editor_model.gd")
const Scorer = preload("res://ui/editor/lot_scorer.gd")
const PlacePanel = preload("res://ui/editor/place_panel.gd")

const Workbench = preload("res://ui/editor/workbench.gd")

class WorkbenchStub extends Workbench:
	func refresh() -> void:
		_place_if_needed()


static func run(t: SceneTree, tmp: String) -> void:
	var m := Model.new()
	m.load_all()
	m.set_sentence("ice hockey, three against three")
	m.answer("rink", "small")
	m.answer("dressing", "bare")
	var flat := func(_x: float, _z: float) -> float: return 0.0
	var slope := func(x: float, _z: float) -> float: return 0.1 * x
	var best := Vector2(-207, 44)
	var bank := Scorer.score(m, Vector2(-250, -30), 0, flat)
	t.check("place: a ring in the river is refused", not bank.valid and str(bank.lines).contains("river"))
	var over := Scorer.score(m, Vector2(194, 61), 0, flat)
	t.check("place: overlap names the hockey plot and the distance", not over.valid and str(over.lines).contains("hockey") and str(over.lines).contains(" m"))
	var level := Scorer.score(m, best, 0, flat)
	var tilted := Scorer.score(m, best, 0, slope)
	t.check("place: a flat pad loses no ground points, a tilted pad does", level.valid and tilted.valid and level.lines[1].points == 0 and tilted.lines[1].points > 0)
	# Round 2: the Designer only when the words name a place; otherwise the editor's own three measured places
	var neutral := ["ice hockey, three against three", "knock down a tower of crates with balls", "a car race, three laps against the clock",
		"an arena where I fight waves of goblins with a sword", "a frozen pond rink with trees", "football on grass, five a side"]
	var placed := {"a quiet rink": ["quiet"], "hockey by the river": ["river", "by the"], "a rink next to the other hockey": ["next to"],
		"a slalom on the hill, far from the road": ["far from", "hill"], "an arena in the middle of the village": ["middle"]}
	var words_ok := true
	for sentence: String in neutral:
		words_ok = words_ok and PlacePanel.place_words(sentence).is_empty()
	for sentence: String in placed:
		words_ok = words_ok and Array(PlacePanel.place_words(sentence)) == placed[sentence]
	t.check("place: the Designer is asked only for words that name a place (%d neutral, %d placed)" % [neutral.size(), placed.size()], words_ok)
	var mine: Array = PlacePanel.measured_proposals(m)
	var ids: Array = mine.map(func(p: Dictionary) -> String: return p.candidate)
	var top3: Array = Scorer.candidates(m, m.heights, 3).map(func(c: Dictionary) -> String: return c.id)
	t.check("place: no place words -> the scorer's top three, worded from their facts, no model call", ids == top3 and ids.size() == 3 and
		mine.all(func(p: Dictionary) -> bool: return p.reason.contains(" m walk from") and p.reason.length() < 120 and p.reason.count("next to") <= 1) and PlacePanel.valid_answer({"schema": "tl.place-answer/1", "proposals": mine, "adapter": "fake", "model": "editor", "durationMs": 0}), str(mine))
	# Round 3: "next to walker" is not a walk fact (a 43 m ring's third place had walker twice in its reason)
	m.answer("rink", "standard")
	var bigger: Array = PlacePanel.measured_proposals(m)
	t.check("place: a measured reason names one walk and at most one neighbour", bigger.size() == 3 and bigger.all(func(p: Dictionary) -> bool:
		return p.reason.count(" m walk from") == 1 and p.reason.count("next to") <= 1), str(bigger))
	m.answer("rink", "small")
	var a := {"at": [best.x, best.y], "yaw_deg": 0, "reason": "short walk"}
	var b := {"at": [347, -80], "yaw_deg": 15, "reason": "long walk"}
	var c := {"at": [-250, -30], "yaw_deg": 0, "reason": "river"}
	var ordered := Scorer.rank(m, [b,c,a], flat)
	t.check("place: ranking is stable over three input orders", ordered == Scorer.rank(m, [c,a,b], flat) and ordered == Scorer.rank(m, [a,b,c], flat) and ordered[0].at == best and not ordered[-1].valid)
	m.answer("rink", "big")
	t.check("place: a larger footprint can invalidate a previously fitting proposal", not Scorer.score(m, best, 0, flat).valid)
	m.answer("rink", "small")
	var stub := WorkbenchStub.new()
	stub.jobs_root = tmp
	stub.model = m
	var panel := PlacePanel.new()
	panel.wb = stub
	panel.status = Label.new()
	panel.add_child(panel.status)
	var started := Time.get_ticks_usec()
	var measured := Scorer.candidates(m, m.heights)
	print("[selftest] candidate sweep: %.2f ms, %d places" % [(Time.get_ticks_usec() - started) / 1000.0, measured.size()])
	t.check("place: deterministic measured candidate list", measured == Scorer.candidates(m, m.heights) and measured.size() == 10)
	var centres := PackedVector2Array()
	var valid := true
	var diverse := true
	var facts_match := true
	for i in measured.size():
		var site: Dictionary = measured[i]
		var centre := Vector2(site.at[0], site.at[1])
		var verified := Scorer.score(m, centre, 0, m.heights)
		valid = valid and verified.valid and verified.score == site.score and site.id == String.chr(65+i)
		facts_match = facts_match and ("%.0f m walk from the gate to the road" % verified.path.length_m) in site.facts
		for earlier in centres:
			diverse = diverse and centre.distance_to(earlier) >= maxf(40, m.lot_radius())
		centres.append(centre)
	t.check("place: measured candidates have valid scores and sequential ids", valid)
	t.check("place: measured candidates are separated by at least the ring or 40 m", diverse)
	t.check("place: candidate path facts match the live scorer", facts_match)
	var expected := centres[0] if not centres.is_empty() else Vector2.INF
	m.sentence = "ice hockey, three against three by the river"   # words that name a place: the Designer is asked (and its door fails)
	panel._find()
	m.sentence = "ice hockey, three against three"
	t.check("place: failed door takes candidate A and explains it", m.placed and m.at == expected and panel.status.text.contains("best measured free place") and panel.status.text.contains("Foreman"))
	m.answer("dressing", "arena")
	stub.refresh()
	t.check("place: answering after a fallback resumes automatic roadside placement", m.at == m.first_free())
	m.answer("dressing", "bare")
	panel.free()
	stub.free()
	t.check("place: square placement has no turn notice", m.yaw_note().is_empty())
	m.turn(-1)
	t.check("place: a turn is explained and kept in the draft", m.yaw_note() == "Turned -15°: the game stands turned on its lot; its gate still faces the road." and m.draft().lot.yaw_deg == -15)
	m.plots = [{"id":"yard","label":"parkour yard","kind":"plot","at":Vector2(14, 30),"r":12.0}]
	m.road_samples = PackedVector2Array([Vector2(-100,0),Vector2.ZERO,Vector2(100,0)])
	m.river_samples.clear()
	var path := Scorer.score(m, Vector2(0,100), 0, flat)
	t.check("place: a path outside the parkour radius but across its lot edge is refused", not path.valid and path.lines[0].text == "the path crosses parkour yard's lot")
	m.plots = [{"id":"paddle","label":"paddle","kind":"plot","at":Vector2.ZERO,"r":40.0}]
	# End the spur away from paddle, with the road itself well clear of both lots.
	m.road_samples = PackedVector2Array([Vector2(50,-100),Vector2(81.2,-100),Vector2(120,-100)])
	var crossed := Scorer.score(m, Vector2(77.6,0), 0, flat)
	t.check("place: a 5.6 m gap between radii overlaps paddle by 1.6 m", not crossed.valid and crossed.lines[0].text == "its edge would cross paddle's by 1.6 m")
	var touching := Scorer._score(m, Vector2(81.2,0), 0, flat, 32, true)
	t.check("place: a 9.2 m gap between radii leaves exactly 2 m between lots", touching.valid and "next to paddle (2 m between lots)" in touching.get("facts", []))
	# A centre just inside the legal margin can round onto the wrong side when written to the job.
	m.plots[0].at = Vector2(0.03,0)
	m.place(Vector2(81.24,0))
	t.check("place: a dragged boundary lot keeps its fitting centre in the draft", m.fits() and m.draft().lot.at == [m.at.x, m.at.y])
	m.plots.clear()
	m.road_samples = PackedVector2Array([Vector2(-100,0),Vector2.ZERO,Vector2(100,0)])
	m.river_samples = PackedVector2Array([Vector2(-20,30),Vector2(20,30)])
	path = Scorer.score(m, Vector2(0,100), 0, flat)
	t.check("place: a clear pad with a path across the river is refused", not path.valid and str(path.lines).contains("path crosses the river"))
	m.river_samples.clear()
	t.check("place: the lot edge needs 1 m off the road edge", Scorer.score(m, Vector2(0,39.6), 0, flat).valid and not Scorer.score(m, Vector2(0,39.5), 0, flat).valid)
	m.river_samples = PackedVector2Array([Vector2(-50,100),Vector2(50,100)])
	t.check("place: the lot edge needs 2 m off the riverbank", Scorer.score(m, Vector2(0,56.4), 0, flat).valid and not Scorer.score(m, Vector2(0,56.5), 0, flat).valid)
	m.river_samples.clear()
	t.check("place: the lot edge can touch the village bounds", Scorer.score(m, Vector2(0,114.4), 0, flat).valid and not Scorer.score(m, Vector2(0,114.5), 0, flat).valid)
