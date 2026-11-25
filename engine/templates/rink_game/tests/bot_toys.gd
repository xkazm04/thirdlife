extends "bot_match_hand.gd"
## What the cartridge puts on the ice is drawn (lane E1b, 25 Nov; E5 job 2 played slow and fast patches and corner bumpers
## on plain ice). bot_match_hand.gd's hand plays MAX frames of the match through the keys and mouse; then scripts/
## rink_toys.gd's counts (the meta `toys` on the RinkToys node) are held against the cartridge of data/match.json:
##   - every visible zone of game.rink.zones is painted (visible false: not), every obstacle of game.rink.obstacles stands;
##   - with game.pickups: pickups were put on the ice while the match ran, and the ones standing are the ones put down and
##     not taken. RinkCore 1.3 does not report pickups (rink_toys.gd NOTE): then the summary says so in words ("pickups NOT
##     REPORTED by the core") and the zones and obstacles alone decide; the day the core reports them, they are checked;
##   - without them, none.
## A cartridge with none of these passes with zeros (the regular cartridge). Headless; the drawing is checked in a window by
## a still (README.md "Its tests").

const MAX: int = 2400
var toys: Dictionary = {}


func _bot_tick(frame: int) -> void:
	if frame == 0:
		ctx.input.tap(&"level_rookie")
		return
	if frame >= MAX:
		ctx.input.release_all()
		var n: Node = ctx.root.find_child("RinkToys", true, false)
		toys = n.get_meta(&"toys", {}) if n != null else {}
		done = true
		return
	super._bot_tick(frame)
	done = false


func _bot_result() -> Dictionary:
	var cart: Dictionary = ctx.read_json(String((ctx.read_json("match.json") as Dictionary).get("cartridge", "hockey.regular.cartridge.json")))
	var g: Dictionary = cart["game"]
	var rk: Dictionary = g["rink"]
	var want_zones: int = 0
	for z: Dictionary in rk.get("zones", []):
		if bool(z.get("visible", true)):
			want_zones += 1
	var want_obs: int = (rk.get("obstacles", []) as Array).size()
	var has_pickups: bool = not (g.get("pickups", []) as Array).is_empty()
	var fails: Array = []
	if toys.is_empty():
		fails.append("no RinkToys node with its counts")
	else:
		if int(toys["zones"]) != want_zones:
			fails.append("zones drawn %d, the cartridge paints %d" % [int(toys["zones"]), want_zones])
		if int(toys["obstacles"]) != want_obs:
			fails.append("obstacles drawn %d, the cartridge has %d" % [int(toys["obstacles"]), want_obs])
		if has_pickups and bool(toys.get("reported", false)) and int(toys["spawned"]) == 0:
			fails.append("the cartridge has pickups and none was put on the ice in %d frames" % MAX)
		if not has_pickups and int(toys["spawned"]) != 0:
			fails.append("pickups drawn without game.pickups")
		if int(toys["pickups_on_ice"]) != int(toys["spawned"]) - int(toys["taken"]):
			fails.append("pickups standing %d, put down %d, taken %d" % [int(toys["pickups_on_ice"]), int(toys["spawned"]), int(toys["taken"])])
	var summary: String = "zones %d of %d, obstacles %d of %d, pickups put down %d, taken %d, standing %d at frame %d" % [
		int(toys.get("zones", -1)), want_zones, int(toys.get("obstacles", -1)), want_obs, int(toys.get("spawned", -1)),
		int(toys.get("taken", -1)), int(toys.get("pickups_on_ice", -1)), MAX]
	if has_pickups and not bool(toys.get("reported", false)):
		summary += "; the cartridge's pickups NOT REPORTED by the core (SNAPSHOT.md has no Pickups): not drawn"
	return {"ok": done and fails.is_empty(), "summary": summary + ("" if fails.is_empty() else " FAILS: " + "; ".join(fails)), "frames": ctx.frame}
