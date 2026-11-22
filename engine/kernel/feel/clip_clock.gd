extends RefCounted
## E1 (loop round 1, night of 22 Nov 2026): the clock of one biped's rig clip, for TLBiped.play_clip / set_clip_speed.
## Internal to the kernel. TLBiped._tick_rig calls step() right before rig.tick(): step sets the rig's clip time so that
## after the tick (which adds one frame itself) the rig shows the clip frame the timeline asks for. A hit-stop skips
## _tick_rig, so the timeline holds with the pose. When the rig's clip is no longer this clip (a kernel reaction, a fall,
## another play), the clock is done. Visual only: nothing here reaches physics or the state hash.

const DT: float = 1.0 / 60.0

var clip: StringName = &""
var knots: Array = []          # [[frame, clip frame], ...], frames from the play (the tick after it is frame 1)
var speed: float = 1.0         # without knots: clip frames per tick
var t: int = 0                 # ticks since the play
var pos: float = 0.0           # the clip frame now


## TLBiped.play_clip: plays the clip; returns the clock that steers it (null: its own pace, or nothing played).
static func play(who: TLBiped, cname: StringName, timing: Array, blend: float) -> RefCounted:
	var why := check(timing)
	if not why.is_empty():
		push_error("TLBiped.play_clip: " + why)
		return null
	if who.rig == null or (cname != &"" and not who._rig_has(cname)):
		return null
	who.rig.call("play", cname, blend)
	if cname == &"" or timing.is_empty():
		return null
	var c = new()
	c.clip = cname
	c.knots = timing.duplicate(true)
	return c


## TLBiped.set_clip_speed: a clock at a constant pace for the clip playing now (`kept` when nothing plays).
static func paced(rig: Node, pace: float, kept: RefCounted) -> RefCounted:
	if now(rig) == &"":
		return kept
	var c = new()
	c.clip = now(rig)
	c.speed = maxf(0.0, pace)
	c.pos = float(rig.get(&"clip_t")) / DT
	return c


static func now(rig: Node) -> StringName:
	return StringName(rig.get(&"clip")) if rig != null and "clip" in rig and "clip_t" in rig else &""


static func frame_of(rig: Node) -> float:
	return float(rig.get(&"clip_t")) / DT if now(rig) != &"" else 0.0


static func check(timing: Array) -> String:
	var last := -1.0
	for k: Variant in timing:
		if not (k is Array) or (k as Array).size() != 2:
			return "each knot is [frame, clip frame]"
		var f := float(k[0])
		if f < 0.0 or f <= last or float(k[1]) < 0.0:
			return "knot frames start at 0 and rise; clip frames are >= 0"
		last = f
	return ""


## Clip frame at tick `x` of the timeline (piecewise linear between knots; before the first knot, its value).
static func at(timing: Array, x: float) -> float:
	var px := float(timing[0][0])
	var py := float(timing[0][1])
	for k: Array in timing:
		var kx := float(k[0])
		var ky := float(k[1])
		if x <= kx:
			return ky if kx <= px else lerpf(py, ky, (x - px) / (kx - px))
		px = kx
		py = ky
	return py


## True while the clock still steers the rig.
func step(rig: Node) -> bool:
	if rig == null or StringName(rig.get(&"clip")) != clip:
		return false
	t += 1
	if not knots.is_empty():
		if float(t) > float(knots[-1][0]):
			return false                   # past the last knot: the clip runs on at its own pace
		pos = at(knots, float(t))
	else:
		pos += speed
	rig.set(&"clip_t", maxf(0.0, pos * DT - DT))
	return true
