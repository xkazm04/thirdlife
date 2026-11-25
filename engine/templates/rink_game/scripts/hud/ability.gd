extends RefCounted
## The ability slot of the HUD (lane E1b, 25 Nov): a cartridge's game.abilities[] (a trick on F) shown as thirdjam shows it.

const R := preload("rules.gd")

var abilities: Array = []               # game.abilities[] (hud.gd sets it)
var names: Dictionary = {}              # lane H2d: the skin's ability_names ({"shotgun": "cannon"}): the game's own word for a kind


func setup(abilities_: Array, names_: Dictionary) -> void:
	abilities = abilities_
	names = names_


## Lane A84 (R-0041 point 3) and A188 in thirdjam: "F: SHOTGUN  READY" on a dark plate above the radar, right-aligned with
## it, 440 wide (AbilitySlotW, HUDWidget.cpp:43), the cooldown fill along its foot; yellow while armed or a shield runs, paper
## when ready, grey while it cools down. The feed is AHokejGameMode's (HokejGameMode.cpp:1590-1613): the kind held (the
## slot's), or the one still armed, or a running shield; its state ON n.ns / NEXT SHOT|HIT|PASS / ARMED / ns / READY, and
## "  xN" charges. Hidden while the human holds nothing.
const ABILITY_SLOT_W := 440.0
const ABILITY_DEFAULT_COOLDOWN := 1200   # UJamSim::AbilityDefaultCooldown (JamSim.cpp:4455-4458)
static func ability_armed_word(kind: String) -> String:   # UJamHudWidget::AbilityArmedWord (HUDGoalBanner.cpp:122-129)
	match kind:
		"shotgun": return "NEXT SHOT"
		"hip_check": return "NEXT HIT"
		"slow_puck": return "NEXT PASS"
	return "ARMED"


## The plate's words and fill for the human `hu` at `now`: {} when he holds nothing, else {text, ready01, live}.
## `names_` (lane H2d): the skin's ability_names: the plate says the game's own word for the kind (G1's "F: CANNON"), else the core's id.
static func ability_feed(hu: Dictionary, abilities_: Array, now: int, names_: Dictionary = {}) -> Dictionary:
	var slot: int = int(hu.get("AbilitySlot", -1))
	var armed: String = String(hu.get("AbilityArmed", ""))
	var shield: int = int(hu.get("ShieldFrames", 0))
	var kind: String = ""
	var cool: int = 1
	if slot >= 0 and slot < abilities_.size():
		kind = String((abilities_[slot] as Dictionary).get("kind", ""))
		cool = int((abilities_[slot] as Dictionary).get("cooldown_frames", 0))
		if cool <= 0:
			cool = ABILITY_DEFAULT_COOLDOWN
	elif armed != "":
		kind = armed
	elif shield > 0:
		kind = "shield"
	if kind == "":
		return {}
	var left: int = maxi(0, int(hu.get("AbilityReadyFrame", 0)) - now)
	var state: String = "READY"
	if shield > 0:
		state = "ON %.1fs" % (float(shield) / 60.0)
	elif armed != "":
		state = ability_armed_word(armed)
	elif left > 0:
		state = "%ds" % ((left + 59) / 60)
	var charges: int = int(hu.get("AbilityCharges", -1))
	if charges > 0:
		state += "  x%d" % charges
	return {"text": "F: %s  %s" % [String(names_.get(kind, kind.replace("_", " "))).to_upper(), state],
		"ready01": 1.0 if shield > 0 else 1.0 - clampf(float(left) / float(maxi(1, cool)), 0.0, 1.0), "live": shield > 0 or armed != ""}


func paint(lay, snap: Dictionary, vw: float, vh: float, hu: Dictionary, shown: Dictionary) -> void:
	if abilities.is_empty():
		return
	var feed: Dictionary = ability_feed(hu, abilities, int(snap["Frame"]), names)
	if feed.is_empty():
		return
	var sz := Vector2(ABILITY_SLOT_W, 46.0)
	var br := Vector2(vw - R.EDGE_PX, vh - (R.EDGE_PX + R.RADAR_H + 12.0 + 30.0))   # above the radar's frame, right-aligned with it
	var tl: Vector2 = br - sz
	lay.box(tl, sz, Color(0, 0, 0, 0.62), 4.0, R.ML_EDGE, 1.0)
	var ready: bool = float(feed["ready01"]) >= 0.999
	var tc: Color = R.YELLOW if bool(feed["live"]) else (R.PAPER if ready else Color(0.6, 0.6, 0.6).linear_to_srgb())
	lay.text(Vector2(tl.x + 10.0, tl.y + sz.y * 0.5 - 2.0), String(feed["text"]), R.LINE_PT, tc, {"face": "bold_condensed", "tracking": R.TRACK_LABEL, "align": Vector2(0, 0.5)})
	var fc: Color = R.YELLOW if bool(feed["live"]) else (R.PAPER if ready else Color(0.45, 0.45, 0.45).linear_to_srgb())
	lay.box(Vector2(tl.x + 10.0, br.y - 6.0), Vector2(maxf(2.0, (sz.x - 20.0) * float(feed["ready01"])), 4.0), fc)
	shown["ability"] = String(feed["text"])
