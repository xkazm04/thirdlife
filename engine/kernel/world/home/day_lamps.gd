extends RefCounted
## Lane DN (day of 27 Nov 2026): the Home's lamps. The pieces that carry a light (street_lamp, house, light_mast: the
## kit's own OmniLight3D and SpotLight3D) are drawn instanced like every other piece (build/piece_draw.gd); what they
## light with is a SOCKET here: the kit light as a template, and where it stands in the world. At most CAP sockets
## burn at once (a light costs per pixel it reaches): every CHOOSE_EVERY physics frames the sockets that are on are
## sorted by their distance to the camera and the CAP nearest get one of CAP light nodes (a live one keeps its node
## unless another is nearer than KEEP of its distance, so the choice does not flicker at its edge). A newly lit node
## fades in over FADE frames. A lamp is on when the day's lamp strength (style_day.gd day_look "lamps", 0 by day) is above
## its own threshold (0.05..0.30, from where it stands): at dusk the lamps come on one by one, at dawn they go out.
## By day nothing burns and the light nodes are hidden. Visual only: nothing here touches a body or a state hash.

const CAP := 48
const CHOOSE_EVERY := 15
const KEEP := 0.81                     # a live socket's squared distance is weighed by this (0.9 of its distance)
const FADE := 12
## Round 2 (27 Nov): a street lamp only burns at dusk and at night, where the kit's lantern light (half a house window,
## 10.8 m) left a faint patch beside the light mast's pool. Its socket burns brighter, reaches further and falls off
## flatter, in a warmer colour: the mast's pool is the bar. Factors on the kit's values (energy, range), values to set.
const NIGHT := {"street_lamp": {"light_energy": 2.4, "omni_range": 1.6, "omni_attenuation": 0.9, "light_color": "#ffb04c"}}
## what a light node takes from another template of its own kind when its slot moves to it
const PROPS: PackedStringArray = ["light_color", "light_specular", "light_indirect_energy", "light_size", "shadow_enabled",
	"omni_range", "omni_attenuation", "spot_range", "spot_angle", "spot_angle_attenuation", "spot_attenuation"]

var holder: Node3D = null              # "HomeLamps" (null: sockets and choices only, nothing drawn)
var templates := {}                    # template key -> {"class": "OmniLight3D" | "SpotLight3D", PROPS and light_energy}
var sockets := {}                      # section -> Array of [id, template key, Transform3D, threshold]
var slots: Array = []                  # CAP of {"id": String ("" free), "node": Light3D or null, "key": String, "fade": int}
var gain := 0.0                        # lamp strength now (0: off)
var cam_at := Vector3.ZERO
var _frame := 0
var _dirty := true
var stats := {"choices": 0, "swaps": 0, "on": 0, "live": 0, "sockets": 0, "max_live_d": 0.0, "min_out_d": -1.0}


func _init(parent: Node3D) -> void:
	for i: int in CAP:
		slots.append({"id": "", "node": null, "key": "", "fade": 0})
	if parent != null:
		holder = Node3D.new()
		holder.name = "HomeLamps"
		parent.add_child(holder)


## The lights a built part carries: [[template key, template, local Transform3D], ...] (`key` names the part). A template
## is data ({"class", the light's PROPS and light_energy}), never a node: nothing out of the tree is left to leak.
static func lights_of(n: Node, key: String) -> Array:
	var out := []
	_walk(n, Transform3D.IDENTITY, key, out)
	return out


static func _walk(n: Node, xf: Transform3D, key: String, out: Array) -> void:
	for c: Node in n.get_children():
		var cx := xf * (c as Node3D).transform if c is Node3D else xf
		if c is Light3D:
			var tpl := {"class": c.get_class(), "light_energy": (c as Light3D).light_energy}
			for prop: String in PROPS:
				if prop in c:
					tpl[prop] = c.get(prop)
			out.append(["%s#%d" % [key, out.size()], tpl, cx])
		_walk(c, cx, key, out)


func add_template(key: String, tpl: Dictionary) -> void:
	if templates.has(key):
		return
	var t := tpl.duplicate()
	var part := key.get_slice("|", 0)
	for prop: String in (NIGHT.get(part, {}) as Dictionary):
		var v: Variant = NIGHT[part][prop]
		if prop == "light_color":
			t[prop] = Color(String(v))
		elif prop == "omni_attenuation":
			t[prop] = v
		elif t.has(prop):
			t[prop] = float(t[prop]) * float(v)
	templates[key] = t


## Section `s` lights from these sockets now: [[template key, world Transform3D], ...] ([] clears it).
func set_section(s: Vector2i, list: Array) -> void:
	if list.is_empty():
		if sockets.erase(s):
			_dirty = true
		return
	var out := []
	for i: int in list.size():
		var xf: Transform3D = list[i][1]
		var p := xf.origin
		var h := absi(hash(Vector3i(roundi(p.x * 10.0), roundi(p.y * 10.0), roundi(p.z * 10.0)))) % 1000
		out.append(["%d,%d:%d" % [s.x, s.y, i], str(list[i][0]), xf, 0.05 + 0.25 * h / 1000.0])
	sockets[s] = out
	_dirty = true


func count() -> int:
	var n := 0
	for s: Vector2i in sockets:
		n += (sockets[s] as Array).size()
	return n


## Once per physics frame: the lamp strength `g` and the camera's position.
func update(g: float, cam: Vector3) -> void:
	_frame += 1
	var was_off := gain <= 0.0
	var moved_on := false
	if g != gain:
		for s: Vector2i in sockets:
			for sk: Array in sockets[s]:
				if (gain >= float(sk[3])) != (g >= float(sk[3])):
					moved_on = true
	gain = g
	cam_at = cam
	if g <= 0.0:
		if not was_off:
			for sl: Dictionary in slots:
				if sl.node != null:
					(sl.node as Light3D).visible = false
				sl.id = ""
			stats.live = 0
			stats.on = 0
		return
	if _dirty or moved_on or was_off or _frame % CHOOSE_EVERY == 0:
		_choose()
	for sl: Dictionary in slots:
		if sl.node == null or str(sl.id) == "":
			continue
		if int(sl.fade) < FADE:
			sl.fade = int(sl.fade) + 1
		var t: Dictionary = templates.get(sl.key, {})
		(sl.node as Light3D).light_energy = float(t.get("light_energy", 1.0)) * g * float(sl.fade) / FADE


func _choose() -> void:
	_dirty = false
	stats.choices += 1
	var live_ids := {}
	for sl: Dictionary in slots:
		if str(sl.id) != "":
			live_ids[sl.id] = true
	var cand := []
	var total := 0
	for s: Vector2i in sockets:
		for sk: Array in sockets[s]:
			total += 1
			if gain < float(sk[3]):
				continue
			var d2: float = cam_at.distance_squared_to((sk[2] as Transform3D).origin)
			cand.append([d2 * (KEEP if live_ids.has(sk[0]) else 1.0), sk, d2])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and str(a[1][0]) < str(b[1][0])))
	var want := {}
	var max_live := 0.0
	for i: int in mini(CAP, cand.size()):
		want[cand[i][1][0]] = cand[i][1]
		max_live = maxf(max_live, sqrt(float(cand[i][2])))
	var min_out := -1.0
	for i: int in range(CAP, cand.size()):
		var d := sqrt(float(cand[i][2]))
		min_out = d if min_out < 0.0 else minf(min_out, d)
	stats.sockets = total
	stats.on = cand.size()
	stats.live = want.size()
	stats.max_live_d = max_live
	stats.min_out_d = min_out
	# slots whose socket is no longer wanted (or moved: its section was redrawn) are freed
	for sl: Dictionary in slots:
		if str(sl.id) != "" and (not want.has(sl.id) or not _same(sl, want[sl.id])):
			sl.id = ""
			if sl.node != null:
				(sl.node as Light3D).visible = false
	var held := {}
	for sl: Dictionary in slots:
		if str(sl.id) != "":
			held[sl.id] = true
	for id: String in want:
		if held.has(id):
			continue
		var sk: Array = want[id]
		var slot: Dictionary = {}
		for sl: Dictionary in slots:
			if str(sl.id) == "" and str(sl.key) == str(sk[1]):
				slot = sl
				break
		if slot.is_empty():
			for sl: Dictionary in slots:
				if str(sl.id) == "":
					slot = sl
					break
		_assign(slot, sk)
		stats.swaps += 1


func _same(sl: Dictionary, sk: Array) -> bool:
	return str(sl.key) == str(sk[1]) and sl.node != null and (sl.node as Node3D).transform.is_equal_approx(sk[2])


func _assign(sl: Dictionary, sk: Array) -> void:
	sl.id = sk[0]
	sl.fade = 0
	if holder == null or not templates.has(sk[1]):
		sl.key = sk[1]
		return
	var tpl: Dictionary = templates[sk[1]]
	if sl.node == null or (str(sl.key) != str(sk[1]) and (sl.node as Object).get_class() != str(tpl["class"])):
		if sl.node != null:
			(sl.node as Node).queue_free()
		var l := ClassDB.instantiate(str(tpl["class"])) as Light3D
		l.name = "Lamp%d" % slots.find(sl)
		holder.add_child(l)
		sl.node = l
		sl.key = ""
	if str(sl.key) != str(sk[1]):
		for prop: String in tpl:
			if prop != "class":
				(sl.node as Object).set(prop, tpl[prop])     # the template's values (a node of the same kind is reused)
	sl.key = sk[1]
	var n: Light3D = sl.node
	n.transform = sk[2]
	n.light_energy = 0.0
	n.visible = true


## {"cap", "sockets", "on", "live", "nodes" (light nodes drawn now), "max_live_d", "min_out_d", "choices", "swaps"}.
func figures() -> Dictionary:
	var drawn := 0
	for sl: Dictionary in slots:
		if sl.node != null and (sl.node as Light3D).visible and str(sl.id) != "":
			drawn += 1
	var f := stats.duplicate()
	f["cap"] = CAP
	f["sockets"] = count()
	f["nodes"] = drawn
	return f


func free_all() -> void:
	sockets.clear()
	for sl: Dictionary in slots:
		if sl.node != null and is_instance_valid(sl.node):
			(sl.node as Node).queue_free()
		sl.node = null
		sl.id = ""
	if holder != null and is_instance_valid(holder):
		holder.queue_free()
	holder = null
