extends RefCounted
## The first minute teaches by play (plays-twice items 5 and 10; For Honor's guided first duel, Sekiro's sparring
## partner at the start of the game). Only in round 1 against the first rival: the Wall shows each answer once with a
## slower, held wind-up and a cue line read BEFORE the blow, then stands open for the punish:
##   1. block: a heavy with an 18-frame hold -> "HOLD SPACE to block"; blocked -> he bounces off -> "hit him NOW"
##   2. parry: a light with a 14-frame hold and the glint -> "TAP SPACE as it lands"; parried -> "a HEAVY cannot miss"
##   3. bash:  he raises his shield and walks in behind it -> "E breaks it"; guard broken -> "strike!"
## A lesson that fails is shown once more; after the third (or 50 s) he fights for real. The attacks are real: they hit,
## block, parry and count like any other. Data: data/lessons.json.

var g
var steps: Array = []
var on: bool = false
var i: int = 0                         ## the step being taught
var phase: String = "show"             ## show (cue up, walking in) | strike | open (standing open for the punish) | gap
var t: int = 0
var tries: int = 0
var serial: int = -1                   ## the rival's attack serial of this try
var log_from: int = 0
var results: Array = []                ## [id, "ok" | "missed"] per step
var punished: int = 0                  ## punishes landed in an open window
var cfg: Dictionary = {}
var done_line: String = ""
var damage_k: float = 1.0                ## share of damage he takes while his lessons run (rivals.<key>.damage_k)


func setup(main) -> void:
	g = main
	cfg = g.ctx.read_json("lessons.json")
	steps = cfg["steps"]


## Called at every round start: lessons run in round 1 against the first rung, never in a drill.
func start() -> void:
	var key: String = str(g.rival.cfg.get("key", ""))
	var mine: Dictionary = (cfg.get("rivals", {}) as Dictionary).get(key, {})
	steps = mine.get("steps", []) if g.rung > 0 else cfg["steps"]   # round 11: the Duelist teaches his own tell and parry
	done_line = str(mine.get("done", cfg["done"]))
	damage_k = float(mine.get("damage_k", 1.0)) if g.rung > 0 else 1.0
	on = g.rung < 3 and not steps.is_empty() and g.round_no == 1 and g.drill.is_empty() and bool(cfg["enabled"])
	if not on:
		return                                      # later rounds keep the record of round 1
	i = 0
	phase = "show"
	t = 0
	tries = 0
	results = []
	punished = 0
	log_from = g.contact.log.size()


func stop() -> void:
	on = false


## The rival's mind asks first: true while a lesson drives the rival this frame.
func tick(f: int) -> bool:
	if not on:
		return false
	var me = g.rival
	var you = g.you
	if g.round_rules != null and g.round_rules.total_frames > int(cfg["max_frames"]):
		_finish()
		return false
	t += 1
	var step: Dictionary = steps[i]
	me.walk = Vector2.ZERO
	me.heavy_held = false
	match phase:
		"show":
			if t == 1:
				g.show.cue(str(step["cue"]), int(cfg["cue_frames"]))
			var want: float = float(step.get("distance", 2.0))
			me.walk = Vector2(0.0, clampf((me.dist() - want) * 1.5, -1.0, 1.0))
			me.block_held = str(step["id"]) == "bash"
			if me.block_held and me.st != "BLOCK" and me.can_act():
				me.press("block")
			if t >= int(cfg["read_frames"]) and me.can_act() and absf(me.dist() - want) < 0.5:
				log_from = g.contact.log.size()
				if str(step["id"]) == "bash":
					phase = "strike"
					t = 0
				elif me.act(str(step["move"]), {"frames": int(step["frames"])} if step.has("frames") else {"hold": int(step["hold"])}):
					serial = me.serial
					phase = "strike"
					t = 0
		"strike":
			me.block_held = str(step["id"]) == "bash"
			var got: String = _outcome(step)
			if got == "ok":
				results.append([step["id"], "ok"])
				g.show.cue(str(step["next_cue"]), int(cfg["open_frames"]))
				phase = "open"
				t = 0
			elif got == "missed" or t > int(cfg["strike_frames"]):
				tries += 1
				if tries >= 2:
					results.append([step["id"], "missed"])
					_next()
				else:
					g.show.cue(str(cfg["again"]), 60)
					phase = "show"
					t = int(cfg["read_frames"]) - 40
		"open":
			me.block_held = false                       # he stands open for the punish (his stun does the rest)
			for k in range(log_from, g.contact.log.size()):
				var e: Dictionary = g.contact.log[k]
				if e["by"] == you.id and str(e["type"]).begins_with("hit"):
					punished += 1
					log_from = g.contact.log.size()
			if t > int(cfg["open_frames"]):
				_next()
		"gap":
			me.walk = Vector2(0.0, -0.5)
			if t > int(cfg["gap_frames"]):
				phase = "show"
				t = 0
	g.brain.last_action = f                         # a lesson is the rival acting, not idling
	return true


## What this try's blow met: "ok" (the answer the step teaches), "missed" (anything else), "" (not yet).
func _outcome(step: Dictionary) -> String:
	for k in range(log_from, g.contact.log.size()):
		var e: Dictionary = g.contact.log[k]
		var kind: String = str(e["type"])
		if kind in (step["ok"] as Array):
			return "ok"
		if str(step["id"]) != "bash" and e["by"] == g.rival.id:
			return "missed"
	if str(step["id"]) != "bash" and g.rival.serial == serial and g.rival.st == "RECOVERY" and g.rival.whiffed:
		return "missed"
	return ""


func _next() -> void:
	i += 1
	tries = 0
	if i >= steps.size():
		_finish()
		return
	phase = "gap"
	t = 0


func _finish() -> void:
	if on:
		g.show.cue(done_line, 90)
	on = false


func snapshot() -> Dictionary:
	return {"on": on, "step": i, "phase": phase, "results": results.duplicate(true), "punished": punished}
