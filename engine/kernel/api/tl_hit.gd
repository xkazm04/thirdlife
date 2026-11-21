class_name TLHit
extends RefCounted
## K7 (21 Nov 2026, spark game-quality-bar): how a figure takes a hit. One place every pack calls, so the way a hit
## looks (a flinch, a fall away from the blow, a get-up) can change without changing a pack.
##
##   TLHit.react(victim, attacker.global_position - victim.global_position, 0.8)   # flinch or stumble by strength
##   TLHit.down(victim, 90, attacker.global_position - victim.global_position)      # floored, falling away from it
##
## `from_dir` is the direction FROM the victim TOWARD where the blow came from (world space; length ignored; zero =
## unknown). `strength` is the hit's size: about 0.3 a tap, 0.7 a solid hit, 1.2 and up a big one.
## v1 is a stand-in: `react` is a stumble from 0.4 up (nothing below), `down` is `TLBiped.down(frames)` and ignores
## `from_dir`. The falls experiment of 21 Nov replaces the bodies (directional flinch, a fall away from the blow, a
## get-up); the signatures stay.


## A hit that does not floor him: below 0.4 nothing, from 0.4 a stumble of 8 + 10 * strength frames, leaning away from
## the blow when `from_dir` says where it came from. Ignored while he is down (as `stumble` is).
static func react(who: TLBiped, from_dir: Vector3, strength: float) -> void:
	if who == null or strength < 0.4:
		return
	var lean := 0.7
	var basis: Basis = who.global_basis if who.is_inside_tree() else who.basis
	var side := from_dir - basis.y * from_dir.dot(basis.y)
	if side.length() > 0.001:
		var right := basis.x.dot(side.normalized())              # +1: the blow came from his right
		if absf(right) > 0.2:
			lean = -0.7 * signf(right)                              # a blow from his right leans him left (-1)
	who.stumble(int(round(8.0 + 10.0 * strength)), lean)


## Floors him for `frames` physics frames, falling away from `from_dir` (v1: `TLBiped.down(frames)`, the rig's `fall`
## clip, whatever the direction). Everything `TLBiped.down` says holds: he rises over `get_up_frames`, `downed` and
## `got_up` fire, `down` while down keeps the longer time.
static func down(who: TLBiped, frames: int, from_dir: Vector3 = Vector3.ZERO) -> void:
	if who == null:
		return
	assert(from_dir.is_finite(), "TLHit.down: from_dir must be finite")
	who.down(frames)
