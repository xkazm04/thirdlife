extends RefCounted
## thirdjam's barks (lane K5, round 4; HEAD 8dc713c6, `jam.Barks` -1 = the cartridge's game.barks, here enabled at "normal";
## `jam.hud.BarkLane` 1): a skater's short line in a bubble. The picker (FJamBarkPicker, BarkSystem.cpp:182-328) over the
## 1,340 lines of the bank (data/hud_barks.json = BarkData.inl = Content/Barks/barks.json); the triggers (UJamBarkSystem,
## BarkSystem.cpp:418-505): a goal, the human's check landed, the human knocked down, a faceoff, the end, a near miss (a shot
## then a board hit by the net within 45 frames), a steal (the puck changes team), a stall (5 s untouched, slow). The lane
## (UJamBarkWidget, BarkWidget.cpp:18-38, 240-370): one bubble a side, the newest of a team whose speaker is in the frame and
## within 24 m, standing in the scoreboard's row (bottom at y 84) 262 units beside the centre, never over a figure, the puck or
## the human's box, never while a HUD line of words stands; held 150 frames, faded over 90; cleared by a pause. One look
## (HUDOneLook.cpp:241-251): the panel at 0.9, a 4-unit corner, the team's edge 2 wide, Bold 18 in the text colour.
## Its stream is its own (seeded from the match's seed): presentation only, never in the state hash.

const R := preload("rules.gd")
const GLOBAL_COOLDOWN := 240
const SPEAKER_COOLDOWN := 480
const NO_REPEAT := 10
const HOLD := 150
const FADE := 90
const STALL := 300
const NEAR_MISS := 45
const MAX_BUBBLES := 6
const LANE_BOTTOM_Y := 84.0
const LANE_GAP_X := 262.0
const LANE_EDGE := 8.0
const MAX_DISTANCE_M := 24.0
const HEIGHT_M := 2.35                # BubbleHeightCm: over the figure's feet

var bank: Dictionary = {}             # "situation|speaker|tone" -> [[id, text], ...]
var enabled: bool = true
var rng := RandomNumberGenerator.new()
var last_global: int = -1000000
var last_speaker: Dictionary = {}
var history: Array = []
var bubbles: Array = []               # {speaker, team, frame, text}
var last_shot: int = -1000000
var last_shot_team: int = -1
var last_touch_team: int = -1
var last_touch_frame: int = 0
var last_stall: int = -1000000
var last_frame: int = -1
var goal_line_x: float = 41.0
var goal_w: float = 4.0
var said: Array = []                  # this frame's barks: [speaker, situation] (the booth yields to one at the human)


func _init(game: Dictionary, rows: Array, seed_value: int) -> void:
	var b: Dictionary = game.get("barks", {})
	enabled = bool(b.get("enabled", true))
	for r: Array in rows:
		var k: String = "%s|%s|%s" % [r[1], r[2], r[3]]
		if not bank.has(k):
			bank[k] = []
		(bank[k] as Array).append([r[0], r[4]])
	var rk: Dictionary = game["rink"]
	goal_line_x = float(rk["length_m"]) * 0.5 - 4.0
	goal_w = float(rk.get("goal_width_m", 4.0))
	rng.seed = hash([seed_value, 0xBA2C, 77])


static func _team(snap: Dictionary, i: int) -> int:
	var sk: Array = snap["Skaters"]
	return int((sk[i] as Dictionary)["Team"]) if i >= 0 and i < sk.size() else -1


## FJamBarkWorld::Nearest: the nearest opponent (or teammate) of the human to `where`, never the human.
static func nearest(snap: Dictionary, where: Vector2, opponents: bool) -> int:
	var me: int = int(snap["HumanIndex"])
	var mt: int = _team(snap, me)
	var best: int = -1
	var bd: float = INF
	for i: int in (snap["Skaters"] as Array).size():
		if i == me:
			continue
		var t: int = _team(snap, i)
		if opponents != (t != mt):
			continue
		var d: float = ((snap["Skaters"][i] as Dictionary)["Pos"] as Vector2).distance_squared_to(where)
		if d < bd:
			bd = d
			best = i
	return best


func _tone(side_opp: bool, situation: String) -> String:          # ChooseTone at "normal" (BarkSystem.cpp:258-279)
	var roll: int = rng.randi_range(0, 99)
	if side_opp:
		return "mock" if roll < 50 else ("complain" if roll < 80 else "bravado")
	if situation in ["signal_ack_defend", "signal_ack_space", "signal_ack_pass", "praise_reply"]:
		return "encourage" if roll < 70 else "praise"
	return "encourage" if roll < 40 else ("praise" if roll < 75 else "complain")


func _cooling(speaker: int, f: int) -> bool:
	return f - last_global < GLOBAL_COOLDOWN or (last_speaker.has(speaker) and f - int(last_speaker[speaker]) < SPEAKER_COOLDOWN)


## Pick (BarkSystem.cpp:292-327): a tone by the roll, else the first tone of the side that has lines; a line not in the last ten.
func pick(situation: String, opp: bool, speaker: int, f: int, snap: Dictionary, tone: String = "") -> bool:
	if not enabled or speaker < 0 or _cooling(speaker, f):
		return false
	var who: String = "opponent" if opp else "teammate"
	if tone == "":
		tone = _tone(opp, situation)
		if not bank.has("%s|%s|%s" % [situation, who, tone]):
			tone = ""
			for t: String in (["mock", "complain", "bravado"] if opp else ["encourage", "praise", "complain"]):
				if bank.has("%s|%s|%s" % [situation, who, t]):
					tone = t
					break
			if tone == "":
				return false
	var all: Array = bank.get("%s|%s|%s" % [situation, who, tone], [])
	if all.is_empty():
		return false
	var fresh: Array = all.filter(func(l: Array) -> bool: return not history.has(l[0]))
	var pool: Array = fresh if not fresh.is_empty() else all
	var line: Array = pool[rng.randi_range(0, pool.size() - 1)]
	last_global = f
	last_speaker[speaker] = f
	history.append(line[0])
	if history.size() > NO_REPEAT:
		history.remove_at(0)
	_show(speaker, _team(snap, speaker), f, line[1])
	said.append([speaker, situation])
	return true


func _show(speaker: int, team: int, f: int, text: String) -> void:   # ShowBark: the same speaker's bubble, else the oldest
	for b: Dictionary in bubbles:
		if int(b["speaker"]) == speaker:
			b.merge({"team": team, "frame": f, "text": text}, true)
			return
	if bubbles.size() < MAX_BUBBLES:
		bubbles.append({"speaker": speaker, "team": team, "frame": f, "text": text})
		return
	var oldest: Dictionary = bubbles[0]
	for b: Dictionary in bubbles:
		if int(b["frame"]) < int(oldest["frame"]):
			oldest = b
	oldest.merge({"speaker": speaker, "team": team, "frame": f, "text": text}, true)


## One sim frame: the frame's events (HandleBusEvent) and the frame's watch (HandleSimFrame). `extra`: the game mode's win / lose.
func step(snap: Dictionary, extra: Array) -> void:
	said = []
	var f: int = int(snap["Frame"])
	if f < last_frame:
		last_global = -1000000
		last_speaker = {}
		bubbles = []
		last_touch_team = -1
	last_frame = f
	if not enabled:
		return
	var me: int = int(snap["HumanIndex"])
	var mt: int = _team(snap, me)
	var hp: Vector2 = (snap["Skaters"][me] as Dictionary)["Pos"]
	for x: Array in extra:
		if x[0] == "win":
			pick("win", false, nearest(snap, hp, false), f, snap)
		elif x[0] == "lose":
			pick("lose", true, nearest(snap, hp, true), f, snap)
	for e: Dictionary in snap["Events"]:
		var name_: String = e["Name"]
		var who: int = int(e["Who"])
		var where: Vector2 = e["Where"]
		match name_:
			"shot":
				last_shot = f
				last_shot_team = _team(snap, who)
			"board":
				if f - last_shot <= NEAR_MISS and last_shot_team >= 0 and absf(where.x) > goal_line_x - 1.5 and absf(where.y) < goal_w * 0.5 + 3.0:
					last_shot = -1000000
					var sp: int = nearest(snap, where, true)
					if last_shot_team == mt:
						pick("near_miss", true, sp, f, snap)
					else:
						pick("near_miss", true, sp, f, snap, "complain")
			"goal":
				var scoring: int = 0 if where.x > 0.0 else 1                # team 0 attacks +x
				if scoring == mt:
					if who == me:
						pick("goal_for", false, nearest(snap, where, false), f, snap)
					else:
						pick("goal_for", true, nearest(snap, where, true), f, snap)
				else:
					var sp2: int = who if who >= 0 and _team(snap, who) != mt and who != me else nearest(snap, where, true)
					pick("goal_against", true, sp2, f, snap)
			"check":
				if who == me:
					pick("check_landed", true, nearest(snap, where, true), f, snap)
			"knockdown":
				if who == me:
					pick("check_received", true, nearest(snap, where, true), f, snap)
			"faceoff":
				pick("faceoff", true, nearest(snap, where, true), f, snap)
	# the watch: only in play
	if int(snap["Phase"]) != 0:
		last_touch_team = -1
		last_touch_frame = f
		return
	var touch: int = int((snap["Puck"] as Dictionary)["LastTouch"])
	var tt: int = _team(snap, touch)
	if tt >= 0 and tt != last_touch_team:
		if last_touch_team >= 0:
			if tt != mt:
				pick("steal", true, touch, f, snap)
			elif touch == me:
				pick("steal", true, nearest(snap, (snap["Skaters"][touch] as Dictionary)["Pos"], true), f, snap, "complain")
		last_touch_team = tt
	if touch >= 0 and bool((snap["Skaters"][touch] as Dictionary).get("bTouchingPuck", false)):
		last_touch_frame = f
	var pv: Vector2 = (snap["Puck"] as Dictionary)["Vel"]
	if f - last_touch_frame > STALL and pv.length() < 2.0 and f - last_stall > 600:
		last_stall = f
		pick("stall", true, nearest(snap, (snap["Puck"] as Dictionary)["Pos"], true), f, snap)


static func opacity(age: int) -> float:                            # OpacityFor (BarkWidget.cpp:78-86)
	if age < 0:
		return 0.0
	if age <= HOLD:
		return 1.0
	var fade: int = age - HOLD
	return 0.0 if fade >= FADE else 1.0 - float(fade) / float(FADE)


## The lane (Layout, BarkWidget.cpp:240-370). `line_up`: a HUD line of words stands this frame; `keep`: the human's box.
## Returns what it drew: [[team, text], ...].
func paint(lay, snap: Dictionary, vw: float, vh: float, now: int, paused: bool, line_up: bool, keep: Rect2, team_col: Array) -> Array:
	var out: Array = []
	if paused:
		for b: Dictionary in bubbles:
			b["frame"] = -1000000                                     # the pause card clears every bubble
		return out
	var eye: Vector3 = lay.eye()
	var owner_: Array = [null, null]
	for b: Dictionary in bubbles:
		if opacity(now - int(b["frame"])) <= 0.0:
			continue
		var p: Vector2 = (snap["Skaters"][int(b["speaker"])] as Dictionary)["Pos"]
		var at := Vector3(p.x, HEIGHT_M, p.y)
		if eye.distance_to(Vector3(p.x, 0, p.y)) > MAX_DISTANCE_M:
			continue
		var sp: Vector3 = lay.project(at)
		if sp.z <= 0.0 or sp.x <= 0.0 or sp.x >= vw or sp.y <= 0.0 or sp.y >= vh:
			continue
		var side: int = 0 if int(b["team"]) == 0 else 1
		if owner_[side] == null or int(b["frame"]) > int((owner_[side] as Dictionary)["frame"]):
			owner_[side] = b
	if line_up:                                                       # a bubble yields to the HUD's one line of words (HUDOneLine.cpp)
		return out
	for side: int in 2:
		var b = owner_[side]
		if b == null:
			continue
		var a: float = opacity(now - int(b["frame"]))
		var t: String = b["text"]
		var ts: Vector2 = lay.measure(t, R.LINE_PT, "bold_condensed")
		var size := Vector2(14 + ts.x + 14, 7 + ts.y + 7)
		var half: float = maxf(60.0, size.x * 0.5)
		var x: float = maxf(vw * 0.5 - LANE_GAP_X - half, LANE_EDGE + half) if side == 0 else minf(vw * 0.5 + LANE_GAP_X + half, vw - LANE_EDGE - half)
		var box := Rect2(Vector2(x - size.x * 0.5, LANE_BOTTOM_Y - size.y), size)
		if _covered(lay, snap, box, keep):
			continue
		var fill := R.ML_PANEL
		fill.a = 0.9 * a
		var edge: Color = R.BLUE if int(b["team"]) == 0 else R.ORANGE
		edge.a = a
		lay.box(box.position, box.size, fill, 4.0, edge, 2.0)
		lay.text(box.position + Vector2(14, 7), t, R.LINE_PT, R.ML_TEXT, {"face": "bold_condensed", "alpha": a, "shadow": Vector2(0, 1), "shadow_color": Color(0, 0, 0, 0.45)})
		out.append([int(b["team"]), t])
	return out


## LaneCovered: a figure (feet to 1.8 m), the puck, or the human's box under the lane box.
func _covered(lay, snap: Dictionary, box: Rect2, keep: Rect2) -> bool:
	if keep.size != Vector2.ZERO and box.intersects(keep.grow(6.0)):
		return true
	for s: Dictionary in snap["Skaters"]:
		var p: Vector2 = s["Pos"]
		var feet: Vector3 = lay.project(Vector3(p.x, 0, p.y))
		var head: Vector3 = lay.project(Vector3(p.x, 1.8, p.y))
		if feet.z <= 0.0 or head.z <= 0.0:
			continue
		var hw: float = maxf(12.0, 0.5 * Vector2(feet.x, feet.y).distance_to(Vector2(head.x, head.y)))
		var col := Rect2(Vector2(minf(feet.x, head.x) - hw, minf(feet.y, head.y)), Vector2(absf(feet.x - head.x) + 2.0 * hw, absf(feet.y - head.y)))
		if col.intersects(box):
			return true
	var pk: Vector2 = (snap["Puck"] as Dictionary)["Pos"]
	var pp: Vector3 = lay.project(Vector3(pk.x, 0, pk.y))
	if pp.z > 0.0 and Rect2(Vector2(pp.x - 12, pp.y - 14), Vector2(24, 28)).intersects(box):
		return true
	return false
