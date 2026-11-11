extends RefCounted
## N5a. The world's clock: which pack gets how many ticks. Pure bookkeeping: no node, no physics, no wall clock.
## The world host (world.gd) asks it once per world tick:
##
##   decide(tick, player_position)  -> the events of this tick boundary (already applied and logged)
##   due(tick)                      -> the plots that get this world tick
##
## Tiers (wire values): `stage` (the player is inside the plot: every world tick), `sideline` (near, or next to the
## stage plot: every world tick), `backdrop` (far: one pack tick per `slice` world ticks, round-robin), `ledger` (not
## in memory). A pack only ever sees its own tick count; a tick it does not get is N2's switch-off.
##
## Everything that decides who ticks is an EVENT (`tier`, `slice`, `speed`, `leave`, `return`, `ticket`, `over`,
## `restart`), and `due` is a pure function of the events applied so far. So a world log (the events in order)
## replays to the same ticks for every pack: `apply(event)` instead of `decide`. Thresholds are data: tiers.json.
##
## Rules, in the order `decide` applies them:
##   1. the stage follows the player: he is inside a plot's footprint; he has left it when he is more than
##      margin_m.stage outside AND (he is inside another plot, or dwell_ticks have passed);
##   2. a ticket pins a plot at a tier for a fixed number of world ticks, against distance and against the valve;
##   3. a plot the valve demoted stays at backdrop for valve.hold_ticks, and returns only when it fits again;
##   4. plots next to the stage plot (gap <= adjacent_gap_m) are sideline whatever the distance;
##   5. otherwise distance: promotion at the boundary at once, demotion only beyond boundary + margin and after
##      dwell_ticks at the current tier;
##   6. the budget valve, every valve.every_ticks: while stage + sideline cost more than budget_ms.front, the
##      farthest sideline plot goes to backdrop; `slice` is set so the backdrop costs about budget_ms.backdrop per
##      world tick (within slice.min..max); when nothing is left to demote and the world still costs more than both
##      budgets, `speed` drops: every pack gets fewer ticks, equally. Speed never reaches 0; no pack is switched off.

const RANK: Dictionary = {"stage": 0, "sideline": 1, "backdrop": 2, "ledger": 3}
const NAMES: Array = ["stage", "sideline", "backdrop", "ledger"]

var cfg: Dictionary = {}
var plots: Array = []                   # one Dictionary per plot, see `setup`
var slice: int = 2                      # a backdrop pack gets one tick per `slice` world ticks (at full speed)
var speed_pm: int = 1000                # the world's pace in per mille: 1000 = every pack at its tier's full rate
var stage: int = -1                     # the plot the player is in
var log: Array = []                     # every event, in order
var valve_demotions: int = 0
var speed_min_pm: int = 1000
var slice_max_seen: int = 0
var _tickets: Array = []                # [{tick, plot (index), tier, ticks}]
var _adjacent: Array = []               # per plot: indices of the plots next to it
var _fcredit: int = 0
var _bcredit: int = 0
var _fcursor: int = -1
var _bcursor: int = -1
var _out: Array = []
# N7: the visitor. The stage does not follow the player: an `enter` request puts the plot he stands in on stage, a
# `leave` request takes it off. Requests come from the walk script (`events`) or from a live key (`request`).
var visitor: bool = false
var _visits: Array = []                 # [{t, e: "enter" | "leave", plot (index or -1: the plot he stands in)}]
var _requests: Array = []               # asked for since the last `decide`
# P5: loading is not simulation. With a build queue (`load.mode` queue, step or wait) a plot is `unbuilt` from the start,
# after a `restart`, a `reload` and a return from the ledger, until its `built` event; `due` leaves it out.
var queued: bool = false
var _reloads: Array = []                # [{t, plot (index)}]: the walk's `reload` events


static func load_config(path: String, overrides: Dictionary = {}) -> Dictionary:
	var res: Dictionary = {"ok": false, "error": "", "cfg": {}}
	if not FileAccess.file_exists(path):
		res["error"] = "tiers file not found: " + path
		return res
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		res["error"] = "%s is not a JSON object (line %d: %s)" % [path, json.get_error_line() + 1, json.get_error_message()]
		return res
	var c: Dictionary = json.data
	for k: Variant in overrides.keys():
		if typeof(overrides[k]) == TYPE_DICTIONARY and typeof(c.get(k)) == TYPE_DICTIONARY:
			(c[k] as Dictionary).merge(overrides[k] as Dictionary, true)
		else:
			c[k] = overrides[k]
	for need: String in ["sideline_m", "backdrop_m", "margin_m", "adjacent_gap_m", "dwell_ticks", "default_footprint_m",
			"budget_ms", "slice", "valve", "cost_model_ms"]:
		if not c.has(need):
			res["error"] = "%s lacks '%s'" % [path, need]
			return res
	res["ok"] = true
	res["cfg"] = c
	return res


## The player's position at a world tick, from a script of [tick, [x, y, z]] pairs (straight lines between them).
static func position_at(script: Array, tick: int) -> Vector3:
	if script.is_empty():
		return Vector3.ZERO
	var prev: Array = script[0]
	if tick <= int(prev[0]):
		return _v3(prev[1])
	for i: int in range(1, script.size()):
		var cur: Array = script[i]
		if tick <= int(cur[0]):
			var span: float = maxf(1.0, float(int(cur[0]) - int(prev[0])))
			return _v3(prev[1]).lerp(_v3(cur[1]), float(tick - int(prev[0])) / span)
		prev = cur
	return _v3(prev[1])


static func _v3(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


## `plot_list`: [{id, pack, origin: Vector3, yaw, size: Vector2, on_leave}]; `tickets`: [{tick, plot (id), tier, ticks}].
func setup(config: Dictionary, plot_list: Array, tickets: Array = [], visits: Array = []) -> void:
	cfg = config
	var lc: Variant = cfg.get("load", {})
	queued = typeof(lc) == TYPE_DICTIONARY and ["queue", "step", "wait"].has(str((lc as Dictionary).get("mode", "block")))
	slice = int((cfg["slice"] as Dictionary)["min"])
	slice_max_seen = slice
	var model: Dictionary = cfg["cost_model_ms"]
	for src: Dictionary in plot_list:
		var p: Dictionary = {"id": str(src["id"]), "pack": str(src.get("pack", "")), "origin": src.get("origin", Vector3.ZERO),
			"yaw": float(src.get("yaw", 0.0)), "size": src.get("size", Vector2(40, 40)), "on_leave": str(src.get("on_leave", "pause")),
			"tier": "", "since": 0, "ticket_tier": "", "ticket_until": 0, "valve_until": 0, "held": false, "over": false,
			"cost": float(model.get(str(src.get("pack", "")), model.get("default", 0.5))), "dist": 0.0, "changes": 0,
			"ticks": 0, "last_due": -1, "max_gap": 0, "by_tier": {"stage": 0, "sideline": 0, "backdrop": 0, "ledger": 0},
			"seen": {}, "unbuilt": queued}
		plots.append(p)
	var gap_max: float = float(cfg["adjacent_gap_m"])
	for i: int in plots.size():
		var near: Array = []
		for j: int in plots.size():
			if i != j and _gap(plots[i], plots[j]) <= gap_max:
				near.append(j)
		_adjacent.append(near)
	for t: Dictionary in tickets:
		var idx: int = index_of(str(t.get("plot", "")))
		if idx >= 0 and RANK.has(str(t.get("tier", ""))):
			_tickets.append({"tick": int(t.get("tick", 0)), "plot": idx, "tier": str(t["tier"]), "ticks": int(t.get("ticks", 0))})
	for v: Variant in visits:
		if typeof(v) == TYPE_DICTIONARY and (str((v as Dictionary).get("e", "")) == "enter" or str((v as Dictionary).get("e", "")) == "leave"):
			_visits.append({"t": int((v as Dictionary).get("t", 0)), "e": str((v as Dictionary)["e"]), "plot": index_of(str((v as Dictionary).get("plot", "")))})
		elif typeof(v) == TYPE_DICTIONARY and str((v as Dictionary).get("e", "")) == "reload" and index_of(str((v as Dictionary).get("plot", ""))) >= 0:
			_reloads.append({"t": int((v as Dictionary).get("t", 0)), "plot": index_of(str((v as Dictionary)["plot"]))})


## N7. A live player asks to enter the plot he stands in (or `plot`), or to leave the stage plot. Answered by the
## next `decide`, as events.
func request(what: String, plot: int = -1) -> void:
	_requests.append({"t": -1, "e": what, "plot": plot})


func index_of(id: String) -> int:
	for i: int in plots.size():
		if str((plots[i] as Dictionary)["id"]) == id:
			return i
	return -1


func _gap(a: Dictionary, b: Dictionary) -> float:
	var ao: Vector3 = a["origin"]
	var bo: Vector3 = b["origin"]
	var asz: Vector2 = a["size"]
	var bsz: Vector2 = b["size"]
	var dx: float = maxf(absf(ao.x - bo.x) - (asz.x + bsz.x) * 0.5, 0.0)
	var dz: float = maxf(absf(ao.z - bo.z) - (asz.y + bsz.y) * 0.5, 0.0)
	return sqrt(dx * dx + dz * dz)


## Metres from `pos` to the nearest edge of the plot's footprint; 0 inside.
func distance(p: Dictionary, pos: Vector3) -> float:
	var o: Vector3 = p["origin"]
	var sz: Vector2 = p["size"]
	var local: Vector2 = Vector2(pos.x - o.x, pos.z - o.z).rotated(float(p["yaw"]))
	var dx: float = maxf(absf(local.x) - sz.x * 0.5, 0.0)
	var dz: float = maxf(absf(local.y) - sz.y * 0.5, 0.0)
	return sqrt(dx * dx + dz * dz)


func _rank_by(d: float, extra_side: float, extra_back: float) -> int:
	if d <= float(cfg["sideline_m"]) + extra_side:
		return 1
	var back: float = float(cfg["backdrop_m"])
	if back <= 0.0 or d <= back + extra_back:
		return 2
	return 3


func _emit(ev: Dictionary) -> void:
	apply(ev)
	_out.append(ev)


## Applies one event to the schedule and logs it. `decide` goes through here; a replay calls it with a log's events.
func apply(ev: Dictionary) -> void:
	log.append(ev)
	var t: int = int(ev.get("t", 0))
	var i: int = index_of(str(ev.get("plot", ""))) if ev.has("plot") else -1
	match str(ev.get("e", "")):
		"tier":
			if i < 0:
				return
			var p: Dictionary = plots[i]
			var to: String = str(ev["to"])
			if str(ev.get("why", "")) != "start":
				p["changes"] = int(p["changes"]) + 1
			if str(ev.get("why", "")) == "valve":
				p["valve_until"] = t + int((cfg["valve"] as Dictionary)["hold_ticks"])
				valve_demotions += 1
			if stage == i and to != "stage":
				stage = -1
				p["over_at"] = t                  # N7: the pause before its next round counts from here
			if to == "stage":
				stage = i
			if str(ev.get("from", "")) == "ledger":
				p["rest_until"] = t + 1           # N7: rebuilt on this tick boundary, first tick on the next (see `due`)
				p["unbuilt"] = queued             # P5: with a queue it arrives with its own `built` event
			p["tier"] = to
			p["since"] = t
			(p["seen"] as Dictionary)[to] = true
		"slice":
			slice = maxi(1, int(ev["slice"]))
			slice_max_seen = maxi(slice_max_seen, slice)
		"speed":
			speed_pm = clampi(int(ev["pm"]), 1, 1000)
			speed_min_pm = mini(speed_min_pm, speed_pm)
		"leave":
			if i >= 0:
				if str(ev.get("on_leave", "")) == "pause":
					(plots[i] as Dictionary)["held"] = true
				elif str(ev.get("on_leave", "")) == "end":
					(plots[i] as Dictionary)["over"] = true
		"return":
			if i >= 0:
				(plots[i] as Dictionary)["held"] = false
		"ticket":
			if i >= 0:
				(plots[i] as Dictionary)["ticket_tier"] = str(ev["tier"])
				(plots[i] as Dictionary)["ticket_until"] = t + int(ev["ticks"])
		"over":
			if i >= 0:
				(plots[i] as Dictionary)["over"] = true
				(plots[i] as Dictionary)["over_at"] = t
		"restart":
			if i >= 0:
				(plots[i] as Dictionary)["over"] = false
				(plots[i] as Dictionary)["rest_until"] = t + 1
				(plots[i] as Dictionary)["unbuilt"] = queued
		"reload":
			if i >= 0:                        # P5: a fresh copy of the same directory takes the plot
				(plots[i] as Dictionary)["rest_until"] = t + 1
				(plots[i] as Dictionary)["unbuilt"] = queued
		"built":
			if i >= 0:                        # P5: attached on this tick boundary, first tick on the next
				(plots[i] as Dictionary)["unbuilt"] = false
				(plots[i] as Dictionary)["rest_until"] = t + 1


func _active(p: Dictionary) -> bool:
	return not bool(p["over"]) and not bool(p["held"])


func _front_cost() -> float:
	var sum: float = 0.0
	for p: Dictionary in plots:
		if _active(p) and (str(p["tier"]) == "stage" or str(p["tier"]) == "sideline"):
			sum += float(p["cost"])
	return sum


## The decisions of one tick boundary. Returns this tick's events (already applied and logged).
func decide(tick: int, pos: Vector3) -> Array:
	_out = []
	var dwell: int = int(cfg["dwell_ticks"])
	var margin: Dictionary = cfg["margin_m"]
	var valve: Dictionary = cfg["valve"]
	var budget: Dictionary = cfg["budget_ms"]
	for tk: Dictionary in _tickets:
		if int(tk["tick"]) == tick:
			_emit({"t": tick, "e": "ticket", "plot": (plots[int(tk["plot"])] as Dictionary)["id"], "tier": tk["tier"], "ticks": tk["ticks"]})
	for r: Dictionary in _reloads:
		if int(r["t"]) == tick and str((plots[int(r["plot"])] as Dictionary)["tier"]) != "ledger":
			_emit({"t": tick, "e": "reload", "plot": (plots[int(r["plot"])] as Dictionary)["id"]})
	var inside: int = -1
	for i: int in plots.size():
		var p: Dictionary = plots[i]
		p["dist"] = distance(p, pos)
		if inside < 0 and float(p["dist"]) == 0.0:
			inside = i
	# 1. the stage follows the player (N7, a world with a visitor: it follows his `enter` and `leave` instead)
	var cur: int = stage
	var want_stage: int = inside
	if visitor:
		_decide_visits(tick, inside, float(margin["stage"]))
		cur = stage
		want_stage = stage
	if cur >= 0:
		var pc: Dictionary = plots[cur]
		if float(pc["dist"]) <= float(margin["stage"]):
			want_stage = cur
		elif inside < 0 and tick - int(pc["since"]) < dwell:
			want_stage = cur
	if want_stage != cur:
		if cur >= 0:
			var pc: Dictionary = plots[cur]
			var to_rank: int = maxi(1, _rank_by(float(pc["dist"]), 0.0, 0.0))
			if want_stage >= 0 and (_adjacent[want_stage] as Array).has(cur):
				to_rank = 1
			_emit({"t": tick, "e": "tier", "plot": pc["id"], "from": "stage", "to": NAMES[to_rank], "why": "left"})
			_emit({"t": tick, "e": "leave", "plot": pc["id"], "on_leave": pc["on_leave"]})
		if want_stage >= 0:
			var pn: Dictionary = plots[want_stage]
			if bool(pn["held"]):
				_emit({"t": tick, "e": "return", "plot": pn["id"]})
			if bool(pn["over"]) and str(pn["on_leave"]) == "end":
				_emit({"t": tick, "e": "restart", "plot": pn["id"], "why": "return"})
			_emit({"t": tick, "e": "tier", "plot": pn["id"], "from": pn["tier"], "to": "stage", "why": "player" if tick > 0 or str(pn["tier"]) != "" else "start"})
	# 2. to 5. every other plot
	var front_now: float = _front_cost()
	for i: int in plots.size():
		if i == stage:
			continue
		var p: Dictionary = plots[i]
		var c: int = int(RANK.get(str(p["tier"]), 99))
		var want: int = c
		var why: String = "distance"
		var d: float = float(p["dist"])
		if int(p["valve_until"]) > 0 and int(p["valve_until"]) <= tick:
			# the hold is over: back by distance only when it fits again, with room to spare
			if speed_pm == 1000 and front_now + float(p["cost"]) <= float(budget["front"]) * float(valve["recover"]):
				p["valve_until"] = 0
			else:
				p["valve_until"] = tick + int(valve["hold_ticks"])
		if int(p["ticket_until"]) > tick:
			want = int(RANK[str(p["ticket_tier"])])
			why = "ticket"
		elif int(p["valve_until"]) > tick:
			want = maxi(c, 2) if c != 99 else 2
			why = "valve_hold"
		elif stage >= 0 and (_adjacent[stage] as Array).has(i):
			want = 1
			why = "adjacent"
		else:
			var near: int = _rank_by(d, 0.0, 0.0)
			var far: int = _rank_by(d, float(margin["sideline"]), float(margin["backdrop"]))
			if c == 99:
				want = near
				why = "start"
			elif near < c:
				want = near
			elif far > c and tick - int(p["since"]) >= dwell:
				want = far
		if c == 99 and why != "start":
			why = "start"
		if want != c:
			if want == 1 and c > 1:
				front_now += float(p["cost"])
			_emit({"t": tick, "e": "tier", "plot": p["id"], "from": p["tier"], "to": NAMES[want], "why": why})
	# 6. the budget valve
	if tick > 0 and tick % maxi(1, int(valve["every_ticks"])) == 0:
		_valve(tick, valve, budget)
	return _out


## N7. The visitor's requests of this tick, then the next round of every game that ended by itself and is not on
## stage (`restart_pause_ticks` after it ended, or after the visitor left it; 0 = never).
func _decide_visits(tick: int, inside: int, stage_margin: float) -> void:
	var asks: Array = _requests
	_requests = []
	for v: Dictionary in _visits:
		if int(v["t"]) == tick:
			asks.append(v)
	for a: Dictionary in asks:
		if str(a["e"]) == "leave":
			if stage < 0:
				_emit({"t": tick, "e": "refused", "ask": "leave", "why": "no game is on stage"})
				continue
			var pc: Dictionary = plots[stage]
			_emit({"t": tick, "e": "tier", "plot": pc["id"], "from": "stage", "to": "sideline", "why": "leave"})
			_emit({"t": tick, "e": "leave", "plot": pc["id"], "on_leave": pc["on_leave"]})
		else:
			var target: int = int(a["plot"]) if int(a["plot"]) >= 0 else inside
			if stage >= 0 or target < 0 or float((plots[target] as Dictionary)["dist"]) > stage_margin:
				_emit({"t": tick, "e": "refused", "ask": "enter", "plot": str((plots[target] as Dictionary)["id"]) if target >= 0 else "",
					"why": "a game is on stage already" if stage >= 0 else ("the visitor stands in no plot" if target < 0 else "the visitor is outside that plot")})
				continue
			var pn: Dictionary = plots[target]
			if bool(pn["held"]):
				_emit({"t": tick, "e": "return", "plot": pn["id"]})
			if bool(pn["over"]):
				_emit({"t": tick, "e": "restart", "plot": pn["id"], "why": "enter"})
			_emit({"t": tick, "e": "tier", "plot": pn["id"], "from": pn["tier"], "to": "stage", "why": "enter"})
	var pause: int = int(cfg.get("restart_pause_ticks", 0))
	if pause > 0:
		for i: int in plots.size():
			var p: Dictionary = plots[i]
			if i != stage and bool(p["over"]) and not bool(p["held"]) and str(p["on_leave"]) != "end" and str(p["tier"]) != "ledger" 					and tick - int(p.get("over_at", tick)) >= pause:
				_emit({"t": tick, "e": "restart", "plot": p["id"], "why": "next_round"})


func _valve(tick: int, valve: Dictionary, budget: Dictionary) -> void:
	var front: float = 0.0
	var back: float = 0.0
	for p: Dictionary in plots:
		if not _active(p):
			continue
		if str(p["tier"]) == "stage" or str(p["tier"]) == "sideline":
			front += float(p["cost"])
		elif str(p["tier"]) == "backdrop":
			back += float(p["cost"])
	var left_to_demote: bool = false
	while true:
		var cand: int = -1
		for i: int in plots.size():
			var p: Dictionary = plots[i]
			if _active(p) and str(p["tier"]) == "sideline" and int(p["ticket_until"]) <= tick:
				if cand < 0 or float(p["dist"]) > float((plots[cand] as Dictionary)["dist"]):
					cand = i
		left_to_demote = cand >= 0
		if front <= float(budget["front"]) or cand < 0:
			break
		var pc: Dictionary = plots[cand]
		_emit({"t": tick, "e": "tier", "plot": pc["id"], "from": "sideline", "to": "backdrop", "why": "valve"})
		front -= float(pc["cost"])
		back += float(pc["cost"])
	var limits: Dictionary = cfg["slice"]
	var want_slice: int = clampi(ceili(back / maxf(0.001, float(budget["backdrop"]))), int(limits["min"]), int(limits["max"]))
	if want_slice != slice:
		_emit({"t": tick, "e": "slice", "slice": want_slice})
	var total: float = front + back / float(slice)
	var all: float = float(budget["front"]) + float(budget["backdrop"])
	var step: int = maxi(1, int(valve["speed_step_pm"]))
	var want_speed: int = 1000
	if total > all and not (front > float(budget["front"]) and left_to_demote):
		want_speed = clampi(int(floor(all / total * 1000.0 / float(step))) * step, int(valve["speed_min_pm"]), 1000)
	if want_speed < speed_pm:
		_emit({"t": tick, "e": "speed", "pm": want_speed, "why": "valve"})
	elif want_speed > speed_pm and total * float(speed_pm + step) / 1000.0 <= all * float(valve["recover"]):
		_emit({"t": tick, "e": "speed", "pm": mini(1000, speed_pm + step), "why": "recover"})


func _next_in(ring: Array, cursor: int) -> int:
	for i: int in ring:
		if i > cursor:
			return i
	return int(ring[0])


## The plots that get world tick `tick`. A pure function of the events applied so far (and of the calls before).
func due(tick: int) -> Array:
	var front: Array = []
	var back: Array = []
	for i: int in plots.size():
		var p: Dictionary = plots[i]
		if not _active(p):
			continue
		# N7: a pack that was built again on this tick boundary (next round, back from the ledger) gets its first tick
		# on the next one. Its nodes entered the tree inside this physics frame and the scene tree would not tick them
		# in it, while the kernel's own calls and the physics step would run: its first tick would be half a tick.
		if int(p.get("rest_until", 0)) > tick or bool(p.get("unbuilt", false)):
			continue
		if str(p["tier"]) == "stage" or str(p["tier"]) == "sideline":
			front.append(i)
		elif str(p["tier"]) == "backdrop":
			back.append(i)
	var out: Array = []
	if front.is_empty():
		_fcredit = 0
	else:
		_fcredit += front.size() * speed_pm
		var n: int = mini(_fcredit / 1000, front.size())
		_fcredit -= n * 1000
		_fcredit = mini(_fcredit, 999)
		for k: int in n:
			_fcursor = _next_in(front, _fcursor)
			out.append(_fcursor)
	if back.is_empty():
		_bcredit = 0
	else:
		var unit: int = 1000 * slice
		_bcredit += back.size() * speed_pm
		var n: int = mini(_bcredit / unit, back.size())
		_bcredit -= n * unit
		_bcredit = mini(_bcredit, unit - 1)
		for k: int in n:
			_bcursor = _next_in(back, _bcursor)
			out.append(_bcursor)
	for i: int in out:
		var p: Dictionary = plots[i]
		p["ticks"] = int(p["ticks"]) + 1
		(p["by_tier"] as Dictionary)[str(p["tier"])] = int((p["by_tier"] as Dictionary)[str(p["tier"])]) + 1
		if int(p["last_due"]) >= 0:
			p["max_gap"] = maxi(int(p["max_gap"]), tick - int(p["last_due"]))
		p["last_due"] = tick
	return out


## P5. Called by the world's build queue when the pack of plot `i` is attached at this tick boundary.
func mark_built(tick: int, i: int) -> Dictionary:
	var ev: Dictionary = {"t": tick, "e": "built", "plot": (plots[i] as Dictionary)["id"]}
	apply(ev)
	return ev


## Called by the world when a pack's game has ended by itself (its bot is done).
func mark_over(tick: int, i: int, own_ticks: int) -> Dictionary:
	var ev: Dictionary = {"t": tick, "e": "over", "plot": (plots[i] as Dictionary)["id"], "ticks": own_ticks}
	apply(ev)
	return ev
