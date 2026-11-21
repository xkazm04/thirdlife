extends RefCounted
## K8 feel kit (lane N1, night of 22 Nov 2026): one biped's hit-stop, stun and push-back. Internal to the kernel: packs
## call TLHit (kernel/api/tl_hit.gd), which makes this object on the first contact a biped takes (`TLBiped._feel`; a biped
## that never took one has none, and its state hash is what it always was).
##
## Stepped first thing in TLBiped._physics_process, every physics frame:
##   hit-stop (stop_left > 0): the body, its rig and its down/stumble counters all hold (step returns 1: nothing else runs)
##   then the push-back travels its share of this frame (move_and_collide: walls stop it; a push in a knock that meets a
##   wall turns into a wall-splat), then the stun counts down (step returns 2: no intent reaches the legs, brake on).

const SHAKE_M: float = 0.035          # the struck body's rig jitters this far along the blow during hit-stop (drawing only)

var stop_left: int = 0                # hit-stop frames still frozen
var stop_total: int = 0
var stun: StringName = &""            # the reaction he is in (&"" none): hitstun, blockstun, recoil, parried, recover,
var stun_left: int = 0                #   rebound, guardbroken, wallsplat
var stun_frames: int = 0
var push: Vector3 = Vector3.ZERO      # world, horizontal: the whole push-back
var push_frames: int = 0
var push_i: int = 0
var splat_frames: int = 0             # > 0: this push is a knock, and a wall in its way splats him for this long
var shake_dir: Vector3 = Vector3.ZERO # world: the struck body shakes along it during hit-stop (zero: no shake)
var rig_base: Vector3 = Vector3.ZERO
var shaking: bool = false
var box: bool = false                 # TLHit.pushbox: this body takes part in its pack's pushbox
var box_radius: float = -1.0          # -1: body_radius() + 0.02


## 0 = free, 1 = frozen in hit-stop (the caller returns at once), 2 = stunned (no intent this frame).
func step(b: TLBiped) -> int:
	if stop_left > 0:
		stop_left -= 1
		_shake(b)
		return 1
	if push_i < push_frames:
		_push_step(b)
		if stop_left > 0:        # the push met a wall: the splat's own hit-stop starts next frame
			return 2
	if stun_left > 0:
		stun_left -= 1
		if stun_left == 0:
			stun = &""
		return 2
	return 0


func freeze(frames: int, along: Vector3, b: TLBiped) -> void:
	stop_left = maxi(stop_left, frames)
	stop_total = stop_left
	if along.length() > 0.001 and b.rig != null:
		if not shaking:
			rig_base = b.rig.position
		shaking = true
		shake_dir = along.normalized()


func set_stun(kind: StringName, frames: int) -> void:
	stun = kind
	stun_left = frames
	stun_frames = frames


## `frames` 0 = by distance: 4 frames for 0.15 m up to 10 for 1 m.
func set_push(world: Vector3, splat: int, frames: int = 0) -> void:
	var flat := Vector3(world.x, 0.0, world.z)
	push = flat
	push_i = 0
	push_frames = (frames if frames > 0 else clampi(int(round(4.0 + 6.0 * flat.length())), 4, 10)) if flat.length() > 0.0005 else 0
	splat_frames = splat


## A knockdown (TLHit.down) ends the stun and the push; a hit-stop still running keeps running.
func knocked_down() -> void:
	stun = &""
	stun_left = 0
	push_frames = 0
	push_i = 0


func clear(b: TLBiped) -> void:
	knocked_down()
	stop_left = 0
	_unshake(b)


func busy() -> int:
	return stop_left + stun_left


## The state hash's share ("" when nothing runs: a body with a past contact hashes like one with none).
func text() -> String:
	if stop_left <= 0 and stun_left <= 0 and push_i >= push_frames:
		return ""
	return ";hit%d,%s%d,%d/%d" % [stop_left, stun, stun_left, push_i, push_frames]


func _shake(b: TLBiped) -> void:
	if not shaking:
		return
	var rig: Node3D = b.rig
	if stop_left == 0 or rig == null:
		_unshake(b)
		return
	var k := float(stop_left) / float(maxi(stop_total, 1))
	var side := 1.0 if stop_left % 2 == 0 else -1.0
	var basis := b.global_transform.basis.orthonormalized() if b.is_inside_tree() else b.transform.basis.orthonormalized()
	rig.position = rig_base + basis.inverse() * shake_dir * (SHAKE_M * k * side)


func _unshake(b: TLBiped) -> void:
	if shaking and b.rig != null:
		b.rig.position = rig_base
	shaking = false


static func _ease(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


func _push_step(b: TLBiped) -> void:
	push_i += 1
	var share := _ease(float(push_i) / float(push_frames)) - _ease(float(push_i - 1) / float(push_frames))
	if not b.is_inside_tree():
		b.position += push * share
		return
	var col: KinematicCollision3D = b.move_and_collide(push * share)
	if col == null or splat_frames <= 0:
		return
	var n := col.get_normal()
	if col.get_collider() is StaticBody3D and Vector3(n.x, 0.0, n.z).normalized().dot(-push.normalized()) > 0.5:
		TLHit._splat(b, n, splat_frames)
