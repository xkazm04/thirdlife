extends RefCounted
## The take and the MATCH card (thirdjam HEAD 8dc713c6). The take is AHokejGameMode's, not the sim's period: ComputeTake =
## clamp(1 + the lead's score, 1, score_to_win) in first_to (HokejGameMode.cpp:372-383), updated only on a Playing frame
## (cpp:1679) and forced at a match's build and restart (cpp:560, 815); a change broadcasts `period` (cpp:385-397), on which
## the controller opens the MATCH card for TakeCardFrames 150 (DirectorsCallController.cpp:96-100, 168-191; .h:31).
## The card (UJamDirectorsCallHudWidget, DirectorsCallWidget.cpp:597-613, 639-737; one look HUDOneLook.cpp:204-232):
## "MATCH 1" over "PERIOD n   -   FACEOFF   -   <LEVEL>", centred at y 190 under the scoreboard; it goes on the first frame
## after a faceoff countdown it has seen (jam.hud.CardAtDrop 1), never on the end card.

const R := preload("rules.gd")
const TAKE_CARD_FRAMES := 150            # UJamDirectorsCallController::TakeCardFrames (DirectorsCallController.h:31)
const MATCH_CARD_CENTRE_Y := 190.0       # DirectorsCallWidget.h:219
const MATCH_CARD_PT := 42                # MatchCardFont: FJamMenuLook::Font(50 - 8, Black, 60) (HUDOneLook.cpp:198-202; DirectorsCallWidget.h:220-223, 90 m rink)

var score_to_win: int = 3
var level: String = "PRO"
var take: int = 1
var take_until: int = -1
var until_seen: int = -2
var count_seen: bool = false
var last_frame: int = -1
var box := Rect2()


func _init(game: Dictionary, level_id: String) -> void:
	score_to_win = int((game.get("rules", {}) as Dictionary).get("score_to_win", 0))
	level = {"rookie": "ROOKIE", "all_star": "ALL-STAR"}.get(level_id, "PRO")   # FJamSettings::DifficultyLabel (SettingsWidget.cpp:171-179)


static func compute_take(score: Array, score_to_win_: int) -> int:
	var lead: int = maxi(int(score[0]), int(score[1]))
	return clampi(1 + lead, 1, score_to_win_) if score_to_win_ > 0 else 1 + lead


## One frame of the take and the card's clock. Returns true while the card is up.
func step(snap: Dictionary, phase: String) -> bool:
	var f: int = int(snap["Frame"])
	if f < last_frame or last_frame < 0:
		take = compute_take(snap["Score"], score_to_win)       # UpdateTake(true): the build, a restart
		take_until = f + TAKE_CARD_FRAMES
	elif int(snap["Phase"]) == 0:
		var t: int = compute_take(snap["Score"], score_to_win)
		if t != take:
			take = t
			take_until = f + TAKE_CARD_FRAMES
	last_frame = f
	var countdown: int = int(snap["FaceoffCountdown"]) if int(snap["Phase"]) == 3 else 0
	if take_until != until_seen:
		until_seen = take_until
		count_seen = false
	if countdown > 0:
		count_seen = true
	elif count_seen and take_until > f:
		take_until = f
		until_seen = take_until
	var end: bool = phase == "win" or phase == "lose"
	return not end and take_until >= 0 and f < take_until


func sub_line() -> String:
	return "PERIOD %d   -   FACEOFF   -   %s" % [maxi(1, take), level]


func paint(lay, vw: float) -> void:
	var title := "MATCH 1"
	var sub := sub_line()
	var shadow := {"shadow": Vector2(0, 1), "shadow_color": Color(0, 0, 0, 0.45)}
	var t_sz: Vector2 = lay.measure(title, MATCH_CARD_PT, "black", R.TRACK_LABEL)
	var s_sz: Vector2 = lay.measure(sub, R.LINE_PT, "bold_condensed", R.TRACK_LABEL)
	var inner := Vector2(32 + maxf(t_sz.x, s_sz.x) + 32, 4 + t_sz.y + 2 + s_sz.y + 10)
	var size := Vector2(inner.x, 3 + inner.y)
	var tl := Vector2(vw * 0.5 - size.x * 0.5, MATCH_CARD_CENTRE_Y - size.y * 0.5)
	box = Rect2(tl, size)
	lay.box(tl, Vector2(size.x * 0.5, 3), R.ML_HOME)
	lay.box(tl + Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, 3), R.ML_AWAY)
	var fill := R.ML_PANEL
	fill.a = 0.9
	lay.box(tl + Vector2(0, 3), inner, fill, 4.0, R.ML_EDGE, 1.0)
	lay.text(Vector2(vw * 0.5, tl.y + 3 + 4), title, MATCH_CARD_PT, R.ML_TEXT, _o("black", Vector2(0.5, 0), shadow))
	lay.text(Vector2(vw * 0.5, tl.y + 3 + 4 + t_sz.y + 2), sub, R.LINE_PT, R.ML_TEXT_DIM, _o("bold_condensed", Vector2(0.5, 0), shadow))


static func _o(face: String, align: Vector2, extra: Dictionary) -> Dictionary:
	var o := {"face": face, "tracking": R.TRACK_LABEL, "align": align}
	o.merge(extra)
	return o
