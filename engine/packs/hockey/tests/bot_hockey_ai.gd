extends Node
## Bot: same strategy as bot_hockey.gd for b0; checks the AI skaters act.

var ctx
var s: Dictionary = {}
var done: bool = false
var spawn: Dictionary = {}
var maxd: Dictionary = {}
var puck_prev: Vector2 = Vector2.ZERO
var have_prev: bool = false
var puck_total: float = 0.0


func _bot_setup(c) -> void:
	ctx = c


func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _bot_tick(_frame: int) -> void:
	s = ctx.pack_state()
	if str(s.get("mode", "base")) != "base":
		ctx.input.tap(&"mode_base")      # H3: this bot tests the base game; under another mode param it switches to it first
		return
	done = s["state"] == "over"
	var pk: Vector2 = _v(s["puck"]["pos"])
	if have_prev:
		var step: float = pk.distance_to(puck_prev)
		if step < 5.0:
			puck_total += step
	puck_prev = pk
	have_prev = true
	var me: Dictionary = {}
	var others: Array = []
	for k: Dictionary in s["skaters"]:
		var p: Vector2 = _v(k["pos"])
		var id: String = str(k["id"])
		if not spawn.has(id):
			spawn[id] = p
			maxd[id] = 0.0
		maxd[id] = maxf(float(maxd[id]), p.distance_to(spawn[id]))
		if id == "b0":
			me = k
		else:
			others.append(p)
	if done or bool(s["frozen"]):
		ctx.input.set_axis(&"left", &"right", 0.0)
		ctx.input.set_axis(&"up", &"down", 0.0)
		return
	var pos: Vector2 = _v(me["pos"])
	var face: Vector2 = _v(me["facing"]).normalized()
	var puck: Vector2 = pk
	var goal: Vector2 = Vector2(26.0, 0.0)
	var dgoal: float = (goal - puck).length()
	var dirg: Vector2 = (goal - puck).normalized()
	for o: Vector2 in others:
		if o.x < 20.0 and o.x > puck.x - 0.5 and o.x < puck.x + 8.0:
			var rel: Vector2 = o - puck
			if rel.dot(dirg) > 0.0 and absf(rel.cross(dirg)) < 2.2:
				var sgn: float = 1.0 if puck.y - o.y >= 0.0 else -1.0
				dirg = (Vector2(o.x + 3.0, o.y + sgn * 3.5) - puck).normalized()
	if absf(puck.y) > 13.4:
		dirg = Vector2(1.0, 0.0)
	var to_puck: Vector2 = puck - pos
	var behind: Vector2 = puck - dirg * 1.2
	var want: Vector2
	var lateral: float = to_puck.cross(dirg)
	if to_puck.dot(dirg) > 0.0 and absf(lateral) < 1.3:
		want = puck + dirg * 3.0 - pos
	else:
		want = behind - pos
		if to_puck.dot(dirg) < 0.0 and to_puck.length() < 4.0:
			var perp: Vector2 = Vector2(-dirg.y, dirg.x) * (1.0 if lateral <= 0.0 else -1.0)
			want = behind + perp * 2.5 - pos
	for o: Vector2 in others:
		var dd: Vector2 = pos - o
		if dd.length() < 1.2 and dd.length() > 0.01:
			want += dd.normalized() * (1.2 - dd.length()) * 3.0
	var dir: Vector2 = want.normalized() if want.length() > 0.05 else Vector2.ZERO
	ctx.input.set_axis(&"left", &"right", dir.x)
	ctx.input.set_axis(&"up", &"down", dir.y)
	if bool(s["shoot_ready"]) and dgoal < 22.0 and face.x > 0.3 and face.dot((goal - puck).normalized()) > 0.95:
		var zg: float = puck.y + face.y / face.x * (26.0 - puck.x)
		var clear: bool = true
		for o: Vector2 in others:
			var r2: Vector2 = o - puck
			if r2.dot(face) > 0.0 and absf(r2.cross(face)) < 1.0 and o.x < 25.0:
				clear = false
		if absf(zg) < 2.5 and clear:
			ctx.input.tap(&"shoot")


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var sc: Dictionary = s.get("scores", {})
	var shots: Dictionary = s.get("shots", {})
	var ai_shots: int = 0
	for id in shots:
		if str(id) != "b0":
			ai_shots += int(shots[id])
	var moved: bool = maxd.size() > 0
	for id in maxd:
		if str(id) != "b0" and float(maxd[id]) < 3.0:
			moved = false
	var res: String = str(s.get("result", ""))
	var ok: bool = done and str(s.get("winner", "")) != "" and (res == "WIN" or res == "LOSE") and ai_shots >= 1 and moved and puck_total > 30.0
	return {"ok": ok, "summary": "winner %s scores %s shots %s puck %.1f m frames %d ai_shots %d moved %s max %s" % [str(s.get("winner", "")), str(sc), str(shots), puck_total, ctx.frame, ai_shots, str(moved), str(maxd)],
		"frames": ctx.frame, "puck_distance": puck_total}
