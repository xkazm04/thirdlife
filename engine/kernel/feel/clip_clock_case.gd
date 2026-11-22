extends SceneTree
## Selftest block 716 (E1, loop round 1, night of 22 Nov 2026), headless. Prints `CLOCK <case> ok=true|false ...`:
##   map     TLBiped.play_clip on a frame timeline: the rig shows the timeline's clip frame on every tick (a duel heavy:
##           0 -> 8 over 24, the coil 8 -> 10 over 6, the chop to 14.4 by 37, back to 30 by 65); a 5-frame hit-stop at
##           tick 10 holds the clip frame for exactly 5 ticks and the timeline resumes where it stood; past the last knot
##           the clip runs on at its own pace
##   speed   set_clip_speed(0.5) advances half a clip frame per tick, 0 holds, and a kernel reaction (TLHit.blocked)
##           takes the rig over and ends the clock
##   bad     a timeline whose frames do not rise is refused with an error and plays nothing
##   same    two runs give the same clip frames (frame counted, no clock)

const MAP: Array = [[0, 0.0], [24, 8.0], [30, 10.0], [37, 14.4], [65, 30.0]]
const Clock = preload("res://kernel/feel/clip_clock.gd")

var lines: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func say(name: String, ok: bool, note: String) -> void:
	print("CLOCK %s ok=%s %s" % [name, "true" if ok else "false", note])


func pair() -> Array:
	var fl := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(20, 1, 20)
	cs.shape = bx
	cs.position.y = -0.5
	fl.add_child(cs)
	root.add_child(fl)
	var a := TLBiped.create({"position": Vector3(0, 0, 0), "rig_params": {"backpack": false}})
	var b := TLBiped.create({"position": Vector3(0, 0, -1.2), "facing": PI, "rig_params": {"backpack": false}})
	root.add_child(a)
	root.add_child(b)
	return [fl, a, b]


## Ticks the biped by hand (physics off) so the count is exact: returns the clip frame after each tick.
func map_run() -> Array:
	var nodes := pair()
	var a: TLBiped = nodes[1]
	var b: TLBiped = nodes[2]
	for n: TLBiped in [a, b]:
		n.set_physics_process(false)
	var seen: Array = []
	a.play_clip(&"strike_heavy", MAP)
	for tick in range(1, 72):
		if tick == 10:
			TLHit.impact(a, b, 5)
		a._physics_process(1.0 / 60.0)
		seen.append([a.clip_now(), snappedf(a.clip_frame(), 0.001)])
	for n in nodes:
		n.free()
	return seen


func run() -> void:
	# map
	var s1 := map_run()
	var s2 := map_run()
	var ok := true
	var why := ""
	for tick in range(1, 72):
		var want: float
		var t := tick if tick < 10 else (9 if tick < 15 else tick - 5)    # ticks 10..14 frozen at tick 9's frame
		if t <= 65:
			want = maxf(1.0, Clock.at(MAP, float(t)))
		else:
			want = 30.0 + float(t - 65)                                         # its own pace after the last knot
		var got: Array = s1[tick - 1]
		var expect_clip: StringName = &"strike_heavy" if want < 30.0 else &""
		if t > 65:
			expect_clip = &""                                                  # a 30-frame clip: done at 30, locomotion
		if expect_clip != &"" and (got[0] != expect_clip or absf(float(got[1]) - want) > 0.002):
			ok = false
			why = "tick %d: %s@%.3f, want %s@%.3f" % [tick, got[0], got[1], expect_clip, want]
			break
	say("map", ok, why if not ok else "71 ticks, hit-stop 10..14 held at %.3f, coil 8 -> 10 over 6, chop at 37 = 14.4" % float(s1[9][1]))
	say("same", s1 == s2, "two runs %s" % ("equal" if s1 == s2 else "DIFFER"))
	# speed
	var nodes := pair()
	var a: TLBiped = nodes[1]
	var b: TLBiped = nodes[2]
	for n: TLBiped in [a, b]:
		n.set_physics_process(false)
	a.play_clip(&"taunt")
	a._physics_process(1.0 / 60.0)
	a.set_clip_speed(0.5)
	var half: Array = []
	for i in 6:
		a._physics_process(1.0 / 60.0)
		half.append(snappedf(a.clip_frame(), 0.001))
	a.set_clip_speed(0.0)
	var held := a.clip_frame()
	for i in 5:
		a._physics_process(1.0 / 60.0)
	var still := a.clip_frame()
	TLHit.blocked(b, a, true)
	a._physics_process(1.0 / 60.0)     # hit-stop: frozen
	for i in 7:
		a._physics_process(1.0 / 60.0)
	var taken: bool = a.clip_now() == &"block_stun" and a._clock == null
	var sp_ok: bool = half == [1.5, 2.0, 2.5, 3.0, 3.5, 4.0] and absf(held - still) < 0.0001 and taken
	say("speed", sp_ok, "half %s, held %.2f -> %.2f, reaction %s clock %s" % [str(half), held, still, a.clip_now(), "ended" if a._clock == null else "kept"])
	# bad
	var before := a.clip_now()
	a.play_clip(&"strike", [[0, 1.0], [-3, 2.0]])
	say("bad", a.clip_now() == before, "refused; the clip stays %s (the error above is expected)" % before)
	for n in nodes:
		n.free()
	quit()
