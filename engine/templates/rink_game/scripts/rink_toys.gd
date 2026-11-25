extends RefCounted
## The cartridge's toys on the ice (lane E1b, 25 Nov): everything a cartridge can put on the rink besides the rink itself,
## drawn from the cartridge and the core's snapshot, never placed by hand. A user's "slow and fast patches and bumpers in
## the corners" is a game only when a person SEES the patches and the bumpers (E5 job 2: the core played them on plain ice).
##   zones      game.rink.zones[] (slow_ice, fast_ice, bumper, no_shoot, boost_only; rect or circle; `visible` false = not
##              painted): ARinkActor::Build's zone decals (S/JamGame/Private/RinkActor.cpp:668-840, thirdjam HEAD 8dc713c6): a
##              flat fill 0.8 cm over the ice (over the markings at 0.6) and a 25 cm rim, the kind's tint x (0.5 + 0.5 x
##              strength), the rim x 1.35; and lane A69's clay ring (cpp:722-780: a ring 6 cm high, 12 cm wide on the outline).
##              Ours on the felt ice: the fill is the tint laid over the ice's own white (a tinted patch, the markings under
##              it hidden as thirdjam's decal hides them), the ring stands proud so the edge reads from the game camera, and
##              each kind carries its own mark so it reads without its colour: fast ice streaks along the rink, slow ice
##              slush dots, a bumper zone a rubber curb, no-shoot a red cross-hatch, boost-only a plus.
##   obstacles  game.rink.obstacles[] (box, pillar, bumper, goal_shield): RinkActor.cpp:1154-1240: boxes and pillars 1.2 m
##              tall in the boards' colour, a goal shield a pale wall `size` wide and 0.3 m deep across the rink, a bumper
##              lane A64's rubber bollard (a magenta body, dark base and top bands 3 cm proud, a dark lid with a magenta boss).
##   pickups    game.pickups[] on the ice (UJamEffectSystem::GetPickups): the snapshot's `Pickups` list ([{Id, Kind, Pos}],
##              FJamPickupOnIce) when the core reports it, else the bus: a `pickup_spawn` event puts one at its Where, a
##              `pickup_take` takes the one at its Where. NOTE (25 Nov): RinkCore 1.3 reports neither (its Events are the
##              sim's only, the effect system keeps its own; rink_core.cpp snapshot), so a cartridge's pickups play unseen
##              until the core adds them (lane E1b's report asks K1/E2); this draws them the frame it does.
##              AJamPickupActor's beacon (S/JamCore/Effects/JamPickupActor.cpp:315-420, JamPickupActor.h:40-80): a turning
##              shape by kind (speed a cone, precision a diamond, heavy_puck a puck, big_puck a ball, reverse_other a cube,
##              a custom effect a star) 1.25 m up on a pedestal of light, a ground ring of 1.1 m, the kind's colour
##              (JamEffects::KindColour, JamEffectTypes.cpp:77-87); lowered to 0.35 when a skater or the puck is within
##              1.6 m (BeaconHeightFor). A taken pickup shrinks away over 18 frames where it lay.
## Presentation only: it reads the cartridge and the snapshot and steps nothing; the match hash cannot move. Colours are
## thirdjam's linear values on the palette's white (the toon shader multiplies the palette colour by the vertex colour), so
## the pack makes no material of its own (TLMesh, palette keys).

const ZONE_Y: float = 0.008                 # RinkActor.cpp:698 ZH 0.8 cm
const RIM_W: float = 0.25                   # RimW 25 cm
const RING_H: float = 0.06                  # lane A69: the clay ring 6 cm high, 12 cm wide
const RING_W: float = 0.12
const BOARD_H: float = 1.2                  # RinkActor.h BoardHeightM
const ICE := Color(0.88, 0.93, 0.98)        # the ice the tint is laid over
const DARK := Color(0.06, 0.06, 0.07)       # MI_Toon_Dark (cpp:1232)
const BOARD := Color(0.93, 0.90, 0.87)      # MI_Toon_Board: the boards' paint
const SHIELD := Color(0.86, 0.88, 0.90)     # MI_Toon_GoalShield: pale grey-white
const BUMPER := Color(0.9, 0.2, 0.6)        # cpp:1219: the bumper's magenta

## RinkActor.cpp:807-815 ZoneTint (linear).
const ZONE_TINT: Dictionary = {
	"slow_ice": Color(0.35, 0.55, 0.95),
	"fast_ice": Color(0.95, 0.45, 0.15),
	"bumper": Color(0.9, 0.2, 0.6),
	"no_shoot": Color(0.85, 0.15, 0.15),
	"boost_only": Color(0.2, 0.85, 0.4),
}
## JamEffects::KindColour (JamEffectTypes.cpp:77-87, linear); a custom effect white.
const PICKUP_COLOUR: Dictionary = {
	"speed": Color(0.1, 0.9, 1.0),
	"precision": Color(1.0, 0.2, 0.9),
	"heavy_puck": Color(0.55, 0.3, 1.0),
	"big_puck": Color(1.0, 0.75, 0.1),
	"reverse_other": Color(1.0, 0.15, 0.1),
}
const HOVER_M: float = 0.45                 # JamPickupActor.h:40 HoverM (the token)
const BEACON_OBJECT_M: float = 1.25         # :72 the shape's centre over the ice
const BEACON_SIZE_M: float = 0.8            # :73 the shape's largest side
const BEACON_PEDESTAL_M: float = 1.0        # :74
const BEACON_PEDESTAL_W: float = 0.2        # :75
const BEACON_RING_R: float = 1.1            # :76
const BEACON_CLEAR_M: float = 1.6           # :78 a skater or the puck this close: the low profile
const BEACON_LOW: float = 0.35              # :79
const SPIN_DEG_PER_FRAME: float = 2.0       # :80 120 degrees a second
const TAKEN_FRAMES: int = 18

var root: Node3D
var zones_drawn: int = 0
var obstacles_drawn: int = 0
var pickups: Array = []                     # [{node, shape, kind, pos: Vector2, born: int, height: float}] on the ice now
var taken: Array = []                       # [{node, frame}] shrinking away
var spawned: int = 0
var took: int = 0
var reported: bool = false                  # the core reported pickups (a Pickups list or a pickup event) at least once
var _last_frame: int = -1


func _init(parent: Node3D, cart: Dictionary) -> void:
	root = Node3D.new()
	root.name = "RinkToys"
	parent.add_child(root)
	var rk: Dictionary = (cart.get("game", {}) as Dictionary).get("rink", {})
	var zones: Array = rk.get("zones", [])
	var obstacles: Array = rk.get("obstacles", [])
	if not zones.is_empty():
		var mk := TLMesh.new(47)
		for z: Dictionary in zones:
			if bool(z.get("visible", true)):
				_zone(mk, z)
				zones_drawn += 1
		if zones_drawn > 0:
			var mi: MeshInstance3D = mk.instance("Zones")
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # cpp:272: the decals cast nothing
			root.add_child(mi)
	if not obstacles.is_empty():
		var om := TLMesh.new(48)
		for o: Dictionary in obstacles:
			_obstacle(om, o)
			obstacles_drawn += 1
		root.add_child(om.instance("Obstacles"))
	root.set_meta(&"toys", counts())             # what is drawn, for a test (tests/bot_toys.gd)


## What is drawn, for a test or a report.
func counts() -> Dictionary:
	return {"zones": zones_drawn, "obstacles": obstacles_drawn, "pickups_on_ice": pickups.size(), "spawned": spawned, "taken": took,
		"reported": reported}


# ---------------------------------------------------------------- zones
static func _tint(kind: String, strength: float) -> Color:
	var base: Color = ZONE_TINT.get(kind, Color(0.6, 0.6, 0.6))   # cpp:814: an unknown kind neutral grey rather than nothing
	var k: float = 0.5 + 0.5 * clampf(strength, 0.0, 1.0)         # cpp:821
	return Color(base.r * k, base.g * k, base.b * k)


func _zone(mk: TLMesh, z: Dictionary) -> void:
	var kind: String = String(z.get("kind", ""))
	var s: float = float(z.get("strength", 0.5))                 # CARTRIDGE.md: absent = 0.5
	var tint: Color = _tint(kind, s)
	# the tint over the ice's white, deeper for a stronger zone; the rim darker than the fill (thirdjam's rim is x 1.35 brighter,
	# cpp:823: on our lit felt ice a brighter rim melts into the white, a darker one draws the edge)
	var fill: Color = ICE.lerp(tint, 0.7 + 0.3 * clampf(s, 0.0, 1.0))
	var rim: Color = tint.darkened(0.3)
	var c := Vector2(float(z.get("x", 0.0)), float(z.get("z", 0.0)))
	var circle: bool = String(z.get("shape", "rect")) == "circle"
	var hx: float = float(z.get("w", 1.0)) * 0.5
	var hy: float = float(z.get("d", 1.0)) * 0.5
	var r: float = float(z.get("r", 1.0))
	var ring_key: String = "black" if kind == "bumper" else "white"
	var ring_col: Color = Color.WHITE if kind == "bumper" else rim
	var ring_h: float = 0.14 if kind == "bumper" else RING_H        # a bumper zone's edge throws the puck back: a rubber curb
	var ring_w: float = 0.22 if kind == "bumper" else RING_W
	if circle:
		_disc(mk, c, 0.0, r, ZONE_Y, fill)
		_disc(mk, c, maxf(0.0, r - RIM_W), r, ZONE_Y + 0.001, rim)
		var n: int = 48
		for i: int in n:
			var a0: float = TAU * float(i) / float(n)
			var a1: float = TAU * float(i + 1) / float(n)
			mk.bar(Vector3(c.x + cos(a0) * r, ring_h * 0.5, c.y + sin(a0) * r), Vector3(c.x + cos(a1) * r, ring_h * 0.5, c.y + sin(a1) * r), ring_w, ring_h, ring_key, ring_col)
	else:
		var x0: float = c.x - hx
		var x1: float = c.x + hx
		var y0: float = c.y - hy
		var y1: float = c.y + hy
		_rect(mk, x0, y0, x1, y1, ZONE_Y, fill)
		var b: float = minf(RIM_W, minf(hx, hy))
		_rect(mk, x0, y0, x1, y0 + b, ZONE_Y + 0.001, rim)
		_rect(mk, x0, y1 - b, x1, y1, ZONE_Y + 0.001, rim)
		_rect(mk, x0, y0, x0 + b, y1, ZONE_Y + 0.001, rim)
		_rect(mk, x1 - b, y0, x1, y1, ZONE_Y + 0.001, rim)
		var e: float = ring_w * 0.5
		for seg: Array in [[Vector2(x0 - e, y0), Vector2(x1 + e, y0)], [Vector2(x0 - e, y1), Vector2(x1 + e, y1)], [Vector2(x0, y0), Vector2(x0, y1)], [Vector2(x1, y0), Vector2(x1, y1)]]:
			var p0: Vector2 = seg[0]
			var p1: Vector2 = seg[1]
			mk.bar(Vector3(p0.x, ring_h * 0.5, p0.y), Vector3(p1.x, ring_h * 0.5, p1.y), ring_w, ring_h, ring_key, ring_col)
	_kind_mark(mk, kind, c, circle, hx, hy, r, rim)


## Each kind's own mark inside the patch (ours: thirdjam's B looks MI_Zone_<kind> carry patterns we do not have), so a
## patch reads by its shape as well as its colour. Laid out on a fixed grid: no randomness.
func _kind_mark(mk: TLMesh, kind: String, c: Vector2, circle: bool, hx: float, hy: float, r: float, col: Color) -> void:
	var y: float = ZONE_Y + 0.002
	var ex: float = r * 0.7 if circle else hx - RIM_W * 2.0
	var ey: float = r * 0.7 if circle else hy - RIM_W * 2.0
	if ex <= 0.3 or ey <= 0.3:
		return
	var light: Color = col.lerp(Color.WHITE, 0.55)
	match kind:
		"fast_ice":
			# speed streaks along the rink: dashes 2.4 m long, 0.16 m wide, rows 1.1 m apart, staggered
			var row: int = 0
			var yy: float = -ey + 0.4
			while yy <= ey - 0.4:
				var xx: float = -ex + (1.6 if row % 2 == 1 else 0.2)
				while xx + 2.4 <= ex:
					if not circle or Vector2(xx + 1.2, yy).length() < r * 0.85:
						_strip(mk, Vector2(c.x + xx, c.y + yy), Vector2(c.x + xx + 2.4, c.y + yy), 0.08, y, light)
					xx += 3.2
				yy += 1.1
				row += 1
		"slow_ice":
			# slush: dots of 0.22-0.34 m on a staggered 1.3 m grid
			var row: int = 0
			var yy: float = -ey + 0.4
			while yy <= ey - 0.3:
				var xx: float = -ex + (0.65 if row % 2 == 1 else 0.0) + 0.3
				var i: int = 0
				while xx <= ex - 0.3:
					if not circle or Vector2(xx, yy).length() < r * 0.85:
						_disc(mk, Vector2(c.x + xx, c.y + yy), 0.0, 0.22 + 0.06 * float((i + row) % 3), y, Color.WHITE.lerp(col, 0.25), 10)
					xx += 1.3
					i += 1
				yy += 1.3
				row += 1
		"no_shoot":
			# a red cross-hatch at 45 degrees, lines 1.5 m apart, clipped to the patch
			var step: float = 1.5
			var k: float = -(ex + ey)
			while k <= ex + ey:
				for sgn: float in [1.0, -1.0]:
					var seg: Array = _clip_diag(k, sgn, ex, ey)
					if not seg.is_empty():
						_strip(mk, c + (seg[0] as Vector2), c + (seg[1] as Vector2), 0.07, y, col)
				k += step
		"boost_only":
			var arm: float = minf(minf(ex, ey) * 0.8, 1.6)
			_strip(mk, c + Vector2(-arm, 0), c + Vector2(arm, 0), 0.2, y, light)
			_strip(mk, c + Vector2(0, -arm), c + Vector2(0, arm), 0.2, y, light)
		"bumper":
			_disc(mk, c, 0.0, minf(minf(ex, ey) * 0.4, 0.8), y, BUMPER.lerp(Color.WHITE, 0.3), 24)


## The line x + sgn * y = k inside the box |x| <= ex, |y| <= ey: its two ends, or [] if it misses.
static func _clip_diag(k: float, sgn: float, ex: float, ey: float) -> Array:
	var pts: Array = []
	for yy: float in [-ey, ey]:
		var xx: float = k - sgn * yy
		if absf(xx) <= ex:
			pts.append(Vector2(xx, yy))
	for xx: float in [-ex, ex]:
		var yy: float = (k - xx) * sgn
		if absf(yy) <= ey:
			pts.append(Vector2(xx, yy))
	if pts.size() < 2:
		return []
	return [pts[0], pts[1]] if (pts[0] as Vector2).distance_to(pts[1]) > 0.05 else []


static func _rect(mk: TLMesh, x0: float, y0: float, x1: float, y1: float, h: float, col: Color) -> void:
	mk.quad_up(Vector3(x0, h, y0), Vector3(x1, h, y0), Vector3(x1, h, y1), Vector3(x0, h, y1), "white", col)


static func _strip(mk: TLMesh, a: Vector2, b: Vector2, hw: float, h: float, col: Color) -> void:
	var d: Vector2 = (b - a).normalized()
	var n: Vector2 = Vector2(-d.y, d.x) * hw
	mk.quad_up(Vector3(a.x + n.x, h, a.y + n.y), Vector3(b.x + n.x, h, b.y + n.y), Vector3(b.x - n.x, h, b.y - n.y), Vector3(a.x - n.x, h, a.y - n.y), "white", col)


static func _disc(mk: TLMesh, c: Vector2, r0: float, r1: float, h: float, col: Color, seg: int = 64) -> void:
	for i: int in seg:
		var t0: float = TAU * float(i) / float(seg)
		var t1: float = TAU * float(i + 1) / float(seg)
		var o0: Vector2 = c + Vector2(cos(t0), sin(t0)) * r1
		var o1: Vector2 = c + Vector2(cos(t1), sin(t1)) * r1
		var i0: Vector2 = c + Vector2(cos(t0), sin(t0)) * r0
		var i1: Vector2 = c + Vector2(cos(t1), sin(t1)) * r0
		mk.quad_up(Vector3(i0.x, h, i0.y), Vector3(o0.x, h, o0.y), Vector3(o1.x, h, o1.y), Vector3(i1.x, h, i1.y), "white", col)


# ---------------------------------------------------------------- obstacles (RinkActor.cpp:1154-1240)
func _obstacle(mk: TLMesh, o: Dictionary) -> void:
	var kind: String = String(o.get("kind", "box"))
	var hs: float = float(o.get("size", 1.0)) * 0.5
	var c := Vector3(float(o.get("x", 0.0)), 0.0, float(o.get("z", 0.0)))
	match kind:
		"pillar":
			mk.cyl(hs, BOARD_H, 20, "white", BOARD, -1.0, c)
			mk.cyl(hs + 0.02, 0.25, 20, "yellow", Color.WHITE, -1.0, c, false, false)   # the boards' kick plate round its foot
		"bumper":
			# lane A64: a rubber bollard: dark base band (0-14 cm) and top band (106-120 cm) 3 cm proud, a dark lid with a
			# magenta boss (r x 0.62, 2 cm high), the magenta body between
			var band: float = 0.14
			var proud: float = 0.03
			mk.cyl(hs, BOARD_H - 2.0 * band, 20, "white", BUMPER, -1.0, c + Vector3(0, band, 0), false, false)
			mk.cyl(hs + proud, band, 20, "white", DARK, -1.0, c, false, true)
			mk.cyl(hs + proud, band, 20, "white", DARK, -1.0, c + Vector3(0, BOARD_H - band, 0), true, false)
			mk.cyl(hs * 0.62, 0.02, 20, "white", BUMPER, -1.0, c + Vector3(0, BOARD_H, 0), true, false)
		"goal_shield":
			mk.boxm(c - Vector3(0.15, 0.0, hs), c + Vector3(0.15, BOARD_H, hs), "white", SHIELD)
			mk.boxm(c - Vector3(0.16, 0.0, hs + 0.01), c + Vector3(0.16, 0.25, hs + 0.01), "yellow")
		_:
			mk.boxm(c - Vector3(hs, 0.0, hs), c + Vector3(hs, BOARD_H, hs), "white", BOARD)
			mk.boxm(c - Vector3(hs + 0.02, 0.0, hs + 0.02), c + Vector3(hs + 0.02, 0.25, hs + 0.02), "yellow")


# ---------------------------------------------------------------- pickups (AJamPickupActor::Sync, cpp:214-247)
## One sim frame: the bus's pickup events, then the beacons turned, raised or lowered (ApplyBeacon, cpp:402-420).
func frame(snap: Dictionary) -> void:
	var f: int = int(snap.get("Frame", 0))
	if f < _last_frame:                         # the core restarted (R): UJamEffectSystem::Reset empties the ice
		clear()
	_last_frame = f
	if snap.has("Pickups"):
		reported = true
		_sync(snap["Pickups"], f)
	else:
		for e: Dictionary in snap.get("Events", []):
			var nm: String = String(e.get("Name", ""))
			if nm == "pickup_spawn":
				reported = true
				_spawn(String(e.get("Kind", "")), e.get("Where", Vector2.ZERO), f)
			elif nm == "pickup_take":
				reported = true
				_take(String(e.get("Kind", "")), e.get("Where", Vector2.ZERO), f)
	var keep: Array = []
	for s: Dictionary in snap.get("Skaters", []):
		if not bool(s.get("InBox", false)):
			keep.append(s.get("Pos", Vector2.ZERO))
	keep.append((snap.get("Puck", {}) as Dictionary).get("Pos", Vector2(1e9, 1e9)))
	for p: Dictionary in pickups:
		var nearest: float = 1e9
		for k: Vector2 in keep:
			nearest = minf(nearest, k.distance_to(p["pos"]))
		var want: float = clampf((nearest - BEACON_CLEAR_M) / 1.0, 0.0, 1.0)   # BeaconHeightFor (cpp:339-343)
		p["height"] = float(p["height"]) + clampf(want - float(p["height"]), -0.08, 0.08)
		var hh: float = BEACON_LOW + (1.0 - BEACON_LOW) * float(p["height"])
		var bob: float = 0.08 * sin(float(f) * TAU / 120.0) * float(p["height"])
		var shape: Node3D = p["shape"]
		shape.position = Vector3(0, BEACON_OBJECT_M * hh + bob, 0)
		shape.rotation = Vector3(0, deg_to_rad(fmod(float(f) * SPIN_DEG_PER_FRAME, 360.0)), 0)
		shape.scale = Vector3.ONE * (0.6 + 0.4 * float(p["height"]))
		(p["pedestal"] as Node3D).scale = Vector3(1, hh, 1)
	for i: int in range(taken.size() - 1, -1, -1):
		var t: Dictionary = taken[i]
		var age: int = f - int(t["frame"])
		if age >= TAKEN_FRAMES:
			(t["node"] as Node3D).queue_free()
			taken.remove_at(i)
		else:
			var k: float = 1.0 - float(age) / float(TAKEN_FRAMES)
			(t["node"] as Node3D).scale = Vector3(1.0 + (1.0 - k) * 0.8, k, 1.0 + (1.0 - k) * 0.8)
	root.set_meta(&"toys", counts())


## The core's own list (AJamPickupActor::Sync: a new Id spawns a beacon, a missing one retires).
func _sync(on_ice: Array, f: int) -> void:
	var ids: Dictionary = {}
	for q: Dictionary in on_ice:
		ids[int(q.get("Id", -1))] = q
	for i: int in range(pickups.size() - 1, -1, -1):
		if not ids.has(int(pickups[i]["id"])):
			var p: Dictionary = pickups[i]
			pickups.remove_at(i)
			took += 1
			taken.append({"node": p["node"], "frame": f})
	var have: Dictionary = {}
	for p: Dictionary in pickups:
		have[int(p["id"])] = true
	for id: int in ids:
		if not have.has(id):
			var q: Dictionary = ids[id]
			_spawn(String(q.get("Kind", "")), q.get("Pos", Vector2.ZERO), f, id)


func clear() -> void:
	for p: Dictionary in pickups:
		(p["node"] as Node3D).queue_free()
	for t: Dictionary in taken:
		(t["node"] as Node3D).queue_free()
	pickups = []
	taken = []


func _spawn(kind: String, at: Vector2, f: int, id: int = -1) -> void:
	var col: Color = PICKUP_COLOUR.get(kind, Color.WHITE)
	var n := Node3D.new()
	n.name = "Pickup_%s_%d" % [kind, spawned]
	root.add_child(n)
	n.position = Vector3(at.x, 0.0, at.y)
	var ground := TLMesh.new(49)
	_disc(ground, Vector2.ZERO, BEACON_RING_R * 0.62, BEACON_RING_R, ZONE_Y + 0.004, col, 24)   # the ground ring (BuildRing: radius 1.1, fill 0.62)
	_disc(ground, Vector2.ZERO, 0.0, BEACON_RING_R * 0.62, ZONE_Y + 0.003, ICE.lerp(col, 0.25), 24)
	var gi: MeshInstance3D = ground.instance("PickupRing")
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(gi)
	var ped := Node3D.new()
	ped.name = "Pedestal"
	n.add_child(ped)
	var pm := TLMesh.new(50)
	pm.cyl(BEACON_PEDESTAL_W * 0.5, BEACON_PEDESTAL_M, 10, "white", col.lerp(Color.WHITE, 0.35))
	ped.add_child(pm.instance("PedestalMesh"))
	var shape := Node3D.new()
	shape.name = "Shape"
	n.add_child(shape)
	var sm := TLMesh.new(51)
	var sz: float = BEACON_SIZE_M
	match kind:
		"speed":                                  # a spike up (cpp:390)
			sm.cyl(sz * 0.375, sz, 16, "white", col, 0.0, Vector3(0, -sz * 0.5, 0))
		"precision":                              # a cube on its corner (cpp:391)
			sm.push_at(Vector3.ZERO, Vector3(45.0, 0.0, 35.26))
			sm.box(Vector3.ONE * sz * 0.62, "white", col)
			sm.pop()
		"heavy_puck":                             # a puck (cpp:392)
			sm.cyl(sz * 0.5, sz * 0.35, 20, "white", col, -1.0, Vector3(0, -sz * 0.175, 0))
		"big_puck":                               # a ball
			sm.blob(Vector3.ONE * sz * 0.5, 1, 0.0, "white", col)
		"reverse_other":                          # a cube
			sm.box(Vector3.ONE * sz * 0.7, "white", col)
		_:                                        # a custom effect: a star (two crossed diamonds)
			for e: Vector3 in [Vector3(45.0, 0.0, 35.26), Vector3(45.0, 45.0, 35.26)]:
				sm.push_at(Vector3.ZERO, e)
				sm.box(Vector3.ONE * sz * 0.5, "white", col)
				sm.pop()
	shape.add_child(sm.instance("PickupShape"))
	pickups.append({"node": n, "shape": shape, "pedestal": ped, "kind": kind, "pos": at, "born": f, "height": 1.0, "id": id})
	spawned += 1


func _take(kind: String, at: Vector2, f: int) -> void:
	var best: int = -1
	var best_d: float = 0.5                       # the take's Where is the pickup's own Pos (JamEffectSystem.cpp StepPickups)
	for i: int in pickups.size():
		var p: Dictionary = pickups[i]
		var d: float = (p["pos"] as Vector2).distance_to(at)
		if d < best_d and (kind == "" or String(p["kind"]) == kind):
			best_d = d
			best = i
	if best < 0:
		return
	var p: Dictionary = pickups[best]
	pickups.remove_at(best)
	took += 1
	taken.append({"node": p["node"], "frame": f})
