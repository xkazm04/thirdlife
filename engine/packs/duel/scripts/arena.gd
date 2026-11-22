extends RefCounted
## Each rival fights in his own place and to his own beat (plays-twice items 6 and 21; For Honor's and Souls' duels sell
## the rival through the arena and the music). data/arenas.json per rival key:
##   dress   kit parts built outside the ring wall (banners in his colours above the stands, his towers, his trees);
##           the champion rungs (3-5) add their own parts on top: escalation you can see
##   beat    a drum from the stand-in presets: one tap every `every` frames, a louder accent each `accent` taps; it
##           quickens when either fighter is low or the rival roars (phase 2) and stops while a hit-stop holds
##   intro   round 1 of a match opens on a slow shot of him in his arena, then the play view
## Outside the ring wall (radius 8.6) only, so the fight itself never touches the dressing.

var g
var cfg: Dictionary = {}
var holder: Node3D = null
var key: String = ""
var beat_t: int = 0
var taps: int = 0
var intro_left: int = 0
var intro_prev: StringName = &"duel"
var times: Dictionary = {}               ## rival key + rung -> best winning match time in frames (this session)


func setup(main) -> void:
	g = main
	cfg = g.ctx.read_json("arenas.json")
	g.ctx.cameras.add_view(&"intro", Vector3(0, 2, -6), Vector3(0, 1, 0), 40.0)


## Build the rival's arena (called when the match's rival is chosen).
func dress(rival_key: String, champion: bool) -> void:
	if holder != null:
		g.ctx.root.remove_child(holder)
		holder.queue_free()
		holder = null
	key = rival_key
	var a: Dictionary = cfg["arenas"].get(key, {})
	if a.is_empty():
		return
	var props: Array = (a["dress"] as Array).duplicate(true)
	if champion:
		props.append_array((cfg["champion"]["dress"] as Array).duplicate(true))
	holder = Node3D.new()
	holder.name = "Arena_" + key
	g.ctx.root.add_child(holder)
	var built: Dictionary = TLKit.build_layout({"schema": "tl.layout/1", "name": "dress_" + key, "props": props}, holder)
	if not built["ok"]:
		push_error("arenas.json %s does not build: %s" % [key, "; ".join(built["errors"])])
	beat_t = 0
	taps = 0


## Round 1 of a match: a slow shot of the rival in his arena under the intro banner.
func intro() -> void:
	intro_left = 0
	if not g.drill.is_empty() or g.round_no != 1 or not bool(cfg["intro"]["on"]):
		return
	intro_left = int(g.tune["rounds"]["intro_frames"])
	intro_prev = g.show.views[g.show.view_i]
	g.ctx.cameras.activate(&"intro")


func tick() -> void:
	_intro_camera()
	if g.phase != "fight" or g.feel.holding(g.you, g.rival):
		return
	var b: Dictionary = cfg["arenas"].get(key, {}).get("beat", {})
	if b.is_empty():
		return
	var every: float = float(b["every"])
	if g.rung >= 3:
		every *= float(cfg["champion"]["beat_k"])
	var low: float = float(cfg["quicken"]["below"])
	if g.you.hp < g.you.hp_max * low or g.rival.hp < g.rival.hp_max * low or g.brain.phase2_on:
		every *= float(cfg["quicken"]["k"])
	if g.brain.pushing and g.rival.cfg.has("rhythm"):
		every *= float(cfg["quicken"]["push_k"])         # the drum drives his push and eases in his breath
	beat_t += 1
	if beat_t < int(every):
		return
	beat_t = 0
	taps += 1
	var accent: bool = taps % int(b["accent"]) == 0
	TLAudio.play(StringName(str(b["accent_preset"] if accent else b["preset"])), null, float(b["db"]) + (6.0 if accent else 0.0))


func _intro_camera() -> void:
	if intro_left <= 0:
		return
	intro_left -= 1
	if g.phase != "intro" or intro_left == 0:
		intro_left = 0
		g.ctx.cameras.activate(intro_prev)
		return
	var c: Dictionary = cfg["intro"]
	var n: float = float(g.tune["rounds"]["intro_frames"])
	var k: float = 1.0 - float(intro_left) / n
	var rv: Vector3 = g.rival.pos()
	var to_you: Vector3 = Vector3(g.you.pos().x - rv.x, 0.0, g.you.pos().z - rv.z)
	to_you = to_you.normalized() if to_you.length() > 0.01 else Vector3(0, 0, 1)
	var dir: Vector3 = to_you.rotated(Vector3.UP, deg_to_rad(float(c["from_deg"]) + (float(c["to_deg"]) - float(c["from_deg"])) * k))
	var at: Vector3 = rv + dir * (float(c["dist"]) + float(c["push"]) * k) + Vector3.UP * float(c["up"])
	var root: Node3D = g.ctx.root
	g.ctx.cameras.add_view(&"intro", root.to_global(at), root.to_global(rv + Vector3.UP * float(c["look_up"])), float(c["fov"]))


## A won match: its time on the card, with the best against this rival so far (a reason to play it again).
func time_line(won: bool) -> String:
	var frames: int = 0
	for r: Array in g.round_log:
		frames += int(r[2])
	var id: String = "%s_%d" % [key, g.rung]
	var line: String = "TIME %s" % _mmss(frames)
	if won:
		var best: int = int(times.get(id, 0))
		if best == 0 or frames < best:
			times[id] = frames
			line += "   BEST!" if best > 0 else ""
		else:
			line += "   BEST %s" % _mmss(best)
	return line


static func _mmss(frames: int) -> String:
	var s: int = frames / 60
	return "%d:%02d" % [s / 60, s % 60]


func snapshot() -> Dictionary:
	return {"key": key, "taps": taps, "best": times.duplicate()}
