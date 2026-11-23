extends "bot_hockey.gd"
## H1 hand (23 Nov): a ladder match (bot_hockey.gd through TLHand: level and hand from env H1_LEVEL, H1_HAND) that writes one
## row per frame to H1_OUT/match_s<seed>.csv: b0, the puck, who holds it, the last release, whether b0 is down or stumbling,
## and the nearest red skater. The same fields as thirdjam's playtester TRACE lines (JamTournament -trace=1), so
## hand_carry.mjs reads both games alike. Lives only in a COPY of the pack (.tl/h1/hockey/tests/).
var rows := PackedStringArray(["f,live,x,z,vx,vz,px,pz,pvx,pvz,holder,rel_kind,rel_by,rel_f,down,opp_d"])

func _init() -> void:
	var lv := OS.get_environment("H1_LEVEL")
	var hd := OS.get_environment("H1_HAND")
	ladder(lv if lv != "" else "pro", hd if hd != "" else "regular")

func _bot_tick(frame: int) -> void:
	super._bot_tick(frame)
	if s.is_empty() or not s.has("skaters"):
		return
	var me: Dictionary = _sk("b0")
	var pk: Dictionary = s.puck
	var rel: Dictionary = s.possession.get("last", {})
	var hits: Dictionary = s.get("hits", {})
	var down := "d" if hits.get("down", {}).has("b0") else ("s" if hits.get("stumbling", {}).has("b0") else "")
	var opp := INF
	for sk: Dictionary in s.skaters:
		if str(sk.id).begins_with("r"):
			opp = minf(opp, Vector2(sk.pos[0] - me.pos[0], sk.pos[1] - me.pos[1]).length())
	var live := 1 if (str(s.get("state", "")) == "running" and not bool(s.get("frozen", false))) else 0
	rows.append("%d,%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%s,%s,%s,%d,%s,%.2f" % [frame, live, me.pos[0], me.pos[1], me.vel[0], me.vel[1],
		pk.pos[0], pk.pos[1], pk.vel[0], pk.vel[1], str(pk.get("holder", "")), str(rel.get("kind", "")), str(rel.get("by", "")), int(rel.get("frame", -1)), down, opp])
	if done:
		var f := FileAccess.open(OS.get_environment("H1_OUT").path_join("match_s%d.csv" % ctx.seed), FileAccess.WRITE)
		f.store_string("\n".join(rows) + "\n")
		f.close()
