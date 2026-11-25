extends Node
## The screen's show rules, headless (lane K5). Two parts.
## A. thirdjam's own assertions on the pure rules, case for case (HUDControlsPanelTests.cpp:84-128, 395-441;
##    HUDPossessionTests.cpp:25-35; CameraTests.cpp:314-316, 1035-1042; CarrierCueTests.cpp:48-53): same inputs, same answers.
## B. Two recorded matches: a second RinkCore of the same cartridge and level, its human played by thirdjam's own playerbot
##    (set_human_mode "playerbot"), then by its regular playtester ("playtester:regular"), every snapshot fed to the pack's hud.gd through a layer that records instead of
##    drawing (a fixed top-down projection, 1920 x 1080 units). Frame by frame the rules are checked against the snapshot
##    itself: the MATCH card up from the build to the drop and 150 frames after a take changes; the markers standing down
##    under it and on the end card; the YOU tag only while a faceoff counts; the dial's words (digit + HOLD, DROP for 30
##    frames, WON / LOST for 40); the panel only in play, its half by the swap rule; the take = 1 + the lead; the possession
##    shown = the sim's carrier.
##    Round 5 (the core's Controls v1.2): the panel's half by ButtonsWithPuck through the swap rule; the take grace's ring from
##    its first frame (CarrierInTakeGrace with TakeGraceLeft still 0: the full count, 1.5 x unless won by a hit); the pass's
##    target ring only while the pass is held (under Controls.PassTargetHeld, thirdjam's HumanPassTarget) or flies (45 frames at most, PassBy = him); the
##    teaching pulse's limits (3 a kind, 90 frames, 900 apart, never after he did it, not counting, not down, not in the
##    draw's first 60 frames; the panel's row lit with it).

var R                     # scripts/hud/rules.gd, hud.gd, cards.gd (ctx.load_script: a test reaches the pack's scripts through ctx)
var Hud
var Cards
var Flow
const FRAMES: int = 36000

var ctx
var fails: Array = []
var checks: int = 0
var done: bool = false
var core
var hud
var lay
var stats: Dictionary = {"frames": 0, "card": 0, "count": 0, "drop": 0, "result": 0, "panel": 0, "goal_pause": 0, "you": 0, "mate": 0, "opponent": 0, "loose": 0, "end": 0}
var prev_count: int = 0
var card_should: bool = true
var card_until: int = 150
var card_seen: bool = false
var take: int = 1
var last_phase: int = -1
var drop_left: int = 0
var result_left: int = 0
var last_snap: Dictionary = {}
var tail: int = 0
var end_age: int = 0                                # drawn frames of the end phase before this one
var booth: Dictionary = {"lines": 0, "gate_ok": 0, "last_start": -1000000, "stop_ok": 0}
var goals_seen: int = 0
var bark_stats: Dictionary = {"barks": 0, "lane": 0, "last": -1000000, "speaker": {}, "yield_until": -1000000, "held_ok": 0}
var banner_frames: int = 0
var end_wait_ok: bool = false
var end_card_seen: bool = false
var swap_mirror: Dictionary = {}
const MODES: Array = ["playerbot", "playtester:regular"]
var match_i: int = 0
var match_frames: int = 0
var r5: Dictionary = {"with_loose": 0, "panel_with": 0, "panel_without": 0, "grace": 0, "grace_first": 0, "grace_first_hit": 0,
	"ring_held": 0, "ring_flight": 0, "teach_pass": 0, "teach_hit": 0, "teach_frames": 0, "teach_row": 0}
var pass_seen: int = -1
var pass_at: int = -1000000
var drop_at: int = -1000000
var teach_mem: Array = [{"at": -1, "end": -1000000, "done_at": -1}, {"at": -1, "end": -1000000, "done_at": -1}]


## A layer that keeps what it was asked to draw (no Control, no camera): a top-down view, 20 units a metre round centre ice.
class Rec:
	extends RefCounted
	var ops: Array = []
	func clear() -> void: ops.clear()
	func extent() -> Vector2: return Vector2(1920, 1080)
	func measure(s: String, pt: float, _face: String = "bold", _tr: int = 0) -> Vector2: return Vector2(s.length() * pt * 0.6, pt * 4.0 / 3.0 * 1.17)
	func box(_p: Vector2, _s: Vector2, _f: Color, _r: float = 0.0, _e: Color = Color(), _ew: float = 0.0, _a: float = 0.0) -> void: ops.append("box")
	func text(p: Vector2, s: String, pt: float, _c: Color, _o: Dictionary = {}) -> Rect2:
		ops.append("text:" + s)
		return Rect2(p, measure(s, pt))
	func ring(_r: Rect2, _c: Color, _b: float = 0.0, _e: float = 0.0, _ec: Color = Color()) -> void: ops.append("ring")
	func chevron(_p: Vector2, _s: float, _c: Color, _e: Color = Color(), _ew: float = 0.0, _a: float = 0.0, _al: Vector2 = Vector2()) -> void: ops.append("chevron")
	func polygon(_p: PackedVector2Array, _c: Color) -> void: pass
	func line(_a: Vector2, _b: Vector2, _c: Color, _w: float = 1.0) -> void: pass
	func minimap(_p: Vector2, _s: Vector2, _f: Vector2, _d: Array) -> void: ops.append("minimap")
	func project(w: Vector3) -> Vector3: return Vector3(960.0 + w.x * 20.0, 540.0 + w.z * 20.0, 30.0)
	func camera_local(w: Vector3) -> Vector3: return Vector3(w.x, w.z, -30.0)
	func eye() -> Vector3: return Vector3(0, 30, 0)
	func ground_ring(c: Vector3, r: float, _n: float = 0.5) -> Rect2: return Rect2(Vector2(960.0 + (c.x - r) * 20.0, 540.0 + (c.z - r) * 20.0), Vector2(r, r) * 40.0)


func _bot_setup(c) -> void:
	ctx = c
	R = ctx.load_script("scripts/hud/rules.gd")
	Hud = ctx.load_script("scripts/hud/hud.gd")
	Cards = ctx.load_script("scripts/hud/cards.gd")
	Flow = ctx.load_script("scripts/hud/flow.gd")


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok and fails.size() < 12:
		fails.append(what)


func _part_a() -> void:
	# HUDControlsPanelTests.cpp:84-112: the rows from the default bindings
	_check(_line(R.panel_rows(true, false, {}, false, false)) == "LMB SHOOT | RMB PASS | WHEEL DEKE | E SPIN | WASD SKATE | SHIFT SPRINT | CTRL BRAKE", "rows with the puck")
	_check(_line(R.panel_rows(true, true, {}, false, false)).ends_with(" | F ABILITY"), "an ability held: its row last")
	_check(_line(R.panel_rows(true, false, {"Pass": true}, false, false)) == "LMB SHOOT | RMB PASS* | WHEEL DEKE | E SPIN | WASD SKATE | SHIFT SPRINT | CTRL BRAKE", "RMB held with the puck: PASS lights")
	_check(_line(R.panel_rows(true, false, {"Pass": true}, true, false)).contains("RMB SAUCER*"), "held to a saucer: SAUCER")
	_check(_line(R.panel_rows(false, false, {"CrossCheck": true, "Skate": true, "Sprint": true}, false, false)) == "LMB CROSS-CHECK* | RMB CHECK | SPACE POKE | WASD SKATE* | SHIFT SPRINT* | CTRL BRAKE", "LMB held without the puck, skating, sprinting")
	_check(_line(R.panel_rows(false, false, {"CrossCheck": true}, false, true)).contains("LMB BRACED*"), "held to a brace: BRACED")
	_check(not _line(R.panel_rows(true, false, {"CrossCheck": true}, false, false)).contains("LMB SHOOT*"), "a held cross-check does not light the puck's half")
	for w: bool in [true, false]:
		for ab: bool in [true, false]:
			var n: int = R.panel_rows(w, ab, {}, false, false).size()
			_check(n >= 6 and n <= R.PANEL_MAX_ROWS, "six to eight rows")
	# HUDControlsPanelTests.cpp:250-256
	_check(R.show_controls_panel("play", false, false), "play: shown")
	_check(not R.show_controls_panel("play", true, false), "paused: hidden")
	_check(not R.show_controls_panel("play", false, true), "GOAL banner: hidden")
	_check(not R.show_controls_panel("goal_pause", false, false), "goal pause: hidden")
	_check(not R.show_controls_panel("win", false, false) and not R.show_controls_panel("lose", false, false), "end card: hidden")
	# HUDControlsPanelTests.cpp:395-441: the swap
	for settled: bool in [true, false]:
		var st: Dictionary = {}
		for f: int in 100:
			R.panel_swap_step(st, settled, false, f)
		var swaps: int = 0
		for f: int in range(100, 160):
			swaps += 1 if R.panel_swap_step(st, ((f - 100) / 2) % 2 == (1 if settled else 0), false, f) else 0
		_check(swaps <= 1, "a flicker after a settled half draws at most one swap (%d)" % swaps)
		var nst: Dictionary = {}
		for f: int in 100:
			R.panel_swap_step(nst, settled, false, f, 0)
		var nsw: int = 0
		for f: int in range(100, 160):
			nsw += 1 if R.panel_swap_step(nst, ((f - 100) / 2) % 2 == (1 if settled else 0), false, f, 0) else 0
		_check(nsw >= 29, "hold 0 follows every flip (%d)" % nsw)
	var s1: Dictionary = {}
	for f: int in 100:
		R.panel_swap_step(s1, true, false, f)
	var at: int = -1
	for f: int in range(100, 140):
		if at < 0 and R.panel_swap_step(s1, false, false, f):
			at = f
	_check(at == 112, "a clean loss swaps at frame 112 (%d)" % at)
	var s2: Dictionary = {}
	for f: int in 100:
		R.panel_swap_step(s2, true, false, f)
	at = -1
	for f: int in range(100, 140):
		if at < 0 and R.panel_swap_step(s2, false, f == 103, f):
			at = f
	_check(at == 103 and int(s2["shown"]) == 0, "a press while without swaps on its frame (103)")
	_check(not R.panel_swap_step(s2, true, false, 105), "regaining 2 frames later: held")
	_check(R.panel_swap_step(s2, true, true, 106) and int(s2["shown"]) == 1, "a press on the puck forces WITH")
	var s3: Dictionary = {}
	for f: int in 100:
		R.panel_swap_step(s3, false, false, f)
	_check(R.panel_swap_step(s3, true, false, 100) and int(s3["shown"]) == 1, "gaining swaps on that frame")
	var s4: Dictionary = {}
	for f: int in 100:
		R.panel_swap_step(s4, true, false, f)
	R.panel_swap_step(s4, false, false, 0)
	_check(int(s4["shown"]) == 0, "a restart shows the truth at once")
	# HUDPossessionTests.cpp:25-33
	_check(R.possess_of(-1, 3, 0, 0) == 0 and R.possess_of(3, 3, 0, 0) == 1 and R.possess_of(4, 3, 0, 0) == 2 and R.possess_of(7, 3, 1, 0) == 3, "possess_of")
	_check(is_equal_approx(R.possess_pulse_scale(0), 1.0 + R.POSSESS_PULSE_GROW) and R.possess_pulse_scale(-1) == 1.0 and R.possess_pulse_scale(R.POSSESS_PULSE_FRAMES) == 1.0, "the pulse's ends")
	for a: int in range(1, R.POSSESS_PULSE_FRAMES + 1):
		_check(R.possess_pulse_scale(a) < R.possess_pulse_scale(a - 1), "the pulse only shrinks")
	# CameraTests.cpp:314-316, 1035-1041
	_check(R.ring_alpha_at(10.0) == 1.0 and R.ring_alpha_at(22.0) == 0.5 and R.ring_alpha_at(24.0) == 0.0, "ring alpha by distance")
	_check(R.ring_down_alpha(false, 500, -1) == 1.0 and R.ring_down_alpha(true, 500, -1) == 0.0 and R.ring_down_alpha(true, 500, 400) == 0.0, "ring down")
	_check(is_equal_approx(R.ring_down_alpha(false, 600, 600), 1.0 / R.RING_BACK_FRAMES) and R.ring_down_alpha(false, 605, 600) == 0.5 and R.ring_down_alpha(false, 612, 600) == 1.0 and R.ring_down_alpha(false, 10, 600) == 1.0, "ring back after the get-up")
	# CarrierCueTests.cpp:48-53
	_check(R.take_grace_ring_scale(30, 30) == 1.5 and R.take_grace_ring_scale(15, 30) == 1.25 and R.take_grace_ring_scale(0, 30) == 1.0 and R.take_grace_ring_scale(5, 0) == 1.0 and R.take_grace_ring_scale(90, 30) == 1.5, "the take grace's ring")
	# h:148, h:1184, cpp:431-435
	_check(R.box_plate_text(61) == "IN THE BOX  2" and R.box_plate_text(0) == "", "IN THE BOX")
	_check(R.own_label_text(24) == "OWN  24 M", "OWN  24 M")
	_check(R.format_timer(3601) == "1:01" and R.format_timer(0) == "0:00", "timer")
	# Jam.Hud.GoalBanner (HUDGoalBanner.cpp:258-276)
	_check(Flow.banner_alpha_at(-1, 120) == 0.0 and Flow.banner_alpha_at(0, 120) < 0.1 and Flow.banner_alpha_at(11, 120) == 1.0 and Flow.banner_alpha_at(60, 120) == 1.0, "banner in and held")
	_check(Flow.banner_alpha_at(108, 120) < 1.0 and Flow.banner_alpha_at(108, 120) > 0.0 and Flow.banner_alpha_at(114, 120) == 0.0 and Flow.banner_alpha_at(120, 120) == 0.0, "banner out, gone by 114")
	_check(Flow.banner_alpha_at(12, 30) > 0.99 and Flow.banner_alpha_at(30, 30) == 0.0, "a short pause: thirds")
	_check(Flow.banner_centre_y(-1.0, -1.0) == 0.30 and Flow.banner_centre_y(0.45, 0.70) == 0.30 and Flow.banner_centre_y(0.33, 0.55) == 0.205 and Flow.banner_centre_y(0.26, 0.31) == 0.205, "banner band")
	# the end card's words (cpp:446-467)
	_check(Flow.end_card_word("win", 3, 1) == "YOU WIN" and Flow.end_card_word("lose", 1, 3) == "BEATEN" and Flow.end_card_word("lose", 2, 2) == "NO WINNER", "end words")
	_check(Flow.end_card_score(3, 1) == "YOU  3 : 1  THEM", "end score line")
	# round 6: the MATCH card shows the level the shell applied (start_level's meta), not match.json's
	var ScreenS = ctx.load_script("scripts/hud/screen.gd")
	var had_meta: bool = ctx.root.has_meta(&"hokej_level")
	var old_meta = ctx.root.get_meta(&"hokej_level") if had_meta else null
	ctx.root.remove_meta(&"hokej_level")
	_check(ScreenS.applied_level(ctx, "pro") == "pro", "no level applied: match.json's stands")
	for lv: Array in [["rookie", "ROOKIE"], ["pro", "PRO"], ["all_star", "ALL-STAR"]]:
		ctx.root.set_meta(&"hokej_level", lv[0])
		var cd = Cards.new({}, "pro")
		cd.set_level(ScreenS.applied_level(ctx, "pro"))
		_check(cd.sub_line().ends_with(String(lv[1])), "the MATCH card shows the applied level %s: %s" % [lv[0], cd.sub_line()])
	ctx.root.remove_meta(&"hokej_level")
	if had_meta:
		ctx.root.set_meta(&"hokej_level", old_meta)
	# Jam.Hud.Teach (HUDPossessionTests.cpp:150-191): TeachStep case for case
	var ts: Dictionary = {}
	var on_frames: int = 0
	var starts: int = 0
	var was: bool = false
	for f: int in 20000:
		var on: bool = R.teach_step(ts, true, false, f)
		on_frames += 1 if on else 0
		starts += 1 if on and not was else 0
		was = on
	_check(starts == R.TEACH_MAX_SHOWS and on_frames == R.TEACH_MAX_SHOWS * R.TEACH_SHOW_FRAMES, "teach: due all match: 3 showings of 90 frames (%d, %d)" % [starts, on_frames])
	var t2: Dictionary = {}
	_check(R.teach_step(t2, true, false, 100) and not R.teach_step(t2, true, true, 110), "teach: he did it: the pulse ends")
	var again: bool = false
	for f: int in range(111, 20000):
		again = R.teach_step(t2, true, false, f) or again
	_check(not again, "teach: never again after he has done it")
	var t3: Dictionary = {}
	R.teach_step(t3, false, true, 5)
	var any3: bool = false
	for f: int in range(6, 5000):
		any3 = R.teach_step(t3, true, false, f) or any3
	_check(not any3, "teach: done before due: never shown")
	var t4: Dictionary = {}
	R.teach_step(t4, true, false, 5000)
	for f: int in range(5001, 5100):
		R.teach_step(t4, false, false, f)
	_check(R.teach_step(t4, true, false, 10) and int(t4["shows"]) == 2, "teach: after a restart the second showing may come")


static func _line(rows: Array) -> String:
	var parts := PackedStringArray()
	for r: Dictionary in rows:
		parts.append("%s %s%s" % [r["key"], r["word"], "*" if r["lit"] else ""])
	return " | ".join(parts)


func _bot_tick(frame: int) -> void:
	if done:
		return
	if frame == 0:
		_part_a()
		_open_match()
		return
	if tail > 0:                                       # the match is over: the end phase's frames (the sim stands still)
		for i: int in 8:
			_end_tail()
		return
	for i: int in 8:                                   # eight sim frames a tick: a whole match fits the budget
		var going: bool = core.step()
		_feed(core.snapshot())
		if not going or match_frames >= FRAMES:
			if going:
				_next_match()                                # the frame budget, not the match's end: no end card to check
			else:
				tail = 1
			return


## Match 1: thirdjam's playerbot on the human (it never passes: the teaching pulses and the grace's first frames); match 2:
## thirdjam's regular playtester (it passes: the pass's target ring held and in flight). A new HUD each: a new session.
func _open_match() -> void:
	core = ctx.cores.open("rink", "hockey.regular.cartridge.json")
	core.set_difficulty(String((ctx.read_json("match.json") as Dictionary)["difficulty"]))
	core.set_human_mode(MODES[match_i])
	core.reset(ctx.seed)
	lay = Rec.new()
	hud = Hud.new(lay, (ctx.read_json("hockey.regular.cartridge.json") as Dictionary)["game"], "pro", ctx.seed, (ctx.read_json("hud_barks.json") as Dictionary)["lines"])
	match_frames = 0
	prev_count = 0
	card_until = 150
	card_seen = false
	take = 1
	last_phase = -1
	drop_left = 0
	result_left = 0
	tail = 0
	end_age = 0
	booth["last_start"] = -1000000
	bark_stats["last"] = -1000000
	bark_stats["yield_until"] = -1000000
	swap_mirror = {}
	pass_seen = -1
	pass_at = -1000000
	drop_at = -1000000
	teach_mem = [{"at": -1, "end": -1000000, "done_at": -1}, {"at": -1, "end": -1000000, "done_at": -1}]
	_feed(core.snapshot())


func _next_match() -> void:
	match_i += 1
	if match_i >= MODES.size():
		done = true
		return
	_open_match()


func _end_tail() -> void:
	# thirdjam's end card waits 1.9 s (114 of our frames) with the last goal's banner in the wait, then shows (HUDEndWait.cpp, HUDGoalBanner.cpp:173-179)
	hud.frame(last_snap, {"with_puck": false, "held": {}, "press": false, "saucer": false, "braced": false, "paused": false, "stamina01": 1.0})
	var sh: Dictionary = hud.shown
	if end_age < 114:
		_check(not sh.has("end_card"), "end age %d: the card during the wait" % end_age)
	elif end_age == 114:
		end_wait_ok = true
	if end_age >= 114:
		_check(sh.has("end_card"), "end tail %d: no card after the wait" % tail)
		if sh.has("end_card"):
			end_card_seen = true
			var sc: Array = last_snap["Score"]
			var me_t: int = int((last_snap["Skaters"][int(last_snap["HumanIndex"])] as Dictionary)["Team"])
			# GOALS counts the human's own goals (HUDEndStats.cpp:49 Hu.Goals; the first end frame counts, h:4e), not the team's
			var hu_end: Dictionary = last_snap["Skaters"][int(last_snap["HumanIndex"])]
			_check(String(sh["end_card"]).contains("GOALS %d" % int(hu_end.get("Goals", 0))), "the end card's GOALS is the human's own %d: %s" % [int(hu_end.get("Goals", 0)), String(sh["end_card"])])
			_check(String(sh["end_card"]).contains("YOU  %d : %d  THEM" % [int(sc[me_t]), int(sc[1 - me_t])]), "the end card's score line: %s" % String(sh["end_card"]))
	_check(not sh.has("panel") and not sh.has("far_badge"), "end tail %d: the panel or a badge on the end card" % tail)
	tail += 1
	end_age += 1
	if tail > 200:
		_next_match()


func _feed(snap: Dictionary) -> void:
	last_snap = snap
	var f: int = int(snap["Frame"])
	stats["frames"] += 1
	match_frames += 1
	var me: int = int(snap["HumanIndex"])
	var hu: Dictionary = snap["Skaters"][me]
	var phase: String = R.phase_of(snap)
	var count: int = int(snap["FaceoffCountdown"]) if int(snap["Phase"]) == 3 else 0
	var ctl: Dictionary = snap["Controls"]
	var with: bool = bool(ctl["ButtonsWithPuck"])
	var li: Dictionary = core.last_human_input()
	hud.frame(snap, {"with_puck": with, "hit_pressed": bool(li.get("bCheck", false)) or bool(li.get("bLift", false)), "held": {}, "press": false,
		"saucer": false, "braced": false, "paused": false, "stamina01": 1.0})
	var sh: Dictionary = hud.shown
	_round5(snap, sh, f, me, hu, ctl, with, phase, count)
	var end: bool = phase == "win" or phase == "lose"
	# the take: 1 + the lead, changed only on a Playing frame; the card 150 frames from a change, gone at the drop it counted down to
	var t: int = Cards.compute_take(snap["Score"], 3)
	var changed: bool = false
	if int(snap["Phase"]) == 0 and t != take:
		take = t
		changed = true
		card_until = f + 150
	var drop_now: bool = count <= 0 and prev_count > 0
	if changed:
		card_seen = false                                                 # a new card has seen no countdown yet (DirectorsCallWidget.cpp:728)
	if count > 0:
		card_seen = true
	elif card_seen and card_until > f:
		card_until = f                                                    # CardAtDrop: the countdown it saw is over (cpp:729-730)
	var card: bool = not end and f < card_until
	_check(sh.has("match_card") == card, "frame %d: MATCH card %s, rule says %s" % [f, str(sh.has("match_card")), str(card)])
	if card:
		stats["card"] += 1
		_check(not sh.has("far_badge") and not sh.has("own_badge") and not sh.has("puck_arrow"), "frame %d: a marker under the MATCH card" % f)
		_check(String(sh["match_card"]) == "PERIOD %d   -   FACEOFF   -   PRO" % take, "frame %d: the card's line %s" % [f, String(sh.get("match_card", ""))])
	_check(String(sh.get("period", "")) == ("PERIOD %d" % take) if phase != "win" and phase != "lose" else true, "frame %d: PERIOD %d on the plate" % [f, take])
	if end:
		_check(not sh.has("end_card"), "frame %d: the end card on the end's frame %d" % [f, end_age])
		end_age += 1
		stats["end"] += 1
		_check(not sh.has("far_badge") and not sh.has("own_badge") and not sh.has("puck_arrow"), "frame %d: a marker on the end card" % f)
	# the YOU tag: only while a faceoff counts
	_check(sh.has("you_tag") == (count > 0 and phase == "play"), "frame %d: YOU tag %s while count=%d" % [f, str(sh.has("you_tag")), count])
	# the dial
	for e: Dictionary in snap["Events"]:
		if String(e["Name"]) == "faceoff" and String(e["Kind"]) == "won":
			result_left = 40
	if count > 0 and phase == "play":
		stats["count"] += 1
		_check(String(sh.get("dial", "")) == "%d HOLD" % ceili(count / 60.0), "frame %d: the dial says %s at count %d" % [f, String(sh.get("dial", "")), count])
	elif result_left > 0 and phase == "play":
		stats["result"] += 1
		_check(String(sh.get("dial", "")) in ["WON", "LOST"], "frame %d: the draw's result %s" % [f, String(sh.get("dial", ""))])
	elif drop_left > 0 and phase == "play":
		stats["drop"] += 1
		_check(String(sh.get("dial", "")) == "DROP", "frame %d: DROP %s" % [f, String(sh.get("dial", ""))])
	if drop_now:
		drop_left = 30
	drop_left = maxi(0, drop_left - 1)
	result_left = maxi(0, result_left - 1)
	# the panel: only in play
	_check(sh.has("panel") == (phase == "play"), "frame %d: panel %s in %s" % [f, str(sh.has("panel")), phase])
	if sh.has("panel"):
		stats["panel"] += 1
	if phase == "goal_pause":
		stats["goal_pause"] += 1
	# possession as shown = the sim's carrier (the release aside)
	if sh.has("possess"):
		var p: String = sh["possess"]
		stats[p] += 1
		var carrier: int = int(snap["Carrier"])
		var want: String = "loose" if carrier < 0 else ("you" if carrier == me else ("mate" if int((snap["Skaters"][carrier] as Dictionary)["Team"]) == int(hu["Team"]) else "opponent"))
		_check(p == want or (want == "you" and p == "loose"), "frame %d: possession %s, carrier says %s" % [f, p, want])
	# the GOAL banner: only in the goal pause after a score grew; the panel and the badges stand down under it
	if sh.has("banner"):
		banner_frames += 1
		_check(phase == "goal_pause" or end, "frame %d: a banner outside a goal pause" % f)
		_check(not sh.has("panel") and not sh.has("far_badge") and not sh.has("puck_arrow"), "frame %d: the panel or a marker under the banner" % f)
	for e: Dictionary in snap["Events"]:
		if String(e["Name"]) == "goal":
			goals_seen += 1
	# the barks (BarkSystem.cpp): at most one each 240 frames, one speaker at most each 480; the lane never with a HUD line of words;
	# a bark at the human holds the booth 150 frames (no line starts then but a priority-5 call)
	if sh.has("bark_said"):
		bark_stats["barks"] += 1
		_check(f - int(bark_stats["last"]) >= 240, "frame %d: a bark %d frames after the last" % [f, f - int(bark_stats["last"])])
		bark_stats["last"] = f
		var sit: String = sh["bark_said"]
		if not (sit == "goal_against" or sit == "faceoff" or sit == "goal_for"):
			bark_stats["yield_until"] = f + 150
	if sh.has("bark"):
		bark_stats["lane"] += 1
		_check(not sh.has("caption") and not sh.has("faceoff_hint"), "frame %d: a bark in the lane with a HUD line of words" % f)
	if sh.has("line_started") and f < int(bark_stats["yield_until"]) and not sh.has("bark_said"):
		var pid: String = sh["line_started"]
		var pr: int = 0
		for x: Dictionary in hud.captions.lines:
			if x["id"] == pid:
				pr = int(x["priority"])
		_check(pr >= 5, "frame %d: line %s started inside a bark's hold" % [f, pid])
		bark_stats["held_ok"] += 1
	# the booth: a line starts only past the 150-frame gate unless it is a priority-5 call or a hit's call; a stoppage line only off play
	if sh.has("line_started"):
		booth["lines"] += 1
		var id: String = sh["line_started"]
		var l: Dictionary = {}
		for x: Dictionary in hud.captions.lines:
			if x["id"] == id:
				l = x
		var gap: int = f - int(booth["last_start"])
		var ok_gate: bool = gap >= 150 or int(l.get("priority", 0)) >= 5 or String(l.get("event", "")) in ["check", "knockdown"] or int(booth["last_start"]) < -1000
		_check(ok_gate, "frame %d: %s started %d frames after the last line" % [f, id, gap])
		if bool(l.get("stop", false)):
			_check(int(snap["Phase"]) != 0, "frame %d: stoppage line %s in play" % [f, id])
			booth["stop_ok"] += 1
		booth["last_start"] = f
	prev_count = count
	last_phase = int(snap["Phase"])


func _round5(snap: Dictionary, sh: Dictionary, f: int, me: int, hu: Dictionary, ctl: Dictionary, with: bool, phase: String, count: int) -> void:
	var carrier: int = int(snap["Carrier"])
	var sk: Array = snap["Skaters"]
	# the glue's two-role fact (InputMapping.cpp:432-442): he carries -> with; another carries -> without
	_check((carrier == me and with) or (carrier >= 0 and carrier != me and not with) or carrier < 0, "frame %d: ButtonsWithPuck %s, carrier %d" % [f, str(with), carrier])
	if carrier < 0 and with:
		r5["with_loose"] += 1
	# the panel's half: the swap rule over ButtonsWithPuck, stepped on the frames the panel is painted
	if sh.has("panel"):
		R.panel_swap_step(swap_mirror, with, false, f)
		var want: int = int(swap_mirror["shown"])
		_check(hud.panel.shown_with == want, "frame %d: the panel's half %d, the swap rule says %d" % [f, hud.panel.shown_with, want])
		_check(String(sh["panel"]).begins_with("LMB=SHOOT") == (want == 1), "frame %d: the panel's rows %s for half %d" % [f, String(sh["panel"]), want])
		r5["panel_with" if want == 1 else "panel_without"] += 1
	# the take grace: from its first frame (TakeGraceLeft 0 there: the full count)
	if phase == "play" or phase == "goal_pause":
		var g: bool = carrier >= 0 and bool(ctl["CarrierInTakeGrace"])
		_check(sh.has("grace") == g, "frame %d: grace ring %s, the core says %s" % [f, str(sh.has("grace")), str(g)])
		if g and sh.has("grace"):
			r5["grace"] += 1
			var gl: int = int((sk[carrier] as Dictionary).get("TakeGraceLeft", 0))
			var gr: Array = sh["grace"]
			_check(int(gr[0]) == carrier and int(gr[2]) == (gl if gl > 0 else hud.take_grace_total), "frame %d: grace %s for carrier %d left %d" % [f, str(gr), carrier, gl])
			if gl == 0:
				r5["grace_first"] += 1
				_check(is_equal_approx(float(gr[1]), 1.5) or float(gr[1]) == 1.0, "frame %d: the grace's first frame at scale %s" % [f, str(gr[1])])
				if float(gr[1]) == 1.0:
					r5["grace_first_hit"] += 1
	# the pass's target ring
	var passes: int = int(hu.get("Passes", 0))
	var carry: bool = carrier == me
	if pass_seen >= 0 and passes > pass_seen:
		pass_at = f
		r5["his_passes"] = int(r5.get("his_passes", 0)) + 1
	if carry and int(hu.get("PassChargeFrames", 0)) > 0:
		r5["held_frames"] = int(r5.get("held_frames", 0)) + 1
	pass_seen = passes
	var pk: Dictionary = snap["Puck"]
	var flying: bool = int(pk.get("PassFrames", 0)) > 0 and int(pk.get("PassBy", -1)) == me and f < pass_at + 45
	var held_t: int = int(ctl["PassTargetHeld"])   # HumanPassTarget along the stick at the hold (HUDChargeLook.cpp:97-112), round 7
	var charge: int = int(hu.get("PassChargeFrames", 0))
	if sh.has("pass_ring"):
		var at: int = int(sh["pass_ring"])
		var held_ok: bool = phase == "play" and carry and charge > 0 and at == held_t
		_check(held_ok or (phase == "play" and flying), "frame %d: a pass ring under %d (carry %s, charge %d, target %d, flying %s)" % [f, at, str(carry), charge, held_t, str(flying)])
		_check(int((sk[at] as Dictionary).get("PenaltyFrames", 0)) <= 0, "frame %d: a pass ring under a boxed skater" % f)
		r5["ring_held" if held_ok else "ring_flight"] += 1
	elif phase == "play" and carry and charge > 0 and held_t >= 0 and int((sk[held_t] as Dictionary).get("PenaltyFrames", 0)) <= 0 and not flying:
		_check(false, "frame %d: the pass held (charge %d) to %d and no ring" % [f, charge, held_t])
	# the teaching pulse
	for e: Dictionary in snap["Events"]:
		if String(e["Name"]) == "faceoff" and String(e["Kind"]) == "drop":
			drop_at = f
	var t: int = hud.charge.teach_shown
	if t >= 0:
		r5["teach_frames"] += 1
		_check(phase == "play" and count <= 0 and not bool(hu.get("IsDown", false)), "frame %d: a teaching pulse in %s, count %d, down %s" % [f, phase, count, str(hu.get("IsDown", false))])
		_check(f - drop_at >= 60 or drop_at > f, "frame %d: a teaching pulse %d frames after the drop" % [f, f - drop_at])
		_check((t == 0) == carry, "frame %d: teach %d while carry %s" % [f, t, str(carry)])
	for k: int in 2:
		var st: Dictionary = hud.charge.teach_state[k]
		if st.is_empty():
			continue
		var m: Dictionary = teach_mem[k]
		if bool(st["done"]) and int(m["done_at"]) < 0:
			m["done_at"] = f
		if int(st["shown_at"]) >= 0 and int(st["shown_at"]) != int(m["at"]):
			_check(int(st["shown_at"]) == f, "frame %d: a pulse started at %d" % [f, int(st["shown_at"])])
			_check(f - int(m["end"]) >= 900, "frame %d: a pulse %d frames after the last" % [f, f - int(m["end"])])
			_check(int(m["done_at"]) < 0, "frame %d: a pulse after he did it (%d)" % [f, int(m["done_at"])])
			r5["teach_pass" if k == 0 else "teach_hit"] += 1
			m["at"] = int(st["shown_at"])
		if t == k:
			_check(f - int(m["at"]) < 90, "frame %d: a pulse %d frames old" % [f, f - int(m["at"])])
			m["end"] = f + 1
		_check(int(st["shows"]) <= 3, "frame %d: %d pulses of kind %d" % [f, int(st["shows"]), k])
	if sh.has("panel"):
		var p: String = sh["panel"]
		_check(not p.contains("!") or t >= 0, "frame %d: a taught row with no pulse: %s" % [f, p])
		if (t == 0 and p.contains("RMB=PASS")) or (t == 1 and p.contains("RMB=CHECK")):
			_check(p.contains("RMB=PASS!") or p.contains("RMB=CHECK!"), "frame %d: teach %d and the row unlit: %s" % [f, t, p])
			r5["teach_row"] += 1


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var sc: Array = core.get_score() if core != null else [0, 0]
	return {"ok": done and fails.is_empty() and checks > 1000 and end_card_seen and booth["lines"] > 10
		and int(r5.get("ring_held", 0)) > 0 and int(r5.get("ring_flight", 0)) > 0 and int(r5["teach_pass"]) > 0 and int(r5["teach_hit"]) > 0
		and int(r5["teach_row"]) > 0 and int(r5["grace_first"]) > 0 and int(r5["panel_with"]) > 0 and int(r5["panel_without"]) > 0, "summary": "%d checks, %d failed (a recorded match of %d frames, score %d:%d; card %d, count %d, drop %d, result %d, panel %d, goal pause %d, end %d; you %d mate %d opponent %d loose %d)%s" % [
		checks, fails.size(), stats["frames"], int(sc[0]), int(sc[1]), stats["card"], stats["count"], stats["drop"], stats["result"], stats["panel"], stats["goal_pause"], stats["end"],
		stats["you"], stats["mate"], stats["opponent"], stats["loose"], "" if fails.is_empty() else ": " + "; ".join(fails)]
		+ "; banner %d frames over %d goals, booth %d lines (%d stoppage), end wait %s, end card %s; barks %d (lane %d frames)" % [banner_frames, goals_seen, booth["lines"], booth["stop_ok"], str(end_wait_ok), str(end_card_seen), bark_stats["barks"], bark_stats["lane"]]
		+ "; r5: %s" % str(r5)}
